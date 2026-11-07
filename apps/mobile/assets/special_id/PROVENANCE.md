# Special-ID art (owner-supplied)

## D299j (2026-11-07): the four tiers' medals and plates

Supplied by the owner on 2026-11-07 as Kabso's premium username (special ID) art, one set per tier —
LEGEND («اسطوري»), RUBY («ياقوتي»), GOLD («ذهبي») and SILVER — each a transparent medal, a transparent plate
(2000 × 667) and a combined reference image (`<tier>_full`), with the owner's instruction to shorten the plate
so the shortest one holds 3 (LEGEND), 4 (RUBY), 5 (GOLD) or 6+ (SILVER) characters. The originals stay
outside git. What is bundled, as Flutter resolution variants (1x, `2.0x/`, `3.0x/`):

| File | Source | Processing |
| ---- | ------ | ---------- |
| `<tier>_medal.png` (44 / 88 / 132 px tall) | LEGEND: `legend_medal.webp` (1254²). RUBY / GOLD / SILVER: the medal cut out of `<tier>_full.webp` (the owner's standalone `<tier>_medal.png` is only 128 px; it was used as the cut-out's shape) | trimmed to its alpha bounds, resized |
| `<tier>_plate_{left,wing_left,gem,wing_right,right}.png` (40 / 80 / 120 px tall) | `<tier>_plate.webp`, trimmed to its alpha bounds | cut into slices at x (source px): LEGEND 670 / 905 / 1080 / 1320, RUBY 505 / 930 / 1070 / 1495, GOLD 535 / 925 / 1075 / 1458, SILVER 478 / 920 / 1080 / 1522; LEGEND's gem slice has its glass rows 178–446 rebuilt from the clean glass beside it (a faint smudge in the art's centre) |
| `<tier>_plate_fill_{left,right}.png` (2 px wide) | one column of `<tier>_plate.webp` at the first / last cut | stretched as plain frame and glass for long IDs |

`KSpecialUsername` (D299j) draws the ends and the gem unscaled, tightens the two arcs beside the gem for short
IDs and stretches the fills for long ones; the ID is drawn in code. The cut script lives outside git.

## D146 (2026-10-27): retired

The first set (`kabso_special_id`: `medal_<tier>.png` at 64 / 128 px and a pill drawn in code) was replaced by
the D299j art for all four tiers; its files were removed.
