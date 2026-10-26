/**
 * The medal catalogue (الميداليات, CP-018, owner D106, CONVENTIONS §10.21). The migration
 * `20261110100000_families_cp_medals` seeds exactly these rows; this copy lets a test database
 * (truncated between suites) be re-seeded and is checked against the migration by a unit test.
 * Medals are awarded automatically when the event happens (medal-awards.ts) and by
 * `medals-admin backfill` for past events.
 */
export interface MedalDef {
  readonly code: MedalCode;
  readonly nameAr: string;
  readonly nameEn: string;
  readonly descriptionAr: string;
  readonly descriptionEn: string;
  readonly iconKey: string;
  readonly sortOrder: number;
}

export type MedalCode =
  | 'FIRST_LIVE'
  | 'LIVE_HOURS_10'
  | 'LIVE_HOURS_100'
  | 'CHARM_10'
  | 'CHARM_50'
  | 'CHARM_100'
  | 'FIRST_FAMILY'
  | 'FIRST_CP'
  | 'BULLET_FIRST';

export const MEDAL_CATALOGUE: readonly MedalDef[] = [
  {
    code: 'FIRST_LIVE',
    nameAr: 'أول لايف',
    nameEn: 'First live',
    descriptionAr: 'استضفت أول بث مباشر لك.',
    descriptionEn: 'Hosted your first live.',
    iconKey: 'medal_first_live',
    sortOrder: 10,
  },
  {
    code: 'LIVE_HOURS_10',
    nameAr: '10 ساعات بث',
    nameEn: '10 live hours',
    descriptionAr: 'استضفت 10 ساعات من البث المباشر.',
    descriptionEn: 'Hosted 10 hours of lives.',
    iconKey: 'medal_live_hours_10', // gitleaks:allow (an asset name)
    sortOrder: 20,
  },
  {
    code: 'LIVE_HOURS_100',
    nameAr: '100 ساعة بث',
    nameEn: '100 live hours',
    descriptionAr: 'استضفت 100 ساعة من البث المباشر.',
    descriptionEn: 'Hosted 100 hours of lives.',
    iconKey: 'medal_live_hours_100', // gitleaks:allow (an asset name)
    sortOrder: 30,
  },
  {
    code: 'CHARM_10',
    nameAr: 'جاذبية 10',
    nameEn: 'Charm 10',
    descriptionAr: 'بلغت مستوى الجاذبية 10.',
    descriptionEn: 'Reached charm level 10.',
    iconKey: 'medal_charm_10',
    sortOrder: 40,
  },
  {
    code: 'CHARM_50',
    nameAr: 'جاذبية 50',
    nameEn: 'Charm 50',
    descriptionAr: 'بلغت مستوى الجاذبية 50.',
    descriptionEn: 'Reached charm level 50.',
    iconKey: 'medal_charm_50',
    sortOrder: 50,
  },
  {
    code: 'CHARM_100',
    nameAr: 'جاذبية 100',
    nameEn: 'Charm 100',
    descriptionAr: 'بلغت مستوى الجاذبية 100.',
    descriptionEn: 'Reached charm level 100.',
    iconKey: 'medal_charm_100',
    sortOrder: 60,
  },
  {
    code: 'FIRST_FAMILY',
    nameAr: 'أول عائلة',
    nameEn: 'First family',
    descriptionAr: 'انضممت إلى عائلة أو أنشأت واحدة.',
    descriptionEn: 'Joined or created a family.',
    iconKey: 'medal_first_family',
    sortOrder: 70,
  },
  {
    code: 'FIRST_CP',
    nameAr: 'أول ثنائي',
    nameEn: 'First couple',
    descriptionAr: 'كوّنت أول ثنائي (CP).',
    descriptionEn: 'Formed your first CP couple.',
    iconKey: 'medal_first_cp',
    sortOrder: 80,
  },
  {
    code: 'BULLET_FIRST',
    nameAr: 'أول رسالة عامة',
    nameEn: 'First bullet message',
    descriptionAr: 'أرسلت أول رسالة عامة.',
    descriptionEn: 'Sent your first bullet message.',
    iconKey: 'medal_bullet_first',
    sortOrder: 90,
  },
];

/** Hours of hosted lives (ended rooms, `ended_at − started_at`) that give a medal. */
export const LIVE_HOURS_MEDALS: readonly { readonly hours: number; readonly code: MedalCode }[] = [
  { hours: 10, code: 'LIVE_HOURS_10' },
  { hours: 100, code: 'LIVE_HOURS_100' },
];

/** Charm (`ATTRACTIVENESS`, CP-005) levels that give a medal. */
export const CHARM_MEDALS: readonly { readonly level: number; readonly code: MedalCode }[] = [
  { level: 10, code: 'CHARM_10' },
  { level: 50, code: 'CHARM_50' },
  { level: 100, code: 'CHARM_100' },
];

/** The charm medals of `level` (every threshold at or below it). */
export function charmMedalsFor(level: number | null): MedalCode[] {
  if (level === null) return [];
  return CHARM_MEDALS.filter((m) => level >= m.level).map((m) => m.code);
}

/** The live-hours medals of `hours` hosted. */
export function liveHoursMedalsFor(hours: number): MedalCode[] {
  return LIVE_HOURS_MEDALS.filter((m) => hours >= m.hours).map((m) => m.code);
}
