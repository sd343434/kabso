import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';

/// What a bullet message costs (CP-017, `LIVE_BULLET_COST_COINS`).
const int liveBulletCostCoins = 15;

/// The signed-in person's coin balance (`GET /wallet/me`, CP-017 §10.19);
/// 0 for guests. A bullet's answer carries the balance after it ([set]).
/// Coins come only from the team for now (no purchases, B5).
class LiveCoinsController extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    if (ref.watch(currentUserProvider) == null) return 0;
    final coins = await ref.read(liveRepositoryProvider).myCoins();
    return coins;
  }

  /// The balance an answer gave.
  void set(int coins) => state = AsyncData(coins);
}

final AsyncNotifierProvider<LiveCoinsController, int> liveCoinsProvider =
    AsyncNotifierProvider.autoDispose<LiveCoinsController, int>(
      LiveCoinsController.new,
    );
