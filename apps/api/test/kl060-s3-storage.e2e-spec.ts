/**
 * KL-060: the production S3ObjectStorage adapter against a real S3-compatible server (MinIO in
 * docker-compose, R2 in the cloud). Opt-in: runs only when S3_TEST_ENDPOINT is set, e.g.
 *   S3_TEST_ENDPOINT=http://127.0.0.1:9000 S3_TEST_ACCESS_KEY_ID=… S3_TEST_SECRET_ACCESS_KEY=…
 * The bucket `kabso-media-e2e` is created when missing. Nothing here is mocked.
 */
import { CreateBucketCommand, HeadBucketCommand, S3Client } from '@aws-sdk/client-s3';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { loadConfig } from '../src/config/app-config.js';
import { S3ObjectStorage } from '../src/modules/media/s3-object-storage.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

const endpoint = process.env.S3_TEST_ENDPOINT;
const accessKeyId = process.env.S3_TEST_ACCESS_KEY_ID ?? 'test';
const secretAccessKey = process.env.S3_TEST_SECRET_ACCESS_KEY ?? 'test';
const bucket = 'kabso-media-e2e';

const s3Env = {
  MEDIA_UPLOADS_ENABLED: 'true',
  S3_ENDPOINT: endpoint ?? 'http://127.0.0.1:1',
  S3_REGION: 'us-east-1',
  S3_BUCKET: bucket,
  S3_ACCESS_KEY_ID: accessKeyId,
  S3_SECRET_ACCESS_KEY: secretAccessKey,
  S3_FORCE_PATH_STYLE: 'true',
  MEDIA_PUBLIC_BASE_URL: `${endpoint ?? 'http://127.0.0.1:1'}/${bucket}`,
};

describe.skipIf(!endpoint)('KL-060 S3ObjectStorage against a real S3-compatible server', () => {
  let storage: S3ObjectStorage;
  let ctx: TestContext;

  beforeAll(async () => {
    const client = new S3Client({
      endpoint,
      region: 'us-east-1',
      forcePathStyle: true,
      credentials: { accessKeyId, secretAccessKey },
    });
    try {
      await client.send(new HeadBucketCommand({ Bucket: bucket }));
    } catch {
      await client.send(new CreateBucketCommand({ Bucket: bucket }));
    }
    storage = new S3ObjectStorage(
      loadConfig({
        DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
        REDIS_URL: 'redis://localhost:6379',
        JWT_ACCESS_SECRET: 'x'.repeat(48),
        APP_PUBLIC_URL: 'http://localhost:3000',
        ...s3Env,
      }),
    );
    ctx = await createTestApp(s3Env);
  });
  afterAll(async () => ctx?.close());

  it('presigned PUT, head, get, put and delete', async () => {
    const key = `uploads/test/${Date.now()}`;
    const body = Buffer.from('hello kabso');
    const signed = await storage.presignPut(key, 'image/jpeg', body.length, 60);
    const put = await fetch(signed.url, { method: 'PUT', headers: signed.headers, body });
    expect(put.status).toBe(200);
    expect(await storage.head(key)).toEqual({ size: body.length });
    expect(await storage.get(key, 1024)).toEqual(body);
    expect(await storage.get(key, 3)).toBeNull();
    await storage.put(`${key}.webp`, body, 'image/webp', 'public, max-age=60');
    await storage.delete([key, `${key}.webp`, `${key}.missing`]);
    expect(await storage.head(key)).toBeNull();
    expect(await storage.get(`${key}.webp`, 1024)).toBeNull();
  });

  it('the whole upload flow through the API with the production adapter', async () => {
    const { res } = await registerVerified(ctx);
    const token = res.body.tokens.accessToken as string;
    const bytes = await sharp({ create: { width: 640, height: 480, channels: 3, background: '#c33' } })
      .jpeg()
      .toBuffer();
    const slot = await ctx.http
      .post('/api/v1/media/uploads')
      .set('Authorization', `Bearer ${token}`)
      .send({ kind: 'POST_IMAGE', contentType: 'image/jpeg', byteSize: bytes.length });
    expect(slot.status).toBe(201);
    const put = await fetch(slot.body.uploadUrl, { method: 'PUT', headers: slot.body.headers, body: bytes });
    expect(put.status).toBe(200);
    const done = await ctx.http
      .post(`/api/v1/media/uploads/${slot.body.uploadId}/complete`)
      .set('Authorization', `Bearer ${token}`);
    expect(done.status).toBe(200);
    expect(done.body).toMatchObject({ width: 640, height: 480, status: 'READY' });
    expect(done.body.url).toBe(`${s3Env.MEDIA_PUBLIC_BASE_URL}/media/${slot.body.uploadId}/1080.webp`);
    // Read through the adapter: the bucket is private; public reads go through the CDN or a
    // public-read rule on `media/` only (docs/DEPLOYMENT.md), never on `uploads/`.
    const large = await storage.get(`media/${slot.body.uploadId}/1080.webp`, 5_000_000);
    expect((await sharp(large!).metadata()).format).toBe('webp');
    expect(await storage.head(`uploads/${res.body.user.id}/${slot.body.uploadId}`)).toBeNull();
  });
});
