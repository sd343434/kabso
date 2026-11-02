import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_rocket_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Geometry of the party page's list cards. Measured on ref 166 (D131)
/// and again on the D246 reference (393 lp, the same values): cards
/// 863 × 161 px, 30 px from the sides, 21 px apart; the cover a 161 px
/// square at the reading start.
abstract final class KVoiceRoomRow {
  /// Side inset (30 px = 12.8 lp).
  static const double inset = 12.8;

  /// Card height and cover side (161 px = 68.6 lp).
  static const double height = 68.6;

  /// Gap between cards (21 px = 8.9 lp).
  static const double gap = 8.9;

  /// Corner radius of the card and of its cover (D246: 13 px ≈ 5.5 lp, E
  /// from the corner's run-in).
  static const double radius = 5.5;

  /// The title's start after the cover (25 px = 10.6 lp) and its top.
  static const double textStart = 10.6;
  static const double textTop = 6.8;

  /// The text's end inset (the count ends 22 px = 9.4 lp in) and the pills'
  /// bottom (23 px = 9.8 lp).
  static const double textEnd = 9.4;
  static const double textBottom = 9.8;

  /// D246: title (cap 22 px = 9.4 lp → 13 sp bold), subtitle (12 sp,
  /// sampled `#8C8F97`) and count (digits 18 px → 11 sp).
  static const double title = 13;
  static const double subtitle = 12;
  static const double count = 11;

  /// The pills line's height (32–33 px = 14 lp), their gap (≈ 7 lp) and
  /// label (≈ 10 sp bold).
  static const double chipHeight = 14;
  static const double chipGap = 6;
  static const double chipFont = 10;

  /// The cover's kind mark: 6.4 lp in, 4.5 lp up (M).
  static const double markStart = 6.4;
  static const double markBottom = 4.5;

  /// Light theme: the card text (sampled `#282828`), the subtitle grey,
  /// and the count's icon (sampled `#43E7E4`).
  static const Color lightInk = Color(0xFF282828);
  static const Color lightSubtitle = Color(0xFF8C8F97);
  static const Color mic = Color(0xFF43E7E4);
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

/// One room as a party-page card (D246, the owner's reference): the cover
/// square at the reading start, rounded, with the live mark and the room's
/// kind at its bottom («ılı بث صوتي»); the title in bold (two lines when
/// there is no topic) and the host's topic in grey under it; a pills line
/// with only what the API says — «PK» while the room is in a PK (D241),
/// «مميز» in a paid slot (D154b) and the seats taken when the room has
/// seats; the viewer count at the end with a mic (audio, podcast) or a
/// camera (multi).
///
/// The ref's host level pill and "Popular" pill need data a room summary
/// does not carry (the host's level, a popularity flag), so they are not
/// drawn (no invented values).
class VoiceRoomRow extends StatelessWidget {
  const new({required this.room, super.key, this.onTap});

  final LiveRoomCardData room;
  final VoidCallback? onTap;

  static const kindKey = Key('voiceRoom.kind');
  static const topicKey = Key('voiceRoom.topic');
  static const pkKey = Key('voiceRoom.pk');
  static const featuredKey = Key('voiceRoom.featured');
  static const seatsKey = Key('voiceRoom.seats');
  static const viewersKey = Key('voiceRoom.viewers');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final light = Theme.of(context).brightness == Brightness.light;
    final ink = light ? KVoiceRoomRow.lightInk : p.textPrimary;
    final grey = light ? KVoiceRoomRow.lightSubtitle : p.textSecondary;
    final white = KPalette.dark.textPrimary;
    final isNew = room.viewerCount < 1;
    final viewers = isNew
        ? l10n.liveCardNew
        : l10n.liveViewers(room.viewerCount, KFormat.grouped(room.viewerCount));
    final kind = room.isPodcast
        ? l10n.liveCategoryPodcast
        : room.isMulti
        ? l10n.liveCategoryMulti
        : room.isAudio
        ? l10n.liveCategoryAudio
        : l10n.liveCategoryLive;
    final base = l10n.liveCardSemanticsMode(
      l10n.liveCardSemantics(room.hostName, viewers, room.title),
      room.inPk ? '$kind, ${l10n.pkBadge}' : kind,
    );
    final category = room.categoryName;
    final withCategory = category == null || category.isEmpty
        ? base
        : l10n.liveCardSemanticsCategory(base, category);
    final semantics = room.featured
        ? '${l10n.liveBoostFeatured}, $withCategory'
        : withCategory;
    final topic = room.topic?.trim();
    final hasTopic = topic != null && topic.isNotEmpty;
    final seats = room.seatCount;
    final radius = BorderRadius.circular(KVoiceRoomRow.radius);
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
              borderRadius: radius,
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
                      child: ClipRRect(
                        borderRadius: radius,
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
                                  colors: [
                                    Color(0x00000000),
                                    Color(0x99000000),
                                  ],
                                ),
                              ),
                            ),
                            // The mark sits on a fixed 68.6 lp picture: it
                            // does not grow with the text size (it would
                            // be cut), the rest of the card does.
                            PositionedDirectional(
                              start: KVoiceRoomRow.markStart,
                              end: 3,
                              bottom: KVoiceRoomRow.markBottom,
                              child: MediaQuery.withNoTextScaling(
                                child: Row(
                                  key: kindKey,
                                  children: [
                                    const KLiveEqualizer(
                                      color: KLiveGrid.liveMark,
                                      size: 9,
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        kind,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: t.caption.copyWith(
                                          color: white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          height: 1.1,
                                          shadows: const [
                                            Shadow(
                                              color: Color(0x66000000),
                                              blurRadius: 3,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: KVoiceRoomRow.height + KVoiceRoomRow.textStart,
                        top: KVoiceRoomRow.textTop,
                        end: KVoiceRoomRow.textEnd,
                        bottom: KVoiceRoomRow.textBottom,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight:
                              KVoiceRoomRow.height -
                              KVoiceRoomRow.textTop -
                              KVoiceRoomRow.textBottom,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  room.title,
                                  maxLines: hasTopic ? 1 : 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.bodyStrong.copyWith(
                                    color: ink,
                                    fontSize: KVoiceRoomRow.title,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                  ),
                                ),
                                if (hasTopic)
                                  Text(
                                    topic,
                                    key: topicKey,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.caption.copyWith(
                                      color: grey,
                                      fontSize: KVoiceRoomRow.subtitle,
                                      fontWeight: FontWeight.w600,
                                      height: 1.25,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: KSpacing.xxs),
                            Row(
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: KVoiceRoomRow.chipGap,
                                    runSpacing: 2,
                                    children: [
                                      if (room.inPk)
                                        _Chip(
                                          key: pkKey,
                                          label: l10n.pkBadge,
                                          pk: true,
                                        ),
                                      if (room.featured)
                                        DefaultTextStyle.merge(
                                          key: featuredKey,
                                          style: t.caption.copyWith(
                                            height: 1.2,
                                          ),
                                          child: KFeaturedPill(
                                            label: l10n.liveBoostFeatured,
                                          ),
                                        ),
                                      if (seats != null)
                                        _Chip(
                                          key: seatsKey,
                                          icon: Icons.event_seat_outlined,
                                          label: l10n.liveVoiceSeats(
                                            room.occupiedSeats,
                                            seats,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: KSpacing.xs),
                                Row(
                                  key: viewersKey,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!isNew) ...[
                                      Icon(
                                        room.isMulti
                                            ? Icons.videocam_rounded
                                            : Icons.mic_rounded,
                                        size: 13,
                                        color: KVoiceRoomRow.mic,
                                      ),
                                      const SizedBox(width: 3),
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
                                        fontSize: KVoiceRoomRow.count,
                                        fontWeight: FontWeight.w500,
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

/// A card pill (the ref's tinted pills, in Kabso's colours): the seats
/// (cyan) or «PK» (brand red, italic bold).
class _Chip extends StatelessWidget {
  const new({required this.label, super.key, this.icon, this.pk = false});

  final IconData? icon;
  final String label;
  final bool pk;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final light = Theme.of(context).brightness == Brightness.light;
    final fill = pk
        ? (light ? const Color(0xFFFFE9EC) : const Color(0x33E8173A))
        : (light ? const Color(0xFFE6F7FB) : p.surfaceOverlay);
    final ink = pk
        ? KBrandColors.red500
        : (light ? const Color(0xFF1D9BB8) : p.textSecondary);
    final icon = this.icon;
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
          if (icon != null) ...[
            Icon(icon, size: 10, color: ink),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: context.textStyles.caption.copyWith(
              color: ink,
              fontSize: KVoiceRoomRow.chipFont,
              fontWeight: pk ? FontWeight.w800 : FontWeight.w700,
              fontStyle: pk ? FontStyle.italic : null,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
