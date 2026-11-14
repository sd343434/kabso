import { z } from 'zod';
import { itemBadgesInput } from '../gifts/item-badges.schemas.js';
import {
  ENTRY_CAR_KIND,
  ENTRY_DISPLAYS,
  STORE_CURRENCIES,
  STORE_DAYS,
  STORE_KINDS,
  STORE_MAX_PRICE,
} from './store-rules.js';

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

/**
 * v1.128-social (D373, §10.165): an entry car's display «طريقة العرض» — FULL_SCREEN «شاشة كاملة» or HALF_SCREEN «نصف
 * الشاشة». Only for an entry car (kind ENTRY_EFFECT): 400 `not_allowed` for any other kind.
 */
const entryDisplay = z.enum(ENTRY_DISPLAYS);

/** v1.79-live (D289): `badges` (the set) or the deprecated `isNew` switch, not both. */
const badgesOrIsNew = {
  message: 'isNew and badges together',
  path: ['isNew'],
  params: { issue: 'conflict' },
};

export const createStoreItemBody = z
  .strictObject({
    kind,
    nameAr: itemName,
    nameEn: itemName,
    ...art,
    /** v1.128-social (D373): an entry car's display (absent: FULL_SCREEN). */
    entryDisplay: entryDisplay.optional(),
    prices,
    sortOrder: z.number().int().min(0).max(100_000).optional(),
    /** Deprecated v1.79-live (D289): true sets «جديد» (14 days), false takes it off. */
    isNew: z.boolean().optional(),
    badges: itemBadgesInput.optional(),
    enabled: z.boolean().optional(),
    /**
     * v1.101-social (D325): an event-exclusive prize item (uploaded inside the event): never sold — no prices, always
     * off and hidden from the store; granted only as that event's prize.
     */
    eventId: z.uuid().optional(),
    reason,
  })
  .refine((v) => v.isNew === undefined || v.badges === undefined, badgesOrIsNew)
  .refine((v) => v.entryDisplay === undefined || v.kind === ENTRY_CAR_KIND, {
    message: 'only an entry car has a display',
    path: ['entryDisplay'],
    params: { issue: 'not_allowed' },
  })
  .refine((v) => v.eventId === undefined || (v.prices.length === 0 && v.enabled !== true), {
    message: 'an event prize item has no prices and is never on sale',
    path: ['eventId'],
    params: { issue: 'conflict' },
  });
export type CreateStoreItemBody = z.output<typeof createStoreItemBody>;

/** The kind never changes (owners' bag rows are of that kind). */
export const updateStoreItemBody = z
  .strictObject({
    nameAr: itemName.optional(),
    nameEn: itemName.optional(),
    ...art,
    /** v1.128-social (D373): an entry car's display; refused (400 `not_allowed`) for any other kind. */
    entryDisplay: entryDisplay.optional(),
    prices: prices.optional(),
    sortOrder: z.number().int().min(0).max(100_000).optional(),
    isNew: z.boolean().optional(),
    badges: itemBadgesInput.optional(),
    reason,
  })
  .refine((v) => Object.keys(v).length > 1, { message: 'nothing to change', path: ['reason'] })
  .refine((v) => v.isNew === undefined || v.badges === undefined, badgesOrIsNew);
export type UpdateStoreItemBody = z.output<typeof updateStoreItemBody>;

export const storeReasonBody = z.strictObject({ reason });

/** v1.79-live (D289b): `DELETE /admin/store/items/{id}` and `…/restore` — the reason is optional (not a money action). */
export const storeOptionalReasonBody = z
  .strictObject({ reason: z.string().trim().max(500).optional() })
  .default({});
export type StoreOptionalReasonBody = z.output<typeof storeOptionalReasonBody>;

/** v1.101-social (D325): `GET /admin/store/items?eventId=` — that event's own prize items (else the store's). */
export const storeItemsAdminQuery = z.strictObject({ eventId: z.uuid().optional() });

/** `POST /admin/store/uploads?kind=animation|still` (an animation is an SVGA 2.x or an MP4, told by its bytes). */
export const storeUploadQuery = z.strictObject({ kind: z.enum(['animation', 'still']) });

/** `GET /admin/store/sales?itemId=&limit=`. */
export const storeSalesQuery = z.strictObject({
  itemId: z.uuid().optional(),
  limit: z.coerce.number().int().min(1).max(200).optional(),
});
