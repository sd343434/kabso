import 'package:material_ui/material_ui.dart';

/// The owner's art for the coin and the gift box (D74), trimmed and
/// centred on a square; they keep their own colours. D135 (owner: "make the
/// currency the gold coin"): the coin people spend is the owner's gold coin
/// with the crowned "K" (`assets/currency/kabso_coin.png`, PROVENANCE) —
/// gift prices, the balance, the wallet, lucky wins; what a host earns is
/// the Kab Cherry (`KCherryIcon`, D134).
enum KabsoArt {
  coin('assets/currency/kabso_coin.png'),
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
