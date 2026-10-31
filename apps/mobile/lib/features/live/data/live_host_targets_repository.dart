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
/// «تارجت» chip — today's cherries (the «استقبل هدايا في بثك» band target
/// in cherries) and lucky-gift value (the «استقبل هدايا الحظ» target, in
/// coins), and today's supporters (D199b: up to 20 by cherries, the lucky
/// list by coins, the end of the day and a signed-in caller's own place).
@immutable
final class LiveHostTargets {
  const new({
    required this.day,
    required this.band,
    required this.cherries,
    required this.lucky,
    required this.topSupporters,
    this.endsAt,
    this.luckySupporters = const [],
    this.meCherries,
    this.meLucky,
  });

  factory fromJson(Map<String, dynamic> json) {
    final me = json['me'];
    final endsAt = json['endsAt'];
    return LiveHostTargets(
      day: json['day']! as String,
      band: _int(json['band']),
      cherries: HostTarget.fromJson(json['cherries']! as Map<String, dynamic>),
      lucky: HostTarget.fromJson(json['lucky']! as Map<String, dynamic>),
      topSupporters: _supporters(json['topSupporters']),
      endsAt: endsAt is String ? DateTime.parse(endsAt) : null,
      luckySupporters: _supporters(json['luckySupporters']),
      meCherries: me is Map<String, dynamic>
          ? HostSupporterRank.fromJson(me['cherries']! as Map<String, dynamic>)
          : null,
      meLucky: me is Map<String, dynamic>
          ? HostSupporterRank.fromJson(me['lucky']! as Map<String, dynamic>)
          : null,
    );
  }

  /// The Riyadh day (`YYYY-MM-DD`).
  final String day;
  final int band;
  final HostTarget cherries;
  final HostTarget lucky;

  /// Today's cherries list.
  final List<HostSupporter> topSupporters;

  /// The end of the Riyadh day (the countdown; null from an older server).
  final DateTime? endsAt;

  /// Today's lucky list.
  final List<HostSupporter> luckySupporters;

  /// The signed-in caller's own place today (null for guests and the host).
  final HostSupporterRank? meCherries;
  final HostSupporterRank? meLucky;
}

/// One bucket of the cherries series (an hour, a day or a month, local).
@immutable
final class HostCherriesBucket {
  const new({required this.start, required this.cherries});

  final DateTime start;
  final int cherries;
}

/// `HostGiftStats` (`GET /me/host-gift-stats?period=`): the host's own
/// cherries and lucky-gift numbers for a period.
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
