import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import {
  APP_CONFIG,
  PK_BOOSTER_KINDS,
  type AppConfig,
  type PkBoosterKindName,
} from '../../config/app-config.js';
import { Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import { UsersService } from '../users/users.service.js';
import { TrailingThrottle } from './live-metadata.service.js';
import {
  absenceOf,
  boosterProblem,
  boosterRule,
  PK_TOPIC,
  pkIdentity,
  pkMatchOfIdentity,
  pkPoints,
  topSupportersIn,
  winnerByScore,
  type PkEndReasonName,
  type PkSideName,
} from './live-pk.js';
import {
  LIVE_TX_OPTIONS,
  LiveRoomsService,
  type RequestMeta,
  type UserSummaryDto,
} from './live-rooms.service.js';
import { isUuid, liveMediaTokenSchema } from './live.schemas.js';
import { LIVE_MEDIA_PROVIDER, type LiveMediaProvider } from './media/live-media.provider.js';

// ---- Response shapes (openapi v1.43-live, CONVENTIONS §10.58) -----------------------------------

/** `PkBoosterRule`: a booster's rule and the catalogue gift that activates it (null: none enabled). */
export interface PkBoosterRuleDto {
  kind: PkBoosterKindName;
  multiplier: number;
  durationSeconds: number;
  lastSeconds: number;
  limitPerMatch: number;
  giftCode: string | null;
}

/** `PkActiveBoost`. */
export interface PkActiveBoostDto {
  id: string;
  kind: PkBoosterKindName;
  multiplier: number;
  startsAt: string;
  endsAt: string;
  sender: UserSummaryDto | null;
}

/** `PkSupporter`. */
export interface PkSupporterDto {
  user: UserSummaryDto;
  points: number;
}

/** `PkGuest`: a guest seated in that side's live (SOLO seats 1–3, D174). */
export interface PkGuestDto {
  user: UserSummaryDto;
  seatIndex: number;
  mutedByHost: boolean;
}

/** `PkSideState`. */
export interface PkSideDto {
  roomId: string;
  host: UserSummaryDto;
  score: number;
  boost: PkActiveBoostDto | null;
  boosterUses: Record<PkBoosterKindName, number>;
  supporters: PkSupporterDto[];
  guests: PkGuestDto[];
  /** This side's host turned the opponent's sound off in their room. */
  mutesOpponent: boolean;
}

/** `PkMatch`. */
export interface PkMatchDto {
  id: string;
  source: 'INVITE' | 'RANDOM';
  status: 'BATTLE' | 'RESULT' | 'CLOSED';
  startedAt: string;
  battleEndsAt: string;
  endedAt: string | null;
  resultEndsAt: string | null;
  endReason: PkEndReasonName | null;
  /** Null for a draw, a void match or while the battle runs. */
  winnerRoomId: string | null;
  /** The room whose host forfeited, disconnected or stayed away. */
  loserCauseRoomId: string | null;
  seq: number;
  serverTime: string;
  /** Side A (the inviter, or the host who waited longest) first. */
  sides: [PkSideDto, PkSideDto];
  boosters: PkBoosterRuleDto[];
}

/** `PkInvite`. */
export interface PkInviteDto {
  id: string;
  status: 'PENDING' | 'ACCEPTED' | 'DECLINED' | 'CANCELLED' | 'EXPIRED';
  fromRoomId: string;
  toRoomId: string;
  from: UserSummaryDto;
  to: UserSummaryDto;
  createdAt: string;
  expiresAt: string;
  matchId: string | null;
}

/** `PkState`: what a room's screen needs (the host also gets its invitation, queue and switch). */
export interface PkStateDto {
  match: PkMatchDto | null;
  invite: PkInviteDto | null;
  queue: { joinedAt: string; expiresAt: string } | null;
  invitesEnabled: boolean | null;
}

/** `PkCandidate`: a host live now who may be invited. */
export interface PkCandidateDto {
  roomId: string;
  title: string;
  viewerCount: number;
  host: UserSummaryDto;
}

/** `PkRandomResult`. */
export interface PkRandomResultDto {
  status: 'WAITING' | 'MATCHED';
  queue: { joinedAt: string; expiresAt: string } | null;
  match: PkMatchDto | null;
}

/** `PkMediaAccess`: a watch-only token for the OTHER room of the match. */
export interface PkMediaAccessDto {
  url: string;
  token: string;
  expiresAt: string;
  roomId: string;
  identity: string;
  /** The other room's host identity (their user id) in that media room. */
  hostIdentity: string;
}

/** `PkHostRecord`. */
export interface PkHostRecordDto {
  wins: number;
  losses: number;
  draws: number;
}

/** `PkHistoryItem`: one finished match from the host's side. */
export interface PkHistoryItemDto {
  id: string;
  result: 'WIN' | 'LOSS' | 'DRAW' | 'VOID';
  endReason: PkEndReasonName;
  score: number;
  opponentScore: number;
  opponent: UserSummaryDto;
  startedAt: string;
  durationSeconds: number;
  supporters: PkSupporterDto[];
}

/** `PkHostProfile`. */
export interface PkHostProfileDto {
  record: PkHostRecordDto;
  recent: PkHistoryItemDto[];
}

/** The data message of topic `pk` (both rooms). */
export interface PkMatchData {
  readonly type: 'pk-match';
  readonly event: 'started' | 'score' | 'boost' | 'ended' | 'closed' | 'mute';
  readonly match: PkMatchDto;
  /** `boost`: the side (room id) and booster that just started (the «فعّل فريق X تربل ×5!» line). */
  readonly boost?: { roomId: string; kind: PkBoosterKindName; multiplier: number; endsAt: string };
}

/** The data message of topic `pk` to one host: an invitation for them, or one of theirs that changed. */
export interface PkInviteData {
  readonly type: 'pk-invite';
  readonly invite: PkInviteDto;
}

/** The data message of topic `pk` to a host whose random-queue wait ran out. */
export interface PkQueueData {
  readonly type: 'pk-queue';
  readonly status: 'EXPIRED';
}

// ---- Request bodies ----------------------------------------------------------------------------

const inviteSchema = z.strictObject({ toRoomId: z.uuid() });
const muteSchema = z.strictObject({ muted: z.boolean() });
const settingsSchema = z.strictObject({ invitesEnabled: z.boolean() });
const candidatesQuerySchema = z.object({
  q: z.string().trim().max(30).optional(),
  limit: z
    .string()
    .regex(/^\d{1,3}$/)
    .transform(Number)
    .pipe(z.number().int().min(1).max(50))
    .optional(),
});

// ---- Internal rows -----------------------------------------------------------------------------

interface MatchRow {
  id: string;
  source: 'INVITE' | 'RANDOM';
  status: 'BATTLE' | 'RESULT' | 'CLOSED';
  room_a_id: string;
  host_a_id: string;
  room_b_id: string;
  host_b_id: string;
  score_a: bigint;
  score_b: bigint;
  started_at: Date;
  battle_ends_at: Date;
  ended_at: Date | null;
  result_ends_at: Date | null;
  end_reason: PkEndReasonName | null;
  winner: PkSideName | null;
  loser_cause: PkSideName | null;
  a_mutes_b: boolean;
  b_mutes_a: boolean;
  seq: number;
  top_a: { userId: string; points: number }[] | null;
  top_b: { userId: string; points: number }[] | null;
}

const MATCH_COLUMNS = `id::text AS id, source::text AS source, status::text AS status,
  room_a_id::text AS room_a_id, host_a_id::text AS host_a_id, room_b_id::text AS room_b_id,
  host_b_id::text AS host_b_id, score_a, score_b, started_at, battle_ends_at, ended_at, result_ends_at,
  end_reason::text AS end_reason, winner::text AS winner, loser_cause::text AS loser_cause,
  a_mutes_b, b_mutes_a, seq, top_a, top_b`;

interface RoomState {
  id: string;
  host_user_id: string;
  status: 'LIVE' | 'ENDED';
  mode: string;
  end_reason: string | null;
  last_heartbeat_at: Date;
  host_away_since: Date | null;
}

/** The match result as the tick or a host decides it. */
interface Finish {
  readonly reason: PkEndReasonName;
  /** The side that forfeited, disconnected or stayed away; null with TIME; `both` when both did. */
  readonly loser: PkSideName | 'both' | null;
}

/** What a gift send in a room during a PK battle did (for the send's post-commit messages). */
export interface PkGiftCredit {
  readonly matchId: string;
  readonly boosted: {
    side: PkSideName;
    roomId: string;
    kind: PkBoosterKindName;
    multiplier: number;
    endsAt: Date;
  } | null;
}

function iso(d: Date): string {
  return d.toISOString();
}

function otherSide(side: PkSideName): PkSideName {
  return side === 'A' ? 'B' : 'A';
}

/**
 * PK 1 v 1 (v1.43-live, D195, CONVENTIONS §10.58, CP-038): two hosts of SOLO video lives battle for
 * PK_BATTLE_SECONDS. A host invites another live host (PK_INVITE_TTL_SECONDS to answer, a cooldown,
 * a switch to refuse invitations) or waits in the random queue; the match is server-authoritative
 * (scores, boosters, ends, the result phase) and reaches both rooms as `pk` data messages, with
 * `GET /live/rooms/{roomId}/pk` as the snapshot after a reconnect. The viewers (and the host) of each
 * room watch the other room's host with a watch-only, hidden token for that room (identity
 * `pk:<matchId>:<identity>`): each room keeps its own chat, gifts and seats. PK points are the coin
 * value of the gifts sent in each room during the battle × that side's booster; they never change
 * money, cherries, live scores, rankings, charm or levels.
 */
@Injectable()
export class LivePkService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(LivePkService.name);
  private readonly scoreThrottle: TrailingThrottle;
  private tickTimer: NodeJS.Timeout | undefined;
  private tickInFlight: Promise<unknown> | null = null;
  private stopped = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly rooms: LiveRoomsService,
    private readonly users: UsersService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    @Inject(LIVE_MEDIA_PROVIDER) private readonly media: LiveMediaProvider,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    this.scoreThrottle = new TrailingThrottle(
      config.pk.scoreBroadcastMs,
      () => this.clock.now().getTime(),
      async (matchId) => {
        await this.broadcastMatch(matchId, 'score');
      },
    );
  }

  onModuleInit(): void {
    if (this.config.pk.tickMs > 0) this.scheduleTick();
  }

  async onModuleDestroy(): Promise<void> {
    this.stopped = true;
    if (this.tickTimer) clearTimeout(this.tickTimer);
    await this.tickInFlight?.catch(() => undefined);
    await this.scoreThrottle.stop();
  }

  private scheduleTick(): void {
    if (this.stopped) return;
    this.tickTimer = setTimeout(() => {
      this.tickInFlight = this.tick()
        .catch((err: unknown) => this.logger.warn({ error: safeErrorLog(err) }, 'PK tick failed'))
        .finally(() => {
          this.tickInFlight = null;
          this.scheduleTick();
        });
    }, this.config.pk.tickMs);
    this.tickTimer.unref();
  }

  // ---- Checks ----------------------------------------------------------------------------------

  private assertPkOn(): void {
    if (!this.config.live.hostingEnabled) throw new AppException(ErrorCode.LIVE_HOSTING_UNAVAILABLE);
    if (!this.config.pk.enabled) throw new AppException(ErrorCode.PK_UNAVAILABLE);
  }

  private staleCutoff(now: Date): Date {
    return new Date(now.getTime() - this.config.live.heartbeatStaleSeconds * 1000);
  }

  private async roomState(
    db: Prisma.TransactionClient | PrismaService,
    roomId: string,
  ): Promise<RoomState | null> {
    const [row] = await db.$queryRaw<RoomState[]>`
      SELECT id::text AS id, host_user_id::text AS host_user_id, status::text AS status, mode::text AS mode,
             end_reason::text AS end_reason, last_heartbeat_at, host_away_since
        FROM live_rooms WHERE id = ${roomId}::uuid`;
    return row ?? null;
  }

  /** A room that may start a PK now: LIVE, a SOLO video live, a fresh heartbeat, the host present. */
  private eligible(room: RoomState | null, now: Date): boolean {
    return (
      room !== null &&
      room.status === 'LIVE' &&
      room.mode === 'SOLO' &&
      room.last_heartbeat_at.getTime() > this.staleCutoff(now).getTime() &&
      room.host_away_since === null
    );
  }

  /** The caller's own room (404 otherwise), eligible for a PK (409 PK_UNAVAILABLE otherwise). */
  private async ownEligibleRoom(callerId: string, roomId: string, now: Date): Promise<RoomState> {
    if (!isUuid(roomId)) throw new AppException(ErrorCode.NOT_FOUND);
    const room = await this.roomState(this.prisma, roomId.toLowerCase());
    if (!room || room.host_user_id !== callerId) throw new AppException(ErrorCode.NOT_FOUND);
    if (room.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    if (!this.eligible(room, now)) throw new AppException(ErrorCode.PK_UNAVAILABLE);
    return room;
  }

  /** The caller's own LIVE room (404 / 409 LIVE_ROOM_ENDED). */
  private async ownRoom(callerId: string, roomId: string): Promise<RoomState> {
    if (!isUuid(roomId)) throw new AppException(ErrorCode.NOT_FOUND);
    const room = await this.roomState(this.prisma, roomId.toLowerCase());
    if (!room || room.host_user_id !== callerId) throw new AppException(ErrorCode.NOT_FOUND);
    return room;
  }

  /** A block either way between two users. */
  private async blocked(
    db: Prisma.TransactionClient | PrismaService,
    a: string,
    b: string,
  ): Promise<boolean> {
    const [row] = await db.$queryRaw<{ blocked: boolean }[]>`
      SELECT EXISTS (SELECT 1 FROM user_blocks
                      WHERE (blocker_id = ${a}::uuid AND blocked_id = ${b}::uuid)
                         OR (blocker_id = ${b}::uuid AND blocked_id = ${a}::uuid)) AS blocked`;
    return row?.blocked ?? false;
  }

  /** Takes the PK locks of rooms (sorted, so two requests never wait on each other in reverse). */
  private async lockRooms(tx: Prisma.TransactionClient, roomIds: readonly string[]): Promise<void> {
    for (const id of [...new Set(roomIds)].sort()) {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`pk-room:${id}`}, 0))`;
    }
  }

  /**
   * Whether a room or its host is busy: a BATTLE / RESULT match, an open invitation either way (an
   * expired one is closed here first) or the host in the random queue. Under the rooms' PK locks.
   */
  private async busyIn(
    tx: Prisma.TransactionClient,
    roomId: string,
    hostId: string,
    now: Date,
  ): Promise<boolean> {
    await tx.$executeRaw`
      UPDATE pk_invites SET status = 'EXPIRED', handled_at = expires_at
       WHERE status = 'PENDING' AND expires_at <= ${iso(now)}::timestamptz
         AND (from_room_id = ${roomId}::uuid OR to_room_id = ${roomId}::uuid)`;
    const [row] = await tx.$queryRaw<{ busy: boolean }[]>`
      SELECT EXISTS (SELECT 1 FROM pk_matches WHERE status <> 'CLOSED'
                        AND (room_a_id = ${roomId}::uuid OR room_b_id = ${roomId}::uuid))
          OR EXISTS (SELECT 1 FROM pk_invites WHERE status = 'PENDING'
                        AND (from_room_id = ${roomId}::uuid OR to_room_id = ${roomId}::uuid))
          OR EXISTS (SELECT 1 FROM pk_queue WHERE host_id = ${hostId}::uuid AND expires_at > ${iso(now)}::timestamptz)
          AS busy`;
    return row?.busy ?? false;
  }

  // ---- Reads -----------------------------------------------------------------------------------

  private async summaries(ids: readonly string[]): Promise<Map<string, UserSummaryDto>> {
    const unique = [...new Set(ids)];
    if (unique.length === 0) return new Map();
    const rows = await this.prisma.user.findMany({
      where: { id: { in: unique } },
      select: USER_SUMMARY_SELECT,
    });
    return new Map(rows.map((r) => [r.id, userSummary(r)]));
  }

  private async selectMatch(
    db: Prisma.TransactionClient | PrismaService,
    where: Prisma.Sql,
    lock = false,
  ): Promise<MatchRow | null> {
    const [row] = await db.$queryRaw<MatchRow[]>(
      Prisma.sql`SELECT ${Prisma.raw(MATCH_COLUMNS)} FROM pk_matches WHERE ${where} ${lock ? Prisma.raw('FOR UPDATE') : Prisma.empty}`,
    );
    return row ?? null;
  }

  /** The room's BATTLE or RESULT match, or null. */
  private async openMatchOfRoom(
    db: Prisma.TransactionClient | PrismaService,
    roomId: string,
  ): Promise<MatchRow | null> {
    return this.selectMatch(
      db,
      Prisma.sql`status <> 'CLOSED' AND (room_a_id = ${roomId}::uuid OR room_b_id = ${roomId}::uuid)`,
    );
  }

  /** The booster rules with the enabled catalogue gift of each (lowest sort order first). */
  private async boosterRules(): Promise<PkBoosterRuleDto[]> {
    const gifts = await this.prisma.gift.findMany({
      where: { enabled: true, pkBooster: { not: null } },
      orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }],
      select: { code: true, pkBooster: true },
    });
    return this.config.pk.boosters.map((rule) => ({
      kind: rule.kind,
      multiplier: rule.multiplier,
      durationSeconds: rule.durationSeconds,
      lastSeconds: rule.lastSeconds,
      limitPerMatch: rule.limitPerMatch,
      giftCode: gifts.find((g) => g.pkBooster === rule.kind)?.code ?? null,
    }));
  }

  /** The full match as both rooms see it. */
  async matchDto(row: MatchRow): Promise<PkMatchDto> {
    const now = this.clock.now();
    const [boosts, uses, supporters, guests, rules] = await Promise.all([
      this.prisma.$queryRaw<
        {
          id: string;
          side: PkSideName;
          kind: PkBoosterKindName;
          multiplier: number;
          starts_at: Date;
          ends_at: Date;
          sender_id: string;
        }[]
      >`
        SELECT DISTINCT ON (side) id::text AS id, side::text AS side, kind::text AS kind, multiplier, starts_at, ends_at,
               sender_id::text AS sender_id
          FROM pk_boosts
         WHERE match_id = ${row.id}::uuid AND starts_at <= ${iso(now)}::timestamptz AND ends_at > ${iso(now)}::timestamptz
           AND ${row.status === 'BATTLE'}
         ORDER BY side, multiplier DESC`,
      this.prisma.$queryRaw<{ side: PkSideName; kind: PkBoosterKindName; n: number }[]>`
        SELECT side::text AS side, kind::text AS kind, count(*)::int AS n FROM pk_boosts
         WHERE match_id = ${row.id}::uuid GROUP BY side, kind`,
      row.status === 'BATTLE' || row.top_a === null || row.top_b === null
        ? this.prisma.$transaction((tx) => topSupportersIn(tx, row.id))
        : Promise.resolve({ A: row.top_a, B: row.top_b }),
      this.prisma.$queryRaw<
        { room_id: string; user_id: string; seat_index: number; muted_by_host: boolean }[]
      >`
        SELECT room_id::text AS room_id, user_id::text AS user_id, seat_index, muted_by_host
          FROM live_room_seats
         WHERE room_id IN (${row.room_a_id}::uuid, ${row.room_b_id}::uuid) AND user_id IS NOT NULL
         ORDER BY seat_index`,
      this.boosterRules(),
    ]);
    const people = await this.summaries([
      row.host_a_id,
      row.host_b_id,
      ...boosts.map((b) => b.sender_id),
      ...supporters.A.map((s) => s.userId),
      ...supporters.B.map((s) => s.userId),
      ...guests.map((g) => g.user_id),
    ]);
    const side = (s: PkSideName): PkSideDto => {
      const roomId = s === 'A' ? row.room_a_id : row.room_b_id;
      const boost = boosts.find((b) => b.side === s);
      const counts = Object.fromEntries(PK_BOOSTER_KINDS.map((k) => [k, 0])) as Record<
        PkBoosterKindName,
        number
      >;
      for (const u of uses) if (u.side === s) counts[u.kind] = u.n;
      return {
        roomId,
        host: people.get(s === 'A' ? row.host_a_id : row.host_b_id)!,
        score: Number(s === 'A' ? row.score_a : row.score_b),
        boost: boost
          ? {
              id: boost.id,
              kind: boost.kind,
              multiplier: boost.multiplier,
              startsAt: iso(boost.starts_at),
              endsAt: iso(boost.ends_at),
              sender: people.get(boost.sender_id) ?? null,
            }
          : null,
        boosterUses: counts,
        supporters: supporters[s]
          .filter((p) => people.has(p.userId))
          .map((p) => ({ user: people.get(p.userId)!, points: p.points })),
        guests: guests
          .filter((g) => g.room_id === roomId && people.has(g.user_id))
          .slice(0, 3)
          .map((g) => ({
            user: people.get(g.user_id)!,
            seatIndex: g.seat_index,
            mutedByHost: g.muted_by_host,
          })),
        mutesOpponent: s === 'A' ? row.a_mutes_b : row.b_mutes_a,
      };
    };
    const roomOf = (s: PkSideName | null) => (s === null ? null : s === 'A' ? row.room_a_id : row.room_b_id);
    return {
      id: row.id,
      source: row.source,
      status: row.status,
      startedAt: iso(row.started_at),
      battleEndsAt: iso(row.battle_ends_at),
      endedAt: row.ended_at ? iso(row.ended_at) : null,
      resultEndsAt: row.result_ends_at ? iso(row.result_ends_at) : null,
      endReason: row.end_reason,
      winnerRoomId: roomOf(row.winner),
      loserCauseRoomId: roomOf(row.loser_cause),
      seq: row.seq,
      serverTime: iso(now),
      sides: [side('A'), side('B')],
      boosters: rules,
    };
  }

  private async inviteDto(id: string): Promise<PkInviteDto | null> {
    const invite = await this.prisma.pkInvite.findUnique({ where: { id } });
    if (!invite) return null;
    const people = await this.summaries([invite.fromHostId, invite.toHostId]);
    return {
      id: invite.id,
      status: invite.status,
      fromRoomId: invite.fromRoomId,
      toRoomId: invite.toRoomId,
      from: people.get(invite.fromHostId)!,
      to: people.get(invite.toHostId)!,
      createdAt: iso(invite.createdAt),
      expiresAt: iso(invite.expiresAt),
      matchId: invite.matchId,
    };
  }

  /**
   * `GET /live/rooms/{roomId}/pk`: anyone who may watch the room (guests while it allows them; not
   * kicked out). The room's BATTLE / RESULT match, else null. Its host also gets their open
   * invitation (either way), their random-queue wait and their invitation switch.
   */
  async state(callerId: string | null, roomId: string): Promise<PkStateDto> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (callerId === null && !row.allow_guests) throw new AppException(ErrorCode.LIVE_GUESTS_NOT_ALLOWED);
    if (row.kicked) throw new AppException(ErrorCode.LIVE_KICKED);
    const match = await this.openMatchOfRoom(this.prisma, row.id);
    const isHost = callerId !== null && callerId === row.host_user_id;
    if (!isHost) {
      return {
        match: match ? await this.matchDto(match) : null,
        invite: null,
        queue: null,
        invitesEnabled: null,
      };
    }
    const now = this.clock.now();
    const [invite, queue, settings] = await Promise.all([
      this.prisma.pkInvite.findFirst({
        where: {
          status: 'PENDING',
          expiresAt: { gt: now },
          OR: [{ fromRoomId: row.id }, { toRoomId: row.id }],
        },
        select: { id: true },
      }),
      this.prisma.pkQueueEntry.findFirst({
        where: { hostId: callerId, roomId: row.id, expiresAt: { gt: now } },
      }),
      this.prisma.pkHostSettings.findUnique({ where: { hostId: callerId } }),
    ]);
    return {
      match: match ? await this.matchDto(match) : null,
      invite: invite ? await this.inviteDto(invite.id) : null,
      queue: queue ? { joinedAt: iso(queue.joinedAt), expiresAt: iso(queue.expiresAt) } : null,
      invitesEnabled: settings?.invitesEnabled ?? true,
    };
  }

  /**
   * `GET /live/rooms/{roomId}/pk/candidates`: hosts live now whom the caller (this room's host) may
   * invite — SOLO video lives with a fresh heartbeat, present, invitations on, not busy, no block
   * either way. `q` matches the start of the username or any part of the display name; without it,
   * the busiest lives first (suggestions).
   */
  async candidates(callerId: string, roomId: string, query: unknown): Promise<{ data: PkCandidateDto[] }> {
    this.assertPkOn();
    await this.ownRoom(callerId, roomId);
    const parsed = candidatesQuerySchema.safeParse(query ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const q = parsed.data.q?.toLowerCase().replace(/[\\%_]/g, (c) => `\\${c}`) ?? '';
    const limit = parsed.data.limit ?? 20;
    const now = this.clock.now();
    const rows = await this.prisma.$queryRaw<
      { id: string; host_user_id: string; title: string; viewer_count: number }[]
    >`
      SELECT r.id::text AS id, r.host_user_id::text AS host_user_id, r.title, r.viewer_count
        FROM live_rooms r
        JOIN users u ON u.id = r.host_user_id AND u.status = 'ACTIVE'::user_status
        JOIN user_profiles p ON p.user_id = r.host_user_id
        LEFT JOIN pk_host_settings s ON s.host_id = r.host_user_id
       WHERE r.status = 'LIVE' AND r.mode = 'SOLO'::live_room_mode
         AND r.last_heartbeat_at > ${iso(this.staleCutoff(now))}::timestamptz AND r.host_away_since IS NULL
         AND r.host_user_id <> ${callerId}::uuid AND COALESCE(s.invites_enabled, true)
         AND NOT EXISTS (SELECT 1 FROM user_blocks b
                          WHERE (b.blocker_id = ${callerId}::uuid AND b.blocked_id = r.host_user_id)
                             OR (b.blocker_id = r.host_user_id AND b.blocked_id = ${callerId}::uuid))
         AND NOT EXISTS (SELECT 1 FROM pk_matches m WHERE m.status <> 'CLOSED'
                          AND (m.room_a_id = r.id OR m.room_b_id = r.id))
         AND NOT EXISTS (SELECT 1 FROM pk_invites i WHERE i.status = 'PENDING'
                          AND i.expires_at > ${iso(now)}::timestamptz
                          AND (i.from_room_id = r.id OR i.to_room_id = r.id))
         AND NOT EXISTS (SELECT 1 FROM pk_queue w WHERE w.host_id = r.host_user_id
                          AND w.expires_at > ${iso(now)}::timestamptz)
         AND (${q} = '' OR lower(p.username) LIKE ${q} || '%' OR lower(p.display_name) LIKE '%' || ${q} || '%')
       ORDER BY r.viewer_count DESC, r.score DESC, r.started_at DESC, r.id DESC
       LIMIT ${limit}`;
    const people = await this.summaries(rows.map((r) => r.host_user_id));
    return {
      data: rows
        .filter((r) => people.has(r.host_user_id))
        .map((r) => ({
          roomId: r.id,
          title: r.title,
          viewerCount: r.viewer_count,
          host: people.get(r.host_user_id)!,
        })),
    };
  }

  // ---- Invitations -----------------------------------------------------------------------------

  /**
   * `POST /live/rooms/{roomId}/pk/invites` `{toRoomId}` (201): checks after the auth guard and the
   * rate limit — PK on (503 / 409 PK_UNAVAILABLE), the body (400), the caller's own room (404, 409
   * LIVE_ROOM_ENDED, 409 PK_UNAVAILABLE), the other room visible to the caller (404; a block either
   * way too) and eligible (409 PK_UNAVAILABLE), its host's switch (409 PK_INVITES_OFF), the cooldown
   * (409 PK_INVITE_COOLDOWN, Retry-After), then under both rooms' PK locks: neither busy (409
   * PK_HOST_BUSY). The invited host gets a `pk-invite` data message.
   */
  async invite(callerId: string, roomId: string, body: unknown): Promise<PkInviteDto> {
    this.assertPkOn();
    const parsed = inviteSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const now = this.clock.now();
    const own = await this.ownEligibleRoom(callerId, roomId, now);
    const targetRow = await this.rooms.visibleRow(parsed.data.toRoomId, callerId);
    if (targetRow.host_user_id === callerId)
      throw AppException.validation([{ field: 'toRoomId', issue: 'invalid_value' }]);
    const target = await this.roomState(this.prisma, targetRow.id);
    if (!this.eligible(target, now)) throw new AppException(ErrorCode.PK_UNAVAILABLE);
    if (await this.blocked(this.prisma, callerId, targetRow.host_user_id))
      throw new AppException(ErrorCode.NOT_FOUND);
    const settings = await this.prisma.pkHostSettings.findUnique({
      where: { hostId: targetRow.host_user_id },
    });
    if (settings && !settings.invitesEnabled) throw new AppException(ErrorCode.PK_INVITES_OFF);
    const cooldown = this.config.pk.inviteCooldownSeconds;
    if (cooldown > 0) {
      const last = await this.prisma.pkInvite.findFirst({
        where: { fromHostId: callerId },
        orderBy: { createdAt: 'desc' },
        select: { createdAt: true },
      });
      const wait = last ? Math.ceil((last.createdAt.getTime() + cooldown * 1000 - now.getTime()) / 1000) : 0;
      if (wait > 0) {
        throw new AppException(ErrorCode.PK_INVITE_COOLDOWN, undefined, undefined, {
          'Retry-After': String(wait),
        });
      }
    }
    const id = uuidv7();
    await this.prisma.$transaction(async (tx) => {
      await this.lockRooms(tx, [own.id, targetRow.id]);
      if (
        (await this.busyIn(tx, own.id, callerId, now)) ||
        (await this.busyIn(tx, targetRow.id, targetRow.host_user_id, now))
      ) {
        throw new AppException(ErrorCode.PK_HOST_BUSY);
      }
      await tx.pkInvite.create({
        data: {
          id,
          fromRoomId: own.id,
          fromHostId: callerId,
          toRoomId: targetRow.id,
          toHostId: targetRow.host_user_id,
          createdAt: now,
          expiresAt: new Date(now.getTime() + this.config.pk.inviteTtlSeconds * 1000),
        },
      });
    }, LIVE_TX_OPTIONS);
    const dto = (await this.inviteDto(id))!;
    await this.tellInvite(dto, 'to');
    return dto;
  }

  /** Sends a `pk-invite` message to the invited host (`to`), the inviter (`from`) or both. */
  private async tellInvite(invite: PkInviteDto, who: 'to' | 'from' | 'both'): Promise<void> {
    const payload = JSON.stringify({ type: 'pk-invite', invite } satisfies PkInviteData);
    const targets: [string, string][] = [];
    if (who !== 'from') targets.push([invite.toRoomId, invite.to.id]);
    if (who !== 'to') targets.push([invite.fromRoomId, invite.from.id]);
    for (const [room, identity] of targets) {
      try {
        await this.media.sendData(room, identity, payload);
      } catch (err) {
        this.logger.warn({ error: safeErrorLog(err) }, 'Could not send a PK invitation data message');
      }
    }
  }

  private async pendingInvite(
    tx: Prisma.TransactionClient,
    inviteId: string,
    roomId: string,
    side: 'from' | 'to',
    now: Date,
  ): Promise<{
    id: string;
    from_room_id: string;
    from_host_id: string;
    to_room_id: string;
    to_host_id: string;
  }> {
    if (!isUuid(inviteId)) throw new AppException(ErrorCode.NOT_FOUND);
    const [invite] = await tx.$queryRaw<
      {
        id: string;
        status: string;
        expires_at: Date;
        from_room_id: string;
        from_host_id: string;
        to_room_id: string;
        to_host_id: string;
      }[]
    >`
      SELECT id::text AS id, status::text AS status, expires_at, from_room_id::text AS from_room_id,
             from_host_id::text AS from_host_id, to_room_id::text AS to_room_id, to_host_id::text AS to_host_id
        FROM pk_invites WHERE id = ${inviteId}::uuid FOR UPDATE`;
    if (!invite || (side === 'to' ? invite.to_room_id : invite.from_room_id) !== roomId) {
      throw new AppException(ErrorCode.NOT_FOUND);
    }
    if (invite.status === 'PENDING' && invite.expires_at.getTime() <= now.getTime()) {
      await tx.$executeRaw`UPDATE pk_invites SET status = 'EXPIRED', handled_at = expires_at WHERE id = ${invite.id}::uuid`;
      throw new AppException(ErrorCode.PK_INVITE_CLOSED);
    }
    if (invite.status !== 'PENDING') throw new AppException(ErrorCode.PK_INVITE_CLOSED);
    return invite;
  }

  /**
   * `POST /live/rooms/{roomId}/pk/invites/{inviteId}/accept`: the invited host (their room in the
   * path; anyone else 404). Open (409 PK_INVITE_CLOSED: answered, cancelled or expired), both rooms
   * still eligible (409 PK_UNAVAILABLE; the invitation is cancelled) and no block → the match starts
   * (BATTLE for PK_BATTLE_SECONDS), both rooms get `pk-match` `started`.
   */
  async accept(callerId: string, roomId: string, inviteId: string): Promise<PkMatchDto> {
    this.assertPkOn();
    const room = await this.ownRoom(callerId, roomId);
    const now = this.clock.now();
    let matchId: string | null = null;
    const outcome: { refused: AppException | null } = { refused: null };
    const inviteKey = inviteId.toLowerCase();
    const inviteRow = isUuid(inviteId)
      ? await this.prisma.pkInvite.findUnique({ where: { id: inviteKey }, select: { fromRoomId: true } })
      : null;
    await this.prisma.$transaction(async (tx) => {
      await this.lockRooms(tx, [room.id, ...(inviteRow ? [inviteRow.fromRoomId] : [])]);
      const invite = await this.pendingInvite(tx, inviteKey, room.id, 'to', now);
      const from = await this.roomState(tx, invite.from_room_id);
      const to = await this.roomState(tx, invite.to_room_id);
      if (
        !this.eligible(from, now) ||
        !this.eligible(to, now) ||
        (await this.blocked(tx, invite.from_host_id, callerId))
      ) {
        await tx.$executeRaw`UPDATE pk_invites SET status = 'CANCELLED', handled_at = ${iso(now)}::timestamptz WHERE id = ${invite.id}::uuid`;
        outcome.refused = new AppException(ErrorCode.PK_UNAVAILABLE);
        return;
      }
      matchId = await this.createMatchIn(tx, {
        source: 'INVITE',
        roomA: invite.from_room_id,
        hostA: invite.from_host_id,
        roomB: invite.to_room_id,
        hostB: invite.to_host_id,
        now,
        inviteId: invite.id,
      });
      if (matchId === null) {
        await tx.$executeRaw`UPDATE pk_invites SET status = 'CANCELLED', handled_at = ${iso(now)}::timestamptz WHERE id = ${invite.id}::uuid`;
        outcome.refused = new AppException(ErrorCode.PK_HOST_BUSY);
      }
    }, LIVE_TX_OPTIONS);
    const invite = await this.inviteDto(inviteKey);
    if (invite) await this.tellInvite(invite, 'from');
    if (outcome.refused) throw outcome.refused;
    return this.started(matchId!);
  }

  /** `…/decline`: the invited host; 409 PK_INVITE_CLOSED when it is no longer open. */
  async decline(callerId: string, roomId: string, inviteId: string): Promise<void> {
    const room = await this.ownRoom(callerId, roomId);
    await this.closeInvite(room.id, inviteId, 'to', 'DECLINED');
  }

  /** `DELETE /live/rooms/{roomId}/pk/invites/{inviteId}`: the inviter takes it back. */
  async cancel(callerId: string, roomId: string, inviteId: string): Promise<void> {
    const room = await this.ownRoom(callerId, roomId);
    await this.closeInvite(room.id, inviteId, 'from', 'CANCELLED');
  }

  private async closeInvite(
    roomId: string,
    inviteId: string,
    side: 'from' | 'to',
    status: 'DECLINED' | 'CANCELLED',
  ): Promise<void> {
    const now = this.clock.now();
    const key = inviteId.toLowerCase();
    const outcome: { closed: AppException | null } = { closed: null };
    await this.prisma.$transaction(async (tx) => {
      try {
        const invite = await this.pendingInvite(tx, key, roomId, side, now);
        await tx.$executeRaw`
          UPDATE pk_invites SET status = ${status}::pk_invite_status, handled_at = ${iso(now)}::timestamptz
           WHERE id = ${invite.id}::uuid`;
      } catch (err) {
        // An expiry found here is stored (the transaction commits), then reported.
        if (err instanceof AppException && err.code === ErrorCode.PK_INVITE_CLOSED) outcome.closed = err;
        else throw err;
      }
    }, LIVE_TX_OPTIONS);
    if (outcome.closed) throw outcome.closed;
    const dto = await this.inviteDto(key);
    if (dto) await this.tellInvite(dto, side === 'to' ? 'from' : 'to');
  }

  // ---- The random queue ------------------------------------------------------------------------

  /**
   * `POST /live/rooms/{roomId}/pk/random` «مطابقة عشوائية»: the caller's eligible room (as for an
   * invitation) joins the queue. Pairing is serialized (one PK queue lock): the host who waited
   * longest, with an eligible room, not busy and no block either way, is paired at once (`MATCHED`,
   * they are side A); otherwise the caller waits up to PK_RANDOM_WAIT_SECONDS (`WAITING`; again: the
   * same wait). Busy otherwise (a match or an open invitation) → 409 PK_HOST_BUSY.
   */
  async joinRandom(callerId: string, roomId: string): Promise<PkRandomResultDto> {
    this.assertPkOn();
    const now = this.clock.now();
    const own = await this.ownEligibleRoom(callerId, roomId, now);
    let matched: string | null = null;
    let waiting: { joinedAt: Date; expiresAt: Date } | null = null;
    await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended('pk-queue', 0))`;
      await this.lockRooms(tx, [own.id]);
      const existing = await tx.pkQueueEntry.findUnique({ where: { hostId: callerId } });
      if (existing && existing.roomId === own.id && existing.expiresAt.getTime() > now.getTime()) {
        waiting = { joinedAt: existing.joinedAt, expiresAt: existing.expiresAt };
        return;
      }
      if (existing) await tx.pkQueueEntry.delete({ where: { hostId: callerId } });
      if (await this.busyIn(tx, own.id, callerId, now)) throw new AppException(ErrorCode.PK_HOST_BUSY);
      const partners = await tx.$queryRaw<{ host_id: string; room_id: string }[]>`
        SELECT q.host_id::text AS host_id, q.room_id::text AS room_id
          FROM pk_queue q
          JOIN live_rooms r ON r.id = q.room_id
         WHERE q.host_id <> ${callerId}::uuid AND q.expires_at > ${iso(now)}::timestamptz
           AND r.status = 'LIVE' AND r.mode = 'SOLO'::live_room_mode AND r.host_user_id = q.host_id
           AND r.last_heartbeat_at > ${iso(this.staleCutoff(now))}::timestamptz AND r.host_away_since IS NULL
           AND NOT EXISTS (SELECT 1 FROM user_blocks b
                            WHERE (b.blocker_id = ${callerId}::uuid AND b.blocked_id = q.host_id)
                               OR (b.blocker_id = q.host_id AND b.blocked_id = ${callerId}::uuid))
         ORDER BY q.joined_at, q.host_id
         LIMIT 5`;
      for (const partner of partners) {
        await this.lockRooms(tx, [partner.room_id]);
        if (await this.busyInIgnoringQueue(tx, partner.room_id, now)) continue;
        matched = await this.createMatchIn(tx, {
          source: 'RANDOM',
          roomA: partner.room_id,
          hostA: partner.host_id,
          roomB: own.id,
          hostB: callerId,
          now,
          inviteId: null,
        });
        if (matched) return;
      }
      const expiresAt = new Date(now.getTime() + this.config.pk.randomWaitSeconds * 1000);
      await tx.pkQueueEntry.create({ data: { hostId: callerId, roomId: own.id, joinedAt: now, expiresAt } });
      waiting = { joinedAt: now, expiresAt };
    }, LIVE_TX_OPTIONS);
    if (matched) return { status: 'MATCHED', queue: null, match: await this.started(matched) };
    const w = waiting as { joinedAt: Date; expiresAt: Date } | null;
    return {
      status: 'WAITING',
      queue: w ? { joinedAt: iso(w.joinedAt), expiresAt: iso(w.expiresAt) } : null,
      match: null,
    };
  }

  /** A queued room is busy only with a match or an open invitation (its own queue row is expected). */
  private async busyInIgnoringQueue(
    tx: Prisma.TransactionClient,
    roomId: string,
    now: Date,
  ): Promise<boolean> {
    const [row] = await tx.$queryRaw<{ busy: boolean }[]>`
      SELECT EXISTS (SELECT 1 FROM pk_matches WHERE status <> 'CLOSED'
                        AND (room_a_id = ${roomId}::uuid OR room_b_id = ${roomId}::uuid))
          OR EXISTS (SELECT 1 FROM pk_invites WHERE status = 'PENDING' AND expires_at > ${iso(now)}::timestamptz
                        AND (from_room_id = ${roomId}::uuid OR to_room_id = ${roomId}::uuid)) AS busy`;
    return row?.busy ?? false;
  }

  /** `DELETE /live/rooms/{roomId}/pk/random`: stops waiting (idempotent). */
  async leaveRandom(callerId: string, roomId: string): Promise<void> {
    const room = await this.ownRoom(callerId, roomId);
    await this.prisma.pkQueueEntry.deleteMany({ where: { hostId: callerId, roomId: room.id } });
  }

  // ---- Matches ---------------------------------------------------------------------------------

  /**
   * Starts a match under both rooms' PK locks (taken by the caller): null when either room is in a
   * match already (the unique indexes back this up). Both hosts leave the random queue; audited
   * `live.pk.start`.
   */
  private async createMatchIn(
    tx: Prisma.TransactionClient,
    input: {
      source: 'INVITE' | 'RANDOM';
      roomA: string;
      hostA: string;
      roomB: string;
      hostB: string;
      now: Date;
      inviteId: string | null;
    },
  ): Promise<string | null> {
    const [busy] = await tx.$queryRaw<{ busy: boolean }[]>`
      SELECT EXISTS (SELECT 1 FROM pk_matches WHERE status <> 'CLOSED'
                      AND (room_a_id IN (${input.roomA}::uuid, ${input.roomB}::uuid)
                        OR room_b_id IN (${input.roomA}::uuid, ${input.roomB}::uuid))) AS busy`;
    if (busy?.busy) return null;
    const id = uuidv7();
    await tx.pkMatch.create({
      data: {
        id,
        source: input.source,
        roomAId: input.roomA,
        hostAId: input.hostA,
        roomBId: input.roomB,
        hostBId: input.hostB,
        startedAt: input.now,
        battleEndsAt: new Date(input.now.getTime() + this.config.pk.battleSeconds * 1000),
        seq: 1,
      },
    });
    if (input.inviteId) {
      await tx.$executeRaw`
        UPDATE pk_invites SET status = 'ACCEPTED', handled_at = ${iso(input.now)}::timestamptz, match_id = ${id}::uuid
         WHERE id = ${input.inviteId}::uuid`;
    }
    await tx.pkQueueEntry.deleteMany({ where: { hostId: { in: [input.hostA, input.hostB] } } });
    await this.audit.recordIn(tx, {
      action: AuditAction.LIVE_PK_START,
      actorUserId: input.hostB,
      targetType: 'pk_match',
      targetId: id,
      metadata: { source: input.source, roomA: input.roomA, roomB: input.roomB, hostA: input.hostA },
    });
    return id;
  }

  private async started(matchId: string): Promise<PkMatchDto> {
    const dto = await this.broadcastMatch(matchId, 'started');
    return dto!;
  }

  /**
   * `POST /live/rooms/{roomId}/pk/end`: the host ends early. During the battle it is a forfeit (the
   * opponent wins, the result phase starts); during the result phase it closes the PK for both
   * rooms. No match → 409 PK_NOT_ACTIVE.
   */
  async end(callerId: string, roomId: string): Promise<PkMatchDto> {
    const room = await this.ownRoom(callerId, roomId);
    const match = await this.openMatchOfRoom(this.prisma, room.id);
    if (!match) throw new AppException(ErrorCode.PK_NOT_ACTIVE);
    const side: PkSideName = match.room_a_id === room.id ? 'A' : 'B';
    if (match.status === 'BATTLE') {
      await this.finishBattle(match.id, { reason: 'FORFEIT', loser: side }, callerId);
    } else {
      await this.closeResult(match.id);
    }
    const row = await this.selectMatch(this.prisma, Prisma.sql`id = ${match.id}::uuid`);
    return this.matchDto(row!);
  }

  /**
   * `POST /live/rooms/{roomId}/pk/mute-opponent` `{muted}`: the host turns the opponent's sound off
   * (or on) in their own room — for them and their viewers; the other room is unchanged.
   */
  async muteOpponent(callerId: string, roomId: string, body: unknown): Promise<PkMatchDto> {
    const parsed = muteSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const room = await this.ownRoom(callerId, roomId);
    const match = await this.openMatchOfRoom(this.prisma, room.id);
    if (!match) throw new AppException(ErrorCode.PK_NOT_ACTIVE);
    const muted = parsed.data.muted;
    const changed =
      match.room_a_id === room.id
        ? await this.prisma.$executeRaw`
            UPDATE pk_matches SET a_mutes_b = ${muted}, seq = seq + 1
             WHERE id = ${match.id}::uuid AND status <> 'CLOSED' AND a_mutes_b <> ${muted}`
        : await this.prisma.$executeRaw`
            UPDATE pk_matches SET b_mutes_a = ${muted}, seq = seq + 1
             WHERE id = ${match.id}::uuid AND status <> 'CLOSED' AND b_mutes_a <> ${muted}`;
    if (changed > 0) return (await this.broadcastMatch(match.id, 'mute'))!;
    return this.matchDto((await this.selectMatch(this.prisma, Prisma.sql`id = ${match.id}::uuid`))!);
  }

  /**
   * Ends a battle (under the match's row lock; nothing when it is no longer BATTLE): TIME → the
   * higher score wins (equal: a draw); FORFEIT / DISCONNECT / AWAY → the other side wins (both
   * absent: a draw). The result phase lasts PK_RESULT_SECONDS; the top three supporters per side are
   * frozen; the hosts' records count the result; audited `live.pk.end`.
   */
  private async finishBattle(
    matchId: string,
    finish: Finish,
    actorId: string | null = null,
  ): Promise<boolean> {
    const now = this.clock.now();
    const done = await this.prisma.$transaction(async (tx) => {
      const m = await this.selectMatch(tx, Prisma.sql`id = ${matchId}::uuid`, true);
      if (!m || m.status !== 'BATTLE') return false;
      const endedAt = finish.reason === 'TIME' ? m.battle_ends_at : now;
      const winner =
        finish.reason === 'TIME'
          ? winnerByScore(m.score_a, m.score_b)
          : finish.loser === 'both' || finish.loser === null
            ? null
            : otherSide(finish.loser);
      const loserCause = finish.loser === 'A' || finish.loser === 'B' ? finish.loser : null;
      const resultEndsAt = new Date(endedAt.getTime() + this.config.pk.resultSeconds * 1000);
      const top = await topSupportersIn(tx, matchId);
      await tx.$executeRaw`
        UPDATE pk_matches
           SET status = 'RESULT', ended_at = ${iso(endedAt)}::timestamptz,
               result_ends_at = ${iso(resultEndsAt)}::timestamptz, end_reason = ${finish.reason}::pk_end_reason,
               winner = ${winner}::pk_side, loser_cause = ${loserCause}::pk_side, seq = seq + 1,
               top_a = ${JSON.stringify(top.A)}::jsonb, top_b = ${JSON.stringify(top.B)}::jsonb
         WHERE id = ${matchId}::uuid`;
      const results: [string, 'wins' | 'losses' | 'draws'][] =
        winner === null
          ? [
              [m.host_a_id, 'draws'],
              [m.host_b_id, 'draws'],
            ]
          : [
              [winner === 'A' ? m.host_a_id : m.host_b_id, 'wins'],
              [winner === 'A' ? m.host_b_id : m.host_a_id, 'losses'],
            ];
      for (const [hostId, column] of results) {
        await tx.$executeRaw`
          INSERT INTO pk_host_records (host_id, wins, losses, draws, updated_at)
          VALUES (${hostId}::uuid, ${column === 'wins' ? 1 : 0}, ${column === 'losses' ? 1 : 0},
                  ${column === 'draws' ? 1 : 0}, ${iso(now)}::timestamptz)
          ON CONFLICT (host_id) DO UPDATE
             SET wins = pk_host_records.wins + EXCLUDED.wins, losses = pk_host_records.losses + EXCLUDED.losses,
                 draws = pk_host_records.draws + EXCLUDED.draws, updated_at = EXCLUDED.updated_at`;
      }
      await this.audit.recordIn(tx, {
        action: AuditAction.LIVE_PK_END,
        actorUserId: actorId,
        targetType: 'pk_match',
        targetId: matchId,
        metadata: {
          reason: finish.reason,
          winner,
          loserCause,
          scoreA: Number(m.score_a),
          scoreB: Number(m.score_b),
        },
      });
      return true;
    }, LIVE_TX_OPTIONS);
    if (done) await this.broadcastMatch(matchId, 'ended');
    return done;
  }

  /** RESULT → CLOSED (nothing when it is no longer RESULT); both rooms told, cross-watchers removed. */
  private async closeResult(matchId: string): Promise<boolean> {
    const now = this.clock.now();
    const closed = await this.prisma.$executeRaw`
      UPDATE pk_matches SET status = 'CLOSED', closed_at = ${iso(now)}::timestamptz, seq = seq + 1
       WHERE id = ${matchId}::uuid AND status = 'RESULT'`;
    if (closed === 0) return false;
    await this.afterClose(matchId);
    return true;
  }

  /** Tells both rooms a match is CLOSED and disconnects its `pk:` watchers from both media rooms. */
  private async afterClose(matchId: string): Promise<void> {
    const dto = await this.broadcastMatch(matchId, 'closed');
    if (!dto) return;
    const prefix = `pk:${matchId}:`;
    for (const side of dto.sides) {
      try {
        const identities = await this.media.listIdentities(side.roomId);
        for (const identity of identities.filter((i) => i.startsWith(prefix))) {
          await this.media.removeParticipant(side.roomId, identity);
        }
      } catch (err) {
        this.logger.warn({ error: safeErrorLog(err) }, 'Could not remove PK watchers from a media room');
      }
    }
  }

  /** Sends the match to both rooms (`pk-match`); returns it (null when it does not exist). */
  private async broadcastMatch(
    matchId: string,
    event: PkMatchData['event'],
    boost?: PkMatchData['boost'],
  ): Promise<PkMatchDto | null> {
    const row = await this.selectMatch(this.prisma, Prisma.sql`id = ${matchId}::uuid`);
    if (!row) return null;
    const match = await this.matchDto(row);
    const payload = JSON.stringify({
      type: 'pk-match',
      event,
      match,
      ...(boost ? { boost } : {}),
    } satisfies PkMatchData);
    for (const roomId of [row.room_a_id, row.room_b_id]) {
      try {
        await this.media.broadcastData(roomId, PK_TOPIC, payload);
      } catch (err) {
        this.logger.warn({ error: safeErrorLog(err) }, 'Could not send a PK data message to a media room');
      }
    }
    return match;
  }

  // ---- Gifts (called by LiveGiftsService inside the send's transaction) ------------------------

  /**
   * v1.43-live (D195): a booster gift is checked before its transaction — PK on, quantity 1 and only
   * the host as recipient (400 otherwise).
   */
  assertBoosterSend(input: { quantity: number; recipients: readonly string[]; hostId: string }): void {
    if (!this.config.pk.enabled) {
      throw new AppException(ErrorCode.PK_BOOSTER_UNAVAILABLE, undefined, [
        { field: 'giftCode', issue: 'no_match' },
      ]);
    }
    if (input.quantity !== 1) throw AppException.validation([{ field: 'quantity', issue: 'invalid_value' }]);
    if (input.recipients.length !== 1 || input.recipients[0] !== input.hostId) {
      throw AppException.validation([{ field: 'recipients', issue: 'invalid_value' }]);
    }
  }

  /**
   * In a gift send's transaction (after the sender's and the room row's locks): when the room is in
   * a PK battle, the send's real coin value × that side's active multiplier becomes PK points (one
   * row per send: never counted twice), the sender's support on that side grows, and a booster
   * gift starts its booster (rules in {@link boosterProblem}; a refusal rolls the whole send back:
   * 409 PK_BOOSTER_UNAVAILABLE, nothing charged). The booster gift itself counts at ×1. Returns what
   * the post-commit messages need, or null when the room is not in a battle.
   */
  async creditGiftIn(
    tx: Prisma.TransactionClient,
    input: {
      roomId: string;
      giftId: string;
      giftCode: string;
      senderId: string;
      coins: number;
      booster: PkBoosterKindName | null;
      now: Date;
    },
  ): Promise<PkGiftCredit | null> {
    const m = await this.selectMatch(
      tx,
      Prisma.sql`status = 'BATTLE' AND (room_a_id = ${input.roomId}::uuid OR room_b_id = ${input.roomId}::uuid)`,
      true,
    );
    const remainingMs = m ? m.battle_ends_at.getTime() - input.now.getTime() : 0;
    if (input.booster !== null && (!m || remainingMs <= 0 || !this.config.pk.enabled)) {
      throw new AppException(ErrorCode.PK_BOOSTER_UNAVAILABLE, undefined, [
        { field: 'giftCode', issue: 'no_match' },
      ]);
    }
    if (!m || remainingMs <= 0) return null;
    const side: PkSideName = m.room_a_id === input.roomId ? 'A' : 'B';
    const at = iso(input.now);
    const [active] = await tx.$queryRaw<{ id: string; multiplier: number }[]>`
      SELECT id::text AS id, multiplier FROM pk_boosts
       WHERE match_id = ${m.id}::uuid AND side = ${side}::pk_side
         AND starts_at <= ${at}::timestamptz AND ends_at > ${at}::timestamptz
       ORDER BY multiplier DESC LIMIT 1`;
    const activeMultiplier = active?.multiplier ?? 1;
    let boosted: PkGiftCredit['boosted'] = null;
    if (input.booster !== null) {
      const rule = boosterRule(this.config.pk.boosters, input.booster);
      const [used] = await tx.$queryRaw<{ n: number }[]>`
        SELECT count(*)::int AS n FROM pk_boosts
         WHERE match_id = ${m.id}::uuid AND side = ${side}::pk_side AND kind = ${input.booster}::pk_booster_kind`;
      const problem = boosterProblem({ rule, remainingMs, used: used?.n ?? 0, activeMultiplier });
      if (problem) {
        throw new AppException(ErrorCode.PK_BOOSTER_UNAVAILABLE, undefined, [
          { field: 'giftCode', issue: problem },
        ]);
      }
      if (active) {
        await tx.$executeRaw`UPDATE pk_boosts SET ends_at = ${at}::timestamptz, replaced = true WHERE id = ${active.id}::uuid`;
      }
      const endsAt = new Date(input.now.getTime() + rule.durationSeconds * 1000);
      await tx.$executeRaw`
        INSERT INTO pk_boosts (id, match_id, side, kind, multiplier, gift_id, gift_code, sender_id, starts_at, ends_at)
        VALUES (${uuidv7()}::uuid, ${m.id}::uuid, ${side}::pk_side, ${input.booster}::pk_booster_kind, ${rule.multiplier},
                ${input.giftId}::uuid, ${input.giftCode}, ${input.senderId}::uuid, ${at}::timestamptz,
                ${iso(endsAt)}::timestamptz)`;
      boosted = { side, roomId: input.roomId, kind: input.booster, multiplier: rule.multiplier, endsAt };
    }
    const coins = BigInt(input.coins);
    // The booster gift counts as normal points (×1); its own multiplier applies from the next send.
    const multiplier = input.booster !== null ? 1 : activeMultiplier;
    const points = pkPoints(coins, multiplier);
    if (points > 0n) {
      const inserted = await tx.$executeRaw`
        INSERT INTO pk_gift_points (gift_id, match_id, side, sender_id, coins, multiplier, points, created_at)
        VALUES (${input.giftId}::uuid, ${m.id}::uuid, ${side}::pk_side, ${input.senderId}::uuid, ${coins},
                ${multiplier}, ${points}, ${at}::timestamptz)
        ON CONFLICT (gift_id) DO NOTHING`;
      if (inserted > 0) {
        if (side === 'A') {
          await tx.$executeRaw`UPDATE pk_matches SET score_a = score_a + ${points}, seq = seq + 1 WHERE id = ${m.id}::uuid`;
        } else {
          await tx.$executeRaw`UPDATE pk_matches SET score_b = score_b + ${points}, seq = seq + 1 WHERE id = ${m.id}::uuid`;
        }
        await tx.$executeRaw`
          INSERT INTO pk_supporters (match_id, side, user_id, points)
          VALUES (${m.id}::uuid, ${side}::pk_side, ${input.senderId}::uuid, ${points})
          ON CONFLICT (match_id, side, user_id) DO UPDATE SET points = pk_supporters.points + EXCLUDED.points`;
      }
    } else if (boosted) {
      await tx.$executeRaw`UPDATE pk_matches SET seq = seq + 1 WHERE id = ${m.id}::uuid`;
    }
    return { matchId: m.id, boosted };
  }

  /** After a send's commit: a booster at once («فعّل فريق X …»), a score within PK_SCORE_BROADCAST_MS. */
  async afterGift(credit: PkGiftCredit): Promise<void> {
    if (credit.boosted) {
      const b = credit.boosted;
      await this.broadcastMatch(credit.matchId, 'boost', {
        roomId: b.roomId,
        kind: b.kind,
        multiplier: b.multiplier,
        endsAt: iso(b.endsAt),
      });
      return;
    }
    await this.scoreThrottle.touch(credit.matchId);
  }

  // ---- Media -----------------------------------------------------------------------------------

  /**
   * `POST /live/rooms/{roomId}/pk/media-token`: a watch-only, hidden token for the OTHER room of this
   * room's PK (BATTLE or RESULT), so the viewers and the host of this room see and hear the other
   * host (and their guests). The caller must be allowed to watch this room (guests while it allows
   * them, 403; not kicked out, 403) and the other one (signed-in: no block with its host → else 404;
   * guests: it allows guests → else 403). Identity `pk:<matchId>:<userId | guest:<guestId>>`.
   */
  async mediaToken(callerId: string | null, roomId: string, body: unknown): Promise<PkMediaAccessDto> {
    if (!this.config.live.hostingEnabled) throw new AppException(ErrorCode.LIVE_HOSTING_UNAVAILABLE);
    const parsed = liveMediaTokenSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const guestId = callerId === null ? parsed.data.guestId?.toLowerCase() : undefined;
    if (callerId === null && guestId === undefined)
      throw AppException.validation([{ field: 'guestId', issue: 'required' }]);
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    if (callerId !== null && row.kicked) throw new AppException(ErrorCode.LIVE_KICKED);
    if (guestId !== undefined && !row.allow_guests) throw new AppException(ErrorCode.LIVE_GUESTS_NOT_ALLOWED);
    const match = await this.openMatchOfRoom(this.prisma, row.id);
    if (!match) throw new AppException(ErrorCode.PK_NOT_ACTIVE);
    const otherRoom = match.room_a_id === row.id ? match.room_b_id : match.room_a_id;
    const otherHost = match.room_a_id === row.id ? match.host_b_id : match.host_a_id;
    const other = await this.rooms.visibleRow(otherRoom, callerId);
    if (guestId !== undefined && !other.allow_guests)
      throw new AppException(ErrorCode.LIVE_GUESTS_NOT_ALLOWED);
    let name: string;
    let base: string;
    if (guestId !== undefined) {
      base = `guest:${guestId}`;
      name = 'Guest';
    } else {
      base = callerId!;
      const me = await this.users.getMe(callerId!);
      name = me?.displayName || me?.username || '';
    }
    const identity = pkIdentity(match.id, base);
    const ttl = 600;
    const token = await this.media.issueToken({
      room: otherRoom,
      identity,
      name,
      publish: false,
      ttlSeconds: ttl,
    });
    return {
      url: this.media.url,
      token,
      expiresAt: iso(new Date(this.clock.now().getTime() + ttl * 1000)),
      roomId: otherRoom,
      identity,
      hostIdentity: otherHost,
    };
  }

  /**
   * The media webhook (or reconciliation) found a `pk:` identity in a room: allowed while that match
   * is BATTLE / RESULT and the room is one of its two (else the caller disconnects it). Never a
   * viewer of that room (no presence row, not counted, no "joined" line).
   */
  async allowsWatcher(roomId: string, identity: string): Promise<boolean> {
    const matchId = pkMatchOfIdentity(identity);
    if (matchId === null) return false;
    const n = await this.prisma.pkMatch.count({
      where: { id: matchId, status: { not: 'CLOSED' }, OR: [{ roomAId: roomId }, { roomBId: roomId }] },
    });
    return n > 0;
  }

  /** The host of a room in a PK battle joined or left the media session (D195 disconnect rule). */
  async onHostMedia(roomId: string, identity: string, joined: boolean): Promise<void> {
    if (!isUuid(identity)) return;
    const now = iso(this.clock.now());
    const host = identity.toLowerCase();
    if (joined) {
      await this.prisma.$executeRaw`
        UPDATE pk_matches SET a_left_at = CASE WHEN room_a_id = ${roomId}::uuid AND host_a_id = ${host}::uuid THEN NULL ELSE a_left_at END,
                              b_left_at = CASE WHEN room_b_id = ${roomId}::uuid AND host_b_id = ${host}::uuid THEN NULL ELSE b_left_at END
         WHERE status = 'BATTLE' AND (room_a_id = ${roomId}::uuid OR room_b_id = ${roomId}::uuid)
           AND (a_left_at IS NOT NULL OR b_left_at IS NOT NULL)`;
    } else {
      await this.prisma.$executeRaw`
        UPDATE pk_matches SET a_left_at = CASE WHEN room_a_id = ${roomId}::uuid AND host_a_id = ${host}::uuid
                                               THEN COALESCE(a_left_at, ${now}::timestamptz) ELSE a_left_at END,
                              b_left_at = CASE WHEN room_b_id = ${roomId}::uuid AND host_b_id = ${host}::uuid
                                               THEN COALESCE(b_left_at, ${now}::timestamptz) ELSE b_left_at END
         WHERE status = 'BATTLE' AND (room_a_id = ${roomId}::uuid OR room_b_id = ${roomId}::uuid)`;
    }
  }

  // ---- Settings, records -----------------------------------------------------------------------

  /** `GET /me/live-pk`: the caller's PK switch and record. */
  async mySettings(callerId: string): Promise<{ invitesEnabled: boolean; record: PkHostRecordDto }> {
    const [settings, record] = await Promise.all([
      this.prisma.pkHostSettings.findUnique({ where: { hostId: callerId } }),
      this.prisma.pkHostRecord.findUnique({ where: { hostId: callerId } }),
    ]);
    return {
      invitesEnabled: settings?.invitesEnabled ?? true,
      record: { wins: record?.wins ?? 0, losses: record?.losses ?? 0, draws: record?.draws ?? 0 },
    };
  }

  /** `PUT /me/live-pk` `{invitesEnabled}`: audited when it changes. */
  async setSettings(
    callerId: string,
    body: unknown,
    meta: RequestMeta,
  ): Promise<{ invitesEnabled: boolean; record: PkHostRecordDto }> {
    const parsed = settingsSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const enabled = parsed.data.invitesEnabled;
    await this.prisma.$transaction(async (tx) => {
      const before = await tx.pkHostSettings.findUnique({ where: { hostId: callerId } });
      if ((before?.invitesEnabled ?? true) === enabled) return;
      await tx.pkHostSettings.upsert({
        where: { hostId: callerId },
        create: { hostId: callerId, invitesEnabled: enabled, updatedAt: this.clock.now() },
        update: { invitesEnabled: enabled, updatedAt: this.clock.now() },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.LIVE_PK_SETTINGS,
        actorUserId: callerId,
        targetType: 'user',
        targetId: callerId,
        metadata: { invitesEnabled: enabled },
        ip: meta.ip,
        requestId: meta.requestId,
      });
    });
    return this.mySettings(callerId);
  }

  /**
   * `GET /live/pk/hosts/{username}`: a host's PK record (wins / losses / draws of finished, non-void
   * matches) and their last 20 matches (newest first; void ones included as VOID). An unknown,
   * inactive or blocked (either way) user → 404.
   */
  async hostProfile(callerId: string | null, username: string): Promise<PkHostProfileDto> {
    const user = await this.users.findActivePublicUser(username);
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    if (callerId !== null && callerId !== user.id && (await this.blocked(this.prisma, callerId, user.id))) {
      throw new AppException(ErrorCode.NOT_FOUND);
    }
    const [record, rows] = await Promise.all([
      this.prisma.pkHostRecord.findUnique({ where: { hostId: user.id } }),
      this.prisma.$queryRaw<MatchRow[]>(
        Prisma.sql`SELECT ${Prisma.raw(MATCH_COLUMNS)} FROM pk_matches
          WHERE status <> 'BATTLE' AND (host_a_id = ${user.id}::uuid OR host_b_id = ${user.id}::uuid)
          ORDER BY started_at DESC, id DESC LIMIT 20`,
      ),
    ]);
    const people = await this.summaries(
      rows.flatMap((r) => [
        r.host_a_id,
        r.host_b_id,
        ...(r.host_a_id === user.id ? (r.top_a ?? []) : (r.top_b ?? [])).map((s) => s.userId),
      ]),
    );
    return {
      record: { wins: record?.wins ?? 0, losses: record?.losses ?? 0, draws: record?.draws ?? 0 },
      recent: rows
        .filter((r) => r.end_reason !== null && r.ended_at !== null)
        .map((r): PkHistoryItemDto => {
          const mine: PkSideName = r.host_a_id === user.id ? 'A' : 'B';
          const result: PkHistoryItemDto['result'] =
            r.end_reason === 'ADMIN'
              ? 'VOID'
              : r.winner === null
                ? 'DRAW'
                : r.winner === mine
                  ? 'WIN'
                  : 'LOSS';
          const top = (mine === 'A' ? r.top_a : r.top_b) ?? [];
          return {
            id: r.id,
            result,
            endReason: r.end_reason!,
            score: Number(mine === 'A' ? r.score_a : r.score_b),
            opponentScore: Number(mine === 'A' ? r.score_b : r.score_a),
            opponent: people.get(mine === 'A' ? r.host_b_id : r.host_a_id)!,
            startedAt: iso(r.started_at),
            durationSeconds: Math.max(0, Math.round((r.ended_at!.getTime() - r.started_at.getTime()) / 1000)),
            supporters: top
              .filter((s) => people.has(s.userId))
              .map((s) => ({ user: people.get(s.userId)!, points: s.points })),
          };
        })
        .filter((r) => r.opponent !== undefined),
    };
  }

  // ---- The tick --------------------------------------------------------------------------------

  /**
   * One PK tick (every PK_TICK_MS; by hand in tests): open invitations past their time expire (both
   * hosts told), random-queue waits past theirs end (the host told), battles whose time is up end
   * (TIME), battles with an absent host end (FORFEIT / DISCONNECT / AWAY), result phases past their
   * time close, and matches a moderator ended are told to both rooms. Each step is idempotent under
   * the rows' state guards, so instances may run it concurrently.
   */
  async tick(): Promise<{ expiredInvites: number; ended: number; closed: number }> {
    const now = this.clock.now();
    const expired = await this.prisma.$queryRaw<{ id: string }[]>`
      UPDATE pk_invites SET status = 'EXPIRED', handled_at = expires_at
       WHERE status = 'PENDING' AND expires_at <= ${iso(now)}::timestamptz
       RETURNING id::text AS id`;
    for (const { id } of expired) {
      const dto = await this.inviteDto(id);
      if (dto) await this.tellInvite(dto, 'both');
    }
    const waits = await this.prisma.$queryRaw<{ host_id: string; room_id: string }[]>`
      DELETE FROM pk_queue WHERE expires_at <= ${iso(now)}::timestamptz
       RETURNING host_id::text AS host_id, room_id::text AS room_id`;
    for (const w of waits) {
      try {
        await this.media.sendData(
          w.room_id,
          w.host_id,
          JSON.stringify({ type: 'pk-queue', status: 'EXPIRED' } satisfies PkQueueData),
        );
      } catch (err) {
        this.logger.warn({ error: safeErrorLog(err) }, 'Could not tell a host their PK wait ended');
      }
    }
    let ended = 0;
    let closed = 0;
    const open = await this.prisma.$queryRaw<
      (MatchRow & { a_left_at: Date | null; b_left_at: Date | null })[]
    >(Prisma.sql`SELECT ${Prisma.raw(MATCH_COLUMNS)}, a_left_at, b_left_at
        FROM pk_matches WHERE status <> 'CLOSED' ORDER BY started_at LIMIT 1000`);
    const grace = this.config.pk.absenceGraceSeconds;
    for (const m of open) {
      if (m.status === 'BATTLE') {
        const [a, b] = await Promise.all([
          this.roomState(this.prisma, m.room_a_id),
          this.roomState(this.prisma, m.room_b_id),
        ]);
        const presence = (room: RoomState | null, leftAt: Date | null) =>
          room === null
            ? 'DISCONNECT'
            : absenceOf(
                {
                  roomStatus: room.status,
                  roomEndReason: room.end_reason,
                  lastHeartbeatAt: room.last_heartbeat_at,
                  hostAwaySince: room.host_away_since,
                  leftAt,
                },
                now,
                grace,
              );
        const absentA = presence(a, m.a_left_at);
        const absentB = presence(b, m.b_left_at);
        let finish: Finish | null = null;
        if (absentA && absentB) finish = { reason: absentA, loser: 'both' };
        else if (absentA) finish = { reason: absentA, loser: 'A' };
        else if (absentB) finish = { reason: absentB, loser: 'B' };
        else if (m.battle_ends_at.getTime() <= now.getTime()) finish = { reason: 'TIME', loser: null };
        if (finish && (await this.finishBattle(m.id, finish))) ended += 1;
      } else if (m.status === 'RESULT') {
        const rooms = await this.prisma.liveRoom.count({
          where: { id: { in: [m.room_a_id, m.room_b_id] }, status: 'LIVE' },
        });
        if ((m.result_ends_at !== null && m.result_ends_at.getTime() <= now.getTime()) || rooms < 2) {
          if (await this.closeResult(m.id)) closed += 1;
        }
      }
    }
    const notices = await this.prisma.$queryRaw<{ id: string }[]>`
      UPDATE pk_matches SET pending_notice = false WHERE pending_notice RETURNING id::text AS id`;
    for (const { id } of notices) await this.afterClose(id);
    return { expiredInvites: expired.length, ended, closed };
  }
}
