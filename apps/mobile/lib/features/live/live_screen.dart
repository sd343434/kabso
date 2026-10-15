import 'package:kabso_live/app/shell/coming_soon_tab.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Live rooms — arrive in Phase 6.
class LiveScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ComingSoonTab(
      title: l10n.navLive,
      icon: Icons.live_tv_outlined,
      headline: l10n.liveComingTitle,
      message: l10n.liveComingBody,
    );
  }
}
