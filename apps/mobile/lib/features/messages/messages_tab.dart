import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/app/shell/coming_soon_tab.dart';
import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/features/debug/conversations_preview_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/messages` — the Messages tab (D86). There is no messaging API yet
/// (contract has no conversations endpoint), so the tab says so honestly.
/// Test builds with Demo data on show the designed conversation list
/// (D68) with labelled test data.
class MessagesTab extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kDemoAvailable && ref.watch(demoModeProvider)) {
      return const ConversationsPreviewScreen();
    }
    final l10n = context.l10n;
    return ComingSoonTab(
      title: l10n.navMessages,
      icon: Icons.forum_outlined,
      headline: l10n.conversationsUnavailableTitle,
      message: l10n.conversationsUnavailableBody,
    );
  }
}
