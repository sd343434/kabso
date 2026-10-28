import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/features/auth/domain/validators.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/premium/data/premium_repository.dart';
import 'package:kabso_live/features/premium/domain/premium_models.dart';

/// The store, all tiers (`null`) or one (`GET /premium-usernames[?tier=]`).
final FutureProviderFamily<PremiumStore, PremiumTier?> premiumStoreProvider =
    FutureProvider.autoDispose.family((ref, tier) {
      ref.watch(currentUserProvider.select((u) => u?.id));
      return ref.watch(premiumRepositoryProvider).store(tier: tier);
    });

/// The caller's premium username, or null (`GET /me/premium-username`).
final FutureProvider<MyPremiumUsername?> myPremiumProvider =
    FutureProvider.autoDispose((ref) {
      ref.watch(currentUserProvider.select((u) => u?.id));
      return ref.watch(premiumRepositoryProvider).mine();
    });

/// The store's live check of the search box.
sealed class PremiumCheck {
  const new();
}

/// Nothing typed.
final class PremiumCheckIdle extends PremiumCheck {
  const new();
}

/// Waiting for the debounce or the server.
final class PremiumCheckLoading extends PremiumCheck {
  const new(this.username);

  final String username;
}

/// The server's answer for the name in [status].
final class PremiumCheckResult extends PremiumCheck {
  const new(this.status);

  final PremiumNameStatus status;
}

/// The check failed (network, server); [failure] says why.
final class PremiumCheckFailed extends PremiumCheck {
  const new(this.username, this.failure);

  final String username;
  final AppFailure failure;
}

/// Debounce before the store's availability call.
final premiumCheckDebounceProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 400),
);

/// Checks what the typed name is (`GET /premium-usernames/{username}`),
/// debounced, keeping only the latest answer.
class PremiumCheckController extends Notifier<PremiumCheck> {
  Timer? _debounce;
  String _latest = '';

  @override
  PremiumCheck build() {
    ref.onDispose(() => _debounce?.cancel());
    return const PremiumCheckIdle();
  }

  void onChanged(String raw) {
    _debounce?.cancel();
    final value = AuthValidators.normalizeUsername(raw).replaceFirst('@', '');
    _latest = value;
    if (value.isEmpty) {
      state = const PremiumCheckIdle();
      return;
    }
    state = PremiumCheckLoading(value);
    _debounce = Timer(
      ref.read(premiumCheckDebounceProvider),
      () => unawaited(_check(value)),
    );
  }

  /// Checks [_latest] again (after a rent or a failure).
  Future<void> refresh() async {
    if (_latest.isEmpty) return;
    state = PremiumCheckLoading(_latest);
    await _check(_latest);
  }

  Future<void> _check(String username) async {
    try {
      final status = await ref.read(premiumRepositoryProvider).status(username);
      if (!ref.mounted || username != _latest) return;
      state = PremiumCheckResult(status);
    } on AppFailure catch (f) {
      if (!ref.mounted || username != _latest) return;
      state = PremiumCheckFailed(username, f);
    }
  }
}

final NotifierProvider<PremiumCheckController, PremiumCheck>
premiumCheckProvider = NotifierProvider.autoDispose(PremiumCheckController.new);
