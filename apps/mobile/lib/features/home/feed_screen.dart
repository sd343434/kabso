import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/feed_region.dart';
import 'package:kabso_live/app/shell/shell_navigation.dart';
import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/country_picker.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
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
/// Posts' top bar is the person's own avatar, name and handle (to their
/// profile), then Search, the notifications bell (with the unread count)
/// and «ريلز», which switches to Reels. Posts has one feed: the server's
/// 1 Following : 2 Trending mix (`GET /feed/posts?tab=mixed`, CONVENTIONS
/// §10.73). The stories tray sits above every posts state (D218: it was
/// drawn only above a non-empty feed, so a new account never saw it).
/// What follows below describes Reels, which keeps Following · For You ·
/// Nearby:
///
/// - Posts' header has three words in the centre (D53): the feed tabs
///   Trending · Following and, past a short divider, "Reels", which
///   switches to it (Reels goes back with its «Posts» chip, D202). The
///   selected feed is kept when the mode switches (Reels calls Trending
///   «For You» and adds Nearby, reels from the viewer's country).
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
///   dark in both app themes (D202, the owner's reference); their own
///   header floats over the video on a scrim with light status-bar icons:
///   Search · Following · For You · Nearby · the bell, then the chips
///   Stories (the stories tray), Rooms (the voice rooms) and Posts (the
///   way back, D53).
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
  static const tabsKey = Key('home.tabs');
  static const searchKey = Key('home.search');
  static const switchKey = Key('home.switch');

  /// D202: the reels page's chips and its third feed.
  static const nearbyKey = Key('home.page.reels.nearby');

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

  /// D202: Reels' third tab «القريبة» (reels from the viewer's country);
  /// Posts has no such feed and keeps [_feed].
  bool _nearby = false;

  /// Nearby is built the first time it is chosen (it reads the viewer's
  /// country), then kept alive like the other feeds.
  bool _nearbyOpened = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reels = _tab == HomeTab.reels;
    final belowHeader = EdgeInsets.only(
      top: KTopInset.of(context) + KPostsTopBar.height,
    );
    final Widget header;
    if (reels) {
      // D202: the reels page's own header floats over the video.
      header = _ReelsHeader(
        key: FeedScreen.headerKey,
        feed: _feed,
        nearby: _nearby,
        showSearch: widget.showSearch,
        showNotifications: widget.showNotifications,
        onSwitch: () => setState(() => _tab = _tab.other),
        onFeed: (feed, {required nearby}) {
          if (feed != _feed || nearby != _nearby) {
            setState(() {
              _feed = feed;
              _nearby = nearby;
              _nearbyOpened |= nearby;
            });
          }
        },
      );
    } else {
      // Posts follow the app theme (owner, 2026-10-26).
      header = ColoredBox(
        key: FeedScreen.headerKey,
        color: p.background,
        child: KTopSafeArea(
          child: _PostsTopBar(
            showSearch: widget.showSearch,
            showNotifications: widget.showNotifications,
            onSwitch: () => setState(() => _tab = _tab.other),
          ),
        ),
      );
    }
    final reelsIndex = _nearby ? HomeFeed.values.length : _feed.index;
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
                    child: _ReelsTheme(
                      child: IndexedStack(
                        index: reelsIndex,
                        sizing: StackFit.expand,
                        children: [
                          for (final feed in HomeFeed.values)
                            KeyedSubtree(
                              key: FeedScreen.feedKey(HomeTab.reels, feed),
                              child: _ReelsPage(feed: feed),
                            ),
                          KeyedSubtree(
                            key: FeedScreen.nearbyKey,
                            child: _nearbyOpened
                                ? const _NearbyReelsPage()
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: reels ? _ReelsTheme(child: header) : header,
            ),
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

/// D202 geometry of the reels header (measured from the owner's reference
/// at 393 dp): the bar's scrim, the tabs' underline, the chips row.
abstract final class KReelsHeader {
  /// The scrim runs this far under the bar's 48 dp row.
  static const double scrimBelow = 8;

  /// Tab labels 16 sp; the selected one's 34 × 3 underline 6 dp below.
  static const double tabFont = 16;
  static const double tabGap = 20;
  static const double underlineWidth = 34;
  static const double underline = 3;
  static const double underlineGap = 6;

  /// Search and the bell sit 12 dp from the edges.
  static const double sideInset = KSpacing.md;

  /// The chip: a 28 dp pill 22 dp under the bar (its 48 dp target 14),
  /// 14 from the start. Owner 2026-10-31: «القصص» and «الغرف» removed, only
  /// «المنشورات» kept, a little smaller (32 → 28 dp, icon 16 → 14).
  static const double chipsGap = 14;
  static const double chipHeight = 28;
  static const double chipSpacing = KSpacing.sm;
  static const double chipsStart = 14;
  static const double chipIcon = 14;
  static const double chipBorder = 1.5;
  static const double chipFont = 12;

  /// The end of the chips row kept free for the video's speaker button.
  static const double muteSlot = KSizes.minTouchTarget + KSpacing.xs + 4;

  /// Where the chips row's 48 dp targets start (the video's speaker button
  /// aligns with them).
  static double chipsTop(BuildContext context) =>
      KTopInset.of(context) + KMetrics.topBarHeight + chipsGap;
}

/// D202: the reels page's header over the video — Search at the start,
/// the tabs Following · For You · Nearby in the middle (the selected one
/// underlined), the bell at the end; under it the chips «القصص» (the
/// stories tray), «الغرف» (the voice rooms) and «المنشورات» (back to
/// Posts, D53).
class _ReelsHeader extends StatelessWidget {
  const new({
    required this.feed,
    required this.nearby,
    required this.showSearch,
    required this.showNotifications,
    required this.onSwitch,
    required this.onFeed,
    super.key,
  });

  final HomeFeed feed;
  final bool nearby;
  final bool showSearch;
  final bool showNotifications;
  final VoidCallback onSwitch;
  final void Function(HomeFeed feed, {required bool nearby}) onFeed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final white = KPalette.dark.textPrimary;
    final top = KTopInset.of(context);
    final selected = nearby ? 2 : (feed == HomeFeed.following ? 0 : 1);
    const slot = KReelsHeader.sideInset + KSizes.minTouchTarget;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: top + KMetrics.topBarHeight + KReelsHeader.scrimBelow,
          child: const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xB3000000), Color(0x40000000)],
                ),
              ),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: top),
            SizedBox(
              height: KMetrics.topBarHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: slot),
                      child: _ReelsTabs(
                        key: FeedScreen.tabsKey,
                        labels: [
                          l10n.feedTabFollowing,
                          l10n.reelsTabForYou,
                          l10n.liveHubFilterNearby,
                        ],
                        selectedIndex: selected,
                        onSelected: (i) => switch (i) {
                          0 => onFeed(HomeFeed.following, nearby: false),
                          1 => onFeed(HomeFeed.trending, nearby: false),
                          _ => onFeed(feed, nearby: true),
                        },
                      ),
                    ),
                  ),
                  if (showSearch)
                    PositionedDirectional(
                      start: KReelsHeader.sideInset,
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
                          color: white,
                        ),
                      ),
                    ),
                  if (showNotifications)
                    PositionedDirectional(
                      end: KReelsHeader.sideInset,
                      top: 0,
                      bottom: 0,
                      child: NotificationsBell(color: white),
                    ),
                ],
              ),
            ),
            const SizedBox(height: KReelsHeader.chipsGap),
            Align(
              alignment: AlignmentDirectional.centerStart,
              // The row stops before the video's speaker button at the end
              // and scrolls when the chips do not fit (large text).
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: KReelsHeader.muteSlot,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsetsDirectional.only(
                    start: KReelsHeader.chipsStart,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // D53: the way back to Posts (the switch word's job on
                      // the Posts header).
                      _ReelsChip(
                        key: FeedScreen.switchKey,
                        asset: AppIcons.grid,
                        iconColor: white,
                        border: white.withValues(alpha: 0.5),
                        label: l10n.homeTabPosts,
                        semanticLabel: l10n.homeShowPosts,
                        onTap: onSwitch,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The reels tabs: centred words, the selected one bold white with a red
/// gradient underline, the others semibold and dimmed. Each is a 48 dp
/// target; the row shrinks to fit (large text, small screens).
class _ReelsTabs extends StatelessWidget {
  const new({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final white = KPalette.dark.textPrimary;
    final base = context.textStyles.bodyStrong.copyWith(
      fontSize: KReelsHeader.tabFont,
      height: 1.3,
      shadows: const [Shadow(color: Color(0x66000000), blurRadius: 6)],
    );
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: KMetrics.topBarMaxTextScale,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, label) in labels.indexed) ...[
                if (i > 0) const SizedBox(width: KReelsHeader.tabGap),
                Semantics(
                  selected: i == selectedIndex,
                  button: true,
                  inMutuallyExclusiveGroup: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelected(i),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: KSizes.minTouchTarget,
                        minHeight: KSizes.minTouchTarget,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            style: base.copyWith(
                              color: i == selectedIndex
                                  ? white
                                  : white.withValues(alpha: 0.72),
                              fontWeight: i == selectedIndex
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: KReelsHeader.underlineGap),
                          Container(
                            width: KReelsHeader.underlineWidth,
                            height: KReelsHeader.underline,
                            decoration: i == selectedIndex
                                ? BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      KRadius.pill,
                                    ),
                                    gradient: const LinearGradient(
                                      colors: KBrandColors.gradientLive,
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A 32 dp glass pill with a coloured outline, an icon and a label; a
/// 48 dp target.
class _ReelsChip extends StatelessWidget {
  const new({
    required this.label,
    required this.semanticLabel,
    required this.iconColor,
    required this.border,
    required this.onTap,
    required this.asset,
    super.key,
  });

  final String label;
  final String semanticLabel;
  final String asset;
  final Color iconColor;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final white = KPalette.dark.textPrimary;
    final glyph = AppIcon(asset, size: KReelsHeader.chipIcon, color: iconColor);
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: KSizes.minTouchTarget),
          child: Center(
            widthFactor: 1,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: KMetrics.overlayMaxTextScale,
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: KReelsHeader.chipHeight,
                ),
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: KSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: KPalette.dark.surface.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(KRadius.pill),
                  border: Border.all(
                    color: border,
                    width: KReelsHeader.chipBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    glyph,
                    const SizedBox(width: KSpacing.xs + 2),
                    Text(
                      label,
                      maxLines: 1,
                      style: context.textStyles.label.copyWith(
                        color: white,
                        fontSize: KReelsHeader.chipFont,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

/// Gap between two posts.
const _postGap = SizedBox(height: KPostCard.gap);

Widget _postsSkeleton(BuildContext context) => SliverList.separated(
  itemCount: 3,
  itemBuilder: (_, _) => const FeedPostSkeleton(),
  separatorBuilder: (_, _) => _postGap,
);

/// D218 geometry of the posts top bar (the owner's reference, E at ≈0.81
/// px/dp, logical width 393 assumed): a 56 dp row, the own avatar 38 dp
/// with a thin story ring, the name 15 sp bold over the handle 12 sp, and
/// three 36 dp grey discs (Search, the bell, «ريلز») 8 dp apart.
abstract final class KPostsTopBar {
  static const double height = KSizes.minTouchTarget + KSpacing.sm;
  static const double avatar = 38;
  static const double disc = 36;
  static const double discGap = KSpacing.sm;
  static const double nameFont = 15;
  static const double handleFont = 12;
}

/// D218: the posts page's top bar — from the reading start: the person's
/// avatar, display name and handle (opens their profile), then Search, the
/// notifications bell with its unread count and «ريلز» (the reels page).
/// No messages icon: messages stay in the bottom bar.
class _PostsTopBar extends ConsumerWidget {
  const new({
    required this.showSearch,
    required this.showNotifications,
    required this.onSwitch,
  });

  final bool showSearch;
  final bool showNotifications;
  final VoidCallback onSwitch;

  static const meKey = Key('home.posts.me');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final me = ref.watch(currentUserProvider);
    final disc = SizedBox(
      width: KSizes.minTouchTarget,
      height: KSizes.minTouchTarget,
      child: Center(
        child: Container(
          width: KPostsTopBar.disc,
          height: KPostsTopBar.disc,
          decoration: BoxDecoration(
            color: p.surfaceOverlay,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
    Widget overDisc(Widget button) =>
        Stack(alignment: Alignment.center, children: [disc, button]);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: KMetrics.topBarMaxTextScale,
      child: SizedBox(
        height: KPostsTopBar.height,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: KSpacing.lg,
            end: KSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: me == null
                    ? const SizedBox.shrink()
                    : Semantics(
                        button: true,
                        label: l10n.postsTopBarMe(
                          me.displayName.isEmpty ? me.username : me.displayName,
                        ),
                        excludeSemantics: true,
                        child: InkWell(
                          key: meKey,
                          borderRadius: BorderRadius.circular(KRadius.md),
                          onTap: () => context.push(AppRoutes.myProfile),
                          child: Row(
                            children: [
                              KAvatar(
                                name: me.displayName,
                                imageUrl: me.avatarUrl,
                                size: KPostsTopBar.avatar - 2 * KMetrics.stroke,
                                ring: KAvatarRing.storyUnseen,
                              ),
                              const SizedBox(width: KSpacing.sm),
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      me.displayName.isEmpty
                                          ? me.username
                                          : me.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: t.bodyStrong.copyWith(
                                        color: p.textPrimary,
                                        fontSize: KPostsTopBar.nameFont,
                                        fontWeight: FontWeight.w700,
                                        height: 1.25,
                                      ),
                                    ),
                                    Text(
                                      KHandle.isolated(
                                        me.username,
                                        premiumTier: me.premiumTier,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: t.caption.copyWith(
                                        color: p.textTertiary,
                                        fontSize: KPostsTopBar.handleFont,
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              if (showSearch)
                overDisc(
                  IconButton(
                    key: FeedScreen.searchKey,
                    tooltip: l10n.feedSearch,
                    constraints: const BoxConstraints.tightFor(
                      width: KSizes.minTouchTarget,
                      height: KSizes.minTouchTarget,
                    ),
                    onPressed: () => context.push(AppRoutes.discover),
                    icon: AppIcon(
                      AppIcons.search,
                      size: KMetrics.iconMd - 2,
                      color: p.textPrimary,
                    ),
                  ),
                ),
              if (showNotifications) overDisc(const NotificationsBell()),
              // The reference's third disc: «ريلز» opens the reels page.
              overDisc(
                IconButton(
                  key: FeedScreen.switchKey,
                  tooltip: l10n.homeShowReels,
                  constraints: const BoxConstraints.tightFor(
                    width: KSizes.minTouchTarget,
                    height: KSizes.minTouchTarget,
                  ),
                  onPressed: onSwitch,
                  icon: AppIcon(
                    AppIcons.reels,
                    size: KMetrics.iconMd - 2,
                    color: p.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
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
          itemBuilder: (_, i) => FeedPostTile(post: posts[i]),
          separatorBuilder: (_, _) => _postGap,
        ),
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
      onRefresh: () {
        ref.invalidate(reelsFeedProvider(feed));
        return ref.refresh(source.future);
      },
      onRetry: () => ref
        ..invalidate(reelsFeedProvider(feed))
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
          storageKey: 'home.reels.pager.${feed.name}',
          muteTop: _reelsMuteTop(context),
          // D162: the next page of the reels feed before the last reel.
          onNearEnd: () =>
              unawaited(ref.read(reelsFeedProvider(feed).notifier).loadMore()),
        ),
      ),
    );
  }
}

/// D202: the video's speaker button sits at the end of the chips row.
double _reelsMuteTop(BuildContext context) => KReelsHeader.chipsTop(context);

/// D202 (v1.68-social, CONVENTIONS §11.15): «القريبة» — reels of authors
/// from the viewer's own country (`GET /feed/reels?tab=nearby`). Without a
/// country it asks for one (the D133 picker); the server never guesses it.
class _NearbyReelsPage extends ConsumerWidget {
  const new();

  static const chooseCountryKey = Key('home.reels.nearby.country');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final demo = kDemoAvailable && ref.watch(demoModeProvider);
    final hasCountry =
        demo ||
        ref.watch(currentUserProvider.select((u) => u?.country)) != null;
    if (!hasCountry) {
      return Padding(
        padding: EdgeInsets.only(top: KReelsHeader.chipsTop(context)),
        child: KEmptyState(
          key: chooseCountryKey,
          icon: Icons.public_rounded,
          title: l10n.reelsNearbyNoCountryTitle,
          message: l10n.reelsNearbyNoCountryBody,
          actionLabel: l10n.reelsNearbyChooseCountry,
          onAction: () => unawaited(showCountryPicker(context)),
        ),
      );
    }
    final (actionLabel, action) = _liveAction(context, ref, HomeFeed.trending);
    final source = homeNearbyReelsProvider;
    return FeedRegion<FeedReelData>(
      key: const PageStorageKey('home.reels.nearby'),
      content: ref.watch(source),
      copy: FeedRegionCopy(
        unavailableIcon: Icons.smart_display_outlined,
        unavailableTitle: l10n.reelsNearbyUnavailableTitle,
        unavailableBody: l10n.homeReelsUnavailableBody,
        unavailableActionLabel: actionLabel,
        unavailableActionIcon: Icons.sensors_rounded,
        onUnavailableAction: action,
        emptyIcon: Icons.smart_display_outlined,
        emptyTitle: l10n.reelsNearbyEmptyTitle,
        emptyBody: l10n.feedPullToRefresh,
        emptyActionLabel: actionLabel,
        emptyActionIcon: Icons.sensors_rounded,
        onEmptyAction: action,
        errorTitle: l10n.reelsNearbyUnavailableTitle,
      ),
      onRefresh: () {
        ref.invalidate(nearbyReelsFeedProvider);
        return ref.refresh(source.future);
      },
      onRetry: () => ref
        ..invalidate(nearbyReelsFeedProvider)
        ..invalidate(source),
      loadingSliver: const SliverFillRemaining(
        hasScrollBody: false,
        child: KSkeleton(width: double.infinity, height: double.infinity),
      ),
      itemsSliver: (reels) => SliverFillRemaining(
        child: HomeReelsPager(
          reels: reels,
          storageKey: 'home.reels.pager.nearby',
          muteTop: _reelsMuteTop(context),
          onNearEnd: () =>
              unawaited(ref.read(nearbyReelsFeedProvider.notifier).loadMore()),
        ),
      ),
    );
  }
}
