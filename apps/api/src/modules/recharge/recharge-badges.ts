import type { Prisma } from '../../generated/prisma/client.js';
import { dayKey } from './recharge-rules.js';

/**
 * The daily recharge badges «شارات الشحن اليومي» (v1.56-social, D187, CONVENTIONS §10.50). The coins a person
 * RECEIVED from recharges in one calendar day (`RECHARGE_BADGE_TIME_ZONE`, default Asia/Riyadh) give a tier
 * 1–5 (`RECHARGE_BADGE_TIERS`); the badge shows for `RECHARGE_BADGE_HOURS` (24) from the moment the tier was
 * reached, and a higher tier the same day replaces it and starts the hours again. What counts is a recharge
 * agent's sale to the buyer (D185) and, once it exists, a website top-up — both through [recordRechargeIn],
 * inside the transaction that credits the coins. Gifts, rewards, admin credits and transfers never call it.
 * Recharge agents (from approval on) never get the badge, as buyers or sellers.
 */

/** What credited the coins. `WEBSITE_TOPUP`: the hook for the future website top-up (no flow yet). */
export type RechargeSource = 'AGENT_SALE' | 'WEBSITE_TOPUP';

export interface RechargeBadgeRules {
  /** The minimum coins in one day for tiers 1…5, increasing. */
  readonly tierMins: readonly number[];
  /** The IANA zone of the calendar day. */
  readonly timeZone: string;
  /** How long a badge shows from the moment its tier was reached. */
  readonly hours: number;
}

/** `RechargeBadge` (openapi v1.56-social). */
export interface RechargeBadgeDto {
  tier: number;
  until: string;
}

/** The tier of a day's total (0: below tier 1). */
export function rechargeBadgeTier(total: bigint, tierMins: readonly number[]): number {
  let tier = 0;
  tierMins.forEach((min, i) => {
    if (total >= BigInt(min)) tier = i + 1;
  });
  return tier;
}

/** The badge to show at `now`: only while `until` is after `now`, never for a recharge agent. */
export function activeRechargeBadge(
  row: { tier: number; until: Date } | null | undefined,
  now: Date,
  isAgent = false,
): RechargeBadgeDto | null {
  if (!row || isAgent || row.tier < 1) return null;
  if (row.until.getTime() <= now.getTime()) return null;
  return { tier: row.tier, until: row.until.toISOString() };
}

export interface RechargeRecorded {
  /** The calendar day (YYYY-MM-DD in the rules' zone). */
  readonly day: string;
  /** The day's total after this recharge. */
  readonly dayTotal: bigint;
  /** The day's tier after this recharge (0: none yet). */
  readonly tier: number;
  /** Whether this recharge reached a new tier and (re)started the badge. */
  readonly badgeChanged: boolean;
}

/**
 * Counts `coins` RECEIVED by `userId` from a recharge at `now`, in the caller's transaction (the agent's sale;
 * later a website top-up): adds them to the person's total of the day and, when the total crosses into a
 * higher tier, gives that tier's badge until `now + hours`. A badge from an earlier day that is still showing
 * and is higher stays (a lower tier the next day does not replace it). Null for a recharge agent (nothing is
 * counted). The daily row's lock serializes the person's concurrent recharges.
 */
export async function recordRechargeIn(
  tx: Prisma.TransactionClient,
  input: { userId: string; coins: bigint; source: RechargeSource; now: Date },
  rules: RechargeBadgeRules,
): Promise<RechargeRecorded | null> {
  if (input.coins <= 0n) throw new RangeError('A recharge is positive');
  const [agent] = await tx.$queryRaw<{ agent: boolean }[]>`
    SELECT EXISTS (SELECT 1 FROM recharge_agents WHERE user_id = ${input.userId}::uuid) AS agent`;
  if (agent?.agent) return null;
  const day = dayKey(input.now, rules.timeZone);
  const [row] = await tx.$queryRaw<{ coins: bigint }[]>`
    INSERT INTO recharge_daily_totals (user_id, day, coins, tier, updated_at)
    VALUES (${input.userId}::uuid, ${day}::date, ${input.coins}, 0, ${input.now})
    ON CONFLICT (user_id, day) DO UPDATE
      SET coins = recharge_daily_totals.coins + EXCLUDED.coins, updated_at = EXCLUDED.updated_at
    RETURNING coins`;
  const dayTotal = BigInt(row!.coins);
  const tier = rechargeBadgeTier(dayTotal, rules.tierMins);
  const before = rechargeBadgeTier(dayTotal - input.coins, rules.tierMins);
  if (tier <= before) return { day, dayTotal, tier, badgeChanged: false };
  await tx.$executeRaw`
    UPDATE recharge_daily_totals SET tier = ${tier}
     WHERE user_id = ${input.userId}::uuid AND day = ${day}::date`;
  const until = new Date(input.now.getTime() + rules.hours * 3_600_000);
  const changed = await tx.$executeRaw`
    INSERT INTO recharge_badges AS b (user_id, badge_tier, badge_until, badge_day, reached_at)
    VALUES (${input.userId}::uuid, ${tier}, ${until}, ${day}::date, ${input.now})
    ON CONFLICT (user_id) DO UPDATE
      SET badge_tier = EXCLUDED.badge_tier, badge_until = EXCLUDED.badge_until,
          badge_day = EXCLUDED.badge_day, reached_at = EXCLUDED.reached_at
      WHERE b.badge_day = EXCLUDED.badge_day
         OR b.badge_until <= EXCLUDED.reached_at
         OR b.badge_tier <= EXCLUDED.badge_tier`;
  return { day, dayTotal, tier, badgeChanged: changed > 0 };
}
