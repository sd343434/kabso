import { inspect } from 'node:util';
import {
  CopyObjectCommand,
  type DeleteObjectsCommand,
  PutObjectCommand,
  type S3Client,
} from '@aws-sdk/client-s3';
import pino from 'pino';
import { describe, expect, it } from 'vitest';
import { REDACT_PATHS } from '../../logging/logger.options.js';
import { AdminSecretBox } from '../admin-panel/admin-crypto.js';
import { bucketForKey, S3ObjectStorage } from '../media/s3-object-storage.js';
import { newPaymentSecretBox } from '../payment-settings/payment-settings.rules.js';
import {
  issueOfError,
  missingFields,
  newStorageSecretBox,
  r2Endpoint,
  resolveStorageSettings,
  STORAGE_AAD,
  targetOf,
  testStorageSettingsSchema,
  updateStorageSettingsSchema,
  type StorageSettingsRow,
} from './storage-settings.rules.js';
import { STORAGE_SETTINGS_CACHE_MS, StorageSettingsStore } from './storage-settings.store.js';

// Made-up values (never real keys).
const ADMIN_KEY = 'unit-admin-totp-key-0123456789-abcdefghijklmnop';
const ACCOUNT = '0123456789abcdef0123456789abcdef';
const PANEL_ID = ['unitpanelaccesskey', 'Ak1d'].join('');
const PANEL_SECRET = ['unitpanelsecretaccesskey0000000000', 'Sc4t'].join('');
const ENV_ID = 'unitenvaccesskeyid';
const ENV_SECRET = 'unitenvsecretaccesskey00000000000';

const envConfig = (over: Partial<{ uploadsEnabled: boolean; bucket: string | undefined }> = {}) => ({
  media: {
    uploadsEnabled: over.uploadsEnabled ?? true,
    s3: {
      endpoint: 'http://127.0.0.1:9000',
      region: 'us-east-1',
      bucket: 'bucket' in over ? over.bucket : 'kabso-media-env',
      accessKeyId: ENV_ID,
      secretAccessKey: ENV_SECRET,
      forcePathStyle: true,
    },
    publicBaseUrl: 'https://env-media.example.test',
    sweepIntervalSeconds: 0,
  },
});

function rowWith(box: AdminSecretBox, over: Partial<StorageSettingsRow> = {}): StorageSettingsRow {
  return {
    enabled: true,
    provider: 'R2',
    accountId: ACCOUNT,
    endpoint: null,
    region: null,
    forcePathStyle: false,
    accessKeyIdEnc: box.seal(PANEL_ID, STORAGE_AAD.accessKeyId),
    accessKeyIdLast4: PANEL_ID.slice(-4),
    accessKeyIdSetById: null,
    accessKeyIdSetAt: null,
    secretAccessKeyEnc: box.seal(PANEL_SECRET, STORAGE_AAD.secretAccessKey),
    secretAccessKeyLast4: PANEL_SECRET.slice(-4),
    secretAccessKeySetById: null,
    secretAccessKeySetAt: null,
    publicBucket: 'kabso-media',
    publicBaseUrl: 'https://media.kabsolive.com',
    privateBucket: 'kabso-private',
    lastTestAt: null,
    lastTestOk: null,
    lastTestById: null,
    lastTest: null,
    updatedAt: new Date('2026-11-01T10:00:00Z'),
    ...over,
  };
}

describe('D222 storage keys at rest', () => {
  it('seal / open with the storage-settings/v1 key; the TOTP and Stripe keys, another column or ADMIN_TOTP_KEY cannot open', () => {
    const box = newStorageSecretBox(ADMIN_KEY)!;
    const sealed = box.seal(PANEL_SECRET, STORAGE_AAD.secretAccessKey);
    expect(sealed).not.toContain(PANEL_SECRET);
    expect(box.open(sealed, STORAGE_AAD.secretAccessKey)).toBe(PANEL_SECRET);
    expect(box.open(sealed, STORAGE_AAD.accessKeyId)).toBeNull();
    expect(newPaymentSecretBox(ADMIN_KEY)!.open(sealed, STORAGE_AAD.secretAccessKey)).toBeNull();
    expect(new AdminSecretBox(ADMIN_KEY).open(sealed, STORAGE_AAD.secretAccessKey)).toBeNull();
    expect(newStorageSecretBox(`${ADMIN_KEY}x`)!.open(sealed, STORAGE_AAD.secretAccessKey)).toBeNull();
    expect(newStorageSecretBox(null)).toBeNull();
  });
});

describe('D222 resolution: the panel over the env', () => {
  const box = newStorageSecretBox(ADMIN_KEY)!;

  it('no row, or the switch off: exactly the env (S3_*, MEDIA_PUBLIC_BASE_URL, MEDIA_UPLOADS_ENABLED)', () => {
    for (const row of [null, rowWith(box, { enabled: false })]) {
      const r = resolveStorageSettings(row, envConfig(), box);
      expect(r.source).toBe('env');
      expect(r.uploadsEnabled).toBe(true);
      expect(r.publicBaseUrl).toBe('https://env-media.example.test');
      expect(r.s3?.bucket).toBe('kabso-media-env');
      expect(r.s3?.privateBucket).toBeNull();
    }
    const off = resolveStorageSettings(null, envConfig({ uploadsEnabled: false, bucket: undefined }), box);
    expect(off).toMatchObject({ source: 'none', uploadsEnabled: false, s3: null });
  });

  it('switch on and complete: R2 endpoint from the account id, region auto, two buckets, uploads on', () => {
    const r = resolveStorageSettings(rowWith(box), envConfig({ uploadsEnabled: false }), box);
    expect(r.source).toBe('panel');
    expect(r.uploadsEnabled).toBe(true);
    expect(r.publicBaseUrl).toBe('https://media.kabsolive.com');
    expect(r.s3).toMatchObject({
      endpoint: r2Endpoint(ACCOUNT),
      region: 'auto',
      bucket: 'kabso-media',
      privateBucket: 'kabso-private',
      forcePathStyle: false,
    });
    expect(r.s3?.accessKeyId.reveal()).toBe(PANEL_ID);
    expect(r.s3?.secretAccessKey.reveal()).toBe(PANEL_SECRET);
    expect(r2Endpoint(ACCOUNT)).toBe(`https://${ACCOUNT}.r2.cloudflarestorage.com`);
  });

  it('generic S3: the endpoint, region and path style typed', () => {
    const t = targetOf({
      ...rowWith(box),
      provider: 'S3',
      endpoint: 'https://s3.eu-central-1.amazonaws.com',
      region: 'eu-central-1',
      forcePathStyle: true,
    });
    expect(t).toMatchObject({
      accountId: null,
      endpoint: 'https://s3.eu-central-1.amazonaws.com',
      region: 'eu-central-1',
      forcePathStyle: true,
    });
    // R2 ignores a typed endpoint (it is derived).
    expect(targetOf({ ...rowWith(box), endpoint: 'https://evil.example' }).endpoint).toBe(
      r2Endpoint(ACCOUNT),
    );
  });

  it('keys sealed with another ADMIN_TOTP_KEY: the env applies, flagged unreadable', () => {
    const other = newStorageSecretBox(`${ADMIN_KEY}-other`)!;
    const r = resolveStorageSettings(rowWith(other), envConfig(), box);
    expect(r.source).toBe('env');
    expect(r.panelIgnored).toBe('unreadable');
  });

  it('missing fields are listed (the private bucket is required)', () => {
    const t = targetOf({ ...rowWith(box), accountId: null, privateBucket: null });
    expect(missingFields(t, { accessKeyId: true, secretAccessKey: false })).toEqual([
      'accountId',
      'secretAccessKey',
      'privateBucket',
    ]);
  });

  it('the resolved settings never print or serialise a key', () => {
    const r = resolveStorageSettings(rowWith(box), envConfig(), box);
    for (const text of [JSON.stringify(r), inspect(r, { depth: 5 }), String(r.s3?.secretAccessKey)]) {
      expect(text).not.toContain(PANEL_SECRET);
      expect(text).not.toContain(PANEL_ID);
    }
  });

  it('log lines drop accessKeyId / secretAccessKey fields', () => {
    const lines: string[] = [];
    const logger = pino(
      { redact: { paths: REDACT_PATHS, censor: '[REDACTED]' } },
      { write: (l: string) => lines.push(l) },
    );
    logger.info({ body: { accessKeyId: PANEL_ID, secretAccessKey: PANEL_SECRET } }, 'x');
    logger.info({ accessKeyId: PANEL_ID, secretAccessKey: PANEL_SECRET }, 'y');
    expect(lines.join('')).not.toContain(PANEL_SECRET);
    expect(lines.join('')).not.toContain(PANEL_ID);
  });
});

describe('D222 request shapes', () => {
  const base = { totpCode: '123456', reason: 'set up R2' };
  it('accepts a full R2 setup; trims the base URL slash; refuses bad buckets, account ids and URLs', () => {
    const ok = updateStorageSettingsSchema.safeParse({
      ...base,
      provider: 'R2',
      accountId: ACCOUNT.toUpperCase(),
      accessKeyId: PANEL_ID,
      secretAccessKey: PANEL_SECRET,
      publicBucket: 'kabso-media',
      publicBaseUrl: 'https://media.kabsolive.com/',
      privateBucket: 'kabso-private',
      enabled: true,
    });
    expect(ok.success).toBe(true);
    expect(ok.data?.publicBaseUrl).toBe('https://media.kabsolive.com');
    expect(ok.data?.accountId).toBe(ACCOUNT);
    for (const bad of [
      { publicBucket: 'Kabso_Media' },
      { privateBucket: 'ab' },
      { accountId: 'not-an-account' },
      { publicBaseUrl: 'https://media.kabsolive.com/?x=1' },
      { publicBaseUrl: 'ftp://media.kabsolive.com' },
      { endpoint: 'https://user:pw@s3.example.test' },
      { secretAccessKey: 'short' },
      { provider: 'GCS' },
      { unknown: true },
    ]) {
      expect(updateStorageSettingsSchema.safeParse({ ...base, ...bad }).success, JSON.stringify(bad)).toBe(
        false,
      );
    }
    expect(updateStorageSettingsSchema.safeParse(base).success).toBe(false); // nothing to change
    expect(updateStorageSettingsSchema.safeParse({ enabled: false }).success).toBe(false); // no code / reason
    expect(testStorageSettingsSchema.safeParse({ totpCode: '123456' }).success).toBe(false);
  });

  it('maps S3 errors to the panel issues', () => {
    expect(issueOfError({ name: 'InvalidAccessKeyId', $metadata: { httpStatusCode: 403 } }).issue).toBe(
      'bad_credentials',
    );
    expect(issueOfError({ name: 'SignatureDoesNotMatch', $metadata: { httpStatusCode: 403 } }).issue).toBe(
      'bad_credentials',
    );
    expect(issueOfError({ name: 'AccessDenied', $metadata: { httpStatusCode: 403 } }).issue).toBe(
      'access_denied',
    );
    expect(issueOfError({ name: 'NoSuchBucket', $metadata: { httpStatusCode: 404 } }).issue).toBe(
      'no_such_bucket',
    );
    expect(
      issueOfError(Object.assign(new Error('connect ECONNREFUSED 127.0.0.1:1'), { name: 'Error' })).issue,
    ).toBe('unreachable');
    expect(issueOfError({ name: 'InternalError', $metadata: { httpStatusCode: 500 } })).toEqual({
      issue: 'error',
      detail: 'InternalError (500)',
    });
  });
});

describe('D222 the adapter routes keys to the two buckets', () => {
  it('media/ → public; uploads/, private/ and the rest → private; one bucket when there is no private one', () => {
    const two = { bucket: 'pub', privateBucket: 'priv' };
    expect(bucketForKey(two, 'media/x/1080.webp')).toBe('pub');
    expect(bucketForKey(two, 'uploads/u/x')).toBe('priv');
    expect(bucketForKey(two, 'private/host-applications/a/photo.webp')).toBe('priv');
    expect(bucketForKey(two, 'mediax/evil')).toBe('priv');
    expect(bucketForKey({ bucket: 'one', privateBucket: null }, 'private/x')).toBe('one');
  });

  it('put, copy (between the buckets) and delete (grouped per bucket) name the right bucket', async () => {
    const sent: unknown[] = [];
    const client = { send: (c: unknown) => (sent.push(c), Promise.resolve({})) } as unknown as S3Client;
    const s = new S3ObjectStorage(
      {
        endpoint: 'http://127.0.0.1:1',
        region: 'auto',
        bucket: 'pub',
        privateBucket: 'priv',
        accessKeyId: 'k',
        secretAccessKey: 's',
        forcePathStyle: true,
      },
      client,
    );
    await s.put('private/recharge-orders/o/m.webp', Buffer.from('x'), 'image/webp', 'private, no-store');
    await s.copy('uploads/u/v', 'media/v/video.mp4', 'video/mp4', 'public');
    await s.delete(['media/a/1080.webp', 'uploads/u/1', 'media/a/320.webp', 'private/p/x']);
    const put = sent[0] as PutObjectCommand;
    expect(put).toBeInstanceOf(PutObjectCommand);
    expect(put.input.Bucket).toBe('priv');
    const copy = sent[1] as CopyObjectCommand;
    expect(copy).toBeInstanceOf(CopyObjectCommand);
    expect(copy.input.Bucket).toBe('pub');
    expect(copy.input.CopySource).toBe('priv/uploads/u/v');
    const dels = sent.slice(2) as DeleteObjectsCommand[];
    expect(dels.map((d) => [d.input.Bucket, d.input.Delete?.Objects?.map((o) => o.Key)])).toEqual([
      ['pub', ['media/a/1080.webp', 'media/a/320.webp']],
      ['priv', ['uploads/u/1', 'private/p/x']],
    ]);
  });

  it('presigned uploads go to the private bucket', async () => {
    const s = new S3ObjectStorage({
      endpoint: 'http://127.0.0.1:9',
      region: 'us-east-1',
      bucket: 'pub',
      privateBucket: 'priv',
      accessKeyId: 'AKIDEXAMPLE',
      secretAccessKey: 'unit-secret-unit-secret',
      forcePathStyle: true,
    });
    const signed = await s.presignPut('uploads/u/1', 'image/jpeg', 10, 60);
    expect(new URL(signed.url).pathname).toBe('/priv/uploads/u/1');
  });
});

describe('D222 the store: hot swap without a restart', () => {
  it('one storage per settings; this instance at once after reload, others within the cache time; current() never waits', async () => {
    const box = newStorageSecretBox(ADMIN_KEY)!;
    let row: StorageSettingsRow | null = null;
    let reads = 0;
    const prisma = {
      storageSettings: {
        findUnique: () => {
          reads += 1;
          return Promise.resolve(row);
        },
      },
    };
    let now = Date.parse('2026-11-01T10:00:00Z');
    const clock = { now: () => new Date(now) };
    const config = { env: 'test', adminPanel: { totpKey: ADMIN_KEY }, ...envConfig() };
    const store = new StorageSettingsStore(prisma as never, clock, config as never);

    expect(store.current().source).toBe('env'); // before any read: the env
    await store.onModuleInit();
    const envStorage = await store.active();
    expect(await store.active()).toBe(envStorage);
    expect(envStorage.settings?.bucket).toBe('kabso-media-env');
    expect(reads).toBe(1);

    // The OWNER turns the panel's storage on: this instance at once.
    row = rowWith(box);
    await store.reload();
    const panel = await store.active();
    expect(panel).not.toBe(envStorage);
    expect(panel.settings).toMatchObject({ bucket: 'kabso-media', privateBucket: 'kabso-private' });
    expect(store.current().publicBaseUrl).toBe('https://media.kabsolive.com');

    // Another instance's change: seen after the cache time (current() refreshes in the background).
    row = rowWith(box, { publicBucket: 'kabso-media-2', publicBaseUrl: 'https://cdn.kabsolive.com' });
    expect(await store.active()).toBe(panel);
    now += STORAGE_SETTINGS_CACHE_MS;
    expect(store.current().publicBaseUrl).toBe('https://media.kabsolive.com'); // the snapshot, no wait
    await store.resolved();
    expect(store.current().publicBaseUrl).toBe('https://cdn.kabsolive.com');
    const swapped = await store.active();
    expect(swapped).not.toBe(panel);
    expect(swapped.settings?.bucket).toBe('kabso-media-2');

    // Switched off: back to the env.
    row = { ...row, enabled: false };
    await store.reload();
    expect((await store.active()).settings?.bucket).toBe('kabso-media-env');
  });

  it('a database failure at start keeps the env (no crash)', async () => {
    const prisma = { storageSettings: { findUnique: () => Promise.reject(new Error('no table')) } };
    const store = new StorageSettingsStore(prisma as never, { now: () => new Date() }, {
      env: 'test',
      adminPanel: { totpKey: null },
      ...envConfig(),
    } as never);
    await store.onModuleInit();
    expect(store.current().source).toBe('env');
  });
});
