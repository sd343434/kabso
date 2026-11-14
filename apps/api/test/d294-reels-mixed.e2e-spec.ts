/**
 * D294 (v1.92-social, CONVENTIONS §10.107): the reels page's one feed `GET /feed/reels?tab=mixed` — the posts home
 * feed's rule (§10.73.1) over reels, end to end against PostgreSQL + Redis with the API as the DML-only runtime role:
 * 1 Following (followed accounts, the caller's own, reposts by followed accounts) : 2 Trending (§11.3 over public
 * reels), exhaustion of either source, each reel once across pages, muted / hidden / blocked / private left out, the
 * frozen snapshot and its bound cursor; `following`, `trending` and the posts `mixed` unchanged. Object storage is the
 * in-memory double; every response is checked against openapi.
 */
import { randomUUID } from 'node:crypto';
import type { Redis } from 'ioredis';
import sharp from 'sharp';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { REDIS } from '../src/redis/redis.module.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { mp4 } from './helpers/mp4.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

interface FeedEntry {
  id: string;
  format: string;
  author: { id: string };
  isSelf: boolean;
  viewerFollowsAuthor: boolean;
  repostedBy: { id: string } | null;
}

const MEDIA_ON = {
  MEDIA_UPLOADS_ENABLED: 'true',
  S3_BUCKET: 'kabso-media-test',
  S3_ACCESS_KEY_ID: 'test',
  S3_SECRET_ACCESS_KEY: 'test',
  MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
  RATE_LIMIT_MEDIA_UPLOAD_USER: '1000/3600',
  RATE_LIMIT_POST_CREATE_HOUR_USER: '1000/3600',
  RATE_LIMIT_POST_CREATE_DAY_USER: '1000/86400',
  RATE_LIMIT_FEED_USER: '10000/60',
};

describe('D294 contract coverage', () => {
  it('openapi v1.92-social declares tab=mixed on listFeedReels; listFeedPosts unchanged', () => {
    const tab = (operationId: string) =>
      (
        operations().find((o) => o.operationId === operationId)?.spec.parameters as
          { name: string; schema?: { enum?: string[] } }[] | undefined
      )?.find((p) => p.name === 'tab')?.schema?.enum;
    expect(tab('listFeedReels')).toEqual(['following', 'trending', 'nearby', 'mixed']);
    expect(tab('listFeedPosts')).toEqual(['following', 'trending', 'mixed']);
  });
});

describe('D294 the reels feed tab=mixed', { timeout: 180_000 }, () => {
  let storage: MemoryObjectStorage;
  let ctx: TestContext;
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
  };
  const follow = (follower: TestUser, followee: TestUser) =>
    withMigrationClient((c) =>
      c.follow.create({ data: { followerId: follower.id, followeeId: followee.id } }),
    );
  const makePrivate = (u: TestUser) =>
    withMigrationClient((c) =>
      c.userSettings.upsert({
        where: { userId: u.id },
        create: { userId: u.id, isPrivate: true },
        update: { isPrivate: true },
      }),
    );
  const upload = async (u: TestUser, kind: string, bytes: Buffer, contentType: string) => {
    const s = await ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send({ kind, contentType, byteSize: bytes.length });
    expect(s.status, JSON.stringify(s.body)).toBe(201);
    expect(storage.upload(s.body.uploadUrl, bytes, contentType)).toBe(true);
    return s.body.uploadId as string;
  };
  let posterBytes: Buffer;
  const reel = async (u: TestUser, text: string): Promise<string> => {
    const video = await upload(
      u,
      'REEL_VIDEO',
      mp4({ durationMs: 6_000, width: 720, height: 1280 }),
      'video/mp4',
    );
    const posterUpload = await upload(u, 'VIDEO_POSTER', posterBytes, 'image/jpeg');
    const poster = await ctx.http.post(`/api/v1/media/uploads/${posterUpload}/complete`).set(auth(u));
    expect(poster.status).toBe(200);
    const done = await ctx.http
      .post(`/api/v1/media/uploads/${video}/complete`)
      .set(auth(u))
      .send({ posterId: poster.body.id });
    expect(done.status, JSON.stringify(done.body)).toBe(200);
    const created = await ctx.http
      .post('/api/v1/posts')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({ format: 'REEL', text, mediaIds: [done.body.id] });
    expect(created.status, JSON.stringify(created.body)).toBe(201);
    return created.body.id as string;
  };
  const textPost = async (u: TestUser, text: string): Promise<string> => {
    const res = await ctx.http
      .post('/api/v1/posts')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({ text });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const repost = async (u: TestUser, postId: string) =>
    expect((await ctx.http.put(`/api/v1/posts/${postId}/repost`).set(auth(u))).status).toBe(200);
  const get = async (
    path: '/api/v1/feed/reels' | '/api/v1/feed/posts',
    u: TestUser,
    tab: string,
    limit: number,
    cursor?: string | null,
  ): Promise<request.Response> => {
    const res = await ctx.http
      .get(path)
      .query({ tab, limit, ...(cursor ? { cursor } : {}) })
      .set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, path === '/api/v1/feed/reels' ? 'listFeedReels' : 'listFeedPosts');
    return res;
  };
  const mixed = (u: TestUser, limit: number, cursor?: string | null) =>
    get('/api/v1/feed/reels', u, 'mixed', limit, cursor);
  /** Every entry of a list, page by page (`limit` per page). */
  const all = async (
    u: TestUser,
    limit = 50,
    tab = 'mixed',
    path: '/api/v1/feed/reels' | '/api/v1/feed/posts' = '/api/v1/feed/reels',
  ): Promise<FeedEntry[]> => {
    const out: FeedEntry[] = [];
    let cursor: string | null = null;
    for (let i = 0; i < 200; i += 1) {
      const res = await get(path, u, tab, limit, cursor);
      out.push(...(res.body.data as FeedEntry[]));
      cursor = res.body.page.nextCursor as string | null;
      if (!res.body.page.hasMore) break;
    }
    return out;
  };
  /** F: a reels Following entry (a followed author, the caller's own, a repost by a followed account); T: Trending. */
  const source = (e: FeedEntry) => (e.viewerFollowsAuthor || e.isSelf || e.repostedBy !== null ? 'F' : 'T');

  beforeAll(async () => {
    storage = new MemoryObjectStorage();
    ctx = await createTestApp(MEDIA_ON, [{ token: OBJECT_STORAGE, value: storage }]);
    ctx.app.getHttpServer().setMaxListeners(64);
    posterBytes = await sharp({ create: { width: 540, height: 960, channels: 3, background: '#357' } })
      .jpeg()
      .toBuffer();
  });
  afterAll(async () => ctx?.close());

  it('is 1 Following : 2 Trending, the caller own reels in Following; Trending continues alone; each once', async () => {
    const [me, friend1, friend2] = [await signup(), await signup(), await signup()];
    await follow(me, friend1);
    await follow(me, friend2);
    const own = await reel(me, 'my own reel');
    const f1 = await reel(friend1, 'friend one');
    const f2 = await reel(friend2, 'friend two');
    const strangers = await Promise.all(Array.from({ length: 6 }, () => signup()));
    const trending: string[] = [];
    for (const s of strangers) trending.push(await reel(s, `stranger ${s.username}`));
    // A text post is never in the reels feed.
    const text = await textPost(friend1, 'a text post');

    const feed = await all(me);
    const ids = feed.map((e) => e.id);
    expect(new Set(ids).size).toBe(ids.length);
    expect(feed.every((e) => e.format === 'REEL')).toBe(true);
    expect(ids).not.toContain(text);
    expect(ids).toEqual(expect.arrayContaining([own, f1, f2, ...trending]));
    // Following newest first at places 0, 3 and 6 (the own reel too), Trending between, then Trending alone.
    expect([ids[0], ids[3], ids[6]]).toEqual([f2, f1, own]);
    const pattern = feed.map(source).join('');
    expect(pattern.startsWith('FTTFTTF')).toBe(true);
    expect(pattern.slice(7)).not.toContain('F');
    expect(feed[6]!.isSelf).toBe(true);
    expect(feed[1]!.viewerFollowsAuthor).toBe(false);
  });

  it('Following continues alone when Trending runs out (a private author is never Trending)', async () => {
    const me = await signup();
    const authors = await Promise.all(Array.from({ length: 3 }, () => signup()));
    const followed: string[] = [];
    for (const a of authors) {
      await follow(me, a);
      await makePrivate(a);
      followed.push(await reel(a, `private ${a.username}`));
    }
    const stranger = await signup();
    const onlyTrending = await reel(stranger, 'the only Trending reel');
    // Trending holds one reel: every other reel author in the database is muted by the caller.
    await withMigrationClient(async (c) => {
      const others = await c.post.findMany({
        where: {
          format: 'REEL',
          authorId: { notIn: [me.id, stranger.id, ...authors.map((a) => a.id)] },
        },
        select: { authorId: true },
        distinct: ['authorId'],
      });
      await c.userMute.createMany({
        data: others.map((o) => ({ muterId: me.id, mutedId: o.authorId })),
        skipDuplicates: true,
      });
    });
    const feed = await all(me, 2);
    // F T F F: the newest Following, the one Trending, then Following alone, newest first.
    expect(feed.map((e) => e.id)).toEqual([followed[2], onlyTrending, followed[1], followed[0]]);
    expect(feed.map(source).join('')).toBe('FTFF');
  });

  it('a reel in both sources is listed once, at its Following place; a repost carries repostedBy', async () => {
    const [me, friend, reposter] = [await signup(), await signup(), await signup()];
    await follow(me, friend);
    await follow(me, reposter);
    const hot = await reel(friend, 'friend hot reel');
    const fans = await Promise.all(Array.from({ length: 4 }, () => signup()));
    for (const fan of fans) await ctx.http.put(`/api/v1/posts/${hot}/like`).set(auth(fan));
    const strangerReel = await reel(await signup(), 'reposted by a followed account');
    await repost(reposter, strangerReel);
    const feed = await all(me);
    expect(feed.filter((e) => e.id === hot)).toHaveLength(1);
    expect(feed.filter((e) => e.id === strangerReel)).toHaveLength(1);
    // The repost is the newest Following entry (place 0) with its reposter; the hot reel the next one (place 3).
    expect(feed[0]!.id).toBe(strangerReel);
    expect(feed[0]!.repostedBy?.id).toBe(reposter.id);
    expect(feed[3]!.id).toBe(hot);
  });

  it('never lists muted, hidden, blocked (both ways) or private strangers; the own reel once even when reposted', async () => {
    const [me, friend, muted, blocked, blocker, hiddenBy, privateStranger] = [
      await signup(),
      await signup(),
      await signup(),
      await signup(),
      await signup(),
      await signup(),
      await signup(),
    ];
    await follow(me, friend);
    await follow(me, muted);
    const mine = await reel(me, 'my own');
    await repost(friend, mine);
    const mutedReel = await reel(muted, 'muted author, followed');
    const blockedReel = await reel(blocked, 'blocked author');
    const blockerReel = await reel(blocker, 'author who blocked me');
    const hiddenReel = await reel(hiddenBy, 'hidden by me');
    await makePrivate(privateStranger);
    const privateReel = await reel(privateStranger, 'private stranger');
    const visible = await reel(friend, 'friend visible');
    await withMigrationClient(async (c) => {
      await c.userMute.create({ data: { muterId: me.id, mutedId: muted.id } });
      await c.userBlock.create({ data: { blockerId: me.id, blockedId: blocked.id } });
      await c.userBlock.create({ data: { blockerId: blocker.id, blockedId: me.id } });
      await c.postHide.create({ data: { userId: me.id, postId: hiddenReel } });
    });
    const feed = await all(me);
    const ids = feed.map((e) => e.id);
    expect(ids).toContain(visible);
    // Reels Following holds the caller's own reels (D162); the repost of it does not list it twice.
    expect(ids.filter((id) => id === mine)).toHaveLength(1);
    for (const gone of [mutedReel, blockedReel, blockerReel, hiddenReel, privateReel])
      expect(ids).not.toContain(gone);
  });

  it('pages a frozen snapshot: no repeats or skips, later reels do not shift it; the cursor is bound', async () => {
    const [me, friend] = [await signup(), await signup()];
    await follow(me, friend);
    await reel(friend, 'friend reel one');
    await reel(friend, 'friend reel two');
    const whole = await all(me, 50);
    const paged = await all(me, 3);
    expect(new Set(paged.map((e) => e.id)).size).toBe(paged.length);
    expect(paged.map((e) => e.id)).toEqual(whole.map((e) => e.id));

    const first = await mixed(me, 2);
    expect(first.body.page.hasMore).toBe(true);
    await reel(friend, 'after the snapshot');
    await reel(await signup(), 'trending after the snapshot');
    const second = await mixed(me, 2, first.body.page.nextCursor as string);
    const third = await mixed(me, 2, second.body.page.nextCursor as string);
    const pagedIds = [...first.body.data, ...second.body.data, ...third.body.data].map(
      (e: FeedEntry) => e.id,
    );
    expect(pagedIds).toEqual(whole.slice(0, 6).map((e) => e.id));
    // A new first page takes the new reel (a new snapshot).
    expect((await mixed(me, 1)).body.data[0].text).toBe('after the snapshot');

    const cursor = first.body.page.nextCursor as string;
    const bad = async (u: TestUser, path: string, tab: string) => {
      const res = await ctx.http.get(path).query({ tab, limit: 2, cursor }).set(auth(u));
      expect(res.status, `${path} ${tab}`).toBe(400);
      expect(res.body.error.details).toEqual([{ field: 'cursor', issue: 'invalid_value' }]);
      return res;
    };
    // Another caller's, another reels tab's and the posts mix's cursor scope → 400 cursor / invalid_value.
    expectContract(await bad(friend, '/api/v1/feed/reels', 'mixed'), 'listFeedReels');
    await bad(me, '/api/v1/feed/reels', 'trending');
    await bad(me, '/api/v1/feed/reels', 'following');
    expectContract(await bad(me, '/api/v1/feed/posts', 'mixed'), 'listFeedPosts');
    const postsCursor = (await get('/api/v1/feed/posts', me, 'mixed', 1)).body.page.nextCursor as
      string | null;
    if (postsCursor) {
      const res = await ctx.http
        .get('/api/v1/feed/reels')
        .query({ tab: 'mixed', limit: 2, cursor: postsCursor })
        .set(auth(me));
      expect(res.status).toBe(400);
    }
    // An expired snapshot (its key gone) → 400 too.
    const redis = ctx.app.get<Redis>(REDIS);
    const keys = await redis.keys(`*social:ranked:${me.id}:*`);
    expect(keys.length).toBeGreaterThan(0);
    await Promise.all(keys.map((k) => redis.del(k.replace(/^.*?(social:ranked:)/, '$1'))));
    const expired = await ctx.http
      .get('/api/v1/feed/reels')
      .query({ tab: 'mixed', limit: 2, cursor })
      .set(auth(me));
    expect(expired.status).toBe(400);
    expect(expired.body.error.details).toEqual([{ field: 'cursor', issue: 'invalid_value' }]);
    // Unknown tabs stay refused; anonymous callers get 401.
    expect((await ctx.http.get('/api/v1/feed/reels').query({ tab: 'foryou' }).set(auth(me))).status).toBe(
      400,
    );
    expect((await ctx.http.get('/api/v1/feed/reels').query({ tab: 'mixed' })).status).toBe(401);
  });

  it('following, trending, nearby and the posts mix are unchanged', async () => {
    const [me, friend, star, other] = [await signup(), await signup(), await signup(), await signup()];
    await follow(me, friend);
    const own = await reel(me, 'own');
    const f1 = await reel(friend, 'friend one');
    const f2 = await reel(friend, 'friend two');
    const hot = await reel(star, 'star reel');
    const fans = await Promise.all(Array.from({ length: 8 }, () => signup()));
    for (const u of [me, friend, other, ...fans])
      expect((await ctx.http.put(`/api/v1/posts/${hot}/like`).set(auth(u))).status).toBe(200);
    const friendPost = await textPost(friend, 'friend text');
    const myPost = await textPost(me, 'my text');

    // following: followed and own reels, newest first.
    expect((await all(me, 50, 'following')).map((e) => e.id)).toEqual([f2, f1, own]);
    // trending: public reels, never the caller's own; the most liked new reel first.
    const trending = (await all(me, 50, 'trending')).map((e) => e.id);
    expect(trending[0]).toBe(hot);
    expect(trending).not.toContain(own);
    expect(trending).toEqual(expect.arrayContaining([f1, f2]));
    // nearby: still served (a caller without a country gets an empty page).
    const nearby = await get('/api/v1/feed/reels', me, 'nearby', 20);
    expect(nearby.body).toEqual({ data: [], page: { hasMore: false, nextCursor: null } });
    // The posts mix: posts only, never the caller's own, the friend's post first.
    const posts = await all(me, 50, 'mixed', '/api/v1/feed/posts');
    expect(posts.every((e) => e.format === 'POST')).toBe(true);
    expect(posts[0]!.id).toBe(friendPost);
    expect(posts.map((e) => e.id)).not.toContain(myPost);
  });
});
