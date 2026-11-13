/**
 * D227 (owner 2026-11-01; contract v1.80-kyc, CONVENTIONS §10.77): identity verification with Didit «تأكيد الهوية»
 * for the applicants «كن مضيفاً مع الإدارة» (D209), «افتح وكالة» (D206) and recharge agents (D185). The OWNER enters
 * the Didit API key, the webhook secret and the workflows in the admin panel «التحقق من الهوية (Didit)» (OWNER only, the
 * code again + a reason, write-only secrets with their last 4, audited, «اختبار الاتصال»); a person starts a session and
 * Didit's signed webhook (or the app's sync) brings the decision; only the minimum is kept (the document number as an
 * HMAC); the three gates; the duplicate-document flag; the disabled mode (manual pictures as the fallback); the
 * notifications; the export and the purge.
 *
 * Didit is FAKED (test/helpers/fake-didit.ts behind `DIDIT_API_FACTORY`): no network call, no real key. End to end
 * against PostgreSQL + Redis.
 */
import { randomUUID } from 'node:crypto';
import { inflateRawSync } from 'node:zlib';
import sharp from 'sharp';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { DIDIT_API_FACTORY } from '../src/modules/kyc/didit-api.js';
import { KYC_CALLBACK_URL } from '../src/modules/kyc/kyc.rules.js';
import { buildDataExport } from '../src/modules/privacy/data-export.js';
import { notificationBody } from '../src/modules/push/push-texts.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { FakeDidit, fakeKey } from './helpers/fake-didit.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, openapi, operations } from './helpers/openapi.js';
import { createTestApp, type TestContext } from './helpers/test-app.js';

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';
const DAY = 86_400_000;

function birthday(at: number, years: number, days = 0): string {
  const d = new Date(at);
  d.setUTCFullYear(d.getUTCFullYear() - years);
  return new Date(d.getTime() + days * DAY).toISOString().slice(0, 10);
}

describe('D227 contract coverage', () => {
  it('openapi v1.80-kyc declares the person, the webhook and the panel operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'getMyKyc GET /api/v1/me/kyc',
        'startKycSession POST /api/v1/me/kyc/sessions',
        'syncKycCheck POST /api/v1/me/kyc/checks/{checkId}/sync',
        'receiveDiditWebhook POST /api/v1/kyc/didit/webhook',
        'getAdminKycSettings GET /api/v1/admin/kyc-settings',
        'updateAdminKycSettings PATCH /api/v1/admin/kyc-settings',
        'testAdminKycSettings POST /api/v1/admin/kyc-settings/test',
        'clearAdminKycSettings POST /api/v1/admin/kyc-settings/clear',
        'getAdminKycCheck GET /api/v1/admin/kyc/checks/{checkId}',
        'getAdminKycCheckMedia POST /api/v1/admin/kyc/checks/{checkId}/media',
      ]),
    );
    const schemas = (openapi.components as { schemas: Record<string, Record<string, unknown>> }).schemas;
    expect((schemas.NotificationType as { enum: string[] }).enum).toEqual(
      expect.arrayContaining(['KYC_APPROVED', 'KYC_DECLINED', 'KYC_IN_REVIEW']),
    );
    expect(schemas.HostingApplicationRequest!.required).not.toContain('photoUploadId');
    for (const o of operations().filter((x) => x.path.startsWith('/api/v1/admin/kyc'))) {
      expect(o.spec.security).toEqual([{ adminSession: [] }]);
      if (o.method !== 'get') expect(JSON.stringify(o.spec.parameters)).toContain('AdminCsrf');
    }
  });

  it('the push texts exist in both languages and never carry a reason', () => {
    for (const type of ['KYC_APPROVED', 'KYC_DECLINED', 'KYC_IN_REVIEW']) {
      const n = { type, actorName: null, actorCount: 0, targetType: null, targetId: null, targetText: null };
      expect(notificationBody(n, 'ar')).toBeTruthy();
      expect(notificationBody(n, 'en')).toBeTruthy();
    }
  });
});

describe('D227 «تأكيد الهوية» with Didit', { timeout: 600_000 }, () => {
  const storage = new MemoryObjectStorage();
  const didit = new FakeDidit();
  const API_KEY = fakeKey('didit_api');
  const SECRET = fakeKey('didit_whsec');
  let workflow: string;
  let ctx: TestContext;
  let png: Buffer;
  const p = panel(() => ctx);
  let owner: Admin;
  let support: Admin;
  let moderator: Admin;
  let finance: Admin;

  const auth = (u: Person) => ({ Authorization: `Bearer ${u.token}` });
  const issueOf = (res: request.Response) =>
    (res.body as { error: { details?: { issue: string }[] } }).error.details?.[0]?.issue;
  const myKyc = async (u: Person) => {
    const res = await ctx.http.get('/api/v1/me/kyc').set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getMyKyc');
    return res.body as {
      enabled: boolean;
      maxSessionsPerDay: number;
      startedLast24h: number;
      purposes: {
        purpose: string;
        approved: boolean;
        check: { id: string; status: string; reasons: string[] } | null;
        canStart: boolean;
        refusal: string | null;
      }[];
    };
  };
  const stateOf = async (u: Person, purpose: string) =>
    (await myKyc(u)).purposes.find((x) => x.purpose === purpose)!;
  const start = (u: Person, purpose = 'HOST_APPLICATION', language = 'ar') =>
    ctx.http.post('/api/v1/me/kyc/sessions').set(auth(u)).send({ purpose, language });
  const deliver = (w: { body: string; headers: Record<string, string> }) => {
    let r = ctx.http.post('/api/v1/kyc/didit/webhook');
    for (const [k, v] of Object.entries(w.headers)) r = r.set(k, v);
    return r.send(w.body);
  };
  /** Starts a session, lets Didit decide and delivers the signed webhook. */
  const verify = async (
    u: Person,
    status: 'Approved' | 'Declined' | 'In Review',
    person: Parameters<FakeDidit['decide']>[2] = {},
    purpose = 'HOST_APPLICATION',
  ) => {
    const res = await start(u, purpose);
    expect([200, 201], JSON.stringify(res.body)).toContain(res.status);
    const s = didit.decide(didit.sessionOf(u.id).sessionId, status, person);
    const hook = await deliver(didit.webhook(s, SECRET, { at: p.now() }));
    expect(hook.status, JSON.stringify(hook.body)).toBe(200);
    return res.body.check.id as string;
  };
  const notifications = async (u: Person) => {
    const res = await ctx.http.get('/api/v1/notifications').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'listNotifications');
    return (res.body.data as { type: string }[]).map((n) => n.type);
  };
  const upload = async (u: Person, kind: string): Promise<string> => {
    const slot = await ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send({ kind, contentType: 'image/png', byteSize: png.length });
    expect(slot.status, JSON.stringify(slot.body)).toBe(201);
    expect(storage.upload(slot.body.uploadUrl as string, png, 'image/png')).toBe(true);
    return slot.body.uploadId as string;
  };
  const hostForm = (extra: Record<string, unknown> = {}) => ({
    displayName: 'سارة المضيفة',
    country: 'SA',
    dateOfBirth: birthday(p.now(), 25),
    contact: { type: 'WHATSAPP', value: '+966511111111' },
    bio: 'أبث الطبخ والدردشة كل مساء',
    acceptRules: true,
    ...extra,
  });
  const applyHost = (u: Person, body: object) =>
    ctx.http
      .post('/api/v1/me/hosting-application')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send(body);
  const agencyForm = (extra: Record<string, unknown> = {}) => ({
    name: `وكالة ${randomUUID().slice(0, 6)}`,
    country: 'SA',
    contact: { type: 'WHATSAPP', value: '+966500000001' },
    expectedHosts: 5,
    ...extra,
  });
  const openAgency = (u: Person, body: object) =>
    ctx.http.post('/api/v1/me/agency/open').set(auth(u)).set('Idempotency-Key', randomUUID()).send(body);
  const rechargeForm = (extra: Record<string, unknown> = {}) => ({
    fullName: 'محمد أحمد علي حسن',
    phone: '+201001234567',
    whatsapp: true,
    locations: [{ country: 'EG', cities: ['Cairo'] }],
    paymentMethods: [{ country: 'EG', type: 'MOBILE_WALLET', details: 'Vodafone Cash 0100' }],
    ...extra,
  });
  const settings = (body: object, who: Admin = owner) =>
    p.send(who, 'patch', '/admin/kyc-settings', {
      totpCode: p.nextCode(who.secret),
      reason: 'D227 test',
      ...body,
    });

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'] });
    p.advance(0);
    png = await sharp({ create: { width: 16, height: 16, channels: 3, background: '#e11d48' } })
      .png()
      .toBuffer();
    didit.keys.add(API_KEY);
    workflow = didit.addWorkflow({ label: 'Kabso KYC' });
    ctx = await createTestApp(
      {
        ADMIN_TOTP_KEY: ADMIN_KEY,
        LIVE_HOSTING_ENABLED: 'true',
        MEDIA_UPLOADS_ENABLED: 'true',
        S3_BUCKET: 'kabso-media-test',
        S3_ACCESS_KEY_ID: 'test',
        S3_SECRET_ACCESS_KEY: 'test',
        MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
        RECHARGE_AGENT_SWEEP_INTERVAL_SECONDS: '0',
        SPECIAL_USERNAME_SWEEP_INTERVAL_SECONDS: '0',
        AGENCY_SWEEP_INTERVAL_SECONDS: '0',
        RATE_LIMIT_HOST_APPLY_USER: '1000/900',
        RATE_LIMIT_AGENCY_OPEN_USER: '1000/900',
        RATE_LIMIT_KYC_START_USER: '1000/900',
        // A day passes on the fake clock (the daily limit): the tokens and panel sessions must outlive it.
        JWT_ACCESS_TTL_SECONDS: String(30 * 86_400),
        REFRESH_TTL_SECONDS: String(30 * 86_400),
        REFRESH_ABSOLUTE_TTL_SECONDS: String(30 * 86_400),
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        ADMIN_SESSION_MAX_SECONDS: '604800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '100000/900',
      },
      [
        { token: OBJECT_STORAGE, value: storage },
        { token: DIDIT_API_FACTORY, value: didit.factory },
      ],
    );
    owner = await p.makeAdmin(['OWNER']);
    support = await p.makeAdmin(['SUPPORT']);
    moderator = await p.makeAdmin(['MODERATION']);
    finance = await p.makeAdmin(['FINANCE']);
  });

  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  // ---- disabled mode ---------------------------------------------------------------------------------------------

  it('off (nothing saved): no session can start, the manual ID pictures stay required and suffice', async () => {
    const u = await p.signup();
    const k = await myKyc(u);
    expect(k.enabled).toBe(false);
    expect(k.purposes.map((x) => x.purpose)).toEqual(['HOST_APPLICATION', 'AGENCY_OPEN', 'RECHARGE_AGENT']);
    expect(k.purposes.every((x) => !x.canStart && x.check === null)).toBe(true);
    const off = await start(u);
    expect(off.status).toBe(503);
    expect(off.body.error.code).toBe('KYC_UNAVAILABLE');
    expectContract(off, 'startKycSession');
    // The pictures are required while Didit is off …
    const missing = await applyHost(u, hostForm());
    expect(missing.status).toBe(400);
    expect(missing.body.error.details).toEqual([
      { field: 'photoUploadId', issue: 'required' },
      { field: 'selfieUploadId', issue: 'required' },
    ]);
    // … and are the check: the team approves without Didit.
    const ok = await applyHost(
      u,
      hostForm({
        photoUploadId: await upload(u, 'RECHARGE_AGENT_PHOTO'),
        selfieUploadId: await upload(u, 'RECHARGE_AGENT_SELFIE'),
      }),
    );
    expect(ok.status, JSON.stringify(ok.body)).toBe(201);
    const appId = ok.body.application.id as string;
    const detail = await p.send(support, 'get', `/admin/host-applications/${appId}`);
    expect(detail.status).toBe(200);
    expectContract(detail, 'getAdminHostApplication');
    expect(detail.body.kyc).toMatchObject({
      enabled: false,
      required: false,
      satisfied: false,
      latest: null,
    });
    const approve = await p.send(support, 'post', `/admin/host-applications/${appId}/approve`);
    expect(approve.status, JSON.stringify(approve.body)).toBe(200);
    // The webhook without a saved secret: 503 (Didit retries later).
    const s = didit.decide((await startFake(u)).sessionId, 'Approved');
    expect((await deliver(didit.webhook(s, SECRET, { at: p.now() }))).status).toBe(503);
  });

  /** A Didit session that exists only at Didit (for the 503 above). */
  const startFake = async (u: Person) => {
    const api = didit.client(API_KEY);
    return api.createSession({
      workflowId: workflow,
      vendorData: u.id,
      callback: KYC_CALLBACK_URL,
      language: null,
      metadata: {},
    });
  };

  // ---- the OWNER's settings ----------------------------------------------------------------------------------------

  it('«التحقق من الهوية (Didit)»: OWNER only, the code again + a reason, write-only secrets, audited, tested', async () => {
    for (const who of [support, moderator, finance]) {
      expect((await p.send(who, 'get', '/admin/kyc-settings')).status).toBe(403);
      expect((await p.send(who, 'patch', '/admin/kyc-settings', { enabled: false })).status).toBe(403);
    }
    const view = await p.send(owner, 'get', '/admin/kyc-settings');
    expect(view.status).toBe(200);
    expectContract(view, 'getAdminKycSettings');
    expect(view.headers['cache-control']).toBe('no-store');
    expect(view.body).toMatchObject({
      status: 'not_configured',
      enabled: false,
      apiKey: null,
      webhookSecret: null,
      missing: ['apiKey', 'webhookSecret', 'workflowId'],
      webhookUrl: 'https://api.kabsolive.com/api/v1/kyc/didit/webhook',
      callbackUrl: KYC_CALLBACK_URL,
      maxSessionsPerDay: 3,
    });
    // No code / a wrong code: refused, nothing saved.
    const noCode = await p.send(owner, 'patch', '/admin/kyc-settings', { apiKey: API_KEY, reason: 'x' });
    expect(noCode.status).toBe(400);
    const wrong = await p.send(owner, 'patch', '/admin/kyc-settings', {
      apiKey: API_KEY,
      totpCode: '000000',
      reason: 'x',
    });
    expect(wrong.status).toBe(403);
    expect(wrong.body.error.code).toBe('ADMIN_TOTP_INVALID');
    expect(await ctx.prisma.kycSettings.count()).toBe(0);
    // «اختبار الاتصال»: a wrong key, an unknown workflow, then the right ones.
    const bad = await p.send(owner, 'post', '/admin/kyc-settings/test', {
      apiKey: fakeKey('wrong'),
      workflowId: workflow,
    });
    expect(bad.status).toBe(200);
    expectContract(bad, 'testAdminKycSettings');
    expect(bad.body).toMatchObject({ ok: false, apiKey: { ok: false, issue: 'bad_api_key' } });
    const unknownWf = await p.send(owner, 'post', '/admin/kyc-settings/test', {
      apiKey: API_KEY,
      workflowId: randomUUID(),
    });
    expect(unknownWf.body.workflows[0]).toMatchObject({ ok: false, issue: 'workflow_not_found' });
    const good = await p.send(owner, 'post', '/admin/kyc-settings/test', {
      apiKey: API_KEY,
      workflowId: workflow,
    });
    expect(good.body).toMatchObject({
      ok: true,
      workflows: [{ field: 'workflowId', ok: true, label: 'Kabso KYC' }],
    });
    // On while incomplete: 409 one detail per missing field.
    const incomplete = await settings({ apiKey: API_KEY, enabled: true });
    expect(incomplete.status).toBe(409);
    expect(incomplete.body.error.details).toEqual([
      { field: 'webhookSecret', issue: 'kyc_incomplete' },
      { field: 'workflowId', issue: 'kyc_incomplete' },
    ]);
    // On with a workflow Didit does not have: the test runs and fails, nothing saved.
    const failed = await settings({
      apiKey: API_KEY,
      webhookSecret: SECRET,
      workflowId: randomUUID(),
      enabled: true,
    });
    expect(failed.status).toBe(409);
    expect(issueOf(failed)).toBe('kyc_test_failed');
    expect((await ctx.prisma.kycSettings.findUnique({ where: { id: 1 } }))?.apiKeyEnc ?? null).toBeNull();
    // Saved and on.
    const on = await settings({
      apiKey: API_KEY,
      webhookSecret: SECRET,
      workflowId: workflow,
      enabled: true,
    });
    expect(on.status, JSON.stringify(on.body)).toBe(200);
    expectContract(on, 'updateAdminKycSettings');
    expect(on.body).toMatchObject({
      status: 'active',
      enabled: true,
      apiKey: { last4: API_KEY.slice(-4), setBy: { id: owner.id } },
      webhookSecret: { last4: SECRET.slice(-4) },
      workflowId: workflow,
      missing: [],
      lastTest: { ok: true },
    });
    const text = JSON.stringify(on.body);
    expect(text).not.toContain(API_KEY);
    expect(text).not.toContain(SECRET);
    // Sealed at rest; audited with the last 4 only.
    const row = await ctx.prisma.kycSettings.findUniqueOrThrow({ where: { id: 1 } });
    expect(row.apiKeyEnc).not.toContain(API_KEY);
    expect(row.webhookSecretEnc).not.toContain(SECRET);
    const audits = await ctx.prisma.auditLog.findMany({
      where: { action: { in: ['kyc.settings.update', 'kyc.settings.test'] } },
    });
    expect(audits.length).toBeGreaterThanOrEqual(4);
    for (const a of audits) {
      expect(JSON.stringify(a.metadata)).not.toContain(API_KEY);
      expect(JSON.stringify(a.metadata)).not.toContain(SECRET);
    }
    const upd = audits.find((a) => a.action === 'kyc.settings.update')!;
    expect(upd.metadata).toMatchObject({
      after: { enabled: true, apiKey: `…${API_KEY.slice(-4)}` },
      connectionTest: 'ok',
      reason: 'D227 test',
      via: 'panel',
    });
  });

  // ---- sessions, the webhook and the transitions ---------------------------------------------------------------------

  it('a session: 201 new, 200 the unfinished one again; Didit gets the person, the callback and the language', async () => {
    const u = await p.signup();
    const first = await start(u);
    expect(first.status, JSON.stringify(first.body)).toBe(201);
    expectContract(first, 'startKycSession');
    expect(first.headers['cache-control']).toBe('no-store');
    expect(first.body.callbackUrl).toBe(KYC_CALLBACK_URL);
    expect(first.body.url).toMatch(/^https:\/\/verify\.didit\.me\/ar\/session\//);
    expect(first.body.check).toMatchObject({
      purpose: 'HOST_APPLICATION',
      status: 'NOT_STARTED',
      reasons: [],
    });
    const s = didit.sessionOf(u.id);
    expect(s).toMatchObject({
      vendorData: u.id,
      workflowId: workflow,
      callback: KYC_CALLBACK_URL,
      language: 'ar',
    });
    expect(s.metadata).toEqual({ purpose: 'HOST_APPLICATION' });
    const again = await start(u);
    expect(again.status).toBe(200);
    expect(again.body.check.id).toBe(first.body.check.id);
    expect(await ctx.prisma.kycCheck.count({ where: { userId: u.id } })).toBe(1);
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'kyc.session.start', targetId: first.body.check.id as string },
    });
    expect(audit.actorUserId).toBe(u.id);
    // A bad body.
    const bad = await ctx.http.post('/api/v1/me/kyc/sessions').set(auth(u)).send({ purpose: 'OTHER' });
    expect(bad.status).toBe(400);
    // Didit down: 503, nothing made.
    const v = await p.signup();
    didit.down = true;
    const down = await start(v);
    didit.down = false;
    expect(down.status).toBe(503);
    expect(down.body.error.code).toBe('SERVICE_UNAVAILABLE');
    expect(await ctx.prisma.kycCheck.count({ where: { userId: v.id } })).toBe(0);
  });

  it('the webhook: a valid signature applies, an invalid / tampered / replayed one is 401, a retry is a no-op', async () => {
    const u = await p.signup();
    const started = await start(u);
    const id = started.body.check.id as string;
    const s = didit.decide(didit.sessionOf(u.id).sessionId, 'In Review', {
      warnings: ['LOW_LIVENESS_SCORE'],
    });
    // Wrong secret.
    const forged = await deliver(didit.webhook(s, fakeKey('not_the_secret'), { at: p.now() }));
    expect(forged.status).toBe(401);
    expectContract(forged, 'receiveDiditWebhook');
    // Tampered body (signed for another status).
    expect((await deliver(didit.webhook(s, SECRET, { at: p.now(), tamper: true }))).status).toBe(401);
    // Replayed (6 minutes old) and from the future.
    expect((await deliver(didit.webhook(s, SECRET, { at: p.now() - 6 * 60_000 }))).status).toBe(401);
    expect((await deliver(didit.webhook(s, SECRET, { at: p.now() + 6 * 60_000 }))).status).toBe(401);
    // No signature at all.
    const w = didit.webhook(s, SECRET, { at: p.now() });
    const unsigned = await ctx.http
      .post('/api/v1/kyc/didit/webhook')
      .set('Content-Type', 'application/json')
      .set('X-Timestamp', w.headers['X-Timestamp']!)
      .send(w.body);
    expect(unsigned.status).toBe(401);
    expect((await ctx.prisma.kycCheck.findUniqueOrThrow({ where: { id } })).status).toBe('NOT_STARTED');
    // Valid → IN_REVIEW with the reason, notified once even when Didit retries the same event.
    const ok = await deliver(w);
    expect(ok.status).toBe(200);
    expectContract(ok, 'receiveDiditWebhook');
    expect(ok.body).toEqual({ received: true });
    expect((await deliver(w)).status).toBe(200);
    const check = await ctx.prisma.kycCheck.findUniqueOrThrow({ where: { id } });
    expect(check).toMatchObject({
      status: 'IN_REVIEW',
      providerStatus: 'In Review',
      reasons: ['LOW_LIVENESS_SCORE'],
    });
    expect(check.decidedAt).not.toBeNull();
    expect((await notifications(u)).filter((t) => t === 'KYC_IN_REVIEW')).toHaveLength(1);
    // The raw-bytes signature (`X-Signature`) is accepted too.
    const { createHmac } = await import('node:crypto');
    const s2 = didit.decide(s.sessionId, 'Approved');
    const w2 = didit.webhook(s2, SECRET, { at: p.now() });
    const raw = await ctx.http
      .post('/api/v1/kyc/didit/webhook')
      .set('Content-Type', 'application/json')
      .set('X-Timestamp', w2.headers['X-Timestamp']!)
      .set('X-Signature', createHmac('sha256', SECRET).update(w2.body).digest('hex'))
      .send(w2.body);
    expect(raw.status).toBe(200);
    expect((await ctx.prisma.kycCheck.findUniqueOrThrow({ where: { id } })).status).toBe('APPROVED');
    // An older event (created before the last one applied) does not undo it.
    const old = didit.webhook({ ...s2, status: 'In Review' }, SECRET, {
      at: p.now(),
      createdAt: Math.floor(p.now() / 1000) - 120,
    });
    expect((await deliver(old)).status).toBe(200);
    expect((await ctx.prisma.kycCheck.findUniqueOrThrow({ where: { id } })).status).toBe('APPROVED');
    // An unknown session is acknowledged and dropped.
    const ghost = didit.webhook({ ...s2, sessionId: randomUUID() }, SECRET, { at: p.now() });
    expect((await deliver(ghost)).status).toBe(200);
  });

  it('approved: the minimum is kept (name, birth date, country, the number as an HMAC); notified; retry refused', async () => {
    const u = await p.signup();
    const id = await verify(u, 'Approved', {
      firstName: 'Noura',
      lastName: 'Al Saud',
      dateOfBirth: '1995-04-02',
      issuingState: 'SAU',
      documentNumber: 'X1234-5678',
    });
    const c = await ctx.prisma.kycCheck.findUniqueOrThrow({ where: { id } });
    expect(c).toMatchObject({
      status: 'APPROVED',
      fullName: 'Noura Al Saud',
      documentCountry: 'SAU',
      reasons: [],
      duplicateDocument: false,
    });
    expect(c.dateOfBirth?.toISOString().slice(0, 10)).toBe('1995-04-02');
    expect(c.documentHash).toMatch(/^[0-9a-f]{64}$/);
    // Nothing else of Didit's answer: no number, no address, no image link.
    const stored = JSON.stringify(c);
    for (const leak of ['X1234', '5678', 'NOT TO BE STORED', 'media.didit.example'])
      expect(stored).not.toContain(leak);
    expect(await notifications(u)).toContain('KYC_APPROVED');
    const state = await stateOf(u, 'HOST_APPLICATION');
    expect(state).toMatchObject({
      approved: true,
      canStart: false,
      refusal: 'ALREADY_APPROVED',
      check: { status: 'APPROVED' },
    });
    // One workflow for all: the approval counts for the two other applications too.
    expect((await stateOf(u, 'AGENCY_OPEN')).approved).toBe(true);
    const again = await start(u, 'AGENCY_OPEN');
    expect(again.status).toBe(409);
    expect(again.body.error.code).toBe('KYC_NOT_ALLOWED');
    expect(issueOf(again)).toBe('ALREADY_APPROVED');
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: {
        action: 'kyc.check.decision',
        targetId: id,
        metadata: { path: ['after'], equals: 'APPROVED' },
      },
    });
    expect(JSON.stringify(audit.metadata)).not.toContain('Noura');
  });

  it('declined (with the reasons) and retried; under 18 → declined UNDER_MIN_AGE; the daily limit', async () => {
    const u = await p.signup();
    const id = await verify(u, 'Declined', { warnings: ['LIVENESS_FACE_ATTACK', 'NO_FACE_DETECTED'] });
    const st = await stateOf(u, 'HOST_APPLICATION');
    expect(st).toMatchObject({
      approved: false,
      canStart: true,
      refusal: null,
      check: { id, status: 'DECLINED', reasons: ['LIVENESS_FACE_ATTACK', 'NO_FACE_DETECTED'] },
    });
    expect(await notifications(u)).toContain('KYC_DECLINED');
    // A retry: a new session (the declined one is finished at Didit).
    const second = await start(u);
    expect(second.status).toBe(201);
    expect(second.body.check.id).not.toBe(id);
    // Under 18: Didit approved, we decline.
    const minor = await p.signup();
    const mid = await verify(minor, 'Approved', {
      dateOfBirth: birthday(p.now(), 17),
      documentNumber: 'MINOR-001',
    });
    expect(await ctx.prisma.kycCheck.findUniqueOrThrow({ where: { id: mid } })).toMatchObject({
      status: 'DECLINED',
      reasons: ['UNDER_MIN_AGE'],
    });
    expect(await notifications(minor)).toContain('KYC_DECLINED');
    // The daily limit (the OWNER's number, 3 by default): a 4th new session within 24 h is refused.
    const busy = await p.signup();
    for (let i = 0; i < 3; i++) await verify(busy, 'Declined', { documentNumber: `BUSY-${i}` });
    const k = await myKyc(busy);
    expect(k).toMatchObject({ startedLast24h: 3, maxSessionsPerDay: 3 });
    expect(k.purposes[0]).toMatchObject({ canStart: false, refusal: 'DAILY_LIMIT' });
    const limited = await start(busy);
    expect(limited.status).toBe(409);
    expect(issueOf(limited)).toBe('DAILY_LIMIT');
    // A day later it may start again.
    p.advance(DAY + 60_000);
    expect((await start(busy)).status).toBe(201);
    // The panel sessions idled out over that day: sign the team in again.
    owner = await p.makeAdmin(['OWNER']);
    support = await p.makeAdmin(['SUPPORT']);
    moderator = await p.makeAdmin(['MODERATION']);
    finance = await p.makeAdmin(['FINANCE']);
  });

  it('sync: after the hosted flow the app reads the decision from Didit (a late webhook)', async () => {
    const u = await p.signup();
    const res = await start(u, 'RECHARGE_AGENT');
    const id = res.body.check.id as string;
    didit.decide(didit.sessionOf(u.id).sessionId, 'Approved', { documentNumber: 'SYNC-001' });
    const synced = await ctx.http.post(`/api/v1/me/kyc/checks/${id}/sync`).set(auth(u));
    expect(synced.status, JSON.stringify(synced.body)).toBe(200);
    expectContract(synced, 'syncKycCheck');
    expect(synced.body).toMatchObject({ id, status: 'APPROVED', purpose: 'RECHARGE_AGENT' });
    // Another person's check: 404.
    const other = await p.signup();
    expect((await ctx.http.post(`/api/v1/me/kyc/checks/${id}/sync`).set(auth(other))).status).toBe(404);
  });

  // ---- the gates --------------------------------------------------------------------------------------------------

  it('D209 host application: with Didit on no pictures are asked, and «موافقة» needs an approved check', async () => {
    const u = await p.signup();
    const res = await applyHost(u, hostForm());
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const appId = res.body.application.id as string;
    const app = await ctx.prisma.hostApplication.findUniqueOrThrow({ where: { id: appId } });
    expect(app.photoKey).toBeNull();
    const refused = await p.send(support, 'post', `/admin/host-applications/${appId}/approve`);
    expect(refused.status).toBe(409);
    expect(refused.body.error.code).toBe('ADMIN_ACTION_REFUSED');
    expect(issueOf(refused)).toBe('kyc_required');
    expect(await ctx.prisma.liveHost.count({ where: { userId: u.id } })).toBe(0);
    // In review: still refused; the detail shows it.
    await verify(u, 'In Review', { documentNumber: 'HOST-001' });
    expect((await p.send(support, 'post', `/admin/host-applications/${appId}/approve`)).status).toBe(409);
    const detail = await p.send(support, 'get', `/admin/host-applications/${appId}`);
    expectContract(detail, 'getAdminHostApplication');
    expect(detail.body.kyc).toMatchObject({
      enabled: true,
      required: true,
      satisfied: false,
      latest: { status: 'IN_REVIEW' },
    });
    // Didit's reviewer approves (a later event) → the team may approve.
    const s = didit.decide(didit.sessionOf(u.id).sessionId, 'Approved', { documentNumber: 'HOST-001' });
    p.advance(1_000);
    expect((await deliver(didit.webhook(s, SECRET, { at: p.now() }))).status).toBe(200);
    const after = await p.send(support, 'get', `/admin/host-applications/${appId}`);
    expect(after.body.kyc).toMatchObject({
      satisfied: true,
      approved: { status: 'APPROVED', fullName: 'Jane Doe' },
    });
    // MODERATION sees the state but no personal field.
    const mod = await p.send(moderator, 'get', `/admin/host-applications/${appId}`);
    expect(mod.status).toBe(200);
    expect(mod.body.kyc.approved).toMatchObject({
      status: 'APPROVED',
      fullName: null,
      dateOfBirth: null,
      documentCountry: null,
    });
    const ok = await p.send(support, 'post', `/admin/host-applications/${appId}/approve`);
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    expect(await ctx.prisma.liveHost.count({ where: { userId: u.id } })).toBe(1);
  });

  it('D206 agency open: refused KYC_REQUIRED until approved; a per-purpose workflow needs its own approval', async () => {
    const u = await p.signup();
    const refused = await openAgency(u, agencyForm());
    expect(refused.status).toBe(409);
    expect(refused.body.error.code).toBe('AGENCY_OPEN_NOT_ALLOWED');
    expect(issueOf(refused)).toBe('KYC_REQUIRED');
    expectContract(refused, 'openAgency');
    await verify(u, 'Approved', { documentNumber: 'AGENCY-001' }, 'AGENCY_OPEN');
    const ok = await openAgency(u, agencyForm());
    expect(ok.status, JSON.stringify(ok.body)).toBe(201);
    const appRow = await ctx.prisma.agencyApplication.findFirstOrThrow({ where: { userId: u.id } });
    expect(appRow.photoKey).toBeNull();
    const detail = await p.send(
      support,
      'get',
      `/admin/agencies/${appRow.agencyId}/applications/${appRow.id}`,
    );
    expect(detail.status).toBe(200);
    expectContract(detail, 'getAdminAgencyApplication');
    expect(detail.body.kyc).toMatchObject({ satisfied: true, approved: { purpose: 'AGENCY_OPEN' } });
    // The OWNER gives «افتح وكالة» its own workflow: a host-purpose approval no longer counts for it.
    const own = didit.addWorkflow({ label: 'Agency KYC' });
    expect((await settings({ workflowIdAgency: own })).status).toBe(200);
    const v = await p.signup();
    await verify(v, 'Approved', { documentNumber: 'HOST-777' }, 'HOST_APPLICATION');
    expect((await stateOf(v, 'AGENCY_OPEN')).approved).toBe(false);
    expect(issueOf(await openAgency(v, agencyForm()))).toBe('KYC_REQUIRED');
    const st = await start(v, 'AGENCY_OPEN');
    expect(st.status).toBe(201);
    expect(didit.sessionOf(v.id).workflowId).toBe(own);
    expect((await settings({ workflowIdAgency: null })).status).toBe(200);
  });

  it('D185 recharge agent: applied without pictures; the first top-up (activation) needs an approved check', async () => {
    const u = await p.signup();
    const applied = await ctx.http
      .post('/api/v1/me/recharge-agent/application')
      .set(auth(u))
      .send(rechargeForm());
    expect(applied.status, JSON.stringify(applied.body)).toBe(201);
    const app = await ctx.prisma.rechargeAgentApplication.findFirstOrThrow({ where: { userId: u.id } });
    expect(app.photoKey).toBeNull();
    const detail = await p.send(support, 'get', `/admin/recharge/applications/${app.id}`);
    expect(detail.status).toBe(200);
    expectContract(detail, 'getAdminRechargeApplication');
    expect(detail.body.kyc).toMatchObject({ required: true, satisfied: false });
    expect((await p.send(support, 'post', `/admin/recharge/applications/${app.id}/approve`)).status).toBe(
      200,
    );
    const topup = () =>
      p.send(finance, 'post', `/admin/recharge/agents/${u.id}/topup`, {
        coins: '30000000',
        paidUsd: '364.50',
        totpCode: p.nextCode(finance.secret),
      });
    const refused = await topup();
    expect(refused.status).toBe(409);
    expect(issueOf(refused)).toBe('kyc_required');
    expect(await ctx.prisma.rechargeTopup.count({ where: { agentUserId: u.id } })).toBe(0);
    await verify(u, 'Approved', { documentNumber: 'AGENT-001' }, 'RECHARGE_AGENT');
    const ok = await topup();
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    expect(ok.body).toMatchObject({ first: true });
  });

  // ---- duplicates, the team's views ---------------------------------------------------------------------------------

  it('the same document on two accounts is flagged to the team on both (never an automatic decline)', async () => {
    const a = await p.signup();
    const b = await p.signup();
    const ida = await verify(a, 'Approved', { documentNumber: 'DUP 99-1', issuingState: 'EGY' });
    const idb = await verify(b, 'Approved', { documentNumber: 'dup-991', issuingState: 'EGY' });
    const [ca, cb] = await Promise.all([
      ctx.prisma.kycCheck.findUniqueOrThrow({ where: { id: ida } }),
      ctx.prisma.kycCheck.findUniqueOrThrow({ where: { id: idb } }),
    ]);
    expect(ca.documentHash).toBe(cb.documentHash);
    expect(ca).toMatchObject({ status: 'APPROVED', duplicateDocument: true });
    expect(cb).toMatchObject({ status: 'APPROVED', duplicateDocument: true });
    const view = await p.send(support, 'get', `/admin/kyc/checks/${idb}`);
    expect(view.status).toBe(200);
    expectContract(view, 'getAdminKycCheck');
    expect(view.body).toMatchObject({
      duplicateDocument: true,
      duplicates: [{ id: a.id }],
      consoleUrl: 'https://business.didit.me',
    });
    expect(JSON.stringify(view.body)).not.toContain(cb.documentHash!);
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'kyc.check.duplicate_document', targetId: idb } }),
    ).toBe(1);
    expect(
      await ctx.prisma.auditLog.count({
        where: { action: 'kyc.check.view', targetId: idb, actorUserId: support.id },
      }),
    ).toBe(1);
    // The images: a short-lived fetch from Didit, audited per fetch, never stored.
    const media = await p.send(support, 'post', `/admin/kyc/checks/${idb}/media`);
    expect(media.status).toBe(200);
    expectContract(media, 'getAdminKycCheckMedia');
    expect(media.headers['cache-control']).toBe('no-store');
    expect(media.body).toMatchObject({
      portrait: 'https://media.didit.example/portrait.jpg?sig=1',
      front: 'https://media.didit.example/front.jpg?sig=1',
      liveness: 'https://media.didit.example/live.jpg?sig=1',
    });
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'kyc.check.media.view', targetId: idb } }),
    ).toBe(1);
    // MODERATION / FINANCE: no `kyc.view`.
    for (const who of [moderator, finance]) {
      expect((await p.send(who, 'get', `/admin/kyc/checks/${idb}`)).status).toBe(403);
      expect((await p.send(who, 'post', `/admin/kyc/checks/${idb}/media`)).status).toBe(403);
    }
  });

  // ---- privacy -----------------------------------------------------------------------------------------------------

  it('the data export has `kyc_checks` (never the hash); the account purge deletes the checks', async () => {
    const u = await p.signup();
    const id = await verify(u, 'Approved', { documentNumber: 'EXPORT-1', firstName: 'Lina', lastName: 'K' });
    const hash = (await ctx.prisma.kycCheck.findUniqueOrThrow({ where: { id } })).documentHash!;
    const out = await buildDataExport(ctx.prisma, {
      userId: u.id,
      now: new Date(p.now()),
      mediaBaseUrl: 'https://media.test',
      supportEmail: 'info@example.com',
      storage: null,
    });
    expect(out.counts.kyc_checks).toBe(1);
    const zipText = unzipEntry(out.zip, 'data/kyc_checks.json');
    const section = JSON.parse(zipText) as Record<string, unknown>[];
    expect(section[0]).toMatchObject({
      id,
      provider: 'Didit',
      status: 'APPROVED',
      fullName: 'Lina K',
      documentNumberStored: false,
    });
    expect(zipText).not.toContain(hash);
    const { requestDeletionIn, purgeAccountIn } = await import('../src/modules/users/account-deletion.js');
    await ctx.prisma.$transaction((tx) =>
      requestDeletionIn(tx, u.id, new Date(p.now()), 30, { via: 'ADMIN', reason: 'test' }),
    );
    await ctx.prisma.$transaction((tx) =>
      purgeAccountIn(tx, u.id, new Date(p.now()), {
        via: 'ADMIN',
        reason: 'test',
        quarantineDays: 0,
        specialGraceDays: 30,
        legalHoldDays: 90,
      }),
    );
    expect(await ctx.prisma.kycCheck.count({ where: { userId: u.id } })).toBe(0);
  });

  it('turned off: no new session, the gates fall back to the pictures; cleared: everything removed, audited', async () => {
    const off = await settings({ enabled: false });
    expect(off.status).toBe(200);
    expect(off.body).toMatchObject({ status: 'off', enabled: false });
    const u = await p.signup();
    expect((await myKyc(u)).enabled).toBe(false);
    expect((await start(u)).status).toBe(503);
    // A host application made while Didit was on (no pictures) cannot be approved without a check while off.
    // (The fallback is the pictures; with neither, the team must refuse or ask again.)
    const cleared = await p.send(owner, 'post', '/admin/kyc-settings/clear', {
      totpCode: p.nextCode(owner.secret),
      reason: 'D227 test',
    });
    expect(cleared.status).toBe(200);
    expectContract(cleared, 'clearAdminKycSettings');
    expect(cleared.body).toMatchObject({
      status: 'not_configured',
      apiKey: null,
      webhookSecret: null,
      workflowId: null,
    });
    const again = await p.send(owner, 'post', '/admin/kyc-settings/clear', {
      totpCode: p.nextCode(owner.secret),
      reason: 'D227 test',
    });
    expect(again.status).toBe(409);
    expect(issueOf(again)).toBe('kyc_nothing_to_clear');
    expect(await ctx.prisma.auditLog.count({ where: { action: 'kyc.settings.clear' } })).toBe(1);
  });
});

/** One file of a ZIP made by our writer (central directory; STORED or DEFLATE). */
function unzipEntry(buf: Buffer, wanted: string): string {
  const end = buf.lastIndexOf(Buffer.from([0x50, 0x4b, 0x05, 0x06]));
  const count = buf.readUInt16LE(end + 10);
  let p = buf.readUInt32LE(end + 16);
  for (let i = 0; i < count; i++) {
    const method = buf.readUInt16LE(p + 10);
    const csize = buf.readUInt32LE(p + 20);
    const nameLen = buf.readUInt16LE(p + 28);
    const extra = buf.readUInt16LE(p + 30);
    const comment = buf.readUInt16LE(p + 32);
    const offset = buf.readUInt32LE(p + 42);
    const name = buf.subarray(p + 46, p + 46 + nameLen).toString('utf8');
    if (name === wanted) {
      const lname = buf.readUInt16LE(offset + 26);
      const lextra = buf.readUInt16LE(offset + 28);
      const data = buf.subarray(offset + 30 + lname + lextra, offset + 30 + lname + lextra + csize);
      return (method === 8 ? inflateRawSync(data) : Buffer.from(data)).toString('utf8');
    }
    p += 46 + nameLen + extra + comment;
  }
  throw new Error(`${wanted} not in the zip`);
}
