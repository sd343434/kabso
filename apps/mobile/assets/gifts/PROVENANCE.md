# Live gift art (CP-020, D108): waiting for the owner

The gift catalogue is managed on the server (`gift-admin`, CONVENTIONS §10.23) and starts empty.
Each gift names its static image with `assetKey`; the app shows `assets/gifts/<assetKey>.png`.
The owner supplies the art; nothing here is copied from another product.

- Static images: `assets/gifts/<assetKey>.png`, square, transparent background (512×512
  suggested; the panel draws them at 44 dp, the banner at 40 dp, the big effect at 176 dp).
- Effects: `assets/gifts/anim/<animationKey>.svga` (see `anim/PROVENANCE.md`).

Until a file exists the app shows Kabso's gift box (`assets/art/kabso_gift_box.webp`), faded, in
its place: a missing file never breaks the panel or the room.

| File | Gift code | Supplied |
| ---- | --------- | -------- |
| *(none yet)* | | |
