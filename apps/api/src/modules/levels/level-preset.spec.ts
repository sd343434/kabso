import { describe, expect, it } from 'vitest';
import { versionConfigIssues } from './level-config.rules.js';
import { PRESET_LEVELS, PRESET_MULTIPLIER, presetLadder, presetTier } from './level-preset.js';
import { parseMultiplier, pointsFor } from './points-math.js';

const at = (n: number) => presetLadder()[n - 1]?.requiredPoints;

describe('owner ladder preset', () => {
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

  it('follows the owner bands', () => {
    expect([at(1), at(2), at(10), at(11), at(20), at(30), at(40)]).toEqual([
      0n,
      10n,
      90n,
      140n,
      590n,
      2_090n,
      6_090n,
    ]);
    expect([at(50), at(60), at(80), at(99), at(100)]).toEqual([
      16_090n,
      41_090n,
      161_090n,
      446_090n,
      546_090n,
    ]);
    const steps = presetLadder()
      .slice(1)
      .map((l, i) => l.requiredPoints - (presetLadder()[i]?.requiredPoints ?? 0n));
    // Never easier as levels go up.
    for (let i = 1; i < steps.length; i++) expect(steps[i]! >= steps[i - 1]!).toBe(true);
  });

  it('1 point per 10 coins: level 10 at 900 coins, level 100 at 5,460,900', () => {
    const m = parseMultiplier(PRESET_MULTIPLIER)!;
    expect(pointsFor(900n, m)).toBe(at(10));
    expect(pointsFor(5_460_900n, m)).toBe(at(100));
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
});
