import 'dart:ui' show ImageFilter;

import 'package:kabso_live/design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Frosted glass over a live background (go-live, seat rooms): a blur, a
/// light veil and a thin bright edge.
class LiveGlass extends StatelessWidget {
  const new({
    required this.child,
    super.key,
    this.radius = KRadius.xl,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.glow,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// Colours the veil (a selected state, the theme accent).
  final Color? tint;

  /// A soft outer glow in this colour.
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    final glow = this.glow;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: glow == null
            ? null
            : [BoxShadow(color: glow.withValues(alpha: 0.45), blurRadius: 18)],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: shape,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (tint ?? const Color(0xFFFFFFFF)).withValues(alpha: 0.16),
                  (tint ?? const Color(0xFFFFFFFF)).withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(
                color: (glow ?? const Color(0xFFFFFFFF)).withValues(
                  alpha: glow == null ? 0.18 : 0.7,
                ),
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
