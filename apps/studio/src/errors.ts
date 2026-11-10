import { ApiError } from './api';
import type { Key } from './i18n';

/** The message key (and variables) for an API error, in the studio's words. */
export function errorKey(err: unknown): { key: Key; vars?: Record<string, string> } {
  if (!(err instanceof ApiError)) return { key: 'errGeneric' };
  switch (err.code) {
    case 'NETWORK':
      return { key: 'errNetwork' };
    case 'AUTH_INVALID_CREDENTIALS':
      return { key: 'errCredentials' };
    case 'AUTH_UNAUTHENTICATED':
    case 'AUTH_REFRESH_INVALID':
      return { key: 'errSession' };
    case 'RATE_LIMITED':
      return { key: 'errRateLimited' };
    case 'ACCOUNT_LOCKED': {
      const until = err.details.find((d) => d.field === 'lockedUntil')?.issue ?? '';
      return { key: 'errLocked', vars: { until: until ? new Date(until).toLocaleString() : '—' } };
    }
    case 'ACCOUNT_DELETION_PENDING':
      return { key: 'errDeletionPending' };
    case 'LIVE_HOSTING_NOT_ALLOWED':
      return { key: 'gateNoPermission' };
    case 'LIVE_HOSTING_UNAVAILABLE':
      return { key: 'gateHostingOff' };
    case 'SERVICE_UNAVAILABLE':
      return { key: 'errBusy' };
    // v1.113-live (D351, CONVENTIONS §10.148): the capacity guard «حد الامتلاء».
    case 'LIVE_CAPACITY_FULL':
      return { key: 'errCapacityFull' };
    case 'VALIDATION_FAILED':
      return err.details.some((d) => d.issue === 'same_as_current') ? { key: 'errSamePassword' } : { key: 'errValidation' };
    case 'AUTH_FORBIDDEN':
      return { key: 'gateUnverified' };
    default:
      return { key: 'errGeneric' };
  }
}

/** D351: the server's default wait after LIVE_CAPACITY_FULL when `Retry-After` is missing (seconds). */
export const CAPACITY_FALLBACK_SECONDS = 60;

/**
 * D351: when «حاول مجددًا» may be pressed after a go-live refused with LIVE_CAPACITY_FULL (epoch ms: now + its
 * `Retry-After`, or 60 s without it); null for any other error.
 */
export function capacityRetryAt(err: unknown, nowMs: number): number | null {
  if (!(err instanceof ApiError) || err.code !== 'LIVE_CAPACITY_FULL') return null;
  const after = err.retryAfterSeconds;
  const seconds = after !== null && Number.isFinite(after) && after > 0 ? after : CAPACITY_FALLBACK_SECONDS;
  return nowMs + seconds * 1000;
}

/** D351: the whole seconds left until [untilMs] (0 once passed), shown as m:ss on the button. */
export function secondsLeft(untilMs: number, nowMs: number): number {
  return Math.max(0, Math.ceil((untilMs - nowMs) / 1000));
}
