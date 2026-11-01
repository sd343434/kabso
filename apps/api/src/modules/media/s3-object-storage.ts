import {
  CopyObjectCommand,
  DeleteObjectsCommand,
  GetObjectCommand,
  HeadObjectCommand,
  NotFound,
  NoSuchKey,
  PutObjectCommand,
  S3Client,
  S3ServiceException,
  type S3ClientConfig,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import type { AppConfig } from '../../config/app-config.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { ObjectStorage, PresignedPut, StoredObjectInfo } from './object-storage.js';

/** The one prefix that may be public (CONVENTIONS §11.1): processed media and gift art. */
export const PUBLIC_KEY_PREFIX = 'media/';

/**
 * Where and how to reach the buckets (v1.75-social, D222): the server's `S3_*` (one bucket) or the OWNER's
 * «التخزين (R2 / S3)» panel settings (a public and a private bucket).
 */
export interface S3Settings {
  readonly endpoint: string | undefined;
  readonly region: string;
  /** The PUBLIC bucket (`media/`), or the only bucket when `privateBucket` is null (the env layout). */
  readonly bucket: string;
  /** D222: when set, every key outside `media/` (`uploads/`, `private/`) lives here, never in the public bucket. */
  readonly privateBucket: string | null;
  readonly accessKeyId: string;
  readonly secretAccessKey: string;
  readonly forcePathStyle: boolean;
}

/** The bucket a key belongs to: `media/` → the public bucket; the rest → the private one when there is one. */
export function bucketForKey(s: Pick<S3Settings, 'bucket' | 'privateBucket'>, key: string): string {
  return s.privateBucket && !key.startsWith(PUBLIC_KEY_PREFIX) ? s.privateBucket : s.bucket;
}

export function newS3Client(s: S3Settings, extra: Partial<S3ClientConfig> = {}): S3Client {
  return new S3Client({
    region: s.region,
    ...(s.endpoint ? { endpoint: s.endpoint } : {}),
    forcePathStyle: s.forcePathStyle,
    credentials: { accessKeyId: s.accessKeyId, secretAccessKey: s.secretAccessKey },
    // Uploads are verified by the server after the PUT; no SDK checksum headers in the URL.
    requestChecksumCalculation: 'WHEN_REQUIRED',
    responseChecksumValidation: 'WHEN_REQUIRED',
    ...extra,
  });
}

/** The env layout (`S3_*`): one bucket, or null when the bucket or the keys are missing. */
export function s3SettingsFromEnv(config: Pick<AppConfig, 'media'>): S3Settings | null {
  const s3 = config.media.s3;
  return s3.bucket && s3.accessKeyId && s3.secretAccessKey
    ? {
        endpoint: s3.endpoint,
        region: s3.region,
        bucket: s3.bucket,
        privateBucket: null,
        accessKeyId: s3.accessKeyId,
        secretAccessKey: s3.secretAccessKey,
        forcePathStyle: s3.forcePathStyle,
      }
    : null;
}

/**
 * S3-compatible storage (AWS S3, Cloudflare R2, MinIO) through the AWS SDK v3. Built from the server's `S3_*`
 * (`new S3ObjectStorage(config)`, the CLIs) or from {@link S3Settings} (D222: the panel's settings, one instance per
 * settings, swapped by `StorageSettingsStore` without a restart). Without a bucket and credentials every call answers
 * 503 (CONVENTIONS §11.1). With a private bucket (D222), keys are routed by {@link bucketForKey}. Credentials never
 * reach logs.
 */
export class S3ObjectStorage implements ObjectStorage {
  private readonly client: S3Client | null;
  readonly settings: S3Settings | null;

  constructor(source: Pick<AppConfig, 'media'> | S3Settings | null, client?: S3Client) {
    this.settings = source === null ? null : 'media' in source ? s3SettingsFromEnv(source) : source;
    this.client = client ?? (this.settings ? newS3Client(this.settings) : null);
  }

  private s3(): S3Client {
    if (!this.client) throw new AppException(ErrorCode.SERVICE_UNAVAILABLE);
    return this.client;
  }

  private bucketOf(key: string): string {
    return this.settings ? bucketForKey(this.settings, key) : '';
  }

  async presignPut(
    key: string,
    contentType: string,
    contentLength: number,
    expiresInSeconds: number,
  ): Promise<PresignedPut> {
    const command = new PutObjectCommand({
      Bucket: this.bucketOf(key),
      Key: key,
      ContentType: contentType,
      ContentLength: contentLength,
    });
    const url = await getSignedUrl(this.s3(), command, {
      expiresIn: expiresInSeconds,
      signableHeaders: new Set(['content-type', 'content-length']),
    });
    return { url, headers: { 'Content-Type': contentType, 'Content-Length': String(contentLength) } };
  }

  async head(key: string): Promise<StoredObjectInfo | null> {
    try {
      const out = await this.s3().send(new HeadObjectCommand({ Bucket: this.bucketOf(key), Key: key }));
      return { size: out.ContentLength ?? 0 };
    } catch (err) {
      if (isMissing(err)) return null;
      throw err;
    }
  }

  async get(key: string, maxBytes: number): Promise<Buffer | null> {
    try {
      const out = await this.s3().send(new GetObjectCommand({ Bucket: this.bucketOf(key), Key: key }));
      if ((out.ContentLength ?? 0) > maxBytes || !out.Body) return null;
      const bytes = await out.Body.transformToByteArray();
      return bytes.byteLength > maxBytes ? null : Buffer.from(bytes);
    } catch (err) {
      if (isMissing(err)) return null;
      throw err;
    }
  }

  async put(key: string, body: Buffer, contentType: string, cacheControl: string): Promise<void> {
    await this.s3().send(
      new PutObjectCommand({
        Bucket: this.bucketOf(key),
        Key: key,
        Body: body,
        ContentType: contentType,
        CacheControl: cacheControl,
      }),
    );
  }

  async getRange(key: string, offset: number, length: number): Promise<Buffer | null> {
    if (length <= 0) return Buffer.alloc(0);
    try {
      const out = await this.s3().send(
        new GetObjectCommand({
          Bucket: this.bucketOf(key),
          Key: key,
          Range: `bytes=${offset}-${offset + length - 1}`,
        }),
      );
      if (!out.Body) return null;
      const bytes = Buffer.from(await out.Body.transformToByteArray());
      // A server that ignores Range returns the whole object: keep only the window asked for.
      return bytes.length > length ? bytes.subarray(offset, offset + length) : bytes;
    } catch (err) {
      if (isMissing(err)) return null;
      throw err;
    }
  }

  async copy(fromKey: string, toKey: string, contentType: string, cacheControl: string): Promise<void> {
    await this.s3().send(
      new CopyObjectCommand({
        Bucket: this.bucketOf(toKey),
        Key: toKey,
        // Keys are server-chosen (`uploads/{uuid}/{uuid}`): only the path separators stay literal. With a private
        // bucket (D222) this is a copy between the account's two buckets (`uploads/` → `media/`).
        CopySource: `${this.bucketOf(fromKey)}/${fromKey.split('/').map(encodeURIComponent).join('/')}`,
        MetadataDirective: 'REPLACE',
        ContentType: contentType,
        CacheControl: cacheControl,
      }),
    );
  }

  async delete(keys: readonly string[]): Promise<void> {
    const byBucket = new Map<string, string[]>();
    for (const key of keys) {
      const bucket = this.bucketOf(key);
      byBucket.set(bucket, [...(byBucket.get(bucket) ?? []), key]);
    }
    for (const [bucket, all] of byBucket) {
      for (let i = 0; i < all.length; i += 1000) {
        const chunk = all.slice(i, i + 1000);
        await this.s3().send(
          new DeleteObjectsCommand({
            Bucket: bucket,
            Delete: { Objects: chunk.map((Key) => ({ Key })), Quiet: true },
          }),
        );
      }
    }
  }
}

export function isMissing(err: unknown): boolean {
  return (
    err instanceof NotFound ||
    err instanceof NoSuchKey ||
    (err instanceof S3ServiceException && err.$metadata.httpStatusCode === 404)
  );
}
