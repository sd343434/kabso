# Kabso Live — mobile app (`apps/mobile`)

Flutter app for Android and iOS. Arabic-first (RTL) with English; the first-launch language
follows the device (`en*` → English, anything else → Arabic) until the user picks one.
Phase 1 scope (KL-003): foundation, design system, navigation shell and the email
authentication slice against `docs/contracts/openapi.yaml`.

## Requirements

- Flutter **3.47.x** stable / Dart **3.13.x** (developed with 3.47.7 / 3.13.5).
- Android: minSdk 24 (required by `flutter_secure_storage` 11), Android SDK + emulator or device.
- iOS: Xcode on macOS.

## Run

```sh
cd apps/mobile
flutter pub get
# Android emulator → API on the host machine (default)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
# iOS simulator
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

| `--dart-define` | Default | Meaning |
| --------------- | ------- | ------- |
| `API_BASE_URL` | `http://10.0.2.2:3000` (debug/profile only) | API origin (no `/api/v1`; the client appends it). **Release builds must pass an `https://` URL** — otherwise startup fails with `AppConfigError` (SEC-007). |
| `APP_VERSION` | `1.0.0` | Sent in `X-Client: kabso-mobile/<version> (<android\|ios>)` and as `device.appVersion`. |

No secrets are compiled into the app. Plain HTTP is allowed only in **debug** builds:

- Android: `usesCleartextTraffic` only in `src/debug/AndroidManifest.xml`.
- iOS: `ios/Runner/Info.plist` has **no** ATS exception. `ios/Flutter/Debug.xcconfig` sets
  `KABSO_ALLOW_LOCAL_NETWORKING = YES`; the Runner build phase "Debug ATS exception" then adds
  `NSAppTransportSecurity/NSAllowsLocalNetworking = true` to the *built* Info.plist (PlistBuddy).
  Release and Profile use `Release.xcconfig`, which does not set it, so the key never ships; the
  phase fails the build if the setting appears in any non-Debug configuration.

## Release signing (Android, SEC-020)

Release builds are never signed with the debug key. Create `android/key.properties`
(git-ignored):

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Without it, any release build (`flutter build apk|appbundle --release`) fails early in
`preReleaseBuild` with an explicit message. To build an unsigned release on purpose (e.g. CI that
signs later), pass `-Pkabso.allowUnsignedRelease=true` (`flutter build appbundle --release
--android-project-arg=kabso.allowUnsignedRelease=true`). Debug builds are unchanged.

## Device data (SEC-019)

- Android: `allowBackup="false"`; `dataExtractionRules` (API 31+) and `fullBackupContent`
  exclude the flutter_secure_storage files (`FlutterSecureStorage.xml`,
  `FlutterSecureKeyStorage.xml`, `FlutterSecureStorageConfiguration.xml`) from cloud backup and
  device-to-device transfer.
- iOS: Keychain items survive uninstall. On the first launch of an install (no
  `pref.installed` flag in shared preferences) the stored refresh token is deleted
  (`core/storage/fresh_install.dart`).

## Quality gates (same commands as CI)

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs && git diff --exit-code
dart format --output=none --set-exit-if-changed lib test
flutter analyze            # very_good_analysis, must report "No issues found!"
flutter test
```

Notes:

- Generated code is committed (decision D5): `*.g.dart` (json_serializable), `*.freezed.dart`
  (Freezed) and `lib/l10n/gen/` (gen-l10n). After changing a DTO/entity run `build_runner`;
  after changing an ARB file run `flutter gen-l10n` (also run implicitly by `flutter pub get`
  / `flutter test` because `generate: true`). Commit the results.
- `build_runner` 2.16 prints `These options have been removed and were ignored:
  --delete-conflicting-outputs`. The flag is harmless and kept so the CI command matches.
- `very_good_analysis` 11 enables `unnecessary_type_name_in_constructor`, so constructors use
  Dart 3.13's `new(...)` / `factory fromJson(...)` declaration syntax. The only rule disabled is
  `public_member_api_docs` (application code, not a published package).

## Architecture

```
lib/
  main.dart, bootstrap.dart     ProviderScope, error handlers, SharedPreferences
  app/                          app.dart (MaterialApp.router), router/ (GoRouter + auth guard),
                                shell/ (5-tab StatefulShellRoute scaffold, custom bottom nav)
  core/
    config/                     AppConfig from --dart-define
    error/                      ErrorCode (every CONVENTIONS §4 code + NETWORK_OFFLINE/TIMEOUT),
                                sealed AppFailure, localized message per code
    network/                    Dio factory, interceptors (request id, Accept-Language, X-Client,
                                bearer, single-flight refresh), envelope → AppFailure mapping,
                                TokenManager (access token in memory, refresh token in secure storage)
    storage/                    SecureTokenStore (flutter_secure_storage), SharedPreferences provider
    preferences/                Language (ar default) and theme mode (dark default), persisted
    logging/                    AppLogger with token/password redaction; HTTP logs never include
                                headers or bodies
  design_system/                tokens (1:1 from design-tokens.json), Material 3 theme builder,
                                KButton, KTextField, KAvatar, KSkeleton, KEmptyState, KErrorState,
                                KInlineMessage, KLogo (text wordmark placeholder), KSnack
  features/
    auth/{domain,data,presentation}   entities (Freezed), repository interface, validators,
                                      DTOs (json_serializable), remote data source, repository,
                                      Session/Auth/UsernameAvailability controllers, screens
    settings/                   theme, language, sessions list + revoke, sign out
    home, discover, create, live      honest "arrives in Phase N" empty states
    profile/                    real user from GET /me + email verification state
  l10n/                         app_ar.arb (template), app_en.arb, gen/ (generated)
```

- **Material library:** `go_router` 18 builds its pages with the decoupled
  [`material_ui`](https://pub.dev/packages/material_ui) package, so the app imports
  `package:material_ui/material_ui.dart` (not `package:flutter/material.dart`) to keep one
  `Theme`/`MaterialLocalizations` tree.
- **Auth flow:** `/splash` restores the session (refresh token → `POST /auth/refresh` →
  `GET /me`). No token → `/auth/login`. Offline/5xx/429 during restore → splash error with retry
  (token kept). `AUTH_REFRESH_INVALID` / `ACCOUNT_SUSPENDED` from refresh → session cleared,
  login shows why.
- **Refresh:** a 401 `AUTH_UNAUTHENTICATED` triggers one shared refresh for all concurrent
  requests; each failed request is retried once. A request whose 401 arrives after another
  request already refreshed reuses the new token.
- **Verify-first registration (contract v1.2):** `POST /auth/register` → 202 (never tokens,
  never `EMAIL_TAKEN`) → code screen (`/auth/register/code`, 8 LTR cells, Arabic-Indic digits
  normalized, paste + auto-submit, 60 s resend cooldown, 30 min expiry hint) →
  `POST /auth/register/verify` → 201 session → Home. The form is kept in memory only while the
  flow is open (`registrationFlowProvider`). There is no verify-email notice or "Not verified"
  UI any more.
- **displayName (v1.2):** counted in grapheme clusters (`String.characters`, max 50) and code
  points (max 100); ZWNJ/ZWJ allowed between characters; server issues `invalid_format`,
  `too_long` and `reserved_term` map to the PHASE1_1_SCREENS §2 copy. The reserved list is
  server-side only.
- **Language (v1.2, D26):** saved choice → device language (`en*` → en, else ar); nothing is
  persisted until the user picks (Login/Register language chip or Settings). After sign-in the
  app `PATCH /me {"locale"}`s an explicit choice that differs from the account, or adopts the
  account locale when there is no choice; failures are silent and retried on the next start.
- **Contract v1.0.3:** usernames are trimmed and lowercased before `register` and
  `username-availability`; `VALIDATION_FAILED` details use the closed issue vocabulary and
  body-level details (`field: ""`) show a form-level message.
- **Errors (PHASE1_SCREENS §10):** `RATE_LIMITED` and `SERVICE_UNAVAILABLE` with `Retry-After`
  show a live `m:ss` countdown and disable the submit button until it reaches zero;
  `INTERNAL_ERROR`, `SERVICE_UNAVAILABLE` and unknown codes show a selectable "Error ID"
  (`requestId`).
- **Digits:** all dates, countdowns and relative times go through `core/format/k_format.dart`
  with Western digits (0–9) in both locales (DESIGN_SYSTEM §3.3).

## Tests

`flutter test` runs unit and widget tests without network: HTTP is faked at the Dio
`HttpClientAdapter` boundary (`test/helpers/fake_http_adapter.dart`) with payloads shaped like
openapi.yaml (`test/helpers/contract_fixtures.dart`); widget tests override providers.

### Golden tests (G-26)

- Tests: `test/goldens/*_golden_test.dart` (tag `golden`); images: `test/goldens/png/`, named
  `<component>.<ar|en>.<phone|android>.png`. Live surfaces are dark-only.
- Harness: `test/helpers/golden.dart`. `loadAppFonts()` loads the bundled Inter, IBM Plex Sans
  Arabic and Material Icons (not the Ahem test font). Viewports are pinned to 393×852 @3x
  (`phone`) and 360×800 @3x (`android`). Animations are disabled, images are in-memory PNGs
  precached in `runAsync`, and data is seeded.
- Fake data lives only in `test/fixtures/**`. `test/fixtures/fixtures_isolation_test.dart` fails
  if `lib/` imports tests, fixtures or `flutter_test`. Production screens keep their empty
  states.
- Goldens are generated and compared **on Linux with the pinned Flutter (3.47.7)**. On macOS or
  Windows, font rasterisation differs and local mismatches are informational. To regenerate,
  use a dedicated commit with A5 reviewing the images:

  ```sh
  flutter test --update-goldens test/goldens/                              # all
  flutter test --update-goldens test/goldens/live_components_golden_test.dart
  ```

## What cannot be built or verified here

The authoring environment has no Android SDK and no Xcode (blocker **B6**): no APK/IPA builds,
no emulator/device runs, no golden or integration tests on devices. Not verified on a device:
secure storage behaviour, font rendering, keyboard/IME and screen-reader behaviour.

## Placeholders / blockers

- **B7** — application id / bundle id is the placeholder `com.kabso.kabso_live`.
- **B8** — no brand assets: `KLogo` is a text wordmark; launcher icons are Flutter defaults.
- Fonts: Inter and IBM Plex Sans Arabic (OFL-1.1) are bundled in `assets/fonts/` with their
  licenses (`OFL-*.txt`), static Regular/SemiBold/Bold instances from Google Fonts.
