# Acceptance-profile calibration (D7), 2026-10-16

**Status:**
- `controlled` is partially calibrated: with the shipped 4×12 grid it detects 6 of 7 defects (see finding 2). A finer grid detecting all 7 is an **unmerged experiment** (finding 6).
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

### 6. Grid-size experiment (branch `claude/kl-054-grid-experiment`, local worktree, NOT merged)

**Change tested:**
- `--grid` also accepts `cell:N` (about N px per cell) and `cell:Nlp` (logical px; needs `--dpr`).
- The experiment's default is `cell:32`, and the grid used is recorded in `metrics.json` (`inputs.grid`).
- Thresholds are unchanged.

**Run:** all 13 cases × 6 grids × 2 profiles.

Each cell shows the verdict and the worst cell MAE. *oos* marks an environment positive that is outside the controlled scope, where FAIL is expected.

#### `controlled` profile

| Case | 4×12 | 8×24 | cell:32 (9×18) | cell:24 (11×24) | cell:16 (17×36) | 16×48 |
| ---- | ---- | ---- | -------------- | --------------- | --------------- | ----- |
| rep1, rep2, rep3, nosubpixel | PASS 0.0 | PASS 0.0 | PASS 0.0 | PASS 0.0 | PASS 0.0 | PASS 0.0 |
| dpr2 *(oos)* | FAIL 3.3 | FAIL 8.0 | FAIL 5.8 | FAIL 7.7 | FAIL 9.1 | FAIL 11.4 |
| direct *(oos)* | FAIL 7.7 | FAIL 11.7 | FAIL 12.0 | FAIL 17.8 | FAIL 23.6 | FAIL 26.1 |
| shift2lp | FAIL 19.2 | FAIL 34.4 | FAIL 28.7 | FAIL 38.2 | FAIL 45.6 | FAIL 67.9 |
| weight_fallback | FAIL 2.3 | FAIL 7.5 | FAIL 7.2 | FAIL 10.0 | FAIL 19.6 | FAIL 20.8 |
| follow_state | FAIL 68.4 | FAIL 106.0 | FAIL 114.8 | FAIL 109.4 | FAIL 152.1 | FAIL 156.4 |
| missing_follow | FAIL 78.1 | FAIL 121.9 | FAIL 131.1 | FAIL 127.5 | FAIL 180.6 | FAIL 179.2 |
| icon_swap | **PASS 3.9 (FN)** | FAIL 15.4 | FAIL 25.4 | FAIL 11.9 | FAIL 31.9 | FAIL 41.1 |
| image_swap | FAIL 37.3 | FAIL 41.6 | FAIL 41.6 | FAIL 42.3 | FAIL 43.8 | FAIL 43.6 |
| bg_color | FAIL 8.3 | FAIL 8.3 | FAIL 8.3 | FAIL 8.3 | FAIL 8.3 | FAIL 8.3 |
| **False negatives / false positives** | 1 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |

**Which check catches each defect:**
- icon_swap at every finer grid: `max_region_mae` only.
- weight_fallback: `changed_pct@32` at every grid, plus `max_region_mae` at the finer grids.

#### `cross_environment` profile (advisory)

| | 4×12 | 8×24 | cell:32 | cell:24 | cell:16 | 16×48 |
| - | ---- | ---- | ------- | ------- | ------- | ----- |
| False negatives (of 7 negatives) | 5 | 5 | 5 | 5 | 4 | 4 |
| False positives | 0 | 0 | 0 | 0 | 0 | 0 |

At cell:16 and 16×48, only shift2lp moves from a false negative to a correct fail.

Grid size does not fix the cross-environment limitation, and it narrows the noise margin. The worst cell MAE of the `direct` pipeline rises from 7.7 at 4×12 to 26.1 at 16×48, against a region limit of 45.

#### Grid-alignment robustness

The cell where a defect lands depends on where the grid lines fall. The table gives the worst cell MAE over grid offsets in 2 px steps (`gridexp/alignment.json`). The worst-case column takes the least favourable offset; the controlled limit is 4.0.

| Case | cell:32 worst / best case | cell:24 | cell:16 |
| ---- | ------------------------- | ------- | ------- |
| icon_swap | **6.27** / 22.3 | 11.1 / 39.6 | 25.1 / 86.8 |
| weight_fallback | 3.30 / 7.05 | 4.81 / 11.6 | 9.46 / 22.7 |
| rep1 | 0 / 0 | 0 / 0 | 0 / 0 |

#### Reading

- In the controlled environment, any grid at or below about 32 px removes the icon_swap false negative without a false positive.
- cell:32 keeps only a 1.6× worst-case margin. **Proposed, pending review: `cell:24`** (at least 2.8×).
- The controlled noise floor on other machines is unmeasured. Smaller cells amplify any non-zero noise, so a second machine should be measured before choosing cell:16.

The experiment adds 8 tests (`test_visual_diff_grid.py`). They pass in the worktree, and 7 of them fail or error against the trial's `visual_diff.py`.

## Reproduce

```bash
bash calib/shoot.sh <name> <dpr> [--block <path>] [--tap x,y] [INSET=<lp>]
python3 visual_diff.py --reference calib/caps/base.png --output calib/caps/<name>.png --out <dir> \
  --dpr 0.6565 --criteria templates/thresholds.json --profile <controlled|cross_environment> \
  --regions regions3.json --shift-search 4
```

Scratch harness: `/tmp/claude-0/-home-user/cf29122e-494f-5122-805c-09d67c75af5d/scratchpad/a1/trial-profile/calib/` (`shoot.sh`, `calcap.mjs`, `cases.json`, `results.json`, `component_separation.json`).
