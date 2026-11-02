import { describe, expect, it } from 'vitest';
import {
  bestMove,
  dueAt,
  globalSquare,
  legalMoves,
  lobbyState,
  LUDO_AUTO_MS,
  LUDO_BASE,
  LUDO_DISCONNECT_MS,
  LUDO_FINISH,
  LUDO_TURN_MS,
  LudoRuleError,
  markAway,
  markBack,
  move,
  movable,
  roll,
  setAuto,
  startGame,
  timeout,
  type LudoState,
} from './live-ludo.js';

const NOW = new Date('2026-11-02T12:00:00.000Z');
const later = (ms: number) => new Date(NOW.getTime() + ms);

/** A started game of the seats [seats] (users u0 … u3), then [pieces] per seat placed by hand. */
function game(
  seats: number[],
  pieces?: Record<number, number[]>,
  mode: 'CLASSIC' | 'QUICK' = 'CLASSIC',
): LudoState {
  const lobby = lobbyState(seats.length === 2 && seats.includes(2) ? 2 : 4);
  const seated: LudoState = {
    ...lobby,
    seats: lobby.seats.map((s) => (seats.includes(s.seat) ? { ...s, userId: `u${s.seat}` } : s)),
  };
  const started = startGame(seated, mode, NOW);
  if (!pieces) return started;
  return {
    ...started,
    seats: started.seats.map((s) => (pieces[s.seat] ? { ...s, pieces: pieces[s.seat]! } : s)),
  };
}

const piecesOf = (state: LudoState, seat: number) => state.seats.find((s) => s.seat === seat)!.pieces;
const kinds = (state: LudoState) => state.events.map((e) => e.kind);

describe('D168 Ludo board geometry', () => {
  it('maps each colour onto the shared track from its own start', () => {
    expect(globalSquare(0, 0)).toBe(0);
    expect(globalSquare(1, 0)).toBe(13);
    expect(globalSquare(2, 0)).toBe(26);
    expect(globalSquare(3, 0)).toBe(39);
    expect(globalSquare(3, 13)).toBe(0); // blue wraps round to red's start
    expect(globalSquare(0, 51)).toBe(51);
    expect(globalSquare(0, 52)).toBeNull(); // home column
    expect(globalSquare(0, LUDO_BASE)).toBeNull();
  });
});

describe('D168 Ludo legal moves', () => {
  it('needs a 6 to leave the base', () => {
    expect(legalMoves([-1, -1, -1, -1], 5)).toEqual([]);
    expect(legalMoves([-1, -1, -1, -1], 6)).toEqual([0, 1, 2, 3]);
    expect(legalMoves([-1, 3, -1, -1], 2)).toEqual([1]);
  });

  it('needs the exact roll to finish and never moves a finished piece', () => {
    expect(legalMoves([55, LUDO_FINISH], 2)).toEqual([0]);
    expect(legalMoves([55, LUDO_FINISH], 3)).toEqual([]);
    expect(legalMoves([56], 1)).toEqual([0]);
  });
});

describe('D168 Ludo turns', () => {
  it('starts with red, every piece home, a 15 s timer', () => {
    const g = game([0, 1, 2, 3]);
    expect(g.turn).toBe(0);
    expect(g.phase).toBe('ROLL');
    expect(piecesOf(g, 0)).toEqual([-1, -1, -1, -1]);
    expect(g.turnEndsAt).toBe(later(LUDO_TURN_MS).toISOString());
    expect(kinds(g)).toEqual(['START']);
  });

  it('quick mode has two pieces; a game of two plays opposite corners', () => {
    const g = game([0, 2], undefined, 'QUICK');
    expect(g.seats.map((s) => s.seat)).toEqual([0, 2]);
    expect(piecesOf(g, 2)).toEqual([-1, -1]);
  });

  it('refuses to start with fewer than 2 players', () => {
    const lobby = lobbyState(4);
    const one = { ...lobby, seats: lobby.seats.map((s) => (s.seat === 1 ? { ...s, userId: 'x' } : s)) };
    expect(() => startGame(one, 'CLASSIC', NOW)).toThrow(LudoRuleError);
  });

  it('a roll with no legal move passes the turn', () => {
    const g = roll(game([0, 2]), 0, 3, NOW);
    expect(kinds(g)).toEqual(['ROLL', 'NO_MOVE']);
    expect(g.turn).toBe(2);
    expect(g.phase).toBe('ROLL');
  });

  it('a 6 leaves the base and gives another turn (one legal piece moves at once)', () => {
    const g = roll(game([0, 2], { 0: [-1, LUDO_FINISH, LUDO_FINISH, LUDO_FINISH] }), 0, 6, NOW);
    expect(kinds(g)).toEqual(['ROLL', 'MOVE']);
    expect(piecesOf(g, 0)[0]).toBe(0);
    expect(g.turn).toBe(0);
    expect(g.sixes).toBe(1);
  });

  it('with several legal pieces the player chooses within a new timer', () => {
    const g = roll(game([0, 2]), 0, 6, later(5000));
    expect(g.phase).toBe('MOVE');
    expect(movable(g)).toEqual([0, 1, 2, 3]);
    expect(g.turnEndsAt).toBe(later(5000 + LUDO_TURN_MS).toISOString());
    const moved = move(g, 0, 2, later(6000));
    expect(piecesOf(moved, 0)).toEqual([-1, -1, 0, -1]);
    expect(moved.turn).toBe(0); // the 6's extra turn
  });

  it('refuses moves out of turn, out of phase and illegal pieces', () => {
    const g = game([0, 2]);
    expect(() => roll(g, 2, 4, NOW)).toThrow('NOT_YOUR_TURN');
    expect(() => move(g, 0, 0, NOW)).toThrow('NOT_YOUR_TURN');
    const choosing = roll(game([0, 2], { 0: [-1, 5, 9, -1] }), 0, 6, NOW);
    expect(() => roll(choosing, 0, 6, NOW)).toThrow('NOT_YOUR_TURN');
    expect(() => move(choosing, 0, 7, NOW)).toThrow('ILLEGAL_MOVE');
  });

  it('three sixes in a row end the turn', () => {
    let g = game([0, 2], { 0: [10, 20, -1, -1] });
    g = move(roll(g, 0, 6, NOW), 0, 0, NOW);
    g = move(roll(g, 0, 6, NOW), 0, 0, NOW);
    expect(g.sixes).toBe(2);
    g = roll(g, 0, 6, NOW);
    expect(kinds(g)).toEqual(['ROLL', 'THREE_SIXES']);
    expect(g.turn).toBe(2);
    expect(g.sixes).toBe(0);
    expect(piecesOf(g, 0)).toEqual([22, 20, -1, -1]);
  });
});

describe('D168 Ludo captures and safe squares', () => {
  it('landing on an opponent sends it home and gives another turn', () => {
    // Red at step 3 (square 3), green at its step 44 = square (13 + 44) % 52 = 5.
    const g = roll(game([0, 1], { 0: [3, -1, -1, -1], 1: [44, -1, -1, -1] }), 0, 2, NOW);
    const m = g.events.find((e) => e.kind === 'MOVE');
    expect(m).toMatchObject({ kind: 'MOVE', from: 3, to: 5, captured: [{ seat: 1, piece: 0, from: 44 }] });
    expect(piecesOf(g, 1)[0]).toBe(LUDO_BASE);
    expect(g.turn).toBe(0);
    expect(g.phase).toBe('ROLL');
  });

  it('captures every opponent piece on the square', () => {
    const g = roll(game([0, 1], { 0: [3, -1, -1, -1], 1: [44, 44, -1, -1] }), 0, 2, NOW);
    expect(piecesOf(g, 1)).toEqual([-1, -1, -1, -1]);
  });

  it('nobody is captured on a safe square (a star or a start)', () => {
    // Square 8 is a star: red step 8; green step 47 = (13 + 47) % 52 = 8.
    const g = roll(game([0, 1], { 0: [5, -1, -1, -1], 1: [47, -1, -1, -1] }), 0, 3, NOW);
    expect(piecesOf(g, 1)[0]).toBe(47);
    expect(g.turn).toBe(1); // no capture, no 6: the turn passes
  });

  it('pieces on their home column cannot be captured', () => {
    const g = roll(game([0, 1], { 0: [50, -1, -1, -1], 1: [53, -1, -1, -1] }), 0, 1, NOW);
    expect(piecesOf(g, 1)[0]).toBe(53);
  });
});

describe('D168 Ludo finishing and winning', () => {
  it('reaching the centre gives another turn', () => {
    const g = roll(game([0, 2], { 0: [54, -1, -1, -1] }), 0, 3, NOW);
    const m = g.events.find((e) => e.kind === 'MOVE');
    expect(m).toMatchObject({ to: LUDO_FINISH, reached: true });
    expect(g.turn).toBe(0);
  });

  it('the first to bring every piece home wins', () => {
    const g = roll(game([0, 2], { 0: [LUDO_FINISH, LUDO_FINISH, LUDO_FINISH, 55] }), 0, 2, NOW);
    expect(g.winner).toBe(0);
    expect(kinds(g)).toEqual(['ROLL', 'MOVE', 'WIN']);
    expect(g.phase).toBeNull();
    expect(dueAt(g)).toBeNull();
    expect(() => roll(g, 0, 1, NOW)).toThrow('NOT_YOUR_TURN');
  });
});

describe('D168 Ludo AUTO and timeouts', () => {
  it('the best move prefers a capture, then finishing, then leaving the base', () => {
    const g = { ...game([0, 1], { 0: [3, 20, -1, 50], 1: [44, -1, -1, -1] }), dice: 2 };
    expect(bestMove(g, 0, 2, [0, 1, 3])).toBe(0); // 3 → 5 captures green
    const h = game([0, 1], { 0: [54, 20, -1, -1] });
    expect(bestMove(h, 0, 3, [0, 1])).toBe(0); // 54 → 57 finishes
    const k = game([0, 1], { 0: [-1, 20, -1, -1] });
    expect(bestMove(k, 0, 6, [0, 1, 2, 3])).toBe(0); // leaving the base (+40)
  });

  it('a timeout rolls for the player; with a choice the player gets another timer, then the best move', () => {
    const g = game([0, 2], { 0: [-1, 20, -1, -1] });
    expect(timeout(g, later(LUDO_TURN_MS - 1), () => 6)).toBeNull();
    const rolled = timeout(g, later(LUDO_TURN_MS), () => 6)!;
    expect(rolled.events[0]).toMatchObject({ kind: 'ROLL', dice: 6, auto: true });
    expect(rolled.phase).toBe('MOVE');
    const moved = timeout(rolled, later(2 * LUDO_TURN_MS), () => 1)!;
    expect(moved.events[0]).toMatchObject({ kind: 'MOVE', piece: 0, from: -1, to: 0, auto: true });
  });

  it('an AUTO seat plays its whole turn shortly after it starts', () => {
    let g = game([0, 2], { 2: [-1, 20, -1, -1] });
    g = setAuto(g, 2, 'LEFT', NOW);
    expect(kinds(g)).toEqual(['AUTO']);
    g = roll(g, 0, 1, NOW); // no move for red → green… yellow's turn
    expect(g.turn).toBe(2);
    expect(g.turnEndsAt).toBe(later(LUDO_AUTO_MS).toISOString());
    const played = timeout(g, later(LUDO_AUTO_MS), () => 6)!;
    expect(kinds(played)).toEqual(['ROLL', 'MOVE']);
    expect(piecesOf(played, 2)[0]).toBe(0); // the best move leaves the base
  });

  it('a player away for 30 s becomes AUTO; coming back in time keeps control', () => {
    let g = markAway(game([0, 2]), 2, NOW);
    expect(dueAt(g)).toBe(later(LUDO_TURN_MS).toISOString());
    g = markBack(g, 2, later(10_000));
    expect(g.seats.find((s) => s.seat === 2)!.awaySince).toBeNull();
    g = markAway(g, 2, later(10_000));
    const auto = timeout(g, later(10_000 + LUDO_DISCONNECT_MS), () => 1)!;
    expect(auto.seats.find((s) => s.seat === 2)!.auto).toBe('DISCONNECTED');
    expect(auto.events[0]).toEqual({ kind: 'AUTO', seat: 2, reason: 'DISCONNECTED' });
    const back = markBack(auto, 2, later(50_000));
    expect(back.seats.find((s) => s.seat === 2)!.auto).toBeNull();
    expect(kinds(back)).toEqual(['BACK']);
  });

  it('a player who left stays AUTO', () => {
    const left = setAuto(game([0, 2]), 2, 'LEFT', NOW);
    expect(markBack(left, 2, NOW).seats.find((s) => s.seat === 2)!.auto).toBe('LEFT');
  });

  it('the turn of a player who becomes AUTO ends soon', () => {
    const g = setAuto(game([0, 2]), 0, 'LEFT', NOW);
    expect(g.turnEndsAt).toBe(later(LUDO_AUTO_MS).toISOString());
  });
});
