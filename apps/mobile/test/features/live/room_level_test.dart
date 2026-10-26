// CP-016 D (D101): the room level (the host's charm level) as the owner's
// charm badge next to the room name, and the owner's tap characters where a
// viewer taps the live — D120: any of all ten, whatever the room level.

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_tap_layer.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

/// The tap characters on screen, by asset, in the order they appeared.
List<String> _characters(WidgetTester tester) => [
  for (final image in tester.widgetList<Image>(
    find.descendant(
      of: find.byType(LiveTapCharacter),
      matching: find.byType(Image),
    ),
  ))
    (image.image as AssetImage).assetName,
];

Future<void> _pumpTaps(WidgetTester tester, {int seed = 1}) async {
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    Scaffold(
      body: LiveTapLayer(
        onTap: () {},
        random: math.Random(seed),
        child: const ColoredBox(color: Colors.black),
      ),
    ),
  );
}

Future<void> _pumpRoom(
  WidgetTester tester,
  LiveRoom room, {
  AppLanguage language = AppLanguage.en,
}) async {
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    const LiveRoomScreen(roomId: 'room-0'),
    language: language,
    overrides: [
      liveRepositoryProvider.overrideWithValue(
        FakeLiveRepository(room: (_) => room),
      ),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile()),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  group('charm tiers (owner pack)', () {
    test('every 10 levels a new creature; outside 1–100 the nearest end', () {
      expect(CharmTier.of(1), CharmTier.sprout);
      expect(CharmTier.of(10), CharmTier.sprout);
      expect(CharmTier.of(11), CharmTier.bunny);
      expect(CharmTier.of(37), CharmTier.butterfly);
      expect(CharmTier.of(91), CharmTier.royal);
      expect(CharmTier.of(100), CharmTier.royal);
      expect(CharmTier.of(150), CharmTier.royal);
      expect(CharmTier.of(0), CharmTier.sprout);
      expect(
        CharmTier.butterfly.icon,
        'assets/charm/charm_04_butterfly_icon.png',
      );
      expect(CharmTier.royal.tap, 'assets/taps/tap_10_royal.png');
    });

    testWidgets('every tier image is bundled', (tester) async {
      for (final tier in CharmTier.values) {
        for (final asset in [tier.icon, tier.tap]) {
          expect(
            (await rootBundle.load(asset)).lengthInBytes,
            greaterThan(0),
            reason: asset,
          );
        }
      }
    });
  });

  group('the room level next to the room name', () {
    testWidgets('a video room: the badge after the title, read as the level', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpRoom(tester, apiRoom().copyWith(roomLevel: 25));
      expect(find.byKey(CharmLevelBadge.badgeKey), findsOneWidget);
      expect(find.bySemanticsLabel('Room level 25'), findsOneWidget);
      final badge = tester.widget<CharmLevelBadge>(
        find.byType(CharmLevelBadge),
      );
      expect(CharmTier.of(badge.level), CharmTier.kitty);
      semantics.dispose();
    });

    testWidgets('no badge while the charm levels are unavailable', (
      tester,
    ) async {
      await _pumpRoom(tester, apiRoom());
      expect(find.byType(CharmLevelBadge), findsNothing);
    });

    testWidgets('Arabic: the label is translated, the number stays LTR', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpRoom(
        tester,
        apiRoom(ar: true).copyWith(roomLevel: 7),
        language: AppLanguage.ar,
      );
      expect(find.bySemanticsLabel('مستوى الغرفة 7'), findsOneWidget);
      final direction = tester.widget<Directionality>(
        find
            .descendant(
              of: find.byType(CharmLevelBadge),
              matching: find.byType(Directionality),
            )
            .first,
      );
      expect(direction.textDirection, TextDirection.ltr);
      semantics.dispose();
    });

    testWidgets('an audio room bar: title, then the badge, on one line', (
      tester,
    ) async {
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        const Scaffold(
          body: LiveAudioRoomHeader(
            cover: SizedBox(),
            title: 'Voices',
            subtitle: 'ID: 123456789',
            level: 42,
            minimizeTooltip: 'Minimize',
            onMinimize: null,
            endTooltip: 'End',
            onEnd: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final title = tester.getCenter(find.text('Voices'));
      final badge = tester.getCenter(find.byType(CharmLevelBadge));
      expect(badge.dx, greaterThan(title.dx));
      expect(badge.dy, closeTo(title.dy, 2));
      expect(CharmTier.of(42), CharmTier.fox);
      expect(tester.takeException(), isNull);
    });
  });

  group('tap characters (owner tap pack)', () {
    testWidgets('D120: every tap picks any of the ten characters, never '
        'the same twice in a row; over many taps all ten show', (tester) async {
      await _pumpTaps(tester);
      final seen = <String>[];
      for (var i = 0; i < 40; i++) {
        await tester.tap(find.byKey(LiveTapLayer.tapKey));
        await tester.pump(const Duration(milliseconds: 50));
        seen.add(_characters(tester).last);
      }
      final all = [for (final t in CharmTier.values) t.tap];
      expect(seen.every(all.contains), isTrue);
      expect(seen.toSet(), all.toSet());
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], isNot(seen[i - 1]));
      }
      await tester.pumpAndSettle();
      expect(find.byType(LiveTapCharacter), findsNothing);
    });

    testWidgets('D120: wherever the finger taps, every character starts '
        'and rises inside the narrow lane at the physical right edge near '
        'the bottom, at half the old size', (tester) async {
      await _pumpTaps(tester, seed: 5);
      final layer = tester.getRect(find.byKey(LiveTapLayer.tapKey));
      final lane = LiveTapLayer.lane(layer.size, 72).shift(layer.topLeft);
      expect(lane.width, LiveTapLayer.laneWidth);
      expect(layer.right - lane.right, LiveTapLayer.laneRightInset);
      expect(LiveTapLayer.size, 19);
      final rects = <Rect>[];
      void sample() {
        for (final e
            in find
                .descendant(
                  of: find.byType(LiveTapCharacter),
                  matching: find.byType(Image),
                )
                .evaluate()) {
          rects.add(tester.getRect(find.byWidget(e.widget)));
        }
      }

      // Taps far from the lane: top-left, centre, bottom-left (any side).
      final spots = [
        layer.topLeft + const Offset(40, 120),
        layer.center,
        layer.bottomLeft + const Offset(30, -200),
      ];
      for (var i = 0; i < 12; i++) {
        await tester.tapAt(spots[i % spots.length]);
        await tester.pump(const Duration(milliseconds: 16));
        sample();
        await tester.pump(const Duration(milliseconds: 90));
        sample();
      }
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        sample();
      }
      expect(rects, isNotEmpty);
      final inLane = lane.inflate(0.5);
      for (final r in rects) {
        expect(
          inLane.contains(r.topLeft) && inLane.contains(r.bottomRight),
          isTrue,
          reason: '$r outside $lane',
        );
      }
      await tester.pumpAndSettle();
    });

    testWidgets('the 10th tap of a combo is a big pop with a ring', (
      tester,
    ) async {
      await _pumpTaps(tester, seed: 3);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(LiveTapLayer.tapKey));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('x4'), findsOneWidget);
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.byKey(LiveTapLayer.tapKey));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('x10'), findsOneWidget);
      final sizes = [
        for (final image in tester.widgetList<Image>(
          find.descendant(
            of: find.byType(LiveTapCharacter),
            matching: find.byType(Image),
          ),
        ))
          image.width!,
      ];
      expect(sizes.last, closeTo(LiveTapLayer.size * 1.7, 0.01));
      expect(sizes.take(9).every((s) => s < LiveTapLayer.size * 1.2), isTrue);
      // The ring's sparkles belong to the big pop only.
      expect(find.byIcon(Icons.auto_awesome), findsNWidgets(4));
      await tester.pumpAndSettle();
      expect(find.byType(LiveTapCharacter), findsNothing);
    });

    testWidgets('a pause longer than the combo timeout starts a new combo', (
      tester,
    ) async {
      await _pumpTaps(tester);
      await tester.tap(find.byKey(LiveTapLayer.tapKey));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(LiveTapLayer.tapKey));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('x2'), findsOneWidget);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LiveTapLayer.tapKey));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining(RegExp(r'^x\d')), findsNothing);
    });
  });
}
