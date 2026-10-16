import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/app/shell/feed_region.dart';
import 'package:kabso_live/app/shell/feed_tabs_scaffold.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/home` — the social feed (D36): Following · Popular · New (default
/// Popular) and search; no wordmark, no title (VG-05/22). Until the feed
/// API exists every tab shows its own compact unavailable state.
class HomeScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => FeedTabsScaffold(
    pageBuilder: (context, tab, selectTab) =>
        _HomeFeedPage(tab: tab, onSeePopular: () => selectTab(FeedTab.popular)),
  );
}

class _HomeFeedPage extends ConsumerWidget {
  const new({required this.tab, required this.onSeePopular});

  final FeedTab tab;
  final VoidCallback onSeePopular;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = homeFeedProvider(tab);
    return HomeFeedBody(
      tab: tab,
      content: ref.watch(provider),
      onRefresh: () => ref.refresh(provider.future),
      onRetry: () => ref.invalidate(provider),
      onSeePopular: onSeePopular,
    );
  }
}

/// One Home feed tab page (pure; the gallery renders it with samples).
class HomeFeedBody extends StatelessWidget {
  const new({
    required this.tab,
    required this.content,
    required this.onRefresh,
    required this.onRetry,
    required this.onSeePopular,
    super.key,
  });

  final FeedTab tab;
  final AsyncValue<FeedLoad<FeedPostData>> content;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final VoidCallback onSeePopular;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final following = tab == FeedTab.following;
    final copy = FeedRegionCopy(
      unavailableIcon: switch (tab) {
        FeedTab.following => Icons.group_outlined,
        FeedTab.popular => Icons.whatshot_outlined,
        FeedTab.latest => Icons.schedule_outlined,
      },
      unavailableTitle: switch (tab) {
        FeedTab.following => l10n.homeFollowingUnavailableTitle,
        FeedTab.popular => l10n.homePopularUnavailableTitle,
        FeedTab.latest => l10n.homeNewUnavailableTitle,
      },
      unavailableBody: switch (tab) {
        FeedTab.following => l10n.homeFollowingUnavailableBody,
        FeedTab.popular => l10n.homePopularUnavailableBody,
        FeedTab.latest => l10n.homeNewUnavailableBody,
      },
      emptyIcon: Icons.dynamic_feed_outlined,
      emptyTitle: following
          ? l10n.homeFollowingEmptyTitle
          : l10n.homeEmptyTitle,
      emptyBody: l10n.feedPullToRefresh,
      emptyActionLabel: following ? l10n.feedSeePopular : null,
      onEmptyAction: following ? onSeePopular : null,
      errorTitle: l10n.homeErrorTitle,
    );
    final divider = Divider(
      height: KMetrics.hairline,
      thickness: KMetrics.hairline,
      color: p.border,
    );
    return FeedRegion<FeedPostData>(
      key: PageStorageKey('home.${tab.name}'),
      content: content,
      copy: copy,
      onRefresh: onRefresh,
      onRetry: onRetry,
      loadingSliver: SliverList.separated(
        itemCount: 3,
        itemBuilder: (_, _) => const FeedPostSkeleton(),
        separatorBuilder: (_, _) => divider,
      ),
      itemsSliver: (posts) => SliverList.separated(
        itemCount: posts.length,
        itemBuilder: (_, i) => FeedPostTile(post: posts[i]),
        separatorBuilder: (_, _) => divider,
      ),
    );
  }
}
