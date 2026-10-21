import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:material_ui/material_ui.dart';

/// The longest query `GET /search` takes (CONVENTIONS §11.6).
const int maxSearchQuery = 64;

/// [raw] as `GET /search` takes it: trimmed, without one leading `@` or
/// `#`, at most [maxSearchQuery] characters; empty means "no search".
String normalizeSearchQuery(String raw) {
  var q = raw.trim();
  if (q.startsWith('@') || q.startsWith('#')) q = q.substring(1).trim();
  final chars = q.characters;
  return chars.length > maxSearchQuery
      ? chars.take(maxSearchQuery).toString()
      : q;
}

/// One search: what to look for and the normalized query.
typedef SearchKey = ({SearchType type, String query});

/// Search results, paged (`GET /search`, CONVENTIONS §11.6): people
/// ([UserSummary]), hashtags ([Hashtag]) or posts (as grid cells,
/// [ProfileGridItem]). Blocked users never appear (server).
class SearchResults extends AsyncNotifier<FeedItems<Object>> {
  new(this.key);

  final SearchKey key;
  String? _next;

  PostsRepository get _repo => ref.read(postsRepositoryProvider);

  Future<(List<Object>, String?)> _page(String? cursor) async {
    final q = key.query;
    switch (key.type) {
      case SearchType.users:
        final page = await _repo.searchPeople(q, cursor: cursor);
        return (<Object>[...page.items], page.next);
      case SearchType.hashtags:
        final page = await _repo.searchHashtags(q, cursor: cursor);
        return (<Object>[...page.items], page.next);
      case SearchType.posts:
        final page = await _repo.searchPosts(q, cursor: cursor);
        final removed = ref.read(removedPostsProvider);
        return (
          <Object>[
            for (final p in page.items)
              if (!removed.contains(p.id)) ProfileGridItem.ofPost(p),
          ],
          page.next,
        );
    }
  }

  static Object _id(Object o) => switch (o) {
    final UserSummary u => u.id,
    Hashtag(:final tag) => tag,
    ProfileGridItem(:final postId) => postId ?? o,
    _ => o,
  };

  @override
  Future<FeedItems<Object>> build() async {
    ref
      ..watch(postsRepositoryProvider)
      ..watch(currentUserProvider.select((u) => u?.id));
    if (key.query.isEmpty) return const FeedItems([]);
    final (items, next) = await _page(null);
    _next = next;
    return FeedItems(items, hasMore: next != null);
  }

  /// The next page, when one exists and none is loading.
  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(FeedItems(s.items, hasMore: true, loadingMore: true));
    try {
      final (items, next) = await _page(_next);
      if (!ref.mounted) return;
      _next = next;
      final known = {for (final o in s.items) _id(o)};
      state = AsyncData(
        FeedItems([
          ...s.items,
          for (final o in items)
            if (!known.contains(_id(o))) o,
        ], hasMore: next != null),
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = AsyncData(FeedItems(s.items, hasMore: true, loadMoreError: e));
    }
  }
}

final AsyncNotifierProviderFamily<SearchResults, FeedItems<Object>, SearchKey>
searchResultsProvider = AsyncNotifierProvider.autoDispose.family(
  SearchResults.new,
);

/// A hashtag and its visible post count (`GET /hashtags/{tag}`).
final FutureProviderFamily<Hashtag, String> hashtagProvider = FutureProvider
    .autoDispose
    .family((ref, tag) => ref.watch(postsRepositoryProvider).hashtag(tag));

/// One hashtag page's posts in one order.
typedef HashtagPostsKey = ({String tag, HashtagSort sort});

/// A hashtag's posts as grid cells (`GET /hashtags/{tag}/posts`), paged.
class HashtagPosts extends AsyncNotifier<FeedItems<ProfileGridItem>> {
  new(this.key);

  final HashtagPostsKey key;
  String? _next;

  List<ProfileGridItem> _cells(List<Post> posts) {
    final removed = ref.read(removedPostsProvider);
    return [
      for (final p in posts)
        if (!removed.contains(p.id)) ProfileGridItem.ofPost(p),
    ];
  }

  @override
  Future<FeedItems<ProfileGridItem>> build() async {
    final repo = ref.watch(postsRepositoryProvider);
    ref.watch(currentUserProvider.select((u) => u?.id));
    final page = await repo.hashtagPosts(key.tag, sort: key.sort);
    _next = page.next;
    return FeedItems(_cells(page.items), hasMore: _next != null);
  }

  /// The next page, when one exists and none is loading.
  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(FeedItems(s.items, hasMore: true, loadingMore: true));
    try {
      final page = await ref
          .read(postsRepositoryProvider)
          .hashtagPosts(key.tag, sort: key.sort, cursor: _next);
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
  HashtagPosts,
  FeedItems<ProfileGridItem>,
  HashtagPostsKey
>
hashtagPostsProvider = AsyncNotifierProvider.autoDispose.family(
  HashtagPosts.new,
);
