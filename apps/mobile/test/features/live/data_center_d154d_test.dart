// D154d («مركز البيانات», CONVENTIONS §10.36): the host's data center sheet
// — the period switch, the totals, the chart and the best hours, the empty
// period — and the end-of-live screen's gifts' value and earnings, Arabic
// RTL and English at 360×800.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/data/live_data_center_repository.dart';
import 'package:kabso_live/features/live/domain/live_room_stats.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_data_center_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_data_center_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _open = Key('test.openData');

class _Opener extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: _open,
        onPressed: () => unawaited(showLiveDataCenter(context)),
        child: const SizedBox.square(dimension: 40),
      ),
    ),
  );
}

MyLiveStats _week() => MyLiveStats.fromJson({
  'period': 'WEEK',
  'totals': const {
    'lives': 3,
    'liveSeconds': 9000,
    'giftCount': 12,
    'giftCoins': 15400,
    'earningsCoins': 9100,
    'newFollowers': 7,
    'uniqueViewers': 240,
    'peakViewers': 60,
  },
  'series': [
    for (var d = 22; d <= 28; d++)
      {
        'start': '2026-10-${d}T00:00',
        'liveSeconds': d.isEven ? 3000 : 0,
        'earningsCoins': d.isEven ? 3000 : 0,
        'newFollowers': 1,
      },
  ],
  'heatmap': const [
    {'weekday': 5, 'hour': 21, 'lives': 2, 'viewers': 200},
    {'weekday': 1, 'hour': 9, 'lives': 1, 'viewers': 40},
  ],
});

Future<FakeLiveDataCenterRepository> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  FakeLiveDataCenterRepository? repo,
}) async {
  setViewport(tester, GoldenViewport.android);
  final data =
      repo ??
      FakeLiveDataCenterRepository(stats: {LiveStatsPeriod.week: _week()});
  await pumpScreen(
    tester,
    const _Opener(),
    language: language,
    liveDataCenterRepository: data,
  );
  await tester.tap(find.byKey(_open));
  await tester.pumpAndSettle();
  return data;
}

void main() {
  for (final language in AppLanguage.values) {
    testWidgets('the week: totals, the chart and the best hours '
        '(${language.name})', (tester) async {
      final repo = await _pump(tester, language: language);
      final ar = language == AppLanguage.ar;
      expect(repo.asked, [LiveStatsPeriod.week]);
      expect(find.text(ar ? '2 س 30 د' : '2 h 30 min'), findsOneWidget);
      expect(find.text('9,100'), findsOneWidget);
      expect(find.text('15,400'), findsOneWidget);
      expect(find.byKey(LiveDataCenterSheet.chartKey), findsOneWidget);
      expect(find.byKey(LiveDataCenterSheet.heatmapKey), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          ar ? 'أفضل وقت: جمعة الساعة 21' : 'Best time: Fri at 21:00',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('switching the period loads it; an empty one says so', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await tester.tap(
      find.byKey(LiveDataCenterSheet.periodKey(LiveStatsPeriod.year)),
    );
    await tester.pumpAndSettle();
    expect(repo.asked, [LiveStatsPeriod.week, LiveStatsPeriod.year]);
    expect(find.byKey(LiveDataCenterSheet.emptyKey), findsOneWidget);
    expect(find.byKey(LiveDataCenterSheet.chartKey), findsNothing);
  });

  test("the end-of-live statistics read the gifts' value and earnings", () {
    final stats = LiveRoomStats.fromJson(const {
      'roomId': 'r',
      'status': 'ENDED',
      'startedAt': '2026-10-28T10:00:00.000Z',
      'endedAt': '2026-10-28T11:00:00.000Z',
      'durationSeconds': 3600,
      'score': {'total': 0, 'tapPoints': 0, 'supportPoints': 0},
      'hostOwnPoints': 0,
      'supporters': 0,
      'topSupporters': <Object?>[],
      'giftCount': 2,
      'giftCoins': 109,
      'earningsCoins': 55,
      'chatMessages': 0,
      'newFollowers': 1,
      'viewers': null,
      'viewerCountries': <Object?>[],
    });
    expect(stats.giftCoins, 109);
    expect(stats.earningsCoins, 55);
  });
}
