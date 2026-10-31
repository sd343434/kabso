/**
 * D199 (v1.44-live, CONVENTIONS §10.62): the host's «تارجت» — `getLiveHostTargets` (public, today only) and
 * `getMyHostGiftStats` (the caller's own, by period) on seeded gifts and lucky gifts, the new daily host task
 * «استقبل هدايا الحظ» (band values, progress, the reached state) and the unchanged caps. Time is a FakeClock
 * (the rankings' days; UTC in tests); lucky draws come from a scripted RNG.
 */
import { randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { addGiftIn, type GiftFields } from '../src/modules/gifts/gift-catalogue.js';
import type { LuckyRng } from '../src/modules/gifts/lucky-odds.js';
import { LUCKY_RNG } from '../src/modules/gifts/lucky-rng.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { seedDefaultTaskPoolIn, seedDefaultTasksIn } from '../src/modules/programs/programs-seed.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

class FakeClock extends Clock {
  // 10:00 in Riyadh on a Wednesday, mid-month: the day, week and month windows hold every send.
  private ms = Date.parse('2027-01-13T07:00:00.000Z');
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

describe('D199 contract coverage', () => {
  it('openapi v1.44-live declares the target operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain('getLiveHostTargets GET /api/v1/live/hosts/{username}/targets');
    expect(ids).toContain('getMyHostGiftStats GET /api/v1/me/host-gift-stats');
  });
});

describe('D199 host targets and statistics', { timeout: 300_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  const rng: LuckyRng = { int: () => 999_999 };
  let ctx: TestContext;
  let seq = 0;
  let host: TestUser;
  let fan1: TestUser;
  let fan2: TestUser;
  let room: string;
  let rose: string;
  let lucky: string;

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
  const gift = async (fields: Partial<GiftFields>): Promise<string> => {
    seq += 1;
    const code = `t${String(seq)}_${randomUUID().slice(0, 6)}`;
    await ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, code, {
        category: 'POPULAR',
        nameAr: `هدية ${String(seq)}`,
        nameEn: `Gift ${String(seq)}`,
        priceCoins: 100,
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
  const send = async (u: TestUser, code: string) => {
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${room}/gifts`)
      .set(auth(u))
      .set('CF-IPCountry', 'SA')
      .send({
        giftCode: code,
        quantity: 1,
        recipients: [host.username],
        source: 'COINS',
        clientId: randomUUID(),
      });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
  };
  const targets = (who: TestUser | null, username = host.username): request.Test => {
    const req = ctx.http.get(`/api/v1/live/hosts/${username}/targets`);
    if (who) void req.set(auth(who));
    return req;
  };
  const stats = (who: TestUser, period?: string): request.Test =>
    ctx.http
      .get('/api/v1/me/host-gift-stats')
      .query(period ? { period } : {})
      .set(auth(who));

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        LUCKY_GIFTS_ENABLED: 'true',
        LUCKY_GIFTS_COUNTRY_HEADER: 'CF-IPCountry',
        LUCKY_PITY_AFTER: '0',
      },
      [
        { token: Clock, value: clock },
        { token: LIVE_MEDIA_PROVIDER, value: media },
        { token: LUCKY_RNG, value: rng },
      ],
    );
    await seedDefaultTasksIn(ctx.prisma);
    await seedDefaultTaskPoolIn(ctx.prisma);
    host = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    [fan1, fan2] = [await signup(), await signup()];
    for (const u of [fan1, fan2]) {
      await ctx.prisma.$transaction((tx) => creditIn(tx, u.id, 1_000_000n, 'ADMIN_GRANT', randomUUID()));
      const age = await ctx.http
        .put('/api/v1/me/lucky-gifts/age-confirmation')
        .set(auth(u))
        .send({ adult: true });
      expect(age.status).toBe(200);
    }
    const res = await ctx.http.post('/api/v1/live/rooms').set(auth(host)).send({ title: 'Targets' });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    room = res.body.id as string;
    for (const u of [fan1, fan2]) await join(room, u);
    rose = await gift({ priceCoins: 100 });
    lucky = await gift({ category: 'LUCKY', priceCoins: 10 });
    // fan1: 3 roses (300) + 2 lucky (20); fan2: 1 rose (100) + 5 lucky (50).
    for (let i = 0; i < 3; i++) await send(fan1, rose);
    for (let i = 0; i < 2; i++) await send(fan1, lucky);
    await send(fan2, rose);
    for (let i = 0; i < 5; i++) await send(fan2, lucky);
  });
  afterAll(async () => ctx?.close());

  it("today's targets are public (guests too): cherries and lucky progress, band 1 targets, top three", async () => {
    const res = await targets(null);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getLiveHostTargets');
    const ledger = await ctx.prisma.cherryLedgerEntry.aggregate({
      where: { userId: host.id, reason: 'GIFT_RECEIVED' },
      _sum: { delta: true },
    });
    expect(res.body).toMatchObject({
      day: '2027-01-13',
      band: 1,
      // P_HOST_GIFTS band 1: 100 000 coins × 10 cherries × 65 %.
      cherries: { received: Number(ledger._sum.delta), target: 650_000, reached: false },
      lucky: { received: 70, target: 20_000, reached: false },
    });
    expect(res.body.cherries.received).toBeGreaterThan(0);
    expect(res.body.topSupporters.map((s: { user: { id: string } }) => s.user.id)).toEqual([
      fan1.id,
      fan2.id,
    ]);
    expect(res.body.topSupporters.map((s: { coins: number }) => s.coins)).toEqual([320, 150]);
    // Viewers signed in see the same (today only).
    expect((await targets(fan1)).body).toEqual(res.body);
  });

  it('404 for a non-host, an unknown name and a block either way', async () => {
    expect((await targets(null, fan1.username)).status).toBe(404);
    expect((await targets(null, 'no_such_user_zz')).status).toBe(404);
    const blocker = await signup();
    await ctx.prisma.userBlock.create({ data: { blockerId: host.id, blockedId: blocker.id } });
    expect((await targets(blocker)).status).toBe(404);
  });

  it("the host's own statistics by period (DAY / WEEK / MONTH / ALL) with the bar series", async () => {
    const expected = {
      cherries: { gifts: 11, givers: 2 },
      lucky: { coins: 70, gifts: 7, givers: 2 },
    };
    const lengths: Record<string, number | null> = { DAY: 24, WEEK: 7, MONTH: 31, ALL: 12 };
    for (const period of ['DAY', 'WEEK', 'MONTH', 'ALL']) {
      const res = await stats(host, period);
      expect(res.status, period).toBe(200);
      expectContract(res, 'getMyHostGiftStats');
      expect(res.body).toMatchObject({ period, ...expected });
      expect(res.body.cherries.series).toHaveLength(lengths[period]!);
      const sum = res.body.cherries.series.reduce((a: number, b: { cherries: number }) => a + b.cherries, 0);
      expect(sum, period).toBe(res.body.cherries.received);
      expect(res.body.lucky.topSupporters.map((s: { coins: number }) => s.coins)).toEqual([50, 20]);
      expect(res.body.targets === null).toBe(period !== 'DAY');
      expect(res.body.from === null).toBe(period === 'ALL');
    }
    expect((await stats(host)).body.period).toBe('DAY');
    expect((await stats(host, 'YEAR')).status).toBe(400);
    expect((await ctx.http.get('/api/v1/me/host-gift-stats')).status).toBe(401);
    // A viewer only ever reads their own (nothing received here).
    const mine = await stats(fan1, 'ALL');
    expect(mine.body).toMatchObject({ cherries: { received: 0, gifts: 0 }, lucky: { coins: 0 } });
  });

  it('a new day: DAY starts again, the month keeps it', async () => {
    clock.advance(24 * 3600);
    expect((await stats(host, 'DAY')).body.cherries).toMatchObject({ received: 0, gifts: 0 });
    expect((await stats(host, 'MONTH')).body.cherries.gifts).toBe(11);
    expect((await targets(null)).body.lucky.received).toBe(0);
    clock.advance(-24 * 3600);
  });

  it('the task «استقبل هدايا الحظ»: a daily host task per band, its progress, the reached state; caps unchanged', async () => {
    const res = await ctx.http.get('/api/v1/me/tasks').set(auth(host));
    expect(res.status).toBe(200);
    const task = (res.body.tasks as { code: string }[]).find((t) => t.code === 'HOST_LUCKY_COINS');
    expect(task).toMatchObject({
      code: 'HOST_LUCKY_COINS',
      target: 20_000,
      rewardCherries: 1_000,
      progress: 70,
    });
    expect(res.body.dailyCapCherries).toBe(50_000);
    const viewer = await ctx.http.get('/api/v1/me/tasks').set(auth(fan1));
    expect((viewer.body.tasks as { code: string }[]).some((t) => t.code === 'HOST_LUCKY_COINS')).toBe(false);
    // An owner who lowers the band target: reached.
    await ctx.prisma.taskDefinition.update({
      where: { code: 'HOST_LUCKY_COINS' },
      data: { bandTargets: [60, 50_000, 100_000, 200_000] },
    });
    expect((await targets(null)).body.lucky).toEqual({ received: 70, target: 60, reached: true });
    // Switched off: no lucky target.
    await ctx.prisma.taskDefinition.update({ where: { code: 'HOST_LUCKY_COINS' }, data: { enabled: false } });
    expect((await targets(null)).body.lucky).toEqual({ received: 70, target: 0, reached: false });
  });
});
