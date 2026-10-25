import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';

/// `LiveRankingPeriod` (CP-016 A).
enum LiveRankingPeriod {
  hour('HOUR'),
  day('DAY'),
  week('WEEK');

  new(this.wire);
  final String wire;
}

/// `LiveRankingEntry`: a host on the board, with their live now, if any.
@immutable
class LiveRankingEntry {
  const new({
    required this.rank,
    required this.host,
    required this.points,
    this.liveRoomId,
    this.liveTitle,
    this.coverUrl,
  });

  factory fromJson(Map<String, dynamic> json) {
    final live = json['liveRoom'] as Map<String, dynamic>?;
    return LiveRankingEntry(
      rank: json['rank']! as int,
      host: UserSummary.fromJson(json['host']! as Map<String, dynamic>),
      points: json['points']! as int,
      liveRoomId: live?['id'] as String?,
      liveTitle: live?['title'] as String?,
      coverUrl: live?['coverUrl'] as String?,
    );
  }

  final int rank;
  final UserSummary host;
  final int points;
  final String? liveRoomId;
  final String? liveTitle;
  final String? coverUrl;

  bool get isLive => liveRoomId != null;
}

/// `LiveRankings`: the board of the current window; [myRank] / [myPoints]
/// only for a signed-in host ([isHost]).
@immutable
class LiveRankings {
  const new({
    required this.period,
    required this.startsAt,
    required this.endsAt,
    required this.entries,
    this.isHost = false,
    this.myRank,
    this.myPoints = 0,
  });

  factory fromJson(Map<String, dynamic> json) {
    final me = json['me'] as Map<String, dynamic>?;
    return LiveRankings(
      period: LiveRankingPeriod.values.firstWhere(
        (p) => p.wire == json['period'],
        orElse: () => LiveRankingPeriod.hour,
      ),
      startsAt: DateTime.parse(json['startsAt']! as String),
      endsAt: DateTime.parse(json['endsAt']! as String),
      entries: [
        for (final e in json['data']! as List<dynamic>)
          LiveRankingEntry.fromJson(e as Map<String, dynamic>),
      ],
      isHost: me != null,
      myRank: me?['rank'] as int?,
      myPoints: (me?['points'] as int?) ?? 0,
    );
  }

  final LiveRankingPeriod period;
  final DateTime startsAt;
  final DateTime endsAt;
  final List<LiveRankingEntry> entries;
  final bool isHost;
  final int? myRank;
  final int myPoints;
}

/// The popularity board (CP-016 A, CONVENTIONS §10.15). Throws an
/// `AppFailure`.
abstract interface class LiveRankingsRepository {
  /// `GET /live/rankings?period=…`.
  Future<LiveRankings> board(LiveRankingPeriod period);
}

class LiveRankingsRepositoryImpl implements LiveRankingsRepository {
  new(this._api);

  final Dio _api;

  @override
  Future<LiveRankings> board(LiveRankingPeriod period) =>
      guardApiCall(() async {
        final res = await _api.get<Map<String, dynamic>>(
          '/live/rankings',
          queryParameters: {'period': period.wire},
        );
        return LiveRankings.fromJson(res.data!);
      });
}

final liveRankingsRepositoryProvider = Provider<LiveRankingsRepository>(
  (ref) => LiveRankingsRepositoryImpl(ref.watch(apiDioProvider)),
);

/// The board of [LiveRankingPeriod] (reloaded when invalidated or when its
/// window ends).
final FutureProviderFamily<LiveRankings, LiveRankingPeriod>
liveRankingsProvider = FutureProvider.autoDispose
    .family<LiveRankings, LiveRankingPeriod>(
      (ref, period) => ref.watch(liveRankingsRepositoryProvider).board(period),
    );
