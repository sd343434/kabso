/**
 * D273 (owner 2026-11-04; contract v1.68-live, CONVENTIONS §10.96.6–§10.96.8): «فريق كابسو» from the app, end to end
 * against PostgreSQL + Redis with the in-memory media server:
 *
 *  - an account holding OWNER / MODERATION / SUPPORT enters any live from the app as «فريق كابسو» (VISIBLE: listed in
 *    `LiveViewerPage.staff`, never counted, no join line; its chat lines carry `authorStaff`, no badges); it sends no
 *    gifts, taps or bullets; HIDDEN «مراقبة خفية» needs `lives.watch.hidden` (SUPPORT 403) — no code since D286 — and
 *    is neither listed nor counted nor able to chat; every staff token audited `admin.live.watch` `via: app`;
 *  - D286 (v1.76-live): no step-up any more — the tools work as soon as the role is held; the deprecated step-up route
 *    still checks the code (not enrolled → 409; wrong codes count towards the panel lockout; a replay refused);
 *  - every staff route checks role and capability per request (SUPPORT reads, MODERATION acts, FINANCE none);
 *    each action audited with `via: app` and the reason; the host told «فريق Kabso», never a name;
 *  - revocation: a revoked role ends the tools and the badge at once; a re-grant works at once; sign-out ends it;
 *  - reports reach the responsible staff member's phone: the assigned staff member on shift, else after a pass the
 *    OWNER / MODERATION on shift, else the OWNERs; one unread row per live; the push names the host only; audited;
 *  - panel accounts are untouchable from the app: kick, chat mute, message removal, family kick / mute → 403
 *    STAFF_PROTECTED; `PublicProfile.kabsoTeam`; a block never keeps staff out of a live.
 */
import { randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { FAMILY_CREATE_COST_COINS } from '../src/modules/families/families.constants.js';
import { uuidv7 } from '../src/modules/levels/uuidv7.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { NotificationPushDispatcher } from '../src/modules/notifications/notification-push.dispatcher.js';
import {
  PUSH_SENDER,
  type PushMessage,
  type PushSendResult,
  type PushSender,
} from '../src/modules/push/push-sender.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, newUser, withMigrationClient, type TestContext } from './helpers/test-app.js';

const COOKIE = '__Host-kabso_admin';

class FakePushSender implements PushSender {
  readonly enabled = true;
  readonly sent: PushMessage[] = [];
  send(message: PushMessage): Promise<PushSendResult> {
    this.sent.push(message);
    return Promise.resolve({ sent: message.tokens.length, failed: 0, invalidTokens: [] });
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly password: string;
  readonly displayName: string;
  token: string;
}
interface Staff extends TestUser {
  secret: string;
  cookie: string;
  csrf: string;
}

const D273_OPS = [
  'getStaffStatus GET /api/v1/staff/me',
  'createStaffStepUp POST /api/v1/staff/step-up',
  'endStaffStepUp DELETE /api/v1/staff/step-up',
  'getStaffShift GET /api/v1/staff/shift',
  'setStaffShift PUT /api/v1/staff/shift',
  'listStaffLives GET /api/v1/staff/lives',
  'listStaffLiveReports GET /api/v1/staff/lives/{roomId}/reports',
  'listStaffLiveModerations GET /api/v1/staff/lives/{roomId}/moderations',
  'moderateStaffLive POST /api/v1/staff/lives/{roomId}/moderate',
  'dismissStaffLiveReports POST /api/v1/staff/lives/{roomId}/reports/dismiss',
  'kickFromStaffLive POST /api/v1/staff/lives/{roomId}/kicks',
  'muteInStaffLive PUT /api/v1/staff/lives/{roomId}/chat-mutes',
  'removeStaffLiveMessage POST /api/v1/staff/lives/{roomId}/chat/{messageId}/remove',
];

describe('D273 contract coverage', () => {
  it('openapi v1.68-live declares the staff tools behind the bearer session (tag staff)', () => {
    const ops = operations();
    const ids = ops.map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(expect.arrayContaining(D273_OPS));
    for (const o of ops.filter((x) => D273_OPS.some((d) => d.startsWith(`${x.operationId} `)))) {
      expect(String(o.spec.description)).toContain('(v1.68-live, D273');
      expect(o.spec.security).toBeUndefined();
      expect(o.spec.tags).toEqual(['staff']);
    }
  });
});

describe('D273 «فريق كابسو» from the app', { timeout: 900_000 }, () => {
  let ctx: TestContext;
  let media: MemoryLiveMedia;
  const push = new FakePushSender();
  let clock = Date.now();
  const advance = (ms: number) => {
    clock += ms;
    vi.setSystemTime(clock);
  };
  const nextCode = (secret: string) => {
    advance(30_000);
    return totpCode(secret, clock);
  };
  let ipCounter = 120;
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
  const grant = async (p: TestUser, roles: string[]) =>
    withMigrationClient(async (db) => {
      for (const role of roles) await db.$transaction((tx) => grantRoleIn(tx, p.email, role as never));
    });
  /** A staff member: the app account, the panel role and the enrolled authenticator (what D271's next steps say). */
  const makeStaff = async (roles: string[], enrol = true): Promise<Staff> => {
    const p = await signup();
    await grant(p, roles);
    if (!enrol) return { ...p, secret: '', cookie: '', csrf: '' };
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
  const stepUp = async (s: Staff) => {
    const res = await ssend(s, 'post', '/staff/step-up', { code: nextCode(s.secret) });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'createStaffStepUp');
    return res.body as { expiresAt: string };
  };
  const mediaToken = (u: { token: string }, roomId: string, body: object = {}) =>
    ctx.http.post(`/api/v1/live/rooms/${roomId}/media-token`).set(auth(u)).send(body);
  /** Joins a live from the app (the token, then the media server's join webhook). */
  const enter = async (u: TestUser, roomId: string, body: object = {}) => {
    const res = await mediaToken(u, roomId, body);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'createLiveMediaToken');
    expect((await hook('participant_joined', roomId, res.body.identity as string)).status).toBe(200);
    return res.body as { identity: string; role: string; staff?: string };
  };
  const viewers = (u: { token: string }, roomId: string) =>
    ctx.http.get(`/api/v1/live/rooms/${roomId}/viewers`).set(auth(u));
  const room = (roomId: string) => ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } });
  const audits = (action: string, targetId?: string) =>
    ctx.prisma.auditLog.findMany({
      where: { action, ...(targetId ? { targetId } : {}) },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    });
  const say = async (u: TestUser, roomId: string, text: string) =>
    ctx.http.post(`/api/v1/live/rooms/${roomId}/chat`).set(auth(u)).send({ text, clientId: randomUUID() });
  const shift = async (s: Staff, onShift: boolean) => {
    const res = await ssend(s, 'put', '/staff/shift', { onShift });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'setStaffShift');
    return res.body as { onShift: boolean; assignedLives: number };
  };
  const endAllLives = () =>
    withMigrationClient(async (db) => {
      await db.$executeRawUnsafe(
        `UPDATE live_rooms SET status = 'ENDED', end_reason = 'HOST_ENDED', ended_at = last_heartbeat_at WHERE status = 'LIVE'`,
      );
      await db.$executeRawUnsafe(`DELETE FROM live_room_assignments`);
      await db.$executeRawUnsafe(`UPDATE admin_shifts SET on_shift = false`);
    });

  let owner: Staff;
  let mod: Staff;
  let support: Staff;
  let finance: Staff;
  let fresh: Staff;

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
        RATE_LIMIT_STAFF_STEP_UP_USER: '100/900',
      },
      [
        { token: LIVE_MEDIA_PROVIDER, value: media },
        { token: PUSH_SENDER, value: push },
      ],
    );
    ctx.app.getHttpServer().setMaxListeners(64);
    owner = await makeStaff(['OWNER']);
    mod = await makeStaff(['MODERATION']);
    support = await makeStaff(['SUPPORT']);
    finance = await makeStaff(['FINANCE']);
    fresh = await makeStaff(['MODERATION'], false);
    await endAllLives();
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('the status: anyone may ask; staff see their roles and tools; not enrolled → enrol in the panel first', async () => {
    const user = await signup();
    const none = await sget(user, '/staff/me');
    expect(none.status, JSON.stringify(none.body)).toBe(200);
    expectContract(none, 'getStaffStatus');
    expect(none.body).toMatchObject({ isStaff: false, protected: false, roles: [], stepUp: null });
    expect((await ssend(user, 'post', '/staff/step-up', { code: '123456' })).status).toBe(403);
    expect((await sget(user, '/staff/lives')).status).toBe(403);

    const s = await sget(support, '/staff/me');
    expect(s.body).toMatchObject({
      isStaff: true,
      protected: true,
      roles: ['SUPPORT'],
      authenticatorEnrolled: true,
    });
    // D286: always «unlocked» (older apps read `stepUp` and never ask for a code).
    expect(new Date(s.body.stepUp.expiresAt as string).getTime()).toBeGreaterThan(clock);
    // v1.78-live (D288): and the shared report queue «بلاغات» (read + «تم حله»), in the table's order.
    // v1.93-social (D296): SUPPORT's temporary lock from a report (`users.lock`, the panel's matrix).
    // v1.116-social (D355): and «واتساب» (the inbox; not its quick-reply management).
    // v1.120-social (D360): SUPPORT's default WhatsApp level is REPLY — reading (`support.whatsapp.view`) + replying.
    expect(s.body.capabilities).toEqual([
      'reports.view',
      'reports.resolve',
      'users.lock',
      'lives.watch',
      'lives.reports',
      'support.whatsapp',
      'support.whatsapp.view',
    ]);
    const m = await sget(mod, '/staff/me');
    expect(m.body.capabilities).toEqual(
      expect.arrayContaining([
        'lives.watch',
        'lives.watch.hidden',
        'lives.reports',
        'lives.moderate',
        'devices.ban',
      ]),
    );
    // FINANCE: protected, but not «فريق كابسو» in lives (no badge, no tools, no step-up).
    const f = await sget(finance, '/staff/me');
    expect(f.body).toMatchObject({ isStaff: false, protected: true, roles: ['FINANCE'] });
    expect((await ssend(finance, 'post', '/staff/step-up', { code: nextCode(finance.secret) })).status).toBe(
      403,
    );

    const nf = await sget(fresh, '/staff/me');
    expect(nf.body).toMatchObject({ isStaff: true, authenticatorEnrolled: false });
    const enrol = await ssend(fresh, 'post', '/staff/step-up', { code: '123456' });
    expect(enrol.status).toBe(409);
    expect(enrol.body.error.code).toBe('STAFF_TOTP_NOT_ENROLLED');
  });

  it('visible from the app: listed with the badge, never counted, no join line, team chat tag, no gifts / taps / bullets', async () => {
    const h = await host();
    const roomId = await goLive(h);
    const viewer = await signup();
    await enter(viewer, roomId);
    const broadcastsBefore = media.broadcasts.length;
    const access = await enter(support, roomId);
    expect(access.staff).toBe('VISIBLE');
    expect(access.role).toBe('VIEWER');
    expect(access.identity.startsWith(`team:${support.id}:`)).toBe(true);
    const issued = media.issued.find((t) => t.identity === access.identity)!;
    expect(issued.publish).toBe(false);
    expect(issued.visible).toBe(true);

    const page = await viewers(h, roomId);
    expect(page.status, JSON.stringify(page.body)).toBe(200);
    expectContract(page, 'listLiveRoomViewers');
    expect(page.body.staff).toEqual([expect.objectContaining({ displayName: support.displayName })]);
    expect((page.body.data as { user: { id: string } | null }[]).map((v) => v.user?.id)).toEqual([viewer.id]);
    expect((await room(roomId)).viewerCount).toBe(1);
    expect(
      media.broadcasts
        .slice(broadcastsBefore)
        .filter((b) => b.topic === 'chat' && b.payload.includes('"type":"join"')),
    ).toEqual([]);
    expect(await ctx.prisma.liveRoomViewer.count({ where: { roomId, userId: support.id } })).toBe(0);
    const watch = (await audits('admin.live.watch', roomId)).at(-1)!;
    expect(watch.actorUserId).toBe(support.id);
    expect(watch.metadata).toMatchObject({ visibility: 'VISIBLE', via: 'app', purpose: 'WATCH' });

    // Chat: the team's tag instead of levels / VIP.
    const line = await say(support, roomId, 'Kabso team here');
    expect(line.status, JSON.stringify(line.body)).toBe(201);
    expect(line.body.authorStaff).toBe(true);
    expect(line.body.cpBubble).toBe(false);
    const list = await ctx.http.get(`/api/v1/live/rooms/${roomId}/chat`).set(auth(viewer));
    const mine = (list.body.data as { author: { id: string }; authorStaff: boolean }[]).find(
      (m) => m.author.id === support.id,
    )!;
    expect(mine.authorStaff).toBe(true);
    const viewerLine = await say(viewer, roomId, 'hello');
    expect(viewerLine.status, JSON.stringify(viewerLine.body)).toBe(201);
    expect(viewerLine.body.authorStaff).toBe(false);

    // No economy in a live.
    const gift = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(support))
      .send({
        giftCode: 'rose',
        quantity: 1,
        recipients: [h.username],
        source: 'COINS',
        clientId: randomUUID(),
      });
    expect(gift.status, JSON.stringify(gift.body)).toBe(403);
    expect(gift.body.error).toMatchObject({
      code: 'LIVE_STAFF_REFUSED',
      details: [{ field: 'staff', issue: 'gifts' }],
    });
    const tap = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/taps`)
      .set(auth(support))
      .send({ count: 3 });
    expect(tap.status).toBe(403);
    expect(tap.body.error.details).toEqual([{ field: 'staff', issue: 'taps' }]);
    const bullet = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/bullets`)
      .set(auth(support))
      .send({ text: 'hi', clientId: randomUUID() });
    expect(bullet.status).toBe(403);
    expect(bullet.body.error.details).toEqual([{ field: 'staff', issue: 'bullets' }]);

    // Leaving: no longer listed.
    expect((await hook('participant_left', roomId, access.identity)).status).toBe(200);
    expect((await viewers(h, roomId)).body.staff).toEqual([]);
  });

  it('hidden from the app: OWNER / MODERATION with no code (D286); SUPPORT refused; never listed, counted or chatting', async () => {
    const h = await host();
    const roomId = await goLive(h);
    const sup = await mediaToken(support, roomId, { staffVisibility: 'HIDDEN' });
    expect(sup.status).toBe(403);
    expect(sup.body.error.code).toBe('AUTH_FORBIDDEN');
    const someone = await signup();
    expect((await mediaToken(someone, roomId, { staffVisibility: 'HIDDEN' })).status).toBe(403);

    // D286: no step-up — the role is enough.
    const access = await enter(mod, roomId, { staffVisibility: 'HIDDEN' });
    expect(access.staff).toBe('HIDDEN');
    expect(access.identity.startsWith(`staff:${mod.id}:`)).toBe(true);
    expect(media.issued.find((t) => t.identity === access.identity)!.visible).toBeUndefined();
    const page = await viewers(h, roomId);
    expect(page.body.staff).toEqual([]);
    expect(page.body.data).toEqual([]);
    expect((await room(roomId)).viewerCount).toBe(0);
    const chat = await say(mod, roomId, 'hidden');
    expect(chat.status).toBe(403);
    expect(chat.body.error).toMatchObject({
      code: 'LIVE_STAFF_REFUSED',
      details: [{ field: 'staff', issue: 'hidden_chat' }],
    });
    const watch = (await audits('admin.live.watch', roomId)).at(-1)!;
    expect(watch.metadata).toMatchObject({ visibility: 'HIDDEN', via: 'app' });
    // A hidden observer still uses the tools.
    const reports = await sget(mod, `/staff/lives/${roomId}/reports`);
    expect(reports.status).toBe(200);
  });

  it('D286: no code for the tools; the deprecated step-up still checks the code and the panel lockout', async () => {
    const s = await makeStaff(['MODERATION']);
    const lives = await sget(s, '/staff/lives');
    expect(lives.status, JSON.stringify(lives.body)).toBe(200);
    expect(new Date((await sget(s, '/staff/me')).body.stepUp.expiresAt as string).getTime()).toBe(
      clock + 12 * 3600 * 1000,
    );
    const bad = await ssend(s, 'post', '/staff/step-up', { code: 'abc' });
    expect(bad.status).toBe(400);
    const ok = await stepUp(s);
    expect(new Date(ok.expiresAt).getTime() - clock).toBe(12 * 3600 * 1000);
    // A code works once.
    const code = totpCode(s.secret, clock);
    const replay = await ssend(s, 'post', '/staff/step-up', { code });
    expect(replay.status).toBe(403);
    expect(replay.body.error.code).toBe('ADMIN_TOTP_INVALID');
    // Wrong codes: 403 until the limit (5, counting the replay), then 429 and the panel sessions end.
    for (let i = 0; i < 3; i += 1) {
      const wrong = await ssend(s, 'post', '/staff/step-up', { code: '000000' });
      expect(wrong.status).toBe(403);
    }
    const locked = await ssend(s, 'post', '/staff/step-up', { code: '000000' });
    expect(locked.status).toBe(429);
    expect(locked.body.error.code).toBe('ADMIN_LOCKED');
    expect((await ctx.http.get('/api/v1/admin/auth/session').set('Cookie', s.cookie)).status).toBe(401);
    expect((await sget(s, '/staff/me')).body.lockedUntil).not.toBeNull();
    // The role, not the code, opens the tools (D286): they keep working.
    expect((await sget(s, '/staff/lives')).status).toBe(200);
    expect((await ctx.prisma.adminAppGrant.findMany({ where: { userId: s.id } }))[0]!.revokedReason).toBe(
      'LOCKED',
    );
  });

  it('per role: SUPPORT reads and keeps a shift; MODERATION acts (with reasons, audited via app); FINANCE nothing', async () => {
    await endAllLives();
    const h = await host();
    const roomId = await goLive(h);
    const viewer = await signup();
    await enter(viewer, roomId);
    const line = await say(viewer, roomId, 'rude line');
    const messageId = line.body.id as string;

    // SUPPORT: shift and «بثوثي», the reports and the history; no action.
    const on = await shift(support, true);
    expect(on.assignedLives).toBeGreaterThanOrEqual(1);
    const lives = await sget(support, '/staff/lives');
    expect(lives.status).toBe(200);
    expectContract(lives, 'listStaffLives');
    expect((lives.body.data as { roomId: string }[]).map((l) => l.roomId)).toContain(roomId);
    const reports = await sget(support, `/staff/lives/${roomId}/reports`);
    expect(reports.status).toBe(200);
    expectContract(reports, 'listStaffLiveReports');
    expect((await sget(support, `/staff/lives/${roomId}/moderations`)).status).toBe(200);
    for (const [method, path, body] of [
      ['post', `/staff/lives/${roomId}/moderate`, { action: 'WARN', reason: 'x' }],
      ['post', `/staff/lives/${roomId}/reports/dismiss`, { reason: 'x' }],
      ['post', `/staff/lives/${roomId}/kicks`, { username: viewer.username, reason: 'x' }],
      ['put', `/staff/lives/${roomId}/chat-mutes`, { username: viewer.username, reason: 'x' }],
      ['post', `/staff/lives/${roomId}/chat/${messageId}/remove`, { reason: 'x' }],
    ] as const) {
      const res = await ssend(support, method, path, body);
      expect(res.status, `${path} ${JSON.stringify(res.body)}`).toBe(403);
      expect(res.body.error.code).toBe('AUTH_FORBIDDEN');
    }
    const shiftAudit = (await audits('admin.shift.on')).filter((r) => r.actorUserId === support.id).at(-1)!;
    expect(shiftAudit.metadata).toMatchObject({ via: 'app' });

    // FINANCE: no staff route at all (and no step-up).
    expect((await sget(finance, '/staff/shift')).status).toBe(403);
    expect((await sget(finance, `/staff/lives/${roomId}/reports`)).status).toBe(403);

    // MODERATION: every action with a reason and no code (D286), audited via app; the host is told by «فريق Kabso».
    expect((await ssend(mod, 'post', `/staff/lives/${roomId}/moderate`, { action: 'WARN' })).status).toBe(
      400,
    );
    const warn = await ssend(mod, 'post', `/staff/lives/${roomId}/moderate`, {
      action: 'WARN',
      reason: 'Language',
    });
    expect(warn.status, JSON.stringify(warn.body)).toBe(200);
    expectContract(warn, 'moderateStaffLive');
    expect(warn.body).toMatchObject({ kind: 'WARN', endedLive: false, endsAt: null });
    expect((await room(roomId)).status).toBe('LIVE');
    const note = await ctx.http.get('/api/v1/notifications').set(auth(h));
    const warned = (
      note.body.data as { type: string; actors: unknown[]; target: { moderation?: string } }[]
    ).find((n) => n.type === 'LIVE_MODERATED')!;
    expect(warned.target.moderation).toBe('WARN');
    expect(warned.actors).toEqual([]);
    expect((await audits('admin.live.moderate', roomId)).at(-1)!.metadata).toMatchObject({
      kind: 'WARN',
      reason: 'Language',
      via: 'app',
    });

    const removed = await ssend(mod, 'post', `/staff/lives/${roomId}/chat/${messageId}/remove`, {
      reason: 'Insult',
    });
    expect(removed.status, JSON.stringify(removed.body)).toBe(200);
    expectContract(removed, 'removeStaffLiveMessage');
    expect(removed.body.removed).toBe(true);
    expect((await audits('admin.live.chat_remove', messageId))[0]!.metadata).toMatchObject({
      reason: 'Insult',
      via: 'app',
    });
    const muted = await ssend(mod, 'put', `/staff/lives/${roomId}/chat-mutes`, {
      username: viewer.username,
      reason: 'Spam',
    });
    expect(muted.status, JSON.stringify(muted.body)).toBe(200);
    expectContract(muted, 'muteInStaffLive');
    expect((await say(viewer, roomId, 'again')).status).toBe(403);
    const muteHost = await ssend(mod, 'put', `/staff/lives/${roomId}/chat-mutes`, {
      username: h.username,
      reason: 'x',
    });
    expect(muteHost.status).toBe(409);
    const kicked = await ssend(mod, 'post', `/staff/lives/${roomId}/kicks`, {
      username: `@${viewer.username}`,
      reason: 'Abuse',
    });
    expect(kicked.status, JSON.stringify(kicked.body)).toBe(200);
    expectContract(kicked, 'kickFromStaffLive');
    const kickData = media.broadcasts.filter((b) => b.room === roomId && b.topic === 'kick').at(-1)!;
    expect(JSON.parse(kickData.payload)).toMatchObject({ by: null, byTeam: true });
    expect((await audits('live.kick', viewer.id)).at(-1)!.metadata).toMatchObject({
      reason: 'Abuse',
      staff: true,
      via: 'app',
    });
    const history = await sget(mod, `/staff/lives/${roomId}/moderations`);
    expectContract(history, 'listStaffLiveModerations');
    expect((history.body.data as { kind: string }[])[0]!.kind).toBe('WARN');

    // END with a reason.
    const end = await ssend(mod, 'post', `/staff/lives/${roomId}/moderate`, {
      action: 'END',
      reason: 'Rules',
    });
    expect(end.status, JSON.stringify(end.body)).toBe(200);
    expect((await room(roomId)).status).toBe('ENDED');
    await shift(support, false);
  });

  it('revocation: a revoked role ends the tools and the badge at once; a re-grant works at once; sign-out ends it', async () => {
    const s = await makeStaff(['MODERATION']);
    const h = await host();
    const roomId = await goLive(h);
    const access = await enter(s, roomId);
    expect((await viewers(h, roomId)).body.staff).toHaveLength(1);
    const revoke = await ctx.http
      .post(`/api/v1/admin/team/${s.id}/revoke`)
      .set('Cookie', owner.cookie)
      .set('X-CSRF-Token', owner.csrf)
      .send({ role: 'MODERATION', reason: 'Left the team', totpCode: nextCode(owner.secret) });
    expect(revoke.status, JSON.stringify(revoke.body)).toBe(200);
    expect((await sget(s, `/staff/lives/${roomId}/reports`)).status).toBe(403);
    expect((await sget(s, '/staff/me')).body.isStaff).toBe(false);
    expect((await viewers(h, roomId)).body.staff).toEqual([]);
    expect(media.removed).toEqual(expect.arrayContaining([{ room: roomId, identity: access.identity }]));
    // An ordinary viewer again.
    const plain = await mediaToken(s, roomId);
    expect(plain.body.staff).toBeUndefined();
    expect(plain.body.identity).toBe(s.id);
    // Granted again: the tools work at once (D286: no code).
    await grant(s, ['MODERATION']);
    expect((await sget(s, '/staff/lives')).status).toBe(200);
    // Sign-out: the session ends, and the tools with it.
    expect((await ctx.http.post('/api/v1/auth/logout').set(auth(s)).send({})).status).toBe(204);
    expect((await sget(s, '/staff/lives')).status).toBe(401);
  });

  it('reports reach the responsible staff member: assigned on shift, else the actors on shift, else the OWNERs', async () => {
    await endAllLives();
    const dispatcher = ctx.app.get(NotificationPushDispatcher);
    await dispatcher.dispatchOnce();
    const phone = `fcm_${randomUUID().replaceAll('-', '')}:APA91b${randomUUID().replaceAll('-', '')}`;
    expect(
      (
        await ctx.http
          .put('/api/v1/me/push-token')
          .set(auth(mod))
          .send({ token: phone, platform: 'ANDROID', appVersion: '0.1.0' })
      ).status,
    ).toBe(204);
    await shift(mod, true);
    const h = await host();
    const roomId = await goLive(h);
    for (
      let i = 0;
      i < 100 && (await ctx.prisma.liveRoomAssignment.findUnique({ where: { roomId } })) === null;
      i += 1
    )
      await new Promise((r) => setTimeout(r, 10));
    expect((await ctx.prisma.liveRoomAssignment.findUniqueOrThrow({ where: { roomId } })).adminId).toBe(
      mod.id,
    );

    const reporter = await signup();
    const rep = await ctx.http
      .post('/api/v1/reports')
      .set(auth(reporter))
      .send({ targetType: 'LIVE_ROOM', targetId: roomId, reason: 'HARASSMENT', note: 'private note' });
    expect(rep.status, JSON.stringify(rep.body)).toBe(201);
    const rows = await ctx.prisma.notification.findMany({
      where: { type: 'LIVE_STAFF_REPORT', liveRoomId: roomId },
    });
    expect(rows.map((r) => r.recipientId)).toEqual([mod.id]);
    const alert = (await audits('live.staff_report.alert', roomId)).at(-1)!;
    expect(alert.metadata).toMatchObject({ route: 'assigned', recipients: [mod.id] });
    push.sent.length = 0;
    expect(await dispatcher.dispatchOnce()).toBe(1);
    const sent = push.sent.find((p) => p.tokens.includes(phone))!;
    expect(sent.data).toMatchObject({ type: 'LIVE_STAFF_REPORT', targetType: 'LIVE_ROOM', targetId: roomId });
    // The host's name only — nothing about the reporter, the reason or the note.
    expect(sent.body).toBe(`New report on ${h.displayName}'s live`);
    expect(JSON.stringify(sent.data)).not.toContain(reporter.username);
    expect((await audits('live.staff_report.push', roomId)).at(-1)!.metadata).toMatchObject({
      recipientId: mod.id,
      onShift: true,
    });
    const inbox = await ctx.http.get('/api/v1/notifications').set(auth(mod));
    expectContract(inbox, 'listNotifications');
    const item = (
      inbox.body.data as { type: string; target: { type: string; id: string; live: boolean } }[]
    ).find((n) => n.type === 'LIVE_STAFF_REPORT')!;
    expect(item.target).toMatchObject({ type: 'LIVE_ROOM', id: roomId, live: true });

    // A user reported from inside the live, and a chat message: the same unread row, moved up; both in the reports.
    const viewer = await signup();
    await enter(viewer, roomId);
    const line = await say(viewer, roomId, 'bad');
    const r2 = await ctx.http
      .post('/api/v1/reports')
      .set(auth(reporter))
      .send({ targetType: 'USER', targetId: viewer.username, reason: 'SPAM', liveRoomId: roomId });
    expect(r2.status, JSON.stringify(r2.body)).toBe(201);
    const r3 = await ctx.http
      .post('/api/v1/reports')
      .set(auth(reporter))
      .send({ targetType: 'LIVE_CHAT_MESSAGE', targetId: line.body.id, reason: 'SPAM' });
    expect(r3.status).toBe(201);
    expect(
      (
        await ctx.http
          .post('/api/v1/reports')
          .set(auth(reporter))
          .send({ targetType: 'POST', targetId: randomUUID(), reason: 'SPAM', liveRoomId: roomId })
      ).status,
    ).toBe(400);
    expect(
      await ctx.prisma.notification.count({ where: { type: 'LIVE_STAFF_REPORT', liveRoomId: roomId } }),
    ).toBe(1);
    const list = await sget(mod, `/staff/lives/${roomId}/reports`);
    expectContract(list, 'listStaffLiveReports');
    const kinds = (
      list.body.data as { targetType: string; target: { user: { id: string } | null } | null }[]
    ).map((r) => `${r.targetType}:${r.target?.user?.id ?? ''}`);
    expect(kinds).toEqual(
      expect.arrayContaining([`LIVE_ROOM:`, `USER:${viewer.id}`, `LIVE_CHAT_MESSAGE:${viewer.id}`]),
    );

    // Off shift: a pass runs; nobody else on shift → the OWNERs (never the reporter).
    await shift(mod, false);
    const h2 = await host();
    const room2 = await goLive(h2);
    const r4 = await ctx.http
      .post('/api/v1/reports')
      .set(auth(reporter))
      .send({ targetType: 'LIVE_ROOM', targetId: room2, reason: 'SPAM' });
    expect(r4.status).toBe(201);
    const a2 = (await audits('live.staff_report.alert', room2)).at(-1)!;
    expect(a2.metadata).toMatchObject({ route: 'owners' });
    expect((a2.metadata as { recipients: string[] }).recipients).toContain(owner.id);
    expect((a2.metadata as { recipients: string[] }).recipients).not.toContain(mod.id);
    // An OWNER on shift who may act: the pass gives them the reported live.
    await shift(owner, true);
    const h3 = await host();
    const room3 = await goLive(h3);
    await ctx.prisma.liveRoomAssignment.deleteMany({ where: { roomId: room3 } });
    await ctx.http
      .post('/api/v1/reports')
      .set(auth(reporter))
      .send({ targetType: 'LIVE_ROOM', targetId: room3, reason: 'SPAM' });
    expect((await audits('live.staff_report.alert', room3)).at(-1)!.metadata).toMatchObject({
      route: 'assigned',
      recipients: [owner.id],
    });
    await shift(owner, false);
  });

  it('panel accounts are untouchable from the app, and a block never keeps staff out of a live', async () => {
    const h = await host();
    const roomId = await goLive(h);
    // FINANCE watches as an ordinary viewer (no badge) but is protected too.
    await enter(finance, roomId);
    await enter(support, roomId);
    for (const target of [support, finance]) {
      const kick = await ctx.http
        .post(`/api/v1/live/rooms/${roomId}/kicks`)
        .set(auth(h))
        .send({ username: target.username });
      expect(kick.status, JSON.stringify(kick.body)).toBe(403);
      expect(kick.body.error.code).toBe('STAFF_PROTECTED');
      const mute = await ctx.http
        .put(`/api/v1/live/rooms/${roomId}/chat/mutes/${target.username}`)
        .set(auth(h));
      expect(mute.status).toBe(403);
      expect(mute.body.error.code).toBe('STAFF_PROTECTED');
    }
    const line = await say(support, roomId, 'staff line');
    const del = await ctx.http
      .delete(`/api/v1/live/rooms/${roomId}/chat/${line.body.id as string}`)
      .set(auth(h));
    expect(del.status).toBe(403);
    expect(del.body.error.code).toBe('STAFF_PROTECTED');
    // Nor from the staff tools: one staff member does not remove another's message.
    const other = await ssend(mod, 'post', `/staff/lives/${roomId}/chat/${line.body.id as string}/remove`, {
      reason: 'x',
    });
    expect(other.status).toBe(403);
    expect(other.body.error.code).toBe('STAFF_PROTECTED');

    const profile = await ctx.http.get(`/api/v1/users/${support.username}`).set(auth(h));
    expect(profile.status).toBe(200);
    expectContract(profile, 'getPublicProfile');
    expect(profile.body.kabsoTeam).toBe(true);
    expect(
      (await ctx.http.get(`/api/v1/users/${h.username}`).set(auth(support))).body.kabsoTeam,
    ).toBeUndefined();

    // A block either way never keeps staff out (it still applies elsewhere).
    expect((await ctx.http.put(`/api/v1/users/${support.username}/block`).set(auth(h))).status).toBe(200);
    const again = await mediaToken(support, roomId);
    expect(again.status, JSON.stringify(again.body)).toBe(200);
    expect(again.body.staff).toBe('VISIBLE');
    const discover = await ctx.http.get(`/api/v1/live/rooms/${roomId}`).set(auth(support));
    expect(discover.status).toBe(200);

    // Family: the leader cannot remove or mute a staff member. (D283: only an OWNER account may join a family —
    // MODERATION / SUPPORT / FINANCE are refused — so the member is the OWNER.)
    const leader = await signup();
    await ctx.prisma.$transaction((tx) =>
      creditIn(tx, leader.id, BigInt(FAMILY_CREATE_COST_COINS), 'ADMIN_GRANT', uuidv7()),
    );
    const fam = await ctx.http
      .post('/api/v1/families')
      .set(auth(leader))
      .send({ name: `Fam${Date.now() % 100000}`, clientId: randomUUID() });
    expect(fam.status, JSON.stringify(fam.body)).toBe(201);
    const familyId = fam.body.family.id as string;
    const asked = await ctx.http.post(`/api/v1/families/${familyId}/join-requests`).set(auth(owner));
    expect(asked.status, JSON.stringify(asked.body)).toBe(201);
    expect(
      (
        await ctx.http
          .post(`/api/v1/families/${familyId}/join-requests/${asked.body.id as string}/accept`)
          .set(auth(leader))
      ).status,
    ).toBe(200);
    const fmute = await ctx.http
      .put(`/api/v1/families/${familyId}/chat/mutes/${owner.username}`)
      .set(auth(leader));
    expect(fmute.status).toBe(403);
    expect(fmute.body.error.code).toBe('STAFF_PROTECTED');
    const fkick = await ctx.http
      .delete(`/api/v1/families/${familyId}/members/${owner.username}`)
      .set(auth(leader));
    expect(fkick.status).toBe(403);
    expect(fkick.body.error.code).toBe('STAFF_PROTECTED');
  });
});
