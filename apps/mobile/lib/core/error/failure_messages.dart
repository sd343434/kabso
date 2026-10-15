import 'package:kabso_live/core/error/app_failure.dart';
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
    ErrorCode.emailTaken => l10n.errorEmailTaken,
    ErrorCode.usernameTaken => l10n.errorUsernameTaken,
    ErrorCode.idempotencyConflict => l10n.errorIdempotencyConflict,
    ErrorCode.tokenExpired => l10n.errorTokenExpired,
    ErrorCode.tokenInvalid => l10n.errorTokenInvalid,
    ErrorCode.rateLimited => l10n.errorRateLimited,
    ErrorCode.internalError => l10n.errorInternal,
    ErrorCode.serviceUnavailable => l10n.errorServiceUnavailable,
    ErrorCode.networkOffline => l10n.errorNetworkOffline,
    ErrorCode.networkTimeout => l10n.errorNetworkTimeout,
    ErrorCode.unknown => l10n.errorUnknown,
  };
}

/// Localized, user-facing message for [failure].
///
/// For `RATE_LIMITED` and `SERVICE_UNAVAILABLE` (e.g. login/register under
/// load, CONVENTIONS v1.1) the server's `Retry-After` is shown when present.
String failureMessage(AppLocalizations l10n, AppFailure failure) {
  if (failure is ServerFailure) {
    final retryAfter = failure.retryAfter;
    if (retryAfter != null && retryAfter > Duration.zero) {
      final wait = retryWaitText(l10n, retryAfter);
      switch (failure.code) {
        case ErrorCode.rateLimited:
          return l10n.errorRateLimitedRetryIn(wait);
        case ErrorCode.serviceUnavailable:
          return l10n.errorServiceBusyRetryIn(wait);
        // Other codes ignore Retry-After.
        // ignore: no_default_cases
        default:
          break;
      }
    }
  }
  return errorCodeMessage(l10n, failure.code);
}

/// "5 seconds" / "2 minutes" (minutes rounded up from 60 s on).
String retryWaitText(AppLocalizations l10n, Duration wait) {
  final seconds = wait.inSeconds < 1 ? 1 : wait.inSeconds;
  if (seconds < 60) return l10n.durationSeconds(seconds);
  return l10n.durationMinutes((seconds / 60).ceil());
}
