import { describe, expect, it } from 'vitest';
import { loadConfig } from '../../config/app-config.js';
import { envSchema } from '../../config/env.schema.js';
import {
  ambassadorMonth,
  capCommission,
  commissionCherries,
  commissionEconomics,
  levelAfterMonth,
  levelIndex,
  levelsProblem,
  metLevelIndex,
  parseLevels,
  previousMonth,
  progressToNext,
  rewardReference,
  type AmbassadorLevel,
} from './ambassador-rules.js';

/** The migration's proposed defaults (CONVENTIONS §10.179.7). */
const DEFAULTS: AmbassadorLevel[] = [
  { code: 'BRONZE', minActiveReferrals: 0, minTopupCoins: 0, commissionBps: 200, reward: { kind: 'NONE' } },
  {
    code: 'SILVER',
    minActiveReferrals: 5,
    minTopupCoins: 3_000_000,
    commissionBps: 300,
    reward: { kind: 'COINS', amount: 100_000 },
  },
  {
    code: 'GOLD',
    minActiveReferrals: 15,
    minTopupCoins: 15_000_000,
    commissionBps: 400,
    reward: { kind: 'VIP_DAYS', amount: 7, vipTier: 'VIP_1' },
  },
  {
    code: 'DIAMOND',
    minActiveReferrals: 40,
    minTopupCoins: 60_000_000,
    commissionBps: 500,
    reward: { kind: 'COINS', amount: 1_000_000 },
  },
];

describe('D390 ambassador levels', () => {
  it('the proposed defaults are valid and parse back', () => {
    expect(levelsProblem(DEFAULTS)).toBeNull();
    expect(parseLevels(JSON.parse(JSON.stringify(DEFAULTS)))).toEqual(DEFAULTS);
  });

  it('refuses a list that is empty, too long, not open at the first level, not increasing or with a lower rate', () => {
    expect(levelsProblem([])).toBe('count');
    expect(levelsProblem(Array.from({ length: 11 }, (_, i) => ({ ...DEFAULTS[0]!, code: `L${i}X` })))).toBe(
      'count',
    );
    expect(levelsProblem([DEFAULTS[0]!, { ...DEFAULTS[1]!, code: 'BRONZE' }])).toBe('duplicate_code');
    expect(levelsProblem([{ ...DEFAULTS[0]!, minActiveReferrals: 1 }])).toBe('first_not_open');
    expect(levelsProblem([DEFAULTS[0]!, { ...DEFAULTS[1]!, minActiveReferrals: 0, minTopupCoins: 0 }])).toBe(
      'not_increasing',
    );
    expect(levelsProblem([DEFAULTS[0]!, DEFAULTS[2]!, DEFAULTS[1]!])).toBe('not_increasing');
    expect(levelsProblem([DEFAULTS[0]!, { ...DEFAULTS[1]!, commissionBps: 100 }])).toBe(
      'commission_decreasing',
    );
  });

  it('an unreadable stored value reads as no level (nothing is paid)', () => {
    expect(parseLevels(null)).toEqual([]);
    expect(parseLevels([{ code: 'x' }])).toEqual([]);
    expect(parseLevels([DEFAULTS[1]!])).toEqual([]);
  });

  it('a removed level code reads as the first level', () => {
    expect(levelIndex(DEFAULTS, 'GOLD')).toBe(2);
    expect(levelIndex(DEFAULTS, 'PLATINUM')).toBe(0);
  });
});

describe('D390 commission and cap', () => {
  it('floor(coins × CHERRIES_PER_COIN × bps / 10 000)', () => {
    expect(commissionCherries(1_000_000n, 10, 500)).toBe(500_000n);
    expect(commissionCherries(333n, 10, 300)).toBe(99n);
    expect(commissionCherries(1n, 10, 300)).toBe(0n);
    expect(commissionCherries(0n, 10, 500)).toBe(0n);
    expect(commissionCherries(1_000n, 10, 0)).toBe(0n);
  });

  it('the monthly cap trims a commission to what is left, then pays nothing (0 = no cap)', () => {
    expect(capCommission(400n, 0n, 1_000n)).toEqual({ cherries: 400n, capped: 0n });
    expect(capCommission(400n, 800n, 1_000n)).toEqual({ cherries: 200n, capped: 200n });
    expect(capCommission(400n, 1_000n, 1_000n)).toEqual({ cherries: 0n, capped: 400n });
    expect(capCommission(400n, 5_000n, 1_000n)).toEqual({ cherries: 0n, capped: 400n });
    expect(capCommission(400n, 9_999n, 0n)).toEqual({ cherries: 400n, capped: 0n });
  });

  it('the worked example of §10.179.5: 1 000 000 coins at Diamond (5 %, the lower-cost defaults) against the platform profit', () => {
    const e = commissionEconomics({
      coins: 1_000_000n,
      bps: 500,
      cherriesPerCoin: 10,
      retailMinorPerMillion: 1250,
      rateCherries: 1_000_000,
      rateMinor: 110,
      hostShareBps: 6500,
    });
    expect(e.revenueMinor).toBe(1250); // $12.50 paid for the coins
    expect(e.commissionCherries).toBe(500_000n);
    expect(e.commissionMinor).toBeCloseTo(55, 6); // $0.55
    expect(e.hostMinor).toBeCloseTo(715, 6); // 6 500 000 cherries = $7.15
    expect(e.profitMinor).toBeCloseTo(535, 6); // $5.35 before the commission
    // The commission is 4.4 % of the money paid and ≈ 10.3 % of the platform's profit on those coins.
    expect(e.commissionMinor / e.revenueMinor).toBeCloseTo(0.044, 6);
    expect(e.commissionMinor / e.profitMinor).toBeCloseTo(0.1028, 3);
    // Bronze (2 %): $0.22, ≈ 4.1 % of the profit.
    const d = commissionEconomics({
      ...{ coins: 1_000_000n, cherriesPerCoin: 10, retailMinorPerMillion: 1250 },
      bps: 200,
      rateCherries: 1_000_000,
      rateMinor: 110,
      hostShareBps: 6500,
    });
    expect(d.commissionMinor).toBeCloseTo(22, 6);
    expect(d.commissionMinor / d.profitMinor).toBeCloseTo(0.0411, 3);
  });
});

describe('D390 monthly evaluation', () => {
  it('the met level is the highest whose two requirements the month meets', () => {
    expect(metLevelIndex(DEFAULTS, { activeReferrals: 0, topupCoins: 0n })).toBe(0);
    expect(metLevelIndex(DEFAULTS, { activeReferrals: 5, topupCoins: 3_000_000n })).toBe(1);
    expect(metLevelIndex(DEFAULTS, { activeReferrals: 50, topupCoins: 3_000_000n })).toBe(1);
    expect(metLevelIndex(DEFAULTS, { activeReferrals: 4, topupCoins: 99_000_000n })).toBe(0);
    expect(metLevelIndex(DEFAULTS, { activeReferrals: 40, topupCoins: 60_000_000n })).toBe(3);
  });

  it('promotes straight to the met level, demotes one level at a time, never below the first', () => {
    expect(levelAfterMonth(0, 2)).toBe(2);
    expect(levelAfterMonth(3, 0)).toBe(2);
    expect(levelAfterMonth(1, 0)).toBe(0);
    expect(levelAfterMonth(0, 0)).toBe(0);
    expect(levelAfterMonth(2, 2)).toBe(2);
  });

  it('what is left to reach the next level, none at the top', () => {
    expect(progressToNext(DEFAULTS, 0, { activeReferrals: 2, topupCoins: 1_000_000n })).toEqual({
      code: 'SILVER',
      activeReferrals: 3,
      topupCoins: 2_000_000,
    });
    expect(progressToNext(DEFAULTS, 0, { activeReferrals: 9, topupCoins: 9_000_000n })).toEqual({
      code: 'SILVER',
      activeReferrals: 0,
      topupCoins: 0,
    });
    expect(progressToNext(DEFAULTS, 3, { activeReferrals: 0, topupCoins: 0n })).toBeNull();
  });

  it('months in the programme zone; the reward reference is once per person and month', () => {
    expect(ambassadorMonth(new Date('2026-11-30T22:30:00.000Z'), 'UTC')).toBe('2026-11');
    expect(ambassadorMonth(new Date('2026-11-30T22:30:00.000Z'), 'Asia/Riyadh')).toBe('2026-12');
    expect(previousMonth('2027-01')).toBe('2026-12');
    expect(previousMonth('2026-11')).toBe('2026-10');
    expect(rewardReference('u1', '2026-11')).toBe('AMB:u1@2026-11');
  });
});

describe('D390 configuration', () => {
  const base = {
    NODE_ENV: 'development',
    DATABASE_URL: 'postgresql://u:p@localhost:5432/kabso_dev',
    REDIS_URL: 'redis://localhost:6379/0',
    JWT_ACCESS_SECRET: 'x'.repeat(48),
    APP_PUBLIC_URL: 'https://kabsolive.com',
  };
  it('the sweeper runs every 5 minutes by default; off is refused in production', () => {
    expect(loadConfig(base).ambassadors.sweepIntervalSeconds).toBe(300);
    expect(
      loadConfig({ ...base, AMBASSADOR_SWEEP_INTERVAL_SECONDS: '0' }).ambassadors.sweepIntervalSeconds,
    ).toBe(0);
    const prod = envSchema.safeParse({
      ...base,
      NODE_ENV: 'production',
      AMBASSADOR_SWEEP_INTERVAL_SECONDS: '0',
    });
    expect(prod.success).toBe(false);
    expect(prod.error!.issues.some((i) => i.path[0] === 'AMBASSADOR_SWEEP_INTERVAL_SECONDS')).toBe(true);
  });
});
