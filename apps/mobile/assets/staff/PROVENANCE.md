# The Kabso Team badge «فريق كابسو» (D282, D282c)

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
