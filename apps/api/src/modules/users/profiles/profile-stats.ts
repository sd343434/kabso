import type { PrismaService } from '../../../prisma/prisma.service.js';

/**
 * v1.77-social (D220, CONVENTIONS §10.74): a user's two lifetime totals on the person card.
 *
 * - `cherriesReceived`: the cherries their received gifts credited — Σ `cherry_ledger.delta` with reason
 *   `GIFT_RECEIVED` or `GIFT_REVERSAL` (a reversed gift no longer counts; never below 0). Agency commissions, task
 *   rewards, sales, withdrawals and team adjustments are not gifts and are left out. Read through the index
 *   `cherry_ledger_user_reason_idx`.
 * - `coinsSent`: the coins they paid for the gifts they sent — Σ `live_gifts.coins_charged` (lives and direct
 *   messages, lucky gifts included; a gift sent from the bag charged 0 coins and adds nothing). Read through the
 *   index `live_gifts_sender_room_idx` (sender first).
 *
 * Aggregated totals only: no gift, sender, recipient or date leaves this function.
 */
export interface ProfileStatsTotals {
  cherriesReceived: number;
  coinsSent: number;
}

export async function profileStatsTotals(
  prisma: Pick<PrismaService, '$queryRaw'>,
  userId: string,
  which: { cherries: boolean; coins: boolean } = { cherries: true, coins: true },
): Promise<Partial<ProfileStatsTotals>> {
  const [cherries, coins] = await Promise.all([
    which.cherries
      ? prisma.$queryRaw<{ n: bigint }[]>`
          SELECT COALESCE(sum(delta), 0)::bigint AS n FROM cherry_ledger
           WHERE user_id = ${userId}::uuid
             AND reason IN ('GIFT_RECEIVED'::cherry_ledger_reason, 'GIFT_REVERSAL'::cherry_ledger_reason)`
      : Promise.resolve(null),
    which.coins
      ? prisma.$queryRaw<{ n: bigint }[]>`
          SELECT COALESCE(sum(coins_charged), 0)::bigint AS n FROM live_gifts WHERE sender_id = ${userId}::uuid`
      : Promise.resolve(null),
  ]);
  const total = (rows: { n: bigint }[] | null): number | undefined => {
    if (!rows) return undefined;
    const n = rows[0]?.n ?? 0n;
    return n > 0n ? Number(n) : 0;
  };
  const out: Partial<ProfileStatsTotals> = {};
  const c = total(cherries);
  const k = total(coins);
  if (c !== undefined) out.cherriesReceived = c;
  if (k !== undefined) out.coinsSent = k;
  return out;
}
