import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/stories/application/stories_controller.dart';
import 'package:kabso_live/features/stories/presentation/story_viewer_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/me/stories` (CP-008): your stories, active and expired, newest first,
/// as a 3-column grid of 9:16 covers with their date; only you see it. A
/// cover opens the stories from there; "+" posts a new one.
class StoryArchiveScreen extends ConsumerWidget {
  const new({super.key});

  static const emptyKey = Key('storyArchive.empty');
  static const addKey = Key('storyArchive.add');
  static Key cellKey(String id) => Key('storyArchive.$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final tag = Localizations.localeOf(context).toLanguageTag();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.storyArchiveTitle),
        actions: [
          IconButton(
            key: addKey,
            tooltip: l10n.storyAdd,
            onPressed: () => context.push(AppRoutes.newStory),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: switch (ref.watch(storyArchiveProvider)) {
        AsyncValue(value: FeedItems(:final items)) when items.isEmpty =>
          KEmptyState(
            key: emptyKey,
            icon: Icons.history_rounded,
            title: l10n.storyArchiveEmpty,
            message: l10n.storyArchiveEmptyBody,
          ),
        AsyncValue(
          value: FeedItems(:final items, :final hasMore, :final loadMoreError),
        ) =>
          RefreshIndicator(
            onRefresh: () => ref.refresh(storyArchiveProvider.future),
            child: CustomScrollView(
              slivers: [
                SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: KProfile.gridGap,
                    crossAxisSpacing: KProfile.gridGap,
                    childAspectRatio: 9 / 16,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final s = items[i];
                    final date = KFormat.date(s.createdAt, tag);
                    return Semantics(
                      button: true,
                      label: l10n.storyArchiveCell(date),
                      excludeSemantics: true,
                      child: InkWell(
                        key: cellKey(s.id),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            fullscreenDialog: true,
                            builder: (_) => StoryViewerScreen.list(
                              stories: items,
                              start: i,
                            ),
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: p.surfaceRaised,
                              child: Image.network(
                                s.media.thumbUrl,
                                fit: BoxFit.cover,
                                excludeFromSemantics: true,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.expand(),
                              ),
                            ),
                            PositionedDirectional(
                              start: KSpacing.xs,
                              top: KSpacing.xs,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: KSpacing.xs,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x99000000),
                                  borderRadius: BorderRadius.circular(
                                    KRadius.sm,
                                  ),
                                ),
                                child: Text(
                                  date,
                                  style: context.textStyles.caption.copyWith(
                                    color: const Color(0xFFFFFFFF),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (hasMore)
                  SliverToBoxAdapter(
                    child: loadMoreError == null
                        ? PostGridLoadMore(
                            key: ValueKey(items.length),
                            onVisible: () => ref
                                .read(storyArchiveProvider.notifier)
                                .loadMore(),
                          )
                        : Center(
                            child: TextButton(
                              onPressed: () => ref
                                  .read(storyArchiveProvider.notifier)
                                  .loadMore(),
                              child: Text(l10n.actionRetry),
                            ),
                          ),
                  ),
              ],
            ),
          ),
        AsyncError(:final error) => FailureErrorState(
          title: l10n.errorTitle,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(storyArchiveProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
