# Daily recharge badges (owner-supplied, AI-generated, 2026-10-30, D187)

The owner supplied five badges for the daily recharge tiers «شارات الشحن اليومي» (a zip named "Daily Coin
Recharge Badges"; made for Kabso with an AI image tool and approved by the owner; owner: these are Kabso's own
assets and may enter git). Originals (RGBA PNG) stay outside git:

| Original | Size | sha256 |
| -------- | ---- | ------ |
| `01_bronze_coin_pouch.png` | 471×448 | `2bd36631e0e5c8f49b4ad591748be48bc57e3c580a995998b8f334dd057314e3` |
| `02_silver_blue_coin_chest.png` | 505×499 | `c9ed27b22d3f44284feb3b29c908e78afee6b7d41975c25f2f3e0985063f12ab` |
| `03_gold_red_coin_chest.png` | 526×488 | `085dd84c1cde063570ccdb7b7a394dd52cbcafb3ba876b2e38a38e684e30b560` |
| `04_purple_coin_vessel.png` | 609×524 | `723ad5345fd3e54cf3e1bde502584b9ad3843f4e5b7aab055f93b5986bcc4f31` |
| `05_royal_red_crystal_vault.png` | 627×586 | `67b209fc76853cf040f63dbbd784dce18a359b4b080fae57fb70e90091b3d3bd` |

**Cleaning.** Three originals carry fragments of a neighbouring badge (cut from a sheet). Every file was split
into 8-connected alpha components; the largest is the badge, and every other component lying **outside the
badge's bounding box** was cleared (inside it: the art's own sparkles, kept — 01 has two):
02 a blue fragment at the left edge (x 10–74, y 130–200) and a 7-px speck under it; 03 two gold fragments at
the bottom left (x 10–76, y 435–477; x 167–189, y 457–480); 05 two red fragments at the top right (x 418–567,
y 7–70); 01 and 04 had none. Then each was trimmed to the badge, centred on a transparent square, resized
with Lanczos (Pillow) to 192×192 and saved as lossy WebP with alpha (quality 88, method 6). No recolour.

| File | Tier (coins recharged in one day, default) | Original |
| ---- | ------------------------------------------ | -------- |
| `tier_1.webp` | 1 000 000 – 10 000 000 | bronze coin pouch |
| `tier_2.webp` | 10 000 001 – 20 000 000 | silver-blue coin chest |
| `tier_3.webp` | 20 000 001 – 40 000 000 | gold-red coin chest |
| `tier_4.webp` | 40 000 001 – 70 000 000 | purple coin vessel |
| `tier_5.webp` | 70 000 001 and more | royal red crystal vault |

Used by `RechargeTierBadge` (`features/recharge/presentation/recharge_badge.dart`) next to the name in live
rooms, on the profile, the Me hub and the person card (CONVENTIONS §10.50).
