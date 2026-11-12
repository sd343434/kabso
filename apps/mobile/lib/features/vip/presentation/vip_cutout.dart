// v1.136-social (D384, owner 2026-11-12: «انتبه جيداً لطريقة الصورة شخصية»;
// CONVENTIONS §10.173.4): the VIP animated picture «صورة متحركة» on the
// person card — the member's own clip with its background removed. Owner
// (2026-11-12): it takes the round photo's place and size; then «أريد صورة
// الملف الشخصي كأنها بدون خلفية»: no circle, no fill, no ring behind it —
// the card (or the D383 VIP background) shows around the person, the head
// pops a little over the box's top and the shoulders fade into the card.

import 'package:kabso_live/features/vip/domain/animated_avatar.dart';
import 'package:material_ui/material_ui.dart';

/// The image of a hosted animated picture URL (tests serve their own
/// synthetic stand-ins; nothing real is bundled).
@visibleForTesting
ImageProvider Function(String src) animatedAvatarImageFor = NetworkImage.new;

/// [animatedAvatarImageFor] for the app's other files.
ImageProvider animatedAvatarImage(String src) => animatedAvatarImageFor(src);

/// D384 geometry, as shares of the photo's box side.
abstract final class VipCutoutMetrics {
  /// How far the head pops over the box's top edge.
  static const double pop = 0.16;

  /// How much wider than the box the picture may be drawn (the head can be
  /// slightly wider than the old circle; nothing clips the sides).
  static const double spread = 0.12;

  /// The lower share of the picture that fades to transparent (the
  /// shoulders melt into the card).
  static const double fade = 0.2;
}

/// The member's cut-out [avatar] free-floating in a [size] square — the round
/// photo's place, without its circle, fill or ring: the looping animated
/// WebP, or its still when [playing] is false (reduced motion, «إخفاء
/// المؤثرات»), drawn up to [VipCutoutMetrics.pop] × [size] over the box's top
/// and a little wider than it, its lower [VipCutoutMetrics.fade] fading to
/// transparent. While the picture loads, or when it cannot be loaded,
/// [fallback] shows instead (the round photo).
class VipCutout extends StatelessWidget {
  const new({
    required this.avatar,
    required this.size,
    required this.playing,
    required this.fallback,
    super.key,
  });

  final AnimatedAvatar avatar;
  final double size;
  final bool playing;
  final Widget fallback;

  static const playingKey = Key('vip.cutout.playing');
  static const stillKey = Key('vip.cutout.still');
  static const fallbackKey = Key('vip.cutout.fallback');

  /// The soft fade at the bottom (a gradient mask, no hard edge).
  static const fadeKey = Key('vip.cutout.fade');

  @override
  Widget build(BuildContext context) {
    final image = animatedAvatarImageFor(
      playing ? avatar.url : avatar.stillUrl,
    );
    final pop = size * VipCutoutMetrics.pop;
    final spread = size * VipCutoutMetrics.spread;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -pop,
            left: -spread / 2,
            width: size + spread,
            height: size + pop,
            child: Image(
              key: playing ? playingKey : stillKey,
              image: image,
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              gaplessPlayback: true,
              excludeFromSemantics: true,
              // The fade is on the picture only (the fallback photo stays
              // whole).
              frameBuilder: (context, child, frame, sync) =>
                  frame == null && !sync
                  ? _fallback(pop, spread)
                  : ShaderMask(
                      key: fadeKey,
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (rect) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFFFFF),
                          Color(0xFFFFFFFF),
                          Color(0x00FFFFFF),
                        ],
                        stops: [0, 1 - VipCutoutMetrics.fade, 1],
                      ).createShader(rect),
                      child: child,
                    ),
              errorBuilder: (_, _, _) => _fallback(pop, spread),
            ),
          ),
        ],
      ),
    );
  }

  /// The round photo, in the box (below the pop, inside the spread).
  Widget _fallback(double pop, double spread) => KeyedSubtree(
    key: fallbackKey,
    child: Padding(
      padding: EdgeInsets.fromLTRB(spread / 2, pop, spread / 2, 0),
      child: fallback,
    ),
  );
}
