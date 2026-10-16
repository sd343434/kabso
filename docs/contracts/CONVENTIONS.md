# Kabso Live — Shared API Conventions (authoritative contract)

Status: **v1.2 — approved 2026-10-15; in implementation (KL-016/017/018/019)**. Until those tasks
merge, the deployed API still behaves as v1.1 for the items marked *(v1.2)* below. See §9.
**v1.3 — approved 2026-10-16 (KL-036, CTO review; D38)**: live discovery, host lifecycle,
public profile and follow (§10; items marked *(v1.3)*). **v1.3.1 — 2026-10-16 (KL-046)**:
text hygiene for `displayName` and titles (§6, SEC-036), stale-room handling (§10.2, SEC-035),
rate-limit wording (§7, D42), the heartbeat 503 code (D41), body-parsing order (§4, QA-001) and
follow on private accounts (§10.6, QA-002); items marked *(v1.3.1)*. **v1.4.0 — approved
2026-10-16 (KL-048, owner decision D44; approved as D45), implemented by KL-049**: image uploads for avatars and
live-room covers behind `MEDIA_UPLOADS_ENABLED` (default off, no provider activated) and an
optional, user-chosen country with a discovery filter (§11; items marked *(v1.4)*); also the
KL-040b residuals SEC-039 (variation selectors and spaces in text hygiene, §6) and SEC-040 (path
decoding before auth, §4), and the heartbeat headroom wording (§7). Data design:
[`DB_PHASE2_DISCOVERY.md`](DB_PHASE2_DISCOVERY.md), [`DB_PHASE2_MEDIA.md`](DB_PHASE2_MEDIA.md).
Changes require a contract-change proposal recorded in
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
  *(v1.2)* `reserved_term`, *(v1.4, D43)* `unsupported_encoding` (a `Content-Encoding` the API
  does not accept) and `unsupported_charset` (a JSON body declared in a charset that is not a UTF
  encoding). The API already emits these two on body-level errors (`field: ""`); v1.4 only adds
  them to the list.
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
  *(v1.4, SEC-040)* **Path decoding runs first too.** A path segment whose percent-encoding does
  not decode (a malformed `%` escape, or bytes that are not valid UTF-8) is rejected by the
  framework's URL decoding, before routing, authentication and rate limiting. The answer is 400
  `VALIDATION_FAILED`, the constant envelope with no field-specific detail, even without a token.
  This is documented, not changed:
  - the response depends only on the request's own bytes, never on stored data or on the caller,
    so it reveals nothing (the same argument as QA-001);
  - the "malformed → 404" rules (`username`, `roomId`, `sessionId`, `uploadId`) apply to
    segments that decode; an undecodable segment never reaches the route, so there is nothing to
    hide yet;
  - forcing a 404 would mean special-casing a framework error ahead of routing, for no security
    gain. Clients never send such paths: they percent-encode valid UTF-8.
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
| 409 | `LIVE_ROOM_ENDED` | *(v1.3)* Heartbeat for a room that is no longer LIVE (ended by the host, heartbeat timeout, suspension or admin). The host client stops heartbeats and shows the ended state. *(v1.4)* Also returned by `PUT /live/rooms/{roomId}/cover` for such a room. |
| 409 | `MEDIA_UPLOAD_NOT_RECEIVED` | *(v1.4)* `complete` was called but no object exists at the signed location yet. Retryable: the client finishes the PUT and calls `complete` again before the upload expires (§11.3). |
| 410 | `TOKEN_EXPIRED` | Email-verification / password-reset token expired or already used. |
| 410 | `MEDIA_UPLOAD_EXPIRED` | *(v1.4)* The upload window closed before `complete` succeeded. The client declares a new upload (§11.3). |
| 422 | `TOKEN_INVALID` | Email-verification / password-reset token malformed or unknown. |
| 422 | `MEDIA_UPLOAD_REJECTED` | *(v1.4)* The uploaded file failed verification. `details` = one `{field: "file", issue}` with `too_big`, `too_small` or `invalid_format` (§11.2). Final for that upload; the client shows the reason and lets the user pick another image. |
| 429 | `RATE_LIMITED` | Too many requests; `Retry-After` header (seconds) is set. |
| 500 | `INTERNAL_ERROR` | Unexpected server error. |
| 503 | `SERVICE_UNAVAILABLE` | Dependency down (DB/Redis) or feature disabled by config. |
| 503 | `LIVE_HOSTING_UNAVAILABLE` | *(v1.3)* Going live (or heartbeating) is disabled by server config `LIVE_HOSTING_ENABLED=false` (no media provider yet, B1). Not transient: no `Retry-After`; the client shows "not available yet" instead of a generic error. |
| 503 | `MEDIA_UPLOADS_UNAVAILABLE` | *(v1.4)* Image uploads are disabled by server config: `MEDIA_UPLOADS_ENABLED=false`, which is the default and the only possible state while no storage is configured (§11.1). Same semantics as `LIVE_HOSTING_UNAVAILABLE`: not transient, no `Retry-After`; the client hides upload controls (it learns the state from `GET /media/config`). Removing an avatar or a cover (`null`) never returns it. |

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
     - Unicode Emoji 17.0 `emoji-sequences.txt` and `emoji-zwj-sequences.txt` (the RGI emoji set);
     - *(v1.4, SEC-039)* `StandardizedVariants.txt` (UCD 17.0.0) and
       `emoji/emoji-variation-sequences.txt` (UCD 17.0.0);
     - *(v1.4, SEC-039)* the Ideographic Variation Database **2022-09-13**, file
       `IVD_Sequences.txt` (every registered collection: Adobe-Japan1, Hanyo-Denshi, Moji_Joho,
       MSARG, KRName, …). If a newer IVD release is published, moving to it is a contract patch.
       **Not vendored yet (KL-049):** see "Known limitation" under rule 3. Every other file in
       this list is vendored and pinned.

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
       NULL NOTEHEAD; *(v1.4, SEC-039)* U+16FE4 KHITAN SMALL SCRIPT FILLER. The list is part of the
       contract; it changes only by contract patch;
     - *(v1.4, SEC-039)* it is a **space other than** U+0020, U+00A0, U+202F or U+3000 (rule 4).
       The v1.4 review of other filler-like or invisible-rendering characters found the rest
       already rejected by rule 2: CGJ U+034F, Khmer U+17B4/U+17B5, Mongolian U+180E, the musical
       format characters U+1D173–U+1D17A, the Egyptian hieroglyph format controls
       U+13430–U+1343F, the shorthand format controls U+1BCA0–U+1BCA3, the invisible operators
       U+2061–U+2064 and the interlinear annotation characters U+FFF9–U+FFFB (all `Cf` or
       `Default_Ignorable_Code_Point`).
  3. **Allowed exceptions.** These are the only default-ignorable or format characters accepted:
     - **Inside an RGI emoji.** Any code point inside a grapheme cluster that is exactly one RGI
       emoji sequence (rule 1 data): ZWJ and VS16 in emoji sequences, and the tag characters
       U+E0020–U+E007F of the England, Scotland and Wales flags. Tag characters are accepted only
       here.
     - **ZWNJ U+200C and ZWJ U+200D** elsewhere: the placement rule above (between two
       non-joiner, non-space characters).
     - **Variation selectors** elsewhere (`Variation_Selector = Yes`: U+180B–U+180D, U+180F,
       U+FE00–U+FE0F, U+E0100–U+E01EF). *(v1.4, SEC-039)* A selector is accepted only when the
       pair (the code point directly before it, the selector) is **listed** in one of:
       - `StandardizedVariants.txt`: standardized variation sequences, including the CJK
         compatibility ideograph variants and the Mongolian free variation selectors;
       - `emoji-variation-sequences.txt`: text or emoji presentation (U+FE0E / U+FE0F), e.g.
         U+2665 U+FE0E;
       - the IVD's `IVD_Sequences.txt`: registered ideographic variation sequences.

       Any other selector is rejected, wherever it is, including after a Latin, Arabic or other
       letter for which no sequence is registered. There is still at most one per base, and never
       one at the start, after a space, after a mark or after another selector. The check runs on
       the NFC form; the bases of these sequences are stable under NFC.

       *Why:* before v1.4 one selector could follow any base character. With 256 selectors that is
       an invisible one-byte-per-character channel in names and titles. A listed sequence chooses
       between at most a few registered glyph forms of one base, which is a visible choice, not a
       hidden byte.

       *What CJK users keep:* with the IVD included, registered Japanese and Korean name variants
       (e.g. 葛 U+845B U+E0100, the many registered forms of 邉 U+9089) stay valid. Only sequences
       that are not registered in the pinned IVD release are refused; a newer IVD release needs a
       contract patch.

       **Known limitation (KL-049, until the IVD file is vendored).** The IVD 2022-09-13
       `IVD_Sequences.txt` could not be obtained from a verifiable source when v1.4 was
       implemented, so the API does **not** yet check ideographic variation sequences against
       the IVD. The interim rule is: a selector U+E0100–U+E01EF is accepted when the code point
       before it is a `Unified_Ideograph` (from the vendored `PropList.txt`), and is rejected
       after anything else. Consequences:
       - registered Japanese and Korean name variants stay valid, as intended;
       - an **unregistered** ideographic selector after a CJK ideograph is also accepted, so the
         rule-8 item "a selector after a CJK ideograph that is not registered for that ideograph
         in the pinned IVD" is **not enforced yet**. The hidden channel SEC-039 closes therefore
         stays open for CJK ideograph bases only (up to 240 selector choices per ideograph);
       - every other part of SEC-039 is enforced: standardized and emoji variation sequences
         are checked against their vendored files, ideographic selectors after non-ideographs
         are rejected, and U+16FE4 and the inner-space rule apply.

       Full conformance with this rule is pending the data file. Vendoring the pinned file (with
       its sha256) switches the API to the registered-pairs check without a contract change
       (`apps/api/src/modules/users/data/README.md`).
  4. **Spaces.** Space separators (`Zs`: U+0020, U+00A0, U+1680, U+2000–U+200A, U+202F, U+205F and
     U+3000 IDEOGRAPHIC SPACE) are removed at either end by trimming. They never count as a letter,
     and a joiner may not touch them. A value made only of spaces is `invalid_format` (v1.2.4).
     U+3000 is **not** a blank look-alike: it is the usual separator in CJK names. Line and
     paragraph separators (`Zl`, `Zp`) and U+180E are not spaces and are rejected by rule 2.
     *(v1.4, SEC-039)* **Inside** a value only U+0020, U+00A0 NO-BREAK SPACE, U+202F NARROW
     NO-BREAK SPACE (Mongolian suffixes) and U+3000 are allowed. U+1680, U+2000–U+200A and U+205F
     are rejected (`invalid_format`): they have no role in names or titles, and choosing among a
     dozen look-alike widths is another invisible channel. Accepted residual: U+0020 versus U+00A0
     is still an invisible one-bit choice per space; names are at most 50 graphemes, so this stays
     tiny.
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
     *(v1.4, SEC-039)* Also: Japanese names with registered IVS, e.g. `葛󠄀飾 北斎` (U+845B U+E0100)
     and a name using a Moji_Joho sequence on 邉 U+9089 taken from the pinned IVD file;
     ❤️ U+2764 U+FE0F and ♥︎ U+2665 U+FE0E inside and after a name; the keycaps `#️⃣` U+0023
     U+FE0F U+20E3 and `1️⃣`; a digit with its listed text/emoji selector (U+0031 U+FE0E); a CJK
     compatibility standardized variant from `StandardizedVariants.txt`; a Mongolian name whose
     letter carries a listed free variation selector; U+202F inside a Mongolian name; U+3000 in
     `山田　太郎`. Every sequence in the three rule 1 variation files must pass when its base is
     valid on its own.
  8. **Must be rejected** (each alone and inside a name): U+3164, U+115F, U+1160, U+FFA0; U+00AD;
     U+034F; U+2061–U+2064; U+180E; any tag character outside an RGI emoji (including a black flag
     followed by non-RGI tags) and U+E0001; U+2028, U+2029; U+FFF9–U+FFFB; U+1D173–U+1D17A;
     U+2800; U+FFFC; U+1D159; private-use and unassigned code points; lone surrogates; U+17B4,
     U+17B5; U+1BCA0–U+1BCA3; U+0600–U+0605; a variation selector at the start, after a space,
     after another selector, or after a mark; everything rejected before v1.3.1.
     *(v1.4, SEC-039)* Also: U+16FE4 (alone, after a letter, inside a name); any selector
     U+FE00–U+FE0F or U+E0100–U+E01EF after a Latin, Arabic, Cyrillic, Hebrew or Hangul letter for
     which no sequence is listed (e.g. `a` U+FE00, `م` U+E0100); a selector after a CJK ideograph
     that is not registered for that ideograph in the pinned IVD (*not enforced until the IVD
     file is vendored*, see "Known limitation" under rule 3); U+2764 or U+2665 followed by a
     selector other than U+FE0E/U+FE0F; a listed sequence followed by a second selector; U+1680,
     U+2000–U+200A and U+205F inside a name or title.
  9. **Tightening, applied on write.** *(v1.4)* The SEC-039 changes follow the same rule. The
     rules are checked when a value is submitted:
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
| `POST /live/rooms/{roomId}/heartbeat` *(v1.3)* | 12 / min per user (expected cadence 1 / 15 s = 4 / min, so the default gives 3× headroom for retries). *(v1.4)* The required minimum is **2×**: in production the API refuses to boot when `RATE_LIMIT_LIVE_HEARTBEAT_USER` allows fewer than 2 × the beats that `LIVE_HEARTBEAT_INTERVAL_SECONDS` produces in the window. So a shorter interval (e.g. 5 s = 12 / min) needs a larger bucket (≥ 24 / min). 3× is the default, 2× the floor |
| `POST /live/rooms/{roomId}/end` *(v1.3)* | 30 / hour per user |
| `PUT` + `DELETE /users/{username}/follow` *(v1.3)* | one shared bucket per user: 60 / hour and 300 / day; idempotent no-op calls count too (anti follow/unfollow churn) |
| `POST /media/uploads` *(v1.4)* | 20 / hour and 60 / day per user; declared bytes ≤ `MEDIA_DAILY_BYTES_PER_USER` (default 100 MiB) / day per user; at most `MEDIA_MAX_PENDING_PER_USER` (default 5) uploads in `AWAITING_UPLOAD` per user (429, `Retry-After` = until the oldest expires). Counted **before** the `MEDIA_UPLOADS_ENABLED` check |
| `POST /media/uploads/{uploadId}/complete` *(v1.4)* | 30 / hour per user; idempotent repeats count too |
| `PUT /live/rooms/{roomId}/cover` *(v1.4)* | 20 / hour per user |
| `GET /live/countries` *(v1.4)* | 300 / 15 min per user |
| `POST /auth/password/forgot` | 3 / hour per email, 10 / hour per IP |
| `POST /auth/refresh` | 60 / 15 min per session |
| `POST /auth/email/resend` | 5 / hour per user |
| Other public routes (`email/verify`, `password/reset`, `users/username-availability`) | 300 / 15 min per IP |
| Everything else (authenticated) — includes `GET /live/config`, `/live/categories`, `/live/rooms/{roomId}`; *(v1.4)* `GET /media/config`, `GET /media/uploads/{uploadId}`, `GET /countries` | 600 / 15 min per user |

*(v1.3)* Every v1.3 bucket is keyed by the authenticated user id (HMAC as below), with
names `live:list`, `users:profile`, `live:start:h`, `live:start:d`, `live:heartbeat`, `live:end`,
`follow:h`, `follow:d`. *(v1.4)* Same for `media:upload:h`, `media:upload:d`, `media:bytes:d`,
`media:complete`, `live:cover`, `live:countries`. The pending-upload cap is a count of rows, not a
Redis bucket.

*(v1.3.1, D42)* **Which buckets a request counts against.** An endpoint-specific limit does not
always replace the default bucket:
- **Replaces the per-user default** (600 / 15 min): only the rows marked *(v1.3)* that carry an
  endpoint limit — `GET /live/rooms`, `GET /users/{username}`, `POST /live/rooms`,
  `POST /live/rooms/{roomId}/heartbeat`, `POST /live/rooms/{roomId}/end`, and `PUT` + `DELETE
  /users/{username}/follow`. These requests count only against their own buckets. *(v1.4)* The
  same applies to every *(v1.4)* row: `POST /media/uploads`, `POST /media/uploads/{uploadId}/complete`,
  `PUT /live/rooms/{roomId}/cover` and `GET /live/countries`.
- **Counts both** its own bucket and the per-user default: the older authenticated rows,
  `PATCH /me` and `POST /auth/email/resend`. This is stricter and therefore safe; it stays as is.
  *(v1.4)* `PATCH /me` keeps this behaviour; setting an avatar or a country uses the same 30 / hour.
- **Per-user default only:** every other authenticated route, including `GET /live/config`,
  `GET /live/categories`, `GET /live/rooms/{roomId}` and `POST /auth/logout`; *(v1.4)*
  `GET /media/config`, `GET /media/uploads/{uploadId}` and `GET /countries`.
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
| *(v1.4)* Table `media_objects` | Backend — new `media` module | CTO; Security (A7) reviews upload, processing and cleanup; see `DB_PHASE2_MEDIA.md` |
| *(v1.4)* Columns `user_profiles.avatar_media_id`, `user_profiles.country` | Backend — `users` module (writes go through `media` for the attach) | CTO |
| *(v1.4)* Columns `live_rooms.cover_media_id`, `live_rooms.country` | Backend — `live` module | CTO |
| *(v1.4)* Server config `MEDIA_*` (§11.12) | DevOps (per-environment value; storage credentials in the secret manager, PP-09) | Turning uploads **on** in any shared environment, choosing the storage provider, the moderation provider and any paid plan needs **owner** approval (D44) |
| *(v1.4)* Storage buckets, CDN origin and their lifecycle rules (`infra/**`) | DevOps | CTO + owner (cost); A7 reviews bucket policies |
| *(v1.4)* Vendored country list and CLDR names (§11.7) | Backend | CTO; changing the source version, adding or removing a code, or overriding a name is a contract patch (owner approval for name overrides) |
| *(v1.4)* Mobile media host allow-list (build configuration, §11.10) | Flutter | CTO + A7 |
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
| v1.4.0 | 2026-10-16 | **Approved (KL-048, D44; approval D45). Implemented by KL-049**, with one documented limitation: the IVD file is not vendored yet, so §6 rule 3 uses an interim rule for ideographic variation selectors (see §6 "Known limitation"). (1) Image uploads for avatars and live-room covers (§11.1–§11.6, §11.10–§11.12): `GET /media/config`, `POST /media/uploads` (presigned PUT to S3-compatible storage), `POST /media/uploads/{uploadId}/complete` (server verification, metadata strip, re-encode to WebP derivatives), `GET /media/uploads/{uploadId}`; avatar via `PATCH /me {avatarUploadId}`; cover via `coverUploadId` on `POST /live/rooms` and new `PUT /live/rooms/{roomId}/cover`; moderation states with owner-only visibility until APPROVED; all behind `MEDIA_UPLOADS_ENABLED` (default false). (2) Optional, user-chosen country (§11.7–§11.9): `PATCH /me {country}`, `country` on `Me`, `PublicProfile` and `LiveRoomSummary`, `GET /live/rooms?country=`, `GET /live/countries` (real counts), `GET /countries` (localized list); no IP geolocation. (3) New response fields `avatarThumbUrl` (`Me`, `UserSummary`, `PublicProfile`), `avatarModeration` (`Me`), `coverThumbUrl` (`LiveRoomSummary`), `coverModeration` (`LiveRoom`, host only). (4) `PATCH /me` body: every property optional, at least one required. (5) New codes `MEDIA_UPLOADS_UNAVAILABLE` (503), `MEDIA_UPLOAD_REJECTED` (422), `MEDIA_UPLOAD_NOT_RECEIVED` (409), `MEDIA_UPLOAD_EXPIRED` (410) (§4). (6) D43: `unsupported_encoding` and `unsupported_charset` added to the §4 issue vocabulary. (7) Rate limits (§7), ownership (§8), cursor payload gains `country` (§10.4). Data design: `DB_PHASE2_MEDIA.md`. (8) KL-040b residuals (CTO): **SEC-039** (§6 text hygiene) — a variation selector is accepted only as part of a sequence listed in the newly vendored `StandardizedVariants.txt`, `emoji-variation-sequences.txt` (UCD 17.0.0) or the pinned IVD 2022-09-13 `IVD_Sequences.txt` (the IVD file is not vendored yet: interim rule, §6 "Known limitation"); U+16FE4 joins the blank look-alike list; inside a value only the spaces U+0020, U+00A0, U+202F and U+3000 are allowed; must-pass and must-fail lists extended. **SEC-040** (§4) — an undecodable percent-encoded path segment gets 400 `VALIDATION_FAILED` before auth; documented, not changed. (9) §7: heartbeat headroom is 3× by default with a 2× floor enforced at boot in production (matches the implementation). | **Additive** for the API surface; SEC-039 is a **tightening applied on write only**, like v1.3.1: `register` and go-live can return 400 `invalid_format` for a name or title with an unlisted variation selector, U+16FE4 or an unusual space, and stored values are not rewritten. No path, code or field is removed or renamed; `avatarUrl` and `coverUrl` keep their names and types and stay null until uploads are enabled and an image is approved. `PATCH /me` accepts every v1.2 body unchanged. Response objects gain fields (clients ignore unknown fields). Cursors issued by v1.3 stay valid for requests without `country`. Mobile: map the four new codes; hide upload controls while `uploadsEnabled = false`; render images only from allow-listed hosts (§11.10). API needs one additive migration (`DB_PHASE2_MEDIA.md` §5). No storage or moderation provider is activated by this version. |

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
  (HL-H4). *(v1.4)* `coverUrl` can be set by an uploaded cover (§11.4); it stays `null` while
  `MEDIA_UPLOADS_ENABLED=false` and for other viewers until the cover is APPROVED (§11.5).

### 10.3 Host lifecycle

- **Go live** (`POST /live/rooms`, body `{title, categorySlug?}`; *(v1.4)* also `coverUploadId?`,
  §11.4): checks run in the order given
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
    only), and the sort key of the last row (`viewerCount`, `startedAt`, `id`). *(v1.4)* It also
    holds `country` (§11.9). The format version becomes 2; a version-1 cursor is still accepted,
    as if it carried `country` absent, so it matches only a request without `country`.
  - The HMAC key is derived from server configuration (implementation: KL-037).
  - The cursor fails with 400 `VALIDATION_FAILED` (`field "cursor"`, `issue "invalid_value"`)
    when it:
    - does not decode;
    - fails the tag check;
    - has an unknown version;
    - does not match the request's `tab`, `category`, *(v1.4)* `country` or caller.
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
  - *(v1.4)* `avatarThumbUrl`, `country` (§11.5, §11.7);
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
- Editing a room's title or category after go-live; covers and cover upload. *(v1.4)* Covers
  and cover upload are added by §11; title and category stay fixed after go-live.

## 11. Media uploads and countries *(v1.4, approved — KL-048, D45)*

Owner decision D44: avatar and room-cover uploads, with an S3-compatible adapter that stays
disabled until the owner approves the provider, cost and credentials; and a Countries & Regions
discovery section where the user chooses their country and location is never inferred. Every
endpoint below is under `/api/v1`, requires a bearer token, and uses §4 errors, §5 pagination
and §7 rate limits. Data design: [`DB_PHASE2_MEDIA.md`](DB_PHASE2_MEDIA.md).

### 11.1 Feature gates

- **`MEDIA_UPLOADS_ENABLED`** (default `false`). Uploads are available only when it is `true`.
  It can only be `true` when the storage configuration (§11.12) is complete and valid: the API
  refuses to boot otherwise, so "enabled but not configured" cannot happen.
- While it is `false`:
  - `GET /media/config` answers `uploadsEnabled: false`, and the client hides every upload
    control (profile photo, room cover). The client shows no error and no "coming soon" upload
    button;
  - `POST /media/uploads`, `POST /media/uploads/{uploadId}/complete`, a non-null
    `avatarUploadId` on `PATCH /me`, a `coverUploadId` on `POST /live/rooms`, and a non-null
    `coverUploadId` on `PUT /live/rooms/{roomId}/cover` → 503 `MEDIA_UPLOADS_UNAVAILABLE`
    (no `Retry-After`);
  - removing an image (`null`) and reading an upload (`GET /media/uploads/{uploadId}`) still
    work;
  - images that were approved before uploads were turned off stay visible. Turning uploads off
    stops new uploads; it does not hide existing images. Hiding existing images is a separate
    moderation or ops action.
- **`room_cover` also needs live hosting.** `POST /media/uploads` with `purpose = room_cover`
  while `LIVE_HOSTING_ENABLED=false` → 503 `LIVE_HOSTING_UNAVAILABLE`, so no covers are stored
  while nobody can go live.
- **Countries have no feature gate.** They need no provider and are always available.
- **No paid provider is activated by this contract.** Storage, CDN and moderation providers,
  their cost and their credentials need owner approval (D44). Until then every environment that
  is shared runs with `MEDIA_UPLOADS_ENABLED=false`.

### 11.2 Image rules

| Rule | `avatar` | `room_cover` |
| ---- | -------- | ------------ |
| Accepted types (declared **and** detected) | JPEG, PNG, WebP | JPEG, PNG, WebP |
| Max bytes (`byteSize` and the stored object) | 5 MiB (5 242 880) | 10 MiB (10 485 760) |
| Max pixels (width × height, from the header, before decoding) | 40 000 000 | 40 000 000 |
| Max side | 8192 px | 8192 px |
| Aspect ratio of the output (server centre-crop) | 1:1 | 3:4 (`size.liveCardAspect` 0.75) |
| Minimum size of the largest centred crop | 128 × 128 | 480 × 640 |
| Derivatives (WebP, sRGB, no metadata) | 512 × 512 (`avatarUrl`), 128 × 128 (`avatarThumbUrl`) | 960 × 1280 (`coverUrl`), 480 × 640 (`coverThumbUrl`) |

- **Refused types:** HEIC/HEIF, AVIF, GIF, SVG, BMP, TIFF and everything else.
  - HEIC is refused because of decoder attack surface and codec licensing. iOS pickers can
    deliver JPEG: the client converts before upload (e.g. `image_picker` with a maximum size and
    quality, which re-encodes to JPEG).
  - SVG is refused because it is a document format that can reference external resources.
- **Animated images are refused** (`invalid_format`): animated WebP and APNG.
- **Derivatives never upscale.** When the crop is smaller than a derivative size (it is never
  smaller than the minimum), that derivative keeps the crop's size. `width` and `height` in
  `MediaUpload` are the actual size of the main derivative.
- **Processing:** decode with only the JPEG, PNG and WebP decoders → apply EXIF orientation →
  centre-crop → convert to sRGB → resize → encode WebP → write the derivatives. **All metadata is
  dropped**: EXIF (including GPS), XMP, IPTC, comments, PNG text chunks, and the ICC profile
  after conversion to sRGB.
- **Failure issues** (`MEDIA_UPLOAD_REJECTED`, `field "file"`):
  - `too_big`: the object is larger than declared or than the purpose limit, or the image
    exceeds the pixel or side limit;
  - `too_small`: the largest centred crop is below the minimum;
  - `invalid_format`: the detected type differs from the declared type or is not accepted; the
    image is animated, truncated or does not decode; or processing exceeded its time limit.
- The client should pre-check type, bytes and dimensions with the values from
  `GET /media/config` and let the user crop to the purpose's ratio before uploading. The server
  is authoritative.

### 11.3 Upload flow

Three steps. The image bytes never pass through the API.

1. **Declare.** `POST /media/uploads` `{purpose, contentType, byteSize}` → 201
   `{uploadId, purpose, method: "PUT", url, headers, expiresAt}`.
   - The server creates a `media_objects` row in `AWAITING_UPLOAD` and signs **one** S3 SigV4
     PUT URL for **one** private object key (§11.11).
   - The signature covers `Content-Type` = `contentType` and `Content-Length` = `byteSize`.
   - `expiresAt` = now + `MEDIA_UPLOAD_URL_TTL_SECONDS` (default 600 s, at most 900 s).
2. **Upload.** The client sends the bytes with `PUT` to `url`, with exactly the returned
   `headers`, and with no `Authorization` header or cookie of its own. The storage provider
   rejects a different size, type or an expired URL.
   - `method` is always `PUT` in v1.4. Presigned POST policies are not used: not every
     S3-compatible store supports them (Cloudflare R2 does not), and the signed `Content-Length`
     gives the same size guarantee.
   - The client never logs `url`: its query string is a bearer credential for that one object.
3. **Complete.** `POST /media/uploads/{uploadId}/complete` (no body).
   - Synchronous. The server checks the stored object's size with a HEAD request, then reads at
     most `byteSize` bytes, then applies §11.2.
   - On success the upload becomes `READY` with `moderationStatus = PENDING`, the original is
     deleted, and the response carries the owner-preview URLs.
   - On failure the upload becomes `FAILED` and the object is deleted → 422
     `MEDIA_UPLOAD_REJECTED`.
   - `complete` is accepted until `expiresAt` + 5 minutes, so a PUT that started just before
     expiry can still finish.
   - It is idempotent: a `READY` upload returns 200 again; a `FAILED` one returns the same 422.
   - Image processing is bounded per process (`MEDIA_PROCESS_MAX_CONCURRENCY`). When it is
     saturated, the answer is 503 `SERVICE_UNAVAILABLE` with `Retry-After`, as for Argon2 (§6).

**Upload states** (`MediaUpload.status`):

```text
(declare) ──► AWAITING_UPLOAD ──complete ok──────► READY ──attach──► (attached: used as avatar/cover)
                     │          ──complete fails──► FAILED
                     └──window closes──────────────► EXPIRED
READY (never attached, MEDIA_UNATTACHED_TTL_HOURS) ─┐
attached, then replaced/removed/room ended/rejected ┴─► DELETED (objects removed after the grace period)
```

- An upload belongs to the user who declared it. Every other caller gets 404 for it, and 400
  `invalid_value` when trying to attach it.
- An upload is **attached at most once**. To use the same picture again, the user uploads it
  again. A reusable "default cover" is an open question (§11.13).

### 11.4 Applying images

- **Avatar: `PATCH /me {avatarUploadId}`.** No separate `PUT /me/avatar`.
  - Rationale: the profile already has one edit endpoint with an all-or-nothing body and a rate
    limit. A separate route would add a second write path to the same row.
  - The value must be the caller's own `avatar` upload in `READY` that is not attached and not
    `REJECTED`. Anything else → 400 (`field "avatarUploadId"`, `issue "invalid_value"`). The
    response does not reveal which condition failed.
  - The previous avatar, if any, is detached and deleted after the grace period (§11.6).
  - `avatarUploadId: null` removes the avatar.
- **Cover at go-live: `coverUploadId` on `POST /live/rooms`** (optional). It is checked after
  `categorySlug` and before the "already live" check, with the same rules (purpose
  `room_cover`, `field "coverUploadId"`). The upload is attached in the same transaction that
  creates the room. If the go-live then fails (for example 409), nothing is attached and the
  upload stays usable.
- **Cover while live: `PUT /live/rooms/{roomId}/cover {coverUploadId}`** (host only).
  - **Decided: yes.** A cover is the room's thumbnail; a host may want to fix a bad one without
    ending the stream. Title and category stay fixed after go-live (§10.3).
  - `null` removes the cover. The previous cover is detached and deleted after the grace
    period.
  - It needs a LIVE room with a fresh heartbeat; otherwise 409 `LIVE_ROOM_ENDED`.
  - Not the host, unknown or malformed id → 404. Hosting disabled → 503
    `LIVE_HOSTING_UNAVAILABLE` before the ownership check, as for heartbeats.
- **Ended rooms keep their cover for `MEDIA_ENDED_ROOM_COVER_TTL_HOURS`** (default 24 h), so the
  "Live ended" view can still show it. After that the cover is deleted and `coverUrl` becomes
  `null`.
- **Audit:** `media.upload.complete`, `media.upload.reject` (verification failure),
  `media.avatar.set`, `media.avatar.remove`, `media.cover.set`, `media.cover.remove`,
  `media.moderation.reject`. There is no audit row for a declare or an expiry.

### 11.5 Moderation and visibility

- **States:** `PENDING` → `APPROVED` or `REJECTED`. An `APPROVED` image can later become
  `REJECTED`, for example after a re-scan or a report; moderation by reports is later work.
- **Visibility rule** (applies to every response that carries an image URL: `Me`,
  `PublicProfile`, `UserSummary` inside rooms, `LiveRoomSummary`, `LiveRoom`):
  - the image's **owner** sees it while `PENDING` and `APPROVED`;
  - **everyone else** sees it only when `APPROVED`. Otherwise its URL fields are `null`, and the
    client shows the same fallback as for "no image" (avatar initial; C2 tinted cover).
- **The owner learns the state from:** `Me.avatarModeration`, `LiveRoom.coverModeration` (sent
  only to the host; `null` for everyone else) and `GET /media/uploads/{uploadId}`. The client
  shows "Visible to others after review" while `PENDING`.
- **Hook.** After `complete`, the server hands the derivative to a `MediaModerationPort`. The
  port's answer sets `APPROVED` or `REJECTED`. The check runs asynchronously: `complete` does not
  wait for it.
- **On `REJECTED`:**
  - the image is detached (`avatar_media_id` or `cover_media_id` set to null);
  - its objects are deleted and a CDN purge is requested;
  - the audit row `media.moderation.reject` is written.

  The owner then sees no image, and `GET /media/uploads/{uploadId}` shows `REJECTED`. User-facing
  notification is later work.
- **With no provider configured (`MEDIA_MODERATION_PROVIDER=none`, the default)**: images stay
  `PENDING` indefinitely. They are **visible only to their owner**; no other user sees any
  uploaded avatar or cover. This fails closed and is the honest state. It also means uploads
  bring no visible benefit to other users until a provider is approved (open question §11.13).
- **`MEDIA_MODERATION_PROVIDER=allow_all`** approves every image that passed §11.2 without any
  content check. It exists for local development and tests. The API **refuses to boot with it in
  production**. Turning it on in a shared staging environment needs CTO approval.
- Images are not checked for faces, text or brand impersonation in v1.4. Legal duties for
  illegal content (for example CSAM detection and reporting) must be settled before public
  launch (open question).

### 11.6 Lifecycle, expiry and cleanup (feeds PP-08)

A periodic job (`MEDIA_CLEANUP_INTERVAL_SECONDS`, default 300 s) works in bounded batches, as the
live sweeper does (§10.2):

| Object | Becomes | Storage removed |
| ------ | ------- | --------------- |
| `AWAITING_UPLOAD` past `expiresAt` + 5 min | `EXPIRED` | The incoming object, if one was uploaded |
| `READY`, never attached, older than `MEDIA_UNATTACHED_TTL_HOURS` (default 24 h) | `DELETED` | All derivatives |
| Detached avatar or cover (replaced, removed) | `DELETED` after `MEDIA_DELETE_GRACE_HOURS` (default 24 h) | All derivatives; then a CDN purge request |
| Cover of an ended room, after `MEDIA_ENDED_ROOM_COVER_TTL_HOURS` (default 24 h) | Detached, then as above | As above |
| `REJECTED` | `DELETED` at once | All derivatives, then a CDN purge request |
| `FAILED` | Kept as a row for 7 days (abuse analysis), then removed | The incoming object at once |
| All media of an account that is soft-deleted (`DELETED`) | `DELETED` | All objects, within 24 h |

- **Defence in depth:** the incoming bucket has a provider lifecycle rule that deletes every
  object older than 1 day, whatever the job does.
- **Grace period.** Why: a client that loaded a profile a moment ago may still request the old
  URL. Public objects are immutable (a new image always gets a new key), so the grace period is
  the only reason an old URL keeps working, and it is bounded.
- **CDN caches.** A deleted object can stay in CDN caches until purge or expiry. The public
  `Cache-Control` is therefore `public, max-age=86400, immutable` (1 day), not a year, so a
  failed purge still ends within a day.
- Hard user erasure removes `media_objects` rows by cascade. The job deletes their storage
  objects first. The ordering is defined in `DB_PHASE2_MEDIA.md` §4.

### 11.7 Country on the profile

- **Field.** `country` on `PATCH /me` (set or `null` to clear), and on `Me` and `PublicProfile`.
  It is `null` unless the user chose one, and it is `null` for every existing account.
- **Values.** ISO 3166-1 alpha-2, uppercase, **and** on the vendored list. Otherwise → 400
  (`field "country"`): `invalid_format` for a malformed value (schema), `invalid_value` for a
  well-formed code that is not on the list. The server does not upper-case the value for the
  client.
- **Vendored list (pinned):**
  - **Codes:** the ISO 3166-1 alpha-2 **officially assigned** codes: 249 entries. User-assigned,
    exceptionally reserved and transitional codes are excluded (for example `XK`, `EU`, `UK`,
    `UN`, `ZZ`).
  - **Names:** Unicode CLDR **48** (`cldr-json` package `cldr-localenames-full` **48.0.0**,
    `main/ar/territories.json` and `main/en/territories.json`), using the default (not the
    `-alt-short` / `-alt-variant`) name for each code.
  - **Check at build time:** every code has a non-empty name in both locales.
  - **Vendoring:** like the Unicode data (§6): the files live in the API with their sha256
    recorded next to them; nothing is downloaded at runtime. KL-048's implementation task
    records the hashes and confirms that 48.0.0 is the tag used.
  - **Changes** (new CLDR version, adding or removing a code, overriding a name) are contract
    patches. A name override needs owner approval and is listed in this section with its reason.
    No overrides exist in v1.4.
- **`GET /countries`** returns the whole list (`{code, name}`) unpaginated (≤ 300). `name` is
  localized like category names (§10.1: `Accept-Language` primary subtag `ar`/`en`, else the
  stored `locale`, else `ar`). It is sorted by the localized name with ICU collation for that
  locale. The list is static per server release; the client may keep it in memory for the
  session, per locale.
- **Privacy — what the server does and does not do:**
  - The country is **only ever what the user chose**. The server never infers, suggests or fills
    it from IP geolocation, `Accept-Language`, `locale`, phone number, SIM, device region or time
    zone. `SessionInfo.ipCountry` stays reserved and `null`; no IP geolocation exists.
  - It is **public**: shown on the profile, copied to the user's live rooms (§11.8) and used by
    the country filter.
  - It is optional and can be cleared at any time. Clearing it also clears it from the user's
    current LIVE room at once.
  - No history of past values is kept (no audit row stores the value; the audit action
    `users.country.update` records only that it changed).
- **Consent wording (client requirement).** The picker:
  - starts with **no** country selected, and never pre-selects from the device locale or
    region;
  - shows this text above the save button (A5 owns the final copy):
    - en: "Optional. Your country is shown on your profile and your live rooms, and helps people
      find you by country. We never detect it automatically. You can remove it at any time."
    - ar: "اختياري. تظهر دولتك في ملفك الشخصي وبثوثك المباشرة، وتساعد الآخرين على إيجادك حسب
      الدولة. لا نحددها تلقائيًا أبدًا، ويمكنك إزالتها في أي وقت."
  - offers "Don't show my country" (sends `null`).

### 11.8 Country of a live room

- **Decided: snapshot at go-live, kept in sync while LIVE.**
  - `POST /live/rooms` copies the host's current `country` into `live_rooms.country`. The request
    has no `country` field: a room's country is always the host's own choice.
  - When the host changes or clears `country` with `PATCH /me` while a room is LIVE, the same
    transaction updates that room's `country`. So a room never shows a country the host no
    longer chose.
  - `ENDED` rooms keep the value they had when they ended. That value is shown only in the
    room's own detail.
- **Why a stored copy instead of a join:** the country filter and `GET /live/countries` use the
  partial indexes on `live_rooms` (`DB_PHASE2_MEDIA.md` §3) in a single keyset query, with no
  cross-module join on `user_profiles` per row.
- `LiveRoomSummary.country` is `null` when the host chose none.

### 11.9 Country discovery

- **`GET /live/rooms?country=XX`** filters every tab, like `category` (§10.4), and combines with
  it. A room with `country = null` never matches. A malformed code → 400 (`field "country"`,
  `issue "invalid_format"`); a well-formed code that is not on the list → 400 (`issue
  "invalid_value"`), as for `PATCH /me` (§11.7). Unlike `category`, there is no "well-formed but unknown →
  empty list" case, because the list is fixed per release.
- **Cursor.** The payload includes `country` (§10.4), and a mismatch → 400 `field "cursor"`.
- **`GET /live/countries`** returns the countries that have at least one listed room right now,
  with `liveRoomCount` (≥ 1).
  - **Decided: live countries with counts, not the full list.** The discovery section shows only
    countries where someone is live, with real numbers. The full list is a separate static
    endpoint (`GET /countries`) for the profile picker.
  - Counts use exactly the `GET /live/rooms` predicate (status LIVE, fresh heartbeat, ACTIVE
    host) plus `country IS NOT NULL`. They are never estimated or padded. A response may be
    cached in the server for at most `LIVE_HEARTBEAT_INTERVAL_SECONDS`, so a count can lag the
    list by up to 15 s.
  - Ordered by `liveRoomCount` desc, then `code` asc. `name` is localized as in §11.7. Unpaginated
    (≤ 300 rows).
  - It is empty while nobody with a country is live, which is always the case while
    `LIVE_HOSTING_ENABLED=false`. The client then hides the Countries & Regions section rather
    than showing an empty strip.
- **Privacy note.** Counts reveal nothing that the room list does not already show: every
  counted room is publicly listed with its country.
- **Regions.** "Regions" in the D44 section name means the client groups countries for display
  (for example by continent). The contract carries no region field. A server-side grouping
  would be a later additive change.

### 11.10 Image hosts and client rendering (answers KL-040's `NetworkImage` observation)

- **Server.** Every image URL in a response is `MEDIA_PUBLIC_BASE_URL` + an object key the server
  generated. The server never returns a URL that a client supplied (no endpoint accepts an image
  URL), and the serializer refuses any URL outside that base. In production
  `MEDIA_PUBLIC_BASE_URL` must be `https://` on a host that is **not** the API host and sets no
  cookies.
- **Client.** It renders a network image **only** when all of these hold:
  - the scheme is `https`;
  - the host is an exact, case-insensitive match against the **build-time allow-list** (a
    `--dart-define`, e.g. `KABSO_MEDIA_HOSTS`, one host per environment);
  - there is no userinfo and the port is the default one.
- **Otherwise** the client treats the URL as `null` and shows the fallback, without a request.
  The allow-list is **not** fetched from the API: a compromised or spoofed response must not be
  able to widen it.
- **Requests to media hosts:**
  - carry no `Authorization` header and no cookies;
  - do not follow redirects to a host outside the allow-list;
  - decode at the displayed size (`cacheWidth` / `cacheHeight`), so a hostile image cannot
    exhaust memory.
- **Fixture images** in tests and goldens stay local assets (D39). Production never shows a
  placeholder photo.

### 11.11 Security threats and controls

| Threat | Control |
| ------ | ------- |
| **SSRF** | No endpoint accepts a URL. The server talks only to the storage endpoint fixed at boot (`MEDIA_STORAGE_ENDPOINT`, https in production) and reads only keys it generated. The image decoders cannot fetch anything: no SVG, XML or other loaders, and untrusted libvips loaders are blocked. |
| **Content-type spoofing** | The declared type is signed into the PUT. On `complete`, the magic bytes must match the declared type (JPEG `FF D8 FF`, PNG `89 50 4E 47 0D 0A 1A 0A`, WebP `RIFF....WEBP`), and the decoder is chosen by the detected type, never by a header or file name. Public objects are always WebP, served with a fixed `Content-Type: image/webp` and `X-Content-Type-Options: nosniff`. |
| **Polyglots and active content** | Originals are never served; they are deleted after processing. Derivatives are re-encoded from decoded pixels, so trailing data, extra chunks and embedded scripts are dropped. Public objects come from a separate cookieless origin with `Content-Security-Policy: default-src 'none'; sandbox`. |
| **EXIF / GPS leaks** | All metadata is stripped from every derivative (§11.2). The original is deleted at `complete`, and the incoming bucket's lifecycle rule deletes leftovers within 1 day. Test: a GPS-tagged JPEG yields derivatives with no EXIF/XMP. |
| **Decompression bombs** | Width, height and pixel count are read from the header **before** decoding and checked against the limits. The decoder's own pixel limit is set to the same value. Animated images are refused. Each processing job has a time limit (`MEDIA_PROCESS_TIMEOUT_MS`), and processing concurrency is capped. |
| **Decoder vulnerabilities** | Only three decoders are enabled, and the image library is kept patched (Dependabot). Running processing in a separate worker process or sandbox is an A7 review item (§11.13). |
| **Storage key guessing / enumeration** | Incoming keys: `in/<uploadId>/<128-bit random>`. Public keys: `<a\|c>/<128-bit random>/<size>.webp`, where the random part comes from a CSPRNG and is unrelated to the user id or upload id. Bucket listing is disabled. The incoming bucket is private. The public bucket is readable only by exact key through the CDN. |
| **Presign scope and expiry** | One URL per upload: one key, `PUT` only, `Content-Type` and `Content-Length` signed, TTL ≤ 900 s. The storage credentials are scoped to the two buckets (put/get/delete on the incoming bucket; put/delete on the public bucket; list on both, for the weekly reconciliation in `DB_PHASE2_MEDIA.md` §4), with no account or bucket administration rights. Presigned URLs are redacted from logs. A second PUT to the same URL after `complete` only creates an orphan, which the lifecycle rule removes; the upload is already terminal. |
| **Quota and cost abuse** | §7 limits: per-hour, per-day and daily-bytes buckets, plus the pending-upload cap. The stored size is checked with HEAD before any download, and the read is capped at `byteSize`. Abandoned and unattached uploads are cleaned up (§11.6). Uploads are off by default. |
| **Using someone else's upload** | Upload ids are checked against the caller on every use. A foreign id gives 404 (read) or 400 `invalid_value` (attach), and is never 403, so ownership is not revealed. |
| **Inappropriate images** | The moderation hook, with owner-only visibility until `APPROVED` (§11.5). It fails closed when no provider is configured. |
| **Country inference / tracking** | None (§11.7): no IP geolocation, no defaulting, public and clearable, no history. |

### 11.12 Configuration (names only; values per environment)

Defaults, ranges and validation are in [`DB_PHASE2_MEDIA.md`](DB_PHASE2_MEDIA.md) §5. Secrets
have no default and no example value. They come from the secret manager (PP-09) and are never
committed (D40).

- Switches: `MEDIA_UPLOADS_ENABLED`, `MEDIA_MODERATION_PROVIDER`.
- Storage (any S3-compatible provider): `MEDIA_STORAGE_ENDPOINT`, `MEDIA_STORAGE_REGION`,
  `MEDIA_STORAGE_FORCE_PATH_STYLE`, `MEDIA_STORAGE_INCOMING_BUCKET`, `MEDIA_STORAGE_PUBLIC_BUCKET`,
  `MEDIA_STORAGE_ACCESS_KEY_ID` (secret), `MEDIA_STORAGE_SECRET_ACCESS_KEY` (secret),
  `MEDIA_PUBLIC_BASE_URL`.
- Limits and timings: `MEDIA_UPLOAD_URL_TTL_SECONDS`, `MEDIA_MAX_PENDING_PER_USER`,
  `MEDIA_DAILY_BYTES_PER_USER`, `MEDIA_PROCESS_MAX_CONCURRENCY`, `MEDIA_PROCESS_TIMEOUT_MS`,
  `MEDIA_UNATTACHED_TTL_HOURS`, `MEDIA_DELETE_GRACE_HOURS`, `MEDIA_ENDED_ROOM_COVER_TTL_HOURS`,
  `MEDIA_CLEANUP_INTERVAL_SECONDS`, `MEDIA_CLEANUP_BATCH_SIZE`.
- Moderation provider credentials: named when a provider is chosen (none in v1.4).
- Mobile build configuration: `KABSO_MEDIA_HOSTS` (§11.10).

**Provider requirements** (what any candidate must support; the choice is an owner question):
- S3 SigV4 presigned `PUT` with signed `Content-Type` and `Content-Length`;
- private buckets with listing disabled;
- object lifecycle (expiry) rules;
- `HEAD`, `GET` and `DELETE` through the S3 API;
- a CDN or custom domain in front of the public bucket, with the response headers of §11.11;
- a cache purge API (preferred, not required).

### 11.13 Open questions and out of scope for v1.4

- **Owner:** storage/CDN provider, region and budget; moderation provider (until then, images
  are visible only to their owner); legal duties for illegal content before launch; name
  overrides for sensitive territories (default: CLDR names unchanged); whether `XK` should be
  selectable.
- **CTO / A7:** sandboxing image processing in a separate worker; whether `allow_all` may run in
  a shared staging environment.
- **Product (later, additive):** a reusable default room cover per host; report or flag an
  image; admin moderation queue; video or animated covers; more than two derivative sizes;
  server-side region grouping.
- **Out of scope:** editing the room title or category after go-live; uploads of any other kind
  (posts, stories, chat images); per-country rankings; any location feature.
