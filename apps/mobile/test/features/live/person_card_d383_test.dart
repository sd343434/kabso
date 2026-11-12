// D383 (owner 2026-11-12): no box or frame around the person card; the card
// keeps its earlier layout (owner: «ارى ان شكل البطاقة السابقة اجمل لكن ميزة
// ... خلفية متحركة للبطاقة يمكن تطبيقهم»). The VIP PROFILE_CARD perk is the
// card's background: a colour and / or a moving art behind the content,
// dimmed by a scrim; still under reduced motion or «إخفاء مؤثرات الهدايا».
// Everyone else gets the earlier card exactly.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/design_system/design_system.dart';
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
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_safety_repository.dart';
import '../../helpers/golden.dart';
import '../bonds/bonds_harness.dart';

const _vip = UserVip(tier: 'VIP_1', rank: 1, color: 0xFF2E8B3D);

/// A tier whose PROFILE_CARD carries [value] and the art given.
VipTierList cardCatalog({
  Object? value,
  String? still,
  String? animation,
  String? videoUrl,
}) => VipTierList(
  tiers: [
    VipTier(
      id: 'id-VIP_1',
      code: 'VIP_1',
      name: 'VIP 1',
      level: 1,
      color: 0xFF2E8B3D,
      priceCoins: 1000000,
      durationDays: 30,
      perks: [
        VipPerk(
          code: VipPerks.profileCard,
          title: 'Card background',
          available: true,
          value: value,
          still: still,
          animation: animation,
          videoUrl: videoUrl,
        ),
      ],
    ),
  ],
  maxAheadDays: 400,
);

PublicProfile _profile({bool vip = false}) =>
    apiProfile(followerCount: 1510000).copyWith(
      displayName: 'Sara',
      followingCount: 59400,
      cherriesReceived: 5830000,
      coinsSent: 33200,
      vip: vip ? _vip : null,
    );

Future<BondFakes> _card(
  WidgetTester tester,
  PublicProfile profile, {
  LivePersonScope? scope = const LivePersonScope(roomId: 'room-0'),
  VipTierList? catalog,
  Brightness brightness = Brightness.light,
}) async {
  setViewport(tester, GoldenViewport.phone);
  await tester.pumpWidget(const SizedBox.shrink());
  final fakes = await pumpBonds(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showHostSheet(context, 'host0', scope: scope),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    brightness: brightness,
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
  return fakes;
}

Color _sheet(WidgetTester tester) =>
    (tester
                .widget<Container>(
                  find
                      .descendant(
                        of: find.byKey(LivePersonSheet.sheetKey),
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration!
            as BoxDecoration)
        .color!;

Color _nameInk(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(LivePersonSheet.nameKey),
        matching: find.byType(Text),
      ),
    )
    .style!
    .color!;

void main() {
  setUp(() {
    // The hosted art's stand-in: Kabso's own theme art (bundled).
    vipImageFor = (_) => const AssetImage('assets/live_themes/galaxy.webp');
  });
  tearDown(() => vipImageFor = NetworkImage.new);

  group('D383 the person card without the perk', () {
    testWidgets('a non-holder gets the plain card: no frame art, no '
        'background, the theme surface', (tester) async {
      for (final brightness in Brightness.values) {
        await _card(tester, _profile(), brightness: brightness);
        expect(find.byKey(LivePersonSheet.vipCardKey), findsNothing);
        expect(find.byKey(LivePersonSheet.vipColorKey), findsNothing);
        expect(find.byKey(LivePersonSheet.vipScrimKey), findsNothing);
        expect(find.byKey(const Key('room.userCard.header')), findsNothing);
        expect(
          _sheet(tester),
          brightness == Brightness.dark
              ? KPalette.dark.surfaceRaised
              : KPalette.light.surfaceRaised,
        );
      }
      // A VIP whose tier has no PROFILE_CARD colour or art: plain too.
      await _card(tester, _profile(vip: true), catalog: cardCatalog());
      expect(find.byKey(LivePersonSheet.vipCardKey), findsNothing);
      expect(find.byKey(LivePersonSheet.vipColorKey), findsNothing);
    });
  });

  group('D383 the VIP card background (PROFILE_CARD)', () {
    testWidgets('a colour: the sheet takes it, the text what reads on it', (
      tester,
    ) async {
      await _card(
        tester,
        _profile(vip: true),
        catalog: cardCatalog(value: '#1E2A44'),
      );
      expect(find.byKey(LivePersonSheet.vipColorKey), findsOneWidget);
      expect(find.byKey(LivePersonSheet.vipCardKey), findsNothing);
      expect(find.byKey(LivePersonSheet.vipScrimKey), findsNothing);
      expect(_sheet(tester), const Color(0xFF1E2A44));
      final dark = _nameInk(tester);
      double ratio(Color a, Color b) {
        final la = a.computeLuminance();
        final lb = b.computeLuminance();
        return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
      }

      expect(ratio(dark, const Color(0xFF1E2A44)), greaterThanOrEqualTo(4.5));
      // A light colour: near-black text.
      await _card(
        tester,
        _profile(vip: true),
        catalog: cardCatalog(value: '#F5E6C8'),
      );
      final light = _nameInk(tester);
      expect(light, isNot(const Color(0xFFFFFFFF)));
      expect(ratio(light, const Color(0xFFF5E6C8)), greaterThanOrEqualTo(4.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('an art: it fills the card behind the content, under a '
        'scrim, and plays', (tester) async {
      await _card(
        tester,
        _profile(vip: true),
        catalog: cardCatalog(
          value: '#1E2A44',
          still: 'https://cdn.test/vip/card_bg.png',
          animation: 'https://cdn.test/vip/card_bg.svga',
        ),
      );
      final art = find.byKey(LivePersonSheet.vipCardKey);
      expect(art, findsOneWidget);
      expect(find.byKey(LivePersonSheet.vipScrimKey), findsOneWidget);
      expect(find.byKey(LivePersonSheet.vipArtPlayingKey), findsOneWidget);
      expect(find.byKey(LivePersonSheet.vipArtStillKey), findsNothing);
      final player = tester.widget<VipAnimatedArt>(
        find.descendant(of: art, matching: find.byType(VipAnimatedArt)),
      );
      expect(player.animate, isTrue);
      expect(player.animation, 'https://cdn.test/vip/card_bg.svga');
      expect(player.fit, BoxFit.cover);
      // Behind the content: the art covers the whole sheet, under the name.
      final sheet = tester.getRect(find.byKey(LivePersonSheet.sheetKey));
      final r = tester.getRect(art);
      expect(r.width, closeTo(sheet.width, 0.5));
      expect(
        r.contains(tester.getCenter(find.byKey(LivePersonSheet.nameKey))),
        isTrue,
      );
      // White text on the scrim (≥ 4.5:1 even over a white art).
      expect(_nameInk(tester), const Color(0xFFFFFFFF));
      final scrim = Color.alphaBlend(
        const Color(0x8C000000),
        const Color(0xFFFFFFFF),
      );
      final l = scrim.computeLuminance();
      expect((1 + 0.05) / (l + 0.05), greaterThanOrEqualTo(4.5));
    });

    testWidgets('reduced motion: the still, nothing plays', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _card(
        tester,
        _profile(vip: true),
        catalog: cardCatalog(
          still: 'https://cdn.test/vip/card_bg.png',
          animation: 'https://cdn.test/vip/card_bg.svga',
        ),
      );
      expect(find.byKey(LivePersonSheet.vipArtStillKey), findsOneWidget);
      expect(find.byKey(LivePersonSheet.vipArtPlayingKey), findsNothing);
      final art = find.byKey(LivePersonSheet.vipCardKey);
      final player = tester.widget<VipAnimatedArt>(
        find.descendant(of: art, matching: find.byType(VipAnimatedArt)),
      );
      expect(player.animate, isFalse);
      expect(
        find.descendant(of: art, matching: find.byType(Image)),
        findsOneWidget,
      );
    });

    testWidgets('«إخفاء مؤثرات الهدايا»: the still too', (tester) async {
      await _card(
        tester,
        _profile(vip: true),
        catalog: cardCatalog(
          still: 'https://cdn.test/vip/card_bg.png',
          animation: 'https://cdn.test/vip/card_bg.svga',
        ),
      );
      expect(find.byKey(LivePersonSheet.vipArtPlayingKey), findsOneWidget);
      ProviderScope.containerOf(
            tester.element(find.byKey(LivePersonSheet.sheetKey)),
          )
          .read(liveViewerPrefsProvider.notifier)
          .setGiftEffectsHidden(hidden: true);
      await tester.pumpAndSettle();
      expect(find.byKey(LivePersonSheet.vipArtStillKey), findsOneWidget);
      expect(find.byKey(LivePersonSheet.vipArtPlayingKey), findsNothing);
    });

    testWidgets('an SVGA without a still: still motion shows its first frame '
        '(the player under reduced motion)', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _card(
        tester,
        _profile(vip: true),
        catalog: cardCatalog(animation: 'https://cdn.test/vip/card_bg.svga'),
      );
      final art = find.byKey(LivePersonSheet.vipCardKey);
      final player = tester.widget<VipAnimatedArt>(
        find.descendant(of: art, matching: find.byType(VipAnimatedArt)),
      );
      expect(player.animate, isTrue);
      final media = MediaQuery.of(
        tester.element(
          find.descendant(of: art, matching: find.byType(VipAnimatedArt)),
        ),
      );
      expect(media.disableAnimations, isTrue);
    });

    testWidgets("the perk's MP4 (no SVGA) plays as a plain video", (
      tester,
    ) async {
      await _card(
        tester,
        _profile(vip: true),
        catalog: cardCatalog(
          still: 'https://cdn.test/vip/card_bg.png',
          videoUrl: 'https://cdn.test/vip/card_bg.mp4',
        ),
      );
      final player = tester.widget<VipAnimatedArt>(
        find.descendant(
          of: find.byKey(LivePersonSheet.vipCardKey),
          matching: find.byType(VipAnimatedArt),
        ),
      );
      expect(player.animation, 'https://cdn.test/vip/card_bg.mp4');
      expect(player.video, ArtVideo.plain);
    });

    testWidgets('a tier saved before D383 (art, no value): the art is the '
        'background', (tester) async {
      await _card(
        tester,
        _profile(vip: true),
        catalog: cardCatalog(still: 'https://cdn.test/vip/card.png'),
      );
      expect(find.byKey(LivePersonSheet.vipCardKey), findsOneWidget);
      expect(find.byKey(LivePersonSheet.vipColorKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('VipPerk reads the MP4 (`video`) from the contract', (
      tester,
    ) async {
      final p = VipPerk.fromJson(const {
        'code': 'PROFILE_CARD',
        'title': 'Card background',
        'available': true,
        'video': 'https://cdn.test/vip/bg.mp4',
        'value': '#1E2A44',
      });
      expect(p.videoUrl, 'https://cdn.test/vip/bg.mp4');
      expect(p.value, '#1E2A44');
      expect(
        VipPerk.fromJson(const {
          'code': 'X',
          'title': 'x',
          'available': true,
          'video': 'http://plain',
        }).videoUrl,
        isNull,
      );
    });
  });
}
