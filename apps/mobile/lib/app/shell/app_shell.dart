import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/create/compose_upload_bar.dart';
import 'package:kabso_live/features/messages/unread_messages.dart';
import 'package:kabso_live/features/push/push_permission.dart';
import 'package:kabso_live/features/stories/application/stories_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Scaffold of the five primary tabs with the owner's animated bottom bar
/// (D322, [KabsoNavBar]): البث · الحفلة · اللحظات · الرسائل · أنا. No centre
/// button: going live starts from the Live hub's «+» (D322), creating a
/// post / reel / story from Moments' «+».
class AppShell extends ConsumerWidget {
  const new({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // D152: right after a sign-in (never at a cold start), explain and ask
    // for the notification permission once.
    if (ref.watch(pushPromptDueProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (ref.read(pushPromptDueProvider.notifier).consume()) {
          unawaited(maybeAskPushPermission(context, ref));
        }
      });
    }
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // D333: a post still uploading in the background (Create is
          // above the shell since D322, so the bar is always here).
          const ComposeUploadBar(),
          shellNavBar(
            context.l10n,
            currentIndex: navigationShell.currentIndex,
            onTap: navigationShell.goBranch,
            // Tapping the active tab returns to its first page (its animation
            // replays too).
            onReselect: (index) =>
                navigationShell.goBranch(index, initialLocation: true),
            // D130: real sources only — unread direct messages (D155) and
            // unseen stories of followed accounts.
            unreadMessages: ref.watch(unreadMessagesProvider),
            newStories: ref.watch(unseenFollowedStoriesProvider),
          ),
        ],
      ),
    );
  }
}

/// The semantics keys of the five tabs, in `AppRoutes.shellBranches` order.
abstract final class ShellNavKeys {
  static const live = Key('nav.home');
  static const party = Key('nav.party');
  static const moments = Key('nav.reels');
  static const messages = Key('nav.messages');
  static const me = Key('nav.profile');
  static const List<Key> all = [live, party, moments, messages, me];
}

/// The shell's bottom bar (D322): the owner's [KabsoNavBar] with the
/// gen-l10n labels, matching `AppRoutes.shellBranches`. [unreadMessages]
/// badges Messages; [newStories] puts the dot on Moments.
KabsoNavBar shellNavBar(
  AppLocalizations l10n, {
  required int currentIndex,
  required ValueChanged<int> onTap,
  ValueChanged<int>? onReselect,
  int unreadMessages = 0,
  bool newStories = false,
}) => KabsoNavBar(
  currentIndex: currentIndex,
  onTap: onTap,
  onReselect: onReselect,
  itemKeys: ShellNavKeys.all,
  labels: [
    l10n.navLive,
    l10n.navParty,
    l10n.navMoments,
    l10n.navMessages,
    l10n.navProfile,
  ],
  unreadMessages: unreadMessages,
  unreadLabel: unreadMessages > 99
      ? l10n.navMessagesUnreadMany
      : l10n.navMessagesUnread(unreadMessages),
  momentsDot: newStories,
  momentsDotLabel: l10n.navMomentsNew,
);
