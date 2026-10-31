/**
 * D209 (owner 2026-10-31; contract v1.73-social, CONVENTIONS §10.68): «كن مضيفاً مع الإدارة» — on «الوكالة», a person
 * who is not a host and in no agency applies to host directly with the Kabso team (the name, country, date of birth
 * ≥ 18, contact, bio, links, the mandatory ID card + selfie as the D185 private uploads, the host rules accepted). The
 * team approves in the panel («طلبات المضيفين») or with `host-admin` — the hosting permission with source IDENTITY, so
 * the person can go live — or rejects with a reason and a 30-day wait. Also the agencies (a join cancels a pending
 * application; a direct host who joins keeps the permission and counts in a D206 probation), the capabilities, the
 * audit and the CLI. End to end against PostgreSQL + Redis.
 */
import { execFile } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { promisify } from 'node:util';
import sharp from 'sharp';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { notificationBody } from '../src/modules/push/push-texts.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, openapi, operations } from './helpers/openapi.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

const run = promisify(execFile);
const DAY = 86_400_000;
const COOKIE = '__Host-kabso_admin';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly password: string;
  readonly token: string;
}
interface Admin extends TestUser {
  secret: string;
  cookie: string;
  csrf: string;
}
interface Mine {
  host: { source: string; grantedAt: string } | null;
  application: {
    id: string;
    status: string;
    displayName: string;
    country: string;
    createdAt: string;
    decidedAt: string | null;
    rejectReason: string | null;
    cancelReason: string | null;
    reapplyAt: string | null;
  } | null;
  rule: { canApply: boolean; refusal: string | null; minAge: number; reapplyDays: number };
}

/** YYYY-MM-DD of `years` years before `at` (UTC), plus `days`. */
function birthday(at: number, years: number, days = 0): string {
  const d = new Date(at);
  d.setUTCFullYear(d.getUTCFullYear() - years);
  return new Date(d.getTime() + days * DAY).toISOString().slice(0, 10);
}

describe('D209 contract coverage', () => {
  it('openapi v1.73-social declares the application, its states and «طلبات المضيفين»', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'getMyHostingApplication GET /api/v1/me/hosting-application',
        'applyForHosting POST /api/v1/me/hosting-application',
        'cancelMyHostingApplication POST /api/v1/me/hosting-application/cancel',
        'listAdminHostApplications GET /api/v1/admin/host-applications',
        'getAdminHostApplication GET /api/v1/admin/host-applications/{applicationId}',
        'getAdminHostApplicationPhoto GET /api/v1/admin/host-applications/{applicationId}/photos/{which}',
        'approveAdminHostApplication POST /api/v1/admin/host-applications/{applicationId}/approve',
        'rejectAdminHostApplication POST /api/v1/admin/host-applications/{applicationId}/reject',
      ]),
    );
    const schemas = (openapi.components as { schemas: Record<string, Record<string, unknown>> }).schemas;
    expect(schemas.HostingApplicationRequest!.required).toEqual(
      expect.arrayContaining(['dateOfBirth', 'acceptRules', 'photoUploadId', 'selfieUploadId']),
    );
    expect((schemas.NotificationType as { enum: string[] }).enum).toEqual(
      expect.arrayContaining(['HOST_APPLICATION_APPROVED', 'HOST_APPLICATION_REJECTED']),
    );
    for (const o of operations().filter((x) => x.path.startsWith('/api/v1/admin/host-applications'))) {
      expect(o.spec.security).toEqual([{ adminSession: [] }]);
      if (o.method !== 'get') expect(JSON.stringify(o.spec.parameters)).toContain('AdminCsrf');
    }
  });

  it('the push texts exist in both languages and never carry the reason', () => {
    for (const type of ['HOST_APPLICATION_APPROVED', 'HOST_APPLICATION_REJECTED']) {
      const n = { type, actorName: null, actorCount: 0, targetType: null, targetId: null, targetText: null };
      expect(notificationBody(n, 'ar')).toBeTruthy();
      expect(notificationBody(n, 'en')).toBeTruthy();
    }
  });
});

describe('D209 «كن مضيفاً مع الإدارة»', { timeout: 600_000 }, () => {
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  let png: Buffer;
  let clock = Date.now();
  const setNow = (ms: number) => {
    clock = ms;
    vi.setSystemTime(clock);
  };
  const advance = (ms: number) => setNow(clock + ms);

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: String(payload.email).trim().toLowerCase(),
      password: payload.password,
      token: res.body.tokens.accessToken as string,
    };
  };
  const upload = async (u: TestUser, kind: string): Promise<string> => {
    const slot = await ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send({ kind, contentType: 'image/png', byteSize: png.length });
    expect(slot.status, JSON.stringify(slot.body)).toBe(201);
    expect(storage.upload(slot.body.uploadUrl as string, png, 'image/png')).toBe(true);
    return slot.body.uploadId as string;
  };
  const form = async (u: TestUser, extra: Record<string, unknown> = {}) => ({
    displayName: 'سارة المضيفة',
    country: 'sa',
    dateOfBirth: birthday(clock, 25),
    contact: { type: 'WHATSAPP', value: '+966511111111' },
    bio: 'أبث الطبخ والدردشة كل مساء',
    links: ['https://www.tiktok.com/@sara'],
    acceptRules: true,
    photoUploadId: await upload(u, 'RECHARGE_AGENT_PHOTO'),
    selfieUploadId: await upload(u, 'RECHARGE_AGENT_SELFIE'),
    ...extra,
  });
  const apply = (u: TestUser, body: object, key: string | null = randomUUID()) => {
    const r = ctx.http.post('/api/v1/me/hosting-application').set(auth(u));
    return (key === null ? r : r.set('Idempotency-Key', key)).send(body);
  };
  const applied = async (u: TestUser): Promise<Mine> => {
    const res = await apply(u, await form(u));
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body as Mine;
  };
  const mine = async (u: TestUser): Promise<Mine> => {
    const res = await ctx.http.get('/api/v1/me/hosting-application').set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getMyHostingApplication');
    return res.body as Mine;
  };
  const issueOf = (res: request.Response) =>
    (res.body as { error: { details?: { issue: string }[] } }).error.details?.[0]?.issue;
  const notifications = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/notifications').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'listNotifications');
    return res.body.data as { type: string; target: unknown }[];
  };
  const openAgency = async (u: TestUser, name: string): Promise<string> => {
    const body = {
      name,
      country: 'SA',
      contact: { type: 'WHATSAPP', value: '+966500000001' },
      expectedHosts: 5,
      photoUploadId: await upload(u, 'RECHARGE_AGENT_PHOTO'),
      selfieUploadId: await upload(u, 'RECHARGE_AGENT_SELFIE'),
    };
    const res = await ctx.http
      .post('/api/v1/me/agency/open')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send(body);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.ownAgency.inviteCode as string;
  };
  const goLive = (u: TestUser) =>
    ctx.http.post('/api/v1/live/rooms').set(auth(u)).send({ title: 'مع الإدارة' });

  // ---- the panel ---------------------------------------------------------------------------------------------
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
    const secret = enrol.body.secret as string;
    const confirm = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment/confirm')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf)
      .send({ code: nextCode(secret) });
    expect(confirm.status, JSON.stringify(confirm.body)).toBe(200);
    return { ...p, secret, cookie: cookieOf(confirm), csrf: confirm.body.session.csrfToken as string };
  };
  const get = (a: Admin, path: string) => ctx.http.get(`/api/v1${path}`).set('Cookie', a.cookie);
  const post = (a: Admin, path: string, body: object = {}) =>
    ctx.http.post(`/api/v1${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf).send(body);

  let owner: Admin;
  let support: Admin;
  let moderator: Admin;
  let finance: Admin;

  beforeAll(async () => {
    png = await sharp({
      create: { width: 64, height: 64, channels: 3, background: { r: 30, g: 120, b: 200 } },
    })
      .png()
      .toBuffer();
    vi.useFakeTimers({ toFake: ['Date'], now: clock });
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        MEDIA_UPLOADS_ENABLED: 'true',
        S3_BUCKET: 'kabso-media-test',
        S3_ACCESS_KEY_ID: 'test',
        S3_SECRET_ACCESS_KEY: 'test',
        MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
        LIVE_RANKINGS_TIME_ZONE: 'UTC',
        RECHARGE_AGENT_SWEEP_INTERVAL_SECONDS: '0',
        SPECIAL_USERNAME_SWEEP_INTERVAL_SECONDS: '0',
        AGENCY_SWEEP_INTERVAL_SECONDS: '0',
        RATE_LIMIT_HOST_APPLY_USER: '1000/900',
        RATE_LIMIT_AGENCY_OPEN_USER: '1000/900',
        // The 30-day wait passes on the fake clock: the people's tokens must outlive it.
        JWT_ACCESS_TTL_SECONDS: String(400 * 86_400),
        REFRESH_TTL_SECONDS: String(400 * 86_400),
        REFRESH_ABSOLUTE_TTL_SECONDS: String(400 * 86_400),
        ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        ADMIN_SESSION_MAX_SECONDS: '604800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '100000/900',
      },
      [
        { token: OBJECT_STORAGE, value: storage },
        { token: LIVE_MEDIA_PROVIDER, value: new MemoryLiveMedia() },
      ],
    );
    owner = await makeAdmin(['OWNER']);
    support = await makeAdmin(['SUPPORT']);
    moderator = await makeAdmin(['MODERATION']);
    finance = await makeAdmin(['FINANCE']);
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('applies with the ID check: 400s, a stolen upload, under 18, idempotency, one pending, audited without private data', async () => {
    const u = await signup();
    const before = await mine(u);
    expect(before).toEqual({
      host: null,
      application: null,
      rule: { canApply: true, refusal: null, minAge: 18, reapplyDays: 30 },
    });

    const body = await form(u);
    const noKey = await apply(u, body, null);
    expect(noKey.status).toBe(400);
    expect(noKey.body.error.details).toEqual([{ field: 'Idempotency-Key', issue: 'required' }]);
    expectContract(noKey, 'applyForHosting');
    for (const bad of [
      { ...body, acceptRules: false },
      { ...body, acceptRules: undefined },
      { ...body, dateOfBirth: '2001-02-30' },
      { ...body, dateOfBirth: '1899-12-31' },
      { ...body, country: 'SAU' },
      { ...body, bio: 'short' },
      { ...body, bio: 'x'.repeat(301) },
      { ...body, links: ['http://insecure.example.com/me'] },
      {
        ...body,
        links: [
          'https://a.example.com',
          'https://b.example.com',
          'https://c.example.com',
          'https://d.example.com',
        ],
      },
      { ...body, contact: { type: 'FAX', value: '123456' } },
      { ...body, displayName: '' },
      { ...body, extra: true },
    ]) {
      const res = await apply(u, bad);
      expect(res.status, JSON.stringify(bad)).toBe(400);
    }
    // Someone else's upload is refused (and nothing is created).
    const thief = await signup();
    const stolen = await apply(thief, { ...(await form(thief)), photoUploadId: body.photoUploadId });
    expect(stolen.status).toBe(400);
    expect(stolen.body.error.details).toEqual([{ field: 'photoUploadId', issue: 'invalid_value' }]);
    expect(await ctx.prisma.hostApplication.count({ where: { userId: thief.id } })).toBe(0);

    // Younger than 18 today (UTC): refused, nothing kept; the 18th birthday today is accepted.
    const young = await signup();
    const tooYoung = await apply(young, await form(young, { dateOfBirth: birthday(clock, 18, 1) }));
    expect(tooYoung.status).toBe(409);
    expect(tooYoung.body.error.code).toBe('HOST_APPLICATION_NOT_ALLOWED');
    expect(issueOf(tooYoung)).toBe('UNDER_MIN_AGE');
    expectContract(tooYoung, 'applyForHosting');
    expect(await ctx.prisma.hostApplication.count({ where: { userId: young.id } })).toBe(0);
    const eighteen = await apply(young, await form(young, { dateOfBirth: birthday(clock, 18) }));
    expect(eighteen.status, JSON.stringify(eighteen.body)).toBe(201);

    const key = randomUUID();
    const res = await apply(u, body, key);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'applyForHosting');
    const m = res.body as Mine;
    expect(m.host).toBeNull();
    expect(m.application).toMatchObject({
      status: 'PENDING',
      displayName: 'سارة المضيفة',
      country: 'SA',
      decidedAt: null,
      rejectReason: null,
      reapplyAt: null,
    });
    expect(m.rule).toMatchObject({ canApply: false, refusal: 'PENDING' });
    // The response carries no private field.
    expect(JSON.stringify(m)).not.toContain('+966511111111');

    // The same key again: the same answer (200); with another body: 409.
    const again = await apply(u, body, key);
    expect(again.status).toBe(200);
    expect(again.body.application.id).toBe(m.application!.id);
    const conflict = await apply(u, { ...body, bio: 'شيء آخر تماماً هنا' }, key);
    expect(conflict.status).toBe(409);
    expect(conflict.body.error.code).toBe('IDEMPOTENCY_CONFLICT');
    // One pending application per user.
    const second = await apply(u, await form(u));
    expect(second.status).toBe(409);
    expect(issueOf(second)).toBe('PENDING');

    const row = await ctx.prisma.hostApplication.findUniqueOrThrow({ where: { id: m.application!.id } });
    expect(row.photoKey).toBe(`private/host-applications/${row.id}/photo.webp`);
    expect(row.selfieKey).toBe(`private/host-applications/${row.id}/selfie.webp`);
    expect(await storage.get(row.photoKey!, 1 << 24)).not.toBeNull();
    expect(row.dateOfBirth?.toISOString().slice(0, 10)).toBe(body.dateOfBirth);
    expect(row.links).toEqual(['https://www.tiktok.com/@sara']);
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'host.application.submit', targetId: row.id },
    });
    expect(audit.actorUserId).toBe(u.id);
    const trail = JSON.stringify(audit.metadata);
    expect(trail).not.toContain('+966511111111');
    expect(trail).not.toContain(body.dateOfBirth);
  });

  it('cancels a pending application (then may apply again at once); nothing pending → 404', async () => {
    const u = await signup();
    await applied(u);
    const res = await ctx.http.post('/api/v1/me/hosting-application/cancel').set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'cancelMyHostingApplication');
    expect(res.body.application).toMatchObject({ status: 'CANCELLED', cancelReason: 'USER' });
    expect(res.body.rule).toMatchObject({ canApply: true, refusal: null });
    const none = await ctx.http.post('/api/v1/me/hosting-application/cancel').set(auth(u));
    expect(none.status).toBe(404);
    expect(
      await ctx.prisma.auditLog.count({
        where: { action: 'host.application.cancel', targetId: res.body.application.id as string },
      }),
    ).toBe(1);
    const back = await applied(u);
    expect(back.application?.status).toBe('PENDING');
  });

  it('approve from the panel → source IDENTITY, can go live, notified, audited; the panel views are audited', async () => {
    const u = await signup();
    const m = await applied(u);
    const appId = m.application!.id;
    // Not a host yet: going live is refused.
    const early = await goLive(u);
    expect(early.status).toBe(403);
    expect(early.body.error.code).toBe('LIVE_HOSTING_NOT_ALLOWED');

    // The list (no private field), the filters.
    const list = await get(moderator, '/admin/host-applications?status=PENDING&pageSize=100');
    expect(list.status, JSON.stringify(list.body)).toBe(200);
    expectContract(list, 'listAdminHostApplications');
    expect(list.body.data.find((r: { id: string }) => r.id === appId)).toMatchObject({
      status: 'PENDING',
      displayName: 'سارة المضيفة',
      country: 'SA',
      user: { id: u.id, username: u.username },
      decidedBy: null,
    });
    expect(JSON.stringify(list.body)).not.toContain('+966511111111');
    const rejectedOnly = await get(moderator, '/admin/host-applications?status=REJECTED&pageSize=100');
    expect(rejectedOnly.body.data.find((r: { id: string }) => r.id === appId)).toBeUndefined();
    const byName = await get(support, `/admin/host-applications?q=${u.username}`);
    expect(byName.body.data.map((r: { id: string }) => r.id)).toContain(appId);
    const csv = await get(owner, '/admin/host-applications?format=csv&status=PENDING');
    expect(csv.status).toBe(200);
    expect(csv.headers['content-type']).toContain('text/csv');
    expect(csv.text).not.toContain('+966511111111');

    // The detail (audited) with the account summary; MODERATION may read it.
    const reporter = await signup();
    const report = await ctx.http
      .post('/api/v1/reports')
      .set(auth(reporter))
      .send({ targetType: 'USER', targetId: u.username, reason: 'SPAM' });
    expect([201, 200]).toContain(report.status);
    const detail = await get(moderator, `/admin/host-applications/${appId}`);
    expect(detail.status, JSON.stringify(detail.body)).toBe(200);
    expectContract(detail, 'getAdminHostApplication');
    expect(detail.body).toMatchObject({
      status: 'PENDING',
      displayName: 'سارة المضيفة',
      age: 25,
      contact: { type: 'WHATSAPP', value: '+966511111111' },
      links: ['https://www.tiktok.com/@sara'],
      photos: { photo: true, selfie: true },
      account: {
        id: u.id,
        status: 'ACTIVE',
        openReports: 1,
        totalReports: 1,
        bans: 0,
        host: null,
        agency: null,
      },
    });
    expect(detail.body.account.accountAgeDays).toBeGreaterThanOrEqual(0);
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'host.application.view', targetId: appId } }),
    ).toBe(1);

    // The pictures: OWNER / SUPPORT only, each view audited; MODERATION and FINANCE refused.
    expect((await get(moderator, `/admin/host-applications/${appId}/photos/photo`)).status).toBe(403);
    expect((await get(finance, '/admin/host-applications')).status).toBe(403);
    expect((await get(finance, `/admin/host-applications/${appId}`)).status).toBe(403);
    const photo = await get(support, `/admin/host-applications/${appId}/photos/selfie`);
    expect(photo.status).toBe(200);
    expect(photo.headers['cache-control']).toBe('private, no-store');
    expect(photo.headers['content-type']).toBe('image/webp');
    expect((await get(support, `/admin/host-applications/${appId}/photos/other`)).status).toBe(404);
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'host.application.photo.view', targetId: appId } }),
    ).toBe(1);

    // MODERATION may not decide; no CSRF → 403; SUPPORT approves (no authenticator code).
    expect((await post(moderator, `/admin/host-applications/${appId}/approve`)).status).toBe(403);
    const noCsrf = await ctx.http
      .post(`/api/v1/admin/host-applications/${appId}/approve`)
      .set('Cookie', support.cookie);
    expect(noCsrf.status).toBe(403);
    const ok = await post(support, `/admin/host-applications/${appId}/approve`);
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    expectContract(ok, 'approveAdminHostApplication');
    expect(ok.body).toEqual({ status: 'APPROVED', source: 'IDENTITY' });
    const host = await ctx.prisma.liveHost.findUniqueOrThrow({ where: { userId: u.id } });
    expect(host).toMatchObject({ source: 'IDENTITY', grantedById: support.id });
    const twice = await post(owner, `/admin/host-applications/${appId}/approve`);
    expect(twice.status).toBe(409);
    expect(twice.body.error.code).toBe('ADMIN_ACTION_REFUSED');

    // The person: approved, a host directly with the team, can go live, notified.
    const after = await mine(u);
    expect(after.host).toMatchObject({ source: 'IDENTITY' });
    expect(after.application).toMatchObject({ status: 'APPROVED' });
    expect(after.rule).toMatchObject({ canApply: false, refusal: 'ALREADY_HOST' });
    const me = await ctx.http.get('/api/v1/me').set(auth(u));
    expect(me.body.canHost).toBe(true);
    const live = await goLive(u);
    expect(live.status, JSON.stringify(live.body)).toBe(201);
    await ctx.http.post(`/api/v1/live/rooms/${live.body.id as string}/end`).set(auth(u));
    expect((await notifications(u)).map((n) => n.type)).toContain('HOST_APPLICATION_APPROVED');
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'host.application.approve', targetId: appId },
    });
    expect(audit.actorUserId).toBe(support.id);
    expect(audit.metadata).toMatchObject({ source: 'IDENTITY', via: 'panel', before: 'PENDING' });
    expect(await ctx.prisma.auditLog.count({ where: { action: 'live.host.grant', targetId: u.id } })).toBe(1);
    // The panel's hosting permissions list shows the source.
    const hosts = await get(owner, '/admin/live-hosts?source=IDENTITY&pageSize=100');
    expect(hosts.status).toBe(200);
    expect(JSON.stringify(hosts.body)).toContain(u.username);
  });

  it('reject with a reason → notified; 30 days before applying again; the reason is required', async () => {
    const u = await signup();
    const m = await applied(u);
    const appId = m.application!.id;
    const noReason = await post(owner, `/admin/host-applications/${appId}/reject`, { reason: '' });
    expect(noReason.status).toBe(400);
    const res = await post(owner, `/admin/host-applications/${appId}/reject`, { reason: 'الصورة غير واضحة' });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'rejectAdminHostApplication');
    const decided = clock;
    const after = await mine(u);
    expect(after.host).toBeNull();
    expect(after.application).toMatchObject({ status: 'REJECTED', rejectReason: 'الصورة غير واضحة' });
    expect(Date.parse(after.application!.reapplyAt!)).toBe(decided + 30 * DAY);
    expect(after.rule).toMatchObject({ canApply: false, refusal: 'REAPPLY_COOLDOWN' });
    expect((await notifications(u)).map((n) => n.type)).toContain('HOST_APPLICATION_REJECTED');
    const cooling = await apply(u, await form(u));
    expect(cooling.status).toBe(409);
    expect(issueOf(cooling)).toBe('REAPPLY_COOLDOWN');
    expect((await post(owner, `/admin/host-applications/${appId}/approve`)).status).toBe(409);
    expect(await ctx.prisma.liveHost.count({ where: { userId: u.id } })).toBe(0);
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'host.application.reject', targetId: appId },
    });
    expect(audit.metadata).toMatchObject({ reason: 'الصورة غير واضحة', via: 'panel' });

    advance(30 * DAY - 60_000);
    expect((await mine(u)).rule.refusal).toBe('REAPPLY_COOLDOWN');
    advance(60_000);
    expect((await mine(u)).rule).toMatchObject({ canApply: true, refusal: null });
    const again = await applied(u);
    expect(again.application?.status).toBe('PENDING');
    // The panel sessions ended during the 30 days: sign in again.
    owner = await makeAdmin(['OWNER']);
    // The panel shows the earlier one in the history.
    const detail = await get(owner, `/admin/host-applications/${again.application!.id}`);
    expect(detail.body.history).toEqual([
      expect.objectContaining({ id: appId, status: 'REJECTED', rejectReason: 'الصورة غير واضحة' }),
    ]);
  });

  it('refuses a host (any source), an agency host and an agency owner; a join cancels a pending application', async () => {
    const opener = await signup();
    const code = await openAgency(opener, 'وكالة الاختبار');
    expect((await mine(opener)).rule.refusal).toBe('OWNS_AGENCY');
    const ownerTry = await apply(opener, await form(opener));
    expect(ownerTry.status).toBe(409);
    expect(issueOf(ownerTry)).toBe('OWNS_AGENCY');

    const member = await signup();
    await ctx.http.post('/api/v1/me/agency/join').set(auth(member)).send({ inviteCode: code }).expect(201);
    expect((await mine(member)).rule.refusal).toBe('HOST_OF_AGENCY');
    expect(issueOf(await apply(member, await form(member)))).toBe('HOST_OF_AGENCY');

    const granted = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: granted.id, source: 'ADMIN' } });
    expect((await mine(granted)).host).toMatchObject({ source: 'ADMIN' });
    expect(issueOf(await apply(granted, await form(granted)))).toBe('ALREADY_HOST');

    // A pending application goes when the person joins an agency.
    const switcher = await signup();
    const m = await applied(switcher);
    await ctx.http.post('/api/v1/me/agency/join').set(auth(switcher)).send({ inviteCode: code }).expect(201);
    const after = await mine(switcher);
    expect(after.application).toMatchObject({
      id: m.application!.id,
      status: 'CANCELLED',
      cancelReason: 'AGENCY',
    });
    expect((await post(owner, `/admin/host-applications/${m.application!.id}/approve`)).status).toBe(409);
  });

  it('a direct host who joins an agency later keeps the permission (source unchanged) and counts in its probation', async () => {
    const u = await signup();
    const m = await applied(u);
    expect((await post(owner, `/admin/host-applications/${m.application!.id}/approve`)).status).toBe(200);

    const opener = await signup();
    const code = await openAgency(opener, 'وكالة التجربة');
    advance(1000);
    await ctx.http.post('/api/v1/me/agency/join').set(auth(u)).send({ inviteCode: code }).expect(201);
    const host = await ctx.prisma.liveHost.findUniqueOrThrow({ where: { userId: u.id } });
    expect(host.source).toBe('IDENTITY');
    expect((await mine(u)).host).toMatchObject({ source: 'IDENTITY' });

    // Goes live and receives a gift after joining: activated, like any other host (D206).
    advance(1000);
    const live = await goLive(u);
    expect(live.status, JSON.stringify(live.body)).toBe(201);
    advance(1000);
    await ctx.prisma.cherryLedgerEntry.create({
      data: {
        userId: u.id,
        delta: 100n,
        balanceAfter: 100n,
        reason: 'GIFT_RECEIVED',
        referenceId: randomUUID(),
        createdAt: new Date(clock),
      },
    });
    advance(1000);
    const agency = await ctx.http.get('/api/v1/me/agency').set(auth(opener));
    expect(agency.status).toBe(200);
    expect(agency.body.ownAgency.probation).toMatchObject({ status: 'RUNNING', activatedHosts: 1 });
    const row = (
      agency.body.ownAgency.probation.hosts as { user: { id: string }; activated: boolean }[]
    ).find((h) => h.user.id === u.id);
    expect(row?.activated).toBe(true);
  });

  it('host-admin: applications, view (audited), approve, reject; refusals exit 1', async () => {
    const a = await signup();
    const b = await signup();
    const appA = (await applied(a)).application!.id;
    const appB = (await applied(b)).application!.id;
    const env = { ...process.env, DOTENV_CONFIG_QUIET: 'true' };
    const cli = (args: string[]) =>
      run('node', ['--import', 'tsx', 'src/cli/host-admin.ts', ...args], { env });
    const list = await cli(['applications', '--status', 'pending']);
    expect(list.stdout).toContain(appA);
    expect(list.stdout).not.toContain('+966511111111');
    const view = await cli(['view', appA]);
    expect(view.stdout).toContain('+966511111111');
    expect(view.stdout).toContain('Date of birth');
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'host.application.view', targetId: appA } }),
    ).toBe(1);
    await expect(cli(['reject', appB])).rejects.toMatchObject({ code: 1 });
    await expect(cli(['approve', 'not-a-uuid'])).rejects.toMatchObject({ code: 1 });
    const approved = await cli(['approve', appA]);
    expect(approved.stdout).toContain('IDENTITY');
    expect(await ctx.prisma.liveHost.findUnique({ where: { userId: a.id } })).toMatchObject({
      source: 'IDENTITY',
      grantedById: null,
    });
    await expect(cli(['approve', appA])).rejects.toMatchObject({ code: 1 });
    const rejected = await cli(['reject', appB, '--reason', 'no ID visible']);
    expect(rejected.stdout).toContain('Rejected');
    expect((await mine(b)).application).toMatchObject({ status: 'REJECTED', rejectReason: 'no ID visible' });
    const audits = await ctx.prisma.auditLog.findMany({
      where: {
        targetId: { in: [appA, appB] },
        action: { in: ['host.application.approve', 'host.application.reject'] },
      },
    });
    expect(audits.map((x) => (x.metadata as { via: string }).via)).toEqual(['cli', 'cli']);
    expect(audits.every((x) => x.actorUserId === null)).toBe(true);
  });
});
