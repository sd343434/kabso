import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:material_ui/material_ui.dart';

/// The profile's content tabs (D57): the posts grid, the reels grid and
/// (D59, own profile only) the saved posts and reels.
enum ProfileTab { posts, reels, saved }

/// One cell of a profile grid: a post's or reel's cover.
@immutable
class ProfileGridItem {
  const new({this.cover, this.isVideo = false});

  final ImageProvider? cover;

  /// A video post: the cell carries a play mark.
  final bool isVideo;
}

/// The profile's counts: `GET /users/{username}` (v1.3) carries the
/// follower and following counts that `GET /me` does not.
final FutureProviderFamily<PublicProfile, String> profileStatsProvider =
    FutureProvider.autoDispose.family(
      (ref, username) =>
          ref.watch(profileRepositoryProvider).getProfile(username),
    );

// There is no posts, reels or saves API yet (posts Phase 3, short video
// Phase 5; saving with them), so production returns [FeedUnavailable] for
// every grid — never sample
// content. Tests and the debug preview override this provider.

/// Which grid: a user's `tab` (saved only for yourself).
typedef ProfileGridKey = ({String username, ProfileTab tab});

/// A user's posts, reels or saved grid.
final FutureProviderFamily<FeedLoad<ProfileGridItem>, ProfileGridKey>
profileGridProvider = FutureProvider.family(
  (ref, key) => const FeedUnavailable<ProfileGridItem>(),
);
