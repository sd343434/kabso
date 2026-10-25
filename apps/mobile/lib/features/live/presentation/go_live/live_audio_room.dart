import 'dart:async';

import 'package:clock/clock.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The audio room on air, laid out after the owner's screen recording (D94;
/// measured on a 384 pt wide frame, kept in scratch): the room bar and the
/// chips at the top, rows of five round seats, the chat bubbles low on the
/// start side, and small round buttons at the bottom — over a purple
/// gradient. Kabso's own icons; nothing of the recorded product's branding.
abstract final class KAudioRoom {
  /// Sampled down the recording's edge (stops are y / height).
  static const backgroundColors = [
    Color(0xFF8B50C5),
    Color(0xFF7E4FC3),
    Color(0xFF5B4AB2),
    Color(0xFF4F4BAB),
    Color(0xFF2B397D),
    Color(0xFF2E2771),
  ];
  static const backgroundStops = [0.07, 0.17, 0.39, 0.45, 0.71, 0.94];

  /// The room bar, the chips and the top buttons.
  static const glass = Color(0x732A1450);

  /// Chat bubbles.
  static const bubble = Color(0xB3222260);

  /// The bottom buttons.
  static const button = Color(0xFF26226A);

  /// Empty seats: white over the purple (#8C6CCF measured).
  static const emptySeat = Color(0x38FFFFFF);
  static const hostTag = Color(0xFF2FE0C5);
  static const text = Color(0xFFFFFFFF);
  static const textSoft = Color(0xD9FFFFFF);
  static const badge = Color(0xFFFF3B5C);
}

/// The recording's purple gradient (the classic theme of an audio room).
class LiveAudioRoomBackground extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: KAudioRoom.backgroundColors,
        stops: KAudioRoom.backgroundStops,
      ),
    ),
    child: SizedBox.expand(),
  );
}

class LiveAudioRoomLayout extends StatelessWidget {
  const new({
    required this.header,
    required this.stage,
    required this.barStart,
    required this.barEnd,
    super.key,
    this.chips,
    this.chat = const [],
    this.composer,
    this.barLead,
  });

  /// Fills the bar's start before [barStart] (the "Say something" pill).
  final Widget? barLead;

  /// The chat box, in place of the buttons while writing (above the
  /// keyboard).
  final Widget? composer;

  final Widget header;

  /// The chips row under the room bar.
  final Widget? chips;
  final Widget stage;

  /// Chat bubbles, oldest first, low on the screen.
  final List<Widget> chat;
  final List<Widget> barStart;
  final List<Widget> barEnd;

  @override
  Widget build(BuildContext context) {
    final chips = this.chips;
    final composer = this.composer;
    return Padding(
      // The keyboard pushes the room up (the screen does not resize).
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        // The chat box runs to the bottom edge, under the home indicator.
        bottom: composer == null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: header,
            ),
            if (chips != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                child: chips,
              ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(4, 30, 4, 16),
                    sliver: SliverToBoxAdapter(child: stage),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Align(
                      alignment: AlignmentDirectional.bottomStart,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final line in chat)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: line,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              // The chat box is a panel across the whole width.
              padding: composer == null
                  ? const EdgeInsets.fromLTRB(4, 2, 4, 4)
                  : EdgeInsets.zero,
              child: composer != null
                  ? ColoredBox(
                      color: LiveChatComposer.panel,
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.paddingOf(context).bottom,
                        ),
                        child: composer,
                      ),
                    )
                  : Row(
                      children: [
                        if (barLead case final lead?) ...[
                          Expanded(child: lead),
                          const SizedBox(width: 4),
                        ],
                        ...barStart,
                        if (barLead == null) const Spacer(),
                        ...barEnd,
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The chat box (owner's reference): a white panel across the bottom with
/// a light rounded field, the send arrow, and a row of quick emoji that go
/// into the field. System emoji only (no third-party stickers).
class LiveChatComposer extends StatefulWidget {
  const new({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.sendLabel,
    required this.onSend,
    required this.onEmoji,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final String sendLabel;
  final VoidCallback onSend;

  /// A Kabi emoji tapped in the row: sent at once as its own message (D66).
  final ValueChanged<KabiEmojis> onEmoji;

  static const fieldKey = Key('liveChat.field');
  static const sendKey = Key('liveChat.send');
  static Key emojiKey(KabiEmojis emoji) => Key('liveChat.emoji.${emoji.id}');

  /// The Kabi row (owner's emojis, D66), measured on the owner's reference:
  /// Kabi 27 pt tall (the Lottie canvas is 35 pt), one every 61.1 pt, the
  /// first centred 32.1 pt from the edge; the rest scroll.
  static const emojiSize = 35.0;
  static const emojiPitch = 61.1;

  /// The panel's colours.
  // Measured on the owner's reference (430 pt wide).
  static const panel = Color(0xFFFFFFFF);
  static const field = Color(0xFFF4F6FA);
  static const ink = Color(0xFF1C1B2E);
  static const hintInk = Color(0xFFC6C7CB);
  static const sendOn = Color(0xFF6C4CF1);
  static const sendOff = Color(0xFFE0E2E4);

  @override
  State<LiveChatComposer> createState() => _LiveChatComposerState();
}

class _LiveChatComposerState extends State<LiveChatComposer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    final hasText = widget.controller.text.trim().isNotEmpty;
    return Container(
      decoration: const BoxDecoration(
        color: LiveChatComposer.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 1.4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(width: 12.6),
              Expanded(
                child: Container(
                  height: 41,
                  padding: const EdgeInsetsDirectional.only(
                    start: 21.9,
                    end: 16,
                  ),
                  decoration: BoxDecoration(
                    color: LiveChatComposer.field,
                    borderRadius: BorderRadius.circular(20.5),
                  ),
                  alignment: Alignment.center,
                  child: TextField(
                    key: LiveChatComposer.fieldKey,
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    maxLength: 200,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => widget.onSend(),
                    cursorColor: LiveChatComposer.sendOn,
                    style: text.body.copyWith(color: LiveChatComposer.ink),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      counterText: '',
                      hintText: widget.hint,
                      hintStyle: text.body.copyWith(
                        color: LiveChatComposer.hintInk,
                      ),
                    ),
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: widget.sendLabel,
                onTap: widget.onSend,
                excludeSemantics: true,
                child: Tooltip(
                  message: widget.sendLabel,
                  child: GestureDetector(
                    key: LiveChatComposer.sendKey,
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onSend,
                    child: SizedBox(
                      width: 46.6,
                      height: 44,
                      child: Icon(
                        Icons.send_rounded,
                        size: 24,
                        // Points along the reading direction.
                        textDirection: Directionality.of(context),
                        color: hasText
                            ? LiveChatComposer.sendOn
                            : LiveChatComposer.sendOff,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5.1),
          SizedBox(
            height: LiveChatComposer.emojiSize,
            child: ListView(
              scrollDirection: Axis.horizontal,
              itemExtent: LiveChatComposer.emojiPitch,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 1.55),
              children: [
                for (final emoji in KabiEmojis.values)
                  Semantics(
                    button: true,
                    label: emoji.label(context.l10n),
                    onTap: () => widget.onEmoji(emoji),
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: LiveChatComposer.emojiKey(emoji),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onEmoji(emoji),
                      // Still, like the picker (less motion, less work).
                      child: Center(
                        child: KabiEmoji(
                          emoji,
                          size: LiveChatComposer.emojiSize,
                          animate: false,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The room bar: the cover, the title and a second line; then the round
/// minimize and ✕ (end) buttons.
class LiveAudioRoomHeader extends StatelessWidget {
  const new({
    required this.cover,
    required this.title,
    required this.minimizeTooltip,
    required this.onMinimize,
    required this.endTooltip,
    required this.onEnd,
    super.key,
    this.subtitle,
    this.minimizeKey,
    this.endKey,
    this.onShare,
    this.shareTooltip,
    this.shareKey,
    this.scoreText,
    this.scoreLabel,
    this.onTap,
    this.onScoreTap,
    this.action,
    this.showMinimize = true,
  });

  /// Opens the score's breakdown from the points (when [onTap] opens
  /// something else, e.g. the host's room info, ref 73).
  final VoidCallback? onScoreTap;

  /// At the end of the room bar (a viewer's Follow).
  final Widget? action;

  /// Viewers have no floating window.
  final bool showMinimize;

  /// CP-012: the live's points, shortened (12.4K); shown with a flame in
  /// place of [subtitle] once there are points.
  final String? scoreText;

  /// [scoreText] for screen readers.
  final String? scoreLabel;

  /// Opens the score's breakdown.
  final VoidCallback? onTap;

  final VoidCallback? onShare;
  final String? shareTooltip;
  final Key? shareKey;

  static const scoreKey = Key('liveRoom.score');
  static const barKey = Key('liveRoom.bar');

  final Widget cover;
  final String title;
  final String? subtitle;
  final String minimizeTooltip;
  final VoidCallback? onMinimize;
  final String endTooltip;
  final VoidCallback? onEnd;
  final Key? minimizeKey;
  final Key? endKey;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    final subtitle = this.subtitle;
    return Row(
      children: [
        // The room bar hugs its title, at most 220 pt (owner D94).
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: GestureDetector(
                key: barKey,
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 38,
                  padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 12, 4),
                  decoration: BoxDecoration(
                    color: KAudioRoom.glass,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: SizedBox.square(dimension: 30, child: cover),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.caption.copyWith(
                                fontSize: 13,
                                height: 1.15,
                                color: KAudioRoom.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (scoreText case final points?)
                              Semantics(
                                label: scoreLabel,
                                button: onScoreTap != null,
                                onTap: onScoreTap,
                                excludeSemantics: true,
                                child: GestureDetector(
                                  onTap: onScoreTap,
                                  behavior: HitTestBehavior.opaque,
                                  child: Row(
                                    key: LiveAudioRoomHeader.scoreKey,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const KPointsIcon(),
                                      const SizedBox(width: 2),
                                      Text(
                                        points,
                                        style: text.caption.copyWith(
                                          fontSize: 10.5,
                                          height: 1.15,
                                          color: KAudioRoom.text,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else if (subtitle != null && subtitle.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.verified_user_rounded,
                                    size: 10,
                                    color: KAudioRoom.hostTag,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textDirection: TextDirection.ltr,
                                      style: text.caption.copyWith(
                                        fontSize: 10,
                                        height: 1.15,
                                        color: KAudioRoom.textSoft,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      if (action case final action?) ...[
                        const SizedBox(width: 8),
                        action,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // The owner's outline icons, close together (D94).
        if (onShare != null)
          _TopIcon(
            key: shareKey,
            asset: 'assets/live_room_icons/share.png',
            label: shareTooltip ?? '',
            onTap: onShare,
          ),
        if (showMinimize)
          _TopIcon(
            key: minimizeKey,
            asset: 'assets/live_room_icons/minimize.png',
            label: minimizeTooltip,
            onTap: onMinimize,
          ),
        _TopIcon(
          key: endKey,
          asset: 'assets/live_room_icons/close.png',
          label: endTooltip,
          onTap: onEnd,
        ),
      ],
    );
  }
}

/// A small chip of the row under the room bar.
class LiveChip extends StatelessWidget {
  const new({required this.child, super.key, this.icon});

  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Container(
      constraints: const BoxConstraints(minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: KAudioRoom.glass,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: const Color(0xFFFFC547)),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: DefaultTextStyle.merge(
              style: context.textStyles.caption.copyWith(
                fontSize: 10.5,
                height: 1,
                color: KAudioRoom.text,
                fontWeight: FontWeight.w600,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// A chat bubble (system notes until the room chat exists).
class LiveRoomBubble extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 282),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: KAudioRoom.bubble,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: context.textStyles.caption.copyWith(
          fontSize: 12.5,
          color: KAudioRoom.text,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

/// A small round icon button (the bottom bar, the top buttons) inside a
/// 44 pt target; the label is for screen readers and the tooltip.
class LiveRoundButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
    this.size = 42,
    this.iconSize = 25,
    this.color = KAudioRoom.button,
    this.iconColor = KAudioRoom.text,
    this.badge = 0,
    this.gradient,
    this.asset,
    this.tintAsset = false,
  });

  /// A picture icon (`assets/live_room_icons/`) instead of [icon].
  final String? asset;

  /// Draws [asset] in [iconColor] (a one-colour icon).
  final bool tintAsset;

  /// Paints the icon with this gradient (the bar's coloured icons).
  final List<Color>? gradient;

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color color;
  final Color iconColor;

  /// A red count at the top corner.
  final int badge;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: size < 40 ? 44 : size + 2,
          child: Center(
            child: Badge(
              isLabelVisible: badge > 0,
              backgroundColor: KAudioRoom.badge,
              label: Text(badge > 99 ? '99+' : badge.toString()),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(
                    color: const Color(0x2EFFFFFF),
                    width: size < 40 ? 1 : 1.4,
                  ),
                  // Coloured buttons glow in their colour; the rest lift.
                  boxShadow: [
                    BoxShadow(
                      color: gradient != null && onTap != null
                          ? gradient!.first.withValues(alpha: 0.45)
                          : const Color(0x59000000),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _icon(),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _icon() {
    final asset = this.asset;
    if (asset != null) {
      return Padding(
        padding: EdgeInsets.all((size - iconSize - 4) / 2),
        child: Opacity(
          opacity: onTap == null ? 0.45 : 1,
          child: Image.asset(asset, color: tintAsset ? iconColor : null),
        ),
      );
    }
    final icon = Icon(
      this.icon,
      size: iconSize,
      color: onTap == null ? iconColor.withValues(alpha: 0.45) : iconColor,
    );
    final gradient = this.gradient;
    if (gradient == null || onTap == null) return icon;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradient,
      ).createShader(rect),
      child: icon,
    );
  }
}

/// The bar's "Say something…" pill: tapping it opens the chat box.
class LiveChatPill extends StatelessWidget {
  const new({required this.hint, required this.onTap, super.key});

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: hint,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 4),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: KAudioRoom.button,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: const Color(0x2EFFFFFF), width: 1.4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x59000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Image.asset(
                'assets/live_room_icons/chat.png',
                width: 20,
                height: 20,
                color: KAudioRoom.text,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.body.copyWith(
                    color: KAudioRoom.textSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Who is watching: up to three overlapping avatars and the count in a
/// circle (the room bar's second row, at the end).
class LiveViewersStack extends StatelessWidget {
  const new({
    required this.avatars,
    required this.count,
    required this.label,
    super.key,
    this.onTap,
  });

  final List<Widget> avatars;
  final String count;

  /// For screen readers ("12 watching").
  final String label;
  final VoidCallback? onTap;

  static const size = 24.0;

  @override
  Widget build(BuildContext context) {
    final shown = avatars.take(3).toList();
    return Semantics(
      button: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (shown.isNotEmpty)
              SizedBox(
                width: size + (shown.length - 1) * (size - 7),
                height: size,
                child: Stack(
                  children: [
                    for (var i = 0; i < shown.length; i++)
                      PositionedDirectional(
                        start: i * (size - 7),
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0x99FFFFFF)),
                          ),
                          child: ClipOval(child: shown[i]),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(width: 4),
            Container(
              constraints: const BoxConstraints(minWidth: size),
              height: size,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: KAudioRoom.glass,
                borderRadius: BorderRadius.circular(size / 2),
              ),
              child: Text(
                count,
                style: context.textStyles.caption.copyWith(
                  fontSize: 10.5,
                  height: 1,
                  color: KAudioRoom.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A top-bar icon drawn white: the picture alone (it has its own frame),
/// 20 pt in a 30 × 44 pt target so the three sit close together.
class _TopIcon extends StatelessWidget {
  const new({
    required this.asset,
    required this.label,
    required this.onTap,
    super.key,
  });

  final String asset;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 30,
          height: 44,
          child: Center(
            child: Opacity(
              opacity: onTap == null ? 0.45 : 1,
              child: Image.asset(
                asset,
                width: 20,
                height: 20,
                color: KAudioRoom.text,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// `m:ss`, or `h:mm:ss` from an hour.
String formatLiveDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// The compact LIVE · time chip (host and viewers); it ticks every second.
class LiveClockChip extends StatefulWidget {
  const new({required this.since, super.key, this.semanticsKey});

  final DateTime? since;
  final Key? semanticsKey;

  @override
  State<LiveClockChip> createState() => _LiveClockChipState();
}

class _LiveClockChipState extends State<LiveClockChip> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final since = widget.since;
    final elapsed = formatLiveDuration(
      since == null ? Duration.zero : clock.now().difference(since),
    );
    return Semantics(
      key: widget.semanticsKey,
      label: l10n.goLiveElapsed(elapsed),
      excludeSemantics: true,
      child: LiveChip(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: KAudioRoom.badge,
              ),
            ),
            const SizedBox(width: 4),
            Text(l10n.liveBadge),
            const SizedBox(width: 5),
            Text(
              elapsed,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
