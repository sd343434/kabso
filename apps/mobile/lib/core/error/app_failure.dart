import 'package:flutter/foundation.dart' show immutable;

/// Stable error codes from `docs/contracts/CONVENTIONS.md` §4, plus the
/// client-only network codes and a fallback for codes this build does not
/// know yet.
enum ErrorCode {
  validationFailed('VALIDATION_FAILED'),
  authUnauthenticated('AUTH_UNAUTHENTICATED'),
  authInvalidCredentials('AUTH_INVALID_CREDENTIALS'),
  authRefreshInvalid('AUTH_REFRESH_INVALID'),
  authForbidden('AUTH_FORBIDDEN'),
  accountSuspended('ACCOUNT_SUSPENDED'),
  notFound('NOT_FOUND'),
  emailTaken('EMAIL_TAKEN'),
  usernameTaken('USERNAME_TAKEN'),
  idempotencyConflict('IDEMPOTENCY_CONFLICT'),
  tokenExpired('TOKEN_EXPIRED'),
  tokenInvalid('TOKEN_INVALID'),
  rateLimited('RATE_LIMITED'),
  internalError('INTERNAL_ERROR'),
  serviceUnavailable('SERVICE_UNAVAILABLE'),

  /// v1.3: going live / heartbeat refused because hosting is switched off by
  /// server config (503, not transient, no `Retry-After`).
  liveHostingUnavailable('LIVE_HOSTING_UNAVAILABLE'),

  /// v1.3: go-live refused, the caller already has a LIVE room (409).
  liveRoomAlreadyActive('LIVE_ROOM_ALREADY_ACTIVE'),

  /// v1.3: heartbeat for a room that is no longer LIVE (409).
  liveRoomEnded('LIVE_ROOM_ENDED'),

  /// Client-only: no connection could be established.
  networkOffline('NETWORK_OFFLINE'),

  /// Client-only: the request timed out.
  networkTimeout('NETWORK_TIMEOUT'),

  /// Any code not listed above (newer server, malformed response, ...).
  unknown('UNKNOWN');

  new(this.wire);

  /// The exact string used on the wire.
  final String wire;

  /// Codes that are sent by the server (everything except client-only ones).
  static List<ErrorCode> get serverCodes => values
      .where(
        (c) =>
            c != ErrorCode.networkOffline &&
            c != ErrorCode.networkTimeout &&
            c != ErrorCode.unknown,
      )
      .toList(growable: false);

  static ErrorCode fromWire(String? code) {
    if (code == null) return ErrorCode.unknown;
    for (final value in values) {
      if (value.wire == code) return value;
    }
    return ErrorCode.unknown;
  }
}

/// One `{ field, issue }` entry of a validation error.
@immutable
class FieldIssue {
  const new({required this.field, required this.issue});

  final String field;
  final String issue;

  @override
  bool operator ==(Object other) =>
      other is FieldIssue && other.field == field && other.issue == issue;

  @override
  int get hashCode => Object.hash(field, issue);

  @override
  String toString() => 'FieldIssue($field: $issue)';
}

/// Every failure surfaced to the domain and presentation layers.
///
/// Branch on [code]; never show [debugMessage] to users (it is English
/// developer text). Use `failureMessage` from `failure_messages.dart` instead.
sealed class AppFailure implements Exception {
  const new();

  ErrorCode get code;

  String get debugMessage;

  @override
  String toString() => 'AppFailure(${code.wire}): $debugMessage';
}

/// The server answered with the error envelope (or an unparseable error).
final class ServerFailure extends AppFailure {
  const new({
    required this.code,
    required this.rawCode,
    required this.debugMessage,
    this.statusCode,
    this.details = const [],
    this.requestId,
    this.retryAfter,
  });

  @override
  final ErrorCode code;

  /// The code exactly as sent (useful when [code] is [ErrorCode.unknown]).
  final String rawCode;

  @override
  final String debugMessage;

  final int? statusCode;
  final List<FieldIssue> details;
  final String? requestId;

  /// Parsed from the `Retry-After` header on `RATE_LIMITED`.
  final Duration? retryAfter;
}

/// Client-only transport failure (`NETWORK_OFFLINE` / `NETWORK_TIMEOUT`).
final class NetworkFailure extends AppFailure {
  const new _(this.code, this.debugMessage);

  const new offline([String message = 'No connection'])
    : this._(ErrorCode.networkOffline, message);

  const new timeout([String message = 'Request timed out'])
    : this._(ErrorCode.networkTimeout, message);

  @override
  final ErrorCode code;

  @override
  final String debugMessage;
}

/// Anything else (cancelled request, unexpected exception, bad payload).
final class UnexpectedFailure extends AppFailure {
  const new([this.debugMessage = 'Unexpected error']);

  @override
  ErrorCode get code => ErrorCode.unknown;

  @override
  final String debugMessage;
}
