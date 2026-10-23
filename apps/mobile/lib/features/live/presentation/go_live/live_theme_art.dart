import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_room_style.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The art of a room theme (CP-011, D94): Kabso's own images
/// (`assets/live_themes/`, PROVENANCE.md), or the drawn classic theme.
@immutable
class LiveThemeArt {
  const new _({required this.slug, required this.accent, this.asset});

  /// The art for [slug]; an unknown slug gets the classic theme (contract).
  factory of(String slug) => switch (slug) {
    'ice-palace' => const LiveThemeArt._(
      slug: 'ice-palace',
      asset: 'assets/live_themes/ice-palace.webp',
      accent: Color(0xFF5CC8FF),
    ),
    'desert-night' => const LiveThemeArt._(
      slug: 'desert-night',
      asset: 'assets/live_themes/desert-night.webp',
      accent: Color(0xFFF5B651),
    ),
    'rose-garden' => const LiveThemeArt._(
      slug: 'rose-garden',
      asset: 'assets/live_themes/rose-garden.webp',
      accent: Color(0xFFFF4D6D),
    ),
    _ => const LiveThemeArt._(
      slug: LiveThemes.classic,
      accent: KLiveStyle.accent,
    ),
  };

  final String slug;
  final String? asset;

  /// Glows, rings and the selected states take this colour.
  final Color accent;

  String name(AppLocalizations l10n) => switch (slug) {
    'ice-palace' => l10n.liveThemeIcePalace,
    'desert-night' => l10n.liveThemeDesertNight,
    'rose-garden' => l10n.liveThemeRoseGarden,
    _ => l10n.liveThemeClassic,
  };
}

/// A full-bleed room background: the theme image (cover), darkened at the
/// top and bottom so the controls stay legible; the classic theme is a deep
/// Kabso red glow on black, or sound waves in an audio room ([waves]).
class LiveThemeBackground extends StatelessWidget {
  const new({required this.theme, super.key, this.waves = false});

  final String theme;

  /// Faint sound-wave lines on the classic navy (audio rooms, D94).
  final bool waves;

  @override
  Widget build(BuildContext context) {
    final art = LiveThemeArt.of(theme);
    final asset = art.asset;
    // Classic: the calm navy of the owner's audio-room reference (D94).
    if (asset == null) return LiveNavyBackground(waves: waves);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          asset,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => LiveNavyBackground(waves: waves),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x99000000),
                Color(0x1A000000),
                Color(0x1A000000),
                Color(0xCC000000),
              ],
              stops: [0, 0.28, 0.6, 1],
            ),
          ),
        ),
      ],
    );
  }
}
