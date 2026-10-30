/**
 * The bag catalogue (الحقيبة, CP-019, owner D107, CONVENTIONS §10.22). The migration
 * `20261111090000_bag` seeds exactly these rows; this copy lets a test database (truncated between
 * suites) be re-seeded and is checked against the migration by a unit test. A new item is a new
 * migration row plus a row here; a new category is a new `bag_category` value plus a row in
 * `BAG_CATEGORIES`.
 */
export type BagCategory = 'PROFILE_CARD' | 'AVATAR_FRAME';

/**
 * Every category, in display order: PROFILE_CARD (D107), AVATAR_FRAME (v1.46-levels, D169: the
 * frame around the user's photo; the support tier frames).
 */
export const BAG_CATEGORIES: readonly BagCategory[] = ['PROFILE_CARD', 'AVATAR_FRAME'];

/** How a user got an item (`bag_item_source`); LEVEL_REWARD: given when a level is reached. */
export type BagItemSource = 'FREE_SIGNUP' | 'BACKFILL' | 'ADMIN' | 'LEVEL_REWARD';

export interface BagItemDef {
  readonly code: string;
  readonly category: BagCategory;
  readonly nameAr: string;
  readonly nameEn: string;
  /**
   * The app's asset (`apps/mobile/assets/profile_card/<assetKey>.svga` for a profile card,
   * `apps/mobile/assets/levels/support_frames/<assetKey>.webp` for a support frame).
   */
  readonly assetKey: string;
  readonly sortOrder: number;
  /** Every new account receives it, and wears the first free one of its category. */
  readonly free: boolean;
}

/** The free profile card every account gets (owner D107). */
export const FREE_PROFILE_CARD = 'bunny_royal';

/** The support tier frames (D169): 20, one per support tier 1–20 (`support-tiers.ts`). */
export const SUPPORT_FRAME_COUNT = 20;

/** The bag code (and assetKey) of the support frame for tier `n` (1–20). */
export const supportFrameCode = (n: number): string => `support_frame_${String(n).padStart(2, '0')}`;

const SUPPORT_FRAMES: readonly BagItemDef[] = Array.from({ length: SUPPORT_FRAME_COUNT }, (_, i) => ({
  code: supportFrameCode(i + 1),
  category: 'AVATAR_FRAME' as const,
  nameAr: `إطار الدعم ${String(i + 1)}`,
  nameEn: `Support frame ${String(i + 1)}`,
  assetKey: supportFrameCode(i + 1),
  sortOrder: (i + 1) * 10,
  free: false,
}));

export const BAG_CATALOGUE: readonly BagItemDef[] = [
  {
    code: 'bunny_royal',
    category: 'PROFILE_CARD',
    nameAr: 'الأرنب الملكي',
    nameEn: 'Royal Bunny',
    assetKey: 'header_bunny_royal',
    sortOrder: 10,
    free: true,
  },
  {
    code: 'kabi_royal',
    category: 'PROFILE_CARD',
    nameAr: 'كابي الملكي',
    nameEn: 'Royal Kabi',
    assetKey: 'header_kabi_royal',
    sortOrder: 20,
    free: false,
  },
  {
    code: 'golden_stags',
    category: 'PROFILE_CARD',
    nameAr: 'الغزلان الذهبية',
    nameEn: 'Golden Stags',
    assetKey: 'header_golden_stags',
    sortOrder: 30,
    free: false,
  },
  {
    code: 'emerald_wings',
    category: 'PROFILE_CARD',
    nameAr: 'الأجنحة الزمردية',
    nameEn: 'Emerald Wings',
    assetKey: 'header_emerald_wings',
    sortOrder: 40,
    free: false,
  },
  ...SUPPORT_FRAMES,
];
