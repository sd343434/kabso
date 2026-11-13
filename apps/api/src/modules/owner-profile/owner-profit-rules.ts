/**
 * v1.95-social (D301 follow-up, owner 2026-11-07: «اريد عند حساب الارباح على صفحتي كمؤسس ان تزيل نسب الجميع لكون ربح
 * نهائي وضعها قبل وبعد … تكاليف ثابتة … يتم تقسيمها على الشهر»; CONVENTIONS §10.112.10): the pure parts of «الربح» —
 * the periods (local days of the dashboard's zone), the proration of the fixed monthly costs, and the deduction lines
 * read from the cherry ledger. No database, no clock.
 */

/** A local calendar day `YYYY-MM-DD`. */
export const DAY_KEY = /^(\d{4})-(\d{2})-(\d{2})$/;

/** The earliest day «الربح» may be asked for (nothing older exists). */
export const PROFIT_FIRST_DAY = '2026-01-01';

/** The days of a month (1-based month). */
export function daysInMonth(year: number, month: number): number {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

/** Whether `day` is a real calendar day `YYYY-MM-DD`. */
export function isDayKey(day: string): boolean {
  const m = DAY_KEY.exec(day);
  if (!m) return false;
  const [y, mo, d] = [Number(m[1]), Number(m[2]), Number(m[3])];
  return mo >= 1 && mo <= 12 && d >= 1 && d <= daysInMonth(y, mo);
}

/** A period of whole local days, both ends included. */
export interface ProfitPeriod {
  readonly kind: 'DAY' | 'MONTH';
  /** `YYYY-MM-DD` for a day, `YYYY-MM` for a month. */
  readonly key: string;
  readonly from: string;
  readonly to: string;
  /** The days covered (1 for a day; the elapsed days for the current month). */
  readonly days: number;
  readonly daysInMonth: number;
  /** The current month counted to today only (the elapsed share of the fixed costs). */
  readonly partial: boolean;
}

const pad = (n: number) => String(n).padStart(2, '0');

/**
 * The day `day` and its month: a past month whole; the current month (the one holding `today`) from its 1st to
 * `today`, `partial`.
 */
export function periodsOf(day: string, today: string): { day: ProfitPeriod; month: ProfitPeriod } {
  const [y, mo] = day.split('-').map(Number) as [number, number];
  const dim = daysInMonth(y, mo);
  const monthKey = `${String(y)}-${pad(mo)}`;
  const current = today.startsWith(monthKey);
  const lastDay = current ? Number(today.slice(8, 10)) : dim;
  return {
    day: { kind: 'DAY', key: day, from: day, to: day, days: 1, daysInMonth: dim, partial: false },
    month: {
      kind: 'MONTH',
      key: monthKey,
      from: `${monthKey}-01`,
      to: `${monthKey}-${pad(lastDay)}`,
      days: lastDay,
      daysInMonth: dim,
      partial: current && lastDay < dim,
    },
  };
}

/** A fixed monthly cost as the proration reads it (days `YYYY-MM-DD`, `to` null = open-ended). */
export interface FixedCostTerm {
  readonly monthlyMinor: bigint;
  readonly activeFrom: string;
  readonly activeTo: string | null;
}

/** The days of [from, to] (keys of one month) on which the cost is active. */
export function activeDays(cost: FixedCostTerm, from: string, to: string): number {
  const start = cost.activeFrom > from ? cost.activeFrom : from;
  const end = cost.activeTo !== null && cost.activeTo < to ? cost.activeTo : to;
  if (start > end) return 0;
  return Number(end.slice(8, 10)) - Number(start.slice(8, 10)) + 1;
}

/**
 * The cost's share of a period inside one month: monthly × active days ÷ the days of the month, rounded half up
 * (owner: «يتم تقسيمها على الشهر» — $300 a month in a 30-day month is $10 a day; a whole month is the whole amount).
 */
export function fixedCostShare(cost: FixedCostTerm, period: ProfitPeriod): bigint {
  const days = BigInt(activeDays(cost, period.from, period.to));
  if (days === 0n) return 0n;
  const dim = BigInt(period.daysInMonth);
  return (cost.monthlyMinor * days * 2n + dim) / (dim * 2n);
}

/** The deduction lines of «الربح», in display order. */
export const PROFIT_DEDUCTIONS = [
  'GIFTS',
  'AGENCY_COMMISSIONS',
  'REFERRAL_REWARDS',
  'TASK_REWARDS',
  'STAFF_COMMISSIONS',
  'TEAM_ADJUSTMENTS',
  'COIN_REWARDS',
  'CARD_FEES',
] as const;
export type ProfitDeduction = (typeof PROFIT_DEDUCTIONS)[number];

/**
 * The cherry-ledger reasons each cherry line sums (net: a reversal or a forfeit is negative). Every cherry credited
 * to someone is money Kabso owes at the payout rate (`CHERRY_PAYOUT_RATE`), counted when credited (not when withdrawn,
 * which would count it twice). Not costs: `WITHDRAWAL_*` (the payout of cherries already counted), `RECHARGE_SALE`
 * and `STORE_PURCHASE` (cherries handed back).
 */
export const CHERRY_LINES: Readonly<
  Record<Exclude<ProfitDeduction, 'CARD_FEES' | 'COIN_REWARDS'>, readonly string[]>
> = {
  GIFTS: ['GIFT_RECEIVED', 'GIFT_REVERSAL'],
  AGENCY_COMMISSIONS: [
    'AGENCY_COMMISSION',
    'PARENT_COMMISSION',
    'AGENCY_COMMISSION_REVERSAL',
    'PARENT_COMMISSION_REVERSAL',
    'AGENCY_FORFEIT',
  ],
  // v1.140-social (D390, §10.179.10): the ambassadors' commissions are referral costs too (net of their claw-backs).
  REFERRAL_REWARDS: [
    'REFERRAL_REWARD',
    'REFERRAL_REVERSAL',
    'AMBASSADOR_COMMISSION',
    'AMBASSADOR_COMMISSION_REVERSAL',
  ],
  TASK_REWARDS: ['TASK_REWARD', 'HOST_TARGET_REWARD'],
  STAFF_COMMISSIONS: ['STAFF_RECRUIT_COMMISSION'],
  TEAM_ADJUSTMENTS: ['ADMIN_ADJUSTMENT'],
};

/** Every reason a cherry line reads. */
export const CHERRY_COST_REASONS: readonly string[] = Object.values(CHERRY_LINES).flat();

/**
 * COIN_REWARDS: the coins Kabso gives away (event prizes, task and check-in coins), valued conservatively at the lowest
 * price an agent pays Kabso (owner: $120 per 10 000 000 coins, `OWNER_PROFIT_COIN_VALUE_MINOR_PER_MILLION`).
 */
export const FREE_COIN_REASONS = [
  'EVENT_PRIZE',
  'TASK_REWARD',
  'CHECK_IN_REWARD',
  // v1.140-social (D390, §10.179.10): an ambassador's monthly target reward in coins.
  'AMBASSADOR_REWARD',
] as const;

/**
 * v1.100-social (D312, CONVENTIONS §10.118; owner: «وتُحسب كتكلفة في الربح»): the custom gift owners' coin shares are coins
 * Kabso gives away too — counted in COIN_REWARDS, net of their claw-backs (a reversed send's
 * `GIFT_OWNER_ROYALTY_REVERSAL` is negative), at the same conservative coin value.
 */
export const GIFT_OWNER_COIN_REASONS = ['GIFT_OWNER_ROYALTY', 'GIFT_OWNER_ROYALTY_REVERSAL'] as const;

/** Coins' value in US cents at `minorPerMillion` cents per 1 000 000 coins, rounded half up. */
export function coinMoney(coins: bigint, minorPerMillion: number): bigint {
  if (coins <= 0n) return 0n;
  return (coins * BigInt(minorPerMillion) * 2n + 1_000_000n) / 2_000_000n;
}

/**
 * The cherries' value in minor units of the payout currency at `rateCherries` cherries = `rateMinor`, rounded half
 * away from zero (a negative net — more reversed than credited — lowers the costs).
 */
export function cherryMoney(cherries: bigint, rateCherries: number, rateMinor: number): bigint {
  const num = cherries * BigInt(rateMinor) * 2n;
  const den = BigInt(rateCherries) * 2n;
  return cherries >= 0n ? (num + BigInt(rateCherries)) / den : -((-num + BigInt(rateCherries)) / den);
}

/** The estimated card fees of `orders` card orders charging `chargedMinor` (owner answer CP-039 Q3). */
export function cardFees(
  chargedMinor: bigint,
  orders: bigint,
  fee: { bps: number; fixedMinor: number },
): bigint {
  if (orders <= 0n) return 0n;
  return (chargedMinor * BigInt(fee.bps) + 5_000n) / 10_000n + orders * BigInt(fee.fixedMinor);
}
