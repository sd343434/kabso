import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { versionConfigIssues } from './level-config.rules.js';
import {
  COINS_PER_USD,
  PRESET_LEVELS,
  PRESET_MULTIPLIER,
  presetCoinsAt,
  presetLadder,
  presetTier,
} from './level-preset.js';
import { MAX_POINTS, parseMultiplier, pointsFor } from './points-math.js';

const at = (n: number) => presetLadder()[n - 1]?.requiredPoints;

/** USD cents (floored) of `coins` at retail 1 000 000 coins = $12.50. */
const cents = (coins: bigint) => (coins * 100n) / COINS_PER_USD;

describe('owner ladder preset (D194, option B)', () => {
  it('is publishable in every category', () => {
    for (const category of ['ATTRACTIVENESS', 'SUPPORT', 'WIZARD', 'GAMING'] as const) {
      expect(
        versionConfigIssues({
          category,
          multiplier: PRESET_MULTIPLIER,
          valueUnit: 'COIN',
          luckyGiftsCountAsSupport: false,
          levels: presetLadder(),
        }),
      ).toEqual([]);
    }
    expect(presetLadder()).toHaveLength(PRESET_LEVELS);
  });

  it('steps by the owner table, in coins per level', () => {
    const coinSteps = new Map<number, bigint>();
    for (let n = 2; n <= 100; n++) coinSteps.set(n, presetCoinsAt(n) - presetCoinsAt(n - 1));
    const band = (from: number, to: number, coins: bigint) => {
      for (let n = from; n <= to; n++) expect(coinSteps.get(n), `level ${String(n)}`).toBe(coins);
    };
    band(2, 10, 45_000n);
    band(11, 20, 200_000n);
    band(21, 30, 1_000_000n);
    band(31, 40, 3_600_000n);
    band(41, 50, 11_000_000n);
    band(51, 60, 32_000_000n);
    band(61, 80, 136_000_000n);
    band(81, 99, 590_000_000n);
    band(100, 100, 5_600_000_000n);
    // Never easier as levels go up.
    const steps = [...coinSteps.values()];
    for (let i = 1; i < steps.length; i++) expect(steps[i]! >= steps[i - 1]!).toBe(true);
  });

  it('cumulative coins and USD at the band ends', () => {
    const table = [10, 20, 30, 40, 50, 60, 80, 99, 100].map((n) => [
      n,
      presetCoinsAt(n),
      cents(presetCoinsAt(n)),
    ]);
    expect(table).toEqual([
      [10, 405_000n, 506n],
      [20, 2_405_000n, 3_006n],
      [30, 12_405_000n, 15_506n],
      [40, 48_405_000n, 60_506n],
      [50, 158_405_000n, 198_006n],
      [60, 478_405_000n, 598_006n],
      [80, 3_198_405_000n, 3_998_006n],
      [99, 14_408_405_000n, 18_010_506n],
      [100, 20_008_405_000n, 25_010_506n],
    ]);
  });

  it('level 100 needs at least 20 billion coins = $250 000', () => {
    expect(presetCoinsAt(100) >= 20_000_000_000n).toBe(true);
    expect(cents(presetCoinsAt(100)) >= 25_000_000n).toBe(true);
    expect(at(100)).toBe(2_000_840_500n);
    expect(at(100)! < MAX_POINTS).toBe(true);
  });

  it('keeps 1 point per 10 coins', () => {
    const m = parseMultiplier(PRESET_MULTIPLIER)!;
    expect(pointsFor(405_000n, m)).toBe(at(10));
    expect(pointsFor(20_008_405_000n, m)).toBe(at(100));
    expect(pointsFor(20_008_404_999n, m) < at(100)!).toBe(true);
    expect(pointsFor(9n, m)).toBe(0n);
  });

  it('names and art follow the badge tiers', () => {
    expect([presetTier(1), presetTier(9), presetTier(10), presetTier(99), presetTier(100)]).toEqual([
      1, 1, 2, 10, 11,
    ]);
    const l = presetLadder();
    expect([l[0]?.nameEn, l[9]?.nameEn, l[99]?.nameEn]).toEqual(['Iron', 'Bronze', 'Legend']);
    expect([l[0]?.iconKey, l[99]?.iconKey]).toEqual(['tier_01', 'tier_11']);
  });

  it('is the ladder the D194 migration publishes, row for row', () => {
    const sql = readFileSync(
      new URL('../../../prisma/migrations/20270104090000_level_ladder_d194/migration.sql', import.meta.url),
      'utf8',
    );
    const rows = [...sql.matchAll(/^ {2}\((\d+), '([^']*)', '([^']*)', (\d+), '([^']*)'\)[,;]$/gmu)].map(
      (m) => ({
        levelNumber: Number(m[1]),
        nameAr: m[2],
        nameEn: m[3],
        requiredPoints: BigInt(m[4] ?? '0'),
        iconKey: m[5],
      }),
    );
    expect(rows).toEqual(presetLadder());
  });
});
