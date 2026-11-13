import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Prisma, type AdminPermission } from '../../generated/prisma/client.js';
import type { PrismaService } from '../../prisma/prisma.service.js';
import { isStaffRegion, sortRegions, type StaffRegion } from './staff-regions.js';

/**
 * v1.68-live (D273, CONVENTIONS §10.96.6 / §10.96.7): who is «فريق كابسو» in the app. Read from the roles held NOW
 * (an ACTIVE account whose `users.role` is ADMIN, like the panel's `rolesOf`), so a revoked role or a suspension
 * applies at once:
 *
 *  - **watch staff** (OWNER, MODERATION, SUPPORT): enter every live as staff — listed with the «فريق كابسو» badge (or
 *    hidden), never counted, never kicked, chat-muted or kept out by a block, and never sending gifts or taps;
 *  - **panel staff** (any panel role, FINANCE too): untouchable from the app — no kick, mute, message removal, seat
 *    action or family kick / mute against them (`STAFF_PROTECTED`).
 */
export const WATCH_STAFF_ROLES = [
  'OWNER',
  'MODERATION',
  'SUPPORT',
] as const satisfies readonly AdminPermission[];
export const PANEL_STAFF_ROLES = [
  'OWNER',
  'MODERATION',
  'SUPPORT',
  'FINANCE',
  // v1.75-live (D285, §10.96.13): «تطوير الأعمال» — recruitment only (never watch staff).
  'BD',
  // v1.139-social (D387, §10.176.1): the operations roles (never watch staff).
  'LIVE_OPS',
  'TALENT',
  'VIP_CARE',
  'COMMUNITY',
] as const satisfies readonly AdminPermission[];

type Db = Pick<PrismaService, '$queryRaw'> | Prisma.TransactionClient;

function rolesSql(roles: readonly AdminPermission[]): Prisma.Sql {
  return Prisma.join(roles.map((r) => Prisma.sql`${r}::admin_permission`));
}

/** SQL: `userId` (a uuid parameter, or a column) is watch staff now. */
export function watchStaffSql(userId: string | Prisma.Sql): Prisma.Sql {
  const id = typeof userId === 'string' ? Prisma.sql`${userId}::uuid` : userId;
  return Prisma.sql`EXISTS (SELECT 1 FROM users su JOIN user_admin_permissions sp ON sp.user_id = su.id
                     WHERE su.id = ${id} AND su.role = 'ADMIN'::user_role AND su.status = 'ACTIVE'::user_status
                       AND sp.permission IN (${rolesSql(WATCH_STAFF_ROLES)}))`;
}

/** SQL: `userId` holds any panel role now. */
export function panelStaffSql(userId: string | Prisma.Sql): Prisma.Sql {
  const id = typeof userId === 'string' ? Prisma.sql`${userId}::uuid` : userId;
  return Prisma.sql`EXISTS (SELECT 1 FROM users su JOIN user_admin_permissions sp ON sp.user_id = su.id
                     WHERE su.id = ${id} AND su.role = 'ADMIN'::user_role AND su.status = 'ACTIVE'::user_status
                       AND sp.permission IN (${rolesSql(PANEL_STAFF_ROLES)}))`;
}

/** The ids among `userIds` that are watch staff now. */
export async function watchStaffAmong(db: Db, userIds: readonly string[]): Promise<Set<string>> {
  const ids = [...new Set(userIds)];
  if (ids.length === 0) return new Set();
  const rows = await db.$queryRaw<{ id: string }[]>`
    SELECT DISTINCT u.id::text AS id FROM users u JOIN user_admin_permissions p ON p.user_id = u.id
     WHERE u.id IN (${Prisma.join(ids.map((id) => Prisma.sql`${id}::uuid`))})
       AND u.role = 'ADMIN'::user_role AND u.status = 'ACTIVE'::user_status
       AND p.permission IN (${rolesSql(WATCH_STAFF_ROLES)})`;
  return new Set(rows.map((r) => r.id));
}

export async function isWatchStaff(db: Db, userId: string): Promise<boolean> {
  return (await watchStaffAmong(db, [userId])).has(userId);
}

export async function isPanelStaff(db: Db, userId: string): Promise<boolean> {
  const [row] = await db.$queryRaw<{ ok: boolean }[]>`SELECT ${panelStaffSql(userId)} AS ok`;
  return row?.ok === true;
}

/**
 * v1.139-social (D387, CONVENTIONS §10.176.8–9): «staff» for the withdrawal rule (§10.176.9) is
 * **any panel role held now** ({@link PANEL_STAFF_ROLES}: OWNER, MODERATION / TRUST_SAFETY, SUPPORT, FINANCE, BD,
 * LIVE_OPS, TALENT, VIP_CARE, COMMUNITY — an ACTIVE ADMIN account), the same set as `STAFF_PROTECTED`. One helper so
 * every path asks the same question.
 */
export const isStaffAccount = isPanelStaff;

/**
 * The gift rule's staff (§10.176.8; owner 2026-11-12: «لا غير ممنوع» — the OWNER is not blocked): an **employee** —
 * a staff account that does not hold OWNER (an OWNER who also holds another role is still the owner). The same set as
 * the limited staff account ({@link isLimitedStaff}).
 */
export async function isGiftBlockedStaff(db: Db, userId: string): Promise<boolean> {
  return isLimitedStaff(db, userId);
}

/** 403 STAFF_GIFT_REFUSED when the caller is an employee (every gift-send path; §10.176.8). */
export async function refuseStaffGift(db: Db, callerId: string): Promise<void> {
  if (await isGiftBlockedStaff(db, callerId)) {
    throw new AppException(ErrorCode.STAFF_GIFT_REFUSED, undefined, [{ field: 'staff', issue: 'gifts' }]);
  }
}

/**
 * 403 STAFF_WITHDRAWAL_COMPANY_ONLY when `userId` (whose cherries would leave) is a staff account: a staff member's
 * cherries leave only through `requestCherryWithdrawal` (to the company; the OWNER handles it), never through a
 * recharge agent or any third party (§10.176.9).
 */
export async function refuseStaffCherryRoute(db: Db, userId: string): Promise<void> {
  if (await isStaffAccount(db, userId)) {
    throw new AppException(ErrorCode.STAFF_WITHDRAWAL_COMPANY_ONLY, undefined, [
      { field: 'staff', issue: 'company_only' },
    ]);
  }
}

/** 403 STAFF_PROTECTED when `targetId` holds a panel role (§10.96.7). */
export async function assertNotStaffTarget(db: Db, targetId: string): Promise<void> {
  if (await isPanelStaff(db, targetId)) throw new AppException(ErrorCode.STAFF_PROTECTED);
}

/**
 * v1.68-live (D273, §10.96.6): the caller's step-up grant for the staff tools in the app — bound to this app session,
 * not ended, not expired; null otherwise. The roles are checked separately (on every request).
 */
export async function activeStaffGrant(
  db: Pick<PrismaService, 'adminAppGrant'> | Prisma.TransactionClient,
  userId: string,
  sessionId: string,
  now: Date,
): Promise<{ id: string; expiresAt: Date } | null> {
  return db.adminAppGrant.findFirst({
    where: { userId, sessionId, revokedAt: null, expiresAt: { gt: now } },
    orderBy: { createdAt: 'desc' },
    select: { id: true, expiresAt: true },
  });
}

/** The panel roles `userId` holds now (an ACTIVE ADMIN account; else none) — the panel's `rolesOf`. */
export async function staffRolesOf(
  db: Pick<PrismaService, 'user'> | Prisma.TransactionClient,
  userId: string,
): Promise<AdminPermission[]> {
  const user = await db.user.findUnique({
    where: { id: userId },
    select: { role: true, status: true, adminPermissions: { select: { permission: true } } },
  });
  if (!user || user.role !== 'ADMIN' || user.status !== 'ACTIVE') return [];
  return user.adminPermissions
    .map((p) => p.permission)
    .filter((p) => (PANEL_STAFF_ROLES as readonly string[]).includes(p));
}

/** Ends every open step-up grant of `userId` (a revoked role, a lockout, a reset authenticator, «إنهاء»). */
export async function revokeStaffGrantsIn(
  db: Pick<PrismaService, 'adminAppGrant'> | Prisma.TransactionClient,
  userId: string,
  reason: 'ROLE_REVOKED' | 'LOCKED' | 'TOTP_RESET' | 'ENDED' | 'REPLACED',
  now: Date = new Date(),
): Promise<number> {
  const out = await db.adminAppGrant.updateMany({
    where: { userId, revokedAt: null },
    data: { revokedAt: now, revokedReason: reason },
  });
  return out.count;
}

/** 403 LIVE_STAFF_REFUSED (`details[0].issue`) when the caller is watch staff (§10.96.6). */
export async function refuseWatchStaff(
  db: Db,
  callerId: string,
  issue: 'gifts' | 'taps' | 'bullets' | 'seat' | 'hidden_chat',
): Promise<void> {
  if (await isWatchStaff(db, callerId)) {
    throw new AppException(ErrorCode.LIVE_STAFF_REFUSED, undefined, [{ field: 'staff', issue }]);
  }
}

/**
 * v1.72-live (D283, CONVENTIONS §10.96.10; owner: «الشخص الذي بفريق الادارة لدينا لا يمكنه فتح لايف وليس لديه
 * ليفيلات — فقط سوف يكون له ايقونة التي وضعناها وإطار، بالاضافة لاعداداته وصفحته الشخصية فقط، يمكن ان يقوم بتنزيل
 * بوست اعلان فقط او ريلز اعلان»): the **limited** staff account — an ACTIVE ADMIN account holding MODERATION,
 * SUPPORT or FINANCE and **not** OWNER (the OWNER's account stays a normal one: lives, levels, any post). Read from the
 * roles held now, like the rest of this file. Such an account cannot go live, shows no levels, posts only
 * announcements, joins no family, buys no VIP and has no tasks.
 */
export const LIMITED_STAFF_ROLES = [
  'MODERATION',
  'SUPPORT',
  'FINANCE',
  // v1.75-live (D285, §10.96.13): BD is a limited staff account too (no live, no levels, the team picture).
  'BD',
  // v1.139-social (D387, §10.176.1): so are the operations roles (after the others: the first held names the line).
  'LIVE_OPS',
  'TALENT',
  'VIP_CARE',
  'COMMUNITY',
] as const satisfies readonly AdminPermission[];
export type LimitedStaffRole = (typeof LIMITED_STAFF_ROLES)[number];

/**
 * The roles that carry regions (§10.96.11). v1.75-live (D285): BD too — its profile line «تطوير الأعمال — الوطن
 * العربي» (the regions only label it: BD has no shift, so no live is ever assigned to it).
 */
export const REGION_STAFF_ROLES = [
  'MODERATION',
  'SUPPORT',
  'BD',
] as const satisfies readonly AdminPermission[];

/** SQL: `userId` is a limited staff account now. */
export function limitedStaffSql(userId: string | Prisma.Sql): Prisma.Sql {
  const id = typeof userId === 'string' ? Prisma.sql`${userId}::uuid` : userId;
  return Prisma.sql`(EXISTS (SELECT 1 FROM users su JOIN user_admin_permissions sp ON sp.user_id = su.id
                      WHERE su.id = ${id} AND su.role = 'ADMIN'::user_role AND su.status = 'ACTIVE'::user_status
                        AND sp.permission IN (${rolesSql(LIMITED_STAFF_ROLES)}))
                 AND NOT EXISTS (SELECT 1 FROM user_admin_permissions so
                      WHERE so.user_id = ${id} AND so.permission = 'OWNER'::admin_permission))`;
}

/** The limited staff role a person's line names: MODERATION, else SUPPORT, else FINANCE; null for OWNER / none. */
export function limitedRoleOf(roles: readonly string[]): LimitedStaffRole | null {
  if (roles.includes('OWNER')) return null;
  for (const r of LIMITED_STAFF_ROLES) if (roles.includes(r)) return r;
  return null;
}

/** The ids among `userIds` that are limited staff now, with the role their line names. */
export async function limitedStaffAmong(
  db: Db,
  userIds: readonly string[],
): Promise<Map<string, LimitedStaffRole>> {
  const ids = [...new Set(userIds)];
  const out = new Map<string, LimitedStaffRole>();
  if (ids.length === 0) return out;
  const rows = await db.$queryRaw<{ id: string; roles: string[] }[]>`
    SELECT u.id::text AS id, array_agg(p.permission::text) AS roles
      FROM users u JOIN user_admin_permissions p ON p.user_id = u.id
     WHERE u.id IN (${Prisma.join(ids.map((id) => Prisma.sql`${id}::uuid`))})
       AND u.role = 'ADMIN'::user_role AND u.status = 'ACTIVE'::user_status
     GROUP BY u.id`;
  for (const r of rows) {
    const role = limitedRoleOf(r.roles);
    if (role) out.set(r.id, role);
  }
  return out;
}

export async function isLimitedStaff(db: Db, userId: string): Promise<boolean> {
  return (await limitedStaffAmong(db, [userId])).has(userId);
}

export type LimitedStaffIssue =
  | 'live'
  | 'post_kind'
  | 'story'
  | 'repost'
  | 'family'
  | 'vip'
  | 'tasks'
  | 'avatar'
  | 'cover'
  | 'bio'
  | 'frame'
  | 'store'
  // v1.87-social (D287, owner): acting as a recharge agent's employee (selling, cherries, orders).
  | 'recharge_employee';

/** 403 STAFF_ACCOUNT_LIMITED (`details[0].issue`) when the caller is a limited staff account (§10.96.10). */
export async function refuseLimitedStaff(db: Db, callerId: string, issue: LimitedStaffIssue): Promise<void> {
  if (await isLimitedStaff(db, callerId)) {
    throw new AppException(ErrorCode.STAFF_ACCOUNT_LIMITED, undefined, [{ field: 'staff', issue }]);
  }
}

/**
 * The «فريق كابسو» identity a limited staff account's profile shows (`KabsoStaffIdentity`, §10.96.10–11): the role
 * its line names and, for MODERATION / SUPPORT, the regions it is responsible for (catalogue order). Null for
 * anyone else (the OWNER too).
 */
export async function staffIdentityOf(
  db: Pick<PrismaService, '$queryRaw' | 'adminStaffRegion'> | Prisma.TransactionClient,
  userId: string,
): Promise<{ role: LimitedStaffRole; regions: StaffRegion[] } | null> {
  const role = (await limitedStaffAmong(db, [userId])).get(userId);
  if (!role) return null;
  if (role === 'FINANCE') return { role, regions: [] };
  const rows = await db.adminStaffRegion.findMany({ where: { userId }, select: { region: true } });
  return { role, regions: sortRegions(rows.map((r) => r.region).filter(isStaffRegion)) };
}
