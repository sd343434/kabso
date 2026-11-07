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

/// `/reels`, the fourth shell tab (D48/D52/D53): Posts (default) and Reels.
///
/// D218 (owner, after a reference: «بهذا التصميم حرفياً مع اضافة ميزاتنا»):
/// Posts keeps its bar of before (Search, the centred words, the bell —
/// owner's follow-up «واجعل زر البحث والاشعارات مثل ما كانو بالاول»); the
/// words are «المنشورات» and the switch «الريلز». Posts has one feed: the
/// server's 1 Following : 2 Trending mix (`GET /feed/posts?tab=mixed`, CONVENTIONS
/// §10.73). The stories tray sits above every posts state (D218: it was
/// drawn only above a non-empty feed, so a new account never saw it).
///
/// D294 (owner, from screenshots of both pages: «اجعل فلتر فقط منشورات
/// وريلز»): the reels page has the posts page's bar — Search, the toggle
/// «المنشورات | الريلز» (here «الريلز» selected; «المنشورات» goes back) and
/// the bell — floating over the video on a scrim. Its tabs Following · For
/// You · Nearby (D202) and its «المنشورات» chip are gone, and so is Nearby
/// (with its «اختر بلدك» prompt): Reels has one feed, the same 1 : 2 mix
/// over reels (`GET /feed/reels?tab=mixed`, CONVENTIONS §10.107).
///
/// - Both pages stay alive in an [IndexedStack]: each keeps its scroll
///   position (and the reels pager its page), and its provider is not
///   re-fetched on a switch. Switching is by tap only, so nothing competes
///   with vertical scrolling or the reels pager. There is no Create button
///   here: Create is the centre button of the bottom bar on every tab
///   (D52). Search sits at the start (owner, D55) and opens Discover.
/// - Posts are flat and full width (D54), under the stories tray (CP-008:
///   your entry first — open your stories or add one — then followed
///   accounts; a ring opens the story viewer); D294: no line between posts.
///   Reels are full-bleed and dark in both app themes (D202), with light
///   status-bar icons. D298 (owner: «اجعل الريلز بحجم الشاشة»): the video
///   runs from the very top (behind the status bar) to the bottom bar; the
///   header floats over it on a soft scrim that fades out to nothing, so
///   no dark band marks where the video "starts".
/// - Posts, stories and (v1.41-social, D162) reels come from their APIs
///   (KL-060, CP-008, `GET /feed/reels`); an empty or failed feed shows
///   its honest state with a real way forward ("Watch live streams" opens
///   Home, the live hub). No content is invented (D39).
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

  /// D298: the reels page's soft top scrim under the floating header.
  static const reelsScrimKey = Key('home.reels.scrim');
  static const tabsKey = Key('home.tabs');
  static const searchKey = Key('home.search');

  /// The other page's word in the toggle: «الريلز» on Posts, «المنشورات» on
  /// Reels (D53, D294).
  static const switchKey = Key('home.switch');

  /// The page of one mode.
  static Key pageKey(HomeTab tab) => Key('home.page.${tab.name}');

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late HomeTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reels = _tab == HomeTab.reels;
    final belowHeader = EdgeInsets.only(
      top: KTopInset.of(context) + KMetrics.topBarHeight,
    );
    final bar = KTopSafeArea(
      child: _ModeTopBar(
        tab: _tab,
        showSearch: widget.showSearch,
        showNotifications: widget.showNotifications,
        onSwitch: () => setState(() => _tab = _tab.other),
      ),
    );
    final header = reels
        // D294: the posts page's bar over the video; D298: no band of its
        // own — it floats on the soft scrim below.
        ? _ReelsTheme(
            child: KeyedSubtree(key: FeedScreen.headerKey, child: bar),
          )
        // Posts follow the app theme (owner, 2026-10-26).
        : ColoredBox(
            key: FeedScreen.headerKey,
            color: p.background,
            child: bar,
          );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: reels || Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: reels ? KPalette.dark.background : p.background,
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
                      child: const _PostsPage(),
                    ),
                  ),
                  // D202: reels are full bleed and always dark (video).
                  KeyedSubtree(
                    key: FeedScreen.pageKey(HomeTab.reels),
                    child: const _ReelsTheme(child: _ReelsPage()),
                  ),
                ],
              ),
            ),
            // D298: a sibling of the header (not inside it), so it can run
            // past the bar and fade out instead of being clipped to it.
            if (reels)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: KReelsHeader.scrimHeight(context),
                child: const _ReelsScrim(key: FeedScreen.reelsScrimKey),
              ),
            Positioned(top: 0, left: 0, right: 0, child: header),
          ],
        ),
      ),
    );
  }
}

/// D202: the reels page is dark in both app themes (it sits on video).
class _ReelsTheme extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
    data: buildAppTheme(
      brightness: Brightness.dark,
      locale: Localizations.localeOf(context),
    ),
    child: child,
  );
}

/// D202 / D294 / D298 geometry of the reels header: the bar's scrim and
/// the video's speaker button under it.
abstract final class KReelsHeader {
  /// D298: the scrim runs this far under the bar's 48 dp row, fading to
  /// fully transparent (D202's ran 8 dp and stopped at 25 % black, which
  /// read as a solid band over the video).
  static const double scrimBelow = 120;

  /// The scrim's height: the status bar, the gap, the bar and the fade.
  static double scrimHeight(BuildContext context) =>
      KTopInset.of(context) + KMetrics.topBarHeight + scrimBelow;

  /// D298: the scrim's black at its top edge (70 %).
  static const double scrimTopOpacity = 0.7;

  /// The scrim's opacity [t] of the way down: a smoothstep from
  /// [scrimTopOpacity] to 0, flat at both ends so no edge shows.
  static double scrimOpacityAt(double t) {
    final x = t.clamp(0.0, 1.0);
    return scrimTopOpacity * (1 - x * x * (3 - 2 * x));
  }

  /// The gradient's stops (evenly spaced samples of [scrimOpacityAt]).
  static const int scrimStops = 9;

  /// D294: the video's speaker button (a 48 dp target) starts this far
  /// under the bar, at the reading end (D202 aligned it with the chips row,
  /// which is gone).
  static const double muteGap = KSpacing.sm;

  /// Where the video's speaker button's 48 dp target starts.
  static double muteTop(BuildContext context) =>
      KTopInset.of(context) + KMetrics.topBarHeight + muteGap;
}

/// D202 / D298: the scrim behind the reels page's floating bar, so white
/// text reads over a bright video: dark at the top (behind the status bar),
/// still dark under the bar's row, then an eased fade to nothing — no edge.
class _ReelsScrim extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    const n = KReelsHeader.scrimStops;
    final stops = [for (var i = 0; i < n; i++) i / (n - 1)];
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: stops,
            colors: [
              for (final t in stops)
                Color.fromRGBO(0, 0, 0, KReelsHeader.scrimOpacityAt(t)),
            ],
          ),
        ),
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

/// Gap between two posts (D294: air only, no line).
const _postGap = SizedBox(height: KPostCard.feedGap);

Widget _postsSkeleton(BuildContext context) => SliverList.separated(
  itemCount: 3,
  itemBuilder: (_, _) => const FeedPostSkeleton(),
  separatorBuilder: (_, _) => _postGap,
);

/// The posts top bar — owner (after D218): «ازل صورة والاسم في الاعلى واجعل
/// زر البحث والاشعارات مثل ما كانو بالاول». The bar of before D218: a 48 dp
/// row with Search at the reading start and the notifications bell at the
/// end, each a 48 dp target in an equal inset; between them, centred, the
/// page's word «المنشورات» (selected; Posts has one feed since D218, the
/// server's mix) and, where the old bar had its third control, the switch
/// word «الريلز» that opens Reels (D53).
///
/// D294: the reels page draws the same bar (in its dark theme): the same
/// words in the same order, «المنشورات | الريلز», with «الريلز» selected and
/// «المنشورات» the switch back.
class _ModeTopBar extends StatelessWidget {
  const new({
    required this.tab,
    required this.showSearch,
    required this.showNotifications,
    required this.onSwitch,
  });

  final HomeTab tab;
  final bool showSearch;
  final bool showNotifications;
  final VoidCallback onSwitch;

  /// Equal side insets keep the words centred on the screen.
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
                labels: [if (reels) l10n.homeTabReels else l10n.homeTabPosts],
                selectedIndex: 0,
                onSelected: (_) {},
                // The other mode's name switches to it (D53); on Reels it
                // comes first, so the words read «المنشورات | الريلز» on both.
                actionFirst: reels,
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

/// D218: the posts page — the stories tray above the server's 1 Following
/// : 2 Trending mix, in every state of the feed.
class _PostsPage extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final (actionLabel, action) = _liveAction(context, ref, HomeFeed.trending);
    final stories = ref.watch(homeStoriesProvider).value;
    final source = homeMixedPostsProvider;
    final content = ref.watch(source);
    return FeedRegion<FeedPostData>(
      key: const PageStorageKey('home.posts.mixed'),
      content: content,
      leading: switch (stories) {
        FeedItems(:final items) when items.isNotEmpty => SliverToBoxAdapter(
          child: FeedStoriesTray(
            stories: items,
            onOpen: (s) => context.push(AppRoutes.stories(s.username!)),
            onAdd: () => context.push(AppRoutes.newStory),
            onOpenLive: (room) => context.push(AppRoutes.liveRoom(room)),
          ),
        ),
        _ => null,
      },
      copy: FeedRegionCopy(
        unavailableIcon: Icons.dynamic_feed_outlined,
        unavailableTitle: l10n.homePopularUnavailableTitle,
        unavailableBody: l10n.homePopularUnavailableBody,
        unavailableActionLabel: actionLabel,
        unavailableActionIcon: Icons.sensors_rounded,
        onUnavailableAction: action,
        emptyIcon: Icons.dynamic_feed_outlined,
        emptyTitle: l10n.homeEmptyTitle,
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
          ..invalidate(followedLiveNowProvider)
          ..invalidate(homeStoriesProvider)
          ..invalidate(mixedPostsFeedProvider);
        return ref.refresh(source.future);
      },
      onRetry: () => ref
        ..invalidate(mixedPostsFeedProvider)
        ..invalidate(source),
      // Only a real paginated source has a next page (fixtures never do).
      onLoadMore: () {
        if (content.value case FeedItems(hasMore: true)) {
          unawaited(ref.read(mixedPostsFeedProvider.notifier).loadMore());
        }
      },
      onRetryLoadMore: () =>
          unawaited(ref.read(mixedPostsFeedProvider.notifier).retryLoadMore()),
      footerLoadingSliver: const SliverToBoxAdapter(child: FeedPostSkeleton()),
      loadingSliver: _postsSkeleton(context),
      itemsSliver: (posts) => SliverPadding(
        padding: const EdgeInsets.only(bottom: KSpacing.lg),
        sliver: SliverList.separated(
          itemCount: posts.length,
          // D294 (owner: «لماذا الخط أسفل البوست؟ أزله»): no line under a
          // post on the feed.
          itemBuilder: (_, i) =>
              FeedPostTile(post: posts[i], closingDivider: false),
          separatorBuilder: (_, _) => _postGap,
        ),
      ),
    );
  }
}

/// D294 (v1.92-social, CONVENTIONS §10.107): the reels page's one feed —
/// the server's 1 Following : 2 Trending mix of reels
/// (`GET /feed/reels?tab=mixed`).
class _ReelsPage extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final (actionLabel, action) = _liveAction(context, ref, HomeFeed.trending);
    final source = homeMixedReelsProvider;
    return FeedRegion<FeedReelData>(
      key: const PageStorageKey('home.reels.mixed'),
      content: ref.watch(source),
      copy: FeedRegionCopy(
        unavailableIcon: Icons.smart_display_outlined,
        unavailableTitle: l10n.homeReelsUnavailableTitle,
        unavailableBody: l10n.homeReelsUnavailableBody,
        unavailableActionLabel: actionLabel,
        unavailableActionIcon: Icons.sensors_rounded,
        onUnavailableAction: action,
        emptyIcon: Icons.smart_display_outlined,
        emptyTitle: l10n.homeReelsEmptyTitle,
        emptyBody: l10n.feedPullToRefresh,
        emptyActionLabel: actionLabel,
        emptyActionIcon: Icons.sensors_rounded,
        onEmptyAction: action,
        errorTitle: l10n.homeReelsErrorTitle,
      ),
      onRefresh: () {
        ref.invalidate(mixedReelsFeedProvider);
        return ref.refresh(source.future);
      },
      onRetry: () => ref
        ..invalidate(mixedReelsFeedProvider)
        ..invalidate(source),
      loadingSliver: const SliverFillRemaining(
        hasScrollBody: false,
        child: KSkeleton(width: double.infinity, height: double.infinity),
      ),
      // The pager fills the region; pull-to-refresh belongs to the outer
      // region, the vertical swipe to the pager.
      itemsSliver: (reels) => SliverFillRemaining(
        child: HomeReelsPager(
          reels: reels,
          storageKey: 'home.reels.pager.mixed',
          muteTop: KReelsHeader.muteTop(context),
          // D162: the next page of the reels feed before the last reel.
          onNearEnd: () =>
              unawaited(ref.read(mixedReelsFeedProvider.notifier).loadMore()),
        ),
      ),
    );
  }
}
