// v1.136-social (D384, owner 2026-11-12: «انتبه جيداً لطريقة الصورة شخصية»;
// CONVENTIONS §10.173.4): the VIP animated picture «صورة متحركة» on the
// person card — the member's own clip with its background removed, looping
// large above the name instead of the round photo.

import 'package:kabso_live/features/vip/domain/animated_avatar.dart';
import 'package:material_ui/material_ui.dart';

/// The image of a hosted animated picture URL (tests serve their own
/// synthetic stand-ins; nothing real is bundled).
@visibleForTesting
ImageProvider Function(String src) animatedAvatarImageFor = NetworkImage.new;

/// [animatedAvatarImageFor] for the app's other files.
ImageProvider animatedAvatarImage(String src) => animatedAvatarImageFor(src);

/// D384 geometry: the cut-out's square box and how it sits on the sheet.
abstract final class VipCutoutMetrics {
  /// The square box at 393 pt wide (about 43 % of the width, never more
  /// than [maxSide]).
  static const double maxSide = 168;

  /// The share of the box above the sheet's top edge (the head over the
  /// edge, as in the owner's reference).
  static const double overEdge = 0.28;

  /// The share of the box the card's top tools leave free at their row
  /// (they sit at the face's height, narrower than the shoulders).
  static const double toolsGap = 0.62;

  /// The lower part that fades into the sheet (the shoulders' cut).
  static const double fade = 0.16;

  /// The side of the box on a sheet [width] wide.
  static double sideFor(double width) => (width * 0.43).clamp(120.0, maxSide);
}

/// The member's cut-out [avatar] in a [side] square: the looping animated
/// WebP, or its still when [playing] is false (reduced motion, «إخفاء
/// المؤثرات»), its shoulders fading out at the bottom and a soft shadow under
/// the chin. While the picture loads, or when it cannot be loaded, [fallback]
/// shows instead (the round photo).
class VipCutout extends StatelessWidget {
  const new({
    required this.avatar,
    required this.side,
    required this.playing,
    required this.fallback,
    super.key,
  });

  final AnimatedAvatar avatar;
  final double side;
  final bool playing;
  final Widget fallback;

  static const playingKey = Key('vip.cutout.playing');
  static const stillKey = Key('vip.cutout.still');
  static const shadowKey = Key('vip.cutout.shadow');
  static const fallbackKey = Key('vip.cutout.fallback');

  @override
  Widget build(BuildContext context) {
    final image = animatedAvatarImageFor(
      playing ? avatar.url : avatar.stillUrl,
    );
    return SizedBox.square(
      dimension: side,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // The soft shadow under the chin, on the sheet behind the
          // shoulders.
          Positioned(
            bottom: side * 0.10,
            child: IgnorePointer(
              child: Container(
                key: shadowKey,
                width: side * 0.56,
                height: side * 0.10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(side * 0.28, side * 0.05),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ShaderMask(
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
              child: Image(
                key: playing ? playingKey : stillKey,
                image: image,
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                frameBuilder: (context, child, frame, sync) =>
                    frame == null && !sync ? _fallback() : child,
                errorBuilder: (_, _, _) => _fallback(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback() => KeyedSubtree(
    key: fallbackKey,
    child: Align(alignment: const Alignment(0, 0.45), child: fallback),
  );
}
