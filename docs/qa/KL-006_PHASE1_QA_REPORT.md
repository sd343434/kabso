# KL-006 — Independent QA verification of the Phase 1 candidate

| | |
| - | - |
| Agent | A6 (QA & Test) |
| Date | 2026-10-15 |
| Candidate tested | `b973d7b` (Merge KL-003), which contains KL-002 `f45b867`, KL-002-D1 `217cad6`, KL-004 and KL-005 |
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
