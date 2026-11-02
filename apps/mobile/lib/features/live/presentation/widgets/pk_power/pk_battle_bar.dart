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
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_power_models.dart';
import 'package:material_ui/material_ui.dart';

// The owner's art in its sheet units (frames 190 × 250, the avatar centred
// at y 124 with radius 38.5; emblem 232 × 250).
const _sheetH = 250.0;
const _frameW = 190.0;
const _avatarY = 124.0;
const _avatarRad = 38.5;
const _emblemW = 232.0;
const _dir = 'assets/pk/score_bar/parts';

/// D231 (owner on a phone: «شريط الـpk صغير والأرقام غير واضحة … وإن لاحظت
/// أن خط الـpk مرتفع عن الشاشتين»): the bar no longer scales the 1536 × 250
/// sheet to the width (a 10 lp track with 7 sp numbers and 27 lp of empty
/// sheet under it, which was the gap above the videos). It is laid out in
/// logical pixels: a [track]-high track whose bottom edge IS the bar's
/// bottom edge (the stage puts the videos right there), [above] of room for
/// Kabi over it, the owner's frames and PK emblem centred on the track
/// (they reach a little over the videos), and each side's score in big
/// outlined figures that the emblem never covers.
abstract final class PkBarMetrics {
  /// The track's height.
  static const double track = 30;

  /// Room over the track for Kabi pushing the emblem.
  static const double above = 34;

  /// The bar's box: the track's bottom is the box's bottom.
  static const double height = above + track;

  /// The owner's tier / neutral frame art's height (the avatar inside is
  /// 77 / 250 of it).
  static const double frame = 64;

  /// The PK emblem's height.
  static const double emblem = 50;

  /// Kabi's height.
  static const double kabi = 40;

  /// The score figures (sp; clamped to the overlay text scale).
  static const double score = 19;

  /// The figures' face: the bundled Baloo Bhaijaan 2 ExtraBold (D199).
  static const String family = 'Baloo Bhaijaan 2';

  /// The largest text scale the figures follow.
  static const double maxTextScale = 1.3;

  /// Gap between a score and the emblem at its nearest.
  static const double gap = 4;

  static double get _kf => frame / _sheetH;
  static double get frameWidth => _frameW * _kf;

  /// The avatar's centre from the bar's outer edge.
  static double get avatarCentre => frameWidth / 2;
  static double get avatarSize => _avatarRad * 2 * _kf;
  static double get emblemWidth => emblem * _emblemW / _sheetH;

  /// Where a side's score starts, from the bar's outer edge.
  static double get scoreInset => frameWidth - 2;

  /// The track's vertical centre in the bar's box.
  static const double trackCentre = above + track / 2;
}

/// The score as the bar shows it: short Latin figures in every language
/// (999, 12.5K, 834.3K, 1.2M — tenths cut, never rounded up), the D220
/// format without its bidi isolate (the bar's text is left-to-right).
String pkBarScore(int value) =>
    KFormat.compactLatin(value).replaceAll(RegExp('[\u2066\u2069]'), '');

/// The score figures' style: white, an even dark outline and a soft shadow.
TextStyle pkBarScoreStyle() => TextStyle(
  fontFamily: PkBarMetrics.family,
  fontFamilyFallback: const ['Inter'],
  fontSize: PkBarMetrics.score,
  height: 1,
  fontWeight: FontWeight.w800,
  color: const Color(0xFFFFFFFF),
  fontFeatures: const [FontFeature.tabularFigures()],
  shadows: [
    for (final o in const [
      Offset(1.4, 0),
      Offset(-1.4, 0),
      Offset(0, 1.4),
      Offset(0, -1.4),
      Offset(1, 1),
      Offset(-1, -1),
      Offset(1, -1),
      Offset(-1, 1),
    ])
      Shadow(color: const Color(0xF2000000), offset: o),
    const Shadow(color: Color(0x99000000), blurRadius: 4, offset: Offset(0, 1)),
  ],
);

String _n(PkPowerTier t) => 't${t.index + 1}';

/// [light, mid, dark, glow]; [red] (D231): with no booster, this room's
/// side is Kabso red and the opponent blue, whichever screen side they are.
List<Color> _pal(
  PkPowerTier? tier,
  bool left,
  double t,
  double u, {
  required bool red,
}) {
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
      red
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
    this.ownSide = PkPowerSide.left,
  });

  /// D231: this room's side on screen (Kabso red with no booster; the
  /// opponent blue).
  final PkPowerSide ownSide;

  static const leftScoreKey = Key('pk.bar.score.left');
  static const rightScoreKey = Key('pk.bar.score.right');
  static const emblemKey = Key('pk.bar.emblem');

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
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: PkBarMetrics.maxTextScale);
    // Measured as drawn: the inherited text style with the figures' own.
    final base = DefaultTextStyle.of(context).style.merge(pkBarScoreStyle());
    final leftText = pkBarScore(widget.leftScore);
    final rightText = pkBarScore(widget.rightScore);
    double measure(String s, TextStyle style) {
      final p = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = p.width;
      p.dispose();
      return width;
    }

    return LayoutBuilder(
      builder: (context, c) {
        final w = widget.width ?? c.maxWidth;
        // Both figures and the emblem between them must fit; on a very
        // narrow bar or a very large text the figures shrink (never the
        // emblem over them).
        final room =
            w -
            2 * PkBarMetrics.scoreInset -
            PkBarMetrics.emblemWidth -
            2 * PkBarMetrics.gap;
        var style = base;
        var leftWidth = measure(leftText, style);
        var rightWidth = measure(rightText, style);
        final need = leftWidth + rightWidth;
        if (need > room && room > 0) {
          style = base.copyWith(fontSize: base.fontSize! * room / need);
          leftWidth = measure(leftText, style);
          rightWidth = measure(rightText, style);
        }
        final g = _geoOf(
          w,
          leftWidth: leftWidth,
          rightWidth: rightWidth,
          leftRed: widget.ownSide == PkPowerSide.left,
        );
        const kf = PkBarMetrics.frame / _sheetH;
        final top = [widget.leftTier, widget.rightTier]
            .whereType<PkPowerTier>()
            .fold<PkPowerTier?>(
              null,
              (m, e) => m == null || e.index > m.index ? e : m,
            );
        final emblem = 'emblem_${_n(top ?? PkPowerTier.doublePower)}';

        Widget frame({required bool left}) {
          final tier = left ? widget.leftTier : widget.rightTier;
          // D231: this room's neutral frame is the red one, the opponent's
          // the blue one, on whichever side they are (mirrored to fit).
          final art = (widget.ownSide == PkPowerSide.left) == left ? 'L' : 'R';
          final img = tier != null
              ? '$_dir/frameL_${_n(tier)}.png'
              : '$_dir/frame_neutral_$art.png';
          final mirror = tier != null ? !left : (art == 'L') != left;
          final avatar = left ? widget.leftAvatar : widget.rightAvatar;
          final fw = PkBarMetrics.frameWidth;
          final d = PkBarMetrics.avatarSize;
          final cx = left
              ? PkBarMetrics.avatarCentre
              : w - PkBarMetrics.avatarCentre;
          return Positioned(
            left: cx - fw / 2,
            top: PkBarMetrics.trackCentre - _avatarY * kf,
            width: fw,
            height: PkBarMetrics.frame,
            child: IgnorePointer(
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
                        left: fw / 2 - d / 2,
                        top: _avatarY * kf - d / 2,
                        width: d,
                        height: d,
                        child: ClipOval(
                          child: avatar != null
                              ? Image(image: avatar, fit: BoxFit.cover)
                              : ColoredBox(
                                  color: const Color(0xFF2A1A2E),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white70,
                                    size: d * .7,
                                  ),
                                ),
                        ),
                      ),
                      Positioned.fill(
                        child: Transform.scale(
                          scale: pul,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.diagonal3Values(
                              mirror ? -1 : 1,
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
            ),
          );
        }

        return SizedBox(
          width: w,
          height: PkBarMetrics.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _BarPainter(
                      _a,
                      widget.leftTier,
                      widget.rightTier,
                      g,
                    ),
                  ),
                ),
              ),
              frame(left: true),
              frame(left: false),
              // Kabi mascots: one per team over the track, hands on the PK
              // emblem (drawn under it so the hands tuck behind).
              if (widget.showKabi)
                _KabiPusher(
                  anim: _a,
                  left: true,
                  geo: g,
                  won: widget.winner == PkPowerSide.left,
                ),
              if (widget.showKabi)
                _KabiPusher(
                  anim: _a,
                  left: false,
                  geo: g,
                  won: widget.winner == PkPowerSide.right,
                ),
              // PK emblem rides the split (never over a score, D231).
              AnimatedBuilder(
                animation: _a,
                builder: (_, child) {
                  final split = g.split(_a.ratio);
                  final v = math.min(1, _a.vel.abs() * 6);
                  final sc = _a.reduced
                      ? 1.0
                      : 1 + .06 * math.sin(_a.t / 220) + .12 * v;
                  final ew = PkBarMetrics.emblemWidth;
                  return Positioned(
                    left: split - ew / 2,
                    top: PkBarMetrics.trackCentre - PkBarMetrics.emblem / 2,
                    width: ew,
                    height: PkBarMetrics.emblem,
                    child: IgnorePointer(
                      child: Transform.rotate(
                        angle: _a.reduced ? 0 : (_a.vel * .08).clamp(-.12, .12),
                        child: Transform.scale(scale: sc, child: child),
                      ),
                    ),
                  );
                },
                child: Image.asset(
                  '$_dir/$emblem.png',
                  key: PkBattleBar.emblemKey,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                ),
              ),
              // D231: the scores — big outlined figures at each end of the
              // track, above everything.
              Positioned(
                left: PkBarMetrics.scoreInset,
                top: PkBarMetrics.above,
                height: PkBarMetrics.track,
                child: Center(
                  child: _score(
                    leftText,
                    style,
                    scaler,
                    PkBattleBar.leftScoreKey,
                  ),
                ),
              ),
              Positioned(
                right: PkBarMetrics.scoreInset,
                top: PkBarMetrics.above,
                height: PkBarMetrics.track,
                child: Center(
                  child: _score(
                    rightText,
                    style,
                    scaler,
                    PkBattleBar.rightScoreKey,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _score(String v, TextStyle style, TextScaler scaler, Key key) =>
      IgnorePointer(
        child: Text(
          v,
          key: key,
          textDirection: TextDirection.ltr,
          maxLines: 1,
          softWrap: false,
          textScaler: scaler,
          style: style,
        ),
      );
}

/// The old sheet scale at 393 lp (lp per sheet unit) and the old track's
/// height: the effects' sizes (D231 keeps them as they were).
const _k0 = 0.256;
const _fu = 10.0;

/// D231: the track's ends and the split's range on a bar of a given width — the
/// emblem stops short of each side's figures.
typedef _Geo = ({double tl, double tr, double lo, double hi, bool leftRed});

extension on _Geo {
  /// The split's x for [ratio] (the left team's share), kept in [lo, hi].
  double split(double ratio) => tl + (tr - tl) * (lo + (hi - lo) * _c01(ratio));
}

_Geo _geoOf(
  double w, {
  required double leftWidth,
  required double rightWidth,
  required bool leftRed,
}) {
  final tl = PkBarMetrics.avatarCentre;
  final tr = w - PkBarMetrics.avatarCentre;
  final span = math.max(1, tr - tl).toDouble();
  final half = PkBarMetrics.emblemWidth / 2;
  final reserve = PkBarMetrics.scoreInset + PkBarMetrics.gap + half;
  var lo = (reserve + leftWidth - tl) / span;
  var hi = (w - reserve - rightWidth - tl) / span;
  if (lo > hi) lo = hi = (lo + hi) / 2;
  return (tl: tl, tr: tr, lo: _c01(lo), hi: _c01(hi), leftRed: leftRed);
}

class _BarPainter extends CustomPainter {
  new(this.a, this.tierL, this.tierR, this.g) : super(repaint: a);
  final _BarAnim a;
  final PkPowerTier? tierL;
  final PkPowerTier? tierR;
  final _Geo g;
  final _p = Paint();
  final _path = Path();

  @override
  void paint(Canvas canvas, Size size) {
    // D231: the track in logical pixels; the effects keep the size they
    // had on the old 10 lp track ([_k0] per sheet unit, [_fu] their unit).
    const k = _k0;
    const fu = _fu;
    final t = a.t;
    const ty = PkBarMetrics.above;
    const th = PkBarMetrics.track;
    final tl = g.tl;
    final tr = g.tr;
    const cy = ty + th / 2;
    final split = g.split(a.ratio);
    final sides = [
      (true, tl, split, tierL, a.changedL, g.leftRed),
      (false, split, tr, tierR, a.changedR, !g.leftRed),
    ];
    final calm = a.reduced;

    // 1. outer aura per team (stacked translucent rounded rects — no blur)
    for (final (left, x1, x2, tier, _, red) in sides) {
      final f = _fx(tier);
      final p = _pal(tier, left, t, .5, red: red);
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
            const Radius.circular(th),
          ),
          _p,
        );
      }
    }

    // 2. flames off the fills (TURBO tiers), leaning toward the opponent
    if (!calm) {
      for (final (left, x1, x2, tier, _, red) in sides) {
        if (!_fx(tier).flames || x2 - x1 < fu) continue;
        final dir = left ? 1.0 : -1.0;
        final n = math.max(4, ((x2 - x1) / (fu * 1.3)).round());
        for (var i = 0; i < n * 2; i++) {
          final top = i < n;
          final j = i % n;
          final x = x1 + (x2 - x1) * ((j + .5) / n);
          final fl = .55 + .45 * math.sin(t / (70 + 13 * (i % 5)) + i * 2.3);
          final fh = fu * (1.1 + .9 * _h(j, 7)) * fl;
          final fw = (x2 - x1) / n * .9;
          final y = top ? ty + 2 : ty + th - 2;
          final sg = top ? -1.0 : 1.0;
          final tip = x + dir * fw * .7;
          final p = _pal(tier, left, t, j / n, red: red);
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
    final track = RRect.fromLTRBR(
      tl,
      ty,
      tr,
      ty + th,
      const Radius.circular(th / 2),
    );
    canvas
      ..save()
      ..clipRRect(track);
    _p
      ..blendMode = BlendMode.srcOver
      ..shader = null
      ..color = const Color(0xFF07070D);
    canvas.drawRRect(track, _p);
    for (final (left, x1, x2, tier, changed, red) in sides) {
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
              final p = _pal(tier, left, t, 0, red: red);
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
      const step = th * .85;
      final off = calm ? 0.0 : ((t * f.speed * dir) % step + step) % step;
      _p
        ..blendMode = BlendMode.plus
        ..style = PaintingStyle.stroke
        ..strokeWidth = th * .12
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (var x = x1 - step * 2 + off; x < x2 + step; x += step) {
        final near = left
            ? _c01(1 - (x2 - x) / (th * 8))
            : _c01(1 - (x - x1) / (th * 8));
        _p.color = Colors.white.pkAlpha(.1 + .35 * near);
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
      ..strokeWidth = 2.2;
    for (final (left, x1, x2, tier, _, red) in sides) {
      canvas
        ..save()
        ..clipRect(Rect.fromLTRB(x1, ty - 10, x2, ty + th + 10));
      _p.color = _pal(tier, left, t, .5, red: red)[0].pkAlpha(.9);
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
    for (final (left, x1, x2, tier, _, red) in sides) {
      if (!_fx(tier).lightning || x2 - x1 < fu) continue;
      final dir = left ? 1.0 : -1.0;
      for (var q = 0; q < 3; q++) {
        final y = q == 1 ? cy : (q == 0 ? ty : ty + th);
        final u = ((t / (520 + 170 * q)) + q * .37) % 1;
        final xa = left ? x1 + (x2 - x1) * u : x2 - (x2 - x1) * u;
        final len = math.min((x2 - x1) * .45, fu * 7);
        _path
          ..reset()
          ..moveTo(xa, y);
        for (var j = 1; j <= 7; j++) {
          _path.lineTo(
            xa - dir * len * j / 7,
            y +
                (_h(b + q * 13 + (left ? 0 : 99), j) - .5) *
                    fu *
                    (q == 1 ? .5 : 1.2),
          );
        }
        final av = math.sin(u * math.pi);
        _p
          ..strokeWidth = fu * .28
          ..color = _pal(tier, left, t, q / 3, red: red)[3].pkAlpha(.45 * av);
        canvas.drawPath(_path, _p);
        _p
          ..strokeWidth = fu * .08
          ..color = Colors.white.pkAlpha(.95 * av);
        canvas.drawPath(_path, _p);
      }
    }

    // 6. particles drifting toward the clash point (deterministic,
    // allocation-free)
    for (final (left, x1, x2, tier, _, red) in sides) {
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
            ? ty - fu * (.2 + _h(i, 5) * 1.6) - u * fu * .6
            : ty + th + fu * (.2 + _h(i, 5) * 1.6) + u * fu * .3;
        final av = math.sin(u * math.pi);
        final sz = fu * (.06 + .08 * _h(i, 6));
        final col = tier == PkPowerTier.tripleTurbo
            ? HSLColor.fromAHSL(1, (t * .12 + i * 29) % 360, .95, .62).toColor()
            : _pal(tier, left, t, 0, red: red)[i % 3 == 0 ? 0 : 1];
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
    const r0 = th * .9;
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
      ..strokeWidth = fu * .1;
    for (var i = 0; i < 10; i++) {
      final life = 380 + _h(i, 9) * 300;
      final u = ((t + i * 97) % life) / life;
      final ang =
          (_h(((t + i * 97) / life).floor(), i) - .5) * math.pi * 1.6 +
          (i.isOdd ? 0 : math.pi);
      final d = fu * (1.2 + 2.6 * _eo(u)) * (1 + v);
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
      o.tierL != tierL || o.tierR != tierR || o.g != g;
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
    required this.geo,
    this.won = false,
  });
  final _BarAnim anim;

  /// Kabso (D199): this side won — the win pose at the end.
  final bool won;
  final bool left;
  final _Geo geo;

  @override
  State<_KabiPusher> createState() => _KabiPusherState();
}

class _KabiPusherState extends State<_KabiPusher> {
  _KabiPose _pose = _KabiPose.push;
  double _changed = 0;

  @override
  Widget build(BuildContext context) {
    final a = widget.anim;
    final g = widget.geo;
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
        // D231: Kabi stands over the track (never over the figures), the
        // hands on the emblem's upper edge.
        final split = g.split(a.ratio);
        const kh = PkBarMetrics.kabi;
        const k = kh / 215;
        const feet = PkBarMetrics.above + 2;
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
          x = split - dir * (PkBarMetrics.emblemWidth / 2 + kw * .42);
          y = feet - kh / 2 - hop;
          rot = calm ? 0 : math.sin(t / 180) * .08;
          sx = sy = .9;
          origin = Offset(kw / 2, kh / 2);
        } else {
          final push = _pose == _KabiPose.push;
          final e = push ? (v > .02 ? effort : .2) : effort;
          x =
              split -
              dir * PkBarMetrics.emblemWidth * .42 +
              (calm
                  ? 0
                  : (push
                            ? math.sin(t / 300) * 1.2
                            : math.sin(t / 23) * 1.6 * e) *
                        k);
          y = feet - kh + _pose.hand.dy * kh;
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
