/**
 * v1.90-social (D293, CONVENTIONS §10.105): the automatic verification badge «شارة التوثيق» — the pure rules (no
 * database, no Nest), shared by the core, the API, the CLI and the unit tests.
 *
 * Owner (2026-11-06): a person shows ONE badge, granted automatically by conditions over the LAST 30 DAYS (rolling);
 * when several apply the highest of this order wins (the owner also expects a person to qualify for one at most —
 * the order only makes an overlap deterministic):
 *
 *  1. OWNER — RESERVED since v1.118-social (D357, owner 2026-11-10: «ازيلها»): the app owner (the panel role OWNER)
 *     shows NO seal at all — holding OWNER suppresses every other badge (`pickBadge` → null), so the founder's only
 *     mark is the app's red photo seal on his own profile. The value stays in the enum (older apps still parse it;
 *     the panel's holders count reads 0) but is never stored or sent;
 *  2. STAFF — red: the Kabso Team (MODERATION, SUPPORT, FINANCE, BD; D283's limited staff);
 *  3. RECHARGE_AGENT — gold: an ACTIVE recharge agent who sold more than N coins AND bought more than M
 *     cherries from hosts in the window (the agent's employees' work counts on the agent's account, D287);
 *  4. HOST_AGENT — green: a host agent whose agency has more than H active hosts now AND whose hosts received
 *     more than C cherries in the window;
 *  5. CREATOR — purple: a member of the creator programme (D285 `creator_members`);
 *  6. VERIFIED_HOST — blue: a host whose identity was approved — a Didit check (D227: document, liveness, face
 *     match) or, owner 2026-11-06, the team's manual review of the ID card and selfie (an APPROVED D209 application).
 */
export const VERIFICATION_BADGES = [
  'OWNER',
  'STAFF',
  'RECHARGE_AGENT',
  'HOST_AGENT',
  'CREATOR',
  'VERIFIED_HOST',
] as const;
export type VerificationBadgeValue = (typeof VERIFICATION_BADGES)[number];

/** The owner's rolling window (not a setting: «آخر ٣٠ يوماً»). */
export const VERIFICATION_WINDOW_DAYS = 30;
const DAY_MS = 86_400_000;

/** The window's start for `now`. */
export function windowStart(now: Date): Date {
  return new Date(now.getTime() - VERIFICATION_WINDOW_DAYS * DAY_MS);
}

/** The OWNER's thresholds (`verification_badge_settings`). Every comparison is "more than". */
export interface VerificationThresholds {
  readonly rechargeMinSalesCoins: bigint;
  readonly rechargeMinCherries: bigint;
  readonly hostAgentMinHosts: number;
  readonly hostAgentMinCherries: bigint;
}

/** The owner's values (also the migration's defaults). */
export const DEFAULT_THRESHOLDS: VerificationThresholds = {
  rechargeMinSalesCoins: 300_000_000n,
  rechargeMinCherries: 300_000_000n,
  hostAgentMinHosts: 30,
  hostAgentMinCherries: 300_000_000n,
};

/** The largest threshold the panel accepts (10^15; the column CHECK says the same). */
export const MAX_THRESHOLD = 1_000_000_000_000_000n;
export const MAX_HOSTS_THRESHOLD = 100_000;

/** "More than": exactly the threshold does not qualify (owner: «أكثر من»). Exact BIGINT arithmetic. */
export function exceeds(value: bigint, threshold: bigint): boolean {
  return value > threshold;
}

/**
 * The highest badge of `held` by the owner's priority, or null when none applies. D357: the app owner (OWNER held)
 * shows none — not OWNER, and not a lower one (STAFF, CREATOR…) he may also qualify for.
 */
export function pickBadge(held: Iterable<VerificationBadgeValue>): VerificationBadgeValue | null {
  const set = new Set(held);
  if (set.has('OWNER')) return null;
  for (const b of VERIFICATION_BADGES) if (set.has(b)) return b;
  return null;
}

/** What happened to a person's badge in one recompute (the audit row's `change`). */
export type BadgeChange = 'granted' | 'changed' | 'removed';

export function changeOf(
  before: VerificationBadgeValue | null,
  after: VerificationBadgeValue | null,
): BadgeChange | null {
  if (before === after) return null;
  if (before === null) return 'granted';
  if (after === null) return 'removed';
  return 'changed';
}

/** The thresholds as the panel shows them (integers as JSON numbers; ≤ 10^15 is exact in a double). */
export interface VerificationThresholdsDto {
  rechargeMinSalesCoins: number;
  rechargeMinCherries: number;
  hostAgentMinHosts: number;
  hostAgentMinCherries: number;
}

export function thresholdsDto(t: VerificationThresholds): VerificationThresholdsDto {
  return {
    rechargeMinSalesCoins: Number(t.rechargeMinSalesCoins),
    rechargeMinCherries: Number(t.rechargeMinCherries),
    hostAgentMinHosts: t.hostAgentMinHosts,
    hostAgentMinCherries: Number(t.hostAgentMinCherries),
  };
}
