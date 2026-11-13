# Testing, CI and security

Authoritative: `.github/workflows/ci.yml`, `docs/DEPLOYMENT.md` (the CI and branch-protection sections),
`docs/SECURITY_MODEL.md`, `.gitleaksignore`, board decision D40.

## CI jobs (`ci.yml`)

| Job | What it runs | Local details |
| --- | ------------ | ------------- |
| `changes` | paths-filter; later jobs run only for the areas changed | — |
| `api` | prisma generate, role bootstrap, migrate deploy, lint, format, typecheck, unit, e2e, build | [nestjs-api.md](nestjs-api.md) |
| `admin`, `studio` | typecheck, lint, unit, build | [web-admin-studio.md](web-admin-studio.md) |
| `mobile` | pub get, codegen drift, format, analyze, test, `kabso_camera_fx` | [flutter-mobile.md](flutter-mobile.md) |
| `android` | debug APK, Kotlin unit tests (`kabso_camera_fx`, `kabso_streamer`) | needs the Android SDK |
| `ios` | unsigned iOS build | needs macOS |
| `contracts` | redocly lint of `openapi.yaml` | [contract-first.md](contract-first.md) |
| `site` | `scripts/check-site-no-tracking.sh` | — |
| `secrets` | gitleaks (pinned version and checksum) over the **whole git history** | see below |
| `ci-ok` | allowlist gate: every job `success` or `skipped` | — |
| `deploy-image`, `staging-apk`, `staging-apk-release` (D330) | only on a push to `staging`, after a green run | deployment: never trigger without approval |

## Reporting results

Use the board's labels: IMPLEMENTED ≠ TESTED ≠ INTEGRATED ≠ PRODUCTION-READY. Report each check as one
of: passed (ran, with the count), failed (with the output), not run (with the reason), or
environment-limited. Never round "not run" up to "passed". Do not skip, disable or weaken a test, and do
not lower a threshold, to get green.

## Secrets and the public repository

- The repository is public (board D40). Never commit credentials, keys, tokens, third-party reference
  screenshots, images of real users, or exploit details for open findings.
- The `secrets` job scans all fetched history, so a past commit can fail any branch.
  `.gitleaksignore` takes **exact fingerprints only** (`commit:file:rule:line`), each with a comment
  saying why it is safe and who approved it. Never ignore a path or a rule.
- Local scan, with gitleaks matching the CI version (`GITLEAKS_VERSION` and its SHA-256 in `ci.yml`):
  `gitleaks git --redact --no-banner --exit-code 1 .`

## Permission patterns are not a security boundary

The ask and deny rules in `.claude/settings.json` match the start of a command. They do not catch every
way of running the same operation:

- `Bash(git push *)` does not match `git -C . push`, `git -c key=value push`, or a push run from a
  script, an alias or another program.
- The same applies to `git commit`, `git merge`, `git reset` and the other gated commands.
- Read deny rules cover the Read tool and the file commands Claude Code recognises in Bash. They do not
  cover a program that opens the file itself.

Treat the rules as a safety net, not a guarantee. What actually protects the repository is the
read-only default (`plan` mode in Claude Code; a trusted read-only project or a read-only personal
sandbox in Codex) and the human approval gate in `AGENTS.md`. Never rewrite a command to get past a
rule; ask the owner instead.

## Visual regression

Flutter goldens are covered in [flutter-mobile.md](flutter-mobile.md). Fidelity against a reference
screenshot belongs to the design skills named in `AGENTS.md`.
