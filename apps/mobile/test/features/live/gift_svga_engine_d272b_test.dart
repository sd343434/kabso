// D272b (owner: «حاول اصلاح المشكلة بالكامل»): the gifts' full-screen SVGA
// on the app's one SVGA engine — read on another isolate (ahead, as the
// gift arrives), drawn from decoded pictures with its own sound in step,
// a file with vector shapes still on the package's player.
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/svga/svga_engine.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_gift_effects.dart';
import 'package:kabso_live/features/live/data/gift_art_cache.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_effect_sound.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/svga_fixture.dart';

class _Cache extends GiftArtCache {
  final loads = <String>[];

  @override
  Future<Uint8List> load(String url) async {
    loads.add(url);
    throw StateError('offline');
  }
}

void main() {
  const url = 'https://cdn.test/gifts/peacock.svga';
  late Uint8List file;
  late List<FakeSvgaPlayer> players;
  late List<String> log;
  late List<String> fetched;
  final fetch = SvgaDocs.fetch;
  final foreground = GiftEffectSound.foreground;
  final cache = GiftArtCache.instance;

  setUp(() {
    players = [];
    log = [];
    fetched = [];
    GiftEffectSound.foreground = () => true;
    GiftEffectSound.newPlayer = () {
      final p = FakeSvgaPlayer(log);
      players.add(p);
      return p;
    };
    SvgaDocs.fetch = (source) async {
      fetched.add(source);
      return file;
    };
  });

  tearDown(() {
    SvgaDocs.fetch = fetch;
    SvgaDocs.residentPixels = 12 * 1000 * 1000;
    SvgaDocs.clear();
    GiftEffectSound.foreground = foreground;
    GiftEffectSound.newPlayer = AudioPlayer.new;
    GiftArtCache.instance = cache;
    KGiftEffect.animate = false;
    LiveGiftEffects.prefetchArt = false;
  });

  group('the shared engine', () {
    testWidgets('reads what a gift draws past its canvas, and which files '
        'need the vector player', (tester) async {
      await tester.runAsync(() async {
        file = await svgaFixture();
        final doc = SvgaDoc.parse(file);
        expect(doc.vector, isFalse);
        expect(doc.bounds, const Rect.fromLTWH(0, 0, 100, 200));
        expect(doc.duration, const Duration(milliseconds: 400));
        final vector = SvgaDoc.parse(await svgaFixture(vector: true));
        expect(vector.vector, isTrue);
        // The package's movie, from the same reading: every picture
        // decoded (at most its own size), the sounds for its player.
        final movie = await vector.toMovie(0.5);
        expect(movie.params.frames, 8);
        expect(movie.bitmapCache, hasLength(8));
        expect(movie.bitmapCache['f0']!.width, 50);
        expect(movie.audiosData.keys, containsAll(['s', 't']));
        expect(movie.sprites.first.frames.first.clipPath, isNotEmpty);
        movie.dispose();
      });
    });

    testWidgets('a small clip keeps its pictures (a combo replays at once); '
        'a big one is read through a window', (tester) async {
      await tester.runAsync(() async {
        file = await svgaFixture(frames: 40);
        final small = (await SvgaDocs.live(url, scale: 1))!;
        expect(small.resident, hasLength(40));
        expect(identical(await SvgaDocs.live(url, scale: 1), small), isTrue);
        // The same file is read once.
        expect(fetched, [url]);
        SvgaDocs.residentPixels = 1000;
        final big = (await SvgaDocs.live(url, scale: 2))!;
        expect(big.resident, isNull);
        final reader = SvgaReader(big);
        await reader.want(0);
        expect(reader.ready(0), isTrue);
        expect(reader.held, lessThanOrEqualTo(reader.ahead + 1));
        reader.dispose();
      });
    });
  });

  group('the gift effect', () {
    // The test view: 2400 physical pixels across a 100-unit canvas.
    const scale = 2400 / 100;

    Future<void> ready(WidgetTester tester) => tester.runAsync(() async {
      file = await svgaFixture();
      await SvgaDocs.live(url, scale: scale);
    });

    // The clip was read in the real zone: its callbacks run there.
    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }

    Widget effect({bool soundOn = true, VoidCallback? onDone}) =>
        Directionality(
          textDirection: TextDirection.ltr,
          child: KGiftEffect(
            animationKey: null,
            animationUrl: url,
            animationFormat: GiftAnimationFormat.svga,
            soundOn: soundOn,
            onDone: onDone,
          ),
        );

    testWidgets('plays on the engine with its own sound in step, then ends '
        'and stops the sound', (tester) async {
      KGiftEffect.animate = true;
      await ready(tester);
      var done = 0;
      await tester.pumpWidget(effect(onDone: () => done++));
      await settle(tester);
      await settle(tester);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is SvgaFramePainter,
        ),
        findsOneWidget,
      );
      // `t` from the first frame; `s` from frame 2 (100 ms at 20 fps),
      // 120 ms into its sound.
      expect(log, ['play 46']);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));
      expect(log, ['play 46', 'play 46']);
      expect(players.last.position, const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(done, 1);
      expect(players.every((p) => p.stopped && p.disposed), isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('silent when the gift sounds are off', (tester) async {
      KGiftEffect.animate = true;
      await ready(tester);
      await tester.pumpWidget(effect(soundOn: false));
      await settle(tester);
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 200));
      expect(players, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('read ahead', () {
    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
          currentUserProvider.overrideWithValue(testUser()),
        ],
      );
      addTearDown(c.dispose);
      c.listen(liveGiftEffectsProvider('room-0'), (_, _) {});
      return c;
    }

    LiveGift gift(String id, Map<String, Object?> art) =>
        LiveGift.fromJson(liveGiftJson(id: id, art: art));

    test('an animated gift is read as it arrives, the one waiting too; an '
        'MP4 and an MP3 are downloaded', () async {
      LiveGiftEffects.prefetchArt = true;
      final art = GiftArtCache.instance = _Cache();
      file = Uint8List(0);
      container().read(liveGiftEffectsProvider('room-0').notifier)
        ..show(gift('g1', {'animationUrl': url, 'animationFormat': 'SVGA'}))
        ..show(
          gift('g2', {
            'animationUrl': 'https://cdn.test/gifts/b.svga',
            'animationFormat': 'SVGA',
          }),
        )
        ..show(
          gift('g3', {
            'animationUrl': 'https://cdn.test/gifts/c.mp4',
            'animationFormat': 'MP4',
            'audioUrl': 'https://cdn.test/gifts/c.mp3',
          }),
        );
      await Future<void>.delayed(Duration.zero);
      expect(fetched, [url, 'https://cdn.test/gifts/b.svga']);
      expect(art.loads, [
        'https://cdn.test/gifts/c.mp4',
        'https://cdn.test/gifts/c.mp3',
      ]);
    });
  });
}
