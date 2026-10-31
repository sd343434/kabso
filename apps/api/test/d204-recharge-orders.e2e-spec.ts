/**
 * D204 (owner 2026-10-31; contract v1.69-social, CONVENTIONS §10.64): recharge orders with escrow «طلبات الشحن» — the
 * server's price (retail USD and the admin's exchange rate), the order's own chat with private pictures, the payment
 * details that freeze the agent's coins, the protection notice, «قمت بالإرسال» with the transfer's screenshot, the
 * 15-minute wait, «استلمت» / «نزاع», cancellations, expiries, employees' hours, the panel's «نزاعات الشحن» (view,
 * «الإدارة» lines, the decision with the code again) and the races between confirm, dispute, cancel, expiry and the
 * decision (exactly one wins; the coins are conserved). End to end against PostgreSQL + Redis.
 */
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import type request from 'supertest';
import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { topUpIn } from '../src/modules/recharge/recharge-core.js';
import { resolveDisputeIn, setExchangeRateIn } from '../src/modules/recharge/recharge-order-core.js';
import {
  formatMinor,
  localMinorOf,
  parseRateMicro,
  usdMinorOf,
  retailMicroPerMillion,
} from '../src/modules/recharge/recharge-order-rules.js';
import { RechargeOrdersService } from '../src/modules/recharge/recharge-orders.service.js';
import { localClock } from '../src/modules/recharge/recharge-rules.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, openapi } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

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

const TIERS = [{ minCoins: 0, minorPerMillion: 1200 }];
const RULES = { activationMinCoins: 30_000_000, priceTiers: TIERS, currency: 'USD' };
const COOKIE = '__Host-kabso_admin';
const MIN = 60_000;

describe('D204 contract coverage', () => {
  it('openapi v1.69-social declares the order operations, the panel ones and the new values', () => {
    const paths = openapi.paths as Record<string, Record<string, { operationId?: string }>>;
    const ops = Object.values(paths).flatMap((p) => Object.values(p).map((o) => o.operationId));
    for (const op of [
      'quoteRechargeOrder',
      'createRechargeOrder',
      'listMyRechargeOrders',
      'getRechargeOrder',
      'listRechargeOrderMessages',
      'postRechargeOrderMessage',
      'getRechargeOrderMessageImage',
      'sendRechargeOrderPaymentDetails',
      'acknowledgeRechargeOrderNotice',
      'markRechargeOrderPaid',
      'confirmRechargeOrder',
      'disputeRechargeOrder',
      'cancelRechargeOrder',
      'listAdminRechargeDisputes',
      'getAdminRechargeOrder',
      'postAdminRechargeOrderMessage',
      'getAdminRechargeOrderMessageImage',
      'resolveAdminRechargeDispute',
      'listAdminRechargeExchangeRates',
      'setAdminRechargeExchangeRate',
      'clearAdminRechargeExchangeRate',
    ]) {
      expect(ops).toContain(op);
    }
    const schemas = (openapi.components as { schemas: Record<string, Record<string, unknown>> }).schemas;
    expect((schemas.MediaKind as { enum: string[] }).enum).toContain('RECHARGE_ORDER_IMAGE');
    expect((schemas.NotificationType as { enum: string[] }).enum).toContain('RECHARGE_ORDER_UPDATE');
    expect((schemas.WalletLedgerReason as { enum: string[] }).enum).toContain('RECHARGE_ORDER');
  });

  it('prices: retail $12.50 per 1 000 000 in cents rounded half up, local at the rate in its decimals', () => {
    const per = retailMicroPerMillion(12.5);
    expect(usdMinorOf(1_000_000n, per)).toBe(1250n);
    expect(usdMinorOf(10_000n, per)).toBe(13n); // 12.5 cents → 13
    expect(usdMinorOf(3_333_333n, per)).toBe(4167n);
    const egp = parseRateMicro('50.5')!;
    expect(egp).toBe(50_500_000n);
    expect(formatMinor(localMinorOf(1250n, egp, 2), 2)).toBe('631.25');
    expect(formatMinor(localMinorOf(1250n, parseRateMicro('0.307')!, 3), 3)).toBe('3.838'); // KWD
    expect(formatMinor(localMinorOf(1250n, parseRateMicro('1310')!, 0), 0)).toBe('16375'); // IQD
    expect(parseRateMicro('0')).toBeNull();
    expect(parseRateMicro('1.1234567')).toBeNull();
  });
});

describe('D204 recharge orders', { timeout: 600_000 }, () => {
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  let png: Buffer;
  let clock = Date.now();
  const advance = (ms: number) => {
    clock += ms;
    vi.setSystemTime(clock);
  };
  const now = () => new Date(clock);

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: payload.email,
      password: payload.password,
      token: res.body.tokens.accessToken as string,
    };
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

  /** An ACTIVE agent serving EG (mobile wallet, bank) and SA (bank), activated with `coins`. */
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
        countries: ['EG', 'SA'],
        locations: [{ country: 'EG', cities: ['Cairo'] }],
        paymentTypes: { EG: ['MOBILE_WALLET', 'BANK_TRANSFER'], SA: ['BANK_TRANSFER'] },
      },
    });
    const r = await ctx.prisma.$transaction((tx) =>
      topUpIn(tx, user.id, coins, (coins * 1200n + 500_000n) / 1_000_000n, null, RULES, now()),
    );
    return { ...user, code: r.code! };
  };

  const stockOf = async (agentId: string) =>
    (await ctx.prisma.rechargeAgent.findUniqueOrThrow({ where: { userId: agentId } })).stockCoins;
  const coinsOf = async (u: TestUser) =>
    (await ctx.prisma.wallet.findUnique({ where: { userId: u.id } }))?.coins ?? 0n;
  /** The stock ledger adds up to the stock (no coin made or lost). */
  const ledgerMatches = async (agentId: string) => {
    const rows = await ctx.prisma.rechargeStockEntry.findMany({ where: { agentUserId: agentId } });
    const sum = rows.reduce((s, r) => s + r.delta, 0n);
    expect(sum).toBe(await stockOf(agentId));
  };

  const create = (
    buyer: TestUser,
    agent: { code: string },
    body: Record<string, unknown> = {},
    key = randomUUID(),
  ) =>
    ctx.http
      .post('/api/v1/recharge-orders')
      .set(auth(buyer))
      .set('Idempotency-Key', key)
      .send({
        agentCode: agent.code,
        country: 'EG',
        coins: 1_000_000,
        paymentType: 'MOBILE_WALLET',
        ...body,
      });
  const act = (u: TestUser, id: string, action: string, body: object = {}) =>
    ctx.http.post(`/api/v1/recharge-orders/${id}/${action}`).set(auth(u)).send(body);
  const getOrder = (u: TestUser, id: string) => ctx.http.get(`/api/v1/recharge-orders/${id}`).set(auth(u));
  const details = (u: TestUser, id: string) =>
    act(u, id, 'payment-details', {
      method: 'MOBILE_WALLET',
      details: 'Vodafone Cash 0100 000 0000\nباسم محمد',
    });

  /** An order taken to `stage` (REQUESTED, AWAITING_PAYMENT, ACKED, PAID). */
  const orderAt = async (
    buyer: TestUser,
    agent: TestUser & { code: string },
    stage: 'REQUESTED' | 'AWAITING_PAYMENT' | 'ACKED' | 'PAID',
    coins = 1_000_000,
  ): Promise<string> => {
    const res = await create(buyer, agent, { coins });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const id = res.body.id as string;
    if (stage === 'REQUESTED') return id;
    expect((await details(agent, id)).status).toBe(200);
    if (stage === 'AWAITING_PAYMENT') return id;
    expect((await act(buyer, id, 'notice-ack')).status).toBe(200);
    if (stage === 'ACKED') return id;
    const paid = await act(buyer, id, 'paid', { proofUploadId: await upload(buyer) });
    expect(paid.status, JSON.stringify(paid.body)).toBe(200);
    return id;
  };

  // ---- admin panel helpers (as in d191) ----
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
  const makeAdmin = async (roles: string[]): Promise<Admin> => {
    const p = await signup();
    await withMigrationClient(async (db) => {
      for (const role of roles) await db.$transaction((tx) => grantRoleIn(tx, p.email, role as never));
    });
    const res = await ctx.http
      .post('/api/v1/admin/auth/login')
      .send({ email: p.email, password: p.password });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    const pending = cookieOf(res);
    const enrol = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment')
      .set('Cookie', pending)
      .set('X-CSRF-Token', res.body.csrfToken as string);
    const secret = enrol.body.secret as string;
    const confirm = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment/confirm')
      .set('Cookie', pending)
      .set('X-CSRF-Token', res.body.csrfToken as string)
      .send({ code: nextCode(secret) });
    expect(confirm.status, JSON.stringify(confirm.body)).toBe(200);
    return { ...p, secret, cookie: cookieOf(confirm), csrf: confirm.body.session.csrfToken as string };
  };
  const relogin = async (a: Admin) => {
    const res = await ctx.http
      .post('/api/v1/admin/auth/login')
      .send({ email: a.email, password: a.password });
    const v = await ctx.http
      .post('/api/v1/admin/auth/totp/verify')
      .set('Cookie', cookieOf(res))
      .set('X-CSRF-Token', res.body.csrfToken as string)
      .send({ code: nextCode(a.secret) });
    expect(v.status, JSON.stringify(v.body)).toBe(200);
    a.cookie = cookieOf(v);
    a.csrf = v.body.csrfToken as string;
  };
  const aget = (a: Admin, path: string) => ctx.http.get(`/api/v1${path}`).set('Cookie', a.cookie);
  const apost = (a: Admin, path: string, body: object = {}) =>
    ctx.http.post(`/api/v1${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf).send(body);

  const badges = () => ctx.config.recharge.badges;

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: clock });
    png = await sharp({ create: { width: 64, height: 48, channels: 3, background: '#c33' } })
      .png()
      .toBuffer();
    ctx = await createTestApp(
      {
        ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
        // The clock moves days forward: the bearer tokens must outlive it.
        JWT_ACCESS_TTL_SECONDS: '2592000',
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        ADMIN_SESSION_MAX_SECONDS: '86400',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '10000/900',
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
  });

  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  afterEach(() => {
    vi.setSystemTime(clock);
  });

  it('quotes in USD, and in the local currency once an admin sets a rate (audited, CLI rule)', async () => {
    const agent = await activeAgent();
    const buyer = await signup();
    const q = (country: string, coins: number) =>
      ctx.http
        .get(`/api/v1/recharge-orders/quote?agentCode=${agent.code}&country=${country}&coins=${coins}`)
        .set(auth(buyer));
    let res = await q('EG', 1_000_000);
    expectContract(res, 'quoteRechargeOrder');
    expect(res.status).toBe(200);
    expect(res.body.price).toEqual({ usdMinor: 1250, usd: '12.50', local: null });
    expect(res.body.paymentMethodTypes).toEqual(['MOBILE_WALLET', 'BANK_TRANSFER']);
    await ctx.prisma.$transaction((tx) =>
      setExchangeRateIn(tx, 'EG', { currency: 'EGP', rateMicro: 50_500_000n, digits: 2 }, 'today', now()),
    );
    res = await q('EG', 1_000_000);
    expect(res.body.price.local).toEqual({
      currency: 'EGP',
      minor: 63_125,
      digits: 2,
      amount: '631.25',
      rate: '50.5',
    });
    // The agent's wholesale tiers are not the buyer's price.
    expect(res.body.price.usdMinor).not.toBe(1200);
    expect((await q('SA', 1_000_000)).body.price.local).toBeNull();
    expect((await q('AE', 1_000_000)).status).toBe(400); // not served
    expect((await q('EG', 5)).status).toBe(400); // under the minimum
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({ where: { action: 'recharge.rate.set' } });
    expect(audit.metadata).toMatchObject({ before: null, after: { currency: 'EGP' }, via: 'cli' });
  });

  it('runs an order end to end: chat, hold, notice, «قمت بالإرسال», the wait and «استلمت» (idempotent)', async () => {
    const agent = await activeAgent();
    const buyer = await signup();
    const stranger = await signup();
    const key = randomUUID();
    const res = await create(buyer, agent, {}, key);
    expectContract(res, 'createRechargeOrder');
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({
      status: 'REQUESTED',
      viewerRole: 'BUYER',
      coins: 1_000_000,
      heldCoins: 0,
      agentCode: agent.code,
      price: { usdMinor: 1250, usd: '12.50' },
      actions: ['MESSAGE', 'CANCEL'],
    });
    const id = res.body.id as string;
    // The same key again: the same order; a different body: 409.
    const again = await create(buyer, agent, {}, key);
    expect(again.status).toBe(200);
    expect(again.body.id).toBe(id);
    expect((await create(buyer, agent, { coins: 2_000_000 }, key)).status).toBe(409);
    // One open order per pair.
    const second = await create(buyer, agent);
    expect(second.status).toBe(409);
    expect(second.body.error.code).toBe('RECHARGE_ORDER_OPEN_EXISTS');
    // The agent's view and notification.
    const asAgent = await getOrder(agent, id);
    expectContract(asAgent, 'getRechargeOrder');
    expect(asAgent.body.viewerRole).toBe('AGENT');
    expect(asAgent.body.actions).toEqual(['MESSAGE', 'SEND_DETAILS', 'CANCEL']);
    expect((await getOrder(stranger, id)).status).toBe(404);
    const note = await ctx.http.get('/api/v1/notifications').set(auth(agent));
    expectContract(note, 'listNotifications');
    expect(note.body.data[0]).toMatchObject({
      type: 'RECHARGE_ORDER_UPDATE',
      target: {
        type: 'RECHARGE_ORDER',
        id,
        coins: 1_000_000,
        orderEvent: 'CREATED',
        orderStatus: 'REQUESTED',
      },
    });
    // Chat: text and a private picture.
    const msg = await ctx.http
      .post(`/api/v1/recharge-orders/${id}/messages`)
      .set(auth(buyer))
      .send({ text: 'السلام عليكم\nأريد مليون عملة' });
    expectContract(msg, 'postRechargeOrderMessage');
    expect(msg.status).toBe(201);
    expect(msg.body).toMatchObject({ kind: 'TEXT', role: 'BUYER', text: 'السلام عليكم\nأريد مليون عملة' });
    const imageUploadId = await upload(agent);
    const pic = await ctx.http
      .post(`/api/v1/recharge-orders/${id}/messages`)
      .set(auth(agent))
      .send({ imageUploadId });
    expect(pic.status, JSON.stringify(pic.body)).toBe(201);
    expect(pic.body).toMatchObject({ kind: 'IMAGE', role: 'AGENT', hasImage: true });
    const stored = await ctx.prisma.rechargeOrderMessage.findUniqueOrThrow({ where: { id: pic.body.id } });
    expect(stored.imageKey).toBe(`private/recharge-orders/${id}/${pic.body.id}.webp`);
    expect(JSON.stringify(pic.body)).not.toContain('private/');
    const img = await ctx.http
      .get(`/api/v1/recharge-orders/${id}/messages/${pic.body.id}/image`)
      .set(auth(buyer));
    expect(img.status).toBe(200);
    expect(img.headers['content-type']).toBe('image/webp');
    expect(img.headers['cache-control']).toBe('private, no-store');
    expect(
      (await ctx.http.get(`/api/v1/recharge-orders/${id}/messages/${pic.body.id}/image`).set(auth(stranger)))
        .status,
    ).toBe(404);
    // «قمت بالإرسال» before the details: refused.
    expect((await act(buyer, id, 'notice-ack')).status).toBe(409);
    // Details: the coins are frozen now.
    const stockBefore = await stockOf(agent.id);
    const d = await details(agent, id);
    expectContract(d, 'sendRechargeOrderPaymentDetails');
    expect(d.body).toMatchObject({ status: 'AWAITING_PAYMENT', heldCoins: 1_000_000 });
    expect(await stockOf(agent.id)).toBe(stockBefore - 1_000_000n);
    const hold = await ctx.prisma.rechargeStockEntry.findFirstOrThrow({
      where: { agentUserId: agent.id, reason: 'ORDER_HOLD', referenceId: id },
    });
    expect(hold.delta).toBe(-1_000_000n);
    expect((await details(agent, id)).status).toBe(409); // never twice
    const asBuyer = await getOrder(buyer, id);
    expect(asBuyer.body.actions).toEqual(['MESSAGE', 'ACK_NOTICE', 'CANCEL']);
    // The notice first.
    const early = await act(buyer, id, 'paid', { proofUploadId: await upload(buyer) });
    expect(early.status).toBe(409);
    expect(early.body.error.code).toBe('RECHARGE_ORDER_NOTICE_REQUIRED');
    const ack = await act(buyer, id, 'notice-ack');
    expectContract(ack, 'acknowledgeRechargeOrderNotice');
    expect(ack.body).toMatchObject({ noticeAcknowledged: true, actions: ['MESSAGE', 'MARK_PAID', 'CANCEL'] });
    expect((await act(buyer, id, 'notice-ack')).status).toBe(200);
    expect((await act(buyer, id, 'paid', { proofUploadId: randomUUID() })).status).toBe(400);
    const paid = await act(buyer, id, 'paid', { proofUploadId: await upload(buyer) });
    expectContract(paid, 'markRechargeOrderPaid');
    expect(paid.body).toMatchObject({ status: 'PAID', expiresAt: null });
    expect(
      new Date(paid.body.disputeOpensAt as string).getTime() - new Date(paid.body.paidAt as string).getTime(),
    ).toBe(15 * MIN);
    expect(paid.body.actions).toEqual(['MESSAGE']);
    // The buyer's «نزاع» opens after 15 minutes.
    const tooEarly = await act(buyer, id, 'dispute');
    expect(tooEarly.status).toBe(409);
    expect(tooEarly.body.error.code).toBe('RECHARGE_ORDER_DISPUTE_TOO_EARLY');
    expect((await getOrder(agent, id)).body.actions).toEqual(['MESSAGE', 'CONFIRM', 'DISPUTE']);
    // A buyer cannot confirm; the agent can.
    expect((await act(buyer, id, 'confirm')).status).toBe(404);
    expect((await act(buyer, id, 'cancel')).status).toBe(409);
    const before = await coinsOf(buyer);
    const done = await act(agent, id, 'confirm');
    expectContract(done, 'confirmRechargeOrder');
    expect(done.body).toMatchObject({ status: 'COMPLETED', heldCoins: 0 });
    expect(await coinsOf(buyer)).toBe(before + 1_000_000n);
    expect((await act(agent, id, 'confirm')).status).toBe(200);
    expect(await coinsOf(buyer)).toBe(before + 1_000_000n);
    const credits = await ctx.prisma.walletLedgerEntry.findMany({
      where: { userId: buyer.id, reason: 'RECHARGE_ORDER', referenceId: id },
    });
    expect(credits).toHaveLength(1);
    expect(await stockOf(agent.id)).toBe(stockBefore - 1_000_000n);
    await ledgerMatches(agent.id);
    // The chat keeps every step.
    const page = await ctx.http.get(`/api/v1/recharge-orders/${id}/messages`).set(auth(buyer));
    expectContract(page, 'listRechargeOrderMessages');
    const kinds = (page.body.data as { kind: string; event: string | null }[]).reverse();
    expect(kinds.map((m) => m.event ?? m.kind)).toEqual([
      'CREATED',
      'TEXT',
      'IMAGE',
      'PAYMENT_DETAILS',
      'DETAILS_SENT',
      'NOTICE_ACKNOWLEDGED',
      'TRANSFER_PROOF',
      'PAID',
      'COMPLETED',
    ]);
    // Paging with the cursor gives the same lines in the same order.
    const seen: string[] = [];
    let cursor: string | null = null;
    do {
      const q: string = cursor === null ? '' : `&cursor=${encodeURIComponent(cursor)}`;
      const p = await ctx.http.get(`/api/v1/recharge-orders/${id}/messages?limit=4${q}`).set(auth(agent));
      expect(p.status, JSON.stringify(p.body)).toBe(200);
      seen.push(...(p.body.data as { id: string }[]).map((m) => m.id));
      cursor = p.body.page.nextCursor as string | null;
    } while (cursor !== null);
    expect(seen).toEqual((page.body.data as { id: string }[]).map((m) => m.id).reverse());
    const list = await ctx.http.get('/api/v1/recharge-orders?role=agent&state=closed').set(auth(agent));
    expectContract(list, 'listMyRechargeOrders');
    expect((list.body.data as { id: string }[]).map((o) => o.id)).toContain(id);
    const me = await ctx.http.get('/api/v1/me/recharge-agent').set(auth(agent));
    expectContract(me, 'getMyRechargeAgent');
    expect(me.body.agent).toMatchObject({ heldCoins: 0, openOrders: 0 });
    expect(me.body.rules.orders).toMatchObject({ enabled: true, disputeAfterMinutes: 15 });
    // Audited state changes.
    const actions = await ctx.prisma.auditLog.findMany({
      where: { targetId: id },
      orderBy: { createdAt: 'asc' },
    });
    expect(actions.map((a) => a.action)).toEqual([
      'recharge.order.create',
      'recharge.order.details',
      'recharge.order.notice_ack',
      'recharge.order.paid',
      'recharge.order.confirm',
    ]);
  });

  it('refuses orders that break the limits (self, blocked, inactive, type, stock) and frees the pair once closed', async () => {
    const agent = await activeAgent();
    const buyer = await signup();
    expect((await create(agent, agent)).status).toBe(400);
    expect((await create(buyer, agent, { paymentType: 'CASH' })).status).toBe(400);
    expect((await create(buyer, agent, { country: 'AE' })).status).toBe(400);
    expect((await create(buyer, { code: 'coin9999' })).status).toBe(404);
    const big = await create(buyer, agent, { coins: 40_000_000 });
    expect(big.status).toBe(409);
    expect(big.body.error.code).toBe('RECHARGE_STOCK_INSUFFICIENT');
    const blocker = await signup();
    await ctx.prisma.userBlock.create({ data: { blockerId: agent.id, blockedId: blocker.id } });
    expect((await create(blocker, agent)).status).toBe(404);
    // Not enough stock when the details are sent: refused, nothing changes.
    const id = await orderAt(buyer, agent, 'REQUESTED', 20_000_000);
    const other = await signup();
    expect((await create(other, agent, { coins: 20_000_000 })).status).toBe(201);
    const otherId = (await ctx.prisma.rechargeOrder.findFirstOrThrow({ where: { buyerUserId: other.id } }))
      .id;
    expect((await details(agent, otherId)).status).toBe(200);
    const stock = await stockOf(agent.id);
    const refused = await details(agent, id);
    expect(refused.status).toBe(409);
    expect(refused.body.error.code).toBe('RECHARGE_STOCK_INSUFFICIENT');
    expect(await stockOf(agent.id)).toBe(stock);
    expect((await getOrder(buyer, id)).body).toMatchObject({ status: 'REQUESTED', heldCoins: 0 });
    // Cancelled: the pair is free again.
    expect((await act(buyer, id, 'cancel', { reason: 'غيّرت رأيي' })).body.status).toBe('CANCELLED');
    expect((await create(buyer, agent)).status).toBe(201);
    // A suspended agent cannot be ordered from.
    await ctx.prisma.rechargeAgent.update({
      where: { userId: agent.id },
      data: { status: 'SUSPENDED', suspendedAt: now() },
    });
    const fresh = await signup();
    expect((await create(fresh, agent)).status).toBe(404);
    await ledgerMatches(agent.id);
  });

  it('cancels: the agent before the details, the buyer before PAID (the hold goes back)', async () => {
    const agent = await activeAgent();
    const b1 = await signup();
    const b2 = await signup();
    const start = await stockOf(agent.id);
    const r = await orderAt(b1, agent, 'REQUESTED');
    const c = await act(agent, r, 'cancel', { reason: 'لا يتوفر' });
    expectContract(c, 'cancelRechargeOrder');
    expect(c.body).toMatchObject({ status: 'CANCELLED', closeReason: 'لا يتوفر' });
    const a = await orderAt(b2, agent, 'AWAITING_PAYMENT');
    expect(await stockOf(agent.id)).toBe(start - 1_000_000n);
    expect((await act(agent, a, 'cancel')).status).toBe(409); // the agent: only before the details
    expect((await act(b2, a, 'cancel')).body.status).toBe('CANCELLED');
    expect(await stockOf(agent.id)).toBe(start);
    const release = await ctx.prisma.rechargeStockEntry.findFirstOrThrow({
      where: { agentUserId: agent.id, reason: 'ORDER_RELEASE', referenceId: a },
    });
    expect(release.delta).toBe(1_000_000n);
    // Nothing more on a cancelled order.
    const late = await ctx.http
      .post(`/api/v1/recharge-orders/${a}/messages`)
      .set(auth(b2))
      .send({ text: 'x' });
    expect(late.status).toBe(409);
    await ledgerMatches(agent.id);
  });

  it('expires REQUESTED after 30 min and AWAITING_PAYMENT after 60 min (released); PAID never', async () => {
    const agent = await activeAgent();
    const [b1, b2, b3] = [await signup(), await signup(), await signup()];
    const start = await stockOf(agent.id);
    const r = await orderAt(b1, agent, 'REQUESTED');
    advance(10 * MIN);
    const a = await orderAt(b2, agent, 'AWAITING_PAYMENT');
    const p = await orderAt(b3, agent, 'PAID');
    const sweeper = ctx.app.get(RechargeOrdersService);
    advance(21 * MIN);
    // (Orders of earlier tests may be due too.)
    expect(await sweeper.sweep()).toBeGreaterThanOrEqual(1);
    expect((await getOrder(b1, r)).body.status).toBe('EXPIRED');
    expect((await getOrder(b2, a)).body.status).toBe('AWAITING_PAYMENT');
    advance(40 * MIN);
    // Read first: a due expiry is applied by the read itself too.
    const read = await getOrder(b2, a);
    expect(read.body).toMatchObject({ status: 'EXPIRED', heldCoins: 0 });
    await sweeper.sweep();
    advance(7 * 24 * 60 * MIN);
    await sweeper.sweep();
    expect((await getOrder(b3, p)).body).toMatchObject({ status: 'PAID', heldCoins: 1_000_000 });
    expect(await stockOf(agent.id)).toBe(start - 1_000_000n);
    const late = await act(b2, a, 'paid', { proofUploadId: await upload(b2) });
    expect(late.status).toBe(409);
    await ledgerMatches(agent.id);
  });

  it('lets employees act only on shift (read any time)', async () => {
    const agent = await activeAgent();
    const employee = await signup();
    const buyer = await signup();
    const clockNow = localClock(now(), 'UTC');
    const start = Math.max(0, clockNow.minutes - 60);
    const hh = (m: number) =>
      `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
    const end = Math.min(24 * 60, clockNow.minutes + 60);
    await ctx.prisma.rechargeEmployee.create({
      data: {
        agentUserId: agent.id,
        employeeUserId: employee.id,
        timeZone: 'UTC',
        schedule: [{ days: [clockNow.day], start: hh(start), end: end === 1440 ? '24:00' : hh(end) }],
      },
    });
    const id = await orderAt(buyer, agent, 'REQUESTED');
    const seen = await getOrder(employee, id);
    expect(seen.body.viewerRole).toBe('EMPLOYEE');
    expect((await details(employee, id)).body.status).toBe('AWAITING_PAYMENT');
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'recharge.order.details', targetId: id },
    });
    expect(audit.metadata).toMatchObject({ byEmployee: true });
    await ctx.prisma.rechargeEmployee.updateMany({
      where: { employeeUserId: employee.id },
      data: {
        schedule: [{ days: [clockNow.day === 7 ? 1 : clockNow.day + 1], start: '00:00', end: '01:00' }],
      },
    });
    expect((await act(buyer, id, 'notice-ack')).status).toBe(200);
    expect((await act(buyer, id, 'paid', { proofUploadId: await upload(buyer) })).status).toBe(200);
    expect((await getOrder(employee, id)).status).toBe(200);
    const off = await act(employee, id, 'confirm');
    expect(off.status).toBe(409);
    expect(off.body.error.code).toBe('RECHARGE_OFF_SHIFT');
  });

  describe('races: exactly one wins and the coins are conserved', () => {
    it('«استلمت» × «نزاع» on the same PAID order', async () => {
      for (let round = 0; round < 3; round++) {
        const agent = await activeAgent();
        const buyer = await signup();
        const id = await orderAt(buyer, agent, 'PAID');
        advance(16 * MIN);
        const [c, d] = await Promise.all([act(agent, id, 'confirm'), act(buyer, id, 'dispute')]);
        const statuses = [c.status, d.status].sort();
        expect(statuses).toEqual([200, 409]);
        const order = await ctx.prisma.rechargeOrder.findUniqueOrThrow({ where: { id } });
        const credited = await coinsOf(buyer);
        if (c.status === 200) {
          expect(order.status).toBe('COMPLETED');
          expect(credited).toBe(1_000_000n);
          expect(d.body.error.code).toBe('RECHARGE_ORDER_STATE_CHANGED');
        } else {
          expect(order.status).toBe('DISPUTED');
          expect(credited).toBe(0n);
          expect(order.heldCoins).toBe(1_000_000n);
        }
        await ledgerMatches(agent.id);
      }
    });

    it('five concurrent «استلمت»: one credit', async () => {
      const agent = await activeAgent();
      const buyer = await signup();
      const id = await orderAt(buyer, agent, 'PAID');
      const all = await Promise.all(Array.from({ length: 5 }, () => act(agent, id, 'confirm')));
      expect(all.every((r) => r.status === 200)).toBe(true);
      expect(await coinsOf(buyer)).toBe(1_000_000n);
      expect(await ctx.prisma.walletLedgerEntry.count({ where: { userId: buyer.id, referenceId: id } })).toBe(
        1,
      );
    });

    it("the buyer's cancel × the agent's details × the expiry", async () => {
      for (let round = 0; round < 3; round++) {
        const agent = await activeAgent();
        const buyer = await signup();
        const id = await orderAt(buyer, agent, 'REQUESTED');
        const start = await stockOf(agent.id);
        const [c, d] = await Promise.all([act(buyer, id, 'cancel'), details(agent, id)]);
        const order = await ctx.prisma.rechargeOrder.findUniqueOrThrow({ where: { id } });
        if (d.status === 200 && c.status === 200) {
          // details first, then the buyer's cancel released the hold.
          expect(order.status).toBe('CANCELLED');
          expect(await stockOf(agent.id)).toBe(start);
        } else {
          expect([c.status, d.status].sort()).toEqual([200, 409]);
          expect(order.status).toBe(c.status === 200 ? 'CANCELLED' : 'AWAITING_PAYMENT');
          expect(await stockOf(agent.id)).toBe(c.status === 200 ? start : start - 1_000_000n);
        }
        await ledgerMatches(agent.id);
      }
      // «قمت بالإرسال» × the sweeper at the deadline: one of them.
      const agent = await activeAgent();
      const buyer = await signup();
      const id = await orderAt(buyer, agent, 'ACKED');
      const proof = await upload(buyer);
      advance(60 * MIN);
      const sweeper = ctx.app.get(RechargeOrdersService);
      const [p, n] = await Promise.all([act(buyer, id, 'paid', { proofUploadId: proof }), sweeper.sweep()]);
      const order = await ctx.prisma.rechargeOrder.findUniqueOrThrow({ where: { id } });
      expect(order.status).toBe('EXPIRED');
      expect(p.status).toBe(409);
      expect(n).toBeLessThanOrEqual(1);
      expect(order.heldCoins).toBe(0n);
      await ledgerMatches(agent.id);
    });

    it('concurrent orders for one pair: one is created', async () => {
      const agent = await activeAgent();
      const buyer = await signup();
      const all = await Promise.all(Array.from({ length: 5 }, () => create(buyer, agent)));
      expect(all.filter((r) => r.status === 201)).toHaveLength(1);
      expect(all.filter((r) => r.status === 409)).toHaveLength(4);
    });

    it('two different decisions on one dispute: one wins', async () => {
      const agent = await activeAgent();
      const buyer = await signup();
      const id = await orderAt(buyer, agent, 'PAID');
      expect((await act(agent, id, 'dispute', { reason: 'لم يصل' })).body.status).toBe('DISPUTED');
      const start = await stockOf(agent.id);
      const results = await Promise.allSettled([
        ctx.prisma.$transaction((tx) =>
          resolveDisputeIn(tx, id, 'CREDIT_BUYER', 'proof ok', now(), badges()),
        ),
        ctx.prisma.$transaction((tx) =>
          resolveDisputeIn(tx, id, 'REFUND_AGENT', 'no proof', now(), badges()),
        ),
      ]);
      expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
      const order = await ctx.prisma.rechargeOrder.findUniqueOrThrow({ where: { id } });
      if (order.status === 'COMPLETED_BY_ADMIN') {
        expect(await coinsOf(buyer)).toBe(1_000_000n);
        expect(await stockOf(agent.id)).toBe(start);
      } else {
        expect(order.status).toBe('REFUNDED_TO_AGENT');
        expect(await coinsOf(buyer)).toBe(0n);
        expect(await stockOf(agent.id)).toBe(start + 1_000_000n);
      }
      await ledgerMatches(agent.id);
    });
  });

  describe('the panel «نزاعات الشحن»', () => {
    let owner: Admin;
    let support: Admin;
    let finance: Admin;
    beforeAll(async () => {
      owner = await makeAdmin(['OWNER']);
      support = await makeAdmin(['SUPPORT']);
      finance = await makeAdmin(['FINANCE']);
    });

    it('opens an order only once disputed, labels «الإدارة», audits views and decides with the code', async () => {
      const agent = await activeAgent();
      const buyer = await signup();
      const id = await orderAt(buyer, agent, 'PAID');
      for (const a of [owner, support, finance]) await relogin(a);
      expect((await aget(support, `/admin/recharge/orders/${id}`)).status).toBe(404);
      advance(15 * MIN);
      const d = await act(buyer, id, 'dispute', { reason: 'مرّت ربع ساعة ولم تصل العملات' });
      expectContract(d, 'disputeRechargeOrder');
      expect(d.body).toMatchObject({ status: 'DISPUTED', disputedBy: 'BUYER', heldCoins: 1_000_000 });
      expect((await act(buyer, id, 'dispute')).status).toBe(200);
      // Both sides keep adding evidence.
      expect(
        (
          await ctx.http
            .post(`/api/v1/recharge-orders/${id}/messages`)
            .set(auth(agent))
            .send({ text: 'لم يصلني' })
        ).status,
      ).toBe(201);
      const queue = await aget(support, '/admin/recharge/disputes');
      expectContract(queue, 'listAdminRechargeDisputes');
      expect((queue.body.data as { id: string }[]).map((o) => o.id)).toContain(id);
      const view = await aget(support, `/admin/recharge/orders/${id}`);
      expectContract(view, 'getAdminRechargeOrder');
      expect(view.body.messages.length).toBeGreaterThan(5);
      const proof = (view.body.messages as { kind: string; id: string }[]).find(
        (m) => m.kind === 'TRANSFER_PROOF',
      )!;
      const img = await aget(support, `/admin/recharge/orders/${id}/messages/${proof.id}/image`);
      expect(img.status).toBe(200);
      expect(img.headers['cache-control']).toBe('private, no-store');
      const views = await ctx.prisma.auditLog.findMany({
        where: { targetId: id, action: { in: ['recharge.order.admin_view', 'recharge.order.image_view'] } },
      });
      expect(views).toHaveLength(2);
      expect(
        views.every((v) => v.actorUserId === support.id && (v.metadata as { via: string }).via === 'panel'),
      ).toBe(true);
      // «الإدارة» in the chat: no name for the users.
      const post = await apost(support, `/admin/recharge/orders/${id}/messages`, {
        text: 'نراجع الإثباتات الآن',
      });
      expectContract(post, 'postAdminRechargeOrderMessage');
      const chat = await ctx.http.get(`/api/v1/recharge-orders/${id}/messages`).set(auth(buyer));
      const adminLine = (chat.body.data as { role: string }[]).find((m) => m.role === 'ADMIN');
      expect(adminLine).toMatchObject({ role: 'ADMIN', author: null, text: 'نراجع الإثباتات الآن' });
      expect(JSON.stringify(chat.body)).not.toContain(support.id);
      // SUPPORT reads and writes; only the money roles decide.
      const denied = await apost(support, `/admin/recharge/orders/${id}/resolve`, {
        outcome: 'CREDIT_BUYER',
        reason: 'x',
        totpCode: nextCode(support.secret),
      });
      expect(denied.status).toBe(403);
      const wrong = await apost(finance, `/admin/recharge/orders/${id}/resolve`, {
        outcome: 'CREDIT_BUYER',
        reason: 'the transfer arrived',
        totpCode: '000000',
      });
      expect(wrong.status).toBe(403);
      expect(wrong.body.error.code).toBe('ADMIN_TOTP_INVALID');
      expect(await coinsOf(buyer)).toBe(0n);
      const ok = await apost(finance, `/admin/recharge/orders/${id}/resolve`, {
        outcome: 'CREDIT_BUYER',
        reason: 'the transfer arrived',
        totpCode: nextCode(finance.secret),
      });
      expectContract(ok, 'resolveAdminRechargeDispute');
      expect(ok.body).toEqual({ status: 'COMPLETED_BY_ADMIN', changed: true });
      expect(await coinsOf(buyer)).toBe(1_000_000n);
      const again = await apost(finance, `/admin/recharge/orders/${id}/resolve`, {
        outcome: 'CREDIT_BUYER',
        reason: 'again',
        totpCode: nextCode(finance.secret),
      });
      expect(again.body).toEqual({ status: 'COMPLETED_BY_ADMIN', changed: false });
      const other = await apost(finance, `/admin/recharge/orders/${id}/resolve`, {
        outcome: 'REFUND_AGENT',
        reason: 'no',
        totpCode: nextCode(finance.secret),
      });
      expect(other.status).toBe(409);
      expect(await coinsOf(buyer)).toBe(1_000_000n);
      const decision = await ctx.prisma.auditLog.findFirstOrThrow({
        where: { action: 'recharge.order.resolve', targetId: id },
      });
      expect(decision.actorUserId).toBe(finance.id);
      expect(decision.ip).not.toBeNull();
      expect(decision.metadata).toMatchObject({
        before: 'DISPUTED',
        after: 'COMPLETED_BY_ADMIN',
        reason: 'the transfer arrived',
        via: 'panel',
      });
      const buyerNote = await ctx.http.get('/api/v1/notifications').set(auth(buyer));
      expect(buyerNote.body.data[0].target).toMatchObject({ orderStatus: 'COMPLETED_BY_ADMIN' });
      await ledgerMatches(agent.id);
    });

    it('refunds the agent and edits the exchange rates (OWNER / FINANCE)', async () => {
      const agent = await activeAgent();
      const buyer = await signup();
      const id = await orderAt(buyer, agent, 'PAID');
      expect((await act(agent, id, 'dispute')).body.disputedBy).toBe('AGENT');
      await relogin(owner);
      const start = await stockOf(agent.id);
      const r = await apost(owner, `/admin/recharge/orders/${id}/resolve`, {
        outcome: 'REFUND_AGENT',
        reason: 'no transfer in the screenshot',
        totpCode: nextCode(owner.secret),
      });
      expect(r.body).toEqual({ status: 'REFUNDED_TO_AGENT', changed: true });
      expect(await stockOf(agent.id)).toBe(start + 1_000_000n);
      expect(await coinsOf(buyer)).toBe(0n);
      const resolved = await aget(owner, '/admin/recharge/disputes?status=RESOLVED');
      expect((resolved.body.data as { id: string }[]).map((o) => o.id)).toContain(id);
      // Rates.
      await relogin(support);
      await relogin(finance);
      const list = await aget(support, '/admin/recharge/exchange-rates');
      expectContract(list, 'listAdminRechargeExchangeRates');
      expect((list.body.data as { country: string }[]).length).toBeGreaterThanOrEqual(22);
      expect(
        (
          await apost(support, '/admin/recharge/exchange-rates/SA', {
            currency: 'SAR',
            unitsPerUsd: '3.75',
            digits: 2,
            reason: 'x',
          })
        ).status,
      ).toBe(403);
      const set = await apost(finance, '/admin/recharge/exchange-rates/sa', {
        currency: 'SAR',
        unitsPerUsd: '3.75',
        digits: 2,
        reason: 'bank rate',
      });
      expectContract(set, 'setAdminRechargeExchangeRate');
      expect(set.body).toMatchObject({ country: 'SA', unitsPerUsd: '3.75' });
      const q = await ctx.http
        .get(`/api/v1/recharge-orders/quote?agentCode=${agent.code}&country=SA&coins=2000000`)
        .set(auth(buyer));
      expect(q.body.price.local).toMatchObject({ currency: 'SAR', amount: '93.75' });
      const clear = await apost(finance, '/admin/recharge/exchange-rates/SA/clear', { reason: 'stop' });
      expectContract(clear, 'clearAdminRechargeExchangeRate');
      const audits = await ctx.prisma.auditLog.findMany({
        where: { targetId: 'SA', action: { in: ['recharge.rate.set', 'recharge.rate.clear'] } },
      });
      expect(audits.map((a) => (a.metadata as { via: string }).via)).toEqual(['panel', 'panel']);
      expect(
        (await apost(finance, '/admin/recharge/exchange-rates/SA/clear', { reason: 'again' })).status,
      ).toBe(409);
      await ledgerMatches(agent.id);
    });
  });

  it('keeps direct selling (D185) working next to the orders', async () => {
    const agent = await activeAgent();
    const buyer = await signup();
    const sale = await ctx.http
      .post('/api/v1/me/recharge-agent/sales')
      .set(auth(agent))
      .set('Idempotency-Key', randomUUID())
      .send({ buyer: buyer.username, coins: 500_000 });
    expect(sale.status).toBe(201);
    expect(await coinsOf(buyer)).toBe(500_000n);
    await ledgerMatches(agent.id);
  });
});

describe('D204 switched off', () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp({ RECHARGE_ORDERS_ENABLED: 'false' });
  });
  afterAll(async () => {
    await ctx?.close();
  });

  it('answers 503 RECHARGE_ORDERS_UNAVAILABLE and tells the app', async () => {
    const { res } = await registerVerified(ctx);
    const token = res.body.tokens.accessToken as string;
    const r = await ctx.http
      .post('/api/v1/recharge-orders')
      .set({ Authorization: `Bearer ${token}` })
      .set('Idempotency-Key', randomUUID())
      .send({ agentCode: 'coin0001', country: 'EG', coins: 1_000_000, paymentType: 'CASH' });
    expect(r.status).toBe(503);
    expect(r.body.error.code).toBe('RECHARGE_ORDERS_UNAVAILABLE');
    const me = await ctx.http.get('/api/v1/me/recharge-agent').set({ Authorization: `Bearer ${token}` });
    expect(me.body.rules.orders.enabled).toBe(false);
  });
});
