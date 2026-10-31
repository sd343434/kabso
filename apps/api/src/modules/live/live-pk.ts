import type { Prisma } from '../../generated/prisma/client.js';
import type { PkBoosterKindName, PkBoosterRule } from '../../config/app-config.js';

/**
 * v1.43-live (D195, CONVENTIONS §10.58, CP-038): the PK 1 v 1 rules that need no database — the
 * booster checks, the outcome, absence, the media identity of a viewer watching the other room — and
 * the moderator's end (shared with the `pk-admin` CLI, so no Nest dependencies here). PK points are
 * never money: nothing here touches a wallet, cherries, a live score, a ranking or a level.
 */

/** The data-message topic of PK (both rooms of a match). */
export const PK_TOPIC = 'pk';

/** A side of a match: A is the inviter (or the host who waited longest in the random queue). */
export type PkSideName = 'A' | 'B';

export type PkEndReasonName = 'TIME' | 'FORFEIT' | 'DISCONNECT' | 'AWAY' | 'ADMIN';

/** Why a booster gift is refused (the `issue` of the 409 PK_BOOSTER_UNAVAILABLE detail). */
export type PkBoosterProblem = 'no_match' | 'too_early' | 'limit_reached' | 'active_higher';

/** The rule of one booster (config order DOUBLE, DOUBLE_TURBO, TRIPLE, TRIPLE_TURBO). */
export function boosterRule(rules: readonly PkBoosterRule[], kind: PkBoosterKindName): PkBoosterRule {
  const rule = rules.find((r) => r.kind === kind);
  if (!rule) throw new Error(`No PK booster rule for ${kind}`);
  return rule;
}

/**
 * Whether a booster may start now on a side (owner defaults, D195): only during the battle; Triple
 * and Triple Turbo only in its last 60 s, Double Turbo in the last 2 min, Double any time
 * (`lastSeconds` 0); at most `limitPerMatch` uses per side; one active booster per side, which a new
 * one replaces only when it is **higher** (an equal or lower one is refused). Null: allowed.
 */
export function boosterProblem(input: {
  readonly rule: PkBoosterRule;
  /** Milliseconds of battle left (≤ 0: over). */
  readonly remainingMs: number;
  /** This side's uses of this booster in the match so far. */
  readonly used: number;
  /** The multiplier active on this side now (1: none). */
  readonly activeMultiplier: number;
}): PkBoosterProblem | null {
  if (input.remainingMs <= 0) return 'no_match';
  if (input.rule.lastSeconds > 0 && input.remainingMs > input.rule.lastSeconds * 1000) return 'too_early';
  if (input.used >= input.rule.limitPerMatch) return 'limit_reached';
  if (input.activeMultiplier >= input.rule.multiplier) return 'active_higher';
  return null;
}

/**
 * The PK points of one send: its real coin value × the side's active multiplier. A booster's own
 * activation gift counts at ×1 (its coin value as normal points; its multiplier starts after it).
 */
export function pkPoints(coins: bigint, multiplier: number): bigint {
  return coins * BigInt(multiplier);
}

/** The winner of a battle that ran its time: the higher score, or null for a draw. */
export function winnerByScore(scoreA: bigint, scoreB: bigint): PkSideName | null {
  if (scoreA === scoreB) return null;
  return scoreA > scoreB ? 'A' : 'B';
}

/** What the PK tick knows about one side's host and room. */
export interface PkSidePresence {
  readonly roomStatus: 'LIVE' | 'ENDED';
  readonly roomEndReason: string | null;
  readonly lastHeartbeatAt: Date;
  /** D170: the video host's app in the background (camera off) since. */
  readonly hostAwaySince: Date | null;
  /** Out of the media session since (the media server's webhook). */
  readonly leftAt: Date | null;
}

/**
 * Why a side has lost the battle by not being there, or null. Ending the live is a forfeit; a
 * stale heartbeat, a media session left (or any other end of the room) for `graceSeconds` is a
 * disconnect; the host away (D170) for `graceSeconds` is AWAY.
 */
export function absenceOf(
  side: PkSidePresence,
  now: Date,
  graceSeconds: number,
): 'FORFEIT' | 'DISCONNECT' | 'AWAY' | null {
  if (side.roomStatus !== 'LIVE') return side.roomEndReason === 'HOST_ENDED' ? 'FORFEIT' : 'DISCONNECT';
  const limit = now.getTime() - graceSeconds * 1000;
  if (side.lastHeartbeatAt.getTime() <= limit) return 'DISCONNECT';
  if (side.leftAt !== null && side.leftAt.getTime() <= limit) return 'DISCONNECT';
  if (side.hostAwaySince !== null && side.hostAwaySince.getTime() <= limit) return 'AWAY';
  return null;
}

/** `pk:<matchId>:<identity>` — a viewer (or the host) of one room watching the other room's host. */
export const PK_IDENTITY_PREFIX = 'pk:';

export function pkIdentity(matchId: string, identity: string): string {
  return `${PK_IDENTITY_PREFIX}${matchId}:${identity}`;
}

/** The match id of a `pk:<matchId>:<identity>` media identity, else null. */
export function pkMatchOfIdentity(identity: string): string | null {
  if (!identity.startsWith(PK_IDENTITY_PREFIX)) return null;
  const rest = identity.slice(PK_IDENTITY_PREFIX.length);
  const cut = rest.indexOf(':');
  if (cut !== 36) return null;
  const id = rest.slice(0, cut).toLowerCase();
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(id) && rest.length > 37
    ? id
    : null;
}

/** The supporters frozen when a battle ends: `[{userId, points}]` per side (top three). */
export async function topSupportersIn(
  tx: Prisma.TransactionClient,
  matchId: string,
): Promise<{ A: { userId: string; points: number }[]; B: { userId: string; points: number }[] }> {
  const rows = await tx.$queryRaw<{ side: PkSideName; user_id: string; points: bigint }[]>`
    SELECT side::text AS side, user_id::text AS user_id, points FROM (
      SELECT side, user_id, points,
             row_number() OVER (PARTITION BY side ORDER BY points DESC, user_id) AS rn
        FROM pk_supporters WHERE match_id = ${matchId}::uuid AND points > 0) t
     WHERE rn <= 3 ORDER BY side, points DESC, user_id`;
  const top = {
    A: [] as { userId: string; points: number }[],
    B: [] as { userId: string; points: number }[],
  };
  for (const r of rows) top[r.side].push({ userId: r.user_id, points: Number(r.points) });
  return top;
}

/**
 * A moderator ends a match (`pk-admin end <matchId> --reason <text>`, audited `live.pk.admin_end`): a
 * running battle becomes void (`ADMIN`, no winner, not counted in any record) and is CLOSED at once;
 * a match already in its result phase is CLOSED (its result stands). The CLI cannot reach the media
 * server, so `pending_notice` makes the API's PK tick tell both rooms. Returns the previous status,
 * or null when there is no such match or it was already CLOSED.
 */
export async function adminEndPkIn(
  tx: Prisma.TransactionClient,
  matchId: string,
  reason: string,
  now: Date,
): Promise<'BATTLE' | 'RESULT' | null> {
  const [row] = await tx.$queryRaw<{ status: string }[]>`
    SELECT status::text AS status FROM pk_matches WHERE id = ${matchId}::uuid FOR UPDATE`;
  if (!row || row.status === 'CLOSED') return null;
  const at = now.toISOString();
  if (row.status === 'BATTLE') {
    const top = await topSupportersIn(tx, matchId);
    await tx.$executeRaw`
      UPDATE pk_matches
         SET status = 'CLOSED', ended_at = ${at}::timestamptz, closed_at = ${at}::timestamptz,
             result_ends_at = ${at}::timestamptz, end_reason = 'ADMIN', winner = NULL, loser_cause = NULL,
             admin_reason = ${reason}, pending_notice = true, seq = seq + 1,
             top_a = ${JSON.stringify(top.A)}::jsonb, top_b = ${JSON.stringify(top.B)}::jsonb
       WHERE id = ${matchId}::uuid`;
  } else {
    await tx.$executeRaw`
      UPDATE pk_matches
         SET status = 'CLOSED', closed_at = ${at}::timestamptz, admin_reason = ${reason},
             pending_notice = true, seq = seq + 1
       WHERE id = ${matchId}::uuid`;
  }
  return row.status as 'BATTLE' | 'RESULT';
}
