import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';

// The Me hub's programs (openapi v1.44-social, D166, CONVENTIONS §10.41):
// the Task Center, the Event Center, SVIP and the recharge packages. Every
// number comes from the server; the app never computes progress, ranks or
// tiers itself.

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

int? _intOrNull(Object? v) => (v as num?)?.toInt();

DateTime? _timeOrNull(Object? v) =>
    v == null ? null : DateTime.parse(v as String);

List<Map<String, dynamic>> _list(Object? v) => [
  for (final e in v! as List<dynamic>) e as Map<String, dynamic>,
];

/// `ProgramTask.metric`: what a task counts (decides where «اذهب» leads).
/// v1.50-social (D176) adds the daily pool's metrics; an unknown one is
/// [other] (a generic icon, «اذهب» to the live hub). v1.57-social (D188)
/// adds [giftCoinsSent]: the coin value of the gifts sent (target in coins).
enum TaskMetric {
  watchLives('WATCH_LIVES'),
  follows('FOLLOWS'),
  liveChatMessages('LIVE_CHAT_MESSAGES'),
  giftSends('GIFT_SENDS'),
  hostLiveMinutes('HOST_LIVE_MINUTES'),
  hostGiftCoins('HOST_GIFT_COINS'),
  watchMinutes('WATCH_MINUTES'),
  audioRooms('AUDIO_ROOMS'),
  liveTaps('LIVE_TAPS'),
  newHostGifts('NEW_HOST_GIFTS'),
  posts('POSTS'),
  reels('REELS'),
  stories('STORIES'),
  postComments('POST_COMMENTS'),
  dmFriends('DM_FRIENDS'),
  dmVoiceMessages('DM_VOICE_MESSAGES'),
  hostGiftsReceived('HOST_GIFTS_RECEIVED'),
  hostGuests('HOST_GUESTS'),
  giftCoinsSent('GIFT_COINS_SENT'),
  // v1.69-live (D277): the host's «هدف الهدايا» and «هدف هدايا الحظ», in
  // cherries (target in cherries).
  hostGiftCherries('HOST_GIFT_CHERRIES'),
  hostLuckyCherries('HOST_LUCKY_CHERRIES'),
  // v1.85-social (D281): the generated catalogue's new actions — a chosen
  // gift ([ProgramTask.gift]) or a category sent, different people gifted,
  // joining a family, family chat, PK battles and wins (hosts).
  giftCountSent('GIFT_COUNT_SENT'),
  categoryGiftsSent('CATEGORY_GIFTS_SENT'),
  giftedHosts('GIFTED_HOSTS'),
  familyJoin('FAMILY_JOIN'),
  familyChatMessages('FAMILY_CHAT_MESSAGES'),
  pkBattles('PK_BATTLES'),
  pkWins('PK_WINS'),
  // v1.94-social (D297): the creator tasks' metrics — what other people did
  // with the creator's content (views of their reels, likes, the comments
  // they replied to, new followers, shares and reposts).
  reelViewsReceived('REEL_VIEWS_RECEIVED'),
  likesReceived('LIKES_RECEIVED'),
  commentReplies('COMMENT_REPLIES'),
  newFollowers('NEW_FOLLOWERS'),
  sharesReceived('SHARES_RECEIVED'),
  // D297 follow-up: different days with a live of 10 minutes or more (hosts).
  hostLiveDays('HOST_LIVE_DAYS'),
  other('');

  new(this.wire);

  final String wire;

  static TaskMetric fromWire(Object? wire) =>
      values.where((m) => m.wire == wire && m != other).firstOrNull ?? other;
}

/// v1.85-social (D281) `TaskGift`: the gift a chosen-gift task names.
@immutable
final class TaskGift {
  const new({
    required this.code,
    required this.name,
    required this.assetKey,
    this.imageUrl,
  });

  factory fromJson(Map<String, dynamic> json) => TaskGift(
    code: json['code']! as String,
    name: json['name']! as String,
    assetKey: (json['assetKey'] as String?) ?? '',
    imageUrl: json['imageUrl'] as String?,
  );

  final String code;
  final String name;
  final String assetKey;
  final String? imageUrl;
}

/// `ProgramTask`: one task with the progress the server computed.
@immutable
final class ProgramTask {
  const new({
    required this.code,
    required this.weekly,
    required this.metric,
    required this.forHosts,
    required this.name,
    required this.target,
    required this.progress,
    required this.completed,
    required this.claimed,
    this.rewardCherries = 0,
    this.rewardCoins = 0,
    this.claimedCoins,
    this.claimedCherries,
    this.pooled = false,
    this.forCreators = false,
    this.gift,
    this.windowFrom,
    this.windowTo,
  });

  factory fromJson(Map<String, dynamic> json) => ProgramTask(
    gift: json['gift'] is Map<String, dynamic>
        ? TaskGift.fromJson(json['gift'] as Map<String, dynamic>)
        : null,
    windowFrom: (json['window'] as Map<String, dynamic>?)?['from'] as String?,
    windowTo: (json['window'] as Map<String, dynamic>?)?['to'] as String?,
    code: json['code']! as String,
    pooled: json['pooled'] == true,
    weekly: json['period'] == 'WEEKLY',
    metric: TaskMetric.fromWire(json['metric']),
    forHosts: json['audience'] == 'HOSTS',
    forCreators: json['audience'] == 'CREATORS',
    name: json['name']! as String,
    target: _int(json['target']),
    progress: _int(json['progress']),
    rewardCherries: _int(json['rewardCherries']),
    rewardCoins: _int(json['rewardCoins']),
    completed: json['completed']! as bool,
    claimed: json['claimed']! as bool,
    claimedCoins: _intOrNull(json['claimedCoins']),
    claimedCherries: _intOrNull(json['claimedCherries']),
  );

  final String code;
  final bool weekly;
  final TaskMetric metric;
  final bool forHosts;

  /// v1.94-social (D297): a creator task «مهام صانع المحتوى» (audience
  /// `CREATORS`: creator-programme members only), shown in its own section.
  final bool forCreators;
  final String name;
  final int target;
  final int progress;

  /// v1.53-social (D184, CONVENTIONS §10.41.3): the cherries the task pays.
  final int rewardCherries;

  /// Deprecated since v1.53-social (0); a server before it paid coins.
  final int rewardCoins;
  final bool completed;
  final bool claimed;

  /// What the claim paid in coins (a claim made before v1.53-social).
  final int? claimedCoins;

  /// v1.53-social (D184): what the claim paid in cherries (after the cap).
  final int? claimedCherries;

  /// The reward is (or was paid) in coins: a server before v1.53-social, or
  /// a claim made in coins before the change. Otherwise cherries.
  bool get inCoins =>
      (rewardCherries == 0 && rewardCoins > 0) ||
      (claimed && (claimedCherries ?? 0) == 0 && (claimedCoins ?? 0) > 0);

  /// The amount the row shows: what the claim paid, else the reward.
  int get shownReward => inCoins
      ? (claimedCoins ?? rewardCoins)
      : (claimedCherries ?? rewardCherries);

  /// v1.50-social (D176): one of the caller's daily pool tasks of today.
  final bool pooled;

  /// v1.85-social (D281): the gift a chosen-gift task names (its picture on
  /// the row), else null.
  final TaskGift? gift;

  /// v1.85-social (D281): the task's hours of the day (`HH:MM`; the server's
  /// name states them too), null for the whole day.
  final String? windowFrom;
  final String? windowTo;
}

/// `MyTasks.band` (v1.50-social, D176): the level band of today's tasks.
typedef TaskBand = ({int band, int level, String name, bool host});

/// `CheckInDay`: one day of the sign-in strip (today first).
@immutable
final class CheckInDay {
  const new({
    required this.date,
    required this.cycleDay,
    required this.today,
    required this.checkedIn,
    required this.rewardCoins,
  });

  factory fromJson(Map<String, dynamic> json) => CheckInDay(
    date: DateTime.parse(json['date']! as String),
    cycleDay: _int(json['cycleDay']),
    today: json['today']! as bool,
    checkedIn: json['checkedIn']! as bool,
    rewardCoins: _int(json['rewardCoins']),
  );

  /// The calendar day (no time zone: shown as month.day).
  final DateTime date;

  /// 1…7; 7 is the bonus day.
  final int cycleDay;
  final bool today;
  final bool checkedIn;
  final int rewardCoins;
}

/// `MyTasks.checkIn`.
@immutable
final class CheckInState {
  const new({
    required this.checkedInToday,
    required this.streak,
    required this.cycleDays,
    required this.rewardCoins,
    required this.bonusCoins,
    required this.days,
  });

  factory fromJson(Map<String, dynamic> json) => CheckInState(
    checkedInToday: json['checkedInToday']! as bool,
    streak: _int(json['streak']),
    cycleDays: _int(json['cycleDays']),
    rewardCoins: _int(json['rewardCoins']),
    bonusCoins: _int(json['bonusCoins']),
    days: [for (final d in _list(json['days'])) CheckInDay.fromJson(d)],
  );

  final bool checkedInToday;
  final int streak;
  final int cycleDays;
  final int rewardCoins;
  final int bonusCoins;
  final List<CheckInDay> days;

  /// Check-ins still needed (today included when not done) to reach the
  /// bonus day, 0 when today is the bonus day and it is done.
  int get daysToBonus {
    final index = days.indexWhere((d) => d.cycleDay == cycleDays);
    if (index < 0) return 0;
    return checkedInToday ? index : index + 1;
  }
}

/// `MyTasks`: the caller's Task Center.
@immutable
final class MyTasks {
  const new({
    required this.dailyCapCoins,
    required this.dailyEarnedCoins,
    required this.checkIn,
    required this.tasks,
    this.dailyCapCherries = 0,
    this.dailyEarnedCherries = 0,
    this.monthlyCapCherries = 0,
    this.monthlyEarnedCherries = 0,
    this.band,
    this.creator = false,
  });

  factory fromJson(Map<String, dynamic> json) => MyTasks(
    band: switch (json['band']) {
      final Map<String, dynamic> b => (
        band: _int(b['band']),
        level: _int(b['level']),
        name: b['name']! as String,
        host: b['host'] == true,
      ),
      _ => null,
    },
    creator: switch (json['band']) {
      final Map<String, dynamic> b => b['creator'] == true,
      _ => false,
    },
    dailyCapCoins: _int(json['dailyCapCoins']),
    dailyEarnedCoins: _int(json['dailyEarnedCoins']),
    dailyCapCherries: _int(json['dailyCapCherries']),
    dailyEarnedCherries: _int(json['dailyEarnedCherries']),
    monthlyCapCherries: _int(json['monthlyCapCherries']),
    monthlyEarnedCherries: _int(json['monthlyEarnedCherries']),
    checkIn: CheckInState.fromJson(json['checkIn']! as Map<String, dynamic>),
    tasks: [for (final t in _list(json['tasks'])) ProgramTask.fromJson(t)],
  );

  /// Since v1.53-social (D184): the check-in's coin cap.
  final int dailyCapCoins;
  final int dailyEarnedCoins;

  /// v1.53-social (D184): the daily tasks' cherry cap (0 from an older
  /// server: the coin cap is the tasks' cap then).
  final int dailyCapCherries;
  final int dailyEarnedCherries;

  /// v1.57-social (D188, CONVENTIONS §10.51): the calendar month's cap of
  /// task cherries, daily and weekly tasks together (0 = none, or an older
  /// server: no monthly line).
  final int monthlyCapCherries;
  final int monthlyEarnedCherries;
  final CheckInState checkIn;
  final List<ProgramTask> tasks;

  /// Null from a server before v1.50-social.
  final TaskBand? band;

  /// v1.94-social (D297, `MyTasks.band.creator`): the caller is a member of
  /// the creator programme (creator tasks are offered; host tasks are not).
  final bool creator;

  /// Today's tasks for the «مكافآت المهام» card (creator tasks have their own).
  List<ProgramTask> get daily => [
    for (final t in tasks)
      if (!t.weekly && !t.forCreators) t,
  ];

  /// The weekly host tasks (creator ones have their own card).
  List<ProgramTask> get weekly => [
    for (final t in tasks)
      if (t.weekly && !t.forCreators) t,
  ];

  /// v1.94-social (D297): today's creator tasks «مهام صانع المحتوى».
  List<ProgramTask> get creatorDaily => [
    for (final t in tasks)
      if (!t.weekly && t.forCreators) t,
  ];

  /// v1.94-social (D297): this week's creator tasks.
  List<ProgramTask> get creatorWeekly => [
    for (final t in tasks)
      if (t.weekly && t.forCreators) t,
  ];
}

/// `SvipPerk`.
@immutable
final class SvipPerk {
  const new({
    required this.code,
    required this.name,
    required this.unlockTier,
    required this.unlocked,
    required this.available,
  });

  factory fromJson(Map<String, dynamic> json) => SvipPerk(
    code: json['code']! as String,
    name: json['name']! as String,
    unlockTier: _int(json['unlockTier']),
    unlocked: json['unlocked']! as bool,
    available: json['available']! as bool,
  );

  final String code;
  final String name;
  final int unlockTier;

  /// The caller's tier reaches it.
  final bool unlocked;

  /// The perk is built and works today; never shown as active otherwise.
  final bool available;
}

/// `SvipStatus`.
@immutable
final class SvipStatus {
  const new({
    required this.tier,
    required this.windowDays,
    required this.spentCoins,
    required this.thresholds,
    required this.perks,
    this.expiresAt,
    this.nextTier,
    this.coinsToNext,
  });

  factory fromJson(Map<String, dynamic> json) => SvipStatus(
    tier: _int(json['tier']),
    expiresAt: _timeOrNull(json['expiresAt']),
    windowDays: _int(json['windowDays']),
    spentCoins: _int(json['spentCoins']),
    thresholds: [
      for (final t in _list(json['tiers'])) _int(t['thresholdCoins']),
    ],
    nextTier: _intOrNull(json['nextTier']),
    coinsToNext: _intOrNull(json['coinsToNext']),
    perks: [for (final p in _list(json['perks'])) SvipPerk.fromJson(p)],
  );

  /// 0 = not SVIP.
  final int tier;
  final DateTime? expiresAt;
  final int windowDays;
  final int spentCoins;

  /// Coins to spend in the window for SVIP 1, 2, … (ascending).
  final List<int> thresholds;
  final int? nextTier;
  final int? coinsToNext;
  final List<SvipPerk> perks;
}

/// `EventSummary.status`.
enum EventStatus { upcoming, running, ended }

/// `EventSummary.tone` (v1.50-social, D176): the calendar bar's Kabso hue.
enum EventTone {
  red,
  gold,
  teal,
  blue,
  pink,
  amber;

  static EventTone? fromWire(Object? wire) =>
      values.where((t) => t.name.toUpperCase() == wire).firstOrNull;
}

/// `EventSummary`.
@immutable
class EventSummary {
  const new({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.status,
    required this.metric,
    required this.forHosts,
    required this.permanent,
    required this.featured,
    this.bannerUrl,
    this.endsAt,
    this.summary,
    this.tone,
  });

  factory fromJson(Map<String, dynamic> json) => EventSummary(
    summary: json['summary'] as String?,
    tone: EventTone.fromWire(json['tone']),
    id: json['id']! as String,
    title: json['title']! as String,
    bannerUrl: json['bannerUrl'] as String?,
    startsAt: DateTime.parse(json['startsAt']! as String),
    endsAt: _timeOrNull(json['endsAt']),
    status: switch (json['status']) {
      'UPCOMING' => EventStatus.upcoming,
      'ENDED' => EventStatus.ended,
      _ => EventStatus.running,
    },
    metric: json['metric']! as String,
    forHosts: json['audience'] == 'HOSTS',
    permanent: json['permanent']! as bool,
    featured: json['featured']! as bool,
  );

  final String id;
  final String title;
  final String? bannerUrl;
  final DateTime startsAt;

  /// Null only for a permanent event without an end.
  final DateTime? endsAt;
  final EventStatus status;

  /// `GIFT_COINS_RECEIVED`, `GIFT_COINS_SENT`, `LIVE_MINUTES`,
  /// `TAPS_RECEIVED` or `NEW_FOLLOWERS`.
  final String metric;
  final bool forHosts;
  final bool permanent;
  final bool featured;

  /// v1.50-social (D176): the calendar bar's second line (a short prize
  /// line), null when none.
  final String? summary;

  /// v1.50-social (D176): null = a stable hue from the id.
  final EventTone? tone;
}

/// `EventPrize`.
typedef EventPrize = ({int rankFrom, int rankTo, int coins});

/// v1.97-social (D303, CONVENTIONS §10.114.3): one item of a prize bundle —
/// coins / cherries ([amount]) or a bag item / VIP card for [days].
@immutable
final class EventPrizeItem {
  const new({
    required this.type,
    this.amount,
    this.days,
    this.code,
    this.name,
    this.category,
    this.assetKey,
    this.color,
    this.imageUrl,
    this.level,
    this.cherries,
    this.coins,
  });

  factory fromJson(Map<String, dynamic> json) => EventPrizeItem(
    imageUrl: json['imageUrl'] as String?,
    level: _intOrNull(json['level']),
    cherries: _intOrNull(json['cherries']),
    coins: _intOrNull(json['coins']),
    type: json['type']! as String,
    amount: _intOrNull(json['amount']),
    days: _intOrNull(json['days']),
    code: json['code'] as String?,
    name: json['name'] as String?,
    category: json['category'] as String?,
    assetKey: json['assetKey'] as String?,
    color: json['color'] as String?,
  );

  /// `COINS`, `CHERRIES`, `BAG_ITEM` or `VIP` (others: shown by name).
  final String type;
  final int? amount;
  final int? days;
  final String? code;
  final String? name;

  /// A bag item's category (`AVATAR_FRAME`, `ENTRY_EFFECT` …); `VIP`.
  final String? category;
  final String? assetKey;

  /// VIP: the tier colour `#RRGGBB`.
  final String? color;

  /// D303 follow-ups — BADGE: the medal level's art and the level.
  final String? imageUrl;
  final int? level;

  /// CP_MONEY: cherries for a host / creator partner, coins for another.
  final int? cherries;
  final int? coins;

  /// A bag item or a medal with no end («دائم»).
  bool get isPermanent =>
      (type == 'BAG_ITEM' || type == 'BADGE') && days == null;
}

/// v1.97-social (D303 follow-ups): `EventDetail.art` — the page art.
@immutable
final class EventArt {
  const new({
    this.backgroundUrl,
    this.backgroundKind,
    this.posterUrl,
    this.titleUrl,
    this.overlayUrl,
    this.overlayFormat,
  });

  factory fromJson(Map<String, dynamic>? json) {
    if (json == null) return const EventArt();
    final bg = json['background'] as Map<String, dynamic>?;
    final overlay = json['overlay'] as Map<String, dynamic>?;
    return EventArt(
      backgroundUrl: bg?['url'] as String?,
      backgroundKind: bg?['kind'] as String?,
      posterUrl: bg?['posterUrl'] as String?,
      titleUrl: json['titleUrl'] as String?,
      overlayUrl: overlay?['url'] as String?,
      overlayFormat: overlay?['format'] as String?,
    );
  }

  /// `IMAGE`, `ANIMATED` or `VIDEO`.
  final String? backgroundKind;
  final String? backgroundUrl;
  final String? posterUrl;
  final String? titleUrl;

  /// `SVGA` or `LOTTIE`.
  final String? overlayFormat;
  final String? overlayUrl;

  /// The still to show (a video's poster, else the picture).
  String? get stillUrl => backgroundKind == 'VIDEO' ? posterUrl : backgroundUrl;

  bool get isEmpty =>
      backgroundUrl == null && titleUrl == null && overlayUrl == null;
}

/// `EventPrizeLine` (D303): the bundle of ranks `rankFrom` … `rankTo`.
typedef EventPrizeLine = ({
  int rankFrom,
  int rankTo,
  List<EventPrizeItem> items,
});

List<EventPrizeItem> _items(Object? v) => [
  for (final i in _list(v)) EventPrizeItem.fromJson(i),
];

/// v1.97-social (D303): a gift event's board kinds, in the server's order.
enum EventBoardKind {
  senders('SENDERS'),
  receivers('RECEIVERS'),
  creators('CREATORS'),
  agencies('AGENCIES'),
  cp('CP');

  new(this.wire);

  final String wire;

  static EventBoardKind? fromWire(Object? wire) =>
      values.where((k) => k.wire == wire).firstOrNull;
}

/// `EventBoard` (D303): a board, its qualification minimum and its prizes.
@immutable
final class EventBoardInfo {
  const new({
    required this.kind,
    required this.minPoints,
    required this.prizes,
  });

  final EventBoardKind kind;
  final int minPoints;
  final List<EventPrizeLine> prizes;
}

/// `EventGift` (D303): an event gift with its price and points.
@immutable
final class EventGiftInfo {
  const new({
    required this.code,
    required this.name,
    required this.priceCoins,
    required this.assetKey,
    required this.pointsPerCoin,
    required this.pointsPerGift,
    required this.pointsEach,
    this.imageUrl,
  });

  factory fromJson(Map<String, dynamic> json) => EventGiftInfo(
    code: json['code']! as String,
    name: json['name']! as String,
    priceCoins: _int(json['priceCoins']),
    assetKey: json['assetKey']! as String,
    imageUrl: json['imageUrl'] as String?,
    pointsPerCoin: _int(json['pointsPerCoin']),
    pointsPerGift: _int(json['pointsPerGift']),
    pointsEach: _int(json['pointsEach']),
  );

  final String code;
  final String name;
  final int priceCoins;
  final String assetKey;
  final String? imageUrl;
  final int pointsPerCoin;
  final int pointsPerGift;

  /// The points of one such gift per recipient.
  final int pointsEach;
}

/// `EventDetail`.
@immutable
final class EventDetail extends EventSummary {
  const new({
    required super.id,
    required super.title,
    required super.startsAt,
    required super.status,
    required super.metric,
    required super.forHosts,
    required super.permanent,
    required super.featured,
    required this.rules,
    required this.prizes,
    super.bannerUrl,
    super.endsAt,
    super.summary,
    super.tone,
    this.paidAt,
    this.timeZone,
    this.gifts = const [],
    this.boards = const [],
    this.art = const EventArt(),
  });

  factory fromJson(Map<String, dynamic> json) {
    final s = EventSummary.fromJson(json);
    return EventDetail(
      id: s.id,
      title: s.title,
      bannerUrl: s.bannerUrl,
      startsAt: s.startsAt,
      endsAt: s.endsAt,
      status: s.status,
      metric: s.metric,
      forHosts: s.forHosts,
      permanent: s.permanent,
      featured: s.featured,
      summary: s.summary,
      tone: s.tone,
      rules: json['rules']! as String,
      prizes: [
        for (final p in _list(json['prizes']))
          (
            rankFrom: _int(p['rankFrom']),
            rankTo: _int(p['rankTo']),
            coins: _int(p['coins']),
          ),
      ],
      paidAt: _timeOrNull(json['paidAt']),
      timeZone: json['timeZone'] as String?,
      art: EventArt.fromJson(json['art'] as Map<String, dynamic>?),
      gifts: [for (final g in _list(json['gifts'])) EventGiftInfo.fromJson(g)],
      boards: [
        for (final b in _list(json['boards']))
          if (EventBoardKind.fromWire(b['kind']) case final kind?)
            EventBoardInfo(
              kind: kind,
              minPoints: _int(b['minPoints']),
              prizes: [
                for (final l in _list(b['prizes']))
                  (
                    rankFrom: _int(l['rankFrom']),
                    rankTo: _int(l['rankTo']),
                    items: _items(l['items']),
                  ),
              ],
            ),
      ],
    );
  }

  final String rules;
  final List<EventPrize> prizes;
  final DateTime? paidAt;

  /// v1.97-social (D303): the zone the event's dates are set in.
  final String? timeZone;

  /// v1.97-social (D303): a gift event's gifts and boards (empty otherwise).
  final List<EventGiftInfo> gifts;
  final List<EventBoardInfo> boards;

  /// v1.97-social (D303 follow-ups): the page art.
  final EventArt art;

  /// A gift event (`EVENT_GIFTS`, D303).
  bool get isGiftEvent => metric == 'EVENT_GIFTS';
}

/// v1.97-social (D303): one row of a gift event's board — CP rows have a
/// [partner], AGENCIES rows the [agencyName] ([user] is its owner).
@immutable
final class GiftBoardRow {
  const new({
    required this.rank,
    required this.user,
    required this.score,
    required this.qualified,
    required this.prize,
    this.partner,
    this.agencyName,
    this.isAgency = false,
  });

  final int rank;
  final UserSummary user;
  final UserSummary? partner;
  final String? agencyName;
  final bool isAgency;
  final int score;
  final bool qualified;
  final List<EventPrizeItem> prize;
}

/// `EventLeaderboard` row.
typedef EventRank = ({int rank, UserSummary user, int score, int prizeCoins});

/// `EventLeaderboard`.
@immutable
final class EventLeaderboard {
  const new({
    required this.isFinal,
    required this.rows,
    required this.myScore,
    required this.myPrize,
    this.myRank,
    this.board,
    this.minPoints = 0,
    this.giftRows = const [],
    this.myQualified = false,
    this.pointsToQualify = 0,
    this.myBundle = const [],
    this.myPrizeStatus,
  });

  factory fromJson(Map<String, dynamic> json) {
    final me = json['me']! as Map<String, dynamic>;
    return EventLeaderboard(
      board: EventBoardKind.fromWire(json['board']),
      minPoints: _int(json['minPoints']),
      giftRows: [
        for (final r in _list(json['data']))
          GiftBoardRow(
            rank: _int(r['rank']),
            user: UserSummary.fromJson(r['user']! as Map<String, dynamic>),
            partner: r['partner'] == null
                ? null
                : UserSummary.fromJson(r['partner']! as Map<String, dynamic>),
            isAgency: r['agency'] != null,
            agencyName:
                (r['agency'] as Map<String, dynamic>?)?['name'] as String?,
            score: _int(r['score']),
            qualified: r['qualified'] as bool? ?? true,
            prize: _items(r['prize']),
          ),
      ],
      myQualified: me['qualified'] as bool? ?? false,
      pointsToQualify: _int(me['pointsToQualify']),
      myBundle: _items(me['prize']),
      myPrizeStatus: EventPrizeStatus.fromWire(me['prizeStatus']),
      isFinal: json['final']! as bool,
      rows: [
        for (final r in _list(json['data']))
          (
            rank: _int(r['rank']),
            user: UserSummary.fromJson(r['user']! as Map<String, dynamic>),
            score: _int(r['score']),
            prizeCoins: _int(r['prizeCoins']),
          ),
      ],
      myRank: _intOrNull(me['rank']),
      myScore: _int(me['score']),
      myPrize: _int(me['prizeCoins']),
    );
  }

  final bool isFinal;
  final List<EventRank> rows;
  final int? myRank;
  final int myScore;
  final int myPrize;

  /// v1.97-social (D303): a gift event's board, its minimum, its rows with
  /// their bundles, and the caller's qualification.
  final EventBoardKind? board;
  final int minPoints;
  final List<GiftBoardRow> giftRows;
  final bool myQualified;
  final int pointsToQualify;
  final List<EventPrizeItem> myBundle;

  /// v1.105-social (D340, §10.134.1): a final board's prize for the caller
  /// (null on a live board, or from an older server).
  final EventPrizeStatus? myPrizeStatus;
}

/// v1.105-social (D340): `EventLeaderboard.me.prizeStatus`.
enum EventPrizeStatus {
  none('NONE'),
  pending('PENDING'),
  paid('PAID'),
  forfeited('FORFEITED');

  new(this.wire);

  final String wire;

  /// Null for a value this app does not know (or none sent).
  static EventPrizeStatus? fromWire(Object? wire) =>
      values.where((s) => s.wire == wire).firstOrNull;
}

/// `EventList.tab`.
enum EventTab {
  calendar('CALENDAR'),
  permanent('PERMANENT'),
  regional('REGIONAL');

  new(this.wire);

  final String wire;
}

/// `EventList`.
@immutable
final class EventList {
  const new({required this.events, this.country});

  factory fromJson(Map<String, dynamic> json) => EventList(
    country: json['country'] as String?,
    events: [for (final e in _list(json['data'])) EventSummary.fromJson(e)],
  );

  /// The caller's country (the regional tab), null when not set.
  final String? country;
  final List<EventSummary> events;
}

/// `RechargePackages` entry.
@immutable
final class RechargePackage {
  const new({
    required this.id,
    required this.coins,
    required this.bonusCoins,
    required this.priceMinor,
    this.originalPriceMinor,
  });

  factory fromJson(Map<String, dynamic> json) => RechargePackage(
    id: json['id']! as String,
    coins: _int(json['coins']),
    bonusCoins: _int(json['bonusCoins']),
    priceMinor: _int(json['priceMinor']),
    originalPriceMinor: _intOrNull(json['originalPriceMinor']),
  );

  final String id;
  final int coins;
  final int bonusCoins;

  /// In the currency's minor unit (cents).
  final int priceMinor;

  /// The price before a discount (the «عرض» ribbon), or null.
  final int? originalPriceMinor;

  int get totalCoins => coins + bonusCoins;
}

/// `RechargePackages`.
@immutable
final class RechargeOffer {
  const new({
    required this.currency,
    required this.purchasesEnabled,
    required this.packages,
    this.websiteTopupUrl,
  });

  factory fromJson(Map<String, dynamic> json) => RechargeOffer(
    currency: json['currency']! as String,
    purchasesEnabled: json['purchasesEnabled']! as bool,
    packages: [
      for (final p in _list(json['packages'])) RechargePackage.fromJson(p),
    ],
    websiteTopupUrl: _httpsUrl(json['websiteTopupUrl']),
  );

  /// Only an http(s) URL is kept (anything else hides the link).
  static String? _httpsUrl(Object? raw) {
    if (raw is! String) return null;
    final uri = Uri.tryParse(raw);
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http')
        ? raw
        : null;
  }

  final String currency;

  /// False until store purchases are allowed (B5).
  final bool purchasesEnabled;
  final List<RechargePackage> packages;

  /// v1.59-social (D190): the Kabso website's top-up page for the
  /// «الشحن من الموقع» link. Null (the default) unless the server switches
  /// the link on (`TOPUP_APP_LINK_ENABLED`, on by default; a server switch).
  /// The app never takes a card payment itself.
  final String? websiteTopupUrl;
}

/// The outcome of a claim or a check-in: the coins it paid (the check-in, a
/// claim made in coins before v1.53-social) and the cherries (a task claim
/// since v1.53-social, D184).
typedef ProgramPayout = ({int paidCoins, int balanceCoins, int paidCherries});

/// The Me hub's programs (openapi v1.44-social, D166). Every method throws
/// an `AppFailure`.
abstract interface class ProgramsRepository {
  /// `GET /me/tasks`.
  Future<MyTasks> tasks();

  /// `POST /me/check-in`.
  Future<ProgramPayout> checkIn();

  /// `POST /me/tasks/{code}/claim`.
  Future<ProgramPayout> claim(String code);

  /// `GET /me/svip`.
  Future<SvipStatus> svip();

  /// `GET /events?tab=&month=` ([month] is `YYYY-MM`, the calendar tab).
  Future<EventList> events(EventTab tab, {String? month});

  /// `GET /events/{eventId}`.
  Future<EventDetail> event(String eventId);

  /// `GET /events/{eventId}/leaderboard` (D303: `?board=` of a gift event).
  Future<EventLeaderboard> leaderboard(String eventId, {String? board});

  /// `GET /wallet/recharge-packages`.
  Future<RechargeOffer> rechargePackages();
}

class ProgramsRepositoryImpl implements ProgramsRepository {
  new(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, dynamic>? query,
  ]) async {
    final res = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: query,
    );
    return res.data!;
  }

  ProgramPayout _payout(Map<String, dynamic> json) => (
    paidCoins: _int(json['paidCoins']),
    balanceCoins: _int(json['balanceCoins']),
    paidCherries: _int(json['paidCherries']),
  );

  @override
  Future<MyTasks> tasks() =>
      guardApiCall(() async => MyTasks.fromJson(await _get('/me/tasks')));

  @override
  Future<ProgramPayout> checkIn() => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>('/me/check-in');
    return _payout(res.data!);
  });

  @override
  Future<ProgramPayout> claim(String code) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/me/tasks/${pathSegment(code)}/claim',
    );
    return _payout(res.data!);
  });

  @override
  Future<SvipStatus> svip() =>
      guardApiCall(() async => SvipStatus.fromJson(await _get('/me/svip')));

  @override
  Future<EventList> events(EventTab tab, {String? month}) => guardApiCall(
    () async => EventList.fromJson(
      await _get('/events', {'tab': tab.wire, 'month': ?month}),
    ),
  );

  @override
  Future<EventDetail> event(String eventId) => guardApiCall(
    () async =>
        EventDetail.fromJson(await _get('/events/${pathSegment(eventId)}')),
  );

  @override
  Future<EventLeaderboard> leaderboard(String eventId, {String? board}) =>
      guardApiCall(
        () async => EventLeaderboard.fromJson(
          await _get('/events/${pathSegment(eventId)}/leaderboard', {
            'board': ?board,
          }),
        ),
      );

  @override
  Future<RechargeOffer> rechargePackages() => guardApiCall(
    () async => RechargeOffer.fromJson(await _get('/wallet/recharge-packages')),
  );
}

final programsRepositoryProvider = Provider<ProgramsRepository>(
  (ref) => ProgramsRepositoryImpl(ref.watch(apiDioProvider)),
);

/// The Task Center's promo banners (`GET /home/banners?placement=tasks`,
/// v1.50-social, D176): the team's banners for the slot at the bottom of
/// the page; none → the slot is hidden.
abstract interface class TaskBannersRepository {
  Future<List<HomeBanner>> list();
}

class TaskBannersRepositoryImpl implements TaskBannersRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<List<HomeBanner>> list() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/home/banners',
      queryParameters: const {'placement': 'tasks'},
    );
    return [
      for (final item in res.data!['data']! as List<dynamic>)
        HomeBanner.fromJson(item as Map<String, dynamic>),
    ];
  });
}

final taskBannersRepositoryProvider = Provider<TaskBannersRepository>(
  (ref) => TaskBannersRepositoryImpl(ref.watch(apiDioProvider)),
);
