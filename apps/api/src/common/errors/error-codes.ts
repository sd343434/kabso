/**
 * Stable error codes — CONVENTIONS.md §4. Adding a code is a contract change.
 * `NETWORK_OFFLINE` / `NETWORK_TIMEOUT` are client-only and intentionally absent.
 */
export enum ErrorCode {
  VALIDATION_FAILED = 'VALIDATION_FAILED',
  AUTH_UNAUTHENTICATED = 'AUTH_UNAUTHENTICATED',
  AUTH_INVALID_CREDENTIALS = 'AUTH_INVALID_CREDENTIALS',
  AUTH_REFRESH_INVALID = 'AUTH_REFRESH_INVALID',
  AUTH_FORBIDDEN = 'AUTH_FORBIDDEN',
  ACCOUNT_SUSPENDED = 'ACCOUNT_SUSPENDED',
  NOT_FOUND = 'NOT_FOUND',
  EMAIL_TAKEN = 'EMAIL_TAKEN',
  USERNAME_TAKEN = 'USERNAME_TAKEN',
  IDEMPOTENCY_CONFLICT = 'IDEMPOTENCY_CONFLICT',
  /** v1.3: go-live refused, the caller already has a LIVE room with a fresh heartbeat. */
  LIVE_ROOM_ALREADY_ACTIVE = 'LIVE_ROOM_ALREADY_ACTIVE',
  /** v1.3: heartbeat for a room that is no longer LIVE. */
  LIVE_ROOM_ENDED = 'LIVE_ROOM_ENDED',
  TOKEN_EXPIRED = 'TOKEN_EXPIRED',
  TOKEN_INVALID = 'TOKEN_INVALID',
  RATE_LIMITED = 'RATE_LIMITED',
  INTERNAL_ERROR = 'INTERNAL_ERROR',
  SERVICE_UNAVAILABLE = 'SERVICE_UNAVAILABLE',
  /** v1.3: going live / heartbeating disabled by LIVE_HOSTING_ENABLED=false (no Retry-After). */
  LIVE_HOSTING_UNAVAILABLE = 'LIVE_HOSTING_UNAVAILABLE',
  /** CP-010: going live needs the hosting permission. */
  LIVE_HOSTING_NOT_ALLOWED = 'LIVE_HOSTING_NOT_ALLOWED',
  /** CP-010: the host switched guests off. */
  LIVE_GUESTS_NOT_ALLOWED = 'LIVE_GUESTS_NOT_ALLOWED',
  /** v1.4-levels (DRAFT, CP-005): a level configuration breaks the publication rules. */
  LEVEL_CONFIG_INVALID = 'LEVEL_CONFIG_INVALID',
  /** v1.4-levels (DRAFT, CP-005): only DRAFT versions change. */
  LEVEL_VERSION_NOT_DRAFT = 'LEVEL_VERSION_NOT_DRAFT',
  /** v1.5-social (DRAFT, CP-006): uploads disabled by MEDIA_UPLOADS_ENABLED=false (no Retry-After). */
  MEDIA_UPLOADS_UNAVAILABLE = 'MEDIA_UPLOADS_UNAVAILABLE',
  /** v1.5-social (DRAFT): the uploaded object is missing, mismatched or not a valid image. */
  MEDIA_INVALID = 'MEDIA_INVALID',
  /** v1.5-social (DRAFT): the caller already has 3 pinned posts. */
  PIN_LIMIT_REACHED = 'PIN_LIMIT_REACHED',
  /** v1.5-social (DRAFT): an admin acted on a report that is no longer OPEN. */
  REPORT_ALREADY_RESOLVED = 'REPORT_ALREADY_RESOLVED',
}

/** HTTP status for every code (CONVENTIONS.md §4 table). */
export const ERROR_HTTP_STATUS: Readonly<Record<ErrorCode, number>> = {
  [ErrorCode.VALIDATION_FAILED]: 400,
  [ErrorCode.AUTH_UNAUTHENTICATED]: 401,
  [ErrorCode.AUTH_INVALID_CREDENTIALS]: 401,
  [ErrorCode.AUTH_REFRESH_INVALID]: 401,
  [ErrorCode.AUTH_FORBIDDEN]: 403,
  [ErrorCode.ACCOUNT_SUSPENDED]: 403,
  [ErrorCode.NOT_FOUND]: 404,
  [ErrorCode.EMAIL_TAKEN]: 409,
  [ErrorCode.USERNAME_TAKEN]: 409,
  [ErrorCode.IDEMPOTENCY_CONFLICT]: 409,
  [ErrorCode.LIVE_ROOM_ALREADY_ACTIVE]: 409,
  [ErrorCode.LIVE_ROOM_ENDED]: 409,
  [ErrorCode.TOKEN_EXPIRED]: 410,
  [ErrorCode.TOKEN_INVALID]: 422,
  [ErrorCode.RATE_LIMITED]: 429,
  [ErrorCode.INTERNAL_ERROR]: 500,
  [ErrorCode.SERVICE_UNAVAILABLE]: 503,
  [ErrorCode.LIVE_HOSTING_UNAVAILABLE]: 503,
  [ErrorCode.LIVE_HOSTING_NOT_ALLOWED]: 403,
  [ErrorCode.LIVE_GUESTS_NOT_ALLOWED]: 403,
  [ErrorCode.LEVEL_CONFIG_INVALID]: 422,
  [ErrorCode.LEVEL_VERSION_NOT_DRAFT]: 409,
  [ErrorCode.MEDIA_UPLOADS_UNAVAILABLE]: 503,
  [ErrorCode.MEDIA_INVALID]: 422,
  [ErrorCode.PIN_LIMIT_REACHED]: 409,
  [ErrorCode.REPORT_ALREADY_RESOLVED]: 409,
};

/** Default developer-facing messages (clients localize by `code`, not by message). */
export const DEFAULT_ERROR_MESSAGE: Readonly<Record<ErrorCode, string>> = {
  [ErrorCode.VALIDATION_FAILED]: 'Request validation failed.',
  [ErrorCode.AUTH_UNAUTHENTICATED]: 'Authentication required.',
  [ErrorCode.AUTH_INVALID_CREDENTIALS]: 'Invalid email/username or password.',
  [ErrorCode.AUTH_REFRESH_INVALID]: 'Refresh token is invalid.',
  [ErrorCode.AUTH_FORBIDDEN]: 'Not allowed.',
  [ErrorCode.ACCOUNT_SUSPENDED]: 'Account is suspended.',
  [ErrorCode.NOT_FOUND]: 'Resource not found.',
  [ErrorCode.EMAIL_TAKEN]: 'Email is already in use.',
  [ErrorCode.USERNAME_TAKEN]: 'Username is already in use.',
  [ErrorCode.IDEMPOTENCY_CONFLICT]: 'Idempotency key reused with a different payload.',
  [ErrorCode.LIVE_ROOM_ALREADY_ACTIVE]: 'You already have a live room.',
  [ErrorCode.LIVE_ROOM_ENDED]: 'The live room has ended.',
  [ErrorCode.TOKEN_EXPIRED]: 'Token has expired or was already used.',
  [ErrorCode.TOKEN_INVALID]: 'Token is invalid.',
  [ErrorCode.RATE_LIMITED]: 'Too many requests.',
  [ErrorCode.INTERNAL_ERROR]: 'Internal server error.',
  [ErrorCode.SERVICE_UNAVAILABLE]: 'Service temporarily unavailable.',
  [ErrorCode.LIVE_HOSTING_UNAVAILABLE]: 'Going live is not available.',
  [ErrorCode.LIVE_HOSTING_NOT_ALLOWED]: 'Your account cannot go live yet.',
  [ErrorCode.LIVE_GUESTS_NOT_ALLOWED]: 'Sign in to watch this live.',
  [ErrorCode.LEVEL_CONFIG_INVALID]: 'The level configuration is invalid.',
  [ErrorCode.LEVEL_VERSION_NOT_DRAFT]: 'Only draft versions can change.',
  [ErrorCode.MEDIA_UPLOADS_UNAVAILABLE]: 'Uploading is not available.',
  [ErrorCode.MEDIA_INVALID]: 'The uploaded file is not a valid image.',
  [ErrorCode.PIN_LIMIT_REACHED]: 'You can pin up to 3 posts.',
  [ErrorCode.REPORT_ALREADY_RESOLVED]: 'The report was already resolved.',
};

export interface ErrorDetail {
  readonly field: string;
  readonly issue: string;
}

export interface ErrorEnvelope {
  error: {
    code: ErrorCode;
    message: string;
    details?: ErrorDetail[];
    requestId: string;
  };
}
