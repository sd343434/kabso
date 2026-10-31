import { ApiError } from './api';
import type { Key } from './i18n';

/** The message key (and variables) for an API error, in the panel's words. */
export function errorKey(err: unknown): { key: Key; vars?: Record<string, number> } {
  if (!(err instanceof ApiError)) return { key: 'errGeneric' };
  switch (err.code) {
    case 'NETWORK':
      return { key: 'errNetwork' };
    case 'AUTH_UNAUTHENTICATED':
      return { key: 'errSession' };
    case 'AUTH_FORBIDDEN':
      return { key: 'errForbidden' };
    case 'AUTH_INVALID_CREDENTIALS':
      return { key: 'errCredentials' };
    case 'ADMIN_LOCKED':
      return { key: 'errLocked', vars: { minutes: Math.max(1, Math.ceil((err.retryAfterSeconds ?? 60) / 60)) } };
    case 'ADMIN_TOTP_INVALID':
      return { key: 'errTotp' };
    case 'ADMIN_CSRF_INVALID':
      return { key: 'errCsrf' };
    case 'ADMIN_PANEL_UNAVAILABLE':
      return { key: 'errUnavailable' };
    case 'VALIDATION_FAILED':
      return { key: 'errValidation' };
    case 'NOT_FOUND':
      return { key: 'errNotFound' };
    case 'RATE_LIMITED':
      return { key: 'errRateLimited' };
    default:
      return { key: 'errGeneric' };
  }
}

/** The server's own sentence for a refused admin rule (ADMIN_ACTION_REFUSED, REPORT_ALREADY_RESOLVED …). */
export function serverMessage(err: unknown): string | null {
  if (err instanceof ApiError && (err.code === 'ADMIN_ACTION_REFUSED' || err.code === 'REPORT_ALREADY_RESOLVED')) {
    return err.message;
  }
  return null;
}
