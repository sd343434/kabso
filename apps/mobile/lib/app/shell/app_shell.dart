import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/shell_navigation.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/messages/unread_messages.dart';
import 'package:kabso_live/features/stories/application/stories_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Scaffold of the five primary tabs with the owner's animated bottom tab
/// bar (D130, [KTabBar]).
class AppShell extends ConsumerWidget {
  const new({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onSelect(WidgetRef ref, int index) {
    final create = AppRoutes.shellBranches.indexOf(AppRoutes.create);
    if (index == create && navigationShell.currentIndex != create) {
      // D123: Create (and Go live from it) returns here when it is left.
      ref
          .read(shellReturnTabProvider.notifier)
          .remember(AppRoutes.shellBranches[navigationShell.currentIndex]);
    }
    navigationShell.goBranch(
      index,
      // Tapping the active tab returns to its first page.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Create is a full-screen flow (owner's reference, KL-060): it has its
    // own Close and Back, so the bar is hidden there.
    final creating =
        navigationShell.currentIndex ==
        AppRoutes.shellBranches.indexOf(AppRoutes.create);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: creating
          ? null
          : KTabBar(
              currentIndex: navigationShell.currentIndex,
              onSelect: (index) => _onSelect(ref, index),
              items: shellTabItems(
                context.l10n,
                // D130: real sources only — no messaging API yet (0, hidden)
                // and unseen stories of followed accounts.
                unreadMessages: ref.watch(unreadMessagesProvider),
                newStories: ref.watch(unseenFollowedStoriesProvider),
              ),
            ),
    );
  }
}

/// The five shell destinations in navigation order (start → end), matching
/// `AppRoutes.shellBranches` (D86: Live · Moments · Create · Messages · Me),
/// drawn by the owner's animated bar (D130). [unreadMessages] badges
/// Messages; [newStories] puts the dot on Moments.
List<KTabBarItem> shellTabItems(
  AppLocalizations l10n, {
  int unreadMessages = 0,
  bool newStories = false,
}) => [
  KTabBarItem(
    key: const Key('nav.home'),
    kind: KTabKind.live,
    label: l10n.navLive,
  ),
  KTabBarItem(
    key: const Key('nav.reels'),
    kind: KTabKind.moments,
    label: l10n.navMoments,
    dot: newStories,
    dotLabel: l10n.navMomentsNew,
  ),
  KTabBarItem(
    key: const Key('nav.create'),
    kind: KTabKind.create,
    label: l10n.navCreate,
  ),
  KTabBarItem(
    key: const Key('nav.messages'),
    kind: KTabKind.messages,
    label: l10n.navMessages,
    badgeCount: unreadMessages,
    badgeLabel: unreadMessages > 99
        ? l10n.navMessagesUnreadMany
        : l10n.navMessagesUnread(unreadMessages),
  ),
  KTabBarItem(
    key: const Key('nav.profile'),
    kind: KTabKind.me,
    label: l10n.navProfile,
  ),
];
