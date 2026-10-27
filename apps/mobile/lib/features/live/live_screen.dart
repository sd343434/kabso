import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/feed_region.dart';
import 'package:kabso_live/app/shell/feed_tabs_scaffold.dart';
import 'package:kabso_live/app/shell/shell_navigation.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/home_banners_provider.dart';
import 'package:kabso_live/features/live/application/live_room_swipe.dart';
import 'package:kabso_live/features/live/application/live_rooms_provider.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/domain/home_banner_link.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/hub/home_banner_carousel.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_grid.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_kind_switch.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/home` — the live-discovery hub, Kabso's home page since D48 (D36/D39,
/// HOME_LIVE_LAYOUT_DECISIONS §1 HL-H3–H6): Following · Popular · New over
/// live rooms (opens on Popular), category chips on Popular and (D124) a
/// 2-column 3:4 grid with the promo banners after the 4th card, all from the
/// API (`liveRoomsProvider`, `homeBannersProvider`). D129: a "voice rooms ·
/// live" switch under the top bar filters every tab on the server
/// (`liveHubKindProvider`, kept per device). D124: a top bar with the
/// Kabso title, search (Discover) and the notifications bell above the
/// tabs; the hub follows the app theme. While the server has hosting
/// switched off every tab shows its own unavailable state with Try again
/// (re-checks the config).
///
/// Another screen can ask for a segment through `liveHubTabRequestProvider`
/// ("Watch live streams" on the Reels tab).
///
/// Freshness (HL-H5): re-tapping the selected tab re-fetches it; returning
/// to the app after more than [resumeRefreshAfter] re-fetches every loaded
/// tab (which also re-checks `GET /live/config`).
class LiveScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const resumeRefreshAfter = Duration(seconds: 60);

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  late final AppLifecycleListener _lifecycle;
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => _leftAt ??= clock.now(),
      onShow: _returned,
    );
  }

  void _returned() {
    final leftAt = _leftAt;
    _leftAt = null;
    if (leftAt == null) return;
    if (clock.now().difference(leftAt) > LiveScreen.resumeRefreshAfter) {
      unawaited(
        refreshLoadedLiveTabs(
          ProviderScope.containerOf(context, listen: false),
        ),
      );
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FeedTabsScaffold(
    centerTabs: true,
    // D129: the voice rooms · live switch under the title, over every tab.
    topBar: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const LiveHubTopBar(),
        LiveHubKindSwitch(
          selected: ref.watch(liveHubKindProvider),
          onSelected: (kind) =>
              unawaited(ref.read(liveHubKindProvider.notifier).select(kind)),
        ),
      ],
    ),
    requestedTab: ref.watch(liveHubTabRequestProvider),
    onReselect: (tab) => unawaited(
      ref
          .read(liveRoomsProvider(tab).notifier)
          .refresh()
          .catchError((Object _) {}),
    ),
    pageBuilder: (context, tab, selectTab) =>
        _LiveHubPage(tab: tab, onSelectTab: selectTab),
  );
}

/// D124: the hub's top bar: the Kabso title at the reading start, search
/// (Discover), the party button (D130) and the notifications bell at the
/// end.
class LiveHubTopBar extends StatelessWidget {
  const new({super.key, this.showNotifications = true});

  /// Off in the gallery (no signed-in user there).
  final bool showNotifications;

  static const titleKey = Key('liveHub.title');
  static const searchKey = Key('liveHub.search');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return SizedBox(
      height: KMetrics.topBarHeight + KSpacing.xs,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: KLiveGrid.inset,
          end: KSpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.liveHubBrand,
                key: titleKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.headline.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              key: searchKey,
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
            // D130: the owner's party button next to the bell (its function
            // comes later: it says Soon).
            const LiveHubPartyButton(),
            if (showNotifications) const NotificationsBell(),
          ],
        ),
      ),
    );
  }
}

/// D130: the owner's party popper in the hub's top bar, beside the bell
/// (owner: "its function comes later"). It does not pretend to work: a tap
/// plays the pop and says "Party: coming soon", like the app's other Soon
/// tools; screen readers hear "Party, Soon".
class LiveHubPartyButton extends StatefulWidget {
  const new({super.key});

  static const buttonKey = Key('liveHub.party');

  @override
  State<LiveHubPartyButton> createState() => _LiveHubPartyButtonState();
}

class _LiveHubPartyButtonState extends State<LiveHubPartyButton> {
  final GlobalKey<KPartyIconState> _icon = GlobalKey();

  void _tap() {
    unawaited(HapticFeedback.selectionClick());
    _icon.currentState?.play();
    final l10n = context.l10n;
    KSnack.info(context, l10n.liveUserBoxSoon(l10n.liveHubParty));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = '${l10n.liveHubParty}, ${l10n.liveSoon}';
    return Semantics(
      button: true,
      label: label,
      onTap: _tap,
      excludeSemantics: true,
      child: IconButton(
        key: LiveHubPartyButton.buttonKey,
        tooltip: label,
        constraints: const BoxConstraints.tightFor(
          width: KSizes.minTouchTarget,
          height: KSizes.minTouchTarget,
        ),
        onPressed: _tap,
        icon: KPartyIcon(key: _icon),
      ),
    );
  }
}

class _LiveHubPage extends ConsumerWidget {
  const new({required this.tab, required this.onSelectTab});

  final FeedTab tab;
  final ValueChanged<FeedTab> onSelectTab;

  void _openBanner(BuildContext context, WidgetRef ref, HomeBanner banner) {
    switch (HomeBannerTarget.parse(banner.link)) {
      case HomeBannerRoute(:final location):
        unawaited(context.push<void>(location));
      case HomeBannerLiveTab(tab: final target):
        openLiveHub(context, ref, target);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = liveRoomsProvider(tab);
    final async = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final hub = async.value;
    final banners = ref.watch(homeBannersProvider).value ?? const [];
    return LiveHubBody(
      tab: tab,
      content: liveHubContent(async),
      categories: hub?.categories ?? const [],
      selectedCategory: hub?.category,
      onSelectCategory: (slug) => unawaited(controller.selectCategory(slug)),
      onRefresh: () {
        // The banners reload with the tab (a failure there shows none).
        ref.invalidate(homeBannersProvider);
        return controller.refresh();
      },
      onRetry: () => unawaited(controller.retry()),
      onLoadMore: () => unawaited(controller.loadMore()),
      onRetryLoadMore: () => unawaited(controller.retryLoadMore()),
      onSelectTab: onSelectTab,
      banners: banners,
      onOpenBanner: (banner) => _openBanner(context, ref, banner),
      canOpenBanner: (banner) => HomeBannerTarget.parse(banner.link) != null,
      onOpenRoom: (room) {
        final id = room.roomId;
        if (id == null) return;
        // D124: swiping inside the room moves through this tab's rooms.
        ref.read(liveRoomSwipeListProvider.notifier).set([
          for (final r in hub?.rooms ?? const <LiveRoomSummary>[])
            (roomId: r.id, hostId: r.host.id),
        ]);
        unawaited(context.push<void>(AppRoutes.liveRoom(id)));
      },
      refreshWhenUnavailable: true,
    );
  }
}

/// Maps a tab's [LiveHubState] to what the grid region shows.
///
/// A reload ("Try again") of a tab that shows nothing yet (unavailable,
/// empty or failed) is loading: its old empty or unavailable state is not
/// shown while the new request runs.
AsyncValue<FeedLoad<LiveRoomCardData>> liveHubContent(
  AsyncValue<LiveHubState> async,
) => switch (async) {
  AsyncValue(:final error?, :final stackTrace, isLoading: false) => AsyncError(
    error,
    stackTrace ?? StackTrace.empty,
  ),
  AsyncValue(
    isLoading: true,
    value: LiveHubState(:final hostingEnabled, :final rooms),
  )
      when !hostingEnabled || rooms.isEmpty =>
    const AsyncLoading(),
  AsyncValue(value: LiveHubState(hostingEnabled: false)) => const AsyncData(
    FeedUnavailable(),
  ),
  AsyncValue(value: LiveHubState(:final reloadError?)) => AsyncError(
    reloadError,
    StackTrace.empty,
  ),
  AsyncValue(value: LiveHubState(reloading: true)) => const AsyncLoading(),
  AsyncValue(value: final LiveHubState hub) => AsyncData(
    FeedItems(
      [for (final room in hub.rooms) LiveRoomCardData.fromSummary(room)],
      hasMore: hub.hasMore,
      loadingMore: hub.loadingMore,
      loadMoreError: hub.loadMoreError,
    ),
  ),
  _ => const AsyncLoading(),
};

/// One Live hub tab page (pure; the gallery and goldens render it with
/// samples).
class LiveHubBody extends StatelessWidget {
  const new({
    required this.tab,
    required this.content,
    required this.onRefresh,
    required this.onRetry,
    required this.onSelectTab,
    super.key,
    this.categories = const [],
    this.selectedCategory,
    this.onSelectCategory,
    this.onLoadMore,
    this.onRetryLoadMore,
    this.onOpenRoom,
    this.refreshWhenUnavailable = false,
    this.banners = const [],
    this.onOpenBanner,
    this.canOpenBanner,
  });

  final FeedTab tab;
  final AsyncValue<FeedLoad<LiveRoomCardData>> content;
  final Future<void> Function() onRefresh;

  /// Re-runs the failed or empty load (config, categories, first page).
  final VoidCallback onRetry;

  /// Switches the header to another tab ("See popular", "See new streams").
  final ValueChanged<FeedTab> onSelectTab;

  /// Active server categories (Popular only). The row always starts with
  /// "All"; it is interactive only when there is something to switch to.
  final List<LiveCategory> categories;

  /// Selected category slug; `null` is "All".
  final String? selectedCategory;
  final ValueChanged<String?>? onSelectCategory;

  final VoidCallback? onLoadMore;
  final VoidCallback? onRetryLoadMore;

  /// Opens a room (`/home/room/:roomId`, KL-034). `null` (gallery,
  /// goldens): cards are not announced or drawn as buttons.
  final ValueChanged<LiveRoomCardData>? onOpenRoom;

  final bool refreshWhenUnavailable;

  /// D124: the active promo banners, shown after the 4th card (none: no
  /// carousel).
  final List<HomeBanner> banners;
  final ValueChanged<HomeBanner>? onOpenBanner;
  final bool Function(HomeBanner banner)? canOpenBanner;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final following = tab == FeedTab.following;
    final copy = FeedRegionCopy(
      unavailableIcon: switch (tab) {
        FeedTab.following => Icons.group_outlined,
        FeedTab.popular => Icons.sensors_outlined,
        FeedTab.latest => Icons.new_releases_outlined,
      },
      unavailableTitle: switch (tab) {
        FeedTab.following => l10n.liveHubFollowingUnavailableTitle,
        FeedTab.popular => l10n.liveHubPopularUnavailableTitle,
        FeedTab.latest => l10n.liveHubNewUnavailableTitle,
      },
      unavailableBody: switch (tab) {
        FeedTab.following => l10n.liveHubFollowingUnavailableBody,
        FeedTab.popular => l10n.liveHubPopularUnavailableBody,
        FeedTab.latest => l10n.liveHubNewUnavailableBody,
      },
      // D41: hosting is a server switch; Try again re-checks it.
      unavailableActionLabel: l10n.actionRetry,
      onUnavailableAction: onRetry,
      emptyIcon: following ? Icons.group_outlined : Icons.sensors_off_outlined,
      emptyTitle: following
          ? l10n.liveHubFollowingEmptyTitle
          : l10n.liveHubEmptyTitle,
      emptyBody: following
          ? l10n.liveHubFollowingEmptyBody
          : l10n.liveHubEmptyBody,
      // Following: "See popular" first; elsewhere re-request the list, and
      // on Popular also offer the New tab.
      emptyActionLabel: following ? l10n.feedSeePopular : l10n.actionRetry,
      onEmptyAction: following ? () => onSelectTab(FeedTab.popular) : onRetry,
      emptySecondaryActionLabel: switch (tab) {
        FeedTab.following => l10n.actionRetry,
        FeedTab.popular => l10n.liveHubSeeNew,
        FeedTab.latest => null,
      },
      onEmptySecondaryAction: switch (tab) {
        FeedTab.following => onRetry,
        FeedTab.popular => () => onSelectTab(FeedTab.latest),
        FeedTab.latest => null,
      },
      errorTitle: l10n.liveHubErrorTitle,
      loadMoreFailed: l10n.liveHubLoadMoreFailed,
    );
    // HL-H3: categories on Popular only, as defined by the server; none are
    // invented. "All" alone is not interactive (nothing to switch to).
    // KL-047: no chip row while live streaming is unavailable (nothing to
    // filter). The row floats above the grid and every other state, so an
    // empty category can be left.
    final chips = tab == FeedTab.popular && content.value is! FeedUnavailable
        ? _chips(context)
        : null;
    final banner = banners.isEmpty
        ? null
        : KHomeBannerCarousel(
            banners: banners,
            onOpen: onOpenBanner,
            canOpen: canOpenBanner,
          );
    return FeedRegion<LiveRoomCardData>(
      key: PageStorageKey('live.${tab.name}'),
      content: content,
      copy: copy,
      header: chips,
      onRefresh: onRefresh,
      onRetry: onRetry,
      onLoadMore: onLoadMore,
      onRetryLoadMore: onRetryLoadMore,
      refreshWhenUnavailable: refreshWhenUnavailable,
      loadingSliver: LiveHubGrid.skeletonSliver(),
      footerLoadingSliver: LiveHubGrid.loadingMoreSliver(context),
      itemsSliver: (rooms) => LiveHubGrid.sliver(
        rooms: rooms,
        banner: banner,
        onOpenRoom: onOpenRoom,
      ),
    );
  }

  Widget _chips(BuildContext context) {
    final select = onSelectCategory;
    final interactive = categories.isNotEmpty && select != null;
    return KChipRow(
      children: [
        KChip(
          key: const ValueKey('live.chip.all'),
          label: context.l10n.liveHubChipAll,
          selected: selectedCategory == null,
          onSelected: interactive ? () => select(null) : null,
        ),
        for (final category in categories)
          KChip(
            key: ValueKey('live.chip.${category.slug}'),
            label: category.name,
            selected: selectedCategory == category.slug,
            onSelected: interactive ? () => select(category.slug) : null,
          ),
      ],
    );
  }
}
