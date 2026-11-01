import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_room_style.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The art of a room theme (CP-011, D94): Kabso's own images
/// (`assets/live_themes/`, PROVENANCE.md), or the drawn classic theme.
@immutable
class LiveThemeArt {
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
    'sunset-sky' => const LiveThemeArt._(
      slug: 'sunset-sky',
      asset: 'assets/live_themes/sunset-sky.webp',
      accent: Color(0xFFFFB36B),
    ),
    'moon-palace' => const LiveThemeArt._(
      slug: 'moon-palace',
      asset: 'assets/live_themes/moon-palace.webp',
      accent: Color(0xFFB9A4FF),
    ),
    'ocean-depths' => const LiveThemeArt._(
      slug: 'ocean-depths',
      asset: 'assets/live_themes/ocean-depths.webp',
      accent: Color(0xFF3FC8FF),
    ),
    'golden-hall' => const LiveThemeArt._(
      slug: 'golden-hall',
      asset: 'assets/live_themes/golden-hall.webp',
      accent: Color(0xFFFFC24D),
    ),
    'game-arena' => const LiveThemeArt._(
      slug: 'game-arena',
      asset: 'assets/live_themes/game-arena.webp',
      accent: Color(0xFFB04DFF),
    ),
    'heart-garden' => const LiveThemeArt._(
      slug: 'heart-garden',
      asset: 'assets/live_themes/heart-garden.webp',
      accent: Color(0xFFFF4D8D),
    ),
    'galaxy' => const LiveThemeArt._(
      slug: 'galaxy',
      asset: 'assets/live_themes/galaxy.webp',
      accent: Color(0xFFA64DFF),
    ),
    // D212: the owner's podcast backgrounds (PROVENANCE.md) — cover-fit from
    // the top centre (cropped at the sides on narrow phones).
    'podcast-studio' => const LiveThemeArt._(
      slug: 'podcast-studio',
      asset: 'assets/live_themes/podcast-studio.webp',
      accent: Color(0xFFFF3B47),
      alignment: Alignment.topCenter,
      podcast: true,
    ),
    'podcast-majlis' => const LiveThemeArt._(
      slug: 'podcast-majlis',
      asset: 'assets/live_themes/podcast-majlis.webp',
      accent: Color(0xFFF5B651),
      alignment: Alignment.topCenter,
      podcast: true,
    ),
    'podcast-library' => const LiveThemeArt._(
      slug: 'podcast-library',
      asset: 'assets/live_themes/podcast-library.webp',
      accent: Color(0xFF3FD69B),
      alignment: Alignment.topCenter,
      podcast: true,
    ),
    _ => const LiveThemeArt._(
      slug: LiveThemes.classic,
      accent: KLiveStyle.accent,
    ),
  };
  const new _({
    required this.slug,
    required this.accent,
    this.asset,
    this.alignment = Alignment.center,
    this.podcast = false,
  });

  /// D212: the owner's podcast backgrounds, in the setup's order (the first
  /// is the PODCAST default). Adding one is data: the asset, a slug here and
  /// on the server (`LIVE_THEMES`), and its name.
  static const podcastThemes = [
    'podcast-studio',
    'podcast-majlis',
    'podcast-library',
  ];

  /// D212: a podcast started without a theme gets the studio.
  static const podcastDefault = 'podcast-studio';

  final String slug;
  final String? asset;

  /// D212: where a cover-fit image is anchored (the podcast art: the top).
  final Alignment alignment;

  /// D212: one of the owner's podcast backgrounds (a stronger top scrim
  /// keeps the header pills readable over their bright areas).
  final bool podcast;

  /// Glows, rings and the selected states take this colour.
  final Color accent;

  String name(AppLocalizations l10n) => switch (slug) {
    'ice-palace' => l10n.liveThemeIcePalace,
    'desert-night' => l10n.liveThemeDesertNight,
    'rose-garden' => l10n.liveThemeRoseGarden,
    'sunset-sky' => l10n.liveThemeSunsetSky,
    'moon-palace' => l10n.liveThemeMoonPalace,
    'ocean-depths' => l10n.liveThemeOceanDepths,
    'golden-hall' => l10n.liveThemeGoldenHall,
    'game-arena' => l10n.liveThemeGameArena,
    'heart-garden' => l10n.liveThemeHeartGarden,
    'galaxy' => l10n.liveThemeGalaxy,
    'podcast-studio' => l10n.liveThemePodcastStudio,
    'podcast-majlis' => l10n.liveThemePodcastMajlis,
    'podcast-library' => l10n.liveThemePodcastLibrary,
    _ => l10n.liveThemeClassic,
  };
}

/// A full-bleed room background: the theme image (cover), darkened at the
/// top and bottom so the controls stay legible; the classic theme is a deep
/// Kabso red glow on black, or sound waves in an audio room ([waves]).
class LiveThemeBackground extends StatelessWidget {
  const new({required this.theme, super.key, this.waves = false});

  final String theme;

  static const podcastScrimKey = Key('liveTheme.podcastScrim');

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
          alignment: art.alignment,
          errorBuilder: (_, _, _) => LiveNavyBackground(waves: waves),
        ),
        // D212: the podcast art is bright behind the header — a deeper top
        // scrim (the owner's ≈ rgba(10,4,24,.55)) under the header pills.
        if (art.podcast)
          const DecoratedBox(
            key: podcastScrimKey,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x8C0A0418), Color(0x000A0418)],
                stops: [0.05, 0.2],
              ),
            ),
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
