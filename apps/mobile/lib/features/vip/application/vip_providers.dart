import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/vip/application/vip_gift_perks_providers.dart';
import 'package:kabso_live/features/vip/data/vip_gift_perks_repository.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';

// Names and perks are localized by the server, so a language change
// reloads them; a new signed-in person reloads everything.

/// The VIP tiers on sale (`GET /vip/tiers`, D252).
final FutureProvider<VipTierList> vipTiersProvider = FutureProvider.autoDispose(
  (ref) {
    ref
      ..watch(languageControllerProvider)
      ..watch(currentUserProvider.select((u) => u?.id));
    return ref.watch(vipRepositoryProvider).tiers();
  },
);

/// The caller's VIP membership, or null (`GET /me/vip`, D252).
final FutureProvider<VipMembership?> myVipProvider = FutureProvider.autoDispose(
  (ref) {
    ref
      ..watch(languageControllerProvider)
      ..watch(currentUserProvider.select((u) => u?.id));
    return ref.watch(vipRepositoryProvider).mine().then((m) {
      // v1.134-social (D381): LONGER_VOICE's limit for the recorders.
      ref
          .read(vipVoiceLimitProvider.notifier)
          .set(m?.perksNow?.voiceLimit ?? defaultVoiceLimit);
      return m;
    });
  },
);

/// «من زار ملفي» (`GET /me/profile-visitors`, D258).
final FutureProvider<ProfileVisitorList> profileVisitorsProvider =
    FutureProvider.autoDispose((ref) {
      ref.watch(currentUserProvider.select((u) => u?.id));
      return ref.watch(vipRepositoryProvider).profileVisitors();
    });

/// D258 (§10.94.12): the caller's renewal discount now, or null (a failed
/// read is none: the list price, which the server would refuse with 409
/// and the page reloads).
final FutureProvider<VipRenewal?> myVipRenewalProvider =
    FutureProvider.autoDispose((ref) async {
      ref.watch(currentUserProvider.select((u) => u?.id));
      try {
        return await ref.watch(vipRepositoryProvider).renewal();
      } on Object {
        return null;
      }
    });
