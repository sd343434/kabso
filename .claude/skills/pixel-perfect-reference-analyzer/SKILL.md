---
name: pixel-perfect-reference-analyzer
description: Analyze an authorized reference screenshot BEFORE any implementation — record the image and viewport, split the screen into regions, measure geometry/colours from pixels, and write a structured spec that separates measured facts from estimates. Use as step 1 of pixel-perfect-ui-workflow or whenever asked to measure or spec a screenshot.
---

# Reference analyzer

Output: a filled-in copy of `.claude/skills/pixel-perfect-ui-workflow/templates/reference-spec.md`.
Implementation does not start until this spec exists (gate B).

Tools (verified present; run `scripts/check_env.sh` to re-check):
`python3 .claude/skills/pixel-perfect-ui-workflow/scripts/measure.py <cmd> <img> ...`.

## Procedure

1. **Record the reference (gate A).**
   - Run `measure.py info <img> --logical-width <W>` → sha256, pixel size, alpha, and the DPR inferred from W.
   - The logical width comes from the device: an iPhone 393/390/430, Android 360/412. If unknown, mark the DPR **E** and ask.
   - Write down the locale, the direction, the target Kabso route, the app state, and who authorized the image and for what use.
   - If the image shows third-party people, names or brands, it stays in scratch (`/tmp/.../scratchpad/...`) and never enters git or a published artifact.
2. **Find the insets.**
   - Status bar: run `vline` down the centre and the edges. Its end is where the colour run changes.
   - Home indicator and bottom nav: same method from the bottom.
   - Record the top and bottom insets in px and logical px.
3. **Map the regions**: header, tabs, sub-tabs, content grid or list, floating elements, nav. Give each one an ID and a box (`bbox` with the background colour, or `hline`/`vline` runs).
4. **Measure each component.**
   - Use `hline` and `vline` runs through its centre to get edges, widths and gaps (padding = the gap between the container edge and the content bbox).
   - Corner radius: zoom with `crop --scale 8` and count the curve's extent in px. Mark it **M** only if the curve is clean; otherwise **E** with a ± range.
   - Colours: `sample` at flat areas (never on anti-aliased edges); `palette` for gradients and photos.
   - Opacity: sample the same overlay over two known backgrounds, then solve for alpha. Otherwise **E**.
5. **Typography.** Always **E** unless verified.
   - Measure cap height, x-height and line pitch in px, then convert to logical units.
   - Estimate the font size from cap height ÷ the font's cap-height ratio (Inter ≈ 0.727, IBM Plex Sans Arabic: check the font file).
   - Weight: compare stem width with the bundled fonts at the same size.
   - Hand font-family identification to `asset-and-typography-forensics`.
6. **Images and icons.** Record the crop aspect, the fit (cover/contain), the focal point, the icon box size and the stroke width. Hand assets to `asset-and-typography-forensics`.
7. **Hierarchy and states.** Write out the component tree. Note the selected, pressed and disabled visuals you can see, and what is not visible (and so unknown).
8. **Uncertainty.** List what could not be measured and why: JPEG artefacts, scaling, motion blur, content overlap, unknown font.

## Rules

- Never present an estimate as measured. Every number carries **M** (plus the `measure.py` command) or **E** (plus the reason).
- Measure in pixels and convert with the recorded DPR. Round only in the implementation, never in the spec.
- Do not "correct" the reference to Kabso tokens here. Record what it is; the implementer decides the mapping.
- Do not start implementing during this step.
