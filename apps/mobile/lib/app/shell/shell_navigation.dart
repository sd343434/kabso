import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/state/feed_load.dart';
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
