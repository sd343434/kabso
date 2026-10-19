# Framework adapters

The workflow and gates are the same for every stack; only IMPLEMENT and CAPTURE change. Use the
conventions `detect_stack.py` reports — never introduce a competing router, state library, styling
system or design system.

## Flutter (Kabso Live)
- Implement with `reference-to-flutter-implementer` (GoRouter, Riverpod, gen-l10n, `KPalette` /
  `KSpacing` / `KRadius` tokens, design-system components, `AppIcons`).
- Capture: web `--profile` build from a **scratch copy** of `apps/mobile` (never add `web/` to the
  repo), static server, `capture_web.mjs --web-dir … --locale ar|en --width 393 --height 852 --dpr 3`.
  Debug builds may emulate phone insets with `--dart-define=KABSO_EMULATE_PHONE_INSETS=true`.
- Regression: goldens via `test/helpers/golden.dart` (real fonts, pinned viewports), widget tests for
  overflow, semantics, RTL order and text scale.
- Not available here: Android emulator, iOS simulator, devices → ENVIRONMENT-LIMITED.

## React / Next.js
- Implement in the existing component library and styling system (Tailwind config, CSS modules,
  styled-components, MUI…); route with the app's router (`app/` or `pages/` for Next.js); text through
  the existing i18n library; images through `next/image` (Next.js) with explicit sizes.
- RTL: `dir="rtl"` on `<html>` from the locale, logical CSS properties (`margin-inline-start`,
  `inset-inline-end`), no mirrored media.
- Capture: run the dev server (`npm run dev` / the `dev` script `detect_stack.py` prints) and use
  Playwright at the reference viewport and `deviceScaleFactor`, `locale`, `colorScheme`,
  `reducedMotion: 'reduce'`; wait for fonts (`document.fonts.ready`) and network idle.
  `capture_web.mjs --url http://localhost:3000/<route>` works for any served page.
- Regression: the project's visual tests if present (Playwright `toHaveScreenshot`, Storybook +
  Chromatic); otherwise `visual_diff.py` against an approved capture with the `controlled` profile.

## Other stacks
Run the stages; if no supported runtime can be captured here, mark CAPTURE/COMPARE as
ENVIRONMENT-LIMITED and say what is needed (device, emulator, credentials). Never substitute a
mock-up render for a capture of the real app.
