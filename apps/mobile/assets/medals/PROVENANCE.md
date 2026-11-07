# The medals page art (D291; D300)

**Owner-supplied, 2026-11-06** (Kabso's own art, authorized for git by the owner: «استخدم هذول في صفحة الميداليات
للدارك مود ولايت مود»). Not taken from the third-party reference screenshot behind D291's layout idea (that image stays
out of git, D40). Used by `lib/features/medals/presentation/medal_stage.dart` and `medals_screen.dart`.

| File | Source (owner's upload) | Use | Processing |
| ---- | ----------------------- | --- | ---------- |
| `medals_stage_pedestal.webp` | `400.webp` 1774 × 887 RGBA | the stage pedestal in the **dark** theme (gold / purple, light burst, sparkles); the worn medals stand on its top surface | resized to 1200 × 600 (Lanczos), WebP q88, alpha kept (alpha q95); 268 KB → 136 KB |
| `medals_stage_pedestal_light.webp` | `405.webp` 1199 × 1312 RGBA (owner, 2026-11-06: the light-mode pedestal, gold / white / violet) | the stage pedestal in the **light** theme (`medals_stage_pedestal.webp` stays for dark) | cropped to the pedestal (x 0–1199, y 291–921, padded 30 px each side so the top disc's centre sits at 57 % of the height, like the dark one), resized to 1200 × 600, WebP q82, alpha kept (alpha q75); 1199 × 1312 → 1200 × 600 |
| `medal_card_frame.webp` | `401.webp` 1086 × 1448 RGBA | the frame of each grid card (crown on top); inner transparent area x 14.3–85.7 %, y 21–85 % | resized to 600 × 800, WebP q88, alpha kept; 305 KB → 106 KB |
| `medal_wealth_l1.webp` … `medal_wealth_l6.webp` | `406.webp` (identical to the first upload `404.webp`) gold lion, red · `407.webp` silver wolf, blue · `408.webp` violet howling wolf · `409.webp` gold and violet lion · `410.webp` eagle, blue, «1 BILLION» · `411.webp` green and gold dragon, «3 BILLION» — each 1254 × 1254 RGBA (owner, 2026-11-06) | the six levels of «ملوك الثروة» / Wealth Kings (`medal_levels.icon_asset` `medal_wealth_l1` … `_l6`; the medal's own `iconKey` `medal_wealth_kings` shows level 1's art) | each resized to 512 × 512 (Lanczos), WebP q86, alpha kept (alpha q95); 383–454 KB → 77–103 KB |
| `medal_lucky_l1.webp` … `medal_lucky_l4.webp` | `412.webp` blue gift, silver frame · `413.webp` violet gift, lilac frame · `414.webp` red gift, gold frame · `415.webp` crystal / opal gift, gold frame — each 1254 × 1254 RGBA (owner, 2026-11-06) | the four levels of «سيد الحظ» / Lucky Master (`medal_levels.icon_asset` `medal_lucky_l1` … `_l4`; the medal's own `iconKey` `medal_lucky_master` shows level 1's art) | each resized to 512 × 512 (Lanczos), WebP q86, alpha kept (alpha q95); 327–419 KB → 65–98 KB |
| `medal_content_school_l1.webp` … `medal_content_school_l4.webp` | **Owner-supplied, 2026-11-07** (D300): `437.webp` blue and silver shield, clapperboard and camera, a star on the ribbon · `438.webp` violet and silver, clapperboard, camera and mic · `439.webp` red and gold with a crown, clapperboard, camera and mic · `440.webp` red and gold with a crown and crystal wings — each 1312 × 1199 RGBA, transparent background | the four levels of «مدرسة المحتوى» / Content School (`medal_levels.icon_asset` `medal_content_school_l1` … `_l4`; the medal's own `iconKey` `medal_content_school` shows level 1's art). No number on the art (D291) | trimmed to the opaque area (alpha > 8), centred on a transparent square, resized to 512 × 512 (Lanczos), WebP q86, alpha kept (alpha q95); 289–506 KB → 70–98 KB |
| `medal_dares_player_l1.webp` … `medal_dares_player_l4.webp` | **Owner-supplied, 2026-11-07** (D300): `441.webp` blue and silver shield, crossed gavels · `442.webp` violet, with a crown · `443.webp` gold and emerald, with a lion and wings · `444.webp` gold and ruby, with a lion and wings — each 1254 × 1254 RGBA, transparent background | the four levels of «لاعب الأحكام» / Dares Player (`medal_levels.icon_asset` `medal_dares_player_l1` … `_l4`; the medal's own `iconKey` `medal_dares_player` shows level 1's art). No number on the art (D291) | trimmed to the opaque area (alpha > 8), centred on a transparent square, resized to 512 × 512 (Lanczos), WebP q86, alpha kept (alpha q95); 339–448 KB → 72–106 KB |
| `medals_bg_light.webp` | `402.webp` 941 × 1672 RGB | the full-page background in the light theme (cover, top-aligned) | size unchanged, WebP q86; 79 KB → 59 KB |
| `medals_bg_dark.webp` | `403.webp` 941 × 1672 RGB | the full-page background in the dark theme | size unchanged, WebP q86; 77 KB → 58 KB |

sha256 (bundled files):
- `medal_dares_player_l1.webp` b83ef1fb1e55c4050d0779752e4f92be7f5d0cc3204e69906cd791936f113b9a
- `medal_dares_player_l2.webp` 2ec5866702c4a37445eb1a992c894923a427e3b51991dc202b19daae7953b7ba
- `medal_dares_player_l3.webp` efafc21bf2fdc8e2c9813ffc8307efbea7a8471eba817982bd044251be5771d1
- `medal_dares_player_l4.webp` 9a9450ea66be495060fe1f5c158aa999c0072989df6652af442184d5f1c4fc46
- `medal_content_school_l1.webp` 44506c08aeb4bea2d991e1c4e0d0c4e436f6a4a8a9bcd3b15e7532053c35600a
- `medal_content_school_l2.webp` 8270812b6068d61bdb8bdafafaf3e5d98f89f7277714a65b9c5b03a297b2de89
- `medal_content_school_l3.webp` 50237ab51b8639dbcc11d69b72c43e042af9ea832a6503dfe81ec834326d5d5e
- `medal_content_school_l4.webp` 99d7435e387cee2aef2ab2004482d458610f7336100011ab0992b2d9904d5c3c
- `medal_lucky_l1.webp` 5a382229bc711e29191e8b3c4bb7c208d4f260b5d052a13ec95e79677ae18996
- `medal_lucky_l2.webp` 774e5a7747299530101106e08b3e4907cb7bc2dca368106b454739ffe11b4c57
- `medal_lucky_l3.webp` 99bc4478331e93ceb94343852f44774f63a79e4458e7ed8725d577cd8e53515b
- `medal_lucky_l4.webp` 5c4c942cc1b6a671f4d43300bfaadab85240a0b2f65091b8a1025d2969f5b9fd
- `medals_stage_pedestal_light.webp` 9d13e4597d01768cc764b2c84ac07d7ceb513cb0e05b4fa7f8be5f5a28377464
- `medal_wealth_l1.webp` e34af0c4c9bc165049fe482f4e33439130e87b93a7354dbc1722594adcb71596
- `medal_wealth_l2.webp` 01bb4b118582e3728213e01a9141dff8c0fb81a404aa2b24ed92696a67976014
- `medal_wealth_l3.webp` 7ffa9ad44c8a12cdfa27ae99001f027f27a66bccaa99e119c60ba6e6462049c1
- `medal_wealth_l4.webp` 136023ba79d0f5caf876a65f74ecfcb511f4c88826036232c7b4c7514a4cd2b9
- `medal_wealth_l5.webp` 9d64d8c2453303648f48f91cd73fa5f6dedb77d1ca07189d4b5e1d433b56142f
- `medal_wealth_l6.webp` b148637cdafe7bc9367d694a5e5a5fdd6b56b7712a9627702eb774f180bb8e62
- `medals_stage_pedestal.webp` 328dfa0a38265f0eda9378dc290f3489d4a496a92cb12f6445f4188bc92a9df4
- `medal_card_frame.webp` 1eaed89f78e4af7e3435e76546abdc80340b8d6eae9b7e3cabc81d1ba5d8eff8
- `medals_bg_light.webp` 5e2ee85ad38bb44e445594bfe5339fa95ab1da11047cc50f573b257cb1c70587
- `medals_bg_dark.webp` 98d01db1cbbcaec9b1ac9db5fa2a06da40b37147d7f56b336af147c1df2f1356
