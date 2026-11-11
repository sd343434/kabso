import type { Prisma } from '../../generated/prisma/client.js';

type Db = Pick<Prisma.TransactionClient, '$queryRaw'>;

/**
 * v1.127-social (D372, CONVENTIONS §10.164; owner: «المضيفون وصناع المحتوى فقط»): of `userIds`, those who may receive a
 * gift on their posts and reels — a host (the hosting permission, `live_hosts`, any source: an admin's or the team's
 * approval, an agency's activation, a creator membership) or a content creator (`creator_members`).
 */
export async function contentGiftRecipients(db: Db, userIds: readonly string[]): Promise<Set<string>> {
  const ids = [...new Set(userIds)];
  if (ids.length === 0) return new Set();
  const rows = await db.$queryRaw<{ user_id: string }[]>`
    SELECT h.user_id::text AS user_id FROM live_hosts h WHERE h.user_id = ANY(${ids}::uuid[])
    UNION
    SELECT cm.user_id::text AS user_id FROM creator_members cm WHERE cm.user_id = ANY(${ids}::uuid[])`;
  return new Set(rows.map((r) => r.user_id));
}

/** Whether `userId` may receive a gift on their content ({@link contentGiftRecipients}). */
export async function isContentGiftRecipient(db: Db, userId: string): Promise<boolean> {
  return (await contentGiftRecipients(db, [userId])).has(userId);
}
