import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// D233 (owner 2026-11-01: «بطاقات الزيارات اجعلهم مثل الصاروخ ب ٤ مراحل …
/// واجعل لكل بطاقة أيقونة … مختلفة وإطار متحرك … بلون المميز»): the visit
/// card is a rocket of four stages, «صاروخ 1 · 2 · 3 · 4».
///
/// The art is Kabso's own: vector shapes drawn in code here (no asset, no
/// third-party art; PROVENANCE in docs/AI_WORKFORCE_BOARD.md D233). Each stage
/// is one distinct rocket that grows in grandeur — body colour, fins, the
/// number of bands on the body (= the stage), a longer and hotter flame,
/// a halo from stage 3 and gold with sparkles at stage 4.
abstract final class KRocketStages {
  /// Stages on sale (the server's `LiveBoostOption.stage`, 1–4).
  static const int count = 4;

  /// The featured «مميز» accent (the hub's label gradient, D154b).
  static const Color accent = Color(0xFFFFD36E);
  static const Color accentDeep = Color(0xFFF2A93B);

  /// A stage in 1 … [count] (anything else reads as the nearest).
  static int clamp(int stage) => stage.clamp(1, count);
}

/// The rocket of [stage] (1–4) in a [size] square. Decorative: callers
/// label it ("Rocket 2").
class KRocketArt extends StatelessWidget {
  const new({required this.stage, super.key, this.size = 48});

  final int stage;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: KRocketPainter(stage: KRocketStages.clamp(stage)),
      ),
    ),
  );
}

/// Paints one rocket on a 100 × 100 design grid scaled to the canvas.
class KRocketPainter extends CustomPainter {
  new({required this.stage});

  final int stage;

  static const _looks = <_Look>[
    // 1: a small white rocket with teal fins and a short flame.
    _Look(
      body: [Color(0xFFFFFFFF), Color(0xFFC9D3DC)],
      trim: [Color(0xFF3FE3D2), Color(0xFF119C90)],
      window: Color(0xFF1C8FD6),
      flame: [Color(0xFFFFE27A), Color(0xFFFF9E3D)],
      flameLength: 15,
      scale: 0.78,
      halo: null,
    ),
    // 2: orange trim, a longer flame.
    _Look(
      body: [Color(0xFFFFFFFF), Color(0xFFD5D9E0)],
      trim: [Color(0xFFFFA25A), Color(0xFFE2541F)],
      window: Color(0xFF2B7BE4),
      flame: [Color(0xFFFFEA8A), Color(0xFFFF6A2B)],
      flameLength: 20,
      scale: 0.85,
      halo: null,
    ),
    // 3: violet-magenta trim, a two-tone flame and a soft glow.
    _Look(
      body: [Color(0xFFF7F2FF), Color(0xFFC9BEE6)],
      trim: [Color(0xFFD86BFF), Color(0xFF7B2FD9)],
      window: Color(0xFFFF5FA8),
      flame: [Color(0xFFFFF3A8), Color(0xFFFF4F7A)],
      flameLength: 25,
      scale: 0.92,
      halo: Color(0x66B45CFF),
    ),
    // 4: a gold rocket with a ruby nose, the biggest flame, a gold halo
    // and sparkles.
    _Look(
      body: [Color(0xFFFFF1B8), Color(0xFFE8A43A)],
      trim: [Color(0xFFFF5A5F), Color(0xFFB0122E)],
      window: Color(0xFF7A1FD6),
      flame: [Color(0xFFFFFFFF), Color(0xFFFFB13D)],
      flameLength: 31,
      scale: 1,
      halo: Color(0x88FFD36E),
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final look = _looks[stage - 1];
    canvas
      ..save()
      ..scale(size.width / 100, size.height / 100);
    if (look.halo case final halo?) {
      canvas.drawCircle(
        const Offset(50, 50),
        46,
        Paint()
          ..shader = RadialGradient(colors: [halo, halo.withValues(alpha: 0)])
              .createShader(
                Rect.fromCircle(center: const Offset(50, 50), radius: 46),
              ),
      );
    }
    // Tilted a little: flying up and to the right.
    canvas
      ..translate(50, 50)
      ..rotate(math.pi / 9)
      ..scale(look.scale)
      ..translate(-50, -50);
    _flame(canvas, look);
    _fins(canvas, look);
    _body(canvas, look);
    canvas.restore();
    if (stage == 4) _sparkles(canvas, size);
  }

  void _flame(Canvas canvas, _Look look) {
    final l = look.flameLength;
    Path flame(double width, double length) => Path()
      ..moveTo(50 - width, 72)
      ..quadraticBezierTo(50 - width * 0.9, 72 + length * 0.55, 50, 72 + length)
      ..quadraticBezierTo(50 + width * 0.9, 72 + length * 0.55, 50 + width, 72)
      ..close();
    const rect = Rect.fromLTWH(30, 70, 40, 34);
    canvas
      ..drawPath(
        flame(11, l),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [look.flame[1], look.flame[1].withValues(alpha: 0)],
          ).createShader(rect),
      )
      ..drawPath(
        flame(7, l * 0.72),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [look.flame[0], look.flame[1].withValues(alpha: 0.2)],
          ).createShader(rect),
      );
    if (stage >= 3) {
      canvas.drawPath(
        flame(3.5, l * 0.45),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.9),
      );
    }
  }

  void _fins(Canvas canvas, _Look look) {
    final paint = Paint()
      ..shader = LinearGradient(colors: look.trim)
          .createShader(const Rect.fromLTWH(20, 50, 60, 26));
    final spread = 6.0 + stage * 1.5;
    final left = Path()
      ..moveTo(38, 50)
      ..quadraticBezierTo(38 - spread, 58, 38 - spread, 74)
      ..lineTo(39, 68)
      ..close();
    final right = Path()
      ..moveTo(62, 50)
      ..quadraticBezierTo(62 + spread, 58, 62 + spread, 74)
      ..lineTo(61, 68)
      ..close();
    canvas
      ..drawPath(left, paint)
      ..drawPath(right, paint);
    if (stage >= 3) {
      // A middle fin seen edge-on.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(48, 58, 4, 17),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  void _body(Canvas canvas, _Look look) {
    final body = Path()
      ..moveTo(50, 6)
      ..cubicTo(60, 14, 64, 28, 63, 44)
      ..lineTo(61, 70)
      ..quadraticBezierTo(50, 74, 39, 70)
      ..lineTo(37, 44)
      ..cubicTo(36, 28, 40, 14, 50, 6)
      ..close();
    const box = Rect.fromLTWH(36, 6, 28, 68);
    canvas
      ..drawPath(
        body,
        Paint()
          ..shader = LinearGradient(
            colors: [look.body[1], look.body[0], look.body[0], look.body[1]],
            stops: const [0, 0.35, 0.55, 1],
          ).createShader(box),
      )
      ..save()
      ..clipPath(body)
      // The nose cap.
      ..drawRect(
        const Rect.fromLTWH(30, 0, 40, 21),
        Paint()..shader = LinearGradient(colors: look.trim).createShader(box),
      );
    // Bands on the lower body: one per stage.
    final band = Paint()
      ..shader = LinearGradient(colors: look.trim).createShader(box);
    for (var i = 0; i < stage; i++) {
      canvas.drawRect(Rect.fromLTWH(30, 64 - i * 4.2, 40, 2.2), band);
    }
    // The window: a rim, the glass, a glint.
    canvas
      ..restore()
      ..drawCircle(
        const Offset(50, 36),
        8.5,
        Paint()..shader = LinearGradient(colors: look.trim).createShader(box),
      )
      ..drawCircle(
        const Offset(50, 36),
        6,
        Paint()
          ..shader =
              RadialGradient(
                center: const Alignment(-0.4, -0.4),
                colors: [
                  Color.lerp(look.window, const Color(0xFFFFFFFF), 0.55)!,
                  look.window,
                ],
              ).createShader(
                Rect.fromCircle(center: const Offset(50, 36), radius: 6),
              ),
      )
      ..drawCircle(
        const Offset(47.6, 33.6),
        1.8,
        Paint()..color = const Color(0xCCFFFFFF),
      )
      // A light stripe down the body (volume).
      ..drawPath(
        Path()
          ..moveTo(45, 18)
          ..quadraticBezierTo(41.5, 40, 43, 64)
          ..lineTo(44.6, 64)
          ..quadraticBezierTo(43.5, 40, 46.6, 18)
          ..close(),
        Paint()..color = const Color(0x66FFFFFF),
      )
      ..drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0x40000000),
      );
  }

  void _sparkles(Canvas canvas, Size size) {
    final s = size.width / 100;
    final paint = Paint()..color = const Color(0xFFFFF4C2);
    for (final (x, y, r) in const [
      (14.0, 22.0, 6.0),
      (86.0, 30.0, 4.5),
      (20.0, 80.0, 4.0),
      (84.0, 76.0, 5.5),
    ]) {
      final c = Offset(x * s, y * s);
      final a = r * s;
      final b = a * 0.28;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - a)
          ..quadraticBezierTo(c.dx + b, c.dy - b, c.dx + a, c.dy)
          ..quadraticBezierTo(c.dx + b, c.dy + b, c.dx, c.dy + a)
          ..quadraticBezierTo(c.dx - b, c.dy + b, c.dx - a, c.dy)
          ..quadraticBezierTo(c.dx - b, c.dy - b, c.dx, c.dy - a)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(KRocketPainter old) => old.stage != stage;
}

class _Look {
  const new({
    required this.body,
    required this.trim,
    required this.window,
    required this.flame,
    required this.flameLength,
    required this.scale,
    required this.halo,
  });

  final List<Color> body;
  final List<Color> trim;
  final Color window;
  final List<Color> flame;
  final double flameLength;
  final double scale;
  final Color? halo;
}

/// D233 follow-up (owner 2026-11-02: «ضع الصاروخ داخل أيقونة مميز، لكن كل
/// صاروخ يكون له لون أيقونة مميز مختلف»): the look of a stage's «مميز» pill
/// and of its animated card frame. Text on the pill ≥ 4.5:1 on both stops:
/// 1 bronze (dark brown ≥ 4.94:1), 2 silver-blue (navy ≥ 7.35:1), 3 gold
/// (the legacy «مميز» colours, ≥ 7.43:1), 4 royal purple → crimson with a
/// gold edge (white ≥ 7.07:1).
typedef KRocketStyle = ({
  List<Color> pill,
  Color text,
  Color? edge,
  Color ring,
  Color arc,
});

/// The four stage styles; see [KRocketStyle].
abstract final class KRocketStyles {
  static const KRocketStyle bronze = (
    pill: [Color(0xFFF2B27A), Color(0xFFC8722F)],
    text: Color(0xFF2B1300),
    edge: null,
    ring: Color(0xFFC8722F),
    arc: Color(0xFFFFC48E),
  );
  static const KRocketStyle silver = (
    pill: [Color(0xFFE8EEF6), Color(0xFF9DB3D0)],
    text: Color(0xFF0E2340),
    edge: null,
    ring: Color(0xFF8FA9CC),
    arc: Color(0xFFE3F0FF),
  );
  static const KRocketStyle gold = (
    pill: [KRocketStages.accent, KRocketStages.accentDeep],
    text: Color(0xFF3B2200),
    edge: null,
    ring: KRocketStages.accentDeep,
    arc: KRocketStages.accent,
  );
  static const KRocketStyle royal = (
    pill: [Color(0xFF7A22D0), Color(0xFFB0122E)],
    text: Color(0xFFFFFFFF),
    edge: KRocketStages.accent,
    ring: Color(0xFF9B3BE8),
    arc: KRocketStages.accent,
  );

  /// The style of [stage] (clamped to 1–4).
  static KRocketStyle of(int stage) => switch (KRocketStages.clamp(stage)) {
    1 => bronze,
    2 => silver,
    3 => gold,
    _ => royal,
  };
}

/// The hub card's «مميز» pill. With a rocket [stage] (1–4) running: that
/// stage's small rocket at the reading start of the text, in the stage's
/// own colours ([KRocketStyles]); without one (a legacy featured live,
/// [stage] 0): the plain gold pill of D154b.
class KFeaturedPill extends StatelessWidget {
  const new({required this.label, super.key, this.stage = 0});

  final String label;
  final int stage;

  /// The rocket's side inside the pill.
  static const double rocket = 16;

  @override
  Widget build(BuildContext context) {
    final style = stage > 0 ? KRocketStyles.of(stage) : KRocketStyles.gold;
    final edge = stage > 0 ? style.edge : null;
    return Container(
      padding: EdgeInsetsDirectional.only(
        start: stage > 0 ? 3 : 6,
        end: 6,
        top: stage > 0 ? 0.5 : 1.5,
        bottom: stage > 0 ? 0.5 : 1.5,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: style.pill),
        borderRadius: BorderRadius.circular(999),
        border: edge == null ? null : Border.all(color: edge, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (stage > 0) ...[
            KRocketArt(stage: stage, size: rocket),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            maxLines: 1,
            style: DefaultTextStyle.of(context).style.copyWith(
              color: style.text,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// D233: the animated frame around a hub card whose live has a rocket
/// [stage] running — a moving gradient on the border with a glow, tinted in
/// the stage's «مميز» colours ([KRocketStyles]: bronze, silver-blue, gold,
/// royal purple with gold arcs); width, glow, speed and the number of
/// bright arcs grow with the stage (4 is the most premium). Reduce motion
/// (and [animate] off in tests and goldens) holds it still. One ticker per
/// card, repainting only the border's own layer, so a few framed cards stay
/// cheap.
class KBoostFrame extends StatefulWidget {
  const new({required this.stage, super.key, this.radius = 5});

  final int stage;
  final double radius;

  /// Off in widget tests and goldens (a repeating animation never settles).
  static bool animate = true;

  /// The frame's look per stage: border width, glow blur, seconds per turn
  /// and bright arcs.
  static ({double width, double glow, double seconds, int arcs}) specOf(
    int stage,
  ) => switch (KRocketStages.clamp(stage)) {
    1 => (width: 1.5, glow: 0, seconds: 4.0, arcs: 1),
    2 => (width: 2, glow: 2, seconds: 3.4, arcs: 1),
    3 => (width: 2.5, glow: 4, seconds: 2.8, arcs: 2),
    _ => (width: 3, glow: 6, seconds: 2.2, arcs: 3),
  };

  @override
  State<KBoostFrame> createState() => _KBoostFrameState();
}

class _KBoostFrameState extends State<KBoostFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _period,
  );

  Duration get _period => Duration(
    milliseconds: (KBoostFrame.specOf(widget.stage).seconds * 1000).round(),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(KBoostFrame old) {
    super.didUpdateWidget(old);
    if (old.stage != widget.stage) {
      _controller.duration = _period;
      if (_controller.isAnimating) _controller.repeat();
    }
  }

  void _sync() {
    // Read reduce motion first: it registers the dependency, so a change of
    // the setting reaches the frame even while [KBoostFrame.animate] is off.
    final reduce = MediaQuery.disableAnimationsOf(context);
    final still = reduce || !KBoostFrame.animate;
    if (still) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _FramePainter(
          turn: _controller,
          stage: KRocketStages.clamp(widget.stage),
          radius: widget.radius,
        ),
      ),
    ),
  );
}

class _FramePainter extends CustomPainter {
  new({required this.turn, required this.stage, required this.radius})
    : super(repaint: turn);

  final Animation<double> turn;
  final int stage;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final spec = KBoostFrame.specOf(stage);
    final inset = spec.width / 2;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(inset),
      Radius.circular(math.max(0, radius - inset)),
    );
    final style = KRocketStyles.of(stage);
    // The resting ring in the stage's colour.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = spec.width
        ..color = style.ring.withValues(alpha: 0.75),
    );
    // The moving bright arcs: a sweep gradient that turns.
    final bright = style.arc;
    final clear = bright.withValues(alpha: 0);
    final colors = <Color>[];
    final stops = <double>[];
    for (var i = 0; i < spec.arcs; i++) {
      final start = i / spec.arcs;
      final span = 0.5 / spec.arcs;
      colors.addAll([clear, bright, const Color(0xFFFFFFFF), bright, clear]);
      stops.addAll([
        start,
        start + span * 0.35,
        start + span * 0.5,
        start + span * 0.65,
        start + span,
      ]);
    }
    if (stops.last < 1) {
      colors.add(clear);
      stops.add(1);
    }
    final shader = SweepGradient(
      colors: colors,
      stops: stops,
      transform: GradientRotation(turn.value * 2 * math.pi),
    ).createShader(rect);
    if (spec.glow > 0) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = spec.width + spec.glow
          ..shader = shader
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, spec.glow),
      );
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = spec.width
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.stage != stage || old.radius != radius || old.turn != turn;
}
