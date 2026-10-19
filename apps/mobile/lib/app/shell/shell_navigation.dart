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
