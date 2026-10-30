import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/follows/data/follow_requests_repository.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The caller's pending follow requests (D175, CONVENTIONS §10.47), newest
/// first and paged; [total] counts them all. Accept and Decline take the
/// row away; a failure keeps it and is rethrown.
class FollowRequestsController extends AsyncNotifier<FeedItems<FollowRequest>> {
  String? _next;

  /// Every pending request (the server's `total`, minus answered ones).
  int total = 0;

  final Set<String> _busy = {};

  bool isBusy(String username) => _busy.contains(username);

  @override
  Future<FeedItems<FollowRequest>> build() async {
    ref.watch(currentUserProvider.select((u) => u?.id));
    final page = await ref.watch(followRequestsRepositoryProvider).list();
    _next = page.next;
    total = page.total;
    return FeedItems(page.items, hasMore: _next != null);
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(FeedItems(s.items, hasMore: true, loadingMore: true));
    try {
      final page = await ref
          .read(followRequestsRepositoryProvider)
          .list(cursor: _next);
      if (!ref.mounted) return;
      _next = page.next;
      total = page.total;
      final known = {for (final r in s.items) r.user.id};
      state = AsyncData(
        FeedItems([
          ...s.items,
          for (final r in page.items)
            if (!known.contains(r.user.id)) r,
        ], hasMore: _next != null),
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = AsyncData(FeedItems(s.items, hasMore: true, loadMoreError: e));
    }
  }

  /// Accepts ([accept] true) or declines the request of [request].
  Future<void> answer(FollowRequest request, {required bool accept}) async {
    final username = request.user.username;
    if (_busy.contains(username)) return;
    _busy.add(username);
    state = AsyncData(state.value ?? const FeedItems([]));
    try {
      final repo = ref.read(followRequestsRepositoryProvider);
      if (accept) {
        await repo.accept(username);
        // The own follower count moved.
        final me = ref.read(currentUserProvider);
        if (me != null) ref.invalidate(profileStatsProvider(me.username));
      } else {
        await repo.decline(username);
      }
      if (!ref.mounted) return;
      final s = state.value;
      if (s == null) return;
      total = (total - 1).clamp(0, 1 << 30);
      state = AsyncData(
        FeedItems([
          for (final r in s.items)
            if (r.user.id != request.user.id) r,
        ], hasMore: s.hasMore),
      );
    } finally {
      _busy.remove(username);
    }
  }
}

final AsyncNotifierProvider<FollowRequestsController, FeedItems<FollowRequest>>
followRequestsProvider =
    AsyncNotifierProvider.autoDispose<
      FollowRequestsController,
      FeedItems<FollowRequest>
    >(FollowRequestsController.new);

/// `/settings/follow-requests` (D175, owner: «طلبات المتابعة»): who asked to
/// follow the private account, with Accept and Decline.
class FollowRequestsScreen extends ConsumerWidget {
  const new({super.key});

  static const emptyKey = Key('followRequests.empty');
  static Key acceptKey(String username) =>
      Key('followRequests.$username.accept');
  static Key declineKey(String username) =>
      Key('followRequests.$username.decline');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final list = ref.watch(followRequestsProvider);
    final controller = ref.read(followRequestsProvider.notifier);

    Future<void> answer(FollowRequest r, {required bool accept}) async {
      final name = r.user.displayName.isEmpty
          ? r.user.username
          : r.user.displayName;
      try {
        await controller.answer(r, accept: accept);
        if (!context.mounted) return;
        KSnack.success(
          context,
          accept
              ? l10n.followRequestAccepted(KFormat.bidiIsolate(name))
              : l10n.followRequestDeclined,
        );
      } on Object catch (e) {
        if (context.mounted) {
          KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
        }
      }
    }

    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(title: Text(l10n.followRequestsTitle)),
      body: switch (list) {
        AsyncValue(value: FeedItems(:final items)) when items.isEmpty =>
          KEmptyState(
            key: emptyKey,
            icon: Icons.person_add_alt_outlined,
            title: l10n.followRequestsEmptyTitle,
            message: l10n.followRequestsEmptyBody,
          ),
        AsyncValue(value: FeedItems(:final items, :final hasMore)) =>
          RefreshIndicator(
            onRefresh: () => ref.refresh(followRequestsProvider.future),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length + (hasMore ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == items.length) {
                  return PostGridLoadMore(
                    key: ValueKey(items.length),
                    onVisible: controller.loadMore,
                  );
                }
                final r = items[i];
                final u = r.user;
                final name = u.displayName.isEmpty ? u.username : u.displayName;
                final busy = controller.isBusy(u.username);
                return Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    KSpacing.lg,
                    KSpacing.sm,
                    KSpacing.lg,
                    KSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              context.push(AppRoutes.userProfile(u.username)),
                          child: Row(
                            children: [
                              ExcludeSemantics(
                                child: KAvatar(
                                  name: name,
                                  imageUrl: u.avatarUrl,
                                ),
                              ),
                              const SizedBox(width: KSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.textStyles.bodyStrong,
                                    ),
                                    Text(
                                      KHandle.text(
                                        l10n,
                                        u.username,
                                        premiumTier: u.premiumTier,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textDirection: TextDirection.ltr,
                                      style: context.textStyles.caption
                                          .copyWith(color: p.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: KSpacing.sm),
                      FilledButton(
                        key: acceptKey(u.username),
                        style: FilledButton.styleFrom(
                          backgroundColor: p.primary,
                          foregroundColor: p.onPrimary,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(
                            horizontal: KSpacing.md,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(KRadius.sm),
                          ),
                        ),
                        onPressed: busy ? null : () => answer(r, accept: true),
                        child: Text(l10n.followRequestAccept),
                      ),
                      const SizedBox(width: KSpacing.xs),
                      OutlinedButton(
                        key: declineKey(u.username),
                        style: profileSecondaryButtonStyle(context).copyWith(
                          minimumSize: const WidgetStatePropertyAll(
                            Size(0, 36),
                          ),
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: KSpacing.md),
                          ),
                        ),
                        onPressed: busy ? null : () => answer(r, accept: false),
                        child: Text(l10n.followRequestDecline),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        AsyncError(:final error) => FailureErrorState(
          title: l10n.errorTitle,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(followRequestsProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
