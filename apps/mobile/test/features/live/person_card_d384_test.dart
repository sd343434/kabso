// D384 (owner 2026-11-12: «انتبه جيداً لطريقة الصورة شخصية»; CONVENTIONS
// §10.173.4; then «اجعلها كأنها بإطار دائري بنفس حجم الإطار السابق»): the VIP
// animated picture «صورة متحركة» on the person card — the member's cut-out in
// the round photo's place: the same circle, size and position, inside the
// same ring and frames, the head popping a little over the circle's top edge;
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
    testWidgets('a holder with a clip: the cut-out plays free-floating — no '
        'circle, fill, ring or frame behind it', (tester) async {
      await serveStandIn(tester);
      await _card(tester, _profile());
      expect(find.byKey(LivePersonSheet.cutoutKey), findsOneWidget);
      expect(find.byKey(VipCutout.playingKey), findsOneWidget);
      expect(find.byKey(VipCutout.stillKey), findsNothing);
      expect(find.byKey(VipCutout.fallbackKey), findsNothing);
      // Owner: «أريد صورة الملف الشخصي كأنها بدون خلفية» — no ring, no
      // circle, no worn frame; nothing painted behind the picture.
      expect(find.byKey(LivePersonSheet.ringKey), findsNothing);
      expect(find.byKey(LivePersonSheet.bagFrameKey), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(LivePersonSheet.cutoutKey),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(LivePersonSheet.cutoutKey),
          matching: find.byType(ClipPath),
        ),
        findsNothing,
      );
      expect(find.byKey(VipCutout.edgeKey), findsOneWidget);
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

    testWidgets("the photo's box and place; bounded by the old photo circle "
        'at the bottom and sides with an invisible soft edge, open at the '
        'top', (tester) async {
      await serveStandIn(tester);
      await _card(tester, _profile(cutout: false));
      final ring = tester.getRect(find.byKey(LivePersonSheet.ringKey));
      final name = tester.getRect(find.byKey(LivePersonSheet.nameKey));
      await _card(tester, _profile());
      final cut = tester.getRect(find.byKey(LivePersonSheet.cutoutKey));
      // The same box (the ring's) at the same place; the name does not move.
      expect(cut, ring);
      expect(tester.getRect(find.byKey(LivePersonSheet.nameKey)), name);
      // The picture: up to the pop over the box's top, a little wider than
      // it, down to the box's bottom.
      final drawn = tester.getRect(find.byKey(VipCutout.edgeKey));
      final d = cut.width;
      expect(cut.top - drawn.top, closeTo(d * VipCutoutMetrics.pop, 0.5));
      expect(drawn.width, closeTo(d * (1 + VipCutoutMetrics.spread), 0.5));
      expect(drawn.center.dx, closeTo(cut.center.dx, 0.5));
      expect(drawn.bottom, closeTo(cut.bottom, 0.5));
      // The round edge: the old photo circle (inside the ring), feathered.
      final edge = tester.widget<RoundEdge>(find.byKey(VipCutout.edgeKey));
      final circle = edge.circle.shift(drawn.topLeft);
      const photo = LivePersonCardMetrics.avatar;
      expect(circle.width, photo);
      expect(circle.height, photo);
      expect(circle.center.dx, closeTo(ring.center.dx, 0.5));
      expect(circle.center.dy, closeTo(ring.center.dy, 0.5));
      expect(edge.feather, inInclusiveRange(4, 6));
      // The mask: inside the circle and anywhere above its centre (the head
      // and hair pop over it); outside the circle below its centre, nothing.
      final mask = tester
          .renderObject<RenderRoundEdge>(find.byKey(VipCutout.edgeKey))
          .maskPath();
      final c = edge.circle;
      expect(mask.contains(c.center), isTrue);
      expect(mask.contains(Offset(c.center.dx, c.bottom - 2)), isTrue);
      expect(mask.contains(Offset(c.left - 3, c.center.dy - 4)), isTrue);
      expect(mask.contains(Offset(c.center.dx, -10)), isTrue);
      expect(mask.contains(Offset(c.left + 2, c.bottom - 2)), isFalse);
      expect(mask.contains(Offset(c.right - 2, c.bottom - 2)), isFalse);
      expect(mask.contains(Offset(c.left - 3, c.center.dy + 6)), isFalse);
    });

    testWidgets('a worn VIP or bag frame is not drawn around the cut-out; '
        'without a clip it is, as before', (tester) async {
      await serveStandIn(tester);
      const frame = AvatarFrame(
        code: 'host_frame_pink',
        assetKey: 'host_frame_pink',
      );
      await _card(tester, _profile().copyWith(avatarFrame: frame));
      expect(find.byKey(LivePersonSheet.cutoutKey), findsOneWidget);
      expect(find.byKey(LivePersonSheet.bagFrameKey), findsNothing);
      await _card(tester, _profile(cutout: false).copyWith(avatarFrame: frame));
      expect(find.byKey(LivePersonSheet.bagFrameKey), findsOneWidget);
      expect(find.byKey(LivePersonSheet.cutoutKey), findsNothing);
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
            // The photo's box (circle and ring): the same size at any width.
            expect(
              cut.width,
              LivePersonCardMetrics.avatar + 2 * LivePersonCardMetrics.ring,
            );
            // The top tools leave the circle free.
            for (final tool
                in find.byKey(LivePersonToolKeys.report).evaluate()) {
              final r = tester.getRect(find.byWidget(tool.widget));
              expect(r.right <= cut.left || r.left >= cut.right, isTrue);
            }
          });
        }
      }
    }
  });
}
