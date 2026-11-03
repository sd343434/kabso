/**
 * «شراء VIP» (v1.82-social, D252, owner 2026-11-03, CONVENTIONS §10.92): the rules of a purchase and of a tier's fields,
 * with no Nest or database dependency (unit-tested in `vip-rules.spec.ts`).
 *
 * The owner manages the tiers in the admin panel: names, order (rank), colour, emblem, price in coins, length in days,
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
 * The perk codes the app really does today. A perk whose code is not here is shown as listed («قريباً»), never as
 * active — the owner can describe any perk in the panel, but only the server says whether it works (CONVENTIONS
 * §10.92.3). None is built yet: each needs Kabso-owned art or a change in the live room (follow-ups in D252).
 */
export const VIP_BUILT_PERKS: ReadonlySet<string> = new Set<string>();

/** The perk codes the panel suggests (CP-024 §3; the same vocabulary as SVIP). Any other code is allowed too. */
export const VIP_SUGGESTED_PERKS = [
  'BADGE',
  'AVATAR_FRAME',
  'CHAT_NAME_COLOR',
  'ENTRY_BANNER',
  'ENTRY_EFFECT',
  'DAILY_BULLET',
  'VIEWER_LIST_PRIORITY',
  'MONTHLY_GIFT',
] as const;

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
 * What buying [target] does for a person holding [current] at [now] (CONVENTIONS §10.92.2):
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
