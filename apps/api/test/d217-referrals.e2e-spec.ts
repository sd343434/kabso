/**
 * D217 (owner 2026-11-01; contract v1.74-social, CONVENTIONS §10.71): «دعوة الأصدقاء» behind «اربح المال». A person's
 * stable invite code and link; a friend applies it at sign-up or later (once, within the window); rewards in
 * withdrawable cherries (ledger REFERRAL_REWARD) held before they are credited and re-checked (banned / deleted /
 * locked accounts void them); the friend's first recharge on each path (website top-up, an agent's sale, a recharge
 * order); the milestones; the fraud rules (own code, same device, same IP, mailbox aliases, a device or a mailbox
 * already referred, the daily cap); the panel's «الدعوات» with the capabilities and the code again; the settings
 * and the switch; the CLI. End to end against PostgreSQL + Redis.
 */
import { execFile } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { promisify } from 'node:util';
import sharp from 'sharp';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { holdCherriesIn } from '../src/modules/economy/cherry-ledger.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { notificationBody } from '../src/modules/push/push-texts.js';
import { topUpIn } from '../src/modules/recharge/recharge-core.js';
import { ReferralSweeper } from '../src/modules/referrals/referrals.service.js';
import { creditOrderIn, reconcileOrderIn } from '../src/modules/topup/topup-core.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, openapi, operations } from './helpers/openapi.js';
import { createTestApp, newUser, withMigrationClient, type TestContext } from './helpers/test-app.js';

const run = promisify(execFile);
const HOUR = 3_600_000;
const DAY = 24 * HOUR;
const COOKIE = '__Host-kabso_admin';
const TIERS = [{ minCoins: 0, minorPerMillion: 1200 }];
const AGENT_RULES = { activationMinCoins: 30_000_000, priceTiers: TIERS, currency: 'USD' };

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
interface Mine {
  enabled: boolean;
  code: string;
  link: string;
  rules: Record<string, number>;
  upTo: { total: number; milestones: number };
  counts: { invited: number; qualified: number; pending: number };
  rewards: { pendingCherries: number; creditedCherries: number };
  milestones: { friends: number; cherries: number; state: string }[];
  invitees: { name: string; status: string; joinedAt: string; firstRecharge: boolean }[];
  invitedBy: { status: string; source: string; at: string } | null;
  canApply: boolean;
  applyUntil: string | null;
}

describe('D217 contract coverage', () => {
  it('openapi v1.74-social declares the page, the later code, the ticker and «الدعوات»', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'getMyReferral GET /api/v1/me/referral',
        'applyReferralCode POST /api/v1/me/referral/apply',
        'listRecentReferralRewards GET /api/v1/referrals/recent-rewards',
        'listAdminReferrals GET /api/v1/admin/referrals',
        'getAdminReferral GET /api/v1/admin/referrals/{referralId}',
        'approveAdminReferral POST /api/v1/admin/referrals/{referralId}/approve',
        'voidAdminReferral POST /api/v1/admin/referrals/{referralId}/void',
        'getAdminReferralSettings GET /api/v1/admin/referral-settings',
        'updateAdminReferralSettings PUT /api/v1/admin/referral-settings',
      ]),
    );
    const schemas = (openapi.components as { schemas: Record<string, Record<string, unknown>> }).schemas;
    expect((schemas.CherryLedgerReason as { enum: string[] }).enum).toEqual(
      expect.arrayContaining(['REFERRAL_REWARD', 'REFERRAL_REVERSAL']),
    );
    expect((schemas.NotificationType as { enum: string[] }).enum).toContain('REFERRAL_REWARD_REVERSED');
    expect((schemas.ReferralRewardStatus as { enum: string[] }).enum).toContain('REVERSED');
    expect(Object.keys(schemas.RegisterRequest!.properties as object)).toContain('referralCode');
    expect(Object.keys(schemas.DeviceInfo!.properties as object)).toContain('installId');
    for (const o of operations().filter((x) => x.path.startsWith('/api/v1/admin/referral'))) {
      expect(o.spec.security).toEqual([{ adminSession: [] }]);
      if (o.method !== 'get') expect(JSON.stringify(o.spec.parameters)).toContain('AdminCsrf');
    }
    const ticker = operations().find((o) => o.operationId === 'listRecentReferralRewards')!;
    expect(ticker.spec.security).toEqual([]);
  });

  it('the claw-back push text exists in both languages', () => {
    const n = {
      type: 'REFERRAL_REWARD_REVERSED',
      actorName: null,
      actorCount: 0,
      targetType: null,
      targetId: null,
      targetText: null,
    };
    expect(notificationBody(n as never, 'ar')).toContain('Kabso');
    expect(notificationBody(n as never, 'en')).toContain('Kabso');
  });
});

describe('D217 «دعوة الأصدقاء»', { timeout: 900_000 }, () => {
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  let sweeper: ReferralSweeper;
  let png: Buffer;
  let clock = Date.now();
  const advance = (ms: number) => {
    clock += ms;
    vi.setSystemTime(clock);
  };
  const now = () => new Date(clock);
  let ipCounter = 10;
  const nextIp = () => {
    ipCounter += 1;
    return `198.51.${Math.floor(ipCounter / 250)}.${(ipCounter % 250) + 1}`;
  };

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}`, 'X-Forwarded-For': u.ip });

  /** A sign-up from its own IP and install id (or the given ones), with an optional invite code. */
  const signupRaw = async (
    opts: { code?: string; ip?: string; installId?: string | null; email?: string } = {},
  ) => {
    const ip = opts.ip ?? nextIp();
    const installId = opts.installId === undefined ? `install-${randomUUID()}` : opts.installId;
    const device = {
      name: 'Pixel 9',
      platform: 'android',
      appVersion: '1.0.0',
      ...(installId ? { installId } : {}),
    };
    const payload = newUser({
      device,
      ...(opts.email ? { email: opts.email } : {}),
      ...(opts.code !== undefined ? { referralCode: opts.code } : {}),
    });
    const email = String(payload.email).trim().toLowerCase();
    const before = ctx.mail.sent.length;
    const reg = await ctx.http.post('/api/v1/auth/register').set('X-Forwarded-For', ip).send(payload);
    return { reg, payload, email, ip, installId, before };
  };
  const signup = async (
    opts: { code?: string; ip?: string; installId?: string | null; email?: string } = {},
  ): Promise<TestUser> => {
    const { reg, payload, email, ip, installId, before } = await signupRaw(opts);
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
      installId: installId ?? '',
    };
  };
  const mine = async (u: TestUser): Promise<Mine> => {
    const res = await ctx.http.get('/api/v1/me/referral').set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getMyReferral');
    return res.body as Mine;
  };
  const apply = (u: TestUser, code: string, installId: string | undefined = u.installId || undefined) =>
    ctx.http
      .post('/api/v1/me/referral/apply')
      .set(auth(u))
      .send({ code, ...(installId ? { installId } : {}) });
  const issueOf = (res: request.Response) =>
    (res.body as { error: { details?: { issue: string }[] } }).error.details?.[0]?.issue;
  const referralOf = (u: TestUser) => ctx.prisma.referral.findUnique({ where: { inviteeUserId: u.id } });
  const rewardsOf = (u: TestUser) =>
    ctx.prisma.referralReward.findMany({ where: { userId: u.id }, orderBy: { createdAt: 'asc' } });
  const cherriesOf = async (u: TestUser) =>
    (await ctx.prisma.cherryWallet.findUnique({ where: { userId: u.id } }))?.cherries ?? 0n;
  const settings = (data: Record<string, unknown>) =>
    withMigrationClient((db) => db.referralSettings.update({ where: { id: 1 }, data }));
  const sweep = (at: number) => sweeper.sweep(new Date(at));

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
  const aget = (a: Admin, path: string) => ctx.http.get(`/api/v1${path}`).set('Cookie', a.cookie);
  const awrite = (a: Admin, method: 'post' | 'put', path: string, body: object = {}) =>
    ctx.http[method](`/api/v1${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf).send(body);

  // ---- recharge paths ----------------------------------------------------------------------------------------
  /** An ACTIVE recharge agent (EG mobile wallet) with `coins` of stock. */
  const activeAgent = async (coins = 30_000_000n): Promise<TestUser & { code: string }> => {
    const user = await signup();
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
    const r = await ctx.prisma.$transaction((tx) =>
      topUpIn(tx, user.id, coins, (coins * 1200n + 500_000n) / 1_000_000n, null, AGENT_RULES, now()),
    );
    return { ...user, code: r.code! };
  };
  /** A website top-up of `coins` credited as the Stripe webhook does (`creditOrderIn`). */
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
  /** An agent's direct sale (HTTP). */
  const agentSale = async (agent: TestUser, buyer: TestUser, coins: number) => {
    const res = await ctx.http
      .post('/api/v1/me/recharge-agent/sales')
      .set(auth(agent))
      .set('Idempotency-Key', randomUUID())
      .send({ buyer: buyer.username, coins });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
  };
  const upload = async (u: TestUser): Promise<string> => {
    const slot = await ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send({ kind: 'RECHARGE_ORDER_IMAGE', contentType: 'image/png', byteSize: png.length });
    expect(slot.status, JSON.stringify(slot.body)).toBe(201);
    expect(storage.upload(slot.body.uploadUrl as string, png, 'image/png')).toBe(true);
    return slot.body.uploadId as string;
  };
  /** A recharge order taken to COMPLETED by the agent's «استلمت» (HTTP). */
  const rechargeOrder = async (buyer: TestUser, agent: TestUser & { code: string }, coins: number) => {
    const act = (u: TestUser, id: string, action: string, body: object = {}) =>
      ctx.http.post(`/api/v1/recharge-orders/${id}/${action}`).set(auth(u)).send(body);
    const res = await ctx.http
      .post('/api/v1/recharge-orders')
      .set(auth(buyer))
      .set('Idempotency-Key', randomUUID())
      .send({ agentCode: agent.code, country: 'EG', coins, paymentType: 'MOBILE_WALLET' });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const id = res.body.id as string;
    const det = await act(agent, id, 'payment-details', {
      method: 'MOBILE_WALLET',
      details: 'Vodafone Cash 0100',
    });
    expect(det.status, JSON.stringify(det.body)).toBe(200);
    expect((await act(buyer, id, 'notice-ack')).status).toBe(200);
    const proof = await upload(buyer);
    const paid = await act(buyer, id, 'paid', { proofUploadId: proof });
    expect(paid.status, JSON.stringify(paid.body)).toBe(200);
    const done = await act(agent, id, 'confirm');
    expect(done.status, JSON.stringify(done.body)).toBe(200);
    return id;
  };

  beforeAll(async () => {
    png = await sharp({ create: { width: 64, height: 48, channels: 3, background: '#c33' } })
      .png()
      .toBuffer();
    vi.useFakeTimers({ toFake: ['Date'], now: clock });
    ctx = await createTestApp(
      {
        TRUST_PROXY: 'loopback',
        APP_PUBLIC_URL: 'https://kabsolive.example',
        ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
        JWT_ACCESS_TTL_SECONDS: String(60 * 86_400),
        REFRESH_TTL_SECONDS: String(60 * 86_400),
        REFRESH_ABSOLUTE_TTL_SECONDS: String(60 * 86_400),
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        ADMIN_SESSION_MAX_SECONDS: '604800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '100000/900',
        RATE_LIMIT_RECHARGE_ORDER_USER: '10000/900',
        RATE_LIMIT_RECHARGE_ORDER_ACTION_USER: '10000/900',
        RATE_LIMIT_REFERRAL_APPLY_USER: '6/86400',
        MEDIA_UPLOADS_ENABLED: 'true',
        S3_BUCKET: 'kabso-media-test',
        S3_ACCESS_KEY_ID: 'test',
        S3_SECRET_ACCESS_KEY: 'test',
        MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
        RECHARGE_AGENT_SWEEP_INTERVAL_SECONDS: '0',
      },
      [{ token: OBJECT_STORAGE, value: storage }],
    );
    sweeper = ctx.app.get(ReferralSweeper);
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('the page: a stable code and link, the configured amounts (defaults), nothing hard-coded', async () => {
    const a = await signup();
    const page = await mine(a);
    expect(page.code).toMatch(/^[23456789ABCDEFGHJKMNPQRSTVWXYZ]{8}$/);
    expect(page.link).toBe(`https://kabsolive.example/i/${page.code}`);
    expect((await mine(a)).code).toBe(page.code);
    expect(page).toMatchObject({
      enabled: true,
      rules: {
        inviterSignupCherries: 20_000,
        inviteeSignupCherries: 0,
        firstRechargeBps: 500,
        holdHours: 24,
        applyWindowDays: 7,
        dailySignupCap: 20,
      },
      upTo: { total: 20_000 * 15 + 1_350_000, milestones: 1_350_000 },
      counts: { invited: 0, qualified: 0, pending: 0 },
      rewards: { pendingCherries: 0, creditedCherries: 0 },
      milestones: [
        { friends: 1, cherries: 50_000, state: 'LOCKED' },
        { friends: 5, cherries: 300_000, state: 'LOCKED' },
        { friends: 15, cherries: 1_000_000, state: 'LOCKED' },
      ],
      invitees: [],
      invitedBy: null,
      canApply: true,
    });
    // A change in the settings shows at once (the app reads the values, never its own).
    await settings({ inviterSignupCherries: 30_000n });
    expect((await mine(a)).rules.inviterSignupCherries).toBe(30_000);
    await settings({ inviterSignupCherries: 20_000n });
  });

  it('sign-up with the code: held 24 h, credited once as REFERRAL_REWARD, milestone 1, ticker, nothing twice', async () => {
    const a = await signup();
    const code = (await mine(a)).code;
    // A malformed code is a 400; v1.108-social (D343, §10.142): an unknown one is a 400 `not_found` too (owner: a clear
    // error at sign-up), and a sign-up without a code makes no referral.
    const bad = await signupRaw({ code: '!!' });
    expect(bad.reg.status).toBe(400);
    const unknown = await signupRaw({ code: 'ZZZZZZZZ' });
    expect(unknown.reg.status).toBe(400);
    expect(issueOf(unknown.reg)).toBe('not_found');
    const stranger = await signup();
    expect(await referralOf(stranger)).toBeNull();

    const b = await signup({ code: `${code.slice(0, 4).toLowerCase()}-${code.slice(4)}` });
    const ref = await referralOf(b);
    expect(ref).toMatchObject({
      inviterUserId: a.id,
      status: 'PENDING',
      source: 'SIGNUP',
      rejectReason: null,
    });
    expect(ref!.holdUntil.getTime()).toBe(ref!.createdAt.getTime() + 24 * HOUR);
    expect(ref!.inviteeIp).toBe(b.ip);
    expect(ref!.inviteeEmailHash).toMatch(/^[0-9a-f]{64}$/);
    const pageA = await mine(a);
    expect(pageA.counts).toEqual({ invited: 1, qualified: 0, pending: 1 });
    expect(pageA.rewards).toEqual({ pendingCherries: 20_000, creditedCherries: 0 });
    expect(pageA.milestones[0]!.state).toBe('UNLOCKED');
    expect(pageA.invitees).toEqual([
      { name: 'T***r', status: 'PENDING', joinedAt: ref!.createdAt.toISOString(), firstRecharge: false },
    ]);
    const pageB = await mine(b);
    expect(pageB.invitedBy).toMatchObject({ status: 'PENDING', source: 'SIGNUP' });
    expect(pageB.canApply).toBe(false);
    expect(pageB.applyUntil).toBeNull();
    expect(await ctx.prisma.auditLog.count({ where: { action: 'referral.attach', targetId: ref!.id } })).toBe(
      1,
    );

    // Not before the hold ends.
    await sweep(clock + 23 * HOUR);
    expect(await cherriesOf(a)).toBe(0n);
    expect((await referralOf(b))!.status).toBe('PENDING');
    // After it: qualified, the sign-up reward and the first milestone credited.
    const s = await sweep(clock + 24 * HOUR + 1000);
    expect(s).toMatchObject({ qualified: 1, credited: 1 });
    expect((await referralOf(b))!.status).toBe('QUALIFIED');
    expect(await cherriesOf(a)).toBe(70_000n);
    const rows = await ctx.prisma.cherryLedgerEntry.findMany({
      where: { userId: a.id, reason: 'REFERRAL_REWARD' },
      orderBy: { createdAt: 'asc' },
    });
    const rewards = await rewardsOf(a);
    expect(rows.map((r) => [r.delta, r.referenceId]).sort()).toEqual(
      rewards.map((r) => [r.cherries, r.id]).sort(),
    );
    expect(rewards.map((r) => [r.kind, r.status])).toEqual([
      ['SIGNUP_INVITER', 'CREDITED'],
      ['MILESTONE', 'CREDITED'],
    ]);
    const after = await mine(a);
    expect(after.counts).toEqual({ invited: 1, qualified: 1, pending: 0 });
    expect(after.rewards).toEqual({ pendingCherries: 0, creditedCherries: 70_000 });
    expect(after.milestones.map((m) => m.state)).toEqual(['CLAIMED', 'LOCKED', 'LOCKED']);
    // Nothing twice.
    await sweep(clock + 48 * HOUR);
    expect(await cherriesOf(a)).toBe(70_000n);
    // The ticker: real rewards, masked names, public.
    const ticker = await ctx.http.get('/api/v1/referrals/recent-rewards');
    expect(ticker.status).toBe(200);
    expectContract(ticker, 'listRecentReferralRewards');
    expect(ticker.headers['cache-control']).toBe('public, max-age=60');
    expect(ticker.body.data.length).toBeGreaterThanOrEqual(2);
    expect(ticker.body.data[0]).toMatchObject({ name: 'T***r' });
    expect(JSON.stringify(ticker.body)).not.toContain(a.id);
  });

  it('a held reward is voided when the friend is banned, deleted or locked, or the inviter is banned', async () => {
    const a = await signup();
    const code = (await mine(a)).code;
    const banned = await signup({ code });
    const locked = await signup({ code });
    const deleted = await signup({ code });
    await ctx.prisma.user.update({ where: { id: banned.id }, data: { status: 'SUSPENDED' } });
    await ctx.prisma.user.update({ where: { id: deleted.id }, data: { status: 'PENDING_DELETION' } });
    await ctx.prisma.accountRestriction.create({
      data: {
        id: randomUUID(),
        userId: locked.id,
        kind: 'LOCK',
        reason: 'fraud check',
        startsAt: now(),
        endsAt: new Date(clock + 30 * DAY),
        via: 'cli',
      },
    });
    await sweep(clock + 25 * HOUR);
    for (const [u, reason] of [
      [banned, 'INVITEE_BANNED'],
      [locked, 'INVITEE_FLAGGED'],
      [deleted, 'INVITEE_DELETED'],
    ] as const) {
      expect(await referralOf(u)).toMatchObject({ status: 'VOID', voidReason: reason });
    }
    expect((await rewardsOf(a)).every((r) => r.status === 'VOID')).toBe(true);
    expect(await cherriesOf(a)).toBe(0n);

    const c = await signup();
    const friend = await signup({ code: (await mine(c)).code });
    await ctx.prisma.user.update({ where: { id: c.id }, data: { status: 'SUSPENDED' } });
    await sweep(clock + 25 * HOUR);
    expect(await referralOf(friend)).toMatchObject({ status: 'VOID', voidReason: 'INVITER_BANNED' });
  });

  it('fraud: own code, the same device, the same IP, mailbox aliases, a device or a mailbox already referred', async () => {
    const a = await signup({ email: `ali.salem.${Date.now()}@gmail.com` });
    const code = (await mine(a)).code;
    // The same install id as the inviter's session.
    const sameDevice = await signup({ code, installId: a.installId });
    expect(await referralOf(sameDevice)).toMatchObject({ status: 'REJECTED', rejectReason: 'SELF_DEVICE' });
    // The inviter's IP (seen in the last 24 h).
    const sameIp = await signup({ code, ip: a.ip });
    expect(await referralOf(sameIp)).toMatchObject({ status: 'REJECTED', rejectReason: 'SELF_IP' });
    // The inviter's own mailbox through an alias (dots, +tag, googlemail).
    const local = a.email.split('@')[0]!.replace(/\./g, '');
    const alias = await signup({ code, email: `${local}+promo@googlemail.com` });
    expect(await referralOf(alias)).toMatchObject({ status: 'REJECTED', rejectReason: 'SELF_EMAIL' });
    // One device, two new accounts: the second is a duplicate (one reward per device).
    const device = `install-${randomUUID()}`;
    const first = await signup({ code, installId: device });
    const second = await signup({ code, installId: device });
    expect((await referralOf(first))!.status).toBe('PENDING');
    expect(await referralOf(second)).toMatchObject({ status: 'REJECTED', rejectReason: 'DUPLICATE_DEVICE' });
    // A mailbox already referred (another inviter), through an alias.
    const other = await signup();
    const box = `nour.${Date.now()}`;
    const m1 = await signup({ code: (await mine(other)).code, email: `${box}@gmail.com` });
    const m2 = await signup({ code, email: `${box.replace('.', '')}+2@gmail.com` });
    expect((await referralOf(m1))!.status).toBe('PENDING');
    expect(await referralOf(m2)).toMatchObject({ status: 'REJECTED', rejectReason: 'DUPLICATE_EMAIL' });
    // A rejected referral pays nothing, ever.
    expect((await rewardsOf(a)).filter((r) => r.status !== 'VOID').length).toBe(1);
    const page = await mine(a);
    expect(page.counts).toEqual({ invited: 6, qualified: 0, pending: 1 });
    expect(page.invitees.filter((i) => i.status === 'REJECTED')).toHaveLength(5);
    // Own code later: 422.
    const own = await apply(a, code);
    expect(own.status).toBe(422);
    expect(own.body.error.code).toBe('REFERRAL_CODE_INVALID');
    expectContract(own, 'applyReferralCode');
    // Sweeping qualifies only the clean one.
    await sweep(clock + 25 * HOUR);
    expect((await referralOf(sameDevice))!.status).toBe('REJECTED');
    expect(await cherriesOf(a)).toBe(20_000n + 50_000n);
  });

  it('the daily cap per inviter: rewards past it are void, the friends still count', async () => {
    await settings({ dailySignupCap: 2 });
    try {
      const a = await signup();
      const code = (await mine(a)).code;
      const friends = [await signup({ code }), await signup({ code }), await signup({ code })];
      const rewardOf = async (f: TestUser) => {
        const ref = (await referralOf(f))!;
        return ctx.prisma.referralReward.findFirstOrThrow({ where: { referralId: ref.id } });
      };
      for (const f of friends.slice(0, 2)) expect(await rewardOf(f)).toMatchObject({ status: 'PENDING' });
      expect(await rewardOf(friends[2]!)).toMatchObject({ status: 'VOID', voidReason: 'DAILY_CAP' });
      expect((await referralOf(friends[2]!))!.status).toBe('PENDING');
      // 24 hours later the cap is free again.
      advance(DAY + 1000);
      const later = await signup({ code });
      expect(await rewardOf(later)).toMatchObject({ kind: 'SIGNUP_INVITER', status: 'PENDING' });
    } finally {
      await settings({ dailySignupCap: 20 });
    }
  });

  it('a code entered later: once, within 7 days, the order of refusals, the rate limit', async () => {
    const a = await signup();
    const code = (await mine(a)).code;
    const c = await signup();
    expect((await mine(c)).canApply).toBe(true);
    const badBody = await apply(c, '!!');
    expect(badBody.status).toBe(400);
    const unknown = await apply(c, 'ZZZZZZZZ');
    expect(unknown.status).toBe(422);
    expectContract(unknown, 'applyReferralCode');
    const ok = await apply(c, `https://kabsolive.example/i/${code}`);
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    expectContract(ok, 'applyReferralCode');
    expect(ok.body.invitedBy).toMatchObject({ status: 'PENDING', source: 'LATER' });
    expect(ok.body.canApply).toBe(false);
    const again = await apply(c, code);
    expect(again.status).toBe(409);
    expect(issueOf(again)).toBe('ALREADY_REFERRED');
    expectContract(again, 'applyReferralCode');
    // The rate limit counts refused attempts too (6 / 24 h in this test).
    const limited = [];
    for (let i = 0; i < 3; i++) limited.push((await apply(c, code)).status);
    expect(limited).toEqual([409, 409, 429]);

    const late = await signup();
    advance(7 * DAY + 1000);
    expect((await mine(late)).canApply).toBe(false);
    const closed = await apply(late, code);
    expect(closed.status).toBe(409);
    expect(issueOf(closed)).toBe('WINDOW_CLOSED');
  });

  it('first recharge on each path: a held share once, never for a recharge before the code; a refund voids it', async () => {
    const a = await signup();
    const code = (await mine(a)).code;
    const agent = await activeAgent(200_000_000n);
    const share = (coins: number) => BigInt(Math.floor((coins * 10 * 500) / 10_000));

    // Website top-up (CARD_TOPUP).
    const web = await signup({ code });
    const order = await cardTopup(web, 1_000_000n);
    await cardTopup(web, 2_000_000n);
    // An agent's sale (RECHARGE_PURCHASE).
    const sale = await signup({ code });
    await agentSale(agent, sale, 500_000);
    await agentSale(agent, sale, 700_000);
    // A recharge order (RECHARGE_ORDER).
    const ord = await signup({ code });
    await rechargeOrder(ord, agent, 1_000_000);
    // A recharge before the code was entered: no share.
    const early = await signup();
    await agentSale(agent, early, 300_000);
    expect((await apply(early, code)).status).toBe(200);
    expect((await referralOf(early))!.firstRechargeAt).not.toBeNull();

    const recharge = (await rewardsOf(a)).filter((r) => r.kind === 'FIRST_RECHARGE');
    expect(recharge.map((r) => [r.rechargeReason, r.baseCoins, r.cherries, r.status]).sort()).toEqual(
      [
        ['CARD_TOPUP', 1_000_000n, share(1_000_000), 'PENDING'],
        ['RECHARGE_ORDER', 1_000_000n, share(1_000_000), 'PENDING'],
        ['RECHARGE_PURCHASE', 500_000n, share(500_000), 'PENDING'],
      ].sort(),
    );
    expect((await mine(a)).invitees.filter((i) => i.firstRecharge)).toHaveLength(4);
    expect(await ctx.prisma.auditLog.count({ where: { action: 'referral.reward.create' } })).toBeGreaterThan(
      0,
    );

    // The website top-up is refunded during the hold: its share is voided, the others are credited.
    const fresh = await ctx.prisma.topupOrder.update({
      where: { id: order },
      data: { refundedMinor: 1250 },
    });
    await ctx.prisma.$transaction((tx) => reconcileOrderIn(tx, fresh, 'evt_refund', now()));
    await sweep(clock + 25 * HOUR);
    const after = (await rewardsOf(a)).filter((r) => r.kind === 'FIRST_RECHARGE');
    expect(after.find((r) => r.rechargeReason === 'CARD_TOPUP')).toMatchObject({
      status: 'VOID',
      voidReason: 'RECHARGE_REVERSED',
    });
    expect(after.filter((r) => r.status === 'CREDITED')).toHaveLength(2);
  });

  it('milestones 1 / 5 / 15 (config): each once, from qualified friends only', async () => {
    await settings({
      milestones: [
        { friends: 1, cherries: 10 },
        { friends: 3, cherries: 30 },
      ],
      inviterSignupCherries: 0n,
    });
    try {
      const a = await signup();
      const code = (await mine(a)).code;
      expect((await mine(a)).milestones.map((m) => m.friends)).toEqual([1, 3]);
      for (let i = 0; i < 3; i++) await signup({ code });
      // No sign-up reward (0) — the friends still qualify and count.
      expect(await rewardsOf(a)).toEqual([]);
      await sweep(clock + 25 * HOUR);
      expect(await cherriesOf(a)).toBe(40n);
      expect((await mine(a)).milestones.map((m) => m.state)).toEqual(['CLAIMED', 'CLAIMED']);
      await signup({ code });
      await sweep(clock + 50 * HOUR);
      expect(await cherriesOf(a)).toBe(40n);
    } finally {
      await settings({
        milestones: [
          { friends: 1, cherries: 50000 },
          { friends: 5, cherries: 300000 },
          { friends: 15, cherries: 1000000 },
        ],
        inviterSignupCherries: 20_000n,
      });
    }
  });

  it('«الدعوات»: capabilities, the code again, approve a rejected one, void a pending one, settings, audited', async () => {
    // The admins sign in now (the clock moved days forward in the tests above).
    const owner = await makeAdmin(['OWNER']);
    const support = await makeAdmin(['SUPPORT']);
    const finance = await makeAdmin(['FINANCE']);
    const a = await signup();
    const code = (await mine(a)).code;
    const rejected = await signup({ code, installId: a.installId });
    const pending = await signup({ code });
    const rRej = (await referralOf(rejected))!;
    const rPen = (await referralOf(pending))!;

    // SUPPORT views (audited) but cannot decide or change the settings.
    const list = await aget(support, `/admin/referrals?status=REJECTED&q=${a.username}`);
    expect(list.status, JSON.stringify(list.body)).toBe(200);
    expectContract(list, 'listAdminReferrals');
    expect(list.body.data.map((r: { id: string }) => r.id)).toContain(rRej.id);
    const detail = await aget(support, `/admin/referrals/${rRej.id}`);
    expect(detail.status).toBe(200);
    expectContract(detail, 'getAdminReferral');
    expect(detail.body.signals).toMatchObject({ installId: true, ip: rejected.ip });
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'referral.view', actorUserId: support.id } }),
    ).toBe(1);
    const csv = await aget(support, '/admin/referrals?format=csv');
    expect(csv.status).toBe(200);
    expect(csv.text.split('\n')[0]).toContain('reject_reason');
    const body = () => ({ reason: 'checked by phone', totpCode: nextCode(finance.secret) });
    expect((await awrite(support, 'post', `/admin/referrals/${rRej.id}/approve`, body())).status).toBe(403);
    expect(
      (await awrite(support, 'put', '/admin/referral-settings', { enabled: false, ...body() })).status,
    ).toBe(403);
    const settingsRead = await aget(support, '/admin/referral-settings');
    expect(settingsRead.status).toBe(200);
    expectContract(settingsRead, 'getAdminReferralSettings');

    // FINANCE: a wrong code is refused; the right one approves (credited now, no hold) — once.
    const wrong = await awrite(finance, 'post', `/admin/referrals/${rRej.id}/approve`, {
      reason: 'x',
      totpCode: '000000',
    });
    expect(wrong.status).toBe(403);
    const approve = await awrite(finance, 'post', `/admin/referrals/${rRej.id}/approve`, {
      reason: 'checked by phone',
      totpCode: nextCode(finance.secret),
    });
    expect(approve.status, JSON.stringify(approve.body)).toBe(200);
    expectContract(approve, 'approveAdminReferral');
    expect(approve.body).toEqual({ status: 'QUALIFIED', changed: true, creditedCherries: 20_000 + 50_000 });
    expect(await referralOf(rejected)).toMatchObject({ status: 'QUALIFIED', rejectReason: 'SELF_DEVICE' });
    expect(await cherriesOf(a)).toBe(70_000n);
    const twice = await awrite(finance, 'post', `/admin/referrals/${rRej.id}/approve`, {
      reason: 'again',
      totpCode: nextCode(finance.secret),
    });
    expect(twice.body).toMatchObject({ changed: false, creditedCherries: 0 });
    expect(await cherriesOf(a)).toBe(70_000n);

    // Void a pending one: its held reward goes; the sweep pays nothing for it.
    const voided = await awrite(finance, 'post', `/admin/referrals/${rPen.id}/void`, {
      reason: 'same family farm',
      totpCode: nextCode(finance.secret),
    });
    expect(voided.status, JSON.stringify(voided.body)).toBe(200);
    expectContract(voided, 'voidAdminReferral');
    expect(voided.body).toEqual({
      status: 'VOID',
      changed: true,
      voidedRewards: 1,
      reversedCherries: 0,
      shortfall: 0,
    });
    await sweep(clock + 25 * HOUR);
    expect(await cherriesOf(a)).toBe(70_000n);
    for (const action of ['referral.approve', 'referral.void']) {
      const row = await ctx.prisma.auditLog.findFirstOrThrow({ where: { action, actorUserId: finance.id } });
      expect(row.metadata).toMatchObject({ via: 'panel' });
    }

    // Settings: FINANCE with the code; validated; audited with before / after.
    const invalid = await awrite(finance, 'put', '/admin/referral-settings', {
      milestones: [
        { friends: 5, cherries: 1 },
        { friends: 2, cherries: 1 },
      ],
      ...body(),
    });
    expect(invalid.status).toBe(400);
    const put = await awrite(finance, 'put', '/admin/referral-settings', {
      inviterSignupCherries: 25_000,
      holdHours: 48,
      reason: 'owner approved',
      totpCode: nextCode(finance.secret),
    });
    expect(put.status, JSON.stringify(put.body)).toBe(200);
    expectContract(put, 'updateAdminReferralSettings');
    expect(put.body).toMatchObject({ inviterSignupCherries: 25_000, holdHours: 48, updatedById: finance.id });
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'referral.settings.update' },
    });
    expect(audit.metadata).toMatchObject({
      via: 'panel',
      reason: 'owner approved',
      before: { inviterSignupCherries: 20_000, holdHours: 24 },
      after: { inviterSignupCherries: 25_000, holdHours: 48 },
    });
    const back = await awrite(owner, 'put', '/admin/referral-settings', {
      inviterSignupCherries: 20_000,
      holdHours: 24,
      reason: 'back',
      totpCode: nextCode(owner.secret),
    });
    expect(back.status).toBe(200);
  });

  it('void after credit: the cherries are taken back (once), a shortfall is a debt that blocks withdrawals', async () => {
    const finance = await makeAdmin(['FINANCE']);
    const voidIt = (id: string) =>
      awrite(finance, 'post', `/admin/referrals/${id}/void`, {
        reason: 'fake friends',
        totpCode: nextCode(finance.secret),
      });
    const reversals = (u: TestUser) =>
      ctx.prisma.cherryLedgerEntry.findMany({
        where: { userId: u.id, reason: 'REFERRAL_REVERSAL' },
        orderBy: { createdAt: 'asc' },
      });

    // 1. Enough cherries: sign-up 20 000 + milestone 1 (50 000) + the first recharge's 5 %, all credited.
    const a = await signup();
    const b = await signup({ code: (await mine(a)).code });
    await cardTopup(b, 1_000_000n);
    await sweep(clock + 24 * HOUR + 1000);
    const share = (1_000_000n * BigInt(ctx.config.economy.cherriesPerCoin) * 500n) / 10_000n;
    const total = 70_000n + share;
    expect(await cherriesOf(a)).toBe(total);
    const ref = (await referralOf(b))!;
    expect(ref.status).toBe('QUALIFIED');

    // The panel shows what «إلغاء» takes back before the team confirms.
    const preview = await aget(finance, `/admin/referrals/${ref.id}`);
    expect(preview.status).toBe(200);
    expectContract(preview, 'getAdminReferral');
    expect(preview.body.voidClawback).toEqual({
      cherries: Number(total),
      shortfall: 0,
      rewards: 3,
      people: [{ userId: a.id, cherries: Number(total), balance: Number(total), shortfall: 0 }],
    });

    const v = await voidIt(ref.id);
    expect(v.status, JSON.stringify(v.body)).toBe(200);
    expectContract(v, 'voidAdminReferral');
    expect(v.body).toEqual({
      status: 'VOID',
      changed: true,
      voidedRewards: 0,
      reversedCherries: Number(total),
      shortfall: 0,
    });
    expect(await cherriesOf(a)).toBe(0n);
    const rewards = await rewardsOf(a);
    expect(rewards.map((w) => [w.kind, w.status, w.reversalShortfall]).sort()).toEqual(
      [
        ['FIRST_RECHARGE', 'REVERSED', 0n],
        ['MILESTONE', 'REVERSED', 0n],
        ['SIGNUP_INVITER', 'REVERSED', 0n],
      ].sort(),
    );
    // One REFERRAL_REVERSAL row per reward, reference = the reward.
    expect((await reversals(a)).map((e) => [e.delta, e.referenceId]).sort()).toEqual(
      rewards.map((w) => [-w.cherries, w.id]).sort(),
    );
    expect(
      await ctx.prisma.notification.count({ where: { recipientId: a.id, type: 'REFERRAL_REWARD_REVERSED' } }),
    ).toBe(1);
    const inbox = await ctx.http.get('/api/v1/notifications').set(auth(a));
    expect(inbox.status).toBe(200);
    expectContract(inbox, 'listNotifications');
    expect(inbox.body.data.map((n: { type: string }) => n.type)).toContain('REFERRAL_REWARD_REVERSED');
    expect(
      await ctx.prisma.auditLog.count({
        where: { action: 'referral.reward.reverse', actorUserId: finance.id },
      }),
    ).toBe(3);
    const page = await mine(a);
    expect(page.counts).toMatchObject({ qualified: 0 });
    expect(page.rewards).toEqual({ pendingCherries: 0, creditedCherries: 0 });
    expect(page.milestones[0]!.state).toBe('LOCKED');
    // The cherry history shows the claw-back.
    const history = await ctx.http.get('/api/v1/wallet/me/cherries/ledger').set(auth(a));
    expect(history.status).toBe(200);
    expectContract(history, 'listMyCherryLedger');
    expect(history.body.data.map((e: { reason: string }) => e.reason)).toContain('REFERRAL_REVERSAL');

    // A second void changes nothing (no second debit, no second notification).
    const again = await voidIt(ref.id);
    expect(again.body).toEqual({
      status: 'VOID',
      changed: false,
      voidedRewards: 0,
      reversedCherries: 0,
      shortfall: 0,
    });
    expect(await cherriesOf(a)).toBe(0n);
    expect(await reversals(a)).toHaveLength(3);

    // The team approves it again: new reward rows are credited (the reversed ones stay as history).
    const re = await awrite(finance, 'post', `/admin/referrals/${ref.id}/approve`, {
      reason: 'it was a real friend',
      totpCode: nextCode(finance.secret),
    });
    expect(re.status, JSON.stringify(re.body)).toBe(200);
    expect(re.body).toMatchObject({ changed: true, creditedCherries: Number(total) });
    expect(await cherriesOf(a)).toBe(total);
    expect((await rewardsOf(a)).filter((w) => w.status === 'CREDITED')).toHaveLength(3);

    // 2. Not enough cherries: 60 000 already withdrawn (held) → the balance goes to −60 000 (the shortfall).
    const c = await signup();
    const d = await signup({ code: (await mine(c)).code });
    await sweep(clock + 24 * HOUR + 1000);
    expect(await cherriesOf(c)).toBe(70_000n);
    await ctx.prisma.$transaction((tx) => holdCherriesIn(tx, c.id, 60_000n, randomUUID(), now()));
    const refD = (await referralOf(d))!;
    const shown = await aget(finance, `/admin/referrals/${refD.id}`);
    expect(shown.body.voidClawback).toMatchObject({ cherries: 70_000, shortfall: 60_000 });
    const short = await voidIt(refD.id);
    expect(short.body).toMatchObject({ changed: true, reversedCherries: 70_000, shortfall: 60_000 });
    expect(await cherriesOf(c)).toBe(-60_000n);
    const cRewards = await rewardsOf(c);
    expect(cRewards.reduce((t, w) => t + (w.reversalShortfall ?? 0n), 0n)).toBe(60_000n);
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'referral.void', targetId: refD.id },
    });
    expect(audit.metadata).toMatchObject({ reversedCherries: 70_000, shortfall: 60_000 });
    // Withdrawals are refused while the balance is below 0.
    const wallet = await ctx.http.get('/api/v1/wallet/me/cherries').set(auth(c));
    expect(wallet.status).toBe(200);
    expect(wallet.body.cherries).toBe(-60_000);
    const withdraw = await ctx.http
      .post('/api/v1/wallet/me/cherries/withdrawals')
      .set(auth(c))
      .set('Idempotency-Key', randomUUID())
      .send({ amountMinor: 1000, payoutDetails: 'Bank: IBAN SA00 0000' });
    expect([withdraw.status, withdraw.body.error?.code]).toEqual([409, 'INSUFFICIENT_CHERRIES']);
    expect(
      await ctx.prisma.$transaction((tx) => holdCherriesIn(tx, c.id, 1n, randomUUID(), now())),
    ).toBeNull();
  });

  it('switched off: the page says so, no referral at sign-up, apply 503, no recharge share, empty ticker', async () => {
    const a = await signup();
    const code = (await mine(a)).code;
    await settings({ enabled: false });
    try {
      expect((await mine(a)).enabled).toBe(false);
      const b = await signup({ code });
      expect(await referralOf(b)).toBeNull();
      const off = await apply(b, code);
      expect(off.status).toBe(503);
      expect(off.body.error.code).toBe('REFERRAL_UNAVAILABLE');
      expectContract(off, 'applyReferralCode');
      const ticker = await ctx.http.get('/api/v1/referrals/recent-rewards');
      expect(ticker.body).toEqual({ data: [] });
      // A friend referred before the switch: the first recharge is marked, no share is made.
      await settings({ enabled: true });
      const c = await signup({ code });
      await settings({ enabled: false });
      await cardTopup(c, 1_000_000n);
      expect((await referralOf(c))!.firstRechargeAt).not.toBeNull();
      expect((await rewardsOf(a)).filter((r) => r.kind === 'FIRST_RECHARGE')).toEqual([]);
    } finally {
      await settings({ enabled: true });
    }
  });

  it('referral-admin (CLI): settings, list, void, sweep — audited via cli', async () => {
    const a = await signup();
    const b = await signup({ code: (await mine(a)).code });
    const r = (await referralOf(b))!;
    const env = { ...process.env, DOTENV_CONFIG_QUIET: 'true' };
    const cli = (...args: string[]) =>
      run('node', ['--import', 'tsx', 'src/cli/referral-admin.ts', ...args], { env });
    const shown = await cli('settings');
    expect(JSON.parse(shown.stdout)).toMatchObject({ enabled: true, inviterSignupCherries: 20_000 });
    const set = await cli(
      'settings',
      '--set',
      'dailySignupCap=5',
      '--set',
      'milestones=1:50000,5:300000,15:1000000',
      '--reason',
      'cli test',
    );
    expect(JSON.parse(set.stdout)).toMatchObject({ dailySignupCap: 5 });
    await expect(cli('settings', '--set', 'firstRechargeBps=9999', '--reason', 'x')).rejects.toThrow();
    const listed = await cli('list', '--status', 'pending');
    expect(listed.stdout).toContain(r.id);
    const v = await cli('void', r.id, '--reason', 'cli check');
    expect(v.stdout).toContain('Voided');
    expect(await referralOf(b)).toMatchObject({ status: 'VOID', voidReason: 'cli check' });
    const row = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'referral.void', targetId: r.id },
    });
    expect(row.metadata).toMatchObject({ via: 'cli' });
    await settings({ dailySignupCap: 20 });
  });
});
