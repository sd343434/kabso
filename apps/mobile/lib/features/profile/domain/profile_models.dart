// Public profile and follow models matching docs/contracts/openapi.yaml
// v1.3 (`getPublicProfile`, `followUser`, `unfollowUser`; CONVENTIONS
// §10.5–10.6), with the family, couple and medals of v1.21-live (CP-018,
// §10.21).

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';
import 'package:kabso_live/features/families/domain/family_models.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';

part 'profile_models.freezed.dart';
part 'profile_models.g.dart';

/// `PublicProfile`. Never contains an email, role, status or locale.
@freezed
abstract class PublicProfile with _$PublicProfile {
  const factory({
    required String id,
    required String username,
    required String displayName,
    required String? avatarUrl,
    required String? bio,
    required bool isPrivate,
    required int followerCount,
    required int followingCount,
    required bool isFollowing,
    required bool isSelf,
    required String? liveRoomId,

    /// CP-007: the caller muted this user (never shown to them). Defaults
    /// to false for previews built without it.
    @Default(false) bool isMuted,

    /// v1.21-live (CP-018): the user's family and role, or null.
    ProfileFamily? family,

    /// v1.21-live (CP-018): the user's couple, or null.
    ProfileCp? cp,

    /// v1.21-live (CP-018): medals owned, the newest and the chosen
    /// showcase (empty for previews built without it).
    @Default(ProfileMedals()) ProfileMedals medals,
  }) = _PublicProfile;

  const new _();

  factory fromJson(Map<String, dynamic> json) => _$PublicProfileFromJson(json);

  /// Whether a Follow control may be offered (§10.5/10.6): never for
  /// yourself, and never to start following a private account (no follow
  /// requests in v1.3). An existing follower of a private account can still
  /// unfollow.
  bool get canFollow => !isSelf && (isFollowing || !isPrivate);
}

/// `FollowState`: the result of follow / unfollow.
@freezed
abstract class FollowState with _$FollowState {
  const factory({required bool isFollowing, required int followerCount}) =
      _FollowState;

  factory fromJson(Map<String, dynamic> json) => _$FollowStateFromJson(json);
}
