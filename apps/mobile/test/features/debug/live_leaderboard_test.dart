// D84: the leaderboard's countdown, directions and narrow phones.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/debug/live_leaderboard.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  test('the countdown reads like the reference', () {
    expect(
      LeaderboardCountdown.format(const Duration(minutes: 5, seconds: 50)),
      '05M 50S',
    );
    expect(
      LeaderboardCountdown.format(const Duration(hours: 7, minutes: 12)),
      '07H 12M',
    );
    expect(
      LeaderboardCountdown.format(const Duration(days: 3, hours: 4)),
      '03D 04H',
    );
    expect(LeaderboardCountdown.format(const Duration(seconds: -3)), '00M 00S');
    expect(countryFlag('jo'), '\u{1F1EF}\u{1F1F4}');
  });

  testWidgets('the countdown follows its end time, second by second', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 20, 12);
    await pumpScreen(
      tester,
      Scaffold(
        body: LeaderboardCountdown(
          endsAt: now.add(const Duration(minutes: 5, seconds: 50)),
          now: () => now,
          onPrevious: null,
          onNext: () {},
          onInfo: () {},
        ),
      ),
    );
    String shown() => tester
        .widget<Text>(find.byKey(LeaderboardCountdown.valueKey))
        .textSpan!
        .toPlainText();
    expect(shown(), contains('05M 50S'));
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(shown(), contains('05M 49S'));
    // No previous period: that chevron is off.
    expect(
      tester
          .widget<IconButton>(find.byKey(LeaderboardCountdown.previousKey))
          .onPressed,
      isNull,
    );
  });

  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;
    testWidgets('${language.name}: the hour sits at the reading start, the '
        'podium keeps 2-1-3, nothing overflows at 360 and 1.3×', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 800 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpScreen(
        tester,
        Scaffold(
          body: LiveLeaderboard(
            viewers: liveViewersFixture(ar: ar),
            period: LiveRankingPeriod.hourly,
            filter: LiveViewersFilter.attraction,
            endsAt: DateTime.now().add(const Duration(minutes: 5)),
            onPeriod: (_) {},
            onFilter: (_) {},
            onGiftFilter: () {},
            onInfo: () {},
            onOpen: (_) {},
          ),
        ),
        language: language,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      double x(Key key) => tester.getCenter(find.byKey(key)).dx;
      final hour = x(LeaderboardPeriodBar.periodKey(LiveRankingPeriod.hourly));
      final month = x(
        LeaderboardPeriodBar.periodKey(LiveRankingPeriod.monthly),
      );
      expect(hour > month, ar);
      final first = x(LeaderboardPodium.placeKey(1));
      expect(x(LeaderboardPodium.placeKey(2)), lessThan(first));
      expect(x(LeaderboardPodium.placeKey(3)), greaterThan(first));
    });
  }
}
