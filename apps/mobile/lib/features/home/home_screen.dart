import 'package:kabso_live/app/shell/coming_soon_tab.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Home feed — arrives in Phase 2.
class HomeScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ComingSoonTab(
      title: l10n.navHome,
      titleWidget: KLogo(
        primary: l10n.brandWordmarkPrimary,
        accent: l10n.brandWordmarkAccent,
        semanticLabel: l10n.brandSemanticLabel,
        size: 22,
      ),
      icon: Icons.dynamic_feed_outlined,
      headline: l10n.homeComingTitle,
      message: l10n.homeComingBody,
    );
  }
}
