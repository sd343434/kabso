import { performance } from 'node:perf_hooks';
import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { AuditAction, AuditService, type AuditEntry } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { UsersService, violatedUniqueIndex } from '../users/users.service.js';
import { LiveRankingsService } from './live-rankings.service.js';
import { LiveScheduleService } from './live-schedule.service.js';
import { LiveCategoriesService, localizedCategory, type LiveCategoryDto } from './live-categories.service.js';
import { cursorScope, LiveCursorCodec, type CursorPosition, type LiveTab } from './live-cursor.js';
import { awardLiveMedalsForRoomsIn } from '../medals/medal-awards.js';
import { clearEndedRoomSeatsIn, releaseUserIn } from './live-seats.store.js';
import {
  DEFAULT_LIVE_THEME,
  isUuid,
  LIVE_SEAT_COUNTS,
  LIVE_THEMES,
  startLiveRoomSchema,
  type ListLiveRoomsQuery,
} from './live.schemas.js';

// ---- Response shapes (openapi v1.3) ------------------------------------------------------------

/** `UserSummary`: never contains an email. */

/**
 * What every path that ends rooms does in its transaction: guests leave their seats (CP-011) and,
 * v1.21-live (CP-018), the hosts get their live medals (FIRST_LIVE, live hours).
 */
async function roomsEndedIn(
  tx: Prisma.TransactionClient,
  roomIds: readonly string[],
  now: Date,
): Promise<void> {
  await clearEndedRoomSeatsIn(tx, roomIds, now);
  await awardLiveMedalsForRoomsIn(tx, roomIds, now);
}

export interface UserSummaryDto {
  id: string;
  username: string;
  displayName: string;
  avatarUrl: string | null;
}

export type LiveRoomMode = 'SOLO' | 'PK' | 'MULTI' | 'AUDIO';
export type LiveRoomEndReason = 'HOST_ENDED' | 'HEARTBEAT_TIMEOUT' | 'HOST_SUSPENDED' | 'ADMIN';

export interface LiveRoomSummaryDto {
  id: string;
  title: string;
  /** CP-014: the live's topic, or null. */
  topic: string | null;
  mode: LiveRoomMode;
  viewerCount: number;
  startedAt: string;
  coverUrl: string | null;
  category: LiveCategoryDto | null;
  host: UserSummaryDto;
  /** CP-011: tiles (host included) of a MULTI or AUDIO room; null for SOLO. */
  seatCount: number | null;
  /** CP-011: guests seated now. */
  occupiedSeats: number;
  /** CP-011: a slug of `LiveConfig.themes`. */
  theme: string;
  /** CP-012: the live's points (taps + support); `popular` orders by it. */
  score: number;
}

/** `LiveScore` (CP-012). */
export interface LiveScoreDto {
  total: number;
  tapPoints: number;
  supportPoints: number;
}

export interface LiveRoomDto extends LiveRoomSummaryDto {
  status: 'LIVE' | 'ENDED';
  endedAt: string | null;
  endReason: LiveRoomEndReason | null;
  /** CP-010: people without an account may watch. */
  allowGuests: boolean;
  /** CP-012: the score and its parts. */
  scoreParts: LiveScoreDto;
  /** CP-013: false when the host turned the chat off. */
  chatEnabled: boolean;
  /** CP-013: the caller is muted in this live's chat (false for guests). */
  chatMuted: boolean;
  /** v1.20-live (D105): the caller was kicked out of this live (false for guests). */
  kicked: boolean;
  /** CP-016 G: the host's public room number (null without the hosting permission). */
  roomNumber: number | null;
  /** CP-016 D (§10.18): the host's charm level. */
  roomLevel: number | null;
}

export interface LiveRoomPageDto {
  data: LiveRoomSummaryDto[];
  page: { nextCursor: string | null; hasMore: boolean };
}

export interface LiveConfigDto {
  hostingEnabled: boolean;
  heartbeatIntervalSeconds: number;
  heartbeatStaleAfterSeconds: number;
  /** CP-011: accepted room themes, in display order (the first is the default). */
  themes: string[];
  /** CP-011: allowed seat counts per mode (host tile included). */
  seatCounts: { MULTI: number[]; AUDIO: number[] };
}

/**
 * CP-014 (§10.12): what the host's `PATCH` asks to change. A field left out is unchanged;
 * `category: null` and `topic: null` remove them. The category has been checked to be active.
 */
export interface RoomInfoEdit {
  readonly title?: string;
  readonly category?: { readonly id: string; readonly slug: string } | null;
  readonly topic?: string | null;
}

/** Request facts recorded in the audit trail. */
export interface RequestMeta {
  readonly ip: string | null;
  readonly requestId: string | null;
}

// ---- Persistence -------------------------------------------------------------------------------

export interface RoomRow {
  id: string;
  title: string;
  /** CP-014: the live's topic (null = none). */
  topic: string | null;
  mode: LiveRoomMode;
  status: 'LIVE' | 'ENDED';
  viewer_count: number;
  started_at: Date;
  last_heartbeat_at: Date;
  ended_at: Date | null;
  end_reason: LiveRoomEndReason | null;
  cover_url: string | null;
  allow_guests: boolean;
  seat_count: number | null;
  theme: string;
  seats_version: number;
  /** CP-012: `live_rooms.score` and its parts (`live_room_scores`; 0 without a row). */
  score: bigint;
  tap_points: bigint;
  support_points: bigint;
  occupied_seats: number;
  /** CP-013: the host's chat switch. */
  chat_enabled: boolean;
  /** CP-013: the reader is muted in this live's chat (room detail only; false otherwise). */
  chat_muted?: boolean;
  /** v1.20-live (D105): the reader was kicked out of this live (room detail only; false otherwise). */
  kicked?: boolean;
  host_user_id: string;
  host_status: string;
  username: string;
  display_name: string;
  avatar_url: string | null;
  category_slug: string | null;
  category_name_ar: string | null;
  category_name_en: string | null;
  /** CP-016 G: the host's room number (null without the hosting permission). */
  room_number: number | null;
  room_level: number | null;
}

/**
 * Room + host identity + category in one statement. Reading `users` / `user_profiles` here (for the
 * ACTIVE-host filter and the host summary) and `follows` (Following tab) are the documented
 * read-only exceptions to module table ownership (DB_PHASE2_DISCOVERY §1): the list must filter
 * and paginate in the database.
 */
/**
 * CP-016 D (§10.18): the host's charm (ATTRACTIVENESS) level, null while the category is
 * unavailable. The same rule as the levels read side (`summaryDto`): the highest level of the
 * published ladder the points reach, or the level kept from that same version if higher.
 */
const ROOM_LEVEL_SQL = Prisma.sql`(
         SELECT CASE WHEN lc.is_enabled AND lc.published_version_id IS NOT NULL THEN
                  GREATEST(
                    (SELECT max(ld.level_number) FROM level_definitions ld
                      WHERE ld.version_id = lc.published_version_id
                        AND ld.required_points <= COALESCE(ls.total_points, 0)),
                    CASE WHEN ls.version_id = lc.published_version_id THEN ls.current_level END)
                END
           FROM level_categories lc
           LEFT JOIN user_level_states ls ON ls.category_id = lc.id AND ls.user_id = r.host_user_id
          WHERE lc.code = 'ATTRACTIVENESS')`;

const ROOM_COLUMNS = Prisma.sql`
         r.id::text AS id, r.title, r.topic, r.mode::text AS mode, r.status::text AS status, r.viewer_count,
         r.started_at, r.last_heartbeat_at, r.ended_at, r.end_reason::text AS end_reason, r.cover_url,
         r.allow_guests, r.seat_count::int AS seat_count, r.theme, r.seats_version, r.score,
         COALESCE(sc.tap_points, 0)::bigint AS tap_points,
         COALESCE(sc.support_points, 0)::bigint AS support_points,
         (SELECT count(*)::int FROM live_room_seats s
           WHERE s.room_id = r.id AND s.user_id IS NOT NULL) AS occupied_seats,
         r.host_user_id::text AS host_user_id, u.status::text AS host_status, p.username,
         p.display_name, p.avatar_url, c.slug AS category_slug, c.name_ar AS category_name_ar,
         c.name_en AS category_name_en, r.chat_enabled, lh.room_number, ${ROOM_LEVEL_SQL} AS room_level`;

const ROOM_FROM = Prisma.sql`
    FROM live_rooms r
    JOIN users u ON u.id = r.host_user_id
    JOIN user_profiles p ON p.user_id = r.host_user_id
    LEFT JOIN live_categories c ON c.id = r.category_id
    LEFT JOIN live_room_scores sc ON sc.room_id = r.id
    LEFT JOIN live_hosts lh ON lh.user_id = r.host_user_id`;

const ROOM_SELECT = Prisma.sql`SELECT ${ROOM_COLUMNS} ${ROOM_FROM}`;

/** CP-013: whether `viewerId` is muted in the room's chat (a guest never is). */
function chatMutedSql(viewerId: string | null): Prisma.Sql {
  if (viewerId === null) return Prisma.sql`FALSE`;
  return Prisma.sql`EXISTS (SELECT 1 FROM live_chat_mutes m
                    WHERE m.room_id = r.id AND m.user_id = ${viewerId}::uuid)`;
}

/** v1.20-live (D105): the reader was kicked out of the room (false for a guest). */
function kickedSql(viewerId: string | null): Prisma.Sql {
  if (viewerId === null) return Prisma.sql`FALSE`;
  return Prisma.sql`EXISTS (SELECT 1 FROM live_room_kicks k
                    WHERE k.room_id = r.id AND k.user_id = ${viewerId}::uuid)`;
}

/** CP-013 (owner D96): chat messages and mutes are kept 30 days after their room ended. */
export const LIVE_CHAT_RETENTION_MS = 30 * 24 * 3600_000;
const CHAT_RETENTION_BATCH = 1_000;
const CHAT_RETENTION_MAX_BATCHES = 20;

const ONE_LIVE_PER_HOST_INDEX = 'live_rooms_one_live_per_host';

/**
 * Explicit interactive-transaction limits for every live-room transaction (SEC-035): Prisma's
 * default 5 s timeout is never relied on, and a slow statement is cancelled by the server
 * (`statement_timeout`) before the client-side timeout rolls the transaction back.
 */
export const LIVE_TX_OPTIONS = { maxWait: 5_000, timeout: 10_000 } as const;
const LIVE_STATEMENT_TIMEOUT_MS = 8_000;

/** Sets the live statement timeout (SEC-035) for the rest of the transaction `tx`. */
export async function setLiveStatementTimeout(tx: Prisma.TransactionClient): Promise<void> {
  await tx.$queryRaw`SELECT set_config('statement_timeout', ${String(LIVE_STATEMENT_TIMEOUT_MS)}, true)`;
}

/** Per-run budget of the sweeper (SEC-035): whichever is reached first ends the run. */
export const SWEEP_MAX_BATCHES_PER_RUN = 100;
export const SWEEP_RUN_BUDGET_MS = 10_000;

/** Why a sweeper run stopped. */
export type SweepStop = 'drained' | 'batch_budget' | 'time_budget' | 'already_running' | 'stopped';

export interface SweepResult {
  /** Rooms this run ended (HEARTBEAT_TIMEOUT). */
  readonly ended: number;
  /** Batches (transactions) this run committed. */
  readonly batches: number;
  readonly stoppedBy: SweepStop;
}

export interface SweepOptions {
  readonly maxBatches?: number;
  readonly budgetMs?: number;
}

/** Error class and driver/Prisma code for failure logs (enough to triage without the message). */
export function errorClassAndCode(err: unknown): { errorClass: string; code: string | null } {
  let errorClass: string = typeof err;
  if (err === null) errorClass = 'null';
  else if (err instanceof Error) errorClass = err.constructor.name || err.name;
  const candidates: unknown[] = [];
  if (err !== null && typeof err === 'object') {
    const e = err as { code?: unknown; cause?: { code?: unknown; originalCode?: unknown } };
    candidates.push(e.code, e.cause?.originalCode, e.cause?.code);
  }
  const code = candidates.find((c): c is string | number => typeof c === 'string' || typeof c === 'number');
  return {
    errorClass: errorClass.slice(0, 100),
    code: code === undefined ? null : String(code).slice(0, 64),
  };
}

function ts(date: Date): string {
  return date.toISOString();
}

/**
 * ORDER BY of a tab (CONVENTIONS §10.4): `popular` = score (CP-012), startedAt, id (all desc);
 * `new` and `following` = startedAt, id (desc). `id` is always the final tiebreak, so the order
 * is total and keyset pages neither repeat nor skip rows of an unchanged result set.
 */
export function orderBy(tab: LiveTab): Prisma.Sql {
  return tab === 'popular'
    ? Prisma.sql`r.score DESC, r.started_at DESC, r.id DESC`
    : Prisma.sql`r.started_at DESC, r.id DESC`;
}

/** Rows strictly after `position` in the tab's order (row-value comparison, all keys desc). */
export function keysetAfter(tab: LiveTab, position: CursorPosition): Prisma.Sql {
  const startedAt = ts(position.startedAt);
  return tab === 'popular'
    ? Prisma.sql`(r.score, r.started_at, r.id) < (${String(position.score)}::bigint, ${startedAt}::timestamptz, ${position.id}::uuid)`
    : Prisma.sql`(r.started_at, r.id) < (${startedAt}::timestamptz, ${position.id}::uuid)`;
}

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND);
}

/**
 * CP-010 (§10.8): rooms of hosts the viewer blocked, or who blocked the viewer, are hidden.
 * Guests (no account) have no blocks.
 */
function notBlockedSql(viewerId: string | null): Prisma.Sql {
  if (viewerId === null) return Prisma.sql`TRUE`;
  return Prisma.sql`NOT EXISTS (SELECT 1 FROM user_blocks b
                    WHERE (b.blocker_id = ${viewerId}::uuid AND b.blocked_id = r.host_user_id)
                       OR (b.blocker_id = r.host_user_id AND b.blocked_id = ${viewerId}::uuid))`;
}

/**
 * Live rooms (`live_rooms`, owned by the live module): discovery lists, room detail and the host
 * lifecycle (go-live, heartbeat, end) behind LIVE_HOSTING_ENABLED (CONVENTIONS §10).
 *
 * Freshness: a LIVE room is fresh while `last_heartbeat_at > now − LIVE_HEARTBEAT_STALE_SECONDS`
 * (server clock, injectable for tests). Stale rooms are never reported as LIVE (CONVENTIONS §10.2,
 * v1.3.1 / SEC-035): every query applies the freshness predicate itself, so a room the sweeper has
 * not reached yet is still never shown as LIVE. The list writes nothing; room detail, the profile's
 * `liveRoomId` and the host's own write paths end only that one room; the background sweeper ends
 * the rest in bounded batches (`HEARTBEAT_TIMEOUT`, `ended_at = last_heartbeat_at`).
 * Every state change is a single `UPDATE … WHERE status = 'LIVE'`, so concurrent end, timeout
 * and suspension resolve to exactly one winner, and the partial unique index
 * `live_rooms_one_live_per_host` guarantees at most one LIVE room per host.
 */
@Injectable()
export class LiveRoomsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(LiveRoomsService.name);
  private readonly cursors: LiveCursorCodec;
  private sweepTimer: NodeJS.Timeout | undefined;
  private sweepInFlight: Promise<SweepResult> | null = null;
  private retentionInFlight: Promise<unknown> | null = null;
  private stopped = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly categories: LiveCategoriesService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly rankings: LiveRankingsService,
    private readonly schedule: LiveScheduleService,
  ) {
    this.cursors = new LiveCursorCodec(config.live.cursorKey);
  }

  onModuleInit(): void {
    if (this.config.live.sweepIntervalSeconds > 0) this.scheduleSweep();
  }

  async onModuleDestroy(): Promise<void> {
    this.stopped = true;
    if (this.sweepTimer) clearTimeout(this.sweepTimer);
    // Let a running batch commit before Prisma disconnects.
    await this.sweepInFlight?.catch(() => undefined);
    await this.retentionInFlight?.catch(() => undefined);
  }

  /**
   * The next run is scheduled only after the previous one has finished (one timer at a time), so
   * runs never overlap in this instance; {@link runSweep} also refuses to start while one runs.
   */
  private scheduleSweep(): void {
    if (this.stopped) return;
    this.sweepTimer = setTimeout(() => {
      void this.runSweep()
        .then((result) => {
          if (result.stoppedBy === 'batch_budget' || result.stoppedBy === 'time_budget') {
            this.logger.warn(
              { ended: result.ended, batches: result.batches, stoppedBy: result.stoppedBy },
              'Stale live-room sweep stopped at its per-run budget; the rest waits for the next run',
            );
          }
        })
        .catch((err: unknown) =>
          this.logger.error(
            { ...errorClassAndCode(err), error: safeErrorLog(err) },
            'Stale live-room sweep failed',
          ),
        )
        .then(() => {
          if (this.stopped) return undefined;
          // CP-016 C: the schedule reminders first (they are due now; a failure is logged and
          // does not hold back the retention sweeps). Then CP-013 chat retention, CP-016 A hourly
          // board points older than 15 days and CP-016 C slots 30 days past their start.
          this.retentionInFlight = this.schedule
            .sendReminders()
            .catch((err: unknown) =>
              this.logger.error(
                { ...errorClassAndCode(err), error: safeErrorLog(err) },
                'Live schedule reminders failed',
              ),
            )
            .then(() => this.sweepChatRetention())
            .then(() => this.rankings.sweepRetention())
            .then(() => this.schedule.sweepRetention())
            .then(() => undefined)
            .finally(() => {
              this.retentionInFlight = null;
            });
          return this.retentionInFlight;
        })
        .catch((err: unknown) =>
          this.logger.error(
            { ...errorClassAndCode(err), error: safeErrorLog(err) },
            'Live chat retention sweep failed',
          ),
        )
        .finally(() => this.scheduleSweep());
    }, this.config.live.sweepIntervalSeconds * 1000);
    this.sweepTimer.unref();
  }

  getConfig(): LiveConfigDto {
    return {
      hostingEnabled: this.config.live.hostingEnabled,
      heartbeatIntervalSeconds: this.config.live.heartbeatIntervalSeconds,
      heartbeatStaleAfterSeconds: this.config.live.heartbeatStaleSeconds,
      themes: [...LIVE_THEMES],
      seatCounts: { MULTI: [...LIVE_SEAT_COUNTS.MULTI], AUDIO: [...LIVE_SEAT_COUNTS.AUDIO] },
    };
  }

  private cutoff(now: Date): Date {
    return new Date(now.getTime() - this.config.live.heartbeatStaleSeconds * 1000);
  }

  private isFresh(lastHeartbeatAt: Date, now: Date): boolean {
    return lastHeartbeatAt.getTime() > this.cutoff(now).getTime();
  }

  // ---- Stale handling --------------------------------------------------------------------------

  private async setStatementTimeout(tx: Prisma.TransactionClient): Promise<void> {
    await setLiveStatementTimeout(tx);
  }

  /** Audits `live.room.timeout` for the rooms a statement just ended. */
  private async auditTimeouts(
    tx: Prisma.TransactionClient,
    rows: readonly { id: string; host_user_id: string }[],
  ): Promise<void> {
    await this.audit.recordManyIn(
      tx,
      rows.map((row): AuditEntry => ({
        action: AuditAction.LIVE_ROOM_TIMEOUT,
        targetType: 'live_room',
        targetId: row.id,
        metadata: { reason: 'HEARTBEAT_TIMEOUT', hostUserId: row.host_user_id },
      })),
    );
  }

  /**
   * Ends the stale LIVE room matching `scope` (one room id, or one host, who has at most one LIVE
   * room) with HEARTBEAT_TIMEOUT and `ended_at = last_heartbeat_at`, auditing `live.room.timeout`
   * for the room this call ended. Never unscoped: the sweeper ends rooms in bounded batches
   * ({@link endStaleBatch}).
   */
  private async endStaleIn(tx: Prisma.TransactionClient, scope: Prisma.Sql, now: Date): Promise<number> {
    const rows = await tx.$queryRaw<{ id: string; host_user_id: string }[]>`
      UPDATE live_rooms
         SET status = 'ENDED', end_reason = 'HEARTBEAT_TIMEOUT', ended_at = last_heartbeat_at,
             updated_at = ${ts(now)}::timestamptz
       WHERE status = 'LIVE' AND last_heartbeat_at <= ${ts(this.cutoff(now))}::timestamptz AND ${scope}
   RETURNING id::text AS id, host_user_id::text AS host_user_id`;
    await this.auditTimeouts(tx, rows);
    await roomsEndedIn(
      tx,
      rows.map((row) => row.id),
      now,
    );
    return rows.length;
  }

  /** {@link endStaleIn} for one room in its own short transaction. */
  private async endStaleOne(scope: Prisma.Sql, now: Date): Promise<number> {
    return this.prisma.$transaction(async (tx) => {
      await this.setStatementTimeout(tx);
      return this.endStaleIn(tx, scope, now);
    }, LIVE_TX_OPTIONS);
  }

  /**
   * One sweeper batch in its own transaction (DB_PHASE2_DISCOVERY §4): locks at most `batchSize`
   * stale LIVE rows, oldest heartbeat first (`live_rooms_live_heartbeat_idx`), skipping rows
   * another transaction holds (`SKIP LOCKED`, so concurrent instances never wait on each other),
   * ends exactly those rows under the `status = 'LIVE'` guard and audits them.
   *
   * Two statements rather than one `UPDATE … FROM (SELECT … FOR UPDATE)`: without table
   * statistics (e.g. right after a bulk change) PostgreSQL plans that join as a nested loop over
   * every LIVE row per batch row, which took seconds per batch at 40k rows. `id = ANY($ids)` is a
   * single pass. Returns the number of rows the batch locked (= ended: the locks are held).
   */
  private async endStaleBatch(now: Date, batchSize: number): Promise<number> {
    const cutoff = ts(this.cutoff(now));
    return this.prisma.$transaction(async (tx) => {
      await this.setStatementTimeout(tx);
      const locked = await tx.$queryRaw<{ id: string }[]>`
        SELECT id::text AS id FROM live_rooms
         WHERE status = 'LIVE' AND last_heartbeat_at <= ${cutoff}::timestamptz
         ORDER BY last_heartbeat_at
         LIMIT ${batchSize}
           FOR UPDATE SKIP LOCKED`;
      if (locked.length === 0) return 0;
      const rows = await tx.$queryRaw<{ id: string; host_user_id: string }[]>`
        UPDATE live_rooms
           SET status = 'ENDED', end_reason = 'HEARTBEAT_TIMEOUT', ended_at = last_heartbeat_at,
               updated_at = ${ts(now)}::timestamptz
         WHERE id = ANY(${locked.map((row) => row.id)}::uuid[])
           AND status = 'LIVE' AND last_heartbeat_at <= ${cutoff}::timestamptz
     RETURNING id::text AS id, host_user_id::text AS host_user_id`;
      await this.auditTimeouts(tx, rows);
      await roomsEndedIn(
        tx,
        rows.map((row) => row.id),
        now,
      );
      return locked.length;
    }, LIVE_TX_OPTIONS);
  }

  /**
   * One sweeper run (CONVENTIONS §10.2, SEC-035): batches of LIVE_SWEEP_BATCH_SIZE rooms, each in
   * its own transaction, until a batch ends fewer rooms than the batch size (drained) or the per-run
   * budget (batch count or wall time) is spent; the rest waits for the next run. A call while a run
   * is in progress in this instance does nothing (`already_running`). Several instances may sweep
   * at once: `SKIP LOCKED` and the `status = 'LIVE'` guard end each room exactly once.
   */
  async runSweep(options: SweepOptions = {}): Promise<SweepResult> {
    if (this.sweepInFlight) return { ended: 0, batches: 0, stoppedBy: 'already_running' };
    const run = this.sweepLoop(options);
    this.sweepInFlight = run;
    try {
      return await run;
    } finally {
      this.sweepInFlight = null;
    }
  }

  private async sweepLoop(options: SweepOptions): Promise<SweepResult> {
    const batchSize = this.config.live.sweepBatchSize;
    const maxBatches = options.maxBatches ?? SWEEP_MAX_BATCHES_PER_RUN;
    const budgetMs = options.budgetMs ?? SWEEP_RUN_BUDGET_MS;
    const startedAt = performance.now();
    let ended = 0;
    let batches = 0;
    for (;;) {
      if (this.stopped) return { ended, batches, stoppedBy: 'stopped' };
      if (batches >= maxBatches) return { ended, batches, stoppedBy: 'batch_budget' };
      if (performance.now() - startedAt >= budgetMs) return { ended, batches, stoppedBy: 'time_budget' };
      const count = await this.endStaleBatch(this.clock.now(), batchSize);
      ended += count;
      batches += 1;
      if (count < batchSize) return { ended, batches, stoppedBy: 'drained' };
    }
  }

  /**
   * CP-013 retention (owner D96, CONVENTIONS §10.11): chat messages (deleted ones included),
   * chat mutes and (v1.20-live) kicks of rooms that ended more than 30 days before `now` are removed, in bounded batches,
   * except messages an OPEN report points at (they stay until the report is closed). Runs after
   * each stale-room sweep. Returns the rows removed.
   */
  async sweepChatRetention(
    now: Date = this.clock.now(),
  ): Promise<{ messages: number; mutes: number; kicks: number }> {
    const cutoff = ts(new Date(now.getTime() - LIVE_CHAT_RETENTION_MS));
    let messages = 0;
    let mutes = 0;
    for (let batch = 0; batch < CHAT_RETENTION_MAX_BATCHES; batch += 1) {
      const removed = await this.prisma.$executeRaw`
        DELETE FROM live_chat_messages
         WHERE id IN (
           SELECT m.id FROM live_chat_messages m JOIN live_rooms r ON r.id = m.room_id
            WHERE r.status = 'ENDED' AND r.ended_at < ${cutoff}::timestamptz
              AND NOT EXISTS (SELECT 1 FROM reports p
                               WHERE p.target_live_chat_message_id = m.id AND p.status = 'OPEN')
            LIMIT ${CHAT_RETENTION_BATCH})`;
      messages += removed;
      if (removed < CHAT_RETENTION_BATCH) break;
    }
    for (let batch = 0; batch < CHAT_RETENTION_MAX_BATCHES; batch += 1) {
      const removed = await this.prisma.$executeRaw`
        DELETE FROM live_chat_mutes
         WHERE (room_id, user_id) IN (
           SELECT x.room_id, x.user_id FROM live_chat_mutes x JOIN live_rooms r ON r.id = x.room_id
            WHERE r.status = 'ENDED' AND r.ended_at < ${cutoff}::timestamptz
            LIMIT ${CHAT_RETENTION_BATCH})`;
      mutes += removed;
      if (removed < CHAT_RETENTION_BATCH) break;
    }
    // v1.20-live (D105, §10.20): kicks follow the chat mutes.
    let kicks = 0;
    for (let batch = 0; batch < CHAT_RETENTION_MAX_BATCHES; batch += 1) {
      const removed = await this.prisma.$executeRaw`
        DELETE FROM live_room_kicks
         WHERE (room_id, user_id) IN (
           SELECT x.room_id, x.user_id FROM live_room_kicks x JOIN live_rooms r ON r.id = x.room_id
            WHERE r.status = 'ENDED' AND r.ended_at < ${cutoff}::timestamptz
            LIMIT ${CHAT_RETENTION_BATCH})`;
      kicks += removed;
      if (removed < CHAT_RETENTION_BATCH) break;
    }
    return { messages, mutes, kicks };
  }

  /** One sweeper run with the default budget; returns the number of rooms it ended. */
  async sweepStale(): Promise<number> {
    return (await this.runSweep()).ended;
  }

  // ---- Reads -----------------------------------------------------------------------------------

  private toSummary(row: RoomRow, lang: ContentLanguage): LiveRoomSummaryDto {
    return {
      id: row.id,
      title: row.title,
      topic: row.topic,
      mode: row.mode,
      viewerCount: row.viewer_count,
      startedAt: row.started_at.toISOString(),
      coverUrl: row.cover_url,
      category:
        row.category_slug === null
          ? null
          : localizedCategory(
              {
                slug: row.category_slug,
                nameAr: row.category_name_ar ?? '',
                nameEn: row.category_name_en ?? '',
              },
              lang,
            ),
      host: {
        id: row.host_user_id,
        username: row.username,
        displayName: row.display_name,
        avatarUrl: row.avatar_url,
      },
      seatCount: row.seat_count,
      occupiedSeats: row.occupied_seats,
      theme: row.theme,
      score: Number(row.score),
    };
  }

  private toRoom(row: RoomRow, lang: ContentLanguage): LiveRoomDto {
    return {
      ...this.toSummary(row, lang),
      status: row.status,
      endedAt: row.ended_at?.toISOString() ?? null,
      endReason: row.end_reason,
      allowGuests: row.allow_guests,
      scoreParts: {
        total: Number(row.score),
        tapPoints: Number(row.tap_points),
        supportPoints: Number(row.support_points),
      },
      chatEnabled: row.chat_enabled,
      chatMuted: row.chat_muted ?? false,
      kicked: row.kicked ?? false,
      roomNumber: row.room_number,
      roomLevel: row.room_level,
    };
  }

  private async selectRoom(roomId: string, viewerId: string | null = null): Promise<RoomRow | null> {
    const rows = await this.prisma.$queryRaw<RoomRow[]>`
      SELECT ${ROOM_COLUMNS}, ${chatMutedSql(viewerId)} AS chat_muted, ${kickedSql(viewerId)} AS kicked
             ${ROOM_FROM}
       WHERE r.id = ${roomId}::uuid AND ${notBlockedSql(viewerId)}`;
    return rows[0] ?? null;
  }

  /**
   * `GET /live/rooms` (§10.4): LIVE, fresh, ACTIVE host; keyset pagination with a signed cursor.
   * Stale rooms are filtered out by the freshness predicate; the list performs no writes (§10.2).
   * CP-010: a guest (`callerId` null) may list `popular` and `new` (`following` → 401); rooms
   * across a block are hidden from a signed-in caller.
   */
  async listRooms(
    callerId: string | null,
    query: ListLiveRoomsQuery,
    lang: ContentLanguage,
  ): Promise<LiveRoomPageDto> {
    if (callerId === null && query.tab === 'following') {
      throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    }
    const scope = cursorScope(query.tab, query.category, callerId ?? 'guest');
    let position: CursorPosition | null = null;
    if (query.cursor !== undefined) {
      position = this.cursors.decode(query.cursor, scope);
      if (!position) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    }

    // Reads filter stale rooms and write nothing (SEC-035): the freshness predicate below is what
    // hides a room the sweeper has not ended yet.
    const now = this.clock.now();
    const conditions: Prisma.Sql[] = [
      Prisma.sql`r.status = 'LIVE'`,
      Prisma.sql`r.last_heartbeat_at > ${ts(this.cutoff(now))}::timestamptz`,
      Prisma.sql`u.status = 'ACTIVE'`,
      notBlockedSql(callerId),
    ];
    if (query.category !== undefined) {
      // Unknown or inactive slug → no category id → empty list (200), §10.4.
      conditions.push(
        Prisma.sql`r.category_id = (SELECT id FROM live_categories WHERE slug = ${query.category} AND is_active)`,
      );
    }
    if (query.tab === 'following') {
      conditions.push(
        Prisma.sql`EXISTS (SELECT 1 FROM follows f WHERE f.follower_id = ${callerId ?? ''}::uuid AND f.followee_id = r.host_user_id)`,
      );
    }
    if (position) conditions.push(keysetAfter(query.tab, position));

    const rows = await this.prisma.$queryRaw<RoomRow[]>`
      ${ROOM_SELECT}
       WHERE ${Prisma.join(conditions, ' AND ')}
       ORDER BY ${orderBy(query.tab)}
       LIMIT ${query.limit + 1}`;

    const hasMore = rows.length > query.limit;
    const page = rows.slice(0, query.limit);
    const last = page.at(-1);
    return {
      data: page.map((row) => this.toSummary(row, lang)),
      page: {
        nextCursor:
          hasMore && last
            ? this.cursors.encode(scope, {
                score: Number(last.score),
                startedAt: last.started_at,
                id: last.id,
              })
            : null,
        hasMore,
      },
    };
  }

  /**
   * `GET /live/rooms/{roomId}`: also ENDED rooms. Nonexistent, malformed and non-ACTIVE-host
   * rooms are the same 404, and so (CP-010) is a room across a block with `viewerId`. A stale
   * LIVE room is ended (that single room) and returned as ENDED. `viewerId` null: a guest.
   */
  async getRoom(roomId: string, lang: ContentLanguage, viewerId: string | null = null): Promise<LiveRoomDto> {
    return this.toRoom(await this.visibleRow(roomId, viewerId), lang);
  }

  /** The room row as {@link getRoom} sees it (stale rooms ended first), else 404. */
  async visibleRow(roomId: string, viewerId: string | null): Promise<RoomRow> {
    if (!isUuid(roomId)) throw notFound();
    let row = await this.selectRoom(roomId, viewerId);
    if (!row || row.host_status !== 'ACTIVE') throw notFound();
    const now = this.clock.now();
    if (row.status === 'LIVE' && !this.isFresh(row.last_heartbeat_at, now)) {
      await this.endStaleOne(Prisma.sql`id = ${roomId}::uuid`, now);
      row = await this.selectRoom(roomId, viewerId);
      if (!row || row.host_status !== 'ACTIVE') throw notFound();
    }
    return row;
  }

  /** The room DTO of a row from {@link visibleRow}. */
  roomDto(row: RoomRow, lang: ContentLanguage): LiveRoomDto {
    return this.toRoom(row, lang);
  }

  /**
   * Id of the host's LIVE room with a fresh heartbeat, else null (`PublicProfile.liveRoomId`).
   * A stale LIVE room found here is ended (that single room, §10.2). The caller has already
   * established that the host is ACTIVE.
   */
  async freshLiveRoomIdOf(hostUserId: string): Promise<string | null> {
    const room = await this.prisma.liveRoom.findFirst({
      where: { hostUserId, status: 'LIVE' },
      select: { id: true, lastHeartbeatAt: true },
    });
    if (!room) return null;
    const now = this.clock.now();
    if (this.isFresh(room.lastHeartbeatAt, now)) return room.id;
    await this.endStaleOne(Prisma.sql`id = ${room.id}::uuid`, now);
    return null;
  }

  // ---- Host lifecycle --------------------------------------------------------------------------

  private assertHostingEnabled(): void {
    if (!this.config.live.hostingEnabled) throw new AppException(ErrorCode.LIVE_HOSTING_UNAVAILABLE);
  }

  /**
   * `POST /live/rooms` (§10.3). Order after auth and rate limit (guards): hosting switch → body →
   * verified email → active category → one LIVE room per host. The caller's stale LIVE room is
   * ended in the same transaction; a fresh one (or a parallel winner) → 409.
   */
  async startRoom(
    callerId: string,
    body: unknown,
    lang: ContentLanguage,
    meta: RequestMeta,
  ): Promise<LiveRoomDto> {
    this.assertHostingEnabled();
    // CP-010 (§10.8): the hosting permission, checked right after the hosting switch.
    if ((await this.prisma.liveHost.count({ where: { userId: callerId } })) === 0) {
      throw new AppException(ErrorCode.LIVE_HOSTING_NOT_ALLOWED);
    }
    const parsed = startLiveRoomSchema.safeParse(body, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = parsed.data;

    if (!(await this.users.isEmailVerified(callerId))) throw new AppException(ErrorCode.AUTH_FORBIDDEN);

    let categoryId: string | null = null;
    if (input.categorySlug !== undefined) {
      categoryId = await this.categories.findActiveId(input.categorySlug);
      if (!categoryId) throw AppException.validation([{ field: 'categorySlug', issue: 'invalid_value' }]);
    }

    const now = this.clock.now();
    let roomId: string;
    try {
      roomId = await this.prisma.$transaction(async (tx) => {
        await this.setStatementTimeout(tx);
        // Re-check (and share-lock) the host inside the transaction: a suspension that commits
        // first refuses the go-live; a later one waits for this transaction and then ends the new
        // room as HOST_SUSPENDED (KL-040 observation).
        if (!(await this.users.lockActiveById(tx, callerId))) {
          throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
        }
        await this.endStaleIn(tx, Prisma.sql`host_user_id = ${callerId}::uuid`, now);
        // CP-015: the host's live cover at go-live, read under a share lock so a concurrent cover
        // change waits and then also updates this room.
        const [host] = await tx.$queryRaw<{ cover_url: string | null }[]>`
          SELECT cover_url FROM live_hosts WHERE user_id = ${callerId}::uuid FOR SHARE`;
        if (!host) throw new AppException(ErrorCode.LIVE_HOSTING_NOT_ALLOWED);
        const room = await tx.liveRoom.create({
          data: {
            hostUserId: callerId,
            title: input.title,
            categoryId,
            startedAt: now,
            lastHeartbeatAt: now,
            allowGuests: input.allowGuests ?? true,
            // CP-011: the mode, its seat count (validated with the mode) and the theme.
            mode: input.mode ?? 'SOLO',
            seatCount: input.seatCount ?? null,
            theme: input.theme ?? DEFAULT_LIVE_THEME,
            coverUrl: host.cover_url,
          },
          select: { id: true },
        });
        await this.audit.recordIn(tx, {
          action: AuditAction.LIVE_ROOM_START,
          actorUserId: callerId,
          targetType: 'live_room',
          targetId: room.id,
          metadata: {
            categorySlug: input.categorySlug ?? null,
            mode: input.mode ?? 'SOLO',
            seatCount: input.seatCount ?? null,
          },
          ip: meta.ip,
          requestId: meta.requestId,
        });
        return room.id;
      }, LIVE_TX_OPTIONS);
    } catch (err) {
      const index = violatedUniqueIndex(err);
      if (index === ONE_LIVE_PER_HOST_INDEX || index === 'host_user_id') {
        throw new AppException(ErrorCode.LIVE_ROOM_ALREADY_ACTIVE);
      }
      throw err;
    }
    const row = await this.selectRoom(roomId);
    if (!row) throw new Error(`live room ${roomId} vanished after creation`);
    return this.toRoom(row, lang);
  }

  /**
   * `POST /live/rooms/{roomId}/heartbeat` (§10.3, DB_PHASE2_DISCOVERY §2.2). Only a fresh LIVE
   * room of the caller is extended, so a late heartbeat never revives a room lists already hide.
   */
  async heartbeat(callerId: string, roomId: string): Promise<void> {
    this.assertHostingEnabled();
    if (!isUuid(roomId)) throw notFound();
    const now = this.clock.now();
    const updated = await this.prisma.$executeRaw`
      UPDATE live_rooms
         SET last_heartbeat_at = ${ts(now)}::timestamptz, updated_at = ${ts(now)}::timestamptz
       WHERE id = ${roomId}::uuid AND host_user_id = ${callerId}::uuid AND status = 'LIVE'
         AND last_heartbeat_at > ${ts(this.cutoff(now))}::timestamptz
         AND last_heartbeat_at <= ${ts(now)}::timestamptz`;
    if (updated === 1) return;

    const room = await this.prisma.liveRoom.findFirst({
      where: { id: roomId, hostUserId: callerId },
      select: { status: true, lastHeartbeatAt: true },
    });
    if (!room) throw notFound(); // not the host, or no such room: never reveal ownership
    if (room.status === 'LIVE') {
      if (this.isFresh(room.lastHeartbeatAt, now)) return; // clock skew between instances; still live
      await this.endStaleOne(Prisma.sql`id = ${roomId}::uuid`, now);
    }
    throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
  }

  /**
   * `POST /live/rooms/{roomId}/end` (§10.3): host only, idempotent, allowed while hosting is
   * disabled. An already ENDED room keeps its original reason and time. A LIVE room that is already
   * stale has, as far as every reader is concerned, timed out; it is ended as HEARTBEAT_TIMEOUT.
   */
  async endRoom(
    callerId: string,
    roomId: string,
    lang: ContentLanguage,
    meta: RequestMeta,
  ): Promise<LiveRoomDto> {
    if (!isUuid(roomId)) throw notFound();
    const owned = await this.prisma.liveRoom.count({ where: { id: roomId, hostUserId: callerId } });
    if (owned === 0) throw notFound();

    const now = this.clock.now();
    await this.prisma.$transaction(async (tx) => {
      await this.setStatementTimeout(tx);
      await this.endStaleIn(tx, Prisma.sql`id = ${roomId}::uuid`, now);
      const ended = await tx.$queryRaw<{ id: string }[]>`
        UPDATE live_rooms
           SET status = 'ENDED', end_reason = 'HOST_ENDED',
               ended_at = GREATEST(${ts(now)}::timestamptz, last_heartbeat_at),
               updated_at = ${ts(now)}::timestamptz
         WHERE id = ${roomId}::uuid AND host_user_id = ${callerId}::uuid AND status = 'LIVE'
           AND last_heartbeat_at > ${ts(this.cutoff(now))}::timestamptz
     RETURNING id::text AS id`;
      if (ended.length === 1) {
        await roomsEndedIn(tx, [roomId], now);
        await this.audit.recordIn(tx, {
          action: AuditAction.LIVE_ROOM_END,
          actorUserId: callerId,
          targetType: 'live_room',
          targetId: roomId,
          metadata: { reason: 'HOST_ENDED' },
          ip: meta.ip,
          requestId: meta.requestId,
        });
      }
    }, LIVE_TX_OPTIONS);
    const row = await this.selectRoom(roomId);
    if (!row) throw notFound();
    return this.toRoom(row, lang);
  }

  /**
   * CP-014 (§10.12): edits the title, category and topic of the host's LIVE room. A field equal to
   * the stored value is not a change. When something changed, `info_version` increases in the same
   * transaction (the room row is locked, so concurrent edits each get their own version) and
   * `live.room.edit` is audited with the names of the changed fields (and the new category slug,
   * never the text). Returns the new info version, or null when nothing changed. Not the host → 404;
   * ended meanwhile → 409.
   */
  async editInfo(
    hostId: string,
    roomId: string,
    edit: RoomInfoEdit,
    meta: RequestMeta,
  ): Promise<number | null> {
    if (!isUuid(roomId)) throw notFound();
    return this.prisma.$transaction(async (tx) => {
      await this.setStatementTimeout(tx);
      const [room] = await tx.$queryRaw<
        { title: string; category_id: string | null; topic: string | null; status: string }[]
      >`
        SELECT title, category_id::text AS category_id, topic, status::text AS status
          FROM live_rooms
         WHERE id = ${roomId}::uuid AND host_user_id = ${hostId}::uuid
           FOR NO KEY UPDATE`;
      if (!room) throw notFound();
      if (room.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);

      const fields: ('title' | 'categorySlug' | 'topic')[] = [];
      const data: Prisma.LiveRoomUpdateInput = {};
      if (edit.title !== undefined && edit.title !== room.title) {
        fields.push('title');
        data.title = edit.title;
      }
      if (edit.category !== undefined && (edit.category?.id ?? null) !== room.category_id) {
        fields.push('categorySlug');
        data.category = edit.category === null ? { disconnect: true } : { connect: { id: edit.category.id } };
      }
      if (edit.topic !== undefined && edit.topic !== room.topic) {
        fields.push('topic');
        data.topic = edit.topic;
      }
      if (fields.length === 0) return null;

      const updated = await tx.liveRoom.update({
        where: { id: roomId },
        data: { ...data, infoVersion: { increment: 1 } },
        select: { infoVersion: true },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.LIVE_ROOM_EDIT,
        actorUserId: hostId,
        targetType: 'live_room',
        targetId: roomId,
        metadata: {
          fields,
          ...(fields.includes('categorySlug') ? { categorySlug: edit.category?.slug ?? null } : {}),
          infoVersion: updated.infoVersion,
        },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      return updated.infoVersion;
    }, LIVE_TX_OPTIONS);
  }

  /**
   * Suspension (§10.2): ends the host's LIVE room with HOST_SUSPENDED inside the caller's
   * transaction (a room that is already stale is ended as HEARTBEAT_TIMEOUT instead). Used by
   * AccountLifecycleService; the ACTIVE-host filter on every read path is the safety net.
   */
  async endForSuspendedHostIn(tx: Prisma.TransactionClient, hostUserId: string): Promise<void> {
    const now = this.clock.now();
    await this.endStaleIn(tx, Prisma.sql`host_user_id = ${hostUserId}::uuid`, now);
    const ended = await tx.$queryRaw<{ id: string }[]>`
      UPDATE live_rooms
         SET status = 'ENDED', end_reason = 'HOST_SUSPENDED',
             ended_at = GREATEST(${ts(now)}::timestamptz, last_heartbeat_at),
             updated_at = ${ts(now)}::timestamptz
       WHERE host_user_id = ${hostUserId}::uuid AND status = 'LIVE'
         AND last_heartbeat_at > ${ts(this.cutoff(now))}::timestamptz
   RETURNING id::text AS id`;
    await roomsEndedIn(
      tx,
      ended.map((row) => row.id),
      now,
    );
    await this.audit.recordManyIn(
      tx,
      ended.map((row): AuditEntry => ({
        action: AuditAction.LIVE_ROOM_END,
        targetType: 'live_room',
        targetId: row.id,
        metadata: { reason: 'HOST_SUSPENDED', hostUserId },
      })),
    );
  }

  /**
   * CP-011 (§10.9): a suspended or deleted account loses its seats, pending seat requests and
   * invitations and moderator roles in every LIVE room, inside the caller's transaction. The media
   * permission and room metadata are re-applied by the sweeper's reconciliation.
   */
  async releaseSeatsOfUserIn(tx: Prisma.TransactionClient, userId: string): Promise<void> {
    await releaseUserIn(tx, userId, this.clock.now(), { moderator: true });
  }

  /**
   * CP-010: an admin ends a LIVE room (report action) with `ADMIN`, inside the caller's
   * transaction, audited by the caller (scope: one room, or the host's room when the hosting
   * permission is revoked). A stale room is ended as HEARTBEAT_TIMEOUT instead. Returns the ids
   * this call ended with `ADMIN`.
   */
  async endByAdminIn(
    tx: Prisma.TransactionClient,
    scope: { roomId: string } | { hostUserId: string },
  ): Promise<string[]> {
    const now = this.clock.now();
    const where =
      'roomId' in scope
        ? Prisma.sql`id = ${scope.roomId}::uuid`
        : Prisma.sql`host_user_id = ${scope.hostUserId}::uuid`;
    await this.endStaleIn(tx, where, now);
    const ended = await tx.$queryRaw<{ id: string }[]>`
      UPDATE live_rooms
         SET status = 'ENDED', end_reason = 'ADMIN',
             ended_at = GREATEST(${ts(now)}::timestamptz, last_heartbeat_at),
             updated_at = ${ts(now)}::timestamptz
       WHERE ${where} AND status = 'LIVE'
         AND last_heartbeat_at > ${ts(this.cutoff(now))}::timestamptz
   RETURNING id::text AS id`;
    await roomsEndedIn(
      tx,
      ended.map((row) => row.id),
      now,
    );
    return ended.map((row) => row.id);
  }
}
