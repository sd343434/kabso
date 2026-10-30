import { randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { loadConfig } from '../../config/app-config.js';
import {
  CHECK_IN_CYCLE_DAYS,
  DEFAULT_TASKS,
  TASK_METRICS,
  cappedReward,
  checkInCycleDay,
  checkInReward,
  isTaskMetric,
  parseEventPrizes,
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
    expect(
      rows.map((m) => ({
        code: m[1],
        period: m[2],
        metric: m[3],
        target: Number(m[4]),
        // D184: seeded in coins; migrations 20261231110000_task_cherries (×10) and
        // 20261231120000_task_rewards_raise (×300) made them cherries.
        rewardCherries: Number(m[5]) * 3000,
        audience: m[6],
        nameAr: m[7],
        nameEn: m[8],
        sortOrder: Number(m[9]),
      })),
    ).toEqual(DEFAULT_TASKS);
  });

  it('knows the task metrics', () => {
    // D166's six, then D176's twelve daily-pool metrics (v1.50-social).
    expect(TASK_METRICS.slice(0, 6)).toEqual([
      'WATCH_LIVES',
      'FOLLOWS',
      'LIVE_CHAT_MESSAGES',
      'GIFT_SENDS',
      'HOST_LIVE_MINUTES',
      'HOST_GIFT_COINS',
    ]);
    expect(TASK_METRICS).toHaveLength(18);
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
    // D184: task rewards are cherries — owner: ≈ $5 a month at most, 150 000 a day.
    expect(programs.taskDailyCapCherries).toBe(150_000);
    // D184: task cherries unlock for withdrawal at $50 of lifetime gift cherries (owner rule).
    expect(loadConfig(base).economy.taskCherriesUnlockGiftMinor).toBe(5000);
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
  });
});
