// D384 (the VIP animated picture «صورة متحركة»): synthetic stand-ins for
// tests and goldens — a drawn cartoon bust with a transparent background
// (no real face, no third-party art; board D40) and synthetic camera frames
// with a person's alpha.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:kabso_live/features/vip/animated_avatar/cutout_frames.dart';
import 'package:kabso_live/features/vip/domain/animated_avatar.dart';

/// The URLs a test profile's animated picture names (served by the test's
/// `animatedAvatarImageFor`).
const syntheticCutoutUrl = 'https://cdn.test/media/d384/clip.webp';
const syntheticCutoutStillUrl = 'https://cdn.test/media/d384/still.webp';

const syntheticCutout = AnimatedAvatar(
  url: syntheticCutoutUrl,
  stillUrl: syntheticCutoutStillUrl,
  width: 320,
  height: 320,
);

/// Draws the stand-in bust on [canvas] in a [side] square, [frame] (0–35)
/// moving its smile a little.
void paintSyntheticBust(ui.Canvas canvas, double side, {int frame = 0}) {
  final s = side;
  final skin = ui.Paint()..color = const ui.Color(0xFFE8B48A);
  final hair = ui.Paint()..color = const ui.Color(0xFF3B2A20);
  final shirt = ui.Paint()..color = const ui.Color(0xFF2F6FB0);
  final ink = ui.Paint()..color = const ui.Color(0xFF2A1A12);
  // Shoulders and shirt.
  canvas
    ..drawRRect(
      ui.RRect.fromLTRBAndCorners(
        s * 0.08,
        s * 0.70,
        s * 0.92,
        s * 1.05,
        topLeft: ui.Radius.circular(s * 0.22),
        topRight: ui.Radius.circular(s * 0.22),
      ),
      shirt,
    )
    // Neck.
    ..drawRect(ui.Rect.fromLTWH(s * 0.42, s * 0.56, s * 0.16, s * 0.18), skin)
    // Head.
    ..drawOval(ui.Rect.fromLTWH(s * 0.28, s * 0.14, s * 0.44, s * 0.50), skin)
    // Hair.
    ..drawArc(
      ui.Rect.fromLTWH(s * 0.26, s * 0.08, s * 0.48, s * 0.34),
      math.pi,
      math.pi,
      true,
      hair,
    )
    // Eyes.
    ..drawCircle(ui.Offset(s * 0.41, s * 0.36), s * 0.025, ink)
    ..drawCircle(ui.Offset(s * 0.59, s * 0.36), s * 0.025, ink);
  // A smile that widens and narrows over the loop.
  final open = 0.04 + 0.03 * math.sin(frame / 36 * 2 * math.pi);
  canvas.drawArc(
    ui.Rect.fromLTWH(s * 0.40, s * 0.42, s * 0.20, s * (0.06 + open)),
    0,
    math.pi,
    false,
    ink
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = s * 0.018,
  );
}

/// The stand-in as a PNG with alpha (call inside `tester.runAsync`).
Future<Uint8List> syntheticCutoutPng({int side = 320, int frame = 0}) async {
  final recorder = ui.PictureRecorder();
  paintSyntheticBust(ui.Canvas(recorder), side.toDouble(), frame: frame);
  final picture = recorder.endRecording();
  final image = await picture.toImage(side, side);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// [count] synthetic camera frames ([width] × [height]): an opaque warm
/// picture with a person-shaped alpha (a head and shoulders) moving
/// slightly; [person] false gives frames with nobody in them.
List<CutoutFrame> syntheticCutoutFrames({
  int width = 96,
  int height = 128,
  int count = 36,
  bool person = true,
}) => [
  for (var f = 0; f < count; f++)
    () {
      final rgba = Uint8List(width * height * 4);
      final alpha = Uint8List(width * height);
      final cx = width / 2 + math.sin(f / 6) * 3;
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final i = y * width + x;
          rgba[i * 4] = 200;
          rgba[i * 4 + 1] = (120 + y) % 256;
          rgba[i * 4 + 2] = 90;
          rgba[i * 4 + 3] = 255;
          if (!person) continue;
          final dx = (x - cx) / (width * 0.22);
          final dy = (y - height * 0.38) / (height * 0.2);
          final head = dx * dx + dy * dy < 1;
          final shoulders = y > height * 0.62 && (x - cx).abs() < width * 0.42;
          alpha[i] = head || shoulders ? 255 : 0;
        }
      }
      return CutoutFrame(
        width: width,
        height: height,
        rgba: rgba,
        alpha: alpha,
      );
    }(),
];

/// [count] synthetic camera frames of the stand-in bust ([width] ×
/// [height], pure Dart): skin, hair, shirt, eyes and a smile that moves, on
/// a striped background the alpha removes.
List<CutoutFrame> syntheticBustFrames({
  int width = 150,
  int height = 200,
  int count = 12,
}) => [for (var f = 0; f < count; f++) _bustFrame(width, height, f, count)];

bool _inEllipse(
  double x,
  double y,
  double cx,
  double cy,
  double rx,
  double ry,
) => ((x - cx) * (x - cx)) / (rx * rx) + ((y - cy) * (y - cy)) / (ry * ry) < 1;

CutoutFrame _bustFrame(int width, int height, int f, int count) {
  final rgba = Uint8List(width * height * 4);
  final alpha = Uint8List(width * height);
  final s = width.toDouble();
  final top = height * 0.12;
  final smile = 0.04 + 0.03 * math.sin(f / count * 2 * math.pi);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = y * width + x;
      final px = x + 0.5;
      final py = y + 0.5;
      // The background (removed by the alpha): stripes.
      var c = (x ~/ 10 + y ~/ 10).isEven
          ? const [90, 140, 90]
          : const [60, 90, 150];
      var a = 0;
      final head = _inEllipse(
        px,
        py,
        s * 0.5,
        top + s * 0.36,
        s * 0.22,
        s * 0.26,
      );
      final hair =
          _inEllipse(px, py, s * 0.5, top + s * 0.22, s * 0.24, s * 0.16) &&
          py < top + s * 0.26;
      final neck =
          (px - s * 0.5).abs() < s * 0.08 &&
          py > top + s * 0.55 &&
          py < top + s * 0.74;
      final shoulders =
          py > top + s * 0.70 &&
          _inEllipse(px, py, s * 0.5, top + s * 1.05, s * 0.46, s * 0.38);
      if (shoulders) {
        c = const [47, 111, 176];
        a = 255;
      }
      if (neck || head) {
        c = const [232, 180, 138];
        a = 255;
      }
      if (hair) {
        c = const [59, 42, 32];
        a = 255;
      }
      final eye =
          _inEllipse(px, py, s * 0.41, top + s * 0.36, s * 0.025, s * 0.03) ||
          _inEllipse(px, py, s * 0.59, top + s * 0.36, s * 0.025, s * 0.03);
      final mouth =
          py > top + s * 0.46 &&
          py < top + s * (0.48 + smile) &&
          (px - s * 0.5).abs() < s * 0.09;
      if (head && (eye || mouth)) c = const [42, 26, 18];
      rgba[i * 4] = c[0];
      rgba[i * 4 + 1] = c[1];
      rgba[i * 4 + 2] = c[2];
      rgba[i * 4 + 3] = 255;
      alpha[i] = a;
    }
  }
  return CutoutFrame(width: width, height: height, rgba: rgba, alpha: alpha);
}
