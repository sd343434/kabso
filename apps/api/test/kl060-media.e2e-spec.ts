/**
 * KL-060 group 1: media upload (openapi v1.5-social DRAFT, CP-006 M1, CONVENTIONS §11.1), end to
 * end against PostgreSQL + Redis with the API as the DML-only runtime role. Object storage is the
 * in-memory test double behind the ObjectStorage port (production: S3ObjectStorage).
 */
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { MediaService } from '../src/modules/media/media.service.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
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
  readonly token: string;
}

const MEDIA_ON = {
  MEDIA_UPLOADS_ENABLED: 'true',
  S3_BUCKET: 'kabso-media-test',
  S3_ACCESS_KEY_ID: 'test',
  S3_SECRET_ACCESS_KEY: 'test',
  MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
};

async function signup(ctx: TestContext): Promise<TestUser> {
  const { res } = await registerVerified(ctx);
  expect(res.status).toBe(201);
  return { id: res.body.user.id, token: res.body.tokens.accessToken };
}

const jpeg = (w = 1600, h = 1200) =>
  sharp({ create: { width: w, height: h, channels: 3, background: { r: 10, g: 120, b: 200 } } })
    .jpeg()
    .withExif({ IFD0: { Make: 'TestCam' }, IFD3: { GPSLatitudeRef: 'N' } })
    .toBuffer();

describe('KL-060 media contract coverage', () => {
  it('openapi v1.5-social declares the three media operations', () => {
    expect(
      operations()
        .filter((o) => o.path.startsWith('/api/v1/media'))
        .map((o) => o.operationId)
        .sort(),
    ).toEqual(['completeMediaUpload', 'createMediaUpload', 'getMedia']);
  });
});

describe('KL-060 media uploads disabled (default)', () => {
  let ctx: TestContext;
  let user: TestUser;

  beforeAll(async () => {
    ctx = await createTestApp({ RATE_LIMIT_MEDIA_UPLOAD_USER: '2/3600' }, [
      { token: OBJECT_STORAGE, value: new MemoryObjectStorage() },
    ]);
    user = await signup(ctx);
  });
  afterAll(async () => ctx?.close());

  it('answers 503 MEDIA_UPLOADS_UNAVAILABLE before validating the body', async () => {
    const res = await ctx.http
      .post('/api/v1/media/uploads')
      .set('Authorization', `Bearer ${user.token}`)
      .send({ nonsense: true });
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('MEDIA_UPLOADS_UNAVAILABLE');
    expect(res.headers['retry-after']).toBeUndefined();
    expectContract(res, 'createMediaUpload');
    const done = await ctx.http
      .post(`/api/v1/media/uploads/0193f1c2-0000-7000-8000-000000000000/complete`)
      .set('Authorization', `Bearer ${user.token}`);
    expect(done.status).toBe(503);
    expectContract(done, 'completeMediaUpload');
  });

  it('counts the per-user bucket before the switch (2 / hour here)', async () => {
    // The first test used one slot; the second is still within the limit, the third is not.
    const second = await ctx.http
      .post('/api/v1/media/uploads')
      .set('Authorization', `Bearer ${user.token}`)
      .send({});
    expect(second.status).toBe(503);
    const res = await ctx.http
      .post('/api/v1/media/uploads')
      .set('Authorization', `Bearer ${user.token}`)
      .send({});
    expect(res.status).toBe(429);
    expectContract(res, 'createMediaUpload');
  });

  it('needs a token', async () => {
    const res = await ctx.http.post('/api/v1/media/uploads').send({});
    expect(res.status).toBe(401);
  });
});

describe('KL-060 media uploads enabled', () => {
  let ctx: TestContext;
  let storage: MemoryObjectStorage;
  let alice: TestUser;
  let bob: TestUser;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const start = (u: TestUser, body: unknown) =>
    ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send(body as object);
  const complete = (u: TestUser, id: string) =>
    ctx.http.post(`/api/v1/media/uploads/${id}/complete`).set(auth(u));

  beforeAll(async () => {
    storage = new MemoryObjectStorage();
    ctx = await createTestApp(MEDIA_ON, [{ token: OBJECT_STORAGE, value: storage }]);
    alice = await signup(ctx);
    bob = await signup(ctx);
  });
  afterAll(async () => ctx?.close());

  it('validates the request strictly', async () => {
    for (const body of [
      {},
      { kind: 'POST_IMAGE', contentType: 'image/heic', byteSize: 10 },
      { kind: 'POST_IMAGE', contentType: 'image/svg+xml', byteSize: 10 },
      { kind: 'POST_VIDEO', contentType: 'image/jpeg', byteSize: 10 },
      { kind: 'POST_IMAGE', contentType: 'image/jpeg', byteSize: 0 },
      { kind: 'POST_IMAGE', contentType: 'image/jpeg', byteSize: 15 * 1024 * 1024 + 1 },
      { kind: 'POST_IMAGE', contentType: 'image/jpeg', byteSize: 10, extra: 1 },
    ]) {
      const res = await start(alice, body);
      expect(res.status, JSON.stringify(body)).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_FAILED');
      expectContract(res, 'createMediaUpload');
    }
  });

  it('uploads, verifies and re-encodes a photo; complete is idempotent', async () => {
    const bytes = await jpeg();
    const slot = await start(alice, {
      kind: 'POST_IMAGE',
      contentType: 'image/jpeg',
      byteSize: bytes.length,
    });
    expect(slot.status).toBe(201);
    expectContract(slot, 'createMediaUpload');
    expect(slot.body.headers).toEqual({
      'Content-Type': 'image/jpeg',
      'Content-Length': String(bytes.length),
    });
    expect(new Date(slot.body.expiresAt).getTime()).toBeGreaterThan(Date.now() + 9 * 60_000);
    // The signature binds type and length: a different length is refused by the store.
    expect(storage.upload(slot.body.uploadUrl, Buffer.concat([bytes, Buffer.alloc(1)]), 'image/jpeg')).toBe(
      false,
    );
    expect(storage.upload(slot.body.uploadUrl, bytes, 'image/jpeg')).toBe(true);

    const res = await complete(alice, slot.body.uploadId);
    expect(res.status).toBe(200);
    expectContract(res, 'completeMediaUpload');
    expect(res.body).toMatchObject({
      id: slot.body.uploadId,
      type: 'IMAGE',
      status: 'READY',
      width: 1080,
      height: 810,
    });
    expect(res.body.url).toBe(`https://media.example.test/media/${slot.body.uploadId}/1080.webp`);
    expect(res.body.thumbUrl).toBe(`https://media.example.test/media/${slot.body.uploadId}/320.webp`);
    // The original (with its EXIF/GPS) is gone; the outputs carry no metadata.
    expect(await storage.head(`uploads/${alice.id}/${slot.body.uploadId}`)).toBeNull();
    const large = storage.objects.get(`media/${slot.body.uploadId}/1080.webp`)!;
    expect((await sharp(large.body).metadata()).exif).toBeUndefined();
    expect(large.cacheControl).toContain('immutable');

    const again = await complete(alice, slot.body.uploadId);
    expect(again.status).toBe(200);
    expect(again.body).toEqual(res.body);

    const get = await ctx.http.get(`/api/v1/media/${slot.body.uploadId}`).set(auth(alice));
    expect(get.status).toBe(200);
    expectContract(get, 'getMedia');
    expect(get.body).toEqual(res.body);
  });

  it('only the uploader may complete or read an asset', async () => {
    const bytes = await jpeg(400, 400);
    const slot = await start(alice, {
      kind: 'POST_IMAGE',
      contentType: 'image/jpeg',
      byteSize: bytes.length,
    });
    storage.upload(slot.body.uploadUrl, bytes, 'image/jpeg');
    const stolen = await complete(bob, slot.body.uploadId);
    expect(stolen.status).toBe(404);
    expectContract(stolen, 'completeMediaUpload');
    const mine = await complete(alice, slot.body.uploadId);
    expect(mine.status).toBe(200);
    const peek = await ctx.http.get(`/api/v1/media/${slot.body.uploadId}`).set(auth(bob));
    expect(peek.status).toBe(404);
    expectContract(peek, 'getMedia');
    for (const id of ['not-a-uuid', '00000000-0000-7000-8000-000000000000']) {
      expect((await complete(alice, id)).status).toBe(404);
      expect((await ctx.http.get(`/api/v1/media/${id}`).set(auth(alice))).status).toBe(404);
    }
  });

  it('refuses a missing object, bytes that are not the declared type and size mismatches', async () => {
    const png = await sharp({ create: { width: 64, height: 64, channels: 3, background: '#fff' } })
      .png()
      .toBuffer();
    // Nothing uploaded.
    const empty = await start(alice, { kind: 'POST_IMAGE', contentType: 'image/jpeg', byteSize: 100 });
    const r1 = await complete(alice, empty.body.uploadId);
    expect(r1.status).toBe(422);
    expect(r1.body.error.code).toBe('MEDIA_INVALID');
    expectContract(r1, 'completeMediaUpload');
    // The slot is closed: completing again stays 422.
    expect((await complete(alice, empty.body.uploadId)).status).toBe(422);

    // A PNG declared as JPEG (the client MIME type is not trusted).
    const liar = await start(alice, { kind: 'POST_IMAGE', contentType: 'image/jpeg', byteSize: png.length });
    storage.putRaw(`uploads/${alice.id}/${liar.body.uploadId}`, png, 'image/jpeg');
    const r2 = await complete(alice, liar.body.uploadId);
    expect(r2.status).toBe(422);
    expect(await storage.head(`uploads/${alice.id}/${liar.body.uploadId}`)).toBeNull();

    // A script with an image name and the declared length.
    const script = Buffer.from('<?php echo 1; ?>'.padEnd(200, ' '));
    const fake = await start(alice, {
      kind: 'POST_IMAGE',
      contentType: 'image/png',
      byteSize: script.length,
    });
    storage.putRaw(`uploads/${alice.id}/${fake.body.uploadId}`, script);
    expect((await complete(alice, fake.body.uploadId)).status).toBe(422);

    // More bytes than declared (written around the signature).
    const big = await start(alice, {
      kind: 'POST_IMAGE',
      contentType: 'image/png',
      byteSize: png.length - 1,
    });
    storage.putRaw(`uploads/${alice.id}/${big.body.uploadId}`, png);
    expect((await complete(alice, big.body.uploadId)).status).toBe(422);

    const failed = await ctx.prisma.mediaUpload.count({ where: { userId: alice.id, status: 'FAILED' } });
    expect(failed).toBe(4);
    expect(await ctx.prisma.mediaAsset.count({ where: { ownerId: alice.id } })).toBe(2);
  });

  it('refuses a slot whose URL expired long ago', async () => {
    const bytes = await jpeg(200, 200);
    const slot = await start(alice, {
      kind: 'POST_IMAGE',
      contentType: 'image/jpeg',
      byteSize: bytes.length,
    });
    storage.putRaw(`uploads/${alice.id}/${slot.body.uploadId}`, bytes);
    await withMigrationClient((c) =>
      c.mediaUpload.update({
        where: { id: slot.body.uploadId },
        data: { expiresAt: new Date(Date.now() - 2 * 3600_000) },
      }),
    );
    expect((await complete(alice, slot.body.uploadId)).status).toBe(422);
  });

  it('the sweeper closes stale slots and deletes assets never attached within 24 hours', async () => {
    const media = ctx.app.get(MediaService);
    const bytes = await jpeg(300, 300);
    const stale = await start(bob, { kind: 'POST_IMAGE', contentType: 'image/jpeg', byteSize: bytes.length });
    storage.putRaw(`uploads/${bob.id}/${stale.body.uploadId}`, bytes);
    const kept = await start(bob, { kind: 'POST_IMAGE', contentType: 'image/jpeg', byteSize: bytes.length });
    storage.upload(kept.body.uploadUrl, bytes, 'image/jpeg');
    await complete(bob, kept.body.uploadId);
    const old = await start(bob, { kind: 'POST_IMAGE', contentType: 'image/jpeg', byteSize: bytes.length });
    storage.upload(old.body.uploadUrl, bytes, 'image/jpeg');
    await complete(bob, old.body.uploadId);
    await withMigrationClient(async (c) => {
      await c.mediaUpload.update({
        where: { id: stale.body.uploadId },
        data: { expiresAt: new Date(Date.now() - 2 * 3600_000) },
      });
      await c.mediaAsset.update({
        where: { id: old.body.uploadId },
        data: { createdAt: new Date(Date.now() - 25 * 3600_000) },
      });
    });
    const result = await media.sweep();
    expect(result.slots).toBeGreaterThanOrEqual(1);
    expect(result.assets).toBe(1);
    expect(
      (await ctx.prisma.mediaUpload.findUniqueOrThrow({ where: { id: stale.body.uploadId } })).status,
    ).toBe('FAILED');
    expect(await storage.head(`uploads/${bob.id}/${stale.body.uploadId}`)).toBeNull();
    expect(await ctx.prisma.mediaAsset.findUnique({ where: { id: old.body.uploadId } })).toBeNull();
    expect(storage.objects.has(`media/${old.body.uploadId}/1080.webp`)).toBe(false);
    expect(await ctx.prisma.mediaAsset.findUnique({ where: { id: kept.body.uploadId } })).not.toBeNull();
    expect(storage.objects.has(`media/${kept.body.uploadId}/1080.webp`)).toBe(true);
  });
});
