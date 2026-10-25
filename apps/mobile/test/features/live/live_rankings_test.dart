// CP-016 A (D99): the popularity board sheet — podium, rows, the periods,
// the countdown, the host's own row, empty and error states.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_rankings_repository.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_rankings_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_rankings_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

LiveRankingEntry _e(int rank, String name, int points, {bool live = false}) =>
    LiveRankingEntry(
      rank: rank,
      host: UserSummary(
        id: 'u$rank',
        username: name.toLowerCase(),
        displayName: name,
        avatarUrl: null,
      ),
      points: points,
      liveRoomId: live ? 'room-$rank' : null,
      liveTitle: live ? 'Live of $name' : null,
    );

LiveRankings _board(
  LiveRankingPeriod p,
  List<LiveRankingEntry> entries, {
  bool host = false,
  int? myRank,
  int myPoints = 0,
}) => LiveRankings(
  period: p,
  startsAt: DateTime.now(),
  endsAt: DateTime.now().add(const Duration(hours: 2, minutes: 4, seconds: 30)),
  entries: entries,
  isHost: host,
  myRank: myRank,
  myPoints: myPoints,
);

Future<FakeLiveRankingsRepository> _open(
  WidgetTester tester,
  FakeLiveRankingsRepository repo,
) async {
  await pumpScreen(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showLiveRankings(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    overrides: [
      liveRankingsRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWithValue(testUser().copyWith(canHost: true)),
    ],
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repo;
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byKey(LiveRankingsKeys.sheet)));

void main() {
  testWidgets('podium, rows, LIVE, the countdown and the host row', (
    tester,
  ) async {
    final repo = await _open(
      tester,
      FakeLiveRankingsRepository({
        LiveRankingPeriod.hour: _board(
          LiveRankingPeriod.hour,
          [
            _e(1, 'Ward', 94, live: true),
            _e(2, 'Malik', 39),
            _e(3, 'Nour', 32),
            _e(4, 'Sara', 16),
          ],
          host: true,
          myRank: 12,
          myPoints: 3,
        ),
      }),
    );
    final l10n = _l10n(tester);
    expect(repo.calls, [LiveRankingPeriod.hour]);
    for (final id in ['u1', 'u2', 'u3', 'u4']) {
      expect(find.byKey(LiveRankingsKeys.entry(id)), findsOneWidget);
    }
    expect(find.text(l10n.liveRankLive), findsOneWidget);
    // The owner's frame for each of the top three; none for rank 4.
    for (final rank in [1, 2, 3]) {
      expect(
        find.descendant(
          of: find.byKey(LiveRankingsKeys.entry('u$rank')),
          matching: find.image(
            AssetImage('assets/live_rank_frames/frame_$rank.webp'),
          ),
        ),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(
        of: find.byKey(LiveRankingsKeys.entry('u4')),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName.contains('live_rank_frames'),
        ),
      ),
      findsNothing,
    );
    // The points coin replaces the flame (owner, 2026-10-25).
    expect(
      find.descendant(
        of: find.byKey(LiveRankingsKeys.entry('u4')),
        matching: find.byType(KPointsIcon),
      ),
      findsOneWidget,
    );
    expect(find.text('Countdown: 00d 02h 04m'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(LiveRankingsKeys.me),
        matching: find.text('12'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('${l10n.liveRankRich}, ${l10n.liveSoon}'),
      findsOneWidget,
    );
  });

  testWidgets('periods load their board; empty says so; no host row for '
      'a viewer', (tester) async {
    final repo = await _open(
      tester,
      FakeLiveRankingsRepository({
        LiveRankingPeriod.week: _board(LiveRankingPeriod.week, [
          _e(1, 'Ward', 900),
        ]),
      }),
    );
    final l10n = _l10n(tester);
    expect(find.text(l10n.liveRankEmpty), findsOneWidget);
    await tester.tap(
      find.byKey(LiveRankingsKeys.period(LiveRankingPeriod.week)),
    );
    await tester.pumpAndSettle();
    expect(repo.calls, [LiveRankingPeriod.hour, LiveRankingPeriod.week]);
    expect(find.byKey(LiveRankingsKeys.entry('u1')), findsOneWidget);
    expect(find.byKey(LiveRankingsKeys.me), findsNothing);
  });

  testWidgets('an error says why', (tester) async {
    final repo = FakeLiveRankingsRepository()
      ..failure = const ServerFailure(
        code: ErrorCode.internalError,
        rawCode: 'INTERNAL_ERROR',
        debugMessage: 'x',
        statusCode: 500,
      );
    await _open(tester, repo);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text(failureMessage(_l10n(tester), repo.failure!)),
      findsOneWidget,
    );
  });
}
