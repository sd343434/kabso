import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/discover/search_home.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D147: the hashtags of the week ("More" on the search home): up to 20
/// from `GET /search/trending-hashtags`, most posts first; a row opens the
/// hashtag page.
class TrendingHashtagsScreen extends ConsumerWidget {
  const new({super.key});

  /// `GET /search/trending-hashtags` serves at most 20.
  static const limit = 20;

  static const emptyKey = Key('trendingHashtags.empty');
  static Key rowKey(String tag) => Key('trendingHashtags.$tag');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final tags = ref.watch(trendingHashtagsProvider(limit));
    return Scaffold(
      appBar: KAppBar(title: Text(l10n.trendingHashtagsTitle)),
      body: switch (tags) {
        AsyncValue(value: final list?) when list.isEmpty => KEmptyState(
          key: emptyKey,
          icon: Icons.tag_rounded,
          title: l10n.trendingHashtagsEmpty,
          message: l10n.searchPromptBody,
        ),
        AsyncValue(value: final list?) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final h = list[i];
            return ListTile(
              key: rowKey(h.tag),
              leading: SizedBox(
                width: KSizes.avatarMd,
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: context.textStyles.bodyStrong.copyWith(
                      color: i < KSearchHome.rankColors.length
                          ? KSearchHome.rankColors[i]
                          : p.textTertiary,
                    ),
                  ),
                ),
              ),
              title: Text(
                l10n.hashtagLabel(h.tag),
                textDirection: hashtagDirection(h.tag),
                textAlign: Directionality.of(context) == TextDirection.rtl
                    ? TextAlign.right
                    : TextAlign.left,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                l10n.trendingHashtagWeekCount(h.postCount),
                style: TextStyle(color: p.textSecondary),
              ),
              onTap: () => context.push(AppRoutes.hashtag(h.tag)),
            );
          },
        ),
        AsyncError(:final error) => FailureErrorState(
          title: l10n.errorTitle,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(trendingHashtagsProvider(limit)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
