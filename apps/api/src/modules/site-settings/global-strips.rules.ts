import { z } from 'zod';
import type { Prisma } from '../../generated/prisma/client.js';

/**
 * v1.85-live (D305, CONVENTIONS §10.115; owner: both thresholds editable in the panel): the thresholds of the global
 * strips — the gifts strip «شريط الهدايا» (the price of ONE gift, in coins) and the games strip «شريط الألعاب» (a
 * prize, in tickets). The OWNER sets them in the panel («إعدادات الموقع» → «شريطا الهدايا والألعاب»); stored as one
 * row of `site_settings` (key `globalStrips`, `{giftMinCoins, gameMinTickets}`); a field absent or invalid → the
 * server's configuration (`GIFT_GLOBAL_TICKER_MIN_COINS`, default 500 000; `GAME_WIN_TICKER_MIN_TICKETS`, default
 * 1 000 000). Kept free of Nest so the unit tests share it.
 */
export const GLOBAL_STRIPS_SETTING_KEY = 'globalStrips';

/** The bounds the panel accepts (the same as the configuration's). */
export const GIFT_MIN_COINS_FLOOR = 1;
export const GIFT_MIN_COINS_CEILING = 1_000_000_000;
export const GAME_MIN_TICKETS_FLOOR = 1;
export const GAME_MIN_TICKETS_CEILING = 1_000_000_000_000;

export interface GlobalStripsSettingsDto {
  /** A gift whose unit price is at least this many coins is the gifts strip. */
  giftMinCoins: number;
  /** A game prize of at least this many tickets is the games strip. */
  gameMinTickets: number;
}

const within = (value: unknown, floor: number, ceiling: number): value is number =>
  typeof value === 'number' && Number.isSafeInteger(value) && value >= floor && value <= ceiling;

/** A stored value read back: each field an integer within its bounds, else [defaults]' (the configuration). */
export function storedGlobalStrips(
  value: unknown,
  defaults: GlobalStripsSettingsDto,
): GlobalStripsSettingsDto {
  const v = (value !== null && typeof value === 'object' ? value : {}) as Record<string, unknown>;
  return {
    giftMinCoins: within(v.giftMinCoins, GIFT_MIN_COINS_FLOOR, GIFT_MIN_COINS_CEILING)
      ? v.giftMinCoins
      : defaults.giftMinCoins,
    gameMinTickets: within(v.gameMinTickets, GAME_MIN_TICKETS_FLOOR, GAME_MIN_TICKETS_CEILING)
      ? v.gameMinTickets
      : defaults.gameMinTickets,
  };
}

/** The current thresholds (a primary-key read); any read failure answers [defaults]. */
export async function readGlobalStrips(
  db: Pick<Prisma.TransactionClient, 'siteSetting'>,
  defaults: GlobalStripsSettingsDto,
): Promise<GlobalStripsSettingsDto> {
  try {
    const row = await db.siteSetting.findUnique({ where: { key: GLOBAL_STRIPS_SETTING_KEY } });
    return storedGlobalStrips(row?.value, defaults);
  } catch {
    return { ...defaults };
  }
}

/** `PUT /admin/global-strips` (both values; `reason` goes to the audit row). */
export const updateGlobalStripsSchema = z.strictObject({
  giftMinCoins: z.number().int().min(GIFT_MIN_COINS_FLOOR).max(GIFT_MIN_COINS_CEILING),
  gameMinTickets: z.number().int().min(GAME_MIN_TICKETS_FLOOR).max(GAME_MIN_TICKETS_CEILING),
  reason: z.string().trim().min(1).max(500).optional(),
});
export type UpdateGlobalStripsInput = z.output<typeof updateGlobalStripsSchema>;
