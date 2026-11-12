/**
 * D381 (owner 2026-11-11: VIP perks phase 2 — gifts, CP, support, rockets, voice; contract v1.134-social, CONVENTIONS
 * §10.171): EXCLUSIVE_GIFTS, HIGHER_GIFT_QUANTITY, FREE_CP_REQUEST, PRIORITY_SUPPORT (reports), MONTHLY_ROCKETS,
 * SCHEDULED_GIFT and LONGER_VOICE — holder vs non-holder, inheritance from a lower tier, an ended VIP and the abuse
 * cases. End to end against PostgreSQL + Redis with the API as the DML-only runtime role. The WhatsApp inbox's priority
 * is in d381-vip-priority-whatsapp.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { addGiftIn, type GiftFields } from '../src/modules/gifts/gift-catalogue.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { DmScheduledGiftsService } from '../src/modules/messages/dm-scheduled-gifts.service.js';
import { grantVipMonthlyRocketsIn } from '../src/modules/vip/vip-monthly-rockets.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Admin } from './helpers/admin-panel.js';
import { m4a } from './helpers/m4a.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, withMigrationClient, type TestContext } from './helpers/test-app.js';

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';
const VIP1 = '01a25200-0000-7000-8000-000000000001';
const DAY = 86_400_000;
const MEDIA_ON = {
  MEDIA_UPLOADS_ENABLED: 'true',
  S3_BUCKET: 'kabso-media-test',
  S3_ACCESS_KEY_ID: 'test',
  S3_SECRET_ACCESS_KEY: 'test',
  MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
};

interface User {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

describe('D381 contract coverage', () => {
  it('openapi v1.134-social declares the scheduled gift operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'listVipScheduledGifts GET /api/v1/me/vip/scheduled-gifts',
      'scheduleVipGift POST /api/v1/me/vip/scheduled-gifts',
      'cancelVipScheduledGift DELETE /api/v1/me/vip/scheduled-gifts/{scheduledGiftId}',
    ]) {
      expect(ids).toContain(op);
    }
  });
});

describe('D381 VIP gift, CP, support, rocket and voice perks', { timeout: 300_000 }, () => {
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let moderator: Admin;
  let vip2Id = '';
  let seq = 0;
  // m1: VIP_1 (holds the perks itself); m2: VIP_2 (inherits them from VIP_1, lists its own exclusive gift); n: none.
  let m1: User;
  let m2: User;
  let n: User;
  let castle = '';
  let crown = '';
  let rose = '';

  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<User> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
    };
  };
  const follow = async (by: User, u: User) => {
    const res = await ctx.http.put(`/api/v1/users/${u.username}/follow`).set(auth(by));
    expect(res.status, JSON.stringify(res.body)).toBeLessThan(300);
  };
  const friends = async (a: User, b: User) => {
    await follow(a, b);
    await follow(b, a);
  };
  const coins = (u: User, amount: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  const wallet = async (u: User) =>
    Number((await ctx.prisma.wallet.findUnique({ where: { userId: u.id } }))?.coins ?? 0n);
  const gift = async (fields: Partial<GiftFields> = {}): Promise<string> => {
    seq += 1;
    const code = `d381_${String(seq)}_${randomUUID().slice(0, 4)}`;
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
  const giveVip = (u: User, tierId: string, days = 30) =>
    withMigrationClient((db) =>
      db.vipMembership.upsert({
        where: { userId: u.id },
        create: {
          userId: u.id,
          tierId,
          startedAt: new Date(Date.now() - DAY),
          expiresAt: new Date(Date.now() + days * DAY),
        },
        update: { tierId, startedAt: new Date(Date.now() - DAY), expiresAt: new Date(Date.now() + days * DAY) },
      }),
    );
  const endVip = (u: User) =>
    withMigrationClient((db) =>
      db.vipMembership.update({
        where: { userId: u.id },
        data: { startedAt: new Date(Date.now() - 40 * DAY), expiresAt: new Date(Date.now() - 1000) },
      }),
    );
  const catalogue = async (u: User) => {
    const res = await ctx.http.get('/api/v1/gifts/catalogue').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getGiftCatalogue');
    return res.body as {
      version: string;
      quantities: number[];
      vipGiftCodes?: string[];
      vipQuantities?: number[];
      data: { code: string }[];
    };
  };
  const dmGift = (by: User, to: User, body: Record<string, unknown>) =>
    ctx.http
      .post('/api/v1/dm/gifts')
      .set(auth(by))
      .send({ to: to.username, quantity: 1, source: 'COINS', clientId: randomUUID(), ...body });
  const myVip = async (u: User) => {
    const res = await ctx.http.get('/api/v1/me/vip').set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getMyVip');
    return res.body as { membership: unknown; perksNow?: Record<string, unknown> };
  };
  const schedule = (by: User, body: Record<string, unknown>) =>
    ctx.http
      .post('/api/v1/me/vip/scheduled-gifts')
      .set(auth(by))
      .set('Accept-Language', 'ar')
      .send({
        quantity: 1,
        deliverAt: new Date(Date.now() + 3_600_000).toISOString(),
        clientId: randomUUID(),
        ...body,
      });
  const ledger = (u: User, reason: string) =>
    ctx.prisma.walletLedger.findMany({ where: { userId: u.id, reason: reason as never }, orderBy: { id: 'asc' } });

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp(
      {
        ...MEDIA_ON,
        ADMIN_TOTP_KEY: ADMIN_KEY,
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        ADMIN_SESSION_MAX_SECONDS: '604800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '10000/900',
        LUCKY_GIFTS_ENABLED: 'true',
        JWT_ACCESS_TTL_SECONDS: String(7 * 86_400),
      },
      [{ token: OBJECT_STORAGE, value: storage }],
    );
    owner = await p.makeAdmin(['OWNER']);
    moderator = await p.makeAdmin(['MODERATION']);
    // The panel helper froze Date for the authenticator codes; real time from here (the worker and months use it).
    vi.useRealTimers();
    castle = await gift({ priceCoins: 5 });
    crown = await gift({ priceCoins: 7 });
    rose = await gift({ priceCoins: 1 });
    const v1 = await p.send(owner, 'patch', `/admin/vip/tiers/${VIP1}`, {
      reason: 'owner D381',
      perks: [
        { code: 'BADGE' },
        { code: 'EXCLUSIVE_GIFTS', value: [castle] },
        { code: 'FREE_CP_REQUEST', value: 2 },
        { code: 'PRIORITY_SUPPORT' },
        { code: 'MONTHLY_ROCKETS', value: { count: 2, stage: 'STAGE_2' } },
        { code: 'SCHEDULED_GIFT' },
        { code: 'HIGHER_GIFT_QUANTITY', value: 9999 },
        { code: 'LONGER_VOICE', value: 180 },
      ],
    });
    expect(v1.status, JSON.stringify(v1.body)).toBe(200);
    const v2 = await p.send(owner, 'post', '/admin/vip/tiers', {
      code: 'VIP_2',
      nameAr: 'في آي بي 2',
      nameEn: 'VIP 2',
      color: '#3366CC',
      priceCoins: 2_000_000,
      durationDays: 30,
      enabled: true,
      // Only its own exclusive gift: every other perk comes from VIP_1 (inheritance), castle too.
      perks: [{ code: 'EXCLUSIVE_GIFTS', value: [crown] }],
      reason: 'owner D381',
    });
    expect(v2.status, JSON.stringify(v2.body)).toBe(201);
    vip2Id = v2.body.id as string;
    [m1, m2, n] = [await signup(), await signup(), await signup()];
    await giveVip(m1, VIP1);
    await giveVip(m2, vip2Id);
    for (const u of [m1, m2, n]) await coins(u, 1_000_000);
  });
  afterAll(async () => {
    vi.useRealTimers();
    await ctx?.close();
  });

  describe('EXCLUSIVE_GIFTS', () => {
    it('the catalogue lists an exclusive gift only to a member who may send it, with the «VIP» tab codes', async () => {
      const plain = await catalogue(n);
      const codes = plain.data.map((g) => g.code);
      expect(codes).toContain(rose);
      expect(codes).not.toContain(castle);
      expect(codes).not.toContain(crown);
      expect(plain.vipGiftCodes).toBeUndefined();

      const one = await catalogue(m1);
      expect(one.data.map((g) => g.code)).toContain(castle);
      expect(one.data.map((g) => g.code)).not.toContain(crown);
      expect(one.vipGiftCodes).toEqual([castle]);
      // VIP_2 holds its own list and VIP_1's (the lower list carries up).
      const two = await catalogue(m2);
      expect(two.vipGiftCodes).toEqual([castle, crown].sort());
      expect(two.version).not.toBe(plain.version);
    });

    it('a send by a member whose VIP may not send it is 409 GIFT_UNAVAILABLE; a holder (or a higher tier) sends it', async () => {
      const to = await signup();
      for (const u of [m1, m2, n]) await friends(u, to);
      const refused = await dmGift(n, to, { giftCode: castle });
      expect(refused.status).toBe(409);
      expect(refused.body.error.code).toBe('GIFT_UNAVAILABLE');
      expect((await dmGift(m1, to, { giftCode: crown })).status).toBe(409);
      const before = await wallet(m1);
      const ok = await dmGift(m1, to, { giftCode: castle });
      expect(ok.status, JSON.stringify(ok.body)).toBe(201);
      expectContract(ok, 'sendDmGift');
      expect(await wallet(m1)).toBe(before - 5);
      expect((await dmGift(m2, to, { giftCode: crown })).status).toBe(201);
      expect((await dmGift(m2, to, { giftCode: castle })).status).toBe(201);
      // Nothing was charged for the refused sends.
      expect((await ledger(n, 'DM_GIFT')).length).toBe(0);
    });
  });

  describe('HIGHER_GIFT_QUANTITY', () => {
    it('a holder (inherited too) gets the larger quantities; a non-member is refused 400', async () => {
      const plain = await catalogue(n);
      expect(plain.vipQuantities).toBeUndefined();
      expect(plain.quantities).not.toContain(9999);
      expect((await catalogue(m1)).vipQuantities).toEqual([3344, 5200, 9999]);
      expect((await catalogue(m2)).vipQuantities).toEqual([3344, 5200, 9999]);

      const to = await signup();
      for (const u of [m1, m2, n]) await friends(u, to);
      const no = await dmGift(n, to, { giftCode: rose, quantity: 9999 });
      expect(no.status).toBe(400);
      expect(no.body.error.details).toEqual([{ field: 'quantity', issue: 'invalid_value' }]);
      const before = await wallet(m2);
      const big = await dmGift(m2, to, { giftCode: rose, quantity: 9999 });
      expect(big.status, JSON.stringify(big.body)).toBe(201);
      expect(await wallet(m2)).toBe(before - 9999);
      // Above the holder's maximum: refused.
      expect((await dmGift(m1, to, { giftCode: rose, quantity: 13140 })).status).toBe(400);
    });

    it('a lucky gift keeps the configured quantities for holders too', async () => {
      const lucky = await gift({ category: 'LUCKY', priceCoins: 1 });
      const to = await signup();
      await friends(m1, to);
      const res = await dmGift(m1, to, { giftCode: lucky, quantity: 9999 });
      expect(res.status).toBe(400);
      expect(res.body.error.details).toEqual([{ field: 'quantity', issue: 'invalid_value' }]);
    });
  });

  describe('FREE_CP_REQUEST', () => {
    const cpConfig = async (u: User) => {
      const res = await ctx.http.get('/api/v1/cp/config').set(auth(u));
      expect(res.status).toBe(200);
      expectContract(res, 'getCpConfig');
      return res.body as { requestCost: number; vipFreeRequests?: { perMonth: number; used: number; left: number } };
    };
    const request = (by: User, to: User) =>
      ctx.http.post('/api/v1/cp/requests').set(auth(by)).send({ username: to.username, clientId: randomUUID() });

    it('a holder sends N free requests a month (nothing charged, nothing refunded), then 99 coins', async () => {
      expect((await cpConfig(n)).vipFreeRequests).toBeUndefined();
      const member = await signup();
      await giveVip(member, vip2Id); // inherited from VIP_1
      await coins(member, 1000);
      expect((await cpConfig(member)).vipFreeRequests).toMatchObject({ perMonth: 2, used: 0, left: 2 });
      const [a, b, c] = [await signup(), await signup(), await signup()];
      const r1 = await request(member, a);
      expect(r1.status, JSON.stringify(r1.body)).toBe(201);
      expect(await wallet(member)).toBe(1000);
      // Declined: the free slot stays used and no coins come back.
      expect((await ctx.http.post(`/api/v1/cp/requests/${r1.body.id as string}/decline`).set(auth(a))).status).toBe(
        200,
      );
      expect(await wallet(member)).toBe(1000);
      expect((await ledger(member, 'CP_REFUND')).length).toBe(0);
      expect((await request(member, b)).status).toBe(201);
      expect((await cpConfig(member)).vipFreeRequests).toMatchObject({ used: 2, left: 0 });
      expect((await request(member, c)).status).toBe(201);
      expect(await wallet(member)).toBe(1000 - 99);
      expect((await ledger(member, 'CP_REQUEST')).map((r) => Number(r.delta))).toEqual([-99]);
      // A non-member pays as before.
      const before = await wallet(n);
      expect((await request(n, await signup())).status).toBe(201);
      expect(await wallet(n)).toBe(before - 99);
    });
  });

  describe('PRIORITY_SUPPORT (the shared reports queue)', () => {
    it("a holder's report is listed before older ones; a safety reason stays first for everyone", async () => {
      const report = async (by: User, reason: string) => {
        const target = await signup();
        const res = await ctx.http
          .post('/api/v1/reports')
          .set(auth(by))
          .send({ targetType: 'USER', targetId: target.username, reason });
        expect(res.status, JSON.stringify(res.body)).toBe(201);
        return res.body.id as string;
      };
      const plain = await report(n, 'SPAM');
      const held = await report(m2, 'SPAM');
      const safety = await report(n, 'NUDITY');
      const queue = await ctx.http.get('/api/v1/admin/reports?limit=50').set(auth(moderator));
      expect(queue.status, JSON.stringify(queue.body)).toBe(200);
      expectContract(queue, 'listAdminReports');
      const rows = (queue.body.data as { id: string; priority: number }[]).filter((r) =>
        [plain, held, safety].includes(r.id),
      );
      expect(rows.map((r) => [r.id, r.priority])).toEqual([
        [safety, 2],
        [held, 1],
        [plain, 0],
      ]);
      // Page by page (limit 1) the order is the same.
      const walked: string[] = [];
      let cursor: string | null = null;
      for (let i = 0; i < 20; i += 1) {
        const page = await ctx.http
          .get(`/api/v1/admin/reports?limit=1${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`)
          .set(auth(moderator));
        expect(page.status).toBe(200);
        walked.push(...(page.body.data as { id: string }[]).map((r) => r.id));
        cursor = page.body.page.nextCursor as string | null;
        if (!cursor) break;
      }
      expect(walked.filter((id) => [plain, held, safety].includes(id))).toEqual([safety, held, plain]);
      // The reporter's own view carries no priority.
      const mine = await ctx.http.get('/api/v1/me/reports').set(auth(n));
      if (mine.status === 200) {
        for (const r of mine.body.data as Record<string, unknown>[]) expect(r.priority).toBeUndefined();
      }
    });
  });

  describe('MONTHLY_ROCKETS', () => {
    it("a holder's traffic cards come once a month (idempotent, audited), shown in «الخاص بي VIP»", async () => {
      const member = await signup();
      await giveVip(member, vip2Id);
      const cards = async () =>
        (await ctx.prisma.liveBoostCard.findUnique({ where: { userId_minutes: { userId: member.id, minutes: 20 } } }))
          ?.quantity ?? 0;
      const mine = await myVip(member);
      expect(mine.perksNow?.monthlyRockets).toMatchObject({ stage: 2, minutes: 20, count: 2 });
      expect(await cards()).toBe(2);
      await myVip(member);
      const offers = await ctx.http.get('/api/v1/live/boosts/offers').set(auth(member));
      expect(offers.status, JSON.stringify(offers.body)).toBe(200);
      expect(await cards()).toBe(2);
      const audits = await withMigrationClient((db) =>
        db.auditLog.findMany({ where: { action: 'vip.monthly_rockets.grant', targetId: member.id } }),
      );
      expect(audits).toHaveLength(1);
      expect(audits[0]!.metadata).toMatchObject({ stage: 2, minutes: 20, count: 2 });
      // The next month: a new grant.
      const next = new Date(Date.now() + 32 * DAY);
      await ctx.prisma.$transaction((tx) =>
        grantVipMonthlyRocketsIn(tx, member.id, next, {
          timeZone: ctx.config.live.rankingsTimeZone,
          stageMinutes: ctx.config.boosts.prices.map((x) => x.minutes),
        }),
      );
      expect(await cards()).toBe(4);
      // A non-member: nothing.
      const plain = await myVip(n);
      expect(plain.perksNow).toBeUndefined();
      expect(await ctx.prisma.liveBoostCard.count({ where: { userId: n.id } })).toBe(0);
    });

    it("«الخاص بي VIP» shows what each held perk gives now", async () => {
      const now = (await myVip(m2)).perksNow!;
      expect(now).toMatchObject({
        freeCpRequests: { perMonth: 2 },
        maxGiftQuantity: 9999,
        voiceSeconds: 180,
        exclusiveGifts: 2,
        scheduledGifts: { maxPending: 10 },
        prioritySupport: true,
      });
    });
  });

  describe('SCHEDULED_GIFT', () => {
    const service = () => ctx.app.get(DmScheduledGiftsService);

    it('only a holder schedules; the coins are held; a retry charges nothing again; bad times are refused', async () => {
      const to = await signup();
      await friends(n, to);
      await friends(m1, to);
      const no = await schedule(n, { to: to.username, giftCode: rose });
      expect(no.status).toBe(409);
      expect(no.body.error).toMatchObject({ code: 'VIP_UNAVAILABLE', details: [{ field: 'perk', issue: 'no_perk' }] });
      expect(
        (await schedule(m1, { to: to.username, giftCode: rose, deliverAt: new Date(Date.now() + 60_000).toISOString() }))
          .status,
      ).toBe(400);
      expect((await schedule(m1, { to: m1.username, giftCode: rose })).status).toBe(400);
      const lucky = await gift({ category: 'LUCKY', priceCoins: 3 });
      expect((await schedule(m1, { to: to.username, giftCode: lucky })).status).toBe(409);
      // An exclusive gift the caller's VIP may not send.
      expect((await schedule(m1, { to: to.username, giftCode: crown })).body.error.code).toBe('GIFT_UNAVAILABLE');

      const before = await wallet(m1);
      const clientId = randomUUID();
      const ok = await schedule(m1, { to: to.username, giftCode: castle, quantity: 9, clientId });
      expect(ok.status, JSON.stringify(ok.body)).toBe(201);
      expectContract(ok, 'scheduleVipGift');
      expect(ok.body.scheduledGift).toMatchObject({ status: 'PENDING', coins: 45, quantity: 9, giftCode: castle });
      expect(ok.body.coins).toBe(before - 45);
      const again = await schedule(m1, { to: to.username, giftCode: castle, quantity: 9, clientId });
      expect(again.status).toBe(200);
      expect(again.body.scheduledGift.id).toBe(ok.body.scheduledGift.id);
      expect(await wallet(m1)).toBe(before - 45);
      const list = await ctx.http.get('/api/v1/me/vip/scheduled-gifts').set(auth(m1));
      expect(list.status).toBe(200);
      expectContract(list, 'listVipScheduledGifts');
      expect(list.body.data[0].id).toBe(ok.body.scheduledGift.id);

      // Cancelled: the coins come back; a second cancel is 409; another sender's gift is 404.
      const id = ok.body.scheduledGift.id as string;
      expect((await ctx.http.delete(`/api/v1/me/vip/scheduled-gifts/${id}`).set(auth(n))).status).toBe(404);
      const cancel = await ctx.http.delete(`/api/v1/me/vip/scheduled-gifts/${id}`).set(auth(m1));
      expect(cancel.status, JSON.stringify(cancel.body)).toBe(200);
      expectContract(cancel, 'cancelVipScheduledGift');
      expect(cancel.body.scheduledGift.status).toBe('CANCELLED');
      expect(await wallet(m1)).toBe(before);
      const twice = await ctx.http.delete(`/api/v1/me/vip/scheduled-gifts/${id}`).set(auth(m1));
      expect(twice.status).toBe(409);
      expect(twice.body.error.details).toEqual([{ field: 'status', issue: 'not_pending' }]);
    });

    it('the worker delivers a due gift as a conversation gift (held → released → charged), once', async () => {
      const to = await signup();
      await friends(m1, to);
      const before = await wallet(m1);
      const res = await schedule(m1, { to: to.username, giftCode: castle, quantity: 9 });
      expect(res.status).toBe(201);
      const id = res.body.scheduledGift.id as string;
      // Not due yet: nothing happens.
      expect(await service().deliverDue()).toBe(0);
      const later = new Date(Date.now() + 2 * 3_600_000);
      expect(await service().deliverDue(later)).toBeGreaterThanOrEqual(1);
      expect(await service().deliverDue(later)).toBe(0);
      const row = await ctx.prisma.vipScheduledGift.findUniqueOrThrow({ where: { id } });
      expect(row.status).toBe('DELIVERED');
      expect(row.dmMessageId).not.toBeNull();
      const msg = await ctx.prisma.dmMessage.findUniqueOrThrow({ where: { id: row.dmMessageId! } });
      expect(msg.senderId).toBe(m1.id);
      expect(await wallet(m1)).toBe(before - 45);
      const refs = await ctx.prisma.walletLedger.findMany({
        where: { userId: m1.id, referenceId: id },
        orderBy: { id: 'asc' },
      });
      expect(refs.map((r) => [r.reason, Number(r.delta)])).toEqual([
        ['VIP_SCHEDULED_GIFT', -45],
        ['VIP_SCHEDULED_GIFT_RELEASE', 45],
      ]);
      expect((await ledger(m1, 'DM_GIFT')).some((r) => Number(r.delta) === -45)).toBe(true);
    });

    it('a delivery the rules of that moment refuse (a block) fails and gives the coins back', async () => {
      const to = await signup();
      await friends(m1, to);
      const before = await wallet(m1);
      const res = await schedule(m1, { to: to.username, giftCode: rose, quantity: 9999 });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      expect((await ctx.http.put(`/api/v1/users/${m1.username}/block`).set(auth(to))).status).toBeLessThan(300);
      await service().deliverDue(new Date(Date.now() + 2 * 3_600_000));
      const row = await ctx.prisma.vipScheduledGift.findUniqueOrThrow({ where: { id: res.body.scheduledGift.id } });
      expect(row.status).toBe('FAILED');
      expect(row.failure).toBeTruthy();
      expect(await wallet(m1)).toBe(before);
    });

    it('at most 10 wait per sender', async () => {
      const sender = await signup();
      await giveVip(sender, VIP1);
      await coins(sender, 1000);
      const to = await signup();
      await friends(sender, to);
      for (let i = 0; i < 10; i += 1) {
        expect((await schedule(sender, { to: to.username, giftCode: rose })).status).toBe(201);
      }
      const over = await schedule(sender, { to: to.username, giftCode: rose });
      expect(over.status).toBe(409);
      expect(over.body.error.details).toEqual([{ field: 'pending', issue: 'too_many' }]);
      expect(await wallet(sender)).toBe(990);
    });
  });

  describe('LONGER_VOICE', () => {
    const upload = async (u: User, bytes: Buffer) => {
      const slot = await ctx.http
        .post('/api/v1/media/uploads')
        .set(auth(u))
        .send({ kind: 'DM_VOICE', contentType: 'audio/mp4', byteSize: bytes.length });
      if (slot.status !== 201) return { slot, done: null };
      expect(storage.upload(slot.body.uploadUrl, bytes, 'audio/mp4')).toBe(true);
      const done = await ctx.http.post(`/api/v1/media/uploads/${slot.body.uploadId}/complete`).set(auth(u));
      return { slot, done };
    };

    it("a holder's clip may last the perk's seconds (and weigh more); everyone else keeps 30 s and 1 MiB", async () => {
      const long = m4a({ durationMs: 120_000 });
      const held = await upload(m2, long);
      expect(held.done?.status, JSON.stringify(held.done?.body)).toBe(200);
      expect(held.done!.body.durationMs).toBe(120_000);
      const plain = await upload(n, long);
      expect(plain.done?.status).toBe(422);
      expect(plain.done?.body.error.code).toBe('MEDIA_INVALID');
      expect((await upload(m2, m4a({ durationMs: 181_000 }))).done?.status).toBe(422);
      // The size: 3 MiB is fine for a 180 s holder, too big for others.
      const big = m4a({ durationMs: 5_000, dataBytes: 3 * 1024 * 1024 });
      expect((await upload(n, big)).slot.status).toBe(400);
      expect((await upload(m2, big)).done?.status).toBe(200);
    });
  });

  describe('an ended VIP', () => {
    it('removes every perk at once', async () => {
      const member = await signup();
      await giveVip(member, VIP1);
      await coins(member, 100_000);
      const to = await signup();
      await friends(member, to);
      expect((await dmGift(member, to, { giftCode: castle })).status).toBe(201);
      await endVip(member);
      expect((await dmGift(member, to, { giftCode: castle })).status).toBe(409);
      expect((await dmGift(member, to, { giftCode: rose, quantity: 9999 })).status).toBe(400);
      const cat = await catalogue(member);
      expect(cat.vipGiftCodes).toBeUndefined();
      expect(cat.vipQuantities).toBeUndefined();
      const cp = await ctx.http.get('/api/v1/cp/config').set(auth(member));
      expect(cp.body.vipFreeRequests).toBeUndefined();
      expect((await schedule(member, { to: to.username, giftCode: rose })).status).toBe(409);
      expect((await myVip(member)).perksNow).toBeUndefined();
      const slot = await ctx.http
        .post('/api/v1/media/uploads')
        .set(auth(member))
        .send({ kind: 'DM_VOICE', contentType: 'audio/mp4', byteSize: 3 * 1024 * 1024 });
      expect(slot.status).toBe(400);
    });
  });
});
