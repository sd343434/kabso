# Acceptance-profile calibration (D7), 2026-10-16

**Status:**
- `controlled` is partially calibrated, on ONE machine only. With 4×12 it detects 6 of 7 defects; with the experimental default `cell:24` (this branch, unmerged) it detects 7 of 7, but subtle icon **colour, opacity and stroke-weight** changes may go undetected (finding 6). It is not a release gate.
- `cross_environment` is **ADVISORY**. `visual_diff.py` marks its verdict `"advisory": true`, and it is never a release gate. It stays advisory until calibrated on at least two genuinely different rendering environments; this sandbox has only one (headless Chromium), so that has not happened.
- Threshold values are unchanged (`thresholds.json` sha256 `98767432…09be8`, guarded by `ThresholdsUnchangedTest`).

## Set-up

| Setting | Value |
| ------- | ----- |
| App | Kabso build of `claude/kl-054-profile-trial` (web `--profile`, CanvasKit, Chromium headless) |
| Screen | `/debug/profile-preview?inset=47`, en, light theme, 393×856 lp |
| Pipeline | Captured at DPR 3, Lanczos-downsampled to 258×562 px (the KL-054 device pipeline) |
| Base | `calib/caps/base.png`; pixel-identical to the iteration-3 capture |
| Comparison | `visual_diff.py` with the D1/D3/D4 fixes, `--criteria templates/thresholds.json --profile <p>`, no masks, default grid 4×12, `--shift-search 4` |

Real-render negatives were produced without code changes: a different URL inset, a blocked font request, or a tap. "Synthetic" negatives are documented pixel edits of the base capture.

## Results

| Case | Kind | How it was made | Expected (controlled / cross) | MAE | SSIM | ch32 % | Shift | controlled | cross_environment |
| ---- | ---- | --------------- | ----------------------------- | --- | ---- | ------ | ----- | ---------- | ----------------- |
| rep1, rep2 | positive | repeat capture, new browser | PASS / PASS | 0 | 1.0 | 0 | 0,0 | PASS ✔ | PASS ✔ |
| rep3 | positive | repeat after a static-server restart | PASS / PASS | 0 | 1.0 | 0 | 0,0 | PASS ✔ | PASS ✔ |
| nosubpixel | positive | Chromium `--disable-font-subpixel-positioning` (no visible effect here) | PASS / PASS | 0 | 1.0 | 0 | 0,0 | PASS ✔ | PASS ✔ |
| dpr2 | positive (environment) | rendered at DPR 2 instead of 3 | out of scope / PASS | 0.58 | 0.997 | 0.15 | 0,0 | FAIL ✔ | PASS ✔ |
| direct | positive (environment) | rendered directly at DPR 0.6565 | out of scope / PASS | 2.08 | 0.971 | 2.26 | 0,0 | FAIL ✔ | PASS ✔ |
| shift2lp | negative, real | inset 49 instead of 47 (2 lp down) | FAIL / FAIL | 5.66 | 0.868 | 4.93 | **0,1** | FAIL ✔ | PASS ✘ **FN** |
| weight_fallback | negative, real | Inter-ExtraBold request blocked; @username falls back to Bold | FAIL / FAIL | 0.10 | 0.999 | 0.12 | 0,0 | FAIL ✔ | PASS ✘ **FN** |
| follow_state | negative, real | Follow tapped (red → grey) | FAIL / FAIL | 2.27 | 0.982 | 1.58 | 0,0 | FAIL ✔ | FAIL ✔ |
| missing_follow | negative, synthetic | Follow button erased | FAIL / FAIL | 2.59 | 0.981 | 1.56 | 0,0 | FAIL ✔ | FAIL ✔ |
| icon_swap | negative, synthetic | bell replaced by the share icon | FAIL / FAIL | 0.16 | 0.997 | 0.10 | 0,0 | PASS ✘ **FN** | PASS ✘ **FN** |
| image_swap | negative, synthetic | grid tiles 1 and 2 swapped | FAIL / FAIL | 4.78 | 0.988 | 13.20 | 0,0 | FAIL ✔ | PASS ✘ **FN** |
| bg_color | negative, synthetic | background #FFFFFF → #F6F6F8 | FAIL / FAIL | 3.96 | 0.996 | 0.00 | 0,0 | FAIL ✔ | PASS ✘ **FN** |

**Notes:**
- False positives: none.
- `controlled` false negatives: 1 (icon_swap).
- `cross_environment` false negatives: 5 of 7 negatives.

## Findings

### 1. `controlled` noise floor

- Repeat captures are pixel-identical, so the measured noise floor is 0. Any controlled threshold above 0 separates the positives seen here.
- Noise on other machines or GPUs was **not** measured, so the threshold values cannot be tightened from this data.

### 2. `controlled` misses a small icon change

- The swapped 14×13 px icon averages into a 64×47 px grid cell: worst cell MAE 3.86 against a limit of 4.0, and changed@32 is 0.10 % against a limit of 0.1 %.
- With the same thresholds and a finer grid, it fails as it should: `--grid 8x24` gives a worst cell MAE of 15.35; `--grid 16x48` gives 41.13. Repeat captures still pass at 0.00.
- **Proposed** (separate change, not applied): make the default grid size depend on the cell size (about 32 px cells), or add per-component checks. No threshold value needs to change.

### 3. `cross_environment` cannot separate defects from rendering noise using global metrics

- Its limits (MAE 18, changed@32 25 %, changed@64 10 %, region MAE 45) sit far above every defect measured: the largest defect MAE is 5.66.
- Defect and noise magnitudes overlap. The weight change (MAE 0.10) and the icon swap (0.16) are smaller than the environment noise of the direct pipeline (MAE 2.08).
- Tightening these global limits would therefore start failing legitimate environment differences. **This is a limitation, not a tuning problem.**

### 4. Component-level metrics separate most of these defects

These come from `component_metrics.py` and `--shift-search`, measured against the environment positives dpr2 and direct:

| Negative | Metric | Negative value | dpr2 | direct |
| -------- | ------ | -------------- | ---- | ------ |
| shift2lp | global shift | (0, 1) | (0, 0) | (0, 0) |
| bg_color | background ΔE2000 | 2.07 | 0 | 0 |
| image_swap | tile MAE | 36.1 | 1.02 | 2.18 |
| missing_follow / follow_state | component reported missing | yes | no | no |
| icon_swap | bell IoU | 0.16 | 0.97 | 0.37 (small margin) |
| weight_fallback | handle shape / ink | 0.25 / 0.91 | 0.06 / 0.98 | **0.20 / 0.90 (not separable)** |

**Proposed** (separate, evidence-backed, not applied): a component-level gate for cross-environment work:

- global shift = 0;
- no missing component;
- token-colour ΔE2000 ≤ 1;
- per-image MAE and per-icon IoU limits.

Each limit should be calibrated on at least two real environment pairs (for example Chromium vs an Android emulator and an iOS simulator, none of which exist in this sandbox) before being enforced.

### 5. Font-weight regressions (unresolved limitation)

Font-weight regressions are not reliably detectable across environments by any metric here. The finer grid (finding 6) does not change this. Use same-environment (controlled) comparison, or a widget test that the weight resolves (see `public_profile_test.dart`, "every Inter weight the profile requests is bundled").

### 6. Controlled grid: `cell:24` (EXPERIMENT on `claude/kl-054-grid-experiment`, not merged, not a release gate)

> **Calibrated on ONE machine only.** All captures come from this sandbox: one headless Chromium, one CPU raster path, one font stack. The controlled noise floor on any other machine, GPU, browser build or device is **unmeasured**. Until a second machine has been measured, `cell:24` is the recommended experimental configuration, not an unconditional release gate.

**Configuration:**
- `visual_diff.py --grid` accepts `COLSxROWS`, `cell:N` (about N px per cell; cols = ceil(w/N), rows = ceil(h/N)) or `cell:Nlp` (logical px; needs `--dpr`). The experimental default is `cell:24`, which gives 11×24 cells on the 258×562 calibration images.
- Every `metrics.json` records the grid used in `inputs.grid`, for example `{"spec": "cell:24", "cols": 11, "rows": 24}`. This was verified in all 52 runs below.
- Thresholds are unchanged.

#### All 13 calibration cases, default `cell:24` vs the shipped 4×12

Values are the verdict and the worst cell MAE (`gridexp2/results.json`). *oos* marks an environment positive outside the controlled scope, where FAIL is expected.

| Case | Kind | controlled, cell:24 | controlled, 4×12 | cross_environment (ADVISORY), cell:24 |
| ---- | ---- | ------------------- | ---------------- | ------------------------------------- |
| rep1, rep2, rep3, nosubpixel | positive | PASS 0.00 | PASS 0.00 | PASS 0.00 |
| dpr2 | env positive | FAIL 7.71 *(oos)* | FAIL 3.29 *(oos)* | PASS 7.71 |
| direct | env positive | FAIL 17.82 *(oos)* | FAIL 7.66 *(oos)* | PASS 17.82 |
| shift2lp | negative | FAIL 38.21 | FAIL 19.19 | PASS (FN) |
| weight_fallback | negative | FAIL 9.95 | FAIL 2.34 (via changed@32) | PASS (FN) |
| follow_state | negative | FAIL 109.45 | FAIL 68.41 | FAIL |
| missing_follow | negative | FAIL 127.49 | FAIL 78.15 | FAIL |
| icon_swap | negative | **FAIL 11.88** | PASS 3.86 **(FN)** | PASS (FN) |
| image_swap | negative | FAIL 42.29 | FAIL 37.33 | PASS (FN) |
| bg_color | negative | FAIL 8.33 | FAIL 8.33 | PASS (FN) |
| **False negatives / false positives** | | **0 / 0** | 1 / 0 | 5 / 0 |

#### Grid alignment (`gridexp2/alignment_cell24.json`)

These are worst cell MAE values over all 576 offsets (0–23 px in x and in y) of the 24 px grid. The controlled limit is 4.0.

| Case | Worst alignment | Median | Best alignment |
| ---- | --------------- | ------ | -------------- |
| rep1, rep2, rep3, nosubpixel | 0.00 | 0.00 | 0.00 |
| icon_swap | **10.88** (2.7× the limit) | 28.0 | 39.6 |
| weight_fallback | 4.44 (also fails changed@32 at every grid) | 9.51 | 11.6 |
| shift2lp | 31.14 | 41.7 | 54.8 |
| image_swap | 41.33 | 42.5 | 42.9 |
| bg_color | 8.33 | 8.33 | 8.33 |
| follow_state / missing_follow | 91.7 / 105.4 | | |

#### Subtler icon changes (synthetic probes on the bell icon, `gridexp2/subtle_icon_probes.json`)

| Probe | Overall MAE | cell:24 (worst / alignment range) | 4×12 | component_metrics (bell) |
| ----- | ----------- | --------------------------------- | ---- | ------------------------ |
| 1 px horizontal shift | 0.083 | **FAIL** 7.15 (5.54–20.9) | PASS (FN) | dx 1.5 lp (detected) |
| stroke 30 % lighter | 0.032 | **PASS (FN)** 2.15 (2.15–7.94) | PASS (FN) | IoU 1.0, ink ratio 1.00 (not detected) |
| stroke 15 % lighter | 0.016 | **PASS (FN)** 1.07 (1.07–3.97) | PASS (FN) | not detected |
| recolour (+40 red on the ink) | 0.009 | **PASS (FN)** 0.62 | PASS (FN) | IoU 0.92 (weak) |

#### Conclusion

1. In this environment `cell:24` removes the icon_swap false negative and catches a 1 px icon shift. No false positive appeared on any available positive control: 4 repeat captures, at every grid alignment.
2. **It does not catch subtle icon opacity, weight or colour changes.** Neither does the 4×12 grid, nor `component_metrics.py`, whose ink normalisation is colour-invariant by design. This remains an **open limitation**. A candidate remedy, an absolute ΔE2000 check on each icon's ink pixels, is not implemented.
3. **Before `cell:24` can become a gate:**
   - measure the repeat-capture noise floor on at least one more machine (different GPU or OS) and confirm it stays below 4.0 per 24 px cell at every alignment;
   - get owner review of this evidence.
4. Grid size does not change the advisory status of `cross_environment`. It also narrows that profile's noise margin: the direct pipeline's worst cell MAE goes from 7.66 to 17.82, against a limit of 45.

## Reproduce

```bash
bash calib/shoot.sh <name> <dpr> [--block <path>] [--tap x,y] [INSET=<lp>]
python3 visual_diff.py --reference calib/caps/base.png --output calib/caps/<name>.png --out <dir> \
  --dpr 0.6565 --criteria templates/thresholds.json --profile <controlled|cross_environment> \
  --regions regions3.json --shift-search 4
```

The capture harness (`shoot.sh`, `calcap.mjs`) and the calibration captures were kept outside the repository and are not committed.
