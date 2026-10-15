# Kabso Live — mobile app (`apps/mobile`)

Flutter app for Android and iOS. Arabic-first (RTL, default locale `ar`) with English.
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
| `API_BASE_URL` | `http://10.0.2.2:3000` | API origin (no `/api/v1`; the client appends it). |
| `APP_VERSION` | `1.0.0` | Sent in `X-Client: kabso-mobile/<version> (<android\|ios>)` and as `device.appVersion`. |

No secrets are compiled into the app. Plain HTTP is allowed only in **debug** Android builds
(`src/debug/AndroidManifest.xml`) and for local networking on iOS (`NSAllowsLocalNetworking`);
release builds need HTTPS.

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
  login shows why. After register the verify-email notice is shown once.
- **Refresh:** a 401 `AUTH_UNAUTHENTICATED` triggers one shared refresh for all concurrent
  requests; each failed request is retried once. A request whose 401 arrives after another
  request already refreshed reuses the new token.
- **Contract v1.0.3:** usernames are trimmed and lowercased before `register` and
  `username-availability`; `VALIDATION_FAILED` details use the closed issue vocabulary and
  body-level details (`field: ""`) show a form-level message.

## Tests

`flutter test` runs unit and widget tests without network: HTTP is faked at the Dio
`HttpClientAdapter` boundary (`test/helpers/fake_http_adapter.dart`) with payloads shaped like
openapi.yaml (`test/helpers/contract_fixtures.dart`); widget tests override providers.

## What cannot be built or verified here

The authoring environment has no Android SDK and no Xcode (blocker **B6**): no APK/IPA builds,
no emulator/device runs, no golden or integration tests on devices. Not verified on a device:
secure storage behaviour, font rendering, keyboard/IME and screen-reader behaviour.

## Placeholders / blockers

- **B7** — application id / bundle id is the placeholder `com.kabso.kabso_live`.
- **B8** — no brand assets: `KLogo` is a text wordmark; launcher icons are Flutter defaults.
- Fonts: Inter and IBM Plex Sans Arabic (OFL-1.1) are bundled in `assets/fonts/` with their
  licenses (`OFL-*.txt`), static Regular/SemiBold/Bold instances from Google Fonts.
