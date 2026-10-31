import { auditBy, CLI_VIA, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PANEL_ROLES, type PanelRole } from './admin-permissions.js';

type Tx = Prisma.TransactionClient;

/**
 * The admin panel's roles from the command line only (v1.60-social, D191, CONVENTIONS §10.54.1): `admin-admin
 * grant|revoke|list|reset-2fa`. A grant makes the account `role = ADMIN` when it is not yet (this is how the first
 * OWNER is bootstrapped); revoking the last panel role ends the person's panel sessions. Every change is audited in
 * its transaction. Shared by the CLI and the tests (no Nest dependencies).
 *
 * v1.65-social (D197, CONVENTIONS §10.60.6): the OWNER's team page runs the same rules (`by` = the panel, with the
 * actor, the IP and the required reason). The role rows are written only through the SECURITY DEFINER function
 * `kabso_admin_panel_role` (migration 20270112100000_admin_v2): the runtime role cannot write
 * `user_admin_permissions` itself, and the function refuses every permission that is not a panel role.
 */
export class AdminRoleError extends Error {}

export function parseRole(raw: string): PanelRole {
  const v = raw.trim().toUpperCase();
  const role = v === 'MODERATOR' ? 'MODERATION' : v;
  if (!(PANEL_ROLES as readonly string[]).includes(role)) {
    throw new AdminRoleError(`Unknown role ${raw}: one of OWNER, MODERATOR, SUPPORT, FINANCE.`);
  }
  return role as PanelRole;
}

/** The account by email (the CLI) or by id (the panel). */
async function userOf(tx: Tx, who: string) {
  const value = who.trim();
  const user = await tx.user.findUnique({
    where: /^[0-9a-f-]{36}$/i.test(value) ? { id: value.toLowerCase() } : { email: value.toLowerCase() },
    select: { id: true, role: true, status: true },
  });
  if (!user) throw new AdminRoleError(`No account ${who}.`);
  return user;
}

/** Adds or removes one panel role row through `kabso_admin_panel_role` (true = a row changed). */
async function setRoleRow(tx: Tx, userId: string, role: PanelRole, grant: boolean, by: AdminVia) {
  const rows = await tx.$queryRaw<{ changed: boolean }[]>`
    SELECT kabso_admin_panel_role(${userId}::uuid, ${role}, ${grant}, ${by.actorUserId}::uuid) AS changed`;
  return rows[0]?.changed === true;
}

/** The panel roles `userId` holds now. */
export async function panelRolesIn(tx: Tx, userId: string): Promise<PanelRole[]> {
  return (await tx.userAdminPermission.findMany({ where: { userId }, select: { permission: true } }))
    .map((p) => p.permission)
    .filter((p): p is PanelRole => (PANEL_ROLES as readonly string[]).includes(p));
}

/** Extra metadata of a panel change (the required reason). */
type Extra = { readonly reason?: string };

export async function grantRoleIn(
  tx: Tx,
  who: string,
  role: PanelRole,
  by: AdminVia = CLI_VIA,
  extra: Extra = {},
): Promise<{ userId: string; madeAdmin: boolean; already: boolean }> {
  const user = await userOf(tx, who);
  if (user.status !== 'ACTIVE') throw new AdminRoleError(`The account is ${user.status}.`);
  const madeAdmin = user.role !== 'ADMIN';
  if (madeAdmin) await tx.user.update({ where: { id: user.id }, data: { role: 'ADMIN' } });
  const already = !(await setRoleRow(tx, user.id, role, true, by));
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.ADMIN_ROLE_GRANT,
      targetType: 'user',
      targetId: user.id,
      metadata: { role, madeAdmin, already, ...extra, via: by.via },
    },
  });
  return { userId: user.id, madeAdmin, already };
}

export async function revokeRoleIn(
  tx: Tx,
  who: string,
  role: PanelRole,
  by: AdminVia = CLI_VIA,
  extra: Extra = {},
): Promise<{ userId: string; left: PanelRole[] }> {
  const user = await userOf(tx, who);
  if (by.via === 'panel') {
    if (user.id === by.actorUserId && role === 'OWNER') {
      throw new AdminRoleError('You cannot take OWNER from your own account.');
    }
    if (role === 'OWNER') {
      // The panel never leaves the team without an OWNER (the CLI can, on the server).
      const owners = await tx.userAdminPermission.count({
        where: { permission: 'OWNER', user: { status: 'ACTIVE', role: 'ADMIN' } },
      });
      if (owners <= 1) throw new AdminRoleError('This is the last OWNER.');
    }
  }
  const before = await panelRolesIn(tx, user.id);
  if (!(await setRoleRow(tx, user.id, role, false, by))) {
    throw new AdminRoleError(`The account does not hold ${role}.`);
  }
  const left = before.filter((r) => r !== role);
  if (left.length === 0) {
    await tx.adminSession.updateMany({
      where: { userId: user.id, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.ADMIN_ROLE_REVOKE,
      targetType: 'user',
      targetId: user.id,
      metadata: { role, left, before, ...extra, via: by.via },
    },
  });
  return { userId: user.id, left };
}

/** A lost authenticator: the secret, recovery codes and lock go, every panel session ends; the next sign-in enrols again. */
export async function resetSecondFactorIn(
  tx: Tx,
  who: string,
  by: AdminVia = CLI_VIA,
  extra: Extra = {},
): Promise<{ userId: string }> {
  const user = await userOf(tx, who);
  if (by.via === 'panel' && user.id === by.actorUserId) {
    throw new AdminRoleError('You cannot reset your own authenticator here.');
  }
  await tx.adminCredential.deleteMany({ where: { userId: user.id } });
  await tx.adminRecoveryCode.deleteMany({ where: { userId: user.id } });
  await tx.adminSession.updateMany({
    where: { userId: user.id, revokedAt: null },
    data: { revokedAt: new Date() },
  });
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.ADMIN_TOTP_RESET,
      targetType: 'user',
      targetId: user.id,
      metadata: { ...extra, via: by.via },
    },
  });
  return { userId: user.id };
}

export async function listPanelAdmins(tx: Tx) {
  const rows = await tx.userAdminPermission.findMany({
    where: { permission: { in: [...PANEL_ROLES] } },
    orderBy: [{ grantedAt: 'asc' }],
    select: {
      permission: true,
      grantedAt: true,
      user: {
        select: {
          id: true,
          email: true,
          role: true,
          status: true,
          adminCredential: { select: { totpEnrolledAt: true, lockedUntil: true } },
        },
      },
    },
  });
  const byUser = new Map<
    string,
    {
      userId: string;
      email: string;
      role: string;
      status: string;
      roles: string[];
      enrolled: boolean;
      lockedUntil: Date | null;
    }
  >();
  for (const r of rows) {
    const entry = byUser.get(r.user.id) ?? {
      userId: r.user.id,
      email: r.user.email,
      role: r.user.role,
      status: r.user.status,
      roles: [],
      enrolled:
        r.user.adminCredential?.totpEnrolledAt !== null &&
        r.user.adminCredential?.totpEnrolledAt !== undefined,
      lockedUntil: r.user.adminCredential?.lockedUntil ?? null,
    };
    entry.roles.push(r.permission === 'MODERATION' ? 'MODERATOR' : r.permission);
    byUser.set(r.user.id, entry);
  }
  return [...byUser.values()];
}
