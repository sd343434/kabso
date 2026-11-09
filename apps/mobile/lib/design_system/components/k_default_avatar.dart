import 'package:material_ui/material_ui.dart';

/// D337 (owner: «اجعل هذه الصورة التلقائية لأي حساب»): the picture of every
/// account without a photo (or whose photo fails to load) — the owner's
/// Kabso mascot, cropped on its head and headphones so it reads inside a
/// circle (`assets/avatar/PROVENANCE.md`). It replaces the initial-letter
/// fallback; the server still sends no avatar (`null`).
abstract final class KDefaultAvatarArt {
  /// 192 px: avatars up to 192 physical pixels (64 dp at 3×).
  static const small = 'assets/avatar/kabso_default_avatar_192.webp';

  /// 512 px: larger avatars and pictures that fill a card.
  static const large = 'assets/avatar/kabso_default_avatar_512.webp';

  /// The file for a picture [logicalSize] dp wide at [devicePixelRatio].
  static String assetFor(double logicalSize, double devicePixelRatio) =>
      logicalSize * devicePixelRatio <= 192 ? small : large;
}

/// The default picture filling [size] (a square), or its box when [size] is
/// `null`, cropped by [fit]. Not clipped: the caller clips (a circle, a
/// rounded square). Decorative: the caller labels it.
class KDefaultAvatarImage extends StatelessWidget {
  const new({super.key, this.size, this.fit = BoxFit.cover});

  final double? size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 3;
    Widget image(double side) => Image.asset(
      KDefaultAvatarArt.assetFor(side, dpr),
      width: size,
      height: size,
      fit: fit,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      // A missing file must not break the screen.
      errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
    );
    final fixed = size;
    if (fixed != null) return image(fixed);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.hasBoundedWidth ? box.maxWidth : 0.0;
        final h = box.hasBoundedHeight ? box.maxHeight : 0.0;
        return SizedBox.expand(child: image(w > h ? w : h));
      },
    );
  }
}
