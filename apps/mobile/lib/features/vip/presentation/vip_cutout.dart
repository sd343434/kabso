// v1.136-social (D384, owner 2026-11-12: «انتبه جيداً لطريقة الصورة شخصية»;
// CONVENTIONS §10.173.4): the VIP animated picture «صورة متحركة» on the
// person card — the member's own clip with its background removed. Owner
// (2026-11-12): it takes the round photo's place and size; «أريد صورة الملف
// الشخصي كأنها بدون خلفية»: no circle fill, ring or frame behind it; then
// «الصورة الشخصية يكون لها حواف مستديرة غير مرئية»: the person is bounded
// by the old photo circle at the bottom and the sides — a soft, feathered
// round edge that is never drawn — and open at the top, so the head pops
// over the circle and the card's edge.

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
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

  /// How much wider than the box the picture is drawn (only the open top
  /// shows it: below the circle's centre the circle bounds the person).
  static const double spread = 0.12;

  /// The round edge's feather (dp): a gentle silhouette, not a hard cut.
  static const double feather = 5;
}

/// The member's cut-out [avatar] in a [size] square — the round photo's
/// place, without its fill, ring or frame: the looping animated WebP, or its
/// still when [playing] is false (reduced motion, «إخفاء المؤثرات»). Below
/// the centre of the photo circle (the box inset by [circleInset]) the person
/// is bounded by that circle with a [VipCutoutMetrics.feather] soft edge that
/// is never drawn; above it the picture is open, popping up to
/// [VipCutoutMetrics.pop] × [size] over the box. While the picture loads, or
/// when it cannot be loaded, [fallback] shows instead (the round photo).
class VipCutout extends StatelessWidget {
  const new({
    required this.avatar,
    required this.size,
    required this.playing,
    required this.fallback,
    super.key,
    this.circleInset = 0,
  });

  final AnimatedAvatar avatar;
  final double size;
  final bool playing;
  final Widget fallback;

  /// The photo circle inside the box (the ring's width).
  final double circleInset;

  static const playingKey = Key('vip.cutout.playing');
  static const stillKey = Key('vip.cutout.still');
  static const fallbackKey = Key('vip.cutout.fallback');

  /// The invisible round edge (a feathered mask, nothing painted).
  static const edgeKey = Key('vip.cutout.edge');

  @override
  Widget build(BuildContext context) {
    final image = animatedAvatarImageFor(
      playing ? avatar.url : avatar.stillUrl,
    );
    final pop = size * VipCutoutMetrics.pop;
    final spread = size * VipCutoutMetrics.spread;
    // The photo circle in the picture's own coordinates.
    final circle = Rect.fromLTWH(
      spread / 2 + circleInset,
      pop + circleInset,
      size - 2 * circleInset,
      size - 2 * circleInset,
    );
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
              // The edge is on the picture only (the fallback photo stays
              // whole).
              frameBuilder: (context, child, frame, sync) =>
                  frame == null && !sync
                  ? _fallback(pop, spread)
                  : RoundEdge(
                      key: edgeKey,
                      circle: circle,
                      feather: VipCutoutMetrics.feather,
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

/// Bounds [child] by [circle] below the circle's centre — a soft edge
/// [feather] dp wide, never drawn — and leaves everything above the centre
/// open (to the child's own bounds and beyond them sideways). Implemented as
/// a layer the child is painted into, then erased (`dstOut`) outside the
/// union of the circle and the open top, the erasing shape blurred at the
/// edge.
class RoundEdge extends SingleChildRenderObjectWidget {
  const new({
    required this.circle,
    required this.feather,
    super.key,
    super.child,
  });

  final Rect circle;
  final double feather;

  @override
  RenderRoundEdge createRenderObject(BuildContext context) =>
      RenderRoundEdge(circle: circle, feather: feather);

  @override
  void updateRenderObject(BuildContext context, RenderRoundEdge renderObject) {
    renderObject
      ..circle = circle
      ..feather = feather;
  }
}

class RenderRoundEdge extends RenderProxyBox {
  new({required this._circle, required this._feather});

  Rect _circle;
  Rect get circle => _circle;
  set circle(Rect value) {
    if (value == _circle) return;
    _circle = value;
    markNeedsPaint();
  }

  double _feather;
  double get feather => _feather;
  set feather(double value) {
    if (value == _feather) return;
    _feather = value;
    markNeedsPaint();
  }

  /// The mask: the circle and, above its centre, an open region reaching well
  /// past the child's top and sides (so only the round edge is feathered).
  Path maskPath() {
    final reach = size.longestSide;
    return Path()
      ..addOval(_circle)
      ..addRect(
        Rect.fromLTRB(-reach, -reach, size.width + reach, _circle.center.dy),
      );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final canvas = context.canvas;
    final bounds = offset & size;
    canvas.saveLayer(bounds.inflate(_feather * 2), Paint());
    context.paintChild(child, offset);
    // paintChild may have moved to another canvas if the child composites;
    // the image never does, so this is the same canvas.
    // A blend mode only acts where a shape is drawn, so the outside of the
    // mask is erased (`dstOut`): the bounds less the mask, blurred at the
    // round edge.
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(bounds.inflate(_feather * 4)),
      maskPath().shift(offset),
    );
    context.canvas.drawPath(
      outside,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..maskFilter = _feather > 0
            ? ui.MaskFilter.blur(ui.BlurStyle.normal, _feather / 2)
            : null,
    );
    context.canvas.restore();
  }
}
