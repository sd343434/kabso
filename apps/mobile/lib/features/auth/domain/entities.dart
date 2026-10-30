import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/models/profile_fields.dart';

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

    /// CP-015: the host's live cover, reused by every live; null → the
    /// avatar is shown.
    String? liveCoverUrl,

    /// v1.27.1-live (D133): the person's own country (ISO 3166-1 alpha-2,
    /// upper case), or null. It decides the live hub's Nearby.
    String? country,

    /// v1.28-live (D146): the tier of the person's premium username, or
    /// null for a regular one.
    PremiumTier? premiumTier,

    /// v1.47-social (D175): the person's gender (null until chosen) and
    /// whether others see it (private by default).
    Gender? gender,
    @Default(false) bool showGender,

    /// v1.47-social (D175): the account category shown under the name.
    AccountCategory? category,

    /// v1.47-social (D175): up to 3 profile links, in order.
    @Default(<ProfileLink>[]) List<ProfileLink> links,
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
