import 'dart:async';

import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/data/live_voice_recorder.dart';
import 'package:kabso_live/features/messages/application/dm_group_providers.dart';
import 'package:kabso_live/features/messages/application/dm_providers.dart';
import 'package:kabso_live/features/messages/attachments.dart';
import 'package:kabso_live/features/messages/data/dm_groups_repository.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/messages/widgets/chat_composer.dart';
import 'package:kabso_live/features/messages/widgets/dm_group_row.dart';
import 'package:kabso_live/features/messages/widgets/dm_message_view.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/posts/presentation/report_sheet.dart';
import 'package:kabso_live/features/push/open_conversation.dart';
import 'package:kabso_live/features/push/push_payload.dart';
import 'package:kabso_live/features/vip/application/vip_gift_perks_providers.dart';
import 'package:kabso_live/features/vip/data/vip_gift_perks_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/message-groups/:groupId` (D339, CONVENTIONS §10.133): a group
/// conversation — the D155 conversation screen with the sender's name over
/// the others' messages. The composer sends text and pack emojis, pictures
/// (`DM_IMAGE`) and voice notes (`DM_VOICE`, up to 30 s); no gifts in a
/// group. A long press copies, deletes for everyone (one's own within an
/// hour, any as an admin) or reports. The ⋮ menu: «معلومات المجموعة»,
/// mute, archive, report and leave. Real time as a conversation: the newest
/// page every 3 s, slowing to 15 s while quiet, paused in the background.
class GroupChatScreen extends ConsumerStatefulWidget {
  const new({required this.groupId, super.key, this.name});

  final String groupId;

  /// The group's name from the list (shown until the group loads).
  final String? name;

  static const headerKey = Key('dm.group.header');
  static const menuKey = Key('dm.group.menu');
  static const infoKey = Key('dm.group.menu.info');
  static const muteKey = Key('dm.group.menu.mute');
  static const archiveKey = Key('dm.group.menu.archive');
  static const reportKey = Key('dm.group.menu.report');
  static const leaveKey = Key('dm.group.menu.leave');
  static const confirmLeaveKey = Key('dm.group.leave.confirm');
  static const composerKey = Key('dm.group.composer');
  static const sendKey = Key('dm.group.send');
  static const emptyKey = Key('dm.group.empty');
  static const unavailableKey = Key('dm.group.unavailable');
  static const deleteKey = Key('dm.group.message.delete');
  static const copyKey = Key('dm.group.message.copy');
  static Key senderKey(String messageId) => Key('dm.group.sender.$messageId');

  /// The polling (tests replace it).
  @visibleForTesting
  static DmPollBackoff Function() newBackoff = DmPollBackoff.new;

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatState();
}

class _GroupChatState extends ConsumerState<GroupChatScreen> {
  final _input = TextEditingController();
  late final DmPollBackoff _backoff = GroupChatScreen.newBackoff();
  late final OpenConversation _open;
  late final AppLifecycleListener _lifecycle;
  late final LiveVoiceRecorder _recorder;
  late final String _conversation = dmGroupConversation(widget.groupId);
  Timer? _poll;
  bool _foreground = true;
  bool _sending = false;
  String? _readUpTo;

  bool _recording = false;
  bool _voiceBusy = false;
  Duration _elapsed = Duration.zero;
  Timer? _tick;

  String get groupId => widget.groupId;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open.opened(_conversation);
    });
    _schedule();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    _lifecycle.dispose();
    _input.dispose();
    // Not while the tree is being torn down (a provider write then is
    // refused): just after.
    final open = _open;
    final conversation = _conversation;
    unawaited(
      Future.microtask(() {
        try {
          open.closed(conversation);
        } on Object {
          // The app (and its providers) went away with the screen.
        }
      }),
    );
    unawaited(_recorder.dispose().then<void>((_) {}, onError: (Object _) {}));
    super.dispose();
  }

  void _schedule() {
    _poll?.cancel();
    if (!_foreground) return;
    _poll = Timer(_backoff.next, () async {
      if (!mounted) return;
      var changed = false;
      try {
        changed = await ref
            .read(dmGroupChatProvider(groupId).notifier)
            .refresh();
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

  /// Marks what arrived as read (the senders see it in `readCount`).
  void _onState(DmGroupChatState s) {
    final newest = s.messages.where((m) => !m.mine).firstOrNull;
    if (newest == null || newest.id == _readUpTo) return;
    _readUpTo = newest.id;
    unawaited(() async {
      final told = await ref
          .read(dmGroupChatProvider(groupId).notifier)
          .markRead();
      if (told && mounted) {
        unawaited(ref.read(dmUnreadProvider.notifier).refresh());
      }
    }());
  }

  // ---- Sending ------------------------------------------------------------

  Future<bool> _send(DmOutgoing outgoing, {required String key}) async {
    final l10n = context.l10n;
    setState(() => _sending = true);
    try {
      await ref
          .read(dmGroupChatProvider(groupId).notifier)
          .send(outgoing, key: key);
      _nudge();
      return true;
    } on Object catch (e) {
      if (mounted) KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      return false;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendText() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final emojis = KabiEmojiText.onlyEmojis(text);
    final outgoing = emojis != null && emojis.length == 1
        ? DmOutgoingEmoji(emojis.single.token)
        : DmOutgoingText(text);
    final ok = await _send(outgoing, key: 'text:$text');
    if (ok && mounted) _input.clear();
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
        // v1.134-social (D381): LONGER_VOICE's limit, else 30 s.
        if (_elapsed >= ref.read(vipVoiceLimitProvider)) {
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
      if (clip.bytes.length > voiceBytesFor(ref.read(vipVoiceLimitProvider))) {
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

  // ---- Actions ------------------------------------------------------------

  Future<void> _messageActions(DmGroupMessage m, DmGroup group) async {
    final l10n = context.l10n;
    final withinHour =
        DateTime.now().difference(m.createdAt) < const Duration(hours: 1);
    final canDelete = group.isAdmin || (m.mine && withinHour);
    final canCopy = m.kind == DmMessageKind.text && (m.text ?? '').isNotEmpty;
    if (!canDelete && !canCopy && m.mine) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canCopy)
              ListTile(
                key: GroupChatScreen.copyKey,
                leading: const Icon(Icons.copy_rounded),
                title: Text(l10n.dmCopy),
                onTap: () => Navigator.of(sheet).pop('copy'),
              ),
            if (canDelete)
              ListTile(
                key: GroupChatScreen.deleteKey,
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: sheet.palette.error,
                ),
                title: Text(l10n.dmDeleteForEveryone),
                onTap: () => Navigator.of(sheet).pop('delete'),
              ),
            if (!m.mine)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(l10n.dmGroupReport),
                onTap: () => Navigator.of(sheet).pop('report'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: m.text ?? ''));
        if (mounted) KSnack.success(context, l10n.dmCopied);
      case 'delete':
        await _run(
          () => ref
              .read(dmGroupChatProvider(groupId).notifier)
              .deleteMessage(m.id),
        );
      case 'report':
        await _report();
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

  Future<void> _report() async {
    final l10n = context.l10n;
    final reason = await pickReportReason(context, l10n.dmGroupReport);
    if (reason == null || !mounted) return;
    await _run(
      () => ref.read(dmGroupsRepositoryProvider).report(groupId, reason),
      done: l10n.dmReported,
    );
  }

  Future<void> _leave() async {
    final ok = await confirmLeaveGroup(context);
    if (!ok || !mounted) return;
    await _run(() async {
      await ref.read(dmGroupsRepositoryProvider).leave(groupId);
      invalidateDmBoxes(ref);
      unawaited(ref.read(dmUnreadProvider.notifier).refresh());
      if (mounted && context.canPop()) context.pop();
    });
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    ref
      ..listen(dmGroupChatProvider(groupId), (_, next) {
        final s = next.value;
        if (s != null) _onState(s);
      })
      ..listen(dmActivityProvider, (_, _) => _nudge());
    final chat = ref.watch(dmGroupChatProvider(groupId));
    final s = chat.value;
    final group = s?.group;
    final name = group?.name ?? widget.name ?? '';
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        titleSpacing: 0,
        title: Semantics(
          button: true,
          hint: l10n.dmGroupInfo,
          child: InkWell(
            key: GroupChatScreen.headerKey,
            borderRadius: BorderRadius.circular(KRadius.md),
            onTap: group == null
                ? null
                : () => context.push(AppRoutes.groupInfo(groupId)),
            child: Row(
              children: [
                DmGroupAvatar(
                  name: name,
                  photoUrl: group?.photoUrl,
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
                      if (group != null)
                        Text(
                          l10n.dmGroupMembersCount(
                            KFormat.compact(group.memberCount, l10n),
                          ),
                          maxLines: 1,
                          style: context.textStyles.caption.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (group != null)
            PopupMenuButton<String>(
              key: GroupChatScreen.menuKey,
              tooltip: l10n.dmMenu,
              onSelected: (v) => switch (v) {
                'info' => unawaited(context.push(AppRoutes.groupInfo(groupId))),
                'mute' => unawaited(
                  _run(
                    () => ref
                        .read(dmGroupChatProvider(groupId).notifier)
                        .setMuted(muted: !group.muted),
                    done: group.muted ? l10n.dmUnmuted : l10n.dmMuted,
                  ),
                ),
                'archive' => unawaited(
                  _run(
                    () async {
                      await ref
                          .read(dmGroupChatProvider(groupId).notifier)
                          .setArchived(archived: !group.archived);
                      invalidateDmBoxes(ref);
                    },
                    done: group.archived
                        ? l10n.dmUnarchivedDone
                        : l10n.dmArchivedDone,
                  ),
                ),
                'report' => unawaited(_report()),
                'leave' => unawaited(_leave()),
                _ => null,
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: GroupChatScreen.infoKey,
                  value: 'info',
                  child: Text(l10n.dmGroupInfo),
                ),
                PopupMenuItem(
                  key: GroupChatScreen.muteKey,
                  value: 'mute',
                  child: Text(group.muted ? l10n.dmUnmute : l10n.dmMute),
                ),
                PopupMenuItem(
                  key: GroupChatScreen.archiveKey,
                  value: 'archive',
                  child: Text(
                    group.archived ? l10n.dmUnarchive : l10n.dmArchive,
                  ),
                ),
                PopupMenuItem(
                  key: GroupChatScreen.reportKey,
                  value: 'report',
                  child: Text(l10n.dmGroupReport),
                ),
                PopupMenuItem(
                  key: GroupChatScreen.leaveKey,
                  value: 'leave',
                  child: Text(
                    l10n.dmGroupLeave,
                    style: TextStyle(color: p.error),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: switch (chat) {
        AsyncValue(:final value?) => _body(context, value),
        AsyncValue(:final error?) =>
          toAppFailure(error).code == ErrorCode.notFound
              ? KEmptyState(
                  key: GroupChatScreen.unavailableKey,
                  icon: Icons.group_off_outlined,
                  title: l10n.dmGroupUnavailable,
                  message: l10n.dmRetentionNotice,
                )
              : FailureErrorState(
                  title: l10n.errorTitle,
                  failure: toAppFailure(error),
                  onRetry: () => ref.invalidate(dmGroupChatProvider(groupId)),
                ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _body(BuildContext context, DmGroupChatState s) {
    final l10n = context.l10n;
    final p = context.palette;
    final others = s.group.memberCount - 1;
    return Column(
      children: [
        Container(
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
        Expanded(
          child: s.messages.isEmpty
              ? ListView(
                  key: GroupChatScreen.emptyKey,
                  padding: const EdgeInsets.all(KSpacing.xl),
                  children: [
                    const SizedBox(height: KSpacing.xl),
                    Center(
                      child: DmGroupAvatar(
                        name: s.group.name,
                        photoUrl: s.group.photoUrl,
                        size: KSizes.avatarLg,
                      ),
                    ),
                    const SizedBox(height: KSpacing.md),
                    Text(
                      s.group.name,
                      textAlign: TextAlign.center,
                      style: context.textStyles.title.copyWith(
                        color: p.textPrimary,
                      ),
                    ),
                    Text(
                      l10n.dmGroupMembersCount(
                        KFormat.compact(s.group.memberCount, l10n),
                      ),
                      textAlign: TextAlign.center,
                      style: context.textStyles.body.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                    const SizedBox(height: KSpacing.sm),
                    Text(
                      l10n.dmNoRecentMessages,
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
                            .read(dmGroupChatProvider(groupId).notifier)
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
                      // The sender's name over the first of their run (the
                      // list is newest first: the next item is older).
                      final older = i + 1 < s.messages.length
                          ? s.messages[i + 1]
                          : null;
                      final showName =
                          !m.mine &&
                          (older == null ||
                              older.mine ||
                              older.sender?.id != m.sender?.id);
                      final senderName =
                          m.sender?.displayName ?? l10n.dmGroupUnknownSender;
                      final bubble = DmMessageView(
                        message: m.asDmMessage(
                          read: others > 0 && m.readCount >= others,
                        ),
                        peerName: senderName,
                        onLongPress: () =>
                            unawaited(_messageActions(m, s.group)),
                      );
                      if (!showName) return bubble;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            key: GroupChatScreen.senderKey(m.id),
                            padding: const EdgeInsetsDirectional.only(
                              start: KSpacing.lg,
                              top: KSpacing.xs,
                            ),
                            child: Text(
                              senderName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textStyles.caption.copyWith(
                                color: p.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          bubble,
                        ],
                      );
                    },
                  ),
                ),
        ),
        ChatComposer(
          controller: _input,
          inputKey: GroupChatScreen.composerKey,
          sendKey: GroupChatScreen.sendKey,
          showGift: false,
          allowVideo: false,
          onSend: _sending ? null : () => unawaited(_sendText()),
          onMedia: (m) => unawaited(_sendPicture(m)),
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

/// «مغادرة المجموعة؟» — true when the caller confirms.
Future<bool> confirmLeaveGroup(BuildContext context) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(l10n.dmGroupLeaveTitle),
      content: Text(l10n.dmGroupLeaveBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(l10n.actionCancel),
        ),
        TextButton(
          key: GroupChatScreen.confirmLeaveKey,
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(
            l10n.dmGroupLeave,
            style: TextStyle(color: dialog.palette.error),
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}
