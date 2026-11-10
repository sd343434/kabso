# Third-party notices — the Kabso Live app (apps/mobile)

Code and artwork from third parties that is copied into the app's own sources (not pulled in as a
package; packages (pubspec.lock) ship their own licences, and bundled assets keep theirs in
each `assets/**/PROVENANCE.md` or `NOTICE.txt`). Local plugins keep their own notices
(`packages/*/THIRD_PARTY_NOTICES.md`).

## Phosphor Icons (D362)

- **What:** the SVG path data of seven glyphs — video camera (bold weight); microphone,
  headphones, game controller, lightning, users, gavel (fill weight) — embedded as strings in
  `lib/features/live/presentation/widgets/kabso_live_icon.dart` (the owner's live-card room-type
  icons, supplied by the owner in the file `kabso_live_icon.dart`, 2026-11-10). The «PK»
  lettermark in the same file is the owner's own drawing. The paths are drawn as supplied; only
  float noise in the lettermark was rounded to 3 decimals and its separators changed to commas.
- **Source:** Phosphor Icons, <https://phosphoricons.com>, <https://github.com/phosphor-icons/core>.
- **Licence:** MIT.

```
MIT License

Copyright (c) 2023 Phosphor Icons

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

**Open before release:** the app has no in-app licence page entry for code copied into its sources
(Flutter's `showLicensePage` lists packages only). Register this notice with
`LicenseRegistry.addLicense` when the app gets its «التراخيص» / Licences page.
