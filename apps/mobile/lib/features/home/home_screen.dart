import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/app/shell/feed_region.dart';
import 'package:kabso_live/app/shell/feed_tabs_scaffold.dart';
import 'package:kabso_live/app/shell/shell_navigation.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/home` — the social feed (D36): Following · Popular · New (default
/// Popular); no wordmark, no title (VG-05/22), no search until search
/// exists (KL-047). Until the posts API exists every tab shows its own
/// honest unavailable state, with a real way forward: "Watch live streams"
/// opens the Live tab on the same segment (D39: no posts are invented and no
/// live grid is shown here).
class HomeScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => FeedTabsScaffold(
    pageBuilder: (context, tab, selectTab) =>
        _HomeFeedPage(tab: tab, onSelectTab: selectTab),
  );
}

class _HomeFeedPage extends ConsumerWidget {
  const new({required this.tab, required this.onSelectTab});

  final FeedTab tab;
  final ValueChanged<FeedTab> onSelectTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = homeFeedProvider(tab);
    return HomeFeedBody(
      tab: tab,
      content: ref.watch(provider),
      onRefresh: () => ref.refresh(provider.future),
      onRetry: () => ref.invalidate(provider),
      onSelectTab: onSelectTab,
      onWatchLive: (tab) => openLiveHub(context, ref, tab),
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
    required this.onSelectTab,
    required this.onWatchLive,
    super.key,
  });

  final FeedTab tab;
  final AsyncValue<FeedLoad<FeedPostData>> content;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;

  /// Switches this screen's header to another tab ("See popular").
  final ValueChanged<FeedTab> onSelectTab;

  /// Opens the Live tab on the given segment ("Watch live streams").
  final ValueChanged<FeedTab> onWatchLive;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final following = tab == FeedTab.following;
    final watchLive = following ? l10n.homeSeeWhoIsLive : l10n.homeWatchLive;
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
      unavailableActionLabel: watchLive,
      unavailableActionIcon: Icons.sensors_rounded,
      onUnavailableAction: () => onWatchLive(tab),
      emptyIcon: Icons.dynamic_feed_outlined,
      emptyTitle: following
          ? l10n.homeFollowingEmptyTitle
          : l10n.homeEmptyTitle,
      emptyBody: l10n.feedPullToRefresh,
      emptyActionLabel: following ? l10n.feedSeePopular : l10n.homeWatchLive,
      emptyActionIcon: following ? null : Icons.sensors_rounded,
      onEmptyAction: following
          ? () => onSelectTab(FeedTab.popular)
          : () => onWatchLive(tab),
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
