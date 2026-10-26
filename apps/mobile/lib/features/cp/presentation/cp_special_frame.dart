import 'dart:math' as math;

import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';
import 'package:kabso_live/features/cp/domain/cp_space_models.dart';
import 'package:kabso_live/features/cp/presentation/cp_space_art.dart';
import 'package:material_ui/material_ui.dart';

// The Special Frame privilege (CP-021, D112, CONVENTIONS §10.24) outside
// the CP space: a person whose couple unlocked `SPECIAL_FRAME` (CP level 1)
// wears the owner's winged heart frame (`assets/cp_space/cp_avatar_frame
// .webp`, see PROVENANCE.md) around their picture, wherever their profile's
// `cp` is already loaded (profile header, the live person card).

/// Whether a profile's couple unlocked a privilege.
extension ProfileCpPrivileges on ProfileCp {
  bool hasPrivilege(CpPrivilegeCode code) => privileges.contains(code.wire);
}

/// Whether the person whose profile carries [cp] wears the Special Frame.
bool cpWearsSpecialFrame(ProfileCp? cp) =>
    cp?.hasPrivilege(CpPrivilegeCode.specialFrame) ?? false;

/// A person's picture clipped to the heart opening of the Special Frame,
/// the frame drawn over it. [width] is the frame's width; the box is
/// trimmed to the art's painted height ([heightFor]), so nothing empty is
/// reserved above or below. The picture fills the heart (a photo, or the
/// initial on the usual avatar circle when there is none).
class CpSpecialFrameAvatar extends StatelessWidget {
  const new({
    required this.width,
    required this.name,
    super.key,
    this.imageUrl,
    this.image,
  });

  /// The frame's width (its art is square, 768², painted y 51–716).
  final double width;
  final String name;
  final String? imageUrl;
  final ImageProvider? image;

  static const _art = 768.0;
  static const _paintTop = 51.0;
  static const _paintBottom = 716.0;

  /// The heart opening's centre in the art (x 182–585, y 253–555).
  static const _holeCentre = Offset(383.5, 404);

  /// The heart opening's width in the art.
  static const _holeWidth = 403.0;

  /// The height of a frame [width] wide (only the painted part).
  static double heightFor(double width) =>
      width * (_paintBottom - _paintTop) / _art;

  /// How far below the box's top the picture's centre sits.
  static double pictureCentreY(double width) =>
      width * (_holeCentre.dy - _paintTop) / _art;

  /// The width of the picture (the heart opening) in a frame [width] wide.
  static double pictureWidth(double width) => width * _holeWidth / _art;

  /// The frame [width] whose heart opening is [picture] wide.
  static double widthForPicture(double picture) => picture * _art / _holeWidth;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: heightFor(width),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -width * _paintTop / _art,
          left: 0,
          width: width,
          height: width,
          child: CpFramedAvatar(
            size: width,
            child: _HeartFill(name: name, imageUrl: imageUrl, image: image),
          ),
        ),
      ],
    ),
  );
}

/// The picture, a little larger than the heart so the clip never shows an
/// edge.
class _HeartFill extends StatelessWidget {
  const new({required this.name, this.imageUrl, this.image});

  final String name;
  final String? imageUrl;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final side = math.max(box.maxWidth, box.maxHeight) * 1.1;
      return OverflowBox(
        // The heart's mass sits above its box's middle (the lobes): the
        // picture's centre (a face, an initial) goes up with it.
        alignment: const Alignment(0, -0.35),
        maxWidth: side,
        maxHeight: side,
        child: KAvatar(
          name: name,
          imageUrl: imageUrl,
          image: image,
          size: side,
        ),
      );
    },
  );
}
