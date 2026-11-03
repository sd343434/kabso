import { z } from 'zod';
import type { Prisma } from '../../generated/prisma/client.js';

/**
 * v1.62-live (D254, CONVENTIONS §10.92): the level from which a level-up is announced in every live — the scrolling
 * banner «🎉 تهانينا لـ … على الترقية إلى المستوى …». It applies to the support level (`SUPPORT`, gift senders) and
 * the charm level (`ATTRACTIVENESS`, hosts and seated guests receiving gifts or taps). The OWNER sets it in the panel
 * («إعدادات الموقع» → «شريط ترقية المستويات»); stored as one row of `site_settings` (key `levelTickerMinLevel`, an
 * integer); absent or invalid → {@link LEVEL_TICKER_DEFAULT_MIN_LEVEL}. Kept free of Nest so the unit tests share it.
 */
export const LEVEL_TICKER_SETTING_KEY = 'levelTickerMinLevel';

/** The owner's default (D254): from level 30. */
export const LEVEL_TICKER_DEFAULT_MIN_LEVEL = 30;
/** The bounds the panel accepts (the level ladders go to 100). */
export const LEVEL_TICKER_MIN_LEVEL_FLOOR = 1;
export const LEVEL_TICKER_MIN_LEVEL_CEILING = 100;

export interface LevelTickerSettingsDto {
  minLevel: number;
}

/** A stored value read back: an integer within the bounds, else the default. */
export function storedLevelTickerMinLevel(value: unknown): number {
  return typeof value === 'number' &&
    Number.isInteger(value) &&
    value >= LEVEL_TICKER_MIN_LEVEL_FLOOR &&
    value <= LEVEL_TICKER_MIN_LEVEL_CEILING
    ? value
    : LEVEL_TICKER_DEFAULT_MIN_LEVEL;
}

/** The current threshold (a primary-key read); any read failure answers the default. */
export async function readLevelTickerMinLevel(
  db: Pick<Prisma.TransactionClient, 'siteSetting'>,
): Promise<number> {
  try {
    const row = await db.siteSetting.findUnique({ where: { key: LEVEL_TICKER_SETTING_KEY } });
    return storedLevelTickerMinLevel(row?.value);
  } catch {
    return LEVEL_TICKER_DEFAULT_MIN_LEVEL;
  }
}

/**
 * Whether a level change is announced: the level went up (`previousLevel` < `level`; no level before counts as 0)
 * and the new level is at least `minLevel`. Every step at or above the threshold is announced (31, 32, …).
 */
export function announcesLevelUp(
  previousLevel: number | null,
  level: number | null,
  minLevel: number,
): boolean {
  if (level === null) return false;
  return level > (previousLevel ?? 0) && level >= minLevel;
}

/** `PUT /admin/level-ticker` (`reason` goes to the audit row). */
export const updateLevelTickerSchema = z.strictObject({
  minLevel: z.number().int().min(LEVEL_TICKER_MIN_LEVEL_FLOOR).max(LEVEL_TICKER_MIN_LEVEL_CEILING),
  reason: z.string().trim().min(1).max(500).optional(),
});
export type UpdateLevelTickerInput = z.output<typeof updateLevelTickerSchema>;
