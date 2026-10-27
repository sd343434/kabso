import { createHash } from 'node:crypto';
import type { Gift, GiftBadge, GiftCategory, Prisma } from '../../generated/prisma/client.js';

/**
 * The gift catalogue and the gift bag (CP-020, D108, CONVENTIONS §10.23), shared by the API and
 * the `gift-admin` CLI (no Nest dependencies). The catalogue is managed only with the CLI; no gift
 * is seeded (the owner supplies the art later, and an empty catalogue is valid). Every write runs
 * inside the caller's transaction.
 */

/**
 * The catalogue tabs, in display order (شائعة, مناسبات, مرح; v1.27-live, D132: حظ, listed only while
 * LUCKY_GIFTS_ENABLED). The bag (الحقيبة) is the last tab.
 */
export const GIFT_CATEGORIES: readonly GiftCategory[] = ['POPULAR', 'EVENT', 'FUN', 'LUCKY'];
export const GIFT_BADGES: readonly GiftBadge[] = ['NONE', 'NEW', 'EVENT'];

/** `gifts_code_format`: lower-case letters, digits and `_`, 1–40 characters, not starting with `_`. */
export const GIFT_CODE_PATTERN = /^[a-z0-9][a-z0-9_]{0,39}$/;
/** An app asset key (static image or effect): letters, digits, `_`, `-`, `.`, `/`, 1–80 characters. */
export const GIFT_ASSET_KEY_PATTERN = /^[A-Za-z0-9][A-Za-z0-9_./-]{0,79}$/;
/** `gifts_price_range`. */
export const GIFT_MIN_PRICE = 1;
export const GIFT_MAX_PRICE = 1_000_000;
/** `user_gift_stock_quantity_range`. */
export const GIFT_STOCK_MAX = 1_000_000_000;
/** Names: 1–60 characters after trimming. */
export const GIFT_NAME_MAX = 60;
/** `gifts_tag_code_format` (v1.24.3-live): a sub-category code, same shape as a gift code. */
export const GIFT_TAG_CODE_PATTERN = /^[a-z0-9][a-z0-9_]{0,39}$/;
/** A sub-category name (the panel's chip): 1–30 characters after trimming. */
export const GIFT_TAG_NAME_MAX = 30;

export interface GiftFields {
  readonly category: GiftCategory;
  readonly nameAr: string;
  readonly nameEn: string;
  readonly priceCoins: number;
  readonly assetKey: string;
  readonly animationKey: string | null;
  readonly sortOrder: number;
  readonly badge: GiftBadge;
  /**
   * The optional sub-category (v1.24.3-live: the panel's chips under the tabs). The three are all
   * null (none) or all set (`gifts_tag_complete`).
   */
  readonly tagCode: string | null;
  readonly tagNameAr: string | null;
  readonly tagNameEn: string | null;
  /**
   * v1.26.2-live (D126): the art in object storage (keys from `gift-art.ts`), or null / absent: the
   * bundled `assetKey` / `animationKey` only. `animationBytes` goes with `animationObjectKey`.
   */
  readonly imageObjectKey?: string | null;
  readonly animationObjectKey?: string | null;
  readonly animationBytes?: number | null;
}

/** Thrown when a change would leave a gift's fields invalid (e.g. a tag without its names). */
export class GiftFieldsError extends Error {}

/** The problem with a whole gift's tag (code and both names all set, or all null), or null. */
export function giftTagProblem(tag: Pick<GiftFields, 'tagCode' | 'tagNameAr' | 'tagNameEn'>): string | null {
  const set = [tag.tagCode, tag.tagNameAr, tag.tagNameEn].filter((v) => v !== null).length;
  if (set === 0 || set === 3) return null;
  return 'a tag needs its code and both names (--tag, --tag-ar, --tag-en), or --tag none';
}

/** Every problem with a gift's fields (empty: valid). Partial input checks only what is given. */
export function giftFieldProblems(fields: Partial<GiftFields>): string[] {
  const problems: string[] = [];
  if (fields.category !== undefined && !GIFT_CATEGORIES.includes(fields.category)) {
    problems.push(`category must be one of ${GIFT_CATEGORIES.join(', ')}`);
  }
  if (fields.badge !== undefined && !GIFT_BADGES.includes(fields.badge)) {
    problems.push(`badge must be one of ${GIFT_BADGES.join(', ')}`);
  }
  for (const [key, value] of [
    ['nameAr', fields.nameAr],
    ['nameEn', fields.nameEn],
  ] as const) {
    if (value !== undefined && (value.trim().length === 0 || value.trim().length > GIFT_NAME_MAX)) {
      problems.push(`${key} must be 1–${String(GIFT_NAME_MAX)} characters`);
    }
  }
  if (
    fields.priceCoins !== undefined &&
    (!Number.isInteger(fields.priceCoins) ||
      fields.priceCoins < GIFT_MIN_PRICE ||
      fields.priceCoins > GIFT_MAX_PRICE)
  ) {
    problems.push(
      `price must be a whole number of coins from ${String(GIFT_MIN_PRICE)} to ${String(GIFT_MAX_PRICE)}`,
    );
  }
  if (fields.assetKey !== undefined && !GIFT_ASSET_KEY_PATTERN.test(fields.assetKey)) {
    problems.push('assetKey must be 1–80 characters: letters, digits, _ - . /');
  }
  if (
    fields.animationKey !== undefined &&
    fields.animationKey !== null &&
    !GIFT_ASSET_KEY_PATTERN.test(fields.animationKey)
  ) {
    problems.push('animationKey must be 1–80 characters: letters, digits, _ - . /');
  }
  if (
    fields.tagCode !== undefined &&
    fields.tagCode !== null &&
    !GIFT_TAG_CODE_PATTERN.test(fields.tagCode)
  ) {
    problems.push('tag must be 1–40 characters: a-z, 0-9 and _ (not first)');
  }
  for (const [key, value] of [
    ['tagNameAr', fields.tagNameAr],
    ['tagNameEn', fields.tagNameEn],
  ] as const) {
    if (
      value !== undefined &&
      value !== null &&
      (value.trim().length === 0 || value.trim().length > GIFT_TAG_NAME_MAX)
    ) {
      problems.push(`${key} must be 1–${String(GIFT_TAG_NAME_MAX)} characters`);
    }
  }
  if (
    fields.sortOrder !== undefined &&
    (!Number.isInteger(fields.sortOrder) || fields.sortOrder < 0 || fields.sortOrder > 1_000_000)
  ) {
    problems.push('sortOrder must be a whole number from 0 to 1000000');
  }
  return problems;
}

type Tx = Prisma.TransactionClient;

/** Adds a gift (enabled). Returns false when the code exists (nothing changes). */
export async function addGiftIn(tx: Tx, code: string, fields: GiftFields): Promise<boolean> {
  const tagProblem = giftTagProblem(fields);
  if (tagProblem !== null) throw new GiftFieldsError(tagProblem);
  const inserted = await tx.gift.createMany({
    data: [
      {
        code,
        category: fields.category,
        nameAr: fields.nameAr.trim(),
        nameEn: fields.nameEn.trim(),
        priceCoins: fields.priceCoins,
        assetKey: fields.assetKey,
        animationKey: fields.animationKey,
        sortOrder: fields.sortOrder,
        badge: fields.badge,
        tagCode: fields.tagCode,
        tagNameAr: fields.tagNameAr?.trim() ?? null,
        tagNameEn: fields.tagNameEn?.trim() ?? null,
        imageObjectKey: fields.imageObjectKey ?? null,
        animationObjectKey: fields.animationObjectKey ?? null,
        animationBytes: fields.animationBytes ?? null,
      },
    ],
    skipDuplicates: true,
  });
  return inserted.count === 1;
}

/**
 * Changes some fields of a gift; returns the gift before and after, or null when it does not exist.
 * Throws {@link GiftFieldsError} (nothing changes) when the gift's tag would be incomplete.
 */
export async function updateGiftIn(
  tx: Tx,
  code: string,
  fields: Partial<GiftFields>,
): Promise<{ before: Gift; after: Gift } | null> {
  const before = await tx.gift.findUnique({ where: { code } });
  if (!before) return null;
  const tagProblem = giftTagProblem({
    tagCode: fields.tagCode !== undefined ? fields.tagCode : before.tagCode,
    tagNameAr: fields.tagNameAr !== undefined ? fields.tagNameAr : before.tagNameAr,
    tagNameEn: fields.tagNameEn !== undefined ? fields.tagNameEn : before.tagNameEn,
  });
  if (tagProblem !== null) throw new GiftFieldsError(tagProblem);
  const after = await tx.gift.update({
    where: { code },
    data: {
      ...fields,
      ...(fields.nameAr !== undefined ? { nameAr: fields.nameAr.trim() } : {}),
      ...(fields.nameEn !== undefined ? { nameEn: fields.nameEn.trim() } : {}),
      ...(typeof fields.tagNameAr === 'string' ? { tagNameAr: fields.tagNameAr.trim() } : {}),
      ...(typeof fields.tagNameEn === 'string' ? { tagNameEn: fields.tagNameEn.trim() } : {}),
    },
  });
  return { before, after };
}

/** Enables or disables a gift; returns whether it changed, or null when it does not exist. */
export async function setGiftEnabledIn(tx: Tx, code: string, enabled: boolean): Promise<boolean | null> {
  const gift = await tx.gift.findUnique({ where: { code }, select: { enabled: true } });
  if (!gift) return null;
  if (gift.enabled === enabled) return false;
  await tx.gift.update({ where: { code }, data: { enabled } });
  return true;
}

/**
 * Adds `quantity` (> 0) of gift `code` to `userId`'s bag; returns the new quantity, or null when the
 * total would pass {@link GIFT_STOCK_MAX} (nothing changes). A disabled gift may be granted (it shows
 * in the bag once enabled).
 */
export async function grantStockIn(
  tx: Tx,
  userId: string,
  code: string,
  quantity: number,
): Promise<number | null> {
  if (!Number.isInteger(quantity) || quantity <= 0) throw new RangeError('A grant is positive');
  const rows = await tx.$queryRaw<{ quantity: number }[]>`
    INSERT INTO user_gift_stock (user_id, gift_code, quantity, updated_at)
    VALUES (${userId}::uuid, ${code}, ${quantity}, now())
    ON CONFLICT (user_id, gift_code) DO UPDATE
       SET quantity = user_gift_stock.quantity + EXCLUDED.quantity, updated_at = now()
     WHERE user_gift_stock.quantity + EXCLUDED.quantity <= ${GIFT_STOCK_MAX}
    RETURNING quantity`;
  return rows[0]?.quantity ?? null;
}

/**
 * Takes `quantity` (> 0) of gift `code` from `userId`'s bag: one conditional UPDATE (the row lock
 * serializes concurrent sends), so the stock never goes below 0. Returns the quantity left, or null
 * (nothing changes) when the bag holds fewer.
 */
export async function consumeStockIn(
  tx: Tx,
  userId: string,
  code: string,
  quantity: number,
): Promise<number | null> {
  if (!Number.isInteger(quantity) || quantity <= 0) throw new RangeError('A use is positive');
  const rows = await tx.$queryRaw<{ quantity: number }[]>`
    UPDATE user_gift_stock SET quantity = quantity - ${quantity}, updated_at = now()
     WHERE user_id = ${userId}::uuid AND gift_code = ${code} AND quantity >= ${quantity}
    RETURNING quantity`;
  return rows[0]?.quantity ?? null;
}

/** What `userId` holds of gift `code` (0 without a row). */
export async function stockOf(db: Pick<Tx, 'userGiftStock'>, userId: string, code: string): Promise<number> {
  const row = await db.userGiftStock.findUnique({
    where: { userId_giftCode: { userId, giftCode: code } },
    select: { quantity: true },
  });
  return row?.quantity ?? 0;
}

/** The catalogue order: tab (POPULAR, EVENT, FUN, LUCKY), then sort order, then code. */
export function compareGifts(
  a: Pick<Gift, 'category' | 'sortOrder' | 'code'>,
  b: Pick<Gift, 'category' | 'sortOrder' | 'code'>,
): number {
  const tab = GIFT_CATEGORIES.indexOf(a.category) - GIFT_CATEGORIES.indexOf(b.category);
  if (tab !== 0) return tab;
  if (a.sortOrder !== b.sortOrder) return a.sortOrder - b.sortOrder;
  return a.code < b.code ? -1 : a.code > b.code ? 1 : 0;
}

/**
 * `GiftCatalogue.version`: changes whenever anything the app shows or caches changes (any enabled
 * gift's fields in both languages, its tag, its hosted art, the order, the quantities, the combo window), and never with the
 * reader's language. 16 hex characters of SHA-256.
 */
export function catalogueVersion(
  gifts: readonly Pick<
    Gift,
    | 'code'
    | 'category'
    | 'nameAr'
    | 'nameEn'
    | 'priceCoins'
    | 'assetKey'
    | 'animationKey'
    | 'sortOrder'
    | 'badge'
    | 'tagCode'
    | 'tagNameAr'
    | 'tagNameEn'
    | 'imageObjectKey'
    | 'animationObjectKey'
  >[],
  quantities: readonly number[],
  comboWindowSeconds: number,
  categories?: readonly GiftCategory[],
): string {
  const canonical = JSON.stringify({
    q: quantities,
    c: comboWindowSeconds,
    // v1.27-live (D132): the tabs, only when LUCKY is among them (so the hash is unchanged otherwise).
    ...(categories?.includes('LUCKY') ? { t: categories } : {}),
    g: gifts.map((g) => [
      g.code,
      g.category,
      g.nameAr,
      g.nameEn,
      g.priceCoins,
      g.assetKey,
      g.animationKey,
      g.sortOrder,
      g.badge,
      // v1.24.3-live: the sub-category (appended, so a gift without one keeps its old hash part).
      ...(g.tagCode === null ? [] : [g.tagCode, g.tagNameAr, g.tagNameEn]),
      // v1.26.2-live: the hosted art (appended only when set, so other gifts keep their hash part).
      ...(g.imageObjectKey === null && g.animationObjectKey === null
        ? []
        : ['art', g.imageObjectKey, g.animationObjectKey]),
    ]),
  });
  return createHash('sha256').update(canonical).digest('hex').slice(0, 16);
}
