import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_side_cards.dart';
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
    this.trailing,
    this.sideStart,
    this.sidePromo,
    this.closeButtonKey = closeKey,
    this.closeLabel,
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

  /// D131 (host): a button between [viewers] and ✕ (minimize).
  final Widget? trailing;

  /// D136: the wish list card, floating at the reading start (left middle).
  final Widget? sideStart;

  /// D137/D141: the promo box, in the same column right above the wish
  /// list.
  final Widget? sidePromo;

  /// ✕'s key and spoken label (the host's ✕ ends the live).
  final Key closeButtonKey;
  final String? closeLabel;

  static const closeKey = Key('room.close');

  /// The header row's top for a top inset of [inset]. D135 (owner: "leave
  /// the phone's status bar free"); D141 (owner: "the top bar must sit
  /// lower"): the visible pill starts [KMetrics.liveHeaderGap] under the
  /// inset — the same gap as the audio room's card — and the 48 pt row
  /// centres it, so the row starts half the difference higher.
  static double headerTop(double inset) => math.max(
    0,
    inset +
        KMetrics.liveHeaderGap -
        (KSizes.minTouchTarget - KMetrics.hostPillHeight) / 2,
  );

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
    // D141 (owner: "the keyboard covers the chat box"): the room's column
    // ends on the keyboard (the live screens do not resize); a screen that
    // resizes has already taken the keyboard out of the media query.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final inset = MediaQuery.paddingOf(context).top;
    return KLiveSurface(
      child: Material(
        color: KPalette.dark.background,
        child: Stack(
          fit: StackFit.expand,
          children: [
            video ?? const KLiveVideoPlaceholder(),
            const _LegibilityGradients(),
            SafeArea(
              top: false,
              // Over the keyboard the bar sits right on it.
              bottom: keyboard == 0,
              child: Padding(
                // D135: the header row below the status bar ([headerTop]),
                // the bar on the bottom safe edge (above the home
                // indicator or the navigation bar) or on the keyboard.
                padding: EdgeInsetsDirectional.only(
                  start: KSpacing.sm,
                  top: headerTop(inset),
                  bottom: keyboard,
                ),
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
                        // Ref 158: a bare ✕ (10.6 pt ink); its centre 24 pt
                        // from the end (ref 18.3) to keep a 48 pt target.
                        ?trailing,
                        KRoomIconButton(
                          key: closeButtonKey,
                          icon: Icons.close,
                          label: closeLabel ?? l10n.liveClose,
                          onPressed: onClose,
                          iconSize: 19,
                          bare: true,
                        ),
                      ],
                    ),
                    if (roomInfo != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: KSpacing.sm,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: roomInfo,
                        ),
                      ),
                    if (statusChip != null) ...[
                      const SizedBox(height: KSpacing.sm),
                      Center(child: statusChip),
                    ],
                    if (stage != null) ...[
                      const SizedBox(height: KSpacing.sm),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: KSpacing.sm,
                        ),
                        child: stage,
                      ),
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
                      // Ref 158: the last circle 7.2 pt from the end (its
                      // 48 pt target reaches 0.6 pt further).
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 0.6),
                        child: actionBar,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // D136/D137/D141: one column at the reading start — the promo
            // box right above the wish note (the promo grows upwards from
            // the note's top, so the note never moves). While the keyboard
            // is up the room is short: they step aside for the chat.
            if (sideStart case final side? when keyboard == 0)
              PositionedDirectional(
                start: KLiveSideCards.wishStart,
                top: inset + KLiveSideCards.wishTop,
                child: side,
              ),
            if (sidePromo case final side? when keyboard == 0)
              PositionedDirectional(
                start: KLiveSideCards.promoStart,
                top: inset + KLiveSideCards.promoTop,
                child: side,
              ),
            ?cover,
            ?overlay,
          ],
        ),
      ),
    );
  }
}

/// D141 (owner: "show the host's username, not the room number"): the
/// host's `@username` beside their name (the video pill) or under the room
/// title (the audio room card); a tap copies it and says «تم النسخ». The
/// room number stays in the API (share links, support) — it is just not
/// shown here any more.
class KLiveUsernameTag extends StatelessWidget {
  const new({required this.username, super.key, this.fontSize = 10});

  final String username;
  final double fontSize;

  static const tagKey = Key('live.usernameTag');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shown = '@$username';
    return Semantics(
      button: true,
      label: '$shown. ${l10n.liveRoomIdCopyHint}',
      excludeSemantics: true,
      child: GestureDetector(
        key: tagKey,
        behavior: HitTestBehavior.opaque,
        onTap: () {
          unawaited(Clipboard.setData(ClipboardData(text: shown)));
          KSnack.info(context, l10n.liveUsernameCopied);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  KFormat.bidiIsolate(shown),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.caption.copyWith(
                    fontSize: fontSize,
                    height: 1.2,
                    color: const Color(0xD9FFFFFF),
                    fontWeight: FontWeight.w600,
                    shadows: KLiveColors.glassShadow,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                Icons.copy_rounded,
                size: fontSize,
                color: const Color(0xD9FFFFFF),
              ),
            ],
          ),
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

/// Host header (G-08, HL-L2; D131 measured on ref 158): a 31 pt stadium on
/// the scrim with the host's 26.6 pt picture, the name (11 sp bold) and a
/// second line, and at the end the follow capsule.
///
/// Second line: [lines] take turns every [lineTime] with a fade (the first
/// stays with reduce motion); else [subtitle]; else one line.
///
/// Follow: a 31.5 × 23.8 pt cyan capsule with a white "+" (announced
/// "Follow") while [following] is false and [onFollow] is set. When
/// [following] turns true it shows a check for
/// `KMetrics.followConfirmDuration`, then fades out (instant with reduce
/// motion). If the follow is rolled back, the capsule returns. With
/// [onFollow] `null` there is no follow control (state unknown, yourself,
/// or a private account).
class KHostPill extends StatefulWidget {
  const new({
    required this.hostName,
    super.key,
    this.avatar,
    this.subtitle,
    this.lines = const [],
    this.following = false,
    this.onFollow,
    this.onTap,
    this.username,
  });

  /// D141 (owner, replaces D135's room ID): the host's `@username` beside
  /// the name; a tap copies it ([KLiveUsernameTag]).
  final String? username;

  /// The visible stadium (D141: its top is [KMetrics.liveHeaderGap] under
  /// the status bar in every room).
  static const pillKey = Key('hostPill.pill');

  final String hostName;
  final ImageProvider? avatar;

  /// Second line (e.g. the follower count); `null` → one line.
  final String? subtitle;

  /// D131: second lines shown in turn (e.g. this live's points, then its
  /// taps); they win over [subtitle].
  final List<Widget> lines;
  final bool following;
  final VoidCallback? onFollow;

  /// Opens the host's profile sheet; `null` → the pill is not a button.
  final VoidCallback? onTap;

  /// How long each of [lines] shows.
  static const lineTime = Duration(seconds: 3);

  /// Ref 158: the follow capsule's gradient (`#23E1DA` → `#0BD6E1`).
  static const followGradient = [Color(0xFF23E1DA), Color(0xFF0BD6E1)];

  /// Ref 158: the points line's yellow.
  static const points = Color(0xFFF5C542);

  /// D141: 30 pt (ref 158's 26.6 pt, enlarged with the pill).
  static const avatarSize = 30.0;
  static const lineKey = Key('hostPill.line');

  @override
  State<KHostPill> createState() => _KHostPillState();
}

class _KHostPillState extends State<KHostPill> {
  bool _confirming = false;
  Timer? _timer;
  Timer? _lines;
  int _line = 0;

  @override
  void initState() {
    super.initState();
    _syncLines();
  }

  void _syncLines() {
    if (widget.lines.length < 2) {
      _lines?.cancel();
      _lines = null;
      _line = 0;
      return;
    }
    _lines ??= Timer.periodic(KHostPill.lineTime, (_) {
      if (!mounted) return;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
      setState(() => _line = (_line + 1) % widget.lines.length);
    });
  }

  @override
  void didUpdateWidget(KHostPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncLines();
    if (_line >= widget.lines.length) _line = 0;
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
    _lines?.cancel();
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
    final hasChip = !widget.following && onFollow != null || _confirming;
    final lines = widget.lines;
    final second = lines.isNotEmpty
        ? AnimatedSwitcher(
            duration: KMotion.of(context, KMotion.base),
            layoutBuilder: (current, previous) => Stack(
              alignment: AlignmentDirectional.centerStart,
              children: [...previous, ?current],
            ),
            child: KeyedSubtree(
              key: ValueKey(_line),
              child: lines[_line.clamp(0, lines.length - 1)],
            ),
          )
        : subtitle == null
        ? null
        : Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textScaler: scaler,
            // White, not textSecondary: secondary grey on the scrim over a
            // white frame is 4.2:1 (below 4.5).
            style: text.caption.copyWith(
              color: p.textPrimary,
              fontSize: 10,
              height: 1.2,
            ),
          );

    final body = Container(
      constraints: const BoxConstraints(minHeight: KMetrics.hostPillHeight),
      padding: const EdgeInsetsDirectional.only(start: 2.2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KAvatar(
            name: widget.hostName,
            image: widget.avatar,
            size: KHostPill.avatarSize,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: scaler),
              child: DefaultTextStyle.merge(
                style: text.caption.copyWith(
                  color: p.textPrimary,
                  fontSize: 10,
                  height: 1.2,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          flex: 3,
                          child: Text(
                            widget.hostName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.label.copyWith(
                              color: p.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                              shadows: KLiveColors.glassShadow,
                            ),
                          ),
                        ),
                        if (widget.username case final name?) ...[
                          const SizedBox(width: 5),
                          // The name keeps most of the room when it is
                          // short (a narrow phone, large text).
                          Flexible(
                            flex: 2,
                            child: KLiveUsernameTag(username: name),
                          ),
                        ],
                      ],
                    ),
                    if (second != null)
                      KeyedSubtree(key: KHostPill.lineKey, child: second),
                  ],
                ),
              ),
            ),
          ),
          // The capsule's room; the capsule and its 48 pt target are laid
          // over it (below), so the pill stays 31 pt tall.
          SizedBox(
            width: hasChip
                ? KSpacing.xs + KMetrics.followChipWidth + 5.3
                : KSpacing.md,
          ),
        ],
      ),
    );

    final onTap = widget.onTap;
    final pill = Material(
      key: KHostPill.pillKey,
      // D135: the lighter glass.
      color: KLiveColors.glass,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );
    final host = Semantics(
      container: true,
      button: onTap != null,
      label: onTap != null ? l10n.liveRoomHostSemantics(widget.hostName) : null,
      // The visual pill is 31 dp; the hit area keeps 48 dp.
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
    // The follow capsule over the pill's end, in a 48 × 48 pt target.
    return Stack(
      alignment: AlignmentDirectional.centerEnd,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: KSizes.minTouchTarget),
          child: Center(heightFactor: 1, widthFactor: 1, child: host),
        ),
        PositionedDirectional(
          end: 5.3 + KMetrics.followChipWidth / 2 - KSizes.minTouchTarget / 2,
          child: AnimatedSwitcher(
            duration: KMotion.of(context, KMotion.base),
            child: chip,
          ),
        ),
      ],
    );
  }
}

/// The follow capsule (ref 158: 31.5 × 23.8 pt, cyan, a white "+", 5.3 pt
/// from the pill's end) inside a 48 dp hit area that overflows the pill.
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
      width: KMetrics.followChipWidth,
      height: KMetrics.followChipHeight,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: KHostPill.followGradient),
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Icon(
        following ? Icons.check_rounded : Icons.add_rounded,
        size: 16,
        color: p.onPrimary,
      ),
    );
    return Semantics(
      container: true,
      button: onTap != null,
      toggled: following,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox.square(
            dimension: KSizes.minTouchTarget,
            child: Center(child: visual),
          ),
        ),
      ),
    );
  }
}

/// A host pill line: an icon and a count (D131: this live's points with
/// the cherry, or its taps with a heart).
class KHostPillLine extends StatelessWidget {
  const new({required this.icon, required this.text, super.key, this.color});

  final Widget icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      icon,
      const SizedBox(width: 2),
      Flexible(
        child: Text(
          KFormat.bidiIsolate(text),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color ?? KHostPill.points,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ),
    ],
  );
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
  const new({required this.title, super.key, this.category, this.level});

  final String title;
  final String? category;

  /// CP-016 D (D101): the room level (the host's charm level) after the
  /// title; none while the charm levels are unavailable.
  final int? level;

  @override
  Widget build(BuildContext context) {
    final category = this.category;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: KSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: _InfoChip(text: title)),
          if (level case final level?) ...[
            const SizedBox(width: KSpacing.xs),
            CharmLevelBadge(level: level, height: 16),
          ],
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
    this.bare = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final double visualSize;
  final double iconSize;

  /// D131: the icon alone (a soft shadow, no circle), e.g. the room's ✕.
  final bool bare;

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
                decoration: bare
                    ? null
                    : BoxDecoration(
                        color: KPalette.dark.scrim,
                        shape: BoxShape.circle,
                      ),
                child: Icon(
                  icon,
                  size: iconSize,
                  color: color ?? KPalette.dark.textPrimary,
                  shadows: bare
                      ? const [Shadow(color: Color(0x66000000), blurRadius: 3)]
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
