import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/state/feed_load.dart';

/// One page of a cursor list (CONVENTIONS §5): the items and the next
/// cursor (null at the end).
typedef PageResult<T> = ({List<T> items, String? next});

/// A cursor-paged list: the first page on build, then [loadMore] for the
/// next one (deduplicated by [idOf]). A failed next page keeps what was
/// loaded and reports the error in the footer state.
abstract class PagedListController<T> extends AsyncNotifier<FeedItems<T>> {
  String? _next;

  /// Reads one page; [cursor] null = the first.
  Future<PageResult<T>> fetch(String? cursor);

  /// A stable id of [item].
  String idOf(T item);

  @override
  Future<FeedItems<T>> build() async {
    final page = await fetch(null);
    _next = page.next;
    return FeedItems(page.items, hasMore: _next != null);
  }

  /// The next page, when one exists and none is loading.
  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(FeedItems(s.items, hasMore: true, loadingMore: true));
    try {
      final page = await fetch(_next);
      if (!ref.mounted) return;
      _next = page.next;
      final known = {for (final item in s.items) idOf(item)};
      state = AsyncData(
        FeedItems([
          ...s.items,
          for (final item in page.items)
            if (!known.contains(idOf(item))) item,
        ], hasMore: _next != null),
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = AsyncData(FeedItems(s.items, hasMore: true, loadMoreError: e));
    }
  }

  /// Drops the item with [id] locally (answered, removed) without reloading.
  void remove(String id) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(
      FeedItems(
        [
          for (final item in s.items)
            if (idOf(item) != id) item,
        ],
        hasMore: s.hasMore,
        loadMoreError: s.loadMoreError,
      ),
    );
  }
}
