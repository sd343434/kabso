import type { Prisma } from '../../generated/prisma/client.js';

/**
 * Serializes follow and block writes between two users (in either direction) for the rest of
 * `tx`: a follow can never commit around a concurrent block (CONVENTIONS §11.7).
 */
export async function lockUserPairIn(tx: Prisma.TransactionClient, a: string, b: string): Promise<void> {
  const [low, high] = a < b ? [a, b] : [b, a];
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:user-pair'), hashtext(${`${low}:${high}`}::text))`;
}

/** Whether either user blocked the other. */
export async function blockedEitherWayIn(
  tx: Prisma.TransactionClient,
  a: string,
  b: string,
): Promise<boolean> {
  const n = await tx.userBlock.count({
    where: {
      OR: [
        { blockerId: a, blockedId: b },
        { blockerId: b, blockedId: a },
      ],
    },
  });
  return n > 0;
}
