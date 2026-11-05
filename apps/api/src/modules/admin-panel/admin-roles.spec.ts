import { describe, expect, it, vi } from 'vitest';
import type { AdminVia } from '../../common/audit/admin-actor.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { AdminRoleError, grantRoleIn, resetSecondFactorIn, revokeRoleIn } from './admin-roles.js';
import { teamGrantBody } from './admin-v2.schemas.js';

/**
 * v1.66-live (D271, CONVENTIONS §10.96.5): «الموظفون والصلاحيات» — the shared `admin-admin` rules the panel runs, on a
 * fake transaction: the account by email / username / id, banned / locked refused, never one's own or the last OWNER
 * (and a suspended OWNER does not count), the last role ends the panel sessions, no watch role left ends the shift,
 * every change audited with `via` and the reason, each refusal with its `issue`.
 */

const OWNER_ID = '11111111-1111-4111-8111-111111111111';
const TARGET_ID = '22222222-2222-4222-8222-222222222222';
const PANEL: AdminVia = { via: 'panel', actorUserId: OWNER_ID, ip: '203.0.113.9', requestId: 'r1' };

interface World {
  user: { id: string; role: string; status: string } | null;
  roles: string[];
  otherActiveOwners: number;
  locked: boolean;
  onShift: boolean;
  /** v1.73-live (D283c): the person's staff number (given by `kabso_admin_panel_role` on a grant). */
  staffNumber: number | null;
}

function fakeTx(w: World) {
  const audits: { action: string; metadata: Record<string, unknown> }[] = [];
  const raw: string[] = [];
  const sessionsEnded = vi.fn(async () => ({ count: 1 }));
  const shiftOff = vi.fn(async () => ({ count: w.onShift ? 1 : 0 }));
  const tx = {
    user: {
      findUnique: vi.fn(async () => (w.user ? { id: w.user.id } : null)),
      update: vi.fn(async () => ({})),
    },
    userProfile: { findUnique: vi.fn(async () => (w.user ? { userId: w.user.id } : null)) },
    staffId: {
      findUnique: vi.fn(async ({ where }: { where: { number?: number; userId?: string } }) => {
        if (where.number !== undefined) {
          return w.user && w.staffNumber === where.number ? { userId: w.user.id } : null;
        }
        return w.staffNumber !== null ? { number: w.staffNumber } : null;
      }),
    },
    userAdminPermission: {
      findMany: vi.fn(async () => w.roles.map((permission) => ({ permission }))),
      count: vi.fn(async () => w.otherActiveOwners),
    },
    accountRestriction: {
      findFirst: vi.fn(async () =>
        w.locked ? { id: 'l1', kind: 'LOCK', endsAt: new Date('2030-01-01T00:00:00Z') } : null,
      ),
    },
    adminSession: { updateMany: sessionsEnded },
    adminShift: { updateMany: shiftOff },
    adminCredential: { deleteMany: vi.fn(async () => ({ count: 1 })) },
    // v1.68-live (D273): a revoke / reset also ends the staff tools' step-up in the app.
    adminAppGrant: { updateMany: vi.fn(async () => ({ count: 0 })) },
    adminRecoveryCode: { deleteMany: vi.fn(async () => ({ count: 10 })) },
    auditLog: {
      create: vi.fn(async ({ data }: { data: { action: string; metadata: Record<string, unknown> } }) => {
        audits.push({ action: data.action, metadata: data.metadata });
        return {};
      }),
    },
    $queryRaw: vi.fn(async (strings: TemplateStringsArray, ...values: unknown[]) => {
      const sql = strings.join('?');
      raw.push(sql);
      if (sql.includes('FROM users')) return w.user ? [w.user] : [];
      if (sql.includes('kabso_admin_panel_role')) {
        const [, role, grant] = values as [string, string, boolean];
        const held = w.roles.includes(role);
        if (grant && !held) w.roles.push(role);
        if (grant) w.staffNumber ??= 7;
        if (!grant && held) w.roles = w.roles.filter((r) => r !== role);
        return [{ changed: grant ? !held : held }];
      }
      return [];
    }),
    $executeRaw: vi.fn(async (strings: TemplateStringsArray) => {
      raw.push(strings.join('?'));
      return 1;
    }),
  };
  return { tx: tx as unknown as Prisma.TransactionClient, audits, raw, sessionsEnded, shiftOff, mock: tx };
}

const world = (over: Partial<World> = {}): World => ({
  user: { id: TARGET_ID, role: 'ADMIN', status: 'ACTIVE' },
  roles: ['SUPPORT'],
  otherActiveOwners: 1,
  locked: false,
  onShift: false,
  staffNumber: null,
  ...over,
});

const issueOf = async (p: Promise<unknown>) => {
  try {
    await p;
  } catch (err) {
    expect(err).toBeInstanceOf(AdminRoleError);
    return (err as AdminRoleError).issue;
  }
  throw new Error('expected a refusal');
};

describe('admin roles (D271 «الموظفون والصلاحيات»)', () => {
  it('finds the account by email, @username or id', async () => {
    const byEmail = fakeTx(world({ roles: [] }));
    await grantRoleIn(byEmail.tx, 'New.Staff@Example.test', 'SUPPORT', PANEL, { reason: 'hired' });
    expect(byEmail.mock.user.findUnique).toHaveBeenCalledWith(
      expect.objectContaining({ where: { email: 'new.staff@example.test' } }),
    );
    const byName = fakeTx(world({ roles: [] }));
    await grantRoleIn(byName.tx, '@Staff_One', 'MODERATION', PANEL, { reason: 'hired' });
    expect(byName.mock.userProfile.findUnique).toHaveBeenCalledWith(
      expect.objectContaining({ where: { username: 'staff_one' } }),
    );
    const byId = fakeTx(world({ roles: [] }));
    await grantRoleIn(byId.tx, TARGET_ID, 'SUPPORT', PANEL, { reason: 'hired' });
    expect(byId.mock.user.findUnique).not.toHaveBeenCalled();
    expect(byId.mock.userProfile.findUnique).not.toHaveBeenCalled();
    // The person's row is locked for the change.
    expect(byId.raw.some((q) => q.includes('FOR NO KEY UPDATE'))).toBe(true);
    expect(await issueOf(grantRoleIn(fakeTx(world({ user: null })).tx, '@nobody', 'SUPPORT', PANEL))).toBe(
      'team_no_account',
    );
  });

  it('v1.73-live (D283c): finds a former staff member by the staff ID kept for them and gives it back', async () => {
    const f = fakeTx(world({ roles: [], staffNumber: 3 }));
    const r = await grantRoleIn(f.tx, 'kabso03', 'SUPPORT', PANEL, { reason: 'back' });
    expect(f.mock.staffId.findUnique).toHaveBeenCalledWith(expect.objectContaining({ where: { number: 3 } }));
    expect(f.mock.userProfile.findUnique).not.toHaveBeenCalled();
    expect(r.staffId).toBe('Kabso03');
    expect(f.audits[0]?.metadata).toMatchObject({ staffId: 'Kabso03' });
    // An unknown staff ID falls back to the username (and then «no account»).
    const g = fakeTx(world({ user: null, staffNumber: null }));
    expect(await issueOf(grantRoleIn(g.tx, 'Kabso99', 'SUPPORT', PANEL))).toBe('team_no_account');
    expect(g.mock.userProfile.findUnique).toHaveBeenCalledWith(
      expect.objectContaining({ where: { username: 'kabso99' } }),
    );
  });

  it('a grant: audited with via panel and the reason; makes the account an admin; banned or locked refused', async () => {
    const f = fakeTx(world({ user: { id: TARGET_ID, role: 'USER', status: 'ACTIVE' }, roles: [] }));
    const r = await grantRoleIn(f.tx, TARGET_ID, 'OWNER', PANEL, { reason: 'co-owner' });
    expect(r).toEqual({ userId: TARGET_ID, madeAdmin: true, already: false, staffId: 'Kabso07' });
    expect(f.mock.user.update).toHaveBeenCalledWith({ where: { id: TARGET_ID }, data: { role: 'ADMIN' } });
    expect(f.audits).toEqual([
      {
        action: 'admin.role.grant',
        metadata: {
          role: 'OWNER',
          madeAdmin: true,
          already: false,
          staffId: 'Kabso07',
          reason: 'co-owner',
          via: 'panel',
        },
      },
    ]);
    for (const status of ['SUSPENDED', 'PENDING_DELETION', 'DELETED']) {
      const banned = fakeTx(world({ user: { id: TARGET_ID, role: 'USER', status }, roles: [] }));
      expect(await issueOf(grantRoleIn(banned.tx, TARGET_ID, 'SUPPORT', PANEL))).toBe('team_not_active');
      expect(banned.audits).toEqual([]);
    }
    const locked = fakeTx(world({ locked: true, roles: [] }));
    expect(await issueOf(grantRoleIn(locked.tx, TARGET_ID, 'SUPPORT', PANEL))).toBe('team_locked');
    expect(locked.audits).toEqual([]);
  });

  it("never one's own OWNER, never the last active OWNER (serialized); a suspended OWNER does not count", async () => {
    const self = fakeTx(world({ user: { id: OWNER_ID, role: 'ADMIN', status: 'ACTIVE' }, roles: ['OWNER'] }));
    expect(await issueOf(revokeRoleIn(self.tx, OWNER_ID, 'OWNER', PANEL, { reason: 'x' }))).toBe(
      'team_self_owner',
    );
    const last = fakeTx(world({ roles: ['OWNER'], otherActiveOwners: 0 }));
    expect(await issueOf(revokeRoleIn(last.tx, TARGET_ID, 'OWNER', PANEL, { reason: 'x' }))).toBe(
      'team_last_owner',
    );
    // The advisory lock comes before the row lock (no deadlock between two OWNERs).
    const lockAt = last.raw.findIndex((q) => q.includes('pg_advisory_xact_lock'));
    expect(lockAt).toBeGreaterThanOrEqual(0);
    expect(lockAt).toBeLessThan(last.raw.findIndex((q) => q.includes('FOR NO KEY UPDATE')));
    expect(last.mock.userAdminPermission.count).toHaveBeenCalledWith({
      where: { permission: 'OWNER', userId: { not: TARGET_ID }, user: { status: 'ACTIVE', role: 'ADMIN' } },
    });
    expect(last.audits).toEqual([]);
    // A banned OWNER's role can go even with no other active OWNER counted (it signs nobody in).
    const banned = fakeTx(
      world({
        user: { id: TARGET_ID, role: 'ADMIN', status: 'SUSPENDED' },
        roles: ['OWNER'],
        otherActiveOwners: 0,
      }),
    );
    await expect(revokeRoleIn(banned.tx, TARGET_ID, 'OWNER', PANEL, { reason: 'x' })).resolves.toMatchObject({
      left: [],
    });
    // Another active OWNER → allowed.
    const two = fakeTx(world({ roles: ['OWNER', 'SUPPORT'], otherActiveOwners: 1 }));
    await expect(revokeRoleIn(two.tx, TARGET_ID, 'OWNER', PANEL, { reason: 'x' })).resolves.toMatchObject({
      left: ['SUPPORT'],
    });
    // The CLI too (owner 2026-11-04): the last OWNER stays; the message says to grant another OWNER first.
    const cli = fakeTx(world({ roles: ['OWNER'], otherActiveOwners: 0 }));
    await expect(revokeRoleIn(cli.tx, TARGET_ID, 'OWNER')).rejects.toThrow(
      /grant OWNER to another active account first/,
    );
    expect(cli.audits).toEqual([]);
    const cliTwo = fakeTx(world({ roles: ['OWNER'], otherActiveOwners: 1 }));
    await expect(revokeRoleIn(cliTwo.tx, TARGET_ID, 'OWNER')).resolves.toMatchObject({ left: [] });
  });

  it('the last role ends the panel sessions; no watch role left ends the shift; audited', async () => {
    const f = fakeTx(world({ roles: ['SUPPORT'], onShift: true }));
    const r = await revokeRoleIn(f.tx, TARGET_ID, 'SUPPORT', PANEL, { reason: 'left the company' });
    expect(r).toEqual({ userId: TARGET_ID, left: [], shiftEnded: true, watchLost: true });
    expect(f.sessionsEnded).toHaveBeenCalledWith({
      where: { userId: TARGET_ID, revokedAt: null },
      data: { revokedAt: expect.any(Date) },
    });
    expect(f.shiftOff).toHaveBeenCalledTimes(1);
    expect(f.audits).toEqual([
      {
        action: 'admin.role.revoke',
        metadata: {
          role: 'SUPPORT',
          left: [],
          before: ['SUPPORT'],
          shiftEnded: true,
          reason: 'left the company',
          via: 'panel',
        },
      },
    ]);
    // MODERATION → FINANCE only: sessions stay, the shift ends.
    const g = fakeTx(world({ roles: ['MODERATION', 'FINANCE'], onShift: true }));
    expect(await revokeRoleIn(g.tx, TARGET_ID, 'MODERATION', PANEL, { reason: 'x' })).toEqual({
      userId: TARGET_ID,
      left: ['FINANCE'],
      shiftEnded: true,
      watchLost: true,
    });
    expect(g.sessionsEnded).not.toHaveBeenCalled();
    // A watch role left: the shift is untouched.
    const h = fakeTx(world({ roles: ['MODERATION', 'SUPPORT'], onShift: true }));
    expect((await revokeRoleIn(h.tx, TARGET_ID, 'MODERATION', PANEL, { reason: 'x' })).shiftEnded).toBe(
      false,
    );
    expect(h.shiftOff).not.toHaveBeenCalled();
    // A role not held.
    expect(await issueOf(revokeRoleIn(fakeTx(world({ roles: [] })).tx, TARGET_ID, 'FINANCE', PANEL))).toBe(
      'team_not_held',
    );
  });

  it("a reset: never one's own; ends the sessions; audited", async () => {
    const self = fakeTx(world({ user: { id: OWNER_ID, role: 'ADMIN', status: 'ACTIVE' } }));
    expect(await issueOf(resetSecondFactorIn(self.tx, OWNER_ID, PANEL))).toBe('team_self_reset');
    const f = fakeTx(world());
    await resetSecondFactorIn(f.tx, TARGET_ID, PANEL, { reason: 'lost phone' });
    expect(f.sessionsEnded).toHaveBeenCalledTimes(1);
    expect(f.audits).toEqual([
      { action: 'admin.totp.reset', metadata: { reason: 'lost phone', via: 'panel' } },
    ]);
  });

  it('the grant body: exactly one of account and email, the code, a reason', () => {
    const base = { role: 'SUPPORT', reason: 'hired', totpCode: '123456' };
    expect(teamGrantBody.safeParse({ ...base, account: '@staff' }).success).toBe(true);
    expect(teamGrantBody.safeParse({ ...base, email: 'a@b.c' }).success).toBe(true);
    expect(teamGrantBody.safeParse({ ...base, account: '@staff', email: 'a@b.c' }).success).toBe(false);
    expect(teamGrantBody.safeParse(base).success).toBe(false);
    expect(teamGrantBody.safeParse({ ...base, account: '@staff', totpCode: undefined }).success).toBe(false);
    expect(teamGrantBody.safeParse({ ...base, account: '@staff', reason: ' ' }).success).toBe(false);
  });
});
