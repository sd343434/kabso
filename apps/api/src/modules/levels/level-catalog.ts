import type {
  LevelCategoryCode,
  LevelReversalPolicy,
  LevelValueUnit,
  Prisma,
} from '../../generated/prisma/client.js';
import { parseMultiplier } from './points-math.js';

export interface LevelDef {
  readonly levelNumber: number;
  readonly nameAr: string;
  readonly nameEn: string;
  readonly requiredPoints: bigint;
  readonly iconKey: string | null;
}

export interface PublishedVersion {
  readonly id: string;
  readonly versionNumber: number;
  /** Scaled by 10^6 (points-math). */
  readonly multiplier: bigint;
  readonly valueUnit: LevelValueUnit;
  readonly reversalPolicy: LevelReversalPolicy;
  readonly luckyGiftsCountAsSupport: boolean;
  /** Sorted by levelNumber. */
  readonly levels: readonly LevelDef[];
}

export interface LoadedCategory {
  readonly id: string;
  readonly code: LevelCategoryCode;
  readonly nameAr: string;
  readonly nameEn: string;
  readonly descriptionAr: string;
  readonly descriptionEn: string;
  readonly enabled: boolean;
  readonly version: PublishedVersion | null;
}

/** AVAILABLE = enabled with a published version (CP-005 §4). */
export function isAvailable(
  category: LoadedCategory,
): category is LoadedCategory & { version: PublishedVersion } {
  return category.enabled && category.version !== null;
}

type Db = Pick<Prisma.TransactionClient, 'levelCategory' | '$queryRaw'>;

const include = {
  publishedVersion: { include: { levels: { orderBy: { levelNumber: 'asc' } } } },
} as const satisfies Prisma.LevelCategoryInclude;

type CategoryRow = Prisma.LevelCategoryGetPayload<{ include: typeof include }>;

function toLoaded(row: CategoryRow): LoadedCategory {
  const v = row.publishedVersion;
  const multiplier = v?.multiplier ? parseMultiplier(v.multiplier.toFixed(6)) : null;
  return {
    id: row.id,
    code: row.code,
    nameAr: row.nameAr,
    nameEn: row.nameEn,
    descriptionAr: row.descriptionAr,
    descriptionEn: row.descriptionEn,
    enabled: row.isEnabled,
    version:
      v && multiplier !== null && v.valueUnit !== null
        ? {
            id: v.id,
            versionNumber: v.versionNumber,
            multiplier,
            valueUnit: v.valueUnit,
            reversalPolicy: v.reversalPolicy,
            luckyGiftsCountAsSupport: v.luckyGiftsCountAsSupport,
            levels: v.levels.map((l) => ({
              levelNumber: l.levelNumber,
              nameAr: l.nameAr,
              nameEn: l.nameEn,
              requiredPoints: l.requiredPoints,
              iconKey: l.iconKey,
            })),
          }
        : null,
  };
}

/**
 * Loads a category with its published version. `lock: 'share'` serializes with a concurrent
 * publish (which takes FOR UPDATE), so an event is applied with one consistent configuration.
 */
export async function loadCategory(
  db: Db,
  code: LevelCategoryCode,
  lock: 'share' | 'update' | null = null,
): Promise<LoadedCategory> {
  if (lock === 'share') {
    await db.$queryRaw`SELECT id FROM level_categories WHERE code = ${code}::level_category_code FOR SHARE`;
  } else if (lock === 'update') {
    await db.$queryRaw`SELECT id FROM level_categories WHERE code = ${code}::level_category_code FOR UPDATE`;
  }
  const row = await db.levelCategory.findUnique({ where: { code }, include });
  if (!row) throw new Error(`level category ${code} is not seeded`);
  return toLoaded(row);
}

export async function loadAllCategories(db: Db): Promise<LoadedCategory[]> {
  const rows = await db.levelCategory.findMany({ include });
  const order = ['ATTRACTIVENESS', 'SUPPORT', 'WIZARD', 'GAMING'];
  return rows.map(toLoaded).sort((a, b) => order.indexOf(a.code) - order.indexOf(b.code));
}
