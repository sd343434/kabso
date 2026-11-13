import { AuditAction } from '../../common/audit/audit.service.js';
import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import { LIMITED_STAFF_ROLES } from '../live/live-staff.js';
import {
  changeOf,
  DEFAULT_THRESHOLDS,
  pickBadge,
  windowStart,
  type BadgeChange,
  type VerificationBadgeValue,
  type VerificationThresholds,
} from './verification-rules.js';

/**
 * v1.90-social (D293, CONVENTIONS §10.105): the only writer of `user_verification_badges` — the sweeper (every
 * `VERIFICATION_BADGE_SWEEP_INTERVAL_SECONDS`), the CLI `verification-admin recompute` (the first-run backfill), a
 * settings change, and the immediate recomputes where they are cheap (a panel role granted or revoked, a creator
 * activated, an identity check decided). No Nest dependencies: shared by the API, the CLI and the tests.
 *
 * Every condition is read from the data as it is NOW, in the caller's transaction (so a role grant sees itself):
 *
 *  - OWNER / STAFF: an ACTIVE `users.role = ADMIN` account holding OWNER / a limited staff role (D283, `live-staff`);
 *    D357: OWNER is still read here but only to SUPPRESS — `pickBadge` gives the app owner no badge, so a stored
 *    OWNER (or a STAFF he also holds) is removed at his next recompute;
 *  - RECHARGE_AGENT: an ACTIVE recharge agent (`recharge_agents.status`, the `rechargeAgent` tag's rule) whose coins
 *    sold in the window — direct sales (`recharge_sales`, the agent's and the employees' sales) plus the coin orders
 *    closed COMPLETED / COMPLETED_BY_ADMIN (`recharge_orders.closed_at`, whoever of the agent's side owned them) — are
 *    more than the threshold, AND whose cherries bought from hosts in the window (`recharge_cherry_requests`
 *    CONFIRMED, `decided_at`, the agent's or an employee's) are more than theirs;
 *  - HOST_AGENT: the owner of an OPEN agency the team has not suspended, with a host code (the `hostAgent` tag's
 *    rule), whose ACTIVE hosts with an ACTIVE account are more than the threshold now, and whose hosts' cherries in
 *    the window (`agency_earnings.host_cherries` not reversed: every gift a linked host received, the ledger behind
 *    the agency's month totals) are more than theirs;
 *  - CREATOR: a `creator_members` row (D285; the membership has no end today);
 *  - VERIFIED_HOST: never a creator member (D295: a person is never both); a host — a hosting permission (`live_hosts`,
 *    any source but D295's `CREATOR`, which only comes
 *    with the creator membership: the team, an agency, «كن مضيفاً مع
 *    الإدارة») or an ACTIVE agency link — whose identity was approved: an APPROVED Didit check (`kyc_checks`:
 *    document, passive liveness and face match, any purpose), or (owner 2026-11-06: «نعم») an APPROVED «كن مضيفاً مع
 *    الإدارة» application (`host_applications`, D209) — the team's manual review of the ID card and the selfie while
 *    Didit is off (with Didit on, that approval itself needs an approved check).
 *
 * Every badge needs an ACTIVE account (a ban, a lock to SUSPENDED or a deletion removes it at the next recompute).
 * Sums are BIGINT/NUMERIC in PostgreSQL and compared there: exact, whatever their size.
 */

type Db = Pick<PrismaClient | Prisma.TransactionClient, '$queryRaw' | '$executeRaw'>;
type Tx = Prisma.TransactionClient;

/** Why a recompute ran (the audit rows' `cause`). */
export type RecomputeCause = 'sweep' | 'backfill' | 'settings' | 'role' | 'creator' | 'kyc' | 'host';

export interface RecomputeResult {
  readonly granted: number;
  readonly changed: number;
  readonly removed: number;
  readonly kept: number;
}

const LOCK_KEY = 'kabso:verification-badges';

export async function thresholdsIn(
  db: Pick<PrismaClient | Prisma.TransactionClient, 'verificationBadgeSettings'>,
): Promise<VerificationThresholds> {
  const row = await db.verificationBadgeSettings.findUnique({ where: { id: 1 } });
  if (!row) return DEFAULT_THRESHOLDS;
  return {
    rechargeMinSalesCoins: row.rechargeMinSalesCoins,
    rechargeMinCherries: row.rechargeMinCherries,
    hostAgentMinHosts: row.hostAgentMinHosts,
    hostAgentMinCherries: row.hostAgentMinCherries,
  };
}

function only(column: string, userIds: readonly string[] | null): Prisma.Sql {
  return userIds === null
    ? Prisma.empty
    : Prisma.sql`AND ${Prisma.raw(column)} = ANY(${[...userIds]}::uuid[])`;
}

/** Every badge each person qualifies for now (all people when `userIds` is null). */
export async function qualifyingIn(
  db: Db,
  now: Date,
  t: VerificationThresholds,
  userIds: readonly string[] | null,
): Promise<Map<string, Set<VerificationBadgeValue>>> {
  const out = new Map<string, Set<VerificationBadgeValue>>();
  if (userIds !== null && userIds.length === 0) return out;
  const from = windowStart(now);
  const staffRoles = Prisma.join(LIMITED_STAFF_ROLES.map((r) => Prisma.sql`${r}::admin_permission`));
  const rows = await db.$queryRaw<{ user_id: string; badge: VerificationBadgeValue }[]>`
    SELECT DISTINCT u.id::text AS user_id, 'OWNER' AS badge
      FROM users u JOIN user_admin_permissions p ON p.user_id = u.id
     WHERE u.role = 'ADMIN'::user_role AND u.status = 'ACTIVE'::user_status
       AND p.permission = 'OWNER'::admin_permission ${only('u.id', userIds)}
    UNION ALL
    SELECT DISTINCT u.id::text, 'STAFF'
      FROM users u JOIN user_admin_permissions p ON p.user_id = u.id
     WHERE u.role = 'ADMIN'::user_role AND u.status = 'ACTIVE'::user_status
       AND p.permission IN (${staffRoles}) ${only('u.id', userIds)}
    UNION ALL
    SELECT ra.user_id::text, 'RECHARGE_AGENT'
      FROM recharge_agents ra JOIN users u ON u.id = ra.user_id
     WHERE ra.status = 'ACTIVE'::recharge_agent_status AND u.status = 'ACTIVE'::user_status
       ${only('ra.user_id', userIds)}
       AND COALESCE((SELECT sum(s.coins) FROM recharge_sales s
                      WHERE s.agent_user_id = ra.user_id AND s.created_at >= ${from} AND s.created_at <= ${now}), 0)
         + COALESCE((SELECT sum(o.coins) FROM recharge_orders o
                      WHERE o.agent_user_id = ra.user_id
                        AND o.status IN ('COMPLETED'::recharge_order_status, 'COMPLETED_BY_ADMIN'::recharge_order_status)
                        AND o.closed_at >= ${from} AND o.closed_at <= ${now}), 0)
           > ${t.rechargeMinSalesCoins}::numeric
       AND COALESCE((SELECT sum(c.cherries) FROM recharge_cherry_requests c
                      WHERE c.agent_user_id = ra.user_id AND c.status = 'CONFIRMED'::recharge_cherry_request_status
                        AND c.decided_at >= ${from} AND c.decided_at <= ${now}), 0)
           > ${t.rechargeMinCherries}::numeric
    UNION ALL
    SELECT a.owner_user_id::text, 'HOST_AGENT'
      FROM agencies a JOIN users u ON u.id = a.owner_user_id
     WHERE a.status = 'OPEN'::agency_status AND a.suspended_at IS NULL AND a.host_code IS NOT NULL
       AND u.status = 'ACTIVE'::user_status ${only('a.owner_user_id', userIds)}
       AND (SELECT count(*) FROM agency_hosts ah JOIN users hu ON hu.id = ah.host_user_id
             WHERE ah.agency_id = a.id AND ah.status = 'ACTIVE'::agency_host_status
               AND hu.status = 'ACTIVE'::user_status) > ${t.hostAgentMinHosts}
       AND COALESCE((SELECT sum(e.host_cherries) FROM agency_earnings e
                      WHERE e.agency_id = a.id AND e.reversed_at IS NULL
                        AND e.created_at >= ${from} AND e.created_at <= ${now}), 0)
           > ${t.hostAgentMinCherries}::numeric
    UNION ALL
    SELECT cm.user_id::text, 'CREATOR'
      FROM creator_members cm JOIN users u ON u.id = cm.user_id
     WHERE u.status = 'ACTIVE'::user_status ${only('cm.user_id', userIds)}
    UNION ALL
    SELECT u.id::text, 'VERIFIED_HOST'
      FROM users u
     WHERE u.status = 'ACTIVE'::user_status ${only('u.id', userIds)}
       -- D295 (owner: never both a host and a creator): a creator member never qualifies for blue, whatever the path.
       AND NOT EXISTS (SELECT 1 FROM creator_members cm WHERE cm.user_id = u.id)
       AND u.id IN (SELECT k.user_id FROM kyc_checks k WHERE k.status = 'APPROVED'::kyc_status
                    UNION
                    SELECT h.user_id FROM host_applications h WHERE h.status = 'APPROVED'::host_application_status)
       AND (EXISTS (SELECT 1 FROM live_hosts lh
                     WHERE lh.user_id = u.id AND lh.source <> 'CREATOR'::live_host_source)
            OR EXISTS (SELECT 1 FROM agency_hosts ah
                        WHERE ah.host_user_id = u.id AND ah.status = 'ACTIVE'::agency_host_status))`;
  for (const r of rows) {
    const set = out.get(r.user_id) ?? new Set<VerificationBadgeValue>();
    set.add(r.badge);
    out.set(r.user_id, set);
  }
  return out;
}

/**
 * Recomputes the badges of `userIds` (everyone when null) and writes the differences in the caller's transaction:
 * a new badge (`since` = now), a changed one (`since` = now), a removed one (the row goes), and `computedAt` = now on
 * every badge kept. Each difference is audited `verification.badge.change` (system; target the user;
 * `{before, after, change, cause}`) — never an amount. One recompute at a time (an advisory transaction lock).
 */
export async function recomputeBadgesIn(
  tx: Tx,
  userIds: readonly string[] | null,
  cause: RecomputeCause,
  now: Date = new Date(),
): Promise<RecomputeResult> {
  const ids = userIds === null ? null : [...new Set(userIds)];
  if (ids !== null && ids.length === 0) return { granted: 0, changed: 0, removed: 0, kept: 0 };
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${LOCK_KEY}))`;
  const thresholds = await thresholdsIn(tx);
  const qualifying = await qualifyingIn(tx, now, thresholds, ids);
  const existing = await tx.userVerificationBadge.findMany({
    where: ids === null ? {} : { userId: { in: ids } },
    select: { userId: true, badge: true },
  });
  const before = new Map(existing.map((r) => [r.userId, r.badge]));
  const people = ids ?? [...new Set([...before.keys(), ...qualifying.keys()])];

  const inserts: { userId: string; badge: VerificationBadgeValue }[] = [];
  const updates: { userId: string; badge: VerificationBadgeValue }[] = [];
  const removes: string[] = [];
  const kept: string[] = [];
  const audits: { userId: string; before: string | null; after: string | null; change: BadgeChange }[] = [];
  for (const userId of people.sort()) {
    const was = before.get(userId) ?? null;
    const next = pickBadge(qualifying.get(userId) ?? []);
    const change = changeOf(was, next);
    if (change === null) {
      if (next !== null) kept.push(userId);
      continue;
    }
    audits.push({ userId, before: was, after: next, change });
    if (change === 'granted') inserts.push({ userId, badge: next! });
    else if (change === 'changed') updates.push({ userId, badge: next! });
    else removes.push(userId);
  }

  if (removes.length > 0) await tx.userVerificationBadge.deleteMany({ where: { userId: { in: removes } } });
  if (inserts.length > 0) {
    await tx.userVerificationBadge.createMany({
      data: inserts.map((r) => ({ userId: r.userId, badge: r.badge, since: now, computedAt: now })),
    });
  }
  for (const r of updates) {
    await tx.userVerificationBadge.update({
      where: { userId: r.userId },
      data: { badge: r.badge, since: now, computedAt: now },
    });
  }
  if (kept.length > 0) {
    await tx.userVerificationBadge.updateMany({
      where: { userId: { in: kept } },
      data: { computedAt: now },
    });
  }
  if (audits.length > 0) {
    await tx.auditLog.createMany({
      data: audits.map((a) => ({
        action: AuditAction.VERIFICATION_BADGE_CHANGE,
        targetType: 'user',
        targetId: a.userId,
        metadata: { before: a.before, after: a.after, change: a.change, cause },
        createdAt: now,
      })),
    });
  }
  if (ids === null) {
    await tx.verificationBadgeSettings.upsert({
      where: { id: 1 },
      create: { id: 1, lastRunAt: now },
      update: { lastRunAt: now },
    });
  }
  return {
    granted: inserts.length,
    changed: updates.length,
    removed: removes.length,
    kept: kept.length,
  };
}

/** A full recompute in its own transaction (the sweeper, the CLI). */
export async function recomputeAllBadges(
  db: Pick<PrismaClient, '$transaction'>,
  cause: Extract<RecomputeCause, 'sweep' | 'backfill' | 'settings'>,
  now: Date = new Date(),
): Promise<RecomputeResult> {
  return db.$transaction((tx) => recomputeBadgesIn(tx, null, cause, now), { timeout: 120_000 });
}

/** The badge a person shows now (the stored one), or null. */
export async function badgeOfIn(
  db: Pick<PrismaClient | Prisma.TransactionClient, 'userVerificationBadge'>,
  userId: string,
): Promise<{ badge: VerificationBadgeValue; since: Date; computedAt: Date } | null> {
  const row = await db.userVerificationBadge.findUnique({ where: { userId } });
  return row ? { badge: row.badge, since: row.since, computedAt: row.computedAt } : null;
}
