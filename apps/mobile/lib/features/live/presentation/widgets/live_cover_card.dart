import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Live room tile (DESIGN_SYSTEM §9.10, G-01): 3:4 cover, radius `sm`,
/// 2 dp live-gradient top accent, LIVE + viewers at top-start, PK at
/// top-end, bottom scrim with host (`bodyStrong`) and title (`caption`,
/// one line). Announced as "{host}, live, {n} viewers, {title}".
class KLiveCoverCard extends StatelessWidget {
  const new({required this.room, super.key, this.onTap});

  final LiveRoomCardData room;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final white = KPalette.dark.textPrimary;
    final cover = room.cover;
    final semantics = l10n.liveCardSemantics(
      room.hostName,
      l10n.liveViewers(room.viewerCount, KFormat.grouped(room.viewerCount)),
      room.title,
    );

    return Semantics(
      button: onTap != null,
      label: semantics,
      container: true,
      child: ExcludeSemantics(
        child: _CardFrame(
          onTap: onTap,
          children: [
            if (cover == null)
              const _CoverUnavailable()
            else
              Image(
                image: cover,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const _CoverUnavailable(),
              ),
            const _BottomScrim(),
            const PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              height: KMetrics.stroke,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                    colors: KBrandColors.gradientLive,
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: KSpacing.sm,
              start: KSpacing.sm,
              child: KLiveWithViewers(count: room.viewerCount),
            ),
            if (room.inPk)
              const PositionedDirectional(
                top: KSpacing.sm,
                end: KSpacing.sm,
                child: KBadge.pk(),
              ),
            PositionedDirectional(
              start: KSpacing.sm,
              end: KSpacing.sm,
              bottom: KSpacing.sm,
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
          width: KSizes.avatarLg,
          height: KMetrics.badgeHeight,
          radius: KRadius.xs,
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

class _CardFrame extends StatelessWidget {
  const new({required this.children, this.onTap, this.skeleton = false});

  final List<Widget> children;
  final VoidCallback? onTap;
  final bool skeleton;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: KSizes.liveCardAspect,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(KRadius.sm),
      child: Material(
        color: skeleton
            ? context.palette.surface
            : context.palette.surfaceRaised,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ...children,
            if (onTap != null) InkWell(onTap: onTap),
          ],
        ),
      ),
    ),
  );
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

/// Media failed or missing (§9.10 error): `surfaceOverlay` block with a
/// broken-image icon and a short caption.
class _CoverUnavailable extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ColoredBox(
      color: p.surfaceOverlay,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.broken_image_outlined,
                size: KMetrics.iconLg,
                color: p.textSecondary,
              ),
              const SizedBox(height: KSpacing.xs),
              Text(
                context.l10n.liveCoverUnavailable,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: context.textStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
