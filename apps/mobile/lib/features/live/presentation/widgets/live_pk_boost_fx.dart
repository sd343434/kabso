import 'dart:math' as math;

import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D199 (owner: «طريقة عرض تفعيل التربيل او تيربو سيء»): the booster's
/// activation and active state, per tier, on the activating side only.
///
/// | Booster | Glow | Extras |
/// | --- | --- | --- |
/// | Double ×2 | gold | — |
/// | Double Turbo ×3 | orange / fire | speed streaks |
/// | Triple ×5 | purple / magenta | electric sparks |
/// | Triple Turbo ×10 | rainbow / fire | particles, the strongest glow, the
/// side's screen edge pulses |
@immutable
class PkBoostTier {
  const new({
    required this.glow,
    required this.gradient,
    required this.streaks,
    required this.sparks,
    required this.particles,
    required this.edgePulse,
    required this.glowRadius,
  });

  factory of(PkBoosterKind kind) => switch (kind) {
    PkBoosterKind.double => const PkBoostTier(
      glow: Color(0xFFFFC83D),
      gradient: [Color(0xFFFFF1A8), Color(0xFFFFC83D), Color(0xFFE59A00)],
      streaks: false,
      sparks: false,
      particles: false,
      edgePulse: false,
      glowRadius: 18,
    ),
    PkBoosterKind.doubleTurbo => const PkBoostTier(
      glow: Color(0xFFFF7A1A),
      gradient: [Color(0xFFFFD27A), Color(0xFFFF7A1A), Color(0xFFE53B00)],
      streaks: true,
      sparks: false,
      particles: false,
      edgePulse: false,
      glowRadius: 22,
    ),
    PkBoosterKind.triple => const PkBoostTier(
      glow: Color(0xFFD63CFF),
      gradient: [Color(0xFFF7A8FF), Color(0xFFD63CFF), Color(0xFF7B1FC9)],
      streaks: false,
      sparks: true,
      particles: false,
      edgePulse: false,
      glowRadius: 26,
    ),
    PkBoosterKind.tripleTurbo => const PkBoostTier(
      glow: Color(0xFFFF4D2E),
      gradient: [
        Color(0xFFFFE14D),
        Color(0xFFFF7A1A),
        Color(0xFFFF2E63),
        Color(0xFFB03CFF),
        Color(0xFF3CA0FF),
      ],
      streaks: true,
      sparks: true,
      particles: true,
      edgePulse: true,
      glowRadius: 34,
    ),
  };

  final Color glow;
  final List<Color> gradient;
  final bool streaks;
  final bool sparks;
  final bool particles;
  final bool edgePulse;
  final double glowRadius;
}

/// The booster's Kabso-made gift art (assets/gifts/pk, D195).
String pkBoosterArt(PkBoosterKind kind) => switch (kind) {
  PkBoosterKind.double => 'assets/gifts/pk/booster_double.png',
  PkBoosterKind.doubleTurbo => 'assets/gifts/pk/booster_double_turbo.png',
  PkBoosterKind.triple => 'assets/gifts/pk/booster_triple.png',
  PkBoosterKind.tripleTurbo => 'assets/gifts/pk/booster_triple_turbo.png',
};

/// The activation line's style. D199 text fix: D195 drew it in the app's
/// Arabic face (Readex Pro) at bold, whose medial «ع» fills its counter, so
/// with the shadda above it «فعّل» read «فقل» (measured at 15 lp @3x).
/// Baloo Bhaijaan 2 ExtraBold (bundled, OFL) keeps the «ع» open and the
/// shadda clear; Latin falls back to Inter.
abstract final class PkBoostText {
  static const family = 'Baloo Bhaijaan 2';
}

TextStyle pkBoostLineStyle(BuildContext context) =>
    context.textStyles.bodyStrong.copyWith(
      fontFamily: PkBoostText.family,
      fontFamilyFallback: const ['Inter'],
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.w800,
      color: const Color(0xFFFFFFFF),
      shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 4)],
    );

/// The activation (about 2.3 s) over the activating side's video box: a
/// banner sweeps in from that side's outer edge with the booster art, large
/// and glowing, the multiplier punching in (scale and a short shake) and
/// «فعّل فريق {host} {booster}»; then it shrinks and flies into the side's
/// chip under the bar (the box's outer top corner). Reduced motion: a fade.
class PkBoostBurst extends StatefulWidget {
  const new({
    required this.kind,
    required this.multiplier,
    required this.teamName,
    required this.outerIsStart,
    super.key,
    this.progress,
  });

  final PkBoosterKind kind;
  final int multiplier;
  final String teamName;

  /// This box's outer edge is the reading start (this room's own side).
  final bool outerIsStart;

  /// A fixed point of the animation (0–1) for goldens and captures.
  final double? progress;

  static const duration = Duration(milliseconds: 2300);

  /// Goldens and captures through the real screens: every burst holds this
  /// point of its animation (null: it plays).
  static double? debugProgress;
  static const lineKey = Key('pk.boost.line');
  static const multiplierKey = Key('pk.boost.multiplier');

  @override
  State<PkBoostBurst> createState() => _PkBoostBurstState();
}

class _PkBoostBurstState extends State<PkBoostBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: PkBoostBurst.duration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.progress ?? PkBoostBurst.debugProgress case final p?) {
      _c.value = p;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tier = PkBoostTier.of(widget.kind);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final line = l10n.pkBoostActivated(
      KFormat.bidiIsolate(widget.teamName),
      _boosterName(l10n, widget.kind),
    );
    return Semantics(
      liveRegion: true,
      label: '$line ×${widget.multiplier}',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          if (reduced) {
            // A simple fade in and out, no movement.
            final o = t < 0.2
                ? t / 0.2
                : t > 0.8
                ? (1 - t) / 0.2
                : 1.0;
            return Opacity(
              opacity: o.clamp(0.0, 1.0),
              child: Center(child: _banner(context, tier, line, 1, 0, 0)),
            );
          }
          final dir = Directionality.of(context);
          // The outer edge in screen terms (+1 right, -1 left).
          final outerRight = (dir == TextDirection.ltr) != widget.outerIsStart;
          final sx = outerRight ? 1.0 : -1.0;
          final sweep = Curves.easeOutCubic.transform(_seg(t, 0, 0.16));
          final punch = _seg(t, 0.12, 0.34);
          final fly = Curves.easeInCubic.transform(_seg(t, 0.74, 1));
          final numScale = punch == 0
              ? 0.0
              : punch < 0.45
              ? 1.9 - 0.9 * Curves.easeOut.transform(punch / 0.45)
              : 1.0 + 0.06 * math.sin((punch - 0.45) * math.pi * 2);
          final shake = punch > 0.2 && punch < 0.8
              ? math.sin(punch * math.pi * 14) * 4 * (1 - punch)
              : 0.0;
          final scale = 1 - 0.78 * fly;
          // Into the chip: the box's outer top corner.
          final target = Alignment(0.86 * sx, -0.98);
          final at = Alignment.lerp(Alignment.center, target, fly)!;
          final dx = (1 - sweep) * 260 * sx;
          final opacity = (sweep * (1 - 0.6 * fly)).clamp(0.0, 1.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              if (tier.edgePulse)
                IgnorePointer(
                  child: _EdgePulse(
                    color: tier.glow,
                    right: outerRight,
                    strength: math.sin(_seg(t, 0.05, 0.8) * math.pi),
                  ),
                ),
              IgnorePointer(
                child: CustomPaint(
                  painter: PkBoostFxPainter(
                    tier: tier,
                    t: t,
                    fade: 1 - fly,
                    fromRight: outerRight,
                  ),
                ),
              ),
              Align(
                alignment: at,
                child: Transform.translate(
                  offset: Offset(dx + shake, 0),
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      child: _banner(context, tier, line, numScale, sweep, fly),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _banner(
    BuildContext context,
    PkBoostTier tier,
    String line,
    double numScale,
    double sweep,
    double fly,
  ) {
    final glow = tier.glow;
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [glow.withValues(alpha: 0.55), const Color(0xCC14060A)],
        ),
        border: Border.all(color: glow, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.75),
            blurRadius: tier.glowRadius,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: glow.withValues(alpha: 0.9),
                      blurRadius: tier.glowRadius,
                    ),
                  ],
                ),
                child: Image.asset(
                  pkBoosterArt(widget.kind),
                  width: 54,
                  height: 54,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.bolt_rounded,
                    size: 48,
                    color: tier.gradient.first,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // ×10 fits a narrow box (360 lp): it shrinks, never overflows.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Transform.scale(
                    scale: numScale,
                    child: ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (r) => LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: tier.gradient,
                      ).createShader(r),
                      child: Text(
                        '×${widget.multiplier}',
                        key: PkBoostBurst.multiplierKey,
                        textDirection: TextDirection.ltr,
                        textScaler: TextScaler.noScaling,
                        style: context.textStyles.title.copyWith(
                          fontFamily: 'Inter',
                          fontSize: 42,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFFFFFFFF),
                          shadows: [Shadow(color: glow, blurRadius: 12)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            line,
            key: PkBoostBurst.lineKey,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textScaler: MediaQuery.textScalerOf(context)
                .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
            style: pkBoostLineStyle(context),
          ),
        ],
      ),
    );
  }
}

String _boosterName(AppLocalizations l10n, PkBoosterKind kind) =>
    switch (kind) {
      PkBoosterKind.double => l10n.pkBoosterDouble,
      PkBoosterKind.doubleTurbo => l10n.pkBoosterDoubleTurbo,
      PkBoosterKind.triple => l10n.pkBoosterTriple,
      PkBoosterKind.tripleTurbo => l10n.pkBoosterTripleTurbo,
    };

/// The tier's extras, painted behind the banner: a radial glow; speed
/// streaks (Double Turbo, Triple Turbo) from the outer edge; electric
/// sparks (Triple, Triple Turbo); particles (Triple Turbo). Deterministic
/// (seeded) so goldens are stable.
class PkBoostFxPainter extends CustomPainter {
  const new({
    required this.tier,
    required this.t,
    required this.fade,
    required this.fromRight,
  });

  final PkBoostTier tier;
  final double t;
  final double fade;
  final bool fromRight;

  @override
  void paint(Canvas canvas, Size size) {
    if (fade <= 0) return;
    final c = size.center(Offset.zero);
    final appear = (t / 0.16).clamp(0.0, 1.0);
    final a = appear * fade;
    canvas.drawCircle(
      c,
      size.shortestSide * 0.62,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                tier.glow.withValues(alpha: 0.55 * a),
                tier.glow.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: c, radius: size.shortestSide * 0.62),
            ),
    );
    final rnd = math.Random(7);
    if (tier.streaks) {
      final p = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.2;
      for (var i = 0; i < 14; i++) {
        final y = size.height * (0.15 + 0.7 * rnd.nextDouble());
        final len = 30 + 60 * rnd.nextDouble();
        final speed = 0.6 + rnd.nextDouble();
        final x0 =
            ((t * speed * 3 + rnd.nextDouble()) % 1) * (size.width + len);
        final x = fromRight ? size.width - x0 : x0 - len;
        p.shader = LinearGradient(
          colors: [
            tier.gradient.first.withValues(alpha: 0),
            tier.gradient.first.withValues(alpha: 0.9 * a),
          ],
        ).createShader(Rect.fromLTWH(x, y, len, 2));
        canvas.drawLine(Offset(x, y), Offset(x + len, y), p);
      }
    }
    if (tier.sparks) {
      final p = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.9 * a)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke;
      final glow = Paint()
        ..color = tier.glow.withValues(alpha: 0.7 * a)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      final flicker = (t * 24).floor();
      for (var i = 0; i < 6; i++) {
        final r = math.Random(flicker * 31 + i);
        final ang = r.nextDouble() * math.pi * 2;
        final r0 = size.shortestSide * 0.22;
        final r1 = size.shortestSide * (0.42 + 0.1 * r.nextDouble());
        final path = Path()
          ..moveTo(c.dx + math.cos(ang) * r0, c.dy + math.sin(ang) * r0);
        for (var k = 1; k <= 4; k++) {
          final rr = r0 + (r1 - r0) * k / 4;
          final aa = ang + (r.nextDouble() - 0.5) * 0.5;
          path.lineTo(c.dx + math.cos(aa) * rr, c.dy + math.sin(aa) * rr);
        }
        canvas
          ..drawPath(path, glow)
          ..drawPath(path, p);
      }
    }
    if (tier.particles) {
      for (var i = 0; i < 26; i++) {
        final ang = rnd.nextDouble() * math.pi * 2;
        final speed = 0.5 + rnd.nextDouble();
        final d = size.shortestSide * 0.6 * ((t * speed * 1.4) % 1);
        final color = tier.gradient[i % tier.gradient.length];
        canvas.drawCircle(
          c + Offset(math.cos(ang) * d, math.sin(ang) * d),
          1.5 + 2.5 * rnd.nextDouble(),
          Paint()
            ..color = color.withValues(
              alpha: 0.85 * a * (1 - d / size.shortestSide),
            ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(PkBoostFxPainter old) =>
      old.t != t || old.fade != fade || old.tier != tier;
}

/// Triple Turbo: the side's outer screen edge pulses briefly.
class _EdgePulse extends StatelessWidget {
  const new({required this.color, required this.right, required this.strength});

  final Color color;
  final bool right;
  final double strength;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: right ? Alignment.centerRight : Alignment.centerLeft,
        end: right ? Alignment.centerLeft : Alignment.centerRight,
        stops: const [0, 0.22],
        colors: [
          color.withValues(alpha: 0.8 * strength.clamp(0.0, 1.0)),
          color.withValues(alpha: 0),
        ],
      ),
    ),
  );
}

/// While a booster runs: its chip under the bar on that side — the art,
/// «×5» and a ring counting down the booster's time (not just text).
class PkBoostChip extends StatelessWidget {
  const new({
    required this.kind,
    required this.multiplier,
    required this.left,
    required this.total,
    super.key,
  });

  final PkBoosterKind kind;
  final int multiplier;
  final Duration left;
  final Duration total;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tier = PkBoostTier.of(kind);
    final seconds = left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
    // Whole seconds, like the number inside (one repaint a second).
    final frac = total.inSeconds <= 0
        ? 0.0
        : (seconds / total.inSeconds).clamp(0.0, 1.0);
    return Semantics(
      label: l10n.pkBoostChipSemantics(
        _boosterName(l10n, kind),
        '$multiplier',
        '$seconds',
      ),
      excludeSemantics: true,
      child: Container(
        height: 24,
        padding: const EdgeInsetsDirectional.fromSTEB(2, 2, 3, 2),
        decoration: BoxDecoration(
          color: const Color(0xCC14060A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tier.glow, width: 1.2),
          boxShadow: [
            BoxShadow(color: tier.glow.withValues(alpha: 0.6), blurRadius: 8),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              pkBoosterArt(kind),
              width: 20,
              height: 20,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.bolt_rounded, size: 18, color: tier.glow),
            ),
            const SizedBox(width: 2),
            Text(
              '×$multiplier',
              textDirection: TextDirection.ltr,
              textScaler: TextScaler.noScaling,
              style: context.textStyles.caption.copyWith(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                color: tier.gradient.first,
              ),
            ),
            const SizedBox(width: 3),
            SizedBox.square(
              dimension: 18,
              child: CustomPaint(
                painter: _RingPainter(fraction: frac, color: tier.glow),
                child: Center(
                  child: Text(
                    '$seconds',
                    textScaler: TextScaler.noScaling,
                    style: context.textStyles.caption.copyWith(
                      fontFamily: 'Inter',
                      fontSize: 8,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFFFFFF),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const new({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(1.5);
    canvas
      ..drawArc(
        r,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0x33FFFFFF),
      )
      ..drawArc(
        r,
        -math.pi / 2,
        math.pi * 2 * fraction,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2
          ..color = color,
      );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color;
}

/// The glow over the boosted side's half of the score bar: it pulses in the
/// tier's colour while the booster runs and fades out when it ends.
class PkBarGlow extends StatefulWidget {
  const new({required this.kind, required this.active, super.key});

  /// The last booster (kept while the glow fades out).
  final PkBoosterKind? kind;
  final bool active;

  /// Pulses (off in widget tests: `LivePkStage.ticks`).
  static bool pulse = true;

  @override
  State<PkBarGlow> createState() => _PkBarGlowState();
}

class _PkBarGlowState extends State<PkBarGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 0.6,
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(PkBarGlow old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.active && PkBarGlow.pulse) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    if (kind == null) return const SizedBox.shrink();
    final tier = PkBoostTier.of(kind);
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: widget.active ? 1 : 0,
        duration: const Duration(milliseconds: 600),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: tier.glow.withValues(alpha: 0.6 + 0.4 * _c.value),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: tier.glow.withValues(alpha: 0.35 + 0.45 * _c.value),
                  blurRadius: 6 + 10 * _c.value,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «+N ×5» rising near the bar on the boosted side for each gift there.
class PkGainFloat extends StatelessWidget {
  const new({
    required this.points,
    required this.multiplier,
    required this.kind,
    super.key,
    this.progress,
  });

  final int points;
  final int multiplier;
  final PkBoosterKind kind;

  /// A fixed point (0–1) for goldens.
  final double? progress;

  static const duration = Duration(milliseconds: 1300);

  /// Goldens and captures: every float holds this point (null: it plays).
  static double? debugProgress;

  @override
  Widget build(BuildContext context) {
    final tier = PkBoostTier.of(kind);
    Widget label(double t) => Transform.translate(
      offset: Offset(0, -26 * t),
      child: Opacity(
        opacity: (t < 0.15 ? t / 0.15 : 1 - math.max(0, t - 0.6) / 0.4).clamp(
          0.0,
          1.0,
        ),
        child: Text(
          context.l10n.pkBoostGain(KFormat.grouped(points), '$multiplier'),
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.noScaling,
          style: context.textStyles.bodyStrong.copyWith(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            color: tier.gradient.first,
            shadows: [
              Shadow(color: tier.glow, blurRadius: 8),
              const Shadow(color: Color(0xCC000000), blurRadius: 2),
            ],
          ),
        ),
      ),
    );
    final p = progress ?? debugProgress;
    if (p != null || MediaQuery.disableAnimationsOf(context)) {
      return label(p ?? 0.4);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      builder: (context, t, _) => label(t),
    );
  }
}
