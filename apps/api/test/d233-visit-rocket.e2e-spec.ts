/**
 * D233 (owner 2026-11-01; contract v1.51-live, CONVENTIONS §10.81): «بطاقة الزيارات» becomes a 4-stage rocket
 * «صاروخ 1 · 2 · 3 · 4» — the owner's prices in coins (200 000 / 550 000 / 1 500 000 / 3 500 000 for 10 / 20 / 30 /
 * 60 minutes), a purchase at every stage with its stage on the card and on the «مميز» list, the FIFO queue
 * unchanged, the prices edited in the admin panel (OWNER, reason + authenticator code, audited), and a card bought
 * before a price change refunded at what it cost. End to end against PostgreSQL + Redis with the API as the
 * DML-only runtime role; time is the faked `Date` of the panel helpers.
 */
import { randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { LiveBoostsService } from '../src/modules/live/live-boosts.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Admin } from './helpers/admin-panel.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';
const PRICES = [200_000, 550_000, 1_500_000, 3_500_000];

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

describe('D233 contract coverage', () => {
  it('openapi v1.51-live declares the rocket stages and the panel prices', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain('getAdminLiveBoostPrices GET /api/v1/admin/live-boost-prices');
    expect(ids).toContain('updateAdminLiveBoostPrices PUT /api/v1/admin/live-boost-prices');
  });
});

describe('D233 visit rockets', { timeout: 180_000 }, () => {
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;

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
  const host = async (): Promise<TestUser> => {
    const u = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  const goLive = async (u: TestUser): Promise<string> => {
    const res = await ctx.http.post('/api/v1/live/rooms').set(auth(u)).send({ title: 'Rocket' });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const coins = (u: TestUser, amount: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  const wallet = async (u: TestUser) =>
    (await ctx.http.get('/api/v1/wallet/me').set(auth(u))).body.coins as number;
  const buy = (roomId: string, u: TestUser, minutes: number): request.Test =>
    ctx.http
      .post(`/api/v1/live/rooms/${roomId}/boosts`)
      .set(auth(u))
      .send({ minutes, source: 'COINS', clientId: randomUUID() });
  const active = async () => {
    const res = await ctx.http.get('/api/v1/live/boosts/active');
    expect(res.status).toBe(200);
    expectContract(res, 'listActiveLiveBoosts');
    return res.body.data as { room: { id: string }; stage: number; endsAt: string }[];
  };
  const reset = async () => {
    await ctx.prisma.liveRoom.updateMany({
      where: { status: 'LIVE' },
      data: { status: 'ENDED', endedAt: new Date(), endReason: 'ADMIN' },
    });
    await ctx.app.get(LiveBoostsService).settle();
    await withMigrationClient((db) => db.liveBoostPrice.deleteMany({}));
  };

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        LIVE_BOOST_MAX_WAIT_MINUTES: '60',
        ADMIN_TOTP_KEY: ADMIN_KEY,
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        ADMIN_SESSION_MAX_SECONDS: '604800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '10000/900',
      },
      [{ token: LIVE_MEDIA_PROVIDER, value: media }],
    );
    owner = await p.makeAdmin(['OWNER']);
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it("offers: four stages at the owner's coin prices, saving nothing", async () => {
    await reset();
    const u = await signup();
    const res = await ctx.http.get('/api/v1/live/boosts/offers').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getLiveBoostOffers');
    expect(res.body.slots).toBe(3);
    expect(res.body.options).toEqual([
      { stage: 1, minutes: 10, priceCoins: 200_000, savePercent: 0 },
      { stage: 2, minutes: 20, priceCoins: 550_000, savePercent: 0 },
      { stage: 3, minutes: 30, priceCoins: 1_500_000, savePercent: 0 },
      { stage: 4, minutes: 60, priceCoins: 3_500_000, savePercent: 0 },
    ]);
  });

  it('a purchase at every stage: charged its price, its stage on the card and on the list; the 4th queues', async () => {
    await reset();
    const hosts = [await host(), await host(), await host(), await host()];
    const rooms = [];
    for (const h of hosts) rooms.push(await goLive(h));
    const fan = await signup();
    await coins(fan, PRICES.reduce((a, b) => a + b, 0) + 1);
    const cards = [];
    for (const [i, minutes] of [10, 20, 30, 60].entries()) {
      const res = await buy(rooms[i]!, fan, minutes);
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      expectContract(res, 'buyLiveBoost');
      expect(res.body.boost).toMatchObject({ stage: i + 1, minutes, coinsCharged: PRICES[i] });
      cards.push(res.body.boost as { stage: number; state: string; startsAt: string; endsAt: string });
      p.advance(1_000);
    }
    expect(cards.map((c) => c.state)).toEqual(['RUNNING', 'RUNNING', 'RUNNING', 'WAITING']);
    // 3 places: the 4th waits for the slot that frees first (stage 1's 10 minutes).
    expect(cards[3]!.startsAt).toBe(cards[0]!.endsAt);
    expect(await wallet(fan)).toBe(1);
    const ledger = await ctx.prisma.walletLedgerEntry.findMany({
      where: { userId: fan.id, reason: 'LIVE_BOOST' },
      orderBy: { createdAt: 'asc' },
    });
    expect(ledger.map((l) => -Number(l.delta))).toEqual(PRICES);
    // The list: the running ones, first started first (purchase order), each with its stage.
    expect((await active()).map((a) => [a.room.id, a.stage])).toEqual([
      [rooms[0], 1],
      [rooms[1], 2],
      [rooms[2], 3],
    ]);
    const room = await ctx.http.get(`/api/v1/live/rooms/${rooms[3]}/boosts`).set(auth(hosts[3]!));
    expectContract(room, 'listLiveRoomBoosts');
    expect(room.body.data[0]).toMatchObject({ stage: 4, state: 'WAITING' });
    // Stage 1 ends: stage 4 takes its place.
    p.advance(10 * 60_000);
    expect((await active()).map((a) => [a.room.id, a.stage])).toEqual([
      [rooms[1], 2],
      [rooms[2], 3],
      [rooms[3], 4],
    ]);
    expect(media.broadcastsOf(rooms[3]!, 'boost')).toHaveLength(1);
  });

  it('the panel: SUPPORT reads, only the OWNER edits with a reason and the code; rising prices; audited', async () => {
    await reset();
    const got = await p.send(owner, 'get', '/admin/live-boost-prices');
    expect(got.status, JSON.stringify(got.body)).toBe(200);
    expectContract(got, 'getAdminLiveBoostPrices');
    expect(got.body.stages).toEqual(
      PRICES.map((c, i) => ({
        stage: i + 1,
        minutes: [10, 20, 30, 60][i],
        priceCoins: c,
        configCoins: c,
        custom: false,
        updatedAt: null,
      })),
    );
    const support = await p.makeAdmin(['SUPPORT']);
    expect((await p.send(support, 'get', '/admin/live-boost-prices')).status).toBe(200);
    const body = (prices: number[], admin: Admin = owner) => ({
      prices,
      reason: 'owner D233',
      totpCode: p.nextCode(admin.secret),
    });
    const denied = await p.send(support, 'put', '/admin/live-boost-prices', body([1, 2, 3, 4], support));
    expect(denied.status).toBe(403);
    const falling = await p.send(owner, 'put', '/admin/live-boost-prices', body([5, 4, 6, 7]));
    expect(falling.status).toBe(400);
    expectContract(falling, 'updateAdminLiveBoostPrices');
    const badCode = await p.send(owner, 'put', '/admin/live-boost-prices', {
      prices: [1, 2, 3, 4],
      reason: 'x',
      totpCode: '000000',
    });
    expect(badCode.status).not.toBe(200);
    const saved = await p.send(
      owner,
      'put',
      '/admin/live-boost-prices',
      body([250_000, 600_000, 1_500_000, 4_000_000]),
    );
    expect(saved.status, JSON.stringify(saved.body)).toBe(200);
    expectContract(saved, 'updateAdminLiveBoostPrices');
    expect(
      saved.body.stages.map((s: { priceCoins: number; custom: boolean }) => [s.priceCoins, s.custom]),
    ).toEqual([
      [250_000, true],
      [600_000, true],
      [1_500_000, true],
      [4_000_000, true],
    ]);
    const audit = await ctx.prisma.auditLog.findMany({ where: { action: 'live.boost_prices.update' } });
    expect(audit).toHaveLength(1);
    expect(audit[0]!.actorUserId).toBe(owner.id);
    expect(audit[0]!.metadata).toMatchObject({
      reason: 'owner D233',
      before: PRICES,
      after: [250_000, 600_000, 1_500_000, 4_000_000],
    });
    // The app sees the new prices and pays them.
    const u = await signup();
    const offers = await ctx.http.get('/api/v1/live/boosts/offers').set(auth(u));
    expect(offers.body.options.map((o: { priceCoins: number }) => o.priceCoins)).toEqual([
      250_000, 600_000, 1_500_000, 4_000_000,
    ]);
    const h = await host();
    const roomId = await goLive(h);
    await coins(h, 300_000);
    const res = await buy(roomId, h, 10);
    expect(res.status).toBe(201);
    expect(res.body.boost).toMatchObject({ stage: 1, coinsCharged: 250_000 });
    expect(res.body.coins).toBe(50_000);
  });

  it('a card bought before a price change keeps what it cost: its refund gives that back', async () => {
    await reset();
    const [h1, h2, h3, h4] = [await host(), await host(), await host(), await host()];
    const [r1, r2, r3, r4] = [await goLive(h1), await goLive(h2), await goLive(h3), await goLive(h4)];
    for (const h of [h1, h2, h3, h4]) await coins(h, 1_000_000);
    await buy(r1, h1, 10).expect(201);
    await buy(r2, h2, 10).expect(201);
    await buy(r3, h3, 10).expect(201);
    const waiting = await buy(r4, h4, 20);
    expect(waiting.body.boost).toMatchObject({ state: 'WAITING', stage: 2, coinsCharged: 550_000 });
    expect(await wallet(h4)).toBe(450_000);
    const saved = await p.send(owner, 'put', '/admin/live-boost-prices', {
      prices: [100_000, 200_000, 300_000, 400_000],
      reason: 'cheaper',
      totpCode: p.nextCode(owner.secret),
    });
    expect(saved.status).toBe(200);
    await ctx.http.post(`/api/v1/live/rooms/${r4}/end`).set(auth(h4)).expect(200);
    await ctx.app.get(LiveBoostsService).settle();
    const refund = await ctx.prisma.walletLedgerEntry.findMany({
      where: { userId: h4.id, reason: 'LIVE_BOOST_REFUND' },
    });
    expect(refund.map((l) => Number(l.delta))).toEqual([550_000]);
    expect(await wallet(h4)).toBe(1_000_000);
  });
});
