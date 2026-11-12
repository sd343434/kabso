/**
 * D379 (owner 2026-11-11: the VIP perks inside live rooms; contract v1.132-social, CONVENTIONS §10.169): SEAT_EMOJI,
 * PINNED_MESSAGE, HOST_GREETING, BIG_GIFT_RAIN, TICKER_HOLD, VIEWER_LIST_PRIORITY, SEAT_REQUEST_PRIORITY, VIP_ROOM and
 * SEAT_RESERVE (SEAT_CROWN is drawn by the app only). Every perk is set on VIP 1 and used by a VIP 2 member (D258's
 * inheritance); a member without VIP, and one whose VIP ended, get nothing. End to end against PostgreSQL + Redis with
 * the API as the DML-only runtime role; the media server is the in-memory fake and the clock is fake.
 */
import { randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Prisma } from '../src/generated/prisma/client.js';
import { Clock } from '../src/common/time/clock.js';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { LiveSeatsService } from '../src/modules/live/live-seats.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, settle, type TestContext } from './helpers/test-app.js';

class FakeClock extends Clock {
  private ms = Date.now();
  now(): Date {
    return new Date(this.ms);
  }
  advance(seconds: number): void {
    this.ms += Math.round(seconds * 1000);
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

const VIP1 = '01a25200-0000-7000-8000-000000000001';
const VIP2 = '01a25200-0000-7000-8000-0000000d3792';
const VIP3 = '01a25200-0000-7000-8000-0000000d3793';
const ART = 'https://media.example.test/media/vip/VIP_1';

describe('v1.132-social contract coverage', () => {
  it('openapi declares the D379 operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'pinLiveChatMessage POST /api/v1/live/rooms/{roomId}/chat-pin',
        'unpinLiveChatMessage DELETE /api/v1/live/rooms/{roomId}/chat-pin',
        'reserveLiveSeat PUT /api/v1/live/rooms/{roomId}/seats/{seatIndex}/reservation',
        'releaseLiveSeat DELETE /api/v1/live/rooms/{roomId}/seats/{seatIndex}/reservation',
      ]),
    );
  });
});

describe('D379 VIP perks in live rooms', { timeout: 240_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  let seq = 0;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
  };
  const host = async (): Promise<TestUser> => {
    const u = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  /** Makes [u] a member of [tierId] (30 days), or ends the membership (`days` < 0). */
  const vip = async (u: TestUser, tierId: string, days = 30) => {
    const expiresAt = new Date(clock.now().getTime() + days * 86_400_000);
    const startedAt = new Date(Math.min(clock.now().getTime(), expiresAt.getTime() - 31 * 86_400_000));
    await ctx.prisma.vipMembership.upsert({
      where: { userId: u.id },
      create: { userId: u.id, tierId, startedAt, expiresAt },
      update: { tierId, startedAt, expiresAt },
    });
  };
  const goLive = async (u: TestUser, extra: object = { mode: 'AUDIO', seatCount: 5 }) => {
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: 'VIP perks', ...extra });
    return res;
  };
  const live = async (u: TestUser, extra?: object): Promise<string> => {
    const res = await goLive(u, extra);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const end = async (roomId: string, u: TestUser) => {
    expect((await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(u))).status).toBe(200);
  };
  const hook = (event: string, roomName: string, identity: string) => {
    const raw = JSON.stringify({ event, room: { name: roomName }, participant: { identity } });
    return ctx.http
      .post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
  };
  const join = async (roomId: string, u: TestUser) => {
    expect((await hook('participant_joined', roomId, u.id)).status).toBe(200);
    await settle(ctx);
  };
  const ask = async (roomId: string, u: TestUser) => {
    const asked = await ctx.http.post(`/api/v1/live/rooms/${roomId}/seat-requests`).set(auth(u)).send({});
    expect(asked.status, JSON.stringify(asked.body)).toBe(201);
    return asked.body.id as string;
  };
  const accept = async (roomId: string, h: TestUser, requestId: string) => {
    const accepted = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/seat-requests/${requestId}/accept`)
      .set(auth(h))
      .send({});
    expect(accepted.status, JSON.stringify(accepted.body)).toBe(200);
  };
  const seats = async (roomId: string, u: TestUser) => {
    const res = await ctx.http.get(`/api/v1/live/rooms/${roomId}/seats`).set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getLiveRoomSeats');
    return res.body.seats as {
      index: number;
      state: string;
      user: { id: string } | null;
      reservation?: { user: { id: string }; until: string };
    }[];
  };
  const seatOf = async (roomId: string, h: TestUser, u: TestUser) =>
    (await seats(roomId, h)).find((s) => s.user?.id === u.id)?.index ?? null;
  const say = async (roomId: string, u: TestUser, text: string) => {
    clock.advance(2);
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/chat`)
      .set(auth(u))
      .send({ text, clientId: randomUUID() });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body as { id: string };
  };
  const pin = (roomId: string, u: TestUser, messageId: string) =>
    ctx.http.post(`/api/v1/live/rooms/${roomId}/chat-pin`).set(auth(u)).send({ messageId });
  const unpin = (roomId: string, u: TestUser) =>
    ctx.http.delete(`/api/v1/live/rooms/${roomId}/chat-pin`).set(auth(u));
  const expectError = (res: request.Response, status: number, code: string, op: string) => {
    expect(res.status, JSON.stringify(res.body)).toBe(status);
    expect(res.body.error.code).toBe(code);
    expectContract(res, op);
  };
  const coins = (u: TestUser, amount: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  const gift = async (price: number): Promise<string> => {
    seq += 1;
    const code = `d379g${String(seq)}_${randomUUID().slice(0, 6)}`;
    await ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, code, {
        category: 'POPULAR',
        nameAr: `هدية ${String(seq)}`,
        nameEn: `Gift ${String(seq)}`,
        priceCoins: price,
        assetKey: `gift_${code}`,
        animationKey: null,
        sortOrder: seq,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      }),
    );
    return code;
  };
  const sendGift = async (roomId: string, from: TestUser, to: TestUser, code: string, quantity = 1) => {
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(from))
      .send({ giftCode: code, quantity, recipients: [to.username], source: 'COINS', clientId: randomUUID() });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    await settle(ctx);
    return res.body as { gift: { id: string } };
  };

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        LIVE_RANKINGS_TIME_ZONE: 'UTC',
      },
      [
        { token: Clock, value: clock },
        { token: LIVE_MEDIA_PROVIDER, value: media },
      ],
    );
    // VIP 2 and VIP 3 above the seeded VIP 1; every D379 perk on VIP 1 only (inherited by the tiers above).
    await ctx.prisma.vipTier.createMany({
      data: [
        {
          id: VIP2,
          code: 'VIP_2',
          nameAr: 'في آي بي 2',
          nameEn: 'VIP 2',
          sortOrder: 2,
          color: '#1E6FD9',
          priceCoins: 2_000_000n,
          durationDays: 30,
          enabled: true,
        },
        {
          id: VIP3,
          code: 'VIP_3',
          nameAr: 'في آي بي 3',
          nameEn: 'VIP 3',
          sortOrder: 3,
          color: '#8E2DE2',
          priceCoins: 3_000_000n,
          durationDays: 30,
          enabled: true,
        },
      ],
    });
    const perk = (code: string, n: number, value: Prisma.InputJsonValue | null, art: object = {}) => ({
      tierId: VIP1,
      code,
      titleAr: code,
      titleEn: code,
      sortOrder: 100 + n,
      enabled: true,
      value: value === null ? Prisma.DbNull : value,
      ...art,
    });
    await ctx.prisma.vipTierPerk.createMany({
      data: [
        perk('SEAT_EMOJI', 1, [`${ART}/e1.svga`, `${ART}/e2.png`]),
        perk('PINNED_MESSAGE', 2, { count: 2, seconds: 30 }),
        perk('HOST_GREETING', 3, null),
        perk('SEAT_CROWN', 4, null, { still: `${ART}/crown.png`, artWidth: 300, artHeight: 200 }),
        perk('BIG_GIFT_RAIN', 5, 1_000, { still: `${ART}/rain.png`, artWidth: 750, artHeight: 1334 }),
        perk('TICKER_HOLD', 6, 5),
        perk('VIEWER_LIST_PRIORITY', 7, null),
        perk('SEAT_REQUEST_PRIORITY', 8, null),
        perk('VIP_ROOM', 9, 'VIP_2'),
        perk('SEAT_RESERVE', 10, 10),
      ],
    });
  });
  afterAll(async () => ctx?.close());

  it('SEAT_EMOJI: a holder (inherited) plays their pack file; a plain member and an ended VIP are refused', async () => {
    const h = await host();
    const holder = await signup();
    const plain = await signup();
    await vip(holder, VIP2);
    const roomId = await live(h);
    for (const u of [holder, plain]) {
      await join(roomId, u);
      await accept(roomId, h, await ask(roomId, u));
    }
    const play = (u: TestUser, token: string) =>
      ctx.http.post(`/api/v1/live/rooms/${roomId}/seat-emoji`).set(auth(u)).send({ token });

    const ok = await play(holder, ':vip_2:');
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    expectContract(ok, 'sendLiveSeatEmoji');
    expect(ok.body).toMatchObject({ token: ':vip_2:', vipArt: `${ART}/e2.png` });
    expect(media.broadcastsOf(roomId, 'seat-emoji').at(-1)).toMatchObject({ vipArt: `${ART}/e2.png` });
    clock.advance(3);
    expectError(await play(holder, ':vip_3:'), 400, 'VALIDATION_FAILED', 'sendLiveSeatEmoji');
    const theirs = await play(plain, ':vip_1:');
    expectError(theirs, 409, 'VIP_UNAVAILABLE', 'sendLiveSeatEmoji');
    expect(theirs.body.error.details).toEqual([{ field: 'perk', issue: 'no_perk' }]);
    // The owner's packs are unchanged for everyone.
    const owners = await play(plain, ':kabi_love:');
    expect(owners.status).toBe(200);
    expect(owners.body.vipArt).toBeNull();
    // The VIP ends: the pack is gone.
    await vip(holder, VIP2, -1);
    clock.advance(3);
    expectError(await play(holder, ':vip_1:'), 409, 'VIP_UNAVAILABLE', 'sendLiveSeatEmoji');
    await end(roomId, h);
  });

  it('PINNED_MESSAGE: own message only, one pin per room (LIVE_PIN_BUSY + Retry-After), a day limit, unpin rules, deleted with the message', async () => {
    const h = await host();
    const holder = await signup();
    const other = await signup();
    const plain = await signup();
    await vip(holder, VIP2);
    await vip(other, VIP1);
    const roomId = await live(h, { mode: 'SOLO' });
    for (const u of [holder, other, plain]) await join(roomId, u);

    const m1 = await say(roomId, holder, 'hello everyone');
    const om = await say(roomId, other, 'mine too');
    const pm = await say(roomId, plain, 'plain line');

    // Someone else's message → 404; a plain member → 409 no_perk.
    expectError(await pin(roomId, holder, om.id), 404, 'NOT_FOUND', 'pinLiveChatMessage');
    const noPerk = await pin(roomId, plain, pm.id);
    expectError(noPerk, 409, 'VIP_UNAVAILABLE', 'pinLiveChatMessage');
    expect(noPerk.body.error.details).toEqual([{ field: 'perk', issue: 'no_perk' }]);

    const first = await pin(roomId, holder, m1.id);
    expect(first.status, JSON.stringify(first.body)).toBe(201);
    expectContract(first, 'pinLiveChatMessage');
    expect(first.body).toMatchObject({ messageId: m1.id, text: 'hello everyone', author: { id: holder.id } });
    expect(new Date(first.body.until as string).getTime() - clock.now().getTime()).toBe(30_000);
    expect(media.broadcastsOf(roomId, 'chat-pin').at(-1)).toMatchObject({ pin: { id: first.body.id } });
    const read = await ctx.http.get(`/api/v1/live/rooms/${roomId}/chat`).set(auth(plain));
    expectContract(read, 'listLiveChatMessages');
    expect(read.body.pin).toMatchObject({ id: first.body.id });

    // Another holder while it shows: refused, not queued.
    clock.advance(10);
    const busy = await pin(roomId, other, om.id);
    expectError(busy, 409, 'LIVE_PIN_BUSY', 'pinLiveChatMessage');
    expect(busy.headers['retry-after']).toBe('20');

    // A plain viewer may not take it down; the host may.
    expectError(await unpin(roomId, plain), 403, 'AUTH_FORBIDDEN', 'unpinLiveChatMessage');
    const down = await unpin(roomId, h);
    expect(down.status).toBe(204);
    expect(media.broadcastsOf(roomId, 'chat-unpin').at(-1)).toEqual({
      type: 'chat-unpin',
      id: first.body.id,
    });
    expect((await ctx.http.get(`/api/v1/live/rooms/${roomId}/chat`).set(auth(plain))).body.pin).toBeNull();

    // Second pin of the day; deleting the message takes it down; the third is over the day's count (2).
    const m2 = await say(roomId, holder, 'second');
    const second = await pin(roomId, holder, m2.id);
    expect(second.status).toBe(201);
    const del = await ctx.http.delete(`/api/v1/live/rooms/${roomId}/chat/${m2.id}`).set(auth(h));
    expect(del.status).toBe(204);
    expect((await ctx.http.get(`/api/v1/live/rooms/${roomId}/chat`).set(auth(plain))).body.pin).toBeNull();
    const m3 = await say(roomId, holder, 'third');
    const usedUp = await pin(roomId, holder, m3.id);
    expectError(usedUp, 409, 'VIP_UNAVAILABLE', 'pinLiveChatMessage');
    expect(usedUp.body.error.details).toEqual([{ field: 'perk', issue: 'used_up' }]);

    // The other holder (VIP 1 itself) pins and takes their own down; nothing showing → 204 again.
    const own = await pin(roomId, other, om.id);
    expect(own.status).toBe(201);
    expect((await unpin(roomId, other)).status).toBe(204);
    expect((await unpin(roomId, h)).status).toBe(204);
    await end(roomId, h);
  });

  it('HOST_GREETING: the join line of a holder carries hostGreeting; a plain member and an ended VIP do not', async () => {
    const h = await host();
    const holder = await signup();
    const plain = await signup();
    const ended = await signup();
    await vip(holder, VIP2);
    await vip(ended, VIP2, -1);
    const roomId = await live(h, { mode: 'SOLO' });
    for (const u of [holder, plain, ended]) {
      clock.advance(1);
      await join(roomId, u);
    }
    const joins = media.broadcastsOf(roomId, 'join') as { user: { id: string }; hostGreeting: boolean }[];
    const byId = new Map(joins.map((j) => [j.user.id, j.hostGreeting]));
    expect(byId.get(holder.id)).toBe(true);
    expect(byId.get(plain.id)).toBe(false);
    expect(byId.get(ended.id)).toBe(false);
    await end(roomId, h);
  });

  it('BIG_GIFT_RAIN: a send at the threshold rains once per 10 s per room; below it, or without the perk, nothing', async () => {
    const h = await host();
    const holder = await signup();
    const plain = await signup();
    await vip(holder, VIP2);
    const roomId = await live(h, { mode: 'SOLO' });
    for (const u of [holder, plain]) {
      await join(roomId, u);
      await coins(u, 100_000);
    }
    const small = await gift(500);
    const rains = () => media.broadcastsOf(roomId, 'vip-rain') as { rain: Record<string, unknown> }[];
    await sendGift(roomId, holder, h, small); // 500 < 1 000
    await sendGift(roomId, plain, h, small, 10); // 5 000, no perk
    expect(rains()).toEqual([]);
    const sent = await sendGift(roomId, holder, h, small, 10); // 5 000
    expect(rains()).toHaveLength(1);
    expect(rains()[0]!.rain).toMatchObject({
      giftId: sent.gift.id,
      roomId,
      sender: { id: holder.id },
      totalCoins: 5_000,
      still: `${ART}/rain.png`,
      video: null,
      durationMs: 4_000,
    });
    expect(
      media.broadcasts
        .filter((b) => b.room === roomId && b.payload.includes('"vip-rain"'))
        .map((b) => b.topic),
    ).toEqual(['gift']);
    await sendGift(roomId, holder, h, small, 10); // within 10 s: dropped
    expect(rains()).toHaveLength(1);
    clock.advance(11);
    await sendGift(roomId, holder, h, small, 10);
    expect(rains()).toHaveLength(2);
    await end(roomId, h);
  });

  it('VIEWER_LIST_PRIORITY and SEAT_REQUEST_PRIORITY: holders first (the higher tier first); the others as before', async () => {
    const h = await host();
    const [a, b, low, high] = [await signup(), await signup(), await signup(), await signup()];
    await vip(low, VIP1);
    await vip(high, VIP3);
    const roomId = await live(h);
    // Joined in this order; newest first is b, a, then the holders lead anyway.
    for (const u of [high, low, a, b]) {
      clock.advance(1);
      await join(roomId, u);
    }
    const viewers = await ctx.http.get(`/api/v1/live/rooms/${roomId}/viewers`).set(auth(h));
    expect(viewers.status).toBe(200);
    expectContract(viewers, 'listLiveRoomViewers');
    const ids = (viewers.body.data as { user: { id: string } | null }[]).map((v) => v.user?.id);
    expect(ids.slice(0, 2)).toEqual([high.id, low.id]);
    expect(ids.filter((id) => id === high.id)).toHaveLength(1);
    expect(new Set(ids)).toEqual(new Set([high.id, low.id, a.id, b.id]));

    // Seat requests: a, then low, then high asked — high (VIP 3) and low (VIP 1) come first, then a.
    for (const u of [a, low, high]) {
      clock.advance(1);
      await ask(roomId, u);
    }
    const list = await ctx.http.get(`/api/v1/live/rooms/${roomId}/seat-requests`).set(auth(h));
    expect(list.status).toBe(200);
    expectContract(list, 'listLiveSeatRequests');
    expect((list.body.data as { user: { id: string } }[]).map((r) => r.user.id)).toEqual([
      high.id,
      low.id,
      a.id,
    ]);
    // The cursor carries the priority: one by one gives the same order.
    const order: string[] = [];
    let cursor: string | null = null;
    do {
      const page = await ctx.http
        .get(`/api/v1/live/rooms/${roomId}/seat-requests`)
        .query({ limit: 1, ...(cursor ? { cursor } : {}) })
        .set(auth(h));
      expect(page.status, JSON.stringify(page.body)).toBe(200);
      order.push(...(page.body.data as { user: { id: string } }[]).map((r) => r.user.id));
      cursor = page.body.page.nextCursor as string | null;
    } while (cursor);
    expect(order).toEqual([high.id, low.id, a.id]);
    // The VIP ends: back to the queue order.
    await vip(high, VIP3, -1);
    const after = await ctx.http.get(`/api/v1/live/rooms/${roomId}/seat-requests`).set(auth(h));
    expect((after.body.data as { user: { id: string } }[]).map((r) => r.user.id)).toEqual([
      low.id,
      a.id,
      high.id,
    ]);
    await end(roomId, h);
  });

  it('VIP_ROOM: an audio room for VIP 2 and above (capped by the perk), the lock in the summary, LIVE_VIP_ONLY for the others', async () => {
    const h = await host();
    const plainHost = await host();
    await vip(h, VIP2);
    // No perk; not AUDIO; an unknown tier; above the cap.
    expectError(
      await goLive(plainHost, { mode: 'AUDIO', seatCount: 5, vipMinTier: 'VIP_1' }),
      409,
      'VIP_UNAVAILABLE',
      'startLiveRoom',
    );
    expectError(
      await goLive(h, { mode: 'SOLO', vipMinTier: 'VIP_1' }),
      400,
      'VALIDATION_FAILED',
      'startLiveRoom',
    );
    const unknown = await goLive(h, { mode: 'AUDIO', seatCount: 5, vipMinTier: 'VIP_9' });
    expectError(unknown, 400, 'VALIDATION_FAILED', 'startLiveRoom');
    expect(unknown.body.error.details).toEqual([{ field: 'vipMinTier', issue: 'not_found' }]);
    const above = await goLive(h, { mode: 'AUDIO', seatCount: 5, vipMinTier: 'VIP_3' });
    expect(above.body.error.details).toEqual([{ field: 'vipMinTier', issue: 'out_of_range' }]);

    const started = await goLive(h, { mode: 'AUDIO', seatCount: 5, vipMinTier: 'VIP_2', allowGuests: true });
    expect(started.status, JSON.stringify(started.body)).toBe(201);
    expectContract(started, 'startLiveRoom');
    expect(started.body.vipMinTier).toEqual({ code: 'VIP_2', name: 'VIP 2', color: '#1E6FD9' });
    expect(started.body.allowGuests).toBe(false);
    const roomId = started.body.id as string;

    const [v1, v3, plain] = [await signup(), await signup(), await signup()];
    await vip(v1, VIP1);
    await vip(v3, VIP3);
    const token = (u: TestUser | null) => {
      const req = ctx.http.post(`/api/v1/live/rooms/${roomId}/media-token`);
      if (u) void req.set(auth(u));
      return req.send(u ? {} : { guestId: randomUUID() });
    };
    const refused = await token(v1);
    expectError(refused, 403, 'LIVE_VIP_ONLY', 'createLiveMediaToken');
    expect(refused.body.error.details).toEqual([{ field: 'vipMinTier', issue: 'VIP_2' }]);
    expectError(await token(plain), 403, 'LIVE_VIP_ONLY', 'createLiveMediaToken');
    expect((await token(null)).status).toBe(403);
    expect((await token(v3)).status).toBe(200);
    expect((await token(h)).status).toBe(200);
    expectError(
      await ctx.http.post(`/api/v1/live/rooms/${roomId}/seat-requests`).set(auth(plain)).send({}),
      403,
      'LIVE_VIP_ONLY',
      'requestLiveSeat',
    );
    // Listed with the lock.
    const listed = await ctx.http
      .get('/api/v1/live/rooms')
      .query({ tab: 'new', kind: 'party' })
      .set(auth(plain));
    expect(listed.status, JSON.stringify(listed.body)).toBe(200);
    const card = (listed.body.data as { id: string; vipMinTier: unknown }[]).find((r) => r.id === roomId);
    expect(card?.vipMinTier).toMatchObject({ code: 'VIP_2' });
    // The host's VIP ends: their room stays as it is, but they cannot open another one.
    await end(roomId, h);
    await vip(h, VIP2, -1);
    expectError(
      await goLive(h, { mode: 'AUDIO', seatCount: 5, vipMinTier: 'VIP_1' }),
      409,
      'VIP_UNAVAILABLE',
      'startLiveRoom',
    );
  });

  it('SEAT_RESERVE: the host keeps a seat for a friend (LOCKED + reservation); others land elsewhere; the friend takes it; it ends on time', async () => {
    const h = await host();
    await vip(h, VIP2);
    const [friend, stranger, late] = [await signup(), await signup(), await signup()];
    const roomId = await live(h, { mode: 'AUDIO', seatCount: 5 });
    for (const u of [friend, stranger, late]) await join(roomId, u);
    const reserve = (by: TestUser, index: number, username: string) =>
      ctx.http
        .put(`/api/v1/live/rooms/${roomId}/seats/${String(index)}/reservation`)
        .set(auth(by))
        .send({ username });

    expectError(await reserve(stranger, 1, friend.username), 403, 'AUTH_FORBIDDEN', 'reserveLiveSeat');
    expectError(await reserve(h, 9, friend.username), 409, 'LIVE_SEAT_UNAVAILABLE', 'reserveLiveSeat');
    expectError(await reserve(h, 1, 'nobody_d379'), 404, 'NOT_FOUND', 'reserveLiveSeat');
    const kept = await reserve(h, 1, friend.username);
    expect(kept.status, JSON.stringify(kept.body)).toBe(200);
    expectContract(kept, 'reserveLiveSeat');
    const one = (
      kept.body.seats as { index: number; state: string; reservation?: { user: { id: string } } }[]
    ).find((s) => s.index === 1);
    expect(one).toMatchObject({ state: 'LOCKED', reservation: { user: { id: friend.id } } });
    expect(media.data.some((d) => d.identity === friend.id && d.payload.includes('"seat-reserved"'))).toBe(
      true,
    );

    // The stranger asks and is accepted: another seat. An explicit ask for seat 1 is refused.
    expect(
      (
        await ctx.http
          .post(`/api/v1/live/rooms/${roomId}/seat-requests`)
          .set(auth(late))
          .send({ seatIndex: 1 })
      ).status,
    ).toBe(409);
    await accept(roomId, h, await ask(roomId, stranger));
    expect(await seatOf(roomId, h, stranger)).not.toBe(1);
    // The friend's request lands on the kept seat; the reservation is gone.
    await accept(roomId, h, await ask(roomId, friend));
    expect(await seatOf(roomId, h, friend)).toBe(1);
    expect((await seats(roomId, h)).some((s) => s.reservation)).toBe(false);

    // A new reservation for `late` on seat 3 ends at the perk's 10 minutes; the sweeper removes it.
    expect((await reserve(h, 3, late.username)).status).toBe(200);
    clock.advance(10 * 60 + 1);
    const three = (await seats(roomId, h)).find((s) => s.index === 3);
    expect(three).toMatchObject({ state: 'EMPTY' });
    expect(three?.reservation).toBeUndefined();
    expect(await ctx.app.get(LiveSeatsService).releaseExpiredReservations()).toBe(1);
    expect(await ctx.prisma.liveSeatReservation.count({ where: { roomId } })).toBe(0);

    // Release is idempotent; the host without the perk cannot keep a seat.
    expect((await reserve(h, 3, late.username)).status).toBe(200);
    const released = await ctx.http.delete(`/api/v1/live/rooms/${roomId}/seats/3/reservation`).set(auth(h));
    expect(released.status).toBe(200);
    expectContract(released, 'releaseLiveSeat');
    expect(
      (await ctx.http.delete(`/api/v1/live/rooms/${roomId}/seats/3/reservation`).set(auth(h))).status,
    ).toBe(200);
    await vip(h, VIP2, -1);
    expectError(await reserve(h, 3, late.username), 409, 'VIP_UNAVAILABLE', 'reserveLiveSeat');
    await end(roomId, h);
  });

  it('TICKER_HOLD: a holder’s gift strip carries holdSeconds; a plain sender’s carries 0', async () => {
    const h = await host();
    const holder = await signup();
    const plain = await signup();
    await vip(holder, VIP2);
    const roomId = await live(h, { mode: 'SOLO' });
    for (const u of [holder, plain]) {
      await join(roomId, u);
      await coins(u, 2_000_000);
    }
    const big = await gift(500_000);
    const strips = () =>
      media.broadcastsOf(roomId, 'gift-ticker') as { holdSeconds: number; gift: { id: string } }[];
    const until = async (check: () => boolean, ms = 15_000) => {
      const stop = Date.now() + ms;
      while (!check()) {
        if (Date.now() > stop) throw new Error('timed out');
        await new Promise((r) => setTimeout(r, 100));
        await settle(ctx);
      }
    };
    const sent = await sendGift(roomId, holder, h, big);
    await until(() => strips().length === 1);
    expect(strips()[0]).toMatchObject({ gift: { id: sent.gift.id }, holdSeconds: 5 });
    // The next strip waits for the longer gate (3 s + 5 s): not before 3.5 s.
    const next = await sendGift(roomId, plain, h, big);
    await new Promise((r) => setTimeout(r, 3_500));
    await settle(ctx);
    expect(strips()).toHaveLength(1);
    await until(() => strips().length === 2);
    expect(strips()[1]).toMatchObject({ gift: { id: next.gift.id }, holdSeconds: 0 });
    await end(roomId, h);
  });
});
