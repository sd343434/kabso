import { randomInt, randomUUID } from 'node:crypto';
import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import {
  dueAt,
  lobbyState,
  LUDO_COLORS,
  LUDO_TURN_MS,
  LudoRuleError,
  markAway,
  markBack,
  move,
  movable,
  piecesOf,
  roll,
  setAuto,
  startGame,
  timeout,
  type LudoColor,
  type LudoEvent,
  type LudoMode,
  type LudoPhase,
  type LudoState,
} from './live-ludo.js';
import { LiveRoomsService, type UserSummaryDto } from './live-rooms.service.js';
import { LIVE_MEDIA_PROVIDER, type LiveMediaProvider } from './media/live-media.provider.js';

/** The media data topic of Ludo messages. */
export const LUDO_TOPIC = 'ludo';
/** Games the timer scan handles per round. */
const TICK_BATCH = 50;

/** The die (D168): the server's cryptographic RNG; tests replace it to script rolls. */
export interface LudoDice {
  roll(): number;
}
export const LUDO_DICE = Symbol('LUDO_DICE');
export const cryptoDice: LudoDice = { roll: () => randomInt(1, 7) };

export type LudoStatus = 'LOBBY' | 'PLAYING' | 'FINISHED' | 'ENDED';

/** `LiveLudoSeat` (v1.45-live, D168, CONVENTIONS §10.42). */
export interface LiveLudoSeatDto {
  seat: number;
  color: LudoColor;
  user: UserSummaryDto | null;
  /** The server plays this seat (its player left or was away 30 s). */
  auto: boolean;
  pieces: number[];
}

/** `LiveLudoGame`: the whole game as everyone in the room sees it. */
export interface LiveLudoGameDto {
  id: string;
  roomId: string;
  status: LudoStatus;
  mode: LudoMode;
  maxPlayers: number;
  piecesPerPlayer: number;
  version: number;
  seats: LiveLudoSeatDto[];
  turn: number | null;
  phase: LudoPhase | null;
  dice: number | null;
  sixes: number;
  movable: number[];
  turnEndsAt: string | null;
  turnSeconds: number;
  winner: number | null;
  events: LudoEvent[];
  serverTime: string;
  createdAt: string;
  startedAt: string | null;
  endedAt: string | null;
}

type GameRow = {
  id: string;
  roomId: string;
  status: string;
  mode: string;
  maxPlayers: number;
  state: Prisma.JsonValue;
  version: number;
  createdAt: Date;
  startedAt: Date | null;
  endedAt: Date | null;
};

const createSchema = z.strictObject({
  mode: z.enum(['CLASSIC', 'QUICK']),
  players: z.union([z.literal(2), z.literal(4)]),
});
const versionSchema = z.strictObject({ version: z.number().int().min(0) });
const moveSchema = z.strictObject({
  version: z.number().int().min(0),
  piece: z.number().int().min(0).max(3),
});
const seatParam = z.coerce.number().int().min(0).max(3);

const OPEN: LudoStatus[] = ['LOBBY', 'PLAYING'];

/**
 * Ludo «لودو» inside a live room (D168, CONVENTIONS §10.42). The host opens one game per room; people
 * in the room take a free seat (up to 4) or watch; the host starts it (≥ 2 seated) and may end it.
 * The server is the single source of truth: it rolls the die (crypto RNG), checks every intent against
 * the rules ({@link roll}, {@link move}), runs the 15 s turn timers and the 30 s away rule on its own
 * timer, and tells the room every change (`{"type":"ludo","game":LiveLudoGame}` on topic `ludo`).
 * Apps only send intents with the `version` they saw; an intent on an older version changes nothing
 * (409 LUDO_STALE_VERSION), and every write is a compare-and-set on `version`, so concurrent intents
 * and the timer apply at most once. Completely free: no coins, no stakes, no rewards.
 */
@Injectable()
export class LiveLudoService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(LiveLudoService.name);
  private timer: NodeJS.Timeout | undefined;
  private ticking = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly rooms: LiveRoomsService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(LIVE_MEDIA_PROVIDER) private readonly media: LiveMediaProvider,
    @Inject(LUDO_DICE) private readonly dice: LudoDice,
  ) {}

  onModuleInit(): void {
    const ms = this.config.live.ludoTickMs;
    if (ms > 0) {
      this.timer = setInterval(() => {
        if (this.ticking) return;
        this.ticking = true;
        this.tick()
          .catch((err: unknown) => this.logger.warn({ error: safeErrorLog(err) }, 'Ludo timers failed'))
          .finally(() => (this.ticking = false));
      }, ms);
      this.timer.unref();
    }
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }

  // ---- Reading ---------------------------------------------------------------------------------

  private stateOf(row: GameRow): LudoState {
    return row.state as unknown as LudoState;
  }

  private async dto(row: GameRow): Promise<LiveLudoGameDto> {
    const state = this.stateOf(row);
    const ids = state.seats.map((s) => s.userId).filter((id): id is string => id !== null);
    const users = ids.length
      ? await this.prisma.user.findMany({ where: { id: { in: ids } }, select: USER_SUMMARY_SELECT })
      : [];
    const byId = new Map(users.map((u) => [u.id, userSummary(u)]));
    const playing = row.status === 'PLAYING';
    return {
      id: row.id,
      roomId: row.roomId,
      status: row.status as LudoStatus,
      mode: row.mode as LudoMode,
      maxPlayers: row.maxPlayers,
      piecesPerPlayer: piecesOf(row.mode as LudoMode),
      version: row.version,
      seats: state.seats.map((s) => ({
        seat: s.seat,
        color: LUDO_COLORS[s.seat]!,
        user: s.userId === null ? null : (byId.get(s.userId) ?? null),
        auto: s.auto !== null,
        pieces: [...s.pieces],
      })),
      turn: playing ? state.turn : null,
      phase: playing ? state.phase : null,
      dice: state.dice,
      sixes: playing ? state.sixes : 0,
      movable: playing ? movable(state) : [],
      turnEndsAt: playing ? state.turnEndsAt : null,
      turnSeconds: LUDO_TURN_MS / 1000,
      winner: state.winner,
      events: [...state.events],
      serverTime: this.clock.now().toISOString(),
      createdAt: row.createdAt.toISOString(),
      startedAt: row.startedAt?.toISOString() ?? null,
      endedAt: row.endedAt?.toISOString() ?? null,
    };
  }

  private openGame(roomId: string): Promise<GameRow | null> {
    return this.prisma.liveLudoGame.findFirst({ where: { roomId, status: { in: OPEN } } });
  }

  /**
   * `GET /live/rooms/{roomId}/ludo`: the room's game in its lobby or playing, else null (anyone who
   * can see the room, guests too: spectators and late joiners get the whole state).
   */
  async get(callerId: string | null, roomId: string): Promise<{ game: LiveLudoGameDto | null }> {
    const room = await this.rooms.visibleRow(roomId, callerId);
    if (room.status !== 'LIVE') return { game: null };
    const row = await this.openGame(room.id);
    return { game: row ? await this.dto(row) : null };
  }

  // ---- Checks ----------------------------------------------------------------------------------

  /** The visible LIVE room; 404 / 409 LIVE_ROOM_ENDED otherwise. */
  private async liveRoom(callerId: string, roomId: string) {
    const room = await this.rooms.visibleRow(roomId, callerId);
    if (room.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    return room;
  }

  /** The host, or someone in the room's media session now (403 LUDO_NOT_IN_ROOM otherwise). */
  private async assertInRoom(roomId: string, hostId: string, userId: string): Promise<void> {
    if (userId === hostId) return;
    const present = await this.prisma.liveRoomViewer.findFirst({
      where: { roomId, userId },
      select: { identity: true },
    });
    if (!present) throw new AppException(ErrorCode.LUDO_NOT_IN_ROOM);
  }

  private async requireOpen(roomId: string): Promise<GameRow> {
    const row = await this.openGame(roomId);
    if (!row) throw new AppException(ErrorCode.NOT_FOUND);
    return row;
  }

  private parse<T>(schema: z.ZodType<T>, body: unknown): T {
    const parsed = schema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    return parsed.data;
  }

  // ---- Writing ---------------------------------------------------------------------------------

  /**
   * Compare-and-set: writes [next] only if the row is still at [row.version] (else null). The timer's
   * due time follows the new state.
   */
  private async save(
    row: GameRow,
    next: LudoState,
    extra: { status?: LudoStatus; winnerUserId?: string | null; startedAt?: Date; endedAt?: Date } = {},
  ): Promise<GameRow | null> {
    const status = extra.status ?? (row.status as LudoStatus);
    const saved = await this.prisma.liveLudoGame.updateManyAndReturn({
      where: { id: row.id, version: row.version, status: row.status },
      data: {
        ...extra,
        state: next as unknown as Prisma.InputJsonValue,
        version: row.version + 1,
        dueAt: status === 'PLAYING' ? dueAtDate(next) : null,
        updatedAt: this.clock.now(),
      },
    });
    return saved[0] ?? null;
  }

  private async broadcast(row: GameRow): Promise<LiveLudoGameDto> {
    const game = await this.dto(row);
    try {
      await this.media.broadcastData(row.roomId, LUDO_TOPIC, JSON.stringify({ type: 'ludo', game }));
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not send a Ludo data message to the media room');
    }
    return game;
  }

  /** Applies a player's intent at the [version] the app saw: 409 LUDO_STALE_VERSION when it moved on. */
  private async intent(
    row: GameRow,
    version: number,
    apply: (state: LudoState) => LudoState,
  ): Promise<LiveLudoGameDto> {
    if (row.version !== version) throw new AppException(ErrorCode.LUDO_STALE_VERSION);
    let next: LudoState;
    try {
      next = apply(this.stateOf(row));
    } catch (err) {
      if (err instanceof LudoRuleError) throw ruleError(err);
      throw err;
    }
    const saved = await this.save(row, next, this.finishFields(next));
    if (!saved) throw new AppException(ErrorCode.LUDO_STALE_VERSION);
    return this.broadcast(saved);
  }

  /** A won game is FINISHED with its winner. */
  private finishFields(state: LudoState): {
    status?: LudoStatus;
    winnerUserId?: string | null;
    endedAt?: Date;
  } {
    if (state.winner === null) return {};
    const winner = state.seats.find((s) => s.seat === state.winner);
    return { status: 'FINISHED', winnerUserId: winner?.userId ?? null, endedAt: this.clock.now() };
  }

  /**
   * `POST /live/rooms/{roomId}/ludo` `{mode, players}`: the host opens a game in its lobby (one per
   * room: 409 LUDO_GAME_EXISTS). 404 / 403 (not the host) / 409 LIVE_ROOM_ENDED / 400.
   */
  async create(callerId: string, roomId: string, body: unknown): Promise<LiveLudoGameDto> {
    const room = await this.liveRoom(callerId, roomId);
    if (room.host_user_id !== callerId) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    const { mode, players } = this.parse(createSchema, body);
    if (await this.openGame(room.id)) throw new AppException(ErrorCode.LUDO_GAME_EXISTS);
    let row: GameRow;
    try {
      row = await this.prisma.liveLudoGame.create({
        data: {
          id: randomUUID(),
          roomId: room.id,
          status: 'LOBBY',
          mode,
          maxPlayers: players,
          state: lobbyState(players) as unknown as Prisma.InputJsonValue,
          createdAt: this.clock.now(),
          updatedAt: this.clock.now(),
        },
      });
    } catch (err) {
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
        throw new AppException(ErrorCode.LUDO_GAME_EXISTS);
      }
      throw err;
    }
    return this.broadcast(row);
  }

  /**
   * `PUT /live/rooms/{roomId}/ludo/seats/{seat}`: the caller (in the room) takes a free seat of the
   * lobby; one seat per person. 409 LUDO_SEAT_UNAVAILABLE otherwise.
   */
  async takeSeat(callerId: string, roomId: string, seatRaw: string): Promise<LiveLudoGameDto> {
    const room = await this.liveRoom(callerId, roomId);
    await this.assertInRoom(room.id, room.host_user_id, callerId);
    const seat = seatParam.safeParse(seatRaw);
    const row = await this.requireOpen(room.id);
    const state = this.stateOf(row);
    const target = seat.success ? state.seats.find((s) => s.seat === seat.data) : undefined;
    if (
      row.status !== 'LOBBY' ||
      !target ||
      target.userId !== null ||
      state.seats.some((s) => s.userId === callerId)
    ) {
      throw new AppException(ErrorCode.LUDO_SEAT_UNAVAILABLE);
    }
    const next: LudoState = {
      ...state,
      seats: state.seats.map((s) => (s === target ? { ...s, userId: callerId } : s)),
      events: [],
    };
    const saved = await this.save(row, next);
    if (!saved) throw new AppException(ErrorCode.LUDO_SEAT_UNAVAILABLE);
    return this.broadcast(saved);
  }

  /**
   * `DELETE /live/rooms/{roomId}/ludo/seats/{seat}`: the seat's player leaves, or the host removes
   * them. In the lobby the seat is free again; in a game the seat becomes AUTO (the server plays it to
   * the end). 404 when no game or nobody sits there; 403 when neither the player nor the host.
   */
  async leaveSeat(callerId: string, roomId: string, seatRaw: string): Promise<LiveLudoGameDto> {
    const room = await this.liveRoom(callerId, roomId);
    const seat = seatParam.safeParse(seatRaw);
    const row = await this.requireOpen(room.id);
    const state = this.stateOf(row);
    const target = seat.success ? state.seats.find((s) => s.seat === seat.data) : undefined;
    if (!target || target.userId === null) throw new AppException(ErrorCode.NOT_FOUND);
    if (target.userId !== callerId && room.host_user_id !== callerId) {
      throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    }
    const now = this.clock.now();
    const next: LudoState =
      row.status === 'LOBBY'
        ? { ...state, seats: state.seats.map((s) => (s === target ? { ...s, userId: null } : s)), events: [] }
        : setAuto(state, target.seat, 'LEFT', now);
    const saved = await this.save(row, next);
    if (!saved) throw new AppException(ErrorCode.LUDO_STALE_VERSION);
    return this.broadcast(saved);
  }

  /** `POST /live/rooms/{roomId}/ludo/start` `{version}`: the host starts the lobby (≥ 2 seated). */
  async start(callerId: string, roomId: string, body: unknown): Promise<LiveLudoGameDto> {
    const room = await this.liveRoom(callerId, roomId);
    if (room.host_user_id !== callerId) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    const { version } = this.parse(versionSchema, body);
    const row = await this.requireOpen(room.id);
    if (row.status !== 'LOBBY') throw new AppException(ErrorCode.LUDO_NOT_STARTABLE);
    if (row.version !== version) throw new AppException(ErrorCode.LUDO_STALE_VERSION);
    let next: LudoState;
    try {
      next = startGame(this.stateOf(row), row.mode as LudoMode, this.clock.now());
    } catch (err) {
      if (err instanceof LudoRuleError) throw ruleError(err);
      throw err;
    }
    const saved = await this.save(row, next, { status: 'PLAYING', startedAt: this.clock.now() });
    if (!saved) throw new AppException(ErrorCode.LUDO_STALE_VERSION);
    return this.broadcast(saved);
  }

  /** The playing game and the caller's seat for a roll or a move. */
  private async turnOf(callerId: string, roomId: string): Promise<{ row: GameRow; seat: number }> {
    const room = await this.liveRoom(callerId, roomId);
    await this.assertInRoom(room.id, room.host_user_id, callerId);
    const row = await this.requireOpen(room.id);
    if (row.status !== 'PLAYING') throw new AppException(ErrorCode.LUDO_NOT_YOUR_TURN);
    const mine = this.stateOf(row).seats.find((s) => s.userId === callerId && s.auto !== 'LEFT');
    if (!mine) throw new AppException(ErrorCode.LUDO_NOT_YOUR_TURN);
    return { row, seat: mine.seat };
  }

  /** `POST /live/rooms/{roomId}/ludo/roll` `{version}`: the player whose turn it is rolls (server die). */
  async roll(callerId: string, roomId: string, body: unknown): Promise<LiveLudoGameDto> {
    const { version } = this.parse(versionSchema, body);
    const { row, seat } = await this.turnOf(callerId, roomId);
    const dice = this.dice.roll();
    // A player back at their phone takes their seat back (AUTO after a disconnect ends).
    return this.intent(row, version, (s) =>
      roll(backIfAway(s, seat, this.clock.now()), seat, dice, this.clock.now()),
    );
  }

  /** `POST /live/rooms/{roomId}/ludo/move` `{version, piece}`: the player moves one of their pieces. */
  async move(callerId: string, roomId: string, body: unknown): Promise<LiveLudoGameDto> {
    const { version, piece } = this.parse(moveSchema, body);
    const { row, seat } = await this.turnOf(callerId, roomId);
    return this.intent(row, version, (s) =>
      move(backIfAway(s, seat, this.clock.now()), seat, piece, this.clock.now()),
    );
  }

  /** `POST /live/rooms/{roomId}/ludo/end`: the host ends the room's game (lobby or playing). */
  async end(callerId: string, roomId: string): Promise<LiveLudoGameDto> {
    const room = await this.liveRoom(callerId, roomId);
    if (room.host_user_id !== callerId) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    const row = await this.requireOpen(room.id);
    const state = this.stateOf(row);
    const saved = await this.save(
      row,
      { ...state, events: [{ kind: 'END' }] },
      {
        status: 'ENDED',
        endedAt: this.clock.now(),
      },
    );
    if (!saved) throw new AppException(ErrorCode.LUDO_STALE_VERSION);
    return this.broadcast(saved);
  }

  // ---- Presence (media webhooks) ---------------------------------------------------------------

  /** [userId] left the room's media session: a lobby seat is freed; a player starts the 30 s count. */
  async onLeft(roomId: string, userId: string): Promise<void> {
    await this.presence(roomId, userId, (row, state, seat) =>
      row.status === 'LOBBY'
        ? {
            ...state,
            seats: state.seats.map((s) => (s.seat === seat ? { ...s, userId: null } : s)),
            events: [],
          }
        : markAway(state, seat, this.clock.now()),
    );
  }

  /** [userId] is in the room's media session again: an away player keeps (or gets back) their seat. */
  async onJoined(roomId: string, userId: string): Promise<void> {
    await this.presence(roomId, userId, (row, state, seat) =>
      row.status === 'PLAYING' ? markBack(state, seat, this.clock.now()) : null,
    );
  }

  private async presence(
    roomId: string,
    userId: string,
    change: (row: GameRow, state: LudoState, seat: number) => LudoState | null,
  ): Promise<void> {
    try {
      for (let attempt = 0; attempt < 3; attempt += 1) {
        const row = await this.openGame(roomId);
        if (!row) return;
        const state = this.stateOf(row);
        const mine = state.seats.find((s) => s.userId === userId);
        if (!mine) return;
        const next = change(row, state, mine.seat);
        if (next === null || JSON.stringify(next.seats) === JSON.stringify(state.seats)) return;
        const saved = await this.save(row, next);
        if (saved) {
          await this.broadcast(saved);
          return;
        }
      }
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Ludo presence update failed');
    }
  }

  // ---- Timers ----------------------------------------------------------------------------------

  /**
   * The server's timer (every `LIVE_LUDO_TICK_MS`): ends the open games of rooms that are no longer
   * LIVE, then plays every due turn (a timeout's roll or best move, an AUTO seat's turn, an away player
   * becoming AUTO). Safe on several instances (compare-and-set). Returns the games changed.
   */
  async tick(): Promise<number> {
    const now = this.clock.now();
    await this.prisma.$executeRaw`
      UPDATE live_ludo_games g
         SET status = 'ENDED', ended_at = ${now.toISOString()}::timestamptz, due_at = NULL,
             version = g.version + 1, updated_at = ${now.toISOString()}::timestamptz
        FROM live_rooms r
       WHERE r.id = g.room_id AND r.status <> 'LIVE' AND g.status IN ('LOBBY', 'PLAYING')`;
    const due = await this.prisma.liveLudoGame.findMany({
      where: { status: 'PLAYING', dueAt: { lte: now } },
      orderBy: { dueAt: 'asc' },
      take: TICK_BATCH,
    });
    let changed = 0;
    for (const row of due) {
      try {
        const next = timeout(this.stateOf(row), now, () => this.dice.roll());
        if (next === null) {
          // Nothing to do yet (a stale due time): re-arm it without changing the game.
          await this.prisma.liveLudoGame.updateMany({
            where: { id: row.id, version: row.version },
            data: { dueAt: dueAtDate(this.stateOf(row)) },
          });
          continue;
        }
        const saved = await this.save(row, next, this.finishFields(next));
        if (saved) {
          changed += 1;
          await this.broadcast(saved);
        }
      } catch (err) {
        this.logger.warn({ error: safeErrorLog(err) }, 'A Ludo turn timer failed');
      }
    }
    return changed;
  }
}

function dueAtDate(state: LudoState): Date | null {
  const at = dueAt(state);
  return at === null ? null : new Date(at);
}

/** A player acting again is back: a disconnect AUTO on their seat ends (leaving stays final). */
function backIfAway(state: LudoState, seat: number, now: Date): LudoState {
  const mine = state.seats.find((s) => s.seat === seat);
  return mine && (mine.auto === 'DISCONNECTED' || mine.awaySince !== null)
    ? markBack(state, seat, now)
    : state;
}

function ruleError(err: LudoRuleError): AppException {
  switch (err.reason) {
    case 'ILLEGAL_MOVE':
      return new AppException(ErrorCode.LUDO_ILLEGAL_MOVE);
    case 'NOT_STARTABLE':
      return new AppException(ErrorCode.LUDO_NOT_STARTABLE);
    default:
      return new AppException(ErrorCode.LUDO_NOT_YOUR_TURN);
  }
}
