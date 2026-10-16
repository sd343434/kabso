# KL-040 — Security review of the contract v1.3 endpoints

| | |
| - | - |
| Reviewer | A7 (security engineer) |
| Date | 2026-10-16 |
| Subject | Contract v1.3 (live discovery, host lifecycle, public profile, follow) as integrated at commit `5102ce3` (KL-037) |
| Environment | Local PostgreSQL 16 with the migration and DML-only runtime roles, Redis 7, Node 22. A dedicated, freshly migrated `*_test` database and its own Redis index; API built from `5102ce3` and probed over HTTP. No superuser role was created or used |
| **Verdict** | **PASS WITH CONDITIONS** (see §5) |

The repository is public (D40). Open findings are listed with id, severity, a one-line
description and status only. Reproduction details went to the coordinator.

## 1. Scope

- Contract: `docs/contracts/openapi.yaml` v1.3.0, `CONVENTIONS.md` §4–§10,
  `DB_PHASE2_DISCOVERY.md`, board decisions D35–D42, `docs/SECURITY_MODEL.md`.
- API: `modules/live/**`, `modules/social/**`, `modules/users/profiles/**`,
  `modules/users/users.service.ts`, `common/rate-limit/**`, `common/http/content-language.ts`,
  `config/env.schema.ts`, `config/app-config.ts`, migration `20261016123000_live_discovery`.
- Mobile: `apps/mobile/lib/features/live/**` (untrusted strings, cursor handling, errors).

Out of scope: media/streaming (B1), the admin API (none exists), and endpoints older than v1.3,
except where v1.3 newly exposes their data (display names on live cards and profiles).

## 2. What was run, and the results

A7 ran everything below against the running API. "Pass" means the result was observed.

### 2.1 Project suites (independent re-run)

| Run | Result |
| --- | ------ |
| `prisma migrate deploy` as the migration role on an emptied database | pass |
| e2e `test/security/kl013-db-roles.e2e-spec.ts` + `test/kl037-live-discovery.e2e-spec.ts` (87 tests) | pass |
| Unit tests for live, rate-limit, http, config and users (338 tests) | pass |

### 2.2 Authorization and IDOR

| Check | Result |
| ----- | ------ |
| Heartbeat and end on another user's room, on a missing id, on a malformed id, on an upper-case id: identical 404 body, room unaffected | pass |
| Host heartbeat on an ended room → 409 `LIVE_ROOM_ENDED`; non-host on the same room → 404 | pass |
| Ending is idempotent; the original `endReason`/`endedAt` are kept | pass |
| Every v1.3 route without a token → 401 | pass |
| Following tab contains only hosts the caller follows; another user's following tab is not reachable (cursor is bound to the caller) | pass |
| `isFollowing` reflects only the caller's own edge | pass |
| Suspended / deleted host: room hidden from all tabs, room detail 404, host token refused (401) | pass |
| `LIVE_HOSTING_ENABLED=false`: go-live → 503 before body validation; heartbeat → 503 for host and non-host alike (no ownership signal); end still allowed for the host, 404 for others; config reports `hostingEnabled: false` | pass |

### 2.3 Enumeration

| Check | Result |
| ----- | ------ |
| Profile and follow: unknown, malformed, pending-only, suspended and deleted usernames return the same 404 body | pass |
| Profile response time: unknown, suspended, deleted, pending and malformed medians within ~0.7 ms of each other (interleaved, 30 rounds) | pass |
| Profiles never contain email, role, status, locale, created-at or settings; no email in any v1.3 response | pass |
| Private profile stays visible; new follow → 403; unfollow allowed; room stays listed | pass |

### 2.4 Abuse and rate limits

| Bucket | Observed first 429 | Result |
| ------ | ------------------ | ------ |
| Follow/unfollow churn, shared bucket (60/h); no-op, 404 and self calls count too | call 61; DELETE refused once PUT exhausted the bucket | pass |
| Heartbeat (12/60 s), own room and other's room | call 13 | pass |
| Go-live (10/h), valid and invalid bodies | call 11 | pass |
| End (30/h) | call 31 | pass |
| List (300/15 min) | call 301 | pass |
| Profile (300/15 min), mixed existing / unknown | call 301 | pass |
| Routes without a specific bucket (room detail, config, categories) still count against the per-user default (600/15 min); `replacesDefault` buckets are independent of it | call 601 | pass |
| Buckets keyed by HMAC of the user id; follow rejections are logged with bucket and user id only | code + log review | pass |

### 2.5 Input handling

| Check | Result |
| ----- | ------ |
| Title: bidi overrides/isolates, LRM/RLM/ALM, ZWSP, WJ, inner BOM, misplaced ZWJ, > 3 combining marks, C0/C1 controls (incl. NUL, tab, newline), punctuation-only, whitespace-only, 81 graphemes, 1001 chars → 400 with the documented issue | pass |
| Body: 1 MB payload → 400 `payload_too_large`; `mode`, unknown fields and `__proto__` → `unknown_field`; wrong types, null/array/missing body, malformed JSON, form/text content types → 400 | pass |
| Category slug: SQL metacharacters, upper case, too long, NUL → 400; unknown/inactive → empty 200 (list) or 400 `invalid_value` (go-live) | pass |
| Query params: unknown fields, repeated params (arrays), bracket/object syntax, prototype-pollution keys, out-of-range/hex/float/negative/huge `limit` → 400; never 500 | pass |
| `Accept-Language`: case, quality values, wildcards, empty entries, 8 KB values, non-ASCII → `ar`/`en` or stored locale; never an error | pass |
| Room id path: malformed ids → 404 (no uuid-cast 500) | pass |
| All raw SQL is tagged-template `$queryRaw`/`$executeRaw` with bound parameters; no `*Unsafe` or `Prisma.raw` use | code review | pass |

### 2.6 Cursor

| Check | Result |
| ----- | ------ |
| Replay in the same scope works; public-tab cursors are user-independent by design | pass |
| Cross-tab, cross-category and cross-user (`following`) replay → 400 `cursor` | pass |
| Tampered payload, altered/short/empty tag, missing or extra `.`, padding, > 512 chars, empty, repeated → 400 | pass |
| A cursor signed with the raw `RATE_LIMIT_KEY_SECRET` (no HKDF) is rejected: key separation holds | pass |
| Validly signed payloads with unknown version, extra fields, negative or fractional values, upper-case id → rejected | pass |
| Construction: HKDF-SHA-256 (info `live-cursor/v1`) → HMAC-SHA-256 with a domain prefix, truncated to 128 bits, constant-time compare on the canonical base64url text | code review | pass |
| Cursors are not logged (request logs carry the path only) | pass |

### 2.7 Configuration

| Check | Result |
| ----- | ------ |
| `LIVE_HOSTING_ENABLED` accepts only exactly `true`/`false` (`TRUE`, `1`, `yes`, `on`, empty and padded values refuse to boot); unset → off | pass |
| Heartbeat interval 5–60, stale ≤ 3600 and ≥ 2 × interval, sweep ≥ 0 | pass |
| Production: weak `LIVE_CURSOR_KEY`, or one equal to JWT / rate-limit / registration secrets, refused; sweeper cannot be disabled | pass |

### 2.8 Concurrency

| Check | Result |
| ----- | ------ |
| 10 parallel go-lives by one host → exactly one 201, nine 409, one LIVE row, one start audit | pass |
| Parallel heartbeats and ends → one end audit, final state ENDED/HOST_ENDED | pass |
| 36 concurrent follow/unfollow from 6 users: all 200, `followerCount` equals the rows; 8 parallel PUTs of one edge → one row | pass |
| Follow while the target row is being deactivated in another transaction: the follow waits on the row lock, then 404, no edge written | pass |

### 2.9 Privacy, audit and database role

| Check | Result |
| ----- | ------ |
| `live.room.start` / `live.room.end` audited with actor, IP and request id; `live.room.timeout` with host id and reason; heartbeats not audited | pass |
| Logs: no access tokens, no cursors, emails masked | pass |
| Runtime role on `live_rooms`, `live_categories`, `follows`: DML only; TRUNCATE, ALTER, DROP, index/constraint changes and CREATE refused; tables owned by the migration role; `audit_logs` stays append-only | pass |

### 2.10 Mobile client

Room ids are percent-encoded as path segments; cursors go through Dio query encoding; a
rejected cursor restarts once from the first page; titles and names render on one line with
ellipsis; cards are deduplicated by id. No logging of cursors or tokens in the network layer.

## 3. Open findings

| Id | Severity | Description | Status |
| -- | -------- | ----------- | ------ |
| SEC-035 | Medium | The stale-room sweep (per-request in `GET /live/rooms` and the background sweeper) ends every stale room in one unbounded transaction. A large backlog makes it exceed the transaction timeout and roll back every time, so the list fails persistently and the sweeper never catches up | Open |
| SEC-036 | Medium | Title and displayName hygiene uses a fixed blocklist, so other invisible or format code points pass (a title or display name can be entirely invisible, or carry line separators or hidden tag text). Display names now appear on live cards and public profiles | Open (contract patch needed, A4) |
| SEC-037 | Low | Some malformed usernames on `GET /users/{username}` and the follow routes return 500 instead of the contract's 404 | Open |
| SEC-038 | Info | The cursor payload schema accepts sort keys outside the database's range; only reachable with the signing key (defence in depth) | Open |

## 4. Observations (no finding id; hardening or follow-up)

- The runtime role can write `live_categories`, which the API only reads (inherited default
  privileges). Acceptable until admin category management lands; consider SELECT-only.
- The heartbeat rate limit is not cross-checked against `LIVE_HEARTBEAT_INTERVAL_SECONDS`; at a
  5 s interval the default 12/min leaves no headroom for retries.
- Numeric environment values are coerced leniently (exponent, hex, padded); cosmetic.
- A PUT by an existing follower on a private account answers 403 rather than an idempotent 200
  (contract-literal; client should not offer it).
- `startRoom` does not re-check the account status inside its transaction; a suspension racing a
  go-live can leave a hidden LIVE room that later ends as HEARTBEAT_TIMEOUT instead of
  HOST_SUSPENDED. The ACTIVE-host filter keeps it hidden. Code review only, not reproduced.
- Status changes made directly in the database bypass `AccountLifecycleService` (D42 item 5);
  the ops procedure must use the service.
- Mobile renders `avatarUrl`/`coverUrl` as network images without a scheme/host allowlist.
  Unreachable in v1.3 (no upload, cover always null); must be addressed with uploads.
- The sweep-failure log line carries no error class or code, which slows diagnosis.

## 5. Conditions

1. **SEC-035** fixed (bounded batches, no unbounded work on the request path, sweeps that do not
   overlap) and covered by the PP-32 load test **before `LIVE_HOSTING_ENABLED=true` in
   production**. While hosting is off in production (the default), no room can become stale.
2. **SEC-036**: contract patch (A4) moving title/displayName hygiene to an allowlist or to the
   Unicode default-ignorable and format classes, then implementation, before go-live of public
   discovery with real users.
3. **SEC-037** and **SEC-038** fixed in the next API patch.

## 6. Not tested

- A reliable timing comparison of heartbeat on an existing vs a missing room id: the 12/min
  bucket limits samples. Status and body are identical, and room ids are public via the lists.
- `AccountLifecycleService.suspend/softDelete` through HTTP: no route exists in v1.3. Covered by
  the KL-037 e2e suite (re-run, pass) and by the database-level lock probe in §2.8.
- Multi-instance behaviour (several API processes sweeping at once) and production-sized
  hardware; the SEC-035 threshold depends on both.
