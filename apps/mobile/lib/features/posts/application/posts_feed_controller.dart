import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:material_ui/material_ui.dart';

/// A [Post] as the feed tile shows it. Images load from the media CDN.
FeedPostData feedPostOf(Post post) {
  final cover = post.media.isEmpty ? null : post.media.first;
  return FeedPostData(
    postId: post.id,
    authorName: post.author.displayName.isEmpty
        ? post.author.username
        : post.author.displayName,
    authorUsername: post.author.username,
    authorId: post.author.id,
    authorAvatar: switch (post.author.avatarUrl) {
      final url? => NetworkImage(url),
      null => null,
    },
    postedAt: post.publishedAt ?? post.createdAt,
    location: post.location,
    text: post.text,
    media: cover == null ? null : NetworkImage(cover.url),
    mediaAspect: cover?.aspect,
    likes: post.likeCount,
    comments: post.commentCount,
    shares: post.shareCount,
    liked: post.viewerHasLiked,
    saved: post.viewerHasSaved,
    isSelf: post.isSelf,
    pendingModeration: post.pendingModeration,
    repostedBy: post.repostedBy?.displayName,
    commentsOpen:
        post.isSelf ||
        (post.commentsEnabled && post.whoCanComment != WhoCanComment.nobody),
  );
}

extension on HomeFeed {
  PostsFeedTab get tab => switch (this) {
    HomeFeed.trending => PostsFeedTab.trending,
    HomeFeed.following => PostsFeedTab.following,
  };
}

/// One posts feed from the real API (`GET /feed/posts`, CONVENTIONS §11.3),
/// paged by cursor. A rejected cursor (an expired Trending snapshot) reloads
/// the feed from the first page once. A hidden or deleted post leaves the
/// list at once.
class PostsFeedController extends AsyncNotifier<FeedItems<Post>> {
  new(this.feed);

  final HomeFeed feed;

  String? _next;
  int _generation = 0;

  PostsRepository get _repo => ref.read(postsRepositoryProvider);

  @override
  Future<FeedItems<Post>> build() {
    ref
      ..watch(currentUserProvider.select((u) => u?.id))
      ..watch(postsRepositoryProvider);
    _generation++;
    return _first();
  }

  Future<FeedItems<Post>> _first() async {
    final page = await _repo.feed(feed.tab);
    _next = page.next;
    return FeedItems(_dedupe(const [], page.items), hasMore: _next != null);
  }

  /// Loads the next page when one exists and nothing is in flight or failed
  /// (prefetch calls this freely).
  Future<void> loadMore() async {
    final current = state.value;
    final cursor = _next;
    if (current == null ||
        state.isLoading ||
        cursor == null ||
        current.loadingMore ||
        current.loadMoreError != null) {
      return;
    }
    final generation = _generation;
    state = AsyncData(
      FeedItems(current.items, hasMore: true, loadingMore: true),
    );
    try {
      final page = await _repo.feed(feed.tab, cursor: cursor);
      if (!ref.mounted || generation != _generation) return;
      _next = page.next;
      state = AsyncData(
        FeedItems(
          _dedupe(state.requireValue.items, page.items),
          hasMore: _next != null,
        ),
      );
    } on Object catch (e) {
      if (!ref.mounted || generation != _generation) return;
      final failure = toAppFailure(e);
      if (_isBadCursor(failure)) {
        try {
          state = AsyncData(await _first());
        } on Object catch (e2) {
          if (!ref.mounted || generation != _generation) return;
          state = AsyncData(
            FeedItems(
              current.items,
              hasMore: true,
              loadMoreError: toAppFailure(e2),
            ),
          );
        }
        return;
      }
      state = AsyncData(
        FeedItems(current.items, hasMore: true, loadMoreError: failure),
      );
    }
  }

  /// "Retry" on the footer error.
  Future<void> retryLoadMore() async {
    final current = state.value;
    if (current == null || current.loadMoreError == null) return;
    state = AsyncData(FeedItems(current.items, hasMore: current.hasMore));
    await loadMore();
  }

  /// Drops [postId] from the list (hidden, reported or deleted).
  void remove(String postId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      FeedItems(
        [
          for (final p in current.items)
            if (p.id != postId) p,
        ],
        hasMore: current.hasMore,
        loadingMore: current.loadingMore,
        loadMoreError: current.loadMoreError,
      ),
    );
  }

  static bool _isBadCursor(AppFailure failure) =>
      failure is ServerFailure &&
      failure.code == ErrorCode.validationFailed &&
      failure.details.any((d) => d.field == 'cursor');

  static List<Post> _dedupe(List<Post> existing, List<Post> page) {
    final seen = {for (final p in existing) p.id};
    return List.unmodifiable([
      ...existing,
      for (final p in page)
        if (seen.add(p.id)) p,
    ]);
  }
}

final AsyncNotifierProviderFamily<
  PostsFeedController,
  FeedItems<Post>,
  HomeFeed
>
postsFeedProvider = AsyncNotifierProvider.family(PostsFeedController.new);

/// Removes [postId] from every loaded posts feed.
void removePostFromFeeds(WidgetRef ref, String postId) {
  for (final feed in HomeFeed.values) {
    if (ref.exists(postsFeedProvider(feed))) {
      ref.read(postsFeedProvider(feed).notifier).remove(postId);
    }
  }
}
