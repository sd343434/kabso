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

/// Every badge tier of a category (D169) as the reference's cards, two
/// per row on the board's deep indigo panel: the tier's name and levels,
/// «تم الفتح» or the points still needed to unlock it, a bar towards it,
/// the points it starts at, and a pill — «الحالي», «مفتوح» or «مقفل» (with
/// a lock; styling, not a button). Locked tiers are desaturated; an
/// inactive category shows every tier locked. One column when two would
/// not fit (a 360-lp phone at text scale 1.3).
class LevelTierGrid extends ConsumerWidget {
  const new({required this.summary, super.key});

  static Key tierKey(int tier) => Key('levels.tier.$tier');
  static Key frameKey(int tier) => Key('levels.tier.frame.$tier');
  static const currentKey = Key('levels.tier.current');
  static const unavailableKey = Key('levels.unavailable');
  static const panelKey = Key('levels.tiers.panel');

  final LevelSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final category = summary.category;
    // The ladder (points and names per level); an inactive category has none.
    final load = summary.available
        ? ref.watch(myLevelProvider(category))
        : null;
    final ladder = {
      for (final l in load?.value?.levels ?? const <LevelBrief>[])
        l.levelNumber: l,
    };
    final level = summary.available ? summary.level : null;
    final current = level == null
        ? 0
        : KLevelArt.tierOf(category, level.levelNumber, iconKey: level.iconKey);
    final count = KLevelArt.tiersOf(category);
    final scale = MediaQuery.textScalerOf(context).scale(1);
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
            final outer = constraints.maxWidth;
            // Two columns need ≈ 300 lp of text width at the current scale.
            final columns = outer / scale >= 300 ? 2 : 1;
            // outer = columns·W + 2·pad·W + (columns − 1)·gap·W.
            final w =
                outer /
                (columns +
                    2 * KLevelCard.panelPadFactor +
                    (columns - 1) * KLevelCard.columnGapFactor);
            final pad = w * KLevelCard.panelPadFactor;
            final gap = w * KLevelCard.columnGapFactor;
            return DecoratedBox(
              key: panelKey,
              decoration: BoxDecoration(
                color: KLevelCard.panel,
                borderRadius: BorderRadius.circular(KRadius.lg),
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.all(pad),
                child: Wrap(
                  spacing: gap,
                  runSpacing: pad,
                  children: [
                    for (var t = 1; t <= count; t++)
                      SizedBox(
                        width: w,
                        child: _TierCard(
                          key: t == current
                              ? LevelTierGrid.currentKey
                              : LevelTierGrid.tierKey(t),
                          summary: summary,
                          tier: t,
                          current: current,
                          ladder: ladder,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TierCard extends StatelessWidget {
  const new({
    required this.summary,
    required this.tier,
    required this.current,
    required this.ladder,
    super.key,
  });

  final LevelSummary summary;
  final int tier;

  /// The caller's tier (0 = none or inactive).
  final int current;
  final Map<int, LevelBrief> ladder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final category = summary.category;
    final (from, to) = KLevelArt.levelRange(category, tier);
    final range = from == to
        ? l10n.levelsLv(from)
        : l10n.levelsTierRange(from, to);
    final first = ladder[from];
    final title = first == null ? range : '${first.name} $range';
    final reached = tier <= current;
    final isCurrent = tier == current;
    final start = first?.requiredPoints;
    final left = start == null || reached ? null : start - summary.points;
    final InlineSpan line;
    if (!summary.available) {
      line = TextSpan(text: l10n.levelsUnavailable);
    } else if (reached) {
      line = TextSpan(text: l10n.levelsTierUnlocked);
    } else if (left != null && left > BigInt.zero) {
      final x = formatPoints(left);
      line = levelCardStressed(l10n.levelsTierToUnlock(x), x);
    } else {
      line = const TextSpan();
    }
    final progress = !summary.available
        ? null
        : reached
        ? 1.0
        : start == null || start == BigInt.zero
        ? 0.0
        : (summary.points.toDouble() / start.toDouble()).clamp(0.0, 1.0);
    final pill = isCurrent
        ? LevelCardPill(l10n.levelsTierCurrent)
        : reached
        ? LevelCardPill(l10n.levelsTierOpen)
        : LevelCardPill(l10n.levelsTierLocked, locked: true);
    // The starting points once the ladder is known (the title has the range).
    final caption = start == null
        ? ''
        : l10n.levelsTierFrom(formatPoints(start));
    final frame = category == LevelCategory.support
        ? KLevelArt.supportFrame(tier)
        : null;
    return Semantics(
      selected: isCurrent,
      label: [
        title,
        line.toPlainText().replaceAll(RegExp('[\u2066\u2069]'), ''),
        if (start != null) caption,
        if (frame != null) l10n.levelsTierFrame,
        pill.label,
      ].where((e) => e.isNotEmpty).join('، '),
      excludeSemantics: true,
      child: KeyedSubtree(
        key: frame == null ? null : LevelTierGrid.frameKey(tier),
        child: LevelTierCard(
          category: category,
          tier: tier,
          title: title,
          line: line,
          caption: caption,
          pill: pill,
          progress: progress,
          locked: !reached,
          frame: frame,
        ),
      ),
    );
  }
}
