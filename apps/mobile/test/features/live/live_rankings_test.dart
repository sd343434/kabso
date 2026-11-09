// CP-016 A (D99): the popularity board sheet — podium, rows, the periods,
// the countdown, the host's own row, empty and error states. D314: this month
// and this year; D315: the «مجنون اللعب» tab only while games are on.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_rankings_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_rankings_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_rankings_repository.dart';
import '../../helpers/fake_live_repository.dart';
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
  FakeLiveRankingsRepository repo, {
  bool gamesEnabled = false,
  AppLanguage language = AppLanguage.en,
}) async {
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
    liveRankingsRepository: repo,
    language: language,
    overrides: [
      currentUserProvider.overrideWithValue(testUser().copyWith(canHost: true)),
      // D315: `LiveConfig.gamesEnabled` gates «مجنون اللعب».
      liveRepositoryProvider.overrideWithValue(
        FakeLiveRepository()..gamesEnabled = gamesEnabled,
      ),
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
    // The points mark (D259: points never wear the cherry; the flame stays
    // replaced, owner 2026-10-25).
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
    // D320: «الأغنى» is a real tab now (no "Soon").
    expect(
      find.byKey(LiveRankingsKeys.tab(LiveRankingBoard.rich)),
      findsOneWidget,
    );
    expect(find.text(l10n.liveSoon), findsNothing);
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

  testWidgets('D314: this month and this year load their own boards', (
    tester,
  ) async {
    final repo = await _open(
      tester,
      FakeLiveRankingsRepository({
        LiveRankingPeriod.month: _board(LiveRankingPeriod.month, [
          _e(1, 'Ward', 4200),
        ]),
        LiveRankingPeriod.year: _board(LiveRankingPeriod.year, [
          _e(1, 'Malik', 88000),
          _e(2, 'Ward', 4200),
        ]),
      }),
    );
    final l10n = _l10n(tester);
    for (final label in [
      l10n.liveRankHour,
      l10n.liveRankDay,
      l10n.liveRankWeek,
      l10n.liveRankMonth,
      l10n.liveRankYear,
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    for (final p in [LiveRankingPeriod.month, LiveRankingPeriod.year]) {
      await tester.ensureVisible(find.byKey(LiveRankingsKeys.period(p)));
      await tester.tap(find.byKey(LiveRankingsKeys.period(p)));
      await tester.pumpAndSettle();
    }
    expect(repo.calls, [
      LiveRankingPeriod.hour,
      LiveRankingPeriod.month,
      LiveRankingPeriod.year,
    ]);
    expect(repo.boardCalls.toSet(), {LiveRankingBoard.popularity});
    expect(find.byKey(LiveRankingsKeys.entry('u1')), findsOneWidget);
    expect(find.byKey(LiveRankingsKeys.entry('u2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('D315: no «مجنون اللعب» tab while no game is on', (tester) async {
    final repo = await _open(tester, FakeLiveRankingsRepository());
    final l10n = _l10n(tester);
    expect(
      find.byKey(LiveRankingsKeys.tab(LiveRankingBoard.games)),
      findsNothing,
    );
    expect(find.text(l10n.liveRankGames), findsNothing);
    expect(repo.boardCalls, [LiveRankingBoard.popularity]);
  });

  testWidgets('D315: «مجنون اللعب» ranks players by tickets spent, with the '
      'ticket beside each and the caller pinned', (tester) async {
    final repo = await _open(
      tester,
      FakeLiveRankingsRepository(
        {
          LiveRankingPeriod.hour: _board(LiveRankingPeriod.hour, [
            _e(1, 'Ward', 94),
          ]),
        },
        {
          LiveRankingPeriod.hour: _board(
            LiveRankingPeriod.hour,
            [
              _e(1, 'Gamer', 12500),
              _e(2, 'Malik', 900),
              _e(3, 'Nour', 300),
              _e(4, 'Sara', 40),
            ],
            host: true,
            myRank: 7,
            myPoints: 15,
          ),
          LiveRankingPeriod.year: _board(LiveRankingPeriod.year, [
            _e(1, 'Gamer', 125000),
          ]),
        },
      ),
      gamesEnabled: true,
    );
    final l10n = _l10n(tester);
    final tab = find.byKey(LiveRankingsKeys.tab(LiveRankingBoard.games));
    expect(tab, findsOneWidget);
    expect(find.text(l10n.liveRankGames), findsOneWidget);
    await tester.tap(tab);
    await tester.pumpAndSettle();
    expect(repo.boardCalls.last, LiveRankingBoard.games);
    for (final id in ['u1', 'u2', 'u3', 'u4']) {
      expect(
        find.descendant(
          of: find.byKey(LiveRankingsKeys.entry(id)),
          matching: find.byWidgetPredicate(
            (w) => w is KabsoArtIcon && w.art == KabsoArt.ticket,
          ),
        ),
        findsOneWidget,
      );
    }
    expect(find.byType(KPointsIcon), findsNothing);
    expect(
      find.bySemanticsLabel(
        l10n.liveRankRow(4, 'Sara', l10n.liveRankTickets('40')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(LiveRankingsKeys.me),
        matching: find.text('7'),
      ),
      findsOneWidget,
    );
    // The same five periods on this board.
    final year = find.byKey(LiveRankingsKeys.period(LiveRankingPeriod.year));
    await tester.ensureVisible(year);
    await tester.tap(year);
    await tester.pumpAndSettle();
    expect(repo.calls.last, LiveRankingPeriod.year);
    expect(repo.boardCalls.last, LiveRankingBoard.games);
    expect(find.byKey(LiveRankingsKeys.entry('u1')), findsOneWidget);
    expect(find.byKey(LiveRankingsKeys.me), findsNothing);
    // Back to popularity: points again.
    await tester.tap(
      find.byKey(LiveRankingsKeys.tab(LiveRankingBoard.popularity)),
    );
    await tester.pumpAndSettle();
    expect(repo.boardCalls.last, LiveRankingBoard.popularity);
    expect(find.text(l10n.liveRankEmpty), findsOneWidget);
  });

  testWidgets('D315: an empty games board says so (Arabic, 360 pt)', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _open(
      tester,
      FakeLiveRankingsRepository(),
      gamesEnabled: true,
      language: AppLanguage.ar,
    );
    expect(find.text('مجنون اللعب'), findsOneWidget);
    expect(find.text('هذا الشهر'), findsOneWidget);
    await tester.ensureVisible(find.text('مجنون اللعب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مجنون اللعب'));
    await tester.pumpAndSettle();
    expect(find.text(_l10n(tester).liveRankGamesEmpty), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('D320: «الأغنى» ranks senders by coins, the coin beside each, '
      'the caller pinned; the five periods', (tester) async {
    final repo = await _open(
      tester,
      FakeLiveRankingsRepository(null, const {}, {
        LiveRankingPeriod.hour: _board(
          LiveRankingPeriod.hour,
          [
            _e(1, 'Sultan', 2500000),
            _e(2, 'Malik', 90000),
            _e(3, 'Nour', 3000),
            _e(4, 'Sara', 400),
          ],
          host: true,
          myRank: 31,
          myPoints: 20,
        ),
        LiveRankingPeriod.year: _board(LiveRankingPeriod.year, [
          _e(1, 'Sultan', 99000000),
        ]),
      }),
    );
    final l10n = _l10n(tester);
    await tester.tap(find.byKey(LiveRankingsKeys.tab(LiveRankingBoard.rich)));
    await tester.pumpAndSettle();
    expect(repo.boardCalls.last, LiveRankingBoard.rich);
    for (final id in ['u1', 'u2', 'u3', 'u4']) {
      expect(
        find.descendant(
          of: find.byKey(LiveRankingsKeys.entry(id)),
          matching: find.byWidgetPredicate(
            (w) => w is KabsoArtIcon && w.art == KabsoArt.coin,
          ),
        ),
        findsOneWidget,
      );
    }
    expect(find.byType(KPointsIcon), findsNothing);
    expect(
      find.bySemanticsLabel(
        l10n.liveRankRow(4, 'Sara', l10n.liveRankCoins('400')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(LiveRankingsKeys.me),
        matching: find.text('31'),
      ),
      findsOneWidget,
    );
    final year = find.byKey(LiveRankingsKeys.period(LiveRankingPeriod.year));
    await tester.ensureVisible(year);
    await tester.tap(year);
    await tester.pumpAndSettle();
    expect(repo.calls.last, LiveRankingPeriod.year);
    expect(repo.boardCalls.last, LiveRankingBoard.rich);
    expect(find.byKey(LiveRankingsKeys.entry('u1')), findsOneWidget);
  });

  testWidgets('D320: an empty «الأغنى» says so (Arabic, 360 pt, with the '
      'games tab too)', (tester) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _open(
      tester,
      FakeLiveRankingsRepository(),
      gamesEnabled: true,
      language: AppLanguage.ar,
    );
    await tester.tap(find.text('الأغنى'));
    await tester.pumpAndSettle();
    expect(find.text(_l10n(tester).liveRankRichEmpty), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
