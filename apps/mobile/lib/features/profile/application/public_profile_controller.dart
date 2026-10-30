import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';

/// A user's public profile with an optimistic follow toggle (CONVENTIONS
/// §10.5–10.6).
///
/// No screen uses this yet: creator profiles are slice 5. It exists for the
/// slice-2 room header, which shows the host and a Follow control.
class PublicProfileController extends AsyncNotifier<PublicProfile> {
  new(this.username);

  final String username;

  bool _busy = false;

  @override
  Future<PublicProfile> build() =>
      ref.watch(profileRepositoryProvider).getProfile(username);

  /// Whether a follow / unfollow request is in flight.
  bool get isBusy => _busy;

  /// Follows ([follow] true) or unfollows the user.
  ///
  /// The profile updates immediately (state and follower count); the
  /// server's `FollowState` then replaces the count. On failure the previous
  /// profile is restored and the `AppFailure` is rethrown for the caller to
  /// show. Ignored while the profile is not loaded, while another toggle is
  /// in flight, when nothing would change, or for yourself.
  ///
  /// v1.47-social (D175, §10.43): following a private account sends a
  /// request (`followRequested`, the count does not move); [follow] false
  /// then cancels the request.
  Future<void> setFollowing({required bool follow}) async {
    final before = state.value;
    if (before == null || _busy) return;
    final active = before.isFollowing || before.followRequested;
    if (active == follow || !before.canFollow) return;
    _busy = true;
    final request = follow && before.isPrivate;
    final counted = before.isFollowing || (follow && !request);
    state = AsyncData(
      before.copyWith(
        isFollowing: follow && !request,
        followRequested: request,
        followerCount: counted
            ? math.max(0, before.followerCount + (follow ? 1 : -1))
            : before.followerCount,
      ),
    );
    try {
      final repo = ref.read(profileRepositoryProvider);
      final result = follow
          ? await repo.follow(username)
          : await repo.unfollow(username);
      if (!ref.mounted) return;
      final latest = state.value ?? before;
      state = AsyncData(
        latest.copyWith(
          isFollowing: result.isFollowing,
          followRequested: result.isRequested,
          followerCount: result.followerCount,
        ),
      );
    } on Object {
      if (ref.mounted) state = AsyncData(before);
      rethrow;
    } finally {
      _busy = false;
    }
  }
}

final AsyncNotifierProviderFamily<
  PublicProfileController,
  PublicProfile,
  String
>
publicProfileProvider = AsyncNotifierProvider.autoDispose
    .family<PublicProfileController, PublicProfile, String>(
      PublicProfileController.new,
    );
