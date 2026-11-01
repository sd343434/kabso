# D221 — live interruption / ended card: reference spec

Owner's own design proposal «اقتراح عند انقطاع البث وانتهائه» (2026-11-01). The image stays in
scratch (D40): a 1200×1311 px card render on a dark red backdrop, no phone frame,
sha256 `7cdf9e95deaab45642cc69b49a917560ba7f66685e48cb52f96c11b97ead1b66`. Arabic RTL,
state: a live that ended after the host's connection was lost, host without a photo
(silhouette), the viewer not following.

**Scale (E).** The reference has no viewport. Assumed: the card's width (976 px, x 112…1088)
is the current `KLiveInterruption` width on a 393 dp screen (`maxWidth` 320 dp), so
**1 dp = 3.05 px**. Every dp value below derives from that assumption. M = measured in pixels,
E = estimate.

| Region | Reference (px) | Spec (dp, card coordinates) | Tag |
| --- | --- | --- | --- |
| Card | 112…1088 × 157…1163 (976×1006) | 320 × 330, radius 24 (corner meets the top edge 70 px in) | M / E scale |
| Body | wine gradient: top-left (49,17,30), centre (45,9,21), right (25,12,24); bottom bloom R≈90…170 | linear TL→BR `#321220 → #2A0A16 → #1A0C18`, red bloom along the bottom 22 % | M |
| Edge | top (255,247,255), sides ≈(90,79,92), bottom (250,140,150) | 1 dp gradient: white-pink → dim white → red-pink | M |
| Light wave | crest from x 180 → peak x 360, y 1102 → back to the edge x 560 | crest 22 → 81 (20 dp above the bottom) → 147 dp | M |
| Faint outer ring | top y 199 | Ø 107, top 12 (14 measured; 2 dp up to remove a 5 px global shift), 1 dp red 30 % | M |
| Ring | Ø 264 outer, 6 px stroke, centre (600, 362) | Ø 86, 2 dp, centre 67 dp from the top | M |
| Picture | Ø ≈250 | Ø 80 | M |
| Sound waves | bars 16 px apart, 6 px wide, heights 9…85 px, x 334…479 / 721…866 | 9 bars per side, 2 dp, 54…98 dp from the centre, 2…24 dp tall, fading outwards; symmetric | M (outer two E) |
| Reason badge | Ø 80 at (600, 401) | Ø 26, 13 dp under the ring's centre, red gradient, white icon | M |
| Status pill | 488…711 × 448…514 | 22 dp tall, centre 105 dp from the top, padding 9, 11.5 dp w700, the dot at the reading start | M |
| Host name | gold (246,198,95), 556…598; crown 43×37 px, 8 dp before | 14.5 dp w700 `KBrandColors.gold`, centre 138 dp; crown 15 dp at the reading start | M |
| Title | white, 626…692 | 22 dp w700 (glyph height matched), centre 165 dp | M |
| Explanation | grey (205,200,207), 720…761 | 13.5 dp `textSecondary`, centre 191 dp | M |
| Primary button | 197…1002 × 810…931, radius ≈50 px, `#FC324B → #95010E` | face 264 × 40, top 214, radius 16, red gradient + glow; target 48; icon at the reading start | M |
| Secondary button | 199…1000 × 961…1067, fill (37,29,39), border ≈ white 30 % | face 264 × 36, top 265, radius 16; target 48 | M |
| Bottom padding | 1067 → 1163 | 23 dp under the secondary target (30 under its face) | M |

**Kept from Kabso (not copied).** Readex Pro / Inter, the brand reds (`#E50914`, `#FF3B47`),
`KBrandColors.gold`, Kabso's crown (`AppIcons.crownFilled`), Material icons
(`add_box_outlined`, `replay_rounded`, the D216 reason badges). No assets taken from the image.

**Deliberate differences.**
- Touch targets: the button faces are 40 / 36 dp as measured, inside 48 dp targets.
- The reference's back label «العودة إلى البث» is ambiguous; the card keeps the real action and
  label «العودة إلى البثوث» (back to the live rooms).
- The badge keeps D216's reason→icon mapping (connection lost = `wifi_off`, the reference
  shows a muted microphone).
- The crown shows only for a status the app really knows; no production caller has one yet.
