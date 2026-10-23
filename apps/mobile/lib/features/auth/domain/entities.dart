import 'package:freezed_annotation/freezed_annotation.dart';

part 'entities.freezed.dart';

enum UserRole { user, admin }

enum SessionPlatform { android, ios, web, other }

/// The signed-in user (`Me` in openapi.yaml).
@freezed
abstract class User with _$User {
  const factory({
    required String id,
    required String email,
    required bool emailVerified,
    required String username,
    required String displayName,
    required String locale,
    required UserRole role,
    required bool isPrivate,
    required DateTime createdAt,
    String? bio,
    String? avatarUrl,

    /// CP-010: holds the hosting permission (may go live).
    @Default(false) bool canHost,
  }) = _User;
}

/// One active session of the user (`SessionInfo` in openapi.yaml).
@freezed
abstract class Session with _$Session {
  const factory({
    required String id,
    required bool current,
    required DateTime createdAt,
    required DateTime lastUsedAt,
    String? deviceName,
    SessionPlatform? platform,
    String? appVersion,
  }) = _Session;
}

/// Result of a username availability check.
@freezed
abstract class UsernameAvailability with _$UsernameAvailability {
  const factory({required String username, required bool available}) =
      _UsernameAvailability;
}
