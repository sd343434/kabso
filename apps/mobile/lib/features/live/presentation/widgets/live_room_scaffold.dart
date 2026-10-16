import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Live room layout (G-07), **layout only**: the video is a slot, and every
/// zone is a slot the caller fills. Always dark.
///
/// Zones (top to bottom, inside the safe area):
/// - header row: [header] (host pill + follow) at the start, [viewers]
///   and the close button at the end;
/// - optional [pk] bar under the header;
/// - bottom: [chat] at the start above the [actionBar].
///
/// [overlay] (e.g. a gift sheet) sits above everything.
class KLiveRoomScaffold extends StatelessWidget {
  const new({
    required this.header,
    required this.chat,
    required this.actionBar,
    super.key,
    this.video,
    this.viewers,
    this.pk,
    this.onClose,
    this.overlay,
  });

  /// `null` shows [KLiveVideoPlaceholder] (no streaming yet, Phase 6).
  final Widget? video;
  final Widget header;
  final Widget? viewers;
  final Widget? pk;
  final Widget chat;
  final Widget actionBar;
  final VoidCallback? onClose;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final overlay = this.overlay;
    final viewers = this.viewers;
    final pk = this.pk;
    return KLiveSurface(
      child: Material(
        color: KPalette.dark.background,
        child: Stack(
          fit: StackFit.expand,
          children: [
            video ?? const KLiveVideoPlaceholder(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: header,
                          ),
                        ),
                        if (viewers != null) ...[
                          const SizedBox(width: KSpacing.sm),
                          viewers,
                        ],
                        KRoomIconButton(
                          icon: Icons.close,
                          label: l10n.liveClose,
                          onPressed: onClose,
                        ),
                      ],
                    ),
                    if (pk != null) ...[
                      const SizedBox(height: KSpacing.sm),
                      pk,
                    ],
                    const SizedBox(height: KSpacing.sm),
                    Expanded(child: chat),
                    const SizedBox(height: KSpacing.sm),
                    actionBar,
                  ],
                ),
              ),
            ),
            ?overlay,
          ],
        ),
      ),
    );
  }
}

/// Stand-in for the video surface until streaming exists.
class KLiveVideoPlaceholder extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    const p = KPalette.dark;
    return Semantics(
      label: context.l10n.liveVideoPlaceholder,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.surfaceOverlay, p.background],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.videocam_outlined,
            size: KSizes.avatarMd,
            color: p.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Host header (G-08): avatar, name and a follow button on a scrim pill.
class KHostPill extends StatelessWidget {
  const new({
    required this.hostName,
    required this.following,
    super.key,
    this.avatar,
    this.onFollow,
  });

  final String hostName;
  final ImageProvider? avatar;
  final bool following;
  final VoidCallback? onFollow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const p = KPalette.dark;
    final text = context.textStyles;
    return Container(
      padding: const EdgeInsetsDirectional.only(
        start: KSpacing.xxs,
        end: KSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: p.scrim,
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KAvatar(name: hostName, image: avatar, size: KSizes.avatarSm),
          const SizedBox(width: KSpacing.sm),
          Flexible(
            child: Text(
              hostName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
              style: text.bodyStrong.copyWith(color: p.textPrimary),
            ),
          ),
          const SizedBox(width: KSpacing.xs),
          // 48 dp hit target around a compact visual pill.
          Semantics(
            button: true,
            toggled: following,
            label: following ? l10n.liveFollowing : l10n.liveFollow,
            child: ExcludeSemantics(
              child: InkResponse(
                onTap: onFollow,
                radius: KSizes.minTouchTarget / 2,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: KSizes.minTouchTarget,
                    minWidth: KSizes.minTouchTarget,
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Container(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: KSpacing.md,
                        vertical: KSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: following ? null : p.primary,
                        border: following
                            ? Border.all(color: p.borderStrong)
                            : null,
                        borderRadius: BorderRadius.circular(KRadius.pill),
                      ),
                      child: Text(
                        following ? l10n.liveFollowing : l10n.liveFollow,
                        textScaler: TextScaler.noScaling,
                        style: text.label.copyWith(color: p.onPrimary),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Viewer strip: up to `KMetrics.viewerStripMax` overlapping avatars and
/// the viewer count chip.
class KViewerStrip extends StatelessWidget {
  const new({required this.names, required this.count, super.key});

  final List<String> names;
  final int count;

  @override
  Widget build(BuildContext context) {
    final shown = names.take(KMetrics.viewerStripMax).toList();
    const step = KSizes.avatarSm - KSpacing.md;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            width: shown.isEmpty
                ? 0
                : KSizes.avatarSm + step * (shown.length - 1),
            height: KSizes.avatarSm,
            child: Stack(
              children: [
                for (var i = 0; i < shown.length; i++)
                  PositionedDirectional(
                    start: step * i,
                    child: KAvatar(name: shown[i], size: KSizes.avatarSm),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: KSpacing.xs),
        KViewerCountChip(count: count),
      ],
    );
  }
}

/// Bottom action bar (G-13): comment field stand-in at the start, share and
/// the gold gift button at the end.
class KRoomActionBar extends StatelessWidget {
  const new({super.key, this.onComment, this.onShare, this.onGift});

  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onGift;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const p = KPalette.dark;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: l10n.liveCommentHint,
            child: ExcludeSemantics(
              child: Material(
                color: p.scrim,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onComment,
                  child: Container(
                    height: KSizes.minTouchTarget,
                    alignment: AlignmentDirectional.centerStart,
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: KSpacing.lg,
                    ),
                    child: Text(
                      l10n.liveCommentHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.body.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: KSpacing.sm),
        KRoomIconButton(
          icon: Icons.share_outlined,
          label: l10n.liveShare,
          onPressed: onShare,
        ),
        const SizedBox(width: KSpacing.sm),
        KRoomIconButton(
          icon: Icons.card_giftcard,
          label: l10n.liveGifts,
          onPressed: onGift,
          color: KBrandColors.gold,
        ),
      ],
    );
  }
}

/// 48 dp circular icon button on `scrim`, for use over video.
class KRoomIconButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    super.key,
    this.onPressed,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: ExcludeSemantics(
      child: Material(
        color: KPalette.dark.scrim,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: KSizes.minTouchTarget,
            child: Icon(
              icon,
              size: KMetrics.iconMd,
              color: color ?? KPalette.dark.textPrimary,
            ),
          ),
        ),
      ),
    ),
  );
}
