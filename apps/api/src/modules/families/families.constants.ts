/**
 * Families (العائلة, CP-018, owner D106, CONVENTIONS §10.21). The numbers below are the owner's
 * decisions (price, capacity, request lifetime) and the CTO's defaults the owner may change
 * (the level ladder): every one is a named constant here and in the contract.
 */

/** What creating a family costs (owner D106). */
export const FAMILY_CREATE_COST_COINS = 500;
/** The most members a family has, the leader included (owner D106). */
export const FAMILY_CAPACITY = 500;
/** A join request expires 7 days after it was made (owner D106). */
export const FAMILY_REQUEST_TTL_MS = 7 * 24 * 3600_000;
/** Family names: 2–20 grapheme clusters, at most 40 code points (display-name text rules). */
export const FAMILY_NAME_MIN_GRAPHEMES = 2;
export const FAMILY_NAME_MAX_GRAPHEMES = 20;
export const FAMILY_NAME_MAX_CODE_POINTS = 40;

/** One step of the family level ladder: the level reached at `minPoints` family points. */
export interface FamilyLevelStep {
  readonly level: number;
  readonly minPoints: number;
}

/**
 * The family level ladder (CTO default, D106; the owner may change it): family points are the
 * coins its members spent in the app while in the family (§10.21). Level 1 at 0 … level 10.
 */
export const FAMILY_LEVELS: readonly FamilyLevelStep[] = [
  { level: 1, minPoints: 0 },
  { level: 2, minPoints: 1_000 },
  { level: 3, minPoints: 5_000 },
  { level: 4, minPoints: 20_000 },
  { level: 5, minPoints: 50_000 },
  { level: 6, minPoints: 100_000 },
  { level: 7, minPoints: 200_000 },
  { level: 8, minPoints: 500_000 },
  { level: 9, minPoints: 1_000_000 },
  { level: 10, minPoints: 2_000_000 },
];

/** The level for `points` family points. */
export function familyLevelFor(points: number | bigint): number {
  const value = Number(points);
  let level = 1;
  for (const step of FAMILY_LEVELS) if (value >= step.minPoints) level = step.level;
  return level;
}

/** The points the next level needs, or null at the top level. */
export function familyNextLevelPoints(level: number): number | null {
  return FAMILY_LEVELS.find((step) => step.level === level + 1)?.minPoints ?? null;
}

// ---- v1.25-live (CP-022, owner D116, CONVENTIONS §10.25) ---------------------------------------

/**
 * The family boards (owner D116): `PRESTIGE` (هيبة العائلة) = family points gained in the current
 * calendar month; `ACTIVE` (الأكثر نشاطاً) = members active in the app during the current week (CTO
 * definition, §10.25). Both windows follow LIVE_RANKINGS_TIME_ZONE (the app's one region).
 */
export const FAMILY_RANKING_BOARDS = ['PRESTIGE', 'ACTIVE'] as const;
export type FamilyRankingBoard = (typeof FAMILY_RANKING_BOARDS)[number];
/** At most this many families on a board (owner D116: top 100). */
export const FAMILY_RANKING_MAX = 100;
/** A family's tagline (the "tags" line under its name): 1–60 code points, one line (CTO). */
export const FAMILY_TAGLINE_MAX_CODE_POINTS = 60;
/** A family chat message: the live chat text rules with at most 200 code points (CTO). */
export const FAMILY_CHAT_MAX_CODE_POINTS = 200;
