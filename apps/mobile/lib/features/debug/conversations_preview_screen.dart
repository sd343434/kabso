import 'package:clock/clock.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/messages_preview_screen.dart';
import 'package:kabso_live/features/debug/preview_photo.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Geometry of the KL-056 conversation list, measured from the owner's Figma
/// reference (UI kit "Direct messages", node 1347:5329, 417x904). The large
/// title, search, "active now" row, filter chips, unread counts and online
/// dots follow the owner's chat reference (D68). Colours are Kabso's and
/// avatars are initials, never a kit's photos.
abstract final class KConversations {
  static const double rowHeight = 73;

  /// The unread row is taller and tinted (81 vs 73).
  static const double unreadRowHeight = 81;
  static const double avatar = 57;
  static const double startInset = 16;
  static const double avatarGap = 12;
  static const double endInset = 16;
  static const double nameSize = 14.5;
  static const double previewSize = 13.7;
  static const double timeSize = 12.2;
  static const double titleSize = 24;
  static const double activeAvatar = 52;
  static const double onlineDot = 13;
  static const double unreadBadge = 20;
  static const double mutedIcon = 14;
}

/// What the last message of a conversation was (drives the preview line).
enum ConversationLast { text, sharedVideo, none }

/// One row of the conversation list (labelled test data, D46).
class ConversationSummary {
  const new({
    required this.peer,
    required this.at,
    this.last = ConversationLast.none,
    this.text = '',
    this.unreadCount = 0,
    this.online = false,
    this.muted = false,
    this.group = false,
    this.favorite = false,
    this.photo,
  });

  final String peer;
  final DateTime at;
  final ConversationLast last;
  final String text;
  final int unreadCount;
  final bool online;
  final bool muted;
  final bool group;
  final bool favorite;

  /// A development headshot (`PreviewPhotos`), shown instead of initials.
  final String? photo;

  bool get unread => unreadCount > 0;
}

List<ConversationSummary> conversationsPreviewFixture({
  required bool ar,
  required DateTime now,
}) => [
  ConversationSummary(
    peer: ar ? 'نور (تجربة)' : 'Nour (test)',
    photo: PreviewPhotos.huda,
    at: now.subtract(const Duration(minutes: 5)),
    last: ConversationLast.sharedVideo,
    unreadCount: 2,
    online: true,
    favorite: true,
  ),
  ConversationSummary(
    peer: ar ? 'مجموعة الأصدقاء (تجربة)' : 'Friends group (test)',
    photo: PreviewPhotos.group,
    at: now.subtract(const Duration(hours: 1)),
    last: ConversationLast.text,
    text: ar ? 'رسالة جماعية تجريبية' : 'A test group message',
    unreadCount: 12,
    muted: true,
    group: true,
  ),
  ConversationSummary(
    peer: ar ? 'سامي (تجربة)' : 'Sami (test)',
    photo: PreviewPhotos.omar,
    at: now.subtract(const Duration(hours: 3)),
    last: ConversationLast.text,
    text: ar ? 'رسالة تجريبية' : 'A test message',
    online: true,
  ),
  ConversationSummary(
    peer: ar ? 'هند (تجربة)' : 'Hind (test)',
    photo: PreviewPhotos.layla,
    at: now.subtract(const Duration(days: 2)),
    online: true,
  ),
  ConversationSummary(
    peer: ar ? 'عمر (تجربة)' : 'Omar (test)',
    photo: PreviewPhotos.karim,
    at: now.subtract(const Duration(days: 3)),
    favorite: true,
  ),
  ConversationSummary(
    peer: ar ? 'ليلى (تجربة)' : 'Layla (test)',
    photo: PreviewPhotos.rania,
    at: now.subtract(const Duration(days: 12)),
    last: ConversationLast.text,
    text: ar ? 'شكرًا على الهدية' : 'Thanks for the gift',
    online: true,
  ),
];

/// The states the preview can show. Production has no messaging API yet
/// (contract has no conversations endpoint), so its honest state today is
/// [unavailable]; the others show how the screen will behave once it has
/// one.
enum ConversationsPreviewState { loading, error, unavailable, empty, populated }

/// The filter chips above the list (D68).
enum ConversationsFilter { all, unread, groups, favorites }

/// `/debug/conversations-preview` — KL-056 conversation list with a state
/// switcher. Opening a conversation shows the messages preview; a
/// conversation without messages opens on the first-time greeting.
class ConversationsPreviewScreen extends StatefulWidget {
  const new({
    super.key,
    this.initialState = ConversationsPreviewState.populated,
  });

  final ConversationsPreviewState initialState;

  static const testDataKey = Key('conversations-preview-test-data');
  static const listKey = Key('conversations-preview-list');
  static const searchToggleKey = Key('conversations-preview-search-toggle');
  static const newMessageKey = Key('conversations-preview-new');
  static const newMessageSearchKey = Key('conversations-preview-new-search');
  static Key personKey(String peer) =>
      Key('conversations-preview-person-$peer');
  static const searchKey = Key('conversations-preview-search');
  static const activeKey = Key('conversations-preview-active');
  static const noMatchKey = Key('conversations-preview-no-match');
  static Key rowKey(String peer) => Key('conversations-preview-row-$peer');
  static Key filterKey(ConversationsFilter f) =>
      Key('conversations-preview-filter-${f.name}');

  @override
  State<ConversationsPreviewScreen> createState() =>
      _ConversationsPreviewScreenState();
}

class _ConversationsPreviewScreenState
    extends State<ConversationsPreviewScreen> {
  late ConversationsPreviewState _state = widget.initialState;
  final _search = TextEditingController();
  var _searching = false;
  ConversationsFilter _filter = ConversationsFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// D68: the search and the chips filter the list on the device.
  bool _matches(ConversationSummary c) {
    final query = _search.text.trim().toLowerCase();
    if (query.isNotEmpty &&
        !c.peer.toLowerCase().contains(query) &&
        !c.text.toLowerCase().contains(query)) {
      return false;
    }
    return switch (_filter) {
      ConversationsFilter.all => true,
      ConversationsFilter.unread => c.unread,
      ConversationsFilter.groups => c.group,
      ConversationsFilter.favorites => c.favorite,
    };
  }

  void _open(ConversationSummary c) {
    final ar = Directionality.of(context) == TextDirection.rtl;
    // Above the tabs when it is the Messages tab (D86).
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => MessagesPreviewScreen(
          peer: c.peer,
          peerPhoto: c.photo,
          online: c.online,
          // A conversation with a last message opens on the test thread;
          // one with none opens on the first-time greeting.
          initialMessages: c.last == ConversationLast.none
              ? const []
              : messagesPreviewFixture(ar: ar),
        ),
      ),
    );
  }

  void _toggleSearch() => setState(() {
    _searching = !_searching;
    if (!_searching) _search.clear();
  });

  /// D68: the "+" picks someone to message; their thread opens (on the
  /// first-time greeting when there is none yet).
  Future<void> _newMessage(List<ConversationSummary> people) async {
    final chosen = await showModalBottomSheet<ConversationSummary>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _NewMessageSheet(people: people),
    );
    if (chosen != null && mounted) _open(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final people = conversationsPreviewFixture(
      ar: Directionality.of(context) == TextDirection.rtl,
      now: clock.now(),
    ).where((c) => !c.group).toList();
    // Owner's reference (D68): search at the start, the title centred, a
    // "+" at the end. The state switcher is gone; the other states stay
    // reachable through [ConversationsPreviewScreen.initialState].
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: IconButton(
          key: ConversationsPreviewScreen.searchToggleKey,
          tooltip: l10n.conversationsSearch,
          onPressed: _state == ConversationsPreviewState.populated
              ? _toggleSearch
              : null,
          icon: _searching
              ? const AppIcon(AppIcons.close, size: KMetrics.iconMd)
              : const AppIcon(AppIcons.search, size: KMetrics.iconMd),
        ),
        title: Semantics(
          header: true,
          child: Text(
            l10n.conversationsTitle,
            style: context.textStyles.headline.copyWith(
              fontSize: KConversations.titleSize,
              color: p.textPrimary,
            ),
          ),
        ),
        actions: [
          IconButton(
            key: ConversationsPreviewScreen.newMessageKey,
            tooltip: l10n.conversationsNewMessage,
            onPressed: () => _newMessage(people),
            icon: const Icon(Icons.add_rounded, size: 28),
          ),
          const SizedBox(width: KSpacing.xs),
        ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = context.l10n;
    switch (_state) {
      case ConversationsPreviewState.loading:
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          children: [for (var i = 0; i < 6; i++) const _SkeletonRow()],
        );
      case ConversationsPreviewState.error:
        return FailureErrorState(
          title: l10n.errorTitle,
          failure: const NetworkFailure.offline(),
          onRetry: () =>
              setState(() => _state = ConversationsPreviewState.loading),
        );
      case ConversationsPreviewState.unavailable:
        return KEmptyState(
          icon: Icons.forum_outlined,
          title: l10n.conversationsUnavailableTitle,
          message: l10n.conversationsUnavailableBody,
        );
      case ConversationsPreviewState.empty:
        return KEmptyState(
          icon: Icons.chat_bubble_outline_rounded,
          title: l10n.conversationsEmptyTitle,
          message: l10n.conversationsEmptyBody,
        );
      case ConversationsPreviewState.populated:
        final all = conversationsPreviewFixture(
          ar: Directionality.of(context) == TextDirection.rtl,
          now: clock.now(),
        );
        final items = all.where(_matches).toList();
        final active = all.where((c) => c.online).toList();
        return ListView(
          key: ConversationsPreviewScreen.listKey,
          children: [
            if (_searching)
              _SearchField(
                controller: _search,
                onChanged: (_) => setState(() {}),
              ),
            if (active.isNotEmpty)
              _ActiveNow(
                key: ConversationsPreviewScreen.activeKey,
                people: active,
                onOpen: _open,
              ),
            KChipRow(
              children: [
                for (final f in ConversationsFilter.values)
                  KChip(
                    key: ConversationsPreviewScreen.filterKey(f),
                    label: _filterLabel(l10n, f),
                    selected: _filter == f,
                    onSelected: () => setState(() => _filter = f),
                  ),
              ],
            ),
            const SizedBox(height: KSpacing.xs),
            if (items.isEmpty)
              Padding(
                key: ConversationsPreviewScreen.noMatchKey,
                padding: const EdgeInsets.all(KSpacing.xl),
                child: Text(
                  l10n.conversationsNoMatch,
                  textAlign: TextAlign.center,
                  style: context.textStyles.body.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ),
            for (final c in items)
              _ConversationRow(item: c, onTap: () => _open(c)),
          ],
        );
    }
  }

  static String _filterLabel(AppLocalizations l10n, ConversationsFilter f) =>
      switch (f) {
        ConversationsFilter.all => l10n.conversationsFilterAll,
        ConversationsFilter.unread => l10n.conversationsFilterUnread,
        ConversationsFilter.groups => l10n.conversationsFilterGroups,
        ConversationsFilter.favorites => l10n.conversationsFilterFavorites,
      };
}

class _SearchField extends StatelessWidget {
  const new({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(KRadius.pill),
      borderSide: BorderSide.none,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KConversations.startInset,
        KSpacing.sm,
        KConversations.endInset,
        KSpacing.xs,
      ),
      child: TextField(
        key: ConversationsPreviewScreen.searchKey,
        controller: controller,
        autofocus: true,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: context.textStyles.body,
        decoration: InputDecoration(
          hintText: context.l10n.conversationsSearch,
          filled: true,
          fillColor: p.surfaceOverlay,
          isDense: true,
          prefixIcon: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: KSpacing.md,
              end: KSpacing.sm,
            ),
            child: AppIcon(AppIcons.search, size: 20, color: p.textSecondary),
          ),
          prefixIconConstraints: const BoxConstraints(),
          contentPadding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
          border: pill,
          enabledBorder: pill,
          focusedBorder: pill.copyWith(
            borderSide: BorderSide(color: p.focusRing, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// Avatar with a green dot while [online].
class _PresenceAvatar extends StatelessWidget {
  const new({
    required this.name,
    required this.size,
    required this.online,
    this.photo,
  });

  final String name;
  final double size;
  final bool online;
  final String? photo;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        KAvatar(name: name, size: size, image: PreviewPhotos.asset(photo)),
        if (online)
          PositionedDirectional(
            end: 0,
            bottom: 0,
            child: Container(
              width: KConversations.onlineDot,
              height: KConversations.onlineDot,
              decoration: BoxDecoration(
                color: p.success,
                shape: BoxShape.circle,
                border: Border.all(color: p.background, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// The people online now, in a row that scrolls sideways (D68).
class _ActiveNow extends StatelessWidget {
  const new({required this.people, required this.onOpen, super.key});

  final List<ConversationSummary> people;
  final ValueChanged<ConversationSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            KConversations.startInset,
            KSpacing.sm,
            KConversations.endInset,
            KSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.conversationsActiveNow,
                  style: t.label.copyWith(color: p.textSecondary),
                ),
              ),
              // D46: populated data is labelled as test data.
              DecoratedBox(
                key: ConversationsPreviewScreen.testDataKey,
                decoration: BoxDecoration(
                  color: p.surfaceOverlay,
                  borderRadius: BorderRadius.circular(KRadius.xs),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KSpacing.xs,
                    vertical: KSpacing.xxs,
                  ),
                  child: Text(
                    l10n.feedPreviewTestData,
                    style: t.caption.copyWith(color: p.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: KConversations.startInset - KSpacing.xs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in people)
                Semantics(
                  button: true,
                  label: '${c.peer}, ${l10n.chatOnline}',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => onOpen(c),
                    borderRadius: BorderRadius.circular(KRadius.md),
                    child: Padding(
                      padding: const EdgeInsets.all(KSpacing.xs),
                      child: SizedBox(
                        width: KConversations.activeAvatar + KSpacing.md,
                        child: Column(
                          children: [
                            _PresenceAvatar(
                              name: c.peer,
                              size: KConversations.activeAvatar,
                              online: true,
                              photo: c.photo,
                            ),
                            const SizedBox(height: KSpacing.xs),
                            Text(
                              // The first name only.
                              c.peer.split(' ').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: t.caption.copyWith(color: p.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Picks someone to message (D68). Without a people-search API this lists
/// the preview's test people; it filters as you type.
class _NewMessageSheet extends StatefulWidget {
  const new({required this.people});

  final List<ConversationSummary> people;

  @override
  State<_NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<_NewMessageSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final l10n = context.l10n;
    final q = _query.text.trim().toLowerCase();
    final people = widget.people
        .where((c) => c.peer.toLowerCase().contains(q))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.conversationsNewMessage,
                textAlign: TextAlign.center,
                style: t.title.copyWith(color: p.textPrimary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(KSpacing.lg),
              child: TextField(
                key: ConversationsPreviewScreen.newMessageSearchKey,
                controller: _query,
                onChanged: (_) => setState(() {}),
                style: t.body,
                decoration: InputDecoration(
                  hintText: l10n.conversationsSearchPeople,
                  filled: true,
                  fillColor: p.surfaceOverlay,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in people)
                    ListTile(
                      key: ConversationsPreviewScreen.personKey(c.peer),
                      leading: _PresenceAvatar(
                        name: c.peer,
                        size: KSizes.avatarSm,
                        online: c.online,
                        photo: c.photo,
                      ),
                      title: Text(c.peer, style: t.bodyStrong),
                      onTap: () => Navigator.pop(context, c),
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

class _ConversationRow extends StatelessWidget {
  const new({required this.item, required this.onTap});

  final ConversationSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final t = context.textStyles;
    final preview = switch (item.last) {
      ConversationLast.text => item.text,
      ConversationLast.sharedVideo => l10n.conversationsSharedVideo,
      ConversationLast.none => l10n.conversationsSayHi(
        KFormat.bidiIsolate(item.peer),
      ),
    };
    final time =
        KFormat.relative(
          item.at,
          clock.now(),
          l10n,
          Localizations.localeOf(context).toLanguageTag(),
        ) ??
        l10n.feedPostJustNow;
    return Semantics(
      key: ConversationsPreviewScreen.rowKey(item.peer),
      button: true,
      label: item.unread ? l10n.conversationsUnread(item.peer) : item.peer,
      value: [
        preview,
        time,
        if (item.unread) l10n.conversationsUnreadCount(item.unreadCount),
        if (item.online) l10n.chatOnline,
        if (item.muted) l10n.conversationsMuted,
      ].join(', '),
      excludeSemantics: true,
      // D68: unread shows in the type, the time and the count, not a
      // tinted block.
      child: Material(
        color: p.background,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: item.unread
                  ? KConversations.unreadRowHeight
                  : KConversations.rowHeight,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: KConversations.startInset,
                end: KConversations.endInset,
                top: KSpacing.sm,
                bottom: KSpacing.sm,
              ),
              child: Row(
                children: [
                  _PresenceAvatar(
                    name: item.peer,
                    size: KConversations.avatar,
                    online: item.online,
                    photo: item.photo,
                  ),
                  const SizedBox(width: KConversations.avatarGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.peer,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodyStrong.copyWith(
                                  fontSize: KConversations.nameSize,
                                  fontWeight: item.unread
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
                                size: KConversations.mutedIcon,
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
                            fontSize: KConversations.previewSize,
                            color: item.unread
                                ? p.textPrimary
                                : p.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  // The time lines up with the name, the unread count with
                  // the message under it (D68).
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        time,
                        style: t.caption.copyWith(
                          fontSize: KConversations.timeSize,
                          color: item.unread ? p.primaryText : p.textTertiary,
                        ),
                      ),
                      const SizedBox(height: KSpacing.xs + 2),
                      if (item.unread)
                        Container(
                          constraints: const BoxConstraints(
                            minWidth: KConversations.unreadBadge,
                          ),
                          height: KConversations.unreadBadge,
                          padding: const EdgeInsets.symmetric(
                            horizontal: KSpacing.xs + 2,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            // A muted conversation counts quietly.
                            color: item.muted ? p.textTertiary : p.primary,
                            borderRadius: BorderRadius.circular(KRadius.pill),
                          ),
                          child: Text(
                            KFormat.compact(item.unreadCount, l10n),
                            style: t.caption.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              height: 1,
                              color: p.onPrimary,
                            ),
                          ),
                        )
                      else
                        // Keeps the time level with the name.
                        const SizedBox(height: KConversations.unreadBadge),
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

class _SkeletonRow extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: KConversations.rowHeight,
    child: Padding(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: KConversations.startInset,
      ),
      child: Row(
        children: [
          KSkeleton(
            width: KConversations.avatar,
            height: KConversations.avatar,
            circle: true,
          ),
          SizedBox(width: KConversations.avatarGap),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KSkeleton(width: 120, height: 14),
                SizedBox(height: KSpacing.sm),
                KSkeleton(width: 180, height: 12),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
