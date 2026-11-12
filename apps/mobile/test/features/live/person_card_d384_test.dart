// D384 (owner 2026-11-12: «انتبه جيداً لطريقة الصورة شخصية»; CONVENTIONS
// §10.173.4): the VIP animated picture «صورة متحركة» on the person card —
// the member's cut-out loops large above the name instead of the round
// photo, its head over the sheet's top edge, a soft shadow under the chin;
// its still under reduced motion or «إخفاء مؤثرات الهدايا»; the round photo
// while it loads, when it fails and for everyone without one; over the D383
// VIP background too; nothing overflows at 360 / 393 × 1.0 / 1.3, ar / en.
// The picture is a synthetic drawn stand-in (no real face).

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/live/application/live_viewer_prefs.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_tools.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_cutout.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/vip/cutout_d384_fixtures.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_safety_repository.dart';
import '../../helpers/golden.dart';
import '../bonds/bonds_harness.dart';
import 'person_card_d383_test.dart' show cardCatalog;

const _vip = UserVip(tier: 'VIP_1', rank: 1, color: 0xFF2E8B3D);

PublicProfile _profile({bool ar = false, bool cutout = true}) =>
    apiProfile(ar: ar, followerCount: 1510000).copyWith(
      displayName: ar ? 'سارة' : 'Sara',
      followingCount: 59400,
      cherriesReceived: 5830000,
      coinsSent: 33200,
      vip: _vip,
      animatedAvatar: cutout ? syntheticCutout : null,
    );

Uint8List? _png;

/// The synthetic stand-in, drawn once per isolate.
Future<Uint8List> _stand(WidgetTester tester) async =>
    _png ??= (await tester.runAsync(syntheticCutoutPng))!;

Future<void> _card(
  WidgetTester tester,
  PublicProfile profile, {
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
  VipTierList? catalog,
  bool precache = true,
}) async {
  setViewport(tester, viewport);
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpBonds(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showHostSheet(
              context,
              'host0',
              scope: const LivePersonScope(roomId: 'room-0'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    language: language,
    brightness: Brightness.light,
    overrides: [
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(profile),
      ),
      safetyRepositoryProvider.overrideWithValue(FakeSafetyRepository()),
      profileLevelsProvider.overrideWith((ref, _) async => const []),
      vipCatalogProvider.overrideWith((ref) async => catalog),
    ],
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  if (precache) await precacheImages(tester);
}

void main() {
  final requested = <String>[];

  setUp(() {
    requested.clear();
    vipImageFor = (_) => const AssetImage('assets/live_themes/galaxy.webp');
  });
  tearDown(() {
    animatedAvatarImageFor = NetworkImage.new;
    vipImageFor = NetworkImage.new;
  });

  Future<void> serveStandIn(WidgetTester tester) async {
    final png = await _stand(tester);
    animatedAvatarImageFor = (src) {
      requested.add(src);
      return MemoryImage(png);
    };
  }

  group('D384 the animated picture on the person card', () {
    testWidgets('a holder with a clip: the cut-out plays instead of the '
        'round photo', (tester) async {
      await serveStandIn(tester);
      await _card(tester, _profile());
      expect(find.byKey(LivePersonSheet.cutoutKey), findsOneWidget);
      expect(find.byKey(VipCutout.playingKey), findsOneWidget);
      expect(find.byKey(VipCutout.stillKey), findsNothing);
      expect(find.byKey(VipCutout.fallbackKey), findsNothing);
      expect(find.byKey(VipCutout.shadowKey), findsOneWidget);
      expect(find.byKey(LivePersonSheet.ringKey), findsNothing);
      expect(requested.toSet(), {syntheticCutoutUrl});
      // A tap still opens the profile (the picture keeps its role).
      expect(
        find.ancestor(
          of: find.byKey(LivePersonSheet.cutoutKey),
          matching: find.byKey(LivePersonSheet.profileKey),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no clip (not a holder, or none set): the round photo, as '
        'before', (tester) async {
      await serveStandIn(tester);
      await _card(tester, _profile(cutout: false));
      expect(find.byKey(LivePersonSheet.cutoutKey), findsNothing);
      expect(find.byKey(LivePersonSheet.ringKey), findsOneWidget);
      expect(requested, isEmpty);
    });

    testWidgets('while it loads, and when it fails: the round photo in its '
        'place', (tester) async {
      // Loading: nothing decoded yet (an earlier test may have cached it).
      imageCache
        ..clear()
        ..clearLiveImages();
      await serveStandIn(tester);
      await _card(tester, _profile(), precache: false);
      expect(find.byKey(LivePersonSheet.cutoutKey), findsOneWidget);
      expect(find.byKey(VipCutout.fallbackKey), findsOneWidget);
      // Failing: the test HTTP client answers 400 to every image.
      animatedAvatarImageFor = NetworkImage.new;
      await _card(tester, _profile());
      expect(find.byKey(VipCutout.fallbackKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion: the still (the first frame), nothing plays', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await serveStandIn(tester);
      await _card(tester, _profile());
      expect(find.byKey(VipCutout.stillKey), findsOneWidget);
      expect(find.byKey(VipCutout.playingKey), findsNothing);
      expect(requested.toSet(), {syntheticCutoutStillUrl});
    });

    testWidgets('«إخفاء مؤثرات الهدايا»: the still too', (tester) async {
      await serveStandIn(tester);
      await _card(tester, _profile());
      expect(find.byKey(VipCutout.playingKey), findsOneWidget);
      ProviderScope.containerOf(
            tester.element(find.byKey(LivePersonSheet.sheetKey)),
          )
          .read(liveViewerPrefsProvider.notifier)
          .setGiftEffectsHidden(hidden: true);
      await tester.pumpAndSettle();
      expect(find.byKey(VipCutout.stillKey), findsOneWidget);
      expect(find.byKey(VipCutout.playingKey), findsNothing);
      expect(requested, contains(syntheticCutoutStillUrl));
    });

    testWidgets("it sits above the name, the head over the sheet's top edge", (
      tester,
    ) async {
      await serveStandIn(tester);
      await _card(tester, _profile());
      final cut = tester.getRect(find.byKey(LivePersonSheet.cutoutKey));
      // The sheet's own box starts under its top margin (the edge).
      final box = find
          .descendant(
            of: find.byKey(LivePersonSheet.sheetKey),
            matching: find.byType(Container),
          )
          .first;
      final margin = tester.widget<Container>(box).margin!.vertical;
      final sheet = tester.getRect(box);
      final edge = sheet.top + margin;
      final name = tester.getRect(find.byKey(LivePersonSheet.nameKey));
      // The head is over the edge; most of the picture inside the sheet.
      expect(cut.top, lessThan(edge));
      expect(cut.bottom, greaterThan(edge));
      expect(edge - cut.top, closeTo(cut.height * 0.28, 1));
      // Large (about 43 % of 393, at most 168) and centred.
      expect(cut.width, 168);
      expect(cut.center.dx, closeTo(393 / 2, 1));
      // The name below it.
      expect(name.top, greaterThanOrEqualTo(cut.bottom - 1));
    });

    testWidgets('over the D383 VIP background: both, the cut-out on top', (
      tester,
    ) async {
      await serveStandIn(tester);
      await _card(
        tester,
        _profile(),
        catalog: cardCatalog(
          value: '#1E2A44',
          still: 'https://cdn.test/vip/card_bg.png',
          animation: 'https://cdn.test/vip/card_bg.svga',
        ),
      );
      expect(find.byKey(LivePersonSheet.vipCardKey), findsOneWidget);
      expect(find.byKey(LivePersonSheet.cutoutKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final language in AppLanguage.values) {
      for (final viewport in GoldenViewport.values) {
        for (final scale in [1.0, 1.3]) {
          testWidgets('${language.name} ${viewport.name} ×$scale: nothing '
              'overflows, the cut-out stays on screen', (tester) async {
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await serveStandIn(tester);
            await _card(
              tester,
              _profile(ar: language == AppLanguage.ar),
              language: language,
              viewport: viewport,
            );
            expect(tester.takeException(), isNull);
            final cut = tester.getRect(find.byKey(LivePersonSheet.cutoutKey));
            final width = viewport.logicalSize.width;
            expect(cut.left, greaterThanOrEqualTo(0));
            expect(cut.right, lessThanOrEqualTo(width));
            expect(cut.top, greaterThanOrEqualTo(0));
            expect(cut.width, closeTo((width * 0.43).clamp(120, 168), 0.01));
            // The top tools leave the face free.
            for (final tool
                in find.byKey(LivePersonToolKeys.report).evaluate()) {
              final r = tester.getRect(find.byWidget(tool.widget));
              expect(
                r.right <= cut.center.dx - cut.width * 0.3 ||
                    r.left >= cut.center.dx + cut.width * 0.3,
                isTrue,
              );
            }
          });
        }
      }
    }
  });
}
