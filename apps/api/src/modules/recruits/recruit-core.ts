import { auditBy, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { Prisma, type StaffRecruitSettings } from '../../generated/prisma/client.js';
import type { PrismaService } from '../../prisma/prisma.service.js';
import type { ProfitEconomy } from '../programs/host-target-engine.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { formatStaffId, parseStaffId } from '../users/staff-ids.js';
import {
  DEFAULT_RECRUIT_BPS,
  RECRUIT_TYPES,
  giftProfitUnits,
  topupProfitUnits,
  type GiftSums,
  type RecruitType,
  type TopupSums,
} from './recruit-math.js';

/**
 * v1.75-live (D285, owner, CONVENTIONS §10.96.13): recruitment by staff «الاستقطاب» — the database side, shared by the
 * application flows (agency, recharge agent, host, creator), the panel, the daily commission job and the tests (no
 * Nest dependencies).
 *
 * **Who can recruit (decision):** an ACTIVE account (`users.role` ADMIN) holding MODERATION «مشرف» or BD «تطوير
 * الأعمال» now — not SUPPORT, FINANCE nor OWNER (the owner's suggestion: the people in the field). Checked when the
 * form is sent and again when the application is activated (a recruiter who left the team meanwhile attributes
 * nothing; audited `staff.recruit.skip`).
 */

type Tx = Prisma.TransactionClient;
type Db = Tx | PrismaService;

// v1.139-social (D387, §10.176.1): TALENT «مدير الوكالات والمواهب» extends BD — a recruiter too.
export const RECRUITER_ROLES = ['MODERATION', 'BD', 'TALENT'] as const;
export type RecruiterRole = (typeof RECRUITER_ROLES)[number];

/** A recruiter as the forms' live check and the panel show them (`StaffRecruiter`). */
export interface StaffRecruiterDto {
  userId: string;
  staffId: string | null;
  username: string;
  displayName: string;
  avatarUrl: string | null;
  role: RecruiterRole;
}

/** The roles of `userId` that make them a recruiter now (empty: not one). */
async function recruiterRoleOf(db: Db, userId: string): Promise<RecruiterRole | null> {
  const user = await db.user.findUnique({
    where: { id: userId },
    select: { role: true, status: true, adminPermissions: { select: { permission: true } } },
  });
  if (!user || user.role !== 'ADMIN' || user.status !== 'ACTIVE') return null;
  const held = user.adminPermissions.map((p) => p.permission as string);
  // MODERATION first: a person holding both is shown as the moderator «مشرف».
  return RECRUITER_ROLES.find((r) => held.includes(r)) ?? null;
}

/**
 * The recruiter named by `raw` — a staff ID («Kabso01», «kabso1», «@Kabso01») or the staff member's username (`@`
 * optional) — when they can recruit now; null otherwise (unknown, or not a recruiter: never told apart).
 */
export async function findRecruiter(db: Db, raw: string): Promise<StaffRecruiterDto | null> {
  const value = raw.trim().slice(0, 64);
  if (value === '') return null;
  let userId: string | null = null;
  const number = parseStaffId(value);
  if (number !== null) {
    userId = (await db.staffId.findUnique({ where: { number }, select: { userId: true } }))?.userId ?? null;
  }
  if (userId === null) {
    const username = value.replace(/^@/, '').toLowerCase();
    if (!/^[a-z0-9._]{1,40}$/.test(username)) return null;
    userId =
      (await db.userProfile.findUnique({ where: { username }, select: { userId: true } }))?.userId ?? null;
  }
  if (userId === null) return null;
  const role = await recruiterRoleOf(db, userId);
  if (role === null) return null;
  const row = await db.user.findUnique({
    where: { id: userId },
    select: {
      profile: { select: { username: true, displayName: true, avatarUrl: true } },
      staffNumber: { select: { number: true } },
    },
  });
  return {
    userId,
    staffId: row?.staffNumber ? formatStaffId(row.staffNumber.number) : null,
    username: row?.profile?.username ?? '',
    displayName: row?.profile?.displayName ?? '',
    avatarUrl: row?.profile?.avatarUrl ?? null,
    role,
  };
}

/**
 * The optional field «إن كنت تابعاً لمشرف، ضع معرّفه هنا» of an application: null when empty or missing; the
 * recruiter's id when valid; else 400 VALIDATION_FAILED `recruiter` (`not_found`, or `self` for the applicant).
 */
export async function recruiterOfForm(
  db: Db,
  raw: string | null | undefined,
  applicantId: string,
): Promise<string | null> {
  // v1.108-social (D343, §10.142): an account created with a supervisor's staff ID (GRANTED) has that supervisor as its
  // recruiter for good — the form's field is not read («لا يمكن تغيير الرمز بعد التسجيل») while they can still recruit.
  const signup = await db.staffSignupRecruit.findUnique({
    where: { userId: applicantId },
    select: { status: true, recruiterUserId: true },
  });
  if (signup?.status === 'GRANTED' && (await recruiterRoleOf(db, signup.recruiterUserId)) !== null)
    return signup.recruiterUserId;
  if (raw === undefined || raw === null || raw.trim() === '') return null;
  const found = await findRecruiter(db, raw);
  if (!found) throw AppException.validation([{ field: 'recruiter', issue: 'not_found' }]);
  if (found.userId === applicantId) throw AppException.validation([{ field: 'recruiter', issue: 'self' }]);
  return found.userId;
}

export interface AttributeInput {
  readonly type: RecruitType;
  readonly recruitUserId: string;
  /** The recruiter the application named (null: no attribution, nothing written). */
  readonly recruiterUserId: string | null;
  readonly applicationId: string;
  readonly agencyId?: string | null;
  readonly now: Date;
  readonly by: AdminVia;
}

/**
 * At the ACTIVATION of an application that named a recruiter (inside the activation's transaction): the recruit is
 * attributed to them for good — one `staff_recruitments` row, audited `staff.recruit.attribute`. Nothing when no
 * recruiter was named. Skipped (audited `staff.recruit.skip` with the reason) when the recruiter cannot recruit any
 * more (`recruiter_inactive`) or the person is already attributed for this type or, HOST / CREATOR, the other one
 * (`already_attributed`: an attribution is permanent).
 */
export async function attributeRecruitIn(
  tx: Tx,
  input: AttributeInput,
): Promise<{ recruitmentId: string } | null> {
  if (input.recruiterUserId === null) return null;
  const skip = async (reason: 'recruiter_inactive' | 'already_attributed' | 'self') => {
    await tx.auditLog.create({
      data: {
        ...auditBy(input.by),
        action: AuditAction.STAFF_RECRUIT_SKIP,
        targetType: 'user',
        targetId: input.recruitUserId,
        metadata: {
          type: input.type,
          recruiter: input.recruiterUserId,
          application: input.applicationId,
          reason,
          via: input.by.via,
        },
      },
    });
    return null;
  };
  if (input.recruiterUserId === input.recruitUserId) return skip('self');
  if ((await recruiterRoleOf(tx, input.recruiterUserId)) === null) return skip('recruiter_inactive');
  const rows = await tx.$queryRaw<{ id: string }[]>`
    INSERT INTO staff_recruitments (id, type, recruiter_user_id, recruit_user_id, application_id, agency_id, activated_at)
    VALUES (${uuidv7()}::uuid, ${input.type}::staff_recruit_type, ${input.recruiterUserId}::uuid,
            ${input.recruitUserId}::uuid, ${input.applicationId}::uuid, ${input.agencyId ?? null}::uuid, ${input.now})
    ON CONFLICT DO NOTHING
    RETURNING id::text AS id`;
  const id = rows[0]?.id;
  if (!id) return skip('already_attributed');
  await tx.auditLog.create({
    data: {
      ...auditBy(input.by),
      action: AuditAction.STAFF_RECRUIT_ATTRIBUTE,
      targetType: 'staff_recruitment',
      targetId: id,
      metadata: {
        type: input.type,
        recruiter: input.recruiterUserId,
        recruit: input.recruitUserId,
        application: input.applicationId,
        ...(input.agencyId ? { agency: input.agencyId } : {}),
        via: input.by.via,
      },
    },
  });
  return { recruitmentId: id };
}

export type RecruitCounts = Record<RecruitType, number> & { total: number };

export function emptyRecruitCounts(): RecruitCounts {
  return { HOST: 0, AGENCY: 0, RECHARGE_AGENT: 0, CREATOR: 0, total: 0 };
}

/** How many recruits each of `userIds` has, by type. */
export async function recruitCountsOf(
  db: Db,
  userIds: readonly string[],
): Promise<Map<string, RecruitCounts>> {
  const out = new Map<string, RecruitCounts>();
  if (userIds.length === 0) return out;
  const rows = await db.staffRecruitment.groupBy({
    by: ['recruiterUserId', 'type'],
    where: { recruiterUserId: { in: [...userIds] } },
    _count: { _all: true },
  });
  for (const r of rows) {
    const c = out.get(r.recruiterUserId) ?? emptyRecruitCounts();
    c[r.type] += r._count._all;
    c.total += r._count._all;
    out.set(r.recruiterUserId, c);
  }
  return out;
}

// ---- The profit a recruit generated in a window ------------------------------------------------------------------

/** The gift sums of the sends matched by `filter` (on `gr` = live_gift_recipients, `g` = live_gifts) in [from, to). */
async function giftSumsIn(
  db: Db,
  filter: Prisma.Sql,
  from: Date,
  to: Date,
): Promise<GiftSums & { sends: number }> {
  const [row] = await db.$queryRaw<
    { charged: bigint; lucky_coins: bigint; cherries: bigint; commissions: bigint; sends: number }[]
  >`
    SELECT COALESCE(sum(x.charged), 0)::bigint AS charged,
           COALESCE(sum(x.coins) FILTER (WHERE x.lucky), 0)::bigint AS lucky_coins,
           COALESCE(sum(x.cherries), 0)::bigint AS cherries,
           COALESCE(sum(x.commissions), 0)::bigint AS commissions,
           count(*)::int AS sends
      FROM (
        SELECT gr.coins,
               -- D323: in numeric — a recipient's coins × the send's charge can pass BIGINT (e.g. 1.3e11 × 3.3e12).
               CASE WHEN g.total_coins > 0 THEN div(gr.coins::numeric * g.coins_charged, g.total_coins) ELSE 0 END AS charged,
               EXISTS (SELECT 1 FROM lucky_gift_draws d WHERE d.gift_id = g.id) AS lucky,
               COALESCE((SELECT sum(l.delta) FROM cherry_ledger l
                          WHERE l.user_id = gr.user_id AND l.reference_id = g.id::text
                            AND l.reason IN ('GIFT_RECEIVED', 'GIFT_REVERSAL')), 0) AS cherries,
               COALESCE((SELECT sum(ae.commission + ae.parent_commission) FROM agency_earnings ae
                          WHERE ae.gift_id = g.id AND ae.host_user_id = gr.user_id AND ae.reversed_at IS NULL), 0)
                 AS commissions
          FROM live_gift_recipients gr
          JOIN live_gifts g ON g.id = gr.gift_id
          JOIN users s ON s.id = g.sender_id AND s.status = 'ACTIVE'
         WHERE ${filter} AND g.created_at >= ${from}::timestamptz AND g.created_at < ${to}::timestamptz
      ) x`;
  return {
    charged: row?.charged ?? 0n,
    luckyCoins: row?.lucky_coins ?? 0n,
    cherries: row?.cherries ?? 0n,
    commissions: row?.commissions ?? 0n,
    sends: row?.sends ?? 0,
  };
}

/** The wholesale top-ups of a recharge agent in [from, to), in the payout currency. */
async function topupSumsIn(
  db: Db,
  agentUserId: string,
  from: Date,
  to: Date,
  currency: string,
): Promise<TopupSums & { topups: number }> {
  const [row] = await db.$queryRaw<{ paid: bigint; coins: bigint; n: number }[]>`
    SELECT COALESCE(sum(paid_minor), 0)::bigint AS paid, COALESCE(sum(coins), 0)::bigint AS coins, count(*)::int AS n
      FROM recharge_topups
     WHERE agent_user_id = ${agentUserId}::uuid AND currency = ${currency}
       AND created_at >= ${from}::timestamptz AND created_at < ${to}::timestamptz`;
  return { paidMinor: row?.paid ?? 0n, coins: row?.coins ?? 0n, topups: row?.n ?? 0 };
}

export interface RecruitProfit {
  /** Money units (D281); may be negative. */
  readonly units: bigint;
  /** The gift sends or top-ups counted. */
  readonly count: number;
}

/** What one recruit generated for the platform in [from, to) (see `recruit-math.ts` for each type). */
export async function recruitProfitIn(
  db: Db,
  r: { type: RecruitType; recruitUserId: string; agencyId: string | null },
  from: Date,
  to: Date,
  e: ProfitEconomy,
  currency: string,
): Promise<RecruitProfit> {
  if (to <= from) return { units: 0n, count: 0 };
  if (r.type === 'RECHARGE_AGENT') {
    const t = await topupSumsIn(db, r.recruitUserId, from, to, currency);
    return { units: topupProfitUnits(t, e), count: t.topups };
  }
  const filter =
    r.type === 'AGENCY'
      ? Prisma.sql`EXISTS (SELECT 1 FROM agency_earnings ae2 WHERE ae2.gift_id = g.id
                            AND ae2.host_user_id = gr.user_id AND ae2.agency_id = ${r.agencyId}::uuid)`
      : Prisma.sql`gr.user_id = ${r.recruitUserId}::uuid`;
  const s = await giftSumsIn(db, filter, from, to);
  return { units: giftProfitUnits(s, e), count: s.sends };
}

// ---- The OWNER's shares ---------------------------------------------------------------------------------------------

export interface RecruitSettingsDto {
  bps: Record<RecruitType, number>;
  defaults: Record<RecruitType, number>;
  updatedAt: string;
  updatedById: string | null;
}

export async function recruitSettingsIn(db: Db): Promise<StaffRecruitSettings> {
  const row = await db.staffRecruitSettings.findUnique({ where: { id: 1 } });
  if (row) return row;
  return db.staffRecruitSettings.upsert({ where: { id: 1 }, create: { id: 1 }, update: {} });
}

export function bpsOf(row: StaffRecruitSettings): Record<RecruitType, number> {
  return {
    HOST: row.hostBps,
    AGENCY: row.agencyBps,
    RECHARGE_AGENT: row.rechargeBps,
    CREATOR: row.creatorBps,
  };
}

export function recruitSettingsDto(row: StaffRecruitSettings): RecruitSettingsDto {
  return {
    bps: bpsOf(row),
    defaults: { ...DEFAULT_RECRUIT_BPS },
    updatedAt: row.updatedAt.toISOString(),
    updatedById: row.updatedById,
  };
}

const BPS_COLUMN: Record<RecruitType, 'hostBps' | 'agencyBps' | 'rechargeBps' | 'creatorBps'> = {
  HOST: 'hostBps',
  AGENCY: 'agencyBps',
  RECHARGE_AGENT: 'rechargeBps',
  CREATOR: 'creatorBps',
};

/** The OWNER changes some shares (with a reason; audited with before and after). */
export async function updateRecruitSettingsIn(
  tx: Tx,
  patch: Partial<Record<RecruitType, number>>,
  reason: string,
  by: AdminVia,
  now: Date,
): Promise<StaffRecruitSettings> {
  await tx.$queryRaw`SELECT 1 FROM staff_recruit_settings WHERE id = 1 FOR UPDATE`;
  const before = bpsOf(await recruitSettingsIn(tx));
  const data: Prisma.StaffRecruitSettingsUpdateInput = { updatedAt: now, updatedById: by.actorUserId };
  for (const t of RECRUIT_TYPES) {
    const v = patch[t];
    if (v !== undefined) data[BPS_COLUMN[t]] = v;
  }
  const after = await tx.staffRecruitSettings.update({ where: { id: 1 }, data });
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.STAFF_RECRUIT_SETTINGS_UPDATE,
      targetType: 'staff_recruit_settings',
      targetId: '1',
      metadata: { before, after: bpsOf(after), reason, via: by.via },
    },
  });
  return after;
}

/** A refused reassignment (the panel answers 409 ADMIN_ACTION_REFUSED with the issue). */
export class RecruitError extends Error {
  constructor(
    message: string,
    readonly issue: string,
  ) {
    super(message);
  }
}

/**
 * The OWNER moves a recruit to another recruiter (panel, a reason; audited `staff.recruit.reassign` {before, after,
 * reason}). The new recruiter must be able to recruit now and not be the recruit; the next days' commissions go to
 * them (the days already paid stay with the former one).
 */
export async function reassignRecruitIn(
  tx: Tx,
  recruitmentId: string,
  recruiterRaw: string,
  reason: string,
  by: AdminVia,
  now: Date,
): Promise<{ before: string; after: string }> {
  const [row] = await tx.$queryRaw<{ recruiter: string; recruit: string; type: string }[]>`
    SELECT recruiter_user_id::text AS recruiter, recruit_user_id::text AS recruit, type::text AS type
      FROM staff_recruitments WHERE id = ${recruitmentId}::uuid FOR UPDATE`;
  if (!row) throw new RecruitError('No such recruit.', 'recruit_not_found');
  const next = await findRecruiter(tx, recruiterRaw);
  if (!next) throw new RecruitError('That person cannot recruit (MODERATION or BD).', 'recruiter_not_found');
  if (next.userId === row.recruit)
    throw new RecruitError('A recruit cannot be their own recruiter.', 'recruiter_self');
  if (next.userId === row.recruiter)
    throw new RecruitError('That is the current recruiter.', 'recruiter_same');
  await tx.staffRecruitment.update({
    where: { id: recruitmentId },
    data: {
      recruiterUserId: next.userId,
      reassignedAt: now,
      reassignedById: by.actorUserId,
      reassignReason: reason,
    },
  });
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.STAFF_RECRUIT_REASSIGN,
      targetType: 'staff_recruitment',
      targetId: recruitmentId,
      metadata: {
        type: row.type,
        recruit: row.recruit,
        before: row.recruiter,
        after: next.userId,
        reason,
        via: by.via,
      },
    },
  });
  return { before: row.recruiter, after: next.userId };
}

export { recruiterRoleOf };
