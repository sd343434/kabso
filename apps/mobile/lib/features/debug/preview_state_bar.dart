import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// KL-056 preview header row: the "test data" label and a chip per state the
/// preview can show (loading, error, empty, …). Debug screens only.
class PreviewStateBar<T> extends StatelessWidget {
  const new({
    required this.values,
    required this.value,
    required this.label,
    required this.onChanged,
    this.testDataKey,
    super.key,
  });

  final List<T> values;
  final T value;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  /// Key of the "test data" label, for the screen's tests.
  final Key? testDataKey;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    return Semantics(
      container: true,
      label: l10n.previewStateLabel,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.md,
          vertical: KSpacing.sm,
        ),
        child: Row(
          children: [
            DecoratedBox(
              key: testDataKey,
              decoration: BoxDecoration(
                color: p.surfaceOverlay,
                borderRadius: BorderRadius.circular(KRadius.xs),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.xs,
                  vertical: KSpacing.xxs,
                ),
                child: Text(
                  l10n.feedPreviewTestData,
                  style: context.textStyles.caption.copyWith(
                    color: p.textSecondary,
                  ),
                ),
              ),
            ),
            for (final s in values) ...[
              const SizedBox(width: KSpacing.xs),
              ChoiceChip(
                label: Text(label(s)),
                selected: s == value,
                onSelected: (_) => onChanged(s),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
