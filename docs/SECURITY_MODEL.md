# Kabso Live — Security Model (Phase 1)

Owner: A7 (Security & Performance). Status: **v1, written against integration commit `b973d7b`**
(KL-002 API + KL-003 mobile + KL-005 CI). Every control listed as implemented below was checked
in code and, where marked **[PoC]**, exercised against a local API instance. Findings and their
evidence are in [`security/KL-007_PHASE1_REVIEW.md`](security/KL-007_PHASE1_REVIEW.md) (IDs
`SEC-0xx`). Regression tests that pin the verified controls are in
`apps/api/test/security/security-regression.e2e-spec.ts`.

Scope of Phase 1: email + password accounts, sessions with rotating refresh tokens, the mobile
token handling, configuration, CI. Out of scope (not built yet): media, live streaming, payments,
admin tooling, social/phone login, real email delivery (blocker B2).

## 1. Assets

| ID | Asset | Where it lives | Why it matters |
| -- | ----- | -------------- | -------------- |
| A1 | Account credentials (passwords) | Only as Argon2id hashes in `users.password_hash` | Account takeover, credential stuffing elsewhere |
| A2 | Refresh tokens `<sessionId>.<secret>` | Secret: mobile secure storage only; server keeps `SHA-256(secret)` in `sessions` | Long-lived (30 d sliding / 180 d absolute) account access |
| A3 | Access JWTs (HS256, 15 min) | Mobile memory only; `Authorization` header | Short-lived API access |
| A4 | `JWT_ACCESS_SECRET` | Process env (secret manager in cloud) | Forging access tokens for any session whose id is known |
| A5 | Email-verification / password-reset tokens | Raw only in the mail; `SHA-256` in `verification_tokens` | Reset token = account takeover for 1 h |
| A6 | PII: email, IP addresses, user agents, device names | `users`, `sessions`, `audit_logs` | Privacy / GDPR exposure |
| A7 | Audit trail | `audit_logs` | Incident response, abuse investigation |
| A8 | Availability of auth endpoints | API + Postgres + Redis | Users locked out; Argon2 is CPU-heavy |
| A9 | Build & supply chain | GitHub Actions, npm/pub dependencies, signing keys (future) | Malicious code in API or app binary |
| A10 | Database / Redis credentials | Env (`DATABASE_URL`, `REDIS_URL`) | Full data access |

## 2. Actors

| Actor | Capability assumed |
| ----- | ------------------ |
| Anonymous internet client | Any HTTP request to public routes; may control many IPv4 addresses (botnet) or a whole IPv6 /64 |
| Registered user | Valid tokens for their own account; may be malicious towards other users |
| Token thief | Holds a copy of someone's refresh and/or access token (malware, backup leak, log leak, shoulder-surfing a proxy) |
| Network attacker | On-path between app and API (public Wi-Fi); defeated by TLS if the app never uses cleartext |
| Log / observability reader | Read access to API logs or Redis (support staff, compromised log pipeline) |
| Insider with DB access | Reads/writes Postgres with the application role |
| Supply-chain attacker | Publishes a malicious package version or compromises a GitHub Action |
| Lost / stolen device holder | Physical access to an unlocked or locked phone |

## 3. Trust boundaries

```
 [Mobile app]  --TLS (prod) / HTTP (dev only)-->  [LB / proxy] --> [NestJS API] --> [PostgreSQL]
   memory: access JWT                                 |  TRUST_PROXY      |   \--> [Redis: rate limits]
   Keychain/Keystore: refresh token                   |                   \--> [MailSender port → log (dev) / SMTP (B2)]
   shared_preferences: theme + language only          |
 [GitHub Actions CI] --(read-only token)--> repo; installs npm/pub/actions pinned by lockfile/SHA
```

- **TB1 device ↔ API**: everything from the client is untrusted, including `X-Forwarded-For`,
  `X-Request-Id`, `Accept-Language`, `device.*`, `User-Agent`.
- **TB2 proxy ↔ API**: client IP is trusted only as far as `TRUST_PROXY` says (SEC-003).
- **TB3 API ↔ data stores**: the API currently connects with the same DB role that owns the
  schema (SEC-011).
- **TB4 API ↔ mail**: the `log` transport writes token links to logs and is refused in production.
- **TB5 CI ↔ third-party code**: actions pinned to SHAs, `contents: read`; dependencies pinned
  by `pnpm-lock.yaml` / `pubspec.lock`.

## 4. STRIDE threat table (Phase 1)

Status: **M** = mitigated by an implemented control, **P** = partially mitigated (see finding),
**A** = accepted residual risk, **O** = open finding.

| # | STRIDE | Threat | Control(s) | Status |
| - | ------ | ------ | ---------- | ------ |
| T1 | S | Forge an access JWT (`alg=none`, HS/RS confusion, other key) | `algorithms: ['HS256']` + explicit secret, `iss`/`aud`/`typ` checks (`access-token.service.ts:50-61`) **[PoC]** | M |
| T2 | S | Use a forged/stolen JWT for another user's session | Guard re-loads the session: must belong to `sub`, be live, user `ACTIVE` (`access-token.guard.ts:39`, `sessions.service.ts:178-197`) **[PoC]** | M |
| T3 | S | Weak `JWT_ACCESS_SECRET` brute-forced offline from any JWT | ≥ 32 bytes; placeholder regex in production — low-entropy strings still pass | P (SEC-005) |
| T4 | S | Credential stuffing / password guessing on one account | Argon2id; 10/15 min per IP+identifier, 50/15 min per IP; no cross-IP per-account limit; IPv6 /64 rotation | P (SEC-002) |
| T5 | S | Spoof client IP via `X-Forwarded-For` to dodge limits | Express `trust proxy` from `TRUST_PROXY` (default `false`) **[PoC]**; `true` is accepted and fully spoofable | P (SEC-003) |
| T6 | S | Refresh token theft and replay | Rotation on every use, CAS on hash, reuse of previous secret revokes the session (`sessions.service.ts:126-164`) **[PoC]** | M |
| T7 | S | Reset/verify token guessing | 256-bit secrets, SHA-256 at rest, single-use, TTL 1 h / 24 h, purpose-bound (`verification-tokens.service.ts`) | M |
| T8 | S | Pre-registration of a victim's email (account pre-hijack) | Reset revokes all sessions; email ownership proven only through reset/verify | A (Phase 2 requirement R9) |
| T9 | T | Tamper with request bodies (mass assignment, prototype pollution) | Strict zod objects, `unknown_field`; `__proto__` rejected **[PoC]** | M |
| T10 | T | SQL injection | Prisma query builder only; the only raw SQL is a tagged `SELECT 1` health probe | M |
| T11 | T | Log injection / header injection via `X-Request-Id` | Strict `[A-Za-z0-9._-]{1,64}` else UUID (`request-id.ts`) **[PoC]**; JSON logs | M |
| T12 | T | Spoofing UI text (bidi/zero-width in `displayName`, control chars in `device.name`) | Control chars rejected only in `displayName` | P (SEC-008) |
| T13 | R | User denies an action / no trail for investigation | `audit_logs` for register, login ok/fail, logout, reuse, verify, reset requested/done, session revoke | M (gaps: SEC-012) |
| T14 | I | Account enumeration via login / forgot | Identical 401 + dummy Argon2 for unknown users (timing measured equal) **[PoC]**; forgot always 202, work after response | M |
| T15 | I | Account enumeration via registration (`EMAIL_TAKEN`) | Contract reveals it; 5/h per IP | A (contract decision, SEC-018) |
| T16 | I | Tokens / passwords in logs | pino redaction list, request serializer logs only id/method/path; `log` mail transport refused in prod **[PoC]**; mobile logger disabled in release + regex redaction | M (SEC-017 note) |
| T17 | I | Tokens cached by intermediaries | No `Cache-Control: no-store` on token responses | O (SEC-006) |
| T18 | I | Cleartext transport from the app | Android cleartext only in `src/debug` manifest; iOS `NSAllowsLocalNetworking` in the shared Info.plist; default base URL is `http://10.0.2.2:3000` | P (SEC-007) |
| T19 | I | Refresh token extracted from device / backups | Keychain `first_unlock_this_device` (no iCloud sync); Android Keystore-wrapped AES-GCM; `allowBackup=false` | M (SEC-019 notes) |
| T20 | I | IDOR on sessions | Revoke `where {id, userId}`; foreign id → 404; list filtered by `userId` **[PoC]** | M |
| T21 | I | DB-level data exposure (insider, SQLi elsewhere) | Hashes only for secrets; no least-privilege role | P (SEC-011) |
| T22 | D | Argon2 CPU exhaustion via login/register | Per-IP limits; ~130 verifications/s per 4-core node **[PoC]**; no global concurrency cap | P (SEC-002) |
| T23 | D | Forced logout of a victim | Any wrong secret with a known session id revokes the session **[PoC]** | O (SEC-001) |
| T24 | D | Rate limiter bypass when Redis is down | Fails closed with 503 **[PoC]** | M |
| T25 | D | Oversized / deeply nested bodies | 100 kB body limit; 1 MB and 10k-deep JSON rejected **[PoC]** | M |
| T26 | D | Session-table growth (unbounded logins, no cleanup) | Rate limits only; cleanup job not built | A (R3) |
| T27 | E | Reach a protected route without a token | Global guard, deny-by-default; `@Public` allow-list pinned by regression test **[PoC]** | M |
| T28 | E | Suspended user keeps acting with a live token | Guard checks `status = ACTIVE` on every request; refresh/login → 403 | M |
| T29 | E | Future WebSocket/RPC handlers bypass auth | Guards return `true` for non-HTTP contexts | O (SEC-013, latent) |
| T30 | E | Malicious dependency / action | SHA-pinned actions, `contents: read`, lockfiles, gitleaks; advisories in prisma CLI graph | P (SEC-014, SEC-015) |

## 5. Controls actually implemented (with file references)

### 5.1 Authentication tokens
- **Access JWT**: HS256 pinned on sign and verify, explicit secret per call, `iss=kabso-api`,
  `aud=kabso-mobile`, `typ=access`, `exp` (15 min); `sub`/`sid` must be UUIDs
  (`apps/api/src/modules/auth/access-token.service.ts:30-62`). No clock tolerance (server issues
  and verifies; mobile uses server expiry).
- **Claims are trusted only after a session lookup**: `AccessTokenGuard` →
  `SessionsService.isActive(sid, sub)` checks owner, `revokedAt`, sliding + absolute expiry and
  `users.status = ACTIVE` (`access-token.guard.ts:24-44`, `sessions.service.ts:178-197`).
- **Refresh tokens**: 32 bytes from `crypto.randomBytes` (`tokens.ts:9`), stored as SHA-256 hex
  (`sessions.service.ts:80`), compared with `timingSafeEqual` (`tokens.ts:18-22`); rotation is a
  compare-and-swap on the current hash (`sessions.service.ts:153-164`); presenting a non-current
  secret revokes the session with `REFRESH_REUSE` and writes `auth.refresh.reuse`; sliding expiry
  capped by `absolute_expires_at` (DB `CHECK expires_at <= absolute_expires_at`).
- **Password reset** revokes every session and every outstanding reset token in one transaction
  (`auth.service.ts:264-289`) **[PoC]**.

### 5.2 Passwords
- Argon2id `m=19456 KiB, t=2, p=1` — exactly the OWASP Password Storage Cheat Sheet minimum
  (`password-hasher.service.ts:9-14`); measured ≈ 35 ms per verification on the review host.
- Length 8–128 code points, UTF-16 length capped at 256 (`password-policy.ts`), login accepts
  ≤ 128 code points, body limit 100 kB → no long-password DoS **[PoC]**.
- Rehash on login when parameters change (`auth.service.ts:134-140`).
- Unknown identifiers burn a dummy Argon2 verification (`auth.service.ts:109-111`); measured
  42.8 ms vs 42.0 ms average (unknown vs known user, 30 interleaved samples) **[PoC]**.
- No Unicode normalisation (SEC-016).

### 5.3 Authorization
- Global deny-by-default guard (`app.module.ts` `APP_GUARD` order: auth, then rate limit).
- Public routes: health ×2, register, login, refresh, email/verify, password/forgot,
  password/reset, username-availability — nothing else (pinned by regression test).
- Session list/revoke are scoped by `userId` (`sessions.service.ts:200-254`) **[PoC]**.

### 5.4 Input validation
- Strict zod schemas mirror `openapi.yaml`; unknown keys → `unknown_field`
  (`auth.schemas.ts`, `zod-validation.pipe.ts`).
- JSON-only body parser, `strict`, `BODY_LIMIT` 100 kB; body errors mapped to 400 without stack
  traces (`app.setup.ts:36-38`, `error-mapping.ts`).
- Emails normalised (trim + lower) and enforced by a DB `CHECK`; usernames by regex + DB `CHECK`.
- `X-Request-Id` accepted only if `[A-Za-z0-9._-]{1,64}` (`request-id.ts:7`).

### 5.5 Rate limiting
- Redis fixed-window counters via an atomic Lua script (`rate-limit.service.ts`); subject keys
  are SHA-256 digests (`rate-limit.guard.ts:10-12`); identifiers/emails trimmed + lowercased
  before keying (`rate-limit.decorator.ts:24-29`) — case/whitespace variants share a bucket
  **[PoC]**; `Retry-After` set; fails closed with 503 **[PoC]**.

### 5.6 Logging and audit
- pino JSON logs; request serializer logs only id, method and path without query string;
  redaction of auth headers and token/password keys (`logger.options.ts`).
- `audit_logs` rows carry action, actor, target, ip, request id and non-secret metadata; audit
  rows survive user deletion (`ON DELETE SET NULL`).
- Dev `log` mail transport prints the token link; production config refuses it
  (`env.schema.ts:128-136`) **[PoC]**.

### 5.7 Configuration and HTTP hardening
- All env validated at boot; secrets never echoed (`app-config.ts`, `main.ts`).
- Production refuses placeholder JWT secrets and the `log` mail transport **[PoC]** (and, today,
  therefore refuses to start at all until SMTP exists — intended).
- `helmet()` defaults (HSTS, nosniff, frame-ancestors, CORP/COOP), `x-powered-by` off, CORS
  disabled unless `CORS_ORIGINS` is set, no credentials (`app.setup.ts`).
- `.env*` git-ignored except examples; `.gitleaksignore` holds exactly two fingerprints of
  test fixtures from commit `d29d958` (verified to be literal test values).

### 5.8 Mobile
- Refresh token only in `flutter_secure_storage` 11.2.0 (iOS
  `first_unlock_this_device`; Android default RSA-OAEP-wrapped AES-GCM, `resetOnError`)
  (`core/storage/secure_token_store.dart`); access token only in `TokenManager` memory.
- `shared_preferences` holds only `pref.themeMode` and `pref.languageCode`.
- Single-flight refresh with a generation counter so a sign-out during refresh cannot resurrect
  the session (`core/network/token_manager.dart`).
- `AUTH_REFRESH_INVALID` and `ACCOUNT_SUSPENDED` clear local tokens and publish the reason; the
  router guard then sends the user to login (`interceptors.dart:101-105`,
  `session_controller.dart`, `auth_redirect.dart`).
- Logging disabled outside debug builds and redacted (`core/logging/app_logger.dart`); HTTP
  logging never prints headers or bodies.
- No deep links / custom URL schemes / associated domains are registered; every route passes the
  global `redirect` guard.
- Android: `allowBackup=false`, cleartext only in the debug manifest.

### 5.9 CI and supply chain
- Workflow-level `permissions: contents: read`; `pull-requests: read` only for paths-filter;
  `persist-credentials: false`; all third-party actions pinned to commit SHAs; gitleaks 8.30.1
  checksum-verified, scanning full history; Dependabot for npm, pub, actions, compose.
- Review run: gitleaks over 22 commits — no leaks; `pnpm audit --prod` — 3 advisories, all in the
  Prisma CLI dependency graph (SEC-014).

## 6. Residual risks (accepted for Phase 1, no production traffic)

1. Registration reveals whether an email exists (contract; SEC-018).
2. Concurrent refresh with the same token from two app instances revokes the session
   (fail-safe; SEC-004).
3. Username availability is public by design (usernames are public handles).
4. No account lockout; brute force is bounded only by per-IP limits until SEC-002 is fixed.
5. No session/token cleanup job, no audit retention policy (SEC-012).
6. API connects with a schema-owning DB role (SEC-011) — **must be fixed before production**.
7. Rotating `JWT_ACCESS_SECRET` signs everyone out (no `kid`, documented in DEPLOYMENT §4).
8. Email is not required to be verified before login (contract; mail delivery is blocked on B2).

## 7. Phase 2+ security requirements

| ID | Requirement | Owner |
| -- | ----------- | ----- |
| R1 | Least-privilege runtime DB role (DML only on app tables; `audit_logs` INSERT/SELECT only, no UPDATE/DELETE); separate migration role | A8 + A3 |
| R2 | SMTP adapter (B2) with SPF/DKIM/DMARC; then revisit registration enumeration (SEC-018) | A3 + CTO |
| R3 | Scheduled cleanup: expired/revoked sessions (> 30 d), consumed/expired verification tokens; audit retention (e.g. 400 d) and IP truncation after 90 d | A3 |
| R4 | Per-account login throttle across IPs + IPv6 /64 bucketing + Argon2 concurrency cap (SEC-002) | CTO-contract + A3 |
| R5 | `kid`-based dual-key JWT rotation; secrets ≥ 32 random bytes generated, not typed | A3 + A8 |
| R6 | Device attestation for high-value actions (Play Integrity / App Attest) before coins/payments (Phase 8) | A2 + A3 |
| R7 | Certificate/public-key pinning decision for the API host before payments; at minimum enforce HTTPS base URL in release builds (SEC-007) | A2 |
| R8 | WebSocket/realtime auth guard that fails closed for non-HTTP contexts (SEC-013) | A3 |
| R9 | Social/phone login must never auto-link to an **unverified** email account (pre-hijack) | A3 + CTO |
| R10 | Error reporting (Sentry or similar) with PII/token scrubbing on both API and app | A8 |
| R11 | Admin/moderation actions: separate role checks, mandatory audit with actor, 2FA for staff | A3 |
| R12 | Session management UI: show sessions, revoke others, notify on new-device login | A2 + A3 |
| R13 | Release signing keys only in CI environment secrets; never sign release with the debug key (SEC-020) | A8 + A2 |
| R14 | Dependency cooldown (≥ 7 days) for new upstream releases; `pnpm audit`/`osv-scanner` gate in CI | A8 |
| R15 | Store minimal PII in audit metadata; document a data-subject deletion procedure (anonymise `ip`, `target_id`) | A3 + CTO |
