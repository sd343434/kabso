import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/theme/app_theme.dart';
import 'package:kabso_live/design_system/tokens/component_metrics.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

enum KBadgeVariant { live, pk }

/// Non-interactive status badge (DESIGN_SYSTEM §9.5): `live` ("LIVE" /
/// "مباشر" on `live.badge`) and `pk` ("PK" on the live gradient). Both use
/// a white `label` at weight 700 (4.79:1 on `live.badge`).
class KBadge extends StatelessWidget {
  const new({required this.variant, super.key});

  const new live({super.key}) : variant = KBadgeVariant.live;

  const new pk({super.key}) : variant = KBadgeVariant.pk;

  final KBadgeVariant variant;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = switch (variant) {
      KBadgeVariant.live => l10n.liveBadge,
      KBadgeVariant.pk => l10n.pkBadge,
    };
    final decoration = switch (variant) {
      KBadgeVariant.live => BoxDecoration(
        color: KLiveColors.badge,
        borderRadius: BorderRadius.circular(KRadius.xs),
      ),
      KBadgeVariant.pk => BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.xs),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: KBrandColors.gradientLive,
        ),
      ),
    };
    return Semantics(
      label: text,
      container: true,
      child: ExcludeSemantics(
        child: Container(
          height: KMetrics.badgeHeight,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: KSpacing.sm,
          ),
          decoration: decoration,
          // Hug the label horizontally, centre it in the fixed height.
          child: Center(
            widthFactor: 1,
            child: Text(
              text,
              maxLines: 1,
              textScaler: TextScaler.noScaling,
              style: _badgeText(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// Viewer count pill (§9.5 `liveWithViewers`): eye icon + compact count on
/// `scrim`. The screen-reader label always has the exact number.
class KViewerCountChip extends StatelessWidget {
  const new({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final white = KPalette.dark.textPrimary;
    return Semantics(
      label: l10n.liveViewers(count, KFormat.grouped(count)),
      container: true,
      child: ExcludeSemantics(
        child: Container(
          height: KMetrics.badgeHeight,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: KSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: KPalette.dark.scrim,
            borderRadius: BorderRadius.circular(KRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.visibility_outlined,
                size: KMetrics.iconXs,
                color: white,
              ),
              const SizedBox(width: KSpacing.xs),
              Text(
                KFormat.compact(count, l10n),
                maxLines: 1,
                textScaler: TextScaler.noScaling,
                style: _badgeText(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `live` badge next to the viewer chip (§9.10 tile, room header).
class KLiveWithViewers extends StatelessWidget {
  const new({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const KBadge.live(),
      const SizedBox(width: KSpacing.xs),
      KViewerCountChip(count: count),
    ],
  );
}

/// Badge text: `label` with weight 700, white. Badges sit on media so the
/// height is fixed; text scaling is absorbed by the screen-reader label.
TextStyle _badgeText(BuildContext context) => context.textStyles.label.copyWith(
  fontWeight: FontWeight.w700,
  color: KPalette.dark.textPrimary,
  height: 1,
);
