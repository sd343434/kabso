import { AuditAction } from '../../common/audit/audit.service.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PANEL_ROLES, type PanelRole } from './admin-permissions.js';

type Tx = Prisma.TransactionClient;

/**
 * The admin panel's roles from the command line only (v1.60-social, D191, CONVENTIONS §10.54.1): `admin-admin
 * grant|revoke|list|reset-2fa`. A grant makes the account `role = ADMIN` when it is not yet (this is how the first
 * OWNER is bootstrapped); revoking the last panel role ends the person's panel sessions. Every change is audited in
 * its transaction. Shared by the CLI and the tests (no Nest dependencies).
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

async function userByEmail(tx: Tx, email: string) {
  const user = await tx.user.findUnique({
    where: { email: email.trim().toLowerCase() },
    select: { id: true, role: true, status: true },
  });
  if (!user) throw new AdminRoleError(`No account ${email}.`);
  return user;
}

export async function grantRoleIn(
  tx: Tx,
  email: string,
  role: PanelRole,
): Promise<{ userId: string; madeAdmin: boolean }> {
  const user = await userByEmail(tx, email);
  if (user.status !== 'ACTIVE') throw new AdminRoleError(`The account is ${user.status}.`);
  const madeAdmin = user.role !== 'ADMIN';
  if (madeAdmin) await tx.user.update({ where: { id: user.id }, data: { role: 'ADMIN' } });
  const created = await tx.userAdminPermission.createMany({
    data: [{ userId: user.id, permission: role }],
    skipDuplicates: true,
  });
  await tx.auditLog.create({
    data: {
      action: AuditAction.ADMIN_ROLE_GRANT,
      targetType: 'user',
      targetId: user.id,
      metadata: { role, madeAdmin, already: created.count === 0, via: 'cli' },
    },
  });
  return { userId: user.id, madeAdmin };
}

export async function revokeRoleIn(
  tx: Tx,
  email: string,
  role: PanelRole,
): Promise<{ userId: string; left: PanelRole[] }> {
  const user = await userByEmail(tx, email);
  const done = await tx.userAdminPermission.deleteMany({ where: { userId: user.id, permission: role } });
  if (done.count === 0) throw new AdminRoleError(`The account does not hold ${role}.`);
  const left = (
    await tx.userAdminPermission.findMany({ where: { userId: user.id }, select: { permission: true } })
  )
    .map((p) => p.permission)
    .filter((p): p is PanelRole => (PANEL_ROLES as readonly string[]).includes(p));
  if (left.length === 0) {
    await tx.adminSession.updateMany({
      where: { userId: user.id, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }
  await tx.auditLog.create({
    data: {
      action: AuditAction.ADMIN_ROLE_REVOKE,
      targetType: 'user',
      targetId: user.id,
      metadata: { role, left, via: 'cli' },
    },
  });
  return { userId: user.id, left };
}

/** A lost authenticator: the secret, recovery codes and lock go, every panel session ends; the next sign-in enrols again. */
export async function resetSecondFactorIn(tx: Tx, email: string): Promise<{ userId: string }> {
  const user = await userByEmail(tx, email);
  await tx.adminCredential.deleteMany({ where: { userId: user.id } });
  await tx.adminRecoveryCode.deleteMany({ where: { userId: user.id } });
  await tx.adminSession.updateMany({
    where: { userId: user.id, revokedAt: null },
    data: { revokedAt: new Date() },
  });
  await tx.auditLog.create({
    data: {
      action: AuditAction.ADMIN_TOTP_RESET,
      targetType: 'user',
      targetId: user.id,
      metadata: { via: 'cli' },
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
