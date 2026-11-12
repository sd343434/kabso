import { assertKabsoOwner } from '../owner-profile/owner-core.js';
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
  BANNER_WIDTH,
  type ImageContentType,
  type ImageShape,
} from './media-image.js';
import {
  AUDIO_CONTENT_TYPES,
  InvalidAudioError,
  MAX_ANY_VOICE_BYTES,
  MAX_VOICE_BYTES,
  verifyVoiceClip,
  voiceLimitsFor,
  type VoiceLimits,
} from './media-audio.js';
import { vipPerkIntIn } from '../vip/vip-gift-perks.js';
import {
  InvalidVideoError,
  MAX_VIDEO_BYTES,
  VIDEO_CONTENT_TYPES,
  VIDEO_LIMITS,
  inspectVideo,
  isVideoKind,
  type VideoContentType,
  type VideoInfo,
  type VideoKind,
} from './media-video.js';
import { StorageSettingsStore } from '../storage-settings/storage-settings.store.js';
import { OBJECT_STORAGE, type ObjectStorage } from './object-storage.js';

/** `MediaAsset` (openapi v1.5-social; `AUDIO` and `durationMs`, CP-017; `VIDEO`, v1.41-social). */
export interface MediaAssetDto {
  id: string;
  type: 'IMAGE' | 'AUDIO' | 'VIDEO';
  status: 'READY';
  /** 0 for AUDIO. */
  width: number;
  height: number;
  blurhash: string | null;
  url: string;
  /** AUDIO: the same as `url`. VIDEO: the poster at 320 px. */
  thumbUrl: string;
  /** VIDEO only (D162): the poster at 1 080 px. */
  posterUrl?: string;
  /**
   * AUDIO: the clip's length (≤ 30 000). VIDEO (D162): ≤ 60 000 for a reel, ≤ 90 000 for a new post
   * video (D168; ones stored before keep up to 180 000).
   */
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
  // v1.21-live (CP-018): a family's emblem (a centre-cropped square, like the live cover).
  'FAMILY_EMBLEM',
  // v1.25-live (CP-022): a family's cover (processed like a post image).
  'FAMILY_COVER',
  // v1.26-live (D124): a home banner (1 500 × 500, cover-cropped to 3:1); attached only by the
  // banner-admin CLI.
  'HOME_BANNER',
  // v1.40-social (D155): a direct message's picture (like a post image) and voice note (like a live
  // chat voice clip); deleted with the message after 24 hours (§11.13).
  'DM_IMAGE',
  'DM_VOICE',
  // v1.41-social (D162, CP-023): a post's video, a reel's video and a video's poster (the first
  // frame, made on the phone; processed like a post image and consumed by the video's `complete`).
  'POST_VIDEO',
  'REEL_VIDEO',
  'VIDEO_POSTER',
  // v1.45-social (D168): the profile photo (a centre-cropped square, like the live cover); attached
  // only by `PUT /me/avatar`.
  'AVATAR',
  // v1.76-social (D218, §10.73.3): the profile cover (processed like a post image, never cropped); attached only
  // by `PUT /me/cover`.
  'PROFILE_COVER',
  // v1.54-social (D185, §10.48): the private pictures of a recharge-agent application; never completed (404),
  // consumed by the application into the private prefix (no asset, no URL).
  'RECHARGE_AGENT_PHOTO',
  'RECHARGE_AGENT_SELFIE',
  // v1.69-social (D204, §10.64): a picture of a recharge order's chat or the transfer's screenshot; private like the
  // two above (consumed into `private/recharge-orders/<order>/`, shown only to the order's people and to admins).
  'RECHARGE_ORDER_IMAGE',
  // v1.89-social (D290, §10.103): the video of a level-raise request «طلب رفع ليفيل» (a staff member records the
  // supporter's profile in the source app); a video like a post video, attached only by the request.
  'LEVEL_RAISE_VIDEO',
  // v1.95-social (D301, §10.112): the app owner's cover video (like a reel's video, with a poster; only the owner gets a
  // slot) and a private picture of «اقترح ميزة / أبلغ عن موظف» (consumed into `private/owner-feedback/<id>/`).
  'PROFILE_COVER_VIDEO',
  'OWNER_FEEDBACK_IMAGE',
  // v1.104-social (D339, §10.133): a group conversation's photo (a centre-cropped square, like a family emblem); attached
  // only by `createDmGroup` / `updateDmGroup`.
  'DM_GROUP_PHOTO',
] as const;
export type MediaKind = (typeof MEDIA_KINDS)[number];

/** v1.54-social (D185): kinds consumed privately (never completed into a public asset). */
export function isPrivateKind(kind: string): boolean {
  return (
    kind === 'RECHARGE_AGENT_PHOTO' ||
    kind === 'RECHARGE_AGENT_SELFIE' ||
    kind === 'RECHARGE_ORDER_IMAGE' ||
    kind === 'OWNER_FEEDBACK_IMAGE'
  );
}

/** The voice-clip kinds (CP-017 pipeline: `audio/mp4`, ≤ 1 MiB, ≤ 30 s). */
export function isVoiceKind(kind: string): boolean {
  return kind === 'LIVE_CHAT_VOICE' || kind === 'DM_VOICE';
}

/** The largest upload of `kind` (images 15 MiB, voice clips 1 MiB, videos per D162). */
export function maxUploadBytes(kind: MediaKind): number {
  if (isVoiceKind(kind)) return MAX_VOICE_BYTES;
  if (isVideoKind(kind)) return VIDEO_LIMITS[kind].maxBytes;
  return MAX_IMAGE_BYTES;
}

/**
 * `CreateMediaUploadRequest`: strict (unknown fields → `unknown_field`). CP-017: a
 * `LIVE_CHAT_VOICE` upload is `audio/mp4` of at most 1 MiB; v1.41-social (D162): a `POST_VIDEO` /
 * `REEL_VIDEO` upload is `video/mp4` or `video/quicktime` (≤ 200 / 100 MiB); every other kind is
 * an image type of at most 15 MiB.
 */
export const createMediaUploadSchema = z
  .strictObject({
    kind: z.enum(MEDIA_KINDS),
    contentType: z.enum([...IMAGE_CONTENT_TYPES, ...AUDIO_CONTENT_TYPES, ...VIDEO_CONTENT_TYPES]),
    byteSize: z.number().int().min(1).max(MAX_VIDEO_BYTES),
  })
  .superRefine((value, ctx) => {
    const family = (type: string): 'audio' | 'video' | 'image' =>
      (AUDIO_CONTENT_TYPES as readonly string[]).includes(type)
        ? 'audio'
        : (VIDEO_CONTENT_TYPES as readonly string[]).includes(type)
          ? 'video'
          : 'image';
    const wanted = isVoiceKind(value.kind) ? 'audio' : isVideoKind(value.kind) ? 'video' : 'image';
    if (family(value.contentType) !== wanted) {
      ctx.addIssue({ code: 'custom', path: ['contentType'], params: { issue: 'invalid_value' } });
    } else if (
      value.byteSize > (isVoiceKind(value.kind) ? MAX_ANY_VOICE_BYTES : maxUploadBytes(value.kind))
    ) {
      // v1.134-social (D381): a voice clip's own bound is the uploader's (LONGER_VOICE), checked next.
      ctx.addIssue({ code: 'custom', path: ['byteSize'], params: { issue: 'too_big' } });
    }
  });

/** v1.41-social (D162): `CompleteMediaUploadRequest` — `{posterId}` for a video, nothing otherwise. */
export const completeMediaUploadSchema = z.strictObject({ posterId: z.uuid().optional() });

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
    private readonly storageSettings: StorageSettingsStore,
  ) {}

  onModuleInit(): void {
    if (this.config.media.sweepIntervalSeconds > 0) this.scheduleSweep();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.sweepTimer) clearTimeout(this.sweepTimer);
    await this.sweepInFlight?.catch(() => undefined);
  }

  /**
   * 503 `MEDIA_UPLOADS_UNAVAILABLE` («التخزين غير مفعّل») unless the storage is on: the panel's «التخزين (R2 / S3)»
   * switch (v1.75-social, D222) or, when it is off, `MEDIA_UPLOADS_ENABLED` as before.
   */
  async assertEnabled(): Promise<void> {
    if (!(await this.storageSettings.resolved()).uploadsEnabled) {
      throw new AppException(ErrorCode.MEDIA_UPLOADS_UNAVAILABLE);
    }
  }

  /**
   * The base of public media URLs (D155: report snapshots build their file's URL from it): the panel's public base
   * URL when its storage is on (D222), else `MEDIA_PUBLIC_BASE_URL`.
   */
  get publicBaseUrl(): string | undefined {
    return this.storageSettings.current().publicBaseUrl;
  }

  private publicUrl(key: string): string {
    return `${this.publicBaseUrl ?? ''}/${key}`;
  }

  toDto(
    asset: Pick<
      MediaAsset,
      'id' | 'kind' | 'width' | 'height' | 'blurhash' | 'largeKey' | 'thumbKey' | 'durationMs' | 'posterKey'
    >,
  ): MediaAssetDto {
    const dto: MediaAssetDto = {
      id: asset.id,
      type: isVoiceKind(asset.kind) ? 'AUDIO' : isVideoKind(asset.kind) ? 'VIDEO' : 'IMAGE',
      status: 'READY',
      width: asset.width,
      height: asset.height,
      blurhash: asset.blurhash,
      url: this.publicUrl(asset.largeKey),
      thumbUrl: this.publicUrl(asset.thumbKey),
    };
    if (asset.posterKey !== null && isVideoKind(asset.kind)) dto.posterUrl = this.publicUrl(asset.posterKey);
    if (asset.durationMs !== null) dto.durationMs = asset.durationMs;
    return dto;
  }

  /** The public URL of an asset's large variant (a live cover's 640 px square, CP-015). */
  largeUrl(asset: Pick<MediaAsset, 'largeKey'>): string {
    return this.publicUrl(asset.largeKey);
  }

  /**
   * v1.54-social (D185, §10.48): consumes the caller's pending private upload of `kind` (a recharge-agent
   * application's photo or selfie): checks and re-encodes it like any image (metadata stripped, at most
   * 1 080 px), stores it at `toKey` with `private, no-store` (a prefix that is never public), marks the upload
   * completed without an asset and deletes the raw object. Returns false — nothing stored — when the upload is
   * not the caller's pending one of that kind, its slot expired or the bytes are not a valid image.
   */
  async consumePrivateImage(
    userId: string,
    uploadId: string,
    kind: MediaKind,
    toKey: string,
  ): Promise<boolean> {
    if (!isPrivateKind(kind) || !isUuid(uploadId)) return false;
    const upload = await this.prisma.mediaUpload.findFirst({
      where: { id: uploadId.toLowerCase(), userId, kind, status: 'PENDING' },
    });
    if (!upload || upload.expiresAt.getTime() + SLOT_GRACE_MS < Date.now()) return false;
    const head = await this.storage.head(upload.objectKey);
    if (!head || head.size !== upload.byteSize) return false;
    const bytes = await this.storage.get(upload.objectKey, upload.byteSize);
    if (!bytes || bytes.length !== upload.byteSize) return false;
    let image;
    try {
      image = await processImage(bytes, upload.contentType as ImageContentType, LARGE_SIDE, 'inside');
    } catch (err) {
      if (err instanceof InvalidImageError) {
        this.logger.warn({ uploadId: upload.id, reason: err.message }, 'Private upload rejected');
        return false;
      }
      throw err;
    }
    await this.storage.put(toKey, image.large, 'image/webp', 'private, no-store');
    const done = await this.prisma.mediaUpload.updateMany({
      where: { id: upload.id, status: 'PENDING' },
      data: { status: 'COMPLETED', completedAt: new Date() },
    });
    await this.storage.delete([upload.objectKey]).catch(() => undefined);
    return done.count === 1;
  }

  /** v1.54-social (D185): deletes private objects (retention); best effort is not enough — it throws. */
  async deletePrivateObjects(keys: readonly string[]): Promise<void> {
    if (keys.length > 0) await this.storage.delete(keys);
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
   * v1.40-social (D155): copies a stored object to `toKey` (a report's own copy of a direct
   * message's file, kept after the message is deleted). Returns false when the source is gone.
   */
  async copyObject(fromKey: string, toKey: string, contentType: string): Promise<boolean> {
    const bytes = await this.storage.get(fromKey, 16 * 1024 * 1024);
    if (!bytes) return false;
    await this.storage.put(toKey, bytes, contentType, 'private, no-store');
    return true;
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

  /**
   * v1.134-social (D381, §10.171.8) LONGER_VOICE: [userId]'s voice clip limits now — the perk's seconds (and the size
   * scaled with them) while held, else 30 s and 1 MiB. Checked when the upload is requested and again when completed.
   */
  async voiceLimits(userId: string): Promise<VoiceLimits> {
    return voiceLimitsFor(await vipPerkIntIn(this.prisma, userId, 'LONGER_VOICE', new Date()));
  }

  /** `POST /media/uploads` (the rate limit was counted by the guard, before this check). */
  async createUpload(userId: string, body: unknown): Promise<MediaUploadDto> {
    await this.assertEnabled();
    const parsed = createMediaUploadSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const { kind, contentType, byteSize } = parsed.data;
    // v1.134-social (D381, §10.171.8): a voice clip up to the uploader's limit (1 MiB, LONGER_VOICE's more).
    if (isVoiceKind(kind) && byteSize > (await this.voiceLimits(userId)).maxBytes) {
      throw AppException.validation([{ field: 'byteSize', issue: 'too_big' }]);
    }
    // v1.95-social (D301, §10.112.1): only the app owner uploads a cover video.
    if (kind === 'PROFILE_COVER_VIDEO') await assertKabsoOwner(this.prisma, userId);
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

  /**
   * `POST /media/uploads/{uploadId}/complete`. Only the uploader; anyone else gets 404. v1.41-social
   * (D162): `body` is `{posterId}` for a video upload and empty for every other kind.
   */
  async completeUpload(userId: string, uploadId: string, body?: unknown): Promise<MediaAssetDto> {
    await this.assertEnabled();
    if (!isUuid(uploadId)) throw new AppException(ErrorCode.NOT_FOUND);
    const upload = await this.prisma.mediaUpload.findFirst({
      where: { id: uploadId.toLowerCase(), userId },
      include: { mediaAsset: true },
    });
    // v1.54-social (D185): a private kind is never completed (only its application consumes it).
    if (!upload || isPrivateKind(upload.kind)) throw new AppException(ErrorCode.NOT_FOUND);
    const parsed = completeMediaUploadSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const posterId = parsed.data.posterId?.toLowerCase();
    const video = isVideoKind(upload.kind);
    if (!video && posterId !== undefined) {
      throw AppException.validation([{ field: 'posterId', issue: 'unknown_field' }]);
    }
    if (upload.status === 'COMPLETED' && upload.mediaAsset) return this.toDto(upload.mediaAsset);
    if (video && posterId === undefined) {
      throw AppException.validation([{ field: 'posterId', issue: 'required' }]);
    }
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
    if (video && !(await this.findPoster(userId, posterId!))) {
      throw AppException.validation([{ field: 'posterId', issue: 'invalid_value' }]);
    }
    const head = await this.storage.head(upload.objectKey);
    if (!head) return fail('object missing');
    if (head.size !== upload.byteSize) return fail('size mismatch');
    if (video) {
      let info: VideoInfo;
      try {
        info = await inspectVideo(
          (offset, length) => this.storage.getRange(upload.objectKey, offset, length),
          head.size,
          upload.contentType as VideoContentType,
          upload.kind as VideoKind,
        );
      } catch (err) {
        if (err instanceof InvalidVideoError) return fail(err.message);
        throw err;
      }
      return this.toDto(await this.storeVideo(userId, upload, posterId!, info));
    }
    const bytes = await this.storage.get(upload.objectKey, upload.byteSize);
    if (!bytes || bytes.length !== upload.byteSize) return fail('size mismatch');

    const kind = MEDIA_KINDS.find((k) => k === upload.kind) ?? 'POST_IMAGE';
    if (isVoiceKind(kind)) {
      let clip: { durationMs: number };
      try {
        clip = verifyVoiceClip(bytes, await this.voiceLimits(userId));
      } catch (err) {
        if (err instanceof InvalidAudioError) return fail(err.message);
        throw err;
      }
      return this.toDto(await this.storeVoice(userId, upload, bytes, clip.durationMs, kind));
    }
    const shape: ImageShape =
      kind === 'HOME_BANNER'
        ? 'banner'
        : kind === 'LIVE_COVER' || kind === 'FAMILY_EMBLEM' || kind === 'AVATAR' || kind === 'DM_GROUP_PHOTO'
          ? 'square'
          : 'inside';
    const side =
      kind === 'STORY_IMAGE'
        ? STORY_LARGE_SIDE
        : shape === 'banner'
          ? BANNER_WIDTH
          : shape === 'square'
            ? COVER_SIDE
            : LARGE_SIDE;
    let image;
    try {
      image = await processImage(bytes, upload.contentType as ImageContentType, side, shape);
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
    kind: MediaKind = 'LIVE_CHAT_VOICE',
  ): Promise<MediaAsset> {
    const key = `media/${upload.id}/voice.m4a`;
    await this.storage.put(key, bytes, 'audio/mp4', IMMUTABLE_CACHE);
    const asset = await this.prisma.$transaction(async (tx) => {
      await tx.mediaAsset.createMany({
        data: [
          {
            id: upload.id,
            ownerId: userId,
            kind,
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

  /** The caller's READY, unattached `VIDEO_POSTER` younger than 24 h, or null. */
  private findPoster(userId: string, posterId: string): Promise<MediaAsset | null> {
    return this.prisma.mediaAsset.findFirst({
      where: {
        id: posterId,
        ownerId: userId,
        kind: 'VIDEO_POSTER',
        attachedAt: null,
        createdAt: { gt: new Date(Date.now() - 24 * 3600 * 1000) },
      },
    });
  }

  /**
   * v1.41-social (D162): a checked video is copied unchanged by the storage service to
   * `media/{mediaId}/video.mp4|.mov`; in one transaction the poster row is locked, its objects
   * become the video's poster and thumbnail, and the poster row is deleted. A poster taken by a
   * concurrent request → 400 `posterId` / `invalid_value` (the copy is removed, the slot stays
   * open). Idempotent with the asset id = the upload id.
   */
  private async storeVideo(
    userId: string,
    upload: { id: string; kind: string; objectKey: string; contentType: string; byteSize: number },
    posterId: string,
    info: VideoInfo,
  ): Promise<MediaAsset> {
    const key = `media/${upload.id}/video.${upload.contentType === 'video/quicktime' ? 'mov' : 'mp4'}`;
    await this.storage.copy(upload.objectKey, key, upload.contentType, IMMUTABLE_CACHE);
    let asset: MediaAsset | null;
    try {
      asset = await this.prisma.$transaction(async (tx) => {
        const locked = await tx.$queryRaw<{ id: string }[]>`
          SELECT id FROM media_assets
           WHERE id = ${posterId}::uuid AND owner_id = ${userId}::uuid AND kind = 'VIDEO_POSTER'
             AND attached_at IS NULL AND created_at > now() - interval '24 hours'
           FOR UPDATE`;
        if (locked.length === 0) return null;
        const poster = await tx.mediaAsset.findUniqueOrThrow({ where: { id: posterId } });
        await tx.mediaAsset.createMany({
          data: [
            {
              id: upload.id,
              ownerId: userId,
              kind: upload.kind,
              width: info.width,
              height: info.height,
              durationMs: info.durationMs,
              blurhash: poster.blurhash,
              largeKey: key,
              thumbKey: poster.thumbKey,
              posterKey: poster.largeKey,
              byteSize: upload.byteSize,
            },
          ],
          skipDuplicates: true,
        });
        await tx.mediaAsset.delete({ where: { id: poster.id } });
        await tx.mediaUpload.updateMany({
          where: { id: upload.id, status: 'PENDING' },
          data: { status: 'COMPLETED', completedAt: new Date(), mediaAssetId: upload.id },
        });
        return tx.mediaAsset.findUniqueOrThrow({ where: { id: upload.id } });
      });
    } catch (err) {
      await this.storage.delete([key]).catch(() => undefined);
      throw err;
    }
    if (!asset) {
      await this.storage.delete([key]).catch(() => undefined);
      throw AppException.validation([{ field: 'posterId', issue: 'invalid_value' }]);
    }
    await this.storage.delete([upload.objectKey]).catch((err: unknown) => {
      this.logger.warn({ uploadId: upload.id, error: safeErrorLog(err) }, 'Upload object not deleted');
    });
    return asset;
  }

  /**
   * v1.89-social (D290, §10.103): a video sent as raw bytes by the admin panel (`POST /admin/level-raise-videos`; the
   * panel has no presigned upload). Checked like an uploaded video of `kind` (the container: brand, length, codec,
   * size), stored unchanged at `media/{id}/video.mp4|.mov` without a poster (the panel plays it), unattached (the
   * request attaches it; unattached assets are swept after 24 h like any upload). 400 `MEDIA_INVALID` otherwise.
   */
  async storeRawVideo(userId: string, bytes: Buffer, kind: VideoKind): Promise<MediaAsset> {
    await this.assertEnabled();
    const limits = VIDEO_LIMITS[kind];
    if (bytes.length === 0 || bytes.length > limits.maxBytes) throw new AppException(ErrorCode.MEDIA_INVALID);
    const brand = bytes.length >= 12 ? bytes.toString('latin1', 4, 12) : '';
    if (!brand.startsWith('ftyp')) throw new AppException(ErrorCode.MEDIA_INVALID);
    const contentType: VideoContentType = brand.slice(4) === 'qt  ' ? 'video/quicktime' : 'video/mp4';
    let info: VideoInfo;
    try {
      info = await inspectVideo(
        (offset, length) => Promise.resolve(bytes.subarray(offset, Math.min(offset + length, bytes.length))),
        bytes.length,
        contentType,
        kind,
      );
    } catch (err) {
      if (err instanceof InvalidVideoError) {
        this.logger.warn({ reason: err.message }, 'Raw video rejected');
        throw new AppException(ErrorCode.MEDIA_INVALID);
      }
      throw err;
    }
    const id = uuidv7();
    const key = `media/${id}/video.${contentType === 'video/quicktime' ? 'mov' : 'mp4'}`;
    await this.storage.put(key, bytes, contentType, IMMUTABLE_CACHE);
    try {
      return await this.prisma.mediaAsset.create({
        data: {
          id,
          ownerId: userId,
          kind,
          width: info.width,
          height: info.height,
          durationMs: info.durationMs,
          blurhash: null,
          largeKey: key,
          thumbKey: key,
          posterKey: null,
          byteSize: bytes.length,
        },
      });
    } catch (err) {
      await this.storage.delete([key]).catch(() => undefined);
      throw err;
    }
  }

  /**
   * v1.137-social (D385, §10.174.6; owner 2026-11-12): a picture the team sends in «دعم كابسو» — the bytes go through
   * the same validation and re-encoding as a `DM_IMAGE` upload (allowed types, ≤ 15 MiB, decoded and written as WebP
   * at the post-image size) and become an asset of [userId], attached at once (never swept as unattached). Throws 400
   * `MEDIA_INVALID` for a file the pipeline refuses.
   */
  async storeRawImage(userId: string, bytes: Buffer, contentType: string): Promise<MediaAsset> {
    await this.assertEnabled();
    if (!(IMAGE_CONTENT_TYPES as readonly string[]).includes(contentType)) {
      throw AppException.validation([{ field: 'mime', issue: 'not_allowed' }]);
    }
    if (bytes.length === 0 || bytes.length > MAX_IMAGE_BYTES) throw new AppException(ErrorCode.MEDIA_INVALID);
    let image;
    try {
      image = await processImage(bytes, contentType as ImageContentType, LARGE_SIDE, 'inside');
    } catch (err) {
      if (err instanceof InvalidImageError) {
        this.logger.warn({ reason: err.message }, 'Raw image rejected');
        throw new AppException(ErrorCode.MEDIA_INVALID);
      }
      throw err;
    }
    const id = uuidv7();
    const largeKey = `media/${id}/${LARGE_SIDE}.webp`;
    const thumbKey = `media/${id}/320.webp`;
    await this.storage.put(largeKey, image.large, 'image/webp', IMMUTABLE_CACHE);
    await this.storage.put(thumbKey, image.thumb, 'image/webp', IMMUTABLE_CACHE);
    try {
      return await this.prisma.mediaAsset.create({
        data: {
          id,
          ownerId: userId,
          kind: 'DM_IMAGE',
          width: image.width,
          height: image.height,
          blurhash: image.blurhash,
          largeKey,
          thumbKey,
          byteSize: image.large.length,
          attachedAt: new Date(),
        },
      });
    } catch (err) {
      await this.storage.delete([largeKey, thumbKey]).catch(() => undefined);
      throw err;
    }
  }

  /** v1.89-social (D290): the size and type of a stored object (the panel's video proxy), or null. */
  headObject(key: string) {
    return this.storage.head(key);
  }

  /** v1.89-social (D290): `length` bytes of a stored object from `offset` (the panel's video proxy), or null. */
  readRange(key: string, offset: number, length: number): Promise<Buffer | null> {
    return this.storage.getRange(key, offset, length);
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
    kind: MediaKind | readonly MediaKind[] = 'POST_IMAGE',
  ): Promise<MediaAsset[] | null> {
    if (ids.length === 0) return [];
    const lower = ids.map((id) => id.toLowerCase());
    const kinds: string[] = typeof kind === 'string' ? [kind] : [...kind];
    const locked = await tx.$queryRaw<{ id: string }[]>`
      SELECT id FROM media_assets
      WHERE id = ANY(${lower}::uuid[]) AND owner_id = ${userId}::uuid AND attached_at IS NULL
        AND kind = ANY(${kinds}::text[])
        AND created_at > now() - interval '24 hours'
        -- D168: a post video uploaded before the 90 s limit and longer than it is not attachable.
        AND NOT (kind = 'POST_VIDEO' AND duration_ms > ${VIDEO_LIMITS.POST_VIDEO.maxDurationMs})
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
        // D290: decided level-raise videos left over (a storage failure at the decision).
        .then(() => this.purgeLevelRaiseVideos())
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
  /**
   * v1.89-social (D290, §10.103.5): deletes the videos of decided level-raise requests (`video_deleted_at` set at the
   * decision) — the objects first, then the asset rows (the request's `video_media_id` becomes NULL; its evidence
   * columns stay). Called right after a decision for that request and by every media sweep for any left over. Never
   * throws: a storage failure is logged and the rows stay, so the next sweep retries (idempotent: deleting a missing
   * object succeeds, and a deleted row is not found again). Returns the number of videos deleted.
   */
  async purgeLevelRaiseVideos(requestIds?: readonly string[]): Promise<number> {
    try {
      const rows = await this.prisma.$queryRaw<
        { id: string; large_key: string; thumb_key: string; poster_key: string | null }[]
      >`
        SELECT a.id, a.large_key, a.thumb_key, a.poster_key
          FROM level_raise_requests r JOIN media_assets a ON a.id = r.video_media_id
         WHERE r.video_deleted_at IS NOT NULL
           AND (${requestIds === undefined}::boolean OR r.id = ANY(${[...(requestIds ?? [])]}::uuid[]))
         ORDER BY r.video_deleted_at
         LIMIT ${SWEEP_BATCH}`;
      if (rows.length === 0) return 0;
      await this.storage.delete([
        ...new Set(rows.flatMap((a) => [a.large_key, a.thumb_key, ...(a.poster_key ? [a.poster_key] : [])])),
      ]);
      const deleted = await this.prisma.mediaAsset.deleteMany({
        where: { id: { in: rows.map((r) => r.id) } },
      });
      return deleted.count;
    } catch (err) {
      this.logger.warn(
        { error: safeErrorLog(err) },
        'Level-raise videos not deleted yet (retried by the sweep)',
      );
      return 0;
    }
  }

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
    const stale = await this.prisma.$queryRaw<
      { large_key: string; thumb_key: string; poster_key: string | null }[]
    >`
      DELETE FROM media_assets
      WHERE id IN (
        SELECT id FROM media_assets
        WHERE attached_at IS NULL AND created_at < now() - interval '24 hours'
        ORDER BY created_at
        LIMIT ${SWEEP_BATCH}
        FOR UPDATE SKIP LOCKED)
        AND attached_at IS NULL
      RETURNING large_key, thumb_key, poster_key`;
    if (stale.length > 0) {
      await this.storage.delete(
        stale.flatMap((a) => [a.large_key, a.thumb_key, ...(a.poster_key ? [a.poster_key] : [])]),
      );
    }
    return { slots: slots.length, assets: stale.length };
  }
}
