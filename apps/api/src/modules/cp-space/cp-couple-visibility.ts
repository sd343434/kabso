import type { Prisma } from '../../generated/prisma/client.js';

type Db = Pick<Prisma.TransactionClient, '$queryRaw'>;

/** A couple row as the CP space reads it. */
export interface VisibleCoupleRow {
  id: string;
  user_a_id: string;
  user_b_id: string;
  since: Date;
  points: bigint;
  level: number;
}

/**
 * The couple `coupleId` as `readerId` may see it on its CP space (CONVENTIONS §10.24, like
 * `PublicProfile.cp`): ongoing, both partners ACTIVE, and — unless the reader is one of the
 * partners — no block either way between the reader and either partner. Null (→ 404) otherwise.
 */
export async function findVisibleCouple(
  db: Db,
  coupleId: string,
  readerId: string,
): Promise<VisibleCoupleRow | null> {
  const [row] = await db.$queryRaw<VisibleCoupleRow[]>`
    SELECT c.id::text AS id, c.user_a_id::text AS user_a_id, c.user_b_id::text AS user_b_id,
           c.since, c.points, c.level
      FROM cp_couples c
      JOIN users ua ON ua.id = c.user_a_id AND ua.status = 'ACTIVE'
      JOIN users ub ON ub.id = c.user_b_id AND ub.status = 'ACTIVE'
     WHERE c.id = ${coupleId}::uuid AND c.ended_at IS NULL
       AND (${readerId}::uuid IN (c.user_a_id, c.user_b_id) OR NOT EXISTS (
             SELECT 1 FROM user_blocks b
              WHERE (b.blocker_id = ${readerId}::uuid AND b.blocked_id IN (c.user_a_id, c.user_b_id))
                 OR (b.blocked_id = ${readerId}::uuid AND b.blocker_id IN (c.user_a_id, c.user_b_id))))`;
  return row ?? null;
}

/** The caller's ongoing couple (as a partner), optionally locked FOR UPDATE; null when unpaired. */
export async function findOwnCouple(
  db: Db,
  userId: string,
  lock = false,
): Promise<(VisibleCoupleRow & { partner_id: string }) | null> {
  const [row] = lock
    ? await db.$queryRaw<(VisibleCoupleRow & { partner_id: string })[]>`
        SELECT c.id::text AS id, c.user_a_id::text AS user_a_id, c.user_b_id::text AS user_b_id,
               c.since, c.points, c.level, p.partner_id::text AS partner_id
          FROM cp_partners p JOIN cp_couples c ON c.id = p.couple_id AND c.ended_at IS NULL
         WHERE p.user_id = ${userId}::uuid
           FOR UPDATE OF c`
    : await db.$queryRaw<(VisibleCoupleRow & { partner_id: string })[]>`
        SELECT c.id::text AS id, c.user_a_id::text AS user_a_id, c.user_b_id::text AS user_b_id,
               c.since, c.points, c.level, p.partner_id::text AS partner_id
          FROM cp_partners p JOIN cp_couples c ON c.id = p.couple_id AND c.ended_at IS NULL
         WHERE p.user_id = ${userId}::uuid`;
  return row ?? null;
}
