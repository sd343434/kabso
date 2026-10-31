import type { LevelDefinitionInput } from './level-config.rules.js';

/**
 * The owner's ladder, repriced (D194, 2026-10-31, option B; replaces the 2026-10-20 ladder of
 * CP-005 §9.1). Coins are cheap — retail 1 000 000 coins = $12.50 — and level 100 must mean at
 * least $250 000 of support (≥ 20 000 000 000 coins). 100 levels, multiplier 0.1 (1 point per 10
 * coins, unchanged); each band fixes the step between one level and the next:
 *
 * | levels | coins per level | points per level | cumulative coins at the band's end | ≈ USD     |
 * | ------ | --------------- | ---------------- | ---------------------------------- | --------- |
 * | 2–10   | 45 000          | 4 500            | 405 000                            | $5.06     |
 * | 11–20  | 200 000         | 20 000           | 2 405 000                          | $30.06    |
 * | 21–30  | 1 000 000       | 100 000          | 12 405 000                         | $155.06   |
 * | 31–40  | 3 600 000       | 360 000          | 48 405 000                         | $605.06   |
 * | 41–50  | 11 000 000      | 1 100 000        | 158 405 000                        | $1 980.06 |
 * | 51–60  | 32 000 000      | 3 200 000        | 478 405 000                        | $5 980.06 |
 * | 61–80  | 136 000 000     | 13 600 000       | 3 198 405 000                      | $39 980   |
 * | 81–99  | 590 000 000     | 59 000 000       | 14 408 405 000                     | $180 105  |
 * | 100    | 5 600 000 000   | 560 000 000      | 20 008 405 000                     | $250 105  |
 *
 * Level n's name is its art tier's (1–9, 10–19 … 90–99, 100: the owner's badge pack), and its
 * `iconKey` names that tier. The same ladder serves the four categories (all coin-valued). The
 * CLI writes it as DRAFTS; migration `20270104090000_level_ladder_d194` published it once, as an
 * audited system change the owner ordered (D194).
 */
export const PRESET_MULTIPLIER = '0.1';
export const PRESET_LEVELS = 100;
/** The audit tag of this ladder. */
export const PRESET_ID = 'owner-d194-2026-10-31';
/** Retail price of coins (D188, D194): 1 000 000 coins = $12.50, i.e. 80 000 coins per dollar. */
export const COINS_PER_USD = 80_000n;
/** Coins per point under {@link PRESET_MULTIPLIER}. */
export const COINS_PER_POINT = 10n;

const BANDS: readonly (readonly [lastLevel: number, step: bigint])[] = [
  [10, 4_500n],
  [20, 20_000n],
  [30, 100_000n],
  [40, 360_000n],
  [50, 1_100_000n],
  [60, 3_200_000n],
  [80, 13_600_000n],
  [99, 59_000_000n],
  [100, 560_000_000n],
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

/** Coins needed in total to reach `level` on the preset ladder. */
export function presetCoinsAt(level: number): bigint {
  const row = presetLadder()[level - 1];
  if (!row) throw new RangeError(`no level ${String(level)}`);
  return row.requiredPoints * COINS_PER_POINT;
}
