import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The live hub's 2-column grid as slivers (D124; D131 geometry of ref 165,
/// [KLiveGrid]).
///
/// D248 (owner, refs 375/376):
/// - `banner` (the promo carousel) full width — D303 (owner): the first
///   block, above the first row;
/// - `cardBanner` (the card-size banner) takes one cell, `cardBannerCell`
///   (0-based, reading order over every cell; after the last room when
///   there are fewer).
///
/// Neither is a room: the rooms keep their indices ([cardKey]) and the
/// list's cursor and paging never see them.
abstract final class LiveHubGrid {
  static const gridKey = Key('liveGrid');
  static const bannerSlotKey = Key('liveGrid.banner');

  /// D248: the cell of the card-size banner.
  static const cardBannerSlotKey = Key('liveGrid.cardBanner');
  static const loadingMoreKey = Key('liveGrid.loadingMore');
  static const skeletonKey = Key('liveGrid.skeleton');

  static Key cardKey(int index) => Key('liveGrid.card.$index');

  static const _delegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    mainAxisSpacing: KLiveGrid.rowGap,
    crossAxisSpacing: KLiveGrid.gap,
    childAspectRatio: KLiveGrid.cardAspect,
  );

  /// One run of cells: `cells[i]` is a room's index in [rooms], or `null`
  /// for the card-size banner.
  static Widget _grid(
    Key key,
    List<LiveRoomCardData> rooms,
    List<int?> cells,
    Widget? cardBanner,
    ValueChanged<LiveRoomCardData>? onOpenRoom, {
    double top = KLiveGrid.gap,
  }) => SliverPadding(
    padding: EdgeInsets.fromLTRB(KLiveGrid.inset, top, KLiveGrid.inset, 0),
    sliver: SliverGrid(
      key: key,
      gridDelegate: _delegate,
      delegate: SliverChildBuilderDelegate((context, i) {
        final index = cells[i];
        if (index == null) {
          return KeyedSubtree(key: cardBannerSlotKey, child: cardBanner!);
        }
        final room = rooms[index];
        return KLiveGridCard(
          key: cardKey(index),
          room: room,
          onTap: onOpenRoom == null ? null : () => onOpenRoom(room),
        );
      }, childCount: cells.length),
    ),
  );

  /// The cells in reading order: every room's index, with `null` (the
  /// card-size banner) at [cardBannerCell] — after the last room when there
  /// are fewer (D248).
  @visibleForTesting
  static List<int?> cells(int rooms, {int? cardBannerCell}) => [
    for (var i = 0; i < rooms; i++) ...[if (i == cardBannerCell) null, i],
    if (cardBannerCell != null && cardBannerCell >= rooms) null,
  ];

  /// The loaded rooms with the banner slots (D248).
  static Widget sliver({
    required List<LiveRoomCardData> rooms,
    Widget? banner,
    Widget? cardBanner,
    int cardBannerCell = HubCardBanners.defaultCell,
    ValueChanged<LiveRoomCardData>? onOpenRoom,
  }) {
    final all = cells(
      rooms.length,
      cardBannerCell: cardBanner == null ? null : cardBannerCell,
    );
    // D303 (owner: «البانر أول شيء في صفحة اللايف»): the carousel is the first
    // block, above the first row (D248 had it after the first row).
    if (banner == null) {
      return _grid(gridKey, rooms, all, cardBanner, onOpenRoom);
    }
    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          key: bannerSlotKey,
          padding: const EdgeInsets.fromLTRB(
            KLiveGrid.inset,
            KLiveGrid.gap,
            KLiveGrid.inset,
            0,
          ),
          sliver: SliverToBoxAdapter(child: banner),
        ),
        _grid(
          gridKey,
          rooms,
          all,
          cardBanner,
          onOpenRoom,
          top: KLiveGrid.bannerBottom,
        ),
      ],
    );
  }

  /// The first page loading: skeleton cards in the same grid.
  static Widget skeletonSliver() => SliverPadding(
    key: skeletonKey,
    padding: const EdgeInsets.fromLTRB(
      KLiveGrid.inset,
      KLiveGrid.gap,
      KLiveGrid.inset,
      0,
    ),
    sliver: SliverGrid(
      gridDelegate: _delegate,
      delegate: SliverChildBuilderDelegate(
        (_, _) => const KLiveGridCardSkeleton(),
        childCount: KLiveGrid.skeletonCount,
      ),
    ),
  );

  /// The footer while the next page loads: the animated live mark.
  static Widget loadingMoreSliver(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.only(top: KSpacing.md),
      child: Center(
        child: Semantics(
          key: loadingMoreKey,
          label: context.l10n.liveHubLoadingMore,
          // The live mark as the progress sign (still with reduce
          // motion and in tests).
          child: KLiveEqualizer(color: context.palette.primary, size: 20),
        ),
      ),
    ),
  );
}
