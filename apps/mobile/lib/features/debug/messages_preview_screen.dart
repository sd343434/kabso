import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/widgets/kabso_motion.dart';
import 'package:kabso_live/features/debug/preview_photo.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_panel.dart';
import 'package:kabso_live/features/messages/attachments.dart';
import 'package:kabso_live/features/messages/widgets/chat_composer.dart';
import 'package:kabso_live/features/messages/widgets/chat_gift_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Geometry of the private-message bubbles. Media sizes and the greeting
/// come from the owner's Figma kit (KL-056, node 1343:4157); the bubbles,
/// header, day chip and typing indicator follow the owner's chat
/// reference (D68). Colours are Kabso's (the sender bubble is Kabso red)
/// and media is generated art, never a kit's photos.
abstract final class KMessagePreview {
  /// First-time greeting (node 1347:5330): title, three greeting tiles of
  /// up to 92 with up to 43 between them, and a close button.
  static const double greetingTitleSize = 15;
  static const double greetingTile = 92;
  static const double greetingGap = 43;
  static const double greetingIcon = 40;
  static const double greetingClose = 20;

  /// The sender's picture beside received messages (D70).
  static const double avatar = 28;
  static const double avatarGap = 8;

  static const double maxBubbleWidth = 282;
  static const double paddingH = 14;
  static const double paddingV = 10;
  static const double radius = 18;

  /// The bubble corner next to the sender's edge, where a tail would be.
  static const double tailRadius = 4;
  static const double textSize = 16;
  static const double textHeight = 1.3;

  /// Time and read ticks at the bottom end of a bubble.
  static const double metaSize = 11;
  static const double tickSize = 15;
  static const Size picture = Size(180, 238);
  static const Size video = Size(168, 297);
  static const double mediaRadius = 15;
  static const double mediaTailRadius = 10;
  static const double playIcon = 40;
  static const double videoUserAvatar = 18;
  static const double videoUserText = 13;
  static const double videoUserInset = 8;
  static const Size reaction = Size(41, 30);
  static const double reactionOverlap = 22.5;
  static const double rowGap = 10;

  /// Between messages in a row from one sender (D69).
  static const double groupGap = 3;

  /// The bubble corners that face another message of the same group.
  static const double groupRadius = 6;
  static const double reactionRowGap = 28;

  static const double onlineDot = 11;
  static const double typingDot = 7;
}

enum MessagePreviewKind { text, picture, video, gift }

/// What happened to a sent message (shown as ticks, D68).
enum MessagePreviewStatus { sent, delivered, read }

/// One message of the preview conversation (labelled test data, D46).
class MessagePreview {
  const new({
    required this.mine,
    this.kind = MessagePreviewKind.text,
    this.text = '',
    this.seed = 0,
    this.reaction,
    this.local,
    this.at,
    this.status = MessagePreviewStatus.sent,
    this.gift,
    this.arrive = false,
  });

  /// Sent by the viewer (end side, Kabso red) or received (start side).
  final bool mine;
  final MessagePreviewKind kind;
  final String text;

  /// Seed of the generated art for picture and video messages.
  final int seed;
  final String? reaction;

  /// A photo or video the viewer attached from the device (D67); shown
  /// from the device, never uploaded.
  final PickedMedia? local;

  /// When it was sent; shown inside the bubble.
  final DateTime? at;

  /// Ticks of a sent message ([mine] only).
  final MessagePreviewStatus status;

  /// The gift of a [MessagePreviewKind.gift] message (D69).
  final ChatGift? gift;

  /// Just sent here: the gift pops in once.
  final bool arrive;
}

/// The other person in the preview conversation.
String messagesPreviewPeer({required bool ar}) =>
    ar ? 'نور (تجربة)' : 'Nour (test)';

List<MessagePreview> messagesPreviewFixture({required bool ar}) {
  // Fixed times keep the goldens stable.
  DateTime at(int minute) => DateTime(2026, 1, 1, 10, minute);
  return [
    MessagePreview(
      mine: false,
      text: ar ? 'مرحبًا! هذه رسالة تجريبية' : 'Hi! This is a test message',
      at: at(2),
    ),
    MessagePreview(
      mine: true,
      text: ar ? 'أهلًا، وصلت' : 'Hey, got it',
      reaction: '❤️',
      at: at(3),
      status: MessagePreviewStatus.read,
    ),
    MessagePreview(
      mine: false,
      kind: MessagePreviewKind.picture,
      seed: 2,
      at: at(5),
    ),
    MessagePreview(
      mine: true,
      kind: MessagePreviewKind.video,
      seed: 5,
      at: at(6),
      status: MessagePreviewStatus.delivered,
    ),
    MessagePreview(
      mine: false,
      text: ar ? 'جميل جدًا' : 'Looks great',
      at: at(8),
    ),
  ];
}

/// D69: the test conversation also holds a received gift; its name comes
/// from the localized preview gifts, so the fixture needs [l10n].
MessagePreview messagesPreviewGiftFixture(AppLocalizations l10n) =>
    MessagePreview(
      mine: false,
      kind: MessagePreviewKind.gift,
      gift: ChatGift(gift: KGiftPanel.preview(l10n)[1], count: 5),
      at: DateTime(2026, 1, 1, 10, 9),
    );

/// Private conversation preview (D68 layout): a header with the peer and
/// their status, a day chip, received bubbles at the start and sent ones
/// (with ticks) at the end, a typing indicator, and the shared composer,
/// which appends locally. With no messages it shows the first-time
/// greeting (UI kit "First time", node 1347:5330). Debug-only; nothing is
/// sent anywhere.
class MessagesPreviewScreen extends StatefulWidget {
  /// [peer] and [initialMessages] default to the labelled test
  /// conversation; [online] and [typing] default to on for it.
  const new({
    super.key,
    this.peer,
    this.peerPhoto,
    this.initialMessages,
    this.online,
    this.typing,
  });

  final String? peer;

  /// A development headshot (`PreviewPhotos`) for [peer]; the test
  /// conversation uses one by default.
  final String? peerPhoto;
  final List<MessagePreview>? initialMessages;
  final bool? online;
  final bool? typing;

  static const testDataKey = Key('messages-preview-test-data');
  static const listKey = Key('messages-preview-list');
  static const inputKey = Key('messages-preview-input');
  static const sendKey = Key('messages-preview-send');
  static const emojiKey = Key('messages-preview-emoji');
  static const attachKey = Key('messages-preview-attach');
  static const giftKey = Key('messages-preview-gift');
  static const greetingKey = Key('messages-preview-greeting');
  static const greetingCloseKey = Key('messages-preview-greeting-close');
  static const dayKey = Key('messages-preview-day');
  static const typingKey = Key('messages-preview-typing');

  @override
  State<MessagesPreviewScreen> createState() => _MessagesPreviewScreenState();
}

class _MessagesPreviewScreenState extends State<MessagesPreviewScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<MessagePreview>? _messages;
  bool _greetingDismissed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messages ??=
        widget.initialMessages ??
        [
          ...messagesPreviewFixture(
            ar: Directionality.of(context) == TextDirection.rtl,
          ),
          messagesPreviewGiftFixture(context.l10n),
        ];
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// D67: an attached photo or video appears at once, shown from the
  /// device.
  void _sendMedia(PickedMedia media) {
    setState(
      () => _messages = [
        ..._messages!,
        MessagePreview(
          mine: true,
          kind: media.isVideo
              ? MessagePreviewKind.video
              : MessagePreviewKind.picture,
          local: media,
          at: clock.now(),
        ),
      ],
    );
    _showLatest();
  }

  /// D67: what was just sent scrolls into view.
  void _showLatest([int tries = 3]) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scroll.hasClients) return;
      await _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      // The list builds lazily, so its end is only an estimate until the
      // last items are laid out: follow it if it moved.
      if (mounted &&
          _scroll.hasClients &&
          tries > 1 &&
          _scroll.position.pixels < _scroll.position.maxScrollExtent - 1) {
        _showLatest(tries - 1);
      }
    });
  }

  /// D69: a gift from the gift box appears at once (nothing is charged or
  /// sent: no gift API, B5).
  Future<void> _sendGift(String peer) async {
    final gift = await showChatGiftSheet(context, peer);
    if (gift == null || !mounted) return;
    setState(
      () => _messages = [
        ..._messages!,
        MessagePreview(
          mine: true,
          kind: MessagePreviewKind.gift,
          gift: gift,
          at: clock.now(),
          arrive: true,
        ),
      ],
    );
    _showLatest();
  }

  void _send([String? greeting]) {
    final text = (greeting ?? _controller.text).trim();
    if (text.isEmpty) return;
    setState(() {
      _messages = [
        ..._messages!,
        MessagePreview(mine: true, text: text, at: clock.now()),
      ];
      if (greeting == null) _controller.clear();
    });
    _showLatest();
  }

  /// Both exist, are plain bubbles (not gifts) and come from one sender.
  static bool _sameSender(List<MessagePreview> m, int a, int b) =>
      a >= 0 &&
      b < m.length &&
      m[a].mine == m[b].mine &&
      m[a].kind != MessagePreviewKind.gift &&
      m[b].kind != MessagePreviewKind.gift;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ar = Directionality.of(context) == TextDirection.rtl;
    final peer = widget.peer ?? messagesPreviewPeer(ar: ar);
    final messages = _messages!;
    final showGreeting = messages.isEmpty && !_greetingDismissed;
    final typing =
        messages.isNotEmpty &&
        (widget.typing ?? widget.initialMessages == null);
    final photo = widget.peer == null ? PreviewPhotos.huda : widget.peerPhoto;
    return Scaffold(
      backgroundColor: p.surface,
      appBar: _Header(
        peer: peer,
        photo: photo,
        online: widget.online ?? widget.initialMessages == null,
      ),
      body: Column(
        children: [
          Expanded(
            // D69: a quiet wallpaper of Kabso shapes behind the thread.
            child: CustomPaint(
              painter: _ChatWallpaper(p.textPrimary),
              child: ListView(
                key: MessagesPreviewScreen.listKey,
                controller: _scroll,
                padding: const EdgeInsets.all(KSpacing.md),
                children: [
                  if (messages.isNotEmpty)
                    const _DayChip(key: MessagesPreviewScreen.dayKey),
                  for (final (i, m) in messages.indexed)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: m.reaction != null
                            ? KMessagePreview.reactionRowGap
                            // D69: messages in a row from one person sit
                            // close together.
                            : _sameSender(messages, i, i + 1)
                            ? KMessagePreview.groupGap
                            : KMessagePreview.rowGap,
                      ),
                      child: _MessageRow(
                        message: m,
                        peer: peer,
                        photo: photo,
                        // D70: the sender's picture by the last of their
                        // messages in a row.
                        showAvatar:
                            i + 1 == messages.length || messages[i + 1].mine,
                        groupedAbove: _sameSender(messages, i - 1, i),
                        groupedBelow: _sameSender(messages, i, i + 1),
                      ),
                    ),
                  if (typing)
                    _WithAvatar(
                      peer: peer,
                      photo: photo,
                      child: _TypingBubble(
                        key: MessagesPreviewScreen.typingKey,
                        peer: peer,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (showGreeting)
            _FirstTimeGreeting(
              peer: peer,
              onGreet: _send,
              onDismiss: () => setState(() => _greetingDismissed = true),
            ),
          ChatComposer(
            controller: _controller,
            onSend: _send,
            // D66: a Kabi emoji goes out at once, as its own message.
            onEmoji: (e) => _send(e.token),
            onMedia: _sendMedia,
            onGift: () => _sendGift(peer),
            giftKey: MessagesPreviewScreen.giftKey,
            inputKey: MessagesPreviewScreen.inputKey,
            sendKey: MessagesPreviewScreen.sendKey,
            emojiKey: MessagesPreviewScreen.emojiKey,
            attachKey: MessagesPreviewScreen.attachKey,
          ),
        ],
      ),
    );
  }
}

/// The conversation header: the peer's avatar (with a green dot while
/// [online]), name and status, and the test-data label.
class _Header extends StatelessWidget implements PreferredSizeWidget {
  const new({required this.peer, required this.online, this.photo});

  final String peer;
  final bool online;
  final String? photo;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final t = context.textStyles;
    return AppBar(
      backgroundColor: p.background,
      titleSpacing: 0,
      shape: Border(bottom: BorderSide(color: p.border, width: 0.7)),
      title: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              KAvatar(
                name: peer,
                size: KSizes.avatarSm,
                image: PreviewPhotos.asset(photo),
              ),
              if (online)
                PositionedDirectional(
                  end: -1,
                  bottom: -1,
                  child: Container(
                    width: KMessagePreview.onlineDot,
                    height: KMessagePreview.onlineDot,
                    decoration: BoxDecoration(
                      color: p.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.background, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: KSpacing.sm),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  peer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyStrong.copyWith(color: p.textPrimary),
                ),
                if (online)
                  Text(
                    l10n.chatOnline,
                    maxLines: 1,
                    style: t.caption.copyWith(color: p.success),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: KSpacing.md),
          child: Center(
            child: DecoratedBox(
              key: MessagesPreviewScreen.testDataKey,
              decoration: BoxDecoration(
                color: p.surfaceOverlay,
                borderRadius: BorderRadius.circular(KRadius.xs),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.xs,
                  vertical: KSpacing.xxs,
                ),
                child: Text(
                  l10n.feedPreviewTestData,
                  style: t.caption.copyWith(color: p.textSecondary),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.md),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.surfaceRaised.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(KRadius.pill),
            border: Border.all(color: p.border.withValues(alpha: 0.6)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.md,
              vertical: KSpacing.xs,
            ),
            child: Text(
              context.l10n.chatToday,
              style: context.textStyles.caption.copyWith(
                color: p.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A received item with the sender's picture at its bottom start (D70);
/// with [showAvatar] off the same space stays empty, so a run of messages
/// lines up.
class _WithAvatar extends StatelessWidget {
  const new({
    required this.peer,
    required this.photo,
    required this.child,
    this.showAvatar = true,
  });

  final String peer;
  final String? photo;
  final Widget child;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      if (showAvatar)
        KAvatar(
          name: peer,
          size: KMessagePreview.avatar,
          image: PreviewPhotos.asset(photo),
        )
      else
        const SizedBox(width: KMessagePreview.avatar),
      const SizedBox(width: KMessagePreview.avatarGap),
      Flexible(
        child: Align(alignment: AlignmentDirectional.centerStart, child: child),
      ),
    ],
  );
}

class _MessageRow extends StatelessWidget {
  const new({
    required this.message,
    required this.peer,
    this.photo,
    this.showAvatar = true,
    this.groupedAbove = false,
    this.groupedBelow = false,
  });

  final MessagePreview message;
  final String peer;
  final String? photo;
  final bool showAvatar;
  final bool groupedAbove;
  final bool groupedBelow;

  @override
  Widget build(BuildContext context) {
    final gift = message.gift;
    final content = gift != null
        ? ChatGiftCard(
            gift: gift,
            mine: message.mine,
            peer: peer,
            arrive: message.arrive,
            meta: Padding(
              padding: const EdgeInsets.only(top: KSpacing.xs),
              child: _Meta(
                message: message,
                color: message.mine
                    ? context.palette.onPrimary.withValues(alpha: 0.75)
                    : context.palette.textTertiary,
              ),
            ),
          )
        : _Bubble(
            message: message,
            groupedAbove: groupedAbove,
            groupedBelow: groupedBelow,
          );
    if (message.mine) {
      return Align(alignment: AlignmentDirectional.centerEnd, child: content);
    }
    return _WithAvatar(
      peer: peer,
      photo: photo,
      showAvatar: showAvatar,
      child: content,
    );
  }
}

/// The time and, on sent messages, the ticks (D68).
class _Meta extends StatelessWidget {
  const new({required this.message, required this.color});

  final MessagePreview message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final at = message.at;
    final status = switch (message.status) {
      MessagePreviewStatus.sent => (Icons.done_rounded, l10n.chatStatusSent),
      MessagePreviewStatus.delivered => (
        Icons.done_all_rounded,
        l10n.chatStatusDelivered,
      ),
      MessagePreviewStatus.read => (
        Icons.done_all_rounded,
        l10n.chatStatusRead,
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (at != null)
          Text(
            KFormat.time(at, Localizations.localeOf(context).toLanguageTag()),
            style: context.textStyles.caption.copyWith(
              fontSize: KMessagePreview.metaSize,
              color: color,
            ),
          ),
        if (message.mine) ...[
          const SizedBox(width: KSpacing.xxs),
          Semantics(
            label: status.$2,
            child: Icon(
              status.$1,
              size: KMessagePreview.tickSize,
              // Read is the full colour; sent and delivered are muted.
              color: message.status == MessagePreviewStatus.read
                  ? color.withValues(alpha: 1)
                  : color,
            ),
          ),
        ],
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const new({
    required this.message,
    this.groupedAbove = false,
    this.groupedBelow = false,
  });

  final MessagePreview message;
  final bool groupedAbove;
  final bool groupedBelow;

  /// Rounded corners with the tail corner at the bottom on the sender's side
  /// (bottom-end for sent messages, bottom-start for received ones).
  static BorderRadiusDirectional _corners({
    required bool mine,
    required double radius,
    required double tail,
    bool above = false,
    bool below = false,
  }) {
    // The sender's side: small where the group continues, the tail at the
    // group's last bubble.
    final top = Radius.circular(above ? KMessagePreview.groupRadius : radius);
    final bottom = Radius.circular(below ? KMessagePreview.groupRadius : tail);
    final round = Radius.circular(radius);
    return BorderRadiusDirectional.only(
      topStart: mine ? round : top,
      topEnd: mine ? top : round,
      bottomStart: mine ? round : bottom,
      bottomEnd: mine ? bottom : round,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final mine = message.mine;
    final metaColor = mine
        ? p.onPrimary.withValues(alpha: 0.75)
        : p.textTertiary;
    final body = switch (message.kind) {
      // D66: only Kabi emojis → shown big, without a bubble.
      MessagePreviewKind.text
          when KabiEmojiText.onlyEmojis(message.text) != null =>
        KabiEmojiText(message.text, style: context.textStyles.body),
      MessagePreviewKind.text => Container(
        constraints: const BoxConstraints(
          maxWidth: KMessagePreview.maxBubbleWidth,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: KMessagePreview.paddingH,
          vertical: KMessagePreview.paddingV,
        ),
        decoration: BoxDecoration(
          // Received bubbles are raised cards on the page (D68); sent ones
          // a soft Kabso-red gradient (D69).
          color: mine ? null : p.surfaceRaised,
          gradient: mine
              ? LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [
                    Color.lerp(p.primary, KBrandColors.red400, 0.35)!,
                    p.primary,
                  ],
                )
              : null,
          borderRadius: _corners(
            mine: mine,
            radius: KMessagePreview.radius,
            tail: KMessagePreview.tailRadius,
            above: groupedAbove,
            below: groupedBelow,
          ),
          boxShadow: [
            BoxShadow(
              color: (mine ? p.primary : p.textPrimary).withValues(
                alpha: mine ? 0.18 : 0.06,
              ),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        // The time sits after the text when it fits, else under it at the
        // end.
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: KSpacing.sm,
          children: [
            KabiEmojiText(
              message.text,
              style: context.textStyles.body.copyWith(
                fontSize: KMessagePreview.textSize,
                height: KMessagePreview.textHeight,
                color: mine ? p.onPrimary : p.textPrimary,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: KSpacing.xxs),
              child: _Meta(message: message, color: metaColor),
            ),
          ],
        ),
      ),
      MessagePreviewKind.picture ||
      MessagePreviewKind.video when message.local != null => LocalMediaView(
        media: message.local!,
        size: message.local!.isVideo
            ? KMessagePreview.video
            : KMessagePreview.picture,
        borderRadius: _corners(
          mine: mine,
          radius: KMessagePreview.mediaRadius,
          tail: KMessagePreview.mediaTailRadius,
        ),
      ),
      // Gifts are drawn by [ChatGiftCard] in the row.
      MessagePreviewKind.gift => const SizedBox.shrink(),
      MessagePreviewKind.picture => _Media(
        size: KMessagePreview.picture,
        seed: message.seed,
        corners: _corners(
          mine: mine,
          radius: KMessagePreview.mediaRadius,
          tail: KMessagePreview.tailRadius,
        ),
      ),
      MessagePreviewKind.video => _Media(
        size: KMessagePreview.video,
        seed: message.seed,
        video: true,
        corners: _corners(
          mine: mine,
          radius: KMessagePreview.mediaRadius,
          tail: KMessagePreview.mediaTailRadius,
        ),
      ),
    };
    final media = message.kind != MessagePreviewKind.text;
    final at = message.at;
    // D69: photos and videos carry their time on a dark pill inside.
    final shown = media && at != null
        ? Stack(
            children: [
              body,
              PositionedDirectional(
                end: KSpacing.sm,
                top: KSpacing.sm,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: KPalette.dark.scrim.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(KRadius.pill),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.sm,
                      vertical: KSpacing.xxs,
                    ),
                    child: _Meta(
                      message: message,
                      color: KPalette.dark.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          )
        : body;
    final reaction = message.reaction;
    return Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (reaction == null)
          shown
        else
          Stack(
            clipBehavior: Clip.none,
            children: [
              shown,
              PositionedDirectional(
                bottom: -KMessagePreview.reactionOverlap,
                end: mine ? 2 : null,
                start: mine ? null : 2,
                child: Semantics(
                  label: context.l10n.messagesPreviewReaction(reaction),
                  excludeSemantics: true,
                  child: Container(
                    width: KMessagePreview.reaction.width,
                    height: KMessagePreview.reaction.height,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.surfaceRaised,
                      borderRadius: BorderRadius.circular(
                        KMessagePreview.reaction.height,
                      ),
                      border: Border.all(color: p.border),
                    ),
                    child: Text(reaction, style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// The peer is typing: three dots that bounce for a few seconds, then
/// rest (still dots with reduced motion).
class _TypingBubble extends StatefulWidget {
  const new({required this.peer, super.key});

  final String peer;

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin, MotionClock {
  @override
  double get motionSeconds => 6;

  @override
  double get restSeconds => 0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: context.l10n.chatTyping(KFormat.bidiIsolate(widget.peer)),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KMessagePreview.paddingH,
          vertical: KMessagePreview.paddingV + 4,
        ),
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          borderRadius: _Bubble._corners(
            mine: false,
            radius: KMessagePreview.radius,
            tail: KMessagePreview.tailRadius,
          ),
          boxShadow: [
            BoxShadow(
              color: p.textPrimary.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ValueListenableBuilder<double>(
          valueListenable: time,
          builder: (_, t, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: KSpacing.xs),
                Transform.translate(
                  // Stops on a whole loop, so the dots rest level.
                  offset: Offset(
                    0,
                    -3 * motionWave(motionLoop(t, 1.2, i * 0.15)),
                  ),
                  child: Container(
                    width: KMessagePreview.typingDot,
                    height: KMessagePreview.typingDot,
                    decoration: BoxDecoration(
                      color: p.textTertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Media extends StatelessWidget {
  const new({
    required this.size,
    required this.seed,
    required this.corners,
    this.video = false,
  });

  final Size size;
  final int seed;
  final BorderRadiusDirectional corners;
  final bool video;

  @override
  Widget build(BuildContext context) {
    final white = KPalette.dark.textPrimary;
    final ar = Directionality.of(context) == TextDirection.rtl;
    return ClipRRect(
      borderRadius: corners,
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PreviewPhoto(seed),
            if (video) ...[
              Center(
                child: Semantics(
                  container: true,
                  button: true,
                  label: context.l10n.messagesPreviewPlay,
                  excludeSemantics: true,
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: KMessagePreview.playIcon,
                    color: white,
                  ),
                ),
              ),
              PositionedDirectional(
                start: KMessagePreview.videoUserInset,
                end: KMessagePreview.videoUserInset,
                bottom: KMessagePreview.videoUserInset,
                child: Row(
                  children: [
                    KAvatar(
                      name: messagesPreviewPeer(ar: ar),
                      size: KMessagePreview.videoUserAvatar,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        ar ? '@نور_تجربة' : '@nour_test',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyles.caption.copyWith(
                          fontSize: KMessagePreview.videoUserText,
                          fontWeight: FontWeight.w600,
                          color: white.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FirstTimeGreeting extends StatelessWidget {
  const new({
    required this.peer,
    required this.onGreet,
    required this.onDismiss,
  });

  final String peer;
  final ValueChanged<String> onGreet;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final greetings = [
      (AppIcons.handWave, l10n.messagesGreetingHi),
      (AppIcons.heart, l10n.messagesGreetingHello),
      (AppIcons.emoji, l10n.messagesGreetingHowAreYou),
    ];
    return Padding(
      key: MessagesPreviewScreen.greetingKey,
      padding: const EdgeInsets.fromLTRB(
        KSpacing.md,
        KSpacing.sm,
        KSpacing.md,
        KSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(width: kMinInteractiveDimension),
              Expanded(
                child: Text(
                  l10n.conversationsSayHi(KFormat.bidiIsolate(peer)),
                  textAlign: TextAlign.center,
                  style: context.textStyles.body.copyWith(
                    fontSize: KMessagePreview.greetingTitleSize,
                    color: p.textPrimary,
                  ),
                ),
              ),
              IconButton(
                key: MessagesPreviewScreen.greetingCloseKey,
                tooltip: l10n.liveClose,
                onPressed: onDismiss,
                icon: AppIcon(
                  AppIcons.close,
                  size: KMessagePreview.greetingClose,
                  color: p.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              // Measured 92 tiles 43 apart; both shrink on narrow screens.
              final gap = math.min(
                KMessagePreview.greetingGap,
                constraints.maxWidth * 0.06,
              );
              final tile = math.min(
                KMessagePreview.greetingTile,
                (constraints.maxWidth - 2 * gap) / 3,
              );
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final (i, (asset, text)) in greetings.indexed) ...[
                    if (i > 0) SizedBox(width: gap),
                    Semantics(
                      button: true,
                      label: text,
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: () => onGreet(text),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: tile,
                          height: tile,
                          decoration: BoxDecoration(
                            color: p.surfaceOverlay,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: AppIcon(
                            asset,
                            size: math.min(
                              KMessagePreview.greetingIcon,
                              tile / 2,
                            ),
                            color: p.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// D69: Kabso's chat wallpaper — small hearts, stars, notes, mics and gift
/// glyphs scattered in a fixed pattern, barely visible (4 % of [ink]).
class _ChatWallpaper extends CustomPainter {
  new(this.ink);

  final Color ink;

  static const List<IconData> _glyphs = [
    Icons.favorite_border_rounded,
    Icons.star_border_rounded,
    Icons.music_note_rounded,
    Icons.mic_none_rounded,
    Icons.card_giftcard_rounded,
    Icons.chat_bubble_outline_rounded,
    Icons.emoji_emotions_outlined,
    Icons.celebration_outlined,
  ];
  static const double _cell = 64;

  @override
  void paint(Canvas canvas, Size size) {
    final color = ink.withValues(alpha: 0.04);
    var n = 0;
    for (var y = 0.0; y < size.height + _cell; y += _cell) {
      final row = (y / _cell).round();
      for (var x = row.isOdd ? _cell / 2 : 0.0; x < size.width; x += _cell) {
        final icon = _glyphs[(n * 5 + row) % _glyphs.length];
        final tp = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              fontSize: 20,
              color: color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        canvas
          ..save()
          ..translate(x + 22, y + 22)
          ..rotate((n % 5 - 2) * 0.2)
          ..translate(-tp.width / 2, -tp.height / 2);
        tp.paint(canvas, Offset.zero);
        canvas.restore();
        tp.dispose();
        n++;
      }
    }
  }

  @override
  bool shouldRepaint(_ChatWallpaper old) => old.ink != ink;
}
