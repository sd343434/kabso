# Kabso Live — Shared API Conventions (authoritative contract)

Status: **v1.2 — approved 2026-10-15; in implementation (KL-016/017/018/019)**. Until those tasks
merge, the deployed API still behaves as v1.1 for the items marked *(v1.2)* below. See §9. Changes require a contract-change proposal recorded in
`docs/AI_WORKFORCE_BOARD.md` (Decision Log), a compatibility note, and coordinated updates to
`apps/api` and `apps/mobile` in the same change set. No specialist may change this silently.

Machine-readable HTTP contract: [`openapi.yaml`](openapi.yaml). Design tokens:
[`design-tokens.json`](design-tokens.json). Real-time events (Phase 6+): `realtime-events.md`
(not yet defined).

## 1. Transport

- Base path: `/api/v1`. Health endpoints live outside the version prefix: `/health/live`,
  `/health/ready`.
- JSON only (`application/json; charset=utf-8`), UTF-8, camelCase property names.
- Every response carries an `X-Request-Id` header. If the client sends `X-Request-Id`
  (≤ 64 chars, `[A-Za-z0-9._-]`), the server reuses it; otherwise it generates a UUID.
- The client sends `Accept-Language: ar` or `en`. Server-generated user-facing text (emails)
  uses it; error `message` fields are English developer text — **clients localize by `code`**.
- Every `/api/v1` response carries `Cache-Control: no-store` (token-bearing and personal data
  must never be cached by intermediaries or the client HTTP cache).
- Clients identify themselves with `X-Client: kabso-mobile/<version> (<android|ios>)` (informational).

## 2. Identifiers and time

- IDs are UUIDv7 strings (time-ordered). Clients treat them as opaque strings.
- Timestamps are ISO-8601 UTC with milliseconds and `Z` suffix: `2026-10-15T13:00:00.000Z`.
- The server clock is authoritative for every expiry (tokens, stories, PK timers).

## 3. Money (applies from Phase 8; fixed now so nobody invents another format)

- Coins and all monetary amounts are **integers in minor units** (`int64`), serialized as JSON
  numbers when ≤ 2^53−1, never floats. Fiat amounts carry an ISO-4217 `currency` field.
- Every state-changing financial request requires an `Idempotency-Key` header (UUID).

## 4. Errors

All non-2xx responses use one envelope:

```json
{
  "error": {
    "code": "AUTH_INVALID_CREDENTIALS",
    "message": "Invalid email/username or password.",
    "details": [{ "field": "password", "issue": "too_short" }],
    "requestId": "0192f1c2-..."
  }
}
```

- `code` is a stable `UPPER_SNAKE_CASE` string; clients branch on it. `details` is optional;
  for validation errors it lists `{ field, issue }` where `field` is a dotted JSON path.
- Validation `issue` vocabulary (closed set; clients may branch on it): `required`,
  `invalid_type`, `too_short`, `too_long`, `too_small`, `too_big`, `invalid_email`,
  `invalid_format`, `invalid_value`, `unknown_field`, `malformed_json`, `payload_too_large`,
  *(v1.2)* `reserved_term`.
  Body-level problems (malformed JSON, body over the size limit, wrong content type) are reported
  as 400 `VALIDATION_FAILED` with `field: ""` — the API does not use 413/415.
- A suspended user's still-valid access token receives 401 `AUTH_UNAUTHENTICATED` on protected
  routes; `ACCOUNT_SUSPENDED` (403) is returned only by login and refresh.
- Never leak stack traces, SQL, or whether an email exists (see AUTH codes below).

| HTTP | code | Meaning |
| ---- | ---- | ------- |
| 400 | `VALIDATION_FAILED` | Body/query failed schema validation (`details` populated). |
| 401 | `AUTH_UNAUTHENTICATED` | Missing/invalid/expired access token. Client should refresh once. |
| 401 | `AUTH_INVALID_CREDENTIALS` | Login failed (same response for unknown user and wrong password). |
| 401 | `AUTH_REFRESH_INVALID` | Refresh token unknown, expired, revoked or reused. Client must sign out locally. |
| 403 | `AUTH_FORBIDDEN` | Authenticated but not allowed. |
| 403 | `ACCOUNT_SUSPENDED` | Account suspended; login and token refresh refused. |
| 404 | `NOT_FOUND` | Resource does not exist **or is not visible to the caller**. |
| 409 | `EMAIL_TAKEN` | Registration email already in use. |
| 409 | `USERNAME_TAKEN` | Username already in use. |
| 409 | `IDEMPOTENCY_CONFLICT` | Same Idempotency-Key reused with a different payload. |
| 410 | `TOKEN_EXPIRED` | Email-verification / password-reset token expired or already used. |
| 422 | `TOKEN_INVALID` | Email-verification / password-reset token malformed or unknown. |
| 429 | `RATE_LIMITED` | Too many requests; `Retry-After` header (seconds) is set. |
| 500 | `INTERNAL_ERROR` | Unexpected server error. |
| 503 | `SERVICE_UNAVAILABLE` | Dependency down (DB/Redis) or feature disabled by config. |

New codes are added by contract change only. The mobile app keeps a localized message for every
code above plus a generic fallback for unknown codes and network failures (`NETWORK_OFFLINE`,
`NETWORK_TIMEOUT` are **client-only** codes, never sent by the server).

## 5. Pagination

Cursor-based everywhere a list can grow. Request: `?cursor=<opaque>&limit=<1..50, default 20>`.

```json
{ "data": [ ... ], "page": { "nextCursor": "opaque-or-null", "hasMore": true } }
```

Cursors are opaque base64url strings; clients never parse or build them. Non-list responses
return the resource object directly (no `data` wrapper).

## 6. Authentication model

- **Access token**: JWT (HS256 in Phase 1; key from `JWT_ACCESS_SECRET`, ≥ 32 bytes), TTL
  15 min (`JWT_ACCESS_TTL_SECONDS`). Claims: `sub` (userId), `sid` (sessionId), `typ: "access"`,
  `iat`, `exp`, `iss: "kabso-api"`, `aud: "kabso-mobile"`. Sent as `Authorization: Bearer <jwt>`.
  The guard also verifies the session is not revoked and the user is `ACTIVE`, so logout,
  session revocation and suspension take effect immediately.
- **Refresh token**: opaque string `<sessionId>.<secret>` where `secret` is 32 random bytes
  base64url. The server stores only `SHA-256(secret)`. TTL 30 days sliding
  (`REFRESH_TTL_SECONDS`), absolute max 180 days. **Rotated on every refresh.** Presenting **the immediately previous** secret for a live session
  = reuse → the session is revoked (`revokedReason = REFRESH_REUSE`) and `AUTH_REFRESH_INVALID`
  is returned. Any other non-matching secret (guessed or garbage, e.g. built from the public `sid`)
  returns `AUTH_REFRESH_INVALID` **without** revoking the session (audited as
  `auth.refresh.invalid_secret`), so knowing a session id cannot force a logout.
  *(v1.2, SEC-022)* The server keeps the hashes of the last **10** rotated secrets per session;
  presenting **any** of them (not only the immediately previous one) is reuse and revokes the
  session. Only secrets that were never issued for the session get the non-revoking 401.
  Concurrent refreshes with the same secret: exactly one succeeds; a request that arrives *after*
  the winner committed presents the now-previous secret and therefore revokes the session. This
  fail-safe is intentional (a grace window would let a token thief keep the session); clients
  must keep refresh single-flight.
- Mobile stores the refresh token only in platform secure storage (Keychain/Keystore) and the
  access token in memory. The HTTP client runs a **single-flight** refresh: concurrent 401s wait
  for one refresh call, then retry once.
- Passwords: 8–128 chars (counted in Unicode code points after NFC normalization), normalized
  to **Unicode NFC** before hashing and before verification, hashed with Argon2id (server-side
  only). The server caps concurrent Argon2 operations per process; when saturated it returns
  503 `SERVICE_UNAVAILABLE` with `Retry-After`. Login accepts email or
  username as `identifier`.
- Usernames: `^[a-z0-9](?:[a-z0-9._]{1,28}[a-z0-9])?$` (3–30 chars, lowercase, no leading/
  trailing `.`/`_`), unique case-insensitively, stored lowercase. The regex alone admits a 1-character name; the 3–30 length bound is a separate, mandatory check (clients and server apply both). A reserved list (admin, kabso,
  support, api, live, …) is rejected with `USERNAME_TAKEN`.
- Emails are normalized (trim + lowercase) before uniqueness checks.
- Password reset uses single-use tokens (32 random bytes, SHA-256 stored, TTL 1 h) delivered
  through the `MailSender` port and revokes all sessions. `POST /auth/email/verify` and
  `/auth/email/resend` (single-use tokens, TTL 24 h) remain for **future email-address changes**;
  from v1.2 every account's email is verified at creation, so the mobile app does not call them.
- `POST /auth/password/forgot` always returns 202 regardless of whether the email exists.
- **Verify-first registration *(v1.2, owner decision B9 — email existence must never be revealed)*:**
  1. `POST /auth/register` validates the body, then **always** returns `202` with the constant body
     `{"status":"verification_pending"}` — identical whether or not the email is registered. It
     never returns tokens and never returns `EMAIL_TAKEN`. Possible errors: 400, 409
     `USERNAME_TAKEN` (usernames are public), 429, 503.
  2. The server always computes the Argon2id hash of the password before branching (equal cost),
     and sends mail after the response is written (equal latency).
  3. **Email not registered:** store a *pending registration* (normalized email, username,
     displayName, locale, password hash, device info, code hash, attempt counter, expiry
     **30 min**; *(v1.2.3, SEC-026)* absolute lifetime **2 h from creation** — resend issues a new
     code but never extends `expiresAt` past that cap, and code attempts are counted per pending
     registration across resends, max **10**). **At most one live pending registration per email:** a new register call for the
     same email replaces the previous one (new code; previous username reservation released), so
     a third party cannot block the address owner. Email the **8-digit numeric code** (CSPRNG,
     stored as HMAC-SHA-256) in the request locale.
  4. **Email already registered:** create nothing; email the account owner an "account already
     exists — log in or reset your password" notice in the **account's** locale
     (max 1 / hour / account).
  5. `POST /auth/register/verify` `{email, code, device?}` → `201 AuthResponse` (user + session):
     in **one transaction** it re-checks that no user has the email and creates User
     (`emailVerifiedAt = now`) + Profile + Settings + Session, then deletes the pending record.
     Every failure — unknown email, no live pending, wrong code, expired, attempts exhausted
     (**5** per pending, after which it is deleted), or the email registered meanwhile — returns
     the same `422 TOKEN_INVALID`. If the email was registered meanwhile, the owner also gets the
     notice from step 4. Unique constraints on `users.email` / `user_profiles.username` remain the
     final backstop (email conflict → `TOKEN_INVALID`, username conflict → `USERNAME_TAKEN`).
  6. `POST /auth/register/resend` `{email}` → always `202` (new code if a live pending exists,
     which invalidates the old code; otherwise nothing).
  7. **Usernames held by live pending registrations count as taken** for `register` and
     `users/username-availability` — *(v1.2.3, SEC-025)* for **every** register call, including one
     with the same email as the pending registration (identical 409 regardless of email, so the
     response never confirms the email). The address owner continues with `register/resend`
     or registers with a different username; reservations disappear when the pending expires or is
     replaced. No account exists before verification, so unverified accounts can never log in and
     duplicate accounts cannot arise.
  8. Expired pending registrations are deleted lazily on access and by a periodic cleanup job.
  Until v1.2 is implemented, `EMAIL_TAKEN` remains a known pre-production blocker (B9).
- Free-text fields (`displayName`, `device.name`, `device.appVersion`) reject C0/C1 control
  characters, bidi override/isolate characters (U+202A–U+202E, U+2066–U+2069), U+200B, U+2060
  and U+FEFF with `issue: "invalid_format"`. *(v1.2.3)* `displayName` also rejects the bidi marks
  LRM U+200E, RLM U+200F and ALM U+061C.
- **`displayName` *(v1.2, KL-017 / QA-008)*:** NFC-normalized, trimmed; **1–50 grapheme
  clusters and ≤ 100 Unicode code points**. ZWNJ (U+200C) and ZWJ (U+200D) are **allowed**
  (Persian/Urdu/Kurdish orthography, emoji sequences) but must sit between two non-joiner,
  non-space characters (not leading/trailing, never adjacent to another joiner or whitespace).
  `device.*` fields still reject all zero-width characters. Rejected with `invalid_format`: names
  consisting only of whitespace, joiners, combining marks or symbols; more than **3** consecutive
  combining marks ("zalgo", counted on the NFD form); the bans above. *(v1.2.1)* A name must
  contain at least one letter, digit **or emoji** grapheme (*(v1.2.2)* Unicode RGI emoji set, `\p{RGI_Emoji}` — not `Extended_Pictographic`, which also includes text symbols such as ★ © ™); emoji-only
  names are valid, punctuation/symbol-only names are not. U+FEFF at either end is removed by
  trimming before validation; inside the name it is rejected. Rejected with
  `issue: "reserved_term"`: *(v1.2.1)* names where, after NFKC casefold and confusable skeleton
  (Unicode TS #39 — *(v1.2.3, SEC-024)* confusable mapping applied both **before and after**
  case-folding, generated from a pinned, checksummed copy of Unicode `confusables.txt`; any single
  word mixing scripts (e.g. Latin + Cyrillic/Greek, excluding Common/Inherited) is rejected with
  `invalid_format`), *(v1.2.2)* (a) a reserved term equals a **whole word** (split on any
  non-letter/digit), or (b) *(v1.2.3)* **any single word contains** a brand term (`kabso`,
  `كابسو`; e.g. "TheKabso", "KabsoFan"), or (c) the whole name with separators removed **equals**
  a reserved term (catches spaced-out "K a b s o"). Names such as "Kab Sonia" are allowed. Substrings inside ordinary words (e.g. "Badminton", "Supporter") are allowed. Terms
  (`kabso`, `admin`, `administrator`, `support`, `official`, `moderator`, `كابسو`,
  `الدعم`, `رسمي`, `الإدارة`; list is server configuration; *(v1.2.4, QA-012)* `staff` and `مشرف` removed because they are common in real names — moderator impersonation is handled by moderation and verified badges). `reserved_term` is evaluated
  after schema validation; audit actions use the `auth.registration.*` prefix; the
  `register/resend` code mail uses `Accept-Language`, else the pending registration's locale.
- **Locale *(v1.2, KL-018)*:** `locale` is `ar` or `en`. The client sends the locale it is
  displaying in `register` (and `Accept-Language` on every request). `PATCH /api/v1/me`
  `{"locale": "ar"|"en"}` persists an explicit user choice. Transactional email language:
  verification code → request `locale`/`Accept-Language`; account notices, password reset,
  security emails → the account's stored `locale`; unknown email (no mail is sent) → n/a.

## 7. Rate limits (Phase 1 defaults, Redis-backed, configurable)

| Endpoint | Limit |
| -------- | ----- |
| `POST /auth/login` | 10 / 15 min per IP+account, 50 / 15 min per IP, **20 / 15 min per account across all IPs** (email and username of one account share the bucket; unknown identifiers are bucketed by normalized identifier). *(v1.2, SEC-023)* the account bucket counts **failed** attempts only, and a source (IPv4 / IPv6 /64) that logged into the account successfully within the last 30 days bypasses the account bucket (still subject to the IP+account bucket). |
| `POST /auth/register` | 5 / hour per IP; *(v1.2)* 3 / hour per email |
| `POST /auth/register/verify` *(v1.2)* | 10 / 15 min per IP; 5 attempts per code, *(v1.2.3)* 10 per pending registration and **15 / day per email** (SEC-027) |
| `POST /auth/register/resend` *(v1.2)* | 3 / hour per email, 10 / hour per IP |
| `PATCH /me` *(v1.2)* | 30 / hour per user |
| `POST /auth/password/forgot` | 3 / hour per email, 10 / hour per IP |
| `POST /auth/refresh` | 60 / 15 min per session |
| `POST /auth/email/resend` | 5 / hour per user |
| Other public routes (`email/verify`, `password/reset`, `users/username-availability`) | 300 / 15 min per IP |
| Everything else (authenticated) | 600 / 15 min per user |

IP-based buckets group IPv6 clients by their /64 prefix. Rate-limit keys are HMAC-SHA-256 of
the subject under a server-side key (no raw or plainly hashed emails/IPs in Redis). The client IP
is derived only via an explicit trusted-proxy hop count or CIDR list; `trust proxy = true` is
refused in production. *(v1.2, SEC-003a)* production also refuses `/0` CIDRs (`0.0.0.0/0`, `::/0`)
and hop counts greater than 3; *(v1.2.3)* also IPv4 prefixes shorter than /8, IPv6 prefixes shorter
than /32, and `::ffff:0:0/96`. Rate-limit counters that gate expensive work are incremented
**before** the check (atomic) and refunded on success, so concurrent requests cannot exceed the
limit.

*(v1.2, SEC-023 residual)* An exhausted account bucket still answers 429 while an unrelated
identifier answers 401, which can link an email to a public username. Accepted only for internal
builds; a CAPTCHA/step-up challenge replacing the 429 is required before public launch (B11).

Rate limiting fails **closed** (503 `SERVICE_UNAVAILABLE`) when Redis is unavailable.

## 8. Ownership of shared artifacts

| Artifact | Owner | Change approval |
| -------- | ----- | --------------- |
| `docs/contracts/*` | CTO | CTO + affected specialists |
| `apps/api/prisma/schema.prisma` + migrations | Backend | CTO; Security for auth/financial tables |
| `apps/api/**` | Backend | CTO review |
| `apps/mobile/lib/app/router/**` (route registry) | Flutter | CTO review |
| `apps/mobile/pubspec.yaml` | Flutter | CTO review |
| `apps/mobile/**` (other) | Flutter | CTO review |
| `docs/design/**` | Design | CTO review |
| `.github/**`, `infra/**`, `docker-compose.yml` | DevOps | CTO review |
| Root `package.json`, `pnpm-workspace.yaml` | Backend (Phase 1) | CTO review |

## 9. Contract change log

| Version | Date | Change | Compatibility |
| ------- | ---- | ------ | ------------- |
| v1.0 | 2026-10-15 | Initial Phase 1 contract. | — |
| v1.0.1 | 2026-10-15 | `openapi.yaml`: quoted the `forgotPassword` 202 description (invalid YAML flow mapping, found by A8). | Fix; no shape change. |
| v1.0.2 | 2026-10-15 | `openapi.yaml`: documented responses already guaranteed by §4/§7 but missing from operations — `400 VALIDATION_FAILED` on `refresh`, `verifyEmail`, `revokeSession`; `429 RATE_LIMITED` on `logout`, `verifyEmail`, `resetPassword`, `listSessions`, `revokeSession`, `getMe`. Added operation summaries and tag descriptions. | Additive documentation only; no request/response shape changed. |

| v1.0.3 | 2026-10-15 | Ratified KL-002 clarifications: validation `issue` vocabulary (§4); body-level errors use 400 not 413/415; suspended access token → 401; extra rate limits for `email/resend` and other public routes (§7); `revokeSession` malformed id → 404 (removes the 400 added in v1.0.2). | Clarification of existing behavior; no shape change. Client must send usernames already lowercased (pattern is enforced strictly, not normalized). |
| v1.0.4 | 2026-10-15 | Clarifications from KL-003 (A2): design-tokens 8-digit hex is `#AARRGGBB`; username length bound must be checked in addition to the regex. KNOWN_LIMITATIONS B7 corrected to the actual placeholder id `com.kabso.kabso_live`. | Documentation only; matches implemented behavior. |
| v1.1 | 2026-10-15 | Security review KL-007 decisions (D13): refresh revocation only for the previous secret (SEC-001) + documented concurrent-refresh fail-safe (SEC-004); NFC password normalization (SEC-016); Argon2 concurrency cap → 503 (SEC-002); per-account login limit, IPv6 /64 bucketing, HMAC rate-limit keys, no `trust proxy = true` in production (SEC-002/003/009/010); `Cache-Control: no-store` (SEC-006); control/bidi/zero-width characters rejected in free text (SEC-008); registration enumeration recorded as accepted Phase 1 risk with launch blocker B9 (SEC-018). | Behavioral tightening; no request/response shape change. Clients: unchanged except they may now see 503 on login/register under load (already a defined code). |
| v1.2 | 2026-10-15 | **Approved, in implementation.** Owner decisions: verify-first registration — `register` → 202 constant body, new `register/verify` (8-digit code) and `register/resend`, pending registrations with username reservation, `EMAIL_TAKEN` no longer returned by register (B9); displayName allows ZWNJ/ZWJ with placement rules, grapheme/code-point limits, zalgo and reserved-term (`reserved_term` issue) rules (KL-017/QA-008); `PATCH /me` locale + email-locale rules (KL-018); refresh reuse across last 10 rotated secrets (SEC-022); failed-only account bucket + recent-success bypass (SEC-023); `/0` CIDR and hop > 3 refused in production (SEC-003a). | **Breaking:** `POST /auth/register` 201 `AuthResponse` → 202; clients must add the code-entry step. Backend (A3) and mobile (A2) ship together in one integration; no released clients exist. |
| v1.2.1 | 2026-10-16 | Clarifications from KL-019/017 implementation: reserved terms match whole words (+ brand prefix/suffix), not substrings; emoji-only displayNames valid, punctuation-only invalid; zalgo counted on NFD; edge U+FEFF trimmed; `reserved_term` after schema validation; resend mail locale; audit prefix `auth.registration.*`. | Behavioral clarification; no shape change. |
| tokens v1.1 | 2026-10-16 | `design-tokens.json` v1.1: approved accessibility fixes KL-009 (P1 dark/P2 light `textTertiary`, P3/P4 `primaryText`, P5–P8 light status colors, P9 `borderStrong`, P11 `focusRing`, P14 `onStatus`) and KL-021 live-UI tokens (`color.live.chatScrim` #99000000, `size.liveCardAspect` 0.75, `size.giftGridColumns` 4, `motion.giftComboBumpMs` 120). | Additive except changed values of `textTertiary` and light status colors (contrast fixes); Flutter applies them in one change set (KL-009 + KL-022). |
| v1.2.2 | 2026-10-16 | displayName: emoji test uses the RGI emoji set (★ © ™ are not emoji); brand rule applies per word (prefix/suffix) plus whole-name equality, so "Kab Sonia" passes. Clients may pre-validate more permissively; the server is authoritative. | Clarification; no shape change. |
| v1.2.3 | 2026-10-16 | KL-007c fixes: confusables both sides of case-fold + vendored `confusables.txt` + mixed-script words rejected (SEC-024); pending-username 409 for every caller (SEC-025); pending lifetime cap 2 h, resend never extends, attempts across resends ≤ 10 (SEC-026); verify 15/day/email (SEC-027); atomic increment-before-check counters (SEC-023 race); stricter TRUST_PROXY prefixes (SEC-003a); brand terms match inside words; LRM/RLM/ALM rejected. Optional `REGISTRATION_CODE_KEY` (SEC-029). | Behavioral; no shape change. Mobile: a 409 on register for a username the user reserved earlier must offer "Resend code". |
| v1.2.4 | 2026-10-16 | Reserved list drops `staff` and `مشرف` (QA-012 false positives on real names); whitespace-only displayName is `invalid_format` (QA-010). | Behavioral; no shape change. |

**Intentionally deferred lint warnings** (`@redocly/cli@2.57.0`, config `redocly.yaml`):
`operation-4xx-response` on `/health/live` and `/health/ready` — these probes accept no input and
cannot produce a 4xx; adding a fictitious 4xx would make the contract less accurate.
