import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The live hub's 2-column grid as slivers (D124; D131 geometry of ref 165,
/// [KLiveGrid]); `banner` (the promo carousel) full width after the
/// first `KLiveGrid.bannerAfter` cards, or after the last card when there
/// are fewer.
abstract final class LiveHubGrid {
  static const gridKey = Key('liveGrid');
  static const restGridKey = Key('liveGrid.rest');
  static const bannerSlotKey = Key('liveGrid.banner');
  static const loadingMoreKey = Key('liveGrid.loadingMore');
  static const skeletonKey = Key('liveGrid.skeleton');

  static Key cardKey(int index) => Key('liveGrid.card.$index');

  static const _delegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    mainAxisSpacing: KLiveGrid.rowGap,
    crossAxisSpacing: KLiveGrid.gap,
    childAspectRatio: KLiveGrid.cardAspect,
  );

  static Widget _grid(
    Key key,
    List<LiveRoomCardData> rooms,
    int offset,
    ValueChanged<LiveRoomCardData>? onOpenRoom,
  ) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(
      KLiveGrid.inset,
      KLiveGrid.gap,
      KLiveGrid.inset,
      0,
    ),
    sliver: SliverGrid(
      key: key,
      gridDelegate: _delegate,
      delegate: SliverChildBuilderDelegate((context, i) {
        final room = rooms[i];
        return KLiveGridCard(
          key: cardKey(offset + i),
          room: room,
          onTap: onOpenRoom == null ? null : () => onOpenRoom(room),
        );
      }, childCount: rooms.length),
    ),
  );

  /// The loaded rooms with the banner slot.
  static Widget sliver({
    required List<LiveRoomCardData> rooms,
    Widget? banner,
    ValueChanged<LiveRoomCardData>? onOpenRoom,
  }) {
    final split = rooms.length < KLiveGrid.bannerAfter
        ? rooms.length
        : KLiveGrid.bannerAfter;
    final first = rooms.sublist(0, split);
    final rest = rooms.sublist(split);
    return SliverMainAxisGroup(
      slivers: [
        _grid(gridKey, first, 0, onOpenRoom),
        if (banner != null)
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
        if (rest.isNotEmpty) _grid(restGridKey, rest, split, onOpenRoom),
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
