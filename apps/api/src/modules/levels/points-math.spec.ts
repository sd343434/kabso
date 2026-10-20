import { describe, expect, it } from 'vitest';
import {
  addPoints,
  formatMultiplier,
  MAX_POINTS,
  parseMultiplier,
  parsePoints,
  pointsFor,
} from './points-math.js';

describe('points math (CP-005 §3)', () => {
  it('parses multipliers exactly, with up to 6 decimals', () => {
    expect(parseMultiplier('1')).toBe(1_000_000n);
    expect(parseMultiplier('0.5')).toBe(500_000n);
    expect(parseMultiplier('2.125')).toBe(2_125_000n);
    expect(parseMultiplier('0.000001')).toBe(1n);
    expect(parseMultiplier('1000000')).toBe(1_000_000_000_000n);
  });

  it.each(['0', '0.0', '-1', '1.0000001', '01', '1e3', '', ' 1', '1000001', 'abc', '.5'])(
    'rejects multiplier %j',
    (text) => {
      expect(parseMultiplier(text)).toBeNull();
    },
  );

  it('formats multipliers canonically', () => {
    expect(formatMultiplier(1_000_000n)).toBe('1');
    expect(formatMultiplier(500_000n)).toBe('0.5');
    expect(formatMultiplier(2_125_000n)).toBe('2.125');
    expect(formatMultiplier(1n)).toBe('0.000001');
  });

  it('floors points (never over-awards)', () => {
    expect(pointsFor(10n, parseMultiplier('1')!)).toBe(10n);
    expect(pointsFor(3n, parseMultiplier('0.5')!)).toBe(1n);
    expect(pointsFor(1n, parseMultiplier('0.999999')!)).toBe(0n);
    expect(pointsFor(7n, parseMultiplier('2.125')!)).toBe(14n);
    // Exact where floating point is not: 0.1 × 3 = 0.30000000000000004 in doubles.
    expect(pointsFor(30n, parseMultiplier('0.1')!)).toBe(3n);
  });

  it('refuses negative values and BIGINT overflow', () => {
    expect(() => pointsFor(-1n, 1_000_000n)).toThrow(RangeError);
    expect(() => pointsFor(MAX_POINTS, parseMultiplier('2')!)).toThrow(RangeError);
    expect(() => addPoints(MAX_POINTS, 1n)).toThrow(RangeError);
    expect(addPoints(5n, -7n)).toBe(-2n);
  });

  it('parses point amounts as BIGINT text only', () => {
    expect(parsePoints('0')).toBe(0n);
    expect(parsePoints('-15')).toBe(-15n);
    expect(parsePoints('9223372036854775807')).toBe(MAX_POINTS);
    expect(parsePoints('9223372036854775808')).toBeNull();
    expect(parsePoints('01')).toBeNull();
    expect(parsePoints('1.5')).toBeNull();
    expect(parsePoints('')).toBeNull();
  });
});
