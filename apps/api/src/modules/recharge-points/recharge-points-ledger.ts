import type { Prisma, RechargePointsReason } from '../../generated/prisma/client.js';

/**
 * Recharge points «نقاط الشحن» (v1.126-social, D370, owner 2026-11-11, CONVENTIONS §10.162): every coin a person
 * RECEIVES from a paid recharge is one point — a website card top-up (`RECHARGE_WEB`), an App Store / Google Play
 * purchase (`RECHARGE_STORE`) and coins from a recharge agent, sold directly or through an order (`RECHARGE_AGENT`,
 * to the buyer, never to the agent). The points never expire; they buy VIP (`VIP_REDEEM`). A reversed recharge takes
 * its points back (`REVERSAL`, the balance may go below 0); the team corrects with `ADMIN_ADJUST` (audited).
 *
 * Not counted (they never call {@link earnRechargePointsIn}): daily coins, tasks, check-ins, lucky / event prizes, VIP
 * daily coins, cherry → coin conversions, admin grants, gifts received, refunds. A recharge agent's stock purchases
 * go to the stock (not a wallet) and an agent cannot sell to their own account, so an agent earns nothing from the
 * agent side; coins an agent buys for their own wallet on the website or in a store count like anyone's.
 *
 * Every function runs inside the caller's transaction. Shared by the API and the CLIs (no Nest dependencies).
 */

type Tx = Prisma.TransactionClient;

/** The earning reasons (credits from a paid recharge). */
export type RechargePointsEarnReason = Extract<
  RechargePointsReason,
  'RECHARGE_WEB' | 'RECHARGE_STORE' | 'RECHARGE_AGENT'
>;

export interface RechargePointsChange {
  /** The balance after the change. */
  readonly points: bigint;
  /** The ledger row written with it. */
  readonly entryId: string;
}

async function writeEntry(
  tx: Tx,
  userId: string,
  delta: bigint,
  balanceAfter: bigint,
  reason: RechargePointsReason,
  referenceId: string,
): Promise<RechargePointsChange> {
  const entry = await tx.rechargePointsEntry.create({
    data: { userId, delta, balanceAfter, reason, referenceId },
    select: { id: true },
  });
  return { points: balanceAfter, entryId: entry.id };
}

/**
 * Adds or takes [delta] (≠ 0) points without a floor (the balance may go below 0): earning, a reversal, an admin
 * adjustment. `(reason, referenceId)` is unique — a second change with the same reference fails with a unique
 * violation and the caller's transaction rolls back.
 */
export async function movePointsIn(
  tx: Tx,
  userId: string,
  delta: bigint,
  reason: RechargePointsReason,
  referenceId: string,
): Promise<RechargePointsChange> {
  if (delta === 0n) throw new RangeError('A points change is not 0');
  const [row] = await tx.$queryRaw<{ points: bigint }[]>`
    INSERT INTO recharge_points_balances (user_id, points, updated_at) VALUES (${userId}::uuid, ${delta}, now())
    ON CONFLICT (user_id) DO UPDATE
      SET points = recharge_points_balances.points + EXCLUDED.points, updated_at = now()
    RETURNING points`;
  return writeEntry(tx, userId, delta, BigInt(row!.points), reason, referenceId);
}

/**
 * The points of a recharge: [coins] (> 0) received by [userId] from a paid recharge, referenced by the recharge's own
 * id (the top-up order, the store purchase, the agent sale or order) — so each recharge earns once.
 */
export async function earnRechargePointsIn(
  tx: Tx,
  input: { userId: string; coins: bigint; reason: RechargePointsEarnReason; referenceId: string },
): Promise<RechargePointsChange> {
  if (input.coins <= 0n) throw new RangeError('A recharge is positive');
  return movePointsIn(tx, input.userId, input.coins, input.reason, input.referenceId);
}

/**
 * Takes [amount] (> 0) points for a VIP redemption: ONE conditional UPDATE (the row lock serializes concurrent
 * redemptions), so the balance never goes below 0 here — null, and nothing changed, when it does not cover the amount
 * (also with no row, or a negative balance).
 */
export async function spendPointsIn(
  tx: Tx,
  userId: string,
  amount: bigint,
  referenceId: string,
): Promise<RechargePointsChange | null> {
  if (amount <= 0n) throw new RangeError('A redemption is positive');
  const [row] = await tx.$queryRaw<{ points: bigint }[]>`
    UPDATE recharge_points_balances SET points = points - ${amount}, updated_at = now()
     WHERE user_id = ${userId}::uuid AND points >= ${amount}
    RETURNING points`;
  if (!row) return null;
  return writeEntry(tx, userId, -amount, BigInt(row.points), 'VIP_REDEEM', referenceId);
}

/** The person's balance now (0 without a row). */
export async function pointsBalanceIn(
  db: Pick<Tx, 'rechargePointsBalance'>,
  userId: string,
): Promise<bigint> {
  const row = await db.rechargePointsBalance.findUnique({ where: { userId }, select: { points: true } });
  return row?.points ?? 0n;
}

/**
 * The reference of a reversal step: the source's own step reference (the Stripe event, the refunded purchase),
 * prefixed so a website step and a store refund never share one. At most 64 characters.
 */
export function reversalReference(source: 'web' | 'store', reference: string): string {
  return `${source}:${reference}`.slice(0, 64);
}
