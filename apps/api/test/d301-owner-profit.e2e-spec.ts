/**
 * D301 follow-up (owner 2026-11-07: «اريد عند حساب الارباح على صفحتي كمؤسس ان تزيل نسب الجميع لكون ربح نهائي وضعها قبل
 * وبعد. بالاضافة هناك تكاليف ثابتة … هذه التكاليف الشهرية يتم تقسيمها على الشهر»; contract v1.95-social, CONVENTIONS
 * §10.112.10): «الربح» on «لوحة المؤسس», end to end against PostgreSQL + Redis:
 *
 *  - «قبل»: card top-ups less refunds and held chargebacks (a won dispute gives back), plus the agents' stock purchases;
 *    another currency apart, never converted;
 *  - every deduction from seeded ledger rows: gift cherries net of reversals, agency + parent commissions less a
 *    forfeit, referral rewards, task and host-target rewards, recruiters' commissions, the team's adjustments, the
 *    estimated card fees — at the configured rates; withdrawals and cherries sold to agents never count;
 *  - the fixed monthly costs prorated by day ($300 a month in a 30-day month = $10 a day; a cost active 10 days; an
 *    ended one ignored), the whole month, the current month to date;
 *  - «بعد» = before − deductions − fixed costs, negative when the costs are larger;
 *  - the fixed costs managed by the owner in the app and by an OWNER in the panel, audited; 403 for everyone else.
 */
import { randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { OwnerProfitService } from '../src/modules/owner-profile/owner-profit.service.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

const COOKIE = '__Host-kabso_admin';
const ZONE = 'Asia/Riyadh';
/** A 30-day month no other test writes money into. */
const DAY = '2026-06-15';
/** Noon in Riyadh on a day of June 2026. */
const at = (d: number) => new Date(Date.UTC(2026, 5, d, 9, 0, 0));

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly password: string;
  readonly token: string;
}
interface Admin extends TestUser {
  cookie: string;
  csrf: string;
}

describe('D301 «الربح» contract coverage', () => {
  it('openapi v1.95-social declares the profit operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'getOwnerProfit GET /api/v1/owner/profit',
        'listOwnerFixedCosts GET /api/v1/owner/fixed-costs',
        'createOwnerFixedCost POST /api/v1/owner/fixed-costs',
        'updateOwnerFixedCost PATCH /api/v1/owner/fixed-costs/{costId}',
        'deleteOwnerFixedCost DELETE /api/v1/owner/fixed-costs/{costId}',
        'listAdminOwnerFixedCosts GET /api/v1/admin/owner-fixed-costs',
        'createAdminOwnerFixedCost POST /api/v1/admin/owner-fixed-costs',
        'updateAdminOwnerFixedCost PATCH /api/v1/admin/owner-fixed-costs/{costId}',
        'deleteAdminOwnerFixedCost DELETE /api/v1/admin/owner-fixed-costs/{costId}',
      ]),
    );
  });
});

describe('D301 «الربح» — before and after every share', { timeout: 900_000 }, () => {
  let ctx: TestContext;
  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
  const codeOf = (res: request.Response) => (res.body as { error?: { code?: string } }).error?.code;
  const issueOf = (res: request.Response) =>
    (res.body as { error: { details?: { field: string; issue: string }[] } }).error.details?.[0];

  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: String(payload.email).trim().toLowerCase(),
      password: payload.password,
      token: res.body.tokens.accessToken as string,
    };
  };
  const cookieOf = (res: request.Response): string => {
    const raw = ([] as string[]).concat(res.headers['set-cookie'] ?? []);
    const line = raw.find((c) => c.startsWith(`${COOKIE}=`));
    if (!line) throw new Error(`no session cookie in ${JSON.stringify(raw)}`);
    return line.split(';')[0]!;
  };
  const grant = (u: TestUser, role: string) =>
    withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, u.email, role as never)));
  const panelLogin = async (p: TestUser): Promise<Admin> => {
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
    const confirm = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment/confirm')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf)
      .send({ code: totpCode(enrol.body.secret as string, Date.now()) });
    expect(confirm.status, JSON.stringify(confirm.body)).toBe(200);
    return { ...p, cookie: cookieOf(confirm), csrf: confirm.body.session.csrfToken as string };
  };
  const admin = (a: Admin, method: 'get' | 'post' | 'patch' | 'delete', path: string, body?: object) => {
    const r = ctx.http[method](`/api/v1${path}`).set('Cookie', a.cookie);
    if (method === 'get') return r;
    const w = r.set('X-CSRF-Token', a.csrf);
    return body === undefined ? w : w.send(body);
  };
  const get = (u: TestUser, path: string) => ctx.http.get(`/api/v1${path}`).set(auth(u));
  const send = (u: TestUser, method: 'post' | 'patch' | 'delete', path: string, body?: object) => {
    const r = ctx.http[method](`/api/v1${path}`).set(auth(u));
    return body === undefined ? r : r.send(body);
  };
  const audits = (action: string) => ctx.prisma.auditLog.findMany({ where: { action } });

  let owner: TestUser;
  let moderator: TestUser;
  let alice: TestUser;
  let bob: TestUser;

  const order = async (
    day: number,
    amountMinor: number,
    extra: {
      refundedMinor?: number;
      disputeStatus?: string;
      disputeAmountMinor?: number;
      currency?: string;
    } = {},
  ) => {
    const terms = randomUUID();
    await ctx.prisma.topupTermsAcceptance.create({
      data: {
        id: terms,
        userId: alice.id,
        termsVersion: 't1',
        termsText: 'x',
        locale: 'ar',
        acceptedAt: at(day),
      },
    });
    await ctx.prisma.topupOrder.create({
      data: {
        id: randomUUID(),
        userId: alice.id,
        termsAcceptanceId: terms,
        packageId: '5000',
        coins: 5000n,
        amountMinor,
        currency: extra.currency ?? 'USD',
        paymentMethodTypes: ['card'],
        status: 'PAID',
        stripePaymentIntentId: `pi_d301p_${randomUUID()}`,
        creditedAt: at(day),
        createdAt: at(day),
        refundedMinor: extra.refundedMinor ?? 0,
        disputeStatus: extra.disputeStatus ?? null,
        disputeAmountMinor: extra.disputeAmountMinor ?? 0,
      },
    });
  };
  let cherryBalance = 0n;
  const cherries = async (reason: string, delta: bigint, day = 15) => {
    cherryBalance += delta;
    await ctx.prisma.cherryLedgerEntry.create({
      data: {
        userId: bob.id,
        delta,
        balanceAfter: cherryBalance,
        reason: reason as never,
        referenceId: `d301p-${randomUUID()}`,
        createdAt: at(day),
      },
    });
  };
  let coinBalance = 0n;
  const coins = async (reason: string, delta: bigint) => {
    coinBalance += delta;
    await ctx.prisma.walletLedgerEntry.create({
      data: {
        userId: bob.id,
        delta,
        balanceAfter: coinBalance,
        reason: reason as never,
        referenceId: `d301p-${randomUUID()}`.slice(0, 64),
        createdAt: at(15),
      },
    });
  };

  beforeAll(async () => {
    ctx = await createTestApp({
      ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
      ADMIN_SESSION_IDLE_SECONDS: '86400',
      ADMIN_SESSION_MAX_SECONDS: '604800',
      ADMIN_DASHBOARD_TIME_ZONE: ZONE,
      CHERRY_PAYOUT_RATE: '1000000:110',
      CHERRY_PAYOUT_CURRENCY: 'USD',
      ADMIN_REPORT_CARD_FEE_BPS: '290',
      ADMIN_REPORT_CARD_FEE_FIXED_MINOR: '30',
      COIN_RETAIL_USD_PER_MILLION: '12.5',
      RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
      RATE_LIMIT_ADMIN_IP: '100000/900',
      RATE_LIMIT_AUTHENTICATED_USER: '100000/900',
    });
    owner = await signup();
    moderator = await signup();
    alice = await signup();
    bob = await signup();
    await grant(owner, 'OWNER');
    await grant(moderator, 'MODERATION');

    // «قبل», 15 June: $100 charged less a $10 refund and a $20 lost chargeback; $50 whose dispute was won (nothing
    // held); an agent paid $30 for 400 000 coins and €50 apart. 3 June: $20 more (the month only).
    await order(15, 10_000, { refundedMinor: 1_000, disputeStatus: 'lost', disputeAmountMinor: 2_000 });
    await order(15, 5_000, { disputeStatus: 'won', disputeAmountMinor: 5_000 });
    await order(3, 2_000);
    const appId = randomUUID();
    await ctx.prisma.rechargeAgentApplication.create({
      data: { id: appId, userId: bob.id, status: 'APPROVED', decidedAt: at(1), purgedAt: at(1) },
    });
    await ctx.prisma.rechargeAgent.create({
      data: {
        userId: bob.id,
        applicationId: appId,
        status: 'ACTIVE',
        code: 'coin9302',
        codeNumber: 9302,
        countries: ['SA'],
        locations: [],
        paymentTypes: [],
        activatedAt: at(1),
      },
    });
    for (const [paid, currency, n] of [
      [3_000n, 'USD', 400_000n],
      [5_000n, 'EUR', 100_000n],
    ] as const) {
      await ctx.prisma.rechargeTopup.create({
        data: {
          agentUserId: bob.id,
          coins: n,
          tier: 'T1',
          pricePerMillionMinor: 750,
          expectedMinor: paid,
          paidMinor: paid,
          currency,
          first: currency === 'USD',
          createdAt: at(15),
        },
      });
    }
    // The shares (1 000 000 cherries = $1.10).
    await cherries('GIFT_RECEIVED', 10_000_000n);
    await cherries('GIFT_REVERSAL', -1_000_000n);
    await cherries('AGENCY_COMMISSION', 2_000_000n);
    await cherries('PARENT_COMMISSION', 1_000_000n);
    await cherries('AGENCY_FORFEIT', -500_000n);
    await cherries('REFERRAL_REWARD', 1_000_000n);
    await cherries('TASK_REWARD', 500_000n);
    await cherries('HOST_TARGET_REWARD', 500_000n);
    await cherries('STAFF_RECRUIT_COMMISSION', 1_000_000n);
    await cherries('ADMIN_ADJUSTMENT', -1_000_000n);
    // Never costs: a withdrawal (the cherries were counted when credited) and cherries sold to an agent.
    await cherries('WITHDRAWAL_HOLD', -3_000_000n);
    await cherries('RECHARGE_SALE', -1_000_000n);
    // Another day of the month: gifts on 3 June (the month only).
    await cherries('GIFT_RECEIVED', 1_000_000n, 3);
    // Free coins (for information): an event prize and task coins.
    await coins('EVENT_PRIZE', 200_000n);
    await coins('TASK_REWARD', 50_000n);
    // v1.139-social (D387, §10.176.4; owner: «نعم ينقص تقرير الربح قيمة هذه العملات»): a VIP care compensation in coins.
    await coins('STAFF_COMPENSATION', 100_000n);
    // The fixed costs: servers $300 a month (always), LiveKit $93 a month for 10 days, an ended one.
    await ctx.prisma.ownerFixedCost.createMany({
      data: [
        { name: 'Servers', monthlyMinor: 30_000n, activeFrom: new Date('2026-01-01') },
        {
          name: 'LiveKit',
          monthlyMinor: 9_300n,
          activeFrom: new Date('2026-06-10'),
          activeTo: new Date('2026-06-19'),
        },
        {
          name: 'Old',
          monthlyMinor: 99_999n,
          activeFrom: new Date('2026-01-01'),
          activeTo: new Date('2026-05-31'),
        },
      ],
    });
  });

  afterAll(async () => {
    await ctx?.close();
  });

  it('a day and its month: before, each deduction, the prorated fixed costs, after (negative shown as is)', async () => {
    const res = await get(owner, `/owner/profit?day=${DAY}`);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getOwnerProfit');
    const { day, month, rates } = res.body;
    expect(rates).toMatchObject({
      cherries: 1_000_000,
      minor: 110,
      cherryCurrency: 'USD',
      cardFeeBps: 290,
      coinValueMinorPerMillion: 1200,
    });
    expect(day).toMatchObject({ kind: 'DAY', key: DAY, days: 1, daysInMonth: 30, partial: false });
    expect(day.before).toEqual({
      amountMinor: 15_000,
      cardChargedMinor: 15_000,
      refundsMinor: 1_000,
      chargebacksMinor: 2_000,
      agentsMinor: 3_000,
    });
    const lines = Object.fromEntries(
      (
        day.deductions as {
          key: string;
          amountMinor: number;
          cherries: number | null;
          orders: number | null;
        }[]
      ).map((d) => [d.key, d]),
    );
    expect(Object.keys(lines)).toEqual([
      'GIFTS',
      'AGENCY_COMMISSIONS',
      'REFERRAL_REWARDS',
      // v1.141-social (D390): the ambassadors' two lines.
      'AMBASSADOR_COMMISSIONS',
      'TASK_REWARDS',
      'STAFF_COMMISSIONS',
      'TEAM_ADJUSTMENTS',
      'COIN_REWARDS',
      'STAFF_COMPENSATIONS',
      'AMBASSADOR_REWARDS',
      'CARD_FEES',
    ]);
    expect(lines.GIFTS).toMatchObject({ cherries: 9_000_000, amountMinor: 990 });
    expect(lines.AGENCY_COMMISSIONS).toMatchObject({ cherries: 2_500_000, amountMinor: 275 });
    expect(lines.REFERRAL_REWARDS).toMatchObject({ cherries: 1_000_000, amountMinor: 110 });
    expect(lines.TASK_REWARDS).toMatchObject({ cherries: 1_000_000, amountMinor: 110 });
    expect(lines.STAFF_COMMISSIONS).toMatchObject({ cherries: 1_000_000, amountMinor: 110 });
    expect(lines.TEAM_ADJUSTMENTS).toMatchObject({ cherries: -1_000_000, amountMinor: -110 });
    // Owner: given-away coins at the lowest agent price, $12 a million: 250 000 coins = $3.
    expect(lines.COIN_REWARDS).toMatchObject({ coins: 250_000, cherries: null, amountMinor: 300 });
    // D387: the compensations, their own line at the same value: 100 000 coins = $1.20.
    expect(lines.STAFF_COMPENSATIONS).toMatchObject({ coins: 100_000, cherries: null, amountMinor: 120 });
    // 2.9 % of $150 = $4.35, + 2 orders × $0.30.
    expect(lines.CARD_FEES).toMatchObject({ orders: 2, cherries: null, amountMinor: 495 });
    // $300 ÷ 30 = $10; $93 ÷ 30 = $3.10; the ended cost is not there.
    expect(day.fixedCosts).toEqual({
      amountMinor: 1_310,
      items: [
        expect.objectContaining({ name: 'LiveKit', monthlyMinor: 9_300, days: 1, shareMinor: 310 }),
        expect.objectContaining({ name: 'Servers', monthlyMinor: 30_000, days: 1, shareMinor: 1_000 }),
      ],
    });
    expect(day.after.amountMinor).toBe(15_000 - 2_280 - 120 - 1_310);
    expect(day.otherCurrencies).toEqual([
      {
        currency: 'EUR',
        beforeMinor: 5_000,
        cardChargedMinor: 0,
        refundsMinor: 0,
        chargebacksMinor: 0,
        agentsMinor: 5_000,
        deductionsMinor: 0,
        afterMinor: 5_000,
      },
    ]);
    // 400 000 agent coins = $5 at retail (information; their purchase counts at the $30 really paid).
    expect(day.info).toEqual({
      agentCoins: 400_000,
      agentCoinsRetailMinor: 500,
    });

    // June, a past month: whole; the fixed costs in full ($300 + 10 days of $93); after is negative.
    expect(month).toMatchObject({
      kind: 'MONTH',
      key: '2026-06',
      from: '2026-06-01',
      to: '2026-06-30',
      days: 30,
    });
    expect(month.partial).toBe(false);
    expect(month.before.amountMinor).toBe(17_000);
    const mLines = Object.fromEntries(
      (month.deductions as { key: string; amountMinor: number }[]).map((d) => [d.key, d.amountMinor]),
    );
    expect(mLines.GIFTS).toBe(1_100);
    // 2.9 % of $170 = $4.93, + 3 × $0.30.
    expect(mLines.CARD_FEES).toBe(583);
    expect(month.fixedCosts.amountMinor).toBe(33_100);
    const deducted = Object.values(mLines).reduce((s, n) => s + n, 0);
    // D387: + the compensations' $1.20.
    expect(deducted).toBe(1_100 + 275 + 110 + 110 + 110 - 110 + 300 + 120 + 583);
    expect(month.after.amountMinor).toBe(17_000 - deducted - 33_100);
    expect(month.after.amountMinor).toBeLessThan(0);

    // The same numbers straight from the service.
    const direct = await ctx.app.get(OwnerProfitService).compute(DAY, res.body.today as string, new Date());
    expect(direct.day.after).toEqual(day.after);
  });

  it('today by default; the current month to date (the elapsed share of the fixed costs)', async () => {
    const res = await get(owner, '/owner/profit');
    expect(res.status).toBe(200);
    expectContract(res, 'getOwnerProfit');
    const today = res.body.today as string;
    expect(res.body.day.key).toBe(today);
    expect(res.body.month).toMatchObject({
      from: `${today.slice(0, 7)}-01`,
      to: today,
      days: Number(today.slice(8)),
    });
    const servers = (res.body.month.fixedCosts.items as { name: string; shareMinor: number }[]).find(
      (i) => i.name === 'Servers',
    );
    expect(servers?.shareMinor).toBe(
      Math.floor(
        (30_000 * Number(today.slice(8)) * 2 + res.body.month.daysInMonth) / (res.body.month.daysInMonth * 2),
      ),
    );
  });

  it('refuses a future day, a malformed one and anyone but the owner', async () => {
    const bad = await get(owner, '/owner/profit?day=2999-01-01');
    expect(bad.status).toBe(400);
    expect(issueOf(bad)).toMatchObject({ field: 'day', issue: 'out_of_range' });
    expect((await get(owner, '/owner/profit?day=2026-02-30')).status).toBe(400);
    for (const u of [alice, moderator]) {
      const r = await get(u, '/owner/profit');
      expect(r.status).toBe(403);
      expect(codeOf(r)).toBe('OWNER_ONLY');
      expect((await get(u, '/owner/fixed-costs')).status).toBe(403);
      expect((await send(u, 'post', '/owner/fixed-costs', { name: 'x', monthlyMinor: 1 })).status).toBe(403);
    }
  });

  it('the owner manages the fixed costs in the app (audited); «الربح» follows at once', async () => {
    const created = await send(owner, 'post', '/owner/fixed-costs', {
      name: 'Claude',
      monthlyMinor: 6_000,
      activeFrom: '2026-06-01',
    });
    expect(created.status, JSON.stringify(created.body)).toBe(201);
    expectContract(created, 'createOwnerFixedCost');
    expect(created.body).toMatchObject({
      name: 'Claude',
      monthlyMinor: 6_000,
      currency: 'USD',
      activeTo: null,
    });
    const id = created.body.id as string;
    // $60 ÷ 30 = $2 a day, immediately (the cache is dropped).
    const p1 = await get(owner, `/owner/profit?day=${DAY}`);
    expect(p1.body.day.fixedCosts.amountMinor).toBe(1_310 + 200);
    const list = await get(owner, '/owner/fixed-costs');
    expectContract(list, 'listOwnerFixedCosts');
    expect((list.body.items as { name: string }[]).map((i) => i.name)).toEqual(
      expect.arrayContaining(['Claude', 'Servers', 'LiveKit', 'Old']),
    );
    const patched = await send(owner, 'patch', `/owner/fixed-costs/${id}`, { monthlyMinor: 9_000 });
    expect(patched.status).toBe(200);
    expectContract(patched, 'updateOwnerFixedCost');
    expect((await get(owner, `/owner/profit?day=${DAY}`)).body.day.fixedCosts.amountMinor).toBe(1_310 + 300);
    // Validation: the end before the start, a currency other than USD, an empty name, nothing to change.
    for (const body of [{ activeTo: '2026-05-01' }, { currency: 'EUR' }, { name: '  ' }, {}]) {
      expect((await send(owner, 'patch', `/owner/fixed-costs/${id}`, body)).status).toBe(400);
    }
    expect((await send(owner, 'post', '/owner/fixed-costs', { name: 'x', monthlyMinor: 0 })).status).toBe(
      400,
    );
    expect((await send(owner, 'patch', `/owner/fixed-costs/${randomUUID()}`, { name: 'x' })).status).toBe(
      404,
    );
    const del = await send(owner, 'delete', `/owner/fixed-costs/${id}`);
    expect(del.status).toBe(204);
    expect((await get(owner, `/owner/profit?day=${DAY}`)).body.day.fixedCosts.amountMinor).toBe(1_310);
    const trail = [
      ...(await audits('owner.fixed_cost.create')),
      ...(await audits('owner.fixed_cost.update')),
      ...(await audits('owner.fixed_cost.delete')),
    ].filter((a) => a.targetId === id);
    expect(trail).toHaveLength(3);
    for (const a of trail) {
      expect(a.actorUserId).toBe(owner.id);
      expect(a.metadata).toMatchObject({ via: 'app' });
    }
  });

  it('and an OWNER in the panel (owner.costs); staff get 403', async () => {
    const a = await panelLogin(owner);
    const created = await admin(a, 'post', '/admin/owner-fixed-costs', {
      name: 'Filters',
      monthlyMinor: 3_000,
      activeFrom: '2026-06-01',
      activeTo: '2026-06-30',
    });
    expect(created.status, JSON.stringify(created.body)).toBe(201);
    expectContract(created, 'createAdminOwnerFixedCost');
    const id = created.body.id as string;
    const list = await admin(a, 'get', '/admin/owner-fixed-costs');
    expectContract(list, 'listAdminOwnerFixedCosts');
    expect((list.body.items as { id: string }[]).some((i) => i.id === id)).toBe(true);
    const patched = await admin(a, 'patch', `/admin/owner-fixed-costs/${id}`, { name: 'DeepAR filters' });
    expect(patched.status).toBe(200);
    expectContract(patched, 'updateAdminOwnerFixedCost');
    expect((await get(owner, `/owner/profit?day=${DAY}`)).body.day.fixedCosts.amountMinor).toBe(1_310 + 100);
    expect((await admin(a, 'delete', `/admin/owner-fixed-costs/${id}`)).status).toBe(204);
    const trail = (await audits('owner.fixed_cost.create')).filter((x) => x.targetId === id);
    expect(trail[0]?.metadata).toMatchObject({ via: 'panel' });

    const m = await panelLogin(moderator);
    expect((await admin(m, 'get', '/admin/owner-fixed-costs')).status).toBe(403);
    expect((await admin(m, 'post', '/admin/owner-fixed-costs', { name: 'x', monthlyMinor: 1 })).status).toBe(
      403,
    );
  });
});
