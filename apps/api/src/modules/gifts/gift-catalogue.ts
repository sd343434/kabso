import { createHash } from 'node:crypto';
import type {
  Gift,
  GiftAnimationFormat,
  GiftBadge,
  GiftCategoryKind,
  GiftVideoAlpha,
  PkBoosterKind,
  Prisma,
} from '../../generated/prisma/client.js';
import {
  activeItemBadges,
  applyLegacyGiftBadge,
  badgeColumns,
  badgeSettingsOf,
  legacyGiftBadge,
  type ItemBadgeColumns,
  type ItemBadgeSetting,
} from './item-badges.js';

/**
 * The gift catalogue and the gift bag (CP-020, D108, CONVENTIONS §10.23), shared by the API and
 * the `gift-admin` CLI (no Nest dependencies). The catalogue is managed only with the CLI; no gift
 * is seeded (the owner supplies the art later, and an empty catalogue is valid). Every write runs
 * inside the caller's transaction.
 */

/**
 * v1.46-live (D207, CONVENTIONS §10.66): a gift's category is the code of a `gift_categories` row (the panel's tab),
 * managed in the admin panel; it was the fixed enum POPULAR, EVENT, FUN, LUCKY, QUIPS, which the migration seeded.
 * The special categories' codes equal their kind (CHECK `gift_categories_kind_code`), so `category === 'LUCKY'` /
 * `'QUIPS'` still names the lucky / quips behaviour. The bag (الحقيبة) is the last tab (not a category).
 */
export type GiftCategoryCode = string;
/** The codes of the special categories (their kind). */
export const LUCKY_CATEGORY: GiftCategoryCode = 'LUCKY';
export const QUIPS_CATEGORY: GiftCategoryCode = 'QUIPS';
/**
 * v1.100-social (D312, CONVENTIONS §10.118): «مُخصَّص» / Custom — every gift in it names its owner (`ownerUserId`), who
 * earns GIFT_CUSTOM_OWNER_PERCENT of each send as coins; sent with coins only.
 */
export const CUSTOM_CATEGORY: GiftCategoryCode = 'CUSTOM';
/** `gift_categories_code_format`: upper-case letters, digits and `_`, 1–40 characters, starting with a letter. */
export const GIFT_CATEGORY_CODE_PATTERN = /^[A-Z][A-Z0-9_]{0,39}$/;
/** The five categories the migration seeded, in their order (tests and the CLI's help). */
export const SEEDED_GIFT_CATEGORIES: readonly GiftCategoryCode[] = [
  'POPULAR',
  'EVENT',
  'FUN',
  'LUCKY',
  'QUIPS',
];
export const GIFT_CATEGORY_KINDS: readonly GiftCategoryKind[] = ['NORMAL', 'LUCKY', 'QUIPS', 'CUSTOM'];
export const GIFT_BADGES: readonly GiftBadge[] = ['NONE', 'NEW', 'EVENT'];
/** v1.43-live (D195): the PK boosters a gift may activate (`--pk-booster`). */
export const GIFT_PK_BOOSTERS: readonly PkBoosterKind[] = [
  'DOUBLE',
  'DOUBLE_TURBO',
  'TRIPLE',
  'TRIPLE_TURBO',
];

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
/** v1.32-live (D154): a quip's sound is 200 ms … 15 s (CHECK `gifts_quip_fields`). */
export const QUIP_SOUND_MS_MIN = 200;
export const QUIP_SOUND_MS_MAX = 15_000;
/** v1.32-live (D154): a quip's line of text, 1–200 characters after trimming. */
export const QUIP_TEXT_MAX = 200;

export interface GiftFields {
  readonly category: GiftCategoryCode;
  readonly nameAr: string;
  readonly nameEn: string;
  readonly priceCoins: number;
  readonly assetKey: string;
  readonly animationKey: string | null;
  readonly sortOrder: number;
  /**
   * Deprecated v1.79-live (D289): the single value of an older client (`gift-admin --badge`, tests); applied to the set
   * with {@link applyLegacyGiftBadge} when `badges` is absent. Absent: NONE on add, unchanged on update.
   */
  readonly badge?: GiftBadge;
  /** v1.79-live (D289, §10.102): the badges with their ends (checked by `resolveItemBadges`). Absent: unchanged. */
  readonly badges?: readonly ItemBadgeSetting[];
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
  /**
   * v1.46-live (D207): the hosted effect's format (with `animationObjectKey`) and an MP4's transparency, and the
   * hosted MP3 sound (key, bytes, length; never on QUIPS). Absent: unchanged / none.
   */
  readonly animationFormat?: GiftAnimationFormat | null;
  readonly animationAlpha?: GiftVideoAlpha | null;
  readonly audioObjectKey?: string | null;
  readonly audioBytes?: number | null;
  readonly audioMs?: number | null;
  /**
   * v1.32-live (D154): a QUIPS gift's bundled sound (an app asset key like `asset` keys), its length
   * in ms and its optional line of text. Set exactly for QUIPS (`gifts_quip_fields`).
   */
  readonly soundKey?: string | null;
  readonly soundMs?: number | null;
  readonly quipText?: string | null;
  /**
   * v1.43-live (D195, §10.58): the PK booster this gift activates (`gifts_pk_booster_kind`: never a
   * LUCKY or QUIPS gift), or null / absent: an ordinary gift.
   */
  readonly pkBooster?: PkBoosterKind | null;
  /**
   * v1.100-social (D312, §10.118): the owner «صاحب الهدية» of a CUSTOM gift — an ACTIVE account's id (checked in the
   * write's transaction). Set exactly for CUSTOM (`gifts_custom_owner`). Absent: none on add, unchanged on update.
   */
  readonly ownerUserId?: string | null;
}

/**
 * v1.43-live (D195, §10.58): the four PK boosters' activation gifts with the suggested default prices
 * (owner-confirmable; 1 000 000 coins = $12.50 retail, D188): «دبل» ×2 5 000 coins (≈ $0.06), «دبل
 * تيربو» ×3 20 000 (≈ $0.25), «تربل» ×5 50 000 (≈ $0.63), «تربل تيربو» ×10 150 000 (≈ $1.88). Category
 * POPULAR (the host share of a normal gift, 65 %); the app draws them from its bundled `pk/booster_*`
 * art. `gift-admin pk-boosters-seed` adds them.
 */
export const PK_BOOSTER_PACK: readonly (GiftFields & { readonly code: string })[] = [
  ['pk_double', 'DOUBLE', 'دبل', 'Double', 5_000],
  ['pk_double_turbo', 'DOUBLE_TURBO', 'دبل تيربو', 'Double Turbo', 20_000],
  ['pk_triple', 'TRIPLE', 'تربل', 'Triple', 50_000],
  ['pk_triple_turbo', 'TRIPLE_TURBO', 'تربل تيربو', 'Triple Turbo', 150_000],
].map(([code, kind, nameAr, nameEn, price], i) => ({
  code: code as string,
  category: 'POPULAR' as const,
  nameAr: nameAr as string,
  nameEn: nameEn as string,
  priceCoins: price as number,
  assetKey: `pk/booster_${(kind as string).toLowerCase()}`,
  animationKey: null,
  sortOrder: 900 + i,
  badge: 'NONE' as const,
  tagCode: null,
  tagNameAr: null,
  tagNameEn: null,
  pkBooster: kind as PkBoosterKind,
}));

/** Thrown when a change would leave a gift's fields invalid (e.g. a tag without its names). */
export class GiftFieldsError extends Error {}

/** The problem with a whole gift's tag (code and both names all set, or all null), or null. */
export function giftTagProblem(tag: Pick<GiftFields, 'tagCode' | 'tagNameAr' | 'tagNameEn'>): string | null {
  const set = [tag.tagCode, tag.tagNameAr, tag.tagNameEn].filter((v) => v !== null).length;
  if (set === 0 || set === 3) return null;
  return 'a tag needs its code and both names (--tag, --tag-ar, --tag-en), or --tag none';
}

/**
 * v1.32-live (D154): the problem with a whole gift's quip fields — a QUIPS gift has a sound and its
 * length, any other gift none of the three; only QUIPS may be free — or null.
 */
export function giftQuipProblem(
  gift: Pick<GiftFields, 'category' | 'priceCoins' | 'soundKey' | 'soundMs' | 'quipText'>,
): string | null {
  const quips = gift.category === QUIPS_CATEGORY;
  const sound = (gift.soundKey ?? null) !== null && (gift.soundMs ?? null) !== null;
  if (quips && !sound) return 'a QUIPS gift needs --sound and --sound-ms';
  if (!quips && ((gift.soundKey ?? null) !== null || (gift.soundMs ?? null) !== null)) {
    return 'only a QUIPS gift has a sound';
  }
  if (!quips && (gift.quipText ?? null) !== null) return 'only a QUIPS gift has a quip text';
  if (!quips && gift.priceCoins === 0) return 'only a QUIPS gift may be free (price 0)';
  return null;
}

/** v1.43-live (D195): a PK booster's gift is an ordinary paid gift (not LUCKY, not QUIPS), or null. */
export function giftPkBoosterProblem(gift: Pick<GiftFields, 'category' | 'pkBooster'>): string | null {
  if ((gift.pkBooster ?? null) === null) return null;
  if (gift.category === LUCKY_CATEGORY || gift.category === QUIPS_CATEGORY)
    return 'a PK booster gift cannot be LUCKY or QUIPS';
  return null;
}

/**
 * v1.100-social (D312): a CUSTOM gift names its owner and is no PK booster; any other gift has no owner — or null.
 */
export function giftCustomProblem(
  gift: Pick<GiftFields, 'category' | 'ownerUserId' | 'pkBooster'>,
): string | null {
  const custom = gift.category === CUSTOM_CATEGORY;
  const owner = (gift.ownerUserId ?? null) !== null;
  if (custom && !owner) return 'a custom gift needs its owner «صاحب الهدية»';
  if (!custom && owner) return 'only a custom gift has an owner';
  if (custom && (gift.pkBooster ?? null) !== null) return 'a custom gift cannot be a PK booster';
  return null;
}

/** v1.100-social (D312): a custom gift's owner must be an ACTIVE account (the FK would only check that it exists). */
async function assertOwnerActiveIn(tx: Tx, userId: string): Promise<void> {
  const owner = await tx.user.findUnique({ where: { id: userId }, select: { status: true } });
  if (owner?.status !== 'ACTIVE') throw new GiftFieldsError('the gift owner must be an active account');
}

/**
 * v1.46-live (D207): the problem with a whole gift's hosted effect and sound — the format goes with the key (and its
 * extension), the transparency exactly with an MP4, the sound's three fields together and never on QUIPS — or null.
 */
export function giftMediaProblem(
  gift: Pick<
    GiftFields,
    | 'category'
    | 'animationObjectKey'
    | 'animationFormat'
    | 'animationAlpha'
    | 'audioObjectKey'
    | 'audioBytes'
    | 'audioMs'
  >,
): string | null {
  const key = gift.animationObjectKey ?? null;
  const format = gift.animationFormat ?? null;
  const alpha = gift.animationAlpha ?? null;
  if (key === null && (format !== null || alpha !== null)) return 'an effect format needs an effect file';
  if (key !== null) {
    if (format === null) return 'the effect file needs its format (SVGA or MP4)';
    if (!key.endsWith(format === 'MP4' ? '.mp4' : '.svga')) return `the effect file is not an ${format}`;
    if ((format === 'MP4') !== (alpha !== null))
      return 'only an MP4 effect has a transparency (none or side-by-side)';
  }
  const audio = [gift.audioObjectKey ?? null, gift.audioBytes ?? null, gift.audioMs ?? null];
  const set = audio.filter((v) => v !== null).length;
  if (set !== 0 && set !== 3) return 'the sound needs its file, size and length';
  if (set === 3 && gift.category === QUIPS_CATEGORY) return 'a QUIPS gift has its own sound; no MP3 sound';
  return null;
}

/** Every problem with a gift's fields (empty: valid). Partial input checks only what is given. */
export function giftFieldProblems(fields: Partial<GiftFields>): string[] {
  const problems: string[] = [];
  if (fields.category !== undefined && !GIFT_CATEGORY_CODE_PATTERN.test(fields.category)) {
    problems.push('category must be a category code (A-Z, 0-9 and _, starting with a letter)');
  }
  if (
    fields.pkBooster !== undefined &&
    fields.pkBooster !== null &&
    !GIFT_PK_BOOSTERS.includes(fields.pkBooster)
  ) {
    problems.push(`pk-booster must be one of ${GIFT_PK_BOOSTERS.join(', ')} (or none)`);
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
      fields.priceCoins < 0 ||
      (fields.priceCoins < GIFT_MIN_PRICE && fields.category !== QUIPS_CATEGORY) ||
      fields.priceCoins > GIFT_MAX_PRICE)
  ) {
    problems.push(
      `price must be a whole number of coins from ${String(GIFT_MIN_PRICE)} to ${String(GIFT_MAX_PRICE)} (0: a free QUIPS gift)`,
    );
  }
  if (
    fields.soundKey !== undefined &&
    fields.soundKey !== null &&
    !GIFT_ASSET_KEY_PATTERN.test(fields.soundKey)
  ) {
    problems.push('sound must be 1–80 characters: letters, digits, _ - . /');
  }
  if (
    fields.soundMs !== undefined &&
    fields.soundMs !== null &&
    (!Number.isInteger(fields.soundMs) ||
      fields.soundMs < QUIP_SOUND_MS_MIN ||
      fields.soundMs > QUIP_SOUND_MS_MAX)
  ) {
    problems.push(
      `sound-ms must be a whole number from ${String(QUIP_SOUND_MS_MIN)} to ${String(QUIP_SOUND_MS_MAX)}`,
    );
  }
  if (
    fields.quipText !== undefined &&
    fields.quipText !== null &&
    (fields.quipText.trim().length === 0 || fields.quipText.trim().length > QUIP_TEXT_MAX)
  ) {
    problems.push(`quip-text must be 1–${String(QUIP_TEXT_MAX)} characters`);
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

/**
 * v1.79-live (D289): the badge columns a write sets — from `badges`, else from the legacy `badge` applied to the current
 * set — with the deprecated `badge` kept in step; null when neither is given (unchanged).
 */
export function giftBadgeWrite(
  fields: Pick<GiftFields, 'badge' | 'badges'>,
  current: readonly ItemBadgeSetting[],
  now: Date,
): (ItemBadgeColumns & { badge: GiftBadge }) | null {
  let settings: readonly ItemBadgeSetting[];
  if (fields.badges !== undefined) settings = fields.badges;
  else if (fields.badge !== undefined) settings = applyLegacyGiftBadge(current, fields.badge, now);
  else return null;
  const columns = badgeColumns(settings);
  return { ...columns, badge: legacyGiftBadge(columns.badges) };
}

/** Adds a gift (enabled). Returns false when the code exists (nothing changes). */
export async function addGiftIn(
  tx: Tx,
  code: string,
  fields: GiftFields,
  now = new Date(),
): Promise<boolean> {
  const tagProblem =
    giftTagProblem(fields) ??
    giftQuipProblem(fields) ??
    giftPkBoosterProblem(fields) ??
    giftCustomProblem(fields) ??
    giftMediaProblem(fields);
  if (tagProblem !== null) throw new GiftFieldsError(tagProblem);
  await assertCategoryExistsIn(tx, fields.category);
  if (fields.ownerUserId) await assertOwnerActiveIn(tx, fields.ownerUserId);
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
        ...(giftBadgeWrite({ ...fields, badge: fields.badge ?? 'NONE' }, [], now) ?? {}),
        tagCode: fields.tagCode,
        tagNameAr: fields.tagNameAr?.trim() ?? null,
        tagNameEn: fields.tagNameEn?.trim() ?? null,
        imageObjectKey: fields.imageObjectKey ?? null,
        animationObjectKey: fields.animationObjectKey ?? null,
        animationBytes: fields.animationBytes ?? null,
        animationFormat: fields.animationFormat ?? (fields.animationObjectKey ? 'SVGA' : null),
        animationAlpha: fields.animationAlpha ?? null,
        audioObjectKey: fields.audioObjectKey ?? null,
        audioBytes: fields.audioBytes ?? null,
        audioMs: fields.audioMs ?? null,
        soundKey: fields.soundKey ?? null,
        soundMs: fields.soundMs ?? null,
        quipText: fields.quipText?.trim() ?? null,
        pkBooster: fields.pkBooster ?? null,
        ownerUserId: fields.ownerUserId ?? null,
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
  now = new Date(),
): Promise<{ before: Gift; after: Gift } | null> {
  const before = await tx.gift.findUnique({ where: { code } });
  if (!before) return null;
  const tagProblem = giftTagProblem({
    tagCode: fields.tagCode !== undefined ? fields.tagCode : before.tagCode,
    tagNameAr: fields.tagNameAr !== undefined ? fields.tagNameAr : before.tagNameAr,
    tagNameEn: fields.tagNameEn !== undefined ? fields.tagNameEn : before.tagNameEn,
  });
  if (tagProblem !== null) throw new GiftFieldsError(tagProblem);
  const quipProblem = giftQuipProblem({
    category: fields.category ?? before.category,
    priceCoins: fields.priceCoins ?? before.priceCoins,
    soundKey: fields.soundKey !== undefined ? fields.soundKey : before.soundKey,
    soundMs: fields.soundMs !== undefined ? fields.soundMs : before.soundMs,
    quipText: fields.quipText !== undefined ? fields.quipText : before.quipText,
  });
  if (quipProblem !== null) throw new GiftFieldsError(quipProblem);
  const boosterProblem = giftPkBoosterProblem({
    category: fields.category ?? before.category,
    pkBooster: fields.pkBooster !== undefined ? fields.pkBooster : before.pkBooster,
  });
  if (boosterProblem !== null) throw new GiftFieldsError(boosterProblem);
  const customProblem = giftCustomProblem({
    category: fields.category ?? before.category,
    ownerUserId: fields.ownerUserId !== undefined ? fields.ownerUserId : before.ownerUserId,
    pkBooster: fields.pkBooster !== undefined ? fields.pkBooster : before.pkBooster,
  });
  if (customProblem !== null) throw new GiftFieldsError(customProblem);
  if (fields.ownerUserId && fields.ownerUserId !== before.ownerUserId) {
    await assertOwnerActiveIn(tx, fields.ownerUserId);
  }
  const pick = <K extends keyof GiftFields & keyof Gift>(k: K) =>
    (fields[k] !== undefined ? fields[k] : before[k]) as Gift[K];
  const mediaProblem = giftMediaProblem({
    category: fields.category ?? before.category,
    animationObjectKey: pick('animationObjectKey'),
    animationFormat: pick('animationFormat'),
    animationAlpha: pick('animationAlpha'),
    audioObjectKey: pick('audioObjectKey'),
    audioBytes: pick('audioBytes'),
    audioMs: pick('audioMs'),
  });
  if (mediaProblem !== null) throw new GiftFieldsError(mediaProblem);
  if (fields.category !== undefined && fields.category !== before.category) {
    await assertCategoryExistsIn(tx, fields.category);
  }
  const { badge: _legacy, badges: _set, ...plain } = fields;
  const after = await tx.gift.update({
    where: { code },
    data: {
      ...plain,
      ...(giftBadgeWrite(fields, badgeSettingsOf(before), now) ?? {}),
      ...(fields.nameAr !== undefined ? { nameAr: fields.nameAr.trim() } : {}),
      ...(fields.nameEn !== undefined ? { nameEn: fields.nameEn.trim() } : {}),
      ...(typeof fields.tagNameAr === 'string' ? { tagNameAr: fields.tagNameAr.trim() } : {}),
      ...(typeof fields.tagNameEn === 'string' ? { tagNameEn: fields.tagNameEn.trim() } : {}),
      ...(typeof fields.quipText === 'string' ? { quipText: fields.quipText.trim() } : {}),
    },
  });
  return { before, after };
}

/** v1.46-live (D207): a gift's category must exist (the FK would refuse it less helpfully). */
async function assertCategoryExistsIn(tx: Tx, code: string): Promise<void> {
  const found = await tx.giftCategory.findUnique({ where: { code }, select: { code: true } });
  if (!found) throw new GiftFieldsError(`there is no gift category ${code}`);
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

/**
 * The catalogue order: tab (v1.46-live, D207: the categories' order, `tabs` — codes not in it last), then sort order,
 * then code.
 */
export function compareGifts(
  a: Pick<Gift, 'category' | 'sortOrder' | 'code'>,
  b: Pick<Gift, 'category' | 'sortOrder' | 'code'>,
  tabs: readonly GiftCategoryCode[] = SEEDED_GIFT_CATEGORIES,
): number {
  const at = (c: string) => {
    const i = tabs.indexOf(c);
    return i < 0 ? tabs.length : i;
  };
  const tab = at(a.category) - at(b.category);
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
  gifts: readonly (Pick<
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
    | 'soundKey'
    | 'soundMs'
    | 'quipText'
  > &
    Partial<Pick<Gift, 'animationFormat' | 'animationAlpha' | 'audioObjectKey'>> &
    Partial<ItemBadgeColumns> & {
      /** v1.100-social (D312): a custom gift's owner as the app shows it (a rename or a new avatar reloads). */
      readonly ownerShown?: readonly (string | null)[] | null;
    })[],
  quantities: readonly number[],
  comboWindowSeconds: number,
  tabs?: readonly {
    readonly code: string;
    readonly nameAr: string;
    readonly nameEn: string;
    readonly iconObjectKey: string | null;
  }[],
  now = new Date(),
  /** v1.89-live (D318): the lucky chat threshold (a change reloads the app's catalogue); undefined: not hashed. */
  luckyChatMinMultiplier?: number,
): string {
  // v1.79-live (D289): the badges running at `now` (a badge's end changes the version, so the app reloads the
  // catalogue); a gift without badges keeps its old hash part ('NONE' where the single badge was).
  const running = (g: Partial<ItemBadgeColumns> & Pick<Gift, 'badge'>) =>
    g.badges === undefined
      ? null
      : activeItemBadges(
          {
            badges: g.badges,
            badgeNewUntil: g.badgeNewUntil ?? null,
            badgeLimitedUntil: g.badgeLimitedUntil ?? null,
            badgeSeasonalUntil: g.badgeSeasonalUntil ?? null,
          },
          now,
        );
  const canonical = JSON.stringify({
    q: quantities,
    c: comboWindowSeconds,
    ...(luckyChatMinMultiplier !== undefined ? { l: luckyChatMinMultiplier } : {}),
    // v1.27-live (D132): the tabs; v1.46-live (D207): with both names and the icon (they are managed now).
    ...(tabs ? { t: tabs.map((t) => [t.code, t.nameAr, t.nameEn, t.iconObjectKey]) } : {}),
    g: gifts.map((g) => [
      g.code,
      g.category,
      g.nameAr,
      g.nameEn,
      g.priceCoins,
      g.assetKey,
      g.animationKey,
      g.sortOrder,
      ...((b) =>
        b === null
          ? [g.badge]
          : b.length === 0
            ? ['NONE']
            : ['badges', ...b.map((x) => `${x.code}@${x.until ?? ''}`)])(running(g)),
      // v1.24.3-live: the sub-category (appended, so a gift without one keeps its old hash part).
      ...(g.tagCode === null ? [] : [g.tagCode, g.tagNameAr, g.tagNameEn]),
      // v1.26.2-live: the hosted art (appended only when set, so other gifts keep their hash part).
      ...(g.imageObjectKey === null && g.animationObjectKey === null
        ? []
        : ['art', g.imageObjectKey, g.animationObjectKey]),
      // v1.32-live (D154): a quip's sound and text (appended only when set).
      ...(g.soundKey === null ? [] : ['quip', g.soundKey, g.soundMs, g.quipText]),
      // v1.46-live (D207): an MP4 effect's transparency and the hosted MP3 (appended only when set).
      ...(g.animationFormat === 'MP4' ? ['mp4', g.animationAlpha] : []),
      ...(g.audioObjectKey ? ['mp3', g.audioObjectKey] : []),
      // v1.100-social (D312): a custom gift's owner (appended only when set).
      ...(g.ownerShown ? ['owner', ...g.ownerShown] : []),
    ]),
  });
  return createHash('sha256').update(canonical).digest('hex').slice(0, 16);
}
