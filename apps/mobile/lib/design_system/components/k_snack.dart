import 'package:kabso_live/design_system/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

/// SnackBar helpers using token colors.
abstract final class KSnack {
  static void success(BuildContext context, String message) => _show(
    context,
    message,
    Icons.check_circle_outline,
    context.palette.success,
  );

  static void error(BuildContext context, String message) =>
      _show(context, message, Icons.error_outline, context.palette.error);

  static void info(BuildContext context, String message) =>
      _show(context, message, Icons.info_outline, context.palette.info);

  static void _show(
    BuildContext context,
    String message,
    IconData icon,
    Color color,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              ExcludeSemantics(child: Icon(icon, color: color)),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
