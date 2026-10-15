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
String failureMessage(AppLocalizations l10n, AppFailure failure) =>
    errorCodeMessage(l10n, failure.code);
