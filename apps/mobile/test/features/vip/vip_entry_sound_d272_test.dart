// D272 (owner: the VIP entry car stutters, freezes and has no sound): the
// SVGA read on another isolate into plain data (its sounds' timing), the
// big clip drawn live from a short window, and the sound's lifecycle.
import 'dart:io' show ZLibCodec;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_effect_sound.dart';
import 'package:kabso_live/features/vip/presentation/vip_svga.dart';
import 'package:material_ui/material_ui.dart';

/// A tiny protobuf writer (the SVGA 2.x MovieEntity fields).
class _Pb {
  final _b = BytesBuilder();

  void _varint(int v) {
    var x = v;
    while (x >= 0x80) {
      _b.addByte((x & 0x7f) | 0x80);
      x >>= 7;
    }
    _b.addByte(x);
  }

  void int32(int field, int v) {
    _varint(field << 3);
    _varint(v);
  }

  void float(int field, double v) {
    _varint((field << 3) | 5);
    _b.add((ByteData(4)..setFloat32(0, v, Endian.little)).buffer.asUint8List());
  }

  void bytes(int field, List<int> v) {
    _varint((field << 3) | 2);
    _varint(v.length);
    _b.add(v);
  }

  void string(int field, String v) => bytes(field, v.codeUnits);

  void message(int field, void Function(_Pb m) build) {
    final m = _Pb();
    build(m);
    bytes(field, m.done());
  }

  Uint8List done() => _b.toBytes();
}

/// A fake MP3 (its ID3 header and some bytes).
final _mp3 = Uint8List.fromList([
  0x49,
  0x44,
  0x33,
  4,
  0,
  0,
  ...List.filled(40, 7),
]);

Future<Uint8List> _png(int w, int h) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = const Color(0xFFFF0000),
  );
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// An SVGA of [frames] frames at [fps] on a 100 × 200 canvas: one picture
/// per frame (`f0`…, 100 × 200, drawn full size like the owner's peacock),
/// plus a sound `s` from frame 2 (120 ms in) to 6, and `t` without an end.
Future<Uint8List> _svga({int frames = 8, int fps = 20}) async {
  final png = await _png(100, 200);
  final pb = _Pb()
    ..string(1, '2.0.0')
    ..message(2, (m) {
      m
        ..float(1, 100)
        ..float(2, 200)
        ..int32(3, fps)
        ..int32(4, frames);
    });
  for (var i = 0; i < frames; i++) {
    pb
      ..message(3, (m) {
        m
          ..string(1, 'f$i')
          ..bytes(2, png);
      })
      ..message(4, (m) {
        m.string(1, 'f$i');
        for (var j = 0; j < frames; j++) {
          m.message(2, (f) {
            if (j != i) return; // hidden (alpha 0).
            f
              ..float(1, 1)
              ..message(2, (l) {
                l
                  ..float(3, 100)
                  ..float(4, 200);
              })
              ..message(3, (t) {
                t
                  ..float(1, 1)
                  ..float(4, 1);
              });
          });
        }
      });
  }
  pb
    ..message(3, (m) {
      m
        ..string(1, 's')
        ..bytes(2, _mp3);
    })
    ..message(3, (m) {
      m
        ..string(1, 't')
        ..bytes(2, _mp3);
    })
    ..message(5, (m) {
      m
        ..string(1, 's')
        ..int32(2, 2)
        ..int32(3, 6)
        ..int32(4, 120)
        ..int32(5, 900);
    })
    ..message(5, (m) => m.string(1, 't'));
  return Uint8List.fromList(ZLibCodec().encode(pb.done()));
}

class _Player implements AudioPlayer {
  new(this.log);

  final List<String> log;
  Duration? position;
  bool stopped = false;
  bool disposed = false;

  @override
  Future<void> setAudioContext(AudioContext ctx) async {}

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    this.position = position;
    if (source is BytesSource) log.add('play ${source.bytes.length}');
  }

  @override
  Future<void> stop() async {
    stopped = true;
    log.add('stop');
  }

  @override
  Future<void> dispose() async => disposed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Uint8List file;
  late List<_Player> players;
  late List<String> log;
  final foreground = GiftEffectSound.foreground;
  final soundEnabled = GiftEffectSound.enabled;
  final clock = VipSvga.clock;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    players = [];
    log = [];
    GiftEffectSound.enabled = true;
    GiftEffectSound.foreground = () => true;
    GiftEffectSound.newPlayer = () {
      final p = _Player(log);
      players.add(p);
      return p;
    };
    VipSvga.enabled = true;
    VipSvgaCache.fetch = (url) async => file;
  });

  tearDown(() {
    GiftEffectSound.enabled = soundEnabled;
    GiftEffectSound.foreground = foreground;
    GiftEffectSound.newPlayer = AudioPlayer.new;
    VipSvga.enabled = false;
    VipSvgaCache.clipPixels = 12 * 1000 * 1000;
    VipSvga.clock = clock;
    VipSvgaCache.clear();
  });

  group('VipSvgaDoc.parse', () {
    testWidgets('reads the sounds (frames, timing) apart from the pictures, '
        'and what each frame draws', (tester) async {
      await tester.runAsync(() async => file = await _svga());
      final doc = VipSvgaDoc.parse(file);
      expect(doc.viewBox, const Size(100, 200));
      expect(doc.fps, 20);
      expect(doc.frameCount, 8);
      expect(doc.images.keys, isNot(contains('s')));
      expect(doc.images, hasLength(8));
      expect(doc.frameKeys[3], ['f3']);
      expect(doc.drawn['f3'], const Size(100, 200));
      final s = doc.sounds.firstWhere((s) => s.key == 's');
      expect(
        (s.startFrame, s.endFrame, s.startTime, s.totalTime),
        (2, 6, 120, 900),
      );
      expect(s.bytes, _mp3);
      expect(s.clip.startAt, const Duration(milliseconds: 120));
      // No end: the whole clip.
      final t = doc.sounds.firstWhere((s) => s.key == 't');
      expect((t.startFrame, t.endFrame), (0, 8));
    });

    test('a picture is decoded at the size it is drawn, never bigger', () {
      const doc = VipSvgaDoc(
        viewBox: Size(100, 200),
        fps: 20,
        frameCount: 1,
        images: {},
        sprites: [],
        frameKeys: [[]],
        drawn: {'a': Size(50, 100)},
        sounds: [],
      );
      expect(doc.decodeSize('a', const Size(400, 800), 2), (
        width: 100,
        height: 200,
      ));
      expect(doc.decodeSize('a', const Size(40, 80), 4), (
        width: 40,
        height: 80,
      ));
    });
  });

  group('the big clip', () {
    testWidgets('is drawn live from about a second of decoded pictures', (
      tester,
    ) async {
      await tester.runAsync(() async {
        file = await _svga(frames: 60);
        VipSvgaCache.clipPixels = 1000;
        final clip = (await VipSvgaCache.load(
          'https://a/car.svga',
          maxSide: 200,
        ))!;
        expect(clip.live, isNotNull);
        expect(clip.frames, isEmpty);
        expect(clip.frameCount, 60);
        expect(clip.duration, const Duration(seconds: 3));
        final reader = VipSvgaReader(clip.live!);
        await reader.want(0);
        expect(reader.ready(0), isTrue);
        expect(reader.ready(reader.ahead), isTrue);
        expect(reader.ready(reader.ahead + 2), isFalse);
        expect(reader.held, reader.ahead + 1);
        await reader.want(40);
        expect(reader.ready(40), isTrue);
        // The pictures behind are released (one kept behind).
        expect(reader.ready(10), isFalse);
        expect(reader.held, lessThanOrEqualTo(reader.ahead + 2));
        reader.dispose();
        expect(reader.held, 0);
      });
    });

    testWidgets('a small clip keeps its frames', (tester) async {
      await tester.runAsync(() async {
        file = await _svga();
        final clip = (await VipSvgaCache.load(
          'https://a/b.svga',
          maxSide: 100,
        ))!;
        expect(clip.live, isNull);
        expect(clip.frames, hasLength(8));
        expect(clip.frames.first.height, 128); // the 128 bucket.
        expect(clip.sounds, hasLength(2));
      });
    });
  });

  group('the sound', () {
    const url = 'https://a/car.svga';

    Future<void> ready(WidgetTester tester) async {
      // The clips follow the test's clock.
      VipSvga.clock = () => Duration(
        microseconds: tester.binding.clock.now().microsecondsSinceEpoch,
      );
      await tester.runAsync(() async {
        file = await _svga();
        // The size the car asks for (128 × the test's 3 device pixels).
        await VipSvgaCache.load(url, maxSide: 384);
      });
    }

    // The clip was read in the real zone: its callbacks run there.
    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }

    Widget car({
      bool sound = true,
      VoidCallback? onDone,
      ValueChanged<Duration>? onStarted,
      Key? key,
    }) => SizedBox.square(
      key: key,
      dimension: 128,
      child: VipSvga(
        url: url,
        once: true,
        sound: sound,
        onDone: onDone,
        onStarted: onStarted,
      ),
    );

    testWidgets('starts with the car at its frame (from its start time), '
        'stops when it ends', (tester) async {
      await ready(tester);
      var done = 0;
      Duration? length;
      await tester.pumpWidget(
        Center(
          child: car(onDone: () => done++, onStarted: (d) => length = d),
        ),
      );
      await settle(tester);
      expect(length, const Duration(milliseconds: 400));
      // `t` from the start; `s` from frame 2 (100 ms at 20 fps).
      expect(log, ['play 46']);
      await tester.pump(const Duration(milliseconds: 120));
      expect(log, ['play 46', 'play 46']);
      expect(players.last.position, const Duration(milliseconds: 120));
      expect(VipSvgaAudio.current, isNotNull);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(done, 1);
      expect(players.every((p) => p.stopped && p.disposed), isTrue);
      expect(VipSvgaAudio.current, isNull);
    });

    testWidgets('removed before its end: the sound stops', (tester) async {
      await ready(tester);
      await tester.pumpWidget(Center(child: car()));
      await settle(tester);
      expect(players, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(players.single.stopped, isTrue);
      expect(players.single.disposed, isTrue);
    });

    testWidgets("a second entrance stops the first one's sound (never "
        'two together)', (tester) async {
      await ready(tester);
      Widget row(List<Widget> children) => Directionality(
        textDirection: TextDirection.ltr,
        child: Row(children: children),
      );
      await tester.pumpWidget(row([car(key: const Key('a'))]));
      await settle(tester);
      final first = players.single;
      await tester.pumpWidget(
        row([car(key: const Key('a')), car(key: const Key('b'))]),
      );
      await settle(tester);
      expect(first.stopped, isTrue);
      expect(players.where((p) => !p.stopped), hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('silent: sound off, reduced motion, or the app in the '
        'background', (tester) async {
      await ready(tester);
      await tester.pumpWidget(Center(child: car(sound: false)));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(const SizedBox());
      // Reduced motion: the still (here nothing) and no sound.
      var done = 0;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Center(child: car(onDone: () => done++)),
        ),
      );
      await tester.pump();
      expect(done, 1);
      await tester.pumpWidget(const SizedBox());
      GiftEffectSound.foreground = () => false;
      await tester.pumpWidget(Center(child: car()));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 200));
      expect(players, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the app leaving the foreground stops it', (tester) async {
      await ready(tester);
      await tester.pumpWidget(Center(child: car()));
      await settle(tester);
      expect(players, hasLength(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(players.single.stopped, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
