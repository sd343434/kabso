import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The level badges on a profile (owner, CP-005 §9.1 7): one per active
/// category, in display order — the emblem with the level number. Nothing
/// while loading, on error, or when no category is active, so the header
/// never shows an invented or empty level. [username] null = the caller,
/// whose badges open "My levels" through [onOpen].
class ProfileLevels extends ConsumerWidget {
  const new({super.key, this.username, this.onOpen});

  final String? username;
  final VoidCallback? onOpen;

  static const rowKey = Key('profile.levels');

  static const double badgeHeight = 18;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levels = ref.watch(profileLevelsProvider(username)).value ?? const [];
    final shown = [
      for (final l in levels)
        if (l.level case final level?) (l, level),
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final label = [
      for (final (l, level) in shown)
        '${l.name}: ${l10n.levelsLevelNumber(level.levelNumber)}',
    ].join('، ');
    final row = Wrap(
      spacing: KSpacing.sm,
      runSpacing: KSpacing.xs,
      children: [
        for (final (l, level) in shown)
          KLevelBadge(
            category: l.category,
            levelNumber: level.levelNumber,
            iconKey: level.iconKey,
            height: badgeHeight,
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: KSpacing.sm),
      child: Semantics(
        key: rowKey,
        container: true,
        label: label,
        button: onOpen != null,
        onTap: onOpen,
        excludeSemantics: true,
        child: GestureDetector(onTap: onOpen, child: row),
      ),
    );
  }
}
