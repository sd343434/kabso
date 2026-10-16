# KL-039 — Live discovery vertical slice: QA report (A6)

| | |
| --- | --- |
| Commit under test | `5102ce3` (branch `claude/amazing-tesla-5aj3um`; KL-037 API + KL-038 Flutter integrated) |
| Contract | v1.3: `docs/contracts/openapi.yaml`, `CONVENTIONS.md` §4, §5, §7, §10, `DB_PHASE2_DISCOVERY.md` |
| Decisions checked | D35–D42, `HOME_LIVE_LAYOUT_DECISIONS.md` (Owner decisions, HL-H2–HL-H6) |
| Date | 2026-10-16 |
| **Verdict** | **APPROVE WITH CONDITIONS.** No functional defect found in the slice. There are 3 low findings and 2 info notes. Conditions: QA-001 and QA-002 go into the next contract patch (wording or behaviour); QA-003 is tracked for the KL-035a design review. None blocks the slice |

## 1. What was run

Everything below was actually executed. The counts are the real outputs.

### 1.1 API black box (HTTP against a running API)

**Setup**
- **Build:** the API was built from `5102ce3` (`pnpm build`) and run as `node dist/main.js` on port 3101.
- **Database and Redis:** PostgreSQL 16 database `kabso_kl013_dev`, emptied and then migrated with `prisma migrate deploy` as the **migration role**. The API connected as the DML-only **runtime role**. Redis used DB 1. No superuser role was created or used.
- **Accounts:** 31 real accounts were registered through the verify-first flow (`POST /auth/register` → the 8-digit code from the dev `log` mail transport → `POST /auth/register/verify`). One extra registration was left pending on purpose. Registration limits were raised by environment variable for the setup only.
- **Contract checks on every response:**
  - the status code is documented for the operation;
  - the body validates against the openapi schema (Ajv 2020 with formats);
  - no undeclared property appears at any depth;
  - no email or `"email"` key appears anywhere;
  - `error.requestId` equals `X-Request-Id`.
- **Fixtures written by SQL** (as the schema owner, i.e. what an ops script would do, because v1.3 has no endpoint for these):
  - categories (none are seeded, D37);
  - `is_private`;
  - `users.status` SUSPENDED (this bypasses `AccountLifecycleService`, so it tests the ACTIVE-filter safety net);
  - `email_verified_at = NULL` (legacy unverified account);
  - `viewer_count`.

| Phase | API config | Checks | Result |
| ----- | ---------- | -----: | ------ |
| 1 Hosting disabled: 401 on all 10 operations (no token and a bad token); config; categories empty by default (ar, en, no header); empty lists; all list query validation; 503 without `Retry-After` before body validation; heartbeat 503; end/get 404 parity; profile self/other/404 parity (10 malformed, unknown, reserved and pending-only names); follow idempotency, 4 parallel follows, counts, self-follow 400, 404 parity, private target | `LIVE_HOSTING_ENABLED=false`, defaults | 428 | 427 ✅, 1 ❌ (QA-001) |
| 2 Hosting enabled, sweeper off: categories (sortOrder/slug order, inactive hidden, `Accept-Language` `ar-EG`/`en`/`fr` → stored locale → `ar`); 16 go-live body validations (title hygiene, `mode` → `unknown_field`, unknown/inactive/malformed `categorySlug`, malformed JSON `field ""`); **journey A live → B popular/new/following, C not following → absent**; category filter on every tab; profile `liveRoomId`; second go-live 409; 5 parallel go-lives → one 201 and four 409; non-host heartbeat/end 404; heartbeats keep the room alive past the stale window; A ends → gone from all tabs, end idempotent (same `endedAt`), heartbeat 409 `LIVE_ROOM_ENDED`; **stale handling through each read path** (list, GET room, profile, go-live replacement) → `ENDED/HEARTBEAT_TIMEOUT` with `endedAt = lastHeartbeatAt`, audited once; suspended host hidden/404 and token 401 | `true`, interval 5 s, stale 10 s, sweep 0 | 204 | all ✅ |
| 3a Sweeper: a stale room is ended with no read requests at all; audited once | `true`, 5/10 s, sweep 2 s | 3 | all ✅ |
| 3b Hosting switched off with a LIVE room (API restart): config false; heartbeat 503 (no `Retry-After`); end still 200 `HOST_ENDED`; list empty within the stale window | `false`, 5/10 s, sweep 2 s | 10 | all ✅ |
| 4 Pagination: 23 live rooms, 17 followed by B, 12 in `music`. Every tab × {no category, `music`} × limit {1, 5, 10, 20, 50}: exact set and order, no duplicates, `nextCursor = null` ⇔ `!hasMore`, full pages while `hasMore`. Cursors: bound to tab, category and caller (`following`); a public-tab cursor works for another caller and with another limit; tampered payload, tampered tag, non-canonical tag, forged payload with original tag, missing tag, 3 parts, padding, non-url base64 → all 400 `cursor/invalid_value`. Drift: rooms ended mid-walk → no duplicates, nothing skipped. Popular ≡ New while viewers = 0 | `true`, defaults (15/45 s) | 665 | all ✅ |
| 5h Rate limits (lowered by env): list, profile (also on the 404 path), follow+unfollow shared bucket (no-ops count; per user), go-live hour bucket (409 counts), heartbeat per minute, end; 429 `RATE_LIMITED` with `Retry-After`; list 429 before query validation; the list bucket replaces the default bucket; config/categories/GET room share the default bucket; follow rejections are logged (bucket and user id, no email) | `true`, `RATE_LIMIT_*` lowered | 55 | all ✅ |
| 5d Go-live day bucket counted **before** the hosting check: `[503, 503, 429]` | `false`, day = 2 | 1 | ✅ |
| 6 Legacy unverified host → 403 `AUTH_FORBIDDEN`; body validated before the verified check | `true` | 7 | all ✅ |
| 7 Popular with non-zero viewer counts (SQL fixture, including ties): exact order with limits 1, 3 and 5; New ignores viewers; drift (a seen room loses viewers) → pages stay 200, the room reappears once (the client dedupes, HL-H5) | `true` | 20 | all ✅ |
| **Total** | | **1,393** | **1,392 ✅, 1 ❌** |

Also checked:
- Server logs: registration-code mails mask the address (`qa***@…`).
- Logs: no unmasked email in any phase.
- API unit tests (`pnpm test`): **436/436** passed.

### 1.2 Flutter

| Run | Result |
| --- | ------ |
| `flutter test` (full suite, `apps/mobile`) | **639/639 passed** |
| `flutter analyze` (repo files) | no issues |
| **Real app stack against the local API** (see below) | **5/5 scenarios passed** |

**How the real app was exercised.** A temporary test file was used and kept **outside the repo**. It needs a running API and is not deterministic in CI, so it was not committed.

The test runs **production code unchanged**:
- the real `LiveScreen` and `LiveRoomsController`;
- the real `LiveRepositoryImpl`, Dio stack, `AuthInterceptor` and `TokenManager`;
- the real `PublicProfileController` and `ProfileRepositoryImpl`.

Only three things are overridden:
- `appConfigProvider` points to `http://localhost:3101`;
- `secureTokenStoreProvider` is an in-memory store seeded with a refresh token from a real login;
- `liveScopeProvider` supplies the user id.

How the test ran:
- **Real sockets:** `HttpOverrides.global = null` lifts flutter_test's mock `HttpClient`.
- **Real I/O:** completed inside `tester.runAsync`.
- **Real token flow:** the first call goes out without an access token and gets 401. The interceptor then calls the real `POST /auth/refresh` and retries. The server log confirms this sequence.

Scenarios:
1. **Hosting off** → Popular shows the `feed.unavailable` state with 0 rooms, and no list call is made.
2. **Hosting on.** The API had 23 live rooms with heartbeats, categories chat/games/music, and B following 17 hosts.
   - **Popular:**
     - chips are `All` plus chat, games and music, in server order;
     - scrolling to the end loads both pages and gives exactly the API's order (23 rooms);
     - tapping the `music` chip gives 12 rooms in API order.
   - **Following:** 17 rooms; no chip row.
   - **New:** 23 rooms; no chip row.
   - **Refresh:** a host ends a room through the API; re-selecting the New tab refreshes and the room disappears.
3. **Arabic:** `Directionality` is RTL and the chips use the server-localized names `دردشة`, `ألعاب` and `موسيقى`.
4. **Controller with a real server-rejected cursor.** A thin decorator corrupts the cursor; the server answers a real 400.
   - The first rejection restarts the list from page 1 and shows no error.
   - A second consecutive rejection shows the footer error (`ServerFailure`, `VALIDATION_FAILED`, `field = cursor`).
   - Retry with a valid cursor recovers, with no duplicate ids.
5. **Profile controller against the real API.**
   - Follow, then unfollow, round trip: `followerCount` goes 0 → 1 → 0, with server values replacing the optimistic ones.
   - For the caller's own profile, `isSelf` is true and `canFollow` is false.

Test-environment note: scenario 4 first failed because the harness logged in the same account more than 10 times in 15 minutes, which is the login IP+account limit, so it got 429. It passed after the harness switched to another account. This is not a product issue.

**Code review of the wiring** (`lib/features/live/**`, `lib/features/profile/**`, `lib/app/shell/*`, `lib/core/network/*`):

- **Pagination and dedupe:**
  - cursor and limit 20 (§5);
  - prefetch when 2 viewports or less remain;
  - dedupe by id across pages (HL-H5);
  - a generation counter drops late responses after a category change or refresh;
  - `hasMore` requires a non-null cursor.
- **Refresh and resume:**
  - pull-to-refresh, tab re-select, and resume after more than 60 s all reload config, categories and page 1 (HL-H5);
  - background failures are silent (D41).
- **Hosting-disabled path:**
  - `GET /live/config` comes first; `false` gives the unavailable state per tab and no list calls;
  - pull-to-refresh on the unavailable state re-checks config (D41).
- **Category chips:**
  - Popular only (HL-H3);
  - `All` is not interactive when the server has no categories;
  - a deactivated selected category falls back to All;
  - other tabs never send `category`.
- **Error mapping:**
  - the envelope is parsed, including `details` and `Retry-After`;
  - `LIVE_HOSTING_UNAVAILABLE`, `LIVE_ROOM_ALREADY_ACTIVE` and `LIVE_ROOM_ENDED` are in `ErrorCode` and have ar/en messages (`failure_messages.dart`, ARB);
  - unknown codes use the generic fallback.
- **Models against the contract:**
  - all required and nullable fields match;
  - `mode` falls back to SOLO for unknown values;
  - `endReason` maps unknown values to `unknown`;
  - no email field on `PublicProfile` or `UserSummary`.
- **Production providers never emit fixture data:**
  - `liveRoomsProvider` uses only `LiveRepositoryImpl`;
  - `homeFeedProvider` returns `FeedUnavailable` for every tab;
  - no `lib/` file imports `test/fixtures`;
  - the component gallery (samples) is behind `if (!kReleaseMode)` in the router.
- **D39 (Home does not show the live-room grid):** confirmed. `HomeScreen` renders only `HomeFeedBody` (post tiles and per-tab unavailable states). `KLiveCoverCard` and `LiveHubBody` are used only by `LiveScreen` and the debug gallery.

### 1.3 Contract ⇄ implementation drift

**Checked mechanically on every response in §1.1** (status documented, schema valid, no extra fields):
- all 10 v1.3 operations;
- every documented status except 503 `SERVICE_UNAVAILABLE`, which needs Redis or the database to be down and was not run.

**Field-by-field review.** No drift in:
- `LiveRoomSummary` and `LiveRoom`: required and nullable fields; `mode`, `status` and `endReason` enums;
- `PublicProfile`, `FollowState`, `LiveConfig`, `LiveCategory` and `UserSummary`;
- the `PageInfo` invariant.

The server enforces the check orders of `startLiveRoom` (rate limit → hosting → body → verified email → category → 409), `heartbeat` (hosting first) and `end` (allowed while disabled). The one exception is QA-001.

**Known contract nit (D41), still open:** the heartbeat `503` references the generic `Error` response instead of naming `LIVE_HOSTING_UNAVAILABLE`.

## 2. Findings

| ID | Severity | Area | Title | Status |
| -- | -------- | ---- | ----- | ------ |
| QA-001 | Low | API / contract | Malformed JSON is rejected (400) before auth, rate limit and the hosting check | Open: contract wording or behaviour |
| QA-002 | Low | Contract ambiguity | Re-`PUT` follow by an existing follower of a private account → 403 vs "existing edge → 200" | Open: contract clarification |
| QA-003 | Low | Flutter / design | HL-H6 "Offline" state (offline banner + auto-retry on reconnect) not implemented | Open: track for KL-035a |
| QA-004 | Info | Flutter | Cards not tappable yet; the HL-L10 "Live ended" path is unreachable; the profile follow toggle is not wired to a screen | Expected (slice 2) |
| QA-005 | Info | API | Error `message` is English regardless of `Accept-Language` | By design (§4) |

### QA-001 — Malformed JSON is rejected before auth, rate limit and the hosting check (Low)

- **Repro:** `POST /api/v1/live/rooms` with `Content-Type: application/json` and body `{"title":`.
  - Tried with `LIVE_HOSTING_ENABLED=false` and a valid token.
  - Also tried with **no token**.
- **Expected:** openapi `startLiveRoom` gives the order auth → rate limit → `LIVE_HOSTING_ENABLED` → body.
  - With hosting disabled: 503 `LIVE_HOSTING_UNAVAILABLE`.
  - With no token: 401 `AUTH_UNAUTHENTICATED`.
- **Actual:** 400 `VALIDATION_FAILED` (`field ""`, `malformed_json`) in both cases.
  - The request is not counted against the go-live bucket.
  - A well-formed but invalid body behaves as documented (503 first).
- **Cause:** the HTTP body parser runs before guards. This is platform-wide behaviour from Phase 1, not specific to v1.3: the same 400 was observed without a token on `POST /auth/logout`.
- **Impact:** low. Nothing leaks: the 400 body is generic. Clients never send malformed JSON.
- **Suggestion:** either state in CONVENTIONS §4 that body-level parse errors (`field ""`) come before authentication on every route, or defer parse errors until after the guards. Owner: A4 (wording) or A3.

### QA-002 — Re-`PUT` follow on a private account by an existing follower (Low, ambiguity)

- **Repro:** B follows A. Set A `is_private = true` (no endpoint sets this in v1.3; SQL fixture). B sends `PUT /users/{A}/follow` again.
- **Actual:** 403 `AUTH_FORBIDDEN`. The edge is kept, and `DELETE` works (200).
- **Contract:** the two documents conflict.
  - Openapi `followUser` says both "Following someone already followed is a no-op that returns 200" and "Target with `isPrivate = true` → 403".
  - §10.6 says "existing edge → 200, with no error".
  - §10.5 restricts the 403 to **new** follows.
- **Impact:** none today (`is_private` cannot be set). The Flutter `canFollow` already offers only Unfollow in this case.
- **Suggestion:** decide which rule wins, then update the contract or the service. Owner: A4/A1.

### QA-003 — HL-H6 "Offline" state not implemented (Low)

- **Source:** `HOME_LIVE_LAYOUT_DECISIONS.md` HL-H6 specifies Offline as "`errorNetworkOffline` state + offline banner; auto-retry on reconnect".
- **Actual (code review only, not run):**
  - an offline failure maps to `NetworkFailure.offline` and shows the generic compact error state with the localized offline message and Try again;
  - there is no offline banner;
  - there is no connectivity listener (no connectivity package), so there is no automatic retry on reconnect;
  - resume after more than 60 s does refresh.
- **Suggestion:** implement it, or record a decision to defer it, at the KL-035a review. Owner: A2/A5.

### QA-004 — Room open, ended-card path and profile follow UI not wired (Info)

- `LiveScreen` passes no `onOpenRoom`, so cards are neither buttons nor announced as buttons. HL-H5's "tapping a stale card opens the room's Live ended state (HL-L10)" is therefore unreachable until the room screen exists (slice 2, KL-034 on hold).
- `PublicProfileController` has no screen yet (its doc comment says so). When it gets one, a follow made there should refresh the Following tab: `liveRoomsProvider(FeedTab.following)` is not invalidated today.
- Because there is no in-app follow UI, the "B follows A → Following tab shows it" journey was verified with an API follow plus the real app's Following tab (§1.2, scenario 2), not through a Follow button.

### QA-005 — Error messages are not localized (Info)

`error.message` is English whatever `Accept-Language` says (`Going live is not available.`, `Resource not found.`). This matches CONVENTIONS §4: clients localize by `code`, and the app has ar/en strings for all three new codes. `Accept-Language` correctly localizes category names (§10.1).

## 3. Not tested (and why)

| Item | Why |
| ---- | --- |
| `AccountLifecycleService.suspend` / `softDelete`: the `HOST_SUSPENDED` end and follow-row deletion on soft delete | No HTTP route in v1.3 (D42.5). Covered only by A3's e2e (`kl037-live-discovery.e2e-spec.ts`). I tested only the ACTIVE-host safety net, using an SQL status flip |
| 503 `SERVICE_UNAVAILABLE` (Redis or database down; rate limiter fails closed) | Shared Redis and PostgreSQL instances are in use by other agents; I did not stop them |
| Multi-instance sweeper and heartbeat clock skew | A single API process only |
| Load and cost of the per-request stale sweep | Out of scope; PP-32 (D42.4) |
| Real Android/iOS device or emulator, web build | No device or emulator here. The real-API flutter_test harness in §1.2 replaced it; no web platform was added |
| Go-live, heartbeat and end from the app | The mobile app has no host lifecycle UI in this slice (`LiveRepository` has read operations only) |
| Offline and reconnect in the app | Not run; see QA-003 (code review only) |
| New committed tests under `apps/api/test/qa/` | Not added. The e2e harness only runs against a `*_test` database, and the databases assigned for this run (`kabso_kl013_dev`) and the existing `_test` databases belong to other agents, so I could not show that such a spec passes. A3's KL-037 e2e already covers most of §1.1; the cross-user journey, drift and hosting-toggle checks here are candidates for a future QA spec |

## 4. Reproduction notes

The harness is a set of Node scripts using built-in `fetch` plus Ajv over `openapi.yaml`, together with the temporary Flutter test. Both live in the QA agent's scratchpad, not in the repo.

Phases that need short timings or low limits restart the API with env overrides, all within config limits:
- `LIVE_HEARTBEAT_INTERVAL_SECONDS=5`;
- `LIVE_HEARTBEAT_STALE_SECONDS=10` (the minimum, 2 × interval);
- `LIVE_SWEEP_INTERVAL_SECONDS` = 0 or 2;
- `RATE_LIMIT_*=n/window`.

No credentials or secrets are recorded here. Test accounts used a local-only throwaway password on a disposable local dev database.
