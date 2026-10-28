/**
 * D154b (owner 2026-10-28, items 15, 15b, 15c; contract v1.33-live, CONVENTIONS §10.34): traffic cards
 * «بطاقة الزيارات» — the offers, buying with coins or a card (the host, or a viewer for the host), the
 * paid slots and their FIFO queue with an honest start, one card per live, the «مميز» list, the refund
 * of a card whose live ended before it ran, the admin grant CLI — end to end against PostgreSQL +
 * Redis with the API as the DML-only runtime role. Time is a FakeClock.
 */
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { LiveBoostsService } from '../src/modules/live/live-boosts.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

class FakeClock extends Clock {
  private ms = Date.now();
  now(): Date {
    return new Date(this.ms);
  }
  advance(minutes: number): void {
    this.ms += Math.round(minutes * 60_000);
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly token: string;
}

/** Runs `pnpm boost:admin …` as on the server (migration role, a child process). */
function boostAdmin(...args: string[]): { status: number; out: string } {
  try {
    const out = execFileSync('pnpm', ['-s', 'boost:admin', ...args], {
      cwd: fileURLToPath(new URL('..', import.meta.url)),
      env: process.env,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    return { status: 0, out };
  } catch (err) {
    const e = err as { status: number; stderr: string };
    return { status: e.status, out: e.stderr };
  }
}

describe('D154b contract coverage', () => {
  it('openapi v1.33-live declares the traffic card operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'getLiveBoostOffers GET /api/v1/live/boosts/offers',
      'listActiveLiveBoosts GET /api/v1/live/boosts/active',
      'buyLiveBoost POST /api/v1/live/rooms/{roomId}/boosts',
      'listLiveRoomBoosts GET /api/v1/live/rooms/{roomId}/boosts',
    ]) {
      expect(ids).toContain(op);
    }
  });
});

describe('D154b traffic cards', { timeout: 180_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: String(payload.email).toLowerCase(),
      token: res.body.tokens.accessToken as string,
    };
  };
  const host = async (): Promise<TestUser> => {
    const u = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  const goLive = async (u: TestUser): Promise<string> => {
    const res = await ctx.http.post('/api/v1/live/rooms').set(auth(u)).send({ title: 'Boost me' });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const end = (u: TestUser, roomId: string) =>
    ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(u)).expect(200);
  const coins = (u: TestUser, amount: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  const buy = (roomId: string, u: TestUser, body: object): request.Test =>
    ctx.http
      .post(`/api/v1/live/rooms/${roomId}/boosts`)
      .set(auth(u))
      .send({ minutes: 10, source: 'COINS', clientId: randomUUID(), ...body });
  const active = async (u?: TestUser) => {
    const req = ctx.http.get('/api/v1/live/boosts/active');
    if (u) void req.set(auth(u));
    const res = await req;
    expect(res.status).toBe(200);
    expectContract(res, 'listActiveLiveBoosts');
    return res.body.data as { room: { id: string }; endsAt: string }[];
  };
  const wallet = async (u: TestUser) =>
    (await ctx.http.get('/api/v1/wallet/me').set(auth(u))).body.coins as number;
  const expectError = (res: request.Response, status: number, code: string) => {
    expect(res.status, JSON.stringify(res.body)).toBe(status);
    expect(res.body.error.code).toBe(code);
    expectContract(res, 'buyLiveBoost');
  };
  /** Ends every card of earlier tests (their lives end) so each test starts with free slots. */
  const reset = async () => {
    await ctx.prisma.liveRoom.updateMany({
      where: { status: 'LIVE' },
      data: { status: 'ENDED', endedAt: clock.now(), endReason: 'ADMIN' },
    });
    await ctx.app.get(LiveBoostsService).settle();
  };

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        LIVE_BOOST_SLOTS: '2',
        LIVE_BOOST_MAX_WAIT_MINUTES: '10',
      },
      [
        { token: Clock, value: clock },
        { token: LIVE_MEDIA_PROVIDER, value: media },
      ],
    );
  });
  afterAll(async () => ctx?.close());

  it("offers: the lengths at the configured prices with what they save, the caller's cards, the queue", async () => {
    await reset();
    const u = await signup();
    const anonymous = await ctx.http.get('/api/v1/live/boosts/offers');
    expect(anonymous.status).toBe(401);
    const res = await ctx.http.get('/api/v1/live/boosts/offers').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getLiveBoostOffers');
    expect(res.body).toMatchObject({
      slots: 2,
      maxWaitMinutes: 10,
      options: [
        { minutes: 10, priceCoins: 10_000, savePercent: 0 },
        { minutes: 20, priceCoins: 18_000, savePercent: 10 },
        { minutes: 30, priceCoins: 25_000, savePercent: 17 },
        { minutes: 60, priceCoins: 45_000, savePercent: 25 },
      ],
      cards: [],
      roomBoost: null,
    });
    expect(Date.parse(res.body.nextStartAt as string)).toBe(clock.now().getTime());
  });

  it('the host buys a card: charged, «مميز» on the list at once, the host earns nothing; one card per live', async () => {
    await reset();
    const h = await host();
    const roomId = await goLive(h);
    await coins(h, 30_000);
    const res = await buy(roomId, h, { minutes: 20 });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'buyLiveBoost');
    expect(res.body.coins).toBe(12_000);
    expect(res.body.boost).toMatchObject({
      roomId,
      minutes: 20,
      source: 'COINS',
      coinsCharged: 18_000,
      state: 'RUNNING',
      host: { username: h.username },
      buyer: { username: h.username },
    });
    expect(Date.parse(res.body.boost.startsAt as string)).toBe(clock.now().getTime());
    const ledger = await ctx.prisma.walletLedgerEntry.findMany({
      where: { userId: h.id, reason: 'LIVE_BOOST' },
    });
    expect(ledger.map((l) => Number(l.delta))).toEqual([-18_000]);
    expect((await active()).map((a) => a.room.id)).toEqual([roomId]);
    expect(media.broadcastsOf(roomId, 'boost')).toHaveLength(1);
    // No score, no points: a card is not a gift.
    const room = await ctx.http.get(`/api/v1/live/rooms/${roomId}`).set(auth(h));
    expect(room.body.score).toBe(0);
    expectError(await buy(roomId, h, {}), 409, 'BOOST_ROOM_BUSY');
    expect(await wallet(h)).toBe(12_000);
    // A retry with the same clientId answers the first card.
    const clientId = (await ctx.prisma.liveBoost.findFirstOrThrow({ where: { roomId } })).clientId;
    const retry = await buy(roomId, h, { minutes: 20, clientId });
    expect(retry.status).toBe(200);
    expect(retry.body.boost.id).toBe(res.body.boost.id);
    // 20 minutes later it is over and off the list.
    clock.advance(20);
    expect(await active()).toEqual([]);
    const list = await ctx.http.get(`/api/v1/live/rooms/${roomId}/boosts`).set(auth(h));
    expectContract(list, 'listLiveRoomBoosts');
    expect(list.body.data[0].state).toBe('DONE');
  });

  it('a viewer gifts a card to the host; a full set of slots queues the next with an honest start', async () => {
    await reset();
    const [h1, h2, h3] = [await host(), await host(), await host()];
    const [r1, r2, r3] = [await goLive(h1), await goLive(h2), await goLive(h3)];
    const fan = await signup();
    await coins(fan, 100_000);
    const a = await buy(r1, fan, { minutes: 30 });
    expect(a.status).toBe(201);
    expect(a.body.boost).toMatchObject({
      state: 'RUNNING',
      host: { username: h1.username },
      buyer: { username: fan.username },
    });
    clock.advance(5);
    const b = await buy(r2, fan, { minutes: 10 });
    expect(b.body.boost.state).toBe('RUNNING');
    // Both slots busy: r3 waits for b (ends in 10 min), not a (25 min).
    const offers = await ctx.http.get(`/api/v1/live/boosts/offers?roomId=${r3}`).set(auth(fan));
    expect(Date.parse(offers.body.nextStartAt as string)).toBe(Date.parse(b.body.boost.endsAt as string));
    const c = await buy(r3, fan, { minutes: 10 });
    expect(c.status).toBe(201);
    expect(c.body.boost.state).toBe('WAITING');
    expect(c.body.boost.startsAt).toBe(b.body.boost.endsAt);
    expect((await active(fan)).map((x) => x.room.id).sort()).toEqual([r1, r2].sort());
    const own = await ctx.http.get(`/api/v1/live/boosts/offers?roomId=${r3}`).set(auth(h3));
    expect(own.body.roomBoost).toMatchObject({ id: c.body.boost.id, state: 'WAITING' });
    // Too far ahead: a fourth live would wait 20 minutes, past LIVE_BOOST_MAX_WAIT_MINUTES (10 here).
    const h4 = await host();
    const r4 = await goLive(h4);
    const before = await wallet(fan);
    expectError(await buy(r4, fan, { minutes: 60 }), 409, 'BOOST_QUEUE_FULL');
    expect(await wallet(fan)).toBe(before);
    clock.advance(10);
    expect((await active()).map((x) => x.room.id).sort()).toEqual([r1, r3].sort());
  });

  it('a waiting card of a live that ended is cancelled and refunded; the queue moves up', async () => {
    await reset();
    const [h1, h2, h3] = [await host(), await host(), await host()];
    const [r1, r2, r3] = [await goLive(h1), await goLive(h2), await goLive(h3)];
    await coins(h1, 50_000);
    await coins(h2, 50_000);
    await coins(h3, 50_000);
    await buy(r1, h1, { minutes: 10 }).expect(201);
    await buy(r2, h2, { minutes: 20 }).expect(201);
    const waiting = await buy(r3, h3, { minutes: 10 });
    expect(waiting.body.boost.state).toBe('WAITING');
    expect(await wallet(h3)).toBe(40_000);
    await end(h3, r3);
    await ctx.app.get(LiveBoostsService).settle();
    expect(await wallet(h3)).toBe(50_000);
    const refund = await ctx.prisma.walletLedgerEntry.findMany({
      where: { userId: h3.id, reason: 'LIVE_BOOST_REFUND' },
    });
    expect(refund.map((l) => Number(l.delta))).toEqual([10_000]);
    const list = await ctx.http.get(`/api/v1/live/rooms/${r3}/boosts`).set(auth(h3));
    expect(list.body.data[0].state).toBe('CANCELLED');
    // A running card whose live ends stops there and frees its slot at once.
    const h4 = await host();
    const r4 = await goLive(h4);
    await coins(h4, 50_000);
    const next = await buy(r4, h4, { minutes: 10 });
    expect(next.body.boost.state).toBe('WAITING');
    await end(h1, r1);
    await ctx.app.get(LiveBoostsService).settle();
    const moved = await ctx.http.get(`/api/v1/live/rooms/${r4}/boosts`).set(auth(h4));
    expect(moved.body.data[0].state).toBe('RUNNING');
    expect((await active()).map((x) => x.room.id).sort()).toEqual([r2, r4].sort());
  });

  it('cards: boost-admin grants them; a card is used instead of coins; none left → 409', async () => {
    await reset();
    const h = await host();
    const roomId = await goLive(h);
    expectError(await buy(roomId, h, { source: 'CARD' }), 409, 'BOOST_CARD_INSUFFICIENT');
    expect(boostAdmin('grant', h.email, '7', '1').status).toBe(1);
    const granted = boostAdmin('grant', `@${h.username}`, '10', '2');
    expect(granted.status, granted.out).toBe(0);
    expect(granted.out).toContain('holds 2');
    expect(boostAdmin('cards', h.email).out).toContain('10 min × 2');
    const offers = await ctx.http.get('/api/v1/live/boosts/offers').set(auth(h));
    expect(offers.body.cards).toEqual([{ minutes: 10, quantity: 2 }]);
    const used = await buy(roomId, h, { source: 'CARD' });
    expect(used.status, JSON.stringify(used.body)).toBe(201);
    expect(used.body).toMatchObject({
      coins: 0,
      cards: [{ minutes: 10, quantity: 1 }],
      boost: { source: 'CARD', coinsCharged: 0 },
    });
    expect(boostAdmin('queue').out).toContain(`@${h.username}`);
    const audit = await ctx.prisma.auditLog.count({
      where: { action: 'live.boost_card.grant', targetId: h.id },
    });
    expect(audit).toBe(1);
    // Not enough coins: nothing kept.
    clock.advance(11);
    expectError(await buy(roomId, h, {}), 409, 'INSUFFICIENT_COINS');
    // An unknown length → 400.
    const bad = await buy(roomId, h, { minutes: 15 });
    expectError(bad, 400, 'VALIDATION_FAILED');
    expect(bad.body.error.details).toEqual([{ field: 'minutes', issue: 'invalid_value' }]);
  });
});
