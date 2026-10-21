import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/debug/demo_data.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_stories_tray.dart';
import 'package:kabso_live/features/home/presentation/widgets/home_reel.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/stories/application/stories_controller.dart';
import 'package:kabso_live/features/stories/domain/story_models.dart';
import 'package:material_ui/material_ui.dart';

/// The two modes of the Reels shell tab (D52): Posts (default) and Reels,
/// switched by the header button next to Create.
enum HomeTab {
  posts,
  reels;

  static const HomeTab initial = posts;

  HomeTab get other => this == posts ? reels : posts;
}

/// The two feeds of each mode (D53), chosen with the header tabs: Trending
/// (default; works for a new account that follows no one) and Following.
enum HomeFeed {
  trending,
  following;

  static const HomeFeed initial = trending;
}

// Posts come from the real API (v1.5-social, CONVENTIONS §11.3) through
// [postsFeedProvider]; there is no stories or reels API yet (stories M3,
// short video M2), so those return [FeedUnavailable] — never sample
// content. Tests and the debug previews supply fixtures by overriding these
// providers; D86: test builds with Demo data on get labelled test data.
// They are not auto-disposed: switching modes never re-fetches.

/// Posts: the feed of photo and text posts, per [HomeFeed], with its
/// pagination footer state. Load more through [postsFeedProvider].
final FutureProviderFamily<FeedLoad<FeedPostData>, HomeFeed> homePostsProvider =
    FutureProvider.family<FeedLoad<FeedPostData>, HomeFeed>((ref, feed) async {
      if (watchDemo(ref)) return DemoData.posts(feed, ar: DemoData.arabic(ref));
      final page = await ref.watch(postsFeedProvider(feed).future);
      final edits = ref.watch(postEditsProvider);
      return FeedItems(
        [
          for (final post in page.items)
            feedPostOf(edits[post.id] ?? post, repostedBy: post.repostedBy),
        ],
        hasMore: page.hasMore,
        loadingMore: page.loadingMore,
        loadMoreError: page.loadMoreError,
      );
    });

/// Stories above the posts (CP-008, `GET /feed/stories`): the caller's
/// own entry first — their stories, or "Your story" to add one — then the
/// followed accounts with active stories, unseen first. A failed tray
/// loads as unavailable: it never hides the posts.
final FutureProvider<FeedLoad<FeedStoryData>> homeStoriesProvider =
    FutureProvider((ref) async {
      if (watchDemo(ref)) return DemoData.stories(ar: DemoData.arabic(ref));
      final me = ref.watch(currentUserProvider);
      final List<StoryTrayItem> tray;
      try {
        tray = await ref.watch(storyTrayProvider.future);
      } on Object {
        return const FeedUnavailable<FeedStoryData>();
      }
      FeedStoryData entry(StoryTrayItem i) => FeedStoryData(
        authorName: i.user.displayName.isEmpty
            ? i.user.username
            : i.user.displayName,
        authorAvatar: switch (i.user.avatarUrl) {
          final url? => NetworkImage(url),
          null => null,
        },
        seen: !i.hasUnseen,
        username: i.user.username,
        isSelf: i.user.id == me?.id,
      );
      final own = [
        for (final i in tray)
          if (i.user.id == me?.id) entry(i),
      ];
      return FeedItems([
        if (own.isNotEmpty)
          ...own
        else if (me != null)
          FeedStoryData(
            authorName: me.displayName.isEmpty ? me.username : me.displayName,
            authorAvatar: switch (me.avatarUrl) {
              final url? => NetworkImage(url),
              null => null,
            },
            username: me.username,
            isSelf: true,
            hasStory: false,
          ),
        for (final i in tray)
          if (i.user.id != me?.id) entry(i),
      ]);
    });

/// Reels: full-screen vertical short videos, per [HomeFeed].
final FutureProviderFamily<FeedLoad<FeedReelData>, HomeFeed> homeReelsProvider =
    FutureProvider.family<FeedLoad<FeedReelData>, HomeFeed>(
      (ref, feed) => watchDemo(ref)
          ? DemoData.reels(feed, ar: DemoData.arabic(ref))
          : const FeedUnavailable<FeedReelData>(),
    );
