/**
 * Families (العائلة, CP-018, owner D106, CONVENTIONS §10.21). The numbers below are the owner's
 * decisions (price and level ladder D200, capacity, request lifetime): every one is a named
 * constant here and in the contract.
 */

/**
 * What creating a family costs: 1 000 000 coins ≈ $12.50 at the retail price (owner D200; it was
 * 500 under D106, before coins were repriced to 1 000 000 = $12.50, D188/D190).
 */
export const FAMILY_CREATE_COST_COINS = 1_000_000;
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
 * The family level ladder (owner D200, CONVENTIONS §10.21; D106's CTO default before it): family
 * points are the coins its members spent in the app while in the family (§10.21), so at the retail
 * price (1 000 000 coins = $12.50) level 2 is about $50 of spending and level 10 about $300 000.
 * Every value is far below 2^53 (`families.points` is a BIGINT capped at 2^53 − 1; the contract's
 * integers carry no int32 format).
 */
export const FAMILY_LEVELS: readonly FamilyLevelStep[] = [
  { level: 1, minPoints: 0 },
  { level: 2, minPoints: 4_000_000 }, // ≈ $50
  { level: 3, minPoints: 20_000_000 }, // ≈ $250
  { level: 4, minPoints: 80_000_000 }, // ≈ $1 000
  { level: 5, minPoints: 240_000_000 }, // ≈ $3 000
  { level: 6, minPoints: 640_000_000 }, // ≈ $8 000
  { level: 7, minPoints: 1_600_000_000 }, // ≈ $20 000
  { level: 8, minPoints: 4_000_000_000 }, // ≈ $50 000
  { level: 9, minPoints: 9_600_000_000 }, // ≈ $120 000
  { level: 10, minPoints: 24_000_000_000 }, // ≈ $300 000
];

/** The highest family level (CHECK families_level_range: 1–10). */
export const FAMILY_MAX_LEVEL = 10;

/** The ladder level for `points` family points (what the points alone reach). */
export function familyLevelFor(points: number | bigint): number {
  const value = Number(points);
  let level = 1;
  for (const step of FAMILY_LEVELS) if (value >= step.minPoints) level = step.level;
  return level;
}

/**
 * The family's level after its points changed (owner D200): a family never drops a level, so the
 * stored level is a floor — `max(stored, ladder level)`. A family that reached a level under an
 * older (cheaper) ladder keeps it and rises again only when its points reach the next level's
 * threshold on the current ladder.
 */
export function familyLevelAfter(points: number | bigint, storedLevel: number): number {
  return Math.min(FAMILY_MAX_LEVEL, Math.max(storedLevel, familyLevelFor(points)));
}

/**
 * The points the next level needs, or null at the top level: the current ladder's threshold of
 * `level + 1`. For a family kept at a level above what its points reach (D200), this is still the
 * next level's threshold, so its progress (`points / nextLevelPoints`) is honest and may be near 0.
 */
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
