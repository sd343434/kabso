import 'package:kabso_live/design_system/components/k_badge.dart';
import 'package:kabso_live/design_system/theme/app_theme.dart';
import 'package:kabso_live/design_system/tokens/component_metrics.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Avatar ring (DESIGN_SYSTEM §9.4). `live` overrides the story rings.
enum KAvatarRing { none, storyUnseen, storySeen, live }

/// Circular avatar: [image] (or a network [imageUrl]) when set, otherwise
/// the first letter of [name] on a surface circle. An optional [ring] is
/// drawn outside the image; [size] is always the image diameter.
class KAvatar extends StatelessWidget {
  const new({
    required this.name,
    super.key,
    this.imageUrl,
    this.image,
    this.size = KSizes.avatarMd,
    this.ring = KAvatarRing.none,
    this.semanticLabel,
  });

  /// The 68 dp story-tray avatar (58 dp image, 3 dp stroke, 2 dp gap).
  const new story({
    required this.name,
    super.key,
    this.imageUrl,
    this.image,
    this.ring = KAvatarRing.storyUnseen,
    this.semanticLabel,
  }) : size = KMetrics.storyImage;

  final String name;
  final String? imageUrl;

  /// Takes precedence over [imageUrl] (tests and galleries use memory images).
  final ImageProvider? image;
  final double size;
  final KAvatarRing ring;
  final String? semanticLabel;

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  bool get _isStory => size == KMetrics.storyImage;

  double get _stroke => switch (ring) {
    KAvatarRing.none => 0,
    KAvatarRing.storySeen => KMetrics.thinStroke,
    _ when _isStory || size >= KSizes.avatarLg => KMetrics.strokeLarge,
    _ => KMetrics.stroke,
  };

  double get _gap => switch (ring) {
    KAvatarRing.none => 0,
    _ when !_isStory && size >= KSizes.avatarLg => KMetrics.ringGapLarge,
    _ => KMetrics.ringGap,
  };

  /// Outer diameter including the ring. For seen stories the thinner stroke
  /// keeps the same outer size as unseen ones, so the tray does not jump.
  double get outerSize {
    if (ring == KAvatarRing.none) return size;
    final stroke = ring == KAvatarRing.storySeen && _isStory
        ? KMetrics.strokeLarge
        : _stroke;
    return size + 2 * (stroke + _gap);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final fallback = Container(
      width: size,
      height: size,
      alignment: AlignmentDirectional.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: p.surfaceOverlay,
        border: Border.all(color: p.border),
      ),
      child: Text(
        _initial,
        textScaler: TextScaler.noScaling,
        style: context.textStyles.title.copyWith(
          fontSize: size * 0.4,
          color: p.textPrimary,
        ),
      ),
    );

    final url = imageUrl;
    final provider =
        image ?? (url == null || url.isEmpty ? null : NetworkImage(url));
    var content = provider == null
        ? fallback
        : ClipOval(
            child: Image(
              image: provider,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
          );

    if (ring != KAvatarRing.none) {
      content = _ringed(context, content);
    }

    final suffix = switch (ring) {
      KAvatarRing.none => null,
      KAvatarRing.storyUnseen => l10n.avatarStoryUnseen,
      KAvatarRing.storySeen => l10n.avatarStorySeen,
      KAvatarRing.live => l10n.avatarLiveNow,
    };
    final base = semanticLabel ?? name;
    return Semantics(
      image: true,
      label: suffix == null ? base : '$base, $suffix',
      child: ExcludeSemantics(child: content),
    );
  }

  Widget _ringed(BuildContext context, Widget image) {
    final p = context.palette;
    final outer = outerSize;
    final ringDecoration = switch (ring) {
      KAvatarRing.live => const BoxDecoration(
        shape: BoxShape.circle,
        // Static sweep (reduce motion and default are the same: no rotation).
        gradient: SweepGradient(
          colors: [...KBrandColors.gradientLive, KBrandColors.red400],
        ),
      ),
      KAvatarRing.storyUnseen => BoxDecoration(
        shape: BoxShape.circle,
        color: p.primary,
      ),
      _ => BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: p.border, width: _stroke),
      ),
    };
    // The ring is a filled disc (or an outline for seen stories) with a
    // background-coloured gap ring between it and the image.
    final filled = ring != KAvatarRing.storySeen;
    final inset = (outer - size) / 2 - _gap;
    final ringed = SizedBox.square(
      dimension: outer,
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: [
          DecoratedBox(
            decoration: ringDecoration,
            child: SizedBox.square(dimension: outer),
          ),
          if (filled)
            Container(
              width: outer - 2 * inset,
              height: outer - 2 * inset,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.background,
              ),
            ),
          image,
        ],
      ),
    );
    if (ring != KAvatarRing.live || size < KSizes.avatarMd) return ringed;
    // LIVE badge overlapping the bottom centre of the ring.
    return SizedBox(
      width: outer,
      height: outer + KMetrics.badgeHeight / 2,
      child: Stack(
        alignment: AlignmentDirectional.topCenter,
        children: [
          ringed,
          const PositionedDirectional(
            bottom: 0,
            child: ExcludeSemantics(child: KBadge.live()),
          ),
        ],
      ),
    );
  }
}
