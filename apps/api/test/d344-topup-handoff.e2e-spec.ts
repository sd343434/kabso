/**
 * D344 (owner 2026-11-09: «اريد جعل الشحن من الموقع يفتح من نفس التطبيق ويدخل اليوزر والباسورد تلقائي»; contract
 * v1.109-social, CONVENTIONS §10.143): the app mints a one-time code, the website top-up page exchanges it once for
 * its own web session. End to end against PostgreSQL + Redis; Stripe is a stub (no call is made here).
 */
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import Stripe from 'stripe';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { STRIPE_API_FACTORY, type StripeApi } from '../src/modules/topup/stripe-api.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

/** Built at run time so no key-shaped literal is committed (gitleaks). */
const SECRET_KEY = ['sk', 'test', randomBytes(16).toString('hex')].join('_');
const WEBHOOK_SECRET = ['whsec', randomBytes(16).toString('hex')].join('_');
const PUBLIC = 'https://kabso.example';
const STRIPE_ENV = {
  STRIPE_SECRET_KEY: SECRET_KEY,
  STRIPE_WEBHOOK_SECRET: WEBHOOK_SECRET,
  TOPUP_PUBLIC_BASE_URL: PUBLIC,
};
const noStripe = (() => {
  throw new Error('no Stripe call is expected');
}) as unknown as StripeApi;
const STUB = [{ token: STRIPE_API_FACTORY, value: () => noStripe }];

interface AppUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
  readonly sessionId: string;
  readonly refreshToken: string;
}

const sha256 = (v: string) => createHash('sha256').update(v, 'utf8').digest('hex');
const bearer = (token: string) => ({ Authorization: `Bearer ${token}` });
const codeOf = (url: string) => /#h=([A-Za-z0-9_-]{43})$/.exec(url)?.[1] ?? '';

type InstallSource = 'PLAY' | 'APP_STORE' | 'SIDELOAD';

/** int21 (§10.143.3): signs up from `platform`, reporting `installSource` (the direct APK unless said; null: none). */
async function signup(
  ctx: TestContext,
  platform: 'android' | 'ios' = 'android',
  installSource: InstallSource | null = 'SIDELOAD',
): Promise<AppUser> {
  const { res } = await registerVerified(ctx, {
    device: {
      name: 'Phone',
      platform,
      appVersion: '1.0.0',
      deviceKey: randomBytes(32).toString('hex'),
      ...(installSource ? { installSource } : {}),
    },
  });
  expect(res.status, JSON.stringify(res.body)).toBe(201);
  const token = res.body.tokens.accessToken as string;
  const refreshToken = res.body.tokens.refreshToken as string;
  const sessionId = refreshToken.split('.')[0]!;
  return {
    id: res.body.user.id as string,
    username: res.body.user.username as string,
    token,
    sessionId,
    refreshToken,
  };
}

describe('D344 contract coverage', () => {
  it('openapi v1.109-social declares the handoff operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain('createTopupWebsiteSession POST /api/v1/wallet/topup-session');
    expect(ids).toContain('exchangeTopupHandoff POST /api/v1/topup/handoff');
  });
});

describe('D344 switched off (no Stripe keys)', { timeout: 120_000 }, () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp();
  });
  afterAll(async () => ctx?.close());

  it('mint and exchange answer 503 TOPUP_UNAVAILABLE', async () => {
    const u = await signup(ctx);
    const mint = await ctx.http.post('/api/v1/wallet/topup-session').set(bearer(u.token));
    expect(mint.status).toBe(503);
    expectContract(mint, 'createTopupWebsiteSession');
    expect(mint.body.error.code).toBe('TOPUP_UNAVAILABLE');
    const ex = await ctx.http.post('/api/v1/topup/handoff').send({ handoff: 'a'.repeat(43) });
    expect(ex.status).toBe(503);
    expectContract(ex, 'exchangeTopupHandoff');
  });
});

describe('D344 one-time website sign-in', { timeout: 300_000 }, () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp(STRIPE_ENV, STUB);
  });
  afterAll(async () => ctx?.close());

  const mint = async (u: AppUser, lang?: string) => {
    let req = ctx.http.post('/api/v1/wallet/topup-session').set(bearer(u.token));
    if (lang) req = req.set('Accept-Language', lang);
    const res = await req;
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'createTopupWebsiteSession');
    return res;
  };
  const exchange = (handoff: unknown, headers: Record<string, string> = {}) =>
    ctx.http
      .post('/api/v1/topup/handoff')
      .set({ 'User-Agent': 'KabsoE2E/1.0 (custom tab)', ...headers })
      .send({ handoff });
  const refusedReasons = async (userId: string) =>
    (
      await ctx.prisma.auditLog.findMany({
        where: { actorUserId: userId, action: 'topup.handoff.refused' },
        orderBy: { createdAt: 'asc' },
      })
    ).map((r) => (r.metadata as { reason: string }).reason);

  it('mints a 60-second code in the URL fragment, stores only its hash, and exchanges it once', async () => {
    const u = await signup(ctx);
    const before = Date.now();
    const res = await mint(u);
    expect(res.body.websiteUrl).toMatch(/^https:\/\/kabso\.example\/topup\?lang=ar#h=[A-Za-z0-9_-]{43}$/);
    const code = codeOf(res.body.websiteUrl as string);
    const ttl = Date.parse(res.body.expiresAt as string) - before;
    expect(ttl).toBeGreaterThan(55_000);
    expect(ttl).toBeLessThanOrEqual(61_000);
    const rows = await ctx.prisma.topupHandoff.findMany({ where: { userId: u.id } });
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ sessionId: u.sessionId, codeHash: sha256(code), consumedAt: null });
    expect(JSON.stringify(rows)).not.toContain(code);

    const ex = await exchange(code);
    expect(ex.status, JSON.stringify(ex.body)).toBe(200);
    expectContract(ex, 'exchangeTopupHandoff');
    expect(ex.body.username).toBe(u.username);
    expect(ex.body).not.toHaveProperty('refreshToken');
    // A normal web session of the same account, carrying the app's device (a device ban ends it too).
    const me = await ctx.http.get('/api/v1/topup/me').set(bearer(ex.body.accessToken as string));
    expect(me.status).toBe(200);
    const profile = await ctx.http.get('/api/v1/me').set(bearer(ex.body.accessToken as string));
    expect(profile.body.id).toBe(u.id);
    const row = await ctx.prisma.topupHandoff.findUniqueOrThrow({ where: { id: rows[0]!.id } });
    expect(row.consumedAt).not.toBeNull();
    const web = await ctx.prisma.session.findUniqueOrThrow({ where: { id: row.webSessionId! } });
    const app = await ctx.prisma.session.findUniqueOrThrow({ where: { id: u.sessionId } });
    expect(web).toMatchObject({ userId: u.id, platform: 'web', deviceHash: app.deviceHash });
    expect(web.deviceHash).not.toBeNull();
    expect(web.revokedAt).toBeNull();

    // Single use.
    const again = await exchange(code);
    expect(again.status).toBe(410);
    expectContract(again, 'exchangeTopupHandoff');
    expect(again.body.error.code).toBe('TOKEN_EXPIRED');
    expect(await refusedReasons(u.id)).toEqual(['used']);

    // Audited, and the code is in no audit row.
    const audits = await ctx.prisma.auditLog.findMany({ where: { actorUserId: u.id } });
    const actions = audits.map((a) => a.action);
    expect(actions).toContain('topup.handoff.mint');
    expect(actions).toContain('topup.handoff.exchange');
    expect(JSON.stringify(audits)).not.toContain(code);
  });

  it('English app → the English page; a new code voids the session’s previous one', async () => {
    const u = await signup(ctx);
    const first = codeOf((await mint(u, 'en')).body.websiteUrl as string);
    const second = await mint(u, 'en');
    expect(second.body.websiteUrl).toMatch(/\/topup\?lang=en#h=/);
    expect((await exchange(first)).status).toBe(410);
    expect((await exchange(codeOf(second.body.websiteUrl as string))).status).toBe(200);
  });

  it('two exchanges at once: exactly one session', async () => {
    const u = await signup(ctx);
    const code = codeOf((await mint(u)).body.websiteUrl as string);
    const results = await Promise.all([exchange(code), exchange(code), exchange(code)]);
    expect(results.map((r) => r.status).sort()).toEqual([200, 410, 410]);
    expect(await ctx.prisma.session.count({ where: { userId: u.id, platform: 'web' } })).toBe(1);
  });

  it('an expired code is refused (the page shows its normal sign-in)', async () => {
    const u = await signup(ctx);
    const code = codeOf((await mint(u)).body.websiteUrl as string);
    const past = new Date(Date.now() - 120_000);
    await ctx.prisma.topupHandoff.updateMany({
      where: { codeHash: sha256(code) },
      data: { createdAt: past, expiresAt: new Date(past.getTime() + 60_000) },
    });
    const res = await exchange(code);
    expect(res.status).toBe(410);
    expect(res.body.error.code).toBe('TOKEN_EXPIRED');
    expect(await refusedReasons(u.id)).toEqual(['expired']);
  });

  it('the code signs in ITS account only; another user’s token sent along changes nothing', async () => {
    const a = await signup(ctx);
    const b = await signup(ctx);
    const code = codeOf((await mint(a)).body.websiteUrl as string);
    const res = await exchange(code, bearer(b.token));
    expect(res.status).toBe(200);
    expect(res.body.username).toBe(a.username);
    const profile = await ctx.http.get('/api/v1/me').set(bearer(res.body.accessToken as string));
    expect(profile.body.id).toBe(a.id);
    // Unknown and malformed codes.
    const unknown = await exchange(randomBytes(32).toString('base64url'));
    expect(unknown.status).toBe(410);
    for (const bad of ['short', 'x'.repeat(44), 12, null]) {
      const r = await exchange(bad);
      expect(r.status, String(bad)).toBe(400);
      expectContract(r, 'exchangeTopupHandoff');
    }
    const extra = await ctx.http.post('/api/v1/topup/handoff').send({ handoff: code, userId: b.id });
    expect(extra.status).toBe(400);
  });

  it('signing out the app session, a suspension or a deletion request voids pending codes', async () => {
    const u = await signup(ctx);
    const code = codeOf((await mint(u)).body.websiteUrl as string);
    const out = await ctx.http.post('/api/v1/auth/logout').set(bearer(u.token));
    expect(out.status).toBe(204);
    expect((await exchange(code)).status).toBe(410);
    expect(await refusedReasons(u.id)).toEqual(['session_revoked']);

    for (const status of ['SUSPENDED', 'PENDING_DELETION'] as const) {
      const v = await signup(ctx);
      const c = codeOf((await mint(v)).body.websiteUrl as string);
      await ctx.prisma.user.update({ where: { id: v.id }, data: { status } });
      expect((await exchange(c)).status, status).toBe(410);
      expect(await refusedReasons(v.id)).toEqual(['account_not_active']);
    }

    // Deleting the session (or the account) deletes its codes.
    const w = await signup(ctx);
    await mint(w);
    await ctx.prisma.session.delete({ where: { id: w.sessionId } });
    expect(await ctx.prisma.topupHandoff.count({ where: { userId: w.id } })).toBe(0);
  });

  it('the website page takes the code out of the address before using it', async () => {
    const page = await ctx.http.get('/topup');
    expect(page.status).toBe(200);
    expect(page.headers['content-security-policy']).toContain("script-src 'self'");
    expect(page.headers['set-cookie']).toBeUndefined();
    const js = await ctx.http.get('/topup/assets/topup.js');
    expect(js.text).toContain('history.replaceState');
    expect(js.text).toContain("'/topup/handoff'");
    // Taken before any request runs.
    expect(js.text.indexOf('var handoff = takeHandoff();')).toBeLessThan(
      js.text.indexOf("api('GET', '/topup/packages')"),
    );
  });
});

describe('D344 per-store link switch and rate limits', { timeout: 300_000 }, () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp(
      {
        ...STRIPE_ENV,
        TOPUP_APP_LINK_PLATFORMS: 'android',
        RATE_LIMIT_TOPUP_HANDOFF_USER: '2/600',
        RATE_LIMIT_TOPUP_HANDOFF_IP: '3/600',
      },
      STUB,
    );
  });
  afterAll(async () => ctx?.close());

  it('an iPhone session gets no link and no code; an Android one does', async () => {
    const ios = await signup(ctx, 'ios');
    const offer = await ctx.http.get('/api/v1/wallet/recharge-packages').set(bearer(ios.token));
    expect(offer.status).toBe(200);
    expectContract(offer, 'listRechargePackages');
    expect(offer.body.websiteTopupUrl).toBeNull();
    const refused = await ctx.http.post('/api/v1/wallet/topup-session').set(bearer(ios.token));
    expect(refused.status).toBe(503);
    expect(refused.body.error.code).toBe('TOPUP_UNAVAILABLE');

    const android = await signup(ctx, 'android');
    const ok = await ctx.http.get('/api/v1/wallet/recharge-packages').set(bearer(android.token));
    expect(ok.body.websiteTopupUrl).toBe(`${PUBLIC}/topup`);
  });

  it('minting is limited per user and exchanging per IP', async () => {
    const u = await signup(ctx, 'android');
    const statuses: number[] = [];
    for (let i = 0; i < 3; i += 1) {
      statuses.push((await ctx.http.post('/api/v1/wallet/topup-session').set(bearer(u.token))).status);
    }
    expect(statuses).toEqual([201, 201, 429]);
    const ex: number[] = [];
    for (let i = 0; i < 4; i += 1) {
      const r = await ctx.http
        .post('/api/v1/topup/handoff')
        .send({ handoff: randomBytes(32).toString('base64url') });
      ex.push(r.status);
      if (r.status === 429) expectContract(r, 'exchangeTopupHandoff');
    }
    expect(ex).toEqual([410, 410, 410, 429]);
  });
});

/** A Stripe that records Checkout sessions and answers a fee for each payment (D344's fee check). */
class FeeStripe {
  readonly sessions: Stripe.Checkout.SessionCreateParams[] = [];
  fee: { feeMinor: number; currency: string } | null = null;
  feeCalls: string[] = [];
  async createCheckoutSession(params: Stripe.Checkout.SessionCreateParams) {
    this.sessions.push(params);
    const id = `cs_e2e_${randomBytes(6).toString('hex')}`;
    return { id, url: `https://checkout.stripe.com/c/pay/${id}`, expires_at: params.expires_at ?? 0 };
  }
  async createRefund(): Promise<{ id: string; status: string }> {
    throw new Error('no refund here');
  }
  async updateDispute(): Promise<{ id: string; status: string }> {
    throw new Error('no dispute here');
  }
  async uploadEvidenceFile(): Promise<{ id: string }> {
    throw new Error('no evidence here');
  }
  async createCustomer() {
    return { id: `cus_e2e_${randomBytes(4).toString('hex')}` };
  }
  async checkKey() {
    return { ok: true as const, livemode: false, restricted: false };
  }
  async paymentFee(pi: string) {
    this.feeCalls.push(pi);
    return this.fee;
  }
}

describe('int21 the website link only for the direct APK (install source)', { timeout: 300_000 }, () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp(STRIPE_ENV, STUB);
  });
  afterAll(async () => ctx?.close());

  const offer = async (u: AppUser) => {
    const res = await ctx.http.get('/api/v1/wallet/recharge-packages').set(bearer(u.token));
    expect(res.status).toBe(200);
    expectContract(res, 'listRechargePackages');
    return res.body.websiteTopupUrl as string | null;
  };
  const mintStatus = async (u: AppUser) =>
    (await ctx.http.post('/api/v1/wallet/topup-session').set(bearer(u.token))).status;
  const refresh = (u: AppUser, body: Record<string, unknown> = {}) =>
    ctx.http.post('/api/v1/auth/refresh').send({ refreshToken: u.refreshToken, ...body });
  const sourceOf = async (sessionId: string) =>
    (await ctx.prisma.session.findUniqueOrThrow({ where: { id: sessionId } })).installSource;

  it('a direct APK (SIDELOAD) gets the link and a code; a Play, App Store or unreported install does not', async () => {
    const apk = await signup(ctx, 'android', 'SIDELOAD');
    expect(await sourceOf(apk.sessionId)).toBe('SIDELOAD');
    expect(await offer(apk)).toBe(`${PUBLIC}/topup`);
    expect(await mintStatus(apk)).toBe(201);

    for (const [platform, source] of [
      ['android', 'PLAY'],
      ['ios', 'APP_STORE'],
      ['android', null],
    ] as const) {
      const u = await signup(ctx, platform, source);
      expect(await sourceOf(u.sessionId)).toBe(source);
      expect(await offer(u), `${platform} ${source}`).toBeNull();
      const refused = await ctx.http.post('/api/v1/wallet/topup-session').set(bearer(u.token));
      expect(refused.status).toBe(503);
      expectContract(refused, 'createTopupWebsiteSession');
      expect(refused.body.error.code).toBe('TOPUP_UNAVAILABLE');
    }
  });

  it('a sign-in reports it too; a refresh reports it for a session signed in earlier and keeps it when omitted', async () => {
    // Signed in by an app that reported nothing (an older app): no link until it reports.
    const old = await signup(ctx, 'android', null);
    expect(await offer(old)).toBeNull();
    const r1 = await refresh(old, { installSource: 'SIDELOAD' });
    expect(r1.status, JSON.stringify(r1.body)).toBe(200);
    expectContract(r1, 'refresh');
    const updated: AppUser = {
      ...old,
      token: r1.body.accessToken as string,
      refreshToken: r1.body.refreshToken as string,
    };
    expect(await sourceOf(old.sessionId)).toBe('SIDELOAD');
    expect(await offer(updated)).toBe(`${PUBLIC}/topup`);
    // Omitted: the stored source is kept.
    const r2 = await refresh(updated);
    expect(r2.status).toBe(200);
    expect(await sourceOf(old.sessionId)).toBe('SIDELOAD');
    // The same phone now runs the Play build (reinstalled from the store): the link goes.
    const r3 = await refresh(
      { ...updated, refreshToken: r2.body.refreshToken as string },
      { installSource: 'PLAY' },
    );
    expect(r3.status).toBe(200);
    expect(await sourceOf(old.sessionId)).toBe('PLAY');
    expect(await offer({ ...updated, token: r3.body.accessToken as string })).toBeNull();
    // An unknown value is a 400 (the token is not spent).
    const bad = await refresh(
      { ...updated, refreshToken: r3.body.refreshToken as string },
      { installSource: 'TESTFLIGHT' },
    );
    expect(bad.status).toBe(400);
    expect(bad.body.error.code).toBe('VALIDATION_FAILED');

    // Login carries it in DeviceInfo.
    const { res, payload } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    const login = await ctx.http.post('/api/v1/auth/login').send({
      identifier: payload.email,
      password: payload.password,
      device: { platform: 'android', installSource: 'SIDELOAD' },
    });
    expect(login.status, JSON.stringify(login.body)).toBe(200);
    expectContract(login, 'login');
    const sid = (login.body.tokens.refreshToken as string).split('.')[0]!;
    expect(await sourceOf(sid)).toBe('SIDELOAD');
    const badLogin = await ctx.http.post('/api/v1/auth/login').send({
      identifier: payload.email,
      password: payload.password,
      device: { platform: 'android', installSource: 'sideload' },
    });
    expect(badLogin.status).toBe(400);
  });
});

describe('int21 TOPUP_APP_LINK_SOURCES set to the stores too', { timeout: 300_000 }, () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp({ ...STRIPE_ENV, TOPUP_APP_LINK_SOURCES: 'PLAY,APP_STORE,SIDELOAD' }, STUB);
  });
  afterAll(async () => ctx?.close());

  it('then a store install sees the link; a session that reported nothing still does not', async () => {
    for (const [platform, source, shown] of [
      ['android', 'PLAY', true],
      ['ios', 'APP_STORE', true],
      ['android', 'SIDELOAD', true],
      ['android', null, false],
    ] as const) {
      const u = await signup(ctx, platform, source);
      const res = await ctx.http.get('/api/v1/wallet/recharge-packages').set(bearer(u.token));
      expect(res.body.websiteTopupUrl, `${platform} ${source}`).toBe(shown ? `${PUBLIC}/topup` : null);
    }
  });
});

describe('D344 Stripe fee in the website price', { timeout: 300_000 }, () => {
  const stripe = new FeeStripe();
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp({ ...STRIPE_ENV, STRIPE_BANK_TRANSFER_ENABLED: 'false' }, [
      { token: STRIPE_API_FACTORY, value: () => stripe },
    ]);
  });
  afterAll(async () => ctx?.close());

  const deliver = (event: object) => {
    const payload = JSON.stringify(event);
    const header = Stripe.webhooks.generateTestHeaderString({ payload, secret: WEBHOOK_SECRET });
    return ctx.http
      .post('/api/v1/payments/stripe/webhook')
      .set('Stripe-Signature', header)
      .set('Content-Type', 'application/json')
      .send(payload);
  };
  const buyAndPay = async (u: AppUser) => {
    const go = await ctx.http
      .post('/api/v1/topup/checkout')
      .set(bearer(u.token))
      .send({ packageId: '1000000', termsAccepted: true, termsVersion: '2026-10-31' });
    expect(go.status, JSON.stringify(go.body)).toBe(201);
    const order = await ctx.prisma.topupOrder.findUniqueOrThrow({ where: { id: go.body.orderId as string } });
    const pi = `pi_${randomUUID()}`;
    const paid = await deliver({
      id: `evt_${randomUUID()}`,
      object: 'event',
      type: 'checkout.session.completed',
      api_version: '2026-09-30.endive',
      created: Math.floor(Date.now() / 1000),
      livemode: false,
      data: {
        object: {
          id: order.stripeSessionId,
          object: 'checkout.session',
          client_reference_id: order.id,
          metadata: { kabso_order_id: order.id },
          amount_total: order.amountMinor,
          currency: 'usd',
          payment_status: 'paid',
          payment_intent: pi,
        },
      },
    });
    expect(paid.status, JSON.stringify(paid.body)).toBe(200);
    return { order, pi };
  };

  it('one all-inclusive price per package: base + Stripe fee, rounded up (placeholder 2.9 % + 30 ¢)', async () => {
    const res = await ctx.http.get('/api/v1/topup/packages');
    expect(res.status).toBe(200);
    expectContract(res, 'listTopupPackages');
    // ceil((base + 30) / 0.971) for 125, 625, 1250, 6250, 12500, 62500 cents.
    expect(res.body.packages).toEqual([
      { id: '100000', coins: 100_000, priceMinor: 160 },
      { id: '500000', coins: 500_000, priceMinor: 675 },
      { id: '1000000', coins: 1_000_000, priceMinor: 1319 },
      { id: '5000000', coins: 5_000_000, priceMinor: 6468 },
      { id: '10000000', coins: 10_000_000, priceMinor: 12_905 },
      { id: '50000000', coins: 50_000_000, priceMinor: 64_398 },
    ]);
    // No separate fee field anywhere on the page's data (surcharging is not allowed in the EU / UK).
    expect(JSON.stringify(res.body)).not.toMatch(/fee/i);
  });

  it('Checkout charges the grossed-up price, the order keeps the parts, the coins stay the package', async () => {
    const u = await signup(ctx);
    stripe.fee = { feeMinor: 68, currency: 'USD' }; // 2.9 % of 1319 = 38.25 → 38, + 30
    const { order, pi } = await buyAndPay(u);
    expect(stripe.sessions.at(-1)!.line_items).toEqual([
      expect.objectContaining({
        price_data: expect.objectContaining({ unit_amount: 1319, currency: 'usd' }),
      }),
    ]);
    expect(stripe.sessions.at(-1)!.line_items?.length).toBe(1); // no fee line
    expect(order).toMatchObject({
      amountMinor: 1319,
      basePriceMinor: 1250,
      feePercentBps: 290,
      feeFixedMinor: 30,
    });
    const created = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'topup.checkout.create', targetId: order.id },
    });
    expect(created.metadata).toMatchObject({
      amountMinor: 1319,
      basePriceMinor: 1250,
      feePercentBps: 290,
      feeFixedMinor: 30,
    });
    expect((await ctx.prisma.wallet.findUniqueOrThrow({ where: { userId: u.id } })).coins).toBe(1_000_000n);
    expect(stripe.feeCalls).toContain(pi);
    const after = await ctx.prisma.topupOrder.findUniqueOrThrow({ where: { id: order.id } });
    expect(after.stripeFeeMinor).toBe(68);
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'topup.fee.exceeded', targetId: order.id } }),
    ).toBe(0);
  });

  it('Stripe took more than the fee in the price: flagged, the coins unchanged', async () => {
    const u = await signup(ctx);
    stripe.fee = { feeMinor: 90, currency: 'USD' }; // e.g. an international card
    const { order } = await buyAndPay(u);
    expect((await ctx.prisma.topupOrder.findUniqueOrThrow({ where: { id: order.id } })).stripeFeeMinor).toBe(
      90,
    );
    const flagged = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'topup.fee.exceeded', targetId: order.id },
    });
    expect(flagged.metadata).toMatchObject({ stripeFeeMinor: 90, marginMinor: 69, estimatedFeeMinor: 68 });
    expect((await ctx.prisma.wallet.findUniqueOrThrow({ where: { userId: u.id } })).coins).toBe(1_000_000n);
  });

  it('no balance transaction yet (or a Stripe error): the credit is not affected', async () => {
    const u = await signup(ctx);
    stripe.fee = null;
    const { order } = await buyAndPay(u);
    expect(
      (await ctx.prisma.topupOrder.findUniqueOrThrow({ where: { id: order.id } })).stripeFeeMinor,
    ).toBeNull();
    expect((await ctx.prisma.wallet.findUniqueOrThrow({ where: { userId: u.id } })).coins).toBe(1_000_000n);
  });
});
