import { createHash } from 'node:crypto';

/**
 * v1.110-social (D345, CONVENTIONS §10.144): the pure rules of store purchases — the account token a purchase is bound
 * to, the reason shown for a refund ban, the consumption percentage and the context buckets of a consumption request.
 */

export type IapPlatformName = 'GOOGLE_PLAY' | 'APP_STORE';
export type AppPlatform = 'ANDROID' | 'IOS';

export const PLATFORM_OF: Record<AppPlatform, IapPlatformName> = { ANDROID: 'GOOGLE_PLAY', IOS: 'APP_STORE' };

/** Android's `obfuscatedAccountId`: SHA-256 hex of the account id (≤ 64 characters, no personal data). */
export function androidAccountToken(userId: string): string {
  return createHash('sha256').update(`kabso-live/store-account/v1|${userId}`).digest('hex');
}

/** iOS StoreKit 2's `appAccountToken`: the account id itself (a UUID), lower case. */
export function iosAccountToken(userId: string): string {
  return userId.toLowerCase();
}

export function accountTokenOf(platform: AppPlatform, userId: string): string {
  return platform === 'ANDROID' ? androidAccountToken(userId) : iosAccountToken(userId);
}

export function tokenHash(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

/** Google's `voidedReason` names (Android Publisher v3). */
export const VOIDED_REASONS: Record<number, string> = {
  0: 'other',
  1: 'remorse',
  2: 'not_received',
  3: 'defective',
  4: 'accidental_purchase',
  5: 'fraud',
  6: 'friendly_fraud',
  7: 'chargeback',
};

/** Google's `voidedSource`: 1 = the developer (the team in Play Console) — such a void never bans. */
export const VOIDED_SOURCE_DEVELOPER = 1;

/** The day as YYYY-MM-DD (UTC). */
function day(at: Date): string {
  return at.toISOString().slice(0, 10);
}

/**
 * The reason of a refund ban, shown in the panel and as DEVICE_BANNED's reason: «استرداد عبر Google Play بتاريخ … —
 * طلب …» / «استرداد عبر App Store بتاريخ … — معاملة …» (+ Google's reason name). At most 500 characters.
 */
export function refundReasonText(
  platform: IapPlatformName,
  at: Date,
  transactionId: string,
  extra: string | null = null,
): string {
  const text =
    platform === 'GOOGLE_PLAY'
      ? `استرداد عبر Google Play بتاريخ ${day(at)} — طلب ${transactionId}`
      : `استرداد عبر App Store بتاريخ ${day(at)} — معاملة ${transactionId}`;
  return (extra ? `${text} (${extra})` : text).slice(0, 500);
}

/** The share of the purchase already spent, in milliunits (0 … 100 000), rounded down. */
export function consumptionPercentage(coins: bigint, unspent: bigint): number {
  if (coins <= 0n) return 0;
  const spent = coins - (unspent < 0n ? 0n : unspent > coins ? coins : unspent);
  return Number((spent * 100_000n) / coins);
}

/** ConsumptionRequestV1's `accountTenure` bucket (kept in the request's context; not sent, §10.144.5). */
export function tenureBucket(days: number): number {
  if (days < 3) return 1;
  if (days < 10) return 2;
  if (days < 30) return 3;
  if (days < 90) return 4;
  if (days < 180) return 5;
  if (days < 365) return 6;
  return 7;
}

/** ConsumptionRequestV1's lifetime-dollars bucket of an amount in US cents (context only). */
export function dollarsBucket(cents: number): number {
  if (cents <= 0) return 1;
  if (cents < 5_000) return 2;
  if (cents < 10_000) return 3;
  if (cents < 50_000) return 4;
  if (cents < 100_000) return 5;
  if (cents < 200_000) return 6;
  return 7;
}

/** ConsumptionRequestV1's `userStatus` (context only): 1 active, 2 suspended, 3 terminated, 0 undeclared. */
export function userStatusCode(status: string): number {
  if (status === 'ACTIVE') return 1;
  if (status === 'SUSPENDED') return 2;
  if (status === 'DELETED' || status === 'PENDING_DELETION') return 3;
  return 0;
}

/** Apple's consumption-request deadline: 12 hours after the notification. */
export const CONSUMPTION_DEADLINE_MS = 12 * 3_600_000;

/** The voided-purchases window: at most 30 days back, overlapping the last poll by 1 hour. */
export const VOIDED_MAX_WINDOW_MS = 30 * 86_400_000;
export const VOIDED_OVERLAP_MS = 3_600_000;

export function voidedWindow(
  polledUntil: Date | null,
  now: Date,
  backMs: number | null = null,
): [number, number] {
  const end = now.getTime();
  const floor = end - VOIDED_MAX_WINDOW_MS + 60_000;
  let start =
    backMs !== null ? end - backMs : polledUntil ? polledUntil.getTime() - VOIDED_OVERLAP_MS : floor;
  if (start < floor) start = floor;
  return [start, end];
}
