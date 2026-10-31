# Pre-Production Checklist (mandatory release conditions)

No staging-with-real-users, production deployment, store submission or other **public exposure**
may happen until every **MANDATORY** item below is ✅ with linked evidence (commit, CI run, review
document). Items are added, never silently removed; closing one requires the owner named in the
"Verified by" column. Owner decisions are recorded in `docs/AI_WORKFORCE_BOARD.md` (Decision Log).

Status legend: ⛔ open · ⏳ in progress · ✅ done (evidence linked)

## Security (from KL-007 review and owner decisions)

| ID | Condition | Task | Verified by | Status |
| -- | --------- | ---- | ----------- | ------ |
| PP-01 | Least-privilege runtime DB role (DML only) + separate migration role; negative tests prove the runtime role cannot run DDL/TRUNCATE (SEC-011) | KL-013, KL-013b | A7 | ⏳ KL-013 merged `466b66b` (CI run 64); A7 KL-007f PASS WITH CONDITIONS: KL7F-01 (cluster-wide group name), KL7F-02 (boot guard ignores memberships), KL7F-09 (docs) must be fixed before first deployment → KL-013b. KL-013b integrated `2a161f0` (CI runs 75/76 green); A7 KL-007g PASS WITH CONDITIONS: KL7G-01/02 (Low) to fix in KL-013c before first deployment |
| PP-02 | Verify-first registration — sign-up never reveals whether an email is registered (owner decision B9, contract v1.2) | KL-019, KL-024 | A7 + A6 | ✅ A7 KL-007d PASS (`c177a27`, merged `4ad9fd2`); A6 KL-006d approve, timing t=−0.60 (`634c1c1`, merged `9fa6e9a`). Real delivery still needs PP-20 |
| PP-03 | Refresh reuse detection (SEC-022): last-10 history done; residual — a thief rotating > 10 times keeps the session; needs a token generation counter | KL-016b | A7 | ⛔ partial |
| PP-04 | Login lockout/oracle: failed-only account bucket + recent-success bypass + atomic counter (SEC-023) | KL-016, KL-024 | A7 | ✅ race fixed (60 parallel → 20 checks), refunds not exploitable (KL-007d); residual oracle → PP-05 |
| PP-05 | CAPTCHA / step-up challenge replacing the account-bucket 429 (SEC-023 residual oracle) | B11 | A7 | ⛔ provider decision needed |
| PP-06 | Refuse over-broad TRUST_PROXY values in production (SEC-003a) | KL-016, KL-024 | A7 | ✅ KL-007d |
| PP-07 | TRUST_PROXY value measured on the real platform with the spoofed-`X-Forwarded-For` check (DEPLOYMENT.md §3.1) | deploy | A8 + A7 | ⛔ |
| PP-08 | Data retention: session/token/pending-registration cleanup jobs, IP/UA retention, audit pseudonymization on deletion (SEC-012) | KL-014 | A7 | ⛔ |
| PP-09 | Production secrets from the secret manager: `JWT_ACCESS_SECRET`, `RATE_LIMIT_KEY_SECRET` (distinct, strength-checked at boot), DB passwords | deploy | A8 | ⛔ |
| PP-10 | `UV_THREADPOOL_SIZE ≥ ARGON2_MAX_CONCURRENCY + 4` in the container spec (DEPLOYMENT.md §3.2) | deploy | A8 | ⛔ |
| PP-11 | Repository private; full-history secret scan clean on all refs | owner + A1 | A1 | ⏳ (scan ✅ 2026-10-15, 60 commits, all refs; visibility change pending owner) |
| PP-12 | Admin panel (D191, CONVENTIONS §10.54) security review before real team use: A7 review of the cookie session, CSRF, TOTP enrolment/recovery/lockout, the role × capability matrix and the private-picture route; `ADMIN_TOTP_KEY` from the secret manager; decide whether `KABSO_ADMIN_ALLOW_IPS` is required in production | D191 | A7 + owner | ⛔ built with e2e evidence (`test/d191-admin-panel.e2e-spec.ts`), not reviewed |

## Product / compliance

| ID | Condition | Task | Verified by | Status |
| -- | --------- | ---- | ----------- | ------ |
| PP-20 | Real email delivery (SMTP/provider, SPF/DKIM) — required by verify-first registration and password reset | B2 | A8 | ⛔ |
| PP-21 | displayName Unicode rules incl. ZWNJ/ZWJ, length, zalgo, reserved terms (contract v1.2.3) | KL-017, KL-024, KL-025 | A6 + A7 | ✅ A7 KL-007e PASS (`5b773ab`): SEC-024/030/031/032 fixed with evidence; no false positives on ordinary names |
| PP-27 | Live discovery hardening from KL-040: SEC-035 (stale sweep), SEC-036, SEC-037, SEC-038; plus KL-040b residuals SEC-039 (Low, hidden variation-selector channel) and SEC-040 (Info) | KL-045, KL-048 | A7 | ⏳ SEC-035..038 FIXED and re-tested (KL-040b `0b90bb4`); SEC-035 cleared from the security side, but `LIVE_HOSTING_ENABLED=true` still needs PP-32 and B1. SEC-039/040 open |
| PP-26 | displayName hardening residuals: SEC-033 (empty chunk breaks single-letter joining) and SEC-034 (non-ASCII digit zeros and CJK strokes as Latin look-alikes) | KL-026 | A7 | ⛔ Low, before public launch |
| PP-28 | Media uploads (KL-052 conditions: SEC-041/042 Medium + SEC-043..045 Low fixed; R2 staging checks): storage provider credentials (B12), moderation provider and illegal-content process (B13), A7 review of the upload and image-processing pipeline, (D162) and of the video container checks (no decode, no transcoding) and video egress cost, before `MEDIA_UPLOADS_ENABLED=true` | KL-048, KL-049 | A7 + owner | ⛔ |
| PP-22 | First-launch language follows device locale; explicit preference persisted; emails in the correct locale | KL-018 | A6 + A7 | ✅ A7 PASS (KL-007c/d); A6 PASS incl. QA-011 fix (KL-006d) |
| PP-23 | App identity, privacy/terms URLs, support contact | B7, D192 | owner | ⏳ D192: https://kabsolive.com/privacy, /terms, /contact (AR+EN), support info@kabsolive.com, entity Kigofi LLC; drafts with a «مسودة» banner until a lawyer reviews them (`infra/deploy/site/config.json` `legalReviewed`) |
| PP-35 | Card top-ups (D190, DEPLOYMENT §5.29): live Stripe keys and the webhook signing secret entered by the owner in the admin panel «الدفع (Stripe)» (D196: tested on Stripe, stored AES-256-GCM sealed under `ADMIN_TOTP_KEY`, write-only; or, as the fallback, on the server env) — never in git/chat; `TOPUP_PUBLIC_BASE_URL` on the server; **A7 review of D196** (the sealing and its key, the write-only responses and audit rows, the code re-entry, the 10-minute webhook grace, no test key in production without `STRIPE_ALLOW_TEST_KEYS_IN_PRODUCTION`) and a real `balance.retrieve` check with the live restricted key (the e2e uses a fake Stripe); webhook endpoint with the 8 events; descriptor «KABSO LIVE»; receipts on; a full test-mode run on staging (3-D Secure card, refund, early-fraud warning, dispute won/lost) checked against the coins, freezes and cases; legal review of the website terms «العملات رقمية وغير قابلة للاسترداد» and the seller details (Kigofi LLC); **before the store release, review the Google Play and App Store payment rules for the in-app «الشحن من الموقع» link** (owner: shown, `TOPUP_APP_LINK_ENABLED=true` by default; set it to false on the server per environment if a store requires) | D190, D196 | owner + A7 | ⛔ |
| PP-24 | Brand assets | B8 | owner | ⛔ |
| PP-25 | Release signing from CI secrets (Android `key.properties`, iOS certificates); release job deletes key material | deploy | A8 + A7 | ⛔ |

## Quality / release engineering

| ID | Condition | Task | Verified by | Status |
| -- | --------- | ---- | ----------- | ------ |
| PP-30 | Device testing on real Android and iOS devices (install, secure storage, backup exclusion, reinstall token clear, RTL, screen readers) | — | A6 | ⛔ never performed |
| PP-31 | `main` is the default branch with required CI checks (`CI OK`) and reviewed pull requests | owner + A8 | A1 | ⏳ |
| PP-32 | Load test of auth endpoints against the Argon2 cap and rate limits; SLOs recorded | Phase 11 | A7 + A8 | ⛔ |
| PP-33 | Backups + tested restore (PITR) for PostgreSQL | deploy | A8 | ⛔ |
| PP-34 | Development-only preview imagery (`assets/preview/`, AI-generated, see `docs/design/PREVIEW_ASSETS.md`) is excluded from release builds (dev flavor) or removed, and never shown as user content | Flutter | A1 | ⛔ |
