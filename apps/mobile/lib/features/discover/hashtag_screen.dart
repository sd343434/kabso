import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/posts/application/search_controller.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/hashtags/:tag` (KL-060): the tag, its visible post count
/// (`GET /hashtags/{tag}`) and its posts as a grid
/// (`GET /hashtags/{tag}/posts`), recent or top (trending score over 30
/// days). An unused tag (404) says so.
class HashtagScreen extends ConsumerStatefulWidget {
  const new({required this.tag, super.key});

  final String tag;

  static const notFoundKey = Key('hashtag.notFound');
  static const emptyKey = Key('hashtag.empty');
  static Key sortKey(HashtagSort s) => Key('hashtag.sort.${s.name}');

  @override
  ConsumerState<HashtagScreen> createState() => _HashtagScreenState();
}

class _HashtagScreenState extends ConsumerState<HashtagScreen> {
  HashtagSort _sort = HashtagSort.recent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final tag = widget.tag;
    final info = ref.watch(hashtagProvider(tag));
    final key = (tag: tag, sort: _sort);
    final posts = ref.watch(hashtagPostsProvider(key));
    void more() => ref.read(hashtagPostsProvider(key).notifier).loadMore();
    final notFound = switch (info) {
      AsyncError(:final error) => switch (toAppFailure(error)) {
        ServerFailure(code: ErrorCode.notFound) => true,
        _ => false,
      },
      _ => false,
    };
    return Scaffold(
      appBar: KAppBar(title: Text(l10n.hashtagLabel(tag))),
      body: notFound
          ? KEmptyState(
              key: HashtagScreen.notFoundKey,
              icon: Icons.tag_rounded,
              title: l10n.hashtagNotFoundTitle,
              message: l10n.hashtagNotFoundBody,
            )
          : RefreshIndicator(
              onRefresh: () async {
                ref
                  ..invalidate(hashtagProvider(tag))
                  ..invalidate(hashtagPostsProvider(key));
                await ref.read(hashtagPostsProvider(key).future);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(KSpacing.md),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: p.primary.withValues(alpha: 0.09),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.tag_rounded,
                              size: 34,
                              color: p.primary,
                            ),
                          ),
                          const SizedBox(width: KSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.hashtagLabel(tag),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.textStyles.title.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (info.value case final h?)
                                  Text(
                                    l10n.hashtagPostCount(h.postCount),
                                    style: context.textStyles.caption.copyWith(
                                      color: p.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        KSpacing.md,
                        0,
                        KSpacing.md,
                        KSpacing.sm,
                      ),
                      child: SegmentedButton<HashtagSort>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: HashtagSort.recent,
                            label: Text(
                              l10n.hashtagRecent,
                              key: HashtagScreen.sortKey(HashtagSort.recent),
                            ),
                          ),
                          ButtonSegment(
                            value: HashtagSort.top,
                            label: Text(
                              l10n.hashtagTop,
                              key: HashtagScreen.sortKey(HashtagSort.top),
                            ),
                          ),
                        ],
                        selected: {_sort},
                        onSelectionChanged: (s) =>
                            setState(() => _sort = s.first),
                      ),
                    ),
                  ),
                  switch (posts) {
                    AsyncValue(value: FeedItems(:final items))
                        when items.isEmpty =>
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: KSpacing.xl),
                          child: KEmptyState(
                            key: HashtagScreen.emptyKey,
                            icon: Icons.grid_on_rounded,
                            title: l10n.hashtagEmpty,
                            message: l10n.hashtagNotFoundBody,
                            compact: true,
                          ),
                        ),
                      ),
                    AsyncValue(
                      value: FeedItems(
                        :final items,
                        :final hasMore,
                        :final loadMoreError,
                      ),
                    ) =>
                      SliverMainAxisGroup(
                        slivers: [
                          SliverGrid.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: KProfile.gridGap,
                                  crossAxisSpacing: KProfile.gridGap,
                                ),
                            itemCount: items.length,
                            itemBuilder: (_, i) => PostGridCell(item: items[i]),
                          ),
                          if (hasMore)
                            SliverToBoxAdapter(
                              child: loadMoreError == null
                                  ? PostGridLoadMore(
                                      key: ValueKey(items.length),
                                      onVisible: more,
                                    )
                                  : Center(
                                      child: TextButton(
                                        onPressed: more,
                                        child: Text(l10n.actionRetry),
                                      ),
                                    ),
                            ),
                        ],
                      ),
                    AsyncError(:final error) => SliverToBoxAdapter(
                      child: FailureErrorState(
                        title: l10n.errorTitle,
                        failure: toAppFailure(error),
                        onRetry: () =>
                            ref.invalidate(hashtagPostsProvider(key)),
                      ),
                    ),
                    _ => const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(KSpacing.xl),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  },
                ],
              ),
            ),
    );
  }
}
