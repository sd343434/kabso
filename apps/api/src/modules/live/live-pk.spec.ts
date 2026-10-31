import { randomBytes } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { loadConfig } from '../../config/app-config.js';
import {
  absenceOf,
  boosterProblem,
  boosterRule,
  pkIdentity,
  pkMatchOfIdentity,
  pkPoints,
  winnerByScore,
  type PkSidePresence,
} from './live-pk.js';

const base = {
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  // Generated per run: never commit a secret-like literal (gitleaks).
  JWT_ACCESS_SECRET: randomBytes(48).toString('base64url'),
  APP_PUBLIC_URL: 'https://kabso.example/',
};

describe('D195 PK config (owner-confirmable defaults)', () => {
  const pk = loadConfig(base).pk;

  it('battle 5 min, result 60 s, invitations 15 s with a 10 s cooldown, absence 30 s', () => {
    expect(pk).toMatchObject({
      enabled: true,
      inviteTtlSeconds: 15,
      inviteCooldownSeconds: 10,
      randomWaitSeconds: 60,
      battleSeconds: 300,
      resultSeconds: 60,
      absenceGraceSeconds: 30,
      tickMs: 1000,
      scoreBroadcastMs: 500,
    });
  });

  it('the four boosters: ×2 / ×3 / ×5 / ×10, 30 / 20 / 20 / 10 s, any / last 120 / 60 / 60 s, 2 each', () => {
    expect(pk.boosters).toEqual([
      { kind: 'DOUBLE', multiplier: 2, durationSeconds: 30, lastSeconds: 0, limitPerMatch: 2 },
      { kind: 'DOUBLE_TURBO', multiplier: 3, durationSeconds: 20, lastSeconds: 120, limitPerMatch: 2 },
      { kind: 'TRIPLE', multiplier: 5, durationSeconds: 20, lastSeconds: 60, limitPerMatch: 2 },
      { kind: 'TRIPLE_TURBO', multiplier: 10, durationSeconds: 10, lastSeconds: 60, limitPerMatch: 2 },
    ]);
  });

  it('every value is configurable', () => {
    const c = loadConfig({
      ...base,
      PK_BATTLE_SECONDS: '180',
      PK_BOOSTER_MULTIPLIERS: '2,4,6,12',
      PK_BOOSTER_SECONDS: '10,10,10,5',
      PK_BOOSTER_WINDOWS: '0,0,30,30',
      PK_BOOSTER_LIMITS: '1,1,1,3',
    }).pk;
    expect(c.battleSeconds).toBe(180);
    expect(c.boosters.map((b) => [b.multiplier, b.durationSeconds, b.lastSeconds, b.limitPerMatch])).toEqual([
      [2, 10, 0, 1],
      [4, 10, 0, 1],
      [6, 10, 30, 1],
      [12, 5, 30, 3],
    ]);
  });

  it('refuses multipliers that are not strictly ascending, lists of the wrong length and a 0 tick in production', () => {
    expect(() => loadConfig({ ...base, PK_BOOSTER_MULTIPLIERS: '2,2,5,10' })).toThrow(
      /PK_BOOSTER_MULTIPLIERS/,
    );
    expect(() => loadConfig({ ...base, PK_BOOSTER_SECONDS: '30,20,20' })).toThrow(/PK_BOOSTER_SECONDS/);
    expect(() => loadConfig({ ...base, PK_BOOSTER_WINDOWS: '0,120,60' })).toThrow(/PK_BOOSTER_WINDOWS/);
    expect(() => loadConfig({ ...base, PK_INVITE_TTL_SECONDS: '1' })).toThrow(/PK_INVITE_TTL_SECONDS/);
  });
});

describe('D195 booster rules', () => {
  const rules = loadConfig(base).pk.boosters;
  const s = 1000;

  it('Double any time; Double Turbo only in the last 2 minutes; Triple and Triple Turbo only in the last minute', () => {
    const at = (kind: Parameters<typeof boosterRule>[1], remainingMs: number) =>
      boosterProblem({ rule: boosterRule(rules, kind), remainingMs, used: 0, activeMultiplier: 1 });
    expect(at('DOUBLE', 299 * s)).toBeNull();
    expect(at('DOUBLE_TURBO', 121 * s)).toBe('too_early');
    expect(at('DOUBLE_TURBO', 120 * s)).toBeNull();
    expect(at('TRIPLE', 61 * s)).toBe('too_early');
    expect(at('TRIPLE', 60 * s)).toBeNull();
    expect(at('TRIPLE_TURBO', 61 * s)).toBe('too_early');
    expect(at('TRIPLE_TURBO', 1)).toBeNull();
    expect(at('DOUBLE', 0)).toBe('no_match');
  });

  it('per-match limit per booster and side', () => {
    const rule = boosterRule(rules, 'DOUBLE');
    expect(boosterProblem({ rule, remainingMs: 200 * s, used: 1, activeMultiplier: 1 })).toBeNull();
    expect(boosterProblem({ rule, remainingMs: 200 * s, used: 2, activeMultiplier: 1 })).toBe(
      'limit_reached',
    );
  });

  it('a new booster replaces the active one only when it is higher', () => {
    const triple = boosterRule(rules, 'TRIPLE');
    expect(boosterProblem({ rule: triple, remainingMs: 30 * s, used: 0, activeMultiplier: 2 })).toBeNull();
    expect(boosterProblem({ rule: triple, remainingMs: 30 * s, used: 0, activeMultiplier: 5 })).toBe(
      'active_higher',
    );
    expect(
      boosterProblem({
        rule: boosterRule(rules, 'DOUBLE'),
        remainingMs: 30 * s,
        used: 0,
        activeMultiplier: 10,
      }),
    ).toBe('active_higher');
  });

  it('PK points are coins × multiplier (and only that)', () => {
    expect(pkPoints(1500n, 10)).toBe(15000n);
    expect(pkPoints(7n, 1)).toBe(7n);
  });
});

describe('D195 outcome and absence', () => {
  const now = new Date('2026-11-01T12:00:00.000Z');
  const present: PkSidePresence = {
    roomStatus: 'LIVE',
    roomEndReason: null,
    lastHeartbeatAt: new Date(now.getTime() - 10_000),
    hostAwaySince: null,
    leftAt: null,
  };

  it('higher score wins; equal is a draw', () => {
    expect(winnerByScore(10n, 3n)).toBe('A');
    expect(winnerByScore(3n, 10n)).toBe('B');
    expect(winnerByScore(5n, 5n)).toBeNull();
  });

  it('ending the live is a forfeit; other ends, stale heartbeats and leaving the session are disconnects', () => {
    expect(absenceOf(present, now, 30)).toBeNull();
    expect(absenceOf({ ...present, roomStatus: 'ENDED', roomEndReason: 'HOST_ENDED' }, now, 30)).toBe(
      'FORFEIT',
    );
    expect(absenceOf({ ...present, roomStatus: 'ENDED', roomEndReason: 'ADMIN' }, now, 30)).toBe(
      'DISCONNECT',
    );
    expect(absenceOf({ ...present, lastHeartbeatAt: new Date(now.getTime() - 30_000) }, now, 30)).toBe(
      'DISCONNECT',
    );
    expect(absenceOf({ ...present, leftAt: new Date(now.getTime() - 29_000) }, now, 30)).toBeNull();
    expect(absenceOf({ ...present, leftAt: new Date(now.getTime() - 30_000) }, now, 30)).toBe('DISCONNECT');
  });

  it('away (D170) more than 30 s loses as AWAY', () => {
    expect(absenceOf({ ...present, hostAwaySince: new Date(now.getTime() - 29_999) }, now, 30)).toBeNull();
    expect(absenceOf({ ...present, hostAwaySince: new Date(now.getTime() - 30_000) }, now, 30)).toBe('AWAY');
  });
});

describe('D195 PK media identity', () => {
  const match = '0192f1d0-0000-7000-8000-000000000001';
  it('pk:<matchId>:<identity> round-trips; anything else is not a PK watcher', () => {
    expect(pkMatchOfIdentity(pkIdentity(match, '0192f1d0-0000-7000-8000-0000000000ff'))).toBe(match);
    expect(pkMatchOfIdentity(pkIdentity(match, 'guest:abc'))).toBe(match);
    expect(pkMatchOfIdentity(`pk:${match}:`)).toBeNull();
    expect(pkMatchOfIdentity('pk:nope:x')).toBeNull();
    expect(pkMatchOfIdentity('guest:abc')).toBeNull();
    expect(pkMatchOfIdentity(match)).toBeNull();
  });
});
