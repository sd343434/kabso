/**
 * D310 (owner 2026-11-08: «ترتيب الغرف اجعله بالكرز … كل 1 مليون كوينز يرسل يصل 6.5 مليون كرزة ولصانع المحتوى 7 مليون»;
 * contract v1.86-live, CONVENTIONS §10.116): a room ranks by its cherries — what the cherry ledger credited the host AND
 * the seated guests for gifts received in this live (each send's stored share: 65 % normal → 6.5 a coin, a creator's live
 * 70 % → 7, lucky 10 % → 1). Taps never count (they stay for the charm level). `LiveRoomSummary.cherries` on the hub card,
 * `LiveScore.roomCherries` in the room / taps result / stats, the media metadata key `roomCherries`; a reversal lowers it.
 * The popularity boards and the score (PK) stay on points.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { reverseGiftCherriesIn } from '../src/modules/economy/cherry-ledger.js';
import { addGiftIn, type GiftFields } from '../src/modules/gifts/gift-catalogue.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

class FakeClock extends Clock {
  now(): Date {
    return new Date();
  }
}

interface TestUser {
  id: string;
  username: string;
  token: string;
}

interface Card {
  id: string;
  score: number;
  cherries: number;
  popular: boolean;
}

describe('D310 rooms rank by their cherries', { timeout: 300_000 }, () => {
  const media = new MemoryLiveMedia();
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
  const coins = (u: TestUser, amount: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  const gift = (code: string, fields: Partial<GiftFields>) =>
    ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, code, {
        category: 'POPULAR',
        nameAr: 'هدية',
        nameEn: 'Gift',
        priceCoins: 100,
        assetKey: `gift_${code}`,
        animationKey: null,
        sortOrder: 0,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
        ...fields,
      }),
    );
  const makeCreator = async (u: TestUser) => {
    const app = await ctx.prisma.creatorApplication.create({
      data: {
        userId: u.id,
        status: 'APPROVED',
        country: 'EG',
        category: 'COMEDY',
        links: ['https://www.tiktok.com/@creator'],
        decidedAt: new Date(),
      },
    });
    await ctx.prisma.creatorMember.create({
      data: { userId: u.id, applicationId: app.id, activatedAt: new Date() },
    });
    // D295: a creator goes live with a CREATOR hosting permission.
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'CREATOR' } });
  };
  const goLive = async (host: TestUser, opts: { creator?: boolean; mode?: string } = {}) => {
    if (!opts.creator) {
      await ctx.prisma.liveHost.upsert({
        where: { userId: host.id },
        create: { userId: host.id, source: 'ADMIN' },
        update: {},
      });
    }
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(host))
      .send({
        title: 'Cherries',
        mode: opts.mode ?? 'AUDIO',
        ...(opts.mode === 'SOLO' ? {} : { seatCount: 10 }),
      });
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
  const send = async (roomId: string, from: TestUser, to: TestUser[], giftCode: string, quantity = 1) => {
    const clientId = randomUUID();
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(from))
      .send({ giftCode, quantity, recipients: to.map((u) => u.username), source: 'COINS', clientId });
    expect([200, 201], JSON.stringify(res.body)).toContain(res.status);
    const row = await ctx.prisma.liveGift.findFirst({
      where: { senderId: from.id, clientId },
      select: { id: true },
    });
    return row!.id;
  };
  const tap = async (roomId: string, u: TestUser, count: number) => {
    const res = await ctx.http.post(`/api/v1/live/rooms/${roomId}/taps`).set(auth(u)).send({ count });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'tapLiveRoom');
    return res.body as {
      accepted: number;
      score: { total: number; roomCherries: number; hostCherries: number };
    };
  };
  const scoreParts = async (roomId: string, as: TestUser) => {
    const res = await ctx.http.get(`/api/v1/live/rooms/${roomId}`).set(auth(as));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getLiveRoom');
    expect(res.body.cherries).toBe(res.body.scoreParts.roomCherries);
    return res.body.scoreParts as {
      total: number;
      supportPoints: number;
      tapPoints: number;
      hostCherries: number;
      roomCherries: number;
    };
  };
  const popular = async (as: TestUser, query = '') => {
    const res = await ctx.http.get(`/api/v1/live/rooms?tab=popular&limit=50${query}`).set(auth(as));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listLiveRooms');
    return res.body.data as Card[];
  };
  const order = (cards: Card[], ids: string[]) => cards.map((c) => c.id).filter((id) => ids.includes(id));
  /** What the cherry ledger credited `u` for the gifts of `roomId` (net of reversals). */
  const ledgerFromRoom = async (roomId: string) => {
    const gifts = await ctx.prisma.liveGift.findMany({ where: { roomId }, select: { id: true } });
    const rows = await ctx.prisma.cherryLedgerEntry.findMany({
      where: {
        reason: { in: ['GIFT_RECEIVED', 'GIFT_REVERSAL'] },
        referenceId: { in: gifts.map((g) => g.id) },
      },
      select: { delta: true },
    });
    return rows.reduce((sum, r) => sum + Number(r.delta), 0);
  };

  let viewer: TestUser;

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        // v1.106-social (D341): this suite's arithmetic is the category share (65 %) of a host in no agency; the direct
        // share of D341 (70 % / a creator's 75 %) is covered by d341-direct-share.e2e-spec.ts.
        GIFT_DIRECT_HOST_SHARE_PERCENT: '65',
        GIFT_DIRECT_CREATOR_SHARE_PERCENT: '70',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        LIVE_RANKINGS_TIME_ZONE: 'UTC',
        LUCKY_GIFTS_ENABLED: 'true',
      },
      [
        { token: LIVE_MEDIA_PROVIDER, value: media },
        { token: Clock, value: new FakeClock() },
      ],
    );
    await gift('d310_rose', {});
    await gift('d310_lucky', { category: 'LUCKY', nameEn: 'Lucky', priceCoins: 1000 });
    viewer = await signup();
    await coins(viewer, 10_000_000);
    const adult = await ctx.http
      .put('/api/v1/me/lucky-gifts/age-confirmation')
      .set(auth(viewer))
      .send({ adult: true });
    expect(adult.status).toBe(200);
  });
  afterAll(async () => ctx?.close());

  it('orders popular by the room cherries; taps move the score but never the order or the cherries', async () => {
    const [a, b, c] = [await signup(), await signup(), await signup()];
    const roomA = await goLive(a);
    const roomB = await goLive(b);
    const roomC = await goLive(c);
    for (const r of [roomA, roomB, roomC]) await enter(r, viewer);

    // A: one normal 100-coin gift → 100 × 65 % × 10 = 650 cherries (6.5 a coin) and 10 000 points.
    await send(roomA, viewer, [a], 'd310_rose');
    // B: two of them → 1 300 cherries.
    await send(roomB, viewer, [b], 'd310_rose');
    await send(roomB, viewer, [b], 'd310_rose');
    // C: no gift, but taps (points only).
    for (let i = 0; i < 3; i++) await tap(roomC, viewer, 10);
    expect(await scoreParts(roomA, viewer)).toMatchObject({
      roomCherries: 650,
      hostCherries: 650,
      total: 10_000,
    });
    expect(await scoreParts(roomB, viewer)).toMatchObject({ roomCherries: 1300, total: 20_000 });
    const tappedC = await scoreParts(roomC, viewer);
    expect(tappedC.roomCherries).toBe(0);
    expect(tappedC.tapPoints).toBeGreaterThan(0);

    const ids = [roomA, roomB, roomC];
    let cards = await popular(viewer);
    expect(order(cards, ids)).toEqual([roomB, roomA, roomC]);
    const cardOf = (id: string) => cards.find((x) => x.id === id)!;
    expect(cardOf(roomA)).toMatchObject({ cherries: 650, score: 10_000 });
    expect(cardOf(roomB)).toMatchObject({ cherries: 1300, score: 20_000 });
    expect(cardOf(roomC).cherries).toBe(0);
    // «رائج» follows the same order (the top N of the kind by cherries).
    expect(cardOf(roomB).popular).toBe(true);

    // Many taps in A: its score passes B's points, its cherries do not move, so the order stays.
    const before = await scoreParts(roomA, viewer);
    const tapper = await signup();
    await enter(roomA, tapper);
    for (let i = 0; i < 5; i++) await tap(roomA, tapper, 10);
    const after = await scoreParts(roomA, viewer);
    expect(after.tapPoints).toBeGreaterThan(before.tapPoints);
    expect(after.roomCherries).toBe(before.roomCherries);
    const taps = await tap(roomA, viewer, 1);
    expect(taps.score.roomCherries).toBe(650);
    cards = await popular(viewer);
    expect(order(cards, ids)).toEqual([roomB, roomA, roomC]);

    // A cursor pages on the cherries key (limit 1, three pages, no repeat or skip).
    const seen: string[] = [];
    let cursor: string | null = null;
    do {
      const res = await ctx.http
        .get(`/api/v1/live/rooms?tab=popular&limit=1${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`)
        .set(auth(viewer));
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      for (const card of res.body.data as Card[]) seen.push(card.id);
      cursor = res.body.page.nextCursor as string | null;
    } while (cursor !== null);
    expect(seen.filter((id) => ids.includes(id))).toEqual([roomB, roomA, roomC]);
    expect(new Set(seen).size).toBe(seen.length);

    // The media metadata carries the room's cherries next to the score.
    // (the score's 2-second throttle: the second send's write is the trailing one).
    await vi.waitFor(
      () =>
        expect(JSON.parse(media.metadata.get(roomB) ?? '{}')).toMatchObject({
          roomCherries: 1300,
          score: 20_000,
        }),
      { timeout: 5_000, interval: 100 },
    );
    // Left out while 0 (a room with taps only keeps the metadata it had before D310).
    expect(JSON.parse(media.metadata.get(roomC) ?? '{}')).not.toHaveProperty('roomCherries');
  });

  it("counts the seated guests' cherries with the host's; a lucky gift counts 1 a coin; a reversal lowers it", async () => {
    const host = await signup();
    const guest = await signup();
    const roomId = await goLive(host);
    await enter(roomId, viewer);
    await enter(roomId, guest);
    await ctx.prisma.liveRoomSeat.create({ data: { roomId, seatIndex: 1, userId: guest.id } });

    // To the host and the seated guest at once: 650 each → the room 1 300, the host pill (D259) 650.
    const both = await send(roomId, viewer, [host, guest], 'd310_rose');
    expect(await scoreParts(roomId, viewer)).toMatchObject({ roomCherries: 1300, hostCherries: 650 });
    // To the guest alone: the room still gets it.
    await send(roomId, viewer, [guest], 'd310_rose');
    expect(await scoreParts(roomId, viewer)).toMatchObject({ roomCherries: 1950, hostCherries: 650 });

    // A lucky 1 000-coin gift: its stored 10 % share → 1 000 cherries (1 a coin), exactly what the ledger credited.
    const luckyId = await send(roomId, viewer, [host], 'd310_lucky');
    const lucky = await ctx.prisma.liveGift.findUniqueOrThrow({
      where: { id: luckyId },
      select: { hostShareBps: true },
    });
    expect(lucky.hostShareBps).toBe(1000);
    const parts = await scoreParts(roomId, viewer);
    expect(parts.roomCherries).toBe(1950 + 1000);
    expect(parts.roomCherries).toBe(await ledgerFromRoom(roomId));

    // A reversal of the two-recipient send takes both credits out of the room (and the host's out of the pill).
    await ctx.prisma.$transaction((tx) => reverseGiftCherriesIn(tx, both, new Date()));
    expect(await scoreParts(roomId, viewer)).toMatchObject({ roomCherries: 2950 - 1300, hostCherries: 1000 });
    expect((await scoreParts(roomId, viewer)).roomCherries).toBe(await ledgerFromRoom(roomId));
    // Twice changes nothing.
    await ctx.prisma.$transaction((tx) => reverseGiftCherriesIn(tx, both, new Date()));
    expect((await scoreParts(roomId, viewer)).roomCherries).toBe(1650);
    const stats = await ctx.http.get(`/api/v1/live/rooms/${roomId}/stats`).set(auth(host));
    expect(stats.status, JSON.stringify(stats.body)).toBe(200);
    expectContract(stats, 'getLiveRoomStats');
    expect(stats.body.score.roomCherries).toBe(1650);
  });

  it("a content creator's live counts 7 cherries a coin; the boards and the score stay on points", async () => {
    const creator = await signup();
    await makeCreator(creator);
    const roomId = await goLive(creator, { creator: true, mode: 'SOLO' });
    await enter(roomId, viewer);
    await send(roomId, viewer, [creator], 'd310_rose', 10);
    // 1 000 coins × 70 % × 10 = 7 000 cherries (7 a coin); the score: 100 000 points.
    const parts = await scoreParts(roomId, viewer);
    expect(parts).toMatchObject({
      roomCherries: 7000,
      hostCherries: 7000,
      supportPoints: 100_000,
      total: 100_000,
    });

    // The popularity board (hour) ranks on points: 100 a coin, as before D310.
    const board = await ctx.http.get('/api/v1/live/rankings?period=HOUR').set(auth(viewer));
    expect(board.status, JSON.stringify(board.body)).toBe(200);
    expectContract(board, 'listLiveRankings');
    const row = (board.body.data as { host: { id: string }; points: number }[]).find(
      (e) => e.host.id === creator.id,
    );
    expect(row?.points).toBe(100_000);
    const card = (await popular(viewer)).find((x) => x.id === roomId)!;
    expect(card).toMatchObject({ cherries: 7000, score: 100_000 });
  });
});
