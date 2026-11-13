import { describe, expect, it } from 'vitest';
import { pkIdentity, pkMatchOfIdentity } from './live-pk.js';
import {
  isEffectivePk4,
  pk4Identity,
  pk4MatchOfIdentity,
  PK4_IDENTITY_PREFIX,
  roleOfSeat,
  teamOfSeat,
  teamsOutcome,
  teamWinnerByScore,
  type Pk4SeatPresence,
} from './live-pk4.js';

/** v1.118-live (D391, CONVENTIONS §10.180): the pure rules of «PK رباعي» (TEAMS). */
describe('PK 2 v 2 places and teams', () => {
  it('places 1–2 are team A (organiser, teammate), 3–4 team B (opponents)', () => {
    expect([1, 2, 3, 4].map(teamOfSeat)).toEqual(['A', 'A', 'B', 'B']);
    expect([1, 2, 3, 4].map(roleOfSeat)).toEqual(['ORGANISER', 'TEAMMATE', 'OPPONENT', 'OPPONENT']);
  });
});

describe('PK 2 v 2 outs (a host who leaves)', () => {
  const seats = (outs: (Pk4SeatPresence['out'] | null)[]): Pk4SeatPresence[] =>
    outs.map((out, i) => ({ seat: i + 1, team: teamOfSeat(i + 1), out }));

  it('one host out: the teammate carries on', () => {
    expect(teamsOutcome(seats(['FORFEIT', null, null, null]), 'FORFEIT')).toEqual({ kind: 'continue' });
    expect(teamsOutcome(seats(['AWAY', null, 'DISCONNECT', null]), 'DISCONNECT')).toEqual({
      kind: 'continue',
    });
  });

  it('both hosts of a team out: the other team wins at once', () => {
    expect(teamsOutcome(seats(['FORFEIT', 'DISCONNECT', null, null]), 'DISCONNECT')).toEqual({
      kind: 'end',
      reason: 'DISCONNECT',
      winner: 'B',
      loserCause: 'A',
    });
    expect(teamsOutcome(seats([null, 'AWAY', 'FORFEIT', 'AWAY']), 'AWAY')).toEqual({
      kind: 'end',
      reason: 'AWAY',
      winner: 'A',
      loserCause: 'B',
    });
  });

  it('everyone out: a draw (void for the records)', () => {
    expect(teamsOutcome(seats(['FORFEIT', 'AWAY', 'DISCONNECT', 'DISCONNECT']), 'DISCONNECT')).toEqual({
      kind: 'end',
      reason: 'DISCONNECT',
      winner: null,
      loserCause: null,
    });
    expect(isEffectivePk4({ reason: 'DISCONNECT', everyoneGone: true, total: 10_000n, minPoints: 0 })).toBe(
      false,
    );
  });
});

describe('PK 2 v 2 result and records', () => {
  it('the higher team sum wins; equal sums are a draw', () => {
    expect(teamWinnerByScore(300n, 200n)).toBe('A');
    expect(teamWinnerByScore(200n, 300n)).toBe('B');
    expect(teamWinnerByScore(250n, 250n)).toBeNull();
  });

  it('counts when not void and the four hosts reach the floor together', () => {
    expect(isEffectivePk4({ reason: 'TIME', everyoneGone: false, total: 3000n, minPoints: 3000 })).toBe(true);
    expect(isEffectivePk4({ reason: 'TIME', everyoneGone: false, total: 2999n, minPoints: 3000 })).toBe(
      false,
    );
    expect(isEffectivePk4({ reason: 'FORFEIT', everyoneGone: false, total: 0n, minPoints: 0 })).toBe(true);
    expect(isEffectivePk4({ reason: 'ADMIN', everyoneGone: false, total: 9999n, minPoints: 0 })).toBe(false);
    expect(isEffectivePk4({ reason: 'CANCELLED', everyoneGone: false, total: 9999n, minPoints: 0 })).toBe(
      false,
    );
  });
});

describe('PK 2 v 2 media identities', () => {
  const match = '0192f1d0-0000-7000-8000-000000000001';

  it('round-trips `pk4:<matchId>:<identity>` and never mixes with PK 1 v 1', () => {
    expect(pk4Identity(match, 'guest:abc')).toBe(`${PK4_IDENTITY_PREFIX}${match}:guest:abc`);
    expect(pk4MatchOfIdentity(pk4Identity(match, '0192f1d0-0000-7000-8000-0000000000ff'))).toBe(match);
    expect(pk4MatchOfIdentity(pk4Identity(match.toUpperCase(), 'x'))).toBe(match);
    expect(pk4MatchOfIdentity(`pk4:${match}:`)).toBeNull();
    expect(pk4MatchOfIdentity('pk4:nope:x')).toBeNull();
    expect(pk4MatchOfIdentity(pkIdentity(match, 'x'))).toBeNull();
    // A 4-way identity is not a 1 v 1 one either (`pk:` vs `pk4:`).
    expect(pkMatchOfIdentity(pk4Identity(match, 'x'))).toBeNull();
    expect(pk4Identity(match, 'x').startsWith('pk:')).toBe(false);
  });
});
