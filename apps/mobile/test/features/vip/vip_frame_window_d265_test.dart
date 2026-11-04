// D265 (owner, on the VIP 1 person card: «الصورة أصغر من فتحة الإطار»): the
// VIP frame's window is the smallest circle around its whole transparent
// opening, so a picture that size leaves no gap — not the opening's widest
// row (D258), which left a non-round opening's corners empty.
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/vip/presentation/vip_svga.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:material_ui/material_ui.dart';

/// A [side]² frame: opaque but for [hole] (cleared), and a sparkle in the
/// middle of the opening when [sparkle].
ui.Image _frame(double side, Rect hole, {bool sparkle = false}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      Rect.fromLTWH(0, 0, side, side),
      Paint()..color = const Color(0xFF2E8B3D),
    )
    ..drawRRect(
      RRect.fromRectAndRadius(hole, Radius.circular(hole.width * 0.2)),
      Paint()..blendMode = BlendMode.clear,
    );
  if (sparkle) {
    canvas.drawCircle(
      hole.center.translate(hole.width * 0.15, -hole.height * 0.1),
      side * 0.03,
      Paint()..color = const Color(0xFFFFFFFF),
    );
  }
  final picture = recorder.endRecording();
  return picture.toImageSync(side.toInt(), side.toInt());
}

void main() {
  test('the smallest circle around points: a square → its diagonal', () {
    final c = VipSvgaClip.enclosingCircle(const [
      Offset(10, 10),
      Offset(110, 10),
      Offset(110, 110),
      Offset(10, 110),
      Offset(60, 60),
    ]);
    expect(c.centre.dx, closeTo(60, 0.2));
    expect(c.centre.dy, closeTo(60, 0.2));
    expect(c.radius, closeTo(50 * 1.41421, 0.2));
  });

  testWidgets('a rounded-square opening: the window holds its corners, '
      'a sparkle in the middle changes nothing', (tester) async {
    await tester.runAsync(() async {
      const side = 400.0;
      final hole = Rect.fromCenter(
        center: const Offset(200, 190),
        width: 240,
        height: 220,
      );
      for (final sparkle in [false, true]) {
        final clip = VipSvgaClip(
          viewBox: const Size(side, side),
          fps: 12,
          frames: [_frame(side, hole, sparkle: sparkle)],
          scale: 1,
        );
        final window = (await clip.window())!;
        // The rounded corners' farthest point from the centre.
        final r = hole.width * 0.2;
        final corner = Offset(hole.width / 2 - r, hole.height / 2 - r);
        final reach = corner.distance + r;
        // Every opening pixel inside the window (no gap), and not much more.
        expect(window.diameter * side / 2, greaterThanOrEqualTo(reach - 2));
        expect(window.diameter * side / 2, lessThan(reach + 4));
        expect(window.centre.dx * side, closeTo(200, 3));
        expect(window.centre.dy * side, closeTo(190, 3));
      }
    });
  });

  test("the owner's svip_1_frame template is its measured window", () {
    // Measured from the owner's SVGA by VipSvgaClip.window (D265).
    expect(VipAvatarFrame.templateWindow, closeTo(0.685, 0.002));
    expect(VipAvatarFrame.templateCentre, const Offset(0.5, 0.5));
    // The picture covers the window's rim: no gap.
    final rect = VipAvatarFrame.artRect(
      84,
      VipAvatarFrame.templateCentre,
      VipAvatarFrame.templateWindow,
    );
    expect(rect.width * VipAvatarFrame.templateWindow, lessThan(84));
    expect(rect.center.dx, closeTo(42, 1e-9));
    expect(rect.center.dy, closeTo(42, 1e-9));
  });

  test('the bubble keeps its one-line scale on a taller message and is never '
      'narrower than its fixed parts', () {
    const nine = VipSvgaNine.bubble;
    const box = Size(990, 720);
    final one = nine.scaleFor(const Size(200, 30), box);
    final three = nine.scaleFor(const Size(200, 75), box);
    expect(one, closeTo(30 / 457, 1e-9));
    // Taller than one line: the scale stops at maxHeight; the slice
    // stretches.
    expect(three, closeTo(32 / 457, 1e-9));
    // The ornament corner and the end: (669 − 140) units at 32 pt.
    expect(nine.minWidth, closeTo(529 * 32 / 457, 1e-6));
    // The stretched band is on straight edges (between the ornaments and the
    // rounded bottom corners).
    expect(nine.slice.top * 720, closeTo(340, 1e-9));
    expect(nine.slice.bottom * 720, closeTo(380, 1e-9));
  });
}
