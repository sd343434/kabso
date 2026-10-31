/**
 * D190 (owner 2026-10-31; contract v1.59-social, CONVENTIONS §10.53, CP-033): card top-ups on the Kabso website
 * through Stripe Checkout. End to end against PostgreSQL + Redis with a fake Stripe client (no network): the
 * webhooks are signed with the library's own test header (HMAC over the exact body).
 */
import { randomBytes, randomUUID } from 'node:crypto';
import Stripe from 'stripe';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { STRIPE_API, type StripeApi } from '../src/modules/topup/stripe-api.js';
import { requestTeamRefund } from '../src/modules/topup/topup-core.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

/** Built at run time so no key-shaped literal is committed (gitleaks). */
const SECRET_KEY = ['sk', 'test', randomBytes(16).toString('hex')].join('_');
const WEBHOOK_SECRET = ['whsec', randomBytes(16).toString('hex')].join('_');
const PUBLIC = 'https://kabso.example';
const WEBHOOK = '/api/v1/payments/stripe/webhook';

/** The Stripe port, recorded; `failRefunds` makes the next refunds fail (a Stripe outage). */
class FakeStripe implements StripeApi {
  readonly sessions: { params: Stripe.Checkout.SessionCreateParams; key: string }[] = [];
  readonly refunds: { params: Stripe.RefundCreateParams; key: string }[] = [];
  readonly disputes: { id: string; params: Stripe.DisputeUpdateParams }[] = [];
  readonly files: { name: string; data: Buffer }[] = [];
  failRefunds = 0;
  /** Runs inside `createCheckoutSession` (to look at the database at that moment). */
  onSession: ((params: Stripe.Checkout.SessionCreateParams) => Promise<void>) | null = null;
  private n = 0;

  async createCheckoutSession(params: Stripe.Checkout.SessionCreateParams, key: string) {
    this.sessions.push({ params, key });
    if (this.onSession) await this.onSession(params);
    this.n += 1;
    return {
      id: `cs_e2e_${this.n}_${randomBytes(4).toString('hex')}`,
      url: `https://checkout.stripe.com/c/pay/cs_e2e_${this.n}`,
      expires_at: params.expires_at ?? Math.floor(Date.now() / 1000) + 1800,
    };
  }
  async createRefund(params: Stripe.RefundCreateParams, key: string) {
    if (this.failRefunds > 0) {
      this.failRefunds -= 1;
      throw new Error('Stripe is down');
    }
    this.refunds.push({ params, key });
    return { id: `re_e2e_${this.refunds.length}`, status: 'succeeded' };
  }
  async updateDispute(id: string, params: Stripe.DisputeUpdateParams) {
    this.disputes.push({ id, params });
    return { id, status: 'under_review' };
  }
  async uploadEvidenceFile(name: string, data: Buffer) {
    this.files.push({ name, data });
    return { id: `file_e2e_${this.files.length}` };
  }
  readonly customers: string[] = [];
  async createCustomer() {
    const id = `cus_e2e_${randomBytes(4).toString('hex')}`;
    this.customers.push(id);
    return { id };
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly token: string;
}

const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });

describe('D190 contract coverage', () => {
  it('openapi v1.59-social declares the top-up operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'listTopupPackages GET /api/v1/topup/packages',
      'getMyTopupState GET /api/v1/topup/me',
      'createTopupCheckout POST /api/v1/topup/checkout',
      'getTopupOrder GET /api/v1/topup/orders/{orderId}',
      'receiveStripeWebhook POST /api/v1/payments/stripe/webhook',
    ]) {
      expect(ids).toContain(op);
    }
  });
});

describe('D190 card top-ups switched off', { timeout: 120_000 }, () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp();
  });
  afterAll(async () => ctx?.close());

  it('without the Stripe keys every operation is 503 TOPUP_UNAVAILABLE and the app link is null', async () => {
    expect(ctx.config.topup.stripe).toBeNull();
    const { res } = await registerVerified(ctx);
    const token = res.body.tokens.accessToken as string;
    const h = { Authorization: `Bearer ${token}` };
    // Built one at a time (a supertest request built before another one ran has a closed server).
    const calls = [
      () => ctx.http.get('/api/v1/topup/packages'),
      () => ctx.http.get('/api/v1/topup/me').set(h),
      () =>
        ctx.http.post('/api/v1/topup/checkout').set(h).send({ packageId: '1000000', termsAccepted: true }),
      () => ctx.http.get(`/api/v1/topup/orders/${randomUUID()}`).set(h),
      () =>
        ctx.http
          .post(WEBHOOK)
          .set('Stripe-Signature', 't=1,v1=x')
          .set('Content-Type', 'application/json')
          .send('{}'),
    ];
    for (const call of calls) {
      const r = await call();
      expect(r.status, JSON.stringify(r.body)).toBe(503);
      expect(r.body.error.code).toBe('TOPUP_UNAVAILABLE');
      expect(r.headers['retry-after']).toBeUndefined();
    }
    const packages = await ctx.http.get('/api/v1/wallet/recharge-packages').set(h);
    expect(packages.status).toBe(200);
    expect(packages.body.websiteTopupUrl).toBeNull();
    // The page itself still renders (it then shows «الشحن بالبطاقة غير مفعّل»).
    const page = await ctx.http.get('/topup');
    expect(page.status).toBe(200);
    expect(page.text).toContain('الشحن بالبطاقة غير مفعّل');
  });
});

describe('D190 card top-ups', { timeout: 300_000 }, () => {
  const stripe = new FakeStripe();
  let ctx: TestContext;
  let host: TestUser;

  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: payload.email,
      token: res.body.tokens.accessToken as string,
    };
  };
  const terms = { termsAccepted: true, termsVersion: '2026-10-31' };
  const checkout = (u: TestUser, body: Record<string, unknown>) =>
    ctx.http
      .post('/api/v1/topup/checkout')
      .set(auth(u))
      .set('User-Agent', 'KabsoE2E/1.0 (website)')
      .send(body);
  /** A checkout of `packageId`; returns the order id and the Stripe session id the fake gave. */
  const buy = async (u: TestUser, packageId = '1000000') => {
    const res = await checkout(u, { packageId, ...terms });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'createTopupCheckout');
    const order = await ctx.prisma.topupOrder.findUniqueOrThrow({
      where: { id: res.body.orderId as string },
    });
    return {
      orderId: order.id,
      sessionId: order.stripeSessionId!,
      amount: order.amountMinor,
      pi: `pi_${randomUUID()}`,
    };
  };
  const evt = (type: string, object: Record<string, unknown>, id = `evt_${randomUUID()}`) => ({
    id,
    object: 'event',
    type,
    api_version: '2026-09-30.endive',
    created: Math.floor(Date.now() / 1000),
    livemode: false,
    data: { object },
  });
  const deliver = (event: object, secret = WEBHOOK_SECRET) => {
    const payload = JSON.stringify(event);
    const header = Stripe.webhooks.generateTestHeaderString({ payload, secret });
    return ctx.http
      .post(WEBHOOK)
      .set('Stripe-Signature', header)
      .set('Content-Type', 'application/json')
      .send(payload);
  };
  const ok = async (event: object) => {
    const res = await deliver(event);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'receiveStripeWebhook');
    return res;
  };
  const session = (
    o: { orderId: string; sessionId: string; amount: number; pi: string },
    paid: boolean,
    extra: Record<string, unknown> = {},
  ) => ({
    id: o.sessionId,
    object: 'checkout.session',
    client_reference_id: o.orderId,
    metadata: { kabso_order_id: o.orderId },
    amount_total: o.amount,
    currency: 'usd',
    payment_status: paid ? 'paid' : 'unpaid',
    payment_intent: o.pi,
    ...extra,
  });
  /** Bought and paid (credited). */
  const paidOrder = async (u: TestUser, packageId = '1000000') => {
    const o = await buy(u, packageId);
    await ok(evt('checkout.session.completed', session(o, true)));
    return o;
  };
  const coins = async (u: TestUser) =>
    (await ctx.prisma.wallet.findUnique({ where: { userId: u.id } }))?.coins ?? 0n;
  const cherries = async (u: TestUser) =>
    (await ctx.prisma.cherryWallet.findUnique({ where: { userId: u.id } }))?.cherries ?? 0n;
  const followed = new Set<string>();
  const dmGift = async (from: TestUser, to: TestUser, source: 'COINS' | 'BAG' = 'COINS') => {
    if (!followed.has(`${to.id}>${from.id}`)) {
      const f = await ctx.http.put(`/api/v1/users/${from.username}/follow`).set(auth(to));
      expect(f.status).toBe(200);
      followed.add(`${to.id}>${from.id}`);
    }
    const clientId = randomUUID();
    const res = await ctx.http
      .post('/api/v1/dm/gifts')
      .set(auth(from))
      .send({ to: to.username, giftCode: 'topup_big', quantity: 1, source, clientId });
    const row = await ctx.prisma.liveGift.findFirst({
      where: { senderId: from.id, clientId },
      select: { id: true },
    });
    return { res, id: row?.id ?? null };
  };
  const me = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/topup/me').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getMyTopupState');
    return res.body as { coins: number; frozen: boolean };
  };
  const charge = (
    o: { pi: string; amount: number; orderId: string },
    refunded: number,
    id = `ch_${o.orderId}`,
  ) => ({
    id,
    object: 'charge',
    payment_intent: o.pi,
    amount: o.amount,
    amount_refunded: refunded,
    metadata: { kabso_order_id: o.orderId },
  });

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        STRIPE_SECRET_KEY: SECRET_KEY,
        STRIPE_WEBHOOK_SECRET: WEBHOOK_SECRET,
        TOPUP_PUBLIC_BASE_URL: PUBLIC,
        RATE_LIMIT_TOPUP_CHECKOUT_USER: '10000/900',
      },
      [{ token: STRIPE_API, value: stripe }],
    );
    await ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, 'topup_big', {
        category: 'POPULAR',
        nameAr: 'هدية',
        nameEn: 'Gift',
        priceCoins: 1000,
        assetKey: 'gift_topup_big',
        animationKey: null,
        sortOrder: 0,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      }),
    );
    host = await signup();
  });
  afterAll(async () => ctx?.close());

  it('lists the server packages: 1 000 000 coins = $12.50, USD, the terms statement', async () => {
    const res = await ctx.http.get('/api/v1/topup/packages');
    expect(res.status).toBe(200);
    expectContract(res, 'listTopupPackages');
    expect(res.body.currency).toBe('USD');
    expect(res.body.packages).toEqual([
      { id: '100000', coins: 100_000, priceMinor: 125 },
      { id: '500000', coins: 500_000, priceMinor: 625 },
      { id: '1000000', coins: 1_000_000, priceMinor: 1250 },
      { id: '5000000', coins: 5_000_000, priceMinor: 6250 },
      { id: '10000000', coins: 10_000_000, priceMinor: 12_500 },
      { id: '50000000', coins: 50_000_000, priceMinor: 62_500 },
    ]);
    expect(res.body.terms).toEqual({
      version: '2026-10-31',
      ar: 'العملات رقمية وغير قابلة للاسترداد',
      en: 'Coins are digital and non-refundable',
    });
    expect(res.body.bankTransfer).toBe(true); // owner CP-033 Q3: on by default
    // Owner CP-033 Q4: the app link is on by default (a server switch): the website's page.
    const u = await signup();
    const offer = await ctx.http.get('/api/v1/wallet/recharge-packages').set(auth(u));
    expect(offer.body.websiteTopupUrl).toBe(`${PUBLIC}/topup`);
  });

  it('checkout: terms required, server price only (a sent price or unknown package is refused)', async () => {
    const u = await signup();
    const before = stripe.sessions.length;
    const refused = [
      { packageId: '1000000' },
      { packageId: '1000000', termsAccepted: false, termsVersion: '2026-10-31' },
      { packageId: '1000000', termsAccepted: true },
      { packageId: '1000000', termsAccepted: true, termsVersion: '2020-01-01' },
      { packageId: '1000000', ...terms, priceMinor: 1 },
      { packageId: '1000000', ...terms, amount: 1, currency: 'usd' },
      { packageId: '999', ...terms },
      { packageId: '1', ...terms },
    ];
    for (const body of refused) {
      const res = await checkout(u, body);
      expect(res.status, JSON.stringify(body)).toBe(400);
      expectContract(res, 'createTopupCheckout');
      expect(res.body.error.code).toBe('VALIDATION_FAILED');
    }
    expect(stripe.sessions.length).toBe(before);
    expect(await ctx.prisma.topupOrder.count({ where: { userId: u.id } })).toBe(0);
    expect(await ctx.prisma.topupTermsAcceptance.count({ where: { userId: u.id } })).toBe(0);
    expect(
      (await ctx.http.post('/api/v1/topup/checkout').send({ packageId: '1000000', ...terms })).status,
    ).toBe(401);
  });

  it('checkout records the terms acceptance (time, IP, UA) BEFORE the session; 3-D Secure, receipt, server price', async () => {
    const u = await signup();
    let seenAtSession = 0;
    stripe.onSession = async () => {
      seenAtSession = await ctx.prisma.topupTermsAcceptance.count({ where: { userId: u.id } });
    };
    try {
      const res = await checkout(u, { packageId: '5000000', ...terms, locale: 'ar' });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      expect(res.body.checkoutUrl).toMatch(/^https:\/\/checkout\.stripe\.com\//);
      expect(seenAtSession).toBe(1);
      const order = await ctx.prisma.topupOrder.findUniqueOrThrow({
        where: { id: res.body.orderId as string },
      });
      expect(order).toMatchObject({
        coins: 5_000_000n,
        amountMinor: 6250,
        currency: 'USD',
        status: 'PENDING',
      });
      expect(order.creditedAt).toBeNull();
      const acceptance = await ctx.prisma.topupTermsAcceptance.findUniqueOrThrow({
        where: { id: order.termsAcceptanceId },
      });
      expect(acceptance).toMatchObject({
        termsText: 'العملات رقمية وغير قابلة للاسترداد',
        termsVersion: '2026-10-31',
        locale: 'ar',
        userAgent: 'KabsoE2E/1.0 (website)',
      });
      expect(acceptance.ip).toBeTruthy();
      const { params, key } = stripe.sessions.at(-1)!;
      expect(key).toBe(`kabso-checkout-${order.id}`);
      expect(params.mode).toBe('payment');
      expect(params.line_items).toEqual([
        expect.objectContaining({
          quantity: 1,
          price_data: expect.objectContaining({ currency: 'usd', unit_amount: 6250 }),
        }),
      ]);
      expect(params.payment_method_options?.card?.request_three_d_secure).toBe('any');
      // Owner CP-033 Q3: US bank transfers next to the card, through the buyer's Stripe customer.
      expect(params.allowed_payment_method_types).toEqual(['card', 'customer_balance']);
      expect(params.payment_method_options?.customer_balance).toEqual({
        funding_type: 'bank_transfer',
        bank_transfer: { type: 'us_bank_transfer' },
      });
      const customer = await ctx.prisma.stripeCustomer.findUniqueOrThrow({ where: { userId: u.id } });
      expect(params.customer).toBe(customer.customerId);
      expect(params.customer_email).toBeUndefined();
      expect(params.payment_intent_data?.receipt_email).toBe(u.email);
      expect(params.payment_intent_data?.metadata).toEqual({ kabso_order_id: order.id, kabso_user_id: u.id });
      expect(params.client_reference_id).toBe(order.id);
      expect(params.success_url).toBe(`${PUBLIC}/topup/success?order=${order.id}&lang=ar`);
      expect(params.cancel_url).toBe(`${PUBLIC}/topup/cancel?order=${order.id}&lang=ar`);
      // Nothing credited by the checkout or the redirect.
      expect(await coins(u)).toBe(0n);
      const status = await ctx.http.get(`/api/v1/topup/orders/${order.id}`).set(auth(u));
      expect(status.status).toBe(200);
      expectContract(status, 'getTopupOrder');
      expect(status.body).toMatchObject({
        status: 'PENDING',
        credited: false,
        coins: 5_000_000,
        amountMinor: 6250,
      });
      // Another user's order is not found.
      const other = await signup();
      expect((await ctx.http.get(`/api/v1/topup/orders/${order.id}`).set(auth(other))).status).toBe(404);
      expect((await ctx.http.get('/api/v1/topup/orders/not-a-uuid').set(auth(other))).status).toBe(404);
    } finally {
      stripe.onSession = null;
    }
  });

  it('a bad or missing signature is 400 and changes nothing', async () => {
    const u = await signup();
    const o = await buy(u);
    const event = evt('checkout.session.completed', session(o, true));
    const wrong = await deliver(event, ['whsec', randomBytes(16).toString('hex')].join('_'));
    expect(wrong.status).toBe(400);
    expectContract(wrong, 'receiveStripeWebhook');
    const none = await ctx.http
      .post(WEBHOOK)
      .set('Content-Type', 'application/json')
      .send(JSON.stringify(event));
    expect(none.status).toBe(400);
    // A body changed after signing.
    const payload = JSON.stringify(event);
    const header = Stripe.webhooks.generateTestHeaderString({ payload, secret: WEBHOOK_SECRET });
    const tampered = await ctx.http
      .post(WEBHOOK)
      .set('Stripe-Signature', header)
      .set('Content-Type', 'application/json')
      .send(payload.replace('"paid"', '"paid" '));
    expect(tampered.status).toBe(400);
    expect(await coins(u)).toBe(0n);
    expect(await ctx.prisma.stripeEvent.count({ where: { id: event.id } })).toBe(0);
  });

  it('only a paid session credits, exactly once (replay, concurrency), and counts for the daily badge', async () => {
    const u = await signup();
    const o = await buy(u);
    // A session completed but not paid (a bank transfer waiting): no coins.
    await ok(evt('checkout.session.completed', session(o, false)));
    expect(await coins(u)).toBe(0n);
    expect((await ctx.prisma.topupOrder.findUniqueOrThrow({ where: { id: o.orderId } })).status).toBe(
      'AWAITING_FUNDS',
    );
    // A paid session with another amount than the order's: refused (logged), no coins.
    await ok(evt('checkout.session.completed', session(o, true, { amount_total: 1 })));
    expect(await coins(u)).toBe(0n);

    const paid = evt('checkout.session.completed', session(o, true));
    const async = evt('checkout.session.async_payment_succeeded', session(o, true));
    const results = await Promise.all([
      deliver(paid),
      deliver(paid),
      deliver(async),
      deliver(paid),
      deliver(async),
    ]);
    for (const r of results) expect(r.status, JSON.stringify(r.body)).toBe(200);
    await ok(paid); // a later replay
    expect(await coins(u)).toBe(1_000_000n);
    expect(await ctx.prisma.walletLedgerEntry.count({ where: { userId: u.id, reason: 'CARD_TOPUP' } })).toBe(
      1,
    );
    const order = await ctx.prisma.topupOrder.findUniqueOrThrow({ where: { id: o.orderId } });
    expect(order).toMatchObject({ status: 'PAID', stripePaymentIntentId: o.pi });
    expect(order.creditedAt).not.toBeNull();
    // D187 hook (WEBSITE_TOPUP): the day's recharge total and the tier-1 badge.
    const day = await ctx.prisma.rechargeDailyTotal.findMany({ where: { userId: u.id } });
    expect(day.map((d) => d.coins)).toEqual([1_000_000n]);
    expect(await ctx.prisma.rechargeBadge.findUnique({ where: { userId: u.id } })).toMatchObject({ tier: 1 });
    const status = await ctx.http.get(`/api/v1/topup/orders/${o.orderId}`).set(auth(u));
    expect(status.body).toMatchObject({ status: 'PAID', credited: true, coinsReversed: 0 });
    expect(await ctx.prisma.auditLog.count({ where: { action: 'topup.credit', targetId: o.orderId } })).toBe(
      1,
    );
  });

  it('refund: coins taken back (balance below 0), buyer frozen from buying and gifting, case lists FIFO gifts; host cherries kept', async () => {
    const u = await signup();
    // 500 coins held before the purchase are spent first (FIFO).
    await ctx.prisma.$transaction((tx) => creditIn(tx, u.id, 500n, 'ADMIN_GRANT', randomUUID()));
    const o = await paidOrder(u);
    const g1 = await dmGift(u, host);
    const g2 = await dmGift(u, host);
    expect(g1.res.status, JSON.stringify(g1.res.body)).toBe(201);
    expect(g2.res.status).toBe(201);
    expect(await coins(u)).toBe(1_000_500n - 2000n);
    const hostCherries = await cherries(host);
    expect(hostCherries).toBeGreaterThan(0n);

    const refund = evt('charge.refunded', charge(o, o.amount));
    await ok(refund);
    await ok(refund); // replay
    expect(await coins(u)).toBe(-1500n);
    expect(
      await ctx.prisma.walletLedgerEntry.count({ where: { userId: u.id, reason: 'CARD_TOPUP_REVERSAL' } }),
    ).toBe(1);
    expect(await me(u)).toEqual({ coins: -1500, frozen: true });
    expect(await cherries(host)).toBe(hostCherries); // never clawed back automatically
    const kase = await ctx.prisma.topupCase.findFirstOrThrow({ where: { orderId: o.orderId } });
    expect(kase).toMatchObject({ kind: 'REFUND', status: 'OPEN', coinsReversed: 1_000_000n });
    const attribution = kase.attribution as {
      openingBalance: number;
      unspentCoins: number;
      gifts: { giftId: string; coinsFromPurchase: number; place: string; recipients: { userId: string }[] }[];
    };
    expect(attribution.openingBalance).toBe(500);
    expect(attribution.unspentCoins).toBe(1_000_000 - 1500);
    expect(attribution.gifts.map((g) => [g.giftId, g.coinsFromPurchase, g.place])).toEqual([
      [g1.id, 500, 'DM'],
      [g2.id, 1000, 'DM'],
    ]);
    expect(attribution.gifts[0]!.recipients.map((r) => r.userId)).toEqual([host.id]);

    // Frozen: no card purchase, no gift (coins or bag) while the balance is below 0.
    const again = await checkout(u, { packageId: '1000000', ...terms });
    expect(again.status).toBe(403);
    expect(again.body.error.code).toBe('TOPUP_ACCOUNT_FROZEN');
    for (const source of ['COINS', 'BAG'] as const) {
      const gift = await dmGift(u, host, source);
      expect(gift.res.status, JSON.stringify(gift.res.body)).toBe(403);
      expect(gift.res.body.error.code).toBe('TOPUP_ACCOUNT_FROZEN');
    }
    // Owner CP-033 Q1: once the balance is back to ≥ 0 the buyer gifts again; card buying stays frozen.
    await ctx.prisma.$transaction((tx) => creditIn(tx, u.id, 2500n, 'ADMIN_GRANT', randomUUID()));
    expect(await coins(u)).toBe(1000n);
    const back = await dmGift(u, host);
    expect(back.res.status, JSON.stringify(back.res.body)).toBe(201);
    expect(await me(u)).toEqual({ coins: 0, frozen: true });
    expect((await checkout(u, { packageId: '1000000', ...terms })).body.error.code).toBe(
      'TOPUP_ACCOUNT_FROZEN',
    );
    const status = await ctx.http.get(`/api/v1/topup/orders/${o.orderId}`).set(auth(u));
    expect(status.body.coinsReversed).toBe(1_000_000);
    expect(await ctx.prisma.auditLog.count({ where: { action: 'topup.reverse', targetId: o.orderId } })).toBe(
      1,
    );
  });

  it('bank transfer: completed unpaid waits, async success credits once; one Stripe customer per buyer', async () => {
    const u = await signup();
    const o = await buy(u);
    await buy(u, '100000'); // a second checkout reuses the customer
    expect(await ctx.prisma.stripeCustomer.count({ where: { userId: u.id } })).toBe(1);
    const sessions = stripe.sessions.slice(-2).map((x) => x.params.customer);
    expect(sessions[0]).toBe(sessions[1]);
    await ok(evt('checkout.session.completed', session(o, false)));
    expect(await coins(u)).toBe(0n);
    const waiting = await ctx.http.get(`/api/v1/topup/orders/${o.orderId}`).set(auth(u));
    expect(waiting.body.status).toBe('AWAITING_FUNDS');
    const funded = evt('checkout.session.async_payment_succeeded', session(o, true));
    await ok(funded);
    await ok(funded);
    expect(await coins(u)).toBe(1_000_000n);
    expect(await ctx.prisma.topupOrder.findUniqueOrThrow({ where: { id: o.orderId } })).toMatchObject({
      status: 'PAID',
      paymentMethodType: 'customer_balance',
    });
    // A transfer that never arrives: failed, nothing credited.
    const late = await buy(u, '500000');
    await ok(evt('checkout.session.completed', session(late, false)));
    await ok(evt('checkout.session.async_payment_failed', session(late, false)));
    expect(await ctx.prisma.topupOrder.findUniqueOrThrow({ where: { id: late.orderId } })).toMatchObject({
      status: 'FAILED',
      creditedAt: null,
    });
    expect(await coins(u)).toBe(1_000_000n);
  });

  it('a team refund (payments-admin) reverses the coins WITHOUT a freeze, marked and audited with its reason', async () => {
    const u = await signup();
    const o = await paidOrder(u);
    const g = await dmGift(u, host);
    expect(g.res.status).toBe(201);
    // Stripe refuses: nothing recorded.
    stripe.failRefunds = 1;
    await expect(
      requestTeamRefund(ctx.prisma, stripe, o.orderId, 'goodwill: duplicate purchase', new Date()),
    ).rejects.toThrow();
    expect(
      (await ctx.prisma.topupOrder.findUniqueOrThrow({ where: { id: o.orderId } })).teamRefundedMinor,
    ).toBe(0);
    const done = await requestTeamRefund(
      ctx.prisma,
      stripe,
      o.orderId,
      'goodwill: duplicate purchase',
      new Date(),
    );
    expect(done.amountMinor).toBe(o.amount);
    const asked = stripe.refunds.at(-1)!;
    expect(asked.params).toMatchObject({
      payment_intent: o.pi,
      amount: o.amount,
      metadata: { kabso_order_id: o.orderId, kabso_initiated: 'true', kabso_reason: 'team_refund' },
    });
    // The webhook Stripe sends for it (the refund listed with our marker).
    await ok(
      evt('charge.refunded', {
        ...charge(o, o.amount),
        refunds: {
          object: 'list',
          data: [{ id: done.refundId, object: 'refund', amount: o.amount, metadata: asked.params.metadata }],
        },
      }),
    );
    expect(await coins(u)).toBe(-1000n);
    expect(await me(u)).toEqual({ coins: -1000, frozen: false });
    expect(await ctx.prisma.topupFreeze.findUnique({ where: { userId: u.id } })).toBeNull();
    // Card buying stays open; gifts wait for the debt (balance below 0) like any spending.
    expect((await checkout(u, { packageId: '100000', ...terms })).status).toBe(201);
    expect((await dmGift(u, host)).res.status).toBe(403);
    const audit = await ctx.prisma.auditLog.findMany({
      where: { targetId: o.orderId, action: { in: ['topup.admin_refund', 'topup.reverse'] } },
      orderBy: { createdAt: 'asc' },
    });
    expect(audit.map((a) => a.action)).toEqual(['topup.admin_refund', 'topup.reverse']);
    expect(audit[0]!.metadata).toMatchObject({
      reason: 'goodwill: duplicate purchase',
      initiatedBy: 'kabso',
    });
    expect(audit[1]!.metadata).toMatchObject({
      initiatedBy: 'kabso',
      reason: 'goodwill: duplicate purchase',
    });
    // Nothing left to refund.
    await expect(requestTeamRefund(ctx.prisma, stripe, o.orderId, 'again', new Date())).rejects.toThrow(
      /in full/,
    );
  });

  it('a team refund recognised from the order even when Stripe does not list the refunds; a foreign one freezes', async () => {
    const u = await signup();
    const o = await paidOrder(u, '100000');
    await requestTeamRefund(ctx.prisma, stripe, o.orderId, 'goodwill', new Date());
    await ok(evt('charge.refunded', charge(o, o.amount)));
    expect(await me(u)).toEqual({ coins: 0, frozen: false });
    // A refund made in the Stripe dashboard (no Kabso marker) on another purchase freezes.
    const p = await paidOrder(u, '100000');
    await ok(
      evt('charge.refunded', {
        ...charge(p, p.amount),
        refunds: {
          object: 'list',
          data: [{ id: 're_dash', object: 'refund', amount: p.amount, metadata: {} }],
        },
      }),
    );
    expect(await me(u)).toEqual({ coins: 0, frozen: true });
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { targetId: p.orderId, action: 'topup.reverse' },
    });
    expect(audit.metadata).toMatchObject({ initiatedBy: 'stripe', reason: 'stripe_refund' });
  });

  it('a partial refund takes back its share, rounded up', async () => {
    const u = await signup();
    const o = await paidOrder(u, '100000'); // $1.25
    await ok(evt('charge.refunded', charge(o, 50)));
    // 100 000 × 50 / 125 = 40 000.
    expect(await coins(u)).toBe(60_000n);
    await ok(evt('charge.refunded', charge(o, 125)));
    expect(await coins(u)).toBe(0n);
    expect(
      await ctx.prisma.walletLedgerEntry.count({ where: { userId: u.id, reason: 'CARD_TOPUP_REVERSAL' } }),
    ).toBe(2);
  });

  it('early-fraud warning: reversal at once, then an automatic refund (retried after a Stripe failure, once)', async () => {
    const u = await signup();
    const o = await paidOrder(u);
    const warning = evt('radar.early_fraud_warning.created', {
      id: `issfr_${randomUUID()}`,
      object: 'radar.early_fraud_warning',
      charge: `ch_${o.orderId}`,
      payment_intent: o.pi,
      fraud_type: 'unauthorized_use_of_card',
    });
    stripe.failRefunds = 1;
    const failed = await deliver(warning);
    expect(failed.status).toBe(503); // Stripe retries the event
    expect(await coins(u)).toBe(0n); // the database step committed
    await ok(warning);
    await ok(warning);
    const mine = stripe.refunds.filter((r) => r.params.payment_intent === o.pi);
    expect(mine).toHaveLength(1);
    expect(mine[0]).toMatchObject({
      key: `kabso-efw-refund-${o.orderId}`,
      params: { reason: 'fraudulent', metadata: { kabso_order_id: o.orderId, kabso_initiated: 'true' } },
    });
    // Stripe then confirms our refund: nothing more is taken, no second case.
    await ok(evt('charge.refunded', charge(o, o.amount)));
    expect(await coins(u)).toBe(0n);
    const cases = await ctx.prisma.topupCase.findMany({ where: { orderId: o.orderId } });
    expect(cases.map((c) => c.kind)).toEqual(['EARLY_FRAUD_WARNING']);
    expect(await me(u)).toEqual({ coins: 0, frozen: true });
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'topup.auto_refund', targetId: o.orderId } }),
    ).toBe(1);
  });

  it('dispute: coins reversed, evidence submitted (the buyer only), case with FIFO gifts; won restores and unfreezes', async () => {
    const u = await signup();
    const o = await paidOrder(u);
    const g = await dmGift(u, host);
    expect(g.res.status).toBe(201);
    // A sign-in from another device, for the access log.
    const login = await ctx.http
      .post('/api/v1/auth/login')
      .set('User-Agent', 'KabsoE2E-Phone/2.0')
      .send({
        identifier: u.email,
        password: 'correct horse battery staple',
        device: { platform: 'web', name: 'Kabso website' },
      });
    expect(login.status, JSON.stringify(login.body)).toBe(200);
    const disputeId = `dp_${randomUUID()}`;
    const dispute = (status: string) => ({
      id: disputeId,
      object: 'dispute',
      charge: `ch_${o.orderId}`,
      payment_intent: o.pi,
      amount: o.amount,
      currency: 'usd',
      reason: 'fraudulent',
      status,
    });
    const created = evt('charge.dispute.created', dispute('needs_response'));
    await ok(created);
    await ok(created);
    expect(await coins(u)).toBe(-1000n);
    expect(await me(u)).toEqual({ coins: -1000, frozen: true });
    const sent = stripe.disputes.filter((d) => d.id === disputeId);
    expect(sent).toHaveLength(1);
    const evidence = sent[0]!.params.evidence as Record<string, string>;
    expect(Object.keys(evidence).sort()).toEqual(
      [
        'access_activity_log',
        'customer_email_address',
        'customer_name',
        'customer_purchase_ip',
        'product_description',
        'receipt',
        'refund_policy',
        'refund_policy_disclosure',
        'service_date',
        'uncategorized_text',
      ].sort(),
    );
    expect(sent[0]!.params.submit).toBe(true);
    expect(evidence.customer_email_address).toBe(u.email);
    expect(evidence.receipt).toMatch(/^file_e2e_/);
    expect(evidence.refund_policy_disclosure).toContain('العملات رقمية وغير قابلة للاسترداد');
    expect(evidence.access_activity_log).toContain(`@${u.username}`);
    expect(evidence.access_activity_log).toContain('sign-in');
    expect(evidence.access_activity_log).toContain('Kabso website');
    expect(evidence.access_activity_log).toContain('sent the gift "topup_big" in a direct conversation');
    // Never another user's data: not the recipient's id, username or email.
    const all = JSON.stringify(sent[0]!.params);
    for (const leak of [host.id, host.username, host.email]) expect(all).not.toContain(leak);
    const pdf = stripe.files.at(-1)!;
    expect(pdf.name).toBe(`kabso-receipt-${o.orderId}.pdf`);
    expect(pdf.data.subarray(0, 8).toString('latin1')).toBe('%PDF-1.4');
    expect(pdf.data.toString('latin1')).not.toContain(host.username);
    const kase = await ctx.prisma.topupCase.findFirstOrThrow({
      where: { orderId: o.orderId, kind: 'DISPUTE' },
    });
    expect((kase.attribution as { gifts: { giftId: string }[] }).gifts.map((x) => x.giftId)).toEqual([g.id]);
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'topup.dispute.evidence', targetId: o.orderId } }),
    ).toBe(1);

    // Won: the coins come back, the freeze is lifted, the case closes.
    await ok(evt('charge.dispute.closed', dispute('won')));
    expect(await coins(u)).toBe(999_000n);
    expect(await me(u)).toEqual({ coins: 999_000, frozen: false });
    expect(
      await ctx.prisma.walletLedgerEntry.count({ where: { userId: u.id, reason: 'CARD_TOPUP_RESTORE' } }),
    ).toBe(1);
    expect(await ctx.prisma.topupCase.findUniqueOrThrow({ where: { id: kase.id } })).toMatchObject({
      status: 'CLOSED',
      outcome: 'won',
    });
    expect((await dmGift(u, host)).res.status).toBe(201);
  });

  it('a lost dispute keeps the coins reversed and the freeze', async () => {
    const u = await signup();
    const o = await paidOrder(u, '100000');
    const disputeId = `dp_${randomUUID()}`;
    const d = (status: string) => ({
      id: disputeId,
      object: 'dispute',
      charge: `ch_${o.orderId}`,
      payment_intent: o.pi,
      amount: o.amount,
      currency: 'usd',
      status,
    });
    await ok(evt('charge.dispute.created', d('needs_response')));
    await ok(evt('charge.dispute.closed', d('lost')));
    expect(await coins(u)).toBe(0n);
    expect((await me(u)).frozen).toBe(true);
    expect(await ctx.prisma.topupCase.findFirstOrThrow({ where: { orderId: o.orderId } })).toMatchObject({
      status: 'OPEN',
      outcome: 'lost',
    });
  });

  it('an event of an unknown payment is acknowledged and audited; other types are ignored', async () => {
    const event = evt('charge.refunded', {
      id: 'ch_unknown',
      object: 'charge',
      payment_intent: 'pi_unknown',
      amount: 100,
      amount_refunded: 100,
      metadata: {},
    });
    await ok(event);
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'topup.event.unmatched', targetId: event.id } }),
    ).toBe(1);
    await ok(evt('customer.created', { id: 'cus_x', object: 'customer' }));
  });

  it('serves the website pages: Arabic RTL by default, English, strict CSP, no inline script', async () => {
    const ar = await ctx.http.get('/topup');
    expect(ar.status).toBe(200);
    expect(ar.headers['content-type']).toMatch(/^text\/html/);
    expect(ar.headers['content-security-policy']).toContain("script-src 'self'");
    expect(ar.text).toContain('<html lang="ar" dir="rtl">');
    expect(ar.text).toContain('العملات رقمية وغير قابلة للاسترداد');
    expect(ar.text).not.toMatch(/<script>(?!<\/script>)/);
    const en = await ctx.http.get('/topup?lang=en');
    expect(en.text).toContain('<html lang="en" dir="ltr">');
    const ok2 = await ctx.http.get(`/topup/success?order=${randomUUID()}&lang=ar`);
    expect(ok2.status).toBe(200);
    const xss = await ctx.http.get('/topup/success?order=%3Cscript%3Ealert(1)%3C%2Fscript%3E');
    expect(xss.text).not.toContain('alert(1)');
    expect((await ctx.http.get('/topup/cancel')).status).toBe(200);
    expect((await ctx.http.get('/topup/assets/topup.js')).headers['content-type']).toMatch(/javascript/);
    expect((await ctx.http.get('/topup/assets/topup.css')).headers['content-type']).toMatch(/css/);
  });
});
