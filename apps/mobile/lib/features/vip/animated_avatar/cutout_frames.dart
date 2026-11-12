// v1.136-social (D384, CONVENTIONS §10.173.2): the pixel work of the VIP
// animated picture «صورة متحركة», in pure Dart (unit-tested): camera
// buffers to RGBA, upright and mirrored like the selfie preview, the
// person's alpha from the segmentation model's confidences, and the one
// head-and-shoulders square every frame is cropped to.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// The clip's limits (§10.173.2): 3 s at 15 frames a second (owner
/// 2026-11-12: 15, not 12), for a recording and a clip from the gallery.
abstract final class CutoutLimits {
  static const Duration length = Duration(seconds: 3);
  static const int fps = 15;
  static const int maxFrames = 45;

  /// Milliseconds between two kept frames (1000 / 15, rounded).
  static const int frameMs = 67;

  /// The frame side uploaded (the server takes 64–512).
  static const int side = 320;

  /// The strip upload limit (8 MiB).
  static const int maxBytes = 8 * 1024 * 1024;

  /// A frame shows the person when at least this share of it is them.
  static const double minPersonShare = 0.015;

  /// The clip is refused when fewer frames than this share show a person.
  static const double minFramesWithPerson = 0.6;
}

/// One frame of the clip, upright as the member saw it in the preview:
/// [rgba] pixels (row by row, 4 bytes each) and the person's [alpha] (one
/// byte a pixel; 0 = background).
@immutable
class CutoutFrame {
  const new({
    required this.width,
    required this.height,
    required this.rgba,
    required this.alpha,
  });

  final int width;
  final int height;
  final Uint8List rgba;
  final Uint8List alpha;
}

int _clamp255(num v) => v < 0 ? 0 : (v > 255 ? 255 : v.round());

/// An Android NV21 buffer (Y plane, then interleaved V/U at half size) to
/// RGBA (BT.601, full range, opaque).
Uint8List nv21ToRgba(Uint8List nv21, int width, int height) {
  final out = Uint8List(width * height * 4);
  final frame = width * height;
  for (var y = 0; y < height; y++) {
    final uvRow = frame + (y >> 1) * width;
    for (var x = 0; x < width; x++) {
      final yy = nv21[y * width + x];
      final uv = uvRow + (x & ~1);
      final v = nv21[uv] - 128;
      final u = nv21[uv + 1] - 128;
      final o = (y * width + x) * 4;
      out[o] = _clamp255(yy + 1.402 * v);
      out[o + 1] = _clamp255(yy - 0.344136 * u - 0.714136 * v);
      out[o + 2] = _clamp255(yy + 1.772 * u);
      out[o + 3] = 255;
    }
  }
  return out;
}

/// An iOS BGRA buffer ([bytesPerRow] may pad each row) to RGBA, opaque.
Uint8List bgraToRgba(Uint8List bgra, int width, int height, int bytesPerRow) {
  final out = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = y * bytesPerRow + x * 4;
      final o = (y * width + x) * 4;
      out[o] = bgra[i + 2];
      out[o + 1] = bgra[i + 1];
      out[o + 2] = bgra[i];
      out[o + 3] = 255;
    }
  }
  return out;
}

/// [data] ([channels] bytes a pixel) turned [quarterTurns] × 90° clockwise,
/// then mirrored left–right when [mirror] (the selfie preview's view).
({Uint8List data, int width, int height}) orientPixels(
  Uint8List data,
  int width,
  int height,
  int channels, {
  int quarterTurns = 0,
  bool mirror = false,
}) {
  final turns = quarterTurns % 4;
  final w = turns.isOdd ? height : width;
  final h = turns.isOdd ? width : height;
  final out = Uint8List(data.length);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var (nx, ny) = switch (turns) {
        1 => (height - 1 - y, x),
        2 => (width - 1 - x, height - 1 - y),
        3 => (y, width - 1 - x),
        _ => (x, y),
      };
      if (mirror) nx = w - 1 - nx;
      final i = (y * width + x) * channels;
      final o = (ny * w + nx) * channels;
      for (var c = 0; c < channels; c++) {
        out[o + c] = data[i + c];
      }
    }
  }
  return (data: out, width: w, height: h);
}

/// The person's alpha (0–255) at [outWidth] × [outHeight] from the model's
/// [confidences] ([maskWidth] × [maskHeight], upright, not mirrored),
/// sampled bilinearly with a soft edge (0.35 → 0, 0.65 → 255) and mirrored
/// left–right when [mirror].
Uint8List alphaFromConfidences(
  List<double> confidences,
  int maskWidth,
  int maskHeight,
  int outWidth,
  int outHeight, {
  bool mirror = false,
}) {
  final out = Uint8List(outWidth * outHeight);
  double at(int x, int y) => confidences[y * maskWidth + x];
  for (var y = 0; y < outHeight; y++) {
    final fy = ((y + 0.5) * maskHeight / outHeight - 0.5).clamp(
      0.0,
      maskHeight - 1.0,
    );
    final y0 = fy.floor();
    final y1 = math.min(y0 + 1, maskHeight - 1);
    final ty = fy - y0;
    for (var x = 0; x < outWidth; x++) {
      final fx = ((x + 0.5) * maskWidth / outWidth - 0.5).clamp(
        0.0,
        maskWidth - 1.0,
      );
      final x0 = fx.floor();
      final x1 = math.min(x0 + 1, maskWidth - 1);
      final tx = fx - x0;
      final c =
          (at(x0, y0) * (1 - tx) + at(x1, y0) * tx) * (1 - ty) +
          (at(x0, y1) * (1 - tx) + at(x1, y1) * tx) * ty;
      final t = ((c - 0.35) / 0.3).clamp(0.0, 1.0);
      final ox = mirror ? outWidth - 1 - x : x;
      out[y * outWidth + ox] = _clamp255(t * t * (3 - 2 * t) * 255);
    }
  }
  return out;
}

/// The one square every frame is cropped to: the person's head at its top
/// and their shoulders below, from the union of the frames that show them.
/// Null when too few frames show a person (the clip is refused on the
/// phone).
({int left, int top, int side})? headAndShoulders(List<CutoutFrame> frames) {
  if (frames.isEmpty) return null;
  final w = frames.first.width;
  final h = frames.first.height;
  var minX = w;
  var minY = h;
  var maxX = -1;
  var maxY = -1;
  var withPerson = 0;
  for (final f in frames) {
    var count = 0;
    var fx0 = w;
    var fy0 = h;
    var fx1 = -1;
    var fy1 = -1;
    for (var y = 0; y < h; y++) {
      final row = y * w;
      for (var x = 0; x < w; x++) {
        if (f.alpha[row + x] >= 128) {
          count++;
          if (x < fx0) fx0 = x;
          if (x > fx1) fx1 = x;
          if (y < fy0) fy0 = y;
          if (y > fy1) fy1 = y;
        }
      }
    }
    if (count < w * h * CutoutLimits.minPersonShare) continue;
    withPerson++;
    minX = math.min(minX, fx0);
    minY = math.min(minY, fy0);
    maxX = math.max(maxX, fx1);
    maxY = math.max(maxY, fy1);
  }
  if (withPerson < frames.length * CutoutLimits.minFramesWithPerson) {
    return null;
  }
  final boxWidth = maxX - minX + 1;
  final side = math.min(math.min(w, h), (boxWidth * 1.12).round());
  final cx = (minX + maxX) / 2;
  final left = (cx - side / 2).round().clamp(0, w - side);
  final top = (minY - side * 0.06).round().clamp(0, h - side);
  return (left: left, top: top, side: side);
}

/// Up to [CutoutLimits.maxFrames] of [frames], evenly spread.
List<T> evenlyCapped<T>(List<T> frames, [int max = CutoutLimits.maxFrames]) {
  if (frames.length <= max) return frames;
  return [for (var i = 0; i < max; i++) frames[i * frames.length ~/ max]];
}
