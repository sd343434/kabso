# Live bottom-bar icons (owner-supplied, 2026-10-25)

Supplied by the owner as Kabso's live room bottom-bar icons (`kabso_live_bar_icons.zip`, replaced
the next day by `kabso_live_bar_icons_1.zip`: white outline chat / emoji / menu and coloured seat,
PK, toolbox and gift, drawn with no circle behind them): used as they are (the 144×144 `@3x` PNGs,
renamed). The pack's SVGs, Dart sample and preview
stay outside git. They replace the tinted outline icons of `assets/live_room_icons/` in the audio room
bar (host and viewer).

| File | Used for |
| ---- | -------- |
| `chat.png` | Chat (opens the chat box) |
| `emoji.png` | Emoji (opens the chat box with the emoji row) |
| `menu.png` | Host: Room Tools (ref 84) |
| `seat.png` | Host: seat requests; viewer: ask for a seat |
| `gift.png` | Viewer and host: the gift box (preview: nothing can be sent until a wallet exists, B5) |
| `bar_pk.png` | Owner-supplied 2026-10-27 (D135, Kabso's own art: red/blue boxing gloves with "PK"; original in chat, 256×256 transparent, trimmed with ≈ 6 % margin, not otherwise modified; the original stays outside git): the host's PK button on the video live, drawn 33 pt with no circle; D141: also the audio room's PK (host), 37–40 pt |
| `bar_gift.png` | Owner-supplied 2026-10-27 (D135, Kabso's own art: a pink gift box with a gold bow; 256×256 transparent, trimmed with ≈ 6 % margin): the gift button of the video live (host and viewer), 33 pt with no circle; D141: also the audio room's gift button (host and viewer), 37–40 pt |
| `bar_games.png` | Owner-supplied 2026-10-27 (D141, Kabso's own art: a glossy blue/red game controller; the supplied 1254×1254 picture's outer background was already transparent — near-invisible stray pixels (alpha < 16) cleared, trimmed and fitted to 256×256 with the same ≈ 6 % margin as the two above; checked for halos at 40 pt over dark and light bars; the original stays outside git): the audio room's games button (host), 40 pt with no circle — in place of the toolbox (it repeated ≡). There are no games yet: a tap says «الألعاب قريباً» |

`pk.png` and `toolbox.png` were removed in D141 (replaced by `bar_pk.png` and, for the toolbox's place, `bar_games.png`). `seat.png` left the audio bar in D141 (owner: the seat button uses the video bar's ∞ icon, `Icons.all_inclusive_rounded`); it stays for the person card's «invite to a seat».

The host's mic button left the bar (owner, 2026-10-26): the host and a seated guest mute and unmute
themselves by tapping their own picture.
