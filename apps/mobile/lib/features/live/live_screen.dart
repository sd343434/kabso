import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/app/shell/feed_region.dart';
import 'package:kabso_live/app/shell/feed_tabs_scaffold.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_rooms_provider.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_cover_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/live` — the live-discovery hub (D36, HOME_LIVE_LAYOUT_DECISIONS §1
/// HL-H3–H6): Following · Popular · New over live rooms, a category chip
/// row on Popular and a 2-column 3:4 grid. Until the Phase 6 live list API
/// exists every tab shows its own compact unavailable state.
class LiveScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => FeedTabsScaffold(
    pageBuilder: (context, tab, selectTab) =>
        _LiveHubPage(tab: tab, onSeePopular: () => selectTab(FeedTab.popular)),
  );
}

class _LiveHubPage extends ConsumerWidget {
  const new({required this.tab, required this.onSeePopular});

  final FeedTab tab;
  final VoidCallback onSeePopular;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = liveRoomsProvider(tab);
    return LiveHubBody(
      tab: tab,
      content: ref.watch(provider),
      onRefresh: () => ref.refresh(provider.future),
      onRetry: () => ref.invalidate(provider),
      onSeePopular: onSeePopular,
    );
  }
}

/// One Live hub tab page (pure; the gallery renders it with samples).
class LiveHubBody extends StatelessWidget {
  const new({
    required this.tab,
    required this.content,
    required this.onRefresh,
    required this.onRetry,
    required this.onSeePopular,
    super.key,
    this.onOpenRoom,
  });

  final FeedTab tab;
  final AsyncValue<FeedLoad<LiveRoomCardData>> content;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final VoidCallback onSeePopular;

  /// Opens a room. `null` until the room route exists (Phase 6, KL-034):
  /// cards are then not announced or drawn as buttons.
  final ValueChanged<LiveRoomCardData>? onOpenRoom;

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
      emptyIcon: Icons.sensors_off_outlined,
      emptyTitle: following
          ? l10n.liveHubFollowingEmptyTitle
          : l10n.liveHubEmptyTitle,
      emptyBody: l10n.feedPullToRefresh,
      emptyActionLabel: following ? l10n.feedSeePopular : null,
      onEmptyAction: following ? onSeePopular : null,
      errorTitle: l10n.liveHubErrorTitle,
    );
    return FeedRegion<LiveRoomCardData>(
      key: PageStorageKey('live.${tab.name}'),
      content: content,
      copy: copy,
      onRefresh: onRefresh,
      onRetry: onRetry,
      // HL-H3: categories on Popular only. Categories are server-defined
      // and none exist yet (D36), so the row is the single selected "All"
      // chip — not interactive, as there is nothing to switch to.
      header: tab == FeedTab.popular
          ? ColoredBox(
              color: context.palette.background,
              child: KChipRow(
                children: [KChip(label: l10n.liveHubChipAll, selected: true)],
              ),
            )
          : null,
      loadingSliver: _grid([
        for (var i = 0; i < KMetrics.liveGridSkeletonCount; i++)
          const KLiveCoverCardSkeleton(),
      ]),
      itemsSliver: (rooms) => _grid([
        for (final room in rooms)
          KLiveCoverCard(
            room: room,
            onTap: onOpenRoom == null ? null : () => onOpenRoom!(room),
          ),
      ]),
    );
  }

  /// HL-H4 / VG-09: 2 columns, 3:4, side padding `sm`, gaps `xs`.
  static Widget _grid(List<Widget> children) => SliverPadding(
    padding: const EdgeInsetsDirectional.all(KMetrics.liveGridPadding),
    sliver: SliverGrid.count(
      crossAxisCount: 2,
      mainAxisSpacing: KMetrics.liveGridGap,
      crossAxisSpacing: KMetrics.liveGridGap,
      childAspectRatio: KSizes.liveCardAspect,
      children: children,
    ),
  );
}
