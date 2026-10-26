import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/follows/application/follow_list_controller.dart';
import 'package:kabso_live/features/follows/domain/follow_list_models.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/users/:username/follows?tab=followers|following` (D121): a user's
/// followers and the accounts they follow, in two tabs labelled like the
/// profile counts (المتابِعون / يتابِع). Each tab is a paged list (newest
/// follow first) with pull to refresh; a row shows the photo, name and
/// @username and opens that profile, with Follow / Following / Follow back
/// (optimistic, rolled back on failure). A private account the reader does
/// not follow (403) and a missing or blocked account (404) have their own
/// states.
class FollowListsScreen extends StatelessWidget {
  const new({
    required this.username,
    this.initial = FollowListKind.followers,
    super.key,
  });

  final String username;
  final FollowListKind initial;

  static Key tabKey(FollowListKind kind) => Key('follows.tab.${kind.path}');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return DefaultTabController(
      length: FollowListKind.values.length,
      initialIndex: initial.index,
      child: Scaffold(
        backgroundColor: p.background,
        appBar: AppBar(
          backgroundColor: p.background,
          centerTitle: true,
          title: Text(
            l10n.profileUsername(username),
            textDirection: TextDirection.ltr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          bottom: TabBar(
            tabs: [
              for (final kind in FollowListKind.values)
                Tab(key: tabKey(kind), text: followListLabel(l10n, kind)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final kind in FollowListKind.values)
              FollowListView(username: username, kind: kind),
          ],
        ),
      ),
    );
  }
}

/// The tab label of [kind]: the profile's count label.
String followListLabel(AppLocalizations l10n, FollowListKind kind) =>
    switch (kind) {
      FollowListKind.followers => l10n.profileFollowers,
      FollowListKind.following => l10n.profileFollowingCount,
    };

/// One list of the screen.
class FollowListView extends ConsumerWidget {
  const new({required this.username, required this.kind, super.key});

  final String username;
  final FollowListKind kind;

  static const emptyKey = Key('follows.empty');
  static const privateKey = Key('follows.private');
  static const notFoundKey = Key('follows.notFound');
  static const loadMoreRetryKey = Key('follows.loadMoreRetry');

  static Key rowKey(String username) => Key('follows.row.$username');
  static Key buttonKey(String username) => Key('follows.button.$username');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = followListProvider((username: username, kind: kind));
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
            padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
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
                listKey: (username: username, kind: kind),
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

/// One person: photo, name, @username and the Follow control; a tap opens
/// their profile.
class FollowListRow extends ConsumerWidget {
  const new({required this.item, required this.listKey, super.key});

  final FollowListItem item;
  final FollowListKey listKey;

  /// The widest a row's button gets (large text scales keep the name).
  static const double buttonMaxWidth = 168;
  static const double buttonHeight = 36;

  Future<void> _set(
    BuildContext context,
    WidgetRef ref, {
    required bool follow,
  }) async {
    final l10n = context.l10n;
    if (!follow && item.isPrivate) {
      // Unfollowing a private account cannot be undone without a request.
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
      if (ok != true) return;
    }
    try {
      await ref
          .read(followListProvider(listKey).notifier)
          .setFollowing(item, follow: follow);
    } on Object catch (e) {
      if (context.mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    Widget? button;
    if (item.canToggle) {
      final label = item.followedByMe
          ? l10n.liveFollowing
          : item.followsMe
          ? l10n.followListsFollowBack
          : l10n.liveFollow;
      final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
      const padding = EdgeInsets.symmetric(horizontal: KSpacing.md);
      const minimum = Size(0, buttonHeight);
      button = ConstrainedBox(
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
    return InkWell(
      key: FollowListView.rowKey(item.username),
      onTap: () => context.push(AppRoutes.userProfile(item.username)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.lg,
          vertical: KSpacing.sm,
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: KAvatar(name: item.name, imageUrl: item.avatarUrl),
            ),
            const SizedBox(width: KSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyStrong.copyWith(color: p.textPrimary),
                  ),
                  Text(
                    l10n.profileUsername(item.username),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    textAlign: rtl ? TextAlign.right : TextAlign.left,
                    style: t.caption.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
            if (button != null) ...[const SizedBox(width: KSpacing.sm), button],
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
    padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
    children: [
      for (var i = 0; i < 8; i++)
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: KSpacing.lg,
            vertical: KSpacing.sm,
          ),
          child: Row(
            children: [
              KSkeleton(
                width: KSizes.avatarMd,
                height: KSizes.avatarMd,
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
