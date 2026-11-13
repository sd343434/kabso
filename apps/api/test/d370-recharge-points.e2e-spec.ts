/**
 * D370 (owner 2026-11-11; contract v1.126-social, CONVENTIONS §10.163): recharge points «نقاط الشحن». Every coin a
 * person RECEIVES from a paid recharge — a website card top-up, a store purchase, a recharge agent's direct sale or a
 * recharge order — is one point, earned once per recharge, to the buyer and never the agent; other credits earn
 * nothing. The points never expire and buy VIP «استبدل بالنقاط» with the same NEW / RENEW / UPGRADE rules and renewal
 * discount as coins (an atomic conditional debit, an Idempotency-Key replay, two redemptions at once, a changed
 * price, INSUFFICIENT_RECHARGE_POINTS). A reversed recharge takes its points back (the balance may go below 0). The
 * panel sets each tier's points price, reads the balance and ledger, and adjusts with the code again (audited). End
 * to end against PostgreSQL + Redis with the API as the DML-only runtime role.
 */
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { topUpIn } from '../src/modules/recharge/recharge-core.js';
import { recordPurchaseIn, refundPurchaseIn } from '../src/modules/store-iap/iap-core.js';
import { creditOrderIn, reconcileOrderIn } from '../src/modules/topup/topup-core.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { panel, type Admin } from './helpers/admin-panel.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, openapi, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';
const AGENT_RULES = {
  activationMinCoins: 30_000_000,
  priceTiers: [{ minCoins: 0, minorPerMillion: 1200 }],
  currency: 'USD',
};

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

describe('D370 contract coverage', () => {
  it('openapi v1.126-social declares the points operations, fields and reasons', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'getMyRechargePoints GET /api/v1/me/recharge-points',
        'adjustAdminUserRechargePoints POST /api/v1/admin/users/{userId}/recharge-points/adjustments',
      ]),
    );
    const schemas = (openapi.components as { schemas: Record<string, Record<string, unknown>> }).schemas;
    expect((schemas.RechargePointsReason as { enum: string[] }).enum).toEqual([
      'RECHARGE_WEB',
      'RECHARGE_STORE',
      'RECHARGE_AGENT',
      'VIP_REDEEM',
      'REVERSAL',
      'ADMIN_ADJUST',
    ]);
    expect((schemas.VipPayWith as { enum: string[] }).enum).toEqual(['COINS', 'POINTS']);
    expect((schemas.BuyVipRequest as { required: string[] }).required).toEqual(['tierId']);
    expect((schemas.VipTier as { required: string[] }).required).toEqual(
      expect.arrayContaining(['pricePoints', 'renewPricePoints']),
    );
    expect((schemas.MyVip as { required: string[] }).required).toContain('rechargePoints');
    expect((schemas.AdminVipTier as { required: string[] }).required).toContain('pointsPrice');
  });
});

describe('D370 «نقاط الشحن»', { timeout: 600_000 }, () => {
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let png: Buffer;
  const tiers: Record<string, string> = {};

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
    };
  };
  const now = () => new Date(p.now());
  const points = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me/recharge-points?limit=50').set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getMyRechargePoints');
    return res.body as {
      balance: number;
      data: { reason: string; delta: number; balanceAfter: number }[];
      page: { hasMore: boolean; nextCursor: string | null };
    };
  };
  const balance = async (u: TestUser) => (await points(u)).balance;
  const coins = async (u: TestUser) =>
    Number((await ctx.prisma.wallet.findUnique({ where: { userId: u.id } }))?.coins ?? 0n);

  // ---- recharge paths ----------------------------------------------------------------------------------------
  const rules = () => ({
    ...ctx.config.recharge.badges,
    cherriesPerCoin: ctx.config.economy.cherriesPerCoin,
  });
  /** A website top-up order of `amount` coins (PENDING). */
  const topupOrder = async (u: TestUser, amount: bigint) => {
    const terms = randomUUID();
    await ctx.prisma.topupTermsAcceptance.create({
      data: { id: terms, userId: u.id, termsVersion: 't1', termsText: 'x', locale: 'ar', acceptedAt: now() },
    });
    return ctx.prisma.topupOrder.create({
      data: {
        id: randomUUID(),
        userId: u.id,
        termsAcceptanceId: terms,
        packageId: String(amount),
        coins: amount,
        amountMinor: 1250,
        currency: 'USD',
        paymentMethodTypes: ['card'],
        status: 'PENDING',
        createdAt: now(),
      },
    });
  };
  /** Credited as the Stripe webhook does (`creditOrderIn`). */
  const cardTopup = async (u: TestUser, amount: bigint) => {
    const order = await topupOrder(u, amount);
    const ok = await ctx.prisma.$transaction((tx) =>
      creditOrderIn(tx, order, now(), rules(), `evt_${order.id}`, 'card'),
    );
    expect(ok).toBe(true);
    return order.id;
  };
  /** An ACTIVE recharge agent (EG mobile wallet) with `stock` coins. */
  const activeAgent = async (stock = 60_000_000n): Promise<TestUser & { code: string }> => {
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
      topUpIn(tx, user.id, stock, (stock * 1200n + 500_000n) / 1_000_000n, null, AGENT_RULES, now()),
    );
    return { ...user, code: r.code! };
  };
  const agentSale = async (agent: TestUser, buyer: TestUser, amount: number) => {
    const res = await ctx.http
      .post('/api/v1/me/recharge-agent/sales')
      .set(auth(agent))
      .set('Idempotency-Key', randomUUID())
      .send({ buyer: buyer.username, coins: amount });
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
  const rechargeOrder = async (buyer: TestUser, agent: TestUser & { code: string }, amount: number) => {
    const act = (u: TestUser, id: string, action: string, body: object = {}) =>
      ctx.http.post(`/api/v1/recharge-orders/${id}/${action}`).set(auth(u)).send(body);
    const res = await ctx.http
      .post('/api/v1/recharge-orders')
      .set(auth(buyer))
      .set('Idempotency-Key', randomUUID())
      .send({ agentCode: agent.code, country: 'EG', coins: amount, paymentType: 'MOBILE_WALLET' });
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
  /** A store purchase verified and credited (`recordPurchaseIn`). */
  const storePurchase = async (u: TestUser, amount: bigint) => {
    const product = await withMigrationClient((db) =>
      db.iapProduct.create({
        data: { platform: 'GOOGLE_PLAY', productId: `coins_${randomUUID().slice(0, 8)}`, coins: amount },
      }),
    );
    const tx = `GPA.${randomUUID()}`;
    const rec = await ctx.prisma.$transaction((t) =>
      recordPurchaseIn(
        t,
        {
          userId: u.id,
          platform: 'GOOGLE_PLAY',
          product,
          transactionId: tx,
          originalTransactionId: null,
          purchaseToken: `tok-${tx}`,
          purchaseTokenHash: randomUUID().replace(/-/g, '').padEnd(64, '0'),
          environment: 'PRODUCTION',
          deviceHash: null,
          priceMilli: 12_500n,
          currency: 'USD',
          purchasedAt: now(),
          consent: { version: 'c1', shareData: false, locale: 'ar' },
          reject: null,
          limitExceeded: false,
        },
        rules(),
        now(),
      ),
    );
    return rec.purchase.id;
  };

  // ---- VIP ---------------------------------------------------------------------------------------------------
  const buyPoints = (u: TestUser, tier: string, pricePoints: number, key: string = randomUUID()) =>
    ctx.http
      .post('/api/v1/me/vip/purchases')
      .set(auth(u))
      .set('Idempotency-Key', key)
      .send({ tierId: tiers[tier] ?? tier, payWith: 'POINTS', pricePoints });
  const myVip = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me/vip').set(auth(u)).set('Accept-Language', 'en');
    expect(res.status).toBe(200);
    expectContract(res, 'getMyVip');
    return res.body as {
      membership: { tier: { code: string }; expiresAt: string } | null;
      rechargePoints: number;
      renewal?: { pricePoints: number | null; priceCoins: number };
    };
  };
  const addTier = async (
    code: string,
    priceCoins: number,
    pointsPrice: number | null,
    extra: object = {},
  ) => {
    const res = await p.send(owner, 'post', '/admin/vip/tiers', {
      code,
      nameAr: `في آي بي ${code.slice(-1)}`,
      nameEn: `VIP ${code.slice(-1)}`,
      color: '#C9A227',
      priceCoins,
      pointsPrice,
      durationDays: 30,
      enabled: true,
      reason: 'owner D370',
      ...extra,
    });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'createAdminVipTier');
    expect(res.body.pointsPrice).toBe(pointsPrice);
    tiers[code] = res.body.id as string;
  };
  const code = (res: { body: unknown }) => (res.body as { error?: { code: string } }).error?.code;
  const issue = (res: { body: unknown }) =>
    (res.body as { error?: { details?: { issue: string }[] } }).error?.details?.[0]?.issue;

  beforeAll(async () => {
    png = await sharp({ create: { width: 64, height: 48, channels: 3, background: '#c33' } })
      .png()
      .toBuffer();
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp(
      {
        ADMIN_TOTP_KEY: ADMIN_KEY,
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        ADMIN_SESSION_MAX_SECONDS: '604800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '100000/900',
        RATE_LIMIT_RECHARGE_ORDER_USER: '10000/900',
        RATE_LIMIT_RECHARGE_ORDER_ACTION_USER: '10000/900',
        MEDIA_UPLOADS_ENABLED: 'true',
        S3_BUCKET: 'kabso-media-test',
        S3_ACCESS_KEY_ID: 'test',
        S3_SECRET_ACCESS_KEY: 'test',
        MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
        RECHARGE_AGENT_SWEEP_INTERVAL_SECONDS: '0',
      },
      [{ token: OBJECT_STORAGE, value: storage }],
    );
    owner = await p.makeAdmin(['OWNER']);
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('the migration priced the seeded VIP 1 at 2 000 000 points (the owner table, by code)', async () => {
    const u = await signup();
    const res = await ctx.http.get('/api/v1/vip/tiers').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'listVipTiers');
    const vip1 = (res.body.data as { code: string; pricePoints: number; renewPricePoints: number }[]).find(
      (t) => t.code === 'VIP_1',
    );
    expect(vip1).toMatchObject({ pricePoints: 2_000_000, renewPricePoints: 1_700_000 });
    // Start the VIP part from the panel's own tiers.
    await withMigrationClient(async (db) => {
      await db.vipPurchase.deleteMany({});
      await db.vipMembership.deleteMany({});
      await db.vipTierPerk.deleteMany({});
      await db.vipTier.deleteMany({});
    });
  });

  it('a website top-up earns one point per coin, once; a fresh account has 0 and an empty history', async () => {
    const u = await signup();
    expect(await points(u)).toMatchObject({
      balance: 0,
      data: [],
      page: { hasMore: false, nextCursor: null },
    });
    const orderId = await cardTopup(u, 1_000_000n);
    expect(await balance(u)).toBe(1_000_000);
    // A second credit of the same order changes nothing (the order says credited; the ledger is unique).
    const order = await ctx.prisma.topupOrder.findUniqueOrThrow({ where: { id: orderId } });
    expect(
      await ctx.prisma.$transaction((tx) => creditOrderIn(tx, order, now(), rules(), 'evt_again', 'card')),
    ).toBe(false);
    const page = await points(u);
    expect(page.balance).toBe(1_000_000);
    expect(page.data).toEqual([
      expect.objectContaining({ reason: 'RECHARGE_WEB', delta: 1_000_000, balanceAfter: 1_000_000 }),
    ]);
    // The reference is never returned.
    expect(Object.keys(page.data[0]!)).toEqual(['id', 'reason', 'delta', 'balanceAfter', 'createdAt']);
  });

  it('an agent sale and a recharge order earn for the BUYER, never the agent; a store purchase earns too', async () => {
    const agent = await activeAgent();
    const buyer = await signup();
    await agentSale(agent, buyer, 2_000_000);
    expect(await balance(buyer)).toBe(2_000_000);
    await rechargeOrder(buyer, agent, 3_000_000);
    expect(await balance(buyer)).toBe(5_000_000);
    await storePurchase(buyer, 400_000n);
    const page = await points(buyer);
    expect(page.balance).toBe(5_400_000);
    expect(page.data.map((e) => e.reason)).toEqual(['RECHARGE_STORE', 'RECHARGE_AGENT', 'RECHARGE_AGENT']);
    // The agent's stock purchase and sales earned the agent nothing.
    expect(await balance(agent)).toBe(0);
    expect(await ctx.prisma.rechargePointsEntry.count({ where: { userId: agent.id } })).toBe(0);
  });

  it('other credits earn nothing: admin grants, task / check-in / event rewards, VIP daily coins, gifts back', async () => {
    const u = await signup();
    await ctx.prisma.$transaction(async (tx) => {
      for (const reason of [
        'ADMIN_GRANT',
        'TASK_REWARD',
        'CHECK_IN_REWARD',
        'EVENT_PRIZE',
        'VIP_DAILY_COINS',
      ] as const) {
        await creditIn(tx, u.id, 5_000_000n, reason, randomUUID());
      }
    });
    expect(await coins(u)).toBe(25_000_000);
    expect(await points(u)).toMatchObject({ balance: 0, data: [] });
  });

  it('redeem: NEW, RENEW (the renewal discount), UPGRADE (full points price); coins untouched; audited', async () => {
    await addTier('VIP_1', 1_000_000, 2_000_000);
    await addTier('VIP_2', 2_000_000, 3_500_000);
    await addTier('VIP_3', 3_000_000, null);
    // A tier without a renewal discount (the concurrent-renewal case below).
    await addTier('VIP_4', 4_000_000, 2_000_000, { renewalDiscountPercent: 0 });
    const u = await signup();
    await cardTopup(u, 8_000_000n);
    const before = await coins(u);

    const fresh = await buyPoints(u, 'VIP_1', 2_000_000);
    expect(fresh.status, JSON.stringify(fresh.body)).toBe(201);
    expectContract(fresh, 'buyVip');
    expect(fresh.body).toMatchObject({
      kind: 'NEW',
      payWith: 'POINTS',
      priceCoins: 0,
      listPriceCoins: 1_000_000,
      pricePoints: 2_000_000,
      listPricePoints: 2_000_000,
      discountPercent: 0,
      rechargePoints: 6_000_000,
      coins: before,
    });
    const mine = await myVip(u);
    expect(mine.rechargePoints).toBe(6_000_000);
    expect(mine.renewal).toMatchObject({ priceCoins: 850_000, pricePoints: 1_700_000 });

    // RENEW: the same 15 % off the points price (CTO choice, §10.163.3).
    const renew = await buyPoints(u, 'VIP_1', 1_700_000);
    expect(renew.status, JSON.stringify(renew.body)).toBe(201);
    expect(renew.body).toMatchObject({ kind: 'RENEW', pricePoints: 1_700_000, discountPercent: 15 });
    expect(renew.body.rechargePoints).toBe(4_300_000);

    // UPGRADE: the higher tier's FULL points price.
    const up = await buyPoints(u, 'VIP_2', 3_500_000);
    expect(up.status, JSON.stringify(up.body)).toBe(201);
    expect(up.body).toMatchObject({ kind: 'UPGRADE', pricePoints: 3_500_000, discountPercent: 0 });
    expect(up.body.rechargePoints).toBe(800_000);
    expect((await myVip(u)).membership?.tier.code).toBe('VIP_2');

    // A tier with no points price cannot be redeemed.
    const none = await buyPoints(u, 'VIP_3', 1);
    expect(none.status).toBe(409);
    expect([code(none), issue(none)]).toEqual(['VIP_UNAVAILABLE', 'no_points_price']);

    expect(await coins(u)).toBe(before);
    const ledger = await points(u);
    expect(ledger.data.filter((e) => e.reason === 'VIP_REDEEM').map((e) => e.delta)).toEqual([
      -3_500_000, -1_700_000, -2_000_000,
    ]);
    const rows = await ctx.prisma.vipPurchase.findMany({ where: { userId: u.id } });
    // (The test clock does not move between the purchases: compare by price.)
    const shown = rows.map((r) => [r.payWith, Number(r.priceCoins), Number(r.pricePoints)] as const);
    expect(shown.sort((a, b) => b[2] - a[2])).toEqual([
      ['POINTS', 0, 3_500_000],
      ['POINTS', 0, 2_000_000],
      ['POINTS', 0, 1_700_000],
    ]);
    const audit = await ctx.prisma.auditLog.findMany({
      where: { action: 'vip.purchase', actorUserId: u.id },
    });
    expect(audit.map((a) => (a.metadata as { payWith: string }).payWith)).toEqual([
      'POINTS',
      'POINTS',
      'POINTS',
    ]);
  });

  it('insufficient points, a changed price, the body rules; a coin purchase still works as before', async () => {
    const u = await signup();
    await cardTopup(u, 1_999_999n);
    const short = await buyPoints(u, 'VIP_1', 2_000_000);
    expect(short.status).toBe(409);
    expect(code(short)).toBe('INSUFFICIENT_RECHARGE_POINTS');
    const changed = await buyPoints(u, 'VIP_1', 1_999_999);
    expect(changed.status).toBe(409);
    expect(code(changed)).toBe('VIP_PRICE_CHANGED');
    expect(await balance(u)).toBe(1_999_999);
    expect(await ctx.prisma.vipPurchase.count({ where: { userId: u.id } })).toBe(0);

    const send = (body: object) =>
      ctx.http.post('/api/v1/me/vip/purchases').set(auth(u)).set('Idempotency-Key', randomUUID()).send(body);
    const both = await send({
      tierId: tiers.VIP_1,
      payWith: 'POINTS',
      pricePoints: 2_000_000,
      priceCoins: 1,
    });
    expect(both.status).toBe(400);
    expect(both.body.error.details).toEqual([{ field: 'priceCoins', issue: 'not_allowed' }]);
    const missing = await send({ tierId: tiers.VIP_1, payWith: 'POINTS' });
    expect(missing.status).toBe(400);
    expect(missing.body.error.details).toEqual([{ field: 'pricePoints', issue: 'required' }]);

    // An older app: no payWith, coins as before (the coins are the card top-up's 1 999 999).
    const old = await send({ tierId: tiers.VIP_1, priceCoins: 1_000_000 });
    expect(old.status, JSON.stringify(old.body)).toBe(201);
    expect(old.body).toMatchObject({
      payWith: 'COINS',
      priceCoins: 1_000_000,
      pricePoints: null,
      rechargePoints: 1_999_999,
    });
  });

  it('an Idempotency-Key retry answers 200 with the first result and takes nothing again; another body → 409', async () => {
    const u = await signup();
    await cardTopup(u, 3_000_000n);
    const key = randomUUID();
    const first = await buyPoints(u, 'VIP_1', 2_000_000, key);
    expect(first.status).toBe(201);
    const again = await buyPoints(u, 'VIP_1', 2_000_000, key);
    expect(again.status).toBe(200);
    expectContract(again, 'buyVip');
    expect(again.body).toEqual(first.body);
    expect(await balance(u)).toBe(1_000_000);
    const other = await buyPoints(u, 'VIP_1', 1_700_000, key);
    expect(other.status).toBe(409);
    expect(code(other)).toBe('IDEMPOTENCY_CONFLICT');
  });

  it('two redemptions at once with points for one: exactly one wins, the balance never goes below 0', async () => {
    const u = await signup();
    await cardTopup(u, 2_500_000n);
    const [a, b] = await Promise.all([buyPoints(u, 'VIP_1', 2_000_000), buyPoints(u, 'VIP_2', 3_500_000)]);
    const statuses = [a.status, b.status].sort();
    // One buys; the other is refused (short of points, or a downgrade / no points after the first).
    expect(statuses[0]).toBe(201);
    expect(statuses[1]).toBe(409);
    const twin = await signup();
    await cardTopup(twin, 3_000_000n);
    // NEW then RENEW of VIP 4 (no discount: both cost 2 000 000) — points for one only.
    const pair = await Promise.all([
      buyPoints(twin, 'VIP_4', 2_000_000),
      buyPoints(twin, 'VIP_4', 2_000_000),
    ]);
    expect(pair.map((r) => r.status).sort()).toEqual([201, 409]);
    expect(code(pair.find((r) => r.status === 409)!)).toBe('INSUFFICIENT_RECHARGE_POINTS');
    expect(await balance(twin)).toBe(1_000_000);
  });

  it('a reversed top-up takes its points back (below 0: nothing redeemable); a won dispute gives them back', async () => {
    const u = await signup();
    const orderId = await cardTopup(u, 2_000_000n);
    expect((await buyPoints(u, 'VIP_1', 2_000_000)).status).toBe(201);
    expect(await balance(u)).toBe(0);
    // Refunded in full: the order's coins and points both go (the balance below 0).
    await ctx.prisma.topupOrder.update({ where: { id: orderId }, data: { refundedMinor: 1250 } });
    await ctx.prisma.$transaction(async (tx) => {
      const order = await tx.topupOrder.findUniqueOrThrow({ where: { id: orderId } });
      await reconcileOrderIn(tx, order, 'evt_refund_1', now());
    });
    expect(await balance(u)).toBe(-2_000_000);
    await cardTopup(u, 3_000_000n);
    expect(await balance(u)).toBe(1_000_000);
    const short = await buyPoints(u, 'VIP_2', 3_500_000);
    expect(code(short)).toBe('INSUFFICIENT_RECHARGE_POINTS');
    // The refund taken back again (as a won dispute restores): a positive REVERSAL.
    await ctx.prisma.topupOrder.update({ where: { id: orderId }, data: { refundedMinor: 0 } });
    await ctx.prisma.$transaction(async (tx) => {
      const order = await tx.topupOrder.findUniqueOrThrow({ where: { id: orderId } });
      await reconcileOrderIn(tx, order, 'evt_restore_1', now());
    });
    expect(await balance(u)).toBe(3_000_000);
    const reversals = (await points(u)).data.filter((e) => e.reason === 'REVERSAL').map((e) => e.delta);
    expect(reversals).toEqual([2_000_000, -2_000_000]);
  });

  it('a refunded store purchase takes its points back; a recharge from before the points takes nothing', async () => {
    const u = await signup();
    const purchaseId = await storePurchase(u, 700_000n);
    expect(await balance(u)).toBe(700_000);
    const out = await ctx.prisma.$transaction((tx) =>
      refundPurchaseIn(
        tx,
        purchaseId,
        { source: 'GOOGLE_VOIDED', refundedAt: now(), reasonText: 'test', ban: false, detail: {} },
        async () => false,
        now(),
      ),
    );
    expect(out.applied).toBe(true);
    expect(await balance(u)).toBe(0);
    // An order credited without points (as before the deploy): its reversal moves no points.
    const old = await signup();
    const order = await topupOrder(old, 1_000_000n);
    await withMigrationClient((db) =>
      db.$transaction(async (tx) => {
        await creditIn(tx, old.id, 1_000_000n, 'CARD_TOPUP', order.id);
        await tx.topupOrder.update({
          where: { id: order.id },
          data: { status: 'PAID', creditedAt: now(), refundedMinor: 1250 },
        });
      }),
    );
    await ctx.prisma.$transaction(async (tx) => {
      const o = await tx.topupOrder.findUniqueOrThrow({ where: { id: order.id } });
      await reconcileOrderIn(tx, o, 'evt_old_refund', now());
    });
    expect(await points(old)).toMatchObject({ balance: 0, data: [] });
    expect(await coins(old)).toBe(0);
  });

  it('the history pages with a cursor bound to the caller', async () => {
    const u = await signup();
    for (let i = 0; i < 3; i++) await cardTopup(u, 100_000n);
    const first = await ctx.http.get('/api/v1/me/recharge-points?limit=2').set(auth(u));
    expect(first.status).toBe(200);
    expectContract(first, 'getMyRechargePoints');
    expect(first.body.data).toHaveLength(2);
    expect(first.body.page.hasMore).toBe(true);
    const next = await ctx.http
      .get(
        `/api/v1/me/recharge-points?limit=2&cursor=${encodeURIComponent(first.body.page.nextCursor as string)}`,
      )
      .set(auth(u));
    expect(next.status).toBe(200);
    expect(next.body.data).toHaveLength(1);
    expect(next.body.page).toEqual({ hasMore: false, nextCursor: null });
    const other = await signup();
    const stolen = await ctx.http
      .get(`/api/v1/me/recharge-points?cursor=${encodeURIComponent(first.body.page.nextCursor as string)}`)
      .set(auth(other));
    expect(stolen.status).toBe(400);
  });

  it('the panel: points price in the tier form (audited), balance and ledger on the user page, the adjustment', async () => {
    const patch = await p.send(owner, 'patch', `/admin/vip/tiers/${tiers.VIP_3}`, {
      pointsPrice: 6_000_000,
      reason: 'owner table',
    });
    expect(patch.status, JSON.stringify(patch.body)).toBe(200);
    expectContract(patch, 'updateAdminVipTier');
    expect(patch.body.pointsPrice).toBe(6_000_000);
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'vip.tier.update', targetId: tiers.VIP_3 },
      orderBy: { createdAt: 'desc' },
    });
    expect(audit.metadata).toMatchObject({ reason: 'owner table' });
    const cleared = await p.send(owner, 'patch', `/admin/vip/tiers/${tiers.VIP_3}`, {
      pointsPrice: null,
      reason: 'off',
    });
    expect(cleared.body.pointsPrice).toBeNull();
    const list = await p.send(owner, 'get', '/admin/vip/tiers');
    expectContract(list, 'listAdminVipTiers');

    const u = await signup();
    await cardTopup(u, 500_000n);
    const detail = await p.send(owner, 'get', `/admin/users/${u.id}`);
    expect(detail.status).toBe(200);
    expectContract(detail, 'getAdminUser');
    expect(detail.body.balances.rechargePoints).toBe(500_000);
    expect(detail.body.ledger.rechargePoints).toHaveLength(1);
    const ledger = await p.send(owner, 'get', `/admin/users/${u.id}/ledger?kind=recharge_points`);
    expect(ledger.status).toBe(200);
    expectContract(ledger, 'listAdminUserLedger');
    expect(ledger.body).toMatchObject({ total: 1, data: [{ reason: 'RECHARGE_WEB', delta: 500_000 }] });

    const adjust = (a: Admin, body: object) =>
      p.send(a, 'post', `/admin/users/${u.id}/recharge-points/adjustments`, {
        reason: 'support case 17',
        totpCode: p.nextCode(a.secret),
        ...body,
      });
    const support = await p.makeAdmin(['SUPPORT']);
    expect((await adjust(support, { direction: 'CREDIT', amount: '1' })).status).toBe(403);
    const finance = await p.makeAdmin(['FINANCE']);
    const credit = await adjust(finance, { direction: 'CREDIT', amount: '250000' });
    expect(credit.status, JSON.stringify(credit.body)).toBe(200);
    expectContract(credit, 'adjustAdminUserRechargePoints');
    expect(credit.body).toEqual({ delta: 250_000, before: 500_000, after: 750_000 });
    const below = await adjust(finance, { direction: 'DEBIT', amount: '800000' });
    expect(below.status).toBe(409);
    expect([code(below), issue(below)]).toEqual(['ADMIN_ACTION_REFUSED', 'below_zero']);
    expect(
      (await adjust(finance, { direction: 'DEBIT', amount: '800000', allowNegative: true })).status,
    ).toBe(403);
    const neg = await adjust(owner, { direction: 'DEBIT', amount: '800000', allowNegative: true });
    expect(neg.status, JSON.stringify(neg.body)).toBe(200);
    expect(neg.body.after).toBe(-50_000);
    const wrongCode = await p.send(owner, 'post', `/admin/users/${u.id}/recharge-points/adjustments`, {
      direction: 'CREDIT',
      amount: '1',
      reason: 'x',
      totpCode: '000000',
    });
    expect(wrongCode.status).not.toBe(200);
    const rows = await ctx.prisma.auditLog.findMany({
      where: { action: 'recharge_points.adjust', targetId: u.id },
      orderBy: { createdAt: 'asc' },
    });
    expect(rows.map((r) => r.metadata)).toEqual([
      expect.objectContaining({ delta: 250_000, before: 500_000, after: 750_000, reason: 'support case 17' }),
      expect.objectContaining({ delta: -800_000, before: 750_000, after: -50_000, allowNegative: true }),
    ]);
    expect(rows.map((r) => r.actorUserId)).toEqual([finance.id, owner.id]);
    expect((await points(u)).data.map((e) => e.reason)).toEqual([
      'ADMIN_ADJUST',
      'ADMIN_ADJUST',
      'RECHARGE_WEB',
    ]);
  });

  it('the ledger is append-only for the runtime role', async () => {
    const row = await ctx.prisma.rechargePointsEntry.findFirstOrThrow({});
    await expect(
      ctx.prisma.rechargePointsEntry.update({ where: { id: row.id }, data: { delta: 1n } }),
    ).rejects.toThrow(/permission denied/i);
    await expect(ctx.prisma.rechargePointsEntry.delete({ where: { id: row.id } })).rejects.toThrow(
      /permission denied/i,
    );
  });
});
