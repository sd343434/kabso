import 'package:kabso_live/design_system/theme/app_theme.dart';
import 'package:kabso_live/design_system/tokens/component_metrics.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Filter chip (DESIGN_SYSTEM §9.9, HL-H3): the secondary level under the
/// primary tabs (categories) and, later, gift quantities.
///
/// 32 dp visual, `pill` radius, inside a 48 dp hit area. Selected: `primary`
/// fill with `onPrimary` text; unselected: `surfaceRaised` (dark) or
/// `surfaceOverlay` (light, D68) with
/// `textPrimary`. Announced as a selectable option in a mutually exclusive
/// group.
///
/// With a `null` [onSelected] the chip is not interactive: use it when the
/// chip is the only option (nothing to switch to), so no control is shown
/// that does nothing.
class KChip extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    super.key,
    this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final duration = KMotion.of(context, KMotion.fast);
    final chip = AnimatedContainer(
      duration: duration,
      height: KMetrics.chipHeight,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: KSpacing.md),
      decoration: BoxDecoration(
        // In the light theme `surfaceRaised` is the page white, so an
        // unselected chip takes `surfaceOverlay` to stay visible (D68).
        color: selected
            ? p.primary
            : Theme.of(context).brightness == Brightness.light
            ? p.surfaceOverlay
            : p.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          maxLines: 1,
          textScaler: MediaQuery.textScalerOf(context)
              .clamp(maxScaleFactor: KMetrics.topBarMaxTextScale),
          style: context.textStyles.label.copyWith(
            color: selected ? p.onPrimary : p.textPrimary,
          ),
        ),
      ),
    );

    final onTap = onSelected;
    return Semantics(
      selected: selected,
      button: onTap != null,
      inMutuallyExclusiveGroup: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: KSizes.minTouchTarget,
          minWidth: KSizes.minTouchTarget,
        ),
        child: onTap == null
            ? Center(widthFactor: 1, heightFactor: 1, child: chip)
            : InkWell(
                onTap: onTap,
                customBorder: const StadiumBorder(),
                child: Center(widthFactor: 1, heightFactor: 1, child: chip),
              ),
      ),
    );
  }
}

/// A 48 dp row of [KChip]s padded `sm` at the start and end with an `sm`
/// gap, scrolling horizontally from the start edge (HL-H3).
class KChipRow extends StatelessWidget {
  const new({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: KSizes.minTouchTarget,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: KSpacing.sm),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(width: KSpacing.sm),
      itemBuilder: (_, i) => children[i],
    ),
  );
}
