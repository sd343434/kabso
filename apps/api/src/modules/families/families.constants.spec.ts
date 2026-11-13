import { describe, expect, it } from 'vitest';
import {
  FAMILY_CREATE_COST_COINS,
  FAMILY_LEVELS,
  FAMILY_MAX_LEVEL,
  familyLevelAfter,
  familyLevelFor,
  familyNextLevelPoints,
} from './families.constants.js';
import { familyNameIssue, familyNameKey, normalizeFamilyName } from './family-name.js';

describe('family level ladder (CP-018, owner D200)', () => {
  // The owner's table (D200): minimum family points (= coins members spent) per level, and the
  // approximate USD at the retail price 1 000 000 coins = $12.50.
  const OWNER_TABLE: readonly [level: number, minPoints: number, usd: number][] = [
    [1, 0, 0],
    [2, 4_000_000, 50],
    [3, 20_000_000, 250],
    [4, 80_000_000, 1_000],
    [5, 240_000_000, 3_000],
    [6, 640_000_000, 8_000],
    [7, 1_600_000_000, 20_000],
    [8, 4_000_000_000, 50_000],
    [9, 9_600_000_000, 120_000],
    [10, 24_000_000_000, 300_000],
  ];

  it("is exactly the owner's ten steps (D200)", () => {
    expect(FAMILY_LEVELS.map((s) => [s.level, s.minPoints])).toEqual(
      OWNER_TABLE.map(([level, minPoints]) => [level, minPoints]),
    );
    expect(FAMILY_MAX_LEVEL).toBe(10);
    for (let i = 1; i < FAMILY_LEVELS.length; i++) {
      expect(FAMILY_LEVELS[i]!.minPoints).toBeGreaterThan(FAMILY_LEVELS[i - 1]!.minPoints);
    }
  });

  it('prices every threshold at the USD in the table (1 000 000 coins = $12.50)', () => {
    for (const [, minPoints, usd] of OWNER_TABLE) expect((minPoints / 1_000_000) * 12.5).toBe(usd);
  });

  it('keeps every threshold an exact safe integer (Number(points) is exact)', () => {
    for (const step of FAMILY_LEVELS) expect(Number.isSafeInteger(step.minPoints)).toBe(true);
    expect(familyLevelFor(9_007_199_254_740_991n)).toBe(10);
  });

  it('maps points to levels at every boundary (n − 1, n)', () => {
    expect(familyLevelFor(0)).toBe(1);
    for (const [level, minPoints] of OWNER_TABLE.slice(1)) {
      expect(familyLevelFor(minPoints - 1)).toBe(level - 1);
      expect(familyLevelFor(minPoints)).toBe(level);
      expect(familyLevelFor(BigInt(minPoints - 1))).toBe(level - 1);
      expect(familyLevelFor(BigInt(minPoints))).toBe(level);
    }
    // The old D106 thresholds no longer level a family up.
    expect(familyLevelFor(1_000)).toBe(1);
    expect(familyLevelFor(2_000_000)).toBe(1);
  });

  it('never lowers a stored level (the floor), and raises it when the points reach more', () => {
    // A family at level 5 under the old ladder (50 000 points) keeps level 5.
    expect(familyLevelAfter(50_000, 5)).toBe(5);
    expect(familyLevelAfter(50_000n, 10)).toBe(10);
    // It rises only at the NEW threshold of a higher level.
    expect(familyLevelAfter(640_000_000 - 1, 5)).toBe(5);
    expect(familyLevelAfter(640_000_000, 5)).toBe(6);
    // A level-1 family follows the ladder.
    expect(familyLevelAfter(4_000_000 - 1, 1)).toBe(1);
    expect(familyLevelAfter(4_000_000n, 1)).toBe(2);
    expect(familyLevelAfter(24_000_000_000, 3)).toBe(10);
  });

  it('gives the next level threshold, null at the top', () => {
    expect(familyNextLevelPoints(1)).toBe(4_000_000);
    expect(familyNextLevelPoints(5)).toBe(640_000_000);
    expect(familyNextLevelPoints(9)).toBe(24_000_000_000);
    expect(familyNextLevelPoints(10)).toBeNull();
  });
});

describe('family create cost (owner D200)', () => {
  it('is 1 000 000 coins ($12.50)', () => {
    expect(FAMILY_CREATE_COST_COINS).toBe(1_000_000);
  });
});

describe('family names (CP-018)', () => {
  const check = (raw: string) => familyNameIssue(raw, ['admin'], ['kabso']);

  it('accepts Arabic and Latin names of 2–20 graphemes', () => {
    expect(check('عائلة النجوم')).toBeNull();
    expect(check('Lions')).toBeNull();
    expect(check('أب')).toBeNull();
  });

  it('refuses too short, too long, blank, mixed-script and reserved names', () => {
    expect(check('A')).toBe('too_short');
    expect(check('')).toBe('too_short');
    expect(check('x'.repeat(21))).toBe('too_long');
    expect(check('   ')).toBe('invalid_format');
    expect(check('abcабв')).toBe('invalid_format');
    expect(check('Admin family')).toBe('reserved_term');
    expect(check('a​b')).toBe('invalid_format');
  });

  it('normalizes and keys names case-insensitively', () => {
    expect(normalizeFamilyName('  Lions  ')).toBe('Lions');
    expect(familyNameKey('LIONS')).toBe(familyNameKey('lions'));
    expect(familyNameKey('ＬＩＯＮＳ')).toBe('lions');
  });
});
