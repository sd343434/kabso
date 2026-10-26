import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_media.dart';
import 'package:kabso_live/features/posts/presentation/report_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The caller's role in the room, for what a chat line offers.
enum LiveChatViewerRole { host, moderator, member, guest }

/// The room chat (CP-013): the newest lines at the bottom of a bounded box
/// at the start side. Tapping a message opens its actions; a line that
/// failed to send offers a retry.
class LiveRoomChatLines extends ConsumerWidget {
  const new({
    required this.roomId,
    required this.role,
    required this.onProfile,
    super.key,
    this.bubble = KAudioRoom.bubble,
  });

  final String roomId;
  final LiveChatViewerRole role;

  /// Opens a user's profile card.
  final void Function(String username) onProfile;

  /// The bubble colour (the audio room's purple, or the video scrim).
  final Color bubble;

  static const listKey = Key('liveChat.lines');

  /// Lines on screen at once (the newest).
  static const maxVisibleLines = 8;
  static Key lineKey(String key) => Key('liveChat.line.$key');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final chat = ref.watch(liveChatProvider(roomId));
    final items = chat.items;
    final maxHeight = math
        .min(240, MediaQuery.sizeOf(context).height * 0.3)
        .toDouble();
    if (items.isEmpty) {
      return chat.loaded
          ? _Bubble(color: bubble, child: _plain(context, l10n.liveChatEmpty))
          : const SizedBox.shrink();
    }
    // The newest lines that fit; older ones fade out at the top. Not a
    // lazy list: the audio room measures the chat's height.
    final visible = items.length > maxVisibleLines
        ? items.sublist(items.length - maxVisibleLines)
        : items;
    return ConstrainedBox(
      key: listKey,
      constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 300),
      child: ClipRect(
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00000000), Color(0xFF000000)],
            stops: [0, 0.18],
          ).createShader(bounds),
          child: Semantics(
            container: true,
            liveRegion: true,
            child: OverflowBox(
              alignment: AlignmentDirectional.bottomStart,
              minHeight: 0,
              maxHeight: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in visible)
                    Padding(
                      key: lineKey(item.key),
                      padding: const EdgeInsets.only(top: 4),
                      child: _line(context, ref, item),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(BuildContext context, WidgetRef ref, LiveChatItem item) {
    final l10n = context.l10n;
    return switch (item) {
      // CP-017: a voice clip or a picture (the controller drops them at
      // `expiresAt` and when the media is gone).
      LiveChatPosted(:final entry)
          when entry.kind != LiveChatKind.text && entry.media != null =>
        _mediaLine(context, ref, entry, entry.media!),
      LiveChatPosted(:final entry) => _Tappable(
        label: l10n.liveChatLineLabel(
          entry.author.displayName,
          kabiSpokenText(entry.text, l10n),
        ),
        onTap: () => unawaited(
          showLiveChatActions(
            context,
            ref,
            roomId: roomId,
            entry: entry,
            role: role,
            onProfile: onProfile,
          ),
        ),
        child: _Bubble(
          color: bubble,
          child: _message(
            context,
            entry.author.displayName,
            entry.text,
            entry.authorRole,
          ),
        ),
      ),
      LiveChatPending(:final failed, :final text, :final authorName) =>
        _Tappable(
          label: [
            l10n.liveChatLineLabel(authorName, kabiSpokenText(text, l10n)),
            if (failed) l10n.liveChatFailed,
          ].join('. '),
          onTap: failed
              ? () => unawaited(_failedActions(context, ref, item))
              : null,
          child: Opacity(
            opacity: failed ? 1 : 0.6,
            child: _Bubble(
              color: bubble,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _message(context, authorName, text, null),
                  if (failed)
                    Text(
                      l10n.liveChatFailed,
                      style: context.textStyles.caption.copyWith(
                        color: const Color(0xFFFF8A9A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      LiveChatJoinLine(:final user) => Opacity(
        opacity: 0.85,
        child: _Bubble(
          color: bubble,
          child: _plain(
            context,
            l10n.chatJoined(KFormat.bidiIsolate(user.displayName)),
          ),
        ),
      ),
    };
  }

  Widget _mediaLine(
    BuildContext context,
    WidgetRef ref,
    LiveChatEntry entry,
    LiveChatMedia media,
  ) {
    final l10n = context.l10n;
    final name = entry.author.displayName;
    final voice = entry.kind == LiveChatKind.voice;
    return _Bubble(
      color: bubble,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The name opens the message's actions, like a text line.
          _Tappable(
            label: voice
                ? l10n.liveChatVoiceLine(
                    name,
                    KFormat.countdown(
                      Duration(milliseconds: media.durationMs ?? 0),
                    ),
                  )
                : l10n.liveChatPictureLine(name),
            onTap: () => unawaited(
              showLiveChatActions(
                context,
                ref,
                roomId: roomId,
                entry: entry,
                role: role,
                onProfile: onProfile,
              ),
            ),
            child: _message(context, name, '', entry.authorRole),
          ),
          const SizedBox(height: 4),
          if (voice)
            LiveVoiceClipPill(key: ValueKey(media.id), media: media)
          else
            LiveChatPictureThumb(media: media),
        ],
      ),
    );
  }

  Widget _plain(BuildContext context, String text) => Text(
    text,
    style: context.textStyles.caption.copyWith(
      fontSize: 12.5,
      color: KAudioRoom.text,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _message(
    BuildContext context,
    String name,
    String text,
    LiveChatRole? authorRole,
  ) {
    final l10n = context.l10n;
    final styles = context.textStyles;
    final badge = switch (authorRole) {
      LiveChatRole.host => l10n.liveChatHostBadge,
      LiveChatRole.moderator => l10n.liveChatModeratorBadge,
      _ => null,
    };
    return Text.rich(
      TextSpan(
        children: [
          if (badge != null) ...[
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: authorRole == LiveChatRole.host
                      ? KAudioRoom.hostTag
                      : const Color(0xFFFFB13B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: styles.caption.copyWith(
                    fontSize: 10,
                    color: const Color(0xFF14123A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const TextSpan(text: ' '),
          ],
          TextSpan(
            text: KFormat.bidiIsolate(name),
            style: styles.caption.copyWith(
              fontSize: 12.5,
              color: const Color(0xFFBFD8FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          // Kabi emoji tokens (D66) show as the animated emoji, inline.
          TextSpan(
            style: styles.caption.copyWith(
              fontSize: 12.5,
              color: KAudioRoom.text,
              fontWeight: FontWeight.w600,
            ),
            children: [
              const TextSpan(text: '  \u2068'),
              ...kabiInlineSpans(text, size: 12.5 * KKabiEmoji.inlineScale),
              const TextSpan(text: '\u2069'),
            ],
          ),
        ],
      ),
      textScaler: MediaQuery.textScalerOf(context)
          .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
    );
  }

  Future<void> _failedActions(
    BuildContext context,
    WidgetRef ref,
    LiveChatPending line,
  ) async {
    final l10n = context.l10n;
    final chat = ref.read(liveChatProvider(roomId).notifier);
    final choice = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('liveChat.retry'),
              leading: const Icon(Icons.refresh_rounded),
              title: Text(l10n.liveChatRetry),
              onTap: () => Navigator.of(sheet).pop(true),
            ),
            ListTile(
              key: const Key('liveChat.discard'),
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(l10n.liveChatDiscard),
              onTap: () => Navigator.of(sheet).pop(false),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (!choice) {
      chat.discard(line);
      return;
    }
    final failure = await chat.retry(line);
    if (failure != null && context.mounted) {
      KSnack.error(context, failureMessage(l10n, failure));
    }
  }
}

class _Bubble extends StatelessWidget {
  const new({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
    ),
    child: child,
  );
}

class _Tappable extends StatelessWidget {
  const new({required this.label, required this.child, this.onTap});

  final String label;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    ),
  );
}

/// What a chat message offers to the caller ([role]): the author's profile,
/// delete (the author, the host, a moderator — not on the host's or another
/// moderator's), mute in chat (the host and moderators, same limits), and
/// report (anyone signed in but the author). The server has the last word.
Future<void> showLiveChatActions(
  BuildContext context,
  WidgetRef ref, {
  required String roomId,
  required LiveChatEntry entry,
  required LiveChatViewerRole role,
  required void Function(String username) onProfile,
}) async {
  final l10n = context.l10n;
  final me = ref.read(currentUserProvider);
  final mine = me != null && entry.author.id == me.id;
  final protected =
      entry.authorRole == LiveChatRole.host ||
      (role == LiveChatViewerRole.moderator &&
          entry.authorRole == LiveChatRole.moderator);
  final moderates =
      role == LiveChatViewerRole.host || role == LiveChatViewerRole.moderator;
  final canDelete = mine || (moderates && !protected);
  final canMute = moderates && !mine && !protected;
  final canReport = me != null && !mine;
  final chat = ref.read(liveChatProvider(roomId).notifier);
  final name = entry.author.displayName;
  final handle = '@${entry.author.username}';

  // Whether the author is muted now (only the host and moderators ask).
  var muted = false;
  if (canMute) {
    try {
      final mutes = await ref.read(liveChatProvider(roomId).notifier).mutes();
      muted = mutes.any((m) => m.user.id == entry.author.id);
    } on Object {
      // Offer muting; the server answers either way (idempotent).
    }
    if (!context.mounted) return;
  }

  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              KFormat.bidiIsolate(switch (entry.kind) {
                LiveChatKind.voice => l10n.liveVoiceRecord,
                LiveChatKind.image => l10n.liveChatPicture,
                LiveChatKind.text => kabiSpokenText(entry.text, l10n),
              }),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(handle),
          ),
          ListTile(
            key: const Key('liveChat.action.profile'),
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(l10n.liveChatViewProfile),
            onTap: () => Navigator.of(sheet).pop('profile'),
          ),
          if (canDelete)
            ListTile(
              key: const Key('liveChat.action.delete'),
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(l10n.liveChatDelete),
              onTap: () => Navigator.of(sheet).pop('delete'),
            ),
          if (canMute)
            ListTile(
              key: const Key('liveChat.action.mute'),
              leading: Icon(
                muted ? Icons.chat_bubble_outline : Icons.speaker_notes_off,
              ),
              title: Text(
                muted
                    ? l10n.liveChatUnmuteUser(KFormat.bidiIsolate(name))
                    : l10n.liveChatMuteUser(KFormat.bidiIsolate(name)),
              ),
              onTap: () => Navigator.of(sheet).pop(muted ? 'unmute' : 'mute'),
            ),
          if (canReport)
            ListTile(
              key: const Key('liveChat.action.report'),
              leading: const Icon(Icons.flag_outlined),
              title: Text(l10n.liveChatReport),
              onTap: () => Navigator.of(sheet).pop('report'),
            ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  try {
    switch (action) {
      case 'profile':
        onProfile(entry.author.username);
      case 'delete':
        await chat.delete(entry);
        if (context.mounted) KSnack.success(context, l10n.liveChatDeleted);
      case 'mute' || 'unmute':
        await chat.setMuted(entry.author.username, muted: action == 'mute');
        if (context.mounted) {
          KSnack.success(
            context,
            action == 'mute'
                ? l10n.liveChatUserMuted(KFormat.bidiIsolate(name))
                : l10n.liveChatUserUnmuted(KFormat.bidiIsolate(name)),
          );
        }
      case 'report':
        final reason = await pickReportReason(
          context,
          l10n.liveChatReportTitle,
        );
        if (reason == null) return;
        await chat.report(entry, reason);
        if (context.mounted) KSnack.success(context, l10n.feedPostReported);
    }
  } on Object catch (e) {
    if (context.mounted) {
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
  }
}

/// The composer's state for the caller: who may write and, if not, why.
({bool canWrite, String hint}) liveChatComposerHint(
  AppLocalizations l10n, {
  required LiveChatState chat,
  required LiveChatViewerRole role,
}) {
  if (role == LiveChatViewerRole.guest) {
    return (canWrite: false, hint: l10n.liveChatSignIn);
  }
  // Chat off says more than a mute (and outlives it).
  if (!chat.enabled && role != LiveChatViewerRole.host) {
    return (canWrite: false, hint: l10n.liveChatOff);
  }
  if (chat.muted) return (canWrite: false, hint: l10n.liveChatMutedPill);
  return (canWrite: true, hint: l10n.goLiveChatPill);
}

/// Sends the composer's text; the field empties at once (the line shows
/// as sending). A refusal is said in a snack.
Future<void> sendLiveChatFrom(
  BuildContext context,
  WidgetRef ref, {
  required String roomId,
  required TextEditingController field,
}) async {
  final text = field.text;
  if (text.trim().isEmpty) return;
  field.clear();
  await sendLiveChatText(context, ref, roomId: roomId, text: text);
}

/// Sends [text] (e.g. a Kabi emoji's token); a refusal shows as a snack.
Future<void> sendLiveChatText(
  BuildContext context,
  WidgetRef ref, {
  required String roomId,
  required String text,
}) async {
  final l10n = context.l10n;
  final failure = await ref.read(liveChatProvider(roomId).notifier).send(text);
  if (failure != null && context.mounted) {
    KSnack.error(context, failureMessage(l10n, failure));
  }
}
