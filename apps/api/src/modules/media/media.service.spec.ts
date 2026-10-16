import 'reflect-metadata';
import { randomBytes } from 'node:crypto';
import { Test } from '@nestjs/testing';
import { describe, expect, it, vi } from 'vitest';
import { InMemoryMediaStorage } from '../../../test/helpers/in-memory-media-storage.js';
import { AppModule } from '../../app.module.js';
import { SystemClock } from '../../common/time/clock.js';
import { loadConfig, type AppConfig } from '../../config/app-config.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { REDIS } from '../../redis/redis.module.js';
import { MEDIA_MODERATION, NoModeration } from './media-moderation.js';
import { MEDIA_STORAGE } from './media-storage.js';
import { MediaUrls } from './media-urls.js';
import { MediaService } from './media.service.js';
import { S3MediaStorage } from './s3-media-storage.js';

const BASE_ENV = {
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  JWT_ACCESS_SECRET: randomBytes(48).toString('base64url'),
  APP_PUBLIC_URL: 'https://api.kabso.example',
};

/** A complete storage configuration with fake values (no provider is contacted). */
const STORAGE_ENV = {
  MEDIA_STORAGE_ENDPOINT: 'https://account.r2.example.invalid',
  MEDIA_STORAGE_REGION: 'auto',
  MEDIA_STORAGE_INCOMING_BUCKET: 'kabso-incoming-test',
  MEDIA_STORAGE_PUBLIC_BUCKET: 'kabso-public-test',
  // Generated per run: never commit a secret-like literal (gitleaks).
  MEDIA_STORAGE_ACCESS_KEY_ID: `test${randomBytes(8).toString('hex')}`,
  MEDIA_STORAGE_SECRET_ACCESS_KEY: randomBytes(30).toString('base64url'),
  MEDIA_PUBLIC_BASE_URL: 'https://media.kabso.example',
};

function service(config: AppConfig, prisma: unknown = {}) {
  return new MediaService(
    prisma as PrismaService,
    { recordIn: vi.fn() } as never,
    { consumeAmount: vi.fn(), refundAmount: vi.fn() } as never,
    { run: vi.fn(), idle: vi.fn() } as never,
    new SystemClock(),
    new MediaUrls(config.media.publicBaseUrl),
    config.media.storage ? new InMemoryMediaStorage() : null,
    new NoModeration(),
    config,
  );
}

const USER = '0192f1c2-7a10-7c3e-9d2a-3b4c5d6e7f80';

describe('MediaService feature gate and request checks (no database reached)', () => {
  it('uploads are disabled by default: config says so and every write path answers 503', async () => {
    const config = loadConfig(BASE_ENV);
    expect(config.media.uploadsEnabled).toBe(false);
    expect(config.media.storage).toBeNull();
    const media = service(
      config,
      new Proxy(
        {},
        {
          get: () => {
            throw new Error('database must not be reached');
          },
        },
      ),
    );
    expect(media.getConfig()).toEqual({
      uploadsEnabled: false,
      allowedContentTypes: ['image/jpeg', 'image/png', 'image/webp'],
      maxPixels: 40_000_000,
      maxSidePixels: 8192,
      purposes: {
        avatar: { maxBytes: 5_242_880, minWidth: 128, minHeight: 128, aspectRatio: '1:1' },
        room_cover: { maxBytes: 10_485_760, minWidth: 480, minHeight: 640, aspectRatio: '3:4' },
      },
    });
    await expect(
      media.createUpload(USER, { purpose: 'avatar', contentType: 'image/jpeg', byteSize: 10 }),
    ).rejects.toMatchObject({
      code: 'MEDIA_UPLOADS_UNAVAILABLE',
      status: 503,
      headers: undefined,
    });
    // The gate comes before body validation.
    await expect(media.createUpload(USER, { nonsense: true })).rejects.toMatchObject({
      code: 'MEDIA_UPLOADS_UNAVAILABLE',
    });
    await expect(media.completeUpload(USER, USER, { ip: null, requestId: null })).rejects.toMatchObject({
      code: 'MEDIA_UPLOADS_UNAVAILABLE',
    });
    expect(() => media.assertUploadsEnabled()).toThrow();
  });

  it('enabled: body validation, the per-purpose byte limit, then the live-hosting gate for covers', async () => {
    const config = loadConfig({ ...BASE_ENV, ...STORAGE_ENV, MEDIA_UPLOADS_ENABLED: 'true' });
    const media = service(
      config,
      new Proxy(
        {},
        {
          get: () => {
            throw new Error('database must not be reached');
          },
        },
      ),
    );
    expect(media.getConfig().uploadsEnabled).toBe(true);
    const details = async (body: unknown) => {
      try {
        await media.createUpload(USER, body);
      } catch (err) {
        return { code: (err as { code: string }).code, details: (err as { details?: unknown }).details };
      }
      throw new Error('expected a rejection');
    };
    expect(await details({})).toEqual({
      code: 'VALIDATION_FAILED',
      details: [
        { field: 'purpose', issue: 'required' },
        { field: 'contentType', issue: 'required' },
        { field: 'byteSize', issue: 'required' },
      ],
    });
    expect(await details({ purpose: 'avatar', contentType: 'image/heic', byteSize: 1 })).toMatchObject({
      details: [{ field: 'contentType', issue: 'invalid_value' }],
    });
    expect(await details({ purpose: 'avatar', contentType: 'image/jpeg', byteSize: 5_242_881 })).toEqual({
      code: 'VALIDATION_FAILED',
      details: [{ field: 'byteSize', issue: 'too_big' }],
    });
    expect(
      await details({ purpose: 'avatar', contentType: 'image/jpeg', byteSize: 10_485_761 }),
    ).toMatchObject({
      details: [{ field: 'byteSize', issue: 'too_big' }],
    });
    expect(await details({ purpose: 'avatar', contentType: 'image/jpeg', byteSize: 0 })).toMatchObject({
      details: [{ field: 'byteSize', issue: 'too_small' }],
    });
    expect(await details({ purpose: 'avatar', contentType: 'image/jpeg', byteSize: 1.5 })).toMatchObject({
      details: [{ field: 'byteSize', issue: 'invalid_type' }],
    });
    expect(
      await details({ purpose: 'avatar', contentType: 'image/jpeg', byteSize: 10, url: 'https://x' }),
    ).toMatchObject({
      details: [{ field: 'url', issue: 'unknown_field' }],
    });
    // LIVE_HOSTING_ENABLED=false (default): no covers are stored while nobody can go live.
    expect(await details({ purpose: 'room_cover', contentType: 'image/png', byteSize: 10 })).toMatchObject({
      code: 'LIVE_HOSTING_UNAVAILABLE',
    });
  });

  it('malformed or foreign upload ids are not found without querying by a bad id', async () => {
    const config = loadConfig({ ...BASE_ENV, ...STORAGE_ENV, MEDIA_UPLOADS_ENABLED: 'true' });
    const findFirst = vi.fn(() => Promise.resolve(null));
    const media = service(config, { mediaObject: { findFirst } });
    await expect(media.getUpload(USER, 'not-a-uuid')).rejects.toMatchObject({ code: 'NOT_FOUND' });
    await expect(media.getUpload(USER, "'; DROP TABLE x; --")).rejects.toMatchObject({ code: 'NOT_FOUND' });
    expect(findFirst).not.toHaveBeenCalled();
    await expect(media.getUpload(USER, '0192f1e0-2222-7bbb-8ccc-0d0e0f101112')).rejects.toMatchObject({
      code: 'NOT_FOUND',
    });
    expect(findFirst).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: '0192f1e0-2222-7bbb-8ccc-0d0e0f101112', ownerUserId: USER } }),
    );
  });
});

describe('MediaModule wiring', () => {
  async function compile(env: Record<string, string>) {
    const config = loadConfig({ ...BASE_ENV, ...env });
    const moduleRef = await Test.createTestingModule({ imports: [AppModule.register(config)] })
      .overrideProvider(PrismaService)
      .useValue({})
      .overrideProvider(REDIS)
      .useValue({ status: 'ready', quit: () => Promise.resolve() })
      .compile();
    return moduleRef;
  }

  it('resolves the whole application graph; no storage adapter without a storage configuration', async () => {
    const moduleRef = await compile({});
    expect(moduleRef.get(MEDIA_STORAGE)).toBeNull();
    expect(moduleRef.get(MEDIA_MODERATION)).toBeInstanceOf(NoModeration);
    expect(moduleRef.get(MediaService).uploadsEnabled).toBe(false);
  });

  it('builds the S3 adapter from a complete storage configuration (without contacting it)', async () => {
    const moduleRef = await compile({ ...STORAGE_ENV, MEDIA_UPLOADS_ENABLED: 'true' });
    expect(moduleRef.get(MEDIA_STORAGE)).toBeInstanceOf(S3MediaStorage);
    expect(moduleRef.get(MediaService).uploadsEnabled).toBe(true);
  });
});
