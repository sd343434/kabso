/**
 * D162 (v1.41-social, CP-023, CONVENTIONS §11.14): video posts and reels — video uploads with a
 * phone-made poster, the server's container checks (no transcoding), posts with a video, reels and
 * the reels feed for Moments, end to end against PostgreSQL + Redis with the API as the DML-only
 * runtime role. Object storage is the in-memory double; every response is checked against openapi.
 */
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { MediaService } from '../src/modules/media/media.service.js';
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
  // Every video here needs two uploads (the file and its poster).
  RATE_LIMIT_MEDIA_UPLOAD_USER: '1000/3600',
  RATE_LIMIT_POST_CREATE_HOUR_USER: '1000/3600',
  RATE_LIMIT_POST_CREATE_DAY_USER: '1000/86400',
};

const MiB = 1024 * 1024;

describe('D162 contract coverage', () => {
  it('openapi v1.41-social declares the reels feed', () => {
    const ids = operations().map((o) => o.operationId);
    expect(ids).toContain('listFeedReels');
    expect(operations().find((o) => o.operationId === 'listFeedReels')?.path).toBe('/api/v1/feed/reels');
  });
});

describe('D162 video posts and reels', () => {
  let ctx: TestContext;
  let storage: MemoryObjectStorage;
  let alice: TestUser;
  let bob: TestUser;
  let carol: TestUser;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
  };
  const slot = (u: TestUser, body: unknown) =>
    ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send(body as object);
  const complete = (u: TestUser, uploadId: string, body?: unknown) => {
    const req = ctx.http.post(`/api/v1/media/uploads/${uploadId}/complete`).set(auth(u));
    return body === undefined ? req : req.send(body as object);
  };
  const image = (w: number, h: number) =>
    sharp({ create: { width: w, height: h, channels: 3, background: '#3a7' } })
      .jpeg()
      .toBuffer();
  const upload = async (u: TestUser, kind: string, bytes: Buffer, contentType: string) => {
    const s = await slot(u, { kind, contentType, byteSize: bytes.length });
    expect(s.status, JSON.stringify(s.body)).toBe(201);
    expect(storage.upload(s.body.uploadUrl, bytes, contentType)).toBe(true);
    return s.body.uploadId as string;
  };
  const poster = async (u: TestUser): Promise<string> => {
    const id = await upload(u, 'VIDEO_POSTER', await image(540, 960), 'image/jpeg');
    const done = await complete(u, id);
    expect(done.status).toBe(200);
    expectContract(done, 'completeMediaUpload');
    expect(done.body.type).toBe('IMAGE');
    return done.body.id as string;
  };
  const video = async (
    u: TestUser,
    kind: 'POST_VIDEO' | 'REEL_VIDEO',
    bytes: Buffer = mp4({ durationMs: 8_000, width: 1920, height: 1080, rotate90: true }),
    contentType = 'video/mp4',
  ) => {
    const uploadId = await upload(u, kind, bytes, contentType);
    const posterId = await poster(u);
    const res = await complete(u, uploadId, { posterId });
    return { res, uploadId, posterId };
  };
  const create = (u: TestUser, body: unknown) =>
    ctx.http
      .post('/api/v1/posts')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send(body as object);
  const feed = (u: TestUser, path: 'reels' | 'posts', tab: string, cursor?: string) =>
    ctx.http
      .get(`/api/v1/feed/${path}`)
      .query({ tab, ...(cursor ? { cursor } : {}), limit: 5 })
      .set(auth(u));
  const hold = (postId: string) =>
    withMigrationClient((c) => c.post.update({ where: { id: postId }, data: { moderation: 'PENDING' } }));
  const follow = (follower: TestUser, followee: TestUser) =>
    withMigrationClient((c) =>
      c.follow.create({ data: { followerId: follower.id, followeeId: followee.id } }),
    );

  beforeAll(async () => {
    storage = new MemoryObjectStorage();
    ctx = await createTestApp(MEDIA_ON, [{ token: OBJECT_STORAGE, value: storage }]);
    ctx.app.getHttpServer().setMaxListeners(64);
    alice = await signup();
    bob = await signup();
    carol = await signup();
  });
  afterAll(async () => ctx?.close());

  describe('upload slots', () => {
    it('takes video types for video kinds only, with each kind size limit', async () => {
      const cases: [unknown, string, string][] = [
        [{ kind: 'POST_IMAGE', contentType: 'video/mp4', byteSize: 10 }, 'contentType', 'invalid_value'],
        [{ kind: 'VIDEO_POSTER', contentType: 'video/mp4', byteSize: 10 }, 'contentType', 'invalid_value'],
        [{ kind: 'REEL_VIDEO', contentType: 'image/jpeg', byteSize: 10 }, 'contentType', 'invalid_value'],
        [{ kind: 'POST_VIDEO', contentType: 'audio/mp4', byteSize: 10 }, 'contentType', 'invalid_value'],
        [{ kind: 'DM_VOICE', contentType: 'video/mp4', byteSize: 10 }, 'contentType', 'invalid_value'],
        [
          { kind: 'REEL_VIDEO', contentType: 'video/x-matroska', byteSize: 10 },
          'contentType',
          'invalid_value',
        ],
        [{ kind: 'REEL_VIDEO', contentType: 'video/mp4', byteSize: 100 * MiB + 1 }, 'byteSize', 'too_big'],
        [{ kind: 'POST_VIDEO', contentType: 'video/mp4', byteSize: 200 * MiB + 1 }, 'byteSize', 'too_big'],
        [{ kind: 'POST_IMAGE', contentType: 'image/jpeg', byteSize: 15 * MiB + 1 }, 'byteSize', 'too_big'],
        [{ kind: 'VIDEO_POSTER', contentType: 'image/jpeg', byteSize: 15 * MiB + 1 }, 'byteSize', 'too_big'],
      ];
      for (const [body, field, issue] of cases) {
        const res = await slot(alice, body);
        expect(res.status, JSON.stringify(body)).toBe(400);
        expect(res.body.error.details, JSON.stringify(body)).toContainEqual({ field, issue });
        expectContract(res, 'createMediaUpload');
      }
      for (const body of [
        { kind: 'REEL_VIDEO', contentType: 'video/mp4', byteSize: 100 * MiB },
        { kind: 'POST_VIDEO', contentType: 'video/quicktime', byteSize: 200 * MiB },
      ]) {
        const res = await slot(alice, body);
        expect(res.status, JSON.stringify(body)).toBe(201);
        expectContract(res, 'createMediaUpload');
        // The signed headers bind the declared size and type (storage refuses anything else).
        expect(res.body.headers).toEqual({
          'Content-Type': body.contentType,
          'Content-Length': String(body.byteSize),
        });
      }
    });
  });

  describe('completing a video', () => {
    it('needs a poster of the caller: required, unknown for other kinds, invalid otherwise', async () => {
      const uploadId = await upload(alice, 'REEL_VIDEO', mp4({ durationMs: 5_000 }), 'video/mp4');
      const missing = await complete(alice, uploadId);
      expect(missing.status).toBe(400);
      expect(missing.body.error.details).toEqual([{ field: 'posterId', issue: 'required' }]);
      expectContract(missing, 'completeMediaUpload');
      const bobsPoster = await poster(bob);
      const foreign = await complete(alice, uploadId, { posterId: bobsPoster });
      expect(foreign.status).toBe(400);
      expect(foreign.body.error.details).toEqual([{ field: 'posterId', issue: 'invalid_value' }]);
      const photoId = await upload(alice, 'POST_IMAGE', await image(400, 300), 'image/jpeg');
      const photo = await complete(alice, photoId);
      expect(photo.status).toBe(200);
      const notPoster = await complete(alice, uploadId, { posterId: photo.body.id });
      expect(notPoster.status).toBe(400);
      expect(notPoster.body.error.details).toEqual([{ field: 'posterId', issue: 'invalid_value' }]);
      const malformed = await complete(alice, uploadId, { posterId: 'nope' });
      expect(malformed.status).toBe(400);
      expect(malformed.body.error.details).toContainEqual({ field: 'posterId', issue: 'invalid_format' });
      const extra = await complete(alice, uploadId, { posterId: bobsPoster, more: 1 });
      expect(extra.body.error.details).toContainEqual({ field: 'more', issue: 'unknown_field' });
      // An image upload refuses a poster.
      const otherPhoto = await upload(alice, 'POST_IMAGE', await image(400, 300), 'image/jpeg');
      const own = await poster(alice);
      const refused = await complete(alice, otherPhoto, { posterId: own });
      expect(refused.status).toBe(400);
      expect(refused.body.error.details).toEqual([{ field: 'posterId', issue: 'unknown_field' }]);
      // The slot stayed open: the right poster completes it.
      const done = await complete(alice, uploadId, { posterId: own });
      expect(done.status).toBe(200);
      expectContract(done, 'completeMediaUpload');
    });

    it('stores the file unchanged, takes the poster, and never reads the whole upload', async () => {
      const bytes = mp4({
        durationMs: 12_345,
        width: 1920,
        height: 1080,
        rotate90: true,
        dataBytes: 300_000,
      });
      const { res, uploadId, posterId } = await video(alice, 'REEL_VIDEO', bytes);
      expect(res.status).toBe(200);
      expectContract(res, 'completeMediaUpload');
      expect(res.body).toMatchObject({
        id: uploadId,
        type: 'VIDEO',
        status: 'READY',
        width: 1080,
        height: 1920,
        durationMs: 12_345,
        url: `https://media.example.test/media/${uploadId}/video.mp4`,
      });
      expect(res.body.thumbUrl).toMatch(
        new RegExp(`^https://media\\.example\\.test/media/${posterId}/320\\.webp$`),
      );
      expect(res.body.posterUrl).toMatch(
        new RegExp(`^https://media\\.example\\.test/media/${posterId}/1080\\.webp$`),
      );
      expect(res.body.blurhash).toEqual(expect.any(String));
      const stored = storage.objects.get(`media/${uploadId}/video.mp4`);
      expect(stored?.body.equals(bytes)).toBe(true);
      expect(stored?.contentType).toBe('video/mp4');
      expect(stored?.cacheControl).toContain('immutable');
      expect(storage.objects.has(`uploads/${alice.id}/${uploadId}`)).toBe(false);
      expect(storage.fullReads).not.toContain(`uploads/${alice.id}/${uploadId}`);
      // The poster no longer exists on its own; the video owns its objects.
      const gone = await ctx.http.get(`/api/v1/media/${posterId}`).set(auth(alice));
      expect(gone.status).toBe(404);
      const mine = await ctx.http.get(`/api/v1/media/${uploadId}`).set(auth(alice));
      expect(mine.status).toBe(200);
      expectContract(mine, 'getMedia');
      expect(mine.body.posterUrl).toBe(res.body.posterUrl);
      // Completing again returns the same asset (idempotent, even without the body).
      const again = await complete(alice, uploadId);
      expect(again.status).toBe(200);
      expect(again.body).toEqual(res.body);
    });

    it('stores QuickTime as .mov when the bytes say QuickTime', async () => {
      const { res, uploadId } = await video(
        alice,
        'POST_VIDEO',
        mp4({ durationMs: 80_000, brand: 'qt  ', codec: 'hvc1', width: 1280, height: 720 }),
        'video/quicktime',
      );
      expect(res.status).toBe(200);
      expect(res.body).toMatchObject({ type: 'VIDEO', width: 1280, height: 720, durationMs: 80_000 });
      expect(res.body.url).toBe(`https://media.example.test/media/${uploadId}/video.mov`);
      expect(storage.objects.get(`media/${uploadId}/video.mov`)?.contentType).toBe('video/quicktime');
    });

    it('refuses bad videos with 422 MEDIA_INVALID, deletes the object and keeps the poster', async () => {
      const bad: [string, Buffer, string][] = [
        ['REEL_VIDEO', mp4({ durationMs: 61_000 }), 'video/mp4'], // too long for a reel
        ['POST_VIDEO', mp4({ durationMs: 91_000 }), 'video/mp4'], // too long for a post (90 s since D168)
        ['REEL_VIDEO', mp4({ durationMs: 500 }), 'video/mp4'], // shorter than 1 s
        ['REEL_VIDEO', mp4({ durationMs: 5_000, noVideo: true }), 'video/mp4'], // audio only
        ['REEL_VIDEO', mp4({ durationMs: 5_000, codec: 'vp09' }), 'video/mp4'], // another codec
        ['REEL_VIDEO', mp4({ durationMs: 5_000, brand: 'qt  ' }), 'video/mp4'], // the bytes are QuickTime
        ['REEL_VIDEO', mp4({ durationMs: 5_000 }), 'video/quicktime'], // the bytes are MP4
        ['REEL_VIDEO', await image(64, 64), 'video/mp4'], // a picture
      ];
      for (const [kind, bytes, type] of bad) {
        const uploadId = await upload(alice, kind, bytes, type);
        const posterId = await poster(alice);
        const res = await complete(alice, uploadId, { posterId });
        expect(res.status, `${kind} ${type}`).toBe(422);
        expect(res.body.error.code).toBe('MEDIA_INVALID');
        expectContract(res, 'completeMediaUpload');
        expect(storage.objects.has(`uploads/${alice.id}/${uploadId}`)).toBe(false);
        expect([...storage.objects.keys()].some((k) => k.startsWith(`media/${uploadId}/`))).toBe(false);
        const stillThere = await ctx.http.get(`/api/v1/media/${posterId}`).set(auth(alice));
        expect(stillThere.status).toBe(200);
        const again = await complete(alice, uploadId, { posterId });
        expect(again.status).toBe(422);
      }
    });

    it('refuses bytes that differ from the declared size', async () => {
      const bytes = mp4({ durationMs: 5_000 });
      const s = await slot(alice, {
        kind: 'REEL_VIDEO',
        contentType: 'video/mp4',
        byteSize: bytes.length + 10,
      });
      expect(storage.upload(s.body.uploadUrl, bytes, 'video/mp4')).toBe(false);
      storage.putRaw(`uploads/${alice.id}/${s.body.uploadId}`, bytes, 'video/mp4');
      const res = await complete(alice, s.body.uploadId, { posterId: await poster(alice) });
      expect(res.status).toBe(422);
    });
  });

  describe('posts and reels', () => {
    it('a post takes photos or one video; a reel exactly one reel video', async () => {
      const postVideo = (await video(alice, 'POST_VIDEO')).res.body.id as string;
      const reelVideo = (await video(alice, 'REEL_VIDEO')).res.body.id as string;
      const photoUpload = await upload(alice, 'POST_IMAGE', await image(400, 300), 'image/jpeg');
      const photo = (await complete(alice, photoUpload)).body.id as string;
      const refusals: [unknown, string, string][] = [
        [{ format: 'REEL', text: 'no video' }, 'mediaIds', 'required'],
        [{ format: 'REEL', mediaIds: [postVideo] }, 'mediaIds', 'invalid_value'],
        [{ format: 'REEL', mediaIds: [photo] }, 'mediaIds', 'invalid_value'],
        [{ mediaIds: [reelVideo] }, 'mediaIds', 'invalid_value'],
        [{ mediaIds: [postVideo, photo] }, 'mediaIds', 'invalid_value'],
        [{ format: 'STORY', text: 'x' }, 'format', 'invalid_value'],
      ];
      for (const [body, field, issue] of refusals) {
        const res = await create(alice, body);
        expect(res.status, JSON.stringify(body)).toBe(400);
        expect(res.body.error.details, JSON.stringify(body)).toContainEqual({ field, issue });
        expectContract(res, 'createPost');
      }
      // A refused create claimed nothing: the same assets still attach.
      const post = await create(alice, { text: 'my video', mediaIds: [postVideo] });
      expect(post.status).toBe(201);
      expectContract(post, 'createPost');
      // D162a: media posts are visible at once (was PENDING under CP-006 Q2).
      expect(post.body).toMatchObject({ format: 'POST', moderation: 'VISIBLE' });
      expect(post.body.media[0]).toMatchObject({ id: postVideo, type: 'VIDEO' });
      const reel = await create(alice, { format: 'REEL', text: 'my reel #kabso', mediaIds: [reelVideo] });
      expect(reel.status).toBe(201);
      expectContract(reel, 'createPost');
      expect(reel.body).toMatchObject({ format: 'REEL', moderation: 'VISIBLE', hashtags: ['kabso'] });
      expect(reel.body.media[0]).toMatchObject({ id: reelVideo, type: 'VIDEO', durationMs: 8_000 });
      // An attached video cannot attach twice.
      const twice = await create(alice, { format: 'REEL', mediaIds: [reelVideo] });
      expect(twice.status).toBe(400);
      const read = await ctx.http.get(`/api/v1/posts/${reel.body.id}`).set(auth(alice));
      expect(read.status).toBe(200);
      expectContract(read, 'getPost');
      expect(read.body.format).toBe('REEL');
      // D162a: visible to others at once (was 404 under the CP-006 Q2 hold).
      const seen = await ctx.http.get(`/api/v1/posts/${reel.body.id}`).set(auth(bob));
      expect(seen.status).toBe(200);
    });

    it('the reels feed: following (with your own) and trending; posts feeds leave reels out', async () => {
      const maker = await signup();
      const viewer = await signup();
      await follow(viewer, maker);
      const reelId = (
        await create(maker, {
          format: 'REEL',
          text: 'public reel',
          mediaIds: [(await video(maker, 'REEL_VIDEO')).res.body.id],
        })
      ).body.id as string;
      const postId = (
        await create(maker, {
          text: 'video post',
          mediaIds: [(await video(maker, 'POST_VIDEO')).res.body.id],
        })
      ).body.id as string;
      const pendingReel = (
        await create(maker, {
          format: 'REEL',
          mediaIds: [(await video(maker, 'REEL_VIDEO')).res.body.id],
        })
      ).body.id as string;
      // D162a: posts are visible at once; one reel is put on hold (PENDING, as a future provider
      // or an admin would) to keep the author-only rule covered.
      await hold(pendingReel);

      const following = await feed(viewer, 'reels', 'following');
      expect(following.status).toBe(200);
      expectContract(following, 'listFeedReels');
      expect(following.body.data.map((p: { id: string }) => p.id)).toEqual([reelId]);
      expect(following.body.data[0].format).toBe('REEL');

      // The maker sees their own reels, the pending one included, newest first.
      const own = await feed(maker, 'reels', 'following');
      expect(own.body.data.map((p: { id: string }) => p.id)).toEqual([pendingReel, reelId]);
      expect(own.body.data[0].moderation).toBe('PENDING');

      const trending = await feed(carol, 'reels', 'trending');
      expect(trending.status).toBe(200);
      expectContract(trending, 'listFeedReels');
      const trendingIds = trending.body.data.map((p: { id: string }) => p.id);
      expect(trendingIds).toContain(reelId);
      expect(trendingIds).not.toContain(postId);
      expect(trendingIds).not.toContain(pendingReel);
      for (const p of trending.body.data) expect(p.format).toBe('REEL');

      const posts = await feed(viewer, 'posts', 'following');
      expect(posts.status).toBe(200);
      expectContract(posts, 'listFeedPosts');
      expect(posts.body.data.map((p: { id: string }) => p.id)).toEqual([postId]);
      const postsTrending = await feed(carol, 'posts', 'trending');
      expect(postsTrending.body.data.map((p: { id: string }) => p.id)).not.toContain(reelId);

      // Profile grids list both formats.
      const grid = await ctx.http.get(`/api/v1/users/${maker.username}/posts`).set(auth(viewer));
      expect(grid.status).toBe(200);
      expect(grid.body.data.map((p: { id: string }) => p.id).sort()).toEqual([reelId, postId].sort());
    });

    it('cursors are bound to their list', async () => {
      const maker = await signup();
      const viewer = await signup();
      await follow(viewer, maker);
      for (let i = 0; i < 6; i++) {
        const id = (
          await create(maker, { format: 'REEL', mediaIds: [(await video(maker, 'REEL_VIDEO')).res.body.id] })
        ).body.id as string;
        expect(id).toEqual(expect.any(String));
      }
      const first = await feed(viewer, 'reels', 'following');
      expect(first.body.data).toHaveLength(5);
      expect(first.body.page.hasMore).toBe(true);
      const cursor = first.body.page.nextCursor as string;
      const second = await feed(viewer, 'reels', 'following', cursor);
      expect(second.status).toBe(200);
      expect(second.body.data).toHaveLength(1);
      const foreign = await feed(viewer, 'posts', 'following', cursor);
      expect(foreign.status).toBe(400);
      expect(foreign.body.error.details).toEqual([{ field: 'cursor', issue: 'invalid_value' }]);
      const bad = await ctx.http.get('/api/v1/feed/reels').query({ tab: 'nearby' }).set(auth(viewer));
      expect(bad.status).toBe(400);
      expectContract(bad, 'listFeedReels');
      const anon = await ctx.http.get('/api/v1/feed/reels').query({ tab: 'following' });
      expect(anon.status).toBe(401);
    });
  });

  describe('D162a: media posts are visible at once', () => {
    it('the data migration makes held posts VISIBLE and leaves REMOVED ones alone', async () => {
      const a = (await create(carol, { text: 'held' })).body.id as string;
      const b = (await create(carol, { text: 'removed' })).body.id as string;
      await withMigrationClient(async (c) => {
        await c.post.update({ where: { id: a }, data: { moderation: 'PENDING' } });
        await c.post.update({ where: { id: b }, data: { moderation: 'REMOVED' } });
        const sql = readFileSync(
          new URL('../prisma/migrations/20261212090000_media_posts_visible/migration.sql', import.meta.url),
          'utf8',
        );
        await c.$executeRawUnsafe(sql.replace(/^--.*$/gm, '').trim());
      });
      const rows = await ctx.prisma.post.findMany({ where: { id: { in: [a, b] } } });
      expect(Object.fromEntries(rows.map((r) => [r.id, r.moderation]))).toEqual({
        [a]: 'VISIBLE',
        [b]: 'REMOVED',
      });
      expect((await ctx.http.get(`/api/v1/posts/${a}`).set(auth(bob))).status).toBe(200);
    });
  });

  describe('sweeper', () => {
    it('deletes a never-attached video with its file and both poster objects', async () => {
      const { res, posterId } = await video(carol, 'REEL_VIDEO');
      expect(res.status).toBe(200);
      const id = res.body.id as string;
      const keys = [`media/${id}/video.mp4`, `media/${posterId}/1080.webp`, `media/${posterId}/320.webp`];
      for (const k of keys) expect(storage.objects.has(k)).toBe(true);
      await withMigrationClient((c) =>
        c.mediaAsset.update({ where: { id }, data: { createdAt: new Date(Date.now() - 25 * 3600_000) } }),
      );
      await ctx.app.get(MediaService).sweep();
      for (const k of keys) expect(storage.objects.has(k)).toBe(false);
      const gone = await ctx.http.get(`/api/v1/media/${id}`).set(auth(carol));
      expect(gone.status).toBe(404);
    });
  });
});
