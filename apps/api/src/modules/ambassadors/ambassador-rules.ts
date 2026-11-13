import { z } from 'zod';
import { addMonths, monthKey } from '../economy/economy-math.js';

/**
 * «برنامج سفراء Kabso» (v1.141-social, D390, CONVENTIONS §10.179): the pure rules — the levels and their validation,
 * the commission, the monthly cap, the monthly level evaluation (promotion / demotion) and the month keys. No database,
 * no Nest: shared by the API, the sweeper and the unit tests.
 */

export const AMBASSADOR_REWARD_KINDS = ['NONE', 'COINS', 'VIP_DAYS', 'BAG_ITEM'] as const;
export type AmbassadorRewardKind = (typeof AMBASSADOR_REWARD_KINDS)[number];

/** The most a level may pay (50 %): a commission above the platform's margin would pay out more than Kabso keeps. */
export const MAX_AMBASSADOR_BPS = 5000;
export const MAX_AMBASSADOR_LEVELS = 10;

export const ambassadorRewardSchema = z.discriminatedUnion('kind', [
  z.strictObject({ kind: z.literal('NONE') }),
  /** Coins (ledger `AMBASSADOR_REWARD`). */
  z.strictObject({ kind: z.literal('COINS'), amount: z.number().int().min(1).max(100_000_000) }),
  /** VIP days of a tier (the event-prize path: never lowers a tier held). */
  z.strictObject({
    kind: z.literal('VIP_DAYS'),
    amount: z.number().int().min(1).max(365),
    vipTier: z.string().trim().min(1).max(32),
  }),
  /** A bag item for `amount` days (the team's bag-grant path). */
  z.strictObject({
    kind: z.literal('BAG_ITEM'),
    amount: z.number().int().min(1).max(3650),
    itemCode: z.string().trim().min(1).max(64),
  }),
]);
export type AmbassadorReward = z.infer<typeof ambassadorRewardSchema>;

export const ambassadorLevelSchema = z.strictObject({
  code: z.string().regex(/^[A-Z][A-Z0-9_]{1,15}$/),
  /** The month's referrals that became ACTIVE (§10.179.4). */
  minActiveReferrals: z.number().int().min(0).max(1_000_000),
  /** The month's qualifying top-ups of the ambassador's referrals, in coins. */
  minTopupCoins: z.number().int().min(0).max(Number.MAX_SAFE_INTEGER),
  commissionBps: z.number().int().min(0).max(MAX_AMBASSADOR_BPS),
  reward: ambassadorRewardSchema,
});
export type AmbassadorLevel = z.infer<typeof ambassadorLevelSchema>;

/**
 * Why a level list cannot be saved (null = fine): 1–10 levels, unique codes, the first one open to everyone
 * (0 / 0 — a new ambassador starts there), each next level asking at least as much as the one before and more of
 * one of the two, and a commission that never goes down when the level goes up.
 */
export function levelsProblem(levels: readonly AmbassadorLevel[]): string | null {
  if (levels.length < 1 || levels.length > MAX_AMBASSADOR_LEVELS) return 'count';
  if (new Set(levels.map((l) => l.code)).size !== levels.length) return 'duplicate_code';
  const first = levels[0]!;
  if (first.minActiveReferrals !== 0 || first.minTopupCoins !== 0) return 'first_not_open';
  for (let i = 1; i < levels.length; i++) {
    const a = levels[i - 1]!;
    const b = levels[i]!;
    if (b.minActiveReferrals < a.minActiveReferrals || b.minTopupCoins < a.minTopupCoins)
      return 'not_increasing';
    if (b.minActiveReferrals === a.minActiveReferrals && b.minTopupCoins === a.minTopupCoins)
      return 'not_increasing';
    if (b.commissionBps < a.commissionBps) return 'commission_decreasing';
  }
  return null;
}

/** The stored levels (JSON) — an unreadable value reads as no level (the programme then pays nothing). */
export function parseLevels(raw: unknown): AmbassadorLevel[] {
  const parsed = z.array(ambassadorLevelSchema).safeParse(raw);
  if (!parsed.success || levelsProblem(parsed.data) !== null) return [];
  return parsed.data;
}

/** The index of `code` in `levels` (an unknown code — a level removed since — reads as the first). */
export function levelIndex(levels: readonly AmbassadorLevel[], code: string): number {
  const i = levels.findIndex((l) => l.code === code);
  return i < 0 ? 0 : i;
}

/** floor(coins × CHERRIES_PER_COIN × bps / 10 000): the commission of one top-up, in cherries (§10.179.5). */
export function commissionCherries(coins: bigint, cherriesPerCoin: number, bps: number): bigint {
  if (coins <= 0n || bps <= 0) return 0n;
  return (coins * BigInt(cherriesPerCoin) * BigInt(bps)) / 10_000n;
}

/**
 * The monthly cap (0 = none): what is left of `cap` after `used` this month. Returns the cherries paid and the part
 * cut off by the cap.
 */
export function capCommission(
  cherries: bigint,
  used: bigint,
  cap: bigint,
): { readonly cherries: bigint; readonly capped: bigint } {
  if (cap <= 0n) return { cherries, capped: 0n };
  const left = cap - used > 0n ? cap - used : 0n;
  const paid = cherries < left ? cherries : left;
  return { cherries: paid, capped: cherries - paid };
}

export interface MonthStats {
  readonly activeReferrals: number;
  readonly topupCoins: bigint;
}

/** The highest level whose two monthly requirements `stats` meet (the first level always). */
export function metLevelIndex(levels: readonly AmbassadorLevel[], stats: MonthStats): number {
  let met = 0;
  for (let i = 0; i < levels.length; i++) {
    const l = levels[i]!;
    if (stats.activeReferrals >= l.minActiveReferrals && stats.topupCoins >= BigInt(l.minTopupCoins)) met = i;
  }
  return met;
}

/**
 * The level after a month (§10.179.6): a month that meets a higher level promotes straight to it; a month below the
 * current level's requirements demotes ONE level (never below the first); otherwise the level stays.
 */
export function levelAfterMonth(current: number, met: number): number {
  if (met > current) return met;
  if (met < current) return current - 1;
  return current;
}

/** What is left to reach the next level (the dashboard's progress); null at the top level. */
export function progressToNext(
  levels: readonly AmbassadorLevel[],
  current: number,
  stats: MonthStats,
): { code: string; activeReferrals: number; topupCoins: number } | null {
  const next = levels[current + 1];
  if (!next) return null;
  return {
    code: next.code,
    activeReferrals: Math.max(0, next.minActiveReferrals - stats.activeReferrals),
    topupCoins: Math.max(0, next.minTopupCoins - Number(stats.topupCoins)),
  };
}

/** The month (`YYYY-MM`) of `at` in the programme's zone (the boards' clock, LIVE_RANKINGS_TIME_ZONE). */
export function ambassadorMonth(at: Date, timeZone: string): string {
  return monthKey(at, timeZone).slice(0, 7);
}

/** The month before `month` (`YYYY-MM`). */
export function previousMonth(month: string): string {
  return addMonths(`${month}-01`, -1).slice(0, 7);
}

/** The coin ledger reference of a month's coin reward (once per ambassador and month). */
export function rewardReference(userId: string, month: string): string {
  return `AMB:${userId}@${month}`;
}

/**
 * The money view of a commission (§10.179.5 worked example), in US cents: what the top-up brought in at the retail
 * price (`retailMinorPerMillion` per 1 000 000 coins), what the commission costs at the payout rate (`rateCherries`
 * cherries = `rateMinor`), and the commission as a share of the platform's profit on those coins once they are gifted
 * (`hostShareBps` of their cherry value goes to the host). Used by the docs' example and its unit test.
 */
export function commissionEconomics(input: {
  coins: bigint;
  bps: number;
  cherriesPerCoin: number;
  retailMinorPerMillion: number;
  rateCherries: number;
  rateMinor: number;
  hostShareBps: number;
}): {
  revenueMinor: number;
  commissionCherries: bigint;
  commissionMinor: number;
  hostMinor: number;
  profitMinor: number;
} {
  const toMinor = (cherries: bigint) => (Number(cherries) * input.rateMinor) / input.rateCherries;
  const revenueMinor = (Number(input.coins) * input.retailMinorPerMillion) / 1_000_000;
  const cherries = commissionCherries(input.coins, input.cherriesPerCoin, input.bps);
  const hostCherries = (input.coins * BigInt(input.cherriesPerCoin) * BigInt(input.hostShareBps)) / 10_000n;
  const hostMinor = toMinor(hostCherries);
  return {
    revenueMinor,
    commissionCherries: cherries,
    commissionMinor: toMinor(cherries),
    hostMinor,
    profitMinor: revenueMinor - hostMinor,
  };
}
