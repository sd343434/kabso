import { describe, expect, it } from 'vitest';
import { countryBreakdown, LIVE_STATS_TOP_COUNTRIES, percentOf, secondsBetween } from './live-stats.js';

describe('D140 live statistics (CONVENTIONS §10.31)', () => {
  describe('percentOf', () => {
    it('rounds each share to one decimal, half up', () => {
      expect(percentOf(1, 3)).toBe(33.3);
      expect(percentOf(2, 3)).toBe(66.7);
      expect(percentOf(1, 8)).toBe(12.5);
      expect(percentOf(1, 16)).toBe(6.3); // 6.25 → 6.3
      expect(percentOf(3, 11)).toBe(27.3);
      expect(percentOf(5, 5)).toBe(100);
    });

    it('is 0 without viewers or without a part', () => {
      expect(percentOf(0, 10)).toBe(0);
      expect(percentOf(3, 0)).toBe(0);
    });
  });

  describe('countryBreakdown', () => {
    it('is empty without viewers', () => {
      expect(countryBreakdown([])).toEqual([]);
      expect(countryBreakdown([{ country: 'SA', viewers: 0 }])).toEqual([]);
    });

    it('sorts by viewers (desc) then code (A → Z), and upper-cases codes', () => {
      expect(
        countryBreakdown([
          { country: 'jo', viewers: 1 },
          { country: 'EG', viewers: 2 },
          { country: 'AE', viewers: 1 },
        ]),
      ).toEqual([
        { country: 'EG', viewers: 2, percent: 50 },
        { country: 'AE', viewers: 1, percent: 25 },
        { country: 'JO', viewers: 1, percent: 25 },
      ]);
    });

    it(`keeps the top ${String(LIVE_STATS_TOP_COUNTRIES)}, then OTHER, then UNKNOWN (last, whatever its size)`, () => {
      const rows = [
        { country: 'SA', viewers: 6 },
        { country: 'EG', viewers: 5 },
        { country: 'JO', viewers: 4 },
        { country: 'AE', viewers: 3 },
        { country: 'KW', viewers: 2 },
        { country: 'MA', viewers: 1 },
        { country: 'QA', viewers: 1 },
        { country: null, viewers: 8 },
      ];
      const out = countryBreakdown(rows);
      expect(out.map((r) => r.country)).toEqual(['SA', 'EG', 'JO', 'AE', 'KW', 'OTHER', 'UNKNOWN']);
      expect(out.at(-2)).toEqual({ country: 'OTHER', viewers: 2, percent: 6.7 });
      expect(out.at(-1)).toEqual({ country: 'UNKNOWN', viewers: 8, percent: 26.7 });
      expect(out.reduce((s, r) => s + r.viewers, 0)).toBe(30);
    });

    it('leaves OTHER and UNKNOWN out when they have nobody', () => {
      expect(countryBreakdown([{ country: 'SA', viewers: 2 }])).toEqual([
        { country: 'SA', viewers: 2, percent: 100 },
      ]);
      expect(countryBreakdown([{ country: null, viewers: 3 }])).toEqual([
        { country: 'UNKNOWN', viewers: 3, percent: 100 },
      ]);
    });

    it('shows the rounded shares as they are (the sum may miss 100 by a tenth)', () => {
      const out = countryBreakdown([
        { country: 'SA', viewers: 1 },
        { country: 'EG', viewers: 1 },
        { country: 'JO', viewers: 1 },
      ]);
      expect(out.map((r) => r.percent)).toEqual([33.3, 33.3, 33.3]);
    });
  });

  it('secondsBetween floors and never goes negative', () => {
    const a = new Date('2026-10-27T10:00:00.000Z');
    expect(secondsBetween(a, new Date('2026-10-27T10:03:18.900Z'))).toBe(198);
    expect(secondsBetween(a, new Date('2026-10-27T09:59:00.000Z'))).toBe(0);
  });
});
