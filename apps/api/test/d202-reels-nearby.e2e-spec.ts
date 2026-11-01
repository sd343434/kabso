/**
 * D202 (v1.68-social, CONVENTIONS §11.15): the reels page's «Nearby» — `GET /feed/reels?tab=nearby`
 * lists visible public reels of authors from the caller's own country (D133 `Me.country`), newest
 * first, never the caller's own, private, muted, hidden or blocked; no country → an empty page; the
 * cursor is bound to the caller and the country. End to end against PostgreSQL + Redis with the API
 * as the DML-only runtime role; every response is checked against openapi.
 */
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
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

const MEDIA_ON = {
  MEDIA_UPLOADS_ENABLED: 'true',
  S3_BUCKET: 'kabso-media-test',
  S3_ACCESS_KEY_ID: 'test',
  S3_SECRET_ACCESS_KEY: 'test',
  MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
  RATE_LIMIT_MEDIA_UPLOAD_USER: '1000/3600',
  RATE_LIMIT_POST_CREATE_HOUR_USER: '1000/3600',
  RATE_LIMIT_POST_CREATE_DAY_USER: '1000/86400',
};

describe('D202 contract coverage', () => {
  it('openapi v1.68-social declares tab=nearby on listFeedReels only', () => {
    const reels = operations().find((o) => o.operationId === 'listFeedReels');
    const posts = operations().find((o) => o.operationId === 'listFeedPosts');
    const tab = (op: typeof reels) =>
      (op?.spec.parameters as { name: string; schema?: { enum?: string[] } }[] | undefined)?.find(
        (p) => p.name === 'tab',
      )?.schema?.enum;
    expect(tab(reels)).toEqual(['following', 'trending', 'nearby']);
    // v1.76-social (D218): listFeedPosts gained `mixed` (never `nearby`).
    expect(tab(posts)).toEqual(['following', 'trending', 'mixed']);
  });
});

describe('D202 reels nearby', () => {
  let ctx: TestContext;
  let storage: MemoryObjectStorage;
  let viewer: TestUser;
  let local1: TestUser;
  let local2: TestUser;
  let abroad: TestUser;
  let noCountry: TestUser;
  let privateLocal: TestUser;
  let mutedLocal: TestUser;
  let blockedLocal: TestUser;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
  };
  const setCountry = async (u: TestUser, country: string | null) => {
    const res = await ctx.http.patch('/api/v1/me').set(auth(u)).send({ country });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
  };
  const upload = async (u: TestUser, kind: string, bytes: Buffer, contentType: string) => {
    const s = await ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send({ kind, contentType, byteSize: bytes.length });
    expect(s.status, JSON.stringify(s.body)).toBe(201);
    expect(storage.upload(s.body.uploadUrl, bytes, contentType)).toBe(true);
    return s.body.uploadId as string;
  };
  const reel = async (u: TestUser, text: string): Promise<string> => {
    const video = await upload(
      u,
      'REEL_VIDEO',
      mp4({ durationMs: 6_000, width: 720, height: 1280 }),
      'video/mp4',
    );
    const posterUpload = await upload(
      u,
      'VIDEO_POSTER',
      await sharp({ create: { width: 540, height: 960, channels: 3, background: '#357' } })
        .jpeg()
        .toBuffer(),
      'image/jpeg',
    );
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
  const nearby = (u: TestUser, cursor?: string, limit = 20) =>
    ctx.http
      .get('/api/v1/feed/reels')
      .query({ tab: 'nearby', limit, ...(cursor ? { cursor } : {}) })
      .set(auth(u));
  const ids = (res: { body: { data: { id: string }[] } }) => res.body.data.map((p) => p.id);

  let r1: string;
  let r2: string;
  let r3: string;
  let rAbroad: string;
  let rNone: string;
  let rPrivate: string;
  let rMuted: string;
  let rBlocked: string;
  let rOwn: string;
  let rPost: string;

  beforeAll(async () => {
    storage = new MemoryObjectStorage();
    ctx = await createTestApp(MEDIA_ON, [{ token: OBJECT_STORAGE, value: storage }]);
    ctx.app.getHttpServer().setMaxListeners(64);
    viewer = await signup();
    local1 = await signup();
    local2 = await signup();
    abroad = await signup();
    noCountry = await signup();
    privateLocal = await signup();
    mutedLocal = await signup();
    blockedLocal = await signup();
    for (const u of [viewer, local1, local2, privateLocal, mutedLocal, blockedLocal])
      await setCountry(u, 'SA');
    await setCountry(abroad, 'EG');
    r1 = await reel(local1, 'first #nearby');
    rAbroad = await reel(abroad, 'from Egypt');
    r2 = await reel(local2, 'second');
    rNone = await reel(noCountry, 'no country');
    rPrivate = await reel(privateLocal, 'private');
    rMuted = await reel(mutedLocal, 'muted');
    rBlocked = await reel(blockedLocal, 'blocked');
    rOwn = await reel(viewer, 'my own');
    r3 = await reel(local1, 'third');
    // A plain post by a local author never shows in a reels list.
    const post = await ctx.http
      .post('/api/v1/posts')
      .set(auth(local2))
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'a text post' });
    expect(post.status).toBe(201);
    rPost = post.body.id as string;
    await withMigrationClient(async (c) => {
      await c.userSettings.upsert({
        where: { userId: privateLocal.id },
        create: { userId: privateLocal.id, isPrivate: true },
        update: { isPrivate: true },
      });
      await c.userMute.create({ data: { muterId: viewer.id, mutedId: mutedLocal.id } });
      await c.userBlock.create({ data: { blockerId: blockedLocal.id, blockedId: viewer.id } });
    });
  });
  afterAll(async () => ctx?.close());

  it('lists visible public reels of authors from the caller country, newest first', async () => {
    const res = await nearby(viewer);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listFeedReels');
    expect(ids(res)).toEqual([r3, r2, r1]);
    expect(res.body.data.every((p: { format: string }) => p.format === 'REEL')).toBe(true);
    expect(res.body.page).toEqual({ hasMore: false, nextCursor: null });
    for (const left of [rAbroad, rNone, rPrivate, rMuted, rBlocked, rOwn, rPost])
      expect(ids(res)).not.toContain(left);
  });

  it('a hidden reel leaves the list', async () => {
    const hide = await ctx.http.put(`/api/v1/posts/${r2}/hide`).set(auth(viewer));
    expect([200, 204]).toContain(hide.status);
    expect(ids(await nearby(viewer))).toEqual([r3, r1]);
    const unhide = await ctx.http.delete(`/api/v1/posts/${r2}/hide`).set(auth(viewer));
    expect([200, 204]).toContain(unhide.status);
    expect(ids(await nearby(viewer))).toEqual([r3, r2, r1]);
  });

  it('pages with a keyset cursor bound to the caller and the country', async () => {
    const first = await nearby(viewer, undefined, 2);
    expect(first.status).toBe(200);
    expectContract(first, 'listFeedReels');
    expect(ids(first)).toEqual([r3, r2]);
    expect(first.body.page.hasMore).toBe(true);
    const cursor = first.body.page.nextCursor as string;
    const second = await nearby(viewer, cursor, 2);
    expect(ids(second)).toEqual([r1]);
    expect(second.body.page).toEqual({ hasMore: false, nextCursor: null });
    // Another caller (same country) cannot reuse it.
    const foreign = await nearby(local2, cursor, 2);
    expect(foreign.status).toBe(400);
    expectContract(foreign, 'listFeedReels');
    expect(foreign.body.error.details).toEqual([{ field: 'cursor', issue: 'invalid_value' }]);
    // Nor a cursor from another list (following) — or after a country change.
    const following = await ctx.http
      .get('/api/v1/feed/reels')
      .query({ tab: 'following', cursor, limit: 2 })
      .set(auth(viewer));
    expect(following.status).toBe(400);
    await setCountry(viewer, 'EG');
    const moved = await nearby(viewer, cursor, 2);
    expect(moved.status).toBe(400);
    expect(moved.body.error.details).toEqual([{ field: 'cursor', issue: 'invalid_value' }]);
    expect(ids(await nearby(viewer))).toEqual([rAbroad]);
    await setCountry(viewer, 'SA');
  });

  it('a caller with no country gets an empty page', async () => {
    const res = await nearby(noCountry);
    expect(res.status).toBe(200);
    expectContract(res, 'listFeedReels');
    expect(res.body).toEqual({ data: [], page: { hasMore: false, nextCursor: null } });
  });

  it('the posts feed has no nearby; an unknown tab is refused', async () => {
    const posts = await ctx.http.get('/api/v1/feed/posts').query({ tab: 'nearby' }).set(auth(viewer));
    expect(posts.status).toBe(400);
    expectContract(posts, 'listFeedPosts');
    expect(posts.body.error.details).toEqual([{ field: 'tab', issue: 'invalid_value' }]);
    const bad = await ctx.http.get('/api/v1/feed/reels').query({ tab: 'world' }).set(auth(viewer));
    expect(bad.status).toBe(400);
    const anonymous = await ctx.http.get('/api/v1/feed/reels').query({ tab: 'nearby' });
    expect(anonymous.status).toBe(401);
  });

  it('like, save and share on a nearby reel use the post interactions and update the counts', async () => {
    const like = await ctx.http.put(`/api/v1/posts/${r1}/like`).set(auth(viewer));
    expect(like.status).toBe(200);
    expect(like.body).toMatchObject({ liked: true, likeCount: 1 });
    const save = await ctx.http.put(`/api/v1/posts/${r1}/save`).set(auth(viewer));
    expect([200, 204]).toContain(save.status);
    const share = await ctx.http.post(`/api/v1/posts/${r1}/shares`).set(auth(viewer));
    expect(share.status).toBe(200);
    expectContract(share, 'countPostShare');
    expect(share.body).toEqual({ shareCount: 1 });
    // Once per user, post and UTC day.
    expect((await ctx.http.post(`/api/v1/posts/${r1}/shares`).set(auth(viewer))).body).toEqual({
      shareCount: 1,
    });
    const page = await nearby(viewer);
    const item = page.body.data.find((p: { id: string }) => p.id === r1);
    expect(item).toMatchObject({ likeCount: 1, shareCount: 1, viewerHasLiked: true, viewerHasSaved: true });
  });
});
