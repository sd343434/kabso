import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_category_card.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Levels geometry (D72; D169).
abstract final class KLevels {
  /// Side inset of the cards (16 lp: a 398-lp card on a 430-lp phone).
  static const double side = KSpacing.lg;

  /// Between two cards, on top of the badge rising above each card.
  static const double cardGap = KSpacing.sm;

  /// A tier tile's badge on the detail page.
  static const double tileBadge = 64;

  /// The support tier's avatar frame in the tile's top end corner (D169).
  static const double tileFrame = 34;
}

/// The caller's four independent levels (D72, CP-005; look D169): one card
/// per category — Attractiveness, Support, Wizard, Gaming, in the server's
/// order and names (`GET /levels/me`) — in a single column, each tinted to
/// its badge with the level, points, what is left to the next level and a
/// «التفاصيل» button that opens the category's page. A category the server
/// has not switched on says "not active yet" with its explanation — the
/// app never invents a level.
///
/// One column, not the board's two: the card holds a two-line Arabic title
/// and explanation next to a badge that takes a third of its width, which
/// needs ≈ 300 lp; two columns would leave 158 lp per card at 360 lp.
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
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.levelsTitle),
      ),
      body: switch (load) {
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () => ref.refresh(myLevelsProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsetsDirectional.fromSTEB(
              KLevels.side,
              KSpacing.sm,
              KLevels.side,
              KSpacing.xl + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              if (value.every((s) => !s.available))
                KInlineMessage(
                  key: preparingKey,
                  message: l10n.levelsPreparing,
                  isError: false,
                )
              else
                Text(
                  l10n.levelsIntro,
                  style: context.textStyles.caption.copyWith(
                    color: p.textSecondary,
                  ),
                ),
              for (final summary in value) ...[
                const SizedBox(height: KLevels.cardGap),
                LevelCategoryCard(
                  key: cardKey(summary.category),
                  summary: summary,
                  onOpen: () =>
                      context.push(AppRoutes.level(summary.category.slug)),
                ),
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

class _LevelsSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('levels.skeleton'),
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsetsDirectional.all(KLevels.side),
    children: [
      for (var i = 0; i < 4; i++) ...[
        const SizedBox(height: KLevelCard.medalRise),
        const KSkeleton(height: 170),
        const SizedBox(height: KLevels.cardGap),
      ],
    ],
  );
}
