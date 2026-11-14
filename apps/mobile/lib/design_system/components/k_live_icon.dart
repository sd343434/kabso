// D139: the owner's animated Live icon (owner-made Kabso art, 2026-10-27:
// "a screen with a LIVE badge", concept 3 of the owner's live-icon sheet),
// drawn with a CustomPainter (no assets). Brought in like `KPartyIcon`:
// no gesture of its own, palette colours, reduced motion respected.
//
// Idle: an outline screen on a stand with a play triangle and a «● LIVE»
// badge on top, in the inactive colour (the palette's `textPrimary` by
// default, like the header's other icons).
// Play: the screen squashes and bounces, fills red from the centre, a
// light sweep passes over it, the play triangle pops and turns light, the
// LIVE badge turns red and drops in with a bounce, its dot blinks, and two
// hearts float up like live likes.

import 'dart:math' as math;

import 'package:kabso_live/design_system/theme/app_theme.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The owner's Live icon. It has no gesture of its own: the caller plays it
/// through a `GlobalKey<KLiveIconState>` (`play()`) or [selected].
class KLiveIcon extends StatefulWidget {
  const new({
    super.key,
    this.size = KSpacing.xl,
    this.selected = false,
    this.inactiveColor,
    this.surfaceColor,
    this.duration = const Duration(milliseconds: 1100),
  });

  final double size;

  /// The coloured state: plays once when it turns true and stays coloured.
  final bool selected;

  /// The idle outline colour; the palette's `textPrimary` when null.
  final Color? inactiveColor;

  /// The inside of the screen and of the idle badge (the surface the icon
  /// sits on); the palette's `surfaceRaised` when null.
  final Color? surfaceColor;
  final Duration duration;

  @override
  State<KLiveIcon> createState() => KLiveIconState();
}

class KLiveIconState extends State<KLiveIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.selected ? 1 : 0,
  )..addStatusListener(_onStatus);
  bool _playing = false;

  /// Whether the play animation is running.
  bool get playing => _playing;

  /// Plays the animation once (not when the platform asks to reduce
  /// motion).
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
  void didUpdateWidget(covariant KLiveIcon oldWidget) {
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
        painter: _LivePainter(
          on: widget.selected || _playing,
          p: _c.value,
          grey: widget.inactiveColor ?? p.textPrimary,
          ink: p.textPrimary,
          red: p.primary,
          redHi: KBrandColors.red400,
          light: p.onPrimary,
          surface: widget.surfaceColor ?? p.surfaceRaised,
        ),
      ),
    );
  }
}

// ───────────────────────────── painter ─────────────────────────────

/// The LIVE badge's red once played (the owner's art).
const Color _badgeRed = Color(0xFFFF2D3A);

/// The hearts: start, x, colour, scale (the owner's art).
const List<(double, double, Color, double)> _hearts = [
  (.3, 19.4, Color(0xFFFF2D3A), 1),
  (.44, 16.4, Color(0xFFFF6FA5), .75),
];

double _c01(double v) => v.clamp(0.0, 1.0);
double _seg(double p, double a, double b) => _c01((p - a) / (b - a));
double _bump(double p, double a, double b) => math.sin(math.pi * _seg(p, a, b));
double _easeOutCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();

class _LivePainter extends CustomPainter {
  new({
    required this.on,
    required this.p,
    required this.grey,
    required this.ink,
    required this.red,
    required this.redHi,
    required this.light,
    required this.surface,
  });

  final bool on;
  final double p;
  final Color grey;
  final Color ink;
  final Color red;
  final Color redHi;
  final Color light;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final inkC = on ? ink : grey;
    final fill = on ? _easeOutCubic(_seg(p, 0, .38)) : 0.0;
    Paint st(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // The stand.
    canvas.drawLine(
      const Offset(8.6, 22),
      const Offset(15.4, 22),
      st(inkC, 1.8),
    );

    // The screen squashes and bounces, anchored on the stand.
    final sq = on ? 1 - .12 * _bump(p, 0, .13) + .07 * _bump(p, .13, .32) : 1.0;
    final q = _seg(p, .13, 1);
    final tilt = on ? math.sin(q * math.pi * 3) * (1 - q) * .08 : 0.0;
    canvas
      ..save()
      ..translate(12, 21)
      ..rotate(tilt)
      ..scale(2 - sq, sq)
      ..translate(-12, -21);
    final scr = RRect.fromRectAndRadius(
      const Rect.fromLTWH(2.6, 6.4, 18.8, 13.4),
      const Radius.circular(3.4),
    );
    canvas.drawRRect(scr, Paint()..color = surface);
    if (fill > 0) {
      canvas
        ..save()
        ..clipRRect(scr)
        ..drawCircle(
          const Offset(12, 13),
          14 * fill,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [redHi, red],
            ).createShader(const Rect.fromLTRB(3, 6, 21, 20)),
        );
      // The light sweep.
      final sw = _seg(p, .4, .75);
      if (sw > 0 && sw < 1) {
        const band = Rect.fromLTWH(-4, -14, 8, 28);
        canvas
          ..save()
          ..translate(-2 + 28 * sw, 13)
          ..rotate(.5)
          ..drawRect(
            band,
            Paint()
              ..shader = LinearGradient(
                colors: [
                  light.withValues(alpha: 0),
                  light.withValues(alpha: .55),
                  light.withValues(alpha: 0),
                ],
              ).createShader(band),
          )
          ..restore();
      }
      canvas.restore();
    }
    canvas.drawRRect(scr, st(inkC, 1.8));
    final pop = on ? 1 + .42 * _bump(p, .2, .56) : 1.0;
    final r = 2.9 * pop;
    final tri = Path()
      ..moveTo(12.6 + r * 1.05, 13.2)
      ..lineTo(12.6 - r * .55, 13.2 - r * .95)
      ..lineTo(12.6 - r * .55, 13.2 + r * .95)
      ..close();
    final triC = fill > .85 ? light : inkC;
    canvas
      ..drawPath(tri, Paint()..color = triC)
      ..drawPath(tri, st(triC, 1))
      ..restore();

    // The LIVE badge drops in with a bounce; its dot blinks.
    var bs = 1.0;
    var by = 0.0;
    if (on) {
      final t = _seg(p, .18, .6);
      bs = t < 1
          ? (t < .5
                ? .45 + .85 * _easeOutCubic(t / .5)
                : 1 + .12 * math.sin((t - .5) / .5 * math.pi))
          : 1.0;
      by = -3 * (1 - _easeOutCubic(math.min(1, t * 1.6)));
    }
    canvas
      ..save()
      ..translate(12, 5.8 + by)
      ..scale(bs);
    final pill = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-7.2, -2.7, 14.4, 5.4),
      const Radius.circular(2.7),
    );
    final blink = on ? .55 + .45 * math.cos(p * math.pi * 6) : 1.0;
    canvas
      ..drawRRect(pill, Paint()..color = on ? _badgeRed : surface)
      ..drawRRect(pill, st(on ? light : grey, 1.1))
      ..drawCircle(
        const Offset(-4.6, 0),
        .95,
        Paint()..color = on ? light.withValues(alpha: blink) : grey,
      );
    // "LIVE" is part of the art (Latin in both directions).
    final tp = TextPainter(
      text: TextSpan(
        text: 'LIVE',
        style: TextStyle(
          // The bundled Latin face, so the badge is the same everywhere.
          fontFamily: KFonts.latin,
          fontSize: 3.6,
          fontWeight: FontWeight.w900,
          color: on ? light : grey,
          height: 1,
          letterSpacing: .1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(1.3 - tp.width / 2, -tp.height / 2 + .1));
    tp.dispose();
    canvas.restore();

    // Hearts (live likes) float up on the right.
    if (on) {
      for (final (start, x, colour, scale) in _hearts) {
        final t = _seg(p, start, start + .5);
        if (t <= 0 || t >= 1) continue;
        final pos = Offset(
          x + 3 + math.sin(t * math.pi * 2) * 1.2,
          16 - 11 * _easeOutCubic(t),
        );
        final sc = scale * (t < .2 ? t / .2 : 1) * 2.2;
        canvas
          ..save()
          ..translate(pos.dx, pos.dy)
          ..scale(sc)
          ..drawPath(
            Path()
              ..moveTo(0, 1)
              ..cubicTo(-1.6, 0, -1.3, -1.4, 0, -.5)
              ..cubicTo(1.3, -1.4, 1.6, 0, 0, 1)
              ..close(),
            Paint()..color = colour.withValues(alpha: _c01(1 - t * t)),
          )
          ..restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LivePainter o) =>
      o.p != p ||
      o.on != on ||
      o.grey != grey ||
      o.ink != ink ||
      o.red != red ||
      o.surface != surface;
}
