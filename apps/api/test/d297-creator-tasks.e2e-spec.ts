/**
 * D297 (owner 2026-11-06: «مهام خاصة بصناع المحتوى، وقيمتها كمهام المضيف»; contract v1.94-social, CONVENTIONS §10.110):
 * Task Center tasks only for content creators (creator-programme members, `creator_members`), valued like the host
 * tasks: the pool group CREATOR (a band's `creator_count` tasks first) and four weekly creator tasks per band, counted
 * from stored data (what OTHER ACTIVE people did with the creator's content), under the SAME daily and monthly caps as
 * the host tasks. A member never gets the host tasks, even with a hosting permission (D295). End to end against
 * PostgreSQL + Redis.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  DEFAULT_CREATOR_POOL_TASKS,
  DEFAULT_CREATOR_TASKS,
  DEFAULT_TASK_POOL_BANDS,
} from '../src/modules/programs/programs-rules.js';
import {
  seedD297TasksIn,
  seedDefaultTaskPoolIn,
  seedDefaultTasksIn,
} from '../src/modules/programs/programs-seed.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { GEN_WEEKLY_COUNT } from '../src/modules/programs/task-generator.js';
import { keepLegacyTargetsEngine, smartTargetsEngineFrom } from './helpers/d281.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, openapi } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

interface Task {
  code: string;
  pooled: boolean;
  period: 'DAILY' | 'WEEKLY';
  metric: string;
  audience: 'EVERYONE' | 'HOSTS' | 'CREATORS';
  name: string;
  target: number;
  progress: number;
  completed: boolean;
  claimed: boolean;
  rewardCherries: number;
  claimedCherries: number | null;
}

interface MyTasks {
  day: string;
  weekStartsAt: string;
  weekResetsAt: string;
  dailyCapCherries: number;
  dailyEarnedCherries: number;
  monthlyCapCherries: number;
  monthlyEarnedCherries: number;
  band: { band: number; level: number; name: string; host: boolean; creator: boolean };
  tasks: Task[];
}

const CREATOR_POOL = DEFAULT_CREATOR_POOL_TASKS.map((t) => t.code);
const CREATOR_WEEKLY = DEFAULT_CREATOR_TASKS.map((t) => t.code);
const DAY_MS = 86_400_000;

/** A fixed-offset zone where it is about noon now, so "today" never ends in the middle of a test. */
function noonZone(): string {
  const offset = 12 - new Date().getUTCHours();
  if (offset === 0) return 'Etc/GMT';
  return offset > 0 ? `Etc/GMT-${String(offset)}` : `Etc/GMT+${String(-offset)}`;
}

describe('D297 contract coverage', () => {
  it('openapi v1.94-social declares the CREATORS audience, the new metrics and MyTasks.band.creator', () => {
    const schemas = (openapi.components as { schemas: Record<string, Record<string, unknown>> }).schemas;
    const task = schemas.ProgramTask as { properties: Record<string, { enum?: string[] }> };
    expect(task.properties.audience!.enum).toEqual(['EVERYONE', 'HOSTS', 'CREATORS']);
    expect(task.properties.metric!.enum).toEqual(
      expect.arrayContaining([
        'REEL_VIEWS_RECEIVED',
        'LIKES_RECEIVED',
        'COMMENT_REPLIES',
        'NEW_FOLLOWERS',
        'SHARES_RECEIVED',
      ]),
    );
    const band = (schemas.MyTasks as { properties: Record<string, { required: string[] }> }).properties.band!;
    expect(band.required).toContain('creator');
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
  const task = async (u: TestUser, code: string) => {
    const found = (await tasks(u)).tasks.find((t) => t.code === code);
    expect(found, code).toBeDefined();
    return found!;
  };
  const claim = async (u: TestUser, code: string) => {
    const res = await get().http.post(`/api/v1/me/tasks/${code}/claim`).set(auth(u));
    expectContract(res, 'claimMyTask');
    return res;
  };
  /** The creator programme's membership, as an approved «انضم كصانع محتوى» application makes it (D285). */
  const makeCreator = async (u: TestUser) => {
    const app = await get().prisma.creatorApplication.create({
      data: {
        userId: u.id,
        status: 'APPROVED',
        country: 'SA',
        category: 'VIDEO',
        links: ['https://x.example/creator'],
        decidedAt: new Date(),
      },
    });
    await get().prisma.creatorMember.create({
      data: { userId: u.id, applicationId: app.id, activatedAt: new Date() },
    });
  };
  /** A published post or reel of `u` (the stored row the counts read; a reel's video is not needed for them). */
  const content = async (u: TestUser, format: 'POST' | 'REEL', extra: { deletedAt?: Date } = {}) =>
    (
      await get().prisma.post.create({
        data: {
          authorId: u.id,
          format,
          text: `${format} ${randomUUID()}`,
          publishedAt: new Date(),
          ...extra,
        },
        select: { id: true },
      })
    ).id;
  /** Only `codes` of the CREATOR pool stay switched on (the team's `task-admin set … --enabled`). */
  const onlyCreatorPool = async (codes: readonly string[]) => {
    await get().prisma.taskDefinition.updateMany({
      where: { code: { in: CREATOR_POOL } },
      data: { enabled: false },
    });
    await get().prisma.taskDefinition.updateMany({
      where: { code: { in: [...codes] } },
      data: { enabled: true },
    });
  };
  const allCreatorPool = () =>
    get().prisma.taskDefinition.updateMany({
      where: { code: { in: CREATOR_POOL } },
      data: { enabled: true },
    });
  const suspend = (u: TestUser) =>
    get().prisma.user.update({ where: { id: u.id }, data: { status: 'SUSPENDED' } });
  return { auth, signup, tasks, task, claim, makeCreator, content, onlyCreatorPool, allCreatorPool, suspend };
}

describe('D297 creator tasks: who gets them, the metrics, the weekly tasks', { timeout: 300_000 }, () => {
  let ctx: TestContext;
  const h = helpers(() => ctx);
  const { auth, signup, tasks, task, claim, makeCreator, content } = h;

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_RANKINGS_TIME_ZONE: noonZone() });
    // D176's pool (the day of the smart engine's switch and before); one test switches the smart engine on.
    await keepLegacyTargetsEngine(ctx.prisma);
    // The database is emptied for the tests: the migrations' defaults again (task-admin seed-defaults).
    expect(await seedDefaultTasksIn(ctx.prisma)).toBe(7);
    await seedDefaultTaskPoolIn(ctx.prisma);
    // The generator switched off here (its own suite below): the hand-made pool and the fixed weekly tasks.
    expect(await seedD297TasksIn(ctx.prisma, { generator: false })).toBe(6 + 6 + 2 + 32);
    expect(await seedD297TasksIn(ctx.prisma, { generator: false })).toBe(0);
  });
  afterAll(async () => ctx?.close());

  it('a creator gets the CREATOR tasks (and never the host tasks); a viewer and a host do not', async () => {
    const creator = await signup();
    await makeCreator(creator);
    // D295 gives a member a hosting permission: still a creator for the tasks (no HOSTS task).
    await ctx.prisma.liveHost.create({ data: { userId: creator.id, source: 'ADMIN' } });
    const mine = await tasks(creator);
    expect(mine.band).toMatchObject({ band: 1, host: false, creator: true });
    expect(mine.tasks.filter((t) => t.audience === 'HOSTS')).toEqual([]);
    const pooled = mine.tasks.filter((t) => t.pooled && t.audience === 'CREATORS');
    expect(pooled).toHaveLength(DEFAULT_TASK_POOL_BANDS[0]!.creatorCount);
    // Creator tasks come first, then everyone's (the band's daily count in all).
    expect(mine.tasks.filter((t) => t.pooled)).toHaveLength(DEFAULT_TASK_POOL_BANDS[0]!.dailyCount);
    expect(mine.tasks.slice(0, pooled.length).every((t) => t.audience === 'CREATORS')).toBe(true);
    for (const t of pooled) {
      const d = DEFAULT_CREATOR_POOL_TASKS.find((x) => x.code === t.code)!;
      expect(t).toMatchObject({
        period: 'DAILY',
        target: d.bandTargets[0],
        rewardCherries: d.bandRewards[0],
      });
    }
    // Never one action counted by two of the day's tasks.
    const metrics = mine.tasks.filter((t) => t.pooled).map((t) => t.metric);
    expect(new Set(metrics).size).toBe(metrics.length);
    // The four weekly creator tasks at band 1: the owner's figures.
    const weekly = mine.tasks.filter((t) => t.period === 'WEEKLY');
    expect(weekly.map((t) => [t.code, t.audience, t.metric, t.target, t.rewardCherries])).toEqual([
      ['CREATOR_WEEKLY_REELS', 'CREATORS', 'REELS', 5, 180_000],
      ['CREATOR_WEEKLY_VIEWS', 'CREATORS', 'REEL_VIEWS_RECEIVED', 5_000, 180_000],
      ['CREATOR_WEEKLY_FOLLOWERS', 'CREATORS', 'NEW_FOLLOWERS', 50, 220_000],
      ['CREATOR_WEEKLY_SHARES', 'CREATORS', 'SHARES_RECEIVED', 20, 220_000],
      // Owner follow-up: six weekly creator tasks.
      ['CREATOR_WEEKLY_LIKES', 'CREATORS', 'LIKES_RECEIVED', 200, 220_000],
      ['CREATOR_WEEKLY_STORIES', 'CREATORS', 'STORIES', 5, 180_000],
    ]);

    // A viewer: no creator task, and a creator task's claim is 404.
    const viewer = await signup();
    const theirs = await tasks(viewer);
    expect(theirs.band).toMatchObject({ host: false, creator: false });
    expect(theirs.tasks.filter((t) => t.audience !== 'EVERYONE')).toEqual([]);
    expect((await claim(viewer, 'CREATOR_WEEKLY_REELS')).status).toBe(404);
    expect((await claim(viewer, pooled[0]!.code)).status).toBe(404);

    // A host: the host tasks, valued like the creator's (band 1), and no creator task.
    const host = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    const hosts = await tasks(host);
    expect(hosts.band).toMatchObject({ host: true, creator: false });
    expect(hosts.tasks.some((t) => t.audience === 'CREATORS')).toBe(false);
    expect(hosts.tasks.filter((t) => t.period === 'WEEKLY').map((t) => [t.code, t.rewardCherries])).toEqual([
      ['HOST_LIVE_MINUTES', 180_000],
      ['HOST_GIFT_COINS', 220_000],
      // Owner follow-up: four weekly host tasks.
      ['HOST_WEEKLY_LIVE_DAYS', 180_000],
      ['HOST_WEEKLY_PK_BATTLES', 180_000],
    ]);
    expect((await claim(host, 'CREATOR_WEEKLY_REELS')).status).toBe(404);
    // The caps are the same numbers for both.
    for (const k of ['dailyCapCherries', 'monthlyCapCherries'] as const) expect(mine[k]).toBe(hosts[k]);

    // A membership that ends ends the creator tasks (D295 deletes the row).
    await ctx.prisma.creatorMember.delete({ where: { userId: creator.id } });
    const after = await tasks(creator);
    expect(after.band).toMatchObject({ host: true, creator: false });
    expect(after.tasks.some((t) => t.audience === 'CREATORS')).toBe(false);
  });

  it('the smart engine (D281) gives a creator CREATOR tasks first and no host tasks', async () => {
    await smartTargetsEngineFrom(ctx.prisma, '2020-01-01');
    try {
      const creator = await signup();
      await makeCreator(creator);
      await ctx.prisma.liveHost.create({ data: { userId: creator.id, source: 'ADMIN' } });
      const mine = await tasks(creator);
      const pooled = mine.tasks.filter((t) => t.pooled);
      expect(pooled.length).toBe(DEFAULT_TASK_POOL_BANDS[0]!.dailyCount);
      const n = DEFAULT_TASK_POOL_BANDS[0]!.creatorCount;
      expect(pooled.slice(0, n).every((t) => t.audience === 'CREATORS')).toBe(true);
      expect(pooled.filter((t) => t.audience === 'CREATORS')).toHaveLength(n);
      expect(mine.tasks.some((t) => t.audience === 'HOSTS')).toBe(false);
      const stored = await ctx.prisma.taskAssignment.findMany({ where: { userId: creator.id } });
      expect(
        stored
          .filter((a) => CREATOR_POOL.includes(a.taskCode))
          .every((a) => a.variant?.startsWith('K.P_CR_')),
      ).toBe(true);
      const viewer = await signup();
      expect((await tasks(viewer)).tasks.some((t) => t.audience === 'CREATORS')).toBe(false);
    } finally {
      await keepLegacyTargetsEngine(ctx.prisma);
    }
  });

  it('weekly: REELS, REEL_VIEWS_RECEIVED, NEW_FOLLOWERS and SHARES_RECEIVED — others’ ACTIVE actions only', async () => {
    const creator = await signup();
    await makeCreator(creator);
    const [a, b, c, s] = [await signup(), await signup(), await signup(), await signup()];
    const week = await tasks(creator);

    // REELS: the creator's published reels this week — not a post, not a deleted reel, not someone else's reel.
    const reel = await content(creator, 'REEL');
    const reel2 = await content(creator, 'REEL');
    await content(creator, 'REEL', { deletedAt: new Date() });
    const post = await content(creator, 'POST');
    await content(a, 'REEL');
    expect(await task(creator, 'CREATOR_WEEKLY_REELS')).toMatchObject({ progress: 2, completed: false });
    await ctx.prisma.post.update({ where: { id: reel2 }, data: { moderation: 'REMOVED' } });
    expect(await task(creator, 'CREATOR_WEEKLY_REELS')).toMatchObject({ progress: 1 });

    // REEL_VIEWS_RECEIVED: §11.4 views through the API (one per viewer and reel per 24 h).
    const view = async (u: TestUser, postId: string) => {
      const res = await ctx.http
        .post('/api/v1/views')
        .set(auth(u))
        .send({ items: [{ postId, watchedMs: 5_000 }] });
      expect(res.status, JSON.stringify(res.body)).toBe(204);
    };
    await view(a, reel);
    await view(a, reel); // the same viewer within 24 h: one view
    await view(b, reel);
    await view(s, reel);
    await view(a, post); // a post is not a reel
    // The creator's own view (the API never stores one; a stored row is still not counted).
    await ctx.prisma.postView.create({ data: { postId: reel, userId: creator.id, viewedAt: new Date() } });
    // A view counted last week does not count this week.
    await ctx.prisma.postView.create({
      data: { postId: reel, userId: c.id, viewedAt: new Date(Date.parse(week.weekStartsAt) - DAY_MS) },
    });
    expect(await task(creator, 'CREATOR_WEEKLY_VIEWS')).toMatchObject({ progress: 3 });
    await h.suspend(s);
    expect(await task(creator, 'CREATOR_WEEKLY_VIEWS')).toMatchObject({ progress: 2 });

    // NEW_FOLLOWERS: follows of the creator this week that still stand, from ACTIVE people.
    const follow = async (u: TestUser) => {
      const res = await ctx.http.put(`/api/v1/users/${creator.username}/follow`).set(auth(u));
      expect(res.status, JSON.stringify(res.body)).toBeLessThan(300);
    };
    await follow(a);
    await follow(b);
    await follow(c);
    expect(await task(creator, 'CREATOR_WEEKLY_FOLLOWERS')).toMatchObject({ progress: 3 });
    // Unfollowed within the week: no longer counted; following back counts once again.
    expect(
      (await ctx.http.delete(`/api/v1/users/${creator.username}/follow`).set(auth(c))).status,
    ).toBeLessThan(300);
    expect(await task(creator, 'CREATOR_WEEKLY_FOLLOWERS')).toMatchObject({ progress: 2 });
    // A follow from before the week, and the creator following others, do not count.
    const old = await signup();
    await ctx.prisma.follow.create({
      data: {
        followerId: old.id,
        followeeId: creator.id,
        createdAt: new Date(Date.parse(week.weekStartsAt) - DAY_MS),
      },
    });
    await ctx.prisma.follow.create({ data: { followerId: creator.id, followeeId: a.id } });
    expect(await task(creator, 'CREATOR_WEEKLY_FOLLOWERS')).toMatchObject({ progress: 2 });
    await h.suspend(b);
    expect(await task(creator, 'CREATOR_WEEKLY_FOLLOWERS')).toMatchObject({ progress: 1 });

    // SHARES_RECEIVED: outside shares (one per person, post and UTC day) and reposts by other ACTIVE people.
    const d = await signup();
    const e = await signup();
    const share = async (u: TestUser, postId: string) => {
      const res = await ctx.http.post(`/api/v1/posts/${postId}/shares`).set(auth(u));
      expect(res.status, JSON.stringify(res.body)).toBe(200);
    };
    await share(d, post);
    await share(d, post); // the same day: once
    await share(d, reel);
    await share(creator, post); // their own share is stored but never counted
    const repost = await ctx.http.put(`/api/v1/posts/${post}/repost`).set(auth(e));
    expect(repost.status, JSON.stringify(repost.body)).toBeLessThan(300);
    // A share event is kept per UTC day: it counts in the period holding that UTC day (each day in one period).
    const utc = (iso: string) => new Date(iso).toISOString().slice(0, 10);
    const today = new Date().toISOString().slice(0, 10);
    const inWeek = today >= utc(week.weekStartsAt) && today < utc(week.weekResetsAt);
    expect(await task(creator, 'CREATOR_WEEKLY_SHARES')).toMatchObject({ progress: (inWeek ? 2 : 0) + 1 });
    // A share stored for a day of last week does not count.
    await ctx.prisma.postShareEvent.create({
      data: {
        postId: reel,
        userId: e.id,
        day: new Date(utc(new Date(Date.parse(week.weekStartsAt) - 2 * DAY_MS).toISOString())),
      },
    });
    expect(await task(creator, 'CREATOR_WEEKLY_SHARES')).toMatchObject({ progress: (inWeek ? 2 : 0) + 1 });
    await h.suspend(e);
    expect(await task(creator, 'CREATOR_WEEKLY_SHARES')).toMatchObject({ progress: inWeek ? 2 : 0 });
  });

  it('daily: LIKES_RECEIVED and COMMENT_REPLIES — others’ ACTIVE actions only', async () => {
    const creator = await signup();
    await makeCreator(creator);
    await h.onlyCreatorPool(['P_CR_LIKES', 'P_CR_REPLIES']);
    let mine: MyTasks;
    try {
      mine = await tasks(creator);
    } finally {
      await h.allCreatorPool();
    }
    expect(
      mine.tasks
        .filter((t) => t.audience === 'CREATORS' && t.pooled)
        .map((t) => t.code)
        .sort(),
    ).toEqual(['P_CR_LIKES', 'P_CR_REPLIES']);
    const [a, b, c, s] = [await signup(), await signup(), await signup(), await signup()];
    const post = await content(creator, 'POST');
    const reel = await content(creator, 'REEL');
    const elsewhere = await content(a, 'POST');

    // LIKES_RECEIVED on posts and reels, through the API.
    const like = async (u: TestUser, postId: string) => {
      const res = await ctx.http.put(`/api/v1/posts/${postId}/like`).set(auth(u));
      expect(res.status, JSON.stringify(res.body)).toBeLessThan(300);
    };
    await like(a, post);
    await like(b, reel);
    await like(c, post);
    await like(s, post);
    await like(b, elsewhere); // not the creator's content
    await ctx.prisma.postLike.create({ data: { postId: post, userId: creator.id } }); // their own like
    expect(await task(creator, 'P_CR_LIKES')).toMatchObject({ progress: 4 });
    expect((await ctx.http.delete(`/api/v1/posts/${post}/like`).set(auth(c))).status).toBeLessThan(300);
    await h.suspend(s);
    expect(await task(creator, 'P_CR_LIKES')).toMatchObject({ progress: 2, target: 20, completed: false });

    // COMMENT_REPLIES: different comments of others on the creator's posts the creator replied to.
    const comment = async (u: TestUser, postId: string, parentId?: string) => {
      const res = await ctx.http
        .post(`/api/v1/posts/${postId}/comments`)
        .set(auth(u))
        .set('Idempotency-Key', randomUUID())
        .send({ text: `c ${randomUUID().slice(0, 6)}`, ...(parentId ? { parentId } : {}) });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      return res.body.id as string;
    };
    const c1 = await comment(a, post);
    const c2 = await comment(b, reel);
    const own = await comment(creator, post);
    const sc = await comment(c, post); // c's comment (ACTIVE)
    await comment(creator, post, c1);
    await comment(creator, post, c1); // two replies to one comment: once
    const r2 = await comment(creator, reel, c2);
    await comment(creator, post, own); // a reply to their own comment
    await comment(a, post, c1); // someone else's reply
    const other = await comment(b, elsewhere);
    await comment(creator, elsewhere, other); // a reply on someone else's post
    expect(await task(creator, 'P_CR_REPLIES')).toMatchObject({ progress: 2 });
    await comment(creator, post, sc);
    expect(await task(creator, 'P_CR_REPLIES')).toMatchObject({ progress: 3, target: 3, completed: true });
    // A deleted reply and a suspended commenter no longer count.
    expect((await ctx.http.delete(`/api/v1/comments/${r2}`).set(auth(creator))).status).toBeLessThan(300);
    expect(await task(creator, 'P_CR_REPLIES')).toMatchObject({ progress: 2, completed: false });
    await h.suspend(c);
    expect(await task(creator, 'P_CR_REPLIES')).toMatchObject({ progress: 1 });
  });

  it('the weekly tasks follow the band of the day (band 2: the second column)', async () => {
    await ctx.prisma.taskPoolBand.update({ where: { band: 2 }, data: { minLevel: 0 } });
    try {
      const creator = await signup();
      await makeCreator(creator);
      const mine = await tasks(creator);
      expect(mine.band).toMatchObject({ band: 2, creator: true });
      expect(
        mine.tasks.filter((t) => t.period === 'WEEKLY').map((t) => [t.code, t.target, t.rewardCherries]),
      ).toEqual(DEFAULT_CREATOR_TASKS.map((t) => [t.code, t.bandTargets![1], t.bandRewards![1]]));
      expect(mine.tasks.filter((t) => t.pooled && t.audience === 'CREATORS')).toHaveLength(
        DEFAULT_TASK_POOL_BANDS[1]!.creatorCount,
      );
    } finally {
      await ctx.prisma.taskPoolBand.update({ where: { band: 2 }, data: { minLevel: 10 } });
    }
    // The team's change (task-admin set … --targets … --rewards …) applies from the next read of a weekly task.
    await ctx.prisma.taskDefinition.update({
      where: { code: 'CREATOR_WEEKLY_REELS' },
      data: { bandTargets: [3, 6, 8, 10], bandRewards: [150_000, 190_000, 220_000, 250_000] },
    });
    try {
      const creator = await signup();
      await makeCreator(creator);
      expect(await task(creator, 'CREATOR_WEEKLY_REELS')).toMatchObject({
        target: 3,
        rewardCherries: 150_000,
      });
    } finally {
      await ctx.prisma.taskDefinition.update({
        where: { code: 'CREATOR_WEEKLY_REELS' },
        data: { bandTargets: [5, 6, 8, 10], bandRewards: [180_000, 190_000, 220_000, 250_000] },
      });
    }
    expect(CREATOR_WEEKLY).toHaveLength(6);
  });
});

describe('D297 creator tasks share the host tasks’ caps; claims pay once', { timeout: 300_000 }, () => {
  let ctx: TestContext;
  const h = helpers(() => ctx);
  const { signup, tasks, task, claim, makeCreator, content } = h;

  beforeAll(async () => {
    ctx = await createTestApp({
      LIVE_RANKINGS_TIME_ZONE: noonZone(),
      // Small caps so one creator reaches both: 5 000 a day; $0.11 a month = 100 000 cherries at $1.10 per 1M.
      TASK_DAILY_CAP_CHERRIES: '5000',
      TASK_MONTHLY_CAP_MINOR: '11',
    });
    await keepLegacyTargetsEngine(ctx.prisma);
    await seedDefaultTasksIn(ctx.prisma);
    await seedDefaultTaskPoolIn(ctx.prisma);
    await seedD297TasksIn(ctx.prisma, { generator: false });
  });
  afterAll(async () => ctx?.close());

  it('daily creator claims count toward the same daily cap, weekly ones toward the same monthly cap', async () => {
    const creator = await signup();
    await makeCreator(creator);
    await h.onlyCreatorPool(['P_CR_REEL', 'P_CR_POST']);
    let mine: MyTasks;
    try {
      mine = await tasks(creator);
    } finally {
      await h.allCreatorPool();
    }
    // The same caps a host sees.
    const host = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    const hosts = await tasks(host);
    expect(mine).toMatchObject({ dailyCapCherries: 5_000, monthlyCapCherries: 100_000 });
    expect([hosts.dailyCapCherries, hosts.monthlyCapCherries]).toEqual([5_000, 100_000]);
    // A creator's day never holds «share a post» / «share a reel» next to its creator twins.
    expect(mine.tasks.some((t) => t.code === 'P_POST' || t.code === 'P_REEL')).toBe(false);

    for (let i = 0; i < 5; i++) await content(creator, 'REEL');
    await content(creator, 'POST');
    expect(await task(creator, 'P_CR_REEL')).toMatchObject({ completed: true, rewardCherries: 4_000 });
    expect(await task(creator, 'CREATOR_WEEKLY_REELS')).toMatchObject({ completed: true, progress: 5 });

    // 4 000 of the 5 000 a day.
    const first = await claim(creator, 'P_CR_REEL');
    expect(first.status, JSON.stringify(first.body)).toBe(201);
    expect(first.body).toMatchObject({ paidCherries: 4_000, paidCoins: 0, balanceCherries: 4_000 });
    // 2 000 more: the remainder (1 000), then the day is full.
    const second = await claim(creator, 'P_CR_POST');
    expect(second.status, JSON.stringify(second.body)).toBe(201);
    expect(second.body).toMatchObject({ paidCherries: 1_000 });
    expect(await tasks(creator)).toMatchObject({ dailyEarnedCherries: 5_000, monthlyEarnedCherries: 5_000 });

    // The weekly creator task is outside the daily cap but inside the month's: 180 000 → the 95 000 left.
    const weekly = await claim(creator, 'CREATOR_WEEKLY_REELS');
    expect(weekly.status, JSON.stringify(weekly.body)).toBe(201);
    expect(weekly.body).toMatchObject({ paidCherries: 95_000, balanceCherries: 100_000 });
    expect(await tasks(creator)).toMatchObject({
      dailyEarnedCherries: 5_000,
      monthlyEarnedCherries: 100_000,
    });

    // The month is full: the next creator claim is 409 TASK_MONTHLY_CAP_REACHED (as a host's would be).
    const r = await ctx.prisma.post.findFirstOrThrow({ where: { authorId: creator.id, format: 'REEL' } });
    const fans = [await signup(), await signup()];
    for (const f of fans) {
      const res = await ctx.http
        .post('/api/v1/views')
        .set({ Authorization: `Bearer ${f.token}` })
        .send({ items: [{ postId: r.id, watchedMs: 2_000 }] });
      expect(res.status).toBe(204);
    }
    await ctx.prisma.taskDefinition.update({
      where: { code: 'CREATOR_WEEKLY_VIEWS' },
      data: { bandTargets: [2, 6_000, 8_000, 10_000] },
    });
    try {
      expect(await task(creator, 'CREATOR_WEEKLY_VIEWS')).toMatchObject({ progress: 2, completed: true });
      const full = await claim(creator, 'CREATOR_WEEKLY_VIEWS');
      expect(full.status).toBe(409);
      expect(full.body.error.code).toBe('TASK_MONTHLY_CAP_REACHED');
    } finally {
      await ctx.prisma.taskDefinition.update({
        where: { code: 'CREATOR_WEEKLY_VIEWS' },
        data: { bandTargets: [5_000, 6_000, 8_000, 10_000] },
      });
    }

    // Paid as task cherries (TASK_REWARD, `<code>@<period start>`), locked like every task reward.
    const ledger = await ctx.prisma.cherryLedgerEntry.findMany({
      where: { userId: creator.id, reason: 'TASK_REWARD' },
      orderBy: { createdAt: 'asc' },
      select: { delta: true, referenceId: true },
    });
    expect(ledger.map((l) => Number(l.delta))).toEqual([4_000, 1_000, 95_000]);
    expect(ledger.map((l) => l.referenceId.split('@')[0])).toEqual([
      'P_CR_REEL',
      'P_CR_POST',
      'CREATOR_WEEKLY_REELS',
    ]);
  });

  it('a claim pays once: a repeat is 200 with nothing paid; concurrent claims pay once', async () => {
    const creator = await signup();
    await makeCreator(creator);
    await h.onlyCreatorPool(['P_CR_POST', 'P_CR_REEL']);
    try {
      await tasks(creator);
    } finally {
      await h.allCreatorPool();
    }
    await content(creator, 'POST');
    for (let i = 0; i < 5; i++) await content(creator, 'REEL');
    expect(await task(creator, 'P_CR_POST')).toMatchObject({ completed: true, rewardCherries: 2_000 });

    const once = await claim(creator, 'P_CR_POST');
    expect(once.status, JSON.stringify(once.body)).toBe(201);
    expect(once.body).toMatchObject({ paidCherries: 2_000, task: { claimed: true, claimedCherries: 2_000 } });
    const again = await claim(creator, 'P_CR_POST');
    expect(again.status).toBe(200);
    expect(again.body).toMatchObject({ paidCherries: 2_000, balanceCherries: 2_000 });

    // Five claims of the weekly task at once: one 201, the rest 200, one payout.
    const results = await Promise.all(
      Array.from({ length: 5 }, () => claim(creator, 'CREATOR_WEEKLY_REELS')),
    );
    expect(results.map((r) => r.status).sort()).toEqual([200, 200, 200, 200, 201]);
    const week = (await tasks(creator)).weekStartsAt;
    expect(
      await ctx.prisma.taskClaim.count({ where: { userId: creator.id, taskCode: 'CREATOR_WEEKLY_REELS' } }),
    ).toBe(1);
    const paid = await ctx.prisma.cherryLedgerEntry.findMany({
      where: {
        userId: creator.id,
        reason: 'TASK_REWARD',
        referenceId: { startsWith: 'CREATOR_WEEKLY_REELS@' },
      },
    });
    expect(paid).toHaveLength(1);
    // Within the month's 100 000: 98 000 left after the post's 2 000.
    expect(Number(paid[0]!.delta)).toBe(98_000);
    expect(week).toBeTruthy();
    expect((await task(creator, 'CREATOR_WEEKLY_REELS')).claimedCherries).toBe(98_000);
  });
});

describe('D297 the generated catalogue: by charm level, creators and hosts', { timeout: 300_000 }, () => {
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  const h = helpers(() => ctx);
  const { auth, signup, tasks, task, claim, makeCreator, content } = h;
  let support = '';
  let charm = '';

  const setLevels = async (u: TestUser, supportLevel: number, charmLevel: number) => {
    for (const [categoryId, level] of [
      [support, supportLevel],
      [charm, charmLevel],
    ] as const) {
      await ctx.prisma.userLevelState.upsert({
        where: { userId_categoryId: { userId: u.id, categoryId } },
        create: { userId: u.id, categoryId, currentLevel: level === 0 ? null : level },
        update: { currentLevel: level === 0 ? null : level },
      });
    }
  };
  /** Only `codes` of the audience's generator templates stay on (`task-admin set … --enabled`). */
  const onlyGenerated = async (prefix: 'G_CR_' | 'G_HO_', codes: readonly string[]) => {
    await ctx.prisma.taskDefinition.updateMany({
      where: { code: { startsWith: prefix } },
      data: { enabled: false },
    });
    await ctx.prisma.taskDefinition.updateMany({
      where: { code: { in: [...codes] } },
      data: { enabled: true },
    });
  };
  const generatorOn = (prefix: 'G_CR_' | 'G_HO_', enabled: boolean) =>
    ctx.prisma.taskDefinition.updateMany({ where: { code: { startsWith: prefix } }, data: { enabled } });
  const stored = (u: TestUser) =>
    ctx.prisma.taskAssignment.findMany({ where: { userId: u.id, taskCode: { startsWith: 'G_' } } });

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        LIVE_RANKINGS_TIME_ZONE: noonZone(),
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
      },
      [{ token: LIVE_MEDIA_PROVIDER, value: media }],
    );
    await keepLegacyTargetsEngine(ctx.prisma);
    await seedDefaultTasksIn(ctx.prisma);
    await seedDefaultTaskPoolIn(ctx.prisma);
    // As migration 20270331090200 seeds them: the generator on for both audiences.
    expect(await seedD297TasksIn(ctx.prisma)).toBe(46);
    const level = (code: 'SUPPORT' | 'ATTRACTIVENESS') =>
      ctx.prisma.levelCategory.create({
        data: { code, nameAr: code, nameEn: code, descriptionAr: '-', descriptionEn: '-', isEnabled: true },
      });
    support = (await level('SUPPORT')).id;
    charm = (await level('ATTRACTIVENESS')).id;
  });
  afterAll(async () => ctx?.close());

  it('a creator gets generated creator tasks at their CHARM level (daily share + 6 weekly), harder when higher', async () => {
    const low = await signup();
    const high = await signup();
    const supportOnly = await signup();
    for (const u of [low, high, supportOnly]) await makeCreator(u);
    await setLevels(high, 0, 60);
    // Support 80 but no charm: band 4 for the number of tasks, level 0 for the generated tasks (owner: charm only).
    await setLevels(supportOnly, 80, 0);
    const lows = await tasks(low);
    const highs = await tasks(high);
    const supports = await tasks(supportOnly);
    for (const [mine, band] of [
      [lows, DEFAULT_TASK_POOL_BANDS[0]!],
      [highs, DEFAULT_TASK_POOL_BANDS[3]!],
      [supports, DEFAULT_TASK_POOL_BANDS[3]!],
    ] as const) {
      const pooled = mine.tasks.filter((t) => t.pooled);
      expect(pooled).toHaveLength(band.dailyCount);
      const gen = pooled.filter((t) => t.code.startsWith('G_CR_'));
      expect(gen).toHaveLength(band.creatorCount);
      expect(gen.every((t) => t.audience === 'CREATORS' && t.period === 'DAILY')).toBe(true);
      // Never the hand-made creator pool, the fixed weekly creator tasks or a host task.
      expect(mine.tasks.some((t) => t.code.startsWith('P_CR_') || t.code.startsWith('CREATOR_WEEKLY_'))).toBe(
        false,
      );
      expect(mine.tasks.some((t) => t.audience === 'HOSTS')).toBe(false);
      const weekly = mine.tasks.filter((t) => t.period === 'WEEKLY');
      expect(weekly).toHaveLength(GEN_WEEKLY_COUNT.CREATORS);
      expect(weekly.every((t) => t.code.startsWith('G_CR_') && t.code.endsWith('_W'))).toBe(true);
      // One task per metric in each period; never one action counted twice in the day.
      const day = pooled.map((t) => t.metric);
      expect(new Set(day).size).toBe(day.length);
      expect(new Set(weekly.map((t) => t.metric)).size).toBe(weekly.length);
      expect(mine.tasks.every((t) => !t.name.startsWith('G_'))).toBe(true);
    }
    // The stored variants carry the charm level: 0, 60 and 0 (support does not count).
    const levelOf = async (u: TestUser) =>
      new Set((await stored(u)).map((a) => Number(a.variant!.split('.')[4])));
    expect(await levelOf(low)).toEqual(new Set([0]));
    expect(await levelOf(high)).toEqual(new Set([60]));
    expect(await levelOf(supportOnly)).toEqual(new Set([0]));
    // Level 60 is harder and pays more than level 0 for the same weekly template (the curve).
    const byCode = (m: MyTasks) =>
      new Map(m.tasks.filter((t) => t.period === 'WEEKLY').map((t) => [t.code, t]));
    const [l, hi] = [byCode(lows), byCode(highs)];
    const shared = [...l.keys()].filter((c) => hi.has(c));
    expect(shared.length).toBeGreaterThan(0);
    let harder = 0;
    for (const c of shared) {
      expect(hi.get(c)!.rewardCherries).toBeGreaterThan(l.get(c)!.rewardCherries * 1.1);
      if (hi.get(c)!.target > l.get(c)!.target) harder++;
    }
    expect(harder).toBeGreaterThan(0);
    // Stable on reload.
    expect((await tasks(high)).tasks.map((t) => [t.code, t.target, t.rewardCherries])).toEqual(
      highs.tasks.map((t) => [t.code, t.target, t.rewardCherries]),
    );
  });

  it('a host gets generated host tasks (daily share + 4 weekly); a viewer and a creator never get the others', async () => {
    const host = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    await setLevels(host, 0, 30);
    const mine = await tasks(host);
    const band = DEFAULT_TASK_POOL_BANDS[2]!; // charm 30: band 3
    expect(mine.tasks.filter((t) => t.pooled && t.code.startsWith('G_HO_'))).toHaveLength(band.hostCount);
    const weekly = mine.tasks.filter((t) => t.period === 'WEEKLY');
    expect(weekly).toHaveLength(GEN_WEEKLY_COUNT.HOSTS);
    expect(weekly.every((t) => t.code.startsWith('G_HO_') && t.audience === 'HOSTS')).toBe(true);
    expect(mine.tasks.some((t) => ['HOST_LIVE_MINUTES', 'HOST_GIFT_COINS'].includes(t.code))).toBe(false);
    expect(mine.tasks.some((t) => t.audience === 'CREATORS')).toBe(false);
    expect(new Set((await stored(host)).map((a) => a.variant!.split('.')[4]))).toEqual(new Set(['30']));

    const viewer = await signup();
    expect((await tasks(viewer)).tasks.some((t) => t.code.startsWith('G_'))).toBe(false);
    expect((await claim(viewer, weekly[0]!.code)).status).toBe(404);
    const creator = await signup();
    await makeCreator(creator);
    await ctx.prisma.liveHost.create({ data: { userId: creator.id, source: 'ADMIN' } });
    const theirs = await tasks(creator);
    expect(theirs.tasks.some((t) => t.code.startsWith('G_HO_'))).toBe(false);
    expect(theirs.tasks.some((t) => t.code.startsWith('G_CR_'))).toBe(true);
    expect((await claim(creator, weekly[0]!.code)).status).toBe(404);

    // A host claims a generated task (once): only «new followers» switched on for their first day.
    const claimer = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: claimer.id, source: 'ADMIN' } });
    await onlyGenerated('G_HO_', ['G_HO_NEW_FOLLOWERS_D']);
    let claimers: MyTasks;
    try {
      claimers = await tasks(claimer);
    } finally {
      await generatorOn('G_HO_', true);
    }
    const followers = claimers.tasks.find((t) => t.code === 'G_HO_NEW_FOLLOWERS_D')!;
    expect(followers).toMatchObject({ audience: 'HOSTS', pooled: true, progress: 0 });
    for (let i = 0; i < followers.target; i++) {
      const fan = await signup();
      const res = await ctx.http.put(`/api/v1/users/${claimer.username}/follow`).set(auth(fan));
      expect(res.status).toBeLessThan(300);
    }
    const paid = await claim(claimer, 'G_HO_NEW_FOLLOWERS_D');
    expect(paid.status, JSON.stringify(paid.body)).toBe(201);
    expect(paid.body.paidCherries).toBe(followers.rewardCherries);
    expect((await claim(claimer, 'G_HO_NEW_FOLLOWERS_D')).status).toBe(200);
  });

  it('generated tasks are claimed once (daily and weekly), under the shared caps', async () => {
    const creator = await signup();
    await makeCreator(creator);
    await onlyGenerated('G_CR_', ['G_CR_POSTS_D', 'G_CR_REELS_D', 'G_CR_POSTS_W']);
    let mine: MyTasks;
    try {
      mine = await tasks(creator);
    } finally {
      await generatorOn('G_CR_', true);
    }
    const gen = mine.tasks.filter((t) => t.code.startsWith('G_CR_'));
    expect(gen.map((t) => t.code).sort()).toEqual(['G_CR_POSTS_D', 'G_CR_POSTS_W', 'G_CR_REELS_D']);
    // Everyone's «share a post» / «share a reel» never sit next to them.
    expect(mine.tasks.some((t) => t.code === 'P_POST' || t.code === 'P_REEL')).toBe(false);
    const weeklyTarget = gen.find((t) => t.code === 'G_CR_POSTS_W')!.target;
    for (let i = 0; i < weeklyTarget; i++) await content(creator, 'POST');
    await content(creator, 'REEL');
    for (const code of ['G_CR_POSTS_D', 'G_CR_REELS_D', 'G_CR_POSTS_W']) {
      expect(await task(creator, code)).toMatchObject({ completed: true });
    }
    const first = await claim(creator, 'G_CR_POSTS_D');
    expect(first.status, JSON.stringify(first.body)).toBe(201);
    const reward = gen.find((t) => t.code === 'G_CR_POSTS_D')!.rewardCherries;
    expect(first.body).toMatchObject({ paidCherries: reward, task: { claimed: true } });
    const again = await claim(creator, 'G_CR_POSTS_D');
    expect(again.status).toBe(200);
    expect(again.body.paidCherries).toBe(reward);
    const weekly = await Promise.all([1, 2, 3].map(() => claim(creator, 'G_CR_POSTS_W')));
    expect(weekly.map((r) => r.status).sort()).toEqual([200, 200, 201]);
    const day = (await tasks(creator)).day;
    const refs = (
      await ctx.prisma.cherryLedgerEntry.findMany({
        where: { userId: creator.id, reason: 'TASK_REWARD' },
        select: { referenceId: true },
      })
    ).map((r) => r.referenceId);
    expect(refs).toContain(`G_CR_POSTS_D@${day}`);
    expect(refs.filter((r) => r.startsWith('G_CR_POSTS_W@'))).toHaveLength(1);
    expect(await ctx.prisma.taskClaim.count({ where: { userId: creator.id } })).toBe(2);
    // Every generated reward is within the caps the creator sees.
    const now = await tasks(creator);
    for (const t of now.tasks.filter((x) => x.code.startsWith('G_'))) {
      if (t.period === 'DAILY') expect(t.rewardCherries).toBeLessThanOrEqual(now.dailyCapCherries);
      else expect(t.rewardCherries).toBeLessThanOrEqual(now.monthlyCapCherries);
    }
  });

  it('switched off for an audience (task-admin generator off): the hand-made tasks again', async () => {
    await generatorOn('G_CR_', false);
    await generatorOn('G_HO_', false);
    try {
      const creator = await signup();
      await makeCreator(creator);
      const mine = await tasks(creator);
      expect(mine.tasks.some((t) => t.code.startsWith('G_'))).toBe(false);
      expect(mine.tasks.filter((t) => t.code.startsWith('P_CR_'))).toHaveLength(
        DEFAULT_TASK_POOL_BANDS[0]!.creatorCount,
      );
      expect(mine.tasks.filter((t) => t.period === 'WEEKLY')).toHaveLength(6);

      // HOST_LIVE_DAYS (fixed HOST_WEEKLY_LIVE_DAYS): a day with a live of 10 minutes or more.
      const host = await signup();
      await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
      expect((await tasks(host)).tasks.filter((t) => t.period === 'WEEKLY')).toHaveLength(4);
      const room = await ctx.http.post('/api/v1/live/rooms').set(auth(host)).send({ title: 'Days' });
      expect(room.status, JSON.stringify(room.body)).toBe(201);
      const at = (minutes: number) => new Date(Date.now() - minutes * 60_000);
      await ctx.prisma.liveRoom.update({
        where: { id: room.body.id as string },
        data: { startedAt: at(5), lastHeartbeatAt: new Date() },
      });
      expect(await task(host, 'HOST_WEEKLY_LIVE_DAYS')).toMatchObject({ progress: 0, target: 3 });
      await ctx.prisma.liveRoom.update({
        where: { id: room.body.id as string },
        data: { startedAt: at(20) },
      });
      expect(await task(host, 'HOST_WEEKLY_LIVE_DAYS')).toMatchObject({ progress: 1 });
    } finally {
      await generatorOn('G_CR_', true);
      await generatorOn('G_HO_', true);
    }
  });
});
