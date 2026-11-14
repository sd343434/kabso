import type {
  LevelCategoryCode,
  LevelSourceEventType,
  PointsSourceType,
} from '../../generated/prisma/client.js';

/** CP-005 §2: the four categories, in their display order. */
export const LEVEL_CATEGORIES = [
  'ATTRACTIVENESS',
  'SUPPORT',
  'WIZARD',
  'GAMING',
] as const satisfies readonly LevelCategoryCode[];

/** Path/query form of a category (lower case). */
export const LEVEL_CATEGORY_SLUGS = ['attractiveness', 'support', 'wizard', 'gaming'] as const;
export type LevelCategorySlug = (typeof LEVEL_CATEGORY_SLUGS)[number];

export function categoryFromSlug(slug: string): LevelCategoryCode | null {
  const index = (LEVEL_CATEGORY_SLUGS as readonly string[]).indexOf(slug);
  return index < 0 ? null : (LEVEL_CATEGORIES[index] ?? null);
}

/** CP-005 §4: at most this many levels per version. */
export const MAX_LEVELS = 200;

/** Ledger source types that a gift or a game event produces (for reversals). */
export const SOURCE_TYPES_BY_EVENT: Readonly<Record<LevelSourceEventType, readonly PointsSourceType[]>> = {
  GIFT_COMMITTED: ['GIFT_RECEIVED', 'GIFT_SENT', 'LUCKY_GIFT_SENT'],
  GIFT_REVERSED: ['GIFT_RECEIVED', 'GIFT_SENT', 'LUCKY_GIFT_SENT'],
  GAME_SPEND_COMMITTED: ['GAME_SPEND'],
  GAME_SPEND_REVERSED: ['GAME_SPEND'],
};

/** Recent rows shown in the admin user view. */
export const ADMIN_RECENT_ROWS = 20;
