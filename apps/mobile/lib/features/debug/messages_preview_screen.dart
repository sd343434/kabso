import 'dart:math' as math;

import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/preview_photo.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Geometry of the KL-056 private-message bubbles, measured from the owner's
/// Figma reference (UI kit "Private Messages", node 1343:4157). Only geometry
/// and type sizes are taken from it; colours are Kabso's (the sender bubble is
/// Kabso red) and media is generated art, never the kit's photos.
abstract final class KMessagePreview {
  /// First-time greeting (node 1347:5330): title, three greeting tiles of
  /// up to 92 with up to 43 between them, and a close button.
  static const double greetingTitleSize = 15;
  static const double greetingTile = 92;
  static const double greetingGap = 43;
  static const double greetingIcon = 40;
  static const double greetingClose = 20;

  static const double avatar = 31;
  static const double avatarGap = 9;
  static const double maxBubbleWidth = 282;
  static const double padding = 12;
  static const double radius = 23;

  /// The bubble corner next to the sender's edge, where the kit draws a tail.
  static const double tailRadius = 4;
  static const double textSize = 17;
  static const double textHeight = 1.15;
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
  static const double rowGap = 12;
  static const double reactionRowGap = 28;
}

enum MessagePreviewKind { text, picture, video }

/// One message of the preview conversation (labelled test data, D46).
class MessagePreview {
  const new({
    required this.mine,
    this.kind = MessagePreviewKind.text,
    this.text = '',
    this.seed = 0,
    this.reaction,
  });

  /// Sent by the viewer (end side, Kabso red) or received (start side).
  final bool mine;
  final MessagePreviewKind kind;
  final String text;

  /// Seed of the generated art for picture and video messages.
  final int seed;
  final String? reaction;
}

/// The other person in the preview conversation.
String messagesPreviewPeer({required bool ar}) =>
    ar ? 'نور (تجربة)' : 'Nour (test)';

List<MessagePreview> messagesPreviewFixture({required bool ar}) => [
  MessagePreview(
    mine: false,
    text: ar ? 'مرحبًا! هذه رسالة تجريبية' : 'Hi! This is a test message',
  ),
  MessagePreview(
    mine: true,
    text: ar ? 'أهلًا، وصلت' : 'Hey, got it',
    reaction: '❤️',
  ),
  const MessagePreview(mine: false, kind: MessagePreviewKind.picture, seed: 2),
  const MessagePreview(mine: true, kind: MessagePreviewKind.video, seed: 5),
  MessagePreview(mine: false, text: ar ? 'جميل جدًا' : 'Looks great'),
];

/// Private conversation preview: received bubbles at the start, sent ones at
/// the end, a composer that appends locally. With no messages it shows the
/// first-time greeting (UI kit "First time", node 1347:5330). Debug-only;
/// nothing is sent anywhere.
class MessagesPreviewScreen extends StatefulWidget {
  /// [peer] and [initialMessages] default to the labelled test conversation.
  const new({super.key, this.peer, this.initialMessages});

  final String? peer;
  final List<MessagePreview>? initialMessages;

  static const testDataKey = Key('messages-preview-test-data');
  static const listKey = Key('messages-preview-list');
  static const inputKey = Key('messages-preview-input');
  static const sendKey = Key('messages-preview-send');
  static const greetingKey = Key('messages-preview-greeting');
  static const greetingCloseKey = Key('messages-preview-greeting-close');

  @override
  State<MessagesPreviewScreen> createState() => _MessagesPreviewScreenState();
}

class _MessagesPreviewScreenState extends State<MessagesPreviewScreen> {
  final _controller = TextEditingController();
  List<MessagePreview>? _messages;
  bool _greetingDismissed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messages ??=
        widget.initialMessages ??
        messagesPreviewFixture(
          ar: Directionality.of(context) == TextDirection.rtl,
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send([String? greeting]) {
    final text = (greeting ?? _controller.text).trim();
    if (text.isEmpty) return;
    setState(() {
      _messages = [..._messages!, MessagePreview(mine: true, text: text)];
      if (greeting == null) _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final ar = Directionality.of(context) == TextDirection.rtl;
    final peer = widget.peer ?? messagesPreviewPeer(ar: ar);
    final messages = _messages!;
    final showGreeting = messages.isEmpty && !_greetingDismissed;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        titleSpacing: 0,
        title: Row(
          children: [
            KAvatar(name: peer, size: KSizes.avatarSm),
            const SizedBox(width: KSpacing.sm),
            Flexible(
              child: Text(
                peer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.bodyStrong.copyWith(
                  color: p.textPrimary,
                ),
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
                    style: context.textStyles.caption.copyWith(
                      color: p.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              key: MessagesPreviewScreen.listKey,
              padding: const EdgeInsets.all(KSpacing.md),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final m = messages[i];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: m.reaction == null
                        ? KMessagePreview.rowGap
                        : KMessagePreview.reactionRowGap,
                  ),
                  child: _MessageRow(message: m, peer: peer),
                );
              },
            ),
          ),
          if (showGreeting)
            _FirstTimeGreeting(
              peer: peer,
              onGreet: _send,
              onDismiss: () => setState(() => _greetingDismissed = true),
            ),
          _Composer(controller: _controller, onSend: _send),
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const new({required this.message, required this.peer});

  final MessagePreview message;
  final String peer;

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final bubble = _Bubble(message: message);
    return Row(
      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!mine) ...[
          KAvatar(name: peer, size: KMessagePreview.avatar),
          const SizedBox(width: KMessagePreview.avatarGap),
        ],
        Flexible(child: bubble),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const new({required this.message});

  final MessagePreview message;

  /// Rounded corners with the tail corner at the bottom on the sender's side
  /// (bottom-end for sent messages, bottom-start for received ones).
  static BorderRadiusDirectional _corners({
    required bool mine,
    required double radius,
    required double tail,
  }) => BorderRadiusDirectional.only(
    topStart: Radius.circular(radius),
    topEnd: Radius.circular(radius),
    bottomStart: Radius.circular(mine ? radius : tail),
    bottomEnd: Radius.circular(mine ? tail : radius),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final mine = message.mine;
    final Widget body = switch (message.kind) {
      MessagePreviewKind.text => Container(
        constraints: const BoxConstraints(
          maxWidth: KMessagePreview.maxBubbleWidth,
        ),
        padding: const EdgeInsets.all(KMessagePreview.padding),
        decoration: BoxDecoration(
          // surfaceOverlay stays distinct from the page in light and dark.
          color: mine ? p.primary : p.surfaceOverlay,
          borderRadius: _corners(
            mine: mine,
            radius: KMessagePreview.radius,
            tail: KMessagePreview.tailRadius,
          ),
        ),
        child: Text(
          message.text,
          style: context.textStyles.body.copyWith(
            fontSize: KMessagePreview.textSize,
            height: KMessagePreview.textHeight,
            color: mine ? p.onPrimary : p.textPrimary,
          ),
        ),
      ),
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
    final reaction = message.reaction;
    if (reaction == null) return body;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        body,
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
                color: p.surfaceOverlay,
                borderRadius: BorderRadius.circular(
                  KMessagePreview.reaction.height,
                ),
              ),
              child: Text(reaction, style: const TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ],
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

class _Composer extends StatelessWidget {
  const new({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.md,
          KSpacing.xs,
          KSpacing.xs,
          KSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: MessagesPreviewScreen.inputKey,
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: l10n.messagesPreviewHint,
                  filled: true,
                  fillColor: p.surfaceOverlay,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: KSpacing.md,
                    vertical: KSpacing.sm,
                  ),
                  // No outline at rest (the theme's enabled border
                  // would add one); its focus border shows while typing.
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            IconButton(
              key: MessagesPreviewScreen.sendKey,
              tooltip: l10n.messagesPreviewSend,
              onPressed: onSend,
              // The paper plane points along the reading direction.
              icon: Transform.flip(
                flipX: Directionality.of(context) == TextDirection.rtl,
                child: AppIcon(AppIcons.send, size: 24, color: p.primary),
              ),
            ),
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
