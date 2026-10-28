import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/data/live_voice_recorder.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/messages/application/dm_providers.dart';
import 'package:kabso_live/features/messages/attachments.dart';
import 'package:kabso_live/features/messages/data/dm_repository.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/messages/widgets/chat_composer.dart';
import 'package:kabso_live/features/messages/widgets/dm_message_view.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/posts/presentation/report_sheet.dart';
import 'package:kabso_live/features/push/open_conversation.dart';
import 'package:kabso_live/features/push/push_payload.dart';
import 'package:kabso_live/features/push/push_permission.dart';
import 'package:kabso_live/features/safety/safety_actions.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D158: the `extra` of a push to `/messages/:username`: the peer's display
/// name and premium username tier, so the handle shows right at once.
typedef ChatPeer = ({String? displayName, PremiumTier? premiumTier});

/// `/messages/:username` (D61; D155: a real conversation). Opened from the
/// list, the person's profile, the person card in a live, or a push.
///
/// - The messages, newest at the bottom, each with its time and ✓ / ✓✓;
///   a long press deletes (for me; one's own for everyone within an hour)
///   or reports. A line says messages are deleted after 24 hours.
/// - A message request from a stranger shows Accept / Delete / Block; one
///   the caller sent says how many messages are left until a reply.
/// - The composer sends text and pack emojis, pictures (`DM_IMAGE`), voice
///   notes (`DM_VOICE`, up to 30 s) and gifts (the gift panel, coins spent
///   even in a request — the caller is told first).
/// - Real time: the newest page is read every few seconds while the screen
///   is open (3 s, slowing to 15 s while quiet; paused in the background)
///   and at once on a `dm` push; no push sound plays for this conversation.
class ChatScreen extends ConsumerStatefulWidget {
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

  /// The longest voice note (the CP-017 pipeline, §11.1).
  static const maxVoice = Duration(seconds: 30);

  static const noticeKey = Key('chat.notice');
  static const composerKey = Key('chat.composer');
  static const emojiKey = Key('chat.emoji');
  static const attachKey = Key('chat.attach');
  static const sendKey = Key('chat.send');
  static const giftKey = Key('chat.gift');
  static const menuKey = Key('chat.menu');
  static const muteKey = Key('chat.menu.mute');
  static const deleteConversationKey = Key('chat.menu.delete');
  static const reportPersonKey = Key('chat.menu.report');
  static const blockKey = Key('chat.menu.block');
  static const requestBannerKey = Key('chat.request');
  static const acceptKey = Key('chat.request.accept');
  static const declineKey = Key('chat.request.decline');
  static const requestBlockKey = Key('chat.request.block');
  static const requestLeftKey = Key('chat.request.left');
  static const cannotSendKey = Key('chat.cannotSend');
  static const emptyKey = Key('chat.empty');
  static const unavailableKey = Key('chat.unavailable');
  static const deleteForMeKey = Key('chat.message.deleteForMe');
  static const deleteForEveryoneKey = Key('chat.message.deleteForEveryone');
  static const reportMessageKey = Key('chat.message.report');
  static const confirmDeleteKey = Key('chat.delete.confirm');
  static const giftRequestContinueKey = Key('chat.gift.requestContinue');

  /// The polling (tests replace it).
  @visibleForTesting
  static DmPollBackoff Function() newBackoff = DmPollBackoff.new;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  late final DmPollBackoff _backoff = ChatScreen.newBackoff();
  late final OpenConversation _open;
  late final AppLifecycleListener _lifecycle;
  late final LiveVoiceRecorder _recorder;
  Timer? _poll;
  bool _foreground = true;
  bool _sending = false;
  String? _conversation;
  String? _readUpTo;

  bool _recording = false;
  bool _voiceBusy = false;
  Duration _elapsed = Duration.zero;
  Timer? _tick;

  String get username => widget.username;

  @override
  void initState() {
    super.initState();
    _open = ref.read(openConversationProvider.notifier);
    _recorder = ref.read(liveVoiceRecorderProvider)();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _foreground = true;
        _backoff.reset();
        _schedule();
      },
      onPause: () {
        _foreground = false;
        _poll?.cancel();
      },
    );
    _schedule();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // D152: a conversation is a moment to explain notifications (once).
      unawaited(maybeAskPushPermission(context, ref));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    _lifecycle.dispose();
    _input.dispose();
    final open = _conversation;
    if (open != null) _open.closed(open);
    unawaited(_recorder.dispose().then<void>((_) {}, onError: (Object _) {}));
    super.dispose();
  }

  // ---- Real time ----------------------------------------------------------

  void _schedule() {
    _poll?.cancel();
    if (!_foreground) return;
    _poll = Timer(_backoff.next, () async {
      if (!mounted) return;
      var changed = false;
      try {
        changed = await ref.read(dmChatProvider(username).notifier).refresh();
      } on Object {
        // Offline for a moment: try again later.
      }
      if (!mounted) return;
      _backoff.after(changed: changed);
      _schedule();
    });
  }

  void _nudge() {
    _backoff.reset();
    _schedule();
  }

  /// After every new state: report the open conversation (no push sound for
  /// it) and mark what arrived as read (not in a request: the sender is not
  /// told before the caller accepts).
  void _onState(DmChatState s) {
    final id = s.conversation?.id;
    if (id != null && _conversation != id) {
      final before = _conversation;
      if (before != null) _open.closed(before);
      _conversation = dmConversation(id);
      _open.opened(_conversation!);
    }
    final newest = s.messages.where((m) => !m.mine).firstOrNull;
    final status = s.conversation?.status;
    if (newest != null &&
        newest.id != _readUpTo &&
        status != DmConversationStatus.requestReceived) {
      _readUpTo = newest.id;
      unawaited(() async {
        final told = await ref
            .read(dmChatProvider(username).notifier)
            .markRead();
        if (told && mounted) {
          unawaited(ref.read(dmUnreadProvider.notifier).refresh());
        }
      }());
    }
  }

  // ---- Sending ------------------------------------------------------------

  Future<void> _sendText() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    // A pack emoji alone goes as an EMOJI message (big, no bubble).
    final emojis = KabiEmojiText.onlyEmojis(text);
    final outgoing = emojis != null && emojis.length == 1
        ? DmOutgoingEmoji(emojis.single.token)
        : DmOutgoingText(text);
    final ok = await _send(outgoing, key: 'text:$text');
    if (ok && mounted) _input.clear();
  }

  Future<bool> _send(DmOutgoing outgoing, {required String key}) async {
    final l10n = context.l10n;
    setState(() => _sending = true);
    try {
      await ref
          .read(dmChatProvider(username).notifier)
          .send(outgoing, key: key);
      _nudge();
      return true;
    } on Object catch (e) {
      final failure = toAppFailure(e);
      if (mounted) {
        KSnack.error(context, failureMessage(l10n, failure));
        // The rules may have changed (privacy, request limit): read again.
        if (failure is ServerFailure) {
          unawaited(ref.read(dmChatProvider(username).notifier).refresh());
        }
      }
      return false;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendPicture(PickedMedia media) async {
    final l10n = context.l10n;
    if (media.isVideo) {
      KSnack.error(context, l10n.dmVideoNotSupported);
      return;
    }
    setState(() => _sending = true);
    try {
      final bytes = await XFile(media.path).readAsBytes();
      final type = sniffImageType(bytes);
      if (type == null) {
        if (mounted) KSnack.error(context, l10n.dmPhotoUnsupported);
        return;
      }
      final id = await ref
          .read(mediaRepositoryProvider)
          .uploadDmMedia(bytes, type, voice: false);
      if (!mounted) return;
      setState(() => _sending = false);
      await _send(DmOutgoingMedia(id, voice: false), key: 'media:$id');
    } on Object catch (e) {
      if (mounted) KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleVoice() async {
    final l10n = context.l10n;
    if (_recording) {
      await _stopVoice(send: true);
      return;
    }
    if (_voiceBusy) return;
    setState(() => _voiceBusy = true);
    try {
      await _recorder.start();
      if (!mounted) return;
      setState(() {
        _recording = true;
        _elapsed = Duration.zero;
      });
      _tick = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _elapsed += const Duration(seconds: 1));
        if (_elapsed >= ChatScreen.maxVoice) {
          unawaited(_stopVoice(send: true));
        }
      });
    } on LiveVoiceException catch (e) {
      if (mounted) {
        KSnack.error(
          context,
          e.problem == LiveVoiceProblem.denied
              ? l10n.liveVoiceDenied
              : l10n.liveVoiceUnavailable,
        );
      }
    } finally {
      if (mounted) setState(() => _voiceBusy = false);
    }
  }

  Future<void> _stopVoice({required bool send}) async {
    _tick?.cancel();
    _tick = null;
    if (!_recording) return;
    final l10n = context.l10n;
    setState(() {
      _recording = false;
      _voiceBusy = send;
    });
    try {
      if (!send) {
        await _recorder.cancel();
        return;
      }
      final clip = await _recorder.stop();
      if (!mounted || clip == null) return;
      if (clip.silent) {
        KSnack.error(context, l10n.liveVoiceSilent);
        return;
      }
      if (clip.bytes.length > maxVoiceBytes) {
        KSnack.error(context, l10n.liveVoiceTooLarge);
        return;
      }
      final id = await ref
          .read(mediaRepositoryProvider)
          .uploadDmMedia(clip.bytes, 'audio/mp4', voice: true);
      if (!mounted) return;
      await _send(DmOutgoingMedia(id, voice: true), key: 'voice:$id');
    } on Object catch (e) {
      if (mounted) KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    } finally {
      if (mounted) setState(() => _voiceBusy = false);
    }
  }

  Future<void> _openGifts(DmChatState s) async {
    final l10n = context.l10n;
    // A stranger's gift is a request message: the coins are spent anyway.
    if (s.peer.asRequest ||
        s.conversation?.status == DmConversationStatus.requestSent) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(l10n.dmGiftRequestTitle),
          content: Text(
            l10n.dmGiftRequestBody(
              KFormat.bidiIsolate(s.peer.user.displayName),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: Text(l10n.actionCancel),
            ),
            TextButton(
              key: ChatScreen.giftRequestContinueKey,
              onPressed: () => Navigator.of(dialog).pop(true),
              child: Text(l10n.dmGiftContinue),
            ),
          ],
        ),
      );
      if (!(ok ?? false) || !mounted) return;
    }
    final repo = ref.read(dmRepositoryProvider);
    final chat = ref.read(dmChatProvider(username).notifier);
    await KLiveGiftSheet.show(
      context,
      room: LiveGiftRoom.conversation(
        peer: s.peer.user,
        send:
            ({
              required giftCode,
              required quantity,
              required source,
              required clientId,
            }) async {
              final result = await repo.sendGift(
                username,
                giftCode: giftCode,
                quantity: quantity,
                source: source,
                clientId: clientId,
              );
              chat.giftSent(result);
              _nudge();
              return (
                coins: result.coins ?? 0,
                bagQuantity: result.bagQuantity ?? 0,
                lucky: result.luckyResult,
              );
            },
      ),
    );
  }

  // ---- Actions ------------------------------------------------------------

  Future<void> _messageActions(DmMessage m) async {
    final l10n = context.l10n;
    final withinHour =
        DateTime.now().difference(m.createdAt) < const Duration(hours: 1);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: ChatScreen.deleteForMeKey,
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.dmDeleteForMe),
              onTap: () => Navigator.of(sheet).pop('me'),
            ),
            if (m.mine && withinHour)
              ListTile(
                key: ChatScreen.deleteForEveryoneKey,
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: sheet.palette.error,
                ),
                title: Text(l10n.dmDeleteForEveryone),
                onTap: () => Navigator.of(sheet).pop('everyone'),
              ),
            if (!m.mine)
              ListTile(
                key: ChatScreen.reportMessageKey,
                leading: const Icon(Icons.flag_outlined),
                title: Text(l10n.dmReportMessage),
                onTap: () => Navigator.of(sheet).pop('report'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    try {
      if (action == 'report') {
        final reason = await pickReportReason(context, l10n.dmReportMessage);
        if (reason == null || !mounted) return;
        await ref.read(dmRepositoryProvider).reportMessage(m.id, reason);
        if (mounted) KSnack.success(context, l10n.dmReported);
        return;
      }
      await ref
          .read(dmChatProvider(username).notifier)
          .deleteMessage(m.id, forEveryone: action == 'everyone');
    } on Object catch (e) {
      if (mounted) KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    final l10n = context.l10n;
    try {
      await action();
      if (done != null && mounted) KSnack.success(context, done);
    } on Object catch (e) {
      if (mounted) KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
  }

  Future<void> _deleteConversation() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.dmDeleteConversationTitle),
        content: Text(l10n.dmDeleteConversationBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            key: ChatScreen.confirmDeleteKey,
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(
              l10n.dmDecline,
              style: TextStyle(color: dialog.palette.error),
            ),
          ),
        ],
      ),
    );
    if (!(ok ?? false) || !mounted) return;
    await _run(() async {
      await ref.read(dmChatProvider(username).notifier).deleteConversation();
      ref
        ..invalidate(dmInboxProvider(false))
        ..invalidate(dmInboxProvider(true));
      unawaited(ref.read(dmUnreadProvider.notifier).refresh());
      if (mounted && context.canPop()) context.pop();
    });
  }

  Future<void> _block(String name) async {
    final blocked = await confirmBlock(
      context,
      ref,
      username: username,
      name: name,
    );
    if (!blocked || !mounted) return;
    ref
      ..invalidate(dmInboxProvider(false))
      ..invalidate(dmInboxProvider(true));
    unawaited(ref.read(dmUnreadProvider.notifier).refresh());
    if (context.canPop()) context.pop();
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    ref
      ..listen(dmChatProvider(username), (_, next) {
        final s = next.value;
        if (s != null) _onState(s);
      })
      ..listen(dmActivityProvider, (_, _) => _nudge());
    final chat = ref.watch(dmChatProvider(username));
    final s = chat.value;
    final user = s?.peer.user;
    final name = user?.displayName ?? widget.displayName ?? username;
    final tier = user?.premiumTier ?? widget.premiumTier;
    final conversation = s?.conversation;
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        titleSpacing: 0,
        title: Row(
          children: [
            KAvatar(
              name: name,
              imageUrl: user?.avatarUrl ?? widget.avatarUrl,
              size: KSizes.avatarSm,
            ),
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
                    style: context.textStyles.bodyStrong.copyWith(
                      color: p.textPrimary,
                    ),
                  ),
                  Text(
                    KHandle.text(l10n, username, premiumTier: tier),
                    maxLines: 1,
                    textDirection: TextDirection.ltr,
                    style: context.textStyles.caption.copyWith(
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (s != null)
            PopupMenuButton<String>(
              key: ChatScreen.menuKey,
              tooltip: l10n.dmMenu,
              onSelected: (v) => switch (v) {
                'mute' => unawaited(
                  _run(
                    () => ref
                        .read(dmChatProvider(username).notifier)
                        .setMuted(muted: !(conversation?.muted ?? false)),
                    done: (conversation?.muted ?? false)
                        ? l10n.dmUnmuted
                        : l10n.dmMuted,
                  ),
                ),
                'delete' => unawaited(_deleteConversation()),
                'report' => unawaited(
                  reportUser(context, ref, userId: s.peer.user.id),
                ),
                'block' => unawaited(_block(name)),
                _ => null,
              },
              itemBuilder: (_) => [
                if (conversation != null)
                  PopupMenuItem(
                    key: ChatScreen.muteKey,
                    value: 'mute',
                    child: Text(
                      conversation.muted ? l10n.dmUnmute : l10n.dmMute,
                    ),
                  ),
                if (conversation != null)
                  PopupMenuItem(
                    key: ChatScreen.deleteConversationKey,
                    value: 'delete',
                    child: Text(l10n.dmDeleteConversation),
                  ),
                PopupMenuItem(
                  key: ChatScreen.reportPersonKey,
                  value: 'report',
                  child: Text(l10n.dmReportPerson),
                ),
                PopupMenuItem(
                  key: ChatScreen.blockKey,
                  value: 'block',
                  child: Text(l10n.safetyBlock),
                ),
              ],
            ),
        ],
      ),
      body: switch (chat) {
        AsyncValue(:final value?) => _body(context, value, name),
        AsyncValue(:final error?) =>
          toAppFailure(error).code == ErrorCode.notFound
              ? KEmptyState(
                  key: ChatScreen.unavailableKey,
                  icon: Icons.person_off_outlined,
                  title: l10n.dmUnavailable,
                  message: l10n.dmRetentionNotice,
                )
              : FailureErrorState(
                  title: l10n.errorTitle,
                  failure: toAppFailure(error),
                  onRetry: () => ref.invalidate(dmChatProvider(username)),
                ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _body(BuildContext context, DmChatState s, String name) {
    final l10n = context.l10n;
    final p = context.palette;
    final conversation = s.conversation;
    final status = conversation?.status;
    final display = KFormat.bidiIsolate(name);
    final cannot = s.peer.canMessage
        ? null
        : s.peer.reason == DmBlockedReason.requestLimit
        ? l10n.dmRequestLimit(display)
        : l10n.dmNotAllowed(display);
    final left = status == DmConversationStatus.requestSent
        ? conversation?.requestMessagesLeft
        : null;
    return Column(
      children: [
        // D155 (owner): every message lives 24 hours — said once, quietly.
        Container(
          key: ChatScreen.noticeKey,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: KSpacing.md,
            vertical: KSpacing.xs,
          ),
          color: p.surface,
          child: Row(
            children: [
              Icon(Icons.timer_outlined, size: 14, color: p.textSecondary),
              const SizedBox(width: KSpacing.xs),
              Expanded(
                child: Text(
                  l10n.dmRetentionNotice,
                  style: context.textStyles.caption.copyWith(
                    color: p.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (status == DmConversationStatus.requestReceived)
          _RequestBanner(
            name: display,
            onAccept: () => _run(() async {
              await ref.read(dmChatProvider(username).notifier).accept();
              ref
                ..invalidate(dmInboxProvider(false))
                ..invalidate(dmInboxProvider(true));
              unawaited(ref.read(dmUnreadProvider.notifier).refresh());
            }),
            onDecline: _deleteConversation,
            onBlock: () => _block(name),
          ),
        Expanded(
          child: s.messages.isEmpty
              ? ListView(
                  key: ChatScreen.emptyKey,
                  padding: const EdgeInsets.all(KSpacing.xl),
                  children: [
                    const SizedBox(height: KSpacing.xl),
                    Center(
                      child: KAvatar(
                        name: name,
                        imageUrl: s.peer.user.avatarUrl,
                        size: KSizes.avatarLg,
                      ),
                    ),
                    const SizedBox(height: KSpacing.md),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: context.textStyles.title.copyWith(
                        color: p.textPrimary,
                      ),
                    ),
                    Text(
                      KHandle.text(
                        l10n,
                        username,
                        premiumTier:
                            s.peer.user.premiumTier ?? widget.premiumTier,
                      ),
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      style: context.textStyles.body.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                    const SizedBox(height: KSpacing.sm),
                    Text(
                      conversation == null
                          ? l10n.dmStartConversation
                          : l10n.dmNoRecentMessages,
                      textAlign: TextAlign.center,
                      style: context.textStyles.body.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.extentAfter < 300) {
                      unawaited(
                        ref
                            .read(dmChatProvider(username).notifier)
                            .loadMore()
                            .catchError((Object _) {}),
                      );
                    }
                    return false;
                  },
                  child: ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
                    itemCount: s.messages.length,
                    itemBuilder: (_, i) {
                      final m = s.messages[i];
                      return DmMessageView(
                        message: m,
                        peerName: name,
                        onLongPress: () => unawaited(_messageActions(m)),
                      );
                    },
                  ),
                ),
        ),
        if (left != null && cannot == null)
          Padding(
            key: ChatScreen.requestLeftKey,
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.md,
              vertical: KSpacing.xxs,
            ),
            child: Text(
              l10n.dmRequestLeft(display, '$left'),
              textAlign: TextAlign.center,
              style: context.textStyles.caption.copyWith(
                color: p.textSecondary,
              ),
            ),
          ),
        if (cannot != null)
          SafeArea(
            top: false,
            child: Container(
              key: ChatScreen.cannotSendKey,
              width: double.infinity,
              margin: const EdgeInsets.all(KSpacing.md),
              padding: const EdgeInsets.all(KSpacing.md),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(KRadius.md),
                border: Border.all(color: p.border),
              ),
              child: Text(
                cannot,
                textAlign: TextAlign.center,
                style: context.textStyles.body.copyWith(color: p.textSecondary),
              ),
            ),
          )
        else
          ChatComposer(
            controller: _input,
            inputKey: ChatScreen.composerKey,
            sendKey: ChatScreen.sendKey,
            emojiKey: ChatScreen.emojiKey,
            attachKey: ChatScreen.attachKey,
            giftKey: ChatScreen.giftKey,
            allowVideo: false,
            onSend: _sending ? null : () => unawaited(_sendText()),
            onMedia: (m) => unawaited(_sendPicture(m)),
            onGift: () => unawaited(_openGifts(s)),
            voice: _recorder.supported
                ? ChatVoiceControl(
                    recording: _recording,
                    elapsed: _elapsed,
                    busy: _voiceBusy || _sending,
                    onToggle: () => unawaited(_toggleVoice()),
                    onCancel: () => unawaited(_stopVoice(send: false)),
                  )
                : null,
          ),
      ],
    );
  }
}

class _RequestBanner extends StatelessWidget {
  const new({
    required this.name,
    required this.onAccept,
    required this.onDecline,
    required this.onBlock,
  });

  final String name;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return Container(
      key: ChatScreen.requestBannerKey,
      width: double.infinity,
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.dmRequestBanner(name),
            style: context.textStyles.body.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: KSpacing.sm),
          Wrap(
            spacing: KSpacing.sm,
            runSpacing: KSpacing.xs,
            children: [
              FilledButton(
                key: ChatScreen.acceptKey,
                onPressed: onAccept,
                child: Text(l10n.dmAccept),
              ),
              OutlinedButton(
                key: ChatScreen.declineKey,
                onPressed: onDecline,
                child: Text(l10n.dmDecline),
              ),
              TextButton(
                key: ChatScreen.requestBlockKey,
                onPressed: onBlock,
                child: Text(l10n.safetyBlock, style: TextStyle(color: p.error)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
