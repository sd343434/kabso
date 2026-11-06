---
name: kabso-verify
description: Run the local equivalents of the Kabso CI jobs for the areas changed on this branch and report each result honestly. Use when asked to verify, check or test a change before review.
disable-model-invocation: true
---

# /kabso-verify

1. Find the changed areas: `git diff --name-only origin/staging...HEAD`, plus uncommitted files. Map
   each path to a CI job using the table in
   `.claude/skills/kabso-monorepo/references/testing-ci-security.md`.
2. For each area, run the commands from its reference file. These are the same commands as
   `.github/workflows/ci.yml`; re-read the workflow if they seem to differ.
   The reference files are in `.claude/skills/kabso-monorepo/references/`.
   - `apps/api/**` or `apps/api/prisma/**`: `nestjs-api.md`. The e2e tests need a `_test` database and
     Redis.
   - `apps/mobile/**`: `flutter-mobile.md`.
   - `apps/admin/**`, `apps/studio/**`: `web-admin-studio.md`.
   - `docs/contracts/openapi.yaml`: the redocly lint in `contract-first.md`.
   - Always: gitleaks over the history, if a pinned binary is available.
3. Report a table: check, exact command, result (passed with counts / failed with the output / not run
   with the reason / environment-limited).

Rules:

- Do not commit, push, update goldens, reset or delete anything. This workflow only runs checks.
- Never report a check you did not run as passed.
- Do not re-run a failing test until it passes, and do not call a failure a flake without evidence.
