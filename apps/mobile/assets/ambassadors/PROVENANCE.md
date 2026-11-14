# Ambassador level icons «سفراء النجوم» (owner-supplied, AI-generated, 2026-11-14, D390)

The owner supplied four medals for the levels of «برنامج سفراء Kabso» (D390, CONVENTIONS §10.179.9), replacing the
names برونزي / فضي / ذهبي / ماسي with the «سفراء النجوم» set. The owner made them for Kabso with an AI image tool; they
are the owner's own art and may enter git (the repository is public, D40). Originals (RGBA WebP) stay outside git:

| Original | Size | sha256 |
| -------- | ---- | ------ |
| `spark.webp` | 1254×1254 | `136898eff224d9e86bc9cb61876adc368856d7abafdd0bbcd188a674593a1058` |
| `star.webp` | 1254×1254 | `e0b7429b9498c0127d23a9abfdcf25e3a671e687c0a2a9abb9eae056b2110fad` |
| `constellation.webp` | 1254×1254 | `cfa8e518644cda49c3608bd457d429c9c1bb088163c3bc96275740b941e1fba7` |
| `galaxy.webp` | 1254×1254 | `1ba4b085413276d75e708985ae84a3bec0d8b57fbd4d6957903f9f3e7cf500b8` |

**Cleaning.** The originals were already cut out (no opaque white backdrop: the corners are alpha 0), but the art's
interior sat at alpha 249–254 and a faint haze (alpha 1–9) lay around it. Each file was flood-filled from the canvas
edges over the background — pixels with alpha < 10, or near-white (every channel ≥ 232) — so only background connected
to the edge goes and the white highlights inside the art stay (white removed: spark 10 px, galaxy 50 px, star and
constellation none); the whitish pixels within 2 px of that background got an alpha from their distance to white with
the white un-mixed out of their colour (no white halo on a dark background); alpha was then remapped (< 10 → 0, ≥ 245
→ 255, linear between). Each was trimmed to the art, centred on a transparent square, resized with Lanczos (Pillow, on
premultiplied alpha) to 256×256 and saved as lossy WebP with alpha (quality 88, method 6). Checked on black, dark,
white and red backgrounds. No recolour.

| File | Level code | Arabic | English | Badge colours |
| ---- | ---------- | ------ | ------- | ------------- |
| `spark.webp` | `SPARK` (level 1) | شرارة | Spark | orange |
| `star.webp` | `STAR` (level 2) | نجم | Star | gold |
| `constellation.webp` | `CONSTELLATION` (level 3) | كوكبة | Constellation | purple |
| `galaxy.webp` | `GALAXY` (level 4) | مجرّة | Galaxy | cosmic blue |

Used by `AmbassadorBadge` (`features/ambassadors/presentation/ambassador_badge.dart`) on the profile's badge row, the
live person card, the programme page and the ambassador dashboard, and by the panel «السفراء» (imported from this
folder by `apps/admin/src/ambassador-levels.tsx`; no copy).
