# Active-host avatar frames (owner-supplied, AI-generated, 2026-10-30, D186)

The owner supplied two avatar frames for active hosts «المضيف النشط» (Kabso art made for Kabso with an AI
image tool and approved by the owner; owner: these are Kabso's own assets and may enter git). Originals
(RGBA WebP, transparent background and centre) stay outside git:

| Original | Size | sha256 |
| -------- | ---- | ------ |
| `host_frame_male.webp` (blue: sapphire crown, wings and microphone) | 1254×1254 | `3292b92c0990f820f3f5f1f41404f2a7f2a0c2b00db7dcd71842d51be1e7571f` |
| `host_frame_female.webp` (pink: heart crown, wings and microphone) | 1254×1254 | `a4625a74a8c794a9b70913504bb6bb6fd3c23c38cd8e69f1e3c6167c824367a1` |

Processed like the support frames (`assets/levels/support_frames/`), with no other change: trimmed to the
pixels with alpha > 32, centred on a transparent square of the longer side, resized with Lanczos (Pillow) to
256×256 and saved as WebP with alpha (quality 90, method 6). No crop of the art, no recolour.

| File | Bag code / `assetKey` | Original | Trimmed box (x0, y0, x1, y1) |
| ---- | --------------------- | -------- | ---------------------------- |
| `host_frame_blue.webp` | `host_frame_blue` | `host_frame_male.webp` | 9, 2, 1245, 1243 (square 1241) |
| `host_frame_pink.webp` | `host_frame_pink` | `host_frame_female.webp` | 5, 0, 1246, 1247 (square 1247) |

Mapping (owner, D186): male → blue, female → pink; «أفضّل عدم الذكر» or no gender → the host picks one.

The photo's circle, measured from the alpha channel (threshold 32) of the trimmed square, as fractions of
its side: the transparent centre was flood-filled from the middle (it does not reach the edge), 720 rays
cast from its centre to the first opaque pixel, the rays shortened by the hanging ornaments (below 95 % of
the 60th percentile) dropped, and a least-squares circle fitted to the rest (twice, re-centred):

| Frame | cx | cy | r |
| ----- | -- | -- | - |
| `host_frame_blue` | 0.5086 | 0.4887 | 0.2830 |
| `host_frame_pink` | 0.5158 | 0.4959 | 0.2784 |

The app draws the photo in that circle, 4 % larger so its edge tucks under the ring; the hanging ornaments
fall over the photo as in the art. No name is written under the frame (owner).
