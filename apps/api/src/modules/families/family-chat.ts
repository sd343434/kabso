import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { Prisma } from '../../generated/prisma/client.js';

/**
 * Report hooks for family chat messages (CONVENTIONS §11.7, §10.25), pure functions the safety
 * module calls with its own Prisma client (no module import cycle).
 */

type Db = Pick<Prisma.TransactionClient, 'familyChatMessage' | 'familyMember' | 'userBlock'>;

/**
 * A family chat message `readerId` could read: not deleted, in a family that is not disbanded and
 * that the reader belongs to now, from an author with no block either way with the reader; else
 * 404. Returns its id and author.
 */
export async function readableFamilyChatMessage(
  db: Db,
  messageId: string,
  readerId: string,
): Promise<{ id: string; authorId: string }> {
  const row = await db.familyChatMessage.findFirst({
    where: { id: messageId, deletedAt: null, family: { disbandedAt: null } },
    select: { id: true, familyId: true, authorId: true },
  });
  const member = row
    ? await db.familyMember.findUnique({ where: { userId: readerId }, select: { familyId: true } })
    : null;
  if (!row || member?.familyId !== row.familyId) throw new AppException(ErrorCode.NOT_FOUND);
  if (row.authorId !== readerId) {
    const blocks = await db.userBlock.count({
      where: {
        OR: [
          { blockerId: readerId, blockedId: row.authorId },
          { blockerId: row.authorId, blockedId: readerId },
        ],
      },
    });
    if (blocks > 0) throw new AppException(ErrorCode.NOT_FOUND);
  }
  return { id: row.id, authorId: row.authorId };
}

/** Report action `REMOVE_TARGET`, inside the caller's transaction: soft-deletes the message. */
export async function removeFamilyChatMessageIn(
  tx: Prisma.TransactionClient,
  messageId: string,
  actorId: string,
  at: Date,
): Promise<boolean> {
  const done = await tx.familyChatMessage.updateMany({
    where: { id: messageId, deletedAt: null },
    data: { deletedAt: at, deletedById: actorId },
  });
  return done.count > 0;
}
