import type { PrismaService } from '../../src/prisma/prisma.service.js';
import {
  MEDAL_CATALOGUE,
  MEDAL_DEFAULT_LEVELS,
  MEDAL_LEVEL_ASSETS,
  MEDAL_LEVEL_REQUIREMENTS,
  RETIRED_MEDAL_CODES,
  type MedalCode,
} from '../../src/modules/medals/medals.catalogue.js';

/** D313 (owner 2026-11-08): the four «first» medals retired after D291. */
export const D313_RETIRED: ReadonlySet<MedalCode> = new Set<MedalCode>([
  'FIRST_LIVE',
  'BULLET_FIRST',
  'FIRST_FAMILY',
  'FIRST_CP',
]);

/**
 * The codes D291 retired (the charm and live-hours ones) — what [seedMedalCatalogue] retires with `keepFirsts`. The
 * D291 / CP-018 / D300 suites test the generic medal mechanics (levels, wear, backfill, the panel) on the CP-018
 * metrics, whose only medals are the four D313 retired; they seed those four live (`keepFirsts`) so that coverage
 * stays, and `d313-medal-retire-firsts` checks the real retirement.
 */
export const PRE_D313_RETIRED: ReadonlySet<MedalCode> = new Set<MedalCode>(
  [...RETIRED_MEDAL_CODES].filter((c) => !D313_RETIRED.has(c)),
);

/**
 * Puts back the medal catalogue and its default levels as the migrations seed them (CP-018 `20261110100000`, D291
 * `20270325090000_medal_levels`; D300 `20270401090100_medal_content_school`'s level requirements): the e2e database is
 * truncated per suite.
 */
export async function seedMedalCatalogue(
  prisma: PrismaService,
  { keepFirsts = false }: { keepFirsts?: boolean } = {},
): Promise<void> {
  const retired = keepFirsts ? PRE_D313_RETIRED : RETIRED_MEDAL_CODES;
  await prisma.medal.createMany({
    data: MEDAL_CATALOGUE.map((m) => ({ ...m, retired: retired.has(m.code) })),
  });
  await prisma.medalLevel.createMany({
    data: MEDAL_CATALOGUE.flatMap((m) =>
      MEDAL_DEFAULT_LEVELS[m.code].map((t, i) => ({
        medalCode: m.code,
        level: i + 1,
        threshold: BigInt(t),
        iconAsset: MEDAL_LEVEL_ASSETS[m.code]?.[i] ?? null,
      })),
    ),
  });
  await prisma.medalLevelRequirement.createMany({
    data: MEDAL_CATALOGUE.flatMap((m) =>
      (MEDAL_LEVEL_REQUIREMENTS[m.code] ?? []).flatMap((reqs, i) =>
        reqs.map((r) => ({
          medalCode: m.code,
          level: i + 1,
          metric: r.metric,
          threshold: BigInt(r.threshold),
        })),
      ),
    ),
  });
}
