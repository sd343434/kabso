import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { findVisibleCouple } from './cp-couple-visibility.js';

/**
 * Report hooks for CP confessions (CONVENTIONS §11.7, §10.24), pure functions the safety module
 * calls with its own Prisma client (no module import cycle).
 */

type Db = Pick<Prisma.TransactionClient, '$queryRaw' | 'cpConfession'>;

/**
 * A confession `readerId` could read: not deleted, on a couple page the reader may see (§10.24);
 * else 404. Returns its id and author.
 */
export async function readableCpConfession(
  db: Db,
  confessionId: string,
  readerId: string,
): Promise<{ id: string; authorId: string }> {
  const row = await db.cpConfession.findFirst({
    where: { id: confessionId, deletedAt: null },
    select: { id: true, coupleId: true, authorId: true },
  });
  if (!row || !(await findVisibleCouple(db, row.coupleId, readerId))) {
    throw new AppException(ErrorCode.NOT_FOUND);
  }
  return { id: row.id, authorId: row.authorId };
}

/** Report action `REMOVE_TARGET`, inside the caller's transaction: soft-deletes the confession. */
export async function removeCpConfessionIn(
  tx: Prisma.TransactionClient,
  confessionId: string,
  actorId: string,
  at: Date,
): Promise<boolean> {
  const done = await tx.cpConfession.updateMany({
    where: { id: confessionId, deletedAt: null },
    data: { deletedAt: at, deletedById: actorId },
  });
  return done.count > 0;
}
