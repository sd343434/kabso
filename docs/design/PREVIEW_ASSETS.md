# Preview imagery (KL-056) — development only

AI-generated images used **only** by the debug previews (`lib/features/debug/`, routes registered
when `!kReleaseMode`) through `PreviewPhoto` / `PreviewPhotos`. Production screens never use them:
they show real API media or their honest states (D35/D39).

## Provenance

- **Generator:** Figma AI image generation (`generate_image`, model `gemini-3.1-flash-lite-image`),
  run on 2026-10-19 at the owner's request, in the owner's Figma file
  `jbSTFrUsrTRMAuexoXp8d5` ("Kabso preview imagery (AI, dev-only)", personal team plan). Each image
  is the raw fill of the node listed below, downloaded with `download_assets`.
- **Subjects:** fictional people and places described by text prompts (no reference photos, no real
  people, no brands). Every prompt asked for no text, logos, watermarks or UI overlays.
- **Edits:** `live_gaming` — the first generation drew fake app UI (badges, chat lines) and was
  rejected; the regenerated image showed a small brand-like logo on the headset, which was painted
  out (dark fill + blur, 34×40 px at 683,548). All images were converted to WebP (portrait kept at
  768×1376, landscape capped at 1200 px wide, avatars 512×512). D68 added three square crops of
  existing images (no new generation): `avatar_karim`, `avatar_rania`, `avatar_group`.
- **Licence status:** generated under the owner's Figma plan and subject to Figma's AI terms.
  **Not reviewed for production use** — development previews only. Do not ship them as content,
  as user photos or in store listings without a separate rights review.
- **Size:** ~1.1 MB in total. Note: Flutter bundles declared assets in release builds too; the
  release app does not reference them. Move them behind a dev flavor (or remove them) before
  launch (tracked in PRE_PRODUCTION_CHECKLIST).

## Files

| Asset | Used for | Subject | Figma node | Original | Bundled | Size | SHA-256 |
| ----- | -------- | ------- | ---------- | -------- | ------- | ---- | ------- |
| `assets/preview/avatar_huda.webp` | Preview avatars (circular crop, face centred) | headshot, young woman in a beige hijab | `13:2` | 1024×1024 JPEG | 512×512 WebP | 15 KB | `91f85e56502cd3051099df3954e0751f85a3db25d04154e0552d7733ecca05db` |
| `assets/preview/avatar_layla.webp` | Preview avatars (circular crop, face centred) | headshot, young woman, dark wavy hair | `11:2` | 1024×1024 JPEG | 512×512 WebP | 20 KB | `86a10d655daa27aecd31d38e4bc5de7f7bb5db2ba47018b37db3a77703ee3bac` |
| `assets/preview/avatar_omar.webp` | Preview avatars (circular crop, face centred) | headshot, man with trimmed beard | `12:2` | 1024×1024 JPEG | 512×512 WebP | 15 KB | `deefeb1b080eaa3330877d77b18802c2034e800d2cc9762150a6a040262232f2` |
| `assets/preview/avatar_karim.webp` | Chat preview avatars (D68) | crop of `live_cooking` (360×360 at 320,210): the cook's face | `2:2` (derived) | 768×1376 WebP | 512×512 WebP | 15 KB | `771c1dd3af0526ac0ff27783b00b838d67a90a8b0d1d3ca21d73acf3985117da` |
| `assets/preview/avatar_rania.webp` | Chat preview avatars (D68) | crop of `live_music` (360×360 at 214,210): the oud player's face | `1:2` (derived) | 768×1376 WebP | 512×512 WebP | 18 KB | `af2cf27b11e717033da9cd25141e4f5f32ab8de5a8f4cb04bb16e29887186c7a` |
| `assets/preview/avatar_group.webp` | Chat preview group avatar (D68) | crop of `post_city` (696×696 at 252,100) | `10:2` (derived) | 1200×896 WebP | 512×512 WebP | 49 KB | `9de96cfe5ce48dc6ff0dcab472f1a70db9a75780617608db544f043b73041c4b` |
| `assets/preview/live_chat.webp` | Live preview, Home live-hub demo covers (portrait list) | woman in a hijab on a balcony at dusk | `4:2` | 768×1376 JPEG | 768×1376 WebP | 57 KB | `3868f406805d62be4803a6515b3824b1ed7298bf344ddedd15cb51f32c2a0768` |
| `assets/preview/live_cooking.webp` | Live preview, Home live-hub demo covers (portrait list) | man cooking in a home kitchen | `2:2` | 768×1376 JPEG | 768×1376 WebP | 74 KB | `077a853bfdf53e655d941ea442c69eb784719b46289919f583115b88553fafa6` |
| `assets/preview/live_gaming.webp` | Live preview, Home live-hub demo covers (portrait list) | young man with a gaming headset, RGB light | `3:2` | 768×1376 JPEG | 768×1376 WebP | 42 KB | `b5a4cd844934165872e93c6c0a6a161462d53ed538139c21e8292d11a340cec6` |
| `assets/preview/live_music.webp` | Live preview, Home live-hub demo covers (portrait list) | woman playing an oud in a home studio | `1:2` | 768×1376 JPEG | 768×1376 WebP | 73 KB | `20d68008a3f82c16dc7e73b8a28085afcacdc2db1499ae75e3daf4ebf7b7d371` |
| `assets/preview/post_city.webp` | Post media, Discover banner (landscape list) | hillside stone city at golden hour | `10:2` | 1200×896 JPEG | 1200×896 WebP | 137 KB | `ea98cac76ebd73a91c42dd512f3a07e7992a6ec7d53da525ec26b3ed79cddacb` |
| `assets/preview/post_mezze.webp` | Post media, Discover banner (landscape list) | overhead Levantine mezze table | `9:2` | 1024×1024 JPEG | 1024×1024 WebP | 205 KB | `49778aa23d340fde0a5c785b34a63231c620f886d34a53011edb93b71b61aec5` |
| `assets/preview/post_oud.webp` | Post media, Discover banner (landscape list) | oud and sheet music by a window | `8:2` | 1200×896 JPEG | 1200×896 WebP | 75 KB | `91ebc47338c881dc9ae32450490d635501edf713d8e13e0a741bd4ffcd034829` |
| `assets/preview/reel_coffee.webp` | Reels / feed / Discover / message media (portrait list) | hands pouring Arabic coffee, dates | `7:2` | 768×1376 JPEG | 768×1376 WebP | 69 KB | `8ea7b4f199849e9cab374888637125ad515ea8740da5416636302ae1bc2ad9a6` |
| `assets/preview/reel_dunes.webp` | Reels / feed / Discover / message media (portrait list) | red desert dunes at sunset, distant walker | `6:2` | 768×1376 JPEG | 768×1376 WebP | 36 KB | `2729787c48fabe75adbe50b85ec35a45a7c43ed48c09dc9902fe47002ea4f383` |
| `assets/preview/reel_souk.webp` | Reels / feed / Discover / message media (portrait list) | old-city market street with lanterns at night | `5:2` | 768×1376 JPEG | 768×1376 WebP | 176 KB | `1d22b6bb85d5a44e13585bbcca71b1768f661f536a856febd6ef3915cc4d851e` |
