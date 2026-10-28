import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Who liked a post (`GET /posts/{postId}/likes`), newest first, paged.
class PostLikers extends AsyncNotifier<FeedItems<UserSummary>> {
  new(this.postId);

  final String postId;
  String? _next;

  @override
  Future<FeedItems<UserSummary>> build() async {
    final repo = ref.watch(postsRepositoryProvider);
    ref.watch(currentUserProvider.select((u) => u?.id));
    final page = await repo.likers(postId);
    _next = page.next;
    return FeedItems(page.items, hasMore: _next != null);
  }

  /// The next page, when one exists and none is loading.
  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(FeedItems(s.items, hasMore: true, loadingMore: true));
    try {
      final page = await ref
          .read(postsRepositoryProvider)
          .likers(postId, cursor: _next);
      if (!ref.mounted) return;
      _next = page.next;
      final known = {for (final u in s.items) u.id};
      state = AsyncData(
        FeedItems([
          ...s.items,
          for (final u in page.items)
            if (!known.contains(u.id)) u,
        ], hasMore: _next != null),
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = AsyncData(FeedItems(s.items, hasMore: true, loadMoreError: e));
    }
  }
}

final AsyncNotifierProviderFamily<PostLikers, FeedItems<UserSummary>, String>
postLikersProvider = AsyncNotifierProvider.autoDispose.family(PostLikers.new);

/// `/posts/:postId/likes` (KL-060): who liked a post; a row opens the
/// profile. When the author hides the like count only the author may see
/// the list (403): the screen says so. A post that is gone (404) too.
class LikersScreen extends ConsumerWidget {
  const new({required this.postId, super.key});

  final String postId;

  static const emptyKey = Key('likers.empty');
  static const hiddenKey = Key('likers.hidden');
  static Key userKey(String username) => Key('likers.user.$username');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = postLikersProvider(postId);
    return Scaffold(
      appBar: KAppBar(title: Text(l10n.likersTitle)),
      body: switch (ref.watch(provider)) {
        AsyncValue(value: FeedItems(:final items)) when items.isEmpty =>
          KEmptyState(
            key: emptyKey,
            icon: Icons.favorite_border_rounded,
            title: l10n.likersEmpty,
            message: l10n.likersEmptyBody,
          ),
        AsyncValue(
          value: FeedItems(:final items, :final hasMore, :final loadMoreError),
        ) =>
          ListView.builder(
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
                          onPressed: () =>
                              ref.read(provider.notifier).loadMore(),
                          child: Text(l10n.actionRetry),
                        ),
                      );
              }
              final u = items[i];
              final name = u.displayName.isEmpty ? u.username : u.displayName;
              return ListTile(
                key: userKey(u.username),
                leading: ExcludeSemantics(
                  child: KAvatar(name: name, imageUrl: u.avatarUrl),
                ),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  l10n.profileUsername(u.username),
                  maxLines: 1,
                  textDirection: TextDirection.ltr,
                  textAlign: Directionality.of(context) == TextDirection.rtl
                      ? TextAlign.right
                      : TextAlign.left,
                ),
                onTap: () => context.push(AppRoutes.userProfile(u.username)),
              );
            },
          ),
        AsyncError(:final error) => switch (toAppFailure(error)) {
          ServerFailure(code: ErrorCode.authForbidden) => KEmptyState(
            key: hiddenKey,
            icon: Icons.visibility_off_outlined,
            title: l10n.likersHiddenTitle,
            message: l10n.likersHiddenBody,
          ),
          ServerFailure(code: ErrorCode.notFound) => KEmptyState(
            icon: Icons.visibility_off_outlined,
            title: l10n.postUnavailableTitle,
            message: l10n.postUnavailableBody,
          ),
          final failure => FailureErrorState(
            title: l10n.errorTitle,
            failure: failure,
            onRetry: () => ref.invalidate(provider),
          ),
        },
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
