/**
 * Storage port of the media module (CONVENTIONS §11.3, §11.11, §11.12). The only implementation
 * in the API is the S3-compatible adapter (s3-media-storage.ts; Cloudflare R2 per D45). Tests use
 * an in-memory fake (test/helpers/in-memory-media-storage.ts). The server only ever passes keys it
 * generated itself; no endpoint accepts a URL or a key.
 */
export const MEDIA_STORAGE = Symbol('MEDIA_STORAGE');

export interface PresignedPut {
  /** Secret-bearing URL for one object: never logged. */
  readonly url: string;
  /** Headers the client must send exactly (signed): Content-Type and Content-Length. */
  readonly headers: Readonly<Record<string, string>>;
}

/** Thrown by {@link MediaStorage.readIncoming} when the object is larger than allowed. */
export class StoredObjectTooLargeError extends Error {
  constructor() {
    super('stored object is larger than allowed');
    this.name = 'StoredObjectTooLargeError';
  }
}

export interface MediaStorage {
  /** One presigned PUT for one private incoming key, `Content-Type` and `Content-Length` signed. */
  presignPut(
    key: string,
    contentType: string,
    contentLength: number,
    expiresInSeconds: number,
  ): Promise<PresignedPut>;
  /** Size of an incoming object (HEAD), or null when there is none. */
  headIncoming(key: string): Promise<{ readonly size: number } | null>;
  /**
   * Reads at most `maxBytes` of an incoming object (ranged GET); throws
   * {@link StoredObjectTooLargeError} when the object is longer.
   */
  readIncoming(key: string, maxBytes: number): Promise<Buffer>;
  /** Deletes an incoming object; succeeds when it does not exist. */
  deleteIncoming(key: string): Promise<void>;
  /** Writes one immutable public derivative (`image/webp`). */
  putPublic(key: string, body: Uint8Array, contentType: string, cacheControl: string): Promise<void>;
  /** Deletes public derivatives; succeeds for keys that do not exist. */
  deletePublic(keys: readonly string[]): Promise<void>;
}
