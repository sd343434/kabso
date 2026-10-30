import 'package:material_ui/material_ui.dart';

/// The owner's art for the coin and the gift box (D74), trimmed and
/// centred on a square; they keep their own colours. D135 (owner: "make the
/// currency the gold coin"): the coin people spend is the owner's gold coin
/// (`assets/currency/kabso_coin.png`, PROVENANCE; the Kabi coin since D161) —
/// gift prices, the balance, the wallet, lucky wins; what a host earns is
/// the Kab Cherry (`KCherryIcon`, D134).
///
/// D182 (owner: «these 3 icons are the coin, the cherry, the ticket»): the
/// three currency icons are one owner-supplied set (`assets/currency/`,
/// PROVENANCE) — the Kabi coin (D161), the cherry and the ticket (game
/// cards).
enum KabsoArt {
  coin('assets/currency/kabso_coin.png'),

  /// The host currency, the Kab Cherry; drawn by `KCherryIcon`.
  cherry('assets/currency/kabso_cherry.webp'),

  /// Game cards (the owner's ticket). Nothing shows game cards yet.
  ticket('assets/currency/kabso_ticket.webp'),
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
