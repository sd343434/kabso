import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Live room tile (DESIGN_SYSTEM §9.10, HOME_LIVE_LAYOUT_DECISIONS §6):
/// 3:4 cover, radius `sm`, no accent line (VG-10).
///
/// - top-start: the LIVE badge (KL-047 owner request, reversing VG-10's
///   "no LIVE badge in grids"; [showLiveBadge] turns it off), then the viewer
///   chip only when at least 1 viewer is reported, otherwise "New" (VG-11):
///   a count is never invented. The group scales down rather than run into
///   the mode tag on narrow cards.
/// - top-end: room mode tag, only when true: PK (solid) or multi-guest.
/// - bottom: 50 % scrim, host (`bodyStrong`), title (`caption`) and the
///   category name when the room has one (`caption` after a `#` glyph),
///   1 line each; with
///   a cover, a `sm` host avatar before them (D39: creator identity on every
///   card).
/// - missing or broken cover: the host avatar on `surfaceRaised`, no error
///   text (VG-13).
/// - press: scales to 0.98 for `durationFast` (instant with reduce motion).
///
/// Announced as "{host}, live, {n viewers | New}, {title}[, {mode}]
/// [, {category}]".
class KLiveCoverCard extends StatelessWidget {
  const new({
    required this.room,
    super.key,
    this.onTap,
    this.showLiveBadge = true,
  });

  static const categoryKey = Key('liveCard.category');

  final LiveRoomCardData room;
  final VoidCallback? onTap;
  final bool showLiveBadge;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final white = KPalette.dark.textPrimary;
    final cover = room.cover;
    final isNew = room.viewerCount < 1;
    final guests = room.guestCount;
    final mode = room.inPk
        ? l10n.pkBadge
        : guests == null
        ? null
        : l10n.liveMultiGuest(guests);
    final base = l10n.liveCardSemantics(
      room.hostName,
      isNew
          ? l10n.liveCardNew
          : l10n.liveViewers(
              room.viewerCount,
              KFormat.grouped(room.viewerCount),
            ),
      room.title,
    );
    final withMode = mode == null
        ? base
        : l10n.liveCardSemanticsMode(base, mode);
    // CP-012: the points, read like the mode.
    final withScore = room.score > 0
        ? l10n.liveCardSemanticsMode(
            withMode,
            l10n.liveScore(room.score, KFormat.compact(room.score, l10n)),
          )
        : withMode;
    final category = room.categoryName;
    final hasCategory = category != null && category.isNotEmpty;
    final semantics = hasCategory
        ? l10n.liveCardSemanticsCategory(withScore, category)
        : withScore;
    final fallback = _CoverFallback(room: room);
    final Widget viewers = isNew
        ? const KBadge.newRoom()
        : KViewerCountChip(count: room.viewerCount);

    return Semantics(
      button: onTap != null,
      label: semantics,
      container: true,
      child: ExcludeSemantics(
        child: _CardFrame(
          onTap: onTap,
          children: [
            if (cover == null)
              fallback
            else
              Image(
                image: cover,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => fallback,
              ),
            const _BottomScrim(),
            PositionedDirectional(
              top: KSpacing.sm,
              start: KSpacing.sm,
              end: KSpacing.sm,
              child: Row(
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showLiveBadge) ...[
                            const KBadge.live(),
                            const SizedBox(width: KSpacing.xs),
                          ],
                          viewers,
                          // CP-012: the points rooms compete on (D95).
                          if (room.score > 0) ...[
                            const SizedBox(width: KSpacing.xs),
                            KScoreChip(score: room.score),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (room.inPk) ...[
                    const SizedBox(width: KSpacing.xs),
                    const KBadge.pk(),
                  ] else if (guests != null) ...[
                    const SizedBox(width: KSpacing.xs),
                    KBadge.multiGuest(count: guests),
                  ],
                ],
              ),
            ),
            PositionedDirectional(
              start: KSpacing.sm,
              end: KSpacing.sm,
              bottom: KSpacing.sm,
              child: Row(
                children: [
                  // D39: the creator is identifiable on every card. Without
                  // a (working) cover the large fallback avatar shows them.
                  if (cover != null) _CoverHostAvatar(room: room, cover: cover),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          room.hostName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyStrong.copyWith(color: white),
                        ),
                        Text(
                          room.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.caption.copyWith(color: white),
                        ),
                        if (hasCategory)
                          Row(
                            key: KLiveCoverCard.categoryKey,
                            children: [
                              Icon(
                                Icons.tag_rounded,
                                size: KMetrics.iconXs,
                                color: white,
                              ),
                              const SizedBox(width: KSpacing.xxs),
                              Flexible(
                                child: Text(
                                  category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.caption.copyWith(color: white),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading state with the card's anatomy (§9.10 "loading = Skeleton").
class KLiveCoverCardSkeleton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => const _CardFrame(
    // Bars are `surfaceRaised` (KSkeleton) on a `surface` frame so they read
    // as blocks when the shimmer is off (reduce motion).
    skeleton: true,
    children: [
      PositionedDirectional(
        top: KSpacing.sm,
        start: KSpacing.sm,
        child: KSkeleton(
          width: KSizes.avatarMd,
          height: KMetrics.badgeHeight,
          radius: KRadius.pill,
        ),
      ),
      PositionedDirectional(
        start: KSpacing.sm,
        end: KSpacing.xxxl,
        bottom: KSpacing.sm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            KSkeleton(width: KSizes.avatarLg, height: KSpacing.md),
            SizedBox(height: KSpacing.xs),
            KSkeleton(width: double.infinity, height: KSpacing.sm),
          ],
        ),
      ),
    ],
  );
}

class _CardFrame extends StatefulWidget {
  const new({required this.children, this.onTap, this.skeleton = false});

  final List<Widget> children;
  final VoidCallback? onTap;
  final bool skeleton;

  @override
  State<_CardFrame> createState() => _CardFrameState();
}

class _CardFrameState extends State<_CardFrame> {
  bool _pressed = false;

  void _press(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    return AnimatedScale(
      scale: _pressed ? KMetrics.cardPressedScale : 1,
      duration: KMotion.of(context, KMotion.fast),
      curve: KMotion.standard,
      child: AspectRatio(
        aspectRatio: KSizes.liveCardAspect,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(KRadius.sm),
          child: Material(
            color: widget.skeleton
                ? context.palette.surface
                : context.palette.surfaceRaised,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ...widget.children,
                if (onTap != null)
                  InkWell(onTap: onTap, onHighlightChanged: _press),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomScrim extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.bottomCenter,
    child: FractionallySizedBox(
      heightFactor: KMetrics.cardScrimFraction,
      widthFactor: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              KPalette.dark.scrim.withValues(alpha: 0),
              KPalette.dark.scrim,
            ],
          ),
        ),
      ),
    ),
  );
}

/// Missing or broken cover (VG-13): the host avatar (`lg`, initials when
/// there is no photo) on `surfaceRaised`. A broken cover is not something
/// the viewer can act on, so there is no error text.
class _CoverFallback extends StatelessWidget {
  const new({required this.room});

  final LiveRoomCardData room;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.palette.surfaceRaised,
    child: Align(
      // Slightly above centre so the avatar clears the bottom text.
      alignment: const AlignmentDirectional(0, -0.3),
      child: KAvatar(
        name: room.hostName,
        image: room.hostAvatar,
        size: KSizes.avatarLg,
      ),
    ),
  );
}

/// The `sm` host avatar before the host name on a card with a cover (D39).
/// Hidden once the cover fails to load: the fallback then shows the large
/// avatar, and one avatar per card is enough.
class _CoverHostAvatar extends StatefulWidget {
  const new({required this.room, required this.cover});

  final LiveRoomCardData room;
  final ImageProvider cover;

  @override
  State<_CoverHostAvatar> createState() => _CoverHostAvatarState();
}

class _CoverHostAvatarState extends State<_CoverHostAvatar> {
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(
    (_, _) {},
    onError: (_, _) {
      if (mounted && !_failed) setState(() => _failed = true);
    },
  );
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_CoverHostAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cover != widget.cover) {
      _failed = false;
      _resolve();
    }
  }

  void _resolve() {
    final stream = widget.cover.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: KSpacing.xs),
      child: KAvatar(
        name: widget.room.hostName,
        image: widget.room.hostAvatar,
        size: KSizes.avatarSm,
      ),
    );
  }
}
