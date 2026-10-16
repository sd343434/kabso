// Public profile and follow models matching docs/contracts/openapi.yaml
// v1.3 (`getPublicProfile`, `followUser`, `unfollowUser`; CONVENTIONS
// §10.5–10.6).

import 'package:freezed_annotation/freezed_annotation.dart';

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
