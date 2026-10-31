import { ApiError } from './api';
import type { Key } from './i18n';

/** The message key (and variables) for an API error, in the panel's words. */
/** D196: the payment-settings refusals the panel words itself (ADMIN_ACTION_REFUSED `details[0].issue`). */
const REFUSAL_KEYS: Record<string, Key> = {
  stripe_rejected: 'payErrRejected',
  test_key_in_production: 'payErrTestInProd',
  connection_test_required: 'payErrTestRequired',
  mode_mismatch: 'payErrModeMismatch',
  nothing_to_clear: 'payErrNothingToClear',
  stripe_keys_missing: 'payErrKeysMissing',
};

function refusalKey(err: ApiError): Key | null {
  if (err.code !== 'ADMIN_ACTION_REFUSED') return null;
  return REFUSAL_KEYS[err.details[0]?.issue ?? ''] ?? null;
}

export function errorKey(err: unknown): { key: Key; vars?: Record<string, number> } {
  if (!(err instanceof ApiError)) return { key: 'errGeneric' };
  const refusal = refusalKey(err);
  if (refusal) return { key: refusal };
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
    case 'SERVICE_UNAVAILABLE':
      return { key: 'payErrUnreachable' };
    default:
      return { key: 'errGeneric' };
  }
}

/** The server's own sentence for a refused admin rule (ADMIN_ACTION_REFUSED, REPORT_ALREADY_RESOLVED …). */
export function serverMessage(err: unknown): string | null {
  if (err instanceof ApiError && refusalKey(err)) return null;
  if (err instanceof ApiError && (err.code === 'ADMIN_ACTION_REFUSED' || err.code === 'REPORT_ALREADY_RESOLVED')) {
    return err.message;
  }
  return null;
}
