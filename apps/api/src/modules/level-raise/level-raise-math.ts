/**
 * v1.89-social (D290, CONVENTIONS §10.103): the proposed support level of a level-raise request «طلب رفع ليفيل».
 * Pure; every number the panel shows as the reasoning comes out of {@link proposeLevel}.
 *
 * The owner's method is by money (owner, 2026-11-06):
 *  1. source level → XP, from the source app's XP table (interpolated between known points);
 *  2. XP × coins per XP → coins spent there → USD at that app's price of 1 000 000 coins;
 *  3. USD → Kabso coins at Kabso's retail price (1 000 000 coins = $12.50, D188 / D194) → support points (the
 *     published SUPPORT version's multiplier, ×0.1 = 1 point per 10 coins) → the level those points reach on the
 *     published SUPPORT ladder: the "source-equivalent level";
 *  4. the Kabso evidence caps it: the recharge in the first days after the account's creation (default 7) and the
 *     total recharge each give a cap (`base + perDoubling × log2(coins / anchor)`); the higher cap wins, and the
 *     source-equivalent level plus small bonuses for the current support and charm levels never passes it;
 *  5. the result is clamped to [the current support level, 40].
 *
 * An app with no usable table ("FACTOR" mode: every app the owner has not confirmed, and "other") converts with a
 * conservative factor instead: `floor(source level × factor)`.
 */

/** Never above level 40 (owner). */
export const MAX_RAISE_LEVEL = 40;
/** Kabso's retail price (D188, D194): 1 000 000 coins = $12.50, i.e. 80 000 coins per dollar = 8 000 000 per $100. */
export const KABSO_COINS_PER_USD = 80_000n;

export type SourceMode = 'MONEY' | 'FACTOR';
export type Confidence = 'CONFIRMED' | 'ESTIMATE';

export interface XpPoint {
  readonly level: number;
  readonly xp: bigint;
  readonly confidence: Confidence;
}

export interface SourceAppMath {
  readonly mode: SourceMode;
  /** MONEY: USD cents per 1 000 000 of the app's coins (Zafa: 2 000 = $20). */
  readonly usdPerMillionCents: bigint | null;
  /** MONEY: the app's coins per XP point × 1 000 (Zafa: 10 000 = 10 coins). */
  readonly coinsPerXpMilli: bigint | null;
  /** MONEY: the known points of the app's level table (any order). */
  readonly xpTable: readonly XpPoint[];
  /** FACTOR: the factor × 1 000 (500 = ×0.5). */
  readonly factorMilli: number | null;
  readonly confidence: Confidence;
}

/** The admin-editable weights (`level_raise_settings`; defaults = {@link DEFAULT_RAISE_SETTINGS}). */
export interface RaiseSettings {
  /** The recharge (net coins) a supporter needs before a request can be approved. */
  readonly minRechargeCoins: bigint;
  /** The window after the account's creation counted as "the first days". */
  readonly firstDays: number;
  /** The recharge that gives the base levels below. */
  readonly anchorCoins: bigint;
  /** The cap at `anchorCoins` recharged in the first days. */
  readonly firstDaysBaseLevel: number;
  /** The cap at `anchorCoins` recharged in total (lower: later recharge is weaker evidence). */
  readonly totalBaseLevel: number;
  /** Levels added to a cap for each doubling of the recharge, × 10 (40 = 4 levels). */
  readonly levelsPerDoublingTenths: number;
  /** +N levels for each 10 current support levels, at most `supportBonusMax`. */
  readonly supportBonusPer10: number;
  readonly supportBonusMax: number;
  /** +N levels for each 10 current charm levels, at most `charmBonusMax`. */
  readonly charmBonusPer10: number;
  readonly charmBonusMax: number;
  /** Below the lowest known point of a table: `xp = xp₀ × (level / level₀)^exponent`, exponent × 10. */
  readonly belowTableExponentTenths: number;
}

/**
 * Conservative defaults that reproduce the owner's examples: 1 000 000 recharged → 15 (total) to 20 (first week),
 * inside the owner's «≈ 15–25»; 32 000 000 recharged in the first week → 40 (20 + 4 × log2 32).
 */
export const DEFAULT_RAISE_SETTINGS: RaiseSettings = {
  minRechargeCoins: 1_000_000n,
  firstDays: 7,
  anchorCoins: 1_000_000n,
  firstDaysBaseLevel: 20,
  totalBaseLevel: 15,
  levelsPerDoublingTenths: 40,
  supportBonusPer10: 1,
  supportBonusMax: 2,
  charmBonusPer10: 1,
  charmBonusMax: 2,
  belowTableExponentTenths: 30,
};

export interface LadderRow {
  readonly levelNumber: number;
  readonly requiredPoints: bigint;
}

export type XpMethod = 'TABLE' | 'INTERPOLATED' | 'BELOW_TABLE' | 'ABOVE_TABLE_CLAMPED';

export interface XpEstimate {
  readonly xp: bigint;
  readonly method: XpMethod;
  /** The table points used (one or two). */
  readonly from: readonly XpPoint[];
}

/**
 * The XP of `level` from the known points: exact on a point; between two points geometric (log-linear —
 * level tables grow roughly exponentially; linear when the lower point is 0); below the lowest point a power curve
 * from 0 (`xp₀ × (level / level₀)^exponent`); above the highest point the highest point itself (never
 * extrapolated upwards: conservative). Null when the table is empty.
 */
export function xpAt(table: readonly XpPoint[], level: number, exponentTenths: number): XpEstimate | null {
  const points = [...table].filter((p) => p.level >= 1 && p.xp >= 0n).sort((a, b) => a.level - b.level);
  if (points.length === 0 || level < 1) return null;
  const exact = points.find((p) => p.level === level);
  if (exact) return { xp: exact.xp, method: 'TABLE', from: [exact] };
  const first = points[0]!;
  const last = points[points.length - 1]!;
  if (level < first.level) {
    const xp = Number(first.xp) * Math.pow(level / first.level, exponentTenths / 10);
    return { xp: BigInt(Math.floor(xp)), method: 'BELOW_TABLE', from: [first] };
  }
  if (level > last.level) return { xp: last.xp, method: 'ABOVE_TABLE_CLAMPED', from: [last] };
  const upperIndex = points.findIndex((p) => p.level > level);
  const lo = points[upperIndex - 1]!;
  const hi = points[upperIndex]!;
  const t = (level - lo.level) / (hi.level - lo.level);
  const a = Number(lo.xp);
  const b = Number(hi.xp);
  const xp = a > 0 && b > 0 ? a * Math.pow(b / a, t) : a + (b - a) * t;
  // Never outside the two points (float rounding).
  const clamped = Math.min(Math.max(Math.floor(xp), Math.min(a, b)), Math.max(a, b));
  return { xp: BigInt(clamped), method: 'INTERPOLATED', from: [lo, hi] };
}

/** The highest ladder level whose threshold ≤ points (0 when none). */
export function ladderLevel(ladder: readonly LadderRow[], points: bigint): number {
  let found = 0;
  for (const row of [...ladder].sort((a, b) => a.levelNumber - b.levelNumber)) {
    if (row.requiredPoints <= points) found = row.levelNumber;
    else break;
  }
  return found;
}

/**
 * A recharge cap: `floor(base + perDoubling × log2(coins / anchor))`, within [0, 40]; 0 without recharge.
 */
export function rechargeCap(coins: bigint, anchor: bigint, base: number, perDoublingTenths: number): number {
  if (coins <= 0n || anchor <= 0n) return 0;
  const value = base + (perDoublingTenths / 10) * Math.log2(Number(coins) / Number(anchor));
  // A tiny epsilon so 32 000 000 / 1 000 000 lands on exactly 40 (log2 is exact there, but be safe).
  const level = Math.floor(value + 1e-9);
  return Math.min(Math.max(level, 0), MAX_RAISE_LEVEL);
}

export function levelBonus(level: number, per10: number, max: number): number {
  if (level <= 0 || per10 <= 0 || max <= 0) return 0;
  return Math.min(Math.floor(level / 10) * per10, max);
}

export type SourceEquivalent =
  | {
      readonly mode: 'MONEY';
      readonly xp: bigint;
      readonly xpMethod: XpMethod;
      readonly xpFrom: readonly XpPoint[];
      readonly sourceCoins: bigint;
      /** USD cents spent in the source app (floored). */
      readonly usdCents: bigint;
      readonly kabsoCoins: bigint;
      readonly kabsoPoints: bigint;
      readonly level: number;
    }
  | {
      readonly mode: 'FACTOR';
      readonly factorMilli: number;
      readonly level: number;
    }
  | {
      /** The app's data cannot convert (no table / price): counts as level 0 (the cap and floor still apply). */
      readonly mode: 'NONE';
      readonly level: 0;
    };

/** Steps 1–3: the source level as a Kabso support level. */
export function sourceEquivalent(
  app: SourceAppMath,
  sourceLevel: number,
  ladder: readonly LadderRow[],
  multiplierScaled: bigint,
  settings: RaiseSettings,
): SourceEquivalent {
  if (app.mode === 'FACTOR') {
    if (app.factorMilli === null || app.factorMilli <= 0) return { mode: 'NONE', level: 0 };
    const level = Math.floor((sourceLevel * app.factorMilli) / 1000);
    return { mode: 'FACTOR', factorMilli: app.factorMilli, level: Math.max(level, 0) };
  }
  const xp = xpAt(app.xpTable, sourceLevel, settings.belowTableExponentTenths);
  if (!xp || !app.coinsPerXpMilli || !app.usdPerMillionCents || app.coinsPerXpMilli <= 0n) {
    return { mode: 'NONE', level: 0 };
  }
  const sourceCoins = (xp.xp * app.coinsPerXpMilli) / 1000n;
  const usdCents = (sourceCoins * app.usdPerMillionCents) / 1_000_000n;
  // Exact: coins × cents-per-million × coins-per-USD / (1 000 000 × 100).
  const kabsoCoins = (sourceCoins * app.usdPerMillionCents * KABSO_COINS_PER_USD) / 100_000_000n;
  const kabsoPoints = (kabsoCoins * multiplierScaled) / 1_000_000n;
  return {
    mode: 'MONEY',
    xp: xp.xp,
    xpMethod: xp.method,
    xpFrom: xp.from,
    sourceCoins,
    usdCents,
    kabsoCoins,
    kabsoPoints,
    level: ladderLevel(ladder, kabsoPoints),
  };
}

export interface ProposalInput {
  readonly app: SourceAppMath;
  readonly sourceLevel: number;
  readonly ladder: readonly LadderRow[];
  /** The published SUPPORT version's multiplier × 10^6 (0.1 = 100 000). */
  readonly multiplierScaled: bigint;
  readonly totalRechargeCoins: bigint;
  readonly firstDaysRechargeCoins: bigint;
  readonly currentSupportLevel: number;
  readonly currentCharmLevel: number;
  readonly settings: RaiseSettings;
}

export type LimitedBy = 'SOURCE' | 'RECHARGE' | 'MAX_LEVEL' | 'CURRENT_LEVEL';

export interface Proposal {
  readonly source: SourceEquivalent;
  readonly firstDaysCap: number;
  readonly totalCap: number;
  /** max(firstDaysCap, totalCap): the result never passes it (except to keep the current level). */
  readonly rechargeCap: number;
  readonly supportBonus: number;
  readonly charmBonus: number;
  /** min(source level + bonuses, rechargeCap) before the clamp. */
  readonly beforeClamp: number;
  readonly proposedLevel: number;
  readonly limitedBy: LimitedBy;
  readonly eligible: boolean;
}

/** Steps 1–5. */
export function proposeLevel(input: ProposalInput): Proposal {
  const s = input.settings;
  const source = sourceEquivalent(input.app, input.sourceLevel, input.ladder, input.multiplierScaled, s);
  const firstDaysCap = rechargeCap(
    input.firstDaysRechargeCoins,
    s.anchorCoins,
    s.firstDaysBaseLevel,
    s.levelsPerDoublingTenths,
  );
  const totalCap = rechargeCap(
    input.totalRechargeCoins,
    s.anchorCoins,
    s.totalBaseLevel,
    s.levelsPerDoublingTenths,
  );
  const cap = Math.max(firstDaysCap, totalCap);
  const supportBonus = levelBonus(input.currentSupportLevel, s.supportBonusPer10, s.supportBonusMax);
  const charmBonus = levelBonus(input.currentCharmLevel, s.charmBonusPer10, s.charmBonusMax);
  const withBonus = source.level + supportBonus + charmBonus;
  const beforeClamp = Math.min(withBonus, cap);
  let limitedBy: LimitedBy = withBonus <= cap ? 'SOURCE' : 'RECHARGE';
  let proposed = beforeClamp;
  if (proposed > MAX_RAISE_LEVEL) {
    proposed = MAX_RAISE_LEVEL;
    limitedBy = 'MAX_LEVEL';
  }
  if (proposed <= input.currentSupportLevel) {
    proposed = input.currentSupportLevel;
    limitedBy = 'CURRENT_LEVEL';
  }
  return {
    source,
    firstDaysCap,
    totalCap,
    rechargeCap: cap,
    supportBonus,
    charmBonus,
    beforeClamp,
    proposedLevel: proposed,
    limitedBy,
    eligible: input.totalRechargeCoins >= s.minRechargeCoins,
  };
}

/**
 * The owner's approval rule: an approved level is ≥ the current level, ≤ the proposal and ≤ 40. Returns the issue
 * when it is not, or null.
 */
export function approvalIssue(
  level: number,
  proposed: number,
  current: number,
): 'level_raise_above_proposal' | 'level_raise_below_current' | 'level_raise_above_max' | null {
  if (level < current) return 'level_raise_below_current';
  // Approving at the current level changes nothing (allowed even above 40: nobody's level goes down, D169).
  if (level === current) return null;
  if (level > MAX_RAISE_LEVEL) return 'level_raise_above_max';
  if (level > proposed) return 'level_raise_above_proposal';
  return null;
}
