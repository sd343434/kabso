import { Prisma } from '../../generated/prisma/client.js';
import type { PrismaService } from '../../prisma/prisma.service.js';

/**
 * Open reports of a live (CONVENTIONS §10.91.2): on the room, or on its host as a user since the live started;
 * v1.68-live (D273, §10.96.6): also on its chat messages and on users reported inside it (the report's context live).
 */
const OPEN_LIVE_REPORTS_SQL = (roomFilter: Prisma.Sql) => Prisma.sql`
  SELECT r.id::text AS room_id, count(rep.id)::int AS n
    FROM live_rooms r
    JOIN reports rep ON rep.status = 'OPEN'::report_status AND (
         rep.target_live_room_id = r.id
      OR (rep.target_type = 'USER'::report_target_type AND rep.target_user_id = r.host_user_id
          AND rep.created_at >= r.started_at)
      OR rep.context_live_room_id = r.id
      OR rep.target_live_chat_message_id IN (SELECT m.id FROM live_chat_messages m WHERE m.room_id = r.id))
   WHERE ${roomFilter}
   GROUP BY r.id`;

/** Open reports per room: every LIVE room, or the given rooms whatever their status (only rooms with at least one). */
export async function openLiveReportsByRoom(
  db: Pick<PrismaService, '$queryRaw'>,
  roomIds?: readonly string[],
): Promise<Map<string, number>> {
  const filter =
    roomIds === undefined
      ? Prisma.sql`r.status = 'LIVE'::live_room_status`
      : roomIds.length === 0
        ? Prisma.sql`false`
        : Prisma.sql`r.id IN (${Prisma.join(roomIds.map((id) => Prisma.sql`${id}::uuid`))})`;
  const rows = await db.$queryRaw<{ room_id: string; n: number }[]>(OPEN_LIVE_REPORTS_SQL(filter));
  return new Map(rows.map((r) => [r.room_id, r.n]));
}
