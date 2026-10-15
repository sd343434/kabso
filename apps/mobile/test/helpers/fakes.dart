import 'dart:async';

import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/domain/auth_repository.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';

class InMemoryTokenStore implements SecureTokenStore {
  new([this.refreshToken]);

  String? refreshToken;
  int clears = 0;

  @override
  Future<void> clear() async {
    clears++;
    refreshToken = null;
  }

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeRefreshToken(String token) async => refreshToken = token;
}

User testUser({
  String displayName = 'Layla',
  String username = 'layla.k',
  String email = 'layla@example.com',
  bool emailVerified = true,
}) => User(
  id: '0192f1c2-7c3a-7b2e-9a51-1d2c3b4a5e6f',
  email: email,
  emailVerified: emailVerified,
  username: username,
  displayName: displayName,
  locale: 'ar',
  role: UserRole.user,
  isPrivate: false,
  createdAt: DateTime.utc(2026, 10, 15, 13),
);

/// Configurable in-memory [AuthRepository] for widget tests.
class FakeAuthRepository implements AuthRepository {
  new({
    this.storedUser,
    User? me,
    this.loginFailure,
    this.registerFailure,
    this.availabilityFailure,
    this.takenUsernames = const {},
    this.availabilityDelay = Duration.zero,
  }) : me = me ?? storedUser ?? testUser();

  /// Returned by [restoreSession]; `null` = no stored session.
  User? storedUser;

  /// Returned by [getMe].
  User me;
  AppFailure? loginFailure;
  AppFailure? registerFailure;
  AppFailure? availabilityFailure;
  int loginCalls = 0;
  int registerCalls = 0;
  Set<String> takenUsernames;
  Duration availabilityDelay;

  final List<String> availabilityChecks = [];
  int logoutCalls = 0;
  int getMeCalls = 0;

  @override
  Future<User?> restoreSession() async => storedUser;

  @override
  Future<User> login({
    required String identifier,
    required String password,
  }) async {
    loginCalls++;
    final failure = loginFailure;
    if (failure != null) throw failure;
    return me;
  }

  @override
  Future<User> register({
    required String email,
    required String password,
    required String username,
    required String displayName,
    required String locale,
  }) async {
    registerCalls++;
    final failure = registerFailure;
    if (failure != null) throw failure;
    return me;
  }

  @override
  Future<void> logout() async => logoutCalls++;

  @override
  Future<User> getMe() async {
    getMeCalls++;
    return me;
  }

  @override
  Future<UsernameAvailability> checkUsernameAvailability(
    String username,
  ) async {
    availabilityChecks.add(username);
    final failure = availabilityFailure;
    if (failure != null) throw failure;
    if (availabilityDelay > Duration.zero) {
      await Future<void>.delayed(availabilityDelay);
    }
    return UsernameAvailability(
      username: username,
      available: !takenUsernames.contains(username),
    );
  }

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> resendVerificationEmail() async {}

  @override
  Future<List<Session>> listSessions() async => const [];

  @override
  Future<void> revokeSession(String sessionId) async {}
}
