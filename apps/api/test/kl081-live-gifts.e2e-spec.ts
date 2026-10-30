/**
 * KL-081 / CP-020 (D108, owner 2026-10-26): live gifts — the catalogue, the gift bag and sending
 * gifts in a live with coins or from the bag (openapi v1.23-live DRAFT, CONVENTIONS §10.23, §10.10,
 * §10.12, §10.15, §10.18, §4, §7), end to end against PostgreSQL + Redis with the API as the
 * DML-only runtime role.
 *
 * `gift-admin` runs as on the server (a child process with the migration role) in its own block;
 * the other tests add gifts, coins and bag stock through the same shared functions the CLIs use
 * (`addGiftIn`, `creditIn`, `grantStockIn`), which is much faster. Seats are a fixture row (the
 * seat flow itself is KL-064/KL-074). The media server is the in-memory fake that records every
 * data message; time is a FakeClock (combos).
 */
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { addGiftIn, grantStockIn, type GiftFields } from '../src/modules/gifts/gift-catalogue.js';
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
  readonly email: string;
  readonly token: string;
}

/** Runs `pnpm gift:admin …` as on the server (migration role, a child process). */
function giftAdmin(...args: string[]): { status: number; out: string } {
  try {
    const out = execFileSync('pnpm', ['-s', 'gift:admin', ...args], {
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

describe('CP-020 contract coverage', () => {
  it('openapi v1.23-live declares the gift operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'getGiftCatalogue GET /api/v1/gifts/catalogue',
      'getMyGiftBag GET /api/v1/me/gifts/bag',
      'sendLiveGift POST /api/v1/live/rooms/{roomId}/gifts',
    ]) {
      expect(ids).toContain(op);
    }
  });
});

describe('CP-020 live gifts', { timeout: 120_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  let seq = 0;

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
  const goLive = async (u: TestUser, extra: object = { mode: 'AUDIO', seatCount: 10 }): Promise<string> => {
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: 'Gifts', ...extra });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const join = async (roomId: string, u: TestUser) => {
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
  /** Fixture: `u` sits on seat `seat` (the seat flow is KL-064 / KL-074). */
  const seat = async (roomId: string, u: TestUser, seatIndex: number) => {
    await join(roomId, u);
    await ctx.prisma.liveRoomSeat.create({ data: { roomId, seatIndex, userId: u.id } });
  };
  const coins = (u: TestUser, amount: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  const stock = (u: TestUser, code: string, quantity: number) =>
    ctx.prisma.$transaction((tx) => grantStockIn(tx, u.id, code, quantity));
  const gift = async (fields: Partial<GiftFields> = {}): Promise<string> => {
    seq += 1;
    const code = `g${String(seq)}_${randomUUID().slice(0, 6)}`;
    await ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, code, {
        category: 'POPULAR',
        nameAr: `هدية ${String(seq)}`,
        nameEn: `Gift ${String(seq)}`,
        priceCoins: 1,
        assetKey: `gift_${code}`,
        animationKey: null,
        sortOrder: seq,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
        ...fields,
      }),
    );
    return code;
  };
  const wallet = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/wallet/me').set(auth(u));
    expect(res.status).toBe(200);
    return res.body.coins as number;
  };
  const send = (roomId: string, u: TestUser | null, body: unknown): request.Test => {
    const req = ctx.http.post(`/api/v1/live/rooms/${roomId}/gifts`);
    if (u) void req.set(auth(u));
    return req.send(body as object);
  };
  const body = (code: string, recipients: TestUser[], extra: object = {}) => ({
    giftCode: code,
    quantity: 1,
    recipients: recipients.map((r) => r.username),
    source: 'COINS',
    clientId: randomUUID(),
    ...extra,
  });
  const giftsTo = (roomId: string) => media.broadcasts.filter((b) => b.room === roomId && b.topic === 'gift');
  const ledger = (u: TestUser) =>
    ctx.prisma.walletLedgerEntry.findMany({ where: { userId: u.id }, orderBy: { createdAt: 'asc' } });
  const roomScore = async (roomId: string, u: TestUser) => {
    const res = await ctx.http.get(`/api/v1/live/rooms/${roomId}`).set(auth(u));
    expect(res.status).toBe(200);
    return {
      score: res.body.score as number,
      parts: res.body.scoreParts as { total: number; tapPoints: number; supportPoints: number },
    };
  };
  const expectError = (res: request.Response, status: number, code: string) => {
    expect(res.status, JSON.stringify(res.body)).toBe(status);
    expect(res.body.error.code).toBe(code);
    expectContract(res, 'sendLiveGift');
  };

  /** A live with a host, two seated guests and a viewer, everyone with coins. */
  const scene = async () => {
    const h = await host();
    const [s1, s2, viewer] = [await signup(), await signup(), await signup()];
    const roomId = await goLive(h);
    await seat(roomId, s1, 1);
    await seat(roomId, s2, 2);
    await join(roomId, viewer);
    for (const u of [h, s1, s2, viewer]) await coins(u, 10_000);
    return { h, s1, s2, viewer, roomId };
  };

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: Clock, value: clock },
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
  });
  afterAll(async () => ctx?.close());

  // ---- Catalogue and bag -------------------------------------------------------------------------

  describe('catalogue', () => {
    it('needs a token, is empty without gifts, and carries the quantities and limits', async () => {
      const anonymous = await ctx.http.get('/api/v1/gifts/catalogue');
      expect(anonymous.status).toBe(401);
      expectContract(anonymous, 'getGiftCatalogue');
      const u = await signup();
      const res = await ctx.http.get('/api/v1/gifts/catalogue').set(auth(u));
      expect(res.status).toBe(200);
      expectContract(res, 'getGiftCatalogue');
      expect(res.body).toEqual({
        version: expect.stringMatching(/^[0-9a-f]{16}$/),
        // v1.32-live (D154): the quips tab is listed too (empty here).
        categories: ['POPULAR', 'EVENT', 'FUN', 'QUIPS'],
        quantities: [1, 10, 66, 99, 188, 520, 1314],
        maxRecipients: 25,
        comboWindowSeconds: 5,
        data: [],
      });
    });

    it('lists enabled gifts by tab then sort order, names by language; the version follows changes', async () => {
      const u = await signup();
      const read = async (lang: string) => {
        const res = await ctx.http.get('/api/v1/gifts/catalogue').set(auth(u)).set('Accept-Language', lang);
        expect(res.status).toBe(200);
        expectContract(res, 'getGiftCatalogue');
        return res.body as { version: string; data: { code: string; name: string; category: string }[] };
      };
      const before = await read('en');
      const fun = await gift({ category: 'FUN', sortOrder: 1, nameEn: 'Clown', nameAr: 'مهرج' });
      const event = await gift({ category: 'EVENT', sortOrder: 5, badge: 'EVENT', animationKey: 'fx_event' });
      const pop = await gift({ category: 'POPULAR', sortOrder: 999_999, priceCoins: 99 });
      const off = await gift({ category: 'POPULAR' });
      await ctx.prisma.gift.update({ where: { code: off }, data: { enabled: false } });

      const en = await read('en');
      const ar = await read('ar');
      expect(en.version).not.toBe(before.version);
      expect(ar.version).toBe(en.version);
      const codes = en.data.map((g) => g.code);
      expect(codes).not.toContain(off);
      expect(codes.indexOf(pop)).toBeLessThan(codes.indexOf(event));
      expect(codes.indexOf(event)).toBeLessThan(codes.indexOf(fun));
      expect(en.data.find((g) => g.code === fun)?.name).toBe('Clown');
      expect(ar.data.find((g) => g.code === fun)?.name).toBe('مهرج');
      expect(en.data.find((g) => g.code === event)).toMatchObject({
        category: 'EVENT',
        badge: 'EVENT',
        animationKey: 'fx_event',
        priceCoins: 1,
      });

      await ctx.prisma.gift.update({ where: { code: pop }, data: { priceCoins: 100 } });
      expect((await read('en')).version).not.toBe(en.version);
    });

    it('v1.24.3-live: each gift carries its optional tag {code, name} by language, else null', async () => {
      const u = await signup();
      const tagged = await gift({
        tagCode: 'treasure_box',
        tagNameAr: 'صندوق الكنز',
        tagNameEn: 'Treasure Box',
      });
      const plain = await gift();
      const read = async (lang: string) => {
        const res = await ctx.http.get('/api/v1/gifts/catalogue').set(auth(u)).set('Accept-Language', lang);
        expect(res.status).toBe(200);
        expectContract(res, 'getGiftCatalogue');
        return res.body as { version: string; data: { code: string; tag: unknown }[] };
      };
      const en = await read('en');
      const ar = await read('ar');
      expect(en.data.find((g) => g.code === tagged)?.tag).toEqual({
        code: 'treasure_box',
        name: 'Treasure Box',
      });
      expect(ar.data.find((g) => g.code === tagged)?.tag).toEqual({
        code: 'treasure_box',
        name: 'صندوق الكنز',
      });
      expect(en.data.find((g) => g.code === plain)?.tag).toBeNull();
      expect(ar.version).toBe(en.version);

      await ctx.prisma.gift.update({ where: { code: tagged }, data: { tagNameEn: 'Treasure' } });
      expect((await read('en')).version).not.toBe(en.version);

      // The bag carries the tag too.
      await stock(u, tagged, 2);
      const bag = await ctx.http.get('/api/v1/me/gifts/bag').set(auth(u)).set('Accept-Language', 'ar');
      expect(bag.status).toBe(200);
      expectContract(bag, 'getMyGiftBag');
      expect(bag.body.data).toEqual([
        expect.objectContaining({
          code: tagged,
          quantity: 2,
          tag: { code: 'treasure_box', name: 'صندوق الكنز' },
        }),
      ]);

      // The database refuses a half tag (CHECK gifts_tag_complete).
      await expect(
        ctx.prisma.gift.update({ where: { code: plain }, data: { tagCode: 'glory' } }),
      ).rejects.toThrow();
    });
  });

  describe('gift bag', () => {
    it('lists the enabled gifts the caller holds, with quantities, in catalogue order', async () => {
      const u = await signup();
      const empty = await ctx.http.get('/api/v1/me/gifts/bag').set(auth(u));
      expect(empty.status).toBe(200);
      expectContract(empty, 'getMyGiftBag');
      expect(empty.body).toEqual({ data: [] });

      const a = await gift({ category: 'FUN' });
      const b = await gift({ category: 'POPULAR', nameAr: 'نجمة', nameEn: 'Star' });
      const off = await gift();
      await stock(u, a, 3);
      await stock(u, b, 5);
      await stock(u, b, 2);
      await stock(u, off, 1);
      await ctx.prisma.gift.update({ where: { code: off }, data: { enabled: false } });

      const res = await ctx.http.get('/api/v1/me/gifts/bag').set(auth(u)).set('Accept-Language', 'ar');
      expect(res.status).toBe(200);
      expectContract(res, 'getMyGiftBag');
      expect(res.body.data.map((g: { code: string; quantity: number }) => [g.code, g.quantity])).toEqual([
        [b, 7],
        [a, 3],
      ]);
      expect(res.body.data[0]).toMatchObject({ name: 'نجمة', category: 'POPULAR', priceCoins: 1 });
    });
  });

  // ---- Sending with coins ------------------------------------------------------------------------

  describe('sending with coins', () => {
    it('charges price × quantity, credits the room, the contributor and the host board, and sends a data message', async () => {
      const { h, viewer, roomId } = await scene();
      const code = await gift({ priceCoins: 5, assetKey: 'gift_heart', animationKey: 'fx_heart' });
      const before = await roomScore(roomId, viewer);

      const res = await send(roomId, viewer, body(code, [h], { quantity: 10 }));
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      expectContract(res, 'sendLiveGift');
      expect(res.body).toEqual({
        gift: {
          id: expect.any(String),
          roomId,
          giftCode: code,
          assetKey: 'gift_heart',
          animationKey: 'fx_heart',
          // v1.26.2-live (D126): no hosted art for this gift (kl089 covers the URLs).
          imageUrl: null,
          animationUrl: null,
          animationBytes: null,
          unitPrice: 5,
          quantity: 10,
          source: 'COINS',
          totalCoins: 50,
          sender: {
            id: viewer.id,
            username: viewer.username,
            displayName: expect.any(String),
            avatarUrl: null,
          },
          recipients: [{ id: h.id, username: h.username, displayName: expect.any(String), avatarUrl: null }],
          combo: { id: res.body.gift.id, count: 1, quantity: 10 },
          createdAt: clock.now().toISOString(),
        },
        coins: 9_950,
        bagQuantity: 0,
      });
      expect(await wallet(viewer)).toBe(9_950);

      // One ledger row, reason LIVE_GIFT, referencing the send.
      const rows = (await ledger(viewer)).filter((r) => r.reason === 'LIVE_GIFT');
      expect(rows.map((r) => [Number(r.delta), Number(r.balanceAfter), r.referenceId])).toEqual([
        [-50, 9_950, res.body.gift.id],
      ]);

      // The live score: 100 a coin, as support points.
      const after = await roomScore(roomId, viewer);
      expect(after.parts.supportPoints - before.parts.supportPoints).toBe(5_000);
      expect(after.score - before.score).toBe(5_000);
      expect(after.parts.tapPoints).toBe(before.parts.tapPoints);

      // The Contribution list and the sender's standing.
      const list = await ctx.http.get(`/api/v1/live/rooms/${roomId}/contributors`).set(auth(h));
      expect(list.status).toBe(200);
      expectContract(list, 'listLiveContributors');
      expect(list.body.data).toEqual([{ user: expect.objectContaining({ id: viewer.id }), points: 5_000 }]);
      const standing = await ctx.http
        .get(`/api/v1/live/rooms/${roomId}/contributors/${viewer.username}`)
        .set(auth(h));
      expect(standing.status).toBe(200);
      expectContract(standing, 'getLiveContributor');
      expect(standing.body).toMatchObject({ points: 5_000, rank: 1 });

      // The popularity board: the host's points this hour.
      const board = await ctx.http.get('/api/v1/live/rankings?period=HOUR').set(auth(h));
      expect(board.status).toBe(200);
      expectContract(board, 'listLiveRankings');
      expect(board.body.me).toMatchObject({ points: 5_000 });

      // The data message to the room.
      await settle(ctx);
      const sent = giftsTo(roomId);
      expect(sent).toHaveLength(1);
      expect(JSON.parse(sent[0]!.payload)).toEqual({ type: 'gift', gift: res.body.gift });
    });

    it('D128: the host and a seated guest may gift themselves; it counts like any gift', async () => {
      const { h, s1, s2, viewer, roomId } = await scene();
      const code = await gift({ priceCoins: 5 });
      const before = await roomScore(roomId, viewer);
      const boardBefore = await ctx.http.get('/api/v1/live/rankings?period=HOUR').set(auth(h));
      const hostBefore = (boardBefore.body.me?.points as number | undefined) ?? 0;

      // The host to themself (a SOLO-like case: nobody else named).
      const mine = await send(roomId, h, body(code, [h], { quantity: 10 }));
      expect(mine.status, JSON.stringify(mine.body)).toBe(201);
      expectContract(mine, 'sendLiveGift');
      expect(mine.body.gift).toMatchObject({
        sender: { id: h.id },
        recipients: [{ id: h.id }],
        totalCoins: 50,
      });
      expect(mine.body.coins).toBe(9_950);
      expect(await wallet(h)).toBe(9_950);

      // A seated guest to themself and the host together.
      const guest = await send(roomId, s1, body(code, [s1, h]));
      expect(guest.status, JSON.stringify(guest.body)).toBe(201);
      expect(guest.body.gift.recipients.map((r: { id: string }) => r.id)).toEqual([s1.id, h.id]);
      expect(await wallet(s1)).toBe(10_000 - 10);
      // A seated guest cannot name someone else who is not seated (unchanged).
      expectError(await send(roomId, s2, body(code, [s2, viewer])), 409, 'LIVE_GIFT_RECIPIENT_UNAVAILABLE');

      // The live score and the host's popularity points grow like for any gift (100 a coin).
      const after = await roomScore(roomId, viewer);
      expect(after.parts.supportPoints - before.parts.supportPoints).toBe(5_000 + 1_000);
      const board = await ctx.http.get('/api/v1/live/rankings?period=HOUR').set(auth(h));
      expect(board.body.me.points - hostBefore).toBe(6_000);
      // The host is never in their own Contribution list; the guest is.
      const list = await ctx.http.get(`/api/v1/live/rooms/${roomId}/contributors`).set(auth(h));
      expect(
        list.body.data.map((c: { user: { id: string }; points: number }) => [c.user.id, c.points]),
      ).toEqual([[s1.id, 1_000]]);
      await settle(ctx);
      expect(giftsTo(roomId)).toHaveLength(2);
    });

    it('is idempotent on clientId: a retry → 200 with the first send, nothing charged or sent again', async () => {
      const { h, viewer, roomId } = await scene();
      const code = await gift({ priceCoins: 7 });
      const first = body(code, [h]);
      const created = await send(roomId, viewer, first);
      expect(created.status).toBe(201);
      const retry = await send(roomId, viewer, {
        ...first,
        quantity: 10,
        clientId: first.clientId.toUpperCase(),
      });
      expect(retry.status).toBe(200);
      expectContract(retry, 'sendLiveGift');
      expect(retry.body).toEqual({ gift: created.body.gift, coins: 9_993, bagQuantity: 0 });
      expect(await wallet(viewer)).toBe(9_993);
      expect((await ledger(viewer)).filter((r) => r.reason === 'LIVE_GIFT')).toHaveLength(1);
      expect(await ctx.prisma.liveGift.count({ where: { senderId: viewer.id } })).toBe(1);
      await settle(ctx);
      expect(giftsTo(roomId)).toHaveLength(1);
      expect((await roomScore(roomId, h)).parts.supportPoints).toBe(700);
    });

    it('409 INSUFFICIENT_COINS: nothing stored, charged or sent', async () => {
      const { h, roomId } = await scene();
      const poor = await signup();
      await join(roomId, poor);
      await coins(poor, 9);
      const code = await gift({ priceCoins: 10 });
      expectError(await send(roomId, poor, body(code, [h])), 409, 'INSUFFICIENT_COINS');
      expect(await wallet(poor)).toBe(9);
      expect(await ctx.prisma.liveGift.count({ where: { senderId: poor.id } })).toBe(0);
      expect((await roomScore(roomId, h)).parts.supportPoints).toBe(0);
      await settle(ctx);
      expect(giftsTo(roomId)).toHaveLength(0);
    });

    it('multi-recipient math: each recipient gets the quantity; price × quantity × recipients', async () => {
      const { h, s1, s2, viewer, roomId } = await scene();
      const code = await gift({ priceCoins: 3 });
      const res = await send(roomId, viewer, body(code, [s2, h, s1], { quantity: 66 }));
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      expect(res.body.gift.totalCoins).toBe(3 * 66 * 3);
      expect(res.body.gift.recipients.map((r: { id: string }) => r.id)).toEqual([s2.id, h.id, s1.id]);
      expect(res.body.coins).toBe(10_000 - 594);
      const rows = await ctx.prisma.liveGiftRecipient.findMany({
        where: { giftId: res.body.gift.id },
        orderBy: { position: 'asc' },
      });
      expect(rows.map((r) => [r.userId, r.position, Number(r.coins)])).toEqual([
        [s2.id, 0, 198],
        [h.id, 1, 198],
        [s1.id, 2, 198],
      ]);
      expect((await roomScore(roomId, h)).parts.supportPoints).toBe(59_400);

      // A seated guest sends to the host and another guest; the host sends to the guests.
      const fromGuest = await send(roomId, s1, body(code, [h, s2]));
      expect(fromGuest.status).toBe(201);
      expect(fromGuest.body.gift.totalCoins).toBe(6);
      const fromHost = await send(roomId, h, body(code, [s1, s2], { quantity: 10 }));
      expect(fromHost.status).toBe(201);
      expect(fromHost.body.gift.totalCoins).toBe(60);
      // The host's own gifts count for the room, never in the list.
      const list = await ctx.http.get(`/api/v1/live/rooms/${roomId}/contributors`).set(auth(viewer));
      expect(
        list.body.data.map((c: { user: { id: string }; points: number }) => [c.user.id, c.points]),
      ).toEqual([
        [viewer.id, 59_400],
        [s1.id, 600],
      ]);
      expect((await roomScore(roomId, h)).parts.supportPoints).toBe(59_400 + 600 + 6_000);
    });

    it('D135: each seat carries the points its person received in this live; a gift to a seated guest moves the seat version', async () => {
      const { h, s1, s2, viewer, roomId } = await scene();
      const code = await gift({ priceCoins: 3 });
      const seats = async (u: TestUser | null = viewer) => {
        const req = ctx.http.get(`/api/v1/live/rooms/${roomId}/seats`);
        if (u) void req.set(auth(u));
        const res = await req;
        expect(res.status, JSON.stringify(res.body)).toBe(200);
        expectContract(res, 'getLiveRoomSeats');
        return res.body as { version: number; seats: { index: number; state: string; points: number }[] };
      };
      const first = await seats();
      expect(first.seats.filter((x) => x.index <= 3).map((x) => [x.index, x.state, x.points])).toEqual([
        [1, 'TAKEN', 0],
        [2, 'TAKEN', 0],
        [3, 'EMPTY', 0],
      ]);
      // To the host only: the seats do not move.
      expect((await send(roomId, viewer, body(code, [h]))).status).toBe(201);
      expect((await seats()).version).toBe(first.version);
      // To two guests and the host, then one guest again from another guest.
      expect((await send(roomId, viewer, body(code, [s1, s2, h], { quantity: 10 }))).status).toBe(201);
      expect((await send(roomId, s2, body(code, [s1]))).status).toBe(201);
      const after = await seats(null);
      expect(after.version).toBeGreaterThan(first.version);
      expect(after.seats.filter((x) => x.index <= 2).map((x) => [x.index, x.points])).toEqual([
        [1, (30 + 3) * 100],
        [2, 30 * 100],
      ]);
      // The metadata follows with the score's next write (the 2 s throttle, on the fake clock).
      clock.advance(3);
      expect((await send(roomId, viewer, body(code, [h]))).status).toBe(201);
      const meta = JSON.parse(media.metadata.get(roomId) ?? '{}') as { seatsVersion?: number };
      expect(meta.seatsVersion).toBe(after.version);
    });

    it('D136: the wish list — PATCH validates (≤ 4, distinct, sendable), the room shows names and received counts, wished gifts to the host move the info version, a new live copies it', async () => {
      const { h, s1, viewer, roomId } = await scene();
      const a = await gift({ priceCoins: 2, nameEn: 'Alpha', nameAr: 'ألفا' });
      const b = await gift({ priceCoins: 3 });
      const c = await gift({ priceCoins: 1 });
      const off = await gift();
      await ctx.prisma.gift.update({ where: { code: off }, data: { enabled: false } });
      const patch = (body: object, u: TestUser = h) =>
        ctx.http.patch(`/api/v1/live/rooms/${roomId}`).set(auth(u)).send(body);
      const info = async () =>
        (await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).infoVersion;
      for (const [body, issue] of [
        [{ wishGifts: [a, b, c, a] }, 'invalid_value'],
        [{ wishGifts: [a, b, c, off] }, 'invalid_value'],
        [{ wishGifts: ['no_such_gift'] }, 'invalid_value'],
        [{ wishGifts: [a, b, c, 'x1', 'x2'] }, 'too_many'],
        [{ wishGifts: ['Bad!'] }, 'invalid_format'],
      ] as const) {
        const res = await patch(body);
        expect(res.status, JSON.stringify(body)).toBe(400);
        expect(res.body.error.details[0]).toMatchObject({ issue });
      }
      expect((await patch({ wishGifts: [a] }, viewer)).status).toBe(404);
      const before = await info();
      const ok = await patch({ wishGifts: [b, a] });
      expect(ok.status).toBe(200);
      expectContract(ok, 'updateLiveRoom');
      expect(ok.body.wishGifts.map((w: { giftCode: string }) => w.giftCode)).toEqual([b, a]);
      expect(await info()).toBe(before + 1);
      expect((await patch({ wishGifts: [b, a] })).status).toBe(200);
      expect(await info()).toBe(before + 1);
      // Received: sends of a wished gift that named the host (from anyone), not to others.
      expect((await send(roomId, viewer, body(a, [h], { quantity: 10 }))).status).toBe(201);
      expect(await info()).toBe(before + 2);
      expect((await send(roomId, s1, body(a, [h, s1]))).status).toBe(201);
      expect((await send(roomId, viewer, body(a, [s1], { quantity: 10 }))).status).toBe(201);
      expect((await send(roomId, viewer, body(c, [h]))).status).toBe(201);
      const read = await ctx.http
        .get(`/api/v1/live/rooms/${roomId}`)
        .set(auth(viewer))
        .set('Accept-Language', 'ar');
      expectContract(read, 'getLiveRoom');
      expect(read.body.wishGifts).toEqual([
        expect.objectContaining({ giftCode: b, received: 0, priceCoins: 3 }),
        expect.objectContaining({ giftCode: a, name: 'ألفا', received: 11, priceCoins: 2, imageUrl: null }),
      ]);
      // A disabled gift drops out of the shown list (kept stored).
      await ctx.prisma.gift.update({ where: { code: b }, data: { enabled: false } });
      const shown = await ctx.http.get(`/api/v1/live/rooms/${roomId}`).set(auth(viewer));
      expect(shown.body.wishGifts.map((w: { giftCode: string }) => w.giftCode)).toEqual([a]);
      await ctx.prisma.gift.update({ where: { code: b }, data: { enabled: true } });
      // Audited.
      const audit = await ctx.prisma.auditLog.findMany({
        where: { targetId: roomId, action: 'live.room.edit' },
      });
      expect(audit.map((x) => (x.metadata as { fields: string[] }).fields)).toEqual([['wishGifts']]);
      // The next live copies the list; an explicit list wins; [] empties.
      await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(h)).expect(200);
      const next = await goLive(h);
      const nextRoom = await ctx.http.get(`/api/v1/live/rooms/${next}`).set(auth(h));
      expect(nextRoom.body.wishGifts.map((w: { giftCode: string }) => w.giftCode)).toEqual([b, a]);
      const cleared = await ctx.http.patch(`/api/v1/live/rooms/${next}`).set(auth(h)).send({ wishGifts: [] });
      expect(cleared.body.wishGifts).toEqual([]);
      await ctx.http.post(`/api/v1/live/rooms/${next}/end`).set(auth(h)).expect(200);
    });

    it('counts for the sender family like other spending', async () => {
      const { h, viewer, roomId } = await scene();
      const created = await ctx.http
        .post('/api/v1/families')
        .set(auth(viewer))
        .send({ name: `Fam${randomUUID().slice(0, 8)}`, clientId: randomUUID() });
      expect(created.status, JSON.stringify(created.body)).toBe(201);
      const code = await gift({ priceCoins: 20 });
      const res = await send(roomId, viewer, body(code, [h]));
      expect(res.status).toBe(201);
      const ledgerRow = (await ledger(viewer)).find((r) => r.reason === 'LIVE_GIFT')!;
      const points = await ctx.prisma.familyPointsEntry.findMany({ where: { walletLedgerId: ledgerRow.id } });
      expect(points.map((p) => Number(p.points))).toEqual([20]);
    });

    it('combos: the same gift to the same recipients within 5 s continues the combo', async () => {
      const { h, s1, viewer, roomId } = await scene();
      const code = await gift();
      const other = await gift();
      const a = await send(roomId, viewer, body(code, [h, s1], { quantity: 10 }));
      clock.advance(2);
      const b = await send(roomId, viewer, body(code, [s1, h], { quantity: 1 }));
      clock.advance(5);
      const c = await send(roomId, viewer, body(code, [h, s1], { quantity: 66 }));
      clock.advance(5.001);
      const d = await send(roomId, viewer, body(code, [h, s1]));
      const e = await send(roomId, viewer, body(other, [h, s1]));
      const f = await send(roomId, viewer, body(other, [h]));
      const combos = [a, b, c, d, e, f].map((r) => {
        expect(r.status).toBe(201);
        return r.body.gift.combo as { id: string; count: number; quantity: number };
      });
      expect(combos[0]).toEqual({ id: a.body.gift.id, count: 1, quantity: 10 });
      expect(combos[1]).toEqual({ id: a.body.gift.id, count: 2, quantity: 11 });
      expect(combos[2]).toEqual({ id: a.body.gift.id, count: 3, quantity: 77 });
      expect(combos[3]).toEqual({ id: d.body.gift.id, count: 1, quantity: 1 });
      expect(combos[4]).toEqual({ id: e.body.gift.id, count: 1, quantity: 1 });
      expect(combos[5]).toEqual({ id: f.body.gift.id, count: 1, quantity: 1 });
      await settle(ctx);
      expect(
        giftsTo(roomId).map((m) => (JSON.parse(m.payload) as { gift: { combo: unknown } }).gift.combo),
      ).toEqual(combos);
    });
  });

  // ---- Refusals ----------------------------------------------------------------------------------

  // v1.41-live (D178, owner «والهدايا يجب أن تظهر في شريط في جميع البثوث»).
  describe('D178 global gift strip', () => {
    it('a send of ≥ GIFT_GLOBAL_TICKER_MIN_COINS (1000) is a `gift-ticker` in every other live, one at a time; smaller ones stay in their room', async () => {
      const { h, viewer, roomId } = await scene();
      const other = await goLive(await host());
      const third = await goLive(await host());
      const tickers = (room: string) => media.broadcastsOf(room).filter((m) => m.type === 'gift-ticker');
      const before = { other: tickers(other).length, third: tickers(third).length };
      const big = await gift({ priceCoins: 1_000 });
      const small = await gift({ priceCoins: 10 });
      expect((await send(roomId, viewer, body(small, [h]))).status).toBe(201);
      await settle(ctx);
      expect(tickers(other)).toHaveLength(before.other);
      const sent = await send(roomId, viewer, body(big, [h]));
      expect(sent.status).toBe(201);
      await settle(ctx);
      // Its own room has the `gift` message only.
      expect(media.broadcastsOf(roomId).filter((m) => m.type === 'gift-ticker')).toEqual([]);
      expect(giftsTo(roomId).length).toBeGreaterThanOrEqual(2);
      for (const room of [other, third]) {
        expect(tickers(room).at(-1)).toMatchObject({
          type: 'gift-ticker',
          gift: { id: sent.body.gift.id, roomId, giftCode: big, totalCoins: 1_000 },
          room: { id: roomId, host: { id: h.id } },
        });
      }
      expect(tickers(other)).toHaveLength(before.other + 1);
      // A second big send inside the 3 s gap waits, then goes out (the newest).
      const next = await send(roomId, viewer, body(big, [h]));
      expect(next.status).toBe(201);
      await settle(ctx);
      expect(tickers(other)).toHaveLength(before.other + 1);
      await new Promise((r) => setTimeout(r, 3_600));
      await settle(ctx);
      expect(tickers(other)).toHaveLength(before.other + 2);
      expect(tickers(other).at(-1)).toMatchObject({ gift: { id: next.body.gift.id } });
    });
  });

  describe('refusals', () => {
    it('401 without a token; 404 for an unknown room; 400 for the body', async () => {
      const { h, viewer, roomId } = await scene();
      const code = await gift();
      expect((await send(roomId, null, body(code, [h]))).status).toBe(401);
      expectError(await send(randomUUID(), viewer, body(code, [h])), 404, 'NOT_FOUND');

      const bad = async (extra: object, field: string, issue: string) => {
        const res = await send(roomId, viewer, body(code, [h], extra));
        expectError(res, 400, 'VALIDATION_FAILED');
        expect(res.body.error.details).toEqual([{ field, issue }]);
      };
      await bad({ quantity: 2 }, 'quantity', 'invalid_value');
      await bad({ quantity: 0 }, 'quantity', 'invalid_value');
      await bad({ recipients: [] }, 'recipients', 'too_few');
      await bad({ recipients: [h.username, h.username] }, 'recipients', 'invalid_value');
      await bad({ source: 'FREE' }, 'source', 'invalid_value');
      await bad({ clientId: 'nope' }, 'clientId', 'invalid_format');
      await bad({ extra: true }, 'extra', 'unknown_field');
      expect(await wallet(viewer)).toBe(10_000);
    });

    it('D128: a viewer who is not seated cannot name themself (409, like any unseated recipient)', async () => {
      const { h, viewer, roomId } = await scene();
      const code = await gift();
      expectError(
        await send(roomId, viewer, body(code, [h, viewer])),
        409,
        'LIVE_GIFT_RECIPIENT_UNAVAILABLE',
      );
      expectError(await send(roomId, viewer, body(code, [viewer])), 409, 'LIVE_GIFT_RECIPIENT_UNAVAILABLE');
      expect(await wallet(viewer)).toBe(10_000);
      await settle(ctx);
      expect(giftsTo(roomId)).toHaveLength(0);
    });

    it('409 LIVE_GIFT_RECIPIENT_UNAVAILABLE: not seated, unknown, blocked; 409 GIFT_UNAVAILABLE', async () => {
      const { h, s1, viewer, roomId } = await scene();
      const other = await signup();
      await join(roomId, other);
      const code = await gift();
      // A viewer who is not seated.
      expectError(await send(roomId, viewer, body(code, [h, other])), 409, 'LIVE_GIFT_RECIPIENT_UNAVAILABLE');
      // An unknown username.
      expectError(
        await send(roomId, viewer, { ...body(code, [h]), recipients: ['nobody_here_xyz'] }),
        409,
        'LIVE_GIFT_RECIPIENT_UNAVAILABLE',
      );
      // Someone who left their seat.
      await ctx.prisma.liveRoomSeat.deleteMany({ where: { roomId, userId: s1.id } });
      expectError(await send(roomId, viewer, body(code, [s1])), 409, 'LIVE_GIFT_RECIPIENT_UNAVAILABLE');
      // A block either way between the sender and a recipient.
      const { h: h2, s1: g, viewer: v2, roomId: room2 } = await scene();
      await ctx.prisma.userBlock.create({ data: { blockerId: g.id, blockedId: v2.id } });
      expectError(await send(room2, v2, body(code, [h2, g])), 409, 'LIVE_GIFT_RECIPIENT_UNAVAILABLE');
      expect((await send(room2, v2, body(code, [h2]))).status).toBe(201);
      // Unknown and disabled gifts.
      expectError(await send(roomId, viewer, body('no_such_gift', [h])), 409, 'GIFT_UNAVAILABLE');
      const off = await gift();
      await ctx.prisma.gift.update({ where: { code: off }, data: { enabled: false } });
      expectError(await send(roomId, viewer, body(off, [h])), 409, 'GIFT_UNAVAILABLE');
      expect(await wallet(viewer)).toBe(10_000);
    });

    it('403 not in the room, 403 LIVE_KICKED, 409 LIVE_ROOM_ENDED', async () => {
      const { h, s1, viewer, roomId } = await scene();
      const code = await gift();
      const outsider = await signup();
      await coins(outsider, 100);
      expectError(await send(roomId, outsider, body(code, [h])), 403, 'LIVE_CHAT_NOT_IN_ROOM');

      const kicked = await ctx.http
        .post(`/api/v1/live/rooms/${roomId}/kicks`)
        .set(auth(h))
        .send({ username: viewer.username });
      expect(kicked.status).toBe(201);
      expectError(await send(roomId, viewer, body(code, [h])), 403, 'LIVE_KICKED');

      const ended = await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(h));
      expect(ended.status).toBe(200);
      expectError(await send(roomId, s1, body(code, [h])), 409, 'LIVE_ROOM_ENDED');
    });
  });

  // ---- Sending from the bag ----------------------------------------------------------------------

  describe('sending from the bag', () => {
    it('takes quantity × recipients from the bag, no coins; 409 GIFT_BAG_INSUFFICIENT when short', async () => {
      const { h, s1, viewer, roomId } = await scene();
      const code = await gift({ priceCoins: 2 });
      await stock(viewer, code, 25);

      const res = await send(roomId, viewer, body(code, [h, s1], { quantity: 10, source: 'BAG' }));
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      expectContract(res, 'sendLiveGift');
      expect(res.body).toMatchObject({ coins: 10_000, bagQuantity: 5 });
      expect(res.body.gift).toMatchObject({ source: 'BAG', unitPrice: 2, quantity: 10, totalCoins: 40 });
      expect((await ledger(viewer)).filter((r) => r.reason === 'LIVE_GIFT')).toEqual([]);
      // The value still counts for the room and the contributor.
      expect((await roomScore(roomId, h)).parts.supportPoints).toBe(4_000);

      const short = await send(roomId, viewer, body(code, [h, s1], { quantity: 10, source: 'BAG' }));
      expectError(short, 409, 'GIFT_BAG_INSUFFICIENT');
      const none = await send(roomId, s1, body(code, [h], { source: 'BAG' }));
      expectError(none, 409, 'GIFT_BAG_INSUFFICIENT');

      const bag = await ctx.http.get('/api/v1/me/gifts/bag').set(auth(viewer));
      expect(bag.body.data.map((g: { code: string; quantity: number }) => [g.code, g.quantity])).toEqual([
        [code, 5],
      ]);
      const one = await send(roomId, viewer, body(code, [h], { source: 'BAG' }));
      expect(one.body.bagQuantity).toBe(4);
      // A COINS send reports what the bag still holds.
      const paid = await send(roomId, viewer, body(code, [h]));
      expect(paid.body).toMatchObject({ coins: 9_998, bagQuantity: 4 });
      await settle(ctx);
      expect(giftsTo(roomId)).toHaveLength(3);
    });
  });

  // ---- Levels ------------------------------------------------------------------------------------

  describe('levels', () => {
    const publish = async (code: 'ATTRACTIVENESS' | 'SUPPORT') => {
      const category = await ctx.prisma.levelCategory.create({
        data: { code, nameAr: 'فئة', nameEn: code, descriptionAr: 'وصف', descriptionEn: 'About' },
      });
      const version = await ctx.prisma.levelCategoryVersion.create({
        data: {
          categoryId: category.id,
          versionNumber: 1,
          status: 'PUBLISHED',
          multiplier: '1',
          valueUnit: 'COIN',
          publishedAt: clock.now(),
          levels: {
            create: [
              { levelNumber: 1, nameAr: 'أ', nameEn: 'A', requiredPoints: 0n },
              { levelNumber: 2, nameAr: 'ب', nameEn: 'B', requiredPoints: 50n },
              { levelNumber: 3, nameAr: 'ج', nameEn: 'C', requiredPoints: 1_000n },
            ],
          },
        },
      });
      await ctx.prisma.levelCategory.update({
        where: { id: category.id },
        data: { isEnabled: true, publishedVersionId: version.id },
      });
    };
    const levels = async (u: TestUser) => {
      const res = await ctx.http.get('/api/v1/levels/me').set(auth(u));
      expect(res.status).toBe(200);
      expectContract(res, 'getMyLevels');
      const by = new Map<string, { points: string; level: { levelNumber: number } | null }>();
      for (const s of res.body.data) by.set(s.category, s);
      return by;
    };

    it('gives each recipient charm and the sender support (coins × multiplier); the room level follows', async () => {
      // Before the categories exist nothing is credited (and nothing fails).
      const pre = await scene();
      const early = await gift();
      expect((await send(pre.roomId, pre.viewer, body(early, [pre.h]))).status).toBe(201);
      expect(await ctx.prisma.pointsLedgerEntry.count({ where: { userId: pre.h.id } })).toBe(0);

      await publish('ATTRACTIVENESS');
      await publish('SUPPORT');
      // The other two exist unpublished (GET /levels/me always lists four).
      for (const code of ['WIZARD', 'GAMING'] as const) {
        await ctx.prisma.levelCategory.create({
          data: { code, nameAr: 'فئة', nameEn: code, descriptionAr: 'وصف', descriptionEn: 'About' },
        });
      }
      const { h, s1, viewer, roomId } = await scene();
      const code = await gift({ priceCoins: 6 });
      const infoBefore = (await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).infoVersion;

      const res = await send(roomId, viewer, body(code, [h, s1], { quantity: 10 }));
      expect(res.status).toBe(201);
      const giftId = res.body.gift.id as string;

      const charm = await ctx.prisma.pointsLedgerEntry.findMany({
        where: { sourceType: 'GIFT_RECEIVED', sourceTransactionId: { startsWith: `gift:${giftId}:` } },
        orderBy: { userId: 'asc' },
      });
      expect(charm.map((e) => [e.userId, e.pointsDelta, e.sourceValue, e.sourceTransactionId])).toEqual(
        [
          [h.id, 60n, 60n, `gift:${giftId}:${h.id}`],
          [s1.id, 60n, 60n, `gift:${giftId}:${s1.id}`],
        ].sort((a, b) => String(a[0]).localeCompare(String(b[0]))),
      );
      const support = await ctx.prisma.pointsLedgerEntry.findMany({
        where: { userId: viewer.id, sourceType: 'GIFT_SENT' },
      });
      expect(support.map((e) => e.pointsDelta)).toEqual([60n, 60n]);

      expect((await levels(h)).get('ATTRACTIVENESS')).toMatchObject({
        points: '60',
        level: { levelNumber: 2 },
      });
      expect((await levels(s1)).get('ATTRACTIVENESS')).toMatchObject({ points: '60' });
      expect((await levels(viewer)).get('SUPPORT')).toMatchObject({
        points: '120',
        level: { levelNumber: 2 },
      });

      // The host's charm level is the room level: it moved, so the info version did.
      const room = await ctx.http.get(`/api/v1/live/rooms/${roomId}`).set(auth(viewer));
      expect(room.body.roomLevel).toBe(2);
      expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).infoVersion).toBe(
        infoBefore + 1,
      );
    });

    it('D128: a gift to oneself gives that person both charm and support, once', async () => {
      // The categories were published by the test above.
      const { h, s1, roomId } = await scene();
      const code = await gift({ priceCoins: 6 });
      const first = body(code, [h], { quantity: 10 });
      const res = await send(roomId, h, first);
      expect(res.status).toBe(201);
      const giftId = res.body.gift.id as string;
      // A retry with the same clientId credits nothing again.
      expect((await send(roomId, h, first)).status).toBe(200);
      const credits = await ctx.prisma.pointsLedgerEntry.findMany({
        where: { sourceTransactionId: `gift:${giftId}:${h.id}` },
      });
      expect(
        credits
          .map((e) => [e.userId, e.sourceType, e.pointsDelta])
          .sort((x, y) => String(x[1]).localeCompare(String(y[1]))),
      ).toEqual([
        [h.id, 'GIFT_RECEIVED', 60n],
        [h.id, 'GIFT_SENT', 60n],
      ]);
      expect((await levels(h)).get('ATTRACTIVENESS')).toMatchObject({
        points: '60',
        level: { levelNumber: 2 },
      });
      expect((await levels(h)).get('SUPPORT')).toMatchObject({ points: '60' });

      // A seated guest gifting themself earns the same way.
      const guest = await send(roomId, s1, body(code, [s1]));
      expect(guest.status).toBe(201);
      expect((await levels(s1)).get('ATTRACTIVENESS')).toMatchObject({ points: '6' });
      expect((await levels(s1)).get('SUPPORT')).toMatchObject({ points: '6' });
    });
  });

  // ---- Contributions with taps -------------------------------------------------------------------

  it('the Contribution list adds gifts to taps; ties by who reached the total first', async () => {
    const { h, s1, viewer, roomId } = await scene();
    const code = await gift({ priceCoins: 1 });
    clock.advance(5);
    const tapped = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/taps`)
      .set(auth(viewer))
      .send({ count: 10 });
    expect(tapped.status).toBe(200);
    clock.advance(1);
    expect((await send(roomId, s1, body(code, [h]))).status).toBe(201); // 100 points
    clock.advance(1);
    expect((await send(roomId, viewer, body(code, [h]))).status).toBe(201); // 10 + 100
    const list = await ctx.http.get(`/api/v1/live/rooms/${roomId}/contributors`).set(auth(h));
    expect(
      list.body.data.map((c: { user: { id: string }; points: number }) => [c.user.id, c.points]),
    ).toEqual([
      [viewer.id, 110],
      [s1.id, 100],
    ]);
    // A gift-only contributor's first tap batch is a first batch (at most 10).
    clock.advance(30);
    const first = await ctx.http.post(`/api/v1/live/rooms/${roomId}/taps`).set(auth(s1)).send({ count: 50 });
    expect(first.body.accepted).toBe(10);
    const row = await ctx.prisma.liveRoomTapper.findUniqueOrThrow({
      where: { roomId_userId: { roomId, userId: s1.id } },
    });
    expect([row.counted, Number(row.supportCoins), Number(row.points)]).toEqual([10, 1, 110]);
    const tie = await ctx.http.get(`/api/v1/live/rooms/${roomId}/contributors`).set(auth(h));
    expect(tie.body.data.map((c: { user: { id: string } }) => c.user.id)).toEqual([viewer.id, s1.id]);
  });

  // ---- gift-admin --------------------------------------------------------------------------------

  describe('gift-admin', () => {
    it('add, update, disable, enable, list, grant and bag, each audited', async () => {
      const code = `cli_${randomUUID().slice(0, 8).replace(/-/g, '')}`;
      const add = giftAdmin(
        'add',
        code,
        '--category',
        'EVENT',
        '--name-ar',
        'كعكة',
        '--name-en',
        'Cake',
        '--price',
        '99',
        '--asset',
        'gift_cake',
        '--animation',
        'fx_cake',
        '--sort',
        '7',
        '--badge',
        'NEW',
      );
      expect(add, add.out).toEqual({ status: 0, out: `+${code} (EVENT, 99 coins).\n` });
      expect(await ctx.prisma.gift.findUniqueOrThrow({ where: { code } })).toMatchObject({
        category: 'EVENT',
        nameAr: 'كعكة',
        nameEn: 'Cake',
        priceCoins: 99,
        assetKey: 'gift_cake',
        animationKey: 'fx_cake',
        sortOrder: 7,
        badge: 'NEW',
        enabled: true,
      });
      expect(
        giftAdmin(
          'add',
          code,
          '--category',
          'FUN',
          '--name-ar',
          'x',
          '--name-en',
          'x',
          '--price',
          '1',
          '--asset',
          'a',
        ).status,
      ).toBe(1);
      expect(giftAdmin('add', 'Bad-Code', '--category', 'FUN').status).toBe(1);
      expect(giftAdmin('add', `${code}x`, '--category', 'FUN').out).toContain('Missing');
      expect(giftAdmin('update', code, '--price', '0').status).toBe(1);

      expect(giftAdmin('update', code, '--price', '120', '--animation', 'none')).toEqual({
        status: 0,
        out: `${code}: priceCoins, animationKey updated.\n`,
      });
      expect(giftAdmin('update', code, '--price', '120')).toEqual({
        status: 0,
        out: `${code}: nothing changed.\n`,
      });
      expect(giftAdmin('disable', code)).toEqual({ status: 0, out: `${code}: disabled.\n` });
      expect(giftAdmin('disable', code).out).toContain('already disabled');
      const listed = giftAdmin('list');
      expect(listed.status).toBe(0);
      expect(listed.out).toContain(
        `- EVENT 7 ${code} 120 coins asset=gift_cake animation=none badge=NEW "كعكة" / "Cake"`,
      );
      expect(listed.out).toContain(`"كعكة" / "Cake" tag=none image=none animation-file=none\n`);
      expect(giftAdmin('enable', code)).toEqual({ status: 0, out: `${code}: enabled.\n` });
      expect(giftAdmin('disable', 'no_such_gift').status).toBe(1);

      // v1.24.3-live: the optional tag (sub-category).
      expect(giftAdmin('update', code, '--tag', 'glory').out).toContain(
        'a tag needs its code and both names',
      );
      expect(
        giftAdmin('update', code, '--tag', 'Bad-Tag', '--tag-ar', 'مجد', '--tag-en', 'Glory').status,
      ).toBe(1);
      expect(giftAdmin('update', code, '--tag', 'none', '--tag-ar', 'مجد').status).toBe(1);
      expect(giftAdmin('update', code, '--tag', 'glory', '--tag-ar', 'مجد', '--tag-en', 'Glory')).toEqual({
        status: 0,
        out: `${code}: tagCode, tagNameAr, tagNameEn updated.\n`,
      });
      expect(giftAdmin('update', code, '--tag-en', 'Glory Hall')).toEqual({
        status: 0,
        out: `${code}: tagNameEn updated.\n`,
      });
      expect(giftAdmin('list').out).toContain(
        `"كعكة" / "Cake" tag=glory "مجد" / "Glory Hall" image=none animation-file=none\n`,
      );
      expect(giftAdmin('update', code, '--tag', 'none')).toEqual({
        status: 0,
        out: `${code}: tagCode, tagNameAr, tagNameEn updated.\n`,
      });
      expect(await ctx.prisma.gift.findUniqueOrThrow({ where: { code } })).toMatchObject({
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      });
      const tagged = `${code}t`;
      expect(
        giftAdmin(
          'add',
          tagged,
          '--category',
          'POPULAR',
          '--name-ar',
          'صندوق',
          '--name-en',
          'Box',
          '--price',
          '5',
          '--asset',
          'gift_box',
          '--tag',
          'treasure_box',
          '--tag-ar',
          'صندوق الكنز',
          '--tag-en',
          'Treasure Box',
        ),
      ).toEqual({ status: 0, out: `+${tagged} (POPULAR, 5 coins).\n` });
      expect(await ctx.prisma.gift.findUniqueOrThrow({ where: { code: tagged } })).toMatchObject({
        tagCode: 'treasure_box',
        tagNameAr: 'صندوق الكنز',
        tagNameEn: 'Treasure Box',
      });
      expect(
        giftAdmin(
          'add',
          `${code}u`,
          '--category',
          'POPULAR',
          '--name-ar',
          'x',
          '--name-en',
          'x',
          '--price',
          '5',
          '--asset',
          'a',
          '--tag-ar',
          'مجد',
        ).out,
      ).toContain('a tag needs its code and both names');

      const u = await signup();
      expect(giftAdmin('grant', u.email, code, '30')).toEqual({
        status: 0,
        out: `${u.email}: +30 ${code}, holds 30.\n`,
      });
      expect(giftAdmin('grant', u.email.toUpperCase(), code, '5').out).toContain('holds 35');
      expect(giftAdmin('grant', u.email, code, '0').status).toBe(1);
      expect(giftAdmin('grant', u.email, 'no_such_gift', '1').status).toBe(1);
      expect(giftAdmin('grant', 'nobody@example.com', code, '1').status).toBe(1);
      expect(giftAdmin('bag', u.email)).toEqual({ status: 0, out: `  ${code} 35\n` });

      const bag = await ctx.http.get('/api/v1/me/gifts/bag').set(auth(u));
      expect(bag.body.data).toEqual([expect.objectContaining({ code, quantity: 35, priceCoins: 120 })]);

      const audits = await ctx.prisma.auditLog.findMany({
        where: { OR: [{ targetId: code }, { targetId: u.id, action: 'gift.grant' }] },
        orderBy: { createdAt: 'asc' },
      });
      expect(audits.map((a) => a.action)).toEqual([
        'gift.add',
        'gift.update',
        'gift.disable',
        'gift.enable',
        'gift.update',
        'gift.update',
        'gift.update',
        'gift.grant',
        'gift.grant',
      ]);
      expect(audits[1]!.metadata).toEqual({
        changes: { priceCoins: { from: 99, to: 120 }, animationKey: { from: 'fx_cake', to: null } },
        via: 'cli',
      });
      expect(audits[5]!.metadata).toEqual({
        changes: { tagNameEn: { from: 'Glory', to: 'Glory Hall' } },
        via: 'cli',
      });
      expect(audits[7]!.metadata).toEqual({ gift: code, quantity: 30, total: 30, via: 'cli' });
    });
  });
});
