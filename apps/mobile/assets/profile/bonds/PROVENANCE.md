# Profile bond medallions (family, couple, medals)

Supplied by the owner on 2026-11-01 (one image, 2000×667 px, transparent
background, sha256 `3cc58053…59f6fc67`): three glossy pills — yellow with a
shield / crown / wings medallion, orange with a flame, purple with a trophy
and laurel — as Kabso's own art («اجعلها بهذه الطريقة بشكل مطابق ١٠٠٪», D218).
Owner-supplied; not third-party. The source image is not in the repository.

The owner then asked for rectangles with slightly rounded corners («مستطيل
بحواف مستديرة قليلاً»), so only the medallions are assets now; the tile body
is painted in code (`BondArt` in `lib/features/profile/profile_bonds.dart`)
from colours sampled on each pill. The full pill cut-outs of the previous
commit were removed (unused).

| File | Bond | Cut | Size | sha256 |
| ---- | ---- | --- | ---- | ------ |
| `family_shield.webp` | العائلة | D292: the owner's family shield (below) | 512×445 | `43cac787…92854b13` |
| `couple_shield.webp` | العلاقة | D292: the owner's couple shield (below) | 512×443 | `838eb9c6…2d2a95df` |
| `medals_shield.webp` | الميداليات | D292: the owner's medals shield (below) | 512×473 | `c046b390…4ab68583` |

Cut along the medallion's circle from the art's own alpha (multiplied by a
circular mask); pixels unchanged, WebP with alpha, quality 94.

## Sampled body colours (`measure.py sample`, pixels of each pill crop)

| Pill | top (120, 58) | middle (120, 142) | bottom (120, 250) | by the medallion (340, 145) | light rim (120, 22) | dark rim (120, 262) |
| ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| family | `#FFDB1D` | `#FCC302` | `#FBCE09` | `#F7A902` | `#FBF8C5` | `#F4B50B` |
| couple | `#FC7516` | `#FA5101` | `#FE6205` | `#E83C00` | `#FDEE7C` | `#F94E06` |
| medals | `#D054F9` | `#982FF5` | `#C149FC` | `#751EE8` | `#D8C2F4` | `#9B3AEC` |

## Family shield (D292)

Supplied by the owner on 2026-11-06 (one image, 1536×1024 px RGBA, transparent background, sha256
`12f9ce16…4d68c6b2`): a gold-and-purple shield with a crown, three gold people, laurels and an **empty** purple
ribbon — Kabso's own art, owner-supplied, not third-party («اجعلها أيقونة العائلة واكتب العائلة في الشريط
البنفسجي، وفاميلي في حال كانت لغة إنجليزية»). The source image is not in the repository.

`family_shield.webp`: trimmed to its opaque bounds (alpha > 20: x 179–1357, all rows → 1178×1024), scaled to
512×445 (Lanczos), WebP with alpha, quality 90. It replaces the earlier family medallion (`family_medal.webp`,
removed: nothing else used it). The ribbon is left empty in the asset; the app writes «العائلة» / "Family" on it
live, in the box measured on the 512×445 asset (purple band, x 140–372, y 300–345 → fractions 0.273–0.727,
0.674–0.775).

## Couple shield (D292)

Supplied by the owner on 2026-11-06 (one image, 1536×1024 px RGBA, transparent background, sha256
`d79922f6…75af7147`): a red heart with a gold crown, two gold rings with a ruby, laurels and an
**empty** red ribbon — Kabso's own art, owner-supplied, not third-party («اجعلها أيقونة العلاقة، واكتب العلاقة في
الشريط الأحمر، وفي حال كانت لغة إنجليزية اكتبها بالإنجليزي»). The source image is not in the repository.

`couple_shield.webp`: trimmed to its opaque bounds (alpha > 20: x 176–1345, y 0–1011 → 1169×1011), scaled to
512×443 (Lanczos), WebP with alpha, quality 90 (sha256 `838eb9c6…2d2a95df`). It replaces the earlier couple
medallion (`couple_medal.webp`, removed: nothing else used it). The app writes «العلاقة» / "Couple" on the ribbon
live, in the box measured on the 512×443 asset (red band under the top gem, x 110–400, y 302–345 → fractions
0.215–0.781, 0.682–0.779).

## Medals shield (D292)

Supplied by the owner on 2026-11-06 (one image, 1312×1199 px RGBA, transparent background, sha256
`f2cda848…6cd3754f`): a green-and-gold shield with a crown, three medals (silver, gold, bronze), laurels and an
**empty** green ribbon — Kabso's own art, owner-supplied, not third-party («اجعلها أيقونة الميداليات، واكتب
الميداليات في الشريط الأخضر، وفي حال كانت لغة إنجليزية اكتبها بالإنجليزي»). The source image is not in the
repository.

`medals_shield.webp`: trimmed to its opaque bounds (alpha > 20: x 11–1301, y 4–1196 → 1290×1192), scaled to 512×473
(Lanczos), WebP with alpha, quality 90. It replaces the earlier medals medallion (`medals_medal.webp`, removed:
nothing else used it). The app writes «الميداليات» / "Medals" on the ribbon live, in the box measured on the 512×473
asset (green band under the top gem, x 120–392, y 340–372 → fractions 0.234–0.766, 0.719–0.786). The tile border
uses the ribbon's green, sampled `#036B13` at (300, 355).

