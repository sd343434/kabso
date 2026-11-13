# Host-agent perks (owner-supplied, AI-generated, 2026-10-30, D189)

The owner supplied three pieces of Kabso art for the host agents «وكيل مضيفين» (blue and gold, a crowned host with
two hosts and a microphone; made for Kabso with an AI image tool and approved by the owner; owner: these are Kabso's
own assets and may enter git). Originals (RGBA WebP) stay outside git:

| Original | Size | sha256 |
| -------- | ---- | ------ |
| `avatar_frame.webp` | 1254×1254 | `dcbf9e9598a85bad769108f7d2de5d23a3a0c186595bebeec8eb95d70f804de1` |
| `badge.webp` | 1402×1122 | `7d8ee07df53628b716bcf8899f2c419a703f98d9d11af5ce523d018a70438a68` |
| `entrance_bar.webp` | 2000×750 | `5b1d1981fab97a077b826bef1acb452805265e146cb8159f22f2eb91fa4a03a9` |

**Cleaning** (as D187): each file was split into 8-connected components of the pixels with alpha > 32; the largest
is the art, and any other component outside its bounding box would have been cleared — none of the three had one.
The faint haze (alpha ≤ 32) outside the art's bounding box was cleared (badge 772 px, frame 705 px, bar 1 812 px).
Then each was trimmed to the art (badge box 71, 6 – 1329, 1109; frame 4, 5 – 1250, 1246; bar 23, 13 – 1979, 737), the
badge and the frame centred on a transparent square of the longer side, resized with Lanczos (Pillow) and saved as
lossy WebP with alpha (method 6). No recolour, nothing else changed.

| File | Size | Quality | Use |
| ---- | ---- | ------- | --- |
| `badge.webp` | 240×240 | 88 | `HostAgentBadge`: beside the name on the profile and the person card, and inline next to the name in live rooms (chat, join line, viewers, seats) — placed exactly as the recharge-agent badge. |
| `avatar_frame.webp` | 512×512 | 90 | `HostAgentFrame`: the photo in the round opening. It has no name plate: no text is written. |
| `entrance_bar.webp` | 1050×389 | 86 | `LiveRechargeEntranceLayer` (host style): «دخل وكيل المضيفين {username}» in the blue plate (x 42–86.5 %, y 40–68 %), the emblem at the left. |

**The photo circle** of the frame, measured from the alpha channel (threshold 32) of the trimmed square, as
fractions of its side: the transparent centre was flood-filled from the middle (it does not reach the edge), 720 rays
cast from its centre to the first opaque pixel, the rays shortened by the hanging ornaments (below 95 % of the 60th
percentile: the crown's point and the hosts and microphone at the bottom) dropped, and a least-squares circle fitted
to the rest (five passes, re-centred): **cx 0.4995, cy 0.4815, r 0.2645**. The app draws the photo 4 % larger so its
edge tucks under the ring; the ornaments at the bottom fall over the photo as in the art.
