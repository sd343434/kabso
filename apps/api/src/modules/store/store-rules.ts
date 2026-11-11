import { createHash, randomBytes } from 'node:crypto';
import type { BagCategory } from '../bag/bag.catalogue.js';

/**
 * «المتجر» (D270, owner; CONVENTIONS §10.98): the store sells timed bag items — avatar frames, profile cards, chat
 * bubbles, entry banners and entry cars / effects — for coins and / or cherries, each at a price per duration (7, 14,
 * 30 days) set in the panel. Pure rules shared by the person's and the panel's services (no Nest dependencies).
 */

/**
 * The kinds the store sells, in the app's tab order. Extensible: a new kind is a `bag_category` value, a row here and
 * the `store_items_shape` CHECK (and the apps' renderers).
 */
export const STORE_KINDS = [
  'AVATAR_FRAME',
  'PROFILE_CARD',
  'CHAT_BUBBLE',
  'ENTRY_BANNER',
  'ENTRY_EFFECT',
] as const satisfies readonly BagCategory[];
export type StoreKind = (typeof STORE_KINDS)[number];

/** The durations on sale (owner: 7, 14 and 30 days; store items are never permanent). */
export const STORE_DAYS = [7, 14, 30] as const;
export type StoreDays = (typeof STORE_DAYS)[number];

export const STORE_CURRENCIES = ['COINS', 'CHERRIES'] as const;
export type StoreCurrency = (typeof STORE_CURRENCIES)[number];

/** A price's bounds (CHECK `store_item_prices_shape`). */
export const STORE_MAX_PRICE = 1_000_000_000_000;

/** At most this many items in the store (a server-bounded list, §5). */
export const STORE_MAX_ITEMS = 500;

/**
 * The furthest an item's end may be from now after a purchase (repeated purchases add days; the bag's cap, §10.45).
 */
export const STORE_MAX_AHEAD_DAYS = 3650;

/** An Idempotency-Key is remembered for 24 hours (§3, like VIP and premium usernames). */
export const STORE_IDEMPOTENCY_MS = 24 * 3600_000;

export const STORE_DAY_MS = 86_400_000;

/** The bag code of a new store item: `store_<12 hex>` (CHECK `store_items_shape`; never a catalogue code). */
export function newStoreBagCode(): string {
  return `store_${randomBytes(6).toString('hex')}`;
}

export function isStoreBagCode(code: string): boolean {
  return /^store_[0-9a-f]{12}$/.test(code);
}

export interface StorePriceRow {
  readonly currency: StoreCurrency;
  readonly days: number;
  readonly amount: bigint;
}

/** The prices in a fixed order: coins first, then cherries; shorter first. */
export function sortedPrices<T extends StorePriceRow>(prices: readonly T[]): T[] {
  return [...prices].sort(
    (a, b) => STORE_CURRENCIES.indexOf(a.currency) - STORE_CURRENCIES.indexOf(b.currency) || a.days - b.days,
  );
}

/** The lowest price in [currency] (the grid's «from» price), or null when the item has none in it. */
export function lowestPrice(prices: readonly StorePriceRow[], currency: StoreCurrency): bigint | null {
  let low: bigint | null = null;
  for (const p of prices) if (p.currency === currency && (low === null || p.amount < low)) low = p.amount;
  return low;
}

/** The request's fingerprint for the Idempotency-Key (the same key with another body → 409). */
export function storeRequestHash(body: {
  itemId: string;
  currency: StoreCurrency;
  days: number;
  price: number;
  recipient: string | null;
}): string {
  return createHash('sha256')
    .update(
      [
        body.itemId.toLowerCase(),
        body.currency,
        String(body.days),
        String(body.price),
        body.recipient?.toLowerCase() ?? '',
      ].join('\n'),
    )
    .digest('hex');
}

/**
 * The item's end after a purchase of [days] at [now]: the days are added to an end still in the future (owner: «شراء
 * عنصر تملكه يضيف الأيام إلى انتهائه»), else counted from now. Null: past {@link STORE_MAX_AHEAD_DAYS}.
 */
export function storeExpiryAfter(owned: Date | null, days: number, now: Date): Date | null {
  const from = owned !== null && owned > now ? owned.getTime() : now.getTime();
  const end = new Date(from + days * STORE_DAY_MS);
  return end.getTime() - now.getTime() > STORE_MAX_AHEAD_DAYS * STORE_DAY_MS ? null : end;
}

// ---- The item's art on the wire ----------------------------------------------------------------------------------

/**
 * v1.128-social (D373, §10.165; owner: «اما بشاشة كاملة او نصف الشاشة»): how an entry car plays — the whole live screen
 * (D331; the default, and every car before D373) or a band about half the screen high above the chat. Set in the panel
 * per store entry car and per VIP ENTRY_EFFECT perk; read for an entry car only.
 */
export const ENTRY_DISPLAYS = ['FULL_SCREEN', 'HALF_SCREEN'] as const;
export type EntryDisplay = (typeof ENTRY_DISPLAYS)[number];

/** The kind (a store item) or perk code (a VIP perk) whose art is an entry car, the only one with a display. */
export const ENTRY_CAR_KIND = 'ENTRY_EFFECT';

/** The columns of a store item's art. */
export const STORE_ART_SELECT = {
  still: true,
  animation: true,
  animationFormat: true,
  animationAlpha: true,
  artWidth: true,
  artHeight: true,
  /** v1.128-social (D373): read for an entry car only (`StoreWornItem.entryDisplay`). */
  entryDisplay: true,
} as const;

export interface StoreArtRow {
  readonly still: string | null;
  readonly animation: string | null;
  readonly animationFormat: 'SVGA' | 'MP4' | null;
  readonly animationAlpha: 'NONE' | 'SIDE_BY_SIDE' | null;
  readonly artWidth: number | null;
  readonly artHeight: number | null;
  /** v1.128-social (D373): the entry car's display (absent in older selects: FULL_SCREEN). */
  readonly entryDisplay?: EntryDisplay;
}

/** `StoreArt`: the still, the animation (SVGA or MP4 — `alpha` set for MP4) and the art's size. */
export interface StoreArtDto {
  still: string | null;
  animation: string | null;
  format: 'SVGA' | 'MP4' | null;
  alpha: 'NONE' | 'SIDE_BY_SIDE' | null;
  width: number | null;
  height: number | null;
}

export function storeArtDto(row: StoreArtRow): StoreArtDto {
  return {
    still: row.still,
    animation: row.animation,
    format: row.animation === null ? null : row.animationFormat,
    alpha: row.animationFormat === 'MP4' ? (row.animationAlpha ?? 'NONE') : null,
    width: row.artWidth,
    height: row.artHeight,
  };
}

/** `StoreWornItem`: a store item worn now (its bag code and art). */
export interface StoreWornItemDto extends StoreArtDto {
  code: string;
  /** v1.128-social (D373, §10.165): the entry car only (`wear.entryEffect`) — how it plays; absent for other kinds. */
  entryDisplay?: EntryDisplay;
}

/**
 * `UserSummary.wear` / `PublicProfile.wear` (D270): the store items a person wears now, by kind — what every renderer
 * draws (the frame, the card, the chat bubble, the entry banner and car). Absent when none.
 */
export interface StoreWearDto {
  avatarFrame?: StoreWornItemDto;
  profileCard?: StoreWornItemDto;
  chatBubble?: StoreWornItemDto;
  entryBanner?: StoreWornItemDto;
  entryEffect?: StoreWornItemDto;
}

const WEAR_KEY: Readonly<Record<StoreKind, keyof StoreWearDto>> = {
  AVATAR_FRAME: 'avatarFrame',
  PROFILE_CARD: 'profileCard',
  CHAT_BUBBLE: 'chatBubble',
  ENTRY_BANNER: 'entryBanner',
  ENTRY_EFFECT: 'entryEffect',
};

/** A worn bag row with its store art (null: not a store item). */
export interface WornStoreRow {
  readonly category?: string;
  readonly itemCode: string;
  readonly expiresAt: Date | null;
  readonly item: { readonly storeItem?: StoreArtRow | null };
}

/** The store items among the worn [rows] at [now], or null when none. */
export function storeWearOf(rows: readonly WornStoreRow[] | undefined, now: Date): StoreWearDto | null {
  const wear: StoreWearDto = {};
  let any = false;
  for (const r of rows ?? []) {
    const art = r.item.storeItem;
    if (!art || (r.expiresAt !== null && r.expiresAt <= now)) continue;
    const key = WEAR_KEY[(r.category ?? 'AVATAR_FRAME') as StoreKind] as keyof StoreWearDto | undefined;
    if (!key) continue;
    wear[key] = {
      code: r.itemCode,
      ...storeArtDto(art),
      // v1.128-social (D373): the car's display, from the server — never guessed by the app.
      ...(key === 'entryEffect' ? { entryDisplay: art.entryDisplay ?? 'FULL_SCREEN' } : {}),
    };
    any = true;
  }
  return any ? wear : null;
}

/** Whether a wear holds an entry banner or car (a join that plays one is never dropped by the 1/s join window). */
export function wearHasEntrance(wear: StoreWearDto | null | undefined): boolean {
  return wear?.entryBanner !== undefined || wear?.entryEffect !== undefined;
}
