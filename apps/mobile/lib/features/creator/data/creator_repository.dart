import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';

/// `CreatorStatsPeriod` (openapi v1.43-social, D164): rolling windows
/// ending now.
enum CreatorStatsPeriod {
  last7Days('LAST_7_DAYS'),
  last30Days('LAST_30_DAYS'),
  allTime('ALL_TIME');

  new(this.wire);

  final String wire;
}

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// `CreatorContentStats`: the posts (or reels) published in the period and
/// the numbers they have now.
@immutable
final class CreatorContentStats {
  const new({
    required this.published,
    required this.views,
    required this.likes,
    required this.comments,
    required this.shares,
  });

  factory fromJson(Map<String, dynamic> json) => CreatorContentStats(
    published: _int(json['published']),
    views: _int(json['views']),
    likes: _int(json['likes']),
    comments: _int(json['comments']),
    shares: _int(json['shares']),
  );

  final int published;
  final int views;
  final int likes;
  final int comments;
  final int shares;
}

/// The ended lives that started in the period (the data center's
/// summaries, §10.36).
@immutable
final class CreatorLiveStats {
  const new({
    required this.lives,
    required this.liveSeconds,
    required this.giftCount,
    required this.giftCoins,
    required this.earningsCoins,
    required this.newFollowers,
    required this.peakViewers,
  });

  factory fromJson(Map<String, dynamic> json) => CreatorLiveStats(
    lives: _int(json['lives']),
    liveSeconds: _int(json['liveSeconds']),
    giftCount: _int(json['giftCount']),
    giftCoins: _int(json['giftCoins']),
    earningsCoins: _int(json['earningsCoins']),
    newFollowers: _int(json['newFollowers']),
    peakViewers: _int(json['peakViewers']),
  );

  final int lives;
  final int liveSeconds;
  final int giftCount;
  final int giftCoins;
  final int earningsCoins;
  final int newFollowers;
  final int peakViewers;
}

/// `CreatorStats` (`GET /me/creator-stats`, D164, CONVENTIONS §10.40).
@immutable
final class CreatorStats {
  const new({
    required this.period,
    required this.followersTotal,
    required this.followersNew,
    required this.posts,
    required this.reels,
    required this.live,
  });

  factory fromJson(Map<String, dynamic> json) {
    final followers = json['followers']! as Map<String, dynamic>;
    return CreatorStats(
      period: CreatorStatsPeriod.values.firstWhere(
        (p) => p.wire == json['period'],
        orElse: () => CreatorStatsPeriod.allTime,
      ),
      followersTotal: _int(followers['total']),
      followersNew: (followers['newInPeriod'] as num?)?.toInt(),
      posts: CreatorContentStats.fromJson(
        json['posts']! as Map<String, dynamic>,
      ),
      reels: CreatorContentStats.fromJson(
        json['reels']! as Map<String, dynamic>,
      ),
      live: CreatorLiveStats.fromJson(json['live']! as Map<String, dynamic>),
    );
  }

  final CreatorStatsPeriod period;
  final int followersTotal;

  /// Follows made in the period that still stand; null for all time.
  final int? followersNew;
  final CreatorContentStats posts;
  final CreatorContentStats reels;
  final CreatorLiveStats live;
}

/// The creator center (openapi v1.43-social, D164). Throws an `AppFailure`.
abstract interface class CreatorRepository {
  Future<CreatorStats> mine(CreatorStatsPeriod period);
}

class CreatorRepositoryImpl implements CreatorRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<CreatorStats> mine(CreatorStatsPeriod period) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/me/creator-stats',
          queryParameters: {'period': period.wire},
        );
        return CreatorStats.fromJson(res.data!);
      });
}

final creatorRepositoryProvider = Provider<CreatorRepository>(
  (ref) => CreatorRepositoryImpl(ref.watch(apiDioProvider)),
);

/// The caller's creator statistics for one period.
final FutureProviderFamily<CreatorStats, CreatorStatsPeriod>
creatorStatsProvider = FutureProvider.autoDispose.family((ref, period) {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(creatorRepositoryProvider).mine(period);
});
