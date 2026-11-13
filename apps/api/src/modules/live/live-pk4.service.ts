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
import { anonymousUserSummary, vipPrivacyOnIn } from '../vip/vip-privacy.js';
import { UsersService } from '../users/users.service.js';
import { TrailingThrottle } from './live-metadata.service.js';
import {
  absenceOf,
  boosterProblem,
  boosterRule,
  PK_TOPIC,
  pkPoints,
  type PkEndReasonName,
  type PkSideName,
} from './live-pk.js';
import {
  adminEndPk4In,
  isEffectivePk4,
  pk4BusySql,
  pk4Identity,
  pk4MatchOfIdentity,
  PK4_IDENTITY_PREFIX,
  roleOfSeat,
  teamOfSeat,
  teamsOutcome,
  teamWinnerByScore,
  topTeamSupportersIn,
  type Pk4FormatName,
} from './live-pk4.js';
import type {
  PkActiveBoostDto,
  PkBoosterRuleDto,
  PkCandidateDto,
  PkSupporterDto,
} from './live-pk.service.js';
import { LIVE_TX_OPTIONS, LiveRoomsService, type UserSummaryDto } from './live-rooms.service.js';
import { isUuid, liveMediaTokenSchema } from './live.schemas.js';
import { pkDareSettingsIn } from './pk-dares/pk-dare-library.js';
import { LIVE_MEDIA_PROVIDER, type LiveMediaProvider } from './media/live-media.provider.js';

// ---- Response shapes (openapi v1.118-live, CONVENTIONS §10.180) ---------------------------------

export type Pk4InviteStatusName = 'PENDING' | 'ACCEPTED' | 'DECLINED' | 'CANCELLED' | 'EXPIRED' | 'LEFT';

/** `Pk4Invite`. */
export interface Pk4InviteDto {
  id: string;
  lobbyId: string;
  format: Pk4FormatName;
  seat: number;
  team: PkSideName;
  status: Pk4InviteStatusName;
  fromRoomId: string;
  toRoomId: string;
  from: UserSummaryDto;
  to: UserSummaryDto;
  createdAt: string;
  expiresAt: string;
  lobbyExpiresAt: string;
}

/** `Pk4LobbySeat`. */
export interface Pk4LobbySeatDto {
  seat: number;
  team: PkSideName;
  role: 'ORGANISER' | 'TEAMMATE' | 'OPPONENT';
  state: 'EMPTY' | 'INVITED' | 'ACCEPTED';
  roomId: string | null;
  host: UserSummaryDto | null;
  invite: Pk4InviteDto | null;
}

/** `Pk4Lobby`. */
export interface Pk4LobbyDto {
  id: string;
  format: Pk4FormatName;
  status: 'OPEN' | 'STARTED' | 'CANCELLED' | 'EXPIRED';
  organiserRoomId: string;
  createdAt: string;
  expiresAt: string;
  matchId: string | null;
  serverTime: string;
  seats: Pk4LobbySeatDto[];
}

/** `Pk4TeamState`. */
export interface Pk4TeamDto {
  team: PkSideName;
  score: number;
  result: 'WIN' | 'LOSS' | 'DRAW' | null;
  boost: PkActiveBoostDto | null;
  boosterUses: Record<PkBoosterKindName, number>;
  supporters: PkSupporterDto[];
}

/** `Pk4SeatState`. */
export interface Pk4SeatDto {
  seat: number;
  team: PkSideName;
  roomId: string;
  host: UserSummaryDto;
  score: number;
  out: boolean;
  outReason: 'FORFEIT' | 'DISCONNECT' | 'AWAY' | null;
  mutedRoomIds: string[];
  pkPoints: number;
}

/** `Pk4Match`. */
export interface Pk4MatchDto {
  id: string;
  format: Pk4FormatName;
  status: 'CONNECTED' | 'BATTLE' | 'RESULT' | 'CLOSED';
  startedAt: string;
  battleEndsAt: string;
  endedAt: string | null;
  resultEndsAt: string | null;
  endReason: PkEndReasonName | null;
  winnerTeam: PkSideName | null;
  seq: number;
  serverTime: string;
  roundSeconds: number;
  connectedAt: string | null;
  effective: boolean | null;
  organiserRoomId: string;
  teams: [Pk4TeamDto, Pk4TeamDto];
  seats: Pk4SeatDto[];
  boosters: PkBoosterRuleDto[];
}

/** `Pk4State`. */
export interface Pk4StateDto {
  match: Pk4MatchDto | null;
  lobby: Pk4LobbyDto | null;
  invite: Pk4InviteDto | null;
}

/** `Pk4MediaAccess`. */
export interface Pk4MediaAccessDto {
  url: string;
  expiresAt: string;
  layer: 'LOW' | 'MEDIUM';
  capped: boolean;
  rooms: { roomId: string; token: string; identity: string; hostIdentity: string }[];
}

export type Pk4MatchEvent = 'connected' | 'started' | 'score' | 'boost' | 'out' | 'ended' | 'closed' | 'mute';

export type Pk4LobbyEvent =
  | 'opened'
  | 'invited'
  | 'accepted'
  | 'declined'
  | 'invite-expired'
  | 'invite-cancelled'
  | 'left'
  | 'cancelled'
  | 'expired'
  | 'started';

/** The data message of topic `pk` to the four rooms. */
export interface Pk4MatchData {
  readonly type: 'pk4-match';
  readonly event: Pk4MatchEvent;
  readonly match: Pk4MatchDto;
  /** `boost`: the team and booster that just started, and the room whose gift started it. */
  readonly boost?: {
    team: PkSideName;
    roomId: string;
    kind: PkBoosterKindName;
    multiplier: number;
    endsAt: string;
  };
}

/** The data message of topic `pk` to each host of a lobby (in their own room). */
export interface Pk4LobbyData {
  readonly type: 'pk4-lobby';
  readonly event: Pk4LobbyEvent;
  readonly lobby: Pk4LobbyDto;
}

/** The data message of topic `pk` to an invited host. */
export interface Pk4InviteData {
  readonly type: 'pk4-invite';
  readonly invite: Pk4InviteDto;
}

/** What a gift send in a 4-way room during the battle did (for the send's post-commit messages). */
export interface Pk4GiftCredit {
  readonly matchId: string;
  readonly boosted: {
    team: PkSideName;
    roomId: string;
    kind: PkBoosterKindName;
    multiplier: number;
    endsAt: Date;
  } | null;
}

// ---- Request bodies ----------------------------------------------------------------------------

const lobbySchema = z.strictObject({ format: z.enum(['TEAMS', 'FREE_FOR_ALL']) });
const inviteSchema = z.strictObject({
  toRoomId: z.uuid(),
  seat: z.union([z.literal(2), z.literal(3), z.literal(4)]),
});
const muteSchema = z.strictObject({ roomId: z.uuid(), muted: z.boolean() });
const candidatesQuerySchema = z.object({
  q: z.string().trim().max(30).optional(),
  friends: z.enum(['true', 'false']).optional(),
  limit: z
    .string()
    .regex(/^\d{1,3}$/)
    .transform(Number)
    .pipe(z.number().int().min(1).max(50))
    .optional(),
});

// ---- Internal rows -----------------------------------------------------------------------------

interface LobbyRow {
  id: string;
  format: Pk4FormatName;
  status: Pk4LobbyDto['status'];
  organiser_room_id: string;
  organiser_host_id: string;
  created_at: Date;
  expires_at: Date;
  match_id: string | null;
}

interface InviteRow {
  id: string;
  lobby_id: string;
  seat: number;
  team: PkSideName;
  to_room_id: string;
  to_host_id: string;
  status: Pk4InviteStatusName;
  created_at: Date;
  expires_at: Date;
}

interface MatchRow {
  id: string;
  lobby_id: string | null;
  format: Pk4FormatName;
  status: Pk4MatchDto['status'];
  organiser_room_id: string;
  started_at: Date;
  battle_ends_at: Date;
  ended_at: Date | null;
  result_ends_at: Date | null;
  end_reason: PkEndReasonName | null;
  winner_team: PkSideName | null;
  loser_cause: PkSideName | null;
  score_a: bigint;
  score_b: bigint;
  round_seconds: number;
  connected_at: Date | null;
  seq: number;
  top_a: { userId: string; points: number }[] | null;
  top_b: { userId: string; points: number }[] | null;
  effective: boolean | null;
}

interface SeatRow {
  match_id: string;
  seat: number;
  team: PkSideName;
  room_id: string;
  host_id: string;
  score: bigint;
  active: boolean;
  left_at: Date | null;
  out_at: Date | null;
  out_reason: 'FORFEIT' | 'DISCONNECT' | 'AWAY' | null;
  muted_room_ids: string[];
}

interface RoomState {
  id: string;
  host_user_id: string;
  status: 'LIVE' | 'ENDED';
  mode: string;
  end_reason: string | null;
  last_heartbeat_at: Date;
  host_away_since: Date | null;
}

const LOBBY_COLUMNS = `id::text AS id, format::text AS format, status::text AS status,
  organiser_room_id::text AS organiser_room_id, organiser_host_id::text AS organiser_host_id, created_at, expires_at,
  match_id::text AS match_id`;

const INVITE_COLUMNS = `id::text AS id, lobby_id::text AS lobby_id, seat, team::text AS team,
  to_room_id::text AS to_room_id, to_host_id::text AS to_host_id, status::text AS status, created_at, expires_at`;

const MATCH_COLUMNS = `id::text AS id, lobby_id::text AS lobby_id, format::text AS format, status::text AS status,
  organiser_room_id::text AS organiser_room_id, started_at, battle_ends_at, ended_at, result_ends_at,
  end_reason::text AS end_reason, winner_team::text AS winner_team, loser_cause::text AS loser_cause, score_a, score_b,
  round_seconds, connected_at, seq, top_a, top_b, effective`;

const SEAT_COLUMNS = `match_id::text AS match_id, seat, team::text AS team, room_id::text AS room_id,
  host_id::text AS host_id, score, active, left_at, out_at, out_reason::text AS out_reason,
  muted_room_ids::text[] AS muted_room_ids`;

/** The end of a battle as the tick or a host decides it. */
interface Finish {
  readonly reason: PkEndReasonName;
  /** Null with TIME (decided by the scores) or when everyone is gone. */
  readonly winner: PkSideName | null;
  readonly loserCause: PkSideName | null;
  readonly everyoneGone: boolean;
}

function iso(d: Date): string {
  return d.toISOString();
}

/** A transaction that must be retried because the lobby's set of rooms changed before its locks were taken. */
class LobbyMoved extends Error {}

/**
 * «PK رباعي» (v1.118-live, D391, CONVENTIONS §10.180, CP-041 phase 2): PK 2 v 2 between four hosts of SOLO video lives,
 * started by invitation. An organiser opens a lobby (PK4_LOBBY_SECONDS) and invites a teammate and two opponents, one
 * place at a time (PK4_INVITE_TTL_SECONDS each); the fourth acceptance starts one round with the organiser's settings.
 * Server-authoritative like PK 1 v 1 (scores, team boosters, outs, the result phase) and told to the four rooms as
 * `pk` data messages, with `GET /live/rooms/{roomId}/pk4` as the snapshot. Each room's viewers watch the three other
 * hosts with watch-only, hidden tokens (`pk4:<matchId>:<identity>`). PK 1 v 1 (`LivePkService`) is untouched; the two
 * share the per-room PK advisory locks and each counts the other's rows as busy.
 */
@Injectable()
export class LivePk4Service implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(LivePk4Service.name);
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
        .catch((err: unknown) => this.logger.warn({ error: safeErrorLog(err) }, 'PK4 tick failed'))
        .finally(() => {
          this.tickInFlight = null;
          this.scheduleTick();
        });
    }, this.config.pk.tickMs);
    this.tickTimer.unref();
  }

  // ---- Checks ----------------------------------------------------------------------------------

  private assertOn(): void {
    if (!this.config.live.hostingEnabled) throw new AppException(ErrorCode.LIVE_HOSTING_UNAVAILABLE);
    if (!this.config.pk.enabled || !this.config.pk.pk4.enabled) {
      throw new AppException(ErrorCode.PK_UNAVAILABLE);
    }
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

  /** As PK 1 v 1 (§10.58): LIVE, a SOLO video live, a fresh heartbeat, the host present. */
  private eligible(room: RoomState | null, now: Date): boolean {
    return (
      room !== null &&
      room.status === 'LIVE' &&
      room.mode === 'SOLO' &&
      room.last_heartbeat_at.getTime() > this.staleCutoff(now).getTime() &&
      room.host_away_since === null
    );
  }

  /** The caller's own room (404 otherwise). */
  private async ownRoom(callerId: string, roomId: string): Promise<RoomState> {
    if (!isUuid(roomId)) throw new AppException(ErrorCode.NOT_FOUND);
    const room = await this.roomState(this.prisma, roomId.toLowerCase());
    if (!room || room.host_user_id !== callerId) throw new AppException(ErrorCode.NOT_FOUND);
    return room;
  }

  /** The caller's own room, LIVE (409 LIVE_ROOM_ENDED) and eligible (409 PK_UNAVAILABLE). */
  private async ownEligibleRoom(callerId: string, roomId: string, now: Date): Promise<RoomState> {
    const room = await this.ownRoom(callerId, roomId);
    if (room.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    if (!this.eligible(room, now)) throw new AppException(ErrorCode.PK_UNAVAILABLE);
    return room;
  }

  /** A block either way between `a` and any of `others`. */
  private async blockedWithAny(
    db: Prisma.TransactionClient | PrismaService,
    a: string,
    others: readonly string[],
  ): Promise<boolean> {
    const ids = others.filter((o) => o !== a);
    if (ids.length === 0) return false;
    const [row] = await db.$queryRaw<{ blocked: boolean }[]>`
      SELECT EXISTS (SELECT 1 FROM user_blocks
                      WHERE (blocker_id = ${a}::uuid AND blocked_id = ANY(${ids}::uuid[]))
                         OR (blocked_id = ${a}::uuid AND blocker_id = ANY(${ids}::uuid[]))) AS blocked`;
    return row?.blocked ?? false;
  }

  /** Takes the PK locks of rooms (the same keys as PK 1 v 1, sorted). */
  private async lockRooms(tx: Prisma.TransactionClient, roomIds: readonly string[]): Promise<void> {
    for (const id of [...new Set(roomIds)].sort()) {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`pk-room:${id}`}, 0))`;
    }
  }

  /**
   * Whether a room or its host is busy for a 4-way step: an open 1 v 1 match or invitation either way, the host's
   * random-queue wait (not with `ignoreQueue`, §10.70), or a 4-way place, lobby or invitation (except `exceptInviteId`,
   * the invitation being answered, and `exceptLobbyId`, the organiser's own lobby). Under the room's PK lock.
   */
  private async busyIn(
    tx: Prisma.TransactionClient,
    roomId: string,
    hostId: string,
    now: Date,
    opts: { ignoreQueue?: boolean; exceptInviteId?: string; exceptLobbyId?: string } = {},
  ): Promise<boolean> {
    const at = iso(now);
    const room = Prisma.sql`${roomId}::uuid`;
    const exceptInvite = opts.exceptInviteId ?? null;
    const exceptLobby = opts.exceptLobbyId ?? null;
    const [row] = await tx.$queryRaw<{ busy: boolean }[]>`
      SELECT EXISTS (SELECT 1 FROM pk_matches WHERE status <> 'CLOSED'
                        AND (room_a_id = ${room} OR room_b_id = ${room}))
          OR EXISTS (SELECT 1 FROM pk_invites WHERE status = 'PENDING' AND expires_at > ${at}::timestamptz
                        AND (from_room_id = ${room} OR to_room_id = ${room}))
          OR (NOT ${opts.ignoreQueue === true}
              AND EXISTS (SELECT 1 FROM pk_queue WHERE host_id = ${hostId}::uuid AND expires_at > ${at}::timestamptz))
          OR EXISTS (SELECT 1 FROM pk4_seats s4 WHERE s4.active AND s4.room_id = ${room})
          OR EXISTS (SELECT 1 FROM pk4_lobbies l4 WHERE l4.status = 'OPEN' AND l4.organiser_room_id = ${room}
                        AND l4.expires_at > ${at}::timestamptz
                        AND (${exceptLobby}::uuid IS NULL OR l4.id <> ${exceptLobby}::uuid))
          OR EXISTS (SELECT 1 FROM pk4_invites i4 JOIN pk4_lobbies l4 ON l4.id = i4.lobby_id
                      WHERE i4.to_room_id = ${room} AND l4.status = 'OPEN' AND l4.expires_at > ${at}::timestamptz
                        AND (${exceptInvite}::uuid IS NULL OR i4.id <> ${exceptInvite}::uuid)
                        AND (i4.status = 'ACCEPTED'
                             OR (i4.status = 'PENDING' AND i4.expires_at > ${at}::timestamptz))) AS busy`;
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

  private async lobbyRow(
    db: Prisma.TransactionClient | PrismaService,
    where: Prisma.Sql,
    lock = false,
  ): Promise<LobbyRow | null> {
    const [row] = await db.$queryRaw<LobbyRow[]>(
      Prisma.sql`SELECT ${Prisma.raw(LOBBY_COLUMNS)} FROM pk4_lobbies WHERE ${where}
        ORDER BY created_at DESC LIMIT 1 ${lock ? Prisma.raw('FOR UPDATE') : Prisma.empty}`,
    );
    return row ?? null;
  }

  private async invitesOf(
    db: Prisma.TransactionClient | PrismaService,
    lobbyId: string,
  ): Promise<InviteRow[]> {
    return db.$queryRaw<InviteRow[]>(
      Prisma.sql`SELECT ${Prisma.raw(INVITE_COLUMNS)} FROM pk4_invites WHERE lobby_id = ${lobbyId}::uuid
        ORDER BY created_at, id`,
    );
  }

  private async inviteRow(
    db: Prisma.TransactionClient | PrismaService,
    inviteId: string,
    lock = false,
  ): Promise<InviteRow | null> {
    if (!isUuid(inviteId)) return null;
    const [row] = await db.$queryRaw<InviteRow[]>(
      Prisma.sql`SELECT ${Prisma.raw(INVITE_COLUMNS)} FROM pk4_invites WHERE id = ${inviteId.toLowerCase()}::uuid
        ${lock ? Prisma.raw('FOR UPDATE') : Prisma.empty}`,
    );
    return row ?? null;
  }

  private async matchRow(
    db: Prisma.TransactionClient | PrismaService,
    where: Prisma.Sql,
    lock = false,
  ): Promise<MatchRow | null> {
    const [row] = await db.$queryRaw<MatchRow[]>(
      Prisma.sql`SELECT ${Prisma.raw(MATCH_COLUMNS)} FROM pk4_matches WHERE ${where}
        ${lock ? Prisma.raw('FOR UPDATE') : Prisma.empty}`,
    );
    return row ?? null;
  }

  private async seatsOf(db: Prisma.TransactionClient | PrismaService, matchId: string): Promise<SeatRow[]> {
    return db.$queryRaw<SeatRow[]>(
      Prisma.sql`SELECT ${Prisma.raw(SEAT_COLUMNS)} FROM pk4_seats WHERE match_id = ${matchId}::uuid ORDER BY seat`,
    );
  }

  /** The room's open match (CONNECTED, BATTLE or RESULT: an active place), or null. */
  private async openMatchOfRoom(
    db: Prisma.TransactionClient | PrismaService,
    roomId: string,
  ): Promise<MatchRow | null> {
    return this.matchRow(
      db,
      Prisma.sql`status <> 'CLOSED' AND id = (SELECT match_id FROM pk4_seats WHERE active AND room_id = ${roomId}::uuid LIMIT 1)`,
    );
  }

  /** The OPEN lobby a room organises or accepted a place in, or null. */
  private async openLobbyOfRoom(
    db: Prisma.TransactionClient | PrismaService,
    roomId: string,
  ): Promise<LobbyRow | null> {
    return this.lobbyRow(
      db,
      Prisma.sql`status = 'OPEN' AND (organiser_room_id = ${roomId}::uuid OR id IN (
        SELECT lobby_id FROM pk4_invites WHERE to_room_id = ${roomId}::uuid AND status = 'ACCEPTED'))`,
    );
  }

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

  private inviteDtoOf(
    invite: InviteRow,
    lobby: LobbyRow,
    people: Map<string, UserSummaryDto>,
  ): Pk4InviteDto | null {
    const from = people.get(lobby.organiser_host_id);
    const to = people.get(invite.to_host_id);
    if (!from || !to) return null;
    return {
      id: invite.id,
      lobbyId: lobby.id,
      format: lobby.format,
      seat: invite.seat,
      team: invite.team,
      status: invite.status,
      fromRoomId: lobby.organiser_room_id,
      toRoomId: invite.to_room_id,
      from,
      to,
      createdAt: iso(invite.created_at),
      expiresAt: iso(invite.expires_at),
      lobbyExpiresAt: iso(lobby.expires_at),
    };
  }

  /** The lobby as its hosts see it (an expired open invitation reads as an empty place). */
  async lobbyDto(lobbyId: string): Promise<Pk4LobbyDto | null> {
    const lobby = await this.lobbyRow(this.prisma, Prisma.sql`id = ${lobbyId}::uuid`);
    if (!lobby) return null;
    const now = this.clock.now();
    const invites = await this.invitesOf(this.prisma, lobby.id);
    const people = await this.summaries([lobby.organiser_host_id, ...invites.map((i) => i.to_host_id)]);
    const seats: Pk4LobbySeatDto[] = [1, 2, 3, 4].map((seat) => {
      const team = teamOfSeat(seat);
      const role = roleOfSeat(seat);
      if (seat === 1) {
        return {
          seat,
          team,
          role,
          state: 'ACCEPTED',
          roomId: lobby.organiser_room_id,
          host: people.get(lobby.organiser_host_id) ?? null,
          invite: null,
        };
      }
      const current = invites.find(
        (i) =>
          i.seat === seat &&
          (i.status === 'ACCEPTED' || (i.status === 'PENDING' && i.expires_at.getTime() > now.getTime())),
      );
      if (!current) return { seat, team, role, state: 'EMPTY', roomId: null, host: null, invite: null };
      return {
        seat,
        team,
        role,
        state: current.status === 'ACCEPTED' ? 'ACCEPTED' : 'INVITED',
        roomId: current.to_room_id,
        host: people.get(current.to_host_id) ?? null,
        invite: this.inviteDtoOf(current, lobby, people),
      };
    });
    return {
      id: lobby.id,
      format: lobby.format,
      status: lobby.status,
      organiserRoomId: lobby.organiser_room_id,
      createdAt: iso(lobby.created_at),
      expiresAt: iso(lobby.expires_at),
      matchId: lobby.match_id,
      serverTime: iso(now),
      seats,
    };
  }

  async inviteDto(inviteId: string): Promise<Pk4InviteDto | null> {
    const invite = await this.inviteRow(this.prisma, inviteId);
    if (!invite) return null;
    const lobby = await this.lobbyRow(this.prisma, Prisma.sql`id = ${invite.lobby_id}::uuid`);
    if (!lobby) return null;
    const people = await this.summaries([lobby.organiser_host_id, invite.to_host_id]);
    return this.inviteDtoOf(invite, lobby, people);
  }

  /** The full match as the four rooms see it. */
  async matchDto(row: MatchRow): Promise<Pk4MatchDto> {
    const now = this.clock.now();
    const [seats, boosts, uses, supporters, rules] = await Promise.all([
      this.seatsOf(this.prisma, row.id),
      this.prisma.$queryRaw<
        {
          id: string;
          team: PkSideName;
          kind: PkBoosterKindName;
          multiplier: number;
          starts_at: Date;
          ends_at: Date;
          sender_id: string;
        }[]
      >`
        SELECT DISTINCT ON (team) id::text AS id, team::text AS team, kind::text AS kind, multiplier, starts_at, ends_at,
               sender_id::text AS sender_id
          FROM pk4_boosts
         WHERE match_id = ${row.id}::uuid AND starts_at <= ${iso(now)}::timestamptz AND ends_at > ${iso(now)}::timestamptz
           AND ${row.status === 'BATTLE'}
         ORDER BY team, multiplier DESC`,
      this.prisma.$queryRaw<{ team: PkSideName; kind: PkBoosterKindName; n: number }[]>`
        SELECT team::text AS team, kind::text AS kind, count(*)::int AS n FROM pk4_boosts
         WHERE match_id = ${row.id}::uuid GROUP BY team, kind`,
      row.status === 'BATTLE' || row.top_a === null || row.top_b === null
        ? this.prisma.$transaction((tx) => topTeamSupportersIn(tx, row.id))
        : Promise.resolve({ A: row.top_a, B: row.top_b }),
      this.boosterRules(),
    ]);
    const records = await this.prisma.pkHostRecord.findMany({
      where: { hostId: { in: seats.map((s) => s.host_id) } },
      select: { hostId: true, points: true },
    });
    const anonymous = await vipPrivacyOnIn(
      this.prisma,
      [...supporters.A, ...supporters.B].map((s) => s.userId),
      'RANKING_ANONYMOUS',
      now,
    );
    const people = await this.summaries([
      ...seats.map((s) => s.host_id),
      ...boosts.map((b) => b.sender_id),
      ...supporters.A.map((s) => s.userId),
      ...supporters.B.map((s) => s.userId),
    ]);
    const team = (t: PkSideName): Pk4TeamDto => {
      const boost = boosts.find((b) => b.team === t);
      const counts = Object.fromEntries(PK_BOOSTER_KINDS.map((k) => [k, 0])) as Record<
        PkBoosterKindName,
        number
      >;
      for (const u of uses) if (u.team === t) counts[u.kind] = u.n;
      const ended = row.status === 'RESULT' || row.status === 'CLOSED';
      const result: Pk4TeamDto['result'] =
        !ended || row.end_reason === null || row.end_reason === 'ADMIN' || row.end_reason === 'CANCELLED'
          ? null
          : row.winner_team === null
            ? 'DRAW'
            : row.winner_team === t
              ? 'WIN'
              : 'LOSS';
      return {
        team: t,
        score: Number(t === 'A' ? row.score_a : row.score_b),
        result,
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
        supporters: supporters[t]
          .filter((p) => people.has(p.userId))
          .map((p) => ({
            user: anonymous.has(p.userId) ? anonymousUserSummary() : people.get(p.userId)!,
            points: p.points,
          })),
      };
    };
    return {
      id: row.id,
      format: row.format,
      status: row.status,
      startedAt: iso(row.started_at),
      battleEndsAt: iso(row.battle_ends_at),
      endedAt: row.ended_at ? iso(row.ended_at) : null,
      resultEndsAt: row.result_ends_at ? iso(row.result_ends_at) : null,
      endReason: row.end_reason,
      winnerTeam: row.winner_team,
      seq: row.seq,
      serverTime: iso(now),
      roundSeconds: row.round_seconds,
      connectedAt: row.connected_at ? iso(row.connected_at) : null,
      effective: row.effective,
      organiserRoomId: row.organiser_room_id,
      teams: [team('A'), team('B')],
      seats: seats
        .filter((s) => people.has(s.host_id))
        .map((s) => ({
          seat: s.seat,
          team: s.team,
          roomId: s.room_id,
          host: people.get(s.host_id)!,
          score: Number(s.score),
          out: s.out_at !== null,
          outReason: s.out_reason,
          mutedRoomIds: s.muted_room_ids,
          pkPoints: records.find((r) => r.hostId === s.host_id)?.points ?? 0,
        })),
      boosters: rules,
    };
  }

  /**
   * `GET /live/rooms/{roomId}/pk4`: anyone who may watch the room. The room's open match; its host also gets their
   * OPEN lobby (organised or accepted) and an open invitation to the room.
   */
  async state(callerId: string | null, roomId: string): Promise<Pk4StateDto> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (callerId === null && !row.allow_guests) throw new AppException(ErrorCode.LIVE_GUESTS_NOT_ALLOWED);
    if (row.kicked) throw new AppException(ErrorCode.LIVE_KICKED);
    return this.stateOf(row.id, callerId !== null && callerId === row.host_user_id);
  }

  private async stateOf(roomId: string, isHost: boolean): Promise<Pk4StateDto> {
    const match = await this.openMatchOfRoom(this.prisma, roomId);
    const matchDto = match ? await this.matchDto(match) : null;
    if (!isHost) return { match: matchDto, lobby: null, invite: null };
    const now = this.clock.now();
    const lobby = await this.openLobbyOfRoom(this.prisma, roomId);
    const [invite] = await this.prisma.$queryRaw<{ id: string }[]>`
      SELECT i.id::text AS id FROM pk4_invites i JOIN pk4_lobbies l ON l.id = i.lobby_id
       WHERE i.to_room_id = ${roomId}::uuid AND i.status = 'PENDING' AND i.expires_at > ${iso(now)}::timestamptz
         AND l.status = 'OPEN' LIMIT 1`;
    return {
      match: matchDto,
      lobby: lobby && lobby.expires_at.getTime() > now.getTime() ? await this.lobbyDto(lobby.id) : null,
      invite: invite ? await this.inviteDto(invite.id) : null,
    };
  }

  /**
   * `GET /live/rooms/{roomId}/pk4/candidates`: as PK 1 v 1's list (§10.58, §10.62, §10.70) — never a host busy for
   * either PK, never one already in the caller's lobby, no block either way with any host of the caller's lobby.
   */
  async candidates(callerId: string, roomId: string, query: unknown): Promise<{ data: PkCandidateDto[] }> {
    this.assertOn();
    const own = await this.ownRoom(callerId, roomId);
    const parsed = candidatesQuerySchema.safeParse(query ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const q = parsed.data.q?.toLowerCase().replace(/[\\%_]/g, (c) => `\\${c}`) ?? '';
    const limit = parsed.data.limit ?? 20;
    const friends = parsed.data.friends === 'true';
    const now = this.clock.now();
    const lobby = await this.openLobbyOfRoom(this.prisma, own.id);
    const members = lobby
      ? await this.lobbyHosts(this.prisma, lobby)
      : [{ roomId: own.id, hostId: callerId }];
    const hostIds = [...new Set([callerId, ...members.map((m) => m.hostId)])];
    const roomIds = [...new Set([own.id, ...members.map((m) => m.roomId)])];
    const at = iso(now);
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
         AND NOT (r.host_user_id = ANY(${hostIds}::uuid[])) AND NOT (r.id = ANY(${roomIds}::uuid[]))
         AND COALESCE(s.invites_enabled, true)
         AND NOT EXISTS (SELECT 1 FROM user_blocks b
                          WHERE (b.blocker_id = ANY(${hostIds}::uuid[]) AND b.blocked_id = r.host_user_id)
                             OR (b.blocker_id = r.host_user_id AND b.blocked_id = ANY(${hostIds}::uuid[])))
         AND NOT EXISTS (SELECT 1 FROM pk_matches m WHERE m.status <> 'CLOSED'
                          AND (m.room_a_id = r.id OR m.room_b_id = r.id))
         AND NOT EXISTS (SELECT 1 FROM pk_invites i WHERE i.status = 'PENDING'
                          AND i.expires_at > ${at}::timestamptz
                          AND (i.from_room_id = r.id OR i.to_room_id = r.id))
         AND NOT ${pk4BusySql(Prisma.sql`r.id`, at)}
         AND (${q} = '' OR lower(p.username) LIKE ${q} || '%' OR lower(p.display_name) LIKE '%' || ${q} || '%')
         AND (${q} <> '' OR ${friends} OR COALESCE(s.recommendable, true))
         AND (NOT ${friends} OR (
              EXISTS (SELECT 1 FROM follows f1 WHERE f1.follower_id = ${callerId}::uuid AND f1.followee_id = r.host_user_id)
          AND EXISTS (SELECT 1 FROM follows f2 WHERE f2.follower_id = r.host_user_id AND f2.followee_id = ${callerId}::uuid)))
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

  /** The organiser and every host with an open or accepted invitation of the lobby. */
  private async lobbyHosts(
    db: Prisma.TransactionClient | PrismaService,
    lobby: LobbyRow,
  ): Promise<
    { roomId: string; hostId: string; seat: number; status: 'ORGANISER' | 'PENDING' | 'ACCEPTED' }[]
  > {
    const now = this.clock.now();
    const invites = await this.invitesOf(db, lobby.id);
    return [
      {
        roomId: lobby.organiser_room_id,
        hostId: lobby.organiser_host_id,
        seat: 1,
        status: 'ORGANISER' as const,
      },
      ...invites
        .filter(
          (i) =>
            i.status === 'ACCEPTED' || (i.status === 'PENDING' && i.expires_at.getTime() > now.getTime()),
        )
        .map((i) => ({
          roomId: i.to_room_id,
          hostId: i.to_host_id,
          seat: i.seat,
          status: i.status as 'PENDING' | 'ACCEPTED',
        })),
    ];
  }

  /**
   * Runs `fn` in a transaction holding the PK locks of every room of the lobby (and `extraRooms`), then the lobby's row
   * lock. The rooms are read first and locked in sorted order; a lobby whose rooms changed in between is read again.
   */
  private async inLobby<T>(
    lobbyId: string,
    extraRooms: readonly string[],
    fn: (tx: Prisma.TransactionClient, lobby: LobbyRow) => Promise<T>,
  ): Promise<T> {
    for (let attempt = 0; ; attempt += 1) {
      const before = await this.lobbyRow(this.prisma, Prisma.sql`id = ${lobbyId}::uuid`);
      if (!before) throw new AppException(ErrorCode.PK_LOBBY_CLOSED);
      const rooms = new Set([
        ...(await this.lobbyHosts(this.prisma, before)).map((h) => h.roomId),
        ...extraRooms,
      ]);
      try {
        return await this.prisma.$transaction(async (tx) => {
          await this.lockRooms(tx, [...rooms]);
          const lobby = await this.lobbyRow(tx, Prisma.sql`id = ${lobbyId}::uuid`, true);
          if (!lobby) throw new AppException(ErrorCode.PK_LOBBY_CLOSED);
          const now = (await this.lobbyHosts(tx, lobby)).map((h) => h.roomId);
          if (now.some((r) => !rooms.has(r))) throw new LobbyMoved();
          return fn(tx, lobby);
        }, LIVE_TX_OPTIONS);
      } catch (err) {
        if (err instanceof LobbyMoved && attempt < 3) continue;
        if (err instanceof LobbyMoved) throw new AppException(ErrorCode.PK_HOST_BUSY);
        throw err;
      }
    }
  }

  // ---- The lobby -------------------------------------------------------------------------------

  /** `POST /live/rooms/{roomId}/pk4/lobby` `{format}` (201): the caller organises a lobby (place 1, team A). */
  async openLobby(callerId: string, roomId: string, body: unknown): Promise<Pk4LobbyDto> {
    this.assertOn();
    const parsed = lobbySchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    // CP-041 phase 3: FREE_FOR_ALL is not built yet.
    if (parsed.data.format !== 'TEAMS') throw new AppException(ErrorCode.PK_UNAVAILABLE);
    const now = this.clock.now();
    const own = await this.ownEligibleRoom(callerId, roomId, now);
    const id = uuidv7();
    await this.prisma.$transaction(async (tx) => {
      await this.lockRooms(tx, [own.id]);
      // An OPEN lobby of this room past its time is closed here first (the tick may not have run yet).
      await this.expireLobbiesIn(tx, Prisma.sql`organiser_room_id = ${own.id}::uuid`, now);
      if (await this.busyIn(tx, own.id, callerId, now)) throw new AppException(ErrorCode.PK_HOST_BUSY);
      await tx.pk4Lobby.create({
        data: {
          id,
          format: 'TEAMS',
          organiserRoomId: own.id,
          organiserHostId: callerId,
          createdAt: now,
          expiresAt: new Date(now.getTime() + this.config.pk.pk4.lobbySeconds * 1000),
        },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.LIVE_PK4_LOBBY,
        actorUserId: callerId,
        targetType: 'pk4_lobby',
        targetId: id,
        metadata: { event: 'opened', format: 'TEAMS', roomId: own.id },
      });
    }, LIVE_TX_OPTIONS);
    return (await this.lobbyDto(id))!;
  }

  /** Marks OPEN lobbies past their time (matching `where`) EXPIRED with their open invitations; their ids. */
  private async expireLobbiesIn(
    tx: Prisma.TransactionClient | PrismaService,
    where: Prisma.Sql,
    now: Date,
  ): Promise<string[]> {
    const at = iso(now);
    const rows = await tx.$queryRaw<{ id: string }[]>`
      UPDATE pk4_lobbies SET status = 'EXPIRED', closed_at = expires_at
       WHERE status = 'OPEN' AND expires_at <= ${at}::timestamptz AND ${where}
       RETURNING id::text AS id`;
    if (rows.length > 0) {
      const ids = rows.map((r) => r.id);
      await tx.$executeRaw`
        UPDATE pk4_invites SET status = 'EXPIRED', handled_at = LEAST(expires_at, ${at}::timestamptz)
         WHERE status = 'PENDING' AND lobby_id = ANY(${ids}::uuid[])`;
    }
    return rows.map((r) => r.id);
  }

  /**
   * `DELETE /live/rooms/{roomId}/pk4/lobby`: the organiser cancels the OPEN lobby (every open invitation CANCELLED), or
   * an accepted host leaves it (LEFT, the place free). Neither → 409 PK_LOBBY_CLOSED.
   */
  async closeLobby(callerId: string, roomId: string): Promise<void> {
    const room = await this.ownRoom(callerId, roomId);
    const lobby = await this.openLobbyOfRoom(this.prisma, room.id);
    if (!lobby) throw new AppException(ErrorCode.PK_LOBBY_CLOSED);
    const now = this.clock.now();
    const organiser = lobby.organiser_room_id === room.id;
    const result = await this.inLobby(lobby.id, [room.id], async (tx, l) => {
      if (l.status !== 'OPEN') throw new AppException(ErrorCode.PK_LOBBY_CLOSED);
      if (organiser) {
        const pending = await tx.$queryRaw<{ id: string }[]>`
          UPDATE pk4_invites SET status = 'CANCELLED', handled_at = ${iso(now)}::timestamptz
           WHERE lobby_id = ${l.id}::uuid AND status = 'PENDING' RETURNING id::text AS id`;
        const hosts = await this.recipientsIn(tx, l);
        await tx.$executeRaw`
          UPDATE pk4_lobbies SET status = 'CANCELLED', closed_at = ${iso(now)}::timestamptz WHERE id = ${l.id}::uuid`;
        await this.audit.recordIn(tx, {
          action: AuditAction.LIVE_PK4_LOBBY,
          actorUserId: callerId,
          targetType: 'pk4_lobby',
          targetId: l.id,
          metadata: { event: 'cancelled' },
        });
        return { event: 'cancelled' as const, hosts, invites: pending.map((p) => p.id) };
      }
      const left = await tx.$executeRaw`
        UPDATE pk4_invites SET status = 'LEFT', handled_at = ${iso(now)}::timestamptz
         WHERE lobby_id = ${l.id}::uuid AND to_room_id = ${room.id}::uuid AND status = 'ACCEPTED'`;
      if (left === 0) throw new AppException(ErrorCode.PK_LOBBY_CLOSED);
      return { event: 'left' as const, hosts: [{ roomId: room.id, hostId: callerId }], invites: [] };
    });
    for (const id of result.invites) {
      const dto = await this.inviteDto(id);
      if (dto) await this.tellInvite(dto);
    }
    await this.tellLobby(lobby.id, result.event, result.hosts);
  }

  /**
   * `POST /live/rooms/{roomId}/pk4/lobby/invites` `{toRoomId, seat}` (201): the organiser invites a host to a free place.
   * Checks in the contract's order (§10.180); the invited host gets `pk4-invite`, the lobby's hosts `pk4-lobby`.
   */
  async invite(callerId: string, roomId: string, body: unknown): Promise<Pk4LobbyDto> {
    this.assertOn();
    const parsed = inviteSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const { seat } = parsed.data;
    const now = this.clock.now();
    const own = await this.ownEligibleRoom(callerId, roomId, now);
    const lobby = await this.lobbyRow(
      this.prisma,
      Prisma.sql`status = 'OPEN' AND organiser_room_id = ${own.id}::uuid AND expires_at > ${iso(now)}::timestamptz`,
    );
    if (!lobby) throw new AppException(ErrorCode.PK_LOBBY_CLOSED);
    const hosts = await this.lobbyHosts(this.prisma, lobby);
    if (hosts.some((h) => h.seat === seat)) throw new AppException(ErrorCode.PK_SEAT_TAKEN);
    const targetRow = await this.rooms.visibleRow(parsed.data.toRoomId, callerId);
    if (hosts.some((h) => h.roomId === targetRow.id || h.hostId === targetRow.host_user_id)) {
      throw AppException.validation([{ field: 'toRoomId', issue: 'invalid_value' }]);
    }
    const target = await this.roomState(this.prisma, targetRow.id);
    if (!this.eligible(target, now)) throw new AppException(ErrorCode.PK_UNAVAILABLE);
    const settings = await this.prisma.pkHostSettings.findUnique({
      where: { hostId: targetRow.host_user_id },
      select: { invitesEnabled: true },
    });
    if (settings && !settings.invitesEnabled) throw new AppException(ErrorCode.PK_INVITES_OFF);
    if (
      await this.blockedWithAny(
        this.prisma,
        targetRow.host_user_id,
        hosts.map((h) => h.hostId),
      )
    ) {
      throw new AppException(ErrorCode.NOT_FOUND);
    }
    const id = uuidv7();
    await this.inLobby(lobby.id, [targetRow.id], async (tx, l) => {
      if (l.status !== 'OPEN' || l.expires_at.getTime() <= now.getTime()) {
        throw new AppException(ErrorCode.PK_LOBBY_CLOSED);
      }
      // An open invitation past its time is closed here first.
      await tx.$executeRaw`
        UPDATE pk4_invites SET status = 'EXPIRED', handled_at = expires_at
         WHERE status = 'PENDING' AND expires_at <= ${iso(now)}::timestamptz
           AND (lobby_id = ${l.id}::uuid OR to_room_id = ${targetRow.id}::uuid)`;
      const current = await this.lobbyHosts(tx, l);
      if (current.some((h) => h.seat === seat)) throw new AppException(ErrorCode.PK_SEAT_TAKEN);
      if (current.some((h) => h.roomId === targetRow.id || h.hostId === targetRow.host_user_id)) {
        throw AppException.validation([{ field: 'toRoomId', issue: 'invalid_value' }]);
      }
      if (
        await this.blockedWithAny(
          tx,
          targetRow.host_user_id,
          current.map((h) => h.hostId),
        )
      ) {
        throw new AppException(ErrorCode.NOT_FOUND);
      }
      // §10.70: a host waiting in the random queue may be invited (accepting ends the wait).
      if (await this.busyIn(tx, targetRow.id, targetRow.host_user_id, now, { ignoreQueue: true })) {
        throw new AppException(ErrorCode.PK_HOST_BUSY);
      }
      const expiresAt = Math.min(
        now.getTime() + this.config.pk.pk4.inviteTtlSeconds * 1000,
        l.expires_at.getTime(),
      );
      await tx.pk4Invite.create({
        data: {
          id,
          lobbyId: l.id,
          seat,
          team: teamOfSeat(seat),
          toRoomId: targetRow.id,
          toHostId: targetRow.host_user_id,
          createdAt: now,
          expiresAt: new Date(expiresAt),
        },
      });
    });
    const dto = await this.inviteDto(id);
    if (dto) await this.tellInvite(dto);
    await this.tellLobby(lobby.id, 'invited');
    return (await this.lobbyDto(lobby.id))!;
  }

  /** `DELETE …/pk4/lobby/invites/{inviteId}`: the organiser takes an open invitation back. */
  async cancelInvite(callerId: string, roomId: string, inviteId: string): Promise<void> {
    const room = await this.ownRoom(callerId, roomId);
    const invite = await this.inviteRow(this.prisma, inviteId);
    const lobby = invite ? await this.lobbyRow(this.prisma, Prisma.sql`id = ${invite.lobby_id}::uuid`) : null;
    if (!invite || !lobby || lobby.organiser_room_id !== room.id) throw new AppException(ErrorCode.NOT_FOUND);
    await this.answerInvite(invite.id, 'CANCELLED');
    const dto = await this.inviteDto(invite.id);
    if (dto) await this.tellInvite(dto);
    await this.tellLobby(lobby.id, 'invite-cancelled', [
      { roomId: invite.to_room_id, hostId: invite.to_host_id },
    ]);
  }

  /** `POST …/pk4/invites/{inviteId}/decline`: the invited host says no; the place is free again. */
  async decline(callerId: string, roomId: string, inviteId: string): Promise<void> {
    const room = await this.ownRoom(callerId, roomId);
    const invite = await this.inviteRow(this.prisma, inviteId);
    if (!invite || invite.to_room_id !== room.id) throw new AppException(ErrorCode.NOT_FOUND);
    await this.answerInvite(invite.id, 'DECLINED');
    await this.tellLobby(invite.lobby_id, 'declined', [{ roomId: room.id, hostId: callerId }]);
  }

  /** PENDING → `status` under the row lock; an expired one is stored as EXPIRED, then 409 PK_INVITE_CLOSED. */
  private async answerInvite(inviteId: string, status: 'CANCELLED' | 'DECLINED'): Promise<void> {
    const now = this.clock.now();
    const outcome: { closed: boolean } = { closed: false };
    await this.prisma.$transaction(async (tx) => {
      const invite = await this.inviteRow(tx, inviteId, true);
      if (!invite || invite.status !== 'PENDING') {
        outcome.closed = true;
        return;
      }
      if (invite.expires_at.getTime() <= now.getTime()) {
        await tx.$executeRaw`UPDATE pk4_invites SET status = 'EXPIRED', handled_at = expires_at WHERE id = ${invite.id}::uuid`;
        outcome.closed = true;
        return;
      }
      await tx.$executeRaw`
        UPDATE pk4_invites SET status = ${status}::pk4_invite_status, handled_at = ${iso(now)}::timestamptz
         WHERE id = ${invite.id}::uuid`;
    }, LIVE_TX_OPTIONS);
    if (outcome.closed) throw new AppException(ErrorCode.PK_INVITE_CLOSED);
  }

  /**
   * `POST …/pk4/invites/{inviteId}/accept`: the invited host takes the place. The third acceptance (all four in) starts
   * the match under the four rooms' PK locks (§10.180).
   */
  async accept(callerId: string, roomId: string, inviteId: string): Promise<Pk4StateDto> {
    this.assertOn();
    const room = await this.ownRoom(callerId, roomId);
    const first = await this.inviteRow(this.prisma, inviteId);
    if (!first || first.to_room_id !== room.id) throw new AppException(ErrorCode.NOT_FOUND);
    const now = this.clock.now();
    const outcome: { refused: AppException | null; matchId: string | null; dropped: string[] } = {
      refused: null,
      matchId: null,
      dropped: [],
    };
    await this.inLobby(first.lobby_id, [room.id], async (tx, lobby) => {
      const invite = (await this.inviteRow(tx, first.id, true))!;
      if (invite.status !== 'PENDING') throw new AppException(ErrorCode.PK_INVITE_CLOSED);
      if (invite.expires_at.getTime() <= now.getTime()) {
        await tx.$executeRaw`UPDATE pk4_invites SET status = 'EXPIRED', handled_at = expires_at WHERE id = ${invite.id}::uuid`;
        outcome.refused = new AppException(ErrorCode.PK_INVITE_CLOSED);
        return;
      }
      if (lobby.status !== 'OPEN' || lobby.expires_at.getTime() <= now.getTime()) {
        throw new AppException(ErrorCode.PK_LOBBY_CLOSED);
      }
      const hosts = await this.lobbyHosts(tx, lobby);
      const [mine, organiser] = await Promise.all([
        this.roomState(tx, room.id),
        this.roomState(tx, lobby.organiser_room_id),
      ]);
      if (
        !this.eligible(mine, now) ||
        !this.eligible(organiser, now) ||
        (await this.blockedWithAny(
          tx,
          callerId,
          hosts.map((h) => h.hostId),
        ))
      ) {
        await tx.$executeRaw`UPDATE pk4_invites SET status = 'CANCELLED', handled_at = ${iso(now)}::timestamptz WHERE id = ${invite.id}::uuid`;
        outcome.refused = new AppException(ErrorCode.PK_UNAVAILABLE);
        return;
      }
      if (await this.busyIn(tx, room.id, callerId, now, { ignoreQueue: true, exceptInviteId: invite.id })) {
        throw new AppException(ErrorCode.PK_HOST_BUSY);
      }
      await tx.$executeRaw`
        UPDATE pk4_invites SET status = 'ACCEPTED', handled_at = ${iso(now)}::timestamptz WHERE id = ${invite.id}::uuid`;
      // §10.70: accepting ends the caller's random-queue wait.
      await tx.pkQueueEntry.deleteMany({ where: { hostId: callerId } });
      const accepted = (await this.lobbyHosts(tx, lobby)).filter((h) => h.status !== 'PENDING');
      if (accepted.length < 4) return;
      // All four in: fresh checks over the four rooms (another place's live may have ended meanwhile).
      for (const h of accepted) {
        if (h.status !== 'ACCEPTED' || h.roomId === room.id) continue;
        if (!this.eligible(await this.roomState(tx, h.roomId), now)) {
          await tx.$executeRaw`
            UPDATE pk4_invites SET status = 'LEFT', handled_at = ${iso(now)}::timestamptz
             WHERE lobby_id = ${lobby.id}::uuid AND to_room_id = ${h.roomId}::uuid AND status = 'ACCEPTED'`;
          outcome.dropped.push(h.roomId);
        }
      }
      if (outcome.dropped.length > 0) return;
      for (const h of accepted) {
        if (
          await this.blockedWithAny(
            tx,
            h.hostId,
            accepted.map((x) => x.hostId),
          )
        ) {
          await tx.$executeRaw`UPDATE pk4_invites SET status = 'CANCELLED', handled_at = ${iso(now)}::timestamptz WHERE id = ${invite.id}::uuid`;
          outcome.refused = new AppException(ErrorCode.PK_UNAVAILABLE);
          return;
        }
      }
      outcome.matchId = await this.createMatchIn(tx, lobby, accepted, now);
    });
    if (outcome.matchId) {
      await this.broadcastMatch(outcome.matchId, await this.startEvent(outcome.matchId));
      await this.tellLobby(first.lobby_id, 'started');
    } else {
      await this.tellLobby(first.lobby_id, outcome.dropped.length > 0 ? 'left' : 'accepted', [
        { roomId: room.id, hostId: callerId },
      ]);
    }
    if (outcome.refused) throw outcome.refused;
    return this.stateOf(room.id, true);
  }

  private async startEvent(matchId: string): Promise<Pk4MatchEvent> {
    const row = await this.matchRow(this.prisma, Prisma.sql`id = ${matchId}::uuid`);
    return row?.status === 'CONNECTED' ? 'connected' : 'started';
  }

  /**
   * Creates the match of a full lobby (under the four rooms' locks and the lobby's row lock): the organiser's round time
   * and auto-start (§10.62); the four hosts leave the random queue; the lobby STARTED; audited `live.pk4.start`.
   */
  private async createMatchIn(
    tx: Prisma.TransactionClient,
    lobby: LobbyRow,
    hosts: readonly { roomId: string; hostId: string; seat: number }[],
    now: Date,
  ): Promise<string> {
    const s = await tx.pkHostSettings.findUnique({ where: { hostId: lobby.organiser_host_id } });
    const roundSeconds =
      s?.roundMinutes !== null && s?.roundMinutes !== undefined
        ? s.roundMinutes * 60
        : this.config.pk.battleSeconds;
    const connected = !(s?.autoStart ?? true);
    const id = uuidv7();
    await tx.pk4Match.create({
      data: {
        id,
        lobbyId: lobby.id,
        format: lobby.format,
        status: connected ? 'CONNECTED' : 'BATTLE',
        organiserRoomId: lobby.organiser_room_id,
        startedAt: now,
        battleEndsAt: new Date(
          now.getTime() + (connected ? this.config.pk.connectSeconds : roundSeconds) * 1000,
        ),
        connectedAt: connected ? now : null,
        roundSeconds,
        seq: 1,
      },
    });
    await tx.pk4Seat.createMany({
      data: [...hosts]
        .sort((a, b) => a.seat - b.seat)
        .map((h) => ({
          matchId: id,
          seat: h.seat,
          team: teamOfSeat(h.seat),
          roomId: h.roomId,
          hostId: h.hostId,
        })),
    });
    await tx.$executeRaw`
      UPDATE pk4_lobbies SET status = 'STARTED', closed_at = ${iso(now)}::timestamptz, match_id = ${id}::uuid
       WHERE id = ${lobby.id}::uuid`;
    await tx.pkQueueEntry.deleteMany({ where: { hostId: { in: hosts.map((h) => h.hostId) } } });
    await this.audit.recordIn(tx, {
      action: AuditAction.LIVE_PK4_START,
      actorUserId: lobby.organiser_host_id,
      targetType: 'pk4_match',
      targetId: id,
      metadata: {
        format: lobby.format,
        lobbyId: lobby.id,
        rooms: [...hosts].sort((a, b) => a.seat - b.seat).map((h) => h.roomId),
        roundSeconds,
        autoStart: !connected,
      },
    });
    return id;
  }

  // ---- The match -------------------------------------------------------------------------------

  /** `POST …/pk4/start`: any of the four hosts starts a CONNECTED match (idempotent once running). */
  async start(callerId: string, roomId: string): Promise<Pk4MatchDto> {
    this.assertOn();
    const room = await this.ownRoom(callerId, roomId);
    const now = this.clock.now();
    const match = await this.openMatchOfRoom(this.prisma, room.id);
    if (!match || match.status === 'RESULT') throw new AppException(ErrorCode.PK_NOT_ACTIVE);
    if (match.status === 'BATTLE') return this.matchDto(match);
    const changed = await this.prisma.$executeRaw`
      UPDATE pk4_matches
         SET status = 'BATTLE', started_at = ${iso(now)}::timestamptz,
             battle_ends_at = ${iso(now)}::timestamptz + make_interval(secs => round_seconds), seq = seq + 1
       WHERE id = ${match.id}::uuid AND status = 'CONNECTED'`;
    if (changed > 0) return (await this.broadcastMatch(match.id, 'started'))!;
    return this.matchDto((await this.matchRow(this.prisma, Prisma.sql`id = ${match.id}::uuid`))!);
  }

  /**
   * `POST …/pk4/end`: during the battle the caller is out (FORFEIT) — the teammate carries on; CONNECTED → CANCELLED;
   * RESULT → CLOSED for the four rooms.
   */
  async end(callerId: string, roomId: string): Promise<Pk4MatchDto> {
    const room = await this.ownRoom(callerId, roomId);
    const match = await this.openMatchOfRoom(this.prisma, room.id);
    if (!match) throw new AppException(ErrorCode.PK_NOT_ACTIVE);
    if (match.status === 'CONNECTED') {
      await this.cancelConnected(match.id);
    } else if (match.status === 'BATTLE') {
      const seats = await this.seatsOf(this.prisma, match.id);
      const mine = seats.find((s) => s.room_id === room.id)!;
      await this.settleOuts(match.id, [{ seat: mine.seat, reason: 'FORFEIT' }], callerId);
    } else {
      await this.closeResult(match.id);
    }
    return this.matchDto((await this.matchRow(this.prisma, Prisma.sql`id = ${match.id}::uuid`))!);
  }

  /** `POST …/pk4/mute` `{roomId, muted}`: a host mutes one of the other three hosts for their own room. */
  async mute(callerId: string, roomId: string, body: unknown): Promise<Pk4MatchDto> {
    const parsed = muteSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const room = await this.ownRoom(callerId, roomId);
    const match = await this.openMatchOfRoom(this.prisma, room.id);
    if (!match) throw new AppException(ErrorCode.PK_NOT_ACTIVE);
    const seats = await this.seatsOf(this.prisma, match.id);
    const other = parsed.data.roomId.toLowerCase();
    if (other === room.id || !seats.some((s) => s.room_id === other)) {
      throw AppException.validation([{ field: 'roomId', issue: 'invalid_value' }]);
    }
    const changed = parsed.data.muted
      ? await this.prisma.$executeRaw`
          UPDATE pk4_seats SET muted_room_ids = array_append(muted_room_ids, ${other}::uuid)
           WHERE match_id = ${match.id}::uuid AND room_id = ${room.id}::uuid AND active
             AND NOT (${other}::uuid = ANY(muted_room_ids))`
      : await this.prisma.$executeRaw`
          UPDATE pk4_seats SET muted_room_ids = array_remove(muted_room_ids, ${other}::uuid)
           WHERE match_id = ${match.id}::uuid AND room_id = ${room.id}::uuid AND active
             AND ${other}::uuid = ANY(muted_room_ids)`;
    if (changed > 0) {
      await this.prisma.$executeRaw`UPDATE pk4_matches SET seq = seq + 1 WHERE id = ${match.id}::uuid`;
      return (await this.broadcastMatch(match.id, 'mute'))!;
    }
    return this.matchDto((await this.matchRow(this.prisma, Prisma.sql`id = ${match.id}::uuid`))!);
  }

  /** A CONNECTED match that never started is closed at once — void (CANCELLED). */
  private async cancelConnected(matchId: string): Promise<boolean> {
    const now = iso(this.clock.now());
    const changed = await this.prisma.$transaction(async (tx) => {
      const n = await tx.$executeRaw`
        UPDATE pk4_matches
           SET status = 'CLOSED', ended_at = ${now}::timestamptz, result_ends_at = ${now}::timestamptz,
               closed_at = ${now}::timestamptz, end_reason = 'CANCELLED', effective = false, seq = seq + 1,
               top_a = '[]'::jsonb, top_b = '[]'::jsonb
         WHERE id = ${matchId}::uuid AND status = 'CONNECTED'`;
      if (n > 0) await tx.$executeRaw`UPDATE pk4_seats SET active = false WHERE match_id = ${matchId}::uuid`;
      return n;
    }, LIVE_TX_OPTIONS);
    if (changed === 0) return false;
    await this.afterClose(matchId);
    return true;
  }

  /**
   * Marks places out of the battle (under the match row lock; nothing when it is no longer BATTLE or they are already
   * out). Both hosts of a team out → the other team wins; all four → a void draw (§10.180). Audited `live.pk4.out`.
   */
  private async settleOuts(
    matchId: string,
    outs: readonly { seat: number; reason: 'FORFEIT' | 'DISCONNECT' | 'AWAY' }[],
    actorId: string | null,
  ): Promise<'out' | 'ended' | false> {
    const now = this.clock.now();
    const done = await this.prisma.$transaction(async (tx): Promise<'out' | 'ended' | false> => {
      const m = await this.matchRow(tx, Prisma.sql`id = ${matchId}::uuid`, true);
      if (!m || m.status !== 'BATTLE') return false;
      const seats = await this.seatsOf(tx, matchId);
      const fresh = outs.filter((o) => seats.some((s) => s.seat === o.seat && s.out_at === null));
      if (fresh.length === 0) return false;
      for (const o of fresh) {
        await tx.$executeRaw`
          UPDATE pk4_seats SET out_at = ${iso(now)}::timestamptz, out_reason = ${o.reason}::pk_end_reason
           WHERE match_id = ${matchId}::uuid AND seat = ${o.seat} AND out_at IS NULL`;
        const seat = seats.find((s) => s.seat === o.seat)!;
        await this.audit.recordIn(tx, {
          action: AuditAction.LIVE_PK4_OUT,
          actorUserId: actorId,
          targetType: 'pk4_match',
          targetId: matchId,
          metadata: { seat: o.seat, team: seat.team, host: seat.host_id, reason: o.reason },
        });
      }
      const presence = seats.map((s) => ({
        seat: s.seat,
        team: s.team,
        out: s.out_reason ?? fresh.find((o) => o.seat === s.seat)?.reason ?? null,
      }));
      const outcome = teamsOutcome(presence, fresh[fresh.length - 1]!.reason);
      if (outcome.kind === 'continue') {
        await tx.$executeRaw`UPDATE pk4_matches SET seq = seq + 1 WHERE id = ${matchId}::uuid`;
        return 'out';
      }
      await this.finishIn(
        tx,
        m,
        {
          reason: outcome.reason,
          winner: outcome.winner,
          loserCause: outcome.loserCause,
          everyoneGone: outcome.winner === null,
        },
        actorId,
        now,
      );
      return 'ended';
    }, LIVE_TX_OPTIONS);
    if (done) await this.broadcastMatch(matchId, done);
    return done;
  }

  /** The battle's time ran out: the higher team sum wins (equal: a draw). */
  private async finishByTime(matchId: string): Promise<boolean> {
    const now = this.clock.now();
    const done = await this.prisma.$transaction(async (tx) => {
      const m = await this.matchRow(tx, Prisma.sql`id = ${matchId}::uuid`, true);
      if (!m || m.status !== 'BATTLE' || m.battle_ends_at.getTime() > now.getTime()) return false;
      await this.finishIn(
        tx,
        m,
        { reason: 'TIME', winner: null, loserCause: null, everyoneGone: false },
        null,
        now,
      );
      return true;
    }, LIVE_TX_OPTIONS);
    if (done) await this.broadcastMatch(matchId, 'ended');
    return done;
  }

  /**
   * BATTLE → RESULT in the caller's transaction (the match row locked): the winner, `effective`, the top three
   * supporters per team frozen, and — when it counts — a win, loss or draw for each of the four hosts with the PK
   * points of `pk_dare_settings` (once per match and host). Audited `live.pk4.end`.
   */
  private async finishIn(
    tx: Prisma.TransactionClient,
    m: MatchRow,
    finish: Finish,
    actorId: string | null,
    now: Date,
  ): Promise<void> {
    const endedAt = finish.reason === 'TIME' ? m.battle_ends_at : now;
    const winner = finish.reason === 'TIME' ? teamWinnerByScore(m.score_a, m.score_b) : finish.winner;
    const effective = isEffectivePk4({
      reason: finish.reason,
      everyoneGone: finish.everyoneGone,
      total: m.score_a + m.score_b,
      minPoints: this.config.pk.effectiveMinPoints,
    });
    const resultEndsAt = new Date(endedAt.getTime() + this.config.pk.resultSeconds * 1000);
    const top = await topTeamSupportersIn(tx, m.id);
    await tx.$executeRaw`
      UPDATE pk4_matches
         SET status = 'RESULT', ended_at = ${iso(endedAt)}::timestamptz,
             result_ends_at = ${iso(resultEndsAt)}::timestamptz, end_reason = ${finish.reason}::pk_end_reason,
             winner_team = ${winner}::pk_side, loser_cause = ${finish.loserCause}::pk_side, seq = seq + 1,
             effective = ${effective}, top_a = ${JSON.stringify(top.A)}::jsonb, top_b = ${JSON.stringify(top.B)}::jsonb
       WHERE id = ${m.id}::uuid`;
    if (effective) {
      const values = await pkDareSettingsIn(tx);
      for (const seat of await this.seatsOf(tx, m.id)) {
        const kind = winner === null ? 'DRAW' : seat.team === winner ? 'WIN' : 'LOSS';
        await this.addPointsIn(tx, {
          matchId: m.id,
          hostId: seat.host_id,
          kind,
          points: kind === 'WIN' ? values.winPoints : kind === 'LOSS' ? values.lossPoints : values.drawPoints,
          now,
        });
      }
    }
    await this.audit.recordIn(tx, {
      action: AuditAction.LIVE_PK4_END,
      actorUserId: actorId,
      targetType: 'pk4_match',
      targetId: m.id,
      metadata: {
        reason: finish.reason,
        winner,
        loserCause: finish.loserCause,
        everyoneGone: finish.everyoneGone,
        scoreA: Number(m.score_a),
        scoreB: Number(m.score_b),
        effective,
      },
    });
  }

  /** The record and the PK points of one host for one 4-way match (idempotent by (match, host, kind)). */
  private async addPointsIn(
    tx: Prisma.TransactionClient,
    input: { matchId: string; hostId: string; kind: 'WIN' | 'LOSS' | 'DRAW'; points: number; now: Date },
  ): Promise<void> {
    const at = iso(input.now);
    const inserted = await tx.$executeRaw`
      INSERT INTO pk4_point_events (match_id, host_id, kind, points, created_at)
      VALUES (${input.matchId}::uuid, ${input.hostId}::uuid, ${input.kind}, ${input.points}, ${at}::timestamptz)
      ON CONFLICT DO NOTHING`;
    if (inserted === 0) return;
    const one = (k: string) => (input.kind === k ? 1 : 0);
    await tx.$executeRaw`
      INSERT INTO pk_host_records (host_id, wins, losses, draws, points, dares_points, dares_done, dares_refused, updated_at)
      VALUES (${input.hostId}::uuid, ${one('WIN')}, ${one('LOSS')}, ${one('DRAW')}, ${input.points}, 0, 0, 0, ${at}::timestamptz)
      ON CONFLICT (host_id) DO UPDATE
         SET wins = pk_host_records.wins + EXCLUDED.wins, losses = pk_host_records.losses + EXCLUDED.losses,
             draws = pk_host_records.draws + EXCLUDED.draws, points = pk_host_records.points + EXCLUDED.points,
             updated_at = EXCLUDED.updated_at`;
    await this.audit.recordIn(tx, {
      action: AuditAction.LIVE_PK_POINTS,
      actorUserId: null,
      targetType: 'pk4_match',
      targetId: input.matchId,
      metadata: { host: input.hostId, kind: input.kind, points: input.points },
    });
  }

  /** RESULT → CLOSED (nothing when it is no longer RESULT); the four rooms told, watchers removed. */
  private async closeResult(matchId: string): Promise<boolean> {
    const now = this.clock.now();
    const closed = await this.prisma.$transaction(async (tx) => {
      const n = await tx.$executeRaw`
        UPDATE pk4_matches SET status = 'CLOSED', closed_at = ${iso(now)}::timestamptz, seq = seq + 1
         WHERE id = ${matchId}::uuid AND status = 'RESULT'`;
      if (n > 0) await tx.$executeRaw`UPDATE pk4_seats SET active = false WHERE match_id = ${matchId}::uuid`;
      return n;
    }, LIVE_TX_OPTIONS);
    if (closed === 0) return false;
    await this.afterClose(matchId);
    return true;
  }

  /** Tells the four rooms a match is CLOSED and disconnects its `pk4:` watchers from the four media rooms. */
  private async afterClose(matchId: string): Promise<void> {
    const dto = await this.broadcastMatch(matchId, 'closed');
    if (!dto) return;
    const prefix = `${PK4_IDENTITY_PREFIX}${matchId}:`;
    for (const seat of dto.seats) {
      try {
        const identities = await this.media.listIdentities(seat.roomId);
        for (const identity of identities.filter((i) => i.startsWith(prefix))) {
          await this.media.removeParticipant(seat.roomId, identity);
        }
      } catch (err) {
        this.logger.warn({ error: safeErrorLog(err) }, 'Could not remove PK4 watchers from a media room');
      }
    }
  }

  /** Sends the match to the four rooms (`pk4-match`); returns it (null when it does not exist). */
  private async broadcastMatch(
    matchId: string,
    event: Pk4MatchEvent,
    boost?: Pk4MatchData['boost'],
  ): Promise<Pk4MatchDto | null> {
    const row = await this.matchRow(this.prisma, Prisma.sql`id = ${matchId}::uuid`);
    if (!row) return null;
    const match = await this.matchDto(row);
    const payload = JSON.stringify({
      type: 'pk4-match',
      event,
      match,
      ...(boost ? { boost } : {}),
    } satisfies Pk4MatchData);
    for (const seat of match.seats) {
      try {
        await this.media.broadcastData(seat.roomId, PK_TOPIC, payload);
      } catch (err) {
        this.logger.warn({ error: safeErrorLog(err) }, 'Could not send a PK4 data message to a media room');
      }
    }
    return match;
  }

  /** The organiser and the hosts with an open or accepted invitation (each in their own room). */
  private async recipientsIn(
    db: Prisma.TransactionClient | PrismaService,
    lobby: LobbyRow,
  ): Promise<{ roomId: string; hostId: string }[]> {
    return (await this.lobbyHosts(db, lobby)).map((h) => ({ roomId: h.roomId, hostId: h.hostId }));
  }

  /** Sends `pk4-lobby` to every host of the lobby (and `extra`, e.g. the host the event is about). */
  private async tellLobby(
    lobbyId: string,
    event: Pk4LobbyEvent,
    extra: readonly { roomId: string; hostId: string }[] = [],
  ): Promise<void> {
    const lobby = await this.lobbyRow(this.prisma, Prisma.sql`id = ${lobbyId}::uuid`);
    const dto = await this.lobbyDto(lobbyId);
    if (!lobby || !dto) return;
    // A started lobby's members are its accepted hosts (their invitations stay ACCEPTED).
    const targets = new Map<string, string>();
    for (const t of [...(await this.recipientsIn(this.prisma, lobby)), ...extra])
      targets.set(t.roomId, t.hostId);
    const payload = JSON.stringify({ type: 'pk4-lobby', event, lobby: dto } satisfies Pk4LobbyData);
    for (const [room, identity] of targets) {
      try {
        await this.media.sendData(room, identity, payload);
      } catch (err) {
        this.logger.warn({ error: safeErrorLog(err) }, 'Could not send a PK4 lobby data message');
      }
    }
  }

  /** Sends `pk4-invite` to the invited host. */
  private async tellInvite(invite: Pk4InviteDto): Promise<void> {
    try {
      await this.media.sendData(
        invite.toRoomId,
        invite.to.id,
        JSON.stringify({ type: 'pk4-invite', invite } satisfies Pk4InviteData),
      );
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not send a PK4 invitation data message');
    }
  }

  // ---- Gifts (called by LiveGiftsService inside the send's transaction) ------------------------

  /** Whether a room has an open 4-way place (then the 4-way rules decide its gifts' PK points, not PK 1 v 1's). */
  async inMatchIn(tx: Prisma.TransactionClient, roomId: string): Promise<boolean> {
    const [row] = await tx.$queryRaw<{ ok: boolean }[]>`
      SELECT EXISTS (SELECT 1 FROM pk4_seats WHERE active AND room_id = ${roomId}::uuid) AS ok`;
    return row?.ok === true;
  }

  /**
   * In a gift send's transaction, for a room with an open 4-way place: during the battle, the send's real coin value ×
   * the TEAM's active multiplier becomes the host's PK points and the team's (one row per send), the sender's support
   * of the team grows, and a booster gift starts the team's booster (§10.58's rules with the uses per team; a refusal
   * rolls the whole send back: 409 PK_BOOSTER_UNAVAILABLE). A host out of the battle: nothing counts in their room.
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
  ): Promise<Pk4GiftCredit | null> {
    const m = await this.matchRow(
      tx,
      Prisma.sql`status = 'BATTLE' AND id = (SELECT match_id FROM pk4_seats WHERE active AND room_id = ${input.roomId}::uuid LIMIT 1)`,
      true,
    );
    const [seat] = m
      ? await tx.$queryRaw<SeatRow[]>(
          Prisma.sql`SELECT ${Prisma.raw(SEAT_COLUMNS)} FROM pk4_seats
            WHERE match_id = ${m.id}::uuid AND room_id = ${input.roomId}::uuid`,
        )
      : [];
    const remainingMs = m ? m.battle_ends_at.getTime() - input.now.getTime() : 0;
    const counts = m !== null && seat !== undefined && seat.out_at === null && remainingMs > 0;
    if (input.booster !== null && (!counts || !this.config.pk.enabled)) {
      throw new AppException(ErrorCode.PK_BOOSTER_UNAVAILABLE, undefined, [
        { field: 'giftCode', issue: 'no_match' },
      ]);
    }
    if (!counts) return null;
    const team = seat.team;
    const at = iso(input.now);
    const [active] = await tx.$queryRaw<{ id: string; multiplier: number }[]>`
      SELECT id::text AS id, multiplier FROM pk4_boosts
       WHERE match_id = ${m.id}::uuid AND team = ${team}::pk_side
         AND starts_at <= ${at}::timestamptz AND ends_at > ${at}::timestamptz
       ORDER BY multiplier DESC LIMIT 1`;
    const activeMultiplier = active?.multiplier ?? 1;
    let boosted: Pk4GiftCredit['boosted'] = null;
    if (input.booster !== null) {
      const rule = boosterRule(this.config.pk.boosters, input.booster);
      const [used] = await tx.$queryRaw<{ n: number }[]>`
        SELECT count(*)::int AS n FROM pk4_boosts
         WHERE match_id = ${m.id}::uuid AND team = ${team}::pk_side AND kind = ${input.booster}::pk_booster_kind`;
      const problem = boosterProblem({ rule, remainingMs, used: used?.n ?? 0, activeMultiplier });
      if (problem) {
        throw new AppException(ErrorCode.PK_BOOSTER_UNAVAILABLE, undefined, [
          { field: 'giftCode', issue: problem },
        ]);
      }
      if (active) {
        await tx.$executeRaw`UPDATE pk4_boosts SET ends_at = ${at}::timestamptz, replaced = true WHERE id = ${active.id}::uuid`;
      }
      const endsAt = new Date(input.now.getTime() + rule.durationSeconds * 1000);
      await tx.$executeRaw`
        INSERT INTO pk4_boosts (id, match_id, team, kind, multiplier, gift_id, gift_code, sender_id, room_id, starts_at, ends_at)
        VALUES (${uuidv7()}::uuid, ${m.id}::uuid, ${team}::pk_side, ${input.booster}::pk_booster_kind, ${rule.multiplier},
                ${input.giftId}::uuid, ${input.giftCode}, ${input.senderId}::uuid, ${input.roomId}::uuid,
                ${at}::timestamptz, ${iso(endsAt)}::timestamptz)`;
      boosted = { team, roomId: input.roomId, kind: input.booster, multiplier: rule.multiplier, endsAt };
    }
    const coins = BigInt(input.coins);
    const multiplier = input.booster !== null ? 1 : activeMultiplier;
    const points = pkPoints(coins, multiplier);
    if (points > 0n) {
      const inserted = await tx.$executeRaw`
        INSERT INTO pk4_gift_points (gift_id, match_id, seat, team, sender_id, coins, multiplier, points, created_at)
        VALUES (${input.giftId}::uuid, ${m.id}::uuid, ${seat.seat}, ${team}::pk_side, ${input.senderId}::uuid, ${coins},
                ${multiplier}, ${points}, ${at}::timestamptz)
        ON CONFLICT (gift_id) DO NOTHING`;
      if (inserted > 0) {
        await tx.$executeRaw`
          UPDATE pk4_seats SET score = score + ${points} WHERE match_id = ${m.id}::uuid AND seat = ${seat.seat}`;
        if (team === 'A') {
          await tx.$executeRaw`UPDATE pk4_matches SET score_a = score_a + ${points}, seq = seq + 1 WHERE id = ${m.id}::uuid`;
        } else {
          await tx.$executeRaw`UPDATE pk4_matches SET score_b = score_b + ${points}, seq = seq + 1 WHERE id = ${m.id}::uuid`;
        }
        await tx.$executeRaw`
          INSERT INTO pk4_supporters (match_id, team, user_id, points)
          VALUES (${m.id}::uuid, ${team}::pk_side, ${input.senderId}::uuid, ${points})
          ON CONFLICT (match_id, team, user_id) DO UPDATE SET points = pk4_supporters.points + EXCLUDED.points`;
      }
    } else if (boosted) {
      await tx.$executeRaw`UPDATE pk4_matches SET seq = seq + 1 WHERE id = ${m.id}::uuid`;
    }
    return { matchId: m.id, boosted };
  }

  /** After a send's commit: a booster at once, a score within PK_SCORE_BROADCAST_MS. */
  async afterGift(credit: Pk4GiftCredit): Promise<void> {
    if (credit.boosted) {
      const b = credit.boosted;
      await this.broadcastMatch(credit.matchId, 'boost', {
        team: b.team,
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
   * `POST …/pk4/media-token`: watch-only, hidden tokens for the three other rooms (identity `pk4:<matchId>:<base>`).
   * A room the caller may not watch is left out; PK4_MAX_WATCHERS_PER_ROOM reached → left out and `capped`.
   */
  async mediaToken(callerId: string | null, roomId: string, body: unknown): Promise<Pk4MediaAccessDto> {
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
    const seats = await this.seatsOf(this.prisma, match.id);
    let name = 'Guest';
    const base = guestId !== undefined ? `guest:${guestId}` : callerId!;
    if (callerId !== null) {
      const me = await this.users.getMe(callerId);
      name = me?.displayName || me?.username || '';
    }
    const identity = pk4Identity(match.id, base);
    const ttl = 600;
    const cap = this.config.pk.pk4.maxWatchersPerRoom;
    let capped = false;
    const rooms: Pk4MediaAccessDto['rooms'] = [];
    for (const seat of seats.filter((s) => s.room_id !== row.id)) {
      try {
        const other = await this.rooms.visibleRow(seat.room_id, callerId);
        if (guestId !== undefined && !other.allow_guests) continue;
      } catch (err) {
        if (err instanceof AppException) continue;
        throw err;
      }
      if (cap > 0) {
        const watchers = (await this.media.listIdentities(seat.room_id)).filter(
          (i) => i.startsWith(PK4_IDENTITY_PREFIX) && i !== identity,
        );
        if (watchers.length >= cap) {
          capped = true;
          continue;
        }
      }
      const token = await this.media.issueToken({
        room: seat.room_id,
        identity,
        name,
        publish: false,
        ttlSeconds: ttl,
      });
      rooms.push({ roomId: seat.room_id, token, identity, hostIdentity: seat.host_id });
    }
    return {
      url: this.media.url,
      expiresAt: iso(new Date(this.clock.now().getTime() + ttl * 1000)),
      layer: callerId !== null && callerId === row.host_user_id ? 'MEDIUM' : 'LOW',
      capped,
      rooms,
    };
  }

  /**
   * The media webhook (or reconciliation) found a `pk4:` identity in a room: allowed while that match is open and the
   * room is one of its four (else the caller disconnects it). Never a viewer of that room.
   */
  async allowsWatcher(roomId: string, identity: string): Promise<boolean> {
    const matchId = pk4MatchOfIdentity(identity);
    if (matchId === null) return false;
    const [row] = await this.prisma.$queryRaw<{ ok: boolean }[]>`
      SELECT EXISTS (SELECT 1 FROM pk4_seats s JOIN pk4_matches m ON m.id = s.match_id
                      WHERE s.match_id = ${matchId}::uuid AND s.room_id = ${roomId}::uuid AND s.active
                        AND m.status <> 'CLOSED') AS ok`;
    return row?.ok === true;
  }

  /** The host of a room in a 4-way match joined or left its own media session (the absence rule). */
  async onHostMedia(roomId: string, identity: string, joined: boolean): Promise<void> {
    if (!isUuid(identity)) return;
    const host = identity.toLowerCase();
    if (joined) {
      await this.prisma.$executeRaw`
        UPDATE pk4_seats SET left_at = NULL
         WHERE active AND room_id = ${roomId}::uuid AND host_id = ${host}::uuid AND left_at IS NOT NULL`;
    } else {
      await this.prisma.$executeRaw`
        UPDATE pk4_seats SET left_at = COALESCE(left_at, ${iso(this.clock.now())}::timestamptz)
         WHERE active AND room_id = ${roomId}::uuid AND host_id = ${host}::uuid AND out_at IS NULL`;
    }
  }

  // ---- Moderation (the panel) ------------------------------------------------------------------

  /**
   * `POST /admin/lives/{roomId}/pk4/end` (`lives.moderate`): the room's open 4-way match ended by a moderator — the
   * rule of `pk-admin end` (`adminEndPk4In`); audited `live.pk.admin_end` in the same transaction. The four rooms are
   * told at once (and by the tick's notice otherwise).
   */
  async adminEndOfRoom(
    roomId: string,
    reason: string,
    actor: { adminId: string; ip?: string | null; requestId?: string | null },
  ): Promise<{ matchId: string; previousStatus: 'CONNECTED' | 'BATTLE' | 'RESULT' }> {
    if (!isUuid(roomId)) throw new AppException(ErrorCode.NOT_FOUND);
    const room = await this.roomState(this.prisma, roomId.toLowerCase());
    if (!room) throw new AppException(ErrorCode.NOT_FOUND);
    const match = await this.openMatchOfRoom(this.prisma, room.id);
    if (!match) throw new AppException(ErrorCode.PK_NOT_ACTIVE);
    const previous = await this.prisma.$transaction(async (tx) => {
      const status = await adminEndPk4In(tx, match.id, reason, this.clock.now());
      if (status === null) return null;
      await this.audit.recordIn(tx, {
        action: AuditAction.LIVE_PK_ADMIN_END,
        actorUserId: actor.adminId,
        targetType: 'pk4_match',
        targetId: match.id,
        metadata: { reason, previousStatus: status, format: match.format, via: 'panel' },
        ip: actor.ip ?? null,
        requestId: actor.requestId ?? null,
      });
      return status;
    }, LIVE_TX_OPTIONS);
    if (previous === null) throw new AppException(ErrorCode.PK_NOT_ACTIVE);
    const notice = await this.prisma.$executeRaw`
      UPDATE pk4_matches SET pending_notice = false WHERE id = ${match.id}::uuid AND pending_notice`;
    if (notice > 0) await this.afterClose(match.id);
    return { matchId: match.id, previousStatus: previous };
  }

  // ---- The tick --------------------------------------------------------------------------------

  /**
   * One 4-way PK tick (every PK_TICK_MS; by hand in tests): open invitations and lobbies past their time expire (the
   * hosts told), a lobby whose organiser's live ended is cancelled and an accepted place whose live ended is freed,
   * absent hosts are marked out (their team may lose, everyone may be gone), battles whose time is up end, result phases
   * past their time close, and moderator ends are told to the four rooms. Every step is idempotent under the rows'
   * state guards, so instances may run it concurrently.
   */
  async tick(): Promise<{ expiredInvites: number; expiredLobbies: number; ended: number; closed: number }> {
    const now = this.clock.now();
    const at = iso(now);
    const expired = await this.prisma.$queryRaw<
      { id: string; lobby_id: string; to_room_id: string; to_host_id: string }[]
    >`
      UPDATE pk4_invites SET status = 'EXPIRED', handled_at = expires_at
       WHERE status = 'PENDING' AND expires_at <= ${at}::timestamptz
       RETURNING id::text AS id, lobby_id::text AS lobby_id, to_room_id::text AS to_room_id, to_host_id::text AS to_host_id`;
    const lobbies = await this.expireLobbiesIn(this.prisma, Prisma.sql`true`, now);
    for (const e of expired) {
      const dto = await this.inviteDto(e.id);
      if (dto) await this.tellInvite(dto);
      if (!lobbies.includes(e.lobby_id)) {
        await this.tellLobby(e.lobby_id, 'invite-expired', [{ roomId: e.to_room_id, hostId: e.to_host_id }]);
      }
    }
    for (const id of lobbies) {
      await this.audit.record({
        action: AuditAction.LIVE_PK4_LOBBY,
        actorUserId: null,
        targetType: 'pk4_lobby',
        targetId: id,
        metadata: { event: 'expired' },
      });
      await this.tellLobby(id, 'expired');
    }
    // The organiser's live ended → the lobby is cancelled; an accepted host's live ended → their place is free.
    const gone = await this.prisma.$queryRaw<{ id: string }[]>`
      UPDATE pk4_lobbies l SET status = 'CANCELLED', closed_at = ${at}::timestamptz
       WHERE l.status = 'OPEN'
         AND NOT EXISTS (SELECT 1 FROM live_rooms r WHERE r.id = l.organiser_room_id AND r.status = 'LIVE')
       RETURNING l.id::text AS id`;
    for (const { id } of gone) {
      await this.prisma.$executeRaw`
        UPDATE pk4_invites SET status = 'CANCELLED', handled_at = ${at}::timestamptz
         WHERE lobby_id = ${id}::uuid AND status = 'PENDING'`;
      await this.tellLobby(id, 'cancelled');
    }
    const leavers = await this.prisma.$queryRaw<
      { lobby_id: string; to_room_id: string; to_host_id: string }[]
    >`
      UPDATE pk4_invites i SET status = 'LEFT', handled_at = ${at}::timestamptz
        FROM pk4_lobbies l
       WHERE l.id = i.lobby_id AND l.status = 'OPEN' AND i.status = 'ACCEPTED'
         AND NOT EXISTS (SELECT 1 FROM live_rooms r WHERE r.id = i.to_room_id AND r.status = 'LIVE')
       RETURNING i.lobby_id::text AS lobby_id, i.to_room_id::text AS to_room_id, i.to_host_id::text AS to_host_id`;
    for (const l of leavers) {
      await this.tellLobby(l.lobby_id, 'left', [{ roomId: l.to_room_id, hostId: l.to_host_id }]);
    }

    let ended = 0;
    let closed = 0;
    const open = await this.prisma.$queryRaw<MatchRow[]>(
      Prisma.sql`SELECT ${Prisma.raw(MATCH_COLUMNS)} FROM pk4_matches WHERE status <> 'CLOSED'
        ORDER BY started_at LIMIT 1000`,
    );
    const grace = this.config.pk.absenceGraceSeconds;
    for (const m of open) {
      const seats = await this.seatsOf(this.prisma, m.id);
      const absence = async (s: SeatRow) => {
        const room = await this.roomState(this.prisma, s.room_id);
        return room === null
          ? ('DISCONNECT' as const)
          : absenceOf(
              {
                roomStatus: room.status,
                roomEndReason: room.end_reason,
                lastHeartbeatAt: room.last_heartbeat_at,
                hostAwaySince: room.host_away_since,
                leftAt: s.left_at,
              },
              now,
              grace,
            );
      };
      if (m.status === 'CONNECTED') {
        let anyGone = false;
        for (const s of seats) if ((await absence(s)) !== null) anyGone = true;
        if (anyGone || m.battle_ends_at.getTime() <= now.getTime()) {
          if (await this.cancelConnected(m.id)) closed += 1;
        }
      } else if (m.status === 'BATTLE') {
        const outs: { seat: number; reason: 'FORFEIT' | 'DISCONNECT' | 'AWAY' }[] = [];
        for (const s of seats) {
          if (s.out_at !== null) continue;
          const reason = await absence(s);
          if (reason !== null) outs.push({ seat: s.seat, reason });
        }
        if (outs.length > 0) {
          if ((await this.settleOuts(m.id, outs, null)) === 'ended') {
            ended += 1;
            continue;
          }
        }
        if (m.battle_ends_at.getTime() <= now.getTime() && (await this.finishByTime(m.id))) ended += 1;
      } else if (m.status === 'RESULT') {
        const live = await this.prisma.liveRoom.count({
          where: { id: { in: seats.map((s) => s.room_id) }, status: 'LIVE' },
        });
        if ((m.result_ends_at !== null && m.result_ends_at.getTime() <= now.getTime()) || live === 0) {
          if (await this.closeResult(m.id)) closed += 1;
        }
      }
    }
    const notices = await this.prisma.$queryRaw<{ id: string }[]>`
      UPDATE pk4_matches SET pending_notice = false WHERE pending_notice RETURNING id::text AS id`;
    for (const { id } of notices) await this.afterClose(id);
    return { expiredInvites: expired.length, expiredLobbies: lobbies.length, ended, closed };
  }
}
