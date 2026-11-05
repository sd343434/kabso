# The Kabso Team badge «فريق كابسو» (D282)

Owner (D282, 2026-11-05): «اجعلها شارة فريق كابسو بحيث سوف تضع الاسم بالعربي لمن هاتفه عربي وانجليزي لمن هاتفه انجليزي».

| File | What | Source |
| ---- | ---- | ------ |
| `kabso_team_badge.png` | The Kabso Team badge: the gold-and-green crest (crown, three people, laurels, star) and an empty green banner with a gold frame | Owner-supplied on 2026-11-05 (2000×667 RGBA WebP, transparent). Pixels with alpha below 16 (faint stray specks) were cleared, the art trimmed to the bounds of what remains (1519×652 from x 239, y 7), then scaled with Lanczos to 600×258 px |

The banner is left empty in the file: `KabsoTeamBadge` (`lib/features/live/presentation/widgets/kabso_team_badge.dart`)
writes the team's name in it in the phone's language («فريق كابسو» / "Kabso Team"). The banner's inner area is
`KabsoTeamBadge.banner`, as fractions of the trimmed art (left 0.540, top 0.411, right 0.883, bottom 0.725); if the
art is replaced with a different layout, re-measure it there.

The art is never mirrored in right-to-left layouts (the crest stays on the left, as drawn); only the text follows the
language. The largest drawn size is 40 pt tall (the shift page), so 258 px covers @3x (≈ 6.4×).
