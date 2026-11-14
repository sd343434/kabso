import 'dart:math' as math;

import 'package:kabso_live/core/models/shared_models.dart';
import 'package:material_ui/material_ui.dart';

/// The one outer box every avatar frame is drawn in (owner, after D185–D189:
/// «تثبيت حجم مثل حجم هذا» — the recharge-agent frame's size on the
/// profile): the recharge-agent frame's own box, [aspect] wide for 1 high.
/// In each context (profile header, person card, seat) every frame — the
/// recharge-agent and host-agent frames, the active-host frames (D186) and
/// the CP Special Frame — is scaled so its painted art fits this box
/// (contained, centred); the photo then fits that art's measured circle.
@immutable
final class AvatarFrameBox {
  const new(this.width);

  /// The box around an [avatar]-wide photo slot: the recharge-agent frame's
  /// box on the profile (1.6 × the slot wide, D185).
  factory aroundAvatar(double avatar) => AvatarFrameBox(avatar * avatarFactor);

  /// The box [height] high.
  factory ofHeight(double height) => AvatarFrameBox(height * aspect);

  /// The recharge-agent frame art's width / height (1312 × 1199).
  static const double aspect = 1312 / 1199;

  /// The box's width for an avatar-wide photo slot.
  static const double avatarFactor = 1.6;

  final double width;
  double get height => width / aspect;

  /// The side of a square frame art fitted in the box.
  double get square => math.min(width, height);

  /// The size of art [artAspect] (width / height) fitted in the box.
  Size fit(double artAspect) => artAspect >= aspect
      ? Size(width, width / artAspect)
      : Size(height * artAspect, height);

  /// How far below the box's top a fitted art [artHeight] high starts.
  double topOf(double artHeight) => (height - artHeight) / 2;

  /// [frame] centred in the box.
  Widget place(Widget frame) => SizedBox(
    width: width,
    height: height,
    child: Center(child: frame),
  );

  @override
  bool operator ==(Object other) =>
      other is AvatarFrameBox && other.width == width;

  @override
  int get hashCode => width.hashCode;
}

/// The avatar frames this app can draw around a photo (bag `AVATAR_FRAME`,
/// v1.55-social, D186, CONVENTIONS §10.49): the art and the photo's circle
/// in it, measured from the art's alpha channel (fractions of the square
/// art; `assets/host_frames/PROVENANCE.md`). A frame without art here (a
/// newer server, or a support frame whose circle is not measured) is not
/// drawn.
enum AvatarFrameArt {
  /// D186: the active-host frames (owner art), blue and pink.
  hostBlue('assets/host_frames/host_frame_blue.webp', 0.5086, 0.4887, 0.2830),
  hostPink('assets/host_frames/host_frame_pink.webp', 0.5158, 0.4959, 0.2784);

  new(this.asset, this.cx, this.cy, this.r);

  /// The square WebP art.
  final String asset;

  /// The photo circle's centre and radius, as fractions of the art's side.
  final double cx;
  final double cy;
  final double r;

  /// The photo is drawn this much larger than the measured circle so its
  /// edge tucks under the ring.
  static const double tuck = 1.04;

  /// The art for [assetKey], or null when this app has none.
  static AvatarFrameArt? byAssetKey(String? assetKey) => switch (assetKey) {
    'host_frame_blue' => hostBlue,
    'host_frame_pink' => hostPink,
    _ => null,
  };

  /// The art for a worn [frame], or null.
  static AvatarFrameArt? of(AvatarFrame? frame) => byAssetKey(frame?.assetKey);

  /// The art's side for a photo [picture] across.
  double widthForPicture(double picture) => picture / (2 * r * tuck);

  /// The photo's diameter in art [width] wide.
  double pictureForWidth(double width) => width * 2 * r * tuck;
}

/// A round photo ([child], [picture] across) with the frame [art] around it.
///
/// By default the widget is the photo's size and the frame overflows it
/// (seats: the layout does not move; the frame never takes taps). With
/// [layout] the widget is the frame's size and the photo sits in its circle
/// (the profile header). No name is written under the frame (owner, D186).
class FramedAvatar extends StatelessWidget {
  const new({
    required this.art,
    required this.picture,
    required this.child,
    super.key,
    this.layout = false,
  });

  final AvatarFrameArt art;
  final double picture;
  final Widget child;
  final bool layout;

  static const frameKey = Key('avatarFrame.art');

  @override
  Widget build(BuildContext context) {
    final width = art.widthForPicture(picture);
    final frame = IgnorePointer(
      child: Image.asset(
        art.asset,
        key: frameKey,
        width: width,
        height: width,
        fit: BoxFit.fill,
        excludeFromSemantics: true,
      ),
    );
    if (layout) {
      return SizedBox.square(
        dimension: width,
        child: Stack(
          children: [
            Positioned(
              left: width * art.cx - picture / 2,
              top: width * art.cy - picture / 2,
              width: picture,
              height: picture,
              child: child,
            ),
            Positioned.fill(child: frame),
          ],
        ),
      );
    }
    return SizedBox.square(
      dimension: picture,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: child),
          Positioned(
            left: picture / 2 - width * art.cx,
            top: picture / 2 - width * art.cy,
            width: width,
            height: width,
            child: frame,
          ),
        ],
      ),
    );
  }
}
