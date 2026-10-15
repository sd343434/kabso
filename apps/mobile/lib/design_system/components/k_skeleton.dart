import 'package:kabso_live/design_system/theme/app_theme.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Loading placeholder with a shimmer. When the platform asks to reduce
/// motion the placeholder is static.
class KSkeleton extends StatefulWidget {
  const new({
    super.key,
    this.width,
    this.height = 16,
    this.radius = KRadius.sm,
    this.circle = false,
  });

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  State<KSkeleton> createState() => _KSkeletonState();
}

class _KSkeletonState extends State<KSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _controller.stop();
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
  Widget build(BuildContext context) {
    final p = context.palette;
    final base = p.surfaceRaised;
    final highlight = p.surfaceOverlay;
    final shape = BoxDecoration(
      color: base,
      shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: widget.circle ? null : BorderRadius.circular(widget.radius),
    );
    final box = SizedBox(
      width: widget.circle ? widget.height : widget.width,
      height: widget.height,
    );

    if (MediaQuery.disableAnimationsOf(context)) {
      return ExcludeSemantics(
        child: DecoratedBox(decoration: shape, child: box),
      );
    }

    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value * 2 - 0.5;
          return DecoratedBox(
            decoration: shape.copyWith(
              gradient: LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: [base, highlight, base],
                stops: [
                  (t - 0.3).clamp(0.0, 1.0),
                  t.clamp(0.0, 1.0),
                  (t + 0.3).clamp(0.0, 1.0),
                ],
              ),
            ),
            child: child,
          );
        },
        child: box,
      ),
    );
  }
}
