import 'package:kabso_live/app/shell/coming_soon_tab.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Create — photo posts arrive in Phase 3, short videos in Phase 5.
class CreateScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ComingSoonTab(
      title: l10n.navCreate,
      icon: Icons.add_photo_alternate_outlined,
      headline: l10n.createComingTitle,
      message: l10n.createComingBody,
    );
  }
}
