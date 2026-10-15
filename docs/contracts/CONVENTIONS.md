# Kabso Live — Shared API Conventions (authoritative contract)

Status: **v1.1 — frozen for Phase 1** (see §9 change log). Changes require a contract-change proposal recorded in
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
  `invalid_format`, `invalid_value`, `unknown_field`, `malformed_json`, `payload_too_large`.
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
  `refresh.invalid_secret`), so knowing a session id cannot force a logout.
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
- Email verification and password reset use single-use tokens (32 random bytes, SHA-256 stored,
  TTL 24 h / 1 h) delivered through the `MailSender` port. Password reset revokes all sessions.
- `POST /auth/password/forgot` always returns 202 regardless of whether the email exists.
- **Enumeration (accepted risk, Phase 1 only):** login, forgot-password and timing do not reveal
  account existence, but `POST /auth/register` returns `EMAIL_TAKEN`. Before any public launch
  registration must become verify-first (always 202 + email to the address), which depends on
  SMTP (blocker B2) — tracked as blocker B9.
- Free-text fields (`displayName`, `device.name`) reject C0/C1 control characters, bidi
  override/isolate characters (U+202A–U+202E, U+2066–U+2069) and zero-width characters
  (U+200B–U+200D, U+2060, U+FEFF) with `issue: "invalid_format"`.

## 7. Rate limits (Phase 1 defaults, Redis-backed, configurable)

| Endpoint | Limit |
| -------- | ----- |
| `POST /auth/login` | 10 / 15 min per IP+account, 50 / 15 min per IP, **20 / 15 min per account across all IPs** (email and username of one account share the bucket; unknown identifiers are bucketed by normalized identifier) |
| `POST /auth/register` | 5 / hour per IP |
| `POST /auth/password/forgot` | 3 / hour per email, 10 / hour per IP |
| `POST /auth/refresh` | 60 / 15 min per session |
| `POST /auth/email/resend` | 5 / hour per user |
| Other public routes (`email/verify`, `password/reset`, `users/username-availability`) | 300 / 15 min per IP |
| Everything else (authenticated) | 600 / 15 min per user |

IP-based buckets group IPv6 clients by their /64 prefix. Rate-limit keys are HMAC-SHA-256 of
the subject under a server-side key (no raw or plainly hashed emails/IPs in Redis). The client IP
is derived only via an explicit trusted-proxy hop count or CIDR list; `trust proxy = true` is
refused in production.

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

**Intentionally deferred lint warnings** (`@redocly/cli@2.57.0`, config `redocly.yaml`):
`operation-4xx-response` on `/health/live` and `/health/ready` — these probes accept no input and
cannot produce a 4xx; adding a fictitious 4xx would make the contract less accurate.
