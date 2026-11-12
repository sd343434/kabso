// v1.136-social (D384, CONVENTIONS §10.173.2): the VIP animated picture's
// upload — the cut-out frames, cropped to one head-and-shoulders square,
// stacked one under another in a PNG strip with alpha (the server re-encodes
// it into a looping animated WebP). Drawn with dart:ui: no image package.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:kabso_live/features/vip/animated_avatar/cutout_frames.dart';

/// The clip shows no person in enough frames.
class CutoutNoPersonException implements Exception {
  const new();
}

/// Even the smallest strip is over [CutoutLimits.maxBytes].
class CutoutTooLargeException implements Exception {
  const new();
}

/// The strip to upload: a PNG of [frames] square frames of [side] px, one
/// under another, and the same picture decoded ([image]) for the preview.
@immutable
class CutoutStrip {
  const new({
    required this.png,
    required this.side,
    required this.frames,
    required this.image,
  });

  final Uint8List png;
  final int side;
  final int frames;
  final ui.Image image;
}

Future<ui.Image> _decode(Uint8List rgba, int width, int height) {
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    width,
    height,
    ui.PixelFormat.rgba8888,
    done.complete,
  );
  return done.future;
}

/// Crops every frame of [frames] to their shared head-and-shoulders square,
/// with the person's alpha, and stacks them into a PNG strip of [side] px
/// frames (at most [CutoutLimits.maxFrames], evenly spread). Over
/// [CutoutLimits.maxBytes] it tries smaller frames (256, then 192 px).
/// Throws [CutoutNoPersonException] or [CutoutTooLargeException].
Future<CutoutStrip> composeCutoutStrip(
  List<CutoutFrame> frames, {
  int side = CutoutLimits.side,
}) async {
  final box = headAndShoulders(frames);
  if (box == null) throw const CutoutNoPersonException();
  final kept = evenlyCapped(frames);
  final images = <ui.Image>[];
  try {
    for (final f in kept) {
      final rgba = Uint8List.fromList(f.rgba);
      for (var i = 0, p = 3; i < f.alpha.length; i++, p += 4) {
        rgba[p] = f.alpha[i];
      }
      images.add(await _decode(rgba, f.width, f.height));
    }
    for (final s in [side, 256, 192]) {
      if (s > side) continue;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;
      final src = ui.Rect.fromLTWH(
        box.left.toDouble(),
        box.top.toDouble(),
        box.side.toDouble(),
        box.side.toDouble(),
      );
      for (var i = 0; i < images.length; i++) {
        canvas.drawImageRect(
          images[i],
          src,
          ui.Rect.fromLTWH(0, (i * s).toDouble(), s.toDouble(), s.toDouble()),
          paint,
        );
      }
      final picture = recorder.endRecording();
      final strip = await picture.toImage(s, s * images.length);
      picture.dispose();
      final data = await strip.toByteData(format: ui.ImageByteFormat.png);
      final png = data!.buffer.asUint8List();
      if (png.length <= CutoutLimits.maxBytes) {
        return CutoutStrip(
          png: png,
          side: s,
          frames: images.length,
          image: strip,
        );
      }
      strip.dispose();
    }
    throw const CutoutTooLargeException();
  } finally {
    for (final i in images) {
      i.dispose();
    }
  }
}
