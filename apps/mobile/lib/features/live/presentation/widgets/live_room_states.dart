import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_interruption.dart';
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
        status: l10n.liveStatusUnavailable,
        title: l10n.liveRoomVideoUnavailableTitle,
        body: l10n.liveRoomVideoUnavailableBody,
      ),
    );
  }
}

/// HL-L10 "Missing video": the host's camera is off. Fixture-only.
/// D216: the shared interruption emblem (the host's picture with a camera
/// badge), no card.
class KRoomCameraOff extends StatelessWidget {
  const new({required this.hostName, super.key, this.avatar});

  final String hostName;
  final ImageProvider? avatar;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: KPalette.dark.surface,
    child: Center(
      child: KLiveInterruption(
        leading: KLiveHostPicture(
          image: avatar,
          size: KLiveInterruption.pictureCompact,
        ),
        badgeIcon: Icons.videocam_off_rounded,
        title: context.l10n.liveRoomCameraOff,
        framed: false,
        compact: true,
        liveRegion: false,
      ),
    ),
  );
}

/// HL-L10 "Poor connectivity": a top-centre chip. Fixture-only.
/// D216: the live's glass pill with a warning signal icon.
class KRoomStatusChip extends StatelessWidget {
  const new({
    required this.label,
    super.key,
    this.icon = Icons.signal_cellular_alt_2_bar_rounded,
  });

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
          padding: const EdgeInsetsDirectional.fromSTEB(
            KSpacing.xs,
            KSpacing.xxs,
            KSpacing.md,
            KSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: const Color(0x8C0B0B0D),
            borderRadius: BorderRadius.circular(KRadius.pill),
            border: Border.all(color: const Color(0x24FFFFFF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: KMetrics.iconMd,
                height: KMetrics.iconMd,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.warning.withValues(alpha: 0.2),
                ),
                child: Icon(icon, size: KMetrics.iconXs, color: p.warning),
              ),
              const SizedBox(width: KSpacing.xs + KSpacing.xxs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
                  style: context.textStyles.label.copyWith(
                    color: p.textPrimary,
                    shadows: KLiveColors.glassShadow,
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

/// HL-L10 "Reconnecting": the last frame dimmed with the interruption card
/// (D216: the turning arc; still with reduce motion). Fixture-only.
class KRoomReconnecting extends StatelessWidget {
  const new({required this.frame, super.key});

  /// The last video frame.
  final Widget frame;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Stack(
      fit: StackFit.expand,
      children: [
        frame,
        const ColoredBox(color: KMetrics.reconnectingDim),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.xl),
            child: KLiveInterruption(
              icon: Icons.wifi_rounded,
              busy: true,
              status: l10n.liveStatusConnectionLost,
              title: l10n.liveRoomReconnecting,
              message: l10n.liveRoomReconnectingBody,
            ),
          ),
        ),
      ],
    );
  }
}

/// HL-L10 "Host left / ended": a full overlay on `background` at 90 %
/// with the host, "This live has ended", the end reason, an optional
/// follow action and "Back to live rooms". D216: on the interruption card,
/// the host's picture with a badge saying why ([reasonIcon]).
class KRoomEndedOverlay extends StatelessWidget {
  const new({
    required this.hostName,
    required this.reason,
    required this.onBack,
    super.key,
    this.avatar,
    this.avatarUrl,
    this.reasonIcon = Icons.stop_rounded,
    this.followAction,
    this.crowned = false,
  });

  final String hostName;
  final ImageProvider? avatar;
  final String? avatarUrl;

  /// The localized end reason.
  final String reason;

  /// The end reason's badge on the host's picture.
  final IconData reasonIcon;
  final VoidCallback onBack;

  /// The follow button, only when the viewer may follow and does not yet.
  final Widget? followAction;

  /// D221: a crown before the host's name, only for a status the app
  /// really knows (none yet in production).
  final bool crowned;

  @override
  Widget build(BuildContext context) {
    const p = KPalette.dark;
    final l10n = context.l10n;
    final followAction = this.followAction;
    return ColoredBox(
      key: const Key('room.ended'),
      color: p.background.withValues(alpha: KMetrics.endedOverlayOpacity),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KSpacing.xl),
            child: KLiveInterruption(
              leading: KLiveHostPicture(
                image: avatar,
                imageUrl: avatarUrl,
                size: KLiveInterruption.picture,
              ),
              badgeIcon: reasonIcon,
              status: l10n.liveStatusEnded,
              eyebrow: hostName,
              crowned: crowned,
              title: l10n.liveRoomEndedTitle,
              message: reason,
              actions: [
                ?followAction,
                KLiveInterruptionButton(
                  key: const Key('room.back'),
                  label: l10n.liveRoomBackToLive,
                  icon: Icons.replay_rounded,
                  onPressed: onBack,
                  primary: followAction == null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A full-screen room message with the close button at the top end: not
/// found, failed to load, offline, removed (D216: the interruption card).
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
    this.status,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? detail;
  final VoidCallback onClose;
  final VoidCallback? onRetry;

  /// Kept for callers; the emblem is always on the brand ring (D216).
  final Color? iconColor;

  /// D221: the state in the card's red pill («غير متصل»).
  final String? status;

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
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(KSpacing.xl),
                    child: KLiveInterruption(
                      icon: icon,
                      status: status,
                      title: title,
                      message: message,
                      detail: detail,
                      actions: [
                        if (onRetry != null)
                          KLiveInterruptionButton(
                            label: l10n.actionRetry,
                            icon: Icons.refresh_rounded,
                            onPressed: onRetry,
                          ),
                        KLiveInterruptionButton(
                          label: l10n.liveRoomBackToLive,
                          icon: Icons.replay_rounded,
                          onPressed: onClose,
                          primary: onRetry == null,
                        ),
                      ],
                    ),
                  ),
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
    this.status,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? status;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(KSpacing.xl),
    child: KLiveInterruption(
      icon: icon,
      status: status,
      title: title,
      message: body,
    ),
  );
}
