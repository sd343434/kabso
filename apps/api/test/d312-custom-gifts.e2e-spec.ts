/**
 * D312 (owner 2026-11-08: «هدايا من فئة مُخصَّص تستند الى مستخدم. يأخذ المضيف 60٪ … 100 ألف → 600 ألف كرزة بدل 650 ألف،
 * وصاحب الهدية يأخذ 3٪ لكن كوينزات يعني 3 آلاف كوينزة، ونفس الشيء صانع المحتوى في هذه الفئة فقط»; contract v1.100-social,
 * CONVENTIONS §10.118): the special category CUSTOM «مُخصَّص». Every gift in it names an ACTIVE owner (the panel takes the
 * Kabso ID); anyone sends it with coins; the recipients get 60 % as cherries wherever it is sent (a host's live, a creator's
 * live, a conversation); the owner gets 3 % of the coin value as coins in the same transaction (never for his own send);
 * a reversal takes both back; the founder's «الربح» counts the owner's coins as a cost. Lucky and normal gifts unchanged.
 */
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { reverseGiftCherriesIn } from '../src/modules/economy/cherry-ledger.js';
import { addGiftIn, type GiftFields } from '../src/modules/gifts/gift-catalogue.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { OwnerProfitService } from '../src/modules/owner-profile/owner-profit.service.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Admin } from './helpers/admin-panel.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

class RealClock extends Clock {
  now(): Date {
    return new Date();
  }
}

interface TestUser {
  id: string;
  username: string;
  token: string;
}

const png = (w: number, h: number) =>
  sharp({ create: { width: w, height: h, channels: 4, background: { r: 30, g: 160, b: 120, alpha: 1 } } })
    .png()
    .toBuffer();

describe('D312 custom gifts «مُخصَّص»', { timeout: 600_000 }, () => {
  const media = new MemoryLiveMedia();
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  const p = panel(() => ctx);

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
  const wallet = async (u: TestUser) =>
    Number((await ctx.prisma.wallet.findUnique({ where: { userId: u.id } }))?.coins ?? 0n);
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
  const goLive = async (host: TestUser, source: 'ADMIN' | 'CREATOR' = 'ADMIN') => {
    await ctx.prisma.liveHost.upsert({
      where: { userId: host.id },
      create: { userId: host.id, source },
      update: {},
    });
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(host))
      .send({ title: 'Custom', mode: 'AUDIO', seatCount: 10 });
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
  const sendLive = (roomId: string, from: TestUser, to: TestUser[], giftCode: string, extra: object = {}) => {
    const clientId = randomUUID();
    const req = ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(from))
      .send({
        giftCode,
        quantity: 1,
        recipients: to.map((u) => u.username),
        source: 'COINS',
        clientId,
        ...extra,
      });
    return Object.assign(req, { clientId: (extra as { clientId?: string }).clientId ?? clientId });
  };
  /** The send a request stored (by its clientId: the test's Date is frozen, so times tie). */
  const sendId = async (req: ReturnType<typeof sendLive>, from: TestUser) => {
    const res = await req;
    expect([200, 201], JSON.stringify(res.body)).toContain(res.status);
    return ctx.prisma.liveGift.findFirstOrThrow({
      where: { senderId: from.id, clientId: req.clientId },
      select: { id: true, hostShareBps: true },
    });
  };
  const cherriesOf = async (u: TestUser, giftId: string) =>
    (
      await ctx.prisma.cherryLedgerEntry.findMany({
        where: { userId: u.id, referenceId: giftId, reason: { in: ['GIFT_RECEIVED', 'GIFT_REVERSAL'] } },
      })
    ).reduce((s, r) => s + Number(r.delta), 0);
  const royaltyRows = (giftId: string) =>
    ctx.prisma.walletLedgerEntry.findMany({
      where: { referenceId: giftId, reason: { in: ['GIFT_OWNER_ROYALTY', 'GIFT_OWNER_ROYALTY_REVERSAL'] } },
      orderBy: { createdAt: 'asc' },
    });
  const makeCreator = async (u: TestUser) => {
    const app = await ctx.prisma.creatorApplication.create({
      data: {
        userId: u.id,
        status: 'APPROVED',
        country: 'EG',
        category: 'COMEDY',
        links: ['https://www.tiktok.com/@c'],
        decidedAt: new Date(),
      },
    });
    await ctx.prisma.creatorMember.create({
      data: { userId: u.id, applicationId: app.id, activatedAt: new Date() },
    });
  };

  let admin: Admin;
  let designer: TestUser;
  let sender: TestUser;

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: Date.now() });
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        LIVE_RANKINGS_TIME_ZONE: 'UTC',
        LUCKY_GIFTS_ENABLED: 'true',
        LIVE_GIFT_QUANTITIES: '1,10,100',
        ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
        ADMIN_SESSION_IDLE_SECONDS: '3600',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '100000/900',
        MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
        ADMIN_DASHBOARD_TIME_ZONE: 'UTC',
      },
      [
        { token: LIVE_MEDIA_PROVIDER, value: media },
        { token: Clock, value: new RealClock() },
        { token: OBJECT_STORAGE, value: storage },
      ],
    );
    admin = await p.makeAdmin(['OWNER']);
    designer = await signup();
    sender = await signup();
    await coins(sender, 10_000_000);
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  describe('the panel: «مُخصَّص» and the gift owner', () => {
    it('seeds CUSTOM as a special category (renamed / reordered only, never off or deleted)', async () => {
      const list = await p.send(admin, 'get', '/admin/gift-categories');
      expect(list.status, JSON.stringify(list.body)).toBe(200);
      expectContract(list, 'listAdminGiftCategories');
      const custom = (
        list.body.data as { code: string; kind: string; nameAr: string; special: boolean }[]
      ).find((c) => c.code === 'CUSTOM');
      expect(custom).toMatchObject({ kind: 'CUSTOM', nameAr: 'مُخصَّص', special: true });
      const off = await p.send(admin, 'post', '/admin/gift-categories/CUSTOM/disable', { reason: 'x' });
      expect(off.status).toBe(409);
      const renamed = await p.send(admin, 'patch', '/admin/gift-categories/CUSTOM', {
        nameEn: 'Custom gifts',
        reason: 'rename',
      });
      expect(renamed.status, JSON.stringify(renamed.body)).toBe(200);
    });

    it('a custom gift needs an existing ACTIVE owner by Kabso ID; other gifts have none; listed with the owner', async () => {
      const up = await p.send(admin, 'get', '/admin/gifts');
      expect(up.status).toBe(200);
      const image = await ctx.http
        .post('/api/v1/admin/gift-uploads?kind=image&code=d312_star')
        .set('Cookie', admin.cookie)
        .set('X-CSRF-Token', admin.csrf)
        .set('Content-Type', 'application/octet-stream')
        .send(await png(256, 256));
      expect(image.status, JSON.stringify(image.body)).toBe(201);
      const base = {
        code: 'd312_star',
        category: 'CUSTOM',
        nameAr: 'نجمة',
        nameEn: 'Star',
        priceCoins: 1000,
        imageObjectKey: image.body.key as string,
        reason: 'new custom gift',
      };
      const noOwner = await p.send(admin, 'post', '/admin/gifts', base);
      expect(noOwner.status).toBe(409);
      expectContract(noOwner, 'createAdminGift');
      const unknown = await p.send(admin, 'post', '/admin/gifts', { ...base, owner: 'nobody_d312' });
      expect(unknown.status).toBe(409);
      expect(unknown.body.error.details).toEqual([{ field: 'owner', issue: 'owner_not_found' }]);
      const banned = await signup();
      await ctx.prisma.user.update({ where: { id: banned.id }, data: { status: 'SUSPENDED' } });
      const inactive = await p.send(admin, 'post', '/admin/gifts', { ...base, owner: banned.username });
      expect(inactive.body.error.details).toEqual([{ field: 'owner', issue: 'owner_not_active' }]);
      const normal = await p.send(admin, 'post', '/admin/gifts', {
        ...base,
        category: 'POPULAR',
        owner: designer.username,
      });
      expect(normal.status).toBe(409);

      const created = await p.send(admin, 'post', '/admin/gifts', {
        ...base,
        owner: `@${designer.username.toUpperCase()}`,
      });
      expect(created.status, JSON.stringify(created.body)).toBe(201);
      expectContract(created, 'createAdminGift');
      const audit = await ctx.prisma.auditLog.findFirstOrThrow({
        where: { action: 'gift.add', targetId: 'd312_star' },
      });
      expect(audit.metadata).toMatchObject({ category: 'CUSTOM', ownerUserId: designer.id, via: 'panel' });
      const listed = await p.send(admin, 'get', '/admin/gifts');
      expectContract(listed, 'listAdminGifts');
      const row = (listed.body.data as { code: string; owner: unknown }[]).find(
        (g) => g.code === 'd312_star',
      )!;
      expect(row.owner).toMatchObject({ id: designer.id, username: designer.username, status: 'ACTIVE' });

      // The app's catalogue: the CUSTOM tab and the owner on the gift.
      const cat = await ctx.http.get('/api/v1/gifts/catalogue').set(auth(sender));
      expect(cat.status).toBe(200);
      expectContract(cat, 'getGiftCatalogue');
      expect(
        (cat.body.tabs as { code: string; kind: string }[]).find((t) => t.code === 'CUSTOM'),
      ).toMatchObject({
        kind: 'CUSTOM',
      });
      const star = (cat.body.data as { code: string; owner?: unknown }[]).find(
        (g) => g.code === 'd312_star',
      )!;
      expect(star.owner).toEqual({
        id: designer.id,
        username: designer.username,
        displayName: expect.any(String),
        avatarUrl: null,
      });
      expect((cat.body.data as { code: string; owner?: unknown }[]).filter((g) => g.owner).length).toBe(1);

      // Moving it out of «مُخصَّص» drops the owner; giving a normal gift an owner is refused.
      const moved = await p.send(admin, 'patch', '/admin/gifts/d312_star', {
        category: 'POPULAR',
        reason: 'move',
      });
      expect(moved.status, JSON.stringify(moved.body)).toBe(200);
      expect(
        (await ctx.prisma.gift.findUniqueOrThrow({ where: { code: 'd312_star' } })).ownerUserId,
      ).toBeNull();
      const back = await p.send(admin, 'patch', '/admin/gifts/d312_star', {
        category: 'CUSTOM',
        reason: 'back',
      });
      expect(back.status).toBe(409);
      const backWithOwner = await p.send(admin, 'patch', '/admin/gifts/d312_star', {
        category: 'CUSTOM',
        owner: designer.username,
        reason: 'back',
      });
      expect(backWithOwner.status, JSON.stringify(backWithOwner.body)).toBe(200);
    });
  });

  describe('sends', () => {
    let host: TestUser;
    let roomId: string;

    beforeAll(async () => {
      await gift('d312_crown', { category: 'CUSTOM', priceCoins: 100_000, ownerUserId: designer.id });
      await gift('d312_rose', { priceCoins: 100_000 });
      await gift('d312_lucky', { category: 'LUCKY', priceCoins: 100_000 });
      host = await signup();
      roomId = await goLive(host);
      await enter(roomId, sender);
      const adult = await ctx.http
        .put('/api/v1/me/lucky-gifts/age-confirmation')
        .set(auth(sender))
        .send({ adult: true });
      expect(adult.status).toBe(200);
    });

    it("100 000 coins to a host: 600 000 cherries (60 %), the owner 3 000 coins (3 %) in the send's transaction", async () => {
      const ownerBefore = await wallet(designer);
      const senderBefore = await wallet(sender);
      const req = sendLive(roomId, sender, [host], 'd312_crown');
      const res = await req;
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      expectContract(res, 'sendLiveGift');
      const send = await sendId(req, sender);
      expect(send.hostShareBps).toBe(6000);
      expect(await cherriesOf(host, send.id)).toBe(600_000);
      expect(await wallet(designer)).toBe(ownerBefore + 3000);
      expect(await wallet(sender)).toBe(senderBefore - 100_000);
      const rows = await royaltyRows(send.id);
      expect(rows.map((r) => [r.userId, r.reason, Number(r.delta)])).toEqual([
        [designer.id, 'GIFT_OWNER_ROYALTY', 3000],
      ]);
      // A retry with the same clientId credits nothing again.
      const clientId = randomUUID();
      const once = await sendLive(roomId, sender, [host], 'd312_crown', { clientId });
      const twice = await sendLive(roomId, sender, [host], 'd312_crown', { clientId });
      expect([once.status, twice.status]).toEqual([201, 200]);
      expect(await wallet(designer)).toBe(ownerBefore + 6000);
      // The room ranks by the real cherries of the send (D310).
      const room = await ctx.http.get(`/api/v1/live/rooms/${roomId}`).set(auth(sender));
      expect(room.body.scoreParts.roomCherries).toBe(1_200_000);
    });

    it('a normal and a lucky gift are unchanged (the host share / the lucky share; no owner coins)', async () => {
      const ownerBefore = await wallet(designer);
      // v1.106-social (D341, §10.140): the host is in no agency — a direct host, 70 % (custom gifts keep 60 %).
      const rose = await sendId(sendLive(roomId, sender, [host], 'd312_rose'), sender);
      expect(rose.hostShareBps).toBe(7000);
      expect(await cherriesOf(host, rose.id)).toBe(700_000);
      expect(await royaltyRows(rose.id)).toEqual([]);
      const lucky = await sendId(sendLive(roomId, sender, [host], 'd312_lucky'), sender);
      expect(lucky.hostShareBps).toBe(1000);
      expect(await cherriesOf(host, lucky.id)).toBe(100_000);
      expect(await royaltyRows(lucky.id)).toEqual([]);
      expect(await wallet(designer)).toBe(ownerBefore);
    });

    it('the owner sending his own gift gets no 3 %; it may go to a seated guest too', async () => {
      await coins(designer, 1_000_000);
      await enter(roomId, designer);
      const guest = await signup();
      await enter(roomId, guest);
      await ctx.prisma.liveRoomSeat.create({ data: { roomId, seatIndex: 2, userId: guest.id } });
      const before = await wallet(designer);
      const own = await sendId(sendLive(roomId, designer, [host, guest], 'd312_crown'), designer);
      expect(await cherriesOf(host, own.id)).toBe(600_000);
      expect(await cherriesOf(guest, own.id)).toBe(600_000);
      expect(await royaltyRows(own.id)).toEqual([]);
      expect(await wallet(designer)).toBe(before - 200_000);
    });

    it("a content creator's live: 60 % too (the creator's 70 % does not apply to this category)", async () => {
      const creator = await signup();
      await makeCreator(creator);
      const live = await goLive(creator, 'CREATOR');
      await enter(live, sender);
      const ownerBefore = await wallet(designer);
      const crown = await sendId(sendLive(live, sender, [creator], 'd312_crown'), sender);
      expect(crown.hostShareBps).toBe(6000);
      expect(await cherriesOf(creator, crown.id)).toBe(600_000);
      expect(await wallet(designer)).toBe(ownerBefore + 3000);
      // A normal gift there keeps the creator share — v1.106-social (D341): a creator in no agency, the direct 75 %.
      const rose = await sendId(sendLive(live, sender, [creator], 'd312_rose'), sender);
      expect(rose.hostShareBps).toBe(7500);
    });

    it('a direct conversation: 60 % and the owner 3 %', async () => {
      const friend = await signup();
      await ctx.http.put(`/api/v1/users/${friend.username}/follow`).set(auth(sender)).expect(200);
      await ctx.http.put(`/api/v1/users/${sender.username}/follow`).set(auth(friend)).expect(200);
      const ownerBefore = await wallet(designer);
      const res = await ctx.http.post('/api/v1/dm/gifts').set(auth(sender)).send({
        to: friend.username,
        giftCode: 'd312_crown',
        quantity: 1,
        source: 'COINS',
        clientId: randomUUID(),
      });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      expectContract(res, 'sendDmGift');
      const send = await ctx.prisma.liveGift.findFirstOrThrow({
        where: { senderId: sender.id, roomId: null },
        orderBy: { createdAt: 'desc' },
      });
      expect(send.hostShareBps).toBe(6000);
      expect(await cherriesOf(friend, send.id)).toBe(600_000);
      expect(await wallet(designer)).toBe(ownerBefore + 3000);
    });

    it('coins only (a bag send → 400); unsendable while the owner is not ACTIVE (and not listed)', async () => {
      const bag = await sendLive(roomId, sender, [host], 'd312_crown', { source: 'BAG' });
      expect(bag.status).toBe(400);
      expect(bag.body.error.details).toEqual([{ field: 'source', issue: 'invalid_value' }]);
      await ctx.prisma.user.update({ where: { id: designer.id }, data: { status: 'SUSPENDED' } });
      try {
        const off = await sendLive(roomId, sender, [host], 'd312_crown');
        expect(off.status).toBe(409);
        expect(off.body.error.code).toBe('GIFT_UNAVAILABLE');
        const cat = await ctx.http.get('/api/v1/gifts/catalogue').set(auth(sender));
        expect((cat.body.data as { code: string }[]).some((g) => g.code === 'd312_crown')).toBe(false);
      } finally {
        await ctx.prisma.user.update({ where: { id: designer.id }, data: { status: 'ACTIVE' } });
      }
    });

    it("a reversal takes the cherries and the owner's coins back (once; the balance may go below 0)", async () => {
      const send = await sendId(sendLive(roomId, sender, [host], 'd312_crown'), sender);
      expect((await royaltyRows(send.id)).length).toBe(1);
      // The owner already spent everything.
      const spent = await wallet(designer);
      await ctx.prisma.$executeRaw`UPDATE wallets SET coins = 1000 WHERE user_id = ${designer.id}::uuid`;
      const r = await ctx.prisma.$transaction((tx) => reverseGiftCherriesIn(tx, send.id, new Date()));
      expect(r).toMatchObject({ reversed: true, royaltyCoins: 3000n });
      expect(await cherriesOf(host, send.id)).toBe(0);
      expect(await wallet(designer)).toBe(1000 - 3000);
      const rows = await royaltyRows(send.id);
      expect(rows.map((x) => [x.reason, Number(x.delta)])).toEqual([
        ['GIFT_OWNER_ROYALTY', 3000],
        ['GIFT_OWNER_ROYALTY_REVERSAL', -3000],
      ]);
      const again = await ctx.prisma.$transaction((tx) => reverseGiftCherriesIn(tx, send.id, new Date()));
      expect(again).toMatchObject({ reversed: false, royaltyCoins: 0n });
      expect(await wallet(designer)).toBe(-2000);
      // In debt, the owner sends no gift (D190's rule).
      const frozen = await sendLive(roomId, designer, [host], 'd312_rose');
      expect(frozen.status).toBe(403);
      await ctx.prisma
        .$executeRaw`UPDATE wallets SET coins = ${BigInt(spent)} WHERE user_id = ${designer.id}::uuid`;
    });

    it("«الربح» counts the owners' coins as a cost (COIN_REWARDS), net of claw-backs", async () => {
      const profit = ctx.app.get(OwnerProfitService);
      const today = new Date().toISOString().slice(0, 10);
      const coinsLine = async () =>
        (await profit.compute(today, today, new Date())).day.deductions.find(
          (d) => d.key === 'COIN_REWARDS',
        )!;
      const before = await coinsLine();
      const send = await sendId(sendLive(roomId, sender, [host], 'd312_crown'), sender);
      const after = await coinsLine();
      expect(after.coins! - before.coins!).toBe(3000);
      expect(after.amountMinor).toBeGreaterThanOrEqual(before.amountMinor);
      await ctx.prisma.$transaction((tx) => reverseGiftCherriesIn(tx, send.id, new Date()));
      expect((await coinsLine()).coins).toBe(before.coins);
    });
  });
});
