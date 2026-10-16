# Vendored country data (CONVENTIONS §11.7, contract v1.4)

| File                              | What                                                                    | sha256                                                             |
| --------------------------------- | ----------------------------------------------------------------------- | ------------------------------------------------------------------ |
| `iso3166-1-alpha2.txt`            | The 249 officially assigned ISO 3166-1 alpha-2 codes (derivation below) | `d98579cc001deece6ad2dd72dc7cdaa791afc17daf08669f255e0479329cbf97` |
| `cldr-48.0.0/ar/territories.json` | Unicode CLDR 48 Arabic territory names, unmodified                      | `b78c4a11a9ad8358048998bcda2eb49e205d5ab281f85991ed097af7b972c3d7` |
| `cldr-48.0.0/en/territories.json` | Unicode CLDR 48 English territory names, unmodified                     | `158c1d575308f7e46912edbeda435c8fe2ef5dad280798231f3a432e406b1807` |
| `cldr-48.0.0/LICENSE`             | Unicode License v3 (from the same package)                              |                                                                    |
| `countries.generated.ts`          | Compact table used at runtime: `node scripts/generate-countries.mjs`    |                                                                    |

**CLDR source:** npm package `cldr-localenames-full` **48.0.0** (the `cldr-json` release; its
`package.json` says `"cldrVersion": "48"`), files `main/ar/territories.json` and
`main/en/territories.json`. Tarball
`https://registry.npmjs.org/cldr-localenames-full/-/cldr-localenames-full-48.0.0.tgz`, integrity
`sha512-H6ZG0+1rjwsg7gqFeIAa2TTab9fWA7/b7U0ovxA2YJSI5tGumyM5sVchY5f/q0kn/9AtseGKwrTb9UDC4xmghw==`
(verified against the download on 2026-10-16). Newer 48.x packages (48.1.0, 48.2.0) exist; the
contract pins 48.0.0. The default name of each code is used, never `-alt-short` / `-alt-variant`
(D45: names unchanged, including `PS` → "Palestinian Territories" / "الأراضي الفلسطينية"). No
overrides exist in v1.4.

**Code list derivation:** every two-letter region code in CLDR 48.0.0 `en/territories.json`
(264), minus the codes that are not officially assigned in ISO 3166-1: exceptionally reserved
`AC CP CQ DG EA EU EZ IC TA UN`, and user-assigned `QO XA XB XK ZZ` (`XK` excluded by owner
decision D45). The result was cross-checked against Debian `iso-codes` (`iso_3166-1.json`, as
shipped in the `pycountry` 26.2.16 wheel): identical 249 codes. Neither package is a dependency of
the API.

`src/modules/countries/countries.spec.ts` checks every sha256 above, the 249 codes, the exclusions,
the non-empty names in both locales, and that `countries.generated.ts` equals a fresh generation.
Changing the CLDR version, adding or removing a code, or overriding a name is a contract patch
(name overrides need owner approval).
