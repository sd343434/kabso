# The public website's assets (D192)

Files under `infra/deploy/site/` (served at kabsolive.com, CONVENTIONS §10.55).

## Provenance

| Files | Source | Edits |
|-------|--------|-------|
| `assets/characters/*.webp` — seed, bunny, kitty, butterfly, fox, owl, unicorn, dragon, phoenix, king-kabi | **Owner-supplied Kabso art** (the ten Kabso mascot characters), embedded as base64 WebP in the owner's page `kabso-coming-soon.html` (2026-10-31, via the coordinator; the owner approved it for git). | Extracted unchanged in size (349–654 px wide, alpha), re-encoded WebP quality 82, alpha lossless (−12 % bytes). The positions in `home.js` (`INFO`: eye and feet points) are the owner's numbers. |
| `assets/logo.webp` | Owner-supplied Kabso logo mark (same page, PNG 127 × 160). | WebP quality 92, alpha lossless. |
| `favicon.ico`, `assets/icon-32.png`, `apple-touch-icon.png` | Owner-supplied Kabso icon (same page, PNG 180 × 180). | 16/32/48 ICO and 32 px PNG by Lanczos downscale; 180 px PNG unchanged. |
| `assets/king-voice.mp3` | Owner-supplied voice line played when King Kabi is tapped (same page). | Unchanged (23.9 KB). |
| `assets/og-image.jpg` (1200 × 630) | Composed for D192 from the owner's art above (characters, logo) and the page's own text, rendered with the self-hosted fonts. | No new artwork. |
| `assets/fonts/*.woff2` | Cairo (© The Cairo Project Authors) and Inter (© The Inter Project Authors), **SIL Open Font License 1.1** (`OFL-Cairo.txt`, `OFL-Inter.txt`), the same variable files Google Fonts served for the owner's page; arabic + latin subsets. | None; self-hosted so no request leaves the domain (CSP `font-src 'self'`, no IP sent to a third party). |
| App Store / Google Play glyphs in the «قريباً» badges | The owner's page; single-colour glyphs, not links, no store badge artwork. | Recoloured to one colour. |

No third-party product art, no real people.

## Size (the root page's first load, transfer with gzip/zstd, measured locally through Caddy)

- Before: the owner's single file 729 KB (525 KB gzipped) — nothing painted before all of it arrived — plus the
  Google Fonts CSS and three font files from Google (~115 KB).
- After: HTML 2 KB, CSS + JS ≈ 18 KB, fonts 113 KB (self-hosted), logo 5.6 KB (preloaded), ten characters 412 KB
  (decoded asynchronously, fetched in parallel, cached 30 days), settings JSON < 0.1 KB: ≈ 551 KB in all, of which
  the page paints from the first ≈ 25 KB (plus the fonts). The voice (24 KB) loads only when King Kabi is tapped.
