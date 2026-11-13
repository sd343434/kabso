// Wire models of the notifications API (docs/contracts/openapi.yaml
// v1.5-social DRAFT, CP-009, CONVENTIONS §11.10). Hand-written `fromJson`,
// as the posts models: a body that does not match throws, which
// `guardApiCall` turns into an `UnexpectedFailure`.

import 'package:kabso_live/core/models/shared_models.dart';
import 'package:material_ui/material_ui.dart';

/// `NotificationType`. [unknown] is a type a newer server added; the app
/// skips it.
enum NotificationType {
  likePost('LIKE_POST'),
  likeComment('LIKE_COMMENT'),
  comment('COMMENT'),
  reply('REPLY'),
  mention('MENTION'),
  follow('FOLLOW'),
  repost('REPOST'),
  postPublished('POST_PUBLISHED'),
  contentRemoved('CONTENT_REMOVED'),

  /// v1.14-live (CP-016 C): a host you follow goes live in about 15
  /// minutes (target: the host as a user, with the title and the start).
  liveScheduledSoon('LIVE_SCHEDULED_SOON'),

  /// v1.21-live (CP-018): someone sent you a CP request (target: them as a
  /// user).
  cpRequest('CP_REQUEST'),

  /// v1.21-live (CP-018): your CP request was accepted (target: the
  /// partner as a user).
  cpAccepted('CP_ACCEPTED'),

  /// v1.21-live (CP-018): your join request was accepted or declined
  /// (target: the family, its name as `text`; actor: who answered).
  familyJoinAccepted('FAMILY_JOIN_ACCEPTED'),
  familyJoinDeclined('FAMILY_JOIN_DECLINED'),

  /// v1.21-live (CP-018, system): you earned a medal (target: the medal
  /// code; its name and icon come from `GET /medals`).
  medalAwarded('MEDAL_AWARDED'),

  /// v1.28-live (D146, system): your premium username ends soon / ended
  /// (target: the username, `endsAt`).
  premiumUsernameExpiring('PREMIUM_USERNAME_EXPIRING'),
  premiumUsernameExpired('PREMIUM_USERNAME_EXPIRED'),

  /// v1.48-social (D171): someone sent you a bag item (actor: the sender;
  /// target: the item, with its category).
  bagItemReceived('BAG_ITEM_RECEIVED'),

  /// v1.54-social (D185): a recharge agent (or employee) sold you coins
  /// (actor: the seller; target RECHARGE_SALE with `coins`).
  rechargeCoinsReceived('RECHARGE_COINS_RECEIVED'),

  /// v1.54-social (D185): a host or agent asks you to confirm a cherry sale
  /// (actor: them; no target — opens the cherry requests).
  rechargeCherryRequest('RECHARGE_CHERRY_REQUEST'),

  /// v1.47-social (D175): someone asked to follow your private account
  /// (target: them as a user; opens the follow requests).
  followRequest('FOLLOW_REQUEST'),

  /// v1.47-social (D175): your follow request was accepted (target: the
  /// account as a user).
  followRequestAccepted('FOLLOW_REQUEST_ACCEPTED'),

  /// v1.47-social (D175, system): a moderator removed your profile photo.
  avatarRemoved('AVATAR_REMOVED'),

  /// v1.76-social (D218, system): a moderator removed your profile cover.
  coverRemoved('COVER_REMOVED'),

  /// v1.136-social (D384, system): a moderator removed your VIP animated
  /// picture «صورة متحركة» (no target; opens it to record another).
  animatedAvatarRemoved('ANIMATED_AVATAR_REMOVED'),

  /// v1.138-social (D386, system): the Kabso Team verified your account
  /// category (no target; opens Edit profile).
  categoryVerified('CATEGORY_VERIFIED'),

  /// v1.138-social (D386, system): the team rejected your request, removed
  /// the verification, cleared, locked or unlocked your category (no target;
  /// opens Edit profile, where the details are).
  categoryReviewed('CATEGORY_REVIEWED'),

  /// v1.66-social (D198, system): the data export «تنزيل بياناتي» is ready
  /// (no target; opens the export screen).
  dataExportReady('DATA_EXPORT_READY'),

  /// v1.69-social (D204, system): a recharge order you take part in changed
  /// or got a message (target RECHARGE_ORDER with `orderEvent`).
  rechargeOrderUpdate('RECHARGE_ORDER_UPDATE'),

  /// v1.70-social (D206, system; target AGENCY): «افتح وكالة» — your agency
  /// is open, a day left in its trial (with the count), it passed, it was
  /// closed (with the count when the trial failed), or the agency you were in
  /// was closed and you are free. All open «الوكالة».
  agencyOpened('AGENCY_OPENED'),
  agencyProbationReminder('AGENCY_PROBATION_REMINDER'),
  agencyProbationPassed('AGENCY_PROBATION_PASSED'),
  agencyClosed('AGENCY_CLOSED'),
  agencyHostReleased('AGENCY_HOST_RELEASED'),

  /// v1.73-social (D209, system, no target): «كن مضيفاً مع الإدارة» — the
  /// team approved / rejected the application. Both open «الوكالة».
  hostApplicationApproved('HOST_APPLICATION_APPROVED'),
  hostApplicationRejected('HOST_APPLICATION_REJECTED'),

  /// v1.74-social (D217, system, no target): the team voided a referral and
  /// took back the cherries it had credited. Opens the cherry wallet.
  referralRewardReversed('REFERRAL_REWARD_REVERSED'),

  /// v1.80-kyc (D227, system, no target): the identity check «تأكيد الهوية»
  /// was approved / declined / sent to a review. All open «الوكالة».
  kycApproved('KYC_APPROVED'),
  kycDeclined('KYC_DECLINED'),
  kycInReview('KYC_IN_REVIEW'),

  /// v1.60-live (D250, system; target LIVE_MODERATION): the team acted on
  /// your live from the panel — ended it, possibly with a ban from going
  /// live, a suspension or a device ban until a time (or for good) — with
  /// the team's reason. No tap target.
  liveModerated('LIVE_MODERATED'),

  /// v1.68-live (D273, system; target LIVE_ROOM): a report on a live this
  /// staff member looks after — opens the live as «فريق كابسو» on its
  /// reports.
  liveStaffReport('LIVE_STAFF_REPORT'),

  /// v1.78-live (D288, system; target REPORT): a new report in the shared
  /// queue — every moderator and support member; opens «بلاغات» on it.
  staffReportNew('STAFF_REPORT_NEW'),

  /// v1.89-social (D290, system; target LEVEL_RAISE): the owner approved /
  /// rejected the staff member's level-raise request (`text` the supporter's
  /// username, `level` the approved level) — opens «طلبات رفع الليفيل»; the
  /// supporter's own support level was raised (`level`) — opens the levels.
  levelRaiseApproved('LEVEL_RAISE_APPROVED'),
  levelRaiseRejected('LEVEL_RAISE_REJECTED'),
  levelRaised('LEVEL_RAISED'),

  /// v1.95-social (D301, system; target OWNER_FEEDBACK, to the app owners
  /// only): a new suggestion or staff report in «صندوق المؤسس» (the panel).
  ownerFeedbackNew('OWNER_FEEDBACK_NEW'),

  /// v1.95-social (D301 follow-up, system; target POST with `texts`): the
  /// app owner published an official announcement — to everyone, once.
  ownerAnnouncement('OWNER_ANNOUNCEMENT'),

  /// v1.97-social (D303, system; target EVENT): a prize of an event board was
  /// paid to you — opens the event.
  eventPrizeWon('EVENT_PRIZE_WON'),

  /// v1.127-social (D372; actor the sender(s), target POST): someone sent a
  /// gift on your post or reel «هدية الدعم» — one row per post.
  contentGiftReceived('CONTENT_GIFT_RECEIVED'),

  /// v1.141-social (D390, system, no target): «برنامج سفراء Kabso» — the
  /// application approved / rejected, a level up, a monthly reward granted.
  ambassadorApplicationApproved('AMBASSADOR_APPLICATION_APPROVED'),
  ambassadorApplicationRejected('AMBASSADOR_APPLICATION_REJECTED'),
  ambassadorLevelUp('AMBASSADOR_LEVEL_UP'),
  ambassadorRewardGranted('AMBASSADOR_REWARD_GRANTED'),
  ambassadorMembershipEnded('AMBASSADOR_MEMBERSHIP_ENDED'),
  unknown('');

  new(this.wire);

  factory fromWire(Object? value) => values.firstWhere(
    (t) => t.wire == value && t != unknown,
    orElse: () => unknown,
  );

  final String wire;

  /// No actor: the app or moderation told you (always on).
  bool get isSystem =>
      this == postPublished ||
      this == contentRemoved ||
      this == medalAwarded ||
      this == premiumUsernameExpiring ||
      this == premiumUsernameExpired ||
      this == avatarRemoved ||
      this == coverRemoved ||
      this == animatedAvatarRemoved ||
      this == dataExportReady ||
      this == rechargeOrderUpdate ||
      isAgency ||
      isHostApplication ||
      isKyc ||
      this == liveModerated ||
      this == liveStaffReport ||
      this == staffReportNew ||
      isLevelRaise ||
      this == ownerFeedbackNew ||
      this == ownerAnnouncement ||
      this == referralRewardReversed ||
      isAmbassador;

  /// v1.141-social (D390): the ambassadors programme.
  bool get isAmbassador =>
      this == ambassadorApplicationApproved ||
      this == ambassadorApplicationRejected ||
      this == ambassadorLevelUp ||
      this == ambassadorRewardGranted ||
      this == ambassadorMembershipEnded;

  /// v1.89-social (D290): a level-raise request's result.
  bool get isLevelRaise =>
      this == levelRaiseApproved ||
      this == levelRaiseRejected ||
      this == levelRaised ||
      this == eventPrizeWon;

  /// v1.80-kyc (D227): the identity check's result.
  bool get isKyc =>
      this == kycApproved || this == kycDeclined || this == kycInReview;

  /// v1.73-social (D209): the decision on «كن مضيفاً مع الإدارة».
  bool get isHostApplication =>
      this == hostApplicationApproved || this == hostApplicationRejected;

  /// v1.70-social (D206): one of the agency's system notifications.
  bool get isAgency =>
      this == agencyOpened ||
      this == agencyProbationReminder ||
      this == agencyProbationPassed ||
      this == agencyClosed ||
      this == agencyHostReleased;
}

/// `NotificationTarget.type`.
enum NotificationTargetType {
  post('POST'),
  comment('COMMENT'),
  story('STORY'),
  user('USER'),

  /// v1.21-live (CP-018): a family (id; `text` its name).
  family('FAMILY'),

  /// v1.21-live (CP-018): a medal (its code as the id).
  medal('MEDAL'),

  /// v1.28-live (D146): a premium username (the name as the id; `endsAt`).
  premiumUsername('PREMIUM_USERNAME'),

  /// v1.48-social (D171): a bag item (its code as the id; `bagCategory`).
  bagItem('BAG_ITEM'),

  /// v1.54-social (D185): coins bought from a recharge agent (`coins`).
  rechargeSale('RECHARGE_SALE'),

  /// v1.69-social (D204): a recharge order (its id; `coins`, `orderEvent`).
  rechargeOrder('RECHARGE_ORDER'),

  /// v1.70-social (D206): an agency (its id; `text` its name;
  /// `activatedHosts` / `requiredHosts`).
  agency('AGENCY'),

  /// v1.60-live (D250): the team's action on a live (its id; `moderation`,
  /// `reason`, `endsAt` or `permanent`; `text` the reason's excerpt).
  liveModeration('LIVE_MODERATION'),

  /// v1.68-live (D273): a live (its id; `text` the host's name).
  liveRoom('LIVE_ROOM'),

  /// v1.78-live (D288): a report of the shared queue (its id; no text).
  report('REPORT'),

  /// v1.89-social (D290): a level-raise request (its id; `text` the
  /// supporter's username for the staff member; `level` the approved level).
  levelRaise('LEVEL_RAISE'),

  /// v1.95-social (D301): a «صندوق المؤسس» item (its id; `feedbackKind`).
  ownerFeedback('OWNER_FEEDBACK'),

  /// v1.97-social (D303): an event (EVENT_PRIZE_WON).
  event('EVENT');

  new(this.wire);

  factory fromWire(Object? value) => values.firstWhere((t) => t.wire == value);

  /// Whether [value] is a target type this app knows (a newer server may
  /// add one; such a target is read as none rather than failing the page).
  static bool isKnown(Object? value) => values.any((t) => t.wire == value);

  final String wire;
}

/// `NotificationTarget`: what a notification points at.
@immutable
class NotificationTarget {
  const new({
    required this.type,
    required this.id,
    this.postId,
    this.thumbUrl,
    this.text,
    this.startsAt,
    this.endsAt,
    this.bagCategory,
    this.coins,
    this.orderEvent,
    this.activatedHosts,
    this.requiredHosts,
    this.moderation,
    this.reason,
    this.permanent = false,
    this.level,
    this.medalLevel,
    this.feedbackKind,
    this.texts,
  });

  factory fromJson(Map<String, dynamic> json) => NotificationTarget(
    type: NotificationTargetType.fromWire(json['type']),
    id: json['id']! as String,
    postId: json['postId'] as String?,
    thumbUrl: json['thumbUrl'] as String?,
    text: json['text'] as String?,
    startsAt: switch (json['startsAt']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
    endsAt: switch (json['endsAt']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
    bagCategory: json['bagCategory'] as String?,
    coins: (json['coins'] as num?)?.toInt(),
    orderEvent: json['orderEvent'] as String?,
    activatedHosts: (json['activatedHosts'] as num?)?.toInt(),
    requiredHosts: (json['requiredHosts'] as num?)?.toInt(),
    moderation: json['moderation'] as String?,
    reason: json['reason'] as String?,
    permanent: json['permanent'] as bool? ?? false,
    level: (json['level'] as num?)?.toInt(),
    medalLevel: (json['medalLevel'] as num?)?.toInt(),
    feedbackKind: json['feedbackKind'] as String?,
    texts: switch (json['texts']) {
      final Map<String, dynamic> t => (
        ar: t['ar'] as String?,
        en: t['en'] as String?,
      ),
      _ => null,
    },
  );

  /// v1.95-social (D301 follow-up): OWNER_ANNOUNCEMENT — both caption
  /// excerpts (the row shows the app language's).
  final ({String? ar, String? en})? texts;

  /// v1.95-social (D301) [NotificationTargetType.ownerFeedback]: `FEATURE`
  /// or `STAFF_REPORT` (never who sent it, about whom or the text).
  final String? feedbackKind;

  /// v1.89-social (D290) [NotificationTargetType.levelRaise]: the support
  /// level approved.
  final int? level;

  final NotificationTargetType type;

  /// A post, comment or story id, a username for a
  /// [NotificationTargetType.user] target, a family id or a medal code.
  final String id;

  /// For a comment: its post.
  final String? postId;

  /// The post or story photo (320 px), when it has one.
  final String? thumbUrl;

  /// A short excerpt (≤ 80 characters) of the comment or caption, or the
  /// scheduled live's title.
  final String? text;

  /// [NotificationType.liveScheduledSoon]: when the live is planned.
  final DateTime? startsAt;

  /// D146 [NotificationTargetType.premiumUsername]: the period's (or the
  /// grace's) end.
  final DateTime? endsAt;

  /// D171 [NotificationTargetType.bagItem]: the item's category (wire).
  final String? bagCategory;

  /// RECHARGE_SALE only (v1.54-social, D185): the coins bought; RECHARGE_ORDER
  /// (v1.69-social, D204): the order's coins.
  final int? coins;

  /// RECHARGE_ORDER only (v1.69-social, D204): the latest event.
  final String? orderEvent;

  /// AGENCY only (v1.70-social, D206): the activated hosts reached and the
  /// hosts needed (the trial's reminder, pass and failure).
  final int? activatedHosts;
  final int? requiredHosts;

  /// LIVE_MODERATION only (v1.60-live, D250): `END`, `NO_LIVE`, `SUSPEND` or
  /// `DEVICE_BAN` (wire), the team's full [reason], and whether a device ban
  /// is [permanent] (then no [endsAt]).
  final String? moderation;
  final String? reason;
  final bool permanent;

  /// MEDAL only (v1.81-live, D291): the level announced — 1 = earned,
  /// more = a level-up; null on older servers.
  final int? medalLevel;
}

/// `Notification`. Likes and reposts on one item group while unread
/// ([actors] are the latest three, [actorCount] all of them).
@immutable
class AppNotification {
  const new({
    required this.id,
    required this.type,
    required this.actors,
    required this.actorCount,
    required this.target,
    required this.createdAt,
    required this.read,
  });

  factory fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id']! as String,
    type: NotificationType.fromWire(json['type']),
    actors: [
      for (final a in json['actors']! as List<dynamic>)
        UserSummary.fromJson(a as Map<String, dynamic>),
    ],
    actorCount: json['actorCount']! as int,
    target: switch (json['target']) {
      final Map<String, dynamic> t
          when NotificationTargetType.isKnown(t['type']) =>
        NotificationTarget.fromJson(t),
      _ => null,
    },
    createdAt: DateTime.parse(json['createdAt']! as String),
    read: json['read']! as bool,
  );

  final String id;
  final NotificationType type;
  final List<UserSummary> actors;
  final int actorCount;
  final NotificationTarget? target;

  /// The latest activity in the group.
  final DateTime createdAt;
  final bool read;

  AppNotification asRead() => AppNotification(
    id: id,
    type: type,
    actors: actors,
    actorCount: actorCount,
    target: target,
    createdAt: createdAt,
    read: true,
  );
}

/// `NotificationSettings`: each switch is on until changed.
@immutable
class NotificationSettings {
  const new({
    this.likes = true,
    this.comments = true,
    this.mentions = true,
    this.follows = true,
    this.reposts = true,
    this.lives = true,
    this.messages = true,
    this.giftStrip = true,
    this.gameStrip = true,
    this.luckyStrip = true,
  });

  factory fromJson(Map<String, dynamic> json) => NotificationSettings(
    likes: json['likes']! as bool,
    comments: json['comments']! as bool,
    mentions: json['mentions']! as bool,
    follows: json['follows']! as bool,
    reposts: json['reposts']! as bool,
    // v1.14-live; an older server does not send it (on).
    lives: json['lives'] as bool? ?? true,
    // v1.30-live (D152); an older server does not send it (on).
    messages: json['messages'] as bool? ?? true,
    // v1.85-live (D305); an older server does not send them (on).
    giftStrip: json['giftStrip'] as bool? ?? true,
    gameStrip: json['gameStrip'] as bool? ?? true,
    // v1.111-live (D347); an older server does not send it (shown).
    luckyStrip: json['luckyStrip'] as bool? ?? true,
  );

  final bool likes;

  /// Comments on your posts and replies to your comments.
  final bool comments;
  final bool mentions;
  final bool follows;
  final bool reposts;

  /// Reminders of lives scheduled by hosts you follow (CP-016 C).
  final bool lives;

  /// Pushes of new family chat messages (v1.30-live, D152).
  final bool messages;

  /// v1.85-live (D305): the global gifts strip «شريط الهدايا» shows in
  /// every live this account watches or hosts (the server still sends it).
  final bool giftStrip;

  /// v1.85-live (D305): the global games strip «شريط الألعاب».
  final bool gameStrip;

  /// v1.111-live (D347): the global lucky banner «شريط المردود» (a ×250 /
  /// ×500 / ×1000 win in another live); false = «إخفاء أشرطة الفوز».
  final bool luckyStrip;

  @override
  bool operator ==(Object other) =>
      other is NotificationSettings &&
      other.likes == likes &&
      other.comments == comments &&
      other.mentions == mentions &&
      other.follows == follows &&
      other.reposts == reposts &&
      other.lives == lives &&
      other.messages == messages &&
      other.giftStrip == giftStrip &&
      other.gameStrip == gameStrip &&
      other.luckyStrip == luckyStrip;

  @override
  int get hashCode => Object.hash(
    likes,
    comments,
    mentions,
    follows,
    reposts,
    lives,
    messages,
    giftStrip,
    gameStrip,
    luckyStrip,
  );
}

/// One switch of [NotificationSettings] (the wire field name).
enum NotificationSetting {
  likes,
  comments,
  mentions,
  follows,
  reposts,
  lives,
  messages,

  /// v1.85-live (D305): the global strips in the lives.
  giftStrip,
  gameStrip,

  /// v1.111-live (D347): the global lucky banner (false: hidden).
  luckyStrip;

  bool of(NotificationSettings s) => switch (this) {
    likes => s.likes,
    comments => s.comments,
    mentions => s.mentions,
    follows => s.follows,
    reposts => s.reposts,
    lives => s.lives,
    messages => s.messages,
    giftStrip => s.giftStrip,
    gameStrip => s.gameStrip,
    luckyStrip => s.luckyStrip,
  };

  NotificationSettings set(NotificationSettings s, {required bool on}) =>
      NotificationSettings(
        likes: this == likes ? on : s.likes,
        comments: this == comments ? on : s.comments,
        mentions: this == mentions ? on : s.mentions,
        follows: this == follows ? on : s.follows,
        reposts: this == reposts ? on : s.reposts,
        lives: this == lives ? on : s.lives,
        messages: this == messages ? on : s.messages,
        giftStrip: this == giftStrip ? on : s.giftStrip,
        gameStrip: this == gameStrip ? on : s.gameStrip,
        luckyStrip: this == luckyStrip ? on : s.luckyStrip,
      );
}
