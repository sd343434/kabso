import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_room_swipe.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Geometry and colours of the search home (D147), measured on the owner's
/// layout reference at 393 pt (E-DPR 2.3486; spec in the D147 report).
abstract final class KSearchHome {
  /// Search field: starts 46.8 pt in (the reference's scan slot is left
  /// empty: Kabso has no QR feature), 32.8 pt tall, gap 14.9 pt to Cancel,
  /// Cancel 15.8 pt from the end.
  static const double fieldStart = 46.8;
  static const double fieldHeight = 32.8;
  static const double fieldToCancel = 14.9;
  static const double cancelEnd = 15.8;

  /// Magnifier 13.6 pt of ink (the outline icon's box is 16), 12.4 pt in;
  /// the hint 8.1 pt after it.
  static const double searchIcon = 16;
  static const double searchIconStart = 11.4;
  static const double hintGap = 7.1;

  /// Section titles 15.75 pt in.
  static const double titleInset = 15.75;

  /// Hot-search rows: 13.2 pt from both sides, 38 pt tall, 40.8 pt apart;
  /// the rank 13.6 pt in, the term 37 pt in (rank column 23.4 pt); the tag
  /// 8.5 pt from the row's end.
  static const double rowInset = 13.2;
  static const double rowHeight = 38;
  static const double rowGap = 2.8;
  static const double rankStart = 13.6;
  static const double rankWidth = 23.4;
  static const double tagEnd = 8.5;

  /// Hot topics: 2 columns 15.3 pt in, the second 6.6 pt past the middle;
  /// lines 32.4 pt apart. Four on the search home.
  static const double topicInset = 15.3;
  static const double topicColumnGap = 6.6;
  static const double topicHeight = 32.4;
  static const int topicCount = 4;

  /// Live cards: 12.35 pt in, 4.6 pt apart across, 7.2 pt down, 181.8 ×
  /// 200.8 pt.
  static const double cardInset = 12.35;
  static const double cardGap = 4.6;
  static const double cardRowGap = 7.2;
  static const double cardAspect = 181.8 / 200.8;
  static const int liveCount = 6;

  /// The hot-search section shows only with at least this many terms.
  static const int minHotSearches = 3;

  /// The hint rotates through the trending terms this often.
  static const Duration hintPeriod = Duration(seconds: 3);

  /// Ranks 1, 2, 3 (sampled #F35F08, #EF900E, #ECB122); their rows' tints
  /// fade to nothing at the end (sampled #FEF1EC, #FFF8EE, #FFFBF3 over
  /// white).
  static const List<Color> rankColors = [
    Color(0xFFF35F08),
    Color(0xFFEF900E),
    Color(0xFFECB122),
  ];
  static const List<double> rowTintAlpha = [0.09, 0.08, 0.06];

  /// Tags: Trending (#FFF2DB on #EB8A0A) and New (#DAFAF8 on #03D8C3).
  static const Color trendingBg = Color(0xFFFFF2DB);
  static const Color trendingFg = Color(0xFFEB8A0A);
  static const Color newBg = Color(0xFFDAFAF8);
  static const Color newFg = Color(0xFF03D8C3);
}

/// D147: `GET /search/trending` (the same for everyone).
final FutureProvider<List<TrendingSearch>> trendingSearchesProvider =
    FutureProvider.autoDispose((ref) {
      ref.watch(currentUserProvider.select((u) => u?.id));
      return ref.watch(postsRepositoryProvider).trendingSearches();
    });

/// D147: `GET /search/trending-hashtags?limit`.
final FutureProviderFamily<List<Hashtag>, int> trendingHashtagsProvider =
    FutureProvider.autoDispose.family((ref, limit) {
      ref.watch(currentUserProvider.select((u) => u?.id));
      return ref.watch(postsRepositoryProvider).trendingHashtags(limit: limit);
    });

/// D147 "You may like": the first popular lives (`GET /live/rooms?tab=popular`).
final FutureProvider<List<LiveRoomSummary>> searchLivesProvider =
    FutureProvider.autoDispose((ref) async {
      ref.watch(currentUserProvider.select((u) => u?.id));
      final page = await ref
          .watch(liveRepositoryProvider)
          .listRooms(tab: LiveRoomsTab.popular, limit: KSearchHome.liveCount);
      return page.data;
    });

/// The search home under an empty field (D147, owner's layout reference):
/// Hot Searches (`GET /search/trending`, hidden below 3 terms), Hot Take
/// (the hashtags of the week; "More" when there are more than four) and You
/// may like (popular lives). Each section is hidden while it has nothing
/// real to show or fails to load; with nothing at all the prompt shows.
class SearchHome extends ConsumerWidget {
  const new({required this.onSearchTerm, super.key});

  /// Searches a hot term (fills the field and shows the results).
  final ValueChanged<String> onSearchTerm;

  static const hotKey = Key('searchHome.hot');
  static const topicsKey = Key('searchHome.topics');
  static const livesKey = Key('searchHome.lives');
  static const moreKey = Key('searchHome.more');
  static Key hotRowKey(String term) => Key('searchHome.hot.$term');
  static Key topicKey(String tag) => Key('searchHome.topic.$tag');
  static Key liveKey(String id) => Key('searchHome.live.$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hot = ref.watch(trendingSearchesProvider).value ?? const [];
    // One more than shown tells whether "More" leads anywhere.
    final topics =
        ref.watch(trendingHashtagsProvider(KSearchHome.topicCount + 1)).value ??
        const [];
    final lives = ref.watch(searchLivesProvider).value ?? const [];
    final showHot = hot.length >= KSearchHome.minHotSearches;
    return CustomScrollView(
      slivers: [
        if (showHot)
          SliverToBoxAdapter(
            child: _HotSearches(key: hotKey, terms: hot, onTap: onSearchTerm),
          ),
        if (topics.isNotEmpty)
          SliverToBoxAdapter(
            child: _HotTopics(
              key: topicsKey,
              tags: topics.take(KSearchHome.topicCount).toList(),
              hasMore: topics.length > KSearchHome.topicCount,
              topGap: showHot,
            ),
          ),
        if (lives.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionTitle(
              key: livesKey,
              text: context.l10n.searchMayLikeTitle,
              top: showHot || topics.isNotEmpty ? 22.1 : 0,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              KSearchHome.cardInset,
              9.8,
              KSearchHome.cardInset,
              KSpacing.xl,
            ),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: KSearchHome.cardGap,
                mainAxisSpacing: KSearchHome.cardRowGap,
                childAspectRatio: KSearchHome.cardAspect,
              ),
              itemCount: lives.length,
              itemBuilder: (context, i) {
                final room = lives[i];
                return KLiveGridCard(
                  key: liveKey(room.id),
                  room: LiveRoomCardData.fromSummary(room),
                  onTap: () {
                    // D124: swiping inside the room moves through these.
                    ref.read(liveRoomSwipeListProvider.notifier).set([
                      for (final r in lives) (roomId: r.id, hostId: r.host.id),
                    ]);
                    unawaited(context.push<void>(AppRoutes.liveRoom(room.id)));
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// The direction a hashtag reads in: right to left when its first strong
/// letter is Arabic (or another RTL script), else left to right.
TextDirection hashtagDirection(String tag) =>
    Bidi.detectRtlDirectionality(tag) ? TextDirection.rtl : TextDirection.ltr;

/// True when the search home has something to show (or is still loading).
bool searchHomeHasContent(WidgetRef ref) {
  final hot = ref.watch(trendingSearchesProvider);
  final topics = ref.watch(
    trendingHashtagsProvider(KSearchHome.topicCount + 1),
  );
  final lives = ref.watch(searchLivesProvider);
  if (hot.isLoading || topics.isLoading || lives.isLoading) return true;
  return (hot.value?.length ?? 0) >= KSearchHome.minHotSearches ||
      (topics.value?.isNotEmpty ?? false) ||
      (lives.value?.isNotEmpty ?? false);
}

class _SectionTitle extends StatelessWidget {
  const new({
    required this.text,
    required this.top,
    super.key,
    this.trailing,
    this.end,
  });

  final String text;
  final double top;

  /// Right after the title (an icon).
  final Widget? trailing;

  /// At the end of the line ("More").
  final Widget? end;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsetsDirectional.only(
      start: KSearchHome.titleInset,
      end: KSearchHome.cancelEnd,
      top: top,
    ),
    child: Row(
      children: [
        Flexible(
          child: Semantics(
            header: true,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.title.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.2,
                letterSpacing: -0.35,
              ),
            ),
          ),
        ),
        ?trailing,
        if (end case final e?) ...[const Spacer(), e],
      ],
    ),
  );
}

class _HotSearches extends StatelessWidget {
  const new({required this.terms, required this.onTap, super.key});

  final List<TrendingSearch> terms;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SectionTitle(text: context.l10n.searchHotTitle, top: 0),
      const SizedBox(height: 8.6),
      for (final (i, t) in terms.indexed) ...[
        if (i > 0) const SizedBox(height: KSearchHome.rowGap),
        _HotRow(rank: i + 1, term: t, onTap: () => onTap(t.term)),
      ],
    ],
  );
}

class _HotRow extends StatelessWidget {
  const new({required this.rank, required this.term, required this.onTap});

  final int rank;
  final TrendingSearch term;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final t = context.textStyles;
    final top = rank <= KSearchHome.rankColors.length;
    final rankColor = top ? KSearchHome.rankColors[rank - 1] : p.textTertiary;
    final tag = switch (term.tag) {
      TrendingSearchTag.trending => _Tag(
        text: l10n.searchTagTrending,
        bg: KSearchHome.trendingBg,
        fg: KSearchHome.trendingFg,
        flame: true,
      ),
      TrendingSearchTag.newTerm => _Tag(
        text: l10n.searchTagNew,
        bg: KSearchHome.newBg,
        fg: KSearchHome.newFg,
      ),
      null => null,
    };
    final tagLabel = switch (term.tag) {
      TrendingSearchTag.trending => l10n.searchTagTrending,
      TrendingSearchTag.newTerm => l10n.searchTagNew,
      null => null,
    };
    final label = l10n.searchHotSemantics(rank, term.term);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSearchHome.rowInset),
      child: Semantics(
        button: true,
        label: tagLabel == null ? label : '$label, $tagLabel',
        excludeSemantics: true,
        child: SizedBox(
          key: SearchHome.hotRowKey(term.term),
          height: KSearchHome.rowHeight,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(KRadius.xs),
              child: Ink(
                decoration: top
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(KRadius.xs),
                        gradient: LinearGradient(
                          begin: AlignmentDirectional.centerStart,
                          end: AlignmentDirectional.centerEnd,
                          stops: const [0, 0.85],
                          colors: [
                            rankColor.withValues(
                              alpha: KSearchHome.rowTintAlpha[rank - 1],
                            ),
                            rankColor.withValues(alpha: 0),
                          ],
                        ),
                      )
                    : null,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: KSearchHome.rankStart,
                    end: KSearchHome.tagEnd,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: KSearchHome.rankWidth,
                        child: Text(
                          '$rank',
                          maxLines: 1,
                          style: t.body.copyWith(
                            color: rankColor,
                            fontSize: top ? 15 : 11,
                            fontWeight: top ? FontWeight.w800 : FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          term.term,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.body.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (tag != null) ...[
                        const SizedBox(width: KSpacing.sm),
                        tag,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const new({
    required this.text,
    required this.bg,
    required this.fg,
    this.flame = false,
  });

  final String text;
  final Color bg;
  final Color fg;
  final bool flame;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.3,
    child: Container(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 3.5, 6.5, 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (flame) ...[
            Icon(Icons.local_fire_department_rounded, size: 10.5, color: fg),
            const SizedBox(width: 1.5),
          ],
          Text(
            text,
            maxLines: 1,
            style: context.textStyles.caption.copyWith(
              color: fg,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
              height: 1.2,
            ),
          ),
        ],
      ),
    ),
  );
}

class _HotTopics extends StatelessWidget {
  const new({
    required this.tags,
    required this.hasMore,
    required this.topGap,
    super.key,
  });

  final List<Hashtag> tags;
  final bool hasMore;
  final bool topGap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final t = context.textStyles;
    final rows = <List<Hashtag>>[
      for (var i = 0; i < tags.length; i += 2)
        tags.sublist(i, (i + 2).clamp(0, tags.length)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          text: l10n.searchHotTakeTitle,
          top: topGap ? 19.9 : 0,
          end: hasMore
              ? _More(onTap: () => context.push(AppRoutes.trendingHashtags))
              : null,
          trailing: Padding(
            padding: const EdgeInsetsDirectional.only(start: 5),
            child: ExcludeSemantics(
              child: Container(
                width: 17,
                height: 15,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: p.textPrimary, width: 1.4),
                  borderRadius: BorderRadius.circular(KRadius.xs),
                ),
                child: Icon(Icons.tag_rounded, size: 11, color: p.textPrimary),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: KSearchHome.topicInset,
            end: KSearchHome.topicInset,
            top: 6.6,
          ),
          child: Column(
            children: [
              for (final row in rows)
                Row(
                  children: [
                    for (final (i, h) in row.indexed)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: i == 0 ? 0 : KSearchHome.topicColumnGap,
                          ),
                          child: _Topic(tag: h, style: t.body),
                        ),
                      ),
                    if (row.length == 1) const Expanded(child: SizedBox()),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _More extends StatelessWidget {
  const new({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      child: InkWell(
        key: SearchHome.moreKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(KRadius.xs),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 20, minWidth: 48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.searchMore,
                style: context.textStyles.body.copyWith(
                  color: p.textTertiary,
                  fontSize: 14.5,
                  letterSpacing: -0.2,
                  height: 1.2,
                ),
              ),
              const SizedBox(width: 3),
              ExcludeSemantics(
                child: Icon(
                  // Mirrored in Arabic (matchTextDirection).
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: p.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Topic extends StatelessWidget {
  const new({required this.tag, required this.style});

  final Hashtag tag;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      key: SearchHome.topicKey(tag.tag),
      onTap: () => context.push(AppRoutes.hashtag(tag.tag)),
      child: SizedBox(
        height: KSearchHome.topicHeight,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            context.l10n.hashtagLabel(tag.tag),
            // The tag's own direction keeps `#` in front of it (a Latin tag
            // in Arabic reads "#music", not "music#").
            textDirection: hashtagDirection(tag.tag),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(
              fontSize: 15,
              height: 1.2,
              letterSpacing: -0.25,
            ),
          ),
        ),
      ),
    ),
  );
}
