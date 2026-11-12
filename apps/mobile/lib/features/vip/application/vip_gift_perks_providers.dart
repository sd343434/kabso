import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/vip/data/vip_gift_perks_repository.dart';

// v1.134-social (D381, CONVENTIONS §10.171): the member's gift, CP, support,
// rocket and voice perks now, and the scheduled gifts. A new signed-in
// person reloads them.

/// LONGER_VOICE: the caller's longest voice clip — 30 s until `GET /me/vip`
/// said otherwise (the Me hub, the VIP page and «الخاص بي VIP» read it).
/// The recorders read it without asking the server.
class VipVoiceLimit extends Notifier<Duration> {
  @override
  Duration build() {
    ref.watch(currentUserProvider.select((u) => u?.id));
    return defaultVoiceLimit;
  }

  /// The limit `GET /me/vip` answered.
  // A notifier's update method (not a property of the class).
  // ignore: use_setters_to_change_properties
  void set(Duration limit) => state = limit;
}

final NotifierProvider<VipVoiceLimit, Duration> vipVoiceLimitProvider =
    NotifierProvider(VipVoiceLimit.new);

/// The caller's scheduled gifts «هدية مؤجلة» (`GET /me/vip/scheduled-gifts`).
final FutureProvider<VipScheduledGiftList> vipScheduledGiftsProvider =
    FutureProvider.autoDispose((ref) {
      ref
        ..watch(languageControllerProvider)
        ..watch(currentUserProvider.select((u) => u?.id));
      return ref.watch(vipGiftPerksRepositoryProvider).scheduled();
    });
