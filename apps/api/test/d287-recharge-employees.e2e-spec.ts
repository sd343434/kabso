/**
 * D287 (owner on staging 2026-11-02, contract v1.87-social, CONVENTIONS §10.100): a recharge agent's employees act FOR
 * the agent within their shift — they buy hosts' cherries into the agent's stock (the agent's caps and money, `actedBy`
 * the employee) and receive the agent's coin orders (the first of the agent's side to act owns the order; the others
 * read it as taken). Two permissions per employee (default ON), the honest read-only states (off shift, not allowed,
 * claimed), the notifications to the on-shift desk, the races, removals, the audit and the per-employee statistics in
 * the app and the panel. End to end against PostgreSQL + Redis.
 */
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import type request from 'supertest';
import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn, revokeRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { topUpIn } from '../src/modules/recharge/recharge-core.js';
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
interface Agent extends TestUser {
  readonly code: string;
}

const TIERS = [{ minCoins: 0, minorPerMillion: 1200 }];
const RULES = { activationMinCoins: 30_000_000, priceTiers: TIERS, currency: 'USD' };
const COOKIE = '__Host-kabso_admin';

describe('D287 contract coverage', () => {
  it('openapi v1.87-social declares the new fields, the block values, the codes and the panel operation', () => {
    const paths = openapi.paths as Record<string, Record<string, { operationId?: string }>>;
    const ops = Object.values(paths).flatMap((p) => Object.values(p).map((o) => o.operationId));
    expect(ops).toContain('listAdminRechargeAgentEmployees');
    const schemas = (openapi.components as { schemas: Record<string, Record<string, unknown>> }).schemas;
    expect((schemas.RechargeAgentSideBlock as { enum: string[] }).enum).toEqual([
      'STAFF',
      'NOT_PERMITTED',
      'CLAIMED',
      'OFF_SHIFT',
    ]);
    const required = (name: string) => (schemas[name] as { required: string[] }).required;
    expect(required('RechargeOrder')).toEqual(
      expect.arrayContaining(['claimedBy', 'claimedAt', 'viewerBlock']),
    );
    expect(required('RechargeCherryRequest')).toEqual(
      expect.arrayContaining(['viewerSide', 'actions', 'viewerBlock', 'actedBy']),
    );
    expect(required('RechargeEmployee')).toEqual(
      expect.arrayContaining(['canBuyCherries', 'receivesOrders', 'cherryPurchases', 'orders', 'kabsoTeam']),
    );
    expect(required('RechargeEmployment')).toEqual(
      expect.arrayContaining(['canBuyCherries', 'receivesOrders', 'kabsoTeam']),
    );
    expect(Object.keys((schemas.RechargeEmployeeUpdate as { properties: object }).properties)).toEqual(
      expect.arrayContaining(['canBuyCherries', 'receivesOrders']),
    );
  });
});

describe('D287 recharge employees act for the agent', { timeout: 600_000 }, () => {
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

  const activeAgent = async (coins = 30_000_000n): Promise<Agent> => {
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
      topUpIn(tx, user.id, coins, (coins * 1200n + 500_000n) / 1_000_000n, null, RULES, now()),
    );
    return { ...user, code: r.code! };
  };

  const hh = (m: number) =>
    `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
  /** A slot around now (UTC), or one tomorrow only (off shift now). */
  const shift = (on: boolean) => {
    const c = localClock(now(), 'UTC');
    if (!on) return [{ days: [c.day === 7 ? 1 : c.day + 1], start: '00:00', end: '01:00' }];
    const end = Math.min(1440, c.minutes + 120);
    return [
      { days: [c.day], start: hh(Math.max(0, c.minutes - 120)), end: end === 1440 ? '24:00' : hh(end) },
    ];
  };
  /** The agent adds `u` through the API (both permissions by default, unless given). */
  const hire = async (agent: Agent, u: TestUser, on = true, perms: Record<string, boolean> = {}) => {
    const res = await ctx.http
      .post('/api/v1/me/recharge-agent/employees')
      .set(auth(agent))
      .send({ username: u.username, timeZone: 'UTC', schedule: shift(on), ...perms });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res;
  };
  const setShift = (u: TestUser, on: boolean) =>
    ctx.prisma.rechargeEmployee.updateMany({
      where: { employeeUserId: u.id, removedAt: null },
      data: { schedule: shift(on) },
    });

  const credit = async (host: TestUser, cherries: bigint) =>
    ctx.prisma.$transaction(async (tx) => {
      const w = await tx.cherryWallet.upsert({
        where: { userId: host.id },
        create: { userId: host.id, cherries },
        update: { cherries: { increment: cherries } },
      });
      await tx.cherryLedgerEntry.create({
        data: {
          userId: host.id,
          delta: cherries,
          balanceAfter: w.cherries,
          reason: 'GIFT_RECEIVED',
          referenceId: randomUUID(),
        },
      });
    });
  const cherriesOf = async (u: TestUser) =>
    (await ctx.prisma.cherryWallet.findUnique({ where: { userId: u.id } }))?.cherries ?? 0n;
  const stockOf = async (agent: Agent) =>
    (await ctx.prisma.rechargeAgent.findUniqueOrThrow({ where: { userId: agent.id } })).stockCoins;
  const ledgerMatches = async (agent: Agent) => {
    const rows = await ctx.prisma.rechargeStockEntry.findMany({ where: { agentUserId: agent.id } });
    expect(rows.reduce((s, r) => s + r.delta, 0n)).toBe(await stockOf(agent));
  };

  const cherryCreate = (u: TestUser, body: Record<string, unknown>, key = randomUUID()) =>
    ctx.http.post('/api/v1/recharge-cherry-requests').set(auth(u)).set('Idempotency-Key', key).send(body);
  const cherryAnswer = (u: TestUser, id: string, action: string) =>
    ctx.http.post(`/api/v1/recharge-cherry-requests/${id}/${action}`).set(auth(u));
  const cherryList = (u: TestUser) => ctx.http.get('/api/v1/recharge-cherry-requests').set(auth(u));
  const notesOf = (u: TestUser, type: string) =>
    ctx.prisma.notification.count({ where: { recipientId: u.id, type: type as never } });

  const order = (buyer: TestUser, agent: Agent, coins = 1_000_000) =>
    ctx.http
      .post('/api/v1/recharge-orders')
      .set(auth(buyer))
      .set('Idempotency-Key', randomUUID())
      .send({ agentCode: agent.code, country: 'EG', coins, paymentType: 'MOBILE_WALLET' });
  const act = (u: TestUser, id: string, action: string, body: object = {}) =>
    ctx.http.post(`/api/v1/recharge-orders/${id}/${action}`).set(auth(u)).send(body);
  const details = (u: TestUser, id: string) =>
    act(u, id, 'payment-details', { method: 'MOBILE_WALLET', details: 'Vodafone Cash 0100 000 0000' });
  const getOrder = (u: TestUser, id: string) => ctx.http.get(`/api/v1/recharge-orders/${id}`).set(auth(u));
  const incoming = (u: TestUser) => ctx.http.get('/api/v1/recharge-orders?role=agent').set(auth(u));

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: clock });
    png = await sharp({ create: { width: 32, height: 24, channels: 3, background: '#3c3' } })
      .png()
      .toBuffer();
    ctx = await createTestApp(
      {
        ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
        JWT_ACCESS_TTL_SECONDS: '2592000',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '10000/900',
        RATE_LIMIT_RECHARGE_WRITE_USER: '10000/900',
        RATE_LIMIT_RECHARGE_ORDER_USER: '10000/900',
        RATE_LIMIT_RECHARGE_ORDER_ACTION_USER: '10000/900',
        MEDIA_UPLOADS_ENABLED: 'true',
        S3_BUCKET: 'kabso-media-test',
        S3_ACCESS_KEY_ID: 'test',
        S3_SECRET_ACCESS_KEY: 'test',
        MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
        LIVE_RANKINGS_TIME_ZONE: 'UTC',
        RECHARGE_AGENT_SWEEP_INTERVAL_SECONDS: '0',
      },
      [{ token: OBJECT_STORAGE, value: storage }],
    );
    expect(png.length).toBeGreaterThan(0);
  });

  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  afterEach(() => {
    vi.setSystemTime(clock);
  });

  it('the agent adds an employee with both permissions ON, switches them, and sees them on the employee', async () => {
    const agent = await activeAgent();
    const emp = await signup();
    const added = await hire(agent, emp);
    expectContract(added, 'addMyRechargeEmployee');
    expect(added.body).toMatchObject({ canBuyCherries: true, receivesOrders: true });
    expect(added.body.cherryPurchases.today).toEqual({ count: 0, coins: 0 });
    const put = await ctx.http
      .put(`/api/v1/me/recharge-agent/employees/${emp.username}`)
      .set(auth(agent))
      .send({ timeZone: 'UTC', schedule: shift(true), canBuyCherries: false });
    expect(put.status, JSON.stringify(put.body)).toBe(200);
    expectContract(put, 'updateMyRechargeEmployee');
    expect(put.body).toMatchObject({ canBuyCherries: false, receivesOrders: true });
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'recharge.employee.update', actorUserId: agent.id },
      orderBy: { createdAt: 'desc' },
    });
    expect(audit.metadata).toMatchObject({
      canBuyCherries: false,
      receivesOrders: true,
      before: { canBuyCherries: true, receivesOrders: true },
    });
    // Left out = unchanged.
    const again = await ctx.http
      .put(`/api/v1/me/recharge-agent/employees/${emp.username}`)
      .set(auth(agent))
      .send({ timeZone: 'UTC', schedule: shift(true) });
    expect(again.body).toMatchObject({ canBuyCherries: false, receivesOrders: true });
    expect(
      (
        await ctx.http
          .put(`/api/v1/me/recharge-agent/employees/${emp.username}`)
          .set(auth(agent))
          .send({ timeZone: 'UTC', schedule: shift(true), canBuyCherries: 'yes' })
      ).status,
    ).toBe(400);
    const me = await ctx.http.get('/api/v1/me/recharge-agent').set(auth(emp));
    expectContract(me, 'getMyRechargeAgent');
    expect(me.body.employment).toMatchObject({
      canBuyCherries: false,
      receivesOrders: true,
      onShiftNow: true,
    });
    const list = await ctx.http.get('/api/v1/me/recharge-agent/employees').set(auth(agent));
    expectContract(list, 'listMyRechargeEmployees');
  });

  it('an on-shift employee buys a host’s cherries for the agent: the agent’s stock, actedBy, audit, stats', async () => {
    const agent = await activeAgent();
    const emp = await signup();
    const host = await signup();
    await hire(agent, emp);
    await credit(host, 3_000_000n);
    const stockBefore = await stockOf(agent);
    const hostNotesBefore = await notesOf(host, 'RECHARGE_CHERRY_REQUEST');

    const created = await cherryCreate(emp, { host: host.username, cherries: 2_000_000 });
    expect(created.status, JSON.stringify(created.body)).toBe(201);
    expectContract(created, 'createRechargeCherryRequest');
    expect(created.body).toMatchObject({
      status: 'PENDING',
      initiatedBy: 'AGENT',
      viewerSide: 'AGENT',
      actions: ['cancel'],
      viewerBlock: null,
      agentCode: agent.code,
      coins: 186_440,
    });
    expect(created.body.agent.id).toBe(agent.id);
    expect(created.body.actedBy.id).toBe(emp.id);
    // The host is told, with the agent as the actor (the agent's name, never the employee's).
    expect(await notesOf(host, 'RECHARGE_CHERRY_REQUEST')).toBe(hostNotesBefore + 1);
    const note = await ctx.prisma.notification.findFirstOrThrow({
      where: { recipientId: host.id, type: 'RECHARGE_CHERRY_REQUEST' },
      orderBy: { createdAt: 'desc' },
      include: { actors: true },
    });
    expect(note.actors.map((a) => a.actorId)).toEqual([agent.id]);

    // The host reads the agent's request and confirms it.
    const hostView = (await cherryList(host)).body.data[0];
    expect(hostView).toMatchObject({ viewerSide: 'HOST', actions: ['confirm', 'decline'] });
    expect(hostView.agent.id).toBe(agent.id);
    const confirmed = await cherryAnswer(host, created.body.id as string, 'confirm');
    expect(confirmed.status, JSON.stringify(confirmed.body)).toBe(200);
    expect(confirmed.body.status).toBe('CONFIRMED');
    expect(await stockOf(agent)).toBe(stockBefore + 186_440n);
    expect(await cherriesOf(host)).toBe(1_000_000n);
    await ledgerMatches(agent);
    const row = await ctx.prisma.rechargeCherryRequest.findUniqueOrThrow({ where: { id: created.body.id } });
    expect(row).toMatchObject({
      agentUserId: agent.id,
      createdBy: emp.id,
      actedBy: emp.id,
      decidedBy: host.id,
    });
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'recharge.cherry.request', targetId: created.body.id },
    });
    expect(audit.actorUserId).toBe(emp.id);
    expect(audit.metadata).toMatchObject({ agent: agent.id, byEmployee: true, actedBy: emp.id });

    // The agent's per-employee statistics count it.
    const list = await ctx.http.get('/api/v1/me/recharge-agent/employees').set(auth(agent));
    const mine = (list.body.data as { user: { id: string }; cherryPurchases: unknown }[]).find(
      (e) => e.user.id === emp.id,
    );
    expect(mine?.cherryPurchases).toMatchObject({ today: { count: 1, coins: 186_440 } });
    // The agent's dashboard counts the day's cherries (whoever acted).
    const me = await ctx.http.get('/api/v1/me/recharge-agent').set(auth(agent));
    expect(me.body.agent.todayCherries).toBe(2_000_000);
  });

  it('a host’s offer notifies the agent and the allowed on-shift employees; the off-shift one reads only', async () => {
    const agent = await activeAgent();
    const [on, off, noPerm, host] = [await signup(), await signup(), await signup(), await signup()];
    await hire(agent, on, true);
    await hire(agent, off, false);
    await hire(agent, noPerm, true, { canBuyCherries: false });
    await credit(host, 2_000_000n);
    const before = await Promise.all(
      [agent, on, off, noPerm].map((u) => notesOf(u, 'RECHARGE_CHERRY_REQUEST')),
    );
    const created = await cherryCreate(host, { agentCode: agent.code, cherries: 1_000_000 });
    expect(created.status, JSON.stringify(created.body)).toBe(201);
    const after = await Promise.all(
      [agent, on, off, noPerm].map((u) => notesOf(u, 'RECHARGE_CHERRY_REQUEST')),
    );
    expect(after.map((n, i) => n - before[i]!)).toEqual([1, 1, 0, 0]);
    const id = created.body.id as string;

    // The off-shift employee reads it with the honest state and cannot act.
    const offList = await cherryList(off);
    expectContract(offList, 'listMyRechargeCherryRequests');
    expect(offList.body.data[0]).toMatchObject({
      id,
      viewerSide: 'AGENT',
      viewerBlock: 'OFF_SHIFT',
      actions: [],
    });
    const offTry = await cherryAnswer(off, id, 'confirm');
    expect(offTry.status).toBe(409);
    expect(offTry.body.error.code).toBe('RECHARGE_OFF_SHIFT');
    // Without the permission: not listed, and refused.
    expect((await cherryList(noPerm)).body.data).toEqual([]);
    const denied = await cherryAnswer(noPerm, id, 'confirm');
    expect(denied.status).toBe(403);
    expect(denied.body.error.code).toBe('RECHARGE_EMPLOYEE_NOT_PERMITTED');
    expect((await cherryCreate(noPerm, { host: host.username, cherries: 1_000_000 })).body.error.code).toBe(
      'RECHARGE_EMPLOYEE_NOT_PERMITTED',
    );
    // The wrong side's action is 400 (the employee is the agent's side: no cancel on the host's offer).
    expect((await cherryAnswer(on, id, 'cancel')).status).toBe(400);

    const stockBefore = await stockOf(agent);
    const ok = await cherryAnswer(on, id, 'confirm');
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    expectContract(ok, 'answerRechargeCherryRequest');
    expect(ok.body).toMatchObject({ status: 'CONFIRMED', actions: [] });
    expect(ok.body.actedBy.id).toBe(on.id);
    expect(await stockOf(agent)).toBe(stockBefore + 93_220n);
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'recharge.cherry.confirm', targetId: id },
    });
    expect(audit.actorUserId).toBe(on.id);
    expect(audit.metadata).toMatchObject({ byEmployee: true, actedBy: on.id, side: 'AGENT' });
    // Too late for the agent now.
    expect((await cherryAnswer(agent, id, 'decline')).body.error.code).toBe('RECHARGE_CHERRY_REQUEST_CLOSED');

    // Off shift, the employee cannot ask a host either.
    const offAsk = await cherryCreate(off, { host: host.username, cherries: 1_000_000 });
    expect(offAsk.status).toBe(409);
    expect(offAsk.body.error.code).toBe('RECHARGE_OFF_SHIFT');
    // The employee cannot be the host of their own request.
    expect((await cherryCreate(on, { host: on.username, cherries: 1_000_000 })).status).toBe(400);
  });

  it('two employees answer the same offer at once: exactly one wins, the other gets 409', async () => {
    for (let round = 0; round < 3; round++) {
      const agent = await activeAgent();
      const [e1, e2, host] = [await signup(), await signup(), await signup()];
      await hire(agent, e1);
      await hire(agent, e2);
      await credit(host, 1_000_000n);
      const created = await cherryCreate(host, { agentCode: agent.code, cherries: 1_000_000 });
      const id = created.body.id as string;
      const before = await stockOf(agent);
      const [a, b] = await Promise.all([cherryAnswer(e1, id, 'confirm'), cherryAnswer(e2, id, 'confirm')]);
      expect([a.status, b.status].sort()).toEqual([200, 409]);
      const loser = a.status === 409 ? a : b;
      expect(loser.body.error.code).toBe('RECHARGE_CHERRY_REQUEST_CLOSED');
      expect(await stockOf(agent)).toBe(before + 93_220n);
      expect(await cherriesOf(host)).toBe(0n);
      await ledgerMatches(agent);
      const winner = a.status === 200 ? e1 : e2;
      const row = await ctx.prisma.rechargeCherryRequest.findUniqueOrThrow({ where: { id } });
      expect(row.actedBy).toBe(winner.id);
    }
  });

  it('the agent’s daily cap counts the cherries of the agent and every employee', async () => {
    const agent = await activeAgent();
    await ctx.prisma.rechargeAgent.update({
      where: { userId: agent.id },
      data: { dailyCherryCap: 2_500_000n },
    });
    const emp = await signup();
    const [h1, h2, h3] = [await signup(), await signup(), await signup()];
    await hire(agent, emp);
    for (const h of [h1, h2, h3]) await credit(h, 2_000_000n);
    const r1 = await cherryCreate(agent, { host: h1.username, cherries: 1_000_000 });
    expect((await cherryAnswer(h1, r1.body.id as string, 'confirm')).status).toBe(200);
    const r2 = await cherryCreate(h2, { agentCode: agent.code, cherries: 1_000_000 });
    expect((await cherryAnswer(emp, r2.body.id as string, 'confirm')).status).toBe(200);
    // 2 000 000 today: 1 000 000 more is over 2 500 000 — refused for the employee and for the agent.
    const over = await cherryCreate(emp, { host: h3.username, cherries: 1_000_000 });
    expect(over.status).toBe(409);
    expect(over.body.error.code).toBe('RECHARGE_CHERRY_CAP_REACHED');
    const pending = await cherryCreate(emp, { host: h3.username, cherries: 500_000 });
    expect(pending.status, JSON.stringify(pending.body)).toBe(400); // below the minimum (1 000 000)
    const fits = await cherryCreate(h3, { agentCode: agent.code, cherries: 1_000_000 });
    expect(fits.status).toBe(409); // also over the cap at creation for the host's offer
    expect(fits.body.error.code).toBe('RECHARGE_CHERRY_CAP_REACHED');
  });

  it('a removed employee is refused at once (404) and no longer told', async () => {
    const agent = await activeAgent();
    const emp = await signup();
    const host = await signup();
    await hire(agent, emp);
    await credit(host, 2_000_000n);
    const created = await cherryCreate(host, { agentCode: agent.code, cherries: 1_000_000 });
    const id = created.body.id as string;
    const del = await ctx.http.delete(`/api/v1/me/recharge-agent/employees/${emp.username}`).set(auth(agent));
    expect(del.status).toBe(204);
    expect((await cherryAnswer(emp, id, 'confirm')).status).toBe(404);
    expect((await cherryCreate(emp, { host: host.username, cherries: 1_000_000 })).status).toBe(404);
    expect((await cherryList(emp)).body.data).toEqual([]);
    const buyer = await signup();
    const o = await order(buyer, agent);
    expect(o.status).toBe(201);
    expect(await notesOf(emp, 'RECHARGE_ORDER_UPDATE')).toBe(0);
    expect((await getOrder(emp, o.body.id as string)).status).toBe(404);
    expect((await incoming(emp)).status).toBe(404);
  });

  describe('the Kabso Team is never an employee (owner’s decision)', () => {
    const grant = (u: TestUser, role: string) =>
      withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, u.email, role as never)));
    const revoke = (u: TestUser, role: string) =>
      withMigrationClient((db) => db.$transaction((tx) => revokeRoleIn(tx, u.email, role as never)));
    const sell = (u: TestUser, buyer: TestUser) =>
      ctx.http
        .post('/api/v1/me/recharge-agent/sales')
        .set(auth(u))
        .set('Idempotency-Key', randomUUID())
        .send({ buyer: buyer.username, coins: 1_000 });
    const expectStaffRefusal = (res: request.Response) => {
      expect(res.status, JSON.stringify(res.body)).toBe(403);
      expect(res.body.error.code).toBe('STAFF_ACCOUNT_LIMITED');
      expect(res.body.error.details).toEqual([{ field: 'staff', issue: 'recharge_employee' }]);
    };

    it('adding a Kabso Team account is 403 RECHARGE_EMPLOYEE_IS_STAFF and stores nothing', async () => {
      const agent = await activeAgent();
      for (const role of ['MODERATION', 'SUPPORT', 'FINANCE', 'BD']) {
        const staff = await signup();
        await grant(staff, role);
        const res = await ctx.http
          .post('/api/v1/me/recharge-agent/employees')
          .set(auth(agent))
          .send({ username: staff.username, timeZone: 'UTC', schedule: shift(true) });
        expect(res.status, `${role} ${JSON.stringify(res.body)}`).toBe(403);
        expectContract(res, 'addMyRechargeEmployee');
        expect(res.body.error.code).toBe('RECHARGE_EMPLOYEE_IS_STAFF');
        expect(await ctx.prisma.rechargeEmployee.count({ where: { employeeUserId: staff.id } })).toBe(0);
        expect(
          await ctx.prisma.auditLog.count({
            where: {
              action: 'recharge.employee.add',
              actorUserId: agent.id,
              metadata: { path: ['employee'], equals: staff.id },
            },
          }),
        ).toBe(0);
      }
      // An ordinary user is still added.
      await hire(agent, await signup());
    });

    it('an employee who becomes staff reads with STAFF, is refused every act (403), is not told; the agent sees it; the role gone, they act again', async () => {
      const agent = await activeAgent();
      const emp = await signup();
      const host = await signup();
      const buyer = await signup();
      await hire(agent, emp);
      await credit(host, 3_000_000n);
      // Before: an agent's request to the host, made by the employee, and a buyer's order.
      const request0 = await cherryCreate(emp, { host: host.username, cherries: 1_000_000 });
      expect(request0.status, JSON.stringify(request0.body)).toBe(201);
      await grant(emp, 'MODERATION');

      // The agent sees why on «الموظفون».
      const list = await ctx.http.get('/api/v1/me/recharge-agent/employees').set(auth(agent));
      expectContract(list, 'listMyRechargeEmployees');
      const row = (list.body.data as { user: { id: string }; kabsoTeam: boolean }[]).find(
        (e) => e.user.id === emp.id,
      );
      expect(row?.kabsoTeam).toBe(true);
      // The employee sees it on their own state.
      const me = await ctx.http.get('/api/v1/me/recharge-agent').set(auth(emp));
      expectContract(me, 'getMyRechargeAgent');
      expect(me.body.employment).toMatchObject({ kabsoTeam: true, onShiftNow: true });

      // Selling, cherries and orders: 403 STAFF_ACCOUNT_LIMITED, nothing changed.
      const stock = await stockOf(agent);
      const sale = await sell(emp, buyer);
      expectStaffRefusal(sale);
      expectContract(sale, 'sellRechargeCoins');
      expectStaffRefusal(await cherryCreate(emp, { host: (await signup()).username, cherries: 1_000_000 }));
      expectStaffRefusal(await cherryAnswer(emp, request0.body.id as string, 'cancel'));
      const reqs = await cherryList(emp);
      expectContract(reqs, 'listMyRechargeCherryRequests');
      expect(reqs.body.data.find((r: { id: string }) => r.id === request0.body.id)).toMatchObject({
        viewerBlock: 'STAFF',
        actions: [],
      });
      const before = await notesOf(emp, 'RECHARGE_ORDER_UPDATE');
      const created = await order(buyer, agent);
      expect(created.status, JSON.stringify(created.body)).toBe(201);
      const id = created.body.id as string;
      // Not told (the agent is).
      expect(await notesOf(emp, 'RECHARGE_ORDER_UPDATE')).toBe(before);
      expect(await notesOf(agent, 'RECHARGE_ORDER_UPDATE')).toBeGreaterThan(0);
      const inbox = await incoming(emp);
      expectContract(inbox, 'listMyRechargeOrders');
      expect(inbox.body.data[0]).toMatchObject({ id, viewerBlock: 'STAFF', actions: [], claimedBy: null });
      expectStaffRefusal(await details(emp, id));
      expectStaffRefusal(await act(emp, id, 'messages', { text: 'مرحبا' }));
      expect(await stockOf(agent)).toBe(stock);
      expect((await ctx.prisma.rechargeOrder.findUniqueOrThrow({ where: { id } })).claimedBy).toBeNull();
      // A host's offer does not reach them either.
      const hostNotes = await notesOf(emp, 'RECHARGE_CHERRY_REQUEST');
      await credit(buyer, 1_000_000n);
      const offer = await cherryCreate(buyer, { agentCode: agent.code, cherries: 1_000_000 });
      expect(offer.status, JSON.stringify(offer.body)).toBe(201);
      expect(await notesOf(emp, 'RECHARGE_CHERRY_REQUEST')).toBe(hostNotes);

      // The role taken away: they act again.
      await revoke(emp, 'MODERATION');
      const again = await details(emp, id);
      expect(again.status, JSON.stringify(again.body)).toBe(200);
      expect(again.body.claimedBy.id).toBe(emp.id);
      const meAgain = await ctx.http.get('/api/v1/me/recharge-agent').set(auth(emp));
      expect(meAgain.body.employment.kabsoTeam).toBe(false);
    });
  });

  describe('the orders inbox', () => {
    it('a buyer’s order reaches the agent and the on-shift employees; the first to act owns it', async () => {
      const agent = await activeAgent();
      const [e1, e2, offE, noOrders, buyer] = [
        await signup(),
        await signup(),
        await signup(),
        await signup(),
        await signup(),
      ];
      await hire(agent, e1);
      await hire(agent, e2);
      await hire(agent, offE, false);
      await hire(agent, noOrders, true, { receivesOrders: false });
      const res = await order(buyer, agent);
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      const id = res.body.id as string;
      const told = await Promise.all(
        [agent, e1, e2, offE, noOrders].map((u) => notesOf(u, 'RECHARGE_ORDER_UPDATE')),
      );
      expect(told).toEqual([1, 1, 1, 0, 0]);

      // Visible to an on-shift employee in the inbox, actionable.
      const inbox = await incoming(e1);
      expectContract(inbox, 'listMyRechargeOrders');
      expect(inbox.body.data[0]).toMatchObject({
        id,
        viewerRole: 'EMPLOYEE',
        viewerBlock: null,
        claimedBy: null,
      });
      expect(inbox.body.data[0].actions).toContain('SEND_DETAILS');
      // Off shift: reads, no actions.
      const offInbox = await incoming(offE);
      expect(offInbox.body.data[0]).toMatchObject({ id, viewerBlock: 'OFF_SHIFT', actions: [] });
      // Without «يستقبل طلبات الشراء»: no inbox, no acting.
      const denied = await incoming(noOrders);
      expect(denied.status).toBe(403);
      expect(denied.body.error.code).toBe('RECHARGE_EMPLOYEE_NOT_PERMITTED');
      expect((await details(noOrders, id)).body.error.code).toBe('RECHARGE_EMPLOYEE_NOT_PERMITTED');

      // e1 acts first and owns it; e2 reads it as taken and is refused.
      const sent = await details(e1, id);
      expect(sent.status, JSON.stringify(sent.body)).toBe(200);
      expectContract(sent, 'sendRechargeOrderPaymentDetails');
      expect(sent.body.claimedBy.id).toBe(e1.id);
      const taken = await getOrder(e2, id);
      expectContract(taken, 'getRechargeOrder');
      expect(taken.body).toMatchObject({ viewerBlock: 'CLAIMED', actions: [] });
      expect(taken.body.claimedBy.id).toBe(e1.id);
      const refused = await act(e2, id, 'messages', { text: 'أنا هنا' });
      expect(refused.status).toBe(409);
      expect(refused.body.error.code).toBe('RECHARGE_ORDER_CLAIMED');
      const cancel = await act(e2, id, 'cancel', {});
      expect(cancel.body.error.code).toBe('RECHARGE_ORDER_CLAIMED');
      // The agent can always act.
      const agentMsg = await ctx.http
        .post(`/api/v1/recharge-orders/${id}/messages`)
        .set(auth(agent))
        .send({ text: 'تابع معك الموظف' });
      expect(agentMsg.status, JSON.stringify(agentMsg.body)).toBe(201);
      // Later events go to the agent and the owner only (and the buyer).
      const e2Before = await ctx.prisma.notification.findFirst({
        where: { recipientId: e2.id, rechargeOrderId: id },
      });
      expect((await act(buyer, id, 'notice-ack')).status).toBe(200);
      const slot = await ctx.http
        .post('/api/v1/media/uploads')
        .set(auth(buyer))
        .send({ kind: 'RECHARGE_ORDER_IMAGE', contentType: 'image/png', byteSize: png.length });
      expect(storage.upload(slot.body.uploadUrl as string, png, 'image/png')).toBe(true);
      expect((await act(buyer, id, 'paid', { proofUploadId: slot.body.uploadId })).status).toBe(200);
      const e1Note = await ctx.prisma.notification.findFirstOrThrow({
        where: { recipientId: e1.id, rechargeOrderId: id },
      });
      expect(e1Note.rechargeOrderEvent).toBe('PAID');
      const e2After = await ctx.prisma.notification.findFirst({
        where: { recipientId: e2.id, rechargeOrderId: id },
      });
      expect(e2After?.rechargeOrderEvent).toBe(e2Before?.rechargeOrderEvent);
      // The owner confirms; the coins and the audit name the employee.
      const done = await act(e1, id, 'confirm');
      expect(done.status, JSON.stringify(done.body)).toBe(200);
      expect(done.body.status).toBe('COMPLETED');
      const audit = await ctx.prisma.auditLog.findFirstOrThrow({
        where: { action: 'recharge.order.details', targetId: id },
      });
      expect(audit).toMatchObject({ actorUserId: e1.id });
      expect(audit.metadata).toMatchObject({ byEmployee: true, claimedBy: e1.id });
      const list = await ctx.http.get('/api/v1/me/recharge-agent/employees').set(auth(agent));
      const stats = (list.body.data as { user: { id: string }; orders: unknown }[]).find(
        (e) => e.user.id === e1.id,
      );
      expect(stats?.orders).toMatchObject({ today: { count: 1, coins: 1_000_000 } });
    });

    it('two employees take the same order at once: exactly one owns it, the other gets 409', async () => {
      for (let round = 0; round < 3; round++) {
        const agent = await activeAgent();
        const [e1, e2, buyer] = [await signup(), await signup(), await signup()];
        await hire(agent, e1);
        await hire(agent, e2);
        const id = (await order(buyer, agent)).body.id as string;
        const stock = await stockOf(agent);
        const [a, b] = await Promise.all([details(e1, id), details(e2, id)]);
        expect([a.status, b.status].sort()).toEqual([200, 409]);
        const loser = a.status === 409 ? a : b;
        expect(['RECHARGE_ORDER_CLAIMED', 'RECHARGE_ORDER_STATE_CHANGED']).toContain(loser.body.error.code);
        const row = await ctx.prisma.rechargeOrder.findUniqueOrThrow({ where: { id } });
        expect(row.claimedBy).toBe(a.status === 200 ? e1.id : e2.id);
        expect(await stockOf(agent)).toBe(stock - 1_000_000n);
        await ledgerMatches(agent);
      }
    });

    it('an employee whose shift ends keeps the order but cannot act until back on shift', async () => {
      const agent = await activeAgent();
      const [emp, buyer] = [await signup(), await signup()];
      await hire(agent, emp);
      const id = (await order(buyer, agent)).body.id as string;
      expect((await details(emp, id)).status).toBe(200);
      await setShift(emp, false);
      const view = await getOrder(emp, id);
      expect(view.body).toMatchObject({ viewerBlock: 'OFF_SHIFT', actions: [] });
      expect((await act(emp, id, 'messages', { text: 'x' })).body.error.code).toBe('RECHARGE_OFF_SHIFT');
      await setShift(emp, true);
      expect((await act(emp, id, 'messages', { text: 'رجعت' })).status).toBe(201);
    });
  });

  it('the panel shows the agent’s employees with what each did (recharge.agents)', async () => {
    const agent = await activeAgent();
    const emp = await signup();
    const host = await signup();
    await hire(agent, emp);
    await credit(host, 1_000_000n);
    const r = await cherryCreate(host, { agentCode: agent.code, cherries: 1_000_000 });
    expect((await cherryAnswer(emp, r.body.id as string, 'confirm')).status).toBe(200);

    const p = await signup();
    await withMigrationClient(async (db) => {
      await db.$transaction((tx) => grantRoleIn(tx, p.email, 'OWNER'));
    });
    const cookieOf = (res: request.Response): string => {
      const raw = ([] as string[]).concat(res.headers['set-cookie'] ?? []);
      const line = raw.find((c) => c.startsWith(`${COOKIE}=`));
      if (!line) throw new Error(`no session cookie in ${JSON.stringify(raw)}`);
      return line.split(';')[0]!;
    };
    const login = await ctx.http
      .post('/api/v1/admin/auth/login')
      .send({ email: p.email, password: p.password });
    const pending = cookieOf(login);
    const enrol = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment')
      .set('Cookie', pending)
      .set('X-CSRF-Token', login.body.csrfToken as string);
    advance(30_000);
    const confirm = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment/confirm')
      .set('Cookie', pending)
      .set('X-CSRF-Token', login.body.csrfToken as string)
      .send({ code: totpCode(enrol.body.secret as string, clock) });
    expect(confirm.status, JSON.stringify(confirm.body)).toBe(200);
    const cookie = cookieOf(confirm);
    const res = await ctx.http
      .get(`/api/v1/admin/recharge/agents/${agent.id}/employees`)
      .set('Cookie', cookie);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listAdminRechargeAgentEmployees');
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0]).toMatchObject({
      userId: emp.id,
      canBuyCherries: true,
      receivesOrders: true,
      removedAt: null,
      cherryPurchases: { today: { count: 1, coins: 93_220 } },
    });
    expect(
      (await ctx.http.get(`/api/v1/admin/recharge/agents/${emp.id}/employees`).set('Cookie', cookie)).status,
    ).toBe(404);
    expect((await ctx.http.get(`/api/v1/admin/recharge/agents/${agent.id}/employees`)).status).toBe(401);
  });
});
