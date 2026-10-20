import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/features/debug/demo_data.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_stories_tray.dart';
import 'package:kabso_live/features/home/presentation/widgets/home_reel.dart';

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

// There is no posts, stories or reels API yet (posts Phase 3, short video
// Phase 5) and contracts are frozen for the design sprint (D34/D35), so
// production returns [FeedUnavailable] for every source — never sample
// content. Tests and the debug previews supply fixtures by overriding these
// providers; D86: test builds with Demo data on get labelled test data.
// They are not auto-disposed: switching modes never re-fetches.

/// Posts: the classic feed of photo, video and text posts, per [HomeFeed].
final FutureProviderFamily<FeedLoad<FeedPostData>, HomeFeed> homePostsProvider =
    FutureProvider.family<FeedLoad<FeedPostData>, HomeFeed>(
      (ref, feed) => watchDemo(ref)
          ? DemoData.posts(feed, ar: DemoData.arabic(ref))
          : const FeedUnavailable<FeedPostData>(),
    );

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
