import { describe, expect, it } from 'vitest';
import { versionConfigIssues, type VersionConfigInput } from './level-config.rules.js';

const level = (levelNumber: number, requiredPoints: bigint) => ({
  levelNumber,
  nameAr: `م${String(levelNumber)}`,
  nameEn: `L${String(levelNumber)}`,
  requiredPoints,
  iconKey: null,
});

const valid: VersionConfigInput = {
  category: 'SUPPORT',
  multiplier: '1',
  valueUnit: 'COIN',
  luckyGiftsCountAsSupport: false,
  levels: [level(1, 0n), level(2, 100n), level(3, 1_000n)],
};

describe('version publication rules (CP-005 §4)', () => {
  it('accepts a complete, ordered ladder', () => {
    expect(versionConfigIssues(valid)).toEqual([]);
    // Any number of levels: one is enough.
    expect(versionConfigIssues({ ...valid, levels: [level(1, 0n)] })).toEqual([]);
  });

  it('needs a multiplier and a unit', () => {
    expect(versionConfigIssues({ ...valid, multiplier: null, valueUnit: null })).toEqual([
      { field: 'multiplier', issue: 'required' },
      { field: 'valueUnit', issue: 'required' },
    ]);
    expect(versionConfigIssues({ ...valid, multiplier: '0' })).toEqual([
      { field: 'multiplier', issue: 'invalid_value' },
    ]);
  });

  it('needs levels numbered 1..n, level 1 at 0, strictly increasing thresholds', () => {
    expect(versionConfigIssues({ ...valid, levels: [] })).toEqual([{ field: 'levels', issue: 'too_few' }]);
    expect(versionConfigIssues({ ...valid, levels: [level(1, 5n)] })).toEqual([
      { field: 'levels[0].requiredPoints', issue: 'must_be_zero' },
    ]);
    expect(versionConfigIssues({ ...valid, levels: [level(1, 0n), level(3, 10n)] })).toEqual([
      { field: 'levels[1].levelNumber', issue: 'not_sequential' },
    ]);
    expect(versionConfigIssues({ ...valid, levels: [level(1, 0n), level(2, 10n), level(3, 10n)] })).toEqual([
      { field: 'levels[2].requiredPoints', issue: 'not_increasing' },
    ]);
    // Order of the input does not matter.
    expect(versionConfigIssues({ ...valid, levels: [level(2, 100n), level(1, 0n)] })).toEqual([]);
  });

  it('allows the lucky-gift switch on SUPPORT only', () => {
    expect(versionConfigIssues({ ...valid, luckyGiftsCountAsSupport: true })).toEqual([]);
    expect(versionConfigIssues({ ...valid, category: 'WIZARD', luckyGiftsCountAsSupport: true })).toEqual([
      { field: 'luckyGiftsCountAsSupport', issue: 'not_applicable' },
    ]);
  });
});
