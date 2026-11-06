import 'package:kabso_live/design_system/design_system.dart';
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
    // D291 «ملوك الثروة»: the owner's art of each level (2026-11-06,
    // assets/medals/PROVENANCE.md); the medal's own key shows level 1.
    'medal_wealth_kings' ||
    'medal_wealth_l1' => 'assets/medals/medal_wealth_l1.webp',
    'medal_wealth_l2' => 'assets/medals/medal_wealth_l2.webp',
    'medal_wealth_l3' => 'assets/medals/medal_wealth_l3.webp',
    'medal_wealth_l4' => 'assets/medals/medal_wealth_l4.webp',
    'medal_wealth_l5' => 'assets/medals/medal_wealth_l5.webp',
    'medal_wealth_l6' => 'assets/medals/medal_wealth_l6.webp',
    // D291 «سيد الحظ»: the owner's art of each level; the medal's own key
    // shows level 1.
    'medal_lucky_master' ||
    'medal_lucky_l1' => 'assets/medals/medal_lucky_l1.webp',
    'medal_lucky_l2' => 'assets/medals/medal_lucky_l2.webp',
    'medal_lucky_l3' => 'assets/medals/medal_lucky_l3.webp',
    'medal_lucky_l4' => 'assets/medals/medal_lucky_l4.webp',
    'medal_first_family' => 'assets/leaderboard/rank_shield_1.webp',
    'medal_first_cp' => 'assets/leaderboard/heart.webp',
    'medal_charm_10' => CharmTier.of(10).icon,
    'medal_charm_50' => CharmTier.of(50).icon,
    'medal_charm_100' => CharmTier.of(100).icon,
    _ => null,
  };

  /// Art that is a whole emblem (drawn full-size, without the tinted disc).
  static bool isEmblem(String iconKey) =>
      iconKey.startsWith('medal_wealth_') || iconKey.startsWith('medal_lucky_');

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

/// Greyscale (BT.709 luma) for medals not earned yet.
const ColorFilter medalGreyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// A medal's icon at [size]: its art on a soft disc, greyed out while
/// [locked].
///
/// v1.81-live (D291): a level's own hosted [iconUrl] replaces the art when
/// the panel set one (the art falls back to [iconKey] if it fails to load).
/// No number is drawn on the art (owner: «لا تضع رقم تحت الميداليات»); the
/// level is written as text next to it.
class MedalIcon extends StatelessWidget {
  const new({
    required this.iconKey,
    super.key,
    this.size = 40,
    this.locked = false,
    this.iconUrl,
    this.iconAsset,
  });

  final String iconKey;
  final double size;
  final bool locked;

  /// The level's own art (https), or null.
  final String? iconUrl;

  /// D291: the level's art bundled in the app (an asset key), or null; a
  /// key this app does not have falls back to [iconKey].
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    final own = iconAsset;
    final key = own != null && MedalArt.asset(own) != null ? own : iconKey;
    final asset = MedalArt.asset(key);
    final (icon, tint) = MedalArt.fallback(key);
    final emblem = MedalArt.isEmblem(key);
    final artSize = emblem ? size : size * 0.82;
    final fallbackArt = asset != null
        ? Image.asset(
            asset,
            width: artSize,
            height: artSize,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) =>
                Icon(icon, size: size * 0.55, color: tint),
          )
        : Icon(icon, size: size * 0.55, color: tint);
    final url = iconUrl;
    final art = url != null
        ? Image.network(
            url,
            width: artSize,
            height: artSize,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => fallbackArt,
          )
        : fallbackArt;
    final disc = emblem
        ? SizedBox(width: size, height: size, child: art)
        : Container(
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
      child: ColorFiltered(colorFilter: medalGreyscale, child: disc),
    );
  }
}

/// A level's number on a small gold plate (D291), Western digits, sized from
/// [size]: the sheet's level ladder only (never on a medal's art, owner:
/// «لا تضع رقم تحت الميداليات»).
class MedalLevelNumeral extends StatelessWidget {
  const new({required this.level, required this.size, super.key});

  static const numeralKey = Key('medal.numeral');

  final int level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final h = (size * 0.3).clamp(10.0, 30.0);
    final font = (h * 0.68).clamp(7.0, 20.0);
    return Container(
      key: numeralKey,
      height: h,
      constraints: BoxConstraints(minWidth: h * 1.15),
      padding: EdgeInsets.symmetric(horizontal: h * 0.28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(h / 2),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE29A), KBrandColors.gold, Color(0xFFC9932A)],
        ),
        border: Border.all(
          color: const Color(0xFF7A5512),
          width: (h * 0.06).clamp(0.6, 1.5),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          '$level',
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: KFonts.latin,
            fontSize: font,
            height: 1,
            fontWeight: FontWeight.w800,
            color: KStatusColors.onStatus,
          ),
        ),
      ),
    );
  }
}
