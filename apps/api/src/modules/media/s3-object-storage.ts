import { Inject, Injectable } from '@nestjs/common';
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
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { ObjectStorage, PresignedPut, StoredObjectInfo } from './object-storage.js';

/**
 * S3-compatible storage (AWS S3, Cloudflare R2, MinIO) through the AWS SDK v3. The client is
 * created only when the bucket and credentials are configured; otherwise every call answers 503
 * (uploads stay off until B12 is resolved, CONVENTIONS §11.1). Credentials never reach logs.
 */
@Injectable()
export class S3ObjectStorage implements ObjectStorage {
  private readonly client: S3Client | null;
  private readonly bucket: string;

  constructor(@Inject(APP_CONFIG) config: AppConfig) {
    const s3 = config.media.s3;
    this.bucket = s3.bucket ?? '';
    this.client =
      s3.bucket && s3.accessKeyId && s3.secretAccessKey
        ? new S3Client({
            region: s3.region,
            ...(s3.endpoint ? { endpoint: s3.endpoint } : {}),
            forcePathStyle: s3.forcePathStyle,
            credentials: { accessKeyId: s3.accessKeyId, secretAccessKey: s3.secretAccessKey },
            // Uploads are verified by the server after the PUT; no SDK checksum headers in the URL.
            requestChecksumCalculation: 'WHEN_REQUIRED',
            responseChecksumValidation: 'WHEN_REQUIRED',
          })
        : null;
  }

  private s3(): S3Client {
    if (!this.client) throw new AppException(ErrorCode.SERVICE_UNAVAILABLE);
    return this.client;
  }

  async presignPut(
    key: string,
    contentType: string,
    contentLength: number,
    expiresInSeconds: number,
  ): Promise<PresignedPut> {
    const command = new PutObjectCommand({
      Bucket: this.bucket,
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
      const out = await this.s3().send(new HeadObjectCommand({ Bucket: this.bucket, Key: key }));
      return { size: out.ContentLength ?? 0 };
    } catch (err) {
      if (isMissing(err)) return null;
      throw err;
    }
  }

  async get(key: string, maxBytes: number): Promise<Buffer | null> {
    try {
      const out = await this.s3().send(new GetObjectCommand({ Bucket: this.bucket, Key: key }));
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
        Bucket: this.bucket,
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
          Bucket: this.bucket,
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
        Bucket: this.bucket,
        Key: toKey,
        // Keys are server-chosen (`uploads/{uuid}/{uuid}`): only the path separators stay literal.
        CopySource: `${this.bucket}/${fromKey.split('/').map(encodeURIComponent).join('/')}`,
        MetadataDirective: 'REPLACE',
        ContentType: contentType,
        CacheControl: cacheControl,
      }),
    );
  }

  async delete(keys: readonly string[]): Promise<void> {
    for (let i = 0; i < keys.length; i += 1000) {
      const chunk = keys.slice(i, i + 1000);
      if (chunk.length === 0) continue;
      await this.s3().send(
        new DeleteObjectsCommand({
          Bucket: this.bucket,
          Delete: { Objects: chunk.map((Key) => ({ Key })), Quiet: true },
        }),
      );
    }
  }
}

function isMissing(err: unknown): boolean {
  return (
    err instanceof NotFound ||
    err instanceof NoSuchKey ||
    (err instanceof S3ServiceException && err.$metadata.httpStatusCode === 404)
  );
}
