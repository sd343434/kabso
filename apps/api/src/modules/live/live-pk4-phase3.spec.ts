import { describe, expect, it } from 'vitest';
import {
  ffaOutcome,
  ffaPlaces,
  ffaResult,
  pickPk4Group,
  pk4DareSides,
  pk4SeatPlan,
  roleOfSeatIn,
  shuffled,
  teamOfSeat,
  teamsOutcome,
  type Pk4DareSeat,
  type Pk4FfaSeat,
} from './live-pk4.js';

/** v1.119-live (D395, CONVENTIONS §10.181, CP-041 phases 3–4): the pure rules of «PK رباعي» for two to four hosts. */

const plan = (format: 'TEAMS' | 'FREE_FOR_ALL', seats: number[]) =>
  [...pk4SeatPlan(format, seats).entries()].sort((a, b) => a[0] - b[0]);

describe('the seat plan (two, three or four hosts)', () => {
  it('TEAMS keeps the invited places; the organiser and the teammate alone play like a 1 v 1', () => {
    expect(plan('TEAMS', [1, 2, 3, 4])).toEqual([
      [1, 1],
      [2, 2],
      [3, 3],
      [4, 4],
    ]);
    // Three: two on one side, the third alone on the other (either way round).
    expect(plan('TEAMS', [1, 2, 4])).toEqual([
      [1, 1],
      [2, 2],
      [4, 4],
    ]);
    expect(plan('TEAMS', [1, 3, 4])).toEqual([
      [1, 1],
      [3, 3],
      [4, 4],
    ]);
    // Two on opposite teams stay; two on one team are split.
    expect(plan('TEAMS', [1, 3])).toEqual([
      [1, 1],
      [3, 3],
    ]);
    expect(plan('TEAMS', [1, 2])).toEqual([
      [1, 1],
      [2, 3],
    ]);
    expect(plan('TEAMS', [3, 4])).toEqual([
      [3, 1],
      [4, 3],
    ]);
  });

  it('FREE_FOR_ALL packs the hosts: halves for two, two + one big tile for three, 2 × 2 for four', () => {
    expect(plan('FREE_FOR_ALL', [1, 4])).toEqual([
      [1, 1],
      [4, 3],
    ]);
    expect(plan('FREE_FOR_ALL', [1, 3, 4])).toEqual([
      [1, 1],
      [3, 2],
      [4, 3],
    ]);
    expect([...pk4SeatPlan('FREE_FOR_ALL', [1, 3, 4]).values()].map(teamOfSeat)).toEqual(['A', 'A', 'B']);
    expect(plan('FREE_FOR_ALL', [4, 2, 1, 3]).map(([, s]) => s)).toEqual([1, 2, 3, 4]);
  });

  it('refuses fewer than two or more than four places', () => {
    expect(() => pk4SeatPlan('TEAMS', [1])).toThrow();
    expect(() => pk4SeatPlan('FREE_FOR_ALL', [1, 2, 3, 4, 5])).toThrow();
    expect(() => pk4SeatPlan('TEAMS', [1, 1])).toThrow();
  });

  it('FREE_FOR_ALL places are PLAYERs in the lobby', () => {
    expect([1, 2, 3, 4].map((s) => roleOfSeatIn('FREE_FOR_ALL', s))).toEqual([
      'ORGANISER',
      'PLAYER',
      'PLAYER',
      'PLAYER',
    ]);
    expect([1, 2, 3, 4].map((s) => roleOfSeatIn('TEAMS', s))).toEqual([
      'ORGANISER',
      'TEAMMATE',
      'OPPONENT',
      'OPPONENT',
    ]);
  });
});

describe('FREE_FOR_ALL places, ties and results', () => {
  const at = (s: number) => new Date(Date.UTC(2027, 0, 1, 0, 0, s));
  const seat = (n: number, score: number, outAt: Date | null = null): Pk4FfaSeat => ({
    seat: n,
    score: BigInt(score),
    outAt,
  });
  const places = (seats: Pk4FfaSeat[]) =>
    [...ffaPlaces(seats).entries()].sort((a, b) => a[0] - b[0]).map(([, p]) => p);

  it('ranks four by score; equal scores share a place (1, 1, 3, 4)', () => {
    expect(places([seat(1, 50), seat(2, 900), seat(3, 300), seat(4, 10)])).toEqual([3, 1, 2, 4]);
    expect(places([seat(1, 500), seat(2, 500), seat(3, 300), seat(4, 300)])).toEqual([1, 1, 3, 3]);
    expect(places([seat(1, 0), seat(2, 0), seat(3, 0), seat(4, 0)])).toEqual([1, 1, 1, 1]);
  });

  it('ranks two and three', () => {
    expect(places([seat(1, 10), seat(3, 20)])).toEqual([2, 1]);
    expect(places([seat(1, 10), seat(3, 10)])).toEqual([1, 1]);
    expect(places([seat(1, 5), seat(2, 7), seat(3, 7)])).toEqual([3, 1, 1]);
  });

  it('a host who left takes the last free place (the first to leave the last), whatever their score', () => {
    // The 4th left first with the best score, then the 3rd: 4 and 3; the two on air are 1 and 2.
    expect(places([seat(1, 9000, at(1)), seat(2, 10), seat(3, 20), seat(4, 5000, at(5))])).toEqual([
      4, 2, 1, 3,
    ]);
    // Two left at the same moment: ordered between them by score.
    expect(places([seat(1, 100, at(3)), seat(2, 50), seat(3, 200, at(3)), seat(4, 10)])).toEqual([
      4, 1, 3, 2,
    ]);
    expect(places([seat(1, 100, at(3)), seat(2, 50), seat(3, 100, at(3))])).toEqual([2, 1, 2]);
  });

  it('1st alone wins, a shared 1st is a draw, every other place loses', () => {
    expect(ffaResult(1, [1, 2, 3, 4])).toBe('WIN');
    expect(ffaResult(2, [1, 2, 3, 4])).toBe('LOSS');
    expect(ffaResult(1, [1, 1, 3, 4])).toBe('DRAW');
    expect(ffaResult(3, [1, 1, 3, 4])).toBe('LOSS');
    expect(ffaResult(1, [1, 1])).toBe('DRAW');
  });

  it('outs: one host left on air ends it, nobody on air is everyone gone, else it goes on', () => {
    const s = (outs: (null | 'FORFEIT')[]) => outs.map((out, i) => ({ seat: i + 1, out }));
    expect(ffaOutcome(s(['FORFEIT', null, null, null]), 'FORFEIT')).toEqual({ kind: 'continue' });
    expect(ffaOutcome(s(['FORFEIT', 'FORFEIT', null, null]), 'FORFEIT')).toEqual({ kind: 'continue' });
    expect(ffaOutcome(s(['FORFEIT', 'FORFEIT', 'FORFEIT', null]), 'FORFEIT')).toEqual({
      kind: 'end',
      reason: 'FORFEIT',
      everyoneGone: false,
    });
    expect(ffaOutcome(s(['FORFEIT', null]), 'FORFEIT')).toEqual({
      kind: 'end',
      reason: 'FORFEIT',
      everyoneGone: false,
    });
    expect(ffaOutcome(s(['FORFEIT', 'FORFEIT']), 'FORFEIT')).toEqual({
      kind: 'end',
      reason: 'FORFEIT',
      everyoneGone: true,
    });
  });
});

describe('TEAMS with three hosts and two', () => {
  it('the lone host of a side out → the other side wins; one of the pair out → it goes on', () => {
    const three = [
      { seat: 1, team: teamOfSeat(1), out: null },
      { seat: 2, team: teamOfSeat(2), out: null },
      { seat: 3, team: teamOfSeat(3), out: 'AWAY' as const },
    ];
    expect(teamsOutcome(three, 'AWAY')).toEqual({
      kind: 'end',
      reason: 'AWAY',
      winner: 'A',
      loserCause: 'B',
    });
    const pairOut = [
      { seat: 1, team: teamOfSeat(1), out: 'FORFEIT' as const },
      { seat: 2, team: teamOfSeat(2), out: null },
      { seat: 3, team: teamOfSeat(3), out: null },
    ];
    expect(teamsOutcome(pairOut, 'FORFEIT')).toEqual({ kind: 'continue' });
    const two = [
      { seat: 1, team: teamOfSeat(1), out: 'FORFEIT' as const },
      { seat: 3, team: teamOfSeat(3), out: null },
    ];
    expect(teamsOutcome(two, 'FORFEIT')).toEqual({
      kind: 'end',
      reason: 'FORFEIT',
      winner: 'B',
      loserCause: 'A',
    });
  });
});

describe('«PK أحكام» for four: who does the dare and who judges', () => {
  const s = (seat: number, place: number | null, out = false): Pk4DareSeat => ({
    seat,
    team: teamOfSeat(seat),
    hostId: `h${String(seat)}`,
    place,
    out,
  });

  it('TEAMS: the losing team does it, the winning team judges; a draw → none', () => {
    const seats = [s(1, null), s(2, null), s(3, null), s(4, null)];
    expect(pk4DareSides('TEAMS', seats, 'A')).toEqual({
      losers: [s(3, null), s(4, null)],
      winners: [s(1, null), s(2, null)],
    });
    expect(pk4DareSides('TEAMS', seats, null)).toBeNull();
    // Three: a lone loser does it alone.
    expect(pk4DareSides('TEAMS', [s(1, null), s(2, null), s(3, null)], 'A')!.losers).toEqual([s(3, null)]);
    // Two: like a 1 v 1.
    expect(pk4DareSides('TEAMS', [s(1, null), s(3, null)], 'B')).toEqual({
      losers: [s(1, null)],
      winners: [s(3, null)],
    });
  });

  it('FREE_FOR_ALL: the lowest place on air does it (the 4th left → the 3rd), the 1st judges', () => {
    expect(pk4DareSides('FREE_FOR_ALL', [s(1, 1), s(2, 2), s(3, 3), s(4, 4)], null)).toEqual({
      losers: [s(4, 4)],
      winners: [s(1, 1)],
    });
    expect(pk4DareSides('FREE_FOR_ALL', [s(1, 1), s(2, 2), s(3, 3), s(4, 4, true)], null)!.losers).toEqual([
      s(3, 3),
    ]);
    // A shared last place does it together; a shared 1st judges together.
    expect(pk4DareSides('FREE_FOR_ALL', [s(1, 1), s(2, 1), s(3, 3), s(4, 3)], null)).toEqual({
      losers: [s(3, 3), s(4, 3)],
      winners: [s(1, 1), s(2, 1)],
    });
    // Everyone 1st → a draw, no dare; nobody but the winner on air → none.
    expect(pk4DareSides('FREE_FOR_ALL', [s(1, 1), s(3, 1)], null)).toBeNull();
    expect(pk4DareSides('FREE_FOR_ALL', [s(1, 1), s(2, 2, true), s(3, 3, true)], null)).toBeNull();
    // Two and three.
    expect(pk4DareSides('FREE_FOR_ALL', [s(1, 2), s(3, 1)], null)).toEqual({
      losers: [s(1, 2)],
      winners: [s(3, 1)],
    });
    expect(pk4DareSides('FREE_FOR_ALL', [s(1, 1), s(2, 3), s(3, 2)], null)!.losers).toEqual([s(2, 3)]);
  });
});

describe('the 4-way random group', () => {
  it('takes the caller and the three longest waiters who fit with everyone already in', () => {
    const blocked = new Set(['b-c']);
    const fits = (a: string, b: string) => !blocked.has(`${a}-${b}`) && !blocked.has(`${b}-${a}`);
    expect(pickPk4Group('me', ['a', 'b', 'c', 'd', 'e'], fits)).toEqual(['me', 'a', 'b', 'd']);
    expect(pickPk4Group('me', ['a', 'b'], fits)).toBeNull();
    expect(pickPk4Group('me', ['b', 'c'], fits)).toBeNull();
  });

  it('shuffles with the given random source (crypto in the service)', () => {
    expect(shuffled([1, 2, 3, 4], () => 0)).toEqual([2, 3, 4, 1]);
    expect(shuffled([1, 2, 3, 4], (max) => max - 1)).toEqual([1, 2, 3, 4]);
    expect([...shuffled([1, 2, 3, 4], (max) => Math.floor(max / 2))].sort()).toEqual([1, 2, 3, 4]);
  });
});
