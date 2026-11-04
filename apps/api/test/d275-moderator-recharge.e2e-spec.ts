/**
 * D275 (owner): the panel's moderator «مشرف» (MODERATION) reads the top-up records — the recharge agents and the
 * exchange rates, the agents' top-ups «شحن الوكلاء», the users' card orders and a user's coin / cherry ledger — and
 * views and decides the recharge disputes «نزاعات الشحن» with the authenticator code again. It moves no other coin:
 * top-up, cap, suspend / reinstate, rates, withdrawals, the financial report, the Stripe cases and a refund are 403.
 * The CSV of the two top-up lists is allowed (owner «نعم»), audited `admin.export.csv`. FINANCE keeps all of it. End to end against PostgreSQL + Redis.
 */
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import type request from 'supertest';
import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { topUpIn } from '../src/modules/recharge/recharge-core.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly email: string;
  readonly password: string;
  readonly token: string;
}
interface Admin extends TestUser {
  secret: string;
  cookie: string;
  csrf: string;
}

const RULES = {
  activationMinCoins: 30_000_000,
  priceTiers: [{ minCoins: 0, minorPerMillion: 1200 }],
  currency: 'USD',
};
const COOKIE = '__Host-kabso_admin';

describe(
  'D275 the moderator «مشرف»: top-up records read-only, disputes decided',
  { timeout: 600_000 },
  () => {
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
        email: payload.email,
        password: payload.password,
        token: res.body.tokens.accessToken as string,
      };
    };

    /** An ACTIVE agent serving EG, activated with 30 000 000 coins (one `recharge_topups` row). */
    const activeAgent = async (): Promise<TestUser & { code: string }> => {
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
      const coins = 30_000_000n;
      const r = await ctx.prisma.$transaction((tx) =>
        topUpIn(tx, user.id, coins, (coins * 1200n + 500_000n) / 1_000_000n, null, RULES, now()),
      );
      return { ...user, code: r.code! };
    };

    const act = (u: TestUser, id: string, action: string, body: object = {}) =>
      ctx.http.post(`/api/v1/recharge-orders/${id}/${action}`).set(auth(u)).send(body);
    const coinsOf = async (u: TestUser) =>
      (await ctx.prisma.wallet.findUnique({ where: { userId: u.id } }))?.coins ?? 0n;
    const stockOf = async (agentId: string) =>
      (await ctx.prisma.rechargeAgent.findUniqueOrThrow({ where: { userId: agentId } })).stockCoins;

    /** A PAID order the agent disputed at once (the agent may; the buyer waits 15 minutes). */
    const disputedOrder = async (buyer: TestUser, agent: TestUser & { code: string }): Promise<string> => {
      const res = await ctx.http
        .post('/api/v1/recharge-orders')
        .set(auth(buyer))
        .set('Idempotency-Key', randomUUID())
        .send({ agentCode: agent.code, country: 'EG', coins: 1_000_000, paymentType: 'MOBILE_WALLET' });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      const id = res.body.id as string;
      expect(
        (await act(agent, id, 'payment-details', { method: 'MOBILE_WALLET', details: 'Vodafone Cash 0100' }))
          .status,
      ).toBe(200);
      expect((await act(buyer, id, 'notice-ack')).status).toBe(200);
      const slot = await ctx.http
        .post('/api/v1/media/uploads')
        .set(auth(buyer))
        .send({ kind: 'RECHARGE_ORDER_IMAGE', contentType: 'image/png', byteSize: png.length });
      expect(slot.status, JSON.stringify(slot.body)).toBe(201);
      expect(storage.upload(slot.body.uploadUrl as string, png, 'image/png')).toBe(true);
      const paid = await act(buyer, id, 'paid', { proofUploadId: slot.body.uploadId as string });
      expect(paid.status, JSON.stringify(paid.body)).toBe(200);
      const d = await act(agent, id, 'dispute', { reason: 'لم يصل' });
      expect(d.body.status).toBe('DISPUTED');
      return id;
    };

    // ---- admin panel helpers (as in d191 / d204) ----
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
    const aget = (a: Admin, path: string) => ctx.http.get(`/api/v1${path}`).set('Cookie', a.cookie);
    const apost = (a: Admin, path: string, body: object = {}) =>
      ctx.http.post(`/api/v1${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf).send(body);

    let mod: Admin;
    let finance: Admin;
    let support: Admin;
    let agent: TestUser & { code: string };
    let buyer: TestUser;

    beforeAll(async () => {
      vi.useFakeTimers({ toFake: ['Date'], now: clock });
      png = await sharp({ create: { width: 64, height: 48, channels: 3, background: '#c33' } })
        .png()
        .toBuffer();
      ctx = await createTestApp(
        {
          ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
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
      mod = await makeAdmin(['MODERATION']);
      finance = await makeAdmin(['FINANCE']);
      support = await makeAdmin(['SUPPORT']);
      agent = await activeAgent();
      buyer = await signup();
    });

    afterAll(async () => {
      await ctx?.close();
      vi.useRealTimers();
    });

    afterEach(() => {
      vi.setSystemTime(clock);
    });

    it('the session lists the read capabilities and the dispute decision, and no other money capability', async () => {
      const me = await aget(mod, '/admin/auth/session');
      expect(me.status, JSON.stringify(me.body)).toBe(200);
      const caps = me.body.capabilities as string[];
      for (const c of [
        'recharge.agents',
        'recharge.topups.view',
        'users.ledger',
        'recharge.disputes',
        'recharge.disputes.resolve',
      ])
        expect(caps, c).toContain(c);
      for (const c of [
        'recharge.topup',
        'recharge.cap',
        'recharge.status',
        'recharge.rates',
        'withdrawals.view',
        'withdrawals.decide',
        'finance.view',
        'finance.refund',
        'payments.settings',
        'users.balance_adjust',
      ])
        expect(caps, c).not.toContain(c);
    });

    it('reads the agents, the rates, the agents’ top-ups, the card orders and a user’s ledger', async () => {
      const agents = await aget(mod, '/admin/recharge/agents');
      expectContract(agents, 'listAdminRechargeAgents');
      expect((agents.body.data as { userId: string }[]).map((a) => a.userId)).toContain(agent.id);
      const rates = await aget(mod, '/admin/recharge/exchange-rates');
      expectContract(rates, 'listAdminRechargeExchangeRates');

      const topups = await aget(mod, '/admin/finance/recharge-topups');
      expectContract(topups, 'listAdminRechargeTopups');
      expect(
        (topups.body.data as { agent: { code: string }; coins: number }[]).some(
          (t) => t.agent.code === agent.code && t.coins === 30_000_000,
        ),
      ).toBe(true);
      const cards = await aget(mod, '/admin/finance/card-orders');
      expectContract(cards, 'listAdminCardOrders');

      const ledger = await aget(mod, `/admin/users/${agent.id}/ledger?kind=coins`);
      expect(ledger.status, JSON.stringify(ledger.body)).toBe(200);
      expectContract(ledger, 'listAdminUserLedger');
      const cherries = await aget(mod, `/admin/users/${agent.id}/ledger?kind=cherries`);
      expect(cherries.status).toBe(200);
      const user = await aget(mod, `/admin/users/${buyer.id}`);
      expect(user.status).toBe(200);
      expect(user.body.ledger).not.toBeNull();

      // Owner «نعم»: the moderator downloads both top-up lists as CSV, each export audited.
      const modCsv = await aget(mod, '/admin/finance/recharge-topups?format=csv');
      expect(modCsv.status).toBe(200);
      expect(modCsv.headers['content-type']).toContain('text/csv');
      expect(modCsv.text).toContain(agent.code);
      const modCards = await aget(mod, '/admin/finance/card-orders?format=csv');
      expect(modCards.status).toBe(200);
      expect(modCards.headers['content-type']).toContain('text/csv');
      const exports = await ctx.prisma.auditLog.findMany({
        where: { action: 'admin.export.csv', actorUserId: mod.id },
      });
      expect(exports).toHaveLength(2);

      // SUPPORT gains no top-up record; FINANCE keeps them, with the CSV.
      expect((await aget(support, '/admin/finance/recharge-topups')).status).toBe(403);
      expect((await aget(support, '/admin/finance/card-orders')).status).toBe(403);
      const csv = await aget(finance, '/admin/finance/recharge-topups?format=csv');
      expect(csv.status).toBe(200);
      expect(csv.headers['content-type']).toContain('text/csv');
      expect((await aget(finance, '/admin/finance/card-orders?format=csv')).status).toBe(200);
      expect(
        (await aget(finance, '/admin/finance/report?granularity=day&from=2026-01-01&to=2026-01-31')).status,
      ).toBe(200);
    });

    it('403 on every other money route: top-up, cap, status, rates, withdrawals, report, cases, refund', async () => {
      const stock = await stockOf(agent.id);
      const forbidden: [string, () => request.Test][] = [
        [
          'topup',
          () =>
            apost(mod, `/admin/recharge/agents/${agent.id}/topup`, {
              coins: '1000000',
              paidUsd: '12.00',
              totpCode: nextCode(mod.secret),
            }),
        ],
        ['cap', () => apost(mod, `/admin/recharge/agents/${agent.id}/cap`, { cap: '10', reason: 'x' })],
        ['suspend', () => apost(mod, `/admin/recharge/agents/${agent.id}/suspend`, { reason: 'x' })],
        ['reinstate', () => apost(mod, `/admin/recharge/agents/${agent.id}/reinstate`, { reason: 'x' })],
        [
          'set rate',
          () =>
            apost(mod, '/admin/recharge/exchange-rates/EG', {
              currency: 'EGP',
              unitsPerUsd: '50',
              digits: 2,
              reason: 'x',
            }),
        ],
        ['clear rate', () => apost(mod, '/admin/recharge/exchange-rates/EG/clear', { reason: 'x' })],
        ['fx refresh', () => apost(mod, '/admin/fx/refresh')],
        ['withdrawals', () => aget(mod, '/admin/withdrawals')],
        [
          'withdrawal pay',
          () => apost(mod, `/admin/withdrawals/${randomUUID()}/pay`, { reference: 'r', totpCode: '000000' }),
        ],
        [
          'withdrawal reject',
          () => apost(mod, `/admin/withdrawals/${randomUUID()}/reject`, { reason: 'x', totpCode: '000000' }),
        ],
        ['report', () => aget(mod, '/admin/finance/report')],
        ['cases', () => aget(mod, '/admin/finance/cases')],
        [
          'refund',
          () =>
            apost(mod, `/admin/finance/card-orders/${randomUUID()}/refund`, {
              reason: 'x',
              totpCode: '000000',
            }),
        ],
        ['payments', () => aget(mod, '/admin/payment-settings')],
        [
          'balance adjust',
          () =>
            apost(mod, `/admin/users/${buyer.id}/balance-adjustments`, {
              currency: 'COINS',
              amount: '100',
              reason: 'x',
              totpCode: '000000',
            }),
        ],
      ];
      for (const [name, req] of forbidden) {
        const res = await req();
        expect(res.status, `${name}: ${JSON.stringify(res.body)}`).toBe(403);
        expect(res.body.error.code, name).toBe('AUTH_FORBIDDEN');
      }
      expect(await stockOf(agent.id)).toBe(stock);
      expect(await coinsOf(buyer)).toBe(0n);
    });

    it('views a dispute (audited), writes as «الإدارة» and decides it with the code — the only coin it moves', async () => {
      const id = await disputedOrder(buyer, agent);
      const queue = await aget(mod, '/admin/recharge/disputes');
      expectContract(queue, 'listAdminRechargeDisputes');
      expect((queue.body.data as { id: string }[]).map((o) => o.id)).toContain(id);
      const view = await aget(mod, `/admin/recharge/orders/${id}`);
      expectContract(view, 'getAdminRechargeOrder');
      const proof = (view.body.messages as { kind: string; id: string }[]).find(
        (m) => m.kind === 'TRANSFER_PROOF',
      )!;
      expect((await aget(mod, `/admin/recharge/orders/${id}/messages/${proof.id}/image`)).status).toBe(200);
      const views = await ctx.prisma.auditLog.findMany({
        where: {
          targetId: id,
          actorUserId: mod.id,
          action: { in: ['recharge.order.admin_view', 'recharge.order.image_view'] },
        },
      });
      expect(views).toHaveLength(2);
      const post = await apost(mod, `/admin/recharge/orders/${id}/messages`, { text: 'نراجع الإثباتات' });
      expectContract(post, 'postAdminRechargeOrderMessage');

      const wrong = await apost(mod, `/admin/recharge/orders/${id}/resolve`, {
        outcome: 'CREDIT_BUYER',
        reason: 'the transfer arrived',
        totpCode: '000000',
      });
      expect(wrong.status).toBe(403);
      expect(wrong.body.error.code).toBe('ADMIN_TOTP_INVALID');
      expect(await coinsOf(buyer)).toBe(0n);

      const ok = await apost(mod, `/admin/recharge/orders/${id}/resolve`, {
        outcome: 'CREDIT_BUYER',
        reason: 'the transfer arrived',
        totpCode: nextCode(mod.secret),
      });
      expectContract(ok, 'resolveAdminRechargeDispute');
      expect(ok.body).toEqual({ status: 'COMPLETED_BY_ADMIN', changed: true });
      expect(await coinsOf(buyer)).toBe(1_000_000n);
      const decision = await ctx.prisma.auditLog.findFirstOrThrow({
        where: { action: 'recharge.order.resolve', targetId: id },
      });
      expect(decision.actorUserId).toBe(mod.id);
      expect(decision.metadata).toMatchObject({ after: 'COMPLETED_BY_ADMIN', via: 'panel' });

      // The other way: back to the agent.
      const second = await disputedOrder(buyer, agent);
      const stock = await stockOf(agent.id);
      const refund = await apost(mod, `/admin/recharge/orders/${second}/resolve`, {
        outcome: 'REFUND_AGENT',
        reason: 'no transfer in the screenshot',
        totpCode: nextCode(mod.secret),
      });
      expect(refund.body).toEqual({ status: 'REFUNDED_TO_AGENT', changed: true });
      expect(await stockOf(agent.id)).toBe(stock + 1_000_000n);
      expect(await coinsOf(buyer)).toBe(1_000_000n);
    });
  },
);
