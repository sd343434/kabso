import { randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { loadConfig } from '../../config/app-config.js';
import {
  CHECK_IN_CYCLE_DAYS,
  DEFAULT_POOL_TASKS,
  DEFAULT_TASKS,
  COIN_VALUE_METRICS,
  TASK_METRICS,
  cappedReward,
  cappedTaskReward,
  checkInCycleDay,
  checkInReward,
  cherriesUsd,
  coinsUsd,
  isTaskMetric,
  monthlyCapCherries,
  parseEventPrizes,
  parsePayoutRate,
  parsePrizeText,
  prizeForRank,
  svipTierFor,
} from './programs-rules.js';
import { addDays } from './programs-time.js';

const base = {
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  JWT_ACCESS_SECRET: randomBytes(48).toString('base64url'),
  APP_PUBLIC_URL: 'https://kabso.example/',
};

describe('D166 check-in rules', () => {
  it('counts a 7-day cycle and adds the bonus on every 7th day in a row', () => {
    expect(CHECK_IN_CYCLE_DAYS).toBe(7);
    expect([1, 2, 6, 7, 8, 14, 15].map(checkInCycleDay)).toEqual([1, 2, 6, 7, 1, 7, 1]);
    expect(checkInReward(1, 5, 20)).toBe(5);
    expect(checkInReward(7, 5, 20)).toBe(25);
    expect(checkInReward(14, 5, 20)).toBe(25);
    expect(checkInReward(8, 5, 20)).toBe(5);
  });

  it('pays all of a reward, what is left of the daily cap, or nothing', () => {
    expect(cappedReward(15, 50, 0)).toBe(15);
    expect(cappedReward(15, 50, 40)).toBe(10);
    expect(cappedReward(15, 50, 50)).toBe(0);
    expect(cappedReward(15, 50, 70)).toBe(0);
  });

  it('D188: the monthly cap in cherries, and a claim under both caps', () => {
    // Owner: $5 (500 minor units) at $1.10 per 1 000 000 cherries, floored.
    expect(monthlyCapCherries(500, 1_000_000, 110)).toBe(4_545_454);
    expect(monthlyCapCherries(0, 1_000_000, 110)).toBe(0);
    const month = (earned: number) => ({ cap: 4_545_454, earned });
    const day = (earned: number) => ({ cap: 50_000, earned });
    expect(cappedTaskReward(1_000, day(0), month(0))).toEqual({ pay: 1_000, cap: null });
    // Crossing the monthly cap pays the remainder, then the monthly cap refuses (before the daily one).
    expect(cappedTaskReward(1_000, day(0), month(4_545_000))).toEqual({ pay: 454, cap: null });
    expect(cappedTaskReward(1_000, day(50_000), month(4_545_454))).toEqual({ pay: 0, cap: 'MONTHLY' });
    expect(cappedTaskReward(1_000, day(49_800), month(0))).toEqual({ pay: 200, cap: null });
    expect(cappedTaskReward(1_000, day(50_000), month(0))).toEqual({ pay: 0, cap: 'DAILY' });
    // A weekly task: no daily cap, the monthly one still counts; no monthly cap (0) = only the daily.
    expect(cappedTaskReward(50_000, null, month(4_520_000))).toEqual({ pay: 25_454, cap: null });
    expect(cappedTaskReward(1_000, day(0), { cap: 0, earned: 9_999_999 })).toEqual({ pay: 1_000, cap: null });
  });

  it('D188: the real money of rewards and coin targets (task-admin)', () => {
    const rate = parsePayoutRate('1000000:110')!;
    expect(rate).toEqual({ cherries: 1_000_000, minor: 110 });
    expect(parsePayoutRate('1000000:0')).toBeNull();
    expect(cherriesUsd(1_000_000, rate)).toBe('$1.10');
    expect(cherriesUsd(50_000, rate)).toBe('$0.055');
    expect(cherriesUsd(1_000, rate)).toBe('$0.0011');
    expect(cherriesUsd(0, rate)).toBe('$0');
    expect(coinsUsd(1_000_000, 12.5)).toBe('$12.50');
    expect(coinsUsd(10_000, 12.5)).toBe('$0.125');
    expect(coinsUsd(5_000_000, 12.5)).toBe('$62.50');
    expect(COIN_VALUE_METRICS).toEqual(['GIFT_COINS_SENT', 'HOST_GIFT_COINS']);
  });

  it('D188: the defaults pay at most about 1 % of the money behind a coin target', () => {
    const rate = { cherries: 1_000_000, minor: 110 };
    const share = (cherries: number, coins: number) =>
      (cherries * rate.minor) / rate.cherries / 100 / ((coins * 12.5) / 1_000_000);
    for (const t of DEFAULT_TASKS.filter((x) => COIN_VALUE_METRICS.includes(x.metric))) {
      expect(share(t.rewardCherries, t.target), t.code).toBeLessThanOrEqual(0.0101);
      for (let i = 0; i < (t.bandTargets?.length ?? 0); i++) {
        expect(
          share(t.bandRewards![i]!, t.bandTargets![i]!),
          `${t.code} band ${String(i + 1)}`,
        ).toBeLessThanOrEqual(0.0101);
      }
    }
    for (const t of DEFAULT_POOL_TASKS.filter((x) => COIN_VALUE_METRICS.includes(x.metric))) {
      for (let i = 0; i < 4; i++) {
        if (t.bandTargets[i] === 0) continue;
        expect(
          share(t.bandRewards[i]!, t.bandTargets[i]!),
          `${t.code} band ${String(i + 1)}`,
        ).toBeLessThanOrEqual(0.0101);
      }
    }
  });

  it('moves calendar dates across months and years', () => {
    expect(addDays('2026-10-31', 1)).toBe('2026-11-01');
    expect(addDays('2027-01-01', -1)).toBe('2026-12-31');
  });

  it('the migration seeds exactly the default tasks', () => {
    const sql = readFileSync(
      fileURLToPath(
        new URL('../../../prisma/migrations/20261214100000_me_programs/migration.sql', import.meta.url),
      ),
      'utf8',
    );
    const rows = [
      ...sql.matchAll(
        /\('([A-Z_]+)', '(DAILY|WEEKLY)', '([A-Z_]+)', (\d+), (\d+), '(EVERYONE|HOSTS)', '([^']+)', '([^']+)', (\d+)\)/g,
      ),
    ];
    // The seeded rows' identity (D166); D188 (v1.57-social) rebalanced their targets, rewards, metric and
    // names: migration 20261231130000_task_rewards_rebalance holds the defaults' values.
    expect(rows.map((m) => ({ code: m[1], period: m[2], audience: m[6], sortOrder: Number(m[9]) }))).toEqual(
      DEFAULT_TASKS.map((t) => ({
        code: t.code,
        period: t.period,
        audience: t.audience,
        sortOrder: t.sortOrder,
      })),
    );
    const rebalance = readFileSync(
      fileURLToPath(
        new URL(
          '../../../prisma/migrations/20261231130000_task_rewards_rebalance/migration.sql',
          import.meta.url,
        ),
      ),
      'utf8',
    ).replace(/\s+/g, ' ');
    // The weekly host tasks got per-band values in 20261231140000_task_weekly_host_bands (follow-up).
    const weekly = readFileSync(
      fileURLToPath(
        new URL(
          '../../../prisma/migrations/20261231140000_task_weekly_host_bands/migration.sql',
          import.meta.url,
        ),
      ),
      'utf8',
    ).replace(/\s+/g, ' ');
    for (const t of DEFAULT_TASKS) {
      if (t.bandTargets && t.bandRewards) {
        expect(weekly).toContain(
          `('${t.code}', ARRAY[${t.bandTargets.join(', ')}], ARRAY[${t.bandRewards.join(', ')}], '${t.nameAr}', '${t.nameEn}')`,
        );
        // The row mirrors band 4.
        expect([t.target, t.rewardCherries]).toEqual([t.bandTargets[3], t.bandRewards[3]]);
        continue;
      }
      expect(rebalance).toContain(`('${t.code}', ${String(t.target)}, ${String(t.rewardCherries)},`);
      const seeded = rows.find((m) => m[1] === t.code)!;
      if (seeded[3] !== t.metric)
        expect(rebalance).toContain(
          `('${t.code}', ${String(t.target)}, ${String(t.rewardCherries)}, '${t.metric}'`,
        );
      if (seeded[7] !== t.nameAr) expect(rebalance).toContain(`'${t.nameAr}', '${t.nameEn}'`);
    }
  });

  it('knows the task metrics', () => {
    // D166's six, then D176's twelve daily-pool metrics (v1.50-social), then D188's coin value sent.
    expect(TASK_METRICS.slice(0, 6)).toEqual([
      'WATCH_LIVES',
      'FOLLOWS',
      'LIVE_CHAT_MESSAGES',
      'GIFT_SENDS',
      'HOST_LIVE_MINUTES',
      'HOST_GIFT_COINS',
    ]);
    expect(TASK_METRICS).toHaveLength(19);
    expect(TASK_METRICS.at(-1)).toBe('GIFT_COINS_SENT');
    expect(isTaskMetric('FOLLOWS')).toBe(true);
    expect(isTaskMetric('SHARES')).toBe(false);
  });
});

describe('D166 SVIP tiers', () => {
  it('gives the highest tier whose threshold the spending meets', () => {
    const tiers = [50_000, 150_000, 400_000];
    expect(svipTierFor(0, tiers)).toBe(0);
    expect(svipTierFor(49_999, tiers)).toBe(0);
    expect(svipTierFor(50_000, tiers)).toBe(1);
    expect(svipTierFor(399_999, tiers)).toBe(2);
    expect(svipTierFor(9_000_000, tiers)).toBe(3);
  });
});

describe('D166 event prizes', () => {
  it('parses the CLI text and finds the prize of a rank', () => {
    const prizes = parsePrizeText('1:5000, 2:3000, 3-10:500');
    expect(prizes).toEqual([
      { rankFrom: 1, rankTo: 1, coins: 5000 },
      { rankFrom: 2, rankTo: 2, coins: 3000 },
      { rankFrom: 3, rankTo: 10, coins: 500 },
    ]);
    expect(prizeForRank(prizes!, 1)).toBe(5000);
    expect(prizeForRank(prizes!, 7)).toBe(500);
    expect(prizeForRank(prizes!, 11)).toBe(0);
    expect(parsePrizeText('')).toEqual([]);
  });

  it('refuses overlapping, unordered, out-of-range or malformed prizes', () => {
    expect(parsePrizeText('1-3:100,2:50')).toBeNull();
    expect(parsePrizeText('2:50,1:100')).toBeNull();
    expect(parsePrizeText('101:5')).toBeNull();
    expect(parsePrizeText('1:0')).toBeNull();
    expect(parsePrizeText('first:10')).toBeNull();
    expect(parseEventPrizes({})).toBeNull();
    expect(parseEventPrizes([{ rankFrom: 1, rankTo: 1, coins: 1.5 }])).toBeNull();
  });
});

describe('D166 config', () => {
  it('has the owner-approved defaults', () => {
    const { programs } = loadConfig(base);
    expect(programs.taskDailyCapCoins).toBe(50);
    // D184: task rewards are cherries; D188 (owner): 50 000 a day, at most $5 a month (500 minor units).
    expect(programs.taskDailyCapCherries).toBe(50_000);
    expect(programs.taskMonthlyCapMinor).toBe(500);
    // D188: task cherries unlock for withdrawal at $60 of lifetime gift cherries (owner rule; was $50).
    expect(loadConfig(base).economy.taskCherriesUnlockGiftMinor).toBe(6000);
    // D188: the anchors — 1 000 000 coins = $12.50 retail, 1 000 000 cherries = $1.10 payout.
    expect(loadConfig(base).economy.coinRetailUsdPerMillion).toBe(12.5);
    expect(loadConfig(base).economy).toMatchObject({ rateCherries: 1_000_000, rateMinor: 110 });
    expect(programs.checkInCoins).toBe(5);
    expect(programs.checkInStreakBonusCoins).toBe(20);
    expect(programs.eventPrizeReviewMs).toBe(24 * 3_600_000);
    expect(programs.svipTiers).toEqual([50_000, 150_000, 400_000]);
    expect(programs.svipWindowDays).toBe(30);
    expect(programs.svipStatusDays).toBe(30);
    expect(programs.rechargeCurrency).toBe('USD');
    expect(programs.rechargePackages).toHaveLength(7);
    expect(programs.rechargePackages[2]).toEqual({
      id: 'p3',
      coins: 276,
      bonusCoins: 28,
      priceMinor: 699,
      originalPriceMinor: 800,
    });
    expect(programs.rechargePackages[0]).toMatchObject({
      coins: 10,
      bonusCoins: 20,
      originalPriceMinor: null,
    });
  });

  it('reads overrides and refuses bad values', () => {
    const custom = loadConfig({ ...base, SVIP_TIERS: '1000,2000', WALLET_RECHARGE_PACKAGES: '100+0:99' });
    expect(custom.programs.svipTiers).toEqual([1000, 2000]);
    expect(custom.programs.rechargePackages).toEqual([
      { id: 'p1', coins: 100, bonusCoins: 0, priceMinor: 99, originalPriceMinor: null },
    ]);
    expect(() => loadConfig({ ...base, SVIP_TIERS: '2000,1000' })).toThrow();
    expect(() => loadConfig({ ...base, WALLET_RECHARGE_PACKAGES: '100+0:99:50' })).toThrow();
    expect(() => loadConfig({ ...base, WALLET_RECHARGE_CURRENCY: 'usd' })).toThrow();
    expect(() => loadConfig({ ...base, TASK_DAILY_CAP_COINS: '0' })).toThrow();
    expect(() => loadConfig({ ...base, TASK_DAILY_CAP_CHERRIES: '0' })).toThrow();
    expect(
      loadConfig({ ...base, TASK_CHERRIES_UNLOCK_GIFT_MINOR: '0' }).economy.taskCherriesUnlockGiftMinor,
    ).toBe(0);
    expect(loadConfig({ ...base, TASK_MONTHLY_CAP_MINOR: '0' }).programs.taskMonthlyCapMinor).toBe(0);
    expect(loadConfig({ ...base, COIN_RETAIL_USD_PER_MILLION: '9.99' }).economy.coinRetailUsdPerMillion).toBe(
      9.99,
    );
    for (const bad of ['0', '-1', '1e3', '12,5', 'abc']) {
      expect(() => loadConfig({ ...base, COIN_RETAIL_USD_PER_MILLION: bad }), bad).toThrow();
    }
  });
});
