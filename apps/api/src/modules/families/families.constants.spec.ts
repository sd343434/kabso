import { describe, expect, it } from 'vitest';
import { FAMILY_LEVELS, familyLevelFor, familyNextLevelPoints } from './families.constants.js';
import { familyNameIssue, familyNameKey, normalizeFamilyName } from './family-name.js';

describe('family level ladder (CP-018)', () => {
  it('is ten ascending steps starting at level 1 with 0 points', () => {
    expect(FAMILY_LEVELS).toHaveLength(10);
    expect(FAMILY_LEVELS[0]).toEqual({ level: 1, minPoints: 0 });
    for (let i = 1; i < FAMILY_LEVELS.length; i++) {
      expect(FAMILY_LEVELS[i]!.level).toBe(i + 1);
      expect(FAMILY_LEVELS[i]!.minPoints).toBeGreaterThan(FAMILY_LEVELS[i - 1]!.minPoints);
    }
  });

  it('maps points to levels at the boundaries', () => {
    expect(familyLevelFor(0)).toBe(1);
    expect(familyLevelFor(999)).toBe(1);
    expect(familyLevelFor(1000)).toBe(2);
    expect(familyLevelFor(4999n)).toBe(2);
    expect(familyLevelFor(5000n)).toBe(3);
    expect(familyLevelFor(2_000_000)).toBe(10);
    expect(familyLevelFor(9_000_000_000)).toBe(10);
  });

  it('gives the next level threshold, null at the top', () => {
    expect(familyNextLevelPoints(1)).toBe(1000);
    expect(familyNextLevelPoints(9)).toBe(2_000_000);
    expect(familyNextLevelPoints(10)).toBeNull();
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
