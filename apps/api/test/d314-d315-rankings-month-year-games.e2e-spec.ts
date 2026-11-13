/**
 * D314 (owner 2026-11-08: the ranking page «التصنيف» — «هذه الساعة / اليوم / هذا الأسبوع / هذا الشهر / هذه السنة»; contract
 * v1.87-live, CONVENTIONS §10.119): MONTH and YEAR on every board, local calendar months / years in
 * LIVE_RANKINGS_TIME_ZONE, read from the monthly rollups (never the hourly rows).
 * D315 («مجنون اللعب»; v1.88-live, §10.120): players ranked by the game tickets they SPENT, written by the documented hook
 * `recordGameTicketSpendIn` (no game exists yet), the same five periods; `LiveConfig.gamesEnabled` (off by default).
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { recordGameTicketSpendIn } from '../src/modules/live/game-ticket-spends.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

/** A clock the test sets. */
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
  startsAt: string;
  endsAt: string;
  data: { rank: number; host: { id: string }; points: number }[];
  me?: { rank: number | null; points: number };
}

const ZONE = 'Asia/Riyadh'; // UTC+3, no daylight saving
/** A local Riyadh wall-clock time as an instant. */
const riyadh = (iso: string) => new Date(`${iso}+03:00`);

describe('D314 / D315 the ranking page: month, year and «مجنون اللعب»', { timeout: 300_000 }, () => {
  const media = new MemoryLiveMedia();
  const clock = new SetClock();
  let ctx: TestContext;

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
  const goLive = async (host: TestUser) => {
    await ctx.prisma.liveHost.upsert({
      where: { userId: host.id },
      create: { userId: host.id, source: 'ADMIN' },
      update: {},
    });
    const res = await ctx.http.post('/api/v1/live/rooms').set(auth(host)).send({ title: 'Board' });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const enter = async (roomId: string, u: TestUser) => {
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
  /** `count` counted taps at `at` (the first batch of a viewer counts up to 10). */
  const tapAt = async (roomId: string, u: TestUser, at: Date, count = 10) => {
    clock.at = at;
    const res = await ctx.http.post(`/api/v1/live/rooms/${roomId}/taps`).set(auth(u)).send({ count });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    return res.body.accepted as number;
  };
  const board = async (query: string, as?: TestUser): Promise<Board> => {
    const req = ctx.http.get(`/api/v1/live/rankings?${query}`);
    const res = await (as ? req.set(auth(as)) : req);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listLiveRankings');
    return res.body as Board;
  };
  const pointsOf = (b: Board, u: TestUser) => b.data.find((e) => e.host.id === u.id)?.points ?? 0;
  const spend = (u: TestUser, tickets: number, at: Date, reference: string = randomUUID()) =>
    ctx.prisma.$transaction((tx) =>
      recordGameTicketSpendIn(
        tx,
        { userId: u.id, gameCode: 'lucky_wheel', tickets: BigInt(tickets), reference, at },
        ZONE,
      ),
    );

  beforeAll(async () => {
    clock.at = riyadh('2027-01-31T23:30:00');
    ctx = await createTestApp(
      { LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600', LIVE_RANKINGS_TIME_ZONE: ZONE },
      [
        { token: Clock, value: clock },
        { token: LIVE_MEDIA_PROVIDER, value: media },
      ],
    );
  });
  afterAll(async () => ctx?.close());

  it('MONTH and YEAR windows are local calendar months and years (Riyadh), with their countdown ends', async () => {
    clock.at = riyadh('2027-02-14T10:00:00');
    const month = await board('period=MONTH');
    expect(month).toMatchObject({
      board: 'POPULARITY',
      period: 'MONTH',
      startsAt: '2027-01-31T21:00:00.000Z',
      endsAt: '2027-02-28T21:00:00.000Z',
    });
    const year = await board('period=YEAR');
    expect(year).toMatchObject({
      period: 'YEAR',
      startsAt: '2026-12-31T21:00:00.000Z',
      endsAt: '2027-12-31T21:00:00.000Z',
    });
    const bad = await ctx.http.get('/api/v1/live/rankings?period=DECADE');
    expect(bad.status).toBe(400);
    expect((await ctx.http.get('/api/v1/live/rankings?board=RICHEST')).status).toBe(400); // v1.90-live (D320): RICH is a board now
  });

  it('a month boundary at local midnight: the month resets, the year keeps both; read from the monthly rollup', async () => {
    const host = await signup();
    const fans = [await signup(), await signup()];
    clock.at = riyadh('2027-01-31T23:30:00');
    const roomId = await goLive(host);
    for (const f of fans) await enter(roomId, f);
    // 23:55 local on 31 January (20:55 UTC): January.
    expect(await tapAt(roomId, fans[0]!, riyadh('2027-01-31T23:55:00'))).toBe(10);
    // 00:05 local on 1 February (21:05 UTC, still 31 January in UTC): February.
    expect(await tapAt(roomId, fans[1]!, riyadh('2027-02-01T00:05:00'))).toBe(10);
    // A gift's points go to the month too (100 a coin).
    await ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, 'd314_rose', {
        category: 'POPULAR',
        nameAr: 'وردة',
        nameEn: 'Rose',
        priceCoins: 5,
        assetKey: 'gift_rose',
        animationKey: null,
        sortOrder: 0,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      }),
    );
    await ctx.prisma.$transaction((tx) => creditIn(tx, fans[1]!.id, 100n, 'ADMIN_GRANT', randomUUID()));
    clock.at = riyadh('2027-02-01T00:10:00');
    const sent = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(fans[1]!))
      .send({
        giftCode: 'd314_rose',
        quantity: 1,
        recipients: [host.username],
        source: 'COINS',
        clientId: randomUUID(),
      });
    expect(sent.status, JSON.stringify(sent.body)).toBe(201);

    const rows = await ctx.prisma.liveHostPointsMonthly.findMany({
      where: { hostUserId: host.id },
      orderBy: { monthStart: 'asc' },
    });
    expect(rows.map((r) => [r.monthStart.toISOString(), Number(r.points)])).toEqual([
      ['2026-12-31T21:00:00.000Z', 10],
      ['2027-01-31T21:00:00.000Z', 10 + 500],
    ]);
    // On 1 February: the month holds February only; the day too; the year both.
    clock.at = riyadh('2027-02-01T00:20:00');
    expect(pointsOf(await board('period=MONTH'), host)).toBe(510);
    expect(pointsOf(await board('period=DAY'), host)).toBe(510);
    expect(pointsOf(await board('period=YEAR'), host)).toBe(520);
    // The host's own row on the month board.
    expect((await board('period=MONTH', host)).me).toEqual({ rank: 1, points: 510 });
    // On 31 January (before local midnight): January's month board.
    clock.at = riyadh('2027-01-31T23:59:00');
    expect(pointsOf(await board('period=MONTH'), host)).toBe(10);
    // MONTH / YEAR never read the hourly rows: they stay after the hourly rows are gone.
    await ctx.prisma.liveHostPointsHourly.deleteMany({ where: { hostUserId: host.id } });
    clock.at = riyadh('2027-02-01T00:20:00');
    expect(pointsOf(await board('period=YEAR'), host)).toBe(520);
    expect(pointsOf(await board('period=HOUR'), host)).toBe(0);
  });

  it('a year boundary at local midnight on 1 January: the year resets', async () => {
    const host = await signup();
    const fans = [await signup(), await signup()];
    clock.at = riyadh('2027-12-31T23:40:00');
    const roomId = await goLive(host);
    for (const f of fans) await enter(roomId, f);
    expect(await tapAt(roomId, fans[0]!, riyadh('2027-12-31T23:50:00'))).toBe(10);
    expect(await tapAt(roomId, fans[1]!, riyadh('2028-01-01T00:02:00'), 7)).toBe(7);
    clock.at = riyadh('2028-01-01T00:05:00');
    const year = await board('period=YEAR');
    expect(year.startsAt).toBe('2027-12-31T21:00:00.000Z');
    expect(pointsOf(year, host)).toBe(7);
    clock.at = riyadh('2027-12-31T23:59:00');
    expect(pointsOf(await board('period=YEAR'), host)).toBe(10);
    // The sweeper keeps a year of monthly rows (removes those older than 400 days only).
    clock.at = riyadh('2028-01-01T00:05:00');
    await ctx.app
      .get((await import('../src/modules/live/live-rankings.service.js')).LiveRankingsService)
      .sweepRetention(riyadh('2028-06-01T00:00:00'));
    expect(await ctx.prisma.liveHostPointsMonthly.count({ where: { hostUserId: host.id } })).toBe(2);
  });

  it('«مجنون اللعب»: players by tickets spent, once per reference, five periods, `me` for any player', async () => {
    const [a, b, c] = [await signup(), await signup(), await signup()];
    // a: 3 000 this hour + 1 000 earlier this month; b: 2 500 this hour; c: 9 000 last month (this year only).
    expect(await spend(a, 3000, riyadh('2027-03-15T10:05:00'), 'round-1')).toBe(true);
    // The same reference again (a retried round) counts nothing.
    expect(await spend(a, 3000, riyadh('2027-03-15T10:06:00'), 'round-1')).toBe(false);
    expect(await spend(a, 1000, riyadh('2027-03-02T09:00:00'))).toBe(true);
    expect(await spend(b, 2500, riyadh('2027-03-15T10:30:00'))).toBe(true);
    expect(await spend(c, 9000, riyadh('2027-02-20T12:00:00'))).toBe(true);
    clock.at = riyadh('2027-03-15T10:45:00');
    const hour = await board('board=GAMES&period=HOUR');
    expect(hour.board).toBe('GAMES');
    const ids = (x: Board) => x.data.filter((e) => [a.id, b.id, c.id].includes(e.host.id));
    expect(ids(hour).map((e) => [e.host.id, e.points])).toEqual([
      [a.id, 3000],
      [b.id, 2500],
    ]);
    const month = await board('board=GAMES&period=MONTH');
    expect(ids(month).map((e) => [e.host.id, e.points])).toEqual([
      [a.id, 4000],
      [b.id, 2500],
    ]);
    const year = await board('board=GAMES&period=YEAR');
    expect(ids(year).map((e) => [e.host.id, e.points])).toEqual([
      [c.id, 9000],
      [a.id, 4000],
      [b.id, 2500],
    ]);
    expect(ids(await board('board=GAMES&period=WEEK')).map((e) => e.points)).toEqual([3000, 2500]);
    // `me` for a signed-in player (not a host); a non-player has rank null.
    expect((await board('board=GAMES&period=MONTH', b)).me).toEqual({ rank: 2, points: 2500 });
    const nobody = await signup();
    expect((await board('board=GAMES&period=MONTH', nobody)).me).toEqual({ rank: null, points: 0 });
    // The popularity board never mixes the tickets in.
    expect(ids(await board('period=MONTH'))).toEqual([]);
    // The ledger keeps the one spend per reference.
    expect(await ctx.prisma.gameTicketSpend.count({ where: { userId: a.id } })).toBe(2);
    // A blocked player is hidden from the reader.
    const block = await ctx.http.put(`/api/v1/users/${c.username}/block`).set(auth(nobody));
    expect([200, 204]).toContain(block.status);
    expect(ids(await board('board=GAMES&period=YEAR', nobody)).map((e) => e.host.id)).not.toContain(c.id);
  });

  it('LiveConfig.gamesEnabled: off by default; LIVE_GAMES_ENABLED=true turns it on', async () => {
    const off = await ctx.http.get('/api/v1/live/config');
    expect(off.status).toBe(200);
    expectContract(off, 'getLiveConfig');
    expect(off.body.gamesEnabled).toBe(false);
    const on = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_GAMES_ENABLED: 'true' });
    try {
      const res = await on.http.get('/api/v1/live/config');
      expect(res.body.gamesEnabled).toBe(true);
    } finally {
      await on.close();
    }
  });
});
