import { describe, expect, it } from 'vitest';
import { carryAfterFraud, carryAtSwitch, keptLevel, levelFor, progressFor } from './level-math.js';
import { presetLadder } from './level-preset.js';

/** The 2026-10-20 ladder D194 replaced (points; 1 point per 10 coins). */
function oldLadder() {
  const bands: [number, bigint][] = [
    [10, 10n],
    [20, 50n],
    [30, 150n],
    [40, 400n],
    [50, 1_000n],
    [60, 2_500n],
    [80, 6_000n],
    [99, 15_000n],
    [100, 100_000n],
  ];
  let required = 0n;
  return Array.from({ length: 100 }, (_, i) => {
    const n = i + 1;
    if (n > 1) required += bands.find(([last]) => n <= last)![1];
    return { levelNumber: n, requiredPoints: required };
  });
}

const OLD = oldLadder();
const NEW = presetLadder();
const thr = (levels: { requiredPoints: bigint }[], n: number) => levels[n - 1]!.requiredPoints;

/** What the levels engine stores and shows after the D194 switch, for a user at `kept` with `total`. */
function afterSwitch(total: bigint, kept: number | null) {
  const { level, carried } = carryAtSwitch({ oldLevels: OLD, newLevels: NEW, total, oldCarry: 0n, kept });
  return { level, carried, progress: progressFor(NEW, total + carried, level) };
}

describe('D194 level floor: a ladder change never lowers a level', () => {
  it('keeps every old level and sets the carry to the new threshold plus the points made inside it', () => {
    // Level 50 on the old ladder = 16 090 points; 16 500 = 410 points into level 50.
    const a = afterSwitch(16_500n, 50);
    expect(a.level).toBe(50);
    expect(a.carried).toBe(thr(NEW, 50) + 410n - 16_500n);
    expect(a.progress.current?.levelNumber).toBe(50);
    expect(a.progress.next?.levelNumber).toBe(51);
    // Progress = 410 of the new 3 200 000 step (floored to 0.0 %); the rest is what is left.
    expect(a.progress.pointsToNext).toBe(3_200_000n - 410n);
    expect(a.progress.progressPercent).toBe(0);
  });

  it('holds for every level and every point inside it on the old ladder', () => {
    for (let n = 1; n <= 100; n++) {
      for (const inside of [0n, 1n, (n < 100 ? thr(OLD, n + 1) - thr(OLD, n) : 1n) - 1n]) {
        const total = thr(OLD, n) + inside;
        const a = afterSwitch(total, n);
        expect(a.level, `level ${String(n)}`).toBe(n);
        expect(levelFor(NEW, total + a.carried)?.levelNumber, `level ${String(n)}`).toBe(n);
        expect(a.carried >= 0n).toBe(true);
      }
    }
  });

  it('never carries anyone already at their level on the new ladder', () => {
    const a = afterSwitch(thr(NEW, 12) + 5n, 12);
    expect(a.carried).toBe(0n);
    expect(a.level).toBe(12);
    // A user above their stored level on the new ladder moves up (the higher of the two).
    expect(afterSwitch(thr(NEW, 14), 12).level).toBe(14);
    expect(afterSwitch(0n, null)).toMatchObject({ level: 1, carried: 0n });
  });

  it('further progress follows the new ladder from the kept level', () => {
    const { carried } = afterSwitch(thr(OLD, 30), 30); // 2 090 points, level 30
    const step = thr(NEW, 31) - thr(NEW, 30); // 360 000 points = 3 600 000 coins
    const half = thr(OLD, 30) + step / 2n;
    expect(progressFor(NEW, half + carried, 30).progressPercent).toBe(50);
    expect(keptLevel(30, levelFor(NEW, thr(OLD, 30) + step + carried)?.levelNumber ?? null)).toBe(31);
  });

  it('a reversal keeps the level; progress shows 0 and the full step', () => {
    const { carried } = afterSwitch(thr(OLD, 40), 40);
    const reversed = thr(OLD, 40) - 1_000n;
    const level = keptLevel(40, levelFor(NEW, reversed + carried)?.levelNumber ?? null);
    expect(level).toBe(40);
    const p = progressFor(NEW, reversed + carried, level);
    expect(p.current?.levelNumber).toBe(40);
    expect(p.progressPercent).toBe(0);
    expect(p.pointsToNext).toBe(thr(NEW, 41) - reversed - carried);
  });

  it('a fraud deduction still lowers the level, and takes its share of the carry', () => {
    const total = thr(OLD, 60); // 41 090 points, level 60
    const { carried } = afterSwitch(total, 60);
    // Half the points were fraud: half the carry goes too, the level falls to what is left.
    const after = total / 2n;
    const left = carryAfterFraud(carried, total, after);
    expect(left).toBe((carried * after) / total);
    const level = levelFor(NEW, after + left)?.levelNumber;
    expect(level).toBeLessThan(60);
    expect(level).toBeGreaterThan(1);
    // Everything was fraud: nothing carried, back to level 1.
    expect(carryAfterFraud(carried, total, 0n)).toBe(0n);
    expect(levelFor(NEW, 0n)?.levelNumber).toBe(1);
    expect(carryAfterFraud(0n, total, after)).toBe(0n);
  });

  it('a later ladder change keeps the progress made inside the level', () => {
    const first = carryAtSwitch({ oldLevels: OLD, newLevels: NEW, total: 6_090n, oldCarry: 0n, kept: 40 });
    const earned = 100_000n;
    const again = carryAtSwitch({
      oldLevels: NEW,
      newLevels: NEW,
      total: 6_090n + earned,
      oldCarry: first.carried,
      kept: 40,
    });
    expect(again.level).toBe(40);
    expect(6_090n + earned + again.carried).toBe(thr(NEW, 40) + earned);
    // The carry is capped below the next level: it never lifts a level by itself.
    const capped = carryAtSwitch({
      oldLevels: OLD,
      newLevels: NEW,
      total: thr(OLD, 40),
      oldCarry: 10n ** 12n,
      kept: 40,
    });
    expect(levelFor(NEW, thr(OLD, 40) + capped.carried)?.levelNumber).toBe(40);
  });

  it('the top level carries to the new top threshold', () => {
    const a = afterSwitch(thr(OLD, 100) + 7n, 100);
    expect(a.level).toBe(100);
    expect(a.carried).toBe(thr(NEW, 100) - thr(OLD, 100) - 7n);
    expect(a.progress.maxLevel).toBe(true);
  });
});
