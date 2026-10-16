import { randomBytes } from 'node:crypto';
import { Readable } from 'node:stream';
import { describe, expect, it } from 'vitest';
import type { MediaStorageConfig } from '../../config/app-config.js';
import { StoredObjectTooLargeError } from './media-storage.js';
import { S3MediaStorage } from './s3-media-storage.js';

/**
 * The S3 adapter against a LOCAL STUB of the HTTP layer (the SDK's `requestHandler`): every
 * request the SDK would send is captured and answered from memory, so no network is used and no
 * provider is contacted. This checks the request shapes the adapter produces (method, bucket,
 * key, Range, headers, signature) and how it reads the answers. The in-memory fake of the storage
 * PORT (test/helpers/in-memory-media-storage.ts) is what the e2e tests use instead.
 */

const CONFIG: MediaStorageConfig = {
  endpoint: 'https://account.r2.example.invalid',
  region: 'auto',
  forcePathStyle: true,
  incomingBucket: 'kabso-incoming-test',
  publicBucket: 'kabso-public-test',
  // Generated per run: never commit a secret-like literal (gitleaks).
  accessKeyId: `test${randomBytes(8).toString('hex')}`,
  secretAccessKey: randomBytes(30).toString('base64url'),
};

interface Captured {
  method: string;
  path: string;
  headers: Record<string, string>;
  body: Buffer | null;
}

type Responder = (req: Captured) => { status: number; headers?: Record<string, string>; body?: Buffer };

async function bodyOf(body: unknown): Promise<Buffer | null> {
  if (body === undefined || body === null) return null;
  if (typeof body === 'string') return Buffer.from(body);
  if (body instanceof Uint8Array) return Buffer.from(body);
  const chunks: Buffer[] = [];
  for await (const chunk of body as AsyncIterable<Uint8Array>) chunks.push(Buffer.from(chunk));
  return Buffer.concat(chunks);
}

function stubbed(respond: Responder) {
  const requests: Captured[] = [];
  const requestHandler = {
    async handle(request: { method: string; path: string; headers: Record<string, string>; body?: unknown }) {
      const captured: Captured = {
        method: request.method,
        path: request.path,
        headers: Object.fromEntries(Object.entries(request.headers).map(([k, v]) => [k.toLowerCase(), v])),
        body: await bodyOf(request.body),
      };
      requests.push(captured);
      const answer = respond(captured);
      return {
        response: {
          statusCode: answer.status,
          headers: answer.headers ?? {},
          body: Readable.from(answer.body ? [answer.body] : []),
        },
      };
    },
    updateHttpClientConfig() {},
    httpHandlerConfigs() {
      return {};
    },
  };
  const storage = new S3MediaStorage(CONFIG, { requestHandler: requestHandler as never, maxAttempts: 1 });
  return { storage, requests };
}

describe('S3MediaStorage presigned PUT (CONVENTIONS §11.3)', () => {
  it('signs one PUT for one incoming key with Content-Type and Content-Length, offline', async () => {
    const { storage, requests } = stubbed(() => ({ status: 500 }));
    const signed = await storage.presignPut(
      'in/0192f1e0-2222-7bbb-8ccc-0d0e0f101112/abc',
      'image/jpeg',
      734003,
      600,
    );
    expect(requests).toHaveLength(0); // presigning never talks to the provider
    const url = new URL(signed.url);
    expect(url.protocol).toBe('https:');
    expect(url.host).toBe('account.r2.example.invalid');
    expect(url.pathname).toBe('/kabso-incoming-test/in/0192f1e0-2222-7bbb-8ccc-0d0e0f101112/abc');
    expect(url.searchParams.get('X-Amz-Algorithm')).toBe('AWS4-HMAC-SHA256');
    expect(url.searchParams.get('X-Amz-Expires')).toBe('600');
    expect(url.searchParams.get('X-Amz-SignedHeaders')).toBe('content-length;content-type;host');
    expect(url.searchParams.get('X-Amz-Signature')).toMatch(/^[0-9a-f]{64}$/);
    // No SDK checksum parameters (R2 and mobile clients cannot satisfy them).
    expect([...url.searchParams.keys()].filter((k) => /checksum/i.test(k))).toEqual([]);
    expect(signed.url).not.toContain(CONFIG.secretAccessKey);
    expect(signed.headers).toEqual({ 'Content-Type': 'image/jpeg', 'Content-Length': '734003' });
  });

  it('a different size or type gives a different signature', async () => {
    const { storage } = stubbed(() => ({ status: 500 }));
    const sig = async (type: string, size: number) =>
      new URL((await storage.presignPut('in/x/y', type, size, 600)).url).searchParams.get('X-Amz-Signature');
    const base = await sig('image/jpeg', 1000);
    expect(await sig('image/jpeg', 1001)).not.toBe(base);
    expect(await sig('image/png', 1000)).not.toBe(base);
  });
});

describe('S3MediaStorage requests (local HTTP stub)', () => {
  it('HEAD: the size of an incoming object, null when absent', async () => {
    const { storage, requests } = stubbed((req) =>
      req.path.endsWith('/present')
        ? { status: 200, headers: { 'content-length': '1234' } }
        : { status: 404 },
    );
    expect(await storage.headIncoming('in/a/present')).toEqual({ size: 1234 });
    expect(await storage.headIncoming('in/a/missing')).toBeNull();
    expect(requests.map((r) => [r.method, r.path])).toEqual([
      ['HEAD', '/kabso-incoming-test/in/a/present'],
      ['HEAD', '/kabso-incoming-test/in/a/missing'],
    ]);
    expect(requests[0]!.headers.authorization).toMatch(/^AWS4-HMAC-SHA256 /);
  });

  it('GET: a ranged read capped at byteSize + 1, and a longer object is refused', async () => {
    const data = Buffer.from('0123456789');
    const { storage, requests } = stubbed(() => ({ status: 206, body: data }));
    expect(await storage.readIncoming('in/a/b', 10)).toEqual(data);
    expect(requests[0]).toMatchObject({ method: 'GET', path: '/kabso-incoming-test/in/a/b' });
    expect(requests[0]!.headers.range).toBe('bytes=0-10');
    await expect(storage.readIncoming('in/a/b', 5)).rejects.toBeInstanceOf(StoredObjectTooLargeError);
  });

  it('PUT public: WebP with the immutable 1-day Cache-Control, in the public bucket', async () => {
    const { storage, requests } = stubbed(() => ({ status: 200 }));
    await storage.putPublic(
      'a/token/512.webp',
      Buffer.from('RIFFxxxxWEBP'),
      'image/webp',
      'public, max-age=86400, immutable',
    );
    expect(requests[0]).toMatchObject({
      method: 'PUT',
      path: '/kabso-public-test/a/token/512.webp',
    });
    expect(requests[0]!.headers['content-type']).toBe('image/webp');
    expect(requests[0]!.headers['cache-control']).toBe('public, max-age=86400, immutable');
    expect(requests[0]!.body?.toString()).toBe('RIFFxxxxWEBP');
  });

  it('DELETE: incoming and public objects; a missing object is not an error', async () => {
    const { storage, requests } = stubbed((req) =>
      req.path.includes('gone') ? { status: 404 } : { status: 204 },
    );
    await storage.deleteIncoming('in/a/b');
    await storage.deleteIncoming('in/a/gone');
    await storage.deletePublic(['c/t/960.webp', 'c/t/480.webp']);
    expect(requests.map((r) => [r.method, r.path])).toEqual([
      ['DELETE', '/kabso-incoming-test/in/a/b'],
      ['DELETE', '/kabso-incoming-test/in/a/gone'],
      ['DELETE', '/kabso-public-test/c/t/960.webp'],
      ['DELETE', '/kabso-public-test/c/t/480.webp'],
    ]);
  });

  it('a provider error is surfaced (the service maps it to 503)', async () => {
    const { storage } = stubbed(() => ({ status: 500 }));
    await expect(storage.headIncoming('in/a/b')).rejects.toBeDefined();
  });
});
