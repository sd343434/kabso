import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';

/// Which of the caller's unpublished posts (`GET /me/posts?status=`).
enum MyPostsList {
  drafts('DRAFT'),
  scheduled('SCHEDULED');

  new(this.status);

  /// The `status` the API takes.
  final String status;
}

/// The caller's drafts (newest first) or scheduled posts (soonest first),
/// paged. A post published, moved or deleted in this session leaves the
/// list it no longer belongs to.
class MyPosts extends AsyncNotifier<FeedItems<Post>> {
  new(this.list);

  final MyPostsList list;
  String? _next;

  List<Post> _keep(List<Post> posts) {
    final removed = ref.read(removedPostsProvider);
    final edits = ref.read(postEditsProvider);
    return [
      for (final p in posts)
        if (!removed.contains(p.id) &&
            (edits[p.id]?.status ?? p.status) == list.status)
          edits[p.id] ?? p,
    ];
  }

  @override
  Future<FeedItems<Post>> build() async {
    final repo = ref.watch(postsRepositoryProvider);
    ref
      ..watch(currentUserProvider.select((u) => u?.id))
      ..listen(removedPostsProvider, (_, _) => _refilter())
      ..listen(postEditsProvider, (_, _) => _refilter());
    final page = await repo.myPosts(list.status);
    _next = page.next;
    return FeedItems(_keep(page.items), hasMore: _next != null);
  }

  void _refilter() {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(
      FeedItems(
        _keep(s.items),
        hasMore: s.hasMore,
        loadingMore: s.loadingMore,
        loadMoreError: s.loadMoreError,
      ),
    );
  }

  /// The next page, when one exists and none is loading.
  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(FeedItems(s.items, hasMore: true, loadingMore: true));
    try {
      final page = await ref
          .read(postsRepositoryProvider)
          .myPosts(list.status, cursor: _next);
      if (!ref.mounted) return;
      _next = page.next;
      final known = {for (final p in s.items) p.id};
      state = AsyncData(
        FeedItems([
          ...s.items,
          for (final p in _keep(page.items))
            if (!known.contains(p.id)) p,
        ], hasMore: _next != null),
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = AsyncData(FeedItems(s.items, hasMore: true, loadMoreError: e));
    }
  }
}

final AsyncNotifierProviderFamily<MyPosts, FeedItems<Post>, MyPostsList>
myPostsProvider = AsyncNotifierProvider.autoDispose.family(MyPosts.new);
