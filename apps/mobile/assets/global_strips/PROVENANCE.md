# Global strips «شريط الهدايا» and «شريط الألعاب» (owner-supplied, 2026-11-07, D305)

Two strip artworks made for Kabso and supplied by the owner on 2026-11-07 (owner: «هذا شريط الهدايا والآخر شريط
الألعاب»): 2000 × 667 RGBA WebP, a glass bar in a gold frame with wings, a crown on top and a medallion at the left
(the gift box; the trophy and gamepad). The art has no text; the app writes the words in code inside the glass bar.
The originals stay outside git:

| Original | sha256 |
| -------- | ------ |
| `gifts_strip.webp` (pink / magenta) | `ce0499a88d298c05473cc19bda2cd6ddabc82099c63db5ee89b8a4164894f0b6` |
| `games_strip.webp` (purple / blue) | `a5bf4c62dd3b496635f5094085cf689341c5f5391e49bd8e9259085ed4a05390` |

**Steps (both files the same):** cropped to the union of the two arts' alpha bounds (alpha > 16: x 17–1983,
y 40–611 → 1966 × 571, so both strips share one box and one text area), resized with Lanczos to 270 / 540 / 810 px
wide (D305b, owner «اجعل حجم الشريط اصغر»: the strip is drawn at most 270 pt wide, ≈ 78 pt tall with the crown and
wings; its glass bar ≈ 32 pt; the first version was 360 pt) and saved as WebP (quality 90, lossless-quality alpha,
method 6). Not otherwise modified; not mirrored in Arabic.

| File | Size | sha256 |
| ---- | ---- | ------ |
| `gift_strip.webp` (270 × 78) | 14.6 KB | `4da8de985ad618990a2916868a61823640af9241bde1fa82476cf01f884c1969` |
| `2.0x/gift_strip.webp` (540 × 157) | 40.4 KB | `948abb8855d6474cad2be860773ac52533a21a651f4425acdbaf2a43626ab928` |
| `3.0x/gift_strip.webp` (810 × 235) | 74.6 KB | `388189c3a4bc2490963b85953e6f59aa5211842a810732e8d2c11726156b65d6` |
| `game_strip.webp` (270 × 78) | 14.6 KB | `fc468ced6f9bf1477797e564f71708439c14c8df41bb66e47b342ce03c1b7e51` |
| `2.0x/game_strip.webp` (540 × 157) | 40.1 KB | `f9a21e67b4c2a4904c2c51f3d12d730af60bebafcbaa5f05e936c615c6648c08` |
| `3.0x/game_strip.webp` (810 × 235) | 74.3 KB | `9a129105ce4a2817c451a97772a38a14775626bd415b31c30f41b8f34867aae1` |

Use: `LiveGlobalStripBar` (`lib/features/live/presentation/widgets/live_global_strip_bar.dart`). The words sit in
`LiveGlobalStripBar.glass` = (0.351, 0.413) – (0.865, 0.781) of the art, measured on the trimmed originals (glass bar
x 0.317 – 0.897, y 0.39 – 0.80; inset to clear the medallion's swoosh, the rounded ends and the crown's and bottom
diamonds). The gift's / game's picture sits at the glass's right end; the ticket is `assets/currency/kabso_ticket.webp`
(D182).
