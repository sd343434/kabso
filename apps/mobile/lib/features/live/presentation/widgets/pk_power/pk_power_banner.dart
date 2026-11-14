// Kabso Live — PK power banner, shared by every tier (timings/intensity come
// from PkPowerFx).
//
//                     DOUBLE (gold)                          DOUBLE TURBO
// (orange/red)
//   entrance          0–450 ms, scale .82→1, centre streak   0–500 ms, slides
// in from the team's side, scale .78→1,
//                                                            fire streak, red
// crystal fragments, short banner-only shake
//   impact            200–650 ms flash, ring, 10 streaks     150–700 ms
// stronger flash + orange-red mascot aura,
//                                                            ring, 16 streaks,
// 14 speed lines, bigger spark burst
//   active            sweep every 3 s, gentle pulse,         sweep every 2.1 s,
// stronger pulse, 7 fast outward flame
//                     4 soft trails, 26 particles            trails, 48
// particles (rising embers), edge sparks
//   exit              fade + scale .94 (420 ms)              energy sweep
// toward the team's side + fade (380 ms)
//
//   TRIPLE (electric purple): scale .75→1 + 0.2 slide, purple-white flash, 7
// lightning arcs, 3 expanding rings,
//   border discharge, crystalline under-flash, screen-edge pulse (in
// PkPowerLayer); active: arcs running along both
//   sides, irregular edge arcs, 2 counter-rotating rings, 120
// sparks/branches/crystals, sweep every 1.6 s;
//   exit: rings contract, violet discharge (450 ms).
//
//   TRIPLE TURBO (ultimate, rainbow): 800 ms entrance from .7, white-gold
// flash, 4 multicolour shockwave rings,
//   10 rainbow bolts, 18 crystal shards, 12 rainbow flame tongues per side,
// rainbow border that travels continuously,
//   10 ribbons in opposite directions, 3 rotating rainbow rings, 170 particles,
// sweep every 1.25 s,
//   rainbow edge wave; exit: ribbons contract, final multicolour shockwave (560
// ms).
//
// The widget owns only presentation. Countdown = activation.endsAt − now, so
// rebuilds never restart it.
// Repaints are driven by one Ticker → ValueNotifier, isolated inside
// RepaintBoundary; the PK screen is not rebuilt.
// Respects MediaQuery.disableAnimations (reduced motion) and TickerMode (pauses
// when the route is hidden).

import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/scheduler.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_power_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_power_painters.dart';
import 'package:material_ui/material_ui.dart';

class PkPowerBanner extends StatefulWidget {
  const new({
    required this.activation,
    super.key,
    this.width = 300,
    this.exiting = false,
    this.onExited,
  });

  final PkPowerActivation activation;
  final double width;

  /// Set by the parent when the power ended (expired or removed by the server)
  /// to play the exit animation.
  final bool exiting;
  final VoidCallback? onExited;

  /// Kabso (D199): goldens and captures freeze every banner at this time
  /// (ms since its activation); null plays it. Countdowns then stop ticking.
  static double? debugTimeMs;

  /// Kabso (D199): goldens pin the countdown (a slow run under load must
  /// not turn «00:14» into «00:13»); null reads the clock.
  static Duration? debugRemaining;

  @override
  State<PkPowerBanner> createState() => _PkPowerBannerState();
}

class _PkPowerBannerState extends State<PkPowerBanner>
    with SingleTickerProviderStateMixin {
  final _clock = PkPowerClock();
  late final Ticker _ticker = createTicker(_onTick);
  late PkPowerTheme _theme = PkPowerTheme.of(widget.activation.tier);
  late PkPowerParticles _particles = PkPowerParticles(
    _clock,
    _theme,
    seed: widget.activation.id.hashCode,
  );
  late PkPowerFrontPainter _front = PkPowerFrontPainter(
    _clock,
    _theme,
    seed: widget.activation.id.hashCode,
  );
  late PkPowerBackPainter _back = PkPowerBackPainter(_clock, _theme);
  bool _exitNotified = false;

  @override
  void initState() {
    super.initState();
    _clock.side = widget.activation.side;
    // Kabso: goldens and captures hold one moment of the animation.
    if (PkPowerBanner.debugTimeMs case final t?) {
      _clock.value = t;
      if (widget.exiting) _beginExit();
      return;
    }
    _ticker.start();
    if (widget.exiting) _beginExit();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clock.reducedMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    unawaited(precacheImage(AssetImage(_theme.asset), context));
  }

  @override
  void didUpdateWidget(covariant PkPowerBanner old) {
    super.didUpdateWidget(old);
    // a different activation id is a new activation → restart; same id = keep
    // everything running
    if (old.activation.id != widget.activation.id) {
      _theme = PkPowerTheme.of(widget.activation.tier);
      _particles = PkPowerParticles(
        _clock,
        _theme,
        seed: widget.activation.id.hashCode,
      );
      _front = PkPowerFrontPainter(
        _clock,
        _theme,
        seed: widget.activation.id.hashCode,
      );
      _back = PkPowerBackPainter(_clock, _theme);
      _clock
        ..side = widget.activation.side
        ..exitStart = -1
        ..value = 0;
      _exitNotified = false;
      _ticker
        ..stop()
        ..start();
    }
    if (widget.exiting && !old.exiting) _beginExit();
  }

  void _beginExit() {
    if (_clock.exitStart < 0) _clock.exitStart = _clock.value;
  }

  void _onTick(Duration elapsed) {
    _clock.value = elapsed.inMicroseconds / 1000.0;
    // auto-exit when the server time says it's over (parent may also set
    // exiting)
    if (_clock.exitStart < 0 && widget.activation.isExpired) _beginExit();
    if (_clock.exitStart >= 0 &&
        _clock.value - _clock.exitStart >= _theme.fx.exitMs &&
        !_exitNotified) {
      _exitNotified = true;
      _ticker.stop();
      widget.onExited?.call();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fx = _theme.fx;
    final geo = _theme.geometry;
    final w = widget.width;
    final h = w * geo.aspect;
    final size = Size(w, h);
    final art = Image.asset(
      _theme.asset,
      width: w,
      height: h,
      fit: BoxFit.fill,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => SizedBox(width: w, height: h),
    );

    return IgnorePointer(
      child: RepaintBoundary(
        child: ValueListenableBuilder<double>(
          valueListenable: _clock,
          // only transform/opacity/sweep rebuild here; painters repaint on
          // their own
          builder: (context, t, child) {
            final reduced = _clock.reducedMotion;
            final fromSide = widget.activation.side == PkPowerSide.left
                ? -1.0
                : 1.0; // enter from the team's side
            double scale;
            double opacity;
            var dx = 0.0;
            var dy = 0.0;
            if (_clock.exitStart >= 0) {
              final u = ((t - _clock.exitStart) / fx.exitMs).clamp(0.0, 1.0);
              scale = 1 - .06 * Curves.easeIn.transform(u);
              opacity = 1 - Curves.easeIn.transform(u);
              if (fx.exitSweep && !reduced) {
                dx = fromSide * w * .08 * Curves.easeIn.transform(u);
              }
            } else if (reduced) {
              scale = 1;
              opacity = (t / 200).clamp(0.0, 1.0);
            } else {
              final u = (t / fx.entranceMs).clamp(0.0, 1.0);
              scale =
                  fx.startScale +
                  (1 - fx.startScale) * const _GentleBack().transform(u);
              opacity = Curves.easeOut.transform(
                (t / (fx.entranceMs * .55)).clamp(0.0, 1.0),
              );
              dx =
                  fromSide *
                  w *
                  fx.slideIn *
                  (1 - Curves.easeOutCubic.transform(u));
              // short impact shake — banner only, decays in ~250 ms
              final sk = ((t - fx.impactStart) / 260).clamp(0.0, 1.0);
              if (fx.shake > 0 && sk > 0 && sk < 1) {
                final amp = fx.shake * h * (1 - sk);
                dx += math.sin(t * .09) * amp;
                dy += math.cos(t * .11) * amp * .6;
              }
            }
            return Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(dx, dy),
                child: Transform.scale(scale: scale, child: child),
              ),
            );
          },
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: CustomPaint(painter: _back)),
                Positioned.fill(
                  child: _clock.reducedMotion
                      ? art
                      : ValueListenableBuilder<double>(
                          valueListenable: _clock,
                          builder: (_, t, child) => ShaderMask(
                            blendMode: BlendMode.srcATop,
                            shaderCallback: (r) => _sweepShader(r, t),
                            child: child,
                          ),
                          child: art,
                        ),
                ),
                Positioned.fill(child: CustomPaint(painter: _front)),
                Positioned.fill(child: CustomPaint(painter: _particles)),
                // dynamic info — never baked into the artwork
                Positioned.fromRect(
                  rect: geo.scale(geo.textLeft, size),
                  child: _PowerLabel(
                    theme: _theme,
                    multiplier: widget.activation.multiplier,
                    scale: w / 300,
                    label: widget.activation.label,
                  ),
                ),
                Positioned.fromRect(
                  rect: geo.scale(geo.textRight, size),
                  child: _Countdown(
                    endsAt: widget.activation.endsAt,
                    theme: _theme,
                    scale: w / 300,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Shader _sweepShader(Rect r, double t) {
    final fx = _theme.fx;
    final start = fx.impactEnd;
    final u = t > start ? ((t - start) % fx.sweepPeriodMs) / fx.sweepMs : 2;
    if (u >= 1 || _clock.exitStart >= 0) {
      return const LinearGradient(
        colors: [Colors.transparent, Colors.transparent],
      ).createShader(r);
    }
    final c = -.2 + 1.4 * u;
    return LinearGradient(
      begin: const Alignment(-1, -.4),
      end: const Alignment(1, .4),
      colors: [
        Colors.transparent,
        _theme.highlight.pkAlpha(fx.sweepAlpha),
        Colors.transparent,
      ],
      stops: [
        (c - .09).clamp(0.0, 1.0),
        c.clamp(0.0, 1.0),
        (c + .09).clamp(0.0, 1.0),
      ],
    ).createShader(r);
  }
}

/// ease-out-back with a small overshoot (no excessive bouncing)
class _GentleBack extends Curve {
  const new();
  @override
  double transformInternal(double t) {
    const c = 1.15;
    final x = t - 1;
    return 1 + (c + 1) * x * x * x + c * x * x;
  }
}

List<Shadow> _outline(Color c, double w) => [
  for (final o in const [
    Offset(1, 0),
    Offset(-1, 0),
    Offset(0, 1),
    Offset(0, -1),
    Offset(.7, .7),
    Offset(-.7, .7),
    Offset(.7, -.7),
    Offset(-.7, -.7),
  ])
    Shadow(color: c, offset: o * w),
];

class _PowerLabel extends StatelessWidget {
  const new({
    required this.theme,
    required this.multiplier,
    required this.scale,
    this.label,
  });
  final PkPowerTheme theme;

  /// Kabso: the localized booster name (else the theme's label).
  final String? label;
  final int multiplier;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Text(
                  'x$multiplier',
                  style: TextStyle(
                    fontSize: 20 * scale,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    height: 1,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 3.2 * scale
                      ..strokeJoin = StrokeJoin.round
                      ..color = const Color(0xFF3A1800),
                  ),
                ),
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (r) => LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [theme.highlight, theme.gold, theme.orange],
                    stops: const [0, .5, 1],
                  ).createShader(r),
                  child: Text(
                    'x$multiplier',
                    style: TextStyle(
                      fontSize: 20 * scale,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      height: 1,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: 4 * scale),
            // long labels ("TRIPLE TURBO") stack on two lines so they stay
            // readable at banner size
            Text(
              (label ?? theme.label).replaceAll(' ', '\n'),
              style: TextStyle(
                fontSize:
                    ((label ?? theme.label).contains(' ') ? 8.5 : 9) * scale,
                fontWeight: FontWeight.w900,
                // Kabso: spacing would break Arabic letters apart.
                letterSpacing: label == null ? 1 : 0,
                height: 1.05,
                color: theme.highlight,
                shadows: _outline(const Color(0xCC3A1800), 1 * scale),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Countdown derived from endsAt — rebuilds can't restart it. Only this small
/// widget ticks once a second.
class _Countdown extends StatefulWidget {
  const new({required this.endsAt, required this.theme, required this.scale});
  final DateTime endsAt;
  final PkPowerTheme theme;
  final double scale;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (PkPowerBanner.debugTimeMs == null) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    // align ticks to the next whole second so the display doesn't drift
    final ms = widget.endsAt.difference(clock.now()).inMilliseconds % 1000;
    _timer = Timer(Duration(milliseconds: ms <= 0 ? 1000 : ms), () {
      if (!mounted) return;
      setState(() {});
      if (widget.endsAt.isAfter(clock.now())) {
        _timer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) return t.cancel();
          setState(() {});
          if (!widget.endsAt.isAfter(clock.now())) t.cancel();
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant _Countdown old) {
    super.didUpdateWidget(old);
    if (old.endsAt != widget.endsAt) {
      _schedule(); // server extended / corrected the expiry
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left =
        PkPowerBanner.debugRemaining ?? widget.endsAt.difference(clock.now());
    final secs = math.max(0, (left.inMilliseconds / 1000).ceil());
    final txt =
        '${(secs ~/ 60).toString().padLeft(2, '0')}:'
        '${(secs % 60).toString().padLeft(2, '0')}';
    final s = widget.scale;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_rounded, size: 12 * s, color: widget.theme.gold),
            SizedBox(width: 3 * s),
            Text(
              txt,
              style: TextStyle(
                fontSize: 15 * s,
                fontWeight: FontWeight.w900,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: widget.theme.highlight,
                shadows: _outline(const Color(0xFF3A1800), 1.2 * s),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
