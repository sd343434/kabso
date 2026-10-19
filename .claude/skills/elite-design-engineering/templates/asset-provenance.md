# Asset provenance — <feature / ticket>

One row per asset added or replaced. Never fill a cell you cannot prove: write `unknown` and keep
the asset out of production until it is resolved. Third-party reference screenshots and anything
showing real users are never committed (keep them in scratch).

| Asset path | Screen / component | Kind | Source (provider, URL or file id, prompt for generated) | Retrieved / generated | Licence & attribution | Original (px, format) | Final (px, format, size) | SHA-256 | Edits | Status |
| ---------- | ------------------ | ---- | ------------------------------------------------------- | --------------------- | --------------------- | --------------------- | ------------------------ | ------- | ----- | ------ |
| `assets/...` | | photo · illustration · icon · font · avatar | | YYYY-MM-DD | verified · pending review · unknown | | | | crop / resize / recolour / retouch (what and where) | production-approved · dev/test only |

## Checks done for each asset
- [ ] Opened and inspected at full size (no watermark, no third-party logo, no embedded UI text).
- [ ] Dimensions and aspect ratio fit the slot at DPR 3; file size reasonable for repeated use.
- [ ] Focal point survives the actual crop (faces inside circles, subjects inside portrait crops).
- [ ] Declared in the asset manifest (e.g. `pubspec.yaml`) once; referenced through a named constant.
- [ ] Loads in the running app (captured screenshot listed in the report).
- [ ] Usage rights verified for the intended use (dev preview vs production vs store listing).
