import { randomInt } from 'node:crypto';
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
import { awardPkDaresMedalsIn } from '../medals/medal-awards.js';
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
  type PkGenderPrefName,
  type PkRegionPrefName,
  type PkSideName,
} from './live-pk.js';
import {
  adminEndPk4In,
  ffaOutcome,
  ffaPlaces,
  ffaResult,
  isEffectivePk4,
  pickPk4Group,
  pk4BusySql,
  pk4DareSides,
  pk4Identity,
  pk4MatchOfIdentity,
  pk4SeatPlan,
  PK4_IDENTITY_PREFIX,
  roleOfSeatIn,
  shuffled,
  teamOfSeat,
  teamsOutcome,
  teamWinnerByScore,
  topSeatSupportersIn,
  topTeamSupportersIn,
  type Pk4FormatName,
} from './live-pk4.js';
import type {
  PkActiveBoostDto,
  PkBoosterRuleDto,
  PkCandidateDto,
  PkDareDto,
  PkDareOptionDto,
  PkSupporterDto,
  PkTypeName,
} from './live-pk.service.js';
import { LIVE_TX_OPTIONS, LiveRoomsService, type UserSummaryDto } from './live-rooms.service.js';
import { isUuid, liveMediaTokenSchema } from './live.schemas.js';
import { pkDareSettingsIn } from './pk-dares/pk-dare-library.js';
import { addPkDareDoneIn, drawPk4DareIn } from './pk-dares/pk-dare-match.js';
import { LIVE_MEDIA_PROVIDER, type LiveMediaProvider } from './media/live-media.provider.js';

// ---- Response shapes (openapi v1.118-live / v1.119-live, CONVENTIONS §10.180 / §10.181) ----------

export type Pk4InviteStatusName = 'PENDING' | 'ACCEPTED' | 'DECLINED' | 'CANCELLED' | 'EXPIRED' | 'LEFT';

export type Pk4ResultName = 'WIN' | 'LOSS' | 'DRAW';

/** `Pk4Invite`. */
export interface Pk4InviteDto {
  id: string;
  lobbyId: string;
  format: Pk4FormatName;
  /** v1.119-live (D395): «PK أحكام» or a normal 4-way PK. */
  type: PkTypeName;
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
  role: 'ORGANISER' | 'TEAMMATE' | 'OPPONENT' | 'PLAYER';
  state: 'EMPTY' | 'INVITED' | 'ACCEPTED';
  roomId: string | null;
  host: UserSummaryDto | null;
  invite: Pk4InviteDto | null;
}

/** `Pk4Lobby`. */
export interface Pk4LobbyDto {
  id: string;
  format: Pk4FormatName;
  type: PkTypeName;
  status: 'OPEN' | 'STARTED' | 'CANCELLED' | 'EXPIRED';
  organiserRoomId: string;
  createdAt: string;
  expiresAt: string;
  matchId: string | null;
  serverTime: string;
  /** v1.119-live (D395): the hosts in (the organiser and the accepted places), 1–4. */
  accepted: number;
  /** v1.119-live (D395): the organiser may start now («ابدأ الآن»: at least one invited host accepted). */
  canStart: boolean;
  seats: Pk4LobbySeatDto[];
}

/** `Pk4TeamState`. */
export interface Pk4TeamDto {
  team: PkSideName;
  score: number;
  result: Pk4ResultName | null;
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
  /** v1.119-live (D395): FREE_FOR_ALL's place (equal scores share one); null in TEAMS, while it runs, void. */
  place: number | null;
  /** v1.119-live (D395): this host's result (TEAMS: the team's; FREE_FOR_ALL: by place); null while it runs, void. */
  result: Pk4ResultName | null;
  /** v1.119-live (D395): FREE_FOR_ALL — the host's own booster now (TEAMS: the team's). */
  boost: PkActiveBoostDto | null;
  /** v1.119-live (D395): FREE_FOR_ALL — the host's own uses of each booster (TEAMS: the team's). */
  boosterUses: Record<PkBoosterKindName, number>;
  /** v1.119-live (D395): FREE_FOR_ALL — the host's top three supporters (TEAMS: empty; the team's are on the team). */
  supporters: PkSupporterDto[];
}

/** `Pk4Dare` (v1.119-live, D395). */
export interface Pk4DareDto {
  status: PkDareDto['status'];
  cause: PkDareDto['cause'];
  loserRoomIds: string[];
  winnerRoomIds: string[];
  options: PkDareOptionDto[];
  drawn: number;
  revealAt: string;
  decideBy: string;
  startedAt: string | null;
  endsAt: string | null;
  finishedAt: string | null;
  points: number;
  refusePoints: number;
}

/** `Pk4Rematch` (v1.119-live, D395): an open «جولة أخرى» offer. */
export interface Pk4RematchDto {
  byRoomId: string;
  expiresAt: string;
  acceptedRoomIds: string[];
  /** The present hosts' rooms that have not accepted yet. */
  waitingRoomIds: string[];
}

/** `Pk4Match`. */
export interface Pk4MatchDto {
  id: string;
  format: Pk4FormatName;
  type: PkTypeName;
  source: 'INVITE' | 'RANDOM' | 'REMATCH';
  playerCount: number;
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
  /** TEAMS: team A then B. FREE_FOR_ALL: empty (no teams; v1.119-live). */
  teams: Pk4TeamDto[];
  seats: Pk4SeatDto[];
  boosters: PkBoosterRuleDto[];
  dare: Pk4DareDto | null;
  rematch: Pk4RematchDto | null;
  rematchOf: string | null;
  rematchesLeft: number | null;
}

/** `Pk4Queue` (v1.119-live, D395): the host's wait in the 4-way random queue. */
export interface Pk4QueueDto {
  format: Pk4FormatName;
  type: PkTypeName;
  joinedAt: string;
  expiresAt: string;
}

/** `Pk4State`. */
export interface Pk4StateDto {
  match: Pk4MatchDto | null;
  lobby: Pk4LobbyDto | null;
  invite: Pk4InviteDto | null;
  /** v1.119-live (D395): the room's host only — their 4-way random wait. */
  queue: Pk4QueueDto | null;
}

/** `Pk4RandomResult` (v1.119-live, D395). */
export interface Pk4RandomResultDto {
  status: 'MATCHED' | 'WAITING';
  queue: Pk4QueueDto | null;
  match: Pk4MatchDto | null;
}

/** `Pk4MediaAccess`. */
export interface Pk4MediaAccessDto {
  url: string;
  expiresAt: string;
  layer: 'LOW' | 'MEDIUM';
  capped: boolean;
  rooms: { roomId: string; token: string; identity: string; hostIdentity: string }[];
}

export type Pk4MatchEvent =
  | 'connected'
  | 'started'
  | 'score'
  | 'boost'
  | 'out'
  | 'ended'
  | 'closed'
  | 'mute'
  | 'dare'
  | 'rematch-offer'
  | 'rematch-accepted'
  | 'rematch'
  | 'rematch-declined'
  | 'rematch-cancelled'
  | 'rematch-expired';

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

/** The data message of topic `pk` to the rooms of a match. */
export interface Pk4MatchData {
  readonly type: 'pk4-match';
  readonly event: Pk4MatchEvent;
  readonly match: Pk4MatchDto;
  /** `boost`: the team (and, FREE_FOR_ALL, the place) and booster that just started, and the room whose gift did. */
  readonly boost?: {
    team: PkSideName;
    seat: number | null;
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

/** v1.119-live (D395): the data message to a host whose 4-way random wait ended (matched, or ran out). */
export interface Pk4QueueData {
  readonly type: 'pk4-queue';
  readonly status: 'MATCHED' | 'EXPIRED';
  readonly matchId?: string;
}

/** What a gift send in a 4-way room during the battle did (for the send's post-commit messages). */
export interface Pk4GiftCredit {
  readonly matchId: string;
  readonly boosted: {
    team: PkSideName;
    seat: number | null;
    roomId: string;
    kind: PkBoosterKindName;
    multiplier: number;
    endsAt: Date;
  } | null;
}

// ---- Request bodies ----------------------------------------------------------------------------

const typeSchema = z.enum(['NORMAL', 'DARES']);
const lobbySchema = z.strictObject({
  format: z.enum(['TEAMS', 'FREE_FOR_ALL']),
  type: typeSchema.optional(),
});
const randomSchema = z.strictObject({
  format: z.enum(['TEAMS', 'FREE_FOR_ALL']),
  type: typeSchema.optional(),
});
const inviteSchema = z.strictObject({
  toRoomId: z.uuid(),
  seat: z.union([z.literal(2), z.literal(3), z.literal(4)]),
});
const muteSchema = z.strictObject({ roomId: z.uuid(), muted: z.boolean() });
const verdictSchema = z.strictObject({ done: z.boolean() });
const reportSchema = z.strictObject({ dareId: z.uuid() });
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
  type: PkTypeName;
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
  type: PkTypeName;
  source: Pk4MatchDto['source'];
  player_count: number;
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
  top_seats: Record<string, { userId: string; points: number }[]> | null;
  effective: boolean | null;
  rematch_of: string | null;
  rematch_root_id: string | null;
  rematch_count: number;
  rematch_by_room_id: string | null;
  rematch_expires_at: Date | null;
  rematch_accepted: string[];
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
  place: number | null;
}

interface DareRow {
  match_id: string;
  loser_seats: number[];
  loser_host_ids: string[];
  winner_seats: number[];
  winner_host_ids: string[];
  option_ids: string[];
  drawn: number;
  dare_id: string;
  status: 'DECIDING' | 'ACTIVE' | 'DONE' | 'REFUSED' | 'CANCELLED';
  cause: PkDareDto['cause'];
  reveal_at: Date;
  decide_by: Date;
  started_at: Date | null;
  ends_at: Date | null;
  finished_at: Date | null;
  points: number;
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

/** A host who starts a match: their room, their user id, their place before the seat plan. */
interface StartingHost {
  readonly roomId: string;
  readonly hostId: string;
  readonly seat: number;
}

const LOBBY_COLUMNS = `id::text AS id, format::text AS format, type::text AS type, status::text AS status,
  organiser_room_id::text AS organiser_room_id, organiser_host_id::text AS organiser_host_id, created_at, expires_at,
  match_id::text AS match_id`;

const INVITE_COLUMNS = `id::text AS id, lobby_id::text AS lobby_id, seat, team::text AS team,
  to_room_id::text AS to_room_id, to_host_id::text AS to_host_id, status::text AS status, created_at, expires_at`;

const MATCH_COLUMNS = `id::text AS id, lobby_id::text AS lobby_id, format::text AS format, type::text AS type,
  source, player_count, status::text AS status,
  organiser_room_id::text AS organiser_room_id, started_at, battle_ends_at, ended_at, result_ends_at,
  end_reason::text AS end_reason, winner_team::text AS winner_team, loser_cause::text AS loser_cause, score_a, score_b,
  round_seconds, connected_at, seq, top_a, top_b, top_seats, effective, rematch_of::text AS rematch_of,
  rematch_root_id::text AS rematch_root_id, rematch_count, rematch_by_room_id::text AS rematch_by_room_id,
  rematch_expires_at, rematch_accepted::text[] AS rematch_accepted`;

const SEAT_COLUMNS = `match_id::text AS match_id, seat, team::text AS team, room_id::text AS room_id,
  host_id::text AS host_id, score, active, left_at, out_at, out_reason::text AS out_reason,
  muted_room_ids::text[] AS muted_room_ids, place`;

const DARE_COLUMNS = `match_id::text AS match_id, loser_seats::int[] AS loser_seats,
  loser_host_ids::text[] AS loser_host_ids, winner_seats::int[] AS winner_seats,
  winner_host_ids::text[] AS winner_host_ids, option_ids::text[] AS option_ids, drawn, dare_id::text AS dare_id,
  status::text AS status, cause::text AS cause, reveal_at, decide_by, started_at, ends_at, finished_at, points`;

/** The end of a battle as the tick or a host decides it. */
interface Finish {
  readonly reason: PkEndReasonName;
  /** TEAMS: null with TIME (decided by the scores) or when everyone is gone. FREE_FOR_ALL: always null (places). */
  readonly winner: PkSideName | null;
  readonly loserCause: PkSideName | null;
  readonly everyoneGone: boolean;
}

function iso(d: Date): string {
  return d.toISOString();
}

function zeroUses(): Record<PkBoosterKindName, number> {
  return Object.fromEntries(PK_BOOSTER_KINDS.map((k) => [k, 0])) as Record<PkBoosterKindName, number>;
}

/** A transaction that must be retried because the lobby's set of rooms changed before its locks were taken. */
class LobbyMoved extends Error {}

/**
 * «PK رباعي» (v1.118-live, D391, CONVENTIONS §10.180, CP-041 phase 2; v1.119-live, D395, §10.181, phases 3–4): PK
 * between two to four hosts of SOLO video lives — TEAMS (2 v 2, and with three or two hosts) or FREE_FOR_ALL (each host
 * alone, places 1–4) — started by invitation (an organiser's lobby; all four in, the organiser's «ابدأ الآن» with at
 * least one more host, or the lobby's time running out with two or more in) or by the 4-way random queue (four hosts).
 * Server-authoritative like PK 1 v 1 (scores, boosters, outs, places, the result phase, «PK أحكام», «جولة أخرى») and told
 * to the rooms as `pk` data messages, with `GET /live/rooms/{roomId}/pk4` as the snapshot. Each room's viewers watch
 * the other hosts with watch-only, hidden tokens (`pk4:<matchId>:<identity>`). PK 1 v 1 (`LivePkService`) shares the
 * per-room PK advisory locks; each counts the other's rows as busy.
 */
@Injectable()
export class LivePk4Service implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(LivePk4Service.name);
  private readonly scoreThrottle: TrailingThrottle;
  private tickTimer: NodeJS.Timeout | undefined;
  private tickInFlight: Promise<unknown> | null = null;
  private stopped = false;
  /** Tests: the drawn dare card (0–2); else crypto random. */
  darePick: (() => number) | null = null;
  /** Tests: the random source of the 4-way random teams and places; else crypto random. */
  randomSource: ((max: number) => number) | null = null;

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

  /** «PK أحكام» needs PK_DARES_ENABLED for new lobbies and waits (running dares finish). */
  private typeOf(type: PkTypeName | undefined): PkTypeName {
    const t = type ?? 'NORMAL';
    if (t === 'DARES' && !this.config.pk.daresEnabled) throw new AppException(ErrorCode.PK_UNAVAILABLE);
    return t;
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

  /** A block either way between any two of `ids`. */
  private async blockedAmong(
    db: Prisma.TransactionClient | PrismaService,
    ids: readonly string[],
  ): Promise<boolean> {
    const unique = [...new Set(ids)];
    if (unique.length < 2) return false;
    const [row] = await db.$queryRaw<{ blocked: boolean }[]>`
      SELECT EXISTS (SELECT 1 FROM user_blocks
                      WHERE blocker_id = ANY(${unique}::uuid[]) AND blocked_id = ANY(${unique}::uuid[])
                        AND blocker_id <> blocked_id) AS blocked`;
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
   * random-queue wait — 1 v 1 or 4-way — (not with `ignoreQueue`, §10.70), or a 4-way place, lobby or invitation
   * (except `exceptInviteId`, the invitation being answered, and `exceptLobbyId`, the organiser's own lobby). Under the
   * room's PK lock.
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
              AND (EXISTS (SELECT 1 FROM pk_queue WHERE host_id = ${hostId}::uuid AND expires_at > ${at}::timestamptz)
                   OR EXISTS (SELECT 1 FROM pk4_queue WHERE host_id = ${hostId}::uuid
                                 AND expires_at > ${at}::timestamptz)))
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

  /** A queued room is busy for the 4-way matcher only with a PK of either kind or an open invitation. */
  private async busyIgnoringQueue(tx: Prisma.TransactionClient, roomId: string, now: Date): Promise<boolean> {
    const at = iso(now);
    const [row] = await tx.$queryRaw<{ busy: boolean }[]>`
      SELECT EXISTS (SELECT 1 FROM pk_matches WHERE status <> 'CLOSED'
                        AND (room_a_id = ${roomId}::uuid OR room_b_id = ${roomId}::uuid))
          OR EXISTS (SELECT 1 FROM pk_invites WHERE status = 'PENDING' AND expires_at > ${at}::timestamptz
                        AND (from_room_id = ${roomId}::uuid OR to_room_id = ${roomId}::uuid))
          OR ${pk4BusySql(Prisma.sql`${roomId}::uuid`, at)} AS busy`;
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

  private async matchById(id: string): Promise<MatchRow> {
    return (await this.matchRow(this.prisma, Prisma.sql`id = ${id}::uuid`))!;
  }

  private async seatsOf(db: Prisma.TransactionClient | PrismaService, matchId: string): Promise<SeatRow[]> {
    return db.$queryRaw<SeatRow[]>(
      Prisma.sql`SELECT ${Prisma.raw(SEAT_COLUMNS)} FROM pk4_seats WHERE match_id = ${matchId}::uuid ORDER BY seat`,
    );
  }

  private async dareRow(
    db: Prisma.TransactionClient | PrismaService,
    matchId: string,
    lock = false,
  ): Promise<DareRow | null> {
    const [row] = await db.$queryRaw<DareRow[]>(
      Prisma.sql`SELECT ${Prisma.raw(DARE_COLUMNS)} FROM pk4_match_dares WHERE match_id = ${matchId}::uuid
        ${lock ? Prisma.raw('FOR UPDATE') : Prisma.empty}`,
    );
    return row ?? null;
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
      type: lobby.type,
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
      const role = roleOfSeatIn(lobby.format, seat);
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
    const accepted = seats.filter((s) => s.state === 'ACCEPTED').length;
    return {
      id: lobby.id,
      format: lobby.format,
      type: lobby.type,
      status: lobby.status,
      organiserRoomId: lobby.organiser_room_id,
      createdAt: iso(lobby.created_at),
      expiresAt: iso(lobby.expires_at),
      matchId: lobby.match_id,
      serverTime: iso(now),
      accepted,
      canStart: lobby.status === 'OPEN' && accepted >= 2,
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

  /** v1.119-live (D395) `Pk4Dare` of a DARES match (null before the battle ends, or with no dare). */
  private async dareDto(match: MatchRow, seats: readonly SeatRow[]): Promise<Pk4DareDto | null> {
    if (match.type !== 'DARES') return null;
    const d = await this.dareRow(this.prisma, match.id);
    if (!d) return null;
    const dares = await this.prisma.pkDare.findMany({
      where: { id: { in: d.option_ids } },
      select: { id: true, level: true, category: true, textAr: true, textEn: true },
    });
    const options = d.option_ids
      .map((id) => dares.find((x) => x.id === id))
      .filter((x): x is NonNullable<typeof x> => x !== undefined);
    const now = this.clock.now();
    const status: Pk4DareDto['status'] =
      d.status === 'DECIDING' && now.getTime() < d.reveal_at.getTime() ? 'DRAWING' : d.status;
    const roomOf = (seat: number) => seats.find((s) => s.seat === seat)?.room_id;
    return {
      status,
      cause: d.cause,
      loserRoomIds: d.loser_seats.map(roomOf).filter((r): r is string => r !== undefined),
      winnerRoomIds: d.winner_seats.map(roomOf).filter((r): r is string => r !== undefined),
      options,
      drawn: d.drawn,
      revealAt: iso(d.reveal_at),
      decideBy: iso(d.decide_by),
      startedAt: d.started_at ? iso(d.started_at) : null,
      endsAt: d.ends_at ? iso(d.ends_at) : null,
      finishedAt: d.finished_at ? iso(d.finished_at) : null,
      points: d.points,
      refusePoints: (await pkDareSettingsIn(this.prisma)).refusePoints,
    };
  }

  /** The present hosts of a RESULT match for «جولة أخرى»: not out and their room still eligible. */
  private async presentSeats(
    db: Prisma.TransactionClient | PrismaService,
    seats: readonly SeatRow[],
    now: Date,
  ): Promise<SeatRow[]> {
    const out: SeatRow[] = [];
    for (const s of seats) {
      if (s.out_at !== null) continue;
      if (this.eligible(await this.roomState(db, s.room_id), now)) out.push(s);
    }
    return out;
  }

  /** The full match as its rooms see it. */
  async matchDto(row: MatchRow): Promise<Pk4MatchDto> {
    const now = this.clock.now();
    const ffa = row.format === 'FREE_FOR_ALL';
    const ended = row.status === 'RESULT' || row.status === 'CLOSED';
    const [seats, boosts, uses, teamTop, seatTop, rules] = await Promise.all([
      this.seatsOf(this.prisma, row.id),
      this.prisma.$queryRaw<
        {
          id: string;
          team: PkSideName;
          seat: number | null;
          kind: PkBoosterKindName;
          multiplier: number;
          starts_at: Date;
          ends_at: Date;
          sender_id: string;
        }[]
      >`
        SELECT DISTINCT ON (team, COALESCE(seat, 0)) id::text AS id, team::text AS team, seat, kind::text AS kind,
               multiplier, starts_at, ends_at, sender_id::text AS sender_id
          FROM pk4_boosts
         WHERE match_id = ${row.id}::uuid AND starts_at <= ${iso(now)}::timestamptz AND ends_at > ${iso(now)}::timestamptz
           AND ${row.status === 'BATTLE'}
         ORDER BY team, COALESCE(seat, 0), multiplier DESC`,
      this.prisma.$queryRaw<{ team: PkSideName; seat: number | null; kind: PkBoosterKindName; n: number }[]>`
        SELECT team::text AS team, seat, kind::text AS kind, count(*)::int AS n FROM pk4_boosts
         WHERE match_id = ${row.id}::uuid GROUP BY team, seat, kind`,
      row.status === 'BATTLE' || row.top_a === null || row.top_b === null
        ? this.prisma.$transaction((tx) => topTeamSupportersIn(tx, row.id))
        : Promise.resolve({ A: row.top_a, B: row.top_b }),
      ffa && (row.status === 'BATTLE' || row.top_seats === null)
        ? this.prisma.$transaction((tx) => topSeatSupportersIn(tx, row.id))
        : Promise.resolve(row.top_seats ?? {}),
      this.boosterRules(),
    ]);
    const records = await this.prisma.pkHostRecord.findMany({
      where: { hostId: { in: seats.map((s) => s.host_id) } },
      select: { hostId: true, points: true },
    });
    const allTop = [...teamTop.A, ...teamTop.B, ...Object.values(seatTop).flat()];
    const anonymous = await vipPrivacyOnIn(
      this.prisma,
      allTop.map((s) => s.userId),
      'RANKING_ANONYMOUS',
      now,
    );
    const people = await this.summaries([
      ...seats.map((s) => s.host_id),
      ...boosts.map((b) => b.sender_id),
      ...allTop.map((s) => s.userId),
    ]);
    const supportersOf = (list: readonly { userId: string; points: number }[]): PkSupporterDto[] =>
      list
        .filter((p) => people.has(p.userId))
        .map((p) => ({
          user: anonymous.has(p.userId) ? anonymousUserSummary() : people.get(p.userId)!,
          points: p.points,
        }));
    const boostDto = (b: (typeof boosts)[number] | undefined): PkActiveBoostDto | null =>
      b
        ? {
            id: b.id,
            kind: b.kind,
            multiplier: b.multiplier,
            startsAt: iso(b.starts_at),
            endsAt: iso(b.ends_at),
            sender: people.get(b.sender_id) ?? null,
          }
        : null;
    const void_ = row.end_reason === null || row.end_reason === 'ADMIN' || row.end_reason === 'CANCELLED';
    const teamResult = (t: PkSideName): Pk4ResultName | null =>
      !ended || void_ ? null : row.winner_team === null ? 'DRAW' : row.winner_team === t ? 'WIN' : 'LOSS';
    const teamUses = (t: PkSideName) => {
      const counts = zeroUses();
      for (const u of uses) if (u.team === t && u.seat === null) counts[u.kind] += u.n;
      return counts;
    };
    const team = (t: PkSideName): Pk4TeamDto => ({
      team: t,
      score: Number(t === 'A' ? row.score_a : row.score_b),
      result: teamResult(t),
      boost: boostDto(boosts.find((b) => b.team === t && b.seat === null)),
      boosterUses: teamUses(t),
      supporters: supportersOf(teamTop[t]),
    });
    const places = seats.map((s) => s.place).filter((p): p is number => p !== null);
    // TEAMS: the team's result; FREE_FOR_ALL: by place (no places when everyone was gone: a void draw).
    const seatResult = (s: SeatRow): Pk4ResultName | null => {
      if (!ended || void_) return null;
      if (!ffa) return teamResult(s.team);
      return s.place === null ? null : ffaResult(s.place, places);
    };
    let rematch: Pk4RematchDto | null = null;
    if (
      row.status === 'RESULT' &&
      row.rematch_by_room_id !== null &&
      row.rematch_expires_at !== null &&
      row.rematch_expires_at.getTime() > now.getTime()
    ) {
      const present = await this.presentSeats(this.prisma, seats, now);
      rematch = {
        byRoomId: row.rematch_by_room_id,
        expiresAt: iso(row.rematch_expires_at),
        acceptedRoomIds: row.rematch_accepted,
        waitingRoomIds: present.map((s) => s.room_id).filter((r) => !row.rematch_accepted.includes(r)),
      };
    }
    return {
      id: row.id,
      format: row.format,
      type: row.type,
      source: row.source,
      playerCount: row.player_count,
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
      teams: ffa ? [] : [team('A'), team('B')],
      seats: seats
        .filter((s) => people.has(s.host_id))
        .map((s) => {
          const own = zeroUses();
          for (const u of uses) if (u.seat === s.seat) own[u.kind] += u.n;
          return {
            seat: s.seat,
            team: s.team,
            roomId: s.room_id,
            host: people.get(s.host_id)!,
            score: Number(s.score),
            out: s.out_at !== null,
            outReason: s.out_reason,
            mutedRoomIds: s.muted_room_ids,
            pkPoints: records.find((r) => r.hostId === s.host_id)?.points ?? 0,
            place: ffa && ended && !void_ ? s.place : null,
            result: seatResult(s),
            boost: ffa
              ? boostDto(boosts.find((b) => b.seat === s.seat))
              : boostDto(boosts.find((b) => b.team === s.team && b.seat === null)),
            boosterUses: ffa ? own : teamUses(s.team),
            supporters: ffa ? supportersOf(seatTop[String(s.seat)] ?? []) : [],
          };
        }),
      boosters: rules,
      dare: await this.dareDto(row, seats),
      rematch,
      rematchOf: row.rematch_of,
      rematchesLeft:
        this.config.pk.rematchMax === 0 ? null : Math.max(0, this.config.pk.rematchMax - row.rematch_count),
    };
  }

  /**
   * `GET /live/rooms/{roomId}/pk4`: anyone who may watch the room. The room's open match; its host also gets their
   * OPEN lobby (organised or accepted), an open invitation to the room and their 4-way random wait.
   */
  async state(callerId: string | null, roomId: string): Promise<Pk4StateDto> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (callerId === null && !row.allow_guests) throw new AppException(ErrorCode.LIVE_GUESTS_NOT_ALLOWED);
    if (row.kicked) throw new AppException(ErrorCode.LIVE_KICKED);
    return this.stateOf(row.id, callerId !== null && callerId === row.host_user_id ? callerId : null);
  }

  private async stateOf(roomId: string, hostId: string | null): Promise<Pk4StateDto> {
    const match = await this.openMatchOfRoom(this.prisma, roomId);
    const matchDto = match ? await this.matchDto(match) : null;
    if (hostId === null) return { match: matchDto, lobby: null, invite: null, queue: null };
    const now = this.clock.now();
    const lobby = await this.openLobbyOfRoom(this.prisma, roomId);
    const [invite] = await this.prisma.$queryRaw<{ id: string }[]>`
      SELECT i.id::text AS id FROM pk4_invites i JOIN pk4_lobbies l ON l.id = i.lobby_id
       WHERE i.to_room_id = ${roomId}::uuid AND i.status = 'PENDING' AND i.expires_at > ${iso(now)}::timestamptz
         AND l.status = 'OPEN' LIMIT 1`;
    const wait = await this.prisma.pk4QueueEntry.findUnique({ where: { hostId } });
    return {
      match: matchDto,
      lobby: lobby && lobby.expires_at.getTime() > now.getTime() ? await this.lobbyDto(lobby.id) : null,
      invite: invite ? await this.inviteDto(invite.id) : null,
      queue:
        wait && wait.roomId === roomId && wait.expiresAt.getTime() > now.getTime()
          ? {
              format: wait.format,
              type: wait.type,
              joinedAt: iso(wait.joinedAt),
              expiresAt: iso(wait.expiresAt),
            }
          : null,
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

  /**
   * `POST /live/rooms/{roomId}/pk4/lobby` `{format, type?}` (201): the caller organises a lobby (place 1, team A).
   * v1.119-live (D395): FREE_FOR_ALL too, and «PK أحكام» (`type` DARES, PK_DARES_ENABLED).
   */
  async openLobby(callerId: string, roomId: string, body: unknown): Promise<Pk4LobbyDto> {
    this.assertOn();
    const parsed = lobbySchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const { format } = parsed.data;
    const type = this.typeOf(parsed.data.type);
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
          format,
          type,
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
        metadata: { event: 'opened', format, type, roomId: own.id },
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
      // §10.70: a host waiting in a random queue may be invited (accepting ends the wait).
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
   * the match under the rooms' PK locks (§10.180); fewer wait for the organiser's «ابدأ الآن» or the lobby's end.
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
      // §10.70: accepting ends the caller's random-queue waits (1 v 1 and 4-way).
      await tx.pkQueueEntry.deleteMany({ where: { hostId: callerId } });
      await tx.pk4QueueEntry.deleteMany({ where: { hostId: callerId } });
      const accepted = (await this.lobbyHosts(tx, lobby)).filter((h) => h.status !== 'PENDING');
      if (accepted.length < 4) return;
      const started = await this.startLobbyIn(tx, lobby, now, null);
      outcome.dropped = started.dropped;
      if (started.refused) {
        await tx.$executeRaw`UPDATE pk4_invites SET status = 'CANCELLED', handled_at = ${iso(now)}::timestamptz WHERE id = ${invite.id}::uuid`;
        outcome.refused = started.refused;
        return;
      }
      outcome.matchId = started.matchId;
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
    return this.stateOf(room.id, callerId);
  }

  /**
   * v1.119-live (D395, owner «أ») `POST /live/rooms/{roomId}/pk4/lobby/start` «ابدأ الآن»: the organiser starts the OPEN
   * lobby with the hosts in — at least one invited host accepted (else 409 PK_UNAVAILABLE `too_few`). The open
   * invitations are CANCELLED (their hosts told); the match starts with two, three or four hosts under the rooms' PK
   * locks and fresh checks (§10.181). The answer is the caller's `Pk4State`.
   */
  async startLobby(callerId: string, roomId: string): Promise<Pk4StateDto> {
    this.assertOn();
    const room = await this.ownRoom(callerId, roomId);
    const lobby = await this.lobbyRow(
      this.prisma,
      Prisma.sql`status = 'OPEN' AND organiser_room_id = ${room.id}::uuid`,
    );
    if (!lobby) throw new AppException(ErrorCode.PK_LOBBY_CLOSED);
    const now = this.clock.now();
    const result = await this.inLobby(lobby.id, [room.id], async (tx, l) => {
      if (l.status !== 'OPEN' || l.expires_at.getTime() <= now.getTime()) {
        throw new AppException(ErrorCode.PK_LOBBY_CLOSED);
      }
      return this.startLobbyIn(tx, l, now, callerId);
    });
    await this.afterLobbyStart(lobby.id, result);
    if (result.refused) throw result.refused;
    return this.stateOf(room.id, callerId);
  }

  /** After a lobby start's transaction: the cancelled invitations told, the match and the lobby's hosts told. */
  private async afterLobbyStart(
    lobbyId: string,
    result: { matchId: string | null; dropped: string[]; cancelled: string[] },
  ): Promise<void> {
    for (const id of result.cancelled) {
      const dto = await this.inviteDto(id);
      if (dto) await this.tellInvite(dto);
    }
    if (result.matchId) {
      await this.broadcastMatch(result.matchId, await this.startEvent(result.matchId));
      await this.tellLobby(lobbyId, 'started');
    } else if (result.dropped.length > 0) {
      await this.tellLobby(lobbyId, 'left');
    }
  }

  /**
   * Starts an OPEN lobby with the hosts in it (under its rooms' PK locks and its row lock): the organiser and every
   * accepted place; fewer than two → refused `too_few`. Fresh checks — an accepted host whose live is no longer
   * eligible loses the place (LEFT, `dropped`), the organiser's room not eligible or a block between any two → refused
   * (the lobby stays OPEN). Open invitations are CANCELLED (`cancelled`). `actorId`: the organiser («ابدأ الآن»), null
   * for the third acceptance or the lobby's time running out.
   */
  private async startLobbyIn(
    tx: Prisma.TransactionClient,
    lobby: LobbyRow,
    now: Date,
    actorId: string | null,
  ): Promise<{
    matchId: string | null;
    dropped: string[];
    cancelled: string[];
    refused: AppException | null;
  }> {
    const dropped: string[] = [];
    const tooFew = () =>
      new AppException(ErrorCode.PK_UNAVAILABLE, undefined, [{ field: 'lobby', issue: 'too_few' }]);
    let accepted = (await this.lobbyHosts(tx, lobby)).filter((h) => h.status !== 'PENDING');
    if (accepted.length < 2) return { matchId: null, dropped, cancelled: [], refused: tooFew() };
    if (!this.eligible(await this.roomState(tx, lobby.organiser_room_id), now)) {
      return { matchId: null, dropped, cancelled: [], refused: new AppException(ErrorCode.PK_UNAVAILABLE) };
    }
    for (const h of accepted) {
      if (h.status !== 'ACCEPTED') continue;
      if (!this.eligible(await this.roomState(tx, h.roomId), now)) {
        await tx.$executeRaw`
          UPDATE pk4_invites SET status = 'LEFT', handled_at = ${iso(now)}::timestamptz
           WHERE lobby_id = ${lobby.id}::uuid AND to_room_id = ${h.roomId}::uuid AND status = 'ACCEPTED'`;
        dropped.push(h.roomId);
      }
    }
    accepted = accepted.filter((h) => !dropped.includes(h.roomId));
    // All four needed (the third acceptance) but one dropped: the lobby stays OPEN for another host.
    if (actorId === null && dropped.length > 0 && lobby.expires_at.getTime() > now.getTime()) {
      return { matchId: null, dropped, cancelled: [], refused: null };
    }
    if (accepted.length < 2) return { matchId: null, dropped, cancelled: [], refused: tooFew() };
    if (
      await this.blockedAmong(
        tx,
        accepted.map((h) => h.hostId),
      )
    ) {
      return { matchId: null, dropped, cancelled: [], refused: new AppException(ErrorCode.PK_UNAVAILABLE) };
    }
    const cancelled = await tx.$queryRaw<{ id: string }[]>`
      UPDATE pk4_invites SET status = 'CANCELLED', handled_at = ${iso(now)}::timestamptz
       WHERE lobby_id = ${lobby.id}::uuid AND status = 'PENDING' RETURNING id::text AS id`;
    const matchId = await this.createMatchIn(tx, {
      format: lobby.format,
      type: lobby.type,
      source: 'INVITE',
      lobbyId: lobby.id,
      organiserRoomId: lobby.organiser_room_id,
      settingsHostId: lobby.organiser_host_id,
      hosts: accepted,
      actorId: actorId ?? lobby.organiser_host_id,
      now,
    });
    await tx.$executeRaw`
      UPDATE pk4_lobbies SET status = 'STARTED', closed_at = ${iso(now)}::timestamptz, match_id = ${matchId}::uuid
       WHERE id = ${lobby.id}::uuid`;
    if (accepted.length < 4) {
      await this.audit.recordIn(tx, {
        action: AuditAction.LIVE_PK4_LOBBY,
        actorUserId: actorId,
        targetType: 'pk4_lobby',
        targetId: lobby.id,
        metadata: {
          event: actorId === null ? 'auto-started' : 'started-early',
          hosts: accepted.length,
          matchId,
        },
      });
    }
    return { matchId, dropped, cancelled: cancelled.map((c) => c.id), refused: null };
  }

  private async startEvent(matchId: string): Promise<Pk4MatchEvent> {
    const row = await this.matchRow(this.prisma, Prisma.sql`id = ${matchId}::uuid`);
    return row?.status === 'CONNECTED' ? 'connected' : 'started';
  }

  /**
   * Creates a match (under the rooms' locks): two to four hosts placed by `pk4SeatPlan`; the settings of
   * `settingsHostId` (§10.62: the round time and auto-start; a rematch keeps the previous round time and starts at
   * once); the hosts leave both random queues; audited `live.pk4.start`.
   */
  private async createMatchIn(
    tx: Prisma.TransactionClient,
    input: {
      format: Pk4FormatName;
      type: PkTypeName;
      source: 'INVITE' | 'RANDOM' | 'REMATCH';
      lobbyId: string | null;
      organiserRoomId: string;
      settingsHostId: string;
      hosts: readonly StartingHost[];
      actorId: string | null;
      now: Date;
      rematch?: { of: string; root: string; count: number; roundSeconds: number };
    },
  ): Promise<string> {
    const { now } = input;
    const s = await tx.pkHostSettings.findUnique({ where: { hostId: input.settingsHostId } });
    const roundSeconds =
      input.rematch?.roundSeconds ??
      (s?.roundMinutes !== null && s?.roundMinutes !== undefined
        ? s.roundMinutes * 60
        : this.config.pk.battleSeconds);
    const connected = input.rematch ? false : !(s?.autoStart ?? true);
    const plan = pk4SeatPlan(
      input.format,
      input.hosts.map((h) => h.seat),
    );
    const seated = input.hosts
      .map((h) => ({ ...h, seat: plan.get(h.seat)! }))
      .sort((a, b) => a.seat - b.seat);
    const id = uuidv7();
    await tx.pk4Match.create({
      data: {
        id,
        lobbyId: input.lobbyId,
        format: input.format,
        type: input.type,
        source: input.source,
        playerCount: seated.length,
        status: connected ? 'CONNECTED' : 'BATTLE',
        organiserRoomId: input.organiserRoomId,
        startedAt: now,
        battleEndsAt: new Date(
          now.getTime() + (connected ? this.config.pk.connectSeconds : roundSeconds) * 1000,
        ),
        connectedAt: connected ? now : null,
        roundSeconds,
        seq: 1,
        ...(input.rematch
          ? {
              rematchOf: input.rematch.of,
              rematchRootId: input.rematch.root,
              rematchCount: input.rematch.count,
            }
          : {}),
      },
    });
    await tx.pk4Seat.createMany({
      data: seated.map((h) => ({
        matchId: id,
        seat: h.seat,
        team: teamOfSeat(h.seat),
        roomId: h.roomId,
        hostId: h.hostId,
      })),
    });
    const hostIds = seated.map((h) => h.hostId);
    await tx.pkQueueEntry.deleteMany({ where: { hostId: { in: hostIds } } });
    await tx.pk4QueueEntry.deleteMany({ where: { hostId: { in: hostIds } } });
    await this.audit.recordIn(tx, {
      action: AuditAction.LIVE_PK4_START,
      actorUserId: input.actorId,
      targetType: 'pk4_match',
      targetId: id,
      metadata: {
        format: input.format,
        type: input.type,
        source: input.source,
        lobbyId: input.lobbyId,
        players: seated.length,
        rooms: seated.map((h) => h.roomId),
        seats: seated.map((h) => h.seat),
        roundSeconds,
        autoStart: !connected,
        ...(input.rematch ? { rematchOf: input.rematch.of, rematchCount: input.rematch.count } : {}),
      },
    });
    return id;
  }

  // ---- The match -------------------------------------------------------------------------------

  /** `POST …/pk4/start`: any host of the match starts a CONNECTED match (idempotent once running). */
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
    return this.matchDto(await this.matchById(match.id));
  }

  /**
   * `POST …/pk4/end`: during the battle the caller is out (FORFEIT) — TEAMS: the teammate carries on; FREE_FOR_ALL: the
   * others carry on; CONNECTED → CANCELLED; RESULT → CLOSED for the rooms (an open dare is settled as that host
   * leaving first, as §10.80).
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
      if (match.type === 'DARES') await this.settleDareOnLeave(match.id, room.id, callerId);
      await this.closeResult(match.id, true);
    }
    return this.matchDto(await this.matchById(match.id));
  }

  /** `POST …/pk4/mute` `{roomId, muted}`: a host mutes one of the other hosts for their own room. */
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
    return this.matchDto(await this.matchById(match.id));
  }

  /** A CONNECTED match that never started is closed at once — void (CANCELLED). */
  private async cancelConnected(matchId: string): Promise<boolean> {
    const now = iso(this.clock.now());
    const changed = await this.prisma.$transaction(async (tx) => {
      const n = await tx.$executeRaw`
        UPDATE pk4_matches
           SET status = 'CLOSED', ended_at = ${now}::timestamptz, result_ends_at = ${now}::timestamptz,
               closed_at = ${now}::timestamptz, end_reason = 'CANCELLED', effective = false, seq = seq + 1,
               top_a = '[]'::jsonb, top_b = '[]'::jsonb, top_seats = '{}'::jsonb
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
   * out). TEAMS: every host of a team out → the other team wins; everyone → a void draw (§10.180). FREE_FOR_ALL: one
   * host left on air → the battle ends (that host is 1st); everyone → a void draw (§10.181). Audited `live.pk4.out`.
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
          metadata: { seat: o.seat, team: seat.team, host: seat.host_id, reason: o.reason, format: m.format },
        });
      }
      const presence = seats.map((s) => ({
        seat: s.seat,
        team: s.team,
        out: s.out_reason ?? fresh.find((o) => o.seat === s.seat)?.reason ?? null,
      }));
      const last = fresh[fresh.length - 1]!.reason;
      let finish: Finish | null = null;
      if (m.format === 'FREE_FOR_ALL') {
        const outcome = ffaOutcome(presence, last);
        if (outcome.kind === 'end') {
          finish = {
            reason: outcome.reason,
            winner: null,
            loserCause: null,
            everyoneGone: outcome.everyoneGone,
          };
        }
      } else {
        const outcome = teamsOutcome(presence, last);
        if (outcome.kind === 'end') {
          finish = {
            reason: outcome.reason,
            winner: outcome.winner,
            loserCause: outcome.loserCause,
            everyoneGone: outcome.winner === null,
          };
        }
      }
      if (finish === null) {
        await tx.$executeRaw`UPDATE pk4_matches SET seq = seq + 1 WHERE id = ${matchId}::uuid`;
        return 'out';
      }
      await this.finishIn(tx, m, finish, actorId, now);
      return 'ended';
    }, LIVE_TX_OPTIONS);
    if (done) await this.broadcastMatch(matchId, done);
    return done;
  }

  /** The battle's time ran out: TEAMS — the higher team sum wins (equal: a draw); FREE_FOR_ALL — places by score. */
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
   * BATTLE → RESULT in the caller's transaction (the match row locked): the result (TEAMS: the winning team; FREE_FOR_ALL:
   * each host's place), `effective`, the top three supporters (per team, or per host) frozen, and — when it counts — a
   * win, loss or draw for each host with the PK points of `pk_dare_settings` (once per match and host; FREE_FOR_ALL: 1st
   * a win, equal 1st a draw, every other place a loss; «PK أحكام»: a host who left the battle and lost gets
   * `forfeitPoints`, as 1 v 1). «PK أحكام» with a result: the server's draw for the losing side. Audited `live.pk4.end`.
   */
  private async finishIn(
    tx: Prisma.TransactionClient,
    m: MatchRow,
    finish: Finish,
    actorId: string | null,
    now: Date,
  ): Promise<void> {
    const ffa = m.format === 'FREE_FOR_ALL';
    const endedAt = finish.reason === 'TIME' ? m.battle_ends_at : now;
    const winner = ffa
      ? null
      : finish.reason === 'TIME'
        ? teamWinnerByScore(m.score_a, m.score_b)
        : finish.winner;
    const seats = await this.seatsOf(tx, m.id);
    const total = seats.reduce((sum, s) => sum + s.score, 0n);
    const effective = isEffectivePk4({
      reason: finish.reason,
      everyoneGone: finish.everyoneGone,
      total,
      minPoints: this.config.pk.effectiveMinPoints,
    });
    // FREE_FOR_ALL places (never for everyone gone: a void draw).
    const places =
      ffa && !finish.everyoneGone
        ? ffaPlaces(seats.map((s) => ({ seat: s.seat, score: s.score, outAt: s.out_at })))
        : new Map<number, number>();
    for (const [seat, place] of places) {
      await tx.$executeRaw`UPDATE pk4_seats SET place = ${place} WHERE match_id = ${m.id}::uuid AND seat = ${seat}`;
    }
    const resultEndsAt = new Date(endedAt.getTime() + this.config.pk.resultSeconds * 1000);
    const top = await topTeamSupportersIn(tx, m.id);
    const topSeats = await topSeatSupportersIn(tx, m.id);
    await tx.$executeRaw`
      UPDATE pk4_matches
         SET status = 'RESULT', ended_at = ${iso(endedAt)}::timestamptz,
             result_ends_at = ${iso(resultEndsAt)}::timestamptz, end_reason = ${finish.reason}::pk_end_reason,
             winner_team = ${winner}::pk_side, loser_cause = ${finish.loserCause}::pk_side, seq = seq + 1,
             effective = ${effective}, top_a = ${JSON.stringify(top.A)}::jsonb, top_b = ${JSON.stringify(top.B)}::jsonb,
             top_seats = ${JSON.stringify(topSeats)}::jsonb
       WHERE id = ${m.id}::uuid`;
    const placeList = [...places.values()];
    const resultOf = (s: SeatRow): Pk4ResultName =>
      ffa
        ? ffaResult(places.get(s.seat) ?? seats.length, placeList)
        : winner === null
          ? 'DRAW'
          : s.team === winner
            ? 'WIN'
            : 'LOSS';
    const values = await pkDareSettingsIn(tx);
    if (effective) {
      for (const seat of seats) {
        const kind = resultOf(seat);
        const withdrew = m.type === 'DARES' && kind === 'LOSS' && seat.out_at !== null;
        await this.addPointsIn(tx, {
          matchId: m.id,
          hostId: seat.host_id,
          kind,
          points:
            kind === 'WIN'
              ? values.winPoints
              : kind === 'LOSS'
                ? withdrew
                  ? values.forfeitPoints
                  : values.lossPoints
                : values.drawPoints,
          counter: kind === 'WIN' ? 'wins' : kind === 'LOSS' ? 'losses' : 'draws',
          dares: m.type === 'DARES',
          now,
        });
      }
    }
    // v1.119-live (D395) «PK أحكام» for four: a result with a losing side (never a draw or a void match) → the draw.
    if (m.type === 'DARES' && !finish.everyoneGone) {
      const sides = pk4DareSides(
        m.format,
        seats.map((s) => ({
          seat: s.seat,
          team: s.team,
          hostId: s.host_id,
          place: ffa ? (places.get(s.seat) ?? null) : null,
          out: s.out_at !== null,
        })),
        winner,
      );
      if (sides) {
        const drawn = await drawPk4DareIn(tx, {
          matchId: m.id,
          loserSeats: sides.losers.map((s) => s.seat),
          loserHostIds: sides.losers.map((s) => s.hostId),
          winnerSeats: sides.winners.map((s) => s.seat),
          winnerHostIds: sides.winners.map((s) => s.hostId),
          now,
          drawSeconds: this.config.pk.dareDrawSeconds,
          decideSeconds: values.decideSeconds,
          ...(this.darePick ? { pick: this.darePick } : {}),
        });
        if (drawn) {
          await tx.$executeRaw`
            UPDATE pk4_matches SET result_ends_at = GREATEST(result_ends_at, ${iso(drawn.decideBy)}::timestamptz)
             WHERE id = ${m.id}::uuid`;
        } else {
          this.logger.warn({ matchId: m.id }, 'PK4 dares: no active dare at some level, no dare drawn');
        }
      }
    }
    await this.audit.recordIn(tx, {
      action: AuditAction.LIVE_PK4_END,
      actorUserId: actorId,
      targetType: 'pk4_match',
      targetId: m.id,
      metadata: {
        format: m.format,
        type: m.type,
        players: seats.length,
        reason: finish.reason,
        winner,
        loserCause: finish.loserCause,
        everyoneGone: finish.everyoneGone,
        scoreA: Number(m.score_a),
        scoreB: Number(m.score_b),
        ...(ffa ? { places: Object.fromEntries(places) } : {}),
        effective,
      },
    });
  }

  /**
   * The record and the PK points of one host for one 4-way match (idempotent by (match, host, kind)). A «PK أحكام»
   * match's points also count in `dares_points` (D300 «لاعب الأحكام», with its medal), as 1 v 1.
   */
  private async addPointsIn(
    tx: Prisma.TransactionClient,
    input: {
      matchId: string;
      hostId: string;
      kind: 'WIN' | 'LOSS' | 'DRAW' | 'DARE_REFUSED';
      points: number;
      counter: 'wins' | 'losses' | 'draws' | 'dares_refused';
      dares: boolean;
      now: Date;
    },
  ): Promise<void> {
    const at = iso(input.now);
    const inserted = await tx.$executeRaw`
      INSERT INTO pk4_point_events (match_id, host_id, kind, points, created_at)
      VALUES (${input.matchId}::uuid, ${input.hostId}::uuid, ${input.kind}, ${input.points}, ${at}::timestamptz)
      ON CONFLICT DO NOTHING`;
    if (inserted === 0) return;
    const one = (c: string) => (input.counter === c ? 1 : 0);
    const daresPoints = input.dares ? input.points : 0;
    const [record] = await tx.$queryRaw<{ dares_points: number }[]>`
      INSERT INTO pk_host_records (host_id, wins, losses, draws, points, dares_points, dares_done, dares_refused, updated_at)
      VALUES (${input.hostId}::uuid, ${one('wins')}, ${one('losses')}, ${one('draws')}, ${input.points}, ${daresPoints},
              0, ${one('dares_refused')}, ${at}::timestamptz)
      ON CONFLICT (host_id) DO UPDATE
         SET wins = pk_host_records.wins + EXCLUDED.wins, losses = pk_host_records.losses + EXCLUDED.losses,
             draws = pk_host_records.draws + EXCLUDED.draws, points = pk_host_records.points + EXCLUDED.points,
             dares_points = pk_host_records.dares_points + EXCLUDED.dares_points,
             dares_refused = pk_host_records.dares_refused + EXCLUDED.dares_refused,
             updated_at = EXCLUDED.updated_at
      RETURNING dares_points`;
    if (record && daresPoints > 0)
      await awardPkDaresMedalsIn(tx, input.hostId, record.dares_points, input.now);
    await this.audit.recordIn(tx, {
      action: AuditAction.LIVE_PK_POINTS,
      actorUserId: null,
      targetType: 'pk4_match',
      targetId: input.matchId,
      metadata: { host: input.hostId, kind: input.kind, points: input.points },
    });
  }

  /**
   * RESULT → CLOSED (nothing when it is no longer RESULT; not while its dare is open, unless `force` — a host's End);
   * the rooms told, watchers removed.
   */
  private async closeResult(matchId: string, force = false): Promise<boolean> {
    const now = this.clock.now();
    const closed = await this.prisma.$transaction(async (tx) => {
      const n = await tx.$executeRaw`
        UPDATE pk4_matches
           SET status = 'CLOSED', closed_at = ${iso(now)}::timestamptz, seq = seq + 1,
               rematch_by_room_id = NULL, rematch_expires_at = NULL, rematch_accepted = ARRAY[]::uuid[]
         WHERE id = ${matchId}::uuid AND status = 'RESULT'
           AND (${force} OR NOT EXISTS (SELECT 1 FROM pk4_match_dares d
                                         WHERE d.match_id = ${matchId}::uuid AND d.finished_at IS NULL))`;
      if (n > 0) {
        await tx.$executeRaw`UPDATE pk4_seats SET active = false WHERE match_id = ${matchId}::uuid`;
        // A host's End during the dare already settled it; anything still open ends with the match.
        await tx.$executeRaw`
          UPDATE pk4_match_dares SET status = 'CANCELLED', cause = 'WINNER_LEFT', finished_at = ${iso(now)}::timestamptz
           WHERE match_id = ${matchId}::uuid AND finished_at IS NULL`;
      }
      return n;
    }, LIVE_TX_OPTIONS);
    if (closed === 0) return false;
    await this.afterClose(matchId);
    return true;
  }

  /** Tells the rooms a match is CLOSED and disconnects its `pk4:` watchers from their media rooms. */
  private async afterClose(matchId: string, onlyRooms?: readonly string[]): Promise<void> {
    const dto = await this.broadcastMatch(matchId, 'closed', undefined, onlyRooms);
    if (!dto) return;
    const prefix = `${PK4_IDENTITY_PREFIX}${matchId}:`;
    for (const seat of dto.seats) {
      if (onlyRooms && !onlyRooms.includes(seat.roomId)) continue;
      try {
        const identities = await this.media.listIdentities(seat.roomId);
        for (const identity of identities.filter((i) =>
          i.startsWith(onlyRooms ? PK4_IDENTITY_PREFIX : prefix),
        )) {
          await this.media.removeParticipant(seat.roomId, identity);
        }
      } catch (err) {
        this.logger.warn({ error: safeErrorLog(err) }, 'Could not remove PK4 watchers from a media room');
      }
    }
  }

  /** Sends the match to its rooms (`pk4-match`; `onlyRooms`: those only); returns it (null when it does not exist). */
  private async broadcastMatch(
    matchId: string,
    event: Pk4MatchEvent,
    boost?: Pk4MatchData['boost'],
    onlyRooms?: readonly string[],
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
      if (onlyRooms && !onlyRooms.includes(seat.roomId)) continue;
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

  /** Sends `pk4-queue` to a host in their own room. */
  private async tellQueue(roomId: string, hostId: string, data: Pk4QueueData): Promise<void> {
    try {
      await this.media.sendData(roomId, hostId, JSON.stringify(data));
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not send a PK4 queue data message');
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
   * the active multiplier (TEAMS: the team's; FREE_FOR_ALL: the host's own) becomes the host's PK points (and the
   * team's sum; one row per send), the sender's support grows (TEAMS: of the team; FREE_FOR_ALL: of the host), and a
   * booster gift starts the booster (§10.58's rules with the uses per team or per host; a refusal rolls the whole send
   * back: 409 PK_BOOSTER_UNAVAILABLE). «PK أحكام»: a lucky gift adds no PK points (§10.80). A host out of the battle:
   * nothing counts in their room.
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
      lucky?: boolean;
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
    const ffa = m.format === 'FREE_FOR_ALL';
    const team = seat.team;
    // FREE_FOR_ALL: the host's own booster and supporters (their place); TEAMS: the team's (place 0 / null).
    const own = ffa ? seat.seat : null;
    const at = iso(input.now);
    const [active] = await tx.$queryRaw<{ id: string; multiplier: number }[]>`
      SELECT id::text AS id, multiplier FROM pk4_boosts
       WHERE match_id = ${m.id}::uuid AND team = ${team}::pk_side
         AND seat IS NOT DISTINCT FROM ${own}::smallint
         AND starts_at <= ${at}::timestamptz AND ends_at > ${at}::timestamptz
       ORDER BY multiplier DESC LIMIT 1`;
    const activeMultiplier = active?.multiplier ?? 1;
    let boosted: Pk4GiftCredit['boosted'] = null;
    if (input.booster !== null) {
      const rule = boosterRule(this.config.pk.boosters, input.booster);
      const [used] = await tx.$queryRaw<{ n: number }[]>`
        SELECT count(*)::int AS n FROM pk4_boosts
         WHERE match_id = ${m.id}::uuid AND team = ${team}::pk_side AND seat IS NOT DISTINCT FROM ${own}::smallint
           AND kind = ${input.booster}::pk_booster_kind`;
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
        INSERT INTO pk4_boosts (id, match_id, team, seat, kind, multiplier, gift_id, gift_code, sender_id, room_id,
                                starts_at, ends_at)
        VALUES (${uuidv7()}::uuid, ${m.id}::uuid, ${team}::pk_side, ${own}::smallint, ${input.booster}::pk_booster_kind,
                ${rule.multiplier}, ${input.giftId}::uuid, ${input.giftCode}, ${input.senderId}::uuid,
                ${input.roomId}::uuid, ${at}::timestamptz, ${iso(endsAt)}::timestamptz)`;
      boosted = {
        team,
        seat: own,
        roomId: input.roomId,
        kind: input.booster,
        multiplier: rule.multiplier,
        endsAt,
      };
    }
    // §10.80: in «PK أحكام» a lucky gift adds no PK points (it is still a gift for everything else).
    const coins = m.type === 'DARES' && input.lucky === true ? 0n : BigInt(input.coins);
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
          INSERT INTO pk4_supporters (match_id, team, seat, user_id, points)
          VALUES (${m.id}::uuid, ${team}::pk_side, ${own ?? 0}, ${input.senderId}::uuid, ${points})
          ON CONFLICT (match_id, team, seat, user_id) DO UPDATE SET points = pk4_supporters.points + EXCLUDED.points`;
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
        seat: b.seat,
        roomId: b.roomId,
        kind: b.kind,
        multiplier: b.multiplier,
        endsAt: iso(b.endsAt),
      });
      return;
    }
    await this.scoreThrottle.touch(credit.matchId);
  }

  // ---- «PK أحكام» for four (v1.119-live, D395, CP-041 §7) --------------------------------------

  /**
   * The caller's room's open RESULT match of type DARES with its dare (404 / 409 PK_NOT_ACTIVE otherwise), and the
   * caller's side in it: a loser (does the dare), a winner (judges) or neither (403 PK_DARE_FORBIDDEN for any answer).
   */
  private async ownDare(
    callerId: string,
    roomId: string,
  ): Promise<{ match: MatchRow; dare: DareRow; side: 'LOSER' | 'WINNER' | 'NONE' }> {
    const room = await this.ownRoom(callerId, roomId);
    const match = await this.openMatchOfRoom(this.prisma, room.id);
    if (!match || match.type !== 'DARES') throw new AppException(ErrorCode.PK_NOT_ACTIVE);
    const dare = await this.dareRow(this.prisma, match.id);
    if (!dare) throw new AppException(ErrorCode.PK_NOT_ACTIVE);
    const seat = (await this.seatsOf(this.prisma, match.id)).find((s) => s.room_id === room.id);
    const side =
      seat === undefined
        ? 'NONE'
        : dare.loser_seats.includes(seat.seat)
          ? 'LOSER'
          : dare.winner_seats.includes(seat.seat)
            ? 'WINNER'
            : 'NONE';
    return { match, dare, side };
  }

  /**
   * Ends an open 4-way dare (under its row lock; nothing when it is no longer in one of `from`): DONE — each losing
   * host's «dares done» + 1; REFUSED — each losing host's refusal points (`refusePoints`) and «dares refused» + 1;
   * CANCELLED — nothing. The result phase then lasts as §10.80 (D276). Audited (target `pk4_match`).
   */
  private async finishDare(
    matchId: string,
    outcome: { status: 'DONE' | 'REFUSED' | 'CANCELLED'; cause: NonNullable<PkDareDto['cause']> },
    from: readonly DareRow['status'][],
    actorId: string | null,
  ): Promise<boolean> {
    const now = this.clock.now();
    const done = await this.prisma.$transaction(async (tx) => {
      const d = await this.dareRow(tx, matchId, true);
      if (!d || d.finished_at !== null || !from.includes(d.status)) return false;
      const settings = await pkDareSettingsIn(tx);
      const points = outcome.status === 'REFUSED' ? settings.refusePoints : 0;
      await tx.$executeRaw`
        UPDATE pk4_match_dares
           SET status = ${outcome.status}::pk_dare_status, cause = ${outcome.cause}::pk_dare_cause,
               finished_at = ${iso(now)}::timestamptz, points = ${points},
               judged_by = CASE WHEN ${outcome.cause} IN ('WINNER_DONE', 'WINNER_NOT_DONE')
                                THEN ${actorId}::uuid ELSE judged_by END,
               answered_by = CASE WHEN ${outcome.cause} = 'LOSER_REFUSED' THEN ${actorId}::uuid ELSE answered_by END
         WHERE match_id = ${matchId}::uuid`;
      for (const host of d.loser_host_ids) {
        if (outcome.status === 'REFUSED') {
          await this.addPointsIn(tx, {
            matchId,
            hostId: host,
            kind: 'DARE_REFUSED',
            points,
            counter: 'dares_refused',
            dares: true,
            now,
          });
        } else if (outcome.status === 'DONE') {
          await addPkDareDoneIn(tx, host, now);
        }
      }
      const { resultSeconds, dareOutcomeSeconds, rematchMax } = this.config.pk;
      const after = Math.max(resultSeconds, dareOutcomeSeconds);
      await tx.$executeRaw`
        UPDATE pk4_matches
           SET result_ends_at = GREATEST(ended_at + make_interval(secs => ${resultSeconds}),
                                         ${iso(now)}::timestamptz + make_interval(secs => (CASE
                                           WHEN ${rematchMax}::int = 0 OR rematch_count < ${rematchMax}::int
                                           THEN ${after}::int ELSE ${dareOutcomeSeconds}::int END))),
               seq = seq + 1
         WHERE id = ${matchId}::uuid AND status = 'RESULT'`;
      const action =
        outcome.cause === 'LOSER_REFUSED'
          ? AuditAction.LIVE_PK_DARE_ANSWER
          : outcome.cause === 'WINNER_DONE' || outcome.cause === 'WINNER_NOT_DONE'
            ? AuditAction.LIVE_PK_DARE_VERDICT
            : AuditAction.LIVE_PK_DARE_END;
      await this.audit.recordIn(tx, {
        action,
        actorUserId: actorId,
        targetType: 'pk4_match',
        targetId: matchId,
        metadata: {
          dareId: d.dare_id,
          status: outcome.status,
          cause: outcome.cause,
          points,
          from: d.status,
          losers: d.loser_host_ids,
        },
      });
      return true;
    }, LIVE_TX_OPTIONS);
    if (done) await this.broadcastMatch(matchId, 'dare');
    return done;
  }

  private assertDeciding(dare: DareRow, now: Date): void {
    if (dare.status !== 'DECIDING') throw new AppException(ErrorCode.PK_DARE_CLOSED);
    if (now.getTime() < dare.reveal_at.getTime() || now.getTime() >= dare.decide_by.getTime()) {
      throw new AppException(ErrorCode.PK_DARE_CLOSED);
    }
  }

  /**
   * `POST /live/rooms/{roomId}/pk4/dare/accept` «قبول»: a losing host answers for the losing side (§10.181), after the
   * reveal and before `decideBy` → ACTIVE: the timer (PK_DARE_SECONDS) starts in every room. Any other host 403
   * PK_DARE_FORBIDDEN. Already accepted: the match as it is.
   */
  async acceptDare(callerId: string, roomId: string): Promise<Pk4MatchDto> {
    const { match, dare, side } = await this.ownDare(callerId, roomId);
    if (side !== 'LOSER') throw new AppException(ErrorCode.PK_DARE_FORBIDDEN);
    if (dare.status === 'ACTIVE') return this.matchDto(match);
    const now = this.clock.now();
    this.assertDeciding(dare, now);
    const endsAt = new Date(now.getTime() + this.config.pk.dareSeconds * 1000);
    const changed = await this.prisma.$transaction(async (tx) => {
      const n = await tx.$executeRaw`
        UPDATE pk4_match_dares SET status = 'ACTIVE', started_at = ${iso(now)}::timestamptz,
               ends_at = ${iso(endsAt)}::timestamptz, answered_by = ${callerId}::uuid
         WHERE match_id = ${match.id}::uuid AND status = 'DECIDING' AND decide_by > ${iso(now)}::timestamptz`;
      if (n === 0) return false;
      await tx.$executeRaw`
        UPDATE pk4_matches
           SET result_ends_at = GREATEST(result_ends_at, ${iso(endsAt)}::timestamptz
                                         + make_interval(secs => ${this.config.pk.dareOutcomeSeconds})),
               seq = seq + 1
         WHERE id = ${match.id}::uuid`;
      await this.audit.recordIn(tx, {
        action: AuditAction.LIVE_PK_DARE_ANSWER,
        actorUserId: callerId,
        targetType: 'pk4_match',
        targetId: match.id,
        metadata: { dareId: dare.dare_id, answer: 'ACCEPTED', endsAt: iso(endsAt) },
      });
      return true;
    }, LIVE_TX_OPTIONS);
    if (changed) return (await this.broadcastMatch(match.id, 'dare'))!;
    const again = await this.dareRow(this.prisma, match.id);
    if (again?.status !== 'ACTIVE') throw new AppException(ErrorCode.PK_DARE_CLOSED);
    return this.matchDto(await this.matchById(match.id));
  }

  /**
   * `POST /live/rooms/{roomId}/pk4/dare/refuse` «رفض»: a losing host refuses for the losing side while deciding →
   * REFUSED: every losing host gets the refusal's points at once. Already refused: the match as it is.
   */
  async refuseDare(callerId: string, roomId: string): Promise<Pk4MatchDto> {
    const { match, dare, side } = await this.ownDare(callerId, roomId);
    if (side !== 'LOSER') throw new AppException(ErrorCode.PK_DARE_FORBIDDEN);
    if (dare.status === 'REFUSED' && dare.cause === 'LOSER_REFUSED') return this.matchDto(match);
    this.assertDeciding(dare, this.clock.now());
    const ok = await this.finishDare(
      match.id,
      { status: 'REFUSED', cause: 'LOSER_REFUSED' },
      ['DECIDING'],
      callerId,
    );
    if (!ok) {
      const again = await this.dareRow(this.prisma, match.id);
      if (!(again?.status === 'REFUSED' && again.cause === 'LOSER_REFUSED')) {
        throw new AppException(ErrorCode.PK_DARE_CLOSED);
      }
    }
    return this.matchDto(await this.matchById(match.id));
  }

  /**
   * `POST /live/rooms/{roomId}/pk4/dare/verdict` `{done}`: a winning host judges for the winning side during the timer
   * (the first verdict counts; the same one again answers the match, another 409 PK_DARE_CLOSED).
   */
  async judgeDare(callerId: string, roomId: string, body: unknown): Promise<Pk4MatchDto> {
    const parsed = verdictSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const { match, dare, side } = await this.ownDare(callerId, roomId);
    if (side !== 'WINNER') throw new AppException(ErrorCode.PK_DARE_FORBIDDEN);
    const want = parsed.data.done ? 'WINNER_DONE' : 'WINNER_NOT_DONE';
    if (dare.cause === want) return this.matchDto(match);
    const now = this.clock.now();
    if (dare.status !== 'ACTIVE' || dare.ends_at === null || now.getTime() >= dare.ends_at.getTime()) {
      throw new AppException(ErrorCode.PK_DARE_CLOSED);
    }
    const ok = await this.finishDare(
      match.id,
      parsed.data.done
        ? { status: 'DONE', cause: 'WINNER_DONE' }
        : { status: 'REFUSED', cause: 'WINNER_NOT_DONE' },
      ['ACTIVE'],
      callerId,
    );
    if (!ok) {
      const again = await this.dareRow(this.prisma, match.id);
      if (again?.cause !== want) throw new AppException(ErrorCode.PK_DARE_CLOSED);
    }
    return this.matchDto(await this.matchById(match.id));
  }

  /**
   * `POST /live/rooms/{roomId}/pk4/dare/report` `{dareId}`: as §10.80 — anyone signed in who may watch the room, one of
   * its match's three cards; one report per person per dare; auto-disabled at `reportsToDisable`.
   */
  async reportDare(callerId: string, roomId: string, body: unknown): Promise<void> {
    const parsed = reportSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (row.kicked) throw new AppException(ErrorCode.LIVE_KICKED);
    const match = await this.openMatchOfRoom(this.prisma, row.id);
    const dare = match ? await this.dareRow(this.prisma, match.id) : null;
    const dareId = parsed.data.dareId.toLowerCase();
    if (!match || !dare || !dare.option_ids.includes(dareId)) throw new AppException(ErrorCode.NOT_FOUND);
    const now = this.clock.now();
    await this.prisma.$transaction(async (tx) => {
      // `pk_dare_reports.match_id` belongs to PK 1 v 1's matches: a 4-way report keeps it null (audited with the id).
      const inserted = await tx.$executeRaw`
        INSERT INTO pk_dare_reports (dare_id, user_id, match_id, created_at)
        VALUES (${dareId}::uuid, ${callerId}::uuid, NULL, ${iso(now)}::timestamptz)
        ON CONFLICT DO NOTHING`;
      if (inserted === 0) return;
      const [d] = await tx.$queryRaw<{ report_count: number; active: boolean }[]>`
        UPDATE pk_dares SET report_count = report_count + 1, updated_at = ${iso(now)}::timestamptz
         WHERE id = ${dareId}::uuid RETURNING report_count, active`;
      await this.audit.recordIn(tx, {
        action: AuditAction.LIVE_PK_DARE_REPORT,
        actorUserId: callerId,
        targetType: 'pk_dare',
        targetId: dareId,
        metadata: { pk4MatchId: match.id, reports: d?.report_count ?? 0 },
      });
      const settings = await pkDareSettingsIn(tx);
      if (d && d.active && d.report_count >= settings.reportsToDisable) {
        await tx.$executeRaw`
          UPDATE pk_dares SET active = false, disabled_reason = 'REPORTS' WHERE id = ${dareId}::uuid`;
        await this.audit.recordIn(tx, {
          action: AuditAction.PK_DARE_AUTO_DISABLE,
          actorUserId: null,
          targetType: 'pk_dare',
          targetId: dareId,
          metadata: { reports: d.report_count, threshold: settings.reportsToDisable },
        });
      }
    }, LIVE_TX_OPTIONS);
  }

  /** A host ends the PK (End) during an open dare: a loser → refused (LOSER_LEFT); a judge → as §10.80. */
  private async settleDareOnLeave(matchId: string, roomId: string, actorId: string | null): Promise<void> {
    const dare = await this.dareRow(this.prisma, matchId);
    if (!dare || dare.finished_at !== null) return;
    const seat = (await this.seatsOf(this.prisma, matchId)).find((s) => s.room_id === roomId);
    if (seat && dare.loser_seats.includes(seat.seat)) {
      await this.finishDare(
        matchId,
        { status: 'REFUSED', cause: 'LOSER_LEFT' },
        ['DECIDING', 'ACTIVE'],
        actorId,
      );
    } else if (dare.status === 'ACTIVE') {
      await this.finishDare(matchId, { status: 'DONE', cause: 'WINNER_LEFT' }, ['ACTIVE'], actorId);
    } else {
      await this.finishDare(matchId, { status: 'CANCELLED', cause: 'WINNER_LEFT' }, ['DECIDING'], actorId);
    }
  }

  /**
   * The tick for a RESULT match of type DARES (true while its dare is open: the match stays open this tick): every
   * losing host gone → refused (LOSER_LEFT); no answer by `decideBy` → refused (DECIDE_TIMEOUT); the timer over with no
   * verdict → done (TIMER). Judges gone change nothing.
   */
  private async dareTick(m: MatchRow, now: Date, grace: number): Promise<boolean> {
    const d = await this.dareRow(this.prisma, m.id);
    if (!d || d.finished_at !== null) return false;
    const seats = await this.seatsOf(this.prisma, m.id);
    let present = 0;
    for (const seat of seats.filter((s) => d.loser_seats.includes(s.seat))) {
      const room = await this.roomState(this.prisma, seat.room_id);
      const gone =
        room === null ||
        absenceOf(
          {
            roomStatus: room.status,
            roomEndReason: room.end_reason,
            lastHeartbeatAt: room.last_heartbeat_at,
            hostAwaySince: room.host_away_since,
            leftAt: null,
          },
          now,
          grace,
        ) !== null;
      if (!gone) present += 1;
    }
    if (present === 0) {
      await this.finishDare(m.id, { status: 'REFUSED', cause: 'LOSER_LEFT' }, ['DECIDING', 'ACTIVE'], null);
      return true;
    }
    if (d.status === 'DECIDING' && d.decide_by.getTime() <= now.getTime()) {
      await this.finishDare(m.id, { status: 'REFUSED', cause: 'DECIDE_TIMEOUT' }, ['DECIDING'], null);
      return true;
    }
    if (d.status === 'ACTIVE' && d.ends_at !== null && d.ends_at.getTime() <= now.getTime()) {
      await this.finishDare(m.id, { status: 'DONE', cause: 'TIMER' }, ['ACTIVE'], null);
      return true;
    }
    return true;
  }

  // ---- «جولة أخرى» for four (v1.119-live, D395, CP-041 §7) ------------------------------------

  /** The caller's room's open match under its rooms' PK locks (FOR UPDATE), with its places. None → PK_NOT_ACTIVE. */
  private async lockedOwnMatch(
    tx: Prisma.TransactionClient,
    roomId: string,
  ): Promise<{ match: MatchRow; seats: SeatRow[] }> {
    const first = await this.openMatchOfRoom(tx, roomId);
    if (!first) throw new AppException(ErrorCode.PK_NOT_ACTIVE);
    const before = await this.seatsOf(tx, first.id);
    await this.lockRooms(
      tx,
      before.map((s) => s.room_id),
    );
    const match = await this.matchRow(tx, Prisma.sql`id = ${first.id}::uuid`, true);
    if (!match || match.status === 'CLOSED') throw new AppException(ErrorCode.PK_NOT_ACTIVE);
    return { match, seats: await this.seatsOf(tx, match.id) };
  }

  /**
   * The present hosts who would play «جولة أخرى» (409 PK_REMATCH_UNAVAILABLE otherwise): the match in RESULT with its
   * dare over (or none); fewer than PK_REMATCH_MAX rematches in a row; at least two hosts present (not out of the
   * battle, their lives SOLO video, fresh heartbeat, present), ACTIVE, with no block between any two of them.
   */
  private async rematchPlayersIn(
    tx: Prisma.TransactionClient,
    m: MatchRow,
    seats: readonly SeatRow[],
    now: Date,
  ): Promise<SeatRow[]> {
    const unavailable = () => new AppException(ErrorCode.PK_REMATCH_UNAVAILABLE);
    if (m.status !== 'RESULT') throw unavailable();
    if (this.config.pk.rematchMax > 0 && m.rematch_count >= this.config.pk.rematchMax) throw unavailable();
    const [open] = await tx.$queryRaw<{ open: boolean }[]>`
      SELECT EXISTS (SELECT 1 FROM pk4_match_dares d WHERE d.match_id = ${m.id}::uuid AND d.finished_at IS NULL) AS open`;
    if (open?.open) throw unavailable();
    const present = await this.presentSeats(tx, seats, now);
    const active = await tx.user.findMany({
      where: { id: { in: present.map((s) => s.host_id) }, status: 'ACTIVE' },
      select: { id: true },
    });
    const players = present.filter((s) => active.some((a) => a.id === s.host_id));
    if (players.length < 2) throw unavailable();
    if (
      await this.blockedAmong(
        tx,
        players.map((s) => s.host_id),
      )
    )
      throw unavailable();
    return players;
  }

  /**
   * v1.119-live (D395) `POST /live/rooms/{roomId}/pk4/rematch` «جولة أخرى»: a present host of a RESULT match offers
   * another battle; every present host must accept within PK_REMATCH_ACCEPT_SECONDS (the result is kept open that long).
   * An offer already open: this host's tap is an acceptance (idempotent once accepted). Event `rematch-offer` (or
   * `rematch-accepted` / `rematch`).
   */
  async offerRematch(callerId: string, roomId: string): Promise<Pk4MatchDto> {
    this.assertOn();
    const room = await this.ownRoom(callerId, roomId);
    const now = this.clock.now();
    const result = await this.prisma.$transaction(
      async (
        tx,
      ): Promise<{ kind: 'offered' | 'same' | 'accepted' | 'started'; id: string; old?: string }> => {
        const { match, seats } = await this.lockedOwnMatch(tx, room.id);
        if (match.status === 'BATTLE' && match.rematch_of !== null) return { kind: 'same', id: match.id };
        const pending =
          match.rematch_by_room_id !== null &&
          match.rematch_expires_at !== null &&
          match.rematch_expires_at.getTime() > now.getTime();
        if (pending) {
          if (match.rematch_accepted.includes(room.id)) return { kind: 'same', id: match.id };
          return this.acceptRematchIn(tx, match, seats, room.id, callerId, now);
        }
        const players = await this.rematchPlayersIn(tx, match, seats, now);
        if (!players.some((s) => s.room_id === room.id)) {
          throw new AppException(ErrorCode.PK_REMATCH_UNAVAILABLE);
        }
        const expires = new Date(now.getTime() + this.config.pk.rematchAcceptSeconds * 1000);
        await tx.$executeRaw`
          UPDATE pk4_matches
             SET rematch_by_room_id = ${room.id}::uuid, rematch_expires_at = ${iso(expires)}::timestamptz,
                 rematch_accepted = ARRAY[${room.id}::uuid],
                 result_ends_at = GREATEST(COALESCE(result_ends_at, ${iso(expires)}::timestamptz), ${iso(expires)}::timestamptz),
                 seq = seq + 1
           WHERE id = ${match.id}::uuid`;
        await this.audit.recordIn(tx, {
          action: AuditAction.LIVE_PK4_REMATCH,
          actorUserId: callerId,
          targetType: 'pk4_match',
          targetId: match.id,
          metadata: { event: 'offered', roomId: room.id, players: players.length, expiresAt: iso(expires) },
        });
        return { kind: 'offered', id: match.id };
      },
      LIVE_TX_OPTIONS,
    );
    return this.afterRematchStep(result);
  }

  /**
   * v1.119-live (D395) `POST /live/rooms/{roomId}/pk4/rematch/accept`: a present host accepts the open offer; the last
   * acceptance starts the new battle at once (`rematch`). No open offer → 409 PK_REMATCH_CLOSED.
   */
  async acceptRematch(callerId: string, roomId: string): Promise<Pk4MatchDto> {
    this.assertOn();
    const room = await this.ownRoom(callerId, roomId);
    const now = this.clock.now();
    const result = await this.prisma.$transaction(async (tx) => {
      const { match, seats } = await this.lockedOwnMatch(tx, room.id);
      if (match.status === 'BATTLE' && match.rematch_of !== null)
        return { kind: 'same' as const, id: match.id };
      if (
        match.status !== 'RESULT' ||
        match.rematch_by_room_id === null ||
        match.rematch_expires_at === null ||
        match.rematch_expires_at.getTime() <= now.getTime()
      ) {
        throw new AppException(ErrorCode.PK_REMATCH_CLOSED);
      }
      if (match.rematch_accepted.includes(room.id)) return { kind: 'same' as const, id: match.id };
      return this.acceptRematchIn(tx, match, seats, room.id, callerId, now);
    }, LIVE_TX_OPTIONS);
    return this.afterRematchStep(result);
  }

  /** In a transaction: one more acceptance; every present host in → the new battle. */
  private async acceptRematchIn(
    tx: Prisma.TransactionClient,
    match: MatchRow,
    seats: readonly SeatRow[],
    roomId: string,
    actorId: string,
    now: Date,
  ): Promise<{ kind: 'accepted' | 'started'; id: string; old?: string }> {
    const players = await this.rematchPlayersIn(tx, match, seats, now);
    if (!players.some((s) => s.room_id === roomId)) throw new AppException(ErrorCode.PK_REMATCH_UNAVAILABLE);
    const accepted = [...new Set([...match.rematch_accepted, roomId])];
    await this.audit.recordIn(tx, {
      action: AuditAction.LIVE_PK4_REMATCH,
      actorUserId: actorId,
      targetType: 'pk4_match',
      targetId: match.id,
      metadata: { event: 'accepted', roomId },
    });
    if (!players.every((s) => accepted.includes(s.room_id))) {
      await tx.$executeRaw`
        UPDATE pk4_matches SET rematch_accepted = ${accepted}::uuid[], seq = seq + 1 WHERE id = ${match.id}::uuid`;
      return { kind: 'accepted', id: match.id };
    }
    // Every present host accepted: the old match closes quietly (no `closed` for the players: their 4-way media
    // stays, the chain's watcher identities remain valid) and the new battle starts at once.
    await tx.$executeRaw`
      UPDATE pk4_matches
         SET status = 'CLOSED', closed_at = ${iso(now)}::timestamptz, rematch_by_room_id = NULL,
             rematch_expires_at = NULL, rematch_accepted = ARRAY[]::uuid[], seq = seq + 1
       WHERE id = ${match.id}::uuid AND status = 'RESULT'`;
    await tx.$executeRaw`UPDATE pk4_seats SET active = false WHERE match_id = ${match.id}::uuid`;
    const organiser = players.find((s) => s.room_id === match.organiser_room_id) ?? players[0]!;
    const id = await this.createMatchIn(tx, {
      format: match.format,
      type: match.type === 'DARES' && this.config.pk.daresEnabled ? 'DARES' : 'NORMAL',
      source: 'REMATCH',
      lobbyId: null,
      organiserRoomId: organiser.room_id,
      settingsHostId: organiser.host_id,
      hosts: players.map((s) => ({ roomId: s.room_id, hostId: s.host_id, seat: s.seat })),
      actorId,
      now,
      rematch: {
        of: match.id,
        root: match.rematch_root_id ?? match.id,
        count: match.rematch_count + 1,
        roundSeconds: match.round_seconds,
      },
    });
    // The hosts' mutes carry over to the new places.
    for (const s of players) {
      if (s.muted_room_ids.length === 0) continue;
      await tx.$executeRaw`
        UPDATE pk4_seats SET muted_room_ids = ${s.muted_room_ids}::uuid[]
         WHERE match_id = ${id}::uuid AND room_id = ${s.room_id}::uuid`;
    }
    return { kind: 'started', id, old: match.id };
  }

  private async afterRematchStep(result: {
    kind: 'offered' | 'same' | 'accepted' | 'started';
    id: string;
    old?: string;
  }): Promise<Pk4MatchDto> {
    if (result.kind === 'offered') return (await this.broadcastMatch(result.id, 'rematch-offer'))!;
    if (result.kind === 'accepted') return (await this.broadcastMatch(result.id, 'rematch-accepted'))!;
    if (result.kind === 'started') {
      const dto = (await this.broadcastMatch(result.id, 'rematch'))!;
      // The rooms that do not play again (gone, or out of the battle) get the old match's `closed`.
      if (result.old) {
        const old = await this.seatsOf(this.prisma, result.old);
        const dropped = old.map((s) => s.room_id).filter((r) => !dto.seats.some((s) => s.roomId === r));
        if (dropped.length > 0) await this.afterClose(result.old, dropped);
      }
      return dto;
    }
    return this.matchDto(await this.matchById(result.id));
  }

  /**
   * v1.119-live (D395) `POST /live/rooms/{roomId}/pk4/rematch/decline`: a present host who has not accepted says no —
   * the offer ends (`rematch-declined`) and the PK closes as usual.
   */
  async declineRematch(callerId: string, roomId: string): Promise<void> {
    const room = await this.ownRoom(callerId, roomId);
    const now = this.clock.now();
    const id = await this.prisma.$transaction(async (tx) => {
      const { match } = await this.lockedOwnMatch(tx, room.id);
      if (
        match.status !== 'RESULT' ||
        match.rematch_by_room_id === null ||
        match.rematch_accepted.includes(room.id) ||
        match.rematch_expires_at === null ||
        match.rematch_expires_at.getTime() <= now.getTime()
      ) {
        throw new AppException(ErrorCode.PK_REMATCH_CLOSED);
      }
      return match.id;
    }, LIVE_TX_OPTIONS);
    await this.endRematchOffer(id, 'rematch-declined', null, callerId);
  }

  /**
   * v1.119-live (D395) `DELETE /live/rooms/{roomId}/pk4/rematch`: the asking host withdraws the offer
   * (`rematch-cancelled`); the result goes on until its own end. No offer of theirs open → 409 PK_REMATCH_CLOSED.
   */
  async cancelRematch(callerId: string, roomId: string): Promise<Pk4MatchDto> {
    const room = await this.ownRoom(callerId, roomId);
    const now = this.clock.now();
    const id = await this.prisma.$transaction(async (tx) => {
      const { match } = await this.lockedOwnMatch(tx, room.id);
      if (
        match.status !== 'RESULT' ||
        match.rematch_by_room_id !== room.id ||
        match.rematch_expires_at === null ||
        match.rematch_expires_at.getTime() <= now.getTime()
      ) {
        throw new AppException(ErrorCode.PK_REMATCH_CLOSED);
      }
      return match.id;
    }, LIVE_TX_OPTIONS);
    await this.endRematchOffer(id, 'rematch-cancelled', 'keep', callerId);
    return this.matchDto(await this.matchById(id));
  }

  /** Ends an open offer (still open: the guard): `event` to the rooms; then, unless `keep`, the PK closes as usual. */
  private async endRematchOffer(
    matchId: string,
    event: 'rematch-cancelled' | 'rematch-declined' | 'rematch-expired',
    keep: 'keep' | null,
    actorId: string | null,
  ): Promise<boolean> {
    const changed = await this.prisma.$transaction(async (tx) => {
      const n = await tx.$executeRaw`
        UPDATE pk4_matches SET rematch_by_room_id = NULL, rematch_expires_at = NULL,
               rematch_accepted = ARRAY[]::uuid[], seq = seq + 1
         WHERE id = ${matchId}::uuid AND status = 'RESULT' AND rematch_by_room_id IS NOT NULL`;
      if (n > 0) {
        await this.audit.recordIn(tx, {
          action: AuditAction.LIVE_PK4_REMATCH,
          actorUserId: actorId,
          targetType: 'pk4_match',
          targetId: matchId,
          metadata: { event: event.replace('rematch-', '') },
        });
      }
      return n;
    }, LIVE_TX_OPTIONS);
    if (changed === 0) return false;
    await this.broadcastMatch(matchId, event);
    if (keep === null) await this.closeResult(matchId, true);
    return true;
  }

  // ---- The 4-way random queue (v1.119-live, D395, CP-041 §3.2) ---------------------------------

  /**
   * `POST /live/rooms/{roomId}/pk4/random` `{format, type?}` «مطابقة عشوائية»: the caller's eligible room joins the 4-way
   * queue of that format and type (a wait of the caller's in another queue — 1 v 1 or another format — is replaced).
   * Serialized by one queue lock: the caller and the three longest waiters who can play together (no block between any
   * two, both hosts' gender / region preferences, §10.62; eligible rooms, not busy) are matched at once (`MATCHED`; TEAMS:
   * the two teams drawn at random; FREE_FOR_ALL: the places at random); otherwise the caller waits up to
   * PK4_RANDOM_WAIT_SECONDS (`WAITING`; again: the same wait). Busy otherwise → 409 PK_HOST_BUSY. Only four: a 4-way
   * random match never starts with fewer.
   */
  async joinRandom(callerId: string, roomId: string, body: unknown): Promise<Pk4RandomResultDto> {
    this.assertOn();
    const parsed = randomSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const { format } = parsed.data;
    const type = this.typeOf(parsed.data.type);
    const now = this.clock.now();
    const own = await this.ownEligibleRoom(callerId, roomId, now);
    type Waiter = {
      hostId: string;
      roomId: string;
      gender: string | null;
      country: string | null;
      wantGender: PkGenderPrefName;
      wantRegion: PkRegionPrefName;
      blocks: Set<string>;
    };
    const outcome: { matched: string | null; group: Waiter[]; waiting: Pk4QueueDto | null } = {
      matched: null,
      group: [],
      waiting: null,
    };
    await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended('pk4-queue', 0))`;
      const existing = await tx.pk4QueueEntry.findUnique({ where: { hostId: callerId } });
      if (
        existing &&
        existing.roomId === own.id &&
        existing.format === format &&
        existing.type === type &&
        existing.expiresAt.getTime() > now.getTime()
      ) {
        outcome.waiting = {
          format,
          type,
          joinedAt: iso(existing.joinedAt),
          expiresAt: iso(existing.expiresAt),
        };
        return;
      }
      // One wait per host: a 4-way wait of another format or type, or a 1 v 1 wait, is replaced.
      await tx.pk4QueueEntry.deleteMany({ where: { hostId: callerId } });
      await tx.pkQueueEntry.deleteMany({ where: { hostId: callerId } });
      const rows = await tx.$queryRaw<
        {
          host_id: string;
          room_id: string;
          gender: string | null;
          country: string | null;
          g: PkGenderPrefName;
          c: PkRegionPrefName;
        }[]
      >`
        SELECT p.user_id::text AS host_id, ${own.id}::text AS room_id, p.gender::text AS gender, p.country_code AS country,
               COALESCE(s.random_gender::text, 'BOTH') AS g, COALESCE(s.random_region::text, 'GLOBAL') AS c
          FROM user_profiles p LEFT JOIN pk_host_settings s ON s.host_id = p.user_id
         WHERE p.user_id = ${callerId}::uuid
        UNION ALL
        SELECT * FROM (
          SELECT q.host_id::text AS host_id, q.room_id::text AS room_id, pp.gender::text AS gender,
                 pp.country_code AS country, COALESCE(ps.random_gender::text, 'BOTH') AS g,
                 COALESCE(ps.random_region::text, 'GLOBAL') AS c
            FROM pk4_queue q
            JOIN live_rooms r ON r.id = q.room_id
            JOIN users u ON u.id = q.host_id AND u.status = 'ACTIVE'::user_status
            JOIN user_profiles pp ON pp.user_id = q.host_id
            LEFT JOIN pk_host_settings ps ON ps.host_id = q.host_id
           WHERE q.host_id <> ${callerId}::uuid AND q.expires_at > ${iso(now)}::timestamptz
             AND q.format = ${format}::pk4_format AND q.type = ${type}::pk_type
             AND r.status = 'LIVE' AND r.mode = 'SOLO'::live_room_mode AND r.host_user_id = q.host_id
             AND r.last_heartbeat_at > ${iso(this.staleCutoff(now))}::timestamptz AND r.host_away_since IS NULL
           ORDER BY q.joined_at, q.host_id
           LIMIT 50) w`;
      const ids = rows.map((r) => r.host_id);
      const blocks = await tx.$queryRaw<{ a: string; b: string }[]>`
        SELECT blocker_id::text AS a, blocked_id::text AS b FROM user_blocks
         WHERE blocker_id = ANY(${ids}::uuid[]) AND blocked_id = ANY(${ids}::uuid[])`;
      const waiters: Waiter[] = rows.map((r) => ({
        hostId: r.host_id,
        roomId: r.room_id,
        gender: r.gender === 'MALE' || r.gender === 'FEMALE' ? r.gender : null,
        country: r.country,
        wantGender: r.g,
        wantRegion: r.c,
        blocks: new Set(blocks.filter((b) => b.a === r.host_id).map((b) => b.b)),
      }));
      const me = waiters.find((w) => w.hostId === callerId);
      if (!me) throw new AppException(ErrorCode.NOT_FOUND);
      // §10.62's preferences between every pair, both ways; no block either way.
      const wants = (a: Waiter, b: Waiter) =>
        (a.wantGender === 'BOTH' || b.gender === null || b.gender === a.wantGender) &&
        (a.wantRegion === 'GLOBAL' || a.country === null || b.country === a.country);
      const fits = (a: Waiter, b: Waiter) =>
        !a.blocks.has(b.hostId) && !b.blocks.has(a.hostId) && wants(a, b) && wants(b, a);
      const free: Waiter[] = [];
      for (const w of waiters.filter((x) => x.hostId !== callerId)) {
        if (!(await this.busyIgnoringQueue(tx, w.roomId, now))) free.push(w);
      }
      const group = pickPk4Group(me, free, fits);
      if (group) {
        await this.lockRooms(
          tx,
          group.map((g) => g.roomId),
        );
        let ok = !(await this.busyIn(tx, own.id, callerId, now));
        for (const g of group)
          if (ok && g.hostId !== callerId) ok = !(await this.busyIgnoringQueue(tx, g.roomId, now));
        if (ok) {
          const pick = this.randomSource ?? randomInt;
          const order = shuffled(group, (max) => pick(max));
          outcome.matched = await this.createMatchIn(tx, {
            format,
            type,
            source: 'RANDOM',
            lobbyId: null,
            organiserRoomId: order[0]!.roomId,
            settingsHostId: order[0]!.hostId,
            hosts: order.map((g, i) => ({ roomId: g.roomId, hostId: g.hostId, seat: i + 1 })),
            actorId: callerId,
            now,
          });
          outcome.group = group;
          await this.audit.recordIn(tx, {
            action: AuditAction.LIVE_PK4_QUEUE,
            actorUserId: callerId,
            targetType: 'pk4_match',
            targetId: outcome.matched,
            metadata: { event: 'matched', format, type, hosts: order.map((g) => g.hostId) },
          });
          return;
        }
      }
      await this.lockRooms(tx, [own.id]);
      if (await this.busyIn(tx, own.id, callerId, now)) throw new AppException(ErrorCode.PK_HOST_BUSY);
      const expiresAt = new Date(now.getTime() + this.config.pk.pk4.randomWaitSeconds * 1000);
      await tx.pk4QueueEntry.create({
        data: { hostId: callerId, roomId: own.id, format, type, joinedAt: now, expiresAt },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.LIVE_PK4_QUEUE,
        actorUserId: callerId,
        targetType: 'live_room',
        targetId: own.id,
        metadata: { event: 'joined', format, type, expiresAt: iso(expiresAt) },
      });
      outcome.waiting = { format, type, joinedAt: iso(now), expiresAt: iso(expiresAt) };
    }, LIVE_TX_OPTIONS);
    if (outcome.matched) {
      const match = (await this.broadcastMatch(outcome.matched, await this.startEvent(outcome.matched)))!;
      for (const g of outcome.group) {
        if (g.hostId === callerId) continue;
        await this.tellQueue(g.roomId, g.hostId, { type: 'pk4-queue', status: 'MATCHED', matchId: match.id });
      }
      return { status: 'MATCHED', queue: null, match };
    }
    return { status: 'WAITING', queue: outcome.waiting, match: null };
  }

  /** `DELETE /live/rooms/{roomId}/pk4/random`: stops waiting (idempotent). */
  async leaveRandom(callerId: string, roomId: string): Promise<void> {
    const room = await this.ownRoom(callerId, roomId);
    const gone = await this.prisma.pk4QueueEntry.deleteMany({ where: { hostId: callerId, roomId: room.id } });
    if (gone.count > 0) {
      await this.audit.record({
        action: AuditAction.LIVE_PK4_QUEUE,
        actorUserId: callerId,
        targetType: 'live_room',
        targetId: room.id,
        metadata: { event: 'left' },
      });
    }
  }

  // ---- Media -----------------------------------------------------------------------------------

  /**
   * `POST …/pk4/media-token`: watch-only, hidden tokens for the other rooms of the match (one to three; identity
   * `pk4:<matchId>:<base>`). A room the caller may not watch is left out; PK4_MAX_WATCHERS_PER_ROOM reached → left out
   * and `capped`.
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
   * The media webhook (or reconciliation) found a `pk4:` identity in a room: allowed while that match — or, after a
   * «جولة أخرى», the open match of its chain (v1.119-live) — is open and the room is one of its places (else the caller
   * disconnects it). Never a viewer of that room.
   */
  async allowsWatcher(roomId: string, identity: string): Promise<boolean> {
    const matchId = pk4MatchOfIdentity(identity);
    if (matchId === null) return false;
    const [row] = await this.prisma.$queryRaw<{ ok: boolean }[]>`
      WITH root AS (
        SELECT COALESCE((SELECT rematch_root_id FROM pk4_matches WHERE id = ${matchId}::uuid), ${matchId}::uuid) AS id)
      SELECT EXISTS (SELECT 1 FROM pk4_seats s JOIN pk4_matches m ON m.id = s.match_id
                      WHERE s.room_id = ${roomId}::uuid AND s.active AND m.status <> 'CLOSED'
                        AND (m.id = ${matchId}::uuid OR m.id = (SELECT id FROM root)
                             OR m.rematch_root_id = (SELECT id FROM root))) AS ok`;
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
   * rule of `pk-admin end` (`adminEndPk4In`: an open dare CANCELLED too); audited `live.pk.admin_end` in the same
   * transaction. The rooms are told at once (and by the tick's notice otherwise).
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
        metadata: {
          reason,
          previousStatus: status,
          format: match.format,
          type: match.type,
          players: match.player_count,
          via: 'panel',
        },
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
   * v1.119-live (D395, owner «أ»): OPEN lobbies whose time ran out with two or more hosts in start (the open invitations
   * CANCELLED); those that cannot start (the organiser's live not eligible, a block, one host left) expire as before.
   */
  private async autoStartLobbies(now: Date): Promise<number> {
    const due = await this.prisma.$queryRaw<{ id: string }[]>`
      SELECT l.id::text AS id FROM pk4_lobbies l
       WHERE l.status = 'OPEN' AND l.expires_at <= ${iso(now)}::timestamptz
         AND EXISTS (SELECT 1 FROM pk4_invites i WHERE i.lobby_id = l.id AND i.status = 'ACCEPTED')
       ORDER BY l.expires_at LIMIT 100`;
    let started = 0;
    for (const { id } of due) {
      try {
        const result = await this.inLobby(id, [], async (tx, l) => {
          if (l.status !== 'OPEN' || l.expires_at.getTime() > now.getTime()) {
            return { matchId: null, dropped: [] as string[], cancelled: [] as string[], refused: null };
          }
          return this.startLobbyIn(tx, l, now, null);
        });
        await this.afterLobbyStart(id, result);
        if (result.matchId) started += 1;
      } catch (err) {
        this.logger.warn({ error: safeErrorLog(err) }, 'PK4 lobby could not start at its end');
      }
    }
    return started;
  }

  /**
   * One 4-way PK tick (every PK_TICK_MS; by hand in tests): lobbies past their time start with two or more hosts in,
   * otherwise expire (the hosts told); open invitations past their time expire; a lobby whose organiser's live ended is
   * cancelled and an accepted place whose live ended is freed; 4-way random waits past their time (or whose live ended)
   * end (the host told); absent hosts are marked out (a team gone, one FREE_FOR_ALL host left, everyone gone), battles
   * whose time is up end, open dares run their timeouts, rematch offers lapse, result phases past their time close, and
   * moderator ends are told to the rooms. Every step is idempotent under the rows' state guards, so instances may run it
   * concurrently.
   */
  async tick(): Promise<{
    expiredInvites: number;
    expiredLobbies: number;
    started: number;
    ended: number;
    closed: number;
  }> {
    const now = this.clock.now();
    const at = iso(now);
    const started = await this.autoStartLobbies(now);
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
    // v1.119-live (D395): 4-way random waits past their time, or whose live ended (never messaged: no media room).
    const waits = await this.prisma.$queryRaw<{ host_id: string; room_id: string; live: boolean }[]>`
      WITH gone AS (
        DELETE FROM pk4_queue q
         WHERE q.expires_at <= ${at}::timestamptz
            OR NOT EXISTS (SELECT 1 FROM live_rooms r WHERE r.id = q.room_id AND r.status = 'LIVE')
        RETURNING q.host_id, q.room_id)
      SELECT g.host_id::text AS host_id, g.room_id::text AS room_id, COALESCE(r.status = 'LIVE', false) AS live
        FROM gone g LEFT JOIN live_rooms r ON r.id = g.room_id`;
    for (const w of waits) {
      if (w.live) await this.tellQueue(w.room_id, w.host_id, { type: 'pk4-queue', status: 'EXPIRED' });
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
        // v1.119-live (D395): a rematch offer not every present host accepted in time lapses; the PK closes as usual.
        if (m.rematch_by_room_id !== null && m.rematch_expires_at !== null) {
          if (m.rematch_expires_at.getTime() <= now.getTime()) {
            if (await this.endRematchOffer(m.id, 'rematch-expired', null, null)) closed += 1;
          }
          continue;
        }
        // An open dare runs first (its timeouts, the losers gone); the PK stays open meanwhile.
        if (m.type === 'DARES' && (await this.dareTick(m, now, grace))) continue;
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
    return { expiredInvites: expired.length, expiredLobbies: lobbies.length, started, ended, closed };
  }
}
