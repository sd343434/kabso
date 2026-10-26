import 'package:kabso_live/features/medals/domain/medal_models.dart';
import 'package:kabso_live/features/medals/presentation/medal_icon.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The medals a user chose to show (`PublicProfile.medals.showcase`, owner
/// D106 amendment): up to six icons in one row, in their order. Nothing at
/// all when the showcase is empty: no placeholders, no auto-fill.
class MedalShowcaseRow extends StatelessWidget {
  const new({
    required this.medals,
    super.key,
    this.size = 26,
    this.onTap,
    this.alignment = MainAxisAlignment.center,
  });

  final List<ProfileMedal> medals;
  final double size;
  final VoidCallback? onTap;
  final MainAxisAlignment alignment;

  static const rowKey = Key('profile.medals.showcase');

  static Key medalKey(String code) => Key('profile.medals.showcase.$code');

  @override
  Widget build(BuildContext context) {
    final shown = medals.take(maxShowcaseMedals).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final label = context.l10n.medalsRowLabel(
      shown.map((m) => m.name).join('، '),
    );
    final row = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: alignment,
        children: [
          for (final (i, m) in shown.indexed) ...[
            if (i > 0) const SizedBox(width: 6),
            MedalIcon(key: medalKey(m.code), iconKey: m.iconKey, size: size),
          ],
        ],
      ),
    );
    return Semantics(
      key: rowKey,
      container: true,
      label: label,
      button: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Align(
          alignment: switch (alignment) {
            MainAxisAlignment.start => AlignmentDirectional.centerStart,
            _ => Alignment.center,
          },
          child: row,
        ),
      ),
    );
  }
}
