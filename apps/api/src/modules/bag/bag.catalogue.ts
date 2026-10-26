/**
 * The bag catalogue (الحقيبة, CP-019, owner D107, CONVENTIONS §10.22). The migration
 * `20261111090000_bag` seeds exactly these rows; this copy lets a test database (truncated between
 * suites) be re-seeded and is checked against the migration by a unit test. A new item is a new
 * migration row plus a row here; a new category is a new `bag_category` value plus a row in
 * `BAG_CATEGORIES`.
 */
export type BagCategory = 'PROFILE_CARD';

/** Every category, in display order (only PROFILE_CARD for now; designed to grow). */
export const BAG_CATEGORIES: readonly BagCategory[] = ['PROFILE_CARD'];

/** How a user got an item (`bag_item_source`). */
export type BagItemSource = 'FREE_SIGNUP' | 'BACKFILL' | 'ADMIN';

export interface BagItemDef {
  readonly code: string;
  readonly category: BagCategory;
  readonly nameAr: string;
  readonly nameEn: string;
  /** The app's asset (`apps/mobile/assets/profile_card/<assetKey>.svga` for a profile card). */
  readonly assetKey: string;
  readonly sortOrder: number;
  /** Every new account receives it, and wears the first free one of its category. */
  readonly free: boolean;
}

/** The free profile card every account gets (owner D107). */
export const FREE_PROFILE_CARD = 'bunny_royal';

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
];
