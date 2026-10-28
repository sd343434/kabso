# Special-ID medals (owner-supplied, 2026-10-27, D146)

Supplied by the owner as Kabso's premium username badge (`kabso_special_id`: a Dart sample
`KabsoSpecialId`, the medal PNGs at 64/128/256/512 px, a preview, an animation video and an HTML
demo). Only the medals are bundled, unmodified, renamed to Flutter resolution variants:

| File | Source | Used for |
| ---- | ------ | -------- |
| `medal_<tier>.png` | `medal_<tier>_64.png` (64×64) | 1.0x |
| `2.0x/medal_<tier>.png` | `medal_<tier>_128.png` (128×128) | 2.0x and up (the medal is at most ≈ 41 pt, ≈ 123 px at 3x) |

Tiers: `legend` (rainbow, crowned), `ruby` (Kabso red), `gold`, `silver`. The 256/512 px files,
the preview, the video and the HTML demo stay outside git. The pill is drawn in code
(`KSpecialUsername`, adapted from the owner's sample).
