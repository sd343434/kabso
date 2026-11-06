# Flutter app (`apps/mobile`)

Authoritative: `apps/mobile/README.md` (architecture, quality gates, goldens), `apps/mobile/pubspec.yaml`,
`apps/mobile/analysis_options.yaml`, the `mobile` and `android` jobs in `.github/workflows/ci.yml`.

## Facts

- Package `kabso_live`. Imports use `package:kabso_live/...`. The app imports
  `package:material_ui/material_ui.dart`, not `package:flutter/material.dart` (README, "Material library").
- State: `flutter_riverpod`. Routing: `go_router`, in `lib/app/router/`. HTTP: `dio`, in `lib/core/network/`.
  Models: `freezed` and `json_serializable`.
- Layout: `lib/app/`, `lib/core/`, `lib/design_system/` (tokens 1:1 from `docs/contracts/design-tokens.json`),
  and `lib/features/<feature>/`. Features use some of `domain/`, `data/`, `application/` and
  `presentation/`, but not all of them; follow the feature you are changing.
- Errors: `lib/core/error/` maps every `CONVENTIONS.md` §4 code to a localized message. A new API error
  code needs an entry there.
- Generated code is committed (board D5): `*.g.dart`, `*.freezed.dart` and `lib/l10n/gen/`. CI fails on
  drift.
- File names are `snake_case.dart`. Lint: `very_good_analysis` (see `analysis_options.yaml`).
- Local plugins live in `apps/mobile/packages/`: `kabso_camera_fx`, `kabso_streamer` and
  `kabso_live_music`. `kabso_camera_fx` is analysed and tested on its own in CI. The Kotlin unit tests
  run in the `android` job through Gradle.

## Tests

- `flutter test` runs unit and widget tests with no network. HTTP is faked at the Dio adapter
  (`test/helpers/fake_http_adapter.dart`), with payloads shaped like `openapi.yaml`
  (`test/helpers/contract_fixtures.dart`).
- Test files are `*_test.dart` under `test/`. Fake data lives only in `test/fixtures/**`, and
  `test/fixtures/fixtures_isolation_test.dart` enforces that.
- Goldens: `test/goldens/*_golden_test.dart`, images in `test/goldens/png/`, viewports 393×852 and
  360×800 @3x, generated on Linux with the pinned Flutter. Regenerate with `--update-goldens` only in a
  dedicated change, and say why (README, "Golden tests").

## Checks (the same commands as the CI `mobile` job, run from `apps/mobile`)

```sh
flutter pub get --enforce-lockfile
dart run build_runner build --delete-conflicting-outputs && git diff --exit-code -- .
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

The drift check (`git diff --exit-code`) also fails on your own uncommitted edits. Run it on a tree
with no other changes in `apps/mobile`, or read the diff to see which files `build_runner` or
`gen-l10n` changed.

Building an APK or IPA needs the Android SDK or Xcode. Many agent environments have neither, so say
"not run" rather than skipping silently. CI builds the debug APK and the staging APK.
