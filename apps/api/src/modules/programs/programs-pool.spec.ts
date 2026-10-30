import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import {
  DEFAULT_POOL_TASKS,
  DEFAULT_TASK_POOL_BANDS,
  TASK_METRICS,
  TASK_POOL_BANDS,
  TASK_POOL_GROUPS,
  assignDailyTasks,
  bandForLevel,
  seedOf,
  type PoolTemplate,
} from './programs-rules.js';

// v1.50-social (D176, CONVENTIONS §10.41.1): the daily task pool's pure rules.

const templates: PoolTemplate[] = DEFAULT_POOL_TASKS.map((t) => ({
  code: t.code,
  group: t.group,
  audience: t.audience,
  bandTargets: t.bandTargets,
  bandRewards: t.bandRewards,
  sortOrder: t.sortOrder,
}));
const band = (n: number) => DEFAULT_TASK_POOL_BANDS[n - 1]!;
const seed = (user: string, day: string) => seedOf(`${user}:${day}`);
const byCode = new Map(DEFAULT_POOL_TASKS.map((t) => [t.code, t]));

describe('the default pool and bands (D176)', () => {
  it('every template has a known metric and group, one target and reward per band, both 0 or both set', () => {
    expect(DEFAULT_POOL_TASKS.length).toBeGreaterThanOrEqual(15);
    for (const t of DEFAULT_POOL_TASKS) {
      expect(TASK_METRICS).toContain(t.metric);
      expect(TASK_POOL_GROUPS).toContain(t.group);
      expect(t.code).toMatch(/^P_[A-Z0-9_]+$/);
      expect(t.bandTargets).toHaveLength(TASK_POOL_BANDS);
      expect(t.bandRewards).toHaveLength(TASK_POOL_BANDS);
      for (let i = 0; i < TASK_POOL_BANDS; i++) expect(t.bandTargets[i] === 0).toBe(t.bandRewards[i] === 0);
      // A higher band never has an easier target or a smaller reward.
      for (let i = 1; i < TASK_POOL_BANDS; i++) {
        expect(t.bandTargets[i]!).toBeGreaterThanOrEqual(t.bandTargets[i - 1]!);
        expect(t.bandRewards[i]!).toBeGreaterThanOrEqual(t.bandRewards[i - 1]!);
      }
      expect(t.audience === 'HOSTS').toBe(t.group === 'HOST');
    }
    expect(new Set(DEFAULT_POOL_TASKS.map((t) => t.code)).size).toBe(DEFAULT_POOL_TASKS.length);
  });

  it('the migration seeds the same pool and bands', () => {
    const sql = readFileSync(
      fileURLToPath(
        new URL('../../../prisma/migrations/20261230090000_daily_task_pool/migration.sql', import.meta.url),
      ),
      'utf8',
    );
    // D184: seeded in coins; migration 20261231110000_task_cherries made every reward cherries (×10).
    for (const t of DEFAULT_POOL_TASKS) {
      const coins = t.bandRewards.map((r) => r / 10);
      expect(sql).toContain(
        `('${t.code}', 'DAILY', '${t.metric}', ${String(Math.max(...t.bandTargets))}, ${String(Math.max(...coins))}, ` +
          `'${t.audience}', '${t.nameAr}', '${t.nameEn.replace(/'/g, "''")}', ${String(t.sortOrder)}, true, '${t.group}', ` +
          `ARRAY[${t.bandTargets.join(', ')}], ARRAY[${coins.join(', ')}])`,
      );
    }
    const cherries = readFileSync(
      fileURLToPath(
        new URL('../../../prisma/migrations/20261231110000_task_cherries/migration.sql', import.meta.url),
      ),
      'utf8',
    );
    expect(cherries).toContain('"reward_cherries" = "reward_cherries" * 10');
    expect(cherries).toContain('SELECT r * 10 FROM unnest("band_rewards")');
    for (const b of DEFAULT_TASK_POOL_BANDS) {
      expect(sql).toContain(
        `(${String(b.band)}, ${String(b.minLevel)}, ${String(b.dailyCount)}, ${String(b.hostCount)}, '${b.nameAr}', '${b.nameEn}')`,
      );
    }
    // Rewards are coins only (owner 2026-10-30): no experience column.
    expect(sql).not.toMatch(/exp_reward|expReward/i);
  });

  it('bands by the higher of Support and Charm levels: 0–9, 10–29, 30–59, 60+', () => {
    const b = (level: number) => bandForLevel(level, DEFAULT_TASK_POOL_BANDS).band;
    expect([0, 9, 10, 29, 30, 59, 60, 100].map(b)).toEqual([1, 1, 2, 2, 3, 3, 4, 4]);
    // Order of the rows does not matter.
    expect(bandForLevel(45, [...DEFAULT_TASK_POOL_BANDS].reverse()).band).toBe(3);
  });
});

describe('assignDailyTasks (D176)', () => {
  it('is deterministic per person and day, and differs between people and days', () => {
    const a = assignDailyTasks(templates, band(2), false, seed('u1', '2026-10-30'));
    expect(assignDailyTasks(templates, band(2), false, seed('u1', '2026-10-30'))).toEqual(a);
    const others = [
      assignDailyTasks(templates, band(2), false, seed('u2', '2026-10-30')),
      assignDailyTasks(templates, band(2), false, seed('u1', '2026-10-31')),
    ];
    for (const o of others) expect(o.map((p) => p.code)).not.toEqual(a.map((p) => p.code));
    // The input order does not matter (the templates are sorted first).
    expect(assignDailyTasks([...templates].reverse(), band(2), false, seed('u1', '2026-10-30'))).toEqual(a);
  });

  it("gives the band's number of tasks, no duplicates, varied groups, the band's target and reward", () => {
    for (let n = 1; n <= TASK_POOL_BANDS; n++) {
      for (let day = 1; day <= 30; day++) {
        const picks = assignDailyTasks(templates, band(n), false, seed('person', `2026-11-${String(day)}`));
        expect(picks).toHaveLength(band(n).dailyCount);
        expect(new Set(picks.map((p) => p.code)).size).toBe(picks.length);
        expect(picks.map((p) => p.position)).toEqual(picks.map((_, i) => i));
        const groups = picks.map((p) => byCode.get(p.code)!.group);
        // Six groups for everyone: the first six picks are of six different groups.
        expect(new Set(groups.slice(0, 6)).size).toBe(6);
        for (const g of new Set(groups)) expect(groups.filter((x) => x === g).length).toBeLessThanOrEqual(2);
        for (const p of picks) {
          const t = byCode.get(p.code)!;
          expect(t.audience).toBe('EVERYONE');
          expect(p.target).toBe(t.bandTargets[n - 1]);
          expect(p.rewardCherries).toBe(t.bandRewards[n - 1]);
          expect(p.target).toBeGreaterThan(0);
        }
      }
    }
  });

  it('a template not offered in a band (target 0) is never picked there', () => {
    for (let day = 1; day <= 60; day++) {
      const picks = assignDailyTasks(templates, band(1), true, seed('x', `d${String(day)}`));
      expect(picks.map((p) => p.code)).not.toContain('P_SEND_GIFTS');
      expect(picks.map((p) => p.code)).not.toContain('P_REEL');
    }
  });

  it('higher bands get harder targets and bigger rewards for the same task', () => {
    const totals = [1, 2, 3, 4].map((n) => {
      let target = 0;
      let reward = 0;
      for (let day = 1; day <= 40; day++) {
        for (const p of assignDailyTasks(templates, band(n), false, seed('same', `day-${String(day)}`))) {
          target += p.target / byCode.get(p.code)!.bandTargets[3];
          reward += p.rewardCherries;
        }
      }
      return { target, reward };
    });
    for (let n = 1; n < 4; n++) {
      expect(totals[n]!.target).toBeGreaterThan(totals[n - 1]!.target);
      expect(totals[n]!.reward).toBeGreaterThan(totals[n - 1]!.reward);
    }
  });

  it("hosts get the band's host tasks first; others never get host tasks", () => {
    for (let n = 1; n <= TASK_POOL_BANDS; n++) {
      const host = assignDailyTasks(templates, band(n), true, seed('host', '2026-10-30'));
      expect(host).toHaveLength(band(n).dailyCount);
      const hostCodes = host.filter((p) => byCode.get(p.code)!.audience === 'HOSTS');
      expect(hostCodes).toHaveLength(band(n).hostCount);
      expect(host.slice(0, band(n).hostCount)).toEqual(hostCodes);
      const viewer = assignDailyTasks(templates, band(n), false, seed('host', '2026-10-30'));
      expect(viewer.some((p) => byCode.get(p.code)!.audience === 'HOSTS')).toBe(false);
    }
  });

  it('fewer templates than the band asks for: all of them; none: nothing', () => {
    const two = templates.filter((t) => t.code === 'P_FOLLOW' || t.code === 'P_POST');
    expect(
      assignDailyTasks(two, band(4), false, 1)
        .map((p) => p.code)
        .sort(),
    ).toEqual(['P_FOLLOW', 'P_POST']);
    expect(assignDailyTasks([], band(4), true, 1)).toEqual([]);
  });
});
