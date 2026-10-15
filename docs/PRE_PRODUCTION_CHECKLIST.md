# Pre-Production Checklist (mandatory release conditions)

No staging-with-real-users, production deployment, store submission or other **public exposure**
may happen until every **MANDATORY** item below is ✅ with linked evidence (commit, CI run, review
document). Items are added, never silently removed; closing one requires the owner named in the
"Verified by" column. Owner decisions are recorded in `docs/AI_WORKFORCE_BOARD.md` (Decision Log).

Status legend: ⛔ open · ⏳ in progress · ✅ done (evidence linked)

## Security (from KL-007 review and owner decisions)

| ID | Condition | Task | Verified by | Status |
| -- | --------- | ---- | ----------- | ------ |
| PP-01 | Least-privilege runtime DB role (DML only) + separate migration role; negative tests prove the runtime role cannot run DDL/TRUNCATE (SEC-011) | KL-013 | A7 | ⛔ |
| PP-02 | Verify-first registration — sign-up never reveals whether an email is registered (owner decision B9, contract v1.2) | KL-019 | A7 + A6 | ⏳ |
| PP-03 | Refresh reuse detection across last 10 rotated secrets (SEC-022) | KL-016 | A7 | ⏳ |
| PP-04 | Login lockout/oracle: failed-only account bucket + recent-success bypass (SEC-023) | KL-016 | A7 | ⏳ |
| PP-05 | CAPTCHA / step-up challenge replacing the account-bucket 429 (SEC-023 residual oracle) | B11 | A7 | ⛔ provider decision needed |
| PP-06 | Refuse `/0` CIDRs and hop counts > 3 in production TRUST_PROXY (SEC-003a) | KL-016 | A7 | ⏳ |
| PP-07 | TRUST_PROXY value measured on the real platform with the spoofed-`X-Forwarded-For` check (DEPLOYMENT.md §3.1) | deploy | A8 + A7 | ⛔ |
| PP-08 | Data retention: session/token/pending-registration cleanup jobs, IP/UA retention, audit pseudonymization on deletion (SEC-012) | KL-014 | A7 | ⛔ |
| PP-09 | Production secrets from the secret manager: `JWT_ACCESS_SECRET`, `RATE_LIMIT_KEY_SECRET` (distinct, strength-checked at boot), DB passwords | deploy | A8 | ⛔ |
| PP-10 | `UV_THREADPOOL_SIZE ≥ ARGON2_MAX_CONCURRENCY + 4` in the container spec (DEPLOYMENT.md §3.2) | deploy | A8 | ⛔ |
| PP-11 | Repository private; full-history secret scan clean on all refs | owner + A1 | A1 | ⏳ (scan ✅ 2026-10-15, 60 commits, all refs; visibility change pending owner) |

## Product / compliance

| ID | Condition | Task | Verified by | Status |
| -- | --------- | ---- | ----------- | ------ |
| PP-20 | Real email delivery (SMTP/provider, SPF/DKIM) — required by verify-first registration and password reset | B2 | A8 | ⛔ |
| PP-21 | displayName Unicode rules incl. ZWNJ/ZWJ, length, zalgo, reserved terms (contract v1.2) | KL-017 | A6 + A7 | ⏳ |
| PP-22 | First-launch language follows device locale; explicit preference persisted; emails in the correct locale | KL-018 | A6 | ⏳ |
| PP-23 | App identity, privacy/terms URLs, support contact | B7 | owner | ⛔ |
| PP-24 | Brand assets | B8 | owner | ⛔ |
| PP-25 | Release signing from CI secrets (Android `key.properties`, iOS certificates); release job deletes key material | deploy | A8 + A7 | ⛔ |

## Quality / release engineering

| ID | Condition | Task | Verified by | Status |
| -- | --------- | ---- | ----------- | ------ |
| PP-30 | Device testing on real Android and iOS devices (install, secure storage, backup exclusion, reinstall token clear, RTL, screen readers) | — | A6 | ⛔ never performed |
| PP-31 | `main` is the default branch with required CI checks (`CI OK`) and reviewed pull requests | owner + A8 | A1 | ⏳ |
| PP-32 | Load test of auth endpoints against the Argon2 cap and rate limits; SLOs recorded | Phase 11 | A7 + A8 | ⛔ |
| PP-33 | Backups + tested restore (PITR) for PostgreSQL | deploy | A8 | ⛔ |
