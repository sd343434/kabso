/**
 * Object storage port (CONVENTIONS §11.1). Production uses {@link S3ObjectStorage} (MinIO
 * locally, Cloudflare R2 in the cloud, D45); tests provide an in-memory double. Keys are
 * server-chosen (`uploads/{userId}/{uploadId}`, `media/{mediaId}/…`), never client input.
 */
export const OBJECT_STORAGE = Symbol('OBJECT_STORAGE');

export interface PresignedPut {
  readonly url: string;
  /** Headers the client must send unchanged (they are part of the signature). */
  readonly headers: Readonly<Record<string, string>>;
}

export interface StoredObjectInfo {
  readonly size: number;
}

export interface ObjectStorage {
  /** A URL that accepts exactly one PUT of `contentLength` bytes of `contentType`. */
  presignPut(
    key: string,
    contentType: string,
    contentLength: number,
    expiresInSeconds: number,
  ): Promise<PresignedPut>;
  /** Size of the object, or null when it does not exist. */
  head(key: string): Promise<StoredObjectInfo | null>;
  /** The object's bytes, or null when it does not exist or is larger than `maxBytes`. */
  get(key: string, maxBytes: number): Promise<Buffer | null>;
  put(key: string, body: Buffer, contentType: string, cacheControl: string): Promise<void>;
  /**
   * v1.41-social (D162): `length` bytes from `offset` (fewer at the object's end), or null when the
   * object does not exist. Videos are inspected this way, never loaded whole.
   */
  getRange(key: string, offset: number, length: number): Promise<Buffer | null>;
  /**
   * v1.41-social (D162): copies `fromKey` to `toKey` inside the bucket (a server-side copy; the bytes
   * do not pass through the API) with a new content type and cache header.
   */
  copy(fromKey: string, toKey: string, contentType: string, cacheControl: string): Promise<void>;
  /** Deletes the keys; missing keys are not an error. */
  delete(keys: readonly string[]): Promise<void>;
}
