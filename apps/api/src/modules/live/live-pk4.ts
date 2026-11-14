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
        FROM pk4_supporters WHERE match_id = ${matchId}::uuid AND seat = 0 AND points > 0) t
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
    const seats = await topSeatSupportersIn(tx, matchId);
    await tx.$executeRaw`
      UPDATE pk4_matches
         SET status = 'CLOSED', ended_at = ${at}::timestamptz, closed_at = ${at}::timestamptz,
             result_ends_at = ${at}::timestamptz, end_reason = 'ADMIN', winner_team = NULL, loser_cause = NULL,
             admin_reason = ${reason}, pending_notice = true, seq = seq + 1, effective = false,
             top_a = ${JSON.stringify(top.A)}::jsonb, top_b = ${JSON.stringify(top.B)}::jsonb,
             top_seats = ${JSON.stringify(seats)}::jsonb
       WHERE id = ${matchId}::uuid`;
  } else {
    await tx.$executeRaw`
      UPDATE pk4_matches
         SET status = 'CLOSED', closed_at = ${at}::timestamptz, admin_reason = ${reason},
             pending_notice = true, seq = seq + 1
       WHERE id = ${matchId}::uuid`;
  }
  await tx.$executeRaw`UPDATE pk4_seats SET active = false WHERE match_id = ${matchId}::uuid`;
  // v1.119-live (D395): an open dare ends with the match (CANCELLED, ADMIN: no points either way).
  await tx.$executeRaw`
    UPDATE pk4_match_dares SET status = 'CANCELLED', cause = 'ADMIN', finished_at = ${at}::timestamptz
     WHERE match_id = ${matchId}::uuid AND finished_at IS NULL`;
  await tx.$executeRaw`
    UPDATE pk4_matches SET rematch_by_room_id = NULL, rematch_expires_at = NULL, rematch_accepted = ARRAY[]::uuid[]
     WHERE id = ${matchId}::uuid`;
  return row.status as 'CONNECTED' | 'BATTLE' | 'RESULT';
}

// ---- v1.119-live (D395, CONVENTIONS §10.181, CP-041 phases 3–4) ---------------------------------------------------

/** The role a place stands for in the lobby (FREE_FOR_ALL: every invited place is a PLAYER). */
export function roleOfSeatIn(
  format: Pk4FormatName,
  seat: number,
): 'ORGANISER' | 'TEAMMATE' | 'OPPONENT' | 'PLAYER' {
  if (seat === 1) return 'ORGANISER';
  return format === 'FREE_FOR_ALL' ? 'PLAYER' : roleOfSeat(seat);
}

/**
 * v1.119-live (D395, owner «أ»): the places of the hosts who start a match — two, three or four (the lobby's places, a
 * random group's or the present hosts of a rematch), in their order. The match's place decides the side of the screen
 * (`teamOfSeat`: 1–2 the start side, 3–4 the end side):
 * - TEAMS keeps each host's place (the teams stay as invited), except when the two hosts present are on one team (the
 *   organiser and the teammate only): then they play «like a 1 v 1» — the first at 1, the second at 3.
 * - FREE_FOR_ALL packs the hosts: two → 1 and 3 (half the screen each), three → 1, 2 and 3 (two stacked on the start
 *   side, the third alone on the end side, a tile the size of two), four → 1–4 (the 2 × 2 grid).
 * Returns old place → new place. Fewer than two or more than four hosts → an error (a bug in the caller).
 */
export function pk4SeatPlan(format: Pk4FormatName, seats: readonly number[]): Map<number, number> {
  const sorted = [...seats].sort((a, b) => a - b);
  if (sorted.length < 2 || sorted.length > 4 || new Set(sorted).size !== sorted.length) {
    throw new Error(`a 4-way match needs two to four distinct places, got ${sorted.join(',')}`);
  }
  if (format === 'FREE_FOR_ALL') {
    const packed = sorted.length === 2 ? [1, 3] : sorted.length === 3 ? [1, 2, 3] : [1, 2, 3, 4];
    return new Map(sorted.map((s, i) => [s, packed[i]!]));
  }
  const teams = new Set(sorted.map(teamOfSeat));
  if (teams.size === 1) return new Map(sorted.map((s, i) => [s, i === 0 ? 1 : 3]));
  return new Map(sorted.map((s) => [s, s]));
}

/** One place of a FREE_FOR_ALL match as the ranking needs it. */
export interface Pk4FfaSeat {
  readonly seat: number;
  readonly score: bigint;
  /** When the host left the battle (null: still on air). */
  readonly outAt: Date | null;
}

/** Competition ranking of `items` by `score` descending from `first` (equal scores share a place: 1, 1, 3). */
function rankFrom<T extends { score: bigint }>(items: readonly T[], first: number): Map<T, number> {
  const sorted = [...items].sort((a, b) => (a.score === b.score ? 0 : a.score > b.score ? -1 : 1));
  const out = new Map<T, number>();
  sorted.forEach((item, i) => {
    const prev = sorted[i - 1];
    out.set(item, prev !== undefined && prev.score === item.score ? out.get(prev)! : first + i);
  });
  return out;
}

/**
 * v1.119-live (D395, CP-041 §2 and §4) the places of a FREE_FOR_ALL match: the hosts still on air by score (equal
 * scores share a place), then the hosts who left — each took the last free place when they left (the first to leave
 * the last place, 4th then 3rd …); hosts who left at the same moment are ordered between them by score. Returns
 * place → place number.
 */
export function ffaPlaces(seats: readonly Pk4FfaSeat[]): Map<number, number> {
  const places = new Map<number, number>();
  const onAir = seats.filter((s) => s.outAt === null);
  for (const [s, p] of rankFrom(onAir, 1)) places.set(s.seat, p);
  // The hosts who left, the latest first (a better place than those who left before them).
  const gone = seats.filter((s) => s.outAt !== null);
  const moments = [...new Set(gone.map((s) => s.outAt!.getTime()))].sort((a, b) => b - a);
  let next = onAir.length + 1;
  for (const t of moments) {
    const group = gone.filter((s) => s.outAt!.getTime() === t);
    for (const [s, p] of rankFrom(group, next)) places.set(s.seat, p);
    next += group.length;
  }
  return places;
}

/** A host's result from FREE_FOR_ALL places: 1st alone → WIN; 1st shared → DRAW; any other place → LOSS. */
export function ffaResult(place: number, places: readonly number[]): 'WIN' | 'LOSS' | 'DRAW' {
  if (place !== 1) return 'LOSS';
  return places.filter((p) => p === 1).length > 1 ? 'DRAW' : 'WIN';
}

/**
 * v1.119-live (D395, CP-041 §4) what the outs do to a FREE_FOR_ALL battle: one host still on air → the battle ends at
 * once (that host is 1st); nobody on air → everyone gone (a draw, void for the records); otherwise it goes on.
 */
export function ffaOutcome(
  seats: readonly { seat: number; out: Pk4SeatPresence['out'] }[],
  lastOut: PkEndReasonName,
): { kind: 'continue' } | { kind: 'end'; reason: PkEndReasonName; everyoneGone: boolean } {
  const onAir = seats.filter((s) => s.out === null).length;
  if (onAir === 0) return { kind: 'end', reason: lastOut, everyoneGone: true };
  if (onAir === 1) return { kind: 'end', reason: lastOut, everyoneGone: false };
  return { kind: 'continue' };
}

/** One place at the end of a 4-way battle, for the dare's sides. */
export interface Pk4DareSeat {
  readonly seat: number;
  readonly team: PkSideName;
  readonly hostId: string;
  /** FREE_FOR_ALL's place (null in TEAMS). */
  readonly place: number | null;
  readonly out: boolean;
}

/**
 * v1.119-live (D395, CP-041 §7 «PK أحكام» for four): who does the dare and who judges it, or null (no dare).
 * - TEAMS: the losing team's hosts do it together, the winning team judges; a draw → no dare.
 * - FREE_FOR_ALL: the 1st place judges (shared → each of them); the lowest place still on air does it (shared → each of
 *   them; owner «ان كان حكم ينفذ الثالث الحكم»: the 4th left, so the 3rd does it). Everyone 1st (a draw), or no host
 *   but the winners still on air → no dare.
 * With two or three hosts the same rules hold on the hosts present.
 */
export function pk4DareSides(
  format: Pk4FormatName,
  seats: readonly Pk4DareSeat[],
  winnerTeam: PkSideName | null,
): { losers: Pk4DareSeat[]; winners: Pk4DareSeat[] } | null {
  if (format === 'TEAMS') {
    if (winnerTeam === null) return null;
    const winners = seats.filter((s) => s.team === winnerTeam);
    const losers = seats.filter((s) => s.team !== winnerTeam);
    return winners.length > 0 && losers.length > 0 ? { losers, winners } : null;
  }
  if (seats.some((s) => s.place === null)) return null;
  const winners = seats.filter((s) => s.place === 1);
  const candidates = seats.filter((s) => s.place !== 1 && !s.out);
  if (winners.length === 0 || candidates.length === 0) return null;
  const lowest = Math.max(...candidates.map((s) => s.place!));
  return { losers: candidates.filter((s) => s.place === lowest), winners };
}

/**
 * v1.119-live (D395, CP-041 §3.2) the 4-way random matching: from the waiters in queue order (the longest wait first),
 * the caller and the first three who can play with the caller and with each other (`fits`: no block either way, both
 * hosts' gender / region preferences) — greedily, so the longest waits are preferred. Null when four cannot be made.
 */
export function pickPk4Group<T>(caller: T, waiters: readonly T[], fits: (a: T, b: T) => boolean): T[] | null {
  const group: T[] = [caller];
  for (const w of waiters) {
    if (group.length === 4) break;
    if (group.every((g) => fits(g, w))) group.push(w);
  }
  return group.length === 4 ? group : null;
}

/** Fisher–Yates with a random integer source (crypto in the service; fixed in tests). */
export function shuffled<T>(items: readonly T[], randomInt: (max: number) => number): T[] {
  const out = [...items];
  for (let i = out.length - 1; i > 0; i -= 1) {
    const j = randomInt(i + 1);
    [out[i], out[j]] = [out[j]!, out[i]!];
  }
  return out;
}

/** The supporters frozen when a FREE_FOR_ALL battle ends: `{seat: [{userId, points}]}` (top three per host). */
export async function topSeatSupportersIn(
  tx: Prisma.TransactionClient,
  matchId: string,
): Promise<Record<string, { userId: string; points: number }[]>> {
  const rows = await tx.$queryRaw<{ seat: number; user_id: string; points: bigint }[]>`
    SELECT seat, user_id::text AS user_id, points FROM (
      SELECT seat, user_id, points,
             row_number() OVER (PARTITION BY seat ORDER BY points DESC, user_id) AS rn
        FROM pk4_supporters WHERE match_id = ${matchId}::uuid AND seat > 0 AND points > 0) t
     WHERE rn <= 3 ORDER BY seat, points DESC, user_id`;
  const top: Record<string, { userId: string; points: number }[]> = {};
  for (const r of rows) (top[String(r.seat)] ??= []).push({ userId: r.user_id, points: Number(r.points) });
  return top;
}
