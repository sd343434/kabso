import { randomInt } from 'node:crypto';

/**
 * The cherry economy's arithmetic (v1.52-social, D179, CONVENTIONS §10.46). Pure functions, shared by
 * the API, the `economy-admin` CLI and the unit tests. Every amount is a whole number of cherries
 * (bigint); every rounding is down (floor), except the cherries a withdrawal holds (rounded up, so the
 * company never pays more than the rate).
 */

/** The rules in force (server config, owner defaults). */
export interface EconomyRules {
  /** 1 coin of a recipient's share = this many cherries (owner: 10). */
  readonly cherriesPerCoin: number;
  /** An agency's commission on its hosts' cherries (owner: 15 % = 1 500). */
  readonly agencyCommissionBps: number;
  /** The rate in the month after a month in which its hosts earned ≥ the tier (owner: 16 %). */
  readonly agencyTierCommissionBps: number;
  /** The tier (owner: 1 500 000 000 cherries in a calendar month). */
  readonly agencyTierMonthlyCherries: number;
  /** A parent agency's commission on its sub-agencies' hosts' cherries (owner: 3 %). */
  readonly parentCommissionBps: number;
}

export interface RankRules {
  readonly rankMinActiveHosts: number;
  readonly rankExceptionCherries: number;
  readonly adminMinSubAgencies: number;
}

export type AgencyRankValue = 'NEW' | 'AGENT' | 'ADMIN' | 'LAPSED';

/**
 * The cherries a recipient gets for their part of a send: floor(coins × share × cherries per coin),
 * the share in basis points (the send's stored `host_share_bps`). 100 coins at 65 % → 650 cherries;
 * 1 coin at 65 % → 6 (6.5 rounded down).
 */
export function giftCherries(coins: bigint, shareBps: number, cherriesPerCoin: number): bigint {
  if (coins <= 0n || shareBps <= 0) return 0n;
  return (coins * BigInt(shareBps) * BigInt(cherriesPerCoin)) / 10_000n;
}

/** floor(cherries × rate) for a rate in basis points. */
export function commissionOf(cherries: bigint, rateBps: number): bigint {
  if (cherries <= 0n || rateBps <= 0) return 0n;
  return (cherries * BigInt(rateBps)) / 10_000n;
}

/** This month's agency rate: the tier rate when its hosts' cherries last month reached the tier. */
export function agencyRateBps(previousMonthHostCherries: bigint, rules: EconomyRules): number {
  return previousMonthHostCherries >= BigInt(rules.agencyTierMonthlyCherries)
    ? rules.agencyTierCommissionBps
    : rules.agencyCommissionBps;
}

/**
 * Whether a send earns the agency its commission: always while the agency qualifies (NEW in its grace,
 * AGENT, ADMIN); while it is LAPSED only for hosts who joined when it was not lapsed (owner: "no
 * commission for hosts who join after that, existing hosts stay linked").
 */
export function agencyCommissionPaid(rank: AgencyRankValue, linkEligible: boolean): boolean {
  return rank !== 'LAPSED' || linkEligible;
}

/** A parent agency earns its 3 % only while its rank is ADMIN. */
export function parentCommissionPaid(parentRank: AgencyRankValue | null): boolean {
  return parentRank === 'ADMIN';
}

/**
 * An agency qualifies as a host agent with ≥ 5 active hosts, or — the owner's exception — when its
 * hosts earned ≥ 200 000 000 cherries in the month (the current or the last calendar month).
 */
export function qualifiesAsAgent(activeHosts: number, monthHostCherries: bigint, rules: RankRules): boolean {
  return activeHosts >= rules.rankMinActiveHosts || monthHostCherries >= BigInt(rules.rankExceptionCherries);
}

/** The rank an agency qualifies for now (LAPSED: none). An ADMIN is an agent with ≥ 3 qualified subs. */
export function qualifiedRank(
  selfQualifies: boolean,
  qualifiedSubAgencies: number,
  rules: RankRules,
): AgencyRankValue {
  if (!selfQualifies) return 'LAPSED';
  return qualifiedSubAgencies >= rules.adminMinSubAgencies ? 'ADMIN' : 'AGENT';
}

const RANK_ORDER: Readonly<Record<AgencyRankValue, number>> = { LAPSED: 0, NEW: 1, AGENT: 2, ADMIN: 3 };

/**
 * The rank after an evaluation. At a month start (once per month, after the agency's grace) the rank
 * becomes what it qualifies for — up or down. During the month a rank only goes up ("kept until the
 * end of the month"); a NEW agency in its grace stays NEW until it qualifies or is evaluated.
 */
export function nextRank(
  current: AgencyRankValue,
  qualified: AgencyRankValue,
  monthStart: boolean,
): AgencyRankValue {
  if (monthStart) return qualified;
  return RANK_ORDER[qualified] > RANK_ORDER[current] ? qualified : current;
}

/** The cherries a withdrawal of `amountMinor` holds: ceil(amount × rateCherries / rateMinor). */
export function withdrawalCherries(amountMinor: bigint, rateCherries: number, rateMinor: number): bigint {
  const numerator = amountMinor * BigInt(rateCherries);
  const divisor = BigInt(rateMinor);
  return (numerator + divisor - 1n) / divisor;
}

/** What `cherries` are worth in minor units at the rate (rounded down). */
export function cherriesValueMinor(cherries: bigint, rateCherries: number, rateMinor: number): bigint {
  if (cherries <= 0n) return 0n;
  return (cherries * BigInt(rateMinor)) / BigInt(rateCherries);
}

/** Invite codes: 8 characters without 0/O, 1/I (CHECK `agencies_shape`). */
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

export function newInviteCode(): string {
  let code = '';
  for (let i = 0; i < 8; i++) code += CODE_ALPHABET[randomInt(CODE_ALPHABET.length)];
  return code;
}

/** A typed code, normalized (trimmed, upper case), or null when it cannot be an invite code. */
export function normalizeInviteCode(raw: string): string | null {
  const code = raw.trim().toUpperCase();
  return /^[A-HJ-NP-Z2-9]{8}$/.test(code) ? code : null;
}

/** `YYYY-MM-01` of `now` in `timeZone` (the boards' clock, LIVE_RANKINGS_TIME_ZONE). */
export function monthKey(now: Date, timeZone: string): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
  }).formatToParts(now);
  const year = parts.find((p) => p.type === 'year')!.value;
  const month = parts.find((p) => p.type === 'month')!.value;
  return `${year}-${month}-01`;
}

/** `YYYY-MM-01` moved by `months` calendar months. */
export function addMonths(month: string, months: number): string {
  const [y, m] = month.split('-').map(Number) as [number, number];
  const index = y * 12 + (m - 1) + months;
  const year = Math.floor(index / 12);
  const mm = (index % 12) + 1;
  return `${String(year).padStart(4, '0')}-${String(mm).padStart(2, '0')}-01`;
}

/** A `DATE` column value for `YYYY-MM-DD`. */
export function dateValue(date: string): Date {
  return new Date(`${date}T00:00:00.000Z`);
}

/** v1.53-social (D184): the task-cherry lock of one person (CONVENTIONS §10.46.1). */
export interface TaskCherryLock {
  /** The unlock rule passed (or there is no rule: threshold 0). */
  readonly unlocked: boolean;
  /** Task cherries not withdrawable now (0 when unlocked). */
  readonly lockedCherries: bigint;
  /** Lifetime gift cherries (reversals subtracted) at the payout rate, minor units. */
  readonly giftValueMinor: bigint;
  readonly thresholdMinor: bigint;
}

/**
 * The unlock rule for task-reward cherries (owner, confirmed 2026-10-30): lifetime gift cherries received
 * (reversals subtracted) worth at least `thresholdMinor` ($50) at the payout rate unlock every task cherry;
 * until then all task cherries ever credited stay locked.
 */
export function taskCherryLock(
  taskCherries: bigint,
  giftCherriesNet: bigint,
  thresholdMinor: number,
  rateCherries: number,
  rateMinor: number,
): TaskCherryLock {
  const giftValueMinor = cherriesValueMinor(giftCherriesNet, rateCherries, rateMinor);
  const threshold = BigInt(thresholdMinor);
  const unlocked = threshold === 0n || giftValueMinor >= threshold;
  return {
    unlocked,
    lockedCherries: unlocked || taskCherries < 0n ? 0n : taskCherries,
    giftValueMinor,
    thresholdMinor: threshold,
  };
}

/** What may be withdrawn: the balance minus the locked task cherries (never below 0). */
export function withdrawableCherries(balance: bigint, lockedCherries: bigint): bigint {
  const free = balance - lockedCherries;
  return free > 0n ? free : 0n;
}
