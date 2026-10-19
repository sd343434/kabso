import 'package:kabso_live/features/debug/feed_preview_screen.dart'
    show FeedPreviewArt;
import 'package:material_ui/material_ui.dart';

/// Which slot a preview photo fills; each kind cycles through photos made
/// for that shape.
enum PreviewPhotoKind { portrait, landscape, avatar }

/// KL-056 development imagery for the debug previews only: AI-generated,
/// fictional people and places (`assets/preview/`, provenance in
/// `assets/preview/README.md`). Never used by production screens, which show
/// real API media or their honest states.
abstract final class PreviewPhotos {
  static const String _p = 'assets/preview';

  /// 9:16 — live covers and reels.
  static const List<String> portrait = [
    '$_p/live_music.webp',
    '$_p/live_cooking.webp',
    '$_p/live_gaming.webp',
    '$_p/live_chat.webp',
    '$_p/reel_souk.webp',
    '$_p/reel_dunes.webp',
    '$_p/reel_coffee.webp',
  ];

  /// 4:3 and square — post media and banners.
  static const List<String> landscape = [
    '$_p/post_city.webp',
    '$_p/post_oud.webp',
    '$_p/post_mezze.webp',
  ];

  /// Square headshots for avatars (face centred for circular crops).
  static const List<String> avatars = [
    '$_p/avatar_layla.webp',
    '$_p/avatar_omar.webp',
    '$_p/avatar_huda.webp',
  ];

  static String of(PreviewPhotoKind kind, int seed) {
    final list = switch (kind) {
      PreviewPhotoKind.portrait => portrait,
      PreviewPhotoKind.landscape => landscape,
      PreviewPhotoKind.avatar => avatars,
    };
    return list[seed.abs() % list.length];
  }

  static AssetImage image(PreviewPhotoKind kind, int seed) =>
      AssetImage(of(kind, seed));

  /// A headshot for a preview avatar, or `null` (initials) while
  /// [PreviewPhoto.enabled] is off.
  static ImageProvider? avatar(int seed) =>
      PreviewPhoto.enabled ? image(PreviewPhotoKind.avatar, seed) : null;

  /// A cover for a preview card, or `null` (fallback) while
  /// [PreviewPhoto.enabled] is off.
  static ImageProvider? cover(int seed) =>
      PreviewPhoto.enabled ? image(PreviewPhotoKind.portrait, seed) : null;
}

/// A preview photo over the generated [FeedPreviewArt]: the art shows until
/// the photo has decoded (no blank frame) and stays if it fails. Portrait
/// photos keep faces, which sit in the upper half, inside the crop.
class PreviewPhoto extends StatelessWidget {
  const new(
    this.seed, {
    super.key,
    this.kind = PreviewPhotoKind.portrait,
    this.alignment,
    this.photoSeed,
  });

  /// Seed of the generated art (and of the photo unless [photoSeed]).
  final int seed;

  /// Picks the photo independently of the art.
  final int? photoSeed;
  final PreviewPhotoKind kind;

  /// Defaults: portrait slightly above centre, others centred.
  final AlignmentGeometry? alignment;

  /// Widget tests and goldens keep the generated art only (asset decoding
  /// is asynchronous and would make goldens timing-dependent); set by
  /// `test/flutter_test_config.dart`.
  static bool enabled = true;

  @override
  Widget build(BuildContext context) {
    final art = CustomPaint(painter: FeedPreviewArt(seed));
    if (!enabled) return art;
    return Stack(
      fit: StackFit.expand,
      children: [
        art,
        Image(
          image: PreviewPhotos.image(kind, photoSeed ?? seed),
          fit: BoxFit.cover,
          alignment:
              alignment ??
              (kind == PreviewPhotoKind.portrait
                  ? const Alignment(0, -0.3)
                  : Alignment.center),
          gaplessPlayback: true,
          excludeFromSemantics: true,
          frameBuilder: (_, child, frame, sync) =>
              sync || frame != null ? child : const SizedBox.shrink(),
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
