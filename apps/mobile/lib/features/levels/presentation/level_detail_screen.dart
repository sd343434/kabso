import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/features/levels/presentation/levels_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// One category (D72): the current emblem large, level, points and
/// progress, how the category grows, then the whole ladder with the
/// caller's level marked (`GET /levels/me/{category}`).
class LevelDetailScreen extends ConsumerWidget {
  const new({required this.category, super.key});

  final LevelCategory category;

  static Key ladderRowKey(int levelNumber) => Key('levels.ladder.$levelNumber');
  static const currentKey = Key('levels.ladder.current');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final load = ref.watch(myLevelProvider(category));
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(load.value?.summary.name ?? l10n.levelsTitle),
      ),
      body: switch (load) {
        AsyncValue(:final value?) when !value.summary.available => KEmptyState(
          icon: Icons.hourglass_empty_rounded,
          title: l10n.levelsUnavailable,
          message: l10n.levelsUnavailableBody,
        ),
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () => ref.refresh(myLevelProvider(category).future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsetsDirectional.all(KSpacing.lg),
            children: [
              _Hero(summary: value.summary),
              const SizedBox(height: KSpacing.xl),
              Semantics(
                header: true,
                child: Text(l10n.levelsLadder, style: context.textStyles.title),
              ),
              const SizedBox(height: KSpacing.sm),
              for (final level in value.levels)
                _LadderRow(
                  key: value.summary.level?.levelNumber == level.levelNumber
                      ? currentKey
                      : ladderRowKey(level.levelNumber),
                  category: category,
                  level: level,
                  current:
                      value.summary.level?.levelNumber == level.levelNumber,
                  reached: value.summary.points >= level.requiredPoints,
                ),
            ],
          ),
        ),
        AsyncValue(:final error?, isLoading: false) => FailureErrorState(
          title: l10n.levelsLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(myLevelProvider(category)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const new({required this.summary});

  final LevelSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final s = summary;
    final tier = summaryTier(s);
    final gem = KLevelArt.gem(tier);
    final level = s.level;
    return Container(
      padding: const EdgeInsetsDirectional.all(KSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.xl),
        border: Border.all(color: p.border),
        gradient: RadialGradient(
          center: const Alignment(0, -0.6),
          radius: 1.1,
          colors: [gem.withValues(alpha: 0.22), p.surface],
        ),
      ),
      child: Column(
        children: [
          KLevelEmblem(
            category: s.category,
            tier: tier,
            size: KLevels.heroEmblem,
          ),
          const SizedBox(height: KSpacing.sm),
          if (level != null) ...[
            Text(
              level.name,
              style: t.headline.copyWith(color: KLevelArt.text(tier)),
              textAlign: TextAlign.center,
            ),
            Text(
              l10n.levelsLevelNumber(level.levelNumber),
              style: t.bodyStrong.copyWith(color: p.textSecondary),
            ),
          ],
          const SizedBox(height: KSpacing.md),
          Text(l10n.levelsPoints(formatPoints(s.points)), style: t.title),
          const SizedBox(height: KSpacing.sm),
          KLevelProgressBar(percent: s.progressPercent ?? 0, color: gem),
          const SizedBox(height: KSpacing.xs),
          Text(
            s.maxLevel
                ? l10n.levelsMax
                : s.pointsToNext == null || s.nextLevel == null
                ? ''
                : l10n.levelsToNamed(
                    formatPoints(s.pointsToNext!),
                    s.nextLevel!.name,
                  ),
            style: t.caption.copyWith(color: p.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: KSpacing.md),
          Text(
            s.description,
            style: t.body.copyWith(color: p.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LadderRow extends StatelessWidget {
  const new({
    required this.category,
    required this.level,
    required this.current,
    required this.reached,
    super.key,
  });

  final LevelCategory category;
  final LevelBrief level;
  final bool current;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final tier = KLevelArt.tier(level.levelNumber, iconKey: level.iconKey);
    final required = l10n.levelsPoints(formatPoints(level.requiredPoints));
    return Semantics(
      selected: current,
      label: [
        level.name,
        l10n.levelsLevelNumber(level.levelNumber),
        required,
        if (current) l10n.levelsCurrent,
      ].join('، '),
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsetsDirectional.only(bottom: KSpacing.xs),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: KSpacing.md,
          vertical: KSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: current ? p.surfaceRaised : null,
          borderRadius: BorderRadius.circular(KRadius.md),
          border: current ? Border.all(color: KLevelArt.gem(tier)) : null,
        ),
        child: Row(
          children: [
            KLevelEmblem(
              category: category,
              tier: tier,
              size: KLevels.ladderEmblem,
              dimmed: !reached,
            ),
            const SizedBox(width: KSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.name,
                    style: t.bodyStrong.copyWith(
                      color: reached ? p.textPrimary : p.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Level number and threshold share one line that may
                  // wrap, so large text never pushes the row out.
                  Text(
                    '${l10n.levelsLevelNumber(level.levelNumber)} · $required',
                    style: t.caption.copyWith(
                      color: reached ? p.textSecondary : p.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (current) ...[
              const SizedBox(width: KSpacing.sm),
              Container(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: KSpacing.sm,
                  vertical: KSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: KLevelArt.gem(tier).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(KRadius.pill),
                ),
                child: Text(
                  l10n.levelsCurrent,
                  style: t.caption.copyWith(color: KLevelArt.gem(tier)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
