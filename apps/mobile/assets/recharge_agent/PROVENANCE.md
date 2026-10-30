# Recharge-agent perks (owner-supplied, AI-generated, 2026-10-30, D185)

The owner supplied three pieces of Kabso art for the recharge agents «وكلاء الشحن» (the Kabi mascot, made for
Kabso with an AI image tool and approved by the owner; owner: these are Kabso's own assets and may enter git).
Originals (RGBA WebP) stay outside git:

| Original | Size | sha256 |
| -------- | ---- | ------ |
| `avatar_frame.webp` | 1312×1199 | `ad4f3c519e6835ef71e2c2923b1a69251653738a7b9c3f425b95d59322f1d820` |
| `badge.webp` | 1312×1199 | `977346e64c7e583a4f1569becc792ea9028cb0450926fc2a83810ae393e4467a` |
| `entrance_bar.webp` | 2000×667 | `60dfb464cb8e22946c3b62332117f7710665f7df7822771cc1bbea70852612d3` |

Each was resized with Lanczos (Pillow), alpha kept, and saved as lossy WebP with alpha (quality 86, method 6);
nothing else was changed (no crop, no recolour):

| File | Size | Use |
| ---- | ---- | --- |
| `avatar_frame.webp` | 540×493 | `RechargeAgentFrame`: the agent's photo in the round opening (centre 49.9 % / 49.2 %, radius 28.6 % of the width, measured on the original) and the agent code written by the app in the red plate (x 17.5–82.3 %, y 78.0–89.2 %). |
| `badge.webp` | 240×219 | `RechargeAgentBadge`: beside the name on the profile and the person card, and inline next to the name in live rooms (chat, join line, viewers, seats). |
| `entrance_bar.webp` | 1050×350 | `LiveRechargeEntranceLayer`: the bar that crosses the live room when an agent joins; the app writes «دخل وكيل الشحن {code}» in the red plate (x 44–91.5 %, y 36.7–67.5 %); the mascot stays on the emblem. |
