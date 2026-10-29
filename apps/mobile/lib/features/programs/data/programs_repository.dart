import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';

// The Me hub's programs (openapi v1.44-social, D166, CONVENTIONS §10.41):
// the Task Center, the Event Center, SVIP and the recharge packages. Every
// number comes from the server; the app never computes progress, ranks or
// tiers itself.

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

int? _intOrNull(Object? v) => (v as num?)?.toInt();

DateTime? _timeOrNull(Object? v) => v == null ? null : DateTime.parse(v as String);

List<Map<String, dynamic>> _list(Object? v) => [
  for (final e in v! as List<dynamic>) e as Map<String, dynamic>,
];

/// `ProgramTask.metric`: what a task counts (decides where «اذهب» leads).
enum TaskMetric {
  watchLives('WATCH_LIVES'),
  follows('FOLLOWS'),
  liveChatMessages('LIVE_CHAT_MESSAGES'),
  giftSends('GIFT_SENDS'),
  hostLiveMinutes('HOST_LIVE_MINUTES'),
  hostGiftCoins('HOST_GIFT_COINS'),
  other('');

  new(this.wire);

  final String wire;

  static TaskMetric fromWire(Object? wire) =>
      values.where((m) => m.wire == wire && m != other).firstOrNull ?? other;
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
    required this.rewardCoins,
    required this.completed,
    required this.claimed,
    this.claimedCoins,
  });

  factory fromJson(Map<String, dynamic> json) => ProgramTask(
    code: json['code']! as String,
    weekly: json['period'] == 'WEEKLY',
    metric: TaskMetric.fromWire(json['metric']),
    forHosts: json['audience'] == 'HOSTS',
    name: json['name']! as String,
    target: _int(json['target']),
    progress: _int(json['progress']),
    rewardCoins: _int(json['rewardCoins']),
    completed: json['completed']! as bool,
    claimed: json['claimed']! as bool,
    claimedCoins: _intOrNull(json['claimedCoins']),
  );

  final String code;
  final bool weekly;
  final TaskMetric metric;
  final bool forHosts;
  final String name;
  final int target;
  final int progress;
  final int rewardCoins;
  final bool completed;
  final bool claimed;

  /// What the claim paid (after the daily cap).
  final int? claimedCoins;
}

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
  });

  factory fromJson(Map<String, dynamic> json) => MyTasks(
    dailyCapCoins: _int(json['dailyCapCoins']),
    dailyEarnedCoins: _int(json['dailyEarnedCoins']),
    checkIn: CheckInState.fromJson(json['checkIn']! as Map<String, dynamic>),
    tasks: [for (final t in _list(json['tasks'])) ProgramTask.fromJson(t)],
  );

  final int dailyCapCoins;
  final int dailyEarnedCoins;
  final CheckInState checkIn;
  final List<ProgramTask> tasks;

  List<ProgramTask> get daily => [
    for (final t in tasks)
      if (!t.weekly) t,
  ];

  List<ProgramTask> get weekly => [
    for (final t in tasks)
      if (t.weekly) t,
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
  });

  factory fromJson(Map<String, dynamic> json) => EventSummary(
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
}

/// `EventPrize`.
typedef EventPrize = ({int rankFrom, int rankTo, int coins});

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
    this.paidAt,
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
    );
  }

  final String rules;
  final List<EventPrize> prizes;
  final DateTime? paidAt;
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
  });

  factory fromJson(Map<String, dynamic> json) {
    final me = json['me']! as Map<String, dynamic>;
    return EventLeaderboard(
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
  });

  factory fromJson(Map<String, dynamic> json) => RechargeOffer(
    currency: json['currency']! as String,
    purchasesEnabled: json['purchasesEnabled']! as bool,
    packages: [
      for (final p in _list(json['packages'])) RechargePackage.fromJson(p),
    ],
  );

  final String currency;

  /// False until store purchases are allowed (B5).
  final bool purchasesEnabled;
  final List<RechargePackage> packages;
}

/// The outcome of a claim or a check-in: the coins it paid.
typedef ProgramPayout = ({int paidCoins, int balanceCoins});

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

  /// `GET /events/{eventId}/leaderboard`.
  Future<EventLeaderboard> leaderboard(String eventId);

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

  ProgramPayout _payout(Map<String, dynamic> json) =>
      (paidCoins: _int(json['paidCoins']), balanceCoins: _int(json['balanceCoins']));

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
  Future<EventLeaderboard> leaderboard(String eventId) => guardApiCall(
    () async => EventLeaderboard.fromJson(
      await _get('/events/${pathSegment(eventId)}/leaderboard'),
    ),
  );

  @override
  Future<RechargeOffer> rechargePackages() => guardApiCall(
    () async =>
        RechargeOffer.fromJson(await _get('/wallet/recharge-packages')),
  );
}

final programsRepositoryProvider = Provider<ProgramsRepository>(
  (ref) => ProgramsRepositoryImpl(ref.watch(apiDioProvider)),
);
