import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Room states (HOME_LIVE_LAYOUT_DECISIONS §3 HL-L10).
///
/// Production uses [KRoomVideoUnavailable] (no media provider yet, B1),
/// [KRoomEndedOverlay] and [KRoomMessage] (not found, error, offline).
/// [KRoomCameraOff], [KRoomStatusChip] and [KRoomReconnecting] need signals
/// from a media SDK, so today they appear only in fixtures and the gallery;
/// no production path shows them.

/// The honest video layer while video cannot play (B1): the dark backdrop
/// with a "video unavailable" message. Never a fake video.
class KRoomVideoUnavailable extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return KLiveVideoPlaceholder(
      child: _StageMessage(
        key: const Key('room.videoUnavailable'),
        icon: Icons.videocam_off_outlined,
        title: l10n.liveRoomVideoUnavailableTitle,
        body: l10n.liveRoomVideoUnavailableBody,
      ),
    );
  }
}

/// HL-L10 "Missing video": the host's camera is off. Fixture-only.
class KRoomCameraOff extends StatelessWidget {
  const new({required this.hostName, super.key, this.avatar});

  final String hostName;
  final ImageProvider? avatar;

  @override
  Widget build(BuildContext context) {
    const p = KPalette.dark;
    return ColoredBox(
      color: p.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KAvatar(name: hostName, image: avatar, size: KSizes.avatarLg),
            const SizedBox(height: KSpacing.md),
            Text(
              context.l10n.liveRoomCameraOff,
              textAlign: TextAlign.center,
              textScaler: MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
              style: context.textStyles.bodyStrong.copyWith(
                color: p.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// HL-L10 "Poor connectivity": a top-centre chip. Fixture-only.
class KRoomStatusChip extends StatelessWidget {
  const new({required this.label, super.key, this.icon = Icons.warning_amber});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const p = KPalette.dark;
    return Semantics(
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(
            minHeight: KMetrics.roomInfoChipHeight,
          ),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: KSpacing.md,
          ),
          decoration: BoxDecoration(
            color: p.scrim,
            borderRadius: BorderRadius.circular(KRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: KMetrics.iconSm, color: p.warning),
              const SizedBox(width: KSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
                  style: context.textStyles.label.copyWith(
                    color: p.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// HL-L10 "Reconnecting": the last frame dimmed by 30 % with a centred
/// progress indicator (a static icon with reduce motion) and the label.
/// Fixture-only.
class KRoomReconnecting extends StatelessWidget {
  const new({required this.frame, super.key});

  /// The last video frame.
  final Widget frame;

  @override
  Widget build(BuildContext context) {
    const p = KPalette.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        frame,
        const ColoredBox(color: KMetrics.reconnectingDim),
        Center(
          child: Container(
            padding: const EdgeInsets.all(KSpacing.lg),
            decoration: BoxDecoration(
              color: p.scrim,
              borderRadius: BorderRadius.circular(KRadius.lg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: KMetrics.iconMd,
                  child: reduceMotion
                      ? Icon(
                          Icons.sync_rounded,
                          size: KMetrics.iconMd,
                          color: p.textPrimary,
                        )
                      : CircularProgressIndicator(
                          strokeWidth: KMetrics.stroke,
                          color: p.textPrimary,
                        ),
                ),
                const SizedBox(height: KSpacing.sm),
                Text(
                  context.l10n.liveRoomReconnecting,
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
                  style: context.textStyles.bodyStrong.copyWith(
                    color: p.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// HL-L10 "Host left / ended": a full overlay on `background` at 90 %
/// with the host, "This live has ended", the end reason, an optional
/// follow action and "Back to live rooms".
class KRoomEndedOverlay extends StatelessWidget {
  const new({
    required this.hostName,
    required this.reason,
    required this.onBack,
    super.key,
    this.avatar,
    this.followAction,
  });

  final String hostName;
  final ImageProvider? avatar;

  /// The localized end reason.
  final String reason;
  final VoidCallback onBack;

  /// The follow button, only when the viewer may follow and does not yet.
  final Widget? followAction;

  @override
  Widget build(BuildContext context) {
    const p = KPalette.dark;
    final l10n = context.l10n;
    final text = context.textStyles;
    final followAction = this.followAction;
    return ColoredBox(
      key: const Key('room.ended'),
      color: p.background.withValues(alpha: KMetrics.endedOverlayOpacity),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KAvatar(name: hostName, image: avatar, size: KSizes.avatarLg),
                  const SizedBox(height: KSpacing.md),
                  Text(
                    hostName,
                    textAlign: TextAlign.center,
                    style: text.bodyStrong.copyWith(color: p.textPrimary),
                  ),
                  const SizedBox(height: KSpacing.xl),
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      l10n.liveRoomEndedTitle,
                      textAlign: TextAlign.center,
                      style: text.title.copyWith(color: p.textPrimary),
                    ),
                  ),
                  const SizedBox(height: KSpacing.sm),
                  Text(
                    reason,
                    textAlign: TextAlign.center,
                    style: text.body.copyWith(color: p.textSecondary),
                  ),
                  const SizedBox(height: KSpacing.xl),
                  if (followAction != null) ...[
                    followAction,
                    const SizedBox(height: KSpacing.sm),
                  ],
                  KButton(
                    key: const Key('room.back'),
                    label: l10n.liveRoomBackToLive,
                    onPressed: onBack,
                    variant: followAction == null
                        ? KButtonVariant.primary
                        : KButtonVariant.secondary,
                    expand: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A full-screen room message with the close button at the top end: not
/// found, failed to load, offline.
class KRoomMessage extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.message,
    required this.onClose,
    super.key,
    this.detail,
    this.onRetry,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? detail;
  final VoidCallback onClose;
  final VoidCallback? onRetry;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onRetry = this.onRetry;
    return KLiveSurface(
      child: Material(
        color: KPalette.dark.background,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: KEmptyState(
                  icon: icon,
                  iconColor: iconColor,
                  title: title,
                  message: message,
                  detail: detail,
                  actionLabel: onRetry != null
                      ? l10n.actionRetry
                      : l10n.liveRoomBackToLive,
                  onAction: onRetry ?? onClose,
                  actionVariant: KButtonVariant.primary,
                  secondaryActionLabel: onRetry != null
                      ? l10n.liveRoomBackToLive
                      : null,
                  onSecondaryAction: onRetry != null ? onClose : null,
                ),
              ),
              PositionedDirectional(
                top: KSpacing.sm,
                end: KSpacing.sm,
                child: KRoomIconButton(
                  icon: Icons.close,
                  label: l10n.liveClose,
                  onPressed: onClose,
                  visualSize: KMetrics.closeVisual,
                  iconSize: KMetrics.closeIcon,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageMessage extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    const p = KPalette.dark;
    final text = context.textStyles;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(icon, size: KSizes.avatarMd, color: p.textSecondary),
            ),
            const SizedBox(height: KSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              textScaler: scaler,
              style: text.bodyStrong.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: KSpacing.xs),
            Text(
              body,
              textAlign: TextAlign.center,
              textScaler: scaler,
              style: text.caption.copyWith(color: p.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
