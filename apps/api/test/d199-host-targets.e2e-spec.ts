/**
 * D199 (v1.44-live, CONVENTIONS §10.62): the host's «تارجت» — `getLiveHostTargets` (public, today only) and
 * `getMyHostGiftStats` (the caller's own, by period) on seeded gifts and lucky gifts, the new daily host task
 * «استقبل هدايا الحظ» (band values, progress, the reached state) and the unchanged caps. Time is a FakeClock
 * (the rankings' days; UTC in tests); lucky draws come from a scripted RNG.
 *
 * D277 (v1.69-live, owner): both targets in CHERRIES — «هدف الهدايا» (`gifts`, the deprecated `cherries` the
 * same) counts the cherries of gifts outside the lucky category from other people; «هدف هدايا الحظ» the
 * cherries of lucky gifts, the host's own sends to themself included. The supporters lists never hold the host.
 */
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { addGiftIn, type GiftFields } from '../src/modules/gifts/gift-catalogue.js';
import type { LuckyRng } from '../src/modules/gifts/lucky-odds.js';
import { LUCKY_RNG } from '../src/modules/gifts/lucky-rng.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { seedDefaultTaskPoolIn, seedDefaultTasksIn } from '../src/modules/programs/programs-seed.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { keepLegacyTargetsEngine } from './helpers/d281.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

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
    // D281: these rules are the engine before the smart targets and tasks (the switch day and before).
    await keepLegacyTargetsEngine(ctx.prisma);
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
    // D277: «هدف الهدايا» — the four roses (4 × 100 coins × 65 % × 10 = 2 600 cherries), never the lucky
    // gifts; P_HOST_GIFTS band 1 is stored in cherries (D188's 100 000 coins × 10 × 65 %). «هدف هدايا الحظ» —
    // the seven lucky gifts' cherries (7 × 10 coins × 10 % × 10 = 70); HOST_LUCKY_COINS band 1: 20 000 cherries.
    expect(res.body).toMatchObject({
      day: '2027-01-13',
      band: 1,
      gifts: { received: 2_600, target: 650_000, reached: false },
      lucky: { received: 70, target: 20_000, reached: false },
    });
    // The deprecated `cherries` is `gifts`, for older apps.
    expect(res.body.cherries).toEqual(res.body.gifts);
    const ledger = await ctx.prisma.cherryLedgerEntry.aggregate({
      where: { userId: host.id, reason: 'GIFT_RECEIVED' },
      _sum: { delta: true },
    });
    expect(Number(ledger._sum.delta)).toBe(2_600 + 70);
    expect(res.body.topSupporters.map((s: { user: { id: string } }) => s.user.id)).toEqual([
      fan1.id,
      fan2.id,
    ]);
    // D277: the gifts list counts gifts outside the lucky category only.
    expect(res.body.topSupporters.map((s: { coins: number }) => s.coins)).toEqual([300, 100]);
    // D199b: each row's cherries (the ledger of their sends) add up to the day's; the support level; the
    // lucky list by coins; the end of the day; no own place for a guest.
    const rows = res.body.topSupporters as { cherries: number; supportLevel: number | null }[];
    expect(rows[0]!.cherries).toBeGreaterThan(rows[1]!.cherries);
    expect(rows.reduce((a, r) => a + r.cherries, 0)).toBe(res.body.gifts.received);
    for (const r of rows) expect(r.supportLevel === null || r.supportLevel >= 1).toBe(true);
    expect(res.body.luckySupporters.map((s: { user: { id: string } }) => s.user.id)).toEqual([
      fan2.id,
      fan1.id,
    ]);
    expect(res.body.luckySupporters.map((s: { coins: number }) => s.coins)).toEqual([50, 20]);
    // The end of the day in the tests' zone (UTC).
    expect(res.body.endsAt).toBe('2027-01-14T00:00:00.000Z');
    expect(res.body.me).toBeNull();
    // A signed-in viewer sees the same lists and their own place in each.
    const fan = await targets(fan1);
    expectContract(fan, 'getLiveHostTargets');
    const { me, ...rest } = fan.body as { me: unknown };
    expect({ ...rest, me: null }).toEqual(res.body);
    expect(me).toEqual({
      gifts: { rank: 1, amount: rows[0]!.cherries },
      cherries: { rank: 1, amount: rows[0]!.cherries },
      lucky: { rank: 2, amount: 20 },
    });
    // Someone who sent nothing: no rank; the host: no own place.
    const stranger = await signup();
    expect((await targets(stranger)).body.me).toEqual({
      gifts: { rank: null, amount: 0 },
      cherries: { rank: null, amount: 0 },
      lucky: { rank: null, amount: 0 },
    });
    expect((await targets(host)).body.me).toBeNull();
  });

  it('404 for a non-host, an unknown name and a block either way', async () => {
    expect((await targets(null, fan1.username)).status).toBe(404);
    expect((await targets(null, 'no_such_user_zz')).status).toBe(404);
    const blocker = await signup();
    await ctx.prisma.userBlock.create({ data: { blockerId: host.id, blockedId: blocker.id } });
    expect((await targets(blocker)).status).toBe(404);
  });

  it("the host's own statistics by period (DAY / WEEK / MONTH / ALL) with the bar series", async () => {
    // D277: the cherries side is «هدف الهدايا»'s (the four roses); lucky adds its cherries.
    const expected = {
      cherries: { received: 2_600, gifts: 4, givers: 2 },
      lucky: { coins: 70, cherries: 70, gifts: 7, givers: 2 },
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
    expect((await stats(host, 'MONTH')).body.cherries.gifts).toBe(4);
    expect((await targets(null)).body.lucky.received).toBe(0);
    clock.advance(-24 * 3600);
  });

  it('the task «استقبل هدايا الحظ»: a daily host task per band, its progress, the reached state; caps unchanged', async () => {
    const res = await ctx.http.get('/api/v1/me/tasks').set(auth(host));
    expect(res.status).toBe(200);
    const task = (res.body.tasks as { code: string }[]).find((t) => t.code === 'HOST_LUCKY_COINS');
    // D277: «هدف هدايا الحظ», in cherries.
    expect(task).toMatchObject({
      code: 'HOST_LUCKY_COINS',
      metric: 'HOST_LUCKY_CHERRIES',
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

  it('D277: a self-sent lucky gift counts toward the lucky target; self-sends and lucky gifts stay out of «هدف الهدايا»', async () => {
    await ctx.prisma.taskDefinition.update({
      where: { code: 'HOST_LUCKY_COINS' },
      data: { enabled: true, bandTargets: [20_000, 50_000, 100_000, 200_000] },
    });
    const before = (await targets(null)).body as { gifts: { received: number }; lucky: { received: number } };
    expect([before.gifts.received, before.lucky.received]).toEqual([2_600, 70]);
    // The host may gift themself (D128), a lucky gift too (same gates: coins, 18+, region).
    await ctx.prisma.$transaction((tx) => creditIn(tx, host.id, 1_000_000n, 'ADMIN_GRANT', randomUUID()));
    const age = await ctx.http
      .put('/api/v1/me/lucky-gifts/age-confirmation')
      .set(auth(host))
      .send({ adult: true });
    expect(age.status).toBe(200);
    for (let i = 0; i < 3; i++) await send(host, lucky);
    // A rose to themself: not «هدف الهدايا» (from other people only), not lucky.
    await send(host, rose);
    // fan1: a FUN gift of 7 coins — 7 × 65 % × 10 = 45.5 → the ledger credits 45 (floored per send).
    const fun = await gift({ category: 'FUN', priceCoins: 7 });
    await send(fan1, fun);
    const res = await targets(fan1);
    expect(res.status).toBe(200);
    expectContract(res, 'getLiveHostTargets');
    expect(res.body.gifts).toEqual({ received: 2_645, target: 650_000, reached: false });
    expect(res.body.lucky).toEqual({ received: 100, target: 20_000, reached: false });
    // Exact: the host's ledger holds every send's credit (the self-sends too: 3 × 10 + 650).
    const ledger = await ctx.prisma.cherryLedgerEntry.aggregate({
      where: { userId: host.id, reason: { in: ['GIFT_RECEIVED', 'GIFT_REVERSAL'] } },
      _sum: { delta: true },
    });
    expect(Number(ledger._sum.delta)).toBe(2_645 + 100 + 650);
    // The supporters lists rank other people only (never the host), the gifts list by non-lucky cherries.
    const ids = (list: { user: { id: string } }[]) => list.map((x) => x.user.id);
    expect(ids(res.body.topSupporters)).toEqual([fan1.id, fan2.id]);
    expect(
      res.body.topSupporters.map((x: { coins: number; cherries: number }) => [x.coins, x.cherries]),
    ).toEqual([
      [307, 1_995],
      [100, 650],
    ]);
    expect(ids(res.body.luckySupporters)).toEqual([fan2.id, fan1.id]);
    expect(res.body.me.gifts).toEqual({ rank: 1, amount: 1_995 });
    // The host's own stats agree (lucky cherries with the self-sends; the lucky list without the host).
    const day = (await stats(host, 'DAY')).body;
    expect(day.cherries).toMatchObject({ received: 2_645, gifts: 5, givers: 2 });
    expect(day.lucky).toMatchObject({ coins: 70, cherries: 100, gifts: 7, givers: 2 });
    expect(ids(day.lucky.topSupporters)).toEqual([fan2.id, fan1.id]);

    // The Task Center counts the same cherries: the lucky task, and «هدف الهدايا» (today's offer added
    // when the host's band did not draw it).
    const today = new Date('2027-01-13T00:00:00.000Z');
    await ctx.prisma.taskAssignment.upsert({
      where: { userId_day_taskCode: { userId: host.id, day: today, taskCode: 'P_HOST_GIFTS' } },
      create: {
        userId: host.id,
        day: today,
        taskCode: 'P_HOST_GIFTS',
        band: 1,
        target: 650_000,
        rewardCherries: 10_000,
        position: 9,
      },
      update: {},
    });
    const taskOf = async (code: string) =>
      ((await ctx.http.get('/api/v1/me/tasks').set(auth(host))).body.tasks as { code: string }[]).find(
        (t) => t.code === code,
      ) as { progress: number; target: number; completed: boolean; metric: string } | undefined;
    expect(await taskOf('HOST_LUCKY_COINS')).toMatchObject({ progress: 100, completed: false });
    expect(await taskOf('P_HOST_GIFTS')).toMatchObject({
      metric: 'HOST_GIFT_CHERRIES',
      progress: 2_645,
      target: 650_000,
      completed: false,
    });

    // Reached exactly at the cherry amounts.
    const setBand1 = async (code: string, target: number) => {
      const def = await ctx.prisma.taskDefinition.findUniqueOrThrow({ where: { code } });
      await ctx.prisma.taskDefinition.update({
        where: { code },
        data: { bandTargets: [target, ...def.bandTargets.slice(1)] },
      });
    };
    await setBand1('HOST_LUCKY_COINS', 101);
    await setBand1('P_HOST_GIFTS', 2_646);
    let now = (await targets(null)).body;
    expect([now.gifts.reached, now.lucky.reached]).toEqual([false, false]);
    await setBand1('HOST_LUCKY_COINS', 100);
    await setBand1('P_HOST_GIFTS', 2_645);
    now = (await targets(null)).body;
    expect(now.gifts).toEqual({ received: 2_645, target: 2_645, reached: true });
    expect(now.lucky).toEqual({ received: 100, target: 100, reached: true });
    expect(now.cherries).toEqual(now.gifts);
    expect(await taskOf('HOST_LUCKY_COINS')).toMatchObject({ progress: 100, target: 100, completed: true });
    await ctx.prisma.taskAssignment.update({
      where: { userId_day_taskCode: { userId: host.id, day: today, taskCode: 'P_HOST_GIFTS' } },
      data: { target: 2_645 },
    });
    expect(await taskOf('P_HOST_GIFTS')).toMatchObject({ progress: 2_645, completed: true });
  });

  it('D277: migration 20270311090000 stores both targets in cherries (coins × 10 × 65 %, lucky × 10 × 10 %)', async () => {
    const day = new Date('2027-01-13T00:00:00.000Z');
    // Back to the D188 / D199 rows (coins) and an offer of the day in coins.
    await ctx.prisma.taskDefinition.update({
      where: { code: 'P_HOST_GIFTS' },
      data: {
        metric: 'HOST_GIFT_COINS',
        bandTargets: [100_000, 250_000, 500_000, 1_000_000],
        target: 1_000_000,
        nameAr: 'استقبل هدايا في بثك (بالعملات)',
        nameEn: 'Receive gifts in your live (coins)',
      },
    });
    await ctx.prisma.taskDefinition.update({
      where: { code: 'HOST_LUCKY_COINS' },
      data: { metric: 'HOST_LUCKY_COINS', bandTargets: [20_000, 50_000, 100_000, 200_000], target: 200_000 },
    });
    await ctx.prisma.taskAssignment.update({
      where: { userId_day_taskCode: { userId: host.id, day, taskCode: 'P_HOST_GIFTS' } },
      data: { target: 100_000 },
    });
    const sql = readFileSync(
      new URL('../prisma/migrations/20270313090000_host_targets_cherries/migration.sql', import.meta.url),
      'utf8',
    );
    const statements = sql
      .split('\n')
      .filter((line) => !line.trimStart().startsWith('--'))
      .join('\n')
      .split(';')
      .map((x) => x.trim())
      .filter((x) => x.length > 0)
      // D281: a later migration (20270315090100) widened the metrics CHECK; the old one would refuse its rows.
      .filter((x) => !x.startsWith('ALTER TABLE "task_definitions"'));
    await withMigrationClient(async (db) => {
      for (const st of statements) await db.$executeRawUnsafe(st);
      // Once only: a second run changes nothing.
      for (const st of statements) await db.$executeRawUnsafe(st);
    });
    const defs = await ctx.prisma.taskDefinition.findMany({
      where: { code: { in: ['P_HOST_GIFTS', 'HOST_LUCKY_COINS'] } },
      orderBy: { code: 'asc' },
      select: { code: true, metric: true, bandTargets: true, target: true, nameAr: true, nameEn: true },
    });
    expect(defs).toEqual([
      {
        code: 'HOST_LUCKY_COINS',
        metric: 'HOST_LUCKY_CHERRIES',
        bandTargets: [20_000, 50_000, 100_000, 200_000],
        target: 200_000,
        nameAr: 'هدف هدايا الحظ (بالكرز)',
        nameEn: 'Lucky gifts target (cherries)',
      },
      {
        code: 'P_HOST_GIFTS',
        metric: 'HOST_GIFT_CHERRIES',
        bandTargets: [650_000, 1_625_000, 3_250_000, 6_500_000],
        target: 6_500_000,
        nameAr: 'هدف الهدايا (بالكرز)',
        nameEn: 'Gifts target (cherries)',
      },
    ]);
    const offer = await ctx.prisma.taskAssignment.findUniqueOrThrow({
      where: { userId_day_taskCode: { userId: host.id, day, taskCode: 'P_HOST_GIFTS' } },
    });
    expect(offer.target).toBe(650_000);
    expect((await targets(null)).body.gifts).toMatchObject({ received: 2_645, target: 650_000 });
  });
});
