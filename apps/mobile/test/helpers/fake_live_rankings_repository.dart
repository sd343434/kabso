import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/live/data/live_rankings_repository.dart';

/// An in-memory [LiveRankingsRepository] (tests only): [boards] by period;
/// a missing one is an empty board of the current hour.
class FakeLiveRankingsRepository implements LiveRankingsRepository {
  new([Map<LiveRankingPeriod, LiveRankings>? boards]) : boards = boards ?? {};

  final Map<LiveRankingPeriod, LiveRankings> boards;
  final List<LiveRankingPeriod> calls = [];
  AppFailure? failure;

  @override
  Future<LiveRankings> board(LiveRankingPeriod period) async {
    calls.add(period);
    if (failure case final f?) throw f;
    final now = DateTime.now();
    return boards[period] ??
        LiveRankings(
          period: period,
          startsAt: now,
          endsAt: now.add(const Duration(minutes: 30)),
          entries: const [],
        );
  }
}
