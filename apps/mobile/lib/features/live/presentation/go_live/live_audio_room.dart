import 'dart:async';

import 'package:clock/clock.dart';
import 'package:kabso_live/core/emoji/unicode_emoji.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/emoji/emoji_panel.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart'
    show KLiveUsernameTag;
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

  /// Owner ref 83 (430 pt, black over the room): the room bar 33 %, the
  /// round top buttons 35 %, the chips 45 %.
  static const bar = Color(0x54000000);
  static const topButton = Color(0x55000000);

  /// D135: the lighter live glass (was 45 % black).
  static const Color chip = KLiveColors.glass;

  /// Chat bubbles.
  static const bubble = Color(0xB3222260);

  /// The chat pill (and the bottom buttons before ref 83).
  static const button = Color(0xFF26226A);

  /// The audio room's round bottom buttons: white 15 % over the room
  /// (owner ref 83).
  static const roundButton = Color(0x26FFFFFF);

  /// Empty seats: white over the purple (#8C6CCF measured).
  static const emptySeat = Color(0x38FFFFFF);

  /// Ref 83's empty seat: a chair in white 18 % over the room.
  static const chair = Color(0x2EFFFFFF);
  static const hostTag = Color(0xFF2FE0C5);
  static const text = Color(0xFFFFFFFF);
  static const textSoft = Color(0xD9FFFFFF);
  static const badge = Color(0xFFFF3B5C);

  /// D123, owner ref 147 (923 px = 430 pt, measured): the bottom bar's
  /// buttons are equal dark translucent circles (black ≈ 27 % over the
  /// room), 46 pt apart, the outer ones 8 pt from the edges. The reference
  /// measured 37.5 pt circles with 25 pt icons; on the device the owner
  /// found the icons too small, so they are drawn larger (42 pt circles,
  /// 31 pt icons) on the same 46 pt pitch. D141 (owner: "a slight
  /// enlargement"): 46 pt circles with 34 pt icons in 48 pt targets.
  static const barCircle = Color(0x45000000);
  static const barButton = 46.0;
  static const barIcon = 34.0;

  /// D141: the owner's colourful art (gift, PK, bag) fills the circle's
  /// place with no dark circle behind it, as on the video bar.
  static const barArt = 40.0;

  /// The bar buttons' touch target.
  static const barTarget = 48.0;

  /// Ref 147: the top buttons are 31 pt circles (black ≈ 33 %) 39 pt
  /// apart, the last one 10 pt from the edge; our framed icons are drawn
  /// at 17 pt in them.
  static const topCircle = 34.0;
  static const topPitch = 42.0;
  static const topIcon = 19.0;

  /// Ref 147: the room card is 39.6 pt tall, at most 268 pt wide; its
  /// action circle (a viewer's Follow) 26 pt, 6.5 pt from its end.
  static const cardHeight = 43.0;
  static const cardMaxWidth = 268.0;
  static const cardAction = 26.0;

  /// Ref 147: the chips under the card are 22 pt tall, 10 pt under it.
  static const chipHeight = 24.0;
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

/// [buttons] with 2 pt between them (D141: 48 pt targets 50 pt apart).
List<Widget> _spaced(List<Widget> buttons) => [
  for (final (i, b) in buttons.indexed) ...[
    if (i > 0) const SizedBox(width: 2),
    b,
  ],
];

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
    this.promo,
    this.combo,
    this.strips,
  });

  /// D145a: the lucky combo's button and chips, in the promo box's place
  /// (at the end over the gift button) while it shows.
  final Widget? combo;

  /// D145a: the gift strips, between the seats and the chat.
  final Widget? strips;

  /// D141a (owner): the room's promo box, low at the end over the bar's
  /// gift button (the last of [barEnd]); the chat keeps clear of it and the
  /// seats stay above it. Hidden while writing (the keyboard is up).
  final Widget? promo;

  /// The promo box's distance from the end edge and above the bar.
  static const double promoEnd = 4;
  static const double promoGap = 6;

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

  /// D141: the header row's top under the safe area, so the card's top is
  /// [KMetrics.liveHeaderGap] under it (the row is a 48 pt target tall).
  static const double headerTop =
      KMetrics.liveHeaderGap -
      (KSizes.minTouchTarget - KAudioRoom.cardHeight) / 2;

  @override
  Widget build(BuildContext context) {
    final chips = this.chips;
    final composer = this.composer;
    // D145a: while the lucky combo shows it takes the promo box's place.
    final slot = composer == null ? (combo ?? promo) : null;
    return Padding(
      // The keyboard pushes the room up (the screen does not resize).
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        // The chat box runs to the bottom edge, under the home indicator.
        bottom: composer == null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ref 147 (430 pt): the room card 10.5 pt from the edge, the
            // last top circle 10 pt from the other edge (6 + its 39 pt
            // target's 4 pt margin); the chips 10 pt under the card, the
            // viewers chip 10 pt from the edge. D141: the card's top
            // [KMetrics.liveHeaderGap] under the status bar, as the video
            // live's host pill (the 48 pt row centres the card).
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                10.5,
                headerTop,
                6,
                0,
              ),
              child: header,
            ),
            if (chips != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(10.5, 10, 10, 0),
                child: chips,
              ),
            // The seats (scrolling when they do not fit), then the chat low on
            // the start side, at most 40 % of the height (ref 83).
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // D123: the seats keep one size in every room; when
                    // they do not fit above the chat, they scroll.
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(4, 58, 4, 8),
                        child: stage,
                      ),
                    ),
                    // D145a: the gift strips between the seats and the
                    // chat (they never cover a seat).
                    if (strips case final strips?)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Align(
                          alignment: AlignmentDirectional.bottomStart,
                          child: strips,
                        ),
                      ),
                    if (chat.isNotEmpty || slot != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: box.maxHeight * 0.4,
                        ),
                        // The end slot (promo box or combo) beside the
                        // chat: the chat narrows for it and the seats end
                        // above it.
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                  8,
                                  0,
                                  slot == null ? 8 : promoGap,
                                  6,
                                ),
                                child: SingleChildScrollView(
                                  reverse: true,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (final line in chat)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: line,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (slot != null)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  end: promoEnd,
                                  bottom: promoGap,
                                ),
                                child: slot,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              // The chat box is a panel across the whole width.
              // Ref 147: the outer circles 8 pt from the edges (5 + the
              // 44 pt target's 3.25 pt margin).
              padding: composer == null
                  ? const EdgeInsets.fromLTRB(5, 2, 5, 0)
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
                  // Ref 147: equal circles, 46 pt apart.
                  : Row(
                      children: [
                        if (barLead case final lead?) ...[
                          Expanded(child: lead),
                          const SizedBox(width: 4),
                        ],
                        ..._spaced(barStart),
                        if (barLead == null) const Spacer(),
                        ..._spaced(barEnd),
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
    this.tools,
    this.replaceField,
    this.maxLength = 200,
    this.accent = false,
    this.startWithEmoji = false,
  });

  /// D131 (ref 162): open on the emoji panel, the keyboard hidden until the
  /// field is tapped.
  final bool startWithEmoji;

  /// CP-017: a row of small buttons above the field (bullet, voice,
  /// messages, picture).
  final Widget? tools;

  /// CP-017: shown instead of the field (e.g. while recording a clip).
  final Widget? replaceField;

  /// Code points the field takes (200 for chat, 60 for a bullet).
  final int maxLength;

  /// The field is outlined in the accent colour (bullet mode).
  final bool accent;

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final String sendLabel;
  final VoidCallback onSend;

  /// A Kabi emoji tapped in the row: sent at once as its own message (D66).
  final ValueChanged<KabsoEmoji> onEmoji;

  static const fieldKey = Key('liveChat.field');
  static const sendKey = Key('liveChat.send');

  /// D131 (ref 162): the keyboard / emoji switch in the field, the emoji
  /// panel, its group strip and its emoji.
  static const modeKey = Key('liveChat.mode');
  static const emojiPanelKey = Key('liveChat.emojiPanel');

  /// D138: the panel is the shared [EmojiPanel] (the owner's packs first,
  /// then the Unicode groups); these name its tabs and cells.
  static Key groupKey(UnicodeEmojiGroup g) =>
      EmojiPanel.tabKey(UnicodeEmojiTab(g));
  static Key packTabKey(EmojiPack p) => EmojiPanel.tabKey(EmojiPackTab(p));
  static Key unicodeKey(String emoji) => EmojiPanel.unicodeKey(emoji);
  static Key packKey(KabsoEmoji emoji) => EmojiPanel.packKey(emoji);
  static const modeCircle = Color(0xFFC6C7CB);
  static Key emojiKey(KabsoEmoji emoji) => Key('liveChat.emoji.${emoji.id}');

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
  late bool _emoji = widget.startWithEmoji;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.focusNode.addListener(_focusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.focusNode.removeListener(_focusChanged);
    super.dispose();
  }

  void _changed() => setState(() {});

  /// The keyboard came up (the field was tapped): the panel goes.
  void _focusChanged() {
    if (widget.focusNode.hasFocus && _emoji) setState(() => _emoji = false);
  }

  void _toggleMode() {
    if (_emoji) {
      setState(() => _emoji = false);
      widget.focusNode.requestFocus();
    } else {
      widget.focusNode.unfocus();
      setState(() => _emoji = true);
    }
  }

  /// Puts [emoji] (or a pack token) at the cursor.
  void _insert(String emoji) =>
      insertEmojiText(widget.controller, emoji, maxLength: widget.maxLength);

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    final hasText =
        widget.replaceField != null || widget.controller.text.trim().isNotEmpty;
    // D131 (ref 162): the white panel runs on under the home indicator
    // (the bar sits inside the safe area; its copy, shifted down, fills it).
    final below = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: LiveChatComposer.panel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
        boxShadow: [
          if (below > 0)
            BoxShadow(color: LiveChatComposer.panel, offset: Offset(0, below)),
        ],
      ),
      padding: EdgeInsets.only(top: widget.tools == null ? 12 : 8, bottom: 1.4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.tools case final tools?) ...[
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 12.6),
              child: tools,
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              const SizedBox(width: 12.6),
              Expanded(
                child: Container(
                  height: 41,
                  padding: const EdgeInsetsDirectional.only(
                    start: 21.9,
                    end: 2,
                  ),
                  decoration: BoxDecoration(
                    color: LiveChatComposer.field,
                    borderRadius: BorderRadius.circular(20.5),
                    border: widget.accent
                        ? Border.all(color: LiveChatComposer.sendOn, width: 1.2)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    children: [
                      Expanded(
                        child:
                            widget.replaceField ??
                            TextField(
                              key: LiveChatComposer.fieldKey,
                              controller: widget.controller,
                              focusNode: widget.focusNode,
                              maxLength: widget.maxLength,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => widget.onSend(),
                              cursorColor: LiveChatComposer.sendOn,
                              style: text.body.copyWith(
                                color: LiveChatComposer.ink,
                              ),
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
                      if (widget.replaceField == null)
                        Semantics(
                          button: true,
                          label: _emoji
                              ? context.l10n.liveEmojiKeyboard
                              : context.l10n.liveEmojiPanel,
                          excludeSemantics: true,
                          child: GestureDetector(
                            key: LiveChatComposer.modeKey,
                            behavior: HitTestBehavior.opaque,
                            onTap: _toggleMode,
                            child: SizedBox(
                              width: 40,
                              height: 41,
                              child: Center(
                                child: Container(
                                  width: 21.7,
                                  height: 21.7,
                                  decoration: BoxDecoration(
                                    color: _emoji
                                        ? LiveChatComposer.modeCircle
                                        : null,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _emoji
                                        ? Icons.keyboard_rounded
                                        : Icons.emoji_emotions_outlined,
                                    size: _emoji ? 14 : 21,
                                    color: _emoji
                                        ? const Color(0xFFFFFFFF)
                                        : LiveChatComposer.modeCircle,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
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
          if (_emoji)
            EmojiPanel(key: LiveChatComposer.emojiPanelKey, onEmoji: _insert)
          else ...[
            const SizedBox(height: 5.1),
            SizedBox(
              height: LiveChatComposer.emojiSize,
              child: ListView(
                scrollDirection: Axis.horizontal,
                itemExtent: LiveChatComposer.emojiPitch,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 1.55,
                ),
                children: [
                  for (final emoji in EmojiPack.kabi.emojis)
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
        ],
      ),
    );
  }
}

/// The room bar (owner ref 83): a rounded bar with the cover, the title and
/// a second line (the room number, "ID: …"); then share, minimize and ✕ in
/// round dark buttons. The live's points are a chip under the bar
/// ([LiveScoreChip]).
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
    this.username,
    this.minimizeKey,
    this.endKey,
    this.onShare,
    this.shareTooltip,
    this.shareKey,
    this.onTap,
    this.action,
    this.showMinimize = true,
    this.level,
  });

  /// CP-016 D (D101): the room level (the host's charm level) after the
  /// title; none while the charm levels are unavailable.
  final int? level;

  /// At the end of the room bar (a viewer's Follow).
  final Widget? action;

  /// Viewers have no floating window.
  final bool showMinimize;

  /// Opens the room's info (host) or the host's sheet (viewer).
  final VoidCallback? onTap;

  final VoidCallback? onShare;
  final String? shareTooltip;
  final Key? shareKey;

  /// The points chip ([LiveScoreChip]) keeps this key.
  static const scoreKey = Key('liveRoom.score');
  static const barKey = Key('liveRoom.bar');

  final Widget cover;
  final String title;
  final String? subtitle;

  /// D141 (owner): the host's `@username` under the title (copy on tap),
  /// in place of [subtitle].
  final String? username;
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
        // Ref 147: the card hugs its title, from 10.5 pt to at most
        // 278.5 pt; 39.6 pt tall, fully rounded.
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: KAudioRoom.cardMaxWidth,
              ),
              child: GestureDetector(
                key: barKey,
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  // At least 39.6 pt; it grows with large text instead of
                  // clipping the title and the subtitle.
                  constraints: const BoxConstraints(
                    minHeight: KAudioRoom.cardHeight,
                  ),
                  // Ref 147: the cover 5 pt in; the action circle 6.5 pt
                  // from the end, the title 14 pt without one.
                  padding: EdgeInsetsDirectional.fromSTEB(
                    5,
                    5,
                    action == null ? 14 : 6.5,
                    5,
                  ),
                  decoration: BoxDecoration(
                    color: KAudioRoom.bar,
                    borderRadius: BorderRadius.circular(
                      KAudioRoom.cardHeight / 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: SizedBox.square(dimension: 32, child: cover),
                      ),
                      // Ref 147: the title starts 52 pt from the edge.
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.caption.copyWith(
                                      fontSize: 14,
                                      height: 1.15,
                                      color: KAudioRoom.text,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (level case final level?) ...[
                                  const SizedBox(width: 4),
                                  CharmLevelBadge(level: level, height: 13),
                                ],
                              ],
                            ),
                            if (username case final name?)
                              KLiveUsernameTag(username: name, fontSize: 11)
                            else if (subtitle != null && subtitle.isNotEmpty)
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.caption.copyWith(
                                  fontSize: 11,
                                  height: 1.2,
                                  color: KAudioRoom.textSoft,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (action case final action?) ...[
                        const SizedBox(width: 8),
                        // Ref 147: a 26 pt circle; its 44 pt target
                        // overflows the card instead of making it taller.
                        SizedBox.square(
                          dimension: KAudioRoom.cardAction,
                          child: OverflowBox(
                            maxWidth: KSizes.minTouchTarget,
                            maxHeight: KSizes.minTouchTarget,
                            child: action,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Ref 147: 31 pt round buttons, 39 pt apart.
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
    // Ref 147: 22 pt tall, fully rounded, dark over the room.
    return Container(
      constraints: const BoxConstraints(minHeight: KAudioRoom.chipHeight),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: KAudioRoom.chip,
        borderRadius: BorderRadius.circular(KAudioRoom.chipHeight / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: const Color(0xFFFFC547)),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: DefaultTextStyle.merge(
              style: context.textStyles.caption.copyWith(
                fontSize: 12.5,
                height: 1,
                color: KAudioRoom.text,
                fontWeight: FontWeight.w600,
                shadows: KLiveColors.glassShadow,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// CP-012: the live's points as a chip under the room bar (owner ref 84:
/// the points coin and the count); tapping opens the breakdown.
class LiveScoreChip extends StatelessWidget {
  const new({
    required this.text,
    required this.label,
    super.key = LiveAudioRoomHeader.scoreKey,
    this.onTap,
  });

  /// Shortened points (12.4K).
  final String text;

  /// The points for screen readers.
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: onTap != null,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: LiveChip(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KCherryIcon(size: 13),
            const SizedBox(width: 4),
            Text(text),
          ],
        ),
      ),
    ),
  );
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
    this.size = 37,
    this.iconSize = 22,
    this.color = KAudioRoom.roundButton,
    this.iconColor = KAudioRoom.text,
    this.badge = 0,
    this.gradient,
    this.asset,
    this.tintAsset = false,
    this.bare = false,
    this.art = false,
  });

  /// D141 (owner): [asset] is the owner's colourful art (gift, PK, bag):
  /// drawn larger ([KAudioRoom.barArt]) with no dark circle behind it, as
  /// on the video bar.
  final bool art;

  /// The audio room's bar button (owner ref 147, D123): a flat dark
  /// translucent circle ([KAudioRoom.barButton]) with [asset] in its own
  /// colours (the owner's live bar pack), or [icon] in white, at
  /// [KAudioRoom.barIcon]; [size], [iconSize] and [color] do not apply.
  final bool bare;

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
          dimension: bare
              ? KAudioRoom.barTarget
              : size < 40
              ? 44
              : size + 2,
          child: Center(
            child: Badge(
              isLabelVisible: badge > 0,
              backgroundColor: KAudioRoom.badge,
              label: Text(badge > 99 ? '99+' : badge.toString()),
              child: bare
                  ? Container(
                      width: KAudioRoom.barButton,
                      height: KAudioRoom.barButton,
                      alignment: Alignment.center,
                      decoration: art
                          ? null
                          : const BoxDecoration(
                              shape: BoxShape.circle,
                              color: KAudioRoom.barCircle,
                            ),
                      child: Opacity(
                        opacity: onTap == null ? 0.45 : 1,
                        child: switch (asset) {
                          final asset? => Image.asset(
                            asset,
                            width: art ? KAudioRoom.barArt : KAudioRoom.barIcon,
                            height: art
                                ? KAudioRoom.barArt
                                : KAudioRoom.barIcon,
                          ),
                          null => Icon(
                            icon,
                            size: KAudioRoom.barIcon - 3,
                            color: iconColor,
                          ),
                        },
                      ),
                    )
                  : Container(
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
    this.avatarSize = size,
    this.pitch = size - 7,
    this.countHeight = size,
    this.countMinWidth,
  });

  /// D135 (ref 158 §4.2): the count pill's width at least (31 pt on the
  /// video live); else as wide as tall.
  final double? countMinWidth;

  final List<Widget> avatars;
  final String count;

  /// For screen readers ("12 watching").
  final String label;
  final VoidCallback? onTap;

  /// D131 (ref 158, the video live): 25.6 pt pictures 30.6 pt apart (no
  /// overlap) and a 25 pt count pill; the audio room keeps ref 147's.
  final double avatarSize;
  final double pitch;
  final double countHeight;

  /// Ref 147: as tall as the chips beside it.
  static const double size = KAudioRoom.chipHeight;

  @override
  Widget build(BuildContext context) {
    final shown = avatars.take(3).toList();
    final size = avatarSize;
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
                width: size + (shown.length - 1) * pitch,
                height: size,
                child: Stack(
                  children: [
                    for (var i = 0; i < shown.length; i++)
                      PositionedDirectional(
                        start: i * pitch,
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
            // Ref 147: the count is a chip like the room rank's.
            Container(
              constraints: BoxConstraints(
                minWidth: countMinWidth ?? countHeight,
              ),
              height: countHeight,
              padding: EdgeInsets.symmetric(
                horizontal: countMinWidth == null ? 8 : 6,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: KAudioRoom.chip,
                borderRadius: BorderRadius.circular(countHeight / 2),
              ),
              child: Text(
                count,
                style: context.textStyles.caption.copyWith(
                  fontSize: 11.5,
                  height: 1,
                  color: KAudioRoom.text,
                  fontWeight: FontWeight.w700,
                  shadows: KLiveColors.glassShadow,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A top-bar button (owner ref 147): a 31 pt dark round button with the
/// icon drawn white, 39 pt apart (in a 39 × 44 pt target).
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
          width: KAudioRoom.topPitch,
          height: KSizes.minTouchTarget,
          child: Center(
            child: Opacity(
              opacity: onTap == null ? 0.45 : 1,
              child: Container(
                width: KAudioRoom.topCircle,
                height: KAudioRoom.topCircle,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: KAudioRoom.topButton,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  asset,
                  width: KAudioRoom.topIcon,
                  height: KAudioRoom.topIcon,
                  color: KAudioRoom.text,
                ),
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
