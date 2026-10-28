# Launch screen (owner-supplied Kabso assets)

## `kabso_splash.mp4` — the launch video (D156, 2026-10-28)

Made for Kabso and supplied by the owner on 2026-10-28 as the new launch screen: a red gift box on a
dark stage shakes and bursts open, Kabi pops out with coins, cherries and confetti on red, and
"kabso • LIVE" appears at the end. Kabso's own mascot and wordmark; no third-party art.

The owner's original stays **outside git** (1080×1920, 60 fps, H.264 High, AAC LC mono 44.1 kHz,
6.6 s, 7.6 MB; SHA-256 `4878d5f2704ff66669fbc28cfff6679286e67350d50a5b89b477a2748cd33fff`). The app
bundles a re-encode, nothing else changed (no crop, no edit, same length and sound):

```
ffmpeg -i in.mp4 -vf "scale=720:1280:flags=lanczos,fps=30,format=yuv420p" \
  -c:v libx264 -profile:v high -level 4.0 -preset slow -crf 22 -pix_fmt yuv420p \
  -c:a aac -b:a 96k -ac 1 -ar 44100 -movflags +faststart kabso_splash.mp4
```

720×1280, 30 fps, H.264 High@4.0, yuv420p, AAC LC mono 96 kbps, `moov` before `mdat` (fast start),
6.6 s, 2,257,980 bytes. SSIM against the original scaled to 720×1280: 0.9896 (all planes). 1080×1920
at CRF 24 was 3.37 MB, over the 2.5 MB budget.

## `kabso_splash_end.webp` — the video's last frame

The original's last frame scaled to 720×1280 (Lanczos), WebP quality 82 (78,628 bytes). Shown instead
of the video with reduced motion, and when the video cannot play.

## `kabso_splash.json` — the D63 Lottie (Kabi hops in)

Owner-supplied (D63, 2026-10-19). No longer the launch screen; still the welcome screen's Kabi
(`KabiMascot`). The D63 voice `kabso_voice.mp3` was removed with D156 (nothing else used it).

SHA-256:

```
582d849d3a4226eab3cf6de7009e398c2f7929131ef53be2347438e8d013437c  kabso_splash.mp4
298339094807000069c59d8fabf050e32724c8ab05a80b2099898df455bc89a6  kabso_splash_end.webp
```
