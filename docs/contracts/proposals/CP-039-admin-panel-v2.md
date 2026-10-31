# CP-039 — The admin panel v2 «لوحة الإدارة»: redesign and phase 2

**Status: OWNER REQUEST (2026-10-31, via the coordinator) — built in D197 (contract v1.65-social, CONVENTIONS
§10.60).** The owner: «لوحة الإدارة تصميمها ضعيف وفيها كثير من نقص». A professional redesign of the D191 panel
(CP-034) first, then the missing sections. The CLIs stay; the panel runs their rules.

## 1. Owner request

| Topic | Request |
|-------|---------|
| Look | A third-party dashboard kit as a reference for **layout only** (kept in scratch, never in git; none of its brand, text, art, illustrations or people): a rounded coloured sidebar with icon navigation in groups, a top bar (search, notifications, the admin), coloured KPI cards with sparklines, a large line chart with a legend, a range selector and a tooltip, a recent-activity list, card grids, generous radii and soft shadows. Kabso colours and tokens (Kabso red, not purple); light and dark; Arabic RTL first and English. One small chart library or hand-rolled SVG, justified; a small bundle. |
| Sidebar | الرئيسية · المستخدمون · الوكالات · المضيفون والبث · الهدايا والعناصر · المال · المحتوى والبلاغات · المهام والمستويات · الإعدادات (site, payments, team, audit) — each item only when the role can use it. |
| Top bar | Quick search across users, agents and agencies (username, code, email); a bell with the pending counts (applications, withdrawals, reports, deletion requests); the admin menu. |
| Dashboard | KPI cards with a sparkline and the change against yesterday (new users, coins sold by agents and the website, gifts value, lives now, pending items); a 30-day chart (new users, coins sold, gifts) with 7/30/90; «يحتاج انتباهك»; recent admin activity. Real aggregates from read-only `/admin/stats/*`, indexed, on the Asia/Riyadh day. |
| Tables | One reusable component: server pages, sort, filters, search, column visibility, CSV export (audited), empty / loading / error states. |
| User page | Tabs: overview, money (balances, ledger), content, reports, the audit about the user, devices / sessions (revoke); action buttons by role. |
| Sections | 1 agencies (list, detail, create, suspend / reinstate, complaints, rank evaluation) · 2 hosts and lives (lives now, END LIVE with a reason, hosting permissions; PK history if present) · 3 gifts and items (gift CRUD, bag items, frames and badges, banners, events) · 4 money (agents' top-ups, withdrawals moved here, card top-ups and Stripe cases with a team refund under TOTP, the financial report with CSV) · 5 the audit viewer and the TEAM (grant / revoke / reset 2FA, TOTP + reason; the CLI stays) · 6 tasks and levels with USD, special usernames, the waitlist, account deletion (only if D193 is in the base), reports (moved). |
| Rules | Contract-first; role checks and an audit row per mutation; reasons on sensitive actions; TOTP again where money moves; no fake data, no display-only buttons; sections without data hidden. |

## 2. Choices made while building (each can change)

| | Choice | Where |
|-|--------|-------|
| a | **Charts are hand-written SVG** (a sparkline and a two-axis line chart, ~250 lines, unit-tested geometry): three small charts do not justify a dependency, and the panel's CSP (`default-src 'self'`) and pinned, minimal dependency list stay as they are. The panel's JS is 437 kB (127 kB gzip) with no new package. | `apps/admin/src/ui/charts.tsx` |
| b | The chart puts coins (sold, gifts) on one axis and new users on the other (different magnitudes), and runs right to left in Arabic. | `LineChart` |
| c | «Lives now» and «pending» have no history: their cards show the state now as the big number and *lives started* / *new pending items* per day as the sparkline and the change. | `AdminStatsService.overview` |
| d | Sixteen new capabilities (§10.60.1). SUPPORT manages agencies and items (the users CSV is OWNER only, Q2); MODERATION ends lives and signs devices out; FINANCE sees money only; the audit log, the team, the waitlist and catalogue changes are OWNER-only. | `admin-permissions.ts` |
| e | **Team management from the panel needs a database change**: `user_admin_permissions` was read-only for the API's runtime role on purpose (D72). The panel writes panel roles only through a SECURITY DEFINER function that accepts the four panel roles and is executable only by the runtime group; `LEVELS_*` stay CLI-only. Each grant / revoke / reset needs OWNER, a reason and the authenticator code again; never one's own OWNER, never the last OWNER. **This widens what a compromised API process could do (grant itself a panel role)** — kept by the owner (Q1). | migration `20270112100000_admin_v2`, `admin-roles.ts` |
| f | The CLI rules that were inline (`agency-create`, `complaint-resolve`, `event-admin create/end/hold/release`, the audit rows of `gift-admin`, `bag-admin`, `banner-admin`, the waitlist read) moved into shared modules with an `AdminVia`; the CLIs call them and write the same rows (`via: cli`). | `agency-admin.ts`, `gift-admin-rules.ts`, `bag-admin-rules.ts`, `event-admin-rules.ts`, `waitlist-admin.ts` |
| g | A CSV export takes at most 5 000 rows and is audited `admin.export.csv` (table, count, filters — never the rows). The waitlist keeps its own `waitlist.view` row (as the CLI). | `admin-tables.ts` |
| h | Ending a live uses the report action's rule (end reason `ADMIN`); the reason is in the audit row `admin.live.end`, not shown to the host. | `admin-lives.service.ts` |
| i | Signing a user's devices out uses the app's session revocation with the new reason `ADMIN_REVOKED`. | `admin-people.service.ts` |
| j | Gift art upload (`--image`, `--animation-file`) and new banners (a picture upload) stay with the CLIs: the panel has no file upload yet. | §10.60.4 |
| k | The estimated margin is cash in (agents' top-ups + card orders) − card refunds − estimated card fees (Q3) − host payouts; the value of cherries not withdrawn yet is shown apart, not deducted. | `admin-money.service.ts` |

## 3. Hidden, and why

- **PK history** — the PK tables are D195, not in this base: no operation, no page.
- **Account deletion requests** — D193 is not in this base: no operation, no page; the bell and «يحتاج انتباهك» gain
  them when it merges.
- **Badges / medals grant** — no rule exists to grant one by hand (they are earned): the items page says so.
- **Payments (Stripe keys) settings** — D196 builds it on its own branch; the sidebar has a slot under الإعدادات.

## 4. Owner answers (2026-10-31, via the coordinator)

| # | Question | Answer (built) |
|---|----------|----------------|
| Q1 | Team management in the panel lets the API's runtime role add panel roles (through a narrow function). Keep it? | **Keep** — OWNER, TOTP again, a reason, audited; never the last OWNER. |
| Q2 | Should SUPPORT export the users table (emails) as CSV? | **No** — `users.export` is OWNER only. |
| Q3 | Deduct payment fees from the estimated margin? | **Yes, as an estimate** — `ADMIN_REPORT_CARD_FEE_BPS` (290) of each credited card order + `ADMIN_REPORT_CARD_FEE_FIXED_MINOR` (30 cents) per order; the report labels it an estimate. |
| — | The sidebar (owner feedback «الشريط الجانبي دعه ابيض في لايت واسود في دارك») | White in light mode, the dark surface in dark mode; Kabso red only for the active item; a border between the sidebar and the content; the phone drawer the same. |
