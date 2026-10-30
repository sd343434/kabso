import { Inject, Injectable, Logger } from '@nestjs/common';
import type { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode, type ErrorDetail } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import { SocialCursorCodec } from '../posts/social-cursor.js';
import { UsersService } from '../users/users.service.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { cpTierName } from '../couples/couples.constants.js';
import { cpPrivilegesFor, type CpPrivilegeCode } from '../cp-space/cp-privileges.js';
import {
  LiveRoomsService,
  LIVE_TX_OPTIONS,
  type LiveRoomMode,
  type RoomRow,
  type UserSummaryDto,
} from './live-rooms.service.js';
import { bumpSeatsVersionIn, releaseUserIn, type ReleasedUser } from './live-seats.store.js';
import { LiveRoomMetadataService } from './live-metadata.service.js';
import { POINTS_PER_SUPPORT_COIN } from './live-taps.js';
import {
  guestSeatCount,
  hasGuestSeats,
  isUuid,
  liveSeatInviteBodySchema,
  liveSeatLockBodySchema,
  liveSeatMuteBodySchema,
  liveSeatRequestBodySchema,
  parseSeatIndexPath,
  type GuestSeatMode,
} from './live.schemas.js';
import {
  LIVE_MEDIA_PROVIDER,
  type LiveMediaPermission,
  type LiveMediaProvider,
  type LiveMediaSource,
} from './media/live-media.provider.js';

// ---- Response shapes (openapi v1.7-live, CP-011) -----------------------------------------------

export interface LiveSeatDto {
  index: number;
  state: 'EMPTY' | 'LOCKED' | 'TAKEN';
  user: UserSummaryDto | null;
  mutedByHost: boolean;
  /** v1.27.2-live (D135): gift points the seated person received in this live (0 unless TAKEN). */
  points: number;
}

export interface LiveSeatRequestDto {
  id: string;
  user: UserSummaryDto;
  seatIndex: number | null;
  createdAt: string;
}

export interface LiveSeatInviteDto {
  id: string;
  user: UserSummaryDto;
  seatIndex: number | null;
  invitedBy: UserSummaryDto;
  expiresAt: string;
}

export type LiveSeatRole = 'HOST' | 'MODERATOR' | 'SEATED' | 'VIEWER';

/**
 * v1.23.3-live (D111): a CP couple (CP-018) whose partners both sit in the room now, the host's
 * seat included. `userIds` in seat order (the host first, then by seat index).
 */
export interface LiveSeatCoupleDto {
  userIds: [string, string];
  level: number;
  levelName: string;
  /** v1.24.2-live (D115): the CP privileges the couple's level unlocked (the app plays the Couple Mic Effect from `MIC_EFFECT`). */
  privileges: CpPrivilegeCode[];
}

export interface LiveSeatsDto {
  roomId: string;
  mode: GuestSeatMode;
  version: number;
  seatCount: number;
  /** v1.39-live (D173): the room is a cinema now (YouTube together in an AUDIO room). */
  cinema: boolean;
  seats: LiveSeatDto[];
  moderators: UserSummaryDto[];
  couples: LiveSeatCoupleDto[];
  pendingRequests?: number;
  mine?: {
    role: LiveSeatRole;
    seatIndex: number | null;
    request: LiveSeatRequestDto | null;
    invite: LiveSeatInviteDto | null;
  };
}

export interface PageDto<T> {
  data: T[];
  page: { nextCursor: string | null; hasMore: boolean };
}

/**
 * v1.39-live (D173, owner: «عندما مشاهدة يوتيوب لا يكون هناك إلا ١٠ كراسي فقط»): while an AUDIO room
 * watches YouTube together (a `live_watch` row exists) it is a cinema with the 10 drawn seats — the
 * host's and seats 1–9. Seats from this index on are unavailable (read as LOCKED) until it closes.
 */
export const CINEMA_SEAT_COUNT = 10;

/** An invitation is valid for 60 seconds (owner D94). */
export const SEAT_INVITE_TTL_SECONDS = 60;
/** Up to 5 moderators per room (owner D94). */
export const MAX_ROOM_MODERATORS = 5;
const REQUEST_PAGE_MAX = 50;

/** The media permission of a guest on a seat of `mode` (§10.9). */
export function seatPermission(mode: GuestSeatMode, mutedByHost: boolean): LiveMediaPermission {
  // D174: a SOLO live's guests are on camera like a multi-guest live's.
  const sources: LiveMediaSource[] =
    mode !== 'AUDIO'
      ? mutedByHost
        ? ['camera']
        : ['camera', 'microphone']
      : mutedByHost
        ? []
        : ['microphone'];
  return { visible: true, sources };
}

/** A viewer: hidden, publishing nothing. */
export const VIEWER_PERMISSION: LiveMediaPermission = { visible: false, sources: [] };

/** What the host of a room of `mode` may publish (CP-011: an AUDIO host the microphone only). */
export function hostSources(mode: LiveRoomMode): LiveMediaSource[] {
  return mode === 'AUDIO' ? ['microphone'] : ['camera', 'microphone'];
}

/** 422 `VALIDATION_FAILED` (openapi `addLiveModerator`: the moderator limit and a bad target). */
class UnprocessableValidation extends AppException {
  override readonly status = 422;
  constructor(details: readonly ErrorDetail[]) {
    super(ErrorCode.VALIDATION_FAILED, undefined, details);
  }
}

function seatUnavailable(): AppException {
  return new AppException(ErrorCode.LIVE_SEAT_UNAVAILABLE);
}

function notPending(): AppException {
  return new AppException(ErrorCode.LIVE_REQUEST_NOT_PENDING);
}

function forbidden(): AppException {
  return new AppException(ErrorCode.AUTH_FORBIDDEN);
}

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND);
}

function parseBody<S extends z.ZodType>(schema: S, body: unknown): z.output<S> {
  const parsed = schema.safeParse(body ?? {}, { reportInput: true });
  if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
  return parsed.data;
}

/**
 * The `{seatIndex}` path segment. A segment that is not an integer names no seat of the room, like
 * an out-of-range index: 409 LIVE_SEAT_UNAVAILABLE after the room checks (openapi documents no 400
 * for `removeFromLiveSeat`, and 400 on mute and lock is for the body).
 */
function seatIndexOf(raw: string): number {
  return parseSeatIndexPath(raw) ?? -1;
}

/** A locked LIVE room (`SELECT … FOR UPDATE`). */
interface LockedRoom {
  id: string;
  hostUserId: string;
  mode: GuestSeatMode;
  /** The seats usable now: the room's count, or {@link CINEMA_SEAT_COUNT} in a cinema (D173). */
  seatCount: number;
  /** The room's own seat count (what a cinema gives back when it closes). */
  roomSeatCount: number;
  cinema: boolean;
}

/** Media work to do after a seat transaction commits (best effort). */
type Effect =
  | { readonly kind: 'permission'; readonly identity: string; readonly permission: LiveMediaPermission }
  | { readonly kind: 'data'; readonly identity: string; readonly payload: string };

/** The outcome of a seat transaction: the new version (if it changed) and media effects. */
interface Change<T> {
  readonly result: T;
  readonly version: number | null;
  readonly effects: readonly Effect[];
  /** Thrown after the commit (e.g. an expired invitation that was marked EXPIRED). */
  readonly error?: AppException;
}

/**
 * Seats in MULTI and AUDIO rooms (CP-011, CONVENTIONS §10.9): reading the seats, requests,
 * invitations, the host's and moderators' controls and moderators.
 *
 * Every change runs in one transaction that first locks the room row (`FOR UPDATE`), so changes
 * of one room are serialized (two accepts racing for the last seat: exactly one wins), and
 * increases the room's `seats_version`. After the commit the media server is told, best effort:
 * the room metadata `{"seatsVersion": n, "score": total}` (the score: CP-012), the guest's
 * publish permission, and the invitation data message. A media failure never undoes the change; the sweeper's reconciliation repeats the
 * permission and metadata ({@link reconcileRoom}).
 */
@Injectable()
export class LiveSeatsService {
  private readonly logger = new Logger(LiveSeatsService.name);
  private readonly cursors: SocialCursorCodec;

  constructor(
    private readonly prisma: PrismaService,
    private readonly rooms: LiveRoomsService,
    private readonly users: UsersService,
    private readonly clock: Clock,
    @Inject(LIVE_MEDIA_PROVIDER) private readonly media: LiveMediaProvider,
    @Inject(APP_CONFIG) config: AppConfig,
    private readonly metadata: LiveRoomMetadataService,
  ) {
    this.cursors = new SocialCursorCodec(config.social.cursorKey);
  }

  // ---- Room checks -----------------------------------------------------------------------------

  /** A visible (404), LIVE (409 LIVE_ROOM_ENDED) room with seats (409 LIVE_SEAT_UNAVAILABLE). */
  private async seatedRoom(roomId: string, callerId: string | null): Promise<RoomRow> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    if (!hasGuestSeats(row.mode)) throw seatUnavailable();
    return row;
  }

  /** Locks the room row; it must still be LIVE (a concurrent end → 409 LIVE_ROOM_ENDED). */
  private async lockRoom(tx: Prisma.TransactionClient, roomId: string): Promise<LockedRoom> {
    const [room] = await tx.$queryRaw<
      { id: string; host_user_id: string; mode: string; seat_count: number | null; status: string }[]
    >`
      SELECT id::text AS id, host_user_id::text AS host_user_id, mode::text AS mode,
             seat_count::int AS seat_count, status::text AS status
        FROM live_rooms WHERE id = ${roomId}::uuid FOR UPDATE`;
    if (!room) throw notFound();
    if (room.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    if (!hasGuestSeats(room.mode)) throw seatUnavailable();
    const count = guestSeatCount(room.mode, room.seat_count);
    if (count === 0) throw seatUnavailable();
    const cinema = await this.isCinema(tx, room.id, room.mode);
    return {
      id: room.id,
      hostUserId: room.host_user_id,
      mode: room.mode,
      seatCount: cinema ? Math.min(count, CINEMA_SEAT_COUNT) : count,
      roomSeatCount: count,
      cinema,
    };
  }

  /** D173: an AUDIO room that watches YouTube together now is a cinema. */
  private async isCinema(
    db: Prisma.TransactionClient | PrismaService,
    roomId: string,
    mode: string,
  ): Promise<boolean> {
    if (mode !== 'AUDIO') return false;
    return (await db.liveWatch.count({ where: { roomId } })) > 0;
  }

  private async isModerator(
    db: Prisma.TransactionClient | PrismaService,
    roomId: string,
    userId: string,
  ): Promise<boolean> {
    return (await db.liveRoomModerator.count({ where: { roomId, userId } })) > 0;
  }

  /** The caller's privilege in a room: HOST, MODERATOR or none (→ 403). */
  private async privilege(
    tx: Prisma.TransactionClient,
    room: { id: string; hostUserId: string },
    callerId: string,
  ): Promise<'HOST' | 'MODERATOR'> {
    if (callerId === room.hostUserId) return 'HOST';
    if (await this.isModerator(tx, room.id, callerId)) return 'MODERATOR';
    throw forbidden();
  }

  /** A moderator never acts on the host or another moderator (§10.9); acting on oneself is fine. */
  private async assertMayActOn(
    tx: Prisma.TransactionClient,
    room: LockedRoom,
    callerId: string,
    privilege: 'HOST' | 'MODERATOR',
    targetId: string,
  ): Promise<void> {
    if (privilege === 'HOST' || targetId === callerId) return;
    if (targetId === room.hostUserId || (await this.isModerator(tx, room.id, targetId))) throw forbidden();
  }

  private async blockedWithHost(
    tx: Prisma.TransactionClient | PrismaService,
    hostId: string,
    userId: string,
  ): Promise<boolean> {
    const count = await tx.userBlock.count({
      where: {
        OR: [
          { blockerId: hostId, blockedId: userId },
          { blockerId: userId, blockedId: hostId },
        ],
      },
    });
    return count > 0;
  }

  /** Seats 1 … seatCount-1 that are EMPTY, in order. */
  private async freeSeats(tx: Prisma.TransactionClient, room: LockedRoom): Promise<number[]> {
    const used = new Set(
      (await tx.liveRoomSeat.findMany({ where: { roomId: room.id }, select: { seatIndex: true } })).map(
        (s) => s.seatIndex,
      ),
    );
    const free: number[] = [];
    for (let i = 1; i < room.seatCount; i += 1) if (!used.has(i)) free.push(i);
    return free;
  }

  /**
   * The seat to use: `explicit` must be free (else 409); otherwise `preferred` if free, else the
   * first free seat; none → 409 LIVE_SEAT_UNAVAILABLE.
   */
  private async pickSeat(
    tx: Prisma.TransactionClient,
    room: LockedRoom,
    explicit: number | null,
    preferred: number | null,
  ): Promise<number> {
    const free = await this.freeSeats(tx, room);
    if (explicit !== null) {
      if (!free.includes(explicit)) throw seatUnavailable();
      return explicit;
    }
    if (preferred !== null && free.includes(preferred)) return preferred;
    const first = free[0];
    if (first === undefined) throw seatUnavailable();
    return first;
  }

  private async seatOf(tx: Prisma.TransactionClient, roomId: string, userId: string): Promise<number | null> {
    const seat = await tx.liveRoomSeat.findFirst({ where: { roomId, userId }, select: { seatIndex: true } });
    return seat?.seatIndex ?? null;
  }

  /** Seats `userId` and closes their pending request and invitation (ACCEPTED). */
  private async seatUserIn(
    tx: Prisma.TransactionClient,
    room: LockedRoom,
    userId: string,
    seatIndex: number,
    now: Date,
  ): Promise<Effect> {
    await tx.liveRoomSeat.create({
      data: { roomId: room.id, seatIndex, userId, locked: false, mutedByHost: false, updatedAt: now },
    });
    await tx.liveSeatRequest.updateMany({
      where: { roomId: room.id, userId, status: 'PENDING' },
      data: { status: 'ACCEPTED', handledAt: now },
    });
    await tx.liveSeatInvite.updateMany({
      where: { roomId: room.id, userId, status: 'PENDING' },
      data: { status: 'ACCEPTED', handledAt: now },
    });
    return { kind: 'permission', identity: userId, permission: seatPermission(room.mode, false) };
  }

  private async bump(tx: Prisma.TransactionClient, roomId: string): Promise<number> {
    return (await bumpSeatsVersionIn(tx, [roomId])).get(roomId) ?? 0;
  }

  // ---- Transactions and media effects -----------------------------------------------------------

  /** Runs a seat transaction, then applies its media effects; rethrows a deferred error. */
  private async change<T>(
    roomId: string,
    fn: (tx: Prisma.TransactionClient, now: Date) => Promise<Change<T>>,
  ): Promise<T> {
    const now = this.clock.now();
    const outcome = await this.prisma.$transaction((tx) => fn(tx, now), LIVE_TX_OPTIONS);
    await this.applyEffects(roomId, outcome.version, outcome.effects);
    if (outcome.error) throw outcome.error;
    return outcome.result;
  }

  /**
   * Best effort: permission changes and data messages first, then the metadata (so an app that
   * refetches on the new version finds its permission already changed). Failures are logged without
   * identities and repaired by {@link reconcileRoom}.
   */
  private async applyEffects(
    roomId: string,
    version: number | null,
    effects: readonly Effect[],
  ): Promise<void> {
    for (const effect of effects) {
      try {
        if (effect.kind === 'permission') {
          await this.media.setPermission(roomId, effect.identity, effect.permission);
        } else {
          await this.media.sendData(roomId, effect.identity, effect.payload);
        }
      } catch (err) {
        this.logger.warn(
          { effect: effect.kind, error: safeErrorLog(err) },
          'Could not apply a seat change on the media server; reconciliation repeats it',
        );
      }
    }
    if (version !== null) await this.metadata.write(roomId);
  }

  // ---- Reading ---------------------------------------------------------------------------------

  /** `GET /live/rooms/{roomId}/seats` (guests too: no `mine`, no `pendingRequests`). */
  async getSeats(callerId: string | null, roomId: string, lang: ContentLanguage): Promise<LiveSeatsDto> {
    const row = await this.seatedRoom(roomId, callerId);
    return this.seatsOf(row.id, callerId, lang);
  }

  /** The seats of a room as `callerId` sees them (after a change, or for a read). */
  private async seatsOf(
    roomId: string,
    callerId: string | null,
    lang: ContentLanguage,
  ): Promise<LiveSeatsDto> {
    const room = await this.prisma.liveRoom.findUniqueOrThrow({
      where: { id: roomId },
      select: { id: true, mode: true, seatCount: true, seatsVersion: true, hostUserId: true },
    });
    const mode = room.mode as GuestSeatMode;
    const seatCount = guestSeatCount(mode, room.seatCount);
    // D173: in a cinema the seats from CINEMA_SEAT_COUNT on read as LOCKED (nobody sits there).
    const cinema = await this.isCinema(this.prisma, roomId, mode);
    const usable = cinema ? Math.min(seatCount, CINEMA_SEAT_COUNT) : seatCount;
    const [rows, moderators] = await Promise.all([
      this.prisma.liveRoomSeat.findMany({
        where: { roomId, seatIndex: { lt: usable } },
        include: { user: { select: USER_SUMMARY_SELECT } },
      }),
      this.prisma.liveRoomModerator.findMany({
        where: { roomId, user: { status: 'ACTIVE' } },
        orderBy: [{ addedAt: 'asc' }, { userId: 'asc' }],
        include: { user: { select: USER_SUMMARY_SELECT } },
      }),
    ]);
    const byIndex = new Map(rows.map((r) => [r.seatIndex, r]));
    const points = await this.receivedPoints(
      roomId,
      rows.flatMap((r) => (r.user && r.seatIndex < usable ? [r.user.id] : [])),
    );
    const seats: LiveSeatDto[] = [];
    for (let index = 1; index < seatCount; index += 1) {
      const row = byIndex.get(index);
      if (index >= usable) {
        seats.push({ index, state: 'LOCKED', user: null, mutedByHost: false, points: 0 });
      } else if (row?.user) {
        seats.push({
          index,
          state: 'TAKEN',
          user: userSummary(row.user),
          mutedByHost: row.mutedByHost,
          points: points.get(row.user.id) ?? 0,
        });
      } else if (row?.locked) {
        seats.push({ index, state: 'LOCKED', user: null, mutedByHost: false, points: 0 });
      } else {
        seats.push({ index, state: 'EMPTY', user: null, mutedByHost: false, points: 0 });
      }
    }
    const dto: LiveSeatsDto = {
      roomId: room.id,
      mode,
      version: room.seatsVersion,
      seatCount,
      cinema,
      seats,
      moderators: moderators.map((m) => userSummary(m.user)),
      couples: await this.seatedCouples(room.hostUserId, seats, lang),
    };
    if (callerId === null) return dto;

    const isHost = callerId === room.hostUserId;
    const isModerator = moderators.some((m) => m.userId === callerId);
    if (isHost || isModerator) {
      dto.pendingRequests = await this.prisma.liveSeatRequest.count({
        where: { roomId, status: 'PENDING', user: { status: 'ACTIVE' } },
      });
    }
    const mySeat = rows.find((r) => r.userId === callerId)?.seatIndex ?? null;
    const [request, invite] = await Promise.all([
      this.prisma.liveSeatRequest.findFirst({
        where: { roomId, userId: callerId, status: 'PENDING' },
        include: { user: { select: USER_SUMMARY_SELECT } },
      }),
      this.prisma.liveSeatInvite.findFirst({
        where: { roomId, userId: callerId, status: 'PENDING', expiresAt: { gt: this.clock.now() } },
        include: { user: { select: USER_SUMMARY_SELECT }, invitedBy: { select: USER_SUMMARY_SELECT } },
      }),
    ]);
    dto.mine = {
      role: isHost ? 'HOST' : isModerator ? 'MODERATOR' : mySeat !== null ? 'SEATED' : 'VIEWER',
      seatIndex: mySeat,
      request: request ? requestDto(request) : null,
      invite: invite ? inviteDto(invite) : null,
    };
    return dto;
  }

  /**
   * v1.27.2-live (D135, §10.9): the gift points each of [userIds] received in this live — 100 for
   * every counted coin of their share, as the live score counts them (a LUCKY send counts the host
   * share stored with its draw, §10.27).
   */
  private async receivedPoints(roomId: string, userIds: readonly string[]): Promise<Map<string, number>> {
    if (userIds.length === 0) return new Map();
    const rows = await this.prisma.$queryRaw<{ user_id: string; coins: bigint }[]>`
      SELECT r.user_id::text AS user_id,
             SUM(CASE WHEN d.gift_id IS NULL THEN r.coins
                      ELSE (r.coins * (d.odds->>'hostShareBps')::bigint) / 10000 END)::bigint AS coins
        FROM live_gift_recipients r
        JOIN live_gifts g ON g.id = r.gift_id
        LEFT JOIN lucky_gift_draws d ON d.gift_id = g.id
       WHERE g.room_id = ${roomId}::uuid AND r.user_id = ANY(${[...userIds]}::uuid[])
       GROUP BY r.user_id`;
    return new Map(rows.map((r) => [r.user_id, Number(r.coins) * POINTS_PER_SUPPORT_COIN]));
  }

  /**
   * v1.23.3-live (D111): the CP couples (CP-018) whose partners both sit in the room now — the host
   * and the TAKEN seats. Like `PublicProfile.cp`, a couple shows only while both accounts are
   * ACTIVE; a couple whose partners have a block between them (either way) is not shown. An ended
   * couple has no `cp_partners` rows, so it is never listed.
   */
  private async seatedCouples(
    hostUserId: string,
    seats: readonly LiveSeatDto[],
    lang: ContentLanguage,
  ): Promise<LiveSeatCoupleDto[]> {
    const order = new Map<string, number>([[hostUserId, 0]]);
    for (const seat of seats) if (seat.user) order.set(seat.user.id, seat.index);
    if (order.size < 2) return [];
    const ids = [...order.keys()];
    const rows = await this.prisma.cpPartner.findMany({
      where: {
        userId: { in: ids },
        partnerId: { in: ids },
        user: { status: 'ACTIVE' },
        partner: { status: 'ACTIVE' },
        couple: { endedAt: null },
      },
      select: { userId: true, partnerId: true, couple: { select: { level: true } } },
    });
    const pairs = rows.filter((r) => r.userId < r.partnerId);
    if (pairs.length === 0) return [];
    const blocks = await this.prisma.userBlock.findMany({
      where: { blockerId: { in: ids }, blockedId: { in: ids } },
      select: { blockerId: true, blockedId: true },
    });
    const blocked = new Set(blocks.map((b) => `${b.blockerId}:${b.blockedId}`));
    const couples: LiveSeatCoupleDto[] = [];
    for (const pair of pairs) {
      if (
        blocked.has(`${pair.userId}:${pair.partnerId}`) ||
        blocked.has(`${pair.partnerId}:${pair.userId}`)
      ) {
        continue;
      }
      const [first, second] =
        order.get(pair.userId)! < order.get(pair.partnerId)!
          ? [pair.userId, pair.partnerId]
          : [pair.partnerId, pair.userId];
      couples.push({
        userIds: [first, second],
        level: pair.couple.level,
        levelName: cpTierName(pair.couple.level, lang),
        privileges: cpPrivilegesFor(pair.couple.level),
      });
    }
    return couples.sort((x, y) => order.get(x.userIds[0])! - order.get(y.userIds[0])!);
  }

  // ---- Seat requests ---------------------------------------------------------------------------

  /** `POST /live/rooms/{roomId}/seat-requests`: 201 new, 200 the pending one. */
  async requestSeat(
    callerId: string,
    roomId: string,
    body: unknown,
  ): Promise<{ created: boolean; request: LiveSeatRequestDto }> {
    const input = parseBody(liveSeatRequestBodySchema, body);
    const row = await this.seatedRoom(roomId, callerId);
    // v1.20-live (D105, §10.20): nobody kicked out of this live asks for a seat in it.
    if (row.kicked) throw new AppException(ErrorCode.LIVE_KICKED);
    const outcome = await this.change(row.id, async (tx, now) => {
      const room = await this.lockRoom(tx, row.id);
      if (callerId === room.hostUserId) throw seatUnavailable();
      if ((await this.seatOf(tx, room.id, callerId)) !== null) throw seatUnavailable();
      const pending = await tx.liveSeatRequest.findFirst({
        where: { roomId: room.id, userId: callerId, status: 'PENDING' },
        include: { user: { select: USER_SUMMARY_SELECT } },
      });
      if (pending)
        return { result: { created: false, request: requestDto(pending) }, version: null, effects: [] };
      const asked = input.seatIndex ?? null;
      if (asked !== null && asked >= room.seatCount) throw seatUnavailable();
      await this.pickSeat(tx, room, asked, null);
      const created = await tx.liveSeatRequest.create({
        data: { roomId: room.id, userId: callerId, seatIndex: asked, createdAt: now },
        include: { user: { select: USER_SUMMARY_SELECT } },
      });
      return {
        result: { created: true, request: requestDto(created) },
        version: await this.bump(tx, room.id),
        effects: [],
      };
    });
    return outcome;
  }

  /** `DELETE /live/rooms/{roomId}/seat-requests/me` (idempotent). */
  async cancelRequest(callerId: string, roomId: string): Promise<void> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    await this.change(row.id, async (tx, now) => {
      const updated = await tx.liveSeatRequest.updateMany({
        where: { roomId: row.id, userId: callerId, status: 'PENDING' },
        data: { status: 'CANCELLED', handledAt: now },
      });
      return {
        result: undefined,
        version: updated.count > 0 ? await this.bump(tx, row.id) : null,
        effects: [],
      };
    });
  }

  /** `GET /live/rooms/{roomId}/seat-requests` (host and moderators): pending, oldest first. */
  async listRequests(
    callerId: string,
    roomId: string,
    query: { cursor?: string; limit: number },
  ): Promise<PageDto<LiveSeatRequestDto>> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (callerId !== row.host_user_id && !(await this.isModerator(this.prisma, row.id, callerId))) {
      throw forbidden();
    }
    const scope = `live-seat-requests:${row.id}`;
    let after: { at: Date; id: string } | null = null;
    if (query.cursor !== undefined) {
      after = this.cursors.decode(query.cursor, scope);
      if (!after) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    }
    const limit = Math.min(query.limit, REQUEST_PAGE_MAX);
    const rows =
      row.status === 'LIVE' && hasGuestSeats(row.mode)
        ? await this.prisma.liveSeatRequest.findMany({
            where: {
              roomId: row.id,
              status: 'PENDING',
              user: { status: 'ACTIVE' },
              ...(after
                ? { OR: [{ createdAt: { gt: after.at } }, { createdAt: after.at, id: { gt: after.id } }] }
                : {}),
            },
            orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
            take: limit + 1,
            include: { user: { select: USER_SUMMARY_SELECT } },
          })
        : [];
    const hasMore = rows.length > limit;
    const page = rows.slice(0, limit);
    const last = page.at(-1);
    return {
      data: page.map(requestDto),
      page: {
        hasMore,
        nextCursor: hasMore && last ? this.cursors.encode(scope, { at: last.createdAt, id: last.id }) : null,
      },
    };
  }

  /** `POST …/seat-requests/{requestId}/accept` (host or moderator). */
  async acceptRequest(
    callerId: string,
    roomId: string,
    requestId: string,
    body: unknown,
    lang: ContentLanguage,
  ): Promise<LiveSeatsDto> {
    const input = parseBody(liveSeatRequestBodySchema, body);
    if (!isUuid(requestId)) throw notFound();
    const row = await this.seatedRoom(roomId, callerId);
    await this.change(row.id, async (tx, now) => {
      const room = await this.lockRoom(tx, row.id);
      const privilege = await this.privilege(tx, room, callerId);
      const request = await tx.liveSeatRequest.findFirst({
        where: { id: requestId.toLowerCase(), roomId: room.id },
      });
      if (!request) throw notFound();
      if (request.status !== 'PENDING') throw notPending();
      await this.assertMayActOn(tx, room, callerId, privilege, request.userId);
      // A requester who is no longer ACTIVE, is blocked with the host or already sits is not
      // waiting any more: the request expires (committed) and the caller gets 409.
      const active = await tx.user.count({ where: { id: request.userId, status: 'ACTIVE' } });
      if (
        active === 0 ||
        (await this.blockedWithHost(tx, room.hostUserId, request.userId)) ||
        (await this.seatOf(tx, room.id, request.userId)) !== null
      ) {
        await tx.liveSeatRequest.update({
          where: { id: request.id },
          data: { status: 'EXPIRED', handledAt: now },
        });
        return { result: undefined, version: await this.bump(tx, room.id), effects: [], error: notPending() };
      }
      if (input.seatIndex !== undefined && input.seatIndex >= room.seatCount) throw seatUnavailable();
      const seatIndex = await this.pickSeat(tx, room, input.seatIndex ?? null, request.seatIndex);
      const effect = await this.seatUserIn(tx, room, request.userId, seatIndex, now);
      return { result: undefined, version: await this.bump(tx, room.id), effects: [effect] };
    });
    return this.seatsOf(row.id, callerId, lang);
  }

  /** `POST …/seat-requests/{requestId}/decline` (host or moderator; already handled → 204). */
  async declineRequest(callerId: string, roomId: string, requestId: string): Promise<void> {
    if (!isUuid(requestId)) throw notFound();
    const row = await this.rooms.visibleRow(roomId, callerId);
    await this.change(row.id, async (tx, now) => {
      await tx.$queryRaw`SELECT id FROM live_rooms WHERE id = ${row.id}::uuid FOR UPDATE`;
      const host = { id: row.id, hostUserId: row.host_user_id };
      const privilege = await this.privilege(tx, host, callerId);
      const request = await tx.liveSeatRequest.findFirst({
        where: { id: requestId.toLowerCase(), roomId: row.id },
      });
      if (!request) throw notFound();
      if (privilege === 'MODERATOR' && request.userId !== callerId) {
        if (await this.isModerator(tx, row.id, request.userId)) throw forbidden();
      }
      if (request.status !== 'PENDING') return { result: undefined, version: null, effects: [] };
      await tx.liveSeatRequest.update({
        where: { id: request.id },
        data: { status: 'DECLINED', handledAt: now },
      });
      return { result: undefined, version: await this.bump(tx, row.id), effects: [] };
    });
  }

  // ---- Invitations -----------------------------------------------------------------------------

  /** `POST /live/rooms/{roomId}/seat-invites` (host or moderator) → 201. */
  async invite(callerId: string, roomId: string, body: unknown): Promise<LiveSeatInviteDto> {
    const input = parseBody(liveSeatInviteBodySchema, body);
    const row = await this.seatedRoom(roomId, callerId);
    const target = await this.users.findActivePublicUser(input.username);
    return this.change(row.id, async (tx, now) => {
      const room = await this.lockRoom(tx, row.id);
      const privilege = await this.privilege(tx, room, callerId);
      if (!target || (await this.blockedWithHost(tx, room.hostUserId, target.id))) throw notFound();
      if (target.id === room.hostUserId) throw seatUnavailable();
      await this.assertMayActOn(tx, room, callerId, privilege, target.id);
      if ((await this.seatOf(tx, room.id, target.id)) !== null) throw seatUnavailable();
      // Watching now: connected to the room's media session (CP-010 presence).
      const watching = await tx.liveRoomViewer.count({ where: { roomId: room.id, identity: target.id } });
      if (watching === 0) throw seatUnavailable();
      const asked = input.seatIndex ?? null;
      if (asked !== null && asked >= room.seatCount) throw seatUnavailable();
      await this.pickSeat(tx, room, asked, null);
      await tx.liveSeatInvite.updateMany({
        where: { roomId: room.id, userId: target.id, status: 'PENDING' },
        data: { status: 'REPLACED', handledAt: now },
      });
      const created = await tx.liveSeatInvite.create({
        data: {
          roomId: room.id,
          userId: target.id,
          seatIndex: asked,
          invitedById: callerId,
          createdAt: now,
          expiresAt: new Date(now.getTime() + SEAT_INVITE_TTL_SECONDS * 1000),
        },
        include: { user: { select: USER_SUMMARY_SELECT }, invitedBy: { select: USER_SUMMARY_SELECT } },
      });
      return {
        result: inviteDto(created),
        version: await this.bump(tx, room.id),
        effects: [
          {
            kind: 'data',
            identity: target.id,
            payload: JSON.stringify({ type: 'seat-invite', roomId: room.id }),
          },
        ],
      };
    });
  }

  /** `POST /live/rooms/{roomId}/seat-invites/me/accept`. */
  async acceptInvite(callerId: string, roomId: string, lang: ContentLanguage): Promise<LiveSeatsDto> {
    const row = await this.seatedRoom(roomId, callerId);
    await this.change(row.id, async (tx, now) => {
      const room = await this.lockRoom(tx, row.id);
      const invite = await tx.liveSeatInvite.findFirst({
        where: { roomId: room.id, userId: callerId, status: 'PENDING' },
      });
      if (!invite) throw notPending();
      if (invite.expiresAt.getTime() <= now.getTime()) {
        await tx.liveSeatInvite.update({
          where: { id: invite.id },
          data: { status: 'EXPIRED', handledAt: now },
        });
        return { result: undefined, version: null, effects: [], error: notPending() };
      }
      if ((await this.seatOf(tx, room.id, callerId)) !== null) throw seatUnavailable();
      const seatIndex = await this.pickSeat(tx, room, null, invite.seatIndex);
      const effect = await this.seatUserIn(tx, room, callerId, seatIndex, now);
      return { result: undefined, version: await this.bump(tx, room.id), effects: [effect] };
    });
    return this.seatsOf(row.id, callerId, lang);
  }

  /** `POST /live/rooms/{roomId}/seat-invites/me/decline` (idempotent). */
  async declineInvite(callerId: string, roomId: string): Promise<void> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    await this.change(row.id, async (tx, now) => {
      const updated = await tx.liveSeatInvite.updateMany({
        where: { roomId: row.id, userId: callerId, status: 'PENDING' },
        data: { status: 'DECLINED', handledAt: now },
      });
      return {
        result: undefined,
        version: updated.count > 0 ? await this.bump(tx, row.id) : null,
        effects: [],
      };
    });
  }

  // ---- On the seat -----------------------------------------------------------------------------

  /** `POST /live/rooms/{roomId}/seats/me/leave` (idempotent). */
  async leaveSeat(callerId: string, roomId: string): Promise<void> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    await this.change(row.id, async (tx) => {
      await tx.$queryRaw`SELECT id FROM live_rooms WHERE id = ${row.id}::uuid FOR UPDATE`;
      const removed = await tx.liveRoomSeat.deleteMany({ where: { roomId: row.id, userId: callerId } });
      if (removed.count === 0) return { result: undefined, version: null, effects: [] };
      return {
        result: undefined,
        version: await this.bump(tx, row.id),
        effects: [{ kind: 'permission', identity: callerId, permission: VIEWER_PERMISSION }],
      };
    });
  }

  /** The seat at `index` of a locked room (out of range → 409). */
  private async seatAt(tx: Prisma.TransactionClient, room: LockedRoom, index: number) {
    if (index < 1 || index >= room.seatCount) throw seatUnavailable();
    return tx.liveRoomSeat.findUnique({ where: { roomId_seatIndex: { roomId: room.id, seatIndex: index } } });
  }

  /** `POST /live/rooms/{roomId}/seats/{seatIndex}/mute` (host or moderator; idempotent). */
  async mute(
    callerId: string,
    roomId: string,
    rawIndex: string,
    body: unknown,
    lang: ContentLanguage,
  ): Promise<LiveSeatsDto> {
    const input = parseBody(liveSeatMuteBodySchema, body);
    const index = seatIndexOf(rawIndex);
    const row = await this.seatedRoom(roomId, callerId);
    await this.change(row.id, async (tx, now) => {
      const room = await this.lockRoom(tx, row.id);
      const privilege = await this.privilege(tx, room, callerId);
      const seat = await this.seatAt(tx, room, index);
      if (!seat?.userId) throw seatUnavailable();
      await this.assertMayActOn(tx, room, callerId, privilege, seat.userId);
      if (seat.mutedByHost === input.muted) return { result: undefined, version: null, effects: [] };
      await tx.liveRoomSeat.update({
        where: { roomId_seatIndex: { roomId: room.id, seatIndex: index } },
        data: { mutedByHost: input.muted, updatedAt: now },
      });
      return {
        result: undefined,
        version: await this.bump(tx, room.id),
        effects: [
          { kind: 'permission', identity: seat.userId, permission: seatPermission(room.mode, input.muted) },
        ],
      };
    });
    return this.seatsOf(row.id, callerId, lang);
  }

  /** `POST /live/rooms/{roomId}/seats/{seatIndex}/remove` (host or moderator; empty → unchanged). */
  async remove(
    callerId: string,
    roomId: string,
    rawIndex: string,
    lang: ContentLanguage,
  ): Promise<LiveSeatsDto> {
    const index = seatIndexOf(rawIndex);
    const row = await this.seatedRoom(roomId, callerId);
    await this.change(row.id, async (tx) => {
      const room = await this.lockRoom(tx, row.id);
      const privilege = await this.privilege(tx, room, callerId);
      const seat = await this.seatAt(tx, room, index);
      if (!seat?.userId) return { result: undefined, version: null, effects: [] };
      await this.assertMayActOn(tx, room, callerId, privilege, seat.userId);
      await tx.liveRoomSeat.delete({ where: { roomId_seatIndex: { roomId: room.id, seatIndex: index } } });
      return {
        result: undefined,
        version: await this.bump(tx, room.id),
        effects: [{ kind: 'permission', identity: seat.userId, permission: VIEWER_PERMISSION }],
      };
    });
    return this.seatsOf(row.id, callerId, lang);
  }

  /** `POST /live/rooms/{roomId}/seats/{seatIndex}/lock` (host only; an occupied seat → 409). */
  async lock(
    callerId: string,
    roomId: string,
    rawIndex: string,
    body: unknown,
    lang: ContentLanguage,
  ): Promise<LiveSeatsDto> {
    const input = parseBody(liveSeatLockBodySchema, body);
    const index = seatIndexOf(rawIndex);
    const row = await this.seatedRoom(roomId, callerId);
    await this.change(row.id, async (tx, now) => {
      const room = await this.lockRoom(tx, row.id);
      if (callerId !== room.hostUserId) throw forbidden();
      const seat = await this.seatAt(tx, room, index);
      if (seat?.userId) {
        if (input.locked) throw seatUnavailable();
        return { result: undefined, version: null, effects: [] };
      }
      if (input.locked === (seat?.locked ?? false)) return { result: undefined, version: null, effects: [] };
      if (input.locked) {
        await tx.liveRoomSeat.create({
          data: { roomId: room.id, seatIndex: index, locked: true, updatedAt: now },
        });
      } else {
        await tx.liveRoomSeat.delete({ where: { roomId_seatIndex: { roomId: room.id, seatIndex: index } } });
      }
      return { result: undefined, version: await this.bump(tx, room.id), effects: [] };
    });
    return this.seatsOf(row.id, callerId, lang);
  }

  /**
   * `PATCH /live/rooms/{roomId}` with `seatCount` and/or `theme` (the host; checked by the caller).
   * Shrinking below an occupied seat → 409; locked seats beyond the new count are dropped.
   * v1.27.2-live (D135): a real theme change moves the room info version (§10.12) so everyone in
   * the room re-reads it; returns whether it did (the caller writes the metadata).
   */
  async updateSettings(roomId: string, input: { seatCount?: number; theme?: string }): Promise<boolean> {
    return this.change(roomId, async (tx) => {
      let version: number | null = null;
      if (input.seatCount !== undefined) {
        const room = await this.lockRoom(tx, roomId);
        if (input.seatCount !== room.roomSeatCount) {
          const beyond = await tx.liveRoomSeat.count({
            where: { roomId, seatIndex: { gte: input.seatCount }, userId: { not: null } },
          });
          if (beyond > 0) throw seatUnavailable();
          await tx.liveRoomSeat.deleteMany({ where: { roomId, seatIndex: { gte: input.seatCount } } });
          await tx.liveRoom.update({ where: { id: roomId }, data: { seatCount: input.seatCount } });
          version = await this.bump(tx, roomId);
        }
      }
      let themeChanged = false;
      if (input.theme !== undefined) {
        const changed = await tx.liveRoom.updateMany({
          where: { id: roomId, theme: { not: input.theme } },
          data: { theme: input.theme, infoVersion: { increment: 1 } },
        });
        themeChanged = changed.count > 0;
      }
      return { result: themeChanged, version, effects: [] };
    });
  }

  // ---- Cinema (D173) ----------------------------------------------------------------------------

  /**
   * v1.39-live (D173): YouTube together started in an AUDIO room with more than
   * {@link CINEMA_SEAT_COUNT} seats. Everyone on a seat from that index on moves to the first free
   * seat below it (their mic state kept), in seat order; when none is free they leave the seat (the
   * publish permission is withdrawn). Pending requests and invitations for those seats expire.
   * Idempotent: nothing to move → no change. Returns the users who moved (`to`) or left (`to` null).
   */
  async enterCinema(roomId: string): Promise<{ userId: string; from: number; to: number | null }[]> {
    return this.change(roomId, async (tx, now) => {
      const room = await this.lockRoom(tx, roomId);
      if (!room.cinema || room.roomSeatCount <= CINEMA_SEAT_COUNT) {
        return { result: [], version: null, effects: [] };
      }
      const beyond = await tx.liveRoomSeat.findMany({
        where: { roomId, seatIndex: { gte: CINEMA_SEAT_COUNT } },
        orderBy: { seatIndex: 'asc' },
      });
      const stale = await tx.liveSeatRequest.updateMany({
        where: { roomId, status: 'PENDING', seatIndex: { gte: CINEMA_SEAT_COUNT } },
        data: { status: 'EXPIRED', handledAt: now },
      });
      const staleInvites = await tx.liveSeatInvite.updateMany({
        where: { roomId, status: 'PENDING', seatIndex: { gte: CINEMA_SEAT_COUNT } },
        data: { status: 'EXPIRED', handledAt: now },
      });
      if (beyond.length === 0 && stale.count === 0 && staleInvites.count === 0) {
        return { result: [], version: null, effects: [] };
      }
      const free = await this.freeSeats(tx, room);
      const moves: { userId: string; from: number; to: number | null }[] = [];
      const effects: Effect[] = [];
      for (const seat of beyond) {
        await tx.liveRoomSeat.delete({
          where: { roomId_seatIndex: { roomId, seatIndex: seat.seatIndex } },
        });
        if (seat.userId === null) continue; // a locked seat beyond the cinema: dropped
        const to = free.shift();
        if (to === undefined) {
          moves.push({ userId: seat.userId, from: seat.seatIndex, to: null });
          effects.push({ kind: 'permission', identity: seat.userId, permission: VIEWER_PERMISSION });
          continue;
        }
        await tx.liveRoomSeat.create({
          data: {
            roomId,
            seatIndex: to,
            userId: seat.userId,
            locked: false,
            mutedByHost: seat.mutedByHost,
            updatedAt: now,
          },
        });
        moves.push({ userId: seat.userId, from: seat.seatIndex, to });
      }
      return { result: moves, version: await this.bump(tx, roomId), effects };
    });
  }

  /**
   * v1.39-live (D173): YouTube together stopped — the room's own seat count is usable again (nobody
   * is moved back). A new seat version tells the apps to refetch.
   */
  async leaveCinema(roomId: string): Promise<void> {
    await this.change(roomId, async (tx) => {
      const room = await this.lockRoom(tx, roomId);
      if (room.mode !== 'AUDIO' || room.roomSeatCount <= CINEMA_SEAT_COUNT) {
        return { result: undefined, version: null, effects: [] };
      }
      return { result: undefined, version: await this.bump(tx, roomId), effects: [] };
    });
  }

  // ---- Moderators ------------------------------------------------------------------------------

  /** `PUT /live/rooms/{roomId}/moderators/{username}` (host only; up to 5; idempotent). */
  async addModerator(
    callerId: string,
    roomId: string,
    username: string,
    lang: ContentLanguage,
  ): Promise<LiveSeatsDto> {
    const row = await this.seatedRoom(roomId, callerId);
    const target = await this.users.findActivePublicUser(username);
    await this.change(row.id, async (tx, now) => {
      const room = await this.lockRoom(tx, row.id);
      if (callerId !== room.hostUserId) throw forbidden();
      if (!target || (await this.blockedWithHost(tx, room.hostUserId, target.id))) throw notFound();
      if (target.id === room.hostUserId) {
        throw new UnprocessableValidation([{ field: 'username', issue: 'invalid_value' }]);
      }
      if (await this.isModerator(tx, room.id, target.id))
        return { result: undefined, version: null, effects: [] };
      // v1.20-live (D105, §10.20): someone kicked out of this live cannot moderate it.
      if ((await tx.liveRoomKick.count({ where: { roomId: room.id, userId: target.id } })) > 0) {
        throw new UnprocessableValidation([{ field: 'username', issue: 'invalid_value' }]);
      }
      if ((await tx.liveRoomModerator.count({ where: { roomId: room.id } })) >= MAX_ROOM_MODERATORS) {
        throw new UnprocessableValidation([{ field: 'moderators', issue: 'too_many' }]);
      }
      await tx.liveRoomModerator.create({ data: { roomId: room.id, userId: target.id, addedAt: now } });
      return { result: undefined, version: await this.bump(tx, room.id), effects: [] };
    });
    return this.seatsOf(row.id, callerId, lang);
  }

  /** `DELETE /live/rooms/{roomId}/moderators/{username}` (host only; idempotent). */
  async removeModerator(
    callerId: string,
    roomId: string,
    username: string,
    lang: ContentLanguage,
  ): Promise<LiveSeatsDto> {
    const row = await this.seatedRoom(roomId, callerId);
    const target = await this.users.findActivePublicUser(username);
    await this.change(row.id, async (tx) => {
      const room = await this.lockRoom(tx, row.id);
      if (callerId !== room.hostUserId) throw forbidden();
      if (!target) throw notFound();
      const removed = await tx.liveRoomModerator.deleteMany({
        where: { roomId: room.id, userId: target.id },
      });
      return {
        result: undefined,
        version: removed.count > 0 ? await this.bump(tx, room.id) : null,
        effects: [],
      };
    });
    return this.seatsOf(row.id, callerId, lang);
  }

  // ---- Losing a seat (presence, blocks) and media ------------------------------------------------

  /** Media effects of {@link releaseUserIn}: withdraw publishing, push the versions. */
  async afterRelease(userId: string, released: readonly ReleasedUser[]): Promise<void> {
    for (const r of released) {
      await this.applyEffects(
        r.roomId,
        r.version,
        r.wasSeated ? [{ kind: 'permission', identity: userId, permission: VIEWER_PERMISSION }] : [],
      );
    }
  }

  /**
   * A user left the room's media session (webhook or reconciliation): they lose their seat, their
   * pending request and their invitation (§10.9). Cheap when they had none.
   */
  async onLeft(roomId: string, userId: string): Promise<void> {
    const [has] = await this.prisma.$queryRaw<{ ok: boolean }[]>`
      SELECT (EXISTS (SELECT 1 FROM live_room_seats WHERE room_id = ${roomId}::uuid AND user_id = ${userId}::uuid)
           OR EXISTS (SELECT 1 FROM live_seat_requests
                       WHERE room_id = ${roomId}::uuid AND user_id = ${userId}::uuid AND status = 'PENDING')
           OR EXISTS (SELECT 1 FROM live_seat_invites
                       WHERE room_id = ${roomId}::uuid AND user_id = ${userId}::uuid AND status = 'PENDING')) AS ok`;
    if (!has?.ok) return;
    const released = await this.prisma.$transaction(
      (tx) => releaseUserIn(tx, userId, this.clock.now(), { roomScope: Prisma.sql`r.id = ${roomId}::uuid` }),
      LIVE_TX_OPTIONS,
    );
    await this.afterRelease(userId, released);
  }

  /**
   * A block between two users (either way): in each one's LIVE room, the other loses their seat,
   * request, invitation and moderator role (§10.9).
   */
  async onBlock(a: string, b: string): Promise<void> {
    for (const [hostId, userId] of [
      [a, b],
      [b, a],
    ] as const) {
      const released = await this.prisma.$transaction(
        (tx) =>
          releaseUserIn(tx, userId, this.clock.now(), {
            roomScope: Prisma.sql`r.host_user_id = ${hostId}::uuid`,
            moderator: true,
          }),
        LIVE_TX_OPTIONS,
      );
      await this.afterRelease(userId, released);
    }
  }

  /**
   * A user joined the media session: if they hold a seat (e.g. they rejoined with a token issued
   * before they were seated), their seat's permission is applied at once.
   */
  async onJoined(roomId: string, userId: string): Promise<void> {
    const seat = await this.prisma.liveRoomSeat.findFirst({
      where: { roomId, userId },
      select: { mutedByHost: true, room: { select: { mode: true } } },
    });
    if (!seat || !hasGuestSeats(seat.room.mode)) return;
    await this.applyEffects(roomId, null, [
      { kind: 'permission', identity: userId, permission: seatPermission(seat.room.mode, seat.mutedByHost) },
    ]);
  }

  /** The publish permission a joined user should have in a room now (media token, CP-011). */
  async seatOfUser(roomId: string, userId: string): Promise<{ mutedByHost: boolean } | null> {
    const seat = await this.prisma.liveRoomSeat.findFirst({
      where: { roomId, userId },
      select: { mutedByHost: true },
    });
    return seat;
  }

  /** Sweeper: pending invitations past their 60 seconds become EXPIRED (they already read as none). */
  async expireInvites(): Promise<number> {
    const now = this.clock.now();
    const updated = await this.prisma.liveSeatInvite.updateMany({
      where: { status: 'PENDING', expiresAt: { lte: now } },
      data: { status: 'EXPIRED', handledAt: now },
    });
    return updated.count;
  }

  /**
   * Reconciliation of one LIVE room with seats (§10.9): every connected participant other than the
   * host gets the permission its seat implies (repairing a failed or missed change), and the room
   * metadata carries the current version. Returns the number of repairs.
   */
  async reconcileRoom(roomId: string): Promise<number> {
    const room = await this.prisma.liveRoom.findUnique({
      where: { id: roomId },
      select: { mode: true, status: true, hostUserId: true },
    });
    if (!room || room.status !== 'LIVE') return 0;
    if (!hasGuestSeats(room.mode)) return this.reconcileMetadata(roomId, false);
    const mode = room.mode;
    const seats = new Map(
      (
        await this.prisma.liveRoomSeat.findMany({
          where: { roomId, userId: { not: null } },
          select: { userId: true, mutedByHost: true },
        })
      ).map((s) => [s.userId!, s.mutedByHost]),
    );
    let repairs = 0;
    for (const participant of await this.media.listParticipants(roomId)) {
      if (participant.identity === room.hostUserId) continue;
      const muted = seats.get(participant.identity);
      const want = muted === undefined ? VIEWER_PERMISSION : seatPermission(mode, muted);
      if (samePermission(participant.permission, want)) continue;
      await this.media.setPermission(roomId, participant.identity, want);
      repairs += 1;
    }
    return repairs + (await this.reconcileMetadata(roomId, true));
  }

  /**
   * The room metadata carries the current seat version, score and info version (CP-011, CP-012,
   * CP-014). A room without seats that nobody has tapped and the host never edited needs none.
   * Returns 1 when it was repaired.
   */
  private async reconcileMetadata(roomId: string, seated: boolean): Promise<number> {
    const expected = await this.metadata.expected(roomId);
    if (!expected) return 0;
    const current = await this.media.roomMetadata(roomId);
    if (current === null || current === expected.json) return 0;
    if (!seated && current === '' && expected.score === 0 && expected.roomInfoVersion === 0) return 0;
    await this.media.setRoomMetadata(roomId, expected.json);
    return 1;
  }
}

function samePermission(a: LiveMediaPermission, b: LiveMediaPermission): boolean {
  return a.visible === b.visible && [...a.sources].sort().join(',') === [...b.sources].sort().join(',');
}

function requestDto(row: {
  id: string;
  seatIndex: number | null;
  createdAt: Date;
  user: { id: string; profile: { username: string; displayName: string; avatarUrl: string | null } | null };
}): LiveSeatRequestDto {
  return {
    id: row.id,
    user: userSummary(row.user),
    seatIndex: row.seatIndex,
    createdAt: row.createdAt.toISOString(),
  };
}

function inviteDto(row: {
  id: string;
  seatIndex: number | null;
  expiresAt: Date;
  user: { id: string; profile: { username: string; displayName: string; avatarUrl: string | null } | null };
  invitedBy: {
    id: string;
    profile: { username: string; displayName: string; avatarUrl: string | null } | null;
  };
}): LiveSeatInviteDto {
  return {
    id: row.id,
    user: userSummary(row.user),
    seatIndex: row.seatIndex,
    invitedBy: userSummary(row.invitedBy),
    expiresAt: row.expiresAt.toISOString(),
  };
}
