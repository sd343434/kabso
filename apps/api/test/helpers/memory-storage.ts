import type {
  ObjectStorage,
  PresignedPut,
  StoredObjectInfo,
} from '../../src/modules/media/object-storage.js';

interface StoredObject {
  readonly body: Buffer;
  readonly contentType: string;
  readonly cacheControl: string;
}

/**
 * Test double of the ObjectStorage port (tests only; production uses S3ObjectStorage). A
 * presigned "URL" is `memory://<key>`; tests upload with {@link MemoryObjectStorage.upload},
 * which enforces the signed Content-Type and Content-Length like S3 does.
 */
export class MemoryObjectStorage implements ObjectStorage {
  readonly objects = new Map<string, StoredObject>();
  private readonly signed = new Map<
    string,
    { contentType: string; contentLength: number; expires: number }
  >();

  presignPut(
    key: string,
    contentType: string,
    contentLength: number,
    expiresInSeconds: number,
  ): Promise<PresignedPut> {
    this.signed.set(key, { contentType, contentLength, expires: Date.now() + expiresInSeconds * 1000 });
    return Promise.resolve({
      url: `memory://${key}`,
      headers: { 'Content-Type': contentType, 'Content-Length': String(contentLength) },
    });
  }

  /** What a client PUT to `url` does: refused when the signed headers do not match. */
  upload(url: string, body: Buffer, contentType: string): boolean {
    const key = url.replace(/^memory:\/\//, '');
    const grant = this.signed.get(key);
    if (!grant || grant.expires < Date.now()) return false;
    if (grant.contentType !== contentType || grant.contentLength !== body.length) return false;
    this.objects.set(key, { body, contentType, cacheControl: '' });
    return true;
  }

  /** Bypasses the signature (a misbehaving client, or bytes that changed in transit). */
  putRaw(key: string, body: Buffer, contentType = 'application/octet-stream'): void {
    this.objects.set(key, { body, contentType, cacheControl: '' });
  }

  head(key: string): Promise<StoredObjectInfo | null> {
    const o = this.objects.get(key);
    return Promise.resolve(o ? { size: o.body.length } : null);
  }

  get(key: string, maxBytes: number): Promise<Buffer | null> {
    const o = this.objects.get(key);
    return Promise.resolve(o && o.body.length <= maxBytes ? o.body : null);
  }

  put(key: string, body: Buffer, contentType: string, cacheControl: string): Promise<void> {
    this.objects.set(key, { body, contentType, cacheControl });
    return Promise.resolve();
  }

  delete(keys: readonly string[]): Promise<void> {
    for (const key of keys) this.objects.delete(key);
    return Promise.resolve();
  }
}
