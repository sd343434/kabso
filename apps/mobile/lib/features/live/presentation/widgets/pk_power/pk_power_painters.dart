// Kabso Live — PK power painters, shared by every tier. All intensity comes
// from PkPowerTheme / PkPowerFx.
//
//   PkPowerBackPainter   behind the artwork: impact flash, mascot aura +
// breathing glow, energy/flame trails
//   PkPowerFrontPainter  above the artwork: entrance streak, ring + streaks,
// speed lines, crystal fragments,
//                        travelling border light, border pulse, exit sweep
//   PkPowerParticles     bounded, allocation-free pool: dots/embers, sparks,
// streaks, burst, edge sparks

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_power_models.dart';
import 'package:material_ui/material_ui.dart';

double _c01(double v) => v.clamp(0.0, 1.0);
double _seg(double t, double a, double b) => _c01((t - a) / (b - a));
double _eo(double t) => 1 - math.pow(1 - t, 3).toDouble();

/// Shared animation clock (ms since activation). Painters repaint from this
/// notifier only —
/// the PK screen itself is never rebuilt by the effect.
class PkPowerClock extends ValueNotifier<double> {
  new() : super(0);
  double exitStart = -1; // ms when expiration started, -1 = active
  bool reducedMotion = false;
  PkPowerSide side = PkPowerSide.left;
}

double _fade(PkPowerClock c, PkPowerFx fx) => c.exitStart < 0
    ? 1
    : 1 - _seg(c.value, c.exitStart, c.exitStart + fx.exitMs * .9);

Shader _radial(Offset c, double r, List<Color> colors, [List<double>? stops]) =>
    RadialGradient(
      colors: colors,
      stops: stops,
    ).createShader(Rect.fromCircle(center: c, radius: r));

/// Full-spectrum colour that travels over time. [h] in degrees.
Color _rb(double h, [double s = .95, double v = 1]) =>
    HSVColor.fromAHSV(1, h % 360, s, v).toColor();

/// Cheap deterministic hash → [0,1). No allocation (used for lightning jitter
/// that flickers per time bucket).
double _h(int a, int b) {
  var x = (a * 374761393 + b * 668265263) & 0x7fffffff;
  x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff;
  return (x & 0xffff) / 65536.0;
}

/// Jagged lightning bolt from p0 to p1 (glow pass + bright core pass, optional
/// side branch).
/// [seed] changes every flicker bucket so the bolt re-shapes ~18×/s.
void _bolt(
  Canvas c,
  Path path,
  Offset p0,
  Offset p1,
  int seed,
  double jag,
  double width,
  Color glow,
  Color core,
  double alpha, {
  bool branch = true,
}) {
  if (alpha <= 0) return;
  final d = p1 - p0;
  final len = d.distance;
  if (len < 1) return;
  final n = Offset(-d.dy / len, d.dx / len);
  const segs = 8;
  path
    ..reset()
    ..moveTo(p0.dx, p0.dy);
  Offset? mid;
  for (var k = 1; k < segs; k++) {
    final u = k / segs;
    final off = (_h(seed, k) - .5) * 2 * jag * math.sin(u * math.pi);
    final q = p0 + d * u + n * off;
    path.lineTo(q.dx, q.dy);
    if (k == 4) mid = q;
  }
  path.lineTo(p1.dx, p1.dy);
  if (branch && mid != null) {
    final bAng = (_h(seed, 99) - .5) * 1.6;
    final bDir =
        Offset(
          d.dx * math.cos(bAng) - d.dy * math.sin(bAng),
          d.dx * math.sin(bAng) + d.dy * math.cos(bAng),
        ) /
        len;
    final b1 = mid + bDir * len * .28 + n * (_h(seed, 98) - .5) * jag;
    final b2 = mid + bDir * len * .45 + n * (_h(seed, 97) - .5) * jag * 1.5;
    path
      ..moveTo(mid.dx, mid.dy)
      ..lineTo(b1.dx, b1.dy)
      ..lineTo(b2.dx, b2.dy);
  }
  final p = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..blendMode = BlendMode.plus
    ..strokeWidth = width * 3.2
    ..color = glow.pkAlpha(.35 * alpha);
  c.drawPath(path, p);
  p
    ..strokeWidth = width
    ..color = core.pkAlpha(alpha);
  c.drawPath(path, p);
}

// ───────────────────────────── back ─────────────────────────────
class PkPowerBackPainter extends CustomPainter {
  new(this.clock, this.theme) : super(repaint: clock);
  final PkPowerClock clock;
  final PkPowerTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final fx = theme.fx;
    final geo = theme.geometry;
    final t = clock.value;
    final fade = _fade(clock, fx);
    if (fade <= 0) return;
    final m = geo.at(geo.mascot, size);
    final r = geo.mascotR * size.width;
    final add = Paint()..blendMode = BlendMode.plus;

    // always-on soft glow behind the whole banner (stronger tier = stronger
    // glow)
    final amb =
        fx.ambientGlow *
        fade *
        _seg(t, 100, 500) *
        (.75 + .25 * math.sin(t / fx.pulsePeriodMs));
    if (amb > 0) {
      canvas
        ..save()
        ..translate(size.width / 2, size.height / 2)
        ..scale(1, .45);
      final gr0 = size.width * .58;
      final c0 = fx.rainbow ? _rb(t * fx.hueSpeed) : theme.amber;
      final c1 = fx.rainbow ? _rb(t * fx.hueSpeed + 140) : theme.orange;
      add.shader = _radial(
        Offset.zero,
        gr0,
        [c0.pkAlpha(.55 * amb), c1.pkAlpha(.25 * amb), c1.pkAlpha(0)],
        const [0, .55, 1],
      );
      canvas
        ..drawCircle(Offset.zero, gr0, add)
        ..restore();
    }

    // flame tongues licking out from behind the bar (TURBO)
    if (fx.flames > 0 && !clock.reducedMotion) {
      final bar = geo.scale(geo.bar, size);
      final ff = fade * _seg(t, 120, 520) * (clock.exitStart >= 0 ? .5 : 1);
      for (var i = 0; i < fx.flames * 2; i++) {
        final top = i < fx.flames;
        final j = i % fx.flames;
        final x =
            bar.left +
            bar.width * ((j + .5) / fx.flames) +
            math.sin(t / 300 + i) * bar.width * .015;
        final flick = .6 + .4 * math.sin(t / (90 + 17 * (i % 5)) + i * 2.1);
        final fh = size.height * (.22 + .18 * ((i * .618) % 1)) * flick;
        final fw = bar.width / fx.flames * .7;
        final y0 = top
            ? bar.top + size.height * .04
            : bar.bottom - size.height * .04;
        final dir = top ? -1.0 : 1.0;
        final tipX = x + math.sin(t / 140 + i) * fw * .35;
        final path = Path()
          ..moveTo(x - fw / 2, y0)
          ..quadraticBezierTo(
            x - fw * .45,
            y0 + dir * fh * .6,
            tipX,
            y0 + dir * fh,
          )
          ..quadraticBezierTo(x + fw * .45, y0 + dir * fh * .6, x + fw / 2, y0)
          ..close();
        add.shader =
            LinearGradient(
              begin: top ? Alignment.bottomCenter : Alignment.topCenter,
              end: top ? Alignment.topCenter : Alignment.bottomCenter,
              colors: fx.rainbow
                  ? [
                      _rb(t * fx.hueSpeed + i * 30, .3).pkAlpha(.6 * ff),
                      _rb(t * fx.hueSpeed + i * 30).pkAlpha(.85 * ff),
                      _rb(t * fx.hueSpeed + i * 30 + 40).pkAlpha(.55 * ff),
                      _rb(t * fx.hueSpeed + i * 30 + 80).pkAlpha(0),
                    ]
                  : [
                      theme.highlight.pkAlpha(.9 * ff),
                      theme.gold.pkAlpha(.8 * ff),
                      theme.ember.pkAlpha(.55 * ff),
                      theme.orange.pkAlpha(0),
                    ],
              stops: const [0, .3, .65, 1],
            ).createShader(
              Rect.fromLTRB(
                x - fw,
                math.min(y0, y0 + dir * fh),
                x + fw,
                math.max(y0, y0 + dir * fh),
              ),
            );
        canvas.drawPath(path, add);
      }
      add.shader = null;
    }

    if (!clock.reducedMotion) {
      // layered impact flash behind the mascot
      final f = _seg(t, fx.impactStart, fx.impactEnd);
      if (f > 0 && f < 1) {
        final a = math.sin(f * math.pi) * fade * fx.flash;
        final rr = r * (2 + 4.5 * _eo(f));
        add.shader = _radial(
          m,
          rr,
          [
            theme.highlight.pkAlpha(.85 * a),
            theme.amber.pkAlpha(.5 * a),
            theme.orange.pkAlpha(0),
          ],
          const [0, .35, 1],
        );
        canvas.drawCircle(m, rr, add);
        if (fx.aura > 0) {
          // short orange-red aura hugging the mascot
          final ar = r * 1.9;
          final auraC = fx.rainbow ? _rb(t * fx.hueSpeed * 2) : theme.ember;
          add.shader = _radial(
            m,
            ar,
            [
              theme.orange.pkAlpha(0),
              auraC.pkAlpha(fx.aura * a),
              theme.orange.pkAlpha(0),
            ],
            const [.55, .8, 1],
          );
          canvas.drawCircle(m, ar, add);
        }
      }
    }

    // breathing mascot glow
    final breath = .45 + .2 * math.sin(t / (fx.embersRise ? 360 : 520));
    final gr = r * 2.6;
    add.shader = _radial(m, gr, [
      (fx.rainbow ? _rb(t * fx.hueSpeed + 60, .6) : theme.gold).pkAlpha(
        .6 * breath * fade,
      ),
      theme.amber.pkAlpha(0),
    ]);
    canvas.drawCircle(m, gr, add);

    // trails flowing OUTWARD from the activation centre to both ends
    if (!clock.reducedMotion && fx.trails > 0) {
      final trail = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..blendMode = BlendMode.plus;
      final tf = fade * _seg(t, 250, 800) * (clock.exitStart >= 0 ? .6 : 1);
      for (var i = 0; i < fx.trails; i++) {
        final band = fx.trails == 1 ? .5 : i / (fx.trails - 1);
        final y =
            size.height *
                (geo.bar.top -
                    .12 +
                    (geo.bar.bottom - geo.bar.top + .24) * band) +
            math.sin(t / 600 + i) * size.height * .015;
        final period = fx.trailPeriodMs * (1 + .25 * (i % 3));
        final u = ((t + i * 397) % period) / period;
        final dir = i.isEven
            ? 1.0
            : -1.0; // alternate: right half flows right, left half flows left
        // on expiry the ribbons contract toward the centre
        final contract = clock.exitStart >= 0
            ? 1 - _seg(t, clock.exitStart, clock.exitStart + fx.exitMs)
            : 1.0;
        final cx = m.dx + dir * u * size.width * .55 * contract;
        final len = size.width * (.22 + .08 * (i % 2));
        final a = fx.trailAlpha * tf * math.sin(u * math.pi);
        trail
          ..strokeWidth = size.height * fx.trailWidth * (1 + .3 * (i % 2))
          ..shader = LinearGradient(
            colors: [
              theme.orange.pkAlpha(0),
              (fx.rainbow ? _rb(t * fx.hueSpeed + i * 45) : theme.gold).pkAlpha(
                a,
              ),
              (fx.rainbow ? _rb(t * fx.hueSpeed + i * 45 + 60) : theme.ember)
                  .pkAlpha(a * .8),
              theme.orange.pkAlpha(0),
            ],
            stops: const [0, .5, .75, 1],
          ).createShader(Rect.fromLTWH(dir > 0 ? cx - len : cx, y - 2, len, 4));
        canvas.drawLine(Offset(cx - dir * len, y), Offset(cx, y), trail);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PkPowerBackPainter old) =>
      old.theme != theme || old.clock != clock;
}

// ───────────────────────────── front ─────────────────────────────
class PkPowerFrontPainter extends CustomPainter {
  new(this.clock, this.theme, {int seed = 1})
    : _rnd = math.Random(seed),
      super(repaint: clock) {
    // pre-computed crystal fragment directions (no per-frame allocation)
    final n = theme.fx.crystals;
    _crA = Float32List(n);
    _crD = Float32List(n);
    _crS = Float32List(n);
    for (var i = 0; i < n; i++) {
      _crA[i] = (i / n) * math.pi * 2 + _rnd.nextDouble() * .4;
      _crD[i] = .6 + _rnd.nextDouble() * .6;
      _crS[i] = .7 + _rnd.nextDouble() * .6;
    }
  }

  final PkPowerClock clock;
  final PkPowerTheme theme;
  final math.Random _rnd;
  late final Float32List _crA;
  late final Float32List _crD;
  late final Float32List _crS;
  Size? _metricSize;
  late ui.PathMetric _metric;
  late RRect _rrect;
  final Path _boltPath = Path();

  @override
  void paint(Canvas canvas, Size size) {
    if (clock.reducedMotion) return;
    final fx = theme.fx;
    final geo = theme.geometry;
    final t = clock.value;
    final fade = _fade(clock, fx);
    final m = geo.at(geo.mascot, size);
    final r = geo.mascotR * size.width;
    final add = Paint()..blendMode = BlendMode.plus;

    // exit: one horizontal energy sweep across the whole banner
    if (clock.exitStart >= 0 && fx.exitSweep) {
      final u = _seg(t, clock.exitStart, clock.exitStart + fx.exitMs);
      if (u < 1) {
        final x = size.width * (clock.side == PkPowerSide.left ? 1 - u : u);
        add.shader =
            LinearGradient(
              colors: [
                theme.orange.pkAlpha(0),
                theme.highlight.pkAlpha(.9 * (1 - u)),
                theme.orange.pkAlpha(0),
              ],
            ).createShader(
              Rect.fromLTWH(
                x - size.width * .12,
                0,
                size.width * .24,
                size.height,
              ),
            );
        canvas.drawRect(
          Rect.fromLTWH(
            x - size.width * .12,
            size.height * .3,
            size.width * .24,
            size.height * .4,
          ),
          add,
        );
        add.shader = null;
      }
    }
    // ultimate: final multicolour shockwave on expiry
    if (clock.exitStart >= 0 && fx.finalShockwave) {
      final u = _seg(t, clock.exitStart, clock.exitStart + fx.exitMs * 1.1);
      if (u > 0 && u < 1) {
        for (var k = 0; k < 3; k++) {
          final rr = r * (1.5 + (7 + k * 1.6) * _eo(u));
          canvas.drawOval(
            Rect.fromCenter(center: m, width: rr * 2, height: rr * 1.1),
            Paint()
              ..style = PaintingStyle.stroke
              ..blendMode = BlendMode.plus
              ..strokeWidth = size.height * .05 * (1 - u) + .5
              ..color = _rb(k * 120 + u * 200).pkAlpha(.9 * (1 - u)),
          );
        }
      }
    }
    if (fade <= 0) return;

    // entrance: energy / fire streak from the centre to both ends
    final s = _seg(t, 40, fx.entranceMs);
    if (s > 0 && s < 1) {
      final reach = size.width * .5 * _eo(s);
      final a = math.sin(s * math.pi);
      add.shader = LinearGradient(
        colors: [
          theme.orange.pkAlpha(0),
          (fx.rainbow ? _rb(t * .5) : theme.ember).pkAlpha(.6 * a),
          (fx.rainbow ? _rb(t * .5 + 90, .3) : theme.highlight).pkAlpha(
            (fx.rainbow ? .5 : .95) * a,
          ),
          (fx.rainbow ? _rb(t * .5 + 180) : theme.ember).pkAlpha(.6 * a),
          theme.orange.pkAlpha(0),
        ],
        stops: const [0, .3, .5, .7, 1],
      ).createShader(Rect.fromLTRB(m.dx - reach, 0, m.dx + reach, size.height));
      final h =
          size.height * .05 * (1 - .5 * s) * (fx.speedLines > 0 ? 1.4 : 1);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(m.dx - reach, m.dy - h / 2, m.dx + reach, m.dy + h / 2),
          Radius.circular(h),
        ),
        add,
      );
      add.shader = null;
    }

    // crystal fragments scatter briefly on entrance
    if (fx.crystals > 0) {
      final cu = _seg(t, 60, 760);
      if (cu > 0 && cu < 1) {
        final p = Paint()
          ..color = theme.crystal.pkAlpha(_c01((1 - cu) * 1.3) * fade);
        final rainbowShards = fx.rainbow;
        final hi = Paint()
          ..color = theme.highlight.pkAlpha(_c01((1 - cu) * .9) * fade);
        for (var i = 0; i < fx.crystals; i++) {
          final d = r * (1.4 + 5 * _eo(cu) * _crD[i]);
          final c =
              m +
              Offset(
                math.cos(_crA[i]) * d,
                math.sin(_crA[i]) * d * .5 + size.height * .25 * cu * cu,
              );
          final k = size.height * .13 * _crS[i] * (1 - .4 * cu);
          canvas
            ..save()
            ..translate(c.dx, c.dy)
            ..rotate(_crA[i] + t / 140);
          final shard = Path()
            ..moveTo(0, -k)
            ..lineTo(k * .38, 0)
            ..lineTo(0, k)
            ..lineTo(-k * .38, 0)
            ..close();
          if (rainbowShards) {
            p.color = _rb(i * 360.0 / fx.crystals + t * .2)
                .pkAlpha(_c01((1 - cu) * 1.3) * fade);
          }
          canvas
            ..drawPath(shard, p)
            ..drawPath(
              Path()
                ..moveTo(0, -k)
                ..lineTo(k * .38, 0)
                ..lineTo(0, -k * .1)
                ..close(),
              hi,
            )
            ..restore();
        }
      }
    }

    // impact: expanding ring + streaks + fast speed lines
    final ring = _seg(t, fx.impactStart, fx.impactEnd);
    if (ring > 0 && ring < 1) {
      final rr = r * (1.1 + 4 * _eo(ring));
      final stroke = Paint()
        ..blendMode = BlendMode.plus
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = size.height * fx.ringWidth * (1 - ring) + .5
        ..color = theme.amber.pkAlpha(.95 * (1 - ring) * fade * fx.impactAlpha);
      canvas.drawCircle(m, rr, stroke);
      stroke
        ..strokeWidth = size.height * .025
        ..color = theme.highlight.pkAlpha(
          .8 * (1 - ring) * fade * fx.impactAlpha,
        );
      for (var i = 0; i < fx.streaks; i++) {
        final ang = i * math.pi * 2 / fx.streaks + .2;
        final d0 = r * (1.2 + 3.6 * _eo(ring));
        final d1 = d0 + r * 1.6 * (1 - ring);
        final dir = Offset(math.cos(ang), math.sin(ang) * .55);
        canvas.drawLine(m + dir * d0, m + dir * d1, stroke);
      }
      for (var i = 0; i < fx.speedLines; i++) {
        final side = i.isEven ? 1.0 : -1.0;
        final y = size.height * (.22 + .56 * ((i * .37) % 1));
        final u = _seg(t, fx.impactStart + (i % 5) * 25, fx.impactEnd);
        if (u <= 0 || u >= 1) continue;
        final x0 = m.dx + side * size.width * (.08 + .5 * _eo(u));
        final len = size.width * (.14 + .08 * (i % 3)) * (1 - u);
        stroke
          ..strokeWidth = size.height * (.02 + .012 * (i % 2))
          ..color = (i % 3 == 0 ? theme.highlight : theme.gold).pkAlpha(
            .85 * (1 - u) * fade * fx.impactAlpha,
          );
        canvas.drawLine(Offset(x0, y), Offset(x0 - side * len, y), stroke);
      }
    }

    if (fx.lightning > 0 ||
        fx.rings > 0 ||
        fx.impactRings > 1 ||
        fx.idleArcEveryMs > 0) {
      _electric(canvas, size, t, fade, m, r);
    }

    // border: one travelling highlight after the impact, then a pulse while
    // active
    final bar = theme.geometry.scale(theme.geometry.bar, size);
    if (_metricSize != size) {
      _metricSize = size;
      _rrect = RRect.fromRectAndRadius(bar, Radius.circular(bar.height * .25));
      _metric = (Path()..addRRect(_rrect))
          .computeMetrics()
          .first; // cached: no per-frame path work
    }
    final br = _seg(t, fx.impactStart + 100, fx.impactEnd + 250);
    if (br > 0 && br < 1) {
      final len = _metric.length;
      for (final off in const [0.0, .5]) {
        final pos = _metric
            .getTangentForOffset(((_eo(br) + off) % 1) * len)!
            .position;
        final rad = size.height * .16;
        add.shader = _radial(pos, rad, [
          theme.highlight.pkAlpha(.95 * fade),
          theme.gold.pkAlpha(0),
        ]);
        canvas.drawCircle(pos, rad, add);
      }
      add.shader = null;
    }
    // rainbow border: the full spectrum travels around the bar continuously,
    // with a white core
    if (fx.rainbow) {
      final ba = _seg(t, fx.impactStart + 200, fx.impactEnd) * fade;
      if (ba > 0) {
        final rot = t * fx.hueSpeed * math.pi / 180;
        final shader = SweepGradient(
          colors: [for (var k = 0; k <= 8; k++) _rb(k * 45.0)],
          transform: GradientRotation(rot),
        ).createShader(_rrect.outerRect);
        canvas
          ..drawRRect(
            _rrect,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size.height * .05
              ..blendMode = BlendMode.plus
              ..shader = shader
              ..color = Colors.white.pkAlpha(.55 * ba),
          )
          ..drawRRect(
            _rrect,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size.height * .012
              ..blendMode = BlendMode.plus
              ..color = Colors.white.pkAlpha(
                .5 * ba * (.6 + .4 * math.sin(t / 140)),
              ),
          );
      }
    }

    final pulse =
        (.5 + .5 * math.sin(t / fx.pulsePeriodMs * 2)) *
        _seg(t, fx.impactEnd + 200, fx.impactEnd + 600) *
        fade;
    if (pulse > 0) {
      canvas.drawRRect(
        _rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.height * .04
          ..blendMode = BlendMode.plus
          ..color = theme.gold.pkAlpha(fx.borderPulse * pulse),
      );
    }
  }

  /// TRIPLE: lightning arcs, expanding + rotating energy rings, border
  /// discharge, exit discharge.
  void _electric(
    Canvas canvas,
    Size size,
    double t,
    double fade,
    Offset m,
    double r,
  ) {
    final fx = theme.fx;
    final geo = theme.geometry;
    final h = size.height;
    final w = size.width;
    final bucket = (t / 55).floor(); // flicker rate
    final exiting = clock.exitStart >= 0;
    final eu = exiting
        ? _seg(t, clock.exitStart, clock.exitStart + fx.exitMs)
        : 0.0;
    final add = Paint()..blendMode = BlendMode.plus;

    // expanding violet rings (staggered)
    for (var k = 0; k < fx.impactRings; k++) {
      final u = _seg(t, fx.impactStart + k * 110, fx.impactEnd + k * 110);
      if (u <= 0 || u >= 1) continue;
      add
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * fx.ringWidth * (1 - u) + .6
        ..color =
            (fx.rainbow
                    ? _rb(k * 90 + t * fx.hueSpeed)
                    : (k.isEven ? theme.amber : theme.orange))
                .pkAlpha(.95 * (1 - u) * fade * (fx.rainbow ? .7 : 1));
      canvas.drawOval(
        Rect.fromCenter(
          center: m,
          width: r * (2.4 + 9 * _eo(u)),
          height: r * (2.4 + 9 * _eo(u)) * .62,
        ),
        add,
      );
    }

    // impact lightning from the mascot
    final iu = _seg(t, fx.impactStart, fx.impactEnd);
    if (iu > 0 && iu < 1) {
      for (var i = 0; i < fx.lightning; i++) {
        final ang = (i / fx.lightning) * math.pi * 2 + _h(i, 7) * .6;
        final reach = r * (2.2 + 3.2 * _h(i, 8)) * (.35 + .65 * _eo(iu));
        final end =
            m +
            Offset(math.cos(ang) * reach * 1.6, math.sin(ang) * reach * .55);
        final flick = _h(bucket, i + 50) > .25 ? 1.0 : .35;
        // rainbow: coloured cores (not white) so the mascot face stays visible
        // through the burst
        _bolt(
          canvas,
          _boltPath,
          m,
          end,
          bucket * 31 + i,
          r * .45,
          h * .018,
          fx.rainbow ? _rb(i * 36 + t * fx.hueSpeed) : theme.amber,
          fx.rainbow ? _rb(i * 36 + t * fx.hueSpeed, .35) : theme.highlight,
          (1 - iu) * flick * fade * fx.impactAlpha,
        );
      }
      // strong crystalline flash beneath the mascot
      final cf = math.sin(iu * math.pi) * fade;
      add
        ..style = PaintingStyle.fill
        ..shader = _radial(
          m + Offset(0, r * .6),
          r * 2.2,
          [
            theme.highlight.pkAlpha(.9 * cf),
            theme.gold.pkAlpha(.5 * cf),
            theme.amber.pkAlpha(0),
          ],
          const [0, .35, 1],
        );
      canvas.drawOval(
        Rect.fromCenter(
          center: m + Offset(0, r * .6),
          width: r * 4.4,
          height: r * 1.6,
        ),
        add,
      );
      add.shader = null;
    }

    final bar = geo.scale(geo.bar, size);
    // electrical discharge running along the border during the impact (centre →
    // both ends)
    final du = _seg(t, fx.impactStart + 80, fx.impactEnd + 250);
    if (du > 0 && du < 1) {
      for (final top in const [true, false]) {
        final y = top ? bar.top : bar.bottom;
        for (final dir in const [-1.0, 1.0]) {
          final x0 = m.dx + dir * bar.width * .5 * _eo(du) * .2;
          final x1 = m.dx + dir * bar.width * .5 * _eo(du);
          _bolt(
            canvas,
            _boltPath,
            Offset(x0, y),
            Offset(x1, y),
            bucket * 13 + (top ? 1 : 2) + (dir > 0 ? 5 : 0),
            h * .05,
            h * .014,
            theme.gold,
            theme.highlight,
            (1 - du) * fade * fx.impactAlpha,
            branch: false,
          );
        }
      }
    }

    // while active (and fading during exit): arcs travelling along both sides
    // of the banner
    final act =
        _seg(t, fx.impactEnd - 100, fx.impactEnd + 300) * fade * (1 - eu * .7);
    if (fx.idleArcEveryMs > 0 && act > 0) {
      for (var s = 0; s < 2; s++) {
        final period = 1400.0 + 300 * s;
        final u = ((t + s * 500) % period) / period;
        final top = s == 0;
        final y = top ? bar.top : bar.bottom;
        final x = top ? bar.left + bar.width * u : bar.right - bar.width * u;
        final seglen = bar.width * .2;
        _bolt(
          canvas,
          _boltPath,
          Offset(x - seglen / 2, y),
          Offset(x + seglen / 2, y),
          bucket * 17 + s,
          h * .06,
          h * .012,
          s == 0 ? theme.gold : theme.orange,
          theme.highlight,
          act * math.sin(u * math.pi),
          branch: false,
        );
      }
      // irregular random arcs from the banner edge outward
      final ab = (t / fx.idleArcEveryMs).floor();
      final within = t - ab * fx.idleArcEveryMs;
      if (!exiting && _h(ab, 3) > .3 && within < 160) {
        final left = _h(ab, 4) < .5;
        final y = bar.top + bar.height * _h(ab, 5);
        final p0 = Offset(left ? bar.left : bar.right, y);
        final p1 =
            p0 +
            Offset(
              (left ? -1 : 1) * w * (.05 + .07 * _h(ab, 6)),
              (_h(ab, 9) - .5) * h * .9,
            );
        _bolt(
          canvas,
          _boltPath,
          p0,
          p1,
          bucket * 7 + ab,
          h * .1,
          h * .016,
          fx.rainbow ? _rb(ab * 67.0) : theme.amber,
          theme.highlight,
          act * (1 - within / 160),
        );
      }
    }

    // rotating energy rings around the mascot (contract + fade on exit)
    if (fx.rings > 0) {
      final ra = _seg(t, fx.impactStart + 150, fx.impactEnd) * fade;
      if (ra > 0) {
        for (var k = 0; k < fx.rings; k++) {
          final rad = r * (1.55 + .32 * k) * (1 - .45 * eu);
          final rect = Rect.fromCenter(
            center: m,
            width: rad * 2,
            height: rad * 2 * .42,
          );
          final rot = (k.isEven ? 1 : -1) * t / (600 + 200 * k);
          add
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = h * (.022 - .006 * k);
          for (var a = 0; a < 3; a++) {
            final start = rot + a * math.pi * 2 / 3;
            add.color =
                (fx.rainbow
                        ? _rb(a * 120 + k * 40 + t * fx.hueSpeed * 1.5)
                        : (k.isEven ? theme.gold : theme.orange))
                    .pkAlpha(.85 * ra);
            canvas.drawArc(rect, start, 1.15, false, add);
            add.color = theme.highlight.pkAlpha(.9 * ra);
            canvas.drawArc(rect, start + 1.0, .15, false, add);
          }
        }
      }
    }

    // exit: violet electrical discharge
    if (exiting && eu < 1) {
      for (var i = 0; i < 6; i++) {
        final ang = i / 6 * math.pi * 2 + .4;
        final reach = r * (1.5 + 5 * eu);
        final end =
            m + Offset(math.cos(ang) * reach * 1.7, math.sin(ang) * reach * .5);
        _bolt(
          canvas,
          _boltPath,
          m,
          end,
          bucket * 11 + i,
          r * .5,
          h * .016,
          fx.rainbow ? _rb(i * 60.0) : theme.amber,
          theme.highlight,
          1 - eu,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant PkPowerFrontPainter old) =>
      old.theme != theme || old.clock != clock;
}

// ───────────────────────────── particles ─────────────────────────────
/// Bounded, allocation-free particle pool. Particles live above / below the
/// text panels and are skipped
/// inside the text areas. Deterministic for a given seed.
class PkPowerParticles extends CustomPainter {
  new(this.clock, this.theme, {int seed = 7})
    : _n = theme.fx.particles,
      _rnd = math.Random(seed),
      super(repaint: clock) {
    _x = Float32List(_n);
    _y = Float32List(_n);
    _vx = Float32List(_n);
    _vy = Float32List(_n);
    _born = Float32List(_n)..fillRange(0, _n, -1);
    _life = Float32List(_n);
    _size = Float32List(_n);
    _kind = Uint8List(_n);
  }

  final PkPowerClock clock;
  final PkPowerTheme theme;
  final int _n;
  final math.Random _rnd;
  late final Float32List _x;
  late final Float32List _y;
  late final Float32List _vx;
  late final Float32List _vy;
  late final Float32List _born;
  late final Float32List _life;
  late final Float32List _size;
  // 0 ember/dot, 1 spark, 2 streak, 3 golden fragment, 4 lightning branch, 5
  // crystal
  late final Uint8List _kind;
  double _lastSpawn = -1000000000;
  double _lastEdge = -1000000000;
  bool _burstDone = false;
  final Paint _p = Paint()..blendMode = BlendMode.plus;
  final Path _path = Path();

  int _free() {
    for (var i = 0; i < _n; i++) {
      if (_born[i] < 0) return i;
    }
    return -1;
  }

  void _spawnBurst(int i, double t) {
    final geo = theme.geometry;
    final a = _rnd.nextDouble() * math.pi * 2;
    final sp = .00018 + _rnd.nextDouble() * .00026;
    _x[i] = geo.mascot.dx;
    _y[i] = geo.mascot.dy;
    _vx[i] = math.cos(a) * sp;
    _vy[i] = math.sin(a) * sp * 2.4;
    _life[i] = 600 + _rnd.nextDouble() * 450;
    _kind[i] = theme.fx.electric
        ? (_rnd.nextDouble() < .5 ? 4 : 5)
        : (_rnd.nextDouble() < .5 ? 1 : 3);
    _born[i] = t;
    _size[i] = .6 + _rnd.nextDouble();
  }

  void _spawnIdle(int i, double t) {
    final fx = theme.fx;
    final top = _rnd.nextBool();
    final geo = theme.geometry;
    _x[i] = .03 + _rnd.nextDouble() * .94;
    _y[i] = top
        ? geo.bar.top - fx.spread * _rnd.nextDouble()
        : geo.bar.bottom + fx.spread * _rnd.nextDouble();
    if (fx.embersRise) {
      _vx[i] = (_rnd.nextDouble() - .5) * .00008;
      _vy[i] = -(.00010 + _rnd.nextDouble() * .00016); // embers rise and fade
    } else {
      _vx[i] = (_rnd.nextDouble() - .5) * .00006;
      _vy[i] = (top ? -1 : 1) * (.00002 + _rnd.nextDouble() * .00005);
    }
    _life[i] = (fx.embersRise ? 900 : 1400) + _rnd.nextDouble() * 1400;
    final k = _rnd.nextDouble();
    if (fx.electric) {
      // drift slowly in any direction; sparks / lightning branches / rotating
      // crystals
      final a = _rnd.nextDouble() * math.pi * 2;
      final sp =
          (fx.rainbow && k > .4 && k < .58 ? .00025 : .00003) +
          _rnd.nextDouble() * .00007;
      _vx[i] = math.cos(a) * sp;
      _vy[i] =
          math.sin(a) *
          sp *
          (fx.rainbow && k > .4 && k < .58
              ? .4
              : 2); // fast, mostly horizontal energy streaks
      _kind[i] = fx.rainbow
          // orbs, sparks, energy streaks, bolts, crystals
          ? (k < .22 ? 0 : (k < .4 ? 1 : (k < .58 ? 2 : (k < .76 ? 4 : 5))))
          : (k < .3 ? 0 : (k < .5 ? 1 : (k < .7 ? 4 : 5)));
    } else {
      _kind[i] = k < .62 ? 0 : (k < .82 ? 1 : (fx.embersRise ? 2 : 1));
    }
    _born[i] = t;
    _size[i] = .5 + _rnd.nextDouble();
  }

  void _spawnEdgeSpark(int i, double t) {
    final geo = theme.geometry;
    final right = _rnd.nextBool();
    _x[i] = right ? geo.bar.right : geo.bar.left;
    _y[i] = geo.bar.top + _rnd.nextDouble() * (geo.bar.bottom - geo.bar.top);
    final sp = .00035 + _rnd.nextDouble() * .0003;
    _vx[i] = (right ? 1 : -1) * sp;
    _vy[i] = (_rnd.nextDouble() - .6) * sp * 1.6;
    _life[i] = 350 + _rnd.nextDouble() * 250;
    _kind[i] = 2;
    _born[i] = t;
    _size[i] = .8 + _rnd.nextDouble() * .6;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (clock.reducedMotion) return;
    final fx = theme.fx;
    final geo = theme.geometry;
    final t = clock.value;
    final exiting = clock.exitStart >= 0;
    final fade = _fade(clock, fx);
    if (fade <= 0) return;

    if (!_burstDone && t >= fx.impactStart + 20) {
      _burstDone = true;
      for (var k = 0; k < (_n * fx.burstShare).round(); k++) {
        final i = _free();
        if (i < 0) break;
        _spawnBurst(i, t);
      }
    }
    if (!exiting && t > fx.impactEnd && t - _lastSpawn > fx.spawnEveryMs) {
      final i = _free();
      if (i >= 0) {
        _spawnIdle(i, t);
        _lastSpawn = t;
      }
    }
    if (!exiting &&
        fx.edgeSparkEveryMs > 0 &&
        t > fx.impactEnd &&
        t - _lastEdge >
            fx.edgeSparkEveryMs *
                (fx.electric ? .4 + 1.2 * _rnd.nextDouble() : 1)) {
      _lastEdge = t; // electric tiers fire at irregular intervals
      for (var k = 0; k < 3; k++) {
        final i = _free();
        if (i < 0) break;
        _spawnEdgeSpark(i, t);
      }
    }

    final w = size.width;
    final h = size.height;
    final unit = h * fx.particleSize;
    final tl = geo.scale(geo.textLeft, size);
    final tr = geo.scale(geo.textRight, size);
    for (var i = 0; i < _n; i++) {
      if (_born[i] < 0) continue;
      final age = t - _born[i];
      if (age >= _life[i] || age < 0) {
        _born[i] = -1;
        continue;
      }
      final u = age / _life[i];
      final x = (_x[i] + _vx[i] * age) * w;
      final y = (_y[i] + _vy[i] * age) * h;
      final pos = Offset(x, y);
      if (tl.contains(pos) || tr.contains(pos)) continue; // never over text
      final a = _c01(
        math.sin(u * math.pi) * fade * (.6 + .4 * math.sin(t / 110 + i)),
      );
      final s = unit * _size[i];
      final rbc = fx.rainbow
          ? _rb(i * 23.0 + t * fx.hueSpeed * 1.4)
          : null; // per-particle moving hue
      switch (_kind[i]) {
        case 0: // ember / glowing dot
          _p
            ..style = PaintingStyle.fill
            ..color =
                (rbc ??
                        (fx.electric
                            ? theme.highlight
                            : (fx.embersRise ? theme.ember : theme.gold)))
                    .pkAlpha(a);
          canvas.drawCircle(pos, s * .6, _p);
          _p.color = (rbc ?? (fx.electric ? theme.orange : theme.amber))
              .pkAlpha(a * .45);
          canvas.drawCircle(pos, s * 1.7, _p);
        case 1: // 4-point spark
          _p
            ..style = PaintingStyle.fill
            ..color =
                (rbc != null && i.isOdd
                        ? rbc
                        : (fx.embersRise && i.isOdd
                              ? theme.ember
                              : theme.highlight))
                    .pkAlpha(a);
          _path
            ..reset()
            ..moveTo(x, y - s * 2.2)
            ..lineTo(x + s * .35, y)
            ..lineTo(x, y + s * 2.2)
            ..lineTo(x - s * .35, y)
            ..close()
            ..moveTo(x - s * 2.2, y)
            ..lineTo(x, y + s * .35)
            ..lineTo(x + s * 2.2, y)
            ..lineTo(x, y - s * .35)
            ..close();
          canvas.drawPath(_path, _p);
        case 2: // short directional flame streak
          final vx = _vx[i] * w;
          final vy = _vy[i] * h;
          final l = math.sqrt(vx * vx + vy * vy);
          if (l == 0) break;
          final dir = Offset(vx / l, vy / l);
          _p
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = s * .6
            ..color = (rbc ?? theme.gold).pkAlpha(a);
          canvas.drawLine(pos, pos - dir * s * 5, _p);
          _p
            ..strokeWidth = s * .3
            ..color = theme.highlight.pkAlpha(a);
          canvas.drawLine(pos, pos - dir * s * 2, _p);
        case 3: // golden fragment
          _p
            ..style = PaintingStyle.fill
            ..color = theme.gold.pkAlpha(a);
          canvas
            ..save()
            ..translate(x, y)
            ..rotate(t / 120 + i)
            ..drawRect(
              Rect.fromCenter(
                center: Offset.zero,
                width: s * 1.6,
                height: s * .8,
              ),
              _p,
            )
            ..restore();
        case 4: // tiny lightning branch (re-shapes every flicker bucket)
          final b = (t / 55).floor();
          _p
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = s * .35
            ..color = (rbc ?? (i.isEven ? theme.highlight : theme.orange))
                .pkAlpha(a);
          _path
            ..reset()
            ..moveTo(x, y);
          var px = x;
          var py = y;
          for (var k = 0; k < 3; k++) {
            px += (_h(b + i, k) - .5) * s * 4;
            py += s * 1.6 * (k.isEven ? 1 : -.4);
            _path.lineTo(px, py);
          }
          canvas.drawPath(_path, _p);
        default: // rotating violet / magenta crystal
          canvas
            ..save()
            ..translate(x, y)
            ..rotate(t / 260 + i);
          final k2 = s * 1.8;
          _path
            ..reset()
            ..moveTo(0, -k2)
            ..lineTo(k2 * .42, 0)
            ..lineTo(0, k2)
            ..lineTo(-k2 * .42, 0)
            ..close();
          _p
            ..style = PaintingStyle.fill
            ..color = (rbc ?? (i.isEven ? theme.crystal : theme.ember)).pkAlpha(
              a,
            );
          canvas.drawPath(_path, _p);
          _p.color = theme.highlight.pkAlpha(a * .8);
          _path
            ..reset()
            ..moveTo(0, -k2)
            ..lineTo(k2 * .42, 0)
            ..lineTo(0, -k2 * .15)
            ..close();
          canvas
            ..drawPath(_path, _p)
            ..restore();
      }
    }
  }

  @override
  // repaints via clock
  bool shouldRepaint(covariant PkPowerParticles old) => false;
}
