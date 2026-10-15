# KL-007 — Phase 1 Security Review (A7)

| | |
| - | - |
| Candidate reviewed | `b973d7b` (Merge KL-003; includes KL-002 API, KL-005 CI) |
| Reviewer | A7 Security & Performance |
| Date | 2026-10-15 |
| Method | Code review of `apps/api/src`, `apps/mobile/lib` (core/network, core/storage, core/logging, features/auth), Android/iOS manifests, CI, env templates, docs; live proof-of-concept against a local API on `127.0.0.1:3102` (DB `kabso_sec_test`, Redis db 13); gitleaks 8.30.1 (checksum-verified); `pnpm audit --prod`; `flutter pub outdated` |
| Threat model | [`../SECURITY_MODEL.md`](../SECURITY_MODEL.md) |
| Regression tests added | `apps/api/test/security/security-regression.e2e-spec.ts` (17 tests, all passing on `b973d7b`; full e2e suite 61/61) |

**Gate verdict: PASS WITH CONDITIONS** (see §4). No Critical or High finding. Three Medium
findings must be fixed (or explicitly accepted by the CTO) before any public/production exposure;
none blocks closing Phase 1 as an internal milestone.

PoC scripts used (not committed; reproducible from the snippets below): `p1.sh`–`p5.sh`,
`trustproxy.mjs` in the reviewer's scratchpad.

## 1. Findings

| ID | Sev | Title | CWE | Owner |
| -- | --- | ----- | --- | ----- |
| SEC-001 | **Medium** | Anyone who knows a session id can revoke that session without any secret | CWE-306 | A3 |
| SEC-002 | **Medium** | No cross-IP per-account login throttle; IPv6 addresses not bucketed; Argon2 has no concurrency cap | CWE-307, CWE-400 | CTO-contract + A3 |
| SEC-003 | **Medium** | `TRUST_PROXY=true` accepted (also in production) → `X-Forwarded-For` spoofing bypasses every per-IP limit | CWE-348 | A3 + A8 |
| SEC-004 | Low | Concurrent refresh with the same token revokes the winner; API doc says it does not | CWE-362 | A3 (doc) / A2 (awareness) |
| SEC-005 | Low | Low-entropy JWT secrets pass production validation | CWE-326 | A3 |
| SEC-006 | Low | Token-bearing responses have no `Cache-Control: no-store` | CWE-525 | A3 |
| SEC-007 | Low | Release builds: iOS `NSAllowsLocalNetworking` in the shared Info.plist; default `API_BASE_URL` is `http://…` with no HTTPS assertion | CWE-319 | A2 |
| SEC-008 | Low | Control chars accepted in `device.name`/`device.appVersion`; bidi/zero-width accepted in `displayName` | CWE-150, CWE-451 | A3 |
| SEC-009 | Low | Login IP+identifier bucket is per spelling: email and username of one account get separate buckets | CWE-307 | A3 |
| SEC-010 | Low | Rate-limit keys are unkeyed SHA-256 of emails/identifiers (dictionary-confirmable from Redis) | CWE-759 | A3 |
| SEC-011 | Low (Phase 1) / **blocker for production** | No least-privilege DB role; docs claim one exists | CWE-250 | A8 + A3 |
| SEC-012 | Low | PII retention: IP/UA kept indefinitely, audit rows keep `target_id` + `ip` after user deletion, no cleanup jobs | CWE-359 | A3 + CTO |
| SEC-013 | Low (latent) | Global guards return `true` for every non-HTTP execution context | CWE-862 | A3 |
| SEC-014 | Low | `pnpm audit --prod`: 2 high + 1 moderate in the Prisma CLI graph (mysql2, deepmerge-ts) | CWE-1395 | A3 + A8 |
| SEC-015 | Info | `material_ui` 1.7.0 adopted one day after publication; no dependency cooldown | CWE-1357 | A2 + A8 |
| SEC-016 | Info | Passwords are not Unicode-normalised (NFC vs NFD login fails) | CWE-176 | A3 / CTO-contract |
| SEC-017 | Info | Unhandled exceptions are logged with the whole error object; redaction is key-based only | CWE-532 | A3 |
| SEC-018 | Info (contract) | Registration discloses account existence (`EMAIL_TAKEN`); architecture doc claims "no account enumeration" | CWE-204 | CTO-contract |
| SEC-019 | Info | Android 12+ device-to-device transfer not excluded; iOS Keychain survives reinstall | CWE-922 | A2 |
| SEC-020 | Info | Android release build type signs with the debug key | CWE-321 | A2 + A8 |
| SEC-021 | Info | CI: `npx --yes @redocly/cli@x` without a lockfile; service images pinned by tag, not digest | CWE-829 | A8 |

---

### SEC-001 — Session revocation without proof of possession (Medium, CWE-306, owner A3)

**Where:** `apps/api/src/modules/auth/sessions.service.ts:125-139`.
`rotate()` treats *any* well-formed refresh token whose secret differs from the current hash as
reuse and revokes the session. The session id is the token prefix and is also the public `sid`
claim of every access JWT (base64, unencrypted), appears in API logs
(`auth.service.ts:169` `logger.warn({ sessionId })`) and in audit rows.

**PoC (executed, `p2.sh` [A]):**
```
sid taken from JWT payload: 01a13fdc-686e-74c5-bce2-6fd01af9ccc5
attacker POST /auth/refresh with <sid>.<random secret> -> "AUTH_REFRESH_INVALID"
victim GET /me with still-unexpired access token -> "AUTH_UNAUTHENTICATED"
victim POST /auth/refresh with its genuine refresh token -> "AUTH_REFRESH_INVALID"
sessions.revoked_reason = REFRESH_REUSE ; audit: auth.refresh.reuse {"matchedPrevious": false}
```
Impact: unauthenticated forced logout of any user whose session id leaks (an *expired* access
token in a crash report, proxy log or screenshot is enough; the attacker can repeat it after each
re-login if they obtain new tokens). No confidentiality/integrity impact. The contract (§6) only
requires revocation when "a previously rotated secret" is presented — the implementation is
stricter than the contract.

**Fix:** revoke only when `presentedHash === previousRefreshTokenHash` (the code already computes
`matchedPrevious`). For any other mismatch return `AUTH_REFRESH_INVALID` without touching the
session (optionally audit `auth.refresh.invalid`). If deeper reuse detection is wanted, keep a
short list of the last N rotated hashes instead of trusting the id alone. Add an e2e test:
"random secret with a valid sid does not revoke the session". No contract change needed.

### SEC-002 — Distributed guessing and Argon2 CPU exhaustion (Medium, CWE-307/CWE-400, owner CTO-contract + A3)

**Where:** limits are `ip|identifier` and `ip` only (`auth.controller.ts:65-72`); IP keys use the
full address (`rate-limit.guard.ts:44`, `request-context.ts:13`); Argon2 runs on libuv's
4-thread pool with no admission control.

**Evidence:** Argon2id verification costs 34.7 ms; 64 parallel verifications took 491 ms
→ **≈ 130 verifications/s per 4-core node** (measured, `UV_THREADPOOL_SIZE` default). Per IP the
contract allows 50 logins / 15 min = 0.056/s, so ~2,300 IPv4 addresses saturate one node's
password hashing (every login, including unknown users, pays Argon2 — required by T14). Any
host with an IPv6 /64 has 2^64 distinct keys and is unlimited. Against a single account there is
no cross-IP cap at all: 1,000 IPs × 10 guesses / 15 min = 40,000 guesses/hour.

**Fix (needs a §7 contract change):**
1. Add a per-account limit independent of IP, e.g. `login:identifier` 30 / 15 min and 100 / day,
   keyed on the *resolved account id* (covers email/username spelling, SEC-009); on breach return
   429 (not a lockout, to avoid victim DoS) and audit it.
2. Bucket IPv6 clients by /64 (`clientIp` → prefix) for all per-IP rules.
3. Cap concurrent Argon2 operations (semaphore ≈ thread-pool size, small queue, 503 when full)
   and set `UV_THREADPOOL_SIZE` explicitly per container size.
4. Phase 2: CAPTCHA/proof-of-work step-up after N failures per account.

### SEC-003 — `TRUST_PROXY=true` makes client IP attacker-controlled (Medium, CWE-348, owner A3 + A8)

**Where:** `env.schema.ts:35-47` accepts `true`; `app.setup.ts:16` passes it to Express, which then
uses the left-most `X-Forwarded-For` entry. Neither the schema nor `DEPLOYMENT.md` warns; the API
README only says "must be set correctly".

**PoC (executed, `trustproxy.mjs`, login limit 3/IP, rotating `X-Forwarded-For`):**
```
TRUST_PROXY=false: 401 401 401 429 429 429
TRUST_PROXY=true:  401 401 401 401 401 401
TRUST_PROXY=1:     401 401 401 401 401 401   (no proxy in front: hop count trusts the client's own header)
```
With the default `false`, spoofing is ignored (also pinned by a regression test).

**Fix:** reject `TRUST_PROXY=true` when `NODE_ENV=production` (require a hop count or explicit
proxy CIDRs); document in `DEPLOYMENT.md` the exact value per platform (e.g. `1` behind exactly
one appending load balancer, or the LB subnet CIDR); add a readiness log line with the effective
setting.

### SEC-004 — Refresh race revokes the winner (Low, CWE-362, owner A3 doc / A2)

**Where:** `sessions.service.ts:126-139` vs `:163-164`; `docs/API_SPECIFICATION.md:31` states
"losing a concurrent race → 401 without revoking".

**PoC (`p2.sh` [B], [C]):** sequential late duplicate → winner's new access token rejected and new
refresh token `AUTH_REFRESH_INVALID`. 20 truly parallel refreshes with one token →
`1 OK, 19 AUTH_REFRESH_INVALID`, session ends `REFRESH_REUSE` (rotation_counter 1). The "no
revoke" branch only applies when the loser read the row before the winner's CAS.

**Risk assessment:** availability only (the user is signed out; no token is issued to the loser).
The mobile client prevents it within one isolate (single-flight + generation counter,
`token_manager.dart`). Remaining triggers: app killed between the server rotating and the
Keystore write; background isolates added later; two app instances restored from the same
backup. A grace window ("previous hash within N seconds → reject without revoking") would weaken
theft detection: if the thief rotates first, the victim's late presentation inside the window
would no longer kill the thief's session.

**Recommendation:** keep the fail-safe behaviour for Phase 1; correct `API_SPECIFICATION.md:31`;
add monitoring of `auth.refresh.reuse` with `matchedPrevious=true` and the time since the last
rotation so the false-positive rate is measured; A2 must keep refresh single-flight across any
future background isolate (e.g. push handlers). Re-evaluate a grace window bound to the same
device (`X-Client` + session device) only if telemetry shows real user impact.

### SEC-005 — Weak JWT secrets accepted (Low, CWE-326, owner A3)

`env.schema.ts:119-127` rejects placeholders and < 10 distinct characters only. PoC (node,
production env): `abcdefghijklmnopqrstuvwxyzABCDEF`, `kabso-live-production-jwt-key-2026!`,
`0123456789012345678901234567890123` → **accepted**; `aaaa…` → rejected. An HS256 key that can be
guessed lets anyone holding one JWT brute-force it offline. Impact is limited by session binding
(a forged token still needs a live `sid` owned by `sub`), but a known victim `sid` plus the key =
full impersonation. **Fix:** require the secret to be base64/base64url/hex that decodes to ≥ 32
bytes (as produced by `openssl rand -base64 48`) in production, or estimate entropy (≥ 128 bits).

### SEC-006 — No `Cache-Control: no-store` on token responses (Low, CWE-525, owner A3)

PoC (`p1.sh`): `POST /auth/login` response headers contain no `Cache-Control`/`Pragma`
(helmet does not set them). RFC 6749 §5.1 and OWASP REST guidance require `no-store` for
responses that carry tokens. **Fix:** global interceptor/middleware setting
`Cache-Control: no-store` on all `/api/v1` responses (they are all user-specific).

### SEC-007 — Cleartext defaults can reach release builds (Low, CWE-319, owner A2)

- `apps/mobile/ios/Runner/Info.plist:74-78` — `NSAllowsLocalNetworking=true` lives in the single
  Info.plist, so it ships in Release (allows HTTP to `.local`/unqualified hosts).
- `apps/mobile/lib/core/config/app_config.dart:22` — `API_BASE_URL` defaults to
  `http://10.0.2.2:3000`; a release built without `--dart-define` silently uses it. There is no
  scheme check.
- Android is correct: `usesCleartextTraffic` only in `android/app/src/debug/AndroidManifest.xml:9`;
  release keeps the platform default (HTTPS only).

**Fix:** move the ATS exception to a Debug-only plist/build setting; in `AppConfig.fromEnvironment`
throw at startup when `kReleaseMode && !apiBaseUrl.startsWith('https://')`; make the release
pipeline pass `API_BASE_URL` explicitly.

### SEC-008 — Unsafe characters in user-supplied labels (Low, CWE-150/CWE-451, owner A3)

`auth.schemas.ts:27,29` (`device.name`, `device.appVersion`) have no character restrictions.
PoC (`p4.sh` [H]): `device.name = "evil\n\u001b[31mred"` accepted and stored verbatim
(`od -c`: `e v i l \n 033 [ 3 1 m r e d`), then returned by `GET /auth/sessions` and rendered in
future session-management UI / admin tools / CSV exports. `displayName` rejects C0 controls but
accepts `U+202E` (RLO) and `U+200B` (zero-width): `"admin‮gnp.exe"`, `"Kab​so Official"`
were accepted. **Fix:** a shared `safeText` refinement rejecting C0/C1 controls, bidi controls
(U+202A–202E, U+2066–2069) and zero-width characters (U+200B–200D, U+FEFF) for every free-text
field; NFC-normalise display names; Phase 2 profile work should add confusable checks for
"official"-looking names.

### SEC-009 — Login bucket per spelling (Low, CWE-307, owner A3)

`auth.controller.ts:69` keys `ip|identifier`; email and username of one account are different
buckets. PoC (`p5.sh`): 10 failures by username → 11th `RATE_LIMITED`; 5 more by the same
account's email → all evaluated (`AUTH_INVALID_CREDENTIALS`). Case/whitespace variants *are*
correctly merged (`bodyField` trims + lowercases). **Fix:** fold into SEC-002 (per-account key
on the resolved user id, applied after lookup).

### SEC-010 — Unkeyed hashes of identifiers in Redis keys (Low, CWE-759, owner A3)

`rate-limit.guard.ts:10-12` uses plain SHA-256 (truncated) of emails/identifiers/IPs. Verified
that keys contain no raw identifiers (regression test), but anyone with Redis read access can
confirm a guessed email/IP by hashing it. **Fix:** HMAC-SHA-256 with a server-side key (e.g. a
`RATE_LIMIT_KEY_SECRET`, or derive from `JWT_ACCESS_SECRET` with HKDF and a label).

### SEC-011 — No least-privilege database role (Low now; blocker for production; owner A8 + A3)

The API and migrations use the same owner role (`DATABASE_SCHEMA.md` "Not yet done"; CI uses
`kabso` for both). `SYSTEM_ARCHITECTURE.md:74` and `DEPLOYMENT.md` §4 state "The API uses a
least-privilege database role" — **documentation does not match reality**. Impact: any future
injection or SSRF-to-DB bug gets DDL rights and can rewrite `audit_logs`. **Fix:** migration
role (owner, DDL) + runtime role with `SELECT/INSERT/UPDATE/DELETE` on app tables, `INSERT/SELECT`
only on `audit_logs`, no `TRUNCATE`/DDL; `ALTER DEFAULT PRIVILEGES` in a migration; mark the docs
"[DESIGNED]" until then.

### SEC-012 — PII retention and cleanup (Low, CWE-359, owner A3 + CTO)

`sessions.ip`, `sessions.user_agent`, `audit_logs.ip` are kept forever; on user deletion
`audit_logs.actor_user_id` becomes NULL but `target_id` still holds the user id and `ip` remains
(`schema.prisma:144-149`). No job deletes expired sessions/tokens (indexes exist). Failed logins
for unknown identifiers store no identifier hash, which limits stuffing investigations. **Fix:**
retention policy (R3/R15 in the model): delete revoked/expired sessions after 30 days, consumed
tokens after 7 days, truncate IPs in audit after 90 days, anonymise `target_id` on account
deletion; optionally store an HMAC of the failed identifier.

### SEC-013 — Guards allow every non-HTTP context (Low, latent, CWE-862, owner A3)

`access-token.guard.ts:26` and `rate-limit.guard.ts:29`: `if (context.getType() !== 'http') return true;`.
Today only HTTP exists, but Phase 6 realtime (WebSocket gateway) or microservice handlers would
be **unauthenticated and unlimited by default**. **Fix:** return `false` (deny) for unknown
context types and add explicit `ws` handling when gateways arrive (R8).

### SEC-014 — Advisories in the production dependency graph (Low, owner A3 + A8)

`pnpm audit --prod` (executed):
```
high      deepmerge-ts <8.0.0   GHSA-ggr8-5vv4-36mx  apps__api>@prisma/client>prisma>@prisma/config>deepmerge-ts
high      mysql2 <3.22.0        GHSA-3f6p-5ww8-9rcr  apps__api>@prisma/client>prisma>mysql2 (installed 3.15.3)
moderate  mysql2 <=3.23.0       GHSA-rgwj-5xj2-c3m3  same path
```
Not reachable at runtime (Postgres adapter; `@prisma/config` only parses trusted local config),
but the Prisma CLI is pulled into the prod graph as a peer of `@prisma/client` and would ship in
a naive runtime image. **Fix:** `pnpm.overrides` for `mysql2@>=3.23.1` and `deepmerge-ts@>=8`
(verify `prisma generate`/`migrate` still work) or upgrade Prisma when fixed; build the runtime
image with `pnpm deploy --prod` and confirm the CLI is absent; add `pnpm audit --prod --audit-level high`
to CI as a non-blocking report first.

### SEC-015 — Fresh `material_ui` release (Info, owner A2 + A8)

`material_ui` 1.7.0 (repository flutter/packages, publisher flutter.dev per task brief) was
published 2026-10-14 and is a direct dependency (`pubspec.yaml:22`). `pubspec.lock` pins
`sha256 27ea1af2…9060`, matching the local pub cache hash. `flutter pub outdated`: direct
dependencies up to date; only transitive/dev updates pending. Risk is low (first-party
publisher) but there is no policy against day-0 releases. **Fix:** Dependabot `cooldown`
(e.g. 7 days for minor/patch) for npm and pub; keep `--enforce-lockfile` in CI.

### SEC-016 — No Unicode normalisation of passwords (Info, owner A3 / CTO-contract)

PoC (`p4.sh` [G]): registered with NFC `café passphrase`; login with the NFC form → ok, with the
NFD form → `AUTH_INVALID_CREDENTIALS`. NIST SP 800-63B §5.1.1.2 recommends NFKC/NFKD
normalisation before hashing. Arabic input methods are generally consistent, so impact is
usability. **Fix (pre-launch, no migration cost yet):** `password.normalize('NFC')` in register,
login and reset; record it in CONVENTIONS §6.

### SEC-017 — Whole error objects in logs (Info, CWE-532, owner A3)

`all-exceptions.filter.ts:13` logs `{ err: exception }`. Prisma validation/known-request errors
include the failing invocation text, which can contain argument values (e.g. hashes, emails);
pino redaction only matches keys. **Fix:** log `name`, `code`, `message` truncated and stack in
non-production only, or add a serializer that strips Prisma `meta`/argument dumps.

### SEC-018 — Registration enumeration (Info, contract decision, owner CTO)

Verified (`p4.sh` [E]): `POST /auth/register` with an existing email in any case → 409
`EMAIL_TAKEN`; login (identical 401, equal timing) and forgot (always 202) do **not** enumerate.
Username availability is public by design. `SYSTEM_ARCHITECTURE.md:74` claims "no account
enumeration" — inaccurate. See §3 for the recommended decision.

### SEC-019 — Device storage edge cases (Info, owner A2)

- `AndroidManifest.xml:10` `allowBackup=false` disables cloud backup, but for `targetSdk ≥ 31`
  it does **not** disable device-to-device transfer. The secure-storage prefs would be copied
  but cannot be decrypted (Keystore keys do not migrate; `resetOnError` clears them) → the user
  is just signed out. Add `android:dataExtractionRules` excluding the secure-storage file for
  clarity.
- iOS Keychain items survive app deletion: reinstalling restores a live session. Consider
  clearing the Keychain item on first launch (flag in `shared_preferences`).

### SEC-020 — Release signed with debug key (Info, owner A2 + A8)

`android/app/build.gradle.kts:37` `signingConfig = signingConfigs.getByName("debug")` for
`release`. Known (template TODO; release prep is [DESIGNED]). Must be replaced by CI-injected
upload key before any store upload (R13).

### SEC-021 — CI supply-chain nits (Info, owner A8)

Strong baseline verified: `permissions: contents: read` (`ci.yml:24`), `pull-requests: read` only
in `changes`, `persist-credentials: false` on every checkout, actions pinned to SHAs, gitleaks
checksum-verified (the scratchpad tarball matched `551f6fc8…70eb`). Nits: `ci.yml:285` `npx --yes
@redocly/cli@2.57.0` resolves transitive deps at run time without a lockfile; service images
`postgres:16.15-alpine`/`redis:7.4-alpine` are tag-pinned, not digest-pinned. Low risk because
the jobs hold no secrets.

## 2. Controls verified as effective (with evidence)

| Control | Evidence |
| ------- | -------- |
| JWT algorithm pinning; `alg=none`, foreign key, wrong `iss`/`aud`/`typ`, expired → 401 | `access-token.service.ts:50-61`; PoC `p1.sh` (`alg:none` → `AUTH_UNAUTHENTICATED`); regression test "rejects alg=none, a foreign key…" |
| Claims trusted only after session lookup; `sub` bound to `sid` | `access-token.guard.ts:39`; regression test "binds sub to sid" (validly signed token naming Bob on Alice's session → 401) |
| Refresh secret entropy and storage | 32 B `randomBytes` (`tokens.ts:9`), SHA-256 hex at rest, `timingSafeEqual` (`tokens.ts:21`); regression test "stores only SHA-256 digests" |
| Rotation CAS: exactly one concurrent winner | `sessions.service.ts:153-164`; PoC 20 parallel → 1 OK |
| Reuse detection of the previous token | existing e2e `auth.e2e-spec.ts` "detects reuse"; PoC `p2.sh` [B] |
| Password reset revokes all sessions, single-use token, old password dead | PoC `p3.sh` [D]: old access → 401, old refresh → `AUTH_REFRESH_INVALID`, replay → `TOKEN_EXPIRED` |
| Argon2id parameters = OWASP minimum, rehash on login | `password-hasher.service.ts:9-14`; stored hash `$argon2id$v=19$m=19456,p=1,t=2$…` (regression test) |
| Long-password DoS prevented | 1 MB password → 400 `payload_too_large`; 129 chars → `too_long` (PoC `p4.sh` [G]) |
| Login timing equalised | 30 interleaved samples: unknown 42.8 ms vs known 42.0 ms (PoC `p4.sh` [F]) |
| Login / forgot do not enumerate | identical `AUTH_INVALID_CREDENTIALS`; forgot unknown → 202 (PoC `p4.sh` [E]) |
| Deny-by-default routing; only 9 public routes | regression tests "only the allow-listed routes are @Public" + "every non-public route answers 401" |
| Session IDOR | foreign `DELETE /auth/sessions/{id}` → 404, victim still valid (PoC `p1.sh`; regression test) |
| Strict schemas, `__proto__`, control chars in `displayName`, nested JSON, text/plain | PoC `p4.sh` [H]; regression test for `__proto__` |
| `X-Request-Id` CRLF/oversize not reflected | PoC `p1.sh`; regression test |
| XFF ignored with default `TRUST_PROXY=false` | PoC `p1.sh` (4th register → 429 despite rotating XFF); regression test |
| Rate-limit normalisation of case/whitespace; `Retry-After` | PoC `p5.sh`: 12 variants → 10 evaluated, then 429, `Retry-After: 900`; forgot variants → `3×202, 1×429` |
| Redis keys hold no raw identifiers | `redis-cli --scan` (PoC `p5.sh`: 0 raw matches); regression test |
| Fail closed without Redis | live instance with Redis unreachable: login → 503 `SERVICE_UNAVAILABLE`, readiness 503; regression test |
| Production refuses `log` mail transport and placeholder secrets | `node dist/main.js` with `NODE_ENV=production` exits 1 listing both problems; regression tests |
| Security headers | helmet defaults on every response (HSTS, nosniff, frame-ancestors, CORP, COOP), `x-powered-by` off |
| Mobile token storage | refresh token only via `FlutterSecureTokenStore` (Keychain `first_unlock_this_device`); access token only in `TokenManager._accessToken`; prefs hold only theme/language (`app_preferences.dart`) |
| Mobile invalidation on `AUTH_REFRESH_INVALID` / `ACCOUNT_SUSPENDED` | `interceptors.dart:101-105`, `token_manager.dart:78,88`; `flutter test test/core` 79 passed |
| Mobile logging | `AppLogger.enabled = kDebugMode`; regex redaction of Bearer/JWT/token fields; HTTP log prints method/path/status only |
| Android cleartext limited to debug | `src/debug/AndroidManifest.xml:9` only |
| Secrets in repo | gitleaks 8.30.1 (`detect`, full history, 22 commits): no leaks; `.gitleaksignore` = 2 fingerprints of literal test fixtures at `d29d958` (inspected); no `.env`/keystore tracked |
| DB indexes for every auth lookup | `users_email_key`, `user_profiles_username_key`, `sessions_pkey`, `sessions_user_id_created_at_idx`, `verification_tokens_token_hash_key`, `verification_tokens_user_id_purpose_idx` (migration `20261015132258_init`) |

## 3. Contract decisions recommended (CTO)

1. **Registration enumeration (SEC-018).** Options:
   - *A. Keep `EMAIL_TAKEN` (status quo)* — best UX, matches most consumer apps; leaks
     membership at 5/h per IP (plus IPv6/botnet scale).
   - *B. Verify-first registration* — `POST /auth/register` always returns 202 "check your
     email"; new addresses get a verification link that completes sign-up, existing addresses get
     "someone tried to register with your email" mail. No enumeration, but needs SMTP (B2), adds a
     step before first login and changes the response shape (no tokens).
   - *C. Keep A but generic message for `EMAIL_TAKEN` on the client* — cosmetic; does not stop
     scripted enumeration.

   **Recommendation:** accept **A for Phase 1** (no production users, no SMTP) with compensating
   controls: SEC-002 IPv6 bucketing, a global per-subnet register limit, and alerting on
   `EMAIL_TAKEN` rate. Schedule **B as a contract v1.1 change when B2 (SMTP) lands**, before
   public launch, if the product owner rates membership disclosure as sensitive (likely for a
   live-streaming social app where harassment targets may hide accounts). Correct
   `SYSTEM_ARCHITECTURE.md` §5 now.
2. **§7 rate limits:** add per-account login limits keyed on the resolved user id and IPv6 /64
   bucketing (SEC-002/SEC-009).
3. **§6 refresh reuse wording:** state explicitly that only the *previous* secret triggers
   revocation and that an unknown secret is a plain `AUTH_REFRESH_INVALID` (SEC-001); document
   that a concurrent duplicate refresh may revoke the session (SEC-004).
4. **§6 passwords:** NFC-normalise before hashing (SEC-016).
5. **§1 transport:** all `/api/v1` responses carry `Cache-Control: no-store` (SEC-006).

## 4. Gate verdict — PASS WITH CONDITIONS

Justification: the core authentication design is sound and verified end to end — pinned JWTs
whose claims are honoured only after a live-session check, hashed 256-bit refresh secrets with
CAS rotation and reuse detection, OWASP-grade Argon2id with timing-equalised failures,
deny-by-default routing with no accidental `@Public`, strict input validation, fail-closed rate
limiting, production refusal of the token-logging mail transport, and correct mobile token
storage. No finding allows account takeover, token forgery or data disclosure across users.

Conditions (must be closed or formally risk-accepted by the CTO before any public beta or
production deployment):

1. SEC-001 fixed (revoke only on previous-hash match) with a regression test.
2. SEC-003 fixed (`TRUST_PROXY=true` refused in production; documented value per platform).
3. SEC-002 decided in the contract and implemented (per-account limit, IPv6 /64, Argon2 cap).
4. SEC-011 least-privilege DB role in place and docs corrected.
5. SEC-007 release-build HTTPS assertion and Debug-only ATS exception.

The Low/Info items are to be scheduled into Phase 2 backlog by their owners.

## 5. Reviewer notes

- All testing ran only against a local instance (`127.0.0.1:3102`, `kabso_sec_test`, Redis
  db 13); the API was stopped and Redis db 13 flushed afterwards. No external host was tested.
- While stopping the PoC server the reviewer used `pkill -f "node dist/main.js"` and later
  `pgrep -f "^node dist/main.js" | xargs kill`; the second command also terminated one other
  `node dist/main.js` process (PID 16769) that was not started by A7 and may have belonged to
  another agent's API instance. Subsequent stops used the recorded PID only.
- gitleaks `git` sub-command could not be invoked in the reviewer sandbox; the equivalent legacy
  `gitleaks detect --source .` (same engine, full git history) was used.

---

## 6. Re-test (2026-10-15) — candidate `3179be1`

Scope: KL-011 (A3, backend), KL-012 (A2, mobile), KL-010 (A8, CI), contract v1.1. Worktree
merged `claude/amazing-tesla-5aj3um` at `3179be1`, `pnpm install --frozen-lockfile`. Resources:
`kabso_sec_test`, Redis db 13, API on port 3102. Each server was stopped by its recorded PID
(`kill <pid>` after `readlink /proc/<pid>/cwd` confirmed it was this worktree's `apps/api`).
Suites at `3179be1` plus this re-test's additions: API unit 133/133, API e2e 118/118 (incl. 23
tests in `test/security/`), mobile `test/core/app_config_test.dart` + `fresh_install_test.dart`
24/24. `gitleaks detect --source .` over 36 commits: no leaks.

### 6.1 Per-finding results

| ID | Result | Evidence |
| -- | ------ | -------- |
| SEC-001 | **FIXED** | `sessions.service.ts:132-141`. The original PoC (`<sid from JWT>.<random 43 chars>`) now gets `AUTH_REFRESH_INVALID`, while the victim's `/me` → 200 and its refresh → rotated. Session stays `live`. Audit row `auth.refresh.invalid_secret` with `actor_user_id NULL`. 0 log lines contain the sid. Genuine reuse of the previous secret still revokes (`REFRESH_REUSE`, audit `{"matchedPrevious": true, "secondsSinceLastRotation": 0}`). See new **SEC-022** for a side effect. |
| SEC-002 | **FIXED** | Default limits; `TRUST_PROXY=loopback` so the PoC can choose the client IP.<br>• Per-account limit: 25 wrong passwords for one account, each from a different IPv4 → `20 × 401, 5 × 429`.<br>• A different account from a fresh IP → OK.<br>• IPv6: 55 logins from 55 addresses in `2001:db8:1:2::/64` → `50 × 401, 5 × 429`; another /64 → 401.<br>• Argon2 cap (`ARGON2_MAX_CONCURRENCY=1`, `ARGON2_MAX_QUEUE=1`): 12 parallel unknown-user logins → `2 × 401, 10 × 503 SERVICE_UNAVAILABLE` with `Retry-After: 1`. 12 parallel registrations → `2 × 201, 10 × 503`. Readiness and later logins unaffected.<br>• Boot log: `trust proxy = false; Argon2 cap = 4 (+16 queued)`.<br>See new **SEC-023** for a side effect. |
| SEC-003 | **FIXED** (residual Low, see 6.2) | `env.schema.ts:179`. Production rejects `TRUST_PROXY=true`, and the effective setting is logged at boot. Still accepted: `1`, CIDR lists, and also `0.0.0.0/0,::/0` or `999`, which behave like `true` behind no proxy (SEC-003a). |
| SEC-004 | **FIXED** (documentation) | `API_SPECIFICATION.md:41` and CONVENTIONS §6 now say that a duplicate arriving after the winner commits revokes the session (intended fail-safe). Re-measured: 20 parallel refreshes → `1 OK, 19 × 401`, session `REFRESH_REUSE`, which matches the docs. The reuse audit now carries `secondsSinceLastRotation` for false-positive telemetry. |
| SEC-005 | **FIXED** | `secret-strength.ts` (base64 only, ≥ 32 decoded bytes, entropy and sequence checks, placeholder words).<br>• All original PoC secrets are refused in production, plus `abc…XYZ0123456789` (62 chars), `aaaa…` and `change-me…`.<br>• False rejections: 0 of 20,000 `openssl rand -base64 48`-style keys; 1 of 20,000 random 32-byte hex keys. A false rejection fails safe at boot (Info).<br>• `RATE_LIMIT_KEY_SECRET` is required, checked the same way, and must differ from the JWT key. |
| SEC-006 | **FIXED** | `app.setup.ts:38`. `Cache-Control: no-store` on a 200 login response and on a 400 body-parser error. |
| SEC-007 | **FIXED** (static; no Xcode/Android SDK here) | • `Info.plist` no longer has `NSAppTransportSecurity`.<br>• The "Debug ATS exception" build phase in `project.pbxproj` adds `NSAllowsLocalNetworking` to the built plist only when `KABSO_ALLOW_LOCAL_NETWORKING=YES` (set only in `Debug.xcconfig`). It fails the build if the variable is set in any other configuration. Release and Profile use `Release.xcconfig`, which does not set it.<br>• `AppConfig.resolve` refuses non-https in release (tests: `HTTP://…` and the dev default refused in release).<br>• `bootstrap.dart` validates the config before installing error handlers. |
| SEC-008 | **FIXED** | `auth.schemas.ts:13` `UNSAFE_TEXT_CHARS`. Rejected with `invalid_format`:<br>• `device.name` containing newline+ESC, U+0085, U+202E, U+200B, U+2066 or U+FEFF<br>• `appVersion` containing NUL<br>• `displayName` containing RLO or zero-width<br>Accepted: Arabic device and display names. |
| SEC-009 | **FIXED** | After the per-account limit is reached by username, the same account by email from a fresh IP → 429. Key = `user:<id>` (`auth.service.ts:113`, `consumeLoginAccountLimits`). |
| SEC-010 | **FIXED** | `rate-limit.service.ts` `keyFor` = HMAC-SHA-256(`RATE_LIMIT_KEY_SECRET`, bucket‖subject). `redis-cli --scan` shows 0 keys containing an account, email, IPv4 or IPv6 string. |
| SEC-011 | **NOT FIXED** (docs corrected) | `SYSTEM_ARCHITECTURE.md:76` and `DEPLOYMENT.md:237` now say "not yet implemented (KL-013)". Still a **production blocker**. |
| SEC-012 | NOT FIXED (not in KL-011 scope) | No cleanup or retention jobs. Remains Phase 2 (R3/R15). |
| SEC-013 | **FIXED** | `access-token.guard.ts:28`, `rate-limit.guard.ts:24`: non-HTTP contexts → `false`. Unit spec `guards-context.spec.ts` passes. |
| SEC-014 | **FIXED** | Root `package.json` `pnpm.overrides`: `prisma>mysql2 3.24.5`, `@prisma/config>deepmerge-ts 8.0.2`. `pnpm audit --prod` → "No known vulnerabilities found". Prisma generate, migrate, build and all suites pass. |
| SEC-015 | **FIXED** | `.github/dependabot.yml` `cooldown: default-days 7, semver-major-days 14`. |
| SEC-016 | **FIXED** | NFC in `passwordSchema`, `loginSchema` and `PasswordHasher`. Registered with NFD, login with NFC → ok, and with NFD → ok. A 128-character `é` password typed in NFD (256 code points) is accepted by the login length check after NFC. |
| SEC-017 | **FIXED** | `safeErrorLog`/`redactText` (`logging/redact-text.ts`) are used in the exception filter, audit, mail and rate limiter. PoC on a Prisma-style message: email, `passwordHash`, `refreshTokenHash` and the refresh token are all `[REDACTED]`. IP addresses are not masked (acceptable). |
| SEC-018 | ACCEPTED (contract v1.1) | Recorded as blocker B9 (`KNOWN_LIMITATIONS.md:14`). The architecture doc wording is corrected. |
| SEC-019 | **FIXED** | • Android: `dataExtractionRules` and `fullBackupContent` exclude `FlutterSecureStorage.xml`, `FlutterSecureKeyStorage.xml` and `FlutterSecureStorageConfiguration.xml` from cloud backup and device transfer. I checked these names against the flutter_secure_storage 11.2.0 sources. The namespaced config file `FlutterSecureStorageConfiguration:FlutterSecureStorage.xml` is not listed; it holds algorithm settings only, no secret (Info).<br>• iOS: `clearSecureStorageOnFreshInstall` runs in `bootstrap.dart`. The flag is set only after a successful clear (4 tests). |
| SEC-020 | **HOLD** | Read only, as instructed. `build.gradle.kts` no longer references the debug key. Release uses `key.properties` or `null` (unsigned), and `verifyReleaseSigning` (hooked to `preReleaseBuild`) fails without a key unless `-Pkabso.allowUnsignedRelease=true`. `key.properties`, `*.jks` and `*.keystore` are git-ignored. The logic looks right, but the script does not compile in CI (`java.util.Properties`, KL-012-D1). Final verdict after the fix is merged. |
| SEC-021 | **FIXED** | Redocly is pinned via `tools/redocly/package-lock.json` (`npm ci --ignore-scripts`). CI service images are digest-pinned (`ci.yml:98,112`). |
| Dummy-hash timing (A3 KL-011-D1) | **FIXED** | `PasswordHasher.onModuleInit` precomputes the dummy hash through the limiter. Three fresh boots each:<br>• first request = unknown user: 126 / 142 / 142 ms; second request ≈ 56–70 ms<br>• first request = known user with wrong password: 224 / 136 / 125 ms; second ≈ 49–62 ms<br>The first-call overhead is the same cold start for both, so there is no first-call side channel. Warm, 30 interleaved: unknown 57.3 ms vs known 55.1 ms. |

### 6.2 New findings

**SEC-022 — Low — CWE-287 — owner CTO-contract + A3: theft detection is lost once the thief rotates twice.**
`sessions.service.ts:132-141` revokes only for the *immediately previous* hash. A secret from
two or more rotations ago is a silent 401. This is intentional per v1.1 and tested in
`kl011-security-fixes.e2e-spec.ts:86`.

PoC (`r1.sh`): the thief uses stolen RT0 → T1, then T1 → T2. The victim then presents RT0 →
`AUTH_REFRESH_INVALID`, and the session stays `live` (rotation_counter 2). The thief's T2 still
rotates, so the thief keeps the session.

Before KL-011, the victim's late RT0 revoked the session. A thief can now defeat reuse
detection with one extra refresh.

Fix (keeps SEC-001 intact):
- Store the last N (e.g. 5–10) rotated hashes, or an `HMAC(secret)` history, per session.
- A hit anywhere in that history → revoke (`REFRESH_REUSE`).
- Only secrets never issued for that session → `invalid_secret` without revocation.

Phase 2 is acceptable. Theft first requires extracting a Keystore/Keychain-protected token.

**SEC-023 — Low — CWE-645 / CWE-204 — owner CTO-contract + A3: the per-account login limit is a targeted lockout and an email↔account oracle.**
`login:account` (20 / 15 min, keyed on the user id) counts every attempt from any IP, before
Argon2. PoC (`r2.sh`): after 20 wrong guesses from 20 different IPs, the real owner with the
*correct* password from a fresh IP gets **429** for up to 15 minutes. The attacker needs only
the public username and 20 requests per window. Existing sessions keep working.

The shared key also acts as an oracle. After exhausting by username `acctuser`:
- `acct@example.com` → `RATE_LIMITED`
- an unregistered email → `AUTH_INVALID_CREDENTIALS`
- another account → `AUTH_INVALID_CREDENTIALS`

So it confirms that a given email belongs to a given (public) username. Each probe costs about
20 requests, locks the target and is audited (`auth.login.rate_limited`).

Recommendations:
- Count only failed attempts in `login:account`.
- Let a client that recently logged in successfully on that account bypass the account bucket (the per-IP+account bucket still applies), using a device-bound marker such as a session-bound device id.
- Phase 2: replace the hard 429 on the account bucket with a CAPTCHA/step-up.

**SEC-003a — Low — CWE-348 — owner A3: trust-everything equivalents are still accepted in production.**
`TRUST_PROXY=0.0.0.0/0,::/0` or a hop count larger than the real proxy chain (e.g. `999`) has
the same effect as `true` and passes validation. Fix: refuse `/0` CIDRs, and hop counts above a
small bound (e.g. > 3), in production.

**Info:**
- The SEC-019 exclusion list omits the namespaced config prefs file (holds no secret).
- SEC-005 hex keys have a ~0.005 % false-rejection rate (fails safe at boot).
- In non-production, `RATE_LIMIT_KEY_SECRET` falls back to a random per-process key (`app-config.ts:75`), so multiple replicas would not share buckets. Staging must set it explicitly.

### 6.3 Regression tests added (all passing at `3179be1`)

In `apps/api/test/security/security-regression.e2e-spec.ts`:
- SEC-008 e2e (device fields and displayName refused, Arabic accepted).
- The SEC-005 PoC secrets added to the production-secret table.
- SEC-003/005/010 production config (generator output accepted for both keys; `TRUST_PROXY=true` refused, `1` accepted; `RATE_LIMIT_KEY_SECRET` required and distinct from the JWT key).

No tests were committed for SEC-022/023 because they are open defects.

### 6.4 Updated gate verdict (excluding SEC-020): **PASS WITH CONDITIONS**

- Conditions 1, 2, 3 and 5 from §4 (SEC-001, SEC-003, SEC-002, SEC-007) are closed with evidence.
- Remaining before any production or public exposure:
  - **SEC-011** least-privilege DB role (KL-013).
  - **SEC-020** final check after KL-012-D1 is merged.
  - The CTO to schedule or risk-accept **SEC-022**, **SEC-023** and **SEC-003a** (all Low; none allows account takeover or cross-user data access).
- Phase 1 can close as an internal milestone.
