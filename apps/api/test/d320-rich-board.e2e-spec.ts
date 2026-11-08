/**
 * D320 (owner 2026-11-08: «الأغنى» on the ranking page — users ranked by the COINS they SENT as gifts, the coin icon beside
 * their numbers; contract v1.90-live, CONVENTIONS §10.124): `GET /live/rankings?board=RICH`, the five periods of D314
 * (Riyadh local months / years), the top 20, every gift path counted at its coin value, a reversed send taken back, `me`
 * for any signed-in caller.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { reverseGiftCherriesIn } from '../src/modules/economy/cherry-ledger.js';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { addGiftCoinsSentIn } from '../src/modules/live/gift-coins-sent.js';
import { LiveRankingsService } from '../src/modules/live/live-rankings.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

class SetClock extends Clock {
  at = new Date();
  now(): Date {
    return new Date(this.at);
  }
}

interface TestUser {
  id: string;
  username: string;
  token: string;
}

interface Board {
  board: string;
  period: string;
  data: { rank: number; host: { id: string }; points: number }[];
  me?: { rank: number | null; points: number };
}

const ZONE = 'Asia/Riyadh';
const riyadh = (iso: string) => new Date(`${iso}+03:00`);

describe('D320 «الأغنى» — users by the coins they sent as gifts', { timeout: 300_000 }, () => {
  const media = new MemoryLiveMedia();
  const clock = new SetClock();
  let ctx: TestContext;
  let host: TestUser;
  let roomId: string;
  let a: TestUser;
  let b: TestUser;
  let c: TestUser;

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
  const enter = async (u: TestUser) => {
    const raw = JSON.stringify({
      event: 'participant_joined',
      room: { name: roomId },
      participant: { identity: u.id },
    });
    const res = await ctx.http
      .post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
    expect(res.status).toBe(200);
  };
  const coins = (u: TestUser, n: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(n), 'ADMIN_GRANT', randomUUID()));
  /** One gift worth [coins] (the send quantities are fixed: one gift per price). */
  const sendLive = async (u: TestUser, coins: number, at: Date) => {
    clock.at = at;
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(u))
      .send({
        giftCode: `d320_${coins}`,
        quantity: 1,
        recipients: [host.username],
        source: 'COINS',
        clientId: randomUUID(),
      });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.gift.id as string;
  };
  const board = async (query: string, as?: TestUser): Promise<Board> => {
    const req = ctx.http.get(`/api/v1/live/rankings?board=RICH&${query}`);
    const res = await (as ? req.set(auth(as)) : req);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listLiveRankings');
    expect(res.body.board).toBe('RICH');
    return res.body as Board;
  };
  const order = (bd: Board) => bd.data.map((e) => [e.host.id, e.points]);

  beforeAll(async () => {
    clock.at = riyadh('2027-03-15T10:00:00');
    ctx = await createTestApp(
      { LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600', LIVE_RANKINGS_TIME_ZONE: ZONE },
      [
        { token: Clock, value: clock },
        { token: LIVE_MEDIA_PROVIDER, value: media },
      ],
    );
    for (const price of [2000, 3000, 5000]) {
      await ctx.prisma.$transaction((tx) =>
        addGiftIn(tx, `d320_${price}`, {
          category: 'POPULAR',
          nameAr: 'وردة',
          nameEn: 'Rose',
          priceCoins: price,
          assetKey: 'gift_rose',
          animationKey: null,
          sortOrder: price,
          badge: 'NONE',
          tagCode: null,
          tagNameAr: null,
          tagNameEn: null,
        }),
      );
    }
    host = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    const live = await ctx.http.post('/api/v1/live/rooms').set(auth(host)).send({ title: 'Rich' });
    expect(live.status, JSON.stringify(live.body)).toBe(201);
    roomId = live.body.id as string;
    [a, b, c] = [await signup(), await signup(), await signup()];
    for (const u of [a, b, c]) {
      await enter(u);
      await coins(u, 100_000);
    }
  });
  afterAll(async () => ctx?.close());

  it('orders senders by the coins they sent, across a live and a direct conversation; the five periods; the month and year boundaries', async () => {
    // c: 1 000 in February (this year only, Riyadh; through the hook — the live is today's). a: 3 000 in a live + 2 000
    // in a DM + 500 this hour. b: 5 000 this hour.
    await ctx.prisma.$transaction((tx) =>
      addGiftCoinsSentIn(tx, c.id, 1000n, riyadh('2027-02-20T12:00:00'), ZONE),
    );
    await sendLive(a, 3000, riyadh('2027-03-15T10:05:00'));
    await sendLive(b, 5000, riyadh('2027-03-15T10:10:00'));
    // A gift in a direct conversation counts too (the same coin value rule).
    await ctx.http.put(`/api/v1/users/${host.username}/follow`).set(auth(a)).expect(200);
    await ctx.http.put(`/api/v1/users/${a.username}/follow`).set(auth(host)).expect(200);
    clock.at = riyadh('2027-03-15T10:20:00');
    const dm = await ctx.http.post('/api/v1/dm/gifts').set(auth(a)).send({
      to: host.username,
      giftCode: 'd320_2000',
      quantity: 1,
      source: 'COINS',
      clientId: randomUUID(),
    });
    expect(dm.status, JSON.stringify(dm.body)).toBe(201);
    // A 500-coin send straight through the hook (as a CP gift writes it), late this hour.
    await ctx.prisma.$transaction((tx) =>
      addGiftCoinsSentIn(tx, a.id, 500n, riyadh('2027-03-15T10:30:00'), ZONE),
    );

    clock.at = riyadh('2027-03-15T10:45:00');
    for (const period of ['HOUR', 'DAY', 'WEEK', 'MONTH']) {
      expect(order(await board(`period=${period}`)), period).toEqual([
        [a.id, 5500],
        [b.id, 5000],
      ]);
    }
    expect(order(await board('period=YEAR'))).toEqual([
      [a.id, 5500],
      [b.id, 5000],
      [c.id, 1000],
    ]);
    // The host received; the host sent nothing: not on the board.
    expect((await board('period=YEAR')).data.some((e) => e.host.id === host.id)).toBe(false);
    // The month boundary: on 28 Feb 23:59 local, February's board holds c only.
    clock.at = riyadh('2027-02-28T23:59:00');
    expect(order(await board('period=MONTH'))).toEqual([[c.id, 1000]]);
    // The year boundary: on 1 January 2028 the year board is empty.
    clock.at = riyadh('2028-01-01T00:01:00');
    expect((await board('period=YEAR')).data).toEqual([]);
    // Month and year come from the monthly rows (one per sender and local month).
    const rows = await ctx.prisma.giftCoinsSentMonthly.findMany({ where: { userId: a.id } });
    expect(rows.map((r) => [r.monthStart.toISOString(), Number(r.coins)])).toEqual([
      ['2027-02-28T21:00:00.000Z', 5500],
    ]);
  });

  it('`me` for any signed-in caller: their rank and coins, or no rank with 0', async () => {
    clock.at = riyadh('2027-03-15T10:50:00');
    expect((await board('period=HOUR', b)).me).toEqual({ rank: 2, points: 5000 });
    expect((await board('period=YEAR', c)).me).toEqual({ rank: 3, points: 1000 });
    const nobody = await signup();
    expect((await board('period=HOUR', nobody)).me).toEqual({ rank: null, points: 0 });
    // A guest gets no `me`.
    expect((await board('period=HOUR')).me).toBeUndefined();
  });

  it('a reversed send leaves the board (its hour and month), never below 0; reversing twice changes nothing', async () => {
    const giftId = (
      await ctx.prisma.liveGift.findFirstOrThrow({ where: { senderId: a.id, roomId }, select: { id: true } })
    ).id;
    await ctx.prisma.$transaction((tx) => reverseGiftCherriesIn(tx, giftId, new Date()));
    await ctx.prisma.$transaction((tx) => reverseGiftCherriesIn(tx, giftId, new Date()));
    clock.at = riyadh('2027-03-15T10:55:00');
    expect(order(await board('period=HOUR'))).toEqual([
      [b.id, 5000],
      [a.id, 2500],
    ]);
    expect(order(await board('period=MONTH'))).toEqual([
      [b.id, 5000],
      [a.id, 2500],
    ]);
  });

  it('the top 20 only; the sweeper keeps a year of monthly rows', async () => {
    const at = riyadh('2027-03-15T10:40:00');
    for (let i = 0; i < 21; i++) {
      const u = await signup();
      await ctx.prisma.$transaction((tx) => addGiftCoinsSentIn(tx, u.id, BigInt(10_000 + i), at, ZONE));
    }
    clock.at = riyadh('2027-03-15T10:58:00');
    const top = await board('period=HOUR');
    expect(top.data).toHaveLength(20);
    expect(top.data[0]!.points).toBe(10_020);
    // b (5 000) is now 22nd: off the list, its own row still exact.
    expect((await board('period=HOUR', b)).me).toEqual({ rank: 22, points: 5000 });
    // Retention: hourly rows after 15 days, monthly after 400.
    const swept = ctx.app.get(LiveRankingsService);
    await swept.sweepRetention(riyadh('2027-04-15T00:00:00'));
    expect(await ctx.prisma.giftCoinsSentHourly.count({ where: { userId: b.id } })).toBe(0);
    expect(await ctx.prisma.giftCoinsSentMonthly.count({ where: { userId: b.id } })).toBe(1);
  });

  it('an unknown board is a 400', async () => {
    const res = await ctx.http.get('/api/v1/live/rankings?board=RICHEST');
    expect(res.status).toBe(400);
    expectContract(res, 'listLiveRankings');
  });
});
