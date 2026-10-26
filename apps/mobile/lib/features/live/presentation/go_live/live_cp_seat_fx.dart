import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:kabso_live/features/live/presentation/go_live/live_cp_seats.dart';
import 'package:material_ui/material_ui.dart';

/// Owner D113 (amendment, "use the small pieces as animation around the
/// couple"): a light ambient animation around a CP pair joined on seats —
/// sparkles and hearts twinkling above the rings, butterflies fluttering
/// over the pair, petals drifting down the gap, swirls turning by the
/// ornament, a planet (level 2's theme) and a platform under the level-6
/// pair. Richness grows with the CP level. The parts are the owner's art
/// (`assets/live_cp_seats/fx/`, see its PROVENANCE.md).
///
/// Nothing ever covers a picture, a name or a mic badge: every part's whole
/// path is checked against those obstacles and the pair's area once, and a
/// part that would touch one is left out (no popping mid-flight). One
/// controller per pair, inside a [RepaintBoundary]; the room passes a
/// smaller [budget] when many pairs show. With reduced motion
/// (`MediaQuery.disableAnimations`) or [animate] off (widget tests and
/// goldens) the parts hold still at [stillAt].
class CpPairFx extends StatefulWidget {
  const new({
    required this.level,
    required this.a,
    required this.b,
    required this.picture,
    required this.area,
    required this.obstacles,
    this.budget = maxParts,
    this.ornament,
    this.ornamentBounds,
    this.ornamentChild,
    this.ornamentKey,
    super.key,
  });

  /// Owner D113 (feedback): the centre ornament's box (stage coordinates),
  /// drawn here above the rings with the link effect — a heartbeat glow
  /// behind it, a shimmer flowing from each partner's picture to it, and
  /// small hearts and sparkles it lets out now and then. Null: no ornament.
  final Rect? ornament;

  /// Where the ornament and what it lets out may show (defaults to [area]).
  final Rect? ornamentBounds;
  final Widget? ornamentChild;
  final Key? ornamentKey;

  /// The couple's CP level (1–6; others use the nearest).
  final int level;

  /// The two pictures' centres and diameter, in the stage's (visual)
  /// coordinates.
  final Offset a;
  final Offset b;
  final double picture;

  /// Where the parts may show (the pair's tiles, above the names), in the
  /// stage's coordinates; the widget is placed there with [Positioned].
  final Rect area;

  /// Pictures, names and mic badges of the room, in the stage's coordinates.
  final List<CpObstacle> obstacles;

  /// The most parts drawn for this pair.
  final int budget;

  /// The most parts per pair, and the fewer each pair gets when the room
  /// shows many pairs (25 seats).
  static const maxParts = 12;
  static const crowdedParts = 6;

  /// Pairs above this count use [crowdedParts].
  static const crowdedPairs = 4;

  /// One loop of the animation.
  static const period = Duration(seconds: 8);

  /// Off in widget tests and goldens (`test/flutter_test_config.dart`).
  static bool animate = true;

  /// The loop position shown when not animating (mid-way, parts visible).
  static double stillAt = 0.5;

  static Key keyFor(int a, int b) => Key('audioSeat.cp.$a.$b.fx');

  /// Positions this pair's animation in a [Stack].
  Widget positioned() => Positioned.fromRect(rect: area, child: this);

  @override
  State<CpPairFx> createState() => _CpPairFxState();
}

enum _Motion { twinkle, bob, flutter, drift, turn, glow }

/// One part: [asset] (its pixel [aspect], width over height) of [size]
/// picture diameters, at ([x], [y]) in pair units — x along the pair (−1 and
/// 1 are the two picture centres), y away from the line ("up", in picture
/// radii) — moving by [motion], [phase] into the loop, [cycles] times per
/// loop. Shown from CP level [from] up to [until].
class _Part {
  const new(
    this.asset,
    this.aspect,
    this.motion, {
    required this.x,
    required this.y,
    required this.size,
    this.phase = 0,
    this.cycles = 1,
    this.from = 1,
    this.until = 6,
  });

  final String asset;
  final double aspect;
  final _Motion motion;
  final double x;
  final double y;
  final double size;
  final double phase;
  final int cycles;
  final int from;
  final int until;
}

const _fx = 'assets/live_cp_seats/fx';

/// Every part by priority (the budget keeps the first ones). Aspects are the
/// files' pixel sizes.
const _parts = <_Part>[
  _Part(
    '$_fx/sparkle_pink.webp',
    39 / 41,
    _Motion.twinkle,
    x: -0.55,
    y: 1.24,
    size: 0.26,
  ),
  _Part(
    '$_fx/heart_pink.webp',
    89 / 81,
    _Motion.twinkle,
    x: 0,
    y: 1.2,
    size: 0.25,
    phase: 0.33,
    until: 3,
  ),
  _Part(
    '$_fx/heart_glow.webp',
    101 / 129,
    _Motion.glow,
    x: 0,
    y: 1.18,
    size: 0.2,
    phase: 0.33,
    from: 4,
  ),
  _Part(
    '$_fx/sparkle_small.webp',
    32 / 38,
    _Motion.twinkle,
    x: 0.55,
    y: 1.28,
    size: 0.18,
    phase: 0.66,
    cycles: 2,
  ),
  _Part(
    '$_fx/planet.webp',
    197 / 173,
    _Motion.bob,
    x: 0.98,
    y: 1.3,
    size: 0.22,
    from: 2,
    until: 2,
  ),
  _Part(
    '$_fx/butterfly_pink.webp',
    120 / 106,
    _Motion.flutter,
    x: 0,
    y: 1.33,
    size: 0.17,
    from: 3,
  ),
  _Part(
    '$_fx/petal_a.webp',
    46 / 41,
    _Motion.drift,
    x: -0.1,
    y: 1.1,
    size: 0.13,
    from: 4,
  ),
  _Part(
    '$_fx/swirl_l.webp',
    171 / 126,
    _Motion.turn,
    x: -0.1,
    y: 0.45,
    size: 0.26,
    from: 5,
  ),
  _Part(
    '$_fx/swirl_r.webp',
    242 / 145,
    _Motion.turn,
    x: 0.1,
    y: -0.45,
    size: 0.26,
    phase: 0.5,
    from: 5,
  ),
  _Part(
    '$_fx/butterfly_lilac.webp',
    112 / 111,
    _Motion.flutter,
    x: 0,
    y: 1.33,
    size: 0.16,
    phase: 0.5,
    from: 5,
  ),
  _Part(
    '$_fx/heart_violet.webp',
    68 / 62,
    _Motion.twinkle,
    x: -1,
    y: 1.3,
    size: 0.19,
    phase: 0.5,
    from: 2,
  ),
  _Part(
    '$_fx/sparkle_gold.webp',
    64 / 67,
    _Motion.twinkle,
    x: -0.3,
    y: 1.36,
    size: 0.19,
    phase: 0.2,
    from: 3,
  ),
  _Part(
    '$_fx/platform.webp',
    240 / 164,
    _Motion.glow,
    x: 0,
    y: -0.62,
    size: 0.42,
    from: 6,
  ),
  _Part(
    '$_fx/sparkle_big.webp',
    78 / 95,
    _Motion.twinkle,
    x: 1,
    y: 1.32,
    size: 0.22,
    phase: 0.8,
    from: 6,
  ),
  _Part(
    '$_fx/petal_b.webp',
    86 / 40,
    _Motion.drift,
    x: 0.12,
    y: 1.1,
    size: 0.15,
    phase: 0.5,
    from: 4,
  ),
  _Part(
    '$_fx/petal_c.webp',
    38 / 30,
    _Motion.drift,
    x: 0,
    y: 1.1,
    size: 0.11,
    phase: 0.25,
    from: 5,
  ),
  _Part(
    '$_fx/sparkle_gold_small.webp',
    31 / 38,
    _Motion.twinkle,
    x: 0.3,
    y: 1.38,
    size: 0.15,
    phase: 0.4,
    cycles: 2,
    from: 2,
  ),
  _Part(
    '$_fx/sparkle_pink2.webp',
    40 / 43,
    _Motion.twinkle,
    x: -1,
    y: -1.15,
    size: 0.16,
    phase: 0.9,
    from: 6,
  ),
];

/// A part's pose at loop position `t`: where (pair units), how large
/// (× its size), its turn and its opacity.
typedef _Pose = ({
  double x,
  double y,
  double scaleX,
  double scaleY,
  double turn,
  double opacity,
});

_Pose _pose(_Part p, double t) {
  final u = (t * p.cycles + p.phase) % 1;
  final wave = math.sin(2 * math.pi * u);
  switch (p.motion) {
    case _Motion.twinkle:
      final s = math.sin(math.pi * u);
      return (
        x: p.x,
        y: p.y,
        scaleX: 0.55 + 0.45 * s,
        scaleY: 0.55 + 0.45 * s,
        turn: 0.15 * wave,
        opacity: s,
      );
    case _Motion.glow:
      return (
        x: p.x,
        y: p.y,
        scaleX: 0.92 + 0.08 * wave,
        scaleY: 0.92 + 0.08 * wave,
        turn: 0,
        opacity: 0.75 + 0.25 * wave,
      );
    case _Motion.bob:
      return (
        x: p.x,
        y: p.y + 0.06 * wave,
        scaleX: 1,
        scaleY: 1,
        turn: 0.08 * wave,
        opacity: 1,
      );
    case _Motion.flutter:
      // A loose loop over the pair; the wings beat (a horizontal squeeze).
      final angle = 2 * math.pi * u;
      final flap = math.sin(2 * math.pi * u * 12).abs();
      return (
        x: 0.9 * math.cos(angle),
        y: p.y + 0.04 * math.sin(2 * angle),
        scaleX: 0.55 + 0.45 * flap,
        scaleY: 1,
        turn: -0.2 * math.sin(angle),
        opacity: 1,
      );
    case _Motion.drift:
      // Down the gap between the pictures, swaying, fading in and out.
      return (
        x: p.x + 0.08 * math.sin(2 * math.pi * u * 2),
        y: p.y - 1.6 * u,
        scaleX: 1,
        scaleY: 1,
        turn: 2 * math.pi * u,
        opacity: math.sin(math.pi * u),
      );
    case _Motion.turn:
      // A slow sway around the ornament, breathing in and out.
      return (
        x: p.x + 0.05 * wave,
        y: p.y,
        scaleX: 1,
        scaleY: 1,
        turn: 0.35 * wave,
        opacity: 0.35 + 0.35 * (1 + wave) / 2,
      );
  }
}

class _CpPairFxState extends State<CpPairFx>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: CpPairFx.period,
    value: CpPairFx.stillAt,
  );

  /// The parts kept for this pair (level, budget, clear of obstacles).
  late List<_Part> _kept;

  /// The hearts and sparkles the ornament lets out that stay clear.
  late List<_Emit> _emits;

  @override
  void initState() {
    super.initState();
    _kept = _select();
    _emits = _selectEmits();
  }

  @override
  void didUpdateWidget(CpPairFx old) {
    super.didUpdateWidget(old);
    if (old.level != widget.level ||
        old.a != widget.a ||
        old.b != widget.b ||
        old.picture != widget.picture ||
        old.area != widget.area ||
        old.budget != widget.budget ||
        old.ornament != widget.ornament ||
        !identical(old.obstacles, widget.obstacles)) {
      _kept = _select();
      _emits = _selectEmits();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = !CpPairFx.animate || MediaQuery.disableAnimationsOf(context);
    if (still) {
      _controller
        ..stop()
        ..value = CpPairFx.stillAt;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The pair's frame: the midpoint, the unit vector along the pair and the
  /// one away from it (screen-up when the pair lies flat).
  ({Offset mid, Offset along, Offset up, double half, double radius})
  get _frame {
    final d = widget.b - widget.a;
    final length = d.distance;
    final along = length == 0
        ? const Offset(1, 0)
        : Offset(d.dx / length, d.dy / length);
    var up = Offset(along.dy, -along.dx);
    if (up.dy > 0 || (up.dy == 0 && up.dx > 0)) up = -up;
    return (
      mid: Offset.lerp(widget.a, widget.b, 0.5)!,
      along: along,
      up: up,
      half: length / 2,
      radius: widget.picture / 2,
    );
  }

  /// A part's box at loop position [t], in the stage's coordinates (the
  /// largest it gets: unscaled, turned boxes bounded by their diagonal).
  Rect _box(_Part p, double t) {
    final f = _frame;
    final pose = _pose(p, t);
    final c = f.mid + f.along * (pose.x * f.half) + f.up * (pose.y * f.radius);
    final w = p.size * widget.picture;
    final h = w / p.aspect;
    // Petals spin: the box any turn of them fits in (they are small and
    // roundish); others tilt a little.
    final side = p.motion == _Motion.drift ? math.max(w, h) * 1.05 : null;
    // A small tilt grows the box a little.
    return Rect.fromCenter(
      center: c,
      width: side ?? w * 1.1,
      height: side ?? h * 1.1,
    );
  }

  List<_Part> _select() {
    final level = widget.level.clamp(1, 6);
    final kept = <_Part>[];
    for (final p in _parts) {
      if (kept.length >= widget.budget) break;
      if (level < p.from || level > p.until) continue;
      var clear = true;
      for (var i = 0; i < 24 && clear; i++) {
        final box = _box(p, i / 24);
        if (!_inside(widget.area, box) ||
            widget.obstacles.any((o) => o.overlaps(box))) {
          clear = false;
        }
      }
      if (clear) kept.add(p);
    }
    return kept;
  }

  /// An emitted part's box at loop position [t] (stage coordinates).
  Rect _emitBox(_Emit e, Rect o, double t) {
    final pose = _emitPose(e, o, t);
    final w = e.size * o.height;
    return Rect.fromCenter(center: pose.$1, width: w * 1.1, height: w * 1.1);
  }

  List<_Emit> _selectEmits() {
    final o = widget.ornament;
    if (o == null) return const [];
    return [
      for (final e in _emitted)
        if (List.generate(16, (i) => i / 16).every((t) {
          final pose = _emitPose(e, o, t);
          if (pose.$2 <= 0.01) return true;
          final box = _emitBox(e, o, t);
          return _inside(widget.ornamentBounds ?? widget.area, box) &&
              !widget.obstacles.any((x) => x.overlaps(box));
        }))
          e,
    ];
  }

  static bool _inside(Rect outer, Rect r) =>
      r.left >= outer.left - 0.01 &&
      r.top >= outer.top - 0.01 &&
      r.right <= outer.right + 0.01 &&
      r.bottom <= outer.bottom + 0.01;

  @override
  Widget build(BuildContext context) {
    final ornament = widget.ornament;
    if (_kept.isEmpty && ornament == null) return const SizedBox.shrink();
    final origin = widget.area.topLeft;
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final f = _frame;
            final t = _controller.value;
            final beat = cpHeartbeat(t);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                ExcludeSemantics(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final p in _kept) _part(p, t, f, origin),
                      if (ornament != null) ...[
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _BeamPainter(
                              segments: _beams(ornament, origin),
                              t: t,
                              width: widget.picture * 0.09,
                            ),
                          ),
                        ),
                        _halo(ornament.shift(-origin), beat),
                      ],
                    ],
                  ),
                ),
                if (ornament != null)
                  Positioned.fromRect(
                    key: widget.ornamentKey,
                    rect: ornament.shift(-origin),
                    child: Transform.scale(
                      scale: 1 + cpBeatScale * beat,
                      child: widget.ornamentChild ?? const SizedBox.shrink(),
                    ),
                  ),
                if (ornament != null)
                  ExcludeSemantics(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final e in _emits) _emit(e, ornament, t, origin),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// From each partner's picture edge toward the ornament (local).
  List<(Offset, Offset)> _beams(Rect o, Offset origin) {
    final r = widget.picture / 2;
    final c = o.center;
    return [
      for (final p in [widget.a, widget.b])
        if ((c - p).distance > r + 6 + o.width * 0.3)
          () {
            final d = c - p;
            final u = d / d.distance;
            return (p + u * (r + 3) - origin, c - u * (o.width * 0.3) - origin);
          }(),
    ];
  }

  /// The heartbeat glow behind the ornament (local box [o]).
  Widget _halo(Rect o, double beat) => Positioned.fromRect(
    rect: o,
    child: Transform.scale(
      scale: (1 + cpBeatScale * beat) * 1.2,
      child: Opacity(
        opacity: (0.7 + 0.3 * beat).clamp(0, 1).toDouble(),
        child: const DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0xE6FFC8E6), Color(0x99FF6FB1), Color(0x00FF6FB1)],
              stops: [0, 0.55, 1],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _emit(_Emit e, Rect o, double t, Offset origin) {
    final (c, opacity) = _emitPose(e, o, t);
    final w = e.size * o.height;
    final local = c - origin;
    return Positioned(
      left: local.dx - w / 2,
      top: local.dy - w / 2,
      width: w,
      height: w,
      child: Opacity(
        opacity: opacity,
        child: Image.asset(
          e.asset,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _part(
    _Part p,
    double t,
    ({Offset mid, Offset along, Offset up, double half, double radius}) f,
    Offset origin,
  ) {
    final pose = _pose(p, t);
    final c =
        f.mid +
        f.along * (pose.x * f.half) +
        f.up * (pose.y * f.radius) -
        origin;
    final w = p.size * widget.picture;
    final h = w / p.aspect;
    return Positioned(
      left: c.dx - w / 2,
      top: c.dy - h / 2,
      width: w,
      height: h,
      child: Opacity(
        opacity: pose.opacity.clamp(0, 1).toDouble(),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..rotateZ(pose.turn)
            ..scaleByDouble(pose.scaleX, pose.scaleY, 1, 1),
          child: Image.asset(
            p.asset,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// How much the ornament grows on a heartbeat.
const cpBeatScale = 0.08;

/// The heartbeat at loop position [t]: two beats then rest, four times a
/// loop; 0 at rest, about 1 at a beat.
double cpHeartbeat(double t) {
  final p = (t * 4) % 1;
  double bump(double c) => math.exp(-math.pow((p - c) / 0.045, 2).toDouble());
  return (bump(0.12) + 0.75 * bump(0.32)).clamp(0, 1).toDouble();
}

/// A heart or sparkle the ornament lets out: rising from its top, drifting
/// sideways by [drift] ornament widths, [size] ornament heights.
class _Emit {
  const new(this.asset, {required this.size, this.phase = 0, this.drift = 0});

  final String asset;
  final double size;
  final double phase;
  final double drift;
}

const _emitted = <_Emit>[
  _Emit('$_fx/heart_pink.webp', size: 0.3, drift: -0.18),
  _Emit('$_fx/sparkle_pink.webp', size: 0.26, phase: 0.4, drift: 0.2),
  _Emit('$_fx/heart_violet.webp', size: 0.26, phase: 0.7, drift: 0.05),
];

/// Where an emitted part is at [t] and how visible: it rises for the first
/// half of each of its two cycles a loop, and rests (hidden) the other half.
(Offset, double) _emitPose(_Emit e, Rect o, double t) {
  final u = (t * 2 + e.phase) % 1;
  if (u > 0.5) return (o.topCenter, 0);
  final k = u / 0.5;
  final c =
      o.center + Offset(e.drift * o.width * k, -o.height * (0.15 + 0.6 * k));
  return (c, math.sin(math.pi * k));
}

/// The link shimmer: a faint line from each partner toward the ornament
/// with a bright streak flowing along it.
class _BeamPainter extends CustomPainter {
  const new({required this.segments, required this.t, required this.width});

  final List<(Offset, Offset)> segments;
  final double t;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (from, to) in segments) {
      final base = Paint()
        ..color = const Color(0x55FFD6EC)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.6);
      canvas.drawLine(from, to, base);
      for (final shift in [0.0, 0.5]) {
        final p = (t * 3 + shift) % 1;
        final head = Offset.lerp(from, to, p)!;
        final tail = Offset.lerp(from, to, math.max(0, p - 0.3))!;
        if ((head - tail).distance < 0.5) continue;
        final streak = Paint()
          ..shader = ui.Gradient.linear(tail, head, const [
            Color(0x00FFFFFF),
            Color(0xEEFFF0F8),
          ])
          ..strokeWidth = width * 1.2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(tail, head, streak);
      }
    }
  }

  @override
  bool shouldRepaint(_BeamPainter old) =>
      old.t != t || old.segments != segments || old.width != width;
}
