# Kabso Live — Shared API Conventions (authoritative contract)

Status: **v1.2 — approved 2026-10-15; in implementation (KL-016/017/018/019)**. Until those tasks
merge, the deployed API still behaves as v1.1 for the items marked *(v1.2)* below. See §9.
**v1.3 — approved 2026-10-16 (KL-036, CTO review; D38)**: live discovery, host lifecycle,
public profile and follow (§10; items marked *(v1.3)*). **v1.3.1 — 2026-10-16 (KL-046)**:
text hygiene for `displayName` and titles (§6, SEC-036), stale-room handling (§10.2, SEC-035),
rate-limit wording (§7, D42), the heartbeat 503 code (D41), body-parsing order (§4, QA-001) and
follow on private accounts (§10.6, QA-002); items marked *(v1.3.1)*. Data design:
[`DB_PHASE2_DISCOVERY.md`](DB_PHASE2_DISCOVERY.md). Changes require a contract-change proposal recorded in
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
  *(v1.3.1, QA-001)* **Body parsing runs first, on every route.** A JSON body that does not parse
  (`malformed_json`) or exceeds the size limit (`payload_too_large`) is rejected **before**
  authentication, rate limiting and every other check, so it returns 400 even without a token or
  while a feature is disabled. This has been the behaviour since Phase 1 and is accepted: the
  response reveals nothing about the caller or the resource. A body sent with a non-JSON content
  type is not parsed at all; it reaches the route as a missing body and fails at the normal
  body-validation step of that route. Every check order written elsewhere in this contract
  (§10, `openapi.yaml`) starts **after** body parsing.
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
| 409 | `LIVE_ROOM_ALREADY_ACTIVE` | *(v1.3)* Go-live refused: the caller already has a LIVE room with a fresh heartbeat (§10.3). The client resumes or ends it; the room id comes from the caller's own public profile (`liveRoomId`), not from the error. |
| 409 | `LIVE_ROOM_ENDED` | *(v1.3)* Heartbeat for a room that is no longer LIVE (ended by the host, heartbeat timeout, suspension or admin). The host client stops heartbeats and shows the ended state. |
| 410 | `TOKEN_EXPIRED` | Email-verification / password-reset token expired or already used. |
| 422 | `TOKEN_INVALID` | Email-verification / password-reset token malformed or unknown. |
| 429 | `RATE_LIMITED` | Too many requests; `Retry-After` header (seconds) is set. |
| 500 | `INTERNAL_ERROR` | Unexpected server error. |
| 503 | `SERVICE_UNAVAILABLE` | Dependency down (DB/Redis) or feature disabled by config. |
| 503 | `LIVE_HOSTING_UNAVAILABLE` | *(v1.3)* Going live (or heartbeating) is disabled by server config `LIVE_HOSTING_ENABLED=false` (no media provider yet, B1). Not transient: no `Retry-After`; the client shows "not available yet" instead of a generic error. |
| 422 | `LEVEL_CONFIG_INVALID` | *(v1.4-levels, DRAFT, CP-005)* A level configuration breaks the publication rules (CP-005 §4); `details` list every problem. |
| 409 | `LEVEL_VERSION_NOT_DRAFT` | *(v1.4-levels, DRAFT, CP-005)* A published or archived level version cannot change. |
| 503 | `MEDIA_UPLOADS_UNAVAILABLE` | *(v1.5-social, DRAFT, CP-006)* Uploads are disabled by server config `MEDIA_UPLOADS_ENABLED=false` (no storage credentials yet, B12). Not transient: no `Retry-After`. |
| 422 | `MEDIA_INVALID` | *(v1.5-social, DRAFT)* The uploaded object is missing, does not match the declared type or size, or is not a decodable image within the limits (§11.1). |
| 409 | `PIN_LIMIT_REACHED` | *(v1.5-social, DRAFT)* The caller already has 3 pinned posts. |
| 409 | `REPORT_ALREADY_RESOLVED` | *(v1.5-social, DRAFT)* An admin acted on a report that is no longer OPEN. |

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

*(v1.3)* Cursors are **tamper-evident** (signed, §10.4): a cursor that does not decode, fails its
signature, or was issued for different query parameters returns 400 `VALIDATION_FAILED` with
`field: "cursor"`, `issue: "invalid_value"`; the client then reloads from the first page. A small
**server-bounded** list (hard cap enforced by the server, e.g. live categories ≤ 100) may be returned
whole as `{ "data": [...] }` with no `page` object, like `GET /auth/sessions`.

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
  LRM U+200E, RLM U+200F and ALM U+061C. *(v1.3.1)* For `displayName` and live-room titles these
  bans are part of the broader **text hygiene** rules below.
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
  `الدعم`, `الإدارة`; list is server configuration; *(v1.2.6)* `رسمي` removed (given name Rasmi); *(v1.2.4, QA-012)* `staff` and `مشرف` removed because they are common in real names — moderator impersonation is handled by moderation and verified badges). `reserved_term` is evaluated
  after schema validation; audit actions use the `auth.registration.*` prefix; the
  `register/resend` code mail uses `Accept-Language`, else the pending registration's locale.
- **Text hygiene *(v1.3.1, SEC-036)*** — applies to `displayName` and to live-room titles
  (§10.3). It replaces the fixed list of banned characters above with property-based rules; every
  character banned before is still rejected. `device.*` fields keep the older list. The rules run
  on the NFC-normalized, trimmed value, and every violation is `issue: "invalid_format"`.
  1. **Unicode data.** Unicode **17.0.0**:
     - `DerivedCoreProperties.txt` (`Default_Ignorable_Code_Point`);
     - `extracted/DerivedGeneralCategory.txt` (General_Category);
     - `PropList.txt` (`Variation_Selector`);
     - Unicode Emoji 17.0 `emoji-sequences.txt` and `emoji-zwj-sequences.txt` (the RGI emoji set).

     The API **vendors** these files: pinned, with their sha256 recorded next to them, as for
     `confusables.txt` (v1.2.5). It builds its tables from them and downloads nothing at runtime.
     The runtime's own Unicode tables (`\p{…}` in regular expressions; Node 22 ships Unicode 16)
     are not the authority for these rules. Moving to a newer Unicode version is a contract patch.
  2. **Rejected code points.** A code point is rejected when any of these holds, unless rule 3
     allows it:
     - its General_Category is `Cc`, `Cf`, `Zl`, `Zp`, `Co`, `Cs` or `Cn` (controls, format
       characters, line/paragraph separators, private use, surrogates, unassigned);
     - it has `Default_Ignorable_Code_Point = Yes`;
     - it is on the **blank look-alike list**: the Hangul fillers U+115F, U+1160, U+3164, U+FFA0;
       U+2800 BRAILLE PATTERN BLANK; U+FFFC OBJECT REPLACEMENT CHARACTER; U+1D159 MUSICAL SYMBOL
       NULL NOTEHEAD. The list is part of the contract; it changes only by contract patch.
  3. **Allowed exceptions.** These are the only default-ignorable or format characters accepted:
     - **Inside an RGI emoji.** Any code point inside a grapheme cluster that is exactly one RGI
       emoji sequence (rule 1 data): ZWJ and VS16 in emoji sequences, and the tag characters
       U+E0020–U+E007F of the England, Scotland and Wales flags. Tag characters are accepted only
       here.
     - **ZWNJ U+200C and ZWJ U+200D** elsewhere: the placement rule above (between two
       non-joiner, non-space characters).
     - **Variation selectors** elsewhere (`Variation_Selector = Yes`: U+180B–U+180D, U+180F,
       U+FE00–U+FE0F, U+E0100–U+E01EF): only directly after a base character, meaning a code
       point of General_Category `L*`, `N*`, `S*` or `P*` that rule 2 does not reject. So there is
       at most one per base character, and never one at the start, after a space, after a mark, or
       after another selector. This covers text or emoji presentation (U+2665 U+FE0E), CJK ideographic
       variation sequences and Mongolian free variation selectors.
  4. **Spaces.** Space separators (`Zs`: U+0020, U+00A0, U+1680, U+2000–U+200A, U+202F, U+205F and
     U+3000 IDEOGRAPHIC SPACE) are handled as before. They are allowed inside a value and removed at
     either end by trimming. They never count as a letter, and a joiner may not touch them. A value
     made only of spaces is `invalid_format` (v1.2.4). U+3000 is **not** a blank look-alike: it is
     the usual separator in CJK names. Line and paragraph separators (`Zl`, `Zp`) and U+180E are not
     spaces and are rejected by rule 2.
  5. **Letter test.** The "at least one letter, digit or RGI emoji" rule (v1.2.1) counts only code
     points that pass rule 2. Fillers and blank look-alikes **never count as letters**, whatever
     their General_Category in a later Unicode version. The RGI emoji test uses the rule 1 data.
  6. **Unchanged:** the length limits; the zalgo cap (variation selectors are combining marks and
     count toward it, on the NFD form); for `displayName` only, the identity rules (reserved
     terms, confusable skeleton, mixed-script words); error precedence (v1.2.5).
  7. **Must keep passing** (examples; the API test suite carries them): Arabic `محمد علي`, with
     tashkeel `مُحَمَّد` and with tatweel `ليـلى`; Persian `مهر‌آرا` and Urdu `پاک‌ستان` (each with
     ZWNJ U+200C inside); Urdu `عائشہ خان`; Kurdish Sorani `ڕۆژان ئەحمەد` and Kurmanji `Rojîn Şêxo`;
     Hebrew; Devanagari with a ZWJ conjunct; Chinese `李小龙`; Japanese `山田　太郎` (with U+3000)
     and an ideographic variation sequence (U+845B U+E0100); Korean `김민준`; Thai; emoji ZWJ
     sequences (family, rainbow flag U+1F3F3 U+FE0F U+200D U+1F308, health worker with skin tone);
     U+2764 U+FE0F; U+2665 U+FE0E after a name; keycap U+0031 U+FE0F U+20E3; regional-indicator
     flags; the Scotland tag-sequence flag;
     skin-tone modifiers; accented Latin; digits only; U+00A0 inside a name; non-blank braille
     patterns. Every RGI emoji sequence in the rule 1 data must pass after a name.
  8. **Must be rejected** (each alone and inside a name): U+3164, U+115F, U+1160, U+FFA0; U+00AD;
     U+034F; U+2061–U+2064; U+180E; any tag character outside an RGI emoji (including a black flag
     followed by non-RGI tags) and U+E0001; U+2028, U+2029; U+FFF9–U+FFFB; U+1D173–U+1D17A;
     U+2800; U+FFFC; U+1D159; private-use and unassigned code points; lone surrogates; U+17B4,
     U+17B5; U+1BCA0–U+1BCA3; U+0600–U+0605; a variation selector at the start, after a space,
     after another selector, or after a mark; everything rejected before v1.3.1.
  9. **Tightening, applied on write.** The rules are checked when a value is submitted:
     `POST /auth/register` (`displayName`) and `POST /live/rooms` (`title`). No endpoint edits a
     `displayName` in v1.3; a future one must apply these rules. Stored values that no longer pass
     are **not rewritten**: they stay readable and are returned unchanged on every read. A pending
     registration created before the change completes `register/verify` with its stored name (its
     lifetime is at most 2 h). Live-room titles cannot be edited after go-live, so a room keeps its
     title until it ends. Clients keep rendering every server string as untrusted text.
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
| `GET /live/rooms` *(v1.3)* | 300 / 15 min per user |
| `GET /users/{username}` *(v1.3)* | 300 / 15 min per user (profile scraping) |
| `POST /live/rooms` *(v1.3)* | 10 / hour and 30 / day per user; counted **before** the `LIVE_HOSTING_ENABLED` check |
| `POST /live/rooms/{roomId}/heartbeat` *(v1.3)* | 12 / min per user (expected cadence 1 / 15 s = 4 / min; 3× headroom for retries) |
| `POST /live/rooms/{roomId}/end` *(v1.3)* | 30 / hour per user |
| `PUT` + `DELETE /users/{username}/follow` *(v1.3)* | one shared bucket per user: 60 / hour and 300 / day; idempotent no-op calls count too (anti follow/unfollow churn) |
| `POST /auth/password/forgot` | 3 / hour per email, 10 / hour per IP |
| `POST /auth/refresh` | 60 / 15 min per session |
| `POST /auth/email/resend` | 5 / hour per user |
| Other public routes (`email/verify`, `password/reset`, `users/username-availability`) | 300 / 15 min per IP |
| Everything else (authenticated) — includes `GET /live/config`, `/live/categories`, `/live/rooms/{roomId}` | 600 / 15 min per user |

*(v1.3)* Every v1.3 bucket is keyed by the authenticated user id (HMAC as below), with
names `live:list`, `users:profile`, `live:start:h`, `live:start:d`, `live:heartbeat`, `live:end`,
`follow:h`, `follow:d`.

*(v1.3.1, D42)* **Which buckets a request counts against.** An endpoint-specific limit does not
always replace the default bucket:
- **Replaces the per-user default** (600 / 15 min): only the rows marked *(v1.3)* that carry an
  endpoint limit — `GET /live/rooms`, `GET /users/{username}`, `POST /live/rooms`,
  `POST /live/rooms/{roomId}/heartbeat`, `POST /live/rooms/{roomId}/end`, and `PUT` + `DELETE
  /users/{username}/follow`. These requests count only against their own buckets.
- **Counts both** its own bucket and the per-user default: the older authenticated rows,
  `PATCH /me` and `POST /auth/email/resend`. This is stricter and therefore safe; it stays as is.
- **Per-user default only:** every other authenticated route, including `GET /live/config`,
  `GET /live/categories`, `GET /live/rooms/{roomId}` and `POST /auth/logout`.
- **Public routes** (no access token): a route with its own rows above (`login`, `register`,
  `register/verify`, `register/resend`, `password/forgot`, `refresh`) counts only against those
  rows. The per-IP default (300 / 15 min) applies only to public routes without their own row
  (`email/verify`, `password/reset`, `users/username-availability`).

Every new endpoint-specific row must state which of these applies.

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
| *(v1.3)* Tables `live_categories`, `live_rooms` | Backend — `live` module | CTO; see `DB_PHASE2_DISCOVERY.md` |
| *(v1.3)* Table `follows` | Backend — `social` module (follow graph) | CTO; Security reviews follow anti-abuse (KL-040) |
| *(v1.3)* Server config `LIVE_HOSTING_ENABLED` and `LIVE_HEARTBEAT_*` | DevOps (per-environment value) | Turning hosting **on** in staging/production needs owner approval (B1: media provider) |
| *(v1.5-social)* Tables `media_assets`, `media_uploads` | Backend — `media` module | CTO; Security reviews upload validation |
| *(v1.5-social)* Tables `posts`, `post_media`, `post_likes`, `post_saves`, `post_reposts`, `post_share_events`, `post_views`, `post_pins`, `hashtags`, `post_hashtags`, `post_mentions`, `comments`, `comment_likes`, `comment_mentions` | Backend — `posts` module | CTO |
| *(v1.5-social)* Tables `user_blocks`, `user_mutes`, `post_hides`, `reports`, `privacy_settings` | Backend — `safety` module | CTO; Security reviews block semantics |
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
| v1.2.5 | 2026-10-16 | Clarifications from KL-024: (1) error precedence — schema stage rejects mixed-script words with `invalid_format` before reserved-term evaluation; inside the displayName check `reserved_term` is evaluated first. (2) The confusable skeleton = Unicode 17.0.0 `confusables.txt` (vendored, sha256 `091c7f82…ef22a`, verified identical to unicode-org/unicodetools@4fd8eca) plus a documented supplement (i→l, ĸ→k, U+063B/U+063C→ك, ة→ه, combining marks and tatweel stripped). (3) Script data comes from the runtime ICU (Node 22: Unicode 16); characters new in 17 may lack script data — re-check on Node upgrades. (4) The login account bucket counts failures only: attempts from a trusted recent-success source are not counted; a slot is refunded on success, on Argon2 503, and on a correct password for a SUSPENDED account. | Clarification of implemented behavior; no shape change. |
| v1.2.6 | 2026-10-16 | KL-007d residuals: (SEC-030) skeleton supplement adds Latin small capitals U+1D00–U+1D22 and ʙ ɢ ʜ ɪ ʟ ɴ ʀ ʏ ꜰ ꜱ; all-Cyrillic/Greek look-alikes of reserved terms must be caught by the skeleton. (SEC-031) before brand/reserved matching, words joined by non-space separators (`-` `.` `·` `_` etc.) and runs of single-letter words are concatenated (so "Kab-so Live", "K a b s o Team", "ك ا ب س و لايف" are reserved; "Kab Sonia" stays allowed). (SEC-032) the mixed-script rule treats decimal digits of any script as script-neutral and allows Latin combined with Han/Hiragana/Katakana/Hangul in one word (UTS #39 Highly Restrictive); `رسمي` removed from reserved terms. Accepted residual: Arabic words containing the brand string (e.g. "كابسولة") are reserved. | Behavioral; no shape change. |
| v1.2.7 | 2026-10-16 | KL-025 clarifications: small capitals are mapped before the first confusables pass (the Unicode table sends ᴍ→ʍ otherwise); separator/single-letter joining applies to all reserved terms, not only the brand ("Ad-min Ali" reserved). Accepted residual: mixed partial splits such as "Kabs o Live" are allowed (catching them would also block names like "Kab Sonia"); handled by moderation. | Clarification; no shape change. |
| v1.3.0 | 2026-10-16 | **Approved (KL-036, D38).** Phase 2 slice 1 — live discovery (D37): `GET /live/config`, `GET /live/categories` (bounded, empty until admin-created), `GET /live/rooms?tab=popular\|new\|following&category&cursor&limit`, `GET /live/rooms/{roomId}`; host lifecycle behind `LIVE_HOSTING_ENABLED` (default off): `POST /live/rooms`, `POST /live/rooms/{roomId}/heartbeat`, `POST /live/rooms/{roomId}/end`; `GET /users/{username}` (`PublicProfile`), `PUT`/`DELETE /users/{username}/follow`. New codes `LIVE_ROOM_ALREADY_ACTIVE` (409), `LIVE_ROOM_ENDED` (409), `LIVE_HOSTING_UNAVAILABLE` (503) (§4); signed cursors and server-bounded unpaginated lists (§5); new rate limits (§7); table ownership (§8); rules in §10. Tables `live_categories`, `live_rooms`, `follows` (`DB_PHASE2_DISCOVERY.md`). | **Additive**: no existing path, schema or code changes. Mobile maps the three new codes (unknown codes already fall back) and dedupes pages by id. API (KL-037) needs KL-013 merged first. |
| v1.3.1 | 2026-10-16 | KL-040 follow-ups (KL-046). (SEC-036) Text hygiene for `displayName` and live-room titles moves from a fixed list to rules over vendored Unicode 17.0.0 data: `Default_Ignorable_Code_Point`, General_Category Cc/Cf/Zl/Zp/Co/Cs/Cn and a blank look-alike list (Hangul fillers, U+2800, U+FFFC, U+1D159) are rejected. Exceptions: code points inside an RGI emoji (Emoji 17.0), ZWNJ/ZWJ under the existing placement rule, and one variation selector directly after a base character. Spaces unchanged (U+3000 is a space); fillers never count as letters; identity rules unchanged (§6). (SEC-035) Reads filter stale rooms and `GET /live/rooms` writes nothing; the background sweeper ends stale rooms in bounded, non-overlapping batches; room detail and profile compute the timed-out view or end that single room (§10.2; supersedes D42 item 4). (D42) §7 states which endpoint limits replace the per-user default (v1.3 rows) and which count both (`PATCH /me`, `email/resend`). (D41) `heartbeatLiveRoom` 503 names `LIVE_HOSTING_UNAVAILABLE`. (QA-001) §4: body parsing (malformed JSON, size limit) rejects before authentication on every route; check orders in §10 and `openapi.yaml` start after it; a non-JSON content type fails at body validation. (QA-002) `PUT` follow by an existing follower of a private account → idempotent 200, no edge created; a new follow stays 403 (§10.5, §10.6). | **Tightening**, applied on write only: `register` and go-live can now return 400 `invalid_format` for values accepted before. QA-001 documents existing behaviour. QA-002 changes the response from 403 to 200 for an existing follower of a private account; this cannot happen yet, because no endpoint makes an account private in v1.3. Stored names and titles are not rewritten and stay readable. No shape change; responses for stale rooms unchanged. Mobile: no change needed (it already maps `invalid_format`; client pre-validation may stay more permissive, the server is authoritative). |
| tokens v1.2 | 2026-10-18 | `design-tokens.json` v1.2 (D47): `typography.fontFamilyArabic` IBM Plex Sans Arabic → Readex Pro (OFL-1.1), bundled at 400/500/600/700. | Visual only; no shape change. Flutter swaps the bundled Arabic font in the same change set and regenerates goldens. |
| v1.4-levels (draft) | 2026-10-20 | **Draft, owner sign-off pending (CP-005, D72).** Four independent level systems. User: `GET /levels/me`, `/levels/me/{category}`, `/levels/me/history`, `/levels/me/points-history` (signed keyset cursors scoped to caller and filter). Admin (`role = ADMIN`, every mutation in `audit_logs`): categories (list/get/patch), versions (list/create/get/replace/validate/preview/publish with `PRESERVE_POINTS` or `RECOMPUTE_FROM_LEDGER`), a user's states, recalculate, manual adjustment (`Idempotency-Key` required; replay 200, different body 409), reconciliation (`DRY_RUN`/`REPAIR`) and its runs, source events and retry, reports, levels audit log. New error codes `LEVEL_CONFIG_INVALID` (422) and `LEVEL_VERSION_NOT_DRAFT` (409). `GET /users/{username}/levels` (levels only, for profiles). Admin routes need a per-route permission (`LEVELS_VIEW|EDIT|PUBLISH|ADJUST|RECONCILE`) besides `role = ADMIN`. No public endpoint accepts points, levels or events. Additive: no existing path, schema or code changes |
| v1.5-social (draft) | 2026-10-20 | **Draft, owner-approved scope (CP-006 M1, D87).** Media upload (presigned PUT, `MEDIA_UPLOADS_ENABLED`), posts with drafts / scheduling / pins / reposts / shares / views, Following and Trending feeds (frozen 10-minute snapshot), likes and likers, saves, comments with one reply level and pins, hashtags, mentions, prefix search, block / mute / hide, reports with an admin queue (`MODERATION` permission), privacy settings. New codes `MEDIA_UPLOADS_UNAVAILABLE` (503), `MEDIA_INVALID` (422), `PIN_LIMIT_REACHED` (409), `REPORT_ALREADY_RESOLVED` (409). Rules in §11. | Additive: no existing path, schema or code changes. |
| v1.5-social (draft) | 2026-10-21 | **CP-008 (D91, CP-006 M3):** photo stories — `createStory`, `getStory`, `deleteStory`, `listStoryTray`, `listUserStories`, `markStorySeen`, `listStoryViewers`, `listStoryArchive`; schemas `Story`, `StoryList`, `StoryPage`, `StoryTrayItem`, `StoryTrayPage`, `CreateStoryRequest`; `MediaKind.STORY_IMAGE` (1 920 px variant); report `targetType: STORY`; mute also hides stories. §11.1, §11.7, §11.8 lines and §11.9. | Additive: new paths and schemas, new enum values (`STORY_IMAGE`, `STORY`). |
| v1.5-social (draft) | 2026-10-21 | **CP-007 (D89):** `GET /me/mutes` (the caller's muted accounts, newest first, `UserSummaryPage`) and `PublicProfile.isMuted` (the caller's own mute only). §11.7 line added. | Additive: a new path and one new boolean on `PublicProfile`. |

**Intentionally deferred lint warnings** (`@redocly/cli@2.60.0`, pinned in `tools/redocly`, config `redocly.yaml`):
`operation-4xx-response` on `/health/live` and `/health/ready` — these probes accept no input and
cannot produce a 4xx; adding a fictitious 4xx would make the contract less accurate.

## 10. Live discovery, public profiles and follow *(v1.3, approved — KL-036)*

Phase 2 slice 1 (D37). Every endpoint below is under `/api/v1`, requires a bearer token, and
uses §4 errors, §5 pagination and §7 rate limits. Data design: `DB_PHASE2_DISCOVERY.md`.
**There is no media in v1.3** (B1): a "live room" is metadata plus a host heartbeat. That is
why hosting is behind `LIVE_HOSTING_ENABLED` (default `false`) and production lists stay empty
until a media provider is wired in.

### 10.1 Categories

- Server-curated rows (`slug`, Arabic and English names, `sortOrder`, `isActive`). **None are
  seeded**: the owner has not chosen any (D36 Q7, D37). The list is empty and the client shows
  only the "All / الكل" chip.
- `GET /live/categories` returns active rows ordered by `sortOrder`, then `slug`, unpaginated.
  The server caps active categories at **100** (enforced by the future admin write path), which
  keeps the response bounded.
- `name` is a single localized string. The language comes from the primary subtag of
  `Accept-Language` when it is `ar` or `en`, else the caller's stored `locale`, else `ar`. The
  client refetches categories and rooms after a locale change.
- Admin management (create, rename, reorder, deactivate) is **out of scope** for v1.3. It will
  be added as ADMIN-role endpoints under `/api/v1/admin/live/categories` in a later contract
  version, with audit actions `admin.live_category.*`. Categories are deactivated, never deleted,
  because rooms reference them. Until then, rows can only be added by a reviewed migration or an
  ops script that the owner approves.

### 10.2 Room visibility and freshness

- **Fresh heartbeat:** `lastHeartbeatAt > now − LIVE_HEARTBEAT_STALE_SECONDS`. The default is
  **45 s**, which is three missed beats at the 15 s cadence. The server clock is authoritative.
- **Listed** (`GET /live/rooms`) and reported as `liveRoomId`: only when all three hold:
  - `status = LIVE`;
  - the heartbeat is fresh;
  - the host's account is `ACTIVE`.
- **Stale rooms are never reported as LIVE.** A room that has timed out is reported as:
  - `status = ENDED`;
  - `endReason = HEARTBEAT_TIMEOUT`;
  - `endedAt = lastHeartbeatAt` (the last proof of life).
- **How stale rooms are handled *(v1.3.1, SEC-035)*.** Reads filter; a background sweeper ends.
  What clients see is unchanged from v1.3.0.
  - **Reads filter stale rooms out.** Every read applies the freshness predicate itself, so a room
    whose heartbeat is older than the window is never returned as LIVE, however far behind the
    sweeper is:
    - `GET /live/rooms` leaves it out of every tab. The list **performs no writes**; in
      particular it never ends stale rooms.
    - `GET /live/rooms/{roomId}` returns it as ENDED with the fields above. The server either
      computes that view without writing, or ends **that single room** (a one-row update) and
      returns the stored result. Both give the same response, because `endedAt` is the stored
      `lastHeartbeatAt` and a late heartbeat can never revive a stale room (§10.3).
    - `PublicProfile.liveRoomId` is `null` for it, by the same choice.
  - **The background sweeper ends stale rooms** (every `LIVE_SWEEP_INTERVAL_SECONDS`, default
    15 s) in **bounded batches**: each batch ends a limited number of rooms in its own short
    transaction, and a run continues batch by batch until no stale room is left or its per-run
    budget is spent. Runs in one API instance never overlap. Several instances may sweep at once;
    the `status = 'LIVE'` guard makes that safe. Data design: `DB_PHASE2_DISCOVERY.md` §4.
  - **Single-room write paths** (go-live for the caller's own room, heartbeat, end, suspension)
    still end that one stale room in their own transaction (§10.3).
  - Each timed-out room is ended exactly once, with the `live.room.timeout` audit row, whichever
    path ends it.
  - A timed-out room can therefore keep `status = 'LIVE'` in the database until the sweeper
    reaches it. The API never shows this. Every query of `live_rooms`, including future ones,
    applies the freshness predicate rather than trusting `status` alone.
- `GET /live/rooms/{roomId}` also returns ENDED rooms, so a stale card can open the "Live ended"
  state (HL-L10). It returns 404 `NOT_FOUND` in three cases, with the same body each time:
  - the room does not exist;
  - the id is malformed;
  - the host's account is not `ACTIVE`.
- **Suspension:** the suspension flow ends the user's LIVE room with `HOST_SUSPENDED`. No admin
  API exists yet, so suspension is an ops action, and the ops procedure must also end the room.
  The `ACTIVE` filter above is the safety net. `ADMIN` is reserved for a future moderation
  action.
- `viewerCount` is always **0** in v1.3 because there is no realtime presence. `coverUrl` is
  always `null` because there is no upload. The card shows the "New" chip and the host avatar
  (HL-H4).

### 10.3 Host lifecycle

- **Go live** (`POST /live/rooms`, body `{title, categorySlug?}`): checks run in the order given
  in `openapi.yaml`, after body parsing (§4, *(v1.3.1, QA-001)*: malformed JSON or an oversized
  body → 400 before any of them, even without a token or while hosting is disabled). In short:
  - disabled by config → 503 `LIVE_HOSTING_UNAVAILABLE`;
  - unknown or inactive `categorySlug` → 400, `invalid_value`;
  - a fresh LIVE room already exists → 409 `LIVE_ROOM_ALREADY_ACTIVE`.

  A stale LIVE room is ended (`HEARTBEAT_TIMEOUT`) in the same transaction. The database
  guarantees **at most one LIVE room per host** with a partial unique index; a race loser gets
  the 409. Only `SOLO` rooms can be created; `PK` and `MULTI` are reserved and the request has no
  `mode` field (sending one → 400 `unknown_field`).
- **No `Idempotency-Key`** (§3 requires one only for financial requests). A retried go-live
  after a lost response gets 409. The client then reads its own `GET /users/{username}` and either
  resumes heartbeats on `liveRoomId` or ends that room.
- **Verified email** is required. Since v1.2 every account is verified at creation, so this only
  rejects legacy unverified accounts, with 403 `AUTH_FORBIDDEN`.
- **Title:** stored after the same NFC normalization and trimming as `displayName`; 1–80
  grapheme clusters and ≤ 160 code points. Violations → `too_short`, `too_long` or
  `invalid_format`.
  - **These displayName rules apply** (§6):
    - C0/C1 control characters are rejected, so titles are single-line;
    - bidi override/isolate characters U+202A–U+202E and U+2066–U+2069 are rejected;
    - LRM, RLM and ALM are rejected;
    - U+200B, U+2060 and an inner U+FEFF are rejected; a U+FEFF at either end is trimmed;
    - ZWNJ and ZWJ are allowed only between two non-joiner, non-space characters;
    - more than 3 consecutive combining marks (counted on the NFD form) are rejected;
    - the title must contain at least one letter, digit or RGI emoji;
    - *(v1.3.1, SEC-036)* the full **text hygiene** rules of §6, which include every item
      above: default-ignorable, format, separator, private-use and unassigned code points and
      the blank look-alikes are rejected, with the RGI-emoji, joiner and variation-selector
      exceptions. They apply when the room is created; existing rooms keep their titles.
  - **These displayName rules do not apply:**
    - the reserved-term and brand rule (`reserved_term`): a title is content, not an identity,
      so "Kabso support Q&A" is a legitimate title;
    - the confusable-skeleton and mixed-script rules: these exist to stop impersonation in
      identity fields.

  Title impersonation and abuse belong to moderation, which is out of scope here.
- **Heartbeat** (`POST /live/rooms/{roomId}/heartbeat`, 204):
  - Send it every `heartbeatIntervalSeconds` from `GET /live/config` (default **15 s**). Server
    config: `LIVE_HEARTBEAT_INTERVAL_SECONDS` and `LIVE_HEARTBEAT_STALE_SECONDS`.
  - Any caller who is not the host → 404 (never 403, so room ownership is not revealed). This
    covers non-hosts, malformed ids and nonexistent rooms.
  - A host heartbeat on an ended room → 409 `LIVE_ROOM_ENDED`.
  - While `LIVE_HOSTING_ENABLED=false` → 503 `LIVE_HOSTING_UNAVAILABLE` (for every caller,
    before the ownership check, so it reveals nothing about the room; *(v1.3.1, D41)* named
    explicitly in `openapi.yaml`). Turning hosting off
    therefore empties the lists within 45 s, with no extra code path.
- **End** (`POST /live/rooms/{roomId}/end`, 200 `LiveRoom`): host only (others → 404), and
  idempotent. If the room is already ended, the original `endReason` and `endedAt` are kept.
  End is allowed while hosting is disabled.
- Audit actions: `live.room.start`, `live.room.end` (with the reason), `live.room.timeout`.
  Heartbeats are not audited.

### 10.4 Lists and cursors (`GET /live/rooms`)

- **`tab` (required) sets the order**, always with `id` desc as the final tiebreak:

  | Tab | Order |
  | --- | ----- |
  | `popular` | `viewerCount` desc, then `startedAt` desc |
  | `new` | `startedAt` desc |
  | `following` | `startedAt` desc, over rooms whose host the caller follows |

  While `viewerCount` is 0, `popular` orders like `new`.
- **`category`** is optional and filters **every** tab, so the semantics are uniform. Per HL-H3
  the client sends it only on Popular.
  - A malformed slug → 400 (`field "category"`).
  - A well-formed slug that is unknown or inactive → **200 with an empty list**. Categories can
    change between the client's category fetch and the list call, and an empty grid is the
    honest answer.
- **Cursor:** base64url of a compact payload, a `.`, then a truncated HMAC-SHA-256 tag (128-bit).
  - The payload holds a format version, `tab`, `category`, the caller's user id (`following`
    only), and the sort key of the last row (`viewerCount`, `startedAt`, `id`).
  - The HMAC key is derived from server configuration (implementation: KL-037).
  - The cursor fails with 400 `VALIDATION_FAILED` (`field "cursor"`, `issue "invalid_value"`)
    when it:
    - does not decode;
    - fails the tag check;
    - has an unknown version;
    - does not match the request's `tab`, `category` or caller.
  - The cursor contains nothing secret; the HMAC only stops crafted cursors from turning into
    arbitrary keyset queries.
- **Ranking drift:** pages are keyset queries over live data. A room can move between pages (its
  viewer count changes) or end in between. As a result, **a room may appear twice or be
  skipped**, so the client dedupes by `id` (HL-H5). `nextCursor = null` means no more rows at
  query time; pull-to-refresh restarts from the first page.
- `limit` is 1–50, default 20.

### 10.5 Public profile (`GET /users/{username}`)

- **Fields:**
  - `id`, `username`, `displayName`, `avatarUrl`, `bio`;
  - `isPrivate`, `followerCount`, `followingCount`;
  - `isFollowing`, `isSelf`;
  - `liveRoomId`: a fresh LIVE room (§10.2), else null.

  The profile **never** includes an email, role, status, locale, or created-at time.
- **404 `NOT_FOUND` with an identical body** in every one of these cases:
  - the username is malformed (no 400);
  - it is unknown;
  - it is held only by a pending registration;
  - the account is `SUSPENDED` or `DELETED`.

  Suspended and nonexistent accounts are indistinguishable. Implementation note: a single query
  filtered on `status = 'ACTIVE'`, so the response time does not depend on why the result is
  empty.
- **Counts** are the number of follow rows, computed on read in v1.3; denormalized counters can
  come later. They can include accounts that are currently suspended; this is an accepted
  inaccuracy. When an account is deleted, its follow rows are deleted in both directions.
- **Private accounts:** `user_settings.is_private` exists, but no endpoint sets it in v1.3, so it
  is `false` for everyone. Defined behaviour for when it becomes settable:
  - the profile stays visible;
  - **new** follows → 403 `AUTH_FORBIDDEN` (follow requests are deferred to a later contract);
    a repeated `PUT` by an existing follower → idempotent 200 *(v1.3.1, QA-002; §10.6)*;
  - existing followers are kept and can unfollow;
  - the live room stays listed (live rooms are public).

### 10.6 Follow

- **`PUT /users/{username}/follow`** creates the edge. It is idempotent: an existing edge →
  200, with no error and no duplicate.
- **`DELETE /users/{username}/follow`** removes the edge. It is idempotent: a missing edge → 200.
- Both return `{isFollowing, followerCount}`, where `followerCount` is the target's count after
  the operation.
- **Errors:**
  - target malformed, unknown, suspended or deleted → 404;
  - self → 400 `VALIDATION_FAILED` (`field "username"`, `issue "invalid_value"`). The client never
    offers Follow when `isSelf`. A database CHECK is the backstop.
  - private target on `PUT` → 403 `AUTH_FORBIDDEN`, but only when the caller does not already
    follow the target. *(v1.3.1, QA-002)* A `PUT` by an existing follower of a private account
    is the idempotent no-op: 200 `{isFollowing: true, followerCount}`, and no edge is created.
    The existing-edge check comes before the private check.
- **Anti-spam:** follow and unfollow share one rate-limit bucket (§7: 60 / hour, 300 / day). No
  notification is sent in v1.3, so follow spam has no amplification yet. A cap on total
  followees is an open owner question.
- Audit: none per edge (high volume, low risk). Rate-limit rejections are logged.

### 10.7 Out of scope for v1.3 (recorded so nobody assumes otherwise)

- Media and streaming (playback, publish tokens, LiveKit) — B1.
- Realtime presence and real viewer counts; the realtime events contract.
- Live chat, gifts, PK and multi-guest.
- Blocking and muting; follower and following lists; follow requests for private accounts;
  follow notifications.
- Moderation and reporting of rooms or titles; admin end-room (`ADMIN` is reserved).
- Admin category management.
- Search; the featured strip (HL-H4); the "Live now from people you follow" rail as a separate
  endpoint (the client derives it from `tab=following`).
- Editing a room's title or category after go-live; covers and cover upload.

## 11. Social content — posts, comments, search and safety *(v1.5-social, DRAFT — CP-006 M1, D87)*

Additive; no earlier rule changes. Reels and video (M2), stories (M3), notifications (M4),
personalised ranking (M5), places (M6) and sharing in messages (M7) come later and extend
these rules.

### 11.1 Media upload

- Server config `MEDIA_UPLOADS_ENABLED` (default `false`, B12) gates `createMediaUpload` and
  `completeMediaUpload`: off → 503 `MEDIA_UPLOADS_UNAVAILABLE` (no `Retry-After`, like
  `LIVE_HOSTING_UNAVAILABLE`). Storage is S3-compatible (`S3_*`; MinIO locally, R2 in the cloud).
- Accepted types: JPEG, PNG and WebP (the bytes decide, not the declared type: both must agree).
  HEIC/HEIF is refused at `createMediaUpload` (the app converts it to JPEG on the device).
- Objects go to `uploads/{userId}/{uploadId}` (private). Completing verifies the object (HEAD
  size equals `byteSize`, magic bytes match `contentType`, decodes, ≤ 8 000 px per side,
  ≤ 50 MP), strips every metadata block (EXIF, GPS, XMP, ICC kept as sRGB), writes
  `media/{mediaId}/1080.webp` and `media/{mediaId}/320.webp` and a blurhash, and deletes the
  upload object. Failure → 422 `MEDIA_INVALID`; the slot is closed.
- *(CP-008)* `STORY_IMAGE` uploads follow the same checks; their large variant is
  `media/{mediaId}/1920.webp` (at most 1 920 px on the long side) and attaches only to a story,
  as a `POST_IMAGE` asset attaches only to a post (otherwise 400 `mediaId` / `invalid_value`).
- Asset URLs are served from `MEDIA_PUBLIC_BASE_URL` (a CDN or bucket domain). An asset is
  attachable once, only by its owner, within 24 hours; unattached assets and expired slots are
  deleted by a sweeper.

### 11.2 Posts

- `text`: NFC, trimmed, ≤ 2 200 code points, the free-text hygiene rules of §6 (no control,
  bidi-override or zero-width characters except ZWNJ/ZWJ between joining letters; line breaks
  allowed, at most 30). A post needs `text` or at least one image.
- `location`: free text ≤ 80 code points (places arrive with M6), same hygiene.
- `status`: `PUBLISHED` (default), `DRAFT`, or `SCHEDULED` with `publishAt` in
  [now + 5 min, now + 30 days]; a worker publishes due posts within a minute. Drafts and
  scheduled posts are visible only to the author.
- Visibility of a published post to a caller: not removed; author ACTIVE; no block in either
  direction; author public, or the caller is the author or follows the author; `moderation`
  `VISIBLE` unless the caller is the author. Anything else → 404 (never 403).
- **Moderation (CP-006 Q2, until a provider is chosen):** a post with images is `PENDING` —
  visible only to its author and absent from feeds, search and other people's grids; text-only
  posts are `VISIBLE`. Switching on a provider is a config change, not a contract change.
- Settings default from the author's privacy settings (§11.7); `hideLikeCount` makes
  `likeCount` null and the likers list 403 for everyone but the author.
- Pins: at most 3 published posts; a 4th → 409 `PIN_LIMIT_REACHED`. Profile grids list pinned
  posts first (newest pin first), then the rest newest first.
- Reposts: of visible public posts by someone else; a repost puts the post (with `repostedBy`)
  in the reposter's followers' Following feed and on the reposter's Reposts tab. Deleting or
  removing the original removes it everywhere.
- `Idempotency-Key` on `createPost`: kept 24 h per user; same key + same body → the first
  response (status 201); same key + different body → 409 `IDEMPOTENCY_CONFLICT`.

### 11.3 Feeds and cursors

- All lists use signed keyset cursors (§5) bound to the list, its filters and the caller.
- `following`: published, visible posts and reposts of followed accounts, newest first by
  `publishedAt` (for a repost: its repost time); a post appears once (its newest entry).
  Muted authors (and reposts by muted accounts) and hidden posts are left out.
- `trending`: the first page ranks visible public posts published in the last 7 days by
  `(likes + 2·comments + 3·shares + 2·saves + 1) / (hoursSincePublished + 2)^1.5` (weights are
  server config), excluding the caller's own, muted and hidden posts, at most 2 per author in
  any 10. The ranked ids (≤ 500) are frozen for 10 minutes; later pages read the snapshot, so
  they never repeat or skip. An expired or foreign snapshot → 400 `cursor` / `invalid_value`.

### 11.4 Views

`recordViews`: a view counts when `watchedMs ≥ 1 000`, once per user, post and rolling 24 h,
never for the author, and only for posts the caller may see; anything else is ignored. The
count is eventually consistent (≤ 1 min).

### 11.5 Comments

- `text`: NFC, trimmed, 1–500 code points, §6 hygiene, ≤ 5 line breaks.
- Who may comment: `commentsEnabled` and `whoCanComment` (`EVERYONE`; `FOLLOWERS` = people who
  follow the author; `NOBODY`); the author always may. Refused → 403 `AUTH_FORBIDDEN`. Blocked
  users never see the post (404).
- One level of replies: `parentId` of a reply resolves to its top-level comment. Deleting a
  top-level comment deletes its replies. `canDelete` is true for the comment's author and the
  post's author.
- Order: the pinned comment, then by `likeCount` desc, then newest. One pinned comment per post,
  top-level only (a reply → 400 `commentId` / `invalid_value`).

### 11.6 Hashtags, mentions and search

- `#tag`: `#` followed by 1–100 letters, marks, digits or `_` (any script), not preceded by a
  letter or digit; stored in NFC lower case; at most 30 distinct per post (extra ones are plain
  text). Hashtag pages list visible posts; `top` uses the trending score over 30 days.
- `@username`: a valid, existing, ACTIVE username (§6 pattern); at most 20 per post or comment.
  A mention of someone whose `whoCanMention` forbids it (or who blocked the author) stays plain
  text and is not linked.
- `search`: case-insensitive prefix match — users on username and display name, hashtags on the
  tag, posts on caption words (visible posts only). Blocked users never appear. Results are
  ranked by exact match, then followers / post count / recency.

### 11.7 Block, mute, hide, reports and privacy

- **Block** is symmetric in effect: neither side sees the other's posts, comments, profile
  content, likes lists or search entries, and follows both ways are deleted (not restored by
  unblock). While a block exists in either direction, `followUser` between the two → 404 (the
  existing "not found" answer; follow and block writes are serialized). Blocking yourself → 400.
  Their existing comments on your posts are hidden from you.
- **Mute** is one-way and silent: the muted account's posts, reposts and (CP-008) stories leave
  the caller's feeds and stories tray; profile, search and direct links still work. The caller sees their mutes in
  `GET /me/mutes` (newest first, every muted account, like `GET /me/blocks`) and on profiles as
  `PublicProfile.isMuted`; the muted account is never told (CP-007).
- **Hide**: the post leaves the caller's feeds and hashtag pages.
- **Reports**: one OPEN report per reporter and target; a repeat → 200 with the existing
  report. Admins with permission `MODERATION` list and act; `REMOVE_TARGET` removes the post or
  comment (soft, audited) or, for a user, records the decision only (suspension stays a separate
  admin tool); every OPEN report on that target closes with the same outcome. Acting on a closed
  report → 409 `REPORT_ALREADY_RESOLVED`.
- **Privacy settings**: `whoCanMention` (`EVERYONE` default; `FOLLOWING` = accounts the user
  follows; `NOBODY`) and `defaultWhoCanComment` (`EVERYONE` default) for new posts.

### 11.8 Rate limits (all per user; replace the per-user default)

| Endpoint | Limit |
| --- | --- |
| `POST /media/uploads` | 60 / hour; counted **before** the `MEDIA_UPLOADS_ENABLED` check |
| `POST /posts` | 20 / hour, 100 / day |
| `POST /posts/{id}/comments` | 60 / hour |
| `PUT`/`DELETE` like (posts and comments) | one bucket: 600 / hour |
| `PUT`/`DELETE` repost | 60 / hour |
| `POST /posts/{id}/shares` | 120 / hour |
| `POST /views` | 120 / hour |
| `GET /feed/posts`, `GET /search` | 300 / 15 min |
| `PUT /users/{username}/block` | 60 / hour |
| `POST /reports` | 30 / hour |
| `POST /stories` *(CP-008)* | 30 / hour |
| `PUT /stories/{id}/seen` *(CP-008)* | 600 / hour |
| `GET /feed/stories` *(CP-008)* | 300 / 15 min |

### 11.9 Stories *(CP-008, D91 — CP-006 M3, photos only)*

- A story is one `STORY_IMAGE` photo and an optional `text` (NFC, trimmed, ≤ 200 code points,
  §6 hygiene, ≤ 3 line breaks; mentions as §11.6, at most 10; hashtags stay plain text).
  `createStory` takes an `Idempotency-Key` with the rules of `createPost`.
- **Active** = not deleted and `expiresAt` (`createdAt` + 24 h) in the future. Expired stories
  leave every list except the author's archive (`GET /me/stories/archive`, newest first), which
  keeps them until the author deletes them. Deleting is soft and removes the story everywhere.
- **No moderation hold (owner, D91):** story photos are visible at once; safety relies on
  reports (`targetType: STORY`, admin `REMOVE_TARGET` removes the story) and the 24-hour expiry.
- **Visibility** as posts (§11.2): author ACTIVE, no block either way, author public or followed
  by the caller (the author always sees their own). Anything else → 404.
- **Tray** (`GET /feed/stories`): the caller's own entry first when they have an active story;
  then followed accounts with active stories, those with unseen stories first, each group by the
  newest story; muted accounts left out (§11.7). Keyset cursor (§5).
- **Seen**: one row per viewer and story, idempotent, never for the author; `viewCount` (author
  only) counts distinct viewers. `GET /stories/{id}/viewers` is for the author only and only
  until 48 h after posting; otherwise 404.
- Replies, video stories, highlights and stickers are not part of M3 (M7, M2, later).
