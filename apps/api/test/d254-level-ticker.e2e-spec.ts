/**
 * D254 (owner 2026-11-03: «شريط متحرك لاعلان عن ترقية الحسابات وصعود ليفيلات لليفيلات المرتفعة»; contract v1.62-live,
 * CONVENTIONS §10.92): the level-up banner. A support (`SUPPORT`) or charm (`ATTRACTIVENESS`) level that rises in a
 * live to the OWNER's threshold (`levelTickerMinLevel`, default 30) or above is a `level-ticker` data message (topic
 * `level`) in every LIVE room, its own included — one every 8 s for the whole service, the others waiting in line.
 * `GET|PUT /admin/level-ticker` (panel session, `site.settings`: OWNER only), audited. End to end against PostgreSQL +
 * Redis with the in-memory media server.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, settle, type TestContext } from './helpers/test-app.js';

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';
/** The ladder of both level systems here: level n needs (n − 1) × 100 points (1 coin = 1 point). */
const LEVELS = 40;
const pointsFor = (level: number) => (level - 1) * 100;

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

interface LevelTicker {
  type: 'level-ticker';
  levelUp: {
    id: string;
    user: { id: string };
    category: string;
    level: number;
    previousLevel: number | null;
    roomId: string;
  };
  room: { id: string; title: string; host: { id: string } };
}

describe('D254 level-up banner', { timeout: 180_000 }, () => {
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let moderator: Admin;
  let user: Person;
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
  /** A catalogue gift worth `price` coins. */
  const gift = async (price: number): Promise<string> => {
    seq += 1;
    const code = `lv${String(seq)}_${randomUUID().slice(0, 6)}`;
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
  const send = async (roomId: string, from: TestUser, to: TestUser, price: number) => {
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(from))
      .send({
        giftCode: await gift(price),
        quantity: 1,
        recipients: [to.username],
        source: 'COINS',
        clientId: randomUUID(),
      });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    await settle(ctx);
  };
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
        publishedAt: new Date(),
        levels: {
          create: Array.from({ length: LEVELS }, (_, i) => ({
            levelNumber: i + 1,
            nameAr: `م${String(i + 1)}`,
            nameEn: `L${String(i + 1)}`,
            requiredPoints: BigInt(pointsFor(i + 1)),
          })),
        },
      },
    });
    await ctx.prisma.levelCategory.update({
      where: { id: category.id },
      data: { isEnabled: true, publishedVersionId: version.id },
    });
  };
  const tickers = (room: string) => media.broadcastsOf(room, 'level-ticker') as unknown as LevelTicker[];
  const topics = (room: string) =>
    media.broadcasts
      .filter((b) => b.room === room && b.payload.includes('"level-ticker"'))
      .map((b) => b.topic);
  /** Waits (real time) until `check` holds — the banner's gate is 8 s. */
  const until = async (check: () => boolean, ms = 12_000) => {
    const end = Date.now() + ms;
    while (!check()) {
      if (Date.now() > end) throw new Error('timed out');
      await new Promise((r) => setTimeout(r, 100));
      await settle(ctx);
    }
  };

  // Rooms A (where the gifts are sent), B and C; people: A's host, a viewer who sends, a seated guest.
  let hA: TestUser;
  let hC: TestUser;
  let viewer: TestUser;
  let guest: TestUser;
  let roomA: string;
  let roomB: string;
  let roomC: string;

  beforeAll(async () => {
    // Only `Date` is faked (the panel's authenticator codes); the banner's gate runs on real timers.
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
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
    await publish('SUPPORT');
    await publish('ATTRACTIVENESS');
    hA = await host();
    hC = await host();
    viewer = await signup();
    guest = await signup();
    roomA = await goLive(hA);
    roomB = await goLive(await host());
    roomC = await goLive(hC);
    await join(roomA, viewer);
    await join(roomA, guest);
    await ctx.prisma.liveRoomSeat.create({ data: { roomId: roomA, seatIndex: 1, userId: guest.id } });
    await coins(viewer, 100_000);
  });
  afterAll(async () => {
    await ctx?.prisma.siteSetting.deleteMany({ where: { key: 'levelTickerMinLevel' } });
    await ctx?.close();
    vi.useRealTimers();
  });

  it('the threshold is 30 by default', async () => {
    const res = await p.send(owner, 'get', '/admin/level-ticker');
    expect(res.status).toBe(200);
    expectContract(res, 'getAdminLevelTicker');
    expect(res.body).toEqual({ minLevel: 30 });
  });

  it('OWNER only: other panel roles 403, a bearer token 401, no CSRF 403; bounds 1–100', async () => {
    expect((await p.send(moderator, 'get', '/admin/level-ticker')).status).toBe(403);
    const put = await p.send(moderator, 'put', '/admin/level-ticker', { minLevel: 10 });
    expect(put.status).toBe(403);
    expectContract(put, 'updateAdminLevelTicker');
    const bearer = await ctx.http
      .put('/api/v1/admin/level-ticker')
      .set('Authorization', `Bearer ${user.token}`)
      .send({ minLevel: 10 });
    expect(bearer.status).toBe(401);
    const noCsrf = await ctx.http
      .put('/api/v1/admin/level-ticker')
      .set('Cookie', owner.cookie)
      .send({ minLevel: 10 });
    expect(noCsrf.status).toBe(403);
    for (const bad of [
      { minLevel: 0 },
      { minLevel: 101 },
      { minLevel: 30.5 },
      { minLevel: '40' },
      {},
      { minLevel: 40, x: 1 },
    ]) {
      const res = await p.send(owner, 'put', '/admin/level-ticker', bad);
      expect(res.status, JSON.stringify(bad)).toBe(400);
      expectContract(res, 'updateAdminLevelTicker');
      expect(res.body.error.code).toBe('VALIDATION_FAILED');
    }
    expect((await p.send(owner, 'get', '/admin/level-ticker')).body).toEqual({ minLevel: 30 });
    expect(await ctx.prisma.auditLog.count({ where: { action: 'site.settings.update' } })).toBe(0);
  });

  it('a gift that takes the levels to 29 (under 30) announces nothing', async () => {
    await send(roomA, viewer, hA, pointsFor(29));
    await new Promise((r) => setTimeout(r, 300));
    await settle(ctx);
    for (const room of [roomA, roomB, roomC]) expect(tickers(room)).toEqual([]);
  });

  it("reaching 30: the sender's support and the host's charm, in every live (its own too), one at a time", async () => {
    await send(roomA, viewer, hA, 100); // 2 900 points: level 30 for both
    for (const room of [roomA, roomB, roomC]) expect(tickers(room)).toHaveLength(1);
    expect(topics(roomB)).toEqual(['level']);
    const first = tickers(roomB)[0]!;
    expect(first.room).toMatchObject({ id: roomA, title: `Live of ${hA.username}`, host: { id: hA.id } });
    // The second waits for the 8 s gap (the gate is shared by every API instance).
    await new Promise((r) => setTimeout(r, 2_000));
    await settle(ctx);
    expect(tickers(roomC)).toHaveLength(1);
    await until(() => [roomA, roomB, roomC].every((room) => tickers(room).length === 2));
    const both = tickers(roomC).map((t) => t.levelUp);
    expect(both.map((u) => [u.category, u.user.id, u.previousLevel, u.level, u.roomId]).sort()).toEqual(
      [
        ['ATTRACTIVENESS', hA.id, 29, 30, roomA],
        ['SUPPORT', viewer.id, 29, 30, roomA],
      ].sort(),
    );
    expect(both.map((u) => u.id).sort()).toEqual(
      [`${hA.id}:ATTRACTIVENESS:30`, `${viewer.id}:SUPPORT:30`].sort(),
    );
  });

  it('the OWNER raises the threshold to 33 (audited): 32 is not announced, 33 is', async () => {
    const res = await p.send(owner, 'put', '/admin/level-ticker', { minLevel: 33, reason: 'less noise' });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'updateAdminLevelTicker');
    expect(res.body).toEqual({ minLevel: 33 });
    const audit = await ctx.prisma.auditLog.findMany({
      where: { action: 'site.settings.update', actorUserId: owner.id },
    });
    expect(audit).toHaveLength(1);
    expect(audit[0]!.metadata).toMatchObject({
      key: 'levelTickerMinLevel',
      before: 30,
      after: 33,
      reason: 'less noise',
      via: 'panel',
    });
    const before = tickers(roomB).length;
    // To the seated guest: the guest's charm stays low (level 3, 4); the sender's support goes to 32, then 33.
    await send(roomA, viewer, guest, 200);
    await send(roomA, viewer, guest, 100);
    await until(() => tickers(roomB).length === before + 1);
    await new Promise((r) => setTimeout(r, 1_000));
    await settle(ctx);
    expect(
      tickers(roomB)
        .slice(before)
        .map((t) => [t.levelUp.category, t.levelUp.user.id, t.levelUp.level]),
    ).toEqual([['SUPPORT', viewer.id, 33]]);
  });

  it("the host's charm from taps is announced too (threshold 2 here)", async () => {
    expect((await p.send(owner, 'put', '/admin/level-ticker', { minLevel: 2 })).status).toBe(200);
    // Room C's host at 99 charm points (level 1) from a gift; the sender stays at level 1 too.
    const fan = await signup();
    await coins(fan, 1_000);
    await join(roomC, fan);
    await send(roomC, fan, hC, 99);
    const before = tickers(roomB).length;
    // 10 counted taps = 1 charm point → 100 points: level 2.
    const tapped = await ctx.http.post(`/api/v1/live/rooms/${roomC}/taps`).set(auth(fan)).send({ count: 10 });
    expect(tapped.status, JSON.stringify(tapped.body)).toBe(200);
    await until(() => tickers(roomB).length === before + 1);
    expect(tickers(roomB).at(-1)).toMatchObject({
      type: 'level-ticker',
      levelUp: { category: 'ATTRACTIVENESS', user: { id: hC.id }, previousLevel: 1, level: 2, roomId: roomC },
      room: { id: roomC, host: { id: hC.id } },
    });
    expect(tickers(roomC).at(-1)).toMatchObject({ levelUp: { user: { id: hC.id }, level: 2 } });
  });

  it('a level already announced is not announced again; the table refuses unknown keys', async () => {
    // The viewer's support level 33 was announced; nothing new reaches the rooms without a new level.
    const before = tickers(roomB).length;
    await send(roomA, viewer, guest, 1);
    await new Promise((r) => setTimeout(r, 500));
    await settle(ctx);
    expect(tickers(roomB)).toHaveLength(before);
    await expect(
      ctx.prisma.siteSetting.create({ data: { key: 'somethingElse', value: 1 } }),
    ).rejects.toThrow();
  });
});
