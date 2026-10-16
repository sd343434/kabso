import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/locale_sync.dart';

/// Global authentication state. Drives the router's redirect guard.
sealed class AuthState {
  const new();
}

/// Launch: restoring the stored session.
final class AuthRestoring extends AuthState {
  const new();
}

/// Restoring failed for a transient reason (offline, server down). The stored
/// refresh token is kept so the user can retry.
final class AuthRestoreFailed extends AuthState {
  const new(this.failure);

  final AppFailure failure;
}

final class Authenticated extends AuthState {
  const new(this.user);

  final User user;
}

final class Unauthenticated extends AuthState {
  const new({this.reason});

  /// Why the session ended, when the server ended it
  /// (`AUTH_REFRESH_INVALID`, `ACCOUNT_SUSPENDED`). `null` after sign-out or
  /// when no session existed.
  final ErrorCode? reason;
}

class SessionController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final sub = ref
        .read(tokenManagerProvider)
        .invalidations
        .listen((reason) => state = Unauthenticated(reason: reason));
    ref.onDispose(sub.cancel);
    scheduleMicrotask(restore);
    return const AuthRestoring();
  }

  /// Restores the session stored on the device (launch, or retry from the
  /// splash error state).
  Future<void> restore() async {
    state = const AuthRestoring();
    try {
      final user = await ref.read(authRepositoryProvider).restoreSession();
      if (!ref.mounted) return;
      state = user == null ? const Unauthenticated() : Authenticated(user);
      if (user != null) unawaited(ref.read(localeSyncProvider).retryPending());
    } on AppFailure catch (failure) {
      if (!ref.mounted) return;
      final sessionGone =
          failure.code == ErrorCode.authRefreshInvalid ||
          failure.code == ErrorCode.accountSuspended ||
          failure.code == ErrorCode.authUnauthenticated;
      if (!sessionGone) {
        // Offline, timeout, 5xx, 429, unexpected payload: keep the stored
        // token and let the user retry from the splash.
        state = AuthRestoreFailed(failure);
        return;
      }
      if (failure.code == ErrorCode.authUnauthenticated) {
        // Refresh succeeded but /me still refused the token: drop it.
        await ref.read(tokenManagerProvider).clear();
        if (!ref.mounted) return;
      }
      // For AUTH_REFRESH_INVALID / ACCOUNT_SUSPENDED the token manager has
      // already cleared the session and published the reason.
      if (state is! Unauthenticated) state = const Unauthenticated();
    }
  }

  /// After login 200 or register/verify 201. Then syncs the language with
  /// the account (PHASE1_1_SCREENS §3.4) in the background.
  void signedIn(User user) {
    state = Authenticated(user);
    unawaited(ref.read(localeSyncProvider).afterSignIn(user));
  }

  /// Replaces the user (e.g. after a fresh `GET /me`).
  void updateUser(User user) {
    final current = state;
    if (current is Authenticated && current.user != user) {
      state = Authenticated(user);
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    if (!ref.mounted) return;
    state = const Unauthenticated();
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, AuthState>(SessionController.new);

/// The signed-in user, or `null`.
final currentUserProvider = Provider<User?>((ref) {
  final state = ref.watch(sessionControllerProvider);
  return state is Authenticated ? state.user : null;
});
