/**
 * D250 (owner 2026-11-02: «هنا يجب أن يعرض البث لايف، بحيث يمكن أن يكون موظف يراقب اللايفات من خلال اللوحة، وفي حال شخص قام
 * بالإبلاغ عن لايف يظهر في خانة لايفات مبلّغ عنها وبجانبها نقطة حمراء … يغلق البث أو عمل حظر مؤقت أو حظر جهاز، ويضع في صندوق
 * سبب ليصل إشعار للمضيف بالسبب»; contract v1.60-live, CONVENTIONS §10.91): live moderation from the panel, end to end
 * against PostgreSQL + Redis with the in-memory media server and a fake push sender:
 *
 *  - the hidden staff observer token (capabilities, hidden + subscribe-only, never a viewer through the webhook or the
 *    reconciliation, audited, refused to FINANCE, both rooms of a PK); D250b: SUPPORT watches and reads the reports
 *    but every action and the device bans answer 403;
 *  - the reported lives (LIVE_ROOM reports with a note, deduped per reporter; the host's USER reports made during the
 *    live), the counts, the per-live reports with the reporter and the chat before;
 *  - each action with its reason: END, NO_LIVE (go-live refused with the reason until the end, then allowed), SUSPEND
 *    (sign-in refused with the reason, then allowed), DEVICE_BAN (the code again; sign-up, sign-in and go-live refused
 *    from the device for every account; the list; lift), DISMISS; the host's LIVE_MODERATED notification and its push
 *    with the reason; the audit rows; the permissions per role; the validation.
 */
import { createHash, randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { deviceHashOf, deviceHmacKey } from '../src/modules/auth/device-signups.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { NotificationPushDispatcher } from '../src/modules/notifications/notification-push.dispatcher.js';
import {
  PUSH_SENDER,
  type PushMessage,
  type PushSendResult,
  type PushSender,
} from '../src/modules/push/push-sender.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, newUser, withMigrationClient, type TestContext } from './helpers/test-app.js';

const COOKIE = '__Host-kabso_admin';
const HOUR = 3_600_000;

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
  token: string;
  readonly deviceKey: string | null;
}
interface Admin extends TestUser {
  secret: string;
  cookie: string;
  csrf: string;
}

const newDeviceKey = () => createHash('sha256').update(`kabso-test:android:${randomUUID()}`).digest('hex');

const D250_OPS = [
  'getAdminLiveReportsSummary GET /api/v1/admin/live-reports/summary',
  'createAdminLiveWatchToken POST /api/v1/admin/lives/{roomId}/watch-token',
  'listAdminLiveChat GET /api/v1/admin/lives/{roomId}/chat',
  'listAdminLiveReports GET /api/v1/admin/lives/{roomId}/reports',
  'listAdminLiveModerations GET /api/v1/admin/lives/{roomId}/moderations',
  'moderateAdminLive POST /api/v1/admin/lives/{roomId}/moderate',
  'dismissAdminLiveReports POST /api/v1/admin/lives/{roomId}/reports/dismiss',
  'listAdminDeviceBans GET /api/v1/admin/device-bans',
  'liftAdminDeviceBan POST /api/v1/admin/device-bans/{banId}/lift',
];

describe('D250 contract coverage', () => {
  it('openapi v1.60-live declares the panel routes behind the admin session (CSRF on writes)', () => {
    const ops = operations();
    const ids = ops.map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(expect.arrayContaining(D250_OPS));
    for (const o of ops.filter((x) => D250_OPS.some((d) => d.startsWith(`${x.operationId} `)))) {
      expect(o.spec.security).toEqual([{ adminSession: [] }]);
      if (o.method !== 'get') expect(JSON.stringify(o.spec.parameters)).toContain('AdminCsrf');
    }
    for (const id of ['login', 'register', 'registerVerify', 'startLiveRoom']) {
      const op = ops.find((o) => o.operationId === id)!;
      expect(JSON.stringify(op.spec), id).toContain('DEVICE_BANNED');
    }
  });
});

describe('D250 live moderation from the panel', { timeout: 900_000 }, () => {
  let ctx: TestContext;
  let media: MemoryLiveMedia;
  const fake = new FakePushSender();
  let clock = Date.now();
  const advance = (ms: number) => {
    clock += ms;
    vi.setSystemTime(clock);
  };
  let ipCounter = 40;
  const nextIp = () => {
    ipCounter += 1;
    return `198.51.${Math.floor(ipCounter / 250)}.${(ipCounter % 250) + 1}`;
  };
  const deviceOf = (deviceKey: string | null) => ({
    name: 'Pixel 9',
    platform: 'android',
    appVersion: '1.0.0',
    ...(deviceKey ? { deviceKey } : {}),
  });
  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });

  const register = async (deviceKey: string | null) => {
    const payload = newUser({ device: deviceOf(deviceKey) });
    const email = String(payload.email).trim().toLowerCase();
    const before = ctx.mail.sent.length;
    const ip = nextIp();
    const res = await ctx.http.post('/api/v1/auth/register').set('X-Forwarded-For', ip).send(payload);
    return { res, payload, email, ip, before };
  };
  const signup = async (deviceKey: string | null = newDeviceKey()): Promise<TestUser> => {
    const r = await register(deviceKey);
    expect(r.res.status, JSON.stringify(r.res.body)).toBe(202);
    const mail = await ctx.mail.waitFor(r.email, 'code', r.before);
    const res = await ctx.http
      .post('/api/v1/auth/register/verify')
      .set('X-Forwarded-For', r.ip)
      .send({ email: r.email, code: mail.code, device: deviceOf(deviceKey) });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: r.email,
      password: String(r.payload.password),
      token: res.body.tokens.accessToken as string,
      deviceKey,
    };
  };
  const login = (u: TestUser, deviceKey: string | null) =>
    ctx.http
      .post('/api/v1/auth/login')
      .set('X-Forwarded-For', nextIp())
      .send({ identifier: u.email, password: u.password, device: deviceOf(deviceKey) });
  const host = async (deviceKey: string | null = newDeviceKey()) => {
    const u = await signup(deviceKey);
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  const goLive = async (u: TestUser) => {
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
  const report = (by: TestUser, body: object) => ctx.http.post('/api/v1/reports').set(auth(by)).send(body);

  // ---- the panel -----------------------------------------------------------------------------------------------
  const cookieOf = (res: request.Response): string => {
    const raw = ([] as string[]).concat(res.headers['set-cookie'] ?? []);
    const line = raw.find((c) => c.startsWith(`${COOKIE}=`));
    if (!line) throw new Error(`no session cookie in ${JSON.stringify(raw)}`);
    return line.split(';')[0]!;
  };
  const nextCode = (secret: string) => {
    advance(30_000);
    return totpCode(secret, clock);
  };
  const makeAdmin = async (roles: string[]): Promise<Admin> => {
    const p = await signup(null);
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
    const secret = enrol.body.secret as string;
    const confirm = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment/confirm')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf)
      .send({ code: nextCode(secret) });
    expect(confirm.status, JSON.stringify(confirm.body)).toBe(200);
    return { ...p, secret, cookie: cookieOf(confirm), csrf: confirm.body.session.csrfToken as string };
  };
  /** New panel sessions after the clock jumps (they idle out after a day, end after a week). */
  const relogin = async () => {
    for (const a of [owner, moderator, support, finance]) {
      const res = await ctx.http
        .post('/api/v1/admin/auth/login')
        .send({ email: a.email, password: a.password });
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      const v = await ctx.http
        .post('/api/v1/admin/auth/totp/verify')
        .set('Cookie', cookieOf(res))
        .set('X-CSRF-Token', res.body.csrfToken as string)
        .send({ code: nextCode(a.secret) });
      expect(v.status, JSON.stringify(v.body)).toBe(200);
      a.cookie = cookieOf(v);
      a.csrf = v.body.csrfToken as string;
    }
  };
  const aget = (a: Admin, path: string) => ctx.http.get(`/api/v1${path}`).set('Cookie', a.cookie);
  const apost = (a: Admin, path: string, body: object = {}) =>
    ctx.http.post(`/api/v1${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf).send(body);
  const audits = (action: string, targetId?: string) =>
    ctx.prisma.auditLog.findMany({
      where: { action, ...(targetId ? { targetId } : {}) },
      orderBy: { createdAt: 'asc' },
    });
  const expectCode = (res: request.Response, status: number, code: string) => {
    expect(res.status, JSON.stringify(res.body)).toBe(status);
    expect(res.body.error.code).toBe(code);
  };
  const detail = (res: request.Response, field: string) =>
    (res.body.error.details as { field: string; issue: string }[]).find((d) => d.field === field)?.issue;

  let owner: Admin;
  let moderator: Admin;
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
        REFRESH_TTL_SECONDS: String(60 * 86_400),
        REFRESH_ABSOLUTE_TTL_SECONDS: String(60 * 86_400),
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        ADMIN_SESSION_MAX_SECONDS: '604800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '100000/900',
        SIGNUP_MAX_ACCOUNTS_PER_DEVICE: '20',
      },
      [
        { token: LIVE_MEDIA_PROVIDER, value: media },
        { token: PUSH_SENDER, value: fake },
      ],
    );
    ctx.app.getHttpServer().setMaxListeners(64);
    owner = await makeAdmin(['OWNER']);
    moderator = await makeAdmin(['MODERATION']);
    support = await makeAdmin(['SUPPORT']);
    finance = await makeAdmin(['FINANCE']);
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('the hidden observer: OWNER / MODERATION only, hidden and subscribe-only, never a viewer, audited; both PK rooms', async () => {
    const h = await host();
    const roomId = await goLive(h);
    const viewer = await signup();
    expect((await hook('participant_joined', roomId, viewer.id)).status).toBe(200);
    expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).viewerCount).toBe(1);

    expectCode(
      await apost(finance, `/admin/lives/${roomId}/watch-token`, { purpose: 'WATCH' }),
      403,
      'AUTH_FORBIDDEN',
    );
    // D250b (owner): SUPPORT may watch — D260: visibly (`team:`); hidden is OWNER / MODERATION only.
    const bySupport = await apost(support, `/admin/lives/${roomId}/watch-token`, { purpose: 'WATCH' });
    expect(bySupport.status, JSON.stringify(bySupport.body)).toBe(200);
    expectContract(bySupport, 'createAdminLiveWatchToken');
    expect(bySupport.body.main.identity).toMatch(new RegExp(`^team:${support.id}:`));
    expect((await audits('admin.live.watch', roomId)).map((r) => r.actorUserId)).toEqual([support.id]);
    const issuedBefore = media.issued.length;
    const res = await apost(moderator, `/admin/lives/${roomId}/watch-token`, { purpose: 'PREVIEW' });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'createAdminLiveWatchToken');
    expect(res.body.purpose).toBe('PREVIEW');
    expect(res.body.opponent).toBeNull();
    const identity = res.body.main.identity as string;
    expect(identity).toMatch(new RegExp(`^staff:${moderator.id}:[0-9a-f]{12}$`));
    const grant = media.issued.at(-1)!;
    expect(media.issued.length).toBe(issuedBefore + 1);
    // Watch only: no publishing (the provider then sets `hidden` and no data), a short TTL.
    expect(grant).toMatchObject({ room: roomId, identity, publish: false, ttlSeconds: 120 });
    expect(grant.sources).toBeUndefined();

    // Joins through the webhook: never a viewer row, never counted, never kicked while the live is on air.
    expect((await hook('participant_joined', roomId, identity)).status).toBe(200);
    expect(await ctx.prisma.liveRoomViewer.count({ where: { roomId, identity } })).toBe(0);
    expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).viewerCount).toBe(1);
    expect(media.removed.some((r) => r.identity === identity)).toBe(false);
    // The viewer list (host's and viewers') does not show it.
    const viewers = await ctx.http.get(`/api/v1/live/rooms/${roomId}/viewers`).set(auth(h));
    expect((viewers.body.data as unknown[]).length).toBe(1);
    // Reconciliation (a missed join webhook) treats it the same way.
    const { LiveMediaService } = await import('../src/modules/live/live-media.service.js');
    await ctx.app.get(LiveMediaService).reconcile();
    expect(await ctx.prisma.liveRoomViewer.count({ where: { roomId, identity } })).toBe(0);
    expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).viewerCount).toBe(1);
    // Leaving is a no-op for the audience.
    expect((await hook('participant_left', roomId, identity)).status).toBe(200);
    expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).viewerCount).toBe(1);

    const rows = (await audits('admin.live.watch', roomId)).filter((r) => r.actorUserId === moderator.id);
    expect(rows).toHaveLength(1);
    expect(rows[0]!.metadata).toMatchObject({ purpose: 'PREVIEW', identity, hostUserId: h.id, via: 'panel' });

    // A PK: the watch view also gets the other room.
    const other = await host();
    const otherRoom = await goLive(other);
    const inv = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/pk/invites`)
      .set(auth(h))
      .send({ toRoomId: otherRoom });
    expect(inv.status, JSON.stringify(inv.body)).toBe(201);
    const acc = await ctx.http
      .post(`/api/v1/live/rooms/${otherRoom}/pk/invites/${inv.body.id as string}/accept`)
      .set(auth(other));
    expect(acc.status, JSON.stringify(acc.body)).toBe(200);
    const pk = await apost(owner, `/admin/lives/${roomId}/watch-token`, { purpose: 'WATCH' });
    expect(pk.status, JSON.stringify(pk.body)).toBe(200);
    expectContract(pk, 'createAdminLiveWatchToken');
    expect(pk.body.opponent.roomId).toBe(otherRoom);
    expect(pk.body.opponent.identity).toMatch(/^staff:/);
    expect((await hook('participant_joined', otherRoom, pk.body.opponent.identity as string)).status).toBe(
      200,
    );
    expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: otherRoom } })).viewerCount).toBe(0);
    const watchRows = await audits('admin.live.watch', roomId);
    expect(watchRows).toHaveLength(3); // SUPPORT's, MODERATION's preview, OWNER's watch
    expect(watchRows.find((r) => r.actorUserId === owner.id)!.metadata).toMatchObject({
      purpose: 'WATCH',
      opponentRoomId: otherRoom,
    });

    // An ended live: no token, and a staff identity that joins anyway is removed.
    const ended = await ctx.http.post(`/api/v1/live/rooms/${otherRoom}/end`).set(auth(other));
    expect(ended.status, JSON.stringify(ended.body)).toBeLessThan(300);
    expectCode(await apost(owner, `/admin/lives/${otherRoom}/watch-token`, {}), 409, 'LIVE_ROOM_ENDED');
    await hook('participant_joined', otherRoom, `staff:${owner.id}:abcdefabcdef`);
    expect(media.removed.some((r) => r.room === otherRoom && r.identity.startsWith('staff:'))).toBe(true);
  });

  it('reported lives: LIVE_ROOM reports with a note (deduped), the host’s reports during the live, counts, the list and the chat before', async () => {
    const before = (await aget(owner, '/admin/live-reports/summary')).body as {
      rooms: number;
      reports: number;
    };
    const h = await host();
    const [r1, r2, r3] = [await signup(), await signup(), await signup()];
    // A report of the host BEFORE the live does not count for it.
    expect((await report(r3, { targetType: 'USER', targetId: h.username, reason: 'SPAM' })).status).toBe(201);
    advance(1000);
    const roomId = await goLive(h);
    const quiet = await host();
    const quietRoom = await goLive(quiet);
    for (const u of [r1, r2]) expect((await hook('participant_joined', roomId, u.id)).status).toBe(200);
    const say = async (u: TestUser, text: string) => {
      const res = await ctx.http
        .post(`/api/v1/live/rooms/${roomId}/chat`)
        .set(auth(u))
        .send({ text, clientId: randomUUID() });
      expect(res.status, JSON.stringify(res.body)).toBeLessThan(300);
      advance(1000);
    };
    await say(h, 'welcome');
    await say(r1, 'line one');
    await say(h, 'bad words here');
    const first = await report(r1, {
      targetType: 'LIVE_ROOM',
      targetId: roomId,
      reason: 'HARASSMENT',
      note: 'The host insults viewers',
    });
    expect(first.status, JSON.stringify(first.body)).toBe(201);
    expectContract(first, 'createReport');
    // The same reporter again: the open report comes back (200), not a second one.
    const again = await report(r1, { targetType: 'LIVE_ROOM', targetId: roomId, reason: 'HARASSMENT' });
    expect(again.status).toBe(200);
    expect(again.body.id).toBe(first.body.id);
    advance(1000);
    // An older app reports the host as a user during the live: it counts for the live too.
    expect((await report(r2, { targetType: 'USER', targetId: h.username, reason: 'NUDITY' })).status).toBe(
      201,
    );
    // The host cannot report their own live.
    expectCode(
      await report(h, { targetType: 'LIVE_ROOM', targetId: roomId, reason: 'SPAM' }),
      400,
      'VALIDATION_FAILED',
    );

    const summary = await aget(moderator, '/admin/live-reports/summary');
    expect(summary.status).toBe(200);
    expectContract(summary, 'getAdminLiveReportsSummary');
    expect(summary.body).toEqual({ rooms: before.rooms + 1, reports: before.reports + 2 });
    expectCode(await aget(finance, '/admin/live-reports/summary'), 403, 'AUTH_FORBIDDEN');
    // D250b: SUPPORT reads the reported lives (the red dots, the list, a live's reports) but cannot act.
    expect((await aget(support, '/admin/live-reports/summary')).body).toEqual(summary.body);
    const supportList = await aget(support, '/admin/lives?reported=true&pageSize=100');
    expect(supportList.status).toBe(200);
    expect((supportList.body.data as { id: string }[]).map((r) => r.id)).toContain(roomId);
    const supportReports = await aget(support, `/admin/lives/${roomId}/reports`);
    expect(supportReports.status).toBe(200);
    expectContract(supportReports, 'listAdminLiveReports');
    expect(supportReports.body.open).toBe(2);

    const list = await aget(moderator, '/admin/lives?reported=true&pageSize=100');
    expect(list.status, JSON.stringify(list.body)).toBe(200);
    expectContract(list, 'listAdminLives');
    const ids = (list.body.data as { id: string; openReports: number }[]).map((r) => r.id);
    expect(ids).toContain(roomId);
    expect(ids).not.toContain(quietRoom);
    expect(
      (list.body.data as { id: string; openReports: number }[]).find((r) => r.id === roomId)!.openReports,
    ).toBe(2);
    const all = await aget(moderator, '/admin/lives?pageSize=100');
    expect(
      (all.body.data as { id: string; openReports: number }[]).find((r) => r.id === quietRoom)!.openReports,
    ).toBe(0);

    const reports = await aget(moderator, `/admin/lives/${roomId}/reports`);
    expect(reports.status, JSON.stringify(reports.body)).toBe(200);
    expectContract(reports, 'listAdminLiveReports');
    expect(reports.body.open).toBe(2);
    const [userReport, roomReport] = reports.body.data as {
      targetType: string;
      reason: string;
      note: string | null;
      reporter: { id: string };
      chatBefore: { text: string; author: { id: string } }[];
    }[];
    expect(userReport!.targetType).toBe('USER');
    expect(userReport!.reporter.id).toBe(r2.id);
    expect(roomReport).toMatchObject({
      targetType: 'LIVE_ROOM',
      reason: 'HARASSMENT',
      note: 'The host insults viewers',
    });
    expect(roomReport!.reporter.id).toBe(r1.id);
    expect(roomReport!.chatBefore.map((l) => l.text)).toEqual(['welcome', 'line one', 'bad words here']);
    expect(roomReport!.chatBefore.at(-1)!.author.id).toBe(h.id);

    const chat = await aget(owner, `/admin/lives/${roomId}/chat`);
    expect(chat.status).toBe(200);
    expectContract(chat, 'listAdminLiveChat');
    expect((chat.body.data as { text: string }[]).map((l) => l.text)).toEqual([
      'welcome',
      'line one',
      'bad words here',
    ]);
    expectCode(await aget(finance, `/admin/lives/${roomId}/chat`), 403, 'AUTH_FORBIDDEN');
    expect((await aget(support, `/admin/lives/${roomId}/chat`)).status).toBe(200);

    // «تمت المراجعة — لا مخالفة»: the reason is required; the reports close as DISMISSED; no notification to the host.
    expectCode(
      await apost(moderator, `/admin/lives/${roomId}/reports/dismiss`, { reason: ' ' }),
      400,
      'VALIDATION_FAILED',
    );
    expectCode(
      await apost(support, `/admin/lives/${roomId}/reports/dismiss`, { reason: 'ok' }),
      403,
      'AUTH_FORBIDDEN',
    );
    const notesBefore = await ctx.prisma.notification.count({ where: { recipientId: h.id } });
    const dismissed = await apost(moderator, `/admin/lives/${roomId}/reports/dismiss`, {
      reason: 'Reviewed: no violation',
    });
    expect(dismissed.status, JSON.stringify(dismissed.body)).toBe(200);
    expectContract(dismissed, 'dismissAdminLiveReports');
    expect(dismissed.body).toMatchObject({ kind: 'DISMISS', reportsClosed: 2 });
    expect(await ctx.prisma.notification.count({ where: { recipientId: h.id } })).toBe(notesBefore);
    const closed = await ctx.prisma.report.findMany({ where: { id: first.body.id as string } });
    expect(closed[0]).toMatchObject({
      status: 'DISMISSED',
      resolvedById: moderator.id,
      resolutionNote: 'Reviewed: no violation',
    });
    // The report made before the live stays open (it is not this live's).
    expect(await ctx.prisma.report.count({ where: { reporterId: r3.id, status: 'OPEN' } })).toBe(1);
    expect((await aget(owner, '/admin/live-reports/summary')).body).toEqual(before);
    expectCode(
      await apost(moderator, `/admin/lives/${roomId}/reports/dismiss`, { reason: 'again' }),
      409,
      'ADMIN_ACTION_REFUSED',
    );
    const dismissAudit = await audits('admin.live.reports_dismiss', roomId);
    expect(dismissAudit).toHaveLength(1);
    expect(dismissAudit[0]!.metadata).toMatchObject({
      reason: 'Reviewed: no violation',
      reportsClosed: 2,
      via: 'panel',
    });
    const history = await aget(moderator, `/admin/lives/${roomId}/moderations`);
    expectContract(history, 'listAdminLiveModerations');
    expect(history.body.data[0]).toMatchObject({
      kind: 'DISMISS',
      reportsClosed: 2,
      actor: { id: moderator.id },
    });
  });

  it('END: a reason (required), the live ends, its reports are ACTIONED, one LIVE_MODERATED with the reason (in-app + push), audited', async () => {
    const h = await host();
    const roomId = await goLive(h);
    const reporter = await signup();
    expect(
      (await report(reporter, { targetType: 'LIVE_ROOM', targetId: roomId, reason: 'VIOLENCE' })).status,
    ).toBe(201);
    // The host's phone has a push token.
    const pushToken = `fcm_${randomUUID().replaceAll('-', '')}:APA91b${randomUUID().replaceAll('-', '')}`;
    expect(
      (
        await ctx.http
          .put('/api/v1/me/push-token')
          .set(auth(h))
          .send({ token: pushToken, platform: 'ANDROID', appVersion: '1.0.0' })
      ).status,
    ).toBe(204);
    const dispatcher = ctx.app.get(NotificationPushDispatcher);
    await dispatcher.dispatchOnce();

    for (const body of [
      { action: 'END' },
      { action: 'END', reason: '' },
      { action: 'END', reason: 'x', hours: 1 },
      { action: 'END', reason: 'x', totpCode: '123456' },
      { action: 'NO_LIVE', reason: 'x' },
      { action: 'SUSPEND', reason: 'x', permanent: true, hours: 1 },
      { action: 'DEVICE_BAN', reason: 'x', hours: 1 },
      { action: 'DEVICE_BAN', reason: 'x', totpCode: '123456' },
      { action: 'NUKE', reason: 'x' },
    ]) {
      expectCode(await apost(moderator, `/admin/lives/${roomId}/moderate`, body), 400, 'VALIDATION_FAILED');
    }
    for (const a of [support, finance]) {
      expectCode(
        await apost(a, `/admin/lives/${roomId}/moderate`, { action: 'END', reason: 'x' }),
        403,
        'AUTH_FORBIDDEN',
      );
    }
    const reason = 'Violence on camera — this breaks the rules';
    const res = await apost(moderator, `/admin/lives/${roomId}/moderate`, { action: 'END', reason });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'moderateAdminLive');
    expect(res.body).toMatchObject({
      kind: 'END',
      reason,
      endsAt: null,
      endedLive: true,
      reportsClosed: 1,
      devicesBanned: 0,
    });
    const room = await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } });
    expect(room).toMatchObject({ status: 'ENDED', endReason: 'ADMIN' });
    expect(media.closed).toContain(roomId);
    expect(
      await ctx.prisma.report.count({
        where: { targetLiveRoomId: roomId, status: 'ACTIONED', resolutionNote: reason },
      }),
    ).toBe(1);
    expectCode(
      await apost(moderator, `/admin/lives/${roomId}/moderate`, { action: 'END', reason }),
      409,
      'ADMIN_ACTION_REFUSED',
    );

    const inbox = await ctx.http.get('/api/v1/notifications').set(auth(h));
    expect(inbox.status).toBe(200);
    expectContract(inbox, 'listNotifications');
    const n = (inbox.body.data as { type: string; target: Record<string, unknown> }[]).find(
      (x) => x.type === 'LIVE_MODERATED',
    )!;
    expect(n.target).toMatchObject({
      type: 'LIVE_MODERATION',
      moderation: 'END',
      reason,
      text: reason,
      roomId,
    });
    expect(n.target.endsAt).toBeUndefined();
    fake.sent.length = 0;
    expect(await dispatcher.dispatchOnce()).toBeGreaterThanOrEqual(1);
    const push = fake.sent.find((m) => m.tokens.includes(pushToken))!;
    expect(push.body).toBe(`The Kabso team ended your live. Reason: ${reason}`);
    expect(push.data).toMatchObject({ type: 'LIVE_MODERATED', targetType: 'LIVE_MODERATION' });

    const rows = await audits('admin.live.moderate', roomId);
    expect(rows).toHaveLength(1);
    expect(rows[0]!.actorUserId).toBe(moderator.id);
    expect(rows[0]!.metadata).toMatchObject({
      kind: 'END',
      reason,
      endedLive: true,
      reportsClosed: 1,
      before: 'LIVE',
      after: 'ENDED',
      via: 'panel',
    });
  });

  it('NO_LIVE «منع من البث» 24 h: go-live refused with the end and the reason; sign-in still works; allowed again after the end', async () => {
    const h = await host();
    const roomId = await goLive(h);
    const reason = 'Repeated spam in the live title';
    const res = await apost(owner, `/admin/lives/${roomId}/moderate`, {
      action: 'NO_LIVE',
      reason,
      hours: 24,
    });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'moderateAdminLive');
    expect(res.body.endedLive).toBe(true);
    expect(Date.parse(res.body.endsAt as string)).toBe(clock + 24 * HOUR);
    const again = await ctx.http.post('/api/v1/live/rooms').set(auth(h)).send({ title: 'Back' });
    expectCode(again, 403, 'ACCOUNT_RESTRICTED');
    expectContract(again, 'startLiveRoom');
    expect(detail(again, 'restriction')).toBe('NO_LIVE');
    expect(detail(again, 'reason')).toBe(reason);
    expect(detail(again, 'until')).toBe(res.body.endsAt);
    expect((await login(h, h.deviceKey)).status).toBe(200);
    // The D208 restriction, without its own notification (one LIVE_MODERATED instead).
    const restriction = await ctx.prisma.accountRestriction.findFirstOrThrow({
      where: { userId: h.id, kind: 'NO_LIVE' },
    });
    expect(
      await ctx.prisma.notification.count({ where: { recipientId: h.id, type: 'ACCOUNT_RESTRICTED' } }),
    ).toBe(0);
    const inbox = await ctx.http.get('/api/v1/notifications').set(auth(h));
    const n = (inbox.body.data as { type: string; target: Record<string, unknown> }[]).find(
      (x) => x.type === 'LIVE_MODERATED',
    )!;
    expect(n.target).toMatchObject({
      moderation: 'NO_LIVE',
      reason,
      endsAt: restriction.endsAt.toISOString(),
    });
    // Ends by itself (the clock is read on every check).
    advance(24 * HOUR + 1000);
    expect((await ctx.http.post('/api/v1/live/rooms').set(auth(h)).send({ title: 'Back' })).status).toBe(201);
    await relogin();
  });

  it('SUSPEND «تعليق الحساب» 1 h: every session ends, sign-in refused with the end and the reason, then allowed', async () => {
    const h = await host();
    const roomId = await goLive(h);
    const reason = 'Nudity on camera';
    const res = await apost(moderator, `/admin/lives/${roomId}/moderate`, {
      action: 'SUSPEND',
      reason,
      hours: 1,
    });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expect(res.body).toMatchObject({ kind: 'SUSPEND', endedLive: true });
    expect(await ctx.prisma.session.count({ where: { userId: h.id, revokedAt: null } })).toBe(0);
    const refused = await login(h, h.deviceKey);
    expectCode(refused, 403, 'ACCOUNT_LOCKED');
    expectContract(refused, 'login');
    expect(detail(refused, 'reason')).toBe(reason);
    expect(detail(refused, 'lockedUntil')).toBe(res.body.endsAt);
    advance(HOUR + 1000);
    const ok = await login(h, h.deviceKey);
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    h.token = ok.body.tokens.accessToken as string;
    const inbox = await ctx.http.get('/api/v1/notifications').set(auth(h));
    const n = (inbox.body.data as { type: string; target: Record<string, unknown> }[]).find(
      (x) => x.type === 'LIVE_MODERATED',
    )!;
    expect(n.target).toMatchObject({ moderation: 'SUSPEND', reason });
    // A custom end (`until`) works too, and a team member is only for an OWNER.
    const roomB = await goLive(h);
    const until = new Date(clock + 3 * 86_400_000).toISOString();
    const custom = await apost(moderator, `/admin/lives/${roomB}/moderate`, {
      action: 'NO_LIVE',
      reason: 'custom',
      until,
    });
    expect(custom.status, JSON.stringify(custom.body)).toBe(200);
    expect(custom.body.endsAt).toBe(until);
    const far = await apost(moderator, `/admin/lives/${roomB}/moderate`, {
      action: 'NO_LIVE',
      reason: 'x',
      until: new Date(clock + 400 * 86_400_000).toISOString(),
    });
    expectCode(far, 400, 'VALIDATION_FAILED');
  });

  it('DEVICE_BAN «حظر جهاز»: the code again; every device of the host; sign-up, sign-in and go-live refused from them for any account; the list; lift', async () => {
    const signupKey = newDeviceKey();
    const phoneKey = newDeviceKey();
    const h = await host(signupKey);
    // The host also signs in from a second phone; another person shares the first phone.
    const second = await login(h, phoneKey);
    expect(second.status).toBe(200);
    const sibling = await signup(signupKey);
    const roomId = await goLive(h);
    const reporter = await signup();
    expect(
      (await report(reporter, { targetType: 'LIVE_ROOM', targetId: roomId, reason: 'ILLEGAL' })).status,
    ).toBe(201);

    // MODERATION may; SUPPORT never (no lives.moderate / devices.ban); the code is checked first.
    expectCode(
      await apost(support, `/admin/lives/${roomId}/moderate`, {
        action: 'DEVICE_BAN',
        reason: 'x',
        permanent: true,
        totpCode: '000000',
      }),
      403,
      'AUTH_FORBIDDEN',
    );
    const wrong = await apost(moderator, `/admin/lives/${roomId}/moderate`, {
      action: 'DEVICE_BAN',
      reason: 'x',
      permanent: true,
      totpCode: '000000',
    });
    expect([401, 403]).toContain(wrong.status);
    expect(await ctx.prisma.deviceBan.count({ where: { sourceUserId: h.id } })).toBe(0);
    expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).status).toBe('LIVE');

    const reason = 'Illegal content; ban evasion';
    const res = await apost(moderator, `/admin/lives/${roomId}/moderate`, {
      action: 'DEVICE_BAN',
      reason,
      hours: 7 * 24,
      totpCode: nextCode(moderator.secret),
    });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'moderateAdminLive');
    expect(res.body).toMatchObject({
      kind: 'DEVICE_BAN',
      endedLive: true,
      reportsClosed: 1,
      devicesBanned: 2,
    });
    // Both phones' sessions ended — the sibling's too (the same phone).
    expect(res.body.sessionsEnded).toBeGreaterThanOrEqual(3);
    expect(await ctx.prisma.session.count({ where: { userId: sibling.id, revokedAt: null } })).toBe(0);
    const bans = await ctx.prisma.deviceBan.findMany({ where: { sourceUserId: h.id } });
    expect(bans).toHaveLength(2);
    for (const b of bans) {
      expect(b.deviceHash).toMatch(/^[0-9a-f]{64}$/);
      expect([signupKey, phoneKey]).not.toContain(b.deviceHash);
    }

    // Sign-up from the banned phone (any email): refused, no code mailed.
    const reg = await register(signupKey);
    expectCode(reg.res, 403, 'DEVICE_BANNED');
    expectContract(reg.res, 'register');
    expect(detail(reg.res, 'reason')).toBe(reason);
    expect(detail(reg.res, 'until')).toBe(res.body.endsAt);
    expect(ctx.mail.sent.length).toBe(reg.before);
    // Sign-in from either phone: refused for the host and for the sibling.
    for (const [u, key] of [
      [h, signupKey],
      [h, phoneKey],
      [sibling, signupKey],
    ] as const) {
      const r = await login(u, key);
      expectCode(r, 403, 'DEVICE_BANNED');
      expectContract(r, 'login');
    }
    // Honest limit: without a device key (the website, an older app) nothing is checked.
    const web = await login(h, null);
    expect(web.status).toBe(200);
    // Going live from a session on a banned device (e.g. created before the key was known) is refused.
    const webToken = web.body.tokens.accessToken as string;
    const webSession = await ctx.prisma.session.findFirstOrThrow({
      where: { userId: h.id, revokedAt: null },
      orderBy: { createdAt: 'desc' },
    });
    await withMigrationClient((db) =>
      db.session.update({ where: { id: webSession.id }, data: { deviceHash: bans[0]!.deviceHash } }),
    );
    const live = await ctx.http
      .post('/api/v1/live/rooms')
      .set({ Authorization: `Bearer ${webToken}` })
      .send({ title: 'x' });
    expectCode(live, 403, 'DEVICE_BANNED');
    expectContract(live, 'startLiveRoom');
    expect((await audits('auth.device_banned')).map((a) => (a.metadata as { stage: string }).stage)).toEqual(
      expect.arrayContaining(['register', 'live']),
    );
    expect(
      (await audits('auth.login.failure')).filter(
        (a) => (a.metadata as { reason?: string }).reason === 'device_banned',
      ).length,
    ).toBeGreaterThanOrEqual(3);

    // The host's notification carries the reason and the end.
    const inbox = await ctx.http.get('/api/v1/notifications').set({ Authorization: `Bearer ${webToken}` });
    const n = (inbox.body.data as { type: string; target: Record<string, unknown> }[]).find(
      (x) => x.type === 'LIVE_MODERATED',
    )!;
    expect(n.target).toMatchObject({ moderation: 'DEVICE_BAN', reason, endsAt: res.body.endsAt });

    // The list (devices.ban: OWNER, MODERATION), named by the account; never the hash.
    expectCode(await aget(support, '/admin/device-bans'), 403, 'AUTH_FORBIDDEN');
    const list = await aget(moderator, '/admin/device-bans?status=ACTIVE&pageSize=100');
    expect(list.status, JSON.stringify(list.body)).toBe(200);
    expectContract(list, 'listAdminDeviceBans');
    const mine = (
      list.body.data as { id: string; account: { id: string }; reason: string; liveRoomId: string }[]
    ).filter((r) => r.account.id === h.id);
    expect(mine).toHaveLength(2);
    expect(mine[0]).toMatchObject({ reason, liveRoomId: roomId });
    expect(JSON.stringify(list.body)).not.toContain(bans[0]!.deviceHash);
    const audit = await audits('admin.device_ban.create', h.id);
    expect(audit).toHaveLength(1);
    expect(audit[0]!.metadata).toMatchObject({ reason, devices: 2, via: 'panel' });

    // Lift the second phone's ban (a reason): that phone works again; the sign-up phone stays banned.
    const hmac = deviceHmacKey(ctx.config.registration.deviceKey ?? ctx.config.rateLimitKeySecret);
    const phoneBan = bans.find((b) => b.deviceHash === deviceHashOf(hmac, phoneKey))!;
    const otherBan = bans.find((b) => b.deviceHash === deviceHashOf(hmac, signupKey))!;
    expect(phoneBan).toBeDefined();
    expect(otherBan).toBeDefined();
    expectCode(
      await apost(moderator, `/admin/device-bans/${phoneBan.id}/lift`, { reason: '' }),
      400,
      'VALIDATION_FAILED',
    );
    expectCode(
      await apost(support, `/admin/device-bans/${phoneBan.id}/lift`, { reason: 'x' }),
      403,
      'AUTH_FORBIDDEN',
    );
    const lifted = await apost(moderator, `/admin/device-bans/${phoneBan.id}/lift`, {
      reason: 'Appeal accepted',
    });
    expect(lifted.status, JSON.stringify(lifted.body)).toBe(200);
    expectContract(lifted, 'liftAdminDeviceBan');
    expectCode(
      await apost(moderator, `/admin/device-bans/${phoneBan.id}/lift`, { reason: 'again' }),
      409,
      'ADMIN_ACTION_REFUSED',
    );
    expect((await login(h, phoneKey)).status).toBe(200);
    expectCode(await login(h, signupKey), 403, 'DEVICE_BANNED');
    const stillKey = signupKey;
    expect((await audits('admin.device_ban.lift', phoneBan.id))[0]!.metadata).toMatchObject({
      reason: 'Appeal accepted',
    });
    // The ban ends by itself at its end.
    advance(7 * 24 * HOUR + 1000);
    expect((await login(h, stillKey)).status).toBe(200);
    await relogin();
    const expired = await aget(owner, '/admin/device-bans?status=EXPIRED&pageSize=100');
    expect((expired.body.data as { id: string }[]).map((r) => r.id)).toContain(otherBan.id);
  });

  it('a host with no known device: DEVICE_BAN refused (409 no_device) and nothing changes; permanent bans have no end', async () => {
    const h = await host(null);
    const roomId = await goLive(h);
    const res = await apost(owner, `/admin/lives/${roomId}/moderate`, {
      action: 'DEVICE_BAN',
      reason: 'x',
      permanent: true,
      totpCode: nextCode(owner.secret),
    });
    expectCode(res, 409, 'ADMIN_ACTION_REFUSED');
    expect(detail(res, 'device')).toBe('no_device');
    expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).status).toBe('LIVE');

    const key = newDeviceKey();
    const p = await host(key);
    const room2 = await goLive(p);
    const perm = await apost(owner, `/admin/lives/${room2}/moderate`, {
      action: 'DEVICE_BAN',
      reason: 'Permanent ban',
      permanent: true,
      totpCode: nextCode(owner.secret),
    });
    expect(perm.status, JSON.stringify(perm.body)).toBe(200);
    expect(perm.body.endsAt).toBeNull();
    const r = await login(p, key);
    expectCode(r, 403, 'DEVICE_BANNED');
    expect(detail(r, 'until')).toBe('permanent');
    const inbox = await ctx.http.get('/api/v1/notifications').set(auth(p));
    void inbox; // the session ended with the ban
    const n = await ctx.prisma.notification.findFirstOrThrow({
      where: { recipientId: p.id, type: 'LIVE_MODERATED' },
      include: { liveModeration: true },
    });
    expect(n.liveModeration).toMatchObject({ kind: 'DEVICE_BAN', endsAt: null, devicesBanned: 1 });
  });

  it('permissions: never one’s own live; a team member’s live only by an OWNER', async () => {
    // A moderator who is also a host.
    await ctx.prisma.liveHost.create({ data: { userId: moderator.id, source: 'ADMIN' } });
    const modLogin = await ctx.http
      .post('/api/v1/auth/login')
      .send({ identifier: moderator.email, password: moderator.password });
    expect(modLogin.status, JSON.stringify(modLogin.body)).toBe(200);
    const roomId = await goLive({ ...moderator, token: modLogin.body.tokens.accessToken as string });
    expectCode(
      await apost(moderator, `/admin/lives/${roomId}/moderate`, { action: 'END', reason: 'x' }),
      409,
      'ADMIN_ACTION_REFUSED',
    );
    const other = await makeAdmin(['MODERATION']);
    expectCode(
      await apost(other, `/admin/lives/${roomId}/moderate`, { action: 'END', reason: 'x' }),
      403,
      'AUTH_FORBIDDEN',
    );
    const byOwner = await apost(owner, `/admin/lives/${roomId}/moderate`, {
      action: 'END',
      reason: 'Team test',
    });
    expect(byOwner.status, JSON.stringify(byOwner.body)).toBe(200);
    // Unknown live: 404.
    expectCode(
      await apost(owner, `/admin/lives/${randomUUID()}/moderate`, { action: 'END', reason: 'x' }),
      404,
      'NOT_FOUND',
    );
    expectCode(await aget(owner, `/admin/lives/${randomUUID()}/reports`), 404, 'NOT_FOUND');
  });
});
