import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// What the Create button makes.
enum CreateMode { post, story, live }

/// Post · Story · LIVE under Create and the go-live camera (CP-010, the
/// owner's reference): the selected mode is bold with a dot under it.
class CreateModeBar extends StatelessWidget {
  const new({required this.selected, required this.onSelect, super.key});

  final CreateMode selected;
  final ValueChanged<CreateMode> onSelect;

  static Key modeKey(CreateMode mode) => Key('create.mode.${mode.name}');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    Widget mode(CreateMode m, String label) {
      final on = m == selected;
      return Semantics(
        button: true,
        selected: on,
        child: InkWell(
          key: modeKey(m),
          borderRadius: BorderRadius.circular(KRadius.sm),
          onTap: on ? null : () => onSelect(m),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: KSizes.minTouchTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    style: text.label.copyWith(
                      color: on ? p.textPrimary : p.textSecondary,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: KSpacing.xxs),
                  Container(
                    width: KSpacing.xs,
                    height: KSpacing.xs,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: on ? p.textPrimary : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Large text scales shrink the row rather than overflow it.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          mode(CreateMode.post, l10n.createModePost),
          mode(CreateMode.story, l10n.createModeStory),
          mode(CreateMode.live, l10n.createModeLive),
        ],
      ),
    );
  }
}
