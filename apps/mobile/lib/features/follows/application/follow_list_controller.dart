import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/follows/data/follow_lists_repository.dart';
import 'package:kabso_live/features/follows/domain/follow_list_models.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/application/public_profile_controller.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';

/// Which list: a user's followers or following.
typedef FollowListKey = ({String username, FollowListKind kind});

/// One follow list (D121), newest follow first, paged (CONVENTIONS §5),
/// with an optimistic Follow / Unfollow per row.
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
    final page = await repo.list(key.username, key.kind);
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
          .list(key.username, key.kind, cursor: _next);
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

  void _replace(String id, {required bool followedByMe}) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(
      FeedItems(
        [
          for (final u in s.items)
            if (u.id == id)
              u.withFollowedByMe(followedByMe: followedByMe)
            else
              u,
        ],
        hasMore: s.hasMore,
        loadingMore: s.loadingMore,
        loadMoreError: s.loadMoreError,
      ),
    );
  }

  /// Follows ([follow] true) or unfollows the row [item]. The row changes at
  /// once; on failure it is restored and the `AppFailure` rethrown for the
  /// screen to show. Ignored while that row is busy, when nothing would
  /// change, or when the row offers no control (yourself; a private account
  /// you do not follow).
  Future<void> setFollowing(FollowListItem item, {required bool follow}) async {
    final row = state.value?.items.where((u) => u.id == item.id).firstOrNull;
    if (row == null || _busy.contains(row.id) || row.followedByMe == follow) {
      return;
    }
    if (!row.canToggle) return;
    _busy.add(row.id);
    _replace(row.id, followedByMe: follow);
    try {
      final repo = ref.read(profileRepositoryProvider);
      final result = follow
          ? await repo.follow(row.username)
          : await repo.unfollow(row.username);
      if (!ref.mounted) return;
      _replace(row.id, followedByMe: result.isFollowing);
      // The counts on the profiles behind this screen move too.
      ref
        ..invalidate(profileStatsProvider)
        ..invalidate(publicProfileProvider(row.username))
        ..invalidate(publicProfileProvider(key.username));
    } on Object {
      if (ref.mounted) _replace(row.id, followedByMe: row.followedByMe);
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
