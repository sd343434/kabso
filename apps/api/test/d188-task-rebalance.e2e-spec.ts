/**
 * D188 (owner 2026-10-30; contract v1.57-social, CONVENTIONS §10.51): the Task Center's rewards rebalanced
 * to real money — 1 000 000 coins = $12.50 retail, 1 000 000 cherries = $1.10 payout. Gift tasks count the
 * coin value of the stored gift rows (`GIFT_COINS_SENT`; the host's gifts received by coin value), the
 * daily cap is 50 000 cherries, a calendar-month cap of $5 of task cherries covers daily and weekly tasks
 * (a claim crossing it pays the remainder, then 409 `TASK_MONTHLY_CAP_REACHED`, a new month starts again),
 * and task cherries unlock for withdrawal at $60 of lifetime gift support. End to end against PostgreSQL +
 * Redis.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { creditTaskCherriesIn } from '../src/modules/economy/cherry-ledger.js';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { seedDefaultTasksIn } from '../src/modules/programs/programs-seed.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, openapi } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

/** Real time moved by an offset (rows written by the database keep real times). */
class FakeClock extends Clock {
  private offset = 0;
  now(): Date {
    return new Date(Date.now() + this.offset);
  }
  /** From now on, `now()` starts at `at` (and moves with real time). */
  setTo(at: Date): void {
    this.offset = at.getTime() - Date.now();
  }
  advance(ms: number): void {
    this.offset += ms;
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

interface Task {
  code: string;
  period: 'DAILY' | 'WEEKLY';
  metric: string;
  target: number;
  progress: number;
  completed: boolean;
  claimed: boolean;
  rewardCherries: number;
  claimedCherries: number | null;
}

interface MyTasks {
  day: string;
  dailyCapCherries: number;
  dailyEarnedCherries: number;
  monthlyCapCherries: number;
  monthlyEarnedCherries: number;
  tasks: Task[];
}

const HOUR_MS = 3_600_000;
const DAY_MS = 24 * HOUR_MS;

/** A fixed-offset zone where it is about noon now, so "today" never ends in the middle of a test. */
function noonZone(): string {
  const offset = 12 - new Date().getUTCHours();
  if (offset === 0) return 'Etc/GMT';
  return offset > 0 ? `Etc/GMT-${String(offset)}` : `Etc/GMT+${String(-offset)}`;
}

describe('D188 contract coverage', () => {
  it('openapi v1.57-social declares GIFT_COINS_SENT and the monthly cap', () => {
    const schemas = (openapi.components as { schemas: Record<string, Record<string, unknown>> }).schemas;
    const task = schemas.ProgramTask as { properties: Record<string, { enum?: string[] }> };
    expect(task.properties.metric!.enum).toContain('GIFT_COINS_SENT');
    expect((schemas.MyTasks as { required: string[] }).required).toEqual(
      expect.arrayContaining(['monthlyCapCherries', 'monthlyEarnedCherries']),
    );
  });
});

/** Shared helpers over one test app. */
function helpers(get: () => TestContext) {
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(get());
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
    };
  };
  const tasks = async (u: TestUser): Promise<MyTasks> => {
    const res = await get().http.get('/api/v1/me/tasks').set(auth(u)).set('Accept-Language', 'en');
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getMyTasks');
    return res.body as MyTasks;
  };
  const task = async (u: TestUser, code: string) => (await tasks(u)).tasks.find((t) => t.code === code)!;
  const claim = async (u: TestUser, code: string) => {
    const res = await get().http.post(`/api/v1/me/tasks/${code}/claim`).set(auth(u));
    expectContract(res, 'claimMyTask');
    return res;
  };
  return { auth, signup, tasks, task, claim };
}

describe('D188 coin-value gift tasks, the defaults and the $60 unlock', { timeout: 240_000 }, () => {
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  const { auth, signup, tasks, task, claim } = helpers(() => ctx);

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
  const startLive = async (host: TestUser) => {
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(host)).send({ title: 'Rebalance' });
    expect(room.status, JSON.stringify(room.body)).toBe(201);
    return room.body.id as string;
  };
  const send = async (roomId: string, from: TestUser, to: TestUser, giftCode: string) => {
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(from))
      .send({ giftCode, quantity: 1, recipients: [to.username], source: 'COINS', clientId: randomUUID() });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
  };
  const gift = (code: string, priceCoins: number, sortOrder: number) =>
    ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, code, {
        category: 'POPULAR',
        nameAr: code,
        nameEn: code,
        priceCoins,
        assetKey: `gift_${code}`,
        animationKey: null,
        sortOrder,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      }),
    );
  /** Gift cherries as a gift send stores them (a GIFT_RECEIVED row with the balance). */
  const giftCherries = (u: TestUser, cherries: bigint) =>
    ctx.prisma.$transaction(async (tx) => {
      const w = await tx.cherryWallet.upsert({
        where: { userId: u.id },
        create: { userId: u.id, cherries },
        update: { cherries: { increment: cherries } },
      });
      await tx.cherryLedgerEntry.create({
        data: {
          userId: u.id,
          delta: cherries,
          balanceAfter: w.cherries,
          reason: 'GIFT_RECEIVED',
          referenceId: randomUUID(),
        },
      });
    });
  const wallet = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/wallet/me/cherries').set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getMyCherries');
    return res.body as {
      cherries: number;
      lockedTaskCherries: number;
      withdrawableCherries: number;
      taskUnlock: { unlocked: boolean; giftValueMinor: number; thresholdMinor: number };
    };
  };

  beforeAll(async () => {
    // The owner's defaults (no cap, rate or unlock override).
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        LIVE_RANKINGS_TIME_ZONE: noonZone(),
      },
      [{ token: LIVE_MEDIA_PROVIDER, value: media }],
    );
    await gift('r188_rose', 10, 0);
    await gift('r188_gem', 5_000, 1);
    expect(await seedDefaultTasksIn(ctx.prisma)).toBe(6);
  });
  afterAll(async () => ctx?.close());

  it('the defaults: 50 000 a day, $5 a month (4 545 454 cherries), gifts by coin value, the host tasks', async () => {
    const me = await signup();
    const mine = await tasks(me);
    expect(mine).toMatchObject({
      dailyCapCherries: 50_000,
      dailyEarnedCherries: 0,
      monthlyCapCherries: 4_545_454,
      monthlyEarnedCherries: 0,
    });
    expect(mine.tasks.find((t) => t.code === 'SEND_GIFTS')).toMatchObject({
      metric: 'GIFT_COINS_SENT',
      target: 10_000,
      rewardCherries: 1_000,
    });
    const host = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    const weekly = (await tasks(host)).tasks.filter((t) => t.period === 'WEEKLY');
    expect(weekly.map((t) => [t.code, t.metric, t.target, t.rewardCherries])).toEqual([
      ['HOST_LIVE_MINUTES', 'HOST_LIVE_MINUTES', 600, 30_000],
      ['HOST_GIFT_COINS', 'HOST_GIFT_COINS', 5_000_000, 50_000],
    ]);
  });

  it('«send gifts» and «gifts received» count the coin value of the stored gifts, ACTIVE counterparts only', async () => {
    const fan = await signup();
    const host = await signup();
    const other = await signup();
    await creditIn(ctx.prisma, fan.id, 20_000n, 'ADMIN_GRANT', randomUUID());
    const room = await startLive(host);
    const room2 = await startLive(other);
    await join(room, fan);
    await join(room2, fan);

    // One cheap gift: one send, but 10 coins of 10 000 (a count would have been enough before D188).
    await send(room, fan, host, 'r188_rose');
    expect(await task(fan, 'SEND_GIFTS')).toMatchObject({ progress: 10, completed: false });
    expect((await claim(fan, 'SEND_GIFTS')).body.error.code).toBe('TASK_NOT_COMPLETED');

    // 5 000 coins to another host count while that host is ACTIVE, not after a suspension.
    await send(room2, fan, other, 'r188_gem');
    expect(await task(fan, 'SEND_GIFTS')).toMatchObject({ progress: 5_010 });
    await ctx.prisma.user.update({ where: { id: other.id }, data: { status: 'SUSPENDED' } });
    expect(await task(fan, 'SEND_GIFTS')).toMatchObject({ progress: 10 });

    await send(room, fan, host, 'r188_gem');
    await send(room, fan, host, 'r188_gem');
    // The stored rows: 10 010 coins to the ACTIVE host (5 000 more to the suspended one).
    const stored = await ctx.prisma.liveGiftRecipient.aggregate({
      where: { gift: { senderId: fan.id }, userId: host.id },
      _sum: { coins: true },
    });
    expect(stored._sum.coins).toBe(10_010n);
    expect(await task(fan, 'SEND_GIFTS')).toMatchObject({
      progress: 10_000,
      target: 10_000,
      completed: true,
    });
    const paid = await claim(fan, 'SEND_GIFTS');
    expect(paid.status, JSON.stringify(paid.body)).toBe(201);
    expect(paid.body).toMatchObject({ paidCherries: 1_000, paidCoins: 0 });
    expect(await tasks(fan)).toMatchObject({ dailyEarnedCherries: 1_000, monthlyEarnedCherries: 1_000 });

    // The host's weekly «gifts received» is the coin value received from ACTIVE senders.
    expect(await task(host, 'HOST_GIFT_COINS')).toMatchObject({
      metric: 'HOST_GIFT_COINS',
      progress: 10_010,
      target: 5_000_000,
      completed: false,
    });
    await ctx.prisma.user.update({ where: { id: fan.id }, data: { status: 'SUSPENDED' } });
    expect(await task(host, 'HOST_GIFT_COINS')).toMatchObject({ progress: 0 });
  });

  it('task cherries unlock for withdrawal at $60 of lifetime gift support (was $50)', async () => {
    const me = await signup();
    const day = (await tasks(me)).day;
    await ctx.prisma.$transaction((tx) =>
      creditTaskCherriesIn(tx, me.id, 1_000n, `SEND_GIFTS@${day}`, new Date()),
    );
    // $50 at $1.10 per 1 000 000 (45 454 546 cherries): enough before D188, locked now.
    await giftCherries(me, 45_454_546n);
    expect(await wallet(me)).toMatchObject({
      lockedTaskCherries: 1_000,
      withdrawableCherries: 45_454_546,
      taskUnlock: { unlocked: false, giftValueMinor: 5000, thresholdMinor: 6000 },
    });
    // 54 545 454 cherries are worth $59.99 (floored): still locked; one more cherry makes $60.00.
    await giftCherries(me, 9_090_908n);
    expect((await wallet(me)).taskUnlock).toEqual({
      unlocked: false,
      giftValueMinor: 5999,
      thresholdMinor: 6000,
    });
    await giftCherries(me, 1n);
    expect(await wallet(me)).toMatchObject({
      cherries: 54_546_455,
      lockedTaskCherries: 0,
      withdrawableCherries: 54_546_455,
      taskUnlock: { unlocked: true, giftValueMinor: 6000, thresholdMinor: 6000 },
    });
  });
});

describe('D188 the monthly cap of task cherries', { timeout: 240_000 }, () => {
  const clock = new FakeClock();
  let ctx: TestContext;
  const { signup, tasks, claim } = helpers(() => ctx);
  let people: TestUser[] = [];

  /** `me` followed someone new at the programs' "now" (as the follow endpoint stores it). */
  const followNow = async (me: TestUser) => {
    const followee = people.shift()!;
    await ctx.prisma.follow.create({
      data: { followerId: me.id, followeeId: followee.id, createdAt: clock.now() },
    });
  };

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        // Riyadh time (UTC+3, the production zone); the monthly cap $0.01 → 9 090 cherries at $1.10 / 1M.
        LIVE_RANKINGS_TIME_ZONE: 'Asia/Riyadh',
        TASK_MONTHLY_CAP_MINOR: '1',
      },
      [{ token: Clock, value: clock }],
    );
    expect(await seedDefaultTasksIn(ctx.prisma)).toBe(6);
    // The team's settings for this test (task-admin set): one follow a day pays 4 000; a weekly task too.
    await ctx.prisma.taskDefinition.update({
      where: { code: 'FOLLOW_USERS' },
      data: { target: 1, rewardCherries: 4_000 },
    });
    await ctx.prisma.taskDefinition.create({
      data: {
        code: 'W188_FOLLOW',
        period: 'WEEKLY',
        metric: 'FOLLOWS',
        target: 1,
        rewardCherries: 4_000,
        audience: 'EVERYONE',
        nameAr: 'تابع أحداً هذا الأسبوع',
        nameEn: 'Follow someone this week',
        sortOrder: 900,
      },
    });
    for (let i = 0; i < 4; i++) people.push(await signup());
    people = [...people];
  });
  afterAll(async () => ctx?.close());

  it('a claim crossing the cap pays the remainder (weekly tasks count too), then 409; a new month resets it', async () => {
    const me = await signup();
    // Noon (Riyadh) three days before the next month starts there.
    const local = new Date(Date.now() + 3 * HOUR_MS);
    const nextMonth = Date.UTC(local.getUTCFullYear(), local.getUTCMonth() + 1, 1) - 3 * HOUR_MS;
    clock.setTo(new Date(nextMonth - 3 * DAY_MS + 12 * HOUR_MS));

    const first = await tasks(me);
    expect(first).toMatchObject({ monthlyCapCherries: 9_090, monthlyEarnedCherries: 0 });
    // Day 1 and day 2: 4 000 each (daily cap 50 000 not reached).
    for (const earned of [4_000, 8_000]) {
      await followNow(me);
      const res = await claim(me, 'FOLLOW_USERS');
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      expect(res.body.paidCherries).toBe(4_000);
      expect((await tasks(me)).monthlyEarnedCherries).toBe(earned);
      clock.advance(DAY_MS);
    }

    // Day 3 (the month's last day): the weekly task crosses the cap — it pays the 1 090 left.
    await followNow(me);
    const weekly = await claim(me, 'W188_FOLLOW');
    expect(weekly.status, JSON.stringify(weekly.body)).toBe(201);
    expect(weekly.body).toMatchObject({
      paidCherries: 1_090,
      balanceCherries: 9_090,
      task: { code: 'W188_FOLLOW', period: 'WEEKLY', rewardCherries: 4_000, claimedCherries: 1_090 },
    });
    // Then every claim is refused (a daily task here), nothing paid.
    const refused = await claim(me, 'FOLLOW_USERS');
    expect(refused.status).toBe(409);
    expect(refused.body.error.code).toBe('TASK_MONTHLY_CAP_REACHED');
    expect(await tasks(me)).toMatchObject({
      monthlyCapCherries: 9_090,
      monthlyEarnedCherries: 9_090,
      dailyEarnedCherries: 0,
    });
    expect(
      await ctx.prisma.cherryLedgerEntry.aggregate({
        where: { userId: me.id, reason: 'TASK_REWARD' },
        _sum: { delta: true },
      }),
    ).toEqual({ _sum: { delta: 9_090n } });

    // The next calendar month (Riyadh): the cap starts again.
    clock.advance(DAY_MS);
    const next = await tasks(me);
    expect(next.monthlyEarnedCherries).toBe(0);
    await followNow(me);
    const fresh = await claim(me, 'FOLLOW_USERS');
    expect(fresh.status, JSON.stringify(fresh.body)).toBe(201);
    expect(fresh.body.paidCherries).toBe(4_000);
    expect((await tasks(me)).monthlyEarnedCherries).toBe(4_000);
  });
});
