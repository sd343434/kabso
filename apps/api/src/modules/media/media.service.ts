import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import type { MediaAsset, Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { isUuid } from '../live/live.schemas.js';
import {
  IMAGE_CONTENT_TYPES,
  InvalidImageError,
  MAX_IMAGE_BYTES,
  processImage,
  LARGE_SIDE,
  STORY_LARGE_SIDE,
  COVER_SIDE,
  type ImageContentType,
} from './media-image.js';
import { AUDIO_CONTENT_TYPES, InvalidAudioError, MAX_VOICE_BYTES, verifyVoiceClip } from './media-audio.js';
import { OBJECT_STORAGE, type ObjectStorage } from './object-storage.js';

/** `MediaAsset` (openapi v1.5-social; `AUDIO` and `durationMs`, CP-017). */
export interface MediaAssetDto {
  id: string;
  type: 'IMAGE' | 'AUDIO';
  status: 'READY';
  /** 0 for AUDIO. */
  width: number;
  height: number;
  blurhash: string | null;
  url: string;
  /** AUDIO: the same as `url`. */
  thumbUrl: string;
  /** AUDIO only: the clip's length (≤ 30 000). */
  durationMs?: number;
}

/** `MediaUpload` (openapi v1.5-social). */
export interface MediaUploadDto {
  uploadId: string;
  uploadUrl: string;
  method: 'PUT';
  headers: Readonly<Record<string, string>>;
  expiresAt: string;
}

/**
 * `MediaKind`: what an asset may be attached to (CP-008; `LIVE_COVER`, CP-015; `LIVE_CHAT_IMAGE`
 * and `LIVE_CHAT_VOICE`, CP-017).
 */
export const MEDIA_KINDS = [
  'POST_IMAGE',
  'STORY_IMAGE',
  'LIVE_COVER',
  'LIVE_CHAT_IMAGE',
  'LIVE_CHAT_VOICE',
] as const;
export type MediaKind = (typeof MEDIA_KINDS)[number];

/**
 * `CreateMediaUploadRequest`: strict (unknown fields → `unknown_field`). CP-017: a
 * `LIVE_CHAT_VOICE` upload is `audio/mp4` of at most 1 MiB; every other kind is an image type.
 */
export const createMediaUploadSchema = z
  .strictObject({
    kind: z.enum(MEDIA_KINDS),
    contentType: z.enum([...IMAGE_CONTENT_TYPES, ...AUDIO_CONTENT_TYPES]),
    byteSize: z.number().int().min(1).max(MAX_IMAGE_BYTES),
  })
  .superRefine((value, ctx) => {
    const voice = value.kind === 'LIVE_CHAT_VOICE';
    const audio = (AUDIO_CONTENT_TYPES as readonly string[]).includes(value.contentType);
    if (voice !== audio) {
      ctx.addIssue({ code: 'custom', path: ['contentType'], params: { issue: 'invalid_value' } });
    } else if (voice && value.byteSize > MAX_VOICE_BYTES) {
      ctx.addIssue({ code: 'custom', path: ['byteSize'], params: { issue: 'too_big' } });
    }
  });

/** A presigned URL lives 10 minutes (§11.1). */
export const UPLOAD_URL_TTL_SECONDS = 600;
/** An unfinished slot is swept an hour after its URL expired (a slow PUT may still be landing). */
const SLOT_GRACE_MS = 3600 * 1000;
const SWEEP_BATCH = 200;
const IMMUTABLE_CACHE = 'public, max-age=31536000, immutable';

/**
 * Media uploads and assets (CONVENTIONS §11.1). The client uploads straight to object storage
 * with a presigned PUT; `complete` verifies the bytes (signature + decoder, never the declared
 * type alone), re-encodes them without metadata and records the asset. The asset id equals the
 * upload id, so a repeated or concurrent `complete` writes the same objects and the same row.
 */
@Injectable()
export class MediaService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(MediaService.name);
  private sweepTimer: NodeJS.Timeout | undefined;
  private sweepInFlight: Promise<void> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  onModuleInit(): void {
    if (this.config.media.sweepIntervalSeconds > 0) this.scheduleSweep();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.sweepTimer) clearTimeout(this.sweepTimer);
    await this.sweepInFlight?.catch(() => undefined);
  }

  assertEnabled(): void {
    if (!this.config.media.uploadsEnabled) throw new AppException(ErrorCode.MEDIA_UPLOADS_UNAVAILABLE);
  }

  private publicUrl(key: string): string {
    return `${this.config.media.publicBaseUrl ?? ''}/${key}`;
  }

  toDto(
    asset: Pick<
      MediaAsset,
      'id' | 'kind' | 'width' | 'height' | 'blurhash' | 'largeKey' | 'thumbKey' | 'durationMs'
    >,
  ): MediaAssetDto {
    const dto: MediaAssetDto = {
      id: asset.id,
      type: asset.kind === 'LIVE_CHAT_VOICE' ? 'AUDIO' : 'IMAGE',
      status: 'READY',
      width: asset.width,
      height: asset.height,
      blurhash: asset.blurhash,
      url: this.publicUrl(asset.largeKey),
      thumbUrl: this.publicUrl(asset.thumbKey),
    };
    if (asset.durationMs !== null) dto.durationMs = asset.durationMs;
    return dto;
  }

  /** The public URL of an asset's large variant (a live cover's 640 px square, CP-015). */
  largeUrl(asset: Pick<MediaAsset, 'largeKey'>): string {
    return this.publicUrl(asset.largeKey);
  }

  /**
   * Deletes the objects of assets whose rows the caller already deleted (a replaced or removed
   * live cover, CP-015). Best effort: a failure is logged, the rows are gone either way.
   */
  async deleteObjects(keys: readonly string[]): Promise<void> {
    if (keys.length === 0) return;
    await this.storage.delete(keys).catch((err: unknown) => {
      this.logger.warn({ count: keys.length, error: safeErrorLog(err) }, 'Media objects not deleted');
    });
  }

  /**
   * CP-017: deletes assets whose rows nothing else needs any more (expired voice clips and images
   * of the live chat): their objects first — a storage failure throws, so the rows stay and the
   * next sweep retries — then the rows (an FK sets the referencing chat message's `media_id` to
   * NULL). Returns the number of rows deleted.
   */
  async purgeAssets(assets: readonly { id: string; largeKey: string; thumbKey: string }[]): Promise<number> {
    if (assets.length === 0) return 0;
    await this.storage.delete([...new Set(assets.flatMap((a) => [a.largeKey, a.thumbKey]))]);
    const deleted = await this.prisma.mediaAsset.deleteMany({
      where: { id: { in: assets.map((a) => a.id) } },
    });
    return deleted.count;
  }

  /** `POST /media/uploads` (the rate limit was counted by the guard, before this check). */
  async createUpload(userId: string, body: unknown): Promise<MediaUploadDto> {
    this.assertEnabled();
    const parsed = createMediaUploadSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const { kind, contentType, byteSize } = parsed.data;
    const id = uuidv7();
    const objectKey = `uploads/${userId}/${id}`;
    const expiresAt = new Date(Date.now() + UPLOAD_URL_TTL_SECONDS * 1000);
    const presigned = await this.storage.presignPut(objectKey, contentType, byteSize, UPLOAD_URL_TTL_SECONDS);
    await this.prisma.mediaUpload.create({
      data: { id, userId, kind, contentType, byteSize, objectKey, expiresAt },
    });
    return {
      uploadId: id,
      uploadUrl: presigned.url,
      method: 'PUT',
      headers: presigned.headers,
      expiresAt: expiresAt.toISOString(),
    };
  }

  /** `POST /media/uploads/{uploadId}/complete`. Only the uploader; anyone else gets 404. */
  async completeUpload(userId: string, uploadId: string): Promise<MediaAssetDto> {
    this.assertEnabled();
    if (!isUuid(uploadId)) throw new AppException(ErrorCode.NOT_FOUND);
    const upload = await this.prisma.mediaUpload.findFirst({
      where: { id: uploadId.toLowerCase(), userId },
      include: { mediaAsset: true },
    });
    if (!upload) throw new AppException(ErrorCode.NOT_FOUND);
    if (upload.status === 'COMPLETED' && upload.mediaAsset) return this.toDto(upload.mediaAsset);
    if (upload.status !== 'PENDING') throw new AppException(ErrorCode.MEDIA_INVALID);

    const fail = async (reason: string): Promise<never> => {
      this.logger.warn({ uploadId: upload.id, reason }, 'Upload rejected');
      await this.prisma.mediaUpload.updateMany({
        where: { id: upload.id, status: 'PENDING' },
        data: { status: 'FAILED', completedAt: new Date() },
      });
      await this.storage.delete([upload.objectKey]).catch(() => undefined);
      throw new AppException(ErrorCode.MEDIA_INVALID);
    };

    if (upload.expiresAt.getTime() + SLOT_GRACE_MS < Date.now()) return fail('slot expired');
    const head = await this.storage.head(upload.objectKey);
    if (!head) return fail('object missing');
    if (head.size !== upload.byteSize) return fail('size mismatch');
    const bytes = await this.storage.get(upload.objectKey, upload.byteSize);
    if (!bytes || bytes.length !== upload.byteSize) return fail('size mismatch');

    const kind = MEDIA_KINDS.find((k) => k === upload.kind) ?? 'POST_IMAGE';
    if (kind === 'LIVE_CHAT_VOICE') {
      let clip: { durationMs: number };
      try {
        clip = verifyVoiceClip(bytes);
      } catch (err) {
        if (err instanceof InvalidAudioError) return fail(err.message);
        throw err;
      }
      return this.toDto(await this.storeVoice(userId, upload, bytes, clip.durationMs));
    }
    const cover = kind === 'LIVE_COVER';
    const side = kind === 'STORY_IMAGE' ? STORY_LARGE_SIDE : cover ? COVER_SIDE : LARGE_SIDE;
    let image;
    try {
      image = await processImage(bytes, upload.contentType as ImageContentType, side, cover);
    } catch (err) {
      if (err instanceof InvalidImageError) return fail(err.message);
      throw err;
    }
    const largeKey = `media/${upload.id}/${side}.webp`;
    const thumbKey = `media/${upload.id}/320.webp`;
    await this.storage.put(largeKey, image.large, 'image/webp', IMMUTABLE_CACHE);
    await this.storage.put(thumbKey, image.thumb, 'image/webp', IMMUTABLE_CACHE);

    const asset = await this.prisma.$transaction(async (tx) => {
      await tx.mediaAsset.createMany({
        data: [
          {
            id: upload.id,
            ownerId: userId,
            kind,
            width: image.width,
            height: image.height,
            blurhash: image.blurhash,
            largeKey,
            thumbKey,
            byteSize: image.large.length,
          },
        ],
        skipDuplicates: true,
      });
      await tx.mediaUpload.updateMany({
        where: { id: upload.id, status: 'PENDING' },
        data: { status: 'COMPLETED', completedAt: new Date(), mediaAssetId: upload.id },
      });
      return tx.mediaAsset.findUniqueOrThrow({ where: { id: upload.id } });
    });
    await this.storage.delete([upload.objectKey]).catch((err: unknown) => {
      this.logger.warn({ uploadId: upload.id, error: safeErrorLog(err) }, 'Upload object not deleted');
    });
    return this.toDto(asset);
  }

  /**
   * CP-017: a verified voice clip is stored unchanged (`media/{mediaId}/voice.m4a`, `audio/mp4`);
   * the asset has no size (0 × 0) and its one object serves as both variants.
   */
  private async storeVoice(
    userId: string,
    upload: { id: string; objectKey: string },
    bytes: Buffer,
    durationMs: number,
  ): Promise<MediaAsset> {
    const key = `media/${upload.id}/voice.m4a`;
    await this.storage.put(key, bytes, 'audio/mp4', IMMUTABLE_CACHE);
    const asset = await this.prisma.$transaction(async (tx) => {
      await tx.mediaAsset.createMany({
        data: [
          {
            id: upload.id,
            ownerId: userId,
            kind: 'LIVE_CHAT_VOICE',
            width: 0,
            height: 0,
            blurhash: null,
            largeKey: key,
            thumbKey: key,
            byteSize: bytes.length,
            durationMs,
          },
        ],
        skipDuplicates: true,
      });
      await tx.mediaUpload.updateMany({
        where: { id: upload.id, status: 'PENDING' },
        data: { status: 'COMPLETED', completedAt: new Date(), mediaAssetId: upload.id },
      });
      return tx.mediaAsset.findUniqueOrThrow({ where: { id: upload.id } });
    });
    await this.storage.delete([upload.objectKey]).catch((err: unknown) => {
      this.logger.warn({ uploadId: upload.id, error: safeErrorLog(err) }, 'Upload object not deleted');
    });
    return asset;
  }

  /** `GET /media/{mediaId}`: the caller's own assets only (else 404). */
  async getMedia(userId: string, mediaId: string): Promise<MediaAssetDto> {
    if (!isUuid(mediaId)) throw new AppException(ErrorCode.NOT_FOUND);
    const asset = await this.prisma.mediaAsset.findFirst({
      where: { id: mediaId.toLowerCase(), ownerId: userId },
    });
    if (!asset) throw new AppException(ErrorCode.NOT_FOUND);
    return this.toDto(asset);
  }

  /**
   * Attaches the caller's READY, unattached assets of `kind` (in `ids` order) inside the caller's
   * transaction; rows are locked so two posts or stories cannot take the same asset. Returns null
   * when an id is not one of the caller's attachable assets of that kind (CP-008: a story photo
   * never attaches to a post, nor the reverse).
   */
  async claimAssetsIn(
    tx: Prisma.TransactionClient,
    userId: string,
    ids: readonly string[],
    kind: MediaKind = 'POST_IMAGE',
  ): Promise<MediaAsset[] | null> {
    if (ids.length === 0) return [];
    const lower = ids.map((id) => id.toLowerCase());
    const locked = await tx.$queryRaw<{ id: string }[]>`
      SELECT id FROM media_assets
      WHERE id = ANY(${lower}::uuid[]) AND owner_id = ${userId}::uuid AND attached_at IS NULL
        AND kind = ${kind}
        AND created_at > now() - interval '24 hours'
      FOR UPDATE`;
    if (locked.length !== lower.length) return null;
    const now = new Date();
    await tx.mediaAsset.updateMany({ where: { id: { in: lower } }, data: { attachedAt: now } });
    const rows = await tx.mediaAsset.findMany({ where: { id: { in: lower } } });
    const byId = new Map(rows.map((r) => [r.id, r]));
    return lower.map((id) => byId.get(id)!);
  }

  private scheduleSweep(): void {
    this.sweepTimer = setTimeout(() => {
      this.sweepInFlight = this.sweep()
        .then(() => undefined)
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Media sweep failed');
        })
        .finally(() => {
          this.sweepInFlight = null;
          this.scheduleSweep();
        });
    }, this.config.media.sweepIntervalSeconds * 1000);
    this.sweepTimer.unref();
  }

  /**
   * Deletes expired upload slots (marked FAILED, objects removed) and assets never attached
   * within 24 hours (objects then rows). Bounded batches; safe to run concurrently with requests
   * because claims lock the asset rows and only unattached rows are deleted.
   */
  async sweep(): Promise<{ slots: number; assets: number }> {
    const slots = await this.prisma.mediaUpload.findMany({
      where: { status: 'PENDING', expiresAt: { lt: new Date(Date.now() - SLOT_GRACE_MS) } },
      select: { id: true, objectKey: true },
      take: SWEEP_BATCH,
    });
    if (slots.length > 0) {
      await this.storage.delete(slots.map((s) => s.objectKey));
      await this.prisma.mediaUpload.updateMany({
        where: { id: { in: slots.map((s) => s.id) }, status: 'PENDING' },
        data: { status: 'FAILED', completedAt: new Date() },
      });
    }
    // DELETE … RETURNING: only rows still unattached at delete time (a concurrent claim holds the
    // row lock and sets attached_at first) lose their objects.
    const stale = await this.prisma.$queryRaw<{ large_key: string; thumb_key: string }[]>`
      DELETE FROM media_assets
      WHERE id IN (
        SELECT id FROM media_assets
        WHERE attached_at IS NULL AND created_at < now() - interval '24 hours'
        ORDER BY created_at
        LIMIT ${SWEEP_BATCH}
        FOR UPDATE SKIP LOCKED)
        AND attached_at IS NULL
      RETURNING large_key, thumb_key`;
    if (stale.length > 0) await this.storage.delete(stale.flatMap((a) => [a.large_key, a.thumb_key]));
    return { slots: slots.length, assets: stale.length };
  }
}
