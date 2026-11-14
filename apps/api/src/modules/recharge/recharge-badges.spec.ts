import { randomBytes } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { ConfigValidationError, loadConfig } from '../../config/app-config.js';
import { userSummary } from '../posts/post-views.js';
import { activeRechargeBadge, rechargeBadgeTier } from './recharge-badges.js';
import { dayKey } from './recharge-rules.js';

const MINS = [1_000_000, 10_000_001, 20_000_001, 40_000_001, 70_000_001];

const base = {
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  // Generated per run: never commit a secret-like literal (gitleaks).
  JWT_ACCESS_SECRET: randomBytes(48).toString('base64url'),
  APP_PUBLIC_URL: 'https://kabso.example/',
};

describe('D187 daily recharge badge tiers', () => {
  it('maps a day total to the owner tiers, boundaries included', () => {
    const cases: [bigint, number][] = [
      [0n, 0],
      [999_999n, 0],
      [1_000_000n, 1],
      [10_000_000n, 1],
      [10_000_001n, 2],
      [20_000_000n, 2],
      [20_000_001n, 3],
      [40_000_000n, 3],
      [40_000_001n, 4],
      [70_000_000n, 4],
      [70_000_001n, 5],
      [9_000_000_000n, 5],
    ];
    for (const [total, tier] of cases) expect(rechargeBadgeTier(total, MINS), String(total)).toBe(tier);
  });

  it('shows a badge only before its until, and never for an agent', () => {
    const until = new Date('2026-10-31T12:00:00.000Z');
    const row = { tier: 3, until };
    expect(activeRechargeBadge(row, new Date('2026-10-31T11:59:59.999Z'))).toEqual({
      tier: 3,
      until: '2026-10-31T12:00:00.000Z',
    });
    expect(activeRechargeBadge(row, until)).toBeNull();
    expect(activeRechargeBadge(row, new Date('2026-11-01T00:00:00.000Z'))).toBeNull();
    expect(activeRechargeBadge(row, new Date('2026-10-31T00:00:00.000Z'), true)).toBeNull();
    expect(activeRechargeBadge(null, new Date())).toBeNull();
  });

  it('a UserSummary carries the badge while it shows, never for a recharge agent', () => {
    const user = {
      id: 'u1',
      profile: { username: 'sara', displayName: 'Sara', avatarUrl: null },
      status: 'ACTIVE',
      rechargeAgent: null,
      rechargeBadge: { tier: 2, until: new Date('2026-10-31T12:00:00.000Z') },
    };
    expect(userSummary(user, new Date('2026-10-31T11:00:00.000Z')).rechargeBadge).toEqual({
      tier: 2,
      until: '2026-10-31T12:00:00.000Z',
    });
    expect(userSummary(user, new Date('2026-10-31T12:00:00.000Z'))).not.toHaveProperty('rechargeBadge');
    const agent = { ...user, rechargeAgent: { status: 'SUSPENDED', code: 'coin0001' } };
    expect(userSummary(agent, new Date('2026-10-31T11:00:00.000Z'))).not.toHaveProperty('rechargeBadge');
  });

  it('the day is the calendar day in Asia/Riyadh (UTC+3) by default', () => {
    expect(dayKey(new Date('2026-10-30T20:59:59.999Z'), 'Asia/Riyadh')).toBe('2026-10-30');
    expect(dayKey(new Date('2026-10-30T21:00:00.000Z'), 'Asia/Riyadh')).toBe('2026-10-31');
  });

  it('the rules are configurable and validated', () => {
    expect(loadConfig(base).recharge.badges).toEqual({ tierMins: MINS, timeZone: 'Asia/Riyadh', hours: 24 });
    const custom = loadConfig({
      ...base,
      RECHARGE_BADGE_TIERS: '100,200,300,400,500',
      RECHARGE_BADGE_TIME_ZONE: 'Africa/Cairo',
      RECHARGE_BADGE_HOURS: '48',
    });
    expect(custom.recharge.badges).toEqual({
      tierMins: [100, 200, 300, 400, 500],
      timeZone: 'Africa/Cairo',
      hours: 48,
    });
    for (const bad of [
      { RECHARGE_BADGE_TIERS: '100,200,300,400' },
      { RECHARGE_BADGE_TIERS: '100,300,200,400,500' },
      { RECHARGE_BADGE_TIME_ZONE: 'Mars/Base' },
      { RECHARGE_BADGE_HOURS: '0' },
    ]) {
      expect(() => loadConfig({ ...base, ...bad }), JSON.stringify(bad)).toThrow(ConfigValidationError);
    }
  });
});
