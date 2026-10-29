/**
 * D166 (owner 2026-10-29: the Me hub's «قريباً» programs; CP-024 approved with defaults; contract
 * v1.44-social, CONVENTIONS §10.41): the Task Center (server-computed progress, one payout per period,
 * the daily cap, check-in streaks), SVIP earned from gift spending, the Event Center (lists, the live
 * leaderboard, the freeze and the one-time prize payout) and the recharge packages (no purchase) — end
 * to end against PostgreSQL + Redis.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { EventsService } from '../src/modules/programs/events.service.js';
import { seedDefaultTasksIn } from '../src/modules/programs/programs-seed.js';
import { creditIn, debitIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

/** Real time moved by an offset (rows written by the database keep real times). */
class FakeClock extends Clock {
  private offset = 0;
  now(): Date {
    return new Date(Date.now() + this.offset);
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

const HOUR_MS = 3_600_000;
const DAY_MS = 24 * HOUR_MS;
const CAP = 27;

/**
 * A fixed-offset zone where it is about noon now, so "today" never ends in the middle of a test
 * (`Etc/GMT-3` is UTC+3).
 */
function noonZone(): string {
  const offset = 12 - new Date().getUTCHours();
  if (offset === 0) return 'Etc/GMT';
  return offset > 0 ? `Etc/GMT-${String(offset)}` : `Etc/GMT+${String(-offset)}`;
}

interface Task {
  code: string;
  period: string;
  progress: number;
  target: number;
  completed: boolean;
  claimed: boolean;
  claimedCoins: number | null;
}

describe('D166 contract coverage', () => {
  it('openapi v1.44-social declares the Me hub programs', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'getMyTasks GET /api/v1/me/tasks',
        'claimMyTask POST /api/v1/me/tasks/{code}/claim',
        'checkIn POST /api/v1/me/check-in',
        'getMySvip GET /api/v1/me/svip',
        'listEvents GET /api/v1/events',
        'getEvent GET /api/v1/events/{eventId}',
        'getEventLeaderboard GET /api/v1/events/{eventId}/leaderboard',
        'listRechargePackages GET /api/v1/wallet/recharge-packages',
      ]),
    );
    // Purchases stay blocked (B5): no purchase operation exists.
    expect(ids.some((id) => /recharge-packages\/|purchase/i.test(id))).toBe(false);
  });
});

describe('D166 Me hub programs', { timeout: 240_000 }, () => {
  const media = new MemoryLiveMedia();
  const clock = new FakeClock();
  let ctx: TestContext;
  let targets: TestUser[] = [];

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
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(host)).send({ title: 'Programs' });
    expect(room.status, JSON.stringify(room.body)).toBe(201);
    return room.body.id as string;
  };
  const send = async (roomId: string, from: TestUser, to: TestUser, quantity = 1) => {
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(from))
      .send({
        giftCode: 'prog_rose',
        quantity,
        recipients: [to.username],
        source: 'COINS',
        clientId: randomUUID(),
      });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
  };
  const follow = async (a: TestUser, b: TestUser) => {
    const res = await ctx.http.put(`/api/v1/users/${b.username}/follow`).set(auth(a));
    expect(res.status).toBe(200);
  };
  const tasks = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me/tasks').set(auth(u)).set('Accept-Language', 'en');
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getMyTasks');
    return res.body as {
      day: string;
      dailyEarnedCoins: number;
      checkIn: { checkedInToday: boolean; streak: number; days: { cycleDay: number; rewardCoins: number }[] };
      tasks: Task[];
    };
  };
  const task = async (u: TestUser, code: string): Promise<Task | undefined> =>
    (await tasks(u)).tasks.find((t) => t.code === code);
  const claim = (u: TestUser, code: string) => ctx.http.post(`/api/v1/me/tasks/${code}/claim`).set(auth(u));
  const ledger = (u: TestUser, reason: string) =>
    ctx.prisma.walletLedgerEntry.findMany({ where: { userId: u.id, reason: reason as never } });
  /** Ten chat messages of `u` in someone else's live (stored like the chat endpoint stores them). */
  const chat = async (roomId: string, u: TestUser, n: number) => {
    for (let i = 0; i < n; i++) {
      await ctx.prisma.liveChatMessage.create({
        data: { roomId, userId: u.id, clientId: randomUUID(), text: `hi ${String(i)}`, authorRole: 'VIEWER' },
      });
    }
  };
  /** `u` watched `roomId` for `ms` in total (as the media server's presence records it). */
  const watch = (roomId: string, u: TestUser, ms: number) =>
    ctx.prisma.liveRoomAudience.upsert({
      where: { roomId_identity: { roomId, identity: u.id } },
      create: { roomId, identity: u.id, userId: u.id, firstJoinedAt: new Date(), watchMs: BigInt(ms) },
      update: { watchMs: BigInt(ms), openSince: null },
    });

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        LIVE_RANKINGS_TIME_ZONE: noonZone(),
        TASK_DAILY_CAP_COINS: String(CAP),
        EVENT_PRIZE_REVIEW_HOURS: '24',
      },
      [
        { token: LIVE_MEDIA_PROVIDER, value: media },
        { token: Clock, value: clock },
      ],
    );
    await ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, 'prog_rose', {
        category: 'POPULAR',
        nameAr: 'وردة',
        nameEn: 'Rose',
        priceCoins: 10,
        assetKey: 'gift_prog_rose',
        animationKey: null,
        sortOrder: 0,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      }),
    );
    // The database is emptied for the tests: the migration's default tasks again.
    expect(await seedDefaultTasksIn(ctx.prisma)).toBe(6);
    expect(await seedDefaultTasksIn(ctx.prisma)).toBe(0);
    for (let i = 0; i < 11; i++) targets.push(await signup());
    targets = [...targets];
  });
  afterAll(async () => ctx?.close());

  it('the default tasks, from stored data only; host tasks only for hosts; 401 without a session', async () => {
    const me = await signup();
    const body = await tasks(me);
    expect(body.tasks.map((t) => t.code)).toEqual(['WATCH_LIVE', 'FOLLOW_USERS', 'LIVE_CHAT', 'SEND_GIFTS']);
    expect(body.tasks.every((t) => t.progress === 0 && !t.completed && !t.claimed)).toBe(true);
    expect(body.checkIn).toMatchObject({ checkedInToday: false, streak: 0 });
    expect(body.checkIn.days.map((d) => d.cycleDay)).toEqual([1, 2, 3, 4, 5, 6, 7]);
    expect(body.checkIn.days.map((d) => d.rewardCoins)).toEqual([5, 5, 5, 5, 5, 5, 25]);
    expect(body.dailyEarnedCoins).toBe(0);
    expect((await ctx.http.get('/api/v1/me/tasks')).status).toBe(401);
    expect((await ctx.http.post('/api/v1/me/check-in')).status).toBe(401);
    expect((await ctx.http.post('/api/v1/me/tasks/FOLLOW_USERS/claim')).status).toBe(401);

    // Unknown or not-for-me codes are 404; an unfinished task is 409 and pays nothing.
    expect((await claim(me, 'NO_SUCH_TASK')).status).toBe(404);
    expect((await claim(me, 'HOST_LIVE_MINUTES')).status).toBe(404);
    const early = await claim(me, 'FOLLOW_USERS');
    expect(early.status).toBe(409);
    expect(early.body.error.code).toBe('TASK_NOT_COMPLETED');
    expect(await ledger(me, 'TASK_REWARD')).toHaveLength(0);
  });

  it('a task is paid once, even when claimed at the same time; the wallet history shows it', async () => {
    const me = await signup();
    for (const t of targets.slice(0, 10)) await follow(me, t);
    expect(await task(me, 'FOLLOW_USERS')).toMatchObject({
      progress: 10,
      target: 10,
      completed: true,
      claimed: false,
    });

    const results = await Promise.all([1, 2, 3].map(() => claim(me, 'FOLLOW_USERS')));
    expect(results.map((r) => r.status).sort()).toEqual([200, 200, 201]);
    const first = results.find((r) => r.status === 201)!;
    expectContract(first, 'claimMyTask');
    expect(first.body).toMatchObject({
      paidCoins: 5,
      balanceCoins: 5,
      task: { code: 'FOLLOW_USERS', claimed: true },
    });
    const again = await claim(me, 'FOLLOW_USERS');
    expect(again.status).toBe(200);
    expectContract(again, 'claimMyTask');
    expect(again.body).toMatchObject({ paidCoins: 5, balanceCoins: 5 });
    expect(await ledger(me, 'TASK_REWARD')).toHaveLength(1);

    const history = await ctx.http.get('/api/v1/wallet/me/ledger').set(auth(me));
    expect(history.status).toBe(200);
    expectContract(history, 'listMyWalletLedger');
    expect(history.body.data).toEqual([
      expect.objectContaining({ reason: 'TASK_REWARD', delta: 5, balanceAfter: 5 }),
    ]);
  });

  it('unfollowing before the claim, or following someone not active, does not count', async () => {
    const me = await signup();
    for (const t of targets.slice(0, 10)) await follow(me, t);
    await ctx.http.delete(`/api/v1/users/${targets[0]!.username}/follow`).set(auth(me)).expect(200);
    expect(await task(me, 'FOLLOW_USERS')).toMatchObject({ progress: 9, completed: false });
    const refused = await claim(me, 'FOLLOW_USERS');
    expect(refused.status).toBe(409);
    expect(refused.body.error.code).toBe('TASK_NOT_COMPLETED');

    // Follow again (counts again), plus an 11th person who is then suspended: still 10.
    await follow(me, targets[0]!);
    const other = await signup();
    await follow(me, other);
    await ctx.prisma.user.update({ where: { id: other.id }, data: { status: 'SUSPENDED' } });
    expect(await task(me, 'FOLLOW_USERS')).toMatchObject({ progress: 10, completed: true });
    // A suspended account cannot claim at all.
    await ctx.prisma.user.update({ where: { id: me.id }, data: { status: 'SUSPENDED' } });
    expect((await claim(me, 'FOLLOW_USERS')).status).toBe(401);
    expect(await ledger(me, 'TASK_REWARD')).toHaveLength(0);
  });

  it('check-in: once a day, the 7th day in a row adds the bonus; the daily cap stops task coins', async () => {
    const host = await signup();
    const roomId = await startLive(host);
    const me = await signup();
    await creditIn(ctx.prisma, me.id, 1000n, 'ADMIN_GRANT', randomUUID());
    const today = (await tasks(me)).day;
    // Six check-ins in a row before today (streak 1…6).
    for (let i = 6; i >= 1; i--) {
      const d = new Date(`${today}T00:00:00.000Z`);
      d.setUTCDate(d.getUTCDate() - i);
      await ctx.prisma.dailyCheckIn.create({
        data: { userId: me.id, day: d, streak: 7 - i, rewardCoins: 5 },
      });
    }
    const first = await ctx.http.post('/api/v1/me/check-in').set(auth(me));
    expect(first.status, JSON.stringify(first.body)).toBe(201);
    expectContract(first, 'checkIn');
    expect(first.body).toMatchObject({ paidCoins: 25, balanceCoins: 1025 });
    expect(first.body.tasks.checkIn).toMatchObject({ checkedInToday: true, streak: 7 });
    const second = await ctx.http.post('/api/v1/me/check-in').set(auth(me));
    expect(second.status).toBe(200);
    expect(second.body.paidCoins).toBe(25);
    expect(await ledger(me, 'CHECK_IN_REWARD')).toHaveLength(1);

    // Every daily task done: chat, a 15 s watch, follows, ten paid gift sends.
    await join(roomId, me);
    await chat(roomId, me, 10);
    await watch(roomId, me, 15_000);
    for (const t of targets.slice(0, 10)) await follow(me, t);
    for (let i = 0; i < 10; i++) await send(roomId, me, host);
    const all = await tasks(me);
    expect(all.tasks.every((t) => t.completed)).toBe(true);
    expect(all.dailyEarnedCoins).toBe(25);

    // Cap 27: 25 already → the next claim pays the 2 left, then 409.
    const capped = await claim(me, 'SEND_GIFTS');
    expect(capped.status).toBe(201);
    expect(capped.body.paidCoins).toBe(2);
    const refused = await claim(me, 'WATCH_LIVE');
    expect(refused.status).toBe(409);
    expect(refused.body.error.code).toBe('TASK_DAILY_CAP_REACHED');
    expect((await tasks(me)).dailyEarnedCoins).toBe(CAP);

    // The host's weekly tasks: gifts received (100 coins of 1 000), outside the daily cap.
    const hostTasks = await tasks(host);
    expect(hostTasks.tasks.map((t) => t.code)).toEqual(
      expect.arrayContaining(['HOST_LIVE_MINUTES', 'HOST_GIFT_COINS']),
    );
    expect(hostTasks.tasks.find((t) => t.code === 'HOST_GIFT_COINS')).toMatchObject({
      period: 'WEEKLY',
      progress: 100,
      target: 1000,
    });
  });

  it('a new day: daily tasks and the check-in reset, the streak goes on', async () => {
    const me = await signup();
    for (const t of targets.slice(0, 10)) await follow(me, t);
    expect((await ctx.http.post('/api/v1/me/check-in').set(auth(me))).status).toBe(201);
    expect((await claim(me, 'FOLLOW_USERS')).status).toBe(201);

    clock.advance(DAY_MS);
    try {
      const next = await tasks(me);
      expect(next.dailyEarnedCoins).toBe(0);
      expect(next.checkIn).toMatchObject({ checkedInToday: false, streak: 1 });
      expect(next.checkIn.days[0]).toMatchObject({ cycleDay: 2, rewardCoins: 5 });
      expect(next.tasks.find((t) => t.code === 'FOLLOW_USERS')).toMatchObject({
        progress: 0,
        claimed: false,
      });
      const again = await ctx.http.post('/api/v1/me/check-in').set(auth(me));
      expect(again.status).toBe(201);
      expect(again.body.tasks.checkIn.streak).toBe(2);
      // Yesterday's follows do not count today.
      expect((await claim(me, 'FOLLOW_USERS')).body.error.code).toBe('TASK_NOT_COMPLETED');
    } finally {
      clock.advance(-DAY_MS);
    }
  });

  it('SVIP is earned by gift spending in 30 days and lasts 30 days', async () => {
    const me = await signup();
    const empty = await ctx.http.get('/api/v1/me/svip').set(auth(me)).set('Accept-Language', 'ar');
    expect(empty.status).toBe(200);
    expectContract(empty, 'getMySvip');
    expect(empty.body).toMatchObject({
      tier: 0,
      expiresAt: null,
      spentCoins: 0,
      nextTier: 1,
      coinsToNext: 50_000,
      windowDays: 30,
      statusDays: 30,
      tiers: [
        { tier: 1, thresholdCoins: 50_000 },
        { tier: 2, thresholdCoins: 150_000 },
        { tier: 3, thresholdCoins: 400_000 },
      ],
    });
    // Every perk is listed, none claims to work yet.
    expect(empty.body.perks).toHaveLength(8);
    expect(
      empty.body.perks.every((p: { available: boolean; unlocked: boolean }) => !p.available && !p.unlocked),
    ).toBe(true);
    expect(empty.body.perks[0].name).toBe('شارة SVIP');

    await creditIn(ctx.prisma, me.id, 200_000n, 'ADMIN_GRANT', randomUUID());
    await ctx.prisma.$transaction((tx) => debitIn(tx, me.id, 30_000n, 'LIVE_GIFT', randomUUID()));
    // Not gift spending: does not count.
    await ctx.prisma.$transaction((tx) => debitIn(tx, me.id, 40_000n, 'LIVE_BOOST', randomUUID()));
    const partial = await ctx.http.get('/api/v1/me/svip').set(auth(me));
    expect(partial.body).toMatchObject({ tier: 0, spentCoins: 30_000, coinsToNext: 20_000 });
    await ctx.prisma.$transaction((tx) => debitIn(tx, me.id, 25_000n, 'DM_GIFT', randomUUID()));
    const svip = await ctx.http.get('/api/v1/me/svip').set(auth(me));
    expectContract(svip, 'getMySvip');
    expect(svip.body).toMatchObject({ tier: 1, spentCoins: 55_000, nextTier: 2, coinsToNext: 95_000 });
    const expires = Date.parse(svip.body.expiresAt as string);
    expect(Math.abs(expires - (Date.now() + 30 * DAY_MS))).toBeLessThan(10 * 60_000);
    expect(svip.body.perks.find((p: { code: string }) => p.code === 'BADGE')).toMatchObject({
      unlocked: true,
    });

    clock.advance(29 * DAY_MS);
    try {
      expect((await ctx.http.get('/api/v1/me/svip').set(auth(me))).body).toMatchObject({ tier: 1 });
      clock.advance(2 * DAY_MS);
      expect((await ctx.http.get('/api/v1/me/svip').set(auth(me))).body).toMatchObject({
        tier: 0,
        expiresAt: null,
        spentCoins: 0,
      });
    } finally {
      clock.advance(-31 * DAY_MS);
    }
  });

  it('events: the tabs, the detail, the live board; then frozen once and prizes paid once', async () => {
    const viewer = await signup();
    const hostA = await signup();
    const hostB = await signup();
    const fan = await signup();
    await creditIn(ctx.prisma, fan.id, 10_000n, 'ADMIN_GRANT', randomUUID());
    const roomA = await startLive(hostA);
    const roomB = await startLive(hostB);
    await join(roomA, fan);
    await join(roomB, fan);
    const now = Date.now();
    const event = await ctx.prisma.event.create({
      data: {
        titleAr: 'نجوم الأسبوع',
        titleEn: 'Stars of the week',
        rulesAr: 'أكثر من يستقبل هدايا',
        rulesEn: 'Who receives the most gifts',
        // From now: gifts of the earlier tests stay outside the window.
        startsAt: new Date(now - 1000),
        endsAt: new Date(now + HOUR_MS),
        metric: 'GIFT_COINS_RECEIVED',
        featured: true,
        prizes: [
          { rankFrom: 1, rankTo: 1, coins: 500 },
          { rankFrom: 2, rankTo: 3, coins: 200 },
        ],
      },
    });
    const permanent = await ctx.prisma.event.create({
      data: {
        titleAr: 'دائمة',
        titleEn: 'Always on',
        rulesAr: '-',
        rulesEn: '-',
        startsAt: new Date(now - 10 * DAY_MS),
        permanent: true,
        metric: 'NEW_FOLLOWERS',
      },
    });
    const regional = await ctx.prisma.event.create({
      data: {
        titleAr: 'السعودية',
        titleEn: 'Saudi Arabia',
        rulesAr: '-',
        rulesEn: '-',
        startsAt: new Date(now - HOUR_MS),
        endsAt: new Date(now + DAY_MS),
        metric: 'LIVE_MINUTES',
        regions: ['SA'],
      },
    });
    await send(roomA, fan, hostA, 10); // 100
    await send(roomB, fan, hostB); // 10

    const calendar = await ctx.http
      .get('/api/v1/events?tab=CALENDAR')
      .set(auth(viewer))
      .set('Accept-Language', 'en');
    expect(calendar.status, JSON.stringify(calendar.body)).toBe(200);
    expectContract(calendar, 'listEvents');
    expect(calendar.body.data.map((e: { id: string }) => e.id)).toEqual([event.id]);
    expect(calendar.body.data[0]).toMatchObject({
      title: 'Stars of the week',
      status: 'RUNNING',
      featured: true,
    });
    const perm = await ctx.http.get('/api/v1/events?tab=PERMANENT').set(auth(viewer));
    expect(perm.body.data.map((e: { id: string }) => e.id)).toEqual([permanent.id]);
    const noCountry = await ctx.http.get('/api/v1/events?tab=REGIONAL').set(auth(viewer));
    expect(noCountry.body).toMatchObject({ country: null, data: [] });
    await ctx.prisma.userProfile.update({ where: { userId: viewer.id }, data: { countryCode: 'SA' } });
    const saudi = await ctx.http.get('/api/v1/events?tab=REGIONAL').set(auth(viewer));
    expectContract(saudi, 'listEvents');
    expect(saudi.body.data.map((e: { id: string }) => e.id)).toEqual([regional.id]);
    expect((await ctx.http.get('/api/v1/events?tab=SOON').set(auth(viewer))).status).toBe(400);
    expect((await ctx.http.get('/api/v1/events?month=2026-13').set(auth(viewer))).status).toBe(400);
    const otherMonth = await ctx.http.get('/api/v1/events?tab=CALENDAR&month=2020-01').set(auth(viewer));
    expect(otherMonth.body).toMatchObject({ month: '2020-01', data: [] });

    const detail = await ctx.http
      .get(`/api/v1/events/${event.id}`)
      .set(auth(viewer))
      .set('Accept-Language', 'ar');
    expect(detail.status).toBe(200);
    expectContract(detail, 'getEvent');
    expect(detail.body).toMatchObject({
      title: 'نجوم الأسبوع',
      rules: 'أكثر من يستقبل هدايا',
      frozenAt: null,
    });
    expect(detail.body.prizes).toHaveLength(2);
    expect((await ctx.http.get(`/api/v1/events/${randomUUID()}`).set(auth(viewer))).status).toBe(404);
    expect((await ctx.http.get('/api/v1/events/nope').set(auth(viewer))).status).toBe(404);
    expect((await ctx.http.get(`/api/v1/events/${event.id}`)).status).toBe(401);

    const live = await ctx.http.get(`/api/v1/events/${event.id}/leaderboard`).set(auth(hostB));
    expect(live.status).toBe(200);
    expectContract(live, 'getEventLeaderboard');
    expect(live.body.final).toBe(false);
    expect(
      live.body.data.map((r: { rank: number; user: { id: string }; score: number; prizeCoins: number }) => [
        r.rank,
        r.user.id,
        r.score,
        r.prizeCoins,
      ]),
    ).toEqual([
      [1, hostA.id, 100, 500],
      [2, hostB.id, 10, 200],
    ]);
    expect(live.body.me).toEqual({ rank: 2, score: 10, prizeCoins: 200 });
    const outsider = await ctx.http.get(`/api/v1/events/${event.id}/leaderboard`).set(auth(viewer));
    expect(outsider.body.me).toEqual({ rank: null, score: 0, prizeCoins: 0 });

    const sweeper = ctx.app.get(EventsService);
    expect(await sweeper.sweep()).toEqual({ frozen: 0, paid: 0 });
    clock.advance(2 * HOUR_MS);
    try {
      expect((await sweeper.sweep()).frozen).toBeGreaterThanOrEqual(1);
      expect(await sweeper.sweep()).toEqual({ frozen: 0, paid: 0 });
      // Gifts after the end never change the final board.
      await send(roomB, fan, hostB, 10);
      const frozen = await ctx.http.get(`/api/v1/events/${event.id}/leaderboard`).set(auth(viewer));
      expect(frozen.body.final).toBe(true);
      expect(frozen.body.data.map((r: { score: number }) => r.score)).toEqual([100, 10]);
      expect(await ledger(hostA, 'EVENT_PRIZE')).toHaveLength(0);

      // After the 24 h review: paid once; a winner no longer active forfeits.
      await ctx.prisma.user.update({ where: { id: hostB.id }, data: { status: 'SUSPENDED' } });
      clock.advance(25 * HOUR_MS);
      expect((await sweeper.sweep()).paid).toBeGreaterThanOrEqual(1);
      expect(await sweeper.sweep()).toEqual({ frozen: 0, paid: 0 });
      const prizes = await ledger(hostA, 'EVENT_PRIZE');
      expect(prizes.map((p) => Number(p.delta))).toEqual([500]);
      expect(await ledger(hostB, 'EVENT_PRIZE')).toHaveLength(0);
      const results = await ctx.prisma.eventResult.findMany({
        where: { eventId: event.id },
        orderBy: { rank: 'asc' },
      });
      expect(results.map((r) => r.prizeStatus)).toEqual(['PAID', 'FORFEITED']);
      const paidDetail = await ctx.http.get(`/api/v1/events/${event.id}`).set(auth(hostA));
      expectContract(paidDetail, 'getEvent');
      expect(paidDetail.body.paidAt).not.toBeNull();
    } finally {
      clock.advance(-27 * HOUR_MS);
    }
  });

  it('a held payout waits for release', async () => {
    const host = await signup();
    const fan = await signup();
    await creditIn(ctx.prisma, fan.id, 1_000n, 'ADMIN_GRANT', randomUUID());
    const room = await startLive(host);
    await join(room, fan);
    const now = Date.now();
    const event = await ctx.prisma.event.create({
      data: {
        titleAr: 'معلّقة',
        titleEn: 'Held',
        rulesAr: '-',
        rulesEn: '-',
        startsAt: new Date(now - 1000),
        endsAt: new Date(now + HOUR_MS),
        metric: 'GIFT_COINS_SENT',
        payoutHold: true,
        prizes: [{ rankFrom: 1, rankTo: 1, coins: 300 }],
      },
    });
    await send(room, fan, host);
    const sweeper = ctx.app.get(EventsService);
    clock.advance(30 * HOUR_MS);
    try {
      await sweeper.sweep();
      await sweeper.sweep();
      expect(await ledger(fan, 'EVENT_PRIZE')).toHaveLength(0);
      await ctx.prisma.event.update({ where: { id: event.id }, data: { payoutHold: false } });
      // The review window runs from the freeze.
      clock.advance(25 * HOUR_MS);
      await sweeper.sweep();
      expect((await ledger(fan, 'EVENT_PRIZE')).map((p) => Number(p.delta))).toEqual([300]);
    } finally {
      clock.advance(-55 * HOUR_MS);
    }
  });

  it('no events configured: honest empty lists', async () => {
    await ctx.prisma.event.deleteMany({});
    const me = await signup();
    for (const tab of ['CALENDAR', 'PERMANENT', 'REGIONAL']) {
      const res = await ctx.http.get(`/api/v1/events?tab=${tab}`).set(auth(me));
      expect(res.status).toBe(200);
      expect(res.body.data).toEqual([]);
    }
  });

  it('recharge packages come from config; purchases stay off (B5)', async () => {
    const me = await signup();
    const res = await ctx.http.get('/api/v1/wallet/recharge-packages').set(auth(me));
    expect(res.status).toBe(200);
    expectContract(res, 'listRechargePackages');
    expect(res.body.purchasesEnabled).toBe(false);
    expect(res.body.currency).toBe('USD');
    expect(res.body.packages).toHaveLength(7);
    expect(res.body.packages[2]).toEqual({
      id: 'p3',
      coins: 276,
      bonusCoins: 28,
      priceMinor: 699,
      originalPriceMinor: 800,
    });
    expect((await ctx.http.get('/api/v1/wallet/recharge-packages')).status).toBe(401);
  });
});
