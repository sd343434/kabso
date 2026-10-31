import {
  BadRequestException,
  ForbiddenException,
  HttpException,
  NotFoundException,
  PayloadTooLargeException,
  UnauthorizedException,
} from '@nestjs/common';
import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { AppException } from './app-exception.js';
import { ERROR_HTTP_STATUS, ErrorCode } from './error-codes.js';
import { mapException, toEnvelope } from './error-mapping.js';

describe('ErrorCode', () => {
  it('matches CONVENTIONS §4 exactly', () => {
    expect(Object.values(ErrorCode).sort()).toEqual(
      [
        'VALIDATION_FAILED',
        'AUTH_UNAUTHENTICATED',
        'AUTH_INVALID_CREDENTIALS',
        'AUTH_REFRESH_INVALID',
        'AUTH_FORBIDDEN',
        'ACCOUNT_SUSPENDED',
        'NOT_FOUND',
        'EMAIL_TAKEN',
        'USERNAME_TAKEN',
        'IDEMPOTENCY_CONFLICT',
        'TOKEN_EXPIRED',
        'TOKEN_INVALID',
        'RATE_LIMITED',
        // v1.54-social (D185).
        'RECHARGE_APPLICATION_NOT_ALLOWED',
        'RECHARGE_AGENT_NOT_ACTIVE',
        'RECHARGE_OFF_SHIFT',
        'RECHARGE_STOCK_INSUFFICIENT',
        'RECHARGE_EMPLOYEE_NOT_ALLOWED',
        'RECHARGE_CHERRY_REQUEST_PENDING',
        'RECHARGE_CHERRY_REQUEST_CLOSED',
        'RECHARGE_CHERRY_CAP_REACHED',
        'USERNAME_LOCKED',
        // v1.55-social (D186).
        'HOST_FRAME_STYLE_FROM_GENDER',
        'INTERNAL_ERROR',
        'SERVICE_UNAVAILABLE',
        'LIVE_ROOM_ALREADY_ACTIVE',
        'LIVE_ROOM_ENDED',
        'LIVE_HOSTING_UNAVAILABLE',
        'LIVE_HOSTING_NOT_ALLOWED',
        'LIVE_GUESTS_NOT_ALLOWED',
        // v1.4-levels (DRAFT, CP-005)
        'LEVEL_CONFIG_INVALID',
        'LEVEL_VERSION_NOT_DRAFT',
        // v1.5-social (DRAFT, CP-006)
        'MEDIA_UPLOADS_UNAVAILABLE',
        'MEDIA_INVALID',
        'PIN_LIMIT_REACHED',
        'REPORT_ALREADY_RESOLVED',
        // v1.7-live (DRAFT, CP-011)
        'LIVE_SEAT_UNAVAILABLE',
        'LIVE_REQUEST_NOT_PENDING',
        // v1.9-live (DRAFT, CP-013)
        'LIVE_CHAT_NOT_IN_ROOM',
        'LIVE_CHAT_MUTED',
        'LIVE_CHAT_CLOSED',
        // v1.14-live (DRAFT, CP-016 C)
        'LIVE_SCHEDULE_FULL',
        // v1.19-live (DRAFT, CP-017)
        'INSUFFICIENT_COINS',
        // v1.20-live (DRAFT, D105)
        'LIVE_KICKED',
        // v1.21-live (DRAFT, CP-018)
        'ALREADY_IN_FAMILY',
        'FAMILY_FULL',
        'FAMILY_NAME_TAKEN',
        'FAMILY_REQUEST_PENDING',
        'FAMILY_REQUEST_NOT_PENDING',
        'FAMILY_NOT_EMPTY',
        'FAMILY_LEADER_CANNOT_LEAVE',
        'CP_ALREADY_PAIRED',
        'CP_REQUEST_PENDING',
        'CP_REQUEST_NOT_PENDING',
        'CP_NOT_PAIRED',
        'MEDAL_NOT_UNLOCKED',
        // v1.22-live (DRAFT, CP-019)
        'BAG_ITEM_NOT_OWNED',
        // v1.48-social (D171).
        'BAG_ITEM_NOT_TRANSFERABLE',
        'BAG_SEND_PERMANENT_WHOLE_ONLY',
        'BAG_SEND_EXCEEDS_REMAINING',
        'BAG_RECIPIENT_HAS_PERMANENT',
        // v1.23-live (DRAFT, CP-020)
        'GIFT_UNAVAILABLE',
        'GIFT_BAG_INSUFFICIENT',
        'LIVE_GIFT_RECIPIENT_UNAVAILABLE',
        // v1.24-live (DRAFT, CP-021)
        'CP_TASK_NOT_COMPLETED',
        'CP_PRIVILEGE_LOCKED',
        // v1.25-live (DRAFT, CP-022)
        'FAMILY_CHAT_MUTED',
        // v1.27-live (DRAFT, D132)
        'LUCKY_GIFT_AGE_UNCONFIRMED',
        'LUCKY_GIFT_REGION_UNAVAILABLE',
        'PREMIUM_USERNAME_UNAVAILABLE',
        'PREMIUM_USERNAME_PRICE_CHANGED',
        'PREMIUM_USERNAME_ACTIVE',
        // v1.40-social (DRAFT, D155)
        'DM_NOT_ALLOWED',
        'DM_REQUEST_LIMIT',
        'DM_REQUEST_TEXT_ONLY',
        'DM_DELETE_WINDOW_PASSED',
        // v1.32-live (DRAFT, D154)
        'QUIP_FREE_USED',
        'QUIP_QUEUE_FULL',
        // v1.33-live (DRAFT, D154b)
        'BOOST_QUEUE_FULL',
        'BOOST_CARD_INSUFFICIENT',
        'BOOST_ROOM_BUSY',
        'YOUTUBE_VIDEO_UNAVAILABLE',
        'YOUTUBE_SEARCH_UNAVAILABLE',
        // v1.44-social (DRAFT, D166)
        'TASK_NOT_COMPLETED',
        'TASK_DAILY_CAP_REACHED',
        // v1.47-social (DRAFT, D175)
        'FOLLOW_REQUEST_NOT_PENDING',
        // v1.52-social (DRAFT, D179)
        'AGENCY_ALREADY_MEMBER',
        'AGENCY_JOIN_NOT_ALLOWED',
        'AGENCY_LEAVE_WINDOW_CLOSED',
        'INSUFFICIENT_CHERRIES',
        'WITHDRAWAL_PENDING',
        // v1.57-social (DRAFT, D188)
        'TASK_MONTHLY_CAP_REACHED',
        // v1.60-social (D191).
        'ADMIN_PANEL_UNAVAILABLE',
        'ADMIN_LOCKED',
        'ADMIN_TOTP_INVALID',
        'ADMIN_CSRF_INVALID',
        'ADMIN_ACTION_REFUSED',
      ].sort(),
    );
    expect(ERROR_HTTP_STATUS).toMatchObject({
      VALIDATION_FAILED: 400,
      AUTH_UNAUTHENTICATED: 401,
      AUTH_INVALID_CREDENTIALS: 401,
      AUTH_REFRESH_INVALID: 401,
      AUTH_FORBIDDEN: 403,
      ACCOUNT_SUSPENDED: 403,
      NOT_FOUND: 404,
      EMAIL_TAKEN: 409,
      USERNAME_TAKEN: 409,
      IDEMPOTENCY_CONFLICT: 409,
      TOKEN_EXPIRED: 410,
      TOKEN_INVALID: 422,
      RATE_LIMITED: 429,
      INTERNAL_ERROR: 500,
      SERVICE_UNAVAILABLE: 503,
      LIVE_ROOM_ALREADY_ACTIVE: 409,
      LIVE_ROOM_ENDED: 409,
      LIVE_HOSTING_UNAVAILABLE: 503,
      LEVEL_CONFIG_INVALID: 422,
      LEVEL_VERSION_NOT_DRAFT: 409,
      MEDIA_UPLOADS_UNAVAILABLE: 503,
      MEDIA_INVALID: 422,
      PIN_LIMIT_REACHED: 409,
      REPORT_ALREADY_RESOLVED: 409,
      LIVE_SEAT_UNAVAILABLE: 409,
      LIVE_REQUEST_NOT_PENDING: 409,
      LIVE_CHAT_NOT_IN_ROOM: 403,
      LIVE_CHAT_MUTED: 403,
      LIVE_CHAT_CLOSED: 409,
      INSUFFICIENT_COINS: 409,
      LIVE_KICKED: 403,
      ALREADY_IN_FAMILY: 409,
      FAMILY_FULL: 409,
      FAMILY_NAME_TAKEN: 409,
      FAMILY_REQUEST_PENDING: 409,
      FAMILY_REQUEST_NOT_PENDING: 409,
      FAMILY_NOT_EMPTY: 409,
      FAMILY_LEADER_CANNOT_LEAVE: 409,
      CP_ALREADY_PAIRED: 409,
      CP_REQUEST_PENDING: 409,
      CP_REQUEST_NOT_PENDING: 409,
      CP_NOT_PAIRED: 409,
      MEDAL_NOT_UNLOCKED: 409,
      BAG_ITEM_NOT_OWNED: 409,
      GIFT_UNAVAILABLE: 409,
      GIFT_BAG_INSUFFICIENT: 409,
      LIVE_GIFT_RECIPIENT_UNAVAILABLE: 409,
      CP_TASK_NOT_COMPLETED: 409,
      CP_PRIVILEGE_LOCKED: 403,
      FAMILY_CHAT_MUTED: 403,
      LUCKY_GIFT_AGE_UNCONFIRMED: 403,
      LUCKY_GIFT_REGION_UNAVAILABLE: 403,
      PREMIUM_USERNAME_UNAVAILABLE: 409,
      PREMIUM_USERNAME_PRICE_CHANGED: 409,
      PREMIUM_USERNAME_ACTIVE: 409,
      DM_NOT_ALLOWED: 403,
      DM_REQUEST_LIMIT: 403,
      DM_REQUEST_TEXT_ONLY: 403,
      DM_DELETE_WINDOW_PASSED: 409,
      QUIP_FREE_USED: 409,
      QUIP_QUEUE_FULL: 409,
      BOOST_QUEUE_FULL: 409,
      BOOST_CARD_INSUFFICIENT: 409,
      BOOST_ROOM_BUSY: 409,
      YOUTUBE_VIDEO_UNAVAILABLE: 422,
      YOUTUBE_SEARCH_UNAVAILABLE: 503,
      TASK_NOT_COMPLETED: 409,
      TASK_DAILY_CAP_REACHED: 409,
      FOLLOW_REQUEST_NOT_PENDING: 409,
      AGENCY_ALREADY_MEMBER: 409,
      AGENCY_JOIN_NOT_ALLOWED: 409,
      AGENCY_LEAVE_WINDOW_CLOSED: 409,
      INSUFFICIENT_CHERRIES: 409,
      WITHDRAWAL_PENDING: 409,
      TASK_MONTHLY_CAP_REACHED: 409,
      ADMIN_PANEL_UNAVAILABLE: 503,
      ADMIN_LOCKED: 429,
      ADMIN_TOTP_INVALID: 403,
      ADMIN_CSRF_INVALID: 403,
      ADMIN_ACTION_REFUSED: 409,
    });
  });

  it('matches the code table in docs/contracts/CONVENTIONS.md §4 (codes and HTTP statuses)', () => {
    const conventions = readFileSync(
      fileURLToPath(new URL('../../../../../docs/contracts/CONVENTIONS.md', import.meta.url)),
      'utf8',
    );
    const table = Object.fromEntries(
      [...conventions.matchAll(/^\| (\d{3}) \| `([A-Z_]+)` \|/gm)].map((m) => [m[2], Number(m[1])]),
    );
    expect(Object.keys(table).length).toBeGreaterThanOrEqual(18);
    expect({ ...ERROR_HTTP_STATUS }).toEqual(table);
  });
});

describe('mapException', () => {
  it('passes AppException through with details and headers', () => {
    const mapped = mapException(
      new AppException(ErrorCode.RATE_LIMITED, undefined, undefined, { 'Retry-After': '30' }),
    );
    expect(mapped).toMatchObject({
      status: 429,
      code: 'RATE_LIMITED',
      headers: { 'Retry-After': '30' },
      unexpected: false,
    });

    const validation = mapException(AppException.validation([{ field: 'email', issue: 'required' }]));
    expect(validation.status).toBe(400);
    expect(validation.details).toEqual([{ field: 'email', issue: 'required' }]);
  });

  it.each([
    [new NotFoundException(), 404, 'NOT_FOUND'],
    [new UnauthorizedException(), 401, 'AUTH_UNAUTHENTICATED'],
    [new ForbiddenException(), 403, 'AUTH_FORBIDDEN'],
    [new BadRequestException('internal detail'), 400, 'VALIDATION_FAILED'],
    [new PayloadTooLargeException(), 400, 'VALIDATION_FAILED'],
    [new HttpException('x', 503), 503, 'SERVICE_UNAVAILABLE'],
    [new HttpException('x', 502), 500, 'INTERNAL_ERROR'],
  ])('maps Nest HttpException %#', (exception, status, code) => {
    const mapped = mapException(exception);
    expect(mapped.status).toBe(status);
    expect(mapped.code).toBe(code);
    expect(mapped.message).not.toContain('internal detail');
  });

  it('maps body-parser errors to VALIDATION_FAILED with an issue', () => {
    const parseError = Object.assign(new SyntaxError('Unexpected token'), {
      type: 'entity.parse.failed',
      status: 400,
    });
    expect(mapException(parseError)).toMatchObject({
      status: 400,
      code: 'VALIDATION_FAILED',
      details: [{ field: '', issue: 'malformed_json' }],
    });
    const tooLarge = Object.assign(new Error('too large'), { type: 'entity.too.large', status: 413 });
    expect(mapException(tooLarge).details).toEqual([{ field: '', issue: 'payload_too_large' }]);
  });

  it('hides unexpected errors behind INTERNAL_ERROR', () => {
    const mapped = mapException(new Error('relation "users" does not exist at SELECT ...'));
    expect(mapped).toMatchObject({ status: 500, code: 'INTERNAL_ERROR', unexpected: true });
    expect(mapped.message).toBe('Internal server error.');
    expect(mapException('a string').code).toBe('INTERNAL_ERROR');
  });
});

describe('toEnvelope', () => {
  it('builds the contract envelope and omits empty details', () => {
    expect(toEnvelope(mapException(new AppException(ErrorCode.NOT_FOUND)), 'rid-1')).toEqual({
      error: { code: 'NOT_FOUND', message: 'Resource not found.', requestId: 'rid-1' },
    });
    expect(
      toEnvelope(mapException(AppException.validation([{ field: 'a', issue: 'required' }])), 'rid-2').error
        .details,
    ).toEqual([{ field: 'a', issue: 'required' }]);
  });
});
