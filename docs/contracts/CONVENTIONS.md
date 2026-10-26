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
| 403 | `LIVE_HOSTING_NOT_ALLOWED` | *(v1.6-live, DRAFT, CP-010)* Go-live refused: the caller does not hold the hosting permission (`Me.canHost`; admin-granted, later through an agency or an identity check). The app explains how to get it. |
| 403 | `LIVE_GUESTS_NOT_ALLOWED` | *(v1.6-live, DRAFT, CP-010)* A guest (no account) asked to watch a room whose host switched guests off. The app offers to sign in. |
| 409 | `LIVE_SEAT_UNAVAILABLE` | *(v1.7-live, DRAFT, CP-011)* The seat or seats asked for cannot be used: taken, locked, out of range, none free, a room without seats (SOLO), the user already seated, the host, or (invitation) not watching now; also shrinking `seatCount` below an occupied seat and locking an occupied seat. |
| 403 | `LIVE_CHAT_NOT_IN_ROOM` | *(v1.9-live, DRAFT, CP-013)* A chat message from someone who is not in the room now (neither the host nor in the room's media session). The app shows the room again (it rejoins). |
| 403 | `LIVE_CHAT_MUTED` | *(v1.9-live, DRAFT, CP-013)* The host or a moderator muted the caller in this live's chat. The app disables the composer and says so. |
| 409 | `LIVE_CHAT_CLOSED` | *(v1.9-live, DRAFT, CP-013)* The host turned the chat off. The app shows "Chat is off". |
| 409 | `LIVE_REQUEST_NOT_PENDING` | *(v1.7-live, DRAFT, CP-011)* The seat request or invitation was already accepted, declined, cancelled, replaced or expired. |
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
| 409 | `LIVE_SCHEDULE_FULL` | *(v1.14-live, DRAFT, CP-016 C)* The host already has 10 upcoming scheduled lives. |
| 409 | `INSUFFICIENT_COINS` | *(v1.19-live, DRAFT, CP-017)* The caller's coin balance does not cover the price (a bullet message costs 15 coins, §10.19). Nothing was charged or sent. The app shows the balance (`GET /wallet/me`). |
| 403 | `LIVE_KICKED` | *(v1.20-live, DRAFT, D105)* The host or a moderator kicked the caller out of this live (§10.20): no media token, chat, bullet, taps or seat request in it until it ends. The app leaves the room and says so; a later live of the same host is fine. |
| 409 | `ALREADY_IN_FAMILY` | *(v1.21-live, DRAFT, CP-018)* The caller already belongs to a family (creating or asking to join one), or the person a join request is accepted for joined another family meanwhile (§10.21). |
| 409 | `FAMILY_FULL` | *(v1.21-live, DRAFT, CP-018)* The family has 500 members (§10.21). |
| 409 | `FAMILY_NAME_TAKEN` | *(v1.21-live, DRAFT, CP-018)* A family that is not disbanded has this name (compared after NFKC and lower case). Nothing was charged. |
| 409 | `FAMILY_REQUEST_PENDING` | *(v1.21-live, DRAFT, CP-018)* The caller already has a pending join request to another family; the app offers to cancel it. |
| 409 | `FAMILY_REQUEST_NOT_PENDING` | *(v1.21-live, DRAFT, CP-018)* The join request was already accepted, declined, cancelled or expired. |
| 409 | `FAMILY_NOT_EMPTY` | *(v1.21-live, DRAFT, CP-018)* Only a family with the leader alone can be disbanded. |
| 409 | `FAMILY_LEADER_CANNOT_LEAVE` | *(v1.21-live, DRAFT, CP-018)* The leader hands the family over (or disbands a family that has only them) instead of leaving. |
| 409 | `CP_ALREADY_PAIRED` | *(v1.21-live, DRAFT, CP-018)* The caller or the other person already has a CP partner. Nothing was charged. |
| 409 | `CP_REQUEST_PENDING` | *(v1.21-live, DRAFT, CP-018)* The caller already has a pending CP request (one at a time); the app offers to cancel it. |
| 409 | `CP_REQUEST_NOT_PENDING` | *(v1.21-live, DRAFT, CP-018)* The CP request was already accepted, declined, cancelled or expired (its coins were refunded unless it was accepted). |
| 409 | `CP_NOT_PAIRED` | *(v1.21-live, DRAFT, CP-018)* A CP gift from a caller who has no partner. Nothing was charged. |
| 409 | `MEDAL_NOT_UNLOCKED` | *(v1.21-live, DRAFT, CP-018)* `PUT /me/medals/showcase` named a medal the caller has not earned (or an unknown code). Nothing changed. |
| 409 | `BAG_ITEM_NOT_OWNED` | *(v1.22-live, DRAFT, CP-019)* `PUT /me/bag/equipped` named an item the caller does not own in that category (or an unknown code). Nothing changed (§10.22). |
| 409 | `GIFT_UNAVAILABLE` | *(v1.23-live, DRAFT, CP-020)* A gift send named a code that is not in the gift catalogue or was disabled. Nothing was charged or sent; the app reloads `GET /gifts/catalogue` (§10.23). |
| 409 | `GIFT_BAG_INSUFFICIENT` | *(v1.23-live, DRAFT, CP-020)* A send with `source: BAG` needs more of that gift (quantity × recipients) than the caller's gift bag holds. Nothing was taken or sent; the app reloads `GET /me/gifts/bag` (§10.23). |
| 409 | `LIVE_GIFT_RECIPIENT_UNAVAILABLE` | *(v1.23-live, DRAFT, CP-020)* A recipient of a gift send is not the host or seated in that live now, has no ACTIVE account with that username, or blocked the sender (or was blocked by them). Nothing was charged or sent; the app reloads the seats (§10.23). |

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
| `POST /live/rooms/{roomId}/media-token` *(v1.6-live, CP-010)* | 120 / hour per user; guests 60 / hour per IP |
| Seat requests and invitations *(v1.7-live, CP-011)* | 30 / 10 min per user |
| Host and moderator seat actions (accept, decline, mute, remove, lock, moderators, `seatCount`/`theme` in `PATCH`) *(v1.7-live, CP-011)* | 300 / hour per user |
| `GET /live/rooms/{roomId}/seats` *(v1.7-live, CP-011)* | 600 / 15 min per user; guests share the CP-010 guest read limit per IP |
| `POST /live/rooms/{roomId}/taps` *(v1.8-live, CP-012)* | 120 / min per user (one batch a second = 60 / min; 2× headroom). **Replaces** the per-user default (it would exhaust 600 / 15 min). The 10-a-second and 10 000-a-live limits are counting rules, not rate limits: past them taps are dropped with 200 (§10.10) |
| `POST /live/rooms/{roomId}/chat` *(v1.9-live, CP-013)* | 20 / min per user, plus a counting rule of 1 a second per user and room (429 with `Retry-After`). **Replaces** the per-user default |
| Chat delete, chat mutes, `chatEnabled` in `PATCH` *(v1.9-live, CP-013)* | the CP-011 host and moderator bucket (300 / hour per user); deleting one's own message counts there too |
| `GET /live/rooms/{roomId}/contributors` *(v1.10-live, CP-014)*, and *(v1.20-live)* `GET …/contributors/{username}` | the per-user default; guests share the CP-010 guest read limit per IP |
| `title`, `categorySlug`, `topic` in `PATCH /live/rooms/{roomId}` *(v1.10-live, CP-014)* | the existing `PATCH` bucket (60 / hour per user) |
| `PUT` and `DELETE /me/live-cover` *(v1.11-live, CP-015)* | 30 / hour per user (one bucket). **Replaces** the per-user default; the upload itself counts in the `POST /media/uploads` bucket |
| `PUT /me/live-blocked-words` *(v1.12-live, CP-016 B)* | 30 / hour per user. **Replaces** the per-user default; `GET` uses the default |
| `GET /live/rankings` *(v1.13-live, CP-016 A)* | the per-user default; guests share the CP-010 guest read limit per IP |
| `POST` and `DELETE /me/live-schedule` *(v1.14-live, CP-016 C)* | 30 / hour per user (one bucket). **Replaces** the per-user default; `GET` uses the default |
| `POST /live/rooms/{roomId}/bullets` *(v1.19-live, CP-017)* | 20 / min per user (bucket `live:bullet`, the chat rule's numbers), plus a counting rule of **one bullet every 5 s per user** across all lives (429 with `Retry-After`), checked before the charge. **Replaces** the per-user default |
| `GET /wallet/me` *(v1.19-live, CP-017)* | the per-user default |
| VOICE and IMAGE chat messages *(v1.19-live, CP-017)* | the chat rows above (they are chat messages); the uploads count in the `POST /media/uploads` bucket |
| `POST /live/rooms/{roomId}/kicks`, `DELETE /live/rooms/{roomId}/kicks/{username}` *(v1.20-live, D105)* | the CP-011 host and moderator bucket (300 / hour per user); `GET /live/rooms/{roomId}/kicks` uses the per-user default |
| Family writes: `POST /families`, `PATCH` and `DELETE /families/{familyId}`, join requests (ask, accept, decline, `DELETE /me/family-join-request`), leave, remove, role, transfer *(v1.21-live, CP-018)* | 60 / hour per user (bucket `families:write`). **Replaces** the per-user default; family reads use the default |
| CP requests (send, cancel, accept, decline) and `DELETE /cp/me` *(v1.21-live, CP-018)* | 30 / hour per user (bucket `cp:write`). **Replaces** the per-user default; CP reads use the default |
| `POST /cp/me/gifts` *(v1.21-live, CP-018)* | 30 / min per user (bucket `cp:gift`). **Replaces** the per-user default |
| `PUT /me/medals/showcase` *(v1.21-live, CP-018)* | 60 / hour per user (bucket `medals:showcase`). **Replaces** the per-user default; `GET /me/medals/showcase` uses the default |
| `GET /users/{username}/medals` *(v1.21-live, CP-018)* | the `GET /users/{username}` bucket (300 / 15 min per user); `GET /medals` uses the per-user default |
| `POST /live/rooms/{roomId}/gifts` *(v1.23-live, CP-020)* | 120 / min per user (bucket `live:gift`, `RATE_LIMIT_LIVE_GIFT_USER`; combos are quick taps on "send"). **Replaces** the per-user default. `GET /gifts/catalogue` and `GET /me/gifts/bag` use the per-user default |
| `PUT /me/bag/equipped` *(v1.22-live, CP-019)* | 60 / hour per user (bucket `bag:equip`, the family-write numbers like the medal showcase). **Replaces** the per-user default; `GET /bag/catalogue` and `GET /me/bag` use the per-user default |
| `GET /live/rooms/{roomId}/chat` *(v1.9-live, CP-013)* | the per-user default; guests share the CP-010 guest read limit per IP |
| `PATCH /live/rooms/{roomId}` *(v1.6-live, CP-010)* | 60 / hour per user |
| `GET /live/rooms/{roomId}/viewers` *(v1.6-live, CP-010)* | 300 / 15 min per user (shares the `GET /live/rooms` rule); *(v1.23.2-live, D109)* guests share the CP-010 guest read limit per IP |
| Guest reads: `GET /live/config`, `GET /live/rooms`, `GET /live/rooms/{roomId}` without a token *(v1.6-live, CP-010)* | 300 / 15 min per IP |
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
  /users/{username}/follow`; *(v1.8-live)* also `POST /live/rooms/{roomId}/taps`. These requests count only against their own buckets.
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
| *(v1.19-live)* Tables `wallets`, `wallet_ledger` | Backend — `wallet` module | CTO; Security (financial tables) |
| *(v1.19-live)* Table `live_bullets` | Backend — `live` module | CTO |
| *(v1.20-live)* Table `live_room_kicks` | Backend — `live` module | CTO |
| *(v1.21-live)* Tables `families`, `family_members`, `family_join_requests`, `family_points_ledger` | Backend — `families` module (`family_points_ledger` is written with the wallet's debits) | CTO; Security (the points ledger follows wallet debits) |
| *(v1.21-live)* Tables `cp_requests`, `cp_couples`, `cp_partners`, `cp_gifts` | Backend — `couples` module | CTO; Security (coin paths) |
| *(v1.21-live)* Tables `medals`, `user_medals` | Backend — `medals` module (awards are written by the modules where the events happen, through `medal-awards.ts`) | CTO |
| *(v1.22-live)* Tables `bag_items`, `user_bag_items` | Backend — `bag` module (the free items are written at signup by the users module through `bag-grants.ts`, in the account's transaction; admin grants by the `bag-admin` CLI) | CTO |
| *(v1.23-live)* Tables `gifts`, `user_gift_stock`, `live_gifts`, `live_gift_recipients` | Backend — `gifts` module (sends are written by the live module's `LiveGiftsService` through `gift-catalogue.ts` in the send's transaction; the catalogue and grants only by the `gift-admin` CLI) | CTO; Security (coin path) |
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
| v1.6-live (draft) | 2026-10-23 | **CP-010 (D93, Live L1):** live video — `createLiveMediaToken`, `updateLiveRoom`, `listLiveRoomViewers`, `grantLiveHost`, `revokeLiveHost`; schemas `LiveMediaAccess`, `LiveMediaTokenRequest`, `UpdateLiveRoomRequest`, `LiveViewer`, `LiveViewerPage`; `LiveRoom.allowGuests`, `StartLiveRoomRequest.allowGuests`, `Me.canHost`; report `targetType: LIVE_ROOM`; codes `LIVE_HOSTING_NOT_ALLOWED`, `LIVE_GUESTS_NOT_ALLOWED`; guests read the live hub without a token; `viewerCount` counts people watching. §4, §7 rows and §10.8. | **Additive**, plus one **tightening** (go-live needs the hosting permission; hosting is switched off in production today, so nobody loses anything) and one **relaxing** (four live operations accept no token). |
| v1.7-live (draft) | 2026-10-23 | **CP-011 (D94):** multi-guest video and audio rooms — `LiveRoomMode.AUDIO`; `StartLiveRoomRequest.mode`, `seatCount`, `theme`; `LiveRoomSummary.seatCount`, `occupiedSeats`, `theme`; `LiveConfig.themes`, `seatCounts`; `UpdateLiveRoomRequest.seatCount`, `theme` (now at least one field); media role `SPEAKER`; operations `getLiveRoomSeats`, `requestLiveSeat`, `listLiveSeatRequests`, `cancelLiveSeatRequest`, `acceptLiveSeatRequest`, `declineLiveSeatRequest`, `inviteToLiveSeat`, `acceptLiveSeatInvite`, `declineLiveSeatInvite`, `leaveLiveSeat`, `muteLiveSeat`, `removeFromLiveSeat`, `lockLiveSeat`, `addLiveModerator`, `removeLiveModerator`; codes `LIVE_SEAT_UNAVAILABLE`, `LIVE_REQUEST_NOT_PENDING`. §4, §7 rows and §10.9. | **Additive** (a new enum value older apps show as SOLO; new optional request fields; new response fields and operations). |
| v1.10-live (draft) | 2026-10-24 | **CP-014 parts A and B (D97):** `UpdateLiveRoomRequest.title`, `categorySlug` (null = none), `topic`; `LiveRoomTopic`; `LiveRoomSummary.topic` (so `LiveRoom.topic`); media metadata `roomInfoVersion`; `listLiveContributors` (`GET /live/rooms/{roomId}/contributors`, `LiveContributor`, `LiveContributorList`); §7 rows and §10.12. Room boost (part C) waits for L3. | **Additive** (new optional request fields, a new nullable response field, a new operation, a new metadata key). |
| v1.11-live (draft) | 2026-10-24 | **CP-015 (D98):** `MediaKind.LIVE_COVER` (a centre-cropped square, 640 and 320 px); `setLiveCover` / `removeLiveCover` (`PUT` / `DELETE /me/live-cover`, `SetLiveCoverRequest`, `LiveCover`); `Me.liveCoverUrl`; `LiveRoomSummary.coverUrl` is the host's cover; §7 row, §10.13 and §11.1. | **Additive** (a new enum value, new operations, a new response field; `coverUrl` was already nullable). |
| v1.12-live (draft) | 2026-10-24 | **CP-016 part B (D99):** `getLiveBlockedWords` / `setLiveBlockedWords` (`GET` / `PUT /me/live-blocked-words`, `SetLiveBlockedWordsRequest`, `LiveBlockedWords`); `LiveChatMessage.text` may be masked; §7 row and §10.14. | **Additive** (new operations; masking only changes message content). |
| v1.13-live (draft) | 2026-10-25 | **CP-016 part A (D99):** `listLiveRankings` (`GET /live/rankings?period=HOUR\|DAY\|WEEK`, `LiveRankingPeriod`, `LiveRankingEntry`, `LiveRankings`); §7 row and §10.15. | **Additive** (a new operation). |
| v1.23.3-live (draft) | 2026-10-26 | **D111 (owner: "CP pair on seats"):** `LiveSeats.couples` (`LiveSeatCouple` `{userIds, level, levelName}`) on `getLiveRoomSeats` and every operation that answers `LiveSeats`: the CP couples whose partners both sit in the room now (host included), ACTIVE accounts, no block between them; a couple formed, ended, levelled up or a block between the partners raises the seat `version` of the rooms where both sit. The seat responses now read `Accept-Language` (for `levelName`). §10.9. | **Additive** (a new response field older apps ignore). |
| v1.23.2-live (draft) | 2026-10-26 | **D109 (owner: "viewers don't show for the other viewer"):** `listLiveRoomViewers` (`GET /live/rooms/{roomId}/viewers`) is no longer host only: anyone who may watch the room lists who is watching now, newest first, same `LiveViewerPage` (guests too when the room allows guests, `security: [{}, bearerAuth]`); a non-host signed-in caller never sees users with a block either way; 403 `LIVE_GUESTS_NOT_ALLOWED` / `LIVE_KICKED`. The host's answer is unchanged. §7 row and §10.8. | **Relaxing** (an operation that answered 404 to non-hosts now answers 200; it also accepts no token). No shape change. |
| v1.23-live (draft) | 2026-10-26 | **CP-020 (D108, owner 2026-10-26):** live gifts. Tag `gifts`: `getGiftCatalogue` (`GET /gifts/catalogue`, `GiftCatalogue` with `version`, `categories`, `quantities`, `maxRecipients`, `comboWindowSeconds`; `Gift`, `GiftCategory` `POPULAR`/`EVENT`/`FUN`, `GiftBadge` `NONE`/`NEW`/`EVENT`), `getMyGiftBag` (`GET /me/gifts/bag`, `GiftBag`, `GiftBagItem`); tag `live`: `sendLiveGift` (`POST /live/rooms/{roomId}/gifts`, `LiveGiftSendRequest`, `LiveGiftResult`, `LiveGift`, `LiveGiftCombo`, `LiveGiftSource` `COINS`/`BAG`), data message `gift` on topic `gift`; wallet ledger reason `LIVE_GIFT` (counts for the family); codes `GIFT_UNAVAILABLE`, `GIFT_BAG_INSUFFICIENT`, `LIVE_GIFT_RECIPIENT_UNAVAILABLE` (409). Gifts now write `LiveScore.supportPoints` (100 a coin), the Contribution list and the popularity board (100 a coin), charm (`GIFT_RECEIVED`) and support (`GIFT_SENT`) levels. Server config `LIVE_GIFT_QUANTITIES`, `RATE_LIMIT_LIVE_GIFT_USER`; CLI `gift-admin add|update|disable|enable|list|grant|bag`; audit `gift.add`, `gift.update`, `gift.disable`, `gift.enable`, `gift.grant`. The catalogue starts empty. §4, §7, §8, §10.10, §10.11, §10.12, §10.15, §10.18, §10.19, §10.23. | **Additive** (new operations, schemas, codes, a data message topic and a ledger reason). `LiveContributor.points` and the board's points now include gifts (same fields). |
| v1.22-live (draft) | 2026-10-26 | **CP-019 (D107, owner 2026-10-26):** the bag (الحقيبة), first category `PROFILE_CARD`. Tag `bag`: `listBagCatalogue` (`GET /bag/catalogue?category=`, `BagCatalogue`, `BagCatalogueItem`), `getMyBag` (`GET /me/bag?category=`, `Bag`, `BagItem`), `setMyBagEquipped` (`PUT /me/bag/equipped`, `SetBagEquippedRequest`, `BagEquipped`, `BagEquippedItem`); `BagCategory` (`PROFILE_CARD`), `BagItemSource` (`FREE_SIGNUP`, `BACKFILL`, `ADMIN`); parameter `BagCategoryQuery`; `PublicProfile.profileCard` (`ProfileCard` or null, required); code `BAG_ITEM_NOT_OWNED` (409). Every new account receives `bunny_royal` and wears it; existing accounts receive it by the migration. Server CLI `bag-admin grant|revoke|list`; audit `bag.grant`, `bag.revoke`. §4, §7, §8, §10.5, §10.22. | **Additive** (new operations, schemas, a code and a response field). `PublicProfile` gains one **required**, nullable field: strict clients update their model in the same change set. `BagCategory` and `BagItemSource` will gain values: clients ignore items of unknown categories and show unknown sources as opaque. |
| v1.21-live (draft) | 2026-10-26 | **CP-018 (D106, owner 2026-10-26):** families, CP couples and medals. Families (tag `families`): `getFamilyConfig`, `searchFamilies`, `createFamily` (500 coins, ledger `FAMILY_CREATE`, `clientId`), `getMyFamily`, `getFamily`, `getFamilyByNumber` (`GET /family-numbers/{number}`), `updateFamily` (emblem), `disbandFamily`, `listFamilyMembers`, `removeFamilyMember`, `setFamilyMemberRole`, `transferFamily`, `leaveFamily`, `requestToJoinFamily`, `listFamilyJoinRequests`, `acceptFamilyJoinRequest`, `declineFamilyJoinRequest`, `getMyFamilyJoinRequest` / `cancelFamilyJoinRequest` (`/me/family-join-request`). CP (tag `cp`): `getCpConfig`, `sendCpRequest` (99 coins, `CP_REQUEST`, refunded as `CP_REFUND`), `listCpRequests`, `cancelCpRequest`, `acceptCpRequest`, `declineCpRequest`, `getMyCp`, `endCp`, `sendCpGift` (`CP_GIFT`). Medals (tag `medals`): `listMedals`, `listUserMedals`, `getMyMedalShowcase` / `setMyMedalShowcase` (`/me/medals/showcase`, owner amendment: up to 6 unlocked medals, ordered). `PublicProfile.family`, `cp`, `medals` (required; the first two nullable); `NotificationType` `CP_REQUEST`, `CP_ACCEPTED`, `FAMILY_JOIN_ACCEPTED`, `FAMILY_JOIN_DECLINED`, `MEDAL_AWARDED`; `NotificationTarget.type` `FAMILY`, `MEDAL`; `MediaKind.FAMILY_EMBLEM`; codes `ALREADY_IN_FAMILY`, `FAMILY_FULL`, `FAMILY_NAME_TAKEN`, `FAMILY_REQUEST_PENDING`, `FAMILY_REQUEST_NOT_PENDING`, `FAMILY_NOT_EMPTY`, `FAMILY_LEADER_CANNOT_LEAVE`, `CP_ALREADY_PAIRED`, `CP_REQUEST_PENDING`, `CP_REQUEST_NOT_PENDING`, `CP_NOT_PAIRED`, `MEDAL_NOT_UNLOCKED` (409); server config `BONDS_SWEEP_INTERVAL_SECONDS`; §4, §7, §8, §10.5, §10.21, §11.1, §11.10. | **Additive** (new operations, codes, enum values and response fields). `PublicProfile` gains three **required** fields: strict clients update their model in the same change set; clients ignore unknown notification and target types (§11.10). |
| v1.20-live (draft) | 2026-10-26 | **Owner D105:** the host and the room's moderators kick a person out of a live (audio and video) until it ends. `kickFromLive` (`POST /live/rooms/{roomId}/kicks`, `LiveKickRequest`, `LiveKick`; 201, 200 when already kicked), `listLiveKicks` (`GET …/kicks`, `LiveKickList`), `unkickFromLive` (`DELETE …/kicks/{username}`, 204); `LiveRoom.kicked`; data message `kick` on topic `kick`; code `LIVE_KICKED` (403) on `createLiveMediaToken`, `sendLiveChatMessage`, `sendLiveBullet`, `tapLiveRoom` and `requestLiveSeat` (the last two now document 403); audit `live.kick`, `live.kick.undo`. Also (owner, same row) `getLiveContributor` (`GET /live/rooms/{roomId}/contributors/{username}`, `LiveContributorStanding`: one person's points and rank in the live). §4, §7, §8, §10.9, §10.11, §10.12, §10.20. | **Additive** (new operations, a new response field, a new code and data message topic). A kicked user's older app sees the new code as a generic error and cannot rejoin. |
| v1.19-live (draft) | 2026-10-26 | **CP-017 (D104, owner 2026-10-26):** coins and bullet messages, voice clips and images in the live chat. `getMyWallet` (`GET /wallet/me`, `Wallet`; tag `wallet`); coins only from the server's `wallet-admin` tool (purchases still B5); `sendLiveBullet` (`POST /live/rooms/{roomId}/bullets`, `LiveBulletSendRequest`, `LiveBullet`, `LiveBulletResult`), 15 coins, shown in every live as data message `bullet` on topic `bullet`; code `INSUFFICIENT_COINS` (409). Chat: `LiveChatSendRequest.kind` (`TEXT` default, `VOICE`, `IMAGE`) and `mediaId`; `LiveChatMessage.kind`, `media`, `expiresAt` (VOICE and IMAGE vanish 60 s after sending); `MediaKind` `LIVE_CHAT_IMAGE`, `LIVE_CHAT_VOICE`; `CreateMediaUploadRequest.contentType` `audio/mp4`; `MediaAsset.type` `AUDIO`, `durationMs`, `width`/`height` 0 for audio. §4, §7 rows, §8, §10.11, §10.19, §11.1. | **Additive** (new operations, fields, enum values, a code and a data message topic). `LiveChatSendRequest.text` is now required only for `TEXT` (the default, so existing apps send exactly as before); older apps show a VOICE or IMAGE message as an empty line until they update. `MediaAsset.width`/`height` may be 0, only for the new `AUDIO` assets. |
| v1.18-live (draft) | 2026-10-26 | **Owner D103:** `AUDIO` seat counts 5, 10, 15, 20, 25 (host included; was 6, 9, 15, 20, 25); seat indexes stay 1 … 24 (`LiveSeatCount`, `LiveConfig.seatCounts`); §10.9. Existing rooms of 6 / 9 become 10. | **Breaking for `AUDIO` starts with 6 or 9** (400 `invalid_value`); apps read the counts from `LiveConfig.seatCounts`. |
| v1.17-live (draft) | 2026-10-25 | **CP-016 part D (D101, owner 2026-10-25):** `LiveRoom.roomLevel` (the host's charm level); every 10 counted taps of a viewer in a live give the host 1 charm point (`PointsSourceType` `LIVE_TAPS`), at most 10 000 taps (1 000 points) per viewer in each live; §10.18, §10.10. | **Additive** (a new field and a new enum value). |
| v1.16-live (draft) | 2026-10-25 | **Owner D100:** `AUDIO` seat counts 6, 9, 15, 20, 25 (host included; was 5, 9, 13); seat indexes 1 … 24 (`LiveSeatCount`, `LiveConfig.seatCounts`, seat paths and bodies); §10.9. | **Breaking for `AUDIO` starts with 5 or 13** (400 `invalid_value`); apps read the counts from `LiveConfig.seatCounts`. Existing rooms of 5 / 13 became 6 / 15. |
| v1.15-live (draft) | 2026-10-25 | **CP-016 part G (D99, owner 2026-10-25):** `LiveRoom.roomNumber` (the host's 9-digit public room number); §10.17. | **Additive** (a new field). |
| v1.14-live (draft) | 2026-10-25 | **CP-016 part C (D99):** `listMyLiveSchedule`, `createLiveScheduleSlot`, `deleteLiveScheduleSlot` (`GET` / `POST /me/live-schedule`, `DELETE /me/live-schedule/{slotId}`, `CreateLiveScheduleSlotRequest`, `LiveScheduleSlot`, `LiveScheduleList`); notification type `LIVE_SCHEDULED_SOON` (target `USER`: the host, with the title as `text` and the optional `NotificationTarget.startsAt`); `NotificationSettings.lives`; code `LIVE_SCHEDULE_FULL` (409); §7 row, §10.16, §11.10. | **Additive** for new operations and fields. A new `NotificationType` value: clients ignore types they do not know (the app already does); its target uses the existing `USER` type so older apps still read the inbox. |
| v1.9-live (draft) | 2026-10-24 | **CP-013 (D96):** live room chat — `sendLiveChatMessage`, `listLiveChatMessages`, `deleteLiveChatMessage`, `listLiveChatMutes`, `muteLiveChatUser`, `unmuteLiveChatUser`; schemas `LiveChatText`, `LiveChatSendRequest`, `LiveChatMessage`, `LiveChatMessageList`, `LiveChatMute`, `LiveChatMuteList`; `LiveRoom.chatEnabled`, `chatMuted`; `UpdateLiveRoomRequest.chatEnabled`; report `targetType: LIVE_CHAT_MESSAGE`; codes `LIVE_CHAT_NOT_IN_ROOM`, `LIVE_CHAT_MUTED`, `LIVE_CHAT_CLOSED`; media data messages `chat`, `chat-delete`, `join`, `chat-state`. §4, §7 rows and §10.11. | **Additive** (new operations, fields, codes, enum value and data message types; apps ignore unknown data message types). |
| v1.8-live (draft) | 2026-10-23 | **CP-012 (D95):** live taps and the room score — `tapLiveRoom` (`POST /live/rooms/{roomId}/taps`, `LiveTapsRequest`, `LiveTapsResult`); `LiveScore`; `LiveRoomSummary.score`; `LiveRoom.scoreParts`; `popular` ordered by `score` (was `viewerCount`), its cursor carries the score; §7 row and §10.10. | **Additive** in shape (new fields and operation). **Behaviour:** `popular` order changes, and list cursors issued before v1.8-live (every tab: the cursor format version moved) become invalid (400 `invalid_value`); clients already restart from the first page on that error and dedupe by id. |
| v1.5-social (draft) | 2026-10-21 | **CP-009 (D92, CP-006 M4):** in-app notifications — `listNotifications`, `getUnreadNotificationCount`, `markNotificationsRead`, `getNotificationSettings`, `updateNotificationSettings`; schemas `Notification`, `NotificationType`, `NotificationTarget`, `NotificationPage`, `UnreadCount`, `MarkNotificationsReadRequest`, `NotificationSettings`, `UpdateNotificationSettingsRequest`. §11.7 (mute), §11.8 and §11.10. | Additive: new tag, paths and schemas. |
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
  | `popular` | *(v1.8-live)* `score` desc (§10.10), then `startedAt` desc. *(v1.3–v1.7)* `viewerCount` desc |
  | `new` | `startedAt` desc |
  | `following` | `startedAt` desc, over rooms whose host the caller follows |

  While every score is 0, `popular` orders like `new`.
- **`category`** is optional and filters **every** tab, so the semantics are uniform. Per HL-H3
  the client sends it only on Popular.
  - A malformed slug → 400 (`field "category"`).
  - A well-formed slug that is unknown or inactive → **200 with an empty list**. Categories can
    change between the client's category fetch and the list call, and an empty grid is the
    honest answer.
- **Cursor:** base64url of a compact payload, a `.`, then a truncated HMAC-SHA-256 tag (128-bit).
  - The payload holds a format version, `tab`, `category`, the caller's user id (`following`
    only), and the sort key of the last row (*(v1.8-live)* `score`, `startedAt`, `id`;
    earlier `viewerCount`). A cursor of an older format version → 400 as below.
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
  - `liveRoomId`: a fresh LIVE room (§10.2), else null;
  - *(v1.21-live, CP-018)* `family` (`{id, number, name, level, emblemUrl, role}` or null), `cp`
    (`{partner, since, level, levelName, points}` or null; null too while the partner is not
    ACTIVE) and `medals` (`{owned, total, latest, showcase}`: at most the 3 newest, and the up to
    6 medals the user chose to show, in their order), §10.21. Tier and medal
    names follow `Accept-Language`, else the caller's locale.
  - *(v1.22-live, CP-019)* `profileCard`: `{code, assetKey}` of the profile card the user wears
    (the header decoration of their profile card, §10.22), or null when they wear none.

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

- Media and streaming (playback, publish tokens, LiveKit) — B1. *(CP-010: see §10.8.)*
- Realtime presence and real viewer counts; the realtime events contract. *(CP-010: real viewer
  counts, §10.8; the realtime events contract is still out of scope.)*
- Live chat, gifts, PK and multi-guest. *(CP-011: multi-guest, §10.9; CP-013: chat, §10.11.)*
- Blocking and muting; follower and following lists; follow requests for private accounts;
  follow notifications.
- Moderation and reporting of rooms or titles; admin end-room (`ADMIN` is reserved). *(CP-010:
  room reports and admin ending, §10.8.)*
- Admin category management.
- Search; the featured strip (HL-H4); the "Live now from people you follow" rail as a separate
  endpoint (the client derives it from `tab=following`).
- Editing a room's title or category after go-live; covers and cover upload.

### 10.8 Live video *(v1.6-live, DRAFT — CP-010, D93, Live L1)*

- **Media server:** LiveKit (D3) behind a `LiveMediaProvider` port. Config `LIVEKIT_URL`,
  `LIVEKIT_API_KEY` and `LIVEKIT_API_SECRET`: `LIVE_HOSTING_ENABLED=true` requires all three,
  and production requires `wss://`. A LiveKit room is named by the live room's id.
- **Hosting permission** (`live_hosts`, `Me.canHost`):
  - `startLiveRoom` needs it, else 403 `LIVE_HOSTING_NOT_ALLOWED` (checked after
    `LIVE_HOSTING_ENABLED`);
  - admins with `LIVE_HOSTS` grant and revoke it (audited);
  - revoking ends a running room (`ADMIN`);
  - each grant keeps its source (`ADMIN`; `AGENCY` and `IDENTITY` arrive in L1b, owner D93).
- **Visibility:** a room is visible to anyone, private hosts included (owner D93: a live is
  public; only posts, reels and stories follow §11.2). Hidden only when the host is not ACTIVE
  or a block exists either way (404). Guests have no account, so blocks do not apply to them.
- **Media token** (`createLiveMediaToken`):
  - roles:
    - HOST: the host of a LIVE room; may publish camera and microphone only;
    - VIEWER: everyone else; subscribe only;
  - viewers are hidden participants (no viewer roster on the media session);
  - valid 10 minutes to join; a joined session is not cut at expiry;
  - the identity is the user id, or `guest:<guestId>` for a guest.
- **Guests** (no bearer token; owner D93):
  - **may:** `GET /live/config`, `GET /live/rooms` (`popular`, `new`), `GET /live/rooms/{roomId}`
    and `createLiveMediaToken` with a `guestId` (a UUID the app keeps per session); later
    versions add reads such as the seats, the chat and *(v1.23.2-live)* the viewer list;
  - **may not:** everything else; those endpoints need a token;
  - **room switch:** `allowGuests` (default true) is set at go-live or with
    `PATCH /live/rooms/{roomId}`;
  - **switching off:** removes connected guests at once and refuses new guest tokens
    (403 `LIVE_GUESTS_NOT_ALLOWED`);
  - **`guestNumber`:** 1000–9999, derived from the guest id with a server secret, so it is
    stable for a session and reveals nothing.
- **Presence and counts:**
  - the media server's signed webhook (`POST /internal/livekit/webhook`, not public API)
    records joins and leaves in `live_room_viewers`, one row per room and identity;
  - the sweeper reconciles with the media server;
  - `viewerCount` = connected identities other than the host, guests included;
  - `popular` orders by it;
  - `listLiveRoomViewers` lists them, newest first (users and "Guest" + `guestNumber`):
    - the host of the room: everyone connected (v1.6-live; unchanged);
    - *(v1.23.2-live, D109, owner: "viewers don't show for the other viewer")* anyone else who
      may watch the room, in the same shape: a room the caller may not see → 404; a guest
      without an account needs `allowGuests` (else 403 `LIVE_GUESTS_NOT_ALLOWED`); a caller
      kicked out of this live → 403 `LIVE_KICKED` (§10.20); a signed-in caller other than the
      host never sees a user they blocked or who blocked them (guests have no blocks). Being
      connected is not required (like the seats and the chat, the list is part of what the
      room shows). Before v1.23.2-live anyone but the host got 404;
    - an ended room → an empty list.
- **Ending:** whenever a room ends (host, heartbeat timeout, suspension, admin, revoked
  permission), the media session is closed for everyone. A host who drops out without ending
  keeps the room until the heartbeat timeout (§10.3); the app says "The host will be right
  back".
- **Reports:** `POST /reports` accepts `targetType: LIVE_ROOM` (a LIVE or recently ended room the
  reporter can see; not your own). `REMOVE_TARGET` ends the room with `ADMIN` (audited).
- **No time limit** on a live (owner D93).

### 10.9 Multi-guest and audio rooms *(v1.7-live, DRAFT — CP-011, D94)*

- **Modes:** `SOLO` (§10.8), `MULTI` (video seats) and `AUDIO` (voice seats). `PK` stays
  reserved (L5). `seatCount` counts the host's tile: `MULTI` 4, 6, 9 or 12 (owner D94); `AUDIO`
  5, 10, 15, 20 or 25 (v1.18-live, owner D103; was 6, 9, 15, 20 or 25 — rooms of 6 or 9
  became 10; before v1.16-live, owner D100, it was 5, 9 or 13). Seats are numbered 1 … `seatCount`-1 (at most 24); the host is 0.
- **Seat state:** `EMPTY`, `LOCKED` or `TAKEN` (with the user and `mutedByHost`). Every change
  increases the room's seat `version` in the same transaction and writes `{"seatsVersion": n}`
  into the media room's metadata; apps refetch `getLiveRoomSeats` when it moves.
- **Roles in a room:** the host; up to 5 **moderators** the host appoints for this room; seated
  guests; viewers. Guests without an account watch only (owner D94): they cannot ask, be
  invited or moderate.
- **Getting a seat (owner D94: both ways):**
  - a viewer asks (`requestLiveSeat`); the host or a moderator accepts or declines;
  - the host or a moderator invites a viewer watching now (`inviteToLiveSeat`); the invitee
    accepts or declines within 60 seconds; the invitation also reaches them as a media data
    message `{"type":"seat-invite","roomId":…}` addressed to their identity;
  - a request or invitation names a seat or lets the server pick the first free one.
- **Who may do what:**
  - host and moderators: accept, decline, invite, mute, take off;
  - host only: lock or unlock seats, change `seatCount` and `theme`, appoint moderators;
  - a moderator never acts on the host or another moderator.
- **Media permission:** seating a guest (role `SPEAKER`) grants publishing on the media server
  at once: `MULTI` camera and microphone, `AUDIO` microphone. `mutedByHost` withdraws the
  microphone; taking off withdraws publishing and unpublishes. An `AUDIO` host publishes the
  microphone only.
- **Losing a seat or a pending request:** leaving the media session (webhook or
  reconciliation), suspension, a block with the host, removal by the host or a moderator,
  leaving the seat, the room ending, or *(v1.20-live)* being kicked out of the live (§10.20).
- **Locks and resizing:** an occupied seat cannot be locked; `seatCount` cannot shrink below an
  occupied seat (409 `LIVE_SEAT_UNAVAILABLE`).
- **Themes:** `theme` is a slug from `LiveConfig.themes` (the first is the default). The art
  ships in the app; an unknown slug shows the default.
- **Hub:** `LiveRoomSummary.seatCount` and `occupiedSeats` let cards show the mode and how
  many guests are on.
- **CP couples on seats** *(v1.23.3-live, DRAFT — D111)*: `LiveSeats.couples` lists the CP
  couples (§10.21) whose partners **both** sit in the room now — the host (seat 0) and the
  `TAKEN` seats — as `{userIds, level, levelName}`, `userIds` in seat order (the host first),
  the list ordered by the first partner's seat; `levelName` by `Accept-Language`, else the
  caller's locale. Like `PublicProfile.cp`, a couple shows only while both accounts are
  `ACTIVE`; a couple whose partners have a block between them (either way) and an ended couple
  are never listed. Everyone who may read the seats (guests included) reads the same list. A
  change outside the seats that changes the list — a couple formed (`acceptCpRequest`) or ended
  (`endCp`), its level moved by a CP gift, a block between the partners added or removed —
  raises the seat `version` of every `LIVE` room where both sit, in the same transaction; the
  media room metadata follows with the sweeper's reconciliation. Apps draw the two seats joined
  when they are next to each other (same row of 5, or neighbours on the circle); where they sit
  apart, nothing is drawn.

### 10.10 Live taps and the room score *(v1.8-live, DRAFT — CP-012, D95)*

- **Points:** a counted tap is 1 point; a support coin is 100 points (L3 writes
  `supportPoints` in the gift's own transaction, and takes them back on a refund). *(v1.23-live,
  CP-020: every coin of a gift's value sent in the live, §10.23; there are no refunds yet.)* Nothing
  else changes the score. `LiveScore.total` = `tapPoints` + `supportPoints`. The score
  belongs to one room: a new live starts at 0 and an ended room keeps its score.
- **Who may tap:** signed-in callers who may see the room. Guests without an account → 401
  (owner D95). The host's own taps count 0. Seated guests and moderators count like any
  viewer (owner D95).
- **Counting (per caller and room, in the same transaction as the score update):**
  - **10 a second:** a batch adds at most `10 × seconds since the caller's last counted
    batch` (whole and part seconds), at most 10 for the caller's first batch in the room,
    and never more than `count` (1–50).
  - **10 000 a live:** the caller's counted taps in the room never exceed 10 000.
  - Dropped taps are not an error: 200 with `accepted` < `count`.
- **Live updates:** the server writes `{"score": total}` into the media room's metadata
  (next to `seatsVersion`, §10.9), at most once every 2 seconds per room. Apps show it
  without polling; `GET /live/rooms/{roomId}` returns `scoreParts`.
- **Hub:** `LiveRoomSummary.score` is on every card; `popular` orders by it (§10.4) so rooms
  compete to rise (owner D95).
- **Levels:** the score itself counts towards no level. *(v1.17-live, owner D101: a viewer's
  counted taps also give the host charm points, §10.18; the score is unchanged.)*
- **Abuse watch:** each caller's counted taps per room are kept (`live_room_tappers`) for
  admins looking into a suspicious room. *(v1.10-live, owner D97: the top 50 are public as the
  Contribution list, §10.12.)*

### 10.11 Live room chat *(v1.9-live, DRAFT — CP-013, D96)*

- **Path of a message:** the app sends it to the API; the API checks it, stores it and sends
  it to everyone in the media room as a data message. Apps never publish data themselves
  (`canPublishData` stays false), so every line on screen passed the server's checks.
- **Text:** NFC, trimmed, 1–200 code points (owner D96), §6 text hygiene, no line breaks
  (`U+000A`, `U+000D`, `U+2028`, `U+2029` → 400 `invalid_format`). Over 200 → `too_long`; empty
  after trimming → `required`. Mentions and links are plain text.
- *(v1.19-live, CP-017)* **Kinds:** `kind` is `TEXT` (the default: everything above), `VOICE` (a
  voice clip of at most 30 s) or `IMAGE` (a picture). VOICE and IMAGE send `mediaId` — the
  caller's own, unattached `LIVE_CHAT_VOICE` / `LIVE_CHAT_IMAGE` asset (§11.1) — and no `text`;
  they **vanish 60 s after sending** (§10.19). Details in §10.19.
- **Who may send:** signed-in callers who are in the room now: the host, or a caller with a
  row in the room's media session (§10.8; seated guests and moderators included). Guests
  without an account read only (owner D96). Order of checks: 401, 404 (cannot see the room,
  e.g. a block with the host), 409 `LIVE_ROOM_ENDED`, 400 text, 403 `LIVE_CHAT_NOT_IN_ROOM`,
  403 `LIVE_CHAT_MUTED`, 409 `LIVE_CHAT_CLOSED` (the host may still send), 429.
- **Idempotent retry:** `clientId` is unique per sender. The same sender and `clientId` → 200
  with the first message (even if the text differs), and no second data message.
- **`authorRole`:** `HOST`, `MODERATOR`, `SPEAKER` (seated) or `VIEWER`, as when it was sent.
- **Reading:** `GET /live/rooms/{roomId}/chat` returns the last 50 messages, oldest first,
  without deleted ones *(v1.19-live)* and without expired voice clips and images; anyone who may watch the room (guests need `allowGuests`); also on an
  ended room. A signed-in reader never gets messages from someone they blocked or who blocked
  them.
- **Live delivery** (topic `chat`, reliable, in send order, to everyone in the media room):

  | `type` | Payload | When |
  | ------ | ------- | ---- |
  | `chat` | `{"type":"chat","message":LiveChatMessage}` | a message was stored |
  | `chat-delete` | `{"type":"chat-delete","id":"…"}` | a message was deleted |
  | `join` | `{"type":"join","user":UserSummary}` | a signed-in viewer joined the media session (webhook or reconciliation, §10.8); the host and guests without an account are not announced; at most one a second per room, extras dropped (owner D96) |
  | `chat-state` | `{"type":"chat-state","enabled":true\|false}` | the host turned the chat on or off |

  The app hides `chat` and `join` lines from people the reader blocked (from `GET /me/blocks`).
  A broadcast cannot be filtered per reader: someone who blocked the reader may still appear
  to them live (never in `GET`). Unknown `type` values are ignored.
- **Delete:** the author, the host or a moderator; a moderator never deletes the host's or
  another moderator's message (403 `AUTH_FORBIDDEN`). Soft delete, idempotent (204); only while
  the room is live.
- **Chat mute:** the host or a moderator mutes a user for this live only (not a block; their
  earlier messages stay). Nobody mutes the host; a moderator never mutes another moderator
  (403 `AUTH_FORBIDDEN`). `LiveRoom.chatMuted` tells the caller. Idempotent.
- **Chat off:** `PATCH /live/rooms/{roomId}` `chatEnabled` (host only). `LiveRoom.chatEnabled`
  shows it; a new live starts with the chat on.
- **Reports:** `POST /reports` accepts `targetType: LIVE_CHAT_MESSAGE` (a message the reporter
  could read); §11.7 rules apply; `REMOVE_TARGET` deletes the message.
- **Retention (owner D96):** messages, mutes and deleted messages are removed 30 days after
  their room ended, by the live sweeper, except a message with an OPEN report, which stays
  until the report is closed.
- **Not in v1.9-live:** removing someone from the room (owner D96: a follow-up proposal;
  *arrived in v1.20-live, §10.20*), a
  word filter (owner D96: not now), gift lines (L3; *v1.23-live: gifts reach the room as the `gift`
  data message, §10.23, not as chat lines*), replies, reactions, stickers, images
  *(images and voice clips arrived in v1.19-live, §10.19)*.

### 10.12 Editing a live, the topic and the Contribution list *(v1.10-live, DRAFT — CP-014, D97)*

- **Editing while live:** `PATCH /live/rooms/{roomId}` (host only) also takes `title` (the
  go-live rules, §10.3), `categorySlug` (an **active** category, or `null` for none; else 400
  `categorySlug` / `invalid_value`) and `topic`. One category per room (owner D97).
- **Topic:** NFC, trimmed, 0–100 code points, one line (`U+000A`, `U+000D`, `U+2028`,
  `U+2029` → `invalid_format`), §6 text hygiene; `null` or `""` (after trimming) removes it.
  `LiveRoomSummary.topic` is the topic or `null`; the app shows it in the room and on hub cards
  (owner D97). A new live starts without a topic.
- **Reaching the room:** every change to `title`, `categorySlug` or `topic` increases the room's
  info version in the same transaction and writes `{"roomInfoVersion": n}` into the media room's
  metadata (next to `seatsVersion` and `score`); apps re-read `GET /live/rooms/{roomId}` when it
  moves. A `PATCH` that changes nothing does not move it. Edits are audited (`live.room.edit`).
- **Contribution list:** `GET /live/rooms/{roomId}/contributors` returns up to 50 people, by
  points given to this live, highest first; ties by who reached their total first, then user
  id. Points = counted taps (CP-012) plus, with L3, 100 a support coin *(v1.23-live: 100 for every
  coin of value of the gifts the person sent in this live, from coins or the bag, §10.23; ties by
  who reached their total first, a gift or a counted batch)*. People with 0 points and
  the host are never listed. Anyone who may watch reads it (guests need `allowGuests`); a
  signed-in reader never gets people they blocked or who blocked them; inactive accounts are
  left out. Also on an ended room. Public by owner decision (D97).
- *(v1.20-live, owner D105)* **One person's points:** `GET /live/rooms/{roomId}/contributors/{username}`
  → `{"user": UserSummary, "points": n, "rank": r}` for the "points" button on a person's card, for
  anyone (not only the top 50). `points` is computed exactly as in the list (0 when the person gave
  nothing; always 0 for the host); `rank` is their place among the people with points in the list
  as this reader sees it (same order and ties, same exclusions: inactive accounts and, for a
  signed-in reader, blocks either way), so ranks 1 … 50 match the list; `null` when `points` is 0.
  Same access as the list (guests need `allowGuests`; also on an ended room). A room the caller may
  not see, an unknown or inactive user, or one blocked either way with a signed-in reader → 404.
- **Not in v1.10-live:** room boost (CP-014 part C, after L3), several tags per room.

### 10.13 The live cover *(v1.11-live, DRAFT — CP-015, D98)*

- **One cover per host, reused by every live** (owner D98 Q1). The host uploads a `LIVE_COVER`
  photo (§11.1), then `PUT /me/live-cover {mediaId}` → 200 `{coverUrl}`. Order after auth and
  the rate limit: `MEDIA_UPLOADS_ENABLED` (503 `MEDIA_UPLOADS_UNAVAILABLE`) → the hosting
  permission (403 `LIVE_HOSTING_NOT_ALLOWED`) → body (strict) → the asset: a READY, unattached
  `LIVE_COVER` of the caller from the last 24 hours, else 400 `mediaId` / `invalid_value`.
  Setting the current cover again changes nothing.
- `DELETE /me/live-cover` → 204 removes it (idempotent; works while uploads are off). A replaced
  or removed cover's asset and objects are deleted.
- `Me.liveCoverUrl` is the cover (or `null`), so the go-live screen shows it before a room
  exists. A live copies the cover at go-live into `LiveRoomSummary.coverUrl`; a change while
  live updates the room's `coverUrl` and increases its info version (§10.12,
  `roomInfoVersion`), so viewers re-read the room. Both changes are audited
  (`live.cover.update`). Cards and the room show the host's avatar when `coverUrl` is `null`.
- **Safety:** the cover is public on the hub; a `LIVE_ROOM` report covers the room's picture.
  Removing a cover by moderation (back to the avatar) arrives with the moderation provider
  (B13); until then uploads stay behind `MEDIA_UPLOADS_ENABLED` and PP-28.


### 10.14 Blocked words *(v1.12-live, DRAFT — CP-016 B, D99)*

- A host keeps up to **100 blocked words or phrases** (`GET` / `PUT /me/live-blocked-words`; `PUT`
  replaces the list). Each is normalized like chat text: NFC, trimmed, one line, §6 hygiene, 1–30
  code points. No hosting permission → 403 `LIVE_HOSTING_NOT_ALLOWED`.
- **Matching form:** NFKC, lower case, Arabic diacritics and tatweel ignored, أ إ آ ٱ = ا,
  ى = ي, ة = ه. Duplicates by matching form are dropped (the first spelling kept).
- **Effect:** a chat message sent in any live of that host has each match masked — every
  character of it becomes `*` — **before** it is stored and sent (the original text is never
  kept). A word with Arabic letters matches inside a longer word (Arabic attaches ال، و، ب…);
  any other word matches only as a whole word ("ass" never masks "class"). Messages already sent
  are not changed. The host's own messages are masked too.
- `PUT` is audited (`live.blocked_words.update`) with the number of words only.

### 10.15 The popularity board *(v1.13-live, DRAFT — CP-016 A, D99)*

- `GET /live/rankings?period=HOUR|DAY|WEEK` (default `HOUR`): up to **50 hosts** ranked by the
  points their lives received in the **current** hour, day or week, highest first; ties by user
  id. One region for everyone (owner D99). Points are the same as the live score (CP-012: one
  counted tap = 1 point; support coins with L3 — *v1.23-live: 100 a coin of every gift sent in the
  host's live, to the host or to a seated guest, §10.23*), counted when they are given, whichever
  live they went to.
- **Windows:** the hour is the clock hour; the day starts at midnight and the week on Monday in
  the server's `LIVE_RANKINGS_TIME_ZONE` (an IANA zone, default UTC). `startsAt` / `endsAt` give
  the window (the app's countdown runs to `endsAt`); a new window starts empty.
- Only ACTIVE hosts with points; a signed-in reader never gets people they blocked or who blocked
  them. `liveRoom` is the host's live now (cards show LIVE and open it), else null. Guests may
  read the board.
- `me` (signed-in hosts only): the caller's exact rank among all hosts (null with 0 points) and
  points, for the row pinned at the bottom.
- Storage: points per host per UTC hour, written in the same transaction as the taps; rows older
  than 15 days are removed by the live sweeper. Rich (spenders) and regional boards wait (L3, a
  host country).

### 10.16 Live schedule *(v1.14-live, DRAFT — CP-016 C, D99)*

- A host announces upcoming lives (`GET` / `POST /me/live-schedule`, `DELETE
  /me/live-schedule/{slotId}`): a **title** (normalized like a live title: NFC, trimmed, one line,
  §6 hygiene, 1–60 code points) and a **start time** at least **15 minutes** and at most **30
  days** ahead (else 400 `startsAt` / `too_small` or `too_big`). At most **10 upcoming** slots (409
  `LIVE_SCHEDULE_FULL`). No hosting permission → 403 `LIVE_HOSTING_NOT_ALLOWED`. `GET` lists the
  upcoming slots (start still ahead), soonest first. `DELETE` of a slot that is not the caller's
  → 404 `NOT_FOUND`. Create and delete are audited (`live.schedule.create` / `.delete`).
- **Reminder:** **15 minutes** before the start the live sweeper sends `LIVE_SCHEDULED_SOON` to
  the host's followers, once per slot: actor the host, target `USER` (the host's username, the slot's
  title as `text`, and `startsAt`; tapping opens the host's profile). The usual rules apply (§11.10: ACTIVE, no block either way, not
  muted by the follower) and the follower's `lives` setting. A slot deleted after its reminder
  takes the reminder away. Going live is not tied to a slot: the host goes live as usual.
- Retention: slots are deleted 30 days after their start (with their reminders).

### 10.17 Room number *(v1.15-live, DRAFT — CP-016 G, D99)*

- Every host has a **public room number**: 9 digits (100000000–999999999), random, unique, given
  when the hosting permission is granted and kept for every live of that host (the room bar shows
  "ID: …"). `LiveRoom.roomNumber` carries it; null when the host no longer has the permission.
  Revoking the permission drops the number; a new grant gives a new one.
- It is an identifier for people to quote (support, reports), not a secret, and never replaces
  the room or user ids in the API.
### 10.18 Room level *(v1.17-live, DRAFT — CP-016 D, D101)*

- **The room level is the host's charm level:** the host's `ATTRACTIVENESS` level (CP-005,
  §9), the same in every live of that host, and it keeps growing from live to live (the live
  score, §10.10, starts at 0 in every live). `LiveRoom.roomLevel` carries it; null while the
  charm category is not available (disabled or no published version, CP-005 §4).
- **Taps give charm points (owner D101):** every 10 taps of one viewer that count in one live
  (§10.10) give the host 1 charm point, in the same transaction as the score. They go through
  the CP-005 ledger as `EARN` entries with source `LIVE_TAPS` (no multiplier: the rate is fixed
  here); the host's level follows the published ladder. Nothing is credited while the category
  is unavailable, and taps lost that way are not credited later.
- **Limit (owner D101):** **10 000 taps per viewer in each live** — the counting limit of §10.10.
  One viewer therefore gives a host at most 1 000 charm points per live; there is no daily cap
  across lives. The host's own taps give nothing (they count 0, §10.10).
- **Gifts** (L3) add charm points by the CP-005 rules (`GIFT_RECEIVED`); *built in v1.23-live
  (§10.23): when the host receives a gift, their charm level (the room level) may move, and the
  room's info version goes up as for taps.*
- **Live updates:** when a tap batch changes the host's level, the room's info version goes up
  (§10.12), so apps read the room again and show the new level.
- Apps draw the level with the owner's ten charm tiers (levels 1–10, 11–20 … 91–100); a level
  above 100 uses the last tier.

### 10.19 Coins, bullet messages, voice clips and images *(v1.19-live, DRAFT — CP-017, D104)*

- **Coins (owner D104, minimal):** every user has a coin balance, a whole number ≥ 0 (0 until
  the first grant; §3: exact as a JSON number, at most 2^53 − 1). `GET /wallet/me` → `{"coins": n}`
  (signed in). Every change is a ledger row (`wallet_ledger`: user, delta, reason `ADMIN_GRANT`,
  `ADMIN_REVOKE` or `BULLET_MESSAGE` — *v1.21-live adds the family and CP reasons, v1.23-live
  `LIVE_GIFT`* — reference, time) written in the same transaction; one row per
  reason and reference, so a bullet is never charged twice. **No purchases** (B5 still blocks
  them): coins come only from an admin on the server with the `wallet-admin` tool
  (`grant <email> <coins>`, `revoke <email> <coins>`, `balance <email>`; positive whole numbers; a
  revoke never goes below 0; every grant and revoke is audited; docs/DEPLOYMENT.md §5.4). No API
  grants coins.
- **Bullet message (رسالة عامة):** `POST /live/rooms/{roomId}/bullets` with `{text, clientId}`
  sends a line that is shown in **every live** — audio and video, not only the sender's. It costs
  **15 coins** (`LIVE_BULLET_COST_COINS`). `text`: the chat text rules (§10.11) with **1–60 code
  points**; the origin host's blocked words are masked (§10.14). Who may send: like the chat — a
  signed-in caller who is in that LIVE room now (the host, or in its media session); being muted in
  that live's chat refuses it too; the chat switch does not. Order of checks: 401, 404 (cannot see
  the room), 409 `LIVE_ROOM_ENDED`, 400 body, a retry (below), 403 `LIVE_CHAT_NOT_IN_ROOM`, 403
  `LIVE_CHAT_MUTED`, 429 (one bullet every 5 s per user, across lives), then the charge: a balance
  under 15 → 409 `INSUFFICIENT_COINS` and nothing is stored, charged or sent. The bullet and the
  charge are one transaction.
- **Response:** 201 `{"bullet": LiveBullet, "coins": <balance after>}`. **Idempotent retry:**
  `clientId` is unique per sender and plays the role of the §3 `Idempotency-Key` for this
  financial request (no header): the same sender and `clientId` → 200 with the first bullet and the
  current balance, nothing charged or sent again (even if the text differs).
- **Delivery:** after the response the server sends the bullet to every LIVE room as a reliable
  data message on topic **`bullet`** (best effort per room, like every data message):

  | `type` | Payload |
  | ------ | ------- |
  | `bullet` | `{"type":"bullet","bullet":{"id","text","sender":UserSummary,"roomId":<origin live>,"createdAt"}}` |

  Apps show it over the live (a floating line) with the sender, and may link to the origin live
  (`roomId`). A bullet is a broadcast to everyone: the app hides bullets from people the reader
  blocked (`GET /me/blocks`). Bullets are not part of the chat and are not returned by any read.
- **Voice clips and images in the chat:** the app uploads with `POST /media/uploads`
  (`kind: LIVE_CHAT_VOICE`, `contentType: audio/mp4`, at most 1 MiB; or `kind: LIVE_CHAT_IMAGE`, an
  image type as for posts), PUTs the bytes, completes the upload (§11.1), then sends
  `{"kind":"VOICE"|"IMAGE","mediaId":…,"clientId":…}` to `POST /live/rooms/{roomId}/chat` (the
  §10.11 checks and limits apply; an asset that is not the caller's unattached asset of that kind →
  400 `mediaId` / `invalid_value`, after the counting rule). A voice clip is at most **30 s**: the
  server reads the length from the file when the upload completes and refuses a longer one (422
  `MEDIA_INVALID`); `media.durationMs` carries it.
- **They vanish after 60 s (owner D104):** a VOICE or IMAGE message carries `expiresAt` = sent +
  60 s, also in its `chat` data message. Apps hide it at `expiresAt` (server time; apps without a
  synced clock may hide it 60 s after receiving it). From then on `GET …/chat` does not return it,
  it cannot be reported, and the live sweeper deletes its asset and the stored objects (within one
  sweep interval, 15 s by default); its `media` is null if it is read before the sweep. TEXT
  messages keep §10.11 retention and `expiresAt: null`.
- **Not in v1.19-live:** buying coins (B5), a coin history for users, gifts (L3), sending coins to
  other users, captions on images, video clips.

### 10.20 Kicking someone out of a live *(v1.20-live, DRAFT — D105)*

- **Who (owner D105):** the host and the room's moderators (§10.9), in every live (audio and
  video; `SOLO`, `MULTI` and `AUDIO`). Nobody kicks the host or themselves; a moderator never
  kicks another moderator (403 `AUTH_FORBIDDEN`). The host may kick a moderator. Guests without
  an account have no username and cannot be kicked (the host can switch guests off, §10.8).
- **Kick:** `POST /live/rooms/{roomId}/kicks` with `{"username": …}` → 201 `{"user": UserSummary,
  "kickedAt": …}`; someone already kicked from this live → 200 with the first kick (nothing sent or
  audited again). Order of checks: 401, 404 (cannot see the room), 409 `LIVE_ROOM_ENDED`, 400
  body, 403 (caller not host or moderator), 404 (unknown or inactive user; a malformed username
  too), 403 (the target is protected, above). The person need not be in the room now.
- **What happens, in one transaction:** a `live_room_kicks` row (room, user, by, time; one per room
  and user), the person loses their seat, pending seat request and invitation and their moderator
  role in this room (the seat version moves, §10.9), their media-session row is dropped (the
  viewer count follows), and the audit log gets `live.kick` (target the user, metadata the room).
  Then, best effort: the room gets the data message below, and the person is **removed from the
  media session** at once (LiveKit remove participant).
- **Until the live ends:** for a kicked user, `createLiveMediaToken` → 403 `LIVE_KICKED`, a media
  session join (a token issued earlier) is refused and disconnected at once, and chat messages,
  bullet messages, taps and seat requests in this live → 403 `LIVE_KICKED` (checked after 409
  `LIVE_ROOM_ENDED`, and in the chat and bullets after the body and the `clientId` retry, before
  `LIVE_CHAT_NOT_IN_ROOM`). The host cannot appoint a kicked user as a moderator (422
  `VALIDATION_FAILED`, `username` / `invalid_value`). Reading (room detail, chat, seats,
  contributors) stays open like for anyone who may see the room; `LiveRoom.kicked` is true for
  them. A kick belongs to one live: a new live of the same host starts with nobody kicked.
- **Data message** (topic **`kick`**, reliable, to everyone in the media room, sent before the
  removal):

  | `type` | Payload |
  | ------ | ------- |
  | `kick` | `{"type":"kick","user":UserSummary,"by":UserSummary,"at":"…"}` |

  The kicked person's app leaves the room and shows a message; others drop the person from their
  lists. The removal may arrive first (LiveKit disconnects with reason "participant removed"), so
  the app also treats that disconnect, `LiveRoom.kicked` and 403 `LIVE_KICKED` as the same signal.
- **List and undo (host or moderator):** `GET /live/rooms/{roomId}/kicks` → the kicked users, newest
  first (ACTIVE only; also on an ended room). `DELETE /live/rooms/{roomId}/kicks/{username}` → 204
  lets them back in (a new media token works; seat and roles are not given back); not kicked →
  204; only while the room is live (409 `LIVE_ROOM_ENDED`); audited (`live.kick.undo`) when a kick
  was removed.
- **Rate limits:** kick and undo count in the CP-011 host and moderator bucket (§7).
- **Retention:** kicks are removed with the chat mutes, 30 days after their room ended (§10.11).

### 10.21 Families, CP couples and medals *(v1.21-live, DRAFT — CP-018, D106)*

Owner decisions (D106, 2026-10-26) are marked *(owner)*; every other number is a CTO default the
owner may change (a named constant in the API: `families.constants.ts`, `couples.constants.ts`,
`medals.catalogue.ts`). Every route needs a token. Money follows §3: integer coins, every change a
`wallet_ledger` row in the same transaction as what it pays for, a `clientId` (unique per caller)
in place of the `Idempotency-Key` header, the ledger append-only.

**Families (العائلة).**
- **Create** `POST /families` `{name, emblemMediaId?, clientId}` → 201 `{family, coins}`; a retry
  with the same `clientId` → 200 with that family and the current balance (409
  `IDEMPOTENCY_CONFLICT` when it was disbanded since). Costs **500 coins** *(owner)* (ledger
  `FAMILY_CREATE`, reference the family id); the caller becomes its **LEADER**. Order: 400 body →
  retry → 503 `MEDIA_UPLOADS_UNAVAILABLE` (an emblem while uploads are off) → 409
  `ALREADY_IN_FAMILY` → 400 `emblemMediaId` / `invalid_value` → 409 `FAMILY_NAME_TAKEN` → 409
  `INSUFFICIENT_COINS` (nothing created or charged). A pending join request of the creator is
  cancelled.
- **Name:** the display-name text rules (§6: NFC, trimmed, text hygiene, joiners, zalgo, a letter,
  digit or emoji, no mixed-script word, no reserved term) with **2–20 grapheme clusters**, at most
  40 code points; unique among families that are not disbanded, compared after NFKC and lower
  case. **Emblem** (optional): a `FAMILY_EMBLEM` upload (§11.1), set at create or by the leader
  with `PATCH /families/{familyId}` `{emblemMediaId | null}`; `emblemUrl` (640 px) or null.
- **Number:** a random public **8-digit** family number (`number`), unique, like the room number
  (§10.17); `GET /family-numbers/{number}` finds a family by it.
- **Members:** at most **500** *(owner)*, the leader included; a user is in **at most one** family
  *(owner)*. Roles `LEADER` (one), `DEPUTY`, `MEMBER`. `GET /families/{familyId}/members` → the
  leader, then deputies, then members, each by join time (ACTIVE accounts; paged).
- **Joining by request** *(owner)*: `POST /families/{familyId}/join-requests` → 201 (200 when the
  caller already asked this family). Order: 404 → 409 `ALREADY_IN_FAMILY` → retry 200 → 409
  `FAMILY_REQUEST_PENDING` (one pending request at a time) → 403 `AUTH_FORBIDDEN` (a block either
  way between the caller and the leader) → 409 `FAMILY_FULL`. Requests **expire after 7 days**
  *(owner)* (read as `EXPIRED`; a sweeper closes them, `BONDS_SWEEP_INTERVAL_SECONDS`). The
  caller reads and cancels their own with `GET` / `DELETE /me/family-join-request` (cancel is
  idempotent). The leader and deputies list pending ones (`GET …/join-requests`, oldest first;
  403 for anyone else) and answer: `POST …/join-requests/{requestId}/accept` → 200 `FamilyMember`
  (order: 404 family → 403 → 404 request → 409 `FAMILY_REQUEST_NOT_PENDING` → 409
  `ALREADY_IN_FAMILY` (the requester joined elsewhere; the request is closed) → 409
  `FAMILY_FULL`) or `…/decline` → 204. The requester gets `FAMILY_JOIN_ACCEPTED` /
  `FAMILY_JOIN_DECLINED` (§11.10).
- **Roles and leaving** *(owner)*: the leader makes a member a deputy or back
  (`PUT …/members/{username}/role {role: DEPUTY|MEMBER}`), removes a deputy or member
  (`DELETE …/members/{username}`, audited `family.member.remove`) and hands the family over
  (`POST …/transfer {username}`: the member becomes LEADER, the old leader DEPUTY; audited
  `family.transfer`). Only the leader does these (403 `AUTH_FORBIDDEN`); the target must be a
  member (404), not the leader themselves (400 `username` / `invalid_value`). Members and deputies
  leave (`POST …/leave` → 204); the leader cannot (409 `FAMILY_LEADER_CANNOT_LEAVE`). The leader
  **disbands** a family that has only them (`DELETE /families/{familyId}` → 204; others → 409
  `FAMILY_NOT_EMPTY`): pending requests are cancelled, the name becomes free, the emblem is
  deleted, no coins come back; audited `family.disband`.
- **Family level** *(owner: points from members' spending)*: every coin a member spends in the app
  **while in the family** is 1 family point: bullet messages, creating the family, CP gifts, and a
  CP request once it is **accepted** (until then its coins may come back). Admin revokes and
  refunds never count. Points are written with the debit (`family_points_ledger`, one row per
  ledger row) and stay with the family when the member leaves. Ladder (CTO default): level 1 at
  0, 2 at 1 000, 3 at 5 000, 4 at 20 000, 5 at 50 000, 6 at 100 000, 7 at 200 000, 8 at 500 000,
  9 at 1 000 000, 10 at 2 000 000 (`GET /families/config`). `Family.points`, `level`,
  `nextLevelPoints`; `FamilyMember.points` is what that member gave.
- **Reads:** `GET /families?q=` (by points, highest first; `q` a name fragment, or digits that
  also match the number; paged), `GET /families/{familyId}` (with `myRole` and `myRequestId`),
  `GET /families/me` → `{family | null}`, `GET /families/config`.

**CP couples (العلاقة).**
- **Request** `POST /cp/requests {username, clientId}` → 201 `{request, coins}`; a retry with the
  same `clientId` → 200 (nothing charged again). Costs **99 coins** *(owner)*, taken at send
  (ledger `CP_REQUEST`, reference the request id) and **given back** (`CP_REFUND`, same reference)
  when it is declined, cancelled or **expires after 7 days** *(owner)* (by the sweeper, or at the
  next action on it). Order: 400 body → retry → 404 (unknown or inactive user, **or a block either
  way**) → 400 `username` / `invalid_value` (oneself) → 409 `CP_ALREADY_PAIRED` (either has a
  partner) → 409 `CP_REQUEST_PENDING` (one outgoing pending request at a time *(owner)*) → 409
  `INSUFFICIENT_COINS`. The receiver gets `CP_REQUEST`.
- `GET /cp/requests?direction=incoming|outgoing` (pending, newest first; incoming hides senders who
  are not ACTIVE or are blocked either way). The sender cancels (`DELETE /cp/requests/{id}` →
  204); the receiver declines (`POST …/decline` → 204) or **accepts** (`POST …/accept` → 200
  `CpCouple`). Not pending → 409 `CP_REQUEST_NOT_PENDING`. Accepting checks the block and the
  sender's account again (either fails → the request is closed and refunded, 409
  `CP_REQUEST_NOT_PENDING`), then 409 `CP_ALREADY_PAIRED`; it forms the couple (`since` now), closes
  and refunds every other pending request of either partner, counts the 99 coins for the
  sender's family, and the sender gets `CP_ACCEPTED`. **One partner per user** *(owner)*.
- **The couple:** `GET /cp/me` → `{cp | null}`, `CpCouple` = `{id, partner, since, days, points,
  level, levelName, nextLevelName, pointsToNext}` (`days`: the day it was formed is day 1).
  **Ending** *(owner)*: either partner, `DELETE /cp/me` → 204 (no refund; no partner → 204 too).
- **CP gifts** *(owner)*: `POST /cp/me/gifts {amount, clientId}` → 201 `{gift, cp, coins}` (retry →
  200). `amount` one of **10, 52, 99, 520, 1314** coins (CTO default); ledger `CP_GIFT` (counts for
  the sender's family); the couple gains `amount` CP points. Order: 400 → retry → 409
  `CP_NOT_PAIRED` → 409 `INSUFFICIENT_COINS`. The partner receives no coins.
- **Tiers** (CTO default; names localized by `Accept-Language`, else the caller's locale):
  1 ثنائي متحمّس / Eager couple (0), 2 ثنائي فضّي / Silver couple (520), 3 ثنائي ذهبي / Gold
  couple (1 314), 4 ثنائي ماسي / Diamond couple (5 200), 5 ثنائي أسطوري / Legendary couple
  (13 140). `GET /cp/config` → price, lifetime, gift amounts and tiers.

**Medals (الميداليات)** *(owner: automatic achievements)*.
- The catalogue (`medals`, seeded by migration): `FIRST_LIVE` (first live hosted, awarded when it
  ends), `LIVE_HOURS_10`, `LIVE_HOURS_100` (hours of all ended lives hosted, `ended_at −
  started_at`), `CHARM_10`, `CHARM_50`, `CHARM_100` (charm level reached, CP-005
  `ATTRACTIVENESS`), `FIRST_FAMILY` (created or joined a family), `FIRST_CP` (formed a couple),
  `BULLET_FIRST` (sent a first bullet message). Each has Arabic and English names and
  descriptions, an `iconKey` for the app and a sort order. *Not built:* `STREAK_7` / `STREAK_30`
  (no record of active days exists to derive them cheaply; a later change).
- **Awarding** is automatic, in the same transaction as the event (every path that ends a live,
  a charm level change, a family create or accepted join, an accepted CP request, a bullet), once
  per user and medal (awarding again does nothing), with a `MEDAL_AWARDED` notification. Past
  events: `medals-admin backfill [--notify]` (server CLI, idempotent; without `--notify` no
  notifications; docs/DEPLOYMENT.md).
- **Showcase** *(owner, D106 amendment)*: a user chooses up to **6** of their unlocked medals to
  show on their profile, in order: `PUT /me/medals/showcase {medalCodes: [...]}` → 200
  `{showcase: [{code, name, iconKey}]}` (replaces the choice; `[]` shows none). 400: more than 6
  (`too_big`) or a code twice (`invalid_value`); 409 `MEDAL_NOT_UNLOCKED`: a code the caller has
  not earned. `GET /me/medals/showcase` reads it; `PublicProfile.medals.showcase` shows it. Never
  chosen → empty (no auto-fill).
- `GET /medals` → `{data, total, owned}` (catalogue order, each with the caller's `awardedAt` or
  null); `GET /users/{username}/medals` → `{data, owned, total}` (newest first, `awardedAt`; 404
  like the profile).

**Not in v1.21-live:** buying coins (B5), family chat or family live rooms, family tasks or
rankings beyond `GET /families`, CP gifts that give the partner coins or charm points, streak
medals, removing a deleted or suspended account from its family or couple (they are left out of
member lists and `cp` on profiles; a suspended leader's family keeps its leader until an admin
tool exists).

### 10.22 The bag *(v1.22-live, DRAFT — CP-019, D107)*

Owner decisions (D107, 2026-10-26) are marked *(owner)*; every other choice is a CTO default the
owner may change. Every route needs a token. Names follow `Accept-Language`, else the caller's
locale (§10.1).

- **The bag (الحقيبة)** *(owner)*: every user has one. Items belong to a **category**; the first
  is `PROFILE_CARD`, the decoration on the header of the user's profile card. More categories come
  later as new `BagCategory` values (clients ignore items of categories they do not know).
- **Catalogue** (`bag_items`, seeded by migration; `bag.catalogue.ts` keeps the same list)
  *(owner)*: `bunny_royal` الأرنب الملكي / Royal Bunny (**free**), `kabi_royal` كابي الملكي /
  Royal Kabi, `golden_stags` الغزلان الذهبية / Golden Stags, `emerald_wings` الأجنحة الزمردية /
  Emerald Wings. Each has an `assetKey` for the app (`header_<code>`: the profile-card header
  animation `assets/profile_card/<assetKey>.svga`) and a sort order. `GET /bag/catalogue
  [?category=]` → `{data: [{code, category, name, assetKey, sortOrder, free}]}`, by category then
  sort order, whole (not paged).
- **Getting items:** a **free** item is given to **every new account** when it is created, in the
  same transaction (source `FREE_SIGNUP`), and worn (the first free item of each category)
  *(owner)*. Accounts that existed before the bag received it once from the migration (source
  `BACKFILL`, worn: they never chose to take it off) *(owner, D107)*. The other items are owned by
  nobody until granted: for now only an admin on the server grants or takes them back
  (`bag-admin grant|revoke <email> <code>`, `bag-admin list <email>`; source `ADMIN`; audited
  `bag.grant` / `bag.revoke`); a store or rewards come later (new `BagItemSource` values).
  Granting never changes what the user wears *(owner)*. Taking back a worn item leaves the user
  wearing nothing in that category.
- **The caller's bag:** `GET /me/bag[?category=]` → `{data: [{code, category, name, assetKey,
  acquiredAt, source, equipped}]}` in catalogue order; at most one item per category has
  `equipped: true` *(owner)*.
- **Wearing** *(owner)*: `PUT /me/bag/equipped {category, code}` → 200 `{category, equipped:
  {code, name, assetKey} | null}`. `code` wears that item and takes off the one worn before in the
  category; `code: null` takes it off. Idempotent. **Wearing nothing stays so:** the server never
  puts an item back on by itself (not at login, not when an item is granted) *(owner: "worn
  automatically unless the person took it off")*. Only an owned item can be worn: 409
  `BAG_ITEM_NOT_OWNED` otherwise (an unknown code too; nothing changes). 400 `VALIDATION_FAILED`:
  `code` missing (`required`; send `code: null` to take off), `category` missing or unknown
  (`invalid_value`), a `code` that is empty or over 40 characters, or an unknown field.
- **On the profile:** `PublicProfile.profileCard` = `{code, assetKey}` of the worn
  `PROFILE_CARD`, or null (§10.5).

**Not in v1.22-live:** buying or earning items (store, rewards, events), items that expire, other
categories (avatar frames, entrance effects, chat bubbles…), a history of grants other than the
audit log, and `Me` carrying the worn items (the app reads its own profile, or `GET /me/bag`).

### 10.23 Live gifts *(v1.23-live, DRAFT — CP-020, D108)*

Owner decisions (2026-10-26) are marked *(owner)*; every other number is a CTO default the owner
may change (D108). Every route needs a token. Names follow `Accept-Language`, else the caller's
locale (§10.1).

- **Catalogue** *(owner)*: gifts are managed by an admin on the server only, with the `gift-admin`
  CLI (no app or API writes it): `add <code> --category --name-ar --name-en --price --asset
  [--animation] [--sort] [--badge]`, `update <code> …` (`--animation none` removes the effect),
  `disable` / `enable <code>`, `list`; every change is audited (`gift.add`, `gift.update`,
  `gift.disable`, `gift.enable`). A gift has a `code` (`^[a-z0-9][a-z0-9_]{0,39}$`, never reused:
  gifts are disabled, not deleted), Arabic and English names (1–60), a `category` — the panel tabs
  `POPULAR` (شائعة), `EVENT` (مناسبات), `FUN` (مرح); the fourth tab, الحقيبة, is the gift bag below
  — a price of 1 … 1 000 000 coins, an `assetKey` (the app's static image) and an optional
  `animationKey` (the app's SVGA / full-screen effect; null: none), a `sortOrder` and a `badge`
  `NONE`, `NEW` or `EVENT`. Keys are plain strings the app maps to its bundled files
  (`[A-Za-z0-9][A-Za-z0-9_./-]{0,79}`). **The catalogue starts empty** *(owner: the art comes
  later)*; an empty catalogue is valid and the app shows empty tabs.
- **`GET /gifts/catalogue`** → `{version, categories, quantities, maxRecipients,
  comboWindowSeconds, data: [Gift]}`: the **enabled** gifts by tab (in `categories` order), then
  `sortOrder`, then `code`, whole (not paged). `Gift` = `{code, category, name, priceCoins,
  assetKey, animationKey, sortOrder, badge}`. `version` (16 hex characters) changes whenever
  anything in the response except `name`'s language changes; the app caches the catalogue per
  language and `version` and redraws the panel only when it moves (responses stay `no-store`, §1).
  `quantities` are the quantities a send may use (server config `LIVE_GIFT_QUANTITIES`, default
  **1, 10, 66, 99, 188, 520, 1314**) *(owner)*; `maxRecipients` is **25** (the host and 24 seats);
  `comboWindowSeconds` is **5**. Clients ignore gifts of a category they do not know.
- **The gift bag (الحقيبة)** *(owner)*: gifts a user owns and sends without coins
  (`user_gift_stock`: user, gift, quantity ≥ 0). For now only an admin adds to it: `gift-admin grant
  <email> <code> <quantity>` (1 … 10^9; a user holds at most 10^9 of one gift; audited `gift.grant`);
  `gift-admin bag <email>` lists it. `GET /me/gifts/bag` → `{data: [GiftBagItem]}` = every `Gift`
  field plus `quantity`, for the **enabled** gifts the caller holds at least one of, in catalogue
  order. A disabled gift stays in the stock but is not listed and cannot be sent until it is enabled
  again. The CP-019 bag (§10.22) is a different thing: wearable items, one of each.
- **Sending** *(owner)*: `POST /live/rooms/{roomId}/gifts` with `{giftCode, quantity, recipients,
  source, clientId}`. `quantity` is one of `quantities` (else 400 `quantity` / `invalid_value`);
  `recipients` are 1 … 25 distinct usernames: **the host and/or people seated in that room now**
  (§10.9; audio and video, every mode — a SOLO room has only the host); `source` is `COINS` or
  `BAG`; `clientId` a UUID. Each recipient receives `quantity` of the gift.
  - **COINS:** the price is `priceCoins × quantity × recipients`, taken from the wallet in one
    conditional debit (never below 0), one ledger row with reason **`LIVE_GIFT`** and the send as
    reference; it counts for the sender's family like other spending (§10.21).
  - **BAG:** takes `quantity × recipients` of that gift from the sender's bag (never below 0); no
    coins move and nothing counts for the family.
  - **Who:** a signed-in caller in that LIVE room now (the host, or a row in its media session,
    §10.8), not kicked out of it (§10.20). Being muted in the chat or the chat being off does not
    stop gifts. Nobody sends a gift to themself; the host sends only to seated people.
  - **Order of checks:** 401, 404 (cannot see the room, e.g. a block with the host), 409
    `LIVE_ROOM_ENDED`, 400 body, a retry (below), 403 `LIVE_KICKED`, 403 `LIVE_CHAT_NOT_IN_ROOM`,
    400 `recipients` / `invalid_value` (the caller is among them), 409 `GIFT_UNAVAILABLE` (unknown
    or disabled code), 409 `LIVE_GIFT_RECIPIENT_UNAVAILABLE` (a username without an ACTIVE account,
    a recipient who is neither the host nor seated now, or a block either way between the sender
    and a recipient), then the charge: 409 `INSUFFICIENT_COINS` (COINS) or 409
    `GIFT_BAG_INSUFFICIENT` (BAG). Any refusal stores, charges and sends nothing. 429 comes from the
    bucket (§7) before all of these.
  - **Response:** 201 `{"gift": LiveGift, "coins": <balance after>, "bagQuantity": <what the bag
    holds of that gift after>}` (both for either source). **Idempotent retry:** `clientId` is unique
    per sender and plays the role of the §3 `Idempotency-Key` (no header): the same sender and
    `clientId` → 200 with the first send and the current balance and bag quantity; nothing is
    charged, taken, credited or sent again (even if the body differs).
  - **`LiveGift`** = `{id, roomId, giftCode, assetKey, animationKey, unitPrice, quantity, source,
    totalCoins, sender: UserSummary, recipients: [UserSummary] (in the order sent), combo: {id,
    count, quantity}, createdAt}`. `unitPrice` is the price when it was sent; `totalCoins` =
    `unitPrice × quantity × recipients` (the value, also for BAG). No `name`: one message serves
    every language, the app takes the name from its catalogue by `giftCode`.
  - **Combos:** a send continues the sender's combo when their previous send **in the same live**
    was the same gift to the same recipients (in any order) at most `comboWindowSeconds` (5 s)
    before; otherwise it starts one. `combo.id` is the first send's id, `combo.count` 1, 2, 3 … and
    `combo.quantity` the gifts per recipient in the combo so far. Sends of one sender are processed
    one at a time, so counts never repeat. Apps show "×count" and restart the effect per send.
- **Effects, in the send's transaction** (all from the coin value, the same for COINS and BAG):
  - **Live score** (§10.10): `supportPoints` and `total` grow by **100 × `totalCoins`**, for gifts
    to the host and to seated guests alike; the score metadata follows (at most every 2 s).
  - **Popularity board** (§10.15): the host's points in the current hour grow by the same amount.
  - **Contribution list** (§10.12): the sender's points in this live grow by **100 ×
    `totalCoins`** (also when they never tapped). The host is never listed (their own gifts to
    seated guests count for the room score only).
  - **Levels** (CP-005, §10.18): per recipient, a normal (not lucky) gift worth `unitPrice ×
    quantity` coins: the recipient earns **charm** (`ATTRACTIVENESS`, source `GIFT_RECEIVED`) and the
    sender **support** (`SUPPORT`, source `GIFT_SENT`), each `floor(coins × the published version's
    multiplier)` points (the owner's ladder: 0.1, 1 point per 10 coins); nothing while a category is
    unavailable, and a share that rounds to 0 earns nothing. When the host's charm level moves, the
    room's info version goes up (§10.12). Charm medals follow (§10.21).
- **Delivery:** after the response the server sends the send to everyone in that live's media room
  as a reliable data message on topic **`gift`** (best effort, like every data message):

  | `type` | Payload |
  | ------ | ------- |
  | `gift` | `{"type":"gift","gift":LiveGift}` |

  Every viewer plays the effect (`animationKey`, else the image) with the sender, the recipients,
  the quantity and the combo count. A send is a broadcast: the app may hide sends from people the
  reader blocked (`GET /me/blocks`). Gifts are not chat lines (§10.11) and no read lists them yet.
- **Rate limit:** 120 sends / min per user (§7); there is no other counting rule.

**Not in v1.23-live:** buying gifts or coins (B5), lucky gifts and their winnings (`LUCKY_GIFT_SENT`,
`WIZARD`), refunds and reversals, a received-gifts wall or history, gifts as chat lines, a
spenders (rich) board, gifts outside a live, an admin UI, bag gifts that expire.

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
- *(CP-015)* `LIVE_COVER` uploads follow the same checks; both variants are centre-cropped
  squares, never enlarged: `media/{mediaId}/640.webp` (at most 640 × 640) and `320.webp`. They
  attach only as the host's live cover (§10.13).
- *(v1.21-live, CP-018)* `FAMILY_EMBLEM` uploads are processed like `LIVE_COVER` (centre-cropped
  squares, 640 and 320 px) and attach only as a family's emblem (§10.21).
- *(v1.19-live, CP-017)* `LIVE_CHAT_IMAGE` uploads follow the same checks and sizes as
  `POST_IMAGE` and attach only to a live chat message. `LIVE_CHAT_VOICE` uploads are voice clips:
  `audio/mp4` (AAC in an MPEG-4 container, `.m4a`), at most 1 MiB (else 400 `byteSize` /
  `too_big`; an image type for this kind, or `audio/mp4` for another kind → 400 `contentType` /
  `invalid_value`). Completing checks the container — an `ftyp` box first, the movie length from
  `moov/mvhd`, every track a sound track — and refuses a clip longer than 30 s (up to 30.5 s of
  encoder padding is accepted and reported as 30 000 ms) with 422 `MEDIA_INVALID`; the audio is
  not decoded or re-encoded. The bytes are stored unchanged as `media/{mediaId}/voice.m4a`
  (`audio/mp4`). The asset is `type: AUDIO`, `width`/`height` 0, `blurhash` null, `thumbUrl` =
  `url`, plus `durationMs`. Both kinds attach only to a live chat message and are deleted 60 s
  after it was sent (§10.19).
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
  the caller's feeds and stories tray, and (CP-009) it cannot notify the caller; profile, search and direct links still work. The caller sees their mutes in
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
| `GET /notifications`, `GET /notifications/unread-count` *(CP-009)* | one bucket: 300 / 15 min |
| `POST /notifications/read` *(CP-009)* | 120 / hour |

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

### 11.10 Notifications *(CP-009, D92 — CP-006 M4, in-app only)*

- Types and targets: `LIKE_POST` (post), `LIKE_COMMENT` (comment), `COMMENT` on your post and
  `REPLY` to your comment (the comment), `MENTION` in a post, comment or story (that item, only
  when `whoCanMention` allowed it), `FOLLOW` (the follower), `REPOST` (post), and the system types
  `POST_PUBLISHED` (your scheduled post went live) and `CONTENT_REMOVED` (moderation removed your
  post, comment or story). Notifications are written in the same transaction as their action.
  *(v1.14-live, CP-016 C)* `LIVE_SCHEDULED_SOON`: a host you follow goes live in about 15
  minutes (target the host as `USER` with the title and `startsAt`, §10.16; setting `lives`).
  *(v1.21-live, CP-018, §10.21)* `CP_REQUEST` (someone sent you a CP request) and `CP_ACCEPTED`
  (your CP request was accepted): target the other person as `USER`; `FAMILY_JOIN_ACCEPTED` and
  `FAMILY_JOIN_DECLINED`: target `FAMILY` (the family id, its name as `text`), actor the leader or
  deputy who answered; `MEDAL_AWARDED` (system, no actor, always on): target `MEDAL` (the medal
  code as `id`, `text` null; the app reads name and icon from `GET /medals`). No setting switches
  these off.
- **Never yourself**; never between two users with a block in either direction (existing ones
  are hidden while it lasts); never from an account the recipient muted (owner, D92); actors no
  longer ACTIVE are left out of `actors` and `actorCount`, and a group left with no visible actor
  is hidden.
- **Grouping (owner, D92):** `LIKE_POST`, `LIKE_COMMENT` and `REPOST` on the same target join one
  **unread** notification (up to 3 recent `actors`, `actorCount` all); each new actor moves it to
  the top. A read group is closed: the next one starts a new group. Other types never group.
- **Undo:** unlike, un-repost, unfollow, deleting the comment and deleting or removing the target
  take that contribution away; a notification left with no actor is deleted.
- **Settings** (`/me/notification-settings`, all `true` by default): a switched-off type creates
  nothing new (`likes` covers both likes, `comments` covers `COMMENT` and `REPLY`). System types
  are always on.
- **Unread count** is capped at 99. `POST /notifications/read` takes `ids` (1–100, the caller's
  own; others are ignored) or `all: true`; idempotent.
- **Retention (owner, D92):** notifications whose latest activity is older than **30 days** are
  deleted by a sweeper.
- Delivery is in-app (the app polls the unread count); push waits on CP-006 Q4.
