import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { loadConfig } from '../../config/app-config.js';
import { envSchema } from '../../config/env.schema.js';
import {
  AMBASSADOR_REWARD_KINDS,
  ambassadorMonth,
  ambassadorRewardSchema,
  canonicalLevelCode,
  capCommission,
  commissionCherries,
  commissionEconomics,
  DEFAULT_AMBASSADOR_LEVEL_CODES,
  DEFAULT_AMBASSADOR_LEVELS,
  DEFAULT_AMBASSADOR_MONTHLY_CAP_CHERRIES,
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

/** The shipped defaults (CONVENTIONS §10.179.7; the owner's names and numbers of 2026-11-14). */
const DEFAULTS: AmbassadorLevel[] = [...DEFAULT_AMBASSADOR_LEVELS];

/** A list with both monthly requirements (the OWNER may set active referrals too): the evaluation's rules. */
const TWO_REQ: AmbassadorLevel[] = [
  { code: 'SPARK', minActiveReferrals: 0, minTopupCoins: 0, commissionBps: 150, reward: { kind: 'NONE' } },
  {
    code: 'STAR',
    minActiveReferrals: 5,
    minTopupCoins: 3_000_000,
    commissionBps: 250,
    reward: { kind: 'NONE' },
  },
  {
    code: 'CONSTELLATION',
    minActiveReferrals: 15,
    minTopupCoins: 15_000_000,
    commissionBps: 300,
    reward: { kind: 'NONE' },
  },
  {
    code: 'GALAXY',
    minActiveReferrals: 40,
    minTopupCoins: 60_000_000,
    commissionBps: 400,
    reward: { kind: 'NONE' },
  },
];

describe('D390 ambassador levels', () => {
  it('the proposed defaults are valid and parse back', () => {
    expect(levelsProblem(DEFAULTS)).toBeNull();
    expect(levelsProblem(TWO_REQ)).toBeNull();
    expect(parseLevels(JSON.parse(JSON.stringify(DEFAULTS)))).toEqual(DEFAULTS);
  });

  it("the owner's numbers (2026-11-14): 1.5 / 2.5 / 3 / 4 %, from 0 / 20 M / 50 M / 250 M coins a month, no referral requirement", () => {
    expect(DEFAULTS.map((l) => [l.code, l.commissionBps, l.minTopupCoins, l.minActiveReferrals])).toEqual([
      ['SPARK', 150, 0, 0],
      ['STAR', 250, 20_000_000, 0],
      ['CONSTELLATION', 300, 50_000_000, 0],
      ['GALAXY', 400, 250_000_000, 0],
    ]);
    // The monthly rewards in withdrawable cherries (owner 2026-11-14, «نعم»; the coordinator's amounts).
    expect(DEFAULTS.map((l) => l.reward)).toEqual([
      { kind: 'NONE' },
      { kind: 'CHERRIES', amount: 5_000_000 },
      { kind: 'CHERRIES', amount: 15_000_000 },
      { kind: 'CHERRIES', amount: 50_000_000 },
    ]);
    // No monthly commission cap by default (owner 2026-11-14: «إلغاء الحد تماماً»).
    expect(DEFAULT_AMBASSADOR_MONTHLY_CAP_CHERRIES).toBe(0n);
  });

  it('a reward kind CHERRIES next to the others (the OWNER may still pick coins, VIP days or an item)', () => {
    expect(AMBASSADOR_REWARD_KINDS).toEqual(['NONE', 'COINS', 'CHERRIES', 'VIP_DAYS', 'BAG_ITEM']);
    expect(ambassadorRewardSchema.safeParse({ kind: 'CHERRIES', amount: 5_000_000 }).success).toBe(true);
    expect(ambassadorRewardSchema.safeParse({ kind: 'CHERRIES', amount: 0 }).success).toBe(false);
    expect(ambassadorRewardSchema.safeParse({ kind: 'CHERRIES', amount: 5, vipTier: 'VIP_1' }).success).toBe(
      false,
    );
    for (const r of [
      { kind: 'COINS', amount: 100_000 },
      { kind: 'VIP_DAYS', amount: 7, vipTier: 'VIP_1' },
      { kind: 'BAG_ITEM', amount: 30, itemCode: 'frame_gold' },
    ]) {
      expect(ambassadorRewardSchema.safeParse(r).success).toBe(true);
    }
  });

  it('the cap limits commissions only; 0 is no cap', () => {
    expect(capCommission(300_000n, 0n, DEFAULT_AMBASSADOR_MONTHLY_CAP_CHERRIES)).toEqual({
      cherries: 300_000n,
      capped: 0n,
    });
  });

  it('the database default (schema.prisma and the migration) is the same list', () => {
    const schema = readFileSync(new URL('../../../prisma/schema.prisma', import.meta.url), 'utf8');
    const m = /levels\s+Json\s+@default\("((?:[^"\\]|\\.)*)"\)/.exec(schema);
    expect(JSON.parse(JSON.parse(`"${m![1]!}"`) as string)).toEqual(DEFAULTS);
    const sql = readFileSync(
      new URL(
        '../../../prisma/migrations/20270520090000_ambassador_level_names/migration.sql',
        import.meta.url,
      ),
      'utf8',
    );
    const d = /ALTER COLUMN "levels" SET DEFAULT '([^']*)'/.exec(sql);
    expect(JSON.parse(d![1]!)).toEqual(DEFAULTS);
  });

  it('refuses a list that is empty, too long, not open at the first level, not increasing or with a lower rate', () => {
    expect(levelsProblem([])).toBe('count');
    expect(levelsProblem(Array.from({ length: 11 }, (_, i) => ({ ...DEFAULTS[0]!, code: `L${i}X` })))).toBe(
      'count',
    );
    expect(levelsProblem([DEFAULTS[0]!, { ...DEFAULTS[1]!, code: 'SPARK' }])).toBe('duplicate_code');
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
    expect(levelIndex(DEFAULTS, 'CONSTELLATION')).toBe(2);
    expect(levelIndex(DEFAULTS, 'PLATINUM')).toBe(0);
  });

  it("the default codes are the owner's «سفراء النجوم» (2026-11-14)", () => {
    expect(DEFAULTS.map((l) => l.code)).toEqual([...DEFAULT_AMBASSADOR_LEVEL_CODES]);
  });

  it('an old default code reads as its renamed level, both ways; other codes are unchanged', () => {
    expect(canonicalLevelCode('BRONZE')).toBe('SPARK');
    expect(canonicalLevelCode('SILVER')).toBe('STAR');
    expect(canonicalLevelCode('GOLD')).toBe('CONSTELLATION');
    expect(canonicalLevelCode('DIAMOND')).toBe('GALAXY');
    expect(canonicalLevelCode('STAR')).toBe('STAR');
    expect(canonicalLevelCode('PLATINUM')).toBe('PLATINUM');
    // An ambassador row with an old code, the list renamed.
    expect(levelIndex(DEFAULTS, 'BRONZE')).toBe(0);
    expect(levelIndex(DEFAULTS, 'SILVER')).toBe(1);
    expect(levelIndex(DEFAULTS, 'GOLD')).toBe(2);
    expect(levelIndex(DEFAULTS, 'DIAMOND')).toBe(3);
    // A list the migration left with old codes, a row with a new one.
    const old = DEFAULTS.map((l, i) => ({ ...l, code: ['BRONZE', 'SILVER', 'GOLD', 'DIAMOND'][i]! }));
    expect(levelIndex(old, 'CONSTELLATION')).toBe(2);
    // The exact code wins over the mapping (an OWNER list that reuses an old code for another level).
    const mixed = [DEFAULTS[0]!, { ...DEFAULTS[1]!, code: 'GOLD' }, DEFAULTS[2]!];
    expect(levelIndex(mixed, 'GOLD')).toBe(1);
    expect(levelIndex(mixed, 'CONSTELLATION')).toBe(2);
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

  it("the worked example of §10.179.5: 1 000 000 coins at Galaxy (4 %, the owner's numbers of 2026-11-14) against the platform profit", () => {
    const e = commissionEconomics({
      coins: 1_000_000n,
      bps: 400,
      cherriesPerCoin: 10,
      retailMinorPerMillion: 1250,
      rateCherries: 1_000_000,
      rateMinor: 110,
      hostShareBps: 6500,
    });
    expect(e.revenueMinor).toBe(1250); // $12.50 paid for the coins
    expect(e.commissionCherries).toBe(400_000n);
    expect(e.commissionMinor).toBeCloseTo(44, 6); // $0.44
    expect(e.hostMinor).toBeCloseTo(715, 6); // 6 500 000 cherries = $7.15
    expect(e.profitMinor).toBeCloseTo(535, 6); // $5.35 before the commission
    // The commission is 3.5 % of the money paid and ≈ 8.2 % of the platform's profit on those coins.
    expect(e.commissionMinor / e.revenueMinor).toBeCloseTo(0.0352, 6);
    expect(e.commissionMinor / e.profitMinor).toBeCloseTo(0.0822, 3);
    // Spark (1.5 %): 150 000 cherries, $0.165, ≈ 3.1 % of the profit.
    const d = commissionEconomics({
      ...{ coins: 1_000_000n, cherriesPerCoin: 10, retailMinorPerMillion: 1250 },
      bps: 150,
      rateCherries: 1_000_000,
      rateMinor: 110,
      hostShareBps: 6500,
    });
    expect(d.commissionCherries).toBe(150_000n);
    expect(d.commissionMinor).toBeCloseTo(16.5, 6);
    expect(d.commissionMinor / d.profitMinor).toBeCloseTo(0.0308, 3);
  });
});

describe('D390 monthly evaluation', () => {
  it('the met level is the highest whose two requirements the month meets', () => {
    expect(metLevelIndex(TWO_REQ, { activeReferrals: 0, topupCoins: 0n })).toBe(0);
    expect(metLevelIndex(TWO_REQ, { activeReferrals: 5, topupCoins: 3_000_000n })).toBe(1);
    expect(metLevelIndex(TWO_REQ, { activeReferrals: 50, topupCoins: 3_000_000n })).toBe(1);
    expect(metLevelIndex(TWO_REQ, { activeReferrals: 4, topupCoins: 99_000_000n })).toBe(0);
    expect(metLevelIndex(TWO_REQ, { activeReferrals: 40, topupCoins: 60_000_000n })).toBe(3);
  });

  it("the defaults: the month's qualifying top-ups alone decide (a threshold is the minimum)", () => {
    expect(metLevelIndex(DEFAULTS, { activeReferrals: 0, topupCoins: 0n })).toBe(0);
    expect(metLevelIndex(DEFAULTS, { activeReferrals: 0, topupCoins: 19_999_999n })).toBe(0);
    expect(metLevelIndex(DEFAULTS, { activeReferrals: 0, topupCoins: 20_000_000n })).toBe(1);
    expect(metLevelIndex(DEFAULTS, { activeReferrals: 0, topupCoins: 49_990_000n })).toBe(1);
    expect(metLevelIndex(DEFAULTS, { activeReferrals: 0, topupCoins: 50_000_000n })).toBe(2);
    expect(metLevelIndex(DEFAULTS, { activeReferrals: 0, topupCoins: 249_990_000n })).toBe(2);
    expect(metLevelIndex(DEFAULTS, { activeReferrals: 0, topupCoins: 250_000_000n })).toBe(3);
  });

  it('promotes straight to the met level, demotes one level at a time, never below the first', () => {
    expect(levelAfterMonth(0, 2)).toBe(2);
    expect(levelAfterMonth(3, 0)).toBe(2);
    expect(levelAfterMonth(1, 0)).toBe(0);
    expect(levelAfterMonth(0, 0)).toBe(0);
    expect(levelAfterMonth(2, 2)).toBe(2);
  });

  it('what is left to reach the next level, none at the top', () => {
    expect(progressToNext(TWO_REQ, 0, { activeReferrals: 2, topupCoins: 1_000_000n })).toEqual({
      code: 'STAR',
      activeReferrals: 3,
      topupCoins: 2_000_000,
    });
    expect(progressToNext(TWO_REQ, 0, { activeReferrals: 9, topupCoins: 9_000_000n })).toEqual({
      code: 'STAR',
      activeReferrals: 0,
      topupCoins: 0,
    });
    expect(progressToNext(DEFAULTS, 1, { activeReferrals: 0, topupCoins: 32_000_000n })).toEqual({
      code: 'CONSTELLATION',
      activeReferrals: 0,
      topupCoins: 18_000_000,
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
