# CP seat frames and their animation (D111, D113)

When two CP partners sit on adjacent audio-room seats, the app joins them
(`lib/features/live/presentation/go_live/live_cp_seats.dart`, `live_seat_tiles.dart`):
a soft band behind both pictures (D111), the couple's **level frame** around them and a light
animation of small parts (D113, `live_cp_seat_fx.dart`).

## Source art

**Owner-supplied, 2026-10-26** (Kabso's own CP art, not taken from a reference screenshot or
another product). One frame per CP level, each a wide image with two transparent round holes:

| Source file (`source/`, not bundled) | CP level | Tier | Motif |
| ------------------------------------ | -------- | ---- | ----- |
| `level_1.webp` (710 × 257) | 1 | ثنائي متحمّس / Eager couple | CP heart with wings |
| `level_2.webp` (713 × 260) | 2 | ثنائي فضّي / Silver couple | planet and moon |
| `level_3.webp` (700 × 248) | 3 | ثنائي ذهبي / Gold couple | diamond heart with wings |
| `level_4.webp` (695 × 250) | 4 | ثنائي ماسي / Diamond couple | castle heart |
| `level_5.webp` (730 × 259) | 5 | ثنائي أسطوري / Legendary couple | cherry tree |
| `level_6.webp` (693 × 269) | 6 | ثنائي أبدي / Eternal couple (D113) | swans |

The sources are kept in `source/` (a subfolder, so `pubspec.yaml`'s `assets/live_cp_seats/`
does not bundle them) so the pieces can be cut again when the owner changes the art.

## Pieces the app uses (cut from the sources)

The holes in each frame are ~2.7 hole widths apart, the seats' pictures much closer, so the
frame is never stretched across the seats. Each source is cut into three pieces with the
measured hole geometry (centre and diameter of each hole):

- `level_<n>_ring_l.webp` — everything around the **left** hole (the disc of 1.36 hole radii,
  the column above and below the hole for the crown and the bottom heart, and everything
  outward of the hole centre);
- `level_<n>_ring_r.webp` — the same around the **right** hole;
- `level_<n>_center.webp` — the rest between the holes (the centre motif), with a soft
  vignette on its corners to drop ribbon fragments.

Cuts are feathered (2 px), each piece trimmed to its ink, WebP quality 88. The cutter is a
small Python script (PIL + NumPy) kept outside git by the CTO; its output also writes
`lib/features/live/presentation/go_live/live_cp_seats.frames.dart` (each piece's size, hole
centre and hole diameter in pixels). Re-run it whenever a source changes; do not edit the
pieces or the table by hand.

In the app each ring is drawn behind its partner's picture, scaled so the hole is exactly the
picture; the visually left partner wears the left ring (Arabic mirrors the placement, never
the art). In rows a ring shows only within its tile and above the name, fading where it is
cut; in the circle it is drawn whole, shrunk evenly where it would reach another seat. The
centre piece is the ornament: 62 pt, upright, exactly between the two pictures, with the
partners' names and badges painted above it.

## Animation parts (`fx/`)

**Owner-supplied, 2026-10-26**, keyed from the same art sheet ("use the small pieces as
animation around the couple"). Small transparent WebP files:

| File | Use (CP level it starts at) |
| ---- | --------------------------- |
| `sparkle_pink.webp`, `sparkle_small.webp` | twinkle above the rings (1) |
| `heart_pink.webp` | twinkles above the ornament (1–3) |
| `heart_glow.webp` | glows above the ornament (4+) |
| `planet.webp` | bobs above the pair (2, the planet frame) |
| `heart_violet.webp`, `sparkle_gold_small.webp` | twinkle (2) |
| `butterfly_pink.webp` | flutters over the pair (3) |
| `sparkle_gold.webp` | twinkles (3) |
| `petal_a.webp`, `petal_b.webp` | drift down the gap (4) |
| `butterfly_lilac.webp`, `petal_c.webp`, `swirl_l.webp`, `swirl_r.webp` | a second butterfly, a third petal, swirls swaying by the ornament (5) |
| `platform.webp`, `sparkle_big.webp`, `sparkle_pink2.webp` | a glowing platform under the ornament, more sparkles (6) |

A part whose path would touch a picture, a name or a mic badge, or leave the pair's tiles, is
left out for that pair; at most 12 parts per pair, 6 when the room shows more than 4 pairs.
Reduced motion (`MediaQuery.disableAnimations`) holds the parts still.
