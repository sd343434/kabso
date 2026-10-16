import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/l10n/l10n.dart';

/// Localized, user-facing message for an error [code].
///
/// The switch is exhaustive: adding a code to [ErrorCode] without a message
/// is a compile error.
String errorCodeMessage(AppLocalizations l10n, ErrorCode code) {
  return switch (code) {
    ErrorCode.validationFailed => l10n.errorValidationFailed,
    ErrorCode.authUnauthenticated => l10n.errorAuthUnauthenticated,
    ErrorCode.authInvalidCredentials => l10n.errorAuthInvalidCredentials,
    ErrorCode.authRefreshInvalid => l10n.errorAuthRefreshInvalid,
    ErrorCode.authForbidden => l10n.errorAuthForbidden,
    ErrorCode.accountSuspended => l10n.errorAccountSuspended,
    ErrorCode.notFound => l10n.errorNotFound,
    // v1.2 (D24): registration never reveals email use. If an old server
    // still sends EMAIL_TAKEN, show the generic message.
    ErrorCode.emailTaken => l10n.errorUnknown,
    ErrorCode.usernameTaken => l10n.errorUsernameTaken,
    ErrorCode.idempotencyConflict => l10n.errorIdempotencyConflict,
    ErrorCode.tokenExpired => l10n.errorTokenExpired,
    ErrorCode.tokenInvalid => l10n.errorTokenInvalid,
    ErrorCode.rateLimited => l10n.errorRateLimited,
    ErrorCode.internalError => l10n.errorInternal,
    ErrorCode.serviceUnavailable => l10n.errorServiceUnavailable,
    ErrorCode.liveHostingUnavailable => l10n.errorLiveHostingUnavailable,
    ErrorCode.liveRoomAlreadyActive => l10n.errorLiveRoomAlreadyActive,
    ErrorCode.liveRoomEnded => l10n.errorLiveRoomEnded,
    ErrorCode.networkOffline => l10n.errorNetworkOffline,
    ErrorCode.networkTimeout => l10n.errorNetworkTimeout,
    ErrorCode.unknown => l10n.errorUnknown,
  };
}

/// Codes that honour `Retry-After` (countdown + disabled CTA).
bool hasRetryCountdown(AppFailure failure) =>
    failure is ServerFailure &&
    (failure.code == ErrorCode.rateLimited ||
        failure.code == ErrorCode.serviceUnavailable) &&
    (failure.retryAfter ?? Duration.zero) > Duration.zero;

/// Localized, user-facing message for [failure].
///
/// For `RATE_LIMITED` and `SERVICE_UNAVAILABLE` with `Retry-After`
/// (PHASE1_SCREENS §10, CONVENTIONS v1.1) the wait is shown as `m:ss`:
/// [remaining] is the live countdown value; without it the full
/// `Retry-After` is shown. Once the countdown reaches zero the plain message
/// is used.
String failureMessage(
  AppLocalizations l10n,
  AppFailure failure, {
  Duration? remaining,
}) {
  if (failure is ServerFailure && hasRetryCountdown(failure)) {
    final left = remaining ?? failure.retryAfter!;
    if (left > Duration.zero) {
      final wait = KFormat.countdown(_roundUpToSecond(left));
      return failure.code == ErrorCode.rateLimited
          ? l10n.errorRateLimitedRetryIn(wait)
          : l10n.errorServiceBusyRetryIn(wait);
    }
  }
  return errorCodeMessage(l10n, failure.code);
}

/// The request id to show as a selectable "Error ID" (PHASE1_SCREENS §10):
/// only for `INTERNAL_ERROR`, `SERVICE_UNAVAILABLE` and unknown codes.
String? failureErrorId(AppFailure failure) {
  if (failure is! ServerFailure) return null;
  final id = failure.requestId;
  if (id == null || id.isEmpty) return null;
  return switch (failure.code) {
    ErrorCode.internalError ||
    ErrorCode.serviceUnavailable ||
    ErrorCode.unknown => id,
    _ => null,
  };
}

Duration _roundUpToSecond(Duration d) {
  final ms = d.inMilliseconds;
  return Duration(seconds: (ms + 999) ~/ 1000);
}
