/**
 * D196 (owner 2026-10-31; contract v1.64-social, CONVENTIONS §10.53.1): the OWNER enters the Stripe keys in the admin
 * panel «الدفع (Stripe)» instead of the server environment. OWNER only; the code again and a reason for every change;
 * the secrets write-only (fingerprints in every response and audit row, sealed at rest); a new key tried on Stripe
 * before it is saved (the Stripe port is a fake here: no network); panel over env, a clear falls back; the client
 * follows the key without a restart; the webhook's previous secret for 10 minutes; the website's `topupEnabled`
 * refused without keys; and D190's flows with the keys from the database. End to end against PostgreSQL + Redis.
 */
import { randomBytes, randomUUID } from 'node:crypto';
import type request from 'supertest';
import Stripe from 'stripe';
import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { STRIPE_API_FACTORY, type StripeApi, type StripeKeyCheck } from '../src/modules/topup/stripe-api.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

const COOKIE = '__Host-kabso_admin';
const WEBHOOK = '/api/v1/payments/stripe/webhook';
const PUBLIC = 'https://api.kabso.example';
const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';
/** Made-up keys in Stripe's shapes, built at run time (never real; nothing for a secret scanner to match). */
const key = (prefix: string, tail = '') =>
  [...prefix.split('_'), randomBytes(12).toString('hex') + tail].join('_');

/** Records which key each client was made with; a key containing `Bad` is refused by «Stripe». */
class FakeStripeAccount {
  readonly made: string[] = [];
  readonly sessions: { key: string; params: Stripe.Checkout.SessionCreateParams }[] = [];
  readonly disputes: { key: string; submit: boolean | undefined }[] = [];
  readonly checks: string[] = [];
  unreachable = false;

  factory = (secretKey: string): StripeApi => {
    this.made.push(secretKey);
    return {
      createCheckoutSession: async (params) => {
        this.sessions.push({ key: secretKey, params });
        const id = `cs_e2e_${randomBytes(6).toString('hex')}`;
        return { id, url: `https://checkout.stripe.com/c/pay/${id}`, expires_at: params.expires_at ?? 0 };
      },
      createRefund: async () => ({ id: `re_e2e_${randomBytes(4).toString('hex')}`, status: 'succeeded' }),
      updateDispute: async (id, params) => {
        this.disputes.push({ key: secretKey, submit: params.submit });
        return { id, status: 'under_review' };
      },
      uploadEvidenceFile: async () => ({ id: `file_e2e_${randomBytes(4).toString('hex')}` }),
      createCustomer: async () => ({ id: `cus_e2e_${randomBytes(4).toString('hex')}` }),
      checkKey: async (): Promise<StripeKeyCheck> => {
        this.checks.push(secretKey);
        if (this.unreachable) {
          const { StripeUnreachableError } = await import('../src/modules/topup/stripe-api.js');
          throw new StripeUnreachableError('StripeConnectionError');
        }
        return secretKey.includes('Bad')
          ? { ok: false, reason: 'rejected' }
          : { ok: true, livemode: false, restricted: false };
      },
    };
  };
}

interface Person {
  readonly id: string;
  readonly email: string;
  readonly password: string;
  readonly token: string;
}
interface Admin extends Person {
  secret: string;
  cookie: string;
  csrf: string;
}

describe('D196 contract coverage', () => {
  it('openapi v1.64-social declares the «الدفع (Stripe)» operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'getAdminPaymentSettings GET /api/v1/admin/payment-settings',
      'updateAdminPaymentSettings PATCH /api/v1/admin/payment-settings',
      'testAdminPaymentKey POST /api/v1/admin/payment-settings/test',
      'clearAdminPaymentKeys POST /api/v1/admin/payment-settings/clear-keys',
    ]) {
      expect(ids).toContain(op);
    }
  });
});

/** The panel helpers of d191, for one app. */
function panel(getCtx: () => TestContext) {
  let clock = Date.now();
  const advance = (ms: number) => {
    clock += ms;
    vi.setSystemTime(clock);
  };
  const nextCode = (secret: string) => {
    advance(30_000);
    return totpCode(secret, clock);
  };
  const cookieOf = (res: request.Response): string => {
    const raw = ([] as string[]).concat(res.headers['set-cookie'] ?? []);
    const line = raw.find((c) => c.startsWith(`${COOKIE}=`));
    if (!line) throw new Error(`no session cookie in ${JSON.stringify(raw)}`);
    return line.split(';')[0]!;
  };
  const signup = async (): Promise<Person> => {
    const { res, payload } = await registerVerified(getCtx());
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      email: payload.email,
      password: payload.password,
      token: res.body.tokens.accessToken as string,
    };
  };
  const makeAdmin = async (roles: string[]): Promise<Admin> => {
    const ctx = getCtx();
    const p = await signup();
    await withMigrationClient(async (db) => {
      for (const role of roles) await db.$transaction((tx) => grantRoleIn(tx, p.email, role as never));
    });
    const res = await ctx.http
      .post('/api/v1/admin/auth/login')
      .send({ email: p.email, password: p.password });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
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
  const send = (a: Admin, method: 'get' | 'post' | 'patch' | 'put', path: string, body?: object) => {
    const r = getCtx().http[method](`/api/v1${path}`).set('Cookie', a.cookie);
    return method === 'get' ? r : r.set('X-CSRF-Token', a.csrf).send(body ?? {});
  };
  return { advance, nextCode, signup, makeAdmin, send, now: () => clock, start: () => clock };
}

describe('D196 «الدفع (Stripe)» with no env keys', { timeout: 300_000 }, () => {
  const stripe = new FakeStripeAccount();
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let moderator: Admin;
  let support: Admin;
  let finance: Admin;
  const SK = key('rk_test', 'PnlA');
  const WH = key('whsec', 'WhA1');
  const WH2 = key('whsec', 'WhB2');

  const get = (a: Admin) => p.send(a, 'get', '/admin/payment-settings');
  const patch = (a: Admin, body: object) => p.send(a, 'patch', '/admin/payment-settings', body);
  const withCode = (a: Admin, body: object) => ({
    totpCode: p.nextCode(a.secret),
    reason: 'set up Stripe',
    ...body,
  });
  const audits = (action: string) =>
    ctx.prisma.auditLog.findMany({ where: { action }, orderBy: { createdAt: 'asc' } });
  /** No response, row or audit row may ever carry these. */
  const secrets = () => [SK, WH, WH2];
  const expectNoSecret = (text: string) => {
    for (const s of secrets()) expect(text).not.toContain(s);
  };

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp(
      {
        ADMIN_TOTP_KEY: ADMIN_KEY,
        ADMIN_SESSION_IDLE_SECONDS: '7200',
        ADMIN_SESSION_MAX_SECONDS: '28800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '10000/900',
        RATE_LIMIT_TOPUP_CHECKOUT_USER: '10000/900',
        TOPUP_PUBLIC_BASE_URL: PUBLIC,
      },
      [{ token: STRIPE_API_FACTORY, value: stripe.factory }],
    );
    owner = await p.makeAdmin(['OWNER']);
    moderator = await p.makeAdmin(['MODERATION']);
    support = await p.makeAdmin(['SUPPORT']);
    finance = await p.makeAdmin(['FINANCE']);
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });
  afterEach(() => vi.setSystemTime(p.now()));

  it('only the OWNER: the other roles get 403 on every route, no cookie 401', async () => {
    for (const a of [moderator, support, finance]) {
      for (const res of [
        await get(a),
        await patch(a, withCode(a, { appLinkEnabled: false })),
        await p.send(a, 'post', '/admin/payment-settings/test', { secretKey: SK }),
        await p.send(a, 'post', '/admin/payment-settings/clear-keys', withCode(a, {})),
      ]) {
        expect(res.status).toBe(403);
        expect(res.body.error.code).toBe('AUTH_FORBIDDEN');
      }
    }
    expect((await ctx.http.get('/api/v1/admin/payment-settings')).status).toBe(401);
    // A bearer token of the app is no panel session.
    expect(
      (await ctx.http.get('/api/v1/admin/payment-settings').set('Authorization', `Bearer ${owner.token}`))
        .status,
    ).toBe(401);
    // The session lists the capability for the OWNER only.
    const s = await p.send(owner, 'get', '/admin/auth/session');
    expect(s.body.capabilities).toContain('payments.settings');
    expect((await p.send(finance, 'get', '/admin/auth/session')).body.capabilities).not.toContain(
      'payments.settings',
    );
    expect(stripe.checks).toEqual([]);
  });

  it('starts off: no keys (503 for top-ups), the webhook URL and the events to subscribe', async () => {
    const res = await get(owner);
    expect(res.status).toBe(200);
    expectContract(res, 'getAdminPaymentSettings');
    expect(res.headers['cache-control']).toBe('no-store');
    expect(res.body).toMatchObject({
      source: 'none',
      configured: false,
      secretKey: null,
      webhookSecret: null,
      panelKeys: null,
      envKeys: null,
      publicBaseUrl: PUBLIC,
      webhookUrl: `${PUBLIC}/api/v1/payments/stripe/webhook`,
      testKeysAllowed: true,
      connectionTestSkippable: true,
    });
    expect(res.body.webhookEvents).toEqual(
      expect.arrayContaining(['checkout.session.completed', 'charge.dispute.created', 'charge.refunded']),
    );
    expect(res.body.webhookEvents).toHaveLength(8);
    expect((await ctx.http.get('/api/v1/topup/packages')).body.error.code).toBe('TOPUP_UNAVAILABLE');
  });

  it("the website's topupEnabled cannot be turned on without keys (clear message)", async () => {
    const res = await p.send(owner, 'put', '/admin/site-settings', {
      socials: { instagram: null, tiktok: null, whatsapp: null },
      topupEnabled: true,
    });
    expect(res.status).toBe(409);
    expectContract(res, 'updateAdminSiteSettings');
    expect(res.body.error.code).toBe('ADMIN_ACTION_REFUSED');
    expect(res.body.error.message).toContain('«الدفع (Stripe)»');
    expect(res.body.error.details).toEqual([{ field: 'topupEnabled', issue: 'stripe_keys_missing' }]);
    expect((await ctx.http.get('/api/v1/site/settings')).body.topupEnabled).toBe(false);
  });

  it('the code again and a reason: missing → 400, wrong → 403 ADMIN_TOTP_INVALID; nothing saved, Stripe not asked', async () => {
    const body = { secretKey: SK, webhookSecret: WH };
    const noCode = await patch(owner, { ...body, reason: 'x' });
    expect(noCode.status).toBe(400);
    expectContract(noCode, 'updateAdminPaymentSettings');
    const noReason = await patch(owner, { ...body, totpCode: p.nextCode(owner.secret) });
    expect(noReason.status).toBe(400);
    const wrong = await patch(owner, { ...body, totpCode: '000000', reason: 'x' });
    expect(wrong.status).toBe(403);
    expectContract(wrong, 'updateAdminPaymentSettings');
    expect(wrong.body.error.code).toBe('ADMIN_TOTP_INVALID');
    const clearWrong = await p.send(owner, 'post', '/admin/payment-settings/clear-keys', {
      totpCode: '000000',
      reason: 'x',
    });
    expect(clearWrong.status).toBe(403);
    expect(await ctx.prisma.paymentSettings.count()).toBe(0);
    expect(stripe.checks).toEqual([]);
    // One reused code does not work twice either.
    const code = p.nextCode(owner.secret);
    expect((await patch(owner, { appLinkEnabled: true, totpCode: code, reason: 'x' })).status).toBe(200);
    expect((await patch(owner, { appLinkEnabled: true, totpCode: code, reason: 'x' })).status).toBe(403);
    // Failed codes count towards the lockout; a right code resets the count.
    await ctx.prisma.adminCredential.update({ where: { userId: owner.id }, data: { failedAttempts: 0 } });
  });

  it('a key Stripe refuses is not saved (the test call and the save); a malformed one is 400', async () => {
    const bad = key('sk_test', 'Bad0');
    const t = await p.send(owner, 'post', '/admin/payment-settings/test', { secretKey: bad });
    expect(t.status).toBe(409);
    expectContract(t, 'testAdminPaymentKey');
    expect(t.body.error.details).toEqual([{ field: 'secretKey', issue: 'stripe_rejected' }]);
    expectNoSecret(t.text);
    expect(t.text).not.toContain(bad);
    const save = await patch(owner, withCode(owner, { secretKey: bad, webhookSecret: WH }));
    expect(save.status).toBe(409);
    expect(save.body.error.details).toEqual([{ field: 'secretKey', issue: 'stripe_rejected' }]);
    expect(stripe.checks).toEqual([bad, bad]);
    expect(
      (await ctx.prisma.paymentSettings.findUnique({ where: { id: 1 } }))?.secretKeyEnc ?? null,
    ).toBeNull();
    // Stripe unreachable: 503, nothing saved.
    stripe.unreachable = true;
    const down = await patch(owner, withCode(owner, { secretKey: SK, webhookSecret: WH }));
    expect(down.status).toBe(503);
    expect(down.body.error.code).toBe('SERVICE_UNAVAILABLE');
    stripe.unreachable = false;
    // Shapes: a publishable key as the secret key, a secret key as the webhook secret.
    for (const body of [
      { secretKey: key('pk_test'), webhookSecret: WH },
      { secretKey: SK, webhookSecret: key('sk_test') },
      { secretKey: SK, webhookSecret: WH, unknown: true },
    ]) {
      const r = await patch(owner, withCode(owner, body));
      expect(r.status, JSON.stringify(Object.keys(body))).toBe(400);
      expectNoSecret(r.text);
    }
    // The first keys come as a pair.
    const alone = await patch(owner, withCode(owner, { secretKey: SK }));
    expect(alone.status).toBe(400);
    expect(alone.body.error.details).toContainEqual({ field: 'webhookSecret', issue: 'required' });
    // …refused before Stripe is asked: the test call, the unreachable try and the refused key only.
    expect(stripe.checks).toEqual([bad, bad, SK]);
    // The audit of the test call has the fingerprint only.
    const [row] = await audits('payment.settings.test');
    expect(row!.metadata).toMatchObject({ result: 'rejected', via: 'panel' });
    expect(JSON.stringify(row)).not.toContain(bad);
  });

  it('saves the keys after the Stripe test; GET and the response show fingerprints only; sealed at rest; audited masked', async () => {
    const t = await p.send(owner, 'post', '/admin/payment-settings/test', { secretKey: SK });
    expect(t.status).toBe(200);
    expectContract(t, 'testAdminPaymentKey');
    expect(t.body).toEqual({ ok: true, kind: 'restricted', mode: 'test', last4: 'PnlA', restricted: false });
    const res = await patch(
      owner,
      withCode(owner, { secretKey: SK, webhookSecret: WH, reason: 'launch keys' }),
    );
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'updateAdminPaymentSettings');
    expectNoSecret(res.text);
    const view = await get(owner);
    expectContract(view, 'getAdminPaymentSettings');
    expectNoSecret(view.text);
    expect(view.body).toMatchObject({
      source: 'panel',
      configured: true,
      mode: 'test',
      secretKey: {
        kind: 'restricted',
        mode: 'test',
        last4: 'PnlA',
        source: 'panel',
        setBy: { id: owner.id },
      },
      webhookSecret: { kind: 'webhook', mode: null, last4: 'WhA1', source: 'panel', setBy: { id: owner.id } },
      previousWebhookSecretValidUntil: null,
    });
    expect(Date.parse(view.body.secretKey.setAt)).toBeGreaterThan(0);
    // At rest: sealed, only the prefix and the last 4 in clear.
    const row = await ctx.prisma.paymentSettings.findUniqueOrThrow({ where: { id: 1 } });
    expectNoSecret(JSON.stringify(row));
    expect(row.secretKeyEnc).toMatch(/^v1\./);
    expect(row).toMatchObject({
      secretKeyPrefix: 'rk_test',
      secretKeyLast4: 'PnlA',
      webhookSecretLast4: 'WhA1',
    });
    // The audit row: masked before/after, the reason, the Stripe test; never a secret.
    const updates = await audits('payment.settings.update');
    const last = updates.at(-1)!;
    expect(last.actorUserId).toBe(owner.id);
    expect(last.metadata).toMatchObject({
      before: { secretKey: null, webhookSecret: null },
      after: { secretKey: 'rk_test_…PnlA', webhookSecret: 'whsec_…WhA1' },
      changed: expect.arrayContaining(['secretKey', 'webhookSecret']),
      connectionTest: 'stripe',
      reason: 'launch keys',
      via: 'panel',
    });
    for (const a of await ctx.prisma.auditLog.findMany()) expectNoSecret(JSON.stringify(a));
  });

  it("top-ups now run with the panel's key (no restart); the options from the panel apply", async () => {
    const pk = await ctx.http.get('/api/v1/topup/packages');
    expect(pk.status).toBe(200);
    expect(pk.body.bankTransfer).toBe(true);
    const buyer = await p.signup();
    const go = await ctx.http
      .post('/api/v1/topup/checkout')
      .set('Authorization', `Bearer ${buyer.token}`)
      .send({ packageId: '1000000', termsAccepted: true, termsVersion: '2026-10-31' });
    expect(go.status, JSON.stringify(go.body)).toBe(201);
    expect(stripe.made.at(-1)).toBe(SK);
    expect(stripe.sessions.at(-1)!.key).toBe(SK);
    // Options: no bank transfer, a statement suffix, the app link off — from the panel.
    const opts = await patch(
      owner,
      withCode(owner, {
        bankTransferEnabled: false,
        statementDescriptorSuffix: 'COINS',
        appLinkEnabled: false,
      }),
    );
    expect(opts.status).toBe(200);
    expect(opts.body.effective).toEqual({
      bankTransferEnabled: false,
      statementDescriptorSuffix: 'COINS',
      disputeAutoSubmit: true,
      appLinkEnabled: false,
    });
    const go2 = await ctx.http
      .post('/api/v1/topup/checkout')
      .set('Authorization', `Bearer ${buyer.token}`)
      .send({ packageId: '1000000', termsAccepted: true, termsVersion: '2026-10-31' });
    expect(go2.status).toBe(201);
    const params = stripe.sessions.at(-1)!.params;
    expect(params.allowed_payment_method_types).toEqual(['card']);
    expect(params.payment_intent_data?.statement_descriptor_suffix).toBe('COINS');
    const offer = await ctx.http
      .get('/api/v1/wallet/recharge-packages')
      .set('Authorization', `Bearer ${buyer.token}`);
    expect(offer.body.websiteTopupUrl).toBeNull();
    const back = await patch(owner, withCode(owner, { appLinkEnabled: null, bankTransferEnabled: null }));
    expect(back.body.options.appLinkEnabled).toBeNull();
    const offer2 = await ctx.http
      .get('/api/v1/wallet/recharge-packages')
      .set('Authorization', `Bearer ${buyer.token}`);
    expect(offer2.body.websiteTopupUrl).toBe(`${PUBLIC}/topup`);
  });

  it('D190 with the keys from the database: the signed webhook credits once; a dispute uses the panel options', async () => {
    const buyer = await p.signup();
    const go = await ctx.http
      .post('/api/v1/topup/checkout')
      .set('Authorization', `Bearer ${buyer.token}`)
      .send({ packageId: '1000000', termsAccepted: true, termsVersion: '2026-10-31' });
    expect(go.status).toBe(201);
    const order = await ctx.prisma.topupOrder.findUniqueOrThrow({ where: { id: go.body.orderId as string } });
    const pi = `pi_${randomUUID()}`;
    const completed = event('checkout.session.completed', {
      id: order.stripeSessionId,
      object: 'checkout.session',
      client_reference_id: order.id,
      metadata: { kabso_order_id: order.id },
      amount_total: order.amountMinor,
      currency: 'usd',
      payment_status: 'paid',
      payment_intent: pi,
    });
    // Signed with another secret: refused. With the panel's: credited, once.
    expect((await deliver(completed, key('whsec'))).status).toBe(400);
    const ok = await deliver(completed, WH);
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    expect((await deliver(completed, WH)).status).toBe(200);
    expect((await ctx.prisma.wallet.findUniqueOrThrow({ where: { userId: buyer.id } })).coins).toBe(
      1_000_000n,
    );
    // Dispute evidence is staged, not submitted, when the panel says so.
    const staged = await patch(owner, withCode(owner, { disputeAutoSubmit: false }));
    expect(staged.body.effective.disputeAutoSubmit).toBe(false);
    const dispute = await deliver(
      event('charge.dispute.created', {
        id: `dp_${randomUUID()}`,
        object: 'dispute',
        charge: `ch_${order.id}`,
        payment_intent: pi,
        amount: order.amountMinor,
        currency: 'usd',
        reason: 'fraudulent',
        status: 'needs_response',
      }),
      WH,
    );
    expect(dispute.status, JSON.stringify(dispute.body)).toBe(200);
    expect(stripe.disputes.at(-1)).toEqual({ key: SK, submit: false });
    const coinsAfter = (await ctx.prisma.wallet.findUniqueOrThrow({ where: { userId: buyer.id } })).coins;
    expect(coinsAfter).toBe(0n);
  });

  it('rotating the webhook secret: the old one still verifies for 10 minutes, then only the new one', async () => {
    const checksBefore = stripe.checks.length;
    const res = await patch(owner, withCode(owner, { webhookSecret: WH2, reason: 'rotate' }));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectNoSecret(res.text);
    expect(res.body.webhookSecret.last4).toBe('WhB2');
    expect(res.body.secretKey.last4).toBe('PnlA'); // the key stays
    const until = Date.parse(res.body.previousWebhookSecretValidUntil as string);
    expect(until - p.now()).toBe(10 * 60 * 1000);
    expect(stripe.checks).toHaveLength(checksBefore); // a webhook-only change asks Stripe nothing
    const expired = () =>
      event('checkout.session.expired', {
        id: `cs_${randomUUID()}`,
        object: 'checkout.session',
        metadata: {},
      });
    expect((await deliver(expired(), WH)).status).toBe(200);
    expect((await deliver(expired(), WH2)).status).toBe(200);
    p.advance(10 * 60 * 1000 + 1000);
    expect((await deliver(expired(), WH)).status).toBe(400);
    expect((await deliver(expired(), WH2)).status).toBe(200);
    const last = (await audits('payment.settings.update')).find(
      (a) => (a.metadata as { reason?: string }).reason === 'rotate',
    )!;
    expect(last.metadata).toMatchObject({
      before: { webhookSecret: 'whsec_…WhA1' },
      after: { webhookSecret: 'whsec_…WhB2' },
      changed: ['webhookSecret'],
    });
  });

  it('topupEnabled can be turned on now that keys exist', async () => {
    const res = await p.send(owner, 'put', '/admin/site-settings', {
      socials: { instagram: null, tiktok: null, whatsapp: null },
      topupEnabled: true,
      reason: 'keys are in',
    });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expect(res.body.topupEnabled).toBe(true);
  });

  it('a test key may skip the Stripe call outside production; a publishable key of the other mode is refused', async () => {
    const SK2 = key('sk_test', 'Skp9');
    const skipped = await patch(owner, withCode(owner, { secretKey: SK2, skipConnectionTest: true }));
    expect(skipped.status, JSON.stringify(skipped.body)).toBe(200);
    expect(stripe.checks).not.toContain(SK2);
    expect(skipped.body.secretKey).toMatchObject({ kind: 'secret', last4: 'Skp9' });
    const mismatch = await patch(owner, withCode(owner, { publishableKey: key('pk_live') }));
    expect(mismatch.status).toBe(409);
    expect(mismatch.body.error.details).toEqual([{ field: 'publishableKey', issue: 'mode_mismatch' }]);
    const PK = key('pk_test');
    const okPk = await patch(owner, withCode(owner, { publishableKey: PK }));
    expect(okPk.body.publishableKey).toBe(PK);
    // A live key may not skip.
    const live = await patch(owner, withCode(owner, { secretKey: key('rk_live'), skipConnectionTest: true }));
    expect(live.status).toBe(409);
    expect(live.body.error.details).toEqual([
      { field: 'skipConnectionTest', issue: 'connection_test_required' },
    ]);
  });

  it('clearing the keys (code + reason, audited) leaves no keys here: 503, and clear again is refused', async () => {
    const res = await p.send(
      owner,
      'post',
      '/admin/payment-settings/clear-keys',
      withCode(owner, { reason: 'gone' }),
    );
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'clearAdminPaymentKeys');
    expect(res.body).toMatchObject({ source: 'none', configured: false, panelKeys: null, secretKey: null });
    expect((await ctx.http.get('/api/v1/topup/packages')).status).toBe(503);
    const again = await p.send(
      owner,
      'post',
      '/admin/payment-settings/clear-keys',
      withCode(owner, { reason: 'x' }),
    );
    expect(again.status).toBe(409);
    expect(again.body.error.details).toEqual([{ field: 'secretKey', issue: 'nothing_to_clear' }]);
    const [row] = await audits('payment.settings.clear');
    expect(row!.metadata).toMatchObject({
      after: { secretKey: null, webhookSecret: null },
      fallback: 'none',
      reason: 'gone',
    });
    const stored = await ctx.prisma.paymentSettings.findUniqueOrThrow({ where: { id: 1 } });
    expect(stored).toMatchObject({ secretKeyEnc: null, webhookSecretEnc: null, secretKeyLast4: null });
  });

  // ---- helpers: Stripe events signed like Stripe does ---------------------------------------------------------
  function event(type: string, object: Record<string, unknown>) {
    return {
      id: `evt_${randomUUID()}`,
      object: 'event',
      type,
      api_version: '2026-09-30.endive',
      created: Math.floor(Date.now() / 1000),
      livemode: false,
      data: { object },
    };
  }
  function deliver(e: object, secret: string) {
    const payload = JSON.stringify(e);
    return ctx.http
      .post(WEBHOOK)
      .set('Stripe-Signature', Stripe.webhooks.generateTestHeaderString({ payload, secret }))
      .set('Content-Type', 'application/json')
      .send(payload);
  }
});

describe('D196 panel keys over env keys; a clear falls back to the env', { timeout: 300_000 }, () => {
  const stripe = new FakeStripeAccount();
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  const ENV_SK = key('sk_test', 'Env1');
  const ENV_WH = key('whsec', 'Env2');
  const SK = key('sk_test', 'Pan3');
  const WH = key('whsec', 'Pan4');

  const buy = async (u: Person) => {
    const r = await ctx.http
      .post('/api/v1/topup/checkout')
      .set('Authorization', `Bearer ${u.token}`)
      .send({ packageId: '100000', termsAccepted: true, termsVersion: '2026-10-31' });
    expect(r.status, JSON.stringify(r.body)).toBe(201);
    return stripe.sessions.at(-1)!.key;
  };
  const signedBy = (secret: string) => {
    const payload = JSON.stringify({
      id: `evt_${randomUUID()}`,
      object: 'event',
      type: 'checkout.session.expired',
      created: Math.floor(Date.now() / 1000),
      data: { object: { id: `cs_${randomUUID()}`, object: 'checkout.session', metadata: {} } },
    });
    return ctx.http
      .post(WEBHOOK)
      .set('Stripe-Signature', Stripe.webhooks.generateTestHeaderString({ payload, secret }))
      .set('Content-Type', 'application/json')
      .send(payload);
  };

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp(
      {
        ADMIN_TOTP_KEY: ADMIN_KEY,
        ADMIN_SESSION_IDLE_SECONDS: '7200',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '10000/900',
        RATE_LIMIT_TOPUP_CHECKOUT_USER: '10000/900',
        STRIPE_SECRET_KEY: ENV_SK,
        STRIPE_WEBHOOK_SECRET: ENV_WH,
        TOPUP_PUBLIC_BASE_URL: PUBLIC,
      },
      [{ token: STRIPE_API_FACTORY, value: stripe.factory }],
    );
    owner = await p.makeAdmin(['OWNER']);
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });
  afterEach(() => vi.setSystemTime(p.now()));

  it('env keys work as before (D190) and show masked as the fallback', async () => {
    const buyer = await p.signup();
    expect(await buy(buyer)).toBe(ENV_SK);
    const view = await p.send(owner, 'get', '/admin/payment-settings');
    expectContract(view, 'getAdminPaymentSettings');
    expect(view.text).not.toContain(ENV_SK);
    expect(view.text).not.toContain(ENV_WH);
    expect(view.body).toMatchObject({
      source: 'env',
      secretKey: { source: 'env', last4: 'Env1', setBy: null, setAt: null },
      envKeys: { secretKey: { last4: 'Env1' }, webhookSecret: { last4: 'Env2' } },
      panelKeys: null,
    });
    expect((await signedBy(ENV_WH)).status).toBe(200);
  });

  it('panel keys override the env keys at once; a clear falls back to the env keys (old panel secret 10 min)', async () => {
    const buyer = await p.signup();
    const saved = await p.send(owner, 'patch', '/admin/payment-settings', {
      secretKey: SK,
      webhookSecret: WH,
      totpCode: p.nextCode(owner.secret),
      reason: 'move keys to the panel',
    });
    expect(saved.status, JSON.stringify(saved.body)).toBe(200);
    expect(saved.body.source).toBe('panel');
    expect(await buy(buyer)).toBe(SK);
    expect((await signedBy(WH)).status).toBe(200);
    // The env secret was the one in use: it stays valid for the 10-minute grace.
    expect((await signedBy(ENV_WH)).status).toBe(200);
    const cleared = await p.send(owner, 'post', '/admin/payment-settings/clear-keys', {
      totpCode: p.nextCode(owner.secret),
      reason: 'back to the server keys',
    });
    expect(cleared.status).toBe(200);
    expect(cleared.body).toMatchObject({ source: 'env', secretKey: { source: 'env', last4: 'Env1' } });
    expect(await buy(buyer)).toBe(ENV_SK);
    expect((await signedBy(ENV_WH)).status).toBe(200);
    expect((await signedBy(WH)).status).toBe(200); // the panel's secret: still in its grace
    p.advance(11 * 60 * 1000);
    expect((await signedBy(WH)).status).toBe(400);
    const [row] = await ctx.prisma.auditLog.findMany({ where: { action: 'payment.settings.clear' } });
    expect(row!.metadata).toMatchObject({ fallback: 'env', before: { secretKey: 'sk_test_…Pan3' } });
  });
});

describe('D196 without ADMIN_TOTP_KEY', { timeout: 120_000 }, () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp();
  });
  afterAll(async () => ctx?.close());

  it('the section answers 503 ADMIN_PANEL_UNAVAILABLE', async () => {
    const res = await ctx.http.get('/api/v1/admin/payment-settings');
    expect(res.status).toBe(503);
    expectContract(res, 'getAdminPaymentSettings');
    expect(res.body.error.code).toBe('ADMIN_PANEL_UNAVAILABLE');
  });
});
