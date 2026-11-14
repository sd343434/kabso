# CP-040 — Privacy compliance for a global app

**Status: OWNER DECISION (2026-10-31, via the coordinator: "Kabso Live is a GLOBAL app") — built in D198 (contract
v1.66-social, CONVENTIONS §10.61). Legal texts are drafts for a lawyer.**

## 1. Owner decisions

| Topic | Decision |
|-------|----------|
| Scope | Global: EU/UK GDPR, California CCPA/CPRA, Brazil LGPD, UAE and Saudi PDPL. Controller Kigofi LLC (Wyoming), info@kabsolive.com, 18+ only. |
| Access / portability | Settings › Privacy › «تنزيل بياناتي»: password again; async ZIP (JSON + README ar/en); notification + email; single-use, 7-day, authenticated download; one per 24 h; audited; CLI + support path for verified emailed requests. |
| Never exported | Other users' private data, secrets, password hashes, TOTP data, internal fraud signals. |
| Consents | `legal_documents` (versions, effective date, content hash) and `user_consents` (user, document, version, time, truncated IP, UA, method); sign-up records terms + privacy + 18+; a new version published with `legal-admin publish` blocks the app (428 `CONSENT_REQUIRED`) until accepted, except accept / logout / delete / export; D190's top-up terms also recorded. |
| Website | Global privacy policy (controller, purposes and legal bases, processors, US transfers with SCCs, retention, rights by region, children, security, cookies, versioning), EU/UK representative «سيُضاف قريباً» from config, draft banner until `legalReviewed`, a `/delete-account` page. No tracking cookies → no banner; CI note that analytics needs a banner. |

## 2. Default rules (proposals — each changes in one place)

| | Rule built | Where |
|-|------------|-------|
| a | The ready **email carries no link** (as D193's notices: a phished mail must not hand over the data); the single-use link is minted in the app (`createDataExportLink`), bound to the owner's bearer token. The app has no deep links or web sign-in yet, so an emailed link could not be opened anyway. | `DataExportsService`, `mail-templates.ts` |
| b | **Media** of posts/reels/stories are listed as their public links (the files are already public under `media/`); only the private KYC pictures are inside the ZIP; DM attachments are flagged, not included (they expire in 24 h and may hold the other person's content). | `data-export.ts` |
| c | Rows per section capped at 50 000 (the manifest names a cut section). | `SECTION_ROW_LIMIT` |
| d | FAILED jobs do not count towards the 24-hour limit; three build attempts. | `nextExportAllowedAt`, `MAX_ATTEMPTS` |
| e | Consent IP kept as /24 (IPv4) or /48 (IPv6); cleared with the UA at D193's purge; rows deleted at the end of the 7-year retention. | `truncateIp`, `account-deletion.ts` |
| f | The gate starts only when the owner publishes the first versions (no seed in the migration), so the app with the consent screen ships first. | `legal-admin`, DEPLOYMENT §5.31 |
| g | Exempt from 428: `getMyConsents`, `acceptConsents`, `logout`, sessions, `getMe`, `DELETE /me/push-token`, account deletion, data export. | `@ConsentExempt()` |
| h | Sign-up: one required checkbox (18+ and terms + privacy) with links; the versions shown are sent in `RegisterRequest.legal` (optional for older clients — they get the consent screen after sign-in). | `register_screen.dart`, `auth.schemas.ts` |

## 3. Open questions for the owner / a lawyer

1. EU/UK Art. 27 representative: appoint one (paid services exist) or counsel confirms not required.
2. Name the hosting/storage and email providers in the policy; sign DPAs (with SCCs) with each and with Stripe and Google.
3. Confirm the 7-year financial retention and the 90-day legal hold per jurisdiction (PP-35).
4. Response time promised for emailed requests (GDPR 1 month, CCPA 45 days, LGPD 15 days — the policy says "usually one month").
5. Whether a data-protection officer is needed (large-scale processing).
6. App Store privacy "nutrition" labels and the Play Data-safety form from this policy.
