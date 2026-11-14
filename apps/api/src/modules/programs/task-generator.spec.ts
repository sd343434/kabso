import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { TASK_METRICS, monthlyCapCherries } from './programs-rules.js';
import {
  GEN_CHERRIES_PER_COIN,
  GEN_DEFAULT_STEP,
  GEN_ENTRIES,
  GEN_LEVEL_MAX,
  GEN_STEPS,
  GEN_VARIANTS,
  GEN_WEEKLY_COUNT,
  assignGenerated,
  enumerateGenCodes,
  genCatalogueCount,
  genEntriesOf,
  genLevel,
  genName,
  genReward,
  genTarget,
  genTaskAt,
  genTemplateCode,
  isGenTemplateCode,
  type GenAudience,
  type GenCaps,
} from './task-generator.js';

// D297 follow-up (owner 2026-11-06, CONVENTIONS §10.110.1): the generated catalogue of creator and host tasks.

const AUDIENCES: readonly GenAudience[] = ['CREATORS', 'HOSTS'];
/** The owner's defaults: 50 000 a day, $5 a month at $1.10 per 1 000 000. */
const CAPS: GenCaps = { dailyCherries: 50_000, monthlyCherries: monthlyCapCherries(500, 1_000_000, 110) };

/** 32-bit FNV-1a over every code, in order: a fingerprint of the whole catalogue. */
function fingerprint(audience: GenAudience): { count: number; hash: number } {
  let h = 0x811c9dc5;
  let count = 0;
  for (const code of enumerateGenCodes(audience)) {
    count++;
    for (let i = 0; i < code.length; i++) {
      h ^= code.charCodeAt(i);
      h = Math.imul(h, 0x01000193) >>> 0;
    }
    h ^= 0x0a;
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return { count, hash: h >>> 0 };
}

const templatesOf = (audience: GenAudience, period: 'DAILY' | 'WEEKLY') =>
  genEntriesOf(audience)
    .filter((x) => x.period === period)
    .map(genTemplateCode);

describe('D297 the generated catalogue', () => {
  it('holds at least 300 000 distinct tasks per audience (counted, then every code enumerated)', () => {
    for (const audience of AUDIENCES) {
      const count = genCatalogueCount(audience);
      expect(count).toBeGreaterThanOrEqual(300_000);
      expect(count).toBe(genEntriesOf(audience).length * (GEN_LEVEL_MAX + 1) * GEN_STEPS * GEN_VARIANTS);
      const seen = new Set<string>();
      for (const code of enumerateGenCodes(audience)) seen.add(code);
      expect(seen.size).toBe(count);
    }
    // No code is shared by the two audiences.
    expect(genTaskAt('CREATORS', 0).code.startsWith('G.CR.')).toBe(true);
    expect(genTaskAt('HOSTS', 0).code.startsWith('G.HO.')).toBe(true);
  });

  it('codes are stable: the same fingerprint every run (a change to the catalogue changes it on purpose)', () => {
    const a = fingerprint('CREATORS');
    expect(fingerprint('CREATORS')).toEqual(a);
    expect(a.count).toBe(315_120);
    expect(fingerprint('HOSTS').count).toBe(315_120);
    expect(genTaskAt('CREATORS', 0).code).toBe('G.CR.REELS.D.0.0.0');
    expect(genTaskAt('CREATORS', 123_456).code).toBe(genTaskAt('CREATORS', 123_456).code);
    expect(genTaskAt('HOSTS', 315_119).code).toBe('G.HO.NEW_FOLLOWERS.W.100.12.14');
    // The fingerprints of this version (update deliberately when the catalogue changes).
    expect(a.hash.toString(16)).toBe('4a0a340b');
    expect(fingerprint('HOSTS').hash.toString(16)).toBe('ea25261');
  });

  it('one template row per metric and period; metrics known; names in both languages', () => {
    for (const audience of AUDIENCES) {
      const codes = genEntriesOf(audience).map(genTemplateCode);
      expect(new Set(codes).size).toBe(codes.length);
      expect(codes.length).toBe(16);
      for (const code of codes) {
        expect(isGenTemplateCode(code)).toBe(true);
        expect(code).toMatch(/^[A-Z][A-Z0-9_]{1,39}$/);
      }
      // Enough weekly entries for the owner's weekly counts.
      expect(genEntriesOf(audience).filter((x) => x.period === 'WEEKLY').length).toBeGreaterThanOrEqual(
        GEN_WEEKLY_COUNT[audience],
      );
    }
    expect(GEN_WEEKLY_COUNT).toEqual({ CREATORS: 6, HOSTS: 4 });
    for (const entry of GEN_ENTRIES) {
      expect(TASK_METRICS).toContain(entry.metric);
      for (let v = 0; v < GEN_VARIANTS; v++) {
        const n = genName(entry, v);
        expect(n.ar.length).toBeGreaterThan(5);
        expect(n.en).not.toContain(entry.metric);
        expect(n.ar.length).toBeLessThanOrEqual(160);
      }
    }
    expect(isGenTemplateCode('P_CR_REEL')).toBe(false);
    expect(isGenTemplateCode('HOST_LIVE_MINUTES')).toBe(false);
  });

  it('targets and rewards rise with the charm level (never fall), smoothly, from level 0 to 100', () => {
    for (const entry of GEN_ENTRIES) {
      for (let step = 0; step < GEN_STEPS; step++) {
        for (let level = 1; level <= GEN_LEVEL_MAX; level++) {
          expect(genTarget(entry, level, step)).toBeGreaterThanOrEqual(genTarget(entry, level - 1, step));
          expect(genReward(entry, level, step)).toBeGreaterThanOrEqual(genReward(entry, level - 1, step));
        }
      }
      if (entry.max === undefined && entry.t60 > entry.t0) {
        // Strictly harder at the top than at the bottom, and more than four coarse values along the way.
        expect(genTarget(entry, 100, GEN_DEFAULT_STEP)).toBeGreaterThan(
          genTarget(entry, 0, GEN_DEFAULT_STEP),
        );
        const distinct = new Set(
          Array.from({ length: 101 }, (_, l) => genTarget(entry, l, GEN_DEFAULT_STEP)),
        );
        if (entry.t60 >= 20 * entry.t0 || entry.t0 >= 20) expect(distinct.size).toBeGreaterThan(4);
      }
      // Level 0 is band 1's value; level 60 band 4's (the default step).
      expect(genTarget(entry, 0, GEN_DEFAULT_STEP)).toBe(Math.min(entry.max ?? Infinity, entry.t0));
      expect(genTarget(entry, 60, GEN_DEFAULT_STEP)).toBe(Math.min(entry.max ?? Infinity, entry.t60));
    }
    // No charm level is level 0; above 100 is 100.
    expect(genLevel(null)).toBe(0);
    expect(genLevel(undefined)).toBe(0);
    expect(genLevel(250)).toBe(100);
  });

  it('rewards respect the caps and the 1 %-of-value rule', () => {
    for (const audience of AUDIENCES) {
      const total = genCatalogueCount(audience);
      for (let i = 0; i < total; i += 7) {
        const t = genTaskAt(audience, i, CAPS);
        expect(t.rewardCherries).toBeGreaterThanOrEqual(1);
        if (t.entry.period === 'DAILY') expect(t.rewardCherries).toBeLessThanOrEqual(CAPS.dailyCherries);
        else expect(t.rewardCherries).toBeLessThanOrEqual(CAPS.monthlyCherries);
        if (t.entry.coinValued) {
          expect(t.rewardCherries).toBeLessThanOrEqual(Math.floor(t.target * GEN_CHERRIES_PER_COIN));
        }
        // Never more than 1.5 × the entry's top reward.
        expect(t.rewardCherries).toBeLessThanOrEqual(t.entry.r60 * 1.5);
      }
    }
    // A small daily cap bounds every daily reward.
    const tight = { dailyCherries: 2_500, monthlyCherries: 0 };
    for (let i = 0; i < 1_000; i++) {
      const t = genTaskAt('HOSTS', i * 97, tight);
      if (t.entry.period === 'DAILY') expect(t.rewardCherries).toBeLessThanOrEqual(2_500);
    }
  });

  it('the assignment is deterministic, one per metric, varied day to day, at the charm level', () => {
    for (const audience of AUDIENCES) {
      for (const period of ['DAILY', 'WEEKLY'] as const) {
        const count = period === 'DAILY' ? 3 : GEN_WEEKLY_COUNT[audience];
        const days = Array.from({ length: 30 }, (_, d) => `2026-11-${String(d + 1).padStart(2, '0')}`);
        let previous: ReturnType<typeof assignGenerated> = [];
        const firstPicks = new Set<string>();
        for (const day of days) {
          const input = {
            audience,
            period,
            templates: templatesOf(audience, period),
            userId: 'user-1',
            periodKey: day,
            charmLevel: 37,
            count,
            previousCodes: new Set(previous.map((t) => t.code)),
            previousMetrics: new Set(previous.map((t) => t.entry.metric)),
            caps: CAPS,
          };
          const picks = assignGenerated(input);
          expect(assignGenerated(input)).toEqual(picks);
          expect(picks).toHaveLength(count);
          expect(new Set(picks.map((t) => t.entry.metric)).size).toBe(count);
          for (const t of picks) {
            expect(t.level).toBe(37);
            expect(t.entry.period).toBe(period);
            // Never the previous period's exact task.
            expect(input.previousCodes.has(t.code)).toBe(false);
          }
          firstPicks.add(picks[0]!.template);
          previous = picks;
        }
        // Varied: over a month the first task is not always the same.
        expect(firstPicks.size).toBeGreaterThan(1);
      }
    }
    // Another person, the same day: (usually) another list; the avoided metrics are never picked.
    const base = {
      audience: 'CREATORS' as const,
      period: 'DAILY' as const,
      templates: templatesOf('CREATORS', 'DAILY'),
      periodKey: '2026-11-06',
      charmLevel: 0,
      count: 3,
    };
    const lists = new Set(
      Array.from({ length: 20 }, (_, u) =>
        assignGenerated({ ...base, userId: `u${String(u)}` })
          .map((t) => t.code)
          .join(),
      ),
    );
    expect(lists.size).toBeGreaterThan(1);
    const avoided = assignGenerated({
      ...base,
      userId: 'x',
      avoidMetrics: new Set(['POSTS', 'REELS', 'STORIES']),
    });
    expect(avoided.some((t) => ['POSTS', 'REELS', 'STORIES'].includes(t.entry.metric))).toBe(false);
    // Only enabled templates; a higher charm level is never easier for the same pick.
    const two = assignGenerated({
      ...base,
      userId: 'y',
      templates: ['G_CR_REELS_D', 'G_CR_POSTS_D'],
      count: 5,
    });
    expect(two.map((t) => t.template).sort()).toEqual(['G_CR_POSTS_D', 'G_CR_REELS_D']);
    const low = assignGenerated({ ...base, userId: 'z', charmLevel: 5 });
    const high = assignGenerated({ ...base, userId: 'z', charmLevel: 80 });
    expect(high.map((t) => t.template)).toEqual(low.map((t) => t.template));
    for (const [i, t] of high.entries()) {
      expect(t.target).toBeGreaterThanOrEqual(low[i]!.target);
      expect(t.rewardCherries).toBeGreaterThanOrEqual(low[i]!.rewardCherries);
    }
  });

  it('the migration seeds one template row per entry (level-0 values)', () => {
    const sql = readFileSync(
      fileURLToPath(
        new URL('../../../prisma/migrations/20270331090200_task_generator/migration.sql', import.meta.url),
      ),
      'utf8',
    );
    for (const [i, entry] of GEN_ENTRIES.entries()) {
      const n = genName(entry, 0);
      expect(sql).toContain(
        `('${genTemplateCode(entry)}', '${entry.period}', '${entry.metric}', ${String(genTarget(entry, 0, GEN_DEFAULT_STEP))}, ${String(genReward(entry, 0, GEN_DEFAULT_STEP))}, '${entry.audience}', '${n.ar}', '${n.en}', ${String(1000 + i * 10)})`,
      );
    }
    expect(sql).toContain("'HOST_LIVE_DAYS')");
    expect(sql).toContain(`"variant" LIKE 'G.%'`);
  });
});
