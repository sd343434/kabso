# Sounds (owner-supplied Kabso assets, 2026-10-28: MAX X D145d, notifications D152)

Made for Kabso and supplied by the owner on 2026-10-28 with the animated MAX X button design
(`kabso_max_x/assets/sounds/`). Copied unchanged (MPEG-1 Layer III, 128 kbps, 44.1 kHz, mono). The
reference Dart file, the demo page, the preview image and the preview video of that package stay
outside git.

Played by `MaxXSounds` (`lib/features/live/application/max_x.dart`) with `audioplayers`, on the
sender's phone only, while the app's sound effects are on (Settings).

| File | Length | Use |
| ---- | ------ | --- |
| `max_tap.mp3` | 0.34 s | every accepted tap on the MAX X button |
| `max_win_5.mp3` | 0.94 s | a send the server answered with a ×5 win (and any smaller win) |
| `max_win_10.mp3` | 1.15 s | ×10 – ×24 |
| `max_win_25.mp3` | 1.33 s | ×25 – ×49 |
| `max_win_50.mp3` | 1.65 s | ×50 – ×99 |
| `max_win_100.mp3` | 2.04 s | ×100 – ×249 |
| `max_win_250.mp3` | 2.43 s | ×250 – ×499 |
| `max_win_500.mp3` | 3.03 s | ×500 – ×999 («جاكبوت» / JACKPOT) |
| `max_win_1000.mp3` | 3.74 s | ×1000 and more («سوبر جاكبوت» / SUPER JACKPOT) |

SHA-256:

```
8b1b87977f993f00b074b337acec8599c30480f759d7bf7dc24738114783cf8e  max_tap.mp3
81c638e2597b3b2985c0b2f07eb5d1712f447f909f97af143e86a7b26e46b103  max_win_5.mp3
6787eab07ff2dcaa8bbe3e1fa691e2cc6b6c343965fbbbb533239b3d49ee144b  max_win_10.mp3
ecb13e1acc79ce89aed1b2102300c8d3e1ce1ca339398b6b0f838f3d2c621b4d  max_win_25.mp3
a1bff80de47bf452e9be4c7e96098f7b03651551499f3b1ee2b3492916813bb8  max_win_50.mp3
7f8edad1bf2334336e03f2cf2d167147813c35ba6959cc8707ada336a0642570  max_win_100.mp3
c3fc754ef29dd8266ad9fec68ea4e8a6233362885a4f9acc3c2951a4045b53a9  max_win_250.mp3
d88d4efaf57746293f7153bc42a7e02b4948238f043fec6b8477d0dadfefb647  max_win_500.mp3
6184266c83c3ac16e24c74ee65a5c8014903bcad95b9755390a08678f17fa067  max_win_1000.mp3
```

## Notification sounds (owner-supplied Kabso assets, 2026-10-28, D152)

Made for Kabso and supplied by the owner on 2026-10-28 (a download of two mp3 files; only the
mp3s were copied, nothing in it was run). Copied unchanged (MPEG-1 Layer III,
128 kbps, 44.1 kHz, mono). The same two files are also in
`android/app/src/main/res/raw/` (the Android notification channels' sounds; resource names must
be lower case, so the file names are kept as they are).

| File | Length | Use |
| ---- | ------ | --- |
| `kabi_voice_a.mp3` | 2.43 s | general notifications: channel `kabso_general` (pushes) and the in-app sound for a new notification (`NotificationSounds`, `lib/features/push/notification_sounds.dart`) |
| `kabso_message.mp3` | 0.60 s | chat messages: channel `kabso_messages` (pushes) and the in-app sound for a message in another chat |

SHA-256:

```
3414ad17c33196691051460032815f0eb187c0d7f94ebc28946a85bb8bfeea94  kabi_voice_a.mp3
b6c2475a75d597920ecadcd0b0924dab25d57be734bee1cb98c3d877147f9086  kabso_message.mp3
```
