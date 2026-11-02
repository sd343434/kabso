// D233 «صواريخ الزيارات» (owner 2026-11-01; CONVENTIONS §10.81): the hub
// card of a live with a rocket stage running shows that stage's rocket
// INSIDE the «مميز» pill (owner 2026-11-02: no separate round badge), the
// pill in that stage's own colours, and the animated frame tinted to match
// (still with reduce motion), says the stage to screen readers; a legacy
// featured live keeps the plain gold pill; a card without either shows
// neither; the stage comes from the server's `LiveBoostedRoom.stage`
// (older servers: 1).

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/domain/live_boost_models.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_rocket_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

LiveRoomCardData _card({int stage = 0, bool featured = false}) =>
    LiveRoomCardData(
      hostName: 'Lina',
      title: 'Night chat',
      viewerCount: 12,
      roomId: 'r1',
      featured: featured || stage > 0,
      boostStage: stage,
    );

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

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
    testWidgets('stage $stage: its rocket inside «مميز» at the reading '
        'start, the stage colours, the frame, said aloud', (tester) async {
      for (final language in AppLanguage.values) {
        await _pumpCard(tester, _card(stage: stage), language: language);
        final pill = find.byKey(KLiveGridCard.featuredKey);
        expect(tester.widget<KFeaturedPill>(pill).stage, stage);
        final rocket = find.descendant(
          of: pill,
          matching: find.byType(KRocketArt),
        );
        expect(rocket, findsOneWidget);
        expect(tester.widget<KRocketArt>(rocket).stage, stage);
        final label = find.descendant(of: pill, matching: find.byType(Text));
        final r = tester.getRect(rocket);
        final l = tester.getRect(label);
        expect(r.height, lessThanOrEqualTo(l.height + 3));
        if (language == AppLanguage.ar) {
          expect(r.left, greaterThanOrEqualTo(l.right)); // RTL: start = right
        } else {
          expect(r.right, lessThanOrEqualTo(l.left));
        }
        // The text colour is the stage's.
        expect(
          tester.widget<Text>(label).style?.color,
          KRocketStyles.of(stage).text,
        );
      }
      // No separate round badge any more: the pill's is the only rocket.
      expect(find.byType(KRocketArt), findsOneWidget);
      final handle = tester.ensureSemantics();
      await _pumpCard(tester, _card(stage: stage));
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

  testWidgets('a live without a rocket: no pill, no frame', (tester) async {
    await _pumpCard(tester, _card(), language: AppLanguage.en);
    expect(find.byType(KRocketArt), findsNothing);
    expect(find.byKey(KLiveGridCard.frameKey), findsNothing);
    expect(find.byKey(KLiveGridCard.featuredKey), findsNothing);
  });

  testWidgets('a legacy featured live (no stage): the plain gold «مميز», '
      'no rocket, no frame', (tester) async {
    await _pumpCard(tester, _card(featured: true));
    final pill = find.byKey(KLiveGridCard.featuredKey);
    expect(pill, findsOneWidget);
    expect(tester.widget<KFeaturedPill>(pill).stage, 0);
    expect(find.byType(KRocketArt), findsNothing);
    expect(find.byKey(KLiveGridCard.frameKey), findsNothing);
    final text = tester.widget<Text>(
      find.descendant(of: pill, matching: find.byType(Text)),
    );
    expect(text.style?.color, KRocketStyles.gold.text);
  });

  test('four distinct stage styles, text ≥ 4.5:1 on every pill stop', () {
    final styles = [
      for (final s in [1, 2, 3, 4]) KRocketStyles.of(s),
    ];
    expect(styles.map((s) => s.pill.first).toSet(), hasLength(4));
    expect(styles.map((s) => s.ring).toSet(), hasLength(4));
    for (final s in styles) {
      for (final c in s.pill) {
        expect(_contrast(s.text, c), greaterThanOrEqualTo(4.5), reason: '$c');
      }
    }
    expect(KRocketStyles.of(9), KRocketStyles.royal);
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
