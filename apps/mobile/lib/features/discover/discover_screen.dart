import 'package:kabso_live/app/shell/coming_soon_tab.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Discover / search — arrives in Phase 9.
class DiscoverScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ComingSoonTab(
      title: l10n.navDiscover,
      icon: Icons.explore_outlined,
      headline: l10n.discoverComingTitle,
      message: l10n.discoverComingBody,
    );
  }
}
