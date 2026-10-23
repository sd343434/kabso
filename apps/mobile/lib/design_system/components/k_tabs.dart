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
    this.centered = false,
    this.action,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// D53: a word after the tabs, past a short divider, that does something
  /// else than select a tab (the Reels tab's Posts/Reels switch). Styled
  /// like an unselected tab, announced as a button, never selected.
  final KTabAction? action;

  /// D51: the tabs sit in the middle of the bar with [centeredGap] between
  /// them (the full-screen live hub); otherwise they start at the reading
  /// start, side by side.
  final bool centered;

  /// Extra space between centred tabs, on top of each tab's own padding.
  static const double centeredGap = KSpacing.md;

  /// Each label's side padding; [compactPadding] when the words would not
  /// fit otherwise (a 48 dp touch target is kept either way).
  static const double padding = KSpacing.lg / 2;
  static const double compactPadding = KSpacing.xs + 2;

  /// [centeredGap] when the words would not fit otherwise.
  static const double compactGap = KSpacing.xs;

  /// The row's natural width with [pad] around each word and [gap] between
  /// them (centred), measured with the labels' own styles and text scale.
  double _naturalWidth(BuildContext context, double pad, double gap) {
    final t = context.textStyles;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.topBarMaxTextScale);
    final direction = Directionality.of(context);
    double word(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return (width + 2 * pad).clamp(KSizes.minTouchTarget, double.infinity);
    }

    var width = 0.0;
    for (var i = 0; i < labels.length; i++) {
      if (centered && i > 0) width += gap;
      width += word(labels[i], i == selectedIndex ? t.title : t.bodyStrong);
    }
    if (action case final action?) {
      width += KMetrics.hairline + (centered ? gap : 0);
      width += word(action.label, t.bodyStrong);
    }
    return width;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: KMetrics.topBarHeight,
    // Tighter spacing first when the words do not fit (English at 360 dp);
    // scrolls only if large text still does not fit; otherwise static.
    child: LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - KSpacing.lg;
        final compact =
            _naturalWidth(context, padding, centeredGap) > available;
        final pad = compact ? compactPadding : padding;
        final gap = compact ? compactGap : centeredGap;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: KSpacing.lg / 2,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: centered ? available.clamp(0, double.infinity) : 0,
            ),
            child: Row(
              mainAxisAlignment: centered
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < labels.length; i++) ...[
                  if (centered && i > 0) SizedBox(width: gap),
                  _Tab(
                    label: labels[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                    style: _TabStyle.primary,
                    padding: pad,
                  ),
                ],
                if (action case final action?) ...[
                  if (centered) SizedBox(width: gap / 2),
                  Center(
                    child: Container(
                      width: KMetrics.hairline,
                      height: KSpacing.lg,
                      color: context.palette.border,
                    ),
                  ),
                  if (centered) SizedBox(width: gap / 2),
                  _ActionTab(action: action, padding: pad),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// The word [KPrimaryTabs.action] shows after the tabs.
@immutable
class KTabAction {
  const new({
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    this.key,
  });

  final String label;

  /// What the word does, for screen readers (e.g. "Show reels").
  final String semanticLabel;
  final VoidCallback onTap;
  final Key? key;
}

class _ActionTab extends StatelessWidget {
  const new({required this.action, required this.padding});

  final KTabAction action;
  final double padding;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: action.semanticLabel,
    excludeSemantics: true,
    child: InkWell(
      key: action.key,
      onTap: action.onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: KSizes.minTouchTarget),
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(horizontal: padding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                action.label,
                maxLines: 1,
                textAlign: TextAlign.center,
                textScaler: MediaQuery.textScalerOf(context)
                    .clamp(maxScaleFactor: KMetrics.topBarMaxTextScale),
                style: context.textStyles.bodyStrong.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
              // Room of the indicator, so the word sits on the tabs' line.
              const SizedBox(
                height: KSpacing.xs + KMetrics.tabIndicatorHeight + KSpacing.xs,
              ),
            ],
          ),
        ),
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
    this.padding = KPrimaryTabs.padding,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final _TabStyle style;

  /// Side padding of a primary tab.
  final double padding;

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
              horizontal: primary ? padding : KSpacing.sm,
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
