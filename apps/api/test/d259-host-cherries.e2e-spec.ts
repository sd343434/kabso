/**
 * D259 (owner 2026-11-04, contract v1.63-live, CONVENTIONS §10.95): the host pill shows the live's REAL host
 * cherries — what the cherry ledger credited the host for gifts received in this live — not the score's
 * points (100 per coin). `LiveScore.hostCherries` in the room, the taps result and the stats; the media
 * metadata key `hostCherries`; a reversal takes it back.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { reverseGiftCherriesIn } from '../src/modules/economy/cherry-ledger.js';
import { addGiftIn, type GiftFields } from '../src/modules/gifts/gift-catalogue.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

/** Real time moved by an offset. */
class FakeClock extends Clock {
  private offset = 0;
  now(): Date {
    return new Date(Date.now() + this.offset);
  }
}

interface TestUser {
  id: string;
  username: string;
  token: string;
}

describe('D259 the live host cherries', { timeout: 300_000 }, () => {
  const media = new MemoryLiveMedia();
  const clock = new FakeClock();
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
  const goLive = async (host: TestUser, extra: object = { mode: 'AUDIO', seatCount: 10 }) => {
    await ctx.prisma.liveHost.upsert({
      where: { userId: host.id },
      create: { userId: host.id, source: 'ADMIN' },
      update: {},
    });
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(host))
      .send({ title: 'Cherries', ...extra });
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
  const send = async (roomId: string, from: TestUser, to: TestUser[], giftCode: string) => {
    const clientId = randomUUID();
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(from))
      .send({ giftCode, quantity: 1, recipients: to.map((u) => u.username), source: 'COINS', clientId });
    expect([200, 201], JSON.stringify(res.body)).toContain(res.status);
    const row = await ctx.prisma.liveGift.findFirst({
      where: { senderId: from.id, clientId },
      select: { id: true },
    });
    return row!.id;
  };
  const room = async (roomId: string, as: TestUser) => {
    const res = await ctx.http.get(`/api/v1/live/rooms/${roomId}`).set(auth(as));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getLiveRoom');
    return res.body.scoreParts as {
      total: number;
      tapPoints: number;
      supportPoints: number;
      hostCherries: number;
    };
  };
  /** What the cherry ledger credited `u` for the gifts of `roomId`. */
  const ledgerFromRoom = async (u: TestUser, roomId: string) => {
    const gifts = await ctx.prisma.liveGift.findMany({ where: { roomId }, select: { id: true } });
    const rows = await ctx.prisma.cherryLedgerEntry.findMany({
      where: { userId: u.id, reason: 'GIFT_RECEIVED', referenceId: { in: gifts.map((g) => g.id) } },
      select: { delta: true },
    });
    return rows.reduce((sum, r) => sum + Number(r.delta), 0);
  };

  let host: TestUser;
  let viewer: TestUser;
  let guest: TestUser;

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        LIVE_RANKINGS_TIME_ZONE: 'UTC',
        LUCKY_GIFTS_ENABLED: 'true',
      },
      [
        { token: LIVE_MEDIA_PROVIDER, value: media },
        { token: Clock, value: clock },
      ],
    );
    await gift('d259_rose', {});
    await gift('d259_lucky', { category: 'LUCKY', nameEn: 'Lucky' });
    await gift('d259_quip', {
      category: 'QUIPS',
      nameEn: 'Quip',
      soundKey: 'room/clap',
      soundMs: 500,
      quipText: null,
    });
    [host, viewer, guest] = [await signup(), await signup(), await signup()];
    await coins(viewer, 1_000_000);
    await coins(host, 10_000);
    const adult = await ctx.http
      .put('/api/v1/me/lucky-gifts/age-confirmation')
      .set(auth(viewer))
      .send({ adult: true });
    expect(adult.status).toBe(200);
  });
  afterAll(async () => ctx?.close());

  it('counts the host share of each gift kind, never the score; only the host share of a multi-recipient send', async () => {
    const roomId = await goLive(host);
    await enter(roomId, viewer);
    await enter(roomId, guest);
    await ctx.prisma.liveRoomSeat.create({ data: { roomId, seatIndex: 1, userId: guest.id } });
    expect(await room(roomId, viewer)).toMatchObject({ hostCherries: 0, total: 0 });

    // A normal 100-coin gift: 100 × 65 % × 10 = 650 cherries (and 10 000 score points).
    await send(roomId, viewer, [host], 'd259_rose');
    const first = await room(roomId, viewer);
    expect(first).toMatchObject({ hostCherries: 650, supportPoints: 10_000 });
    // The metadata the apps follow carries it next to the score.
    expect(JSON.parse(media.metadata.get(roomId) ?? '{}')).toMatchObject({ hostCherries: 650 });

    // A quip: 50 % → 500.
    await send(roomId, viewer, [host], 'd259_quip');
    expect((await room(roomId, viewer)).hostCherries).toBe(1150);

    // The host and a seated guest at once: only the host's own share moves the pill.
    const guestBefore = await ledgerFromRoom(guest, roomId);
    await send(roomId, viewer, [host, guest], 'd259_rose');
    expect((await room(roomId, viewer)).hostCherries).toBe(1800);
    expect((await ledgerFromRoom(guest, roomId)) - guestBefore).toBe(650);

    // A lucky gift: the stored host share, exactly as the ledger credited it.
    await send(roomId, viewer, [host], 'd259_lucky');
    const afterLucky = await room(roomId, viewer);
    expect(afterLucky.hostCherries).toBe(await ledgerFromRoom(host, roomId));
    expect(afterLucky.hostCherries).toBeGreaterThan(1800);

    // The host's gift to themself counts as the ledger credits it.
    await send(roomId, host, [host], 'd259_rose');
    const self = await room(roomId, host);
    expect(self.hostCherries).toBe(await ledgerFromRoom(host, roomId));

    // The score is points, far above the cherries; the taps result and the stats carry the same cherries.
    expect(self.total).toBeGreaterThan(self.hostCherries * 10);
    const taps = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/taps`)
      .set(auth(viewer))
      .send({ count: 3 });
    expect(taps.status, JSON.stringify(taps.body)).toBe(200);
    expect(taps.body.score.hostCherries).toBe(self.hostCherries);
    const stats = await ctx.http.get(`/api/v1/live/rooms/${roomId}/stats`).set(auth(host));
    expect(stats.status, JSON.stringify(stats.body)).toBe(200);
    expectContract(stats, 'getLiveRoomStats');
    expect(stats.body.score.hostCherries).toBe(self.hostCherries);
  });

  it('a reversal of a send takes its host credit back out (never below 0)', async () => {
    const other = await signup();
    const roomId = await goLive(other, {});
    await enter(roomId, viewer);
    const giftId = await send(roomId, viewer, [other], 'd259_rose');
    expect((await room(roomId, viewer)).hostCherries).toBe(650);
    await ctx.prisma.$transaction((tx) => reverseGiftCherriesIn(tx, giftId, new Date()));
    expect((await room(roomId, viewer)).hostCherries).toBe(0);
    // Twice changes nothing.
    await ctx.prisma.$transaction((tx) => reverseGiftCherriesIn(tx, giftId, new Date()));
    expect((await room(roomId, viewer)).hostCherries).toBe(0);
  });
});
