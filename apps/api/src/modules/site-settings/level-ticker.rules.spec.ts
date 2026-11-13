import { describe, expect, it } from 'vitest';
import {
  announcesLevelUp,
  LEVEL_TICKER_DEFAULT_MIN_LEVEL,
  readLevelTickerMinLevel,
  storedLevelTickerMinLevel,
  updateLevelTickerSchema,
} from './level-ticker.rules.js';

describe('D254 level ticker threshold rules', () => {
  it('defaults to 30; only an integer 1–100 is read back', () => {
    expect(LEVEL_TICKER_DEFAULT_MIN_LEVEL).toBe(30);
    expect(storedLevelTickerMinLevel(1)).toBe(1);
    expect(storedLevelTickerMinLevel(45)).toBe(45);
    expect(storedLevelTickerMinLevel(100)).toBe(100);
    for (const v of [0, 101, 30.5, '40', null, undefined, true, { minLevel: 40 }, -3]) {
      expect(storedLevelTickerMinLevel(v), JSON.stringify(v)).toBe(30);
    }
  });

  it('announces a rise that ends at or above the threshold, every step', () => {
    expect(announcesLevelUp(29, 30, 30)).toBe(true);
    expect(announcesLevelUp(30, 31, 30)).toBe(true);
    expect(announcesLevelUp(12, 45, 30)).toBe(true);
    expect(announcesLevelUp(null, 30, 30)).toBe(true);
    expect(announcesLevelUp(28, 29, 30)).toBe(false);
    expect(announcesLevelUp(31, 31, 30)).toBe(false);
    expect(announcesLevelUp(32, 31, 30)).toBe(false);
    expect(announcesLevelUp(5, null, 30)).toBe(false);
    expect(announcesLevelUp(1, 2, 1)).toBe(true);
  });

  it('the PUT body: an integer 1–100, an optional reason, nothing else', () => {
    expect(updateLevelTickerSchema.parse({ minLevel: 40, reason: ' owner ' })).toEqual({
      minLevel: 40,
      reason: 'owner',
    });
    for (const bad of [
      { minLevel: 0 },
      { minLevel: 101 },
      { minLevel: 30.5 },
      { minLevel: '30' },
      {},
      { minLevel: 30, x: 1 },
      { minLevel: 30, reason: '' },
    ]) {
      expect(updateLevelTickerSchema.safeParse(bad).success, JSON.stringify(bad)).toBe(false);
    }
  });

  it('reads the row; no row or a failing read answers 30', async () => {
    const db = (value: unknown, fail = false) =>
      ({
        siteSetting: {
          findUnique: async () => {
            if (fail) throw new Error('db down');
            return value === undefined ? null : { key: 'levelTickerMinLevel', value };
          },
        },
      }) as never;
    expect(await readLevelTickerMinLevel(db(12))).toBe(12);
    expect(await readLevelTickerMinLevel(db(undefined))).toBe(30);
    expect(await readLevelTickerMinLevel(db(12, true))).toBe(30);
  });
});
