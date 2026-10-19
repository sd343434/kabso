import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/messages/:username` (D61): a private conversation with [username],
/// opened from their profile's Message button.
///
/// There is no messaging API yet, so the screen is not connected: the
/// conversation is empty with a "start a conversation" header, the
/// composer is disabled and a notice says messages are coming. No message
/// is invented or "sent".
class ChatScreen extends StatelessWidget {
  const new({
    required this.username,
    super.key,
    this.displayName,
    this.avatarUrl,
  });

  final String username;
  final String? displayName;
  final String? avatarUrl;

  static const noticeKey = Key('chat.notice');
  static const composerKey = Key('chat.composer');
  static const sendKey = Key('chat.send');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final name = displayName ?? username;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
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
                    l10n.profileUsername(username),
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
                  l10n.profileUsername(username),
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
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.md,
                KSpacing.sm,
                KSpacing.md,
                KSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: composerKey,
                      // No messaging API yet (D61).
                      enabled: false,
                      decoration: InputDecoration(
                        hintText: l10n.messagesPreviewHint,
                        filled: true,
                        fillColor: p.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(KRadius.pill),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: KSpacing.lg,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: sendKey,
                    tooltip: l10n.messagesPreviewSend,
                    onPressed: null,
                    icon: AppIcon(
                      AppIcons.send,
                      size: KMetrics.iconMd,
                      color: p.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
