/**
 * KL-069 / CP-015 (D98): the host's live cover, reused by every live (openapi v1.11-live DRAFT,
 * CONVENTIONS §10.13, §11.1), end to end against PostgreSQL + Redis with the API as the DML-only
 * runtime role. Object storage is the in-memory test double behind the ObjectStorage port; the
 * media server is the in-memory fake behind the LiveMediaProvider port (it records the metadata).
 */
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

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
  LIVE_HOSTING_ENABLED: 'true',
};

describe('CP-015 contract coverage', () => {
  it('openapi declares setLiveCover and removeLiveCover on /me/live-cover', () => {
    expect(
      operations()
        .filter((o) => o.path === '/api/v1/me/live-cover')
        .map((o) => `${o.operationId} ${o.method.toUpperCase()}`)
        .sort(),
    ).toEqual(['removeLiveCover DELETE', 'setLiveCover PUT']);
  });
});

describe('CP-015 the live cover', () => {
  const media = new MemoryLiveMedia();
  let storage: MemoryObjectStorage;
  let ctx: TestContext;
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
  };
  const host = async (): Promise<TestUser> => {
    const u = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  const upload = async (u: TestUser, kind = 'LIVE_COVER', w = 1200, h = 800) => {
    const bytes = await sharp({
      create: { width: w, height: h, channels: 3, background: { r: 30, g: 120, b: 200 } },
    })
      .jpeg()
      .toBuffer();
    const slot = await ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send({ kind, contentType: 'image/jpeg', byteSize: bytes.length });
    expect(slot.status).toBe(201);
    storage.upload(slot.body.uploadUrl, bytes, 'image/jpeg');
    const done = await ctx.http.post(`/api/v1/media/uploads/${slot.body.uploadId}/complete`).set(auth(u));
    expect(done.status).toBe(200);
    return done.body as { id: string; url: string; thumbUrl: string; width: number; height: number };
  };
  const put = async (u: TestUser, body: unknown) => {
    const res = await ctx.http
      .put('/api/v1/me/live-cover')
      .set(auth(u))
      .send(body as object);
    expectContract(res, 'setLiveCover');
    return res;
  };
  const remove = async (u: TestUser) => {
    const res = await ctx.http.delete('/api/v1/me/live-cover').set(auth(u));
    expectContract(res, 'removeLiveCover');
    return res;
  };
  const me = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getMe');
    return res.body as { liveCoverUrl: string | null };
  };
  const goLive = async (u: TestUser): Promise<{ id: string; coverUrl: string | null }> => {
    const res = await ctx.http.post('/api/v1/live/rooms').set(auth(u)).send({ title: 'Cover' });
    expect(res.status).toBe(201);
    expectContract(res, 'startLiveRoom');
    return res.body as { id: string; coverUrl: string | null };
  };
  const room = async (roomId: string) => {
    const res = await ctx.http.get(`/api/v1/live/rooms/${roomId}`);
    expect(res.status).toBe(200);
    expectContract(res, 'getLiveRoom');
    return res.body as { coverUrl: string | null };
  };
  const infoVersion = async (roomId: string) =>
    (await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).infoVersion;
  const keyOf = (url: string) => url.replace('https://media.example.test/', '');

  beforeAll(async () => {
    storage = new MemoryObjectStorage();
    ctx = await createTestApp(MEDIA_ON, [
      { token: OBJECT_STORAGE, value: storage },
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
  });
  afterAll(async () => ctx?.close());

  it('a LIVE_COVER is a centre-cropped square: 640 px and a 320 px thumb, never enlarged', async () => {
    const u = await host();
    const big = await upload(u, 'LIVE_COVER', 1200, 800);
    expect(big.url).toMatch(/\/640\.webp$/);
    expect([big.width, big.height]).toEqual([640, 640]);
    const thumb = await sharp(storage.objects.get(keyOf(big.thumbUrl))!.body).metadata();
    expect([thumb.width, thumb.height]).toEqual([320, 320]);
    const small = await upload(u, 'LIVE_COVER', 500, 900);
    expect([small.width, small.height]).toEqual([500, 500]);
  });

  it('sets the cover: Me shows it, the next live carries it, the old asset is deleted', async () => {
    const u = await host();
    expect((await me(u)).liveCoverUrl).toBeNull();
    const first = await upload(u);
    const set = await put(u, { mediaId: first.id });
    expect(set.status).toBe(200);
    expect(set.body).toEqual({ coverUrl: first.url });
    expect((await me(u)).liveCoverUrl).toBe(first.url);
    // Setting the same cover again changes nothing.
    expect((await put(u, { mediaId: first.id })).body).toEqual({ coverUrl: first.url });

    const second = await upload(u);
    expect((await put(u, { mediaId: second.id })).body).toEqual({ coverUrl: second.url });
    expect(await ctx.prisma.mediaAsset.count({ where: { id: first.id } })).toBe(0);
    expect(storage.objects.has(keyOf(first.url))).toBe(false);
    expect(storage.objects.has(keyOf(first.thumbUrl))).toBe(false);
    expect(storage.objects.has(keyOf(second.url))).toBe(true);
    // The replaced asset is gone, so it cannot be set again.
    const stale = await put(u, { mediaId: first.id });
    expect(stale.status).toBe(400);
    expect(stale.body.error.details).toEqual([{ field: 'mediaId', issue: 'invalid_value' }]);

    const live = await goLive(u);
    expect(live.coverUrl).toBe(second.url);
    expect((await room(live.id)).coverUrl).toBe(second.url);
    const hub = await ctx.http.get('/api/v1/live/rooms?tab=new');
    expect(hub.status).toBe(200);
    expectContract(hub, 'listLiveRooms');
    expect(hub.body.data.find((r: { id: string }) => r.id === live.id)?.coverUrl).toBe(second.url);
  });

  it('a change while live updates the room, bumps roomInfoVersion and the metadata; audited', async () => {
    const u = await host();
    const live = await goLive(u);
    expect(live.coverUrl).toBeNull();
    expect(await infoVersion(live.id)).toBe(0);
    const cover = await upload(u);
    expect((await put(u, { mediaId: cover.id })).status).toBe(200);
    expect((await room(live.id)).coverUrl).toBe(cover.url);
    expect(await infoVersion(live.id)).toBe(1);
    expect(JSON.parse(media.metadata.get(live.id) ?? '{}')).toMatchObject({ roomInfoVersion: 1 });

    const removed = await remove(u);
    expect(removed.status).toBe(204);
    expect((await room(live.id)).coverUrl).toBeNull();
    expect(await infoVersion(live.id)).toBe(2);
    expect((await me(u)).liveCoverUrl).toBeNull();
    expect(await ctx.prisma.mediaAsset.count({ where: { id: cover.id } })).toBe(0);
    // Idempotent: nothing to remove → 204, no new version.
    expect((await remove(u)).status).toBe(204);
    expect(await infoVersion(live.id)).toBe(2);

    const audit = await ctx.prisma.auditLog.findMany({
      where: { action: 'live.cover.update', actorUserId: u.id },
      orderBy: { createdAt: 'asc' },
    });
    expect(audit.map((a) => a.metadata)).toEqual([
      { cover: 'set', roomId: live.id, infoVersion: 1 },
      { cover: 'removed', roomId: live.id, infoVersion: 2 },
    ]);
  });

  it('refuses: no permission → 403; another kind, someone else’s or unknown asset → 400; strict body', async () => {
    const plain = await signup();
    const refused = await put(plain, { mediaId: randomUUID() });
    expect(refused.status).toBe(403);
    expect(refused.body.error.code).toBe('LIVE_HOSTING_NOT_ALLOWED');
    expect((await remove(plain)).status).toBe(403);

    const u = await host();
    const other = await host();
    const post = await upload(u, 'POST_IMAGE');
    const theirs = await upload(other);
    for (const mediaId of [post.id, theirs.id, randomUUID()]) {
      const res = await put(u, { mediaId });
      expect(res.status).toBe(400);
      expect(res.body.error.details).toEqual([{ field: 'mediaId', issue: 'invalid_value' }]);
    }
    expect((await put(u, { mediaId: 'nope' })).status).toBe(400);
    const extra = await put(u, { mediaId: theirs.id, url: 'x' });
    expect(extra.status).toBe(400);
    // A cover never attaches to a post.
    const cover = await upload(u);
    const asPost = await ctx.http
      .post('/api/v1/posts')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({ mediaIds: [cover.id] });
    expect(asPost.status).toBe(400);
    expect(asPost.body.error.details).toEqual([{ field: 'mediaIds', issue: 'invalid_value' }]);
  });
});

describe('CP-015 with uploads off', () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true' });
  });
  afterAll(async () => ctx?.close());

  it('PUT → 503 MEDIA_UPLOADS_UNAVAILABLE; DELETE still works', async () => {
    const { res } = await registerVerified(ctx);
    const token = res.body.tokens.accessToken as string;
    await ctx.prisma.liveHost.create({ data: { userId: res.body.user.id, source: 'ADMIN' } });
    const put = await ctx.http
      .put('/api/v1/me/live-cover')
      .set({ Authorization: `Bearer ${token}` })
      .send({ mediaId: randomUUID() });
    expect(put.status).toBe(503);
    expect(put.body.error.code).toBe('MEDIA_UPLOADS_UNAVAILABLE');
    expectContract(put, 'setLiveCover');
    const del = await ctx.http.delete('/api/v1/me/live-cover').set({ Authorization: `Bearer ${token}` });
    expect(del.status).toBe(204);
  });
});

describe('CP-015 rate limit', () => {
  it('PUT and DELETE share 30 / hour / user (here 2)', async () => {
    const ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', RATE_LIMIT_LIVE_COVER_USER: '2/3600' });
    try {
      const { res } = await registerVerified(ctx);
      const auth = { Authorization: `Bearer ${res.body.tokens.accessToken as string}` };
      await ctx.prisma.liveHost.create({ data: { userId: res.body.user.id, source: 'ADMIN' } });
      expect((await ctx.http.delete('/api/v1/me/live-cover').set(auth)).status).toBe(204);
      expect((await ctx.http.delete('/api/v1/me/live-cover').set(auth)).status).toBe(204);
      const limited = await ctx.http.delete('/api/v1/me/live-cover').set(auth);
      expect(limited.status).toBe(429);
    } finally {
      await ctx.close();
    }
  });
});
