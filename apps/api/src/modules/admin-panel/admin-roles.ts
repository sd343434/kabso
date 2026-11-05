import { auditBy, CLI_VIA, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { activeRestrictionOf } from '../users/account-control.js';
import { CAPABILITIES, PANEL_ROLES, type PanelRole } from './admin-permissions.js';
import { revokeStaffGrantsIn } from '../live/live-staff.js';
import { syncTeamAvatarsIn } from '../live/staff-avatar.js';

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
 *
 * v1.66-live (D271, CONVENTIONS §10.96.5): «الموظفون والصلاحيات» — the account is found by email, id or username
 * (`@name`); a locked account (D208) is refused like a banned one; the last-OWNER check (panel and CLI) is serialized (an
 * advisory lock) and counts the OWNERs who can still sign in other than the target; losing every watch role ends the person's
 * shift «في المناوبة» (D260). Each refusal carries a machine-readable `issue` the panel words itself.
 */
export class AdminRoleError extends Error {
  constructor(
    message: string,
    /** `team_*` (ADMIN_ACTION_REFUSED `details[0].issue`); none for the CLI-only argument errors. */
    readonly issue?: string,
  ) {
    super(message);
  }
}

/** The panel roles that watch lives and have a shift (D260's `WATCH_ROLES`: the `lives.watch` capability). */
const SHIFT_ROLES: readonly string[] = CAPABILITIES['lives.watch'];

export function parseRole(raw: string): PanelRole {
  const v = raw.trim().toUpperCase();
  const role = v === 'MODERATOR' ? 'MODERATION' : v;
  if (!(PANEL_ROLES as readonly string[]).includes(role)) {
    throw new AdminRoleError(`Unknown role ${raw}: one of OWNER, MODERATOR, SUPPORT, FINANCE.`);
  }
  return role as PanelRole;
}

/**
 * The account by id (the panel's paths), email or username (`@name` or `name`; D271), its row locked FOR NO KEY UPDATE
 * (serializes with a ban's FOR UPDATE, never with a foreign key's KEY SHARE such as an audit row's actor).
 */
async function userOf(tx: Tx, who: string) {
  const value = who.trim();
  let id: string | null = null;
  if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)) id = value.toLowerCase();
  else if (/^[^@\s]+@[^@\s]+$/.test(value)) {
    id =
      (await tx.user.findUnique({ where: { email: value.toLowerCase() }, select: { id: true } }))?.id ?? null;
  } else if (value.length > 0) {
    const username = value.replace(/^@/, '').toLowerCase();
    id = (await tx.userProfile.findUnique({ where: { username }, select: { userId: true } }))?.userId ?? null;
  }
  const [user] = id
    ? await tx.$queryRaw<{ id: string; role: string; status: string }[]>`
        SELECT id::text AS id, role::text AS role, status::text AS status FROM users WHERE id = ${id}::uuid FOR NO KEY UPDATE`
    : [];
  if (!user) throw new AdminRoleError(`No account ${who}.`, 'team_no_account');
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
  if (user.status !== 'ACTIVE') throw new AdminRoleError(`The account is ${user.status}.`, 'team_not_active');
  const lock = await activeRestrictionOf(tx, user.id, 'LOCK');
  if (lock) {
    throw new AdminRoleError(`The account is locked until ${lock.endsAt.toISOString()}.`, 'team_locked');
  }
  const madeAdmin = user.role !== 'ADMIN';
  if (madeAdmin) await tx.user.update({ where: { id: user.id }, data: { role: 'ADMIN' } });
  const already = !(await setRoleRow(tx, user.id, role, true, by));
  // v1.71-live (D283, §10.96.10): a limited staff account wears the fixed team picture (an OWNER grant gives the
  // person's own photo back).
  await syncTeamAvatarsIn(tx, user.id);
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
): Promise<{ userId: string; left: PanelRole[]; shiftEnded: boolean; watchLost: boolean }> {
  const ownerCheck = role === 'OWNER';
  // Neither the panel nor the CLI (owner 2026-11-04, D271) leaves the team without an OWNER who can sign in. One such
  // check at a time — taken before any row lock, so two OWNERs revoking each other at once queue instead of
  // deadlocking — and the second one counts after the first committed.
  if (ownerCheck) await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:admin-owner'))`;
  const user = await userOf(tx, who);
  if (by.via === 'panel' && user.id === by.actorUserId && role === 'OWNER') {
    throw new AdminRoleError('You cannot take OWNER from your own account.', 'team_self_owner');
  }
  if (ownerCheck) {
    const others = await tx.userAdminPermission.count({
      where: { permission: 'OWNER', userId: { not: user.id }, user: { status: 'ACTIVE', role: 'ADMIN' } },
    });
    if (others === 0 && user.status === 'ACTIVE' && user.role === 'ADMIN') {
      throw new AdminRoleError(
        'This is the last OWNER: grant OWNER to another active account first, then revoke this one.',
        'team_last_owner',
      );
    }
  }
  const before = await panelRolesIn(tx, user.id);
  if (!(await setRoleRow(tx, user.id, role, false, by))) {
    throw new AdminRoleError(`The account does not hold ${role}.`, 'team_not_held');
  }
  const left = before.filter((r) => r !== role);
  // v1.71-live (D283): no limited role left → the person's own photo again.
  await syncTeamAvatarsIn(tx, user.id);
  if (left.length === 0) {
    await tx.adminSession.updateMany({
      where: { userId: user.id, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }
  // D271: no watch role left → the shift ends (the next assignment pass hands their lives on, §10.96.2).
  const shiftEnded =
    !left.some((r) => SHIFT_ROLES.includes(r)) &&
    (
      await tx.adminShift.updateMany({
        where: { userId: user.id, onShift: true },
        data: { onShift: false, since: new Date() },
      })
    ).count > 0;
  // v1.68-live (D273, §10.96.6): any revoked role ends the staff tools' step-up in the app (a new code is needed).
  const appGrantsEnded = await revokeStaffGrantsIn(tx, user.id, 'ROLE_REVOKED');
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.ADMIN_ROLE_REVOKE,
      targetType: 'user',
      targetId: user.id,
      metadata: {
        role,
        left,
        before,
        ...(shiftEnded ? { shiftEnded } : {}),
        ...(appGrantsEnded > 0 ? { appGrantsEnded } : {}),
        ...extra,
        via: by.via,
      },
    },
  });
  return { userId: user.id, left, shiftEnded, watchLost: !left.some((r) => SHIFT_ROLES.includes(r)) };
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
    throw new AdminRoleError('You cannot reset your own authenticator here.', 'team_self_reset');
  }
  await tx.adminCredential.deleteMany({ where: { userId: user.id } });
  await tx.adminRecoveryCode.deleteMany({ where: { userId: user.id } });
  // v1.68-live (D273): the staff tools' step-up in the app ends too.
  await revokeStaffGrantsIn(tx, user.id, 'TOTP_RESET');
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
