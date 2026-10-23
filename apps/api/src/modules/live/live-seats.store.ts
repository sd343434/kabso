import { Prisma } from '../../generated/prisma/client.js';

/**
 * CP-011 (CONVENTIONS §10.9): seat clean-up inside a caller's transaction, shared by the room
 * lifecycle (a room ends), account suspension and the seats service. Every change increases the
 * room's `seats_version`; callers that can reach the media server afterwards push the new version
 * into the room metadata, the others leave it to the sweeper's reconciliation.
 */

/** Increases the seat version of `roomIds`; returns `room id → new version`. */
export async function bumpSeatsVersionIn(
  tx: Prisma.TransactionClient,
  roomIds: readonly string[],
): Promise<Map<string, number>> {
  if (roomIds.length === 0) return new Map();
  const rows = await tx.$queryRaw<{ id: string; seats_version: number }[]>`
    UPDATE live_rooms SET seats_version = seats_version + 1
     WHERE id = ANY(${[...new Set(roomIds)]}::uuid[])
 RETURNING id::text AS id, seats_version`;
  return new Map(rows.map((r) => [r.id, r.seats_version]));
}

/**
 * A room ended: guests leave their seats and pending requests and invitations expire. Locked seats
 * and moderators stay (they are not shown for an ended room). Returns the rooms that changed.
 */
export async function clearEndedRoomSeatsIn(
  tx: Prisma.TransactionClient,
  roomIds: readonly string[],
  now: Date,
): Promise<string[]> {
  if (roomIds.length === 0) return [];
  const ids = [...new Set(roomIds)];
  const changed = await tx.$queryRaw<{ room_id: string }[]>`
    WITH seats AS (
      DELETE FROM live_room_seats WHERE room_id = ANY(${ids}::uuid[]) AND user_id IS NOT NULL
      RETURNING room_id
    ), requests AS (
      UPDATE live_seat_requests SET status = 'EXPIRED', handled_at = ${now.toISOString()}::timestamptz
       WHERE room_id = ANY(${ids}::uuid[]) AND status = 'PENDING'
      RETURNING room_id
    ), invites AS (
      UPDATE live_seat_invites SET status = 'EXPIRED', handled_at = ${now.toISOString()}::timestamptz
       WHERE room_id = ANY(${ids}::uuid[]) AND status = 'PENDING'
      RETURNING room_id
    )
    SELECT DISTINCT room_id::text AS room_id
      FROM (SELECT room_id FROM seats UNION ALL SELECT room_id FROM requests
            UNION ALL SELECT room_id FROM invites) changed`;
  const rooms = changed.map((r) => r.room_id);
  await bumpSeatsVersionIn(tx, rooms);
  return rooms;
}

/** What {@link releaseUserIn} took from a user in one room. */
export interface ReleasedUser {
  readonly roomId: string;
  /** The user was on a seat (their media permission must be withdrawn). */
  readonly wasSeated: boolean;
  /** The new seat version. */
  readonly version: number;
}

/**
 * A user loses their seat, their pending request and invitation, and (with `moderator`) their
 * moderator role, in the LIVE rooms matched by `roomScope` (a condition on `r`, e.g. one room or
 * the rooms of a host), or in every LIVE room when it is omitted (suspension). The rooms are locked
 * first (by id, FOR UPDATE) so this serializes with seat changes. Returns one entry per room that
 * changed (its version increased).
 */
export async function releaseUserIn(
  tx: Prisma.TransactionClient,
  userId: string,
  now: Date,
  options: { roomScope?: Prisma.Sql; moderator?: boolean } = {},
): Promise<ReleasedUser[]> {
  const scope = options.roomScope ?? Prisma.sql`TRUE`;
  const candidates = await tx.$queryRaw<{ id: string }[]>`
    SELECT r.id::text AS id FROM live_rooms r
     WHERE r.status = 'LIVE' AND ${scope}
       AND (EXISTS (SELECT 1 FROM live_room_seats s WHERE s.room_id = r.id AND s.user_id = ${userId}::uuid)
         OR EXISTS (SELECT 1 FROM live_seat_requests q
                     WHERE q.room_id = r.id AND q.user_id = ${userId}::uuid AND q.status = 'PENDING')
         OR EXISTS (SELECT 1 FROM live_seat_invites i
                     WHERE i.room_id = r.id AND i.user_id = ${userId}::uuid AND i.status = 'PENDING')
         OR (${options.moderator === true}::boolean
             AND EXISTS (SELECT 1 FROM live_room_moderators m
                          WHERE m.room_id = r.id AND m.user_id = ${userId}::uuid)))
     ORDER BY r.id
       FOR UPDATE OF r`;
  if (candidates.length === 0) return [];
  const ids = candidates.map((c) => c.id);
  const at = now.toISOString();
  const seats = await tx.$queryRaw<{ room_id: string }[]>`
    DELETE FROM live_room_seats WHERE room_id = ANY(${ids}::uuid[]) AND user_id = ${userId}::uuid
    RETURNING room_id::text AS room_id`;
  await tx.$executeRaw`
    UPDATE live_seat_requests SET status = 'EXPIRED', handled_at = ${at}::timestamptz
     WHERE room_id = ANY(${ids}::uuid[]) AND user_id = ${userId}::uuid AND status = 'PENDING'`;
  await tx.$executeRaw`
    UPDATE live_seat_invites SET status = 'EXPIRED', handled_at = ${at}::timestamptz
     WHERE room_id = ANY(${ids}::uuid[]) AND user_id = ${userId}::uuid AND status = 'PENDING'`;
  if (options.moderator === true) {
    await tx.$executeRaw`
      DELETE FROM live_room_moderators WHERE room_id = ANY(${ids}::uuid[]) AND user_id = ${userId}::uuid`;
  }
  const versions = await bumpSeatsVersionIn(tx, ids);
  const seated = new Set(seats.map((s) => s.room_id));
  return ids.map((roomId) => ({
    roomId,
    wasSeated: seated.has(roomId),
    version: versions.get(roomId) ?? 0,
  }));
}
