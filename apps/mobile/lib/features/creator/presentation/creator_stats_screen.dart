import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/creator/data/creator_repository.dart';
import 'package:kabso_live/features/wallet/presentation/me_page_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/creator/stats` «بيانات البث» — D164's detailed creator statistics
/// (D172 moved them under the Creator Center hub, which opens them from its
/// stats card, «بيانات البث ›» and «نمو المتابعين»): the person's own
/// followers, posts, reels and lives over 7 days, 30 days or all time
/// (`GET /me/creator-stats`) — stored data only, with an honest empty line
/// for a section with nothing in the period.
class CreatorStatsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static Key periodKey(CreatorStatsPeriod p) => Key('creator.period.${p.name}');
  static Key statKey(String section, String id) => Key('creator.$section.$id');

  /// D164's switch (THIS_MONTH is the hub's card, D172).
  static const List<CreatorStatsPeriod> periods = [
    CreatorStatsPeriod.last7Days,
    CreatorStatsPeriod.last30Days,
    CreatorStatsPeriod.allTime,
  ];

  static const openProfileKey = Key('creator.openProfile');
  static const noPostsKey = Key('creator.posts.none');
  static const noReelsKey = Key('creator.reels.none');
  static const noLivesKey = Key('creator.live.none');

  @override
  ConsumerState<CreatorStatsScreen> createState() => _CreatorStatsScreenState();
}

class _CreatorStatsScreenState extends ConsumerState<CreatorStatsScreen> {
  CreatorStatsPeriod _period = CreatorStatsPeriod.last7Days;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = creatorStatsProvider(_period);
    final load = ref.watch(provider);

    Future<void> refresh() async {
      ref.invalidate(provider);
      try {
        await ref.read(provider.future);
      } on Object {
        // The page shows the failure with a retry.
      }
    }

    final labels = {
      CreatorStatsPeriod.last7Days: l10n.creatorPeriod7,
      CreatorStatsPeriod.last30Days: l10n.creatorPeriod30,
      CreatorStatsPeriod.allTime: l10n.creatorPeriodAll,
    };

    final body = switch (load) {
      AsyncValue(:final value?) => _Sections(stats: value),
      AsyncValue(:final error?, isLoading: false) => FailureErrorState(
        title: l10n.creatorLoadError,
        failure: toAppFailure(error),
        onRetry: () => ref.invalidate(provider),
        compact: true,
      ),
      _ => const Padding(
        padding: EdgeInsets.all(KSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
    };

    return MePage(
      title: l10n.creatorLiveData,
      onRefresh: refresh,
      children: [
        Wrap(
          spacing: KSpacing.sm,
          children: [
            for (final p in CreatorStatsScreen.periods)
              KChip(
                key: CreatorStatsScreen.periodKey(p),
                label: labels[p]!,
                selected: p == _period,
                onSelected: () => setState(() => _period = p),
              ),
          ],
        ),
        body,
        const SizedBox(height: KSpacing.lg),
        KButton(
          key: CreatorStatsScreen.openProfileKey,
          label: l10n.creatorOpenProfile,
          icon: Icons.grid_view_rounded,
          variant: KButtonVariant.secondary,
          onPressed: () => unawaited(context.push(AppRoutes.myProfile)),
        ),
      ],
    );
  }
}

class _Sections extends StatelessWidget {
  const new({required this.stats});

  final CreatorStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    String n(int v) => KFormat.grouped(v);
    Key k(String section, String id) => CreatorStatsScreen.statKey(section, id);

    Widget empty(Key key, String text) => Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
      child: Text(text, style: t.body.copyWith(color: p.textSecondary)),
    );

    List<Widget> content(
      String section,
      String title,
      CreatorContentStats c,
      Key emptyKey,
    ) => [
      MeSectionTitle(title, hint: l10n.creatorContentHint),
      if (c.published == 0)
        empty(emptyKey, l10n.creatorNoPosts)
      else
        MeStatGrid(
          stats: [
            (k(section, 'published'), l10n.creatorPublished, n(c.published)),
            (k(section, 'views'), l10n.creatorViews, n(c.views)),
            (k(section, 'likes'), l10n.creatorLikes, n(c.likes)),
            (k(section, 'comments'), l10n.creatorComments, n(c.comments)),
            (k(section, 'shares'), l10n.creatorShares, n(c.shares)),
          ],
        ),
    ];

    final live = stats.live;
    final followersNew = stats.followersNew;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MeSectionTitle(l10n.creatorFollowers),
        MeStatGrid(
          columns: 2,
          stats: [
            (
              k('followers', 'total'),
              l10n.creatorFollowersTotal,
              n(stats.followersTotal),
            ),
            if (followersNew != null)
              (
                k('followers', 'new'),
                l10n.creatorFollowersNew,
                n(followersNew),
              ),
          ],
        ),
        ...content(
          'posts',
          l10n.creatorPosts,
          stats.posts,
          CreatorStatsScreen.noPostsKey,
        ),
        ...content(
          'reels',
          l10n.creatorReels,
          stats.reels,
          CreatorStatsScreen.noReelsKey,
        ),
        MeSectionTitle(l10n.creatorLive, hint: l10n.creatorLiveHint),
        if (live.lives == 0)
          empty(CreatorStatsScreen.noLivesKey, l10n.creatorNoLives)
        else
          MeStatGrid(
            stats: [
              (k('live', 'lives'), l10n.liveDataLives, n(live.lives)),
              (
                k('live', 'time'),
                l10n.liveDataLiveTime,
                l10n.liveDataDuration(
                  live.liveSeconds ~/ 3600,
                  (live.liveSeconds % 3600) ~/ 60,
                ),
              ),
              (k('live', 'gifts'), l10n.liveStatsGiftCoins, n(live.giftCoins)),
              (
                k('live', 'earnings'),
                l10n.liveStatsEarnings,
                n(live.earningsCoins),
              ),
              (
                k('live', 'followers'),
                l10n.liveDataNewFollowers,
                n(live.newFollowers),
              ),
              (k('live', 'peak'), l10n.creatorPeakViewers, n(live.peakViewers)),
            ],
          ),
      ],
    );
  }
}
