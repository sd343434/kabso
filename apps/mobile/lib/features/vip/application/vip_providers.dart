import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderFamily;
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
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
    return ref.watch(vipRepositoryProvider).mine();
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

/// v1.133-social (D380): whether the caller's own VIP holds the perk `code`
/// now (their tier's or a lower tier's, D258 inheritance; built perks only).
/// False while loading, without a VIP, or when unreadable — the server
/// refuses a perk not held anyway.
final ProviderFamily<bool, String> myVipHoldsProvider = Provider.autoDispose
    .family<bool, String>((ref, code) {
      final mine = ref.watch(myVipProvider).value;
      if (mine == null) return false;
      final look = vipLookOf(
        UserVip(tier: mine.tierCode, rank: 0, color: mine.tierColor),
        ref.watch(vipCatalogProvider).value,
      );
      return look?.has(code) ?? false;
    });
