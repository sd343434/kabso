import { describe, expect, it } from 'vitest';
import { CREATOR_STATS_PERIODS, monthIn } from './creator-stats.service.js';

describe('creator stats (D172)', () => {
  it('names the month in the region, not in UTC', () => {
    // 2026-10-31 22:00 UTC is already November 1st in Riyadh (UTC+3).
    const at = new Date(Date.UTC(2026, 9, 31, 22, 0));
    expect(monthIn(at, 'Asia/Riyadh')).toBe('2026-11');
    expect(monthIn(at, 'UTC')).toBe('2026-10');
    expect(monthIn(new Date(Date.UTC(2027, 0, 1, 0, 0)), 'America/New_York')).toBe('2026-12');
  });

  it('accepts THIS_MONTH beside the rolling windows', () => {
    expect(CREATOR_STATS_PERIODS).toEqual(['LAST_7_DAYS', 'LAST_30_DAYS', 'ALL_TIME', 'THIS_MONTH']);
  });
});
