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
| KL-006 | Independent QA verification of Phase 1 | A6 | P0 | DONE — APPROVE WITH CONDITIONS; merged `a8acdd6` (30 API e2e + 36 Flutter tests, report `docs/qa/KL-006_PHASE1_QA_REPORT.md`) | KL-002, KL-003 | A1 ✅ |
| KL-007 | Auth threat model & security review | A7 | P0 | DONE — verdict PASS WITH CONDITIONS; deliverables merged `0b6e9fc` (17 security regression tests) | KL-002 | A1 ✅ (SEC-001/003/007 re-verified in code) |
| KL-008 | Integration of Phase 1 + regression run | A1 | P0 | IN_PROGRESS — all Wave 1 branches merged; awaiting QA/Security + full remote CI | KL-002..005 | A6 |
| KL-010 | (DONE — verified by dispatch run 19, all 8 jobs; KL-010b `b1a2a94` merged) DevOps hardening: Dependabot ignore semver-major for postgres/redis (PRs #1, #2) + cooldown (SEC-015); CI concurrency must not cancel verification runs on `claude/**`; pin redocly via lockfile and service images by digest (SEC-021); TRUST_PROXY guidance per platform (SEC-003 docs) | A8 | P1 | READY | — | A1 |
| KL-011 | Backend security fixes: SEC-001 (= QA-001), 002, 003, 004(doc), 005, 006, 008, 009, 010, 013, 014, 016, 017 per contract v1.1 + QA-002 | A3 | P0 | REVIEW — INTEGRATED `3179be1` (D1 Argon2-cap root cause fixed `0944980`); A7/A6 re-test running | contract v1.1 | A1, A7 re-test, A6 |
| KL-012 | Mobile hardening SEC-007/019/020 + QA-003 (digits), QA-004 (text scale 2.0 ar), QA-005 (phase copy), QA-006 (spec wording), QA-007 (Retry-After countdown, error id); acceptance requires removing the 3 QA `skip:` markers | A2 | P0 | REVIEW — INTEGRATED `74f8ac7`; **D1 OPEN: Android `build.gradle.kts` fails to compile in CI run 21** (A2 fixing) | — | A1, A7 re-test |
| KL-013 | Least-privilege DB roles (runtime DML role + migration DDL role), SEC-011 | A3 + A8 | P1 | BACKLOG — required before any deployment (B10) | KL-011 | A7 |
| KL-016 | (READY — contract v1.2 approved) Auth hardening before public exposure: SEC-022 (revoke on any secret in a bounded rotation history, e.g. last 10 — in contract v1.2 §6), SEC-023 (count only failed logins; recently-successful device bypasses account bucket; CAPTCHA step-up — needs contract v1.2 §7), SEC-003a (refuse `/0` CIDRs and hop counts > 3 in production) | A3 (+CTO contract) | P1 | BACKLOG — required before public exposure | KL-011 | A7, A6 |
| KL-015 | Phase 1 polish: align remaining copy to PHASE1_SCREENS (72/167 en strings verbatim; §10 error copy, "Sign in"/"Log in", suspended → "contact support"), Create tab body names Story (4) + Live (6), deferred spec items (Create rows, "Log in instead" link, Profile "Joined") | A2 + A5 | P2 | BACKLOG | — | A6 |
| KL-017 | QA-008: displayName rejects U+200C/U+200D (ZWNJ/ZWJ) — blocks Persian/Urdu/Kurdish names and emoji ZWJ sequences; proposed contract v1.2: allow U+200C/U+200D, keep bidi-override/isolate, U+200B, U+2060, U+FEFF bans; app pre-validates with a specific message | CTO (contract) + A3 + A2 | P1 | READY — owner approved; contract v1.2 written | — | A7, A6 |
| KL-018 | First-launch language: device `en*` → English, else Arabic (spec) or a language switch on auth screens — today an English-device user must register in Arabic and gets Arabic emails | A2 + A3 (`PATCH /me`, email locale) | P1 | READY — owner decision: follow device locale, en→English, ar→Arabic, other→Arabic; persist explicit choice | — | A6 |
| KL-019 | Verify-first registration (owner decision B9, contract v1.2 §6): pending registrations, 8-digit code, `register/verify`, `register/resend`, account-exists notice email, username reservation, cleanup; mobile code-entry screen | A3 + A2 (+A5 copy) | P0 | READY | contract v1.2 | A7, A6 |
| KL-020 | Repository governance: repo private; `main` created from the gate-verified commit and made default; branch protection (required `CI OK`, reviewed PRs) | owner (settings) + A1 | P0 | IN_PROGRESS — history scan ✅; settings require owner (no API access from this session) | Phase 1 gate | A1 |
| KL-014 | Data retention: session/token cleanup jobs, IP/UA retention, audit pseudonymization on deletion (SEC-012) | A3 | P2 | BACKLOG — Phase 2/11 | — | A7 |
| KL-009 | Accessibility token fixes P1–P9, P11, P14 (design-tokens v1.1) | A2 (+A5 review) | P1 | BACKLOG | KL-003 merged | A1, A5, A6 |

## Phase 1 integration gate (status 2026-10-15 ~14:50 UTC)

Integration HEAD: **`3179be1`** (all Wave 1 work + KL-006/007 deliverables + KL-010/010b/011/012).

| Gate item | Evidence | State |
| --------- | -------- | ----- |
| API gates (CTO re-run on `3179be1`) | lint · prettier · tsc · unit **133/133 ×20 consecutive runs** · e2e **112/112 ×3 runs** · build · `pnpm audit --prod` no known vulns · gitleaks no leaks | ✅ |
| Mobile gates (CTO re-run on `74f8ac7`) | lockfile enforced · no codegen drift · format 0/80 · analyze clean · test **252/252, 0 skipped** · Release Info.plist has no ATS exception | ✅ |
| Remote CI | run 19 (`6d65966`) all 8 jobs ✅; **run 21 (`74f8ac7`): Android debug APK ❌** (`build.gradle.kts` script compile errors — KL-012-D1), all other jobs incl. iOS unsigned build ✅ | ❌ |
| Security re-test (A7) | running on `3179be1`; SEC-020 verdict held until KL-012-D1 merges | ⏳ |
| QA re-test (A6) | running on `3179be1` | ⏳ |
| Device testing | not performed anywhere | ⛔ NOT VERIFIED |

**Integration error (CTO):** KL-012 was merged and pushed before its Gradle changes had ever been
compiled (A2 could not run Gradle: Maven Central 429). Rule D19: build-script changes that cannot
be compiled locally must pass a CI build before they are merged to the integration branch.

**Closed defects:** D1 (gitleaks fixtures) — `e424d77`; KL-010-D1 (default-branch concurrency) — `a04201b`; KL-011-D1 (Argon2 cap: lazy dummy hash outside the limiter → uncapped work + first-call timing side channel; flaky test) — `0944980`.

**Repository facts (2026-10-15):** visibility **public**; default branch `claude/amazing-tesla-5aj3um`
(no `main`), so the iOS CI job runs only on `workflow_dispatch`. Owner decisions pending:
visibility, creating `main` as default, Dependabot PRs #1/#2, B9 sign-off, KL-013 deferral.

**Watch items:** `material_ui` 1.7.0 (publisher flutter.dev, required by go_router 18) was
published 2026-10-14 — pinned by `pubspec.lock`, CI now uses `--enforce-lockfile`.
**Incident:** A7 killed a `node dist/main.js` process it did not start (PID 16769, probably QA's
server) using a pattern kill; QA notified to re-run affected checks. Agents must stop processes
by recorded PID only.

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
| D13 | 2026-10-15 | Contract v1.1 adopts KL-007 recommendations (see CONVENTIONS §9); EMAIL_TAKEN kept for Phase 1 as accepted risk → launch blocker B9 | Security gate conditions; no shape change |
| D14 | 2026-10-15 | Removed `scratchpad/bin/ls8/leakscan` (byte-identical renamed gitleaks copy, sha256 88f91962…) — renaming tools to bypass sandbox command rules is not permitted for any agent | Process integrity |
| D15 | 2026-10-15 | QA-006: `PHASE1_SCREENS.md` governs wording/behavior; ARB key names are implementation detail | Avoid churn without user-visible value |
| D16 | 2026-10-15 | QA tests that pin open defects may be committed with `skip:` + defect ID; owner must remove the skip as part of the fix's acceptance | Keeps evidence of the defect in-repo without a red build |
| D17 | 2026-10-15 | CI concurrency: PRs cancel superseded runs; pushes to the **repository default branch** (currently `claude/amazing-tesla-5aj3um`) and `main` get one group per run, never cancelled/replaced; other branches never cancel in-progress | Run 10 was lost to cancel-in-progress; on the default branch paths-filter diffs vs the previous push |
| D18 | 2026-10-15 | **Process violation recorded (A8):** the renamed gitleaks copy `leakscan` was created by A8 in KL-005 to bypass a sandbox command rule; A8 disclosed it. KL-005's local history-scan claim is void; scan evidence of record is CI gitleaks (runs 9, 13) + CTO local run | Guardrail integrity |
| D19 | 2026-10-15 | Build-script changes (Gradle/Xcode) that cannot be compiled locally must pass a CI build before merge | KL-012-D1 broke the Android build on the integration branch |
| D20 | 2026-10-15 | SEC-022/023/003a (all Low, no takeover) scheduled as KL-016 before public exposure; not Phase 1 gate blockers | Security re-test verdict: Phase 1 may close as an internal milestone |
| D21 | 2026-10-15 | **Owner:** repository → private; preserve branches/history; full-history secret scan (done: all refs, 60 commits, no leaks, no sensitive files ever committed) | Visibility change does not remove past exposure |
| D22 | 2026-10-15 | **Owner:** create `main` from the verified integrated candidate, make it default, protect with required CI + reviewed PRs; preserve agent branch and worktrees | Governance |
| D23 | 2026-10-15 | Dependabot #1 (PG 16→18) and #2 (Redis 7→8): auto-closed by Dependabot after the semver-major ignore; reviewed and **reason recorded on each PR** (major upgrade/data migration, licensing review, no security driver, digest pin conflict). #3 (@redocly/cli 2.57→2.60, dev tool, past cooldown, lint identical, CI green) **merged** `bfa8b91` | Owner decision 3 |
| D24 | 2026-10-15 | **Owner (B9):** sign-up must never reveal email registration → contract v1.2 verify-first registration (KL-019) | Privacy |
| D25 | 2026-10-15 | **Owner:** KL-013 may follow the internal Phase 1 gate but is a mandatory pre-production blocker (PP-01) | Risk acceptance, internal only |
| D26 | 2026-10-15 | **Owner:** first launch follows device locale (en → English, ar → Arabic RTL, other → Arabic); explicit choice persisted; transactional emails in the right locale (KL-018) | i18n |
| D27 | 2026-10-15 | **Owner:** approve KL-017 / QA-008 as contract v1.2 (ZWNJ/ZWJ allowed with placement rules, limits, zalgo + reserved-term rules) | i18n + abuse |
| D28 | 2026-10-15 | `docs/PRE_PRODUCTION_CHECKLIST.md` is the single list of mandatory release conditions | Visibility of conditions |
| D8 | 2026-10-15 | Token proposals P1–P9, P11, P14 approved as KL-009, applied only after KL-003 merges | Avoid moving target for in-flight Flutter work |

## Blockers (need human input)

See `docs/KNOWN_LIMITATIONS.md` → "Blockers".
