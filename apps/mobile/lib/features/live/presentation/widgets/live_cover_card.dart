import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/creator_live_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Live room tile (DESIGN_SYSTEM §9.10, HOME_LIVE_LAYOUT_DECISIONS §6):
/// 3:4 cover, radius `sm`, no accent line (VG-10).
///
/// Owner (2026-11-08): «أرى أن المعلومات على بطاقة البث كثيرة» — the card
/// carries only:
/// - top-start: ONE type badge — LIVE (KL-047; [showLiveBadge] turns it
///   off), PK (solid), multi-guest (seats + count), or the voice / podcast /
///   streamer label the hub already uses («بث صوتي» …) — then the viewer
///   count (0 shows 0: the real count; the «جديد» chip is gone). The group
///   scales down rather than run into the creator mark on narrow cards.
/// - top-end: a content creator's live — the small purple creator mark
///   (D295's colour and sparkle, no text).
/// - bottom: 50 % scrim and the title the host set (the host's name when it
///   is empty), up to 2 lines with an ellipsis. No host row, category, topic
///   or cherries (the room is ranked by its cherries on the server; the room's
///   host pill shows them, D310).
/// - missing or broken cover: the host avatar on `surfaceRaised`, no error
///   text (VG-13).
/// - press: scales to 0.98 for `durationFast` (instant with reduce motion).
///
/// Announced as "{host}, live, {n viewers}, {title}, {type}[, creator]
/// [, {category}]".
class KLiveCoverCard extends StatelessWidget {
  const new({
    required this.room,
    super.key,
    this.onTap,
    this.showLiveBadge = true,
  });

  static const typeKey = Key('liveCard.type');
  static const titleKey = Key('liveCard.title');

  final LiveRoomCardData room;
  final VoidCallback? onTap;
  final bool showLiveBadge;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final white = KPalette.dark.textPrimary;
    final cover = room.cover;
    final guests = room.guestCount;
    final title = room.title.trim().isEmpty ? room.hostName : room.title;
    // One type: PK, multi-guest, the voice kinds' own labels, else LIVE.
    final voiceLabel = room.isPodcast
        ? l10n.liveCategoryPodcast
        : room.isAudio
        ? l10n.liveCategoryAudio
        : room.isStreamer
        ? l10n.liveCardTagStreamer
        : null;
    final type = room.inPk
        ? l10n.pkBadge
        : guests != null
        ? l10n.liveMultiGuest(guests)
        : room.isMulti
        ? l10n.liveCategoryMulti
        : voiceLabel ?? l10n.liveBadge;
    final Widget? typeBadge = room.inPk
        ? const KBadge.pk()
        : guests != null
        ? KBadge.multiGuest(count: guests)
        : room.isMulti
        ? _TypePill(label: l10n.liveCategoryMulti)
        : voiceLabel != null
        ? _TypePill(label: voiceLabel)
        : showLiveBadge
        ? const KBadge.live()
        : null;
    final base = l10n.liveCardSemantics(
      room.hostName,
      l10n.liveViewers(room.viewerCount, KFormat.grouped(room.viewerCount)),
      title,
    );
    final withType = l10n.liveCardSemanticsMode(base, type);
    final withCreator = room.hostIsCreator
        ? l10n.liveCardSemanticsMode(withType, l10n.liveCreatorBadge)
        : withType;
    final category = room.categoryName;
    final semantics = category != null && category.isNotEmpty
        ? l10n.liveCardSemanticsCategory(withCreator, category)
        : withCreator;
    final fallback = _CoverFallback(room: room);

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
                          if (typeBadge != null) ...[
                            KeyedSubtree(key: typeKey, child: typeBadge),
                            const SizedBox(width: KSpacing.xs),
                          ],
                          KViewerCountChip(count: room.viewerCount),
                        ],
                      ),
                    ),
                  ),
                  if (room.hostIsCreator) ...[
                    const SizedBox(width: KSpacing.xs),
                    const CreatorLiveBadge(iconOnly: true),
                  ],
                ],
              ),
            ),
            PositionedDirectional(
              start: KSpacing.sm,
              end: KSpacing.sm,
              bottom: KSpacing.sm,
              child: Text(
                title,
                key: titleKey,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodyStrong.copyWith(color: white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A voice, podcast, streamer or plain multi-guest live's type, as the badge
/// row's other pills (`scrim`, 20 dp).
class _TypePill extends StatelessWidget {
  const new({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    height: KMetrics.badgeHeight,
    padding: const EdgeInsetsDirectional.symmetric(horizontal: KSpacing.sm),
    decoration: BoxDecoration(
      color: KPalette.dark.scrim,
      borderRadius: BorderRadius.circular(KRadius.pill),
    ),
    child: Center(
      widthFactor: 1,
      child: Text(
        label,
        maxLines: 1,
        textScaler: TextScaler.noScaling,
        style: context.textStyles.label.copyWith(
          color: KPalette.dark.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
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
