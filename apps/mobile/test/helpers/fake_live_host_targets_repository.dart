// In-memory host targets and gift stats (D199 «تارجت», tests only). By
// default nobody is a host (no chip), so the room goldens stay as they were.

import 'package:kabso_live/features/live/data/live_host_targets_repository.dart';

class FakeLiveHostTargetsRepository implements LiveHostTargetsRepository {
  new({
    Map<String, LiveHostTargets>? byHost,
    Map<HostStatsPeriod, HostGiftStats>? stats,
  }) : byHost = byHost ?? {},
       stats = stats ?? {};

  final Map<String, LiveHostTargets> byHost;
  final Map<HostStatsPeriod, HostGiftStats> stats;
  final List<String> askedTargets = [];
  final List<HostStatsPeriod> askedStats = [];

  /// D214 tests: while set, `targets` waits for it (the data still loading).
  Future<void>? hold;

  static HostGiftStats empty(HostStatsPeriod period) => HostGiftStats(
    period: period,
    cherries: 0,
    gifts: 0,
    givers: 0,
    topSupporters: const [],
    series: const [],
    luckyCoins: 0,
    luckyGifts: 0,
    luckyGivers: 0,
    luckySupporters: const [],
  );

  @override
  Future<LiveHostTargets?> targets(String username) async {
    askedTargets.add(username);
    if (hold case final wait?) await wait;
    return byHost[username];
  }

  @override
  Future<HostGiftStats> mine(HostStatsPeriod period) async {
    askedStats.add(period);
    return stats[period] ?? empty(period);
  }
}
