// D130: the owner's animated party-popper icon (owner-made Kabso art,
// 2026-10-27), drawn with a CustomPainter (no assets).
//
// Idle: an outline cone, three short burst lines and a small streamer in
// the inactive colour (the palette's `textPrimary` by default, like the
// header's other icons).
// Play: the cone recoils and shakes, red fills it with light stripes, the
// burst lines shoot out and come back, confetti pops out and falls.

import 'dart:math' as math;

import 'package:kabso_live/design_system/theme/app_theme.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The party popper. It has no gesture of its own: the caller plays it
/// through a `GlobalKey<KPartyIconState>` (`play()`) or [selected].
class KPartyIcon extends StatefulWidget {
  const new({
    super.key,
    this.size = KSpacing.xl,
    this.selected = false,
    this.inactiveColor,
    this.duration = const Duration(milliseconds: 1100),
  });

  final double size;

  /// The coloured state: plays once when it turns true and stays coloured.
  final bool selected;

  /// The idle outline colour; the palette's `textPrimary` when null.
  final Color? inactiveColor;
  final Duration duration;

  @override
  State<KPartyIcon> createState() => KPartyIconState();
}

class KPartyIconState extends State<KPartyIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.selected ? 1 : 0,
  )..addStatusListener(_onStatus);
  bool _playing = false;

  /// Plays the pop once (not when the platform asks to reduce motion).
  void play() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    setState(() => _playing = true);
    _c.forward(from: 0);
  }

  void _onStatus(AnimationStatus s) {
    if (s != AnimationStatus.completed) return;
    if (!widget.selected && mounted) {
      setState(() => _playing = false);
      _c.value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant KPartyIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (widget.selected && !old.selected) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _c.value = 1;
      } else {
        play();
      }
    }
    if (!widget.selected && old.selected && !_c.isAnimating) _c.value = 0;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _PartyPainter(
          on: widget.selected || _playing,
          p: _c.value,
          grey: widget.inactiveColor ?? p.textPrimary,
          ink: p.textPrimary,
          red: p.primary,
          redHi: KBrandColors.red400,
          light: p.onPrimary,
        ),
      ),
    );
  }
}

// ───────────────────────────── painter ─────────────────────────────

/// The confetti's colours (the owner's art).
const List<Color> _confettiColours = [
  Color(0xFFFF2D3A),
  Color(0xFFFFB020),
  Color(0xFFFF6FA5),
  Color(0xFFC2000B),
  Color(0xFFFFD34D),
];

/// The streamer's colour once played (the owner's art).
const Color _streamer = Color(0xFFFFB020);

/// One piece of confetti: angle in degrees, distance, size, colour index,
/// strip (else dot), spin.
typedef _Piece = ({
  double angle,
  double distance,
  double size,
  int colour,
  bool strip,
  double spin,
});

const List<_Piece> _pieces = [
  (angle: -75, distance: 11, size: 1.3, colour: 0, strip: false, spin: 3),
  (angle: -55, distance: 13, size: 1.1, colour: 1, strip: true, spin: -4),
  (angle: -35, distance: 12, size: 1.2, colour: 2, strip: false, spin: 5),
  (angle: -15, distance: 10, size: 1.0, colour: 4, strip: true, spin: -3),
  (angle: 5, distance: 9, size: 1.2, colour: 0, strip: false, spin: 4),
  (angle: -90, distance: 9, size: 1.0, colour: 1, strip: true, spin: 2),
  (angle: -25, distance: 15, size: .9, colour: 3, strip: false, spin: -5),
  (angle: -62, distance: 15.5, size: .9, colour: 4, strip: true, spin: 4),
  (angle: -45, distance: 8, size: 1.1, colour: 2, strip: true, spin: -2),
  (angle: -5, distance: 13, size: .9, colour: 1, strip: false, spin: 3),
];

/// The burst lines: start x, start y, angle in degrees.
const List<(double, double, double)> _bursts = [
  (15.4, 6.2, -80),
  (18, 8.2, -45),
  (19.6, 11.2, -15),
];

double _c01(double v) => v.clamp(0.0, 1.0);
double _seg(double p, double a, double b) => _c01((p - a) / (b - a));
double _bump(double p, double a, double b) => math.sin(math.pi * _seg(p, a, b));
double _easeOutCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();

class _PartyPainter extends CustomPainter {
  new({
    required this.on,
    required this.p,
    required this.grey,
    required this.ink,
    required this.red,
    required this.redHi,
    required this.light,
  });

  final bool on;
  final double p;
  final Color grey;
  final Color ink;
  final Color red;
  final Color redHi;
  final Color light;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final inkC = on ? ink : grey;
    final fill = on ? _easeOutCubic(_seg(p, 0, .4)) : 0.0;
    Paint st(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // The cone recoils (rotates about its tip), then shakes.
    final q = _seg(p, .14, 1);
    final rot = on
        ? (-.28 * _bump(p, 0, .14) + math.sin(q * math.pi * 4) * (1 - q) * .14)
        : 0.0;
    canvas
      ..save()
      ..translate(4.6, 19.6)
      ..rotate(rot)
      ..translate(-4.6, -19.6);
    final cone = Path()
      ..moveTo(4.6, 19.6)
      ..lineTo(8.3, 7.2)
      ..cubicTo(9.6, 5.2, 15.2, 9.6, 17, 15.4)
      ..close();
    final stripes = Path()
      ..moveTo(6.9, 12.4)
      ..quadraticBezierTo(10, 15, 10.8, 17.6);
    canvas
      ..save()
      ..clipPath(cone);
    if (fill > 0) {
      canvas.drawCircle(
        const Offset(4.6, 19.6),
        17 * fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [red, redHi],
          ).createShader(const Rect.fromLTRB(4, 8, 16, 20)),
      );
      stripes
        ..moveTo(5.6, 15.9)
        ..quadraticBezierTo(7.2, 17.2, 7.6, 18.6);
      canvas.drawPath(stripes, st(light.withValues(alpha: .9), 1.3));
    } else {
      canvas.drawPath(stripes, st(grey, 1.3));
    }
    canvas
      ..restore()
      ..drawPath(cone, st(inkC, 1.8))
      ..drawPath(
        Path()
          ..moveTo(8.3, 7.2)
          ..cubicTo(10.8, 7.8, 15.6, 12.2, 17, 15.4),
        st(inkC, 1.5),
      )
      ..restore();

    // The burst lines shoot out, fade and come back.
    final out = on ? _easeOutCubic(_seg(p, .08, .45)) : 0.0;
    final back = on ? _seg(p, .55, .9) : 1.0;
    final alpha = !on
        ? 1.0
        : (p < .45
              ? 1.0
              : (p < .55 ? 1 - _seg(p, .45, .55) : _seg(p, .55, .9)));
    for (final (x, y, deg) in _bursts) {
      final a = deg * math.pi / 180;
      final off = 5 * out * (1 - back);
      final s = Offset(x + math.cos(a) * off, y + math.sin(a) * off);
      canvas.drawLine(
        s,
        s + Offset(math.cos(a) * 2.6, math.sin(a) * 2.6),
        st((on ? red : grey).withValues(alpha: alpha), 1.6),
      );
    }
    // The streamer curl.
    canvas.drawPath(
      Path()
        ..moveTo(20.6, 4.2)
        ..quadraticBezierTo(19.2, 5.4, 20.4, 6.4),
      st(on ? _streamer : grey, 1.3),
    );

    // Confetti.
    if (on && p > .05 && p < 1) {
      final t = _seg(p, .05, 1);
      for (final c in _pieces) {
        final a = c.angle * math.pi / 180;
        final d = c.distance * _easeOutCubic(t);
        final pos = Offset(
          13 + math.cos(a) * d,
          11 + math.sin(a) * d + 14 * t * t,
        );
        final paint = Paint()
          ..color = _confettiColours[c.colour].withValues(
            alpha: _c01(1 - math.pow(t, 3).toDouble()),
          );
        canvas
          ..save()
          ..translate(pos.dx, pos.dy)
          ..rotate(c.spin * t * 3);
        if (c.strip) {
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: c.size * 2,
              height: c.size * .9,
            ),
            paint,
          );
        } else {
          canvas.drawCircle(Offset.zero, c.size * .8, paint);
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PartyPainter o) =>
      o.p != p || o.on != on || o.grey != grey || o.ink != ink || o.red != red;
}
