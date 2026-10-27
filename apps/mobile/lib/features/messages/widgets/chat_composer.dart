import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/emoji/emoji_panel.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/messages/attachments.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Composer geometry (D68, layout after the owner's chat reference;
/// colours are Kabso's).
abstract final class KChatComposer {
  static const double button = 44;
  static const double fieldMinHeight = 44;
  static const double icon = 22;
}

/// The message composer of a conversation (D68): a round "+" to attach a
/// photo or video, a pill field with the emoji button inside, and a round
/// red button that sends once something is typed. Empty, it shows a
/// microphone that is disabled: voice messages need an API (CP-004).
///
/// D138 (owner: «وأيضاً ستظهر في الرسائل الخاصة»): the emoji button opens
/// the shared [EmojiPanel] under the field (the owner's nine packs first,
/// then the Unicode groups) in the app theme, the keyboard hidden until the
/// field or the keyboard key is tapped; a tap puts the emoji — a pack emoji
/// as its token `:<pack>_<id>:` (CP-003) — at the cursor, and the bubble
/// shows it animated ([KabiEmojiText]).
///
/// With [onSend] null the whole composer is disabled (the real chat until
/// a messaging API exists).
class ChatComposer extends StatefulWidget {
  const new({
    super.key,
    this.controller,
    this.onSend,
    this.onMedia,
    this.onGift,
    this.inputKey,
    this.sendKey,
    this.emojiKey,
    this.attachKey,
    this.giftKey,
  });

  final TextEditingController? controller;
  final VoidCallback? onSend;
  final ValueChanged<PickedMedia>? onMedia;

  /// Opens the gift box (D69); null disables the gift button.
  final VoidCallback? onGift;
  final Key? inputKey;
  final Key? sendKey;
  final Key? emojiKey;
  final Key? attachKey;
  final Key? giftKey;

  /// D138: the emoji panel under the field.
  static const emojiPanelKey = Key('chat.emojiPanel');

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _focus = FocusNode();
  var _emoji = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_focusChanged)
      ..dispose();
    super.dispose();
  }

  /// The keyboard came up (the field was tapped): the panel goes.
  void _focusChanged() {
    if (_focus.hasFocus && _emoji) setState(() => _emoji = false);
  }

  void _toggleEmoji() {
    if (_emoji) {
      setState(() => _emoji = false);
      _focus.requestFocus();
    } else {
      _focus.unfocus();
      setState(() => _emoji = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final controller = widget.controller;
    final onSend = widget.onSend;
    final onMedia = widget.onMedia;
    final onGift = widget.onGift;
    final enabled = onSend != null;
    final emojiEnabled = enabled && controller != null;
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(KRadius.pill),
      borderSide: BorderSide(color: p.border),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.background,
        // D69: the composer floats over the thread.
        boxShadow: [
          BoxShadow(
            color: p.textPrimary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.sm,
                KSpacing.sm,
                KSpacing.sm,
                KSpacing.sm,
              ),
              child: Row(
                children: [
                  AttachmentButton(
                    key: widget.attachKey,
                    outlined: true,
                    onPicked: enabled ? onMedia : null,
                  ),
                  // D75 (owner): the gift box sits next to "+", outside the
                  // field.
                  SizedBox.square(
                    dimension: KChatComposer.button,
                    child: IconButton(
                      key: widget.giftKey,
                      tooltip: enabled && onGift != null
                          ? l10n.chatGiftButton
                          : l10n.giftSendComingSoon,
                      onPressed: enabled ? onGift : null,
                      padding: EdgeInsets.zero,
                      icon: KabsoArtIcon(
                        KabsoArt.giftBox,
                        size: KChatComposer.button - 10,
                        dimmed: !enabled || onGift == null,
                      ),
                    ),
                  ),
                  const SizedBox(width: KSpacing.xs),
                  Expanded(
                    child: TextField(
                      key: widget.inputKey,
                      controller: controller,
                      focusNode: _focus,
                      enabled: enabled,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend?.call(),
                      style: context.textStyles.body,
                      decoration: InputDecoration(
                        hintText: l10n.messagesPreviewHint,
                        hintMaxLines: 1,
                        filled: true,
                        fillColor: p.surface,
                        isDense: true,
                        constraints: const BoxConstraints(
                          minHeight: KChatComposer.fieldMinHeight,
                        ),
                        contentPadding: const EdgeInsetsDirectional.fromSTEB(
                          KSpacing.md,
                          KSpacing.sm + 2,
                          KSpacing.xs,
                          KSpacing.sm + 2,
                        ),
                        border: pill,
                        enabledBorder: pill,
                        disabledBorder: pill,
                        focusedBorder: pill.copyWith(
                          borderSide: BorderSide(
                            color: p.focusRing,
                            width: 1.5,
                          ),
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: widget.emojiKey,
                              tooltip: _emoji
                                  ? l10n.liveEmojiKeyboard
                                  : l10n.kabiEmojiButton,
                              onPressed: emojiEnabled ? _toggleEmoji : null,
                              icon: _emoji
                                  ? Icon(
                                      Icons.keyboard_rounded,
                                      size: KChatComposer.icon,
                                      color: p.textSecondary,
                                    )
                                  : AppIcon(
                                      AppIcons.emoji,
                                      size: KChatComposer.icon,
                                      color: emojiEnabled
                                          ? p.textSecondary
                                          : p.textTertiary,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: KSpacing.xs),
                  _SendOrMic(
                    controller: controller,
                    onSend: onSend,
                    sendKey: widget.sendKey,
                  ),
                ],
              ),
            ),
            if (_emoji && controller != null)
              EmojiPanel(
                key: ChatComposer.emojiPanelKey,
                colors: EmojiPanelColors.of(context),
                onEmoji: (e) => insertEmojiText(controller, e),
              ),
          ],
        ),
      ),
    );
  }
}

class _SendOrMic extends StatelessWidget {
  const new({
    required this.controller,
    required this.onSend,
    required this.sendKey,
  });

  final TextEditingController? controller;
  final VoidCallback? onSend;
  final Key? sendKey;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) return _button(context, typed: false);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) =>
          _button(context, typed: value.text.trim().isNotEmpty),
    );
  }

  Widget _button(BuildContext context, {required bool typed}) {
    final p = context.palette;
    final l10n = context.l10n;
    final active = typed && onSend != null;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SizedBox.square(
      dimension: KChatComposer.button,
      child: IconButton.filled(
        key: sendKey,
        tooltip: typed ? l10n.messagesPreviewSend : l10n.chatVoiceSoon,
        onPressed: active ? onSend : null,
        style: IconButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.primary.withValues(alpha: 0.35),
          disabledForegroundColor: p.onPrimary.withValues(alpha: 0.8),
          padding: EdgeInsets.zero,
        ),
        icon: typed
            // The paper plane points along the reading direction.
            ? Transform.flip(
                flipX: rtl,
                child: AppIcon(
                  AppIcons.send,
                  size: KChatComposer.icon,
                  color: p.onPrimary,
                ),
              )
            : const Icon(Icons.mic_none_rounded, size: KChatComposer.icon),
      ),
    );
  }
}
