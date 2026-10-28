import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_lucky_combo.dart';
import 'package:kabso_live/features/live/application/max_x.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

// D145d: the owner's animated MAX X button (`kabso_max_x_button.dart`,
// 2026-10-28), drawn in Kabso's live layer: the heat orb with its countdown
// ring and the per-tier win celebrations. The colours, timings and shapes
// are the owner's; the gift picture, the label and the numbers are widgets
// (text scaling, RTL, screen readers).

/// The orb's colours of one heat tier (owner's `_heats`).
@immutable
class MaxXHeatColors {
  const new(this.light, this.mid, this.dark, this.rimA, this.rimB, this.glow);

  final Color light;
  final Color mid;
  final Color dark;
  final Color rimA;
  final Color rimB;
  final Color glow;

  static const _red = MaxXHeatColors(
    Color(0xFFFF7C84),
    Color(0xFFE0101C),
    Color(0xFF6E0006),
    Color(0xFFFFE27A),
    Color(0xFFFF2D3A),
    Color(0xFFFF2D3A),
  );
  static const _pink = MaxXHeatColors(
    Color(0xFFFF9CCB),
    Color(0xFFF0308A),
    Color(0xFF6E0A3C),
    Color(0xFFFFE27A),
    Color(0xFFFF6FA5),
    Color(0xFFFF50A0),
  );
  static const _purple = MaxXHeatColors(
    Color(0xFFD9A8FF),
    Color(0xFF8A3CF0),
    Color(0xFF2E0A6E),
    Color(0xFFFFB8F0),
    Color(0xFF7A6BFF),
    Color(0xFFA05AFF),
  );
  static const _gold = MaxXHeatColors(
    Color(0xFFFFF6C8),
    Color(0xFFF0A81E),
    Color(0xFF7A4706),
    Color(0xFFFFFFFF),
    Color(0xFFFFC93C),
    Color(0xFFFFC93C),
  );

  static MaxXHeatColors of(MaxXHeat heat) => switch (heat) {
    MaxXHeat.red => _red,
    MaxXHeat.pink => _pink,
    MaxXHeat.purple => _purple,
    MaxXHeat.gold => _gold,
  };
}

/// One win tier's celebration (owner's `_winTiers`): how long it lasts,
/// its colour and number gradient, the ribbon (null: animated rainbow),
/// the sunburst's length (0: none), the coins thrown, the shake and the
/// number's size (× the orb's radius).
@immutable
class MaxXWinStyle {
  const new(
    this.tier,
    this.seconds,
    this.color,
    this.numberColors,
    this.ribbon,
    this.rays,
    this.coins,
    this.shake,
    this.size,
  );

  final int tier;
  final double seconds;
  final Color color;
  final List<Color> numberColors;
  final List<Color>? ribbon;
  final double rays;
  final int coins;
  final double shake;
  final double size;

  Duration get duration => Duration(milliseconds: (seconds * 1000).round());

  /// D145e: the same look lasting [s] seconds (the room's big-win card).
  MaxXWinStyle lasting(double s) => MaxXWinStyle(
    tier,
    s,
    color,
    numberColors,
    ribbon,
    rays,
    coins,
    shake,
    size,
  );

  static const all = [
    MaxXWinStyle(
      5,
      .9,
      Color(0xFFFFD650),
      [Color(0xFFFFFFFF), Color(0xFFFFE27A), Color(0xFFF0A81E)],
      [Color(0xFFF0A81E), Color(0xFFB8780A)],
      0,
      6,
      0,
      .42,
    ),
    MaxXWinStyle(
      10,
      1.1,
      Color(0xFFFF50A0),
      [Color(0xFFFFFFFF), Color(0xFFFFB0D8), Color(0xFFF0308A)],
      [Color(0xFFFF4D9A), Color(0xFFB0105A)],
      0,
      12,
      0,
      .48,
    ),
    MaxXWinStyle(
      25,
      1.25,
      Color(0xFF3FE0C8),
      [Color(0xFFFFFFFF), Color(0xFFC2FFF4), Color(0xFF14A893)],
      [Color(0xFF3FE0C8), Color(0xFF0A7A6E)],
      0,
      18,
      .2,
      .53,
    ),
    MaxXWinStyle(
      50,
      1.4,
      Color(0xFFA05AFF),
      [Color(0xFFFFFFFF), Color(0xFFE2C8FF), Color(0xFF8A3CF0)],
      [Color(0xFF9A4DFF), Color(0xFF4A12A8)],
      1,
      24,
      .4,
      .58,
    ),
    MaxXWinStyle(
      100,
      1.8,
      Color(0xFFFFC93C),
      [Color(0xFFFFFFFF), Color(0xFFFFE27A), Color(0xFFFF9F1E)],
      [Color(0xFFFFC93C), Color(0xFFB8780A)],
      1.4,
      32,
      1,
      .64,
    ),
    MaxXWinStyle(
      250,
      2.1,
      Color(0xFFFF6E28),
      [Color(0xFFFFFFFF), Color(0xFFFFD9A8), Color(0xFFFF6A2A)],
      [Color(0xFFFF6A2A), Color(0xFFB81E00)],
      1.7,
      40,
      1.2,
      .7,
    ),
    MaxXWinStyle(
      500,
      2.6,
      Color(0xFFFF78C8),
      [Color(0xFFFFFFFF), Color(0xFFFFE27A), Color(0xFFFF6FA5)],
      null,
      2,
      48,
      1.6,
      .78,
    ),
    MaxXWinStyle(
      1000,
      3.2,
      Color(0xFFFFDC78),
      [Color(0xFFFFFFFF), Color(0xFFFFF3B0), Color(0xFFFFC93C)],
      null,
      2.6,
      64,
      2.2,
      .88,
    ),
  ];

  /// The style of win tier [tier] (one of [MaxXTiers.win]).
  static MaxXWinStyle of(int tier) =>
      all.firstWhere((s) => s.tier == tier, orElse: () => all.first);
}

double _c01(double v) => v.clamp(0.0, 1.0);
double _eo(double t) => 1 - math.pow(1 - t, 3).toDouble();
double _eio(double t) =>
    t < .5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3).toDouble() / 2;
double _eob(double t) {
  const a = 1.70158;
  const b = a + 1;
  return 1 + b * math.pow(t - 1, 3) + a * math.pow(t - 1, 2);
}

void _star(Canvas c, double r, Paint p) => c.drawPath(
  Path()
    ..moveTo(0, -r)
    ..quadraticBezierTo(r * .18, -r * .18, r, 0)
    ..quadraticBezierTo(r * .18, r * .18, 0, r)
    ..quadraticBezierTo(-r * .18, r * .18, -r, 0)
    ..quadraticBezierTo(-r * .18, -r * .18, 0, -r)
    ..close(),
  p,
);

/// The round MAX X button (owner's design): breathing heat glow, rotating
/// rim, counter-rotating energy arcs, orbiting sparkles, swirling light and
/// a shine across the orb; a tap squashes and springs the orb, flashes it
/// and throws a shockwave and sparks; the countdown ring empties over
/// [LuckyComboController.ringTime] and turns urgent (orange, flickering,
/// trembling) in its last [LuckyComboController.urgentTime]. The gift sits
/// in the orb and «MAX x12» / «ماكس x12» under it, the number rolling.
///
/// With reduced motion only the countdown moves (it is the time left, not
/// decoration). Widget tests turn the endless motion off ([animate]).
class MaxXOrb extends StatefulWidget {
  const new({
    required this.ring,
    required this.streak,
    required this.count,
    required this.taps,
    required this.word,
    required this.assetKey,
    super.key,
    this.imageUrl,
    this.size = 84,
    this.countKey,
    this.ringKey,
  });

  /// The countdown (0 → 1 over the ring time).
  final Animation<double> ring;

  /// Sends in the streak: the heat tier.
  final int streak;

  /// The number after the word («x12»).
  final int count;

  /// Grows with each accepted tap (the press feedback).
  final int taps;
  final String word;
  final String assetKey;
  final String? imageUrl;
  final double size;
  final Key? countKey;
  final Key? ringKey;

  /// The endless motion (glow, rim, sparkles); off in widget tests
  /// (`test/flutter_test_config.dart`).
  static bool animate = true;

  /// The orb's radius in a box of [size] (the ring's outer edge).
  static double radiusOf(double size) => size / 2 - 4;

  /// D145e: the label's box — the orb's chord where the label sits (it
  /// used to stick out 0.3 r on each side and was cut at the screen edge).
  static double labelWidthOf(double r) => r * 1.6;

  /// D145e: «ماكس x264» up to three digits; the number alone from 1,000.
  static bool showsWord(int count) => count < 1000;

  static const labelKey = Key('maxx.label');

  @override
  State<MaxXOrb> createState() => _MaxXOrbState();
}

class _MaxXOrbState extends State<MaxXOrb> with TickerProviderStateMixin {
  final _now = ValueNotifier<double>(0);
  late final Ticker _clock = createTicker(
    (e) => _now.value = e.inMicroseconds / 1e6,
  );
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  @override
  void didUpdateWidget(MaxXOrb old) {
    super.didUpdateWidget(old);
    if (widget.taps != old.taps && !_reduce) _press.forward(from: 0);
  }

  bool get _reduce => MediaQuery.disableAnimationsOf(context);

  @override
  void dispose() {
    _clock.dispose();
    _press.dispose();
    _now.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = _reduce;
    final moving = MaxXOrb.animate && !reduce;
    if (moving && !_clock.isActive) {
      _clock.start();
    } else if (!moving && _clock.isActive) {
      _clock.stop();
    }
    final size = widget.size;
    final r = MaxXOrb.radiusOf(size);
    final heat = MaxXHeatColors.of(MaxXHeat.of(widget.streak));
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15);
    final text = context.textStyles.label.copyWith(
      color: const Color(0xFFFFFFFF),
      fontWeight: FontWeight.w800,
      height: 1,
      shadows: const [
        Shadow(color: Color(0xF23C0008), blurRadius: 3),
        Shadow(color: Color(0xF23C0008), offset: Offset(0, 1)),
      ],
    );
    final roll = KMotion.of(context, const Duration(milliseconds: 280));
    final number = AnimatedSwitcher(
      duration: roll,
      transitionBuilder: (child, a) => ClipRect(
        child: SlideTransition(
          position: Tween(
            begin: Offset(0, child.key == ValueKey(widget.count) ? 0.9 : -0.9),
            end: Offset.zero,
          ).animate(a),
          child: FadeTransition(opacity: a, child: child),
        ),
      ),
      child: Text(
        'x${widget.count}',
        key: ValueKey(widget.count),
        maxLines: 1,
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        style: text.copyWith(
          fontSize: r * .4,
          fontStyle: FontStyle.italic,
          color: const Color(0xFFFFE27A),
        ),
      ),
    );
    // D145e (owner: «ماكس 264» was cut): the label stays inside the orb's
    // circle ([labelWidthOf]) and scales down to fit; from four digits the
    // word gives way to the number alone.
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (MaxXOrb.showsWord(widget.count)) ...[
          Text(
            widget.word,
            maxLines: 1,
            textScaler: scaler,
            style: text.copyWith(fontSize: r * .3),
          ),
          SizedBox(width: r * .1),
        ],
        KeyedSubtree(key: widget.countKey, child: number),
      ],
    );
    final repaint = Listenable.merge([_now, _press, widget.ring]);
    return SizedBox.square(
      dimension: size,
      child: AnimatedBuilder(
        animation: repaint,
        builder: (context, child) {
          final left = 1 - widget.ring.value;
          final urgentShare =
              LuckyComboController.urgentTime.inMilliseconds /
              LuckyComboController.ringTime.inMilliseconds;
          final urgent = left > 0 && left < urgentShare;
          final now = _now.value;
          final tt = _press.isAnimating || _press.value > 0 && _press.value < 1
              ? _press.value * 1.2
              : -1.0;
          final tremble = moving && urgent
              ? math.sin(now * 60) * 1.2 * (1 - left / urgentShare)
              : 0.0;
          var scale = 1.0;
          if (tt >= 0 && tt < .5) {
            scale = tt < .07
                ? 1 - .14 * (tt / .07)
                : .86 +
                      .22 * _eob(_c01((tt - .07) / .3)) -
                      .08 * _eio(_c01((tt - .3) / .2));
          }
          final hop = tt >= 0 && tt < .4 ? math.sin(tt / .4 * math.pi) : 0.0;
          return Transform.translate(
            offset: Offset(tremble, 0),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  key: widget.ringKey,
                  size: Size.square(size),
                  painter: MaxXOrbPainter(
                    heat: heat,
                    now: now,
                    tapT: tt,
                    left: left,
                    urgent: urgent,
                    level: math.min(
                      1,
                      math.log(widget.streak + 1) / math.ln10 / 2,
                    ),
                    animated: moving,
                  ),
                ),
                Transform.scale(
                  scale: scale * (moving ? 1 + .018 * math.sin(now * 3.9) : 1),
                  child: SizedBox.square(
                    dimension: size,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: size / 2 - r * .26 - r * .4 - hop * 6,
                          height: r * .8,
                          child: Transform.rotate(
                            angle: hop * .12 * math.sin(tt * 30),
                            child: Center(
                              child: KGiftImage(
                                widget.assetKey,
                                imageUrl: widget.imageUrl,
                                size: r * (1 + .12 * hop),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: (size - MaxXOrb.labelWidthOf(r)) / 2,
                          width: MaxXOrb.labelWidthOf(r),
                          top: size / 2 + r * .2,
                          height: r * .5,
                          child: FittedBox(
                            key: MaxXOrb.labelKey,
                            fit: BoxFit.scaleDown,
                            child: label,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (tt >= 0 && tt < .9)
                  Positioned(
                    top: size / 2 - r * 1.4 - r * .6 * _eo(tt / .9),
                    left: size / 2 + r * .3,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: _c01(1 - (tt / .9) * (tt / .9)),
                        child: Text(
                          '+1',
                          textDirection: TextDirection.ltr,
                          textScaler: scaler,
                          style: text.copyWith(
                            fontSize: r * .34,
                            fontStyle: FontStyle.italic,
                            color: const Color(0xFFFFE27A),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Paints the orb (owner's `_MaxXPainter`, without the text and gift).
class MaxXOrbPainter extends CustomPainter {
  const new({
    required this.heat,
    required this.now,
    required this.tapT,
    required this.left,
    required this.urgent,
    required this.level,
    required this.animated,
  });

  final MaxXHeatColors heat;

  /// Seconds on the orb's clock (0 when still).
  final double now;

  /// Seconds since the last tap, or −1.
  final double tapT;

  /// The countdown left (1 → 0).
  final double left;

  /// The ring's last second.
  final bool urgent;

  /// 0–1: how hot (the streak, logarithmic).
  final double level;

  /// False with reduced motion and in tests: nothing moves but the ring.
  final bool animated;

  @override
  void paint(Canvas canvas, Size size) {
    final r = MaxXOrb.radiusOf(size.width);
    final h = heat;
    final tt = tapT;
    final bp = urgent && animated ? now * 8 : now * 2 * math.pi / 1.6;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2);

    // Glow: breathing, stronger the longer the streak, flaring on a tap.
    final gl =
        .5 +
        (animated ? .25 * math.sin(bp) : 0) +
        .3 * level +
        (tt >= 0 && tt < .5 ? .6 * (1 - tt / .5) : 0);
    canvas.drawCircle(
      Offset.zero,
      r * 1.75,
      Paint()
        ..shader = RadialGradient(
          colors: [
            h.glow.withValues(alpha: _c01(.6 * gl)),
            h.glow.withValues(alpha: 0),
          ],
          stops: const [.29, 1],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 1.75)),
    );

    if (tt >= 0 && tt < 1.2) {
      // Shockwave and its tier-coloured echo.
      for (final (d, c) in [(0.0, const Color(0xFFFFFFFF)), (.08, h.glow)]) {
        final q = _c01((tt - d) / .55);
        if (tt < d || q >= 1) continue;
        canvas.drawCircle(
          Offset.zero,
          r * (1.02 + .8 * _eo(q)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8 * (1 - q) + .5
            ..color = c.withValues(alpha: (1 - q) * .85),
        );
      }
      // 16 sparks with gravity.
      if (tt < .8) {
        final q = tt / .8;
        for (var i = 0; i < 16; i++) {
          final a = i / 16 * 2 * math.pi;
          final sp = .8 + (i * 37 % 10) / 10 * .6;
          final d = r * (1 + .95 * sp * _eo(q));
          final p = Offset(math.cos(a) * d, math.sin(a) * d + r * .5 * q * q);
          final v = Offset(math.cos(a), math.sin(a) + q * .8);
          final tail = r * .22 * (1 - q) * sp;
          final col = i % 3 == 0
              ? const Color(0xFFFFFFFF)
              : (i % 3 == 1 ? const Color(0xFFFFE27A) : h.glow);
          canvas.drawLine(
            p,
            p - v / v.distance * tail,
            Paint()
              ..color = col.withValues(alpha: _c01(1 - q * q))
              ..strokeWidth = 2 * (1 - q * .6)
              ..strokeCap = StrokeCap.round,
          );
        }
      }
    }

    // Sparkles orbiting the rim (faster with the streak).
    if (animated) {
      for (var i = 0; i < 3; i++) {
        final a = now * (1.6 + level * 3) + i * 2 * math.pi / 3;
        canvas
          ..save()
          ..translate(math.cos(a) * (r + 6), math.sin(a) * (r + 6));
        _star(
          canvas,
          4,
          Paint()
            ..color = h.glow.withValues(alpha: .6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        _star(
          canvas,
          2.8,
          Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: .95),
        );
        canvas.restore();
      }
    }

    // Rim.
    final rimRect = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = SweepGradient(
          colors: [h.rimA, h.rimB, const Color(0xFFFFFFFF), h.rimB, h.rimA],
          stops: const [0, .33, .5, .66, 1],
          transform: GradientRotation(now * 1.2),
        ).createShader(rimRect),
    );

    // Energy arcs (counter-rotating).
    if (animated) {
      for (final (speed, sweep, count, width, alpha) in const [
        (2.2, .5, 3, 2.0, .9),
        (-1.5, .25, 5, 1.3, .6),
      ]) {
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = width
          ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha);
        for (var i = 0; i < count; i++) {
          canvas.drawArc(
            Rect.fromCircle(center: Offset.zero, radius: r + 3),
            now * speed + i * 2 * math.pi / count,
            sweep,
            false,
            p,
          );
        }
      }
    }

    // Countdown: the time left, clockwise from the top; urgent: orange,
    // flickering.
    final cr = r - 3.2;
    canvas.drawCircle(
      Offset.zero,
      cr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..color = const Color(0x99280008),
    );
    if (left > 0) {
      final col = urgent
          ? Color.fromARGB(
              255,
              255,
              (150 + (animated ? 60 * math.sin(now * 14) : 0)).round(),
              40,
            )
          : const Color(0xFFFFFFFF);
      final sweep = 2 * math.pi * _c01(left);
      final arcRect = Rect.fromCircle(center: Offset.zero, radius: cr);
      canvas
        ..drawArc(
          arcRect,
          -math.pi / 2,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round
            ..color = col.withValues(alpha: .4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        )
        ..drawArc(
          arcRect,
          -math.pi / 2,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.5
            ..strokeCap = StrokeCap.round
            ..color = col,
        );
      final ea = -math.pi / 2 + sweep;
      canvas.drawCircle(
        Offset(math.cos(ea) * cr, math.sin(ea) * cr),
        3,
        Paint()..color = const Color(0xFFFFFFFF),
      );
    }

    // The orb: a lit sphere with swirling light, an inner shadow, the tap
    // flash and a shine across it every ~2 s.
    final br = r - 7;
    final orbRect = Rect.fromCircle(center: Offset.zero, radius: br);
    canvas
      ..drawCircle(
        Offset.zero,
        br,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.3, -.42),
            colors: [h.light, h.mid, h.dark],
            stops: const [0, .48, 1],
          ).createShader(orbRect),
      )
      ..save()
      ..clipPath(Path()..addOval(orbRect))
      ..save()
      ..rotate(now * .6);
    for (var i = 0; i < 2; i++) {
      canvas
        ..rotate(math.pi)
        ..drawCircle(
          Offset(br * .5, 0),
          br * .9,
          Paint()
            ..shader =
                RadialGradient(
                  colors: [
                    const Color(0xFFFFFFFF).withValues(alpha: .16),
                    const Color(0x00FFFFFF),
                  ],
                ).createShader(
                  Rect.fromCircle(center: Offset(br * .5, 0), radius: br * .9),
                ),
        );
    }
    canvas
      ..restore()
      ..drawRect(
        orbRect,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0x00000000), Color(0x59000000)],
            stops: [.7, 1],
          ).createShader(orbRect),
      );
    if (tt >= 0 && tt < .18) {
      canvas.drawRect(
        orbRect,
        Paint()
          ..color = const Color(0xFFFFFFFF)
              .withValues(alpha: .55 * (1 - tt / .18)),
      );
    }
    final sw = (now % 2.2) / 2.2;
    if (animated && sw < .35) {
      final sx = -br + 2 * br * (sw / .35);
      canvas
        ..save()
        ..rotate(.3)
        ..drawRect(
          Rect.fromLTWH(sx - 10, -br * 1.3, 20, br * 2.6),
          Paint()
            ..shader = LinearGradient(
              colors: [
                const Color(0x00FFFFFF),
                const Color(0xFFFFFFFF).withValues(alpha: .35),
                const Color(0x00FFFFFF),
              ],
            ).createShader(Rect.fromLTWH(sx - 10, 0, 20, 1)),
        )
        ..restore();
    }
    canvas.restore();
    // Gloss.
    final glossRect = Rect.fromCenter(
      center: Offset(0, -r * .52),
      width: r * 1.04,
      height: r * .4,
    );
    canvas
      ..drawOval(
        glossRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFFFFFF).withValues(alpha: .45),
              const Color(0x00FFFFFF),
            ],
          ).createShader(glossRect),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(MaxXOrbPainter old) =>
      old.now != now ||
      old.tapT != tapT ||
      old.left != left ||
      old.urgent != urgent ||
      old.level != level ||
      old.heat != heat ||
      old.animated != animated;
}

/// D145d: the celebration of one winning send (owner's per-tier design):
/// the ring, the ribbon banner «x100» (with «جاكبوت» / «JACKPOT» at ×500
/// and «سوبر جاكبوت» / «SUPER JACKPOT» at ×1000), the coins it won, a coin
/// fountain, sparkles, a sunburst from ×50 and a shake from ×25 (D148: a
/// win the guarantee paid says «ضمان» / «Guaranteed» over it). Painted
/// around the button's centre ([centre]) over the room; never takes taps.
/// The numbers are the server's ([win]); the tier only picks the look.
/// With reduced motion the banner shows still, without rays, coins or
/// shake. Calls [onDone] when it is over.
class MaxXCelebration extends StatefulWidget {
  const new({
    required this.win,
    required this.centre,
    required this.radius,
    required this.onDone,
    super.key,
  });

  final MaxXWin win;
  final Offset centre;

  /// The orb's radius (the celebration scales with it).
  final double radius;
  final VoidCallback onDone;

  static const bannerKey = Key('maxx.win');

  @override
  State<MaxXCelebration> createState() => _MaxXCelebrationState();
}

class _MaxXCelebrationState extends State<MaxXCelebration>
    with SingleTickerProviderStateMixin {
  late final MaxXWinStyle _style = MaxXWinStyle.of(
    MaxXTiers.winTierOf(widget.win.multiplier) ?? MaxXTiers.win.first,
  );
  late final AnimationController _c = AnimationController(
    vsync: this,
    // The banner's time, or the coin fountain's (1.55 s) when longer.
    duration: _style.seconds < 1.6
        ? const Duration(milliseconds: 1600)
        : _style.duration,
    // With reduced motion the still banner stays as long (not cut short).
    animationBehavior: AnimationBehavior.preserve,
  );

  @override
  void initState() {
    super.initState();
    if (_style.tier >= 100) unawaited(HapticFeedback.heavyImpact());
    unawaited(
      _c.forward().whenComplete(() {
        if (mounted) widget.onDone();
      }),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final win = widget.win;
    final title = switch (_style.tier) {
      1000 => l10n.liveMaxXSuperJackpot,
      500 => l10n.liveMaxXJackpot,
      // D148: the guarantee's win (×5) says so, small, over its banner.
      _ when win.guaranteed => l10n.liveMaxXGuaranteed,
      _ => null,
    };
    final spoken = l10n.liveLuckyWon(
      KFormat.bidiIsolate(KFormat.grouped(win.coins)),
      KFormat.grouped(win.multiplier),
    );
    final still = MediaQuery.disableAnimationsOf(context);
    final family = context.textStyles.label.fontFamily;
    return Positioned(
      left: widget.centre.dx,
      top: widget.centre.dy,
      child: IgnorePointer(
        child: Semantics(
          key: MaxXCelebration.bannerKey,
          liveRegion: true,
          label: title == null ? spoken : '$title, $spoken',
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              painter: MaxXWinPainter(
                style: _style,
                multiplier: win.multiplier,
                coins: win.coins,
                title: title,
                t: _c.value * _c.duration!.inMicroseconds / 1e6,
                r: widget.radius,
                still: still,
                fontFamily: family,
                spaceLeft: widget.centre.dx,
                spaceRight: MediaQuery.sizeOf(context).width - widget.centre.dx,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints one win celebration around the origin (owner's win layers).
class MaxXWinPainter extends CustomPainter {
  const new({
    required this.style,
    required this.multiplier,
    required this.coins,
    required this.title,
    required this.t,
    required this.r,
    required this.still,
    this.fontFamily,
    this.spaceLeft = double.infinity,
    this.spaceRight = double.infinity,
    this.banner = true,
    this.bannerDy,
  });

  final MaxXWinStyle style;

  /// D145e: false paints only the burst (rays, rings, coin fountain) — the
  /// room's big-win card draws its own numbers over it.
  final bool banner;

  /// The banner's centre from the origin; null: above the button, clear of
  /// the streak's winnings chip ([bannerDyAt]).
  final double? bannerDy;

  /// D145e (owner: «×10 +550» and «×100 +2,300» overlapped each other and the
  /// orb): where the banner's centre goes above the button's centre [r], so
  /// that — at its largest (the entrance overshoot ×1.12) — the "+coins" line
  /// under it ends [gap] above the winnings chip that sits on the orb.
  static double bannerDyAt(
    MaxXWinStyle style,
    double r, {
    required bool coins,
    double gap = 10,
  }) {
    final rh = r * style.size * 1.25 * .95;
    final below = coins ? rh * .8 + r * .2 : rh / 2;
    return -(r * chipTop + gap + below * 1.12);
  }

  /// The top of the winnings chip over the orb, in orb radii from its centre
  /// (the orb's top, 2 pt and the chip's ~20 pt at the cluster's size).
  static const double chipTop = 1.65;
  final int multiplier;
  final int coins;
  final String? title;

  /// Seconds since the win.
  final double t;
  final double r;

  /// Reduced motion: the banner only, still.
  final bool still;
  final String? fontFamily;

  /// Room from the origin to the screen's left and right edges.
  final double spaceLeft;
  final double spaceRight;

  TextPainter _tp(String s, TextStyle st) => TextPainter(
    text: TextSpan(
      text: s,
      style: st.copyWith(fontFamily: fontFamily),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();

  void _outlined(
    Canvas canvas,
    String s,
    TextStyle st,
    double alpha,
    double stroke, {
    required List<Color> fill,
    double dy = 0,
  }) {
    final o = _tp(
      s,
      st.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xF23C0008).withValues(alpha: alpha),
      ),
    );
    final f = _tp(
      s,
      st.copyWith(
        foreground: Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [for (final c in fill) c.withValues(alpha: alpha)],
          ).createShader(Rect.fromLTWH(0, -o.height / 2 + dy, 1, o.height)),
      ),
    );
    o.paint(canvas, Offset(-o.width / 2, -o.height / 2 + dy));
    f.paint(canvas, Offset(-f.width / 2, -f.height / 2 + dy));
  }

  void _coin(Canvas canvas, double d, double alpha) {
    final dst = Rect.fromCenter(center: Offset.zero, width: d, height: d);
    canvas
      ..drawCircle(
        Offset.zero,
        d / 2,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.3, -.4),
            colors: [
              const Color(0xFFFFF6C8).withValues(alpha: alpha),
              const Color(0xFFF8CF5A).withValues(alpha: alpha),
              const Color(0xFFB8780A).withValues(alpha: alpha),
            ],
          ).createShader(dst),
      )
      ..drawCircle(
        Offset.zero,
        d * .36,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = d * .06
          ..color = const Color(0xFF8A5508).withValues(alpha: alpha),
      );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = style;
    final wt = still ? w.seconds * .5 : t;
    final now = t;
    final shown = wt >= 0 && wt < w.seconds;
    final shake = !still && shown && w.shake > 0
        ? math.sin(now * 70) * 4 * w.shake * math.max(0, 1 - wt / .6)
        : 0.0;
    canvas
      ..save()
      ..translate(shake, 0);

    // Sunburst (×50 and up; ×500 and up: two counter-rotating, rainbow).
    if (!still && shown && w.rays > 0) {
      final q = _c01(wt / w.seconds);
      final a = math.sin(q * math.pi) * .6;
      final nr = w.tier >= 1000 ? 28 : (w.tier >= 100 ? 20 : 16);
      final len = r * (1.4 + w.rays) * _eo(math.min(1, q * 2.5)) + r;
      for (final dir in w.tier >= 500 ? const [1.0, -1.0] : const [1.0]) {
        canvas
          ..save()
          ..rotate(now * .8 * dir);
        for (var i = 0; i < nr; i++) {
          canvas.rotate(2 * math.pi / nr);
          final rc = w.ribbon == null
              ? HSLColor.fromAHSL(
                  1,
                  (i * 24 + now * 120) % 360,
                  1,
                  .8,
                ).toColor()
              : w.color;
          canvas.drawPath(
            Path()
              ..moveTo(r * .6, -r * .08)
              ..lineTo(len, -r * .22)
              ..lineTo(len, r * .22)
              ..lineTo(r * .6, r * .08)
              ..close(),
            Paint()
              ..shader = LinearGradient(
                colors: [
                  rc.withValues(alpha: 0),
                  rc.withValues(alpha: .95 * a),
                  rc.withValues(alpha: 0),
                ],
                stops: const [0, .25, 1],
              ).createShader(Rect.fromLTWH(0, 0, len, 1)),
          );
        }
        canvas.restore();
      }
    }
    // Rings (×1000: extra rainbow rings).
    if (!still && shown) {
      if (w.tier >= 1000) {
        for (final d in const [.25, .5]) {
          final q = _c01((wt - d) / .8);
          if (wt < d || q >= 1) continue;
          canvas.drawCircle(
            Offset.zero,
            r * (1 + 1.6 * _eo(q)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 10 * (1 - q) + 1
              ..color = HSLColor.fromAHSL(
                1 - q,
                (d * 400 + now * 200) % 360,
                1,
                .7,
              ).toColor(),
          );
        }
      }
      final q = _c01(wt / .7);
      canvas.drawCircle(
        Offset.zero,
        r * (1 + 1.1 * _eo(q)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12 * (1 - q) + 1
          ..color = w.color.withValues(alpha: 1 - q),
      );
    }

    // Coin fountain.
    if (!still) {
      double fr(double v) {
        final s = math.sin(v) * 43758.5453;
        return s - s.floorToDouble();
      }

      for (var i = 0; i < w.coins; i++) {
        final s1 = fr(i * 12.9898 + w.tier * .37);
        final s2 = fr(i * 78.233 + w.tier * 1.7);
        final q = t - fr(i * 3.1 + 1) * .45;
        if (q < 0) continue;
        final vx = (s1 - .5) * r * 5.5;
        final vy = -r * (3.2 + s2 * 3.8) * (w.tier >= 100 ? 1.15 : 1);
        final g = r * 9;
        final p = Offset(vx * q, -r * .2 + vy * q + .5 * g * q * q);
        final alpha = _c01(1 - (q - 1.1) / .4);
        if (alpha <= 0) continue;
        canvas
          ..save()
          ..translate(p.dx, p.dy)
          ..scale(math.cos(q * 10 + i) * .9 + .1, 1);
        _coin(canvas, r * .26 * (.8 + s2 * .4), alpha);
        canvas.restore();
      }
    }

    if (shown && banner) {
      // Banner.
      final q = _c01(wt / w.seconds);
      final sIn = still
          ? 1.0
          : q < .18
          ? _eob(q / .18) * 1.12
          : 1.12 - .12 * _c01((q - .18) / .15);
      final al = still ? 1.0 : (q > .8 ? 1 - (q - .8) / .2 : 1.0);
      // Above the streak's winnings chip over the button.
      final by =
          (bannerDy ?? bannerDyAt(style, r, coins: coins > 0)) +
          (still ? 0 : math.sin(wt * 6) * 2);
      final txt = 'x$multiplier';
      final fs = r * w.size * 1.25;
      final numStyle = TextStyle(
        fontSize: fs,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        height: 1,
      );
      final tw = _tp(txt, numStyle).width;
      final rw = tw + fs * 1.1;
      // The button sits near a screen edge: the banner moves in just
      // enough to stay whole on screen.
      final half = rw / 2 * 1.12 + 8;
      final bx = half > spaceLeft
          ? half - spaceLeft
          : (half > spaceRight ? spaceRight - half : 0.0);
      canvas
        ..save()
        ..translate(bx, by)
        ..scale(sIn);
      final rh = fs * .95;
      final rib = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: rw, height: rh),
        Radius.circular(rh / 2),
      );
      final ribRect = rib.outerRect;
      final ribCols =
          w.ribbon ??
          (w.tier >= 1000
              ? const [
                  Color(0xFFFFF3B0),
                  Color(0xFFFFC93C),
                  Color(0xFFFF6FA5),
                  Color(0xFFB04DFF),
                  Color(0xFF4FB0FF),
                  Color(0xFFFFC93C),
                  Color(0xFFFFF3B0),
                ]
              : [
                  for (var k = 0; k <= 6; k++)
                    HSLColor.fromAHSL(
                      1,
                      (k * 60 + now * 160) % 360,
                      .95,
                      .6,
                    ).toColor(),
                ]);
      canvas
        ..drawRRect(
          rib,
          Paint()
            ..color = w.color.withValues(alpha: .9 * al)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        )
        ..saveLayer(
          ribRect.inflate(4),
          Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: al),
        )
        ..drawRRect(
          rib,
          Paint()
            ..shader =
                (w.ribbon != null
                        ? LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: ribCols,
                          )
                        : LinearGradient(
                            colors: ribCols,
                            transform: w.tier >= 1000
                                ? GradientRotation(now * .6)
                                : null,
                          ))
                    .createShader(ribRect),
        )
        ..drawRRect(
          rib,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFFFFFFFF).withValues(alpha: .85),
        );
      if (!still) {
        final sx = -rw / 2 + rw * 1.4 * ((wt * 1.2) % 1);
        canvas
          ..save()
          ..clipRRect(rib)
          ..drawRect(
            Rect.fromLTWH(sx - 14, -rh, 28, rh * 2),
            Paint()
              ..shader = LinearGradient(
                colors: [
                  const Color(0x00FFFFFF),
                  const Color(0xFFFFFFFF).withValues(alpha: .6),
                  const Color(0x00FFFFFF),
                ],
              ).createShader(Rect.fromLTWH(sx - 14, 0, 28, 1)),
          )
          ..restore();
      }
      canvas.restore();
      _outlined(
        canvas,
        txt,
        numStyle,
        al,
        fs * .14,
        fill: w.numberColors,
        dy: fs * .04,
      );
      // JACKPOT / SUPER JACKPOT.
      if (title case final label?) {
        canvas
          ..save()
          ..translate(0, -rh * .85);
        _outlined(
          canvas,
          label,
          TextStyle(
            fontSize: r * (w.tier >= 1000 ? .34 : .3),
            fontWeight: FontWeight.w800,
            height: 1,
          ),
          al,
          4,
          fill: const [Color(0xFFFFF6C8), Color(0xFFFFF6C8)],
        );
        canvas.restore();
      }
      // The coins this send won (the server's number).
      if (coins > 0) {
        final ct = '+${KFormat.grouped(coins)}';
        final cs = TextStyle(
          fontSize: r * .32,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.italic,
          height: 1,
        );
        final cw = _tp(ct, cs).width;
        final isz = r * .34;
        final y2 = rh * .8;
        final ox = -(cw + isz + 4) / 2;
        canvas
          ..save()
          ..translate(ox + isz / 2, y2);
        _coin(canvas, isz, al);
        canvas
          ..restore()
          ..save()
          ..translate(ox + isz + 4 + cw / 2, y2);
        _outlined(
          canvas,
          ct,
          cs,
          al,
          4,
          fill: const [Color(0xFFFFE27A), Color(0xFFFFE27A)],
        );
        canvas.restore();
      }
      canvas.restore();
      // Sparkles around the banner.
      if (!still) {
        final ns = w.tier >= 100 ? 8 : 4;
        for (var i = 0; i < ns; i++) {
          final a = i / ns * 2 * math.pi + wt * 2;
          final rr = r * (1 + .2 * math.sin(wt * 5 + i));
          final sa = math.max(0, math.sin(wt * 8 + i * 1.7)).toDouble();
          canvas
            ..save()
            ..translate(
              bx + math.cos(a) * rr * 1.3,
              by + math.sin(a) * rr * .5,
            );
          _star(
            canvas,
            r * .08 * (.5 + sa),
            Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: sa * al),
          );
          canvas.restore();
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MaxXWinPainter old) =>
      old.t != t ||
      old.style != style ||
      old.multiplier != multiplier ||
      old.coins != coins ||
      old.title != title ||
      old.still != still ||
      old.r != r ||
      old.spaceLeft != spaceLeft ||
      old.spaceRight != spaceRight ||
      old.banner != banner ||
      old.bannerDy != bannerDy;
}
