import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:material_ui/material_ui.dart' show immutable;

/// `LiveStatsPeriod` (v1.35-live, D154d, §10.36).
enum LiveStatsPeriod {
  day('DAY'),
  week('WEEK'),
  month('MONTH'),
  year('YEAR');

  new(this.wire);

  final String wire;
}

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// One bucket of the series (an hour, a day or a month, local time).
@immutable
final class LiveStatsBucket {
  const new({
    required this.start,
    required this.liveSeconds,
    required this.earningsCoins,
    required this.newFollowers,
  });

  factory fromJson(Map<String, dynamic> json) => LiveStatsBucket(
    start: DateTime.parse(json['start']! as String),
    liveSeconds: _int(json['liveSeconds']),
    earningsCoins: _int(json['earningsCoins']),
    newFollowers: _int(json['newFollowers']),
  );

  /// The bucket's local wall-clock start (no time zone).
  final DateTime start;
  final int liveSeconds;
  final int earningsCoins;
  final int newFollowers;
}

/// One cell of the best hours: lives started on [weekday] (1 Monday … 7
/// Sunday) at [hour], and their viewers.
@immutable
final class LiveStatsHeatCell {
  const new({
    required this.weekday,
    required this.hour,
    required this.lives,
    required this.viewers,
  });

  factory fromJson(Map<String, dynamic> json) => LiveStatsHeatCell(
    weekday: _int(json['weekday']),
    hour: _int(json['hour']),
    lives: _int(json['lives']),
    viewers: _int(json['viewers']),
  );

  final int weekday;
  final int hour;
  final int lives;
  final int viewers;
}

/// `MyLiveStats` (`GET /live/stats/me?period=`).
@immutable
final class MyLiveStats {
  const new({
    required this.period,
    required this.lives,
    required this.liveSeconds,
    required this.giftCount,
    required this.giftCoins,
    required this.earningsCoins,
    required this.newFollowers,
    required this.uniqueViewers,
    required this.peakViewers,
    required this.series,
    required this.heatmap,
  });

  factory fromJson(Map<String, dynamic> json) {
    final t = json['totals']! as Map<String, dynamic>;
    return MyLiveStats(
      period: LiveStatsPeriod.values.firstWhere(
        (p) => p.wire == json['period'],
        orElse: () => LiveStatsPeriod.day,
      ),
      lives: _int(t['lives']),
      liveSeconds: _int(t['liveSeconds']),
      giftCount: _int(t['giftCount']),
      giftCoins: _int(t['giftCoins']),
      earningsCoins: _int(t['earningsCoins']),
      newFollowers: _int(t['newFollowers']),
      uniqueViewers: _int(t['uniqueViewers']),
      peakViewers: _int(t['peakViewers']),
      series: [
        for (final b in json['series']! as List<dynamic>)
          LiveStatsBucket.fromJson(b as Map<String, dynamic>),
      ],
      heatmap: [
        for (final c in json['heatmap']! as List<dynamic>)
          LiveStatsHeatCell.fromJson(c as Map<String, dynamic>),
      ],
    );
  }

  final LiveStatsPeriod period;
  final int lives;
  final int liveSeconds;
  final int giftCount;
  final int giftCoins;
  final int earningsCoins;
  final int newFollowers;
  final int uniqueViewers;
  final int peakViewers;
  final List<LiveStatsBucket> series;
  final List<LiveStatsHeatCell> heatmap;
}

/// The host's data center (v1.35-live, D154d). Throws an `AppFailure`.
abstract interface class LiveDataCenterRepository {
  Future<MyLiveStats> mine(LiveStatsPeriod period);
}

class LiveDataCenterRepositoryImpl implements LiveDataCenterRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<MyLiveStats> mine(LiveStatsPeriod period) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/live/stats/me',
      queryParameters: {'period': period.wire},
    );
    return MyLiveStats.fromJson(res.data!);
  });
}

final liveDataCenterRepositoryProvider = Provider<LiveDataCenterRepository>(
  (ref) => LiveDataCenterRepositoryImpl(ref.watch(apiDioProvider)),
);
