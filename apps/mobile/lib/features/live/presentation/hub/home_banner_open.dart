import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/ambassadors/data/ambassador_repository.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Opens a promo banner's in-app route ([location], an allowlisted link from
/// `HomeBannerTarget.parse`) above the current page — the one place every
/// banner placement (HOME, HUB_CARD, ROOM, TASKS, WALLET) goes through.
///
/// v1.142-social (D394, CONVENTIONS §10.26): `/ambassadors` opens
/// «برنامج سفراء Kabso» (D390):
/// - a Kabso Team account gets a short note and stays where it is (the
///   programme's routes are blocked for staff, [AppRoutes.staffBlocked]);
/// - an ambassador gets the dashboard ([AppRoutes.ambassadorDashboard]);
/// - anyone else the programme page, which shows its own state (on: the form
///   or the status; off: «قريباً» and no form). If the status cannot be read,
///   the programme page opens and says why.
Future<void> openHomeBannerRoute(
  BuildContext context,
  WidgetRef ref,
  String location,
) async {
  if (location != AppRoutes.ambassadors) {
    await context.push<void>(location);
    return;
  }
  final user = ref.read(currentUserProvider);
  if (user?.staff != null) {
    KSnack.info(context, context.l10n.bannerAmbassadorsStaff);
    return;
  }
  var target = AppRoutes.ambassadors;
  // A guest (the in-room box) is sent to sign in by the router.
  if (user != null) {
    final repository = ref.read(ambassadorRepositoryProvider);
    try {
      if ((await repository.programme()).isAmbassador) {
        target = AppRoutes.ambassadorDashboard;
      }
    } on Object {
      // The programme page reads it again and shows the failure.
    }
    if (!context.mounted) return;
  }
  await context.push<void>(target);
}
