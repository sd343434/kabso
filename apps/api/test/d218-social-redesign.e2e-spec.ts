/**
 * D218 (v1.76-social, CONVENTIONS §10.73): the owner's social redesign, end to end against PostgreSQL + Redis with
 * the API as the DML-only runtime role — the home feed `GET /feed/posts?tab=mixed` (1 Following : 2 Trending,
 * exhaustion, no duplicates, own / muted / hidden / blocked left out, a frozen snapshot), `Post.viewerFollowsAuthor`,
 * the profile cover (`PROFILE_COVER`, `PUT` / `DELETE /me/cover`, `Me.coverUrl`, `PublicProfile.coverUrl`, the
 * moderator's removal) and `PublicProfile.country` / `joinedMonth`. Object storage is the in-memory double; every
 * response is checked against openapi.
 */
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { removeCoverByAdminIn } from '../src/modules/users/avatar-admin.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
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

describe('D218 contract coverage', () => {
  it('openapi v1.76-social declares tab=mixed, the cover operations and the panel removal', () => {
    const tab = operations().find((o) => o.operationId === 'listFeedPosts')?.spec.parameters as
      { name: string; schema?: { enum?: string[] } }[] | undefined;
    expect(tab?.find((p) => p.name === 'tab')?.schema?.enum).toEqual(['following', 'trending', 'mixed']);
    expect(
      operations()
        .filter(
          (o) => o.path === '/api/v1/me/cover' || o.path === '/api/v1/admin/users/{userId}/cover/remove',
        )
        .map((o) => `${o.operationId} ${o.method.toUpperCase()}`)
        .sort(),
    ).toEqual(['removeAdminUserCover POST', 'removeMyCover DELETE', 'setMyCover PUT']);
  });
});

describe('D218 social redesign', { timeout: 120_000 }, () => {
  let storage: MemoryObjectStorage;
  let ctx: TestContext;
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
  };
  const post = async (u: TestUser, text: string): Promise<string> => {
    const res = await ctx.http
      .post('/api/v1/posts')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({ text });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const follow = (follower: TestUser, followee: TestUser) =>
    withMigrationClient((c) =>
      c.follow.create({ data: { followerId: follower.id, followeeId: followee.id } }),
    );
  const mixed = async (u: TestUser, limit: number, cursor?: string | null): Promise<request.Response> => {
    const res = await ctx.http
      .get(`/api/v1/feed/posts?tab=mixed&limit=${limit}${cursor ? `&cursor=${cursor}` : ''}`)
      .set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listFeedPosts');
    return res;
  };
  /** Every entry of the caller's mixed feed, page by page (`limit` per page). */
  const all = async (u: TestUser, limit = 50): Promise<FeedEntry[]> => {
    const out: FeedEntry[] = [];
    let cursor: string | null = null;
    for (let i = 0; i < 200; i += 1) {
      const res = await mixed(u, limit, cursor);
      out.push(...(res.body.data as FeedEntry[]));
      cursor = res.body.page.nextCursor as string | null;
      if (!res.body.page.hasMore) break;
    }
    return out;
  };
  /** F: a Following entry (a followed author, or a repost by a followed account); T: Trending. */
  const source = (e: FeedEntry) => (e.viewerFollowsAuthor || e.repostedBy !== null ? 'F' : 'T');

  beforeAll(async () => {
    storage = new MemoryObjectStorage();
    ctx = await createTestApp(MEDIA_ON, [{ token: OBJECT_STORAGE, value: storage }]);
  });
  afterAll(async () => ctx?.close());

  describe('the home feed tab=mixed', () => {
    it('is 1 Following : 2 Trending; Trending continues alone when Following runs out; each post once', async () => {
      const [me, friend1, friend2] = [await signup(), await signup(), await signup()];
      await follow(me, friend1);
      await follow(me, friend2);
      const f1 = await post(friend1, 'friend one');
      const f2 = await post(friend2, 'friend two');
      const strangers = await Promise.all(Array.from({ length: 6 }, () => signup()));
      const trending: string[] = [];
      for (const s of strangers) trending.push(await post(s, `stranger ${s.username}`));

      const feed = await all(me);
      const ids = feed.map((e) => e.id);
      expect(new Set(ids).size).toBe(ids.length);
      expect(ids).toEqual(expect.arrayContaining([f1, f2, ...trending]));
      // Following newest first at places 0 and 3, Trending in between, then Trending alone.
      expect(ids[0]).toBe(f2);
      expect(ids[3]).toBe(f1);
      const pattern = feed.map(source).join('');
      expect(pattern.startsWith('FTTFTT')).toBe(true);
      expect(pattern.slice(4)).not.toContain('F');
      // The «متابعة» pill's data: followed authors true, others false.
      expect(feed[0]!.viewerFollowsAuthor).toBe(true);
      expect(feed[1]!.viewerFollowsAuthor).toBe(false);
    });

    it('Following continues alone when Trending runs out (a private author is never Trending)', async () => {
      const me = await signup();
      const authors = await Promise.all(Array.from({ length: 3 }, () => signup()));
      const followed: string[] = [];
      for (const a of authors) {
        await follow(me, a);
        await withMigrationClient((c) =>
          c.userSettings.upsert({
            where: { userId: a.id },
            create: { userId: a.id, isPrivate: true },
            update: { isPrivate: true },
          }),
        );
        followed.push(await post(a, `private ${a.username}`));
      }
      const feed = await all(me);
      // Their posts are Following only; once Trending (the rest of the database) is exhausted no F is lost.
      const fPositions = followed.map((id) => feed.findIndex((e) => e.id === id));
      expect(fPositions.every((i) => i >= 0)).toBe(true);
      expect(fPositions).toEqual([...fPositions].sort((x, y) => y - x)); // newest first
      expect(fPositions.sort((x, y) => x - y)[0]).toBe(0);
    });

    it('never lists the caller own posts (also when reposted), muted, hidden or blocked authors', async () => {
      const [me, friend, muted, blocked, blocker, hiddenBy] = [
        await signup(),
        await signup(),
        await signup(),
        await signup(),
        await signup(),
        await signup(),
      ];
      await follow(me, friend);
      const mine = await post(me, 'my own');
      expect((await ctx.http.put(`/api/v1/posts/${mine}/repost`).set(auth(friend))).status).toBe(200);
      const mutedPost = await post(muted, 'muted author');
      const blockedPost = await post(blocked, 'blocked author');
      const blockerPost = await post(blocker, 'author who blocked me');
      const hiddenPost = await post(hiddenBy, 'hidden by me');
      const visible = await post(friend, 'friend visible');
      await withMigrationClient(async (c) => {
        await c.userMute.create({ data: { muterId: me.id, mutedId: muted.id } });
        await c.userBlock.create({ data: { blockerId: me.id, blockedId: blocked.id } });
        await c.userBlock.create({ data: { blockerId: blocker.id, blockedId: me.id } });
        await c.postHide.create({ data: { userId: me.id, postId: hiddenPost } });
      });
      const ids = (await all(me)).map((e) => e.id);
      expect(ids).toContain(visible);
      for (const gone of [mine, mutedPost, blockedPost, blockerPost, hiddenPost])
        expect(ids).not.toContain(gone);
    });

    it('pages a frozen snapshot: no repeats or skips, later posts do not shift it; the cursor is bound', async () => {
      const [me, friend] = [await signup(), await signup()];
      await follow(me, friend);
      const reposted = await post(await signup(), 'reposted by friend');
      await ctx.http.put(`/api/v1/posts/${reposted}/repost`).set(auth(friend));
      await post(friend, 'friend post');
      const whole = await all(me, 50);
      const paged = await all(me, 3);
      expect(new Set(paged.map((e) => e.id)).size).toBe(paged.length);
      // The first two entries are Following (newest first): the friend's post, then the repost with its label.
      expect(paged[0]!.author.id).toBe(friend.id);
      expect(paged.find((e) => e.id === reposted)?.repostedBy?.id).toBe(friend.id);
      expect(paged.slice(0, 4).map(source).join('')).toBe(whole.slice(0, 4).map(source).join(''));

      const first = await mixed(me, 2);
      expect(first.body.page.hasMore).toBe(true);
      await post(friend, 'after the snapshot');
      await post(await signup(), 'trending after the snapshot');
      const second = await mixed(me, 2, first.body.page.nextCursor as string);
      const third = await mixed(me, 2, second.body.page.nextCursor as string);
      const pagedIds = [...first.body.data, ...second.body.data, ...third.body.data].map(
        (e: FeedEntry) => e.id,
      );
      expect(pagedIds).toEqual(paged.slice(0, 6).map((e) => e.id));

      // Another caller's or another tab's cursor → 400 cursor / invalid_value.
      const foreign = await ctx.http
        .get(`/api/v1/feed/posts?tab=mixed&limit=2&cursor=${first.body.page.nextCursor}`)
        .set(auth(friend));
      expect(foreign.status).toBe(400);
      expectContract(foreign, 'listFeedPosts');
      expect(foreign.body.error.details).toEqual([{ field: 'cursor', issue: 'invalid_value' }]);
      const otherTab = await ctx.http
        .get(`/api/v1/feed/posts?tab=trending&limit=2&cursor=${first.body.page.nextCursor}`)
        .set(auth(me));
      expect(otherTab.status).toBe(400);
      // v1.92-social (D294): the reels feed has its own `mixed` (d294-reels-mixed); the posts mix's cursor is
      // not valid there.
      expect((await ctx.http.get('/api/v1/feed/reels?tab=mixed').set(auth(me))).status).toBe(200);
      const reelsWithPostsCursor = await ctx.http
        .get(`/api/v1/feed/reels?tab=mixed&limit=2&cursor=${first.body.page.nextCursor}`)
        .set(auth(me));
      expect(reelsWithPostsCursor.status).toBe(400);
      expect(reelsWithPostsCursor.body.error.details).toEqual([{ field: 'cursor', issue: 'invalid_value' }]);
    });

    it('a post that is also Trending is listed once, at its Following place', async () => {
      const [me, friend] = [await signup(), await signup()];
      await follow(me, friend);
      const hot = await post(friend, 'friend hot post');
      const fans = await Promise.all(Array.from({ length: 4 }, () => signup()));
      for (const fan of fans) await ctx.http.put(`/api/v1/posts/${hot}/like`).set(auth(fan));
      const feed = await all(me);
      expect(feed.filter((e) => e.id === hot)).toHaveLength(1);
      expect(feed[0]!.id).toBe(hot);
    });
  });

  describe('the profile cover', () => {
    const image = (w: number, h: number) =>
      sharp({ create: { width: w, height: h, channels: 3, background: { r: 30, g: 90, b: 200 } } })
        .jpeg()
        .toBuffer();
    const upload = async (u: TestUser, kind: string, w = 1600, h = 900) => {
      const bytes = await image(w, h);
      const s = await ctx.http
        .post('/api/v1/media/uploads')
        .set(auth(u))
        .send({ kind, contentType: 'image/jpeg', byteSize: bytes.length });
      expect(s.status, JSON.stringify(s.body)).toBe(201);
      expectContract(s, 'createMediaUpload');
      expect(storage.upload(s.body.uploadUrl, bytes, 'image/jpeg')).toBe(true);
      const done = await ctx.http.post(`/api/v1/media/uploads/${s.body.uploadId}/complete`).set(auth(u));
      expect(done.status).toBe(200);
      expectContract(done, 'completeMediaUpload');
      return done.body as { id: string; url: string; width: number; height: number };
    };
    const putCover = async (u: TestUser, body: unknown) => {
      const res = await ctx.http
        .put('/api/v1/me/cover')
        .set(auth(u))
        .send(body as object);
      expectContract(res, 'setMyCover');
      return res;
    };
    const profileOf = async (viewer: TestUser, of: TestUser) => {
      const res = await ctx.http.get(`/api/v1/users/${of.username}`).set(auth(viewer));
      expect(res.status).toBe(200);
      expectContract(res, 'getPublicProfile');
      return res.body as { coverUrl: string | null; country: string | null; joinedMonth: string };
    };
    const meOf = async (u: TestUser) => {
      const res = await ctx.http.get('/api/v1/me').set(auth(u));
      expectContract(res, 'getMe');
      return res.body as { coverUrl: string | null };
    };
    const keyOf = (url: string) => url.replace('https://media.example.test/', '');

    it('sets a PROFILE_COVER (not cropped), replaces it (old files deleted) and removes it; audited', async () => {
      const [u, viewer] = [await signup(), await signup()];
      expect((await meOf(u)).coverUrl).toBeNull();
      expect((await profileOf(viewer, u)).coverUrl).toBeNull();
      const cover = await upload(u, 'PROFILE_COVER');
      // Processed like a post image: the long side ≤ 1 080, the aspect kept.
      expect(cover.width).toBe(1080);
      expect(cover.height).toBe(608);
      const set = await putCover(u, { mediaId: cover.id });
      expect(set.status).toBe(200);
      expect(set.body).toEqual({ coverUrl: cover.url });
      expect((await meOf(u)).coverUrl).toBe(cover.url);
      expect((await profileOf(viewer, u)).coverUrl).toBe(cover.url);
      // Again: nothing changes.
      expect((await putCover(u, { mediaId: cover.id })).body).toEqual({ coverUrl: cover.url });

      const next = await upload(u, 'PROFILE_COVER', 900, 1200);
      expect((await putCover(u, { mediaId: next.id })).status).toBe(200);
      expect(storage.objects.has(keyOf(cover.url))).toBe(false);
      expect(await ctx.prisma.mediaAsset.findUnique({ where: { id: cover.id } })).toBeNull();

      const removed = await ctx.http.delete('/api/v1/me/cover').set(auth(u));
      expect(removed.status).toBe(204);
      expectContract(removed, 'removeMyCover');
      expect((await profileOf(viewer, u)).coverUrl).toBeNull();
      expect(storage.objects.has(keyOf(next.url))).toBe(false);
      expect((await ctx.http.delete('/api/v1/me/cover').set(auth(u))).status).toBe(204);
      const audits = await ctx.prisma.auditLog.findMany({
        where: { actorUserId: u.id, action: 'user.cover.update' },
        orderBy: { createdAt: 'asc' },
      });
      expect(audits.map((a) => (a.metadata as { cover: string }).cover)).toEqual(['set', 'set', 'removed']);
    });

    it('refuses another kind, another user’s asset, an attached one and a malformed body', async () => {
      const [u, other] = [await signup(), await signup()];
      const avatar = await upload(u, 'AVATAR');
      const bad = await putCover(u, { mediaId: avatar.id });
      expect(bad.status).toBe(400);
      expect(bad.body.error.details).toEqual([{ field: 'mediaId', issue: 'invalid_value' }]);
      const theirs = await upload(other, 'PROFILE_COVER');
      expect((await putCover(u, { mediaId: theirs.id })).status).toBe(400);
      expect((await putCover(other, { mediaId: theirs.id })).status).toBe(200);
      expect((await putCover(u, { mediaId: theirs.id })).status).toBe(400);
      expect((await putCover(u, { mediaId: 'nope' })).status).toBe(400);
      expect((await putCover(u, { mediaId: theirs.id, extra: 1 })).status).toBe(400);
      // A cover can never be used as an avatar.
      const mine = await upload(u, 'PROFILE_COVER');
      expect((await ctx.http.put('/api/v1/me/avatar').set(auth(u)).send({ mediaId: mine.id })).status).toBe(
        400,
      );
    });

    it('a moderator removes it: the user is told (COVER_REMOVED), audited, files deleted after', async () => {
      const u = await signup();
      const cover = await upload(u, 'PROFILE_COVER');
      expect((await putCover(u, { mediaId: cover.id })).status).toBe(200);
      const result = await withMigrationClient((c) =>
        c.$transaction((tx) => removeCoverByAdminIn(tx, u.username, 'violates the rules')),
      );
      expect(result.outcome).toBe('removed');
      expect((await meOf(u)).coverUrl).toBeNull();
      const notes = await ctx.http.get('/api/v1/notifications').set(auth(u));
      expect(notes.status).toBe(200);
      expectContract(notes, 'listNotifications');
      expect(notes.body.data.map((n: { type: string }) => n.type)).toContain('COVER_REMOVED');
      const audit = await ctx.prisma.auditLog.findFirst({
        where: { action: 'admin.cover.remove', targetId: u.id },
      });
      expect(audit?.metadata).toMatchObject({ username: u.username, reason: 'violates the rules' });
      expect(
        await withMigrationClient((c) =>
          c.$transaction((tx) => removeCoverByAdminIn(tx, u.username, 'again')),
        ),
      ).toEqual({ outcome: 'no_cover', userId: u.id });
    });
  });

  describe('the public profile row «الدولة · انضم في»', () => {
    it('carries the chosen country (or null) and the month joined, never the exact time', async () => {
      const [u, viewer] = [await signup(), await signup()];
      const before = await ctx.http.get(`/api/v1/users/${u.username}`).set(auth(viewer));
      expectContract(before, 'getPublicProfile');
      expect(before.body.country).toBeNull();
      const created = await ctx.prisma.user.findUniqueOrThrow({ where: { id: u.id } });
      expect(before.body.joinedMonth).toBe(created.createdAt.toISOString().slice(0, 7));
      expect(JSON.stringify(before.body)).not.toContain(created.createdAt.toISOString());
      expect((await ctx.http.patch('/api/v1/me').set(auth(u)).send({ country: 'JO' })).status).toBe(200);
      const after = await ctx.http.get(`/api/v1/users/${u.username}`).set(auth(viewer));
      expect(after.body.country).toBe('JO');
    });

    it('blockedByMe: only the caller sees their own block (the profile offers «إلغاء الحظر»)', async () => {
      const [me, them] = [await signup(), await signup()];
      const read = async (viewer: TestUser, of: TestUser) => {
        const res = await ctx.http.get(`/api/v1/users/${of.username}`).set(auth(viewer));
        expect(res.status).toBe(200);
        expectContract(res, 'getPublicProfile');
        return res.body.blockedByMe as boolean;
      };
      expect(await read(me, them)).toBe(false);
      expect((await ctx.http.put(`/api/v1/users/${them.username}/block`).set(auth(me))).status).toBe(200);
      expect(await read(me, them)).toBe(true);
      expect(await read(them, me)).toBe(false);
      expect(await read(me, me)).toBe(false);
      expect((await ctx.http.delete(`/api/v1/users/${them.username}/block`).set(auth(me))).status).toBe(200);
      expect(await read(me, them)).toBe(false);
    });
  });

  describe('Post.viewerFollowsAuthor', () => {
    it('is true for a followed author, false otherwise and on the caller own post', async () => {
      const [me, friend, stranger] = [await signup(), await signup(), await signup()];
      await follow(me, friend);
      const a = await post(friend, 'a');
      const b = await post(stranger, 'b');
      const c = await post(me, 'c');
      const read = async (id: string) => {
        const res = await ctx.http.get(`/api/v1/posts/${id}`).set(auth(me));
        expectContract(res, 'getPost');
        return res.body.viewerFollowsAuthor as boolean;
      };
      expect([await read(a), await read(b), await read(c)]).toEqual([true, false, false]);
    });
  });
});
