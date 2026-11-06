---
name: kabso-monorepo
description: Map of the Kabso Live monorepo (Flutter app, NestJS API, Prisma/PostgreSQL, React admin and studio, OpenAPI contract) with the source of truth and the local checks for each area. Use when changing code, contracts, migrations, localization, tests or CI in this repository, or when you need to know where something lives or how it is verified.
---

# Kabso Live monorepo

This skill only routes. The rules themselves live in the repository documents listed below; read the
relevant one before acting, and quote it rather than this file. Where a document and this skill
disagree, the document wins. Report the mismatch.

## Approval gate

Get the owner's explicit approval before every commit, push, merge, rebase, reset, PR merge, close or
approval, deployment, and destructive operation, including in scratch worktrees (see `AGENTS.md`).
Never report a check as passed unless you ran it.

## Map

| Path | What it is | Details |
| ---- | ---------- | ------- |
| `apps/mobile` | Flutter app `kabso_live` (Riverpod, GoRouter, Dio, freezed, LiveKit, gen-l10n) | [references/flutter-mobile.md](references/flutter-mobile.md) |
| `apps/mobile/packages/` | Local Flutter plugins `kabso_camera_fx`, `kabso_streamer`, `kabso_live_music` (Kotlin code included) | [references/flutter-mobile.md](references/flutter-mobile.md) |
| `apps/api` | NestJS API `@kabso/api` (Vitest unit and e2e) | [references/nestjs-api.md](references/nestjs-api.md) |
| `apps/api/prisma` | Prisma schema and migrations, PostgreSQL 16 | [references/prisma-postgres.md](references/prisma-postgres.md) |
| `apps/admin`, `apps/studio` | React + Vite web apps `@kabso/admin` and `@kabso/studio` | [references/web-admin-studio.md](references/web-admin-studio.md) |
| `docs/contracts` | `openapi.yaml`, `CONVENTIONS.md`, `design-tokens.json`, `proposals/` | [references/contract-first.md](references/contract-first.md) |
| `apps/mobile/lib/l10n`, admin and studio `i18n` | Arabic and English strings, RTL and LTR | [references/l10n-rtl.md](references/l10n-rtl.md) |
| `.github/workflows/ci.yml`, `.gitleaksignore` | CI jobs, the secret scan, the `ci-ok` gate | [references/testing-ci-security.md](references/testing-ci-security.md) |
| `infra/`, `docs/DEPLOYMENT.md` | Server, Caddy, database roles, deploy | Read `docs/DEPLOYMENT.md`. Deployment always needs approval. |

## Sources of truth

| Topic | Source |
| ----- | ------ |
| Decisions, tasks, ownership, delivery labels (IMPLEMENTED ≠ TESTED ≠ INTEGRATED ≠ PRODUCTION-READY) | `docs/AI_WORKFORCE_BOARD.md` |
| API shapes, error codes, change log | `docs/contracts/openapi.yaml`, `docs/contracts/CONVENTIONS.md` |
| Database | `apps/api/prisma/schema.prisma`, `apps/api/prisma/migrations/`, `docs/DATABASE_SCHEMA.md` |
| Deploy and release gates | `docs/DEPLOYMENT.md`, `docs/PRE_PRODUCTION_CHECKLIST.md` |
| Security | `docs/SECURITY_MODEL.md`; board decision D40 (the repository is public) |
| What CI runs | `.github/workflows/ci.yml` |

## Workflows

These run only when a person types the command (`disable-model-invocation`). If one applies and was not
invoked, read its `SKILL.md` and follow the steps, or suggest the command to the person.

- `/kabso-verify`: run the local equivalents of the CI jobs for the areas you touched.
- `/kabso-contract-change`: the contract-first order for any API change.
- `/kabso-db-migration`: a Prisma migration from schema to runtime grants.

## Visual and RTL work

UI fidelity and visual regression belong to the design skills (`elite-design-engineering`,
`pixel-perfect-ui`, `pixel-perfect-ui-workflow`, `rtl-ltr-visual-specialist`,
`screenshot-diff-and-visual-regression` and the others named in `AGENTS.md`). They are on the branch
`claude/elite-design-engineering`, not on `staging`. If they are not present, say so; do not improvise
a replacement.
