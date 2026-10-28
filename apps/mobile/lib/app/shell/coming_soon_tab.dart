import 'package:kabso_live/design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Honest placeholder for a tab whose feature ships in a later phase.
/// No fake content and no actions that do nothing.
class ComingSoonTab extends StatelessWidget {
  const new({
    required this.title,
    required this.icon,
    required this.headline,
    required this.message,
    super.key,
    this.titleWidget,
  });

  final String title;
  final Widget? titleWidget;
  final IconData icon;
  final String headline;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: KAppBar(title: titleWidget ?? Text(title)),
      body: KEmptyState(icon: icon, title: headline, message: message),
    );
  }
}
