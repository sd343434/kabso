import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
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

/// `/families` (CP-018; redesigned for CP-022, D116, after the owner's style
/// board): the caller's family (or Create), then "Families list" with the
/// search, the boards — هيبة العائلة (points this month) and الأكثر نشاطاً
/// (members active this week); ترتيب القتال is shown as "Soon" (no family
/// battles exist) — as a podium of the top 3 and ranked rows with Join,
/// and the caller's family's place pinned at the bottom. The style board's
/// "family activities" banners are not shown: nothing real backs them yet.
/// The search matches a name or the 8-digit number (a full number opens
/// that family, `GET /family-numbers/{number}`).
class FamiliesScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const searchKey = Key('families.search');
  static const createKey = Key('families.create');
  static const mineKey = Key('families.mine');
  static const cancelRequestKey = Key('families.cancelRequest');
  static const emptyKey = Key('families.empty');
  static const podiumKey = Key('families.podium');
  static const myRankKey = Key('families.myRank');
  static const battleTabKey = Key('families.tab.battle');

  static Key tileKey(String id) => Key('families.tile.$id');
  static Key podiumSlotKey(int place) => Key('families.podium.$place');
  static Key joinKey(String id) => Key('families.join.$id');
  static Key tabKey(FamilyRankingBoard board) =>
      Key('families.tab.${board.name}');

  @override
  ConsumerState<FamiliesScreen> createState() => _FamiliesScreenState();
}

class _FamiliesScreenState extends ConsumerState<FamiliesScreen> {
  final _search = TextEditingController();
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

  List<Widget> _mineSlivers(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final mine = ref.watch(myFamilyProvider);
    final request = ref.watch(myFamilyRequestProvider).value;
    return [
      SliverToBoxAdapter(
        child: switch (mine) {
          AsyncValue(value: final Family family) => Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.sm,
              KSpacing.lg,
              0,
            ),
            child: Material(
              color: p.surface,
              borderRadius: BorderRadius.circular(KRadius.lg),
              child: InkWell(
                key: FamiliesScreen.mineKey,
                borderRadius: BorderRadius.circular(KRadius.lg),
                onTap: () => context.push(AppRoutes.family(family.id)),
                child: Container(
                  padding: const EdgeInsets.all(KSpacing.sm),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(KRadius.lg),
                    border: Border.all(color: p.border),
                  ),
                  child: Row(
                    children: [
                      FamilyEmblem(url: family.emblemUrl, size: 40),
                      const SizedBox(width: KSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.familiesMine,
                              style: t.caption.copyWith(color: p.textSecondary),
                            ),
                            Text(
                              family.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodyStrong.copyWith(
                                color: p.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FamilyLevelChip(level: family.level),
                      Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                        color: p.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AsyncValue(hasValue: true) => Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.sm,
              KSpacing.lg,
              0,
            ),
            child: KButton(
              key: FamiliesScreen.createKey,
              label: l10n.familiesCreate,
              icon: Icons.add_rounded,
              variant: KButtonVariant.secondary,
              onPressed: () => context.push(AppRoutes.newFamily),
            ),
          ),
          _ => const SizedBox.shrink(),
        },
      ),
      if (request != null && mine.value == null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.sm,
              KSpacing.lg,
              0,
            ),
            child: Container(
              padding: const EdgeInsetsDirectional.only(start: KSpacing.md),
              decoration: BoxDecoration(
                color: p.surfaceRaised,
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

  Widget _listHeader(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.lg,
        KSpacing.lg,
        KSpacing.sm,
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        runSpacing: KSpacing.sm,
        spacing: KSpacing.md,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.familiesListTitle,
              style: t.title.copyWith(
                color: p.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 210, minWidth: 150),
            child: SizedBox(
              height: 40,
              child: TextField(
                key: FamiliesScreen.searchKey,
                controller: _search,
                onChanged: _changed,
                onSubmitted: _submitted,
                textInputAction: TextInputAction.search,
                style: t.body.copyWith(color: p.textPrimary),
                decoration: InputDecoration(
                  hintText: l10n.familiesSearchShort,
                  hintStyle: t.body.copyWith(color: p.textTertiary),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: p.textSecondary,
                    size: 20,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: p.surfaceRaised,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: KSpacing.md,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabs(BuildContext context) {
    final l10n = context.l10n;
    Widget tab(
      FamilyRankingBoard? board,
      String label,
      IconData icon, {
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
      child: Row(
        children: [
          tab(
            FamilyRankingBoard.prestige,
            l10n.familiesTabPrestige,
            Icons.workspace_premium_rounded,
          ),
          const SizedBox(width: KSpacing.sm),
          // Owner D116: no family battles exist yet — labelled "Soon",
          // greyed and not a button (D62 convention).
          tab(
            null,
            l10n.familiesTabBattle,
            Icons.sports_martial_arts_rounded,
            key: FamiliesScreen.battleTabKey,
          ),
          const SizedBox(width: KSpacing.sm),
          tab(
            FamilyRankingBoard.active,
            l10n.familiesTabActive,
            Icons.bar_chart_rounded,
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
                scoreLine: _scoreLine(context, board, e.score),
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
                scoreLine: l10n.familyNumber('${f.number}'),
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
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final searching = _query.isNotEmpty;
    final boardLoad = ref.watch(familyRankingsProvider(_board));
    final me = boardLoad.hasValue
        ? ref.read(familyRankingsProvider(_board).notifier).me
        : null;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(
          l10n.familiesTitle,
          style: t.title.copyWith(
            color: p.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          refreshFamilies(ref);
          await (searching
              ? ref.read(familySearchProvider(_query).future)
              : ref.read(familyRankingsProvider(_board).future));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            ..._mineSlivers(context),
            SliverToBoxAdapter(child: _listHeader(context)),
            if (searching)
              ..._searchSlivers(context)
            else ...[
              SliverToBoxAdapter(child: _tabs(context)),
              const SliverToBoxAdapter(child: SizedBox(height: KSpacing.md)),
              ..._boardSlivers(context),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: KSpacing.xl)),
          ],
        ),
      ),
      bottomNavigationBar: searching || me == null
          ? null
          : _MyRankBar(board: _board, me: me),
    );
  }
}

/// What a board row says under the name.
String _scoreLine(BuildContext context, FamilyRankingBoard board, int score) {
  final l10n = context.l10n;
  return board == FamilyRankingBoard.prestige
      ? l10n.familiesScoreMonth(familyCount(context, score))
      : l10n.familiesScoreActive(familyCount(context, score));
}

/// One board tab: a gold pill when selected; without [onTap], "Soon".
class _BoardTab extends StatelessWidget {
  const new({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
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
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.xs),
      decoration: BoxDecoration(
        gradient: selected ? FamilyColors.goldGradient : null,
        color: selected ? null : p.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.pill),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x40D98E28),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: KSpacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.label.copyWith(
                color: fg,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
            const PositionedDirectional(
              top: -8,
              end: 0,
              child: FamilySoonBadge(),
            ),
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

/// The top three on a soft panel: second, first (taller), third.
class _Podium extends StatelessWidget {
  const new({required this.board, required this.top, super.key});

  final FamilyRankingBoard board;
  final List<FamilyRankingEntry> top;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    FamilyRankingEntry? at(int place) =>
        top.length >= place ? top[place - 1] : null;
    Widget slot(int place, int flex) => Expanded(
      flex: flex,
      child: _PodiumCard(
        key: FamiliesScreen.podiumSlotKey(place),
        place: place,
        entry: at(place),
        board: board,
      ),
    );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
      padding: const EdgeInsets.fromLTRB(
        KSpacing.sm,
        KSpacing.md,
        KSpacing.sm,
        KSpacing.md,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.xl),
        gradient: dark
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [p.surfaceRaised, p.surface],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF4EA), Color(0xFFFFE6D5)],
              ),
      ),
      // The podium keeps 2nd – 1st – 3rd from the left in both directions
      // (owner D116: "2nd left, 1st centre larger, 3rd right").
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            slot(2, 10),
            const SizedBox(width: KSpacing.sm),
            slot(1, 12),
            const SizedBox(width: KSpacing.sm),
            slot(3, 10),
          ],
        ),
      ),
    );
  }
}

/// A banner-shaped card with a pointed bottom.
class _BannerClipper extends CustomClipper<Path> {
  const new();

  @override
  Path getClip(Size size) {
    const r = 16.0;
    final tip = size.height * 0.06;
    return Path()
      ..moveTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(size.width - r, 0)
      ..quadraticBezierTo(size.width, 0, size.width, r)
      ..lineTo(size.width, size.height - tip)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height - tip)
      ..close();
  }

  @override
  bool shouldReclip(_BannerClipper oldClipper) => false;
}

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final (top, bottom) = FamilyColors.podium[place - 1];
    final entry = this.entry;
    final first = place == 1;
    final art = FamilyArt.podiumCards[place - 1];
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final emblem = w * (first ? 0.5 : 0.48);
        final frame = w * (first ? 0.98 : 0.94);
        const white = Color(0xFFFFFFFF);
        final card = ClipPath(
          clipper: const _BannerClipper(),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [top, bottom],
              ),
              image: art == null
                  ? null
                  : DecorationImage(image: AssetImage(art), fit: BoxFit.cover),
            ),
            padding: EdgeInsets.fromLTRB(
              KSpacing.xs,
              frame * 0.62,
              KSpacing.xs,
              KSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry?.family.name ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  textDirection: entry == null
                      ? null
                      : Directionality.of(context),
                  style: t.bodyStrong.copyWith(
                    color: white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (entry != null) ...[
                  Text(
                    l10n.familyLevelLong(entry.family.level),
                    maxLines: 1,
                    style: t.caption.copyWith(color: const Color(0xE6FFFFFF)),
                  ),
                  const SizedBox(height: KSpacing.xxs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        board == FamilyRankingBoard.prestige
                            ? Icons.local_fire_department_rounded
                            : Icons.people_alt_rounded,
                        size: 14,
                        color: const Color(0xFFFFD86B),
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          familyCount(context, entry.score),
                          maxLines: 1,
                          style: t.label.copyWith(
                            color: white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KSpacing.xs),
                  FamilyJoinButton(family: entry.family, compact: true),
                ],
              ],
            ),
          ),
        );
        return Semantics(
          container: true,
          label: entry == null
              ? null
              : l10n.familiesPodiumLabel(place, entry.family.name),
          child: Padding(
            padding: EdgeInsets.only(top: first ? 0 : KSpacing.xl),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: frame * 0.3),
                  child: card,
                ),
                SizedBox(
                  width: frame,
                  height: frame * 0.9,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: frame * 0.1),
                        child: entry == null
                            ? SizedBox.square(dimension: emblem)
                            : FamilyEmblem(
                                url: entry.family.emblemUrl,
                                size: emblem,
                              ),
                      ),
                      Image.asset(
                        FamilyArt.podiumFrame(place),
                        width: frame,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                      ),
                      Positioned(
                        bottom: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: bottom,
                            border: Border.all(color: white, width: 2),
                          ),
                          child: Text(
                            '$place',
                            style: t.label.copyWith(
                              color: white,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One family in a list: place, emblem, name with the level, members, the
/// [scoreLine] and Join.
class FamilyBoardRow extends StatelessWidget {
  const new({
    required this.family,
    required this.scoreLine,
    super.key,
    this.rank,
  });

  final FamilyCard family;
  final String scoreLine;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final rank = this.rank;
    return InkWell(
      onTap: () => context.push(AppRoutes.family(family.id)),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.lg,
          vertical: KSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
        ),
        child: Row(
          children: [
            if (rank != null) ...[
              SizedBox(
                width: 26,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: t.title.copyWith(color: p.textPrimary),
                ),
              ),
              const SizedBox(width: KSpacing.xs),
            ],
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: FamilyColors.goldGradient,
              ),
              child: FamilyEmblem(url: family.emblemUrl, size: 46),
            ),
            const SizedBox(width: KSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          family.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyStrong.copyWith(
                            color: p.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: KSpacing.xs),
                      Flexible(
                        child: Text(
                          l10n.familyLevelLong(family.level),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.copyWith(
                            color: const Color(0xFFD2372C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    l10n.familyMembersCount(
                      family.memberCount,
                      family.capacity,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.copyWith(color: p.textSecondary),
                  ),
                  Text(
                    scoreLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: KSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 112),
              child: FamilyJoinButton(family: family),
            ),
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
        color: p.surface,
        elevation: 8,
        child: InkWell(
          key: FamiliesScreen.myRankKey,
          onTap: () => context.push(AppRoutes.family(me.family.id)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.lg,
              vertical: KSpacing.sm,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    rank == null ? '—' : '$rank',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: t.title.copyWith(color: FamilyColors.goldDeep),
                  ),
                ),
                FamilyEmblem(url: me.family.emblemUrl, size: 38),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: Column(
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
                        style: t.caption.copyWith(color: p.textSecondary),
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
