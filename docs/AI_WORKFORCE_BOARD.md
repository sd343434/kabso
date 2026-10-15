# Kabso Live — AI Workforce Board

Authoritative task registry. Statuses: `BACKLOG → READY → IN_PROGRESS → REVIEW → TESTING → DONE`
(+ `BLOCKED`, `REJECTED`). A task is DONE only when acceptance criteria are met, its tests were
actually executed, and required reviews passed. Delivery labels used in reports:
**IMPLEMENTED** (code exists) ≠ **TESTED** (tests executed and passing) ≠ **INTEGRATED** (merged
on the integration branch with the other modules, regression suite green) ≠ **PRODUCTION-READY**
(release gates passed + human authorization).

## Environment audit (2026-10-15)

| Item | Finding |
| ---- | ------- |
| Repository | `sd343434/kabso` was empty (no commits). Greenfield monorepo. |
| Unrelated repo | `sd343434/flexibx` (separate Next.js product) — not modified. |
| Multi-agent capability | Claude Code `Agent` tool with `isolation: "worktree"` is available → genuine parallel subagents in isolated git worktrees. |
| Toolchain | Node 22.22, pnpm, PostgreSQL 16 (local cluster), Redis 7.0, Java; Flutter 3.47.7 / Dart 3.13.5 installed into `/opt/sdk/flutter` this session. |
| Not available | Docker daemon (client only), Android SDK, Xcode/macOS → no device/emulator runs, no APK/IPA builds in this environment. |
| Network | npm, pub.dev, Flutter storage reachable. |

## Agent roster

| ID | Role | Ownership (Phase 1) |
| -- | ---- | ------------------- |
| A1 | CTO / Orchestrator | `docs/contracts/**`, plan, board, integration, reviews |
| A2 | Flutter Mobile | `apps/mobile/**` |
| A3 | Backend & Database | `apps/api/**`, root `package.json`, `pnpm-workspace.yaml` |
| A4 | Real-time Media | Phase 6+ (LiveKit adapter, WS events) — not active in Phase 1 |
| A5 | Product Design & UX | `docs/design/**` |
| A6 | QA & Test | independent verification; may add tests under `apps/*/test` |
| A7 | Security & Performance | `docs/SECURITY_MODEL.md`, review of auth |
| A8 | DevOps & Release | `.github/**`, `docker-compose.yml`, `infra/**`, `docs/DEPLOYMENT.md` |

## Phase 1 tasks

| ID | Title | Owner | Pri | Status | Depends | Review |
| -- | ----- | ----- | --- | ------ | ------- | ------ |
| KL-001 | Environment audit, contracts, architecture, plan | A1 | P0 | DONE | — | self (docs only) |
| KL-002 | Backend foundation + auth vertical slice | A3 | P0 | REVIEW — INTEGRATED (`f45b867`, D1 fix `217cad6`) | KL-001 | A1 ✅; A6, A7 in progress |
| KL-003 | Flutter foundation + auth vertical slice | A2 | P0 | REVIEW — INTEGRATED (`b973d7b`) | KL-001 | A1 ✅; A6, A7 in progress |
| KL-004 | Design system & screen inventory spec | A5 | P1 | DONE — INTEGRATED (`6e64fd3`) | KL-001 | A1 ✅ (scope + contrast math re-computed) |
| KL-005 | CI, local infra, deployment doc | A8 | P0 | TESTING — INTEGRATED (`5ec94ad`); first remote runs in progress | KL-001 | A1 ✅ |
| KL-006 | Independent QA verification of Phase 1 | A6 | P0 | IN_PROGRESS (candidate `b973d7b`, own DB `kabso_qa_test`, Redis db 14) | KL-002, KL-003 | A1 |
| KL-007 | Auth threat model & security review | A7 | P0 | IN_PROGRESS (candidate `b973d7b`, own DB `kabso_sec_test`, Redis db 13) | KL-002 | A1 |
| KL-008 | Integration of Phase 1 + regression run | A1 | P0 | IN_PROGRESS — all Wave 1 branches merged; awaiting QA/Security + full remote CI | KL-002..005 | A6 |
| KL-010 | Dependabot policy: ignore semver-major for postgres/redis images (PRs #1, #2 propose 16→18, 7→8 against D2) | A8 | P2 | BACKLOG | — | A1 |
| KL-009 | Accessibility token fixes P1–P9, P11, P14 (design-tokens v1.1) | A2 (+A5 review) | P1 | BACKLOG | KL-003 merged | A1, A5, A6 |

## Phase 1 integration gate (status 2026-10-15 ~13:57 UTC)

Integrated candidate: **`b973d7b`** (all Wave 1 branches merged; contracts v1.0.4 on top in `416527a`).

| Gate item | Evidence | State |
| --------- | -------- | ----- |
| KL-002 contract conformance | CTO review: 15/15 error codes, 14/14 routes + status codes, strict zod schemas = `openapi.yaml` | ✅ |
| KL-003 contract conformance | CTO review: all endpoint paths under `${API_BASE_URL}/api/v1`; DTO fields/nullability = `openapi.yaml`; request DTOs omit nulls (`includeIfNull: false`) so strict server schemas accept them; v1.0.3 username lowercasing applied | ✅ |
| API gates (local, re-run by CTO on integrated tree) | lint 0 · prettier clean · `tsc` clean · unit **73/73** · e2e **44/44** (Postgres 16.15 + Redis) · build OK · `prisma validate` OK · `migrate status` up to date · `20261015132258_init` applies to empty DB (6 tables, 5 CHECKs) | ✅ |
| Mobile gates (local, re-run by CTO on integrated tree) | `flutter pub get` ✅ · build_runner ✅ · codegen drift none · `dart format` 71 files / 0 changed · `flutter analyze` **No issues found** · `flutter test` **162/162** | ✅ |
| Secret scan | `gitleaks git` (CI command) → no leaks (local + CI run 9) | ✅ |
| Remote CI | run 9 (`217cad6`): gitleaks ✅, API (migrate, lint, format, typecheck, unit, e2e, build) ✅, CI OK ✅. Run 10 (`b973d7b`, first mobile + Android APK run): in progress | ⏳ |
| KL-006 QA / KL-007 Security | running independently on `b973d7b` | ⏳ |
| Android APK / iOS build | not possible locally (B6); CI `android` job in run 10; `ios` job runs only on dispatch/main | ⏳ / ⛔ local |

**Closed defects:** D1 (KL-002) gitleaks on test-fixture literals — fixed in `e424d77` (runtime-generated
secrets + `.gitleaksignore` for exactly two historical fingerprints), verified by CTO and CI run 9.

**Watch items:** `material_ui` 1.7.0 (publisher flutter.dev, required by go_router 18) was published
2026-10-14 — pinned by `pubspec.lock`; re-evaluate on next dependency review.

### Acceptance criteria

**KL-009 Accessibility token fixes** — Approved scope: A5 proposals P1 (dark `textTertiary` →
#92929E), P2 (light `textTertiary` → #666671), P3/P4 (add `primaryText` dark #FF3B47 / light
#C8080F), P5 (light `success` → #137A43), P6 (light `warning` → #955C00), P7 (light `error` →
#C4242D), P8 (light `info` → #1A64BF), P9 (add `borderStrong` dark #70707C / light #85858F),
P11 (add `focusRing`: dark red400, light `primary`), P14 (add `onStatus` #0B0B0D). Process:
(1) A2 + A5 review the proposals against the merged Flutter token implementation and list every
usage site affected; (2) CTO records the contract change (design-tokens v1.1) with compatibility
notes; (3) A2 applies the change to `design-tokens.json` and Flutter tokens/theme in one change
set and switches text-on-red, input outlines, focus indicators and text-on-status-fill to the new
roles; (4) a Flutter test asserts WCAG ratios ≥ 4.5:1 for body-text pairs and ≥ 3:1 for
outlines/large text, computed from the token constants; (5) `flutter analyze`/`flutter test`
green. P10, P12, P13, P15–P19 remain proposals (not approved).


**KL-002 Backend auth slice** — every endpoint in `docs/contracts/openapi.yaml` implemented with
the exact shapes and error codes of `CONVENTIONS.md`; Prisma schema + initial migration
(User, UserProfile, UserSettings, Session, VerificationToken, AuditLog); Argon2id; refresh
rotation with reuse detection; immediate revocation; Redis rate limits; log mail adapter;
health endpoints; zod-validated config; e2e tests against real Postgres+Redis covering happy
paths, validation, duplicate email/username, wrong password (no enumeration), refresh rotation,
reuse detection, logout, session revoke, suspended account, password reset revoking sessions,
rate limiting; lint + typecheck + tests green.

**KL-003 Flutter slice** — app boots to splash → auth gate; Arabic default (RTL) + English;
dark (default) + light themes from `design-tokens.json`; 5-tab `StatefulShellRoute` with
honest "coming in Phase N" empty states (no fake data, no dead buttons); login, register (live
username availability), forgot-password, email-verification notice screens wired to the API;
Dio client with error-envelope mapping and single-flight refresh; refresh token in secure
storage; session restore on launch; logout; loading/error/empty states; unit tests (repository,
interceptor refresh single-flight, error mapping), widget tests (login validation, RTL layout,
shell navigation); `dart format`, `flutter analyze` (zero issues), `flutter test` green.

**KL-004 Design spec** — `docs/design/DESIGN_SYSTEM.md` (tokens usage, components with states,
RTL rules, accessibility, motion) and `docs/design/SCREEN_INVENTORY.md` (all screens across
phases, navigation map, per-screen states) consistent with `design-tokens.json`.

**KL-005 DevOps** — `docker-compose.yml` (Postgres 16, Redis 7, MinIO), `.github/workflows/ci.yml`
(api: install, prisma generate, migrate, lint, typecheck, test with service containers;
mobile: pub get, codegen-diff check, format check, analyze, test; contracts: OpenAPI lint),
`docs/DEPLOYMENT.md`, root `.env.example` guidance.

## Decision log

| # | Date | Decision | Rationale |
| - | ---- | -------- | --------- |
| D1 | 2026-10-15 | Monorepo: `apps/mobile`, `apps/api`, `docs/contracts` | Contract-first, one review surface |
| D2 | 2026-10-15 | NestJS 12 + Prisma 7.10 (stable; npm `latest` is 8.0.0-rc → rejected) + Postgres 16 + Redis | Stable versions only |
| D3 | 2026-10-15 | LiveKit as default live provider behind `LiveMediaProvider` | OSS/self-hostable, Flutter SDK, multi-host |
| D4 | 2026-10-15 | Opaque rotating refresh tokens `<sid>.<secret>` + 15-min JWT; guard checks session | Immediate revocation, reuse detection |
| D5 | 2026-10-15 | Generated Dart code committed, CI checks drift | Analyzer works on fresh clone |
| D6 | 2026-10-15 | Error messages localized client-side by `code` | Single source of copy in the app |
| D7 | 2026-10-15 | OpenAPI v1.0.1/v1.0.2: YAML fix + additive documentation of 400/429 responses; health 4xx warnings deferred | No shape change; see CONVENTIONS §9 |
| D9 | 2026-10-15 | Contract v1.0.3 ratifies KL-002 clarifications (issue vocabulary, 400 not 413/415, suspended token → 401, extra limits, revokeSession 404) | Behaviour already implemented and tested; A2 notified |
| D10 | 2026-10-15 | Backend pins TypeScript 6.0.3 (not 7.0.2) and Vitest+SWC (not Jest) | TS 7 lacks the compiler API typescript-eslint/@nestjs/cli need; Nest 12 is ESM-only |
| D11 | 2026-10-15 | Mobile uses `material_ui` (decoupled Material, flutter.dev) instead of `flutter/material.dart`; Dart 3.13 `new(...)` constructor syntax | go_router 18 requires it; single theme/localizations source |
| D12 | 2026-10-15 | Contract v1.0.4: ARGB token hex, explicit username length check, B7 placeholder id corrected | Documentation only |
| D8 | 2026-10-15 | Token proposals P1–P9, P11, P14 approved as KL-009, applied only after KL-003 merges | Avoid moving target for in-flight Flutter work |

## Blockers (need human input)

See `docs/KNOWN_LIMITATIONS.md` → "Blockers".
