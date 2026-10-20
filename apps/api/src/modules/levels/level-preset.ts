import type { LevelDefinitionInput } from './level-config.rules.js';

/**
 * The owner's ladder (2026-10-20, CP-005 §9.1): 100 levels, multiplier 0.1 (1 point per 10
 * coins), difficulty by band. Each band fixes the points between one level and the next:
 *
 * | levels   | owner's difficulty      | points per level | coins per level |
 * | -------- | ----------------------- | ---------------- | --------------- |
 * | 2–10     | extremely easy          | 10               | 100             |
 * | 11–20    | very, very easy         | 50               | 500             |
 * | 21–30    | very easy               | 150              | 1,500           |
 * | 31–40    | easy                    | 400              | 4,000           |
 * | 41–50    | medium                  | 1,000            | 10,000          |
 * | 51–60    | above medium            | 2,500            | 25,000          |
 * | 61–80    | a little hard           | 6,000            | 60,000          |
 * | 81–99    | hard                    | 15,000           | 150,000         |
 * | 100      | very hard               | 100,000          | 1,000,000       |
 *
 * Level n's name is its art tier's (1–9, 10–19 … 90–99, 100: the owner's badge pack), and its
 * `iconKey` names that tier. The same ladder serves the four categories; it is only ever written
 * as a DRAFT — publishing stays an audited admin action.
 */
export const PRESET_MULTIPLIER = '0.1';
export const PRESET_LEVELS = 100;

const BANDS: readonly (readonly [lastLevel: number, step: bigint])[] = [
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

/** Tier names, tier 1 → 11 (the pack's metals and gems). */
const TIER_NAMES: readonly (readonly [ar: string, en: string])[] = [
  ['حديدي', 'Iron'],
  ['برونزي', 'Bronze'],
  ['فضي', 'Silver'],
  ['ذهبي', 'Gold'],
  ['زمردي', 'Emerald'],
  ['ياقوتي', 'Sapphire'],
  ['وردي', 'Rose'],
  ['فيروزي', 'Turquoise'],
  ['ياقوت أحمر', 'Ruby'],
  ['ماسي', 'Diamond'],
  ['أسطوري', 'Legend'],
];

/** The art tier (1–11) of a level, as the badge pack draws it. */
export function presetTier(level: number): number {
  return level >= 100 ? 11 : Math.floor(Math.min(Math.max(level, 1), 99) / 10) + 1;
}

export function presetLadder(): LevelDefinitionInput[] {
  const levels: LevelDefinitionInput[] = [];
  let required = 0n;
  for (let n = 1; n <= PRESET_LEVELS; n++) {
    if (n > 1) {
      const band = BANDS.find(([last]) => n <= last);
      if (!band) throw new Error(`no band for level ${String(n)}`);
      required += band[1];
    }
    const tier = presetTier(n);
    const [ar, en] = TIER_NAMES[tier - 1] ?? ['', ''];
    levels.push({
      levelNumber: n,
      nameAr: ar,
      nameEn: en,
      requiredPoints: required,
      iconKey: `tier_${String(tier).padStart(2, '0')}`,
    });
  }
  return levels;
}
