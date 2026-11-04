import type { Prisma } from '../../generated/prisma/client.js';
import { vipActive, vipEffectivePerks } from './vip-rules.js';

/**
 * v1.65-live (D264, owner: «عند تفعيل VIP تظهر العناصر في الحقيبة … المدة تنقضي وتعد», CONVENTIONS §10.97): a VIP
 * member's wearable tier items in the bag. They are **derived** from the active membership on every read, never copied
 * into `user_bag_items`: their time is exactly the membership's (a renewal extends them, an upgrade shows the higher
 * tier's items with the lower tiers' inherited, the end removes them), with no grant to keep in step and nothing to
 * sweep. Only what the member took off is stored (`vip_memberships.off_perks`).
 */

/**
 * The wearable VIP perks and the bag category each shows in (owner: one worn item per kind). The frame and the profile
 * card share the bag's own categories (one frame, one card — the bag's header decoration or the VIP card); the others
 * are VIP-only categories.
 */
export const VIP_BAG_PERKS = {
  AVATAR_FRAME: 'AVATAR_FRAME',
  PROFILE_CARD: 'PROFILE_CARD',
  CHAT_BUBBLE: 'CHAT_BUBBLE',
  ENTRY_BANNER: 'ENTRY_BANNER',
  ENTRY_EFFECT: 'ENTRY_EFFECT',
  MIC_WAVE: 'MIC_WAVE',
} as const;
export type VipBagPerk = keyof typeof VIP_BAG_PERKS;
export type VipBagCategory = (typeof VIP_BAG_PERKS)[VipBagPerk];

/** The bag categories only VIP items have (not in `bag_category`, nothing stored). */
export const VIP_ONLY_BAG_CATEGORIES = ['CHAT_BUBBLE', 'ENTRY_BANNER', 'ENTRY_EFFECT', 'MIC_WAVE'] as const;
export type VipOnlyBagCategory = (typeof VIP_ONLY_BAG_CATEGORIES)[number];

export function isVipOnlyBagCategory(category: string): category is VipOnlyBagCategory {
  return (VIP_ONLY_BAG_CATEGORIES as readonly string[]).includes(category);
}

const PERKS = Object.keys(VIP_BAG_PERKS) as VipBagPerk[];

/** The perks whose category the bag's stored items share: one worn item there (a bag item worn covers the VIP one). */
export const VIP_SHARED_PERKS = ['AVATAR_FRAME', 'PROFILE_CARD'] as const;

/**
 * The perks a member does not wear now: those taken off in the bag ([off]) and those whose category holds a bag item
 * worn now ([bagWorn]: the worn stored items' categories) — exactly one worn item per kind.
 */
export function vipNotWorn(off: readonly string[], bagWorn: readonly string[]): string[] {
  const covered = new Set<string>(VIP_SHARED_PERKS.filter((p) => bagWorn.includes(VIP_BAG_PERKS[p])));
  return PERKS.filter((p) => off.includes(p) || covered.has(p));
}

/** A VIP bag item's code: `vip:<PERK>` (never a catalogue code, which is lower case). */
export function vipBagCode(perk: VipBagPerk): string {
  return `vip:${perk}`;
}

/** The perk of a VIP bag code, or null. */
export function vipBagPerkOf(code: string): VipBagPerk | null {
  if (!code.startsWith('vip:')) return null;
  const perk = code.slice(4);
  return (PERKS as string[]).includes(perk) ? (perk as VipBagPerk) : null;
}

/** The perk shown in [category] (null: a category without a VIP item). */
export function vipBagPerkIn(category: string): VipBagPerk | null {
  return PERKS.find((p) => VIP_BAG_PERKS[p] === category) ?? null;
}

/** [off] with [perk] taken off (`wear: false`) or worn again, in a fixed order. */
export function vipOffPerksAfter(off: readonly string[], perk: VipBagPerk, wear: boolean): string[] {
  const next = new Set(off.filter((p) => (PERKS as string[]).includes(p)));
  if (wear) next.delete(perk);
  else next.add(perk);
  return PERKS.filter((p) => next.has(p));
}

/** One VIP item the member holds now. */
export interface VipBagEntry {
  readonly perk: VipBagPerk;
  readonly category: VipBagCategory;
  readonly titleAr: string;
  readonly titleEn: string;
  readonly animation: string | null;
  readonly still: string | null;
  /** Not taken off (a bag frame worn over the VIP frame is decided by the caller). */
  readonly on: boolean;
}

/** The member's VIP bag: the membership and its wearable items (none without an active one). */
export interface VipBag {
  readonly tier: { code: string; nameAr: string; nameEn: string; color: string };
  readonly startedAt: Date;
  readonly expiresAt: Date;
  readonly off: readonly string[];
  readonly items: readonly VipBagEntry[];
}

type Db = Pick<Prisma.TransactionClient, 'vipMembership' | 'vipTier'>;

/**
 * The member's VIP bag at [now], or null without an active membership: every wearable perk the tier holds (enabled,
 * its own or a lower tier's — the highest tier's art winning for a code), in {@link VIP_BAG_PERKS} order. Listed with or
 * without art: the item is the tier's; the art comes when the owner uploads it.
 */
export async function vipBagIn(db: Db, userId: string, now: Date): Promise<VipBag | null> {
  const m = await db.vipMembership.findUnique({
    where: { userId },
    select: {
      startedAt: true,
      expiresAt: true,
      offPerks: true,
      tier: { select: { code: true, nameAr: true, nameEn: true, color: true, sortOrder: true } },
    },
  });
  if (!m || !vipActive(m.expiresAt, now)) return null;
  const tiers = await db.vipTier.findMany({
    where: { sortOrder: { lte: m.tier.sortOrder } },
    select: {
      sortOrder: true,
      perks: {
        where: { code: { in: PERKS }, enabled: true },
        select: {
          code: true,
          enabled: true,
          titleAr: true,
          titleEn: true,
          animation: true,
          still: true,
        },
      },
    },
  });
  const held = vipEffectivePerks(
    tiers.map((t) => ({ rank: t.sortOrder, perks: t.perks })),
    m.tier.sortOrder,
  );
  const items: VipBagEntry[] = [];
  for (const perk of PERKS) {
    const p = held.get(perk);
    if (!p) continue;
    items.push({
      perk,
      category: VIP_BAG_PERKS[perk],
      titleAr: p.titleAr,
      titleEn: p.titleEn,
      animation: p.animation,
      still: p.still,
      on: !m.offPerks.includes(perk),
    });
  }
  return {
    tier: { code: m.tier.code, nameAr: m.tier.nameAr, nameEn: m.tier.nameEn, color: m.tier.color },
    startedAt: m.startedAt,
    expiresAt: m.expiresAt,
    off: m.offPerks,
    items,
  };
}

/**
 * D264: the bag's worn frame and profile card give way to the member's VIP ones (one worn item per kind) — for each
 * shared perk the tier ranked [rank] holds (its own or a lower tier's, enabled) and the member did not take off.
 */
export async function wearVipItemsIn(
  tx: Pick<Prisma.TransactionClient, 'vipTierPerk' | 'userBagItem'>,
  userId: string,
  rank: number,
  off: readonly string[],
): Promise<void> {
  const held = await tx.vipTierPerk.findMany({
    where: {
      code: { in: VIP_SHARED_PERKS.filter((p) => !off.includes(p)) },
      enabled: true,
      tier: { sortOrder: { lte: rank } },
    },
    select: { code: true },
  });
  const categories = [...new Set(held.map((p) => VIP_BAG_PERKS[p.code as VipBagPerk]))];
  if (categories.length === 0) return;
  await tx.userBagItem.updateMany({
    where: { userId, equipped: true, category: { in: categories as ('AVATAR_FRAME' | 'PROFILE_CARD')[] } },
    data: { equipped: false },
  });
}
