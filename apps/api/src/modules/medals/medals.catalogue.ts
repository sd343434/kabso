/**
 * The medal catalogue (الميداليات, CP-018, owner D106, CONVENTIONS §10.21). The migration
 * `20261110100000_families_cp_medals` seeds exactly these rows; this copy lets a test database
 * (truncated between suites) be re-seeded and is checked against the migration by a unit test.
 * Medals are awarded automatically when the event happens (medal-awards.ts) and by
 * `medals-admin backfill` for past events.
 */
export interface MedalDef {
  readonly code: MedalCode;
  /** v1.81-live (D291): the medals page's tab. */
  readonly category: MedalCategoryCode;
  /** v1.81-live (D291): what the medal's levels count. */
  readonly metric: MedalMetricCode;
  readonly nameAr: string;
  readonly nameEn: string;
  readonly descriptionAr: string;
  readonly descriptionEn: string;
  readonly iconKey: string;
  readonly sortOrder: number;
}

/** v1.81-live (D291, §10.104): the medals page's tabs «الإنجازات» / «النشاط». */
export type MedalCategoryCode = 'ACHIEVEMENT' | 'ACTIVITY';

/** v1.81-live (D291, §10.104): what a medal's level thresholds compare with. */
export type MedalMetricCode =
  | 'LIVES_HOSTED'
  | 'LIVE_HOURS'
  | 'CHARM_LEVEL'
  | 'FAMILY_JOINED'
  | 'CP_FORMED'
  | 'BULLETS_SENT'
  | 'GIFTS_SENT_COINS'
  | 'LUCKY_GIFTS_SENT_COINS'
  | 'ALL_REQUIREMENTS'
  | RequirementMetricCode
  | 'PK_POINTS';

/**
 * D300 (§10.111): the metrics a multi-requirement medal's levels need together (`medal_level_requirements`) — a
 * content creator's ACTIVE followers now, likes from other ACTIVE accounts on posts and reels that still stand, and
 * §11.4 views of those posts and reels. They are only counted for content creators (`creator_members`).
 */
export type RequirementMetricCode = 'CREATOR_FOLLOWERS' | 'CREATOR_LIKES' | 'CREATOR_VIEWS';

/** D300: the requirement metrics, in the order the app and the panel show them. */
export const REQUIREMENT_METRICS: readonly RequirementMetricCode[] = [
  'CREATOR_FOLLOWERS',
  'CREATOR_LIKES',
  'CREATOR_VIEWS',
];

/** D300: whether `metric` is a requirement metric (a row of `medal_level_requirements`). */
export function isRequirementMetric(metric: string): metric is RequirementMetricCode {
  return (REQUIREMENT_METRICS as readonly string[]).includes(metric);
}

/** D300: requirement metrics only content creators earn and progress on (a non-creator's value is 0). */
export const CREATOR_ONLY_METRICS: ReadonlySet<RequirementMetricCode> = new Set(REQUIREMENT_METRICS);

/** Metrics that are 0 or 1 (a medal on them has exactly one level, threshold 1). */
export const BINARY_MEDAL_METRICS: ReadonlySet<MedalMetricCode> = new Set(['FAMILY_JOINED', 'CP_FORMED']);

export type MedalCode =
  | 'FIRST_LIVE'
  | 'LIVE_HOURS_10'
  | 'LIVE_HOURS_100'
  | 'CHARM_10'
  | 'CHARM_50'
  | 'CHARM_100'
  | 'FIRST_FAMILY'
  | 'FIRST_CP'
  | 'BULLET_FIRST'
  | 'WEALTH_KINGS'
  | 'LUCKY_MASTER'
  | 'CONTENT_SCHOOL'
  | 'DARES_PLAYER';

export const MEDAL_CATALOGUE: readonly MedalDef[] = [
  {
    code: 'FIRST_LIVE',
    category: 'ACTIVITY',
    metric: 'LIVES_HOSTED',
    nameAr: 'أول لايف',
    nameEn: 'First live',
    descriptionAr: 'استضفت أول بث مباشر لك.',
    descriptionEn: 'Hosted your first live.',
    iconKey: 'medal_first_live',
    sortOrder: 10,
  },
  {
    code: 'LIVE_HOURS_10',
    category: 'ACTIVITY',
    metric: 'LIVE_HOURS',
    nameAr: '10 ساعات بث',
    nameEn: '10 live hours',
    descriptionAr: 'استضفت 10 ساعات من البث المباشر.',
    descriptionEn: 'Hosted 10 hours of lives.',
    iconKey: 'medal_live_hours_10', // gitleaks:allow (an asset name)
    sortOrder: 20,
  },
  {
    code: 'LIVE_HOURS_100',
    category: 'ACTIVITY',
    metric: 'LIVE_HOURS',
    nameAr: '100 ساعة بث',
    nameEn: '100 live hours',
    descriptionAr: 'استضفت 100 ساعة من البث المباشر.',
    descriptionEn: 'Hosted 100 hours of lives.',
    iconKey: 'medal_live_hours_100', // gitleaks:allow (an asset name)
    sortOrder: 30,
  },
  {
    code: 'CHARM_10',
    category: 'ACHIEVEMENT',
    metric: 'CHARM_LEVEL',
    nameAr: 'جاذبية 10',
    nameEn: 'Charm 10',
    descriptionAr: 'بلغت مستوى الجاذبية 10.',
    descriptionEn: 'Reached charm level 10.',
    iconKey: 'medal_charm_10',
    sortOrder: 40,
  },
  {
    code: 'CHARM_50',
    category: 'ACHIEVEMENT',
    metric: 'CHARM_LEVEL',
    nameAr: 'جاذبية 50',
    nameEn: 'Charm 50',
    descriptionAr: 'بلغت مستوى الجاذبية 50.',
    descriptionEn: 'Reached charm level 50.',
    iconKey: 'medal_charm_50',
    sortOrder: 50,
  },
  {
    code: 'CHARM_100',
    category: 'ACHIEVEMENT',
    metric: 'CHARM_LEVEL',
    nameAr: 'جاذبية 100',
    nameEn: 'Charm 100',
    descriptionAr: 'بلغت مستوى الجاذبية 100.',
    descriptionEn: 'Reached charm level 100.',
    iconKey: 'medal_charm_100',
    sortOrder: 60,
  },
  {
    code: 'FIRST_FAMILY',
    category: 'ACHIEVEMENT',
    metric: 'FAMILY_JOINED',
    nameAr: 'أول عائلة',
    nameEn: 'First family',
    descriptionAr: 'انضممت إلى عائلة أو أنشأت واحدة.',
    descriptionEn: 'Joined or created a family.',
    iconKey: 'medal_first_family',
    sortOrder: 70,
  },
  {
    code: 'FIRST_CP',
    category: 'ACHIEVEMENT',
    metric: 'CP_FORMED',
    nameAr: 'أول ثنائي',
    nameEn: 'First couple',
    descriptionAr: 'كوّنت أول ثنائي (CP).',
    descriptionEn: 'Formed your first CP couple.',
    iconKey: 'medal_first_cp',
    sortOrder: 80,
  },
  {
    code: 'BULLET_FIRST',
    category: 'ACTIVITY',
    metric: 'BULLETS_SENT',
    nameAr: 'أول رسالة عامة',
    nameEn: 'First bullet message',
    descriptionAr: 'أرسلت أول رسالة عامة.',
    descriptionEn: 'Sent your first bullet message.',
    iconKey: 'medal_bullet_first',
    sortOrder: 90,
  },
  // D291 (owner 2026-11-06): the first real levelled medal, seeded by 20270325090200_medal_wealth_kings.
  {
    code: 'WEALTH_KINGS',
    category: 'ACHIEVEMENT',
    metric: 'GIFTS_SENT_COINS',
    nameAr: 'ملوك الثروة',
    nameEn: 'Wealth Kings',
    descriptionAr: 'مجموع قيمة الهدايا التي أرسلتها لأي مستخدم، عدا هدايا الحظ.',
    descriptionEn: 'Total value of gifts you sent to anyone, except lucky gifts.',
    iconKey: 'medal_wealth_kings',
    sortOrder: 100,
  },
  // D291 (owner 2026-11-06): the second real levelled medal, seeded by 20270325090500_medal_lucky_master.
  {
    code: 'LUCKY_MASTER',
    category: 'ACHIEVEMENT',
    metric: 'LUCKY_GIFTS_SENT_COINS',
    nameAr: 'سيد الحظ',
    nameEn: 'Lucky Master',
    descriptionAr: 'مجموع قيمة هدايا الحظ التي أرسلتها.',
    descriptionEn: 'Total value of lucky gifts you sent.',
    iconKey: 'medal_lucky_master',
    sortOrder: 110,
  },
  // D300 (owner 2026-11-07): the first multi-requirement medal, for content creators only, seeded by
  // 20270401090100_medal_content_school.
  {
    code: 'CONTENT_SCHOOL',
    category: 'ACHIEVEMENT',
    metric: 'ALL_REQUIREMENTS',
    nameAr: 'مدرسة المحتوى',
    nameEn: 'Content School',
    descriptionAr: 'لصنّاع المحتوى: المتابعون والإعجابات والمشاهدات معاً.',
    descriptionEn: 'For content creators: followers, likes and views together.',
    iconKey: 'medal_content_school',
    sortOrder: 120,
  },
  // D300 (owner 2026-11-07: «عندما يكون نقاط PK تحدي = 1500 / 3000 / 5000 / 20000»): the host's PK points, seeded by
  // 20270401090200_medal_dares_player.
  {
    code: 'DARES_PLAYER',
    category: 'ACTIVITY',
    metric: 'PK_POINTS',
    nameAr: 'لاعب الأحكام',
    nameEn: 'Dares Player',
    descriptionAr: 'نقاط PK التي جمعتها في التحديات.',
    descriptionEn: 'PK points you earned in battles.',
    iconKey: 'medal_dares_player',
    sortOrder: 130,
  },
];

/**
 * v1.81-live (D291, §10.104): the default level thresholds the migration `20270325090000_medal_levels` seeds — level 1
 * is each medal's original award rule (CP-018), the others are CTO proposals the owner may change in the panel. Values
 * are in the medal's metric: lives, hours, the charm level, 0/1, bullet messages.
 */
export const MEDAL_DEFAULT_LEVELS: Readonly<Record<MedalCode, readonly number[]>> = {
  FIRST_LIVE: [1, 10, 50, 100, 500],
  LIVE_HOURS_10: [10, 25, 50],
  LIVE_HOURS_100: [100, 500, 1000],
  CHARM_10: [10, 20, 30, 40],
  CHARM_50: [50, 60, 70, 80, 90],
  CHARM_100: [100],
  FIRST_FAMILY: [1],
  FIRST_CP: [1],
  BULLET_FIRST: [1, 10, 100, 1000],
  // The owner's thresholds (coins of gifts sent to anyone, lucky gifts excluded) — not provisional.
  WEALTH_KINGS: [50_000_000, 150_000_000, 300_000_000, 500_000_000, 1_000_000_000, 3_000_000_000],
  // The owner's thresholds (coins of lucky gifts sent) — not provisional; 10 B is above 2^32 by design.
  LUCKY_MASTER: [500_000_000, 1_500_000_000, 3_000_000_000, 10_000_000_000],
  // D300: a multi-requirement medal's level k has threshold k (its metric's value is the level the requirements reach).
  CONTENT_SCHOOL: [1, 2, 3, 4],
  // D300: the owner's PK points thresholds — not provisional.
  DARES_PLAYER: [1_500, 3_000, 5_000, 20_000],
};

/** D300 (§10.111): one threshold of a multi-requirement level. */
export interface MedalRequirement {
  readonly metric: RequirementMetricCode;
  readonly threshold: number;
}

/**
 * D300: the requirements of each level of the multi-requirement medals, level 1 first, as the migration
 * `20270401090100_medal_content_school` seeds them — the owner's thresholds (not provisional).
 */
export const MEDAL_LEVEL_REQUIREMENTS: Readonly<
  Partial<Record<MedalCode, readonly (readonly MedalRequirement[])[]>>
> = {
  CONTENT_SCHOOL: [
    creatorLevel(2_000, 10_000, 20_000),
    creatorLevel(10_000, 50_000, 100_000),
    creatorLevel(100_000, 200_000, 500_000),
    creatorLevel(1_000_000, 2_000_000, 5_000_000),
  ],
};

/** A content creator's level: followers, likes and views together (D300). */
function creatorLevel(followers: number, likes: number, views: number): readonly MedalRequirement[] {
  return [
    { metric: 'CREATOR_FOLLOWERS', threshold: followers },
    { metric: 'CREATOR_LIKES', threshold: likes },
    { metric: 'CREATOR_VIEWS', threshold: views },
  ];
}

/** D291: each level's art bundled in the app (`medal_levels.icon_asset`), by medal, level 1 first. */
export const MEDAL_LEVEL_ASSETS: Readonly<Partial<Record<MedalCode, readonly string[]>>> = {
  WEALTH_KINGS: [
    'medal_wealth_l1',
    'medal_wealth_l2',
    'medal_wealth_l3',
    'medal_wealth_l4',
    'medal_wealth_l5',
    'medal_wealth_l6',
  ],
  LUCKY_MASTER: ['medal_lucky_l1', 'medal_lucky_l2', 'medal_lucky_l3', 'medal_lucky_l4'],
  CONTENT_SCHOOL: [
    'medal_content_school_l1',
    'medal_content_school_l2',
    'medal_content_school_l3',
    'medal_content_school_l4',
  ],
  DARES_PLAYER: [
    'medal_dares_player_l1',
    'medal_dares_player_l2',
    'medal_dares_player_l3',
    'medal_dares_player_l4',
  ],
};

/** The medals of CP-018 (seeded by 20261110100000_families_cp_medals); WEALTH_KINGS has its own migration. */
export const CP018_MEDAL_CODES: ReadonlySet<MedalCode> = new Set<MedalCode>([
  'FIRST_LIVE',
  'LIVE_HOURS_10',
  'LIVE_HOURS_100',
  'CHARM_10',
  'CHARM_50',
  'CHARM_100',
  'FIRST_FAMILY',
  'FIRST_CP',
  'BULLET_FIRST',
]);

/**
 * D291 (owner: «هذه بالأصل ليست ميدالية يمكن ارتداؤها، فقط تكون أيقونة بجانب الاسم»): the charm and live-hours codes
 * are name-side icons, not wearable medals — `medals.retired` (migration 20270325090300_medal_retire_name_icons).
 */
export const RETIRED_MEDAL_CODES: ReadonlySet<MedalCode> = new Set<MedalCode>([
  'LIVE_HOURS_10',
  'LIVE_HOURS_100',
  'CHARM_10',
  'CHARM_50',
  'CHARM_100',
]);

/** The most levels a medal can have (the panel's limit). */
export const MEDAL_MAX_LEVELS = 20;

/** The highest threshold the panel accepts (coins-sized metrics later fit; well inside a JS number). */
export const MEDAL_MAX_THRESHOLD = 1_000_000_000_000;

/**
 * The level [value] reaches on [thresholds] (strictly rising): how many thresholds are at or below it; 0 = not
 * earned. A value that falls later (a charm level can drop) never lowers a level already held — callers keep the
 * higher of the two.
 */
export function medalLevelFor(thresholds: readonly number[], value: number): number {
  let level = 0;
  for (const t of thresholds) {
    if (value >= t) level += 1;
    else break;
  }
  return level;
}

/**
 * D300 (§10.111): the level a multi-requirement medal reaches for `values` — the highest level k such that every
 * requirement of levels 1 … k is met (a level is never reached over an unmet lower one; with thresholds rising per
 * metric this is simply the highest level whose requirements are all met). A level without requirements is never
 * reached (a medal on `ALL_REQUIREMENTS` always has them). 0 = none.
 */
export function levelByRequirements(
  levels: readonly { readonly requirements: readonly MedalRequirement[] }[],
  values: Readonly<Partial<Record<RequirementMetricCode, number>>>,
): number {
  let level = 0;
  for (const l of levels) {
    const met =
      l.requirements.length > 0 && l.requirements.every((r) => (values[r.metric] ?? 0) >= r.threshold);
    if (!met) break;
    level += 1;
  }
  return level;
}
