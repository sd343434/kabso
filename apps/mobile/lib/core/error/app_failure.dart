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

  /// v1.47-live (D212, 409): a raised hand in a podcast whose host closed
  /// the hands.
  liveQuestionsClosed('LIVE_QUESTIONS_CLOSED'),

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

  /// v1.48-social (D171, §10.45, 409): sending a bag item.
  bagItemNotTransferable('BAG_ITEM_NOT_TRANSFERABLE'),
  bagSendPermanentWholeOnly('BAG_SEND_PERMANENT_WHOLE_ONLY'),
  bagSendExceedsRemaining('BAG_SEND_EXCEEDS_REMAINING'),
  bagRecipientHasPermanent('BAG_RECIPIENT_HAS_PERMANENT'),

  /// v1.23-live (CP-020, §10.23, 409): the gift is not in the catalogue or
  /// was disabled; the app reloads the catalogue.
  giftUnavailable('GIFT_UNAVAILABLE'),

  /// v1.23-live (CP-020, §10.23, 409): the gift bag holds too few of that
  /// gift; the app reloads the bag.
  giftBagInsufficient('GIFT_BAG_INSUFFICIENT'),

  /// v1.23-live (CP-020, §10.23, 409): a recipient is no longer the host or
  /// on a seat (or a block); the app reloads the seats.
  liveGiftRecipientUnavailable('LIVE_GIFT_RECIPIENT_UNAVAILABLE'),

  /// v1.27-live (D132, §10.27, 403): a lucky gift before the 18+
  /// confirmation; nothing was charged; the app asks for it.
  luckyGiftAgeUnconfirmed('LUCKY_GIFT_AGE_UNCONFIRMED'),

  /// v1.27-live (D132, §10.27, 403): lucky gifts are off in the caller's
  /// country; nothing was charged; the app hides the lucky tab.
  luckyGiftRegionUnavailable('LUCKY_GIFT_REGION_UNAVAILABLE'),

  /// v1.24-live (CP-021, §10.24, 409): a daily CP task claimed before it is
  /// done today; nothing was added.
  cpTaskNotCompleted('CP_TASK_NOT_COMPLETED'),

  /// v1.24-live (CP-021, §10.24, 403): another couple's gift wall before it
  /// unlocked `GIFT_WALL`.
  cpPrivilegeLocked('CP_PRIVILEGE_LOCKED'),

  /// v1.25-live (CP-022, §10.25, 403): the leader or a deputy muted the
  /// caller in the family chat.
  familyChatMuted('FAMILY_CHAT_MUTED'),

  /// v1.28-live (D146, §10.32, 409): the name cannot be rented or renewed by
  /// the caller now; nothing was charged; the app reads its status again.
  premiumUsernameUnavailable('PREMIUM_USERNAME_UNAVAILABLE'),

  /// v1.28-live (D146, §10.32, 409): the owner changed the price; nothing
  /// was charged; the app shows the new one.
  premiumUsernamePriceChanged('PREMIUM_USERNAME_PRICE_CHANGED'),

  /// v1.28-live (D146, §10.32, 409): a premium username is active (one at a
  /// time; give it back before changing the regular username).
  premiumUsernameActive('PREMIUM_USERNAME_ACTIVE'),

  /// v1.40-social (D155, §11.13, 403): the person's «who can message you»
  /// does not allow the caller.
  dmNotAllowed('DM_NOT_ALLOWED'),

  /// v1.40-social (D155, §11.13, 403): the request's messages are used up
  /// until the person replies or accepts.
  dmRequestLimit('DM_REQUEST_LIMIT'),

  /// v1.40-social (D155, §11.13, 403): a picture or voice note in a request.
  dmRequestTextOnly('DM_REQUEST_TEXT_ONLY'),

  /// v1.40-social (D155, §11.13, 409): deleting for everyone after an hour.
  dmDeleteWindowPassed('DM_DELETE_WINDOW_PASSED'),

  /// v1.104-social (D339): a message request cannot be archived.
  dmNotArchivable('DM_NOT_ARCHIVABLE'),

  /// v1.104-social (D339): the group would pass its member cap.
  dmGroupFull('DM_GROUP_FULL'),

  /// v1.104-social (D339): someone the caller may not add to a group.
  dmGroupMemberNotAllowed('DM_GROUP_MEMBER_NOT_ALLOWED'),

  /// v1.32-live (D154, §10.33, 409): the caller's one free quip of this
  /// live was sent; paid quips are still available.
  quipFreeUsed('QUIP_FREE_USED'),

  /// v1.32-live (D154, §10.33, 409): too many quips are waiting in this
  /// live; nothing was charged; try again shortly.
  quipQueueFull('QUIP_QUEUE_FULL'),

  /// v1.33-live (D154b, §10.34, 409): every featured slot is booked too far
  /// ahead; nothing was charged.
  boostQueueFull('BOOST_QUEUE_FULL'),

  /// v1.33-live (D154b, §10.34, 409): no traffic card of that length.
  boostCardInsufficient('BOOST_CARD_INSUFFICIENT'),

  /// v1.33-live (D154b, §10.34, 409): this live has a card running or
  /// waiting already.
  boostRoomBusy('BOOST_ROOM_BUSY'),

  /// v1.38-live (D154i, §10.39, 422): the YouTube video is missing, private
  /// or may not be played in other apps.
  youtubeVideoUnavailable('YOUTUBE_VIDEO_UNAVAILABLE'),

  /// v1.38-live (D154i, §10.39, 503): YouTube search is not set up on the
  /// server (or failed); paste a link instead.
  youtubeSearchUnavailable('YOUTUBE_SEARCH_UNAVAILABLE'),

  /// v1.52-social (D179, §10.46, 409): the caller is already a host of
  /// another agency.
  agencyAlreadyMember('AGENCY_ALREADY_MEMBER'),

  /// v1.52-social (D179, §10.46, 409): an agency owner cannot join an
  /// agency as a host.
  agencyJoinNotAllowed('AGENCY_JOIN_NOT_ALLOWED'),

  /// v1.52-social (D179, §10.46, 409): the 14-day leave window is over; a
  /// complaint to the admin remains.
  agencyLeaveWindowClosed('AGENCY_LEAVE_WINDOW_CLOSED'),

  /// v1.70-social (D206, §10.65, 409): «افتح وكالة» refused —
  /// `details[0].issue` says why (`AgencyOpenRefusal`).
  agencyOpenNotAllowed('AGENCY_OPEN_NOT_ALLOWED'),

  /// v1.73-social (D209, §10.68, 409): «كن مضيفاً مع الإدارة» refused —
  /// `details[0].issue` says why (`HostingApplyRefusal`).
  hostApplicationNotAllowed('HOST_APPLICATION_NOT_ALLOWED'),

  /// v1.82-live (D295, §10.108, 409): the agency owner's activation of a
  /// member refused — `details[0].issue`: AGENCY_SUSPENDED, ACCOUNT_NOT_ACTIVE,
  /// STAFF, HOST (a host cannot be made a creator), CREATOR (and back).
  agencyActivationNotAllowed('AGENCY_ACTIVATION_NOT_ALLOWED'),

  /// v1.80-kyc (D227, §10.77, 409): an identity check cannot start now —
  /// `details[0].issue` says why (`KycRefusal`).
  kycNotAllowed('KYC_NOT_ALLOWED'),

  /// v1.80-kyc (D227, 503): identity verification (Didit) is off.
  kycUnavailable('KYC_UNAVAILABLE'),

  /// v1.74-social (D217, §10.71, 503): «دعوة الأصدقاء» is switched off.
  referralUnavailable('REFERRAL_UNAVAILABLE'),

  /// v1.74-social (D217, 422): no such invite code (or the caller's own).
  referralCodeInvalid('REFERRAL_CODE_INVALID'),

  /// v1.74-social (D217, 409): a code was already entered, or the days to
  /// enter one are over (`details[0].issue`).
  referralNotAllowed('REFERRAL_NOT_ALLOWED'),

  /// v1.78-social (D223, §10.75, 409): this device already created its
  /// accounts (`details[0] = {field: device, issue: '<the limit>'}`); signing
  /// in is still possible.
  deviceAccountLimit('DEVICE_ACCOUNT_LIMIT'),

  /// v1.60-live (D250, §10.91.6, 403): the team banned this device «حظر جهاز»
  /// — sign-up, sign-in and going live from it are refused for every account
  /// (`details` `until` — an ISO time or `permanent` — and `reason`).
  deviceBanned('DEVICE_BANNED'),

  /// v1.52-social (D179, §10.46, 409): the cherry balance does not cover
  /// the withdrawal.
  insufficientCherries('INSUFFICIENT_CHERRIES'),

  /// v1.52-social (D179, §10.46, 409): another withdrawal waits to be paid.
  withdrawalPending('WITHDRAWAL_PENDING'),

  /// v1.54-social (D185, §10.48, 409): recharge agents.
  rechargeApplicationNotAllowed('RECHARGE_APPLICATION_NOT_ALLOWED'),
  rechargeAgentNotActive('RECHARGE_AGENT_NOT_ACTIVE'),
  rechargeOffShift('RECHARGE_OFF_SHIFT'),
  rechargeStockInsufficient('RECHARGE_STOCK_INSUFFICIENT'),
  rechargeEmployeeNotAllowed('RECHARGE_EMPLOYEE_NOT_ALLOWED'),
  rechargeCherryRequestPending('RECHARGE_CHERRY_REQUEST_PENDING'),
  rechargeCherryRequestClosed('RECHARGE_CHERRY_REQUEST_CLOSED'),
  rechargeCherryCapReached('RECHARGE_CHERRY_CAP_REACHED'),

  /// v1.54-social (D185): a special username is active and locked.
  usernameLocked('USERNAME_LOCKED'),

  /// v1.55-social (D186, §10.49, 409): the gender sets the host frame's
  /// colour (only a host without a stated gender picks it).
  hostFrameStyleFromGender('HOST_FRAME_STYLE_FROM_GENDER'),

  /// v1.62-social (D193, §10.56, 403): the password given to confirm the
  /// account deletion is not the account's.
  reauthFailed('REAUTH_FAILED'),

  /// v1.62-social (D193, 409): something must be settled before the account
  /// can be deleted (`details[].issue` names each blocker).
  accountDeletionBlocked('ACCOUNT_DELETION_BLOCKED'),

  /// v1.62-social (D193, 409): sign-in to an account in its deletion grace
  /// period (`details` `purgeAfter`); the app offers to cancel. Also the
  /// reason a session ends after the person asked for deletion.
  accountDeletionPending('ACCOUNT_DELETION_PENDING'),

  /// v1.66-social (D198, §10.61.2, 428): a new version of the terms or the
  /// privacy policy waits to be accepted; the app shows the consent screen.
  consentRequired('CONSENT_REQUIRED'),

  /// v1.66-social (D198, 409): the accepted version is no longer the one in
  /// force (a newer one was published while the screen was open).
  consentVersionMismatch('CONSENT_VERSION_MISMATCH'),

  /// v1.66-social (D198, 429): one data export per 24 hours.
  dataExportLimit('DATA_EXPORT_LIMIT'),

  /// v1.66-social (D198, 410): the download link is used, wrong or expired.
  dataExportLinkInvalid('DATA_EXPORT_LINK_INVALID'),

  /// v1.69-social (D204, §10.64): recharge orders (503 switched off; 409 the
  /// rest).
  rechargeOrdersUnavailable('RECHARGE_ORDERS_UNAVAILABLE'),
  rechargeOrderOpenExists('RECHARGE_ORDER_OPEN_EXISTS'),
  rechargeOrderStateChanged('RECHARGE_ORDER_STATE_CHANGED'),
  rechargeOrderNoticeRequired('RECHARGE_ORDER_NOTICE_REQUIRED'),
  rechargeOrderDisputeTooEarly('RECHARGE_ORDER_DISPUTE_TOO_EARLY'),

  /// v1.87-social (D287, §10.100): an employee acting for the agent — the
  /// agent switched the permission off (403), or another person of the
  /// agent's side already took the order (409).
  rechargeEmployeeNotPermitted('RECHARGE_EMPLOYEE_NOT_PERMITTED'),
  rechargeOrderClaimed('RECHARGE_ORDER_CLAIMED'),

  /// D287 (owner, 403): the account to add as an employee is a Kabso Team
  /// account (D283).
  rechargeEmployeeIsStaff('RECHARGE_EMPLOYEE_IS_STAFF'),

  /// v1.72-live (D283, 403): a Kabso Team account cannot do this (D287:
  /// `details` issue `recharge_employee` — acting as a recharge employee).
  staffAccountLimited('STAFF_ACCOUNT_LIMITED'),

  /// v1.72-social (D208): sign-in to an account the team locked for a while
  /// (403; `details` `lockedUntil` and `reason`, shown on the sign-in screen).
  accountLocked('ACCOUNT_LOCKED'),

  /// v1.72-social (D208): the team switched this off for the caller for a
  /// while (403; `details` `restriction` and `until`).
  accountRestricted('ACCOUNT_RESTRICTED'),

  /// v1.72-social (D208): the right password, but the team requires a new
  /// one (403): the app opens the «كلمة مرور جديدة» screen.
  passwordChangeRequired('PASSWORD_CHANGE_REQUIRED'),

  /// v1.82-social (D252, §10.93, 409): this VIP tier cannot be bought by the
  /// caller now (`details` `tier`: `tier_off`, `downgrade` or
  /// `renewal_limit`); nothing was charged.
  vipUnavailable('VIP_UNAVAILABLE'),

  /// v1.82-social (D252, §10.93, 409): the owner changed the tier's price;
  /// nothing was charged; the app reloads the tiers.
  vipPriceChanged('VIP_PRICE_CHANGED'),

  /// D270 (§10.98, 409): this store item cannot be bought now (`details`:
  /// `item` `item_off` / `owned_permanent`, `days` `not_priced` /
  /// `too_far`); nothing was charged.
  storeUnavailable('STORE_UNAVAILABLE'),

  /// D270 (§10.98, 409): the owner changed the item's price; nothing was
  /// charged; the app reloads the items.
  storePriceChanged('STORE_PRICE_CHANGED'),

  /// v1.110-social (D345, §10.144, 503): the store (Google Play / App Store)
  /// is not set up on this server.
  storeIapUnavailable('STORE_IAP_UNAVAILABLE'),

  /// v1.110-social (D345, 400): the store did not confirm the purchase.
  storeIapVerificationFailed('STORE_IAP_VERIFICATION_FAILED'),

  /// v1.110-social (D345, 409): the purchase belongs to another account.
  storeIapPurchaseConflict('STORE_IAP_PURCHASE_CONFLICT'),

  /// v1.110-social (D345, 409): the store has not completed the payment yet.
  storeIapPending('STORE_IAP_PENDING'),

  /// v1.68-live (D273, §10.96.7, 403): the person holds a panel role — the
  /// app never acts on «فريق كابسو» (kick, mute, message, seat, family).
  staffProtected('STAFF_PROTECTED'),

  /// v1.68-live (D273, §10.96.6, 403): «فريق كابسو» sends no gifts, taps or
  /// bullets in a live and takes no seat; a hidden observer does not chat.
  liveStaffRefused('LIVE_STAFF_REFUSED'),

  /// v1.68-live (D273, §10.96.6, 403): a staff tool needs the step-up (the
  /// panel authenticator code in the app).
  staffStepUpRequired('STAFF_STEP_UP_REQUIRED'),

  /// v1.68-live (D273, 409): the panel authenticator is not set up yet.
  staffTotpNotEnrolled('STAFF_TOTP_NOT_ENROLLED'),

  /// v1.60-social (D191; used by the app since D273, 403): the authenticator
  /// code is wrong or used (counts towards the lockout).
  adminTotpInvalid('ADMIN_TOTP_INVALID'),

  /// v1.60-social (D191; app since D273, 429): locked after wrong codes.
  adminLocked('ADMIN_LOCKED'),

  /// v1.60-social (D191; app since D273, 409): a panel rule refused it.
  adminActionRefused('ADMIN_ACTION_REFUSED'),

  /// v1.89-social (D290, 409): a level-raise request for a source account
  /// that already has one PENDING / APPROVED (`details`: `status`,
  /// `createdAt`, `requestedBy`).
  levelRaiseDuplicate('LEVEL_RAISE_DUPLICATE'),

  /// v1.95-social (D301, 403): only the app owner can do this.
  ownerOnly('OWNER_ONLY'),

  /// v1.95-social (D301, 409): «رحلة Kabso» already has 30 milestones.
  ownerJourneyLimit('OWNER_JOURNEY_LIMIT'),

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
