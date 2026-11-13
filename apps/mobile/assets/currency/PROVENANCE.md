# Kabso currency set — the Kabi coin, the Kab Cherry, the ticket

## Currency set v2 — cherry and ticket (owner-supplied, AI-generated, 2026-10-30, D182)

The owner supplied three currency icons as one set (owner, verbatim: "use the new cherry and coin
icons I sent; these 3 icons are the coin, the cherry, the ticket"), each a 1254×1254 RGBA WebP
generated with an AI image tool for Kabso and approved by the owner. Originals stay outside git:

| Original | sha256 |
| -------- | ------ |
| `coin.webp` | `8bab8f8efd6af7ca860d063fede9927ff61788b0b148a69097883d2b031f0b0c` |
| `cherry.webp` | `566220e9ee4848af9ecf5d79da7fc082967cc2680e59fcef7d5e4f8f0b6b06ac` |
| `ticket.webp` | `20f6c8a9e73e4f3a642bff8dc041de96540bbf266f65bb9d73f35d76475f5faa` |

- **Coin:** the same art as the D161 Kabi coin: the original trimmed to its alpha bounds, centred on a
  square and resized to 256 px (Lanczos) equals `kabso_coin.png` pixel for pixel (MAE 0 on all four
  channels). Nothing was added; `kabso_coin.png` stays.
- **Cherry and ticket:** the same steps — trimmed to the alpha bounds, centred on a transparent
  square, resized to 256×256 (Lanczos, 3x of the largest size drawn, 44 pt) and saved as WebP
  (quality 92, lossless-quality alpha, method 6). Not otherwise modified.

| File | sha256 | Use |
| ---- | ------ | --- |
| `kabso_cherry.webp` (22.8 KB) | `545939d694c2799cd2c2a7f0f9347a0c970e4f4410db7c55a3ad6061f1f49232` | `KabsoArt.cherry`, drawn by `KCherryIcon` at every size: everything a host earns |
| `kabso_ticket.webp` (25.5 KB) | `84e4ac4fd906e8a5246a5105d3bcbdfc7b6af6a6c9ad107493c1de7a618b4a68` | `KabsoArt.ticket` (`KabsoArtIcon`): game cards (owner: 1 coin = 5 game cards). No screen shows game cards yet |

The cherry replaces the D134 art below: `kab_cherry_{48,128,256,512,small}.png` and the SVGA loop
`kab_cherry.svga` (which animated the old cherry) were removed from the app.

## Kab Cherry «الكرز» v1 (owner-supplied, 2026-10-27, D134; removed D182)

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
