---
name: elite-design-engineering
description: Master workflow for building or changing any UI screen to a production standard — detects the stack (Flutter, React/Next.js, other), audits the existing architecture, turns a reference (screenshot, Figma export, composite board) or the product's own design system into a measured spec, acquires and documents assets, implements on the existing architecture, runs the real app, captures Arabic RTL and English LTR screenshots, compares, fixes and retests, then reports with evidence and an explicit verification status. Use for "implement this design", "make this screen look like…", "polish/redo this screen", or any UI work that must be verified visually. Orchestrates pixel-perfect-ui-workflow and its specialist skills.
---

# Elite design engineering (coordinator)

This skill owns the **order, the gates, the status vocabulary and the final report**. The detailed
methods live in the specialist skills; do not restate them, invoke them.

| Stage | Owner | Tools / outputs |
| ----- | ----- | --------------- |
| REFERENCE, MEASURE, SPECIFY | `pixel-perfect-reference-analyzer` | `split_composite.py`, `measure.py` → spec from `pixel-perfect-ui-workflow/templates/reference-spec.md` |
| ASSETS (fonts, icons, images) | `asset-and-typography-forensics` (+ `realistic-visual-assets` when installed) | `templates/asset-provenance.md` |
| IMPLEMENT, FIX | `reference-to-flutter-implementer` (Flutter) · `references/framework-adapters.md` (other stacks) | code on the current feature branch |
| RTL/LTR (during IMPLEMENT and RETEST) | `rtl-ltr-visual-specialist` | its checklist, both locales |
| RUN, CAPTURE, COMPARE, RETEST | `screenshot-diff-and-visual-regression` | `capture_web.mjs`, `visual_diff.py`, `component_metrics.py`, `triage_diff.py` |
| Gates A–G for reference fidelity | `pixel-perfect-ui-workflow` | `templates/thresholds.json`, `templates/fidelity-report.md` |
| Quality beyond pixels, REPORT | this skill | `templates/design-quality-checklist.md` |

Scripts: `.claude/skills/pixel-perfect-ui-workflow/scripts/` (measure, capture, diff — existing,
tested) and `.claude/skills/elite-design-engineering/scripts/` (detect_stack, split_composite,
triage_diff — this skill). Run every command from the repo root.

## Stage 0 — AUDIT (always, before touching code)

```bash
git status --short && git branch --show-current          # preserve uncommitted work; never reset/clean
bash .claude/skills/pixel-perfect-ui-workflow/scripts/check_env.sh      # what can really run here
python3 .claude/skills/elite-design-engineering/scripts/detect_stack.py .   # framework + conventions, with file evidence
```

Then read `CLAUDE.md`, the project's decision log/contracts, and the existing design system (tokens,
components) that `detect_stack.py` lists. Record: framework, router, state, l10n + locales, tokens,
fonts, asset folders, golden/visual tests, and which capture path exists. **Use only the
conventions found**; never add a second router, state library, design system or icon set.

Decide the **mode**:
- **Reference mode** — the user supplied an authorized screenshot/Figma export: fidelity first (gates A–G).
- **System mode** — no reference: derive the screen from the existing design system and product
  requirements; never invent a new visual identity. Skip gates A/B/E-fidelity; every other gate applies.
- **Third-party reference** — reproduce layout and interaction patterns only; never copy logos,
  wordmarks, mascots, proprietary icons, photos or user content (`CLAUDE.md`).

## Stage 1 — REFERENCE → MEASURE → SPECIFY

1. Record the reference (sha256, pixel size, source, device, locale, authorization) with
   `measure.py info`. Third-party or real-user images stay in scratch, never in git.
2. **Composite?** If the image may hold more than one screen (boards, side-by-side mock-ups,
   marketing collages), split it first:
   `python3 .claude/skills/elite-design-engineering/scripts/split_composite.py REF.png --out SCRATCH/screens`
   then confirm every box edge with `measure.py hline/vline`. Measure each screen separately.
   The logical width comes from the recorded device, not from the box (the script lists the DPR each
   width would imply; mark the choice M or E).
3. Run `pixel-perfect-reference-analyzer` per screen: regions, geometry, typography (E unless
   verified), colours, radii, shadows, image crops/focal points, icons and hit targets, fixed vs
   scrolling parts, overlays/sheets/keyboard, all states (loading/empty/error/populated), RTL/LTR.
   Every value is **M** (with the command) or **E** (with the reason). No invented numbers.
4. Write the spec into the scratch run folder and show it before implementing large screens.

## Stage 2 — ASSETS

Run `asset-and-typography-forensics`. Order: existing approved assets → user-supplied → authorized
library → configured generator (only with the owner's consent when it costs money) → labelled
dev/test fixtures. Detect integrations; never assume an API key or MCP server works — try it and
report the real error. Record every new file with `templates/asset-provenance.md` (source, date,
licence status, dimensions, checksum, dev-only vs production). Never invent URLs, licences or
results. A missing asset is reported, not approximated with a look-alike.

## Stage 3 — IMPLEMENT

Flutter: `reference-to-flutter-implementer`. Other stacks: `references/framework-adapters.md`.
Rules: tokens and existing components first; translations, never literals; real routing, state and
honest states (no production fixtures, no fake success); semantics/labels; logical (start/end)
geometry; text that can grow (no fixed text heights); add or update tests and goldens with the
change. Fix layouts at the constraint/metric/crop that is wrong — never with arbitrary pixel offsets.

## Stage 4 — RUN → CAPTURE → COMPARE

Follow `screenshot-diff-and-visual-regression`. Capture the **real running app** (Flutter: web
`--profile` build from a scratch copy + `capture_web.mjs`; web stacks: dev server + Playwright) at the
reference viewport and DPR, in each locale, with documented insets, theme, text scale and data.
Golden/widget renders are regression evidence, not device screenshots.

```bash
python3 .claude/skills/pixel-perfect-ui-workflow/scripts/visual_diff.py --reference REF.png --output OUT.png \
  --out RUN/diff-ar --dpr 3 --criteria .claude/skills/pixel-perfect-ui-workflow/templates/thresholds.json \
  --profile cross_environment --regions RUN/regions.json --shift-search 6
python3 .claude/skills/elite-design-engineering/scripts/triage_diff.py RUN/diff-ar/metrics.json --md RUN/triage-ar.md
```

`triage_diff.py` merges hot grid cells into ranked defect clusters (critical/major/minor relative
to the profile's region limit), labels them with named regions, and prints the status. Then **look
at the side-by-side, overlay and heatmap yourself** and classify each defect: layout · typography ·
asset/crop · colour · state/behaviour · environment (renderer, font hinting, photo content).

Without a reference (system mode), capture both locales and the second viewport and review them
against `templates/design-quality-checklist.md`; for regressions compare against the previous
approved capture with the `controlled` profile.

## Stage 5 — FIX → RETEST (loop)

Fix the highest-impact real defect first (layout > asset > typography > colour), smallest
responsible unit, with a regression test where practical. Recapture, re-diff, re-triage. Recheck
the related screens and the other locale/viewport. Stop when the criteria pass and no significant
unexplained defect remains, or a documented blocker (unknown font, missing asset, renderer
difference) is all that is left. Never loosen thresholds, widen masks or edit either image to pass.

## Stage 6 — VERIFY (all must be true before "verified")

- Real runtime captured; viewport, DPR, locale, insets, theme, text scale and data recorded.
- Comparison executed (reference mode) or review checklist completed (system mode).
- Arabic RTL **and** English LTR checked (`rtl-ltr-visual-specialist`), 393×852 and 360×800,
  text scale 1.0/1.3 (2.0 for text-heavy screens); no overflow.
- Project checks green: format, analyze/lint, the full test suite (0 skipped), goldens updated
  with the reason.
- `templates/design-quality-checklist.md` has no open critical item.

## Status vocabulary (use exactly these words in reports)

| Status | Meaning |
| ------ | ------- |
| NOT TESTED | not executed (say why) |
| TESTED – FAILED | executed; fails (give the numbers or the test) |
| TESTED – PASSED | executed; a release-gate criterion passed (`controlled` profile, tests) |
| ADVISORY | executed with an advisory profile (`cross_environment`) or a manual review: evidence only |
| ENVIRONMENT-LIMITED | could not run here (device, emulator, network, credentials); never reported as passed |

Never write "pixel-perfect" unless the `controlled` profile ran with changed@16 = 0 %.

## Stage 7 — REPORT

Use `pixel-perfect-ui-workflow/templates/fidelity-report.md` (reference mode) and add: stack and
conventions found, assets with provenance, the triage tables per locale, the quality checklist
result, the exact commands run and their results, the status of every gate, remaining defects with
cause, what the metrics do not prove, and `git status`. **Do not commit, push, merge or deploy**
unless the owner explicitly asks.

## Self-test (run after changing any script)

```bash
python3 -m unittest discover -s .claude/skills/pixel-perfect-ui-workflow/scripts/tests
python3 -m unittest discover -s .claude/skills/elite-design-engineering/scripts/tests
```

The second suite includes an end-to-end check that `visual_diff.py` + `triage_diff.py` pass two
identical renders and catch, locate and rank a deliberately moved card.

## Sample invocation

> /elite-design-engineering Implement the attached reels screen (iPhone 15 export, 393×852, owner-
> authorized) in Kabso Live: Arabic and English, real data states, no commit.

> /elite-design-engineering Polish the Discover screen to the design system (no reference); verify
> ar/en at 393×852 and 360×800 and report.
