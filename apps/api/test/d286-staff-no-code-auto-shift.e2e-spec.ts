/**
 * D286 (owner 2026-11-05: «لاحظت ان كل ما اراد المشرف عمل شيء قام بإدخال رمز تحقق ثنائي من جوجل، ازله لتسهيل العملية.
 * وعندما يقوم المشرف بالعمل يتم تفعيل زر مناوبة»; contract v1.76-live, CONVENTIONS §10.96.6 / §10.96.14), end to end
 * against PostgreSQL + Redis with the in-memory media server:
 *
 *  - the app's staff tools work with no authenticator code as soon as the role is held (hidden watch, warn, kick, mute,
 *    remove a message, end, suspend, dismiss); still 403 for a plain account, FINANCE, BD, and SUPPORT on actions;
 *  - the code stays where it guards money, permissions or a permanent action: the device ban (app and panel), the
 *    team's grant / revoke / reset / regions, the recharge dispute resolution;
 *  - the automatic shift: entering a live as staff (visible or hidden), a staff tool and «بثوثي» switch «في المناوبة»
 *    on (audited `admin.shift.on` {via: auto, trigger, from}), with an assignment pass; the panel's watch, «بثوثي» and
 *    actions too; reading or switching the shift does not; FINANCE / BD never;
 *  - the idle switch-off: an automatic shift goes off after 2 h without staff work (audited {via: auto, reason: idle}),
 *    not while watching a live visibly, never a shift switched on by hand.
 */
import { randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { LiveStaffAssignmentService } from '../src/modules/live/live-staff-assignment.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, newUser, withMigrationClient, type TestContext } from './helpers/test-app.js';

const COOKIE = '__Host-kabso_admin';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly password: string;
  token: string;
}
interface Staff extends TestUser {
  secret: string;
  cookie: string;
  csrf: string;
}

describe('D286 staff work without a code, and the automatic shift', { timeout: 900_000 }, () => {
  let ctx: TestContext;
  let media: MemoryLiveMedia;
  let clock = Date.now();
  const advance = (ms: number) => {
    clock += ms;
    vi.setSystemTime(clock);
  };
  const nextCode = (secret: string) => {
    advance(30_000);
    return totpCode(secret, clock);
  };
  let ipCounter = 40;
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
  const hook = (event: string, room: string, identity: string) => {
    const raw = JSON.stringify({ event, room: { name: room }, participant: { identity } });
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
  const makeStaff = async (roles: string[]): Promise<Staff> => {
    const p = await signup();
    await withMigrationClient(async (db) => {
      for (const role of roles) await db.$transaction((tx) => grantRoleIn(tx, p.email, role as never));
    });
    const res = await ctx.http
      .post('/api/v1/admin/auth/login')
      .send({ email: p.email, password: p.password });
    const pending = cookieOf(res);
    const csrf = res.body.csrfToken as string;
    const enrolRes = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf);
    const secret = enrolRes.body.secret as string;
    const confirm = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment/confirm')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf)
      .send({ code: nextCode(secret) });
    expect(confirm.status, JSON.stringify(confirm.body)).toBe(200);
    return { ...p, secret, cookie: cookieOf(confirm), csrf: confirm.body.session.csrfToken as string };
  };
  const sget = (u: { token: string }, path: string) => ctx.http.get(`/api/v1${path}`).set(auth(u));
  const ssend = (u: { token: string }, method: 'post' | 'put' | 'delete', path: string, body: object = {}) =>
    ctx.http[method](`/api/v1${path}`).set(auth(u)).send(body);
  const aget = (s: Staff, path: string) => ctx.http.get(`/api/v1/admin${path}`).set('Cookie', s.cookie);
  const asend = (s: Staff, method: 'post' | 'put', path: string, body: object = {}) =>
    ctx.http[method](`/api/v1/admin${path}`).set('Cookie', s.cookie).set('X-CSRF-Token', s.csrf).send(body);
  const mediaToken = (u: { token: string }, roomId: string, body: object = {}) =>
    ctx.http.post(`/api/v1/live/rooms/${roomId}/media-token`).set(auth(u)).send(body);
  const shiftOf = async (userId: string) => ctx.prisma.adminShift.findUnique({ where: { userId } });
  const autoOn = async (userId: string) =>
    (
      await ctx.prisma.auditLog.findMany({
        where: { action: 'admin.shift.on', actorUserId: userId },
        orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      })
    ).filter((r) => (r.metadata as { via?: string }).via === 'auto');
  const resetShifts = () =>
    withMigrationClient(async (db) => {
      await db.$executeRawUnsafe(
        `UPDATE live_rooms SET status = 'ENDED', end_reason = 'HOST_ENDED', ended_at = last_heartbeat_at WHERE status = 'LIVE'`,
      );
      await db.$executeRawUnsafe(`DELETE FROM live_room_assignments`);
      await db.$executeRawUnsafe(`DELETE FROM live_room_staff_watchers`);
      await db.$executeRawUnsafe(`UPDATE admin_shifts SET on_shift = false`);
    });

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
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('the app tools need no code: hidden watch, warn, kick, mute, remove, dismiss, suspend, end; 403 where restricted', async () => {
    await resetShifts();
    const mod = await makeStaff(['MODERATION']);
    const support = await makeStaff(['SUPPORT']);
    const finance = await makeStaff(['FINANCE']);
    const bd = await makeStaff(['BD']);
    const plain = await signup();
    const h = await host();
    const roomId = await goLive(h);
    const viewer = await signup();
    const vt = await mediaToken(viewer, roomId);
    expect((await hook('participant_joined', roomId, vt.body.identity as string)).status).toBe(200);
    const line = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/chat`)
      .set(auth(viewer))
      .send({ text: 'rude', clientId: randomUUID() });
    expect(line.status, JSON.stringify(line.body)).toBe(201);

    // No step-up was ever made: the role alone opens every tool.
    const hidden = await mediaToken(mod, roomId, { staffVisibility: 'HIDDEN' });
    expect(hidden.status, JSON.stringify(hidden.body)).toBe(200);
    expect(hidden.body.staff).toBe('HIDDEN');
    const reporter = await signup();
    const rep = await ctx.http
      .post('/api/v1/reports')
      .set(auth(reporter))
      .send({ targetType: 'LIVE_ROOM', targetId: roomId, reason: 'SPAM' });
    expect(rep.status, JSON.stringify(rep.body)).toBe(201);
    const calls: [string, 'post' | 'put', string, object][] = [
      ['dismissStaffLiveReports', 'post', `/staff/lives/${roomId}/reports/dismiss`, { reason: 'Checked' }],
      [
        'moderateStaffLive',
        'post',
        `/staff/lives/${roomId}/moderate`,
        { action: 'WARN', reason: 'Language' },
      ],
      [
        'muteInStaffLive',
        'put',
        `/staff/lives/${roomId}/chat-mutes`,
        { username: viewer.username, reason: 'Spam' },
      ],
      [
        'removeStaffLiveMessage',
        'post',
        `/staff/lives/${roomId}/chat/${line.body.id as string}/remove`,
        { reason: 'Insult' },
      ],
      [
        'kickFromStaffLive',
        'post',
        `/staff/lives/${roomId}/kicks`,
        { username: viewer.username, reason: 'Abuse' },
      ],
    ];
    for (const [op, method, path, body] of calls) {
      const res = await ssend(mod, method, path, body);
      expect(res.status, `${path} ${JSON.stringify(res.body)}`).toBe(200);
      expectContract(res, op);
    }
    expect(await ctx.prisma.adminAppGrant.count({ where: { userId: mod.id } })).toBe(0);
    // Every action still audited with the reason and `via: app`.
    const warn = await ctx.prisma.auditLog.findFirst({
      where: { action: 'admin.live.moderate', targetId: roomId, actorUserId: mod.id },
    });
    expect(warn!.metadata).toMatchObject({ kind: 'WARN', reason: 'Language', via: 'app' });

    // Restricted as before: SUPPORT may not act, FINANCE / BD / a plain account get nothing.
    for (const u of [support, finance, bd, plain]) {
      const res = await ssend(u, 'post', `/staff/lives/${roomId}/moderate`, { action: 'WARN', reason: 'x' });
      expect(res.status, JSON.stringify(res.body)).toBe(403);
      expect(res.body.error.code).toBe('AUTH_FORBIDDEN');
    }
    for (const u of [finance, bd, plain]) expect((await sget(u, '/staff/lives')).status).toBe(403);
    const supHidden = await mediaToken(support, roomId, { staffVisibility: 'HIDDEN' });
    expect(supHidden.status).toBe(403);
    expect(supHidden.body.error.code).toBe('AUTH_FORBIDDEN');

    // A temporary suspension of the host: no code. END: no code.
    const suspend = await ssend(mod, 'post', `/staff/lives/${roomId}/moderate`, {
      action: 'SUSPEND',
      reason: 'Repeated',
      hours: 24,
    });
    expect(suspend.status, JSON.stringify(suspend.body)).toBe(200);
    expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).status).toBe('ENDED');
    const h2 = await host();
    const room2 = await goLive(h2);
    const end = await ssend(mod, 'post', `/staff/lives/${room2}/moderate`, {
      action: 'END',
      reason: 'Rules',
    });
    expect(end.status, JSON.stringify(end.body)).toBe(200);
  });

  it('the code stays for money, permissions and permanent actions: device ban, team changes, disputes', async () => {
    const owner = await makeStaff(['OWNER']);
    const target = await signup();
    const h = await host();
    const roomId = await goLive(h);
    // The device ban (app and panel): the code is still required.
    const app = await ssend(owner, 'post', `/staff/lives/${roomId}/moderate`, {
      action: 'DEVICE_BAN',
      reason: 'Ban evasion',
      permanent: true,
    });
    expect(app.status).toBe(400);
    expect(app.body.error.details).toEqual(
      expect.arrayContaining([expect.objectContaining({ field: 'totpCode' })]),
    );
    const appWrong = await ssend(owner, 'post', `/staff/lives/${roomId}/moderate`, {
      action: 'DEVICE_BAN',
      reason: 'Ban evasion',
      permanent: true,
      totpCode: '000000',
    });
    expect(appWrong.status).toBe(403);
    expect(appWrong.body.error.code).toBe('ADMIN_TOTP_INVALID');
    const appOk = await ssend(owner, 'post', `/staff/lives/${roomId}/moderate`, {
      action: 'DEVICE_BAN',
      reason: 'Ban evasion',
      hours: 24,
      totpCode: nextCode(owner.secret),
    });
    // The right code passes the check; the rule then runs (this test host signed up with no device id).
    expect(appOk.status, JSON.stringify(appOk.body)).toBe(409);
    expect(appOk.body.error.details).toEqual([{ field: 'device', issue: 'no_device' }]);
    const panel = await asend(owner, 'post', `/lives/${roomId}/moderate`, {
      action: 'DEVICE_BAN',
      reason: 'Ban evasion',
      permanent: true,
    });
    expect(panel.status).toBe(400);
    // The team (D271): grant without a code → 400; a wrong code → 403.
    const noCode = await asend(owner, 'post', '/team/grant', {
      account: target.username,
      role: 'SUPPORT',
      reason: 'New hire',
    });
    expect(noCode.status).toBe(400);
    const wrong = await asend(owner, 'post', '/team/grant', {
      account: target.username,
      role: 'SUPPORT',
      reason: 'New hire',
      totpCode: '000000',
    });
    expect(wrong.status).toBe(403);
    expect(wrong.body.error.code).toBe('ADMIN_TOTP_INVALID');
    const ok = await asend(owner, 'post', '/team/grant', {
      account: target.username,
      role: 'SUPPORT',
      reason: 'New hire',
      totpCode: nextCode(owner.secret),
    });
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    // A recharge dispute: the code is part of the body.
    const dispute = await asend(owner, 'post', `/recharge/orders/${randomUUID()}/resolve`, {
      outcome: 'CREDIT_BUYER',
      reason: 'Paid',
    });
    expect(dispute.status).toBe(400);
    expect(dispute.body.error.details).toEqual(
      expect.arrayContaining([expect.objectContaining({ field: 'totpCode' })]),
    );
  });

  it('staff work switches the shift on: entering a live (visible / hidden), a tool, «بثوثي»; reading the shift does not', async () => {
    await resetShifts();
    const support = await makeStaff(['SUPPORT']);
    const mod = await makeStaff(['MODERATION']);
    const owner = await makeStaff(['OWNER']);
    const finance = await makeStaff(['FINANCE']);
    const bd = await makeStaff(['BD']);
    const h = await host();
    const roomId = await goLive(h);

    // Reading the status or the shift is not staff work.
    expect((await sget(support, '/staff/me')).body.onShift).toBe(false);
    const read = await sget(support, '/staff/shift');
    expect(read.status).toBe(200);
    expect(read.body.onShift).toBe(false);

    // Entering a live visibly: on shift at once, the live assigned (nobody else on shift).
    const access = await mediaToken(support, roomId);
    expect(access.status, JSON.stringify(access.body)).toBe(200);
    expect(access.body.staff).toBe('VISIBLE');
    expect(await shiftOf(support.id)).toMatchObject({ onShift: true, startedVia: 'auto' });
    expect((await sget(support, '/staff/me')).body.onShift).toBe(true);
    const mine = await sget(support, '/staff/shift');
    expectContract(mine, 'getStaffShift');
    expect(mine.body).toMatchObject({ onShift: true, assignedLives: 1 });
    const [a1] = await autoOn(support.id);
    expect(a1!.metadata).toMatchObject({ via: 'auto', trigger: 'live_join', from: 'app', assigned: 1 });
    // Again: already on shift, no second audit row.
    expect((await mediaToken(support, roomId)).status).toBe(200);
    expect(await autoOn(support.id)).toHaveLength(1);

    // Hidden watch (MODERATION).
    expect((await mediaToken(mod, roomId, { staffVisibility: 'HIDDEN' })).status).toBe(200);
    expect((await autoOn(mod.id))[0]!.metadata).toMatchObject({ trigger: 'live_join', from: 'app' });

    // A tool (reading a live's reports) — OWNER.
    expect((await sget(owner, `/staff/lives/${roomId}/reports`)).status).toBe(200);
    expect((await autoOn(owner.id))[0]!.metadata).toMatchObject({ trigger: 'staff_tool', from: 'app' });

    // Turned off by hand, then «بثوثي» turns it on again.
    const off = await ssend(support, 'put', '/staff/shift', { onShift: false });
    expect(off.body.onShift).toBe(false);
    expect((await sget(support, '/staff/lives')).status).toBe(200);
    expect(await shiftOf(support.id)).toMatchObject({ onShift: true, startedVia: 'auto' });
    expect((await autoOn(support.id)).at(-1)!.metadata).toMatchObject({ trigger: 'my_lives' });

    // FINANCE and BD never get a shift (FINANCE watches as an ordinary viewer).
    const f = await mediaToken(finance, roomId);
    expect(f.status).toBe(200);
    expect(f.body.staff).toBeUndefined();
    expect(await shiftOf(finance.id)).toBeNull();
    expect((await mediaToken(bd, roomId)).body.staff).toBeUndefined();
    expect(await shiftOf(bd.id)).toBeNull();
  });

  it("the panel: watching a live, «بثوثي» and an action switch the shift on; the cards' previews do not", async () => {
    await resetShifts();
    const mod = await makeStaff(['MODERATION']);
    const support = await makeStaff(['SUPPORT']);
    const owner = await makeStaff(['OWNER']);
    const h = await host();
    const roomId = await goLive(h);

    const preview = await asend(mod, 'post', `/lives/${roomId}/watch-token`, { purpose: 'PREVIEW' });
    expect(preview.status, JSON.stringify(preview.body)).toBe(200);
    expect(await shiftOf(mod.id)).toBeNull();
    const watch = await asend(mod, 'post', `/lives/${roomId}/watch-token`, { purpose: 'WATCH' });
    expect(watch.status, JSON.stringify(watch.body)).toBe(200);
    expect(await shiftOf(mod.id)).toMatchObject({ onShift: true, startedVia: 'auto' });
    expect((await autoOn(mod.id))[0]!.metadata).toMatchObject({ trigger: 'live_join', from: 'panel' });
    const panelShift = await aget(mod, '/me/shift');
    expect(panelShift.body.onShift).toBe(true);

    // The panel's background refresh of «بثوثي» is not staff work.
    expect((await aget(support, '/lives?assigned=me&background=true')).status).toBe(200);
    expect(await shiftOf(support.id)).toBeNull();
    const lives = await aget(support, '/lives?assigned=me');
    expect(lives.status, JSON.stringify(lives.body)).toBe(200);
    expect((await autoOn(support.id))[0]!.metadata).toMatchObject({ trigger: 'my_lives', from: 'panel' });
    // The plain list is not «بثوثي».
    expect((await aget(owner, '/lives')).status).toBe(200);
    expect(await shiftOf(owner.id)).toBeNull();
    const warn = await asend(owner, 'post', `/lives/${roomId}/moderate`, {
      action: 'WARN',
      reason: 'Language',
    });
    expect(warn.status, JSON.stringify(warn.body)).toBe(200);
    expect((await autoOn(owner.id))[0]!.metadata).toMatchObject({ trigger: 'staff_tool', from: 'panel' });
  });

  it('idle: an automatic shift goes off after 2 h without staff work; not while watching visibly; never a manual one', async () => {
    await resetShifts();
    const sweeper = ctx.app.get(LiveStaffAssignmentService);
    const idle = await makeStaff(['SUPPORT']);
    const watching = await makeStaff(['SUPPORT']);
    const manual = await makeStaff(['MODERATION']);
    const h = await host();
    const roomId = await goLive(h);

    expect((await sget(idle, '/staff/lives')).status).toBe(200);
    const w = await mediaToken(watching, roomId);
    expect((await hook('participant_joined', roomId, w.body.identity as string)).status).toBe(200);
    expect((await ssend(manual, 'put', '/staff/shift', { onShift: true })).body.onShift).toBe(true);
    expect(await shiftOf(manual.id)).toMatchObject({ startedVia: 'app' });
    const held = await ctx.prisma.liveRoomAssignment.findUniqueOrThrow({ where: { roomId } });

    // Not yet: 1 h 59 min.
    advance(2 * 3600 * 1000 - 60_000);
    expect(await sweeper.offIdle()).toEqual([]);
    // 2 h 1 min after the last staff work.
    advance(120_000);
    expect(await sweeper.offIdle()).toEqual([idle.id]);
    expect(await shiftOf(idle.id)).toMatchObject({ onShift: false });
    expect(await shiftOf(watching.id)).toMatchObject({ onShift: true });
    expect(await shiftOf(manual.id)).toMatchObject({ onShift: true });
    const offAudit = await ctx.prisma.auditLog.findFirst({
      where: { action: 'admin.shift.off', actorUserId: idle.id },
    });
    expect(offAudit!.metadata).toMatchObject({ via: 'auto', reason: 'idle', idleSeconds: 7200 });
    expect((offAudit!.metadata as { released: number }).released).toBe(held.adminId === idle.id ? 1 : 0);
    // Their lives went to the others on shift.
    expect((await ctx.prisma.liveRoomAssignment.findUniqueOrThrow({ where: { roomId } })).adminId).not.toBe(
      idle.id,
    );
    expect((await sget(idle, '/staff/me')).body.onShift).toBe(false);

    // The watcher leaves: then idle too.
    expect((await hook('participant_left', roomId, w.body.identity as string)).status).toBe(200);
    expect(await sweeper.offIdle()).toEqual([watching.id]);
    // Hours later: a manual shift is still on (it goes off only by hand or on role loss).
    advance(10 * 3600 * 1000);
    expect(await sweeper.offIdle()).toEqual([]);
    expect(await shiftOf(manual.id)).toMatchObject({ onShift: true });
    await ssend(manual, 'put', '/staff/shift', { onShift: false });
  });
});
