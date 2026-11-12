// v1.136-social (D384, owner 2026-11-12: «انتبه جيداً لطريقة الصورة شخصية»;
// CONVENTIONS §10.173.4): the VIP animated picture «صورة متحركة» on the
// person card — the member's own clip with its background removed. Owner
// (2026-11-12): «والصورة الشخصية الجديدة اجعلها كأنها بإطار دائري بنفس حجم
// الإطار السابق»: it replaces the round photo in place — the same circle, the
// same size and position, inside the same ring and frames — with the head
// popping a little over the circle's top edge.

import 'package:kabso_live/features/vip/domain/animated_avatar.dart';
import 'package:material_ui/material_ui.dart';

/// The image of a hosted animated picture URL (tests serve their own
/// synthetic stand-ins; nothing real is bundled).
@visibleForTesting
ImageProvider Function(String src) animatedAvatarImageFor = NetworkImage.new;

/// [animatedAvatarImageFor] for the app's other files.
ImageProvider animatedAvatarImage(String src) => animatedAvatarImageFor(src);

/// D384 geometry, as shares of the circle's diameter.
abstract final class VipCutoutMetrics {
  /// How far the head may pop over the circle's top edge (the 3D look).
  static const double pop = 0.16;

  /// The width of the band above the circle where the head may show (the
  /// shoulders and sides stay clipped to the circle).
  static const double head = 0.66;
}

/// The member's cut-out [avatar] inside a circle of [size] — the round
/// photo's place: the looping animated WebP, or its still when [playing] is
/// false (reduced motion, «إخفاء المؤثرات»), on [background] (the circle's
/// own fill), clipped to the circle at the bottom and sides; the head pops up
/// to [VipCutoutMetrics.pop] × [size] over the top edge. While the picture
/// loads, or when it cannot be loaded, [fallback] shows instead (the round
/// photo).
class VipCutout extends StatelessWidget {
  const new({
    required this.avatar,
    required this.size,
    required this.playing,
    required this.fallback,
    super.key,
    this.background,
  });

  final AnimatedAvatar avatar;
  final double size;
  final bool playing;
  final Widget fallback;

  /// The circle's fill behind the cut-out (it has no background of its own).
  final Color? background;

  static const playingKey = Key('vip.cutout.playing');
  static const stillKey = Key('vip.cutout.still');
  static const fallbackKey = Key('vip.cutout.fallback');

  /// The circle behind the cut-out.
  static const circleKey = Key('vip.cutout.circle');

  @override
  Widget build(BuildContext context) {
    final image = animatedAvatarImageFor(
      playing ? avatar.url : avatar.stillUrl,
    );
    final pop = size * VipCutoutMetrics.pop;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              key: circleKey,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: background,
              ),
            ),
          ),
          Positioned(
            top: -pop,
            left: 0,
            width: size,
            height: size + pop,
            child: ClipPath(
              clipper: _CircleWithHead(pop: pop),
              child: Image(
                key: playing ? playingKey : stillKey,
                image: image,
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                frameBuilder: (context, child, frame, sync) =>
                    frame == null && !sync ? _fallback(pop) : child,
                errorBuilder: (_, _, _) => _fallback(pop),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The round photo, in the circle (below the head band).
  Widget _fallback(double pop) => KeyedSubtree(
    key: fallbackKey,
    child: Padding(
      padding: EdgeInsets.only(top: pop),
      child: fallback,
    ),
  );
}

/// The circle (the lower [Size.width] square of the box) and, above its
/// centre, a band [VipCutoutMetrics.head] wide reaching [pop] over its top
/// edge, its upper corners rounded: the head pops out, the bottom and the
/// sides stay in the circle.
class _CircleWithHead extends CustomClipper<Path> {
  const new({required this.pop});

  final double pop;

  @override
  Path getClip(Size size) {
    final d = size.width;
    final circle = Path()..addOval(Rect.fromLTWH(0, pop, d, d));
    final w = d * VipCutoutMetrics.head;
    final band = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH((d - w) / 2, 0, w, pop + d / 2),
          topLeft: Radius.circular(w / 2),
          topRight: Radius.circular(w / 2),
        ),
      );
    return Path.combine(PathOperation.union, circle, band);
  }

  @override
  bool shouldReclip(_CircleWithHead old) => old.pop != pop;
}
