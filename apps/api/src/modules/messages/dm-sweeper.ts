import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { MediaService } from '../media/media.service.js';
import { DM_REPORT_SNAPSHOT_DAYS, dmSnapshotObjectKeys } from './dm-reports.js';

/** Rows handled per statement (bounded batches). */
const BATCH = 500;

export interface DmSweepResult {
  /** Messages hard-deleted (expired: sent more than DM_RETENTION_HOURS ago, or deleted for everyone). */
  readonly messages: number;
  /** Their pictures and voice clips deleted (objects and rows). */
  readonly media: number;
  /** Report snapshots cleared (resolved more than 30 days ago). */
  readonly snapshots: number;
}

/**
 * v1.40-social (D155, owner: «الرسائل بين الأشخاص تحذف بعد ٢٤ ساعة», CONVENTIONS §11.13): deletes
 * every direct message whose `expires_at` has passed — 24 hours after it was sent, or at once when
 * it was deleted for everyone or removed by moderation — with its picture or voice objects, in
 * bounded batches every `DM_SWEEP_INTERVAL_SECONDS` (it cannot be off in production). Files go
 * first: a storage failure throws, the rows stay and the next sweep retries (reads already hide
 * them). Also clears the snapshots of `DM_MESSAGE` reports resolved more than 30 days ago. v1.104-social (D339): group
 * messages (`dm_group_messages`) the same way, and `DM_GROUP` report snapshots.
 */
@Injectable()
export class DmSweeper implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger('DmSweeper');
  private timer: NodeJS.Timeout | undefined;
  private inFlight: Promise<void> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly media: MediaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  onModuleInit(): void {
    if (this.config.dm.sweepIntervalSeconds > 0) this.schedule();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    await this.inFlight?.catch(() => undefined);
  }

  private schedule(): void {
    this.timer = setTimeout(() => {
      this.inFlight = this.sweep()
        .then((r) => {
          if (r.messages + r.snapshots > 0) this.logger.log(r, 'Direct messages swept');
        })
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Direct message sweep failed');
        })
        .finally(() => {
          this.inFlight = null;
          this.schedule();
        });
    }, this.config.dm.sweepIntervalSeconds * 1000);
    this.timer.unref();
  }

  /** One pass: expired messages (and their files) until none is left, then old report snapshots. */
  async sweep(): Promise<DmSweepResult> {
    const now = this.clock.now();
    let messages = 0;
    let media = 0;
    for (;;) {
      const due = await this.prisma.$queryRaw<{ id: string; media_id: string | null }[]>`
        SELECT id::text AS id, media_id::text AS media_id FROM dm_messages
         WHERE expires_at <= ${now}::timestamptz
         ORDER BY expires_at
         LIMIT ${BATCH}`;
      if (due.length === 0) break;
      const mediaIds = due.map((d) => d.media_id).filter((id): id is string => id !== null);
      if (mediaIds.length > 0) {
        const assets = await this.prisma.mediaAsset.findMany({
          where: { id: { in: mediaIds } },
          select: { id: true, largeKey: true, thumbKey: true },
        });
        media += await this.media.purgeAssets(assets);
      }
      const deleted = await this.prisma.dmMessage.deleteMany({
        where: { id: { in: due.map((d) => d.id) }, expiresAt: { lte: now } },
      });
      messages += deleted.count;
      if (due.length < BATCH) break;
    }
    // v1.104-social (D339, §10.133): group messages live as long, and go the same way.
    for (;;) {
      const due = await this.prisma.$queryRaw<{ id: string; media_id: string | null }[]>`
        SELECT id::text AS id, media_id::text AS media_id FROM dm_group_messages
         WHERE expires_at <= ${now}::timestamptz
         ORDER BY expires_at
         LIMIT ${BATCH}`;
      if (due.length === 0) break;
      const mediaIds = due.map((d) => d.media_id).filter((id): id is string => id !== null);
      if (mediaIds.length > 0) {
        const assets = await this.prisma.mediaAsset.findMany({
          where: { id: { in: mediaIds } },
          select: { id: true, largeKey: true, thumbKey: true },
        });
        media += await this.media.purgeAssets(assets);
      }
      const deleted = await this.prisma.dmGroupMessage.deleteMany({
        where: { id: { in: due.map((d) => d.id) }, expiresAt: { lte: now } },
      });
      messages += deleted.count;
      if (due.length < BATCH) break;
    }
    const snapshots = await this.purgeSnapshots(now);
    return { messages, media, snapshots };
  }

  /**
   * Clears text, token and file of `DM_MESSAGE` report snapshots resolved more than 30 days ago. D193: not while the
   * report is under a legal hold (its sender's account was purged; the hold deletes it, with the file, after 90 days).
   */
  private async purgeSnapshots(now: Date): Promise<number> {
    const before = new Date(now.getTime() - DM_REPORT_SNAPSHOT_DAYS * 86_400_000);
    // v1.93-social (D296): a USER report made from a conversation keeps a thread too; the thread's files go with it.
    const rows = await this.prisma.$queryRaw<{ id: string; dm_snapshot: unknown }[]>`
      SELECT id::text AS id, dm_snapshot FROM reports
       WHERE target_type IN ('DM_MESSAGE'::report_target_type, 'USER'::report_target_type,
                             'DM_GROUP'::report_target_type)
         AND status <> 'OPEN'::report_status
         AND resolved_at < ${before}::timestamptz
         AND dm_snapshot IS NOT NULL AND COALESCE((dm_snapshot->>'purged')::boolean, false) = false
         AND legal_hold_id IS NULL
       LIMIT ${BATCH}`;
    if (rows.length === 0) return 0;
    await this.media.deleteObjects(rows.flatMap((r) => dmSnapshotObjectKeys(r.dm_snapshot)));
    await this.prisma.$executeRaw`
      UPDATE reports
         SET dm_snapshot = dm_snapshot
             || '{"purged": true, "text": null, "token": null, "mediaKey": null, "thread": null}'::jsonb
       WHERE id = ANY(${rows.map((r) => r.id)}::uuid[])`;
    // v1.104-social (D339): a group's snapshot also drops its members' names.
    await this.prisma.$executeRaw`
      UPDATE reports SET dm_snapshot = dm_snapshot || '{"members": []}'::jsonb
       WHERE id = ANY(${rows.map((r) => r.id)}::uuid[]) AND target_type = 'DM_GROUP'::report_target_type`;
    return rows.length;
  }
}
