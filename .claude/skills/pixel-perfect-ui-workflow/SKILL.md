---
name: pixel-perfect-ui-workflow
description: Orchestrates faithful implementation of a Kabso Live Flutter screen from an authorized reference screenshot — REFERENCE → MEASURE → SPECIFY → IMPLEMENT → CAPTURE → COMPARE → FIX → RETEST → REPORT with gates A–G. Use whenever the user supplies a screenshot and asks to match it, reproduce it, or make a screen "look like" it. Delegates to pixel-perfect-reference-analyzer, asset-and-typography-forensics, reference-to-flutter-implementer, rtl-ltr-visual-specialist and screenshot-diff-and-visual-regression.
---

# Pixel-perfect UI workflow (orchestrator)

This skill owns the **order, gates and final verdict**. The specialist skills own the detailed methods:

| Step | Skill | Output |
| ---- | ----- | ------ |
| REFERENCE, MEASURE, SPECIFY | `pixel-perfect-reference-analyzer` | reference spec (from `templates/reference-spec.md`) |
| (assets and fonts inside SPECIFY) | `asset-and-typography-forensics` | asset table and font findings |
| IMPLEMENT, FIX | `reference-to-flutter-implementer` | code on a feature branch |
| (both directions) | `rtl-ltr-visual-specialist` | RTL/LTR checklist results |
| CAPTURE, COMPARE, RETEST | `screenshot-diff-and-visual-regression` | `metrics.json` and diff images per iteration |
| REPORT | this skill | `templates/fidelity-report.md`, filled in |

Shared tooling lives in `.claude/skills/pixel-perfect-ui-workflow/`:

| Path | What it does |
| ---- | ------------ |
| `scripts/check_env.sh` | Lists the tools that are really installed. Run it first. |
| `scripts/measure.py` | Pixel measurement: info, sample, hline/vline runs, bbox, palette, crop. |
| `scripts/capture_web.mjs` | Real-app capture in headless Chromium at a fixed viewport, DPR and locale. |
| `scripts/visual_diff.py` | Side-by-side, 50 % overlay, heatmap, MAE, SSIM, changed-pixel %, region ranking and pass/fail. `--regions` adds named-region metrics; `--shift-search N` reports the global and per-region displacement (dx, dy), never applied. |
| `scripts/component_metrics.py` | Per-component metrics by category: geometry (bbox centre/size error), typography (ink ratio, shape error, width), icons (IoU, stroke width), images (MAE/SSIM/ΔE), colour (CIEDE2000). |
| `templates/thresholds.json` | Acceptance profiles: `controlled` and `cross_environment` (**advisory only**: its verdict is marked `advisory` and is never a release gate; see `templates/CALIBRATION.md`). |
| `templates/CALIBRATION.md` | D7 calibration of both profiles: positive and negative controls, false negatives, limits. |
| `scripts/tests/` | Tooling regression tests (`python3 -m unittest discover -s .claude/skills/pixel-perfect-ui-workflow/scripts/tests -v`). |
| `templates/reference-spec.md` | The specification template. |
| `templates/fidelity-report.md` | The final report template. |

## Non-negotiables (Kabso project rules)

- **The repository is public (board decision D40).**
  - Third-party reference screenshots, and anything showing real users, stay OUTSIDE git, in scratch only.
  - Commit only text specs with no names or photos, plus screenshots of Kabso's own app.
- **A screenshot is not permission to copy branding.**
  - Never reproduce another product's logo, wordmark, mascot, proprietary icons, illustrations or user photos.
  - Layout, proportions and interaction patterns may be matched only as far as the owner authorized.
  - Use Kabso assets, or ask for them.
- **No fabricated production data.**
  - Populated states come from real local API data, or from test fixtures labelled as fixtures and reachable only in tests or the `!kReleaseMode` gallery.
- **Keep three things apart:** (1) visual reference fidelity, (2) functional behaviour (routing, state, API), (3) responsive adaptation to other widths. Fidelity work never breaks (2), and (3) is checked separately at 360×800.
- **Process:** work on a feature branch, run all repo checks, and do not merge or push without the owner's approval.

## Procedure and gates

Run `bash .claude/skills/pixel-perfect-ui-workflow/scripts/check_env.sh` from the repo root and note which tools are present.

| Gate | Pass condition | If it fails |
| ---- | -------------- | ----------- |
| **A** Reference verified | Reference file exists. sha256, pixel size, logical viewport, DPR, locale, app state and authorization are recorded (analyzer §1). | Stop. Ask for the missing facts. Never "assume 393×852@3". |
| **B** Spec complete | Every region and component needed for the target has M/E-tagged values. Assets are inventoried. Things that must not be copied are listed. | Do not implement. |
| **C** Real architecture | Code changes use the existing router, Riverpod, l10n, repositories, tokens and design-system widgets. No production fixtures. Unrelated screens are unchanged (`git diff --stat` reviewed). | Rework. |
| **D** Real capture | Screenshot of the running app (`capture_web.mjs`, or a device) at the reference viewport, DPR and locale, in the reference's app state. Capture JSON recorded. | Do not compare. |
| **E** Measured | `visual_diff.py` run with `--criteria`. `metrics.json`, heatmap, overlay and side-by-side saved. Worst regions classified as layout / colour / typography / asset / environment. | — |
| **F** Regressions | `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test` (0 skipped), goldens updated with reasons, both locales and 360×800 checked by `rtl-ltr-visual-specialist`. | Fix before reporting. |
| **G** Reported | Fidelity report filled in. It lists every remaining discrepancy with its cause and states what the metrics do not prove. | — |

### The loop

```
A → B → implement → D → E ─┬─ criteria pass, no significant unexplained discrepancy → F → G
                           └─ else: fix the highest-impact region (layout > asset > typography > colour) → D → E …
```

- Do not stop after the first screenshot.
- Iterate until the criteria pass, or until a documented blocker remains. Examples of blockers: an unknown font, missing assets, third-party photos, a renderer difference.
- Record every iteration in the report table.

### What "done" means

- **Not done:** compiling, passing unit tests, or "looks close".
- **Done:** gates A–G are met, the numbers have been reported, and the remaining differences are explained.
- **No reference image:** say that similarity cannot be measured, and make no similarity claim.
- **Never write "pixel-perfect"** unless the run used the `controlled` profile and changed@16 is 0 %.
