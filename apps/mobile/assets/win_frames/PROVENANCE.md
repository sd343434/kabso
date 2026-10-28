# Lucky-win banner frames (owner-supplied, D159)

Made for Kabso and supplied by the owner as the package `kabso_win_banner`: first on 2026-10-28,
then **revision 2** the same day, which replaces the first package entirely (medallion + message
bar frames, an updated reference widget `kabso_win_banner.dart`, the Kabso coin at 32/48/64/128 px,
a preview image and a preview video). The four frames below are revision 2, copied **unchanged**
(byte for byte, 1080x329, transparent PNG). The coin PNGs were not added: the banner uses the app's
spending coin `KabsoArt.coin` (`assets/currency/kabso_coin.png`; the owner's new coin art replaces
that file in another branch). The reference widget was read, not copied; the preview image and
video stay outside git.

| File | Tier | Multipliers | Label |
| ---- | ---- | ----------- | ----- |
| `win_frame_sapphire.png` | sapphire | ×5 … ×25 | «فوز» / WIN |
| `win_frame_ruby.png` | ruby | ×50 … ×100 | «فوز كبير» / BIG WIN |
| `win_frame_amethyst.png` | amethyst | ×250 | «فوز ضخم» / HUGE WIN |
| `win_frame_onyx.png` | onyx | ×500 … ×1000 | «جاكبوت» / JACKPOT |

Geometry, as fractions of the image (the owner's values): the medallion's centre x 0.186,
y 0.563 and radius 0.086 of the width; the message panel left 0.325, top 0.408, right 0.893,
bottom 0.712. The art reads right to left; the English layout draws it mirrored.
