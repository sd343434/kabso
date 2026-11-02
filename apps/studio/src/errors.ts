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
    case 'VALIDATION_FAILED':
      return err.details.some((d) => d.issue === 'same_as_current') ? { key: 'errSamePassword' } : { key: 'errValidation' };
    case 'AUTH_FORBIDDEN':
      return { key: 'gateUnverified' };
    default:
      return { key: 'errGeneric' };
  }
}
