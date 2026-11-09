/**
 * D305 (owner 2026-11-07: «هذا شريط الهدايا والآخر شريط الألعاب، يظهر في جميع الغرف …»; contract v1.85-live, CONVENTIONS
 * §10.115): the global strips. A gift send worth ≥ GIFT_GLOBAL_TICKER_MIN_COINS (default 500 000, on ONE gift's price) is a `gift-ticker`
 * (`kind` GIFT) in every LIVE room, its own included; a game prize ≥ GAME_WIN_TICKER_MIN_TICKETS (default 1 000 000)
 * offered through the games' hook (`LiveGiftTickerService.offerGameWin`) is a `game-win-ticker` (`kind` GAME_WIN) in every
 * LIVE room; one strip every 3 s per kind (D305b: two lanes, so both can show at once). The per-account switches `giftStrip` / `gameStrip` of
 * `/me/notification-settings`. End to end against PostgreSQL + Redis with the in-memory media server.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { LiveGiftTickerService } from '../src/modules/live/live-gift-ticker.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, settle, type TestContext } from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';

describe('D305 global strips', { timeout: 120_000 }, () => {
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let moderator: Admin;
  let user: Person;
  let strips: LiveGiftTickerService;
  let seq = 0;

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
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: `Live of ${u.username}`, mode: 'AUDIO', seatCount: 10 });
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
  const coins = (u: TestUser, amount: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  const gift = async (price: number): Promise<string> => {
    seq += 1;
    const code = `gs${String(seq)}_${randomUUID().slice(0, 6)}`;
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
  const send = async (roomId: string, from: TestUser, to: TestUser, code: string, quantity = 1) => {
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(from))
      .send({ giftCode: code, quantity, recipients: [to.username], source: 'COINS', clientId: randomUUID() });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    await settle(ctx);
    return res.body as { gift: { id: string } };
  };
  const giftStrips = (room: string) => media.broadcastsOf(room, 'gift-ticker');
  const gameStrips = (room: string) => media.broadcastsOf(room, 'game-win-ticker');
  const topicsOf = (room: string, type: string) =>
    media.broadcasts
      .filter((b) => b.room === room && b.payload.includes(`"type":"${type}"`))
      .map((b) => b.topic);
  /** Waits (real time) until `check` holds — the strips' gate is 3 s. */
  const until = async (check: () => boolean, ms = 8_000) => {
    const end = Date.now() + ms;
    while (!check()) {
      if (Date.now() > end) throw new Error('timed out');
      await new Promise((r) => setTimeout(r, 100));
      await settle(ctx);
    }
  };
  /** The gate is free again (no strip in the last 3 s). */
  const gapOver = () => new Promise((r) => setTimeout(r, 3_200));

  let hA: TestUser;
  let viewer: TestUser;
  let roomA: string;
  let roomB: string;
  let roomC: string;

  beforeAll(async () => {
    // Only `Date` is faked (the panel's authenticator codes); the strips' gates run on real timers.
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    // The thresholds are the defaults (500 000 coins, 1 000 000 tickets): not overridden.
    ctx = await createTestApp(
      {
        ADMIN_TOTP_KEY: ADMIN_KEY,
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '10000/900',
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
      },
      [{ token: LIVE_MEDIA_PROVIDER, value: media }],
    );
    owner = await p.makeAdmin(['OWNER']);
    moderator = await p.makeAdmin(['MODERATION']);
    user = await p.signup();
    vi.useRealTimers();
    strips = ctx.app.get(LiveGiftTickerService);
    hA = await host();
    viewer = await signup();
    roomA = await goLive(hA);
    roomB = await goLive(await host());
    roomC = await goLive(await host());
    await join(roomA, viewer);
    await coins(viewer, 5_000_000);
  });
  afterAll(async () => {
    await ctx?.prisma.siteSetting.deleteMany({ where: { key: 'globalStrips' } });
    await ctx?.close();
    vi.useRealTimers();
  });

  it('the defaults: 500 000 coins and 1 000 000 tickets', async () => {
    expect(ctx.config.live.giftTickerMinCoins).toBe(500_000);
    expect(ctx.config.live.gameWinTickerMinTickets).toBe(1_000_000);
    expect(await strips.thresholds()).toEqual({
      giftMinCoins: 500_000,
      gameMinTickets: 1_000_000,
      luckyChatMinMultiplier: 250,
      luckyGlobalMultipliers: [250, 500, 1000],
      luckyGlobalGapSeconds: 10,
    });
  });

  it("gifts strip (owner: one gift's price): 499 999 and 10 × 50 000 stay in the room; a 500 000 gift is a `gift-ticker` kind GIFT in every live, its own too", async () => {
    const under = await gift(499_999);
    await send(roomA, viewer, hA, under);
    // 10 × 50 000 = 500 000 coins, but one gift is 50 000: no strip (D305 owner decision; D178 counted the send).
    const ten = await gift(50_000);
    await send(roomA, viewer, hA, ten, 10);
    await new Promise((r) => setTimeout(r, 200));
    await settle(ctx);
    for (const r of [roomA, roomB, roomC]) expect(giftStrips(r)).toEqual([]);
    const big = await gift(500_000);
    const sent = await send(roomA, viewer, hA, big);
    await until(() => giftStrips(roomC).length === 1);
    for (const r of [roomA, roomB, roomC]) {
      expect(giftStrips(r)).toHaveLength(1);
      expect(giftStrips(r)[0]).toMatchObject({
        type: 'gift-ticker',
        kind: 'GIFT',
        gift: {
          id: sent.gift.id,
          roomId: roomA,
          giftCode: big,
          quantity: 1,
          unitPrice: 500_000,
          totalCoins: 500_000,
        },
        room: { id: roomA, title: `Live of ${hA.username}`, host: { id: hA.id } },
      });
      expect(topicsOf(r, 'gift-ticker')).toEqual(['gift']);
    }
    // The origin room is told first.
    const order = media.broadcasts.filter((b) => b.payload.includes('"gift-ticker"')).map((b) => b.room);
    expect(order[0]).toBe(roomA);
    await gapOver();
  });

  it('games strip: the hook below 1 000 000 tickets does nothing; at 1 000 000 a `game-win-ticker` kind GAME_WIN in every live; a repeated id is ignored', async () => {
    const winner = await signup();
    const base = {
      gameCode: 'lucky_wheel',
      gameName: 'Lucky Wheel',
      gameImageUrl: 'https://cdn.example.com/games/wheel.webp',
      winnerId: winner.id,
      roomId: roomB,
      createdAt: new Date().toISOString(),
    };
    await strips.offerGameWin({ ...base, id: randomUUID(), tickets: 999_999 });
    await settle(ctx);
    for (const r of [roomA, roomB, roomC]) expect(gameStrips(r)).toEqual([]);
    const id = randomUUID();
    await strips.offerGameWin({ ...base, id, tickets: 1_000_000 });
    await until(() => gameStrips(roomC).length === 1);
    for (const r of [roomA, roomB, roomC]) {
      expect(gameStrips(r)).toEqual([
        {
          type: 'game-win-ticker',
          kind: 'GAME_WIN',
          win: {
            id,
            game: {
              code: 'lucky_wheel',
              name: 'Lucky Wheel',
              imageUrl: 'https://cdn.example.com/games/wheel.webp',
            },
            winner: expect.objectContaining({ id: winner.id, username: winner.username }),
            tickets: 1_000_000,
            roomId: roomB,
            createdAt: base.createdAt,
          },
          room: expect.objectContaining({
            id: roomB,
            host: expect.objectContaining({ id: expect.any(String) }),
          }),
        },
      ]);
      expect(topicsOf(r, 'game-win-ticker')).toEqual(['gift']);
    }
    await gapOver();
    // The same prize offered again (a retried game call): no second strip.
    await strips.offerGameWin({ ...base, id, tickets: 1_000_000 });
    await settle(ctx);
    await new Promise((r) => setTimeout(r, 300));
    expect(gameStrips(roomC)).toHaveLength(1);
    await gapOver();
  });

  it('games strip without a live: `room` and `win.roomId` are null, still every live; an unknown winner makes none', async () => {
    const winner = await signup();
    const id = randomUUID();
    const before = gameStrips(roomA).length;
    await strips.offerGameWin({
      id,
      gameCode: 'dice',
      gameName: 'Dice',
      gameImageUrl: null,
      winnerId: winner.id,
      tickets: 2_500_000,
      roomId: null,
      createdAt: new Date().toISOString(),
    });
    await until(() => gameStrips(roomC).some((m) => (m.win as { id: string }).id === id));
    for (const r of [roomA, roomB, roomC]) {
      expect(gameStrips(r).at(-1)).toMatchObject({
        kind: 'GAME_WIN',
        win: { id, game: { imageUrl: null }, tickets: 2_500_000, roomId: null },
        room: null,
      });
    }
    expect(gameStrips(roomA)).toHaveLength(before + 1);
    await gapOver();
    await strips.offerGameWin({
      id: randomUUID(),
      gameCode: 'dice',
      gameName: 'Dice',
      gameImageUrl: null,
      winnerId: randomUUID(),
      tickets: 2_500_000,
      roomId: null,
      createdAt: new Date().toISOString(),
    });
    await settle(ctx);
    expect(gameStrips(roomA)).toHaveLength(before + 1);
    await gapOver();
  });

  it('D305b: each kind has its own lane — a game win right after a big gift goes out at once; a second game win waits 3 s', async () => {
    const winner = await signup();
    const big = await gift(500_000);
    const giftsBefore = giftStrips(roomB).length;
    const gamesBefore = gameStrips(roomB).length;
    await send(roomA, viewer, hA, big);
    await until(() => giftStrips(roomB).length === giftsBefore + 1);
    const offer = (id: string) =>
      strips.offerGameWin({
        id,
        gameCode: 'wheel',
        gameName: 'Wheel',
        gameImageUrl: null,
        winnerId: winner.id,
        tickets: 1_000_000,
        roomId: roomA,
        createdAt: new Date().toISOString(),
      });
    const first = randomUUID();
    await offer(first);
    await settle(ctx);
    // Not held by the gift's gate: both strips at the same time.
    expect(gameStrips(roomB)).toHaveLength(gamesBefore + 1);
    expect(gameStrips(roomB).at(-1)).toMatchObject({ win: { id: first }, room: { id: roomA } });
    const second = randomUUID();
    await offer(second);
    await settle(ctx);
    // Inside its own lane's gap: waits.
    expect(gameStrips(roomB)).toHaveLength(gamesBefore + 1);
    await until(() => gameStrips(roomB).length === gamesBefore + 2);
    expect(gameStrips(roomB).at(-1)).toMatchObject({ win: { id: second } });
    await gapOver();
  });

  it('the per-account switches `giftStrip` / `gameStrip`: on by default, each switched alone, kept', async () => {
    const u = await signup();
    const get = await ctx.http.get('/api/v1/me/notification-settings').set(auth(u));
    expect(get.status).toBe(200);
    expectContract(get, 'getNotificationSettings');
    expect(get.body).toMatchObject({ giftStrip: true, gameStrip: true, luckyStrip: true });
    const off = await ctx.http
      .patch('/api/v1/me/notification-settings')
      .set(auth(u))
      .send({ giftStrip: false });
    expect(off.status).toBe(200);
    expectContract(off, 'updateNotificationSettings');
    expect(off.body).toMatchObject({ giftStrip: false, gameStrip: true, likes: true });
    const games = await ctx.http
      .patch('/api/v1/me/notification-settings')
      .set(auth(u))
      .send({ gameStrip: false });
    expect(games.body).toMatchObject({ giftStrip: false, gameStrip: false });
    const again = await ctx.http.get('/api/v1/me/notification-settings').set(auth(u));
    expect(again.body).toMatchObject({ giftStrip: false, gameStrip: false });
    const row = await ctx.prisma.notificationSettings.findUnique({ where: { userId: u.id } });
    expect(row).toMatchObject({ giftStrip: false, gameStrip: false });
    const bad = await ctx.http
      .patch('/api/v1/me/notification-settings')
      .set(auth(u))
      .send({ giftStrip: 'no' });
    expect(bad.status).toBe(400);
    expectContract(bad, 'updateNotificationSettings');
    // The server keeps sending: the switch is the app's (one message per room, not per person).
    expect(giftStrips(roomA).length).toBeGreaterThan(0);
  });

  it('the panel (OWNER only, audited): GET the configuration; PUT both thresholds; bad bodies 400; other roles 403; a bearer 401', async () => {
    const get = await p.send(owner, 'get', '/admin/global-strips');
    expect(get.status).toBe(200);
    expectContract(get, 'getAdminGlobalStrips');
    // v1.89-live (D318): with the lucky chat threshold and the multipliers to choose from.
    expect(get.body).toEqual({
      giftMinCoins: 500_000,
      gameMinTickets: 1_000_000,
      luckyChatMinMultiplier: 250,
      luckyGlobalMultipliers: [250, 500, 1000],
      luckyGlobalGapSeconds: 10,
      luckyMultipliers: [5, 10, 25, 50, 100, 250, 500, 1000],
    });
    expect((await p.send(moderator, 'get', '/admin/global-strips')).status).toBe(403);
    const denied = await p.send(moderator, 'put', '/admin/global-strips', {
      giftMinCoins: 1,
      gameMinTickets: 1,
    });
    expect(denied.status).toBe(403);
    expectContract(denied, 'updateAdminGlobalStrips');
    const bearer = await ctx.http
      .put('/api/v1/admin/global-strips')
      .set('Authorization', `Bearer ${user.token}`)
      .send({ giftMinCoins: 1, gameMinTickets: 1 });
    expect(bearer.status).toBe(401);
    for (const bad of [
      { giftMinCoins: 0, gameMinTickets: 1 },
      { giftMinCoins: 1.5, gameMinTickets: 1 },
      { giftMinCoins: '5', gameMinTickets: 1 },
      { giftMinCoins: 5 },
      { giftMinCoins: 5, gameMinTickets: 1, x: 1 },
    ]) {
      const res = await p.send(owner, 'put', '/admin/global-strips', bad);
      expect(res.status, JSON.stringify(bad)).toBe(400);
      expectContract(res, 'updateAdminGlobalStrips');
    }
    const put = await p.send(owner, 'put', '/admin/global-strips', {
      giftMinCoins: 20_000,
      gameMinTickets: 300,
      reason: 'launch week',
    });
    expect(put.status, JSON.stringify(put.body)).toBe(200);
    expectContract(put, 'updateAdminGlobalStrips');
    expect(put.body).toEqual({
      giftMinCoins: 20_000,
      gameMinTickets: 300,
      luckyChatMinMultiplier: 250,
      luckyGlobalMultipliers: [250, 500, 1000],
      luckyGlobalGapSeconds: 10,
      luckyMultipliers: [5, 10, 25, 50, 100, 250, 500, 1000],
    });
    const audit = await ctx.prisma.auditLog.findMany({
      where: { action: 'site.settings.update', actorUserId: owner.id },
    });
    expect(audit).toHaveLength(1);
    expect(audit[0]!.metadata).toMatchObject({
      key: 'globalStrips',
      before: { giftMinCoins: 500_000, gameMinTickets: 1_000_000, luckyChatMinMultiplier: 250 },
      after: { giftMinCoins: 20_000, gameMinTickets: 300, luckyChatMinMultiplier: 250 },
      reason: 'launch week',
      via: 'panel',
    });
    expect((await p.send(owner, 'get', '/admin/global-strips')).body).toEqual({
      giftMinCoins: 20_000,
      gameMinTickets: 300,
      luckyChatMinMultiplier: 250,
      luckyGlobalMultipliers: [250, 500, 1000],
      luckyGlobalGapSeconds: 10,
      luckyMultipliers: [5, 10, 25, 50, 100, 250, 500, 1000],
    });
  });

  it("the panel's thresholds apply without a restart (after the ≤ 30 s cache): a 20 000 gift is a strip, a 19 999 one is not", async () => {
    // The cache would expire within 30 s; the test forgets it instead of waiting.
    strips.forgetThresholds();
    expect(await strips.thresholds()).toEqual({
      giftMinCoins: 20_000,
      gameMinTickets: 300,
      luckyChatMinMultiplier: 250,
      luckyGlobalMultipliers: [250, 500, 1000],
      luckyGlobalGapSeconds: 10,
    });
    await gapOver();
    const before = giftStrips(roomB).length;
    await send(roomA, viewer, hA, await gift(19_999));
    await new Promise((r) => setTimeout(r, 200));
    await settle(ctx);
    expect(giftStrips(roomB)).toHaveLength(before);
    const sent = await send(roomA, viewer, hA, await gift(20_000));
    await until(() => giftStrips(roomB).length === before + 1);
    expect(giftStrips(roomB).at(-1)).toMatchObject({ gift: { id: sent.gift.id, unitPrice: 20_000 } });
    await ctx.prisma.siteSetting.deleteMany({ where: { key: 'globalStrips' } });
    strips.forgetThresholds();
    await gapOver();
  });

  it('D318: the lucky chat threshold — 250 by default in the catalogue; the OWNER picks one of the multipliers (else 400); the catalogue follows (version changes); a PUT without it keeps it', async () => {
    const gifts = ctx.app.get((await import('../src/modules/gifts/gifts.service.js')).GiftsService);
    gifts.forgetLuckyChat();
    const reader = await signup();
    const catalogue = () => ctx.http.get('/api/v1/gifts/catalogue').set(auth(reader));
    const before = await catalogue();
    expect(before.status).toBe(200);
    expectContract(before, 'getGiftCatalogue');
    expect(before.body.luckyChatMinMultiplier).toBe(250);
    for (const bad of [300, 0, 1.5, '500']) {
      const res = await p.send(owner, 'put', '/admin/global-strips', {
        giftMinCoins: 20_000,
        gameMinTickets: 300,
        luckyChatMinMultiplier: bad,
      });
      expect(res.status, JSON.stringify(bad)).toBe(400);
      expectContract(res, 'updateAdminGlobalStrips');
    }
    const put = await p.send(owner, 'put', '/admin/global-strips', {
      giftMinCoins: 20_000,
      gameMinTickets: 300,
      luckyChatMinMultiplier: 500,
    });
    expect(put.status, JSON.stringify(put.body)).toBe(200);
    expect(put.body.luckyChatMinMultiplier).toBe(500);
    gifts.forgetLuckyChat();
    const after = await catalogue();
    expect(after.body.luckyChatMinMultiplier).toBe(500);
    expect(after.body.version).not.toBe(before.body.version);
    // An older panel (no field) leaves it as it is.
    const older = await p.send(owner, 'put', '/admin/global-strips', {
      giftMinCoins: 20_000,
      gameMinTickets: 300,
    });
    expect(older.status).toBe(200);
    expect(older.body.luckyChatMinMultiplier).toBe(500);
    // A stored value that is no longer a multiplier falls back to the configuration.
    await ctx.prisma.siteSetting.update({
      where: { key: 'globalStrips' },
      data: { value: { giftMinCoins: 20_000, gameMinTickets: 300, luckyChatMinMultiplier: 7 } },
    });
    gifts.forgetLuckyChat();
    expect((await catalogue()).body.luckyChatMinMultiplier).toBe(250);
  });

  it('D347: the global lucky banner — the OWNER sets its multipliers and gap (validated like the env, audited, a PUT without them keeps them); the viewer switch `luckyStrip`', async () => {
    const ticker = ctx.app.get(
      (await import('../src/modules/live/live-lucky-ticker.service.js')).LiveLuckyTickerService,
    );
    await ctx.prisma.siteSetting.deleteMany({ where: { key: 'globalStrips' } });
    ticker.forgetSettings();
    expect(await ticker.settings()).toEqual({ multipliers: [250, 500, 1000], gapMs: 10_000 });
    const base = { giftMinCoins: 20_000, gameMinTickets: 300 };
    for (const bad of [
      { luckyGlobalMultipliers: [] },
      { luckyGlobalMultipliers: [250, 300] },
      { luckyGlobalMultipliers: [500, 500] },
      { luckyGlobalMultipliers: [1.5] },
      { luckyGlobalMultipliers: '250' },
      { luckyGlobalGapSeconds: 0 },
      { luckyGlobalGapSeconds: 601 },
      { luckyGlobalGapSeconds: 2.5 },
    ]) {
      const res = await p.send(owner, 'put', '/admin/global-strips', { ...base, ...bad });
      expect(res.status, JSON.stringify(bad)).toBe(400);
      expectContract(res, 'updateAdminGlobalStrips');
    }
    const denied = await p.send(moderator, 'put', '/admin/global-strips', {
      ...base,
      luckyGlobalMultipliers: [100],
    });
    expect(denied.status).toBe(403);
    const put = await p.send(owner, 'put', '/admin/global-strips', {
      ...base,
      luckyGlobalMultipliers: [1000, 100],
      luckyGlobalGapSeconds: 30,
      reason: 'test week',
    });
    expect(put.status, JSON.stringify(put.body)).toBe(200);
    expectContract(put, 'updateAdminGlobalStrips');
    expect(put.body).toMatchObject({ luckyGlobalMultipliers: [100, 1000], luckyGlobalGapSeconds: 30 });
    const audit = await ctx.prisma.auditLog.findFirst({
      where: { action: 'site.settings.update', actorUserId: owner.id },
      orderBy: { createdAt: 'desc' },
    });
    expect(audit?.metadata).toMatchObject({
      key: 'globalStrips',
      before: { luckyGlobalMultipliers: [250, 500, 1000], luckyGlobalGapSeconds: 10 },
      after: { luckyGlobalMultipliers: [100, 1000], luckyGlobalGapSeconds: 30 },
      reason: 'test week',
    });
    // No restart: the ticker reads it (after its ≤ 30 s cache).
    ticker.forgetSettings();
    expect(await ticker.settings()).toEqual({ multipliers: [100, 1000], gapMs: 30_000 });
    // An older panel (neither field) keeps them.
    const older = await p.send(owner, 'put', '/admin/global-strips', base);
    expect(older.body).toMatchObject({ luckyGlobalMultipliers: [100, 1000], luckyGlobalGapSeconds: 30 });
    const get = await p.send(owner, 'get', '/admin/global-strips');
    expectContract(get, 'getAdminGlobalStrips');
    expect(get.body).toMatchObject({ luckyGlobalMultipliers: [100, 1000], luckyGlobalGapSeconds: 30 });
    await ctx.prisma.siteSetting.deleteMany({ where: { key: 'globalStrips' } });
    ticker.forgetSettings();

    // «إخفاء أشرطة الفوز»: a per-account switch, on (shown) by default, kept.
    const viewerAuth = { Authorization: `Bearer ${user.token}` };
    const off = await ctx.http
      .patch('/api/v1/me/notification-settings')
      .set(viewerAuth)
      .send({ luckyStrip: false });
    expect(off.status).toBe(200);
    expectContract(off, 'updateNotificationSettings');
    expect(off.body).toMatchObject({ luckyStrip: false, giftStrip: true });
    const again = await ctx.http.get('/api/v1/me/notification-settings').set(viewerAuth);
    expect(again.body.luckyStrip).toBe(false);
    const bad = await ctx.http
      .patch('/api/v1/me/notification-settings')
      .set(viewerAuth)
      .send({ luckyStrip: 'no' });
    expect(bad.status).toBe(400);
  });
});
