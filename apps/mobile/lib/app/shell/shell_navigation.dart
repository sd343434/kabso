import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/create/create_menu_sheet.dart';
import 'package:material_ui/material_ui.dart';

/// A request to show `tab` in a shell tab's `FeedTabsScaffold`; `serial`
/// makes repeated requests for the same tab distinct.
typedef FeedTabRequest = ({FeedTab tab, int serial});

/// The live hub segment other screens asked for (KL-047: "Watch live
/// streams" on Reels opens Home, the live hub since D48, on the matching
/// segment). The route stays `/home`; only the in-page segment is requested.
class LiveHubTabRequest extends Notifier<FeedTabRequest?> {
  @override
  FeedTabRequest? build() => null;

  void request(FeedTab tab) =>
      state = (tab: tab, serial: (state?.serial ?? 0) + 1);
}

final NotifierProvider<LiveHubTabRequest, FeedTabRequest?>
liveHubTabRequestProvider = NotifierProvider(LiveHubTabRequest.new);

/// Switches to the Home shell tab, the live hub (the real `/home` route,
/// through the shell's branch navigation), showing [tab].
void openLiveHub(BuildContext context, WidgetRef ref, FeedTab tab) {
  ref.read(liveHubTabRequestProvider.notifier).request(tab);
  context.go(AppRoutes.home);
}

/// D139: back to the live hub from a page pushed over it (the voice
/// rooms): a pop when the page under this one is the hub, so the hub keeps
/// its state and the back stack stays as it was; otherwise (opened from a
/// link, another page, or nothing under it) a `go` to the hub.
void returnToLiveHub(GoRouter router) {
  final leaves = _leafLocations(
    router.routerDelegate.currentConfiguration.matches,
  );
  final under = leaves.length >= 2 ? leaves[leaves.length - 2] : null;
  if (under == AppRoutes.home && router.canPop()) {
    router.pop();
  } else {
    router.go(AppRoutes.home);
  }
}

/// D123: the primary tab the person was on when they opened Create (the
/// Live hub, Home, unless they came from another tab). A live started from
/// Create and then minimized returns there, with the floating window, not
/// to Create.
class ShellReturnTab extends Notifier<String> {
  @override
  String build() => AppRoutes.home;

  void remember(String location) {
    if (location != AppRoutes.create) state = location;
  }
}

final NotifierProvider<ShellReturnTab, String> shellReturnTabProvider =
    NotifierProvider<ShellReturnTab, String>(ShellReturnTab.new);

/// Leaves a full-screen page that was pushed over the shell (the go-live
/// screen minimized, D123): back to the page under it, except Create — the
/// person is no longer creating — which gives way to the tab they came from
/// ([shellReturnTabProvider]).
void leaveToShell(GoRouter router, WidgetRef ref) {
  final leaves = _leafLocations(
    router.routerDelegate.currentConfiguration.matches,
  );
  final under = leaves.length >= 2 ? leaves[leaves.length - 2] : null;
  if (under == AppRoutes.create || !router.canPop()) {
    router.go(ref.read(shellReturnTabProvider));
  } else {
    router.pop();
  }
}

List<String> _leafLocations(List<RouteMatchBase> matches) => [
  for (final match in matches)
    if (match is ShellRouteMatch)
      ..._leafLocations(match.matches)
    else
      match.matchedLocation,
];

/// D162 / D322: the create menu (post, reel, story, go live; D283: a Kabso
/// Team account gets announcements only) and its choice. Opened from
/// Moments' «+» since the bar's centre button is gone; Create and the other
/// flows open above the shell, and [from] (the tab under them) is where a
/// live started from Create returns when minimized (D123).
Future<void> openCreateMenu(
  BuildContext context,
  WidgetRef ref, {
  String from = AppRoutes.reels,
}) async {
  final choice = await showCreateMenu(
    context,
    staff: ref.read(currentUserProvider)?.staff != null,
  );
  if (choice == null || !context.mounted) return;
  ref.read(shellReturnTabProvider.notifier).remember(from);
  unawaited(
    context.push(switch (choice) {
      CreateChoice.post => AppRoutes.create,
      CreateChoice.reel => AppRoutes.newReel,
      CreateChoice.story => AppRoutes.newStory,
      // D123: a minimized live returns to the tab under it.
      CreateChoice.live => AppRoutes.goLive,
    }),
  );
}
