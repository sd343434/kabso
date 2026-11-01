# D220 — the in-live person card: reference spec and fidelity notes

Owner, 2026-11-01: «اريد تصميم مطابق لبطاقة التعريفية عندما يضغط شخص على شخص في بث», then «لا صورة شخصية اجعلها فوق
الاسم لاننا من فوق سيكون يظهر باقي البث». The reference is a third-party marketing image (a gallery screenshot of a
VIP-set design, two phones; the RIGHT phone is used, the left one is a mirror). It stays in scratch (D40). Only the
card's **layout and proportions** are taken; its frame/wings art, mascot and photos are not copied, nor any name.

## Gate A — the reference

| Item | Value |
| ---- | ----- |
| File | scratch only, sha256 `cb15dd48852ffe20ced549bab406ef8e018b65cb8db6480589cb57eb11fe5cff`, 2000×1299 RGB WebP |
| Region used | the right phone's white card, from the REPORT row down: 385×360 px at (990, 690) |
| Viewport / DPR | unknown: a phone photographed in perspective inside a browser page. Screen ≈ 380 px wide for an assumed 393 dp → **≈ 0.97 px/dp (E)** |
| Locale | English LTR (the app is Arabic RTL first) |
| State | someone else's card, not followed |

Every number below is **E** (perspective, scaling, JPEG/WebP artefacts); colours are **M** samples
(`measure.py sample/palette`) of a compressed image, so ±5 per channel.

## Regions (top → bottom, crop px; dp ≈ px / 0.97)

| Region | Reference | Implementation (dp) |
| ------ | --------- | ------------------- |
| Top row | REPORT (flag + caps) at the reading start, y≈35 | «إبلاغ» + flag first in the tools row; points / host tools after it; ⋯ (report, block) and mutes at the end |
| Picture | (none on the card: a full-height photo above) | owner change: 84 dp round picture centred on the sheet's top edge; a 3 dp white ring, or the worn frame |
| Name | centred, dark, ≈20 dp, y≈77 | 20 sp w700, one line, ellipsis; taps open the profile |
| ID | «ID:…», grey, ≈12 dp, y≈103 | «ID: username» 12 sp, `#9A9BA5`, always LTR, copy on tap (premium IDs keep their badge) |
| Badge pills | one centred row of small pills, y≈135, ≈16–18 dp high | one centred row (scrolls sideways when long): role, charm level, other levels, recharge / agent badges, chosen medals |
| Numbers | four columns, number ≈19 dp bold over a grey label, y≈178/207 | owner follow-up: equal `Expanded` cells, short Latin numbers (`KFormat.compactLatin`: 999, 1.2K, 1.5M, 1B, LTR-isolated) 17 sp w700 over 11 sp grey, a 1 × 22 dp divider in the theme's `border` token between shown numbers; hidden ones are absent and the rest share the row |
| Pills | orange showcase pill (≈168 px) + purple «Gift Wall» (≈113 px), ≈37 px high, r≈8 | 3 : 2, 40 dp high, r 10: orange `#FFC596→#FF9466` (family | couple), purple `#C77BFB→#9445E6` gift wall |
| Actions | cyan Follow (≈151 px), round gift (≈38 px), outline Chat (≈160 px), ≈48 px high | 11 : 48 dp : 9, 48 dp high. Owner follow-up: Follow filled in the theme's brand red (`primary`/`onPrimary`, white ≥ 4.5:1), followed → neutral outline «إلغاء المتابعة» that asks first; the gift is the app's main gift icon (`assets/live_bar/bar_gift.png`) at 30 dp inside a 48 dp circle as high as the pills (owner: «اجعل ايقونة الهدايا بداخل دائرة»), neutral fill (`surface` light / `surfaceOverlay` dark) and the `border` outline; Chat outline in the `border` token |
| Sheet | white, rounded top | white (light) / `surfaceRaised` (dark), top radius 22 |

Colours measured on the reference: follow `#00E3D9`/`#05D7E4`, gift wall `#CE7EFD`/`#C475FB`, showcase
`#FFBC8A`…`#FF9165`, sheet `#FFFFFF`.

## Kept from the earlier card (D86 onward)

Moderation (kick, chat mute, moderator, seat mic, points), ⋯ report and block, mention, the host's traffic card
and seat invite (a row of small outline chips above the actions, only when they apply), copy the ID, the agents'
code lines, the bio (two lines), the profile card header on the top edge (SVGA, still under reduced motion), the
honest loading / error states, and «تعديل الملف» instead of follow / gift / chat on your own card.

## Deliberate differences from the reference

- No hero photo (owner change); the live shows above the sheet.
- The orange pill holds Kabso's family and couple (what the card showed there), not a VIP tag.
- The gift wall has no API for a person yet: a tap says it is coming (as before).
- Text on the showcase pill is dark brown (white on light orange fails contrast).
- Owner follow-up: Follow is brand red, not the reference's cyan; once followed it reads «إلغاء المتابعة»; the
  gift button and the DM composer's gift button use the live bar's gift art. In dark mode the number dividers
  use the strong border token at 60 % (a little more visible).
- Owner follow-up (2026-11-01, «الارقام كبيرة اكتب ١ مليون هكذا 1M … وبين كل فئة مثل خط بلون رمادي صغير»): the card's
  numbers are short Latin in both languages (1.5M, 59.4K, 999) — other screens keep the localized compact words —
  smaller, with thin grey dividers.
- No country flag: `PublicProfile` has no country on this base (D218 adds one on its own branch).

## Verification

Headless renders of the real `LiveRoomScreen` (audio room, fake repositories) — goldens
`room.person_card*` — and the advisory comparison with the resampled reference crop
(`cross_environment`: MAE 33.7, SSIM 0.71, changed@16 41 % — fails, expected: different layout parts above,
perspective and content). Not a device capture.
