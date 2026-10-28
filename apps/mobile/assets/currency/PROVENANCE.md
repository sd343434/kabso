# Kab Cherry «الكرز», the host's currency (owner-supplied, 2026-10-27, D134)

Made for Kabso by the owner and supplied as the package `kabso_host_currency/kab_cherry`
(PNGs, SVGs, an SVGA loop, a preview video and a sample widget). The files below are copied
unchanged; the SVGs, the 24/32/64/96 px PNGs, the preview video and the sample widget (which
needs the archived `svgaplayer_flutter`) stay outside git. It replaces the gold "K" coin of
`assets/points/` next to every count a host earns; what people spend is the coin
(`KabsoArt.coin`, below).

| File | Use |
| ---- | --- |
| `kab_cherry_48.png` | `KCherryIcon` drawn at ≤ 26 pt (the owner's bucket) |
| `kab_cherry_small.png` | `KCherryIcon` at ≤ 34 pt (bolder small art) |
| `kab_cherry_128.png` | `KCherryIcon` at ≤ 48 pt |
| `kab_cherry_256.png` | `KCherryIcon` at ≤ 96 pt |
| `kab_cherry_512.png` | `KCherryIcon` above 96 pt |
| `kab_cherry.svga` | `KCherryIcon(animated: true)`: the sway / shine / sparkles loop, played with `flutter_svga` |

## Kabso coin (owner-supplied, 2026-10-25; restored 2026-10-27, D135)

`kabso_coin.png` is the owner's gold coin with a crowned "K", supplied on 2026-10-25 as the icon for
live points (then `assets/points/coin.png`, removed in D134 when points became cherries). The
original was a 1503x1046 image on black; the black background outside the coin was removed (dark
pixels reached from the image edges, a 3 px soft edge with the black divided out), the coin
cropped to its bounds, centred on a square and resized to 96x96 PNG (3x of the 32 pt it is drawn
at, at most). Not otherwise modified; the original stays outside git. Restored byte for byte from
git (`42be212^:apps/mobile/assets/points/coin.png`) when the owner asked for the gold coin as the
spending currency (D135); it replaces the D74 coin `assets/art/kabso_coin.webp` (removed).

| File | Use |
| ---- | --- |
| `kabso_coin.png` | `KabsoArt.coin`: every count of coins people spend — gift prices, quantities and the balance in the gift panel, the gift toast, the wallet, bullets, lucky wins, CP gifts |

## Kabso coin v2 — Kabi coin (owner-supplied, 2026-10-28, D161)

The owner replaced the crowned-"K" coin with a new spending-coin artwork: Kabi (3D, peace sign)
on a red medallion in a gold rim with a crown and red diamonds, supplied in the conversation as a
1254×1254 transparent PNG. `kabso_coin.png` now holds it trimmed, centred on a square canvas and
scaled to 256×256 (sharper than the old 96 px file at every size it is drawn). Same file name, so
`KabsoArt.coin` and every use above are unchanged.
