import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/debug/demo_data.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:material_ui/material_ui.dart';

/// The profile's content tabs (D57): the posts grid, the reels grid and
/// (D59, own profile only) the saved posts and reels.
enum ProfileTab { posts, reels, reposts, saved }

/// One cell of a profile grid: a post's or reel's cover.
@immutable
class ProfileGridItem {
  const new({
    this.cover,
    this.isVideo = false,
    this.postId,
    this.text,
    this.pinned = false,
    this.multiple = false,
  });

  /// A grid cell of [post]: its first photo, or its text when it has none.
  factory ofPost(Post post) => ProfileGridItem(
    postId: post.id,
    cover: post.media.isEmpty ? null : NetworkImage(post.media.first.thumbUrl),
    text: post.media.isEmpty ? post.text : null,
    pinned: post.pinned,
    multiple: post.media.length > 1,
  );

  final ImageProvider? cover;

  /// A video post: the cell carries a play mark.
  final bool isVideo;

  /// The API id: set for real posts, whose cell opens the post.
  final String? postId;

  /// A text-only post shows its text in the cell.
  final String? text;

  /// Pinned on the profile (pinned posts come first).
  final bool pinned;

  /// More than one photo: the cell carries the gallery mark.
  final bool multiple;
}

/// The profile's counts: `GET /users/{username}` (v1.3) carries the
/// follower and following counts that `GET /me` does not.
final FutureProviderFamily<PublicProfile, String> profileStatsProvider =
    FutureProvider.autoDispose.family(
      (ref, username) =>
          ref.watch(profileRepositoryProvider).getProfile(username),
    );

/// Which grid: a user's `tab` (saved only for yourself).
typedef ProfileGridKey = ({String username, ProfileTab tab});

/// The pages of a grid on the posts API (v1.5-social): `posts` reads
/// `GET /users/{username}/posts` (pinned first, then newest), `saved`
/// reads `GET /me/saved` (newest save first), `reposts` reads
/// `GET /users/{username}/reposts` (newest repost first). Reels have no API before M2:
/// [FeedUnavailable], never sample content. A private account you do not
/// follow, or a block, answers 404: an empty grid (the profile says why).
class ProfileGridPages extends AsyncNotifier<FeedLoad<ProfileGridItem>> {
  new(this.key);

  final ProfileGridKey key;
  String? _next;

  PostsRepository get _repo => ref.read(postsRepositoryProvider);

  Future<PageOf<Post>> _page(String? cursor) => switch (key.tab) {
    ProfileTab.saved => _repo.saved(cursor: cursor),
    ProfileTab.reposts => _repo.userReposts(key.username, cursor: cursor),
    _ => _repo.userPosts(key.username, cursor: cursor),
  };

  List<ProfileGridItem> _cells(List<Post> posts) {
    final removed = ref.read(removedPostsProvider);
    return [
      for (final p in posts)
        if (!removed.contains(p.id)) ProfileGridItem.ofPost(p),
    ];
  }

  @override
  Future<FeedLoad<ProfileGridItem>> build() async {
    ref
      ..watch(postsRepositoryProvider)
      ..watch(currentUserProvider.select((u) => u?.id))
      ..listen(removedPostsProvider, (_, removed) {
        final s = state.value;
        if (s is FeedItems<ProfileGridItem>) {
          state = AsyncData(
            FeedItems([
              for (final c in s.items)
                if (!removed.contains(c.postId)) c,
            ], hasMore: s.hasMore),
          );
        }
      });
    if (key.tab == ProfileTab.reels) return const FeedUnavailable();
    try {
      final page = await _page(null);
      _next = page.next;
      return FeedItems(_cells(page.items), hasMore: _next != null);
    } on ServerFailure catch (e) {
      if (e.code == ErrorCode.notFound) return const FeedItems([]);
      rethrow;
    }
  }

  /// The next page, when one exists and none is loading.
  Future<void> loadMore() async {
    final s = state.value;
    if (s is! FeedItems<ProfileGridItem> || !s.hasMore || s.loadingMore) {
      return;
    }
    state = AsyncData(FeedItems(s.items, hasMore: true, loadingMore: true));
    try {
      final page = await _page(_next);
      if (!ref.mounted) return;
      _next = page.next;
      final known = {for (final c in s.items) c.postId};
      state = AsyncData(
        FeedItems([
          ...s.items,
          for (final c in _cells(page.items))
            if (!known.contains(c.postId)) c,
        ], hasMore: _next != null),
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = AsyncData(FeedItems(s.items, hasMore: true, loadMoreError: e));
    }
  }
}

final AsyncNotifierProviderFamily<
  ProfileGridPages,
  FeedLoad<ProfileGridItem>,
  ProfileGridKey
>
profileGridPagesProvider = AsyncNotifierProvider.family(ProfileGridPages.new);

/// A user's posts, reels or saved grid as the screen shows it (Demo data
/// in debug builds; tests and the debug preview override it).
final FutureProviderFamily<FeedLoad<ProfileGridItem>, ProfileGridKey>
profileGridProvider = FutureProvider.family(
  (ref, key) => watchDemo(ref)
      ? DemoData.grid(key)
      : ref.watch(profileGridPagesProvider(key).future),
);
