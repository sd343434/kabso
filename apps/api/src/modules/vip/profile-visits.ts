import { Prisma } from '../../generated/prisma/client.js';
import type { PrismaService } from '../../prisma/prisma.service.js';

/** A second opening within this long is the same visit (not counted again). */
export const PROFILE_VISIT_GAP_MS = 10 * 60 * 1000;

/** «من زار ملفي» lists the visitors of the last this many days, newest first, at most {@link PROFILE_VISITORS_MAX}. */
export const PROFILE_VISITORS_DAYS = 30;
export const PROFILE_VISITORS_MAX = 100;

/**
 * v1.83-social (D258, §10.94.9): [visitorId] opened [ownerId]'s profile at [now]. Never for oneself, never while either
 * blocked the other. One row per pair: the last visit moves; `visits` grows only for an opening at least
 * {@link PROFILE_VISIT_GAP_MS} after the last one. Best effort: a failure never fails the profile read.
 */
export async function recordProfileVisit(
  prisma: PrismaService,
  ownerId: string,
  visitorId: string,
  now: Date,
): Promise<void> {
  if (ownerId === visitorId) return;
  const gap = new Date(now.getTime() - PROFILE_VISIT_GAP_MS);
  await prisma.$executeRaw(Prisma.sql`
    INSERT INTO profile_visits (owner_id, visitor_id, first_visited_at, last_visited_at, visits)
    SELECT ${ownerId}::uuid, ${visitorId}::uuid, ${now}, ${now}, 1
    WHERE NOT EXISTS (
      SELECT 1 FROM user_blocks
      WHERE (blocker_id = ${ownerId}::uuid AND blocked_id = ${visitorId}::uuid)
         OR (blocker_id = ${visitorId}::uuid AND blocked_id = ${ownerId}::uuid)
    )
    ON CONFLICT (owner_id, visitor_id) DO UPDATE
      SET last_visited_at = EXCLUDED.last_visited_at,
          visits = profile_visits.visits + CASE WHEN profile_visits.last_visited_at <= ${gap} THEN 1 ELSE 0 END
      WHERE profile_visits.last_visited_at < EXCLUDED.last_visited_at`);
}
