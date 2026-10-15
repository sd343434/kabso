import 'package:kabso_live/design_system/theme/app_theme.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:material_ui/material_ui.dart';

enum KButtonVariant { primary, secondary, ghost, destructive }

/// Token-driven button. Height 52 (`size.buttonHeight`), never smaller than
/// the 48dp touch target. While [loading], it shows a spinner, ignores taps
/// and announces itself as busy.
class KButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = KButtonVariant.primary,
    this.loading = false,
    this.icon,
    this.expand = true,
  });

  final String label;

  /// `null` disables the button.
  final VoidCallback? onPressed;
  final KButtonVariant variant;
  final bool loading;
  final IconData? icon;

  /// Stretch to the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = context.textStyles;
    final enabled = onPressed != null && !loading;

    final (Color bg, Color fg, BorderSide side) = switch (variant) {
      KButtonVariant.primary => (p.primary, p.onPrimary, BorderSide.none),
      KButtonVariant.secondary => (
        p.surfaceRaised,
        p.textPrimary,
        BorderSide(color: p.border),
      ),
      KButtonVariant.ghost => (Colors.transparent, p.primary, BorderSide.none),
      KButtonVariant.destructive => (p.error, p.onPrimary, BorderSide.none),
    };

    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(KSizes.minTouchTarget, KSizes.buttonHeight),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsetsDirectional.symmetric(horizontal: KSpacing.xl),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(KRadius.md)),
      ),
      side: WidgetStatePropertyAll(side),
      elevation: const WidgetStatePropertyAll(0),
      textStyle: WidgetStatePropertyAll(text.bodyStrong),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) && !loading
            ? bg.withValues(alpha: bg.a * 0.4)
            : bg,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) && !loading
            ? fg.withValues(alpha: 0.5)
            : fg,
      ),
      overlayColor: WidgetStatePropertyAll(fg.withValues(alpha: 0.08)),
    );

    final child = loading
        ? SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: KSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          );

    // TextButton provides the button semantics (role, enabled, tap action);
    // while loading the label is kept for screen readers.
    final button = TextButton(
      onPressed: enabled ? onPressed : null,
      style: style,
      child: loading ? Semantics(label: label, child: child) : child,
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
