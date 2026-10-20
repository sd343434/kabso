import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Levels geometry (D72).
abstract final class KLevels {
  static const double cardEmblem = 64;
  static const double heroEmblem = 128;
  static const double ladderEmblem = 40;
}

/// The caller's four independent levels (D72, CP-005): Attractiveness,
/// Support, Wizard and Gaming, each a card with its emblem, level, points
/// and progress to the next level, from `GET /levels/me`. A category the
/// server has not switched on shows as "not active yet" — the app never
/// invents a level.
class LevelsScreen extends ConsumerWidget {
  const new({super.key});

  static Key cardKey(LevelCategory c) => Key('levels.card.${c.slug}');
  static const preparingKey = Key('levels.preparing');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final load = ref.watch(myLevelsProvider);
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.levelsTitle),
      ),
      body: switch (load) {
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () => ref.refresh(myLevelsProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsetsDirectional.all(KSpacing.lg),
            children: [
              if (value.every((s) => !s.available)) ...[
                KInlineMessage(
                  key: preparingKey,
                  message: l10n.levelsPreparing,
                  isError: false,
                ),
                const SizedBox(height: KSpacing.lg),
              ] else ...[
                Text(
                  l10n.levelsIntro,
                  style: context.textStyles.caption.copyWith(
                    color: p.textSecondary,
                  ),
                ),
                const SizedBox(height: KSpacing.md),
              ],
              for (final summary in value) ...[
                LevelCard(
                  key: cardKey(summary.category),
                  summary: summary,
                  onTap: () =>
                      context.push(AppRoutes.level(summary.category.slug)),
                ),
                const SizedBox(height: KSpacing.md),
              ],
            ],
          ),
        ),
        AsyncValue(:final error?, isLoading: false) => FailureErrorState(
          title: l10n.levelsLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(myLevelsProvider),
        ),
        _ => const _LevelsSkeleton(),
      },
    );
  }
}

/// The tier of a summary's current level (tier 1 when it has none).
int summaryTier(LevelSummary s) {
  final level = s.level;
  return level == null
      ? 1
      : KLevelArt.tier(level.levelNumber, iconKey: level.iconKey);
}

/// One category: emblem, name, level, points and progress.
class LevelCard extends StatelessWidget {
  const new({required this.summary, required this.onTap, super.key});

  final LevelSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final s = summary;
    final tier = summaryTier(s);
    final level = s.level;
    final gem = KLevelArt.gem(tier);
    final status = !s.available
        ? l10n.levelsUnavailable
        : level == null
        ? l10n.levelsNoLevel
        : '${level.name} · ${l10n.levelsLevelNumber(level.levelNumber)}';
    final points = l10n.levelsPoints(formatPoints(s.points));
    final next = !s.available
        ? null
        : s.maxLevel
        ? l10n.levelsMax
        : s.pointsToNext == null
        ? null
        : l10n.levelsToNext(formatPoints(s.pointsToNext!));

    return Semantics(
      button: true,
      onTap: onTap,
      label: [s.name, status, if (s.available) points, ?next].join('، '),
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KRadius.lg),
          side: BorderSide(color: p.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(KSpacing.lg),
            child: Row(
              children: [
                KLevelEmblem(
                  category: s.category,
                  tier: tier,
                  size: KLevels.cardEmblem,
                  dimmed: !s.available,
                ),
                const SizedBox(width: KSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: KSpacing.xxs),
                      Text(
                        status,
                        style: t.bodyStrong.copyWith(
                          color: s.available
                              ? KLevelArt.text(tier)
                              : p.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (s.available) ...[
                        const SizedBox(height: KSpacing.sm),
                        KLevelProgressBar(
                          percent: s.progressPercent ?? 0,
                          color: gem,
                        ),
                        const SizedBox(height: KSpacing.xs),
                        // Points first, then what is left to the next level;
                        // one line that may wrap at large text sizes.
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: points,
                                style: TextStyle(
                                  color: p.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (next != null) TextSpan(text: ' · $next'),
                            ],
                          ),
                          style: t.caption.copyWith(color: p.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else ...[
                        const SizedBox(height: KSpacing.xxs),
                        Text(
                          s.description,
                          style: t.caption.copyWith(color: p.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  color: p.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelsSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('levels.skeleton'),
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsetsDirectional.all(KSpacing.lg),
    children: [
      for (var i = 0; i < 4; i++) ...[
        const Row(
          children: [
            KSkeleton(
              width: KLevels.cardEmblem,
              height: KLevels.cardEmblem,
              circle: true,
            ),
            SizedBox(width: KSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KSkeleton(width: 140, height: 18),
                  SizedBox(height: KSpacing.sm),
                  KSkeleton(width: 96),
                  SizedBox(height: KSpacing.sm),
                  KSkeleton(height: KLevelProgressBar.height),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: KSpacing.xl),
      ],
    ],
  );
}
