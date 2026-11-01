import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/referrals/data/referral_repository.dart';

/// v1.74-social (D217): the caller's invite page (`GET /me/referral`); null
/// from an older server.
final FutureProvider<MyReferral?> myReferralProvider =
    FutureProvider.autoDispose((ref) async {
      ref.watch(currentUserProvider.select((u) => u?.id));
      final mine = await ref.watch(referralRepositoryProvider).mine();
      ref.read(referralEnabledProvider.notifier).enabled =
          mine?.enabled ?? false;
      return mine;
    });

/// The public ticker of real rewards (empty → hidden).
final FutureProvider<List<ReferralTickerItem>> referralTickerProvider =
    FutureProvider.autoDispose(
      (ref) => ref.watch(referralRepositoryProvider).ticker(),
    );

/// Whether the programme was on at the last read of the invite page (null:
/// not read yet). The Me hub's «اربح المال» opens the cherry wallet directly
/// when it was off; otherwise the invite page (which goes to the wallet
/// itself if it finds the programme off).
class ReferralEnabled extends Notifier<bool?> {
  @override
  bool? build() => null;

  // A setter (the lint's preference); the last read wins.
  // ignore: avoid_setters_without_getters
  set enabled(bool value) => state = value;
}

final NotifierProvider<ReferralEnabled, bool?> referralEnabledProvider =
    NotifierProvider<ReferralEnabled, bool?>(ReferralEnabled.new);
