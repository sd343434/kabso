# The Kabso Team art: the badge (D282, D282c), the frame, picture, covers and entry car (D283)

Owner (D282, 2026-11-05): «اجعلها شارة فريق كابسو بحيث سوف تضع الاسم بالعربي لمن هاتفه عربي وانجليزي لمن هاتفه انجليزي».
Owner (D282c, 2026-11-05): new art that replaces the Kabso Team badge everywhere, for all staff roles
(«بدل شارة فريق كابسو كلها»), with the name in a suitable gold («ولون الخط في داخلها ذهبي مناسب»).

| File | What | Source |
| ---- | ---- | ------ |
| `kabso_team_badge.png` | The Kabso Team badge: a red-and-gold crest (Kabi in a headset and suit, crown, laurels) and an empty red banner with a gold frame and an end cap on the right | Owner-supplied on 2026-11-05 (1920×819 RGBA WebP, transparent). Pixels with alpha below 16 (faint specks across the canvas) were cleared, the art trimmed to the bounds of what remains (1774×809 from x 68, y 7), then scaled with Lanczos to 720×328 px |

It replaces the first D282 art (a green crest and banner, owner-supplied the same day), which is no longer in the app.

The banner is left empty in the file: `KabsoTeamBadge` (`lib/features/live/presentation/widgets/kabso_team_badge.dart`)
writes the team's name in it in the phone's language («فريق كابسو» / "Kabso Team") in a warm gold (#FFD36A) over a thin
dark shadow. The banner's inner area is `KabsoTeamBadge.banner`, as fractions of the trimmed art (left 0.555, top 0.449,
right 0.875, bottom 0.727). It stops before the end cap on the right. If the art is replaced with a different layout,
re-measure it there.

The art is never mirrored in right-to-left layouts (the crest stays on the left, as drawn); only the text follows the
language. The largest drawn size is 40 pt tall (the shift page), so 328 px covers @3x (≈ 8×).

## D283: the team frame, picture and covers (owner-supplied 2026-11-05)

Owner: «فقط سوف يكون له ايقونة التي وضعناها وإطار»; «وهذه الصورة الشخصية الخاص بالادمن والمشرفين بحيث لا يمكن تغييرها»;
«وهذا غلاف الادارة والمشرفين العرب»; «وهذا غلاف الادارة والمشرفين الاجانب، لا يمكن تغييره». A limited Kabso Team
account (MODERATION / SUPPORT / FINANCE, not OWNER) always wears them; none can be changed (CONVENTIONS §10.96.10).

| File | What | Source |
| ---- | ---- | ------ |
| `kabso_team_frame.png` | The locked team avatar frame: a red ring with a gold border, a gold crown with a red gem, stars, red diamond gems, gold laurel wings, the Kabi mascot (headset, suit, thumbs-up) at the lower left and a red shield with a crown and a gear at the bottom; transparent outside and in the round photo window | Owner-supplied on 2026-11-05 (1254×1254 RGBA WebP). Pixels with alpha below 16 cleared, trimmed to the bounds (1248×1248 from x 3, y 0), Lanczos to 768×768 (≥ 3× the largest drawn size, the 160 pt staff Me tab and profile slot, ≈ 4.8×) |
| `kabso_team_avatar.png` | The fixed team picture: the Kabi mascot in a black suit with a red cape, a headset and a tablet | Owner-supplied on 2026-11-05 (1278×1230 RGBA WebP). Alpha below 16 cleared, trimmed (1155×1191 from x 69, y 12), Lanczos to 497×512. The same file is served by the API (`apps/api/assets/staff/kabso_team_avatar.png`, `GET /api/v1/staff/team-avatar.png`) |
| `covers/arab_world.webp` | The cover of the Arab World's staff: the mascot at a desk, «إدارة التطبيق والمشرفون», four feature tiles | Owner-supplied on 2026-11-05, the cover-sized version (1311×1200, made for the 42 % profile cover box), Lanczos to 1200×1098, WebP q86 |
| `covers/international.webp` | The cover of every other region (and staff with no region): the same scene, "App Administration & Moderation", English tiles | Owner-supplied on 2026-11-05, the cover-sized version (1310×1201), Lanczos to 1200×1100, WebP q86 |

**The frame's photo window** is measured from the art itself (`KabsoTeamFrameWindow`, as D265's `VipSvgaClip.window`:
the smallest circle around the transparent opening, rays from the canvas centre to the first pixel with alpha ≥ 40). The
measurement of this file — centre (0.496, 0.500), diameter 0.714 of the art — is also kept as the constants used until
the device's own measurement is ready, and a widget test checks they agree; a new art dropped in at the same path needs
no code change (only the test's constants, if its window differs).

**The picture** is drawn in the window on a red radial background (Kabso red to a deep wine), cropped to the head and
shoulders: a square of 0.68 of the art's width from (0.16, 0.14) (`KabsoTeamLook.picture*`).

**The covers** go by the staff member's first region (`StaffCovers.byRegion`: `ARAB_WORLD` → `arab_world.webp`; any
other region or none → `international.webp`, until the owner sends a region's own cover — add it to the map). They are
2:1 and the 42 % cover box is about square, so the sides are cropped (`StaffCovers.alignment`, slightly to the title's
side: the title stays whole, the mascot's face mostly in); the photo sits at the bottom-start over the tiles.

## D283: the team entry car (owner-supplied 2026-11-05)

Owner: «سيارة دخولية للمشرفين والإدارة».

| File | What | Source |
| ---- | ---- | ------ |
| `kabso_team_entry.svga` | The Kabso Team's entry car: a red sports car with a gold crown grille and the Kabi mascot in a suit and headset, on red light streaks | Owner-supplied on 2026-11-05 (`premium_effect.svga`), unchanged: SVGA 2.0, 3 085 488 bytes (3 115 395 inflated), viewBox 396 × 720, 12 fps, 73 frames (≈ 6.1 s), 73 sprites each one full-frame **opaque JPEG** 396 × 720 (one per frame, no transparency: it covers the live under it while it plays), and one MP3 (`audio`, ID3, 97 531 bytes, frames 0–73, 6 042 ms) |

It plays through the shared SVGA engine (D272 / D272b: read off the UI isolate, the read-ahead window, its own sound
while the app's sound effects are on), bottom-anchored at the screen's full width like the VIP car (D280: about 715 pt
of an 852 pt phone, the top of the live stays visible), once per visible entry «فريق كابسو» (the `staff-join` data
message; never a hidden watch), not again after the live is minimized and opened again. It is the only entrance a
limited staff account has (no VIP or store car, banner or effect).
