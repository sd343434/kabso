import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/conversations_preview_screen.dart';
import 'package:kabso_live/features/messages/application/dm_providers.dart';
import 'package:kabso_live/features/messages/chat_screen.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
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
  static Key rowKey(String conversationId) => Key('dm.row.$conversationId');

  @override
  ConsumerState<DmInboxScreen> createState() => _DmInboxScreenState();
}

class _DmInboxScreenState extends ConsumerState<DmInboxScreen> {
  bool _requests = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(dmUnreadPoll, (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    unawaited(ref.read(dmInboxProvider(_requests).notifier).refresh());
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
        title: Semantics(
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
          // D155: «من يستطيع مراسلتك» is one tap away.
          IconButton(
            key: DmInboxScreen.privacyKey,
            tooltip: l10n.privacyMessageTitle,
            onPressed: () => context.push(AppRoutes.privacy),
            icon: const Icon(Icons.tune_rounded),
          ),
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
          Expanded(child: _Box(requests: _requests)),
        ],
      ),
    );
  }
}

class _Box extends ConsumerWidget {
  const new({required this.requests});

  final bool requests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final box = ref.watch(dmInboxProvider(requests));
    final hint = requests
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
        onRefresh: () => ref.read(dmInboxProvider(requests).notifier).refresh(),
        child: value.items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  ?hint,
                  Padding(
                    padding: const EdgeInsets.only(top: KSpacing.xl),
                    child: KEmptyState(
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
                    unawaited(
                      ref.read(dmInboxProvider(requests).notifier).loadMore(),
                    );
                  }
                  return false;
                },
                child: ListView(
                  key: DmInboxScreen.listKey,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    ?hint,
                    for (final c in value.items) DmConversationRow(item: c),
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
        onRetry: () => ref.invalidate(dmInboxProvider(requests)),
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
  const new({required this.item, super.key});

  final DmConversation item;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final t = context.textStyles;
    final peer = item.peer;
    final unread = item.unreadCount > 0;
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
        if (unread) l10n.conversationsUnreadCount(item.unreadCount),
        if (item.muted) l10n.conversationsMuted,
      ].join(', '),
      excludeSemantics: true,
      child: Material(
        color: p.background,
        child: InkWell(
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
                      if (unread)
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
