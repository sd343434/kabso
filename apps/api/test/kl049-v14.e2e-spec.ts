/**
 * KL-049: contract v1.4 — media uploads (avatars, room covers), the user-chosen country and the
 * SEC-039 text-hygiene tightening (CONVENTIONS §6, §7, §11; openapi v1.4; DB_PHASE2_MEDIA.md), end
 * to end against PostgreSQL + Redis with the API running as the DML-only runtime role.
 *
 * Storage: an in-memory fake of the storage port (test/helpers/in-memory-media-storage.ts). It
 * plays the provider's side of the presigned PUT (signed size and type, expiry); image processing
 * runs for real in the isolated worker process. No provider is contacted.
 * Time: the FakeClock is moved instead of sleeping (upload windows, grace periods, cleanup).
 * Every response of a v1.4 operation is checked against openapi.yaml (`expectContract`).
 */
import { createHmac, hkdfSync } from 'node:crypto';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { MediaCleanupService } from '../src/modules/media/media-cleanup.service.js';
import { detectContentType } from '../src/modules/media/image-header.js';
import { MEDIA_STORAGE } from '../src/modules/media/media-storage.js';
import { MediaService } from '../src/modules/media/media.service.js';
import { AccountLifecycleService } from '../src/modules/users/profiles/account-lifecycle.service.js';
import { animatedWebp, jpeg, png, pngBomb } from './helpers/image-fixtures.js';
import { InMemoryMediaStorage } from './helpers/in-memory-media-storage.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, settle, type TestContext } from './helpers/test-app.js';

class FakeClock extends Clock {
  private ms = Date.now();
  now(): Date {
    return new Date(this.ms);
  }
  advance(seconds: number): void {
    this.ms += seconds * 1000;
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

const MEDIA_BASE = 'https://media.kabso-test.example';
const MISSING_ID = '0192f1d0-0000-7000-8000-000000000000';
const HOUR = 3600;

/** Fake, per-run storage settings (no provider is ever contacted: the port is replaced). */
const STORAGE_ENV = {
  MEDIA_STORAGE_ENDPOINT: 'https://account.r2.example.invalid',
  MEDIA_STORAGE_REGION: 'auto',
  MEDIA_STORAGE_INCOMING_BUCKET: 'kabso-incoming-e2e',
  MEDIA_STORAGE_PUBLIC_BUCKET: 'kabso-public-e2e',
  MEDIA_STORAGE_ACCESS_KEY_ID: `e2e${Date.now().toString(16)}`,
  MEDIA_STORAGE_SECRET_ACCESS_KEY: `e2e-${Math.random().toString(36).slice(2)}${Date.now().toString(36)}`,
  MEDIA_PUBLIC_BASE_URL: MEDIA_BASE,
};

async function signup(ctx: TestContext, overrides: Partial<Record<string, unknown>> = {}): Promise<TestUser> {
  const { res } = await registerVerified(ctx, overrides);
  expect(res.status).toBe(201);
  return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
}

function bearer(user: TestUser): { Authorization: string } {
  return { Authorization: `Bearer ${user.token}` };
}

function expectError(
  res: { status: number; body: { error?: { code?: string } }; headers?: Record<string, string> },
  status: number,
  code: string,
) {
  expect({ status: res.status, code: res.body.error?.code }).toEqual({ status, code });
}

function errorShape(res: { status: number; body: { error?: Record<string, unknown> } }) {
  const { requestId: _ignored, ...rest } = res.body.error ?? {};
  return { status: res.status, ...rest };
}

interface MediaApp {
  readonly clock: FakeClock;
  readonly storage: InMemoryMediaStorage;
  create(): Promise<TestContext>;
}

/** An app with uploads enabled on the in-memory store, live hosting on, and a fake clock. */
function mediaApp(overrides: Record<string, string> = {}): MediaApp {
  const clock = new FakeClock();
  const storage = new InMemoryMediaStorage(() => clock.now().getTime());
  return {
    clock,
    storage,
    create: () =>
      createTestApp(
        { LIVE_HOSTING_ENABLED: 'true', MEDIA_UPLOADS_ENABLED: 'true', ...STORAGE_ENV, ...overrides },
        [
          { token: Clock, value: clock },
          { token: MEDIA_STORAGE, value: storage },
        ],
      ),
  };
}

/** Client helpers bound to one app. */
function client(ctx: () => TestContext, storage: InMemoryMediaStorage) {
  const declare = (user: TestUser, body: unknown) =>
    ctx()
      .http.post('/api/v1/media/uploads')
      .set(bearer(user))
      .send(body as object);
  const complete = (user: TestUser, id: string) =>
    ctx().http.post(`/api/v1/media/uploads/${id}/complete`).set(bearer(user)).send();
  const getUpload = (user: TestUser, id: string) =>
    ctx().http.get(`/api/v1/media/uploads/${id}`).set(bearer(user));
  const patchMe = (user: TestUser, body: unknown) =>
    ctx()
      .http.patch('/api/v1/me')
      .set(bearer(user))
      .send(body as object);
  const getMe = (user: TestUser) => ctx().http.get('/api/v1/me').set(bearer(user));
  const profile = (viewer: TestUser, username: string) =>
    ctx().http.get(`/api/v1/users/${username}`).set(bearer(viewer));
  const startRoom = (user: TestUser, body: unknown) =>
    ctx()
      .http.post('/api/v1/live/rooms')
      .set(bearer(user))
      .send(body as object);
  const setCover = (user: TestUser, roomId: string, body: unknown) =>
    ctx()
      .http.put(`/api/v1/live/rooms/${roomId}/cover`)
      .set(bearer(user))
      .send(body as object);
  const getRoom = (user: TestUser, roomId: string) =>
    ctx().http.get(`/api/v1/live/rooms/${roomId}`).set(bearer(user));
  const list = (user: TestUser, query: Record<string, string | number>) =>
    ctx().http.get('/api/v1/live/rooms').query(query).set(bearer(user));

  /** Declares, uploads (as the client would) and returns the declare response. */
  async function declareAndPut(
    user: TestUser,
    purpose: 'avatar' | 'room_cover',
    bytes: Buffer,
    contentType = 'image/jpeg',
  ) {
    const res = await declare(user, { purpose, contentType, byteSize: bytes.length });
    expectContract(res, 'createMediaUpload');
    expect(res.status, `declare ${purpose} (${contentType}): ${JSON.stringify(res.body)}`).toBe(201);
    expect(storage.clientPut(res.body.url, res.body.headers, bytes), 'fake storage PUT').toBe(200);
    return res;
  }

  /** A READY upload (declare → PUT → complete). */
  async function ready(user: TestUser, purpose: 'avatar' | 'room_cover', bytes?: Buffer): Promise<string> {
    const image = bytes ?? (purpose === 'avatar' ? await jpeg(600, 600) : await jpeg(960, 1280));
    // Declare the real type of the bytes (the API refuses a declared/detected mismatch).
    const contentType = detectContentType(image);
    expect(contentType, 'test image must be JPEG, PNG or WebP').not.toBeNull();
    const declared = await declareAndPut(user, purpose, image, contentType!);
    const done = await complete(user, declared.body.uploadId);
    expectContract(done, 'completeMediaUpload');
    // On failure the message carries the rejection (code and `details` issue).
    expect(done.status, `complete ${purpose} (${contentType}): ${JSON.stringify(done.body)}`).toBe(200);
    return declared.body.uploadId as string;
  }

  return {
    declare,
    complete,
    getUpload,
    patchMe,
    getMe,
    profile,
    startRoom,
    setCover,
    getRoom,
    list,
    declareAndPut,
    ready,
  };
}

// ---------------------------------------------------------------------------------------------

describe('KL-049 contract coverage', () => {
  it('openapi v1.4 declares the seven new operations implemented here', () => {
    const v14 = operations()
      .filter((o) =>
        /^\/api\/v1\/(media\/|countries$|live\/countries$|live\/rooms\/\{roomId\}\/cover$)/.test(o.path),
      )
      .map((o) => o.operationId)
      .sort();
    expect(v14).toEqual(
      [
        'getMediaConfig',
        'createMediaUpload',
        'getMediaUpload',
        'completeMediaUpload',
        'setLiveRoomCover',
        'listLiveCountries',
        'listCountries',
      ].sort(),
    );
  });
});

describe('KL-049 authentication', () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true' });
  });
  afterAll(async () => {
    await ctx?.close();
  });

  it('every v1.4 operation answers 401 AUTH_UNAUTHENTICATED without a token', async () => {
    const calls: [string, () => Promise<{ status: number; body: { error?: { code?: string } } }>][] = [
      ['getMediaConfig', () => ctx.http.get('/api/v1/media/config')],
      ['createMediaUpload', () => ctx.http.post('/api/v1/media/uploads').send({})],
      ['getMediaUpload', () => ctx.http.get(`/api/v1/media/uploads/${MISSING_ID}`)],
      ['completeMediaUpload', () => ctx.http.post(`/api/v1/media/uploads/${MISSING_ID}/complete`)],
      [
        'setLiveRoomCover',
        () => ctx.http.put(`/api/v1/live/rooms/${MISSING_ID}/cover`).send({ coverUploadId: null }),
      ],
      ['listLiveCountries', () => ctx.http.get('/api/v1/live/countries')],
      ['listCountries', () => ctx.http.get('/api/v1/countries')],
      ['updateMe', () => ctx.http.patch('/api/v1/me').send({ country: 'SA' })],
    ];
    for (const [operationId, call] of calls) {
      const res = await call();
      expectContract(res as never, operationId);
      expect({ operationId, status: res.status, code: res.body.error?.code }).toEqual({
        operationId,
        status: 401,
        code: 'AUTH_UNAUTHENTICATED',
      });
    }
  });
});

describe('KL-049 uploads disabled (the default: MEDIA_UPLOADS_ENABLED=false, no storage)', () => {
  let ctx: TestContext;
  const c = client(() => ctx, new InMemoryMediaStorage());

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', RATE_LIMIT_MEDIA_UPLOAD_HOUR_USER: '3/3600' });
  });
  afterAll(async () => {
    await ctx?.close();
  });

  it('GET /media/config reports uploadsEnabled=false and the contract limits', async () => {
    const user = await signup(ctx);
    const res = await ctx.http.get('/api/v1/media/config').set(bearer(user));
    expectContract(res, 'getMediaConfig');
    expect(res.body).toEqual({
      uploadsEnabled: false,
      allowedContentTypes: ['image/jpeg', 'image/png', 'image/webp'],
      maxPixels: 40_000_000,
      maxSidePixels: 8192,
      purposes: {
        avatar: { maxBytes: 5_242_880, minWidth: 128, minHeight: 128, aspectRatio: '1:1' },
        room_cover: { maxBytes: 10_485_760, minWidth: 480, minHeight: 640, aspectRatio: '3:4' },
      },
    });
  });

  it('declare and complete answer 503 MEDIA_UPLOADS_UNAVAILABLE without Retry-After; reads still work', async () => {
    const user = await signup(ctx);
    for (const body of [
      { purpose: 'avatar', contentType: 'image/jpeg', byteSize: 1000 },
      { nonsense: true },
    ]) {
      const res = await c.declare(user, body);
      expectContract(res, 'createMediaUpload');
      expectError(res, 503, 'MEDIA_UPLOADS_UNAVAILABLE');
      expect(res.headers['retry-after']).toBeUndefined();
    }
    const done = await c.complete(user, MISSING_ID);
    expectContract(done, 'completeMediaUpload');
    expectError(done, 503, 'MEDIA_UPLOADS_UNAVAILABLE');
    const read = await c.getUpload(user, MISSING_ID);
    expectContract(read, 'getMediaUpload');
    expectError(read, 404, 'NOT_FOUND');
    expect(await ctx.prisma.mediaObject.count()).toBe(0);
  });

  it('the upload hour bucket is counted before the feature gate (429 even while disabled)', async () => {
    const user = await signup(ctx);
    const body = { purpose: 'avatar', contentType: 'image/jpeg', byteSize: 1000 };
    // Bucket 3 / hour; the previous test's user had its own bucket.
    for (let i = 0; i < 3; i += 1) expectError(await c.declare(user, body), 503, 'MEDIA_UPLOADS_UNAVAILABLE');
    const limited = await c.declare(user, body);
    expectContract(limited, 'createMediaUpload');
    expectError(limited, 429, 'RATE_LIMITED');
    expect(Number(limited.headers['retry-after'])).toBeGreaterThan(0);
  });

  it('PATCH /me: a non-null avatarUploadId → 503; null and country still work', async () => {
    const user = await signup(ctx);
    const blocked = await c.patchMe(user, { avatarUploadId: MISSING_ID, country: 'SA' });
    expectContract(blocked, 'updateMe');
    expectError(blocked, 503, 'MEDIA_UPLOADS_UNAVAILABLE');
    expect((await c.getMe(user)).body.country).toBeNull(); // all-or-nothing
    // Body schema first: a bad locale is 400 even with an avatar id.
    expectError(
      await c.patchMe(user, { avatarUploadId: MISSING_ID, locale: 'fr' }),
      400,
      'VALIDATION_FAILED',
    );
    const ok = await c.patchMe(user, { avatarUploadId: null, country: 'SA' });
    expectContract(ok, 'updateMe');
    expect(ok.status).toBe(200);
    expect(ok.body).toMatchObject({
      avatarUrl: null,
      avatarThumbUrl: null,
      avatarModeration: null,
      country: 'SA',
    });
  });

  it('go-live with a coverUploadId → 503 MEDIA_UPLOADS_UNAVAILABLE; PUT cover: null works, an id → 503', async () => {
    const host = await signup(ctx);
    const refused = await c.startRoom(host, { title: 'With cover', coverUploadId: MISSING_ID });
    expectContract(refused, 'startLiveRoom');
    expectError(refused, 503, 'MEDIA_UPLOADS_UNAVAILABLE');
    const room = await c.startRoom(host, { title: 'No cover' });
    expectContract(room, 'startLiveRoom');
    expect(room.status).toBe(201);
    const removed = await c.setCover(host, room.body.id, { coverUploadId: null });
    expectContract(removed, 'setLiveRoomCover');
    expect(removed.status).toBe(200);
    expect(removed.body).toMatchObject({ coverUrl: null, coverThumbUrl: null, coverModeration: null });
    const blocked = await c.setCover(host, room.body.id, { coverUploadId: MISSING_ID });
    expectContract(blocked, 'setLiveRoomCover');
    expectError(blocked, 503, 'MEDIA_UPLOADS_UNAVAILABLE');
  });
});

describe('KL-049 avatar uploads (uploads enabled, in-memory store)', () => {
  const app = mediaApp();
  const { clock, storage } = app;
  let ctx: TestContext;
  const c = client(() => ctx, storage);

  beforeAll(async () => {
    ctx = await app.create();
    ctx.app.getHttpServer().setMaxListeners(32);
  });
  afterAll(async () => {
    await ctx?.close();
  });

  it('declare → PUT → complete: READY, PENDING, owner-preview URLs, original deleted, idempotent', async () => {
    const user = await signup(ctx);
    const bytes = await jpeg(1000, 800, { gps: true });
    const declared = await c.declare(user, {
      purpose: 'avatar',
      contentType: 'image/jpeg',
      byteSize: bytes.length,
    });
    expectContract(declared, 'createMediaUpload');
    expect(declared.status).toBe(201);
    expect(declared.body).toEqual({
      uploadId: expect.any(String),
      purpose: 'avatar',
      method: 'PUT',
      url: expect.stringMatching(/^https:\/\/storage\.test\.invalid\/incoming\/in\//),
      headers: { 'Content-Type': 'image/jpeg', 'Content-Length': String(bytes.length) },
      expiresAt: new Date(clock.now().getTime() + 600_000).toISOString(),
    });
    const id = declared.body.uploadId as string;

    const awaiting = await c.getUpload(user, id);
    expectContract(awaiting, 'getMediaUpload');
    expect(awaiting.body).toEqual({
      uploadId: id,
      purpose: 'avatar',
      status: 'AWAITING_UPLOAD',
      moderationStatus: null,
      width: null,
      height: null,
      url: null,
      thumbUrl: null,
      attached: false,
      expiresAt: declared.body.expiresAt,
      failure: null,
    });

    // The provider refuses a different size or type (signed headers).
    expect(
      storage.clientPut(declared.body.url, { ...declared.body.headers, 'Content-Type': 'image/png' }, bytes),
    ).toBe(403);
    expect(
      storage.clientPut(declared.body.url, declared.body.headers, Buffer.concat([bytes, Buffer.from('x')])),
    ).toBe(403);
    expect(storage.clientPut(declared.body.url, declared.body.headers, bytes)).toBe(200);

    const done = await c.complete(user, id);
    expectContract(done, 'completeMediaUpload');
    expect(done.status).toBe(200);
    const token = /\/a\/([A-Za-z0-9_-]{22})\/512\.webp$/.exec(done.body.url)?.[1];
    expect(token).toBeDefined();
    expect(done.body).toEqual({
      uploadId: id,
      purpose: 'avatar',
      status: 'READY',
      moderationStatus: 'PENDING',
      width: 512,
      height: 512,
      url: `${MEDIA_BASE}/a/${token}/512.webp`,
      thumbUrl: `${MEDIA_BASE}/a/${token}/128.webp`,
      attached: false,
      expiresAt: new Date(clock.now().getTime() + 24 * HOUR * 1000).toISOString(),
      failure: null,
    });
    // Storage: original deleted, two WebP derivatives with the immutable 1-day Cache-Control and
    // no metadata (the input carried GPS EXIF).
    expect(storage.incoming.size).toBe(0);
    for (const [key, size] of [
      [`a/${token}/512.webp`, 512],
      [`a/${token}/128.webp`, 128],
    ] as const) {
      const object = storage.public.get(key)!;
      expect(object).toMatchObject({
        contentType: 'image/webp',
        cacheControl: 'public, max-age=86400, immutable',
      });
      const meta = await sharp(object.body).metadata();
      expect({
        format: meta.format,
        width: meta.width,
        exif: meta.exif,
        icc: meta.icc,
        xmp: meta.xmp,
      }).toEqual({
        format: 'webp',
        width: size,
        exif: undefined,
        icc: undefined,
        xmp: undefined,
      });
    }
    const audits = await ctx.prisma.auditLog.findMany({
      where: { action: 'media.upload.complete', targetId: id },
    });
    expect(audits).toHaveLength(1);
    // Idempotent: the same 200 body, no second processing or audit row.
    const again = await c.complete(user, id);
    expectContract(again, 'completeMediaUpload');
    expect(again.body).toEqual(done.body);
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'media.upload.complete', targetId: id } }),
    ).toBe(1);
  });

  it('PATCH /me {avatarUploadId}: attaches; the owner sees it while PENDING, others only once APPROVED', async () => {
    const owner = await signup(ctx, { displayName: 'Avatar Owner' });
    const viewer = await signup(ctx);
    const id = await c.ready(owner, 'avatar');
    const res = await c.patchMe(owner, { avatarUploadId: id });
    expectContract(res, 'updateMe');
    expect(res.status).toBe(200);
    expect(res.body.avatarUrl).toMatch(new RegExp(`^${MEDIA_BASE}/a/[A-Za-z0-9_-]{22}/512\\.webp$`));
    expect(res.body.avatarThumbUrl).toMatch(/\/128\.webp$/);
    expect(res.body.avatarModeration).toBe('PENDING');
    const me = await c.getMe(owner);
    expect(me.body).toMatchObject({ avatarUrl: res.body.avatarUrl, avatarModeration: 'PENDING' });
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'media.avatar.set', actorUserId: owner.id } }),
    ).toBe(1);

    const attached = await c.getUpload(owner, id);
    expect(attached.body).toMatchObject({ attached: true, expiresAt: null });

    // Visibility (CONVENTIONS §11.5): PENDING → owner only.
    const self = await c.profile(owner, owner.username);
    expectContract(self, 'getPublicProfile');
    expect(self.body.avatarUrl).toBe(res.body.avatarUrl);
    const other = await c.profile(viewer, owner.username);
    expectContract(other, 'getPublicProfile');
    expect(other.body).toMatchObject({ avatarUrl: null, avatarThumbUrl: null });

    expect(await ctx.app.get(MediaService).applyModeration(id, 'APPROVED', 'e2e')).toBe(true);
    const approved = await c.profile(viewer, owner.username);
    expect(approved.body).toMatchObject({
      avatarUrl: res.body.avatarUrl,
      avatarThumbUrl: res.body.avatarThumbUrl,
    });
    expect((await c.getMe(owner)).body.avatarModeration).toBe('APPROVED');
  });

  it('attach refusals are one identical 400 (another user’s, reused, wrong purpose, not READY, unknown)', async () => {
    const owner = await signup(ctx);
    const stranger = await signup(ctx);
    const theirs = await c.ready(stranger, 'avatar');
    const used = await c.ready(owner, 'avatar');
    expect((await c.patchMe(owner, { avatarUploadId: used })).status).toBe(200);
    const cover = await c.ready(owner, 'room_cover');
    const pending = (await c.declare(owner, { purpose: 'avatar', contentType: 'image/png', byteSize: 10 }))
      .body.uploadId;
    const bodies = [];
    for (const avatarUploadId of [theirs, used, cover, pending, MISSING_ID]) {
      const res = await c.patchMe(owner, { avatarUploadId });
      expectContract(res, 'updateMe');
      bodies.push(errorShape(res));
    }
    for (const body of bodies) {
      expect(body).toEqual({
        status: 400,
        code: 'VALIDATION_FAILED',
        message: 'Request validation failed.',
        details: [{ field: 'avatarUploadId', issue: 'invalid_value' }],
      });
    }
    // Another user's upload is 404 on read and on complete, never 403.
    expectError(await c.getUpload(owner, theirs), 404, 'NOT_FOUND');
    expectError(await c.complete(owner, theirs), 404, 'NOT_FOUND');
    for (const bad of ['not-a-uuid', 'ZZZZ', '0192f1d0-0000-7000-8000-00000000000g']) {
      expectError(await c.getUpload(owner, bad), 404, 'NOT_FOUND');
      expectError(await c.complete(owner, bad), 404, 'NOT_FOUND');
    }
    // all-or-nothing: the locale in the same refused body was not applied.
    const refused = await c.patchMe(owner, { avatarUploadId: theirs, locale: 'ar' });
    expect(refused.status).toBe(400);
    expect((await c.getMe(owner)).body.locale).toBe('en');
  });

  it('replacing and removing the avatar detach the previous one (grace period), audited', async () => {
    const owner = await signup(ctx);
    const first = await c.ready(owner, 'avatar');
    const second = await c.ready(owner, 'avatar');
    await c.patchMe(owner, { avatarUploadId: first });
    const replaced = await c.patchMe(owner, { avatarUploadId: second });
    expect(replaced.status).toBe(200);
    const firstRow = await ctx.prisma.mediaObject.findUniqueOrThrow({ where: { id: first } });
    expect(firstRow.detachedAt).not.toBeNull();
    const removed = await c.patchMe(owner, { avatarUploadId: null });
    expectContract(removed, 'updateMe');
    expect(removed.body).toMatchObject({ avatarUrl: null, avatarThumbUrl: null, avatarModeration: null });
    expect(
      (await ctx.prisma.mediaObject.findUniqueOrThrow({ where: { id: second } })).detachedAt,
    ).not.toBeNull();
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'media.avatar.remove', actorUserId: owner.id } }),
    ).toBe(1);
    // A detached upload cannot be attached again ("attached at most once").
    expectError(await c.patchMe(owner, { avatarUploadId: first }), 400, 'VALIDATION_FAILED');
  });

  it('moderation REJECTED: detached at once, URLs null everywhere, audited; cleanup deletes the objects', async () => {
    const owner = await signup(ctx);
    const id = await c.ready(owner, 'avatar');
    await c.patchMe(owner, { avatarUploadId: id });
    const token = (await ctx.prisma.mediaObject.findUniqueOrThrow({ where: { id } })).publicToken!;
    expect(await ctx.app.get(MediaService).applyModeration(id, 'REJECTED', 'e2e')).toBe(true);
    expect((await c.getMe(owner)).body).toMatchObject({ avatarUrl: null, avatarModeration: null });
    const read = await c.getUpload(owner, id);
    expectContract(read, 'getMediaUpload');
    expect(read.body).toMatchObject({
      status: 'READY',
      moderationStatus: 'REJECTED',
      url: null,
      thumbUrl: null,
    });
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'media.moderation.reject', targetId: id } }),
    ).toBe(1);
    expect(storage.public.has(`a/${token}/512.webp`)).toBe(true);
    await ctx.app.get(MediaCleanupService).runCleanup();
    expect(storage.public.has(`a/${token}/512.webp`)).toBe(false);
    expect(storage.public.has(`a/${token}/128.webp`)).toBe(false);
    const row = await ctx.prisma.mediaObject.findUniqueOrThrow({ where: { id } });
    expect(row.status).toBe('DELETED');
    expect(row.deletedAt).not.toBeNull();
    expect((await c.getUpload(owner, id)).body).toMatchObject({ status: 'DELETED', url: null });
  });

  it('complete: 409 MEDIA_UPLOAD_NOT_RECEIVED until the PUT arrives, then 200', async () => {
    const user = await signup(ctx);
    const bytes = await jpeg(300, 300);
    const declared = await c.declare(user, {
      purpose: 'avatar',
      contentType: 'image/jpeg',
      byteSize: bytes.length,
    });
    const early = await c.complete(user, declared.body.uploadId);
    expectContract(early, 'completeMediaUpload');
    expectError(early, 409, 'MEDIA_UPLOAD_NOT_RECEIVED');
    expect((await c.getUpload(user, declared.body.uploadId)).body.status).toBe('AWAITING_UPLOAD');
    storage.clientPut(declared.body.url, declared.body.headers, bytes);
    const done = await c.complete(user, declared.body.uploadId);
    expect(done.status).toBe(200);
    expect(done.body).toMatchObject({ width: 300, height: 300 }); // never upscaled
  });

  it('complete: accepted until expiresAt + 5 min, then 410 MEDIA_UPLOAD_EXPIRED', async () => {
    const user = await signup(ctx);
    const bytes = await jpeg(200, 200);
    const late = await c.declareAndPut(user, 'avatar', bytes);
    const tooLate = await c.declareAndPut(user, 'avatar', bytes);
    clock.advance(600 + 290);
    expect((await c.complete(user, late.body.uploadId)).status).toBe(200);
    clock.advance(20);
    const expired = await c.complete(user, tooLate.body.uploadId);
    expectContract(expired, 'completeMediaUpload');
    expectError(expired, 410, 'MEDIA_UPLOAD_EXPIRED');
    // The provider refuses a PUT after the URL expired.
    const old = await c.declare(user, {
      purpose: 'avatar',
      contentType: 'image/jpeg',
      byteSize: bytes.length,
    });
    clock.advance(601);
    expect(storage.clientPut(old.body.url, old.body.headers, bytes)).toBe(403);
    // The cleanup job marks abandoned uploads EXPIRED.
    clock.advance(301);
    await ctx.app.get(MediaCleanupService).runCleanup();
    expect((await c.getUpload(user, old.body.uploadId)).body.status).toBe('EXPIRED');
    expectError(await c.complete(user, old.body.uploadId), 410, 'MEDIA_UPLOAD_EXPIRED');
  });

  it.each([
    ['type differs from the declared type', 'image/png', async () => jpeg(300, 300), 'invalid_format'],
    [
      'GIF bytes declared as PNG',
      'image/png',
      async () =>
        sharp({ create: { width: 300, height: 300, channels: 3, background: 'red' } })
          .gif()
          .toBuffer(),
      'invalid_format',
    ],
    ['animated WebP', 'image/webp', async () => animatedWebp(300, 300), 'invalid_format'],
    ['truncated JPEG', 'image/jpeg', async () => (await jpeg(400, 400)).subarray(0, 900), 'invalid_format'],
    ['below the minimum size', 'image/jpeg', async () => jpeg(100, 100), 'too_small'],
    ['decompression bomb (header 8000 × 8000)', 'image/png', async () => pngBomb(8000, 8000), 'too_big'],
  ] as const)('complete → 422 MEDIA_UPLOAD_REJECTED: %s', async (_label, contentType, make, issue) => {
    const user = await signup(ctx);
    const bytes = await make();
    const declared = await c.declareAndPut(user, 'avatar', Buffer.from(bytes), contentType);
    const res = await c.complete(user, declared.body.uploadId);
    expectContract(res, 'completeMediaUpload');
    expectError(res, 422, 'MEDIA_UPLOAD_REJECTED');
    expect(res.body.error.details).toEqual([{ field: 'file', issue }]);
    // FAILED, original deleted, audited; a repeat gives the same 422.
    const read = await c.getUpload(user, declared.body.uploadId);
    expectContract(read, 'getMediaUpload');
    expect(read.body).toMatchObject({ status: 'FAILED', failure: { field: 'file', issue }, url: null });
    expect(storage.incoming.has(storage.keyOf(declared.body.url))).toBe(false);
    expect(
      await ctx.prisma.auditLog.count({
        where: { action: 'media.upload.reject', targetId: declared.body.uploadId },
      }),
    ).toBe(1);
    const again = await c.complete(user, declared.body.uploadId);
    expect(errorShape(again)).toEqual(errorShape(res));
  });

  it('complete → 422 too_big when the stored object is larger than declared (HEAD before download)', async () => {
    const user = await signup(ctx);
    const declared = await c.declare(user, { purpose: 'avatar', contentType: 'image/jpeg', byteSize: 1000 });
    storage.forceIncoming(storage.keyOf(declared.body.url), Buffer.alloc(5000, 1));
    const before = storage.calls.length;
    const res = await c.complete(user, declared.body.uploadId);
    expectError(res, 422, 'MEDIA_UPLOAD_REJECTED');
    expect(res.body.error.details).toEqual([{ field: 'file', issue: 'too_big' }]);
    expect(storage.calls.slice(before).some((call) => call.startsWith('GET '))).toBe(false);
  });

  it('declare validation: per-purpose byte limit, accepted types, strict body', async () => {
    const user = await signup(ctx);
    const cases: [unknown, { field: string; issue: string }][] = [
      [
        { purpose: 'avatar', contentType: 'image/jpeg', byteSize: 5_242_881 },
        { field: 'byteSize', issue: 'too_big' },
      ],
      [
        { purpose: 'room_cover', contentType: 'image/jpeg', byteSize: 10_485_761 },
        { field: 'byteSize', issue: 'too_big' },
      ],
      [
        { purpose: 'avatar', contentType: 'image/heic', byteSize: 10 },
        { field: 'contentType', issue: 'invalid_value' },
      ],
      [
        { purpose: 'avatar', contentType: 'image/svg+xml', byteSize: 10 },
        { field: 'contentType', issue: 'invalid_value' },
      ],
      [
        { purpose: 'banner', contentType: 'image/jpeg', byteSize: 10 },
        { field: 'purpose', issue: 'invalid_value' },
      ],
      [
        { purpose: 'avatar', contentType: 'image/jpeg', byteSize: 0 },
        { field: 'byteSize', issue: 'too_small' },
      ],
      [
        { purpose: 'avatar', contentType: 'image/jpeg', byteSize: 10, url: 'https://x' },
        { field: 'url', issue: 'unknown_field' },
      ],
    ];
    for (const [body, detail] of cases) {
      const res = await c.declare(user, body);
      expectContract(res, 'createMediaUpload');
      expect({ body, status: res.status, details: res.body.error?.details }).toEqual({
        body,
        status: 400,
        details: [detail],
      });
    }
    const cover = await c.declare(user, {
      purpose: 'room_cover',
      contentType: 'image/webp',
      byteSize: 10_485_760,
    });
    expect(cover.status).toBe(201);
  });

  it('pending-upload cap: the 6th AWAITING_UPLOAD → 429 with Retry-After until the oldest expires', async () => {
    const user = await signup(ctx);
    const other = await signup(ctx);
    const body = { purpose: 'avatar', contentType: 'image/jpeg', byteSize: 100 };
    for (let i = 0; i < 5; i += 1) expect((await c.declare(user, body)).status).toBe(201);
    const limited = await c.declare(user, body);
    expectContract(limited, 'createMediaUpload');
    expectError(limited, 429, 'RATE_LIMITED');
    expect(limited.headers['retry-after']).toBe('600');
    clock.advance(100);
    expect((await c.declare(user, body)).headers['retry-after']).toBe('500');
    expect((await c.declare(other, body)).status).toBe(201);
    // An expired upload no longer counts.
    clock.advance(501);
    expect((await c.declare(user, body)).status).toBe(201);
  });

  it('processing saturated → 503 SERVICE_UNAVAILABLE with Retry-After; nothing changes', async () => {
    const user = await signup(ctx);
    const declared = await c.declareAndPut(user, 'avatar', await jpeg(300, 300));
    const media: unknown = ctx.app.get(MediaService);
    const { processor } = media as { processor: { reserve(): { release(): void } } };
    const slots = [processor.reserve(), processor.reserve()]; // MEDIA_PROCESS_MAX_CONCURRENCY = 2
    try {
      const res = await c.complete(user, declared.body.uploadId);
      expectContract(res, 'completeMediaUpload');
      expectError(res, 503, 'SERVICE_UNAVAILABLE');
      expect(res.headers['retry-after']).toBe('10');
      expect((await c.getUpload(user, declared.body.uploadId)).body.status).toBe('AWAITING_UPLOAD');
    } finally {
      for (const slot of slots) slot.release();
    }
    await new Promise((resolve) => setImmediate(resolve));
    expect((await c.complete(user, declared.body.uploadId)).status).toBe(200);
  });

  it('storage unavailable → 503 SERVICE_UNAVAILABLE; the upload stays usable', async () => {
    const user = await signup(ctx);
    const declared = await c.declareAndPut(user, 'avatar', await jpeg(300, 300));
    storage.failing = true;
    try {
      const res = await c.complete(user, declared.body.uploadId);
      expectError(res, 503, 'SERVICE_UNAVAILABLE');
      expect(JSON.stringify(res.body)).not.toMatch(/storage unavailable/);
    } finally {
      storage.failing = false;
    }
    expect((await c.complete(user, declared.body.uploadId)).status).toBe(200);
  });

  it('concurrent completes process the image once and both get the same READY body', async () => {
    const user = await signup(ctx);
    const declared = await c.declareAndPut(user, 'avatar', await jpeg(400, 400));
    const [a, b] = await Promise.all([
      c.complete(user, declared.body.uploadId),
      c.complete(user, declared.body.uploadId),
    ]);
    const statuses = [a.status, b.status].sort();
    // Both 200, or one 200 and one 503 if both reached the processor at the same instant.
    expect(statuses[1]).toBe(200);
    if (statuses[0] === 200) expect(a.body).toEqual(b.body);
    expect(
      await ctx.prisma.auditLog.count({
        where: { action: 'media.upload.complete', targetId: declared.body.uploadId },
      }),
    ).toBe(1);
  });

  it('cleanup: an unattached READY upload is deleted after 24 h; FAILED rows go after 7 days', async () => {
    const user = await signup(ctx);
    const id = await c.ready(user, 'avatar');
    const token = (await ctx.prisma.mediaObject.findUniqueOrThrow({ where: { id } })).publicToken!;
    const failed = await c.declareAndPut(user, 'avatar', await jpeg(50, 50));
    expectError(await c.complete(user, failed.body.uploadId), 422, 'MEDIA_UPLOAD_REJECTED');
    const cleanup = ctx.app.get(MediaCleanupService);
    clock.advance(23 * HOUR);
    await cleanup.runCleanup();
    expect((await c.getUpload(user, id)).body.status).toBe('READY');
    clock.advance(HOUR + 1);
    const result = await cleanup.runCleanup();
    expect(result.stoppedBy).toBe('drained');
    expect((await c.getUpload(user, id)).body.status).toBe('DELETED');
    expect(storage.public.has(`a/${token}/512.webp`)).toBe(false);
    clock.advance(7 * 24 * HOUR);
    await cleanup.runCleanup();
    expectError(await c.getUpload(user, failed.body.uploadId), 404, 'NOT_FOUND');
  });

  it('cleanup: a detached avatar is deleted after the grace period, never before', async () => {
    const user = await signup(ctx);
    const first = await c.ready(user, 'avatar');
    const second = await c.ready(user, 'avatar');
    await c.patchMe(user, { avatarUploadId: first });
    await c.patchMe(user, { avatarUploadId: second });
    const cleanup = ctx.app.get(MediaCleanupService);
    clock.advance(23 * HOUR);
    await cleanup.runCleanup();
    expect((await c.getUpload(user, first)).body.status).toBe('READY');
    clock.advance(2 * HOUR);
    await cleanup.runCleanup();
    expect((await c.getUpload(user, first)).body.status).toBe('DELETED');
    // The current avatar is never touched.
    expect((await c.getUpload(user, second)).body).toMatchObject({ status: 'READY', attached: true });
    expect((await c.getMe(user)).body.avatarUrl).not.toBeNull();
  });

  it('account soft deletion: avatar detached at once, every stored object deleted by the cleanup job', async () => {
    const user = await signup(ctx);
    const avatar = await c.ready(user, 'avatar');
    await c.patchMe(user, { avatarUploadId: avatar });
    const loose = await c.ready(user, 'avatar');
    const tokens = await ctx.prisma.mediaObject.findMany({
      where: { ownerUserId: user.id },
      select: { publicToken: true },
    });
    expect(await ctx.app.get(AccountLifecycleService).softDelete(user.id)).toBe(true);
    const profileRow = await ctx.prisma.userProfile.findUniqueOrThrow({ where: { userId: user.id } });
    expect(profileRow.avatarMediaId).toBeNull();
    await ctx.app.get(MediaCleanupService).runCleanup();
    const rows = await ctx.prisma.mediaObject.findMany({ where: { id: { in: [avatar, loose] } } });
    expect(rows.map((r) => r.status).sort()).toEqual(['DELETED', 'DELETED']);
    for (const { publicToken } of tokens) expect(storage.public.has(`a/${publicToken}/512.webp`)).toBe(false);
  });
});

describe('KL-049 daily declared-bytes budget', () => {
  const app = mediaApp({ MEDIA_DAILY_BYTES_PER_USER: '10485760', MEDIA_MAX_PENDING_PER_USER: '20' });
  let ctx: TestContext;
  const c = client(() => ctx, app.storage);
  beforeAll(async () => {
    ctx = await app.create();
  });
  afterAll(async () => {
    await ctx?.close();
  });

  it('declared bytes are capped per user per day (429; a refused declare consumes nothing)', async () => {
    const user = await signup(ctx);
    const big = { purpose: 'avatar', contentType: 'image/jpeg', byteSize: 5_242_880 };
    expect((await c.declare(user, big)).status).toBe(201);
    expect((await c.declare(user, big)).status).toBe(201);
    const limited = await c.declare(user, { ...big, byteSize: 1 });
    expectContract(limited, 'createMediaUpload');
    expectError(limited, 429, 'RATE_LIMITED');
    expect(Number(limited.headers['retry-after'])).toBeGreaterThan(0);
    expect(await ctx.prisma.mediaObject.count({ where: { ownerUserId: user.id } })).toBe(2);
    expect((await c.declare(await signup(ctx), big)).status).toBe(201);
  });
});

describe('KL-049 moderation provider allow_all (dev/test only)', () => {
  const app = mediaApp({ MEDIA_MODERATION_PROVIDER: 'allow_all' });
  let ctx: TestContext;
  const c = client(() => ctx, app.storage);
  beforeAll(async () => {
    ctx = await app.create();
  });
  afterAll(async () => {
    await ctx?.close();
  });

  it('approves asynchronously after complete; other users then see the avatar', async () => {
    const owner = await signup(ctx);
    const viewer = await signup(ctx);
    const id = await c.ready(owner, 'avatar');
    await settle(ctx);
    const read = await c.getUpload(owner, id);
    expect(read.body.moderationStatus).toBe('APPROVED');
    const row = await ctx.prisma.mediaObject.findUniqueOrThrow({ where: { id } });
    expect(row.moderationSource).toBe('allow_all');
    await c.patchMe(owner, { avatarUploadId: id });
    expect((await c.profile(viewer, owner.username)).body.avatarUrl).toBe(read.body.url);
  });
});

describe('KL-049 room covers', () => {
  const app = mediaApp();
  const { clock, storage } = app;
  let ctx: TestContext;
  const c = client(() => ctx, storage);

  beforeAll(async () => {
    ctx = await app.create();
  });
  afterAll(async () => {
    await ctx?.close();
  });

  it('go-live with coverUploadId: the host sees the PENDING cover and its state; others see none', async () => {
    const host = await signup(ctx);
    const viewer = await signup(ctx);
    const cover = await c.ready(host, 'room_cover', await png(1200, 1600));
    const res = await c.startRoom(host, { title: 'Cover night', coverUploadId: cover });
    expectContract(res, 'startLiveRoom');
    expect(res.status).toBe(201);
    expect(res.body.coverUrl).toMatch(new RegExp(`^${MEDIA_BASE}/c/[A-Za-z0-9_-]{22}/960\\.webp$`));
    expect(res.body.coverThumbUrl).toMatch(/\/480\.webp$/);
    expect(res.body.coverModeration).toBe('PENDING');
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'media.cover.set', targetId: res.body.id } }),
    ).toBe(1);
    const asViewer = await c.getRoom(viewer, res.body.id);
    expectContract(asViewer, 'getLiveRoom');
    expect(asViewer.body).toMatchObject({ coverUrl: null, coverThumbUrl: null, coverModeration: null });
    const listed = await c.list(viewer, { tab: 'new' });
    expectContract(listed, 'listLiveRooms');
    expect(listed.body.data.find((r: { id: string }) => r.id === res.body.id)).toMatchObject({
      coverUrl: null,
    });
    await ctx.app.get(MediaService).applyModeration(cover, 'APPROVED', 'e2e');
    const approved = await c.getRoom(viewer, res.body.id);
    expect(approved.body).toMatchObject({ coverUrl: res.body.coverUrl, coverModeration: null });
    expect((await c.getRoom(host, res.body.id)).body.coverModeration).toBe('APPROVED');
    await ctx.http.post(`/api/v1/live/rooms/${res.body.id}/end`).set(bearer(host));
  });

  it('go-live refusals: invalid cover → 400 coverUploadId; already live → 409 and the cover stays unattached', async () => {
    const host = await signup(ctx);
    const avatar = await c.ready(host, 'avatar');
    for (const coverUploadId of [avatar, MISSING_ID]) {
      const res = await c.startRoom(host, { title: 'Bad cover', coverUploadId });
      expectContract(res, 'startLiveRoom');
      expect({ status: res.status, details: res.body.error?.details }).toEqual({
        status: 400,
        details: [{ field: 'coverUploadId', issue: 'invalid_value' }],
      });
    }
    expect((await c.startRoom(host, { title: 'First' })).status).toBe(201);
    const cover = await c.ready(host, 'room_cover');
    const conflict = await c.startRoom(host, { title: 'Second', coverUploadId: cover });
    expectError(conflict, 409, 'LIVE_ROOM_ALREADY_ACTIVE');
    expect((await c.getUpload(host, cover)).body.attached).toBe(false);
  });

  it('PUT cover: replace (old detached), remove, audited; host only; LIVE and fresh only', async () => {
    const host = await signup(ctx);
    const viewer = await signup(ctx);
    const first = await c.ready(host, 'room_cover');
    const room = (await c.startRoom(host, { title: 'Covers', coverUploadId: first })).body;
    const second = await c.ready(host, 'room_cover');
    const replaced = await c.setCover(host, room.id, { coverUploadId: second });
    expectContract(replaced, 'setLiveRoomCover');
    expect(replaced.status).toBe(200);
    expect(replaced.body.coverUrl).not.toBe(room.coverUrl);
    expect(
      (await ctx.prisma.mediaObject.findUniqueOrThrow({ where: { id: first } })).detachedAt,
    ).not.toBeNull();
    // Not the host / unknown / malformed → the same 404.
    const third = await c.ready(viewer, 'room_cover');
    const notHost = await c.setCover(viewer, room.id, { coverUploadId: third });
    expectContract(notHost, 'setLiveRoomCover');
    expectError(notHost, 404, 'NOT_FOUND');
    expectError(await c.setCover(host, MISSING_ID, { coverUploadId: null }), 404, 'NOT_FOUND');
    expectError(await c.setCover(host, 'not-a-uuid', { coverUploadId: null }), 404, 'NOT_FOUND');
    // Body schema.
    const missing = await c.setCover(host, room.id, {});
    expect({ status: missing.status, details: missing.body.error?.details }).toEqual({
      status: 400,
      details: [{ field: 'coverUploadId', issue: 'required' }],
    });
    // Someone else's or an avatar upload → 400.
    const avatar = await c.ready(host, 'avatar');
    for (const coverUploadId of [third, avatar]) {
      const res = await c.setCover(host, room.id, { coverUploadId });
      expect({ status: res.status, details: res.body.error?.details }).toEqual({
        status: 400,
        details: [{ field: 'coverUploadId', issue: 'invalid_value' }],
      });
    }
    const removed = await c.setCover(host, room.id, { coverUploadId: null });
    expect(removed.body).toMatchObject({ coverUrl: null, coverThumbUrl: null, coverModeration: null });
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'media.cover.remove', targetId: room.id } }),
    ).toBe(1);
    // Ended room → 409.
    await ctx.http.post(`/api/v1/live/rooms/${room.id}/end`).set(bearer(host));
    const ended = await c.setCover(host, room.id, { coverUploadId: null });
    expectContract(ended, 'setLiveRoomCover');
    expectError(ended, 409, 'LIVE_ROOM_ENDED');
  });

  it('PUT cover on a stale room → 409 LIVE_ROOM_ENDED and the room is ended as HEARTBEAT_TIMEOUT', async () => {
    const host = await signup(ctx);
    const room = (await c.startRoom(host, { title: 'Goes stale' })).body;
    clock.advance(46);
    const res = await c.setCover(host, room.id, { coverUploadId: null });
    expectError(res, 409, 'LIVE_ROOM_ENDED');
    expect((await c.getRoom(host, room.id)).body).toMatchObject({
      status: 'ENDED',
      endReason: 'HEARTBEAT_TIMEOUT',
    });
  });

  it('cleanup: the cover of an ended room is detached after 24 h, then deleted after the grace period', async () => {
    const host = await signup(ctx);
    const cover = await c.ready(host, 'room_cover');
    const room = (await c.startRoom(host, { title: 'Ending', coverUploadId: cover })).body;
    await ctx.http.post(`/api/v1/live/rooms/${room.id}/end`).set(bearer(host));
    const token = (await ctx.prisma.mediaObject.findUniqueOrThrow({ where: { id: cover } })).publicToken!;
    const cleanup = ctx.app.get(MediaCleanupService);
    clock.advance(23 * HOUR);
    await cleanup.runCleanup();
    expect((await c.getRoom(host, room.id)).body.coverUrl).not.toBeNull(); // "Live ended" still shows it
    clock.advance(HOUR + 1);
    await cleanup.runCleanup();
    expect((await c.getRoom(host, room.id)).body.coverUrl).toBeNull();
    expect(storage.public.has(`c/${token}/960.webp`)).toBe(true); // grace period
    clock.advance(24 * HOUR + 1);
    await cleanup.runCleanup();
    expect(storage.public.has(`c/${token}/960.webp`)).toBe(false);
    expect((await c.getUpload(host, cover)).body.status).toBe('DELETED');
  });
});

describe('KL-049 covers while live hosting is disabled', () => {
  const app = mediaApp({ LIVE_HOSTING_ENABLED: 'false' });
  let ctx: TestContext;
  const c = client(() => ctx, app.storage);
  beforeAll(async () => {
    ctx = await app.create();
  });
  afterAll(async () => {
    await ctx?.close();
  });

  it('declaring a room_cover → 503 LIVE_HOSTING_UNAVAILABLE; PUT cover → 503 before the ownership check', async () => {
    const user = await signup(ctx);
    const res = await c.declare(user, { purpose: 'room_cover', contentType: 'image/jpeg', byteSize: 1000 });
    expectContract(res, 'createMediaUpload');
    expectError(res, 503, 'LIVE_HOSTING_UNAVAILABLE');
    expect(
      (await c.declare(user, { purpose: 'avatar', contentType: 'image/jpeg', byteSize: 1000 })).status,
    ).toBe(201);
    const cover = await c.setCover(user, MISSING_ID, { coverUploadId: null });
    expectContract(cover, 'setLiveRoomCover');
    expectError(cover, 503, 'LIVE_HOSTING_UNAVAILABLE');
    const countries = await ctx.http.get('/api/v1/live/countries').set(bearer(user));
    expectContract(countries, 'listLiveCountries');
    expect(countries.body).toEqual({ data: [] });
  });
});

describe('KL-049 countries', () => {
  const clock = new FakeClock();
  let ctx: TestContext;
  const c = client(() => ctx, new InMemoryMediaStorage());

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true' }, [{ token: Clock, value: clock }]);
  });
  afterAll(async () => {
    await ctx?.close();
  });

  const endAll = () =>
    ctx.prisma
      .$executeRaw`UPDATE live_rooms SET status = 'ENDED', end_reason = 'HOST_ENDED', ended_at = last_heartbeat_at WHERE status = 'LIVE'`;

  it('GET /countries: the 249 vendored countries, localized and sorted (ar default, en by header or locale)', async () => {
    const ar = await signup(ctx, { locale: 'ar' });
    const en = await signup(ctx, { locale: 'en' });
    const arList = await ctx.http.get('/api/v1/countries').set(bearer(ar));
    expectContract(arList, 'listCountries');
    expect(arList.body.data).toHaveLength(249);
    expect(arList.body.data.find((x: { code: string }) => x.code === 'SA').name).toBe(
      'المملكة العربية السعودية',
    );
    const collator = new Intl.Collator('ar', { sensitivity: 'base' });
    const names = arList.body.data.map((x: { name: string }) => x.name) as string[];
    for (let i = 1; i < names.length; i += 1)
      expect(collator.compare(names[i - 1]!, names[i]!)).toBeLessThanOrEqual(0);
    const enList = await ctx.http.get('/api/v1/countries').set(bearer(en));
    expect(enList.body.data[0]).toEqual({ code: 'AF', name: 'Afghanistan' });
    const byHeader = await ctx.http.get('/api/v1/countries').set(bearer(ar)).set('Accept-Language', 'en-GB');
    expect(byHeader.body).toEqual(enList.body);
    expect(enList.body.data.some((x: { code: string }) => x.code === 'XK')).toBe(false);
  });

  it('PATCH /me country: set, validate, clear; public on the profile; audited without the value', async () => {
    const user = await signup(ctx);
    const viewer = await signup(ctx);
    expect((await c.getMe(user)).body.country).toBeNull();
    const set = await c.patchMe(user, { country: 'SA' });
    expectContract(set, 'updateMe');
    expect(set.body.country).toBe('SA');
    const shown = await c.profile(viewer, user.username);
    expectContract(shown, 'getPublicProfile');
    expect(shown.body.country).toBe('SA');
    for (const [country, issue] of [
      ['sa', 'invalid_format'],
      ['SAU', 'invalid_format'],
      ['', 'invalid_format'],
      ['XK', 'invalid_value'],
      ['ZZ', 'invalid_value'],
      ['EU', 'invalid_value'],
    ] as const) {
      const res = await c.patchMe(user, { country });
      expectContract(res, 'updateMe');
      expect({ country, status: res.status, details: res.body.error?.details }).toEqual({
        country,
        status: 400,
        details: [{ field: 'country', issue }],
      });
    }
    const empty = await c.patchMe(user, {});
    expect({ status: empty.status, details: empty.body.error?.details }).toEqual({
      status: 400,
      details: [{ field: '', issue: 'required' }],
    });
    const cleared = await c.patchMe(user, { country: null });
    expect(cleared.body.country).toBeNull();
    const audits = await ctx.prisma.auditLog.findMany({
      where: { action: 'users.country.update', actorUserId: user.id },
    });
    expect(audits).toHaveLength(2);
    for (const audit of audits) expect(JSON.stringify(audit.metadata ?? null)).not.toMatch(/SA/);
    // Setting the same value again changes nothing (no audit row).
    await c.patchMe(user, { country: null });
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'users.country.update', actorUserId: user.id } }),
    ).toBe(2);
  });

  it('room country: snapshot at go-live, synced while LIVE, frozen once ENDED', async () => {
    const host = await signup(ctx);
    await c.patchMe(host, { country: 'SA' });
    const room = await c.startRoom(host, { title: 'Country room' });
    expectContract(room, 'startLiveRoom');
    expect(room.body.country).toBe('SA');
    await c.patchMe(host, { country: 'EG' });
    expect((await c.getRoom(host, room.body.id)).body.country).toBe('EG');
    await c.patchMe(host, { country: null });
    expect((await c.getRoom(host, room.body.id)).body.country).toBeNull();
    await c.patchMe(host, { country: 'AE' });
    await ctx.http.post(`/api/v1/live/rooms/${room.body.id}/end`).set(bearer(host));
    await c.patchMe(host, { country: 'MA' });
    expect((await c.getRoom(host, room.body.id)).body.country).toBe('AE');
    // The request has no country field.
    const withCountry = await c.startRoom(host, { title: 'Nope', country: 'SA' });
    expect(withCountry.body.error?.details).toEqual([{ field: 'country', issue: 'unknown_field' }]);
  });

  it('GET /live/rooms?country: filters every tab, combines with category, validates, binds the cursor', async () => {
    await endAll();
    const viewer = await signup(ctx);
    const hosts: TestUser[] = [];
    for (const country of ['SA', 'SA', 'EG', null] as const) {
      const host = await signup(ctx);
      if (country) await c.patchMe(host, { country });
      expect((await c.startRoom(host, { title: `Room ${country ?? 'none'}` })).status).toBe(201);
      hosts.push(host);
      clock.advance(1);
    }
    const sa = await c.list(viewer, { tab: 'new', country: 'SA' });
    expectContract(sa, 'listLiveRooms');
    expect(sa.body.data.map((r: { country: string }) => r.country)).toEqual(['SA', 'SA']);
    expect((await c.list(viewer, { tab: 'popular', country: 'EG' })).body.data).toHaveLength(1);
    expect((await c.list(viewer, { tab: 'new' })).body.data).toHaveLength(4);
    expect((await c.list(viewer, { tab: 'new', country: 'IQ' })).body.data).toEqual([]);
    expect((await c.list(viewer, { tab: 'new', country: 'SA', category: 'music' })).body.data).toEqual([]);
    for (const [country, issue] of [
      ['sa', 'invalid_format'],
      ['SAU', 'invalid_format'],
      ['XK', 'invalid_value'],
    ] as const) {
      const res = await c.list(viewer, { tab: 'new', country });
      expectContract(res, 'listLiveRooms');
      expect({ status: res.status, details: res.body.error?.details }).toEqual({
        status: 400,
        details: [{ field: 'country', issue }],
      });
    }
    // Cursor v2 is bound to the country.
    const first = await c.list(viewer, { tab: 'new', country: 'SA', limit: 1 });
    expect(first.body.page.hasMore).toBe(true);
    const cursor = first.body.page.nextCursor as string;
    const next = await c.list(viewer, { tab: 'new', country: 'SA', limit: 1, cursor });
    expect(next.status).toBe(200);
    expect(next.body.data).toHaveLength(1);
    expect(next.body.data[0].id).not.toBe(first.body.data[0].id);
    for (const query of [
      { tab: 'new', limit: 1, cursor },
      { tab: 'new', country: 'EG', limit: 1, cursor },
    ] as Record<string, string | number>[]) {
      const res = await c.list(viewer, query);
      expect({ status: res.status, details: res.body.error?.details }).toEqual({
        status: 400,
        details: [{ field: 'cursor', issue: 'invalid_value' }],
      });
    }
    // A version-1 cursor (issued by v1.3) is still accepted for a request without country.
    const key = Buffer.from(hkdfSync('sha256', ctx.config.live.cursorKey, 'kabso', 'live-cursor/v1', 32));
    const lastRoom = first.body.data[0];
    const payload = Buffer.from(
      JSON.stringify({
        v: 1,
        t: 'new',
        c: null,
        u: null,
        n: 0,
        s: Date.parse(lastRoom.startedAt),
        i: lastRoom.id,
      }),
    ).toString('base64url');
    const tag = createHmac('sha256', key).update(`live-cursor\u0000${payload}`).digest().subarray(0, 16);
    const v1 = `${payload}.${tag.toString('base64url')}`;
    expect((await c.list(viewer, { tab: 'new', cursor: v1 })).status).toBe(200);
    expect((await c.list(viewer, { tab: 'new', country: 'SA', cursor: v1 })).status).toBe(400);
  });

  it('GET /live/countries: real counts of listed rooms, ordered, localized, cached ≤ 15 s', async () => {
    await endAll();
    clock.advance(20); // past the counts cache of earlier tests
    const viewer = await signup(ctx, { locale: 'en' });
    const add = async (country: string | null) => {
      const host = await signup(ctx);
      if (country) await c.patchMe(host, { country });
      const room = await c.startRoom(host, { title: `Count ${country ?? 'none'}` });
      expect(room.status).toBe(201);
      return { host, roomId: room.body.id as string };
    };
    await add('EG');
    await add('SA');
    await add('SA');
    await add('AE');
    await add(null);
    const suspended = await add('IQ');
    await ctx.app.get(AccountLifecycleService).suspend(suspended.host.id);
    clock.advance(16);
    const res = await ctx.http.get('/api/v1/live/countries').set(bearer(viewer));
    expectContract(res, 'listLiveCountries');
    expect(res.body).toEqual({
      data: [
        { code: 'SA', name: 'Saudi Arabia', liveRoomCount: 2 },
        { code: 'AE', name: 'United Arab Emirates', liveRoomCount: 1 },
        { code: 'EG', name: 'Egypt', liveRoomCount: 1 },
      ],
    });
    const ar = await ctx.http.get('/api/v1/live/countries').set(bearer(viewer)).set('Accept-Language', 'ar');
    expect(ar.body.data[0]).toEqual({ code: 'SA', name: 'المملكة العربية السعودية', liveRoomCount: 2 });
    // Cached: a new room is not counted until the cache window (15 s) has passed.
    await add('EG');
    expect((await ctx.http.get('/api/v1/live/countries').set(bearer(viewer))).body).toEqual(res.body);
    clock.advance(15);
    const fresh = await ctx.http.get('/api/v1/live/countries').set(bearer(viewer));
    expect(fresh.body.data.find((x: { code: string }) => x.code === 'EG').liveRoomCount).toBe(2);
    // Stale rooms are not counted (same predicate as the list).
    clock.advance(46);
    expect((await ctx.http.get('/api/v1/live/countries').set(bearer(viewer))).body).toEqual({ data: [] });
  });
});

describe('KL-049 SEC-039 text hygiene over HTTP (register and go-live)', () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true' });
  });
  afterAll(async () => {
    await ctx?.close();
  });

  const cp = (...points: number[]) => String.fromCodePoint(...points);

  it.each([
    ['Latin letter + U+FE00', `Sa${cp(0xfe00)}ra`],
    ['Arabic letter + U+E0100', `علي م${cp(0xe0100)}`],
    ['U+16FE4 inside a name', `Ali ${cp(0x16fe4)}Hassan`],
    ['U+2003 EM SPACE inside', `Ali${cp(0x2003)}Hassan`],
    ['U+205F inside', `Ali${cp(0x205f)}Hassan`],
    ['U+2764 + U+FE00', `Lina ${cp(0x2764, 0xfe00)}`],
    ['a listed sequence + a second selector', `Ali ${cp(0x31, 0xfe0e, 0xfe0e)}`],
  ])('rejects %s in displayName and title', async (_label, value) => {
    const reg = await ctx.http.post('/api/v1/auth/register').send({
      email: `sec039-${Date.now()}-${Math.random().toString(36).slice(2)}@example.com`,
      password: 'correct horse battery staple',
      username: `s39${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`,
      displayName: value,
      locale: 'en',
    });
    expect({ status: reg.status, details: reg.body.error?.details }).toEqual({
      status: 400,
      details: [{ field: 'displayName', issue: 'invalid_format' }],
    });
    const host = await signup(ctx);
    const room = await ctx.http.post('/api/v1/live/rooms').set(bearer(host)).send({ title: value });
    expect({ status: room.status, details: room.body.error?.details }).toEqual({
      status: 400,
      details: [{ field: 'title', issue: 'invalid_format' }],
    });
  });

  it.each([
    ['Japanese name with a registered IVS', `${cp(0x845b, 0xe0100)}飾 北斎`],
    ['U+2665 U+FE0E inside a name', `Ali ${cp(0x2665, 0xfe0e)} Lina`],
    ['keycap #️⃣', `Team ${cp(0x23, 0xfe0f, 0x20e3)}`],
    [
      'U+202F inside a Mongolian name',
      `${cp(0x1820, 0x182f, 0x1832, 0x1820, 0x1828)}${cp(0x202f)}${cp(0x1824)}`,
    ],
    ['U+3000 inside', `山田${cp(0x3000)}太郎`],
  ])('accepts %s in displayName and title', async (_label, value) => {
    const user = await signup(ctx, { displayName: value });
    const room = await ctx.http.post('/api/v1/live/rooms').set(bearer(user)).send({ title: value });
    expect(room.status).toBe(201);
    await ctx.http.post(`/api/v1/live/rooms/${room.body.id}/end`).set(bearer(user));
  });
});
