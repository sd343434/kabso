// D272: the owner's entry car (peacock, 13.8 MB, 75 frames of 563 × 1000
// at 12 fps, with its MP3) before and after the engine's rework. Runs only
// with VIP_ENTRY_SVGA=<path to the .svga> (the art is not in the repo):
//   VIP_ENTRY_SVGA=… flutter test test/features/vip/vip_entry_bench_d272_test.dart
// It prints the numbers; the checks only guard the new path's budget.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_svga/flutter_svga.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/vip/presentation/vip_svga.dart';
import 'package:material_ui/material_ui.dart';

final String? _file = Platform.environment['VIP_ENTRY_SVGA'];
bool get _skip => _file == null || !File(_file!).existsSync();

/// The longest the UI isolate went without running a 1 ms timer while
/// [work] ran (how long the UI would have been frozen).
Future<({T result, int ms, int stallMs})> _timed<T>(
  Future<T> Function() work,
) async {
  var last = DateTime.now();
  var stall = 0;
  final timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
    final now = DateTime.now();
    stall = math.max(stall, now.difference(last).inMilliseconds);
    last = now;
  });
  final sw = Stopwatch()..start();
  final result = await work();
  final ms = sw.elapsedMilliseconds;
  timer.cancel();
  final tail = DateTime.now().difference(last).inMilliseconds;
  return (result: result, ms: ms, stallMs: math.max(stall, tail));
}

/// The engine as it was (D258–D271): the package's parser on the UI isolate
/// (every picture decoded full size), then every frame drawn at once.
List<ui.Image> _legacyRender(MovieEntity movie, int side) {
  final box = Size(movie.params.viewBoxWidth, movie.params.viewBoxHeight);
  final k = side / math.max(box.width, box.height);
  final w = (box.width * k).round();
  final h = (box.height * k).round();
  final paint = Paint()..filterQuality = FilterQuality.medium;
  return [
    for (var i = 0; i < movie.params.frames; i++)
      () {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..scale(k);
        for (final sprite in movie.sprites) {
          if (i >= sprite.frames.length) continue;
          final bitmap = movie.bitmapCache[sprite.imageKey];
          final f = sprite.frames[i];
          if (bitmap == null || !f.hasLayout() || f.alpha <= 0) continue;
          canvas
            ..save()
            ..transform(
              Float64List.fromList([
                f.transform.a, f.transform.b, 0, 0, //
                f.transform.c, f.transform.d, 0, 0,
                0, 0, 1, 0,
                f.transform.tx, f.transform.ty, 0, 1,
              ]),
            )
            ..drawImageRect(
              bitmap,
              Rect.fromLTWH(
                0,
                0,
                bitmap.width.toDouble(),
                bitmap.height.toDouble(),
              ),
              Rect.fromLTWH(0, 0, f.layout.width, f.layout.height),
              paint,
            )
            ..restore();
        }
        final picture = recorder.endRecording();
        final image = picture.toImageSync(w, h);
        picture.dispose();
        return image;
      }(),
  ];
}

/// One frame painted on a 1080 × 1918 screen and rasterized (ms).
Future<double> _paintMs(void Function(Canvas canvas) draw) async {
  final sw = Stopwatch()..start();
  const n = 20;
  for (var i = 0; i < n; i++) {
    final recorder = ui.PictureRecorder();
    draw(Canvas(recorder));
    final picture = recorder.endRecording();
    final image = await picture.toImage(1080, 1918);
    picture.dispose();
    image.dispose();
  }
  return sw.elapsedMicroseconds / 1000 / n;
}

void main() {
  // The car on a 1080-pixel-wide phone: 1080 × 1918 → the 1024 bucket.
  const side = 1024;

  testWidgets('D272 bench: before', skip: _skip, (tester) async {
    await tester.runAsync(() async {
      final bytes = await File(_file!).readAsBytes();
      final parsed = await _timed(
        () => SVGAParser.shared.decodeFromBuffer(bytes),
      );
      final movie = parsed.result;
      final bitmaps = movie.bitmapCache.values.fold(
        0,
        (s, b) => s + b.width * b.height,
      );
      final rendered = await _timed(() async => _legacyRender(movie, side));
      final frames = rendered.result;
      final raster = await _timed(() async {
        for (final f in frames) {
          await f.toByteData();
        }
      });
      final px = frames.fold(0, (s, f) => s + f.width * f.height);
      final paint = await _paintMs(
        (c) => c.drawImageRect(
          frames[30],
          Offset.zero & const Size(577, 1024),
          Offset.zero & const Size(1080, 1918),
          Paint()..filterQuality = FilterQuality.medium,
        ),
      );
      // ignore: avoid_print, the bench's output.
      print(
        'BEFORE: decode ${parsed.ms} ms (UI stall ${parsed.stallMs} ms), '
        'full-size bitmaps ${bitmaps ~/ 1000}k px '
        '(${(bitmaps * 4 / 1e6).round()} MB); render ${rendered.ms} ms '
        '(UI stall ${rendered.stallMs} ms) + raster ${raster.ms} ms; '
        'frames ${frames.length} × ${frames.first.width}×'
        '${frames.first.height} = ${px ~/ 1000}k px '
        '(${(px * 4 / 1e6).round()} MB) vs the 24 M cache budget; '
        'per-frame paint ${paint.toStringAsFixed(2)} ms; '
        'sound: ${movie.audios.length} entry, played: no',
      );
      movie.dispose();
      for (final f in frames) {
        f.dispose();
      }
    });
  });

  testWidgets('D272 bench: after', skip: _skip, (tester) async {
    await tester.runAsync(() async {
      final bytes = await File(_file!).readAsBytes();
      final read = await _timed(() => VipSvgaDoc.read(bytes));
      final doc = read.result;
      final made = await _timed(() => VipSvgaCache.render(doc, side));
      final clip = made.result;
      expect(clip.live, isNotNull);
      final reader = VipSvgaReader(clip.live!);
      final primed = await _timed(() => reader.want(0));
      expect(reader.ready(0), isTrue);
      // Play it through at its own pace: how many frames were late.
      var late = 0;
      var maxHeld = 0;
      var maxStall = 0;
      final sw = Stopwatch()..start();
      for (var f = 0; f < doc.frameCount; f++) {
        final due = Duration(microseconds: (f * 1e6 / doc.fps).round());
        final wait = due - sw.elapsed;
        if (wait > Duration.zero) await Future<void>.delayed(wait);
        final step = await _timed(() async {
          unawaited(reader.want(f));
        });
        maxStall = math.max(maxStall, step.stallMs);
        if (!reader.ready(f)) late++;
        maxHeld = math.max(maxHeld, reader.held);
      }
      final first = reader.pictures.values.first;
      final held = maxHeld * first.width * first.height;
      final k = clip.scale;
      final paint = await _paintMs((c) {
        c.scale(1080 / doc.viewBox.width);
        doc.drawFrame(c, doc.frameCount - 1, reader.pictures);
      });
      reader.dispose();
      final s = doc.sounds.single;
      // ignore: avoid_print, the bench's output.
      print(
        'AFTER: read ${read.ms} ms on another isolate (UI stall '
        '${read.stallMs} ms); clip ${made.ms} ms (live, scale '
        '${k.toStringAsFixed(3)}); first second decoded in ${primed.ms} ms '
        '(UI stall ${primed.stallMs} ms); played at ${doc.fps} fps: '
        '$late of ${doc.frameCount} frames late, at most $maxHeld pictures '
        '${first.width}×${first.height} held (${held ~/ 1000}k px, '
        '${(held * 4 / 1e6).round()} MB); per-frame paint '
        '${paint.toStringAsFixed(2)} ms; sound "${s.key}" frames '
        '${s.startFrame}–${s.endFrame}, ${s.totalTime} ms, '
        '${s.bytes.length} bytes',
      );
      expect(maxHeld, lessThanOrEqualTo(doc.fps + 3));
      expect(read.stallMs, lessThan(400));
    });
  });
}
