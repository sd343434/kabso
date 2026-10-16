import { performance } from 'node:perf_hooks';
import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import {
  COMPLETE_GRACE_MS,
  FAILED_ROW_RETENTION_MS,
  TERMINAL_ROW_RETENTION_MS,
  type DbMediaPurpose,
} from './media.constants.js';
import { MEDIA_STORAGE, type MediaStorage } from './media-storage.js';
import { PUBLIC_TOKEN_PATTERN, publicKeys } from './media-urls.js';

/** Per-run budget (as the live sweeper, SEC-035): whichever is reached first ends the run. */
export const CLEANUP_MAX_BATCHES_PER_RUN = 200;
export const CLEANUP_RUN_BUDGET_MS = 60_000;

const CLEANUP_TX_OPTIONS = { maxWait: 5_000, timeout: 10_000 } as const;
const CLEANUP_STATEMENT_TIMEOUT_MS = 8_000;

export type CleanupPass =
  | 'expire_awaiting'
  | 'retire_unattached'
  | 'retire_detached'
  | 'retire_rejected'
  | 'retire_deleted_accounts'
  | 'detach_ended_room_covers'
  | 'delete_storage'
  | 'purge_rows';

export type CleanupStop = 'drained' | 'batch_budget' | 'time_budget' | 'already_running' | 'stopped';

export interface CleanupResult {
  /** Rows changed per pass in this run. */
  readonly counts: Readonly<Partial<Record<CleanupPass, number>>>;
  readonly batches: number;
  readonly stoppedBy: CleanupStop;
}

export interface CleanupOptions {
  readonly maxBatches?: number;
  readonly budgetMs?: number;
}

interface StorageRow {
  id: string;
  purpose: DbMediaPurpose;
  public_token: string | null;
  incoming_key: string;
}

/**
 * Media cleanup job (CONVENTIONS §11.6, DB_PHASE2_MEDIA §4), following the KL-045 sweeper
 * pattern: every MEDIA_CLEANUP_INTERVAL_SECONDS, bounded batches of MEDIA_CLEANUP_BATCH_SIZE
 * rows, each claimed in its own short transaction with `FOR UPDATE SKIP LOCKED` (several pods may
 * run it at once), runs never overlap within a process, and a run stops at its batch / time
 * budget. Storage requests never run inside a database transaction.
 *
 * Passes, in order:
 *  1. AWAITING_UPLOAD past `expiresAt` + 5 min → EXPIRED (incoming object deleted, best effort:
 *     the bucket's 1-day lifecycle rule is the backstop).
 *  2. READY → DELETED (storage pending) when: never attached after MEDIA_UNATTACHED_TTL_HOURS;
 *     detached for MEDIA_DELETE_GRACE_HOURS; REJECTED (at once); or the owner's account is
 *     soft-deleted (also its AWAITING uploads → EXPIRED).
 *  3. Covers of rooms ENDED for MEDIA_ENDED_ROOM_COVER_TTL_HOURS are detached (then pass 2 after
 *     the grace period).
 *  4. DELETED rows whose objects are still stored: delete the objects, then stamp `deleted_at`.
 *     A failed storage delete leaves the row as it was; the next run retries it. A row is never
 *     marked deleted before its objects are gone, so no object loses its only reference. The CDN
 *     purge request (§11.6) is not implemented: no CDN provider is chosen yet; the 1-day
 *     `Cache-Control` bounds stale copies.
 *  5. FAILED rows after 7 days, EXPIRED and fully DELETED rows after 30 days are removed.
 *
 * Moving a READY row to DELETED happens under the row lock, so a concurrent attach (which needs
 * `status = 'READY'`) either commits first (the row no longer qualifies) or fails with 400.
 */
@Injectable()
export class MediaCleanupService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(MediaCleanupService.name);
  private timer: NodeJS.Timeout | undefined;
  private inFlight: Promise<CleanupResult> | null = null;
  private stopped = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(MEDIA_STORAGE) private readonly storage: MediaStorage | null,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  onModuleInit(): void {
    if (this.config.media.cleanupIntervalSeconds > 0) this.schedule();
  }

  async onModuleDestroy(): Promise<void> {
    this.stopped = true;
    if (this.timer) clearTimeout(this.timer);
    await this.inFlight?.catch(() => undefined);
  }

  private schedule(): void {
    if (this.stopped) return;
    this.timer = setTimeout(() => {
      void this.runCleanup()
        .then((result) => {
          if (result.stoppedBy === 'batch_budget' || result.stoppedBy === 'time_budget') {
            this.logger.warn({ ...result }, 'Media cleanup stopped at its per-run budget');
          }
        })
        .catch((err: unknown) => this.logger.error({ error: safeErrorLog(err) }, 'Media cleanup failed'))
        .finally(() => this.schedule());
    }, this.config.media.cleanupIntervalSeconds * 1000);
    this.timer.unref();
  }

  /** One run; a call while a run is in progress in this instance does nothing. */
  async runCleanup(options: CleanupOptions = {}): Promise<CleanupResult> {
    if (this.inFlight) return { counts: {}, batches: 0, stoppedBy: 'already_running' };
    const run = this.loop(options);
    this.inFlight = run;
    try {
      return await run;
    } finally {
      this.inFlight = null;
    }
  }

  private async loop(options: CleanupOptions): Promise<CleanupResult> {
    const maxBatches = options.maxBatches ?? CLEANUP_MAX_BATCHES_PER_RUN;
    const budgetMs = options.budgetMs ?? CLEANUP_RUN_BUDGET_MS;
    const started = performance.now();
    const counts: Partial<Record<CleanupPass, number>> = {};
    let batches = 0;
    const passes: [
      CleanupPass,
      (now: Date, size: number) => Promise<{ claimed: number; changed: number }>,
    ][] = [
      ['expire_awaiting', (now, size) => this.expireAwaiting(now, size)],
      ['retire_unattached', (now, size) => this.retire('unattached', now, size)],
      ['retire_detached', (now, size) => this.retire('detached', now, size)],
      ['retire_rejected', (now, size) => this.retire('rejected', now, size)],
      ['retire_deleted_accounts', (now, size) => this.retireDeletedAccounts(now, size)],
      ['detach_ended_room_covers', (now, size) => this.detachEndedRoomCovers(now, size)],
      ['delete_storage', (now, size) => this.deleteStorage(now, size)],
      ['purge_rows', (now, size) => this.purgeRows(now, size)],
    ];
    const size = this.config.media.cleanupBatchSize;
    for (const [name, pass] of passes) {
      for (;;) {
        if (this.stopped) return { counts, batches, stoppedBy: 'stopped' };
        if (batches >= maxBatches) return { counts, batches, stoppedBy: 'batch_budget' };
        if (performance.now() - started >= budgetMs) return { counts, batches, stoppedBy: 'time_budget' };
        const { claimed, changed } = await pass(this.clock.now(), size);
        batches += 1;
        counts[name] = (counts[name] ?? 0) + changed;
        // Drained, or no progress (e.g. storage failing): move on; the next run retries.
        if (claimed < size || changed === 0) break;
      }
    }
    return { counts, batches, stoppedBy: 'drained' };
  }

  private async tx<T>(fn: (tx: Prisma.TransactionClient) => Promise<T>): Promise<T> {
    return this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT set_config('statement_timeout', ${String(CLEANUP_STATEMENT_TIMEOUT_MS)}, true)`;
      return fn(tx);
    }, CLEANUP_TX_OPTIONS);
  }

  private hours(h: number): number {
    return h * 3600 * 1000;
  }

  /** Pass 1. */
  private async expireAwaiting(now: Date, size: number): Promise<{ claimed: number; changed: number }> {
    const cutoff = new Date(now.getTime() - COMPLETE_GRACE_MS).toISOString();
    const rows = await this.tx(async (tx) => {
      const locked = await tx.$queryRaw<{ id: string }[]>`
        SELECT id::text AS id FROM media_objects
         WHERE status = 'AWAITING_UPLOAD' AND upload_expires_at < ${cutoff}::timestamptz
         ORDER BY upload_expires_at LIMIT ${size} FOR UPDATE SKIP LOCKED`;
      if (locked.length === 0) return [];
      return tx.$queryRaw<StorageRow[]>`
        UPDATE media_objects SET status = 'EXPIRED', updated_at = ${now.toISOString()}::timestamptz
         WHERE id = ANY(${locked.map((r) => r.id)}::uuid[]) AND status = 'AWAITING_UPLOAD'
     RETURNING id::text AS id, purpose::text AS purpose, public_token, incoming_key`;
    });
    await this.deleteIncomingBestEffort(rows);
    return { claimed: rows.length, changed: rows.length };
  }

  private async deleteIncomingBestEffort(rows: readonly StorageRow[]): Promise<void> {
    if (this.storage === null) return;
    for (const row of rows) {
      try {
        await this.storage.deleteIncoming(row.incoming_key);
      } catch (err) {
        this.logger.warn(
          { error: safeErrorLog(err) },
          'Deleting an incoming object failed (lifecycle rule backstop)',
        );
      }
    }
  }

  /** Pass 2 (one READY category per call): READY → DELETED, storage deletion pending. */
  private async retire(
    category: 'unattached' | 'detached' | 'rejected',
    now: Date,
    size: number,
  ): Promise<{ claimed: number; changed: number }> {
    const unattachedCutoff = new Date(
      now.getTime() - this.hours(this.config.media.unattachedTtlHours),
    ).toISOString();
    const graceCutoff = new Date(
      now.getTime() - this.hours(this.config.media.deleteGraceHours),
    ).toISOString();
    const select =
      category === 'unattached'
        ? Prisma.sql`SELECT id::text AS id FROM media_objects
            WHERE status = 'READY' AND attached_at IS NULL AND completed_at < ${unattachedCutoff}::timestamptz
            ORDER BY completed_at LIMIT ${size} FOR UPDATE SKIP LOCKED`
        : category === 'detached'
          ? Prisma.sql`SELECT id::text AS id FROM media_objects
              WHERE status = 'READY' AND detached_at IS NOT NULL AND detached_at < ${graceCutoff}::timestamptz
              ORDER BY detached_at LIMIT ${size} FOR UPDATE SKIP LOCKED`
          : Prisma.sql`SELECT id::text AS id FROM media_objects
              WHERE status = 'READY' AND moderation_status = 'REJECTED'
              ORDER BY moderated_at LIMIT ${size} FOR UPDATE SKIP LOCKED`;
    const changed = await this.tx(async (tx) => {
      const locked = await tx.$queryRaw<{ id: string }[]>(select);
      if (locked.length === 0) return 0;
      // An image that is still referenced (only possible for "unattached" rows that were attached
      // meanwhile, which the lock excludes) is never retired: the guard re-checks it.
      return tx.$executeRaw`
        UPDATE media_objects SET status = 'DELETED', updated_at = ${now.toISOString()}::timestamptz
         WHERE id = ANY(${locked.map((r) => r.id)}::uuid[]) AND status = 'READY'
           AND NOT EXISTS (SELECT 1 FROM user_profiles p WHERE p.avatar_media_id = media_objects.id)
           AND NOT EXISTS (SELECT 1 FROM live_rooms r WHERE r.cover_media_id = media_objects.id)`;
    });
    return { claimed: changed, changed };
  }

  /** Pass 2 for accounts that are soft-deleted (status DELETED): all their media. */
  private async retireDeletedAccounts(
    now: Date,
    size: number,
  ): Promise<{ claimed: number; changed: number }> {
    const changed = await this.tx(async (tx) => {
      const locked = await tx.$queryRaw<{ id: string; status: string }[]>`
        SELECT m.id::text AS id, m.status::text AS status FROM media_objects m
          JOIN users u ON u.id = m.owner_user_id
         WHERE u.status = 'DELETED' AND m.status IN ('AWAITING_UPLOAD', 'READY')
         ORDER BY m.created_at LIMIT ${size} FOR UPDATE OF m SKIP LOCKED`;
      if (locked.length === 0) return 0;
      const ids = locked.map((r) => r.id);
      const at = now.toISOString();
      // Detach first (purgeUserIn normally did already), then retire.
      await tx.$executeRaw`UPDATE user_profiles SET avatar_media_id = NULL, updated_at = ${at}::timestamptz WHERE avatar_media_id = ANY(${ids}::uuid[])`;
      await tx.$executeRaw`UPDATE live_rooms SET cover_media_id = NULL, updated_at = ${at}::timestamptz WHERE cover_media_id = ANY(${ids}::uuid[])`;
      const expired = await tx.$executeRaw`
        UPDATE media_objects SET status = 'EXPIRED', updated_at = ${at}::timestamptz
         WHERE id = ANY(${ids}::uuid[]) AND status = 'AWAITING_UPLOAD'`;
      const retired = await tx.$executeRaw`
        UPDATE media_objects SET status = 'DELETED', updated_at = ${at}::timestamptz,
               detached_at = CASE WHEN attached_at IS NOT NULL THEN COALESCE(detached_at, ${at}::timestamptz) END
         WHERE id = ANY(${ids}::uuid[]) AND status = 'READY'`;
      return expired + retired;
    });
    return { claimed: changed, changed };
  }

  /** Pass 3: covers of rooms ended long enough ago are detached (grace period follows). */
  private async detachEndedRoomCovers(
    now: Date,
    size: number,
  ): Promise<{ claimed: number; changed: number }> {
    const cutoff = new Date(
      now.getTime() - this.hours(this.config.media.endedRoomCoverTtlHours),
    ).toISOString();
    const changed = await this.tx(async (tx) => {
      const rooms = await tx.$queryRaw<{ id: string; cover_media_id: string }[]>`
        SELECT id::text AS id, cover_media_id::text AS cover_media_id FROM live_rooms
         WHERE cover_media_id IS NOT NULL AND status = 'ENDED' AND ended_at < ${cutoff}::timestamptz
         LIMIT ${size} FOR UPDATE SKIP LOCKED`;
      if (rooms.length === 0) return 0;
      const at = now.toISOString();
      await tx.$executeRaw`
        UPDATE live_rooms SET cover_media_id = NULL, updated_at = ${at}::timestamptz
         WHERE id = ANY(${rooms.map((r) => r.id)}::uuid[]) AND status = 'ENDED'`;
      await tx.$executeRaw`
        UPDATE media_objects SET detached_at = ${at}::timestamptz, updated_at = ${at}::timestamptz
         WHERE id = ANY(${rooms.map((r) => r.cover_media_id)}::uuid[]) AND attached_at IS NOT NULL AND detached_at IS NULL`;
      return rooms.length;
    });
    return { claimed: changed, changed };
  }

  /** Pass 4: storage first, row second. */
  private async deleteStorage(now: Date, size: number): Promise<{ claimed: number; changed: number }> {
    if (this.storage === null) return { claimed: 0, changed: 0 }; // nothing can be deleted without storage
    const storage = this.storage;
    const rows = await this.prisma.$queryRaw<StorageRow[]>`
      SELECT id::text AS id, purpose::text AS purpose, public_token, incoming_key FROM media_objects
       WHERE status = 'DELETED' AND deleted_at IS NULL
       ORDER BY updated_at LIMIT ${size}`;
    const done: string[] = [];
    for (const row of rows) {
      try {
        if (row.public_token !== null && PUBLIC_TOKEN_PATTERN.test(row.public_token)) {
          const keys = publicKeys(row.purpose, row.public_token);
          await storage.deletePublic([keys.main, keys.thumb]);
        }
        await storage.deleteIncoming(row.incoming_key);
        done.push(row.id);
      } catch (err) {
        this.logger.warn({ error: safeErrorLog(err) }, 'Deleting media objects failed; retried next run');
      }
    }
    if (done.length > 0) {
      await this.prisma.$executeRaw`
        UPDATE media_objects SET deleted_at = ${now.toISOString()}::timestamptz, updated_at = ${now.toISOString()}::timestamptz
         WHERE id = ANY(${done}::uuid[]) AND status = 'DELETED' AND deleted_at IS NULL`;
    }
    return { claimed: rows.length, changed: done.length };
  }

  /** Pass 5: FAILED after 7 days; EXPIRED and fully DELETED after 30 days. */
  private async purgeRows(now: Date, size: number): Promise<{ claimed: number; changed: number }> {
    const failedCutoff = new Date(now.getTime() - FAILED_ROW_RETENTION_MS).toISOString();
    const terminalCutoff = new Date(now.getTime() - TERMINAL_ROW_RETENTION_MS).toISOString();
    const changed = await this.tx(async (tx) => {
      const locked = await tx.$queryRaw<{ id: string }[]>`
        SELECT id::text AS id FROM media_objects
         WHERE status IN ('FAILED', 'EXPIRED', 'DELETED')
           AND updated_at < ${failedCutoff}::timestamptz
           AND ((status = 'FAILED' AND created_at < ${failedCutoff}::timestamptz)
             OR (status = 'EXPIRED' AND updated_at < ${terminalCutoff}::timestamptz)
             OR (status = 'DELETED' AND deleted_at IS NOT NULL AND updated_at < ${terminalCutoff}::timestamptz))
         ORDER BY updated_at LIMIT ${size} FOR UPDATE SKIP LOCKED`;
      if (locked.length === 0) return 0;
      return tx.$executeRaw`DELETE FROM media_objects WHERE id = ANY(${locked.map((r) => r.id)}::uuid[])`;
    });
    return { claimed: changed, changed };
  }
}
