import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/vip/data/vip_gift_perks_repository.dart';

// v1.134-social (D381, CONVENTIONS §10.171): the member's gift, CP, support,
// rocket and voice perks now, and the scheduled gifts. A new signed-in
// person reloads them.

/// `MyVip.perksNow` (none without an active membership; reading it also
/// grants this month's MONTHLY_ROCKETS on the server).
final FutureProvider<VipPerksNow> vipPerksNowProvider = FutureProvider((ref) {
  ref.watch(currentUserProvider.select((u) => u?.id));
  if (ref.read(currentUserProvider) == null) {
    return Future.value(VipPerksNow.none);
  }
  return ref.watch(vipGiftPerksRepositoryProvider).perksNow();
});

/// LONGER_VOICE: the caller's longest voice clip — 30 s until the perks are
/// known, on an error, or without the perk.
final Provider<Duration> vipVoiceLimitProvider = Provider((ref) {
  final now = ref.watch(vipPerksNowProvider).value;
  return now?.voiceLimit ?? defaultVoiceLimit;
});

/// The caller's scheduled gifts «هدية مؤجلة» (`GET /me/vip/scheduled-gifts`).
final FutureProvider<VipScheduledGiftList> vipScheduledGiftsProvider =
    FutureProvider.autoDispose((ref) {
      ref
        ..watch(languageControllerProvider)
        ..watch(currentUserProvider.select((u) => u?.id));
      return ref.watch(vipGiftPerksRepositoryProvider).scheduled();
    });
