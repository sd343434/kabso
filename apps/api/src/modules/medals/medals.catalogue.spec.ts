import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import {
  BINARY_MEDAL_METRICS,
  CP018_MEDAL_CODES,
  MEDAL_CATALOGUE,
  MEDAL_LEVEL_ASSETS,
  MEDAL_DEFAULT_LEVELS,
  MEDAL_LEVEL_REQUIREMENTS,
  MEDAL_MAX_LEVELS,
  REQUIREMENT_METRICS,
  levelByRequirements,
  medalLevelFor,
} from './medals.catalogue.js';

const migration = readFileSync(
  new URL('../../../prisma/migrations/20261110100000_families_cp_medals/migration.sql', import.meta.url),
  'utf8',
);
const wealthMigration = readFileSync(
  new URL('../../../prisma/migrations/20270325090200_medal_wealth_kings/migration.sql', import.meta.url),
  'utf8',
);
const luckyMigration = readFileSync(
  new URL('../../../prisma/migrations/20270325090500_medal_lucky_master/migration.sql', import.meta.url),
  'utf8',
);
const contentSchoolMigration = readFileSync(
  new URL('../../../prisma/migrations/20270401090100_medal_content_school/migration.sql', import.meta.url),
  'utf8',
);
const daresMigration = readFileSync(
  new URL('../../../prisma/migrations/20270401090200_medal_dares_player/migration.sql', import.meta.url),
  'utf8',
);
const daresOnlyMigration = readFileSync(
  new URL('../../../prisma/migrations/20270401090300_medal_dares_only_points/migration.sql', import.meta.url),
  'utf8',
);
const levelsMigration = readFileSync(
  new URL('../../../prisma/migrations/20270325090000_medal_levels/migration.sql', import.meta.url),
  'utf8',
);

describe('medal catalogue (CP-018)', () => {
  it('matches the rows the migration seeds', () => {
    for (const m of MEDAL_CATALOGUE.filter((x) => CP018_MEDAL_CODES.has(x.code))) {
      const row = `('${m.code}', '${m.nameAr}', '${m.nameEn}', '${m.descriptionAr}', '${m.descriptionEn}', '${m.iconKey}', ${String(m.sortOrder)})`;
      expect(migration).toContain(row);
    }
    expect(migration.match(/^ {2}\('/gm)?.length).toBe(CP018_MEDAL_CODES.size);
  });

  it('has unique codes and sort orders', () => {
    expect(new Set(MEDAL_CATALOGUE.map((m) => m.code)).size).toBe(MEDAL_CATALOGUE.length);
    expect(new Set(MEDAL_CATALOGUE.map((m) => m.sortOrder)).size).toBe(MEDAL_CATALOGUE.length);
  });

  it('gives charm and live-hours medals at their original thresholds (level 1)', () => {
    const level = (code: keyof typeof MEDAL_DEFAULT_LEVELS, v: number) =>
      medalLevelFor(MEDAL_DEFAULT_LEVELS[code], v);
    expect(level('CHARM_10', 9)).toBe(0);
    expect(level('CHARM_10', 10)).toBe(1);
    expect(level('CHARM_50', 49)).toBe(0);
    expect(level('CHARM_100', 100)).toBe(1);
    expect(level('LIVE_HOURS_10', 9.99)).toBe(0);
    expect(level('LIVE_HOURS_10', 10)).toBe(1);
    expect(level('LIVE_HOURS_100', 150)).toBe(1);
    expect(level('FIRST_LIVE', 1)).toBe(1);
    expect(level('BULLET_FIRST', 1)).toBe(1);
  });

  // v1.81-live (D291, §10.104).
  describe('levels (D291)', () => {
    it('counts the thresholds reached; 0 below the first; stops at the top', () => {
      expect(medalLevelFor([10, 100, 500, 1000], 0)).toBe(0);
      expect(medalLevelFor([10, 100, 500, 1000], 99.9)).toBe(1);
      expect(medalLevelFor([10, 100, 500, 1000], 100)).toBe(2);
      expect(medalLevelFor([10, 100, 500, 1000], 999)).toBe(3);
      expect(medalLevelFor([10, 100, 500, 1000], 1e9)).toBe(4);
      expect(medalLevelFor([], 50)).toBe(0);
    });

    it('defaults: level 1 = the original rule, strictly rising, within the limits, one level on 0/1 metrics', () => {
      const original: Record<string, number> = {
        FIRST_LIVE: 1,
        LIVE_HOURS_10: 10,
        LIVE_HOURS_100: 100,
        CHARM_10: 10,
        CHARM_50: 50,
        CHARM_100: 100,
        FIRST_FAMILY: 1,
        FIRST_CP: 1,
        BULLET_FIRST: 1,
        WEALTH_KINGS: 50_000_000,
        LUCKY_MASTER: 500_000_000,
        CONTENT_SCHOOL: 1,
        DARES_PLAYER: 1_500,
      };
      for (const m of MEDAL_CATALOGUE) {
        const levels = MEDAL_DEFAULT_LEVELS[m.code];
        expect(levels[0], m.code).toBe(original[m.code]);
        expect(levels.length).toBeLessThanOrEqual(MEDAL_MAX_LEVELS);
        expect(
          levels.every((t, i) => i === 0 || t > levels[i - 1]!),
          m.code,
        ).toBe(true);
        if (BINARY_MEDAL_METRICS.has(m.metric)) expect(levels).toEqual([1]);
      }
    });

    it('the migration seeds exactly the default levels, tabs and metrics', () => {
      const seeded = [...levelsMigration.matchAll(/\('([A-Z_0-9]+)', (\d+), (\d+)\)/g)].map((r) => [
        r[1],
        Number(r[2]),
        Number(r[3]),
      ]);
      const expected = MEDAL_CATALOGUE.filter((m) => CP018_MEDAL_CODES.has(m.code)).flatMap((m) =>
        MEDAL_DEFAULT_LEVELS[m.code].map((t, i) => [m.code, i + 1, t]),
      );
      expect(seeded).toEqual(expected);
      for (const m of MEDAL_CATALOGUE.filter((x) => CP018_MEDAL_CODES.has(x.code))) {
        const line = levelsMigration
          .split('\n')
          .find((l) => l.includes(`'${m.code}'`) && l.startsWith('UPDATE "medals"'));
        expect(line, m.code).toContain(`"category" = '${m.category}', "metric" = '${m.metric}'`);
      }
    });

    it("Wealth Kings: the owner's six thresholds, its row and each level's art, as the migration seeds them", () => {
      const m = MEDAL_CATALOGUE.find((x) => x.code === 'WEALTH_KINGS')!;
      expect(wealthMigration).toContain(
        `('${m.code}', '${m.nameAr}', '${m.nameEn}', '${m.descriptionAr}', '${m.descriptionEn}', '${m.iconKey}', ${String(m.sortOrder)}, '${m.category}', '${m.metric}')`,
      );
      const seeded = [...wealthMigration.matchAll(/\('WEALTH_KINGS', (\d+), (\d+), '([a-z0-9_]+)'\)/g)].map(
        (r) => [Number(r[1]), Number(r[2]), r[3]],
      );
      expect(seeded).toEqual(
        MEDAL_DEFAULT_LEVELS.WEALTH_KINGS.map((t, i) => [i + 1, t, MEDAL_LEVEL_ASSETS.WEALTH_KINGS![i]]),
      );
      expect(MEDAL_DEFAULT_LEVELS.WEALTH_KINGS).toEqual([5e7, 1.5e8, 3e8, 5e8, 1e9, 3e9]);
      expect(medalLevelFor(MEDAL_DEFAULT_LEVELS.WEALTH_KINGS, 49_999_999)).toBe(0);
      expect(medalLevelFor(MEDAL_DEFAULT_LEVELS.WEALTH_KINGS, 50_000_000)).toBe(1);
      expect(medalLevelFor(MEDAL_DEFAULT_LEVELS.WEALTH_KINGS, 1_200_000_000)).toBe(5);
    });

    it("Lucky Master: the owner's four thresholds (10 B above 2^32), its row and each level's art", () => {
      const m = MEDAL_CATALOGUE.find((x) => x.code === 'LUCKY_MASTER')!;
      expect(luckyMigration).toContain(
        `('${m.code}', '${m.nameAr}', '${m.nameEn}', '${m.descriptionAr}', '${m.descriptionEn}', '${m.iconKey}', ${String(m.sortOrder)}, '${m.category}', '${m.metric}')`,
      );
      const seeded = [...luckyMigration.matchAll(/\('LUCKY_MASTER', (\d+), (\d+), '([a-z0-9_]+)'\)/g)].map(
        (r) => [Number(r[1]), Number(r[2]), r[3]],
      );
      expect(seeded).toEqual(
        MEDAL_DEFAULT_LEVELS.LUCKY_MASTER.map((t, i) => [i + 1, t, MEDAL_LEVEL_ASSETS.LUCKY_MASTER![i]]),
      );
      expect(MEDAL_DEFAULT_LEVELS.LUCKY_MASTER).toEqual([5e8, 1.5e9, 3e9, 1e10]);
      expect(MEDAL_DEFAULT_LEVELS.LUCKY_MASTER[3]! > 2 ** 32).toBe(true);
      expect(medalLevelFor(MEDAL_DEFAULT_LEVELS.LUCKY_MASTER, 10_000_000_000)).toBe(4);
      expect(medalLevelFor(MEDAL_DEFAULT_LEVELS.LUCKY_MASTER, 9_999_999_999)).toBe(3);
    });
  });

  // D300 (owner 2026-11-07, §10.111): «مدرسة المحتوى» — a level needs followers, likes and views together.
  describe('Content School (D300)', () => {
    const levels = MEDAL_LEVEL_REQUIREMENTS.CONTENT_SCHOOL!.map((requirements) => ({ requirements }));
    const v = (f: number, l: number, w: number) => ({
      CREATOR_FOLLOWERS: f,
      CREATOR_LIKES: l,
      CREATOR_VIEWS: w,
    });

    it("the owner's thresholds, its row, each level's art and threshold = the level number, as the migration seeds them", () => {
      const m = MEDAL_CATALOGUE.find((x) => x.code === 'CONTENT_SCHOOL')!;
      expect(m).toMatchObject({
        metric: 'ALL_REQUIREMENTS',
        category: 'ACHIEVEMENT',
        iconKey: 'medal_content_school',
      });
      expect(m.descriptionAr).toBe('لصنّاع المحتوى: المتابعون والإعجابات والمشاهدات معاً.');
      expect(m.descriptionEn).toBe('For content creators: followers, likes and views together.');
      expect(contentSchoolMigration).toContain(
        `('${m.code}', '${m.nameAr}', '${m.nameEn}', '${m.descriptionAr}', '${m.descriptionEn}', '${m.iconKey}', ${String(m.sortOrder)}, '${m.category}', '${m.metric}')`,
      );
      const seededLevels = [
        ...contentSchoolMigration.matchAll(/\('CONTENT_SCHOOL', (\d+), (\d+), '([a-z0-9_]+)'\)/g),
      ].map((r) => [Number(r[1]), Number(r[2]), r[3]]);
      expect(seededLevels).toEqual(
        MEDAL_DEFAULT_LEVELS.CONTENT_SCHOOL.map((t, i) => [i + 1, t, MEDAL_LEVEL_ASSETS.CONTENT_SCHOOL![i]]),
      );
      expect(MEDAL_DEFAULT_LEVELS.CONTENT_SCHOOL).toEqual([1, 2, 3, 4]);
      const seededReqs = [
        ...contentSchoolMigration.matchAll(/\('CONTENT_SCHOOL', (\d+), '([A-Z_]+)', (\d+)\)/g),
      ].map((r) => [Number(r[1]), r[2], Number(r[3])]);
      expect(seededReqs).toEqual(
        MEDAL_LEVEL_REQUIREMENTS.CONTENT_SCHOOL!.flatMap((reqs, i) =>
          reqs.map((r) => [i + 1, r.metric, r.threshold]),
        ),
      );
      expect(MEDAL_LEVEL_REQUIREMENTS.CONTENT_SCHOOL!.map((reqs) => reqs.map((r) => r.threshold))).toEqual([
        [2_000, 10_000, 20_000],
        [10_000, 50_000, 100_000],
        [100_000, 200_000, 500_000],
        [1_000_000, 2_000_000, 5_000_000],
      ]);
      for (const reqs of MEDAL_LEVEL_REQUIREMENTS.CONTENT_SCHOOL!) {
        expect(reqs.map((r) => r.metric)).toEqual(REQUIREMENT_METRICS);
      }
    });

    it('a level needs ALL its requirements; two of three is not enough; jumps; never over an unmet level', () => {
      expect(levelByRequirements(levels, v(0, 0, 0))).toBe(0);
      expect(levelByRequirements(levels, v(2_000, 10_000, 19_999))).toBe(0);
      expect(levelByRequirements(levels, v(1_999, 10_000, 20_000))).toBe(0);
      expect(levelByRequirements(levels, v(2_000, 9_999, 20_000))).toBe(0);
      expect(levelByRequirements(levels, v(2_000, 10_000, 20_000))).toBe(1);
      // Followers of L4, the rest of L1: level 1.
      expect(levelByRequirements(levels, v(5_000_000, 10_000, 20_000))).toBe(1);
      expect(levelByRequirements(levels, v(100_000, 200_000, 500_000))).toBe(3);
      expect(levelByRequirements(levels, v(1_000_000, 2_000_000, 5_000_000))).toBe(4);
      expect(levelByRequirements(levels, v(9e9, 9e9, 9e9))).toBe(4);
      // A level without requirements is never reached; nor anything above it.
      expect(levelByRequirements([{ requirements: [] }, ...levels], v(9e9, 9e9, 9e9))).toBe(0);
      expect(levelByRequirements([], v(1, 1, 1))).toBe(0);
    });
  });

  // D300 (owner 2026-11-07: «عندما يكون نقاط PK تحدي = 1500 / 3000 / 5000 / 20000»).
  it("Dares Player: the owner's four PK points thresholds, its row and each level's art, as the migration seeds them", () => {
    const m = MEDAL_CATALOGUE.find((x) => x.code === 'DARES_PLAYER')!;
    // Owner's answers: «PK أحكام» points only, and the tab of the other medals.
    expect(m).toMatchObject({
      metric: 'PK_DARES_POINTS',
      category: 'ACHIEVEMENT',
      iconKey: 'medal_dares_player',
    });
    expect(m.descriptionAr).toBe('نقاط PK التي جمعتها في التحديات.');
    expect(m.descriptionEn).toBe('PK points you earned in battles.');
    expect(daresMigration).toContain(
      `('${m.code}', '${m.nameAr}', '${m.nameEn}', '${m.descriptionAr}', '${m.descriptionEn}', '${m.iconKey}', ${String(m.sortOrder)}, 'ACTIVITY', 'PK_POINTS')`,
    );
    // …then 20270401090300 renames the metric and moves both D300 medals to the other medals' tab.
    expect(daresOnlyMigration).toContain(
      `ALTER TYPE "MedalMetric" RENAME VALUE 'PK_POINTS' TO '${m.metric}';`,
    );
    expect(daresOnlyMigration).toContain(
      `UPDATE "medals" SET "category" = '${m.category}' WHERE "code" IN ('DARES_PLAYER', 'CONTENT_SCHOOL');`,
    );
    expect(daresOnlyMigration).toContain('ADD COLUMN "dares_points" INTEGER NOT NULL DEFAULT 0');
    expect(daresOnlyMigration).toMatch(/WHERE m\."type" = 'DARES'/);
    expect(MEDAL_CATALOGUE.find((x) => x.code === 'CONTENT_SCHOOL')!.category).toBe(m.category);
    expect(MEDAL_CATALOGUE.find((x) => x.code === 'WEALTH_KINGS')!.category).toBe(m.category);
    const seeded = [...daresMigration.matchAll(/\('DARES_PLAYER', (\d+), (\d+), '([a-z0-9_]+)'\)/g)].map(
      (r) => [Number(r[1]), Number(r[2]), r[3]],
    );
    expect(seeded).toEqual(
      MEDAL_DEFAULT_LEVELS.DARES_PLAYER.map((t, i) => [i + 1, t, MEDAL_LEVEL_ASSETS.DARES_PLAYER![i]]),
    );
    expect(MEDAL_DEFAULT_LEVELS.DARES_PLAYER).toEqual([1_500, 3_000, 5_000, 20_000]);
    expect(medalLevelFor(MEDAL_DEFAULT_LEVELS.DARES_PLAYER, 1_499)).toBe(0);
    expect(medalLevelFor(MEDAL_DEFAULT_LEVELS.DARES_PLAYER, 1_500)).toBe(1);
    expect(medalLevelFor(MEDAL_DEFAULT_LEVELS.DARES_PLAYER, 6_000)).toBe(3);
    expect(medalLevelFor(MEDAL_DEFAULT_LEVELS.DARES_PLAYER, -3)).toBe(0);
  });
});
