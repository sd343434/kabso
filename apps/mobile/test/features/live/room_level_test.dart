// CP-016 D (D101): the room level (the host's charm level) as the owner's
// charm badge next to the room name, and the owner's tap characters — only
// the tiers the host has reached — where a viewer taps the live.

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

Future<void> _pumpTaps(WidgetTester tester, {required int maxTier}) async {
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    Scaffold(
      body: LiveTapLayer(
        onTap: () {},
        maxTier: maxTier,
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
    testWidgets('a level 1 room shows only the sprout', (tester) async {
      await _pumpTaps(tester, maxTier: 1);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(LiveTapLayer.tapKey));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(_characters(tester), List.filled(3, CharmTier.sprout.tap));
      await tester.pumpAndSettle();
      expect(find.byType(LiveTapCharacter), findsNothing);
    });

    testWidgets('the reached tiers take turns; the 10th tap of a combo is a '
        "big pop of the host's highest tier with a ring", (tester) async {
      await _pumpTaps(tester, maxTier: 3);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(LiveTapLayer.tapKey));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(_characters(tester), [
        CharmTier.sprout.tap,
        CharmTier.bunny.tap,
        CharmTier.kitty.tap,
        CharmTier.sprout.tap,
      ]);
      expect(find.text('x4'), findsOneWidget);
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.byKey(LiveTapLayer.tapKey));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('x10'), findsOneWidget);
      expect(_characters(tester).last, CharmTier.kitty.tap);
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
      await _pumpTaps(tester, maxTier: 2);
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
