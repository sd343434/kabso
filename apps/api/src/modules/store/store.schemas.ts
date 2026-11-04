import { z } from 'zod';
import { STORE_CURRENCIES, STORE_DAYS, STORE_KINDS, STORE_MAX_PRICE } from './store-rules.js';

/** D270 (CONVENTIONS §10.98): request bodies of «المتجر» and its panel page. */

const kind = z.enum(STORE_KINDS);
const currency = z.enum(STORE_CURRENCIES);
const days = z.union([z.literal(7), z.literal(14), z.literal(30)]);
const amount = z.number().int().min(1).max(STORE_MAX_PRICE);
const reason = z.string().trim().min(1).max(500);
const itemName = z.string().trim().min(1).max(40);
/** A hosted https URL from the panel's upload (nothing is bundled in the app). */
const artRef = z
  .string()
  .trim()
  .regex(/^https:\/\/\S{1,2040}$/);
const artSize = z.number().int().min(1).max(8192);

/** `GET /store/items?kind=`. */
export const storeItemsQuery = z.strictObject({ kind: kind.optional() });
export type StoreItemsQuery = z.output<typeof storeItemsQuery>;

/** `POST /me/store/purchases`: `recipient` (a username) makes it a gift; absent / null: for oneself. */
export const buyStoreItemBody = z.strictObject({
  itemId: z.uuid(),
  currency,
  days,
  /** The price the app showed (else 409 `STORE_PRICE_CHANGED`). */
  price: amount,
  recipient: z.string().trim().min(1).max(30).nullable().optional(),
});
export type BuyStoreItemBody = z.output<typeof buyStoreItemBody>;

/** One price of the panel's form. */
const priceInput = z.strictObject({ currency, days, amount });

/** The whole price list; at most one per currency and duration. Empty: not on sale (not listed). */
const prices = z
  .array(priceInput)
  .max(STORE_CURRENCIES.length * STORE_DAYS.length)
  .refine((list) => new Set(list.map((p) => `${p.currency}:${String(p.days)}`)).size === list.length, {
    message: 'a currency and duration repeat',
    params: { issue: 'duplicate_value' },
  });

const art = {
  still: artRef.nullable().optional(),
  animation: artRef.nullable().optional(),
  /** The animation's format (MP4: `animationAlpha` too); required with an animation. */
  animationFormat: z.enum(['SVGA', 'MP4']).nullable().optional(),
  animationAlpha: z.enum(['NONE', 'SIDE_BY_SIDE']).nullable().optional(),
  artWidth: artSize.nullable().optional(),
  artHeight: artSize.nullable().optional(),
};

export const createStoreItemBody = z.strictObject({
  kind,
  nameAr: itemName,
  nameEn: itemName,
  ...art,
  prices,
  sortOrder: z.number().int().min(0).max(100_000).optional(),
  isNew: z.boolean().optional(),
  enabled: z.boolean().optional(),
  reason,
});
export type CreateStoreItemBody = z.output<typeof createStoreItemBody>;

/** The kind never changes (owners' bag rows are of that kind). */
export const updateStoreItemBody = z
  .strictObject({
    nameAr: itemName.optional(),
    nameEn: itemName.optional(),
    ...art,
    prices: prices.optional(),
    sortOrder: z.number().int().min(0).max(100_000).optional(),
    isNew: z.boolean().optional(),
    reason,
  })
  .refine((v) => Object.keys(v).length > 1, { message: 'nothing to change', path: ['reason'] });
export type UpdateStoreItemBody = z.output<typeof updateStoreItemBody>;

export const storeReasonBody = z.strictObject({ reason });

/** `POST /admin/store/uploads?kind=animation|still` (an animation is an SVGA 2.x or an MP4, told by its bytes). */
export const storeUploadQuery = z.strictObject({ kind: z.enum(['animation', 'still']) });

/** `GET /admin/store/sales?itemId=&limit=`. */
export const storeSalesQuery = z.strictObject({
  itemId: z.uuid().optional(),
  limit: z.coerce.number().int().min(1).max(200).optional(),
});
