import type { ContentLanguage } from '../../common/http/content-language.js';

/**
 * CP couples (العلاقة, CP-018, owner D106, CONVENTIONS §10.21). The request price and lifetime are
 * the owner's; the gift amounts and the tier names and thresholds are CTO defaults the owner may
 * change (named constants here and in the contract).
 */

/** What a CP request costs; taken at send, given back when it is declined, cancelled or expires. */
export const CP_REQUEST_COST_COINS = 99;
/** A CP request expires 7 days after it was sent. */
export const CP_REQUEST_TTL_MS = 7 * 24 * 3600_000;
/** The CP gift amounts (coins) a partner may send; each adds the same number of CP points. */
export const CP_GIFT_AMOUNTS: readonly number[] = [10, 52, 99, 520, 1314];

/** v1.24-live (CP-021, owner D112): a named CP gift card — one per amount, same order. */
export interface CpGiftPreset {
  /** Stable code (never renamed; the app keys its art on it). */
  readonly code: string;
  readonly amount: number;
  readonly nameAr: string;
  readonly nameEn: string;
  /** The app's image for the card (`assets/cp/gifts/<assetKey>`). */
  readonly assetKey: string;
}

/** The owner's CP gift names (D112), mapped to {@link CP_GIFT_AMOUNTS} ascending. */
export const CP_GIFT_PRESETS: readonly CpGiftPreset[] = [
  { code: 'rose_love', amount: 10, nameAr: 'وردة الحب', nameEn: 'Rose Love', assetKey: 'cp_gift_rose_love' },
  {
    code: 'angel_heart',
    amount: 52,
    nameAr: 'قلب الملاك',
    nameEn: 'Angel Heart',
    assetKey: 'cp_gift_angel_heart',
  },
  {
    code: 'love_carriage',
    amount: 99,
    nameAr: 'عربة الحب',
    nameEn: 'Love Carriage',
    assetKey: 'cp_gift_love_carriage',
  },
  {
    code: 'swan_love',
    amount: 520,
    nameAr: 'بجعتا الحب',
    nameEn: 'Swan Love',
    assetKey: 'cp_gift_swan_love',
  },
  {
    code: 'eternal_heart',
    amount: 1314,
    nameAr: 'القلب الأبدي',
    nameEn: 'Eternal Heart',
    assetKey: 'cp_gift_eternal_heart',
  },
];

/** The preset of a gift `amount`, or null (an amount no longer offered). */
export function cpGiftPresetFor(amount: number): CpGiftPreset | null {
  return CP_GIFT_PRESETS.find((p) => p.amount === amount) ?? null;
}

/** One CP tier: the level reached at `minPoints` CP points, with its Arabic and English names. */
export interface CpTier {
  readonly level: number;
  readonly minPoints: number;
  readonly nameAr: string;
  readonly nameEn: string;
}

/** The CP tiers (CTO default, D106; level 6 owner D113, its name a CTO default). */
export const CP_TIERS: readonly CpTier[] = [
  { level: 1, minPoints: 0, nameAr: 'ثنائي متحمّس', nameEn: 'Eager couple' },
  { level: 2, minPoints: 520, nameAr: 'ثنائي فضّي', nameEn: 'Silver couple' },
  { level: 3, minPoints: 1314, nameAr: 'ثنائي ذهبي', nameEn: 'Gold couple' },
  { level: 4, minPoints: 5200, nameAr: 'ثنائي ماسي', nameEn: 'Diamond couple' },
  { level: 5, minPoints: 13140, nameAr: 'ثنائي أسطوري', nameEn: 'Legendary couple' },
  { level: 6, minPoints: 52000, nameAr: 'ثنائي أبدي', nameEn: 'Eternal couple' },
];

/** The CP level for `points`. */
export function cpLevelFor(points: number | bigint): number {
  const value = Number(points);
  let level = 1;
  for (const tier of CP_TIERS) if (value >= tier.minPoints) level = tier.level;
  return level;
}

/** A tier's name in `lang`. */
export function cpTierName(level: number, lang: ContentLanguage): string {
  const tier = CP_TIERS.find((t) => t.level === level) ?? CP_TIERS[0]!;
  return lang === 'ar' ? tier.nameAr : tier.nameEn;
}

/** The next tier after `level`, or null at the top. */
export function cpNextTier(level: number): CpTier | null {
  return CP_TIERS.find((t) => t.level === level + 1) ?? null;
}
