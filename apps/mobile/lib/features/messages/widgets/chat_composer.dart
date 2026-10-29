import 'package:kabso_live/core/format/k_format.dart';
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
/// microphone: it records a voice note when [voice] is given (D155), else it
/// is disabled and says voice messages are not available here (D165).
///
/// D138 (owner: «وأيضاً ستظهر في الرسائل الخاصة»): the emoji button opens
/// the shared [EmojiPanel] under the field (the owner's nine packs first,
/// then the Unicode groups) in the app theme, the keyboard hidden until the
/// field or the keyboard key is tapped; a tap puts the emoji — a pack emoji
/// as its token `:<pack>_<id>:` (CP-003) — at the cursor, and the bubble
/// shows it animated ([KabiEmojiText]).
///
/// With [onSend] null the whole composer is disabled.
///
/// D155: the real conversation passes [voice] (the microphone records a
/// voice note: tap to start, tap again to send, × to cancel), hides the
/// gift button unless [onGift] is given ([showGift]), and offers photos only
/// ([allowVideo] false).
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
    this.voice,
    this.showGift = true,
    this.allowVideo = true,
    this.hintText,
  });

  final TextEditingController? controller;

  /// D155: the voice note recorder's state and actions (null: the
  /// microphone stays disabled).
  final ChatVoiceControl? voice;

  /// D155: false hides the gift button when [onGift] is null.
  final bool showGift;

  /// D155: false leaves "record a video" out of the attach sheet.
  final bool allowVideo;

  /// Overrides the field's hint.
  final String? hintText;
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
                    allowVideo: widget.allowVideo,
                    onPicked: enabled && widget.voice?.recording != true
                        ? onMedia
                        : null,
                  ),
                  // D75 (owner): the gift box sits next to "+", outside the
                  // field.
                  if (widget.showGift || onGift != null)
                    SizedBox.square(
                      dimension: KChatComposer.button,
                      child: IconButton(
                        key: widget.giftKey,
                        // D165: busy for a moment is not "can't send yet".
                        tooltip: onGift != null
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
                  if (widget.voice?.recording ?? false)
                    Expanded(child: _Recording(voice: widget.voice!))
                  else
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
                          hintText: widget.hintText ?? l10n.messagesPreviewHint,
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
                    voice: widget.voice,
                    enabled: enabled,
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

/// D155: the voice note recorder as the composer shows it.
@immutable
class ChatVoiceControl {
  const new({
    required this.recording,
    required this.elapsed,
    required this.onToggle,
    required this.onCancel,
    this.busy = false,
  });

  /// A note is being recorded (the field shows the time and ×).
  final bool recording;
  final Duration elapsed;

  /// Starts recording, or stops and sends.
  final VoidCallback onToggle;
  final VoidCallback onCancel;

  /// Uploading or sending: the microphone waits.
  final bool busy;

  static const cancelKey = Key('chat.voice.cancel');
  static const recordingKey = Key('chat.voice.recording');
}

class _Recording extends StatelessWidget {
  const new({required this.voice});

  final ChatVoiceControl voice;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    return Container(
      key: ChatVoiceControl.recordingKey,
      constraints: const BoxConstraints(
        minHeight: KChatComposer.fieldMinHeight,
      ),
      padding: const EdgeInsetsDirectional.only(start: KSpacing.md),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(KRadius.pill),
        border: Border.all(color: p.primary),
      ),
      child: Row(
        children: [
          Icon(Icons.fiber_manual_record_rounded, size: 14, color: p.primary),
          const SizedBox(width: KSpacing.xs),
          Expanded(
            child: Text(
              l10n.liveVoiceRecording(KFormat.countdown(voice.elapsed)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.body.copyWith(color: p.textPrimary),
            ),
          ),
          IconButton(
            key: ChatVoiceControl.cancelKey,
            tooltip: l10n.liveVoiceCancel,
            onPressed: voice.onCancel,
            icon: Icon(Icons.close_rounded, color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SendOrMic extends StatelessWidget {
  const new({
    required this.controller,
    required this.onSend,
    required this.sendKey,
    this.voice,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final VoidCallback? onSend;
  final Key? sendKey;
  final ChatVoiceControl? voice;

  /// D165: false while the composer is busy (the microphone waits but keeps
  /// saying what it does).
  final bool enabled;

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
    final voice = this.voice;
    final recording = voice?.recording ?? false;
    final mic =
        !typed && voice != null && !voice.busy && (enabled || recording);
    final active = (typed && onSend != null && !recording) || mic;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SizedBox.square(
      dimension: KChatComposer.button,
      child: IconButton.filled(
        key: sendKey,
        tooltip: typed && !recording
            ? l10n.messagesPreviewSend
            : recording
            ? l10n.liveVoiceSend
            : voice != null
            ? l10n.liveVoiceRecord
            : l10n.chatVoiceUnavailable,
        onPressed: !active
            ? null
            : typed && !recording
            ? onSend
            : voice?.onToggle,
        style: IconButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.primary.withValues(alpha: 0.35),
          disabledForegroundColor: p.onPrimary.withValues(alpha: 0.8),
          padding: EdgeInsets.zero,
        ),
        icon: typed || recording
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
