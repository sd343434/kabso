import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/families/application/families_providers.dart';
import 'package:kabso_live/features/families/data/families_repository.dart';
import 'package:kabso_live/features/families/domain/family_models.dart';
import 'package:kabso_live/features/families/presentation/bond_widgets.dart';
import 'package:kabso_live/features/families/presentation/family_widgets.dart';
import 'package:kabso_live/features/profile/profile_screen.dart'
    show PostGridLoadMore;
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/families` (CP-018; CP-022, D116; D127: laid out literally after the
/// owner's own mockup, measured at 393 pt). Top to bottom: the header
/// (back on the left, the title centred, on the right Create — or the
/// caller's family — where the mockup has nothing), "Family activities"
/// with the monthly-ranking card (it opens the prestige board; the
/// mockup's promo-video card and "More" are hidden: there is no video),
/// "Families list" with the search, the three board pills (battles greyed
/// "Soon", D62), the podium on its warm backdrop, the ranked rows with
/// Join, and the caller's family pinned at the bottom. As on the mockup
/// the rows run left to right in both directions (rank, emblem, text,
/// Join); the Arabic text itself stays right-to-left. The search matches a
/// name or the 8-digit number (a full number opens that family,
/// `GET /family-numbers/{number}`).
class FamiliesScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const searchKey = Key('families.search');
  static const createKey = Key('families.create');
  static const mineKey = Key('families.mine');
  static const backKey = Key('families.back');
  static const cancelRequestKey = Key('families.cancelRequest');
  static const emptyKey = Key('families.empty');
  static const podiumKey = Key('families.podium');
  static const myRankKey = Key('families.myRank');
  static const battleTabKey = Key('families.tab.battle');
  static const activityMonthlyKey = Key('families.activity.monthly');
  static const listHeaderKey = Key('families.listHeader');

  static Key tileKey(String id) => Key('families.tile.$id');
  static Key podiumSlotKey(int place) => Key('families.podium.$place');
  static Key podiumPlaceKey(int place) => Key('families.podium.$place.place');
  static Key joinKey(String id) => Key('families.join.$id');
  static Key tabKey(FamilyRankingBoard board) =>
      Key('families.tab.${board.name}');

  /// Measured on the owner's mockup at 393 pt (D127).
  static const double headerHeight = 44;
  static const double gutter = 12;
  static const double activityHeight = 95;
  static const double tabHeight = 32;
  static const double searchWidth = 168;
  static const double searchHeight = 30;
  static const double rowHeight = 59;

  @override
  ConsumerState<FamiliesScreen> createState() => _FamiliesScreenState();
}

class _FamiliesScreenState extends ConsumerState<FamiliesScreen> {
  final _search = TextEditingController();
  final GlobalKey _listHeader = GlobalKey();
  Timer? _debounce;
  String _query = '';
  FamilyRankingBoard _board = FamilyRankingBoard.prestige;

  static final RegExp _number = RegExp(r'^\d{8}$');

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  Future<void> _submitted(String value) async {
    final q = value.trim();
    _debounce?.cancel();
    setState(() => _query = q);
    if (!_number.hasMatch(q)) return;
    final l10n = context.l10n;
    try {
      final family = await ref.read(familiesRepositoryProvider).byNumber(q);
      if (mounted) unawaited(context.push(AppRoutes.family(family.id)));
    } on Object catch (e) {
      if (!mounted) return;
      KSnack.error(
        context,
        isErrorCode(e, ErrorCode.notFound)
            ? l10n.familiesNumberNotFound
            : failureMessage(l10n, toAppFailure(e)),
      );
    }
  }

  Future<void> _cancelRequest() async {
    final l10n = context.l10n;
    try {
      await ref.read(familiesRepositoryProvider).cancelMyRequest();
      if (!mounted) return;
      refreshFamilies(ref);
      KSnack.success(context, l10n.familyRequestCancelled);
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
    }
  }

  /// The monthly-ranking card: the prestige board, scrolled into view.
  void _openMonthly() {
    _search.clear();
    _debounce?.cancel();
    setState(() {
      _query = '';
      _board = FamilyRankingBoard.prestige;
    });
    final target = _listHeader.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: KMotion.of(context, KMotion.base),
        curve: KMotion.standard,
      );
    }
  }

  /// The header: back (left), the title (centre) and, where the mockup
  /// has nothing (right), Create — or the caller's family.
  Widget _header(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final mine = ref.watch(myFamilyProvider);
    final canPop = context.canPop();
    final end = switch (mine) {
      AsyncValue(value: final Family family) => Semantics(
        button: true,
        label: l10n.familiesMine,
        excludeSemantics: true,
        child: InkResponse(
          key: FamiliesScreen.mineKey,
          radius: 22,
          onTap: () => context.push(AppRoutes.family(family.id)),
          child: SizedBox.square(
            dimension: 44,
            child: Center(child: FamilyEmblem(url: family.emblemUrl, size: 30)),
          ),
        ),
      ),
      AsyncValue(hasValue: true) => IconButton(
        key: FamiliesScreen.createKey,
        tooltip: l10n.familiesCreate,
        icon: Icon(Icons.add_rounded, size: 28, color: p.textPrimary),
        onPressed: () => context.push(AppRoutes.newFamily),
      ),
      _ => null,
    };
    return SizedBox(
      width: double.infinity,
      height: FamiliesScreen.headerHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Semantics(
              header: true,
              child: Text(
                l10n.familiesTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.headline.copyWith(
                  color: p.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ),
          ),
          if (canPop)
            Positioned(
              left: 4,
              // "<" on the left in both directions (the mockup).
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: IconButton(
                  key: FamiliesScreen.backKey,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 22,
                    color: p.textPrimary,
                  ),
                  onPressed: () => context.pop(),
                ),
              ),
            ),
          if (end != null) Positioned(right: 4, child: end),
        ],
      ),
    );
  }

  List<Widget> _requestSlivers(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final mine = ref.watch(myFamilyProvider);
    final request = ref.watch(myFamilyRequestProvider).value;
    if (request == null || mine.value != null) return const [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            FamiliesScreen.gutter,
            KSpacing.xs,
            FamiliesScreen.gutter,
            0,
          ),
          child: Container(
            padding: const EdgeInsetsDirectional.only(start: KSpacing.md),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(KRadius.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.familyPendingRequest(request.family.name),
                    style: t.body.copyWith(color: p.textPrimary),
                  ),
                ),
                TextButton(
                  key: FamiliesScreen.cancelRequestKey,
                  onPressed: _cancelRequest,
                  child: Text(l10n.familyCancelRequest),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  /// "Family activities" and its card (only the monthly ranking: the
  /// mockup's second card, a promo video, has no video behind it).
  Widget _activities(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                Flexible(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.familiesActivitiesTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.title.copyWith(
                        color: p.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, c) => Row(
              textDirection: TextDirection.ltr,
              children: [
                SizedBox(
                  width: (c.maxWidth - 6) / 2,
                  height: FamiliesScreen.activityHeight,
                  child: _ActivityCard(
                    key: FamiliesScreen.activityMonthlyKey,
                    asset: FamilyArt.activityMonthly,
                    title: l10n.familiesActivityMonthly,
                    onTap: _openMonthly,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "Families list" (left) and the search (right), as on the mockup.
  Widget _listHeaderRow(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final search = SizedBox(
      width: FamiliesScreen.searchWidth,
      height: FamiliesScreen.searchHeight,
      child: TextField(
        key: FamiliesScreen.searchKey,
        controller: _search,
        onChanged: _changed,
        onSubmitted: _submitted,
        textInputAction: TextInputAction.search,
        textAlignVertical: TextAlignVertical.center,
        style: t.label.copyWith(color: p.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: l10n.familiesSearchShort,
          hintStyle: t.label.copyWith(
            color: p.textTertiary,
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: p.textSecondary,
            size: 22,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          isDense: true,
          filled: true,
          fillColor: p.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
          border: _pillBorder,
          enabledBorder: _pillBorder,
          focusedBorder: _pillBorder,
        ),
      ),
    );
    return Padding(
      key: _listHeader,
      padding: const EdgeInsets.fromLTRB(
        FamiliesScreen.gutter,
        19,
        FamiliesScreen.gutter,
        9,
      ),
      child: Row(
        key: FamiliesScreen.listHeaderKey,
        textDirection: TextDirection.ltr,
        children: [
          Expanded(
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                Flexible(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.familiesListTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.title.copyWith(
                        color: p.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          Flexible(child: search),
        ],
      ),
    );
  }

  Widget _tabs(BuildContext context) {
    final l10n = context.l10n;
    Widget tab(
      FamilyRankingBoard? board,
      String label,
      Widget Function(Color) icon, {
      Key? key,
    }) => Expanded(
      child: _BoardTab(
        key: key ?? (board == null ? null : FamiliesScreen.tabKey(board)),
        label: label,
        icon: icon,
        selected: board == _board,
        onTap: board == null ? null : () => setState(() => _board = board),
      ),
    );
    // Left to right in both directions, as on the mockup.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          tab(
            FamilyRankingBoard.prestige,
            l10n.familiesTabPrestige,
            (c) => AppIcon(AppIcons.crownFilled, size: 17, color: c),
          ),
          const SizedBox(width: 10),
          // Owner D116: no family battles exist yet — labelled "Soon",
          // greyed and not a button (D62 convention).
          tab(
            null,
            l10n.familiesTabBattle,
            (c) => Icon(Icons.sports_martial_arts_rounded, size: 17, color: c),
            key: FamiliesScreen.battleTabKey,
          ),
          const SizedBox(width: 10),
          tab(
            FamilyRankingBoard.active,
            l10n.familiesTabActive,
            (c) => Icon(Icons.bar_chart_rounded, size: 17, color: c),
          ),
        ],
      ),
    );
  }

  List<Widget> _boardSlivers(BuildContext context) {
    final l10n = context.l10n;
    final board = _board;
    final load = ref.watch(familyRankingsProvider(board));
    final notifier = ref.read(familyRankingsProvider(board).notifier);
    return switch (load) {
      AsyncValue(:final value?) when value.items.isEmpty => [
        SliverToBoxAdapter(
          child: Padding(
            key: FamiliesScreen.emptyKey,
            padding: const EdgeInsets.symmetric(vertical: KSpacing.xl),
            child: KEmptyState(
              icon: Icons.groups_2_outlined,
              title: l10n.familiesBoardEmpty,
              message: board == FamilyRankingBoard.prestige
                  ? l10n.familiesBoardEmptyPrestige
                  : l10n.familiesBoardEmptyActive,
              compact: true,
            ),
          ),
        ),
      ],
      AsyncValue(:final value?) => [
        SliverToBoxAdapter(
          child: _Podium(
            key: FamiliesScreen.podiumKey,
            board: board,
            top: value.items.take(3).toList(),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: KSpacing.xs)),
        SliverList.builder(
          itemCount:
              (value.items.length > 3 ? value.items.length - 3 : 0) +
              (value.hasMore ? 1 : 0),
          itemBuilder: (context, i) {
            final j = i + 3;
            if (j < value.items.length) {
              final e = value.items[j];
              return FamilyBoardRow(
                key: FamiliesScreen.tileKey(e.family.id),
                family: e.family,
                rank: e.rank,
                scoreLabel: _scoreLabel(context, board),
                scoreValue: familyCount(context, e.score),
              );
            }
            return value.loadMoreError == null
                ? PostGridLoadMore(
                    key: ValueKey(value.items.length),
                    onVisible: () => unawaited(notifier.loadMore()),
                  )
                : Center(
                    child: TextButton(
                      onPressed: () => unawaited(notifier.loadMore()),
                      child: Text(l10n.actionRetry),
                    ),
                  );
          },
        ),
      ],
      AsyncValue(:final error?, isLoading: false) => [
        SliverToBoxAdapter(
          child: FailureErrorState(
            title: l10n.familiesLoadError,
            failure: toAppFailure(error),
            onRetry: () => ref.invalidate(familyRankingsProvider(board)),
            compact: true,
          ),
        ),
      ],
      _ => [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(KSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    };
  }

  List<Widget> _searchSlivers(BuildContext context) {
    final l10n = context.l10n;
    final list = ref.watch(familySearchProvider(_query));
    final notifier = ref.read(familySearchProvider(_query).notifier);
    return switch (list) {
      AsyncValue(:final value?) when value.items.isEmpty => [
        SliverToBoxAdapter(
          child: Padding(
            key: FamiliesScreen.emptyKey,
            padding: const EdgeInsets.symmetric(vertical: KSpacing.xl),
            child: KEmptyState(
              icon: Icons.groups_2_outlined,
              title: l10n.familiesNoMatch,
              message: l10n.familiesNoMatchBody,
              compact: true,
            ),
          ),
        ),
      ],
      AsyncValue(:final value?) => [
        SliverList.builder(
          itemCount: value.items.length + (value.hasMore ? 1 : 0),
          itemBuilder: (context, i) {
            if (i < value.items.length) {
              final f = value.items[i];
              return FamilyBoardRow(
                key: FamiliesScreen.tileKey(f.id),
                family: f,
                scoreLabel: l10n.familyNumber('${f.number}'),
              );
            }
            return value.loadMoreError == null
                ? PostGridLoadMore(
                    key: ValueKey(value.items.length),
                    onVisible: () => unawaited(notifier.loadMore()),
                  )
                : Center(
                    child: TextButton(
                      onPressed: () => unawaited(notifier.loadMore()),
                      child: Text(l10n.actionRetry),
                    ),
                  );
          },
        ),
      ],
      AsyncValue(:final error?, isLoading: false) => [
        SliverToBoxAdapter(
          child: FailureErrorState(
            title: l10n.familiesLoadError,
            failure: toAppFailure(error),
            onRetry: () => ref.invalidate(familySearchProvider(_query)),
            compact: true,
          ),
        ),
      ],
      _ => [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(KSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final searching = _query.isNotEmpty;
    final boardLoad = ref.watch(familyRankingsProvider(_board));
    final me = boardLoad.hasValue
        ? ref.read(familyRankingsProvider(_board).notifier).me
        : null;
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  refreshFamilies(ref);
                  await (searching
                      ? ref.read(familySearchProvider(_query).future)
                      : ref.read(familyRankingsProvider(_board).future));
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    ..._requestSlivers(context),
                    SliverToBoxAdapter(child: _activities(context)),
                    SliverToBoxAdapter(child: _listHeaderRow(context)),
                    if (searching)
                      ..._searchSlivers(context)
                    else ...[
                      SliverToBoxAdapter(child: _tabs(context)),
                      const SliverToBoxAdapter(child: SizedBox(height: 7)),
                      ..._boardSlivers(context),
                    ],
                    const SliverToBoxAdapter(
                      child: SizedBox(height: KSpacing.xl),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: searching || me == null
          ? null
          : _MyRankBar(board: _board, me: me),
    );
  }
}

const _pillBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(KRadius.pill)),
  borderSide: BorderSide.none,
);

/// The label before a row's score.
String _scoreLabel(BuildContext context, FamilyRankingBoard board) =>
    board == FamilyRankingBoard.prestige
    ? context.l10n.familiesMonthPointsLabel
    : context.l10n.familiesActiveLabel;

/// What the pinned bar says under the name.
String _scoreLine(BuildContext context, FamilyRankingBoard board, int score) {
  final l10n = context.l10n;
  return board == FamilyRankingBoard.prestige
      ? l10n.familiesScoreMonth(familyCount(context, score))
      : l10n.familiesScoreActive(familyCount(context, score));
}

/// An activity card: the owner's art with its title over it, white, in two
/// centred lines (D127, the mockup's card 1).
class _ActivityCard extends StatelessWidget {
  const new({
    required this.asset,
    required this.title,
    required this.onTap,
    super.key,
  });

  final String asset;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return Semantics(
      button: true,
      label: title.replaceAll('\n', ' '),
      excludeSemantics: true,
      child: Material(
        color: const Color(0xFF3B0D12),
        borderRadius: BorderRadius.circular(KRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(asset, fit: BoxFit.cover, excludeFromSemantics: true),
              const DecoratedBox(
                decoration: BoxDecoration(color: Color(0x40000000)),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: KMetrics.overlayMaxTextScale,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: t.title.copyWith(
                          color: const Color(0xFFFFFFFF),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                          shadows: const [
                            Shadow(color: Color(0xCC000000), blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One board pill: gold when selected; without [onTap], greyed "Soon".
/// The icon sits left of the label in both directions (the mockup).
class _BoardTab extends StatelessWidget {
  const new({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final Widget Function(Color) icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final soon = onTap == null;
    final fg = selected
        ? const Color(0xFFFFFFFF)
        : soon
        ? p.textTertiary
        : p.textPrimary;
    final pill = Container(
      constraints: const BoxConstraints(minHeight: FamiliesScreen.tabHeight),
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.xs),
      decoration: BoxDecoration(
        gradient: selected ? FamilyColors.buttonGradient : null,
        color: selected ? null : p.surface,
        borderRadius: BorderRadius.circular(KRadius.pill),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x40D98E28),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Row(
        textDirection: TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon(fg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.label.copyWith(
                color: fg,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
    if (soon) {
      return Semantics(
        label: context.l10n.familiesSoonLabel(label),
        excludeSemantics: true,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            pill,
            const Positioned(top: -8, right: 2, child: FamilySoonBadge()),
          ],
        ),
      );
    }
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: pill,
      ),
    );
  }
}

/// The top three on the owner's podium cards (D125) inside the mockup's
/// warm backdrop (D127): second on the left, first in the centre (larger),
/// third on the right, in both directions; the cards stand on one line.
class _Podium extends StatelessWidget {
  const new({required this.board, required this.top, super.key});

  final FamilyRankingBoard board;
  final List<FamilyRankingEntry> top;

  /// Of the backdrop's width (measured at 393: the backdrop 373 wide). The
  /// mockup's cards are 129 and 98 wide; the owner's art needs 158 and 136
  /// for its panels to hold three readable lines (CTO minimums, D125). The
  /// side cards' centres are 120 from the middle, under the first's wings.
  static const double firstShare = 158 / 373;
  static const double sideShare = 136 / 373;
  static const double sideOffset = 120 / 373;

  /// The backdrop's padding above the first card (its crown has its own
  /// clear margin) and below the cards: the backdrop stays 215 pt tall as
  /// measured.
  static const double topInset = 0;
  static const double bottomInset = 4;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    FamilyRankingEntry? at(int place) =>
        top.length >= place ? top[place - 1] : null;
    // Text over the art is capped like other overlays.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: KMetrics.overlayMaxTextScale,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final w1 = w * firstShare;
            final ws = w * sideShare;
            double height(int place, double width) {
              final art = FamilyArt.podiumCards[place - 1].size;
              return width * art.height / art.width;
            }

            Widget slot(int place, double width) => SizedBox(
              width: width,
              height: height(place, width),
              child: _PodiumCard(
                key: FamiliesScreen.podiumSlotKey(place),
                place: place,
                entry: at(place),
                board: board,
              ),
            );
            final h1 = height(1, w1);
            return Container(
              height: topInset + h1 + bottomInset,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(KRadius.md + 2),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: dark
                      ? FamilyColors.podiumBackdropDark
                      : FamilyColors.podiumBackdropLight,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: w / 2 - w * sideOffset - ws / 2,
                    bottom: bottomInset,
                    child: slot(2, ws),
                  ),
                  Positioned(
                    left: w / 2 + w * sideOffset - ws / 2,
                    bottom: bottomInset,
                    child: slot(3, ws),
                  ),
                  Positioned(
                    left: (w - w1) / 2,
                    bottom: bottomInset,
                    child: slot(1, w1),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One of the owner's podium cards: the emblem in its circle with the place
/// badge on the circle's lower edge; the name, level and points in its
/// panel; Join on the panel's lower edge. A tap opens the family.
class _PodiumCard extends StatelessWidget {
  const new({
    required this.place,
    required this.entry,
    required this.board,
    super.key,
  });

  final int place;
  final FamilyRankingEntry? entry;
  final FamilyRankingBoard board;

  /// Minimum sizes (CTO review, D125): the text is cut with an ellipsis to
  /// the panel's width, never scaled below these at text scale 1.
  static const double nameSize = 13;
  static const double lineSize = 11;
  static const double placeSize = 14;
  static const double joinSize = 28;
  static const double placeBadge = 24;

  /// How much of Join overlaps the panel (the rest covers its frame).
  static const double joinInside = 10;

  /// The place badge colours (red-gold, silver-blue, rose gold).
  static const List<(Color, Color)> placeColors = [
    (Color(0xFFFFD86B), Color(0xFF9A1B12)),
    (Color(0xFFE4ECFF), Color(0xFF1E46A8)),
    (Color(0xFFFFD2B5), Color(0xFF9A4A2A)),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final entry = this.entry;
    final art = FamilyArt.podiumCards[place - 1];
    const white = Color(0xFFFFFFFF);
    final (badgeFg, badgeBg) = placeColors[place - 1];
    return LayoutBuilder(
      builder: (context, c) {
        final drawn = Offset.zero & c.biggest;
        final circle = art.circleIn(drawn);
        final panel = art.map(art.panel, drawn);
        // Join sits on the panel's lower edge, [joinInside] of it inside;
        // the text keeps above it.
        final textArea = Rect.fromLTRB(
          panel.left,
          panel.top,
          panel.right,
          panel.bottom - (entry == null ? 0 : joinInside),
        );
        Text line(String text, double size, {bool bold = false}) => Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: t.caption.copyWith(
            color: bold ? white : const Color(0xF2FFFFFF),
            fontSize: size,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            height: size == nameSize ? 1.15 : 1.0,
            shadows: const [Shadow(color: Color(0x99000000), blurRadius: 3)],
          ),
        );
        final lines = SizedBox(
          width: textArea.width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              line(entry?.family.name ?? '—', nameSize, bold: true),
              if (entry != null) ...[
                line(l10n.familyLevelLong(entry.family.level), lineSize),
                Row(
                  textDirection: TextDirection.ltr,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      board == FamilyRankingBoard.prestige
                          ? Icons.local_fire_department_rounded
                          : Icons.people_alt_rounded,
                      size: lineSize + 2,
                      color: const Color(0xFFFFD86B),
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: line(
                        familyCount(context, entry.score),
                        lineSize,
                        bold: true,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
        final card = Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Image.asset(
                art.asset,
                fit: BoxFit.fill,
                excludeFromSemantics: true,
              ),
            ),
            Positioned.fromRect(
              rect: circle,
              child: entry == null
                  ? const SizedBox.shrink()
                  : FamilyEmblem(
                      url: entry.family.emblemUrl,
                      size: circle.width,
                    ),
            ),
            // The place on the circle's lower edge, like a medal.
            Positioned(
              left: circle.center.dx - placeBadge / 2,
              top: circle.bottom - placeBadge / 2 - 2,
              width: placeBadge,
              height: placeBadge,
              child: Container(
                key: FamiliesScreen.podiumPlaceKey(place),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badgeBg,
                  border: Border.all(color: badgeFg, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66000000), blurRadius: 4),
                  ],
                ),
                child: FittedBox(
                  child: Text(
                    '$place',
                    style: t.label.copyWith(
                      color: badgeFg,
                      fontSize: placeSize,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
            // Fits at text scale 1; larger scales shrink it back towards
            // the minimums instead of overflowing the panel.
            Positioned.fromRect(
              rect: textArea,
              child: FittedBox(fit: BoxFit.scaleDown, child: lines),
            ),
            if (entry != null)
              Positioned(
                left: panel.center.dx - joinSize / 2,
                top: panel.bottom - joinInside,
                width: joinSize,
                height: joinSize,
                child: FittedBox(
                  child: FamilyJoinButton(family: entry.family, compact: true),
                ),
              ),
          ],
        );
        return Semantics(
          container: true,
          label: entry == null
              ? null
              : l10n.familiesPodiumLabel(place, entry.family.name),
          child: entry == null
              ? card
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.push(AppRoutes.family(entry.family.id)),
                  child: card,
                ),
        );
      },
    );
  }
}

/// One family in a list (D127, the owner's mockup, left to right in both
/// directions): the place, the emblem in its gold hexagon, the name with
/// the level, "Members: n/cap", the [scoreLabel] with [scoreValue], and
/// Join on the right.
class FamilyBoardRow extends StatelessWidget {
  const new({
    required this.family,
    required this.scoreLabel,
    super.key,
    this.scoreValue,
    this.rank,
  });

  final FamilyCard family;
  final String scoreLabel;
  final String? scoreValue;
  final int? rank;

  static const double joinWidth = 84;
  static const double joinHeight = 31;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final rank = this.rank;
    final scoreValue = this.scoreValue;
    final grey = p.textTertiary;
    final levelColor = dark
        ? FamilyColors.levelRedOnDark
        : FamilyColors.levelRed;
    return InkWell(
      onTap: () => context.push(AppRoutes.family(family.id)),
      child: Container(
        constraints: const BoxConstraints(minHeight: FamiliesScreen.rowHeight),
        margin: const EdgeInsets.symmetric(horizontal: FamiliesScreen.gutter),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          textDirection: TextDirection.ltr,
          children: [
            SizedBox(
              width: 18,
              child: rank == null
                  ? null
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$rank',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: t.title.copyWith(
                          color: p.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 5),
            FamilyHexEmblem(url: family.emblemUrl),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                textDirection: TextDirection.ltr,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    textDirection: TextDirection.ltr,
                    children: [
                      Flexible(
                        child: Text(
                          family.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyStrong.copyWith(
                            color: p.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: KSpacing.sm),
                      AppIcon(
                        AppIcons.crownFilled,
                        size: 14,
                        color: levelColor,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          l10n.familyLevelLong(family.level),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.label.copyWith(
                            color: levelColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    l10n.familiesRowMembers(
                      family.memberCount,
                      family.capacity,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.label.copyWith(
                      color: grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                    ),
                  ),
                  Row(
                    textDirection: TextDirection.ltr,
                    children: [
                      Flexible(
                        child: Text(
                          scoreLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.copyWith(
                            color: grey,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ),
                      if (scoreValue != null) ...[
                        const SizedBox(width: KSpacing.xs),
                        Flexible(
                          child: Text(
                            scoreValue,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.body.copyWith(
                              color: grey,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: KSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: joinWidth,
                maxWidth: 112,
              ),
              child: FamilyJoinButton(family: family),
            ),
            const SizedBox(width: 3),
          ],
        ),
      ),
    );
  }
}

/// Join from a list (`POST …/join-requests`): only for someone without a
/// family; "Requested" while the caller's request to it waits; nothing for
/// a member of any family. [compact] is the podium's round "+".
class FamilyJoinButton extends ConsumerStatefulWidget {
  const new({required this.family, super.key, this.compact = false});

  final FamilyCard family;
  final bool compact;

  @override
  ConsumerState<FamilyJoinButton> createState() => _FamilyJoinButtonState();
}

class _FamilyJoinButtonState extends ConsumerState<FamilyJoinButton> {
  bool _busy = false;

  Future<void> _join() async {
    if (_busy) return;
    final l10n = context.l10n;
    final repo = ref.read(familiesRepositoryProvider);
    setState(() => _busy = true);
    try {
      try {
        await repo.requestToJoin(widget.family.id);
      } on Object catch (e) {
        if (!isErrorCode(e, ErrorCode.familyRequestPending) || !mounted) {
          rethrow;
        }
        // One pending request at a time: offer to cancel the other one.
        final cancel = await confirmBond(
          context,
          title: l10n.errorFamilyRequestPending,
          confirm: l10n.familyCancelRequest,
        );
        if (!cancel || !mounted) return;
        await repo.cancelMyRequest();
        await repo.requestToJoin(widget.family.id);
      }
      if (!mounted) return;
      refreshFamilies(ref, familyId: widget.family.id);
      KSnack.success(context, l10n.familyJoinSent);
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mine = ref.watch(myFamilyProvider);
    final request = ref.watch(myFamilyRequestProvider).value;
    // Unknown yet, or already in a family: no button.
    if (!mine.hasValue || mine.value != null) return const SizedBox.shrink();
    final family = widget.family;
    final requested = request?.family.id == family.id;
    final full = family.memberCount >= family.capacity;
    final onPressed = requested || full ? null : _join;
    if (widget.compact) {
      return Semantics(
        button: true,
        enabled: onPressed != null,
        label: requested
            ? l10n.familyRequested
            : l10n.familyJoinNamed(family.name),
        excludeSemantics: true,
        child: InkResponse(
          key: FamiliesScreen.joinKey(family.id),
          onTap: onPressed,
          radius: 24,
          child: Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xF2FFFFFF),
              boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 6)],
            ),
            child: _busy
                ? const Padding(
                    padding: EdgeInsets.all(9),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    requested ? Icons.hourglass_top_rounded : Icons.add_rounded,
                    color: FamilyColors.podium[0].$1,
                    size: 22,
                  ),
          ),
        ),
      );
    }
    return FamilyGoldButton(
      key: FamiliesScreen.joinKey(family.id),
      label: requested
          ? l10n.familyRequested
          : full
          ? l10n.familyFullLabel
          : l10n.familyJoinShort,
      icon: requested || full ? null : Icons.add_rounded,
      height: FamilyBoardRow.joinHeight,
      fontSize: 13.5,
      iconSize: 16,
      horizontalPadding: KSpacing.sm,
      busy: _busy,
      onPressed: onPressed,
    );
  }
}

/// The caller's family on the board, pinned at the bottom.
class _MyRankBar extends StatelessWidget {
  const new({required this.board, required this.me});

  final FamilyRankingBoard board;
  final FamilyRankingMe me;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final rank = me.rank;
    return SafeArea(
      top: false,
      child: Material(
        color: p.background,
        elevation: 8,
        child: InkWell(
          key: FamiliesScreen.myRankKey,
          onTap: () => context.push(AppRoutes.family(me.family.id)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FamiliesScreen.gutter,
              vertical: KSpacing.sm,
            ),
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    rank == null ? '—' : '$rank',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: t.title.copyWith(color: FamilyColors.goldDeep),
                  ),
                ),
                const SizedBox(width: KSpacing.xs),
                FamilyHexEmblem(url: me.family.emblemUrl, width: 38),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: Column(
                    textDirection: TextDirection.ltr,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        me.family.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyStrong.copyWith(color: p.textPrimary),
                      ),
                      Text(
                        rank == null
                            ? l10n.familiesMyRankNone
                            : _scoreLine(context, board, me.score),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption.copyWith(color: p.textTertiary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A family's level on a gold pill.
class FamilyLevelChip extends StatelessWidget {
  const new({required this.level, super.key});

  final int level;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm, vertical: 2),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(KRadius.pill),
      gradient: const LinearGradient(
        colors: [Color(0xFFF2B84B), Color(0xFFD9922E)],
      ),
    ),
    child: Text(
      context.l10n.familyLevel(level),
      style: context.textStyles.caption.copyWith(
        color: const Color(0xFFFFFFFF),
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
