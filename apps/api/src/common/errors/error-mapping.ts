import { HttpException } from '@nestjs/common';
import { AppException } from './app-exception.js';
import {
  DEFAULT_ERROR_MESSAGE,
  ERROR_HTTP_STATUS,
  ErrorCode,
  type ErrorDetail,
  type ErrorEnvelope,
} from './error-codes.js';

export interface MappedError {
  readonly status: number;
  readonly code: ErrorCode;
  readonly message: string;
  readonly details?: readonly ErrorDetail[];
  readonly headers?: Readonly<Record<string, string>>;
  /** True when the failure is unexpected and must be logged with its stack. */
  readonly unexpected: boolean;
}

/** Shape of errors raised by Express' body-parser (`http-errors`). */
interface BodyParserError {
  readonly type: string;
  readonly status: number;
}

function isBodyParserError(e: unknown): e is BodyParserError {
  return (
    typeof e === 'object' &&
    e !== null &&
    typeof (e as { type?: unknown }).type === 'string' &&
    typeof (e as { status?: unknown }).status === 'number'
  );
}

const BODY_PARSER_ISSUES: Readonly<Record<string, string>> = {
  'entity.parse.failed': 'malformed_json',
  'entity.too.large': 'payload_too_large',
  'encoding.unsupported': 'unsupported_encoding',
  'charset.unsupported': 'unsupported_charset',
  'request.aborted': 'request_aborted',
  'request.size.invalid': 'invalid_size',
  'entity.verify.failed': 'invalid_body',
  'stream.encoding.set': 'invalid_body',
  'stream.not.readable': 'invalid_body',
  'parameters.too.many': 'invalid_body',
};

function fromCode(code: ErrorCode, extra: Partial<MappedError> = {}): MappedError {
  return {
    status: ERROR_HTTP_STATUS[code],
    code,
    message: DEFAULT_ERROR_MESSAGE[code],
    unexpected: false,
    ...extra,
  };
}

/**
 * Maps any thrown value to the contract error (CONVENTIONS §4). Never exposes internal messages
 * of unexpected errors (stack traces, SQL, driver errors).
 */
export function mapException(exception: unknown): MappedError {
  if (exception instanceof AppException) {
    return {
      status: exception.status,
      code: exception.code,
      message: exception.message,
      ...(exception.details ? { details: exception.details } : {}),
      ...(exception.headers ? { headers: exception.headers } : {}),
      unexpected: false,
    };
  }

  if (exception instanceof HttpException) {
    const status = exception.getStatus();
    switch (status) {
      case 400:
      case 413:
      case 415:
        return fromCode(ErrorCode.VALIDATION_FAILED);
      case 401:
        return fromCode(ErrorCode.AUTH_UNAUTHENTICATED);
      case 403:
        return fromCode(ErrorCode.AUTH_FORBIDDEN);
      case 404:
      case 405:
        return fromCode(ErrorCode.NOT_FOUND);
      case 429:
        return fromCode(ErrorCode.RATE_LIMITED);
      case 503:
        return fromCode(ErrorCode.SERVICE_UNAVAILABLE);
      default:
        return status >= 500
          ? fromCode(ErrorCode.INTERNAL_ERROR, { unexpected: true })
          : fromCode(ErrorCode.VALIDATION_FAILED);
    }
  }

  if (isBodyParserError(exception) && exception.status >= 400 && exception.status < 500) {
    // The contract has no 413/415 codes: body problems are reported as VALIDATION_FAILED (400).
    return fromCode(ErrorCode.VALIDATION_FAILED, {
      message: 'Request body could not be parsed.',
      details: [{ field: '', issue: BODY_PARSER_ISSUES[exception.type] ?? 'invalid_body' }],
    });
  }

  return fromCode(ErrorCode.INTERNAL_ERROR, { unexpected: true });
}

export function toEnvelope(mapped: MappedError, requestId: string): ErrorEnvelope {
  return {
    error: {
      code: mapped.code,
      message: mapped.message,
      ...(mapped.details && mapped.details.length > 0 ? { details: [...mapped.details] } : {}),
      requestId,
    },
  };
}
