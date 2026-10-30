/**
 * D184 (owner 2026-10-30; contract v1.53-social, CONVENTIONS §10.41.3, §10.46.1): the Task Center's
 * rewards are cherries — the old coins ×10 (1 coin = 10 cherries), credited to the cherry ledger with
 * reason `TASK_REWARD` (one row per person, task and day, in the claim's transaction), under the daily
 * cherry cap; claims made in coins before the change keep what they paid; the check-in keeps its coins.
 * Task cherries stay out of withdrawals until the (placeholder) unlock rule passes: lifetime gift cherries
 * worth `TASK_CHERRIES_UNLOCK_GIFT_MINOR`. End to end against PostgreSQL + Redis.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { creditTaskCherriesIn } from '../src/modules/economy/cherry-ledger.js';
import { dateValue } from '../src/modules/programs/programs-time.js';
import { seedDefaultTasksIn } from '../src/modules/programs/programs-seed.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { expectContract, openapi } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

interface Task {
  code: string;
  rewardCoins: number;
  rewardCherries: number;
  completed: boolean;
  claimed: boolean;
  claimedCoins: number | null;
  claimedCherries: number | null;
}

interface MyTasks {
  day: string;
  dailyCapCoins: number;
  dailyEarnedCoins: number;
  dailyCapCherries: number;
  dailyEarnedCherries: number;
  tasks: Task[];
}

interface CherryWallet {
  cherries: number;
  taskRewardTotal: number;
  lockedTaskCherries: number;
  withdrawableCherries: number;
  taskUnlock: { unlocked: boolean; giftValueMinor: number; thresholdMinor: number };
}

/** The daily cherry cap here (D188 defaults: a free task 300 + 200 of the next). */
const CHERRY_CAP = 500;
const COIN_CAP = 27;

/** A fixed-offset zone where it is about noon now, so "today" never ends in the middle of a test. */
function noonZone(): string {
  const offset = 12 - new Date().getUTCHours();
  if (offset === 0) return 'Etc/GMT';
  return offset > 0 ? `Etc/GMT-${String(offset)}` : `Etc/GMT+${String(-offset)}`;
}

describe('D184 contract coverage', () => {
  it('openapi v1.53-social declares task cherries, TASK_REWARD and the locked task cherries', () => {
    const schemas = (openapi.components as { schemas: Record<string, Record<string, unknown>> }).schemas;
    const required = (name: string) => (schemas[name] as { required: string[] }).required;
    expect(required('ProgramTask')).toEqual(expect.arrayContaining(['rewardCherries', 'claimedCherries']));
    expect(required('MyTasks')).toEqual(expect.arrayContaining(['dailyCapCherries', 'dailyEarnedCherries']));
    expect(required('TaskClaimResult')).toEqual(expect.arrayContaining(['paidCherries', 'balanceCherries']));
    expect(required('CherryWallet')).toEqual(
      expect.arrayContaining(['taskRewardTotal', 'lockedTaskCherries', 'withdrawableCherries', 'taskUnlock']),
    );
    expect((schemas.CherryLedgerReason as { enum: string[] }).enum).toContain('TASK_REWARD');
  });
});

describe('D184 task rewards in cherries', { timeout: 240_000 }, () => {
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  let targets: TestUser[] = [];
  let host: TestUser;
  let roomId = '';

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
  const follow = async (a: TestUser, b: TestUser) => {
    const res = await ctx.http.put(`/api/v1/users/${b.username}/follow`).set(auth(a));
    expect(res.status).toBe(200);
  };
  const tasks = async (u: TestUser): Promise<MyTasks> => {
    const res = await ctx.http.get('/api/v1/me/tasks').set(auth(u)).set('Accept-Language', 'en');
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getMyTasks');
    return res.body as MyTasks;
  };
  const task = async (u: TestUser, code: string) => (await tasks(u)).tasks.find((t) => t.code === code)!;
  const claim = (u: TestUser, code: string) => ctx.http.post(`/api/v1/me/tasks/${code}/claim`).set(auth(u));
  const wallet = async (u: TestUser): Promise<CherryWallet> => {
    const res = await ctx.http.get('/api/v1/wallet/me/cherries').set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getMyCherries');
    return res.body as CherryWallet;
  };
  const withdraw = async (u: TestUser, amountMinor: number) => {
    const res = await ctx.http
      .post('/api/v1/wallet/me/cherries/withdrawals')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({ amountMinor, payoutDetails: 'IBAN TEST 123' });
    expectContract(res, 'requestCherryWithdrawal');
    return res;
  };
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
  /** All four daily tasks done: ten follows, ten chat messages and a 15 s watch in a live, ten gifts. */
  const doEverything = async (me: TestUser) => {
    for (const t of targets.slice(0, 10)) await follow(me, t);
    for (let i = 0; i < 10; i++) {
      await ctx.prisma.liveChatMessage.create({
        data: {
          roomId,
          userId: me.id,
          clientId: randomUUID(),
          text: `hi ${String(i)}`,
          authorRole: 'VIEWER',
        },
      });
    }
    await ctx.prisma.liveRoomAudience.create({
      data: { roomId, identity: me.id, userId: me.id, firstJoinedAt: new Date(), watchMs: 15_000n },
    });
  };

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        LIVE_RANKINGS_TIME_ZONE: noonZone(),
        TASK_DAILY_CAP_CHERRIES: String(CHERRY_CAP),
        TASK_DAILY_CAP_COINS: String(COIN_CAP),
        // Small payout units: 1 000 cherries = $1.10; task cherries unlock at $20 of gift cherries.
        CHERRY_PAYOUT_RATE: '1000:110',
        TASK_CHERRIES_UNLOCK_GIFT_MINOR: '2000',
      },
      [{ token: LIVE_MEDIA_PROVIDER, value: media }],
    );
    expect(await seedDefaultTasksIn(ctx.prisma)).toBe(6);
    for (let i = 0; i < 10; i++) targets.push(await signup());
    targets = [...targets];
    host = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(host)).send({ title: 'Tasks' });
    expect(room.status, JSON.stringify(room.body)).toBe(201);
    roomId = room.body.id as string;
  });
  afterAll(async () => ctx?.close());

  it('the rewards are cherries — the D188 defaults (owner: free actions 300, gifts by coin value); the caps', async () => {
    const me = await signup();
    const mine = await tasks(me);
    expect(mine).toMatchObject({
      dailyCapCherries: CHERRY_CAP,
      dailyEarnedCherries: 0,
      dailyCapCoins: COIN_CAP,
      dailyEarnedCoins: 0,
    });
    expect(mine.tasks.map((t) => [t.code, t.rewardCherries, t.rewardCoins])).toEqual([
      ['WATCH_LIVE', 300, 0],
      ['FOLLOW_USERS', 300, 0],
      ['LIVE_CHAT', 300, 0],
      ['SEND_GIFTS', 1_000, 0],
    ]);
    // The weekly host tasks too (D188 follow-up: per band; band 1 — 5 hours live → 180 000, 2 500 000 coins
    // received → 220 000).
    const hostTasks = await tasks(host);
    expect(hostTasks.tasks.filter((t) => t.code.startsWith('HOST_')).map((t) => t.rewardCherries)).toEqual([
      180_000, 220_000,
    ]);
  });

  it('a claim credits TASK_REWARD once (concurrent claims too), in the Cherries history; the cap', async () => {
    const me = await signup();
    await doEverything(me);
    const results = await Promise.all([1, 2, 3].map(() => claim(me, 'FOLLOW_USERS')));
    expect(results.map((r) => r.status).sort()).toEqual([200, 200, 201]);
    for (const r of results) {
      expectContract(r, 'claimMyTask');
      expect(r.body).toMatchObject({
        paidCherries: 300,
        balanceCherries: 300,
        paidCoins: 0,
        balanceCoins: 0,
      });
    }
    const day = (await tasks(me)).day;
    const rows = await ctx.prisma.cherryLedgerEntry.findMany({ where: { userId: me.id } });
    expect(rows).toEqual([
      expect.objectContaining({
        reason: 'TASK_REWARD',
        delta: 300n,
        balanceAfter: 300n,
        referenceId: `FOLLOW_USERS@${day}`,
      }),
    ]);
    expect(await ctx.prisma.walletLedgerEntry.count({ where: { userId: me.id } })).toBe(0);
    const claimRow = await ctx.prisma.taskClaim.findFirstOrThrow({ where: { userId: me.id } });
    expect(claimRow).toMatchObject({ rewardAmount: 300, rewardCurrency: 'CHERRIES' });

    // The ledger itself refuses a second TASK_REWARD for the same task and day.
    await expect(
      ctx.prisma.$transaction((tx) =>
        creditTaskCherriesIn(tx, me.id, 300n, `FOLLOW_USERS@${day}`, new Date()),
      ),
    ).rejects.toThrow();

    const history = await ctx.http.get('/api/v1/wallet/me/cherries/ledger').set(auth(me));
    expect(history.status).toBe(200);
    expectContract(history, 'listMyCherryLedger');
    expect(history.body.data).toEqual([
      expect.objectContaining({ reason: 'TASK_REWARD', delta: 300, balanceAfter: 300, gift: null }),
    ]);

    // Cap 500: 300 paid → the next pays the 200 left (of 300), then 409; nothing more is credited.
    const capped = await claim(me, 'LIVE_CHAT');
    expect(capped.status).toBe(201);
    expect(capped.body).toMatchObject({
      paidCherries: 200,
      balanceCherries: 500,
      task: {
        code: 'LIVE_CHAT',
        claimed: true,
        rewardCherries: 300,
        claimedCherries: 200,
        claimedCoins: 0,
      },
    });
    const refused = await claim(me, 'WATCH_LIVE');
    expect(refused.status).toBe(409);
    expect(refused.body.error.code).toBe('TASK_DAILY_CAP_REACHED');
    const after = await tasks(me);
    expect(after.dailyEarnedCherries).toBe(CHERRY_CAP);
    expect(after.dailyEarnedCoins).toBe(0);
    expect(
      await ctx.prisma.cherryLedgerEntry.aggregate({
        where: { userId: me.id, reason: 'TASK_REWARD' },
        _sum: { delta: true },
      }),
    ).toEqual({ _sum: { delta: BigInt(CHERRY_CAP) } });
    // The check-in still pays coins, outside the cherry cap.
    const checkIn = await ctx.http.post('/api/v1/me/check-in').set(auth(me));
    expect(checkIn.status).toBe(201);
    expect(checkIn.body).toMatchObject({ paidCoins: 5, balanceCoins: 5 });
  });

  it('a claim paid in coins before the change keeps its coins; the check-in coin cap counts it', async () => {
    const me = await signup();
    await doEverything(me);
    const day = (await tasks(me)).day;
    // As migration 20261231110000 leaves an earlier claim: COINS, its wallet row untouched.
    const legacy = await ctx.prisma.taskClaim.create({
      data: {
        userId: me.id,
        taskCode: 'FOLLOW_USERS',
        periodStart: dateValue(day),
        rewardAmount: 25,
        rewardCurrency: 'COINS',
      },
    });
    await creditIn(ctx.prisma, me.id, 25n, 'TASK_REWARD', legacy.id);
    expect(await task(me, 'FOLLOW_USERS')).toMatchObject({
      claimed: true,
      claimedCoins: 25,
      claimedCherries: 0,
      rewardCherries: 300,
    });
    const again = await claim(me, 'FOLLOW_USERS');
    expect(again.status).toBe(200);
    expectContract(again, 'claimMyTask');
    expect(again.body).toMatchObject({
      paidCoins: 25,
      paidCherries: 0,
      balanceCoins: 25,
      balanceCherries: 0,
    });
    const mine = await tasks(me);
    expect(mine.dailyEarnedCoins).toBe(25);
    expect(mine.dailyEarnedCherries).toBe(0);
    // Coin cap 27: the check-in's 5 coins pay the 2 left.
    const checkIn = await ctx.http.post('/api/v1/me/check-in').set(auth(me));
    expect(checkIn.status).toBe(201);
    expect(checkIn.body.paidCoins).toBe(2);
    // The cherry cap is untouched by coins: a task pays its full 300 cherries.
    const fresh = await claim(me, 'LIVE_CHAT');
    expect(fresh.status).toBe(201);
    expect(fresh.body.paidCherries).toBe(300);
  });

  it('task cherries are not withdrawable until gift cherries reach the unlock value', async () => {
    const me = await signup();
    const day = (await tasks(me)).day;
    await ctx.prisma.$transaction((tx) =>
      creditTaskCherriesIn(tx, me.id, 20_000n, `SEND_GIFTS@${day}`, new Date()),
    );
    await giftCherries(me, 10_000n); // $11 of gift cherries: below the $20 rule
    expect(await wallet(me)).toMatchObject({
      cherries: 30_000,
      taskRewardTotal: 20_000,
      lockedTaskCherries: 20_000,
      withdrawableCherries: 10_000,
      taskUnlock: { unlocked: false, giftValueMinor: 1100, thresholdMinor: 2000 },
    });
    // $12 needs 10 910 cherries: more than the 10 000 withdrawable.
    const refused = await withdraw(me, 1200);
    expect(refused.status).toBe(409);
    expect(refused.body.error.code).toBe('INSUFFICIENT_CHERRIES');
    expect(await ctx.prisma.cherryWithdrawal.count({ where: { userId: me.id } })).toBe(0);

    await giftCherries(me, 9_000n); // $20.90 of gift cherries: unlocked
    expect(await wallet(me)).toMatchObject({
      cherries: 39_000,
      lockedTaskCherries: 0,
      withdrawableCherries: 39_000,
      taskUnlock: { unlocked: true, giftValueMinor: 2090 },
    });
    const paid = await withdraw(me, 4000); // 36 364 cherries: needs the task cherries
    expect(paid.status, JSON.stringify(paid.body)).toBe(201);
    expect((await wallet(me)).cherries).toBe(39_000 - 36_364);
  });
});
