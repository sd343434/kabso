/**
 * D258 (owner's VIP 1 perks; contract v1.83-social, CONVENTIONS §10.94.4–§10.94.5): a VIP's free public messages a
 * day (DAILY_BULLET 3) and the level speed-up (LEVEL_SPEEDUP 1 % on the points a gift earns). End to end against
 * PostgreSQL + Redis with the API as the DML-only runtime role.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { presetLadder } from '../src/modules/levels/level-preset.js';
import { LIVE_BULLET_COST_COINS } from '../src/modules/live/live-bullets.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

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

describe('D258 VIP daily perks', { timeout: 120_000 }, () => {
  const clock = new FakeClock();
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
  const vip = async (u: TestUser) => {
    await coins(u, 1_000_000);
    const res = await ctx.http
      .post('/api/v1/me/vip/purchases')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({ tierId: VIP1, priceCoins: 1_000_000 });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
  };
  const host = async (): Promise<TestUser> => {
    const u = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  const goLive = async (u: TestUser): Promise<string> => {
    const res = await ctx.http.post('/api/v1/live/rooms').set(auth(u)).send({ title: 'VIP' });
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
  const bullet = (roomId: string, u: TestUser) =>
    ctx.http
      .post(`/api/v1/live/rooms/${roomId}/bullets`)
      .set(auth(u))
      .send({ text: 'VIP hello', clientId: randomUUID() });

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: Clock, value: clock },
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
    // The test database is truncated: a published SUPPORT ladder is seeded again (as D169 does).
    const category = await ctx.prisma.levelCategory.create({
      data: {
        code: 'SUPPORT',
        nameAr: 'الدعم',
        nameEn: 'Support',
        descriptionAr: 'دعم',
        descriptionEn: 'Support',
      },
    });
    const version = await ctx.prisma.levelCategoryVersion.create({
      data: {
        categoryId: category.id,
        versionNumber: 1,
        status: 'PUBLISHED',
        multiplier: '1',
        valueUnit: 'COIN',
        publishedAt: new Date(),
        levels: { create: presetLadder() },
      },
    });
    await ctx.prisma.levelCategory.update({
      where: { id: category.id },
      data: { isEnabled: true, publishedVersionId: version.id },
    });
  });
  afterAll(async () => ctx?.close());

  it('three free public messages a day, then LIVE_BULLET_COST_COINS (10 000, D371) each; a new day gives three again', async () => {
    const h = await host();
    const room = await goLive(h);
    const member = await signup();
    await vip(member);
    await coins(member, LIVE_BULLET_COST_COINS + 100);
    await join(room, member);
    const before = Number((await ctx.http.get('/api/v1/wallet/me').set(auth(member))).body.coins);
    for (const left of [2, 1, 0]) {
      const res = await bullet(room, member);
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      expectContract(res, 'sendLiveBullet');
      expect(res.body).toMatchObject({ free: true, freeLeft: left, coins: before });
      clock.advance(5.01);
    }
    const paid = await bullet(room, member);
    expect(paid.status).toBe(201);
    expect(paid.body).toMatchObject({ free: false, freeLeft: 0, coins: before - LIVE_BULLET_COST_COINS });
    const rows = await ctx.prisma.liveBullet.findMany({
      where: { userId: member.id },
      orderBy: { createdAt: 'asc' },
    });
    expect(rows.map((r) => r.cost)).toEqual([0, 0, 0, LIVE_BULLET_COST_COINS]);
    // Someone without VIP pays from the first one, and gets no `free` field.
    const plain = await signup();
    await coins(plain, LIVE_BULLET_COST_COINS + 100);
    await join(room, plain);
    const once = await bullet(room, plain);
    expect(once.status).toBe(201);
    expect(once.body.free).toBeUndefined();
    // The next day: three free again.
    // (A day without heartbeats ends the room: a new one is opened.)
    clock.advance(86_400);
    const next = await goLive(await host());
    await join(next, member);
    const tomorrow = await bullet(next, member);
    expect(tomorrow.body).toMatchObject({ free: true, freeLeft: 2 });
  });

  it('the level speed-up adds 1 % to the support points a gift earns', async () => {
    await ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, 'd258_rose', {
        category: 'POPULAR',
        nameAr: 'وردة',
        nameEn: 'Rose',
        priceCoins: 10_000,
        assetKey: 'gift_d258_rose', // gitleaks:allow (an asset name)
        animationKey: null,
        sortOrder: 0,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      }),
    );
    const h = await host();
    const room = await goLive(h);
    const send = async (from: TestUser) => {
      await coins(from, 10_000);
      await join(room, from);
      const res = await ctx.http
        .post(`/api/v1/live/rooms/${room}/gifts`)
        .set(auth(from))
        .send({
          giftCode: 'd258_rose',
          quantity: 1,
          recipients: [h.username],
          source: 'COINS',
          clientId: randomUUID(),
        });
      expect([200, 201], JSON.stringify(res.body)).toContain(res.status);
      const support = await ctx.prisma.levelCategory.findUnique({
        where: { code: 'SUPPORT' },
        select: { id: true },
      });
      const rows = await ctx.prisma.pointsLedgerEntry.findMany({
        where: { userId: from.id, categoryId: support!.id },
        select: { pointsDelta: true, reason: true },
      });
      return rows;
    };
    const plain = await send(await signup());
    const member = await signup();
    await vip(member);
    const sped = await send(member);
    expect(plain).toHaveLength(1);
    expect(sped).toHaveLength(1);
    const base = plain[0]!.pointsDelta;
    expect(base > 0n).toBe(true);
    expect(sped[0]!.pointsDelta).toBe(base + base / 100n);
    expect(sped[0]!.reason).toBe('VIP level speed-up +1%');
    expect(plain[0]!.reason).toBeNull();
  });
  it('daily coins: the panel sets the amount; a member claims once a day; no perk → 409 no_perk', async () => {
    const plain = await signup();
    const refused = await ctx.http.post('/api/v1/me/vip/daily-coins').set(auth(plain));
    expect(refused.status).toBe(409);
    expect(refused.body.error).toMatchObject({
      code: 'VIP_UNAVAILABLE',
      details: [{ field: 'perk', issue: 'no_perk' }],
    });

    const member = await signup();
    await vip(member);
    // VIP 1's DAILY_COINS is seeded without an amount: nothing to claim yet.
    const none = await ctx.http.get('/api/v1/me/vip').set(auth(member));
    expect(none.status).toBe(200);
    expectContract(none, 'getMyVip');
    expect(none.body.dailyCoins).toBeUndefined();
    expect((await ctx.http.post('/api/v1/me/vip/daily-coins').set(auth(member))).status).toBe(409);

    // The owner sets it (as `updateAdminVipTier` does).
    await ctx.prisma.vipTierPerk.updateMany({
      where: { tierId: VIP1, code: 'DAILY_COINS' },
      data: { amount: 500 },
    });
    const before = Number((await ctx.http.get('/api/v1/wallet/me').set(auth(member))).body.coins);
    const state = await ctx.http.get('/api/v1/me/vip').set(auth(member));
    expectContract(state, 'getMyVip');
    expect(state.body.dailyCoins).toMatchObject({ amount: 500, claimedToday: false });

    const first = await ctx.http.post('/api/v1/me/vip/daily-coins').set(auth(member));
    expect(first.status, JSON.stringify(first.body)).toBe(200);
    expectContract(first, 'claimVipDailyCoins');
    expect(first.body).toMatchObject({
      coins: 500,
      balance: before + 500,
      dailyCoins: { amount: 500, claimedToday: true },
    });
    // The same day: nothing more (also two at once).
    const [again, racing] = await Promise.all([
      ctx.http.post('/api/v1/me/vip/daily-coins').set(auth(member)),
      ctx.http.post('/api/v1/me/vip/daily-coins').set(auth(member)),
    ]);
    for (const res of [again, racing]) {
      expect(res.status).toBe(200);
      expect(res.body).toMatchObject({ coins: 0, balance: before + 500 });
    }
    const ledger = await ctx.prisma.walletLedgerEntry.findMany({
      where: { userId: member.id, reason: 'VIP_DAILY_COINS' },
    });
    expect(ledger.map((l) => l.delta)).toEqual([500n]);

    // The next day: once more.
    clock.advance(86_400);
    const tomorrow = await ctx.http.post('/api/v1/me/vip/daily-coins').set(auth(member));
    expect(tomorrow.body).toMatchObject({ coins: 500, balance: before + 1000 });
  });
  it('profile visitors: someone else opening the profile is listed for a member holding the perk', async () => {
    const owner = await signup();
    const visitor = async (u: TestUser) => {
      const res = await ctx.http.get(`/api/v1/users/${owner.username}`).set(auth(u));
      expect(res.status).toBe(200);
    };
    const list = () => ctx.http.get('/api/v1/me/profile-visitors').set(auth(owner));

    // Without the perk: refused.
    const refused = await list();
    expect(refused.status).toBe(409);
    expect(refused.body.error).toMatchObject({
      code: 'VIP_UNAVAILABLE',
      details: [{ field: 'perk', issue: 'no_perk' }],
    });

    const a = await signup();
    const b = await signup();
    const c = await signup();
    await visitor(a);
    await visitor(a); // the same visit (within 10 minutes)
    clock.advance(60);
    await visitor(b);
    await visitor(c);
    await visitor(owner); // never oneself
    // c is blocked: never listed (nor recorded again).
    await ctx.prisma.userBlock.create({ data: { blockerId: owner.id, blockedId: c.id } });
    clock.advance(11 * 60);
    await visitor(a); // a new visit, the latest

    await vip(owner);
    const res = await list();
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listProfileVisitors');
    expect(res.body.total).toBe(2);
    expect(res.body.data.map((v: { user: { id: string }; visits: number }) => [v.user.id, v.visits])).toEqual(
      [
        [a.id, 2],
        [b.id, 1],
      ],
    );
    const rows = await ctx.prisma.profileVisit.findMany({ where: { ownerId: owner.id } });
    expect(rows.map((r) => r.visitorId).sort()).toEqual([a.id, b.id, c.id].sort());
  });
});
