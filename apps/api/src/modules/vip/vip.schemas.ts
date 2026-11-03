import { z } from 'zod';
import {
  VIP_CODE_PATTERN,
  VIP_COLOR_PATTERN,
  VIP_MAX_DURATION_DAYS,
  VIP_MAX_PERKS,
  VIP_MAX_PRICE_COINS,
} from './vip-rules.js';

/** v1.82-social (D252, CONVENTIONS §10.92): request bodies of «شراء VIP» and its panel page. */

const reason = z.string().trim().min(1).max(500);
const tierName = z.string().trim().min(1).max(30);
const perkTitle = z.string().trim().min(1).max(40);
const perkText = z.string().trim().max(200);
const price = z.number().int().min(1).max(VIP_MAX_PRICE_COINS);
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

export const vipPerkInput = z.strictObject({
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
  /** The tier BADGE (central crest): an SVGA animation and a still (asset path or https URL). */
  badgeAnimation: artRef.nullable().optional(),
  badgeStill: artRef.nullable().optional(),
  priceCoins: price,
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
    badgeAnimation: artRef.nullable().optional(),
    badgeStill: artRef.nullable().optional(),
    priceCoins: price.optional(),
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

export const buyVipBody = z.strictObject({
  tierId: z.uuid(),
  priceCoins: price,
});
