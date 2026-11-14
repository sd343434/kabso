// D335 (owner: «إذا لم يكن لدى المستخدم غلاف، يظهر غلاف Kabso افتراضي
// خاص»): the default cover of a profile without one of its own.
//
// Provenance: ORIGINAL, drawn in code for Kabso (no image file, nothing
// taken from the owner's reference or any other product): the Kabso red
// gradient of the design tokens and a faint lattice of «K» monograms built
// from three straight strokes, with a soft light at the top end. A light and
// a dark variant follow the app's theme.

import 'dart:math' as math;

import 'package:kabso_live/design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// The default Kabso cover: the brand red gradient with a faint «K» lattice.
class ProfileDefaultCover extends StatelessWidget {
  const new({super.key});

  /// Light theme: bright Kabso red to deep red.
  static const List<Color> lightColors = [
    KBrandColors.red400,
    KBrandColors.red500,
    KBrandColors.red700,
  ];

  /// Dark theme: the same reds, deeper, ending near black.
  static const List<Color> darkColors = [
    KBrandColors.red500,
    KBrandColors.red700,
    Color(0xFF2A0306),
  ];

  /// The monograms' ink: white, faint.
  static const Color lightInk = Color(0x14FFFFFF);
  static const Color darkInk = Color(0x0FFFFFFF);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart.resolve(
              Directionality.of(context),
            ),
            end: AlignmentDirectional.bottomEnd.resolve(
              Directionality.of(context),
            ),
            colors: dark ? darkColors : lightColors,
            stops: const [0, 0.55, 1],
          ),
        ),
        child: CustomPaint(
          painter: _KabsoPatternPainter(
            ink: dark ? darkInk : lightInk,
            glowEnd: !rtl,
            glow: dark ? 0.10 : 0.18,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _KabsoPatternPainter extends CustomPainter {
  const new({required this.ink, required this.glowEnd, required this.glow});

  final Color ink;

  /// The soft light sits at the top end (right in LTR, left in RTL).
  final bool glowEnd;
  final double glow;

  /// The lattice's pitch and the monogram's height (logical pixels).
  static const double pitch = 46;
  static const double glyph = 13;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final centre = Offset(glowEnd ? size.width * 0.85 : size.width * 0.15, 0);
    canvas.drawCircle(
      centre,
      size.longestSide * 0.7,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Color.fromRGBO(255, 255, 255, glow),
                const Color(0x00FFFFFF),
              ],
            ).createShader(
              Rect.fromCircle(center: centre, radius: size.longestSide * 0.7),
            ),
    );
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..translate(size.width / 2, size.height / 2)
      ..rotate(-math.pi / 12);
    final reach = size.longestSide;
    var row = 0;
    for (var y = -reach; y <= reach; y += pitch * 0.62, row++) {
      final shift = row.isOdd ? pitch / 2 : 0.0;
      for (var x = -reach + shift; x <= reach; x += pitch) {
        _monogram(canvas, Offset(x, y), stroke);
      }
    }
    canvas.restore();
  }

  /// A «K» of three strokes: the stem and the two arms meeting at the
  /// stem's middle.
  void _monogram(Canvas canvas, Offset o, Paint paint) {
    const h = glyph / 2;
    const w = glyph * 0.62;
    final stem = o.translate(-w / 2, 0);
    canvas
      ..drawLine(stem.translate(0, -h), stem.translate(0, h), paint)
      ..drawLine(stem, o.translate(w / 2, -h), paint)
      ..drawLine(
        stem.translate(w * 0.28, -h * 0.28),
        o.translate(w / 2, h),
        paint,
      );
  }

  @override
  bool shouldRepaint(_KabsoPatternPainter old) =>
      old.ink != ink || old.glowEnd != glowEnd || old.glow != glow;
}
