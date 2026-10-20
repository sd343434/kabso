import 'package:material_ui/material_ui.dart';

/// The owner's 3D art for the coin and the gift box (D74), 256 px WebP,
/// trimmed and centred on a square. They keep their own colours.
enum KabsoArt {
  coin('assets/art/kabso_coin.webp'),
  giftBox('assets/art/kabso_gift_box.webp');

  new(this.asset);

  final String asset;
}

/// [art] at [size] (square). Decorative: the caller labels it. [dimmed]
/// shows it faded (a disabled control).
class KabsoArtIcon extends StatelessWidget {
  const new(this.art, {super.key, this.size = 24, this.dimmed = false});

  final KabsoArt art;
  final double size;
  final bool dimmed;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Opacity(
      opacity: dimmed ? 0.4 : 1,
      child: Image.asset(
        art.asset,
        width: size,
        height: size,
        excludeFromSemantics: true,
        // A missing file must not break the screen.
        errorBuilder: (_, _, _) => SizedBox.square(dimension: size),
      ),
    ),
  );
}
