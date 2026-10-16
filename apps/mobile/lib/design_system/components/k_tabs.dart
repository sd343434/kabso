import 'package:kabso_live/design_system/theme/app_theme.dart';
import 'package:kabso_live/design_system/tokens/component_metrics.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Scrollable text tabs (DESIGN_SYSTEM §9.8 `scrollable`): start-aligned,
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
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final duration = KMotion.of(context, KMotion.fast);
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: KMetrics.tabMinWidth),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: KSpacing.sm,
            ),
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  AnimatedDefaultTextStyle(
                    duration: duration,
                    style: context.textStyles.label.copyWith(
                      color: selected ? p.textPrimary : p.textSecondary,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Spacer(),
                  AnimatedOpacity(
                    duration: duration,
                    opacity: selected ? 1 : 0,
                    child: Container(
                      height: KMetrics.stroke,
                      decoration: BoxDecoration(
                        color: p.primary,
                        borderRadius: BorderRadius.circular(KMetrics.stroke),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
