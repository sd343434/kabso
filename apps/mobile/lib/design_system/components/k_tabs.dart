import 'package:kabso_live/design_system/theme/app_theme.dart';
import 'package:kabso_live/design_system/tokens/component_metrics.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Scrollable text tabs (DESIGN_SYSTEM §9.8 `scrollable`, the secondary
/// level where chips don't fit): start-aligned,
/// `lg` side padding, 2 dp `primary` indicator under the selected label,
/// 1 dp `border` baseline. Order follows the reading direction (RTL in
/// Arabic). Min tab width 72 dp, hit height 48 dp.
class KScrollableTabs extends StatefulWidget {
  const new({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<KScrollableTabs> createState() => _KScrollableTabsState();
}

class _KScrollableTabsState extends State<KScrollableTabs> {
  late List<GlobalKey> _keys = _newKeys();

  List<GlobalKey> _newKeys() => [
    for (var i = 0; i < widget.labels.length; i++) GlobalKey(),
  ];

  @override
  void didUpdateWidget(KScrollableTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.labels.length != widget.labels.length) _keys = _newKeys();
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  void _reveal() {
    if (!mounted) return;
    final index = widget.selectedIndex;
    if (index < 0 || index >= _keys.length) return;
    final target = _keys[index].currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      alignment: 0.5,
      duration: KMotion.of(context, KMotion.base),
      curve: KMotion.standard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: SizedBox(
        height: KSizes.minTouchTarget,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: KSpacing.lg - KSpacing.sm,
          ),
          itemCount: widget.labels.length,
          itemBuilder: (context, i) => _Tab(
            key: _keys[i],
            label: widget.labels[i],
            selected: i == widget.selectedIndex,
            onTap: () => widget.onSelected(i),
            style: _TabStyle.scrollable,
          ),
        ),
      ),
    );
  }
}

/// Primary header tabs (HL-H2, VG-07): the screen's top-level segments
/// (e.g. Following · Popular · New). Selected: `title` 18/600
/// `textPrimary` over a short 16×3 dp `primary` indicator that fades in
/// (D33); unselected: `bodyStrong` 15 `textSecondary`. `lg` between labels,
/// no baseline. 48 dp hit height; order follows the reading direction.
///
/// The secondary level uses chips (`KChip`), never this style.
class KPrimaryTabs extends StatelessWidget {
  const new({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: KMetrics.topBarHeight,
    // Scrolls only if large text no longer fits; otherwise it is static.
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: KSpacing.lg / 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < labels.length; i++)
            _Tab(
              label: labels[i],
              selected: i == selectedIndex,
              onTap: () => onSelected(i),
              style: _TabStyle.primary,
            ),
        ],
      ),
    ),
  );
}

enum _TabStyle { primary, scrollable }

class _Tab extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.style,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final _TabStyle style;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final duration = KMotion.of(context, KMotion.fast);
    final primary = style == _TabStyle.primary;
    final textStyle = switch ((style, selected)) {
      (_TabStyle.primary, true) => t.title.copyWith(color: p.textPrimary),
      (_TabStyle.primary, false) => t.bodyStrong.copyWith(
        color: p.textSecondary,
      ),
      (_TabStyle.scrollable, _) => t.label.copyWith(
        color: selected ? p.textPrimary : p.textSecondary,
      ),
    };
    final indicator = AnimatedOpacity(
      duration: duration,
      opacity: selected ? 1 : 0,
      child: Container(
        width: primary ? KMetrics.tabIndicatorWidth : null,
        height: primary ? KMetrics.tabIndicatorHeight : KMetrics.stroke,
        decoration: BoxDecoration(
          color: p.primary,
          borderRadius: BorderRadius.circular(
            primary ? KMetrics.strokeLarge : KMetrics.stroke,
          ),
        ),
      ),
    );
    final text = AnimatedDefaultTextStyle(
      duration: duration,
      style: textStyle,
      child: Text(
        label,
        maxLines: 1,
        textAlign: TextAlign.center,
        textScaler: primary
            ? MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: KMetrics.topBarMaxTextScale)
            : null,
      ),
    );

    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: primary ? KSizes.minTouchTarget : KMetrics.tabMinWidth,
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: primary ? KSpacing.lg / 2 : KSpacing.sm,
            ),
            child: primary
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      text,
                      const SizedBox(height: KSpacing.xs),
                      indicator,
                      const SizedBox(height: KSpacing.xs),
                    ],
                  )
                : IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(),
                        text,
                        const Spacer(),
                        indicator,
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
