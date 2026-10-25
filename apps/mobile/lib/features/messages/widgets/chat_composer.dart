import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/design_system/design_system.dart';
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
/// photo or video, a pill field with the Kabi emoji button inside, and a
/// round red button that sends once something is typed. Empty, it shows a
/// microphone that is disabled: voice messages need an API (CP-004).
///
/// With [onSend] null the whole composer is disabled (the real chat until
/// a messaging API exists).
class ChatComposer extends StatelessWidget {
  const new({
    super.key,
    this.controller,
    this.onSend,
    this.onEmoji,
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
  final ValueChanged<KabsoEmoji>? onEmoji;
  final ValueChanged<PickedMedia>? onMedia;

  /// Opens the gift box (D69); null disables the gift button.
  final VoidCallback? onGift;
  final Key? inputKey;
  final Key? sendKey;
  final Key? emojiKey;
  final Key? attachKey;
  final Key? giftKey;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final enabled = onSend != null;
    final onEmoji = this.onEmoji;
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.sm,
            KSpacing.sm,
            KSpacing.sm,
            KSpacing.sm,
          ),
          child: Row(
            children: [
              AttachmentButton(
                key: attachKey,
                outlined: true,
                onPicked: enabled ? onMedia : null,
              ),
              // D75 (owner): the gift box sits next to "+", outside the
              // field.
              SizedBox.square(
                dimension: KChatComposer.button,
                child: IconButton(
                  key: giftKey,
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
                  key: inputKey,
                  controller: controller,
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
                      borderSide: BorderSide(color: p.focusRing, width: 1.5),
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: emojiKey,
                          tooltip: l10n.kabiEmojiButton,
                          onPressed: !enabled || onEmoji == null
                              ? null
                              : () async {
                                  final emoji = await showKabiEmojiPicker(
                                    context,
                                  );
                                  if (emoji != null) onEmoji(emoji);
                                },
                          icon: AppIcon(
                            AppIcons.emoji,
                            size: KChatComposer.icon,
                            color: enabled ? p.textSecondary : p.textTertiary,
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
                sendKey: sendKey,
              ),
            ],
          ),
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
