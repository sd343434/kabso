/**
 * Live Ludo «لودو» rules (D168, CONVENTIONS §10.42): pure functions over a game's state, the single
 * source of truth the server applies. The board, the rules and the AUTO heuristic are those of the
 * owner-approved prototype: 4 pieces (classic) or 2 (quick); 52 track squares, then 5 home squares,
 * then the centre (57); a 6 leaves the base and gives another turn; landing on an opponent outside a
 * safe square sends it home and gives another turn; reaching the centre gives another turn; a third
 * 6 in a row ends the turn; the exact roll is needed to finish; the first to bring every piece home
 * wins. Free: no coins, no stakes, no rewards.
 */

/** Seat colours, seat 0 … 3 (red top-left, green top-right, yellow bottom-right, blue bottom-left). */
export const LUDO_COLORS = ['RED', 'GREEN', 'YELLOW', 'BLUE'] as const;
export type LudoColor = (typeof LUDO_COLORS)[number];

/** Each colour's start square on the shared 52-square track (its piece's step 0). */
export const LUDO_START: readonly number[] = [0, 13, 26, 39];
/** Track squares where nobody can be captured (the starts and the stars). */
export const LUDO_SAFE: ReadonlySet<number> = new Set([0, 8, 13, 21, 26, 34, 39, 47]);
export const LUDO_TRACK = 52;
/** A piece's step: -1 in the base, 0 … 51 on the track, 52 … 56 on its home column, 57 home. */
export const LUDO_BASE = -1;
export const LUDO_LAST_TRACK_STEP = 51;
export const LUDO_FINISH = 57;

/** A player's turn (each phase: rolling, then choosing a piece). */
export const LUDO_TURN_MS = 15_000;
/** An AUTO seat plays this long after its turn starts (clients animate meanwhile). */
export const LUDO_AUTO_MS = 1_500;
/** A seated player away from the room's media session this long becomes AUTO. */
export const LUDO_DISCONNECT_MS = 30_000;
/** The seats a game of 2 uses (opposite corners, as the prototype). */
export const LUDO_SEATS_OF_TWO: readonly number[] = [0, 2];

export type LudoMode = 'CLASSIC' | 'QUICK';
export type LudoPhase = 'ROLL' | 'MOVE';
/** Why a seat is played by the server: its player left the game, or was away too long. */
export type LudoAutoReason = 'LEFT' | 'DISCONNECTED';

export interface LudoSeat {
  readonly seat: number;
  readonly userId: string | null;
  readonly auto: LudoAutoReason | null;
  /** While not AUTO: when the player left the media session (ISO), else null. */
  readonly awaySince: string | null;
  readonly pieces: readonly number[];
}

export interface LudoCapture {
  readonly seat: number;
  readonly piece: number;
  readonly from: number;
}

/** What one transition did, in order (clients animate them). */
export type LudoEvent =
  | { readonly kind: 'START' }
  | { readonly kind: 'ROLL'; readonly seat: number; readonly dice: number; readonly auto: boolean }
  | {
      readonly kind: 'MOVE';
      readonly seat: number;
      readonly piece: number;
      readonly from: number;
      readonly to: number;
      readonly dice: number;
      readonly captured: readonly LudoCapture[];
      readonly reached: boolean;
      readonly auto: boolean;
    }
  | { readonly kind: 'NO_MOVE'; readonly seat: number; readonly dice: number }
  | { readonly kind: 'THREE_SIXES'; readonly seat: number }
  | { readonly kind: 'AUTO'; readonly seat: number; readonly reason: LudoAutoReason }
  | { readonly kind: 'BACK'; readonly seat: number }
  | { readonly kind: 'WIN'; readonly seat: number }
  | { readonly kind: 'END' };

export interface LudoState {
  /** The seats in play (in a lobby: the open seats, some empty). */
  readonly seats: readonly LudoSeat[];
  readonly turn: number | null;
  readonly phase: LudoPhase | null;
  readonly dice: number | null;
  /** Sixes rolled in a row in this turn (the three tabs by the base). */
  readonly sixes: number;
  readonly turnEndsAt: string | null;
  readonly winner: number | null;
  /** What the last transition did. */
  readonly events: readonly LudoEvent[];
}

export class LudoRuleError extends Error {
  constructor(readonly reason: 'NOT_YOUR_TURN' | 'ILLEGAL_MOVE' | 'NOT_STARTABLE') {
    super(reason);
  }
}

export const piecesOf = (mode: LudoMode): number => (mode === 'QUICK' ? 2 : 4);

/** The open seats of a game of [players] (2 or 4). */
export const openSeats = (players: number): readonly number[] =>
  players === 2 ? LUDO_SEATS_OF_TWO : [0, 1, 2, 3];

/** A lobby: the open seats, empty. */
export function lobbyState(players: number): LudoState {
  return {
    seats: openSeats(players).map((seat) => ({
      seat,
      userId: null,
      auto: null,
      awaySince: null,
      pieces: [],
    })),
    turn: null,
    phase: null,
    dice: null,
    sixes: 0,
    turnEndsAt: null,
    winner: null,
    events: [],
  };
}

/** The shared-track square of [seat]'s piece at [step], or null when it is not on the shared track. */
export function globalSquare(seat: number, step: number): number | null {
  return step >= 0 && step <= LUDO_LAST_TRACK_STEP ? (LUDO_START[seat]! + step) % LUDO_TRACK : null;
}

/** The pieces of [pieces] that may move [dice] steps. */
export function legalMoves(pieces: readonly number[], dice: number): number[] {
  const out: number[] = [];
  pieces.forEach((step, i) => {
    if (step >= LUDO_FINISH) return;
    if (step < 0) {
      if (dice === 6) out.push(i);
      return;
    }
    if (step + dice <= LUDO_FINISH) out.push(i);
  });
  return out;
}

const seatOf = (state: LudoState, seat: number): LudoSeat => {
  const found = state.seats.find((s) => s.seat === seat);
  if (!found) throw new Error(`no seat ${seat}`);
  return found;
};

/** The prototype's AUTO heuristic: a move's score (higher is better). */
export function scoreMove(state: LudoState, seat: number, piece: number, dice: number): number {
  const step = seatOf(state, seat).pieces[piece]!;
  const next = step < 0 ? 0 : step + dice;
  let score = next * 0.3;
  if (step < 0) score += 40;
  if (next === LUDO_FINISH) score += 60;
  const square = globalSquare(seat, next);
  if (square !== null) {
    if (LUDO_SAFE.has(square)) score += 12;
    else {
      for (const other of state.seats) {
        if (other.seat === seat) continue;
        if (other.pieces.some((p) => globalSquare(other.seat, p) === square)) score += 100;
      }
    }
  }
  if (next > LUDO_LAST_TRACK_STEP && step <= LUDO_LAST_TRACK_STEP) score += 20;
  return score;
}

/** The best of [options] by {@link scoreMove}; the first one wins a tie. */
export function bestMove(state: LudoState, seat: number, dice: number, options: readonly number[]): number {
  return options.reduce((a, b) =>
    scoreMove(state, seat, b, dice) > scoreMove(state, seat, a, dice) ? b : a,
  );
}

const at = (now: Date, ms: number): string => new Date(now.getTime() + ms).toISOString();

function turnDeadline(seat: LudoSeat, now: Date): string {
  return at(now, seat.auto ? LUDO_AUTO_MS : LUDO_TURN_MS);
}

function withTurn(state: LudoState, seat: number, sixes: number, now: Date, events: LudoEvent[]): LudoState {
  return {
    ...state,
    turn: seat,
    phase: 'ROLL',
    dice: null,
    sixes,
    turnEndsAt: turnDeadline(seatOf(state, seat), now),
    events,
  };
}

function nextTurn(state: LudoState, now: Date, events: LudoEvent[]): LudoState {
  const order = state.seats.map((s) => s.seat);
  const i = order.indexOf(state.turn ?? order[0]!);
  return withTurn(state, order[(i + 1) % order.length]!, 0, now, events);
}

/**
 * Starts a game from a lobby: the seated players play (in seat order, red first), every piece in its
 * base. Throws NOT_STARTABLE with fewer than 2 players.
 */
export function startGame(lobby: LudoState, mode: LudoMode, now: Date): LudoState {
  const seated = lobby.seats.filter((s) => s.userId !== null);
  if (seated.length < 2) throw new LudoRuleError('NOT_STARTABLE');
  const pieces = Array<number>(piecesOf(mode)).fill(LUDO_BASE);
  const state: LudoState = {
    ...lobby,
    seats: seated.map((s) => ({ ...s, auto: s.auto, pieces })),
    winner: null,
  };
  return withTurn(state, seated[0]!.seat, 0, now, [{ kind: 'START' }]);
}

/**
 * [seat] rolls [dice] (1–6). A third 6 in a row ends the turn; no legal move passes the turn; a
 * single legal move — or any roll of an AUTO seat — is played at once (the best move); otherwise the
 * player chooses within a new turn timer.
 */
export function roll(state: LudoState, seat: number, dice: number, now: Date, byServer = false): LudoState {
  if (state.winner !== null || state.turn !== seat || state.phase !== 'ROLL') {
    throw new LudoRuleError('NOT_YOUR_TURN');
  }
  if (!Number.isInteger(dice) || dice < 1 || dice > 6) throw new Error(`bad dice ${dice}`);
  const player = seatOf(state, seat);
  const auto = byServer || player.auto !== null;
  const events: LudoEvent[] = [{ kind: 'ROLL', seat, dice, auto }];
  const sixes = dice === 6 ? state.sixes + 1 : state.sixes;
  const rolled: LudoState = { ...state, dice, sixes, events };
  if (sixes >= 3) return nextTurn(rolled, now, [...events, { kind: 'THREE_SIXES', seat }]);
  const options = legalMoves(player.pieces, dice);
  if (options.length === 0) return nextTurn(rolled, now, [...events, { kind: 'NO_MOVE', seat, dice }]);
  if (options.length === 1 || player.auto !== null) {
    const piece = options.length === 1 ? options[0]! : bestMove(rolled, seat, dice, options);
    return applyMove({ ...rolled, phase: 'MOVE' }, seat, piece, now, auto, events);
  }
  return { ...rolled, phase: 'MOVE', turnEndsAt: at(now, LUDO_TURN_MS) };
}

/** The pieces [seat] may move now (empty unless it is choosing). */
export function movable(state: LudoState): number[] {
  if (state.phase !== 'MOVE' || state.turn === null || state.dice === null) return [];
  return legalMoves(seatOf(state, state.turn).pieces, state.dice);
}

/** [seat] moves [piece] by the rolled dice. Throws NOT_YOUR_TURN or ILLEGAL_MOVE. */
export function move(state: LudoState, seat: number, piece: number, now: Date, byServer = false): LudoState {
  if (state.winner !== null || state.turn !== seat || state.phase !== 'MOVE') {
    throw new LudoRuleError('NOT_YOUR_TURN');
  }
  if (!movable(state).includes(piece)) throw new LudoRuleError('ILLEGAL_MOVE');
  return applyMove(state, seat, piece, now, byServer || seatOf(state, seat).auto !== null, []);
}

function applyMove(
  state: LudoState,
  seat: number,
  piece: number,
  now: Date,
  auto: boolean,
  before: LudoEvent[],
): LudoState {
  const dice = state.dice!;
  const from = seatOf(state, seat).pieces[piece]!;
  const to = from < 0 ? 0 : from + dice;
  const square = globalSquare(seat, to);
  const captured: LudoCapture[] = [];
  const seats = state.seats.map((s) => {
    if (s.seat === seat) return { ...s, pieces: s.pieces.map((p, i) => (i === piece ? to : p)) };
    if (square === null || LUDO_SAFE.has(square)) return s;
    return {
      ...s,
      pieces: s.pieces.map((p, i) => {
        if (globalSquare(s.seat, p) !== square) return p;
        captured.push({ seat: s.seat, piece: i, from: p });
        return LUDO_BASE;
      }),
    };
  });
  const reached = to >= LUDO_FINISH;
  const events: LudoEvent[] = [
    ...before,
    { kind: 'MOVE', seat, piece, from, to, dice, captured, reached, auto },
  ];
  const moved: LudoState = { ...state, seats };
  if (seatOf(moved, seat).pieces.every((p) => p >= LUDO_FINISH)) {
    return {
      ...moved,
      winner: seat,
      phase: null,
      turnEndsAt: null,
      events: [...events, { kind: 'WIN', seat }],
    };
  }
  if (dice === 6 || captured.length > 0 || reached) return withTurn(moved, seat, moved.sixes, now, events);
  return nextTurn(moved, now, events);
}

/** [seat] becomes AUTO for [reason]; on its turn the server plays it shortly. */
export function setAuto(state: LudoState, seat: number, reason: LudoAutoReason, now: Date): LudoState {
  const player = seatOf(state, seat);
  if (player.auto === 'LEFT' || player.auto === reason) return { ...state, events: [] };
  const seats = state.seats.map((s) => (s.seat === seat ? { ...s, auto: reason, awaySince: null } : s));
  const soon = at(now, LUDO_AUTO_MS);
  const turnEndsAt =
    state.turn === seat && state.turnEndsAt !== null && state.turnEndsAt > soon ? soon : state.turnEndsAt;
  return { ...state, seats, turnEndsAt, events: [{ kind: 'AUTO', seat, reason }] };
}

/** [seat]'s player left the media session at [now] (AUTO after {@link LUDO_DISCONNECT_MS}). */
export function markAway(state: LudoState, seat: number, now: Date): LudoState {
  const player = seatOf(state, seat);
  if (player.auto !== null || player.awaySince !== null) return { ...state, events: [] };
  return {
    ...state,
    seats: state.seats.map((s) => (s.seat === seat ? { ...s, awaySince: now.toISOString() } : s)),
    events: [],
  };
}

/** [seat]'s player is back in the room: a disconnect AUTO ends (leaving the game is final). */
export function markBack(state: LudoState, seat: number, now: Date): LudoState {
  const player = seatOf(state, seat);
  if (player.auto === 'DISCONNECTED') {
    const seats = state.seats.map((s) => (s.seat === seat ? { ...s, auto: null, awaySince: null } : s));
    const back: LudoState = { ...state, seats, events: [{ kind: 'BACK', seat }] };
    // Their own turn gets a full timer again.
    return state.turn === seat && state.phase !== null
      ? { ...back, turnEndsAt: at(now, LUDO_TURN_MS) }
      : back;
  }
  if (player.awaySince === null) return { ...state, events: [] };
  return {
    ...state,
    seats: state.seats.map((s) => (s.seat === seat ? { ...s, awaySince: null } : s)),
    events: [],
  };
}

/** When the server next has something to do for this game (a turn timer or an away player). */
export function dueAt(state: LudoState): string | null {
  if (state.winner !== null) return null;
  const times: string[] = [];
  if (state.turnEndsAt) times.push(state.turnEndsAt);
  for (const s of state.seats) {
    if (s.auto === null && s.awaySince !== null) {
      times.push(new Date(Date.parse(s.awaySince) + LUDO_DISCONNECT_MS).toISOString());
    }
  }
  return times.length === 0 ? null : times.reduce((a, b) => (b < a ? b : a));
}

/**
 * The server's step at [now]: players away for 30 s become AUTO; then, when the turn's time is up, a
 * roll ([dice] gives the number) or the best move is played for the player. Null when nothing is due.
 */
export function timeout(state: LudoState, now: Date, dice: () => number): LudoState | null {
  if (state.winner !== null || state.turn === null) return null;
  let next = state;
  const events: LudoEvent[] = [];
  for (const s of state.seats) {
    if (
      s.auto === null &&
      s.awaySince !== null &&
      now.getTime() - Date.parse(s.awaySince) >= LUDO_DISCONNECT_MS
    ) {
      next = setAuto(next, s.seat, 'DISCONNECTED', now);
      events.push(...next.events);
    }
  }
  if (next.turnEndsAt !== null && Date.parse(next.turnEndsAt) <= now.getTime()) {
    const seat = next.turn!;
    if (next.phase === 'ROLL') next = roll(next, seat, dice(), now, true);
    else {
      const options = movable(next);
      next = move(next, seat, bestMove(next, seat, next.dice!, options), now, true);
    }
    events.push(...next.events);
  }
  if (events.length === 0) return null;
  return { ...next, events };
}
