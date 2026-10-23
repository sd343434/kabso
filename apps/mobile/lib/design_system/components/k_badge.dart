import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/theme/app_theme.dart';
import 'package:kabso_live/design_system/tokens/component_metrics.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

enum KBadgeVariant { live, pk, newRoom, multiGuest }

/// Non-interactive status badge (DESIGN_SYSTEM §9.5, VG-11/12/16), 20 dp
/// high, white `label` at weight 700:
///
/// - `live`: "LIVE" / "مباشر" on `live.badge` (4.79:1). Where live and
///   non-live content mix (profile, search, avatars) and, since KL-047 (owner
///   request, reversing VG-10), on live grid cards too.
/// - `pk`: "PK" on a **solid** `brand.red600` fill (6.8:1); gradients are
///   reserved for the avatar live ring (VG-16).
/// - `newRoom`: "New" / "جديد" on `scrim`, shown instead of a viewer count
///   below 1 viewer (VG-11).
/// - `multiGuest`: seats glyph + guest [count] on `scrim` (VG-12).
class KBadge extends StatelessWidget {
  const new({required this.variant, super.key}) : count = null;

  const new live({super.key}) : variant = KBadgeVariant.live, count = null;

  const new pk({super.key}) : variant = KBadgeVariant.pk, count = null;

  const new newRoom({super.key})
    : variant = KBadgeVariant.newRoom,
      count = null;

  const new multiGuest({required int this.count, super.key})
    : variant = KBadgeVariant.multiGuest;

  final KBadgeVariant variant;

  /// Guests on stage (`multiGuest` only).
  final int? count;

  /// Solid PK fill (VG-16).
  static const Color pkFill = KBrandColors.red600;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final white = KPalette.dark.textPrimary;
    final guests = count ?? 0;
    final text = switch (variant) {
      KBadgeVariant.live => l10n.liveBadge,
      KBadgeVariant.pk => l10n.pkBadge,
      KBadgeVariant.newRoom => l10n.liveCardNew,
      KBadgeVariant.multiGuest => KFormat.grouped(guests),
    };
    final semantics = variant == KBadgeVariant.multiGuest
        ? l10n.liveMultiGuest(guests)
        : text;
    final decoration = switch (variant) {
      KBadgeVariant.live => BoxDecoration(
        color: KLiveColors.badge,
        borderRadius: BorderRadius.circular(KRadius.xs),
      ),
      KBadgeVariant.pk => BoxDecoration(
        color: pkFill,
        borderRadius: BorderRadius.circular(KRadius.xs),
      ),
      KBadgeVariant.newRoom || KBadgeVariant.multiGuest => BoxDecoration(
        color: KPalette.dark.scrim,
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
    };
    final label = Text(
      text,
      maxLines: 1,
      textScaler: TextScaler.noScaling,
      style: _badgeText(context),
    );
    return Semantics(
      label: semantics,
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
            child: variant == KBadgeVariant.multiGuest
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.groups_outlined,
                        size: KMetrics.iconXs,
                        color: white,
                      ),
                      const SizedBox(width: KSpacing.xs),
                      label,
                    ],
                  )
                : label,
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

/// A live's points (CP-012): a flame and the short count on `scrim`, the
/// same size as [KViewerCountChip].
class KScoreChip extends StatelessWidget {
  const new({required this.score, super.key});

  final int score;

  /// The flame's colour (warm orange, legible on `scrim`).
  static const flame = Color(0xFFFFA43A);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final formatted = KFormat.compact(score, l10n);
    return Semantics(
      label: l10n.liveScore(score, formatted),
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
              const Icon(
                Icons.local_fire_department_rounded,
                size: KMetrics.iconXs,
                color: flame,
              ),
              const SizedBox(width: KSpacing.xxs),
              Text(
                formatted,
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
