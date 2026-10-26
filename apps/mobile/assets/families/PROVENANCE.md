# Family art (slots, D116)

No files yet. The owner will supply Kabso's own family art; until then the families screens
(CP-022) draw gradients and shapes and reuse Kabso's D84 leaderboard art (`assets/leaderboard/`:
the winged crowned podium frames and the gold, silver and bronze rank shields). Nothing here or in
the screens comes from the owner's third-party style board (kept outside git, look only).

When a file lands here: add `assets/families/` to `pubspec.yaml`, set the matching slot in
`FamilyArt` (`lib/features/families/presentation/family_widgets.dart`) and add a row below.

| Slot (`FamilyArt`) | Where it shows | Suggested size |
| ------------------ | -------------- | -------------- |
| `heroBackground` | Family page hero, behind the top bar, when the family has no cover | 1080 × 600, opaque |
| `podiumCards[0..2]` | Families list podium cards, places 1, 2, 3 (banner with a pointed bottom) | 360 × 560, transparent |
| `levelCrown` | The "Level N" chip in the hero | 96 × 96, transparent |
| `toolIcons[0..4]` | Tools: manage, join requests, competitions, family shop, tasks | 256 × 256, transparent |

| File | What | Notes |
| ---- | ---- | ----- |
