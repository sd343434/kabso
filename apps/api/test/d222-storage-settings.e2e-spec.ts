/**
 * D222 (owner 2026-11-01; contract v1.75-social, CONVENTIONS §10.72): the OWNER enters and turns on the media storage
 * (Cloudflare R2 or any S3) in the admin panel «التخزين (R2 / S3)». OWNER only; the code again and a reason for every
 * change, audited with the keys' last 4 only, sealed at rest; «اختبار الاتصال» — a real round trip on both buckets
 * (put, head, get, the public URL for the public bucket, «not public» for the private one, delete); panel over the env
 * `S3_*` and back; the S3 client swapped without a restart; the switch off → 503 «التخزين غير مفعّل»; the private
 * bucket never readable without a key.
 *
 * The S3 side is the production adapter (`S3ObjectStorage`, the real AWS SDK) against a local S3-compatible HTTP
 * server: `FakeS3` (test/helpers/fake-s3.ts) by default, or a real one (MinIO, moto) when `S3_TEST_ENDPOINT` is set
 * (`S3_TEST_ACCESS_KEY_ID` / `S3_TEST_SECRET_ACCESS_KEY`; the buckets are created, the public one with a public-read
 * policy). End to end against PostgreSQL + Redis.
 */
import { randomBytes } from 'node:crypto';
import {
  CreateBucketCommand,
  DeleteBucketPolicyCommand,
  HeadBucketCommand,
  ListObjectsV2Command,
  PutBucketPolicyCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { MediaService } from '../src/modules/media/media.service.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { FakeS3 } from './helpers/fake-s3.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, type TestContext } from './helpers/test-app.js';

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';
const REAL = process.env.S3_TEST_ENDPOINT;
/** Made-up keys built at run time (never real; nothing for a secret scanner to match). */
const ACCESS_KEY_ID = REAL
  ? (process.env.S3_TEST_ACCESS_KEY_ID ?? 'test')
  : `AKD222${randomBytes(6).toString('hex')}Ak1d`;
const SECRET = REAL
  ? (process.env.S3_TEST_SECRET_ACCESS_KEY ?? 'test')
  : `${randomBytes(16).toString('hex')}Sc4t`;
const run = randomBytes(3).toString('hex');
const PUB = `kabso-pub-${run}`;
const PUB2 = `kabso-pub2-${run}`;
const PRIV = `kabso-priv-${run}`;
const ENVB = `kabso-env-${run}`;

/** The S3 server under test: the fake one, or MinIO / moto at S3_TEST_ENDPOINT. */
interface Backend {
  endpoint: string;
  publicUrl(bucket: string): string;
  keys(bucket: string): Promise<string[]>;
  start(): Promise<void>;
  stop(): Promise<void>;
  /** Signed requests with these keys are refused (fake only). */
  fakeOnly: FakeS3 | null;
}

function backend(): Backend {
  if (!REAL) {
    const s3 = new FakeS3(ACCESS_KEY_ID, SECRET);
    return {
      get endpoint() {
        return s3.endpoint;
      },
      publicUrl: (b) => s3.publicUrl(b),
      keys: (b) => Promise.resolve(s3.keys(b)),
      start: async () => {
        await s3.start();
        for (const [b, pub] of [
          [PUB, true],
          [PUB2, true],
          [PRIV, false],
          [ENVB, false],
        ] as const) {
          s3.createBucket(b, pub);
        }
      },
      stop: () => s3.stop(),
      fakeOnly: s3,
    };
  }
  const client = new S3Client({
    endpoint: REAL,
    region: 'us-east-1',
    forcePathStyle: true,
    credentials: { accessKeyId: ACCESS_KEY_ID, secretAccessKey: SECRET },
  });
  return {
    endpoint: REAL,
    publicUrl: (b) => `${REAL}/${b}`,
    keys: async (b) =>
      ((await client.send(new ListObjectsV2Command({ Bucket: b }))).Contents ?? []).map((o) => o.Key!).sort(),
    start: async () => {
      for (const [b, pub] of [
        [PUB, true],
        [PUB2, true],
        [PRIV, false],
        [ENVB, false],
      ] as const) {
        try {
          await client.send(new HeadBucketCommand({ Bucket: b }));
        } catch {
          await client.send(new CreateBucketCommand({ Bucket: b }));
        }
        if (pub) {
          const Policy = JSON.stringify({
            Version: '2012-10-17',
            Statement: [
              { Effect: 'Allow', Principal: '*', Action: 's3:GetObject', Resource: `arn:aws:s3:::${b}/*` },
            ],
          });
          await client.send(new PutBucketPolicyCommand({ Bucket: b, Policy }));
        } else {
          await client.send(new DeleteBucketPolicyCommand({ Bucket: b })).catch(() => undefined);
        }
      }
    },
    stop: () => Promise.resolve(client.destroy()),
    fakeOnly: null,
  };
}

const s3 = backend();
const jpeg = () =>
  sharp({ create: { width: 64, height: 48, channels: 3, background: '#c33' } })
    .jpeg()
    .toBuffer();

describe('D222 contract coverage', () => {
  it('openapi v1.75-social declares the «التخزين (R2 / S3)» operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'getAdminStorageSettings GET /api/v1/admin/storage-settings',
      'updateAdminStorageSettings PATCH /api/v1/admin/storage-settings',
      'testAdminStorageSettings POST /api/v1/admin/storage-settings/test',
      'clearAdminStorageSettings POST /api/v1/admin/storage-settings/clear',
    ]) {
      expect(ids).toContain(op);
    }
  });
});

/** Uploads one JPEG through the API and the presigned URL; returns the slot and the completed asset. */
async function uploadPost(ctx: TestContext, user: Person) {
  const bytes = await jpeg();
  const slot = await ctx.http
    .post('/api/v1/media/uploads')
    .set('Authorization', `Bearer ${user.token}`)
    .send({ kind: 'POST_IMAGE', contentType: 'image/jpeg', byteSize: bytes.length });
  return { slot, bytes };
}

async function putAndComplete(
  ctx: TestContext,
  user: Person,
  slot: { body: Record<string, unknown> },
  bytes: Buffer,
) {
  const put = await fetch(slot.body.uploadUrl as string, {
    method: 'PUT',
    headers: slot.body.headers as Record<string, string>,
    body: bytes,
  });
  expect(put.status).toBe(200);
  return ctx.http
    .post(`/api/v1/media/uploads/${slot.body.uploadId as string}/complete`)
    .set('Authorization', `Bearer ${user.token}`);
}

describe('D222 «التخزين (R2 / S3)» on a server without S3 (staging today)', { timeout: 300_000 }, () => {
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let moderator: Admin;
  let support: Admin;
  let finance: Admin;
  let user: Person;

  const get = (a: Admin) => p.send(a, 'get', '/admin/storage-settings');
  const patch = (a: Admin, body: object) => p.send(a, 'patch', '/admin/storage-settings', body);
  const test = (a: Admin, body: object) => p.send(a, 'post', '/admin/storage-settings/test', body);
  const withCode = (a: Admin, body: object) => ({
    totpCode: p.nextCode(a.secret),
    reason: 'set up R2',
    ...body,
  });
  const full = () => ({
    provider: 'S3',
    endpoint: s3.endpoint,
    region: 'us-east-1',
    forcePathStyle: true,
    accessKeyId: ACCESS_KEY_ID,
    secretAccessKey: SECRET,
    publicBucket: PUB,
    publicBaseUrl: s3.publicUrl(PUB),
    privateBucket: PRIV,
  });
  const audits = (action: string) =>
    ctx.prisma.auditLog.findMany({ where: { action }, orderBy: { createdAt: 'asc' } });
  const expectNoSecret = (text: string) => {
    expect(text).not.toContain(SECRET);
    if (!REAL) expect(text).not.toContain(ACCESS_KEY_ID);
  };

  beforeAll(async () => {
    await s3.start();
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp({
      ADMIN_TOTP_KEY: ADMIN_KEY,
      ADMIN_SESSION_IDLE_SECONDS: '7200',
      ADMIN_SESSION_MAX_SECONDS: '28800',
      RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
      RATE_LIMIT_ADMIN_IP: '10000/900',
      MEDIA_UPLOADS_ENABLED: 'false',
    });
    owner = await p.makeAdmin(['OWNER']);
    moderator = await p.makeAdmin(['MODERATION']);
    support = await p.makeAdmin(['SUPPORT']);
    finance = await p.makeAdmin(['FINANCE']);
    user = await p.signup();
  });
  afterAll(async () => {
    await ctx?.prisma.storageSettings.deleteMany();
    await ctx?.close();
    await s3.stop();
    vi.useRealTimers();
  });

  it('OWNER only: MODERATION, SUPPORT and FINANCE are refused every operation; no session is 401', async () => {
    for (const a of [moderator, support, finance]) {
      expect((await get(a)).status).toBe(403);
      expect((await patch(a, withCode(a, { enabled: false }))).status).toBe(403);
      expect((await test(a, full())).status).toBe(403);
      expect((await p.send(a, 'post', '/admin/storage-settings/clear', withCode(a, {}))).status).toBe(403);
    }
    expect((await ctx.http.get('/api/v1/admin/storage-settings')).status).toBe(401);
    expect(await ctx.prisma.storageSettings.count()).toBe(0);
  });

  it('nothing configured: the section says so and every upload is 503 MEDIA_UPLOADS_UNAVAILABLE («التخزين غير مفعّل»)', async () => {
    const res = await get(owner);
    expect(res.status).toBe(200);
    expectContract(res, 'getAdminStorageSettings');
    expect(res.headers['cache-control']).toBe('no-store');
    expect(res.body).toMatchObject({
      status: 'not_configured',
      source: 'none',
      uploadsEnabled: false,
      enabled: false,
      lastTest: null,
      publicPrefix: 'media/',
      healthcheckPrefix: '_healthcheck/',
    });
    expect(res.body.panel.missing).toEqual([
      'accountId',
      'accessKeyId',
      'secretAccessKey',
      'publicBucket',
      'publicBaseUrl',
      'privateBucket',
    ]);
    const { slot } = await uploadPost(ctx, user);
    expect(slot.status).toBe(503);
    expect(slot.body.error.code).toBe('MEDIA_UPLOADS_UNAVAILABLE');
  });

  it('«اختبار الاتصال»: a real round trip on both buckets, nothing left behind, audited without the keys', async () => {
    const res = await test(owner, full());
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'testAdminStorageSettings');
    expect(res.body.ok).toBe(true);
    expect(
      res.body.steps.map(
        (s: { bucket: string; step: string; ok: boolean }) => `${s.bucket}.${s.step}:${s.ok}`,
      ),
    ).toEqual([
      'public.put:true',
      'public.head:true',
      'public.get:true',
      'public.public_read:true',
      'public.delete:true',
      'private.put:true',
      'private.head:true',
      'private.get:true',
      'private.not_public:true',
      'private.delete:true',
    ]);
    expect(res.body.accessKeyIdLast4).toBe(ACCESS_KEY_ID.slice(-4));
    expectNoSecret(JSON.stringify(res.body));
    expect((await s3.keys(PUB)).filter((k) => k.startsWith('_healthcheck/'))).toEqual([]);
    expect((await s3.keys(PRIV)).filter((k) => k.startsWith('_healthcheck/'))).toEqual([]);
    // Nothing saved but the result: still off, the result shown with who ran it.
    const after = (await get(owner)).body;
    expect(after.enabled).toBe(false);
    expect(after.panel.accessKeyId).toBeNull();
    expect(after.lastTest).toMatchObject({ ok: true, by: { id: owner.id } });
    const rows = await audits('storage.settings.test');
    expect(rows).toHaveLength(1);
    expect(rows[0]!.actorUserId).toBe(owner.id);
    expect(rows[0]!.metadata).toMatchObject({ result: 'ok', accessKeyId: `…${ACCESS_KEY_ID.slice(-4)}` });
    expectNoSecret(JSON.stringify(rows));
  });

  it('a failing test says which step and why: wrong key, missing bucket, public bucket not public, private bucket public', async () => {
    const failed = async (over: object) => {
      const res = await test(owner, { ...full(), ...over });
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      expect(res.body.ok).toBe(false);
      return (res.body.steps as { bucket: string; step: string; ok: boolean; issue: string | null }[]).filter(
        (s) => !s.ok,
      );
    };
    expect((await failed({ publicBucket: `kabso-missing-${run}` }))[0]).toMatchObject({
      bucket: 'public',
      step: 'put',
      issue: 'no_such_bucket',
    });
    // The private bucket as the "public URL": the public bucket's object is not there.
    expect((await failed({ publicBaseUrl: s3.publicUrl(PRIV) }))[0]).toMatchObject({
      bucket: 'public',
      step: 'public_read',
      issue: 'not_public',
    });
    // The public bucket named as the private one: readable without a key.
    expect((await failed({ privateBucket: PUB2 })).map((s) => `${s.bucket}.${s.step}:${s.issue}`)).toEqual([
      'private.not_public:publicly_readable',
    ]);
    if (s3.fakeOnly) {
      expect((await failed({ accessKeyId: 'AKWRONGKEY00000000' }))[0]).toMatchObject({
        step: 'put',
        issue: 'bad_credentials',
      });
      s3.fakeOnly.denied.add(PRIV);
      expect((await failed({}))[0]).toMatchObject({ bucket: 'private', step: 'put', issue: 'access_denied' });
      s3.fakeOnly.denied.clear();
    }
    const unreachable = await failed({ endpoint: 'http://127.0.0.1:1' });
    expect(unreachable[0]).toMatchObject({ step: 'put', issue: 'unreachable' });
    expect((await test(owner, { ...full(), privateBucket: PUB })).body.error.details[0]).toEqual({
      field: 'privateBucket',
      issue: 'same_bucket',
    });
    const missing = await test(owner, { provider: 'S3', endpoint: s3.endpoint });
    expect(missing.status).toBe(400);
  });

  it('every change needs the code again and a reason; turning on needs every field; the same bucket twice is refused', async () => {
    const noReason = await patch(owner, { ...full(), totpCode: p.nextCode(owner.secret) });
    expect(noReason.status).toBe(400);
    const wrong = await patch(owner, { ...full(), totpCode: '000000', reason: 'x' });
    expect(wrong.status).toBe(403);
    expect(wrong.body.error.code).toBe('ADMIN_TOTP_INVALID');
    const incomplete = await patch(
      owner,
      withCode(owner, { provider: 'S3', endpoint: s3.endpoint, enabled: true }),
    );
    expect(incomplete.status).toBe(409);
    expect(incomplete.body.error.details.map((d: { field: string }) => d.field)).toEqual([
      'accessKeyId',
      'secretAccessKey',
      'publicBucket',
      'publicBaseUrl',
      'privateBucket',
    ]);
    const same = await patch(owner, withCode(owner, { ...full(), privateBucket: PUB }));
    expect(same.status).toBe(409);
    expect(same.body.error.details[0].issue).toBe('same_bucket');
    expect(await ctx.prisma.storageSettings.findUnique({ where: { id: 1 } })).toMatchObject({
      accessKeyIdEnc: null,
      enabled: false,
    });
  });

  it('turning on runs the round trip first: a failing one saves nothing', async () => {
    const res = await patch(
      owner,
      withCode(owner, { ...full(), publicBaseUrl: s3.publicUrl(PRIV), enabled: true }),
    );
    expect(res.status).toBe(409);
    expect(res.body.error.details[0]).toEqual({ field: 'enabled', issue: 'storage_test_failed' });
    const row = await ctx.prisma.storageSettings.findUnique({ where: { id: 1 } });
    expect(row?.enabled).toBe(false);
    expect(row?.accessKeyIdEnc).toBeNull();
    expect(row?.lastTestOk).toBe(false);
    expect((await uploadPost(ctx, user)).slot.status).toBe(503);
  });

  it('saved and on: write-only keys (last 4 only, sealed at rest), audited masked; uploads work at once without a restart', async () => {
    const res = await patch(owner, withCode(owner, { ...full(), enabled: true }));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'updateAdminStorageSettings');
    expect(res.body).toMatchObject({
      status: 'active',
      source: 'panel',
      uploadsEnabled: true,
      enabled: true,
      publicBaseUrl: s3.publicUrl(PUB),
      panel: {
        provider: 'S3',
        publicBucket: PUB,
        privateBucket: PRIV,
        accessKeyId: { last4: ACCESS_KEY_ID.slice(-4), setBy: { id: owner.id } },
        secretAccessKey: { last4: SECRET.slice(-4), setBy: { id: owner.id } },
        missing: [],
      },
    });
    expectNoSecret(JSON.stringify(res.body));
    expectNoSecret(JSON.stringify((await get(owner)).body));
    const row = await ctx.prisma.storageSettings.findUniqueOrThrow({ where: { id: 1 } });
    expect(row.secretAccessKeyEnc).toMatch(/^v1\./);
    expectNoSecret(JSON.stringify(row));
    const [audit] = await audits('storage.settings.update');
    expect(audit!.metadata).toMatchObject({
      reason: 'set up R2',
      connectionTest: 'ok',
      before: { enabled: false, accessKeyId: null },
      after: {
        enabled: true,
        accessKeyId: `…${ACCESS_KEY_ID.slice(-4)}`,
        secretAccessKey: `…${SECRET.slice(-4)}`,
        publicBucket: PUB,
      },
    });
    expectNoSecret(JSON.stringify(await audits('storage.settings.update')));

    // The next upload: the raw bytes to the PRIVATE bucket, the processed images to the PUBLIC one, URLs on its base.
    const { slot, bytes } = await uploadPost(ctx, user);
    expect(slot.status, JSON.stringify(slot.body)).toBe(201);
    const signed = new URL(slot.body.uploadUrl as string);
    expect(`${signed.origin}`).toBe(new URL(s3.endpoint).origin);
    expect(signed.pathname).toBe(`/${PRIV}/uploads/${user.id}/${slot.body.uploadId as string}`);
    const done = await putAndComplete(ctx, user, slot, bytes);
    expect(done.status, JSON.stringify(done.body)).toBe(200);
    const id = slot.body.uploadId as string;
    expect(done.body.url).toBe(`${s3.publicUrl(PUB)}/media/${id}/1080.webp`);
    expect(await s3.keys(PUB)).toEqual(
      expect.arrayContaining([`media/${id}/1080.webp`, `media/${id}/320.webp`]),
    );
    expect((await s3.keys(PUB)).some((k) => k.startsWith('uploads/'))).toBe(false);
    expect((await s3.keys(PRIV)).some((k) => k.includes(id))).toBe(false); // the raw upload deleted
    const pub = await fetch(done.body.url as string);
    expect(pub.status).toBe(200);
    expect((await sharp(Buffer.from(await pub.arrayBuffer())).metadata()).format).toBe('webp');
  });

  it('private pictures (ID photos, payment proofs) stay in the private bucket and are never readable without a key', async () => {
    const bytes = await jpeg();
    const slot = await ctx.http
      .post('/api/v1/media/uploads')
      .set('Authorization', `Bearer ${user.token}`)
      .send({ kind: 'RECHARGE_AGENT_PHOTO', contentType: 'image/jpeg', byteSize: bytes.length });
    expect(slot.status, JSON.stringify(slot.body)).toBe(201);
    const put = await fetch(slot.body.uploadUrl as string, {
      method: 'PUT',
      headers: slot.body.headers,
      body: bytes,
    });
    expect(put.status).toBe(200);
    const key = `private/recharge-agents/d222-${run}/photo.webp`;
    const consumed = await ctx.app
      .get(MediaService)
      .consumePrivateImage(user.id, slot.body.uploadId as string, 'RECHARGE_AGENT_PHOTO', key);
    expect(consumed).toBe(true);
    expect(await s3.keys(PRIV)).toContain(key);
    expect(await s3.keys(PUB)).not.toContain(key);
    for (const url of [`${s3.publicUrl(PUB)}/${key}`, `${s3.endpoint}/${PRIV}/${key}`]) {
      expect((await fetch(url)).status, url).not.toBe(200);
    }
  });

  it('hot swap: a new public bucket is used by the next request; an upload signed before the swap still completes', async () => {
    const before = await uploadPost(ctx, user);
    expect(before.slot.status).toBe(201);
    const res = await patch(
      owner,
      withCode(owner, { publicBucket: PUB2, publicBaseUrl: s3.publicUrl(PUB2) }),
    );
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expect(res.body.publicBaseUrl).toBe(s3.publicUrl(PUB2));
    const [, second] = await audits('storage.settings.update');
    expect(second!.metadata).toMatchObject({
      changed: ['publicBucket', 'publicBaseUrl'],
      connectionTest: 'ok',
    });
    // The slot signed before the swap: its raw bytes are in the (unchanged) private bucket; it completes in the new one.
    const done = await putAndComplete(ctx, user, before.slot, before.bytes);
    expect(done.status, JSON.stringify(done.body)).toBe(200);
    const id = before.slot.body.uploadId as string;
    expect(done.body.url).toBe(`${s3.publicUrl(PUB2)}/media/${id}/1080.webp`);
    expect(await s3.keys(PUB2)).toContain(`media/${id}/1080.webp`);
  });

  it('switched off: uploads are 503 again at once; on again (tested again); clear removes the panel settings', async () => {
    const off = await patch(owner, withCode(owner, { enabled: false }));
    expect(off.status).toBe(200);
    expect(off.body).toMatchObject({ status: 'off', source: 'none', uploadsEnabled: false, enabled: false });
    expect((await uploadPost(ctx, user)).slot.status).toBe(503);
    const tests = (await audits('storage.settings.test')).length;
    const on = await patch(owner, withCode(owner, { enabled: true }));
    expect(on.status).toBe(200);
    expect((await audits('storage.settings.test')).length).toBe(tests + 1);
    expect((await uploadPost(ctx, user)).slot.status).toBe(201);
    const clear = await p.send(owner, 'post', '/admin/storage-settings/clear', withCode(owner, {}));
    expect(clear.status).toBe(200);
    expectContract(clear, 'clearAdminStorageSettings');
    expect(clear.body).toMatchObject({
      status: 'not_configured',
      enabled: false,
      panel: { accessKeyId: null, secretAccessKey: null },
    });
    expect((await uploadPost(ctx, user)).slot.status).toBe(503);
    const again = await p.send(owner, 'post', '/admin/storage-settings/clear', withCode(owner, {}));
    expect(again.status).toBe(409);
    expect(again.body.error.details[0].issue).toBe('storage_nothing_to_clear');
    expect((await audits('storage.settings.clear'))[0]!.metadata).toMatchObject({ fallback: 'none' });
  });
});

describe('D222 panel over the env S3_* (an existing deployment keeps working)', { timeout: 300_000 }, () => {
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let user: Person;
  const withCode = (a: Admin, body: object) => ({
    totpCode: p.nextCode(a.secret),
    reason: 'move to R2',
    ...body,
  });

  beforeAll(async () => {
    await s3.start();
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp({
      ADMIN_TOTP_KEY: ADMIN_KEY,
      ADMIN_SESSION_IDLE_SECONDS: '7200',
      ADMIN_SESSION_MAX_SECONDS: '28800',
      RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
      RATE_LIMIT_ADMIN_IP: '10000/900',
      MEDIA_UPLOADS_ENABLED: 'true',
      S3_ENDPOINT: s3.endpoint,
      S3_REGION: 'us-east-1',
      S3_BUCKET: ENVB,
      S3_ACCESS_KEY_ID: ACCESS_KEY_ID,
      S3_SECRET_ACCESS_KEY: SECRET,
      S3_FORCE_PATH_STYLE: 'true',
      MEDIA_PUBLIC_BASE_URL: 'https://env-media.example.test',
    });
    owner = await p.makeAdmin(['OWNER']);
    user = await p.signup();
  });
  afterAll(async () => {
    await ctx?.prisma.storageSettings.deleteMany();
    await ctx?.close();
    await s3.stop();
    vi.useRealTimers();
  });

  it('env first, the panel over it once on, the env again when off', async () => {
    const view = await p.send(owner, 'get', '/admin/storage-settings');
    expect(view.body).toMatchObject({
      status: 'env',
      source: 'env',
      uploadsEnabled: true,
      env: { configured: true, bucket: ENVB, accessKeyIdLast4: ACCESS_KEY_ID.slice(-4) },
    });
    expectContract(view, 'getAdminStorageSettings');
    const envSlot = await uploadPost(ctx, user);
    expect(new URL(envSlot.slot.body.uploadUrl as string).pathname.startsWith(`/${ENVB}/uploads/`)).toBe(
      true,
    );

    const on = await p.send(
      owner,
      'patch',
      '/admin/storage-settings',
      withCode(owner, {
        provider: 'S3',
        endpoint: s3.endpoint,
        region: 'us-east-1',
        forcePathStyle: true,
        accessKeyId: ACCESS_KEY_ID,
        secretAccessKey: SECRET,
        publicBucket: PUB,
        publicBaseUrl: s3.publicUrl(PUB),
        privateBucket: PRIV,
        enabled: true,
      }),
    );
    expect(on.status, JSON.stringify(on.body)).toBe(200);
    expect(on.body.source).toBe('panel');
    const panelSlot = await uploadPost(ctx, user);
    expect(new URL(panelSlot.slot.body.uploadUrl as string).pathname.startsWith(`/${PRIV}/uploads/`)).toBe(
      true,
    );
    const done = await putAndComplete(ctx, user, panelSlot.slot, panelSlot.bytes);
    expect(done.body.url.startsWith(`${s3.publicUrl(PUB)}/media/`)).toBe(true);

    const off = await p.send(owner, 'patch', '/admin/storage-settings', withCode(owner, { enabled: false }));
    expect(off.body).toMatchObject({ status: 'env', source: 'env', uploadsEnabled: true, enabled: false });
    const back = await uploadPost(ctx, user);
    expect(new URL(back.slot.body.uploadUrl as string).pathname.startsWith(`/${ENVB}/uploads/`)).toBe(true);
    const envDone = await putAndComplete(ctx, user, back.slot, back.bytes);
    expect(envDone.body.url.startsWith('https://env-media.example.test/media/')).toBe(true);
  });
});
