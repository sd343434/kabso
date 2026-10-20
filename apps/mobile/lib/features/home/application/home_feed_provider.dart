import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/features/debug/demo_data.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_stories_tray.dart';
import 'package:kabso_live/features/home/presentation/widgets/home_reel.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';

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
      return FeedItems(
        [for (final post in page.items) feedPostOf(post)],
        hasMore: page.hasMore,
        loadingMore: page.loadingMore,
        loadMoreError: page.loadMoreError,
      );
    });

/// Stories above the posts. The tray is drawn only for non-empty items, so
/// it is absent in production until a stories API exists.
final FutureProvider<FeedLoad<FeedStoryData>> homeStoriesProvider =
    FutureProvider(
      (ref) => watchDemo(ref)
          ? DemoData.stories(ar: DemoData.arabic(ref))
          : const FeedUnavailable<FeedStoryData>(),
    );

/// Reels: full-screen vertical short videos, per [HomeFeed].
final FutureProviderFamily<FeedLoad<FeedReelData>, HomeFeed> homeReelsProvider =
    FutureProvider.family<FeedLoad<FeedReelData>, HomeFeed>(
      (ref, feed) => watchDemo(ref)
          ? DemoData.reels(feed, ar: DemoData.arabic(ref))
          : const FeedUnavailable<FeedReelData>(),
    );
