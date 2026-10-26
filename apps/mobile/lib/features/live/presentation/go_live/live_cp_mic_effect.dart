import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Owner D115 (the CP privilege `MIC_EFFECT`, CP level 3): while a seated
/// partner of such a couple speaks, their picture's normal speaking glow is
/// replaced by the couple mic effect, unmistakable at a glance (owner:
/// "stronger and clearer"):
///
/// - three concentric rings, pink to purple, ~3 pt thick, spreading from the
///   picture's edge (1.0 ×) to 1.45 × its radius and fading, staggered;
/// - a bright pink glow ring hugging the picture's edge, pulsing;
/// - hearts (the owner's `heart_pink` / `heart_violet` parts, 10–14 pt)
///   rising on both sides, 4–6 in view at a time;
/// - the owner's privilege art (`assets/cp_space/privilege_mic.webp`) as an
///   ~18 pt badge at the picture's top corner (the mic-off badge keeps the
///   bottom corner and stays on top).
///
/// It may spread over the tile's free space and the ring art but stays in
/// [area] (the tile, from [area]'s top down to the name's top, given around
/// the picture's centre): never over the name or another seat. The bottom
/// edge fades instead of ending on a straight cut. One controller per
/// speaking seat inside [RepaintBoundary]s, [IgnorePointer]. With reduced
/// motion (`MediaQuery.disableAnimations`) or [animate] off (widget tests
/// and goldens) it holds still at [stillAt], its brightest moment.
class CpMicEffect extends StatefulWidget {
  const new({
    required this.size,
    required this.child,
    required this.area,
    super.key,
  });

  /// The picture's diameter; [child] is the (clipped) picture.
  final double size;
  final Widget child;

  /// Where the effect may show, relative to the picture's centre.
  final Rect area;

  /// One cycle of the rings.
  static const period = Duration(milliseconds: 2400);

  /// The rings' largest radius, in picture radii.
  static const reach = 1.45;

  /// The privilege art shown as the badge, and the hearts' art.
  static const badge = 'assets/cp_space/privilege_mic.webp';
  static const heartPink = 'assets/live_cp_seats/fx/heart_pink.webp';
  static const heartViolet = 'assets/live_cp_seats/fx/heart_violet.webp';

  /// Off in widget tests and goldens (`test/flutter_test_config.dart`).
  static bool animate = true;

  /// The loop position shown when not animating: the glow at its brightest,
  /// the rings spread out.
  static double stillAt = 0.125;

  static const effectKey = Key('cpMicEffect');

  @override
  State<CpMicEffect> createState() => _CpMicEffectState();
}

class _CpMicEffectState extends State<CpMicEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: CpMicEffect.period,
    value: CpMicEffect.stillAt,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still =
        !CpMicEffect.animate || MediaQuery.disableAnimationsOf(context);
    if (still) {
      _controller
        ..stop()
        ..value = CpMicEffect.stillAt;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// [child] shown only within the area, its bottom fading out over a few
  /// points (it ends above the name).
  Widget _inArea(Widget child) {
    final area = widget.area;
    final r = widget.size / 2;
    final fade = math.min(4, area.height / 6) / area.height;
    return Positioned(
      left: r + area.left,
      top: r + area.top,
      width: area.width,
      height: area.height,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [
                  Color(0xFFFFFFFF),
                  Color(0xFFFFFFFF),
                  Color(0x00FFFFFF),
                ],
                stops: [0, 1 - fade, 1],
              ).createShader(bounds),
              child: ClipRect(child: child),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final area = widget.area;
    final centre = -area.topLeft;
    final badge = size * 0.36;
    return SizedBox.square(
      key: CpMicEffect.effectKey,
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          _inArea(
            CustomPaint(
              size: area.size,
              painter: _MicRings(_controller, centre: centre, radius: size / 2),
            ),
          ),
          widget.child,
          _inArea(
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final h in _hearts) _heart(h, _controller.value, centre),
                ],
              ),
            ),
          ),
          PositionedDirectional(
            top: -badge * 0.3,
            end: -badge * 0.3,
            width: badge,
            height: badge,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Image.asset(
                  CpMicEffect.badge,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A heart rising beside the picture (local to the area, [centre] the
  /// picture's centre there).
  Widget _heart(_Heart h, double t, Offset centre) {
    final u = (t + h.phase) % 1;
    final r = widget.size / 2;
    final side = widget.size * h.size;
    final cx = centre.dx + h.x * r + math.sin(u * 2 * math.pi) * r * 0.08;
    final cy = centre.dy + r * (0.7 - 2.1 * u);
    return Positioned(
      left: cx - side / 2,
      top: cy - side / 2,
      width: side,
      height: side,
      child: Opacity(
        opacity: math.sin(math.pi * u).clamp(0, 1).toDouble(),
        child: Transform.rotate(
          angle: 0.25 * math.sin(u * 4 * math.pi),
          child: Image.asset(
            h.violet ? CpMicEffect.heartViolet : CpMicEffect.heartPink,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Icon(
              Icons.favorite_rounded,
              size: side,
              color: h.violet
                  ? const Color(0xFFB58CFF)
                  : const Color(0xFFFF6FB1),
            ),
          ),
        ),
      ),
    );
  }
}

/// A rising heart: [x] sideways (picture radii), [size] in picture
/// diameters, [phase] into its loop.
class _Heart {
  const new(
    this.x, {
    required this.size,
    required this.phase,
    this.violet = false,
  });

  final double x;
  final double size;
  final double phase;
  final bool violet;
}

/// Three on each side (both hands of the picture), staggered so 4–6 show.
const _hearts = <_Heart>[
  _Heart(-1.12, size: 0.26, phase: 0),
  _Heart(1.12, size: 0.24, phase: 0.17, violet: true),
  _Heart(-1.18, size: 0.22, phase: 0.33, violet: true),
  _Heart(1.18, size: 0.28, phase: 0.5),
  _Heart(-1.1, size: 0.24, phase: 0.67),
  _Heart(1.1, size: 0.22, phase: 0.83, violet: true),
];

/// The glow ring hugging the picture and the spreading rings.
class _MicRings extends CustomPainter {
  new(this.animation, {required this.centre, required this.radius})
    : super(repaint: animation);

  final Animation<double> animation;
  final Offset centre;
  final double radius;

  static const _pink = Color(0xFFFF4FA3);
  static const _purple = Color(0xFFA066FF);

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final stroke = radius * 0.12;
    for (var i = 0; i < 3; i++) {
      final u = (t + i / 3) % 1;
      final r = radius * (1 + (CpMicEffect.reach - 1) * u);
      final alpha = (1 - u).clamp(0, 1).toDouble();
      final color = Color.lerp(_pink, _purple, u)!;
      canvas
        ..drawCircle(
          centre,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke * 2.2
            ..color = color.withValues(alpha: 0.35 * alpha)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke),
        )
        ..drawCircle(
          centre,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke * (1 - 0.4 * u)
            ..color = color.withValues(alpha: 0.95 * alpha),
        );
    }
    // The glow ring on the picture's edge, pulsing twice a loop.
    final pulse = math.sin(t * 4 * math.pi).abs();
    canvas
      ..drawCircle(
        centre,
        radius + stroke * 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * (2.2 + 1.4 * pulse)
          ..color = _pink.withValues(alpha: 0.55 + 0.4 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 1.2),
      )
      ..drawCircle(
        centre,
        radius + stroke * 0.4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 0.9
          ..color = const Color(0xFFFFC2E0)
              .withValues(alpha: 0.7 + 0.3 * pulse),
      );
  }

  @override
  bool shouldRepaint(_MicRings old) =>
      old.animation != animation ||
      old.centre != centre ||
      old.radius != radius;
}
