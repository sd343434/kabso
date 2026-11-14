import { randomBytes } from 'node:crypto';
import { StorageSettingsStore } from '../storage-settings/storage-settings.store.js';
import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { BackgroundTasks } from '../../common/background/background-tasks.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { DataExport } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { normalizePassword } from '../auth/auth.schemas.js';
import type { RequestMeta } from '../auth/auth.service.js';
import { PasswordHasher } from '../auth/password-hasher.service.js';
import { MAIL_SENDER, type MailSender } from '../mail/mail-sender.js';
import { OBJECT_STORAGE, type ObjectStorage } from '../media/object-storage.js';
import { Notifier } from '../notifications/notifier.js';
import { buildDataExport, exportObjectKey, nextExportAllowedAt, tokenHash } from './data-export.js';

/** `DataExportRequestBody` (openapi v1.66-social): the password again. */
export const dataExportRequestSchema = z.strictObject({
  password: z
    .string()
    .min(1)
    .max(512)
    .transform(normalizePassword)
    .refine((v) => [...v].length <= 128, { params: { issue: 'too_long' } }),
});
export type DataExportRequestInput = z.output<typeof dataExportRequestSchema>;

export const downloadQuerySchema = z.strictObject({ token: z.string().regex(/^[A-Za-z0-9_-]{43}$/) });

/** `DataExport` (openapi). */
export interface DataExportDto {
  id: string;
  status: 'PENDING' | 'READY' | 'DOWNLOADED' | 'EXPIRED' | 'FAILED';
  requestedAt: string;
  readyAt: string | null;
  /** When the download link stops working (READY only). */
  expiresAt: string | null;
  downloadedAt: string | null;
  sizeBytes: number | null;
}

/** `DataExportLink` (openapi): a fresh single-use download path for a READY export. */
export interface DataExportLinkDto {
  /** `/api/v1/me/data-exports/{id}/file?token=…` — works once, with the owner's bearer token. */
  path: string;
  expiresAt: string;
}

export interface DataExportListDto {
  items: DataExportDto[];
  /** When the next export may be asked for (null: now). */
  nextAllowedAt: string | null;
}

/** A job is retried this many times before FAILED. */
const MAX_ATTEMPTS = 3;
/** A RUNNING job older than this (a restart mid-build) is picked up again by the sweeper. */
const STALE_RUNNING_MS = 15 * 60_000;
/** The largest ZIP the download serves (the export holds JSON and two KYC pictures: far smaller). */
const MAX_ZIP_BYTES = 512 * 1024 * 1024;

/**
 * v1.66-social (D198, CONVENTIONS §10.61.1): «تنزيل بياناتي». `POST /me/data-exports` (password again; one per 24 h;
 * audited) creates a PENDING job that is built after the response (and by the sweeper after a restart); the ZIP is
 * stored under `private/data-exports/`; a single-use token (only its SHA-256 kept) lets the owner download it once,
 * within DATA_EXPORT_LINK_DAYS, with their bearer token. A notification and a mail say it is ready.
 */
@Injectable()
export class DataExportsService {
  private readonly logger = new Logger(DataExportsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly passwords: PasswordHasher,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    private readonly background: BackgroundTasks,
    private readonly notifier: Notifier,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
    @Inject(MAIL_SENDER) private readonly mail: MailSender,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly storageSettings: StorageSettingsStore,
  ) {}

  /** `GET /me/data-exports`. */
  async list(userId: string): Promise<DataExportListDto> {
    const rows = await this.prisma.dataExport.findMany({
      where: { userId },
      orderBy: { requestedAt: 'desc' },
      take: 10,
    });
    const next = await nextExportAllowedAt(this.prisma, userId, this.config.dataExport.minIntervalHours);
    const now = this.clock.now();
    return {
      items: rows.map((r) => this.toDto(r, now)),
      nextAllowedAt: next && next > now ? next.toISOString() : null,
    };
  }

  /**
   * `POST /me/data-exports`. Order: 400 → 403 REAUTH_FAILED (audited) → 429 DATA_EXPORT_LIMIT (+ Retry-After;
   * audited) → 202 with the PENDING job (the build runs after the response).
   */
  async request(userId: string, input: DataExportRequestInput, meta: RequestMeta): Promise<DataExportDto> {
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { passwordHash: true } });
    if (!user) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    if (!(await this.passwords.verify(user.passwordHash, input.password))) {
      await this.audit.record({
        action: AuditAction.DATA_EXPORT_REAUTH_FAILED,
        actorUserId: userId,
        targetType: 'user',
        targetId: userId,
        ip: meta.ip,
        requestId: meta.requestId,
      });
      throw new AppException(ErrorCode.REAUTH_FAILED);
    }
    const created = await this.create(userId, 'APP', {
      actorUserId: userId,
      ip: meta.ip,
      requestId: meta.requestId,
    });
    this.background.run('privacy.export.build', () => this.build(created.id).then(() => undefined));
    return this.toDto(created, this.clock.now());
  }

  /**
   * Creates a PENDING job unless the 24-hour limit forbids it (429, audited). Serialized per user with an advisory
   * lock, so two parallel requests never make two jobs. Shared with `privacy-admin export` (via ADMIN).
   */
  async create(
    userId: string,
    via: 'APP' | 'ADMIN',
    actor: { actorUserId: string | null; ip: string | null; requestId?: string; reason?: string },
  ): Promise<DataExport> {
    const now = this.clock.now();
    const outcome = await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('data_export'), hashtext(${userId}))`;
      const next = await nextExportAllowedAt(tx, userId, this.config.dataExport.minIntervalHours);
      if (next && next > now) return { limited: next, row: null } as const;
      const row = await tx.dataExport.create({ data: { userId, requestedVia: via, requestedAt: now } });
      await this.audit.recordIn(tx, {
        action: AuditAction.DATA_EXPORT_REQUESTED,
        actorUserId: actor.actorUserId,
        targetType: 'data_export',
        targetId: row.id,
        metadata: {
          userId,
          via: via === 'APP' ? 'app' : 'cli',
          ...(actor.reason ? { reason: actor.reason } : {}),
        },
        ip: actor.ip,
        ...(actor.requestId ? { requestId: actor.requestId } : {}),
      });
      return { limited: null, row } as const;
    });
    if (outcome.limited) {
      await this.audit.record({
        action: AuditAction.DATA_EXPORT_LIMITED,
        actorUserId: actor.actorUserId,
        targetType: 'user',
        targetId: userId,
        metadata: { nextAllowedAt: outcome.limited.toISOString() },
        ip: actor.ip,
        ...(actor.requestId ? { requestId: actor.requestId } : {}),
      });
      const seconds = Math.max(1, Math.ceil((outcome.limited.getTime() - now.getTime()) / 1000));
      throw new AppException(
        ErrorCode.DATA_EXPORT_LIMIT,
        undefined,
        [{ field: 'nextAllowedAt', issue: outcome.limited.toISOString() }],
        { 'Retry-After': String(seconds) },
      );
    }
    return outcome.row;
  }

  /**
   * Builds one job (PENDING, or RUNNING left behind): the ZIP is stored, a new single-use token minted, the row READY,
   * then the notification (same transaction) and the mail (after). Returns the token (tests and the CLI), or null when
   * the job was not buildable (taken by another worker, or failed — retried until {@link MAX_ATTEMPTS}).
   */
  async build(exportId: string): Promise<{ token: string } | null> {
    const now = this.clock.now();
    const claimed = await this.prisma.dataExport.updateMany({
      where: {
        id: exportId,
        OR: [
          { status: 'PENDING' },
          { status: 'RUNNING', startedAt: { lt: new Date(now.getTime() - STALE_RUNNING_MS) } },
        ],
      },
      data: { status: 'RUNNING', startedAt: now, attempts: { increment: 1 } },
    });
    if (claimed.count !== 1) return null;
    const job = await this.prisma.dataExport.findUniqueOrThrow({ where: { id: exportId } });
    try {
      const result = await buildDataExport(this.prisma, {
        userId: job.userId,
        now,
        mediaBaseUrl: this.storageSettings.current().publicBaseUrl ?? '',
        supportEmail: this.config.accountDeletion.supportEmail,
        storage: this.storage,
      });
      const key = exportObjectKey(job.userId, job.id);
      await this.storage.put(key, result.zip, 'application/zip', 'private, no-store');
      const token = randomBytes(32).toString('base64url');
      const readyAt = this.clock.now();
      const expiresAt = new Date(readyAt.getTime() + this.config.dataExport.linkDays * 86_400_000);
      const user = await this.prisma.$transaction(async (tx) => {
        const done = await tx.dataExport.updateMany({
          where: { id: job.id, status: 'RUNNING' },
          data: {
            status: 'READY',
            readyAt,
            expiresAt,
            objectKey: key,
            sizeBytes: result.zip.length,
            sha256: result.sha256,
            tokenHash: tokenHash(token),
            error: null,
          },
        });
        if (done.count !== 1) return null;
        await this.audit.recordIn(tx, {
          action: AuditAction.DATA_EXPORT_READY,
          actorUserId: null,
          targetType: 'data_export',
          targetId: job.id,
          metadata: {
            userId: job.userId,
            bytes: result.zip.length,
            sections: result.counts,
            files: result.files,
          },
        });
        await this.notifier.system(tx, { type: 'DATA_EXPORT_READY', recipientId: job.userId });
        return tx.user.findUnique({
          where: { id: job.userId },
          select: { email: true, status: true, profile: { select: { locale: true } } },
        });
      });
      if (!user) {
        await this.storage.delete([key]).catch(() => undefined);
        return null;
      }
      if (user.status === 'ACTIVE') {
        const locale = user.profile?.locale === 'en' ? 'en' : 'ar';
        this.background.run('privacy.export.mail', async () => {
          try {
            await this.mail.sendDataExportReady({
              to: user.email,
              locale,
              expiresAt,
              supportEmail: this.config.accountDeletion.supportEmail,
            });
          } catch (err) {
            this.logger.error({ error: safeErrorLog(err) }, 'Data-export notice not delivered');
          }
        });
      }
      return { token };
    } catch (err) {
      const failed = job.attempts + 1 >= MAX_ATTEMPTS;
      this.logger.error({ error: safeErrorLog(err), exportId: job.id, failed }, 'Data export not built');
      await this.prisma.dataExport.updateMany({
        where: { id: job.id, status: 'RUNNING' },
        data: {
          status: failed ? 'FAILED' : 'PENDING',
          error: String((err as Error)?.name ?? 'Error').slice(0, 200),
        },
      });
      if (failed) {
        await this.audit.record({
          action: AuditAction.DATA_EXPORT_FAILED,
          actorUserId: null,
          targetType: 'data_export',
          targetId: job.id,
          metadata: { userId: job.userId, attempts: job.attempts + 1 },
        });
      }
      return null;
    }
  }

  /**
   * `POST /me/data-exports/{id}/link`: a new single-use token for a READY export of the caller (the previous one stops
   * working). The link ends with the export (DATA_EXPORT_LINK_DAYS after it was ready). 410 otherwise.
   */
  async link(userId: string, exportId: string, meta: RequestMeta): Promise<DataExportLinkDto> {
    const now = this.clock.now();
    const token = randomBytes(32).toString('base64url');
    const row = await this.prisma.dataExport.findFirst({
      where: { id: exportId, userId, status: 'READY', expiresAt: { gt: now } },
      select: { expiresAt: true },
    });
    const done = row
      ? await this.prisma.dataExport.updateMany({
          where: { id: exportId, userId, status: 'READY', expiresAt: { gt: now } },
          data: { tokenHash: tokenHash(token) },
        })
      : { count: 0 };
    if (!row?.expiresAt || done.count !== 1) {
      await this.audit.record({
        action: AuditAction.DATA_EXPORT_DOWNLOAD_REFUSED,
        actorUserId: userId,
        targetType: 'data_export',
        targetId: exportId,
        metadata: { reason: 'link_not_available' },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      throw new AppException(ErrorCode.DATA_EXPORT_LINK_INVALID);
    }
    return {
      path: `/api/v1/me/data-exports/${exportId}/file?token=${token}`,
      expiresAt: row.expiresAt.toISOString(),
    };
  }

  /**
   * `GET /me/data-exports/{id}/file?token=`: the ZIP, once. The token is consumed atomically before the bytes are
   * read (a second request, even a racing one, gets 410). Wrong owner, wrong token, used or expired → 410
   * DATA_EXPORT_LINK_INVALID (audited).
   */
  async download(
    userId: string,
    exportId: string,
    token: string,
    meta: RequestMeta,
  ): Promise<{ bytes: Buffer; name: string }> {
    const now = this.clock.now();
    const refuse = async (reason: string): Promise<never> => {
      await this.audit.record({
        action: AuditAction.DATA_EXPORT_DOWNLOAD_REFUSED,
        actorUserId: userId,
        targetType: 'data_export',
        targetId: exportId,
        metadata: { reason },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      throw new AppException(ErrorCode.DATA_EXPORT_LINK_INVALID);
    };
    const used = await this.prisma.dataExport.updateMany({
      where: { id: exportId, userId, status: 'READY', tokenHash: tokenHash(token), expiresAt: { gt: now } },
      data: { status: 'DOWNLOADED', downloadedAt: now, tokenHash: null },
    });
    if (used.count !== 1) {
      const row = await this.prisma.dataExport.findFirst({
        where: { id: exportId, userId },
        select: { status: true, expiresAt: true },
      });
      return refuse(
        !row
          ? 'unknown'
          : row.status === 'DOWNLOADED'
            ? 'already_used'
            : row.status === 'READY' && row.expiresAt && row.expiresAt <= now
              ? 'expired'
              : row.status === 'READY'
                ? 'wrong_token'
                : `status_${row.status.toLowerCase()}`,
      );
    }
    const row = await this.prisma.dataExport.findUniqueOrThrow({ where: { id: exportId } });
    const bytes = row.objectKey ? await this.storage.get(row.objectKey, MAX_ZIP_BYTES) : null;
    if (!bytes) {
      // The file is gone (storage failure): the job is spent; a new export may be asked for after the limit.
      this.logger.error({ exportId }, 'Data-export file missing at download');
      return refuse('file_missing');
    }
    await this.audit.record({
      action: AuditAction.DATA_EXPORT_DOWNLOADED,
      actorUserId: userId,
      targetType: 'data_export',
      targetId: exportId,
      metadata: { bytes: bytes.length },
      ip: meta.ip,
      requestId: meta.requestId,
    });
    return { bytes, name: `kabso-data-${now.toISOString().slice(0, 10)}.zip` };
  }

  /**
   * The sweeper's step (also the tests' entry, with a moved clock): builds waiting jobs, expires READY jobs whose link
   * ended (audited) and deletes the files of DOWNLOADED and EXPIRED jobs.
   */
  async sweep(
    now: Date = this.clock.now(),
  ): Promise<{ built: number; expired: number; filesDeleted: number }> {
    let built = 0;
    const waiting = await this.prisma.dataExport.findMany({
      where: {
        OR: [
          { status: 'PENDING' },
          { status: 'RUNNING', startedAt: { lt: new Date(now.getTime() - STALE_RUNNING_MS) } },
        ],
      },
      orderBy: { requestedAt: 'asc' },
      select: { id: true },
      take: 20,
    });
    for (const w of waiting) if (await this.build(w.id)) built++;

    const due = await this.prisma.dataExport.findMany({
      where: { status: 'READY', expiresAt: { lte: now } },
      select: { id: true, userId: true },
      take: 500,
    });
    let expired = 0;
    for (const d of due) {
      const r = await this.prisma.dataExport.updateMany({
        where: { id: d.id, status: 'READY', expiresAt: { lte: now } },
        data: { status: 'EXPIRED', tokenHash: null },
      });
      if (r.count === 1) {
        expired++;
        await this.audit.record({
          action: AuditAction.DATA_EXPORT_EXPIRED,
          actorUserId: null,
          targetType: 'data_export',
          targetId: d.id,
          metadata: { userId: d.userId },
        });
      }
    }
    const spent = await this.prisma.dataExport.findMany({
      where: { status: { in: ['DOWNLOADED', 'EXPIRED', 'FAILED'] }, objectKey: { not: null } },
      select: { id: true, objectKey: true },
      take: 500,
    });
    let filesDeleted = 0;
    if (spent.length > 0) {
      try {
        await this.storage.delete(spent.map((s) => s.objectKey as string));
        const r = await this.prisma.dataExport.updateMany({
          where: { id: { in: spent.map((s) => s.id) } },
          data: { objectKey: null },
        });
        filesDeleted = r.count;
      } catch (err) {
        this.logger.warn({ error: safeErrorLog(err), count: spent.length }, 'Data-export files not deleted');
      }
    }
    return { built, expired, filesDeleted };
  }

  private toDto(r: DataExport, now: Date): DataExportDto {
    const ready = r.status === 'READY' && r.expiresAt !== null && r.expiresAt > now;
    const status: DataExportDto['status'] =
      r.status === 'RUNNING' ? 'PENDING' : r.status === 'READY' && !ready ? 'EXPIRED' : r.status;
    return {
      id: r.id,
      status,
      requestedAt: r.requestedAt.toISOString(),
      readyAt: r.readyAt?.toISOString() ?? null,
      expiresAt: ready ? (r.expiresAt?.toISOString() ?? null) : null,
      downloadedAt: r.downloadedAt?.toISOString() ?? null,
      sizeBytes: r.sizeBytes,
    };
  }
}

/** Builds waiting jobs and cleans up every DATA_EXPORT_SWEEP_INTERVAL_SECONDS (0: off — tests). */
@Injectable()
export class DataExportSweeper implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DataExportSweeper.name);
  private timer: NodeJS.Timeout | null = null;
  private inFlight: Promise<unknown> | null = null;

  constructor(
    private readonly exports: DataExportsService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  onModuleInit(): void {
    if (this.config.dataExport.sweepIntervalSeconds > 0) this.schedule();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    await this.inFlight?.catch(() => undefined);
  }

  private schedule(): void {
    this.timer = setTimeout(() => {
      this.inFlight = this.exports
        .sweep()
        .then((r) => {
          if (r.built + r.expired + r.filesDeleted > 0) this.logger.log(r, 'Data exports swept');
        })
        .catch((err: unknown) => this.logger.error({ error: safeErrorLog(err) }, 'Data-export sweep failed'))
        .finally(() => {
          this.inFlight = null;
          this.schedule();
        });
    }, this.config.dataExport.sweepIntervalSeconds * 1000);
    this.timer.unref();
  }
}
