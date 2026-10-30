/**
 * D185 (owner 2026-10-30; contract v1.54-social, CONVENTIONS §10.48, CP-028): recharge agents «وكلاء الشحن» —
 * the private application, activation by the first top-up (≥ 30 000 000 coins) with sequential codes, the stock
 * sold atomically and idempotently, employees' hours, the directory, cherry sales from hosts with two-sided
 * confirmation, and the perks (and the in-room badge on every UserSummary) removed by a suspension. End to end
 * against PostgreSQL + Redis, with the in-memory object storage.
 */
import { execFile } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { promisify } from 'node:util';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { LiveChatService } from '../src/modules/live/live-chat.service.js';
import { LiveMediaService } from '../src/modules/live/live-media.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import {
  approveApplicationIn,
  purgeApplications,
  RechargeAdminError,
  reinstateIn,
  rejectApplicationIn,
  setCapIn,
  suspendIn,
  topUpIn,
} from '../src/modules/recharge/recharge-core.js';
import { localClock } from '../src/modules/recharge/recharge-rules.js';
import { RechargeService } from '../src/modules/recharge/recharge.service.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, openapi } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

const run = promisify(execFile);

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly token: string;
}

const TIERS = [
  { minCoins: 0, minorPerMillion: 1200 },
  { minCoins: 100_000_000, minorPerMillion: 1195 },
  { minCoins: 300_000_000, minorPerMillion: 1190 },
];
const RULES = { activationMinCoins: 30_000_000, priceTiers: TIERS, currency: 'USD' };

describe('D185 contract coverage', () => {
  it('openapi v1.54-social declares the recharge operations, the private kinds and the perks', () => {
    const paths = openapi.paths as Record<string, Record<string, { operationId?: string }>>;
    const ops = Object.values(paths).flatMap((p) => Object.values(p).map((o) => o.operationId));
    for (const op of [
      'getMyRechargeAgent',
      'applyForRechargeAgent',
      'setMyRechargeAvailability',
      'sellRechargeCoins',
      'listMyRechargeSales',
      'listMyRechargeEmployees',
      'addMyRechargeEmployee',
      'updateMyRechargeEmployee',
      'removeMyRechargeEmployee',
      'listRechargeAgents',
      'getRechargeAgent',
      'createRechargeCherryRequest',
      'listMyRechargeCherryRequests',
      'answerRechargeCherryRequest',
    ]) {
      expect(ops).toContain(op);
    }
    const schemas = (openapi.components as { schemas: Record<string, Record<string, unknown>> }).schemas;
    expect((schemas.MediaKind as { enum: string[] }).enum).toEqual(
      expect.arrayContaining(['RECHARGE_AGENT_PHOTO', 'RECHARGE_AGENT_SELFIE']),
    );
    expect((schemas.PublicProfile as { required: string[] }).required).toContain('rechargeAgent');
    expect(Object.keys((schemas.UserSummary as { properties: object }).properties)).toContain(
      'rechargeAgent',
    );
    expect((schemas.CherryLedgerReason as { enum: string[] }).enum).toContain('RECHARGE_SALE');
  });
});

describe('D185 recharge agents', { timeout: 300_000 }, () => {
  const storage = new MemoryObjectStorage();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  let png: Buffer;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
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
  const upload = async (u: TestUser, kind: string): Promise<string> => {
    const slot = await ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send({ kind, contentType: 'image/png', byteSize: png.length });
    expect(slot.status, JSON.stringify(slot.body)).toBe(201);
    expect(storage.upload(slot.body.uploadUrl as string, png, 'image/png')).toBe(true);
    return slot.body.uploadId as string;
  };
  const application = async (u: TestUser, extra: Record<string, unknown> = {}) => ({
    fullName: 'محمد أحمد علي حسن',
    phone: '+201001234567',
    whatsapp: true,
    photoUploadId: await upload(u, 'RECHARGE_AGENT_PHOTO'),
    selfieUploadId: await upload(u, 'RECHARGE_AGENT_SELFIE'),
    locations: [
      { country: 'EG', cities: ['Cairo', 'Giza'] },
      { country: 'SA', cities: ['Riyadh'] },
    ],
    paymentMethods: [
      { country: 'EG', type: 'MOBILE_WALLET', details: 'Vodafone Cash 0100 SECRET' },
      { country: 'SA', type: 'BANK_TRANSFER', details: 'IBAN SA00 SECRET' },
    ],
    ...extra,
  });
  const apply = async (u: TestUser) => {
    const body = await application(u);
    const res = await ctx.http.post('/api/v1/me/recharge-agent/application').set(auth(u)).send(body);
    expectContract(res, 'applyForRechargeAgent');
    return res;
  };
  const me = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me/recharge-agent').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getMyRechargeAgent');
    return res.body as {
      status: string;
      canApply: boolean;
      agent: {
        code: string | null;
        stockCoins: number;
        todayCherries: number;
        sales: { today: { count: number } };
      };
      employment: { onShiftNow: boolean } | null;
    };
  };
  const appId = async (u: TestUser) =>
    (
      await ctx.prisma.rechargeAgentApplication.findFirstOrThrow({
        where: { userId: u.id },
        orderBy: { createdAt: 'desc' },
      })
    ).id;
  const now = () => new Date();
  /** An applicant approved and activated with `coins` (≥ 30M): returns the code. */
  const activeAgent = async (coins = 30_000_000n): Promise<{ user: TestUser; code: string }> => {
    const user = await signup();
    expect((await apply(user)).status).toBe(201);
    const id = await appId(user);
    await ctx.prisma.$transaction((tx) => approveApplicationIn(tx, id, now()));
    const r = await ctx.prisma.$transaction((tx) =>
      topUpIn(tx, user.id, coins, (coins * 1200n + 500_000n) / 1_000_000n, null, RULES, now()),
    );
    return { user, code: r.code! };
  };
  const sell = (seller: TestUser, buyer: string, coins: number, key = randomUUID()) =>
    ctx.http
      .post('/api/v1/me/recharge-agent/sales')
      .set(auth(seller))
      .set('Idempotency-Key', key)
      .send({ buyer, coins });
  const coinsOf = async (u: TestUser) =>
    (await ctx.prisma.wallet.findUnique({ where: { userId: u.id } }))?.coins ?? 0n;
  const profile = async (viewer: TestUser, u: TestUser) => {
    const res = await ctx.http.get(`/api/v1/users/${u.username}`).set(auth(viewer));
    expect(res.status).toBe(200);
    expectContract(res, 'getPublicProfile');
    return res.body as { rechargeAgent: { code: string } | null };
  };

  beforeAll(async () => {
    png = await sharp({ create: { width: 64, height: 64, channels: 3, background: '#c33' } })
      .png()
      .toBuffer();
    ctx = await createTestApp(
      {
        MEDIA_UPLOADS_ENABLED: 'true',
        S3_BUCKET: 'kabso-media-test',
        S3_ACCESS_KEY_ID: 'test',
        S3_SECRET_ACCESS_KEY: 'test',
        MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        LIVE_RANKINGS_TIME_ZONE: 'UTC',
        RECHARGE_AGENT_SWEEP_INTERVAL_SECONDS: '0',
      },
      [
        { token: OBJECT_STORAGE, value: storage },
        { token: LIVE_MEDIA_PROVIDER, value: media },
      ],
    );
  });
  afterAll(async () => ctx?.close());

  it('the application is private: stored under the private prefix, never completed, never returned', async () => {
    const u = await signup();
    expect((await me(u)).status).toBe('NONE');
    // A private upload can never be completed into a public asset.
    const pid = await upload(u, 'RECHARGE_AGENT_PHOTO');
    const complete = await ctx.http.post(`/api/v1/media/uploads/${pid}/complete`).set(auth(u));
    expect(complete.status).toBe(404);
    expectContract(complete, 'completeMediaUpload');
    // Bad shapes.
    const badBody = await application(u, { fullName: 'Two Names' });
    const bad = await ctx.http.post('/api/v1/me/recharge-agent/application').set(auth(u)).send(badBody);
    expect(bad.status).toBe(400);
    const foreign = await signup();
    const stolenBody = { ...(await application(foreign)), photoUploadId: pid };
    const stolen = await ctx.http
      .post('/api/v1/me/recharge-agent/application')
      .set(auth(foreign))
      .send(stolenBody);
    expect(stolen.status).toBe(400);
    expect(stolen.body.error.details).toEqual([{ field: 'photoUploadId', issue: 'invalid_value' }]);

    const res = await apply(u);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expect(res.body).toMatchObject({ status: 'PENDING', canApply: false, agent: null });
    const body = JSON.stringify(res.body);
    for (const secret of ['محمد', '+2010', 'SECRET', 'Cairo', 'private/']) expect(body).not.toContain(secret);
    const app = await ctx.prisma.rechargeAgentApplication.findFirstOrThrow({ where: { userId: u.id } });
    for (const key of [app.photoKey!, app.selfieKey!]) {
      expect(key.startsWith(`private/recharge-agents/${app.id}/`)).toBe(true);
      expect(storage.objects.get(key)?.cacheControl).toBe('private, no-store');
    }
    expect([...storage.objects.keys()].some((k) => k.startsWith('media/'))).toBe(false);
    // The upload became no asset: GET /media/{id} is 404 for the owner and anyone else.
    for (const viewer of [u, foreign]) {
      expect((await ctx.http.get(`/api/v1/media/${app.id}`).set(auth(viewer))).status).toBe(404);
    }
    // The submission audit names countries only.
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'recharge.application.submit', targetId: app.id },
    });
    expect(JSON.stringify(audit.metadata)).not.toContain('SECRET');
    // A second application while one is pending.
    const againBody = await application(u);
    const again = await ctx.http.post('/api/v1/me/recharge-agent/application').set(auth(u)).send(againBody);
    expect(again.status).toBe(409);
    expect(again.body.error.code).toBe('RECHARGE_APPLICATION_NOT_ALLOWED');

    // Only the admin CLI reads it, and every read is audited.
    const cli = await run('node', ['--import', 'tsx', 'src/cli/recharge-admin.ts', 'view', app.id], {
      env: { ...process.env, DOTENV_CONFIG_QUIET: 'true' },
    });
    expect(cli.stdout).toContain('محمد أحمد علي حسن');
    expect(cli.stdout).toContain('+201001234567');
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'recharge.application.view', targetId: app.id } }),
    ).toBe(1);
    const list = await run('node', ['--import', 'tsx', 'src/cli/recharge-admin.ts', 'applications'], {
      env: { ...process.env, DOTENV_CONFIG_QUIET: 'true' },
    });
    expect(list.stdout).toContain(app.id);
    expect(list.stdout).not.toContain('+201001234567');

    // Rejected with a reason; may apply again; the private data is purged after the retention.
    await ctx.prisma.$transaction((tx) => rejectApplicationIn(tx, app.id, 'Photo unclear', now()));
    const after = await me(u);
    expect(after).toMatchObject({ status: 'REJECTED', canApply: true });
    expect((after as unknown as { application: { rejectReason: string } }).application.rejectReason).toBe(
      'Photo unclear',
    );
    const deleted: string[] = [];
    const del = (keys: string[]) => {
      deleted.push(...keys);
      return storage.delete(keys);
    };
    expect(await purgeApplications(ctx.prisma, del, now(), 90, 'cli')).toBe(0);
    await ctx.prisma.rechargeAgentApplication.update({
      where: { id: app.id },
      data: { decidedAt: new Date(Date.now() - 91 * 86_400_000) },
    });
    expect(await purgeApplications(ctx.prisma, del, now(), 90, 'cli')).toBe(1);
    expect(deleted.sort()).toEqual([app.photoKey!, app.selfieKey!].sort());
    expect(storage.objects.has(app.photoKey!)).toBe(false);
    const purged = await ctx.prisma.rechargeAgentApplication.findUniqueOrThrow({ where: { id: app.id } });
    expect(purged).toMatchObject({
      fullName: null,
      phone: null,
      photoKey: null,
      locations: null,
      status: 'REJECTED',
    });
    expect(purged.purgedAt).not.toBeNull();
  });

  it('activation needs a first top-up of 30 000 000 coins; codes are sequential under concurrency', async () => {
    const u = await signup();
    expect((await apply(u)).status).toBe(201);
    const id = await appId(u);
    await ctx.prisma.$transaction((tx) => approveApplicationIn(tx, id, now()));
    expect(await me(u)).toMatchObject({ status: 'APPROVED', agent: { code: null, stockCoins: 0 } });
    await expect(
      ctx.prisma.$transaction((tx) => topUpIn(tx, u.id, 29_999_999n, 36_000n, null, RULES, now())),
    ).rejects.toBeInstanceOf(RechargeAdminError);
    // A price other than the tier's needs a note.
    await expect(
      ctx.prisma.$transaction((tx) => topUpIn(tx, u.id, 30_000_000n, 35_000n, null, RULES, now())),
    ).rejects.toBeInstanceOf(RechargeAdminError);
    expect(await me(u)).toMatchObject({ status: 'APPROVED' });

    // Six approved agents activated at the same time: consecutive codes, none twice.
    const before = (await ctx.prisma.rechargeAgentCounter.findUnique({ where: { id: 1 } }))?.lastNumber ?? 0;
    const users = [u];
    for (let i = 0; i < 5; i++) {
      const v = await signup();
      expect((await apply(v)).status).toBe(201);
      const vid = await appId(v);
      await ctx.prisma.$transaction((tx) => approveApplicationIn(tx, vid, now()));
      users.push(v);
    }
    const results = await Promise.all(
      users.map((v) =>
        ctx.prisma.$transaction((tx) => topUpIn(tx, v.id, 30_000_000n, 36_000n, null, RULES, now())),
      ),
    );
    const numbers = results.map((r) => Number(r.code!.slice(4))).sort((a, b) => a - b);
    expect(numbers).toEqual([1, 2, 3, 4, 5, 6].map((n) => before + n));
    expect(results.every((r) => r.first && r.tier === 'STANDARD' && r.stock === 30_000_000n)).toBe(true);
    expect(results[0]!.code).toMatch(/^coin[0-9]{4}$/);
    // The second top-up does not change the code; the tier follows the amount.
    const second = await ctx.prisma.$transaction((tx) =>
      topUpIn(tx, u.id, 300_000_000n, 357_000n, null, RULES, now()),
    );
    expect(second).toMatchObject({
      first: false,
      code: results[0]!.code,
      tier: 'FROM_300M',
      minorPerMillion: 1190,
    });
    const topups = await ctx.prisma.rechargeTopup.findMany({
      where: { agentUserId: u.id },
      orderBy: { createdAt: 'asc' },
    });
    expect(topups.map((t) => [t.tier, t.pricePerMillionMinor, Number(t.paidMinor), t.first])).toEqual([
      ['STANDARD', 1200, 36_000, true],
      ['FROM_300M', 1190, 357_000, false],
    ]);
    expect(await me(u)).toMatchObject({ status: 'ACTIVE', agent: { stockCoins: 330_000_000 } });
    expect(await ctx.prisma.auditLog.count({ where: { action: 'recharge.activate', targetId: u.id } })).toBe(
      1,
    );
  });

  it('a sale is one transaction: idempotent, never below 0, notified, with the buyer and seller', async () => {
    const { user: agent, code } = await activeAgent();
    const buyer = await signup();
    const first = await sell(agent, `@${buyer.username}`, 1000);
    expect(first.status, JSON.stringify(first.body)).toBe(201);
    expectContract(first, 'sellRechargeCoins');
    expect(first.body).toMatchObject({ coins: 1000, agentCode: code, stockAfter: 29_999_000 });
    expect(first.body.seller.rechargeAgent).toEqual({ code });
    expect(await coinsOf(buyer)).toBe(1000n);
    // The same key again: the same sale, nothing moved twice; another body: 409.
    const key = randomUUID();
    const a = await sell(agent, buyer.id, 500, key);
    const b = await sell(agent, buyer.id, 500, key);
    expect([a.status, b.status]).toEqual([201, 200]);
    expectContract(b, 'sellRechargeCoins');
    expect(b.body.id).toBe(a.body.id);
    expect((await sell(agent, buyer.id, 501, key)).body.error.code).toBe('IDEMPOTENCY_CONFLICT');
    expect(await coinsOf(buyer)).toBe(1500n);
    // The buyer's notification.
    const notes = await ctx.http.get('/api/v1/notifications').set(auth(buyer));
    expectContract(notes, 'listNotifications');
    const n = (notes.body.data as { type: string; target: { type: string; coins: number } }[]).filter(
      (x) => x.type === 'RECHARGE_COINS_RECEIVED',
    );
    expect(n).toHaveLength(2);
    expect(n.map((x) => x.target.coins).sort((x, y) => x - y)).toEqual([500, 1000]);
    expect(n[0]!.target.type).toBe('RECHARGE_SALE');
    // Refusals.
    expect((await sell(agent, agent.username, 10)).status).toBe(400);
    expect((await sell(agent, 'nobody_here_x', 10)).status).toBe(404);
    expect((await sell(buyer, agent.username, 10)).status).toBe(404);
    expect((await sell(agent, buyer.id, 0)).status).toBe(400);
    expect(
      (
        await ctx.http
          .post('/api/v1/me/recharge-agent/sales')
          .set(auth(agent))
          .send({ buyer: buyer.id, coins: 1 })
      ).status,
    ).toBe(400);
    // Concurrent sales larger than the stock together: some succeed, the stock never goes below 0.
    const stockBefore = BigInt((await me(agent)).agent.stockCoins);
    const tries = await Promise.all([1, 2, 3, 4, 5].map(() => sell(agent, buyer.id, 7_000_000)));
    const ok = tries.filter((t) => t.status === 201).length;
    expect(ok).toBe(Number(stockBefore / 7_000_000n));
    for (const t of tries.filter((x) => x.status !== 201)) {
      expect(t.status).toBe(409);
      expectContract(t, 'sellRechargeCoins');
      expect(t.body.error.code).toBe('RECHARGE_STOCK_INSUFFICIENT');
    }
    const after = await ctx.prisma.rechargeAgent.findUniqueOrThrow({ where: { userId: agent.id } });
    expect(after.stockCoins).toBe(stockBefore - BigInt(ok) * 7_000_000n);
    const sums = await ctx.prisma.rechargeStockEntry.aggregate({
      where: { agentUserId: agent.id },
      _sum: { delta: true },
    });
    expect(sums._sum.delta).toBe(after.stockCoins);
    expect(await coinsOf(buyer)).toBe(1500n + BigInt(ok) * 7_000_000n);
    const list = await ctx.http.get('/api/v1/me/recharge-agent/sales').set(auth(agent));
    expectContract(list, 'listMyRechargeSales');
    expect(list.body.data).toHaveLength(2 + ok);
  });

  it("an employee sells from the agent's stock only during their hours; per-employee statistics", async () => {
    const { user: agent } = await activeAgent();
    const staff = await signup();
    const buyer = await signup();
    const clock = localClock(new Date(), 'UTC');
    const today = { days: [clock.day], start: '00:00', end: '24:00' };
    const otherDay = { days: [(clock.day % 7) + 1], start: '00:00', end: '24:00' };
    const add = await ctx.http
      .post('/api/v1/me/recharge-agent/employees')
      .set(auth(agent))
      .send({ username: staff.username, timeZone: 'UTC', schedule: [today] });
    expect(add.status, JSON.stringify(add.body)).toBe(201);
    expectContract(add, 'addMyRechargeEmployee');
    expect(add.body.onShiftNow).toBe(true);
    // Not twice, not the agent, not another agent.
    const dup = await ctx.http
      .post('/api/v1/me/recharge-agent/employees')
      .set(auth(agent))
      .send({ username: staff.username, timeZone: 'UTC', schedule: [today] });
    expect(dup.body.error.code).toBe('RECHARGE_EMPLOYEE_NOT_ALLOWED');
    expect((await me(staff)).employment?.onShiftNow).toBe(true);
    expect((await me(staff)).canApply).toBe(false);

    const sold = await sell(staff, buyer.username, 2500);
    expect(sold.status, JSON.stringify(sold.body)).toBe(201);
    expect(sold.body.seller.id).toBe(staff.id);
    expect((await me(agent)).agent.stockCoins).toBe(30_000_000 - 2500);

    const off = await ctx.http
      .put(`/api/v1/me/recharge-agent/employees/${staff.username}`)
      .set(auth(agent))
      .send({ timeZone: 'UTC', schedule: [otherDay] });
    expect(off.status).toBe(200);
    expectContract(off, 'updateMyRechargeEmployee');
    expect(off.body.onShiftNow).toBe(false);
    const refused = await sell(staff, buyer.username, 100);
    expect(refused.status).toBe(409);
    expect(refused.body.error.code).toBe('RECHARGE_OFF_SHIFT');
    expect(await coinsOf(buyer)).toBe(2500n);

    // The agent's own sale; the statistics per seller.
    expect((await sell(agent, buyer.username, 100)).status).toBe(201);
    const staffSales = await ctx.http.get('/api/v1/me/recharge-agent/sales').set(auth(staff));
    expect((staffSales.body.data as { coins: number }[]).map((s) => s.coins)).toEqual([2500]);
    const list = await ctx.http.get('/api/v1/me/recharge-agent/employees').set(auth(agent));
    expectContract(list, 'listMyRechargeEmployees');
    expect(list.body.data[0].sales).toEqual({
      today: { count: 1, coins: 2500 },
      last7Days: { count: 1, coins: 2500 },
      last30Days: { count: 1, coins: 2500 },
    });
    expect((await me(agent)).agent.sales.today.count).toBe(2);

    const removed = await ctx.http
      .delete(`/api/v1/me/recharge-agent/employees/${staff.username}`)
      .set(auth(agent));
    expect(removed.status).toBe(204);
    expect((await sell(staff, buyer.username, 100)).status).toBe(404);
    expect((await me(staff)).employment).toBeNull();
  });

  it('a host sells cherries to an agent: two-sided, never locked task cherries, expiry, the daily cap', async () => {
    const { user: agent, code } = await activeAgent();
    const host = await signup();
    // 3 000 000 gift cherries (withdrawable) + 2 000 000 task cherries (locked: gifts worth < $50).
    const credit = async (cherries: bigint, reason: 'GIFT_RECEIVED' | 'TASK_REWARD') =>
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
            reason,
            referenceId: randomUUID(),
          },
        });
      });
    await credit(3_000_000n, 'GIFT_RECEIVED');
    await credit(2_000_000n, 'TASK_REWARD');
    const create = (u: TestUser, body: Record<string, unknown>, key = randomUUID()) =>
      ctx.http.post('/api/v1/recharge-cherry-requests').set(auth(u)).set('Idempotency-Key', key).send(body);
    const answer = (u: TestUser, id: string, action: string) =>
      ctx.http.post(`/api/v1/recharge-cherry-requests/${id}/${action}`).set(auth(u));

    const locked = await create(host, { agentCode: code.toUpperCase(), cherries: 4_000_000 });
    expect(locked.status).toBe(409);
    expectContract(locked, 'createRechargeCherryRequest');
    expect(locked.body.error.code).toBe('INSUFFICIENT_CHERRIES');
    expect((await create(host, { agentCode: code, cherries: 1_050_000 })).status).toBe(400);
    expect((await create(host, { agentCode: code, cherries: 900_000 })).status).toBe(400);
    expect((await create(host, { agentCode: code, host: agent.username, cherries: 1_000_000 })).status).toBe(
      400,
    );
    expect((await create(host, { host: agent.username, cherries: 1_000_000 })).status).toBe(404); // not an agent

    const req = await create(host, { agentCode: code, cherries: 2_000_000 });
    expect(req.status, JSON.stringify(req.body)).toBe(201);
    expect(req.body).toMatchObject({
      status: 'PENDING',
      cherries: 2_000_000,
      coins: 186_440,
      payoutMinor: 220,
      currency: 'USD',
      agentCode: code,
      initiatedBy: 'HOST',
    });
    expect((await create(host, { agentCode: code, cherries: 1_000_000 })).body.error.code).toBe(
      'RECHARGE_CHERRY_REQUEST_PENDING',
    );
    // The creator cannot confirm; a stranger gets 404.
    expect((await answer(host, req.body.id as string, 'confirm')).status).toBe(400);
    expect((await answer(await signup(), req.body.id as string, 'confirm')).status).toBe(404);
    const ok = await answer(agent, req.body.id as string, 'confirm');
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    expectContract(ok, 'answerRechargeCherryRequest');
    expect(ok.body.status).toBe('CONFIRMED');
    expect((await answer(agent, req.body.id as string, 'confirm')).body.error.code).toBe(
      'RECHARGE_CHERRY_REQUEST_CLOSED',
    );
    expect((await ctx.prisma.cherryWallet.findUniqueOrThrow({ where: { userId: host.id } })).cherries).toBe(
      3_000_000n,
    );
    const row = await ctx.prisma.cherryLedgerEntry.findFirstOrThrow({
      where: { userId: host.id, reason: 'RECHARGE_SALE' },
    });
    expect(row.delta).toBe(-2_000_000n);
    expect((await me(agent)).agent).toMatchObject({
      stockCoins: 30_000_000 + 186_440,
      todayCherries: 2_000_000,
    });

    // The agent asks; it expires before the host confirms.
    const asked = await create(agent, { host: host.username, cherries: 1_000_000 });
    expect(asked.status).toBe(201);
    expect(asked.body.initiatedBy).toBe('AGENT');
    await ctx.prisma.rechargeCherryRequest.update({
      where: { id: asked.body.id as string },
      data: { expiresAt: new Date(Date.now() - 1000) },
    });
    const late = await answer(host, asked.body.id as string, 'confirm');
    expect(late.status).toBe(409);
    expect(late.body.error.code).toBe('RECHARGE_CHERRY_REQUEST_CLOSED');
    const list = await ctx.http.get('/api/v1/recharge-cherry-requests').set(auth(host));
    expectContract(list, 'listMyRechargeCherryRequests');
    expect((list.body.data as { status: string }[]).map((r) => r.status)).toEqual(['EXPIRED', 'CONFIRMED']);

    // Decline and cancel.
    const d = await create(agent, { host: host.username, cherries: 1_000_000 });
    expect((await answer(agent, d.body.id as string, 'decline')).status).toBe(400);
    expect((await answer(host, d.body.id as string, 'decline')).body.status).toBe('DECLINED');
    const c = await create(host, { agentCode: code, cherries: 1_000_000 });
    expect((await answer(host, c.body.id as string, 'cancel')).body.status).toBe('CANCELLED');

    // The daily cap: 2 000 000 already today; cap 2 500 000.
    await ctx.prisma.$transaction((tx) => setCapIn(tx, agent.id, 2_500_000n));
    const capped = await create(host, { agentCode: code, cherries: 1_000_000 });
    expect(capped.status).toBe(409);
    expect(capped.body.error.code).toBe('RECHARGE_CHERRY_CAP_REACHED');
    // The cap is checked again at confirmation (a lower cap set after the request).
    await ctx.prisma.$transaction((tx) => setCapIn(tx, agent.id, null));
    const late2 = await create(host, { agentCode: code, cherries: 1_000_000 });
    expect(late2.status).toBe(201);
    await ctx.prisma.$transaction((tx) => setCapIn(tx, agent.id, 2_000_000n));
    expect((await answer(agent, late2.body.id as string, 'confirm')).body.error.code).toBe(
      'RECHARGE_CHERRY_CAP_REACHED',
    );
    expect((await ctx.prisma.cherryWallet.findUniqueOrThrow({ where: { userId: host.id } })).cherries).toBe(
      3_000_000n,
    );
    // Spending the gift cherries elsewhere first: confirmation still never touches the locked ones.
    await ctx.prisma.$transaction((tx) => setCapIn(tx, agent.id, null));
    await ctx.prisma.cherryWallet.update({ where: { userId: host.id }, data: { cherries: 2_500_000n } });
    const nope = await answer(agent, late2.body.id as string, 'confirm');
    expect(nope.status).toBe(409);
    expect(nope.body.error.code).toBe('INSUFFICIENT_CHERRIES');
    expect((await ctx.prisma.cherryWallet.findUniqueOrThrow({ where: { userId: host.id } })).cherries).toBe(
      2_500_000n,
    );
  });

  it('the directory and the perks; a suspension removes all of them at once (and the in-room badge)', async () => {
    const { user: agent, code } = await activeAgent();
    const viewer = await signup();
    const clock = localClock(new Date(), 'UTC');
    const avail = await ctx.http
      .put('/api/v1/me/recharge-agent/availability')
      .set(auth(agent))
      .send({
        timeZone: 'UTC',
        slots: [
          {
            days: [clock.day],
            start: '00:00',
            end: '24:00',
            whatsapp: '+201112223334',
            paymentMethod: 'InstaPay',
          },
        ],
      });
    expect(avail.status, JSON.stringify(avail.body)).toBe(200);
    expectContract(avail, 'setMyRechargeAvailability');

    const directory = async (country: string) => {
      const res = await ctx.http.get(`/api/v1/recharge-agents?country=${country}`).set(auth(viewer));
      expect(res.status).toBe(200);
      expectContract(res, 'listRechargeAgents');
      return res.body.data as { code: string; paymentMethodTypes: string[]; availableNow: unknown }[];
    };
    const eg = (await directory('eg')).find((l) => l.code === code);
    expect(eg).toMatchObject({
      paymentMethodTypes: ['MOBILE_WALLET'],
      availableNow: { whatsapp: '+201112223334', paymentMethod: 'InstaPay' },
    });
    expect(JSON.stringify(await directory('EG'))).not.toContain('SECRET');
    expect((await directory('MA')).find((l) => l.code === code)).toBeUndefined();
    expect((await ctx.http.get('/api/v1/recharge-agents').set(auth(viewer))).status).toBe(400);
    const one = await ctx.http.get(`/api/v1/recharge-agents/${code}`).set(auth(viewer));
    expectContract(one, 'getRechargeAgent');
    expect(one.status).toBe(200);
    expect((await profile(viewer, agent)).rechargeAgent).toEqual({ code });

    // In a live room: the host's summary, chat messages, the join line, the viewers list.
    await ctx.prisma.liveHost.create({ data: { userId: agent.id, source: 'ADMIN' } });
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(agent)).send({ title: 'Agent live' });
    expect(room.status, JSON.stringify(room.body)).toBe(201);
    const roomId = room.body.id as string;
    expect(room.body.host.rechargeAgent).toEqual({ code });
    const say = (text: string) =>
      ctx.http
        .post(`/api/v1/live/rooms/${roomId}/chat`)
        .set(auth(agent))
        .send({ text, clientId: randomUUID() });
    const msg = await say('hello');
    expect(msg.status, JSON.stringify(msg.body)).toBe(201);
    expectContract(msg, 'sendLiveChatMessage');
    expect(msg.body.author.rechargeAgent).toEqual({ code });
    const before = await ctx.http.get(`/api/v1/live/rooms/${roomId}/chat`).set(auth(viewer));
    expect((before.body.data as { author: { rechargeAgent?: unknown } }[])[0]!.author.rechargeAgent).toEqual({
      code,
    });

    const { user: guest, code: guestCode } = await activeAgent();
    const joinsOf = () => media.broadcastsOf(roomId, 'join');
    const onJoined = (id: string) =>
      ctx.app
        .get<LiveMediaService, { onJoined(r: string, i: string): Promise<void> }>(LiveMediaService)
        .onJoined(roomId, id);
    const plain = await signup();
    await onJoined(plain.id);
    await onJoined(guest.id); // the same second: an agent's join is never dropped
    expect(joinsOf().map((j) => (j.user as { rechargeAgent?: unknown }).rechargeAgent)).toEqual([
      undefined,
      { code: guestCode },
    ]);
    const viewers = await ctx.http.get(`/api/v1/live/rooms/${roomId}/viewers`).set(auth(agent));
    expectContract(viewers, 'listLiveRoomViewers');
    const vrow = (viewers.body.data as { user?: { id: string; rechargeAgent?: unknown } }[]).find(
      (v) => v.user?.id === guest.id,
    );
    expect(vrow?.user?.rechargeAgent).toEqual({ code: guestCode });

    // Suspended: no listing, no perks, no selling, no in-room badge — all at once.
    await ctx.prisma.$transaction((tx) => suspendIn(tx, agent.id, 'fraud check', now()));
    expect((await directory('EG')).find((l) => l.code === code)).toBeUndefined();
    expect((await ctx.http.get(`/api/v1/recharge-agents/${code}`).set(auth(viewer))).status).toBe(404);
    expect((await profile(viewer, agent)).rechargeAgent).toBeNull();
    const refused = await sell(agent, viewer.username, 10);
    expect(refused.status).toBe(409);
    expect(refused.body.error.code).toBe('RECHARGE_AGENT_NOT_ACTIVE');
    // The earlier message's author no longer carries the badge either.
    const chat = await ctx.http.get(`/api/v1/live/rooms/${roomId}/chat`).set(auth(viewer));
    expectContract(chat, 'listLiveChatMessages');
    const hello = (chat.body.data as { text: string; author: { rechargeAgent?: unknown } }[]).find(
      (m) => m.text === 'hello',
    );
    expect(hello).toBeDefined();
    expect(hello!.author.rechargeAgent).toBeUndefined();
    const roomNow = await ctx.http.get(`/api/v1/live/rooms/${roomId}`).set(auth(viewer));
    expect(roomNow.body.host.rechargeAgent).toBeUndefined();
    // Past the one-join-a-second window: a plain (suspended) join line, no badge.
    await new Promise((r) => setTimeout(r, 1100));
    const count = joinsOf().length;
    await ctx.app.get(LiveChatService).announceJoin(roomId, agent.id);
    expect(joinsOf()).toHaveLength(count + 1);
    expect((joinsOf().at(-1)!.user as { rechargeAgent?: unknown }).rechargeAgent).toBeUndefined();
    expect(await me(agent)).toMatchObject({ status: 'SUSPENDED' });
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'recharge.suspend', targetId: agent.id } }),
    ).toBe(1);

    // Reinstated: everything back, the same code.
    expect(await ctx.prisma.$transaction((tx) => reinstateIn(tx, agent.id, now()))).toBe('ACTIVE');
    expect((await profile(viewer, agent)).rechargeAgent).toEqual({ code });
    expect((await sell(agent, viewer.username, 10)).status).toBe(201);
    expect(ctx.app.get(RechargeService)).toBeDefined();
  });
});
