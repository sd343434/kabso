import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/whatsapp/application/wa_providers.dart';
import 'package:kabso_live/features/whatsapp/data/wa_repository.dart';
import 'package:kabso_live/features/whatsapp/domain/wa_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.116-social (D355, CONVENTIONS §10.151; owner: «زر واتساب … عداد غير
/// مقروء … إشعار … والرد على العميل»): the staff's WhatsApp inbox on the
/// phone. Tabs «غير مسندة» / «محادثاتي» / «الكل» / «مغلقة», a search by name
/// or number; each row with the unread count and who has it. Off on the
/// server → an honest empty state.
class WaInboxScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const tabsKey = Key('wa.tabs');
  static const searchKey = Key('wa.search');
  static Key row(String id) => Key('wa.row.$id');

  @override
  ConsumerState<WaInboxScreen> createState() => _WaInboxScreenState();
}

class _WaInboxScreenState extends ConsumerState<WaInboxScreen> {
  WaFilter _filter = WaFilter.unassigned;
  String _q = '';
  Timer? _debounce;
  Timer? _poll;

  WaListKey get _key => (filter: _filter, q: _q);

  @override
  void initState() {
    super.initState();
    // The inbox reads the server again every 20 s while it is open.
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _reload());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    ref.invalidate(waConversationsProvider(_key));
    if (ref.exists(waSummaryProvider)) {
      unawaited(ref.read(waSummaryProvider.notifier).refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final summary = ref.watch(waSummaryProvider).value;
    if (summary != null && !summary.enabled) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.waTitle)),
        body: KEmptyState(
          icon: Icons.chat_bubble_outline_rounded,
          title: l10n.waOff,
          message: l10n.waOffHint,
        ),
      );
    }
    final list = ref.watch(waConversationsProvider(_key));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.waTitle), actions: const [_MuteButton()]),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KScrollableTabs(
            key: WaInboxScreen.tabsKey,
            labels: [
              l10n.waTabUnassigned,
              l10n.waTabMine,
              l10n.waTabAll,
              l10n.waTabClosed,
            ],
            selectedIndex: _filter.index,
            onSelected: (i) => setState(() => _filter = WaFilter.values[i]),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              KSpacing.lg,
              KSpacing.sm,
              KSpacing.lg,
              KSpacing.xs,
            ),
            child: TextField(
              key: WaInboxScreen.searchKey,
              decoration: InputDecoration(
                hintText: l10n.waSearch,
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 350),
                  () => setState(() => _q = v.trim()),
                );
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _reload();
                await ref.read(waConversationsProvider(_key).future);
              },
              child: switch (list) {
                AsyncData(:final value) when value.isEmpty => ListView(
                  children: [
                    KEmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: l10n.waEmpty,
                      message: l10n.waEmptyHint,
                      compact: true,
                    ),
                  ],
                ),
                AsyncData(:final value) => ListView.separated(
                  itemCount: value.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: p.border),
                  itemBuilder: (_, i) => WaConversationTile(
                    key: WaInboxScreen.row(value[i].id),
                    c: value[i],
                    onTap: () async {
                      await context.push<void>(
                        AppRoutes.staffWhatsAppChat(value[i].id),
                      );
                      _reload();
                    },
                  ),
                ),
                AsyncError(:final error) => ListView(
                  children: [
                    KErrorState(
                      title: l10n.waTitle,
                      message: failureMessage(l10n, toAppFailure(error)),
                      retryLabel: l10n.actionRetry,
                      onRetry: _reload,
                      compact: true,
                    ),
                  ],
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// «كتم إشعارات واتساب» for this staff member (every phone of the account).
class _MuteButton extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_MuteButton> createState() => _MuteButtonState();
}

class _MuteButtonState extends ConsumerState<_MuteButton> {
  bool? _muted;

  @override
  void initState() {
    super.initState();
    unawaited(
      ref.read(waRepositoryProvider).pushMuted().then((m) {
        if (mounted) setState(() => _muted = m);
      }, onError: (Object _) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = _muted;
    if (muted == null) return const SizedBox.shrink();
    return IconButton(
      key: const Key('wa.mute'),
      tooltip: context.l10n.waMute,
      isSelected: muted,
      icon: Icon(
        muted
            ? Icons.notifications_off_rounded
            : Icons.notifications_active_rounded,
      ),
      onPressed: () async {
        try {
          final next = await ref
              .read(waRepositoryProvider)
              .setPushMuted(muted: !muted);
          if (mounted) setState(() => _muted = next);
        } on Object catch (e) {
          if (context.mounted) {
            KSnack.error(
              context,
              failureMessage(context.l10n, toAppFailure(e)),
            );
          }
        }
      },
    );
  }
}

/// A phone number reads left to right inside Arabic.
String waPhone(String e164) => KFormat.bidiIsolate(e164);

String _staff(AppLocalizations l10n, WaStaffRef? s) =>
    s?.label ?? l10n.waSomeone;

class WaConversationTile extends StatelessWidget {
  const new({required this.c, required this.onTap, super.key});

  final WaConversation c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final unread = c.unreadCount > 0;
    final tag = !c.open
        ? l10n.waClosed
        : c.assignedToMe
        ? l10n.waAssignedToMe
        : c.assignedTo != null
        ? l10n.waAssignedTo(_staff(l10n, c.assignedTo))
        : l10n.waUnassigned;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.lg,
          vertical: KSpacing.md,
        ),
        child: Row(
          children: [
            KAvatar(name: c.title, size: 44),
            const SizedBox(width: KSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.name ?? waPhone(c.phone),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: unread ? t.bodyStrong : t.body,
                        ),
                      ),
                      Text(
                        KFormat.time(c.lastMessageAt.toLocal(), locale),
                        style: t.caption.copyWith(color: p.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: KSpacing.xxs),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.lastPreview ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.copyWith(color: p.textSecondary),
                        ),
                      ),
                      if (unread) WaCountBadge(count: c.unreadCount),
                    ],
                  ),
                  const SizedBox(height: KSpacing.xxs),
                  Text(
                    tag,
                    style: t.caption.copyWith(
                      color: c.assignedToMe
                          ? p.info
                          : (c.assignedTo == null && c.open
                                ? p.success
                                : p.textTertiary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The red count (hidden at 0, «99+» above 99) — the inbox rows and the Me
/// tab's «واتساب» row.
class WaCountBadge extends StatelessWidget {
  const new({required this.count, super.key});

  static const badgeKey = Key('wa.badge');

  final int count;

  static String? text(int count) =>
      count <= 0 ? null : (count > 99 ? '99+' : '$count');

  @override
  Widget build(BuildContext context) {
    final label = text(count);
    if (label == null) return const SizedBox.shrink();
    return Semantics(
      label: context.l10n.waUnreadCount(count),
      excludeSemantics: true,
      child: Container(
        key: badgeKey,
        constraints: const BoxConstraints(minWidth: 22),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: KBrandColors.red600,
          borderRadius: BorderRadius.circular(KRadius.pill),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: context.textStyles.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ---- the chat --------------------------------------------------------

/// One conversation: the bubbles (media, voice, ticks, reactions), the 24-hour
/// window banner — closed → the composer is «إرسال قالب» only — claim /
/// release / transfer / close / reopen, and the customer's details (the
/// linked Kabso account, the internal notes).
class WaChatScreen extends ConsumerStatefulWidget {
  const new({required this.conversationId, super.key});

  final String conversationId;

  static const composerKey = Key('wa.composer');
  static const sendKey = Key('wa.send');
  static const templateKey = Key('wa.template');
  static const windowClosedKey = Key('wa.windowClosed');
  static const menuKey = Key('wa.menu');
  static const detailsKey = Key('wa.details');

  @override
  ConsumerState<WaChatScreen> createState() => _WaChatScreenState();
}

class _WaChatScreenState extends ConsumerState<WaChatScreen> {
  Timer? _poll;
  bool _readSent = false;

  String get _id => widget.conversationId;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _reload());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    ref.invalidate(waThreadProvider(_id));
    if (ref.exists(waSummaryProvider)) {
      unawaited(ref.read(waSummaryProvider.notifier).refresh());
    }
  }

  void _markReadOnce(WaConversation c) {
    if (_readSent || c.unreadCount == 0) return;
    _readSent = true;
    unawaited(
      ref
          .read(waRepositoryProvider)
          .markRead(_id)
          .then((_) => _reload(), onError: (Object _) {}),
    );
  }

  Future<void> _run(Future<Object?> Function(WaRepository repo) action) async {
    try {
      await action(ref.read(waRepositoryProvider));
      _reload();
    } on Object catch (e) {
      if (mounted) KSnack.error(context, waErrorMessage(context.l10n, e));
    }
  }

  Future<void> _transfer() async {
    final to = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => const _AgentsSheet(),
    );
    if (to != null) await _run((r) => r.transfer(_id, to));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final thread = ref.watch(waThreadProvider(_id));
    final c = thread.value?.conversation;
    if (c != null) _markReadOnce(c);
    return Scaffold(
      appBar: AppBar(
        title: c == null
            ? Text(l10n.waTitle)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    waPhone(c.phone),
                    style: context.textStyles.caption.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ),
        actions: [
          if (c != null)
            IconButton(
              key: WaChatScreen.detailsKey,
              tooltip: l10n.waDetails,
              icon: const Icon(Icons.person_outline_rounded),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => WaCustomerSheet(conversationId: _id),
              ),
            ),
          if (c != null)
            PopupMenuButton<String>(
              key: WaChatScreen.menuKey,
              onSelected: (a) => a == 'transfer'
                  ? unawaited(_transfer())
                  : unawaited(_run((r) => r.act(_id, a))),
              itemBuilder: (_) => [
                if (c.open && c.assignedTo == null)
                  PopupMenuItem(value: 'claim', child: Text(l10n.waClaim)),
                if (c.open && c.assignedTo != null)
                  PopupMenuItem(value: 'release', child: Text(l10n.waRelease)),
                if (c.open)
                  PopupMenuItem(
                    value: 'transfer',
                    child: Text(l10n.waTransfer),
                  ),
                if (c.open)
                  PopupMenuItem(value: 'close', child: Text(l10n.waClose)),
                if (!c.open)
                  PopupMenuItem(value: 'reopen', child: Text(l10n.waReopen)),
              ],
            ),
        ],
      ),
      body: switch (thread) {
        AsyncData(:final value) => WaChatBody(
          thread: value,
          onSent: _reload,
          onClaim: () => unawaited(_run((r) => r.act(_id, 'claim'))),
          onReopen: () => unawaited(_run((r) => r.act(_id, 'reopen'))),
        ),
        AsyncError(:final error) => KErrorState(
          title: l10n.waTitle,
          message: waErrorMessage(l10n, error),
          retryLabel: l10n.actionRetry,
          onRetry: _reload,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// The server's WhatsApp codes in words (§10.151.4), else the general text.
String waErrorMessage(AppLocalizations l10n, Object error) {
  final f = toAppFailure(error);
  return switch (f.code) {
    ErrorCode.whatsappWindowClosed => l10n.waErrWindow,
    ErrorCode.whatsappConversationAssigned => l10n.waErrAssigned,
    ErrorCode.whatsappConversationClosed => l10n.waErrClosed,
    ErrorCode.whatsappSendFailed => l10n.waErrSend,
    ErrorCode.whatsappUnavailable => l10n.waErrOff,
    _ => failureMessage(l10n, f),
  };
}

/// The chat without its loading (the goldens pump it with a fixed thread).
class WaChatBody extends StatelessWidget {
  const new({
    required this.thread,
    required this.onSent,
    required this.onClaim,
    required this.onReopen,
    super.key,
  });

  final WaThread thread;
  final VoidCallback onSent;
  final VoidCallback onClaim;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final c = thread.conversation;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WaWindowBanner(c: c),
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(KSpacing.md),
            itemCount: thread.messages.length,
            itemBuilder: (_, i) => WaBubble(m: thread.messages[i]),
          ),
        ),
        if (!c.open)
          _BottomAction(label: l10n.waReopen, onPressed: onReopen)
        else if (c.takenByOther)
          _BottomNote(text: l10n.waErrAssigned)
        else
          WaComposer(c: c, onSent: onSent, onClaim: onClaim),
      ],
    );
  }
}

class WaWindowBanner extends StatelessWidget {
  const new({required this.c, super.key});

  final WaConversation c;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    if (!c.open) return const SizedBox.shrink();
    final closes = c.windowClosesAt;
    if (c.windowOpen && closes != null) {
      final locale = Localizations.localeOf(context).toLanguageTag();
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.lg,
          vertical: KSpacing.xs,
        ),
        child: Text(
          l10n.waWindowOpen(
            '${KFormat.date(closes.toLocal(), locale)} '
            '${KFormat.time(closes.toLocal(), locale)}',
          ),
          style: context.textStyles.caption.copyWith(color: p.success),
        ),
      );
    }
    return Container(
      key: WaChatScreen.windowClosedKey,
      margin: const EdgeInsets.all(KSpacing.md),
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: p.surfaceOverlay,
        border: Border.all(color: p.warning),
        borderRadius: BorderRadius.circular(KRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, color: p.warning, size: 20),
          const SizedBox(width: KSpacing.sm),
          Expanded(
            child: Text(
              closes == null ? l10n.waWindowNever : l10n.waWindowClosed,
              style: context.textStyles.body,
            ),
          ),
        ],
      ),
    );
  }
}

class WaBubble extends StatelessWidget {
  const new({required this.m, super.key});

  final WaMessage m;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final out = m.outbound;
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      margin: const EdgeInsets.symmetric(vertical: KSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.md,
        vertical: KSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: out ? p.primary.withValues(alpha: 0.12) : p.surfaceRaised,
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(KRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (m.templateName != null)
            Text(
              l10n.waTemplateTag(m.templateName!),
              style: t.caption.copyWith(
                color: p.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          if (m.media != null) _MediaPart(m: m),
          if (m.latitude != null && m.longitude != null)
            Text(
              '📍 ${m.locationName ?? l10n.waLocation}\n'
              '${KFormat.bidiIsolate(_coords(m.latitude!, m.longitude!))}',
              style: t.body,
            ),
          if (m.type == 'UNSUPPORTED')
            Text(
              l10n.waUnsupported,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          if (m.text != null && m.text!.isNotEmpty)
            Text(m.text!, style: t.body, textDirection: _dirOf(m.text!)),
          if (m.errorTitle != null)
            Text(m.errorTitle!, style: t.caption.copyWith(color: p.error)),
          const SizedBox(height: KSpacing.xxs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (out && m.sentBy != null)
                Flexible(
                  child: Text(
                    '${l10n.waSentBy(_staff(l10n, m.sentBy))} · ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.copyWith(color: p.textTertiary),
                  ),
                ),
              Text(
                KFormat.time(m.at.toLocal(), locale),
                style: t.caption.copyWith(color: p.textTertiary),
              ),
              if (out) ...[
                const SizedBox(width: KSpacing.xs),
                WaTicks(tick: m.tick),
              ],
            ],
          ),
        ],
      ),
    );
    return Align(
      alignment: out
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          bubble,
          if (m.reaction != null)
            PositionedDirectional(
              end: KSpacing.sm,
              bottom: -8,
              child: Text(m.reaction!, style: const TextStyle(fontSize: 16)),
            ),
        ],
      ),
    );
  }
}

String _coords(double lat, double lng) =>
    '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

/// A customer may write in either script: the paragraph follows its first
/// strong letter.
TextDirection? _dirOf(String text) {
  final m = RegExp('[A-Za-z؀-ۿ]').firstMatch(text);
  if (m == null) return null;
  return RegExp('[؀-ۿ]').hasMatch(m.group(0)!)
      ? TextDirection.rtl
      : TextDirection.ltr;
}

/// ✓ sent, ✓✓ delivered, blue ✓✓ read, ⚠ failed.
class WaTicks extends StatelessWidget {
  const new({required this.tick, super.key});

  final WaTick tick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final (IconData icon, Color color, String label) = switch (tick) {
      WaTick.sent => (Icons.done_rounded, p.textTertiary, l10n.waStatusSent),
      WaTick.delivered => (
        Icons.done_all_rounded,
        p.textTertiary,
        l10n.waStatusDelivered,
      ),
      WaTick.read => (Icons.done_all_rounded, p.info, l10n.waStatusRead),
      WaTick.failed => (
        Icons.error_outline_rounded,
        p.error,
        l10n.waStatusFailed,
      ),
      WaTick.received => (Icons.done_rounded, p.textTertiary, ''),
    };
    return Semantics(
      label: label,
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _MediaPart extends ConsumerWidget {
  const new({required this.m});

  final WaMessage m;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final media = m.media!;
    final note = switch (media.state) {
      WaMediaState.tooLarge => l10n.waMediaTooLarge,
      WaMediaState.typeRefused => l10n.waMediaRefused,
      WaMediaState.failed => l10n.waMediaFailed,
      WaMediaState.stored => null,
    };
    if (note != null) {
      return Text(
        note,
        style: t.caption.copyWith(
          color: p.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    if (m.type == 'IMAGE' || m.type == 'STICKER') {
      final bytes = ref.watch(waMediaProvider(m.id));
      return ClipRRect(
        borderRadius: BorderRadius.circular(KRadius.sm),
        child: SizedBox(
          width: 220,
          height: 160,
          child: switch (bytes) {
            AsyncData(:final value) => Image.memory(
              Uint8List.fromList(value),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => _filePlaceholder(context),
            ),
            AsyncError() => _filePlaceholder(context),
            _ => ColoredBox(color: p.surfaceOverlay),
          },
        ),
      );
    }
    if (m.type == 'AUDIO') return _VoicePlayer(m: m);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          m.type == 'VIDEO' ? Icons.movie_outlined : Icons.description_outlined,
          color: p.textSecondary,
        ),
        const SizedBox(width: KSpacing.xs),
        Flexible(
          child: Text(
            media.filename ?? l10n.waOpenFile,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.body,
          ),
        ),
      ],
    );
  }

  Widget _filePlaceholder(BuildContext context) => ColoredBox(
    color: context.palette.surfaceOverlay,
    child: Icon(Icons.image_outlined, color: context.palette.textSecondary),
  );
}

/// A voice note / audio file: the bytes are read on the first tap (never a
/// public URL), then played from memory.
class _VoicePlayer extends ConsumerStatefulWidget {
  const new({required this.m});

  final WaMessage m;

  @override
  ConsumerState<_VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends ConsumerState<_VoicePlayer> {
  AudioPlayer? _player;
  bool _playing = false;
  bool _loading = false;

  @override
  void dispose() {
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player?.pause();
      setState(() => _playing = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final bytes = await ref.read(waMediaProvider(widget.m.id).future);
      final player = _player ??= AudioPlayer()
        ..onPlayerComplete.listen((_) {
          if (mounted) setState(() => _playing = false);
        });
      await player.play(
        BytesSource(Uint8List.fromList(bytes), mimeType: widget.m.media?.mime),
      );
      if (mounted) setState(() => _playing = true);
    } on Object catch (e) {
      if (mounted) KSnack.error(context, waErrorMessage(context.l10n, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: _playing ? l10n.waPause : l10n.waPlay,
          onPressed: _loading ? null : () => unawaited(_toggle()),
          icon: Icon(
            _playing
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_fill_rounded,
            color: p.primary,
            size: 32,
          ),
        ),
        Text(
          widget.m.media!.voice
              ? l10n.waVoice
              : (widget.m.media!.filename ?? l10n.waVoice),
          style: context.textStyles.caption,
        ),
      ],
    );
  }
}

class _BottomAction extends StatelessWidget {
  const new({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.all(KSpacing.md),
      child: KButton(
        label: label,
        onPressed: onPressed,
        variant: KButtonVariant.secondary,
      ),
    ),
  );
}

class _BottomNote extends StatelessWidget {
  const new({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.all(KSpacing.lg),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: context.textStyles.caption.copyWith(
          color: context.palette.textSecondary,
        ),
      ),
    ),
  );
}

/// The composer: text + quick replies + a photo inside the window; outside it
/// only «إرسال قالب». «إرسال» is disabled while a send is in flight (a send
/// to Meta cannot be undone, §10.151.4).
class WaComposer extends ConsumerStatefulWidget {
  const new({
    required this.c,
    required this.onSent,
    required this.onClaim,
    super.key,
  });

  final WaConversation c;
  final VoidCallback onSent;
  final VoidCallback onClaim;

  @override
  ConsumerState<WaComposer> createState() => _WaComposerState();
}

class _WaComposerState extends ConsumerState<WaComposer> {
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send(Future<Object?> Function(WaRepository repo) send) async {
    setState(() => _busy = true);
    try {
      await send(ref.read(waRepositoryProvider));
      _text.clear();
      widget.onSent();
    } on Object catch (e) {
      if (mounted) KSnack.error(context, waErrorMessage(context.l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _quick() async {
    final body = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => const _QuickRepliesSheet(),
    );
    if (body == null) return;
    final cur = _text.text;
    _text.text = cur.isEmpty ? body : '$cur\n$body';
  }

  Future<void> _photo() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final png = file.name.toLowerCase().endsWith('.png');
    await _send(
      (r) => r.sendMedia(
        widget.c.id,
        bytes,
        mime: png ? 'image/png' : 'image/jpeg',
        filename: file.name,
      ),
    );
  }

  Future<void> _template() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => WaTemplateSheet(conversationId: widget.c.id),
    );
    if (sent ?? false) widget.onSent();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    if (!widget.c.windowOpen) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: KButton(
            key: WaChatScreen.templateKey,
            label: l10n.waSendTemplate,
            icon: Icons.description_outlined,
            onPressed: () => unawaited(_template()),
          ),
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.border)),
        ),
        padding: const EdgeInsets.fromLTRB(
          KSpacing.sm,
          KSpacing.xs,
          KSpacing.sm,
          KSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: l10n.waQuickReplies,
              icon: const Icon(Icons.bolt_rounded),
              onPressed: () => unawaited(_quick()),
            ),
            IconButton(
              tooltip: l10n.waAttach,
              icon: const Icon(Icons.image_outlined),
              onPressed: _busy ? null : () => unawaited(_photo()),
            ),
            Expanded(
              child: TextField(
                key: WaChatScreen.composerKey,
                controller: _text,
                minLines: 1,
                maxLines: 5,
                maxLength: 4096,
                buildCounter: (
                  _, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
                decoration: InputDecoration(
                  hintText: l10n.waComposerHint,
                  isDense: true,
                ),
              ),
            ),
            ValueListenableBuilder(
              valueListenable: _text,
              builder: (_, value, _) => IconButton(
                key: WaChatScreen.sendKey,
                tooltip: l10n.waSend,
                icon: Icon(Icons.send_rounded, color: p.primary),
                onPressed: _busy || value.text.trim().isEmpty
                    ? null
                    : () => unawaited(
                        _send(
                          (r) => r.sendText(widget.c.id, value.text.trim()),
                        ),
                      ),
              ),
            ),
            IconButton(
              tooltip: l10n.waSendTemplate,
              icon: const Icon(Icons.description_outlined),
              onPressed: () => unawaited(_template()),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickRepliesSheet extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return FutureBuilder<List<WaQuickReply>>(
      future: ref.read(waRepositoryProvider).quickReplies(),
      builder: (context, snap) {
        final items = snap.data;
        if (items == null) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (items.isEmpty) {
          return SizedBox(
            height: 160,
            child: Center(child: Text(l10n.waNoQuickReplies)),
          );
        }
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final q in items)
                ListTile(
                  title: Text(q.title),
                  subtitle: Text(
                    q.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.of(context).pop(q.body),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// «إرسال قالب»: an approved template and its variables.
class WaTemplateSheet extends ConsumerStatefulWidget {
  const new({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<WaTemplateSheet> createState() => _WaTemplateSheetState();
}

class _WaTemplateSheetState extends ConsumerState<WaTemplateSheet> {
  /// The template's own name and language code (Meta data, not app copy).
  static String _templateLabel(WaTemplate t) => '${t.name} (${t.language})';

  late final Future<List<WaTemplate>> _templates = ref
      .read(waRepositoryProvider)
      .templates();
  WaTemplate? _pick;
  final _params = <int, String>{};
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: FutureBuilder<List<WaTemplate>>(
          future: _templates,
          builder: (context, snap) {
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(KSpacing.lg),
                child: Text(waErrorMessage(l10n, snap.error!)),
              );
            }
            final list = snap.data;
            if (list == null) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(KSpacing.lg),
                child: Text(l10n.waNoTemplates),
              );
            }
            final tpl = _pick ?? list.first;
            final ready = List.generate(
              tpl.parameterCount,
              (i) => (_params[i] ?? '').trim(),
            ).every((v) => v.isNotEmpty);
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(KSpacing.lg),
              children: [
                Text(l10n.waSendTemplate, style: context.textStyles.title),
                const SizedBox(height: KSpacing.md),
                RadioGroup<WaTemplate>(
                  groupValue: tpl,
                  onChanged: (v) => setState(() {
                    _pick = v;
                    _params.clear();
                  }),
                  child: Column(
                    children: [
                      for (final x in list)
                        RadioListTile<WaTemplate>(
                          value: x,
                          title: Text(_templateLabel(x)),
                          subtitle: x.body == null
                              ? null
                              : Text(
                                  x.body!,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                    ],
                  ),
                ),
                for (var i = 0; i < tpl.parameterCount; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: KSpacing.sm),
                    child: TextField(
                      key: Key('wa.param.$i'),
                      decoration: InputDecoration(
                        labelText: l10n.waTemplateParam(i + 1),
                      ),
                      onChanged: (v) => setState(() => _params[i] = v),
                    ),
                  ),
                const SizedBox(height: KSpacing.lg),
                KButton(
                  label: l10n.waSend,
                  loading: _busy,
                  onPressed: !ready || _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            await ref
                                .read(waRepositoryProvider)
                                .sendTemplate(
                                  widget.conversationId,
                                  tpl,
                                  List.generate(
                                    tpl.parameterCount,
                                    (i) => _params[i]!.trim(),
                                  ),
                                );
                            if (context.mounted) {
                              Navigator.of(context).pop(true);
                            }
                          } on Object catch (e) {
                            if (context.mounted) {
                              KSnack.error(context, waErrorMessage(l10n, e));
                            }
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                ),
                const SizedBox(height: KSpacing.md),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AgentsSheet extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return FutureBuilder<List<WaAgent>>(
      future: ref.read(waRepositoryProvider).agents(),
      builder: (context, snap) {
        final items = snap.data;
        if (items == null) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(l10n.waTransferTo, style: context.textStyles.title),
              ),
              for (final a in items)
                ListTile(
                  leading: Icon(
                    Icons.circle,
                    size: 10,
                    color: a.onShift
                        ? context.palette.success
                        : context.palette.textTertiary,
                  ),
                  title: Text(_staff(l10n, a.ref)),
                  subtitle: a.ref.staffId == null ? null : Text(a.ref.staffId!),
                  onTap: () => Navigator.of(context).pop(a.ref.userId),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The customer's details: the linked Kabso account (or «ربط بحساب»: Kabso
/// keeps no verified phone to match, §10.151.7) and the internal notes.
class WaCustomerSheet extends ConsumerStatefulWidget {
  const new({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<WaCustomerSheet> createState() => _WaCustomerSheetState();
}

class _WaCustomerSheetState extends ConsumerState<WaCustomerSheet> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _do(Future<Object?> Function(WaRepository r) f) async {
    try {
      await f(ref.read(waRepositoryProvider));
      _input.clear();
      ref.invalidate(waThreadProvider(widget.conversationId));
    } on Object catch (e) {
      if (mounted) KSnack.error(context, waErrorMessage(context.l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final thread = ref.watch(waThreadProvider(widget.conversationId)).value;
    if (thread == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final c = thread.conversation;
    final a = c.linkedAccount;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(KSpacing.lg),
          children: [
            Text(l10n.waCustomer, style: t.title),
            Text(waPhone(c.phone), style: t.body),
            const SizedBox(height: KSpacing.md),
            Text(l10n.waAccount, style: t.bodyStrong),
            if (a != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: KAvatar(name: a.displayName, imageUrl: a.avatarUrl),
                title: Text(a.displayName),
                subtitle: Text(
                  '${KFormat.bidiIsolate('@${a.username}')} · '
                  '${KFormat.date(a.createdAt.toLocal(), locale)}',
                ),
                trailing: TextButton(
                  onPressed: () => unawaited(_do((r) => r.unlink(c.id))),
                  child: Text(l10n.waUnlink),
                ),
              )
            else ...[
              Text(
                l10n.waNoAccount,
                style: t.caption.copyWith(color: p.textSecondary),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: InputDecoration(
                        hintText: l10n.waUsername,
                        isDense: true,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final u = _input.text.trim();
                      if (u.isNotEmpty) unawaited(_do((r) => r.link(c.id, u)));
                    },
                    child: Text(l10n.waLink),
                  ),
                ],
              ),
            ],
            const SizedBox(height: KSpacing.lg),
            Text(l10n.waNotes, style: t.bodyStrong),
            Text(
              l10n.waNotesHint,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
            if (thread.notes.isEmpty) Text(l10n.waNoNotes, style: t.caption),
            for (final n in thread.notes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(n.body),
                subtitle: Text(
                  '${_staff(l10n, n.author)} · '
                  '${KFormat.time(n.at.toLocal(), locale)}',
                ),
              ),
            _NoteInput(onAdd: (body) => _do((r) => r.addNote(c.id, body))),
          ],
        ),
      ),
    );
  }
}

class _NoteInput extends StatefulWidget {
  const new({required this.onAdd});

  final Future<void> Function(String body) onAdd;

  @override
  State<_NoteInput> createState() => _NoteInputState();
}

class _NoteInputState extends State<_NoteInput> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: TextField(
          controller: _c,
          maxLength: 2000,
          buildCounter: (
            _, {
            required currentLength,
            required isFocused,
            maxLength,
          }) => null,
          decoration: InputDecoration(
            hintText: context.l10n.waAddNote,
            isDense: true,
          ),
        ),
      ),
      IconButton(
        tooltip: context.l10n.waAddNote,
        icon: const Icon(Icons.note_add_outlined),
        onPressed: () async {
          final v = _c.text.trim();
          if (v.isEmpty) return;
          await widget.onAdd(v);
          _c.clear();
        },
      ),
    ],
  );
}
