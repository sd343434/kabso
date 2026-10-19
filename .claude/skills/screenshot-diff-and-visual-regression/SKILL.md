---
name: screenshot-diff-and-visual-regression
description: Capture the real running Kabso Live app at the reference viewport/DPR/locale and objectively compare it to the reference — side-by-side, 50% overlay, heatmap, MAE, SSIM, changed-pixel % and worst regions — then drive the fix/retest loop. Use for CAPTURE, COMPARE and RETEST in pixel-perfect-ui-workflow, or to check any UI change against an approved screenshot.
---

# Screenshot diff and visual regression

Scripts are in `.claude/skills/pixel-perfect-ui-workflow/scripts/`. They have been verified to run in this environment.

## 1. Capture the real app (gate D)

**Preferred: Flutter web build in Chromium** (`capture_web.mjs`)

1. Copy the tracked `apps/mobile` into scratch:
   ```
   cd apps/mobile && git ls-files | tar -cf - -T - | tar -xf - -C "$SCRATCH/webapp"
   ```
2. In the scratch copy:
   ```
   flutter create --platforms=web --project-name kabso_live .
   flutter build web --profile --dart-define=API_BASE_URL=http://localhost:<port>
   ```
   Never add the web platform to the repo.
3. Serve the build: `python3 -m http.server 8135 -d build/web`.
   - If a local API is used, its `CORS_ORIGINS` must include `http://localhost:8135`.
   - Use only labelled local test accounts. Fixtures are not allowed in this path.
4. Capture:
   ```
   node capture_web.mjs --url http://localhost:8135/#/<route> --out out.png \
     --width <lw> --height <lh> --dpr <dpr> --locale <ar|en> --web-dir "$SCRATCH/webapp/build/web" \
     [--profile-dir <dir>] [--hold <url-part>] [--offline]
   ```
   Keep the JSON line it prints. `--hold` and `--offline` produce states that must be labelled **simulated**.

**Alternative: headless render harness** (`apps/mobile/tool/ui_audit/capture_test.dart`, `flutter test tool/ui_audit/`). It renders the real widget tree with fake repositories. Label these captures **headless render (fake repositories)**; they are not device screenshots.

**Not available here:** emulators, simulators, physical devices. Say so; never imply a device capture.

## 2. Make the comparison fair

Before comparing, confirm these match: logical viewport, DPR, pixel size, locale, text scale (1.0), the
status-bar and safe-area insets, the scroll position, the selected tab and the data state.

- **Size mismatch:** fix the capture. `visual_diff.py` refuses mismatched sizes unless you pass `--resample-reference "reason"`, which it records.
- **Region that differs for an unavoidable reason** (e.g. the status-bar clock, or a third-party photo we must not copy): `--mask "x,y,w,h:reason"`. Masks apply to both images and are listed in `metrics.json` and drawn on `regions.png`.
- **Never** crop, blur, recolour or otherwise edit the output screenshot.

## 3. Compare (gate E)

```
python3 visual_diff.py --reference ref.png --output out.png --out diff/iter-01 --dpr <dpr> \
  --criteria ../templates/thresholds.json --profile cross_environment [--mask ...]
```

- `--criteria` takes `templates/thresholds.json` with `--profile NAME`, or a file holding one profile object. Use `controlled` only when the renderer, fonts and assets match; use `cross_environment` for third-party references.
- Criteria fail closed: a missing or malformed file, an unknown profile, unrecognised keys, invalid values, an uncomputed changed-pixel threshold or an empty profile exits 2 before measuring. A configured check that cannot run (for example, everything masked) is listed in `verdict.not_run` and fails the verdict. `metrics.json` lists the checks that ran (`checks`) and the ones not configured (`not_configured`). A verdict never passes with zero checks.
- SSIM methodology (recorded in `metrics.json`): 11×11 Gaussian window, σ 1.5, population covariance, reflect padding. The mean excludes a 5 px border and is validated against scikit-image. Masked output pixels are replaced by the reference's before SSIM, so masks cannot lower the score of neighbouring valid pixels. MAE and changed % use every unmasked pixel. Masks are never widened to hide a defect.
- `capture_web.mjs` always closes its context and browser (`finally`, plus SIGINT/SIGTERM). Exit codes: 0 = captured, 1 = capture failed (JSON error on stderr), 2 = usage. `--nav-timeout` bounds navigation.
- Profile calibration and its limits: `pixel-perfect-ui-workflow/templates/CALIBRATION.md`.
- **`cross_environment` is ADVISORY.** Its verdict carries `"advisory": true` with the reason, and `visual_diff.py` prints an `ADVISORY` line on stderr. Its PASS is evidence for manual review, never a release or acceptance gate. Exit codes are unchanged, so a script must read `verdict.advisory` and not the exit code alone. It stays advisory until it has been calibrated on at least two genuinely different rendering environments. Do not change its thresholds without that measured evidence.
- **Font-weight regressions are an unresolved limitation.** Across environments no metric here separates a weight fallback from rendering noise. Check weights with a same-environment `controlled` comparison and a widget test that the requested weight is bundled.
- Tooling regression tests: `python3 -m unittest discover -s .claude/skills/pixel-perfect-ui-workflow/scripts/tests -v`. This covers criteria (D1), SSIM (D3/D4), the capture lifecycle (D6, which needs node, Playwright and Chromium) and generated files (D5).
- Outputs:
  - `side_by_side.png` (reference | output | heatmap);
  - `overlay50.png`, `heatmap.png`, `regions.png` (top-5 worst cells in red, masks in blue);
  - `metrics.json` (inputs with sha256, methodology, MAE, SSIM, changed % at 8/16/32/64, worst regions in px and logical px, verdict).
- Exit codes: 0 = criteria pass, 1 = fail, 2 = invalid input.
- ImageMagick `compare -metric AE|MAE|RMSE|PSNR` is available as a cross-check. IM6 has no SSIM; the SSIM comes from `visual_diff.py`'s numpy implementation.

## 4. Classify and fix

For each worst region, inspect `side_by_side.png` and the overlay, then classify it:

| Class | Signal | Typical fix |
| ----- | ------ | ----------- |
| layout | edges doubled or shifted in the overlay | padding, size or alignment |
| colour | same shapes, uniform tint in the heatmap | token or opacity |
| typography | glyph-shaped noise, different line breaks | font size, weight or line height (or a font blocker) |
| asset/image | whole-image difference | correct asset, or a documented blocker |
| environment | anti-aliasing speckle, status-bar content, third-party photos | mask with a reason, or document it |

Fix the highest-impact class first (layout > asset > typography > colour), then re-capture and re-compare. Name each iteration directory `iter-NN` and keep all of them.

## Rules

- A score is evidence, not proof. Always look at the images too.
- Never lower a threshold to get a pass. If a criterion can't be met, report the failing number and its cause.
- Don't compare different app states, viewports, DPRs or insets without stating and handling the difference.
- Don't claim pixel-perfect while measurable differences remain.
- Third-party reference images, and diffs that contain them, stay in scratch, not in git.
