/**
 * D270 (owner: «المتجر»; contract v1.84-social, CONVENTIONS §10.98): the store — items the OWNER manages in the admin
 * panel (art uploads SVGA / MP4 / still, prices per duration per currency, «جديد», on / off, sales; audited), bought in
 * the app with coins or cherries for oneself or as a gift: the bag item lands (STORE / GIFT), a held one is extended,
 * insufficient balance, the Idempotency-Key replay, a disabled item, a blocked or inactive recipient, a frozen account;
 * worn store items in `UserSummary.wear` with one worn item per kind against the VIP items. End to end against
 * PostgreSQL + Redis with the API as the DML-only runtime role.
 */
import { randomUUID } from 'node:crypto';
import { deflateSync } from 'node:zlib';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { creditReferralCherriesIn, creditTaskCherriesIn } from '../src/modules/economy/cherry-ledger.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { creditIn, reverseTopupIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { mp4 } from './helpers/mp4.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, withMigrationClient, type TestContext } from './helpers/test-app.js';

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';
const BASE = 'https://media.example.test';
const DAY = 86_400_000;
const svga = () => deflateSync(Buffer.concat([Buffer.from([0x0a, 0x05]), Buffer.from('2.0.0')]));

interface StoreItem {
  id: string;
  code: string;
  kind: string;
  name: string;
  isNew: boolean;
  prices: { currency: string; days: number; amount: number }[];
  fromCoins: number | null;
  fromCherries: number | null;
  ownedUntil: string | null;
  art: { still: string | null; animation: string | null; format: string | null; alpha: string | null };
}

describe('D270 contract coverage', () => {
  it('openapi v1.84-social declares the store operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'listStoreItems GET /api/v1/store/items',
      'buyStoreItem POST /api/v1/me/store/purchases',
      'uploadAdminStoreArt POST /api/v1/admin/store/uploads',
      'listAdminStoreItems GET /api/v1/admin/store/items',
      'createAdminStoreItem POST /api/v1/admin/store/items',
      'updateAdminStoreItem PATCH /api/v1/admin/store/items/{itemId}',
      'enableAdminStoreItem POST /api/v1/admin/store/items/{itemId}/enable',
      'disableAdminStoreItem POST /api/v1/admin/store/items/{itemId}/disable',
      'listAdminStoreSales GET /api/v1/admin/store/sales',
    ]) {
      expect(ids).toContain(op);
    }
  });
});

describe('D270 the store', { timeout: 180_000 }, () => {
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let support: Admin;
  let frame: { id: string; code: string };
  let bubble: { id: string; code: string };

  const auth = (u: Person) => ({ Authorization: `Bearer ${u.token}` });
  const usernameOf = async (u: Person) =>
    (await ctx.http.get('/api/v1/me').set(auth(u))).body.username as string;
  const coins = (u: Person, amount: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  /** Unlocked cherries (a referral reward: spendable). */
  const cherries = (u: Person, amount: number) =>
    ctx.prisma.$transaction((tx) =>
      creditReferralCherriesIn(tx, u.id, BigInt(amount), randomUUID(), new Date()),
    );
  /** Task cherries: locked (no gifts received) — never spent in the store (owner, D270). */
  const taskCherries = (u: Person, amount: number) =>
    ctx.prisma.$transaction((tx) =>
      creditTaskCherriesIn(tx, u.id, BigInt(amount), `TEST@${randomUUID()}`, new Date()),
    );
  const balances = async (u: Person) => {
    const [w, c] = await Promise.all([
      ctx.prisma.wallet.findUnique({ where: { userId: u.id } }),
      ctx.prisma.cherryWallet.findUnique({ where: { userId: u.id } }),
    ]);
    return { coins: Number(w?.coins ?? 0n), cherries: Number(c?.cherries ?? 0n) };
  };
  const items = async (u: Person, query = '', lang = 'ar') => {
    const res = await ctx.http.get(`/api/v1/store/items${query}`).set(auth(u)).set('Accept-Language', lang);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listStoreItems');
    return res.body as { data: StoreItem[]; kinds: string[]; balances: { coins: number; cherries: number } };
  };
  const buy = (
    u: Person,
    body: { itemId: string; currency: string; days: number; price: number; recipient?: string | null },
    key: string = randomUUID(),
  ) => ctx.http.post('/api/v1/me/store/purchases').set(auth(u)).set('Idempotency-Key', key).send(body);
  const bag = async (u: Person) => {
    const res = await ctx.http.get('/api/v1/me/bag').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getMyBag');
    return res.body.data as {
      code: string;
      category: string;
      source: string;
      equipped: boolean;
      expiresAt: string | null;
      transferable: boolean;
      giftedBy: { id: string } | null;
      art?: { still: string | null };
    }[];
  };
  const upload = (kind: 'animation' | 'still', body: Buffer) =>
    ctx.http
      .post(`/api/v1/admin/store/uploads?kind=${kind}`)
      .set('Cookie', owner.cookie)
      .set('X-CSRF-Token', owner.csrf)
      .set('Content-Type', 'application/octet-stream')
      .send(body);

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp(
      {
        ADMIN_TOTP_KEY: ADMIN_KEY,
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        ADMIN_SESSION_MAX_SECONDS: '604800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '10000/900',
        MEDIA_PUBLIC_BASE_URL: BASE,
      },
      [{ token: OBJECT_STORAGE, value: new MemoryObjectStorage() }],
    );
    owner = await p.makeAdmin(['OWNER']);
    support = await p.makeAdmin(['SUPPORT']);
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('the panel: art uploads (SVGA, MP4 side by side, still), items added / changed / switched, audited; SUPPORT reads', async () => {
    const anim = await upload('animation', svga());
    expect(anim.status, JSON.stringify(anim.body)).toBe(201);
    expectContract(anim, 'uploadAdminStoreArt');
    expect(anim.body).toMatchObject({ format: 'SVGA', detectedAlpha: null });
    expect(anim.body.url).toMatch(new RegExp(`^${BASE}/media/store/[0-9a-f]{32}\\.svga$`));
    const video = await upload('animation', mp4({ durationMs: 3000, width: 1440, height: 720 }));
    expect(video.status, JSON.stringify(video.body)).toBe(201);
    expect(video.body).toMatchObject({
      format: 'MP4',
      detectedAlpha: 'SIDE_BY_SIDE',
      width: 720,
      height: 720,
    });
    expect(video.body.url).toMatch(/\.mp4$/);
    const still = await upload(
      'still',
      await sharp({ create: { width: 300, height: 300, channels: 4, background: '#e1122d' } })
        .png()
        .toBuffer(),
    );
    expect(still.status).toBe(201);
    expect([still.body.width, still.body.height]).toEqual([300, 300]);
    expect((await upload('animation', Buffer.from([0x50, 0x4b, 0x03, 0x04, 1, 2]))).status).toBe(409);

    const created = await p.send(owner, 'post', '/admin/store/items', {
      kind: 'AVATAR_FRAME',
      nameAr: 'إطار الوردة',
      nameEn: 'Rose frame',
      still: still.body.url,
      animation: anim.body.url,
      prices: [
        { currency: 'COINS', days: 7, amount: 50_000 },
        { currency: 'COINS', days: 30, amount: 150_000 },
        { currency: 'CHERRIES', days: 7, amount: 400_000 },
      ],
      isNew: true,
      enabled: true,
      reason: 'owner D270',
    });
    expect(created.status, JSON.stringify(created.body)).toBe(201);
    expectContract(created, 'createAdminStoreItem');
    expect(created.body).toMatchObject({
      kind: 'AVATAR_FRAME',
      animationFormat: 'SVGA',
      animationAlpha: null,
    });
    expect(created.body.code).toMatch(/^store_[0-9a-f]{12}$/);
    frame = { id: created.body.id as string, code: created.body.code as string };

    const car = await p.send(owner, 'post', '/admin/store/items', {
      kind: 'CHAT_BUBBLE',
      nameAr: 'فقاعة النجوم',
      nameEn: 'Star bubble',
      still: still.body.url,
      animation: video.body.url,
      animationAlpha: 'SIDE_BY_SIDE',
      prices: [{ currency: 'COINS', days: 14, amount: 20_000 }],
      reason: 'owner D270',
    });
    expect(car.status, JSON.stringify(car.body)).toBe(201);
    expect(car.body).toMatchObject({
      animationFormat: 'MP4',
      animationAlpha: 'SIDE_BY_SIDE',
      enabled: false,
    });
    bubble = { id: car.body.id as string, code: car.body.code as string };

    // A duplicate currency / duration → 400; SUPPORT cannot add.
    const dup = await p.send(owner, 'post', '/admin/store/items', {
      kind: 'PROFILE_CARD',
      nameAr: 'س',
      nameEn: 'x',
      prices: [
        { currency: 'COINS', days: 7, amount: 1 },
        { currency: 'COINS', days: 7, amount: 2 },
      ],
      reason: 'x',
    });
    expect(dup.status).toBe(400);
    expect((await p.send(support, 'post', '/admin/store/items', { kind: 'PROFILE_CARD' })).status).toBe(403);
    const read = await p.send(support, 'get', '/admin/store/items');
    expect(read.status).toBe(200);
    expectContract(read, 'listAdminStoreItems');
    expect((read.body.data as { id: string }[]).map((i) => i.id)).toEqual([frame.id, bubble.id]);

    const on = await p.send(owner, 'post', `/admin/store/items/${bubble.id}/enable`, { reason: 'launch' });
    expect(on.status).toBe(200);
    expectContract(on, 'enableAdminStoreItem');
    const edit = await p.send(owner, 'patch', `/admin/store/items/${frame.id}`, {
      nameEn: 'Rose frame II',
      reason: 'rename',
    });
    expect(edit.status).toBe(200);
    expectContract(edit, 'updateAdminStoreItem');
    expect((await ctx.prisma.bagItem.findUnique({ where: { code: frame.code } }))!.nameEn).toBe(
      'Rose frame II',
    );
    const audit = await ctx.prisma.auditLog.findMany({
      where: { action: { startsWith: 'store.item.' } },
      orderBy: { createdAt: 'asc' },
    });
    expect(audit.map((a) => a.action)).toEqual([
      'store.item.add',
      'store.item.add',
      'store.item.enable',
      'store.item.update',
    ]);
    expect(audit.every((a) => (a.metadata as { reason?: string }).reason)).toBe(true);
  });

  it('the app lists the items on sale with the lowest prices, the kinds and the balances', async () => {
    const u = await p.signup();
    await coins(u, 1_000);
    const list = await items(u, '', 'en');
    expect(list.kinds).toEqual(['AVATAR_FRAME', 'CHAT_BUBBLE']);
    expect(list.balances).toEqual({ coins: 1_000, cherries: 0, lockedCherries: 0 });
    const f = list.data.find((i) => i.id === frame.id)!;
    expect(f).toMatchObject({ name: 'Rose frame II', isNew: true, fromCoins: 50_000, fromCherries: 400_000 });
    expect(f.prices.map((pr) => `${pr.currency}:${pr.days}`)).toEqual(['COINS:7', 'COINS:30', 'CHERRIES:7']);
    expect(f.art.format).toBe('SVGA');
    const b = list.data.find((i) => i.id === bubble.id)!;
    expect(b.art).toMatchObject({ format: 'MP4', alpha: 'SIDE_BY_SIDE' });
    expect((await items(u, '?kind=CHAT_BUBBLE')).data.map((i) => i.id)).toEqual([bubble.id]);
  });

  it('buys with coins: debited, in the bag (STORE, timed, transferable), audited; extends a held item', async () => {
    const u = await p.signup();
    await coins(u, 300_000);
    const res = await buy(u, { itemId: frame.id, currency: 'COINS', days: 7, price: 50_000 });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'buyStoreItem');
    expect(res.body).toMatchObject({ recipient: null, extended: false, balances: { coins: 250_000 } });
    const end1 = new Date(res.body.expiresAt as string).getTime();
    expect(end1).toBe(Date.now() + 7 * DAY);
    const own = (await bag(u)).find((i) => i.code === frame.code)!;
    expect(own).toMatchObject({
      source: 'STORE',
      equipped: false,
      transferable: true,
      category: 'AVATAR_FRAME',
    });
    expect(own.art?.still).toMatch(/^https:/);
    const ledger = await ctx.prisma.walletLedgerEntry.findFirst({
      where: { userId: u.id, reason: 'STORE_PURCHASE' },
    });
    expect(ledger).toMatchObject({ delta: -50_000n, referenceId: res.body.id });
    expect(await ctx.prisma.auditLog.count({ where: { action: 'store.purchase', actorUserId: u.id } })).toBe(
      1,
    );

    // Buying it again adds the days to its end.
    const again = await buy(u, { itemId: frame.id, currency: 'COINS', days: 30, price: 150_000 });
    expect(again.status).toBe(201);
    expect(again.body.extended).toBe(true);
    expect(new Date(again.body.expiresAt as string).getTime()).toBe(end1 + 30 * DAY);
    expect((await items(u)).data.find((i) => i.id === frame.id)!.ownedUntil).toBe(again.body.expiresAt);
    expect((await balances(u)).coins).toBe(100_000);
  });

  it('buys with cherries (the cherry ledger); insufficient coins / cherries charge nothing', async () => {
    const u = await p.signup();
    await cherries(u, 500_000);
    const ok = await buy(u, { itemId: frame.id, currency: 'CHERRIES', days: 7, price: 400_000 });
    expect(ok.status, JSON.stringify(ok.body)).toBe(201);
    expect(ok.body.balances).toEqual({ coins: 0, cherries: 100_000, lockedCherries: 0 });
    const row = await ctx.prisma.cherryLedgerEntry.findFirst({
      where: { userId: u.id, reason: 'STORE_PURCHASE' },
    });
    expect(row).toMatchObject({ delta: -400_000n, balanceAfter: 100_000n, referenceId: ok.body.id });

    const poor = await p.signup();
    const noCoins = await buy(poor, { itemId: frame.id, currency: 'COINS', days: 7, price: 50_000 });
    expect(noCoins.status).toBe(409);
    expect(noCoins.body.error.code).toBe('INSUFFICIENT_COINS');
    const noCherries = await buy(poor, { itemId: frame.id, currency: 'CHERRIES', days: 7, price: 400_000 });
    expect(noCherries.status).toBe(409);
    expect(noCherries.body.error.code).toBe('INSUFFICIENT_CHERRIES');
    expect(await bag(poor)).not.toContainEqual(expect.objectContaining({ code: frame.code }));
  });

  it('locked task cherries are never spent (owner: «هل يُصرف كرز المهام المقفل في المتجر؟ لا»)', async () => {
    // Only locked task cherries: refused, nothing taken; the list shows them as locked, none spendable.
    const u = await p.signup();
    await taskCherries(u, 900_000);
    expect((await items(u)).balances).toEqual({ coins: 0, cherries: 0, lockedCherries: 900_000 });
    const refused = await buy(u, { itemId: frame.id, currency: 'CHERRIES', days: 7, price: 400_000 });
    expect(refused.status).toBe(409);
    expect(refused.body.error.code).toBe('INSUFFICIENT_CHERRIES');
    expect((await balances(u)).cherries).toBe(900_000);

    // Some unlocked and some locked: only the unlocked part pays.
    const mixed = await p.signup();
    await cherries(mixed, 500_000);
    await taskCherries(mixed, 300_000);
    expect((await items(mixed)).balances).toEqual({ coins: 0, cherries: 500_000, lockedCherries: 300_000 });
    const ok = await buy(mixed, { itemId: frame.id, currency: 'CHERRIES', days: 7, price: 400_000 });
    expect(ok.status, JSON.stringify(ok.body)).toBe(201);
    expect(ok.body.balances).toEqual({ coins: 0, cherries: 100_000, lockedCherries: 300_000 });
    const again = await buy(mixed, { itemId: frame.id, currency: 'CHERRIES', days: 7, price: 400_000 });
    expect(again.body.error.code).toBe('INSUFFICIENT_CHERRIES');
    expect((await balances(mixed)).cherries).toBe(400_000);
  });

  it('a price not offered, a changed price and a disabled item are refused; nothing charged', async () => {
    const u = await p.signup();
    await coins(u, 1_000_000);
    const unpriced = await buy(u, { itemId: frame.id, currency: 'COINS', days: 14, price: 1 });
    expect(unpriced.status).toBe(409);
    expect(unpriced.body.error).toMatchObject({
      code: 'STORE_UNAVAILABLE',
      details: [{ field: 'days', issue: 'not_priced' }],
    });
    const changed = await buy(u, { itemId: frame.id, currency: 'COINS', days: 7, price: 49_999 });
    expect(changed.body.error.code).toBe('STORE_PRICE_CHANGED');
    const unknown = await buy(u, { itemId: randomUUID(), currency: 'COINS', days: 7, price: 1 });
    expect(unknown.status).toBe(404);

    const off = await p.send(owner, 'post', `/admin/store/items/${bubble.id}/disable`, { reason: 'pause' });
    expectContract(off, 'disableAdminStoreItem');
    const refused = await buy(u, { itemId: bubble.id, currency: 'COINS', days: 14, price: 20_000 });
    expect(refused.status).toBe(409);
    expect(refused.body.error.details).toEqual([{ field: 'item', issue: 'item_off' }]);
    expect((await items(u)).data.map((i) => i.id)).not.toContain(bubble.id);
    await p.send(owner, 'post', `/admin/store/items/${bubble.id}/enable`, { reason: 'back' });
    expect((await balances(u)).coins).toBe(1_000_000);
  });

  it('the Idempotency-Key: the same body replays (200, charged once); another body → 409', async () => {
    const u = await p.signup();
    await coins(u, 200_000);
    const key = randomUUID();
    const body = { itemId: frame.id, currency: 'COINS', days: 7, price: 50_000 };
    const first = await buy(u, body, key);
    expect(first.status).toBe(201);
    const replay = await buy(u, body, key);
    expect(replay.status).toBe(200);
    expectContract(replay, 'buyStoreItem');
    expect(replay.body.id).toBe(first.body.id);
    expect((await balances(u)).coins).toBe(150_000);
    const conflict = await buy(u, { ...body, days: 30, price: 150_000 }, key);
    expect(conflict.status).toBe(409);
    expect(conflict.body.error.code).toBe('IDEMPOTENCY_CONFLICT');
    const noKey = await ctx.http.post('/api/v1/me/store/purchases').set(auth(u)).send(body);
    expect(noKey.status).toBe(400);
  });

  it('gifts: the item lands in their bag (GIFT, giftedBy) with a notification; blocked, inactive, oneself refused', async () => {
    const giver = await p.signup();
    const friend = await p.signup();
    await coins(giver, 500_000);
    const friendName = await usernameOf(friend);
    const res = await buy(giver, {
      itemId: frame.id,
      currency: 'COINS',
      days: 7,
      price: 50_000,
      recipient: friendName,
    });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expect(res.body.recipient.id).toBe(friend.id);
    const got = (await bag(friend)).find((i) => i.code === frame.code)!;
    expect(got).toMatchObject({ source: 'GIFT', giftedBy: { id: giver.id } });
    expect(await bag(giver)).not.toContainEqual(expect.objectContaining({ code: frame.code }));
    const note = await ctx.prisma.notification.findFirst({
      where: { recipientId: friend.id, type: 'BAG_ITEM_RECEIVED' },
      include: { actors: { select: { actorId: true } } },
    });
    expect(note).toMatchObject({ bagItemCode: frame.code, actors: [{ actorId: giver.id }] });

    const self = await buy(giver, {
      itemId: frame.id,
      currency: 'COINS',
      days: 7,
      price: 50_000,
      recipient: await usernameOf(giver),
    });
    expect(self.status).toBe(400);

    await ctx.http.put(`/api/v1/users/${friendName}/block`).set(auth(giver)).expect(200);
    const blocked = await buy(giver, {
      itemId: frame.id,
      currency: 'COINS',
      days: 7,
      price: 50_000,
      recipient: friendName,
    });
    expect(blocked.status).toBe(404);
    await ctx.http.delete(`/api/v1/users/${friendName}/block`).set(auth(giver)).expect(200);

    const gone = await p.signup();
    const goneName = await usernameOf(gone);
    await withMigrationClient((db) =>
      db.user.update({ where: { id: gone.id }, data: { status: 'SUSPENDED' } }),
    );
    const inactive = await buy(giver, {
      itemId: frame.id,
      currency: 'COINS',
      days: 7,
      price: 50_000,
      recipient: goneName,
    });
    expect(inactive.status).toBe(404);
    expect((await balances(giver)).coins).toBe(450_000);
  });

  it('a frozen account (coins below 0) buys nothing, even with cherries', async () => {
    const u = await p.signup();
    await cherries(u, 500_000);
    await ctx.prisma.$transaction((tx) => reverseTopupIn(tx, u.id, 10n, randomUUID()));
    const res = await buy(u, { itemId: frame.id, currency: 'CHERRIES', days: 7, price: 400_000 });
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('TOPUP_ACCOUNT_FROZEN');
    expect((await balances(u)).cherries).toBe(500_000);
  });

  it('worn: a store bubble shows in UserSummary.wear and takes the VIP bubble off (one worn item per kind)', async () => {
    const u = await p.signup();
    await coins(u, 2_000_000);
    // A VIP member (VIP 1 is seeded with a CHAT_BUBBLE perk).
    const vip = await ctx.http
      .post('/api/v1/me/vip/purchases')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({ tierId: '01a25200-0000-7000-8000-000000000001', priceCoins: 1_000_000 });
    expect(vip.status, JSON.stringify(vip.body)).toBe(201);
    const bought = await buy(u, { itemId: bubble.id, currency: 'COINS', days: 14, price: 20_000 });
    expect(bought.status).toBe(201);
    const wear = await ctx.http
      .put('/api/v1/me/bag/equipped')
      .set(auth(u))
      .send({ category: 'CHAT_BUBBLE', code: bubble.code });
    expect(wear.status, JSON.stringify(wear.body)).toBe(200);
    expectContract(wear, 'setMyBagEquipped');
    expect(wear.body.equipped.art).toMatchObject({ format: 'MP4', alpha: 'SIDE_BY_SIDE' });

    const items2 = await bag(u);
    expect(items2.find((i) => i.code === 'vip:CHAT_BUBBLE')!.equipped).toBe(false);
    expect(items2.find((i) => i.code === bubble.code)!.equipped).toBe(true);
    const name = await usernameOf(u);
    const viewer = await p.signup();
    const profile = await ctx.http.get(`/api/v1/users/${name}`).set(auth(viewer));
    expect(profile.status).toBe(200);
    expectContract(profile, 'getPublicProfile');
    expect(profile.body.wear.chatBubble).toMatchObject({ code: bubble.code, format: 'MP4' });
    expect(profile.body.vip.off).toContain('CHAT_BUBBLE');

    // Wearing the VIP bubble again takes the store one off.
    const back = await ctx.http
      .put('/api/v1/me/bag/equipped')
      .set(auth(u))
      .send({ category: 'CHAT_BUBBLE', code: 'vip:CHAT_BUBBLE' });
    expect(back.status).toBe(200);
    expect((await bag(u)).find((i) => i.code === bubble.code)!.equipped).toBe(false);
    const after = await ctx.http.get(`/api/v1/users/${name}`).set(auth(viewer));
    expect(after.body.wear).toBeUndefined();
  });

  it('the panel sees the sales and their totals', async () => {
    const res = await p.send(support, 'get', '/admin/store/sales?limit=5');
    expect(res.status).toBe(200);
    expectContract(res, 'listAdminStoreSales');
    expect(res.body.data).toHaveLength(5);
    // 2 coin purchases, 2 cherry (one with locked task cherries beside), 1 (replayed), 1 gift, 1 bubble.
    expect(res.body.totals.purchases).toBe(7);
    expect(res.body.totals.gifts).toBe(1);
    expect(res.body.totals.cherries).toBe(800_000);
    const one = await p.send(support, 'get', `/admin/store/sales?itemId=${bubble.id}`);
    expect(one.body.totals).toMatchObject({ purchases: 1, coins: 20_000 });
  });
});
