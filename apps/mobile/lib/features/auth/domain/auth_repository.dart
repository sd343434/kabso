import 'package:kabso_live/features/auth/domain/entities.dart';

/// Authentication and session operations.
///
/// Every method throws an `AppFailure` (see core/error) on failure.
abstract interface class AuthRepository {
  /// Restores a stored session (refresh token → `POST /auth/refresh` →
  /// `GET /me`). Returns `null` when no session is stored.
  Future<User?> restoreSession();

  Future<User> login({required String identifier, required String password});

  /// Starts a verify-first registration (contract v1.2): `POST
  /// /auth/register` → 202. Creates no account and no session; the emailed
  /// 8-digit code completes it via [verifyRegistration].
  Future<void> register({
    required String email,
    required String password,
    required String username,
    required String displayName,
    required String locale,
  });

  /// `POST /auth/register/verify` → 201: creates the account and stores the
  /// session (like [login]).
  Future<User> verifyRegistration({
    required String email,
    required String code,
  });

  /// `POST /auth/register/resend` → always 202.
  Future<void> resendRegistrationCode(String email);

  /// `PATCH /me {"locale"}` (v1.2): persists the user's language choice.
  Future<User> updateLocale(String locale);

  /// Revokes the current session on the server (best effort) and always
  /// clears the local session.
  Future<void> logout();

  Future<User> getMe();

  Future<UsernameAvailability> checkUsernameAvailability(String username);

  /// Always succeeds for well-formed emails (no account enumeration).
  Future<void> requestPasswordReset(String email);

  Future<List<Session>> listSessions();

  Future<void> revokeSession(String sessionId);
}
