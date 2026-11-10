import type { ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { describe, expect, it, vi } from 'vitest';
import { AppException } from '../../common/errors/app-exception.js';
import {
  assertNotStaffTarget,
  refuseWatchStaff,
  revokeStaffGrantsIn,
  staffRolesOf,
  watchStaffAmong,
} from '../live/live-staff.js';
import { LiveStaffAlertsService } from '../live/live-staff-alerts.service.js';
import { notificationBody } from '../push/push-texts.js';
import { NotStaffWork, StaffAppGuard, StaffCapability } from './staff-app.guard.js';
import { effectiveCapabilities } from './admin-permissions.js';

/** v1.68-live (D273, §10.96.6–§10.96.8): «فريق كابسو» from the app — the pure and mocked parts. */

const USER = '0190d8a8-0000-7000-8000-000000000001';
const SESSION = '0190d8a8-0000-7000-8000-0000000000aa';

function codeOf(err: unknown): string {
  return err instanceof AppException ? err.code : String(err);
}

async function rejection(p: Promise<unknown>): Promise<unknown> {
  try {
    await p;
  } catch (err) {
    return err;
  }
  throw new Error('expected a rejection');
}

describe('D273 / D286 the staff guard (role and capability on every request; no step-up; staff work)', () => {
  class Handler {
    @StaffCapability('lives.moderate')
    moderate() {}
    @StaffCapability('lives.reports')
    reports() {}
    @StaffCapability('lives.watch')
    lives() {}
    @StaffCapability('lives.watch')
    @NotStaffWork()
    shift() {}
    nothing() {}
  }
  const ctxFor = (handler: keyof Handler, req: object) =>
    ({
      switchToHttp: () => ({ getRequest: () => req }),
      getHandler: () => Handler.prototype[handler],
      getClass: () => Handler,
    }) as unknown as ExecutionContext;
  const guard = (roles: string[]) => {
    const auth = {
      requireOn: vi.fn(),
      rolesOf: vi.fn(async () => roles),
      // D360: the guard reads the roles and their capabilities (the WhatsApp ones from the level; none set here).
      accessOf: vi.fn(async () => ({ roles, capabilities: effectiveCapabilities(roles, null) })),
    };
    const assignments = { staffWorkBestEffort: vi.fn(async () => undefined) };
    return {
      guard: new StaffAppGuard(new Reflector(), auth as never, assignments as never),
      assignments,
    };
  };
  const req = () => ({ auth: { userId: USER, sessionId: SESSION }, headers: {}, ip: '203.0.113.9' });

  it('lets MODERATION act with no code at all; the context says via app and carries the app session', async () => {
    const { guard: g, assignments } = guard(['MODERATION']);
    const r = req();
    expect(await g.canActivate(ctxFor('moderate', r))).toBe(true);
    expect((r as { staff?: { via: string; roles: string[]; sessionId: string } }).staff).toMatchObject({
      via: 'app',
      roles: ['MODERATION'],
      userId: USER,
      sessionId: SESSION,
    });
    expect(assignments.staffWorkBestEffort).toHaveBeenCalledWith(
      USER,
      'staff_tool',
      'app',
      expect.objectContaining({ ip: expect.any(String) }),
    );
  });

  it('«بثوثي» is staff work (my_lives); reading or switching the shift is not', async () => {
    const a = guard(['SUPPORT']);
    expect(await a.guard.canActivate(ctxFor('lives', req()))).toBe(true);
    expect(a.assignments.staffWorkBestEffort).toHaveBeenCalledWith(
      USER,
      'my_lives',
      'app',
      expect.anything(),
    );
    const b = guard(['SUPPORT']);
    expect(await b.guard.canActivate(ctxFor('shift', req()))).toBe(true);
    expect(b.assignments.staffWorkBestEffort).not.toHaveBeenCalled();
  });

  it('SUPPORT reads but may not act; FINANCE, BD and a plain account get nothing; no capability → refused', async () => {
    expect(await guard(['SUPPORT']).guard.canActivate(ctxFor('reports', req()))).toBe(true);
    const support = guard(['SUPPORT']);
    expect(codeOf(await rejection(support.guard.canActivate(ctxFor('moderate', req()))))).toBe(
      'AUTH_FORBIDDEN',
    );
    expect(support.assignments.staffWorkBestEffort).not.toHaveBeenCalled();
    expect(codeOf(await rejection(guard(['FINANCE']).guard.canActivate(ctxFor('reports', req()))))).toBe(
      'AUTH_FORBIDDEN',
    );
    expect(codeOf(await rejection(guard(['BD']).guard.canActivate(ctxFor('lives', req()))))).toBe(
      'AUTH_FORBIDDEN',
    );
    expect(codeOf(await rejection(guard([]).guard.canActivate(ctxFor('reports', req()))))).toBe(
      'AUTH_FORBIDDEN',
    );
    expect(codeOf(await rejection(guard(['OWNER']).guard.canActivate(ctxFor('nothing', req()))))).toBe(
      'AUTH_FORBIDDEN',
    );
  });

  it('without a session → 401', async () => {
    expect(
      codeOf(await rejection(guard(['OWNER']).guard.canActivate(ctxFor('moderate', { headers: {} })))),
    ).toBe('AUTH_UNAUTHENTICATED');
  });
});

describe('D273 who is «فريق كابسو»', () => {
  it('reads the roles held now (an ACTIVE ADMIN account only)', async () => {
    const db = (u: object | null) => ({ user: { findUnique: vi.fn(async () => u) } }) as never;
    expect(
      await staffRolesOf(
        db({ role: 'ADMIN', status: 'ACTIVE', adminPermissions: [{ permission: 'SUPPORT' }] }),
        USER,
      ),
    ).toEqual(['SUPPORT']);
    expect(
      await staffRolesOf(
        db({ role: 'ADMIN', status: 'SUSPENDED', adminPermissions: [{ permission: 'OWNER' }] }),
        USER,
      ),
    ).toEqual([]);
    expect(
      await staffRolesOf(
        db({ role: 'USER', status: 'ACTIVE', adminPermissions: [{ permission: 'OWNER' }] }),
        USER,
      ),
    ).toEqual([]);
    expect(await staffRolesOf(db(null), USER)).toEqual([]);
  });

  it('refuses gifts / taps for watch staff and any action against a panel account', async () => {
    const staff = { $queryRaw: vi.fn(async () => [{ id: USER, ok: true }]) } as never;
    const plain = { $queryRaw: vi.fn(async () => []) } as never;
    expect(await watchStaffAmong(plain, [])).toEqual(new Set());
    const gifts = await rejection(refuseWatchStaff(staff, USER, 'gifts'));
    expect(codeOf(gifts)).toBe('LIVE_STAFF_REFUSED');
    expect((gifts as AppException).details).toEqual([{ field: 'staff', issue: 'gifts' }]);
    await expect(refuseWatchStaff(plain, USER, 'taps')).resolves.toBeUndefined();
    expect(codeOf(await rejection(assertNotStaffTarget(staff, USER)))).toBe('STAFF_PROTECTED');
    await expect(assertNotStaffTarget(plain, USER)).resolves.toBeUndefined();
  });

  it('ends every open grant with the reason', async () => {
    const updateMany = vi.fn(async () => ({ count: 2 }));
    const now = new Date('2026-11-04T00:00:00Z');
    expect(await revokeStaffGrantsIn({ adminAppGrant: { updateMany } } as never, USER, 'LOCKED', now)).toBe(
      2,
    );
    expect(updateMany).toHaveBeenCalledWith({
      where: { userId: USER, revokedAt: null },
      data: { revokedAt: now, revokedReason: 'LOCKED' },
    });
  });
});

describe('D273 report alerts (the responsible staff member, then the actors, then the OWNERs)', () => {
  const ROOM = '0190d8a8-0000-7000-8000-0000000000b1';
  const HOST = '0190d8a8-0000-7000-8000-0000000000c1';
  const REPORTER = '0190d8a8-0000-7000-8000-0000000000c2';
  const make = (opts: {
    holder: object | null;
    afterPass?: object | null;
    actors?: string[];
    owners?: string[];
  }) => {
    let passes = 0;
    const created: { recipientId: string }[] = [];
    const audit: { metadata: object }[] = [];
    const tx = {
      $executeRaw: vi.fn(async () => 1),
      notification: {
        findFirst: vi.fn(async () => null),
        create: vi.fn(async (a: { data: { recipientId: string } }) => created.push(a.data)),
        update: vi.fn(),
      },
    };
    const prisma = {
      report: {
        findUnique: vi.fn(async () => ({
          targetType: 'LIVE_ROOM',
          targetLiveRoomId: ROOM,
          targetUserId: null,
          contextLiveRoomId: null,
          targetLiveChatMessage: null,
        })),
      },
      liveRoom: { findFirst: vi.fn(async () => ({ id: ROOM, hostUserId: HOST })) },
      liveRoomAssignment: {
        findUnique: vi.fn(async () => (passes === 0 ? opts.holder : (opts.afterPass ?? null))),
      },
      user: {
        findMany: vi.fn(async (a: { where: { adminShift?: unknown } }) =>
          (a.where.adminShift ? (opts.actors ?? []) : (opts.owners ?? [])).map((id) => ({ id })),
        ),
      },
      $transaction: vi.fn(async (fn: (t: typeof tx) => Promise<unknown>) => fn(tx)),
    };
    const assignments = { assignPending: vi.fn(async () => (passes += 1)) };
    const svc = new LiveStaffAlertsService(
      prisma as never,
      { recordIn: vi.fn(async (_t: unknown, e: { metadata: object }) => audit.push(e)) } as never,
      { now: () => new Date('2026-11-04T12:00:00Z') },
      assignments as never,
    );
    return { svc, created, audit, assignments };
  };
  const onShift = (id: string, roles = ['MODERATION']) => ({
    adminId: id,
    admin: {
      role: 'ADMIN',
      status: 'ACTIVE',
      adminShift: { onShift: true },
      adminPermissions: roles.map((permission) => ({ permission })),
    },
  });

  it('the assigned staff member on shift; no pass', async () => {
    const m = make({ holder: onShift('s1') });
    expect(await m.svc.onReport('r', REPORTER)).toEqual({
      roomId: ROOM,
      route: 'assigned',
      recipients: ['s1'],
    });
    expect(m.assignments.assignPending).not.toHaveBeenCalled();
    expect(m.created.map((c) => c.recipientId)).toEqual(['s1']);
    expect(m.audit[0]!.metadata).toMatchObject({ route: 'assigned', recipients: ['s1'] });
  });

  it('off shift: a pass first, and its result decides', async () => {
    const m = make({
      holder: { ...onShift('s1'), admin: { ...onShift('s1').admin, adminShift: { onShift: false } } },
      afterPass: onShift('s2', ['OWNER']),
    });
    expect((await m.svc.onReport('r', REPORTER))!.recipients).toEqual(['s2']);
    expect(m.assignments.assignPending).toHaveBeenCalledWith('reported');
  });

  it('nobody assigned: the actors on shift, else the OWNERs — never the reporter or the host', async () => {
    const a = make({ holder: null, actors: ['m1', 'm2', REPORTER] });
    expect(await a.svc.onReport('r', REPORTER)).toMatchObject({ route: 'actors', recipients: ['m1', 'm2'] });
    const o = make({ holder: null, actors: [], owners: ['o1', HOST] });
    expect(await o.svc.onReport('r', REPORTER)).toMatchObject({ route: 'owners', recipients: ['o1'] });
  });

  it('the push names the host only', () => {
    const base = {
      type: 'LIVE_STAFF_REPORT',
      actorName: null,
      actorCount: 0,
      targetType: 'LIVE_ROOM',
      targetId: ROOM,
    };
    expect(notificationBody({ ...base, targetText: 'Sara' }, 'ar')).toBe('بلاغ جديد على بث Sara');
    expect(notificationBody({ ...base, targetText: 'Sara' }, 'en')).toBe("New report on Sara's live");
    expect(notificationBody({ ...base, targetText: null }, 'en')).toBe('New report on a live');
    expect(
      notificationBody(
        {
          ...base,
          type: 'LIVE_MODERATED',
          targetType: 'LIVE_MODERATION',
          targetText: 'Language',
          moderation: 'WARN',
        },
        'en',
      ),
    ).toBe('A warning from the Kabso team on your live: Language');
  });
});
