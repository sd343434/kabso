import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:material_ui/material_ui.dart';

/// The art of a medal's `iconKey` (CP-018). There is no medal art yet
/// (the owner supplies it later), so a key either borrows a fitting Kabso
/// asset or falls back to a design-system icon in a tinted circle; nothing
/// is copied from another product.
///
/// - `medal_first_family`: the leaderboard's gold shield (the family box);
/// - `medal_first_cp`: the leaderboard's heart (the relationship box);
/// - `medal_charm_10` / `_50` / `_100`: that level's charm creature (D101);
/// - `medal_first_live`, `medal_live_hours_10`, `medal_live_hours_100`,
///   `medal_bullet_first` and any other key: a fallback icon (no art yet).
abstract final class MedalArt {
  /// A Kabso asset for [iconKey], or null for the fallback.
  static String? asset(String iconKey) => switch (iconKey) {
    'medal_first_family' => 'assets/leaderboard/rank_shield_1.webp',
    'medal_first_cp' => 'assets/leaderboard/heart.webp',
    'medal_charm_10' => CharmTier.of(10).icon,
    'medal_charm_50' => CharmTier.of(50).icon,
    'medal_charm_100' => CharmTier.of(100).icon,
    _ => null,
  };

  /// The fallback icon and tint of [iconKey].
  static (IconData, Color) fallback(String iconKey) => switch (iconKey) {
    'medal_first_live' => (Icons.videocam_rounded, const Color(0xFFE5484D)),
    'medal_live_hours_10' => (Icons.schedule_rounded, const Color(0xFF3E7BFA)),
    'medal_live_hours_100' => (
      Icons.workspace_premium_rounded,
      const Color(0xFF7448DC),
    ),
    'medal_bullet_first' => (Icons.campaign_rounded, const Color(0xFFE08A00)),
    _ => (Icons.military_tech_rounded, const Color(0xFFB8860B)),
  };
}

/// A medal's icon at [size]: its art on a soft disc, greyed out while
/// [locked].
class MedalIcon extends StatelessWidget {
  const new({
    required this.iconKey,
    super.key,
    this.size = 40,
    this.locked = false,
  });

  final String iconKey;
  final double size;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final asset = MedalArt.asset(iconKey);
    final (icon, tint) = MedalArt.fallback(iconKey);
    final art = asset != null
        ? Image.asset(
            asset,
            width: size * 0.82,
            height: size * 0.82,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) =>
                Icon(icon, size: size * 0.55, color: tint),
          )
        : Icon(icon, size: size * 0.55, color: tint);
    final disc = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tint.withValues(alpha: 0.14),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: art,
    );
    if (!locked) return disc;
    return Opacity(
      opacity: 0.45,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0, //
          0, 0, 0, 1, 0,
        ]),
        child: disc,
      ),
    );
  }
}
