import { z } from 'zod';
import type { AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';

/**
 * v1.85-live (D305, CONVENTIONS §10.115; owner: both thresholds editable in the panel): the thresholds of the global
 * strips — the gifts strip «شريط الهدايا» (the price of ONE gift, in coins) and the games strip «شريط الألعاب» (a
 * prize, in tickets). The OWNER sets them in the panel («إعدادات الموقع» → «شريطا الهدايا والألعاب»); stored as one
 * row of `site_settings` (key `globalStrips`, `{giftMinCoins, gameMinTickets}`); a field absent or invalid → the
 * server's configuration (`GIFT_GLOBAL_TICKER_MIN_COINS`, default 500 000; `GAME_WIN_TICKER_MIN_TICKETS`, default
 * 1 000 000). Kept free of Nest so the unit tests share it.
 *
 * v1.89-live (D318, CONVENTIONS §10.121; owner «لا يظهر في التكست إلا المكسب x250 وx500 وx1000»): the same row also holds
 * `luckyChatMinMultiplier` — a lucky win's chat line shows only from this multiplier (one of `LUCKY_GIFT_MULTIPLIERS`;
 * absent or not one of them → `LUCKY_CHAT_MIN_MULTIPLIER`, default 250).
 *
 * v1.111-live (D347, CONVENTIONS §10.146; owner «نعم موافق»: the global banner's set and gap in the panel): the same
 * row holds `luckyGlobalMultipliers` and `luckyGlobalGapSeconds` (absent or invalid → LUCKY_GLOBAL_BANNER_MULTIPLIERS /
 * LUCKY_GLOBAL_BANNER_GAP_SECONDS).
 */
export const GLOBAL_STRIPS_SETTING_KEY = 'globalStrips';

/** The bounds the panel accepts (the same as the configuration's). */
export const GIFT_MIN_COINS_FLOOR = 1;
export const GIFT_MIN_COINS_CEILING = 1_000_000_000;
export const GAME_MIN_TICKETS_FLOOR = 1;
export const GAME_MIN_TICKETS_CEILING = 1_000_000_000_000;
export const LUCKY_CHAT_MIN_CEILING = 10_000;
/** v1.111-live (D347): the global lucky banner's gap, seconds (as LUCKY_GLOBAL_BANNER_GAP_SECONDS). */
export const LUCKY_GLOBAL_GAP_FLOOR = 1;
export const LUCKY_GLOBAL_GAP_CEILING = 600;
/** At most as many as the lucky multipliers can be (§10.27: 1–32). */
export const LUCKY_GLOBAL_MULTIPLIERS_MAX = 32;

export interface GlobalStripsSettingsDto {
  /** A gift whose unit price is at least this many coins is the gifts strip. */
  giftMinCoins: number;
  /** A game prize of at least this many tickets is the games strip. */
  gameMinTickets: number;
  /** v1.89-live (D318): a lucky win of at least this multiplier has a chat line. */
  luckyChatMinMultiplier: number;
  /**
   * v1.111-live (D347, §10.146): the best-win multipliers that make the global lucky banner (ascending, distinct, each
   * one of LUCKY_GIFT_MULTIPLIERS); default LUCKY_GLOBAL_BANNER_MULTIPLIERS.
   */
  luckyGlobalMultipliers: number[];
  /** v1.111-live (D347): at most one global lucky banner per this many seconds; default LUCKY_GLOBAL_BANNER_GAP_SECONDS. */
  luckyGlobalGapSeconds: number;
}

/** `AdminGlobalStrips` (the panel's read): the values and, v1.89-live (D318), the lucky multipliers to choose from. */
export interface AdminGlobalStripsDto extends GlobalStripsSettingsDto {
  luckyMultipliers: number[];
}

/** The configuration's values (when the OWNER has set none), and the multipliers the lucky value must be one of. */
export function globalStripsDefaultsOf(config: AppConfig): GlobalStripsSettingsDto {
  return {
    giftMinCoins: config.live.giftTickerMinCoins,
    gameMinTickets: config.live.gameWinTickerMinTickets,
    luckyChatMinMultiplier: config.lucky.chatMinMultiplier,
    luckyGlobalMultipliers: [...config.lucky.globalBannerMultipliers],
    luckyGlobalGapSeconds: Math.round(config.lucky.globalBannerGapMs / 1000),
  };
}

/** The lucky multipliers (`LUCKY_GIFT_MULTIPLIERS`), ascending. */
export function luckyMultipliersOf(config: AppConfig): readonly number[] {
  return config.lucky.table.outcomes.map((o) => o.multiplier);
}

const within = (value: unknown, floor: number, ceiling: number): value is number =>
  typeof value === 'number' && Number.isSafeInteger(value) && value >= floor && value <= ceiling;

/**
 * v1.111-live (D347): whether [value] is a valid global-banner set — the same rules as LUCKY_GLOBAL_BANNER_MULTIPLIERS:
 * 1–32 distinct whole numbers, each one of [multipliers] (when given).
 */
export function validLuckyGlobalMultipliers(
  value: unknown,
  multipliers?: readonly number[],
): value is number[] {
  return (
    Array.isArray(value) &&
    value.length >= 1 &&
    value.length <= LUCKY_GLOBAL_MULTIPLIERS_MAX &&
    value.every(
      (m) => within(m, 1, LUCKY_CHAT_MIN_CEILING) && (multipliers === undefined || multipliers.includes(m)),
    ) &&
    new Set(value).size === value.length
  );
}

/** A stored value read back: each field an integer within its bounds, else [defaults]' (the configuration). */
export function storedGlobalStrips(
  value: unknown,
  defaults: GlobalStripsSettingsDto,
  multipliers?: readonly number[],
): GlobalStripsSettingsDto {
  const v = (value !== null && typeof value === 'object' ? value : {}) as Record<string, unknown>;
  return {
    giftMinCoins: within(v.giftMinCoins, GIFT_MIN_COINS_FLOOR, GIFT_MIN_COINS_CEILING)
      ? v.giftMinCoins
      : defaults.giftMinCoins,
    gameMinTickets: within(v.gameMinTickets, GAME_MIN_TICKETS_FLOOR, GAME_MIN_TICKETS_CEILING)
      ? v.gameMinTickets
      : defaults.gameMinTickets,
    luckyChatMinMultiplier:
      within(v.luckyChatMinMultiplier, 1, LUCKY_CHAT_MIN_CEILING) &&
      (multipliers === undefined || multipliers.includes(v.luckyChatMinMultiplier))
        ? v.luckyChatMinMultiplier
        : defaults.luckyChatMinMultiplier,
    luckyGlobalMultipliers: validLuckyGlobalMultipliers(v.luckyGlobalMultipliers, multipliers)
      ? [...v.luckyGlobalMultipliers].sort((a, b) => a - b)
      : [...defaults.luckyGlobalMultipliers],
    luckyGlobalGapSeconds: within(v.luckyGlobalGapSeconds, LUCKY_GLOBAL_GAP_FLOOR, LUCKY_GLOBAL_GAP_CEILING)
      ? v.luckyGlobalGapSeconds
      : defaults.luckyGlobalGapSeconds,
  };
}

/** The current thresholds (a primary-key read); any read failure answers [defaults]. */
export async function readGlobalStrips(
  db: Pick<Prisma.TransactionClient, 'siteSetting'>,
  defaults: GlobalStripsSettingsDto,
  multipliers?: readonly number[],
): Promise<GlobalStripsSettingsDto> {
  try {
    const row = await db.siteSetting.findUnique({ where: { key: GLOBAL_STRIPS_SETTING_KEY } });
    return storedGlobalStrips(row?.value, defaults, multipliers);
  } catch {
    return { ...defaults, luckyGlobalMultipliers: [...defaults.luckyGlobalMultipliers] };
  }
}

/** `PUT /admin/global-strips` (both values; `reason` goes to the audit row). */
export const updateGlobalStripsSchema = z.strictObject({
  giftMinCoins: z.number().int().min(GIFT_MIN_COINS_FLOOR).max(GIFT_MIN_COINS_CEILING),
  gameMinTickets: z.number().int().min(GAME_MIN_TICKETS_FLOOR).max(GAME_MIN_TICKETS_CEILING),
  /** v1.89-live (D318): optional (an older panel leaves it as it is); one of LUCKY_GIFT_MULTIPLIERS (checked by the service). */
  luckyChatMinMultiplier: z.number().int().min(1).max(LUCKY_CHAT_MIN_CEILING).optional(),
  /**
   * v1.111-live (D347): optional (absent: unchanged); distinct values of LUCKY_GIFT_MULTIPLIERS (checked by the service).
   */
  luckyGlobalMultipliers: z
    .array(z.number().int().min(1).max(LUCKY_CHAT_MIN_CEILING))
    .min(1)
    .max(LUCKY_GLOBAL_MULTIPLIERS_MAX)
    .optional(),
  /** v1.111-live (D347): optional (absent: unchanged); 1–600. */
  luckyGlobalGapSeconds: z
    .number()
    .int()
    .min(LUCKY_GLOBAL_GAP_FLOOR)
    .max(LUCKY_GLOBAL_GAP_CEILING)
    .optional(),
  reason: z.string().trim().min(1).max(500).optional(),
});
export type UpdateGlobalStripsInput = z.output<typeof updateGlobalStripsSchema>;
