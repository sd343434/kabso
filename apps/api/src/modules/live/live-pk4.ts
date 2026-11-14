import { Prisma } from '../../generated/prisma/client.js';
import type { PkEndReasonName, PkSideName } from './live-pk.js';

/**
 * v1.118-live (D391, CONVENTIONS §10.180, CP-041 phase 2) «PK رباعي»: the PK 2 v 2 rules that need no Nest service — the
 * places and teams, what a host out of the battle does to the match, the media identity of a watcher of another room,
 * the SQL of "busy in a 4-way PK" (PK 1 v 1 uses it too) and the moderator's end (shared with the `pk-admin` CLI and the
 * panel). PK points are never money: nothing here touches a wallet, cherries, a live score, a ranking or a level.
 */

/** The four places: 1 the organiser, 2 the teammate (team A), 3 and 4 the opponents (team B). */
export const PK4_SEATS = [1, 2, 3, 4] as const;
export type Pk4SeatNumber = (typeof PK4_SEATS)[number];

export type Pk4FormatName = 'TEAMS' | 'FREE_FOR_ALL';

/** The team of a place (A: 1–2, B: 3–4). */
export function teamOfSeat(seat: number): PkSideName {
  return seat <= 2 ? 'A' : 'B';
}

/** The role a place stands for in the lobby. */
export function roleOfSeat(seat: number): 'ORGANISER' | 'TEAMMATE' | 'OPPONENT' {
  if (seat === 1) return 'ORGANISER';
  return seat === 2 ? 'TEAMMATE' : 'OPPONENT';
}

/** What the tick (or a host's End) knows about one place while the battle runs. */
export interface Pk4SeatPresence {
  readonly seat: number;
  readonly team: PkSideName;
  /** Out already, or out now (with the reason). */
  readonly out: 'FORFEIT' | 'DISCONNECT' | 'AWAY' | null;
}

/** What the outs do to a TEAMS battle. */
export type Pk4OutOutcome =
  | { readonly kind: 'continue' }
  | {
      readonly kind: 'end';
      readonly reason: PkEndReasonName;
      /** The winning team, or null: everyone gone (a draw, void for the records). */
      readonly winner: PkSideName | null;
      /** The team whose two hosts are out; null when all four are. */
      readonly loserCause: PkSideName | null;
    };

/**
 * v1.118-live (D391, owner CP-041 §4): a host out keeps their points and the teammate carries on alone. Both hosts of a
 * team out → the other team wins at once (the reason of that team's last out, `lastOut`); all four out → a draw that
 * is void for the records. Otherwise the battle goes on.
 */
export function teamsOutcome(seats: readonly Pk4SeatPresence[], lastOut: PkEndReasonName): Pk4OutOutcome {
  const gone = (team: PkSideName) => seats.filter((s) => s.team === team).every((s) => s.out !== null);
  const goneA = gone('A');
  const goneB = gone('B');
  if (goneA && goneB) return { kind: 'end', reason: lastOut, winner: null, loserCause: null };
  if (goneA) return { kind: 'end', reason: lastOut, winner: 'B', loserCause: 'A' };
  if (goneB) return { kind: 'end', reason: lastOut, winner: 'A', loserCause: 'B' };
  return { kind: 'continue' };
}

/** The winner of a TEAMS battle that ran its time: the higher team sum, or null for a draw. */
export function teamWinnerByScore(scoreA: bigint, scoreB: bigint): PkSideName | null {
  if (scoreA === scoreB) return null;
  return scoreA > scoreB ? 'A' : 'B';
}

/**
 * Whether a finished 4-way match counts in the records: not void (ADMIN, CANCELLED, or everyone gone) and the four
 * hosts' PK points together at least `minPoints` (PK_EFFECTIVE_MIN_POINTS).
 */
export function isEffectivePk4(input: {
  readonly reason: PkEndReasonName;
  readonly everyoneGone: boolean;
  readonly total: bigint;
  readonly minPoints: number;
}): boolean {
  if (input.reason === 'ADMIN' || input.reason === 'CANCELLED' || input.everyoneGone) return false;
  return input.total >= BigInt(input.minPoints);
}

/** `pk4:<matchId>:<identity>` — a viewer (or a host) of one room watching another room of the 4-way match. */
export const PK4_IDENTITY_PREFIX = 'pk4:';

export function pk4Identity(matchId: string, identity: string): string {
  return `${PK4_IDENTITY_PREFIX}${matchId}:${identity}`;
}

/** The match id of a `pk4:<matchId>:<identity>` media identity, else null. */
export function pk4MatchOfIdentity(identity: string): string | null {
  if (!identity.startsWith(PK4_IDENTITY_PREFIX)) return null;
  const rest = identity.slice(PK4_IDENTITY_PREFIX.length);
  const cut = rest.indexOf(':');
  if (cut !== 36) return null;
  const id = rest.slice(0, cut).toLowerCase();
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(id) && rest.length > 37
    ? id
    : null;
}

/**
 * The SQL condition "this room is busy in a 4-way PK" (`room` is a uuid expression, `at` an ISO time): an open place in
 * a match (`pk4_seats.active`), an OPEN lobby it organises, an accepted place in an OPEN lobby, or an open invitation to
 * it. PK 1 v 1 adds it to its own busy checks (a host in either PK is busy for the other).
 */
export function pk4BusySql(room: Prisma.Sql, at: string): Prisma.Sql {
  return Prisma.sql`(EXISTS (SELECT 1 FROM pk4_seats s4 WHERE s4.active AND s4.room_id = ${room})
    OR EXISTS (SELECT 1 FROM pk4_lobbies l4 WHERE l4.status = 'OPEN'::pk4_lobby_status
                  AND l4.organiser_room_id = ${room} AND l4.expires_at > ${at}::timestamptz)
    OR EXISTS (SELECT 1 FROM pk4_invites i4 JOIN pk4_lobbies l4 ON l4.id = i4.lobby_id
                WHERE i4.to_room_id = ${room} AND l4.status = 'OPEN'::pk4_lobby_status
                  AND l4.expires_at > ${at}::timestamptz
                  AND (i4.status = 'ACCEPTED'::pk4_invite_status
                       OR (i4.status = 'PENDING'::pk4_invite_status AND i4.expires_at > ${at}::timestamptz))))`;
}

/** The supporters frozen when a 4-way battle ends: `[{userId, points}]` per team (top three, from both rooms). */
export async function topTeamSupportersIn(
  tx: Prisma.TransactionClient,
  matchId: string,
): Promise<{ A: { userId: string; points: number }[]; B: { userId: string; points: number }[] }> {
  const rows = await tx.$queryRaw<{ team: PkSideName; user_id: string; points: bigint }[]>`
    SELECT team::text AS team, user_id::text AS user_id, points FROM (
      SELECT team, user_id, points,
             row_number() OVER (PARTITION BY team ORDER BY points DESC, user_id) AS rn
        FROM pk4_supporters WHERE match_id = ${matchId}::uuid AND points > 0) t
     WHERE rn <= 3 ORDER BY team, points DESC, user_id`;
  const top = {
    A: [] as { userId: string; points: number }[],
    B: [] as { userId: string; points: number }[],
  };
  for (const r of rows) top[r.team].push({ userId: r.user_id, points: Number(r.points) });
  return top;
}

/**
 * A moderator ends a 4-way match (`pk-admin end <matchId> --reason`, or the panel's `endAdminLivePk4`): a CONNECTED or
 * running battle becomes void (`ADMIN`, no winner, not counted) and is CLOSED at once; a match in its result phase is
 * CLOSED (its result stands). Its places are released. `pending_notice` makes the API's PK tick tell the four rooms
 * (the CLI cannot reach the media server). Returns the previous status, or null when there is no such match or it
 * was already CLOSED. The caller writes the audit row.
 */
export async function adminEndPk4In(
  tx: Prisma.TransactionClient,
  matchId: string,
  reason: string,
  now: Date,
): Promise<'CONNECTED' | 'BATTLE' | 'RESULT' | null> {
  const [row] = await tx.$queryRaw<{ status: string }[]>`
    SELECT status::text AS status FROM pk4_matches WHERE id = ${matchId}::uuid FOR UPDATE`;
  if (!row || row.status === 'CLOSED') return null;
  const at = now.toISOString();
  if (row.status === 'BATTLE' || row.status === 'CONNECTED') {
    const top = await topTeamSupportersIn(tx, matchId);
    await tx.$executeRaw`
      UPDATE pk4_matches
         SET status = 'CLOSED', ended_at = ${at}::timestamptz, closed_at = ${at}::timestamptz,
             result_ends_at = ${at}::timestamptz, end_reason = 'ADMIN', winner_team = NULL, loser_cause = NULL,
             admin_reason = ${reason}, pending_notice = true, seq = seq + 1, effective = false,
             top_a = ${JSON.stringify(top.A)}::jsonb, top_b = ${JSON.stringify(top.B)}::jsonb
       WHERE id = ${matchId}::uuid`;
  } else {
    await tx.$executeRaw`
      UPDATE pk4_matches
         SET status = 'CLOSED', closed_at = ${at}::timestamptz, admin_reason = ${reason},
             pending_notice = true, seq = seq + 1
       WHERE id = ${matchId}::uuid`;
  }
  await tx.$executeRaw`UPDATE pk4_seats SET active = false WHERE match_id = ${matchId}::uuid`;
  return row.status as 'CONNECTED' | 'BATTLE' | 'RESULT';
}
