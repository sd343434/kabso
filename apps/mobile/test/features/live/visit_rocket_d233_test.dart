// D233 «صواريخ الزيارات» (owner 2026-11-01; CONVENTIONS §10.81): the hub
// card of a live with a rocket stage running shows that stage's rocket
// badge and the animated «مميز» frame (still with reduce motion), says the
// stage to screen readers; a card without one shows neither; the stage
// comes from the server's `LiveBoostedRoom.stage` (older servers: 1).

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/domain/live_boost_models.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_rocket_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

LiveRoomCardData _card({int stage = 0}) => LiveRoomCardData(
  hostName: 'Lina',
  title: 'Night chat',
  viewerCount: 12,
  roomId: 'r1',
  featured: stage > 0,
  boostStage: stage,
);

Future<void> _pumpCard(
  WidgetTester tester,
  LiveRoomCardData room, {
  AppLanguage language = AppLanguage.ar,
  bool reduceMotion = false,
}) async {
  setViewport(tester, GoldenViewport.android);
  await pumpScreen(
    tester,
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: Center(
          child: SizedBox(
            width: 170,
            height: 190,
            child: KLiveGridCard(room: room),
          ),
        ),
      ),
    ),
    language: language,
  );
}

void main() {
  for (final stage in [1, 2, 3, 4]) {
    testWidgets('stage $stage: its rocket badge, the frame, said aloud', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpCard(tester, _card(stage: stage));
      final badge = tester.widget<KRocketBadge>(
        find.byKey(KLiveGridCard.rocketKey),
      );
      expect(badge.stage, stage);
      expect(
        tester.getSize(find.byKey(KLiveGridCard.rocketKey)).width,
        KRocketBadge.sizeOf(stage),
      );
      final frame = tester.widget<KBoostFrame>(
        find.byKey(KLiveGridCard.frameKey),
      );
      expect(frame.stage, stage);
      expect(find.byKey(KLiveGridCard.featuredKey), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('مميز, صاروخ $stage, ')),
        findsOneWidget,
      );
      handle.dispose();
    });
  }

  testWidgets('a live without a rocket: no badge, no frame', (tester) async {
    await _pumpCard(tester, _card(), language: AppLanguage.en);
    expect(find.byKey(KLiveGridCard.rocketKey), findsNothing);
    expect(find.byKey(KLiveGridCard.frameKey), findsNothing);
    expect(find.byKey(KLiveGridCard.featuredKey), findsNothing);
  });

  testWidgets('the frame moves, and holds still with reduce motion', (
    tester,
  ) async {
    KBoostFrame.animate = true;
    addTearDown(() => KBoostFrame.animate = false);
    await _pumpCard(tester, _card(stage: 4));
    expect(tester.hasRunningAnimations, isTrue);
    await _pumpCard(tester, _card(stage: 4), reduceMotion: true);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
  });

  test('the frame grows with the stage; stage 4 is the most premium', () {
    final specs = [
      for (final s in [1, 2, 3, 4]) KBoostFrame.specOf(s),
    ];
    for (var i = 1; i < specs.length; i++) {
      expect(specs[i].width, greaterThan(specs[i - 1].width));
      expect(specs[i].glow, greaterThanOrEqualTo(specs[i - 1].glow));
      expect(specs[i].seconds, lessThan(specs[i - 1].seconds));
      expect(specs[i].arcs, greaterThanOrEqualTo(specs[i - 1].arcs));
    }
    expect(KBoostFrame.specOf(9), KBoostFrame.specOf(4));
  });

  test('the server stage reaches the card; an older server reads as 1', () {
    final json = {
      'room': {
        'id': 'r1',
        'title': 'Room',
        'topic': null,
        'mode': 'SOLO',
        'host': {
          'id': 'h1',
          'username': 'h1',
          'displayName': 'Host',
          'avatarUrl': null,
        },
        'category': null,
        'viewerCount': 3,
        'startedAt': '2026-11-01T12:00:00.000Z',
        'score': 0,
        'coverUrl': null,
      },
      'endsAt': '2026-11-01T12:30:00.000Z',
    };
    final old = LiveBoostedRoom.fromJson(json);
    expect(old.stage, 1);
    final now = LiveBoostedRoom.fromJson({...json, 'stage': 3});
    expect(now.stage, 3);
    final card = LiveRoomCardData.fromSummary(now.room, boostStage: now.stage);
    expect(card.featured, isTrue);
    expect(card.boostStage, 3);
    expect(
      LiveBoostOption.fromJson({
        'stage': 4,
        'minutes': 60,
        'priceCoins': 3500000,
        'savePercent': 0,
      }).stage,
      4,
    );
  });
}
