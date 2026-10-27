import { describe, expect, it } from 'vitest';
import { loadConfig } from '../../config/app-config.js';
import {
  budgetLeft,
  capWins,
  drawWinners,
  expectedReturnBps,
  LUCKY_CHANCE_SCALE,
  luckyResultDto,
  luckyTable,
  outcomeOf,
  percentToBps,
  shareOf,
  type LuckyRng,
  type LuckyTable,
} from './lucky-odds.js';

const DEFAULT = luckyTable(8500, 1000, [5, 10, 50, 100, 500], [40, 25, 15, 12, 8]) as LuckyTable;

/** Σ p_i × m_i, with p_i = chance per million / 10^6. */
const rtpOf = (t: LuckyTable) =>
  t.outcomes.reduce((a, o) => a + (o.chancePerMillion / LUCKY_CHANCE_SCALE) * o.multiplier, 0);

describe('D132 lucky odds from the return (CONVENTIONS §10.27)', () => {
  it('the owner defaults: ×5…×500, Σ p·m = 85 % exactly, the published chances', () => {
    expect(Array.isArray(DEFAULT)).toBe(false);
    expect(DEFAULT.outcomes).toEqual([
      { multiplier: 5, chancePerMillion: 68_000 },
      { multiplier: 10, chancePerMillion: 21_250 },
      { multiplier: 50, chancePerMillion: 2_550 },
      { multiplier: 100, chancePerMillion: 1_020 },
      { multiplier: 500, chancePerMillion: 136 },
    ]);
    expect(DEFAULT.noWinChancePerMillion).toBe(907_044);
    expect(DEFAULT.noWinChancePerMillion + DEFAULT.outcomes.reduce((a, o) => a + o.chancePerMillion, 0)).toBe(
      LUCKY_CHANCE_SCALE,
    );
    expect(rtpOf(DEFAULT)).toBeCloseTo(0.85, 12);
    expect(expectedReturnBps(DEFAULT)).toBe(8500);
    // Big ones very rare: ×500 is about 1 in 7 353, ×100 about 1 in 980.
    expect(LUCKY_CHANCE_SCALE / DEFAULT.outcomes[4]!.chancePerMillion).toBeGreaterThan(7000);
  });

  it.each([
    [8500, [5, 10, 50, 100, 500], [40, 25, 15, 12, 8]],
    [8000, [5, 10, 50, 100, 500], [20, 20, 20, 20, 20]],
    [9000, [2, 3, 7, 1000], [50, 30, 15, 5]],
    [8550, [5, 10, 50, 100, 500], [33, 27, 17, 13, 10]],
    [100, [2], [100]],
  ])('Σ p·m = RTP within the per-million rounding (RTP %i bps)', (rtp, multipliers, shares) => {
    const t = luckyTable(rtp, 1000, multipliers, shares) as LuckyTable;
    expect(Array.isArray(t)).toBe(false);
    const target = rtp / 10_000;
    // Each floor loses less than one draw per million of its multiplier.
    const tolerance = multipliers.reduce((a, m) => a + m, 0) / LUCKY_CHANCE_SCALE;
    expect(rtpOf(t)).toBeLessThanOrEqual(target + 1e-12);
    expect(target - rtpOf(t)).toBeLessThan(tolerance);
    expect(expectedReturnBps(t)).toBeLessThanOrEqual(rtp);
  });

  it('refuses invalid tables (the server would not start)', () => {
    const bad = (rtp: number, host: number, m: number[], s: number[]) => luckyTable(rtp, host, m, s);
    expect(bad(10_000, 0, [5], [100])).toEqual(['the return (RTP) must be 1–99 %']);
    expect(bad(9500, 1000, [5], [100])).toEqual([
      'the return plus the host share must not pass 100 % (the platform would pay out more than it takes)',
    ]);
    expect(bad(8500, 1000, [10, 5], [50, 50])).toHaveLength(1);
    expect(bad(8500, 1000, [1, 5], [50, 50])).toHaveLength(1);
    expect(bad(8500, 1000, [5, 10], [50, 40])).toEqual([
      'the return shares must be whole numbers ≥ 1, one per multiplier, summing to 100',
    ]);
    expect(bad(8500, 1000, [5, 10], [100])).toHaveLength(1);
    expect(bad(100, 1000, [5, 10_000], [99, 1])).toEqual([
      'the chance of ×10000 rounds to 0 per million; give it a larger share',
    ]);
  });

  it('parses percentages with at most two decimals', () => {
    expect(percentToBps('85')).toBe(8500);
    expect(percentToBps('85.5')).toBe(8550);
    expect(percentToBps('10.25')).toBe(1025);
    expect(percentToBps(' 0 ')).toBe(0);
    for (const raw of ['', '85%', '-1', '1e2', '85.555', '085', 'abc']) expect(percentToBps(raw)).toBeNull();
  });

  it('loadConfig: the defaults are the owner table; an invalid table or a country list without a header refuses to start', () => {
    const base = {
      DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
      REDIS_URL: 'redis://localhost:6379',
      JWT_ACCESS_SECRET: 'x'.repeat(64),
      APP_PUBLIC_URL: 'https://kabso.example/',
    };
    const config = loadConfig(base);
    expect(config.lucky).toEqual({
      enabled: false,
      table: DEFAULT,
      bigWinMultiplier: 100,
      dayTimeZone: 'UTC',
      disabledCountries: [],
      countryHeader: null,
    });
    expect(
      loadConfig({
        ...base,
        LUCKY_GIFTS_DISABLED_COUNTRIES: 'ir, KP',
        LUCKY_GIFTS_COUNTRY_HEADER: 'CF-IPCountry',
      }).lucky,
    ).toMatchObject({ disabledCountries: ['IR', 'KP'], countryHeader: 'cf-ipcountry' });
    for (const bad of [
      { LUCKY_GIFT_RTP_PERCENT: '100' },
      { LUCKY_GIFT_RTP_PERCENT: '95' }, // + 10 % host share > 100 %
      { LUCKY_GIFT_RTP_PERCENT: 'eighty' },
      { LUCKY_GIFT_MULTIPLIERS: '5,10' },
      { LUCKY_GIFT_RTP_SHARES: '50,50,0,0,0' },
      { LUCKY_GIFT_BIG_WIN_MULTIPLIER: '200' },
      { LUCKY_GIFT_DAY_TIME_ZONE: 'Mars/Base' },
      { LUCKY_GIFTS_DISABLED_COUNTRIES: 'IR' },
      { LUCKY_GIFTS_DISABLED_COUNTRIES: 'IRN', LUCKY_GIFTS_COUNTRY_HEADER: 'cf-ipcountry' },
      { LUCKY_GIFTS_ENABLED: 'yes' },
    ]) {
      expect(() => loadConfig({ ...base, ...bad }), JSON.stringify(bad)).toThrow();
    }
  });
});

describe('D132 draws', () => {
  it('maps a uniform draw onto the cumulative table', () => {
    expect(outcomeOf(DEFAULT, 0)).toBe(5);
    expect(outcomeOf(DEFAULT, 67_999)).toBe(5);
    expect(outcomeOf(DEFAULT, 68_000)).toBe(10);
    expect(outcomeOf(DEFAULT, 89_249)).toBe(10);
    expect(outcomeOf(DEFAULT, 89_250)).toBe(50);
    expect(outcomeOf(DEFAULT, 91_800)).toBe(100);
    expect(outcomeOf(DEFAULT, 92_820)).toBe(500);
    expect(outcomeOf(DEFAULT, 92_955)).toBe(500);
    expect(outcomeOf(DEFAULT, 92_956)).toBe(0);
    expect(outcomeOf(DEFAULT, 999_999)).toBe(0);
  });

  it('returns only the winning draws, in order, one rng call per draw', () => {
    const values = [999_999, 0, 500_000, 92_900, 70_000];
    let calls = 0;
    const rng: LuckyRng = {
      int: (max) => {
        expect(max).toBe(LUCKY_CHANCE_SCALE);
        return values[calls++]!;
      },
    };
    expect(drawWinners(DEFAULT, 5, rng)).toEqual([
      [1, 5],
      [3, 500],
      [4, 10],
    ]);
    expect(calls).toBe(5);
  });

  it('over many seeded draws the realised return is close to 85 %', () => {
    // A deterministic generator (xorshift) so the test never flakes; the server uses crypto.randomInt.
    let x = 0x9e3779b9;
    const rng: LuckyRng = {
      int: (max) => {
        x ^= x << 13;
        x ^= x >>> 17;
        x ^= x << 5;
        return (x >>> 0) % max;
      },
    };
    const n = 2_000_000;
    const won = drawWinners(DEFAULT, n, rng).reduce((a, [, m]) => a + m, 0);
    expect(won / n).toBeGreaterThan(0.8);
    expect(won / n).toBeLessThan(0.9);
  });
});

describe('D132 daily protection', () => {
  it('the budget is floor(spend × RTP) − paid, never below 0', () => {
    expect(budgetLeft(100n, 0n, 8500)).toBe(85n);
    expect(budgetLeft(101n, 0n, 8500)).toBe(85n);
    expect(budgetLeft(100n, 80n, 8500)).toBe(5n);
    expect(budgetLeft(100n, 90n, 8500)).toBe(0n);
  });

  it('pays wins in draw order while they fit; a win that does not fit is downgraded or withheld', () => {
    const multipliers = [5, 10, 50, 100, 500];
    // unit price 10: ×500 = 5 000, ×100 = 1 000, ×50 = 500, ×10 = 100, ×5 = 50.
    const capped = capWins(
      [
        [0, 5],
        [3, 500],
        [7, 100],
        [9, 5],
      ],
      10,
      multipliers,
      1_200n,
    );
    // 50 paid (1 150 left); ×500 does not fit → ×100 (150 left); ×100 → ×10 (50 left); ×5 = 50 (0 left).
    expect(capped.wins).toEqual([
      [0, 5, 5],
      [3, 500, 100],
      [7, 100, 10],
      [9, 5, 5],
    ]);
    expect(capped.coinsWon).toBe(1_200n);
    expect(capped.downgraded).toBe(2);
    expect(capped.budgetAfter).toBe(0n);

    const none = capWins([[2, 500]], 10, multipliers, 49n);
    expect(none).toEqual({ wins: [[2, 500, 0]], coinsWon: 0n, downgraded: 1, budgetAfter: 49n });
  });

  it('never pays more than the budget, whatever the draws', () => {
    const multipliers = [5, 10, 50, 100, 500];
    for (const budget of [0n, 1n, 49n, 50n, 999n, 12_345n]) {
      const winners = Array.from({ length: 40 }, (_, i) => [i, multipliers[i % 5]!] as [number, number]);
      const capped = capWins(winners, 7, multipliers, budget);
      expect(capped.coinsWon).toBeLessThanOrEqual(budget);
      expect(capped.budgetAfter).toBe(budget - capped.coinsWon);
    }
  });

  it('the response groups the paid draws by multiplier', () => {
    expect(
      luckyResultDto(
        12,
        [
          [0, 5, 5],
          [3, 500, 100],
          [5, 5, 5],
          [9, 50, 0],
        ],
        10,
        2,
      ),
    ).toEqual({
      draws: 12,
      wins: [
        { multiplier: 5, count: 2, coins: 100 },
        { multiplier: 100, count: 1, coins: 1_000 },
      ],
      coinsWon: 1_100,
      topMultiplier: 100,
      downgraded: 2,
    });
    expect(luckyResultDto(3, [], 10, 0)).toEqual({
      draws: 3,
      wins: [],
      coinsWon: 0,
      topMultiplier: null,
      downgraded: 0,
    });
  });

  it('the host share is floor(value × 10 %), exact for large values', () => {
    expect(shareOf(100, 1000)).toBe(10);
    expect(shareOf(9, 1000)).toBe(0);
    expect(shareOf(25_000_000_000_000, 1000)).toBe(2_500_000_000_000);
    expect(shareOf(123, 10_000)).toBe(123);
  });
});
