import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/features/levels/presentation/level_category_card.dart';
import 'package:kabso_live/features/levels/presentation/level_detail_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Levels geometry (D72; D169).
abstract final class KLevels {
  /// Side inset of the page (16 lp: a 398-lp card on a 430-lp phone).
  static const double side = KSpacing.lg;

  /// The category tab bar: its height, the badge in each tab and the
  /// selected tab's underline (D169, owner: four side by side, never
  /// wrapping).
  static const double tabBarHeight = 64;
  static const double tabBadge = 26;
  static const double tabIndicatorWidth = 28;
  static const double tabIndicatorHeight = 3;
}

/// The levels page (D72, CP-005; D169 after the owner's feedback «هذه
/// الصفحة ليس لها داعي، اجعل هذه الصفحة الأولى، والفلتر في الأعلى اجعله
/// بغير طريقة، والخانات بجانب بعض»): every entry — the Me hub, the
/// profile badges, `/levels` and `/levels/:category` — opens one page with
/// the four categories (Attractiveness, Support, Wizard, Gaming) as tabs side
/// by side at the top and a page per category under them that the tabs and
/// a swipe move between. Each page: the category's card (badge, level,
/// points, progress and "Need X experience to the next level"), how it
/// grows, and every badge tier ([LevelTierGrid]). An inactive category says
/// «غير مفعّل بعد» with its explanation and its tiers dimmed — the app
/// never invents a level.
///
/// It opens on [initialCategory], else the caller's highest active level,
/// else Attractiveness.
class LevelsScreen extends ConsumerStatefulWidget {
  const new({super.key, this.initialCategory});

  final LevelCategory? initialCategory;

  static Key tabKey(LevelCategory c) => Key('levels.tab.${c.slug}');
  static const tabBarKey = Key('levels.tabs');
  static const headerKey = Key('levels.header');
  static const preparingKey = Key('levels.preparing');

  /// The category to open on: the caller's highest active level (the first
  /// in order on a tie), else Attractiveness.
  static LevelCategory defaultCategory(List<LevelSummary> all) {
    LevelSummary? best;
    for (final s in all) {
      final n = s.available ? s.level?.levelNumber : null;
      if (n == null) continue;
      if (best == null || n > best.level!.levelNumber) best = s;
    }
    return best?.category ?? LevelCategory.attractiveness;
  }

  @override
  ConsumerState<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends ConsumerState<LevelsScreen> {
  PageController? _pages;
  LevelCategory? _selected;

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  /// Created once the summaries are known (the default needs them).
  PageController _controller(List<LevelSummary> all) {
    if (_pages case final p?) return p;
    final first = widget.initialCategory ?? LevelsScreen.defaultCategory(all);
    _selected = first;
    final index = all.indexWhere((s) => s.category == first);
    return _pages = PageController(initialPage: index < 0 ? 0 : index);
  }

  void _select(List<LevelSummary> all, LevelCategory c) {
    final index = all.indexWhere((s) => s.category == c);
    if (index < 0) return;
    setState(() => _selected = c);
    final duration = KMotion.of(context, KMotion.base);
    if (duration == Duration.zero) {
      _pages?.jumpToPage(index);
    } else {
      _pages?.animateToPage(index, duration: duration, curve: KMotion.standard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final load = ref.watch(myLevelsProvider);
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.levelsTitle),
      ),
      body: switch (load) {
        AsyncValue(:final value?) when value.isNotEmpty => () {
          final pages = _controller(value);
          final selected = _selected ?? value.first.category;
          return Column(
            children: [
              if (value.every((s) => !s.available))
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    KLevels.side,
                    0,
                    KLevels.side,
                    KSpacing.sm,
                  ),
                  child: KInlineMessage(
                    key: LevelsScreen.preparingKey,
                    message: l10n.levelsPreparing,
                    isError: false,
                  ),
                ),
              _CategoryTabBar(
                summaries: value,
                selected: selected,
                onSelect: (c) => _select(value, c),
              ),
              Expanded(
                child: PageView(
                  controller: pages,
                  onPageChanged: (i) =>
                      setState(() => _selected = value[i].category),
                  children: [for (final s in value) _CategoryPage(summary: s)],
                ),
              ),
            ],
          );
        }(),
        AsyncValue(:final error?, isLoading: false) => FailureErrorState(
          title: l10n.levelsLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(myLevelsProvider),
        ),
        AsyncValue(hasValue: true) => KEmptyState(
          icon: Icons.hourglass_empty_rounded,
          title: l10n.levelsUnavailable,
          message: l10n.levelsPreparing,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// The four categories side by side, equal widths, never wrapping: each
/// tab is the category's current badge over a short name (scaled down
/// rather than wrapped at large text), the selected one in Kabso red with
/// an underline. Order follows the reading direction.
class _CategoryTabBar extends StatelessWidget {
  const new({
    required this.summaries,
    required this.selected,
    required this.onSelect,
  });

  final List<LevelSummary> summaries;
  final LevelCategory selected;
  final ValueChanged<LevelCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      container: true,
      label: context.l10n.levelsCategories,
      child: DecoratedBox(
        key: LevelsScreen.tabBarKey,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.border)),
        ),
        child: SizedBox(
          height: KLevels.tabBarHeight,
          child: Row(
            children: [
              for (final s in summaries)
                Expanded(
                  child: _CategoryTab(
                    key: LevelsScreen.tabKey(s.category),
                    summary: s,
                    selected: s.category == selected,
                    onTap: () => onSelect(s.category),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const new({
    required this.summary,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final LevelSummary summary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = summary;
    final level = s.available ? s.level : null;
    final tier = level == null
        ? 1
        : KLevelArt.tierOf(
            s.category,
            level.levelNumber,
            iconKey: level.iconKey,
          );
    final color = selected ? p.primary : p.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: s.name,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: KSpacing.xxs,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              KLevelEmblem(
                category: s.category,
                tier: tier,
                size: KLevels.tabBadge,
                dimmed: !s.available,
              ),
              const SizedBox(height: KSpacing.xxs),
              SizedBox(
                height: 20,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    levelsTabName(context.l10n, s.category),
                    maxLines: 1,
                    style: context.textStyles.bodyStrong.copyWith(
                      fontSize: 14,
                      height: 1.2,
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: KSpacing.xxs),
              AnimatedContainer(
                duration: KMotion.of(context, KMotion.fast),
                width: KLevels.tabIndicatorWidth,
                height: KLevels.tabIndicatorHeight,
                decoration: BoxDecoration(
                  color: selected ? p.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(KRadius.pill),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One category's page: its card, how it grows, every badge tier.
class _CategoryPage extends ConsumerWidget {
  const new({required this.summary});

  final LevelSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final s = summary;
    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(myLevelProvider(s.category))
          ..invalidate(myLevelsProvider);
        await ref.read(myLevelsProvider.future);
      },
      child: ListView(
        key: PageStorageKey('levels.page.${s.category.slug}'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.fromSTEB(
          KLevels.side,
          KSpacing.md,
          KLevels.side,
          KSpacing.xl + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          LevelCategoryCard(key: LevelsScreen.headerKey, summary: s),
          const SizedBox(height: KSpacing.xl),
          _Heading(l10n.levelsHowItGrows),
          const SizedBox(height: KSpacing.xs),
          Text(
            s.available
                ? s.description
                : '${s.description}\n${l10n.levelsUnavailableBody}',
            key: s.available ? null : LevelTierGrid.unavailableKey,
            style: context.textStyles.body.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: KSpacing.xl),
          _Heading(l10n.levelsTiers),
          const SizedBox(height: KSpacing.sm),
          LevelTierGrid(summary: s),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(text, style: context.textStyles.title),
  );
}

/// The short name of [c] in the tab bar (D169).
String levelsTabName(AppLocalizations l10n, LevelCategory c) => switch (c) {
  LevelCategory.attractiveness => l10n.levelsTabAttractiveness,
  LevelCategory.support => l10n.levelsTabSupport,
  LevelCategory.wizard => l10n.levelsTabWizard,
  LevelCategory.gaming => l10n.levelsTabGaming,
};
