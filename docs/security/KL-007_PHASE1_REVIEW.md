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

### 6.5 SEC-020 follow-up — candidate `f2b147e` (KL-012-D1) — **FIXED**

KL-012-D1 changes two lines: `import java.util.Properties` (`build.gradle.kts:1`) and
`Properties()` (`:20`). Nothing else in the signing logic changed since §6.1. Evidence, all in
`apps/mobile/android/app/build.gradle.kts`:

- **No debug key anywhere.** The release build type uses
  `if (hasReleaseSigning) signingConfigs.getByName("release") else null` (`:75-76`). No
  `signingConfigs.getByName("debug")` remains in the file (it was `:37` in `b973d7b`).
- **Release key only from git-ignored `key.properties`.** The file is read at `:18-24`. The
  `release` signing config is created only when the file exists (`:62-69`). Every field is
  required and non-blank via `requiredSigningProperty` (`:29-33`). `key.properties`, `*.jks` and
  `*.keystore` are in both `.gitignore` files.
- **Fail-closed release builds.** `verifyReleaseSigning` (`:83-92`) runs before every
  `preReleaseBuild` (`:95-96`). With no key, it throws unless the explicit opt-out
  `-Pkabso.allowUnsignedRelease=true` (`:26-27`) is passed. That opt-out yields an *unsigned*
  artifact, which Play and the App Store refuse, so it cannot leak a wrongly-signed release.
- **Compile evidence.** CI run 38754642734 (push, `f2b147e`) built and uploaded the debug APK.
  This is as reported by the coordinator; I could not run Gradle here because there is no
  Android SDK (B6).

**A2's caveat (an incomplete `key.properties` breaks every build, debug included):** I assess
this as **acceptable, fail-closed**.
- The file exists only where release signing is intended: the release CI job, which decodes it
  from environment secrets, or a release engineer's machine. A partly written file there is a
  misconfiguration. Stopping with the explicit message "android/key.properties is missing
  '<name>'" is better than silently falling back to an unsigned build or a different key.
- Developers without the file are unaffected (`hasReleaseSigning = false`, `:25`), and the
  debug build in CI proves it.

Residual notes (Info, owner A2/A8):
- (a) A wrong `storeFile` path or a wrong password is caught only at the signing task, not at
  configuration time. Still fail-closed.
- (b) The `preReleaseBuild` hook will need to match `pre<Flavor>ReleaseBuild` if product
  flavours are added later.
- (c) The future release job must write `key.properties` from secrets and delete it (and the
  keystore) at job end, as in `DEPLOYMENT.md` §4.

**Final gate verdict for Phase 1: PASS WITH CONDITIONS.** SEC-020 is closed. Remaining before
production or public exposure:
- **SEC-011** (least-privilege DB role, KL-013).
- The scheduled Low items **SEC-022**, **SEC-023** and **SEC-003a** (CTO).

---

## 7. v1.2 review (KL-007c, 2026-10-16) — candidate `ed84dd4`

Scope: contract v1.2 / v1.2.1 / v1.2.2 as implemented. That covers:
- verify-first registration (B9 / D24, PP-02);
- the SEC-022 / SEC-023 / SEC-003a fixes;
- displayName v1.2.2 (PP-21);
- `PATCH /me` and the mobile changes (PP-22).

How I tested:
- Worktree merged `claude/amazing-tesla-5aj3um` at `ed84dd4`.
- Resources: `kabso_sec_test`, Redis db 13, API on :3102. Each server was stopped by its recorded PID after checking its working directory.
- Temporary files are only in the scratchpad `sec/` directory: `v1.sh`–`v4.sh`, `timing.py`, `dn.mjs`, `run-api.sh`.
- Suites: API unit 233/233; API e2e 166/166 (incl. 41 in `test/security/`, 3 consecutive green runs of that directory).
- `pnpm audit --prod`: no known vulnerabilities. gitleaks (`detect --source .`): no leaks.

### 7.1 Verify-first registration (PP-02)

| Check | Result | Evidence |
| ----- | ------ | -------- |
| Status / body / headers, registered vs new email | **Equal** | Both return `202 {"status":"verification_pending"}`, `Content-Length: 33`, the same ETag `W/"21-4Ssjy…"`. Headers are identical apart from Date and X-Request-Id (`v1.sh`). |
| Timing, `register`, real Argon2 | **Equal** | 80 + 80 interleaved samples in random order. Existing email: median 47.1 ms (p25 44.7, p90 56.9). New email: median 47.7 ms (p25 44.8, p90 53.0). Δmedian −0.6 ms; Mann-Whitney z = +0.45, p = 0.65 (`timing.py 80`). |
| Timing, `register/resend` and `register/verify` | **Sub-ms difference** (SEC-028) | First-time rate-limit keys on both sides, loopback.<br>• resend, live pending vs unknown: 2.8 vs 3.0 ms median, z = −3.09, p = 0.002.<br>• verify, live pending + wrong code vs unknown email: 5.9 vs 6.2 ms, z = −2.51, p = 0.012.<br>This reveals *pending* state only, not account existence (registered vs unknown email on verify: p = 0.43). |
| Rate-limit behaviour | **Equal** | `register:email` (3/h) and `register:ip` are consumed before branching and are keyed on the request email, so a registered and an unknown email get the same limits. |
| Verify error uniformity | **Uniform** | These all return the identical `422 {"code":"TOKEN_INVALID","message":"Token is invalid."}`: unknown email, registered email without a pending, wrong code, and the correct code after the attempts are exhausted. A malformed code (7 digits, fullwidth digits) → 400 `invalid_format`, identical for every email. |
| Mail side channel | **OK** | The account-exists notice goes to the owner in the account's locale, at most 1/h (Redis `SET NX`). The code mail goes to the requester's address. The attacker sees neither. |
| Code generation | **OK** | `crypto.randomInt(0, 10^8)`, zero-padded (`registration.service.ts:372-374`), uniform CSPRNG. |
| Code storage | **OK** | HMAC-SHA-256 over `email\ncode` under `HKDF-SHA256(RATE_LIMIT_KEY_SECRET, salt "kabso", info "registration-code/v1")` (`:80-82`, `:109-111`). The DB row contains neither the code nor a plain SHA-256 of it (regression test). Key separation from the rate-limit HMAC is by HKDF `info`, which is cryptographically sound. Operational coupling is noted in SEC-029. |
| Attempt counting under concurrency | **OK** | Atomic `UPDATE … WHERE attempts < 5 … RETURNING` claims an attempt before comparing (`:213-218`). PoC: 40 parallel wrong codes → exactly 4 `wrong_code` + 1 `attempts_exhausted` for that pending, the row is deleted, and the correct code afterwards → 422. Regression test added. |
| Two concurrent verifies | **OK** | 10 parallel verifies with the correct code → `1 × 201, 9 × 422`, exactly one user row (`createAccount` claims the row with `deleteMany` inside the transaction). |
| Register vs verify race | **OK** | Verify (correct code) in parallel with register (same email, new username) → verify 201, register 202 (it took the existing-account branch), 1 user, 0 pending. |
| Redis down | **Fail-closed** | `register`, `register/verify` and `register/resend` → 503 `SERVICE_UNAVAILABLE`; no pending row is written (`v4.sh`). |
| Background mail task | **OK** | `BackgroundTasks.run` defers to `setImmediate`, logs failures through `safeErrorLog`, and is awaited on shutdown. |
| LogMailSender in production | **OK** | `MAIL_TRANSPORT=log` is still refused by the production schema (re-run). As a second layer, codes and links are scrubbed when `isProduction` (`log-mail-sender.ts`, `mail.spec.ts` "never logs the code in production"). |

Brute-force math (defaults):
- **Per pending:** 5 checks.
- **Per email:** fresh codes come from `register` (3/h per email) and `register/resend` (3/h per email; resend also resets the attempts). That is ≤ 6 codes × 5 = **≤ 30 checks/h per targeted email**. P(success) ≈ 3 × 10⁻⁷ per hour, ≈ 2.6 × 10⁻³ per year of continuous effort, and every code triggers a mail to the real owner.
- **Untargeted** (any address): an attacker IP can create 5 pendings/h (register limit), i.e. ≤ 25 checks/h. With 1,000 IPs that is 2.5 × 10⁴ checks/h → about 2 accounts per year that carry someone else's address as "verified". The real owner can still take such an account over through `password/forgot`.
- Acceptable; see SEC-027 for a cheap hardening.

### 7.2 Findings

**SEC-024 — Medium — CWE-1007 (Insufficient Visual Distinction of Homoglyphs) — owner A3 (+ CTO for the terms list): reserved-term check bypassed by uppercase homoglyphs and missing confusables.**

Where: `confusables.ts:128-129`. The skeleton lowercases *before* mapping. Uppercase Greek and
Cyrillic letters that look exactly like Latin capitals lowercase to letters that are not in
`CONFUSABLES`, so the mapping never sees them.

PoC (`dn.mjs`, run against the built candidate) — all **ACCEPTED**:
- Uppercase homoglyphs: `ADΜIN` (Greek Μ U+039C), `ADМIN` (Cyrillic М U+041C), `KAΒSO` (Greek Β U+0392), `ADMIΝ` (Greek Ν U+039D).
- Lowercase look-alikes missing from the table: `kabsσ` (σ), `kabsօ` (Armenian U+0585), `kabsⲟ` (Coptic), `kabs໐` (Lao zero), `ᴋabso` (U+1D0B), `kabꜱo` (U+A731), `ᏦABSO` (Cherokee), `ꓗABSO` (Lisu).
- Arabic: `كابسۆ` (U+06C6 for و), `ػابسو` (U+063B for ك).

The controls still work: fullwidth, Cyrillic а, spaced, KabsoFan, keheh, tatweel, ZWJ, presentation forms, `adrnin`, combining marks → `reserved_term` (regression tests added for these).

Impact: staff or brand impersonation in a live-streaming app (scams such as "ADΜIN: send coins to verify").

Fix:
1. Map before *and* after case folding, or follow UTS #39 exactly (NFD → confusables mapping on the original case → NFD; then casefold).
2. Generate `CONFUSABLES` from `confusables.txt` instead of a hand-picked subset. Vendor the file with a pinned SHA-256 (it is ~600 kB of data; a build script can produce a compact JSON for Latin/Greek/Cyrillic/Arabic/Armenian/Cherokee/Lisu targets).
3. Add the UTS #39 §5.2 mixed-script restriction ("Moderately Restrictive": a single word may not mix Latin with Greek/Cyrillic, or Arabic with other scripts). This closes most of the long tail without an exhaustive table.

Assessment of the hand-written subset: the reasons given (no maintained npm package, unicode.org unreachable from the build environment) are factual. The algorithm structure is sound, and applying the same function to the input and to the terms is correct. But the subset is too small and the case-ordering bug defeats it with standard capital-letter homoglyphs. A vendored data file with a checksum is the right fix — a package is not required.

**SEC-025 — Low — CWE-204 (Observable Response Discrepancy) — owner A3 / CTO-contract: pending-registration email oracle via the username check.**

Where: `users.service.ts:198-210`. `isUsernameTaken(username, exceptEmail)` ignores a live
pending registration that belongs to the request's own email.

PoC (`v1.sh`): `carol@example.com` has a pending registration holding username `carol01`.
- `register(guess@…, carol01)` → 409 `USERNAME_TAKEN`
- `register(carol@example.com, carol01)` → 202

The 202 confirms that this email is mid-registration with that username. The attacker's request
also **replaces** Carol's pending registration, so her code becomes invalid. Usernames of accounts
are not affected (an account's username is taken for every email, including its own; verified).

Fix:
- Do not special-case the same email. Treat a username held by *any* live pending registration as taken, except when the request carries the same email **and** the same username — and make that case also replace the row silently (the response is 202 either way).
- Or evaluate username availability *after* the email branch and return 202 for any email whose pending registration already holds that username.

**SEC-026 — Low — CWE-400 / business logic — owner A3 + CTO-contract: indefinite username squatting without owning a mailbox; targeted sign-up DoS.**

Where: `registration.service.ts:279-284`. `resend` sets `expiresAt = now + 30 min` and resets
`attempts`.

PoC: the pending registration for `carol01` had `expires_at` 09:09:11.677. After `resend` it was
09:09:13.845 with `attempts = 0`. One resend every 25 minutes (limit 3/h per email) keeps a
username reserved forever, with any made-up address. The username stays unavailable to everyone
else, including `users/username-availability`.

Related: `register:email` (3/h) is shared by the address owner and an attacker. An attacker who
spends the 3 slots for a victim's address (also replacing the victim's pending, see SEC-025)
makes the owner's own `register` return 429 for that hour.

Fix:
- Cap a pending registration's total lifetime (e.g. `created_at + 30 min`, or at most 2 h); resend should not extend it.
- Count replacements per email separately from the owner's resend.
- Optionally do not reserve the username until the first code check succeeds (the contract's anti-duplicate goal is still met by the unique index at verify).

**SEC-027 — Low — CWE-307 — owner A3: no per-email budget for verify attempts.**

Only `register_verify:ip` (10/15 min) applies. Per email the attempt budget is bounded only
indirectly, through `register`/`resend` replacements (≤ 30 checks/h, §7.1).

Fix: add a per-email verify budget (e.g. 15 checks / 24 h, counting failures) and alert on
`auth.registration.verify_failed` bursts per email.

**SEC-028 — Info — CWE-208 — owner A3: sub-millisecond timing differences on `register/resend` and `register/verify` reveal whether a pending registration exists.**

Measured on loopback: Δmedian 0.2–0.3 ms, p ≤ 0.012 with 80 samples per side. Internet jitter makes
this impractical, and SEC-025 already leaks pending state more directly. It does **not** reveal
account existence.

Optional fix: do the same Redis/DB work on both branches (e.g. a dummy `updateMany` for unknown
emails), or move all of resend's work into the background task, as `register` already does.

**SEC-029 — Info — owner A3 / A8: code key derived from `RATE_LIMIT_KEY_SECRET`.**

The HKDF separation is correct, but the coupling has operational consequences:
- Rotating the rate-limit key silently invalidates every pending code (≤ 30 min impact).
- A non-production process without the variable falls back to a random per-process key (`app-config.ts`), so multi-replica staging cannot verify codes issued by another replica.

Fix: document both effects in DEPLOYMENT, or introduce `REGISTRATION_CODE_KEY_SECRET` (required in production).

**SEC-022 (re-test) — PARTIAL — Low — CWE-287 — owner CTO-contract + A3.**

PoC (`v2.sh`):
- Thief rotations 2 / 5 / 10, then the victim presents RT0 → session `REFRESH_REUSE`; the thief's next refresh → 401. Audit records `rotationsAgo` 2 / 5 / 10. **Fixed for ≤ 10.**
- 11 or 12 rotations → the victim's RT0 → 401 but the session stays **live** and the thief keeps rotating. Eleven rotations took 172 ms and stay within the 60/15 min refresh limit.

Bounded history therefore still lets a thief evade detection at negligible cost.

Fix options:
- Embed a monotonically increasing generation in the token (`<sid>.<gen>.<secret>`). Any presented token with `gen < current` and a valid HMAC/hash is reuse. Only the generation counter needs to be stored.
- Or enforce a minimum refresh interval (e.g. ≥ 60 s between rotations), so 11 rotations take ≥ 10 min — longer than a typical victim refresh gap.

A regression test pins the ≤ 10 behaviour.

**SEC-023 (re-test) — PARTIAL — Low — CWE-645 / CWE-204 / CWE-362 — owner A3 + CTO-contract.**

PoC (`v3.sh`, defaults, `TRUST_PROXY=loopback`):
- **Fixed (owner lockout from trusted sources):** 25 failures from 25 IPs → `20 × 401, 5 × 429`. The owner from a previously successful source with the correct password → **OK**.
- **Still open:**
  - The owner from a *new* source → 429 (owners logging in on a new network stay locked for up to 15 min).
  - The email↔account oracle remains: after the bucket is exhausted, `alice@example.com` → 429 while an unregistered email → 401.
- **Race (A3's non-atomic peek/increment) — exploitable:**
  - 60 parallel wrong passwords from 60 IPs against a fresh account (limit 20 failures) → `39 × 401, 10 × 429, 11 × 503`.
  - 39 password guesses were actually checked (39 `auth.login.failure` rows), about **2×** the limit in one burst. Only the Argon2 queue cap (4 + 16) bounded it.
  - The overshoot scales with the number of API replicas (each has its own Argon2 cap), and the burst can be repeated every window.
- **Trusted-source sharing:** a source address is shared behind CGNAT/NAT. An attacker on the owner's trusted IPv4 bypasses the account bucket and is limited only by IP+account (10/15 min).

Fix:
- Reserve before checking: `INCR` the account bucket atomically when the attempt starts (refuse if the result exceeds the max); `DECR` it again after a successful login. This keeps "failures only" semantics without a race.
- Narrow the trusted source to source **and** device (a signed device id stored with the session) rather than the IP alone.

**SEC-003a (re-test) — PARTIAL — Low — CWE-348 — owner A3.**

`env.schema.ts:218-235` now refuses hop counts > 3 and `/0` CIDRs. PoC (production schema):
- These **are still accepted**:
  - `0.0.0.0/1,128.0.0.0/1` and `::/1,8000::/1` — they cover every address.
  - `::ffff:0:0/96` — trusts every IPv4 client on a dual-stack listener.
- Correctly accepted: `3`, `1`, `10.0.0.0/8`. Refused: `true`, `4`, `0.0.0.0/0`, `::/0`, `0.0.0.0/00`.

Fix: refuse IPv4 prefixes shorter than /8 and IPv6 prefixes shorter than /32, and `::ffff:0:0/96` itself, in production. Or compute the union and refuse configurations that cover public address space.

**displayName — other checks (PP-21):**
- **Word-boundary design gaps (Info, CTO-contract):** these are accepted by design (v1.2.2 rule b covers only prefixes/suffixes): `TheKabsoTeam`, `فريقكابسوالرسمي` ("Kabso official team" written as one word), `OfficialSupport` (two reserved terms glued together), `admin1`. Consider "brand anywhere inside a word" for the two brand terms, which have few false positives, and splitting on Latin case changes (camelCase).
- **Bidi marks (Info):** U+200E LRM, U+200F RLM and U+061C ALM are accepted (only overrides and isolates are banned). They cannot reorder text the way overrides can, but they can make two names render identically. Strip them, or ban them outside Arabic-script context.
- **DoS:** fine. Worst case is 4.0 ms per call for a 100 kB combining-mark string. The 100 kB body limit applies first, and the code-point check runs before grapheme segmentation. Regression test with a 250 ms bound.

### 7.3 `PATCH /me` and mobile (PP-22)

| Check | Result | Evidence |
| ----- | ------ | -------- |
| `PATCH /me` auth | **OK** | No token → 401 `AUTH_UNAUTHENTICATED`. Rate limit 30/h per user. |
| `PATCH /me` mass assignment | **OK** | `updateMeSchema = z.strictObject({ locale })`. `role`, `email`, `username`, `displayName`, `__proto__` → 400 `unknown_field`; `locale:"fr"` → `invalid_value`; `[]` → `invalid_type`. DB afterwards: `role = USER`, email/username unchanged. Only `user_profiles.locale` is written (`users.service.ts` `updateLocale`). Regression test added. |
| Code-entry paste sanitization | **OK** | `code_field.dart` `normalizeCodeDigits` keeps ASCII digits and maps Arabic-Indic and Extended Arabic-Indic digits to ASCII; everything else is dropped (spaces, NBSP, bidi marks, letters). The value is capped at 8 digits. A paste that is not exactly 8 digits is flagged `_pasteInvalid` and not auto-submitted. The field is forced LTR. The server independently enforces `^[0-9]{8}$`. |
| Locale sync | **OK** | `locale_sync.dart`: `PATCH /me` only with a value from `AppLanguage`. It stores only the boolean `pref.localeSyncPending` in shared_preferences. 400 drops the retry; other failures retry later. |
| Registration draft | **OK (Info)** | `registration_flow.dart` keeps email, username, displayName and **password** in Riverpod memory only, while the flow is open. It is never persisted and is cleared on success or exit. Acceptable; consider clearing the password from the draft once the code screen is shown, if "Change email" does not need it. |
| Debug gallery unreachable in release | **OK** | `app_router.dart:66-72`: the route is registered only `if (!kReleaseMode)`. `kReleaseMode` is a compile-time constant, so the route and `ComponentGalleryScreen` are tree-shaken. The only other entry point, `settings_screen.dart:115-122`, is also `!kReleaseMode`. The screen asserts `!kReleaseMode`. The route is not in `publicAuthRoutes`, so even in debug it needs a session. |
| Test fixtures not in `lib/` | **OK** | No `flutter_test`, `test/` or `helpers/` imports, `contract_fixtures` or fake HTTP adapters in `lib/`. The only sample data lives in `features/debug` (debug-only, tree-shaken) and in `live_view_data.dart` (data classes, no credentials). No hard-coded emails or passwords in `lib/` (grep). |

### 7.4 Controls verified as effective (v1.2)

- Constant register response, with equal Argon2 cost and equal latency (statistically indistinguishable).
- Uniform 422 on every verify failure.
- CSPRNG 8-digit code, stored as an HKDF-keyed HMAC.
- Atomic attempt claim (≤ 5 checks under 40-way concurrency).
- Single account under 10-way concurrent verify.
- Register/verify race safe.
- Fail-closed without Redis.
- Owner notice throttled; production log transport refused and scrubbed.
- SEC-022 for ≤ 10 rotations.
- SEC-023 failures-only counting and trusted-source bypass.
- SEC-003a for `true`, `/0` and hop counts > 3.
- `PATCH /me` strict schema plus auth.
- displayName controls (fullwidth, single-script Cyrillic lowercase, spacing, brand prefix/suffix, Persian/Arabic variants, tatweel, joiners, presentation forms, marks); bounded DoS cost.
- Mobile paste sanitization; release-only exclusion of the debug gallery.

Regression tests added: `apps/api/test/security/kl007c-v12.e2e-spec.ts` (18 tests, all passing on `ed84dd4`).

### 7.5 Verdicts

| Package | Verdict | Conditions |
| ------- | ------- | ---------- |
| **PP-02** verify-first registration | **PASS WITH CONDITIONS** | B9 itself is met: account existence is not revealed through status, body, headers, timing or rate limits. Before public launch: fix SEC-025 (pending-email oracle) and SEC-026 (unbounded reservation via resend). SEC-027/028/029 to the backlog. |
| **PP-21** displayName v1.2.2 | **FAIL (one Medium finding)** | SEC-024: trivial uppercase-homoglyph bypasses of the reserved terms (`ADΜIN`, `KAΒSO`) defeat the purpose of the rule. Re-test after the case-ordering fix plus a generated confusables table or a mixed-script restriction. Everything else in PP-21 passes. |
| **PP-22** PATCH /me, locale, mobile | **PASS** | No findings. Info: shorten how long the password stays in the registration draft. |

Carry-over (unchanged gate items): SEC-011 least-privilege DB role. SEC-022, SEC-023 and SEC-003a
are PARTIAL (Low) and are documented above with their remaining fixes.

---

## 8. Re-test of the KL-024 fixes (KL-007d, 2026-10-16) — candidate `0051b3a`

Scope: contract §9 v1.2.3, v1.2.4 and v1.2.5.

How I tested:
- Worktree merged `claude/amazing-tesla-5aj3um` at `0051b3a`.
- Resources: `kabso_sec_test` (migrations applied), Redis db 13, API on :3102. Each server was stopped by its recorded PID after a `readlink /proc/<pid>/cwd` check.
- Scripts are only in the scratchpad `sec/` directory: `dn2.mjs`, `v5.sh`–`v7.sh`, `run-api.sh`.
- Suites: API unit 297/297; API e2e 309/309, two consecutive runs (incl. 102 in `test/security/`).

### 8.1 Per-finding results

| ID | Result | Evidence |
| -- | ------ | -------- |
| SEC-024 | **FIXED** (residual Low: SEC-030, SEC-031) | All 14 KL-007c bypass strings are now rejected: the 4 uppercase homoglyphs, the 8 missing look-alikes and the 2 Arabic letters (12 `reserved_term`, plus mixed-script `invalid_format` where applicable; `dn2.mjs`). Brand inside a word (`TheKabsoTeam`, `فريقكابسوالرسمي`) → `reserved_term`.<br>New probes also rejected: all-Cyrillic `КАВЅО`, all-Cherokee `ᏦᎪᏴᏚᎾ`, math bold, circled letters, madda, harakat, Urdu letters, `Adm1n`, `Kab‌so`, `kabsօ fan`, `Kabso🔥`.<br>**Data:** `data/confusables.txt` sha256 `091c7f82fc39ef208faf8f94d29c244de99254675e09de163160c810d13ef22a` (local `sha256sum`), header "Version 17.0.0 / 2025-07-22", 6,565 `MA` lines. `confusables.spec.ts` checks the hash and that the generated table matches a fresh generation (unit tests pass). I cannot reach GitHub, so the upstream identity rests on the CTO's comparison.<br>**Supplement review:** `i→l`, `ĸ→k`, `U+063B/063C→ك`, `ة→ه` are applied identically to names and terms, so they can only make matching stricter. They are correct and needed (the UTS #39 table maps capital I and 1 to l but not i; κ/к/ᴋ map to ĸ).<br>**Ordering:** the mapping runs before *and* after case folding (`confusables.ts` `confusableSkeleton`), which fixes the KL-007c root cause.<br>**Mixed-script rule:** `script-mixing.ts` intersects augmented Script_Extensions per word and ignores Common/Inherited. Unknown (post-ICU) code points get a unique script, so they fail closed when mixed. |
| SEC-025 | **FIXED** | Username held by a pending registration: other email → 409, *same* email → 409, identical body. The pending row is untouched (`v5.sh`). Regression test added. |
| SEC-026 | **FIXED** (residual Info) | Resend at created_at + 115 min → `expires_at` = created_at + 2 h exactly. Resend at +121 min → nothing changes (returns early). `total_attempts` reaches 10 across codes (4 + resend + 4 + resend + 2), then the row is deleted and the fresh code from the last mail → 422 (`v5.sh`). Regression tests added.<br>Residual (Info): after the 2 h cap a squatter can register the same username again, since lazy deletion frees it on the next register. Holding a name now takes one new `register` per 2 h (the per-email and per-IP limits still apply). Acceptable. |
| SEC-027 | **FIXED** | 17 verify attempts for one email from 17 different IPs → `15 × 422, 2 × 429` (`register_verify:email` 15/86400, counted before the check). Regression test added. A3's `RATE_LIMIT_REGISTER_VERIFY_EMAIL: GENEROUS` in `test/helpers/test-app.ts` is correct for my KL-007c concurrency test: that test is about the 5-checks-per-code cap, and still counts exactly ≤ 5 `wrong_code`/`attempts_exhausted` audit rows for its own pending (filtered by `targetId`). |
| SEC-023 (race) | **FIXED** | 60 parallel wrong passwords from 60 IPs → `20 × 401, 40 × 429`; **exactly 20** password checks (20 `auth.login.failure` rows), down from 39 at KL-007c. Increment-before-check (`consume` = atomic INCR, refuse when > max). Regression test added (`TRUST_PROXY=loopback` + XFF, ≤ 20 checks). |
| SEC-023 (refund semantics, v1.2.5 note 4) | **Not exploitable** | The refund `DECR`s one slot via Lua and never goes below 0 (`rate-limit.service.ts` `REFUND_SCRIPT`). It is called only for an attempt that holds a reservation (`limits.reserved`).<br>• **Argon2 503:** with `ARGON2_MAX_CONCURRENCY=1, QUEUE=0`, 5 bursts × 40 parallel wrong passwords gave `5/5/4/4/1 × 401`, the rest 503/429. **19 password checks in total** (≤ 20): a 503 refunds a slot for which no password was checked, so the attacker gains nothing.<br>• **SUSPENDED:** 19 wrong guesses, then 3 × correct password (`ACCOUNT_SUSPENDED` each, each refunding only its own slot), then 3 more wrong guesses → `401, 429, 429`. Failures stay capped at 20. The 403 confirms the password, but that is the contract's intended behaviour for suspended accounts (§4), not a new oracle. Repeating the correct password is bounded by the IP+account bucket (10/15 min).<br>• Edge: a refund that straddles a window boundary decrements the new window's counter (at most +1 guess per straddling success). Negligible. |
| SEC-023 (residual) | **OPEN** (B11, accepted by CTO) | Owner from a new source with the correct password → 429 after an attack. The email↔account oracle remains: after exhaustion, `alice@` → 429 while an unknown email → 401 (`v5.sh`). Tracked as B11. |
| SEC-003a | **FIXED** | Production schema refuses `0.0.0.0/1,128.0.0.0/1`, `::/1,8000::/1`, `::ffff:0:0/96`, `::ffff:0.0.0.0/96`, `0.0.0.0/7`, `2000::/16` and `4`; accepts `1`, `3`, `10.0.0.0/8`, `2001:db8::/32`, `loopback`.<br>I also probed `::/64`, `::ffff:0:0/64`, `::/80` (accepted by the schema). With the installed `proxy-addr@2.0.8` they do **not** trust IPv4 or IPv4-mapped clients (`compile(...)('203.0.113.9')` and `('::ffff:203.0.113.9')` → false), so there is no bypass. Only `::ffff:0:0/96` itself maps onto all of IPv4, and it is refused. Info: the validator's completeness relies on proxy-addr's mapping semantics; re-check on proxy-addr upgrades. |
| SEC-029 | **FIXED** | Optional `REGISTRATION_CODE_KEY`: in production it must pass `productionSecretProblem` and differ from `JWT_ACCESS_SECRET` and `RATE_LIMIT_KEY_SECRET` (weak / equal values refused, random accepted). The HKDF uses it when set (`registration-code-key.spec.ts`). Rotation effects are documented in the env schema comment and CONVENTIONS v1.2.3. |
| LRM / RLM / ALM | **FIXED** | U+200E, U+200F and U+061C in displayName → `invalid_format` (`display-name.ts` `BANNED`). Regression test added. |

### 8.2 Residual findings (new)

**SEC-030 — Low — CWE-1007 — owner A3: single-script small-capital spoofs.**

The UTS #39 table does not map Latin small capitals to their letters. The Cyrillic в maps *to* ʙ.
Single-script words therefore pass the mixed-script rule and keep a skeleton different from
`kabso`.

PoC (`dn2.mjs`):
- `ᴋᴀʙꜱᴏ` (Latin small caps; reads clearly as KABSO) → **ACCEPTED**, skeleton `kᴀʙso`.
- `кавѕо` (all-Cyrillic lowercase) → **ACCEPTED**, skeleton `kaʙso`.

Not convincing, and not counted: `ΑΔΜΙΝ` and `Ѕиррогт`, which are visually distinct.

Fix: add the Latin small capitals to `SUPPLEMENT` after folding (U+1D00–U+1D22, ʙ U+0299, ɢ U+0262,
ʜ U+029C, ɪ U+026A, ʟ U+029F, ɴ U+0274, ʀ U+0280, ʏ U+028F, ꜰ U+A730, ꜱ U+A731) → base letter.
Like the rest of the supplement, this only makes matching stricter.

**SEC-031 — Low — CWE-1007 / design (CTO-contract): brand split by separators plus any other word.**

Rule (c) only matches when the *whole* name equals a term once separators are removed. PoC —
all **ACCEPTED**:
- `K a b s o Team`
- `Kab-so Live`
- `K.a.b.s.o Fan`
- `Kab·so Live`
- `ك ا ب س و لايف`

Fix (keeps "Kab Sonia" allowed):
- Concatenate runs of words joined by non-space separators (`-`, `.`, `·`, `_`), and runs of single-letter words, before applying the brand-contains rule (b).

**SEC-032 — Info — owner CTO-contract / A3: false positives in the new rules.**

- **Mixed-script `invalid_format` on plausible nicknames:**
  - Latin plus Arabic-Indic or Persian digits in one word (`Ali٣`, `Ahmed۲۰۲۴`).
  - Latin plus CJK/Hangul (`TOKYO東京`, `Ｊ太郎`, `iPhone大好き`, `Kim김`).

  UTS #39 "Highly Restrictive" allows Latin + Han + Hiragana + Katakana and Latin + Han + Hangul. Treating decimal digits (`\p{Nd}`) of any script as script-neutral would remove the digit cases.
- **Brand-inside rule:** `كابسولة` (colloquial "capsule") and `Kabsoon` → `reserved_term`. That is the accepted cost of rule (b) for the two brand terms.
- **Generic term `رسمي`:** rejected as a whole word, but "Rasmi" (رسمي) is also an Arabic given name. Consider dropping it from the list, as v1.2.4 did for `مشرف`.

Legitimate names checked and **accepted**: `Sara سارة`, `محمد علي`, `Zoë Đorđević`,
`Işık Yılmaz`, `Nguyễn Văn An`, `Γιώργος`, `Алексей Смирнов`, `田中さん`, `김민수`, `राम कुमार`,
`שרה`, `می‌خواهم` (ZWNJ), `Kab Sonia`, `Badminton Club`, `Supporter`, `Stafford`, `مشرف`, `staff`,
`Rasmi`, `DJ Ахмед`, `Ali🔥`, a family emoji, `O’Brien`, `Jean-Luc`.

Cost: at most 3.4 ms per call for a 100 kB combining-mark string; 0.04 ms for a 100-code-point mixed-script name.

### 8.3 Regression tests added (all passing at `0051b3a`)

`apps/api/test/security/kl007d-v123.e2e-spec.ts`:
- **SEC-024:** all 14 KL-007c spoofs plus 6 new ones rejected; LRM/RLM/ALM rejected; 20 legitimate multilingual names accepted.
- **SEC-025:** identical 409 for the same and for another email.
- **SEC-026:** the 2 h cap, and 10 checks across resends.
- **SEC-027:** 15 per day per email.
- **SEC-023:** 60 parallel → ≤ 20 password checks.
- **SEC-003a:** ranges refused and accepted.
- **SEC-029:** key validation.

No tests were added for SEC-030/031/032 because they are open.

### 8.4 Updated verdicts

| Package | Verdict | Notes |
| ------- | ------- | ----- |
| **PP-02** verify-first registration | **PASS** | SEC-025, SEC-026, SEC-027 and SEC-029 are fixed with evidence. The KL-007c controls still hold (constant response, uniform 422, atomic attempts, fail-closed). SEC-028 (sub-ms pending-state timing) remains Info. |
| **PP-21** displayName v1.2.2–v1.2.5 | **PASS WITH CONDITIONS** | The Medium (SEC-024) is fixed. Before public launch: SEC-030 (small-caps supplement, a one-line table addition) and a CTO decision on SEC-031 (separated brand plus another word) and SEC-032 (false positives on digits and CJK + Latin). |
| **PP-22** `PATCH /me`, locale, mobile | **PASS** | Unchanged since KL-007c. |

### 8.5 Open items for the pre-production checklist

1. **SEC-011** — least-privilege runtime DB role (KL-013). **Blocker.**
2. **SEC-022** — PARTIAL. A thief who rotates ≥ 11 times (≈ 170 ms) evades reuse detection. Fix: token generation number, or a minimum refresh interval.
3. **SEC-023 residual / B11** — owner lockout from new sources, and the email↔account oracle after an exhausted account bucket (CTO-accepted, tracked as B11). The race and refund semantics are fixed and not exploitable.
4. **SEC-030 / SEC-031 / SEC-032** — displayName residuals (Low/Info), as above.
5. Unchanged Phase 2 items: SEC-012 retention/cleanup jobs; SEC-028 timing (Info).

---

## 9. Re-test of SEC-030/031/032 (KL-007e, 2026-10-16) — candidate `b19ab0c`

Contract v1.2.6 / v1.2.7 (KL-025, merge `578e9a4`).

How I tested:
- Worktree merged `claude/amazing-tesla-5aj3um` at `b19ab0c`.
- Probes ran against the built `dist/` (`scratchpad/sec/dn3.mjs`). No server was needed (pure validation logic), so none was started.
- Suites: API unit 323/323, API e2e 355/355 (incl. the new `test/security/kl007e-v126.e2e-spec.ts`).

### 9.1 Results

| ID | Result | Evidence |
| -- | ------ | -------- |
| SEC-030 | **FIXED** | `ᴋᴀʙꜱᴏ`, `кавѕо` and `ᴀᴅᴍɪɴ` → `reserved_term`. Small capitals are mapped before the first confusables pass (`confusables.ts` `SMALL_CAPITALS`). |
| SEC-031 | **FIXED** | `K a b s o Team`, `Kab-so Live`, `K.a.b.s.o Fan`, `Kab·so Live`, `ك ا ب س و لايف`, `Ad-min Ali`, `A D M I N Ali` → `reserved_term`. The same holds for NBSP- and ideographic-space-split runs, fullwidth letters, `Kab/so`, `Kab+so`, `(Kab)(so)`, `K'a'b's'o`, `Kab🔥so` and `Kab⠀so` (braille blank). `Kab Sonia` and `Kab So Nia` stay accepted. |
| SEC-032 | **FIXED** | `Ali٣`, `Ahmed۲۰۲۴`, `TOKYO東京`, `Kim김`, `Ｊ太郎`, `iPhone大好き` and `رسمي` → accepted. Latin + Cyrillic/Greek inside one word is still `invalid_format` (regression test). |
| Accepted residuals (v1.2.6/v1.2.7) | Noted, not re-filed | `كابسولة` → `reserved_term`. Mixed partial splits are accepted: `Kabs o Live`, `Ka b so Live`, `Ka bs o Live`. |

### 9.2 New residual findings (Low)

**SEC-033 — Low — CWE-1007 — owner A3: an empty chunk breaks the single-letter run.**

Where: `confusables.ts` `joinedWords()`. A space-delimited chunk that is empty after the skeleton
calls `flush()`, which ends the run of single letters. Examples of such chunks: punctuation
only, a lone combining mark, a tatweel, an emoji.

PoC — all **ACCEPTED**:
- `K . a b s o Live`
- `K - a b s o Live`
- `K ̃ a b s o Team` (U+0303 on its own chunk)
- `ك ـ ا ب س و لايف` (tatweel chunk)
- `K 🔥 a b s o Team`

The first four still read as the brand.

Fix: skip empty chunks (`continue` without `flush()`) when they sit between single-letter chunks.
Only a chunk containing a multi-letter word should end a run.

**SEC-034 — Low — CWE-1007 — owner A3: the v1.2.6 script relaxations re-admit look-alikes that the mixed-script rule used to catch.**

1. **Decimal digits of any script are now script-neutral.** Zeros that render as a circle but are not in `confusables.txt` now pass inside a Latin word:
   - `kabs᱐` (Ol Chiki U+1C50)
   - `kabs᭐` (Balinese U+1B50)
   - `kabs꧐` (Javanese U+A9D0)
   - `kabs꯰` (Meetei Mayek U+ABF0)
   - `kabs༠` (Tibetan U+0F20)
   - `kabs᠐` (Mongolian U+1810)

   An exhaustive scan of every Nd block found **57 zeros accepted in `kabs<0>`**. Most do not look like "o"; the ones above do. Under v1.2.5 all of them were `invalid_format` (mixed script).

   Fix: make neutral only ASCII digits plus the digits SEC-032 needed (Arabic-Indic U+0660–0669, Extended Arabic-Indic U+06F0–06F9). Alternatively, map every Nd zero to `o` and every Nd one to `l` in the supplement.

2. **Latin + Han/Hangul/Bopomofo/Katakana in one word.** CJK strokes and circles that look like Latin letters pass:
   - `kabsㅇ` (Hangul ieung U+3147), `kabsᄋ` (U+110B)
   - `admㅣn` (Hangul I U+3163)
   - `admㄧn` (Bopomofo I U+3127)
   - `adm丨n` (Han U+4E28)
   - weaker: `kabsロ`, `kabs口`, `admエn`

   Fix: add these to the supplement: ㅇ ᄋ ᆼ → o; ㅣ ᅵ ㄧ 丨 → l; optionally ロ 口 → o. Or allow the Latin + CJK combination only when the Latin part of the word is not a prefix or suffix of a reserved term.

**Info — new false positives from joining (rare):**
- A brand straddling a hyphen inside a compound name is now reserved: `Ali Kab-Sonia`, `Abakab-Sorensen`.
- Initials joined by rule (c) (`S. U. P. Port`, `Ad Min`) were already reserved before v1.2.6.
- No false positives found on `J R R Tolkien`, `محمد و علي`, `O.K. Computer`, `K. Abson`, `Ka B. Sonnet`, `D. J. Kab`, `A. D. Minh`, `Ad-Minh Tran`, `Sup-Porter`.

### 9.3 Final PP-21 verdict: **PASS**

- Every finding from KL-007c and KL-007d (SEC-024, SEC-030, SEC-031, SEC-032) is fixed with evidence, and there are no new false positives on real names.
- The two new residuals (SEC-033, SEC-034) are Low. Each needs a deliberately crafted string, and their fixes are a few lines each; the reserved-term rule is also defence in depth behind moderation and verified badges.
- I recommend fixing them before public launch, but they do not gate PP-21.

Regression tests: `apps/api/test/security/kl007e-v126.e2e-spec.ts`. Every SEC-030/031 spoof above is rejected; the SEC-032 names and no-false-positive names are accepted; Latin + Cyrillic/Greek in one word is still invalid. No tests encode SEC-033/034.
