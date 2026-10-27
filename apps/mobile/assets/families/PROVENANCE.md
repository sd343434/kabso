# Family art (slots, D116; files D125)

Kabso's own family art, **owner-supplied 2026-10-26** (D125): the owner gave these files for the
families screens (the lion and crown are Kabso art). Nothing here or in the screens comes from the
owner's third-party style board (kept outside git, look only). Slots still empty draw gradients and
shapes and reuse Kabso's D84 leaderboard art (`assets/leaderboard/`).

The empty places in each picture (the circle for the emblem, the panel for the text) are measured in
the image's own pixels (a flood fill and a least-squares circle fit on the files) and kept in
`FamilyArt` (`lib/features/families/presentation/family_widgets.dart`, `FamilyArtSlots`). Replacing a
file with a different layout means measuring it again.

When a file lands here: set the matching slot in `FamilyArt` and add a row below.

| Slot (`FamilyArt`) | Where it shows | Suggested size |
| ------------------ | -------------- | -------------- |
| `hero` | Family page hero when the family has no cover (full width under the top bar; never mirrored) | 1860 × 845, opaque |
| `podiumCards[0..2]` | Families list podium cards, places 1, 2, 3 | 640 wide, transparent |
| `activityMonthly` | Families list, "Family activities" card (monthly ranking) | 570 × 300 (1.9 : 1) |
| `levelCrown` | The "Level N" chip in the hero | 96 × 96, transparent |
| `toolIcons[0..4]` | Tools: manage, join requests, competitions, family shop, tasks | 256 × 256, transparent |

| File | What | Notes |
| ---- | ---- | ----- |
| `hero_banner.webp` | Default family cover: red curtains, film strip, a gold lion shield with a crown, an empty dark-red panel (left) and an empty gold ring (right) | Owner-supplied 2026-10-26 (D125). 1860 × 845 WebP. Ring centre (1625, 475), emblem radius 118; panel text area (400, 235)–(1110, 560) |
| `podium_1.webp` | 1st place card: red and gold, crown, wings | Owner-supplied 2026-10-26 (D125). 640 × 855, transparent. Circle (320, 293) r 114; panel (140, 492)–(500, 690) |
| `podium_2.webp` | 2nd place card: blue and silver | Owner-supplied 2026-10-26 (D125). 640 × 919, transparent. Circle (320, 292) r 136; panel (172, 520)–(468, 752) |
| `podium_3.webp` | 3rd place card: rose gold (the circle is transparent) | Owner-supplied 2026-10-26 (D125). 640 × 923, transparent. Circle (320, 285) r 130; panel (168, 506)–(472, 740) |
| `activity_monthly.webp` | Monthly-ranking activity card: the left part of the owner's families banner (podium, winged shield, crowns, red carpet), no lettering | Owner-supplied 2026-10-26 (D127): cropped from the owner's `banner_families` (1500 × 500, x 0–950 — the part without its baked-in Arabic title) and resized to 570 × 300 WebP q86. The card's title is the app's own localized text. |
