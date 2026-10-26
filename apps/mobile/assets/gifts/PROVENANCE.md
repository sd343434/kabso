# Live gift art (CP-020, D108; hosted art D126)

The gift catalogue is managed on the server (`gift-admin`, CONVENTIONS §10.23) and starts empty.
Nothing here is copied from another product.

## Hosted on the server (D126) — the normal way now

Animated gifts are large (the first one is a 16.8 MB SVGA), so gift art is **not bundled**: the
owner's files are uploaded with `gift-admin add|update --image <file> --animation-file <file>` to
object storage (`media/gifts/<code>/<sha256 prefix>.<ext>`, immutable) and the app downloads them on
demand and keeps them in its cache. A new gift needs no app release. **These files are not in git**
(the repository is public, D40); the owner keeps the originals.

| Gift code | Files (uploaded, not in git) | Source | Recorded |
| --------- | ---------------------------- | ------ | -------- |
| `angel_warrior` (الملاك المحارب / Angel Warrior) | `angel_warrior.png` (300 × 300 RGBA PNG, 38 254 B, sha256 `1eaf9644281e113f…`); `angel_warrior.svga` (SVGA 2.1.0, 750 × 1624, 30 fps, 300 frames = 10 s, 125 bitmaps, 2 embedded MP3 sound clips; 16 830 815 B, sha256 `d1c23c640419becb…`) | Supplied by the owner, who confirmed the art and its sound are theirs / licensed (2026-10-26) | 2026-10-26 (D126) |

## Bundled fallback (older builds, or a gift without hosted art)

Each gift names a bundled static image with `assetKey`; the app shows `assets/gifts/<assetKey>.png`
when the gift has no `imageUrl` (or it cannot be downloaded).

- Static images: `assets/gifts/<assetKey>.png`, square, transparent background (512×512
  suggested; the panel draws them at 52 dp, the banner at 40 dp, the big effect at 176 dp).
- Effects: `assets/gifts/anim/<animationKey>.svga` (see `anim/PROVENANCE.md`).

Until a file exists the app shows Kabso's gift box (`assets/art/kabso_gift_box.webp`), faded, in
its place: a missing file never breaks the panel or the room.

| File | Gift code | Supplied |
| ---- | --------- | -------- |
| *(none yet)* | | |
