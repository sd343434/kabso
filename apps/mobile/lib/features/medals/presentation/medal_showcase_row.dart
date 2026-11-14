import 'package:kabso_live/features/medals/domain/medal_models.dart';
import 'package:kabso_live/features/medals/presentation/medal_icon.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The medals a user chose to show (`PublicProfile.medals.showcase`, owner
/// D106 amendment): up to five icons (D269) in one row, in their order, each
/// with its level in the row's label (D291; no number on the art). Nothing
/// at all when the showcase is empty: no placeholders, no auto-fill.
class MedalShowcaseRow extends StatelessWidget {
  const new({
    required this.medals,
    super.key,
    this.size = 26,
    this.onTap,
    this.alignment = MainAxisAlignment.center,
    this.spacing = 6,
  });

  final List<ProfileMedal> medals;
  final double size;
  final VoidCallback? onTap;
  final MainAxisAlignment alignment;

  /// The space between two medals (D316: wider on the centred profile).
  final double spacing;

  static const rowKey = Key('profile.medals.showcase');

  static Key medalKey(String code) => Key('profile.medals.showcase.$code');

  @override
  Widget build(BuildContext context) {
    final shown = medals.take(maxShowcaseMedals).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final label = l10n.medalsRowLabel(
      shown.map((m) => '${m.name} ${l10n.medalsLevel(m.level)}').join('، '),
    );
    final row = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: alignment,
        children: [
          for (final (i, m) in shown.indexed) ...[
            if (i > 0) SizedBox(width: spacing),
            MedalIcon(
              key: medalKey(m.code),
              iconKey: m.iconKey,
              size: size,
              iconUrl: m.iconUrl,
              iconAsset: m.iconAsset,
            ),
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
