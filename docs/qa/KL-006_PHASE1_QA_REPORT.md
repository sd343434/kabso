# KL-006 — Independent QA verification of the Phase 1 candidate

| | |
| - | - |
| Agent | A6 (QA & Test) |
| Date | 2026-10-15 |
| Candidate tested | `b973d7b` (Merge KL-003), which contains KL-002 `f45b867`, KL-002-D1 `217cad6`, KL-004 and KL-005 |
| Re-test | `3179be1` (KL-011 + KL-012 fixes, contract v1.1). See **§8**, which supersedes §4 and §7 for defect status. |
| v1.2 re-test (KL-006c) | `ed84dd4` (contract v1.2 / v1.2.1 / v1.2.2, openapi 1.2.0). See **§9**. |
| Contract | `CONVENTIONS.md` v1.0.3, `openapi.yaml` 1.0.0-phase1 |
| Environment | Node 22.22.0, pnpm 10.28.0, PostgreSQL 16 (`kabso_qa_test`), Redis 7 (db 14), Flutter 3.47.7 / Dart 3.13.5. No Android SDK or Xcode. |

Rule applied: a criterion is **PASS** only if I ran the evidence myself. Implementer reports were not
used as evidence.

## 1. Gate results (re-run by A6 on `b973d7b`)

### API (`apps/api`; `DATABASE_URL=…/kabso_qa_test`, `REDIS_URL=redis://localhost:6379/14`)

| Gate | Result |
| ---- | ------ |
| `pnpm install --frozen-lockfile` | OK, 548 packages, lockfile up to date |
| `pnpm prisma:generate` | OK (Prisma Client 7.10.0) |
| `pnpm prisma:migrate:deploy` | OK, `20261015132258_init` applied → 6 tables, 5 CHECK constraints (`user_profiles_username_format`, `users_email_normalized`, `user_profiles_locale_valid`, `sessions_platform_valid`, `sessions_expiry_order`) |
| `pnpm lint` | exit 0, 0 problems |
| `pnpm format:check` | "All matched files use Prettier code style!" |
| `pnpm typecheck` | exit 0 |
| `pnpm test` (unit) | **73/73** passed, 9 files |
| `pnpm test:e2e` (candidate suite) | **44/44** passed, 3 files |
| `pnpm test:e2e` (+ QA suite added here) | **74/74** passed, 4 files (44 existing + 30 new) |
| `pnpm build` | exit 0, `dist/main.js` produced |

### Mobile (`apps/mobile`)

| Gate | Result |
| ---- | ------ |
| `flutter pub get` | OK |
| `dart run build_runner build --delete-conflicting-outputs` | OK, "wrote 5 outputs" |
| `git diff --exit-code` (codegen drift) | exit 0, no drift |
| `dart format --output=none --set-exit-if-changed lib test` | 71 files, 0 changed (73 with QA tests) |
| `flutter analyze` | "No issues found!" (also with the QA tests) |
| `flutter test` (candidate) | **162/162** passed |
| `flutter test` (+ QA tests added here) | **196 passed, 3 skipped**. The 3 skips are QA regression tests for defects QA-003 and QA-004; each carries its defect ID. |

### Black-box contract run (API on `localhost:3101`, `kabso_qa_test`, Redis db 14, default rate limits except register)

A standalone script (fetch-based) ran **131 checks: 128 PASS, 3 FAIL**. The 3 failures are QA-001 (2 checks) and
QA-002 (1 check). The result was reproduced on two separate runs (`bb2`, `bb3`). One earlier attempt
failed with `ECONNREFUSED`. That was environmental: another agent's broad `pkill` stopped the server. It is not a product defect.

## 2. Acceptance criteria → evidence

Legend: **PASS** (ran and passed) · **FAIL** (ran and failed) · **PARTIAL** · **NOT VERIFIED** · **GAP→QA** (no test existed; A6 added one, and it passes).

### KL-002 Backend auth slice

| Criterion | Evidence | Status |
| --------- | -------- | ------ |
| Every `openapi.yaml` endpoint implemented with exact shapes | `test/qa/kl006-contract.e2e-spec.ts` › "register, login, refresh, me, sessions, username-availability" (exact key sets, ISO-8601 `…sssZ`, UUIDs); `auth.e2e-spec.ts` › "creates the account…"; black-box: 14 routes, no extra fields, `Content-Type: application/json; charset=utf-8`, 204/202 bodies empty | PASS |
| Error codes and envelope per CONVENTIONS §4 | `error-mapping.spec.ts` › "matches CONVENTIONS §4 exactly"; QA `expectEnvelope` checks on every error (exact keys `code,message,requestId[,details]`, `requestId` == `X-Request-Id`, no stack traces); black-box: VALIDATION_FAILED, AUTH_*, ACCOUNT_SUSPENDED, NOT_FOUND, EMAIL_TAKEN, USERNAME_TAKEN, TOKEN_EXPIRED, TOKEN_INVALID, RATE_LIMITED, SERVICE_UNAVAILABLE all observed | PASS |
| v1.0.3: body errors → 400 with `field:""` (no 413/415) | `platform.e2e-spec.ts` › malformed / oversized; QA › wrong content type (text/plain, form), JSON array / string / empty body | PASS (GAP→QA for content type) |
| v1.0.3: suspended access token → 401; 403 only on login/refresh | `auth.e2e-spec.ts` › "refuses suspended accounts with 403"; black-box suspension block; QA › suspended + wrong password → 401 | PASS |
| v1.0.3: `revokeSession` malformed id → 404 | `auth.e2e-spec.ts` › "revokes own sessions and returns 404…"; black-box | PASS |
| Prisma schema + initial migration (6 tables) | `migrate deploy` on an empty `kabso_qa_test`; 6 tables, 5 CHECKs; `auth.e2e` › "enforces the username format in the database" | PASS |
| Argon2id | `auth.e2e` › "creates the account…" asserts `$argon2id$` | PASS |
| Refresh rotation | `auth.e2e` › "rotates…", "lets exactly one of several concurrent refreshes…" | PASS |
| Reuse detection | `auth.e2e` › "detects reuse…" (`REFRESH_REUSE`, audit `matchedPrevious: true`) | PASS, but see **QA-001** (overbroad: a never-issued secret also revokes) |
| Immediate revocation (logout, session revoke, suspension, password reset) | `auth.e2e` logout / sessions; `email-password.e2e` › "reset … revokes every session"; QA › "two independent sessions…", "upper-case id", "second logout" | PASS |
| Redis rate limits (all §7 rules) | `platform.e2e` › login IP+identifier, forgot per email, per user; **QA** › register/IP, refresh/session, resend/user, public/IP, login/IP (each 429 + integer `Retry-After` ≤ window); black-box › 11th login (mixed case identifier) → 429, `Retry-After: 900` | PASS (5 rules were GAP→QA) |
| Rate limiting fails closed (503) when Redis is down | **QA** › "Redis outage…" (`/health/ready` 503 `redis: down`, login and username-availability 503 `SERVICE_UNAVAILABLE`, `/health/live` 200) | PASS (GAP→QA) |
| Log mail adapter | Black-box server log: `[dev mail] email_verification → open http://localhost:3101/verify-email?token=…`; `app-config.spec` › refuses `log` in production | PASS |
| Health endpoints | `platform.e2e`; QA outage test; black-box | PASS |
| zod-validated config | `app-config.spec.ts` (5 tests) | PASS |
| E2E coverage list (happy paths, validation, duplicates, no enumeration, rotation, reuse, logout, revoke, suspended, reset revokes sessions, rate limiting) | All present in `auth.e2e-spec.ts`, `email-password.e2e-spec.ts`, `platform.e2e-spec.ts`; all ran green | PASS |
| Lint, typecheck, tests green | §1 | PASS |

### KL-003 Flutter slice

| Criterion | Evidence | Status |
| --------- | -------- | ------ |
| Boots splash → auth gate | `app_shell_test` › "no stored token → login, without any request"; `auth_redirect_test` (7) | PASS |
| Arabic default (RTL) + English | **QA** › "language defaults to Arabic and theme to dark"; `app_shell_test` › RTL group (nav mirrors); `auth_forms_test` › "Arabic: RTL…" | PASS (default was GAP→QA) |
| Dark default + light themes from design tokens | QA defaults test (dark); QA text-scale suite renders every tab in dark and light | PASS (token-to-JSON parity not tested; out of KL-006 scope, tracked by KL-009) |
| 5-tab `StatefulShellRoute`, honest empty states | `app_shell_test` › "renders 5 tabs and switches branches"; grep finds no dead `onPressed`/fake data | PARTIAL: phase numbers contradict the spec (**QA-005**) |
| Login / register (live availability) / forgot / verify-notice wired to API | `auth_repository_impl_test` (17, fake HTTP shaped by openapi); `auth_forms_test` (14); **QA** › stale availability response test | PASS (verify-notice screen itself has no widget test; only its redirect is tested) |
| Dio client: envelope mapping | `error_mapper_test` (every §4 code, Retry-After, unknown codes, offline/timeout) | PASS |
| Single-flight refresh | `auth_interceptor_test` › "N concurrent 401s → exactly one refresh…", "a 401 arriving after another request refreshed…"; **QA** › "401 on a protected call → refresh rejected → login with banner" (end-to-end through router) | PASS |
| Refresh token in secure storage, access token in memory | `TokenManager` / `InMemoryTokenStore` tests | PASS (logic). Real Keychain/Keystore: **NOT VERIFIED** (no device) |
| Session restore on launch | `app_shell_test` › "stored token → refresh → /me → home", suspended, offline keeps token | PASS |
| Logout | `app_shell_test` › "settings: … logout"; `auth_repository_impl_test` › "clears local tokens even when the server call fails" | PASS |
| Loading / error / empty states | Splash error + retry tested; settings sessions error/retry and profile error state have no test | PARTIAL |
| Required unit and widget tests exist | listed above | PASS |
| `dart format`, `flutter analyze` 0 issues, `flutter test` green | §1 | PASS |
| Android / iOS builds, device runs | No SDK in this environment | **NOT VERIFIED** |

### PHASE1_SCREENS.md §11 QA checklist

| # | Check | Evidence | Status |
| - | ----- | -------- | ------ |
| 1 | ar/en × dark/light × text 1.0/2.0 at 360×640 without overflow | **QA** `kl006_text_scale_test.dart`: 24 cases (login, register, forgot, 5 tabs, profile, settings) pass; settings in **ar @ 2.0** fails | FAIL (**QA-004**); splash and verify-notice not covered |
| 2 | No hard-coded strings; every spec key in both ARBs | **QA**: no `Text('literal')` in lib/; ar/en ARB key and placeholder parity. 126 of 171 keys named in the spec are absent by name, and much of the copy differs | PARTIAL (**QA-006**) |
| 3 | Directional icons flip in RTL | lib/ uses no directional icons except the framework `BackButton` (which mirrors) | NOT VERIFIED visually |
| 4 | Username availability states; stale responses never overwrite | `auth_forms_test` (checking/available/taken, debounce, lowercase); **QA** › out-of-order response test. 5 states are implemented (idle, checking, available, taken, check-failed); the spec says 6 | PASS (state count: see QA-006) |
| 5 | Forgot flow identical for registered and unregistered | `auth_forms_test` › "always shows the same neutral confirmation"; API black-box: identical empty 202 bodies | PASS |
| 6 | Each §10 code → specified copy and presentation | `failure_messages_test` (distinct message per code, ar/en). `Retry-After` countdown and Error ID are never rendered | FAIL (**QA-007**) |
| 7 | Logout clears storage offline; splash keeps tokens on network errors | `auth_repository_impl_test`, `app_shell_test` › offline restore | PASS |
| 8 | Revoking another session removes it; NOT_FOUND = already ended | **QA** › 4 settings tests (success, NOT_FOUND refreshes the list, cancel, no action on the current device) | PASS functionally; copy is a generic error, not "already ended" (QA-006) |
| 9 | Targets ≥ 48 dp; focus order; screen reader | **QA** › `androidTapTargetGuideline` and `labeledTapTargetGuideline` on login/register/forgot (ar, en); bottom nav ≥ 48×48 | PASS for tap targets; focus order / TalkBack / VoiceOver **NOT VERIFIED** |
| 10 | Reduce motion | Code: `KSkeleton` and `KMotion.of` honour `disableAnimations`; route transitions are framework defaults | PARTIAL / NOT VERIFIED |
| 11 | Latin digits in Arabic | **QA** test (skipped, QA-003): settings shows `١٥ أكتوبر ٢٠٢٦ ١٢:٣٠ م` | FAIL (**QA-003**) |
| 12 | Phase empty states name the correct phase, no fake data | ARB copy vs spec §6 | FAIL (**QA-005**) |

## 3. Black-box API checks beyond the e2e suite (all PASS unless noted)

- Success shapes: AuthResponse, Me (`bio`/`avatarUrl` present and null), TokenPair, `{data: SessionInfo[]}`, availability. No extra fields. Timestamps match `^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$`. Access TTL 900 s, refresh 30 d. JWT claims are exactly `sub,sid,typ,iat,exp,iss,aud`, HS256.
- `X-Request-Id`: echoed when valid, including exactly 64 chars. Replaced when > 64 chars or containing a space. Equals `error.requestId`.
- Malformed JSON → `malformed_json`. 300 KB body → 400 `payload_too_large`. `text/plain`, form-encoded, or missing content type → 400 `field:""`. JSON array, string, or empty body → 400. `__proto__` key → no 500. Unknown body field and unknown query parameter → `unknown_field`. Wrong type → `invalid_type`.
- Uppercase username → 400 `invalid_format` (register and availability). Whitespace-only displayName → `too_short`. Tab/NUL → `invalid_format`. 51 chars → `too_long`. 50 Arabic chars and 26 emoji accepted. `"  عبد الله ✨ Ünïcødé 😀  "` round-trips trimmed via register and `GET /me`. Email trimmed and lowercased.
- Login: uppercase email, uppercase username, and padded identifier all → 200. Unknown user vs wrong password → identical body. Suspended + wrong password → 401.
- JWT: garbage, empty, `alg:none`, expired (real key), foreign key, wrong aud/iss, `typ:refresh`, unknown `sid`, other user's `sub` with own `sid`, tampered payload, refresh token as bearer, `Basic` scheme → all 401 `AUTH_UNAUTHENTICATED`. Lowercase `bearer` → 401 (**QA-002**).
- Refresh: < 10 or > 200 chars → 400. No dot, non-UUID sid, two dots, non-ASCII, empty secret → 401 `AUTH_REFRESH_INVALID`. Numeric → 400. **Known sid + random secret revokes the session (QA-001).**
- Two sessions: revoking A from B → 204 with empty body. A's access and refresh are dead immediately. B's access and rotation still work. Second revoke → 404. Malformed id → 404. Uppercase id → 204. Sessions are listed newest first.
- Rate limit: 11th login (identifier case alternating) → 429 `RATE_LIMITED`, `Retry-After: 900`. A correct password is also refused while limited. A different identifier from the same IP is not affected.
- Forgot: known vs unknown email → both 202 with identical empty body.

Nothing contradicts `openapi.yaml` / CONVENTIONS v1.0.3 except QA-001, which goes beyond §6's definition of reuse.

## 4. Defects

| ID | Sev | Owner | Summary |
| -- | --- | ----- | ------- |
| QA-001 | Medium | A3 (+A7 / CTO decision) | Any refresh token carrying a victim's session id plus a random secret revokes that session |
| QA-002 | Low | A3 | `Authorization` scheme is matched case-sensitively (`bearer` → 401) |
| QA-003 | Medium | A2 | Arabic dates use Arabic-Indic digits (checklist #11) |
| QA-004 | Medium | A2 | Settings session tile breaks layout in Arabic at text scale 2.0 (checklist #1) |
| QA-005 | Medium | A2 (+A5 copy) | Empty-state copy names the wrong phases (checklist #12) |
| QA-006 | Low | A2 / A5 / CTO | l10n keys and copy diverge widely from PHASE1_SCREENS.md (checklist #2, #4, #8) |
| QA-007 | Medium | A2 | `RATE_LIMITED` countdown and Error ID are never shown (checklist #6) |

### QA-001: a never-issued secret is treated as reuse and revokes the session (Medium, A3)

- **Where:** `apps/api/src/modules/auth/sessions.service.ts` `rotate()`. Any secret that is not the current hash revokes the session with `REFRESH_REUSE`.
- **Contract:** CONVENTIONS §6 defines reuse as "presenting a *previously rotated* secret". Here, a random secret that was never issued also revokes.
- **Impact:** Anyone who knows a session id can sign that device out, with no secret needed. Where session ids are exposed:
  - the `sid` claim of every access token;
  - the prefix of the refresh token;
  - plaintext request logs (`"url":"/api/v1/auth/sessions/01a13fdf-…"`, 6 occurrences in one run).

  The result is targeted forced logout, a DoS against a single session.
- **Repro** (server on 3101; script used: `repro-qa001.sh`):
  1. Register → keep `accessToken` (AT) and `refreshToken` (RT). Let `SID = RT.split('.')[0]`.
  2. `POST /api/v1/auth/refresh {"refreshToken":"<SID>.<43 random base64url chars>"}`
  3. `GET /api/v1/me` with AT.
- **Expected:** step 2 → 401 `AUTH_REFRESH_INVALID`; the victim's session stays usable (3 → 200, and RT still rotates).
- **Actual:**

  ```
  1) GET /me before: 200
  2) refresh with sid+random secret: {"error":{"code":"AUTH_REFRESH_INVALID",…}}
  3) GET /me after: 401
  4) victim's real refresh: {"error":{"code":"AUTH_REFRESH_INVALID",…}}
  db: revoked_reason=REFRESH_REUSE
  ```
- **Suggested fix:** revoke only when the presented hash equals `previousRefreshTokenHash` (`matchedPrevious` is already computed). Otherwise return 401 without revoking. If the stricter behaviour is intended, CTO/A7 should ratify it in CONVENTIONS and stop logging session ids in URLs.
- **Not committed as a test** (it would fail). Black-box checks: "random-secret refresh with a known sid does not revoke the live session" and "victim can still refresh after random-secret attempt".

### QA-002: case-sensitive `Bearer` scheme (Low, A3)

- **Where:** `access-token.guard.ts`, regex `^Bearer …`.
- **Repro:** `GET /api/v1/me` with `Authorization: bearer <valid AT>`.
- **Expected:** 200. Auth schemes are case-insensitive per RFC 7235 §2.1 and RFC 6750.
- **Actual:** 401 `AUTH_UNAUTHENTICATED`.
- **Impact:** None for the shipped app (it sends `Bearer`). This is an interoperability issue for other clients and proxies.

### QA-003: Arabic-Indic digits in Arabic (Medium, A2)

- **Where:** `lib/features/settings/settings_screen.dart` `_SessionTile`: `DateFormat.yMMMd('ar').add_jm()`.
- **Repro:** `apps/mobile/test/qa/kl006_qa_test.dart` › "session dates in Arabic use Latin digits". Remove `skip: true` and run `flutter test test/qa/kl006_qa_test.dart`.
- **Expected:** Latin digits (PHASE1_SCREENS §9 relative time, §11 #11).
- **Actual:** `هذا الجهاز · أندرويد · آخر نشاط: ١٥ أكتوبر ٢٠٢٦ ١٢:٣٠ م`.

### QA-004: settings layout error in Arabic at text scale 2.0 (Medium, A2)

- **Where:** `_SessionTile`. The trailing `TextButton` (Arabic "sign out" label) consumes the whole `ListTile` width.
- **Repro:** `apps/mobile/test/qa/kl006_text_scale_test.dart` › "ar/{dark,light}/x2.0: settings (sessions list) has no layout error". Remove the `skip:` and run.
- **Expected:** no exception at 360×640 dp, text scale 2.0.
- **Actual:** `Trailing widget consumes the entire tile width (including ListTile.contentPadding)` (material_ui `list_tile.dart:1588`), followed by about 6,000 cascading semantics assertions. In release builds this means a broken layout.
- **Scope:** en @ 2.0, ar @ 1.0, and every other screen tested pass.

### QA-005: empty states name the wrong phases (Medium, A2 + A5)

The copy in `lib/l10n/app_en.arb` and `app_ar.arb` disagrees with PHASE1_SCREENS §6:

| Key | App says | Spec says |
| --- | -------- | --------- |
| `homeComingBody` | "Posts and stories … arrive in Phase 2." | feed/follow Phase 2, posts Phase 3 |
| `discoverComingBody` | "Search and trending creators arrive in Phase 9." | people search Phase 2, trending Phase 9 |
| `profileContentComingBody` | "Your posts, followers and highlights arrive in Phase 2." | followers Phase 2, posts Phase 3, stories/highlights Phase 4 |
| `liveComingBody` | (omits) | PK/gifts Phase 7 |

This is user-facing misinformation (checklist #12).

### QA-006: l10n keys and copy diverge from the screen spec (Low, A2 / A5 / CTO)

- `scratchpad/keys.py` compares the spec with the ARB files. Of 171 spec keys that carry Arabic copy, 126 are absent by name. Examples: the `err*` → `error*` renames, `comingInPhase`, `sessionsAlreadyEnded`, `errorIdLabel`, `errRateLimitedWait`, the `forgotSent*` family, `registerTerms`.
- The copy also differs:
  - `EMAIL_TAKEN`: "This email is already registered." (spec: neutral wording);
  - "Last active {date}" uses an absolute date instead of relative time;
  - a revoke that returns `NOT_FOUND` shows the generic "We couldn't find that." instead of "This session had already ended".
- The username indicator has 5 states; the spec says 6.
- **Needs a CTO decision:** is the spec or the implementation the source of truth for Phase 1 copy? Then align one to the other.

### QA-007: no `Retry-After` countdown and no Error ID (Medium, A2)

- `AppFailure.retryAfter` and `requestId` are parsed (`core/network/error_mapper.dart`) but never rendered anywhere in `lib/` (grep shows only `core/error` and `core/network` hits).
- **Expected** (PHASE1_SCREENS §10):
  - `RATE_LIMITED` with `Retry-After` → "Too many attempts. Try again in {m:ss}" plus a disabled CTA countdown;
  - `INTERNAL_ERROR`, `SERVICE_UNAVAILABLE` and unknown codes → a selectable Error ID.
- **Actual:** a static generic message only. This matters on login, where the API returns `Retry-After: 900`.

## 5. Not verified

- Android/iOS builds, emulator/device runs, real Keychain/Keystore behaviour, font rendering, IME, TalkBack/VoiceOver and focus order (no Android SDK or Xcode, blocker B6). CI `android`/`ios` jobs are the only proof.
- Checklist #3 (visual icon mirroring) and #10 (route transitions under reduce motion).
- Splash and verify-notice screens at text scale 2.0.
- CI on GitHub (KL-005) and the gitleaks D1 re-run. Not in A6 scope and not run here.
- Spec screens that are not in KL-003's acceptance list: reset-password and verify-result deep links, terms. Recorded here as a scope gap for the CTO, not as a defect.

## 6. Tests added by A6 (this commit)

- `apps/api/test/qa/kl006-contract.e2e-spec.ts`: **30 e2e tests**, all passing. They cover:
  - exact openapi shapes and JWT claims;
  - Unicode/Arabic displayName round-trip and boundaries;
  - uppercase username, whitespace and control-character displayName;
  - dotted detail paths;
  - username-case login;
  - suspended + wrong password → 401;
  - wrong content type and non-object JSON;
  - 64-char request id;
  - 11 forged/expired/mis-scoped JWTs at the guard;
  - refresh token formats;
  - two independent sessions;
  - double logout;
  - expired reset token → 410;
  - 5 previously untested rate-limit rules;
  - Redis outage → fail closed.
- `apps/mobile/test/qa/kl006_qa_test.dart`: 12 tests, 11 passing and 1 skipped (QA-003). They cover:
  - session revoke flows (success, NOT_FOUND, cancel, no action on the current device);
  - session expiry mid-use through interceptor + router;
  - tap-target and label guidelines;
  - ARB parity;
  - the no-literal-`Text` scan;
  - fresh-install defaults (ar, dark);
  - stale availability responses.
- `apps/mobile/test/qa/kl006_text_scale_test.dart`: 24 tests, 22 passing and 2 skipped (QA-004).

No production code was modified.

## 7. Recommendation

**Approve with conditions.**

- **API (KL-002): approve.** Every acceptance criterion passed under independent test, and the contract holds in 128/131 black-box checks. QA-001 must be decided (fix, or ratify plus stop logging session ids) before any public exposure. It is not a blocker for integration. QA-002 is cosmetic.
- **Mobile (KL-003): approve for integration, not DONE.** All gates are green, and the core auth/refresh/restore/logout behaviour passes independent tests. Before KL-003 is marked DONE, A2 should fix QA-003, QA-004, QA-005 and QA-007, then remove the `skip:` markers in `test/qa`. QA-006 needs a CTO decision on whether the spec or the implementation sets Phase 1 copy.
- **Release readiness: not verifiable here.** No device or store builds were possible.

## 8. Re-test on `3179be1` (2026-10-15, after KL-011 / KL-012)

- **Integration:** `git merge --no-edit claude/amazing-tesla-5aj3um` fast-forwarded the worktree to **`3179be1`**.
- **My tests on the branch:** A6 commit `119e37e` is an ancestor. `git diff 119e37e 3179be1 -- apps/*/test/qa` shows only the three `skip:` removals (QA-003, QA-004), as the CTO stated.
- **Resources used again:** `kabso_qa_test`, Redis db 14, port 3101.
- **Contract:** CONVENTIONS **v1.1** (D13) and D15 (spec governs wording, not key names).

### 8.1 Gates (re-run by A6)

| Gate | Result |
| ---- | ------ |
| `pnpm install --frozen-lockfile` | OK |
| API `prisma:generate` / `lint` / `format:check` / `typecheck` | all exit 0; lint 0 problems; "All matched files use Prettier code style!" |
| API `test` (unit) | **133/133**, 16 files |
| API `test:e2e` | **112/112**, 7 files (includes the 30 A6 QA tests); no pending migrations |
| API `build` | exit 0, `dist/main.js` |
| Mobile `flutter pub get`, `build_runner` | OK ("wrote 1 output") |
| Codegen drift `git diff --exit-code` | clean (empty `git status`) |
| `dart format --set-exit-if-changed lib test` | exit 0, 0 changed (80 files; 81 with the new QA file) |
| `flutter analyze` | "No issues found!" |
| `flutter test` (as integrated) | **252 passed, 0 skipped** |
| `flutter test` (+ new `test/qa/kl006_retest_test.dart`) | **267 passed, 0 skipped** |
| Black-box script (131 original + 16 v1.1 checks) | **147/147 PASS**, including the 3 previous failures |

### 8.2 Defect re-verification

| ID | Status | Evidence (run by A6) |
| -- | ------ | -------------------- |
| QA-001 (= SEC-001) | **FIXED** | See note 1. |
| QA-002 | **FIXED** | `Authorization: bearer <AT>` → **200** (repro step 5). `Basic` and garbage are still 401 (black-box). |
| QA-003 | **FIXED** | Previously skipped `kl006_qa_test` › "session dates in Arabic use Latin digits" passes unskipped. New test: an Arabic register countdown renders `12:34` with no U+0660–0669 / U+06F0–06F9 digits. `KFormat` sets `useNativeDigits = false`. |
| QA-004 | **FIXED** | See note 2. |
| QA-005 | **FIXED** | See note 3. |
| QA-006 (D15 items) | **FIXED** | See note 4. |
| QA-006 (broader wording) | **OPEN, Low** | See note 5. |
| QA-007 | **FIXED** | See note 6. |

**Note 1: QA-001.**
- **Repro script (same as before):**

  ```
  1) GET /me before: 200
  2) refresh <sid>.<random>: 401 AUTH_REFRESH_INVALID
  3) GET /me after: 200
  4) victim's real refresh: 200 (new pair)
  ```

  The DB shows `revoked_reason` NULL, and the audit log records `auth.refresh.invalid_secret`.
- **Previous secret still revokes** (black-box v1.1):
  - rotate;
  - replay the previous secret → 401;
  - the rotated access token and refresh token → both 401.
- Session ids still appear in request-log URLs. Under v1.1 they are public, so this no longer matters.

**Note 2: QA-004.**
- `kl006_text_scale_test`: all 24 cases pass, including ar/en × dark/light × 1.0/2.0 for login, register, forgot, the 5 tabs, profile and settings. The ar@2.0 settings cases are unskipped.
- New tests at 2.0, in ar and en:
  - splash restore error;
  - verify-email notice;
  - login with a 1:02:05 countdown + Error ID banner;
  - register with every field error.

  `takeException()` returns null in every case.

**Note 3: QA-005.**
- The Home, Discover, Live and Profile bodies match PHASE1_SCREENS §6 **verbatim** in en and ar.
- Create names correct phases (posts 3, videos 5) but omits Story (4) and Live (6), because the rows were not built (§8.3).

**Note 4: QA-006 items listed under D15.**
- **EMAIL_TAKEN:** en is the spec text verbatim ("This email can't be used to create a new account…").
- **Revoke NOT_FOUND:** new test › "shows 'already ended' and removes the row". It shows `sessionsAlreadyEnded`, does not show `errorNotFound`, and the row disappears.
- **Relative "last active":** the same test shows "5h ago" for a session active 5 h earlier.
- **Six username states:** idle, invalid, checking, available, taken and unknown exist in `auth_controller.dart`. A2's test "unknown state: check failed → neutral hint, submit allowed" passes, and the server still decides.

**Note 5: QA-006 broader wording.**
- The `scratchpad/copy.py` text match finds **72/167** spec en strings verbatim; 95 differ.
- Most differences are in §10 error copy. For example:
  - `errorAuthInvalidCredentials` is "Incorrect email, username or password." vs the spec's "The email/username or password is incorrect.";
  - `errorAccountSuspended` lacks "…contact support".
- "Sign in" vs "Log in" terminology also differs, and some screens/strings are not built (reset, Create rows, Settings groups).
- Under D15 the spec governs wording, so A2 + A5 should align the remaining strings. This is non-blocking.

**Note 6: QA-007.**
- A2's login tests pass.
- A6's independent tests (new file) cover:
  - **Register:** 429 → `2:05` → `2:03`, submit disabled (`registerCalls` stays 1), re-enabled at zero.
  - **Register, Argon2-cap 503:** `0:03` countdown, disabled, selectable `Error ID: rid-argon-503`.
  - **Forgot:** 429 for 3600 s → `1:00:00` then `59:59`, disabled.
  - **Forgot, 503:** disabled until zero.
  - **Unknown code** → `errorUnknown` + selectable Error ID.
- **Server side:** the API was started with `ARGON2_MAX_CONCURRENCY=1 ARGON2_MAX_QUEUE=0` and hit with 8 concurrent logins → `{"401":1,"503":7}`, 503 body `SERVICE_UNAVAILABLE` "Password hashing capacity exhausted.", `Retry-After: 1`. Unknown-user logins are capped too, so there is no timing oracle.

### 8.3 A2's deliberately kept differences

| Difference | Classification | Reason |
| ---------- | -------------- | ------ |
| Arabic default regardless of device locale (spec §1: device `en*` → `en`) | **Acceptable for Phase 1 internal builds; not for public launch** | See note A. |
| "End" button label | **Acceptable** | See note B. |
| Settings theme/language as inline segmented controls, not bottom sheets (§9.2) | **Acceptable** | Same choices, same immediate apply, fewer taps. Widget tests cover switching. There is no accessibility regression (tap-target guideline passes). |
| Create tab: no 4 disabled rows with phase badges | **Acceptable for Phase 1, with a copy condition** | The rows are informational only (disabled), so no function is missing and there are no dead buttons. The body copy should then name all four phases (Story 4, Live 6 are missing; note 3). |

**Note A: Arabic default.**
- KL-003's acceptance criterion says "Arabic default", so this is conformant with the task.
- However, language can only be changed in Settings **after** sign-in (`languageControllerProvider` is used only by `settings_screen.dart`).
- An English-device user therefore has to log in or register in Arabic, and register sends `locale: ar`, which makes their emails Arabic.
- Before launch, either follow spec §1 or add a language switch to the auth screens.

**Note B: "End" label.**
- The `sessionsRevoke` row label now matches the spec ("End" / "إنهاء").
- The confirm button reuses it instead of the spec's "End session" (`sessionsRevokeConfirm`). The meaning is identical, and the dialog title says "End this session?".

### 8.4 New findings

**QA-008 (Low; owner CTO/A7 for the contract, A2 for the message): v1.1 rejects ZWJ/ZWNJ in `displayName`.**
- **Where:** CONVENTIONS v1.1 / `auth.schemas.ts` reject U+200B–U+200D in `displayName`.
- **Repro:** register with `displayName: "عائلة 👨‍👩‍👧"` → **400** `invalid_format` (black-box `bb4`).
- **Impact:**
  - Common emoji ZWJ sequences are refused (👨‍👩‍👧, 🏳️‍🌈, ❤️‍🔥, profession emoji).
  - U+200C (ZWNJ) is required in Persian/Urdu/Kurdish orthography.
  - The app has no client-side check, so the user only sees a generic field error.
- **Behaviour is contract-conformant.** This is a product/i18n decision, so I've recorded it rather than failing anything.
- **Suggestion:** allow U+200C/U+200D, or allow them only inside emoji/joining contexts, while keeping the bidi-override and BOM bans.

No other new defects. KL-002 and KL-003 acceptance criteria were regression-checked:
- all original e2e tests and A6 QA e2e tests are inside the green 112;
- all original and A6 Flutter tests are inside the green 267;
- the black-box contract run is 147/147.

### 8.5 Open items, not verified

- **KL-012-D1:** the Android debug APK fails to compile in CI (`android/app/build.gradle.kts`), fix in progress. This is outside A6 scope; noted as open.
- Device builds/runs, real Keychain/Keystore, screen readers and focus order are still **NOT VERIFIED** (no Android SDK/Xcode).
- Two items are not verifiable headlessly:
  - the iOS Debug-only ATS build phase;
  - Android backup exclusion (SEC-019).

### 8.6 Updated recommendation

**Approve.** Phase 1 KL-002 and KL-003 can be marked DONE from a QA standpoint, with these non-blocking conditions:
1. A2 + A5 align the remaining wording to PHASE1_SCREENS (QA-006 residual), including the Create body phases.
2. Before public launch, resolve the language-at-first-launch deviation (§8.3) and decide QA-008.
3. Release readiness still depends on KL-012-D1 (APK compile) and device verification in CI. Neither can be checked here.

Every QA-001…QA-007 item is verified fixed by A6's own runs.

## 9. v1.2 re-test — KL-006c on `ed84dd4` (2026-10-16)

- **Integration:** `git merge --no-edit claude/amazing-tesla-5aj3um` fast-forwarded to **`ed84dd4`**: KL-017b mobile, KL-009 tokens v1.1, and the KL-022 P0 live components + golden infra merge.
- **Specs read:**
  - CONVENTIONS §6, §7, §9 (v1.2, v1.2.1, v1.2.2);
  - openapi 1.2.0;
  - PHASE1_1_SCREENS;
  - PRE_PRODUCTION_CHECKLIST PP-02, PP-21, PP-22.
- **Resources:** `kabso_qa_test`, Redis db 14, API on :3101 (PID 13558, stopped by PID).
- **Temp files:** `scratchpad/qa/` only (D30).

### 9.1 Gates (re-run by A6)

| Gate | Result |
| ---- | ------ |
| `pnpm install --frozen-lockfile` | OK |
| API `prisma:generate` / `lint` / `format:check` / `typecheck` / `build` | all exit 0 |
| API unit | **233/233** (18 files) |
| API e2e (as integrated) | **148/148** (9 files); migration `20261015151159_verify_first_registration` applied to `kabso_qa_test` |
| API e2e (+ new `test/qa/kl006c-v12.e2e-spec.ts`) | **197/197** (10 files; +49) |
| Mobile `pub get`, `build_runner`, drift (`git status` empty), `dart format` (0 changed) | OK |
| `flutter analyze` | "No issues found!" |
| `flutter test` (as integrated) | **440 passed, 0 skipped** |
| `flutter test` (+ new `test/qa/kl006c_v12_test.dart`) | **451 passed, 1 skipped**. The skip is QA-011, pinned per D16. |
| `flutter test --tags golden` | **28/28** |
| Black-box v1.2 script (`bb12.mjs`): verify-first / displayName / locale | **41 + 58 = 99/99 PASS** |
| Adapted 147-check black-box suite (`blackbox12.mjs`, `V11=1`) | **148/148 PASS** (one check split in two, see §9.5) |
| Reserved-term bypass probes (`probe-reserved.mjs`) | 20/21 rejected as intended (see §9.3) |

### 9.2 Item 1: verify-first registration (PP-02) — **PASS**

All evidence below comes from A6's black-box run against :3101: real Argon2, the log mail transport, and psql.

| Check | Result |
| ----- | ------ |
| New vs existing email | Both **202** with body `{"status":"verification_pending"}`. Every response header is identical except `x-request-id`, `date` and `etag`. No `accessToken`/`refreshToken`/JWT and no `EMAIL_TAKEN` in either. |
| Existing email | An `account_exists` mail is sent in the **account** locale (`en`), although the request said `ar`. No code mail and no pending row are created. The notice is throttled: a second attempt within the hour sends no second notice. |
| One live pending per email | A second register for the same email → 202 and exactly 1 pending row. The old code → 422. The old username is released (`available: true`). The new code → 201 with the replacement username. A code is single-use (second use → 422). |
| Pending username shows as taken | `username-availability` returns `available: false`, and a register by someone else → **409 `USERNAME_TAKEN`**. |
| Verify success | 201 AuthResponse with `emailVerified: true`. DB: exactly 1 `users` row with `email_verified_at` set; pending row deleted. |
| Identical 422 | See note 1. |
| Malformed code (4 digits) | 400 `VALIDATION_FAILED`. |
| Concurrent verify race | 8 parallel verifies with the correct code → `201×1, 422×7`, and exactly 1 user row. |
| Email registered between register and verify | A pending registration exists; then another verified account's email is changed to that address in the DB. Verify → 422 with the identical body. The owner gets `account_exists`. Still exactly 1 user. |
| Unverified registrants cannot log in | See note 2. |
| Resend | 202 constant body. The new code differs; the old code → 422; the new code → 201. Resend for unknown, existing and pending emails returns byte-identical 202s. The resend mail uses `Accept-Language` (`ar`), while the created account keeps the pending locale (`en`). |
| Rate limits | Register per email: `202,202,202,429`. Resend per email: `202,202,202,429` with `Retry-After`. The verify-per-IP limit (10/15 min) is covered by A3 e2e `kl019` › "register/verify: 10 / 15 min per IP" (green). |
| Timing, real Argon2 | See note 3. |

**Note 1: identical 422.**
- Five failure kinds were compared:
  - wrong code;
  - unknown email;
  - registered email with no pending registration;
  - attempts exhausted (5 wrong, then the correct code);
  - expired (`expires_at` moved into the past).
- All five → **422 `TOKEN_INVALID`** with byte-identical bodies (requestId excluded).
- After the 5th failure the pending row is deleted.

**Note 2: unverified registrants cannot log in.**
- Login with the email → 401, byte-identical (minus requestId) to the 401 for an unknown identifier.
- Login with the username → 401 `AUTH_INVALID_CREDENTIALS`.

**Note 3: timing.**
- Requests are interleaved, sequential, on localhost. "Existing" means distinct verified accounts.
- **N=30:**
  - new: mean 45.4 ms, median 44.9 ms (p10 40.6 / p90 52.5, sd 4.8);
  - existing: mean 46.0 ms, median 46.5 ms (p10 41.5 / p90 52.0, sd 4.4);
  - Welch t = −0.50.
- **N=60:**
  - new: mean 46.6 ms, median 46.6 ms (sd 4.6);
  - existing: mean 47.2 ms, median 47.0 ms (sd 3.9);
  - Welch t = −0.77.
- **Judgement:** no measurable timing oracle. The differences (0.4–1.6 ms) are well inside noise and smaller than one standard deviation, and both groups pay one Argon2 hash. Mail is sent after the response.

### 9.3 Item 2: displayName (PP-21) — **PASS**, with two Low findings

**Server (black-box and the new e2e) — accepted (202):**
- Persian ZWNJ `علی‌رضا محمدی`
- Urdu `شاہد آفریدی`
- Kurdish Sorani `ژیان کەریم ڕەش`
- 👨‍👩‍👧
- flags 🇸🇦🇮🇶🇪🇬
- skin tones 👋🏽 / 👍🏿
- 🏳️‍🌈 (FE0F + ZWJ)
- emoji-only
- 50 graphemes
- 20 families (20 graphemes / 100 code points)
- 3 combining marks
- "Kab Sonia"
- "Badminton Supporter"
- edge U+FEFF (trimmed)

**Rejected:**

| Issue | Inputs |
| ----- | ------ |
| `too_long` | 51 graphemes; 101 code points |
| `invalid_format` | leading/trailing/double joiners; joiner next to a space; joiners only; 4 combining marks (zalgo); RLO spoof `Layla‮gnp.exe`; bidi isolate; inner ZWSP; inner U+FEFF; ★★; ©™; `...` |
| `reserved_term` | "TheKabso"; "KabsoFan"; "Kabso Fan"; "K а b s o" (Cyrillic а); "ＫＡＢＳＯ"; "k-a-b-s-o"; "الدعم الفني"; "كابسو"; "Official Layla"; "Admin" |

**Bypass probes rejected as `reserved_term`:**
- ZWNJ/ZWJ inside "Kabso";
- tatweel `كـابسو`;
- spaced `ك ا ب س و`;
- harakat;
- `Kâbso` / combining acute;
- `Kabs0`;
- Greek ο;
- 𝐊𝐚𝐛𝐬𝐨;
- `kabso_fan`;
- `k.a.b.s.o`;
- emoji separators;
- Cyrillic `аdmin`;
- `Moderator Sam`;
- `فريق الإدارة`;
- Persian kaf `کابسو`.

`Ⓚⓐⓑⓢⓞ` → `invalid_format`, because it is symbols only.

**Round-trip after verify (stored exactly):** ZWNJ name; family emoji; 🏳️‍🌈; `﻿  Layla  ﻿` → `Layla`; NFD `éclair` → NFC. `device.name` with ZWJ is still `invalid_format`.

**Mobile copy:** new A6 widget tests confirm each server issue on the displayName field shows the PHASE1_1 §2 copy, and the code screen is not opened:
- `reserved_term` → `displayNameReserved`;
- `invalid_format` → `displayNameInvalid`;
- `too_long` → `displayNameTooLong`.

This holds in ar and en (6 tests). A2's `display_name_test` also checks that no reserved term ships in the copy.

### 9.4 Item 3: language (PP-22) — **PASS**, with one defect (QA-011)

**Mobile, full `KabsoApp`, new A6 tests:**
- **First launch:** device `en-US` → English LTR login; `ar-EG` → Arabic RTL; `fr-FR` → Arabic RTL. Nothing is persisted. A saved `en` beats an `ar-EG` device.
- **Auth chip:** on an fr-FR device (Arabic UI) the chip shows "English". Tapping it switches the UI to English and LTR and persists `en`.
- **Register locale:** register sent `locale: "en"` (the language displayed) and opened the code screen.
- A2's tests cover the remaining switch states: field contents kept, errors re-rendered, disabled while submitting.

**Server `PATCH /me`:**
- `{locale:"ar"}` → 200 with the full `Me` (only `locale` changed) and `GET /me` reflects it.
- `fr`, missing, unknown field, `null` → 400. Unauthenticated → 401.
- Limit **exactly 30/hour/user**: the 31st PATCH → 429. Bad-body requests count too, because the limiter runs before validation.

**Email locale:**

| Mail | Language used |
| ---- | ------------- |
| Code mail | Body `locale` (`en` wins over `Accept-Language: ar`); with no body locale, `Accept-Language: en-US` → `en`; resend → `Accept-Language` |
| Account notice and password reset | The account's stored locale, even after `PATCH /me` and with a different `Accept-Language` |

**PATCH /me sync rules (client):** A2's `locale_test` covers them: explicit choice ≠ `me.locale` → PATCH; equal → none; no choice → adopt; failures retried after refresh; 400 drops the flag. A6 found one gap (QA-011).

### 9.5 Item 4: regression

**Black-box suite adapted to verify-first: 148/148 PASS.** Script `scratchpad/qa/adapt.py` makes these edits:

| # | Adaptation | Reason |
| - | ---------- | ------ |
| A1 | Test emails use a unique domain (`qa@d<id>.example.com`) | The dev mail log masks recipients (`qa***@domain`); a unique domain identifies each code. No semantic change. |
| A2 | `register()` = register (expects 202) → code from the mail log → `register/verify`, and returns the verify response | Under v1.2 an account and tokens exist only after verify. About 25 checks use `register()`: Me/TokenPair schema, `Content-Type`, displayName round-trips, email normalization, default locale, suspension, logout, reuse, sessions, JWT claims. They now exercise the verify 201. |
| A3 | "register 201" split into "register 202 constant body" + "register/verify 201" | Same coverage plus the new constant body. This is why 147 → 148. |
| A4 | Mixed-case email `  QA@D<id>.Example.COM  ` | A1 applied to the normalization check. |
| A5 | "duplicate email → 409 `EMAIL_TAKEN`" → "→ **202** constant body, no `EMAIL_TAKEN`" | Contract v1.2 (B9). |
| A6 | ZWJ displayName: was informational ("rejected in v1.1") → must be **201** and stored intact | Contract v1.2 (QA-008). |

**Acceptance criteria:** the KL-002 and KL-003 criteria remain covered by the green 197 API e2e, the 451 Flutter tests and the 148 black-box checks:
- envelopes and codes, `X-Request-Id`, body-level 400s;
- JWT attacks, refresh rotation and reuse (any of the last 10), logout/revoke/suspension;
- rate limits, Redis fail-closed;
- RTL, the shell, single-flight refresh, restore and logout.

### 9.6 Item 5: KL-015 copy alignment and the edits to A6's tests

**Copy:** `scratchpad/qa/final_copy.py` compares every PHASE1_1_SCREENS §5 "Final en / Final ar" cell with both ARB files: **53 keys, all verbatim**.
- The 7 flagged rows are not mismatches. Six are "as ARB" rows, which state no text. `profileTitle` was replaced by `@{username}` in the TopBar, as decided.
- No English string contains "Sign in/Sign out".
- Checklist #9 passes: no verify-email notice, verify banner or "Not verified" UI remains. Only the `emailVerified` DTO/entity field is left.

**Edits to A6 test files** (`git diff 414d7be ed84dd4 -- apps/*/test/qa`):

| Edit | Verdict | Reason |
| ---- | ------- | ------ |
| `kl006_qa_test.dart`: fresh-install test pins `deviceLocalesProvider = [fr-FR]` | **Confirmed** | D26 makes the device locale an input. Pinning a non-en/non-ar locale keeps the test's intent (Arabic fallback) and makes it independent of the CI host's locale. A6's new tests add the en-US / ar-EG cases end to end. |
| `kl006_qa_test.dart`: revoke dialog finder `sessionsRevoke` → `sessionsRevokeConfirm` ("End session") | **Confirmed** | PHASE1_1 §5.5 makes the destructive confirm name the object. The test still taps the dialog's confirm action and asserts the same outcomes. |
| `kl006_retest_test.dart`: verify-email-notice text-scale case → registration code screen | **Confirmed** | See note 1. |
| `kl006-contract.e2e-spec.ts`: `register()` helper → `registerVerified` (register 202 → code → verify) | **Confirmed** | See note 2. |
| `kl006-contract.e2e-spec.ts`: rate-limit test expects 202, 202, 429, then verifies the first registration | **Confirmed** | See note 3. |

**Note 1: code screen replacing the verify-notice case.**
- The notice is retired (PHASE1_1 §0), and the code screen is its replacement in the flow, so the 2.0-scale coverage moves to the right screen.
- The test seeds a `RegistrationDraft` and navigates to `AppRoutes.registerCode`. That is the same state a 202 creates; A2's `register_code_test` covers the 202 → code-screen path itself.

**Note 2: `registerVerified` helper.**
- I reviewed `registerVerified` in `test/helpers/test-app.ts`.
- It fails loudly if register is not 202, reads the code from the capturing mail double, and posts verify with the same device.
- It doesn't weaken any assertion, because each test still asserts `201` and the response shape.

**Note 3: rate-limit test.** It still proves the register per-IP limit (3rd → 429) and obtains tokens legitimately for the refresh/resend/login limits that follow.

### 9.7 Item 6: P0 live components and goldens (debug-only)

**Wiring:** the live widgets (`features/live/presentation/widgets/*`) are imported only by `features/debug/component_gallery_screen.dart` and by tests. `HomeScreen` and `LiveScreen` are still `ComingSoonTab` empty states; the copy is verbatim spec (§8.2).

**`/debug/components` in release:**
- The route is registered only inside `if (!kReleaseMode)`, which is a compile-time constant, so it is tree-shaken.
- The Settings entry is behind the same guard.
- The screen asserts `!kReleaseMode`.
- Signed-out users are redirected to login in any build.
- **Release binary: NOT VERIFIED.** No Android SDK, and no web/linux target, so no release build could be produced here.

**Golden review.** I viewed room_viewer, room_pk, room_gifts, cover_cards (ar/en, phone/android), pk_bar, chat_overlay, tabs, badges and avatar_rings.

| Area | Result |
| ---- | ------ |
| RTL/LTR | Correct. Host pill, close, count and Follow mirror. Send ▶ points to the end in RTL. The PK host side (red) is at the start in both directions, and win/lose/draw labels match the scores. LTR chat messages inside the RTL list keep their own direction ("Can you play it again?"). |
| Digits | Latin in Arabic: `12.3 ألف`, `1.2 مليون`, `0:09`. |
| Disabled state | The gift Send is disabled with an honest "sending gifts is coming soon" note. |
| Contrast | PK white scores 3.45:1 on `pkLeft` and 3.32:1 on `pkRight`; that is ≥ 3:1 for large text (≥ 20 sp bold), and `contrast_test.dart` enforces it. Chat scrim text ≥ 5.74:1 (token note). |
| Clipping | See **QA-009** below. Long titles and names on cover cards ellipsize correctly. |

### 9.8 New findings

**QA-009 (Low, A2; must be fixed before the components are wired, Phase 6).**
- **Where:** `room_viewer`/`room_pk`/`room_gifts` `.{en,ar}.android.png` goldens (360 dp).
- **Problem:** the host pill truncates "Sara"/"سارة" to `S…`/`س…`. On the 393 dp phone goldens the full name shows. Any real host name is unreadable on a 360 dp phone.
- **Repro:** `test/goldens/png/room_viewer.en.android.png`, top start.
- **Expected:** at least ~8 characters of the host name visible at 360 dp; the Follow chip or facepile should yield first.

**QA-010 (Low, A3 or contract clarification).**
- **Problem:** a whitespace-only `displayName` returns `too_short` instead of the `invalid_format` named in CONVENTIONS §6 ("names consisting only of whitespace…") and PHASE1_1 §2 (`required` / `invalid_format`).
- **Repro:** `POST /auth/register` with `displayName: "   "` → `{"field":"displayName","issue":"too_short"}`.
- **Impact:** the app maps server `too_short` to `displayNameInvalid` ("has characters that can't be used"), which is misleading copy. It is rarely reached, because the client blocks whitespace-only names first with `validationRequired`.
- **Fix:** align the server issue or the contract text.

**QA-011 (Medium, A2): a language change during an in-flight `PATCH /me` is lost.**
- **Where:** `LocaleSync._push` returns early while `_pushing` is true, without setting the `localeSyncPending` flag.
- **Result:** after en → ar quickly, the UI shows Arabic but the account stays `en`. Password-reset and notice emails go out in the wrong language until the next sign-in, and there is no retry.
- **Repro:** `test/qa/kl006c_v12_test.dart` › "a second language change during an in-flight PATCH is not lost". Run with `flutter test --dart-define=QA_SKIP_011=false test/qa/kl006c_v12_test.dart`.
- **Expected vs actual:** server `ar`, or a pending sync; actual `server=en updates=[en] pending=false`.
- Committed skipped per D16. A2 should remove the skip with the fix, e.g. re-push when the displayed language differs from the pushed one, or set the pending flag.

**QA-012 (Low, CTO/A7, term-list configuration): reserved-list false positive.**
- `"مشرف علي"` → `reserved_term`, although مشرف (Musharraf) is a common given name; `"Musharraf Ali"` passes. `"Staff Sergeant"` is also rejected.
- This is contract-conformant: whole-word match on a configured term.
- **Suggestion:** reconsider `مشرف` and `staff` as whole-word terms, or allow them with a following word.
- Informational only: `كابسۆ` (Kurdish ۆ) is not folded by the confusable skeleton and passes. That is a distinct letter, so it is acceptable.

**Process note (A6).** While moving my files into `scratchpad/qa/` (D30), a `mv *.log` in the shared scratchpad root briefly moved 8 log files belonging to other agents. They were moved back unmodified within the same minute:
- `api-defaults.log`, `api-generous.log`, `api-noredis.log`, `api.log`;
- `boot.log`, `dev.log`, `down.log`, `install.log`.

No file was edited or deleted.

### 9.9 Open items / not verified

- **Release build:** absence of `/debug/components` in a release build, Android/iOS device runs, real Keychain/Keystore, screen readers. No SDKs here.
- **KL-012-D1:** the Android APK compile in CI, as before.
- **PP-05 / B11:** the account-bucket 429 oracle remains, as the contract accepts it, until a CAPTCHA is in place.

### 9.10 Recommendation (KL-006c)

**Approve contract v1.2 / v1.2.1 / v1.2.2 for integration.**
- PP-02 (verify-first: indistinguishable responses, identical failures, no timing oracle) is **verified** by A6.
- PP-21 is verified except for the Low copy/term findings QA-010 and QA-012.
- PP-22 is verified except for **QA-011**, which A2 should fix before PP-22 is ticked.
- QA-009 must be fixed before the live components are wired into production screens.
- No Blocker or High defects.
