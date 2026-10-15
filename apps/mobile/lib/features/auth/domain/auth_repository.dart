import 'package:kabso_live/features/auth/domain/entities.dart';

/// Authentication and session operations.
///
/// Every method throws an `AppFailure` (see core/error) on failure.
abstract interface class AuthRepository {
  /// Restores a stored session (refresh token → `POST /auth/refresh` →
  /// `GET /me`). Returns `null` when no session is stored.
  Future<User?> restoreSession();

  Future<User> login({required String identifier, required String password});

  Future<User> register({
    required String email,
    required String password,
    required String username,
    required String displayName,
    required String locale,
  });

  /// Revokes the current session on the server (best effort) and always
  /// clears the local session.
  Future<void> logout();

  Future<User> getMe();

  Future<UsernameAvailability> checkUsernameAvailability(String username);

  /// Always succeeds for well-formed emails (no account enumeration).
  Future<void> requestPasswordReset(String email);

  Future<void> resendVerificationEmail();

  Future<List<Session>> listSessions();

  Future<void> revokeSession(String sessionId);
}
