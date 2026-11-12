import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_voice_recorder.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/features/messages/application/dm_providers.dart';
import 'package:kabso_live/features/messages/attachments.dart';
import 'package:kabso_live/features/messages/widgets/chat_composer.dart';
import 'package:kabso_live/features/messages/widgets/dm_message_view.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/push/open_conversation.dart';
import 'package:kabso_live/features/push/push_payload.dart';
import 'package:kabso_live/features/support/application/support_providers.dart';
import 'package:kabso_live/features/support/domain/support_models.dart';
import 'package:kabso_live/features/vip/application/vip_gift_perks_providers.dart';
import 'package:kabso_live/features/vip/data/vip_gift_perks_repository.dart';
import 'package:kabso_live/features/whatsapp/domain/wa_models.dart'
    show WaDepartment;
import 'package:kabso_live/features/whatsapp/presentation/wa_screens.dart'
    show waDepartmentIcon, waDepartmentName;
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/support-chat` — «دعم كابسو» (D385, CONVENTIONS §10.174): the person's
/// conversation with the Kabso Team, built from the direct messages'
/// pieces (the bubbles, the composer: text, a photo such as a recharge
/// receipt, a voice note). The first message of a new ticket needs a topic
/// — one of the five departments (D366) — picked above the composer. The
/// person's own messages say «تم الاستلام» (then «تمت القراءة»); a reply
/// shows the staff member's first name under the «فريق كابسو» badge, never
/// their account. It cannot be deleted, muted or blocked.
class SupportChatScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const titleKey = Key('support.title');
  static const topicsKey = Key('support.topics');
  static Key topicKey(WaDepartment d) => Key('support.topic.${d.wire}');
  static const topicChipKey = Key('support.topic.current');
  static const introKey = Key('support.intro');
  static const composerKey = Key('support.composer');
  static const sendKey = Key('support.send');
  static const attachKey = Key('support.attach');
  static const receiptKey = Key('support.receipt');
  static Key staffKey(String messageId) => Key('support.staff.$messageId');

  /// Tests replace the poll's backoff (no timers left behind).
  @visibleForTesting
  static DmPollBackoff Function() newBackoff = DmPollBackoff.new;

  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen> {
  final _input = TextEditingController();
  late final DmPollBackoff _backoff = SupportChatScreen.newBackoff();
  late final OpenConversation _open;
  late final LiveVoiceRecorder _recorder;
  Timer? _poll;
  Timer? _tick;
  bool _sending = false;
  bool _recording = false;
  bool _voiceBusy = false;
  Duration _elapsed = Duration.zero;
  WaDepartment? _topic;
  String? _openId;

  @override
  void initState() {
    super.initState();
    _open = ref.read(openConversationProvider.notifier);
    _recorder = ref.read(liveVoiceRecorderProvider)();
    _schedule();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    _input.dispose();
    final open = _openId;
    if (open != null) _open.closed(open);
    unawaited(_recorder.dispose().then<void>((_) {}, onError: (Object _) {}));
    super.dispose();
  }

  void _schedule() {
    _poll?.cancel();
    _poll = Timer(_backoff.next, () async {
      if (!mounted) return;
      var changed = false;
      try {
        changed = await ref.read(supportChatProvider.notifier).refresh();
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

  void _onState(SupportChatState s) {
    final id = s.thread.id;
    if (id != null && _openId != supportConversation(id)) {
      final before = _openId;
      if (before != null) _open.closed(before);
      _openId = supportConversation(id);
      _open.opened(_openId!);
    }
    if (s.thread.unreadCount > 0) {
      unawaited(ref.read(supportChatProvider.notifier).markRead());
    }
  }

  // ---- Sending ------------------------------------------------------------

  /// The topic of a new ticket, or null when a ticket is open; asks for one
  /// when it is missing (and returns false).
  bool _topicReady(SupportChatState s) {
    if (!s.thread.needsTopic || _topic != null) return true;
    KSnack.error(context, context.l10n.supportPickTopicFirst);
    return false;
  }

  Future<bool> _send(SupportOutgoing outgoing, {required String key}) async {
    final l10n = context.l10n;
    final s = ref.read(supportChatProvider).value;
    if (s == null || !_topicReady(s)) return false;
    setState(() => _sending = true);
    try {
      await ref
          .read(supportChatProvider.notifier)
          .send(outgoing, key: key, topic: s.thread.needsTopic ? _topic : null);
      if (mounted) setState(() => _topic = null);
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
    final ok = await _send(SupportOutgoingText(text), key: 'text:$text');
    if (ok && mounted) _input.clear();
  }

  Future<void> _sendPicture(PickedMedia media) async {
    final l10n = context.l10n;
    final s = ref.read(supportChatProvider).value;
    if (s == null || !_topicReady(s)) return;
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
      await _send(SupportOutgoingMedia(id, voice: false), key: 'media:$id');
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
    final s = ref.read(supportChatProvider).value;
    if (_voiceBusy || s == null || !_topicReady(s)) return;
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
      await _send(SupportOutgoingMedia(id, voice: true), key: 'voice:$id');
    } on Object catch (e) {
      if (mounted) KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    } finally {
      if (mounted) setState(() => _voiceBusy = false);
    }
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    ref
      ..listen(supportChatProvider, (_, next) {
        final s = next.value;
        if (s != null) _onState(s);
      })
      ..listen(dmActivityProvider, (_, _) => _nudge());
    final chat = ref.watch(supportChatProvider);
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        titleSpacing: 0,
        title: Row(
          children: [
            const KabsoTeamPicture(size: KSizes.avatarSm),
            const SizedBox(width: KSpacing.sm),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.supportChatName,
                    key: SupportChatScreen.titleKey,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyStrong.copyWith(color: p.textPrimary),
                  ),
                  Text(
                    l10n.supportChatSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: switch (chat) {
        AsyncValue(:final value?) => _body(context, value),
        AsyncValue(:final error?) => FailureErrorState(
          title: l10n.errorTitle,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(supportChatProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _body(BuildContext context, SupportChatState s) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final threadId = s.thread.id ?? 'support';
    final newestMine = s.messages.where((m) => m.mine).firstOrNull;
    final department = s.thread.department;
    return Column(
      children: [
        if (!s.thread.needsTopic && department != null)
          Container(
            key: SupportChatScreen.topicChipKey,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.md,
              vertical: KSpacing.xs,
            ),
            color: p.surface,
            child: Row(
              children: [
                Icon(
                  waDepartmentIcon(department),
                  size: 16,
                  color: p.textSecondary,
                ),
                const SizedBox(width: KSpacing.xs),
                Expanded(
                  child: Text(
                    l10n.supportTopicOf(waDepartmentName(l10n, department)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.copyWith(color: p.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: s.messages.isEmpty
              ? const _Intro(key: SupportChatScreen.introKey)
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.extentAfter < 300) {
                      unawaited(
                        ref
                            .read(supportChatProvider.notifier)
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
                      final older = i + 1 < s.messages.length
                          ? s.messages[i + 1]
                          : null;
                      // The badge and the name over the first of a run of
                      // replies from one staff member.
                      final head =
                          !m.mine &&
                          (older == null ||
                              older.mine ||
                              older.staffFirstName != m.staffFirstName);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (head)
                            _StaffLine(
                              key: SupportChatScreen.staffKey(m.id),
                              firstName: m.staffFirstName,
                            ),
                          DmMessageView(
                            message: m.toDm(threadId),
                            peerName: l10n.supportChatName,
                          ),
                          if (m.mine && identical(m, newestMine))
                            _Receipt(read: m.receipt == SupportReceipt.read),
                        ],
                      );
                    },
                  ),
                ),
        ),
        if (s.thread.needsTopic)
          _TopicPicker(
            key: SupportChatScreen.topicsKey,
            selected: _topic,
            closed: s.thread.status == SupportThreadStatus.closed,
            onSelect: (d) => setState(() => _topic = d),
          ),
        ChatComposer(
          controller: _input,
          inputKey: SupportChatScreen.composerKey,
          sendKey: SupportChatScreen.sendKey,
          attachKey: SupportChatScreen.attachKey,
          allowVideo: false,
          showGift: false,
          hintText: l10n.supportComposerHint,
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

/// Before the first message: who answers here.
class _Intro extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return ListView(
      padding: const EdgeInsets.all(KSpacing.xl),
      children: [
        const SizedBox(height: KSpacing.lg),
        const Center(child: KabsoTeamPicture(size: KSizes.avatarLg)),
        const SizedBox(height: KSpacing.md),
        Text(
          l10n.supportChatName,
          textAlign: TextAlign.center,
          style: t.title.copyWith(color: p.textPrimary),
        ),
        const SizedBox(height: KSpacing.xs),
        const Center(child: KabsoTeamBadge(height: 28)),
        const SizedBox(height: KSpacing.sm),
        Text(
          l10n.supportIntro,
          textAlign: TextAlign.center,
          style: t.body.copyWith(color: p.textSecondary),
        ),
      ],
    );
  }
}

/// Over a reply: the «فريق كابسو» badge and the staff member's first name.
class _StaffLine extends StatelessWidget {
  const new({required this.firstName, super.key});

  final String? firstName;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final name = firstName;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: KSpacing.md,
        end: KSpacing.md,
        top: KSpacing.xs,
      ),
      child: Wrap(
        spacing: KSpacing.xs,
        runSpacing: KSpacing.xxs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const KabsoTeamBadge(height: KabsoTeamBadge.chatHeight),
          if (name != null)
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: p.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Under the person's newest message: «تم الاستلام» / «تمت القراءة».
class _Receipt extends StatelessWidget {
  const new({required this.read});

  final bool read;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    return Padding(
      key: SupportChatScreen.receiptKey,
      padding: const EdgeInsetsDirectional.only(
        start: KSpacing.md,
        end: KSpacing.md,
        bottom: KSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(
            read ? Icons.done_all_rounded : Icons.done_rounded,
            size: 14,
            color: read ? p.info : p.textTertiary,
          ),
          const SizedBox(width: KSpacing.xxs),
          Flexible(
            child: Text(
              read ? l10n.supportReceiptRead : l10n.supportReceiptReceived,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.caption.copyWith(color: p.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The five departments (D366) as the new ticket's topic.
class _TopicPicker extends StatelessWidget {
  const new({
    required this.selected,
    required this.closed,
    required this.onSelect,
    super.key,
  });

  final WaDepartment? selected;
  final bool closed;
  final ValueChanged<WaDepartment> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        KSpacing.md,
        KSpacing.sm,
        KSpacing.md,
        KSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            closed ? l10n.supportNewTicket : l10n.supportPickTopic,
            style: t.bodyStrong.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: KSpacing.xs),
          Wrap(
            spacing: KSpacing.xs,
            runSpacing: KSpacing.xs,
            children: [
              for (final d in WaDepartment.values)
                ChoiceChip(
                  key: SupportChatScreen.topicKey(d),
                  avatar: Icon(
                    waDepartmentIcon(d),
                    size: 16,
                    color: selected == d ? p.onPrimary : p.textSecondary,
                  ),
                  showCheckmark: false,
                  label: Text(waDepartmentName(l10n, d)),
                  labelStyle: t.caption.copyWith(
                    fontSize: 13,
                    color: selected == d ? p.onPrimary : p.textPrimary,
                  ),
                  selected: selected == d,
                  selectedColor: p.primary,
                  backgroundColor: p.background,
                  side: BorderSide(color: selected == d ? p.primary : p.border),
                  onSelected: (_) => onSelect(d),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
