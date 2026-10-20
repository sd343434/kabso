import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/locale_sync.dart';
import 'package:kabso_live/features/debug/demo_data.dart';

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
    // PHASE1_1_SCREENS §3.4: a pending locale sync is also retried after
    // the next successful token refresh (no-op when nothing is pending or
    // no one is signed in).
    final refreshed = ref
        .read(tokenManagerProvider)
        .refreshed
        .listen((_) => unawaited(ref.read(localeSyncProvider).retryPending()));
    ref
      ..onDispose(sub.cancel)
      ..onDispose(refreshed.cancel);
    scheduleMicrotask(restore);
    return const AuthRestoring();
  }

  /// Restores the session stored on the device (launch, or retry from the
  /// splash error state).
  Future<void> restore() async {
    state = const AuthRestoring();
    // D86: with Demo data on (test builds) the demo account is signed in,
    // without a server or a stored token.
    if (kDemoAvailable && ref.read(demoModeProvider)) {
      state = Authenticated(_demoUser());
      return;
    }
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

  User _demoUser() =>
      DemoData.user(ar: ref.read(languageControllerProvider) == AppLanguage.ar);

  /// D86: "Try with demo data" (test builds): Demo data on, signed in as
  /// the demo account.
  Future<void> enterDemo() async {
    if (!kDemoAvailable) return;
    await ref.read(demoModeProvider.notifier).set(enabled: true);
    if (!ref.mounted) return;
    state = Authenticated(_demoUser());
  }

  /// D86: Demo data off. The demo account signs out; a real session stays.
  Future<void> exitDemo() async {
    await ref.read(demoModeProvider.notifier).set(enabled: false);
    if (!ref.mounted) return;
    final current = state;
    if (current is Authenticated && current.user.id == _demoUser().id) {
      state = const Unauthenticated();
    }
  }

  Future<void> logout() async {
    final current = state;
    if (kDemoAvailable &&
        current is Authenticated &&
        current.user.id == _demoUser().id) {
      await exitDemo();
      return;
    }
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
