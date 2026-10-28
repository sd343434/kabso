import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/messages/widgets/chat_composer.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/messages/:username` (D61): a private conversation with [username],
/// opened from their profile's Message button.
///
/// There is no messaging API yet, so the screen is not connected: the
/// conversation is empty with a "start a conversation" header, the
/// composer is disabled and a notice says messages are coming. No message
/// is invented or "sent".
///
/// D158: a push may hand the peer's display name and premium tier as
/// [ChatPeer] in `extra` (or the display name alone as a `String`); a
/// premium username shows without «@».
class ChatScreen extends StatelessWidget {
  const new({
    required this.username,
    super.key,
    this.displayName,
    this.avatarUrl,
    this.premiumTier,
  });

  final String username;
  final String? displayName;
  final String? avatarUrl;

  /// The peer's premium username tier (D146), or null for a regular one.
  final PremiumTier? premiumTier;

  static const noticeKey = Key('chat.notice');
  static const composerKey = Key('chat.composer');
  static const emojiKey = Key('chat.emoji');
  static const attachKey = Key('chat.attach');
  static const sendKey = Key('chat.send');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final name = displayName ?? username;
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        titleSpacing: 0,
        title: Row(
          children: [
            KAvatar(name: name, imageUrl: avatarUrl, size: KSizes.avatarSm),
            const SizedBox(width: KSpacing.sm),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyStrong.copyWith(color: p.textPrimary),
                  ),
                  Text(
                    KHandle.text(l10n, username, premiumTier: premiumTier),
                    maxLines: 1,
                    textDirection: TextDirection.ltr,
                    style: t.caption.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(KSpacing.xl),
              children: [
                const SizedBox(height: KSpacing.xl),
                Center(
                  child: KAvatar(
                    name: name,
                    imageUrl: avatarUrl,
                    size: KSizes.avatarLg,
                  ),
                ),
                const SizedBox(height: KSpacing.md),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: t.title.copyWith(color: p.textPrimary),
                ),
                Text(
                  KHandle.text(l10n, username, premiumTier: premiumTier),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  style: t.body.copyWith(color: p.textSecondary),
                ),
                const SizedBox(height: KSpacing.xl),
                Container(
                  key: noticeKey,
                  padding: const EdgeInsets.all(KSpacing.md),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(KRadius.md),
                    border: Border.all(color: p.border),
                  ),
                  child: Text(
                    l10n.chatUnavailable,
                    textAlign: TextAlign.center,
                    style: t.body.copyWith(color: p.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          // D68: the shared composer, disabled until a messaging API
          // exists (D61); attachments (D67, CP-004) and Kabi emojis (D66,
          // CP-003) with it.
          const ChatComposer(
            inputKey: composerKey,
            sendKey: sendKey,
            emojiKey: emojiKey,
            attachKey: attachKey,
          ),
        ],
      ),
    );
  }
}

/// D158: the `extra` of a push to `/messages/:username`: the peer's display
/// name and premium username tier, so the handle shows right at once.
typedef ChatPeer = ({String? displayName, PremiumTier? premiumTier});
