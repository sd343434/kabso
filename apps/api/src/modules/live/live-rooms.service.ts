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
import { CountriesService } from '../countries/countries.service.js';
import type { ModerationStatus } from '../media/media.constants.js';
import { MediaService } from '../media/media.service.js';
import { MediaUrls, type MediaRef } from '../media/media-urls.js';
import { UsersService, violatedUniqueIndex } from '../users/users.service.js';
import { LiveCategoriesService, localizedCategory, type LiveCategoryDto } from './live-categories.service.js';
import { cursorScope, LiveCursorCodec, type CursorPosition, type LiveTab } from './live-cursor.js';
import {
  isUuid,
  setLiveRoomCoverSchema,
  startLiveRoomSchema,
  type ListLiveRoomsQuery,
} from './live.schemas.js';

// ---- Response shapes (openapi v1.3, v1.4) ------------------------------------------------------

/** `UserSummary`: never contains an email. */
export interface UserSummaryDto {
  id: string;
  username: string;
  displayName: string;
  avatarUrl: string | null;
  /** v1.4: null exactly when `avatarUrl` is null. */
  avatarThumbUrl: string | null;
}

export type LiveRoomMode = 'SOLO' | 'PK' | 'MULTI';
export type LiveRoomEndReason = 'HOST_ENDED' | 'HEARTBEAT_TIMEOUT' | 'HOST_SUSPENDED' | 'ADMIN';

export interface LiveRoomSummaryDto {
  id: string;
  title: string;
  mode: LiveRoomMode;
  viewerCount: number;
  startedAt: string;
  coverUrl: string | null;
  /** v1.4: null exactly when `coverUrl` is null. */
  coverThumbUrl: string | null;
  category: LiveCategoryDto | null;
  /** v1.4: the host's chosen country (snapshot at go-live, synced while LIVE). */
  country: string | null;
  host: UserSummaryDto;
}

export interface LiveRoomDto extends LiveRoomSummaryDto {
  status: 'LIVE' | 'ENDED';
  endedAt: string | null;
  endReason: LiveRoomEndReason | null;
  /** v1.4: moderation state of the cover, sent only to the host (null for everyone else). */
  coverModeration: ModerationStatus | null;
}

/** v1.4 `LiveCountry`. */
export interface LiveCountryDto {
  code: string;
  name: string;
  liveRoomCount: number;
}

export interface LiveRoomPageDto {
  data: LiveRoomSummaryDto[];
  page: { nextCursor: string | null; hasMore: boolean };
}

export interface LiveConfigDto {
  hostingEnabled: boolean;
  heartbeatIntervalSeconds: number;
  heartbeatStaleAfterSeconds: number;
}

/** Request facts recorded in the audit trail. */
export interface RequestMeta {
  readonly ip: string | null;
  readonly requestId: string | null;
}

// ---- Persistence -------------------------------------------------------------------------------

interface RoomRow {
  id: string;
  title: string;
  mode: LiveRoomMode;
  status: 'LIVE' | 'ENDED';
  viewer_count: number;
  started_at: Date;
  last_heartbeat_at: Date;
  ended_at: Date | null;
  end_reason: LiveRoomEndReason | null;
  country: string | null;
  cover_token: string | null;
  cover_status: string | null;
  cover_purpose: 'AVATAR' | 'ROOM_COVER' | null;
  cover_moderation: ModerationStatus | null;
  cover_owner: string | null;
  host_user_id: string;
  host_status: string;
  username: string;
  display_name: string;
  avatar_token: string | null;
  avatar_status: string | null;
  avatar_purpose: 'AVATAR' | 'ROOM_COVER' | null;
  avatar_moderation: ModerationStatus | null;
  avatar_owner: string | null;
  category_slug: string | null;
  category_name_ar: string | null;
  category_name_en: string | null;
}

/**
 * Room + host identity + category + cover and host avatar in one statement. Reading `users` /
 * `user_profiles` here (for the ACTIVE-host filter and the host summary), `follows` (Following tab)
 * and `media_objects` (v1.4: two LEFT JOINs for the cover and the host avatar; public token, purpose,
 * status and moderation state only) are the documented read-only exceptions to module table
 * ownership (DB_PHASE2_DISCOVERY §1, DB_PHASE2_MEDIA §1): the list must filter and paginate in the
 * database. Image URLs are computed from the token, never stored (DB_PHASE2_MEDIA §3).
 */
const ROOM_SELECT = Prisma.sql`
  SELECT r.id::text AS id, r.title, r.mode::text AS mode, r.status::text AS status, r.viewer_count,
         r.started_at, r.last_heartbeat_at, r.ended_at, r.end_reason::text AS end_reason, r.country::text AS country,
         cm.public_token AS cover_token, cm.status::text AS cover_status, cm.purpose::text AS cover_purpose,
         cm.moderation_status::text AS cover_moderation, cm.owner_user_id::text AS cover_owner,
         r.host_user_id::text AS host_user_id, u.status::text AS host_status, p.username,
         p.display_name, am.public_token AS avatar_token, am.status::text AS avatar_status,
         am.purpose::text AS avatar_purpose, am.moderation_status::text AS avatar_moderation,
         am.owner_user_id::text AS avatar_owner, c.slug AS category_slug,
         c.name_ar AS category_name_ar, c.name_en AS category_name_en
    FROM live_rooms r
    JOIN users u ON u.id = r.host_user_id
    JOIN user_profiles p ON p.user_id = r.host_user_id
    LEFT JOIN live_categories c ON c.id = r.category_id
    LEFT JOIN media_objects cm ON cm.id = r.cover_media_id
    LEFT JOIN media_objects am ON am.id = p.avatar_media_id`;

function coverRef(row: RoomRow): MediaRef | null {
  if (row.cover_purpose === null || row.cover_status === null || row.cover_owner === null) return null;
  return {
    ownerUserId: row.cover_owner,
    purpose: row.cover_purpose,
    status: row.cover_status,
    publicToken: row.cover_token,
    moderationStatus: row.cover_moderation,
  };
}

function avatarRef(row: RoomRow): MediaRef | null {
  if (row.avatar_purpose === null || row.avatar_status === null || row.avatar_owner === null) return null;
  return {
    ownerUserId: row.avatar_owner,
    purpose: row.avatar_purpose,
    status: row.avatar_status,
    publicToken: row.avatar_token,
    moderationStatus: row.avatar_moderation,
  };
}

const ONE_LIVE_PER_HOST_INDEX = 'live_rooms_one_live_per_host';

/**
 * Explicit interactive-transaction limits for every live-room transaction (SEC-035): Prisma's
 * default 5 s timeout is never relied on, and a slow statement is cancelled by the server
 * (`statement_timeout`) before the client-side timeout rolls the transaction back.
 */
export const LIVE_TX_OPTIONS = { maxWait: 5_000, timeout: 10_000 } as const;
const LIVE_STATEMENT_TIMEOUT_MS = 8_000;

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
 * ORDER BY of a tab (CONVENTIONS §10.4): `popular` = viewerCount, startedAt, id (all desc);
 * `new` and `following` = startedAt, id (desc). `id` is always the final tiebreak, so the order
 * is total and keyset pages neither repeat nor skip rows of an unchanged result set.
 */
export function orderBy(tab: LiveTab): Prisma.Sql {
  return tab === 'popular'
    ? Prisma.sql`r.viewer_count DESC, r.started_at DESC, r.id DESC`
    : Prisma.sql`r.started_at DESC, r.id DESC`;
}

/** Rows strictly after `position` in the tab's order (row-value comparison, all keys desc). */
export function keysetAfter(tab: LiveTab, position: CursorPosition): Prisma.Sql {
  const startedAt = ts(position.startedAt);
  return tab === 'popular'
    ? Prisma.sql`(r.viewer_count, r.started_at, r.id) < (${position.viewerCount}::int, ${startedAt}::timestamptz, ${position.id}::uuid)`
    : Prisma.sql`(r.started_at, r.id) < (${startedAt}::timestamptz, ${position.id}::uuid)`;
}

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND);
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
  private stopped = false;
  /** v1.4 `GET /live/countries` counts, cached for at most LIVE_HEARTBEAT_INTERVAL_SECONDS. */
  private countriesCache: {
    readonly at: number;
    readonly rows: readonly { country: string; count: number }[];
  } | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly categories: LiveCategoriesService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    private readonly media: MediaService,
    private readonly mediaUrls: MediaUrls,
    private readonly countries: CountriesService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
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
        .finally(() => this.scheduleSweep());
    }, this.config.live.sweepIntervalSeconds * 1000);
    this.sweepTimer.unref();
  }

  getConfig(): LiveConfigDto {
    return {
      hostingEnabled: this.config.live.hostingEnabled,
      heartbeatIntervalSeconds: this.config.live.heartbeatIntervalSeconds,
      heartbeatStaleAfterSeconds: this.config.live.heartbeatStaleSeconds,
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
    await tx.$queryRaw`SELECT set_config('statement_timeout', ${String(LIVE_STATEMENT_TIMEOUT_MS)}, true)`;
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

  /** One sweeper run with the default budget; returns the number of rooms it ended. */
  async sweepStale(): Promise<number> {
    return (await this.runSweep()).ended;
  }

  // ---- Reads -----------------------------------------------------------------------------------

  /** `viewerId`: the caller, for the moderation visibility rule (CONVENTIONS §11.5). */
  private toSummary(row: RoomRow, lang: ContentLanguage, viewerId: string): LiveRoomSummaryDto {
    const cover = this.mediaUrls.visibleUrls(coverRef(row), viewerId);
    const avatar = this.mediaUrls.visibleUrls(avatarRef(row), viewerId);
    return {
      id: row.id,
      title: row.title,
      mode: row.mode,
      viewerCount: row.viewer_count,
      startedAt: row.started_at.toISOString(),
      coverUrl: cover.url,
      coverThumbUrl: cover.thumbUrl,
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
      country: row.country,
      host: {
        id: row.host_user_id,
        username: row.username,
        displayName: row.display_name,
        avatarUrl: avatar.url,
        avatarThumbUrl: avatar.thumbUrl,
      },
    };
  }

  private toRoom(row: RoomRow, lang: ContentLanguage, viewerId: string): LiveRoomDto {
    const isHost = viewerId === row.host_user_id;
    return {
      ...this.toSummary(row, lang, viewerId),
      status: row.status,
      endedAt: row.ended_at?.toISOString() ?? null,
      endReason: row.end_reason,
      coverModeration: isHost && coverRef(row) !== null ? row.cover_moderation : null,
    };
  }

  private async selectRoom(roomId: string): Promise<RoomRow | null> {
    const rows = await this.prisma.$queryRaw<RoomRow[]>`${ROOM_SELECT} WHERE r.id = ${roomId}::uuid`;
    return rows[0] ?? null;
  }

  /**
   * `GET /live/rooms` (§10.4): LIVE, fresh, ACTIVE host; keyset pagination with a signed cursor.
   * Stale rooms are filtered out by the freshness predicate; the list performs no writes (§10.2).
   */
  async listRooms(
    callerId: string,
    query: ListLiveRoomsQuery,
    lang: ContentLanguage,
  ): Promise<LiveRoomPageDto> {
    if (query.country !== undefined && !this.countries.isListed(query.country)) {
      throw AppException.validation([{ field: 'country', issue: 'invalid_value' }]);
    }
    const scope = cursorScope(query.tab, query.category, callerId, query.country);
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
    ];
    if (query.category !== undefined) {
      // Unknown or inactive slug → no category id → empty list (200), §10.4.
      conditions.push(
        Prisma.sql`r.category_id = (SELECT id FROM live_categories WHERE slug = ${query.category} AND is_active)`,
      );
    }
    if (query.country !== undefined) {
      // v1.4 (§11.9): rooms without a country never match.
      conditions.push(Prisma.sql`r.country = ${query.country}::char(2)`);
    }
    if (query.tab === 'following') {
      conditions.push(
        Prisma.sql`EXISTS (SELECT 1 FROM follows f WHERE f.follower_id = ${callerId}::uuid AND f.followee_id = r.host_user_id)`,
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
      data: page.map((row) => this.toSummary(row, lang, callerId)),
      page: {
        nextCursor:
          hasMore && last
            ? this.cursors.encode(scope, {
                viewerCount: last.viewer_count,
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
   * rooms are the same 404. A stale LIVE room is ended (that single room) and returned as ENDED.
   */
  async getRoom(roomId: string, lang: ContentLanguage, viewerId: string): Promise<LiveRoomDto> {
    if (!isUuid(roomId)) throw notFound();
    let row = await this.selectRoom(roomId);
    if (!row || row.host_status !== 'ACTIVE') throw notFound();
    const now = this.clock.now();
    if (row.status === 'LIVE' && !this.isFresh(row.last_heartbeat_at, now)) {
      await this.endStaleOne(Prisma.sql`id = ${roomId}::uuid`, now);
      row = await this.selectRoom(roomId);
      if (!row || row.host_status !== 'ACTIVE') throw notFound();
    }
    return this.toRoom(row, lang, viewerId);
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
   * verified email → active category → (v1.4) `coverUploadId`: uploads disabled → 503
   * MEDIA_UPLOADS_UNAVAILABLE, not the caller's attachable cover → 400 → one LIVE room per host.
   * The caller's stale LIVE room is ended in the same transaction; a fresh one (or a parallel
   * winner) → 409, and then nothing is attached (the upload stays usable). The room's country is
   * the host's profile country at this moment (§11.8).
   */
  async startRoom(
    callerId: string,
    body: unknown,
    lang: ContentLanguage,
    meta: RequestMeta,
  ): Promise<LiveRoomDto> {
    this.assertHostingEnabled();
    const parsed = startLiveRoomSchema.safeParse(body, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = parsed.data;

    if (!(await this.users.isEmailVerified(callerId))) throw new AppException(ErrorCode.AUTH_FORBIDDEN);

    let categoryId: string | null = null;
    if (input.categorySlug !== undefined) {
      categoryId = await this.categories.findActiveId(input.categorySlug);
      if (!categoryId) throw AppException.validation([{ field: 'categorySlug', issue: 'invalid_value' }]);
    }
    if (input.coverUploadId !== undefined) this.media.assertUploadsEnabled();

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
        if (
          input.coverUploadId !== undefined &&
          !(await this.media.attachIn(tx, callerId, input.coverUploadId, 'ROOM_COVER', now))
        ) {
          throw AppException.validation([{ field: 'coverUploadId', issue: 'invalid_value' }]);
        }
        const room = await tx.liveRoom.create({
          data: {
            hostUserId: callerId,
            title: input.title,
            categoryId,
            startedAt: now,
            lastHeartbeatAt: now,
            coverMediaId: input.coverUploadId ?? null,
            country: await this.users.countryOfIn(tx, callerId),
          },
          select: { id: true },
        });
        await this.audit.recordIn(tx, {
          action: AuditAction.LIVE_ROOM_START,
          actorUserId: callerId,
          targetType: 'live_room',
          targetId: room.id,
          metadata: { categorySlug: input.categorySlug ?? null },
          ip: meta.ip,
          requestId: meta.requestId,
        });
        if (input.coverUploadId !== undefined) {
          await this.audit.recordIn(tx, {
            action: AuditAction.MEDIA_COVER_SET,
            actorUserId: callerId,
            targetType: 'live_room',
            targetId: room.id,
            metadata: { uploadId: input.coverUploadId },
            ip: meta.ip,
            requestId: meta.requestId,
          });
        }
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
    return this.toRoom(row, lang, callerId);
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
    return this.toRoom(row, lang, callerId);
  }

  /**
   * `PUT /live/rooms/{roomId}/cover` (v1.4, §11.4). Order after auth and rate limit: hosting switch
   * (503, for every caller, before the ownership check) → body → host's room (else 404) → LIVE with a
   * fresh heartbeat (else 409 LIVE_ROOM_ENDED; a stale room is ended as HEARTBEAT_TIMEOUT) → a
   * non-null upload while uploads are disabled → 503 MEDIA_UPLOADS_UNAVAILABLE → the caller's own
   * attachable `room_cover` upload (else 400). The previous cover is detached (grace period).
   */
  async setCover(
    callerId: string,
    roomId: string,
    body: unknown,
    lang: ContentLanguage,
    meta: RequestMeta,
  ): Promise<LiveRoomDto> {
    this.assertHostingEnabled();
    const parsed = setLiveRoomCoverSchema.safeParse(body, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const uploadId = parsed.data.coverUploadId;
    if (!isUuid(roomId)) throw notFound();

    const now = this.clock.now();
    const outcome = await this.prisma.$transaction(async (tx): Promise<'ok' | 'ended'> => {
      await this.setStatementTimeout(tx);
      const rooms = await tx.$queryRaw<
        { status: string; last_heartbeat_at: Date; cover_media_id: string | null }[]
      >`
        SELECT status::text AS status, last_heartbeat_at, cover_media_id::text AS cover_media_id
          FROM live_rooms WHERE id = ${roomId}::uuid AND host_user_id = ${callerId}::uuid FOR UPDATE`;
      const room = rooms[0];
      if (!room) throw notFound(); // not the host, or no such room: never reveal ownership
      if (room.status !== 'LIVE') return 'ended';
      if (!this.isFresh(room.last_heartbeat_at, now)) {
        await this.endStaleIn(tx, Prisma.sql`id = ${roomId}::uuid`, now);
        return 'ended';
      }
      if (uploadId !== null) {
        this.media.assertUploadsEnabled();
        if (!(await this.media.attachIn(tx, callerId, uploadId, 'ROOM_COVER', now))) {
          throw AppException.validation([{ field: 'coverUploadId', issue: 'invalid_value' }]);
        }
      }
      if (room.cover_media_id !== null) await this.media.detachIn(tx, room.cover_media_id, now);
      await tx.$executeRaw`
        UPDATE live_rooms SET cover_media_id = ${uploadId}::uuid, updated_at = ${ts(now)}::timestamptz
         WHERE id = ${roomId}::uuid`;
      if (uploadId !== null || room.cover_media_id !== null) {
        await this.audit.recordIn(tx, {
          action: uploadId === null ? AuditAction.MEDIA_COVER_REMOVE : AuditAction.MEDIA_COVER_SET,
          actorUserId: callerId,
          targetType: 'live_room',
          targetId: roomId,
          metadata: uploadId === null ? {} : { uploadId },
          ip: meta.ip,
          requestId: meta.requestId,
        });
      }
      return 'ok';
    }, LIVE_TX_OPTIONS);
    if (outcome === 'ended') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    const row = await this.selectRoom(roomId);
    if (!row) throw notFound();
    return this.toRoom(row, lang, callerId);
  }

  /**
   * v1.4 (§11.8, DB_PHASE2_MEDIA §3.2): inside the `PATCH /me` transaction, the host's LIVE room
   * takes the host's new country (or null). ENDED rooms keep theirs.
   */
  async syncHostCountryIn(
    tx: Prisma.TransactionClient,
    hostUserId: string,
    country: string | null,
  ): Promise<void> {
    await tx.$executeRaw`
      UPDATE live_rooms SET country = ${country}::char(2), updated_at = ${ts(this.clock.now())}::timestamptz
       WHERE host_user_id = ${hostUserId}::uuid AND status = 'LIVE'`;
  }

  /**
   * `GET /live/countries` (v1.4, §11.9): countries with at least one room that `GET /live/rooms`
   * would list (LIVE, fresh heartbeat, ACTIVE host) and a non-null country, with real counts
   * (never estimated or padded). The counts are cached in this process for at most
   * LIVE_HEARTBEAT_INTERVAL_SECONDS; names are localized per request.
   */
  async listCountries(lang: ContentLanguage): Promise<LiveCountryDto[]> {
    const nowMs = this.clock.now().getTime();
    const ttlMs = this.config.live.heartbeatIntervalSeconds * 1000;
    let cache = this.countriesCache;
    if (!cache || nowMs - cache.at >= ttlMs || nowMs < cache.at) {
      const now = new Date(nowMs);
      const rows = await this.prisma.$queryRaw<{ country: string; count: number }[]>`
        SELECT r.country::text AS country, count(*)::int AS count
          FROM live_rooms r
          JOIN users u ON u.id = r.host_user_id
         WHERE r.status = 'LIVE' AND r.country IS NOT NULL
           AND r.last_heartbeat_at > ${ts(this.cutoff(now))}::timestamptz
           AND u.status = 'ACTIVE'
         GROUP BY r.country`;
      cache = { at: nowMs, rows };
      this.countriesCache = cache;
    }
    return cache.rows
      .filter((row) => row.count >= 1 && this.countries.isListed(row.country))
      .sort((a, b) => b.count - a.count || (a.country < b.country ? -1 : a.country > b.country ? 1 : 0))
      .map((row) => ({
        code: row.country,
        name: this.countries.name(row.country, lang) ?? row.country,
        liveRoomCount: row.count,
      }));
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
}
