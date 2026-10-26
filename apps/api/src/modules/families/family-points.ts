import type { Prisma } from '../../generated/prisma/client.js';
import { uuidv7 } from '../levels/uuidv7.js';
import type { WalletLedgerReason } from '../wallet/wallet-ledger.js';
import { familyLevelFor } from './families.constants.js';

/**
 * Wallet debits that count for the spender's family at the moment they are made (CP-018, D106,
 * CONVENTIONS §10.21): bullet messages, creating a family and CP gifts. A CP request counts only
 * when it is accepted (until then its coins may come back), through {@link creditFamilyForSpendIn}
 * called by the couples module; admin revokes and refunds never count.
 */
export const FAMILY_SPEND_REASONS: ReadonlySet<WalletLedgerReason> = new Set([
  'BULLET_MESSAGE',
  'FAMILY_CREATE',
  'CP_GIFT',
]);

/**
 * Adds `coins` family points for a wallet debit of `userId` to the family they belong to now,
 * inside the caller's transaction: a `family_points_ledger` row (unique per wallet ledger row, so
 * a spend never counts twice), the member's and the family's points, and the family level. Not in
 * a family → nothing. Locks the family row (after the caller's wallet row: the same order as every
 * money path). Shared by the API and the CLIs (no Nest dependencies).
 */
export async function creditFamilyForSpendIn(
  tx: Prisma.TransactionClient,
  userId: string,
  walletLedgerId: string,
  coins: bigint,
): Promise<void> {
  if (coins <= 0n) return;
  const [member] = await tx.$queryRaw<{ family_id: string }[]>`
    SELECT family_id::text AS family_id FROM family_members WHERE user_id = ${userId}::uuid FOR SHARE`;
  if (!member) return;
  const inserted = await tx.$executeRaw`
    INSERT INTO family_points_ledger (id, family_id, user_id, wallet_ledger_id, points, created_at)
    VALUES (${uuidv7()}::uuid, ${member.family_id}::uuid, ${userId}::uuid, ${walletLedgerId}::uuid, ${coins}, now())
    ON CONFLICT (wallet_ledger_id) DO NOTHING`;
  if (inserted === 0) return;
  await tx.$executeRaw`
    UPDATE family_members SET points = points + ${coins} WHERE user_id = ${userId}::uuid`;
  const [family] = await tx.$queryRaw<{ points: bigint; level: number }[]>`
    UPDATE families SET points = LEAST(points + ${coins}, 9007199254740991), updated_at = now()
     WHERE id = ${member.family_id}::uuid
    RETURNING points, level`;
  if (!family) return;
  const level = familyLevelFor(family.points);
  if (level !== family.level) {
    await tx.$executeRaw`UPDATE families SET level = ${level} WHERE id = ${member.family_id}::uuid`;
  }
}
