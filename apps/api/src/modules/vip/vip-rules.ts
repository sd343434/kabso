/**
 * «شراء VIP» (v1.82-social, D252, owner 2026-11-03, CONVENTIONS §10.93): the rules of a purchase and of a tier's fields,
 * with no Nest or database dependency (unit-tested in `vip-rules.spec.ts`).
 *
 * The owner manages the tiers in the admin panel: names, order (rank), colour, badge art, price in coins, length in days,
 * on / off, and each tier's own perks. A person holds at most one membership; renewal is manual (never charged on its
 * own, CP-024 §3).
 */

const DAY_MS = 86_400_000;

/** A tier's or a perk's code: stable, upper case. */
export const VIP_CODE_PATTERN = /^[A-Z][A-Z0-9_]{0,39}$/;
/** A tier's colour, `#RRGGBB` upper case. */
export const VIP_COLOR_PATTERN = /^#[0-9A-F]{6}$/;
export const VIP_MAX_TIERS = 20;
export const VIP_MAX_PERKS = 20;
export const VIP_MAX_PRICE_COINS = 1_000_000_000_000;
export const VIP_MAX_DURATION_DAYS = 365;
/** A renewal may not take the end further than this many days from now (prepaying is capped, as premium usernames). */
export const VIP_MAX_AHEAD_DAYS = 400;

/**
 * D258 (owner): the renewal discount also applies this many days after a membership ended (buying the same tier
 * again); never on a first purchase or an upgrade.
 */
export const VIP_RENEWAL_GRACE_DAYS = 7;

/** D258: a tier's renewal discount bounds (percent, whole) and its default. */
export const VIP_RENEWAL_DISCOUNT_MAX = 90;
export const VIP_RENEWAL_DISCOUNT_DEFAULT = 15;

/** D258: [price] with [percent] off, rounded down to whole coins. */
export function vipDiscounted(price: bigint, percent: number): bigint {
  if (percent <= 0) return price;
  return (price * BigInt(100 - percent)) / 100n;
}

/**
 * D258: whether buying [tierId] now is a renewal that earns the tier's discount — the caller's membership is of that
 * tier and is active, or ended at most {@link VIP_RENEWAL_GRACE_DAYS} days ago.
 */
export function vipRenewalApplies(
  held: { tierId: string; expiresAt: Date } | null,
  tierId: string,
  now: Date,
): boolean {
  if (held === null || held.tierId !== tierId) return false;
  return now.getTime() <= held.expiresAt.getTime() + VIP_RENEWAL_GRACE_DAYS * DAY_MS;
}

/**
 * The perk codes the app really does today. A perk whose code is not here is shown as listed («قريباً»), never as
 * active — the owner can describe any perk in the panel, but only the server says whether it works (CONVENTIONS
 * §10.93.3). D258 (owner's VIP 1 perks): built one by one, §10.94.
 */
export const VIP_BUILT_PERKS: ReadonlySet<string> = new Set<string>([
  'BADGE',
  'AVATAR_FRAME',
  'CHAT_NAME_COLOR',
  'CHAT_BUBBLE',
  'PROFILE_CARD',
  // Phase 2 (the app draws them from the art; §10.94.7).
  'ENTRY_BANNER',
  'ENTRY_EFFECT',
  'MIC_WAVE',
  // Phase 4: «من زار ملفي» (§10.94.9).
  'PROFILE_VISITORS',
  // Free public messages a day and the level speed-up (§10.94.4); the daily coins (§10.94.5).
  'DAILY_BULLET',
  'DAILY_COINS',
  'LEVEL_SPEEDUP',
]);

/**
 * D258: the perks that take a number per tier (`VipTierPerk.amount`) and its bounds: free public messages a day,
 * coins a day, the level speed-up in percent. Absent (null) = the perk gives nothing until the owner sets it.
 */
export const VIP_PERK_AMOUNTS: Readonly<Record<string, { readonly min: number; readonly max: number }>> = {
  DAILY_BULLET: { min: 1, max: 100 },
  DAILY_COINS: { min: 1, max: 1_000_000_000 },
  LEVEL_SPEEDUP: { min: 1, max: 100 },
};

/** The perk codes the panel suggests (CP-024 §3; the same vocabulary as SVIP). Any other code is allowed too. */
export const VIP_SUGGESTED_PERKS = [
  'BADGE',
  'AVATAR_FRAME',
  'CHAT_NAME_COLOR',
  'ENTRY_BANNER',
  'ENTRY_EFFECT',
  'MIC_WAVE',
  'CHAT_BUBBLE',
  'DAILY_BULLET',
  'PROFILE_VISITORS',
  'DAILY_COINS',
  'LEVEL_SPEEDUP',
  'PROFILE_CARD',
  'VIEWER_LIST_PRIORITY',
  'MONTHLY_GIFT',
] as const;

/** A perk as the inheritance sees it. */
export interface VipPerkRow {
  readonly code: string;
  readonly enabled: boolean;
}

/**
 * D258 (owner: «كل مستوى يحمل امتيازات ما قبله»): the perks a holder of the tier ranked [rank] has — every enabled
 * perk of the tiers ranked up to it, by code; for a code several tiers list, the highest-ranked tier's perk (its art
 * and amount). [tiers] are any tiers (on or off sale: a holder keeps what their tier gave).
 */
export function vipEffectivePerks<P extends VipPerkRow>(
  tiers: readonly { readonly rank: number; readonly perks: readonly P[] }[],
  rank: number,
): Map<string, P> {
  const out = new Map<string, P>();
  const below = tiers.filter((t) => t.rank <= rank).sort((a, b) => a.rank - b.rank);
  for (const t of below) {
    for (const p of t.perks) if (p.enabled) out.set(p.code, p);
  }
  return out;
}

export function vipPerkAvailable(code: string): boolean {
  return VIP_BUILT_PERKS.has(code);
}

export type VipPurchaseKind = 'NEW' | 'RENEW' | 'UPGRADE';
/** Why a purchase is refused (409 `VIP_UNAVAILABLE`, `details: [{field: 'tier', issue}]`). */
export type VipRefusal = 'tier_off' | 'downgrade' | 'renewal_limit';

export interface VipCurrent {
  readonly tierId: string;
  /** The held tier's `sortOrder` now. */
  readonly rank: number;
  readonly startedAt: Date;
  readonly expiresAt: Date;
}

export interface VipTarget {
  readonly id: string;
  readonly rank: number;
  readonly enabled: boolean;
  readonly durationDays: number;
}

export type VipPlan =
  | { readonly ok: true; readonly kind: VipPurchaseKind; readonly startedAt: Date; readonly expiresAt: Date }
  | { readonly ok: false; readonly refusal: VipRefusal };

/** Whether a membership ending at [expiresAt] is active at [now]. */
export function vipActive(expiresAt: Date | null | undefined, now: Date): boolean {
  return expiresAt !== null && expiresAt !== undefined && expiresAt.getTime() > now.getTime();
}

/**
 * What buying [target] does for a person holding [current] at [now] (CONVENTIONS §10.93.2):
 *
 * - **NEW** — no membership, or it ended: `durationDays` from now.
 * - **RENEW** — the same tier while active: the end moves by `durationDays` (nothing is lost); refused
 *   (`renewal_limit`) when the end would be more than {@link VIP_MAX_AHEAD_DAYS} days from now.
 * - **UPGRADE** — a higher tier (higher `sortOrder`) while active: the new tier at once, `durationDays` from now, at its
 *   full price; the days left of the lower tier are not carried over or refunded (the app says so before paying).
 * - A lower or equal-rank other tier while active is refused (`downgrade`): it can be bought once the membership ends.
 * - A tier that is switched off is refused (`tier_off`), even as a renewal (the held one stays until its end).
 */
export function planVipPurchase(current: VipCurrent | null, target: VipTarget, now: Date): VipPlan {
  if (!target.enabled) return { ok: false, refusal: 'tier_off' };
  const length = target.durationDays * DAY_MS;
  if (current === null || !vipActive(current.expiresAt, now)) {
    return { ok: true, kind: 'NEW', startedAt: now, expiresAt: new Date(now.getTime() + length) };
  }
  if (current.tierId === target.id) {
    const expiresAt = new Date(current.expiresAt.getTime() + length);
    if (expiresAt.getTime() > now.getTime() + VIP_MAX_AHEAD_DAYS * DAY_MS) {
      return { ok: false, refusal: 'renewal_limit' };
    }
    return { ok: true, kind: 'RENEW', startedAt: current.startedAt, expiresAt };
  }
  if (target.rank > current.rank) {
    return { ok: true, kind: 'UPGRADE', startedAt: now, expiresAt: new Date(now.getTime() + length) };
  }
  return { ok: false, refusal: 'downgrade' };
}

/** Whole days left until [expiresAt] (rounded up; 0 once it ended). */
export function vipDaysLeft(expiresAt: Date, now: Date): number {
  return Math.max(0, Math.ceil((expiresAt.getTime() - now.getTime()) / DAY_MS));
}

/** A tier order: [ids] must name every tier exactly once; the new `sortOrder` of each (1 … n). */
export function vipOrderOf(ids: readonly string[], existing: readonly string[]): Map<string, number> | null {
  if (ids.length !== existing.length || new Set(ids).size !== ids.length) return null;
  const known = new Set(existing);
  if (!ids.every((id) => known.has(id))) return null;
  return new Map(ids.map((id, i) => [id, i + 1]));
}

/**
 * D258 (§10.94.5): level points raised by a VIP's LEVEL_SPEEDUP percent (rounded down; nothing without the perk).
 * Only earned points: reversals and adjustments never pass here.
 */
export function vipSpedUp(points: bigint, percent: number | null): bigint {
  if (percent === null || percent <= 0 || points <= 0n) return points;
  return points + (points * BigInt(percent)) / 100n;
}
