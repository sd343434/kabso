import { z } from 'zod';
import { ENTRY_CAR_KIND, ENTRY_DISPLAYS } from '../store/store-rules.js';
import {
  VIP_CODE_PATTERN,
  VIP_COLOR_PATTERN,
  VIP_MAX_DURATION_DAYS,
  VIP_MAX_PERKS,
  VIP_MAX_PRICE_COINS,
  VIP_MAX_PRICE_POINTS,
  VIP_PERK_AMOUNTS,
  VIP_RENEWAL_DISCOUNT_MAX,
} from './vip-rules.js';

/** v1.82-social (D252, CONVENTIONS §10.93): request bodies of «شراء VIP» and its panel page. */

const reason = z.string().trim().min(1).max(500);
const tierName = z.string().trim().min(1).max(30);
const perkTitle = z.string().trim().min(1).max(40);
const perkText = z.string().trim().max(200);
const price = z.number().int().min(1).max(VIP_MAX_PRICE_COINS);
/** v1.126-social (D370, §10.163): a tier's price in recharge points; null = not redeemable with points. */
const pointsPrice = z.number().int().min(1).max(VIP_MAX_PRICE_POINTS);
const days = z.number().int().min(1).max(VIP_MAX_DURATION_DAYS);
const color = z
  .string()
  .trim()
  .transform((v) => v.toUpperCase())
  .pipe(z.string().regex(VIP_COLOR_PATTERN));

/**
 * A reference to a piece of art (a badge or a perk's SVGA / still): a hosted https URL, uploaded from the admin
 * panel (the gifts `animationUrl` pattern, D126). Nothing is bundled in the app. D252b.
 */
const artRef = z
  .string()
  .trim()
  .regex(/^https:\/\/\S{1,2040}$/);
const artSize = z.number().int().min(1).max(8192);

export const vipPerkInput = z
  .strictObject({
    code: z.string().regex(VIP_CODE_PATTERN),
    titleAr: perkTitle,
    titleEn: perkTitle,
    descriptionAr: perkText.nullable().optional(),
    descriptionEn: perkText.nullable().optional(),
    enabled: z.boolean().optional(),
    /** The perk's own art (SVGA + still) and its intrinsic size. */
    animation: artRef.nullable().optional(),
    still: artRef.nullable().optional(),
    artWidth: artSize.nullable().optional(),
    artHeight: artSize.nullable().optional(),
    /**
     * D258: the perk's number for this tier — DAILY_BULLET (1–100 a day), DAILY_COINS (1–10^9 a day), LEVEL_SPEEDUP
     * (1–100 %); refused for other codes.
     */
    amount: z.number().int().min(1).max(1_000_000_000).nullable().optional(),
    /**
     * v1.128-social (D373, §10.165): the ENTRY_EFFECT perk's display «طريقة العرض» — FULL_SCREEN «شاشة كاملة» or
     * HALF_SCREEN «الجزء السفلي (٧٠٪)» (the screen's bottom 70 %); absent: kept as it was (FULL_SCREEN for a new perk). Refused for other codes.
     */
    entryDisplay: z.enum(ENTRY_DISPLAYS).optional(),
  })
  .superRefine((p, ctx) => {
    if (p.entryDisplay !== undefined && p.code !== ENTRY_CAR_KIND) {
      ctx.addIssue({
        code: 'custom',
        path: ['entryDisplay'],
        message: 'only the entry car perk has a display',
        params: { issue: 'not_allowed' },
      });
    }
    if (p.amount === null || p.amount === undefined) return;
    const bounds = VIP_PERK_AMOUNTS[p.code];
    if (!bounds) {
      ctx.addIssue({
        code: 'custom',
        path: ['amount'],
        message: 'no amount for this perk',
        params: { issue: 'not_allowed' },
      });
    } else if (p.amount < bounds.min || p.amount > bounds.max) {
      ctx.addIssue({
        code: 'custom',
        path: ['amount'],
        message: 'out of range',
        params: { issue: 'out_of_range' },
      });
    }
  });
export type VipPerkInput = z.output<typeof vipPerkInput>;

/** The whole list of a tier's perks, in order; codes unique within the tier. */
const perks = z
  .array(vipPerkInput)
  .max(VIP_MAX_PERKS)
  .refine((list) => new Set(list.map((p) => p.code)).size === list.length, {
    message: 'perk codes repeat',
    params: { issue: 'duplicate_code' },
  });

export const createVipTierBody = z.strictObject({
  code: z.string().regex(VIP_CODE_PATTERN),
  nameAr: tierName,
  nameEn: tierName,
  color,
  /** v1.83-social (D258): the special text colour (CHAT_NAME_COLOR), or null. */
  nameColor: color.nullable().optional(),
  /** v1.83-social (D258): percent off a renewal, 0 – 90 (default 15). */
  renewalDiscountPercent: z.number().int().min(0).max(VIP_RENEWAL_DISCOUNT_MAX).optional(),
  /** The tier BADGE (central crest): an SVGA animation and a still (asset path or https URL). */
  badgeAnimation: artRef.nullable().optional(),
  badgeStill: artRef.nullable().optional(),
  priceCoins: price,
  pointsPrice: pointsPrice.nullable().optional(),
  durationDays: days,
  enabled: z.boolean().optional(),
  perks: perks.optional(),
  reason,
});
export type CreateVipTierBody = z.output<typeof createVipTierBody>;

export const updateVipTierBody = z
  .strictObject({
    nameAr: tierName.optional(),
    nameEn: tierName.optional(),
    color: color.optional(),
    nameColor: color.nullable().optional(),
    renewalDiscountPercent: z.number().int().min(0).max(VIP_RENEWAL_DISCOUNT_MAX).optional(),
    badgeAnimation: artRef.nullable().optional(),
    badgeStill: artRef.nullable().optional(),
    priceCoins: price.optional(),
    pointsPrice: pointsPrice.nullable().optional(),
    durationDays: days.optional(),
    perks: perks.optional(),
    reason,
  })
  .refine((v) => Object.keys(v).length > 1, { message: 'nothing to change', path: ['reason'] });
export type UpdateVipTierBody = z.output<typeof updateVipTierBody>;

export const vipReasonBody = z.strictObject({ reason });

export const reorderVipTiersBody = z.strictObject({
  tierIds: z.array(z.uuid()).min(1).max(100),
  reason,
});

/**
 * `BuyVipRequest`. v1.126-social (D370, §10.163): `payWith` COINS (default; `priceCoins` required, as before) or
 * POINTS (`pricePoints` required: the points price the person was shown); the other price must be absent.
 */
export const buyVipBody = z
  .strictObject({
    tierId: z.uuid(),
    payWith: z.enum(['COINS', 'POINTS']).optional(),
    priceCoins: price.optional(),
    pricePoints: pointsPrice.optional(),
  })
  .superRefine((b, ctx) => {
    const points = b.payWith === 'POINTS';
    const need = points ? 'pricePoints' : 'priceCoins';
    const other = points ? 'priceCoins' : 'pricePoints';
    if (b[need] === undefined) {
      ctx.addIssue({ code: 'custom', path: [need], message: 'required', params: { issue: 'required' } });
    }
    if (b[other] !== undefined) {
      ctx.addIssue({
        code: 'custom',
        path: [other],
        message: 'not allowed',
        params: { issue: 'not_allowed' },
      });
    }
  })
  .transform((b) =>
    b.payWith === 'POINTS'
      ? { tierId: b.tierId, payWith: 'POINTS' as const, price: b.pricePoints! }
      : { tierId: b.tierId, payWith: 'COINS' as const, price: b.priceCoins! },
  );
export type BuyVipBody = z.output<typeof buyVipBody>;
