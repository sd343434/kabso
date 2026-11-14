import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/stories/data/stories_repository.dart';
import 'package:kabso_live/features/stories/domain/story_models.dart';

/// How many tray entries the Posts page asks for (one page; the tray is a
/// short row of rings).
const int storyTrayLimit = 50;

/// The stories tray from `GET /feed/stories` (CP-008): the caller first
/// when they have an active story, then followed accounts, unseen first.
final FutureProvider<List<StoryTrayItem>> storyTrayProvider = FutureProvider((
  ref,
) async {
  ref.watch(currentUserProvider.select((u) => u?.id));
  final page = await ref
      .watch(storiesRepositoryProvider)
      .tray(limit: storyTrayLimit);
  return page.items;
});

/// D130: the Moments tab's dot — someone the caller follows has a story
/// the caller has not seen (`hasUnseen` in the stories tray, the caller's
/// own entry left out). False while the tray loads or when it fails (no
/// dot is ever guessed).
final Provider<bool> unseenFollowedStoriesProvider = Provider<bool>((ref) {
  final me = ref.watch(currentUserProvider.select((u) => u?.id));
  final tray = ref.watch(storyTrayProvider).value;
  if (me == null || tray == null) return false;
  return tray.any((item) => item.hasUnseen && item.user.id != me);
});

/// One account's active stories, oldest first.
final FutureProviderFamily<List<Story>, String> userStoriesProvider =
    FutureProvider.autoDispose.family(
      (ref, username) =>
          ref.watch(storiesRepositoryProvider).userStories(username),
    );

/// The caller's story archive (`GET /me/stories/archive`), newest first,
/// paged.
class StoryArchive extends AsyncNotifier<FeedItems<Story>> {
  String? _next;

  @override
  Future<FeedItems<Story>> build() async {
    final repo = ref.watch(storiesRepositoryProvider);
    ref.watch(currentUserProvider.select((u) => u?.id));
    final page = await repo.archive();
    _next = page.next;
    return FeedItems(page.items, hasMore: _next != null);
  }

  /// The next page, when one exists and none is loading.
  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(FeedItems(s.items, hasMore: true, loadingMore: true));
    try {
      final page = await ref
          .read(storiesRepositoryProvider)
          .archive(cursor: _next);
      if (!ref.mounted) return;
      _next = page.next;
      final known = {for (final x in s.items) x.id};
      state = AsyncData(
        FeedItems([
          ...s.items,
          for (final x in page.items)
            if (!known.contains(x.id)) x,
        ], hasMore: _next != null),
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = AsyncData(FeedItems(s.items, hasMore: true, loadMoreError: e));
    }
  }

  /// Drops [storyId] (deleted).
  void remove(String storyId) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(
      FeedItems([
        for (final x in s.items)
          if (x.id != storyId) x,
      ], hasMore: s.hasMore),
    );
  }
}

final AsyncNotifierProvider<StoryArchive, FeedItems<Story>>
storyArchiveProvider = AsyncNotifierProvider.autoDispose(StoryArchive.new);
