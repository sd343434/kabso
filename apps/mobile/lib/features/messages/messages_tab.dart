import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/conversations_preview_screen.dart';
import 'package:kabso_live/features/messages/application/dm_providers.dart';
import 'package:kabso_live/features/messages/chat_screen.dart';
import 'package:kabso_live/features/messages/data/dm_repository.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/messages/widgets/dm_new_message_sheet.dart';
import 'package:kabso_live/features/safety/safety_actions.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Row geometry of the conversation list (D68, measured on the owner's
/// chat reference; colours are Kabso's).
abstract final class KDmList {
  static const double rowHeight = 73;
  static const double avatar = 57;
  static const double startInset = 16;
  static const double avatarGap = 12;
  static const double endInset = 16;
  static const double nameSize = 14.5;
  static const double previewSize = 13.7;
  static const double timeSize = 12.2;
  static const double titleSize = 24;
  static const double unreadBadge = 20;
  static const double mutedIcon = 14;
}

/// `/messages` — the Messages tab (D86; D155: real direct messages). Two
/// boxes: the conversations (accepted, and requests the caller sent) and
/// «طلبات المراسلة» (requests from people the caller does not follow),
/// each newest message first. The list reads the server again every
/// [dmUnreadPoll], on pull-to-refresh, and when a `dm` push arrives.
/// Test builds with Demo data on show the designed list with labelled test
/// data (D86; release builds compile it out).
///
/// D165: the search button filters the box by the peer's name or username
/// (`listDmConversations?q=`), the pen opens «رسالة جديدة» (find someone,
/// then the conversation), and a long press on a row offers mark read /
/// unread, mute, delete and block.
class MessagesTab extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kDemoAvailable && ref.watch(demoModeProvider)) {
      return const ConversationsPreviewScreen();
    }
    return const DmInboxScreen();
  }
}

/// The real conversation list (D155).
class DmInboxScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const inboxTabKey = Key('dm.tab.inbox');
  static const privacyKey = Key('dm.privacy');
  static const requestsTabKey = Key('dm.tab.requests');
  static const listKey = Key('dm.list');
  static const emptyKey = Key('dm.empty');
  static const requestsHintKey = Key('dm.requests.hint');
  static const searchKey = Key('dm.search');
  static const searchFieldKey = Key('dm.search.field');
  static const searchCloseKey = Key('dm.search.close');
  static const searchEmptyKey = Key('dm.search.empty');
  static const newMessageKey = Key('dm.new');
  static const actionReadKey = Key('dm.action.read');
  static const actionUnreadKey = Key('dm.action.unread');
  static const actionMuteKey = Key('dm.action.mute');
  static const actionDeleteKey = Key('dm.action.delete');
  static const actionBlockKey = Key('dm.action.block');
  static const confirmDeleteKey = Key('dm.action.delete.confirm');
  static Key rowKey(String conversationId) => Key('dm.row.$conversationId');

  @override
  ConsumerState<DmInboxScreen> createState() => _DmInboxScreenState();
}

class _DmInboxScreenState extends ConsumerState<DmInboxScreen> {
  bool _requests = false;
  Timer? _poll;

  /// D165: the search field is open; [_query] is what it searches (after a
  /// short pause in typing), null for the whole box.
  bool _searching = false;
  String? _query;
  Timer? _debounce;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(dmUnreadPoll, (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    unawaited(ref.read(dmInboxProvider(_requests).notifier).refresh());
    final q = _query;
    if (q != null) {
      unawaited(
        ref
            .read(
              dmInboxSearchProvider((requests: _requests, query: q)).notifier,
            )
            .refresh(),
      );
    }
  }

  void _queryChanged(String raw) {
    var q = raw.trim();
    if (q.startsWith('@')) q = q.substring(1).trim();
    if (q.length > 30) q = q.substring(0, 30);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = q.isEmpty ? null : q);
    });
  }

  void _closeSearch() {
    _debounce?.cancel();
    _search.clear();
    setState(() {
      _searching = false;
      _query = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    // A push or a grown badge: read the list again at once.
    ref
      ..listen(dmActivityProvider, (_, _) => _refresh())
      ..listen(dmUnreadProvider, (before, next) {
        if (before != next) _refresh();
      });
    final requests = ref.watch(dmUnreadProvider.select((u) => u.requests));
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: _searching
            ? TextField(
                key: DmInboxScreen.searchFieldKey,
                controller: _search,
                autofocus: true,
                maxLength: 31,
                textInputAction: TextInputAction.search,
                onChanged: _queryChanged,
                style: context.textStyles.body.copyWith(color: p.textPrimary),
                decoration: InputDecoration(
                  hintText: l10n.dmSearchHint,
                  counterText: '',
                  isDense: true,
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: p.textSecondary,
                  ),
                ),
              )
            : Semantics(
                header: true,
                child: Text(
                  l10n.conversationsTitle,
                  style: context.textStyles.headline.copyWith(
                    fontSize: KDmList.titleSize,
                    color: p.textPrimary,
                  ),
                ),
              ),
        actions: [
          if (_searching)
            IconButton(
              key: DmInboxScreen.searchCloseKey,
              tooltip: l10n.dmSearchClose,
              onPressed: _closeSearch,
              icon: const Icon(Icons.close_rounded),
            )
          else ...[
            // D165: search the conversations.
            IconButton(
              key: DmInboxScreen.searchKey,
              tooltip: l10n.dmSearch,
              onPressed: () => setState(() => _searching = true),
              icon: const Icon(Icons.search_rounded),
            ),
            // D165: write to someone new.
            IconButton(
              key: DmInboxScreen.newMessageKey,
              tooltip: l10n.conversationsNewMessage,
              onPressed: () => unawaited(showDmNewMessageSheet(context)),
              icon: const Icon(Icons.edit_square),
            ),
            // D155: «من يستطيع مراسلتك» is one tap away.
            IconButton(
              key: DmInboxScreen.privacyKey,
              tooltip: l10n.privacyMessageTitle,
              onPressed: () => context.push(AppRoutes.privacy),
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
          const SizedBox(width: KSpacing.xs),
        ],
      ),
      body: Column(
        children: [
          KChipRow(
            children: [
              KChip(
                key: DmInboxScreen.inboxTabKey,
                label: l10n.dmTabChats,
                selected: !_requests,
                onSelected: () => setState(() => _requests = false),
              ),
              KChip(
                key: DmInboxScreen.requestsTabKey,
                label: requests > 0
                    ? l10n.dmTabRequestsCount(KFormat.compact(requests, l10n))
                    : l10n.dmTabRequests,
                selected: _requests,
                onSelected: () => setState(() => _requests = true),
              ),
            ],
          ),
          Expanded(
            child: _Box(requests: _requests, query: _query),
          ),
        ],
      ),
    );
  }
}

class _Box extends ConsumerWidget {
  const new({required this.requests, this.query});

  final bool requests;

  /// D165: the search (null: the whole box).
  final String? query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final q = query;
    final provider = q == null
        ? dmInboxProvider(requests)
        : dmInboxSearchProvider((requests: requests, query: q));
    final box = ref.watch(provider);
    final hint = requests && q == null
        ? Padding(
            key: DmInboxScreen.requestsHintKey,
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.sm,
              KSpacing.lg,
              KSpacing.sm,
            ),
            child: Text(
              l10n.dmRequestsHint,
              style: context.textStyles.caption.copyWith(
                color: p.textSecondary,
              ),
            ),
          )
        : null;
    return switch (box) {
      AsyncValue(:final value?) => RefreshIndicator(
        onRefresh: () => ref.read(provider.notifier).refresh(),
        child: value.items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  ?hint,
                  Padding(
                    padding: const EdgeInsets.only(top: KSpacing.xl),
                    child: q != null
                        ? KEmptyState(
                            key: DmInboxScreen.searchEmptyKey,
                            icon: Icons.search_off_rounded,
                            title: l10n.dmSearchEmpty(KFormat.bidiIsolate(q)),
                            message: l10n.dmSearchHint,
                          )
                        : KEmptyState(
                            key: DmInboxScreen.emptyKey,
                            icon: Icons.chat_bubble_outline_rounded,
                            title: requests
                                ? l10n.dmRequestsEmptyTitle
                                : l10n.conversationsEmptyTitle,
                            message: requests
                                ? l10n.dmRetentionNotice
                                : l10n.conversationsEmptyBody,
                          ),
                  ),
                ],
              )
            : NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.extentAfter < 300) {
                    unawaited(ref.read(provider.notifier).loadMore());
                  }
                  return false;
                },
                child: ListView(
                  key: DmInboxScreen.listKey,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    ?hint,
                    for (final c in value.items)
                      DmConversationRow(
                        item: c,
                        onLongPress: () => unawaited(
                          _conversationActions(
                            context,
                            ref,
                            c,
                            requests: requests,
                            query: q,
                          ),
                        ),
                      ),
                    if (value.loadingMore)
                      const Padding(
                        padding: EdgeInsets.all(KSpacing.lg),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
      ),
      AsyncValue(:final error?) => FailureErrorState(
        title: l10n.errorTitle,
        failure: toAppFailure(error),
        onRetry: () => ref.invalidate(provider),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

/// The preview line of a conversation (its newest readable message).
String dmPreview(AppLocalizations l10n, DmConversation c) {
  final m = c.lastMessage;
  if (m == null) return l10n.dmPreviewExpired;
  final body = switch (m.kind) {
    DmMessageKind.text => m.text ?? '',
    DmMessageKind.image => l10n.dmLastPhoto,
    DmMessageKind.voice => l10n.dmPreviewVoice,
    DmMessageKind.emoji => l10n.dmPreviewSticker,
    DmMessageKind.gift => l10n.dmPreviewGift('${m.gift?.quantity ?? 1}'),
    DmMessageKind.unknown => l10n.dmPreviewUnsupported,
  };
  // Single line: line breaks of a long text become spaces.
  final line = body.replaceAll(RegExp(r'\s+'), ' ');
  return m.mine ? l10n.dmPreviewYou(line) : line;
}

/// One conversation in the list (D68 look): picture, name, the newest
/// message, its time and the unread count (grey when muted).
class DmConversationRow extends StatelessWidget {
  const new({required this.item, super.key, this.onLongPress});

  final DmConversation item;

  /// D165: the row's actions (mark read / unread, mute, delete, block).
  final VoidCallback? onLongPress;

  static const markedDotKey = Key('dm.row.marked');

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final t = context.textStyles;
    final peer = item.peer;
    final unread = item.isUnread;
    final preview = dmPreview(l10n, item);
    final time =
        KFormat.relative(
          item.lastActivityAt,
          clock.now(),
          l10n,
          Localizations.localeOf(context).toLanguageTag(),
        ) ??
        l10n.feedPostJustNow;
    return Semantics(
      key: DmInboxScreen.rowKey(item.id),
      button: true,
      label: unread
          ? l10n.conversationsUnread(peer.displayName)
          : peer.displayName,
      value: [
        preview,
        time,
        if (item.unreadCount > 0)
          l10n.conversationsUnreadCount(item.unreadCount)
        else if (item.markedUnread)
          l10n.dmMarkedUnread,
        if (item.muted) l10n.conversationsMuted,
      ].join(', '),
      excludeSemantics: true,
      onLongPressHint: onLongPress == null ? null : l10n.dmConversationActions,
      child: Material(
        color: p.background,
        child: InkWell(
          onLongPress: onLongPress,
          onTap: () => context.push(
            AppRoutes.chat(peer.username),
            extra: (
              displayName: peer.displayName,
              premiumTier: peer.premiumTier,
            ) as ChatPeer,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: KDmList.rowHeight),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: KDmList.startInset,
                end: KDmList.endInset,
                top: KSpacing.sm,
                bottom: KSpacing.sm,
              ),
              child: Row(
                children: [
                  KAvatar(
                    name: peer.displayName,
                    imageUrl: peer.avatarUrl,
                    size: KDmList.avatar,
                  ),
                  const SizedBox(width: KDmList.avatarGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                peer.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodyStrong.copyWith(
                                  fontSize: KDmList.nameSize,
                                  fontWeight: unread
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: p.textPrimary,
                                ),
                              ),
                            ),
                            if (item.muted) ...[
                              const SizedBox(width: KSpacing.xs),
                              Icon(
                                Icons.volume_off_rounded,
                                size: KDmList.mutedIcon,
                                color: p.textTertiary,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: KSpacing.xxs),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.body.copyWith(
                            fontSize: KDmList.previewSize,
                            color: unread ? p.textPrimary : p.textSecondary,
                          ),
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
                        style: t.caption.copyWith(
                          fontSize: KDmList.timeSize,
                          color: unread ? p.primaryText : p.textTertiary,
                        ),
                      ),
                      const SizedBox(height: KSpacing.xs + 2),
                      if (unread && item.unreadCount == 0)
                        // D165: marked unread — a dot, no number.
                        Container(
                          key: DmConversationRow.markedDotKey,
                          width: KDmList.unreadBadge / 2,
                          height: KDmList.unreadBadge / 2,
                          margin: const EdgeInsets.all(KDmList.unreadBadge / 4),
                          decoration: BoxDecoration(
                            color: item.muted ? p.textTertiary : p.primary,
                            shape: BoxShape.circle,
                          ),
                        )
                      else if (unread)
                        Container(
                          constraints: const BoxConstraints(
                            minWidth: KDmList.unreadBadge,
                          ),
                          height: KDmList.unreadBadge,
                          padding: const EdgeInsets.symmetric(
                            horizontal: KSpacing.xs + 2,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: item.muted ? p.textTertiary : p.primary,
                            borderRadius: BorderRadius.circular(KRadius.pill),
                          ),
                          child: Text(
                            item.unreadCount >= 99
                                ? '99+'
                                : KFormat.compact(item.unreadCount, l10n),
                            style: t.caption.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              height: 1,
                              color: p.onPrimary,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: KDmList.unreadBadge),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// D165: the long-press menu of a conversation row.
Future<void> _conversationActions(
  BuildContext context,
  WidgetRef ref,
  DmConversation item, {
  required bool requests,
  required String? query,
}) async {
  final l10n = context.l10n;
  final last = item.lastMessage;
  // Reading a request from the list would tell the sender (the chat does not
  // either before the caller accepts): there only the mark is cleared.
  final readMessages =
      item.unreadCount > 0 &&
      last != null &&
      item.status != DmConversationStatus.requestReceived;
  final canRead = item.markedUnread || readMessages;
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canRead)
            ListTile(
              key: DmInboxScreen.actionReadKey,
              leading: const Icon(Icons.mark_chat_read_outlined),
              title: Text(l10n.dmMarkRead),
              onTap: () => Navigator.of(sheet).pop('read'),
            )
          else if (!item.isUnread)
            ListTile(
              key: DmInboxScreen.actionUnreadKey,
              leading: const Icon(Icons.mark_chat_unread_outlined),
              title: Text(l10n.dmMarkUnread),
              onTap: () => Navigator.of(sheet).pop('unread'),
            ),
          ListTile(
            key: DmInboxScreen.actionMuteKey,
            leading: Icon(
              item.muted ? Icons.volume_up_outlined : Icons.volume_off_outlined,
            ),
            title: Text(item.muted ? l10n.dmUnmute : l10n.dmMute),
            onTap: () => Navigator.of(sheet).pop('mute'),
          ),
          ListTile(
            key: DmInboxScreen.actionDeleteKey,
            leading: const Icon(Icons.delete_outline),
            title: Text(l10n.dmDeleteConversation),
            onTap: () => Navigator.of(sheet).pop('delete'),
          ),
          ListTile(
            key: DmInboxScreen.actionBlockKey,
            leading: Icon(Icons.block_rounded, color: sheet.palette.error),
            title: Text(
              l10n.safetyBlock,
              style: TextStyle(color: sheet.palette.error),
            ),
            onTap: () => Navigator.of(sheet).pop('block'),
          ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  final repo = ref.read(dmRepositoryProvider);
  final box = ref.read(dmInboxProvider(requests).notifier);
  final search = query == null
      ? null
      : ref.read(
          dmInboxSearchProvider((requests: requests, query: query)).notifier,
        );
  void patch(DmConversation Function(DmConversation c) change) {
    box.patch(item.id, change);
    search?.patch(item.id, change);
  }

  void drop() {
    box.drop(item.id);
    search?.drop(item.id);
  }

  try {
    switch (action) {
      case 'read':
        if (readMessages) {
          await repo.markRead(item.id, last.id);
          patch((c) => c.copyWith(unreadCount: 0, markedUnread: false));
        } else {
          await repo.setMarkedUnread(item.id, marked: false);
          patch((c) => c.copyWith(markedUnread: false));
        }
      case 'unread':
        await repo.setMarkedUnread(item.id, marked: true);
        patch((c) => c.copyWith(markedUnread: true));
      case 'mute':
        await repo.setMuted(item.id, muted: !item.muted);
        patch((c) => c.copyWith(muted: !item.muted));
        if (context.mounted) {
          KSnack.success(context, item.muted ? l10n.dmUnmuted : l10n.dmMuted);
        }
      case 'delete':
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
                key: DmInboxScreen.confirmDeleteKey,
                onPressed: () => Navigator.of(dialog).pop(true),
                child: Text(
                  l10n.dmDecline,
                  style: TextStyle(color: dialog.palette.error),
                ),
              ),
            ],
          ),
        );
        if (!(ok ?? false)) return;
        await repo.deleteConversation(item.id);
        drop();
      case 'block':
        if (!context.mounted) return;
        final blocked = await confirmBlock(
          context,
          ref,
          username: item.peer.username,
          name: item.peer.displayName,
        );
        if (!blocked) return;
        drop();
    }
    unawaited(ref.read(dmUnreadProvider.notifier).refresh());
  } on Object catch (e) {
    if (context.mounted) {
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
  }
}
