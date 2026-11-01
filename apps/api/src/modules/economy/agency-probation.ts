import { auditBy, CLI_VIA, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import type { Prisma, PrismaClient } from '../../generated/prisma/client.js';
import { Notifier } from '../notifications/notifier.js';
import { syncAgentUsernameIn } from '../users/agent-usernames.js';
import { SpecialUsernameError } from '../users/special-usernames.js';
import { HostAgentError } from './host-agents.js';

/**
 * «افتح وكالة» — a self-opened agency's probation and the closing / reopening of an agency (v1.70-social, D206,
 * CONVENTIONS §10.65, owner 2026-10-31). Shared by the API (the open endpoint, the reads, the sweeper), the panel and
 * the `economy-admin` CLI (no Nest dependencies).
 *
 * **The one rule (deterministic).** A host counts as *activated* at an instant `at` when one of their links to the
 * agency was a membership at `at` (`activated_at < at`, not ended before `at`) and, in that link's window
 * `[activated_at, at)`, they started at least one live of their own (`live_rooms.started_at`) AND received at least one
 * gift (a `GIFT_RECEIVED` cherry-ledger row that was not reversed). A probation is decided by the state at
 * `min(now, probationEndsAt)`: anything at or after `probationEndsAt` — a join, a live, a gift — does not count, and a
 * sweep that runs late decides exactly as one that ran on time.
 */

type Tx = Prisma.TransactionClient;
type Db = Pick<PrismaClient, '$queryRaw'> | Pick<Tx, '$queryRaw'>;

export interface ProbationRules {
  readonly probationDays: number;
  readonly probationMinHosts: number;
  readonly probationReminderHours: number;
  readonly reopenCooldownDays: number;
}

export const DAY_MS = 86_400_000;
const HOUR_MS = 3_600_000;
const notifier = new Notifier();

/** One host of an agency in its probation, at an instant. */
export interface ProbationHost {
  readonly userId: string;
  readonly joinedAt: Date;
  readonly wentLive: boolean;
  readonly receivedGifts: boolean;
  readonly activated: boolean;
}

/**
 * The hosts that were members of `agencyId` at `at`, each with what they did after joining and before `at` (a host
 * who left and joined again: the best of their links that were memberships at `at`). Newest join first.
 */
export async function probationHostsAt(db: Db, agencyId: string, at: Date): Promise<ProbationHost[]> {
  const rows = await db.$queryRaw<{ user_id: string; joined_at: Date; went_live: boolean; gifts: boolean }[]>`
    SELECT DISTINCT ON (l.host_user_id) l.host_user_id AS user_id, l.joined_at, l.went_live, l.gifts
      FROM (
        SELECT ah.host_user_id::text AS host_user_id, ah.activated_at AS joined_at,
               EXISTS (SELECT 1 FROM live_rooms r
                        WHERE r.host_user_id = ah.host_user_id
                          AND r.started_at >= ah.activated_at AND r.started_at < ${at}) AS went_live,
               EXISTS (SELECT 1 FROM cherry_ledger c
                        WHERE c.user_id = ah.host_user_id AND c.reason = 'GIFT_RECEIVED'::cherry_ledger_reason
                          AND c.delta > 0 AND c.created_at >= ah.activated_at AND c.created_at < ${at}
                          AND NOT EXISTS (
                            SELECT 1 FROM cherry_ledger x
                             WHERE x.user_id = c.user_id AND x.reason = 'GIFT_REVERSAL'::cherry_ledger_reason
                               AND x.reference_id = c.reference_id)) AS gifts
          FROM agency_hosts ah
         WHERE ah.agency_id = ${agencyId}::uuid AND ah.activated_at < ${at}
           AND (ah.ended_at IS NULL OR ah.ended_at >= ${at})
      ) l
     ORDER BY l.host_user_id, (l.went_live AND l.gifts) DESC, l.went_live DESC, l.gifts DESC, l.joined_at DESC`;
  return rows
    .map((r) => ({
      userId: r.user_id,
      joinedAt: r.joined_at,
      wentLive: r.went_live,
      receivedGifts: r.gifts,
      activated: r.went_live && r.gifts,
    }))
    .sort((a, b) => b.joinedAt.getTime() - a.joinedAt.getTime() || (a.userId < b.userId ? -1 : 1));
}

/** The instant a probation is judged at: now, but never after its end. */
export function probationInstant(now: Date, endsAt: Date): Date {
  return now.getTime() < endsAt.getTime() ? now : endsAt;
}

/** When a person whose agency closed at `closedAt` may open one again. */
export function reopenAt(closedAt: Date, rules: Pick<ProbationRules, 'reopenCooldownDays'>): Date {
  return new Date(closedAt.getTime() + rules.reopenCooldownDays * DAY_MS);
}

/** A refused special-username step as a rule refusal (the whole transaction rolls back). */
async function usernameIn(step: () => Promise<unknown>): Promise<void> {
  try {
    await step();
  } catch (err) {
    if (err instanceof SpecialUsernameError) throw new HostAgentError(`Username: ${err.message}`);
    throw err;
  }
}

interface LockedAgency {
  id: string;
  owner: string;
  status: 'OPEN' | 'CLOSED';
  origin: 'ADMIN' | 'SELF';
  ends_at: Date | null;
  passed_at: Date | null;
  reminded_at: Date | null;
}

async function lockAgency(tx: Tx, agencyId: string): Promise<LockedAgency | null> {
  const [a] = await tx.$queryRaw<LockedAgency[]>`
    SELECT id::text AS id, owner_user_id::text AS owner, status::text AS status, origin::text AS origin,
           probation_ends_at AS ends_at, probation_passed_at AS passed_at, probation_reminded_at AS reminded_at
      FROM agencies WHERE id = ${agencyId}::uuid FOR UPDATE`;
  return a ?? null;
}

/**
 * Closes an OPEN agency in the caller's transaction: `CLOSED` with the reason; its ACTIVE hosts are released for free
 * (as if they had left — `RELEASED`, any open complaint resolved) and each is told; the owner is told why (with the
 * probation's count when it failed) and loses the host-agent perks (the username goes back; the code stays theirs).
 * Commissions already earned stay with the owner (nothing is reversed). Audited. Returns the released hosts (the
 * caller syncs their active-host frames after the commit), or null when the agency was not OPEN (nothing changed —
 * the closing is idempotent).
 */
export async function closeAgencyIn(
  tx: Tx,
  agencyId: string,
  input: {
    reason: 'PROBATION_FAILED' | 'ADMIN';
    note: string | null;
    activated: number | null;
    required: number | null;
  },
  now: Date,
  specialGraceDays: number,
  by: AdminVia | 'sweeper' = CLI_VIA,
): Promise<{ owner: string; releasedHosts: string[] } | null> {
  const rows = await tx.$queryRaw<{ owner: string }[]>`
    UPDATE agencies
       SET status = 'CLOSED'::agency_status, closed_at = ${now}, close_reason = ${input.reason}::agency_close_reason,
           close_note = ${input.note}, probation_activated = COALESCE(${input.activated}::int, probation_activated),
           updated_at = ${now}
     WHERE id = ${agencyId}::uuid AND status = 'OPEN'::agency_status
     RETURNING owner_user_id::text AS owner`;
  const owner = rows[0]?.owner;
  if (!owner) return null;
  const released = await tx.$queryRaw<{ id: string; host: string }[]>`
    UPDATE agency_hosts SET status = 'RELEASED'::agency_host_status, ended_at = ${now}
     WHERE agency_id = ${agencyId}::uuid AND status = 'ACTIVE'::agency_host_status
     RETURNING id::text AS id, host_user_id::text AS host`;
  if (released.length > 0) {
    await tx.agencyComplaint.updateMany({
      where: { agencyHostId: { in: released.map((r) => r.id) }, status: 'OPEN' },
      data: { status: 'RESOLVED', resolution: 'RELEASED', note: 'the agency was closed', resolvedAt: now },
    });
  }
  await usernameIn(() => syncAgentUsernameIn(tx, owner, now, specialGraceDays, { note: 'agency closed' }));
  await notifier.agency(tx, {
    type: 'AGENCY_CLOSED',
    recipientId: owner,
    agencyId,
    activated: input.activated,
    required: input.required,
  });
  for (const r of released) {
    await notifier.agency(tx, { type: 'AGENCY_HOST_RELEASED', recipientId: r.host, agencyId });
  }
  await tx.auditLog.create({
    data: {
      ...(by === 'sweeper' ? {} : auditBy(by)),
      action: AuditAction.AGENCY_CLOSE,
      targetType: 'agency',
      targetId: agencyId,
      metadata: {
        owner,
        reason: input.reason,
        ...(input.note ? { note: input.note } : {}),
        activated: input.activated,
        required: input.required,
        releasedHosts: released.length,
        before: 'OPEN',
        after: 'CLOSED',
        via: by === 'sweeper' ? 'sweeper' : by.via,
      },
    },
  });
  return { owner, releasedHosts: released.map((r) => r.host) };
}

export type ProbationOutcome = 'passed' | 'closed' | 'reminded' | null;

/**
 * Settles one agency's probation now, in its own transaction (the row locked, so a sweep and a read never both act):
 * enough activated hosts at `min(now, end)` → it passes (at once, also before the end); otherwise at or after the end
 * it is closed (`PROBATION_FAILED`); otherwise, in the last AGENCY_PROBATION_REMINDER_HOURS, the owner is reminded
 * once. Nothing for an agency without a running probation.
 */
export async function settleProbation(
  prisma: PrismaClient,
  agencyId: string,
  now: Date,
  rules: ProbationRules,
  specialGraceDays: number,
): Promise<{ outcome: ProbationOutcome; activated: number; releasedHosts: string[] }> {
  return prisma.$transaction(async (tx) => {
    const a = await lockAgency(tx, agencyId);
    if (!a || a.status !== 'OPEN' || a.ends_at === null || a.passed_at !== null) {
      return { outcome: null, activated: 0, releasedHosts: [] };
    }
    const at = probationInstant(now, a.ends_at);
    const activated = (await probationHostsAt(tx, agencyId, at)).filter((h) => h.activated).length;
    const required = rules.probationMinHosts;
    if (activated >= required) {
      await tx.agency.update({
        where: { id: agencyId },
        data: { probationPassedAt: now, probationActivated: activated },
      });
      await notifier.agency(tx, {
        type: 'AGENCY_PROBATION_PASSED',
        recipientId: a.owner,
        agencyId,
        activated,
        required,
      });
      await tx.auditLog.create({
        data: {
          action: AuditAction.AGENCY_PROBATION_PASS,
          targetType: 'agency',
          targetId: agencyId,
          metadata: { owner: a.owner, activated, required, endsAt: a.ends_at.toISOString(), via: 'sweeper' },
        },
      });
      return { outcome: 'passed' as const, activated, releasedHosts: [] };
    }
    if (now.getTime() >= a.ends_at.getTime()) {
      const closed = await closeAgencyIn(
        tx,
        agencyId,
        { reason: 'PROBATION_FAILED', note: null, activated, required },
        now,
        specialGraceDays,
        'sweeper',
      );
      return { outcome: 'closed' as const, activated, releasedHosts: closed?.releasedHosts ?? [] };
    }
    const remindFrom = a.ends_at.getTime() - rules.probationReminderHours * HOUR_MS;
    if (now.getTime() >= remindFrom && a.reminded_at === null) {
      await tx.agency.update({ where: { id: agencyId }, data: { probationRemindedAt: now } });
      await notifier.agency(tx, {
        type: 'AGENCY_PROBATION_REMINDER',
        recipientId: a.owner,
        agencyId,
        activated,
        required,
      });
      return { outcome: 'reminded' as const, activated, releasedHosts: [] };
    }
    return { outcome: null, activated, releasedHosts: [] };
  });
}

/**
 * The sweeper's step: every running probation that may need a decision — any running one (it may have passed) —
 * oldest end first, one transaction each. Returns what happened and the released hosts (their frames follow).
 */
export async function sweepAgencyProbations(
  prisma: PrismaClient,
  now: Date,
  rules: ProbationRules,
  specialGraceDays: number,
): Promise<{ passed: string[]; closed: string[]; reminded: string[]; releasedHosts: string[] }> {
  const due = await prisma.agency.findMany({
    where: { status: 'OPEN', probationEndsAt: { not: null }, probationPassedAt: null },
    orderBy: [{ probationEndsAt: 'asc' }, { id: 'asc' }],
    select: { id: true },
    take: 500,
  });
  const out = {
    passed: [] as string[],
    closed: [] as string[],
    reminded: [] as string[],
    releasedHosts: [] as string[],
  };
  for (const a of due) {
    const r = await settleProbation(prisma, a.id, now, rules, specialGraceDays);
    if (r.outcome === 'passed') out.passed.push(a.id);
    if (r.outcome === 'closed') out.closed.push(a.id);
    if (r.outcome === 'reminded') out.reminded.push(a.id);
    out.releasedHosts.push(...r.releasedHosts);
  }
  return out;
}

/**
 * `economy-admin agency-probation-extend` / the panel: a running probation ends `days` later (counted from its end,
 * or from now when the end already passed and no sweep closed it yet); the reminder may come again. Audited.
 */
export async function extendProbationIn(
  tx: Tx,
  agencyId: string,
  days: number,
  reason: string,
  now: Date,
  by: AdminVia = CLI_VIA,
): Promise<{ endsAt: string }> {
  if (!Number.isInteger(days) || days < 1 || days > 90) throw new HostAgentError('days is 1–90.');
  const a = await lockAgency(tx, agencyId);
  if (!a) throw new HostAgentError('No such agency.');
  if (a.status !== 'OPEN' || a.ends_at === null || a.passed_at !== null) {
    throw new HostAgentError('The agency has no running probation.');
  }
  const from = Math.max(a.ends_at.getTime(), now.getTime());
  const endsAt = new Date(from + days * DAY_MS);
  await tx.agency.update({
    where: { id: agencyId },
    data: { probationEndsAt: endsAt, probationRemindedAt: null, updatedAt: now },
  });
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.AGENCY_PROBATION_EXTEND,
      targetType: 'agency',
      targetId: agencyId,
      metadata: {
        owner: a.owner,
        days,
        before: a.ends_at.toISOString(),
        after: endsAt.toISOString(),
        reason,
        via: by.via,
      },
    },
  });
  return { endsAt: endsAt.toISOString() };
}

/** `economy-admin agency-close` / the panel: the team closes an OPEN agency (reason ADMIN). */
export async function closeAgencyByAdminIn(
  tx: Tx,
  agencyId: string,
  reason: string,
  now: Date,
  specialGraceDays: number,
  by: AdminVia = CLI_VIA,
): Promise<{ releasedHosts: string[] }> {
  const a = await lockAgency(tx, agencyId);
  if (!a) throw new HostAgentError('No such agency.');
  const closed = await closeAgencyIn(
    tx,
    agencyId,
    { reason: 'ADMIN', note: reason, activated: null, required: null },
    now,
    specialGraceDays,
    by,
  );
  if (!closed) throw new HostAgentError('The agency is already closed.');
  return { releasedHosts: closed.releasedHosts };
}

/**
 * `economy-admin agency-reopen` / the panel: a CLOSED agency opens again with the same invite code and host code (the
 * released hosts do not come back; they may join again). A self-opened agency whose probation had not passed gets a
 * new full probation from now. The owner must be ACTIVE and not a host of another agency. Audited; the owner is told.
 */
export async function reopenAgencyIn(
  tx: Tx,
  agencyId: string,
  reason: string,
  now: Date,
  rules: ProbationRules,
  specialGraceDays: number,
  by: AdminVia = CLI_VIA,
): Promise<{ probationEndsAt: string | null }> {
  const a = await lockAgency(tx, agencyId);
  if (!a) throw new HostAgentError('No such agency.');
  if (a.status !== 'CLOSED') throw new HostAgentError('The agency is not closed.');
  const owner = await tx.user.findUnique({
    where: { id: a.owner },
    select: { status: true, deletedAt: true },
  });
  if (!owner || owner.deletedAt !== null || owner.status !== 'ACTIVE') {
    throw new HostAgentError('The owner account is not ACTIVE.');
  }
  if ((await tx.agencyHost.count({ where: { hostUserId: a.owner, status: 'ACTIVE' } })) > 0) {
    throw new HostAgentError('The owner is now a host of another agency; they must leave it first.');
  }
  const newProbation = a.ends_at !== null && a.passed_at === null;
  const endsAt = newProbation ? new Date(now.getTime() + rules.probationDays * DAY_MS) : null;
  await tx.agency.update({
    where: { id: agencyId },
    data: {
      status: 'OPEN',
      closedAt: null,
      closeReason: null,
      closeNote: null,
      updatedAt: now,
      ...(newProbation
        ? { probationEndsAt: endsAt, probationRemindedAt: null, probationActivated: null }
        : {}),
    },
  });
  await usernameIn(() => syncAgentUsernameIn(tx, a.owner, now, specialGraceDays));
  await notifier.agency(tx, { type: 'AGENCY_OPENED', recipientId: a.owner, agencyId });
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.AGENCY_REOPEN,
      targetType: 'agency',
      targetId: agencyId,
      metadata: {
        owner: a.owner,
        reason,
        probationEndsAt: endsAt?.toISOString() ?? null,
        before: 'CLOSED',
        after: 'OPEN',
        via: by.via,
      },
    },
  });
  return { probationEndsAt: endsAt?.toISOString() ?? null };
}
