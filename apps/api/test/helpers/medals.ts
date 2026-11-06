import type { PrismaService } from '../../src/prisma/prisma.service.js';
import {
  MEDAL_CATALOGUE,
  MEDAL_DEFAULT_LEVELS,
  MEDAL_LEVEL_ASSETS,
  RETIRED_MEDAL_CODES,
} from '../../src/modules/medals/medals.catalogue.js';

/**
 * Puts back the medal catalogue and its default levels as the migrations seed them (CP-018 `20261110100000`, D291
 * `20270325090000_medal_levels`): the e2e database is truncated per suite.
 */
export async function seedMedalCatalogue(prisma: PrismaService): Promise<void> {
  await prisma.medal.createMany({
    data: MEDAL_CATALOGUE.map((m) => ({ ...m, retired: RETIRED_MEDAL_CODES.has(m.code) })),
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
}
