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

  /// CP-010: going live needs the hosting permission (`Me.canHost`, 403).
  liveHostingNotAllowed('LIVE_HOSTING_NOT_ALLOWED'),

  /// CP-010: the host does not let people without an account watch (403).
  liveGuestsNotAllowed('LIVE_GUESTS_NOT_ALLOWED'),

  /// CP-013: a chat message from someone not in the room now (403).
  liveChatNotInRoom('LIVE_CHAT_NOT_IN_ROOM'),

  /// CP-013: the caller is muted in this live's chat (403).
  liveChatMuted('LIVE_CHAT_MUTED'),

  /// CP-013: the host turned the chat off (409).
  liveChatClosed('LIVE_CHAT_CLOSED'),

  /// v1.5-social: photo uploads are switched off by server config (503, not
  /// transient, no `Retry-After`).
  mediaUploadsUnavailable('MEDIA_UPLOADS_UNAVAILABLE'),

  /// v1.5-social: the uploaded photo is missing, mismatched or not a
  /// decodable image within the limits (422).
  mediaInvalid('MEDIA_INVALID'),

  /// v1.5-social: already 3 pinned posts (409).
  pinLimitReached('PIN_LIMIT_REACHED'),

  /// v1.5-social: an admin acted on a report that is no longer open (409).
  reportAlreadyResolved('REPORT_ALREADY_RESOLVED'),

  /// v1.14-live (CP-016 C): already 10 upcoming scheduled lives (409).
  liveScheduleFull('LIVE_SCHEDULE_FULL'),

  /// CP-017: the coin balance does not cover the price (a bullet costs 15
  /// coins; 409, nothing charged).
  insufficientCoins('INSUFFICIENT_COINS'),

  /// v1.20-live (D105): the host or a moderator kicked the caller out of
  /// this live (403); the app leaves the room and says so.
  liveKicked('LIVE_KICKED'),

  /// v1.21-live (CP-018, §10.21, 409): the caller already belongs to a family.
  alreadyInFamily('ALREADY_IN_FAMILY'),

  /// v1.21-live (CP-018, §10.21, 409): the family has 500 members.
  familyFull('FAMILY_FULL'),

  /// v1.21-live (CP-018, §10.21, 409): a family already has this name (nothing
  /// charged).
  familyNameTaken('FAMILY_NAME_TAKEN'),

  /// v1.21-live (CP-018, §10.21, 409): a pending join request to another family
  /// exists.
  familyRequestPending('FAMILY_REQUEST_PENDING'),

  /// v1.21-live (CP-018, §10.21, 409): the join request was already answered,
  /// cancelled or expired.
  familyRequestNotPending('FAMILY_REQUEST_NOT_PENDING'),

  /// v1.21-live (CP-018, §10.21, 409): only a family with the leader alone can
  /// be disbanded.
  familyNotEmpty('FAMILY_NOT_EMPTY'),

  /// v1.21-live (CP-018, §10.21, 409): the leader hands the family over or
  /// disbands it instead.
  familyLeaderCannotLeave('FAMILY_LEADER_CANNOT_LEAVE'),

  /// v1.21-live (CP-018, §10.21, 409): the caller or the other person already
  /// has a CP partner.
  cpAlreadyPaired('CP_ALREADY_PAIRED'),

  /// v1.21-live (CP-018, §10.21, 409): the caller already has a pending CP
  /// request.
  cpRequestPending('CP_REQUEST_PENDING'),

  /// v1.21-live (CP-018, §10.21, 409): the CP request was already answered,
  /// cancelled or expired.
  cpRequestNotPending('CP_REQUEST_NOT_PENDING'),

  /// v1.21-live (CP-018, §10.21, 409): a CP gift from a caller who has no
  /// partner.
  cpNotPaired('CP_NOT_PAIRED'),

  /// v1.21-live (CP-018, §10.21, 409): the showcase named a medal the caller
  /// has not earned.
  medalNotUnlocked('MEDAL_NOT_UNLOCKED'),

  /// v1.22-live (CP-019, §10.22, 409): wearing an item the caller does not
  /// own (or an unknown code).
  bagItemNotOwned('BAG_ITEM_NOT_OWNED'),

  /// v1.23-live (CP-020, §10.23, 409): the gift is not in the catalogue or
  /// was disabled; the app reloads the catalogue.
  giftUnavailable('GIFT_UNAVAILABLE'),

  /// v1.23-live (CP-020, §10.23, 409): the gift bag holds too few of that
  /// gift; the app reloads the bag.
  giftBagInsufficient('GIFT_BAG_INSUFFICIENT'),

  /// v1.23-live (CP-020, §10.23, 409): a recipient is no longer the host or
  /// on a seat (or a block); the app reloads the seats.
  liveGiftRecipientUnavailable('LIVE_GIFT_RECIPIENT_UNAVAILABLE'),

  /// v1.24-live (CP-021, §10.24, 409): a daily CP task claimed before it is
  /// done today; nothing was added.
  cpTaskNotCompleted('CP_TASK_NOT_COMPLETED'),

  /// v1.24-live (CP-021, §10.24, 403): another couple's gift wall before it
  /// unlocked `GIFT_WALL`.
  cpPrivilegeLocked('CP_PRIVILEGE_LOCKED'),

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
