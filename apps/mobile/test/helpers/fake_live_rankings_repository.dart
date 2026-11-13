import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/live/data/live_rankings_repository.dart';

/// An in-memory [LiveRankingsRepository] (tests only): [boards] (popularity),
/// [gameBoards] (D315) and [richBoards] (D320) by period; a missing one is an
/// empty board of the current hour.
class FakeLiveRankingsRepository implements LiveRankingsRepository {
  new([
    Map<LiveRankingPeriod, LiveRankings>? boards,
    this.gameBoards = const {},
    this.richBoards = const {},
  ]) : boards = boards ?? {};

  final Map<LiveRankingPeriod, LiveRankings> boards;
  final Map<LiveRankingPeriod, LiveRankings> gameBoards;

  /// D320: «الأغنى» boards by period.
  final Map<LiveRankingPeriod, LiveRankings> richBoards;
  final List<LiveRankingPeriod> calls = [];
  final List<LiveRankingBoard> boardCalls = [];
  AppFailure? failure;

  @override
  Future<LiveRankings> board(
    LiveRankingPeriod period, {
    LiveRankingBoard board = LiveRankingBoard.popularity,
  }) async {
    calls.add(period);
    boardCalls.add(board);
    if (failure case final f?) throw f;
    final now = DateTime.now();
    final source = switch (board) {
      LiveRankingBoard.games => gameBoards,
      LiveRankingBoard.rich => richBoards,
      LiveRankingBoard.popularity => boards,
    };
    return source[period] ??
        LiveRankings(
          period: period,
          startsAt: now,
          endsAt: now.add(const Duration(minutes: 30)),
          entries: const [],
        );
  }
}
