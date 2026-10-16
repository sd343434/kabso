import {
  DeleteObjectCommand,
  GetObjectCommand,
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
  type S3ClientConfig,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import type { MediaStorageConfig } from '../../config/app-config.js';
import { StoredObjectTooLargeError, type MediaStorage, type PresignedPut } from './media-storage.js';

/** Headers the presigned PUT signs (CONVENTIONS §11.3): size and type cannot be changed. */
const SIGNED_HEADERS = new Set(['content-type', 'content-length']);

function isNotFound(err: unknown): boolean {
  const e = err as { name?: unknown; $metadata?: { httpStatusCode?: unknown } } | null;
  return e?.name === 'NotFound' || e?.name === 'NoSuchKey' || e?.$metadata?.httpStatusCode === 404;
}

async function readCapped(body: unknown, maxBytes: number): Promise<Buffer> {
  if (body === undefined || body === null) return Buffer.alloc(0);
  const chunks: Buffer[] = [];
  let total = 0;
  for await (const chunk of body as AsyncIterable<Uint8Array>) {
    total += chunk.byteLength;
    if (total > maxBytes) {
      const destroy = (body as { destroy?: () => void }).destroy;
      if (typeof destroy === 'function') destroy.call(body);
      throw new StoredObjectTooLargeError();
    }
    chunks.push(Buffer.from(chunk.buffer, chunk.byteOffset, chunk.byteLength));
  }
  return Buffer.concat(chunks, total);
}

/**
 * S3-compatible storage adapter (AWS SDK v3), aimed at Cloudflare R2 (D45) but provider-neutral:
 * SigV4 presigned PUT, HEAD, ranged GET, PUT and DELETE. Constructed only from a complete storage
 * configuration; it contacts the configured endpoint only when a method is called (never at
 * boot). Credentials stay inside the SDK client and are never logged.
 *
 * `requestChecksumCalculation: WHEN_REQUIRED`: newer SDK versions otherwise add CRC32 checksum
 * parameters to presigned URLs, which S3-compatible stores such as R2 reject or which a mobile
 * client cannot satisfy.
 */
export class S3MediaStorage implements MediaStorage {
  private readonly client: S3Client;

  constructor(
    private readonly config: MediaStorageConfig,
    overrides: Partial<S3ClientConfig> = {},
  ) {
    this.client = new S3Client({
      region: config.region,
      ...(config.endpoint === undefined ? {} : { endpoint: config.endpoint }),
      forcePathStyle: config.forcePathStyle,
      credentials: { accessKeyId: config.accessKeyId, secretAccessKey: config.secretAccessKey },
      requestChecksumCalculation: 'WHEN_REQUIRED',
      responseChecksumValidation: 'WHEN_REQUIRED',
      maxAttempts: 3,
      requestHandler: { requestTimeout: 15_000, connectionTimeout: 5_000 },
      ...overrides,
    });
  }

  async presignPut(
    key: string,
    contentType: string,
    contentLength: number,
    expiresInSeconds: number,
  ): Promise<PresignedPut> {
    const command = new PutObjectCommand({
      Bucket: this.config.incomingBucket,
      Key: key,
      ContentType: contentType,
      ContentLength: contentLength,
    });
    const url = await getSignedUrl(this.client, command, {
      expiresIn: expiresInSeconds,
      signableHeaders: SIGNED_HEADERS,
      unhoistableHeaders: SIGNED_HEADERS,
    });
    return { url, headers: { 'Content-Type': contentType, 'Content-Length': String(contentLength) } };
  }

  async headIncoming(key: string): Promise<{ size: number } | null> {
    try {
      const head = await this.client.send(
        new HeadObjectCommand({ Bucket: this.config.incomingBucket, Key: key }),
      );
      return { size: head.ContentLength ?? 0 };
    } catch (err) {
      if (isNotFound(err)) return null;
      throw err;
    }
  }

  async readIncoming(key: string, maxBytes: number): Promise<Buffer> {
    // One byte more than allowed, so an object that grew after HEAD is detected.
    const result = await this.client.send(
      new GetObjectCommand({ Bucket: this.config.incomingBucket, Key: key, Range: `bytes=0-${maxBytes}` }),
    );
    return readCapped(result.Body, maxBytes);
  }

  async deleteIncoming(key: string): Promise<void> {
    try {
      await this.client.send(new DeleteObjectCommand({ Bucket: this.config.incomingBucket, Key: key }));
    } catch (err) {
      if (!isNotFound(err)) throw err;
    }
  }

  async putPublic(key: string, body: Uint8Array, contentType: string, cacheControl: string): Promise<void> {
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.config.publicBucket,
        Key: key,
        Body: body,
        ContentType: contentType,
        ContentLength: body.byteLength,
        CacheControl: cacheControl,
      }),
    );
  }

  async deletePublic(keys: readonly string[]): Promise<void> {
    for (const key of keys) {
      try {
        await this.client.send(new DeleteObjectCommand({ Bucket: this.config.publicBucket, Key: key }));
      } catch (err) {
        if (!isNotFound(err)) throw err;
      }
    }
  }

  destroy(): void {
    this.client.destroy();
  }
}
