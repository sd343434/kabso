import { Prisma } from '../../generated/prisma/client.js';
import type { PrismaService } from '../../prisma/prisma.service.js';

type Db = Prisma.TransactionClient | PrismaService;

/**
 * v1.27.6-live (D140, CONVENTIONS §10.31): the audience record of a live, kept next to the presence
 * rows (`live_room_viewers`, who is connected now). A join opens a visit (the first join also sets
 * `first_joined_at`); every way a presence row goes away closes the open visits it ends, adding
 * their time to `watch_ms`. A visit still open when it is read counts until the room's end (or
 * now while LIVE), so a missed close never stretches a live's watch time past its end.
 */

/** A recorded viewer is connected: opens a visit unless one is open (a repeated webhook). */
export async function openVisit(
  db: Db,
  roomId: string,
  identity: string,
  userId: string | null,
  at: Date,
): Promise<void> {
  const ts = at.toISOString();
  await db.$executeRaw`
    INSERT INTO live_room_audience (room_id, identity, user_id, first_joined_at, watch_ms, open_since)
    VALUES (${roomId}::uuid, ${identity}, ${userId}::uuid, ${ts}::timestamptz, 0, ${ts}::timestamptz)
    ON CONFLICT (room_id, identity) DO UPDATE
       SET open_since = COALESCE(live_room_audience.open_since, EXCLUDED.open_since)`;
}

/**
 * Closes the open visits of `identities` in the room (every open visit when `null`) at `at`, but
 * never later than the room's end.
 */
export async function closeVisits(
  db: Db,
  roomId: string,
  identities: readonly string[] | null,
  at: Date,
): Promise<void> {
  if (identities !== null && identities.length === 0) return;
  const ts = at.toISOString();
  const which =
    identities === null ? Prisma.sql`TRUE` : Prisma.sql`a.identity IN (${Prisma.join([...identities])})`;
  await db.$executeRaw`
    UPDATE live_room_audience a
       SET watch_ms = a.watch_ms + GREATEST(0, floor(extract(epoch FROM (
             LEAST(${ts}::timestamptz, COALESCE(r.ended_at, ${ts}::timestamptz)) - a.open_since)) * 1000))::bigint,
           open_since = NULL
      FROM live_rooms r
     WHERE r.id = a.room_id AND a.room_id = ${roomId}::uuid AND a.open_since IS NOT NULL AND ${which}`;
}

/**
 * Closes the open visits of every room that is no longer LIVE (the sweeper's presence clean-up,
 * §10.8), at the room's end.
 */
export async function closeVisitsOfEndedRooms(db: Db): Promise<void> {
  await db.$executeRaw`
    UPDATE live_room_audience a
       SET watch_ms = a.watch_ms + GREATEST(0, floor(extract(epoch FROM (
             COALESCE(r.ended_at, a.open_since) - a.open_since)) * 1000))::bigint,
           open_since = NULL
      FROM live_rooms r
     WHERE r.id = a.room_id AND r.status <> 'LIVE' AND a.open_since IS NOT NULL`;
}

/**
 * `viewer_count` = connected identities other than the host; `peak_viewer_count` keeps the most at
 * once (left NULL for a live from before D140).
 */
export async function recountViewers(db: Db, roomId: string): Promise<void> {
  await db.$executeRaw`
    UPDATE live_rooms r
       SET viewer_count = c.n,
           peak_viewer_count = CASE WHEN r.peak_viewer_count IS NULL THEN NULL
                                    ELSE GREATEST(r.peak_viewer_count, c.n) END
      FROM (SELECT count(*)::int AS n FROM live_room_viewers v WHERE v.room_id = ${roomId}::uuid) c
     WHERE r.id = ${roomId}::uuid`;
}
