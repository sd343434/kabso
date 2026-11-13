// D331 (owner, from a device: «سيارة الدخلة لا تُعرض بشاشة كاملة، بالإضافة
// لا تُعرض كاملة، يتم اقتصاص من وقتها»): the entry car (a VIP's or a worn
// store item's ENTRY_EFFECT) plays its file's whole length — the layer's
// cap was 10 s (every car over 9 s was cut) and an MP4 car's 10 s counted
// from its download — and covers the whole live screen when its canvas is
// portrait or square (it was full width only, leaving a band of the room
// above it). Two entrances in a row queue: neither is cut.
//
// The cars are real SVGA files (the engine's own decoding) on the test's
// clock; the MP4 car runs on a fake video controller.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/data/gift_art_cache.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_effect_sound.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_video_effect.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_entrance.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_svga.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

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

const _svgaUrl = 'https://cdn.test/vip/car.svga';
const _mp4Url = 'https://cdn.test/store/car.mp4';

/// VIP 1 with only an entry car (no banner: the car alone decides when the
/// entrance ends).
VipTierList _catalog({String url = _svgaUrl, ArtVideo? video}) => VipTierList(
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
          code: VipPerks.entryEffect,
          title: 'car',
          available: true,
          animation: url,
          video: video,
        ),
      ],
    ),
  ],
  maxAheadDays: 400,
);

final GlobalKey _boundary = GlobalKey();

class _Live extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: _boundary,
    child: const SizedBox.expand(
      child: LiveVipEntranceLayer(
        key: LiveVipEntranceLayer.layerKey,
        roomId: 'room-0',
      ),
    ),
  );
}

final Finder _car = find.byKey(LiveVipEntranceLayer.carKey);

/// The car's art widget (its key names the entrance), or null.
Key? _carArt(WidgetTester tester) {
  final art = find.descendant(of: _car, matching: find.byType(VipAnimatedArt));
  return art.evaluate().isEmpty ? null : tester.widget(art).key;
}

/// Whether the SVGA car is drawing (its clip read and playing).
bool _drawing(WidgetTester tester) => find
    .descendant(of: _car, matching: find.byType(CustomPaint))
    .evaluate()
    .isNotEmpty;

/// The fake clock's time.
Duration _now(WidgetTester tester) =>
    Duration(microseconds: tester.binding.clock.now().microsecondsSinceEpoch);

/// Pumps [d] in steps of [step].
Future<void> _advance(
  WidgetTester tester,
  Duration d, {
  Duration step = const Duration(milliseconds: 100),
}) async {
  var left = d;
  while (left > Duration.zero) {
    final s = left < step ? left : step;
    await tester.pump(s);
    left -= s;
  }
}

/// Pumps (the clip is read in the real zone) until the car draws.
Future<void> _untilDrawing(WidgetTester tester) async {
  for (var i = 0; i < 40 && !_drawing(tester); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(_drawing(tester), isTrue, reason: 'the car never started');
}

Future<FakeLiveMediaEngine> _pump(
  WidgetTester tester, {
  required VipTierList catalog,
  GoldenViewport viewport = GoldenViewport.phone,
  AppLanguage language = AppLanguage.en,
}) async {
  final engine = FakeLiveMediaEngine()..present.add('user-0');
  setViewport(tester, viewport);
  await pumpScreen(
    tester,
    const _Live(),
    language: language,
    liveMediaEngine: engine,
    overrides: [
      liveRepositoryProvider.overrideWithValue(
        FakeLiveRepository(room: (id) => apiRoom(id: id)),
      ),
      currentUserProvider.overrideWithValue(testUser()),
      vipCatalogProvider.overrideWith((ref) async => catalog),
    ],
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(_Live)),
  );
  final keep = container.listen(liveChatProvider('room-0'), (_, _) {});
  addTearDown(keep.close);
  await container
      .read(liveChatProvider('room-0').notifier)
      .attach(engine, enabled: true, muted: false);
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
  return engine;
}

/// An SVGA car of [seconds] seconds (one frame a second), read ahead at the
/// size the layer asks for (the phone's longest side at 3×).
Future<void> _svga(
  WidgetTester tester,
  void Function(Uint8List) set, {
  required int seconds,
  int width = 100,
}) async {
  await tester.runAsync(() async {
    set(await svgaFixture(frames: seconds, fps: 1, width: width));
    await VipSvgaCache.load(_svgaUrl, maxSide: 852 * 3);
  });
}

/// A video controller that "plays" [length] on the test's clock.
class _FakeVideo extends VideoPlayerController {
  new(this.length, this.picture) : super.networkUrl(Uri.parse('file:///car'));

  final Duration length;
  final Size picture;
  Timer? _end;

  @override
  Future<void> initialize() async {
    value = value.copyWith(
      isInitialized: true,
      duration: length,
      size: picture,
    );
  }

  @override
  Future<void> setVolume(double volume) async {
    value = value.copyWith(volume: volume);
  }

  @override
  Future<void> setLooping(bool looping) async {
    value = value.copyWith(isLooping: looping);
  }

  @override
  Future<void> play() async {
    value = value.copyWith(isPlaying: true);
    _end = Timer(length, () {
      value = value.copyWith(isPlaying: false, position: length);
    });
  }

  @override
  Future<void> dispose() async {
    _end?.cancel();
    await super.dispose();
  }
}

/// The device's cache: the MP4 is downloaded in [delay].
class _SlowCache extends GiftArtCache {
  new(this.delay);

  final Duration delay;

  @override
  Future<Uint8List> load(String url) => Future.error(UnsupportedError(url));

  @override
  Future<String> path(String url) =>
      Future<String>.delayed(delay, () => '/cache/car.mp4');
}

void main() {
  late Uint8List file;
  final clock = VipSvga.clock;

  final newPlayer = GiftEffectSound.newPlayer;
  setUp(() {
    // The cars' own sounds go to fake players (no audio plugin).
    GiftEffectSound.newPlayer = () => FakeSvgaPlayer([]);
    LiveVipEntranceLayer.animate = false;
    VipAnimatedArt.animationsEnabled = true;
    VipSvga.enabled = true;
    VipSvgaCache.fetch = (url) async => file;
  });
  tearDown(() {
    GiftEffectSound.newPlayer = newPlayer;
    LiveVipEntranceLayer.animate = true;
    VipAnimatedArt.animationsEnabled = false;
    VipSvga.enabled = false;
    VipSvga.clock = clock;
    VipSvgaCache.clear();
  });

  group('the rules', () {
    test('a portrait or square car covers the screen; a landscape one '
        "keeps the screen's width at the bottom", () {
      expect(LiveVipEntranceLayer.carFit, BoxFit.cover);
      expect(LiveVipEntranceLayer.carAlignment, Alignment.bottomCenter);
      // The owner's peacock (563 × 1000), the team car (396 × 720).
      expect(
        LiveVipEntranceLayer.carFitFor(const Size(563, 1000)),
        BoxFit.cover,
      );
      expect(
        LiveVipEntranceLayer.carFitFor(const Size(396, 720)),
        BoxFit.cover,
      );
      expect(
        LiveVipEntranceLayer.carFitFor(const Size(500, 500)),
        BoxFit.cover,
      );
      expect(
        LiveVipEntranceLayer.carFitFor(const Size(660, 150)),
        BoxFit.fitWidth,
      );
      // Unknown size (no art size from the panel): covers.
      expect(LiveVipEntranceLayer.carFitFor(Size.zero), BoxFit.cover);
    });

    test("the car's own length, then a moment; the cap is the panel's "
        'upload limit (15 s + its 0.5 s tolerance)', () {
      expect(
        LiveVipEntranceLayer.carLimit,
        const Duration(milliseconds: 15500),
      );
      expect(
        LiveVipEntranceLayer.carTimeout(const Duration(seconds: 6)),
        const Duration(seconds: 7),
      );
      expect(
        LiveVipEntranceLayer.carTimeout(const Duration(seconds: 10)),
        const Duration(seconds: 11),
      );
      expect(
        LiveVipEntranceLayer.carTimeout(const Duration(seconds: 15)),
        LiveVipEntranceLayer.carLimit,
      );
      expect(
        LiveVipEntranceLayer.carTimeout(const Duration(seconds: 40)),
        LiveVipEntranceLayer.carLimit,
      );
    });
  });

  group('the whole length', () {
    for (final seconds in [6, 10, 12]) {
      testWidgets('a $seconds s SVGA car plays to its end, then leaves', (
        tester,
      ) async {
        VipSvga.clock = () => _now(tester);
        await _svga(tester, (f) => file = f, seconds: seconds);
        final engine = await _pump(tester, catalog: _catalog());
        engine.chat.add(const LiveChatJoined(_layla));
        await _untilDrawing(tester);
        final started = _now(tester);
        final art = _carArt(tester);
        // Still playing just before its end (the 10 s cap cut it before).
        await _advance(
          tester,
          Duration(seconds: seconds) - const Duration(milliseconds: 300),
        );
        expect(_car, findsOneWidget);
        expect(_drawing(tester), isTrue);
        expect(_carArt(tester), art);
        // The file ends: the car leaves with it (not on a timer after).
        await _advance(tester, const Duration(milliseconds: 600));
        expect(_car, findsNothing);
        expect(
          _now(tester) - started,
          lessThan(Duration(seconds: seconds) + const Duration(seconds: 1)),
        );
      });
    }

    testWidgets('two entrances in a row queue: each car plays whole', (
      tester,
    ) async {
      VipSvga.clock = () => _now(tester);
      await _svga(tester, (f) => file = f, seconds: 6);
      final engine = await _pump(tester, catalog: _catalog());
      engine.chat.add(const LiveChatJoined(_layla));
      await _untilDrawing(tester);
      final first = _carArt(tester);
      // Sara comes in a second later: she waits.
      await _advance(tester, const Duration(seconds: 1));
      engine.chat.add(const LiveChatJoined(_sara));
      await tester.pump();
      await _advance(tester, const Duration(milliseconds: 4700));
      expect(_carArt(tester), first, reason: "Layla's car was cut");
      expect(_drawing(tester), isTrue);
      // Layla's ends; Sara's starts and plays its 6 s.
      Key? second;
      for (var i = 0; i < 20 && (second == null || second == first); i++) {
        await tester.pump(const Duration(milliseconds: 100));
        second = _carArt(tester);
      }
      expect(second, isNot(first));
      await _untilDrawing(tester);
      await _advance(tester, const Duration(milliseconds: 5700));
      expect(_carArt(tester), second, reason: "Sara's car was cut");
      expect(_drawing(tester), isTrue);
      await _advance(tester, const Duration(milliseconds: 600));
      expect(_car, findsNothing);
    });

    testWidgets('an MP4 car downloaded in 3 s plays its 12 s from its '
        'start (its download no longer counts)', (tester) async {
      final cache = GiftArtCache.instance;
      final controller = giftVideoController;
      GiftArtCache.instance = _SlowCache(const Duration(seconds: 3));
      final videos = <_FakeVideo>[];
      giftVideoController = (path) {
        final v = _FakeVideo(
          const Duration(seconds: 12),
          const Size(720, 1280),
        );
        videos.add(v);
        return v;
      };
      addTearDown(() {
        GiftArtCache.instance = cache;
        giftVideoController = controller;
      });
      final engine = await _pump(
        tester,
        catalog: _catalog(url: _mp4Url, video: ArtVideo.plain),
      );
      engine.chat.add(const LiveChatJoined(_layla));
      await tester.pump();
      await tester.pump();
      // The car is shown (waiting for its file) at once; the download
      // takes 3 s.
      expect(_car, findsOneWidget);
      await _advance(tester, const Duration(milliseconds: 3200));
      expect(videos, hasLength(1));
      expect(videos.single.value.isPlaying, isTrue);
      // A portrait video covers the screen.
      final box = tester.widget<FittedBox>(
        find.descendant(of: _car, matching: find.byType(FittedBox)),
      );
      expect(box.fit, BoxFit.cover);
      expect(box.alignment, Alignment.bottomCenter);
      // 11.7 s into the video (about 14.8 s after the join; the 10 s from
      // the join cut it before): still there.
      await _advance(tester, const Duration(milliseconds: 11700));
      expect(_car, findsOneWidget);
      expect(videos.single.value.isPlaying, isTrue);
      // It ends: the car leaves.
      await _advance(tester, const Duration(milliseconds: 600));
      expect(_car, findsNothing);
    });
  });

  group('full screen', () {
    /// The layer's picture (logical pixels), read back as RGBA.
    Future<({ui.Image image, ByteData data})> capture(
      WidgetTester tester,
    ) async {
      final render =
          _boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      return (await tester.runAsync(() async {
        final image = render.toImageSync();
        final data = (await image.toByteData())!;
        return (image: image, data: data);
      }))!;
    }

    int alpha(ByteData data, int width, int x, int y) =>
        data.getUint8((y * width + x) * 4 + 3);

    for (final viewport in GoldenViewport.values) {
      for (final language in [AppLanguage.ar, AppLanguage.en]) {
        final w = viewport.logicalSize.width.toInt();
        final h = viewport.logicalSize.height.toInt();
        for (final (shape, width) in [('portrait', 100), ('square', 200)]) {
          testWidgets('a $shape car covers the whole ${w}x$h screen '
              '(${language.name})', (tester) async {
            VipSvga.clock = () => _now(tester);
            await _svga(tester, (f) => file = f, seconds: 6, width: width);
            final engine = await _pump(
              tester,
              catalog: _catalog(),
              viewport: viewport,
              language: language,
            );
            engine.chat.add(const LiveChatJoined(_layla));
            await _untilDrawing(tester);
            await tester.pump(const Duration(milliseconds: 500));
            // The car's box is the whole screen.
            expect(tester.getRect(_car), Offset.zero & viewport.logicalSize);
            final (:image, :data) = await capture(tester);
            expect((image.width, image.height), (w, h));
            // Every corner, the middle and the edges' middles are the art:
            // no band of the room left (D280's full width left the top).
            for (final (x, y) in [
              (0, 0),
              (w - 1, 0),
              (0, h - 1),
              (w - 1, h - 1),
              (w ~/ 2, h ~/ 2),
              (w ~/ 2, 0),
              (0, h ~/ 2),
              (w - 1, h ~/ 2),
            ]) {
              expect(alpha(data, w, x, y), 255, reason: '($x, $y)');
            }
            image.dispose();
          });
        }
      }
    }

    testWidgets('a landscape car keeps the full width at the bottom; '
        'above it the room shows through (nothing is painted there)', (
      tester,
    ) async {
      VipSvga.clock = () => _now(tester);
      // 400 × 200: on 393 wide, 196.5 high at the bottom.
      await _svga(tester, (f) => file = f, seconds: 6, width: 400);
      final engine = await _pump(tester, catalog: _catalog());
      engine.chat.add(const LiveChatJoined(_layla));
      await _untilDrawing(tester);
      await tester.pump(const Duration(milliseconds: 500));
      final (:image, :data) = await capture(tester);
      expect(alpha(data, 393, 0, 851), 255);
      expect(alpha(data, 393, 392, 851), 255);
      expect(alpha(data, 393, 196, 852 - 190), 255);
      expect(alpha(data, 393, 196, 852 - 205), 0);
      expect(alpha(data, 393, 196, 10), 0);
      image.dispose();
    });
  });

  testWidgets('reduced motion: as before, no car plays', (tester) async {
    VipSvga.clock = () => _now(tester);
    await _svga(tester, (f) => file = f, seconds: 6);
    final engine = FakeLiveMediaEngine()..present.add('user-0');
    setViewport(tester, GoldenViewport.phone);
    await pumpScreen(
      tester,
      const _Live(),
      disableAnimations: true,
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
    final keep = container.listen(liveChatProvider('room-0'), (_, _) {});
    addTearDown(keep.close);
    await container
        .read(liveChatProvider('room-0').notifier)
        .attach(engine, enabled: true, muted: false);
    await tester.pump();
    engine.chat.add(const LiveChatJoined(_layla));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(_drawing(tester), isFalse);
    expect(_car, findsNothing);
    // (The chat's own timers.)
    await tester.pump(const Duration(seconds: 10));
  });
}
