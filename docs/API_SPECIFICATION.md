# Kabso Live — API Specification (contract v1.2)

The machine-readable contract is [`contracts/openapi.yaml`](contracts/openapi.yaml); transport,
error, auth and rate-limit rules are in [`contracts/CONVENTIONS.md`](contracts/CONVENTIONS.md).
This page records **how the implementation (`apps/api`) authorizes and limits each endpoint**.

## Global behaviour

- Every route requires `Authorization: Bearer <access JWT>` (scheme matched
  case-insensitively, RFC 7235) unless marked **public** below.
  The guard verifies the JWT (HS256 only, `iss=kabso-api`, `aud=kabso-mobile`, `typ=access`,
  not expired) **and** loads the session: it must belong to `sub`, not be revoked, not be expired,
  and the user must be `ACTIVE`. Otherwise → 401 `AUTH_UNAUTHENTICATED`.
- Bodies are strict: unknown fields → 400 `VALIDATION_FAILED` with `issue: "unknown_field"`.
  Malformed JSON / oversize bodies (> `BODY_LIMIT`, default 100 kB) → 400 `VALIDATION_FAILED`.
- Validation `issue` values: `required`, `invalid_type`, `too_short`, `too_long`, `too_small`,
  `too_big`, `invalid_email`, `invalid_format`, `invalid_value`, `unknown_field`,
  `malformed_json`, `payload_too_large`, `reserved_term` (v1.2).
- Every response carries `Cache-Control: no-store` (CONVENTIONS §1).
- Free text: `device.name` / `device.appVersion` reject C0/C1 controls, bidi override/isolate
  and **all** zero-width characters with `invalid_format`.
- `displayName` (v1.2, KL-017): NFC + trim; 1–50 grapheme clusters (`Intl.Segmenter`) and
  ≤ 100 code points (`too_short` / `too_long`; empty → `too_short`, whitespace-only →
  `invalid_format`, v1.2.4 QA-010). `invalid_format` for C0/C1, bidi controls (incl. LRM U+200E,
  RLM U+200F, ALM U+061C, v1.2.3), U+200B, U+2060, U+FEFF; a single word mixing scripts
  (Unicode `Script_Extensions`; Common/Inherited ignored, e.g. Latin+Greek/Cyrillic, v1.2.3
  SEC-024 — "Sara سارة" is two words and passes); ZWNJ/ZWJ not between two non-joiner, non-space characters; > 3 consecutive
  combining marks (counted on the NFD form); no letter, digit or emoji (`RGI_Emoji`) grapheme at
  all — emoji-only names are valid (v1.2.1/v1.2.2). U+FEFF at either end is trimmed.
  `reserved_term` (v1.2.3), on the confusable skeleton split into words on non-letters/digits:
  (a) a reserved term (`RESERVED_DISPLAY_NAME_TERMS`, default = CONVENTIONS §6 list, v1.2.4:
  without `staff`/`مشرف`) equals a whole word; (b) any single word **contains** a brand term
  (`RESERVED_DISPLAY_NAME_BRAND_TERMS`, default `kabso,كابسو`) anywhere; (c) the separator-free
  name equals a reserved term. "Kab Sonia" and "Staff Sergeant" pass; "TheKabsoTeam" does not.
  The skeleton applies the pinned Unicode 17.0.0 `confusables.txt` (UTS #39, vendored with its
  sha256 under `apps/api/src/modules/users/data/`) both before and after case folding
  (NFKC → map → fold → map), plus a small documented supplement (`confusables.ts`), and drops
  diacritics and tatweel. The reserved-term check runs after schema validation, in the
  registration service.
- Passwords are normalized to Unicode NFC before length checks, hashing and verification. Argon2
  work is capped per process; when saturated → 503 `SERVICE_UNAVAILABLE` + `Retry-After: 1`.
- Rate limits are Redis fixed windows keyed by HMAC-SHA-256 of the subject under
  `RATE_LIMIT_KEY_SECRET`. IP buckets use the client IP derived per `TRUST_PROXY` (never `true`
  in production; production also refuses IPv4 ranges broader than /8, IPv6 broader than /32 and
  `::ffff:0:0/96`, v1.2.3 SEC-003a), with IPv6 grouped by /64. If Redis is unavailable, rate-limited routes fail
  **closed** with 503 `SERVICE_UNAVAILABLE`.
- Non-HTTP execution contexts (WebSocket, RPC) are denied by both global guards until a
  dedicated auth strategy exists.
- Work that must not change response timing or reveal which branch ran (registration mail,
  account-exists notice, resend, forgot-password) runs after the response in a background task
  that is drained on shutdown.
- Expired pending registrations are deleted lazily (register / verify) and by a periodic job
  every `REGISTRATION_CLEANUP_INTERVAL_SECONDS` (default 600 s; 0 disables) in each API process.
- Every authenticated request also counts against 600 / 15 min per user; public routes without
  a specific rule count against 300 / 15 min per IP (`RATE_LIMIT_PUBLIC_IP`).

## Endpoints

| Endpoint | Auth | Rate limit (default) | Notes |
| -------- | ---- | -------------------- | ----- |
| `GET /health/live` | public | none | process up |
| `GET /health/ready` | public | none | DB `SELECT 1` + Redis `PING` (2 s timeout each); 503 + `{status:"down"}` if either fails |
| `POST /auth/register` | public | 5/h per IP (/64), 3/h per email | **v1.2 verify-first.** Always `202 {"status":"verification_pending"}` (no tokens, never `EMAIL_TAKEN`). Order: schema → `reserved_term` → reserved/taken username (an account, or **any** *live* pending registration — including one for the same email, v1.2.3 SEC-025) → identical 409 `USERNAME_TAKEN` → **one Argon2 hash (always, through the cap)** → user lookup → the same transaction on `pending_registrations` in both branches (look up, clear, insert; rolled back when the email belongs to an account) → 202. After the response: new email → 8-digit code mail (request locale: body `locale`, else `Accept-Language`, else `ar`), audit `auth.registration.pending_created` / `auth.registration.replaced`; registered email → "account already exists" notice in the **account's** locale, at most 1/h/account (Redis flag), audit `auth.registration.existing_email_notice`. One row per email (unique index): a new register replaces the old row (new code, old username released). |
| `POST /auth/register/verify` | public | 10/15 min per IP (/64); 15/day per email (v1.2.3 SEC-027, counted before the check); 5 code checks per code and 10 per pending across resends (SEC-026) | v1.2. Atomically consumes an attempt (`attempts < 5`, `total_attempts < 10`, not expired) **before** comparing the code (HMAC, constant-time); the wrong code that reaches either limit deletes the row. Success → one transaction: claim (delete) the pending row, re-check the email is free, create User (`emailVerifiedAt = now`) + Profile + Settings + Session → **201 AuthResponse**; the source is remembered for SEC-023; audit `auth.registration.verified`. **Every failure → the identical 422 `TOKEN_INVALID`** (unknown email, no live pending, wrong code, expired, exhausted, concurrent verify, email registered meanwhile — the owner then also gets the notice); internal reason audited as `auth.registration.verify_failed`. Backstops: email unique violation → 422, username unique violation → 409 `USERNAME_TAKEN`. Malformed body (code not 8 digits) → 400. |
| `POST /auth/register/resend` | public | 3/h per email, 10/h per IP (/64) | v1.2. Always `202 {"status":"verification_pending"}`; after the response, if a live pending exists: new code (old one invalid), per-code attempts reset (`total_attempts` kept), expiry renewed to now + 30 min but **never past `created_at` + 2 h** (`REGISTRATION_MAX_LIFETIME_SECONDS`, v1.2.3 SEC-026; nothing is sent once that has passed), code mail in `Accept-Language` else the pending's locale. |
| `POST /auth/login` | public | 50/15 min per IP (guard); then, after resolving the account and **before** Argon2: 10/15 min per IP+account (every attempt) and 20/15 min per account across all IPs counting **failed attempts only** (v1.2.3 SEC-023: an atomic INCR reserves a slot before Argon2 and is refused above the limit; a correct password — or an Argon2 503 — refunds it with DECR, so concurrent guesses can never exceed 20). A source (IPv4 / IPv6 /64) with a successful login to the account in the last 30 days (`LOGIN_RECENT_SUCCESS_TTL_SECONDS`; HMAC-keyed Redis flag with TTL) bypasses the account bucket. Email and username of one account share the keys; unknown identifiers are keyed by the normalized identifier; breaches audited as `auth.login.rate_limited` | `identifier` containing `@` is treated as an email, otherwise a username; unknown user and wrong password both → 401 `AUTH_INVALID_CREDENTIALS` (unknown users still pay an Argon2 verification); SUSPENDED (after correct password) → 403 `ACCOUNT_SUSPENDED`; DELETED → 401 |
| `POST /auth/refresh` | public (refresh token) | 60/15 min per session | rotation via compare-and-swap. **v1.2 (SEC-022):** the hashes of the last **10** rotated secrets are kept per session (`sessions.rotated_refresh_token_hashes`, newest first, bounded by the rotation SQL and a CHECK); presenting **any** of them = reuse → session revoked (`REFRESH_REUSE`, audited with `rotationsAgo`, `matchedPrevious` and seconds since the last rotation) + 401 `AUTH_REFRESH_INVALID`. A secret never issued for the session (e.g. made up from the public `sid`) or older than the history → 401 `AUTH_REFRESH_INVALID` **without** revoking (audited `auth.refresh.invalid_secret`). Concurrent refreshes with one secret: exactly one succeeds; a duplicate that arrives *after* the winner committed presents the now-previous secret and therefore **revokes the session** (intentional fail-safe, CONVENTIONS §6 — clients must keep refresh single-flight); a duplicate that read the row before the winner committed just gets 401. SUSPENDED → 403 |
| `POST /auth/logout` | bearer | per user | revokes the caller's session (`LOGOUT`) |
| `POST /auth/email/verify` | public | per IP | malformed/unknown → 422 `TOKEN_INVALID`; used/expired → 410 `TOKEN_EXPIRED` |
| `POST /auth/email/resend` | bearer | 5/h per user (`RATE_LIMIT_EMAIL_RESEND_USER`) + per user | no-op when already verified; new token invalidates older ones |
| `POST /auth/password/forgot` | public | 3/h per email, 10/h per IP (/64) | always 202 with empty body; work happens after the response; only ACTIVE users receive mail |
| `POST /auth/password/reset` | public | per IP | token single-use; sets new password and revokes **all** sessions (`PASSWORD_RESET`) |
| `GET /auth/sessions` | bearer | per user | live sessions only, newest first, max 50, `current` = caller's session, `ipCountry` always null |
| `DELETE /auth/sessions/{id}` | bearer | per user | own live session only; foreign, revoked, unknown or malformed id → 404 `NOT_FOUND` |
| `GET /me` | bearer | per user | `Me` |
| `PATCH /me` | bearer | 30/h per user + per user | v1.2 (KL-018): strict body `{"locale":"ar"\|"en"}` → 200 `Me`; the stored locale is used for account mail (notice, password reset, security mail). |
| `GET /users/username-availability` | public | per IP | malformed → 400; reserved, taken by an account or held by a live pending registration → `available:false` |

## Audit events

`auth.registration.pending_created`, `auth.registration.replaced`, `auth.registration.verified`,
`auth.registration.verify_failed` (internal `reason`), `auth.registration.existing_email_notice`,
`auth.login.success`, `auth.login.failure` (with `reason`: `unknown_identifier`
\| `bad_password` \| `suspended`), `auth.login.rate_limited`, `auth.logout`, `auth.refresh.reuse`,
`auth.refresh.invalid_secret` (CONVENTIONS §6 `refresh.invalid_secret`), `auth.email.verified`,
`auth.password.reset_requested`, `auth.password.reset`, `auth.session.revoke`.
