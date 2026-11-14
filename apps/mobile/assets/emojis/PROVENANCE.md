# Emoji packs (owner-supplied, D66, D102)

Lottie animations supplied by the owner (the first Kabi pack, then `kabso_emoji_packs_4`–`7.zip`,
2026-10-25): 512x512, 60 fps, 120 frames each. One folder per pack, one tab per pack in the
picker (`lib/features/emoji/kabi_emoji.dart`). The names (Arabic and English) come from the
owner's `kabso_emoji_packs.dart`; the pack previews (GIFs) stay outside git.

| Folder | Pack | Count | Changes |
| ------ | ---- | ----- | ------- |
| `kabi/` | Kabi | 24 | Dark outline added by `tool/kabi_emoji_outline.py` (legibility on light surfaces). |
| `kiki/` | Kiki | 18 | Minified JSON only. |
| `boo/` | Boo | 12 | Minified JSON only. |
| `pipo/` | Pipo | 12 | Minified JSON only. |
| `dubi/` | Dubi | 12 | Minified JSON only. |
| `gogo/` | Gogo | 12 | Minified JSON only. |
| `lulu/` | Lulu | 12 | Minified JSON only. |
| `neno/` | Neno | 22 | The owner's `amin` pack, renamed Neno by the owner; minified JSON only. |
| `flags/` | Flags | 18 | Neno waving Arab country flags (ISO codes); minified JSON only. |

Neno and Flags show the owner's own chibi character; the owner confirmed it is theirs and approved
publishing it in the app and this public repository (2026-10-25). The character sheet
(`amin_character.png`) and the previews stay outside git.

## `noto/` — Google Noto Animated Emoji (D376 «الحالة», CC BY 4.0)

51 Lottie files for the status packs «عام» (24, free) and «المميزة» (27, sold in «متجر الحالة»), listed in
`lib/features/status/status_catalogue.dart`. Not owner art: Google's Noto Animated Emoji.

- **Source:** `https://fonts.gstatic.com/s/e/notoemoji/latest/<code>/lottie.json`, fetched 2026-11-12 by the
  agent with its own `curl` script (the owner's `tool/download_status_emojis.dart` was read, not run). Every file
  parsed as Lottie JSON (60 fps, 1024×1024 except `2764_fe0f` 800×800, no embedded images); the bytes are
  unchanged (already minified).
- **Licence:** Creative Commons Attribution 4.0 International (CC BY 4.0) —
  https://creativecommons.org/licenses/by/4.0/. Google states the animated Noto emoji artwork is available under
  CC BY 4.0 (Google for Developers blog, "Updates to Emoji: New Characters, Animation, Color Customization, and
  More", 2022, and the gallery at googlefonts.github.io/noto-emoji-animation). Those pages could not be opened
  from the build machine (host blocked); the licence was confirmed from Google's statement as quoted by search
  results — re-read the gallery page before release (PRE_PRODUCTION_CHECKLIST).
- **Attribution (required):** "Animated emoji by Google (Noto Emoji), CC BY 4.0" — Settings › Licenses (row and
  `showLicensePage`), registered in `lib/bootstrap.dart` (`registerStatusEmojiLicense`).
- **Left out:** the owner's premium list named 29 emoji; `1f99c` (parrot) and `1f4b0` (money bag) answer 404 at
  the source (not in the animated set) and are not shipped. Nothing else was added.
- **Size:** 3,864,243 bytes (3.7 MiB) in 51 files. The Kabso packs add nothing (the status uses the chat emoji
  files above).
- The owner's own premium designs, when supplied, go in `premium/` (owner art, its own row here).

| File | Pack | Bytes | SHA-256 |
| ---- | ---- | ----- | ------- |
| `1f600.json` | «عام» (free) | 37,328 | `b93b4e7f34019b29…` |
| `1f602.json` | «عام» (free) | 59,124 | `ae479405485961c5…` |
| `1f970.json` | «عام» (free) | 58,353 | `c9fc242ce2d31e86…` |
| `1f60d.json` | «عام» (free) | 42,336 | `2351f649844d0211…` |
| `1f60e.json` | «عام» (free) | 25,407 | `17ca3ea161b36f64…` |
| `1f929.json` | «عام» (free) | 46,757 | `11faaec0e83c4f3b…` |
| `1f973.json` | «عام» (free) | 67,877 | `6cc02b10d9471287…` |
| `1f607.json` | «عام» (free) | 47,770 | `5727bf7aa8d367ce…` |
| `1f61c.json` | «عام» (free) | 74,487 | `d5a841a9582c2095…` |
| `1f917.json` | «عام» (free) | 80,181 | `feeec5c571e24716…` |
| `1f618.json` | «عام» (free) | 64,904 | `20be88735ef8db8a…` |
| `1f914.json` | «عام» (free) | 68,027 | `46405d972ad78a2f…` |
| `1f634.json` | «عام» (free) | 24,420 | `1fa14c3065950327…` |
| `1f644.json` | «عام» (free) | 29,512 | `2a77c3ae12e34b66…` |
| `1f622.json` | «عام» (free) | 47,018 | `58c4605cb7cae240…` |
| `1f62d.json` | «عام» (free) | 119,550 | `9f8b1a18099511d5…` |
| `1f621.json` | «عام» (free) | 46,289 | `7233c926fc3509ed…` |
| `1f631.json` | «عام» (free) | 90,226 | `159c6e05378b35fd…` |
| `2764_fe0f.json` | «عام» (free) | 8,439 | `7925790edd7ec4a4…` |
| `1f525.json` | «عام» (free) | 29,358 | `96199d8e8fea7d90…` |
| `1f4af.json` | «عام» (free) | 66,142 | `8e48b464d7473e94…` |
| `1f44d.json` | «عام» (free) | 40,892 | `a5803c4978c07609…` |
| `1f389.json` | «عام» (free) | 67,875 | `eab1fd7070bffd29…` |
| `1f64f.json` | «عام» (free) | 63,630 | `96c6f33baf19eb1e…` |
| `1f426.json` | «المميزة» (store) | 141,824 | `0a97c63589d8080e…` |
| `1f54a_fe0f.json` | «المميزة» (store) | 176,763 | `a5884f834ec75f54…` |
| `1f985.json` | «المميزة» (store) | 72,897 | `9c1d49926c01b9dc…` |
| `1f989.json` | «المميزة» (store) | 69,591 | `1a2753824622c37a…` |
| `1f9a9.json` | «المميزة» (store) | 64,205 | `3abaf70283e08c27…` |
| `1f99a.json` | «المميزة» (store) | 167,783 | `c0175c317cb6d5f5…` |
| `1f427.json` | «المميزة» (store) | 141,195 | `9cada87e32315670…` |
| `1f424.json` | «المميزة» (store) | 30,711 | `a4ba0fbce3a8e3cf…` |
| `1f423.json` | «المميزة» (store) | 53,445 | `b1d8d6be6ef344e6…` |
| `1f451.json` | «المميزة» (store) | 160,863 | `242b70a86733181e…` |
| `1f48e.json` | «المميزة» (store) | 62,646 | `7d72e50d378fc4c5…` |
| `1f680.json` | «المميزة» (store) | 81,575 | `2b6daf24cee4de34…` |
| `1f981.json` | «المميزة» (store) | 114,116 | `41ba731436368e93…` |
| `1f911.json` | «المميزة» (store) | 62,491 | `586ddc8ddca3e2dc…` |
| `1f3c6.json` | «المميزة» (store) | 79,233 | `3270e7b560f539cb…` |
| `1f31f.json` | «المميزة» (store) | 73,203 | `6a2654898edd8c50…` |
| `2728.json` | «المميزة» (store) | 15,584 | `60b0b7e80faadfad…` |
| `1f984.json` | «المميزة» (store) | 278,449 | `5f9c7fd7590e9fba…` |
| `1f409.json` | «المميزة» (store) | 258,884 | `7323f9903aba8c4a…` |
| `1f339.json` | «المميزة» (store) | 45,174 | `f5f1e7c3b6517dc6…` |
| `1f381.json` | «المميزة» (store) | 73,479 | `7c8172f12a23c3b4…` |
| `1f386.json` | «المميزة» (store) | 110,210 | `1da59d537da6bd30…` |
| `1f308.json` | «المميزة» (store) | 13,837 | `e750f606615ddec7…` |
| `1f496.json` | «المميزة» (store) | 34,772 | `71614ccf8c7fe4c3…` |
| `1f37e.json` | «المميزة» (store) | 37,645 | `f9c0c1ead9682b7a…` |
| `1f942.json` | «المميزة» (store) | 94,364 | `3e85e7f8bb6e2a55…` |
| `1f608.json` | «المميزة» (store) | 43,402 | `8da6f974d2ff9ec8…` |
