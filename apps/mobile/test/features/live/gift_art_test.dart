// D126: gift art hosted on the server (CONVENTIONS §10.23, openapi
// v1.26.2-live) — the image fallback chain (hosted → bundled → Kabso's gift
// box), the disk cache (hit, shared download, failure and retry, size
// limits, prefetch of small animations only), the SVGA's own sound (started
// at its frames, never in the background, stopped with the effect) and the
// effect layer handing the hosted URLs to the effect.

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_gift_effects.dart';
import 'package:kabso_live/features/live/data/gift_art_cache.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_effect_sound.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_effects_layer.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _png =
    'https://media.example.test/media/gifts/angel_warrior/'
    '1eaf9644281e113f96c7cb40293572e6.png';
const _svga =
    'https://media.example.test/media/gifts/angel_warrior/'
    'd1c23c640419becb8269caa182e98891.svga';

/// A cache that answers from a map (or fails), counting loads.
class _MemoryCache extends GiftArtCache {
  new([this.files = const {}]);

  final Map<String, Uint8List> files;
  final loads = <String>[];

  @override
  Future<Uint8List> load(String url) async {
    loads.add(url);
    final bytes = files[url];
    if (bytes == null) throw StateError('offline');
    return bytes;
  }
}

/// Answers every GET with [body] (or [status]), counting requests.
class _BytesAdapter implements HttpClientAdapter {
  new(this.body, {this.status = 200});

  Uint8List body;
  int status;
  Completer<void>? gate;
  final requests = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri);
    await gate?.future;
    return ResponseBody.fromBytes(
      status == 200 ? body : Uint8List(0),
      status,
      headers: {
        Headers.contentLengthHeader: ['${status == 200 ? body.length : 0}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A player that records what it was asked to do.
class _Player implements AudioPlayer {
  final played = <int>[];
  bool stopped = false;
  bool disposed = false;
  AudioContext? context;

  @override
  Future<void> setAudioContext(AudioContext ctx) async => context = ctx;

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    if (source is BytesSource) played.add(source.bytes.length);
  }

  @override
  Future<void> stop() async => stopped = true;

  @override
  Future<void> dispose() async => disposed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Finder _assetImage(String name) => find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName == name,
);

void main() {
  final original = GiftArtCache.instance;
  tearDown(() => GiftArtCache.instance = original);

  group('KGiftImage: hosted, else bundled, else the gift box', () {
    // Each test decodes afresh (the image cache outlives a test).
    tearDown(() => PaintingBinding.instance.imageCache.clear());

    testWidgets('a hosted image is drawn from the cache', (tester) async {
      final bytes = File('assets/live_room_icons/close.png').readAsBytesSync();
      final cache = GiftArtCache.instance = _MemoryCache({_png: bytes});
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: KGiftImage('gift_angel_warrior', imageUrl: _png),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      expect(find.byKey(KGiftImage.networkKey), findsOneWidget);
      expect(find.byKey(KGiftImage.fallbackKey), findsNothing);
      expect(cache.loads, [_png]);
      final image = tester.widget<Image>(find.byKey(KGiftImage.networkKey));
      expect(image.image, const GiftArtImage(_png));
    });

    testWidgets('a hosted image that fails shows the bundled one (here '
        'missing too: the faded gift box)', (tester) async {
      final cache = GiftArtCache.instance = _MemoryCache();
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: KGiftImage('gift_angel_warrior', imageUrl: _png),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      expect(cache.loads, [_png]);
      expect(
        _assetImage('assets/gifts/gift_angel_warrior.png'),
        findsOneWidget,
      );
      expect(find.byKey(KGiftImage.fallbackKey), findsOneWidget);
    });

    testWidgets('no hosted image (or a refused URL): the bundled one, no '
        'download', (tester) async {
      final cache = GiftArtCache.instance = _MemoryCache();
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              KGiftImage('gift_rose'),
              KGiftImage('gift_rose', imageUrl: 'ftp://x.test/a.png'),
            ],
          ),
        ),
      );
      expect(find.byKey(KGiftImage.networkKey), findsNothing);
      expect(_assetImage('assets/gifts/gift_rose.png'), findsNWidgets(2));
      expect(cache.loads, isEmpty);
    });
  });

  group('DiskGiftArtCache', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('gift_art_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    DiskGiftArtCache cacheWith(
      _BytesAdapter adapter, {
      int maxTotal = 1 << 30,
    }) => DiskGiftArtCache(
      dio: Dio()..httpClientAdapter = adapter,
      directory: () async => dir,
      maxTotalBytes: maxTotal,
      maxFileBytes: 1000,
    );

    test('downloads once, then reads the device (a cache hit); concurrent '
        'loads share one download', () async {
      final adapter = _BytesAdapter(Uint8List.fromList(List.filled(300, 7)))
        ..gate = Completer<void>();
      final cache = cacheWith(adapter);
      final a = cache.load(_svga);
      final b = cache.load(_svga);
      await Future<void>.delayed(Duration.zero);
      adapter.gate!.complete();
      expect((await a).length, 300);
      expect((await b).length, 300);
      expect(adapter.requests, hasLength(1));
      expect(await cache.load(_svga), hasLength(300));
      expect(adapter.requests, hasLength(1));
      final file = File('${dir.path}/${DiskGiftArtCache.fileName(_svga)}');
      expect(file.existsSync(), isTrue);
      expect(DiskGiftArtCache.fileName(_svga), endsWith('.svga'));
      // A new cache over the same directory (the app restarted) still hits.
      expect(await cacheWith(adapter).load(_svga), hasLength(300));
      expect(adapter.requests, hasLength(1));
    });

    test(
      'a failed download throws, leaves nothing and is tried again',
      () async {
        final adapter = _BytesAdapter(
          Uint8List.fromList([1, 2, 3]),
          status: 404,
        );
        final cache = cacheWith(adapter);
        await expectLater(cache.load(_png), throwsA(isA<DioException>()));
        expect(dir.listSync(), isEmpty);
        adapter.status = 200;
        expect(await cache.load(_png), [1, 2, 3]);
        expect(adapter.requests, hasLength(2));
      },
    );

    test('refuses other schemes and files over the size limit', () async {
      final adapter = _BytesAdapter(Uint8List(2000));
      final cache = cacheWith(adapter);
      await expectLater(cache.load('ftp://x.test/a.svga'), throwsArgumentError);
      expect(adapter.requests, isEmpty);
      await expectLater(cache.load(_svga), throwsA(isA<DioException>()));
      expect(dir.listSync(), isEmpty);
    });

    test('keeps the cache under its limit, oldest-used out first', () async {
      final adapter = _BytesAdapter(Uint8List(400));
      final cache = cacheWith(adapter, maxTotal: 900);
      const one = 'https://m.test/media/gifts/a/1.png';
      const two = 'https://m.test/media/gifts/b/2.png';
      const three = 'https://m.test/media/gifts/c/3.png';
      await cache.load(one);
      File('${dir.path}/${DiskGiftArtCache.fileName(one)}')
          .setLastModifiedSync(DateTime(2020));
      await cache.load(two);
      await cache.load(three);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final names = dir.listSync().map((e) => e.uri.pathSegments.last).toSet();
      expect(names, {
        DiskGiftArtCache.fileName(two),
        DiskGiftArtCache.fileName(three),
      });
    });

    test('the panel prefetches only animations of at most 2 MB', () async {
      final cache = _MemoryCache();
      Map<String, Object?> art(String code, String? url, int? bytes) => {
        ...giftJson(code),
        'animationUrl': url,
        'animationBytes': bytes,
      };
      cache.prefetchSmallAnimations(
        GiftCatalogue.fromJson(
          giftCatalogueJson(
            codes: const [],
            extra: [
              art('rose', 'https://m.test/small.svga', 2 * 1024 * 1024),
              art('cake', 'https://m.test/big.svga', 16830815),
              art('crown', null, null),
            ],
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cache.loads, ['https://m.test/small.svga']);
    });
  });

  group('GiftEffectSound', () {
    final foreground = GiftEffectSound.foreground;
    late List<_Player> players;
    setUp(() {
      players = [];
      GiftEffectSound.newPlayer = () {
        final p = _Player();
        players.add(p);
        return p;
      };
    });
    tearDown(() {
      GiftEffectSound.newPlayer = AudioPlayer.new;
      GiftEffectSound.foreground = foreground;
    });

    GiftEffectSound sound() => GiftEffectSound([
      GiftSoundClip(
        key: 'a',
        startFrame: 0,
        endFrame: 152,
        bytes: Uint8List(10),
      ),
      GiftSoundClip(
        key: 'b',
        startFrame: 149,
        endFrame: 300,
        bytes: Uint8List(20),
      ),
    ]);

    test('each clip starts once at its frame, as media without audio focus '
        'on Android, and stops with the effect', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final s = sound()..onFrame(0);
      await Future<void>.delayed(Duration.zero);
      expect(players, hasLength(1));
      expect(players.single.played, [10]);
      expect(
        players.single.context?.android.audioFocus,
        AndroidAudioFocus.none,
      );
      expect(players.single.context?.android.usageType, AndroidUsageType.media);
      s
        ..onFrame(100)
        ..onFrame(149)
        ..onFrame(150);
      await Future<void>.delayed(Duration.zero);
      expect(players.map((p) => p.played), [
        [10],
        [20],
      ]);
      await s.stop();
      expect(players.every((p) => p.stopped && p.disposed), isTrue);
      s.onFrame(299);
      expect(players, hasLength(2));
    });

    test('nothing plays while the app is in the background', () async {
      GiftEffectSound.foreground = () => false;
      sound()
        ..onFrame(0)
        ..onFrame(200);
      await Future<void>.delayed(Duration.zero);
      expect(players, isEmpty);
    });
  });

  group('the effect layer', () {
    testWidgets('a hosted animated gift plays the effect with its URLs and '
        'ends when the effect says so', (tester) async {
      GiftArtCache.instance = _MemoryCache();
      setViewport(tester, GoldenViewport.android);
      final engine = FakeLiveMediaEngine();
      await pumpScreen(
        tester,
        const Scaffold(body: LiveGiftEffectsLayer(roomId: 'room-0')),
        liveGiftRepository: FakeLiveGiftRepository(),
        overrides: [currentUserProvider.overrideWithValue(testUser())],
      );
      await tester.pumpAndSettle();
      ProviderScope.containerOf(
        tester.element(find.byType(LiveGiftEffectsLayer)),
      ).read(liveGiftEffectsProvider('room-0').notifier).attach(engine);
      // 50 coins: not big by value; it plays because it has an animation.
      engine.chat.add(
        LiveGiftReceived(
          LiveGift.fromJson(
            liveGiftJson(
              code: 'confetti',
              quantity: 1,
              recipients: [giftUserJson('sara', 'Sara')],
              art: const {
                'imageUrl': _png,
                'animationUrl': _svga,
                'animationBytes': 16830815,
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final effect = tester.widget<KGiftEffect>(find.byType(KGiftEffect));
      expect(effect.animationUrl, _svga);
      expect(effect.imageUrl, _png);
      final banner = tester.widget<LiveGiftBanner>(find.byType(LiveGiftBanner));
      expect(banner.imageUrl, _png);
      // Tests do not decode SVGA (`KGiftEffect.animate` is off): the image
      // pops for the usual time, without holding for an animation.
      await tester.pump(LiveGiftEffects.bigTime);
      await tester.pump();
      expect(find.byType(KGiftEffect), findsNothing);
      await tester.pumpAndSettle();

      // An effect that fetches or plays an SVGA holds the screen until it
      // says it is done (here driven by hand), not the image's 3.2 s.
      final effects = ProviderScope.containerOf(
        tester.element(find.byType(LiveGiftEffectsLayer)),
      ).read(liveGiftEffectsProvider('room-0').notifier);
      engine.chat.add(
        LiveGiftReceived(
          LiveGift.fromJson(
            liveGiftJson(
              id: 'svga-2',
              code: 'confetti',
              quantity: 1,
              recipients: [giftUserJson('sara', 'Sara')],
              art: const {'animationUrl': _svga, 'animationBytes': 16830815},
            ),
          ),
        ),
      );
      await tester.pump();
      effects.bigHold('svga-2');
      await tester.pump(LiveGiftEffects.bigTime * 2);
      expect(find.byType(KGiftEffect), findsOneWidget);
      effects
        ..bigDone('other')
        ..bigDone('svga-2');
      await tester.pump();
      expect(find.byType(KGiftEffect), findsNothing);
      await tester.pumpAndSettle();
    });
  });
}
