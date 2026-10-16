import 'dart:async';

import 'package:intl/intl.dart' show Bidi;
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Live room layout (G-07, HOME_LIVE_LAYOUT_DECISIONS §3 HL-L1/L9),
/// **layout only**: every zone is a slot the caller fills, and an empty
/// slot draws nothing. Always dark.
///
/// Layers (bottom → top, HL-L1):
/// 0. [video] full-bleed under the status bar ([KLiveVideoPlaceholder]
///    when `null`);
/// 1. legibility gradients (top 120 dp, bottom 280 dp, VG-26);
/// 2. inside the safe area: the header row ([header] at the start,
///    [viewers] and close at the end), the optional [roomInfo] row, a
///    top-centre [statusChip], the PK / multi-guest [stage], the [chat]
///    (start side, capped at 30 % of the screen height) and the
///    [actionBar];
/// 3. [cover]: a full-screen room state above everything (ended);
/// 4. [overlay]: an in-tree sheet (goldens; real sheets are routes).
class KLiveRoomScaffold extends StatelessWidget {
  const new({
    required this.header,
    super.key,
    this.video,
    this.viewers,
    this.onClose,
    this.roomInfo,
    this.statusChip,
    this.stage,
    this.chat,
    this.actionBar,
    this.cover,
    this.overlay,
  });

  final Widget? video;
  final Widget header;
  final Widget? viewers;
  final VoidCallback? onClose;
  final Widget? roomInfo;
  final Widget? statusChip;

  /// PK split panes (`KPkLayout`) or multi-guest seats (`KGuestSeatGrid`).
  final Widget? stage;
  final Widget? chat;
  final Widget? actionBar;
  final Widget? cover;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final viewers = this.viewers;
    final roomInfo = this.roomInfo;
    final statusChip = this.statusChip;
    final stage = this.stage;
    final chat = this.chat;
    final actionBar = this.actionBar;
    final chatCap =
        MediaQuery.sizeOf(context).height * KMetrics.chatMaxHeightFactor;
    return KLiveSurface(
      child: Material(
        color: KPalette.dark.background,
        child: Stack(
          fit: StackFit.expand,
          children: [
            video ?? const KLiveVideoPlaceholder(),
            const _LegibilityGradients(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: header,
                          ),
                        ),
                        if (viewers != null) ...[
                          const SizedBox(width: KSpacing.xs),
                          viewers,
                        ],
                        KRoomIconButton(
                          icon: Icons.close,
                          label: l10n.liveClose,
                          onPressed: onClose,
                          visualSize: KMetrics.closeVisual,
                          iconSize: KMetrics.closeIcon,
                        ),
                      ],
                    ),
                    if (roomInfo != null)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: roomInfo,
                      ),
                    if (statusChip != null) ...[
                      const SizedBox(height: KSpacing.sm),
                      Center(child: statusChip),
                    ],
                    if (stage != null) ...[
                      const SizedBox(height: KSpacing.sm),
                      stage,
                    ],
                    const SizedBox(height: KSpacing.sm),
                    Expanded(
                      child: chat == null
                          ? const SizedBox.shrink()
                          : Align(
                              alignment: AlignmentDirectional.bottomStart,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxHeight: chatCap),
                                child: chat,
                              ),
                            ),
                    ),
                    if (actionBar != null) ...[
                      const SizedBox(height: KSpacing.sm),
                      actionBar,
                    ],
                  ],
                ),
              ),
            ),
            ?cover,
            ?overlay,
          ],
        ),
      ),
    );
  }
}

/// HL-L1 layer 1: black gradients under the overlays so white text stays
/// legible on bright video (VG-26). Decorative; never hit-tested.
class _LegibilityGradients extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: KMetrics.legibilityTopHeight + padding.top,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [KMetrics.legibilityTop, KMetrics.legibilityClear],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: KMetrics.legibilityBottomHeight + padding.bottom,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [KMetrics.legibilityBottom, KMetrics.legibilityClear],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The dark backdrop of the video layer when there is no video frame.
class KLiveVideoPlaceholder extends StatelessWidget {
  const new({super.key, this.child});

  /// Centred content (the honest "video unavailable" message, camera off).
  final Widget? child;

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
          child:
              child ??
              Icon(
                Icons.videocam_outlined,
                size: KSizes.avatarMd,
                color: p.textSecondary,
              ),
        ),
      ),
    );
  }
}

/// Host header (G-08, HL-L2): avatar, name, an optional second line (only
/// with API data) and the follow chip, on a 40 dp scrim pill.
///
/// Follow: a 28 dp `primary` "+ Follow" chip while [following] is false and
/// [onFollow] is set. When [following] turns true the chip shows a check for
/// `KMetrics.followConfirmDuration`, then fades out (instant with reduce
/// motion). If the follow is rolled back, the chip returns. With
/// [onFollow] `null` there is no follow control (state unknown, yourself,
/// or a private account).
class KHostPill extends StatefulWidget {
  const new({
    required this.hostName,
    super.key,
    this.avatar,
    this.subtitle,
    this.following = false,
    this.onFollow,
    this.onTap,
  });

  final String hostName;
  final ImageProvider? avatar;

  /// Second line (e.g. the follower count); `null` → one line.
  final String? subtitle;
  final bool following;
  final VoidCallback? onFollow;

  /// Opens the host's profile sheet; `null` → the pill is not a button.
  final VoidCallback? onTap;

  @override
  State<KHostPill> createState() => _KHostPillState();
}

class _KHostPillState extends State<KHostPill> {
  bool _confirming = false;
  Timer? _timer;

  @override
  void didUpdateWidget(KHostPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.following && widget.following) {
      _timer?.cancel();
      _confirming = true;
      _timer = Timer(KMetrics.followConfirmDuration, () {
        if (mounted) setState(() => _confirming = false);
      });
    } else if (!widget.following && _confirming) {
      _timer?.cancel();
      _confirming = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const p = KPalette.dark;
    final text = context.textStyles;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final subtitle = widget.subtitle;
    final onFollow = widget.onFollow;
    final Widget chip;
    if (!widget.following && onFollow != null) {
      chip = _FollowChip(
        key: const ValueKey('follow'),
        label: l10n.liveFollow,
        onTap: onFollow,
      );
    } else if (_confirming) {
      chip = _FollowChip(
        key: const ValueKey('followed'),
        label: l10n.liveFollowing,
        following: true,
      );
    } else {
      chip = const SizedBox.shrink(key: ValueKey('none'));
    }

    final body = Container(
      constraints: const BoxConstraints(minHeight: KMetrics.hostPillHeight),
      padding: const EdgeInsetsDirectional.only(
        start: KSpacing.xs,
        end: KSpacing.xs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KAvatar(
            name: widget.hostName,
            image: widget.avatar,
            size: KSizes.avatarSm,
          ),
          const SizedBox(width: KSpacing.sm),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.hostName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: scaler,
                  style: text.label.copyWith(color: p.textPrimary),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: scaler,
                    // White, not textSecondary: secondary grey on the scrim
                    // over a white frame is 4.2:1 (below 4.5).
                    style: text.caption.copyWith(color: p.textPrimary),
                  ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: KMotion.of(context, KMotion.base),
            child: chip,
          ),
          const SizedBox(width: KSpacing.xs),
        ],
      ),
    );

    final onTap = widget.onTap;
    final pill = Material(
      color: p.scrim,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );
    return Semantics(
      container: true,
      button: onTap != null,
      label: onTap != null ? l10n.liveRoomHostSemantics(widget.hostName) : null,
      // The visual pill is 40 dp; the hit area keeps 48 dp.
      child: onTap == null
          ? pill
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: KSizes.minTouchTarget,
                ),
                child: Center(heightFactor: 1, widthFactor: 1, child: pill),
              ),
            ),
    );
  }
}

/// 28 dp follow chip inside a 48 dp hit area.
class _FollowChip extends StatelessWidget {
  const new({
    required this.label,
    super.key,
    this.onTap,
    this.following = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool following;

  @override
  Widget build(BuildContext context) {
    const p = KPalette.dark;
    final visual = Container(
      height: KMetrics.followChipHeight,
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: following ? KSpacing.xs : KSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: p.primary,
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            following ? Icons.check_rounded : Icons.add_rounded,
            size: KMetrics.iconSm,
            color: p.onPrimary,
          ),
          if (!following) ...[
            const SizedBox(width: KSpacing.xxs),
            Text(
              label,
              textScaler: TextScaler.noScaling,
              style: context.textStyles.label.copyWith(color: p.onPrimary),
            ),
          ],
        ],
      ),
    );
    return Semantics(
      container: true,
      button: onTap != null,
      toggled: following,
      label: label,
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: onTap,
          radius: KSizes.minTouchTarget / 2,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: KSizes.minTouchTarget,
              minWidth: KSizes.minTouchTarget,
            ),
            child: Center(widthFactor: 1, child: visual),
          ),
        ),
      ),
    );
  }
}

/// Loading stand-in for [KHostPill].
class KHostPillSkeleton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: KMetrics.hostPillHeight,
    padding: const EdgeInsetsDirectional.symmetric(horizontal: KSpacing.xs),
    decoration: BoxDecoration(
      color: KPalette.dark.scrim,
      borderRadius: BorderRadius.circular(KRadius.pill),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KSkeleton(height: KSizes.avatarSm, circle: true),
        SizedBox(width: KSpacing.sm),
        KSkeleton(width: KSpacing.xxxl * 2, height: KSpacing.md),
        SizedBox(width: KSpacing.md),
      ],
    ),
  );
}

/// HL-L4 room info row: the room title and its category, as 28 dp scrim
/// chips under the host pill. Each text is laid out in its own script
/// direction (an Arabic title in an English UI and the reverse).
class KRoomInfoRow extends StatelessWidget {
  const new({required this.title, super.key, this.category});

  final String title;
  final String? category;

  @override
  Widget build(BuildContext context) {
    final category = this.category;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: KSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: _InfoChip(text: title)),
          if (category != null && category.isNotEmpty) ...[
            const SizedBox(width: KSpacing.xs),
            Flexible(
              child: Semantics(
                label: context.l10n.liveRoomCategory(category),
                child: ExcludeSemantics(
                  child: _InfoChip(text: category, icon: Icons.tag_rounded),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const new({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    const p = KPalette.dark;
    final icon = this.icon;
    return Container(
      constraints: const BoxConstraints(minHeight: KMetrics.roomInfoChipHeight),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: KSpacing.sm),
      decoration: BoxDecoration(
        color: p.scrim,
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            ExcludeSemantics(
              child: Icon(icon, size: KMetrics.iconXs, color: p.textPrimary),
            ),
            const SizedBox(width: KSpacing.xxs),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: Bidi.detectRtlDirectionality(text)
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              textScaler: MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
              style: context.textStyles.caption.copyWith(
                color: p.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Viewer strip (HL-L3): up to `KMetrics.viewerStripMax` overlapping
/// avatars and the viewer count chip, **only from real data**: no names
/// means no avatars, and a count below 1 shows nothing (never a made-up
/// count). On screens narrower than `KMetrics.viewerAvatarsMinScreenWidth`
/// only the chip is shown, so the host name keeps its room (QA-009).
class KViewerStrip extends StatelessWidget {
  const new({required this.count, super.key, this.names = const []});

  final List<String> names;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count < 1) return const SizedBox.shrink();
    final compact =
        MediaQuery.sizeOf(context).width < KMetrics.viewerAvatarsMinScreenWidth;
    if (compact || names.isEmpty) return KViewerCountChip(count: count);
    final shown = names.take(KMetrics.viewerStripMax).toList();
    const step = KSizes.avatarSm - KSpacing.md;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            width: KSizes.avatarSm + step * (shown.length - 1),
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

/// Bottom action bar (G-13, HL-L7): the comment pill at the start, share
/// and the gold gift button at the end. **No decorative controls**: a
/// control whose callback is `null` is not shown (VG-31).
class KRoomActionBar extends StatelessWidget {
  const new({super.key, this.onComment, this.onShare, this.onGift});

  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onGift;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const p = KPalette.dark;
    final onComment = this.onComment;
    final onShare = this.onShare;
    final onGift = this.onGift;
    return Row(
      children: [
        if (onComment != null)
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
                        textScaler: MediaQuery.textScalerOf(
                          context,
                        ).clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
                        style: context.textStyles.body.copyWith(
                          color: p.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        else
          const Spacer(),
        if (onShare != null) ...[
          const SizedBox(width: KSpacing.xs),
          KRoomIconButton(
            icon: Icons.share_outlined,
            label: l10n.liveShare,
            onPressed: onShare,
          ),
        ],
        if (onGift != null) ...[
          const SizedBox(width: KSpacing.xs),
          KRoomIconButton(
            icon: Icons.card_giftcard,
            label: l10n.liveGifts,
            onPressed: onGift,
            color: KBrandColors.gold,
          ),
        ],
      ],
    );
  }
}

/// Round icon button on `scrim` for use over video: a [visualSize] circle
/// (40 dp by default) inside a 48 dp hit area.
class KRoomIconButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    super.key,
    this.onPressed,
    this.color,
    this.visualSize = KMetrics.roomIconVisual,
    this.iconSize = KMetrics.iconMd,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final double visualSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    enabled: onPressed != null,
    label: label,
    child: ExcludeSemantics(
      child: SizedBox.square(
        dimension: KSizes.minTouchTarget,
        child: Material(
          type: MaterialType.transparency,
          child: InkResponse(
            onTap: onPressed,
            radius: KSizes.minTouchTarget / 2,
            child: Center(
              child: Container(
                width: visualSize,
                height: visualSize,
                decoration: BoxDecoration(
                  color: KPalette.dark.scrim,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: iconSize,
                  color: color ?? KPalette.dark.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
