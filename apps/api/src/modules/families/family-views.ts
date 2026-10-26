import type { FamilyRole, Prisma } from '../../generated/prisma/client.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import { isOnline } from '../users/presence.js';

type Db = Prisma.TransactionClient;

/** A family time window (UTC instants). */
export interface FamilyWindow {
  readonly start: Date;
  readonly end: Date;
}

/**
 * The current calendar month (`month`) or week from Monday (`week`) in `timeZone`
 * (LIVE_RANKINGS_TIME_ZONE, the app's one region; §10.15, §10.25).
 */
export async function familyWindow(
  db: Pick<Db, '$queryRaw'>,
  unit: 'month' | 'week',
  timeZone: string,
  now: Date,
): Promise<FamilyWindow> {
  const [w] = await db.$queryRaw<{ start: Date; end: Date }[]>`
    SELECT (date_trunc(${unit}::text, ${now}::timestamptz AT TIME ZONE ${timeZone}::text)
              AT TIME ZONE ${timeZone}::text) AS start,
           ((date_trunc(${unit}::text, ${now}::timestamptz AT TIME ZONE ${timeZone}::text)
              + ${'1 ' + unit}::interval) AT TIME ZONE ${timeZone}::text) AS "end"`;
  return { start: w!.start, end: w!.end };
}

/** `FamilyPresence`: shown only as §10.25 allows (else the member's `presence` is null). */
export interface FamilyPresenceDto {
  online: boolean;
  lastActiveAt: string | null;
}

/** `FamilyMember` (v1.25-live adds `monthPoints`, `presence`, `chatMuted` and, by points, `rank`). */
export interface FamilyMemberDto {
  user: UserSummaryDto;
  role: FamilyRole;
  joinedAt: string;
  /** Family points this member gave while in the family. */
  points: number;
  /** v1.25-live: of those, the ones given in the current month (LIVE_RANKINGS_TIME_ZONE). */
  monthPoints: number;
  /** v1.25-live: online now / last active, or null when the caller may not see it (§10.25). */
  presence: FamilyPresenceDto | null;
  /** v1.25-live: muted in the family chat; null unless the caller is the leader or a deputy. */
  chatMuted: boolean | null;
  /** v1.25-live: the place by points in the whole family (only with `sort=POINTS`). */
  rank?: number;
}

/**
 * The points each of `userIds` gave `familyId` in `month` during their current membership (like
 * `FamilyMember.points`: what they gave before leaving and joining again is not counted).
 */
export async function monthPointsOf(
  db: Pick<Db, '$queryRaw'>,
  familyId: string,
  userIds: readonly string[],
  month: FamilyWindow,
): Promise<Map<string, number>> {
  if (userIds.length === 0) return new Map();
  const rows = await db.$queryRaw<{ user_id: string; points: bigint }[]>`
    SELECT l.user_id::text AS user_id, SUM(l.points)::bigint AS points
      FROM family_points_ledger l
      JOIN family_members m ON m.user_id = l.user_id AND m.family_id = l.family_id
     WHERE l.family_id = ${familyId}::uuid
       AND l.user_id = ANY(${[...userIds]}::uuid[])
       AND l.created_at >= GREATEST(${month.start}::timestamptz, m.joined_at)
       AND l.created_at < ${month.end}::timestamptz
     GROUP BY l.user_id`;
  return new Map(rows.map((r) => [r.user_id, Number(r.points)]));
}

/** One membership row to present. */
export interface MemberRow {
  readonly userId: string;
  readonly role: FamilyRole;
  readonly joinedAt: Date;
  readonly points: bigint | number;
  readonly rank?: number;
}

/**
 * Builds `FamilyMember` bodies for `callerId` (rows of one family, in order). Presence is shown
 * when the caller is a member of the same family, the person did not turn off
 * `showActivityStatus` and there is no block either way (the caller always sees their own).
 */
export async function memberViews(
  db: Db,
  input: {
    readonly familyId: string;
    readonly callerId: string;
    readonly now: Date;
    readonly month: FamilyWindow;
    readonly rows: readonly MemberRow[];
  },
): Promise<FamilyMemberDto[]> {
  const { familyId, callerId, now, month, rows } = input;
  if (rows.length === 0) return [];
  const ids = rows.map((r) => r.userId);
  const [users, caller, months, blocks, mutes] = await Promise.all([
    db.user.findMany({
      where: { id: { in: ids } },
      select: {
        ...USER_SUMMARY_SELECT,
        lastActiveAt: true,
        privacySettings: { select: { showActivityStatus: true } },
      },
    }),
    db.familyMember.findUnique({ where: { userId: callerId }, select: { familyId: true, role: true } }),
    monthPointsOf(db, familyId, ids, month),
    db.userBlock.findMany({
      where: {
        OR: [
          { blockerId: callerId, blockedId: { in: ids } },
          { blockedId: callerId, blockerId: { in: ids } },
        ],
      },
      select: { blockerId: true, blockedId: true },
    }),
    db.familyChatMute.findMany({ where: { familyId, userId: { in: ids } }, select: { userId: true } }),
  ]);
  const byId = new Map(users.map((u) => [u.id, u]));
  const sameFamily = caller?.familyId === familyId;
  const moderator = sameFamily && (caller.role === 'LEADER' || caller.role === 'DEPUTY');
  const blocked = new Set(blocks.map((b) => (b.blockerId === callerId ? b.blockedId : b.blockerId)));
  const muted = new Set(mutes.map((m) => m.userId));
  const monthly = months;
  const out: FamilyMemberDto[] = [];
  for (const row of rows) {
    const user = byId.get(row.userId);
    if (!user) continue;
    const visible =
      row.userId === callerId ||
      (sameFamily && (user.privacySettings?.showActivityStatus ?? true) && !blocked.has(row.userId));
    const lastActive = row.userId === callerId ? (user.lastActiveAt ?? now) : user.lastActiveAt;
    const dto: FamilyMemberDto = {
      user: userSummary(user),
      role: row.role,
      joinedAt: row.joinedAt.toISOString(),
      points: Number(row.points),
      monthPoints: monthly.get(row.userId) ?? 0,
      presence: visible
        ? { online: isOnline(lastActive, now), lastActiveAt: lastActive?.toISOString() ?? null }
        : null,
      chatMuted: moderator ? muted.has(row.userId) : null,
    };
    if (row.rank !== undefined) dto.rank = row.rank;
    out.push(dto);
  }
  return out;
}
