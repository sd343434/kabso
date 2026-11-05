import {
  cherryUnits,
  coinUnits,
  maxNormalShareBps,
  rewardCherriesFor,
  type ProfitEconomy,
} from '../programs/host-target-engine.js';

/**
 * v1.75-live (D285, owner, CONVENTIONS §10.96.13): the recruiter's automatic commission — a share of the PLATFORM PROFIT
 * each recruit generates, in D281's exact money units (`platformProfitUnits`: micro-cents × `rateCherries`, so a coin
 * and a cherry are whole numbers). Pure functions (no database): the queries sum the rows, these turn the sums into
 * profit and cherries.
 *
 * Per recruit type (one programs' day, from the activation on):
 *  - **HOST** / **CREATOR** — the gifts the recruit RECEIVED (every live gift to them, the sender ACTIVE, as D281):
 *    the coins paid − the recruit's cherries (net of reversals) − the agency and parent commissions paid on those
 *    sends (net of reversals) − for a lucky gift the expected payout to the sender (RTP × the coin value);
 *  - **AGENCY** — the same for the gifts received by the agency's hosts while linked to it (its `agency_earnings`
 *    rows; its own and its parent's commissions are costs);
 *  - **RECHARGE_AGENT** — the agent's wholesale top-ups recorded that day (the money actually paid, in the payout
 *    currency) − the payout value of the cherries those coins become when gifted (coins × CHERRIES_PER_COIN × the
 *    highest normal host share, D281's cautious share).
 *
 * The commission is floor(profit × share / cherry value); 0 when the profit is 0 or negative. Never more than the
 * share of the ACTUAL profit counted (the owner's guard, also a CHECK in the database).
 */

export const RECRUIT_TYPES = ['HOST', 'AGENCY', 'RECHARGE_AGENT', 'CREATOR'] as const;
export type RecruitType = (typeof RECRUIT_TYPES)[number];

/** The owner's suggested defaults (basis points): 2 % hosts and creators, 1 % agencies and recharge agents. */
export const DEFAULT_RECRUIT_BPS: Readonly<Record<RecruitType, number>> = {
  HOST: 200,
  CREATOR: 200,
  AGENCY: 100,
  RECHARGE_AGENT: 100,
};

/** The highest share the OWNER may set (20 %; the CHECK `staff_recruit_settings_shape`). */
export const MAX_RECRUIT_BPS = 2000;

/** The sums of one day's gift sends that a HOST / CREATOR / AGENCY recruit's profit reads. */
export interface GiftSums {
  /** The coins paid for the sends (a gift from the bag or a free quip: 0). */
  readonly charged: bigint;
  /** The coin value of the lucky sends (their expected payout to the sender is a cost). */
  readonly luckyCoins: bigint;
  /** The cherries credited to the recipients (net of reversals). */
  readonly cherries: bigint;
  /** The agency and parent commissions paid on the sends (net of reversals). */
  readonly commissions: bigint;
}

/** The sums of one day's wholesale top-ups of a recharge agent. */
export interface TopupSums {
  /** The money paid, minor units of the payout currency. */
  readonly paidMinor: bigint;
  readonly coins: bigint;
}

/** The platform profit of gift sends (money units; may be negative). */
export function giftProfitUnits(s: GiftSums, e: ProfitEconomy): bigint {
  const coin = coinUnits(e);
  const cherry = cherryUnits(e);
  return (
    s.charged * coin - (s.cherries + s.commissions) * cherry - (s.luckyCoins * BigInt(e.luckyRtpBps) * coin) / 10_000n
  );
}

/** The platform profit of wholesale top-ups (money units; may be negative). */
export function topupProfitUnits(t: TopupSums, e: ProfitEconomy): bigint {
  // A minor unit is 10^6 micro-minor; × rateCherries makes it money units (see `coinUnits`).
  const paid = t.paidMinor * 1_000_000n * BigInt(e.rateCherries);
  const cherriesOwed = (t.coins * BigInt(e.cherriesPerCoin) * BigInt(maxNormalShareBps(e))) / 10_000n;
  return paid - cherriesOwed * cherryUnits(e);
}

/** The commission in cherries: `bps` of the profit at the payout value of a cherry (floored; 0 without profit). */
export function commissionCherries(profitUnits: bigint, bps: number, e: ProfitEconomy): bigint {
  return BigInt(rewardCherriesFor(profitUnits, bps, e));
}

/** The owner's guard: `cherries` is never more than `bps` of the ACTUAL profit counted. */
export function withinGuard(cherries: bigint, profitUnits: bigint, bps: number, e: ProfitEconomy): boolean {
  if (cherries < 0n) return false;
  const profit = profitUnits > 0n ? profitUnits : 0n;
  return cherries * cherryUnits(e) * 10_000n <= profit * BigInt(bps);
}

/** Money units as US dollars (the payout currency), rounded to the micro-dollar, for display. */
export function unitsToUsd(units: bigint, e: ProfitEconomy): number {
  const microDollars = units / BigInt(e.rateCherries) / 100n;
  return Number(microDollars) / 1_000_000;
}

/** The ledger reference of a recruitment's commission of a day (`SR:<recruitment>@<day>`, 50 characters). */
export function recruitCommissionReference(recruitmentId: string, day: string): string {
  return `SR:${recruitmentId}@${day}`;
}
