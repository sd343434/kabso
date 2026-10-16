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
import { LiveCategoriesService, localizedCategory, type LiveCategoryDto } from './live-categories.service.js';
import { cursorScope, LiveCursorCodec, type CursorPosition, type LiveTab } from './live-cursor.js';
import { isUuid, startLiveRoomSchema, type ListLiveRoomsQuery } from './live.schemas.js';

// ---- Response shapes (openapi v1.3) ------------------------------------------------------------

/** `UserSummary`: never contains an email. */
export interface UserSummaryDto {
  id: string;
  username: string;
  displayName: string;
  avatarUrl: string | null;
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
  category: LiveCategoryDto | null;
  host: UserSummaryDto;
}

export interface LiveRoomDto extends LiveRoomSummaryDto {
  status: 'LIVE' | 'ENDED';
  endedAt: string | null;
  endReason: LiveRoomEndReason | null;
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
  cover_url: string | null;
  host_user_id: string;
  host_status: string;
  username: string;
  display_name: string;
  avatar_url: string | null;
  category_slug: string | null;
  category_name_ar: string | null;
  category_name_en: string | null;
}

/**
 * Room + host identity + category in one statement. Reading `users` / `user_profiles` here (for the
 * ACTIVE-host filter and the host summary) and `follows` (Following tab) are the documented
 * read-only exceptions to module table ownership (DB_PHASE2_DISCOVERY §1): the list must filter
 * and paginate in the database.
 */
const ROOM_SELECT = Prisma.sql`
  SELECT r.id::text AS id, r.title, r.mode::text AS mode, r.status::text AS status, r.viewer_count,
         r.started_at, r.last_heartbeat_at, r.ended_at, r.end_reason::text AS end_reason, r.cover_url,
         r.host_user_id::text AS host_user_id, u.status::text AS host_status, p.username,
         p.display_name, p.avatar_url, c.slug AS category_slug, c.name_ar AS category_name_ar,
         c.name_en AS category_name_en
    FROM live_rooms r
    JOIN users u ON u.id = r.host_user_id
    JOIN user_profiles p ON p.user_id = r.host_user_id
    LEFT JOIN live_categories c ON c.id = r.category_id`;

const ONE_LIVE_PER_HOST_INDEX = 'live_rooms_one_live_per_host';

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
 * (server clock, injectable for tests). Stale rooms are never reported as LIVE: the sweeper and
 * every read path that meets one end it (`HEARTBEAT_TIMEOUT`, `ended_at = last_heartbeat_at`).
 * Every state change is a single `UPDATE … WHERE status = 'LIVE'`, so concurrent end, timeout
 * and suspension resolve to exactly one winner, and the partial unique index
 * `live_rooms_one_live_per_host` guarantees at most one LIVE room per host.
 */
@Injectable()
export class LiveRoomsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(LiveRoomsService.name);
  private readonly cursors: LiveCursorCodec;
  private sweepTimer: NodeJS.Timeout | undefined;

  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly categories: LiveCategoriesService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    this.cursors = new LiveCursorCodec(config.live.cursorKey);
  }

  onModuleInit(): void {
    const seconds = this.config.live.sweepIntervalSeconds;
    if (seconds > 0) {
      this.sweepTimer = setInterval(() => {
        void this.sweepStale().catch((err: unknown) =>
          this.logger.error({ error: safeErrorLog(err) }, 'Stale live-room sweep failed'),
        );
      }, seconds * 1000);
      this.sweepTimer.unref();
    }
  }

  onModuleDestroy(): void {
    if (this.sweepTimer) clearInterval(this.sweepTimer);
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

  /**
   * Ends every stale LIVE room matching `scope` (all when null) with HEARTBEAT_TIMEOUT and
   * `ended_at = last_heartbeat_at`, auditing `live.room.timeout` for the rooms this call ended.
   */
  private async endStaleIn(
    tx: Prisma.TransactionClient,
    scope: Prisma.Sql | null,
    now: Date,
  ): Promise<number> {
    const rows = await tx.$queryRaw<{ id: string; host_user_id: string }[]>`
      UPDATE live_rooms
         SET status = 'ENDED', end_reason = 'HEARTBEAT_TIMEOUT', ended_at = last_heartbeat_at,
             updated_at = ${ts(now)}::timestamptz
       WHERE status = 'LIVE' AND last_heartbeat_at <= ${ts(this.cutoff(now))}::timestamptz
             ${scope ? Prisma.sql`AND ${scope}` : Prisma.empty}
   RETURNING id::text AS id, host_user_id::text AS host_user_id`;
    await this.audit.recordManyIn(
      tx,
      rows.map((row): AuditEntry => ({
        action: AuditAction.LIVE_ROOM_TIMEOUT,
        targetType: 'live_room',
        targetId: row.id,
        metadata: { reason: 'HEARTBEAT_TIMEOUT', hostUserId: row.host_user_id },
      })),
    );
    return rows.length;
  }

  private async endStale(scope: Prisma.Sql | null, now: Date): Promise<number> {
    return this.prisma.$transaction((tx) => this.endStaleIn(tx, scope, now));
  }

  /**
   * The periodic sweeper (every LIVE_SWEEP_INTERVAL_SECONDS per API instance). Idempotent and safe
   * to run concurrently on several instances (the `status = 'LIVE'` guard). Returns rooms ended.
   */
  async sweepStale(): Promise<number> {
    return this.endStale(null, this.clock.now());
  }

  // ---- Reads -----------------------------------------------------------------------------------

  private toSummary(row: RoomRow, lang: ContentLanguage): LiveRoomSummaryDto {
    return {
      id: row.id,
      title: row.title,
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
    };
  }

  private toRoom(row: RoomRow, lang: ContentLanguage): LiveRoomDto {
    return {
      ...this.toSummary(row, lang),
      status: row.status,
      endedAt: row.ended_at?.toISOString() ?? null,
      endReason: row.end_reason,
    };
  }

  private async selectRoom(roomId: string): Promise<RoomRow | null> {
    const rows = await this.prisma.$queryRaw<RoomRow[]>`${ROOM_SELECT} WHERE r.id = ${roomId}::uuid`;
    return rows[0] ?? null;
  }

  /**
   * `GET /live/rooms` (§10.4): LIVE, fresh, ACTIVE host; keyset pagination with a signed cursor.
   * Stale rooms are ended first (read path, §10.2), so a page never contains one.
   */
  async listRooms(
    callerId: string,
    query: ListLiveRoomsQuery,
    lang: ContentLanguage,
  ): Promise<LiveRoomPageDto> {
    const scope = cursorScope(query.tab, query.category, callerId);
    let position: CursorPosition | null = null;
    if (query.cursor !== undefined) {
      position = this.cursors.decode(query.cursor, scope);
      if (!position) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    }

    const now = this.clock.now();
    await this.endStale(null, now);

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
      data: page.map((row) => this.toSummary(row, lang)),
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
   * rooms are the same 404. A stale LIVE room is ended first and returned as ENDED.
   */
  async getRoom(roomId: string, lang: ContentLanguage): Promise<LiveRoomDto> {
    if (!isUuid(roomId)) throw notFound();
    let row = await this.selectRoom(roomId);
    if (!row || row.host_status !== 'ACTIVE') throw notFound();
    const now = this.clock.now();
    if (row.status === 'LIVE' && !this.isFresh(row.last_heartbeat_at, now)) {
      await this.endStale(Prisma.sql`id = ${roomId}::uuid`, now);
      row = await this.selectRoom(roomId);
      if (!row || row.host_status !== 'ACTIVE') throw notFound();
    }
    return this.toRoom(row, lang);
  }

  /**
   * Id of the host's LIVE room with a fresh heartbeat, else null (`PublicProfile.liveRoomId`).
   * A stale LIVE room found here is ended (read path, §10.2). The caller has already established
   * that the host is ACTIVE.
   */
  async freshLiveRoomIdOf(hostUserId: string): Promise<string | null> {
    const room = await this.prisma.liveRoom.findFirst({
      where: { hostUserId, status: 'LIVE' },
      select: { id: true, lastHeartbeatAt: true },
    });
    if (!room) return null;
    const now = this.clock.now();
    if (this.isFresh(room.lastHeartbeatAt, now)) return room.id;
    await this.endStale(Prisma.sql`id = ${room.id}::uuid`, now);
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
        await this.endStaleIn(tx, Prisma.sql`host_user_id = ${callerId}::uuid`, now);
        const room = await tx.liveRoom.create({
          data: {
            hostUserId: callerId,
            title: input.title,
            categoryId,
            startedAt: now,
            lastHeartbeatAt: now,
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
        return room.id;
      });
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
      await this.endStale(Prisma.sql`id = ${roomId}::uuid`, now);
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
      await this.endStaleIn(tx, Prisma.sql`id = ${roomId}::uuid`, now);
      const ended = await tx.$queryRaw<{ id: string }[]>`
        UPDATE live_rooms
           SET status = 'ENDED', end_reason = 'HOST_ENDED',
               ended_at = GREATEST(${ts(now)}::timestamptz, last_heartbeat_at),
               updated_at = ${ts(now)}::timestamptz
         WHERE id = ${roomId}::uuid AND host_user_id = ${callerId}::uuid AND status = 'LIVE'
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
    });
    const row = await this.selectRoom(roomId);
    if (!row) throw notFound();
    return this.toRoom(row, lang);
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
