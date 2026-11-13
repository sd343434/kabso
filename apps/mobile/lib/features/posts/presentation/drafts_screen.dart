import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/create/compose_widgets.dart';
import 'package:kabso_live/features/posts/application/my_posts_controller.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/me/drafts` (KL-060): the caller's drafts (newest first) and
/// scheduled posts (soonest first) from `GET /me/posts?status=`. A row
/// opens the post's edit screen, where it can be changed, posted now,
/// scheduled or moved back to drafts; the bin deletes it after asking.
/// Only the author ever sees these posts (§11.2).
class DraftsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static Key tabKey(MyPostsList l) => Key('drafts.tab.${l.name}');
  static Key rowKey(String postId) => Key('drafts.row.$postId');
  static Key deleteKey(String postId) => Key('drafts.row.$postId.delete');
  static const emptyKey = Key('drafts.empty');
  static const deleteConfirmKey = Key('drafts.delete.confirm');

  @override
  ConsumerState<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends ConsumerState<DraftsScreen> {
  MyPostsList _list = MyPostsList.drafts;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: KAppBar(title: Text(l10n.draftsTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(KSpacing.md),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<MyPostsList>(
                showSelectedIcon: false,
                segments: [
                  for (final (l, label) in [
                    (MyPostsList.drafts, l10n.draftsTabDrafts),
                    (MyPostsList.scheduled, l10n.draftsTabScheduled),
                  ])
                    ButtonSegment(
                      value: l,
                      label: Text(label, key: DraftsScreen.tabKey(l)),
                    ),
                ],
                selected: {_list},
                onSelectionChanged: (s) => setState(() => _list = s.first),
              ),
            ),
          ),
          Expanded(
            child: _MyPostsList(key: ValueKey(_list), list: _list),
          ),
        ],
      ),
    );
  }
}

class _MyPostsList extends ConsumerWidget {
  const new({required this.list, super.key});

  final MyPostsList list;

  Future<void> _delete(BuildContext context, WidgetRef ref, Post post) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.draftsDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            key: DraftsScreen.deleteConfirmKey,
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.feedPostDelete),
          ),
        ],
      ),
    );
    if (!(ok ?? false) || !context.mounted) return;
    try {
      await ref.read(postsRepositoryProvider).deletePost(post.id);
      ref.read(removedPostsProvider.notifier).add(post.id);
      if (context.mounted) KSnack.success(context, l10n.draftsDeleted);
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
    final provider = myPostsProvider(list);
    final drafts = list == MyPostsList.drafts;
    return switch (ref.watch(provider)) {
      AsyncValue(value: FeedItems(:final items)) when items.isEmpty =>
        KEmptyState(
          key: DraftsScreen.emptyKey,
          icon: drafts ? Icons.drafts_outlined : Icons.schedule_rounded,
          title: drafts ? l10n.draftsEmpty : l10n.scheduledEmpty,
          message: drafts ? l10n.draftsEmptyBody : l10n.scheduledEmptyBody,
        ),
      AsyncValue(
        value: FeedItems(:final items, :final hasMore, :final loadMoreError),
      ) =>
        RefreshIndicator(
          onRefresh: () => ref.refresh(provider.future),
          child: ListView.separated(
            itemCount: items.length + (hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(height: 1),
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
              final post = items[i];
              final when = scheduleLabel(
                context,
                drafts ? post.createdAt : (post.publishAt ?? post.createdAt),
              );
              final thumb = post.media.isEmpty ? null : post.media.first;
              return ListTile(
                key: DraftsScreen.rowKey(post.id),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(KRadius.sm),
                  child: SizedBox.square(
                    dimension: KSizes.avatarMd,
                    child: ColoredBox(
                      color: p.surfaceOverlay,
                      child: thumb == null
                          ? Icon(Icons.notes_rounded, color: p.textSecondary)
                          : Image.network(
                              thumb.thumbUrl,
                              fit: BoxFit.cover,
                              excludeFromSemantics: true,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                    ),
                  ),
                ),
                title: Text(
                  post.text.isEmpty ? l10n.draftsNoText : post.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  drafts
                      ? l10n.draftsSavedOn(when)
                      : l10n.draftsPublishesOn(when),
                  style: TextStyle(color: p.textSecondary),
                ),
                trailing: IconButton(
                  key: DraftsScreen.deleteKey(post.id),
                  tooltip: l10n.feedPostDelete,
                  onPressed: () => _delete(context, ref, post),
                  icon: Icon(Icons.delete_outline, color: p.textSecondary),
                ),
                onTap: () => context.push(AppRoutes.editPost(post.id)),
              );
            },
          ),
        ),
      AsyncError(:final error) => FailureErrorState(
        title: l10n.errorTitle,
        failure: toAppFailure(error),
        onRetry: () => ref.invalidate(provider),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}
