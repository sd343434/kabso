import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/feed_region.dart';
import 'package:kabso_live/app/shell/shell_navigation.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_stories_tray.dart';
import 'package:kabso_live/features/home/presentation/widgets/home_reel.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/stories/application/stories_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/reels`, the fourth shell tab (D48/D52/D53): Posts (default) and Reels,
/// each with the feeds Trending (default) and Following.
///
/// - The header has three words in the centre (D53): the feed tabs
///   Trending · Following and, past a short divider, the other mode's name
///   ("Reels" on Posts, "Posts" on Reels), which switches to it. The
///   selected feed is kept when the mode switches.
///   There is no Create button here: Create is the centre button of the
///   bottom bar on every tab (D52). Search sits at the start (owner, D55)
///   and opens Discover, where search will live; it is shown here although
///   `FeedTabsScaffold.searchAvailable` still hides it on the live hub.
/// - All four pages (2 modes × 2 feeds) stay alive in [IndexedStack]s:
///   each keeps its scroll position (and each reels pager its page), and
///   its provider is not re-fetched on a switch. Switching is by tap only,
///   so nothing competes with vertical scrolling or the reels pager.
/// - Posts are flat and full width (D54), under the stories tray (CP-008:
///   your entry first — open your stories or add one — then followed
///   accounts; a ring opens the story viewer). Reels are full-bleed and
///   dark; the header floats over the video on a scrim with light
///   status-bar icons.
/// - Posts and stories come from their APIs (KL-060, CP-008); reels have
///   no API before M2, so that mode shows its honest unavailable state
///   with a real way forward ("Watch live streams" opens Home, the live
///   hub). No content is invented (D39).
class FeedScreen extends StatefulWidget {
  const new({
    super.key,
    this.initialTab = HomeTab.initial,
    this.showSearch = true,
    this.showNotifications = true,
  });

  final HomeTab initialTab;

  /// Whether the header shows Search (D55: yes).
  final bool showSearch;

  /// Whether the header shows the notifications bell (CP-009: yes; the
  /// debug previews, which have no session, leave it out).
  final bool showNotifications;

  static const headerKey = Key('home.header');
  static const tabsKey = Key('home.tabs');
  static const searchKey = Key('home.search');
  static const switchKey = Key('home.switch');

  /// The page of one mode, holding its two feeds.
  static Key pageKey(HomeTab tab) => Key('home.page.${tab.name}');

  /// One feed of one mode.
  static Key feedKey(HomeTab tab, HomeFeed feed) =>
      Key('home.page.${tab.name}.${feed.name}');

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late HomeTab _tab = widget.initialTab;
  HomeFeed _feed = HomeFeed.initial;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final belowHeader = EdgeInsets.only(
      top: MediaQuery.paddingOf(context).top + KMetrics.topBarHeight,
    );
    final bar = SafeArea(
      bottom: false,
      child: _FeedHeader(
        tab: _tab,
        feed: _feed,
        showSearch: widget.showSearch,
        showNotifications: widget.showNotifications,
        onSwitch: () => setState(() => _tab = _tab.other),
        onFeed: (feed) {
          if (feed != _feed) setState(() => _feed = feed);
        },
      ),
    );
    // Reels follow the app theme like Posts (owner, 2026-10-26).
    final header = ColoredBox(
      key: FeedScreen.headerKey,
      color: p.background,
      child: bar,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: p.background,
        body: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(
                index: _tab.index,
                sizing: StackFit.expand,
                children: [
                  KeyedSubtree(
                    key: FeedScreen.pageKey(HomeTab.posts),
                    child: Padding(
                      padding: belowHeader,
                      child: _feeds(HomeTab.posts, (f) => _PostsPage(feed: f)),
                    ),
                  ),
                  KeyedSubtree(
                    key: FeedScreen.pageKey(HomeTab.reels),
                    child: Padding(
                      padding: belowHeader,
                      child: _feeds(HomeTab.reels, (f) => _ReelsPage(feed: f)),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(top: 0, left: 0, right: 0, child: header),
          ],
        ),
      ),
    );
  }

  /// The two feeds of [tab], both kept alive.
  Widget _feeds(HomeTab tab, Widget Function(HomeFeed feed) page) =>
      IndexedStack(
        index: _feed.index,
        sizing: StackFit.expand,
        children: [
          for (final feed in HomeFeed.values)
            KeyedSubtree(key: FeedScreen.feedKey(tab, feed), child: page(feed)),
        ],
      );
}

class _FeedHeader extends StatelessWidget {
  const new({
    required this.tab,
    required this.feed,
    required this.showSearch,
    required this.showNotifications,
    required this.onSwitch,
    required this.onFeed,
  });

  final HomeTab tab;
  final HomeFeed feed;
  final bool showSearch;
  final bool showNotifications;
  final VoidCallback onSwitch;
  final ValueChanged<HomeFeed> onFeed;

  /// Equal side insets keep the words centred on the screen; Search, when
  /// shown, sits in the start one and the bell in the end one.
  static const double _searchSlot = KSizes.minTouchTarget + KSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final reels = tab == HomeTab.reels;
    return SizedBox(
      height: KMetrics.topBarHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: showSearch || showNotifications
                    ? _searchSlot
                    : KSpacing.xs,
              ),
              child: KPrimaryTabs(
                key: FeedScreen.tabsKey,
                centered: true,
                labels: [l10n.homeFeedTrending, l10n.feedTabFollowing],
                selectedIndex: feed.index,
                onSelected: (i) => onFeed(HomeFeed.values[i]),
                // The other mode's name switches to it (D53).
                action: KTabAction(
                  key: FeedScreen.switchKey,
                  label: reels ? l10n.homeTabPosts : l10n.homeTabReels,
                  semanticLabel: reels
                      ? l10n.homeShowPosts
                      : l10n.homeShowReels,
                  onTap: onSwitch,
                ),
              ),
            ),
          ),
          if (showSearch)
            PositionedDirectional(
              start: KSpacing.xs,
              top: 0,
              bottom: 0,
              child: IconButton(
                key: FeedScreen.searchKey,
                tooltip: l10n.feedSearch,
                constraints: const BoxConstraints.tightFor(
                  width: KSizes.minTouchTarget,
                  height: KSizes.minTouchTarget,
                ),
                onPressed: () => context.push(AppRoutes.discover),
                icon: AppIcon(
                  AppIcons.search,
                  size: KMetrics.iconMd,
                  color: p.textPrimary,
                ),
              ),
            ),
          if (showNotifications)
            const PositionedDirectional(
              end: KSpacing.xs,
              top: 0,
              bottom: 0,
              child: NotificationsBell(),
            ),
        ],
      ),
    );
  }
}

/// The way forward from an empty or unavailable feed: "Watch live
/// streams" opens Home (the live hub) on Popular; from Following, "See
/// who's live" opens it on Following.
(String, VoidCallback) _liveAction(
  BuildContext context,
  WidgetRef ref,
  HomeFeed feed,
) => switch (feed) {
  HomeFeed.trending => (
    context.l10n.homeWatchLive,
    () => openLiveHub(context, ref, FeedTab.popular),
  ),
  HomeFeed.following => (
    context.l10n.homeSeeWhoIsLive,
    () => openLiveHub(context, ref, FeedTab.following),
  ),
};

/// Gap between two posts.
const _postGap = SizedBox(height: KPostCard.gap);

Widget _postsSkeleton(BuildContext context) => SliverList.separated(
  itemCount: 3,
  itemBuilder: (_, _) => const FeedPostSkeleton(),
  separatorBuilder: (_, _) => _postGap,
);

class _PostsPage extends ConsumerWidget {
  const new({required this.feed});

  final HomeFeed feed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final (actionLabel, action) = _liveAction(context, ref, feed);
    final following = feed == HomeFeed.following;
    final stories = ref.watch(homeStoriesProvider).value;
    final source = homePostsProvider(feed);
    final content = ref.watch(source);
    return FeedRegion<FeedPostData>(
      key: PageStorageKey('home.posts.${feed.name}'),
      content: content,
      copy: FeedRegionCopy(
        unavailableIcon: Icons.dynamic_feed_outlined,
        unavailableTitle: following
            ? l10n.homeFollowingUnavailableTitle
            : l10n.homePopularUnavailableTitle,
        unavailableBody: following
            ? l10n.homeFollowingUnavailableBody
            : l10n.homePopularUnavailableBody,
        unavailableActionLabel: actionLabel,
        unavailableActionIcon: Icons.sensors_rounded,
        onUnavailableAction: action,
        emptyIcon: Icons.dynamic_feed_outlined,
        emptyTitle: following
            ? l10n.homeFollowingEmptyTitle
            : l10n.homeEmptyTitle,
        emptyBody: l10n.feedPullToRefresh,
        emptyActionLabel: actionLabel,
        emptyActionIcon: Icons.sensors_rounded,
        onEmptyAction: action,
        errorTitle: l10n.homeErrorTitle,
        loadMoreFailed: l10n.feedPostsLoadMoreFailed,
      ),
      onRefresh: () {
        ref
          ..invalidate(storyTrayProvider)
          ..invalidate(homeStoriesProvider)
          ..invalidate(postsFeedProvider(feed));
        return ref.refresh(source.future);
      },
      onRetry: () => ref
        ..invalidate(postsFeedProvider(feed))
        ..invalidate(source),
      // Only a real paginated source has a next page (fixtures never do).
      onLoadMore: () {
        if (content.value case FeedItems(hasMore: true)) {
          unawaited(ref.read(postsFeedProvider(feed).notifier).loadMore());
        }
      },
      onRetryLoadMore: () =>
          unawaited(ref.read(postsFeedProvider(feed).notifier).retryLoadMore()),
      footerLoadingSliver: const SliverToBoxAdapter(child: FeedPostSkeleton()),
      loadingSliver: _postsSkeleton(context),
      itemsSliver: (posts) => SliverMainAxisGroup(
        slivers: [
          if (stories case FeedItems(:final items) when items.isNotEmpty)
            SliverToBoxAdapter(
              child: FeedStoriesTray(
                stories: items,
                onOpen: (s) => context.push(AppRoutes.stories(s.username!)),
                onAdd: () => context.push(AppRoutes.newStory),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.only(
              top: KSpacing.xs,
              bottom: KSpacing.lg,
            ),
            sliver: SliverList.separated(
              itemCount: posts.length,
              itemBuilder: (_, i) => FeedPostTile(post: posts[i]),
              separatorBuilder: (_, _) => _postGap,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelsPage extends ConsumerWidget {
  const new({required this.feed});

  final HomeFeed feed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final (actionLabel, action) = _liveAction(context, ref, feed);
    final following = feed == HomeFeed.following;
    final source = homeReelsProvider(feed);
    return FeedRegion<FeedReelData>(
      key: PageStorageKey('home.reels.${feed.name}'),
      content: ref.watch(source),
      copy: FeedRegionCopy(
        unavailableIcon: Icons.smart_display_outlined,
        unavailableTitle: following
            ? l10n.homeReelsFollowingUnavailableTitle
            : l10n.homeReelsUnavailableTitle,
        unavailableBody: following
            ? l10n.homeReelsFollowingUnavailableBody
            : l10n.homeReelsUnavailableBody,
        unavailableActionLabel: actionLabel,
        unavailableActionIcon: Icons.sensors_rounded,
        onUnavailableAction: action,
        emptyIcon: Icons.smart_display_outlined,
        emptyTitle: following
            ? l10n.homeReelsFollowingEmptyTitle
            : l10n.homeReelsEmptyTitle,
        emptyBody: l10n.feedPullToRefresh,
        emptyActionLabel: actionLabel,
        emptyActionIcon: Icons.sensors_rounded,
        onEmptyAction: action,
        errorTitle: l10n.homeReelsErrorTitle,
      ),
      onRefresh: () => ref.refresh(source.future),
      onRetry: () => ref.invalidate(source),
      loadingSliver: const SliverFillRemaining(
        hasScrollBody: false,
        child: KSkeleton(width: double.infinity, height: double.infinity),
      ),
      // The pager fills the region; pull-to-refresh belongs to the outer
      // region, the vertical swipe to the pager.
      itemsSliver: (reels) => SliverFillRemaining(
        child: HomeReelsPager(
          reels: reels,
          storageKey: 'home.reels.pager.${feed.name}',
        ),
      ),
    );
  }
}
