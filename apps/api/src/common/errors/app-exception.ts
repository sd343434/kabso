import { DEFAULT_ERROR_MESSAGE, ERROR_HTTP_STATUS, ErrorCode, type ErrorDetail } from './error-codes.js';

/** The only exception type application code should throw for expected failures. */
export class AppException extends Error {
  readonly status: number;

  constructor(
    readonly code: ErrorCode,
    message?: string,
    readonly details?: readonly ErrorDetail[],
    readonly headers?: Readonly<Record<string, string>>,
  ) {
    super(message ?? DEFAULT_ERROR_MESSAGE[code]);
    this.name = 'AppException';
    this.status = ERROR_HTTP_STATUS[code];
  }

  static validation(details: readonly ErrorDetail[], message?: string): AppException {
    return new AppException(ErrorCode.VALIDATION_FAILED, message, details);
  }
}
