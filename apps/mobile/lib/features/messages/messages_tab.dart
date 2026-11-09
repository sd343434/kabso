import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/conversations_preview_screen.dart';
import 'package:kabso_live/features/messages/application/dm_providers.dart';
import 'package:kabso_live/features/messages/chat_screen.dart';
import 'package:kabso_live/features/messages/data/dm_repository.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/messages/widgets/dm_new_message_sheet.dart';
import 'package:kabso_live/features/messages/widgets/dm_story_cards.dart';
import 'package:kabso_live/features/profile/profile_verification_badge.dart';
import 'package:kabso_live/features/safety/safety_actions.dart';
import 'package:kabso_live/features/stories/application/stories_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Geometry of the Messages tab (D336: measured on the owner's reference,
/// 1.356 px/dp; D68's colours stay Kabso's).
abstract final class KDmList {
  static const double rowHeight = 80.5;
  static const double avatar = 64;
  static const double startInset = 23;
  static const double avatarGap = 20;
  static const double endInset = 24;
  static const double nameSize = 16;
  static const double previewSize = 14.5;
  static const double timeSize = 13;

  /// A long time (a date) is cut rather than squeezing the name.
  static const double timeMaxWidth = 80;

  /// «الرسائل» (the section title) and «القصص» (the page title).
  static const double titleSize = 23;
  static const double storiesTitleSize = 30;

  /// The header rows: 48 dp targets, the title at [startInset].
  static const double headerHeight = 48;
  static const double headerEndInset = 10;

  /// The dark «+» disc (new story) and the paper plane / search glyphs.
  static const double addDisc = 28;
  static const double planeIcon = 30;
  static const double searchIcon = 26;

  /// Header row → cards, cards → «الرسائل».
  static const double cardsTop = 10;
  static const double cardsBottom = 27;
  static const double unreadBadge = 24;
  static const double timeToBadge = 10;

  /// The time sits a little lower than the row's centre (on the name).
  static const double timeTop = 10;
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
///
/// D336 (owner's reference, layout only): the page opens on «القصص» — a
/// dark «+» (a new story) and the paper plane (a new message) — over the
/// story cards ([DmStoryCards]), then «الرسائل» with search, the two boxes
/// and the rows (64 dp picture, name, preview, time, the red unread count
/// under it). Everything scrolls together.
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

  /// D336: «القصص» and its «+» (a new story).
  static const storiesTitleKey = Key('dm.stories.title');
  static const newStoryKey = Key('dm.stories.new');
  static const actionReadKey = Key('dm.action.read');
  static const actionUnreadKey = Key('dm.action.unread');
  static const actionMuteKey = Key('dm.action.mute');
  static const actionDeleteKey = Key('dm.action.delete');
  static const actionBlockKey = Key('dm.action.block');
  static const confirmDeleteKey = Key('dm.action.delete.confirm');
  static Key rowKey(String conversationId) => Key('dm.row.$conversationId');

  /// D293: a row's verification seal.
  static Key sealKey(String username) => Key('dm.seal.$username');

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
    final t = context.textStyles;
    final ar = Directionality.of(context) == TextDirection.rtl;
    // A push or a grown badge: read the list again at once.
    ref
      ..listen(dmActivityProvider, (_, _) => _refresh())
      ..listen(dmUnreadProvider, (before, next) {
        if (before != next) _refresh();
      });
    final requests = ref.watch(dmUnreadProvider.select((u) => u.requests));
    // D336: «القصص» — the title, a dark «+» (a new story) and the paper
    // plane (a new message).
    final storiesHeader = SizedBox(
      height: KDmList.headerHeight,
      child: Row(
        children: [
          const SizedBox(width: KDmList.startInset),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                l10n.dmStoriesTitle,
                key: DmInboxScreen.storiesTitleKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.display.copyWith(
                  fontSize: KDmList.storiesTitleSize,
                  height: 1.2,
                  color: p.textPrimary,
                ),
              ),
            ),
          ),
          IconButton(
            key: DmInboxScreen.newStoryKey,
            tooltip: l10n.storyNewTitle,
            onPressed: () => context.push(AppRoutes.newStory),
            icon: Container(
              width: KDmList.addDisc,
              height: KDmList.addDisc,
              decoration: BoxDecoration(
                color: p.textPrimary.withValues(alpha: 0.78),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded, size: 20, color: p.background),
            ),
          ),
          // D165: write to someone new.
          IconButton(
            key: DmInboxScreen.newMessageKey,
            tooltip: l10n.conversationsNewMessage,
            onPressed: () => unawaited(showDmNewMessageSheet(context)),
            icon: Transform.flip(
              flipX: ar,
              child: AppIcon(
                AppIcons.send,
                size: KDmList.planeIcon,
                color: p.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: KDmList.headerEndInset),
        ],
      ),
    );
    // «الرسائل» with search and (D155) «من يستطيع مراسلتك»; while searching,
    // the field in its place.
    final messagesHeader = SizedBox(
      height: KDmList.headerHeight,
      child: Row(
        children: [
          const SizedBox(width: KDmList.startInset),
          Expanded(
            child: _searching
                ? TextField(
                    key: DmInboxScreen.searchFieldKey,
                    controller: _search,
                    autofocus: true,
                    maxLength: 31,
                    textInputAction: TextInputAction.search,
                    onChanged: _queryChanged,
                    style: t.body.copyWith(color: p.textPrimary),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.headline.copyWith(
                        fontSize: KDmList.titleSize,
                        height: 1.2,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
          ),
          if (_searching)
            IconButton(
              key: DmInboxScreen.searchCloseKey,
              tooltip: l10n.dmSearchClose,
              onPressed: _closeSearch,
              icon: const Icon(Icons.close_rounded),
            )
          else ...[
            // D155: «من يستطيع مراسلتك» is one tap away.
            IconButton(
              key: DmInboxScreen.privacyKey,
              tooltip: l10n.privacyMessageTitle,
              onPressed: () => context.push(AppRoutes.privacy),
              icon: Icon(Icons.tune_rounded, color: p.textSecondary),
            ),
            // D165: search the conversations.
            IconButton(
              key: DmInboxScreen.searchKey,
              tooltip: l10n.dmSearch,
              onPressed: () => setState(() => _searching = true),
              icon: AppIcon(
                AppIcons.search,
                size: KDmList.searchIcon,
                color: p.textPrimary,
              ),
            ),
          ],
          const SizedBox(width: KDmList.headerEndInset),
        ],
      ),
    );
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The stories step aside while searching.
        if (!_searching) ...[
          storiesHeader,
          const SizedBox(height: KDmList.cardsTop),
          const DmStoryCards(),
          const SizedBox(height: KDmList.cardsBottom),
        ],
        messagesHeader,
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: KDmList.startInset - KSpacing.sm,
          ),
          child: KChipRow(
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
        ),
      ],
    );
    return Scaffold(
      backgroundColor: p.background,
      body: KTopSafeArea(
        child: _Box(
          requests: _requests,
          query: _query,
          header: header,
          onRefresh: () async {
            ref.invalidate(storyTrayProvider);
          },
        ),
      ),
    );
  }
}

class _Box extends ConsumerWidget {
  const new({
    required this.requests,
    required this.header,
    required this.onRefresh,
    this.query,
  });

  final bool requests;

  /// D336: the page's top (stories, «الرسائل», the boxes): it scrolls with
  /// the list in every state.
  final Widget header;

  /// Pull to refresh also reads the stories again.
  final Future<void> Function() onRefresh;

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
            padding: const EdgeInsetsDirectional.fromSTEB(
              KDmList.startInset,
              KSpacing.xs,
              KDmList.endInset,
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
    Widget scroll(List<Widget> slivers, {Key? key}) => RefreshIndicator(
      onRefresh: () async {
        await onRefresh();
        await ref.read(provider.notifier).refresh();
      },
      child: CustomScrollView(
        key: key,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: header),
          if (hint != null) SliverToBoxAdapter(child: hint),
          ...slivers,
        ],
      ),
    );
    return switch (box) {
      AsyncValue(:final value?) when value.items.isEmpty => scroll([
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(
              top: KSpacing.xl,
              bottom: KSpacing.xl,
            ),
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
        ),
      ]),
      AsyncValue(:final value?) => NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 300) {
            unawaited(ref.read(provider.notifier).loadMore());
          }
          return false;
        },
        child: scroll(key: DmInboxScreen.listKey, [
          SliverList.list(
            children: [
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
              const SizedBox(height: KSpacing.sm),
            ],
          ),
        ]),
      ),
      AsyncValue(:final error?) => scroll([
        SliverFillRemaining(
          hasScrollBody: false,
          child: FailureErrorState(
            title: l10n.errorTitle,
            failure: toAppFailure(error),
            onRetry: () => ref.invalidate(provider),
          ),
        ),
      ]),
      _ => scroll([
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.only(top: KSpacing.xl),
            child: Align(
              alignment: Alignment.topCenter,
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      ]),
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
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final now = clock.now();
    // D336: compact on screen («5د», "5m"), in words for screen readers.
    final time =
        KFormat.relativeShort(item.lastActivityAt, now, l10n, localeTag) ??
        l10n.feedPostJustNow;
    final timeSpoken =
        KFormat.relative(item.lastActivityAt, now, l10n, localeTag) ??
        l10n.feedPostJustNow;
    return Semantics(
      key: DmInboxScreen.rowKey(item.id),
      button: true,
      label: unread
          ? l10n.conversationsUnread(peer.displayName)
          : peer.displayName,
      value: [
        preview,
        timeSpoken,
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
                top: (KDmList.rowHeight - KDmList.avatar) / 2,
                bottom: (KDmList.rowHeight - KDmList.avatar) / 2,
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
                                  height: 1.3,
                                  fontWeight: unread
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: p.textPrimary,
                                ),
                              ),
                            ),
                            // D293: the peer's verification seal.
                            VerificationSeal(
                              peer.verification,
                              key: DmInboxScreen.sealKey(peer.username),
                              fontSize: KDmList.nameSize,
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
                        const SizedBox(height: KSpacing.xs),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.body.copyWith(
                            fontSize: KDmList.previewSize,
                            height: 1.35,
                            color: p.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: KSpacing.md),
                  // D336: the time, and the unread count under it.
                  Padding(
                    padding: const EdgeInsets.only(top: KDmList.timeTop),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: KDmList.timeMaxWidth,
                          ),
                          child: Text(
                            time,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.caption.copyWith(
                              fontSize: KDmList.timeSize,
                              color: p.textTertiary,
                            ),
                          ),
                        ),
                        const SizedBox(height: KDmList.timeToBadge),
                        if (unread && item.unreadCount == 0)
                          // D165: marked unread — a dot, no number.
                          Container(
                            key: DmConversationRow.markedDotKey,
                            width: KDmList.unreadBadge / 2,
                            height: KDmList.unreadBadge / 2,
                            margin: const EdgeInsets.all(
                              KDmList.unreadBadge / 4,
                            ),
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
                                fontSize: 12,
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
