import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/follows/data/follow_lists_repository.dart';
import 'package:kabso_live/features/follows/domain/follow_list_models.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/application/public_profile_controller.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';

/// Which list: a user's followers or following, the search ('' = none) and
/// the order (D125).
typedef FollowListKey = ({
  String username,
  FollowListKind kind,
  String query,
  FollowListOrder order,
});

/// The list of [username]'s [kind] for [query] in [order].
FollowListKey followListKey(
  String username,
  FollowListKind kind, {
  String query = '',
  FollowListOrder order = FollowListOrder.newest,
}) => (username: username, kind: kind, query: query, order: order);

/// One follow list (D121), newest follow first (D125: or oldest first, and
/// searched by name), paged (CONVENTIONS §5), with an optimistic Follow /
/// Unfollow per row; on your own lists, removing a follower and dropping a
/// row you unfollowed or blocked (D125).
class FollowListController extends AsyncNotifier<FeedItems<FollowListItem>> {
  new(this.key);

  final FollowListKey key;
  String? _next;
  final Set<String> _busy = {};

  @override
  Future<FeedItems<FollowListItem>> build() async {
    final repo = ref.watch(followListsRepositoryProvider);
    ref.watch(currentUserProvider.select((u) => u?.id));
    _busy.clear();
    final page = await repo.list(
      key.username,
      key.kind,
      query: key.query.isEmpty ? null : key.query,
      order: key.order,
    );
    _next = page.next;
    return FeedItems(page.items, hasMore: _next != null);
  }

  /// Whether a follow / unfollow of the row [id] is in flight.
  bool isBusy(String id) => _busy.contains(id);

  /// The next page, when one exists and none is loading. Rows already shown
  /// are skipped (a follow can move between pages, §10.4).
  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(FeedItems(s.items, hasMore: true, loadingMore: true));
    try {
      final page = await ref
          .read(followListsRepositoryProvider)
          .list(
            key.username,
            key.kind,
            cursor: _next,
            query: key.query.isEmpty ? null : key.query,
            order: key.order,
          );
      if (!ref.mounted) return;
      _next = page.next;
      final current = state.value?.items ?? s.items;
      final known = {for (final u in current) u.id};
      state = AsyncData(
        FeedItems([
          ...current,
          for (final u in page.items)
            if (!known.contains(u.id)) u,
        ], hasMore: _next != null),
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      final current = state.value?.items ?? s.items;
      state = AsyncData(FeedItems(current, hasMore: true, loadMoreError: e));
    }
  }

  void _replace(
    String id, {
    required bool followedByMe,
    bool requestedByMe = false,
  }) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(
      FeedItems(
        [
          for (final u in s.items)
            if (u.id == id)
              u.withFollowedByMe(
                followedByMe: followedByMe,
                requestedByMe: requestedByMe,
              )
            else
              u,
        ],
        hasMore: s.hasMore,
        loadingMore: s.loadingMore,
        loadMoreError: s.loadMoreError,
      ),
    );
  }

  /// Takes the row [id] out of the list (unfollowed or blocked from your
  /// own list, D125).
  void drop(String id) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(
      FeedItems(
        [
          for (final u in s.items)
            if (u.id != id) u,
        ],
        hasMore: s.hasMore,
        loadingMore: s.loadingMore,
        loadMoreError: s.loadMoreError,
      ),
    );
  }

  void _countsMoved(String username) => ref
    ..invalidate(profileStatsProvider)
    ..invalidate(publicProfileProvider(username))
    ..invalidate(publicProfileProvider(key.username));

  /// D125: removes [item] from your followers (`DELETE /me/followers/…`);
  /// the row leaves the list once the server agrees. Throws an `AppFailure`
  /// (nothing changes). Ignored while that row is busy.
  Future<void> removeFollower(FollowListItem item) async {
    if (_busy.contains(item.id)) return;
    _busy.add(item.id);
    try {
      await ref
          .read(followListsRepositoryProvider)
          .removeFollower(item.username);
      if (!ref.mounted) return;
      drop(item.id);
      _countsMoved(item.username);
    } finally {
      _busy.remove(item.id);
    }
  }

  /// Follows ([follow] true) or unfollows the row [item]. The row changes at
  /// once; on failure it is restored and the `AppFailure` rethrown for the
  /// screen to show. Ignored while that row is busy, when nothing would
  /// change, or when the row offers no control (yourself).
  ///
  /// v1.47-social (D175): following a private account sends a request (the
  /// row says "Requested"); [follow] false on such a row cancels it.
  Future<void> setFollowing(FollowListItem item, {required bool follow}) async {
    final row = state.value?.items.where((u) => u.id == item.id).firstOrNull;
    final active = row != null && (row.followedByMe || row.requestedByMe);
    if (row == null || _busy.contains(row.id) || active == follow) {
      return;
    }
    if (!row.canToggle) return;
    _busy.add(row.id);
    _replace(
      row.id,
      followedByMe: follow && !row.isPrivate,
      requestedByMe: follow && row.isPrivate,
    );
    try {
      final repo = ref.read(profileRepositoryProvider);
      final result = follow
          ? await repo.follow(row.username)
          : await repo.unfollow(row.username);
      if (!ref.mounted) return;
      _replace(
        row.id,
        followedByMe: result.isFollowing,
        requestedByMe: result.isRequested,
      );
      // The counts on the profiles behind this screen move too.
      _countsMoved(row.username);
    } on Object {
      if (ref.mounted) {
        _replace(
          row.id,
          followedByMe: row.followedByMe,
          requestedByMe: row.requestedByMe,
        );
      }
      rethrow;
    } finally {
      _busy.remove(row.id);
    }
  }
}

final AsyncNotifierProviderFamily<
  FollowListController,
  FeedItems<FollowListItem>,
  FollowListKey
>
followListProvider = AsyncNotifierProvider.autoDispose.family(
  FollowListController.new,
);
