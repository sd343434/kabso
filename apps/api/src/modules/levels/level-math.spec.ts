import { describe, expect, it } from 'vitest';
import { levelFor, progressFor } from './level-math.js';

// Example ladder from the brief §9 (illustrative only, never seeded).
const ladder = [
  { levelNumber: 1, requiredPoints: 0n },
  { levelNumber: 2, requiredPoints: 1_000n },
  { levelNumber: 3, requiredPoints: 5_000n },
  { levelNumber: 4, requiredPoints: 15_000n },
  { levelNumber: 5, requiredPoints: 50_000n },
];

describe('level math', () => {
  it('resolves the highest level whose threshold is reached', () => {
    expect(levelFor(ladder, 0n)?.levelNumber).toBe(1);
    expect(levelFor(ladder, 999n)?.levelNumber).toBe(1);
    expect(levelFor(ladder, 1_000n)?.levelNumber).toBe(2);
    expect(levelFor(ladder, 49_999n)?.levelNumber).toBe(4);
    expect(levelFor(ladder, 10n ** 18n)?.levelNumber).toBe(5);
    expect(levelFor([{ levelNumber: 1, requiredPoints: 10n }], 5n)).toBeNull();
  });

  it('measures progress between the current and next thresholds, floored to 0.1 %', () => {
    const p = progressFor(ladder, 3_000n);
    expect(p.current?.levelNumber).toBe(2);
    expect(p.next?.levelNumber).toBe(3);
    expect(p.pointsToNext).toBe(2_000n);
    expect(p.progressPercent).toBe(50);
    expect(p.maxLevel).toBe(false);
    expect(progressFor(ladder, 1_001n).progressPercent).toBe(0); // 0.025 % floors to 0.0
    expect(progressFor(ladder, 4_999n).progressPercent).toBe(99.9);
  });

  it('reports a stable maximum level (100 %, nothing to the next)', () => {
    const p = progressFor(ladder, 60_000n);
    expect(p.current?.levelNumber).toBe(5);
    expect(p.next).toBeNull();
    expect(p.pointsToNext).toBeNull();
    expect(p.progressPercent).toBe(100);
    expect(p.maxLevel).toBe(true);
    expect(progressFor([{ levelNumber: 1, requiredPoints: 0n }], 0n).maxLevel).toBe(true);
  });

  it('keeps a floor level after a reversal (KEEP_LEVEL) without negative progress', () => {
    const p = progressFor(ladder, 4_000n, 3);
    expect(p.current?.levelNumber).toBe(3);
    expect(p.next?.levelNumber).toBe(4);
    expect(p.progressPercent).toBe(0);
    expect(p.pointsToNext).toBe(11_000n);
    // A floor below the reached level changes nothing.
    expect(progressFor(ladder, 6_000n, 2).current?.levelNumber).toBe(3);
  });
});
