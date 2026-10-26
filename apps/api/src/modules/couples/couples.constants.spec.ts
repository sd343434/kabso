import { describe, expect, it } from 'vitest';
import { CP_GIFT_AMOUNTS, CP_TIERS, cpLevelFor, cpNextTier, cpTierName } from './couples.constants.js';

describe('CP tiers (CP-018)', () => {
  it('are the five named tiers with ascending thresholds', () => {
    expect(CP_TIERS.map((t) => [t.level, t.minPoints])).toEqual([
      [1, 0],
      [2, 520],
      [3, 1314],
      [4, 5200],
      [5, 13140],
    ]);
  });

  it('maps CP points to a tier at the boundaries', () => {
    expect(cpLevelFor(0)).toBe(1);
    expect(cpLevelFor(519)).toBe(1);
    expect(cpLevelFor(520)).toBe(2);
    expect(cpLevelFor(1314n)).toBe(3);
    expect(cpLevelFor(13140)).toBe(5);
    expect(cpLevelFor(1_000_000)).toBe(5);
  });

  it('names tiers in Arabic and English and knows the next one', () => {
    expect(cpTierName(1, 'ar')).toBe('ثنائي متحمّس');
    expect(cpTierName(1, 'en')).toBe('Eager couple');
    expect(cpTierName(5, 'en')).toBe('Legendary couple');
    expect(cpNextTier(2)?.minPoints).toBe(1314);
    expect(cpNextTier(5)).toBeNull();
  });

  it('offers the preset gift amounts', () => {
    expect(CP_GIFT_AMOUNTS).toEqual([10, 52, 99, 520, 1314]);
  });
});
