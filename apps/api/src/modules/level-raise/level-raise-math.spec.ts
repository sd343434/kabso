import { describe, expect, it } from 'vitest';
import { presetLadder } from '../levels/level-preset.js';
import {
  DEFAULT_RAISE_SETTINGS,
  approvalIssue,
  ladderLevel,
  levelBonus,
  proposeLevel,
  rechargeCap,
  sourceEquivalent,
  xpAt,
  type ProposalInput,
  type SourceAppMath,
} from './level-raise-math.js';

const ladder = presetLadder();
/** The published SUPPORT multiplier 0.1 (D194), scaled by 10^6. */
const MULT = 100_000n;

/** Zafa, confirmed by the owner: 1M coins = $20, 10 coins = 1 XP, level 32 = 27 742 536 XP. */
const zafa: SourceAppMath = {
  mode: 'MONEY',
  usdPerMillionCents: 2_000n,
  coinsPerXpMilli: 10_000n,
  xpTable: [{ level: 32, xp: 27_742_536n, confidence: 'CONFIRMED' }],
  factorMilli: null,
  confidence: 'CONFIRMED',
};
const other: SourceAppMath = {
  mode: 'FACTOR',
  usdPerMillionCents: null,
  coinsPerXpMilli: null,
  xpTable: [],
  factorMilli: 500,
  confidence: 'ESTIMATE',
};

function input(over: Partial<ProposalInput>): ProposalInput {
  return {
    app: zafa,
    sourceLevel: 32,
    ladder,
    multiplierScaled: MULT,
    totalRechargeCoins: 1_000_000n,
    firstDaysRechargeCoins: 1_000_000n,
    currentSupportLevel: 0,
    currentCharmLevel: 0,
    settings: DEFAULT_RAISE_SETTINGS,
    ...over,
  };
}

describe('xpAt (interpolation)', () => {
  const table = [
    { level: 10, xp: 1_000n, confidence: 'ESTIMATE' as const },
    { level: 20, xp: 100_000n, confidence: 'ESTIMATE' as const },
  ];
  it('is exact on a known point', () => {
    expect(xpAt(table, 10, 30)).toMatchObject({ xp: 1_000n, method: 'TABLE' });
  });
  it('interpolates geometrically between two points', () => {
    // halfway between 1 000 and 100 000 in log space = 10 000
    expect(xpAt(table, 15, 30)).toMatchObject({ xp: 10_000n, method: 'INTERPOLATED' });
    const e = xpAt(table, 12, 30)!;
    expect(e.xp > 1_000n && e.xp < 10_000n).toBe(true);
  });
  it('interpolates linearly from a zero point', () => {
    const t = [
      { level: 1, xp: 0n, confidence: 'ESTIMATE' as const },
      { level: 11, xp: 1_000n, confidence: 'ESTIMATE' as const },
    ];
    expect(xpAt(t, 6, 30)?.xp).toBe(500n);
  });
  it('uses a power curve below the lowest point', () => {
    // 1 000 × (5 / 10)^3 = 125
    expect(xpAt(table, 5, 30)).toMatchObject({ xp: 125n, method: 'BELOW_TABLE' });
  });
  it('never extrapolates above the highest point', () => {
    expect(xpAt(table, 50, 30)).toMatchObject({ xp: 100_000n, method: 'ABOVE_TABLE_CLAMPED' });
  });
  it('is null for an empty table', () => {
    expect(xpAt([], 5, 30)).toBeNull();
  });
});

describe('sourceEquivalent (money conversion)', () => {
  it('reproduces the owner Zafa example exactly: level 32 → $5 548.50 → Kabso level 58', () => {
    const s = sourceEquivalent(zafa, 32, ladder, MULT, DEFAULT_RAISE_SETTINGS);
    expect(s).toMatchObject({
      mode: 'MONEY',
      xp: 27_742_536n,
      xpMethod: 'TABLE',
      sourceCoins: 277_425_360n,
      usdCents: 554_850n,
      kabsoCoins: 443_880_576n,
      kabsoPoints: 44_388_057n,
      level: 58,
    });
    // Level 58 starts at 41 440 500 points, level 59 at 44 640 500 (D194 ladder).
    expect(ladder[57]!.requiredPoints).toBe(41_440_500n);
    expect(ladder[58]!.requiredPoints).toBe(44_640_500n);
  });
  it('a lower Zafa level is derived from the one known point (power curve, estimate)', () => {
    const s = sourceEquivalent(zafa, 16, ladder, MULT, DEFAULT_RAISE_SETTINGS);
    expect(s.mode).toBe('MONEY');
    if (s.mode === 'MONEY') {
      expect(s.xpMethod).toBe('BELOW_TABLE');
      expect(s.xp).toBe(27_742_536n / 8n);
      expect(s.level).toBeLessThan(58);
    }
  });
  it('the unknown / other app uses the conservative factor', () => {
    expect(sourceEquivalent(other, 32, ladder, MULT, DEFAULT_RAISE_SETTINGS)).toEqual({
      mode: 'FACTOR',
      factorMilli: 500,
      level: 16,
    });
  });
  it('an app without usable data counts as level 0', () => {
    const broken: SourceAppMath = { ...zafa, xpTable: [] };
    expect(sourceEquivalent(broken, 32, ladder, MULT, DEFAULT_RAISE_SETTINGS)).toEqual({
      mode: 'NONE',
      level: 0,
    });
  });
  it('ladderLevel reads the real ladder', () => {
    expect(ladderLevel(ladder, 0n)).toBe(1);
    expect(ladderLevel(ladder, 100_000n)).toBe(12); // 1 000 000 coins recharged and all spent = level 12
    expect(ladderLevel([], 5n)).toBe(0);
  });
});

describe('caps and bonuses', () => {
  it('first-days cap: 1M → 20, 2M → 24, 32M → 40, more stays 40', () => {
    const cap = (c: bigint) => rechargeCap(c, 1_000_000n, 20, 40);
    expect(cap(1_000_000n)).toBe(20);
    expect(cap(2_000_000n)).toBe(24);
    expect(cap(32_000_000n)).toBe(40);
    expect(cap(500_000_000n)).toBe(40);
    expect(cap(0n)).toBe(0);
    expect(cap(1_000n)).toBe(0);
  });
  it('total cap is lower: 1M → 15', () => {
    expect(rechargeCap(1_000_000n, 1_000_000n, 15, 40)).toBe(15);
  });
  it('bonuses are small and capped', () => {
    expect(levelBonus(9, 1, 2)).toBe(0);
    expect(levelBonus(10, 1, 2)).toBe(1);
    expect(levelBonus(35, 1, 2)).toBe(2);
    expect(levelBonus(35, 0, 2)).toBe(0);
  });
});

describe('proposeLevel (the owner examples and clamps)', () => {
  it('1M recharged in the first week, Zafa 32 → 20 (owner ≈ 15–25)', () => {
    const p = proposeLevel(input({}));
    expect(p.source.level).toBe(58);
    expect(p.firstDaysCap).toBe(20);
    expect(p.totalCap).toBe(15);
    expect(p.proposedLevel).toBe(20);
    expect(p.limitedBy).toBe('RECHARGE');
    expect(p.eligible).toBe(true);
  });
  it('1M recharged after the first week → 15 (still inside ≈ 15–25)', () => {
    const p = proposeLevel(input({ firstDaysRechargeCoins: 0n }));
    expect(p.proposedLevel).toBe(15);
  });
  it('32M recharged in the first week → 40 (owner)', () => {
    const p = proposeLevel(input({ totalRechargeCoins: 32_000_000n, firstDaysRechargeCoins: 32_000_000n }));
    expect(p.proposedLevel).toBe(40);
  });
  it('a big source level with little Kabso recharge cannot reach 40', () => {
    const p = proposeLevel(
      input({ sourceLevel: 32, totalRechargeCoins: 1_500_000n, firstDaysRechargeCoins: 1_500_000n }),
    );
    expect(p.proposedLevel).toBeLessThan(40);
    expect(p.proposedLevel).toBe(22);
  });
  it('never above 40, whatever the recharge and bonuses', () => {
    const p = proposeLevel(
      input({
        totalRechargeCoins: 10_000_000_000n,
        firstDaysRechargeCoins: 10_000_000_000n,
        currentSupportLevel: 35,
        currentCharmLevel: 90,
      }),
    );
    expect(p.proposedLevel).toBe(40);
  });
  it('never below the current level', () => {
    const p = proposeLevel(input({ currentSupportLevel: 33 }));
    expect(p.proposedLevel).toBe(33);
    expect(p.limitedBy).toBe('CURRENT_LEVEL');
    const high = proposeLevel(input({ currentSupportLevel: 55 }));
    expect(high.proposedLevel).toBe(55);
  });
  it('the source level limits when it is the lower one; bonuses add to it', () => {
    const p = proposeLevel(
      input({
        app: other,
        sourceLevel: 20,
        totalRechargeCoins: 32_000_000n,
        firstDaysRechargeCoins: 32_000_000n,
        currentSupportLevel: 10,
        currentCharmLevel: 20,
      }),
    );
    // factor 0.5 → 10, + support 1 + charm 2 = 13
    expect(p.source.level).toBe(10);
    expect(p.supportBonus).toBe(1);
    expect(p.charmBonus).toBe(2);
    expect(p.proposedLevel).toBe(13);
    expect(p.limitedBy).toBe('SOURCE');
  });
  it('unknown app default: Zafa-sized level 32 gives only 16 even with 32M recharged', () => {
    const p = proposeLevel(
      input({ app: other, totalRechargeCoins: 32_000_000n, firstDaysRechargeCoins: 32_000_000n }),
    );
    expect(p.proposedLevel).toBe(16);
  });
  it('eligibility: below 1 000 000 recharged is not eligible', () => {
    expect(
      proposeLevel(input({ totalRechargeCoins: 999_999n, firstDaysRechargeCoins: 999_999n })).eligible,
    ).toBe(false);
  });
});

describe('approvalIssue', () => {
  it('allows the proposal or lower, never higher, never below current, never above 40', () => {
    expect(approvalIssue(20, 20, 5)).toBeNull();
    expect(approvalIssue(12, 20, 5)).toBeNull();
    expect(approvalIssue(21, 20, 5)).toBe('level_raise_above_proposal');
    expect(approvalIssue(4, 20, 5)).toBe('level_raise_below_current');
    expect(approvalIssue(41, 45, 5)).toBe('level_raise_above_max');
    expect(approvalIssue(45, 45, 45)).toBeNull();
  });
});
