import 'package:kabso_live/design_system/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

/// SnackBar helpers using token colors.
abstract final class KSnack {
  /// With [actionLabel], the bar carries one action (e.g. Undo). [leading]
  /// replaces the check icon (e.g. an amount with its currency icon).
  static void success(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Widget? leading,
  }) => _show(
    context,
    message,
    Icons.check_circle_outline,
    context.palette.success,
    leading: leading,
    action: actionLabel == null || onAction == null
        ? null
        : SnackBarAction(label: actionLabel, onPressed: onAction),
  );

  static void error(BuildContext context, String message) =>
      _show(context, message, Icons.error_outline, context.palette.error);

  static void info(BuildContext context, String message) =>
      _show(context, message, Icons.info_outline, context.palette.info);

  static void _show(
    BuildContext context,
    String message,
    IconData icon,
    Color color, {
    SnackBarAction? action,
    Widget? leading,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          action: action,
          content: Row(
            children: [
              ExcludeSemantics(child: leading ?? Icon(icon, color: color)),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
