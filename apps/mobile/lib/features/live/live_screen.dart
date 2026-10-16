import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/app/shell/feed_region.dart';
import 'package:kabso_live/app/shell/feed_tabs_scaffold.dart';
import 'package:kabso_live/app/shell/shell_navigation.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_rooms_provider.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_cover_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/live` — the live-discovery hub (D36/D39, HOME_LIVE_LAYOUT_DECISIONS §1
/// HL-H3–H6): Following · Popular · New over live rooms (opens on Popular),
/// category chips on Popular and a 2-column 3:4 grid, all from the v1.3 API
/// (`liveRoomsProvider`). While the server has hosting switched off every
/// tab shows its own unavailable state with Try again (re-checks the
/// config). No search control until search exists (KL-047).
///
/// Another screen can ask for a segment through `liveHubTabRequestProvider`
/// (Home's "Watch live streams").
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

class _LiveHubPage extends ConsumerWidget {
  const new({required this.tab, required this.onSelectTab});

  final FeedTab tab;
  final ValueChanged<FeedTab> onSelectTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = liveRoomsProvider(tab);
    final async = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final hub = async.value;
    return LiveHubBody(
      tab: tab,
      content: liveHubContent(async),
      categories: hub?.categories ?? const [],
      selectedCategory: hub?.category,
      onSelectCategory: (slug) => unawaited(controller.selectCategory(slug)),
      onRefresh: controller.refresh,
      onRetry: () => unawaited(controller.retry()),
      onLoadMore: () => unawaited(controller.loadMore()),
      onRetryLoadMore: () => unawaited(controller.retryLoadMore()),
      onSelectTab: onSelectTab,
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

  /// Opens a room. `null` until the room screen exists (slice 2, KL-034):
  /// cards are then not announced or drawn as buttons.
  final ValueChanged<LiveRoomCardData>? onOpenRoom;

  final bool refreshWhenUnavailable;

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
      endOfList: l10n.liveHubListEnd,
    );
    return FeedRegion<LiveRoomCardData>(
      key: PageStorageKey('live.${tab.name}'),
      content: content,
      copy: copy,
      onRefresh: onRefresh,
      onRetry: onRetry,
      onLoadMore: onLoadMore,
      onRetryLoadMore: onRetryLoadMore,
      refreshWhenUnavailable: refreshWhenUnavailable,
      // HL-H3: categories on Popular only, as defined by the server; none
      // are invented. "All" alone is not interactive (nothing to switch to).
      // KL-047: no chip row while live streaming is unavailable (nothing to
      // filter).
      header: tab == FeedTab.popular && content.value is! FeedUnavailable
          ? _chips(context)
          : null,
      loadingSliver: _grid([
        for (var i = 0; i < KMetrics.liveGridSkeletonCount; i++)
          const KLiveCoverCardSkeleton(),
      ]),
      footerLoadingSliver: _grid(const [
        KLiveCoverCardSkeleton(),
        KLiveCoverCardSkeleton(),
      ], top: 0),
      itemsSliver: (rooms) => _grid([
        for (final room in rooms)
          KLiveCoverCard(
            room: room,
            onTap: onOpenRoom == null ? null : () => onOpenRoom!(room),
          ),
      ]),
    );
  }

  Widget _chips(BuildContext context) {
    final select = onSelectCategory;
    final interactive = categories.isNotEmpty && select != null;
    return ColoredBox(
      color: context.palette.background,
      child: KChipRow(
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
      ),
    );
  }

  /// HL-H4 / VG-09: 2 columns, 3:4, side padding `sm`, gaps `xs`.
  static Widget _grid(
    List<Widget> children, {
    double top = KMetrics.liveGridPadding,
  }) => SliverPadding(
    padding: EdgeInsetsDirectional.only(
      start: KMetrics.liveGridPadding,
      end: KMetrics.liveGridPadding,
      top: top,
      bottom: KMetrics.liveGridPadding,
    ),
    sliver: SliverGrid.count(
      crossAxisCount: 2,
      mainAxisSpacing: KMetrics.liveGridGap,
      crossAxisSpacing: KMetrics.liveGridGap,
      childAspectRatio: KSizes.liveCardAspect,
      children: children,
    ),
  );
}
