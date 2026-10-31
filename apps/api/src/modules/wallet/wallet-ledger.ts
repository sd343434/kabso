import type { Prisma } from '../../generated/prisma/client.js';

/**
 * CP-017 (D104): why a balance changed (`wallet_ledger_reason`). v1.21-live (CP-018, D106):
 * creating a family, a CP request (taken at send), its refund, and a CP gift. v1.23-live (CP-020,
 * D108): a gift sent in a live and paid with coins.
 */
export type WalletLedgerReason =
  | 'ADMIN_GRANT'
  | 'ADMIN_REVOKE'
  | 'BULLET_MESSAGE'
  | 'FAMILY_CREATE'
  | 'CP_REQUEST'
  | 'CP_REFUND'
  | 'CP_GIFT'
  | 'LIVE_GIFT'
  /** v1.27-live (D132): a LUCKY gift's charge (10 % counts for the family) and the coins it won. */
  | 'LUCKY_GIFT'
  | 'LUCKY_GIFT_WIN'
  /** v1.28-live (D146): renting a premium username and renewing it (reference: the payment). */
  | 'PREMIUM_USERNAME_RENT'
  | 'PREMIUM_USERNAME_RENEW'
  /** v1.33-live (D154b): a traffic card bought with coins, and its refund when it never ran. */
  | 'LIVE_BOOST'
  | 'LIVE_BOOST_REFUND'
  /** v1.40-social (D155): a gift sent in a direct conversation. */
  | 'DM_GIFT'
  /** v1.44-social (D166): a claimed task, a daily check-in and an event prize (credits). */
  | 'TASK_REWARD'
  | 'CHECK_IN_REWARD'
  | 'EVENT_PRIZE'
  /** v1.54-social (D185): coins bought from a recharge agent (reference: the sale). */
  | 'RECHARGE_PURCHASE'
  /**
   * v1.59-social (D190): coins bought on the website (reference: the order), taken back after a refund, an
   * early-fraud warning or a dispute (reference: the Stripe event) and given back when a dispute is won.
   */
  | 'CARD_TOPUP'
  | 'CARD_TOPUP_REVERSAL'
  | 'CARD_TOPUP_RESTORE';

/** The largest balance (CONVENTIONS §3: exact as a JSON number; CHECK `wallets_coins_range`). */
export const MAX_COINS = 9_007_199_254_740_991n;

export interface WalletChange {
  /** The balance after the change. */
  readonly coins: bigint;
  /** The `wallet_ledger` row written with it. */
  readonly ledgerId: string;
}

/**
 * Adds `amount` (> 0) coins to `userId`'s balance and writes the ledger row, inside the caller's
 * transaction (the wallet row is created on first use). `(reason, referenceId)` is unique: a
 * second change with the same reference fails with a unique violation and the transaction rolls
 * back. Shared by the API and the `wallet-admin` CLI (no Nest dependencies).
 */
export async function creditIn(
  tx: Prisma.TransactionClient,
  userId: string,
  amount: bigint,
  reason: WalletLedgerReason,
  referenceId: string,
): Promise<WalletChange> {
  if (amount <= 0n) throw new RangeError('A credit is positive');
  const [row] = await tx.$queryRaw<{ coins: bigint }[]>`
    INSERT INTO wallets (user_id, coins, updated_at) VALUES (${userId}::uuid, ${amount}, now())
    ON CONFLICT (user_id) DO UPDATE SET coins = wallets.coins + EXCLUDED.coins, updated_at = now()
    RETURNING coins`;
  const coins = row!.coins;
  const entry = await tx.walletLedgerEntry.create({
    data: { userId, delta: amount, balanceAfter: coins, reason, referenceId },
    select: { id: true },
  });
  return { coins, ledgerId: entry.id };
}

/**
 * Takes `amount` (> 0) coins from `userId`'s balance and writes the ledger row, inside the
 * caller's transaction. One conditional UPDATE (the row lock serializes concurrent charges), so
 * a balance never goes below 0: returns null — and changes nothing — when the balance (0 without
 * a wallet row) does not cover the amount.
 */
export async function debitIn(
  tx: Prisma.TransactionClient,
  userId: string,
  amount: bigint,
  reason: WalletLedgerReason,
  referenceId: string,
): Promise<WalletChange | null> {
  if (amount <= 0n) throw new RangeError('A debit is positive');
  const [row] = await tx.$queryRaw<{ coins: bigint }[]>`
    UPDATE wallets SET coins = coins - ${amount}, updated_at = now()
     WHERE user_id = ${userId}::uuid AND coins >= ${amount}
    RETURNING coins`;
  if (!row) return null;
  const entry = await tx.walletLedgerEntry.create({
    data: { userId, delta: -amount, balanceAfter: row.coins, reason, referenceId },
    select: { id: true },
  });
  return { coins: row.coins, ledgerId: entry.id };
}

/**
 * v1.59-social (D190, §10.53): takes `amount` (> 0) coins back from a website purchase even when they were already
 * spent — the balance may go below 0 (a debt the buyer's next coins pay first). Only `CARD_TOPUP_REVERSAL` may do
 * this; every other charge goes through [debitIn]. Inside the caller's transaction; the reference is unique.
 */
export async function reverseTopupIn(
  tx: Prisma.TransactionClient,
  userId: string,
  amount: bigint,
  referenceId: string,
): Promise<WalletChange> {
  if (amount <= 0n) throw new RangeError('A reversal is positive');
  const [row] = await tx.$queryRaw<{ coins: bigint }[]>`
    INSERT INTO wallets (user_id, coins, updated_at) VALUES (${userId}::uuid, ${-amount}, now())
    ON CONFLICT (user_id) DO UPDATE SET coins = wallets.coins - ${amount}, updated_at = now()
    RETURNING coins`;
  const entry = await tx.walletLedgerEntry.create({
    data: { userId, delta: -amount, balanceAfter: row!.coins, reason: 'CARD_TOPUP_REVERSAL', referenceId },
    select: { id: true },
  });
  return { coins: row!.coins, ledgerId: entry.id };
}

/**
 * v1.59-social (D190, §10.53): whether the user's coin balance is below 0 (a reversed website purchase whose coins
 * were already spent). While it is, the buyer sends no gift at all — not even from the bag — and transfers no bag
 * item (403 TOPUP_ACCOUNT_FROZEN); coin spending fails anyway (INSUFFICIENT_COINS). Inside the caller's transaction.
 */
export async function inCoinDebtIn(tx: Prisma.TransactionClient, userId: string): Promise<boolean> {
  const [row] = await tx.$queryRaw<{ debt: boolean }[]>`
    SELECT EXISTS (SELECT 1 FROM wallets WHERE user_id = ${userId}::uuid AND coins < 0) AS debt`;
  return row?.debt === true;
}
