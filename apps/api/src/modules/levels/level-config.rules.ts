import type { ErrorDetail } from '../../common/errors/error-codes.js';
import type { LevelCategoryCode } from '../../generated/prisma/client.js';
import { MAX_LEVELS } from './levels.constants.js';
import { parseMultiplier } from './points-math.js';

export interface LevelDefinitionInput {
  readonly levelNumber: number;
  readonly nameAr: string;
  readonly nameEn: string;
  readonly requiredPoints: bigint;
  readonly iconKey: string | null;
}

export interface VersionConfigInput {
  readonly category: LevelCategoryCode;
  readonly multiplier: string | null;
  readonly valueUnit: string | null;
  readonly luckyGiftsCountAsSupport: boolean;
  readonly levels: readonly LevelDefinitionInput[];
}

/**
 * CP-005 §4 publication rules. Returns every problem (empty = publishable):
 * multiplier and unit set; 1–200 levels numbered 1..n without gaps; level 1 at 0 points;
 * thresholds strictly increasing; the lucky-gift switch only on SUPPORT.
 */
export function versionConfigIssues(input: VersionConfigInput): ErrorDetail[] {
  const issues: ErrorDetail[] = [];
  if (input.multiplier === null) issues.push({ field: 'multiplier', issue: 'required' });
  else if (parseMultiplier(input.multiplier) === null)
    issues.push({ field: 'multiplier', issue: 'invalid_value' });
  if (input.valueUnit === null) issues.push({ field: 'valueUnit', issue: 'required' });
  if (input.luckyGiftsCountAsSupport && input.category !== 'SUPPORT') {
    issues.push({ field: 'luckyGiftsCountAsSupport', issue: 'not_applicable' });
  }
  const levels = [...input.levels].sort((a, b) => a.levelNumber - b.levelNumber);
  if (levels.length === 0) {
    issues.push({ field: 'levels', issue: 'too_few' });
    return issues;
  }
  if (levels.length > MAX_LEVELS) issues.push({ field: 'levels', issue: 'too_many' });
  levels.forEach((level, i) => {
    const field = `levels[${String(i)}]`;
    if (level.levelNumber !== i + 1) issues.push({ field: `${field}.levelNumber`, issue: 'not_sequential' });
    if (level.requiredPoints < 0n) issues.push({ field: `${field}.requiredPoints`, issue: 'too_small' });
    if (i === 0 && level.requiredPoints !== 0n)
      issues.push({ field: `${field}.requiredPoints`, issue: 'must_be_zero' });
    const previous = levels[i - 1];
    if (previous && level.requiredPoints <= previous.requiredPoints) {
      issues.push({ field: `${field}.requiredPoints`, issue: 'not_increasing' });
    }
  });
  return issues;
}
