import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/follows/application/follow_list_controller.dart';
import 'package:kabso_live/features/follows/domain/follow_list_models.dart';
import 'package:kabso_live/features/profile/application/public_profile_controller.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/safety/safety_actions.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/users/:username/follows?tab=followers|following` (D121, restyled after
/// the owner's reference in D125): a header (back, @username, add people →
/// Discover), two tabs with the profile's counts ("N المتابِعون" / "N يتابع",
/// underlined when selected), a rounded search field (server-side `q`,
/// debounced) and the sort row (default = newest follow first, or oldest
/// first). Rows: photo, bold username, the display name in grey. On your
/// own lists: "مراسلة" (the conversation) and ⋯ (unfollow or remove the
/// follower, report, block); on someone else's: Follow / Following / Follow
/// back (optimistic, rolled back on failure) and ⋯ (report, block). A
/// private account the reader does not follow (403) and a missing or
/// blocked account (404) have their own states.
class FollowListsScreen extends ConsumerStatefulWidget {
  const new({
    required this.username,
    this.initial = FollowListKind.followers,
    super.key,
  });

  final String username;
  final FollowListKind initial;

  static Key tabKey(FollowListKind kind) => Key('follows.tab.${kind.path}');
  static const backKey = Key('follows.back');
  static const addPeopleKey = Key('follows.addPeople');
  static const searchKey = Key('follows.search');
  static const searchClearKey = Key('follows.searchClear');
  static const sortKey = Key('follows.sort');

  /// The search waits this long after the last keystroke (D125).
  static const searchDebounce = Duration(milliseconds: 300);

  /// The longest search the server takes (`q`, 1–30 characters).
  static const searchMaxLength = 30;

  /// The header's round buttons.
  static const double headerButton = 40;

  @override
  ConsumerState<FollowListsScreen> createState() => _FollowListsScreenState();
}

class _FollowListsScreenState extends ConsumerState<FollowListsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  FollowListOrder _order = FollowListOrder.newest;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(FollowListsScreen.searchDebounce, () {
      if (mounted) setState(() => _query = value.trim());
    });
    // The clear button follows the text at once.
    setState(() {});
  }

  void _clear() {
    _debounce?.cancel();
    _search.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final username = widget.username;
    final me = ref.watch(currentUserProvider)?.username;
    final mine = me != null && me.toLowerCase() == username.toLowerCase();
    final profile = ref.watch(publicProfileProvider(username)).value;
    String tabLabel(FollowListKind kind) {
      final count = switch (kind) {
        FollowListKind.followers => profile?.followerCount,
        FollowListKind.following => profile?.followingCount,
      };
      if (count == null) return followListLabel(l10n, kind);
      final n = KFormat.compact(count, l10n);
      return switch (kind) {
        FollowListKind.followers => l10n.followListsTabFollowers(n),
        FollowListKind.following => l10n.followListsTabFollowing(n),
      };
    }

    return DefaultTabController(
      length: FollowListKind.values.length,
      initialIndex: widget.initial.index,
      child: Scaffold(
        backgroundColor: p.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(username: username),
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsetsDirectional.only(start: KSpacing.xs),
                labelPadding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.md,
                ),
                labelColor: p.textPrimary,
                unselectedLabelColor: p.textSecondary,
                labelStyle: t.bodyStrong.copyWith(fontWeight: FontWeight.w700),
                unselectedLabelStyle: t.bodyStrong.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(color: p.textPrimary, width: 2.5),
                ),
                dividerColor: p.border,
                dividerHeight: 1,
                tabs: [
                  for (final kind in FollowListKind.values)
                    Tab(
                      key: FollowListsScreen.tabKey(kind),
                      text: tabLabel(kind),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  KSpacing.md,
                  KSpacing.md,
                  KSpacing.md,
                  0,
                ),
                child: _SearchField(
                  controller: _search,
                  onChanged: _changed,
                  onClear: _clear,
                ),
              ),
              _SortRow(
                order: _order,
                onToggle: () => setState(
                  () => _order = _order == FollowListOrder.newest
                      ? FollowListOrder.oldest
                      : FollowListOrder.newest,
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final kind in FollowListKind.values)
                      FollowListView(
                        username: username,
                        kind: kind,
                        query: _query,
                        order: _order,
                        mine: mine,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tab label of [kind] without a count: the profile's count label.
String followListLabel(AppLocalizations l10n, FollowListKind kind) =>
    switch (kind) {
      FollowListKind.followers => l10n.profileFollowers,
      FollowListKind.following => l10n.profileFollowingCount,
    };

/// A round, outlined header button.
class _RoundButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const size = FollowListsScreen.headerButton;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: KSizes.minTouchTarget,
          child: Center(
            child: Material(
              color: p.background,
              shape: CircleBorder(side: BorderSide(color: p.border)),
              elevation: 1,
              shadowColor: const Color(0x33000000),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: SizedBox.square(
                  dimension: size,
                  child: Icon(icon, size: 22, color: p.textPrimary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Back, the @username centred, add people (Discover: search for people).
class _Header extends StatelessWidget {
  const new({required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.sm,
        vertical: KSpacing.xs,
      ),
      child: Row(
        children: [
          _RoundButton(
            key: FollowListsScreen.backKey,
            // The chevron points to the reading start.
            icon: rtl
                ? Icons.arrow_forward_ios_rounded
                : Icons.arrow_back_ios_new_rounded,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                username,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.title.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          _RoundButton(
            key: FollowListsScreen.addPeopleKey,
            icon: Icons.person_add_alt_outlined,
            tooltip: l10n.followListsAddPeople,
            onPressed: () => context.push(AppRoutes.discover),
          ),
        ],
      ),
    );
  }
}

/// The rounded grey search field (search within the list).
class _SearchField extends StatelessWidget {
  const new({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return TextField(
      key: FollowListsScreen.searchKey,
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      inputFormatters: [
        LengthLimitingTextInputFormatter(FollowListsScreen.searchMaxLength),
      ],
      style: t.body.copyWith(color: p.textPrimary),
      decoration: InputDecoration(
        hintText: l10n.followListsSearchHint,
        hintStyle: t.body.copyWith(color: p.textSecondary),
        filled: true,
        // A visible grey in both themes (light #ECECF0, dark #2A2A32).
        fillColor: p.surfaceOverlay,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: KSpacing.sm + 2),
        prefixIcon: Icon(Icons.search_rounded, color: p.textSecondary),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                key: FollowListsScreen.searchClearKey,
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                icon: Icon(
                  Icons.cancel_rounded,
                  size: 18,
                  color: p.textSecondary,
                ),
                onPressed: onClear,
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KRadius.pill),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KRadius.pill),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KRadius.pill),
          borderSide: BorderSide(color: p.border),
        ),
      ),
    );
  }
}

/// "الترتيب: الافتراضي" with the toggle (newest first ↔ oldest first).
class _SortRow extends StatelessWidget {
  const new({required this.order, required this.onToggle});

  final FollowListOrder order;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final value = order == FollowListOrder.newest
        ? l10n.followListsSortDefault
        : l10n.followListsSortOldest;
    return Semantics(
      button: true,
      label: '${l10n.followListsSortBy} $value',
      hint: l10n.followListsSortToggle,
      excludeSemantics: true,
      child: InkWell(
        key: FollowListsScreen.sortKey,
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            KSpacing.lg,
            KSpacing.sm,
            KSpacing.sm,
            KSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${l10n.followListsSortBy} '),
                      TextSpan(
                        text: value,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.body.copyWith(color: p.textPrimary),
                ),
              ),
              SizedBox.square(
                dimension: KSizes.minTouchTarget,
                child: Icon(
                  Icons.swap_vert_rounded,
                  size: 26,
                  color: p.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One list of the screen.
class FollowListView extends ConsumerWidget {
  const new({
    required this.username,
    required this.kind,
    super.key,
    this.query = '',
    this.order = FollowListOrder.newest,
    this.mine = false,
  });

  final String username;
  final FollowListKind kind;

  /// The search ('' = none).
  final String query;
  final FollowListOrder order;

  /// The reader's own list (Message and the owner's ⋯ actions).
  final bool mine;

  static const emptyKey = Key('follows.empty');
  static const noMatchKey = Key('follows.noMatch');
  static const privateKey = Key('follows.private');
  static const notFoundKey = Key('follows.notFound');
  static const loadMoreRetryKey = Key('follows.loadMoreRetry');

  static Key rowKey(String username) => Key('follows.row.$username');
  static Key buttonKey(String username) => Key('follows.button.$username');
  static Key messageKey(String username) => Key('follows.message.$username');
  static Key moreKey(String username) => Key('follows.more.$username');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final listKey = followListKey(username, kind, query: query, order: order);
    final provider = followListProvider(listKey);
    Future<void> refresh() =>
        ref.refresh(provider.future).then((_) {}, onError: (_) {});

    /// A state that still lets the user pull to refresh.
    Widget scrollableState(Widget child) => RefreshIndicator(
      onRefresh: refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: child),
          ),
        ],
      ),
    );

    return switch (ref.watch(provider)) {
      AsyncValue(value: FeedItems(:final items))
          when items.isEmpty && query.isNotEmpty =>
        scrollableState(
          KEmptyState(
            key: noMatchKey,
            icon: Icons.search_off_rounded,
            title: l10n.followListsNoMatch,
            message: l10n.followListsNoMatchBody(query),
          ),
        ),
      AsyncValue(value: FeedItems(:final items)) when items.isEmpty =>
        scrollableState(
          KEmptyState(
            key: emptyKey,
            icon: Icons.people_outline_rounded,
            title: kind == FollowListKind.followers
                ? l10n.followListsFollowersEmpty
                : l10n.followListsFollowingEmpty,
            message: kind == FollowListKind.followers
                ? l10n.followListsFollowersEmptyBody
                : l10n.followListsFollowingEmptyBody,
          ),
        ),
      AsyncValue(
        value: FeedItems(:final items, :final hasMore, :final loadMoreError),
      ) =>
        RefreshIndicator(
          onRefresh: refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
            itemCount: items.length + (hasMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == items.length) {
                return loadMoreError == null
                    ? PostGridLoadMore(
                        key: ValueKey(items.length),
                        onVisible: () => ref.read(provider.notifier).loadMore(),
                      )
                    : Center(
                        child: TextButton(
                          key: loadMoreRetryKey,
                          onPressed: () =>
                              ref.read(provider.notifier).loadMore(),
                          child: Text(l10n.actionRetry),
                        ),
                      );
              }
              return FollowListRow(
                item: items[i],
                listKey: listKey,
                mine: mine,
              );
            },
          ),
        ),
      AsyncError(:final error) => switch (toAppFailure(error)) {
        ServerFailure(code: ErrorCode.authForbidden) => scrollableState(
          KEmptyState(
            key: privateKey,
            icon: Icons.lock_outline_rounded,
            title: l10n.profilePrivateTitle,
            message: l10n.followListsPrivateBody,
          ),
        ),
        ServerFailure(code: ErrorCode.notFound) => scrollableState(
          KEmptyState(
            key: notFoundKey,
            icon: Icons.person_off_outlined,
            title: l10n.profileNotFoundTitle,
            message: l10n.profileNotFoundBody,
          ),
        ),
        final failure => FailureErrorState(
          title: l10n.errorTitle,
          failure: failure,
          onRetry: () => ref.invalidate(provider),
        ),
      },
      _ => const _FollowListSkeleton(),
    };
  }
}

/// The ⋯ menu's actions.
enum _RowAction { followBack, unfollow, removeFollower, report, block }

/// One person: photo, bold username, display name in grey; Message (own
/// lists) or the Follow control (others' lists); ⋯. A tap opens their
/// profile.
class FollowListRow extends ConsumerWidget {
  const new({
    required this.item,
    required this.listKey,
    super.key,
    this.mine = false,
  });

  final FollowListItem item;
  final FollowListKey listKey;

  /// The reader's own list.
  final bool mine;

  /// The widest a row's button gets (large text scales keep the name).
  static const double buttonMaxWidth = 168;
  static const double buttonHeight = 34;
  static const double avatarSize = 56;

  /// The Message button's least width (D125 reference).
  static const double messageMinWidth = 92;

  /// The Message button's corners, measured on the reference (≈ 12 px at
  /// 2.35 px/pt).
  static const double messageRadius = 6;

  FollowListController _notifier(WidgetRef ref) =>
      ref.read(followListProvider(listKey).notifier);

  /// Unfollowing a private account cannot be undone without a request.
  Future<bool> _confirmPrivateUnfollow(BuildContext context) async {
    if (!item.isPrivate) return true;
    final l10n = context.l10n;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(KSpacing.lg),
              child: Text(
                l10n.profileUnfollowConfirm(item.name),
                textAlign: TextAlign.center,
                style: sheet.textStyles.bodyStrong,
              ),
            ),
            ListTile(
              key: const Key('follows.unfollowConfirm'),
              title: Text(
                l10n.homeUnfollowAuthor(item.name),
                textAlign: TextAlign.center,
                style: TextStyle(color: sheet.palette.error),
              ),
              onTap: () => Navigator.of(sheet).pop(true),
            ),
          ],
        ),
      ),
    );
    return ok ?? false;
  }

  Future<void> _set(
    BuildContext context,
    WidgetRef ref, {
    required bool follow,
  }) async {
    final l10n = context.l10n;
    if (!follow && !await _confirmPrivateUnfollow(context)) return;
    try {
      await _notifier(ref).setFollowing(item, follow: follow);
    } on Object catch (e) {
      if (context.mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
    }
  }

  Future<void> _removeFollower(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.followListsRemoveFollowerTitle(item.name)),
        content: Text(l10n.followListsRemoveFollowerBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            key: const Key('follows.removeConfirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(
              l10n.followListsRemoveFollowerConfirm,
              style: TextStyle(color: dialog.palette.error),
            ),
          ),
        ],
      ),
    );
    if (!(ok ?? false) || !context.mounted) return;
    try {
      await _notifier(ref).removeFollower(item);
      if (context.mounted) {
        KSnack.success(context, l10n.followListsFollowerRemoved(item.name));
      }
    } on Object catch (e) {
      if (context.mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
    }
  }

  Future<void> _openMore(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final followers = listKey.kind == FollowListKind.followers;
    final action = await showModalBottomSheet<_RowAction>(
      context: context,
      builder: (sheet) {
        final p = sheet.palette;
        ListTile tile(
          _RowAction action,
          IconData icon,
          String label, {
          bool danger = false,
        }) => ListTile(
          key: Key('follows.menu.${action.name}'),
          leading: Icon(icon, color: danger ? p.error : p.textPrimary),
          title: Text(label, style: danger ? TextStyle(color: p.error) : null),
          onTap: () => Navigator.of(sheet).pop(action),
        );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mine && followers && !item.followedByMe && item.canToggle)
                tile(
                  _RowAction.followBack,
                  Icons.person_add_alt_outlined,
                  l10n.followListsFollowBack,
                ),
              if (mine && !followers && item.followedByMe)
                tile(
                  _RowAction.unfollow,
                  Icons.person_remove_outlined,
                  l10n.homeUnfollowAuthor(item.name),
                ),
              if (mine && followers)
                tile(
                  _RowAction.removeFollower,
                  Icons.person_off_outlined,
                  l10n.followListsRemoveFollower,
                ),
              tile(
                _RowAction.report,
                Icons.flag_outlined,
                l10n.safetyReportUser,
                danger: true,
              ),
              tile(
                _RowAction.block,
                Icons.block_rounded,
                l10n.safetyBlockUser(item.name),
                danger: true,
              ),
            ],
          ),
        );
      },
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _RowAction.followBack:
        await _set(context, ref, follow: true);
      case _RowAction.unfollow:
        if (!await _confirmPrivateUnfollow(context) || !context.mounted) {
          return;
        }
        try {
          await _notifier(ref).setFollowing(item, follow: false);
          // Not followed any more: it leaves my Following list.
          _notifier(ref).drop(item.id);
        } on Object catch (e) {
          if (context.mounted) {
            KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
          }
        }
      case _RowAction.removeFollower:
        await _removeFollower(context, ref);
      case _RowAction.report:
        await reportUser(context, ref, userId: item.id);
      case _RowAction.block:
        final blocked = await confirmBlock(
          context,
          ref,
          username: item.username,
          name: item.name,
        );
        // Blocking removes the follows both ways (§11.7).
        if (blocked) _notifier(ref).drop(item.id);
    }
  }

  Widget? _followButton(BuildContext context, WidgetRef ref) {
    if (!item.canToggle) return null;
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final label = item.followedByMe
        ? l10n.liveFollowing
        : item.followsMe
        ? l10n.followListsFollowBack
        : l10n.liveFollow;
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    const padding = EdgeInsets.symmetric(horizontal: KSpacing.md);
    const minimum = Size(0, buttonHeight);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: buttonMaxWidth),
      child: item.followedByMe
          ? OutlinedButton(
              key: FollowListView.buttonKey(item.username),
              style: profileSecondaryButtonStyle(context).copyWith(
                padding: const WidgetStatePropertyAll(padding),
                minimumSize: const WidgetStatePropertyAll(minimum),
              ),
              onPressed: () => _set(context, ref, follow: false),
              child: text,
            )
          : FilledButton(
              key: FollowListView.buttonKey(item.username),
              style: FilledButton.styleFrom(
                backgroundColor: p.primary,
                foregroundColor: p.onPrimary,
                minimumSize: minimum,
                padding: padding,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KRadius.sm),
                ),
                textStyle: t.bodyStrong,
              ),
              onPressed: () => _set(context, ref, follow: true),
              child: text,
            ),
    );
  }

  Widget _messageButton(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: buttonMaxWidth),
      child: FilledButton(
        key: FollowListView.messageKey(item.username),
        style: FilledButton.styleFrom(
          backgroundColor: p.surfaceOverlay,
          foregroundColor: p.textPrimary,
          elevation: 0,
          minimumSize: const Size(messageMinWidth, buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(messageRadius),
          ),
          textStyle: t.bodyStrong,
        ),
        onPressed: () =>
            context.push(AppRoutes.chat(item.username), extra: item.name),
        child: Text(
          l10n.profileMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final trailing = item.isSelf
        ? null
        : mine
        ? _messageButton(context)
        : _followButton(context, ref);
    final hasName = item.displayName.isNotEmpty;
    return InkWell(
      key: FollowListView.rowKey(item.username),
      onTap: () => context.push(AppRoutes.userProfile(item.username)),
      child: Padding(
        // The ⋯ lines up with the sort icon above (both 32 pt from the end).
        padding: const EdgeInsetsDirectional.fromSTEB(
          KSpacing.md,
          KSpacing.xs + 1,
          KSpacing.sm,
          KSpacing.xs + 1,
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: KAvatar(
                name: item.name,
                imageUrl: item.avatarUrl,
                size: avatarSize,
              ),
            ),
            const SizedBox(width: KSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    textAlign: rtl ? TextAlign.right : TextAlign.left,
                    style: t.bodyStrong.copyWith(
                      color: p.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (hasName)
                    Text(
                      item.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.body.copyWith(color: p.textSecondary),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: KSpacing.sm),
              trailing,
            ],
            if (!item.isSelf)
              IconButton(
                key: FollowListView.moreKey(item.username),
                tooltip: l10n.followListsRowMore(item.name),
                icon: Icon(Icons.more_horiz_rounded, color: p.textPrimary),
                onPressed: () => _openMore(context, ref),
              )
            else
              const SizedBox(width: KSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _FollowListSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
    children: [
      for (var i = 0; i < 8; i++)
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: KSpacing.md,
            vertical: KSpacing.xs + 1,
          ),
          child: Row(
            children: [
              KSkeleton(
                width: FollowListRow.avatarSize,
                height: FollowListRow.avatarSize,
                circle: true,
              ),
              SizedBox(width: KSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KSkeleton(width: 140),
                    SizedBox(height: KSpacing.xs),
                    KSkeleton(width: 90),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
