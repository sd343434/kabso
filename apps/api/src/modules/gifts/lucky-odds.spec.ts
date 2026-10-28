import { describe, expect, it } from 'vitest';
import { loadConfig } from '../../config/app-config.js';
import {
  budgetLeft,
  capWins,
  drawWinners,
  expectedReturnBps,
  expectedReturnWithPity,
  LUCKY_CHANCE_SCALE,
  luckyResultDto,
  luckyTable,
  outcomeOf,
  percentToBps,
  settleDraws,
  shareOf,
  type LuckyRng,
  type LuckyTable,
  type PityRule,
} from './lucky-odds.js';

/** D148 (owner 2026-10-28): eight tiers, the chances per million, the guarantee after 15 losses. */
const TIERS = [5, 10, 25, 50, 100, 250, 500, 1000];
const CHANCES = [48_918, 15_451, 3_903, 1_464, 569, 130, 40, 12];
const PITY: PityRule = { after: 15, multiplier: 5 };
const DEFAULT = luckyTable(8500, 1000, TIERS, CHANCES, PITY) as LuckyTable;
/** The D132 table (×5…×500 from shares 40/25/15/12/8 of 85 %), for the arithmetic tests. */
const D132 = luckyTable(
  8500,
  1000,
  [5, 10, 50, 100, 500],
  [68_000, 21_250, 2_550, 1_020, 136],
  null,
) as LuckyTable;

/**
 * A deterministic generator so the tests never flake (the server uses crypto.randomInt):
 * xoshiro128** seeded with splitmix32, mapped to [0, max) by the high bits. (A plain xorshift32
 * `% max` has serial correlation: it under-counts long losing streaks, i.e. the guarantee.)
 */
function seeded(seed: number): LuckyRng {
  let z = seed >>> 0;
  const split = () => {
    z = (z + 0x9e3779b9) >>> 0;
    let t = z;
    t = Math.imul(t ^ (t >>> 16), 0x21f0aaad);
    t = Math.imul(t ^ (t >>> 15), 0x735a2d97);
    return (t ^ (t >>> 15)) >>> 0;
  };
  const s = [split(), split(), split(), split()];
  const rotl = (x: number, k: number) => ((x << k) | (x >>> (32 - k))) >>> 0;
  const next = () => {
    const result = Math.imul(rotl(Math.imul(s[1]!, 5) >>> 0, 7), 9) >>> 0;
    const t = (s[1]! << 9) >>> 0;
    s[2] = (s[2]! ^ s[0]!) >>> 0;
    s[3] = (s[3]! ^ s[1]!) >>> 0;
    s[1] = (s[1]! ^ s[2]) >>> 0;
    s[0] = (s[0]! ^ s[3]) >>> 0;
    s[2] = (s[2] ^ t) >>> 0;
    s[3] = rotl(s[3], 11);
    return result;
  };
  return { int: (max) => Math.floor((next() / 4_294_967_296) * max) };
}

/** The realised return of `draws` draws by one sender, sends of `perSend` draws, no budget limit. */
function simulate(table: LuckyTable, draws: number, perSend: number, seed: number) {
  const rng = seeded(seed);
  const multipliers = table.outcomes.map((o) => o.multiplier);
  let losses = 0;
  let won = 0n;
  let guaranteed = 0;
  const hits = new Map<number, number>();
  for (let done = 0; done < draws; done += perSend) {
    const n = Math.min(perSend, draws - done);
    const settled = settleDraws(
      drawWinners(table, n, rng),
      n,
      1,
      multipliers,
      10n ** 15n,
      table.pity,
      losses,
    );
    losses = settled.lossesAfter;
    won += settled.coinsWon;
    guaranteed += settled.guaranteed;
    for (const [, , paid] of settled.wins) hits.set(paid, (hits.get(paid) ?? 0) + 1);
  }
  return { rtp: Number(won) / draws, guaranteedShare: guaranteed / draws, hits };
}

describe('D148 lucky odds: eight tiers, chances per million, the guarantee (CONVENTIONS §10.27)', () => {
  it('the owner defaults: ×5…×1000, the published chances, 85 % with the guarantee', () => {
    expect(Array.isArray(DEFAULT)).toBe(false);
    expect(DEFAULT.outcomes).toEqual(
      TIERS.map((multiplier, i) => ({ multiplier, chancePerMillion: CHANCES[i] })),
    );
    expect(DEFAULT.noWinChancePerMillion).toBe(929_513);
    expect(DEFAULT.noWinChancePerMillion + DEFAULT.outcomes.reduce((a, o) => a + o.chancePerMillion, 0)).toBe(
      LUCKY_CHANCE_SCALE,
    );
    expect(DEFAULT.pity).toEqual(PITY);
    // The draws alone return 69.1275 %; the guarantee brings it to 84.9999 % (never above 85).
    expect(expectedReturnBps(DEFAULT)).toBe(6912.75);
    const rtp = expectedReturnWithPity(DEFAULT);
    expect(rtp).toBeLessThanOrEqual(0.85);
    expect(rtp).toBeGreaterThan(0.84999);
    // Big ones very rare: ×1000 is 1 in 83 333, ×500 1 in 25 000, ×250 1 in 7 692.
    expect(LUCKY_CHANCE_SCALE / DEFAULT.outcomes[7]!.chancePerMillion).toBeGreaterThan(80_000);
  });

  it('the numbers first proposed (48 330 … 12) return 84.46 % with the guarantee — scaled up to 85 %', () => {
    const proposed = luckyTable(
      8500,
      1000,
      TIERS,
      [48_330, 15_304, 3_866, 1_450, 564, 129, 40, 12],
      PITY,
    ) as LuckyTable;
    expect(expectedReturnBps(proposed)).toBe(6844.9);
    expect(expectedReturnWithPity(proposed)).toBeCloseTo(0.844574, 5);
    // Without the guarantee the draws alone would return 68.4 %; an exact ×5 in place of the draw
    // (instead of «at least ×5») would give 83.3 %.
    expect(expectedReturnWithPity({ outcomes: proposed.outcomes, pity: null })).toBeCloseTo(0.68449, 6);
  });

  it('the exact formula matches a brute-force walk of the losing streak', () => {
    // Iterate the streak distribution draw by draw until it settles; average the return.
    for (const table of [
      DEFAULT,
      luckyTable(8000, 1000, [2, 5, 50], [100_000, 20_000, 1_000], { after: 3, multiplier: 2 }) as LuckyTable,
    ]) {
      const pity = table.pity!;
      const p = table.outcomes.map((o) => o.chancePerMillion / LUCKY_CHANCE_SCALE);
      const q = 1 - p.reduce((a, b) => a + b, 0);
      const base = table.outcomes.reduce((a, o, i) => a + p[i]! * o.multiplier, 0);
      const guaranteedReturn = table.outcomes.reduce(
        (a, o, i) => a + p[i]! * Math.max(o.multiplier, pity.multiplier),
        q * pity.multiplier,
      );
      let dist: number[] = Array.from({ length: pity.after + 1 }, (_, k) => (k === 0 ? 1 : 0));
      let total = 0;
      const steps = 20_000;
      for (let step = 0; step < steps; step += 1) {
        const next = dist.map(() => 0);
        for (let k = 0; k <= pity.after; k += 1) {
          if (k === pity.after) {
            total += dist[k]! * guaranteedReturn;
            next[0]! += dist[k]!;
          } else {
            total += dist[k]! * base;
            next[k + 1]! += dist[k]! * q;
            next[0]! += dist[k]! * (1 - q);
          }
        }
        dist = next;
      }
      expect(total / steps).toBeCloseTo(expectedReturnWithPity(table), 3);
    }
  });

  it('10 000 000 seeded draws: the realised return is 85 % ± 0.6; 3.42 % of draws are guarantee draws, 3.18 % paid by it', () => {
    const run = simulate(DEFAULT, 10_000_000, 100, 0x9e3779b9);
    process.stderr.write(
      `[D148 RTP] 10M draws (seed 0x9e3779b9, sends of 100): return ${(run.rtp * 100).toFixed(3)} %, guaranteed ${(run.guaranteedShare * 100).toFixed(3)} % of draws, wins ${JSON.stringify([...run.hits.entries()].sort((a, b) => a[0] - b[0]))}\n`,
    );
    expect(Math.abs(run.rtp - 0.85)).toBeLessThan(0.006);
    // A guarantee draw (π_15 = q^15 / Σ_{k≤15} q^k = 3.415 % of draws) that also wins on its own pays
    // its own win; the guarantee itself pays on π_15 × q = 3.174 % of draws.
    const q = DEFAULT.noWinChancePerMillion / LUCKY_CHANCE_SCALE;
    const sum = Array.from({ length: 16 }, (_, k) => q ** k).reduce((a, b) => a + b, 0);
    expect(run.guaranteedShare).toBeCloseTo((q ** 15 / sum) * q, 3);
    // Every tier is hit, ×1000 about 12 times per million.
    for (const m of TIERS) expect(run.hits.get(m) ?? 0).toBeGreaterThan(0);
  });

  it('refuses invalid tables (the server would not start)', () => {
    const bad = (rtp: number, host: number, m: number[], c: number[], pity: PityRule | null = null) =>
      luckyTable(rtp, host, m, c, pity);
    expect(bad(10_000, 0, [5], [1000])).toEqual(['the return (RTP) must be 1–99 %']);
    expect(bad(9500, 1000, [5], [1000])).toEqual([
      'the return plus the host share must not pass 100 % (the platform would pay out more than it takes)',
    ]);
    expect(bad(8500, 1000, [10, 5], [10, 10])).toHaveLength(1);
    expect(bad(8500, 1000, [1, 5], [10, 10])).toHaveLength(1);
    expect(bad(8500, 1000, [5, 10], [10])).toEqual([
      'the chances must be whole numbers ≥ 1 per million, one per multiplier',
    ]);
    expect(bad(8500, 1000, [5, 10], [10, 0])).toHaveLength(1);
    expect(bad(8500, 1000, [2, 3], [600_000, 500_000])).toEqual([
      'the winning chances add up to more than 100 %',
    ]);
    expect(bad(8500, 1000, [5, 10], [10, 10], { after: 15, multiplier: 7 })).toEqual([
      'the guarantee must come after 1–1000 losing draws and pay one of the multipliers',
    ]);
    expect(bad(8500, 1000, [5, 10], [10, 10], { after: 0, multiplier: 5 })).toHaveLength(1);
    // The return with the guarantee must not pass R: the D132 table (85 % alone) plus a guarantee.
    expect(bad(8500, 1000, [5, 10, 50, 100, 500], [68_000, 21_250, 2_550, 1_020, 136], PITY)).toEqual([
      expect.stringMatching(
        /^the chances return 9[0-9]\.[0-9]{4} % with the guarantee, more than the configured 85 %/,
      ),
    ]);
    expect(bad(8500, 1000, [5, 10, 50, 100, 500], [68_000, 21_250, 2_550, 1_020, 136])).not.toBeInstanceOf(
      Array,
    );
  });

  it('parses percentages with at most two decimals', () => {
    expect(percentToBps('85')).toBe(8500);
    expect(percentToBps('85.5')).toBe(8550);
    expect(percentToBps('10.25')).toBe(1025);
    expect(percentToBps(' 0 ')).toBe(0);
    for (const raw of ['', '85%', '-1', '1e2', '85.555', '085', 'abc']) expect(percentToBps(raw)).toBeNull();
  });

  it('loadConfig: the defaults are the owner table; an invalid table, the D132 shares or a country list without a header refuse to start', () => {
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
    expect(loadConfig({ ...base, LUCKY_PITY_AFTER: '0' }).lucky.table.pity).toBeNull();
    expect(loadConfig({ ...base, LUCKY_PITY_AFTER: '20' }).lucky.table.pity).toEqual({
      after: 20,
      multiplier: 5,
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
      { LUCKY_GIFT_RTP_SHARES: '40,25,15,12,8' },
      { LUCKY_GIFT_CHANCES_PER_MILLION: '48918,15451,3903,1464,569,130,40' },
      { LUCKY_GIFT_CHANCES_PER_MILLION: '60000,15451,3903,1464,569,130,40,12' }, // > 85 %
      { LUCKY_PITY_MULTIPLIER: '7' },
      { LUCKY_PITY_MULTIPLIER: '10' }, // a ×10 guarantee returns 89 % > 85 %
      { LUCKY_PITY_AFTER: '-1' },
      { LUCKY_PITY_AFTER: '1001' },
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
    expect(outcomeOf(DEFAULT, 48_917)).toBe(5);
    expect(outcomeOf(DEFAULT, 48_918)).toBe(10);
    expect(outcomeOf(DEFAULT, 64_369)).toBe(25);
    expect(outcomeOf(DEFAULT, 68_272)).toBe(50);
    expect(outcomeOf(DEFAULT, 69_736)).toBe(100);
    expect(outcomeOf(DEFAULT, 70_305)).toBe(250);
    expect(outcomeOf(DEFAULT, 70_435)).toBe(500);
    expect(outcomeOf(DEFAULT, 70_475)).toBe(1000);
    expect(outcomeOf(DEFAULT, 70_486)).toBe(1000);
    expect(outcomeOf(DEFAULT, 70_487)).toBe(0);
    expect(outcomeOf(DEFAULT, 999_999)).toBe(0);
  });

  it('returns only the winning draws, in order, one rng call per draw', () => {
    const values = [999_999, 0, 500_000, 70_480, 50_000];
    let calls = 0;
    const rng: LuckyRng = {
      int: (max) => {
        expect(max).toBe(LUCKY_CHANCE_SCALE);
        return values[calls++]!;
      },
    };
    expect(drawWinners(DEFAULT, 5, rng)).toEqual([
      [1, 5],
      [3, 1000],
      [4, 10],
    ]);
    expect(calls).toBe(5);
  });

  it('over many seeded draws the realised return of the draws alone is close to the table (D132 table, 85 %)', () => {
    const rng = seeded(0x9e3779b9);
    const n = 2_000_000;
    const won = drawWinners(D132, n, rng).reduce((a, [, m]) => a + m, 0);
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
      guaranteed: false,
    });
    expect(luckyResultDto(3, [], 10, 0)).toEqual({
      draws: 3,
      wins: [],
      coinsWon: 0,
      topMultiplier: null,
      downgraded: 0,
      guaranteed: false,
    });
    // D148: a draw paid above what it drew is the guarantee.
    expect(luckyResultDto(16, [[15, 0, 5]], 10, 0)).toMatchObject({
      wins: [{ multiplier: 5, count: 1, coins: 50 }],
      topMultiplier: 5,
      guaranteed: true,
    });
  });

  it('the host share is floor(value × 10 %), exact for large values', () => {
    expect(shareOf(100, 1000)).toBe(10);
    expect(shareOf(9, 1000)).toBe(0);
    expect(shareOf(25_000_000_000_000, 1000)).toBe(2_500_000_000_000);
    expect(shareOf(123, 10_000)).toBe(123);
  });
});

describe('D148 the guarantee (pity, option B) and the daily protection', () => {
  const BIG = 10n ** 12n;
  it('15 losing draws, then the 16th pays ×5 (guaranteed); the streak restarts at 0', () => {
    const s = settleDraws([], 16, 10, TIERS, BIG, PITY, 0);
    expect(s.wins).toEqual([[15, 0, 5]]);
    expect(s.coinsWon).toBe(50n);
    expect(s.guaranteed).toBe(1);
    expect(s.downgraded).toBe(0);
    expect(s.lossesAfter).toBe(0);
    // 31 losing draws: the 16th is guaranteed, then 15 more losses.
    const t = settleDraws([], 31, 10, TIERS, BIG, PITY, 0);
    expect(t.wins).toEqual([[15, 0, 5]]);
    expect(t.lossesAfter).toBe(15);
  });

  it('the streak carries over from earlier sends (any room): 14 before + 1 loss → the next draw is guaranteed', () => {
    expect(settleDraws([], 1, 10, TIERS, BIG, PITY, 14)).toMatchObject({ wins: [], lossesAfter: 15 });
    expect(settleDraws([], 1, 10, TIERS, BIG, PITY, 15)).toMatchObject({
      wins: [[0, 0, 5]],
      guaranteed: 1,
      lossesAfter: 0,
    });
  });

  it('any win resets the streak; a draw that wins on the guaranteed draw pays what it won (at least ×5)', () => {
    expect(settleDraws([[3, 10]], 10, 10, TIERS, BIG, PITY, 10)).toMatchObject({
      wins: [[3, 10, 10]],
      guaranteed: 0,
      lossesAfter: 6,
    });
    // Draw 1 is the guaranteed one (14 + 1 loss before it) and drew ×500: pays ×500, not ×5.
    expect(settleDraws([[1, 500]], 2, 10, TIERS, BIG, PITY, 14)).toMatchObject({
      wins: [[1, 500, 500]],
      guaranteed: 0,
      lossesAfter: 0,
    });
    // Off: never guaranteed.
    expect(settleDraws([], 40, 10, TIERS, BIG, null, 0)).toMatchObject({ wins: [], lossesAfter: 40 });
  });

  it('daily protection: a guarantee that does not fit pays nothing and stays due on the next draw', () => {
    // Budget 49 < ×5 × 10 = 50: draws 15 and 16 are due ×5 but cannot be paid.
    const s = settleDraws([], 17, 10, TIERS, 49n, PITY, 0);
    expect(s.wins).toEqual([
      [15, 0, 0],
      [16, 0, 0],
    ]);
    expect(s.coinsWon).toBe(0n);
    expect(s.downgraded).toBe(2);
    expect(s.guaranteed).toBe(0);
    expect(s.lossesAfter).toBe(17);
    expect(luckyResultDto(17, s.wins, 10, s.downgraded)).toMatchObject({
      topMultiplier: null,
      guaranteed: false,
    });
    // The next send, with budget: its first draw is the guarantee.
    expect(settleDraws([], 1, 10, TIERS, 50n, PITY, s.lossesAfter)).toMatchObject({
      wins: [[0, 0, 5]],
      coinsWon: 50n,
      guaranteed: 1,
      budgetAfter: 0n,
      lossesAfter: 0,
    });
  });

  it('daily protection: a win larger than what is left is cut to the largest tier that fits — a win all the same', () => {
    // ×1000 × 10 = 10 000 coins due, 3 000 left → ×250 (2 500) paid, 500 left; streak reset.
    const s = settleDraws([[2, 1000]], 4, 10, TIERS, 3_000n, PITY, 15);
    // Draw 0 is the guarantee (15 losses before): ×5 = 50 → 2 950 left; draw 2: ×1000 → ×250.
    expect(s.wins).toEqual([
      [0, 0, 5],
      [2, 1000, 250],
    ]);
    expect(s.coinsWon).toBe(2_550n);
    expect(s.budgetAfter).toBe(450n);
    expect(s.downgraded).toBe(1);
    expect(s.guaranteed).toBe(1);
    expect(s.lossesAfter).toBe(1);
  });

  it('never pays more than the budget, guarantee included, whatever the draws and the streak', () => {
    const rng = seeded(7);
    for (const budget of [0n, 49n, 50n, 999n, 12_345n, 1_000_000n]) {
      for (let k = 0; k < 50; k += 1) {
        const draws = 1 + rng.int(200);
        const winners = drawWinners(DEFAULT, draws, rng);
        const s = settleDraws(winners, draws, 1 + rng.int(500), TIERS, budget, PITY, rng.int(30));
        expect(s.coinsWon).toBeLessThanOrEqual(budget);
        expect(s.budgetAfter).toBe(budget - s.coinsWon);
        expect(s.lossesAfter).toBeGreaterThanOrEqual(0);
      }
    }
  });
});
