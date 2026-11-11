import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/messages/widgets/chat_composer.dart';
import 'package:kabso_live/features/messages/widgets/dm_message_view.dart';
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

  /// D366: the department filter's chips (null: «كل الأقسام»).
  static const departmentsKey = Key('wa.departments');
  static Key departmentChip(WaDepartment? d) =>
      Key('wa.department.${d?.wire ?? 'all'}');

  @override
  ConsumerState<WaInboxScreen> createState() => _WaInboxScreenState();
}

class _WaInboxScreenState extends ConsumerState<WaInboxScreen> {
  WaFilter _filter = WaFilter.unassigned;
  String _q = '';
  WaDepartment? _department;
  Timer? _debounce;
  Timer? _poll;

  WaListKey get _key => (filter: _filter, q: _q, department: _department);

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
          // D366 (§10.159.4): one department's conversations — with
          // «غير مسندة», its queue.
          SingleChildScrollView(
            key: WaInboxScreen.departmentsKey,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
            child: Row(
              children: [
                for (final d in <WaDepartment?>[null, ...WaDepartment.values])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: KSpacing.xs),
                    child: KChip(
                      key: WaInboxScreen.departmentChip(d),
                      label: d == null
                          ? l10n.waDeptAll
                          : waDepartmentName(l10n, d),
                      selected: _department == d,
                      onSelected: () => setState(() => _department = d),
                    ),
                  ),
              ],
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

/// A phone number reads left to right inside Arabic. D365: grouped for the
/// eye («+966 50 000 1001») and isolated left to right (LRI … PDI) so the
/// «+» stays in front inside an Arabic line.
String waPhone(String e164) => '\u2066${waPhoneGroups(e164)}\u2069';

/// D365: an E.164 number in its national groups — the Gulf / Arab codes the
/// customers write from, North America and the UK; any other number as
/// `+cc rest` in threes. Not a number → unchanged.
String waPhoneGroups(String e164) {
  final digits = e164.replaceAll(RegExp('[^0-9]'), '');
  if (!e164.trim().startsWith('+') || digits.length < 8) return e164.trim();
  // Country code → the national number's groups (by its length).
  const plans = <String, Map<int, List<int>>>{
    '966': {
      9: [2, 3, 4],
    },
    '971': {
      9: [2, 3, 4],
    },
    '965': {
      8: [4, 4],
    },
    '974': {
      8: [4, 4],
    },
    '973': {
      8: [4, 4],
    },
    '968': {
      8: [4, 4],
    },
    '962': {
      9: [1, 4, 4],
    },
    '964': {
      10: [3, 3, 4],
    },
    '20': {
      10: [2, 4, 4],
    },
    '212': {
      9: [3, 2, 2, 2],
    },
    '44': {
      10: [4, 6],
    },
    '1': {
      10: [3, 3, 4],
    },
  };
  for (final cc in plans.keys) {
    if (!digits.startsWith(cc)) continue;
    final rest = digits.substring(cc.length);
    final groups = plans[cc]![rest.length];
    if (groups == null) continue;
    final out = <String>[];
    var i = 0;
    for (final g in groups) {
      out.add(rest.substring(i, i + g));
      i += g;
    }
    return '+$cc ${out.join(' ')}';
  }
  // Unknown plan: the first 3 digits as the code, the rest in threes.
  final cc = digits.substring(0, 3);
  final rest = digits.substring(3);
  final out = <String>[
    for (var i = 0; i < rest.length; i += 3)
      rest.substring(i, math.min(i + 3, rest.length)),
  ];
  return '+$cc ${out.join(' ')}';
}

String _staff(AppLocalizations l10n, WaStaffRef? s) =>
    s?.label ?? l10n.waSomeone;

/// D366 (§10.159): a department's name in the app's language.
String waDepartmentName(AppLocalizations l10n, WaDepartment d) => switch (d) {
  WaDepartment.payments => l10n.waDeptPAYMENTS,
  WaDepartment.agencies => l10n.waDeptAGENCIES,
  WaDepartment.technical => l10n.waDeptTECHNICAL,
  WaDepartment.reports => l10n.waDeptREPORTS,
  WaDepartment.general => l10n.waDeptGENERAL,
};

/// D366: each department's icon (the chip, the sheet).
IconData waDepartmentIcon(WaDepartment d) => switch (d) {
  WaDepartment.payments => Icons.payments_outlined,
  WaDepartment.agencies => Icons.groups_outlined,
  WaDepartment.technical => Icons.build_outlined,
  WaDepartment.reports => Icons.flag_outlined,
  WaDepartment.general => Icons.forum_outlined,
};

/// D366: the conversation's department as a small neutral pill (inbox rows,
/// the chat's status strip), read as «القسم: …».
class WaDepartmentPill extends StatelessWidget {
  const new({required this.department, super.key});

  static const pillKey = Key('wa.departmentPill');

  final WaDepartment department;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = waDepartmentName(l10n, department);
    return Semantics(
      key: pillKey,
      label: l10n.waDeptLabel(name),
      excludeSemantics: true,
      child: WaPill(
        label: name,
        color: context.palette.textSecondary,
        icon: waDepartmentIcon(department),
      ),
    );
  }
}

/// D365: one inbox row, in the Messages tab's language (D336): the picture,
/// the name (or the number, formatted), the time and the unread count under
/// it, the last message, and who has it as a small tinted chip.
class WaConversationTile extends StatelessWidget {
  const new({required this.c, required this.onTap, super.key});

  final WaConversation c;
  final VoidCallback onTap;

  static const double avatar = 52;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final now = clock.now();
    final unread = c.unreadCount > 0;
    final time =
        KFormat.relativeShort(c.lastMessageAt, now, l10n, locale) ??
        l10n.feedPostJustNow;
    final tag = !c.open
        ? l10n.waClosed
        : c.assignedToMe
        ? l10n.waAssignedToMe
        : c.assignedTo != null
        ? l10n.waAssignedTo(_staff(l10n, c.assignedTo))
        : c.department != WaDepartment.general
        ? l10n.waQueueOf(waDepartmentName(l10n, c.department))
        : l10n.waUnassigned;
    final tagColor = !c.open
        ? p.textTertiary
        : c.assignedToMe
        ? p.info
        : c.assignedTo == null
        ? p.success
        : p.textSecondary;
    final named = c.name != null;
    return Material(
      color: p.background,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            KSpacing.lg,
            KSpacing.sm + 2,
            KSpacing.lg,
            KSpacing.sm + 2,
          ),
          child: Row(
            children: [
              KAvatar(name: c.title, size: avatar),
              const SizedBox(width: KSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      named ? c.name! : waPhone(c.phone),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyStrong.copyWith(
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: KSpacing.xxs),
                    Text(
                      c.lastPreview ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.body.copyWith(
                        fontSize: 14,
                        color: unread ? p.textSecondary : p.textTertiary,
                      ),
                    ),
                    const SizedBox(height: KSpacing.xs),
                    Wrap(
                      spacing: KSpacing.xs,
                      runSpacing: KSpacing.xxs,
                      children: [
                        WaPill(label: tag, color: tagColor),
                        WaDepartmentPill(department: c.department),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KSpacing.sm),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    time,
                    maxLines: 1,
                    style: t.caption.copyWith(
                      color: unread ? p.primaryText : p.textTertiary,
                      fontWeight: unread ? FontWeight.w600 : null,
                    ),
                  ),
                  const SizedBox(height: KSpacing.sm),
                  if (unread)
                    WaCountBadge(count: c.unreadCount)
                  else
                    const SizedBox(height: 22),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// D365: a small tinted label (who has the conversation, the reply window,
/// «مشاهدة فقط»): the colour at 14 % behind its own text.
class WaPill extends StatelessWidget {
  const new({required this.label, required this.color, super.key, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.sm,
        vertical: KSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: KSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.caption.copyWith(
                color: Color.lerp(color, p.textPrimary, 0.25),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
/// window chip — closed → the composer is «إرسال قالب» only — claim /
/// release / transfer / close / reopen, and the customer's details (the
/// linked Kabso account, the internal notes).
///
/// D365 (owner: «شكل مسجات واتساب في التطبيق سيء»): the look of Kabso's own
/// conversation (D68/D69/D336) — the header with the picture, the name and
/// the number, a status strip (the window's countdown, who has it, «مشاهدة
/// فقط»), DM bubbles grouped by sender with day separators, and the DM
/// composer's shape. Behaviour unchanged.
class WaChatScreen extends ConsumerStatefulWidget {
  const new({required this.conversationId, super.key});

  final String conversationId;

  static const composerKey = Key('wa.composer');
  static const sendKey = Key('wa.send');
  static const templateKey = Key('wa.template');
  static const windowClosedKey = Key('wa.windowClosed');
  static const menuKey = Key('wa.menu');
  static const detailsKey = Key('wa.details');

  /// D366: the header's «تحويل» button (REPLY+, open conversations).
  static const transferKey = Key('wa.transfer');

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
    // D360: a viewer («مشاهدة فقط») never marks read — the conversation
    // stays unread for those who can answer, the customer sees no blue ticks.
    if (_readSent || c.unreadCount == 0 || ref.read(waViewOnlyProvider)) {
      return;
    }
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

  /// D366 (§10.159.2): the transfer sheet — a department, «أول متاح في
  /// القسم» or one of its agents, a note — then a toast with where it went.
  Future<void> _transfer(WaConversation c) async {
    final choice = await showModalBottomSheet<WaTransferChoice>(
      context: context,
      isScrollControlled: true,
      builder: (_) => WaTransferSheet(conversation: c),
    );
    if (choice == null || !mounted) return;
    final l10n = context.l10n;
    try {
      final after = await ref
          .read(waRepositoryProvider)
          .transfer(
            _id,
            department: choice.department,
            toUserId: choice.to?.ref.userId,
            note: choice.note,
          );
      if (mounted) {
        KSnack.success(
          context,
          after.assignedTo != null
              ? l10n.waTransferDoneTo(_staff(l10n, after.assignedTo))
              : l10n.waTransferDoneQueue(
                  waDepartmentName(l10n, after.department),
                ),
        );
      }
      _reload();
    } on Object catch (e) {
      if (mounted) KSnack.error(context, waErrorMessage(l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final thread = ref.watch(waThreadProvider(_id));
    final viewOnly = ref.watch(waViewOnlyProvider);
    final c = thread.value?.conversation;
    if (c != null) _markReadOnce(c);
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        titleSpacing: 0,
        title: c == null
            ? Text(l10n.waTitle)
            : Row(
                children: [
                  KAvatar(name: c.title, size: KSizes.avatarSm + 4),
                  const SizedBox(width: KSpacing.sm),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          c.name ?? waPhone(c.phone),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyStrong.copyWith(color: p.textPrimary),
                        ),
                        if (c.name != null)
                          Text(
                            waPhone(c.phone),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.caption.copyWith(color: p.textSecondary),
                          ),
                      ],
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
          // D366: «تحويل» in the header, beside the customer button (not in
          // the menu any more); never for VIEW or a closed conversation.
          if (c != null && !viewOnly && c.open)
            IconButton(
              key: WaChatScreen.transferKey,
              tooltip: l10n.waTransfer,
              icon: const Icon(Icons.swap_horiz_rounded),
              onPressed: () => unawaited(_transfer(c)),
            ),
          // D360: VIEW reads only — no actions menu (the label is in the
          // status strip).
          if (c != null && !viewOnly)
            PopupMenuButton<String>(
              key: WaChatScreen.menuKey,
              tooltip: l10n.waMenu,
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (a) => unawaited(_run((r) => r.act(_id, a))),
              itemBuilder: (_) => [
                if (c.open && c.assignedTo == null)
                  PopupMenuItem(value: 'claim', child: Text(l10n.waClaim)),
                if (c.open && c.assignedTo != null)
                  PopupMenuItem(value: 'release', child: Text(l10n.waRelease)),
                if (c.open)
                  PopupMenuItem(value: 'close', child: Text(l10n.waClose)),
                if (!c.open)
                  PopupMenuItem(value: 'reopen', child: Text(l10n.waReopen)),
              ],
            ),
          const SizedBox(width: KSpacing.xs),
        ],
      ),
      body: switch (thread) {
        AsyncData(:final value) => WaChatBody(
          thread: value,
          viewOnly: viewOnly,
          onSent: _reload,
          onClaim: () => unawaited(_run((r) => r.act(_id, 'claim'))),
          onReopen: () => unawaited(_run((r) => r.act(_id, 'reopen'))),
          onRetry: (m) => unawaited(_run((r) => r.sendText(_id, m.text!))),
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

/// D365: why Meta refused a sent message, in the app's language — Meta's
/// own title (English) is never shown.
String waFailReason(AppLocalizations l10n, int? metaCode) => switch (metaCode) {
  131047 || 470 => l10n.waErrWindow,
  131026 => l10n.waFailUndeliverable,
  131051 => l10n.waFailUnsupported,
  130429 || 131056 || 80007 || 4 => l10n.waFailRate,
  _ => l10n.waErrSend,
};

/// The chat without its loading (the goldens pump it with a fixed thread).
class WaChatBody extends StatelessWidget {
  const new({
    required this.thread,
    required this.onSent,
    required this.onClaim,
    required this.onReopen,
    this.onRetry,
    this.viewOnly = false,
    super.key,
  });

  static const viewOnlyKey = Key('wa.viewOnly');

  final WaThread thread;
  final VoidCallback onSent;
  final VoidCallback onClaim;
  final VoidCallback onReopen;

  /// D365: sends a failed text again (a new message); null hides it.
  final ValueChanged<WaMessage>? onRetry;

  /// D360 (§10.155): the WhatsApp level VIEW — no composer, no reopen, the
  /// «مشاهدة فقط» note instead.
  final bool viewOnly;

  @override
  Widget build(BuildContext context) {
    final c = thread.conversation;
    final l10n = context.l10n;
    final messages = thread.messages;
    final canRetry = !viewOnly && c.open && c.windowOpen && !c.takenByOther;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WaWindowBanner(c: c, viewOnly: viewOnly),
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.symmetric(vertical: KSpacing.md),
            itemCount: messages.length,
            // The API answers newest first: [i + 1] is the older neighbour.
            itemBuilder: (context, i) {
              final m = messages[i];
              final older = i + 1 < messages.length ? messages[i + 1] : null;
              final newer = i > 0 ? messages[i - 1] : null;
              final newDay = older == null || !_sameDay(older.at, m.at);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (newDay) WaDaySeparator(day: m.at),
                  WaBubble(
                    m: m,
                    first: newDay || !_joins(older, m),
                    last: newer == null || !_joins(m, newer),
                    onRetry:
                        canRetry &&
                            m.outbound &&
                            m.tick == WaTick.failed &&
                            m.type == 'TEXT' &&
                            (m.text?.isNotEmpty ?? false) &&
                            onRetry != null
                        ? () => onRetry!(m)
                        : null,
                  ),
                ],
              );
            },
          ),
        ),
        if (viewOnly)
          _BottomNote(
            key: viewOnlyKey,
            icon: Icons.visibility_outlined,
            text: l10n.waViewOnlyHint,
          )
        else if (!c.open)
          _BottomAction(label: l10n.waReopen, onPressed: onReopen)
        else if (c.takenByOther)
          _BottomNote(
            icon: Icons.lock_outline_rounded,
            text: l10n.waErrAssigned,
          )
        else
          WaComposer(c: c, onSent: onSent, onClaim: onClaim),
      ],
    );
  }
}

bool _sameDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// D365: two messages read as one run — same side, same sender, same day,
/// at most [_runGap] apart.
const _runGap = Duration(minutes: 5);

bool _joins(WaMessage? older, WaMessage newer) {
  if (older == null) return false;
  if (older.outbound != newer.outbound) return false;
  if (older.outbound && older.sentBy?.userId != newer.sentBy?.userId) {
    return false;
  }
  if (!_sameDay(older.at, newer.at)) return false;
  return newer.at.difference(older.at).abs() <= _runGap;
}

/// D365: the centred day pill — «اليوم», «أمس», else the date.
class WaDaySeparator extends StatelessWidget {
  const new({required this.day, super.key});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final now = clock.now();
    final local = day.toLocal();
    final today = DateTime(
      now.toLocal().year,
      now.toLocal().month,
      now.toLocal().day,
    );
    final that = DateTime(local.year, local.month, local.day);
    final days = today.difference(that).inDays;
    final label = days == 0
        ? l10n.chatToday
        : days == 1
        ? l10n.waYesterday
        : KFormat.date(local, Localizations.localeOf(context).toLanguageTag());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _incomingFill(context),
            borderRadius: BorderRadius.circular(KRadius.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.md,
              vertical: KSpacing.xs,
            ),
            child: Text(
              label,
              style: context.textStyles.caption.copyWith(
                color: p.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A received bubble's fill: raised in the dark theme, the overlay grey in
/// the light one (where `surfaceRaised` is the page white, D68).
Color _incomingFill(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? context.palette.surfaceRaised
    : context.palette.surfaceOverlay;

/// D365: the status strip under the header (the place of DM's notice, D155):
/// the reply window's countdown — or «مغلقة — قالب فقط» — who has the
/// conversation, and «مشاهدة فقط» for the level VIEW (D360).
class WaWindowBanner extends StatelessWidget {
  const new({required this.c, this.viewOnly = false, super.key});

  final WaConversation c;
  final bool viewOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final closes = c.windowClosesAt;
    final Widget window;
    if (!c.open) {
      window = WaPill(
        label: l10n.waClosed,
        color: p.textTertiary,
        icon: Icons.archive_outlined,
      );
    } else if (c.windowOpen && closes != null) {
      final left = closes.difference(clock.now());
      final minutes = left.isNegative ? 0 : (left.inSeconds / 60).ceil();
      final tag = Localizations.localeOf(context).toLanguageTag();
      window = Semantics(
        label: l10n.waWindowOpen(
          '${KFormat.date(closes.toLocal(), tag)} '
          '${KFormat.time(closes.toLocal(), tag)}',
        ),
        excludeSemantics: true,
        child: WaPill(
          label: minutes >= 60
              ? l10n.waWindowLeftHours(minutes ~/ 60)
              : l10n.waWindowLeftMinutes(minutes),
          color: minutes >= 60 ? p.success : p.warning,
          icon: Icons.schedule_rounded,
        ),
      );
    } else {
      window = Semantics(
        key: WaChatScreen.windowClosedKey,
        label: closes == null ? l10n.waWindowNever : l10n.waWindowClosed,
        excludeSemantics: true,
        child: WaPill(
          label: l10n.waWindowClosedChip,
          color: p.warning,
          icon: Icons.lock_clock_outlined,
        ),
      );
    }
    final owner = !c.open
        ? null
        : c.assignedToMe
        ? (l10n.waAssignedToMe, p.info)
        : c.assignedTo != null
        ? (l10n.waAssignedTo(_staff(l10n, c.assignedTo)), p.textSecondary)
        : c.department != WaDepartment.general
        ? (l10n.waQueueOf(waDepartmentName(l10n, c.department)), p.success)
        : (l10n.waUnassigned, p.success);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.md,
        vertical: KSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Wrap(
        spacing: KSpacing.xs,
        runSpacing: KSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          window,
          if (owner != null)
            WaPill(
              label: owner.$1,
              color: owner.$2,
              icon: Icons.support_agent_rounded,
            ),
          WaDepartmentPill(department: c.department),
          if (viewOnly) const WaViewOnlyLabel(),
        ],
      ),
    );
  }
}

/// One message as a Kabso DM bubble (D68/D69, [KDmBubble]): the staff's on
/// the end side in the red gradient, the customer's on the start side in the
/// raised grey. [first] / [last]: its place in a run of the same sender —
/// the joined corners tighten, the tail only on the last, the staff name
/// only on the first.
class WaBubble extends StatelessWidget {
  const new({
    required this.m,
    super.key,
    this.first = true,
    this.last = true,
    this.onRetry,
  });

  final WaMessage m;
  final bool first;
  final bool last;

  /// D365: «إعادة الإرسال» under a failed text (null: not offered).
  final VoidCallback? onRetry;

  static const failedKey = Key('wa.failed');
  static const retryKey = Key('wa.retry');

  static const double _joined = 6;

  BorderRadiusDirectional _corners() {
    const round = Radius.circular(KDmBubble.radius);
    final top = first ? round : const Radius.circular(_joined);
    final bottom = last
        ? const Radius.circular(KDmBubble.tailRadius)
        : const Radius.circular(_joined);
    return m.outbound
        ? BorderRadiusDirectional.only(
            topStart: round,
            bottomStart: round,
            topEnd: top,
            bottomEnd: bottom,
          )
        : BorderRadiusDirectional.only(
            topEnd: round,
            bottomEnd: round,
            topStart: top,
            bottomStart: bottom,
          );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final out = m.outbound;
    final fg = out ? p.onPrimary : p.textPrimary;
    final soft = out ? p.onPrimary.withValues(alpha: 0.78) : p.textTertiary;
    final corners = _corners();
    final picture =
        (m.type == 'IMAGE' || m.type == 'STICKER') &&
        m.media?.state == WaMediaState.stored;
    final textStyle = t.body.copyWith(
      fontSize: KDmBubble.textSize,
      height: KDmBubble.textHeight,
      color: fg,
    );
    final meta = _WaMeta(m: m, color: soft);
    final body = <Widget>[
      if (out && first && m.sentBy != null)
        Padding(
          padding: const EdgeInsets.only(bottom: KSpacing.xxs),
          child: Semantics(
            label: l10n.waSentBy(_staff(l10n, m.sentBy)),
            excludeSemantics: true,
            child: Text(
              _staff(l10n, m.sentBy),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.caption.copyWith(
                color: soft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      if (m.templateName != null)
        Padding(
          padding: const EdgeInsets.only(bottom: KSpacing.xxs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_outlined, size: 13, color: soft),
              const SizedBox(width: KSpacing.xxs),
              Flexible(
                child: Text(
                  l10n.waTemplateTag(m.templateName!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption.copyWith(color: soft),
                ),
              ),
            ],
          ),
        ),
      if (m.media != null && !picture) _MediaPart(m: m, color: fg),
      if (m.latitude != null && m.longitude != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.place_outlined, size: 20, color: fg),
            const SizedBox(width: KSpacing.xs),
            Flexible(
              child: Text(
                '${m.locationName ?? l10n.waLocation}\n'
                '${KFormat.bidiIsolate(_coords(m.latitude!, m.longitude!))}',
                style: textStyle,
              ),
            ),
          ],
        ),
      if (m.type == 'UNSUPPORTED')
        Text(
          l10n.waUnsupported,
          style: t.caption.copyWith(color: soft, fontStyle: FontStyle.italic),
        ),
      if (m.text != null && m.text!.isNotEmpty)
        Text(m.text!, style: textStyle, textDirection: _dirOf(m.text!)),
    ];
    final maxWidth = math.min(
      KDmBubble.maxWidth,
      MediaQuery.sizeOf(context).width * 0.78,
    );
    final Widget bubble;
    if (picture) {
      bubble = _WaPicture(m: m, corners: corners, meta: meta, out: out);
    } else {
      bubble = Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(
          horizontal: KDmBubble.paddingH,
          vertical: KDmBubble.paddingV - 2,
        ),
        decoration: BoxDecoration(
          color: out ? null : _incomingFill(context),
          gradient: out
              ? LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [
                    Color.lerp(p.primary, KBrandColors.red400, 0.35)!,
                    p.primary,
                  ],
                )
              : null,
          borderRadius: corners,
          // A soft lift; none under a received bubble in the dark theme
          // (a light shadow there reads as a rim).
          boxShadow: [
            if (out || Theme.of(context).brightness == Brightness.light)
              BoxShadow(
                color: (out ? p.primary : p.textPrimary).withValues(
                  alpha: out ? 0.16 : 0.05,
                ),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ...body,
            // The time and ticks sit small at the bubble's bottom end.
            Align(
              alignment: AlignmentDirectional.centerEnd,
              widthFactor: 1,
              child: Padding(
                padding: const EdgeInsets.only(top: KSpacing.xxs),
                child: meta,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: KSpacing.md,
        end: KSpacing.md,
        top: first ? KDmBubble.rowGap : KSpacing.xxs / 2,
        bottom:
            (last ? KDmBubble.rowGap : KSpacing.xxs / 2) +
            (m.reaction != null ? KSpacing.sm : 0),
      ),
      child: Column(
        crossAxisAlignment: out
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              bubble,
              if (m.reaction != null)
                PositionedDirectional(
                  start: KSpacing.sm,
                  bottom: -14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.xs + 2,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: p.surfaceRaised,
                      borderRadius: BorderRadius.circular(KRadius.pill),
                      border: Border.all(color: p.background, width: 2),
                    ),
                    child: Text(
                      m.reaction!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
            ],
          ),
          if (out && m.tick == WaTick.failed)
            _FailedLine(m: m, onRetry: onRetry),
        ],
      ),
    );
  }
}

/// D365: under a failed staff message — «تعذّر الإرسال» (tap: the reason in
/// words) and, for a text inside the window, «إعادة الإرسال».
class _FailedLine extends StatelessWidget {
  const new({required this.m, this.onRetry});

  final WaMessage m;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final reason = waFailReason(l10n, m.errorCode);
    return Padding(
      padding: const EdgeInsets.only(top: KSpacing.xs),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: KSpacing.xs,
        children: [
          Tooltip(
            key: WaBubble.failedKey,
            message: reason,
            triggerMode: TooltipTriggerMode.tap,
            showDuration: const Duration(seconds: 5),
            child: Semantics(
              label: '${l10n.waFailed}. $reason',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: KSpacing.xxs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 15, color: p.error),
                    const SizedBox(width: KSpacing.xxs),
                    Text(
                      l10n.waFailed,
                      style: t.caption.copyWith(
                        color: p.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: KSpacing.xxs),
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: p.textTertiary,
                      semanticLabel: l10n.waFailDetails,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onRetry != null)
            TextButton.icon(
              key: WaBubble.retryKey,
              onPressed: onRetry,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
                foregroundColor: p.primaryText,
                textStyle: t.caption.copyWith(fontWeight: FontWeight.w700),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(l10n.waRetry),
            ),
        ],
      ),
    );
  }
}

/// The time and, on the staff's messages, the ticks.
class _WaMeta extends StatelessWidget {
  const new({required this.m, required this.color});

  final WaMessage m;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        KFormat.time(
          m.at.toLocal(),
          Localizations.localeOf(context).toLanguageTag(),
        ),
        style: context.textStyles.caption.copyWith(
          fontSize: KDmBubble.metaSize,
          color: color,
        ),
      ),
      if (m.outbound) ...[
        const SizedBox(width: KSpacing.xxs),
        WaTicks(tick: m.tick, color: color),
      ],
    ],
  );
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

/// ✓ sent, ✓✓ delivered, ✓✓ read (full strength, a little larger), ⚠
/// failed. D365: inside the red bubble the ticks take its text colour
/// ([color]); without one, the palette's (blue for read).
class WaTicks extends StatelessWidget {
  const new({required this.tick, super.key, this.color});

  final WaTick tick;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final base = color ?? p.textTertiary;
    final strong = color?.withValues(alpha: 1) ?? p.info;
    final (IconData icon, Color c, String label) = switch (tick) {
      WaTick.sent => (Icons.done_rounded, base, l10n.waStatusSent),
      WaTick.delivered => (
        Icons.done_all_rounded,
        base,
        l10n.waStatusDelivered,
      ),
      WaTick.read => (Icons.done_all_rounded, strong, l10n.waStatusRead),
      WaTick.failed => (
        Icons.error_outline_rounded,
        color == null ? p.error : strong,
        l10n.waStatusFailed,
      ),
      WaTick.received => (Icons.done_rounded, base, ''),
    };
    return Semantics(
      label: label,
      child: Icon(
        icon,
        size: tick == WaTick.read ? KDmBubble.tickSize + 1 : KDmBubble.tickSize,
        color: c,
      ),
    );
  }
}

/// A stored picture, as DM shows one (D68): no bubble, the corners of its
/// run, the time on a dark pill at its bottom end.
class _WaPicture extends ConsumerWidget {
  const new({
    required this.m,
    required this.corners,
    required this.meta,
    required this.out,
  });

  final WaMessage m;
  final BorderRadiusDirectional corners;
  final Widget meta;
  final bool out;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final bytes = ref.watch(waMediaProvider(m.id));
    Widget placeholder() => ColoredBox(
      color: _incomingFill(context),
      child: Icon(Icons.image_outlined, color: p.textTertiary),
    );
    return ClipRRect(
      borderRadius: corners,
      child: SizedBox(
        width: KDmBubble.picture.width + 40,
        height: KDmBubble.picture.width,
        child: Stack(
          fit: StackFit.expand,
          children: [
            switch (bytes) {
              AsyncData(:final value) => Image.memory(
                Uint8List.fromList(value),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => placeholder(),
              ),
              AsyncError() => placeholder(),
              _ => ColoredBox(color: _incomingFill(context)),
            },
            PositionedDirectional(
              end: KSpacing.sm,
              bottom: KSpacing.sm,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: KPalette.dark.scrim.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(KRadius.pill),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KSpacing.sm,
                    vertical: KSpacing.xxs,
                  ),
                  child: _WaMeta(m: m, color: KPalette.dark.textPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaPart extends StatelessWidget {
  const new({required this.m, required this.color});

  final WaMessage m;

  /// The bubble's text colour.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final media = m.media!;
    final note = switch (media.state) {
      WaMediaState.tooLarge => l10n.waMediaTooLarge,
      WaMediaState.typeRefused => l10n.waMediaRefused,
      WaMediaState.failed => l10n.waMediaFailed,
      WaMediaState.stored => null,
    };
    if (note != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.block_rounded,
            size: 16,
            color: color.withValues(alpha: 0.7),
          ),
          const SizedBox(width: KSpacing.xs),
          Flexible(
            child: Text(
              note,
              style: t.caption.copyWith(
                color: color.withValues(alpha: 0.85),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      );
    }
    if (m.type == 'AUDIO') return _VoicePlayer(m: m, color: color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            m.type == 'VIDEO'
                ? Icons.movie_outlined
                : Icons.description_outlined,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(width: KSpacing.sm),
        Flexible(
          child: Text(
            media.filename ?? l10n.waOpenFile,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.body.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// A voice note / audio file, in DM's voice-note shape (D155): play, a wave,
/// the label. The bytes are read on the first tap (never a public URL), then
/// played from memory.
class _VoicePlayer extends ConsumerStatefulWidget {
  const new({required this.m, required this.color});

  final WaMessage m;
  final Color color;

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
    final fg = widget.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 40,
          child: IconButton(
            tooltip: _playing ? l10n.waPause : l10n.waPlay,
            padding: EdgeInsets.zero,
            onPressed: _loading ? null : () => unawaited(_toggle()),
            icon: Icon(
              _playing
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              color: fg,
              size: 34,
            ),
          ),
        ),
        const SizedBox(width: KSpacing.xxs),
        Icon(
          Icons.graphic_eq_rounded,
          size: 22,
          color: fg.withValues(alpha: 0.8),
        ),
        const SizedBox(width: KSpacing.xs),
        Flexible(
          child: Text(
            widget.m.media!.voice
                ? l10n.waVoice
                : (widget.m.media!.filename ?? l10n.waVoice),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.caption.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
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
  Widget build(BuildContext context) => _ComposerSurface(
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

/// The bar in the composer's place (VIEW, another agent's conversation).
class _BottomNote extends StatelessWidget {
  const new({required this.text, required this.icon, super.key});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _ComposerSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.lg,
          vertical: KSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: p.textSecondary),
            const SizedBox(width: KSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: context.textStyles.caption.copyWith(
                  color: p.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The composer's floor, as DM's (D69): the page colour, a soft shadow over
/// the thread.
class _ComposerSurface extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.background,
        boxShadow: [
          BoxShadow(
            color: p.textPrimary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

/// v1.120-social (D360, §10.155): «مشاهدة فقط» — the chip for a staff
/// member whose WhatsApp level is VIEW (no actions menu). D365: in the
/// status strip.
class WaViewOnlyLabel extends StatelessWidget {
  const new({super.key});

  static const labelKey = Key('wa.viewOnlyLabel');

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.waViewOnlyHint,
    excludeSemantics: true,
    child: WaPill(
      key: labelKey,
      label: context.l10n.waViewOnly,
      color: context.palette.warning,
      icon: Icons.visibility_outlined,
    ),
  );
}

/// The composer, in DM's shape (D68, [KChatComposer]): a round «+» (a photo,
/// a template), the pill field with the quick replies inside it, and the
/// round red send button. Outside the window only «إرسال قالب», with the
/// reason above it. «إرسال» is disabled while a send is in flight (a send
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

  static const attachKey = Key('wa.attach');
  static const attachPhotoKey = Key('wa.attach.photo');
  static const attachTemplateKey = Key('wa.attach.template');
  static const quickKey = Key('wa.quick');

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

  Future<void> _attach() async {
    final l10n = context.l10n;
    final pick = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: WaComposer.attachPhotoKey,
              leading: const Icon(Icons.image_outlined),
              title: Text(l10n.waAttachPhoto),
              onTap: () => Navigator.of(sheet).pop('photo'),
            ),
            ListTile(
              key: WaComposer.attachTemplateKey,
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.waSendTemplate),
              onTap: () => Navigator.of(sheet).pop('template'),
            ),
          ],
        ),
      ),
    );
    switch (pick) {
      case 'photo':
        await _photo();
      case 'template':
        await _template();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    if (!widget.c.windowOpen) {
      return _ComposerSurface(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.md,
            KSpacing.sm + 2,
            KSpacing.md,
            KSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_clock_outlined, size: 16, color: p.warning),
                  const SizedBox(width: KSpacing.xs),
                  Expanded(
                    child: Text(
                      widget.c.windowClosesAt == null
                          ? l10n.waWindowNever
                          : l10n.waWindowClosed,
                      style: t.caption.copyWith(color: p.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KSpacing.sm),
              KButton(
                key: WaChatScreen.templateKey,
                label: l10n.waSendTemplate,
                icon: Icons.description_outlined,
                onPressed: () => unawaited(_template()),
              ),
            ],
          ),
        ),
      );
    }
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(KRadius.pill),
      borderSide: BorderSide(color: p.border),
    );
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return _ComposerSurface(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox.square(
              dimension: KChatComposer.button,
              child: IconButton(
                key: WaComposer.attachKey,
                tooltip: l10n.waAttach,
                padding: EdgeInsets.zero,
                onPressed: _busy ? null : () => unawaited(_attach()),
                style: IconButton.styleFrom(
                  shape: CircleBorder(side: BorderSide(color: p.border)),
                ),
                icon: Icon(
                  Icons.add_rounded,
                  size: KChatComposer.icon + 4,
                  color: p.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: KSpacing.xs),
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
                style: t.body,
                decoration: InputDecoration(
                  hintText: l10n.waComposerHint,
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
                  suffixIcon: IconButton(
                    key: WaComposer.quickKey,
                    tooltip: l10n.waQuickReplies,
                    onPressed: () => unawaited(_quick()),
                    icon: Icon(
                      Icons.bolt_rounded,
                      size: KChatComposer.icon,
                      color: p.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: KSpacing.xs),
            ValueListenableBuilder(
              valueListenable: _text,
              builder: (_, value, _) => SizedBox.square(
                dimension: KChatComposer.button,
                child: IconButton.filled(
                  key: WaChatScreen.sendKey,
                  tooltip: l10n.waSend,
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    backgroundColor: p.primary,
                    foregroundColor: p.onPrimary,
                    disabledBackgroundColor: p.primary.withValues(alpha: 0.35),
                    disabledForegroundColor: p.onPrimary.withValues(alpha: 0.8),
                  ),
                  onPressed: _busy || value.text.trim().isEmpty
                      ? null
                      : () => unawaited(
                          _send(
                            (r) => r.sendText(widget.c.id, value.text.trim()),
                          ),
                        ),
                  // The paper plane points along the reading direction.
                  icon: Transform.flip(
                    flipX: rtl,
                    child: AppIcon(
                      AppIcons.send,
                      size: KChatComposer.icon,
                      color: p.onPrimary,
                    ),
                  ),
                ),
              ),
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

/// D366 (CONVENTIONS §10.159.2; owner «نعم موافق»): the transfer sheet —
/// the department chips, then «أول متاح في القسم» first, then that
/// department's agents (an on-shift dot and their open conversations), an
/// internal note (never sent), and «تحويل». Pops a [WaTransferChoice].
class WaTransferSheet extends ConsumerStatefulWidget {
  const new({required this.conversation, super.key});

  final WaConversation conversation;

  static Key departmentKey(WaDepartment d) => Key('wa.transfer.dept.${d.wire}');
  static const firstKey = Key('wa.transfer.first');
  static Key agentKey(String userId) => Key('wa.transfer.agent.$userId');
  static const noteKey = Key('wa.transfer.note');
  static const confirmKey = Key('wa.transfer.confirm');

  @override
  ConsumerState<WaTransferSheet> createState() => _WaTransferSheetState();
}

class _WaTransferSheetState extends ConsumerState<WaTransferSheet> {
  late WaDepartment _department = widget.conversation.department;

  /// null: «أول متاح في القسم».
  WaAgent? _to;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final agents = ref.watch(waAgentsProvider(_department));
    Widget section(String label) => Padding(
      padding: const EdgeInsetsDirectional.only(
        top: KSpacing.md,
        bottom: KSpacing.xs,
      ),
      child: Text(
        label,
        style: t.caption.copyWith(
          color: p.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.md,
              KSpacing.lg,
              KSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.waTransferTitle, style: t.title),
                section(l10n.waTransferDepartment),
                Wrap(
                  spacing: KSpacing.xs,
                  children: [
                    for (final d in WaDepartment.values)
                      KChip(
                        key: WaTransferSheet.departmentKey(d),
                        label: waDepartmentName(l10n, d),
                        selected: d == _department,
                        onSelected: () => setState(() {
                          _department = d;
                          _to = null;
                        }),
                      ),
                  ],
                ),
                section(l10n.waTransferWho),
                _TransferOption(
                  key: WaTransferSheet.firstKey,
                  selected: _to == null,
                  leading: CircleAvatar(
                    radius: KSizes.avatarSm / 2,
                    backgroundColor: p.success.withValues(alpha: 0.14),
                    child: Icon(Icons.bolt_rounded, color: p.success),
                  ),
                  title: l10n.waTransferFirst,
                  subtitle: l10n.waTransferFirstHint,
                  onTap: () => setState(() => _to = null),
                ),
                switch (agents) {
                  AsyncData(:final value) when value.isEmpty => Padding(
                    padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
                    child: Text(
                      l10n.waTransferNoAgents,
                      style: t.caption.copyWith(color: p.textTertiary),
                    ),
                  ),
                  AsyncData(:final value) => Column(
                    children: [
                      for (final a in value)
                        _TransferOption(
                          key: WaTransferSheet.agentKey(a.ref.userId),
                          selected: _to?.ref.userId == a.ref.userId,
                          leading: _AgentAvatar(agent: a),
                          title: _staff(l10n, a.ref),
                          subtitle: [
                            if (a.ref.staffId != null &&
                                a.ref.displayName != null)
                              a.ref.staffId!,
                            if (a.onShift) l10n.waOnShift else l10n.waOffShift,
                            l10n.waAgentOpen(a.openCount),
                          ].join(' · '),
                          onTap: () => setState(() => _to = a),
                        ),
                    ],
                  ),
                  AsyncError(:final error) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
                    child: Text(
                      waErrorMessage(l10n, error),
                      style: t.caption.copyWith(color: p.error),
                    ),
                  ),
                  _ => const Padding(
                    padding: EdgeInsets.all(KSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                },
                const SizedBox(height: KSpacing.md),
                TextField(
                  key: WaTransferSheet.noteKey,
                  controller: _note,
                  maxLength: 500,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.waTransferNote,
                    helperText: l10n.waTransferNoteHint,
                    prefixIcon: const Icon(Icons.sticky_note_2_outlined),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: KSpacing.md),
                KButton(
                  key: WaTransferSheet.confirmKey,
                  label: l10n.waTransferConfirm,
                  icon: Icons.swap_horiz_rounded,
                  onPressed: () => Navigator.of(context).pop(
                    WaTransferChoice(
                      department: _department,
                      to: _to,
                      note: _note.text.trim().isEmpty
                          ? null
                          : _note.text.trim(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One choice of the transfer sheet (radio-like: the check on the end side).
class _TransferOption extends StatelessWidget {
  const new({
    required this.selected,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final bool selected;
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
        color: selected
            ? p.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(KRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(KRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.sm,
              vertical: KSpacing.sm,
            ),
            child: Row(
              children: [
                leading,
                const SizedBox(width: KSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyStrong.copyWith(color: p.textPrimary),
                      ),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption.copyWith(color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? p.primary : p.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An agent's picture with the on-shift dot (green on shift, grey off).
class _AgentAvatar extends StatelessWidget {
  const new({required this.agent});

  final WaAgent agent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox.square(
      dimension: KSizes.avatarSm,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          KAvatar(name: _staff(context.l10n, agent.ref), size: KSizes.avatarSm),
          PositionedDirectional(
            end: -1,
            bottom: -1,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: agent.onShift ? p.success : p.textTertiary,
                shape: BoxShape.circle,
                border: Border.all(color: p.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
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
    // D360: VIEW reads the account and the notes; linking, unlinking and
    // adding a note need REPLY.
    final viewOnly = ref.watch(waViewOnlyProvider);
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
                trailing: viewOnly
                    ? null
                    : TextButton(
                        onPressed: () => unawaited(_do((r) => r.unlink(c.id))),
                        child: Text(l10n.waUnlink),
                      ),
              )
            else ...[
              Text(
                l10n.waNoAccount,
                style: t.caption.copyWith(color: p.textSecondary),
              ),
              if (!viewOnly)
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
                        if (u.isNotEmpty) {
                          unawaited(_do((r) => r.link(c.id, u)));
                        }
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
            if (!viewOnly)
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
