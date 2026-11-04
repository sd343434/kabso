// D258 phase 2 (§10.94.7): a VIP's entry banner and entry car, and the mic
// wave on a speaking seat.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/cp/data/cp_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/recharge/presentation/live_recharge_entrance.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_entrance.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_bonds_repositories.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _vip1 = UserVip(tier: 'VIP_1', rank: 1, color: 0xFF2E8B3D);

const _member = UserSummary(
  id: 'u-layla',
  username: 'layla',
  displayName: 'Layla',
  avatarUrl: null,
  vip: _vip1,
);
const _agentMember = UserSummary(
  id: 'u-nour',
  username: 'coin0007',
  displayName: 'Nour',
  avatarUrl: null,
  rechargeAgentCode: 'coin0007',
  vip: _vip1,
);
const _plain = UserSummary(
  id: 'u-mona',
  username: 'mona',
  displayName: 'Mona',
  avatarUrl: null,
);

VipTierList _catalog({bool car = true}) => VipTierList(
  tiers: [
    VipTier(
      id: 'id-VIP_1',
      code: 'VIP_1',
      name: 'VIP 1',
      level: 1,
      color: 0xFF2E8B3D,
      nameColor: 0xFFFFD12E,
      priceCoins: 1000000,
      durationDays: 30,
      perks: [
        const VipPerk(code: VipPerks.badge, title: 'b', available: true),
        const VipPerk(
          code: VipPerks.entryBanner,
          title: 'banner',
          available: true,
          still: 'https://cdn.test/vip/banner.png',
          artWidth: 2000,
          artHeight: 667,
        ),
        if (car)
          const VipPerk(
            code: VipPerks.entryEffect,
            title: 'car',
            available: true,
            animation: 'https://cdn.test/vip/car.svga',
          ),
        const VipPerk(
          code: VipPerks.micWave,
          title: 'wave',
          available: true,
          still: 'https://cdn.test/vip/top_1.png',
        ),
      ],
    ),
  ],
  maxAheadDays: 400,
);

String _assetFor(String url) {
  if (url.endsWith('banner.png')) {
    return 'assets/recharge_agent/entrance_bar.webp';
  }
  return 'assets/live_top_frames/top_1.webp';
}

Future<FakeLiveMediaEngine> _room(
  WidgetTester tester, {
  required VipTierList catalog,
  AppLanguage language = AppLanguage.en,
}) async {
  final engine = FakeLiveMediaEngine()..present.add('user-0');
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    const LiveRoomScreen(roomId: 'room-0'),
    language: language,
    liveMediaEngine: engine,
    overrides: [
      liveRepositoryProvider.overrideWithValue(
        FakeLiveRepository(room: (id) => apiRoom(id: id)),
      ),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile(ar: language == AppLanguage.ar)),
      ),
      cpRepositoryProvider.overrideWithValue(FakeCpRepository()),
      currentUserProvider.overrideWithValue(testUser()),
      vipCatalogProvider.overrideWith((ref) async => catalog),
    ],
  );
  await tester.pumpAndSettle();
  return engine;
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
}

void main() {
  setUp(() {
    vipImageFor = (url) => AssetImage(_assetFor(url));
    LiveVipEntranceLayer.animate = false;
  });
  tearDown(() {
    vipImageFor = NetworkImage.new;
    LiveVipEntranceLayer.animate = true;
  });

  testWidgets("a VIP's join shows the banner with the display name, then "
      'leaves; a plain join shows nothing', (tester) async {
    final engine = await _room(tester, catalog: _catalog());
    engine.chat.add(const LiveChatJoined(_plain));
    await _frames(tester);
    expect(find.byKey(LiveVipEntranceLayer.bannerKey), findsNothing);

    engine.chat.add(const LiveChatJoined(_member));
    await _frames(tester);
    await tester.pump(const Duration(milliseconds: 300));
    final banner = find.byKey(LiveVipEntranceLayer.bannerKey);
    expect(banner, findsOneWidget);
    expect(
      find.descendant(of: banner, matching: find.textContaining('Layla')),
      findsOneWidget,
    );
    final rect = tester.getRect(banner);
    expect(rect.width, closeTo(393 * VipEntranceBanner.widthFactor, 0.5));
    expect(rect.height, closeTo(rect.width / (2000 / 667), 0.5));
    expect(rect.left, greaterThanOrEqualTo(16 - 0.01));
    expect(rect.right, lessThanOrEqualTo(393 - 16 + 0.01));
    // The text plate keeps white text ≥ 7:1 on any art (worst case: white).
    expect(
      vipContrast(
        const Color(0xFFFFFFFF),
        Color.alphaBlend(VipEntranceBanner.plate, const Color(0xFFFFFFFF)),
      ),
      greaterThanOrEqualTo(7),
    );
    await tester.pump(LiveVipEntranceLayer.stillDuration);
    await _frames(tester);
    expect(banner, findsNothing);
    expect(find.byKey(LiveVipEntranceLayer.carKey), findsNothing);
  });

  testWidgets("D265: the VIP host's own entrance plays once on their screen "
      '(the host never joins as a viewer)', (tester) async {
    setViewport(tester, GoldenViewport.phone);
    await pumpScreen(
      tester,
      const Stack(
        children: [LiveVipEntranceLayer(roomId: 'room-0', self: _member)],
      ),
      liveMediaEngine: FakeLiveMediaEngine()..present.add('user-0'),
      overrides: [
        liveRepositoryProvider.overrideWithValue(
          FakeLiveRepository(room: (id) => apiRoom(id: id)),
        ),
        currentUserProvider.overrideWithValue(testUser()),
        vipCatalogProvider.overrideWith((ref) async => _catalog()),
      ],
    );
    await _frames(tester);
    await tester.pump(const Duration(milliseconds: 300));
    final banner = find.byKey(LiveVipEntranceLayer.bannerKey);
    expect(banner, findsOneWidget);
    expect(
      find.descendant(of: banner, matching: find.textContaining('Layla')),
      findsOneWidget,
    );
    await tester.pump(LiveVipEntranceLayer.stillDuration);
    await _frames(tester);
    expect(banner, findsNothing);
    // Once: a rebuild does not play it again.
    await tester.pump(const Duration(seconds: 1));
    expect(banner, findsNothing);
  });

  testWidgets("an agent's bar wins over the banner; the car still plays "
      'once and leaves (here: cannot play, done at once)', (tester) async {
    LiveRechargeEntranceLayer.animate = false;
    addTearDown(() => LiveRechargeEntranceLayer.animate = true);
    final engine = await _room(tester, catalog: _catalog());
    engine.chat.add(const LiveChatJoined(_agentMember));
    await _frames(tester);
    expect(find.byKey(LiveRechargeEntranceLayer.barKey), findsOneWidget);
    expect(find.byKey(LiveVipEntranceLayer.bannerKey), findsNothing);
    // The car could not play (no animations in tests): it is done at once.
    expect(find.byKey(LiveVipEntranceLayer.carKey), findsNothing);
    await tester.pump(LiveRechargeEntranceLayer.stillDuration);
    await _frames(tester);
  });

  testWidgets('a car that plays to the end calls onDone once', (tester) async {
    var done = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: VipAnimatedArt(
          animation: null,
          still: null,
          once: true,
          onDone: () => done++,
        ),
      ),
    );
    await _frames(tester);
    expect(done, 1);
  });

  testWidgets('the mic wave plays behind a speaking VIP only', (tester) async {
    Future<void> pump({required bool speaking, UserVip? vip}) =>
        tester.pumpWidget(
          ProviderScope(
            overrides: [
              vipCatalogProvider.overrideWith((ref) async => _catalog()),
            ],
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: VipMicWave(
                  vip: vip,
                  speaking: speaking,
                  size: 50,
                  fallback: const SizedBox(key: Key('glow')),
                  child: const SizedBox.square(dimension: 50),
                ),
              ),
            ),
          ),
        );
    await pump(speaking: true, vip: _vip1);
    await _frames(tester);
    expect(find.byKey(VipMicWave.waveKey), findsOneWidget);
    expect(tester.getSize(find.byKey(VipMicWave.waveKey)).width, 85);
    await pump(speaking: false, vip: _vip1);
    expect(find.byKey(VipMicWave.waveKey), findsNothing);
    expect(find.byKey(const Key('glow')), findsOneWidget);
    await pump(speaking: true);
    expect(find.byKey(VipMicWave.waveKey), findsNothing);
  });

  forEachLanguage((language) {
    testWidgets('golden vip.entrance ($language)', (tester) async {
      final catalog = _catalog();
      final look = vipLookOf(_vip1, catalog)!;
      final ar = language == AppLanguage.ar;
      await pumpGolden(
        tester,
        ProviderScope(
          overrides: [vipCatalogProvider.overrideWith((ref) async => catalog)],
          child: ColoredBox(
            color: const Color(0xFF3A4150),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // The owner's banner art (stand-in), then a tier without art.
                VipEntranceBanner(
                  name: ar ? 'ليلى' : 'Layla',
                  look: look,
                  perk: look.perk(VipPerks.entryBanner)!,
                ),
                const SizedBox(height: 24),
                VipEntranceBanner(
                  name: ar ? 'سامي' : 'Sami',
                  look: look,
                  perk: const VipPerk(
                    code: VipPerks.entryBanner,
                    title: 'b',
                    available: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        language: language,
        bare: true,
      );
      await tester.pump();
      await precacheImages(tester);
      await expectScreenGolden('vip.entrance', language: language);
    });
  });
}
