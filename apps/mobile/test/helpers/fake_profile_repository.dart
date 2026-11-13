import 'dart:async';

import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';

/// In-memory [ProfileRepository] for one user: `GET /users/{username}` and
/// follow / unfollow, with an optional [gate] (hold the follow call) and
/// [followFailure] (thrown after the gate). Every call is recorded as
/// `GET u`, `PUT u` or `DELETE u`.
class FakeProfileRepository implements ProfileRepository {
  new(this.profile, {this.profileFailure});

  PublicProfile profile;

  /// Thrown by `getProfile` while set.
  AppFailure? profileFailure;

  /// When set, follow / unfollow wait for it.
  Completer<void>? gate;

  /// Thrown by follow / unfollow (after [gate]) while set.
  AppFailure? followFailure;

  final List<String> calls = [];

  @override
  Future<PublicProfile> getProfile(String username) async {
    calls.add('GET $username');
    if (profileFailure case final failure?) throw failure;
    return profile;
  }

  Future<FollowState> _edge(String verb, String username, bool to) async {
    calls.add('$verb $username');
    await gate?.future;
    if (followFailure case final failure?) throw failure;
    // D175: a new follow of a private account is a request; unfollowing
    // a requested account cancels it. Neither moves the count.
    if (to && profile.isPrivate && !profile.isFollowing) {
      profile = profile.copyWith(followRequested: true);
      return FollowState(
        isFollowing: false,
        isRequested: true,
        followerCount: profile.followerCount,
      );
    }
    if (!to && profile.followRequested) {
      profile = profile.copyWith(followRequested: false);
      return FollowState(
        isFollowing: false,
        followerCount: profile.followerCount,
      );
    }
    final was = profile.isFollowing;
    final count = profile.followerCount + (to == was ? 0 : (to ? 1 : -1));
    profile = profile.copyWith(isFollowing: to, followerCount: count);
    return FollowState(isFollowing: to, followerCount: count);
  }

  @override
  Future<FollowState> follow(String username) => _edge('PUT', username, true);

  @override
  Future<FollowState> unfollow(String username) =>
      _edge('DELETE', username, false);
}
