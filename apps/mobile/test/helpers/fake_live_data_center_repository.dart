// In-memory data center (D154d, tests only).

import 'package:kabso_live/features/live/data/live_data_center_repository.dart';

class FakeLiveDataCenterRepository implements LiveDataCenterRepository {
  new({Map<LiveStatsPeriod, MyLiveStats>? stats}) : stats = stats ?? {};

  final Map<LiveStatsPeriod, MyLiveStats> stats;
  final List<LiveStatsPeriod> asked = [];

  static MyLiveStats empty(LiveStatsPeriod period) => MyLiveStats(
    period: period,
    lives: 0,
    liveSeconds: 0,
    giftCount: 0,
    giftCoins: 0,
    earningsCoins: 0,
    newFollowers: 0,
    uniqueViewers: 0,
    peakViewers: 0,
    series: const [],
    heatmap: const [],
  );

  @override
  Future<MyLiveStats> mine(LiveStatsPeriod period) async {
    asked.add(period);
    return stats[period] ?? empty(period);
  }
}
