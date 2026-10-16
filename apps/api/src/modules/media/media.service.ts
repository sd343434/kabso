import { randomBytes } from 'node:crypto';
import { Inject, Injectable, Logger, type OnModuleDestroy } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { BackgroundTasks } from '../../common/background/background-tasks.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { uuidV7 } from '../../common/ids/uuid-v7.js';
import { RateLimitService } from '../../common/rate-limit/rate-limit.service.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { ProcessOutcome } from './image-pipeline.js';
import { ImageProcessor, type ProcessingSlot } from './image-processor.js';
import {
  COMPLETE_GRACE_MS,
  MEDIA_CONTENT_TYPES,
  MEDIA_MAX_PIXELS,
  MEDIA_MAX_SIDE,
  PUBLIC_CACHE_CONTROL,
  PURPOSES,
  rulesForDb,
  type ApiMediaPurpose,
  type DbMediaPurpose,
  type MediaContentType,
  type MediaFailureIssue,
  type ModerationStatus,
} from './media.constants.js';
import { MEDIA_MODERATION, type MediaModerationPort, type ModerationDecision } from './media-moderation.js';
import { MEDIA_STORAGE, StoredObjectTooLargeError, type MediaStorage } from './media-storage.js';
import { MediaUrls, publicKeys } from './media-urls.js';
import { createMediaUploadSchema } from './media.schemas.js';

// ---- Response shapes (openapi v1.4) ------------------------------------------------------------

export interface MediaPurposeLimitsDto {
  maxBytes: number;
  minWidth: number;
  minHeight: number;
  aspectRatio: '1:1' | '3:4';
}

export interface MediaConfigDto {
  uploadsEnabled: boolean;
  allowedContentTypes: MediaContentType[];
  maxPixels: number;
  maxSidePixels: number;
  purposes: { avatar: MediaPurposeLimitsDto; room_cover: MediaPurposeLimitsDto };
}

export interface MediaUploadTicketDto {
  uploadId: string;
  purpose: ApiMediaPurpose;
  method: 'PUT';
  url: string;
  headers: Record<string, string>;
  expiresAt: string;
}

export type MediaUploadStatus = 'AWAITING_UPLOAD' | 'READY' | 'FAILED' | 'EXPIRED' | 'DELETED';

export interface MediaUploadDto {
  uploadId: string;
  purpose: ApiMediaPurpose;
  status: MediaUploadStatus;
  moderationStatus: ModerationStatus | null;
  width: number | null;
  height: number | null;
  url: string | null;
  thumbUrl: string | null;
  attached: boolean;
  expiresAt: string | null;
  failure: { field: 'file'; issue: MediaFailureIssue } | null;
}

/** Request facts recorded in the audit trail. */
export interface MediaRequestMeta {
  readonly ip: string | null;
  readonly requestId: string | null;
}

/** The `media_objects` columns the service reads. */
interface MediaRow {
  id: string;
  ownerUserId: string;
  purpose: DbMediaPurpose;
  status: MediaUploadStatus;
  declaredContentType: string;
  declaredBytes: number;
  incomingKey: string;
  uploadExpiresAt: Date;
  publicToken: string | null;
  width: number | null;
  height: number | null;
  failureIssue: string | null;
  moderationStatus: ModerationStatus | null;
  completedAt: Date | null;
  attachedAt: Date | null;
}

const ROW_SELECT = {
  id: true,
  ownerUserId: true,
  purpose: true,
  status: true,
  declaredContentType: true,
  declaredBytes: true,
  incomingKey: true,
  uploadExpiresAt: true,
  publicToken: true,
  width: true,
  height: true,
  failureIssue: true,
  moderationStatus: true,
  completedAt: true,
  attachedAt: true,
} as const;

const UUID_ANY = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Path / body ids that are not UUIDs never reach the database. */
export function isUuid(value: string): boolean {
  return UUID_ANY.test(value);
}

const FAILURE_ISSUES = new Set<MediaFailureIssue>(['too_big', 'too_small', 'invalid_format']);

function toFailureIssue(value: string | null): MediaFailureIssue {
  return value !== null && FAILURE_ISSUES.has(value as MediaFailureIssue)
    ? (value as MediaFailureIssue)
    : 'invalid_format';
}

function rejected(issue: MediaFailureIssue): AppException {
  return new AppException(ErrorCode.MEDIA_UPLOAD_REJECTED, undefined, [{ field: 'file', issue }]);
}

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND);
}

/** Interactive transaction limits; `complete` adds the processing time limit to the timeout. */
const MEDIA_TX_OPTIONS = { maxWait: 5_000, timeout: 10_000 } as const;
const MEDIA_STATEMENT_TIMEOUT_MS = 8_000;
/** Storage round trips inside `complete` (HEAD, GET, 2 × PUT, DELETE) on top of processing. */
const COMPLETE_STORAGE_BUDGET_MS = 60_000;

/** Bucket names (CONVENTIONS §7); the hour/day buckets are counted by the guard. */
export const MEDIA_BYTES_BUCKET = 'media:bytes:d';

type CompleteResult =
  | { readonly kind: 'ready'; readonly row: MediaRow; readonly moderationImage: Uint8Array | null }
  | { readonly kind: 'failed'; readonly issue: MediaFailureIssue };

/**
 * Media uploads (`media_objects`, owned by the media module; CONVENTIONS §11,
 * DB_PHASE2_MEDIA.md). Declares uploads (presigned PUT), verifies and processes them (`complete`,
 * in an isolated worker), attaches them as avatar or cover inside the caller's transaction, and
 * applies the moderation result. Everything that creates or processes an upload is behind
 * MEDIA_UPLOADS_ENABLED; reading an upload and removing an image always work.
 */
@Injectable()
export class MediaService implements OnModuleDestroy {
  private readonly logger = new Logger(MediaService.name);
  private readonly processor: ImageProcessor;

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly rateLimits: RateLimitService,
    private readonly background: BackgroundTasks,
    private readonly clock: Clock,
    readonly urls: MediaUrls,
    @Inject(MEDIA_STORAGE) private readonly storage: MediaStorage | null,
    @Inject(MEDIA_MODERATION) private readonly moderation: MediaModerationPort,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    this.processor = new ImageProcessor({
      maxConcurrency: config.media.processMaxConcurrency,
      timeoutMs: config.media.processTimeoutMs,
    });
  }

  async onModuleDestroy(): Promise<void> {
    await this.background.idle();
  }

  /** Image processing jobs running now in this process. */
  get processingActive(): number {
    return this.processor.active;
  }

  // ---- Feature gate --------------------------------------------------------------------------

  get uploadsEnabled(): boolean {
    return this.config.media.uploadsEnabled && this.storage !== null;
  }

  /** 503 MEDIA_UPLOADS_UNAVAILABLE (no Retry-After) while uploads are disabled (§11.1). */
  assertUploadsEnabled(): void {
    if (!this.uploadsEnabled) throw new AppException(ErrorCode.MEDIA_UPLOADS_UNAVAILABLE);
  }

  private requireStorage(): MediaStorage {
    if (this.storage === null) throw new AppException(ErrorCode.MEDIA_UPLOADS_UNAVAILABLE);
    return this.storage;
  }

  getConfig(): MediaConfigDto {
    const limits = (purpose: ApiMediaPurpose): MediaPurposeLimitsDto => {
      const r = PURPOSES[purpose];
      return {
        maxBytes: r.maxBytes,
        minWidth: r.minWidth,
        minHeight: r.minHeight,
        aspectRatio: r.aspectRatio,
      };
    };
    return {
      uploadsEnabled: this.uploadsEnabled,
      allowedContentTypes: [...MEDIA_CONTENT_TYPES],
      maxPixels: MEDIA_MAX_PIXELS,
      maxSidePixels: MEDIA_MAX_SIDE,
      purposes: { avatar: limits('avatar'), room_cover: limits('room_cover') },
    };
  }

  // ---- Reads ---------------------------------------------------------------------------------

  /** The owner-only view of an upload (openapi `MediaUpload`). */
  toUpload(row: MediaRow): MediaUploadDto {
    const rules = rulesForDb(row.purpose);
    const ready = row.status === 'READY';
    const urls = ready ? this.urls.urlsOf(row) : { url: null, thumbUrl: null };
    let expiresAt: string | null = null;
    if (row.status === 'AWAITING_UPLOAD') expiresAt = row.uploadExpiresAt.toISOString();
    else if (ready && row.attachedAt === null && row.completedAt !== null) {
      expiresAt = new Date(
        row.completedAt.getTime() + this.config.media.unattachedTtlHours * 3600 * 1000,
      ).toISOString();
    }
    return {
      uploadId: row.id,
      purpose: rules.api,
      status: row.status,
      moderationStatus: row.completedAt === null ? null : row.moderationStatus,
      width: ready ? row.width : null,
      height: ready ? row.height : null,
      url: urls.url,
      thumbUrl: urls.thumbUrl,
      attached: row.attachedAt !== null,
      expiresAt,
      failure: row.status === 'FAILED' ? { field: 'file', issue: toFailureIssue(row.failureIssue) } : null,
    };
  }

  private async findOwned(callerId: string, uploadId: string): Promise<MediaRow | null> {
    if (!isUuid(uploadId)) return null;
    return this.prisma.mediaObject.findFirst({
      where: { id: uploadId, ownerUserId: callerId },
      select: ROW_SELECT,
    });
  }

  /** `GET /media/uploads/{uploadId}`: owner only; another user's, unknown or malformed id → 404. */
  async getUpload(callerId: string, uploadId: string): Promise<MediaUploadDto> {
    const row = await this.findOwned(callerId, uploadId);
    if (!row) throw notFound();
    return this.toUpload(row);
  }

  // ---- Declare -------------------------------------------------------------------------------

  /**
   * `POST /media/uploads` (§11.3 step 1). Order after the guard's hour/day buckets: feature gate
   * → body → `room_cover` needs live hosting → pending-upload cap (429) → daily declared bytes
   * (429) → row + presigned PUT.
   */
  async createUpload(callerId: string, body: unknown): Promise<MediaUploadTicketDto> {
    this.assertUploadsEnabled();
    const storage = this.requireStorage();
    const parsed = createMediaUploadSchema.safeParse(body, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = parsed.data;
    const rules = PURPOSES[input.purpose];
    if (input.byteSize > rules.maxBytes)
      throw AppException.validation([{ field: 'byteSize', issue: 'too_big' }]);
    if (input.purpose === 'room_cover' && !this.config.live.hostingEnabled) {
      throw new AppException(ErrorCode.LIVE_HOSTING_UNAVAILABLE);
    }

    const now = this.clock.now();
    const expiresAt = new Date(now.getTime() + this.config.media.uploadUrlTtlSeconds * 1000);
    const id = uuidV7(now.getTime());
    const incomingKey = `in/${id}/${randomBytes(16).toString('base64url')}`;
    let bytesCounted = false;
    try {
      await this.prisma.$transaction(async (tx) => {
        await this.setStatementTimeout(tx);
        // Serializes this user's declares, so concurrent requests cannot exceed the cap.
        // $executeRaw: the function returns void, which $queryRaw cannot deserialize.
        await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`media-declare:${callerId}`}, 0))`;
        const pending = await tx.mediaObject.findMany({
          where: { ownerUserId: callerId, status: 'AWAITING_UPLOAD', uploadExpiresAt: { gt: now } },
          select: { uploadExpiresAt: true },
          orderBy: { uploadExpiresAt: 'asc' },
          take: this.config.media.maxPendingPerUser,
        });
        if (pending.length >= this.config.media.maxPendingPerUser) {
          const oldest = pending[0]!.uploadExpiresAt.getTime();
          throw new AppException(ErrorCode.RATE_LIMITED, undefined, undefined, {
            'Retry-After': String(Math.max(1, Math.ceil((oldest - now.getTime()) / 1000))),
          });
        }
        await this.rateLimits.consumeAmount(MEDIA_BYTES_BUCKET, callerId, input.byteSize, {
          max: this.config.media.dailyBytesPerUser,
          windowSeconds: 86_400,
        });
        bytesCounted = true;
        await tx.mediaObject.create({
          data: {
            id,
            ownerUserId: callerId,
            purpose: rules.db,
            declaredContentType: input.contentType,
            declaredBytes: input.byteSize,
            incomingKey,
            uploadExpiresAt: expiresAt,
            createdAt: now,
          },
        });
      }, MEDIA_TX_OPTIONS);
    } catch (err) {
      if (bytesCounted) await this.rateLimits.refundAmount(MEDIA_BYTES_BUCKET, callerId, input.byteSize);
      throw err;
    }

    try {
      const signed = await storage.presignPut(
        incomingKey,
        input.contentType,
        input.byteSize,
        this.config.media.uploadUrlTtlSeconds,
      );
      return {
        uploadId: id,
        purpose: input.purpose,
        method: 'PUT',
        url: signed.url,
        headers: { ...signed.headers },
        expiresAt: expiresAt.toISOString(),
      };
    } catch (err) {
      // Presigning is local computation; if it fails, leave nothing behind.
      await this.prisma.mediaObject.deleteMany({ where: { id, status: 'AWAITING_UPLOAD' } });
      await this.rateLimits.refundAmount(MEDIA_BYTES_BUCKET, callerId, input.byteSize);
      this.logger.error({ error: safeErrorLog(err) }, 'Presigning an upload failed');
      throw new AppException(ErrorCode.SERVICE_UNAVAILABLE);
    }
  }

  // ---- Complete ------------------------------------------------------------------------------

  /** The answer for an upload that is not (or no longer) waiting for its file. */
  private settledAnswer(row: MediaRow, now: Date): MediaUploadDto | AppException | null {
    switch (row.status) {
      case 'READY':
        return this.toUpload(row);
      case 'FAILED':
        return rejected(toFailureIssue(row.failureIssue));
      case 'EXPIRED':
      case 'DELETED':
        return new AppException(ErrorCode.MEDIA_UPLOAD_EXPIRED);
      default:
        if (now.getTime() > row.uploadExpiresAt.getTime() + COMPLETE_GRACE_MS) {
          return new AppException(ErrorCode.MEDIA_UPLOAD_EXPIRED);
        }
        return null;
    }
  }

  /**
   * `POST /media/uploads/{uploadId}/complete` (§11.3 step 3). Synchronous and idempotent: READY →
   * 200 again, FAILED → the same 422. The row is locked (`FOR UPDATE`) for the whole check, so two
   * concurrent completes process the image once and the loser returns the winner's result.
   */
  async completeUpload(callerId: string, uploadId: string, meta: MediaRequestMeta): Promise<MediaUploadDto> {
    this.assertUploadsEnabled();
    const storage = this.requireStorage();
    const row = await this.findOwned(callerId, uploadId);
    if (!row) throw notFound();
    const early = this.settledAnswer(row, this.clock.now());
    if (early instanceof AppException) throw early;
    if (early) return early;

    // 503 + Retry-After at once when processing is saturated (nothing changes).
    const slot = this.processor.reserve();
    let result: CompleteResult | MediaUploadDto;
    try {
      result = await this.prisma.$transaction(
        (tx) => this.completeLocked(tx, storage, slot, callerId, uploadId, meta),
        {
          maxWait: MEDIA_TX_OPTIONS.maxWait,
          timeout: this.config.media.processTimeoutMs + COMPLETE_STORAGE_BUDGET_MS,
        },
      );
    } finally {
      slot.release();
    }
    if ('uploadId' in result) return result;
    if (result.kind === 'failed') throw rejected(result.issue);
    if (result.moderationImage) this.scheduleModeration(result.row, result.moderationImage);
    return this.toUpload(result.row);
  }

  private async completeLocked(
    tx: Prisma.TransactionClient,
    storage: MediaStorage,
    slot: ProcessingSlot,
    callerId: string,
    uploadId: string,
    meta: MediaRequestMeta,
  ): Promise<CompleteResult | MediaUploadDto> {
    await this.setStatementTimeout(tx);
    const locked = await tx.$queryRaw<{ id: string }[]>`
      SELECT id::text AS id FROM media_objects
       WHERE id = ${uploadId}::uuid AND owner_user_id = ${callerId}::uuid FOR UPDATE`;
    if (locked.length === 0) throw notFound();
    const row: MediaRow = await tx.mediaObject.findUniqueOrThrow({
      where: { id: uploadId },
      select: ROW_SELECT,
    });
    const now = this.clock.now();
    const settled = this.settledAnswer(row, now);
    if (settled instanceof AppException) throw settled;
    if (settled) return settled; // a concurrent complete won

    const rules = rulesForDb(row.purpose);
    const head = await this.storageCall(() => storage.headIncoming(row.incomingKey));
    if (head === null) throw new AppException(ErrorCode.MEDIA_UPLOAD_NOT_RECEIVED);

    let outcome: ProcessOutcome;
    if (head.size > row.declaredBytes || head.size > rules.maxBytes) {
      outcome = { ok: false, issue: 'too_big', reason: 'stored_size' };
    } else if (head.size !== row.declaredBytes) {
      outcome = { ok: false, issue: 'invalid_format', reason: 'truncated' };
    } else {
      let bytes: Buffer | null = null;
      try {
        bytes = await storage.readIncoming(row.incomingKey, row.declaredBytes);
      } catch (err) {
        if (!(err instanceof StoredObjectTooLargeError)) throw this.storageFailure(err);
      }
      if (bytes === null) outcome = { ok: false, issue: 'too_big', reason: 'stored_size' };
      else if (bytes.length !== row.declaredBytes) {
        outcome = { ok: false, issue: 'invalid_format', reason: 'truncated' };
      } else {
        outcome = await slot.run({
          bytes,
          declaredType: row.declaredContentType as MediaContentType,
          rules: {
            ratio: rules.ratio,
            minWidth: rules.minWidth,
            minHeight: rules.minHeight,
            main: rules.main,
            thumb: rules.thumb,
          },
        });
      }
    }

    if (!outcome.ok) {
      // The original is deleted at once; the row is kept 7 days for abuse analysis (§11.6).
      await this.deleteIncomingQuietly(storage, row.incomingKey);
      await tx.mediaObject.update({
        where: { id: row.id },
        data: { status: 'FAILED', failureIssue: outcome.issue, updatedAt: now },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.MEDIA_UPLOAD_REJECT,
        actorUserId: callerId,
        targetType: 'media_object',
        targetId: row.id,
        metadata: { issue: outcome.issue, reason: outcome.reason, purpose: rules.api },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      return { kind: 'failed', issue: outcome.issue };
    }

    const token = randomBytes(16).toString('base64url');
    const keys = publicKeys(row.purpose, token);
    await this.storageCall(() =>
      storage.putPublic(keys.main, outcome.main.data, 'image/webp', PUBLIC_CACHE_CONTROL),
    );
    await this.storageCall(() =>
      storage.putPublic(keys.thumb, outcome.thumb.data, 'image/webp', PUBLIC_CACHE_CONTROL),
    );
    await this.deleteIncomingQuietly(storage, row.incomingKey);
    const updated: MediaRow = await tx.mediaObject.update({
      where: { id: row.id },
      data: {
        status: 'READY',
        detectedContentType: outcome.detectedType,
        publicToken: token,
        width: outcome.main.width,
        height: outcome.main.height,
        thumbWidth: outcome.thumb.width,
        thumbHeight: outcome.thumb.height,
        storedBytes: outcome.main.data.byteLength + outcome.thumb.data.byteLength,
        moderationStatus: 'PENDING',
        completedAt: now,
        updatedAt: now,
      },
      select: ROW_SELECT,
    });
    await this.audit.recordIn(tx, {
      action: AuditAction.MEDIA_UPLOAD_COMPLETE,
      actorUserId: callerId,
      targetType: 'media_object',
      targetId: row.id,
      metadata: { purpose: rules.api },
      ip: meta.ip,
      requestId: meta.requestId,
    });
    return { kind: 'ready', row: updated, moderationImage: outcome.main.data };
  }

  private async deleteIncomingQuietly(storage: MediaStorage, key: string): Promise<void> {
    try {
      await storage.deleteIncoming(key);
    } catch (err) {
      // The cleanup job and the bucket's 1-day lifecycle rule remove it later.
      this.logger.warn({ error: safeErrorLog(err) }, 'Deleting an incoming object failed');
    }
  }

  /** A storage failure is a dependency failure: 503, never the provider's message. */
  private storageFailure(err: unknown): AppException {
    if (err instanceof AppException) return err;
    this.logger.error({ error: safeErrorLog(err) }, 'Media storage request failed');
    return new AppException(ErrorCode.SERVICE_UNAVAILABLE);
  }

  private async storageCall<T>(call: () => Promise<T>): Promise<T> {
    try {
      return await call();
    } catch (err) {
      throw this.storageFailure(err);
    }
  }

  private async setStatementTimeout(tx: Prisma.TransactionClient): Promise<void> {
    await tx.$queryRaw`SELECT set_config('statement_timeout', ${String(MEDIA_STATEMENT_TIMEOUT_MS)}, true)`;
  }

  // ---- Moderation ----------------------------------------------------------------------------

  private scheduleModeration(row: MediaRow, image: Uint8Array): void {
    this.background.run('media.moderation', async () => {
      const decision = await this.moderation.review({ uploadId: row.id, purpose: row.purpose, image });
      if (decision) await this.applyModeration(row.id, decision, this.moderation.source);
    });
  }

  /**
   * Applies a moderation decision (§11.5) to a READY, PENDING (or APPROVED, for a later
   * rejection) image. REJECTED detaches it from the profile or room at once, writes the
   * `media.moderation.reject` audit row, and leaves the storage deletion to the cleanup job (no
   * grace period). Returns false when nothing changed.
   */
  async applyModeration(uploadId: string, decision: ModerationDecision, source: string): Promise<boolean> {
    const now = this.clock.now();
    if (decision === 'APPROVED') {
      const updated = await this.prisma.mediaObject.updateMany({
        where: { id: uploadId, status: 'READY', moderationStatus: 'PENDING' },
        data: { moderationStatus: 'APPROVED', moderationSource: source.slice(0, 32), moderatedAt: now },
      });
      return updated.count === 1;
    }
    return this.prisma.$transaction(async (tx) => {
      await this.setStatementTimeout(tx);
      const rows = await tx.$queryRaw<{ id: string; owner_user_id: string; purpose: string }[]>`
        UPDATE media_objects
           SET moderation_status = 'REJECTED', moderation_source = ${source.slice(0, 32)},
               moderated_at = ${now.toISOString()}::timestamptz,
               detached_at = CASE WHEN attached_at IS NOT NULL THEN COALESCE(detached_at, ${now.toISOString()}::timestamptz) END,
               updated_at = ${now.toISOString()}::timestamptz
         WHERE id = ${uploadId}::uuid AND status = 'READY' AND moderation_status <> 'REJECTED'
     RETURNING id::text AS id, owner_user_id::text AS owner_user_id, purpose::text AS purpose`;
      const row = rows[0];
      if (!row) return false;
      // DB_PHASE2_MEDIA §2 "Reject": the referencing column is cleared wherever it points here.
      await tx.$executeRaw`UPDATE user_profiles SET avatar_media_id = NULL, updated_at = ${now.toISOString()}::timestamptz WHERE avatar_media_id = ${uploadId}::uuid`;
      await tx.$executeRaw`UPDATE live_rooms SET cover_media_id = NULL, updated_at = ${now.toISOString()}::timestamptz WHERE cover_media_id = ${uploadId}::uuid`;
      await this.audit.recordIn(tx, {
        action: AuditAction.MEDIA_MODERATION_REJECT,
        actorUserId: null,
        targetType: 'media_object',
        targetId: uploadId,
        metadata: { source: source.slice(0, 32), purpose: row.purpose, ownerUserId: row.owner_user_id },
      });
      return true;
    }, MEDIA_TX_OPTIONS);
  }

  // ---- Attach / detach (inside the caller's transaction) -------------------------------------

  /**
   * Attaches the caller's own READY, unattached, not REJECTED upload of `purpose`
   * (DB_PHASE2_MEDIA §2 "Attach"). False for every other case, which the caller reports as one
   * 400 `invalid_value` without saying which condition failed.
   */
  async attachIn(
    tx: Prisma.TransactionClient,
    ownerUserId: string,
    uploadId: string,
    purpose: DbMediaPurpose,
    now: Date,
  ): Promise<boolean> {
    if (!isUuid(uploadId)) return false;
    const rows = await tx.$queryRaw<{ id: string }[]>`
      UPDATE media_objects SET attached_at = ${now.toISOString()}::timestamptz, updated_at = ${now.toISOString()}::timestamptz
       WHERE id = ${uploadId}::uuid AND owner_user_id = ${ownerUserId}::uuid
         AND purpose = ${purpose}::media_purpose AND status = 'READY' AND attached_at IS NULL
         AND moderation_status <> 'REJECTED'
   RETURNING id::text AS id`;
    return rows.length === 1;
  }

  /**
   * Account soft deletion (DB_PHASE2_MEDIA §4, `MediaService.purgeUser`): inside the lifecycle
   * transaction, detaches the user's avatar and the covers of their rooms. The cleanup job then
   * deletes every storage object of the DELETED account (its "soft-deleted accounts" pass), well
   * within the contract's 24 h.
   */
  async purgeUserIn(tx: Prisma.TransactionClient, userId: string, now: Date): Promise<void> {
    const at = now.toISOString();
    await tx.$executeRaw`UPDATE user_profiles SET avatar_media_id = NULL, updated_at = ${at}::timestamptz WHERE user_id = ${userId}::uuid AND avatar_media_id IS NOT NULL`;
    await tx.$executeRaw`UPDATE live_rooms SET cover_media_id = NULL, updated_at = ${at}::timestamptz WHERE host_user_id = ${userId}::uuid AND cover_media_id IS NOT NULL`;
    await tx.$executeRaw`
      UPDATE media_objects SET detached_at = ${at}::timestamptz, updated_at = ${at}::timestamptz
       WHERE owner_user_id = ${userId}::uuid AND attached_at IS NOT NULL AND detached_at IS NULL`;
  }

  /** Starts the grace period of an image that stopped being an avatar or cover (§11.6). */
  async detachIn(tx: Prisma.TransactionClient, mediaId: string, now: Date): Promise<void> {
    await tx.$executeRaw`
      UPDATE media_objects SET detached_at = ${now.toISOString()}::timestamptz, updated_at = ${now.toISOString()}::timestamptz
       WHERE id = ${mediaId}::uuid AND attached_at IS NOT NULL AND detached_at IS NULL`;
  }
}
