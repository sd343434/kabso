# Arabic and English, RTL and LTR

Authoritative: `apps/mobile/l10n.yaml`, `apps/mobile/lib/l10n/app_ar.arb` (the template) and
`app_en.arb`, `apps/mobile/README.md` (language, digits, generated code), and the admin and studio
`src/i18n*.ts` files.

## Mechanics

- Mobile: `gen-l10n` with `arb-dir: lib/l10n` and `template-arb-file: app_ar.arb`; output in
  `lib/l10n/gen/` (committed, board D5). A new string goes into **both** ARB files, then run
  `flutter gen-l10n` (or `flutter pub get`). Include the generated files in the change; committing them
  still needs the owner's approval.
- Arabic is the template and the default language. The device language picks English only for `en*`
  (README, "Language").
- Digits: dates, counters and relative times go through `lib/core/format/k_format.dart`, with Western
  digits in both locales (README, "Digits").
- Admin and studio: Arabic and English dictionaries in `src/i18n.ts`; the admin also has
  `src/i18n-d<NNN>.ts`. Add the key in both languages.
- No user-facing string is hardcoded in widgets or components.

## Visual checks

Layout direction, mirrored icons, bidi text, ellipsis and the two viewports (393×852 and 360×800) are
covered by the existing design skill `rtl-ltr-visual-specialist` and the goldens (`<component>.<ar|en>.*`
in `apps/mobile/test/goldens/png/`). That skill is on the branch `claude/elite-design-engineering`. If
it is not present, check Arabic and English renders yourself and say which checks you could not run.
