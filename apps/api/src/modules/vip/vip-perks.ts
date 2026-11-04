import type { Prisma } from '../../generated/prisma/client.js';
import { VIP_BUILT_PERKS } from './vip-rules.js';

type Db = Pick<Prisma.TransactionClient, 'vipMembership' | 'vipTierPerk'>;

/**
 * v1.83-social (D258, CONVENTIONS §10.94.2): the number a member's VIP gives for the perk [code] now — the perk of the
 * highest-ranked tier at or below the member's (a tier holds every lower tier's perks), when that perk is enabled and
 * has an amount. Null: no active membership, the perk is not held / not built / has no amount yet.
 */
export async function vipPerkAmountIn(
  db: Db,
  userId: string,
  code: string,
  now: Date,
): Promise<number | null> {
  if (!VIP_BUILT_PERKS.has(code)) return null;
  const membership = await db.vipMembership.findUnique({
    where: { userId },
    select: { expiresAt: true, tier: { select: { sortOrder: true } } },
  });
  if (!membership || membership.expiresAt.getTime() <= now.getTime()) return null;
  const perks = await db.vipTierPerk.findMany({
    where: { code, enabled: true, tier: { sortOrder: { lte: membership.tier.sortOrder } } },
    select: { amount: true, tier: { select: { sortOrder: true } } },
  });
  let best: { amount: number | null; rank: number } | null = null;
  for (const p of perks) {
    if (best === null || p.tier.sortOrder > best.rank) best = { amount: p.amount, rank: p.tier.sortOrder };
  }
  return best?.amount ?? null;
}
