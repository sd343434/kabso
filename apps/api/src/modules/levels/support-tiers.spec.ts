import { describe, expect, it } from 'vitest';
import { presetLadder } from './level-preset.js';
import { SUPPORT_TIERS, supportFramesFor, supportTier } from './support-tiers.js';

describe('support tiers and frames (D169)', () => {
  it('five levels per tier, 96–99 in tier 20, level 100 alone in tier 21', () => {
    expect([1, 5, 6, 10, 11, 37, 95, 96, 99, 100, 180].map(supportTier)).toEqual([
      1, 1, 2, 2, 3, 8, 19, 20, 20, 21, 21,
    ]);
    // Every preset level falls in a tier, and every tier has a level.
    const tiers = new Set(presetLadder().map((l) => supportTier(l.levelNumber)));
    expect(tiers.size).toBe(SUPPORT_TIERS);
  });

  it('the frames of every tier reached; tier 21 keeps frame 20', () => {
    expect(supportFramesFor(null)).toEqual([]);
    expect(supportFramesFor(0)).toEqual([]);
    expect(supportFramesFor(3)).toEqual(['support_frame_01']);
    expect(supportFramesFor(12)).toEqual(['support_frame_01', 'support_frame_02', 'support_frame_03']);
    expect(supportFramesFor(99)).toHaveLength(20);
    expect(supportFramesFor(100)).toEqual(supportFramesFor(99));
  });
});
