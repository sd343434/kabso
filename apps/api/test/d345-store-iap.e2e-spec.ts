/**
 * D345 (owner 2026-11-09; contract v1.110-social, CONVENTIONS §10.144): coins from Google Play Billing and App Store
 * In-App Purchase. End to end against PostgreSQL + Redis with an in-memory Google Play and App Store (no network): the
 * App Store's signed data is signed by a throwaway chain shaped like Apple's (test/helpers/fake-stores.ts) and the
 * server is given that root. Covers: verify → credit once, the duplicate token, another account's token, the consent,
 * a pending purchase; a voided purchase → claw-back (below 0) + account and device ban + the panel's reason; Apple
 * REFUND → the same; CONSUMPTION_REQUEST → the body Apple gets, only with consent; the once-per-account+device switch;
 * a banned device at the catalogue, the purchase and the sign-in; the OWNER's audited «فك الحظر».
 */
import { randomBytes, randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { IAP_STORE_CLIENTS } from '../src/modules/store-iap/store-clients.js';
import { creditIn, debitIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Admin } from './helpers/admin-panel.js';
import {
  FakeAppStore,
  FakeGooglePlay,
  fakeClients,
  signJws,
  TestPki,
  type Chain,
} from './helpers/fake-stores.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, newUser, settle, type TestContext } from './helpers/test-app.js';

const PACKAGE = 'com.kabso.live';
const BUNDLE = 'com.kabso.live';
const RTDN_TOKEN = randomBytes(24).toString('base64url');
const CONSENT = 'v-e2e-1';

interface TestUser {
  readonly id: string;
  readonly email: string;
  readonly password: string;
  readonly token: string;
  readonly deviceKey: string;
}

const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
const newDeviceKey = () => randomBytes(32).toString('hex');

describe('D345 contract coverage', () => {
  it('openapi v1.110-social declares the store operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'getStoreIapCatalog GET /api/v1/store/iap/catalog',
      'verifyStorePurchase POST /api/v1/store/iap/purchases',
      'receiveAppleNotification POST /api/v1/payments/apple/notifications',
      'receiveGoogleRtdn POST /api/v1/payments/google/rtdn',
      'getAdminStoreIapOverview GET /api/v1/admin/store-iap/overview',
      'updateAdminStoreIapSettings PATCH /api/v1/admin/store-iap/settings',
      'listAdminStoreIapProducts GET /api/v1/admin/store-iap/products',
      'createAdminStoreIapProduct POST /api/v1/admin/store-iap/products',
      'updateAdminStoreIapProduct PATCH /api/v1/admin/store-iap/products/{productId}',
      'listAdminStoreIapPurchases GET /api/v1/admin/store-iap/purchases',
      'listAdminStoreIapRefundBans GET /api/v1/admin/store-iap/refund-bans',
      'unbanAdminStoreIapRefund POST /api/v1/admin/store-iap/refund-bans/{banId}/unban',
      'syncAdminStoreIapVoided POST /api/v1/admin/store-iap/google/voided-sync',
    ]) {
      expect(ids).toContain(op);
    }
  });
});

describe('D345 store purchases switched off', { timeout: 120_000 }, () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp();
  });
  afterAll(async () => ctx?.close());

  it('without credentials the catalogue says OFF and every store operation is 503 STORE_IAP_UNAVAILABLE', async () => {
    expect(ctx.config.storeIap.google).toBeNull();
    expect(ctx.config.storeIap.apple).toBeNull();
    const payload = newUser();
    const reg = await ctx.http.post('/api/v1/auth/register').send(payload);
    expect(reg.status).toBe(202);
    const mail = await ctx.mail.waitFor(String(payload.email).toLowerCase(), 'code', 0);
    const v = await ctx.http
      .post('/api/v1/auth/register/verify')
      .send({ email: String(payload.email).toLowerCase(), code: mail.code });
    const h = auth({ token: v.body.tokens.accessToken as string });
    for (const platform of ['ANDROID', 'IOS']) {
      const c = await ctx.http.get(`/api/v1/store/iap/catalog?platform=${platform}`).set(h);
      expect(c.status).toBe(200);
      expectContract(c, 'getStoreIapCatalog');
      expect(c.body).toMatchObject({ available: false, unavailableReason: 'OFF', products: [] });
    }
    const consent = { accepted: true, version: '2026-11-09', shareConsumptionData: true };
    const calls = [
      () =>
        ctx.http
          .post('/api/v1/store/iap/purchases')
          .set(h)
          .send({ platform: 'ANDROID', productId: 'coins_1', purchaseToken: 't', consent }),
      () => ctx.http.post('/api/v1/payments/apple/notifications').send({ signedPayload: 'a.b.c' }),
      () => ctx.http.post('/api/v1/payments/google/rtdn?token=x').send({ message: { messageId: '1' } }),
    ];
    for (const call of calls) {
      const r = await call();
      expect(r.status, JSON.stringify(r.body)).toBe(503);
      expect(r.body.error.code).toBe('STORE_IAP_UNAVAILABLE');
    }
  });
});

describe('D345 store purchases', { timeout: 600_000 }, () => {
  const pki = new TestPki();
  let apple: Chain;
  let rogue: Chain;
  const google = new FakeGooglePlay();
  const appStore = new FakeAppStore();
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let moderator: Admin;
  let ipCounter = 10;
  const nextIp = () => {
    ipCounter += 1;
    return `203.0.${Math.floor(ipCounter / 250)}.${(ipCounter % 250) + 1}`;
  };
  const deviceOf = (deviceKey: string) => ({
    name: 'Pixel 9',
    platform: 'android',
    appVersion: '1.0.0',
    deviceKey,
  });

  const signup = async (deviceKey: string = newDeviceKey()): Promise<TestUser> => {
    const payload = newUser({ device: deviceOf(deviceKey) });
    const email = String(payload.email).trim().toLowerCase();
    const before = ctx.mail.sent.length;
    const ip = nextIp();
    const reg = await ctx.http.post('/api/v1/auth/register').set('X-Forwarded-For', ip).send(payload);
    expect(reg.status, JSON.stringify(reg.body)).toBe(202);
    const mail = await ctx.mail.waitFor(email, 'code', before);
    const res = await ctx.http
      .post('/api/v1/auth/register/verify')
      .set('X-Forwarded-For', ip)
      .send({ email, code: mail.code, device: deviceOf(deviceKey) });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return {
      id: res.body.user.id as string,
      email,
      password: String(payload.password),
      token: res.body.tokens.accessToken as string,
      deviceKey,
    };
  };
  const login = (u: TestUser, deviceKey = u.deviceKey) =>
    ctx.http
      .post('/api/v1/auth/login')
      .set('X-Forwarded-For', nextIp())
      .send({ identifier: u.email, password: u.password, device: deviceOf(deviceKey) });
  const coins = async (u: TestUser) =>
    (await ctx.prisma.wallet.findUnique({ where: { userId: u.id } }))?.coins ?? 0n;
  const consent = (share = true, version = CONSENT) => ({
    accepted: true,
    version,
    shareConsumptionData: share,
  });
  const catalog = async (u: TestUser, platform: 'ANDROID' | 'IOS') => {
    const r = await ctx.http.get(`/api/v1/store/iap/catalog?platform=${platform}`).set(auth(u));
    expect(r.status, JSON.stringify(r.body)).toBe(200);
    expectContract(r, 'getStoreIapCatalog');
    return r.body as {
      available: boolean;
      unavailableReason: string | null;
      products: { productId: string; coins: number }[];
      accountToken: string;
    };
  };
  const verify = (u: TestUser, body: Record<string, unknown>) =>
    ctx.http.post('/api/v1/store/iap/purchases').set(auth(u)).send(body);
  let orderSeq = 0;
  /** A Google purchase the fake store knows, bound to `u` (as the app's `obfuscatedAccountId`). */
  const googlePurchase = async (u: TestUser, extra: Record<string, unknown> = {}) => {
    orderSeq += 1;
    const token = `gp-token-${randomUUID()}`;
    const orderId = `GPA.3345-${String(orderSeq).padStart(4, '0')}-0001`;
    const cat = await catalog(u, 'ANDROID');
    google.purchases.set(token, {
      productId: 'coins_1m',
      purchaseState: 0,
      consumptionState: 0,
      orderId,
      purchaseTimeMillis: String(Date.now()),
      obfuscatedExternalAccountId: cat.accountToken,
      ...extra,
    });
    return { token, orderId };
  };
  const buyGoogle = async (u: TestUser, share = true) => {
    const g = await googlePurchase(u);
    const r = await verify(u, {
      platform: 'ANDROID',
      productId: 'coins_1m',
      purchaseToken: g.token,
      consent: consent(share),
    });
    expect(r.status, JSON.stringify(r.body)).toBe(200);
    expectContract(r, 'verifyStorePurchase');
    return { ...g, purchaseId: r.body.purchaseId as string, body: r.body };
  };
  let txSeq = 2_000_000_000;
  const appleTx = (u: TestUser | null, extra: Record<string, unknown> = {}, chain = apple) => {
    txSeq += 1;
    const transactionId = String(txSeq);
    return {
      transactionId,
      jws: signJws(chain, {
        transactionId,
        originalTransactionId: transactionId,
        bundleId: BUNDLE,
        productId: 'ios.coins.1m',
        type: 'Consumable',
        environment: 'Sandbox',
        purchaseDate: Date.now(),
        signedDate: Date.now(),
        price: 12_990,
        currency: 'USD',
        ...(u ? { appAccountToken: u.id } : {}),
        ...extra,
      }),
    };
  };
  const buyApple = async (u: TestUser, share = true) => {
    const t = appleTx(u);
    const r = await verify(u, {
      platform: 'IOS',
      productId: 'ios.coins.1m',
      signedTransaction: t.jws,
      consent: consent(share),
    });
    expect(r.status, JSON.stringify(r.body)).toBe(200);
    expectContract(r, 'verifyStorePurchase');
    return { ...t, purchaseId: r.body.purchaseId as string, body: r.body };
  };
  const notify = (payload: Record<string, unknown>, chain = apple) =>
    ctx.http
      .post('/api/v1/payments/apple/notifications')
      .send({ signedPayload: signJws(chain, { signedDate: Date.now(), version: '2.0', ...payload }) });
  const appleNotice = (type: string, transactionId: string, extra: Record<string, unknown> = {}) => ({
    notificationType: type,
    notificationUUID: randomUUID(),
    data: {
      bundleId: BUNDLE,
      environment: 'Sandbox',
      signedTransactionInfo: signJws(apple, {
        transactionId,
        bundleId: BUNDLE,
        productId: 'ios.coins.1m',
        type: 'Consumable',
        environment: 'Sandbox',
        signedDate: Date.now(),
        ...extra,
      }),
    },
  });
  const spend = (u: TestUser, amount: bigint) =>
    ctx.prisma.$transaction((tx) => debitIn(tx, u.id, amount, 'BULLET_MESSAGE', `e2e-${randomUUID()}`));
  const syncVoided = async () => {
    const r = await p.send(owner, 'post', '/admin/store-iap/google/voided-sync');
    expect(r.status, JSON.stringify(r.body)).toBe(200);
    expectContract(r, 'syncAdminStoreIapVoided');
    return r.body as { checked: number; refunded: number; unknown: number };
  };
  const voidOf = (g: { token: string; orderId: string }, extra: Record<string, unknown> = {}) => ({
    purchaseToken: g.token,
    orderId: g.orderId,
    voidedTimeMillis: String(Date.now()),
    purchaseTimeMillis: String(Date.now() - 60_000),
    voidedSource: 0,
    voidedReason: 7,
    ...extra,
  });

  beforeAll(async () => {
    apple = pki.chain('apple');
    rogue = pki.chain('rogue');
    ctx = await createTestApp(
      {
        TRUST_PROXY: 'loopback',
        ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
        JWT_ACCESS_TTL_SECONDS: String(60 * 86_400),
        REFRESH_TTL_SECONDS: String(60 * 86_400),
        REFRESH_ABSOLUTE_TTL_SECONDS: String(60 * 86_400),
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        STORE_IAP_GOOGLE_PACKAGE_NAME: PACKAGE,
        STORE_IAP_GOOGLE_SERVICE_ACCOUNT_FILE: '/unused/sa.json',
        STORE_IAP_GOOGLE_RTDN_TOKEN: RTDN_TOKEN,
        STORE_IAP_APPLE_BUNDLE_ID: BUNDLE,
        STORE_IAP_APPLE_ISSUER_ID: '57246542-96fe-1a63-e053-0824d011072a',
        STORE_IAP_APPLE_KEY_ID: 'ABCDEFGHIJ',
        STORE_IAP_APPLE_PRIVATE_KEY_FILE: '/unused/key.p8',
        STORE_IAP_APPLE_ROOT_CERT_FILES: '/unused/root.cer',
        STORE_IAP_SWEEP_INTERVAL_SECONDS: '0',
        STORE_IAP_CONSENT_VERSION: CONSENT,
      },
      [{ token: IAP_STORE_CLIENTS, value: fakeClients(google, appStore, apple.root) }],
    );
    owner = await p.makeAdmin(['OWNER']);
    moderator = await p.makeAdmin(['MODERATION']);
  });
  afterAll(async () => {
    vi.useRealTimers();
    pki.cleanup();
    await ctx?.close();
  });

  it('the OWNER maps store products to coins; a moderator reads but cannot change them', async () => {
    const denied = await p.send(moderator, 'post', '/admin/store-iap/products', {
      platform: 'GOOGLE_PLAY',
      productId: 'coins_1m',
      coins: 1_000_000,
      reason: 'launch',
    });
    expect(denied.status).toBe(403);
    for (const body of [
      {
        platform: 'GOOGLE_PLAY',
        productId: 'coins_1m',
        coins: 1_000_000,
        referenceUsdCents: 1299,
        reason: 'launch',
      },
      {
        platform: 'APP_STORE',
        productId: 'ios.coins.1m',
        coins: 1_000_000,
        referenceUsdCents: 1299,
        reason: 'launch',
      },
      { platform: 'GOOGLE_PLAY', productId: 'coins_old', coins: 10, enabled: false, reason: 'retired' },
    ]) {
      const r = await p.send(owner, 'post', '/admin/store-iap/products', body);
      expect(r.status, JSON.stringify(r.body)).toBe(201);
      expectContract(r, 'createAdminStoreIapProduct');
    }
    const dup = await p.send(owner, 'post', '/admin/store-iap/products', {
      platform: 'GOOGLE_PLAY',
      productId: 'coins_1m',
      coins: 5,
      reason: 'again',
    });
    expect(dup.status).toBe(409);
    const list = await p.send(moderator, 'get', '/admin/store-iap/products');
    expect(list.status).toBe(200);
    expectContract(list, 'listAdminStoreIapProducts');
    expect(list.body.data).toHaveLength(3);
    const overview = await p.send(moderator, 'get', '/admin/store-iap/overview');
    expect(overview.status).toBe(200);
    expectContract(overview, 'getAdminStoreIapOverview');
    expect(overview.body.googlePlay).toMatchObject({
      configured: true,
      packageName: PACKAGE,
      rtdnEnabled: true,
    });
    expect(overview.body.appStore).toMatchObject({ configured: true, bundleId: BUNDLE, roots: 1 });
    expect(overview.body.settings.oncePerAccountDevice).toBe(false);
    const audit = await ctx.prisma.auditLog.count({ where: { action: 'store_iap.product.create' } });
    expect(audit).toBe(3);
  });

  it('the catalogue lists the enabled products of the platform with the account token', async () => {
    const u = await signup();
    const a = await catalog(u, 'ANDROID');
    expect(a).toMatchObject({ available: true, unavailableReason: null });
    expect(a.products).toEqual([{ productId: 'coins_1m', coins: 1_000_000 }]);
    expect(a.accountToken).toMatch(/^[0-9a-f]{64}$/);
    const i = await catalog(u, 'IOS');
    expect(i.products).toEqual([{ productId: 'ios.coins.1m', coins: 1_000_000 }]);
    expect(i.accountToken).toBe(u.id);
  });

  it('Google: verified → credited once and consumed; the same token again is the stored result; another account 409', async () => {
    const u = await signup();
    const g = await buyGoogle(u);
    expect(g.body).toMatchObject({
      status: 'CREDITED',
      coins: 1_000_000,
      balance: 1_000_000,
      alreadyProcessed: false,
      environment: 'PRODUCTION',
      platform: 'ANDROID',
    });
    expect(google.consumed).toContain(g.token);
    const again = await verify(u, {
      platform: 'ANDROID',
      productId: 'coins_1m',
      purchaseToken: g.token,
      consent: consent(),
    });
    expect(again.status).toBe(200);
    expect(again.body).toMatchObject({
      purchaseId: g.purchaseId,
      alreadyProcessed: true,
      balance: 1_000_000,
    });
    expect(await coins(u)).toBe(1_000_000n);
    const ledger = await ctx.prisma.walletLedgerEntry.count({ where: { userId: u.id, reason: 'STORE_IAP' } });
    expect(ledger).toBe(1);
    const other = await signup();
    const stolen = await verify(other, {
      platform: 'ANDROID',
      productId: 'coins_1m',
      purchaseToken: g.token,
      consent: consent(),
    });
    expect(stolen.status).toBe(409);
    expect(stolen.body.error.code).toBe('STORE_IAP_PURCHASE_CONFLICT');
    // A token bound to another account (obfuscatedAccountId) is refused even the first time.
    const theirs = await googlePurchase(u);
    const r = await verify(other, {
      platform: 'ANDROID',
      productId: 'coins_1m',
      purchaseToken: theirs.token,
      consent: consent(),
    });
    expect(r.status).toBe(409);
    expect(await coins(other)).toBe(0n);
  });

  it('Google: the consent, an unknown product, a pending payment, a rejected token and a test purchase', async () => {
    const u = await signup();
    const g = await googlePurchase(u);
    const body = { platform: 'ANDROID', productId: 'coins_1m', purchaseToken: g.token };
    const stale = await verify(u, { ...body, consent: consent(true, 'old') });
    expect(stale.status).toBe(400);
    expect(stale.body.error.details[0]).toMatchObject({ field: 'consent.version', issue: 'stale' });
    const unticked = await verify(u, { ...body, consent: { ...consent(), accepted: false } });
    expect(unticked.status).toBe(400);
    const unknown = await verify(u, { ...body, productId: 'nope', consent: consent() });
    expect(unknown.status).toBe(400);
    expect(unknown.body.error.code).toBe('STORE_IAP_VERIFICATION_FAILED');
    const both = await verify(u, { ...body, signedTransaction: 'x', consent: consent() });
    expect(both.status).toBe(400);
    const pending = await googlePurchase(u, { purchaseState: 2 });
    const pr = await verify(u, { ...body, purchaseToken: pending.token, consent: consent() });
    expect(pr.status).toBe(409);
    expect(pr.body.error.code).toBe('STORE_IAP_PENDING');
    const bad = await verify(u, { ...body, purchaseToken: 'never-issued', consent: consent() });
    expect(bad.status).toBe(400);
    expect(bad.body.error.details[0]).toMatchObject({ field: 'purchaseToken', issue: 'rejected' });
    const test = await googlePurchase(u, { purchaseType: 0, orderId: undefined });
    const tr = await verify(u, { ...body, purchaseToken: test.token, consent: consent() });
    expect(tr.status).toBe(200);
    expect(tr.body).toMatchObject({ environment: 'SANDBOX', status: 'CREDITED' });
    const row = await ctx.prisma.iapPurchase.findUniqueOrThrow({
      where: { id: tr.body.purchaseId as string },
    });
    expect(row.transactionId).toMatch(/^token:[0-9a-f]{64}$/);
    expect(await coins(u)).toBe(1_000_000n);
    expect(await ctx.prisma.iapPurchase.count({ where: { userId: u.id } })).toBe(1);
  });

  it('Google refund (voided purchases) → coins back below 0, account and every device banned, the panel shows the reason', async () => {
    const u = await signup();
    const sameDevice = await signup(u.deviceKey);
    // Owner (int21, D345 #5): a device the account only signed in on (sessions.device_hash history) is banned too.
    const tablet = newDeviceKey();
    const onTablet = await login(u, tablet);
    expect(onTablet.status, JSON.stringify(onTablet.body)).toBe(200);
    const tabletOwner = await signup(tablet);
    const g = await buyGoogle(u);
    await spend(u, 600_000n);
    google.voided.push(voidOf(g));
    const result = await syncVoided();
    expect(result.refunded).toBe(1);
    expect(await coins(u)).toBe(-600_000n);
    const purchase = await ctx.prisma.iapPurchase.findUniqueOrThrow({ where: { id: g.purchaseId } });
    expect(purchase).toMatchObject({
      status: 'REFUNDED',
      refundSource: 'GOOGLE_VOIDED',
      coinsReversed: 1_000_000n,
    });
    expect(purchase.refundReason).toMatch(
      /^استرداد عبر Google Play بتاريخ \d{4}-\d{2}-\d{2} — طلب GPA\.3345-/,
    );
    expect(purchase.refundReason).toContain('(chargeback)');
    const user = await ctx.prisma.user.findUniqueOrThrow({ where: { id: u.id } });
    expect(user.status).toBe('SUSPENDED');
    const bans = await ctx.prisma.deviceBan.findMany({ where: { iapPurchaseId: g.purchaseId } });
    expect(bans).toHaveLength(2);
    for (const b of bans) {
      expect(b.endsAt).toBeNull();
      expect(b.reason).toBe(purchase.refundReason);
    }
    expect(new Set(bans.map((b) => b.deviceHash.trim())).size).toBe(2);
    const refundBan = await ctx.prisma.iapRefundBan.findFirstOrThrow({ where: { purchaseId: g.purchaseId } });
    expect(refundBan.devicesBanned).toBe(2);
    // The tablet's own account is refused there too.
    const tabletLogin = await login(tabletOwner);
    expect(tabletLogin.status).toBe(403);
    expect(tabletLogin.body.error.code).toBe('DEVICE_BANNED');
    // Signing in: the account is suspended; another account on the banned device is refused with the reason.
    const own = await login(u);
    expect(own.status).toBe(403);
    const other = await login(sameDevice);
    expect(other.status).toBe(403);
    expect(other.body.error.code).toBe('DEVICE_BANNED');
    expect(JSON.stringify(other.body.error.details)).toContain('استرداد عبر Google Play');
    // A sign-up from the device is refused too (the existing ban model).
    const reg = await ctx.http
      .post('/api/v1/auth/register')
      .set('X-Forwarded-For', nextIp())
      .send(newUser({ device: deviceOf(u.deviceKey) }));
    expect(reg.status).toBe(403);
    expect(reg.body.error.code).toBe('DEVICE_BANNED');
    // Idempotent: the same void again changes nothing.
    const again = await syncVoided();
    expect(again.refunded).toBe(0);
    expect(await coins(u)).toBe(-600_000n);
    const panelBans = await p.send(moderator, 'get', '/admin/store-iap/refund-bans?status=ACTIVE');
    expect(panelBans.status).toBe(200);
    expectContract(panelBans, 'listAdminStoreIapRefundBans');
    const row = (panelBans.body.data as { user: { id: string }; reason: string }[]).find(
      (r) => r.user.id === u.id,
    );
    expect(row).toMatchObject({
      reason: purchase.refundReason,
      accountBanned: true,
      deviceBanned: true,
      coins: 1_000_000,
    });
    const purchases = await p.send(
      moderator,
      'get',
      '/admin/store-iap/purchases?status=REFUNDED&platform=GOOGLE_PLAY',
    );
    expect(purchases.status).toBe(200);
    expectContract(purchases, 'listAdminStoreIapPurchases');
    expect((purchases.body.data as { id: string }[]).map((r) => r.id)).toContain(g.purchaseId);
    expect(JSON.stringify(purchases.body)).not.toContain(g.token);
    const audit = await ctx.prisma.auditLog.findFirst({
      where: { action: 'store_iap.refund', targetId: g.purchaseId },
    });
    expect(audit?.metadata).toMatchObject({ accountBanned: true, devicesBanned: 2, ban: true });
  });

  it('only the OWNER lifts a refund ban (the code again, a reason, audited); the general unban and the device list refuse it', async () => {
    const u = await signup();
    const g = await buyGoogle(u);
    google.voided.push(voidOf(g, { voidedReason: 1 }));
    await syncVoided();
    const ban = await ctx.prisma.iapRefundBan.findUniqueOrThrow({ where: { purchaseId: g.purchaseId } });
    const deviceBan = await ctx.prisma.deviceBan.findFirstOrThrow({ where: { iapPurchaseId: g.purchaseId } });
    const modUnban = await p.send(moderator, 'post', `/admin/store-iap/refund-bans/${ban.id}/unban`, {
      account: true,
      device: true,
      reason: 'try',
      totpCode: p.nextCode(moderator.secret),
    });
    expect(modUnban.status).toBe(403);
    const general = await p.send(moderator, 'post', `/admin/users/${u.id}/unban`, { reason: 'try' });
    expect(general.status).toBe(409);
    expect(general.body.error.code).toBe('ADMIN_ACTION_REFUSED');
    const lift = await p.send(moderator, 'post', `/admin/device-bans/${deviceBan.id}/lift`, {
      reason: 'try',
    });
    expect(lift.status).toBe(409);
    const noCode = await p.send(owner, 'post', `/admin/store-iap/refund-bans/${ban.id}/unban`, {
      account: true,
      device: false,
      reason: 'goodwill',
    });
    expect(noCode.status).toBe(403);
    expect(noCode.body.error.code).toBe('ADMIN_TOTP_INVALID');
    const ok = await p.send(owner, 'post', `/admin/store-iap/refund-bans/${ban.id}/unban`, {
      account: true,
      device: false,
      reason: 'العميل أثبت أن الاسترداد خطأ من المتجر',
      totpCode: p.nextCode(owner.secret),
    });
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    expectContract(ok, 'unbanAdminStoreIapRefund');
    expect(ok.body).toMatchObject({ accountBanned: false, deviceBanned: true, devicesLifted: 0 });
    expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: u.id } })).status).toBe('ACTIVE');
    // The device is still banned: the account signs in only from another phone.
    expect((await login(u)).body.error?.code).toBe('DEVICE_BANNED');
    const device = await p.send(owner, 'post', `/admin/store-iap/refund-bans/${ban.id}/unban`, {
      account: false,
      device: true,
      reason: 'the device too',
      totpCode: p.nextCode(owner.secret),
    });
    expect(device.status).toBe(200);
    expect(device.body).toMatchObject({ accountBanned: false, deviceBanned: false, devicesLifted: 1 });
    expect((await login(u)).status).toBe(200);
    const twice = await p.send(owner, 'post', `/admin/store-iap/refund-bans/${ban.id}/unban`, {
      account: true,
      device: false,
      reason: 'again',
      totpCode: p.nextCode(owner.secret),
    });
    expect(twice.status).toBe(409);
    const audits = await ctx.prisma.auditLog.findMany({
      where: { action: 'store_iap.unban', targetId: u.id },
    });
    expect(audits).toHaveLength(2);
    expect(audits.every((a) => a.actorUserId === owner.id)).toBe(true);
    const first = audits.find((a) => (a.metadata as { account?: boolean }).account === true);
    expect(first?.metadata).toMatchObject({
      reason: 'العميل أثبت أن الاسترداد خطأ من المتجر',
      via: 'panel',
      before: { account: true, device: true },
      after: { account: false, device: true },
    });
    // The coins taken back stay taken.
    expect(await coins(u)).toBe(0n);
  });

  it('a void the team made in Play Console takes the coins back without a ban', async () => {
    const u = await signup();
    const g = await buyGoogle(u);
    google.voided.push(voidOf(g, { voidedSource: 1, voidedReason: 0 }));
    await syncVoided();
    expect(await coins(u)).toBe(0n);
    expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: u.id } })).status).toBe('ACTIVE');
    expect(await ctx.prisma.iapRefundBan.count({ where: { purchaseId: g.purchaseId } })).toBe(0);
    expect(await ctx.prisma.deviceBan.count({ where: { iapPurchaseId: g.purchaseId } })).toBe(0);
  });

  it('RTDN: a wrong token is 403; a voided notification only triggers a poll (applied once per message)', async () => {
    const u = await signup();
    const g = await buyGoogle(u);
    const msg = (data: Record<string, unknown>, id = randomUUID()) => ({
      message: { data: Buffer.from(JSON.stringify(data)).toString('base64'), messageId: id },
      subscription: 'projects/kabso/subscriptions/play',
    });
    const wrong = await ctx.http
      .post('/api/v1/payments/google/rtdn?token=nope')
      .send(msg({ packageName: PACKAGE }));
    expect(wrong.status).toBe(403);
    // A forged notification for a purchase the Voided Purchases API does not list refunds nothing.
    const calls = google.voidedCalls.length;
    const forged = await ctx.http.post(`/api/v1/payments/google/rtdn?token=${RTDN_TOKEN}`).send(
      msg({
        packageName: PACKAGE,
        voidedPurchaseNotification: { purchaseToken: g.token, orderId: g.orderId },
      }),
    );
    expect(forged.status).toBe(200);
    expectContract(forged, 'receiveGoogleRtdn');
    await settle(ctx);
    expect(google.voidedCalls.length).toBe(calls + 1);
    expect(await coins(u)).toBe(1_000_000n);
    google.voided.push(voidOf(g));
    const id = randomUUID();
    const real = msg(
      { packageName: PACKAGE, voidedPurchaseNotification: { purchaseToken: g.token, orderId: g.orderId } },
      id,
    );
    expect((await ctx.http.post(`/api/v1/payments/google/rtdn?token=${RTDN_TOKEN}`).send(real)).status).toBe(
      200,
    );
    await settle(ctx);
    expect(await coins(u)).toBe(0n);
    expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: u.id } })).status).toBe('SUSPENDED');
    const replay = await ctx.http.post(`/api/v1/payments/google/rtdn?token=${RTDN_TOKEN}`).send(real);
    expect(replay.status).toBe(200);
    await settle(ctx);
    expect(google.voidedCalls.length).toBe(calls + 2);
  });

  it('App Store: a signed transaction is verified to the configured root and credited once', async () => {
    const u = await signup();
    const t = await buyApple(u);
    expect(t.body).toMatchObject({
      status: 'CREDITED',
      environment: 'SANDBOX',
      platform: 'IOS',
      balance: 1_000_000,
    });
    const row = await ctx.prisma.iapPurchase.findUniqueOrThrow({ where: { id: t.purchaseId } });
    expect(row).toMatchObject({
      transactionId: t.transactionId,
      priceMilli: 12_990n,
      currency: 'USD',
      consentShareData: true,
    });
    const again = await verify(u, {
      platform: 'IOS',
      productId: 'ios.coins.1m',
      signedTransaction: t.jws,
      consent: consent(),
    });
    expect(again.body.alreadyProcessed).toBe(true);
    expect(await coins(u)).toBe(1_000_000n);
    const forged = appleTx(u, {}, rogue);
    const fr = await verify(u, {
      platform: 'IOS',
      productId: 'ios.coins.1m',
      signedTransaction: forged.jws,
      consent: consent(),
    });
    expect(fr.status).toBe(400);
    expect(fr.body.error.details[0]).toMatchObject({ field: 'signedTransaction', issue: 'root' });
    const otherBundle = appleTx(u, { bundleId: 'com.other.app' });
    expect(
      (
        await verify(u, {
          platform: 'IOS',
          productId: 'ios.coins.1m',
          signedTransaction: otherBundle.jws,
          consent: consent(),
        })
      ).status,
    ).toBe(400);
    const wrongProduct = appleTx(u, { productId: 'ios.other' });
    expect(
      (
        await verify(u, {
          platform: 'IOS',
          productId: 'ios.coins.1m',
          signedTransaction: wrongProduct.jws,
          consent: consent(),
        })
      ).body.error.details[0],
    ).toMatchObject({ field: 'productId', issue: 'mismatch' });
    const other = await signup();
    const bound = appleTx(u);
    expect(
      (
        await verify(other, {
          platform: 'IOS',
          productId: 'ios.coins.1m',
          signedTransaction: bound.jws,
          consent: consent(),
        })
      ).status,
    ).toBe(409);
  });

  it('App Store REFUND → coins back, account and device banned; a replay changes nothing', async () => {
    const u = await signup();
    const t = await buyApple(u);
    await spend(u, 1_000_000n);
    const note = appleNotice('REFUND', t.transactionId, { revocationDate: Date.now(), revocationReason: 0 });
    const r = await notify(note);
    expect(r.status, JSON.stringify(r.body)).toBe(200);
    expectContract(r, 'receiveAppleNotification');
    expect(await coins(u)).toBe(-1_000_000n);
    const row = await ctx.prisma.iapPurchase.findUniqueOrThrow({ where: { id: t.purchaseId } });
    expect(row.status).toBe('REFUNDED');
    expect(row.refundReason).toMatch(/^استرداد عبر App Store بتاريخ \d{4}-\d{2}-\d{2} — معاملة \d+/);
    expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: u.id } })).status).toBe('SUSPENDED');
    expect(await ctx.prisma.deviceBan.count({ where: { iapPurchaseId: t.purchaseId, liftedAt: null } })).toBe(
      1,
    );
    expect((await notify(note)).status).toBe(200);
    expect(await coins(u)).toBe(-1_000_000n);
    // A notification signed by another root is refused.
    const forged = await notify(appleNotice('REFUND', t.transactionId), rogue);
    expect(forged.status).toBe(400);
  });

  it('CONSUMPTION_REQUEST → the consumption information is sent only with the consent', async () => {
    const u = await signup();
    await ctx.prisma.$transaction((tx) => creditIn(tx, u.id, 500_000n, 'ADMIN_GRANT', `e2e-${randomUUID()}`));
    const t = await buyApple(u, true);
    // 500 000 older coins go first: spending 750 000 uses 250 000 of the purchase → 25 %.
    await spend(u, 750_000n);
    const before = appStore.sent.length;
    const r = await notify(appleNotice('CONSUMPTION_REQUEST', t.transactionId));
    expect(r.status).toBe(200);
    expect(appStore.sent.length).toBe(before + 1);
    expect(appStore.sent.at(-1)).toEqual({
      transactionId: t.transactionId,
      sandbox: true,
      body: {
        customerConsented: true,
        consumptionPercentage: 25_000,
        deliveryStatus: 'DELIVERED',
        refundPreference: 'DECLINE',
        sampleContentProvided: false,
      },
    });
    const req = await ctx.prisma.iapConsumptionRequest.findFirstOrThrow({
      where: { purchaseId: t.purchaseId },
    });
    expect(req.status).toBe('SENT');
    expect(req.context).toMatchObject({ accountTenure: 1, userStatus: 1 });
    // No consent: Apple is not answered.
    const n = await signup();
    const t2 = await buyApple(n, false);
    const r2 = await notify(appleNotice('CONSUMPTION_REQUEST', t2.transactionId));
    expect(r2.status).toBe(200);
    expect(appStore.sent.length).toBe(before + 1);
    const req2 = await ctx.prisma.iapConsumptionRequest.findFirstOrThrow({
      where: { purchaseId: t2.purchaseId },
    });
    expect(req2.status).toBe('SKIPPED_NO_CONSENT');
    // A failure is retried by the sweeper.
    const t3 = await buyApple(n, true);
    appStore.fail = 1;
    await notify(appleNotice('CONSUMPTION_REQUEST', t3.transactionId));
    const req3 = await ctx.prisma.iapConsumptionRequest.findFirstOrThrow({
      where: { purchaseId: t3.purchaseId },
    });
    expect(req3).toMatchObject({ status: 'PENDING', attempts: 1 });
    const { IapService } = await import('../src/modules/store-iap/iap.service.js');
    const swept = await ctx.app.get(IapService).sweep();
    expect(swept.consumptions).toBe(1);
    expect(appStore.sent.at(-1)?.body.consumptionPercentage).toBe(0);
  });

  it('«شراء واحد لكل حساب وجهاز»: on, a second purchase is refused (Google not credited, Apple credited and flagged); off, unlimited', async () => {
    const u = await signup();
    await buyGoogle(u);
    const second = await buyGoogle(u);
    expect(second.body.status).toBe('CREDITED');
    expect(await coins(u)).toBe(2_000_000n);
    const denied = await p.send(moderator, 'patch', '/admin/store-iap/settings', {
      oncePerAccountDevice: true,
      reason: 'x',
    });
    expect(denied.status).toBe(403);
    const on = await p.send(owner, 'patch', '/admin/store-iap/settings', {
      oncePerAccountDevice: true,
      reason: 'launch rule',
    });
    expect(on.status).toBe(200);
    expectContract(on, 'updateAdminStoreIapSettings');
    expect((await catalog(u, 'ANDROID')).unavailableReason).toBe('LIMIT_REACHED');
    const fresh = await signup();
    expect((await catalog(fresh, 'ANDROID')).available).toBe(true);
    // Another account on the same device has reached it too.
    const twin = await signup(u.deviceKey);
    expect((await catalog(twin, 'ANDROID')).unavailableReason).toBe('LIMIT_REACHED');
    const race = await buyGoogle(u);
    expect(race.body).toMatchObject({ status: 'REJECTED', rejectReason: 'ONCE_LIMIT' });
    expect(google.consumed).not.toContain(race.token);
    expect(await coins(u)).toBe(2_000_000n);
    // Google refunds the unconsumed purchase by itself: that void never bans.
    google.voided.push(voidOf(race));
    await syncVoided();
    expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: u.id } })).status).toBe('ACTIVE');
    const ios = await buyApple(u);
    expect(ios.body.status).toBe('CREDITED');
    const flagged = await ctx.prisma.auditLog.findFirst({
      where: { action: 'store_iap.credit', targetId: ios.purchaseId },
    });
    expect(flagged?.metadata).toMatchObject({ limitExceeded: true });
    const off = await p.send(owner, 'patch', '/admin/store-iap/settings', {
      oncePerAccountDevice: false,
      reason: 'open',
    });
    expect(off.status).toBe(200);
    expect((await catalog(u, 'ANDROID')).available).toBe(true);
    expect((await buyGoogle(u)).body.status).toBe('CREDITED');
    const audit = await ctx.prisma.auditLog.count({ where: { action: 'store_iap.settings.update' } });
    expect(audit).toBe(2);
  });

  it('a banned device sees no store and cannot buy', async () => {
    const victim = await signup();
    const g = await buyGoogle(victim);
    google.voided.push(voidOf(g));
    await syncVoided();
    // A second account made on the device before the ban, still holding an old session there.
    const before = await ctx.prisma.session.findFirst({ where: { userId: victim.id, revokedAt: null } });
    expect(before).toBeNull();
    const elsewhere = await signup();
    const relog = await login(elsewhere, victim.deviceKey);
    expect(relog.status).toBe(403);
    expect(relog.body.error.code).toBe('DEVICE_BANNED');
    // A session from before the ban on the device keeps no store: the device key in the request is checked.
    const other = await googlePurchase(elsewhere);
    const r = await verify(elsewhere, {
      platform: 'ANDROID',
      productId: 'coins_1m',
      purchaseToken: other.token,
      consent: consent(),
      device: deviceOf(victim.deviceKey),
    });
    expect(r.status).toBe(403);
    expect(r.body.error.code).toBe('DEVICE_BANNED');
    expect(await coins(elsewhere)).toBe(0n);
  });

  it('the purchases list is a contract table and a CSV export is audited', async () => {
    const res = await p.send(owner, 'get', '/admin/store-iap/purchases?format=csv');
    expect(res.status).toBe(200);
    expect(String(res.headers['content-type'])).toContain('text/csv');
    expect(res.text.split('\n')[0]).toContain('transaction');
    const audit = await ctx.prisma.auditLog.count({
      where: { action: 'admin.export.csv', targetId: 'iap_purchases' },
    });
    expect(audit).toBe(1);
  });
});
