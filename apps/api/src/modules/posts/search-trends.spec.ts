import { describe, expect, it } from 'vitest';
import { containsBlockedWord, hourOf, normalizeSearchTerm, trendingTag } from './search-trends.js';

describe('D147 search trends rules', () => {
  it('normalizes a submitted search: NFC, trim, one @/#, spaces collapsed, lower case', () => {
    expect(normalizeSearchTerm('  Rising   Stars ')).toBe('rising stars');
    expect(normalizeSearchTerm('#Live PK')).toBe('live pk');
    expect(normalizeSearchTerm('@Sara')).toBe('sara');
    expect(normalizeSearchTerm('تعارف  عربي')).toBe('تعارف عربي');
    expect(normalizeSearchTerm('Café')).toBe('café');
  });

  it('never counts short, letterless or identifying searches', () => {
    expect(normalizeSearchTerm('a')).toBeNull();
    expect(normalizeSearchTerm('  ')).toBeNull();
    expect(normalizeSearchTerm('1234')).toBeNull();
    expect(normalizeSearchTerm('call 0791234567')).toBeNull();
    expect(normalizeSearchTerm('room 123456789')).toBeNull();
    expect(normalizeSearchTerm('٠٧٩١٢٣٤٥٦٧ رقم')).toBeNull();
    expect(normalizeSearchTerm('me@example.com')).toBeNull();
    expect(normalizeSearchTerm('https://x.y')).toBeNull();
    expect(normalizeSearchTerm('www.site')).toBeNull();
    expect(normalizeSearchTerm('a‎b')).toBeNull();
    expect(normalizeSearchTerm('x'.repeat(65))).toBeNull();
    expect(normalizeSearchTerm('ali 1990')).toBe('ali 1990');
  });

  it('matches blocked words like live blocked words (folded, whole words for Latin)', () => {
    expect(containsBlockedWord('bad words here', ['WORDS'])).toBe(true);
    expect(containsBlockedWord('swordsman', ['words'])).toBe(false);
    expect(containsBlockedWord('والكلمة', ['كلمه'])).toBe(true);
    expect(containsBlockedWord('anything', [])).toBe(false);
  });

  it('tags NEW (first seen < 24 h), TRENDING (≥ 3 and ≥ 2× the day before) or nothing', () => {
    const now = new Date('2026-11-02T12:30:00Z');
    const old = new Date('2026-10-28T00:00:00Z');
    expect(trendingTag({ firstSeenAt: new Date('2026-11-02T00:00:00Z'), day: 9, previousDay: 0 }, now)).toBe(
      'NEW',
    );
    expect(trendingTag({ firstSeenAt: old, day: 6, previousDay: 3 }, now)).toBe('TRENDING');
    expect(trendingTag({ firstSeenAt: old, day: 3, previousDay: 0 }, now)).toBe('TRENDING');
    expect(trendingTag({ firstSeenAt: old, day: 5, previousDay: 3 }, now)).toBeNull();
    expect(trendingTag({ firstSeenAt: old, day: 2, previousDay: 0 }, now)).toBeNull();
  });

  it('buckets by UTC hour', () => {
    expect(hourOf(new Date('2026-11-02T12:59:59.999Z')).toISOString()).toBe('2026-11-02T12:00:00.000Z');
  });
});
