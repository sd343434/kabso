import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import {
  DEFAULT_CREATOR_POOL_TASKS,
  DEFAULT_CREATOR_TASKS,
  DEFAULT_D297_HOST_TASKS,
  DEFAULT_POOL_TASKS,
  DEFAULT_TASKS,
  DEFAULT_TASK_POOL_BANDS,
  TASK_METRICS,
  TASK_POOL_BANDS,
  TASK_POOL_GROUPS,
  assignDailyTasks,
  audienceOffered,
  seedOf,
  taskRoleOf,
  type PoolTemplate,
} from './programs-rules.js';
import { assignSmartTasks, taskSeed, type TaskProfile, type TaskTemplate } from './task-catalogue.js';

// v1.94-social (D297, CONVENTIONS §10.110): tasks for content creators «مهام صانع المحتوى», valued like the host tasks.

const ALL_POOL = [...DEFAULT_POOL_TASKS, ...DEFAULT_CREATOR_POOL_TASKS].filter((t) => t.enabled !== false);
const pool: PoolTemplate[] = ALL_POOL.map((t) => ({
  code: t.code,
  group: t.group,
  audience: t.audience,
  metric: t.metric,
  bandTargets: t.bandTargets,
  bandRewards: t.bandRewards,
  sortOrder: t.sortOrder,
}));
const smart: TaskTemplate[] = ALL_POOL.map((t) => ({
  code: t.code,
  metric: t.metric,
  group: t.group,
  audience: t.audience,
  bandTargets: t.bandTargets,
  bandRewards: t.bandRewards,
  sortOrder: t.sortOrder,
  nameAr: t.nameAr,
  nameEn: t.nameEn,
}));
const byCode = new Map(ALL_POOL.map((t) => [t.code, t]));
const band = (n: number) => DEFAULT_TASK_POOL_BANDS[n - 1]!;
const host = (code: string) => DEFAULT_POOL_TASKS.find((t) => t.code === code)!;
const hostWeekly = (code: string) => DEFAULT_TASKS.find((t) => t.code === code)!;
const NEW_METRICS = [
  'REEL_VIEWS_RECEIVED',
  'LIKES_RECEIVED',
  'COMMENT_REPLIES',
  'NEW_FOLLOWERS',
  'SHARES_RECEIVED',
] as const;

const migration = readFileSync(
  fileURLToPath(
    new URL('../../../prisma/migrations/20270331090100_creator_tasks/migration.sql', import.meta.url),
  ),
  'utf8',
).replace(/\s+/g, ' ');

describe('D297 the creator tasks: defaults', () => {
  it('the new metrics and the CREATOR group exist; every creator task is for CREATORS only', () => {
    for (const m of NEW_METRICS) expect(TASK_METRICS).toContain(m);
    expect(TASK_POOL_GROUPS).toContain('CREATOR');
    for (const t of DEFAULT_CREATOR_POOL_TASKS) {
      expect(t).toMatchObject({ audience: 'CREATORS', group: 'CREATOR' });
      expect(t.code).toMatch(/^P_CR_[A-Z_]+$/);
      expect(t.bandTargets).toHaveLength(TASK_POOL_BANDS);
      expect(t.bandRewards).toHaveLength(TASK_POOL_BANDS);
      for (let i = 1; i < TASK_POOL_BANDS; i++) {
        expect(t.bandTargets[i]!).toBeGreaterThanOrEqual(t.bandTargets[i - 1]!);
        expect(t.bandRewards[i]!).toBeGreaterThan(t.bandRewards[i - 1]!);
      }
    }
    for (const t of DEFAULT_CREATOR_TASKS) {
      expect(t).toMatchObject({ audience: 'CREATORS', period: 'WEEKLY' });
      // A banded weekly task's target and reward mirror band 4.
      expect(t.target).toBe(t.bandTargets![3]);
      expect(t.rewardCherries).toBe(t.bandRewards![3]);
    }
    // Codes never collide with the other defaults.
    const codes = [
      ...DEFAULT_TASKS,
      ...DEFAULT_POOL_TASKS,
      ...DEFAULT_CREATOR_POOL_TASKS,
      ...DEFAULT_CREATOR_TASKS,
    ];
    expect(new Set(codes.map((t) => t.code)).size).toBe(codes.length);
    // The proposed actions: reel, post, story, views, likes, replies (daily); reels, views, followers, shares (weekly).
    expect(DEFAULT_CREATOR_POOL_TASKS.map((t) => t.metric)).toEqual([
      'REELS',
      'POSTS',
      'STORIES',
      'REEL_VIEWS_RECEIVED',
      'LIKES_RECEIVED',
      'COMMENT_REPLIES',
    ]);
    expect(DEFAULT_CREATOR_TASKS.map((t) => [t.metric, t.bandTargets![0]])).toEqual([
      ['REELS', 5],
      ['REEL_VIEWS_RECEIVED', 5_000],
      ['NEW_FOLLOWERS', 50],
      ['SHARES_RECEIVED', 20],
      // Owner follow-up: six weekly creator tasks.
      ['LIKES_RECEIVED', 200],
      ['STORIES', 5],
    ]);
    // …and four weekly host tasks: the two of D188 and two more on the live-minutes ladder.
    expect(DEFAULT_D297_HOST_TASKS.map((t) => [t.code, t.metric, t.bandTargets, t.bandRewards])).toEqual([
      ['HOST_WEEKLY_LIVE_DAYS', 'HOST_LIVE_DAYS', [3, 4, 5, 6], hostWeekly('HOST_LIVE_MINUTES').bandRewards],
      ['HOST_WEEKLY_PK_BATTLES', 'PK_BATTLES', [5, 6, 8, 10], hostWeekly('HOST_LIVE_MINUTES').bandRewards],
    ]);
    expect(DEFAULT_TASKS.filter((t) => t.audience === 'HOSTS' && t.period === 'WEEKLY').length + 2).toBe(4);
  });

  it('the rewards are the host tasks’ own ladders, band by band («قيمتها كمهام المضيف»)', () => {
    const daily = (code: string) => DEFAULT_CREATOR_POOL_TASKS.find((t) => t.code === code)!.bandRewards;
    expect(daily('P_CR_REEL')).toEqual(host('P_HOST_LIVE_30').bandRewards);
    expect(daily('P_CR_POST')).toEqual(host('P_HOST_GUEST').bandRewards);
    expect(daily('P_CR_REPLIES')).toEqual(host('P_HOST_GUEST').bandRewards);
    expect(daily('P_CR_STORY')).toEqual(host('P_PK_BATTLES').bandRewards);
    expect(daily('P_CR_VIEWS')).toEqual(host('P_PK_WINS').bandRewards);
    expect(daily('P_CR_LIKES')).toEqual(host('P_PK_WINS').bandRewards);
    const weekly = (code: string) => DEFAULT_CREATOR_TASKS.find((t) => t.code === code)!.bandRewards;
    expect(weekly('CREATOR_WEEKLY_REELS')).toEqual(hostWeekly('HOST_LIVE_MINUTES').bandRewards);
    expect(weekly('CREATOR_WEEKLY_VIEWS')).toEqual(hostWeekly('HOST_LIVE_MINUTES').bandRewards);
    expect(weekly('CREATOR_WEEKLY_FOLLOWERS')).toEqual(hostWeekly('HOST_GIFT_COINS').bandRewards);
    expect(weekly('CREATOR_WEEKLY_SHARES')).toEqual(hostWeekly('HOST_GIFT_COINS').bandRewards);
    // The weekly targets scale like the weekly live minutes (300 · 360 · 480 · 600 = ×1 · ×1.2 · ×1.6 · ×2).
    const live = hostWeekly('HOST_LIVE_MINUTES').bandTargets!;
    for (const t of DEFAULT_CREATOR_TASKS) {
      const base = t.bandTargets![0];
      expect(t.bandTargets!.map((x) => x / base)).toEqual(live.map((x) => x / live[0]));
    }
    // A band's creator count mirrors its host count.
    for (const b of DEFAULT_TASK_POOL_BANDS) expect(b.creatorCount).toBe(b.hostCount);
  });

  it('the migration seeds the same rows', () => {
    for (const t of DEFAULT_CREATOR_POOL_TASKS) {
      expect(migration, t.code).toContain(
        `('${t.code}', 'DAILY', '${t.metric}', ${String(Math.max(...t.bandTargets))}, ${String(Math.max(...t.bandRewards))}, '${t.audience}', '${t.nameAr}', '${t.nameEn}', ${String(t.sortOrder)}, true, '${t.group}', ARRAY[${t.bandTargets.join(', ')}], ARRAY[${t.bandRewards.join(', ')}])`,
      );
    }
    const followUp = readFileSync(
      fileURLToPath(
        new URL('../../../prisma/migrations/20270331090200_task_generator/migration.sql', import.meta.url),
      ),
      'utf8',
    ).replace(/\s+/g, ' ');
    for (const t of [...DEFAULT_CREATOR_TASKS, ...DEFAULT_D297_HOST_TASKS]) {
      const sql =
        ['CREATOR_WEEKLY_LIKES', 'CREATOR_WEEKLY_STORIES'].includes(t.code) || t.audience === 'HOSTS'
          ? followUp
          : migration;
      expect(sql, t.code).toContain(
        `('${t.code}', 'WEEKLY', '${t.metric}', ${String(t.target)}, ${String(t.rewardCherries)}, '${t.audience}', '${t.nameAr}', '${t.nameEn}', ${String(t.sortOrder)}, false, NULL, ARRAY[${t.bandTargets!.join(', ')}], ARRAY[${t.bandRewards!.join(', ')}])`,
      );
    }
    for (const m of NEW_METRICS) expect(migration).toContain(`'${m}'`);
    expect(migration).toContain(`'HOST', 'CREATOR')`);
    expect(migration).toContain('UPDATE "task_pool_bands" SET "creator_count" = "host_count";');
  });
});

describe('D297 who gets them', () => {
  it('a creator-programme member is a creator and never a host for the tasks, even with a hosting permission', () => {
    expect(taskRoleOf(true, false)).toEqual({ host: true, creator: false });
    expect(taskRoleOf(true, true)).toEqual({ host: false, creator: true });
    expect(taskRoleOf(false, true)).toEqual({ host: false, creator: true });
    expect(taskRoleOf(false, false)).toEqual({ host: false, creator: false });
    const creator = taskRoleOf(true, true);
    expect(audienceOffered('EVERYONE', creator)).toBe(true);
    expect(audienceOffered('CREATORS', creator)).toBe(true);
    expect(audienceOffered('HOSTS', creator)).toBe(false);
    expect(audienceOffered('CREATORS', taskRoleOf(true, false))).toBe(false);
    expect(audienceOffered('UNKNOWN', creator)).toBe(false);
  });

  it('D176 pool: a creator gets the band’s creator count of CREATOR tasks first, no HOST task, no double count', () => {
    for (let n = 1; n <= TASK_POOL_BANDS; n++) {
      for (let user = 0; user < 40; user++) {
        const s = seedOf(`creator-${String(user)}:2026-11-06`);
        // D295 gives a member a hosting permission: still a creator.
        const picks = assignDailyTasks(pool, band(n), true, s, true);
        expect(picks).toHaveLength(band(n).dailyCount);
        const groups = picks.map((p) => byCode.get(p.code)!.group);
        expect(groups.slice(0, band(n).creatorCount)).toEqual(
          new Array(band(n).creatorCount).fill('CREATOR'),
        );
        expect(groups.filter((g) => g === 'CREATOR')).toHaveLength(band(n).creatorCount);
        expect(groups).not.toContain('HOST');
        const metrics = picks.map((p) => byCode.get(p.code)!.metric);
        expect(new Set(metrics).size, metrics.join()).toBe(metrics.length);
        // Each pick carries the band's own target and reward.
        for (const p of picks) {
          expect(p.target).toBe(byCode.get(p.code)!.bandTargets[n - 1]);
          expect(p.rewardCherries).toBe(byCode.get(p.code)!.bandRewards[n - 1]);
        }
        // The same person and day: the same list.
        expect(assignDailyTasks(pool, band(n), true, s, true)).toEqual(picks);
        // A host and a viewer never get a creator task.
        for (const isHost of [true, false]) {
          expect(
            assignDailyTasks(pool, band(n), isHost, s).some((p) => byCode.get(p.code)!.group === 'CREATOR'),
          ).toBe(false);
        }
      }
    }
  });

  it('D176 pool: the creator templates do not change a non-creator’s list', () => {
    const others = pool.filter((t) => t.audience !== 'CREATORS');
    for (let user = 0; user < 20; user++) {
      const s = seedOf(`u-${String(user)}:2026-11-06`);
      for (const isHost of [true, false]) {
        expect(assignDailyTasks(pool, band(2), isHost, s)).toEqual(
          assignDailyTasks(others, band(2), isHost, s),
        );
      }
    }
  });

  it('D281 smart assignment: a creator gets CREATOR tasks first, never HOST ones; others never get CREATOR ones', () => {
    const profile = (over: Partial<TaskProfile>): TaskProfile => ({
      band: band(4),
      isHost: false,
      dailyAverage: {},
      recentAssigned: 0,
      recentClaimed: 0,
      recentVariants: [],
      yesterdayTemplates: [],
      inFamily: false,
      favouriteGifts: [],
      activeHours: new Array<number>(24).fill(0),
      ...over,
    });
    for (let user = 0; user < 30; user++) {
      const seed = taskSeed(`creator-${String(user)}`, '2026-11-06');
      const picks = assignSmartTasks(smart, profile({ isHost: true, isCreator: true }), [], seed);
      expect(picks).toHaveLength(band(4).dailyCount);
      const groups = picks.map((p) => byCode.get(p.template)!.group);
      expect(groups.slice(0, band(4).creatorCount)).toEqual(new Array(band(4).creatorCount).fill('CREATOR'));
      expect(groups).not.toContain('HOST');
      const metrics = picks.map((p) => byCode.get(p.template)!.metric);
      expect(new Set(metrics).size).toBe(metrics.length);
      for (const p of picks.filter((x) => byCode.get(x.template)!.group === 'CREATOR')) {
        expect(p.rewardCherries).toBeGreaterThan(0);
        expect(p.variant.code.startsWith(`K.${p.template}.*.`)).toBe(true);
      }
      for (const isHost of [true, false]) {
        const other = assignSmartTasks(smart, profile({ isHost }), [], seed);
        expect(other.some((p) => byCode.get(p.template)!.group === 'CREATOR')).toBe(false);
      }
    }
  });
});
