# CP-034 — The admin panel «لوحة الإدارة» (phase 1)

**Status: OWNER-APPROVED BRIEF (2026-10-31, via the coordinator) — built in D191 (contract v1.60-social, CONVENTIONS
§10.54).** The team's web panel at `admin.<domain>`, replacing day-to-day use of the admin CLIs for the five phase-1
sections plus the website's settings. The CLIs stay; the panel runs the very same rules.

## 1. Owner decisions

| Topic | Decision (owner) |
|-------|------------------|
| Roles | OWNER, MODERATOR «مشرف», SUPPORT «دعم», FINANCE «مالية» — an extension of the existing role / granular admin permission system (no parallel one). Granted and revoked only with the CLI `admin-admin grant\|revoke\|list` (audited); the first OWNER is bootstrapped with the CLI. |
| Sign-in | A separate admin sign-in with the existing admin account and **mandatory TOTP 2FA** (QR at enrolment; the secret encrypted with a server key; hashed single-use recovery codes); a short-lived HttpOnly Secure SameSite=Strict cookie, a CSRF token, rate limits, lockout. |
| Checks | Every `/admin/*` route checks its permission on the server; every change is audited (actor, action, target, reason, before/after, IP); reasons required on sensitive actions; financial actions (top-up, withdrawal payout, balance changes) need the TOTP code again. No PII in logs. Private recharge pictures only streamed through the API, each view audited (D185). |
| Sections | 1 Home dashboard (real aggregates) · 2 Users (search, profile, ban/unban, avatar removal, special usernames) · 3 Recharge agents (applications with private pictures, approve/reject, top-up with tier price + paid USD under TOTP, suspend/reinstate, cap) · 4 Withdrawals (mark paid with a reference under TOTP, reject with refund) · 5 Reports & moderation (dismiss, remove content, warn, ban) · plus «إعدادات الموقع» (OWNER: the website's social links and `topupEnabled`, with D192). |
| Web | React + TypeScript + Vite, exact pinned versions, minimal dependencies (no UI library; a tiny router; fetch); Arabic RTL first + English; Kabso colours; light/dark; paginated tables; only `/admin/*`. Static build served by Caddy at `admin.{$KABSO_DOMAIN}` with `/admin/*` API proxied same-origin; CSP, frame-ancestors none, HSTS; optional IP allowlist. |
| Not now | Phase-2 sections; Stripe cases and website top-ups (until D190 merges). |

## 2. Choices made while building (each can change)

| | Choice | Where |
|-|--------|-------|
| a | The moderator role **is** the existing `MODERATION` permission (the report queue's); OWNER, SUPPORT and FINANCE are new `admin_permission` values. `admin-admin` accepts `MODERATOR`. | `admin-permissions.ts`, migration `20270104090000_admin_panel_enums` |
| b | The capability table of §10.54.1 (e.g. SUPPORT reviews applications and their pictures; FINANCE tops up and pays; MODERATION sees balances read-only — owner answer Q3 — but no ledger rows and no private pictures; only OWNER edits the website). | `CAPABILITIES` in `admin-permissions.ts` |
| c | Only an OWNER may act on an account that holds a panel role; nobody on their own account. | `AdminUsersService.target`, `AdminModerationService.act` |
| d | Rejecting a withdrawal also needs the code again (it moves cherries back). | `AdminFinanceService.rejectWithdrawal` |
| e | WARN is a new system notification `MODERATION_WARNING` (the app ignores it until it shows it); BAN from a report suspends the author. Both close the target's open reports as ACTIONED. | `admin-moderation.service.ts` |
| f | «Today» on the dashboard is the Asia/Riyadh day (owner answer Q2; `ADMIN_DASHBOARD_TIME_ZONE`, default Asia/Riyadh). | `dashboardDayStart` |
| g | The authenticator code consumed at sign-in cannot be re-used for a financial action in the same 30 s (single use); the panel asks for the next code. | `consumeTotp` |
| h | The panel's API paths live under `/api/v1/admin/...` beside the older bearer-token `/admin/reports` and `/admin/levels` (unchanged); the panel's report queue is `/admin/moderation/reports`. | openapi tag `admin-panel` |

## 3. Questions for the owner — answered 2026-10-31 (via the coordinator)

1. ~~Should the IP allowlist be mandatory in production?~~ **No:** no allowlist by default (`KABSO_ADMIN_ALLOW_IPS`
   unset = everyone); the owner may set one later.
2. ~~UTC or Asia/Riyadh «today»?~~ **Asia/Riyadh:** the dashboard counts the Riyadh day (`ADMIN_DASHBOARD_TIME_ZONE`,
   default `Asia/Riyadh`, the same day rule as the recharge badges; a server setting can change it).
3. ~~Should MODERATION see balances?~~ **Yes, read-only:** `users.balances` now includes MODERATION; the ledger rows
   are a separate capability `users.ledger` (OWNER, SUPPORT, FINANCE), so the moderator sees the balances only.
4. **Kept:** rejecting a withdrawal still needs the authenticator code again (choice d).
5. **Kept (D190):** a team refund (`payments-admin refund`) opens an admin case without freezing the buyer.
6. Still open — phase 2: an audit-log viewer, admin role management in the panel (now CLI-only by decision), the
   Stripe cases.
