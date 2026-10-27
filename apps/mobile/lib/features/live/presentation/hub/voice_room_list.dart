import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Geometry of the Voice rooms' list rows, measured on ref 166 (393 pt):
/// rows 863 × 161 px, 30 px from the sides, 22 px apart; the cover a
/// 161 px square at the reading start.
abstract final class KVoiceRoomRow {
  /// Side inset (30 px = 12.8 pt).
  static const double inset = 12.8;

  /// Row height and cover side (161 px = 68.6 pt).
  static const double height = 68.6;

  /// Gap between rows (21–22 px = 9.2 pt).
  static const double gap = 9.2;

  /// Corner radius (≈ 20 px; E).
  static const double radius = 8.5;

  /// The title's start after the cover (25 px = 10.6 pt) and its top
  /// (16 px = 6.8 pt).
  static const double textStart = 10.6;
  static const double textTop = 6.8;

  /// The chips line's height (33 px = 14 pt) and bottom (≈ 10 pt).
  static const double chipHeight = 14;

  /// Light theme: the row text (sampled `#282828`) and the count's mic
  /// (`#48E4E6`).
  static const Color lightInk = Color(0xFF282828);
  static const Color mic = Color(0xFF48E4E6);
}

/// The Voice rooms' list (ref 166) as slivers: one row per room, the promo
/// banner after the 4th row.
abstract final class VoiceRoomList {
  static const listKey = Key('voiceRooms.list');
  static const restListKey = Key('voiceRooms.list.rest');
  static const bannerSlotKey = Key('voiceRooms.banner');
  static const skeletonKey = Key('voiceRooms.skeleton');
  static Key rowKey(int index) => Key('voiceRooms.row.$index');

  static Widget _list(
    Key key,
    List<LiveRoomCardData> rooms,
    int offset,
    ValueChanged<LiveRoomCardData>? onOpenRoom,
  ) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(
      KVoiceRoomRow.inset,
      0,
      KVoiceRoomRow.inset,
      0,
    ),
    sliver: SliverList(
      key: key,
      delegate: SliverChildBuilderDelegate((context, i) {
        final room = rooms[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: KVoiceRoomRow.gap),
          child: VoiceRoomRow(
            key: rowKey(offset + i),
            room: room,
            onTap: onOpenRoom == null ? null : () => onOpenRoom(room),
          ),
        );
      }, childCount: rooms.length),
    ),
  );

  static Widget sliver({
    required List<LiveRoomCardData> rooms,
    Widget? banner,
    ValueChanged<LiveRoomCardData>? onOpenRoom,
  }) {
    final split = rooms.length < KLiveGrid.bannerAfter
        ? rooms.length
        : KLiveGrid.bannerAfter;
    return SliverMainAxisGroup(
      slivers: [
        _list(listKey, rooms.sublist(0, split), 0, onOpenRoom),
        if (banner != null)
          SliverPadding(
            key: bannerSlotKey,
            padding: const EdgeInsets.fromLTRB(
              KVoiceRoomRow.inset,
              0,
              KVoiceRoomRow.inset,
              KVoiceRoomRow.gap,
            ),
            sliver: SliverToBoxAdapter(child: banner),
          ),
        if (rooms.length > split)
          _list(restListKey, rooms.sublist(split), split, onOpenRoom),
      ],
    );
  }

  static Widget skeletonSliver() => SliverPadding(
    key: skeletonKey,
    padding: const EdgeInsets.symmetric(horizontal: KVoiceRoomRow.inset),
    sliver: SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, _) => Padding(
          padding: const EdgeInsets.only(bottom: KVoiceRoomRow.gap),
          child: SizedBox(
            height: KVoiceRoomRow.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.palette.surfaceRaised,
                borderRadius: BorderRadius.circular(KVoiceRoomRow.radius),
              ),
              child: const Row(
                children: [
                  KSkeleton(
                    width: KVoiceRoomRow.height,
                    height: KVoiceRoomRow.height,
                    radius: KVoiceRoomRow.radius,
                  ),
                  SizedBox(width: KVoiceRoomRow.textStart),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        KSkeleton(width: 140, height: KSpacing.md),
                        SizedBox(height: KSpacing.md),
                        KSkeleton(width: 64, height: KSpacing.sm),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        childCount: KLiveGrid.skeletonCount,
      ),
    ),
  );
}

/// One voice room as a list row (ref 166): the cover square at the reading
/// start with the live mark and the category at its bottom; the title (up
/// to 2 lines); a chips line with the seats taken when the room has seats;
/// the viewer count with a mic at the end.
///
/// The ref's host level chip and "Popular" chip need data a room summary
/// does not carry (the host's level, the board rank), and "Room PK" has no
/// backend, so they are not drawn (no invented values).
class VoiceRoomRow extends StatelessWidget {
  const new({required this.room, super.key, this.onTap});

  final LiveRoomCardData room;
  final VoidCallback? onTap;

  static const seatsKey = Key('voiceRoom.seats');
  static const viewersKey = Key('voiceRoom.viewers');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final light = Theme.of(context).brightness == Brightness.light;
    final ink = light ? KVoiceRoomRow.lightInk : p.textPrimary;
    final white = KPalette.dark.textPrimary;
    final isNew = room.viewerCount < 1;
    final viewers = isNew
        ? l10n.liveCardNew
        : l10n.liveViewers(room.viewerCount, KFormat.grouped(room.viewerCount));
    final base = l10n.liveCardSemantics(room.hostName, viewers, room.title);
    final category = room.categoryName;
    final semantics = category == null || category.isEmpty
        ? base
        : l10n.liveCardSemanticsCategory(base, category);
    final seats = room.seatCount;
    return Semantics(
      button: onTap != null,
      container: true,
      label: semantics,
      child: ExcludeSemantics(
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: KLiveGrid.maxTextScale,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: KVoiceRoomRow.height),
            child: Material(
              color: p.surfaceRaised,
              borderRadius: BorderRadius.circular(KVoiceRoomRow.radius),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Stack(
                  children: [
                    PositionedDirectional(
                      start: 0,
                      top: 0,
                      bottom: 0,
                      width: KVoiceRoomRow.height,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          KLiveRoomPicture(room: room),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: [0.55, 1],
                                colors: [Color(0x00000000), Color(0x99000000)],
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            start: 5,
                            end: 4,
                            bottom: 4,
                            child: Row(
                              children: [
                                const KLiveEqualizer(
                                  color: KLiveGrid.liveMark,
                                  size: 9,
                                ),
                                if (category != null &&
                                    category.isNotEmpty) ...[
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      category,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: t.caption.copyWith(
                                        color: white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: KVoiceRoomRow.height + KVoiceRoomRow.textStart,
                        top: KVoiceRoomRow.textTop,
                        end: 10,
                        bottom: 8,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight:
                              KVoiceRoomRow.height - KVoiceRoomRow.textTop - 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              room.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodyStrong.copyWith(
                                color: ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: KSpacing.xs),
                            Row(
                              children: [
                                if (seats != null)
                                  _Chip(
                                    key: seatsKey,
                                    icon: Icons.event_seat_outlined,
                                    label: l10n.liveVoiceSeats(
                                      room.occupiedSeats,
                                      seats,
                                    ),
                                  ),
                                const Spacer(),
                                Row(
                                  key: viewersKey,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!isNew) ...[
                                      const Icon(
                                        Icons.mic_rounded,
                                        size: 13,
                                        color: KVoiceRoomRow.mic,
                                      ),
                                      const SizedBox(width: 2),
                                    ],
                                    Text(
                                      isNew
                                          ? l10n.liveCardNew
                                          : KFormat.compact(
                                              room.viewerCount,
                                              l10n,
                                            ),
                                      style: t.caption.copyWith(
                                        color: ink,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
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

class _Chip extends StatelessWidget {
  const new({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final light = Theme.of(context).brightness == Brightness.light;
    // A Kabso-neutral chip (the ref's tinted chips carry other data).
    final fill = light ? const Color(0xFFE6F7FB) : p.surfaceOverlay;
    final ink = light ? const Color(0xFF1D9BB8) : p.textSecondary;
    return Container(
      constraints: const BoxConstraints(minHeight: KVoiceRoomRow.chipHeight),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: ink),
          const SizedBox(width: 3),
          Text(
            label,
            style: context.textStyles.caption.copyWith(
              color: ink,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
