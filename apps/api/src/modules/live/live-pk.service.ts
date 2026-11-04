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
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import { UsersService } from '../users/users.service.js';
import { TrailingThrottle } from './live-metadata.service.js';
import {
  absenceOf,
  boosterProblem,
  boosterRule,
  isEffectivePk,
  matchSettings,
  roundOutcome,
  PK_TOPIC,
  pkIdentity,
  pkMatchOfIdentity,
  pkPoints,
  topSupportersIn,
  winnerByScore,
  type PkEndReasonName,
  type PkGenderPrefName,
  type PkMatchSettings,
  type PkModeName,
  type PkRegionPrefName,
  type PkSideName,
} from './live-pk.js';
import {
  LIVE_TX_OPTIONS,
  LiveRoomsService,
  type RequestMeta,
  type UserSummaryDto,
} from './live-rooms.service.js';
import { isUuid, liveMediaTokenSchema } from './live.schemas.js';
import { addPkDareDoneIn, addPkPointsIn, drawPkDareIn } from './pk-dares/pk-dare-match.js';
import { pkDareSettingsIn } from './pk-dares/pk-dare-library.js';
import type { PkDareCategory, PkDareLevel } from './pk-dares/pk-dare-rules.js';
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
  /** The running round's PK points (the only round of a single PK). */
  score: number;
  /** v1.44-live (D199): every round's PK points, this one included. */
  totalScore: number;
  /** v1.44-live (D199): rounds this side won (best of three). */
  roundsWon: number;
  boost: PkActiveBoostDto | null;
  boosterUses: Record<PkBoosterKindName, number>;
  supporters: PkSupporterDto[];
  guests: PkGuestDto[];
  /** This side's host turned the opponent's sound off in their room. */
  mutesOpponent: boolean;
  /**
   * v1.67-live (D276) «نقاط PK»: this side's host's PK points (`PkHostRecord.points` — win / draw / loss, refused
   * dares; may be below 0), shown on their half for both rooms. A finished match's own points are in once it ends.
   */
  pkPoints: number;
}

/** v1.50-live (D229) `PkType`: the normal PK, or «PK أحكام». */
export type PkTypeName = 'NORMAL' | 'DARES';

/** v1.50-live (D229) `PkDareOption`: one of the three cards (EASY, MEDIUM, HARD in that order). */
export interface PkDareOptionDto {
  id: string;
  level: PkDareLevel;
  category: PkDareCategory;
  textAr: string;
  textEn: string;
}

/**
 * v1.50-live (D229) `PkDare`: the dare of a DARES match. DRAWING (the cards shuffle until `revealAt`) → DECIDING (the
 * loser accepts or refuses until `decideBy`) → ACTIVE (the timer until `endsAt`; the winner judges) → DONE / REFUSED;
 * CANCELLED (a moderator's end).
 */
export interface PkDareDto {
  status: 'DRAWING' | 'DECIDING' | 'ACTIVE' | 'DONE' | 'REFUSED' | 'CANCELLED';
  cause:
    | 'LOSER_REFUSED'
    | 'DECIDE_TIMEOUT'
    | 'LOSER_LEFT'
    | 'WINNER_DONE'
    | 'WINNER_NOT_DONE'
    | 'TIMER'
    | 'WINNER_LEFT'
    | 'ADMIN'
    | null;
  loserRoomId: string;
  winnerRoomId: string;
  options: PkDareOptionDto[];
  /** The drawn card (0–2); the animation lands on it at `revealAt`. */
  drawn: number;
  revealAt: string;
  decideBy: string;
  startedAt: string | null;
  endsAt: string | null;
  finishedAt: string | null;
  /** The loser's PK points from the dare (the refusal's value, else 0). */
  points: number;
  /** What a refusal (or «لم يُنفّذ») counts now (the panel's `refusePoints`, −3): the confirm shows it. */
  refusePoints: number;
}

/** `PkMatch`. */
export interface PkMatchDto {
  id: string;
  source: 'INVITE' | 'RANDOM';
  status: 'CONNECTED' | 'BATTLE' | 'RESULT' | 'CLOSED';
  /** CONNECTED: when the hosts were connected; then when the battle (round 1) started. */
  startedAt: string;
  /** BATTLE: the running round's end. CONNECTED: the time by which a host must start (else cancelled). */
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
  /** v1.44-live (D199): the settings used (`settingsFromRoomId`: whose, when the hosts' differed). */
  mode: PkModeName;
  roundSeconds: number;
  /** The running (or last) round: 1–3. */
  round: number;
  /** 1 (single) or 3 (best of three). */
  rounds: number;
  connectedAt: string | null;
  settingsFromRoomId: string | null;
  /** Whether the finished match counts in the records; null until it ends. */
  effective: boolean | null;
  /** v1.50-live (D229): the PK type. */
  type: PkTypeName;
  /** v1.50-live (D229): the dare of a DARES match with a winner; null otherwise (and until the battle ends). */
  dare: PkDareDto | null;
  /** v1.55-live (D242) «جولة أخرى»: the open offer of a RESULT match (who asked, until when); null otherwise. */
  rematch: { byRoomId: string; expiresAt: string } | null;
  /** v1.55-live (D242): the battle this one is a rematch of, and how many rematches came before it. */
  rematchOf: string | null;
  rematchCount: number;
  /** v1.55-live (D242): rematches this pair may still play in a row (PK_REMATCH_MAX); null = unlimited. */
  rematchesLeft: number | null;
  /**
   * v1.67-live (D276, owner: «انسحاب = −3»): what withdrawing from the battle counts now (the panel's
   * `forfeitPoints`, −3): the app's «إنهاء التحدي» confirm shows it.
   */
  forfeitPoints: number;
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
  /** v1.50-live (D229): the PK type offered. */
  type: PkTypeName;
}

/** `PkState`: what a room's screen needs (the host also gets its invitation, queue and switch). */
export interface PkStateDto {
  match: PkMatchDto | null;
  invite: PkInviteDto | null;
  queue: { joinedAt: string; expiresAt: string; type: PkTypeName } | null;
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
  queue: { joinedAt: string; expiresAt: string; type: PkTypeName } | null;
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
  /** v1.50-live (D229): PK points (win / draw / loss / refused dare; may be below 0). */
  points: number;
  daresDone: number;
  daresRefused: number;
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
  /** v1.44-live (D199): counted in the record (an «effective PK»). */
  effective: boolean;
  mode: PkModeName;
  roundsWon: number;
  opponentRoundsWon: number;
  /** v1.50-live (D229). */
  type: PkTypeName;
  /** v1.50-live (D229): the dare of that match (the drawn one), null when there was none. */
  dare: {
    status: PkDareDto['status'];
    level: PkDareLevel;
    textAr: string;
    textEn: string;
    mine: boolean;
  } | null;
}

/** v1.44-live (D199) `PkSettings`: the caller's PK Setting page (1 v 1) and record. */
export interface PkSettingsDto {
  invitesEnabled: boolean;
  mode: PkModeName;
  /** The chosen round time (3, 5 or 10), or null: the server's default (`roundSeconds`). */
  roundMinutes: number | null;
  roundSeconds: number;
  autoStart: boolean;
  randomGender: PkGenderPrefName;
  randomRegion: PkRegionPrefName;
  autoMatch: boolean;
  recommendable: boolean;
  /** The «effective PK» threshold: both sides' PK points together (PK_EFFECTIVE_MIN_POINTS). */
  effectiveMinPoints: number;
  record: PkHostRecordDto;
}

/** `PkHostProfile`. */
export interface PkHostProfileDto {
  record: PkHostRecordDto;
  recent: PkHistoryItemDto[];
}

/** The data message of topic `pk` (both rooms). */
export interface PkMatchData {
  readonly type: 'pk-match';
  readonly event:
    | 'connected'
    | 'started'
    | 'round'
    | 'score'
    | 'boost'
    | 'ended'
    | 'closed'
    | 'mute'
    /** v1.50-live (D229): the dare changed (drawn, accepted, refused, judged, over). */
    | 'dare'
    /** v1.55-live (D242) «جولة أخرى»: offered, withdrawn, declined, lapsed; `rematch` = the new battle started. */
    | 'rematch-offer'
    | 'rematch-cancelled'
    | 'rematch-declined'
    | 'rematch-expired'
    | 'rematch';
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

const pkTypeSchema = z.enum(['NORMAL', 'DARES']);
const inviteSchema = z.strictObject({ toRoomId: z.uuid(), type: pkTypeSchema.optional() });
/** v1.50-live (D229): `joinLivePkRandom`'s optional body. */
const randomSchema = z.strictObject({ type: pkTypeSchema.optional() });
const verdictSchema = z.strictObject({ done: z.boolean() });
const reportSchema = z.strictObject({ dareId: z.uuid() });
const muteSchema = z.strictObject({ muted: z.boolean() });
const settingsSchema = z
  .strictObject({
    invitesEnabled: z.boolean().optional(),
    mode: z.enum(['SINGLE', 'BEST_OF_THREE']).optional(),
    roundMinutes: z.union([z.literal(3), z.literal(5), z.literal(10)]).optional(),
    autoStart: z.boolean().optional(),
    randomGender: z.enum(['BOTH', 'MALE', 'FEMALE']).optional(),
    randomRegion: z.enum(['GLOBAL', 'SAME_COUNTRY']).optional(),
    autoMatch: z.boolean().optional(),
    recommendable: z.boolean().optional(),
  })
  .refine((v) => Object.keys(v).length > 0, { message: 'at least one setting' });
const candidatesQuerySchema = z.object({
  q: z.string().trim().max(30).optional(),
  /** v1.44-live (D199): only mutual follows («Friends»). */
  friends: z.enum(['true', 'false']).optional(),
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
  status: 'CONNECTED' | 'BATTLE' | 'RESULT' | 'CLOSED';
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
  mode: PkModeName;
  round_seconds: number;
  round: number;
  rounds_a: number;
  rounds_b: number;
  total_a: bigint;
  total_b: bigint;
  settings_from: PkSideName | null;
  connected_at: Date | null;
  effective: boolean | null;
  type: PkTypeName;
  /** v1.55-live (D242). */
  rematch_of: string | null;
  rematch_root_id: string | null;
  rematch_count: number;
  rematch_by: PkSideName | null;
  rematch_expires_at: Date | null;
}

/** v1.50-live (D229): a match's dare row. */
interface DareRow {
  match_id: string;
  loser_side: PkSideName;
  loser_host_id: string;
  winner_host_id: string;
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

const DARE_COLUMNS = `match_id::text AS match_id, loser_side::text AS loser_side, loser_host_id::text AS loser_host_id,
  winner_host_id::text AS winner_host_id, option_ids::text[] AS option_ids, drawn, dare_id::text AS dare_id,
  status::text AS status, cause::text AS cause, reveal_at, decide_by, started_at, ends_at, finished_at, points`;

const MATCH_COLUMNS = `id::text AS id, source::text AS source, status::text AS status,
  room_a_id::text AS room_a_id, host_a_id::text AS host_a_id, room_b_id::text AS room_b_id,
  host_b_id::text AS host_b_id, score_a, score_b, started_at, battle_ends_at, ended_at, result_ends_at,
  end_reason::text AS end_reason, winner::text AS winner, loser_cause::text AS loser_cause,
  a_mutes_b, b_mutes_a, seq, top_a, top_b, mode::text AS mode, round_seconds, round, rounds_a, rounds_b,
  total_a, total_b, settings_from::text AS settings_from, connected_at, effective, type::text AS type,
  rematch_of::text AS rematch_of, rematch_root_id::text AS rematch_root_id, rematch_count,
  rematch_by::text AS rematch_by, rematch_expires_at`;

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

/** `PkHostRecord` (no row: zeros). */
function recordDto(
  r: {
    wins: number;
    losses: number;
    draws: number;
    points: number;
    daresDone: number;
    daresRefused: number;
  } | null,
): PkHostRecordDto {
  return {
    wins: r?.wins ?? 0,
    losses: r?.losses ?? 0,
    draws: r?.draws ?? 0,
    points: r?.points ?? 0,
    daresDone: r?.daresDone ?? 0,
    daresRefused: r?.daresRefused ?? 0,
  };
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
  /** Tests only: the drawn card of the next draws (else crypto random). */
  darePick: (() => number) | null = null;

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
   * expired one is closed here first) or the host in the random queue — not with `ignoreQueue`
   * (v1.48-live, D215: an invited host may be waiting there). Under the rooms' PK locks.
   */
  private async busyIn(
    tx: Prisma.TransactionClient,
    roomId: string,
    hostId: string,
    now: Date,
    opts: { ignoreQueue?: boolean } = {},
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
          OR (NOT ${opts.ignoreQueue === true}
              AND EXISTS (SELECT 1 FROM pk_queue WHERE host_id = ${hostId}::uuid AND expires_at > ${iso(now)}::timestamptz))
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
         WHERE match_id = ${row.id}::uuid AND round = ${row.round} GROUP BY side, kind`,
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
    // v1.67-live (D276): both hosts' PK points («نقاط PK») on their halves.
    const records = await this.prisma.pkHostRecord.findMany({
      where: { hostId: { in: [row.host_a_id, row.host_b_id] } },
      select: { hostId: true, points: true },
    });
    const pkPointsOf = (hostId: string) => records.find((r) => r.hostId === hostId)?.points ?? 0;
    const { forfeitPoints } = await pkDareSettingsIn(this.prisma);
    const dare = row.type === 'DARES' ? await this.dareDto(row) : null;
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
        totalScore: Number(this.totalOf(row, s)),
        roundsWon: s === 'A' ? row.rounds_a : row.rounds_b,
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
        pkPoints: pkPointsOf(s === 'A' ? row.host_a_id : row.host_b_id),
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
      mode: row.mode,
      roundSeconds: row.round_seconds,
      round: row.round,
      rounds: row.mode === 'BEST_OF_THREE' ? 3 : 1,
      connectedAt: row.connected_at ? iso(row.connected_at) : null,
      settingsFromRoomId: roomOf(row.settings_from),
      effective: row.effective,
      type: row.type,
      dare,
      rematch:
        row.status === 'RESULT' && row.rematch_by !== null && row.rematch_expires_at !== null
          ? { byRoomId: roomOf(row.rematch_by)!, expiresAt: iso(row.rematch_expires_at) }
          : null,
      rematchOf: row.rematch_of,
      rematchCount: row.rematch_count,
      rematchesLeft:
        this.config.pk.rematchMax === 0 ? null : Math.max(0, this.config.pk.rematchMax - row.rematch_count),
      forfeitPoints,
    };
  }

  /** v1.50-live (D229): a match's dare row (locked with `lock`), or null. */
  private async dareRow(
    db: Prisma.TransactionClient | PrismaService,
    matchId: string,
    lock = false,
  ): Promise<DareRow | null> {
    const [row] = await db.$queryRaw<DareRow[]>(
      Prisma.sql`SELECT ${Prisma.raw(DARE_COLUMNS)} FROM pk_match_dares WHERE match_id = ${matchId}::uuid ${lock ? Prisma.raw('FOR UPDATE') : Prisma.empty}`,
    );
    return row ?? null;
  }

  /** v1.50-live (D229) `PkDare` of a DARES match (null before the battle ends, or with no winner). */
  private async dareDto(match: MatchRow): Promise<PkDareDto | null> {
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
    const status: PkDareDto['status'] =
      d.status === 'DECIDING' && now.getTime() < d.reveal_at.getTime() ? 'DRAWING' : d.status;
    const roomOf = (side: PkSideName) => (side === 'A' ? match.room_a_id : match.room_b_id);
    return {
      status,
      cause: d.cause,
      loserRoomId: roomOf(d.loser_side),
      winnerRoomId: roomOf(otherSide(d.loser_side)),
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

  /**
   * A side's PK points of every round. While a round runs (and for a match that ended before D199)
   * the running round's score is not yet in `total_*`; once the match ends it is (see finishBattle).
   */
  private totalOf(row: MatchRow, s: PkSideName): bigint {
    const total = s === 'A' ? row.total_a : row.total_b;
    const score = s === 'A' ? row.score_a : row.score_b;
    const folded = row.status === 'RESULT' || row.status === 'CLOSED';
    return folded && total > 0n ? total : total + score;
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
      type: invite.type,
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
      queue: queue
        ? { joinedAt: iso(queue.joinedAt), expiresAt: iso(queue.expiresAt), type: queue.type }
        : null,
      invitesEnabled: settings?.invitesEnabled ?? true,
    };
  }

  /**
   * `GET /live/rooms/{roomId}/pk/candidates`: hosts live now whom the caller (this room's host) may
   * invite — SOLO video lives with a fresh heartbeat, present, invitations on, not in a PK or an open
   * invitation, no block either way. `q` matches the start of the username or any part of the
   * display name; without it, the busiest lives first (suggestions). v1.48-live (D215): a host
   * waiting in the random queue (or kept there by Auto Match) is idle and is listed — before, a
   * friend who had tapped «مطابقة عشوائية» vanished from «الأصدقاء» and only the random match
   * found them.
   */
  async candidates(callerId: string, roomId: string, query: unknown): Promise<{ data: PkCandidateDto[] }> {
    this.assertPkOn();
    await this.ownRoom(callerId, roomId);
    const parsed = candidatesQuerySchema.safeParse(query ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const q = parsed.data.q?.toLowerCase().replace(/[\\%_]/g, (c) => `\\${c}`) ?? '';
    const limit = parsed.data.limit ?? 20;
    const friends = parsed.data.friends === 'true';
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
    const type: PkTypeName = parsed.data.type ?? 'NORMAL';
    if (type === 'DARES' && !this.config.pk.daresEnabled) throw new AppException(ErrorCode.PK_UNAVAILABLE);
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
      // v1.48-live (D215): the invited host may be waiting in the random queue (the invitation
      // keeps them out of random matches while it is open; accepted, both waits end).
      if (
        (await this.busyIn(tx, own.id, callerId, now)) ||
        (await this.busyIn(tx, targetRow.id, targetRow.host_user_id, now, { ignoreQueue: true }))
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
          type,
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
    type: PkTypeName;
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
        type: PkTypeName;
      }[]
    >`
      SELECT id::text AS id, status::text AS status, expires_at, from_room_id::text AS from_room_id,
             from_host_id::text AS from_host_id, to_room_id::text AS to_room_id, to_host_id::text AS to_host_id,
             type::text AS type
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
        type: invite.type,
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
  async joinRandom(callerId: string, roomId: string, body?: unknown): Promise<PkRandomResultDto> {
    this.assertPkOn();
    const parsedBody = randomSchema.safeParse(body ?? {});
    if (!parsedBody.success) throw AppException.validation(zodErrorToDetails(parsedBody.error));
    // v1.50-live (D229): a «PK أحكام» waiter is only paired with another «PK أحكام» waiter.
    const type: PkTypeName = parsedBody.data.type ?? 'NORMAL';
    if (type === 'DARES' && !this.config.pk.daresEnabled) throw new AppException(ErrorCode.PK_UNAVAILABLE);
    const now = this.clock.now();
    const own = await this.ownEligibleRoom(callerId, roomId, now);
    let matched: string | null = null;
    let waiting: { joinedAt: Date; expiresAt: Date; type: PkTypeName } | null = null;
    await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended('pk-queue', 0))`;
      await this.lockRooms(tx, [own.id]);
      const existing = await tx.pkQueueEntry.findUnique({ where: { hostId: callerId } });
      if (
        existing &&
        existing.roomId === own.id &&
        existing.type === type &&
        existing.expiresAt.getTime() > now.getTime()
      ) {
        waiting = { joinedAt: existing.joinedAt, expiresAt: existing.expiresAt, type };
        return;
      }
      if (existing) await tx.pkQueueEntry.delete({ where: { hostId: callerId } });
      if (await this.busyIn(tx, own.id, callerId, now)) throw new AppException(ErrorCode.PK_HOST_BUSY);
      // v1.44-live (D199): both hosts' gender and region preferences must hold (each way).
      const [me] = await tx.$queryRaw<
        { gender: string | null; country: string | null; g: PkGenderPrefName; c: PkRegionPrefName }[]
      >`
        SELECT p.gender::text AS gender, p.country_code AS country,
               COALESCE(s.random_gender::text, 'BOTH') AS g, COALESCE(s.random_region::text, 'GLOBAL') AS c
          FROM user_profiles p LEFT JOIN pk_host_settings s ON s.host_id = p.user_id
         WHERE p.user_id = ${callerId}::uuid`;
      const myGender = me?.gender === 'MALE' || me?.gender === 'FEMALE' ? me.gender : null;
      const myCountry = me?.country ?? null;
      const wantGender = me?.g ?? 'BOTH';
      const wantCountry = me?.c === 'SAME_COUNTRY' ? myCountry : null;
      const partners = await tx.$queryRaw<{ host_id: string; room_id: string }[]>`
        SELECT q.host_id::text AS host_id, q.room_id::text AS room_id
          FROM pk_queue q
          JOIN live_rooms r ON r.id = q.room_id
          JOIN user_profiles pp ON pp.user_id = q.host_id
          LEFT JOIN pk_host_settings ps ON ps.host_id = q.host_id
         WHERE q.host_id <> ${callerId}::uuid AND q.expires_at > ${iso(now)}::timestamptz
           AND q.type = ${type}::pk_type
           AND r.status = 'LIVE' AND r.mode = 'SOLO'::live_room_mode AND r.host_user_id = q.host_id
           AND r.last_heartbeat_at > ${iso(this.staleCutoff(now))}::timestamptz AND r.host_away_since IS NULL
           AND NOT EXISTS (SELECT 1 FROM user_blocks b
                            WHERE (b.blocker_id = ${callerId}::uuid AND b.blocked_id = q.host_id)
                               OR (b.blocker_id = q.host_id AND b.blocked_id = ${callerId}::uuid))
           AND (${wantGender} = 'BOTH' OR pp.gender IS NULL OR pp.gender::text NOT IN ('MALE', 'FEMALE')
                OR pp.gender::text = ${wantGender})
           AND (COALESCE(ps.random_gender::text, 'BOTH') = 'BOTH' OR ${myGender}::text IS NULL
                OR ps.random_gender::text = ${myGender}::text)
           AND (${wantCountry}::text IS NULL OR pp.country_code = ${wantCountry}::text)
           AND (COALESCE(ps.random_region::text, 'GLOBAL') = 'GLOBAL' OR pp.country_code IS NULL
                OR pp.country_code = ${myCountry}::text)
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
          type,
        });
        if (matched) return;
      }
      const expiresAt = new Date(now.getTime() + this.config.pk.randomWaitSeconds * 1000);
      await tx.pkQueueEntry.create({
        data: { hostId: callerId, roomId: own.id, joinedAt: now, expiresAt, type },
      });
      waiting = { joinedAt: now, expiresAt, type };
    }, LIVE_TX_OPTIONS);
    if (matched) return { status: 'MATCHED', queue: null, match: await this.started(matched) };
    const w = waiting as { joinedAt: Date; expiresAt: Date; type: PkTypeName } | null;
    return {
      status: 'WAITING',
      queue: w ? { joinedAt: iso(w.joinedAt), expiresAt: iso(w.expiresAt), type: w.type } : null,
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
      /** v1.50-live (D229). */
      type: PkTypeName;
    },
  ): Promise<string | null> {
    const [busy] = await tx.$queryRaw<{ busy: boolean }[]>`
      SELECT EXISTS (SELECT 1 FROM pk_matches WHERE status <> 'CLOSED'
                      AND (room_a_id IN (${input.roomA}::uuid, ${input.roomB}::uuid)
                        OR room_b_id IN (${input.roomA}::uuid, ${input.roomB}::uuid))) AS busy`;
    if (busy?.busy) return null;
    const id = uuidv7();
    const [a, b] = await Promise.all([
      this.matchSettingsOf(tx, input.hostA),
      this.matchSettingsOf(tx, input.hostB),
    ]);
    const { settings, from } = matchSettings(a, b, () => randomInt(2) === 0);
    const connected = !settings.autoStart;
    await tx.pkMatch.create({
      data: {
        id,
        source: input.source,
        status: connected ? 'CONNECTED' : 'BATTLE',
        roomAId: input.roomA,
        hostAId: input.hostA,
        roomBId: input.roomB,
        hostBId: input.hostB,
        startedAt: input.now,
        // CONNECTED: the start deadline (PK_CONNECT_SECONDS); BATTLE: round 1's end.
        battleEndsAt: new Date(
          input.now.getTime() + (connected ? this.config.pk.connectSeconds : settings.roundSeconds) * 1000,
        ),
        connectedAt: connected ? input.now : null,
        mode: settings.mode,
        roundSeconds: settings.roundSeconds,
        settingsFrom: from,
        seq: 1,
        type: input.type,
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
      metadata: {
        source: input.source,
        roomA: input.roomA,
        roomB: input.roomB,
        hostA: input.hostA,
        mode: settings.mode,
        roundSeconds: settings.roundSeconds,
        autoStart: settings.autoStart,
        settingsFrom: from,
        type: input.type,
      },
    });
    return id;
  }

  /** v1.44-live (D199): a host's settings that shape a match (no row: the defaults). */
  private async matchSettingsOf(tx: Prisma.TransactionClient, hostId: string): Promise<PkMatchSettings> {
    const s = await tx.pkHostSettings.findUnique({ where: { hostId } });
    return {
      mode: s?.mode ?? 'SINGLE',
      roundSeconds:
        s?.roundMinutes !== null && s?.roundMinutes !== undefined
          ? s.roundMinutes * 60
          : this.config.pk.battleSeconds,
      autoStart: s?.autoStart ?? true,
    };
  }

  /** The new match told to both rooms: `started`, or `connected` while it waits for a start. */
  private async started(matchId: string): Promise<PkMatchDto> {
    const row = await this.selectMatch(this.prisma, Prisma.sql`id = ${matchId}::uuid`);
    const dto = await this.broadcastMatch(matchId, row?.status === 'CONNECTED' ? 'connected' : 'started');
    return dto!;
  }

  /**
   * v1.44-live (D199) `POST /live/rooms/{roomId}/pk/start`: either host of a CONNECTED match starts the
   * battle (round 1, `roundSeconds`); both rooms get `started`. Already running: the match as it is
   * (idempotent). No open match, or one in its result → 409 PK_NOT_ACTIVE.
   */
  async start(callerId: string, roomId: string): Promise<PkMatchDto> {
    this.assertPkOn();
    const room = await this.ownRoom(callerId, roomId);
    const now = this.clock.now();
    const match = await this.openMatchOfRoom(this.prisma, room.id);
    if (!match || match.status === 'RESULT') throw new AppException(ErrorCode.PK_NOT_ACTIVE);
    if (match.status === 'BATTLE') return this.matchDto(match);
    const changed = await this.prisma.$executeRaw`
      UPDATE pk_matches
         SET status = 'BATTLE', started_at = ${iso(now)}::timestamptz,
             battle_ends_at = ${iso(now)}::timestamptz + make_interval(secs => round_seconds), seq = seq + 1
       WHERE id = ${match.id}::uuid AND status = 'CONNECTED'`;
    if (changed > 0) return (await this.broadcastMatch(match.id, 'started'))!;
    return this.matchDto((await this.selectMatch(this.prisma, Prisma.sql`id = ${match.id}::uuid`))!);
  }

  /**
   * v1.44-live (D199): a CONNECTED match that never started is closed at once — void (CANCELLED), no
   * winner, never counted. A host's End, a host gone or the start deadline passed.
   */
  private async cancelConnected(matchId: string, loser: PkSideName | null): Promise<boolean> {
    const now = iso(this.clock.now());
    const changed = await this.prisma.$executeRaw`
      UPDATE pk_matches
         SET status = 'CLOSED', ended_at = ${now}::timestamptz, result_ends_at = ${now}::timestamptz,
             closed_at = ${now}::timestamptz, end_reason = 'CANCELLED', loser_cause = ${loser}::pk_side,
             effective = false, seq = seq + 1, top_a = '[]'::jsonb, top_b = '[]'::jsonb
       WHERE id = ${matchId}::uuid AND status = 'CONNECTED'`;
    if (changed === 0) return false;
    await this.afterClose(matchId);
    return true;
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
    if (match.status === 'CONNECTED') {
      await this.cancelConnected(match.id, side);
    } else if (match.status === 'BATTLE') {
      await this.finishBattle(match.id, { reason: 'FORFEIT', loser: side }, callerId);
    } else {
      // v1.50-live (D229): ending the PK during an open dare settles it as that host leaving — the loser: refused
      // (LOSER_LEFT, the refusal's points); the winner: an accepted dare counts as done (no verdict), one not yet
      // answered is cancelled (no points).
      if (match.type === 'DARES') await this.settleDareOnLeave(match.id, room.id, callerId);
      await this.closeResult(match.id, true);
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
    const done = await this.prisma.$transaction(async (tx): Promise<'ended' | 'round' | false> => {
      const m = await this.selectMatch(tx, Prisma.sql`id = ${matchId}::uuid`, true);
      if (!m || m.status !== 'BATTLE') return false;
      const endedAt = finish.reason === 'TIME' ? m.battle_ends_at : now;
      // v1.44-live (D199): every round's points, this one included.
      const totalA = m.total_a + m.score_a;
      const totalB = m.total_b + m.score_b;
      let roundsA = m.rounds_a;
      let roundsB = m.rounds_b;
      let winner: PkSideName | null;
      if (finish.reason === 'TIME' && m.mode === 'BEST_OF_THREE') {
        const out = roundOutcome({
          round: m.round,
          roundsA,
          roundsB,
          scoreA: m.score_a,
          scoreB: m.score_b,
          totalA,
          totalB,
        });
        roundsA = out.roundsA;
        roundsB = out.roundsB;
        if (out.kind === 'next') {
          // The next round: its own scores, boosters and multipliers (the running booster ends here).
          await tx.$executeRaw`
            UPDATE pk_boosts SET ends_at = ${iso(now)}::timestamptz
             WHERE match_id = ${matchId}::uuid AND ends_at > ${iso(now)}::timestamptz`;
          await tx.$executeRaw`
            UPDATE pk_matches
               SET round = round + 1, rounds_a = ${roundsA}, rounds_b = ${roundsB}, total_a = ${totalA},
                   total_b = ${totalB}, score_a = 0, score_b = 0,
                   battle_ends_at = ${iso(now)}::timestamptz + make_interval(secs => round_seconds), seq = seq + 1
             WHERE id = ${matchId}::uuid`;
          await this.audit.recordIn(tx, {
            action: AuditAction.LIVE_PK_END,
            actorUserId: null,
            targetType: 'pk_match',
            targetId: matchId,
            metadata: {
              round: m.round,
              roundsA,
              roundsB,
              scoreA: Number(m.score_a),
              scoreB: Number(m.score_b),
            },
          });
          return 'round';
        }
        winner = out.winner;
      } else {
        winner =
          finish.reason === 'TIME'
            ? winnerByScore(m.score_a, m.score_b)
            : finish.loser === 'both' || finish.loser === null
              ? null
              : otherSide(finish.loser);
        if (m.mode === 'SINGLE' && finish.reason === 'TIME') {
          roundsA = winner === 'A' ? 1 : 0;
          roundsB = winner === 'B' ? 1 : 0;
        }
      }
      const loserCause = finish.loser === 'A' || finish.loser === 'B' ? finish.loser : null;
      const resultEndsAt = new Date(endedAt.getTime() + this.config.pk.resultSeconds * 1000);
      const effective = isEffectivePk(finish.reason, totalA, totalB, this.config.pk.effectiveMinPoints);
      const top = await topSupportersIn(tx, matchId);
      await tx.$executeRaw`
        UPDATE pk_matches
           SET status = 'RESULT', ended_at = ${iso(endedAt)}::timestamptz,
               result_ends_at = ${iso(resultEndsAt)}::timestamptz, end_reason = ${finish.reason}::pk_end_reason,
               winner = ${winner}::pk_side, loser_cause = ${loserCause}::pk_side, seq = seq + 1,
               rounds_a = ${roundsA}, rounds_b = ${roundsB}, total_a = ${totalA}, total_b = ${totalB},
               effective = ${effective},
               top_a = ${JSON.stringify(top.A)}::jsonb, top_b = ${JSON.stringify(top.B)}::jsonb
         WHERE id = ${matchId}::uuid`;
      // v1.44-live (D199): only an «effective PK» counts in the records. v1.67-live (D276, owner: «انسحاب = −3»):
      // a host who withdrew (FORFEIT, DISCONNECT, AWAY: `finish.loser`) gets `forfeitPoints` instead of the loss's
      // points, still a loss in the record; both withdrew → both. The other host wins as before.
      const hostOf = (side: PkSideName) => (side === 'A' ? m.host_a_id : m.host_b_id);
      const results: [string, 'wins' | 'losses' | 'draws', boolean][] = !effective
        ? []
        : finish.loser === 'both'
          ? [
              [m.host_a_id, 'losses', true],
              [m.host_b_id, 'losses', true],
            ]
          : winner === null
            ? [
                [m.host_a_id, 'draws', false],
                [m.host_b_id, 'draws', false],
              ]
            : [
                [hostOf(winner), 'wins', false],
                [hostOf(otherSide(winner)), 'losses', finish.loser === otherSide(winner)],
              ];
      // v1.50-live (D229): the record and the PK points (win / draw / loss, `pk_dare_settings`) in one step,
      // idempotent by (match, host, kind).
      const pointValues = await pkDareSettingsIn(tx);
      for (const [hostId, column, withdrew] of results) {
        const kind = column === 'wins' ? 'WIN' : column === 'losses' ? 'LOSS' : 'DRAW';
        await addPkPointsIn(tx, {
          matchId,
          hostId,
          kind,
          points:
            kind === 'WIN'
              ? pointValues.winPoints
              : kind === 'LOSS'
                ? withdrew
                  ? pointValues.forfeitPoints
                  : pointValues.lossPoints
                : pointValues.drawPoints,
          counter: column,
          now,
        });
      }
      // v1.50-live (D229) «PK أحكام»: a result with a winner (never a draw or a void match) → the server's draw.
      if (m.type === 'DARES' && winner !== null) {
        const loserSide = otherSide(winner);
        const drawnDare = await drawPkDareIn(tx, {
          matchId,
          loserSide,
          loserHostId: loserSide === 'A' ? m.host_a_id : m.host_b_id,
          winnerHostId: winner === 'A' ? m.host_a_id : m.host_b_id,
          now,
          drawSeconds: this.config.pk.dareDrawSeconds,
          decideSeconds: pointValues.decideSeconds,
          ...(this.darePick ? { pick: this.darePick } : {}),
        });
        if (drawnDare) {
          await tx.$executeRaw`
            UPDATE pk_matches SET result_ends_at = GREATEST(result_ends_at, ${iso(drawnDare.decideBy)}::timestamptz)
             WHERE id = ${matchId}::uuid`;
        } else {
          this.logger.warn({ matchId }, 'PK dares: no active dare at some level, no dare drawn');
        }
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
          totalA: Number(totalA),
          totalB: Number(totalB),
          roundsA,
          roundsB,
          effective,
        },
      });
      return 'ended';
    }, LIVE_TX_OPTIONS);
    if (done) await this.broadcastMatch(matchId, done);
    return done !== false;
  }

  /**
   * RESULT → CLOSED (nothing when it is no longer RESULT); both rooms told, cross-watchers removed. v1.50-live (D229):
   * not while its dare is open, unless `force` (a host's End).
   */
  private async closeResult(matchId: string, force = false): Promise<boolean> {
    const now = this.clock.now();
    const closed = await this.prisma.$executeRaw`
      UPDATE pk_matches SET status = 'CLOSED', closed_at = ${iso(now)}::timestamptz, seq = seq + 1
       WHERE id = ${matchId}::uuid AND status = 'RESULT'
         AND (${force} OR NOT EXISTS (SELECT 1 FROM pk_match_dares d
                                       WHERE d.match_id = ${matchId}::uuid AND d.finished_at IS NULL))`;
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
      /** v1.50-live (D229): a lucky gift — worth 0 PK points in a «PK أحكام» match (normal PK unchanged). */
      lucky?: boolean;
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
    // v1.50-live (D229, owner): in «PK أحكام» lucky gifts (their wins and multipliers too) give no PK points; they
    // still count as gifts for money, cherries, levels and boards (all written before this, with the real value).
    if (m.type === 'DARES' && input.lucky === true && input.booster === null) return null;
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
         WHERE match_id = ${m.id}::uuid AND side = ${side}::pk_side AND kind = ${input.booster}::pk_booster_kind
           AND round = ${m.round}`;
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
        INSERT INTO pk_boosts (id, match_id, side, kind, multiplier, gift_id, gift_code, sender_id, starts_at, ends_at, round)
        VALUES (${uuidv7()}::uuid, ${m.id}::uuid, ${side}::pk_side, ${input.booster}::pk_booster_kind, ${rule.multiplier},
                ${input.giftId}::uuid, ${input.giftCode}, ${input.senderId}::uuid, ${at}::timestamptz,
                ${iso(endsAt)}::timestamptz, ${m.round})`;
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

  // ---- «PK أحكام» (v1.50-live, D229, CONVENTIONS §10.80) -----------------------------------------------------

  /** The caller's room's open RESULT match of type DARES with its dare (404 / 409 PK_NOT_ACTIVE otherwise). */
  private async ownDare(
    callerId: string,
    roomId: string,
  ): Promise<{ room: RoomState; match: MatchRow; dare: DareRow; isLoser: boolean }> {
    const room = await this.ownRoom(callerId, roomId);
    const match = await this.openMatchOfRoom(this.prisma, room.id);
    if (!match || match.type !== 'DARES') throw new AppException(ErrorCode.PK_NOT_ACTIVE);
    const dare = await this.dareRow(this.prisma, match.id);
    if (!dare) throw new AppException(ErrorCode.PK_NOT_ACTIVE);
    const loserRoom = dare.loser_side === 'A' ? match.room_a_id : match.room_b_id;
    return { room, match, dare, isLoser: loserRoom === room.id };
  }

  /**
   * Ends an open dare (under its row lock; nothing when it is no longer in one of `from`): DONE — the loser's «dares
   * done» + 1; REFUSED — the refusal's PK points (`refusePoints`, −3 by default) and «dares refused» + 1; CANCELLED —
   * nothing. The PK's result phase then lasts PK_DARE_OUTCOME_SECONDS more (at least its own time) — v1.67-live (D276):
   * PK_RESULT_SECONDS more while «جولة أخرى» is still allowed. Audited.
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
        UPDATE pk_match_dares
           SET status = ${outcome.status}::pk_dare_status, cause = ${outcome.cause}::pk_dare_cause,
               finished_at = ${iso(now)}::timestamptz, points = ${points}
         WHERE match_id = ${matchId}::uuid`;
      if (outcome.status === 'REFUSED') {
        await addPkPointsIn(tx, {
          matchId,
          hostId: d.loser_host_id,
          kind: 'DARE_REFUSED',
          points,
          counter: 'dares_refused',
          now,
        });
      } else if (outcome.status === 'DONE') {
        await addPkDareDoneIn(tx, d.loser_host_id, now);
      }
      // v1.67-live (D276): while «جولة أخرى» is still allowed (PK_REMATCH_MAX), the hosts get a whole result phase
      // (PK_RESULT_SECONDS) after the dare to offer it, as after a normal PK — before, only the outcome's 8 s.
      const { resultSeconds, dareOutcomeSeconds, rematchMax } = this.config.pk;
      const after = Math.max(resultSeconds, dareOutcomeSeconds);
      await tx.$executeRaw`
        UPDATE pk_matches
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
        targetType: 'pk_match',
        targetId: matchId,
        metadata: { dareId: d.dare_id, status: outcome.status, cause: outcome.cause, points, from: d.status },
      });
      return true;
    }, LIVE_TX_OPTIONS);
    if (done) await this.broadcastMatch(matchId, 'dare');
    return done;
  }

  /** The loser's decision window is open: the draw was revealed and the decision time has not run out. */
  private assertDeciding(dare: DareRow, now: Date): void {
    if (dare.status !== 'DECIDING') throw new AppException(ErrorCode.PK_DARE_CLOSED);
    if (now.getTime() < dare.reveal_at.getTime() || now.getTime() >= dare.decide_by.getTime()) {
      throw new AppException(ErrorCode.PK_DARE_CLOSED);
    }
  }

  /**
   * `POST /live/rooms/{roomId}/pk/dare/accept` «قبول»: the losing host (their room in the path; the winner 403
   * PK_DARE_FORBIDDEN), after the draw's reveal and before `decideBy` → ACTIVE: the timer (PK_DARE_SECONDS, 180)
   * starts for both rooms; the winner may judge during it. Already accepted: the match as it is (idempotent).
   */
  async acceptDare(callerId: string, roomId: string): Promise<PkMatchDto> {
    const { match, dare, isLoser } = await this.ownDare(callerId, roomId);
    if (!isLoser) throw new AppException(ErrorCode.PK_DARE_FORBIDDEN);
    if (dare.status === 'ACTIVE') return this.matchDto(match);
    const now = this.clock.now();
    this.assertDeciding(dare, now);
    const endsAt = new Date(now.getTime() + this.config.pk.dareSeconds * 1000);
    const changed = await this.prisma.$transaction(async (tx) => {
      const n = await tx.$executeRaw`
        UPDATE pk_match_dares SET status = 'ACTIVE', started_at = ${iso(now)}::timestamptz,
               ends_at = ${iso(endsAt)}::timestamptz
         WHERE match_id = ${match.id}::uuid AND status = 'DECIDING' AND decide_by > ${iso(now)}::timestamptz`;
      if (n === 0) return false;
      await tx.$executeRaw`
        UPDATE pk_matches
           SET result_ends_at = GREATEST(result_ends_at, ${iso(endsAt)}::timestamptz
                                         + make_interval(secs => ${this.config.pk.dareOutcomeSeconds})),
               seq = seq + 1
         WHERE id = ${match.id}::uuid`;
      await this.audit.recordIn(tx, {
        action: AuditAction.LIVE_PK_DARE_ANSWER,
        actorUserId: callerId,
        targetType: 'pk_match',
        targetId: match.id,
        metadata: { dareId: dare.dare_id, answer: 'ACCEPTED', endsAt: iso(endsAt) },
      });
      return true;
    }, LIVE_TX_OPTIONS);
    if (!changed) {
      const again = await this.dareRow(this.prisma, match.id);
      if (again?.status !== 'ACTIVE') throw new AppException(ErrorCode.PK_DARE_CLOSED);
    } else {
      return (await this.broadcastMatch(match.id, 'dare'))!;
    }
    return this.matchDto((await this.selectMatch(this.prisma, Prisma.sql`id = ${match.id}::uuid`))!);
  }

  /**
   * `POST /live/rooms/{roomId}/pk/dare/refuse` «رفض»: the losing host, while deciding (after the reveal) → REFUSED:
   * the refusal's PK points (−3 by default) at once, «رفض الحكم» in both rooms. Not after accepting (409
   * PK_DARE_CLOSED). Already refused by them: the match as it is.
   */
  async refuseDare(callerId: string, roomId: string): Promise<PkMatchDto> {
    const { match, dare, isLoser } = await this.ownDare(callerId, roomId);
    if (!isLoser) throw new AppException(ErrorCode.PK_DARE_FORBIDDEN);
    if (dare.status === 'REFUSED' && dare.cause === 'LOSER_REFUSED') return this.matchDto(match);
    this.assertDeciding(dare, this.clock.now());
    const ok = await this.finishDare(
      match.id,
      { status: 'REFUSED', cause: 'LOSER_REFUSED' },
      ['DECIDING'],
      callerId,
    );
    const row = (await this.selectMatch(this.prisma, Prisma.sql`id = ${match.id}::uuid`))!;
    if (!ok) {
      const again = await this.dareRow(this.prisma, match.id);
      if (!(again?.status === 'REFUSED' && again.cause === 'LOSER_REFUSED'))
        throw new AppException(ErrorCode.PK_DARE_CLOSED);
    }
    return this.matchDto(row);
  }

  /**
   * `POST /live/rooms/{roomId}/pk/dare/verdict` `{done}` «نُفّذ ✅» / «لم يُنفّذ ❌»: the winning host only (the loser
   * 403 PK_DARE_FORBIDDEN), during the timer (409 PK_DARE_CLOSED before the loser accepted or once the timer ran
   * out — then it already counts as done). done → DONE; not done → REFUSED with the refusal's points. Final: the same
   * verdict again answers the match as it is, another one 409 PK_DARE_CLOSED.
   */
  async judgeDare(callerId: string, roomId: string, body: unknown): Promise<PkMatchDto> {
    const parsed = verdictSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const { match, dare, isLoser } = await this.ownDare(callerId, roomId);
    if (isLoser) throw new AppException(ErrorCode.PK_DARE_FORBIDDEN);
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
    return this.matchDto((await this.selectMatch(this.prisma, Prisma.sql`id = ${match.id}::uuid`))!);
  }

  /**
   * `POST /live/rooms/{roomId}/pk/dare/report` `{dareId}` ⚠️: anyone signed in who may watch the room (viewers and
   * both hosts), for one of the three dares of the room's open «PK أحكام» (404 otherwise). One report per person per
   * dare (again: 204, not counted twice). At `reportsToDisable` reports (5) the dare is disabled automatically
   * (audited) and goes to the panel's «مُبلَّغ عنها» queue. Rate limit: bucket `live:pk:dare-report` (10 / 10 min).
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
      const inserted = await tx.$executeRaw`
        INSERT INTO pk_dare_reports (dare_id, user_id, match_id, created_at)
        VALUES (${dareId}::uuid, ${callerId}::uuid, ${match.id}::uuid, ${iso(now)}::timestamptz)
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
        metadata: { matchId: match.id, reports: d?.report_count ?? 0 },
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

  /** A host ends the PK (End) during an open dare: see {@link end}. */
  private async settleDareOnLeave(matchId: string, roomId: string, actorId: string | null): Promise<void> {
    const dare = await this.dareRow(this.prisma, matchId);
    if (!dare || dare.finished_at !== null) return;
    const match = (await this.selectMatch(this.prisma, Prisma.sql`id = ${matchId}::uuid`))!;
    const loserRoom = dare.loser_side === 'A' ? match.room_a_id : match.room_b_id;
    if (loserRoom === roomId) {
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
   * The PK tick for a RESULT match of type DARES (true while its dare is open or just ended — the PK then stays open
   * this tick, so the outcome is shown PK_DARE_OUTCOME_SECONDS before the close): the loser
   * gone (live ended, no heartbeat or away for PK_ABSENCE_GRACE_SECONDS) → refused (LOSER_LEFT), also after
   * accepting; no answer by `decideBy` → refused (DECIDE_TIMEOUT, owner-confirmable); the timer over with no verdict
   * → done (TIMER). The winner gone changes nothing: the timer's end counts as done.
   */
  private async dareTick(m: MatchRow, now: Date, grace: number): Promise<boolean> {
    const d = await this.dareRow(this.prisma, m.id);
    if (!d || d.finished_at !== null) return false;
    const loserRoom = await this.roomState(this.prisma, d.loser_side === 'A' ? m.room_a_id : m.room_b_id);
    const gone =
      loserRoom === null ||
      absenceOf(
        {
          roomStatus: loserRoom.status,
          roomEndReason: loserRoom.end_reason,
          lastHeartbeatAt: loserRoom.last_heartbeat_at,
          hostAwaySince: loserRoom.host_away_since,
          leftAt: null,
        },
        now,
        grace,
      ) !== null;
    if (gone) {
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
    // v1.55-live (D242): a rematch keeps the PK media of its chain — a watcher of an earlier battle of the same
    // chain stays while the chain's open match is in this room.
    const [row] = await this.prisma.$queryRaw<{ ok: boolean }[]>`
      WITH me AS (SELECT COALESCE(rematch_root_id, id) AS root FROM pk_matches WHERE id = ${matchId}::uuid)
      SELECT EXISTS (
        SELECT 1 FROM pk_matches m, me
         WHERE m.status <> 'CLOSED' AND (m.room_a_id = ${roomId}::uuid OR m.room_b_id = ${roomId}::uuid)
           AND (m.id = ${matchId}::uuid OR m.rematch_root_id = me.root)) AS ok`;
    return row?.ok === true;
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
         WHERE status IN ('CONNECTED', 'BATTLE') AND (room_a_id = ${roomId}::uuid OR room_b_id = ${roomId}::uuid)
           AND (a_left_at IS NOT NULL OR b_left_at IS NOT NULL)`;
    } else {
      await this.prisma.$executeRaw`
        UPDATE pk_matches SET a_left_at = CASE WHEN room_a_id = ${roomId}::uuid AND host_a_id = ${host}::uuid
                                               THEN COALESCE(a_left_at, ${now}::timestamptz) ELSE a_left_at END,
                              b_left_at = CASE WHEN room_b_id = ${roomId}::uuid AND host_b_id = ${host}::uuid
                                               THEN COALESCE(b_left_at, ${now}::timestamptz) ELSE b_left_at END
         WHERE status IN ('CONNECTED', 'BATTLE') AND (room_a_id = ${roomId}::uuid OR room_b_id = ${roomId}::uuid)`;
    }
  }

  // ---- «جولة أخرى» (v1.55-live, D242) -------------------------------------------------------------

  /**
   * The caller's room's open match under both rooms' PK locks (FOR UPDATE), with the caller's side. No open match
   * → 409 PK_NOT_ACTIVE.
   */
  private async lockedOwnMatch(
    tx: Prisma.TransactionClient,
    room: RoomState,
  ): Promise<{ match: MatchRow; side: PkSideName }> {
    const first = await this.openMatchOfRoom(tx, room.id);
    if (!first) throw new AppException(ErrorCode.PK_NOT_ACTIVE);
    await this.lockRooms(tx, [first.room_a_id, first.room_b_id]);
    const match = await this.selectMatch(tx, Prisma.sql`id = ${first.id}::uuid`, true);
    if (!match || match.status === 'CLOSED') throw new AppException(ErrorCode.PK_NOT_ACTIVE);
    return { match, side: match.room_a_id === room.id ? 'A' : 'B' };
  }

  /**
   * Why «جولة أخرى» cannot be played now (409 PK_REMATCH_UNAVAILABLE), or nothing: the match is in RESULT with
   * its dare over (or none); both lives still on air as SOLO video lives with fresh heartbeats and their hosts
   * present; both hosts ACTIVE and not blocked either way; fewer than PK_REMATCH_MAX rematches in a row.
   */
  private async assertRematchable(tx: Prisma.TransactionClient, m: MatchRow, now: Date): Promise<void> {
    const unavailable = () => new AppException(ErrorCode.PK_REMATCH_UNAVAILABLE);
    if (m.status !== 'RESULT') throw unavailable();
    if (this.config.pk.rematchMax > 0 && m.rematch_count >= this.config.pk.rematchMax) throw unavailable();
    const [open] = await tx.$queryRaw<{ open: boolean }[]>`
      SELECT EXISTS (SELECT 1 FROM pk_match_dares d WHERE d.match_id = ${m.id}::uuid AND d.finished_at IS NULL) AS open`;
    if (open?.open) throw unavailable();
    const [a, b] = await Promise.all([this.roomState(tx, m.room_a_id), this.roomState(tx, m.room_b_id)]);
    if (!this.eligible(a, now) || !this.eligible(b, now)) throw unavailable();
    const active = await tx.user.count({
      where: { id: { in: [m.host_a_id, m.host_b_id] }, status: 'ACTIVE' },
    });
    if (active < 2) throw unavailable();
    if (await this.blocked(tx, m.host_a_id, m.host_b_id)) throw unavailable();
  }

  /**
   * v1.55-live (D242) `POST /live/rooms/{roomId}/pk/rematch` «جولة أخرى»: a host of a RESULT match offers another
   * battle with the same opponent; the other host has PK_REMATCH_ACCEPT_SECONDS to answer (the PK stays open that
   * long). The other host's own offer open → it is an acceptance (both tapped). Already offered by the caller: the
   * match as it is (idempotent). Event `rematch-offer` to both rooms.
   */
  async offerRematch(callerId: string, roomId: string): Promise<PkMatchDto> {
    this.assertPkOn();
    const room = await this.ownRoom(callerId, roomId);
    const now = this.clock.now();
    const result = await this.prisma.$transaction(
      async (tx): Promise<{ kind: 'offered' | 'same'; id: string } | { kind: 'accepted'; id: string }> => {
        const { match, side } = await this.lockedOwnMatch(tx, room);
        if (match.status === 'BATTLE' && match.rematch_of !== null) return { kind: 'same', id: match.id };
        const pending =
          match.rematch_by !== null &&
          match.rematch_expires_at !== null &&
          match.rematch_expires_at.getTime() > now.getTime();
        if (pending && match.rematch_by === side) return { kind: 'same', id: match.id };
        if (pending) return { kind: 'accepted', id: await this.startRematchIn(tx, match, callerId, now) };
        await this.assertRematchable(tx, match, now);
        const expires = new Date(now.getTime() + this.config.pk.rematchAcceptSeconds * 1000);
        await tx.$executeRaw`
          UPDATE pk_matches
             SET rematch_by = ${side}::pk_side, rematch_expires_at = ${iso(expires)}::timestamptz,
                 result_ends_at = GREATEST(COALESCE(result_ends_at, ${iso(expires)}::timestamptz), ${iso(expires)}::timestamptz),
                 seq = seq + 1
           WHERE id = ${match.id}::uuid`;
        return { kind: 'offered', id: match.id };
      },
      LIVE_TX_OPTIONS,
    );
    if (result.kind === 'offered') return (await this.broadcastMatch(result.id, 'rematch-offer'))!;
    if (result.kind === 'accepted') return (await this.broadcastMatch(result.id, 'rematch'))!;
    return this.matchDto((await this.selectMatch(this.prisma, Prisma.sql`id = ${result.id}::uuid`))!);
  }

  /**
   * v1.55-live (D242) `POST /live/rooms/{roomId}/pk/rematch/accept`: the other host accepts — the RESULT match
   * closes quietly (its PK media stays: the chain's watchers remain valid) and a NEW battle starts between the same
   * two rooms at once, with the previous battle's mode and round time, scores and boosters from zero, the same
   * type (its own dare). Event `rematch` to both rooms. Already accepted: the new battle as it is.
   */
  async acceptRematch(callerId: string, roomId: string): Promise<PkMatchDto> {
    this.assertPkOn();
    const room = await this.ownRoom(callerId, roomId);
    const now = this.clock.now();
    const result = await this.prisma.$transaction(async (tx) => {
      const { match, side } = await this.lockedOwnMatch(tx, room);
      if (match.status === 'BATTLE' && match.rematch_of !== null) return { started: false, id: match.id };
      if (
        match.status !== 'RESULT' ||
        match.rematch_by === null ||
        match.rematch_by === side ||
        match.rematch_expires_at === null ||
        match.rematch_expires_at.getTime() <= now.getTime()
      ) {
        throw new AppException(ErrorCode.PK_REMATCH_CLOSED);
      }
      return { started: true, id: await this.startRematchIn(tx, match, callerId, now) };
    }, LIVE_TX_OPTIONS);
    if (result.started) return (await this.broadcastMatch(result.id, 'rematch'))!;
    return this.matchDto((await this.selectMatch(this.prisma, Prisma.sql`id = ${result.id}::uuid`))!);
  }

  /** In the accept's transaction: the checks again, the old match closed, the new battle created; its id. */
  private async startRematchIn(
    tx: Prisma.TransactionClient,
    old: MatchRow,
    actorId: string,
    now: Date,
  ): Promise<string> {
    await this.assertRematchable(tx, old, now);
    await tx.$executeRaw`
      UPDATE pk_matches
         SET status = 'CLOSED', closed_at = ${iso(now)}::timestamptz, rematch_by = NULL, rematch_expires_at = NULL,
             seq = seq + 1
       WHERE id = ${old.id}::uuid AND status = 'RESULT'`;
    const id = uuidv7();
    const type: PkTypeName = old.type === 'DARES' && this.config.pk.daresEnabled ? 'DARES' : 'NORMAL';
    await tx.pkMatch.create({
      data: {
        id,
        source: old.source,
        status: 'BATTLE',
        roomAId: old.room_a_id,
        hostAId: old.host_a_id,
        roomBId: old.room_b_id,
        hostBId: old.host_b_id,
        startedAt: now,
        battleEndsAt: new Date(now.getTime() + old.round_seconds * 1000),
        mode: old.mode,
        roundSeconds: old.round_seconds,
        settingsFrom: old.settings_from,
        seq: 1,
        type,
        aMutesB: old.a_mutes_b,
        bMutesA: old.b_mutes_a,
        rematchOf: old.id,
        rematchRootId: old.rematch_root_id ?? old.id,
        rematchCount: old.rematch_count + 1,
      },
    });
    await this.audit.recordIn(tx, {
      action: AuditAction.LIVE_PK_START,
      actorUserId: actorId,
      targetType: 'pk_match',
      targetId: id,
      metadata: {
        source: 'REMATCH',
        rematchOf: old.id,
        rematchCount: old.rematch_count + 1,
        roomA: old.room_a_id,
        roomB: old.room_b_id,
        mode: old.mode,
        roundSeconds: old.round_seconds,
        type,
      },
    });
    return id;
  }

  /**
   * v1.55-live (D242) `POST /live/rooms/{roomId}/pk/rematch/decline`: the other host says no — the offer ends
   * (event `rematch-declined`, the asking host's honest toast) and the PK closes as it normally does.
   */
  async declineRematch(callerId: string, roomId: string): Promise<void> {
    const room = await this.ownRoom(callerId, roomId);
    const now = this.clock.now();
    const id = await this.prisma.$transaction(async (tx) => {
      const { match, side } = await this.lockedOwnMatch(tx, room);
      if (
        match.status !== 'RESULT' ||
        match.rematch_by === null ||
        match.rematch_by === side ||
        match.rematch_expires_at === null ||
        match.rematch_expires_at.getTime() <= now.getTime()
      ) {
        throw new AppException(ErrorCode.PK_REMATCH_CLOSED);
      }
      return match.id;
    }, LIVE_TX_OPTIONS);
    await this.endRematchOffer(id, 'rematch-declined', null);
  }

  /**
   * v1.55-live (D242) `DELETE /live/rooms/{roomId}/pk/rematch`: the asking host withdraws the offer (event
   * `rematch-cancelled`); the result goes on until its own end. No offer of theirs open → 409 PK_REMATCH_CLOSED.
   */
  async cancelRematch(callerId: string, roomId: string): Promise<PkMatchDto> {
    const room = await this.ownRoom(callerId, roomId);
    const now = this.clock.now();
    const id = await this.prisma.$transaction(async (tx) => {
      const { match, side } = await this.lockedOwnMatch(tx, room);
      if (
        match.status !== 'RESULT' ||
        match.rematch_by !== side ||
        match.rematch_expires_at === null ||
        match.rematch_expires_at.getTime() <= now.getTime()
      ) {
        throw new AppException(ErrorCode.PK_REMATCH_CLOSED);
      }
      return match.id;
    }, LIVE_TX_OPTIONS);
    await this.endRematchOffer(id, 'rematch-cancelled', 'keep');
    return this.matchDto((await this.selectMatch(this.prisma, Prisma.sql`id = ${id}::uuid`))!);
  }

  /**
   * Ends an open offer (still open: the guard): `event` to both rooms; then, unless `keep`, the PK closes as usual
   * (declined or lapsed). True when this call ended it.
   */
  private async endRematchOffer(
    matchId: string,
    event: 'rematch-cancelled' | 'rematch-declined' | 'rematch-expired',
    keep: 'keep' | null,
  ): Promise<boolean> {
    const changed = await this.prisma.$executeRaw`
      UPDATE pk_matches SET rematch_by = NULL, rematch_expires_at = NULL, seq = seq + 1
       WHERE id = ${matchId}::uuid AND status = 'RESULT' AND rematch_by IS NOT NULL`;
    if (changed === 0) return false;
    await this.broadcastMatch(matchId, event);
    if (keep === null) await this.closeResult(matchId, true);
    return true;
  }

  // ---- Settings, records -----------------------------------------------------------------------

  /** `GET /me/live-pk`: the caller's PK switch and record. */
  async mySettings(callerId: string): Promise<PkSettingsDto> {
    const [settings, record] = await Promise.all([
      this.prisma.pkHostSettings.findUnique({ where: { hostId: callerId } }),
      this.prisma.pkHostRecord.findUnique({ where: { hostId: callerId } }),
    ]);
    const minutes = settings?.roundMinutes ?? null;
    return {
      invitesEnabled: settings?.invitesEnabled ?? true,
      mode: settings?.mode ?? 'SINGLE',
      roundMinutes: minutes,
      roundSeconds: minutes !== null ? minutes * 60 : this.config.pk.battleSeconds,
      autoStart: settings?.autoStart ?? true,
      randomGender: settings?.randomGender ?? 'BOTH',
      randomRegion: settings?.randomRegion ?? 'GLOBAL',
      autoMatch: settings?.autoMatch ?? false,
      recommendable: settings?.recommendable ?? true,
      effectiveMinPoints: this.config.pk.effectiveMinPoints,
      record: recordDto(record),
    };
  }

  /**
   * `PUT /me/live-pk`: any of the settings (v1.43: `invitesEnabled`; v1.44-live, D199: the PK Setting
   * page — at least one field, 400 otherwise). Audited with the fields that changed, when any did.
   * Auto match off also takes the host out of the random queue.
   */
  async setSettings(callerId: string, body: unknown, meta: RequestMeta): Promise<PkSettingsDto> {
    const parsed = settingsSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const next = parsed.data;
    await this.prisma.$transaction(async (tx) => {
      const before = await tx.pkHostSettings.findUnique({ where: { hostId: callerId } });
      const current: Record<string, unknown> = {
        invitesEnabled: before?.invitesEnabled ?? true,
        mode: before?.mode ?? 'SINGLE',
        roundMinutes: before?.roundMinutes ?? null,
        autoStart: before?.autoStart ?? true,
        randomGender: before?.randomGender ?? 'BOTH',
        randomRegion: before?.randomRegion ?? 'GLOBAL',
        autoMatch: before?.autoMatch ?? false,
        recommendable: before?.recommendable ?? true,
      };
      const changed = Object.fromEntries(
        Object.entries(next).filter(([k, v]) => v !== undefined && current[k] !== v),
      );
      if (Object.keys(changed).length === 0) return;
      const now = this.clock.now();
      await tx.pkHostSettings.upsert({
        where: { hostId: callerId },
        create: { hostId: callerId, ...changed, updatedAt: now },
        update: { ...changed, updatedAt: now },
      });
      if (changed.autoMatch === false) await tx.pkQueueEntry.deleteMany({ where: { hostId: callerId } });
      await this.audit.recordIn(tx, {
        action: AuditAction.LIVE_PK_SETTINGS,
        actorUserId: callerId,
        targetType: 'user',
        targetId: callerId,
        metadata: changed,
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
          WHERE status IN ('RESULT', 'CLOSED') AND end_reason IS DISTINCT FROM 'CANCELLED'
            AND (host_a_id = ${user.id}::uuid OR host_b_id = ${user.id}::uuid)
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
    // v1.50-live (D229): the dare of each listed DARES match (the drawn one).
    const dareRows = await this.prisma.pkMatchDare.findMany({
      where: { matchId: { in: rows.filter((r) => r.type === 'DARES').map((r) => r.id) } },
      select: {
        matchId: true,
        status: true,
        loserHostId: true,
        dare: { select: { level: true, textAr: true, textEn: true } },
      },
    });
    return {
      record: recordDto(record),
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
            score: Number(this.totalOf(r, mine)),
            opponentScore: Number(this.totalOf(r, otherSide(mine))),
            opponent: people.get(mine === 'A' ? r.host_b_id : r.host_a_id)!,
            startedAt: iso(r.started_at),
            durationSeconds: Math.max(0, Math.round((r.ended_at!.getTime() - r.started_at.getTime()) / 1000)),
            supporters: top
              .filter((s) => people.has(s.userId))
              .map((s) => ({ user: people.get(s.userId)!, points: s.points })),
            // A match before D199 has no `effective`: it was counted.
            effective: r.effective ?? r.end_reason !== 'ADMIN',
            mode: r.mode,
            roundsWon: mine === 'A' ? r.rounds_a : r.rounds_b,
            opponentRoundsWon: mine === 'A' ? r.rounds_b : r.rounds_a,
            type: r.type,
            dare: ((d) =>
              d
                ? {
                    status: d.status,
                    level: d.dare.level,
                    textAr: d.dare.textAr,
                    textEn: d.dare.textEn,
                    mine: d.loserHostId === user.id,
                  }
                : null)(dareRows.find((d) => d.matchId === r.id)),
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
    // D210: a wait whose room is no longer LIVE (ended, timed out) is dropped at once and never
    // messaged — its media room is gone (LiveKit answers "no response from servers"); a wait that
    // timed out in a LIVE room is told once. Either way the row is deleted first: no retries.
    const waits = await this.prisma.$queryRaw<{ host_id: string; room_id: string; live: boolean }[]>`
      WITH gone AS (
        DELETE FROM pk_queue q
         WHERE q.expires_at <= ${iso(now)}::timestamptz
            OR NOT EXISTS (SELECT 1 FROM live_rooms r WHERE r.id = q.room_id AND r.status = 'LIVE')
        RETURNING q.host_id, q.room_id)
      SELECT g.host_id::text AS host_id, g.room_id::text AS room_id, COALESCE(r.status = 'LIVE', false) AS live
        FROM gone g LEFT JOIN live_rooms r ON r.id = g.room_id`;
    for (const w of waits) {
      if (!w.live) continue;
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
      if (m.status === 'CONNECTED') {
        // v1.44-live (D199): not started — a host gone, or nobody started it in time: cancelled.
        const [a, b] = await Promise.all([
          this.roomState(this.prisma, m.room_a_id),
          this.roomState(this.prisma, m.room_b_id),
        ]);
        const gone = (room: RoomState | null, leftAt: Date | null) =>
          room === null ||
          absenceOf(
            {
              roomStatus: room.status,
              roomEndReason: room.end_reason,
              lastHeartbeatAt: room.last_heartbeat_at,
              hostAwaySince: room.host_away_since,
              leftAt,
            },
            now,
            grace,
          ) !== null;
        const goneA = gone(a, m.a_left_at);
        const goneB = gone(b, m.b_left_at);
        if (goneA || goneB || m.battle_ends_at.getTime() <= now.getTime()) {
          const loser = goneA && !goneB ? 'A' : goneB && !goneA ? 'B' : null;
          if (await this.cancelConnected(m.id, loser)) closed += 1;
        }
      } else if (m.status === 'BATTLE') {
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
        // v1.55-live (D242): a rematch offer nobody answered in time lapses, and the PK closes as usual.
        if (m.rematch_by !== null && m.rematch_expires_at !== null) {
          if (m.rematch_expires_at.getTime() <= now.getTime()) {
            if (await this.endRematchOffer(m.id, 'rematch-expired', null)) closed += 1;
            continue;
          }
        }
        // v1.50-live (D229): an open dare runs first (its timeouts, the loser gone); the PK stays open meanwhile.
        if (m.type === 'DARES' && (await this.dareTick(m, now, grace))) continue;
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
    await this.autoMatch(now);
    return { expiredInvites: expired.length, ended, closed };
  }

  /**
   * v1.44-live (D199) «Auto Match»: a host with it on whose SOLO video live may start a PK and who is
   * idle — no match, no open invitation, not waiting, no PK of theirs closed in the last
   * PK_AUTO_MATCH_REST_SECONDS — enters the random queue as if they had tapped «مطابقة عشوائية». Their
   * preferences apply as usual. Refusals (PK off, a block, a race) are left for the next tick.
   */
  private async autoMatch(now: Date): Promise<number> {
    if (!this.config.pk.enabled || !this.config.live.hostingEnabled) return 0;
    const rest = new Date(now.getTime() - this.config.pk.autoMatchRestSeconds * 1000);
    const hosts = await this.prisma.$queryRaw<{ host_id: string; room_id: string }[]>`
      SELECT s.host_id::text AS host_id, r.id::text AS room_id
        FROM pk_host_settings s
        JOIN live_rooms r ON r.host_user_id = s.host_id AND r.status = 'LIVE' AND r.mode = 'SOLO'::live_room_mode
       WHERE s.auto_match
         AND r.last_heartbeat_at > ${iso(this.staleCutoff(now))}::timestamptz AND r.host_away_since IS NULL
         AND NOT EXISTS (SELECT 1 FROM pk_queue q WHERE q.host_id = s.host_id AND q.expires_at > ${iso(now)}::timestamptz)
         AND NOT EXISTS (SELECT 1 FROM pk_matches m WHERE (m.room_a_id = r.id OR m.room_b_id = r.id)
                          AND (m.status <> 'CLOSED' OR m.closed_at > ${iso(rest)}::timestamptz))
         AND NOT EXISTS (SELECT 1 FROM pk_invites i WHERE i.status = 'PENDING' AND i.expires_at > ${iso(now)}::timestamptz
                          AND (i.from_room_id = r.id OR i.to_room_id = r.id))
       ORDER BY r.started_at, s.host_id
       LIMIT 200`;
    let joined = 0;
    for (const h of hosts) {
      try {
        await this.joinRandom(h.host_id, h.room_id);
        joined += 1;
      } catch (err) {
        if (!(err instanceof AppException)) {
          this.logger.warn({ error: safeErrorLog(err) }, 'PK auto match could not queue a host');
        }
      }
    }
    return joined;
  }
}
