// Kabso Live — PK battle bar (live, per power tier), styled after the supplied
// 4-tier design sheet.
//
// What moves:
//   • ONE track between the two avatars. The split point = leftScore /
// (leftScore + rightScore) and follows score
//     changes with a spring, so the leading team's fill pushes into the other
// team's side.
//   • The PK emblem rides the split (bounces / tilts while it moves) — it
// always sits where the two teams clash.
//   • Each team's chevrons flow TOWARD the opponent (left → right for the left
// team, right → left for the right team).
//   • A clash glow + sparks live at the split and flare up while the split is
// moving.
//   • Per team, its own active power tier drives: fill colours, glow, light
// sweep, flames (TURBO tiers),
//     lightning on the rim (TRIPLE tiers), rainbow fill (TRIPLE TURBO),
// particles flowing to the clash point,
//     frame pulse and an activation flash. A team with no power keeps its
// default team colour (left red / right blue).
//
// Artwork taken from the design sheet (assets/pk/score_bar/parts/):
// frameL_t1..t4 (tier frames), frame_neutral_L/R
// (default frames), emblem_t1..t4 (PK emblem; the highest active tier is
// shown). Everything else is painted live.
//
//   PkBattleBar(
//     leftScore: s.left, rightScore: s.right,          // your existing values
// — never modified here
//     leftTier: s.leftTeam.activePower?.tier,          // null = no power
//     rightTier: s.rightTeam.activePower?.tier,
//     leftAvatar: NetworkImage(...), rightAvatar: NetworkImage(...),
//   )

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_power_models.dart';
import 'package:material_ui/material_ui.dart';

// geometry in sheet units (1536 × 250), scaled to the widget width
const _sheetW = 1536.0;
const _sheetH = 250.0;
const _trackL = 180.0;
const _trackR = 1356.0;
const _trackY = 104.0;
const _trackH = 40.0;
const _avatarL = Offset(117, 124);
const _avatarR = Offset(1416, 124);
const _avatarRad = 38.5;
const _dir = 'assets/pk/score_bar/parts';

String _n(PkPowerTier t) => 't${t.index + 1}';

/// [light, mid, dark, glow]
List<Color> _pal(PkPowerTier? tier, bool left, double t, double u) {
  if (tier == PkPowerTier.tripleTurbo) {
    final h = t * .12 + u * 300 * (left ? 1 : -1);
    Color c(double hh, double l) =>
        HSLColor.fromAHSL(1, hh % 360, .95, l).toColor();
    return [c(h, .8), c(h, .58), c(h + 30, .4), c(h, .6)];
  }
  return switch (tier) {
    PkPowerTier.doublePower => const [
      Color(0xFFFFF0A0),
      Color(0xFFFFB21E),
      Color(0xFFE07800),
      Color(0xFFFFC23A),
    ],
    PkPowerTier.doubleTurbo => const [
      Color(0xFFFFC27A),
      Color(0xFFFF6A12),
      Color(0xFFC81E08),
      Color(0xFFFF5A1A),
    ],
    PkPowerTier.triple => const [
      Color(0xFFFFB0F8),
      Color(0xFFD84DFF),
      Color(0xFF6A2BE0),
      Color(0xFFC455FF),
    ],
    _ =>
      left
          ? const [
              Color(0xFFFF9AAA),
              Color(0xFFF0405A),
              Color(0xFFA80E28),
              Color(0xFFFF4060),
            ]
          : const [
              Color(0xFFA8DCFF),
              Color(0xFF3D8BFF),
              Color(0xFF1340B8),
              Color(0xFF3D8BFF),
            ],
  };
}

/// particles, flames, lightning, sweep period (ms, 0 = none), glow, chevron
/// speed
class _Fx {
  const new(
    this.particles,
    this.sweep,
    this.glow,
    this.speed, {
    this.flames = false,
    this.lightning = false,
  });
  final int particles;
  final bool flames;
  final bool lightning;
  final double sweep;
  final double glow;
  final double speed;
}

const _none = _Fx(0, 0, .25, .05);
_Fx _fx(PkPowerTier? t) => switch (t) {
  PkPowerTier.doublePower => const _Fx(14, 2600, .55, .07),
  PkPowerTier.doubleTurbo => const _Fx(26, 1900, .7, .11, flames: true),
  PkPowerTier.triple => const _Fx(34, 1500, .8, .13, lightning: true),
  PkPowerTier.tripleTurbo => const _Fx(
    48,
    1150,
    .95,
    .16,
    flames: true,
    lightning: true,
  ),
  null => _none,
};

double _c01(double v) => v.clamp(0.0, 1.0);
double _eo(double t) => 1 - math.pow(1 - t, 3).toDouble();
double _h(int a, int b) {
  var x = (a * 374761393 + b * 668265263) & 0x7fffffff;
  x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff;
  return (x & 0xffff) / 65536.0;
}

class PkBattleBar extends StatefulWidget {
  const new({
    required this.leftScore,
    required this.rightScore,
    super.key,
    this.leftTier,
    this.rightTier,
    this.leftAvatar,
    this.rightAvatar,
    this.width,
    this.showKabi = true,
    this.winner,
  });

  /// Kabi pushes / pulls the PK emblem for each team
  /// (assets/pk/score_bar/kabi/kabi_{push,pull,win}.png).
  final bool showKabi;

  /// Kabso (D199): the side that won the PK (its Kabi celebrates at the end,
  /// whatever the split); null while it runs.
  final PkPowerSide? winner;

  /// Kabso (D199): goldens and captures freeze the bar at this time (ms) with
  /// the split already at the score; null plays it.
  static double? debugTimeMs;

  /// Kabso (D199): with [debugTimeMs], the split's velocity (Kabi pushes
  /// when the side gains, pulls when it loses).
  static double debugVelocity = 0;
  final int leftScore;
  final int rightScore;
  final PkPowerTier? leftTier;
  final PkPowerTier? rightTier;
  final ImageProvider? leftAvatar;
  final ImageProvider? rightAvatar;
  final double? width;

  @override
  State<PkBattleBar> createState() => _PkBattleBarState();
}

/// All animated values live here; the PK screen is never rebuilt by the bar's
/// animation.
class _BarAnim extends ChangeNotifier {
  double t = 0;
  double ratio = .5;
  double vel = 0;
  double target = .5;
  double changedL = -1000000000;
  double changedR = -1000000000;
  bool reduced = false;
  void tick(double now) {
    final dt = math.min(1 / 30, (now - t) / 1000);
    t = now;
    if (reduced) {
      ratio = target;
      vel = 0;
    } else {
      // critically-damped-ish spring: the split glides to the new score and
      // settles
      final a = 60 * (target - ratio) - 11 * vel;
      vel += a * dt;
      ratio += vel * dt;
    }
    notifyListeners();
  }
}

class _PkBattleBarState extends State<PkBattleBar>
    with SingleTickerProviderStateMixin {
  final _a = _BarAnim();
  late final Ticker _ticker = createTicker(
    (e) => _a.tick(e.inMicroseconds / 1000.0),
  );

  double get _target {
    final l = widget.leftScore;
    final r = widget.rightScore;
    return (l + r) <= 0 ? .5 : l / (l + r);
  }

  @override
  void initState() {
    super.initState();
    _a
      ..target = _target
      ..ratio = _target;
    if (PkBattleBar.debugTimeMs case final t?) {
      _a
        ..t = t
        ..vel = PkBattleBar.debugVelocity;
      return;
    }
    _ticker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _a.reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    for (final t in PkPowerTier.values) {
      unawaited(
        precacheImage(AssetImage('$_dir/frameL_${_n(t)}.png'), context),
      );
      unawaited(
        precacheImage(AssetImage('$_dir/emblem_${_n(t)}.png'), context),
      );
    }
    for (final p in _KabiPose.values) {
      unawaited(precacheImage(AssetImage(p.asset), context));
    }
  }

  @override
  void didUpdateWidget(covariant PkBattleBar old) {
    super.didUpdateWidget(old);
    // only the target changes; the spring keeps its current position (no jump,
    // no restart)
    _a.target = _target;
    if (PkBattleBar.debugTimeMs != null) _a.ratio = _target;
    if (old.leftTier != widget.leftTier) _a.changedL = _a.t;
    if (old.rightTier != widget.rightTier) _a.changedR = _a.t;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = widget.width ?? c.maxWidth;
        final k = w / _sheetW;
        final h = _sheetH * k;
        final top = [widget.leftTier, widget.rightTier]
            .whereType<PkPowerTier>()
            .fold<PkPowerTier?>(
              null,
              (m, e) => m == null || e.index > m.index ? e : m,
            );
        final emblem = 'emblem_${_n(top ?? PkPowerTier.doublePower)}';

        Widget frame({required bool left}) {
          final tier = left ? widget.leftTier : widget.rightTier;
          final c0 = left ? _avatarL : _avatarR;
          final img = tier != null
              ? '$_dir/frameL_${_n(tier)}.png'
              : '$_dir/frame_neutral_${left ? 'L' : 'R'}.png';
          final avatar = left ? widget.leftAvatar : widget.rightAvatar;
          return Positioned(
            left: (c0.dx - 95) * k,
            top: 0,
            width: 190 * k,
            height: h,
            child: AnimatedBuilder(
              animation: _a,
              builder: (_, _) {
                final pul = tier == null || _a.reduced
                    ? 1.0
                    : 1 +
                          .03 *
                              math.sin(
                                _a.t /
                                    (tier == PkPowerTier.tripleTurbo
                                        ? 150
                                        : 260),
                              );
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: (95 - _avatarRad) * k,
                      top: (c0.dy - _avatarRad) * k,
                      width: _avatarRad * 2 * k,
                      height: _avatarRad * 2 * k,
                      child: ClipOval(
                        child: avatar != null
                            ? Image(image: avatar, fit: BoxFit.cover)
                            : ColoredBox(
                                color: const Color(0xFF1A1A24),
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white54,
                                  size: 40 * k,
                                ),
                              ),
                      ),
                    ),
                    Positioned.fill(
                      child: Transform.scale(
                        scale: pul,
                        child: Transform(
                          alignment: Alignment.center,
                          // right team uses the same tier frame, mirrored
                          transform: Matrix4.diagonal3Values(
                            !left && tier != null ? -1 : 1,
                            1,
                            1,
                          ),
                          child: Image.asset(
                            img,
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
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

        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _BarPainter(_a, widget.leftTier, widget.rightTier),
                  ),
                ),
              ),
              frame(left: true),
              frame(left: false),
              // Kabi mascots: one per team, hands on the PK emblem (drawn under
              // it so the hands tuck behind)
              if (widget.showKabi)
                _KabiPusher(
                  anim: _a,
                  left: true,
                  k: k,
                  won: widget.winner == PkPowerSide.left,
                ),
              if (widget.showKabi)
                _KabiPusher(
                  anim: _a,
                  left: false,
                  k: k,
                  won: widget.winner == PkPowerSide.right,
                ),
              // PK emblem rides the split
              AnimatedBuilder(
                animation: _a,
                builder: (_, child) {
                  final split =
                      (_trackL + (_trackR - _trackL) * _c01(_a.ratio)) * k;
                  final v = math.min(1, _a.vel.abs() * 6);
                  final sc = _a.reduced
                      ? 1.0
                      : 1 + .06 * math.sin(_a.t / 220) + .12 * v;
                  return Positioned(
                    left: split - 116 * k,
                    top: 0,
                    width: 232 * k,
                    height: h,
                    child: Transform.rotate(
                      angle: _a.reduced ? 0 : (_a.vel * .08).clamp(-.12, .12),
                      child: Transform.scale(scale: sc, child: child),
                    ),
                  );
                },
                child: Image.asset(
                  '$_dir/$emblem.png',
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                ),
              ),
              // scores (from state) — above everything, outlined
              Positioned(
                left: (_trackL + 24) * k,
                top: _trackY * k,
                height: _trackH * k,
                child: Center(child: _score(widget.leftScore, k)),
              ),
              Positioned(
                right: w - (_trackR - 24) * k,
                top: _trackY * k,
                height: _trackH * k,
                child: Center(child: _score(widget.rightScore, k)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _score(int v, double k) => IgnorePointer(
    child: Text(
      '$v',
      style: TextStyle(
        fontSize: _trackH * .66 * k,
        height: 1,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        shadows: [
          for (final o in const [
            Offset(1, 0),
            Offset(-1, 0),
            Offset(0, 1),
            Offset(0, -1),
          ])
            Shadow(color: const Color(0xD9000000), offset: o * 1.3),
        ],
      ),
    ),
  );
}

class _BarPainter extends CustomPainter {
  new(this.a, this.tierL, this.tierR) : super(repaint: a);
  final _BarAnim a;
  final PkPowerTier? tierL;
  final PkPowerTier? tierR;
  final _p = Paint();
  final _path = Path();

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / _sheetW;
    final t = a.t;
    final ty = _trackY * k;
    final th = _trackH * k;
    final tl = _trackL * k;
    final tr = _trackR * k;
    final cy = ty + th / 2;
    final split = tl + (tr - tl) * _c01(a.ratio);
    final sides = [
      (true, tl, split, tierL, a.changedL),
      (false, split, tr, tierR, a.changedR),
    ];
    final calm = a.reduced;

    // 1. outer aura per team (stacked translucent rounded rects — no blur)
    for (final (left, x1, x2, tier, _) in sides) {
      final f = _fx(tier);
      final p = _pal(tier, left, t, .5);
      final pul = calm
          ? 1.0
          : .8 +
                .2 *
                    math.sin(t / (tier == PkPowerTier.tripleTurbo ? 160 : 300));
      _p
        ..shader = null
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.plus;
      for (var i = 3; i >= 1; i--) {
        _p.color = p[3].pkAlpha(f.glow * .12 / i * pul);
        canvas.drawRRect(
          RRect.fromLTRBR(
            x1 - i * 21 * k,
            ty - i * 15 * k,
            x2 + i * 21 * k,
            ty + th + i * 15 * k,
            Radius.circular(th),
          ),
          _p,
        );
      }
    }

    // 2. flames off the fills (TURBO tiers), leaning toward the opponent
    if (!calm) {
      for (final (left, x1, x2, tier, _) in sides) {
        if (!_fx(tier).flames || x2 - x1 < th) continue;
        final dir = left ? 1.0 : -1.0;
        final n = math.max(4, ((x2 - x1) / (th * 1.3)).round());
        for (var i = 0; i < n * 2; i++) {
          final top = i < n;
          final j = i % n;
          final x = x1 + (x2 - x1) * ((j + .5) / n);
          final fl = .55 + .45 * math.sin(t / (70 + 13 * (i % 5)) + i * 2.3);
          final fh = th * (1.1 + .9 * _h(j, 7)) * fl;
          final fw = (x2 - x1) / n * .9;
          final y = top ? ty + 2 : ty + th - 2;
          final sg = top ? -1.0 : 1.0;
          final tip = x + dir * fw * .7;
          final p = _pal(tier, left, t, j / n);
          _p.shader =
              LinearGradient(
                begin: top ? Alignment.bottomCenter : Alignment.topCenter,
                end: top ? Alignment.topCenter : Alignment.bottomCenter,
                colors: [p[0].pkAlpha(.9), p[1].pkAlpha(.75), p[1].pkAlpha(0)],
                stops: const [0, .35, 1],
              ).createShader(
                Rect.fromLTRB(
                  x - fw,
                  math.min(y, y + sg * fh),
                  x + fw,
                  math.max(y, y + sg * fh),
                ),
              );
          _path
            ..reset()
            ..moveTo(x - fw / 2, y)
            ..quadraticBezierTo(x - fw * .1, y + sg * fh * .6, tip, y + sg * fh)
            ..quadraticBezierTo(x + fw * .4, y + sg * fh * .45, x + fw / 2, y)
            ..close();
          canvas.drawPath(_path, _p);
        }
        _p.shader = null;
      }
    }

    // 3. track + fills
    final track = RRect.fromLTRBR(tl, ty, tr, ty + th, Radius.circular(th / 2));
    canvas
      ..save()
      ..clipRRect(track);
    _p
      ..blendMode = BlendMode.srcOver
      ..shader = null
      ..color = const Color(0xFF07070D);
    canvas.drawRRect(track, _p);
    for (final (left, x1, x2, tier, changed) in sides) {
      if (x2 - x1 < 1) continue;
      final f = _fx(tier);
      final dir = left ? 1.0 : -1.0;
      final rect = Rect.fromLTRB(x1, ty, x2, ty + th);
      final from = left ? Alignment.centerLeft : Alignment.centerRight;
      final to = left ? Alignment.centerRight : Alignment.centerLeft;
      final colors = tier == PkPowerTier.tripleTurbo
          ? [
              for (var q = 0; q <= 6; q++)
                HSLColor.fromAHSL(
                  1,
                  (t * .12 + q * 55 * dir) % 360,
                  .95,
                  .58,
                ).toColor(),
            ]
          : (() {
              final p = _pal(tier, left, t, 0);
              return [p[2], p[1], p[0]];
            })();
      _p.shader = LinearGradient(
        begin: from,
        end: to,
        colors: colors,
        stops: colors.length == 3 ? const [0, .75, 1] : null,
      ).createShader(rect);
      canvas.drawRect(rect, _p);
      _p.shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x73FFFFFF),
          Color(0x0DFFFFFF),
          Color(0x0D000000),
          Color(0x59000000),
        ],
        stops: [0, .45, .55, 1],
      ).createShader(rect);
      canvas.drawRect(rect, _p);
      _p.shader = null;

      canvas
        ..save()
        ..clipRect(rect);
      // chevrons flowing toward the opponent, brighter near the clash point
      final step = th * .85;
      final off = calm ? 0.0 : ((t * f.speed * dir) % step + step) % step;
      _p
        ..blendMode = BlendMode.plus
        ..style = PaintingStyle.stroke
        ..strokeWidth = th * .16
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (var x = x1 - step * 2 + off; x < x2 + step; x += step) {
        final near = left
            ? _c01(1 - (x2 - x) / (th * 8))
            : _c01(1 - (x - x1) / (th * 8));
        _p.color = Colors.white.pkAlpha(.12 + .5 * near);
        _path
          ..reset()
          ..moveTo(x - dir * th * .18, ty + th * .24)
          ..lineTo(x + dir * th * .1, cy)
          ..lineTo(x - dir * th * .18, ty + th * .76);
        canvas.drawPath(_path, _p);
      }
      _p.style = PaintingStyle.fill;
      // light sweep (faster for higher tiers)
      if (f.sweep > 0 && !calm) {
        final u = (t % f.sweep) / (f.sweep * .42);
        if (u < 1) {
          final cx = left
              ? x1 + (x2 - x1) * (u * 1.4 - .2)
              : x2 - (x2 - x1) * (u * 1.4 - .2);
          final r = Rect.fromLTRB(cx - th * 2.2, ty, cx + th * 2.2, ty + th);
          _p.shader = const LinearGradient(
            colors: [Color(0x00FFFFFF), Color(0xA6FFFFFF), Color(0x00FFFFFF)],
          ).createShader(r);
          canvas.drawRect(r, _p);
          _p.shader = null;
        }
      }
      // activation flash (450 ms)
      final fa = _c01((t - changed) / 450);
      if (tier != null && fa < 1) {
        _p.color = Colors.white.pkAlpha(.7 * math.sin(fa * math.pi));
        canvas.drawRect(rect, _p);
      }
      canvas.restore();
    }
    canvas.restore();

    // 4. rim in each team's colour, meeting at the split
    _p
      ..blendMode = BlendMode.plus
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.6 * k;
    for (final (left, x1, x2, tier, _) in sides) {
      canvas
        ..save()
        ..clipRect(Rect.fromLTRB(x1, ty - 10, x2, ty + th + 10));
      _p.color = _pal(tier, left, t, .5)[0].pkAlpha(.9);
      canvas
        ..drawRRect(track, _p)
        ..restore();
    }

    if (calm) return;

    // 5. lightning crawling along the rim (TRIPLE tiers)
    final b = (t / 55).floor();
    _p
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final (left, x1, x2, tier, _) in sides) {
      if (!_fx(tier).lightning || x2 - x1 < th) continue;
      final dir = left ? 1.0 : -1.0;
      for (var q = 0; q < 3; q++) {
        final y = q == 1 ? cy : (q == 0 ? ty : ty + th);
        final u = ((t / (520 + 170 * q)) + q * .37) % 1;
        final xa = left ? x1 + (x2 - x1) * u : x2 - (x2 - x1) * u;
        final len = math.min((x2 - x1) * .45, th * 7);
        _path
          ..reset()
          ..moveTo(xa, y);
        for (var j = 1; j <= 7; j++) {
          _path.lineTo(
            xa - dir * len * j / 7,
            y +
                (_h(b + q * 13 + (left ? 0 : 99), j) - .5) *
                    th *
                    (q == 1 ? .5 : 1.2),
          );
        }
        final av = math.sin(u * math.pi);
        _p
          ..strokeWidth = th * .28
          ..color = _pal(tier, left, t, q / 3)[3].pkAlpha(.45 * av);
        canvas.drawPath(_path, _p);
        _p
          ..strokeWidth = th * .08
          ..color = Colors.white.pkAlpha(.95 * av);
        canvas.drawPath(_path, _p);
      }
    }

    // 6. particles drifting toward the clash point (deterministic,
    // allocation-free)
    for (final (left, x1, x2, tier, _) in sides) {
      final f = _fx(tier);
      if (f.particles == 0) continue;
      final dir = left ? 1.0 : -1.0;
      for (var i = 0; i < f.particles; i++) {
        final life = 700 + _h(i, 1) * 900;
        final u = ((t + _h(i, 2) * 5000) % life) / life;
        final top = _h(i, 3) < .5;
        final x =
            x1 +
            (x2 - x1) *
                (left
                    ? (_h(i, 4) * .9 + u * .35)
                    : (1 - _h(i, 4) * .9 - u * .35));
        if (x < x1 || x > x2) continue;
        final y = top
            ? ty - th * (.2 + _h(i, 5) * 1.6) - u * th * .6
            : ty + th + th * (.2 + _h(i, 5) * 1.6) + u * th * .3;
        final av = math.sin(u * math.pi);
        final sz = th * (.06 + .08 * _h(i, 6));
        final col = tier == PkPowerTier.tripleTurbo
            ? HSLColor.fromAHSL(1, (t * .12 + i * 29) % 360, .95, .62).toColor()
            : _pal(tier, left, t, 0)[i % 3 == 0 ? 0 : 1];
        if (i % 4 == 0) {
          _p
            ..style = PaintingStyle.stroke
            ..strokeWidth = sz * .8
            ..color = col.pkAlpha(av);
          canvas.drawLine(Offset(x, y), Offset(x - dir * sz * 7, y), _p);
        } else if (f.lightning && i % 4 == 1) {
          canvas
            ..save()
            ..translate(x, y)
            ..rotate(t / 250 + i);
          _p
            ..style = PaintingStyle.fill
            ..color = col.pkAlpha(av);
          _path
            ..reset()
            ..moveTo(0, -sz * 2.4)
            ..lineTo(sz, 0)
            ..lineTo(0, sz * 2.4)
            ..lineTo(-sz, 0)
            ..close();
          canvas
            ..drawPath(_path, _p)
            ..restore();
        } else {
          _p
            ..style = PaintingStyle.fill
            ..color = col.pkAlpha(av);
          canvas.drawCircle(Offset(x, y), sz, _p);
          _p.color = col.pkAlpha(av * .3);
          canvas.drawCircle(Offset(x, y), sz * 2.6, _p);
        }
      }
    }

    // 7. clash point: glow + sparks, flaring while the split moves
    final v = math.min(1, a.vel.abs() * 6).toDouble();
    final r0 = th * 1.6;
    _p
      ..style = PaintingStyle.fill
      ..shader =
          RadialGradient(
            colors: [
              Colors.white.pkAlpha(.5 + .4 * v),
              const Color(0x59FFDC96),
              const Color(0x00FF783C),
            ],
            stops: const [0, .3, 1],
          ).createShader(
            Rect.fromCircle(center: Offset(split, cy), radius: r0 * (1.3 + v)),
          );
    canvas.drawCircle(Offset(split, cy), r0 * (1.3 + v), _p);
    _p
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = th * .07;
    for (var i = 0; i < 10; i++) {
      final life = 380 + _h(i, 9) * 300;
      final u = ((t + i * 97) % life) / life;
      final ang =
          (_h(((t + i * 97) / life).floor(), i) - .5) * math.pi * 1.6 +
          (i.isOdd ? 0 : math.pi);
      final d = th * (1.2 + 2.6 * _eo(u)) * (1 + v);
      _p.color = Color.fromRGBO(
        255,
        200 + 40 * (i % 2),
        i % 3 == 0 ? 230 : 150,
        (1 - u) * .9,
      );
      canvas.drawLine(
        Offset(split + math.cos(ang) * d * .6, cy + math.sin(ang) * d * .35),
        Offset(split + math.cos(ang) * d, cy + math.sin(ang) * d * .6),
        _p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter o) =>
      o.tierL != tierL || o.tierR != tierR;
}

// ───────────────────────────── Kabi push / pull ─────────────────────────────
enum _KabiPose {
  // hand = where the hands are in the image (fraction of width / height) — that
  // point is pinned to the emblem
  push('assets/pk/score_bar/kabi/kabi_push.png', Offset(.984, .584), 512 / 413),
  pull('assets/pk/score_bar/kabi/kabi_pull.png', Offset(.992, .609), 512 / 414),
  win('assets/pk/score_bar/kabi/kabi_win.png', Offset(.5, .5), 512 / 489);

  new(this.asset, this.hand, this.aspect);
  final String asset;
  final Offset hand;
  final double aspect;
}

/// One team's Kabi. The team gaining ground pushes the emblem toward the
/// opponent; the team losing ground
/// leans back and pulls (shaking, sweat); a big, stable lead (> 72 %) makes the
/// leader hop in victory.
/// The right team's Kabi is the same art mirrored. All motion comes from the
/// shared ticker — no extra controllers.
class _KabiPusher extends StatefulWidget {
  const new({
    required this.anim,
    required this.left,
    required this.k,
    this.won = false,
  });
  final _BarAnim anim;

  /// Kabso (D199): this side won — the win pose at the end.
  final bool won;
  final bool left;
  final double k;

  @override
  State<_KabiPusher> createState() => _KabiPusherState();
}

class _KabiPusherState extends State<_KabiPusher> {
  _KabiPose _pose = _KabiPose.push;
  double _changed = 0;

  @override
  Widget build(BuildContext context) {
    final a = widget.anim;
    final k = widget.k;
    return AnimatedBuilder(
      animation: a,
      builder: (_, _) {
        final t = a.t;
        final dir = widget.left ? 1.0 : -1.0;
        final v = a.vel * dir;
        final share = widget.left ? a.ratio : 1 - a.ratio;
        final want = widget.won
            ? _KabiPose.win
            : v > .02
            ? _KabiPose.push
            : (v < -.02
                  ? _KabiPose.pull
                  : (share > .72 ? _KabiPose.win : _KabiPose.push));
        if (want != _pose) {
          _pose = want;
          _changed = t;
        }
        final pop = ((t - _changed) / 140).clamp(
          0.0,
          1.0,
        ); // small pop when the pose switches
        final split = (_trackL + (_trackR - _trackL) * _c01(a.ratio)) * k;
        final cy = 124 * k;
        final kh = 215 * k;
        final kw = kh * _pose.aspect;
        final effort = math.min(1, a.vel.abs() * 8);
        final calm = a.reduced;

        double x;
        double y;
        double rot = 0;
        double sx = 1;
        double sy = 1;
        Offset origin;
        if (_pose == _KabiPose.win) {
          final hop = calm ? 0.0 : math.sin(t / 180).abs() * 26 * k;
          x = split - dir * 150 * k;
          y = cy - 40 * k - hop;
          rot = calm ? 0 : math.sin(t / 180) * .08;
          sx = sy = .9;
          origin = Offset(kw / 2, kh / 2);
        } else {
          final push = _pose == _KabiPose.push;
          final e = push ? (v > .02 ? effort : .2) : effort;
          x =
              split -
              dir * 58 * k +
              (calm
                  ? 0
                  : (push
                            ? math.sin(t / 300) * 1.2
                            : math.sin(t / 23) * 1.6 * e) *
                        k);
          y = cy - 18 * k;
          rot = calm ? 0 : (push ? .02 + .06 * e : -.03 - .06 * e);
          final sq = calm
              ? 1.0
              : 1 +
                    (push ? .05 : -.04) *
                        math.sin(t / (push ? 120 : 60)) *
                        (.3 + e);
          sx = 1 / sq;
          sy = sq;
          origin = Offset(_pose.hand.dx * kw, _pose.hand.dy * kh);
        }
        final s0 = .85 + .15 * Curves.easeOutBack.transform(pop);
        return Positioned(
          left: x - origin.dx,
          top: y - origin.dy,
          width: kw,
          height: kh,
          child: IgnorePointer(
            child: Transform(
              origin: origin,
              transform: Matrix4.identity()
                ..scaleByDouble(dir, 1, 1, 1) // mirror for the right team
                ..rotateZ(rot)
                ..scaleByDouble(sx * s0, sy * s0, 1, 1),
              child: Image.asset(
                _pose.asset,
                fit: BoxFit.fill,
                gaplessPlayback: true,
              ),
            ),
          ),
        );
      },
    );
  }
}
