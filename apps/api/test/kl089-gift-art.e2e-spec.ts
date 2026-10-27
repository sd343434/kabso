/**
 * D126 (owner 2026-10-26): gift art hosted in object storage and downloaded by the app on demand
 * (openapi v1.26.2-live DRAFT, CONVENTIONS §10.23), end to end against PostgreSQL + Redis with the
 * API as the DML-only runtime role.
 *
 * `gift-admin add|update --image <file> --animation-file <file>` runs as on the server (a child
 * process with the migration role) and uploads through the production S3 adapter to a minimal
 * S3-compatible HTTP server in this process (path-style PUTs recorded with their headers), so the
 * Content-Type and Cache-Control the bucket receives are checked, not assumed. The CLI runs
 * asynchronously (the fake server lives on this process's event loop). The catalogue and the
 * bag then answer the public URLs under `MEDIA_PUBLIC_BASE_URL`.
 */
import { execFile } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { createServer, type IncomingHttpHeaders, type Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { deflateSync } from 'node:zlib';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { grantStockIn } from '../src/modules/gifts/gift-catalogue.js';
import { expectContract } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

const BASE = 'https://media.example.test';
const BUCKET = 'kabso-gift-art-test';

interface StoredPut {
  readonly body: Buffer;
  readonly headers: IncomingHttpHeaders;
}

/** Just enough of S3 for PutObject (path style): records every object and its headers. */
function fakeS3(): Promise<{ server: Server; endpoint: string; objects: Map<string, StoredPut> }> {
  const objects = new Map<string, StoredPut>();
  const server = createServer((req, res) => {
    const chunks: Buffer[] = [];
    req.on('data', (c: Buffer) => chunks.push(c));
    req.on('end', () => {
      const path = decodeURIComponent(new URL(req.url ?? '/', 'http://x').pathname);
      if (req.method === 'PUT' && path.startsWith(`/${BUCKET}/`)) {
        const body = Buffer.concat(chunks);
        objects.set(path.slice(BUCKET.length + 2), { body, headers: req.headers });
        res.writeHead(200, { ETag: `"${createHash('md5').update(body).digest('hex')}"` });
        res.end();
        return;
      }
      res.writeHead(400, { 'Content-Type': 'application/xml' });
      res.end('<Error><Code>InvalidRequest</Code></Error>');
    });
  });
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address() as AddressInfo;
      resolve({ server, endpoint: `http://127.0.0.1:${String(port)}`, objects });
    });
  });
}

describe('D126 gift art', { timeout: 180_000 }, () => {
  let ctx: TestContext;
  let s3: Awaited<ReturnType<typeof fakeS3>>;
  let dir: string;
  let token: string;
  let userId: string;
  const code = `art_${String(Date.now()).slice(-8)}`;

  /** `pnpm gift:admin …` with the storage settings of the API (or without them). */
  const giftAdmin = (
    args: string[],
    storage = true,
  ): Promise<{ status: number; out: string; err: string }> => {
    const env: NodeJS.ProcessEnv = { ...process.env };
    for (const k of [
      'S3_ENDPOINT',
      'S3_BUCKET',
      'S3_ACCESS_KEY_ID',
      'S3_SECRET_ACCESS_KEY',
      'MEDIA_PUBLIC_BASE_URL',
    ]) {
      delete env[k];
    }
    if (storage) {
      Object.assign(env, {
        S3_ENDPOINT: s3.endpoint,
        S3_REGION: 'auto',
        S3_BUCKET: BUCKET,
        S3_ACCESS_KEY_ID: 'test',
        S3_SECRET_ACCESS_KEY: 'test',
        S3_FORCE_PATH_STYLE: 'true',
        MEDIA_PUBLIC_BASE_URL: BASE,
      });
    }
    return new Promise((resolve) => {
      execFile(
        'pnpm',
        ['-s', 'gift:admin', ...args],
        { cwd: fileURLToPath(new URL('..', import.meta.url)), env, encoding: 'utf8' },
        (error, stdout, stderr) => {
          resolve({ status: error ? Number(error.code ?? 1) : 0, out: stdout, err: stderr });
        },
      );
    });
  };
  const file = (name: string, body: Buffer) => {
    const path = join(dir, name);
    writeFileSync(path, body);
    return path;
  };
  const sha = (b: Buffer) => createHash('sha256').update(b).digest('hex').slice(0, 32);
  const catalogueGift = async () => {
    const res = await ctx.http
      .get('/api/v1/gifts/catalogue')
      .set({ Authorization: `Bearer ${token}` })
      .set('Accept-Language', 'en');
    expect(res.status).toBe(200);
    expectContract(res, 'getGiftCatalogue');
    return (res.body.data as Record<string, unknown>[]).find((g) => g.code === code);
  };

  beforeAll(async () => {
    s3 = await fakeS3();
    dir = mkdtempSync(join(tmpdir(), 'gift-art-'));
    ctx = await createTestApp({
      MEDIA_UPLOADS_ENABLED: 'true',
      S3_BUCKET: BUCKET,
      S3_ACCESS_KEY_ID: 'test',
      S3_SECRET_ACCESS_KEY: 'test',
      MEDIA_PUBLIC_BASE_URL: BASE,
    });
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    token = res.body.tokens.accessToken as string;
    userId = res.body.user.id as string;
  });
  afterAll(async () => {
    await ctx?.close();
    s3?.server.close();
    if (dir) rmSync(dir, { recursive: true, force: true });
  });

  it('add uploads the image and the SVGA (types, immutable cache) and the catalogue answers their URLs', async () => {
    const image = await sharp({
      create: { width: 300, height: 300, channels: 4, background: { r: 240, g: 200, b: 60, alpha: 0.8 } },
    })
      .png()
      .toBuffer();
    const movie = deflateSync(
      Buffer.concat([Buffer.from([0x0a, 0x05]), Buffer.from('2.1.0'), Buffer.alloc(4096, 7)]),
    );
    const add = await giftAdmin([
      'add',
      code,
      '--category',
      'FUN',
      '--name-ar',
      'الملاك المحارب',
      '--name-en',
      'Angel Warrior',
      '--price',
      '50',
      '--asset',
      'gift_angel_warrior',
      '--tag',
      'luxury',
      '--tag-ar',
      'فخامة',
      '--tag-en',
      'Luxury',
      '--image',
      file('angel.png', image),
      '--animation-file',
      file('angel.svga', movie),
    ]);
    expect(add.status, add.err).toBe(0);
    const imageKey = `media/gifts/${code}/${sha(image)}.png`;
    const movieKey = `media/gifts/${code}/${sha(movie)}.svga`;
    expect(add.out).toContain(
      `uploaded image ${BASE}/${imageKey} (image/png, ${String(image.length)} bytes)`,
    );
    expect(add.out).toContain(
      `uploaded animation ${BASE}/${movieKey} (application/octet-stream, ${String(movie.length)} bytes)`,
    );
    expect(add.out).toContain(`+${code} (FUN, 50 coins).`);

    const putImage = s3.objects.get(imageKey)!;
    expect(putImage.body.equals(image)).toBe(true);
    expect(putImage.headers['content-type']).toBe('image/png');
    expect(putImage.headers['cache-control']).toBe('public, max-age=31536000, immutable');
    const putMovie = s3.objects.get(movieKey)!;
    expect(putMovie.body.equals(movie)).toBe(true);
    expect(putMovie.headers['content-type']).toBe('application/octet-stream');
    expect(putMovie.headers['cache-control']).toBe('public, max-age=31536000, immutable');

    expect(await catalogueGift()).toMatchObject({
      name: 'Angel Warrior',
      priceCoins: 50,
      category: 'FUN',
      assetKey: 'gift_angel_warrior',
      animationKey: null,
      imageUrl: `${BASE}/${imageKey}`,
      animationUrl: `${BASE}/${movieKey}`,
      animationBytes: movie.length,
      tag: { code: 'luxury', name: 'Luxury' },
    });

    // The bag carries the same art.
    await withMigrationClient((c) => c.$transaction((tx) => grantStockIn(tx, userId, code, 3)));
    const bag = await ctx.http.get('/api/v1/me/gifts/bag').set({ Authorization: `Bearer ${token}` });
    expect(bag.status).toBe(200);
    expectContract(bag, 'getMyGiftBag');
    expect((bag.body.data as Record<string, unknown>[]).find((g) => g.code === code)).toMatchObject({
      imageUrl: `${BASE}/${imageKey}`,
      animationUrl: `${BASE}/${movieKey}`,
      animationBytes: movie.length,
      quantity: 3,
    });

    const listed = await giftAdmin(['list']);
    expect(listed.out).toContain(
      `image=${imageKey} animation-file=${movieKey} (${String(movie.length)} bytes)\n`,
    );
    const audit = await withMigrationClient((c) =>
      c.auditLog.findFirstOrThrow({ where: { action: 'gift.add', targetId: code } }),
    );
    expect(audit.metadata).toMatchObject({ imageObjectKey: imageKey, animationObjectKey: movieKey });
  });

  it('refuses bad files and missing storage before changing anything; none clears; version moves', async () => {
    const before = await catalogueGift();
    const version = async () =>
      (await ctx.http.get('/api/v1/gifts/catalogue').set({ Authorization: `Bearer ${token}` })).body
        .version as string;
    const v0 = await version();
    const puts = s3.objects.size;

    const wide = await sharp({ create: { width: 400, height: 200, channels: 3, background: '#fff' } })
      .png()
      .toBuffer();
    expect((await giftAdmin(['update', code, '--image', file('wide.png', wide)])).err).toContain(
      'about square',
    );
    expect(
      (await giftAdmin(['update', code, '--animation-file', file('a.zip', Buffer.from('PK\u0003\u0004zip'))]))
        .err,
    ).toContain('SVGA 1.x');
    expect((await giftAdmin(['update', code, '--image', join(dir, 'missing.png')])).err).toContain(
      'mount its folder',
    );
    const square = await sharp({ create: { width: 128, height: 128, channels: 4, background: '#123456' } })
      .webp()
      .toBuffer();
    const noStorage = await giftAdmin(['update', code, '--image', file('sq.webp', square)], false);
    expect(noStorage.status).toBe(1);
    expect(noStorage.err).toContain('S3_BUCKET');
    expect((await giftAdmin(['add', code, '--image', 'none'])).status).toBe(1);
    expect((await giftAdmin(['update', 'no_such_gift', '--image', file('sq2.webp', square)])).err).toContain(
      'No gift',
    );
    expect(s3.objects.size).toBe(puts);
    expect(await catalogueGift()).toEqual(before);

    const webp = await giftAdmin(['update', code, '--image', file('sq3.webp', square)]);
    expect(webp.status, webp.err).toBe(0);
    expect(webp.out).toContain(`${code}: imageObjectKey updated.`);
    expect((await catalogueGift())?.imageUrl).toBe(`${BASE}/media/gifts/${code}/${sha(square)}.webp`);
    expect(s3.objects.get(`media/gifts/${code}/${sha(square)}.webp`)?.headers['content-type']).toBe(
      'image/webp',
    );
    const v1 = await version();
    expect(v1).not.toBe(v0);

    const cleared = await giftAdmin(['update', code, '--image', 'none', '--animation-file', 'none']);
    expect(cleared.out).toBe(`${code}: imageObjectKey, animationObjectKey, animationBytes updated.\n`);
    expect(await catalogueGift()).toMatchObject({ imageUrl: null, animationUrl: null, animationBytes: null });
    expect(await version()).not.toBe(v1);
    expect((await giftAdmin(['update', code, '--image', 'none'])).out).toBe(`${code}: nothing changed.\n`);
  });
});
