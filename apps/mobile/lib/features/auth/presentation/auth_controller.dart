import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/auth_repository.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/domain/validators.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';

/// Submission state of an auth form: idle, submitting, or failed.
sealed class FormSubmission {
  const new();
}

final class SubmissionIdle extends FormSubmission {
  const new();
}

final class SubmissionInProgress extends FormSubmission {
  const new();
}

final class SubmissionFailed extends FormSubmission {
  const new(this.failure);

  final AppFailure failure;
}

/// Runs the auth form actions (login, register, forgot password, resend
/// verification). One instance per screen (auto-disposed).
class AuthController extends Notifier<FormSubmission> {
  @override
  FormSubmission build() => const SubmissionIdle();

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  bool get isSubmitting => state is SubmissionInProgress;

  Future<bool> login({required String identifier, required String password}) =>
      _run(() async {
        final user = await _repo.login(
          identifier: identifier,
          password: password,
        );
        ref.read(sessionControllerProvider.notifier).signedIn(user);
      });

  Future<bool> register({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) => _run(() async {
    final user = await _repo.register(
      email: email,
      password: password,
      username: username,
      displayName: displayName,
      locale: ref.read(languageControllerProvider).name,
    );
    ref
        .read(sessionControllerProvider.notifier)
        .signedIn(user, justRegistered: true);
  });

  Future<bool> requestPasswordReset(String email) =>
      _run(() => _repo.requestPasswordReset(email));

  Future<bool> resendVerificationEmail() => _run(_repo.resendVerificationEmail);

  void reset() => state = const SubmissionIdle();

  Future<bool> _run(Future<void> Function() action) async {
    if (isSubmitting) return false;
    state = const SubmissionInProgress();
    try {
      await action();
      if (ref.mounted) state = const SubmissionIdle();
      return true;
    } on Object catch (e) {
      if (ref.mounted) state = SubmissionFailed(toAppFailure(e));
      return false;
    }
  }
}

final NotifierProvider<AuthController, FormSubmission> authControllerProvider =
    NotifierProvider.autoDispose<AuthController, FormSubmission>(
      AuthController.new,
    );

/// Live username availability shown under the register form's field.
sealed class UsernameStatus {
  const new();
}

/// Nothing to show (empty or locally invalid input).
final class UsernameIdle extends UsernameStatus {
  const new();
}

final class UsernameChecking extends UsernameStatus {
  const new(this.username);

  final String username;
}

final class UsernameAvailable extends UsernameStatus {
  const new(this.username);

  final String username;
}

final class UsernameTaken extends UsernameStatus {
  const new(this.username);

  final String username;
}

/// Fails the contract pattern; no request is sent.
final class UsernameInvalid extends UsernameStatus {
  const new(this.issue);

  final UsernameIssue issue;
}

/// The check failed (offline, timeout, 429, 5xx): neutral hint, submit is
/// still allowed and the server decides.
final class UsernameUnknown extends UsernameStatus {
  const new(this.username, this.failure);

  final String username;
  final AppFailure failure;
}

/// Debounce applied before calling the availability endpoint.
final usernameDebounceProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 450),
);

class UsernameAvailabilityController extends Notifier<UsernameStatus> {
  Timer? _debounce;
  String _latest = '';

  @override
  UsernameStatus build() {
    ref.onDispose(() => _debounce?.cancel());
    return const UsernameIdle();
  }

  /// Call on every change of the username field.
  void onChanged(String raw) {
    _debounce?.cancel();
    final value = AuthValidators.normalizeUsername(raw);
    _latest = value;
    final issue = AuthValidators.usernameIssue(value);
    if (issue == UsernameIssue.required) {
      state = const UsernameIdle();
      return;
    }
    if (issue != null) {
      state = UsernameInvalid(issue);
      return;
    }
    state = UsernameChecking(value);
    _debounce = Timer(ref.read(usernameDebounceProvider), () => _check(value));
  }

  /// Marks [username] as taken (e.g. after `USERNAME_TAKEN` on submit).
  void markTaken(String username) {
    _debounce?.cancel();
    state = UsernameTaken(username);
  }

  Future<void> _check(String username) async {
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .checkUsernameAvailability(username);
      if (!ref.mounted || username != _latest) return;
      state = result.available
          ? UsernameAvailable(username)
          : UsernameTaken(username);
    } on AppFailure catch (f) {
      if (!ref.mounted || username != _latest) return;
      state = UsernameUnknown(username, f);
    }
  }
}

typedef UsernameAvailabilityProvider =
    NotifierProvider<UsernameAvailabilityController, UsernameStatus>;

final UsernameAvailabilityProvider usernameAvailabilityProvider =
    NotifierProvider.autoDispose(UsernameAvailabilityController.new);

/// Fresh `GET /me` for the profile tab; also refreshes the session's user.
final FutureProvider<User> meProvider = FutureProvider.autoDispose((ref) async {
  final user = await ref.watch(authRepositoryProvider).getMe();
  ref.read(sessionControllerProvider.notifier).updateUser(user);
  return user;
});

/// `GET /auth/sessions` for the settings screen.
final FutureProvider<List<Session>> sessionsProvider =
    FutureProvider.autoDispose(
      (ref) => ref.watch(authRepositoryProvider).listSessions(),
    );
