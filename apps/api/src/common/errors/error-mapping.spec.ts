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
