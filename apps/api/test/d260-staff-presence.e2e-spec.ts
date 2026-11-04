/**
 * D260 (owner 2026-11-04, «حسابات موظفين تدخل البثوث لمراقبتها»; answers: visible with a «فريق كابسو» badge, every new
 * live assigned automatically, real employee accounts; contract v1.64-live, CONVENTIONS §10.96): staff presence in
 * lives, end to end against PostgreSQL + Redis with the in-memory media server:
 *
 *  - the shift «في المناوبة» (lives.watch; FINANCE refused; audited on/off; OWNER's list with each one's load);
 *  - every live assigned to a staff member on shift, spread by load; reported lives first and moved to someone who may
 *    act (OWNER / MODERATION) instead of SUPPORT; going off shift hands one's lives to the others; nobody on shift →
 *    unassigned; «بثوثي» (`listAdminLives?assigned=me`); each assignment audited `admin.live.assign`;
 *  - the VISIBLE watch (`team:` — not hidden, listed in `LiveViewerPage.staff`, never a viewer row, never counted, no
 *    join line; leave / reconcile / room end remove it; a join to an ended room is kicked); HIDDEN needs
 *    `lives.watch.hidden` (SUPPORT 403); the audit's `visibility`.
 */
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { LiveMediaService } from '../src/modules/live/live-media.service.js';
import { LiveStaffAssignmentService } from '../src/modules/live/live-staff-assignment.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, newUser, withMigrationClient, type TestContext } from './helpers/test-app.js';

const COOKIE = '__Host-kabso_admin';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly password: string;
  readonly displayName: string;
  token: string;
}
interface Admin extends TestUser {
  cookie: string;
  csrf: string;
}

const D260_OPS = [
  'getAdminMyShift GET /api/v1/admin/me/shift',
  'setAdminMyShift PUT /api/v1/admin/me/shift',
  'listAdminShifts GET /api/v1/admin/shifts',
];

describe('D260 contract coverage', () => {
  it('openapi v1.64-live declares the shift routes behind the admin session (CSRF on writes)', () => {
    const ops = operations();
    const ids = ops.map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(expect.arrayContaining(D260_OPS));
    for (const o of ops.filter((x) => D260_OPS.some((d) => d.startsWith(`${x.operationId} `)))) {
      expect(o.spec.security).toEqual([{ adminSession: [] }]);
      if (o.method !== 'get') expect(JSON.stringify(o.spec.parameters)).toContain('AdminCsrf');
    }
  });
});

describe('D260 staff presence in lives', { timeout: 900_000 }, () => {
  let ctx: TestContext;
  let media: MemoryLiveMedia;
  let clock = Date.now();
  const advance = (ms: number) => {
    clock += ms;
    vi.setSystemTime(clock);
  };
  let ipCounter = 60;
  const nextIp = () => {
    ipCounter += 1;
    return `198.51.${Math.floor(ipCounter / 250)}.${(ipCounter % 250) + 1}`;
  };
  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });

  const signup = async (): Promise<TestUser> => {
    const payload = newUser();
    const email = String(payload.email).trim().toLowerCase();
    const before = ctx.mail.sent.length;
    const ip = nextIp();
    const res = await ctx.http.post('/api/v1/auth/register').set('X-Forwarded-For', ip).send(payload);
    expect(res.status, JSON.stringify(res.body)).toBe(202);
    const mail = await ctx.mail.waitFor(email, 'code', before);
    const ok = await ctx.http
      .post('/api/v1/auth/register/verify')
      .set('X-Forwarded-For', ip)
      .send({ email, code: mail.code });
    expect(ok.status, JSON.stringify(ok.body)).toBe(201);
    return {
      id: ok.body.user.id as string,
      username: ok.body.user.username as string,
      displayName: ok.body.user.displayName as string,
      email,
      password: String(payload.password),
      token: ok.body.tokens.accessToken as string,
    };
  };
  const host = async () => {
    const u = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  const goLive = async (u: TestUser) => {
    advance(1000);
    const res = await ctx.http.post('/api/v1/live/rooms').set(auth(u)).send({ title: 'On air' });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const hook = (event: string, room: string, identity?: string) => {
    const raw = JSON.stringify({
      event,
      room: { name: room },
      ...(identity ? { participant: { identity } } : {}),
    });
    return ctx.http
      .post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
  };

  const cookieOf = (res: request.Response): string => {
    const raw = ([] as string[]).concat(res.headers['set-cookie'] ?? []);
    const line = raw.find((c) => c.startsWith(`${COOKIE}=`));
    if (!line) throw new Error(`no session cookie in ${JSON.stringify(raw)}`);
    return line.split(';')[0]!;
  };
  const makeAdmin = async (roles: string[]): Promise<Admin> => {
    const p = await signup();
    await withMigrationClient(async (db) => {
      for (const role of roles) await db.$transaction((tx) => grantRoleIn(tx, p.email, role as never));
    });
    const res = await ctx.http
      .post('/api/v1/admin/auth/login')
      .send({ email: p.email, password: p.password });
    const pending = cookieOf(res);
    const csrf = res.body.csrfToken as string;
    const enrol = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf);
    advance(30_000);
    const confirm = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment/confirm')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf)
      .send({ code: totpCode(enrol.body.secret as string, clock) });
    expect(confirm.status, JSON.stringify(confirm.body)).toBe(200);
    return { ...p, cookie: cookieOf(confirm), csrf: confirm.body.session.csrfToken as string };
  };
  const aget = (a: Admin, path: string) => ctx.http.get(`/api/v1${path}`).set('Cookie', a.cookie);
  const asend = (a: Admin, method: 'post' | 'put', path: string, body: object = {}) =>
    ctx.http[method](`/api/v1${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf).send(body);
  const shift = async (a: Admin, onShift: boolean) => {
    const res = await asend(a, 'put', '/admin/me/shift', { onShift });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'setAdminMyShift');
    expect(res.body.onShift).toBe(onShift);
    return res.body as { onShift: boolean; since: string | null; assignedLives: number };
  };
  const audits = (action: string, targetId?: string) =>
    ctx.prisma.auditLog.findMany({
      where: { action, ...(targetId ? { targetId } : {}) },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    });
  const assignee = async (roomId: string) =>
    (await ctx.prisma.liveRoomAssignment.findUnique({ where: { roomId } }))?.adminId ?? null;
  /** The pass after a go-live runs in the background: wait for it. */
  const assignedSoon = async (roomId: string) => {
    for (let i = 0; i < 200; i += 1) {
      const a = await assignee(roomId);
      if (a !== null) return a;
      await new Promise((r) => setTimeout(r, 10));
    }
    return null;
  };
  const loads = async (ids: string[]) => {
    const rows = await ctx.prisma.liveRoomAssignment.groupBy({
      by: ['adminId'],
      where: { adminId: { in: ids }, room: { status: 'LIVE' } },
      _count: { _all: true },
    });
    return Object.fromEntries(ids.map((id) => [id, rows.find((r) => r.adminId === id)?._count._all ?? 0]));
  };
  const endAllLives = () =>
    withMigrationClient(async (db) => {
      await db.$executeRawUnsafe(
        `UPDATE live_rooms SET status = 'ENDED', end_reason = 'HOST_ENDED', ended_at = last_heartbeat_at WHERE status = 'LIVE'`,
      );
      await db.$executeRawUnsafe(`DELETE FROM live_room_assignments`);
      await db.$executeRawUnsafe(`UPDATE admin_shifts SET on_shift = false`);
    });
  const endLive = async (u: TestUser, roomId: string) => {
    const res = await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
  };

  let owner: Admin;
  let mod1: Admin;
  let mod2: Admin;
  let support: Admin;
  let finance: Admin;

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: clock });
    media = new MemoryLiveMedia();
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        TRUST_PROXY: 'loopback',
        ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
        JWT_ACCESS_TTL_SECONDS: String(60 * 86_400),
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        ADMIN_SESSION_MAX_SECONDS: '604800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '100000/900',
      },
      [{ token: LIVE_MEDIA_PROVIDER, value: media }],
    );
    ctx.app.getHttpServer().setMaxListeners(64);
    owner = await makeAdmin(['OWNER']);
    mod1 = await makeAdmin(['MODERATION']);
    mod2 = await makeAdmin(['MODERATION']);
    support = await makeAdmin(['SUPPORT']);
    finance = await makeAdmin(['FINANCE']);
    await endAllLives();
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('the shift: watch staff only, idempotent, audited; nobody on shift leaves a live unassigned', async () => {
    expect((await aget(finance, '/admin/me/shift')).status).toBe(403);
    expect((await asend(finance, 'put', '/admin/me/shift', { onShift: true })).status).toBe(403);
    expect((await aget(mod1, '/admin/shifts')).status).toBe(403);
    const mine = await aget(support, '/admin/me/shift');
    expect(mine.status, JSON.stringify(mine.body)).toBe(200);
    expectContract(mine, 'getAdminMyShift');
    expect(mine.body).toEqual({ onShift: false, since: null, assignedLives: 0 });
    const bad = await asend(support, 'put', '/admin/me/shift', { onShift: 'yes' });
    expect(bad.status).toBe(400);

    const h = await host();
    const roomId = await goLive(h);
    await new Promise((r) => setTimeout(r, 100));
    expect(await assignee(roomId)).toBeNull();
    const list = await aget(owner, '/admin/shifts');
    expect(list.status, JSON.stringify(list.body)).toBe(200);
    expectContract(list, 'listAdminShifts');
    expect(list.body.onShift).toBe(0);
    expect(list.body.unassignedLives).toBe(1);
    const ids = (list.body.data as { user: { id: string } }[]).map((d) => d.user.id);
    expect(ids).toEqual(expect.arrayContaining([owner.id, mod1.id, mod2.id, support.id]));
    expect(ids).not.toContain(finance.id);

    // Going on shift takes the waiting live; a repeat changes nothing (one audit row).
    const on = await shift(mod1, true);
    expect(on.assignedLives).toBe(1);
    await shift(mod1, true);
    expect(await assignee(roomId)).toBe(mod1.id);
    const ons = (await audits('admin.shift.on')).filter((r) => r.actorUserId === mod1.id);
    expect(ons).toHaveLength(1);
    expect(ons[0]!.metadata).toMatchObject({ assigned: 1, via: 'panel' });
    const assigned = await audits('admin.live.assign', roomId);
    expect(assigned).toHaveLength(1);
    expect(assigned[0]!.actorUserId).toBeNull();
    expect(assigned[0]!.metadata).toMatchObject({ adminId: mod1.id, reason: 'shift_on', reports: 0 });
    await endLive(h, roomId);
  });

  it('every new live goes to the least-loaded staff member on shift (an even spread), never to its own host', async () => {
    await endAllLives();
    await shift(mod1, true);
    await shift(mod2, true);
    await shift(support, true);
    const staff = [mod1.id, mod2.id, support.id];
    const rooms: string[] = [];
    for (let i = 0; i < 6; i += 1) {
      const roomId = await goLive(await host());
      rooms.push(roomId);
      expect(await assignedSoon(roomId)).not.toBeNull();
    }
    expect(await loads(staff)).toEqual({ [mod1.id]: 2, [mod2.id]: 2, [support.id]: 2 });
    // Round robin: the first three went to three different people.
    expect(new Set(await Promise.all(rooms.slice(0, 3).map(assignee))).size).toBe(3);
    const rows = await audits('admin.live.assign');
    for (const roomId of rooms) {
      const row = rows.find((r) => r.targetId === roomId)!;
      expect(row.metadata).toMatchObject({ reason: 'live_start', reports: 0 });
    }
    // A staff member who goes live is never assigned their own live.
    const self = await makeAdmin(['MODERATION']);
    await ctx.prisma.liveHost.create({ data: { userId: self.id, source: 'ADMIN' } });
    await shift(self, true);
    const own = await goLive(self);
    const got = await assignedSoon(own);
    expect(got).not.toBeNull();
    expect(got).not.toBe(self.id);
    await shift(self, false);

    // «بثوثي»: only one's own lives, with who watches each.
    const my = await aget(mod1, '/admin/lives?assigned=me');
    expect(my.status, JSON.stringify(my.body)).toBe(200);
    expectContract(my, 'listAdminLives');
    const myRows = my.body.data as { id: string; assignedTo: { id: string; displayName: string } }[];
    expect(myRows.length).toBe((await loads([mod1.id]))[mod1.id]);
    for (const r of myRows) expect(r.assignedTo).toEqual({ id: mod1.id, displayName: mod1.displayName });
    const all = await aget(owner, '/admin/lives');
    expect((all.body.data as { assignedTo: unknown }[]).every((r) => r.assignedTo !== null)).toBe(true);
    expect((await aget(mod1, '/admin/lives?assigned=all')).status).toBe(400);
    const me = await aget(mod1, '/admin/me/shift');
    expect(me.body.assignedLives).toBe(myRows.length);
  });

  it('reported lives first, and to someone who may act on them (not SUPPORT)', async () => {
    await endAllLives();
    // Nobody on shift: an older live and a newer reported one wait.
    const older = await goLive(await host());
    const newer = await goLive(await host());
    const reporter = await signup();
    const rep = await ctx.http
      .post('/api/v1/reports')
      .set(auth(reporter))
      .send({ targetType: 'LIVE_ROOM', targetId: newer, reason: 'HARASSMENT' });
    expect(rep.status, JSON.stringify(rep.body)).toBe(201);
    await shift(mod1, true);
    const a = await ctx.prisma.liveRoomAssignment.findUniqueOrThrow({ where: { roomId: older } });
    const b = await ctx.prisma.liveRoomAssignment.findUniqueOrThrow({ where: { roomId: newer } });
    // The reported live was assigned first in the pass.
    expect(b.assignedAt.getTime()).toBeLessThan(a.assignedAt.getTime());
    expect((await audits('admin.live.assign', newer))[0]!.metadata).toMatchObject({ reports: 1 });

    // SUPPORT gets a new live (least loaded); once it is reported, the sweep moves it to a moderator.
    await shift(support, true);
    const third = await goLive(await host());
    expect(await assignedSoon(third)).toBe(support.id);
    const rep2 = await ctx.http
      .post('/api/v1/reports')
      .set(auth(reporter))
      .send({ targetType: 'LIVE_ROOM', targetId: third, reason: 'SPAM' });
    expect(rep2.status, JSON.stringify(rep2.body)).toBe(201);
    const pass = await ctx.app.get(LiveStaffAssignmentService).assignPending('sweep');
    expect(pass.assigned).toEqual([
      { roomId: third, adminId: mod1.id, previousAdminId: support.id, reports: 1 },
    ]);
    expect(await assignee(third)).toBe(mod1.id);
    const moved = (await audits('admin.live.assign', third)).at(-1)!;
    expect(moved.metadata).toMatchObject({
      adminId: mod1.id,
      reason: 'reported',
      previousAdminId: support.id,
    });
    // With no moderator on shift, a reported live still goes to SUPPORT (watched rather than not at all).
    await shift(mod1, false);
    for (const id of [older, newer, third]) expect(await assignee(id)).toBe(support.id);
  });

  it('going off shift hands one’s lives to the others; nobody left → unassigned; ended lives are released', async () => {
    await endAllLives();
    await shift(mod1, true);
    const hosts = [await host(), await host(), await host()];
    const rooms: string[] = [];
    for (const h of hosts) {
      const id = await goLive(h);
      rooms.push(id);
      expect(await assignedSoon(id)).toBe(mod1.id);
    }
    await shift(mod2, true);
    const off = await shift(mod1, false);
    expect(off.assignedLives).toBe(0);
    for (const id of rooms) expect(await assignee(id)).toBe(mod2.id);
    const offRows = (await audits('admin.shift.off')).filter((r) => r.actorUserId === mod1.id);
    expect(offRows.at(-1)!.metadata).toMatchObject({ released: 3, via: 'panel' });
    expect((await audits('admin.live.assign', rooms[0])).at(-1)!.metadata).toMatchObject({
      adminId: mod2.id,
      reason: 'shift_off',
    });
    // A live that ends is released by the next pass.
    await endLive(hosts[0]!, rooms[0]!);
    const pass = await ctx.app.get(LiveStaffAssignmentService).assignPending('sweep');
    expect(pass.released).toBe(1);
    expect(await assignee(rooms[0]!)).toBeNull();
    // A demoted staff member's lives are handed on too.
    await shift(mod1, true);
    await withMigrationClient((db) =>
      db.userAdminPermission.deleteMany({ where: { userId: mod2.id, permission: 'MODERATION' } }),
    );
    await ctx.app.get(LiveStaffAssignmentService).assignPending('sweep');
    for (const id of rooms.slice(1)) expect(await assignee(id)).toBe(mod1.id);
    await withMigrationClient((db) =>
      db.$transaction((tx) => grantRoleIn(tx, mod2.email, 'MODERATION')),
    );
    // Nobody on shift: the lives wait.
    await shift(mod2, false);
    await shift(mod1, false);
    for (const id of rooms.slice(1)) expect(await assignee(id)).toBeNull();
    const list = await aget(owner, '/admin/shifts');
    expect(list.body.unassignedLives).toBe(2);
  });

  it('the visible watch: «فريق كابسو» in the viewer list, never a viewer or counted; hidden needs lives.watch.hidden', async () => {
    await endAllLives();
    const h = await host();
    const roomId = await goLive(h);
    const viewer = await signup();
    expect((await hook('participant_joined', roomId, viewer.id)).status).toBe(200);
    expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).viewerCount).toBe(1);

    // A WATCH is VISIBLE by default.
    const res = await asend(mod1, 'post', `/admin/lives/${roomId}/watch-token`, { purpose: 'WATCH' });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'createAdminLiveWatchToken');
    expect(res.body.visibility).toBe('VISIBLE');
    const identity = res.body.main.identity as string;
    expect(identity).toMatch(new RegExp(`^team:${mod1.id}:[0-9a-f]{12}$`));
    expect(media.issued.at(-1)).toMatchObject({ identity, publish: false, visible: true, ttlSeconds: 120 });
    const watchAudit = (await audits('admin.live.watch', roomId)).at(-1)!;
    expect(watchAudit.actorUserId).toBe(mod1.id);
    expect(watchAudit.metadata).toMatchObject({ purpose: 'WATCH', visibility: 'VISIBLE', identity });

    const broadcastsBefore = media.broadcasts.length;
    expect((await hook('participant_joined', roomId, identity)).status).toBe(200);
    expect(media.removed.some((r) => r.identity === identity)).toBe(false);
    expect(await ctx.prisma.liveRoomViewer.count({ where: { roomId, identity } })).toBe(0);
    expect(await ctx.prisma.liveRoomStaffWatcher.count({ where: { roomId, identity } })).toBe(1);
    expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).viewerCount).toBe(1);
    // No «joined» line for staff.
    expect(media.broadcasts.slice(broadcastsBefore).some((b) => b.payload.includes('"join"'))).toBe(false);
    // Listed (host and viewers), never as a viewer, and not on a later page.
    for (const who of [h, viewer]) {
      const list = await ctx.http.get(`/api/v1/live/rooms/${roomId}/viewers`).set(auth(who));
      expect(list.status, JSON.stringify(list.body)).toBe(200);
      expectContract(list, 'listLiveRoomViewers');
      expect((list.body.data as unknown[]).length).toBe(1);
      expect(list.body.staff).toHaveLength(1);
      expect(list.body.staff[0]).toMatchObject({ displayName: mod1.displayName });
      expect(Object.keys(list.body.staff[0] as object).sort()).toEqual(['avatarUrl', 'displayName', 'since']);
    }
    // A second token of the same staff member is still one entry.
    const again = await asend(mod1, 'post', `/admin/lives/${roomId}/watch-token`, {});
    const identity2 = again.body.main.identity as string;
    expect((await hook('participant_joined', roomId, identity2)).status).toBe(200);
    const listed = await ctx.http.get(`/api/v1/live/rooms/${roomId}/viewers`).set(auth(viewer));
    expect(listed.body.staff).toHaveLength(1);
    expect((await hook('participant_left', roomId, identity2)).status).toBe(200);
    expect(await ctx.prisma.liveRoomStaffWatcher.count({ where: { roomId } })).toBe(1);

    // Reconciliation: kept while connected, removed once gone; the count never moves.
    media.rooms.set(roomId, new Set([viewer.id, identity]));
    await ctx.app.get(LiveMediaService).reconcile();
    expect(await ctx.prisma.liveRoomStaffWatcher.count({ where: { roomId, identity } })).toBe(1);
    expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).viewerCount).toBe(1);
    media.rooms.set(roomId, new Set([viewer.id]));
    await ctx.app.get(LiveMediaService).reconcile();
    expect(await ctx.prisma.liveRoomStaffWatcher.count({ where: { roomId } })).toBe(0);
    expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).viewerCount).toBe(1);
    // Rejoin, then leave: no longer listed.
    expect((await hook('participant_joined', roomId, identity)).status).toBe(200);
    expect((await hook('participant_left', roomId, identity)).status).toBe(200);
    const after = await ctx.http.get(`/api/v1/live/rooms/${roomId}/viewers`).set(auth(viewer));
    expect(after.body.staff).toEqual([]);
    expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).viewerCount).toBe(1);

    // HIDDEN: OWNER / MODERATION only; a PREVIEW is always hidden (SUPPORT may preview).
    const hidden = await asend(mod1, 'post', `/admin/lives/${roomId}/watch-token`, {
      purpose: 'WATCH',
      visibility: 'HIDDEN',
    });
    expect(hidden.status, JSON.stringify(hidden.body)).toBe(200);
    expect(hidden.body.visibility).toBe('HIDDEN');
    expect(hidden.body.main.identity).toMatch(new RegExp(`^staff:${mod1.id}:`));
    expect(media.issued.at(-1)!.visible).toBeUndefined();
    const bySupport = await asend(support, 'post', `/admin/lives/${roomId}/watch-token`, {
      purpose: 'WATCH',
      visibility: 'HIDDEN',
    });
    expect(bySupport.status).toBe(403);
    expect(bySupport.body.error.code).toBe('AUTH_FORBIDDEN');
    const supportVisible = await asend(support, 'post', `/admin/lives/${roomId}/watch-token`, {});
    expect(supportVisible.status).toBe(200);
    expect(supportVisible.body.main.identity).toMatch(new RegExp(`^team:${support.id}:`));
    const preview = await asend(support, 'post', `/admin/lives/${roomId}/watch-token`, {
      purpose: 'PREVIEW',
      visibility: 'VISIBLE',
    });
    expect(preview.status).toBe(200);
    expect(preview.body.visibility).toBe('HIDDEN');
    expect(preview.body.main.identity).toMatch(/^staff:/);
    expect((await asend(finance, 'post', `/admin/lives/${roomId}/watch-token`, {})).status).toBe(403);
    const invalid = await asend(mod1, 'post', `/admin/lives/${roomId}/watch-token`, { visibility: 'GHOST' });
    expect(invalid.status).toBe(400);

    // The live ends: the staff rows go with it; a late join is kicked; a forged identity is kicked.
    expect((await hook('participant_joined', roomId, identity)).status).toBe(200);
    await endLive(h, roomId);
    expect(await ctx.prisma.liveRoomStaffWatcher.count({ where: { roomId } })).toBe(0);
    expect((await hook('participant_joined', roomId, identity)).status).toBe(200);
    expect(await ctx.prisma.liveRoomStaffWatcher.count({ where: { roomId } })).toBe(0);
    expect(media.removed.some((r) => r.room === roomId && r.identity === identity)).toBe(true);
    const other = await goLive(await host());
    expect((await hook('participant_joined', other, 'team:not-a-uuid:00')).status).toBe(200);
    expect(media.removed.some((r) => r.room === other && r.identity === 'team:not-a-uuid:00')).toBe(true);
    expect(await ctx.prisma.liveRoomStaffWatcher.count({ where: { roomId: other } })).toBe(0);
  });
});
