// D85: the live header's "Ranking list" — the room's host among all hosts
// this hour, today, this month and of all time.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/debug/live_host_ranking_sheet.dart';
import 'package:kabso_live/features/debug/live_leaderboard.dart';
import 'package:kabso_live/features/debug/live_preview_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;
    testWidgets('${language.name}: the chip opens the hosts ranking', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(393 * 3, 852 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final l10n = l10nFor(language);
      await pumpScreen(tester, const LivePreviewScreen(), language: language);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text(l10n.liveRankingList), findsOneWidget);
      await tester.tap(find.byKey(LivePreviewScreen.rankKey));
      await _frames(tester);
      expect(find.byKey(LiveHostRankingSheet.sheetKey), findsOneWidget);
      // Hour, day, month, all time — no week, no gift systems.
      for (final p in LiveRankingPeriod.hostPeriods) {
        expect(find.byKey(LeaderboardPeriodBar.periodKey(p)), findsOneWidget);
      }
      expect(
        find.byKey(LeaderboardPeriodBar.periodKey(LiveRankingPeriod.weekly)),
        findsNothing,
      );
      expect(find.byType(LeaderboardGiftFilters), findsNothing);
      final host = ar ? 'سارة (تجربة)' : 'Sara (test)';
      String place() => tester
          .widget<Text>(
            find
                .descendant(
                  of: find.byKey(LiveHostRankingSheet.placeKey),
                  matching: find.byType(Text),
                )
                .first,
          )
          .data!;
      // This hour the host is third, on the podium.
      expect(place(), '3');
      expect(find.bySemanticsLabel('3. $host'), findsOneWidget);
      // Today 7th, a row.
      await tester.tap(
        find.byKey(LeaderboardPeriodBar.periodKey(LiveRankingPeriod.daily)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(place(), '7');
      expect(
        tester
            .widget<LeaderboardRow>(find.byKey(LiveLeaderboard.rowKey(7)))
            .viewer
            .name,
        host,
      );
      // This month 12th: outside the top ten, still pinned below.
      await tester.tap(
        find.byKey(LeaderboardPeriodBar.periodKey(LiveRankingPeriod.monthly)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(place(), '12');
      // All time has no countdown, and no next period.
      await tester.tap(find.byKey(LeaderboardCountdown.nextKey));
      await tester.pump(const Duration(milliseconds: 300));
      expect(place(), '13');
      expect(find.text(l10n.liveRankingAllTime), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(LeaderboardCountdown.nextKey))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the list shows the top 100, no more', (tester) async {
    tester.view
      ..physicalSize = const Size(393 * 3, 852 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpScreen(
      tester,
      Scaffold(
        body: LiveHostRankingSheet(
          hosts: [
            ...liveHostsFixture(
              ar: false,
              hostName: 'Sara (test)',
              hostUsername: 'test_host_sara',
            ),
            // One more than fits: it must not be listed.
            ...liveHostsFixture(
              ar: false,
              hostName: 'Extra (test)',
              hostUsername: 'test_host_extra',
            ).take(1),
          ],
          hostUsername: 'test_host_sara',
        ),
      ),
    );
    await tester.pump();
    final list = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.byKey(LiveLeaderboard.rowKey(100)),
      600,
      scrollable: list,
    );
    expect(find.byKey(LiveLeaderboard.rowKey(100)), findsOneWidget);
    await tester.drag(list, const Offset(0, -2000));
    await tester.pump();
    expect(find.byKey(LiveLeaderboard.rowKey(101)), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
