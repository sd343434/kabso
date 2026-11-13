/**
 * D390 (contract v1.140-social, CONVENTIONS §10.179): «برنامج سفراء Kabso» — the ambassadors programme. OFF by default;
 * the application and its review, the direct appointment, the precedence over the D217 referral reward (no double
 * pay), the commission on qualifying top-ups with its hold, the activity rule, the refund / chargeback reversal, the
 * monthly cap, self-referral and self-payment, the velocity and IP-cluster flags, freeze / unfreeze, staff
 * ineligibility, the monthly evaluation with its reward, the panel's capabilities and the OWNER-only money totals.
 * End to end against PostgreSQL + Redis.
 */
import { randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { AmbassadorSweeper } from '../src/modules/ambassadors/ambassadors.service.js';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { notificationBody } from '../src/modules/push/push-texts.js';
import { topUpIn } from '../src/modules/recharge/recharge-core.js';
import { ReferralSweeper } from '../src/modules/referrals/referrals.service.js';
import { creditOrderIn, reconcileOrderIn } from '../src/modules/topup/topup-core.js';
import { expectContract, openapi, operations } from './helpers/openapi.js';
import { createTestApp, newUser, withMigrationClient, type TestContext } from './helpers/test-app.js';

const HOUR = 3_600_000;
const DAY = 24 * HOUR;
const COOKIE = '__Host-kabso_admin';
const AGENT_RULES = {
  activationMinCoins: 30_000_000,
  priceTiers: [{ minCoins: 0, minorPerMillion: 1200 }],
  currency: 'USD',
};

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly password: string;
  readonly token: string;
  readonly ip: string;
  readonly installId: string;
}
interface Admin extends TestUser {
  secret: string;
  cookie: string;
  csrf: string;
}

describe('D390 contract coverage', () => {
  it('openapi v1.140-social declares the app and panel operations, the enums and the capabilities', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'getAmbassadorProgramme GET /api/v1/ambassadors/programme',
        'applyForAmbassadorProgramme POST /api/v1/ambassadors/applications',
        'getMyAmbassadorDashboard GET /api/v1/ambassadors/me',
        'listAdminAmbassadors GET /api/v1/admin/ambassadors',
        'appointAdminAmbassador POST /api/v1/admin/ambassadors',
        'getAdminAmbassador GET /api/v1/admin/ambassadors/{userId}',
        'freezeAdminAmbassador POST /api/v1/admin/ambassadors/{userId}/freeze',
        'unfreezeAdminAmbassador POST /api/v1/admin/ambassadors/{userId}/unfreeze',
        'clearAdminAmbassadorReview POST /api/v1/admin/ambassadors/{userId}/clear-review',
        'listAdminAmbassadorApplications GET /api/v1/admin/ambassador-applications',
        'approveAdminAmbassadorApplication POST /api/v1/admin/ambassador-applications/{applicationId}/approve',
        'rejectAdminAmbassadorApplication POST /api/v1/admin/ambassador-applications/{applicationId}/reject',
        'getAdminAmbassadorSettings GET /api/v1/admin/ambassador-settings',
        'updateAdminAmbassadorSettings PUT /api/v1/admin/ambassador-settings',
        'listAdminAmbassadorCampaigns GET /api/v1/admin/ambassador-campaigns',
        'createAdminAmbassadorCampaign POST /api/v1/admin/ambassador-campaigns',
        'updateAdminAmbassadorCampaign PUT /api/v1/admin/ambassador-campaigns/{campaignId}',
      ]),
    );
    const schemas = (openapi.components as { schemas: Record<string, { enum?: string[] }> }).schemas;
    expect(schemas.CherryLedgerReason!.enum).toEqual(
      expect.arrayContaining(['AMBASSADOR_COMMISSION', 'AMBASSADOR_COMMISSION_REVERSAL']),
    );
    expect(schemas.WalletLedgerReason!.enum).toContain('AMBASSADOR_REWARD');
    expect(schemas.NotificationType!.enum).toEqual(
      expect.arrayContaining([
        'AMBASSADOR_APPLICATION_APPROVED',
        'AMBASSADOR_APPLICATION_REJECTED',
        'AMBASSADOR_LEVEL_UP',
        'AMBASSADOR_REWARD_GRANTED',
      ]),
    );
    for (const o of operations().filter((x) => x.path.startsWith('/api/v1/admin/ambassador'))) {
      expect(o.spec.security).toEqual([{ adminSession: [] }]);
      if (o.method !== 'get') expect(JSON.stringify(o.spec.parameters)).toContain('AdminCsrf');
    }
  });

  it('the four pushes have a text in both languages', () => {
    for (const type of [
      'AMBASSADOR_APPLICATION_APPROVED',
      'AMBASSADOR_APPLICATION_REJECTED',
      'AMBASSADOR_LEVEL_UP',
      'AMBASSADOR_REWARD_GRANTED',
    ]) {
      const n = { type, actorName: null, actorCount: 0, targetType: null, targetId: null, targetText: null };
      expect(notificationBody(n as never, 'ar')?.length).toBeGreaterThan(10);
      expect(notificationBody(n as never, 'en')?.length).toBeGreaterThan(10);
      // Copy rule T2: the brand in Latin script in Arabic.
      expect(notificationBody(n as never, 'ar')).not.toContain('كابسو');
    }
  });
});

describe('D390 «برنامج سفراء Kabso»', { timeout: 900_000 }, () => {
  let ctx: TestContext;
  let sweeper: AmbassadorSweeper;
  let referrals: ReferralSweeper;
  // A fixed day 2 of next month, so the whole flow stays in one month and the evaluation runs on the next.
  const real = new Date();
  let clock = Date.UTC(real.getUTCFullYear(), real.getUTCMonth() + 1, 2, 10, 0, 0);
  const advance = (ms: number) => {
    clock += ms;
    vi.setSystemTime(clock);
  };
  const now = () => new Date(clock);
  let ipCounter = 10;
  const nextIp = () => {
    ipCounter += 1;
    return `203.0.${Math.floor(ipCounter / 250)}.${(ipCounter % 250) + 1}`;
  };
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}`, 'X-Forwarded-For': u.ip });

  const signup = async (opts: { code?: string; ip?: string; installId?: string } = {}): Promise<TestUser> => {
    const ip = opts.ip ?? nextIp();
    const installId = opts.installId ?? `install-${randomUUID()}`;
    const device = { name: 'Pixel 9', platform: 'android', appVersion: '1.0.0', installId };
    const payload = newUser({ device, ...(opts.code !== undefined ? { referralCode: opts.code } : {}) });
    const email = String(payload.email).trim().toLowerCase();
    const before = ctx.mail.sent.length;
    const reg = await ctx.http.post('/api/v1/auth/register').set('X-Forwarded-For', ip).send(payload);
    expect(reg.status, JSON.stringify(reg.body)).toBe(202);
    const mail = await ctx.mail.waitFor(email, 'code', before);
    const res = await ctx.http
      .post('/api/v1/auth/register/verify')
      .set('X-Forwarded-For', ip)
      .send({ email, code: mail.code, device: payload.device });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email,
      password: payload.password,
      token: res.body.tokens.accessToken as string,
      ip,
      installId,
    };
  };
  const codeOf = async (u: TestUser): Promise<string> => {
    const res = await ctx.http.get('/api/v1/me/referral').set(auth(u));
    expect(res.status).toBe(200);
    return res.body.code as string;
  };
  const programme = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/ambassadors/programme').set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getAmbassadorProgramme');
    return res.body as {
      enabled: boolean;
      status: string;
      canApply: boolean;
      refusal: string | null;
      levels: unknown[];
    };
  };
  const dashboard = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/ambassadors/me').set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getMyAmbassadorDashboard');
    return res.body as {
      code: string;
      level: { code: string; commissionBps: number };
      payoutsHeld: boolean;
      referrals: { total: number; active: number; pending: number };
      commissions: {
        pendingCherries: number;
        heldCherries: number;
        paidCherries: number;
        reversedCherries: number;
      };
      month: { activeReferrals: number; topupCoins: number };
      history: { month: string; levelAfter: string; rewardStatus: string }[];
    };
  };
  const application = (u: TestUser, over: Record<string, unknown> = {}) =>
    ctx.http
      .post('/api/v1/ambassadors/applications')
      .set(auth(u))
      .send({
        country: 'EG',
        links: ['https://example.com/@me'],
        audienceSize: 12_000,
        motivation: 'I host a weekly show and want to bring my audience.',
        ...over,
      });
  const issueOf = (res: request.Response) =>
    (res.body as { error: { details?: { issue: string }[] } }).error.details?.[0]?.issue;
  const commissionsOf = (u: TestUser) =>
    ctx.prisma.ambassadorCommission.findMany({
      where: { ambassadorUserId: u.id },
      orderBy: { createdAt: 'asc' },
    });
  const cherriesOf = async (u: TestUser) =>
    (await ctx.prisma.cherryWallet.findUnique({ where: { userId: u.id } }))?.cherries ?? 0n;
  const sweep = () => sweeper.sweep(now());

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
  /** Signs the panel accounts in again after the clock jumped past the session's idle time. */
  const relogin = async (...admins: Admin[]) => {
    for (const a of admins) {
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
  const later = async (ms: number) => {
    advance(ms);
    await relogin(owner, support, finance);
  };
  const aget = (a: Admin, path: string) => ctx.http.get(`/api/v1${path}`).set('Cookie', a.cookie);
  const awrite = (a: Admin, method: 'post' | 'put', path: string, body: object = {}) =>
    ctx.http[method](`/api/v1${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf).send(body);
  const settings = async (owner: Admin, patch: Record<string, unknown>) => {
    const res = await awrite(owner, 'put', '/admin/ambassador-settings', {
      ...patch,
      reason: 'test',
      totpCode: nextCode(owner.secret),
    });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'updateAdminAmbassadorSettings');
    return res.body as Record<string, unknown>;
  };

  // ---- recharge paths ----------------------------------------------------------------------------------------
  const cardTopup = async (u: TestUser, coins: bigint) => {
    const terms = randomUUID();
    await ctx.prisma.topupTermsAcceptance.create({
      data: { id: terms, userId: u.id, termsVersion: 't1', termsText: 'x', locale: 'ar', acceptedAt: now() },
    });
    const orderId = randomUUID();
    const order = await ctx.prisma.topupOrder.create({
      data: {
        id: orderId,
        userId: u.id,
        termsAcceptanceId: terms,
        packageId: String(coins),
        coins,
        amountMinor: 1250,
        currency: 'USD',
        paymentMethodTypes: ['card'],
        status: 'PENDING',
        createdAt: now(),
      },
    });
    const rules = { ...ctx.config.recharge.badges, cherriesPerCoin: ctx.config.economy.cherriesPerCoin };
    await ctx.prisma.$transaction((tx) => creditOrderIn(tx, order, now(), rules, `evt_${orderId}`, 'card'));
    return orderId;
  };
  const refund = async (orderId: string) => {
    const fresh = await ctx.prisma.topupOrder.update({
      where: { id: orderId },
      data: { refundedMinor: 1250 },
    });
    await ctx.prisma.$transaction((tx) => reconcileOrderIn(tx, fresh, `evt_refund_${orderId}`, now()));
  };
  /** Makes `user` an ACTIVE recharge agent with stock (as d217's `activeAgent`, for an existing account). */
  const makeAgent = async (user: TestUser) => {
    const appId = randomUUID();
    await ctx.prisma.rechargeAgentApplication.create({
      data: {
        id: appId,
        userId: user.id,
        status: 'APPROVED',
        fullName: 'محمد أحمد علي حسن',
        phone: '+201001234567',
        photoKey: `private/recharge-agents/${appId}/photo.webp`,
        selfieKey: `private/recharge-agents/${appId}/selfie.webp`,
        locations: [{ country: 'EG', cities: ['Cairo'] }],
        paymentMethods: [{ country: 'EG', type: 'MOBILE_WALLET', details: 'x' }],
        decidedAt: now(),
      },
    });
    await ctx.prisma.rechargeAgent.create({
      data: {
        userId: user.id,
        applicationId: appId,
        countries: ['EG'],
        locations: [{ country: 'EG', cities: ['Cairo'] }],
        paymentTypes: { EG: ['MOBILE_WALLET'] },
      },
    });
    const coins = 30_000_000n;
    await ctx.prisma.$transaction((tx) =>
      topUpIn(tx, user.id, coins, (coins * 1200n + 500_000n) / 1_000_000n, null, AGENT_RULES, now()),
    );
  };

  let owner: Admin;
  let support: Admin;
  let finance: Admin;

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: clock });
    ctx = await createTestApp({
      TRUST_PROXY: 'loopback',
      APP_PUBLIC_URL: 'https://kabsolive.example',
      ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
      JWT_ACCESS_TTL_SECONDS: String(90 * 86_400),
      REFRESH_TTL_SECONDS: String(90 * 86_400),
      REFRESH_ABSOLUTE_TTL_SECONDS: String(90 * 86_400),
      ADMIN_SESSION_IDLE_SECONDS: '86400',
      ADMIN_SESSION_MAX_SECONDS: '604800',
      RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
      RATE_LIMIT_ADMIN_IP: '100000/900',
      RECHARGE_AGENT_SWEEP_INTERVAL_SECONDS: '0',
      LIVE_RANKINGS_TIME_ZONE: 'UTC',
    });
    sweeper = ctx.app.get(AmbassadorSweeper);
    referrals = ctx.app.get(ReferralSweeper);
    owner = await makeAdmin(['OWNER']);
    support = await makeAdmin(['SUPPORT']);
    finance = await makeAdmin(['FINANCE']);
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  let amb: TestUser;

  it('is OFF by default: no form, apply 503, and an ambassador appointed meanwhile keeps the normal D217 track', async () => {
    const u = await signup();
    const p = await programme(u);
    expect(p).toMatchObject({
      enabled: false,
      status: 'NONE',
      canApply: false,
      refusal: 'DISABLED',
      levels: [],
    });
    const res = await application(u);
    expect(res.status).toBe(503);
    // The panel may appoint before launch; nothing earns while off.
    amb = await signup();
    const appoint = await awrite(owner, 'post', '/admin/ambassadors', {
      username: amb.username,
      reason: 'launch team',
    });
    expect(appoint.status, JSON.stringify(appoint.body)).toBe(201);
    expectContract(appoint, 'appointAdminAmbassador');
    const friend = await signup({ code: await codeOf(amb) });
    expect(await ctx.prisma.ambassadorReferral.count({ where: { inviteeUserId: friend.id } })).toBe(0);
    const d217 = await ctx.prisma.referralReward.findMany({ where: { userId: amb.id } });
    expect(d217.map((r) => r.kind)).toEqual(['SIGNUP_INVITER']);
    // The settings are the OWNER's: SUPPORT and FINANCE get 403.
    expect((await aget(support, '/admin/ambassador-settings')).status).toBe(403);
    expect((await aget(finance, '/admin/ambassadors')).status).toBe(403);
    const s = await aget(owner, '/admin/ambassador-settings');
    expect(s.status).toBe(200);
    expectContract(s, 'getAdminAmbassadorSettings');
    expect(s.body).toMatchObject({
      enabled: false,
      attributionWindowDays: 90,
      holdDays: 14,
      minActiveDays: 3,
      minActiveTopupCoins: 100_000,
      monthlyCapCherries: 50_000_000,
      velocityMaxPerDay: 30,
      ipClusterMax: 3,
      ipClusterWindowDays: 30,
    });
    expect(
      (s.body.levels as { code: string; commissionBps: number }[]).map((l) => [l.code, l.commissionBps]),
    ).toEqual([
      ['BRONZE', 300],
      ['SILVER', 500],
      ['GOLD', 700],
      ['DIAMOND', 1000],
    ]);
  });

  it('the OWNER turns it on (code again; bad levels refused); the switch is audited', async () => {
    const bad = await awrite(owner, 'put', '/admin/ambassador-settings', {
      levels: [
        {
          code: 'BRONZE',
          minActiveReferrals: 1,
          minTopupCoins: 0,
          commissionBps: 300,
          reward: { kind: 'NONE' },
        },
      ],
      reason: 'x',
      totpCode: nextCode(owner.secret),
    });
    expect(bad.status).toBe(400);
    expect(
      (
        await awrite(support, 'put', '/admin/ambassador-settings', {
          enabled: true,
          reason: 'x',
          totpCode: '000000',
        })
      ).status,
    ).toBe(403);
    // A 2-day hold keeps the whole flow inside one month (the default is 14 days).
    const after = await settings(owner, { enabled: true, holdDays: 2 });
    expect(after).toMatchObject({ enabled: true, holdDays: 2 });
    expect(await ctx.prisma.auditLog.count({ where: { action: 'ambassador.settings.update' } })).toBe(1);
  });

  it('applies (https links only), one pending at a time; SUPPORT approves; the person is notified; staff may not apply', async () => {
    const u = await signup();
    expect((await programme(u)).canApply).toBe(true);
    const http = await application(u, { links: ['http://example.com/me'] });
    expect(http.status).toBe(400);
    const ok = await application(u);
    expect(ok.status, JSON.stringify(ok.body)).toBe(201);
    expectContract(ok, 'applyForAmbassadorProgramme');
    expect(ok.body.status).toBe('PENDING');
    const again = await application(u);
    expect(again.status).toBe(409);
    expect(again.body.error.code).toBe('AMBASSADOR_APPLICATION_NOT_ALLOWED');
    expect(issueOf(again)).toBe('PENDING');
    // Kabso Team accounts (any panel role, the OWNER included) cannot be ambassadors.
    const staffApply = await application(support);
    expect(staffApply.status).toBe(409);
    expect(issueOf(staffApply)).toBe('STAFF');
    expect((await programme(owner)).refusal).toBe('STAFF');
    const staffAppoint = await awrite(owner, 'post', '/admin/ambassadors', {
      username: support.username,
      reason: 'x',
    });
    expect(staffAppoint.status).toBe(409);
    expect(issueOf(staffAppoint)).toBe('staff');

    const list = await aget(support, '/admin/ambassador-applications?status=PENDING');
    expect(list.status).toBe(200);
    expectContract(list, 'listAdminAmbassadorApplications');
    const row = (list.body.data as { id: string; user: { id: string } }[]).find((a) => a.user.id === u.id)!;
    const approve = await awrite(support, 'post', `/admin/ambassador-applications/${row.id}/approve`);
    expect(approve.status, JSON.stringify(approve.body)).toBe(200);
    expectContract(approve, 'approveAdminAmbassadorApplication');
    expect((await programme(u)).status).toBe('AMBASSADOR');
    expect(
      await ctx.prisma.notification.count({
        where: { recipientId: u.id, type: 'AMBASSADOR_APPLICATION_APPROVED' },
      }),
    ).toBe(1);
    const d = await dashboard(u);
    expect(d.level).toEqual({ code: 'BRONZE', commissionBps: 300 });
    expect(d.code).toBe(await codeOf(u));
    const stranger = await signup();
    expect((await ctx.http.get('/api/v1/ambassadors/me').set(auth(stranger))).status).toBe(404);

    // Rejected with a reason the person sees, and notified.
    const v = await signup();
    expect((await application(v)).status).toBe(201);
    const app = await ctx.prisma.ambassadorApplication.findFirstOrThrow({ where: { userId: v.id } });
    expect(
      (await awrite(finance, 'post', `/admin/ambassador-applications/${app.id}/reject`, { reason: 'x' }))
        .status,
    ).toBe(403);
    const reject = await awrite(support, 'post', `/admin/ambassador-applications/${app.id}/reject`, {
      reason: 'Audience too small for now',
    });
    expect(reject.status).toBe(200);
    expect((await programme(v)).status).toBe('REJECTED');
    expect(
      await ctx.prisma.notification.count({
        where: { recipientId: v.id, type: 'AMBASSADOR_APPLICATION_REJECTED' },
      }),
    ).toBe(1);
    expect(await ctx.prisma.auditLog.count({ where: { action: 'ambassador.application.approve' } })).toBe(1);
  });

  let friend: TestUser;
  let order1: string;

  it('precedence: an ambassador’s friend earns NO D217 inviter reward; each top-up makes a held commission', async () => {
    const before = await ctx.prisma.referralReward.count({ where: { userId: amb.id } });
    friend = await signup({ code: await codeOf(amb) });
    const ref = await ctx.prisma.ambassadorReferral.findUniqueOrThrow({
      where: { inviteeUserId: friend.id },
    });
    expect(ref).toMatchObject({ ambassadorUserId: amb.id, status: 'PENDING' });
    order1 = await cardTopup(friend, 1_000_000n);
    // No SIGNUP_INVITER, no FIRST_RECHARGE for the ambassador.
    expect(await ctx.prisma.referralReward.count({ where: { userId: amb.id } })).toBe(before);
    const [c] = await commissionsOf(amb);
    // BRONZE 3 %: 1 000 000 coins × 10 cherries × 300 / 10 000.
    expect(c).toMatchObject({
      status: 'PENDING',
      cherries: 300_000n,
      rateBps: 300,
      level: 'BRONZE',
      rechargeReason: 'CARD_TOPUP',
    });
    // The D217 hold passes: the referral qualifies but pays the ambassador nothing, and no milestone counts it (a
    // milestone at 2 friends: the ambassador has one D217 friend from before the switch, and this one must not count).
    await withMigrationClient((db) =>
      db.referralSettings.update({
        where: { id: 1 },
        data: { milestones: [{ friends: 2, cherries: 1000 }] },
      }),
    );
    await later(25 * HOUR);
    await referrals.sweep(now());
    const d217 = await ctx.prisma.referral.findUniqueOrThrow({ where: { inviteeUserId: friend.id } });
    expect(d217.status).toBe('QUALIFIED');
    expect(await ctx.prisma.referralReward.count({ where: { referralId: d217.id } })).toBe(0);
    expect(
      await ctx.prisma.referralReward.count({
        where: { userId: amb.id, kind: { in: ['MILESTONE', 'FIRST_RECHARGE'] } },
      }),
    ).toBe(0);
    expect(await ctx.prisma.referralReward.count({ where: { userId: amb.id } })).toBe(before);
    // Before its hold ends the commission stays pending.
    await sweep();
    expect((await commissionsOf(amb))[0]!.status).toBe('PENDING');
    expect((await dashboard(amb)).commissions.pendingCherries).toBe(300_000);
  });

  it('after the hold and the activity rule (3 days, 100 000 coins) the commission is credited as withdrawable cherries', async () => {
    await later(2 * DAY);
    const before = await cherriesOf(amb);
    const r = await sweep();
    expect(r.activated).toBe(1);
    expect(r.credited).toBe(1);
    expect(
      (await ctx.prisma.ambassadorReferral.findUniqueOrThrow({ where: { inviteeUserId: friend.id } })).status,
    ).toBe('ACTIVE');
    expect(await cherriesOf(amb)).toBe(before + 300_000n);
    const row = await ctx.prisma.cherryLedgerEntry.findFirstOrThrow({
      where: { userId: amb.id, reason: 'AMBASSADOR_COMMISSION' },
    });
    expect(row.delta).toBe(300_000n);
    const d = await dashboard(amb);
    expect(d.commissions.paidCherries).toBe(300_000);
    expect(d.referrals).toMatchObject({ total: 1, active: 1, pending: 0 });
    expect(d.month).toMatchObject({ activeReferrals: 1, topupCoins: 1_000_000 });
  });

  it('a refund voids a pending commission and claws back a credited one (once)', async () => {
    const order2 = await cardTopup(friend, 500_000n);
    await refund(order2);
    const pending = (await commissionsOf(amb)).find((c) => c.rechargeReference === order2)!;
    expect(pending).toMatchObject({ status: 'VOID', voidReason: 'RECHARGE_REVERSED' });
    const before = await cherriesOf(amb);
    await refund(order1);
    const credited = (await commissionsOf(amb)).find((c) => c.rechargeReference === order1)!;
    expect(credited.status).toBe('REVERSED');
    expect(await cherriesOf(amb)).toBe(before - 300_000n);
    expect(
      await ctx.prisma.cherryLedgerEntry.count({
        where: { userId: amb.id, reason: 'AMBASSADOR_COMMISSION_REVERSAL' },
      }),
    ).toBe(1);
    await ctx.prisma.$transaction(async (tx) => {
      const o = await tx.topupOrder.findUniqueOrThrow({ where: { id: order1 } });
      await reconcileOrderIn(tx, o, 'evt_again', now());
    });
    expect(
      await ctx.prisma.cherryLedgerEntry.count({
        where: { userId: amb.id, reason: 'AMBASSADOR_COMMISSION_REVERSAL' },
      }),
    ).toBe(1);
    expect((await dashboard(amb)).commissions.reversedCherries).toBe(300_000);
  });

  it('the monthly cap trims a commission, then pays nothing more this month', async () => {
    await settings(owner, { monthlyCapCherries: 400_000 });
    // Used this month: 0 (the first was reversed, the second voided). 1 000 000 coins → 300 000; then 300 000 → cap.
    const orders = [];
    for (let i = 0; i < 3; i++) {
      orders.push(await cardTopup(friend, 1_000_000n));
      advance(1_000);
    }
    const all = await commissionsOf(amb);
    const last3 = orders.map((o) => all.find((c) => c.rechargeReference === o)!);
    expect(last3.map((c) => [c.status, c.cherries, c.cappedCherries, c.voidReason])).toEqual([
      ['PENDING', 300_000n, 0n, null],
      ['PENDING', 100_000n, 200_000n, null],
      ['VOID', 0n, 300_000n, 'MONTHLY_CAP'],
    ]);
    await settings(owner, { monthlyCapCherries: 50_000_000 });
  });

  it('self-referral is blocked (same device as the ambassador): no ambassador referral, nothing paid', async () => {
    const self = await signup({ code: await codeOf(amb), installId: amb.installId });
    const ref = await ctx.prisma.referral.findUniqueOrThrow({ where: { inviteeUserId: self.id } });
    expect(ref.status).toBe('REJECTED');
    expect(await ctx.prisma.ambassadorReferral.count({ where: { inviteeUserId: self.id } })).toBe(0);
    const n = (await commissionsOf(amb)).length;
    await cardTopup(self, 1_000_000n);
    expect((await commissionsOf(amb)).length).toBe(n);
  });

  it('self-payment (the ambassador sells the coins as a recharge agent): VOID and the ambassador goes under review', async () => {
    const b = await signup();
    expect(
      (await awrite(owner, 'post', '/admin/ambassadors', { username: b.username, reason: 'x' })).status,
    ).toBe(201);
    await makeAgent(b);
    const f = await signup({ code: await codeOf(b) });
    const sale = await ctx.http
      .post('/api/v1/me/recharge-agent/sales')
      .set(auth(b))
      .set('Idempotency-Key', randomUUID())
      .send({ buyer: f.username, coins: 1_000_000 });
    expect(sale.status, JSON.stringify(sale.body)).toBe(201);
    const [c] = await commissionsOf(b);
    expect(c).toMatchObject({
      status: 'VOID',
      voidReason: 'SELF_PAYMENT',
      rechargeReason: 'RECHARGE_PURCHASE',
    });
    const row = await ctx.prisma.ambassador.findUniqueOrThrow({ where: { userId: b.id } });
    expect(row).toMatchObject({ underReview: true, reviewReason: 'SELF_PAYMENT' });
    expect((await dashboard(b)).payoutsHeld).toBe(true);
    // The OWNER ends the review (code again); SUPPORT cannot.
    expect(
      (
        await awrite(support, 'post', `/admin/ambassadors/${b.id}/clear-review`, {
          reason: 'x',
          totpCode: '000000',
        })
      ).status,
    ).toBe(403);
    const clear = await awrite(owner, 'post', `/admin/ambassadors/${b.id}/clear-review`, {
      reason: 'checked',
      totpCode: nextCode(owner.secret),
    });
    expect(clear.status, JSON.stringify(clear.body)).toBe(200);
    expectContract(clear, 'clearAdminAmbassadorReview');
    expect(clear.body.ambassador.underReview).toBe(false);
  });

  it('velocity and IP clustering flag the ambassador; the clustered referral counts for nothing', async () => {
    const c = await signup();
    expect(
      (await awrite(owner, 'post', '/admin/ambassadors', { username: c.username, reason: 'x' })).status,
    ).toBe(201);
    await settings(owner, { ipClusterMax: 1, velocityMaxPerDay: 2 });
    const code = await codeOf(c);
    const ip = nextIp();
    const f1 = await signup({ code, ip });
    const f2 = await signup({ code, ip });
    expect(
      (await ctx.prisma.ambassadorReferral.findUniqueOrThrow({ where: { inviteeUserId: f1.id } })).status,
    ).toBe('PENDING');
    expect(
      await ctx.prisma.ambassadorReferral.findUniqueOrThrow({ where: { inviteeUserId: f2.id } }),
    ).toMatchObject({
      status: 'VOID',
      voidReason: 'IP_CLUSTER',
    });
    await signup({ code });
    const flags = await ctx.prisma.ambassadorFlag.findMany({
      where: { ambassadorUserId: c.id },
      orderBy: { createdAt: 'asc' },
    });
    expect(flags.map((f) => f.kind)).toEqual(['IP_CLUSTER', 'VELOCITY']);
    // A clustered friend's top-ups pay nothing.
    await cardTopup(f2, 1_000_000n);
    expect(await ctx.prisma.ambassadorCommission.count({ where: { ambassadorUserId: c.id } })).toBe(0);
    await settings(owner, { ipClusterMax: 3, velocityMaxPerDay: 30 });
  });

  it('freeze holds every due commission; unfreeze (code again) pays them at the next sweep', async () => {
    const freeze = await awrite(owner, 'post', `/admin/ambassadors/${amb.id}/freeze`, {
      reason: 'checking a complaint',
    });
    expect(freeze.status, JSON.stringify(freeze.body)).toBe(200);
    expectContract(freeze, 'freezeAdminAmbassador');
    expect(
      (await awrite(support, 'post', `/admin/ambassadors/${amb.id}/freeze`, { reason: 'x' })).status,
    ).toBe(403);
    await later(3 * DAY);
    const before = await cherriesOf(amb);
    await sweep();
    expect(await cherriesOf(amb)).toBe(before);
    const held = await dashboard(amb);
    expect(held.payoutsHeld).toBe(true);
    expect(held.commissions.heldCherries).toBe(400_000);
    const unfreeze = await awrite(owner, 'post', `/admin/ambassadors/${amb.id}/unfreeze`, {
      reason: 'resolved',
      totpCode: nextCode(owner.secret),
    });
    expect(unfreeze.status).toBe(200);
    await sweep();
    expect(await cherriesOf(amb)).toBe(before + 400_000n);
    expect(
      await ctx.prisma.auditLog.count({
        where: { action: { in: ['ambassador.freeze', 'ambassador.unfreeze'] } },
      }),
    ).toBe(2);
  });

  it('an ambassador who joins the team stops earning (staff are never ambassadors)', async () => {
    const s = await signup();
    expect(
      (await awrite(owner, 'post', '/admin/ambassadors', { username: s.username, reason: 'x' })).status,
    ).toBe(201);
    const f = await signup({ code: await codeOf(s) });
    await withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, s.email, 'SUPPORT')));
    await cardTopup(f, 1_000_000n);
    const [c] = await ctx.prisma.ambassadorCommission.findMany({ where: { ambassadorUserId: s.id } });
    expect(c).toMatchObject({ status: 'VOID', voidReason: 'STAFF' });
  });

  it('the month is evaluated after it ends: promotion, the coin reward through the ledger, the notifications', async () => {
    await settings(owner, {
      levels: [
        {
          code: 'BRONZE',
          minActiveReferrals: 0,
          minTopupCoins: 0,
          commissionBps: 300,
          reward: { kind: 'NONE' },
        },
        {
          code: 'SILVER',
          minActiveReferrals: 1,
          minTopupCoins: 1_000_000,
          commissionBps: 500,
          reward: { kind: 'COINS', amount: 100_000 },
        },
        {
          code: 'GOLD',
          minActiveReferrals: 5,
          minTopupCoins: 50_000_000,
          commissionBps: 700,
          reward: { kind: 'COINS', amount: 500_000 },
        },
      ],
    });
    const month = (await dashboard(amb)).history.length;
    expect(month).toBe(0);
    const real2 = new Date(clock);
    clock = Date.UTC(real2.getUTCFullYear(), real2.getUTCMonth() + 1, 1, 6, 0, 0);
    await later(0);
    const r = await sweep();
    expect(r.monthsEvaluated).toBeGreaterThanOrEqual(1);
    const row = await ctx.prisma.ambassadorMonth.findFirstOrThrow({ where: { ambassadorUserId: amb.id } });
    expect(row).toMatchObject({
      activeReferrals: 1,
      levelBefore: 'BRONZE',
      metLevel: 'SILVER',
      levelAfter: 'SILVER',
      rewardStatus: 'GRANTED',
    });
    expect((await ctx.prisma.ambassador.findUniqueOrThrow({ where: { userId: amb.id } })).level).toBe(
      'SILVER',
    );
    const coin = await ctx.prisma.walletLedgerEntry.findFirstOrThrow({
      where: { userId: amb.id, reason: 'AMBASSADOR_REWARD' },
    });
    expect(coin.delta).toBe(100_000n);
    for (const type of ['AMBASSADOR_LEVEL_UP', 'AMBASSADOR_REWARD_GRANTED'] as const) {
      expect(await ctx.prisma.notification.count({ where: { recipientId: amb.id, type } })).toBe(1);
    }
    // Once per month: a second sweep changes nothing.
    await sweep();
    expect(
      await ctx.prisma.walletLedgerEntry.count({ where: { userId: amb.id, reason: 'AMBASSADOR_REWARD' } }),
    ).toBe(1);
    const d = await dashboard(amb);
    expect(d.level.code).toBe('SILVER');
    expect(d.history[0]).toMatchObject({ levelAfter: 'SILVER', rewardStatus: 'GRANTED' });
  });

  it('the panel: SUPPORT sees performance without money; the OWNER sees the totals; campaigns', async () => {
    const asSupport = await aget(support, '/admin/ambassadors');
    expect(asSupport.status).toBe(200);
    expectContract(asSupport, 'listAdminAmbassadors');
    const mine = (asSupport.body.data as { user: { id: string }; commissions: unknown }[]).find(
      (r) => r.user.id === amb.id,
    )!;
    expect(mine.commissions).toBeNull();
    const asOwner = await aget(owner, `/admin/ambassadors/${amb.id}`);
    expect(asOwner.status).toBe(200);
    expectContract(asOwner, 'getAdminAmbassador');
    expect(asOwner.body.commissions.paidCherries).toBe(400_000);
    expect(asOwner.body.level).toBe('SILVER');
    const detailSupport = await aget(support, `/admin/ambassadors/${amb.id}`);
    expect(detailSupport.body.commissionList.every((c: { cherries: unknown }) => c.cherries === null)).toBe(
      true,
    );
    const review = await aget(owner, '/admin/ambassadors?status=REVIEW');
    expect(review.status).toBe(200);

    const create = await awrite(support, 'post', '/admin/ambassador-campaigns', {
      title: 'Ramadan nights — Cairo',
      country: 'EG',
      startsOn: '2027-02-20',
      endsOn: '2027-03-20',
      notes: 'Two lives a week with the team.',
      ambassadors: [amb.id],
    });
    expect(create.status, JSON.stringify(create.body)).toBe(201);
    expectContract(create, 'createAdminAmbassadorCampaign');
    const bad = await awrite(support, 'post', '/admin/ambassador-campaigns', {
      title: 'x',
      startsOn: '2027-02-20',
      endsOn: '2027-02-19',
    });
    expect(bad.status).toBe(400);
    const notAmb = await awrite(support, 'post', '/admin/ambassador-campaigns', {
      title: 'x',
      startsOn: '2027-02-20',
      endsOn: '2027-02-21',
      ambassadors: [support.id],
    });
    expect(notAmb.status).toBe(400);
    const update = await awrite(support, 'put', `/admin/ambassador-campaigns/${create.body.id}`, {
      title: 'Ramadan nights — Cairo and Giza',
      startsOn: '2027-02-20',
      endsOn: '2027-03-25',
      ambassadors: [],
    });
    expect(update.status).toBe(200);
    expect(update.body.ambassadors).toEqual([]);
    const list = await aget(support, '/admin/ambassador-campaigns');
    expectContract(list, 'listAdminAmbassadorCampaigns');
    expect(list.body.data[0].title).toBe('Ramadan nights — Cairo and Giza');
    expect((await aget(finance, '/admin/ambassador-campaigns')).status).toBe(403);
  });
});
