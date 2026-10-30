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
    ErrorCode.liveHostingNotAllowed => l10n.errorLiveHostingNotAllowed,
    ErrorCode.liveGuestsNotAllowed => l10n.errorLiveGuestsNotAllowed,
    ErrorCode.liveChatNotInRoom => l10n.errorLiveChatNotInRoom,
    ErrorCode.liveChatMuted => l10n.errorLiveChatMuted,
    ErrorCode.liveChatClosed => l10n.errorLiveChatClosed,
    ErrorCode.mediaUploadsUnavailable => l10n.errorMediaUploadsUnavailable,
    ErrorCode.mediaInvalid => l10n.errorMediaInvalid,
    ErrorCode.pinLimitReached => l10n.errorPinLimitReached,
    ErrorCode.liveScheduleFull => l10n.errorLiveScheduleFull,
    ErrorCode.reportAlreadyResolved => l10n.errorReportAlreadyResolved,
    ErrorCode.insufficientCoins => l10n.errorInsufficientCoins,
    ErrorCode.liveKicked => l10n.errorLiveKicked,
    ErrorCode.alreadyInFamily => l10n.errorAlreadyInFamily,
    ErrorCode.familyFull => l10n.errorFamilyFull,
    ErrorCode.familyNameTaken => l10n.errorFamilyNameTaken,
    ErrorCode.familyRequestPending => l10n.errorFamilyRequestPending,
    ErrorCode.familyRequestNotPending => l10n.errorFamilyRequestNotPending,
    ErrorCode.familyNotEmpty => l10n.errorFamilyNotEmpty,
    ErrorCode.familyLeaderCannotLeave => l10n.errorFamilyLeaderCannotLeave,
    ErrorCode.cpAlreadyPaired => l10n.errorCpAlreadyPaired,
    ErrorCode.cpRequestPending => l10n.errorCpRequestPending,
    ErrorCode.cpRequestNotPending => l10n.errorCpRequestNotPending,
    ErrorCode.cpNotPaired => l10n.errorCpNotPaired,
    ErrorCode.medalNotUnlocked => l10n.errorMedalNotUnlocked,
    ErrorCode.bagItemNotOwned => l10n.errorBagItemNotOwned,
    ErrorCode.bagItemNotTransferable => l10n.errorBagItemNotTransferable,
    ErrorCode.bagSendPermanentWholeOnly => l10n.errorBagSendPermanentWholeOnly,
    ErrorCode.bagSendExceedsRemaining => l10n.errorBagSendExceedsRemaining,
    ErrorCode.bagRecipientHasPermanent => l10n.errorBagRecipientHasPermanent,
    ErrorCode.giftUnavailable => l10n.errorGiftUnavailable,
    ErrorCode.giftBagInsufficient => l10n.errorGiftBagInsufficient,
    ErrorCode.liveGiftRecipientUnavailable =>
      l10n.errorLiveGiftRecipientUnavailable,
    ErrorCode.luckyGiftAgeUnconfirmed => l10n.errorLuckyGiftAgeUnconfirmed,
    ErrorCode.luckyGiftRegionUnavailable =>
      l10n.errorLuckyGiftRegionUnavailable,
    ErrorCode.cpTaskNotCompleted => l10n.errorCpTaskNotCompleted,
    ErrorCode.cpPrivilegeLocked => l10n.errorCpPrivilegeLocked,
    ErrorCode.familyChatMuted => l10n.errorFamilyChatMuted,
    ErrorCode.premiumUsernameUnavailable =>
      l10n.errorPremiumUsernameUnavailable,
    ErrorCode.premiumUsernamePriceChanged =>
      l10n.errorPremiumUsernamePriceChanged,
    ErrorCode.premiumUsernameActive => l10n.errorPremiumUsernameActive,
    ErrorCode.dmNotAllowed => l10n.errorDmNotAllowed,
    ErrorCode.dmRequestLimit => l10n.errorDmRequestLimit,
    ErrorCode.dmRequestTextOnly => l10n.errorDmRequestTextOnly,
    ErrorCode.dmDeleteWindowPassed => l10n.errorDmDeleteWindowPassed,
    ErrorCode.quipFreeUsed => l10n.errorQuipFreeUsed,
    ErrorCode.quipQueueFull => l10n.errorQuipQueueFull,
    ErrorCode.boostQueueFull => l10n.errorBoostQueueFull,
    ErrorCode.boostCardInsufficient => l10n.errorBoostCardInsufficient,
    ErrorCode.boostRoomBusy => l10n.errorBoostRoomBusy,
    ErrorCode.youtubeVideoUnavailable => l10n.errorYoutubeVideoUnavailable,
    ErrorCode.youtubeSearchUnavailable => l10n.errorYoutubeSearchUnavailable,
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
