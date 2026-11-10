/**
 * D353 (owner, staging 8ddbbfb: «المستخدمين لا يمكنهم رفع/وضع صورة غلاف، يظهر خطأ»): the profile cover as a regular
 * user does it from the app (CONVENTIONS §10.73.3), end to end against PostgreSQL + Redis with the API as the
 * DML-only runtime role — `POST /media/uploads` (`PROFILE_COVER`) → the presigned PUT → `complete` → `PUT /me/cover`
 * → `GET /me` and `GET /users/{username}` show `coverUrl`; for each picture the app sends (the picker's JPEG at
 * 2 160 px / q90, a PNG, a WebP, a portrait photo, a 4 032 × 3 024 camera JPEG). No owner or staff right is needed;
 * the founder's cover video stays the owner's only. Object storage is the in-memory double; every response is
 * checked against openapi.
 */
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract } from './helpers/openapi.js';
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
  RATE_LIMIT_MEDIA_UPLOAD_USER: '1000/3600',
};

type Format = 'jpeg' | 'png' | 'webp';

describe('D353 a regular user sets the profile cover', { timeout: 120_000 }, () => {
  let storage: MemoryObjectStorage;
  let ctx: TestContext;
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
  };
  const picture = (w: number, h: number, format: Format) => {
    const img = sharp({ create: { width: w, height: h, channels: 3, background: { r: 200, g: 40, b: 60 } } });
    return (
      format === 'png' ? img.png() : format === 'webp' ? img.webp() : img.jpeg({ quality: 90 })
    ).toBuffer();
  };

  beforeAll(async () => {
    storage = new MemoryObjectStorage();
    ctx = await createTestApp(MEDIA_ON, [{ token: OBJECT_STORAGE, value: storage }]);
  });
  afterAll(async () => ctx?.close());

  it.each([
    ['the picker JPEG (2 160 × 1 620, q90)', 2160, 1620, 'jpeg', 1080, 810],
    ['a PNG', 1500, 500, 'png', 1080, 360],
    ['a WebP', 1200, 900, 'webp', 1080, 810],
    ['a portrait photo', 1620, 2160, 'jpeg', 810, 1080],
    ['a camera JPEG (4 032 × 3 024)', 4032, 3024, 'jpeg', 1080, 810],
  ] as const)(
    '%s: upload → complete → PUT /me/cover → shown on GET /me and the profile',
    async (_, w, h, format, ow, oh) => {
      const [u, viewer] = [await signup(), await signup()];
      const bytes = await picture(w, h, format);
      const contentType = `image/${format}`;
      const slot = await ctx.http
        .post('/api/v1/media/uploads')
        .set(auth(u))
        .send({ kind: 'PROFILE_COVER', contentType, byteSize: bytes.length });
      expect(slot.status, JSON.stringify(slot.body)).toBe(201);
      expectContract(slot, 'createMediaUpload');
      expect(storage.upload(slot.body.uploadUrl, bytes, contentType)).toBe(true);
      const done = await ctx.http.post(`/api/v1/media/uploads/${slot.body.uploadId}/complete`).set(auth(u));
      expect(done.status, JSON.stringify(done.body)).toBe(200);
      expectContract(done, 'completeMediaUpload');
      expect([done.body.width, done.body.height]).toEqual([ow, oh]);

      const set = await ctx.http.put('/api/v1/me/cover').set(auth(u)).send({ mediaId: done.body.id });
      expect(set.status, JSON.stringify(set.body)).toBe(200);
      expectContract(set, 'setMyCover');
      expect(set.body).toEqual({ coverUrl: done.body.url });

      const me = await ctx.http.get('/api/v1/me').set(auth(u));
      expectContract(me, 'getMe');
      expect(me.body.coverUrl).toBe(done.body.url);
      const profile = await ctx.http.get(`/api/v1/users/${u.username}`).set(auth(viewer));
      expect(profile.status).toBe(200);
      expectContract(profile, 'getPublicProfile');
      expect(profile.body.coverUrl).toBe(done.body.url);
    },
  );

  it('the owner-only rule stays on the cover video: a regular user gets no PROFILE_COVER_VIDEO slot', async () => {
    const u = await signup();
    const res = await ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send({ kind: 'PROFILE_COVER_VIDEO', contentType: 'video/mp4', byteSize: 1000 });
    expect(res.status).toBe(403);
    expect((res.body as { error?: { code?: string } }).error?.code).toBe('OWNER_ONLY');
  });
});
