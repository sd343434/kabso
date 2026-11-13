import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:material_ui/material_ui.dart' show immutable;

/// `HostStatsPeriod` (v1.44-live, D199, CONVENTIONS §10.62): Riyadh calendar
/// periods, like the tasks.
enum HostStatsPeriod {
  day('DAY'),
  week('WEEK'),
  month('MONTH'),
  all('ALL');

  new(this.wire);

  final String wire;
}

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// `HostTarget`: today's progress against one of the host's daily targets
/// ([target] 0: no target — its task is switched off).
@immutable
final class HostTarget {
  const new({
    required this.received,
    required this.target,
    required this.reached,
  });

  factory fromJson(Map<String, dynamic> json) => HostTarget(
    received: _int(json['received']),
    target: _int(json['target']),
    reached: json['reached'] == true,
  );

  final int received;
  final int target;
  final bool reached;

  bool get hasTarget => target > 0;

  /// 0 … 1 (1 once reached; 0 without a target).
  double get progress => target <= 0 ? 0 : (received / target).clamp(0.0, 1.0);
}

/// D281 (v1.71-live): a smart target's level «سهل / متوسط / صعب».
enum TargetLevel {
  easy('EASY'),
  medium('MEDIUM'),
  hard('HARD');

  new(this.wire);

  final String wire;

  static TargetLevel fromWire(Object? wire) =>
      values.firstWhere((l) => l.wire == wire, orElse: () => easy);
}

/// D281b: the sheet's two tabs — «الهدايا» and «هدايا الحظ» (three targets
/// each).
enum TargetTrack {
  gifts('GIFTS'),
  lucky('LUCKY');

  new(this.wire);

  final String wire;

  static TargetTrack fromWire(Object? wire) =>
      values.firstWhere((t) => t.wire == wire, orElse: () => gifts);
}

/// D281: a gift a target names (its picture and name).
@immutable
final class TargetGift {
  const new({
    required this.code,
    required this.name,
    required this.assetKey,
    this.imageUrl,
  });

  factory fromJson(Map<String, dynamic> json) => TargetGift(
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

/// D281 `HostDailyTarget` (v1.71-live, CONVENTIONS §10.62.2): one of the
/// host's three smart targets of today — its level, title (in the caller's
/// language), progress and reward (locked task cherries: a share of the
/// platform profit it produced; [paidCherries] once paid).
@immutable
final class HostDailyTarget {
  const new({
    required this.level,
    required this.code,
    required this.kind,
    required this.title,
    required this.amount,
    required this.progress,
    required this.reached,
    required this.rewardCherries,
    this.track = TargetTrack.gifts,
    this.rewardBps = 0,
    this.paidCherries,
    this.windowFrom,
    this.windowTo,
    this.gift,
    this.categoryName,
  });

  factory fromJson(Map<String, dynamic> json) {
    final window = json['window'];
    final gift = json['gift'];
    final category = json['category'];
    return HostDailyTarget(
      // D281b: a server before it sends gift targets only.
      track: TargetTrack.fromWire(json['track']),
      level: TargetLevel.fromWire(json['level']),
      code: (json['code'] as String?) ?? '',
      kind: (json['kind'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      amount: _int(json['amount']),
      progress: _int(json['progress']),
      reached: json['reached'] == true,
      rewardCherries: _int(json['rewardCherries']),
      rewardBps: _int(json['rewardBps']),
      paidCherries: (json['paidCherries'] as num?)?.toInt(),
      windowFrom: window is Map<String, dynamic>
          ? window['from'] as String?
          : null,
      windowTo: window is Map<String, dynamic> ? window['to'] as String? : null,
      gift: gift is Map<String, dynamic> ? TargetGift.fromJson(gift) : null,
      categoryName: category is Map<String, dynamic>
          ? category['name'] as String?
          : null,
    );
  }

  /// D281b: the tab the target belongs to.
  final TargetTrack track;
  final TargetLevel level;
  final String code;

  /// `GIFT_CHERRIES`, `LUCKY_CHERRIES`, `GIFT_COUNT`, … (an unknown kind is
  /// shown with the gifts badge).
  final String kind;
  final String title;
  final int amount;
  final int progress;
  final bool reached;
  final int rewardCherries;
  final int rewardBps;
  final int? paidCherries;

  /// The hours of the day (`HH:MM`), null for the whole day.
  final String? windowFrom;
  final String? windowTo;
  final TargetGift? gift;
  final String? categoryName;

  bool get lucky => track == TargetTrack.lucky;
  bool get paid => paidCherries != null;

  /// What the row shows: what was paid, else the reward offered.
  int get shownReward => paidCherries ?? rewardCherries;

  /// 0 … 1.
  double get fraction => amount <= 0 ? 0 : (progress / amount).clamp(0.0, 1.0);
}

/// `HostSupporter`: a giver, the coin value of their gifts in the period
/// and (D199b) the cherries the host got from them and their support level.
@immutable
final class HostSupporter {
  const new({
    required this.user,
    required this.coins,
    this.cherries = 0,
    this.supportLevel,
  });

  factory fromJson(Map<String, dynamic> json) => HostSupporter(
    user: UserSummary.fromJson(json['user']! as Map<String, dynamic>),
    coins: _int(json['coins']),
    cherries: _int(json['cherries']),
    supportLevel: (json['supportLevel'] as num?)?.toInt(),
  );

  final UserSummary user;
  final int coins;
  final int cherries;

  /// The `SUPPORT` level number (null while that category is unavailable).
  final int? supportLevel;
}

/// `HostSupporterRank` (D199b): the caller's own place in a list today
/// ([rank] null: they sent nothing). [amount] is cherries in the cherries
/// list, coins in the lucky list.
@immutable
final class HostSupporterRank {
  const new({required this.rank, required this.amount});

  factory fromJson(Map<String, dynamic> json) => HostSupporterRank(
    rank: (json['rank'] as num?)?.toInt(),
    amount: _int(json['amount']),
  );

  final int? rank;
  final int amount;
}

List<HostSupporter> _supporters(Object? list) => [
  for (final s in (list as List<dynamic>?) ?? const <dynamic>[])
    HostSupporter.fromJson(s as Map<String, dynamic>),
];

/// `LiveHostTargets` (`GET /live/hosts/{username}/targets`, public): the
/// «تارجت» chip — today's two targets and supporters (D199b: up to 20 by
/// cherries, the lucky list by coins, the end of the day and a signed-in
/// caller's own place).
///
/// D277 (owner): both targets in cherries — [gifts] «هدف الهدايا» (gifts
/// outside the lucky category from other people; `gifts`, or the older
/// server's `cherries`) and [lucky] «هدف هدايا الحظ» (lucky gifts, the host's
/// own sends to themself included).
@immutable
final class LiveHostTargets {
  const new({
    required this.day,
    required this.band,
    required this.gifts,
    required this.lucky,
    required this.topSupporters,
    this.endsAt,
    this.luckySupporters = const [],
    this.meGifts,
    this.meLucky,
    this.daily = const [],
  });

  factory fromJson(Map<String, dynamic> json) {
    final me = json['me'];
    final endsAt = json['endsAt'];
    // D277: `gifts`; a server before it sends `cherries` only.
    final gifts = json['gifts'] ?? json['cherries'];
    final meGifts = me is Map<String, dynamic>
        ? me['gifts'] ?? me['cherries']
        : null;
    return LiveHostTargets(
      day: json['day']! as String,
      band: _int(json['band']),
      gifts: HostTarget.fromJson(gifts! as Map<String, dynamic>),
      lucky: HostTarget.fromJson(json['lucky']! as Map<String, dynamic>),
      topSupporters: _supporters(json['topSupporters']),
      endsAt: endsAt is String ? DateTime.parse(endsAt) : null,
      luckySupporters: _supporters(json['luckySupporters']),
      meGifts: meGifts is Map<String, dynamic>
          ? HostSupporterRank.fromJson(meGifts)
          : null,
      meLucky: me is Map<String, dynamic>
          ? HostSupporterRank.fromJson(me['lucky']! as Map<String, dynamic>)
          : null,
      daily: [
        for (final t in (json['daily'] as List<dynamic>?) ?? const <dynamic>[])
          HostDailyTarget.fromJson(t as Map<String, dynamic>),
      ],
    );
  }

  /// The Riyadh day (`YYYY-MM-DD`).
  final String day;
  final int band;

  /// D277 «هدف الهدايا» (cherries; was the cherries target).
  final HostTarget gifts;

  /// «هدف هدايا الحظ» (D277: cherries).
  final HostTarget lucky;

  /// Today's gifts list (by cherries; D277: gifts outside the lucky category).
  final List<HostSupporter> topSupporters;

  /// The end of the Riyadh day (the countdown; null from an older server).
  final DateTime? endsAt;

  /// Today's lucky list.
  final List<HostSupporter> luckySupporters;

  /// The signed-in caller's own place today (null for guests and the host).
  final HostSupporterRank? meGifts;
  final HostSupporterRank? meLucky;

  /// D281 (v1.71-live): the host's three smart targets of today (easy,
  /// medium, hard); empty before the smart engine's first day or from an
  /// older server (then [gifts] / [lucky] are D277's two targets).
  final List<HostDailyTarget> daily;
}

/// One bucket of the cherries series (an hour, a day or a month, local).
@immutable
final class HostCherriesBucket {
  const new({required this.start, required this.cherries});

  final DateTime start;
  final int cherries;
}

/// `HostGiftStats` (`GET /me/host-gift-stats?period=`): the host's own
/// cherries and lucky-gift numbers for a period (D277: [cherries] and the
/// list are «هدف الهدايا»'s — gifts outside the lucky category).
@immutable
final class HostGiftStats {
  const new({
    required this.period,
    required this.cherries,
    required this.gifts,
    required this.givers,
    required this.topSupporters,
    required this.series,
    required this.luckyCoins,
    required this.luckyGifts,
    required this.luckyGivers,
    required this.luckySupporters,
    this.luckyCherries = 0,
    this.targets,
    this.to,
  });

  factory fromJson(Map<String, dynamic> json) {
    final c = json['cherries']! as Map<String, dynamic>;
    final l = json['lucky']! as Map<String, dynamic>;
    final targets = json['targets'];
    final to = json['to'];
    return HostGiftStats(
      to: to is String ? DateTime.parse(to) : null,
      period: HostStatsPeriod.values.firstWhere(
        (p) => p.wire == json['period'],
        orElse: () => HostStatsPeriod.day,
      ),
      cherries: _int(c['received']),
      gifts: _int(c['gifts']),
      givers: _int(c['givers']),
      topSupporters: _supporters(c['topSupporters']),
      series: [
        for (final b in (c['series'] as List<dynamic>?) ?? const <dynamic>[])
          HostCherriesBucket(
            start: DateTime.parse(
              (b as Map<String, dynamic>)['start']! as String,
            ),
            cherries: _int(b['cherries']),
          ),
      ],
      luckyCoins: _int(l['coins']),
      luckyCherries: _int(l['cherries']),
      luckyGifts: _int(l['gifts']),
      luckyGivers: _int(l['givers']),
      luckySupporters: _supporters(l['topSupporters']),
      targets: targets is Map<String, dynamic>
          ? LiveHostTargets.fromJson(targets)
          : null,
    );
  }

  final HostStatsPeriod period;
  final int cherries;
  final int gifts;
  final int givers;
  final List<HostSupporter> topSupporters;
  final List<HostCherriesBucket> series;
  final int luckyCoins;

  /// D277: the cherries lucky gifts gave the host (self-sends included; 0
  /// from an older server).
  final int luckyCherries;
  final int luckyGifts;
  final int luckyGivers;
  final List<HostSupporter> luckySupporters;

  /// The day's targets (DAY only).
  final LiveHostTargets? targets;

  /// The end of the period (the countdown; not shown for ALL).
  final DateTime? to;
}

/// D199 «تارجت»: the host's daily targets and gift stats. Throws an
/// `AppFailure`.
abstract interface class LiveHostTargetsRepository {
  /// Null when [username] is not a host (or not visible to the caller).
  Future<LiveHostTargets?> targets(String username);

  /// The caller's own stats (a host).
  Future<HostGiftStats> mine(HostStatsPeriod period);
}

class LiveHostTargetsRepositoryImpl implements LiveHostTargetsRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<LiveHostTargets?> targets(String username) async {
    try {
      return await guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/live/hosts/${Uri.encodeComponent(username)}/targets',
        );
        return LiveHostTargets.fromJson(res.data!);
      });
    } on ServerFailure catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<HostGiftStats> mine(HostStatsPeriod period) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/me/host-gift-stats',
      queryParameters: {'period': period.wire},
    );
    return HostGiftStats.fromJson(res.data!);
  });
}

final liveHostTargetsRepositoryProvider = Provider<LiveHostTargetsRepository>(
  (ref) => LiveHostTargetsRepositoryImpl(ref.watch(apiDioProvider)),
);

/// The chip's data: a host's targets today (null: not a host; refreshed by
/// the chip every minute).
final FutureProviderFamily<LiveHostTargets?, String> liveHostTargetsProvider =
    FutureProvider.autoDispose.family(
      (ref, username) =>
          ref.watch(liveHostTargetsRepositoryProvider).targets(username),
    );
