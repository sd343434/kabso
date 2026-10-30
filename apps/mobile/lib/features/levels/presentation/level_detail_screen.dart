import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/features/levels/presentation/level_category_card.dart';
import 'package:kabso_live/features/levels/presentation/levels_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/levels/:category` (D72): since D169 the levels page itself
/// ([LevelsScreen]) opened on that category's tab.
class LevelDetailScreen extends StatelessWidget {
  const new({required this.category, super.key});

  final LevelCategory category;

  @override
  Widget build(BuildContext context) => LevelsScreen(initialCategory: category);
}

/// Every badge tier of a category (D169): three per row, each with its badge,
/// its levels and — once the ladder is loaded — the points it starts at.
class LevelTierGrid extends ConsumerWidget {
  const new({required this.summary, super.key});

  static Key tierKey(int tier) => Key('levels.tier.$tier');
  static Key frameKey(int tier) => Key('levels.tier.frame.$tier');
  static const currentKey = Key('levels.tier.current');
  static const unavailableKey = Key('levels.unavailable');

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
                          ? LevelTierGrid.currentKey
                          : LevelTierGrid.tierKey(t),
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
                key: LevelTierGrid.frameKey(tier),
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
