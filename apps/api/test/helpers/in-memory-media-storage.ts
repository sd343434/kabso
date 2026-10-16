import { randomBytes } from 'node:crypto';
import {
  StoredObjectTooLargeError,
  type MediaStorage,
  type PresignedPut,
} from '../../src/modules/media/media-storage.js';

/**
 * In-memory fake of the media storage PORT, used by the e2e tests (KL-049).
 *
 * Why a fake of the port rather than a local S3 server: no S3-compatible server (MinIO) is
 * available in this environment, a local HTTP stub would have to re-implement SigV4 verification
 * to be meaningful, and the e2e tests are about the API's behaviour (flow, states, errors,
 * cleanup). The fake therefore enforces what the provider guarantees for a presigned PUT — the
 * signed Content-Length and Content-Type, one key per URL, expiry — through {@link clientPut},
 * which plays the mobile client's upload. The real S3 adapter's request shapes are covered
 * separately by src/modules/media/s3-media-storage.spec.ts with a stub of the SDK's HTTP layer.
 */
export class InMemoryMediaStorage implements MediaStorage {
  readonly incoming = new Map<string, Buffer>();
  readonly public = new Map<string, { body: Buffer; contentType: string; cacheControl: string }>();
  private readonly tickets = new Map<
    string,
    { key: string; contentType: string; contentLength: number; expiresAtMs: number }
  >();
  /** When set, every storage call fails (dependency down). */
  failing = false;
  /** Every call, for assertions on what the API asked storage to do. */
  readonly calls: string[] = [];

  /** Time source for presign expiry (tests may move it with their fake clock). */
  constructor(private readonly now: () => number = () => Date.now()) {}

  private check(op: string): void {
    this.calls.push(op);
    if (this.failing) throw new Error('storage unavailable (fake)');
  }

  async presignPut(
    key: string,
    contentType: string,
    contentLength: number,
    expiresInSeconds: number,
  ): Promise<PresignedPut> {
    const sig = randomBytes(16).toString('hex');
    this.tickets.set(sig, {
      key,
      contentType,
      contentLength,
      expiresAtMs: this.now() + expiresInSeconds * 1000,
    });
    return {
      url: `https://storage.test.invalid/incoming/${key}?X-Amz-Signature=${sig}`,
      headers: { 'Content-Type': contentType, 'Content-Length': String(contentLength) },
    };
  }

  /**
   * The client's PUT to a presigned URL, with the provider's checks: a known, unexpired URL and
   * exactly the signed Content-Type and Content-Length. Returns the HTTP status the provider
   * would answer (200, or 403 for a signature mismatch / expiry).
   */
  clientPut(url: string, headers: Record<string, string>, body: Buffer): number {
    const sig = new URL(url).searchParams.get('X-Amz-Signature') ?? '';
    const ticket = this.tickets.get(sig);
    if (!ticket || this.now() > ticket.expiresAtMs) return 403;
    if (headers['Content-Type'] !== ticket.contentType) return 403;
    if (Number(headers['Content-Length']) !== ticket.contentLength || body.length !== ticket.contentLength)
      return 403;
    this.incoming.set(ticket.key, Buffer.from(body));
    return 200;
  }

  /** Stores bytes at an incoming key directly (bypassing the signed checks), e.g. an oversized object. */
  forceIncoming(key: string, body: Buffer): void {
    this.incoming.set(key, Buffer.from(body));
  }

  keyOf(url: string): string {
    return decodeURIComponent(new URL(url).pathname.replace(/^\/incoming\//, ''));
  }

  async headIncoming(key: string): Promise<{ size: number } | null> {
    this.check(`HEAD ${key}`);
    const body = this.incoming.get(key);
    return body ? { size: body.length } : null;
  }

  async readIncoming(key: string, maxBytes: number): Promise<Buffer> {
    this.check(`GET ${key}`);
    const body = this.incoming.get(key);
    if (!body) throw Object.assign(new Error('NoSuchKey'), { name: 'NoSuchKey' });
    if (body.length > maxBytes) throw new StoredObjectTooLargeError();
    return Buffer.from(body);
  }

  async deleteIncoming(key: string): Promise<void> {
    this.check(`DELETE in ${key}`);
    this.incoming.delete(key);
  }

  async putPublic(key: string, body: Uint8Array, contentType: string, cacheControl: string): Promise<void> {
    this.check(`PUT public ${key}`);
    this.public.set(key, { body: Buffer.from(body), contentType, cacheControl });
  }

  async deletePublic(keys: readonly string[]): Promise<void> {
    for (const key of keys) {
      this.check(`DELETE public ${key}`);
      this.public.delete(key);
    }
  }
}
