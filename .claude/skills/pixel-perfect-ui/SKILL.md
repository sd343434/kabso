---
name: pixel-perfect-ui
description: Pixel-perfect UI reconstruction for Kabso Live — reproduce a supplied reference screenshot as literally as possible inside the existing Flutter app (no redesign), then prove it with a real capture, a measured visual diff, an iterative fix loop, regression checks and an honest report. Use when the user gives a screenshot and asks to "match this", "make it look exactly like this", "copy this screen" or "pixel-perfect". Entry point that runs the repo's pixel-perfect-ui-workflow tooling and gates A–G.
---

# Pixel-perfect UI reconstruction

The reference screenshot is the visual specification. Your job is **faithful implementation, not
creative interpretation**: do not redesign, modernize, "improve", or swap in a similar design.

This skill is the short entry point. The detailed methods and the tools already live in the repo;
use them instead of re-inventing them:

| Need | Use |
| ---- | --- |
| Order, gates A–G, final verdict | `.claude/skills/pixel-perfect-ui-workflow/SKILL.md` |
| Measuring the reference, writing the spec | `pixel-perfect-reference-analyzer` |
| Images, icons, fonts | `asset-and-typography-forensics` |
| Flutter implementation rules | `reference-to-flutter-implementer` |
| Arabic RTL / English LTR checks | `rtl-ltr-visual-specialist` |
| Capture, diff, fix/retest loop | `screenshot-diff-and-visual-regression` |
| UI work without a reference, or a composite board | `elite-design-engineering` |

Tools (all under `.claude/skills/pixel-perfect-ui-workflow/`):
`scripts/check_env.sh`, `scripts/measure.py`, `scripts/capture_web.mjs`, `scripts/visual_diff.py`,
`scripts/component_metrics.py`, `templates/reference-spec.md`, `templates/fidelity-report.md`,
`templates/thresholds.json` (profiles `controlled` and `cross_environment`, the latter advisory only).

## Project rules that always apply

Read `CLAUDE.md`, `docs/AI_WORKFORCE_BOARD.md` (decisions), `docs/contracts/CONVENTIONS.md` and
`docs/contracts/design-tokens.json` before coding. In particular:

- **Public repository (D40).** Third-party reference screenshots, and anything showing real users,
  stay in the scratchpad. Never commit them or put them in a published artifact.
- **A screenshot is not permission** to copy another product's logo, wordmark, mascot, proprietary
  icons, illustrations or user photos. Match layout, proportions and interaction patterns; use
  Kabso assets or ask for them. List what was not copied in the report.
- **Keep apart:** (1) visual fidelity at the reference viewport, (2) functional behaviour (real
  routing, Riverpod state, repositories, API, honest loading/empty/error states — never fixtures in
  production code), (3) responsive adaptation (360×800, text scale, ar RTL and en LTR).
- **No invented measurements.** If the reference file, viewport or DPR is unknown, stop at gate A
  and ask. Never assume "393×852@3".
- Do not commit, push, merge or deploy without the owner's explicit permission. Do not weaken
  tests or lower thresholds.

## Workflow

Run `bash .claude/skills/pixel-perfect-ui-workflow/scripts/check_env.sh` first and note which tools
are really present.

### A. Reference analysis (gate A)

1. Use the actual image file, not a description of it. If the image only exists in the chat, save it
   to the scratchpad first, or ask the user to resend it as a file.
2. `python3 .claude/skills/pixel-perfect-ui-workflow/scripts/measure.py info <ref> --logical-width <W>`
   gives the sha256, pixel size and the DPR inferred from the device's logical width. Examples:
   iPhone 15/16 = 393, iPhone 15 Pro Max = 430, typical Android = 360 or 412.
3. Record:
   - the locale and direction;
   - the target route and the app state;
   - what is visible, clipped, fixed, sticky or scrollable;
   - any open sheet, modal or keyboard;
   - who authorized the image and for what use.
4. If the image is a composite of several phones, isolate one screen before measuring it.

### B. Repository reconnaissance

- **Stack:** Flutter app `apps/mobile`, using GoRouter, Riverpod, gen-l10n (with `app_ar.arb` as the template), tokens and widgets from `design_system/`, and repositories under `features/*/data`.
- **Existing code:** find the existing route, screen and widgets. Reuse components that already match. Change the smallest set of files, and do not touch global theme or tokens unless the reference requires it (then test every affected screen).
- **Fonts and icons:** the bundled fonts are Readex Pro for Arabic and the app's Latin font. Check `pubspec.yaml`, `assets/`, and the existing icon sets before choosing anything.

### C. Measured specification (gate B)

Fill in a copy of `templates/reference-spec.md` before you write any code. Every number is tagged
**M** (measured, with the `measure.py` command used) or **E** (estimate, with the reason).

- **Geometry and colour.** Measure with `measure.py`:
  - `hline` and `vline` runs for edges, gaps and padding;
  - `bbox` for component boxes;
  - `sample` on flat areas for colours (never on anti-aliased edges);
  - `palette` for gradients and photos;
  - `crop --scale 8` for radii.
- **Logical units.** Convert pixels with the recorded DPR. For element `(x, y, w, h)` in a W×H image, also note the ratios `x/W`, `y/H`, `w/W`, `h/H`. Round only in code.
- **Typography.** Measure cap height, x-height and line pitch, then derive the font size and weight. These stay **E** until a render confirms them.
- **Assets.** List every image, icon and font. Then:
  - mark each one as reused, Kabso-owned replacement, missing, or not to be copied;
  - do not use emoji or Unicode characters in place of designed icons;
  - report missing assets instead of silently approximating them.

### D. Literal implementation (gate C)

- Implement from the spec, not from memory, on the existing architecture: real providers, real repositories, l10n strings (no hard-coded user-facing text), and `EdgeInsetsDirectional` / `AlignmentDirectional`.
- Preserve behaviour, validation, accessibility (semantics labels, 44 pt targets) and business logic.
- Add no gradients, shadows, borders, radii, animations or components that are absent from the reference. Remove nothing that is visible in it.
- Review `git diff --stat`: unrelated screens must be unchanged.

### E. Real capture (gate D)

Capture the running app at the reference viewport, DPR, locale and app state. Use the framework's
real runtime:

- **Flutter (this repo): real app in Chromium.** This is the primary method.
  1. Build with `flutter build web --profile --dart-define=API_BASE_URL=http://localhost:<port>`.
  2. Serve it with `python3 -m http.server <port> -d build/web`.
  3. Run `node .claude/skills/pixel-perfect-ui-workflow/scripts/capture_web.mjs --url http://localhost:<port>/#/<route> --out <scratch>/actual.png --width <W> --height <H> --dpr <DPR> --locale ar|en --wait 4000`.
  4. The app state must be real. Use the local API with seeded data (signed-in user, live room…). For sheets and dialogs, drive the UI with a small Playwright script that uses the same browser and viewport. Playwright is installed globally (`/opt/node22/lib/node_modules/playwright`).
- **Flutter goldens: regression only.** The repo's golden tests are `apps/mobile/test/goldens/*`, using `expectScreenGolden` in `test/helpers/golden.dart` with pinned viewports `phone` 393×852 and `android` 360×800.
  - Use them to lock the result, and update them with `flutter test <file> --update-goldens` only for intended changes. Give the reason for each update.
  - A golden is not a capture of the real app at the reference viewport, so it does not satisfy gate D.
- **Other stacks.** For a web stack, use Playwright only if it is installed. Otherwise use the repo's own visual-regression tooling. Record the environment in the capture JSON.
- **Never compare mismatched captures.** Do not compare a different viewport, scale, locale or state against the reference. If the real state cannot be reached (for example, no backend), the gate is blocked; say so.

### F. Visual diff (gate E)

```
python3 .claude/skills/pixel-perfect-ui-workflow/scripts/visual_diff.py \
  --reference <ref> --output <scratch>/actual.png --out <scratch>/diff-<n> \
  --criteria --profile cross_environment [--regions regions.json] [--shift-search 8]
```

- **Outputs to keep:** `metrics.json` (MAE, SSIM, changed-pixel %), the heatmap, the 50 % overlay, the side-by-side image, and the worst regions. Use `component_metrics.py` for per-component geometry, typography, icon and colour errors.
- **Classify each worst region** as layout, asset, typography, colour, or environment (font rasterization, emoji set, third-party photo).
- **Do not hide differences.** Never edit either image. Never use broad masks to pass. A passing metric never overrides an obvious visual defect.

### G. Correction loop

Fix in this order, then recapture and re-diff after every iteration:

1. viewport and page geometry;
2. section positions;
3. component sizes and spacing;
4. assets and image crops;
5. typography and wrapping;
6. colours and surfaces;
7. borders, radii and shadows;
8. sub-pixel alignment.

- Do not polish shadows while blocks are misplaced. Fix root causes (constraints, font metrics, crops), not arbitrary offsets.
- Record every iteration in the report table. Stop when the criteria pass, or when a documented blocker remains (unknown font, missing or unauthorized asset, renderer difference).

### H. Regression checks (gate F)

Run these in `apps/mobile`, and capture each real exit code:

```
dart format --set-exit-if-changed lib test
flutter analyze
flutter test            # 0 failures, 0 skipped
```

- **Goldens:** update them only for intended changes, with reasons.
- **Locales and sizes:** check both ar RTL and en LTR at the reference viewport and at 360×800, and at a large text scale.
- **Bidirectional text:** check directional icons and mixed Arabic and Latin text.

### I. Honest report (gate G)

Fill in `templates/fidelity-report.md` and report:

1. The reference's dimensions, sha256 and target viewport/DPR/locale. Say which values were measured and which were assumed.
2. The files changed.
3. The assets and fonts reused, and what was not copied and why.
4. A summary of the implementation.
5. The comparison results per iteration (metrics, profile, artifact paths in the scratchpad).
6. The remaining differences, each with its cause.
7. The tests run, with their actual outcomes.
8. Whether each gate is met.

For every check, give its status: **not tested**, **tested and failed**, **tested and passed**,
**advisory**, or **environment-limited**. Never report an unexecuted test or comparison as done.
Never write "pixel-perfect" unless the `controlled` profile was used and changed-pixel % is 0.
Compiling, passing unit tests, or "looks close" is not completion.
