// D280 (owner's device): «عندما يقوم الشخص بتصغير البث والعودة الى حجمه
// الطبيعي تعاد تشغيل سيارة الدخول» — each VIP entrance plays once per visit
// to the room, not again when the minimized live opens again (its screen,
// and the entrance layer, are built anew). And «سيارة الدخول يجب ان تبدأ من
// اسفل الشاشة بحيث لا يظهر فراغ من اسفل»: the car covers the screen's width
// with its art's bottom on the screen's bottom edge.
//
// The owner's peacock (not in the repo) is drawn too when
// VIP_ENTRY_SVGA=<path to peacock_000.svga>; D280_OUT=<dir> keeps the
// picture (a preview, never committed).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/svga/svga_engine.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/vip/application/vip_entrance_plays.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_entrance.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_svga.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/svga_fixture.dart';

const _vip1 = UserVip(tier: 'VIP_1', rank: 1, color: 0xFF2E8B3D);

const _layla = UserSummary(
  id: 'u-layla',
  username: 'layla',
  displayName: 'Layla',
  avatarUrl: null,
  vip: _vip1,
);
const _sara = UserSummary(
  id: 'u-sara',
  username: 'sara',
  displayName: 'Sara',
  avatarUrl: null,
  vip: _vip1,
);

VipTierList _catalog() => const VipTierList(
  tiers: [
    VipTier(
      id: 'id-VIP_1',
      code: 'VIP_1',
      name: 'VIP 1',
      level: 1,
      color: 0xFF2E8B3D,
      nameColor: 0xFFFFC928,
      priceCoins: 1000000,
      durationDays: 30,
      perks: [
        VipPerk(
          code: VipPerks.entryBanner,
          title: 'banner',
          available: true,
          still: 'https://cdn.test/vip/banner.png',
          artWidth: 2000,
          artHeight: 667,
        ),
        VipPerk(
          code: VipPerks.entryEffect,
          title: 'car',
          available: true,
          animation: 'https://cdn.test/vip/car.svga',
        ),
      ],
    ),
  ],
  maxAheadDays: 400,
);

/// The live's screen: the entrance layer is there while [shown] (false:
/// the live is minimized).
class _Live extends StatelessWidget {
  const new({required this.shown, this.self});

  final ValueListenable<bool> shown;
  final UserSummary? self;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: shown,
    builder: (context, on, _) => Stack(
      fit: StackFit.expand,
      children: [if (on) LiveVipEntranceLayer(roomId: 'room-0', self: self)],
    ),
  );
}

final Finder _banner = find.byKey(LiveVipEntranceLayer.bannerKey);

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
}

/// The banner shows (Layla's or [name]'s), then leaves.
Future<void> _plays(WidgetTester tester, {String name = 'Layla'}) async {
  await _frames(tester);
  await tester.pump(const Duration(milliseconds: 300));
  expect(_banner, findsOneWidget);
  expect(
    find.descendant(of: _banner, matching: find.textContaining(name)),
    findsOneWidget,
  );
  await tester.pump(LiveVipEntranceLayer.stillDuration);
  await _frames(tester);
  expect(_banner, findsNothing);
}

/// Nothing plays (for longer than an entrance lasts).
Future<void> _quiet(WidgetTester tester) async {
  await _frames(tester);
  for (var i = 0; i < 4; i++) {
    expect(_banner, findsNothing);
    expect(find.byKey(LiveVipEntranceLayer.carKey), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<({FakeLiveMediaEngine engine, ProviderContainer container})> _pump(
  WidgetTester tester,
  ValueNotifier<bool> shown, {
  UserSummary? self,
}) async {
  final engine = FakeLiveMediaEngine()..present.add('user-0');
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    _Live(shown: shown, self: self),
    liveMediaEngine: engine,
    overrides: [
      liveRepositoryProvider.overrideWithValue(
        FakeLiveRepository(room: (id) => apiRoom(id: id)),
      ),
      currentUserProvider.overrideWithValue(testUser()),
      vipCatalogProvider.overrideWith((ref) async => _catalog()),
    ],
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(_Live)),
  );
  return (engine: engine, container: container);
}

/// The room's chat on [engine] (the screen does this), kept while the test
/// runs (the host's chat outlives the minimized screen).
Future<void> _chat(
  WidgetTester tester,
  ProviderContainer container,
  FakeLiveMediaEngine engine,
) async {
  final keep = container.listen(liveChatProvider('room-0'), (_, _) {});
  addTearDown(keep.close);
  await container
      .read(liveChatProvider('room-0').notifier)
      .attach(engine, enabled: true, muted: false);
  await _frames(tester);
}

void main() {
  setUp(() {
    vipImageFor = (url) =>
        const AssetImage('assets/live_top_frames/top_1.webp');
    LiveVipEntranceLayer.animate = false;
  });
  tearDown(() {
    vipImageFor = NetworkImage.new;
    LiveVipEntranceLayer.animate = true;
  });

  group('once per visit', () {
    testWidgets("a viewer's join plays once: minimized and opened again, "
        'it does not play again; the next join does', (tester) async {
      final shown = ValueNotifier(true);
      final (:engine, :container) = await _pump(tester, shown);
      await _chat(tester, container, engine);
      engine.chat.add(const LiveChatJoined(_layla));
      await _plays(tester);

      // Minimized (the layer goes), opened again (a new layer).
      shown.value = false;
      await _frames(tester);
      shown.value = true;
      await _quiet(tester);

      engine.chat.add(const LiveChatJoined(_sara));
      await _plays(tester, name: 'Sara');
    });

    testWidgets('a join that came while the live was minimized does not '
        'play when it opens again (no backlog)', (tester) async {
      final shown = ValueNotifier(true);
      final (:engine, :container) = await _pump(tester, shown);
      await _chat(tester, container, engine);
      shown.value = false;
      await _frames(tester);
      engine.chat.add(const LiveChatJoined(_layla));
      await _frames(tester);
      shown.value = true;
      await _quiet(tester);
    });

    testWidgets('minimized while it plays: it does not start again', (
      tester,
    ) async {
      final shown = ValueNotifier(true);
      final (:engine, :container) = await _pump(tester, shown);
      await _chat(tester, container, engine);
      engine.chat.add(const LiveChatJoined(_layla));
      await _frames(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_banner, findsOneWidget);
      shown.value = false;
      await _frames(tester);
      shown.value = true;
      await _quiet(tester);
    });

    testWidgets('the same VIP announced again within a minute (their media '
        'reconnecting) plays nothing; later it plays', (tester) async {
      final shown = ValueNotifier(true);
      final (:engine, :container) = await _pump(tester, shown);
      await _chat(tester, container, engine);
      engine.chat.add(const LiveChatJoined(_layla));
      await _plays(tester);
      engine.chat.add(const LiveChatJoined(_layla));
      await _quiet(tester);
      await tester.pump(VipEntrancePlays.rejoinQuiet);
      engine.chat.add(const LiveChatJoined(_layla));
      await _plays(tester);
    });

    testWidgets("the host's own entrance plays once per live: not again "
        'when the minimized live opens again', (tester) async {
      final shown = ValueNotifier(true);
      final (engine: _, :container) = await _pump(tester, shown, self: _layla);
      await _plays(tester);

      shown.value = false;
      await _frames(tester);
      shown.value = true;
      await _quiet(tester);
      // And again.
      shown.value = false;
      await _frames(tester);
      shown.value = true;
      await _quiet(tester);

      // Leaving the room ends the visit: the next one plays it again.
      shown.value = false;
      await _frames(tester);
      container.read(vipEntrancePlaysProvider).forget('room-0');
      shown.value = true;
      await _plays(tester);
    });

    testWidgets("the host's own entrance minimized while it plays does not "
        'start again', (tester) async {
      final shown = ValueNotifier(true);
      await _pump(tester, shown, self: _layla);
      await _frames(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_banner, findsOneWidget);
      shown.value = false;
      await _frames(tester);
      shown.value = true;
      await _quiet(tester);
    });

    test('another room is its own visit', () {
      final plays = VipEntrancePlays();
      expect(plays.takeSelf('a'), isTrue);
      expect(plays.takeSelf('a'), isFalse);
      expect(plays.takeSelf('b'), isTrue);
      const line = LiveChatJoinLine(_layla, 0);
      expect(plays.takeJoin('a', line), isTrue);
      expect(plays.takeJoin('a', line), isFalse);
      // A chat built again counts from 0: a new join, even with serial 0.
      expect(plays.takeJoin('a', const LiveChatJoinLine(_sara, 0)), isTrue);
      plays.forget('a');
      expect(plays.takeSelf('a'), isTrue);
    });
  });

  group('the car at the bottom', () {
    late Uint8List file;
    final clipPixels = VipSvgaCache.clipPixels;
    final clock = VipSvga.clock;

    setUp(() {
      VipSvga.enabled = true;
      VipSvgaCache.fetch = (url) async => file;
    });
    tearDown(() {
      VipSvga.enabled = false;
      VipSvga.clock = clock;
      VipSvgaCache.clipPixels = clipPixels;
      VipSvgaCache.clear();
    });

    /// The car as the layer draws it on a [screen] (one device pixel per
    /// unit), [at] after it starts, read back as RGBA.
    Future<({ui.Image image, ByteData data})> draw(
      WidgetTester tester,
      Size screen, {
      Duration at = Duration.zero,
    }) async {
      const url = 'https://cdn.test/vip/car.svga';
      // The clip follows the test's clock.
      VipSvga.clock = () => Duration(
        microseconds: tester.binding.clock.now().microsecondsSinceEpoch,
      );
      tester.view
        ..physicalSize = screen
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(
        () => VipSvgaCache.load(url, maxSide: screen.longestSide),
      );
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MediaQuery(
            data: MediaQueryData(size: screen),
            child: const Directionality(
              textDirection: TextDirection.ltr,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VipSvga(
                    url: url,
                    fit: LiveVipEntranceLayer.carFit,
                    alignment: LiveVipEntranceLayer.carAlignment,
                    trimBottom: true,
                    once: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      // Its pictures are decoded in the real zone, as it plays.
      const step = Duration(milliseconds: 100);
      for (var t = Duration.zero; t <= at + step * 3; t += step) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(t < at ? step : Duration.zero);
      }
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return (await tester.runAsync(() async {
        final image = render.toImageSync();
        final data = (await image.toByteData())!;
        return (image: image, data: data);
      }))!;
    }

    int alphaAt(ByteData data, int width, int x, int y) =>
        data.getUint8((y * width + x) * 4 + 3);

    /// The rows (top, bottom) the art covers in column [x].
    (int, int) rows(ByteData data, int width, int height, int x) {
      var top = -1;
      var bottom = -1;
      for (var y = 0; y < height; y++) {
        if (alphaAt(data, width, x, y) >= 40) {
          if (top < 0) top = y;
          bottom = y;
        }
      }
      return (top, bottom);
    }

    testWidgets('the art covers the width with its bottom on the '
        "screen's bottom — the canvas's empty rows below it left out", (
      tester,
    ) async {
      // A 100 × 200 canvas drawing only its top 150 rows.
      await tester.runAsync(
        () async => file = await svgaFixture(drawHeight: 150),
      );
      expect(SvgaDoc.parse(file).area, const Rect.fromLTRB(0, 0, 100, 150));
      final (:image, :data) = await draw(tester, const Size(393, 852));
      // 393 wide: the art (150 rows of 100) is 589.5 high, at the bottom.
      final (top, bottom) = rows(data, 393, 852, 196);
      expect(bottom, 851);
      expect(top, closeTo(852 - 589.5, 1.5));
      // The whole width.
      expect(alphaAt(data, 393, 0, 840), greaterThanOrEqualTo(40));
      expect(alphaAt(data, 393, 392, 840), greaterThanOrEqualTo(40));
      image.dispose();
    });

    testWidgets('a car taller than the screen loses its top, never its '
        'bottom', (tester) async {
      await tester.runAsync(() async => file = await svgaFixture());
      // 100 × 200 on a 400 × 600 screen: 800 high.
      final (:image, :data) = await draw(tester, const Size(400, 600));
      final (top, bottom) = rows(data, 400, 600, 200);
      expect((top, bottom), (0, 599));
      image.dispose();
    });

    testWidgets("the owner's peacock (VIP_ENTRY_SVGA) on a phone", (
      tester,
    ) async {
      final path = Platform.environment['VIP_ENTRY_SVGA']!;
      file = File(path).readAsBytesSync();
      final doc = SvgaDoc.parse(file);
      expect(doc.viewBox, const Size(563, 1000));
      // Mid-way (the peacock fully in).
      final (:image, :data) = await draw(
        tester,
        const Size(393, 852),
        at: const Duration(milliseconds: 3000),
      );
      final (_, bottom) = rows(data, 393, 852, 196);
      expect(bottom, 851);
      final out = Platform.environment['D280_OUT'];
      if (out != null) {
        final png = await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.png),
        );
        File('$out/peacock_393x852.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      }
      image.dispose();
    }, skip: Platform.environment['VIP_ENTRY_SVGA'] == null);
  });
}
