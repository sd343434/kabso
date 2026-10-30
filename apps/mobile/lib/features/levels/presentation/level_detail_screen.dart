import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/features/levels/presentation/level_category_card.dart';
import 'package:kabso_live/features/levels/presentation/levels_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// One category's page (D72; look D169, e.g. «صفحة مستوى الدعم»): the
/// categories as chips at the top to move between them, the level card
/// large (current badge, level, points, progress and "Need X experience
/// to the next level"), how the category grows, then every badge tier with
/// its levels and the points it starts at — reached tiers in colour, the
/// current one marked, the rest dimmed (`GET /levels/me/{category}`).
/// Support shows the owner's 21 badges; the others the pack's 11.
class LevelDetailScreen extends ConsumerStatefulWidget {
  const new({required this.category, super.key});

  final LevelCategory category;

  static Key chipKey(LevelCategory c) => Key('levels.chip.${c.slug}');
  static Key tierKey(int tier) => Key('levels.tier.$tier');
  static Key frameKey(int tier) => Key('levels.tier.frame.$tier');
  static const currentKey = Key('levels.tier.current');
  static const headerKey = Key('levels.header');
  static const unavailableKey = Key('levels.detail.unavailable');

  @override
  ConsumerState<LevelDetailScreen> createState() => _LevelDetailScreenState();
}

class _LevelDetailScreenState extends ConsumerState<LevelDetailScreen> {
  late LevelCategory _category = widget.category;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final load = ref.watch(myLevelsProvider);
    final summary = load.value
        ?.where((s) => s.category == _category)
        .firstOrNull;
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(summary?.name ?? l10n.levelsTitle),
      ),
      body: switch (load) {
        AsyncValue(:final value?) when summary != null => RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(myLevelProvider(_category))
              ..invalidate(myLevelsProvider);
            await ref.read(myLevelsProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsetsDirectional.fromSTEB(
              KLevels.side,
              0,
              KLevels.side,
              KSpacing.xl + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              Semantics(
                container: true,
                label: l10n.levelsCategories,
                child: Wrap(
                  spacing: KSpacing.sm,
                  runSpacing: KSpacing.sm,
                  children: [
                    for (final s in value)
                      KChip(
                        key: LevelDetailScreen.chipKey(s.category),
                        label: s.name,
                        selected: s.category == _category,
                        onSelected: () =>
                            setState(() => _category = s.category),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: KSpacing.sm),
              LevelCategoryCard(
                key: LevelDetailScreen.headerKey,
                summary: summary,
                header: true,
              ),
              const SizedBox(height: KSpacing.xl),
              _Heading(l10n.levelsHowItGrows),
              const SizedBox(height: KSpacing.xs),
              Text(
                summary.available
                    ? summary.description
                    : '${summary.description}\n${l10n.levelsUnavailableBody}',
                key: summary.available
                    ? null
                    : LevelDetailScreen.unavailableKey,
                style: context.textStyles.body.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: KSpacing.xl),
              _Heading(l10n.levelsTiers),
              const SizedBox(height: KSpacing.sm),
              _TierGrid(summary: summary),
            ],
          ),
        ),
        AsyncValue(:final error?, isLoading: false) => FailureErrorState(
          title: l10n.levelsLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(myLevelsProvider),
        ),
        AsyncValue(hasValue: true) => KEmptyState(
          icon: Icons.hourglass_empty_rounded,
          title: l10n.levelsUnavailable,
          message: l10n.levelsUnavailableBody,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
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

/// Every badge tier of the category: three per row, each with its badge,
/// its levels and — once the ladder is loaded — the points it starts at.
class _TierGrid extends ConsumerWidget {
  const new({required this.summary});

  final LevelSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final category = summary.category;
    // The ladder's points per level; an inactive category has none.
    final load = summary.available
        ? ref.watch(myLevelProvider(category))
        : null;
    final ladder = {
      for (final l in load?.value?.levels ?? const <LevelBrief>[])
        l.levelNumber: l.requiredPoints,
    };
    final level = summary.available ? summary.level : null;
    final current = level == null
        ? 0
        : KLevelArt.tierOf(category, level.levelNumber, iconKey: level.iconKey);
    final count = KLevelArt.tiersOf(category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (load case AsyncValue(:final error?, isLoading: false)) ...[
          KInlineMessage(message: failureMessage(l10n, toAppFailure(error))),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => ref.invalidate(myLevelProvider(category)),
              child: Text(l10n.actionRetry),
            ),
          ),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            const columns = 3;
            final w =
                (constraints.maxWidth - KSpacing.sm * (columns - 1)) / columns;
            return Wrap(
              spacing: KSpacing.sm,
              runSpacing: KSpacing.sm,
              children: [
                for (var t = 1; t <= count; t++)
                  SizedBox(
                    width: w,
                    child: _TierTile(
                      key: t == current
                          ? LevelDetailScreen.currentKey
                          : LevelDetailScreen.tierKey(t),
                      category: category,
                      tier: t,
                      start: ladder[KLevelArt.levelRange(category, t).$1],
                      current: t == current,
                      reached: t <= current,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TierTile extends StatelessWidget {
  const new({
    required this.category,
    required this.tier,
    required this.start,
    required this.current,
    required this.reached,
    super.key,
  });

  final LevelCategory category;
  final int tier;

  /// Points at the tier's first level, when the ladder is known.
  final BigInt? start;
  final bool current;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (from, to) = KLevelArt.levelRange(category, tier);
    final range = from == to
        ? l10n.levelsLv(from)
        : l10n.levelsTierRange(from, to);
    final tint = LevelCardTint(
      KLevelArt.gemOf(category, tier),
      active: reached,
    );
    final points = start == null
        ? null
        : l10n.levelsPoints(formatPoints(start!));
    // Support tiers come with the owner's avatar frame (D169).
    final frame = category == LevelCategory.support;
    return Semantics(
      selected: current,
      label: [
        range,
        ?points,
        if (frame) l10n.levelsTierFrame,
        if (current) l10n.levelsCurrent,
      ].join('، '),
      excludeSemantics: true,
      child: Stack(
        // The tile keeps its grid width.
        fit: StackFit.passthrough,
        children: [
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(
              KSpacing.xs,
              KSpacing.sm,
              KSpacing.xs,
              KSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KRadius.md),
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [tint.light, tint.deep],
              ),
              border: Border.all(
                color: current ? tint.gem : Colors.white.withValues(alpha: 0.7),
                width: current ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                KLevelEmblem(
                  category: category,
                  tier: tier,
                  size: KLevels.tileBadge,
                  dimmed: !reached,
                ),
                const SizedBox(height: KSpacing.xxs),
                Text(
                  range,
                  maxLines: 1,
                  textDirection: TextDirection.ltr,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.bodyStrong.copyWith(
                    fontSize: 13,
                    color: tint.ink,
                  ),
                ),
                Text(
                  current ? l10n.levelsCurrent : points ?? ' ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.caption.copyWith(
                    fontSize: 11.5,
                    color: current ? tint.ink : tint.inkSoft,
                    fontWeight: current ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
          if (frame)
            PositionedDirectional(
              top: KSpacing.xxs,
              end: KSpacing.xxs,
              child: Opacity(
                key: LevelDetailScreen.frameKey(tier),
                opacity: reached ? 1 : 0.45,
                child: Image.asset(
                  KLevelArt.supportFrame(tier),
                  width: KLevels.tileFrame,
                  height: KLevels.tileFrame,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
