// D259 (owner: «عرض الكرز الحقيقي في حبّة المضيف، وتبقى النقاط للترتيب وPK
// فقط بدون أيقونة الكرز»): the host pill shows the real cherries the host
// earned in this live (`LiveScore.hostCherries`), not the score's points
// (100 a gift coin); points never wear the cherry.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/domain/live_room_stats.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/golden.dart';

Map<String, dynamic> _stats(Map<String, dynamic> score) => {
  'roomId': 'room-0',
  'status': 'ENDED',
  'startedAt': '2026-11-04T10:00:00Z',
  'endedAt': '2026-11-04T11:00:00Z',
  'durationSeconds': 3600,
  'score': score,
  'hostOwnPoints': 0,
  'supporters': 1,
  'topSupporters': <Object>[],
  'giftCount': 1,
  'chatMessages': 0,
  'newFollowers': 0,
  'viewerCountries': <Object>[],
};

const _pillKey = Key('d259.pill');

Future<void> _pumpPill(WidgetTester tester, AppLanguage language) => pumpGolden(
  tester,
  Center(
    child: RepaintBoundary(
      key: _pillKey,
      child: ColoredBox(
        color: const Color(0xFF1E2A38),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Builder(
            builder: (context) => KHostPill(
              hostName: language == AppLanguage.ar ? 'ليلى' : 'Layla',
              // 50 coins of gifts: 5 000 points, 325 cherries for the host.
              lines: KHostPill.pointLines(context, cherries: 325, taps: 12),
            ),
          ),
        ),
      ),
    ),
  ),
  language: language,
);

void main() {
  test('LiveScore.hostCherries: read, and 0 from an older server', () {
    final score = LiveScore.fromJson(const {
      'total': 5000,
      'tapPoints': 0,
      'supportPoints': 5000,
      'hostCherries': 325,
    });
    expect(score.hostCherries, 325);
    expect(
      LiveScore.fromJson(const {
        'total': 5000,
        'tapPoints': 0,
        'supportPoints': 5000,
      }).hostCherries,
      0,
    );
  });

  test('LiveRoomStats.hostCherries: read, and 0 from an older server', () {
    final s = LiveRoomStats.fromJson(
      _stats({
        'total': 5000,
        'tapPoints': 0,
        'supportPoints': 5000,
        'hostCherries': 325,
      }),
    );
    expect((s.total, s.hostCherries), (5000, 325));
    expect(
      LiveRoomStats.fromJson(
        _stats({'total': 5000, 'tapPoints': 0, 'supportPoints': 5000}),
      ).hostCherries,
      0,
    );
  });

  testWidgets('the host pill: the cherries with the cherry, never the score', (
    tester,
  ) async {
    await _pumpPill(tester, AppLanguage.en);
    expect(find.text(KFormat.bidiIsolate('325')), findsOneWidget);
    expect(find.text(KFormat.bidiIsolate('5,000')), findsNothing);
    expect(find.byType(KCherryIcon), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label ==
                "This live's cherries ${KFormat.grouped(325)}",
      ),
      findsOneWidget,
    );
  });

  testWidgets('the score chip shows points with the points mark', (
    tester,
  ) async {
    await pumpGolden(
      tester,
      const Center(child: KScoreChip(score: 5000)),
      language: AppLanguage.en,
    );
    expect(find.byType(KPointsIcon), findsOneWidget);
    expect(find.byType(KCherryIcon), findsNothing);
  });

  forEachLanguage((language) {
    testWidgets('golden: the host pill, ${language.name}', (tester) async {
      await _pumpPill(tester, language);
      await expectLater(
        find.byKey(_pillKey),
        matchesGoldenFile('png/live.host_pill_d259.${language.name}.png'),
      );
    }, tags: [goldenTag]);
  });
}
