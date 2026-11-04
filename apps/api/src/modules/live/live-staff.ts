import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Prisma, type AdminPermission } from '../../generated/prisma/client.js';
import type { PrismaService } from '../../prisma/prisma.service.js';

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
