# Support level badges (owner-supplied, 2026-10-30)

Supplied by the owner in chat for «مستوى الدعم» (D169): two AI-generated sheets on a transparent
background — 21 standalone badges in rows of 5/5/5/5 + 1 (1500×1000 RGBA) and the same 21 badges
each on a coloured level bar (1536×1024 RGBA). The sheets themselves stay outside git.

Sliced by alpha (threshold 8) with no other change than trimming and resizing:

- `support_NN.webp` (NN = 01…21, increasing rank, sheet order left→right, top→bottom): each
  badge trimmed to its alpha box, scaled so its longer side is 256 px and centred on a transparent
  256×256 canvas (WebP q90). In the badge sheet rows 2–5 touch at the badges' diamond tips (2–16
  px of contact on the cut row, no overlapping badge bodies); each column was cut at its thinnest
  row and slivers of a neighbour left at a cut edge were cleared (1 px, tier 16).
- `support_pill_NN.webp`: each badge-with-bar trimmed to its alpha box and scaled to 96 px high
  (186–239 px wide). The level number is drawn by the app on the bar.

Default mapping (owner can change): the support ladder has 100 levels (CP-005 preset); tiers 1–20
cover levels 1–5, 6–10 … 96–99 and tier 21 is level 100 alone (`KLevelArt.supportTier`).
