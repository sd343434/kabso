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
| `family_medal.webp` | العائلة | circle r = 131 px (+1.5 px soft edge) around (513, 144.5) of the family pill crop; 4 px rim margin | 270×270 | `d441ca2a…cc163754` |
| `couple_medal.webp` | العلاقة | circle r = 130.5 px around the couple pill's medallion | 269×269 | `b370f237…dd5d586e` |
| `medals_medal.webp` | الميداليات | circle r = 130.5 px around the medals pill's medallion | 269×269 | `82ea14dd…03e032f2` |

Cut along the medallion's circle from the art's own alpha (multiplied by a
circular mask); pixels unchanged, WebP with alpha, quality 94.

## Sampled body colours (`measure.py sample`, pixels of each pill crop)

| Pill | top (120, 58) | middle (120, 142) | bottom (120, 250) | by the medallion (340, 145) | light rim (120, 22) | dark rim (120, 262) |
| ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| family | `#FFDB1D` | `#FCC302` | `#FBCE09` | `#F7A902` | `#FBF8C5` | `#F4B50B` |
| couple | `#FC7516` | `#FA5101` | `#FE6205` | `#E83C00` | `#FDEE7C` | `#F94E06` |
| medals | `#D054F9` | `#982FF5` | `#C149FC` | `#751EE8` | `#D8C2F4` | `#9B3AEC` |
