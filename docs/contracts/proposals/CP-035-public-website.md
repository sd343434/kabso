# CP-035 — The public website kabsolive.com

**Status: OWNER-APPROVED BRIEF (2026-10-31, via the coordinator, with the owner's update the same day) — built in
D192 (contract v1.61-social, CONVENTIONS §10.55).** The owner's wording stays in the coordinator's brief (scratch).

## 1. Owner decisions

| Topic | Decision (owner) |
|-------|------------------|
| Page | The owner's own coming-soon page (10 Kabso characters, logo, the king's voice) replaces `infra/deploy/site/index.html`; design and animation unchanged. Owner-supplied Kabso art, may enter git (`infra/deploy/site/assets/PROVENANCE.md`). |
| Store buttons | Replaced by an e-mail form «أبلغني عند الإطلاق» (mobile and desktop) plus small, honest, non-link «قريباً» badges. |
| Waitlist API | `POST /waitlist {email, locale}`: public, per-IP rate limit, idempotent per email, never reveals whether an email exists; table `waitlist_signups`; CLI `waitlist-admin list\|export`. |
| Top-up link | «شحن العملات» in the header → `https://<domain>/topup` (D190's page), hidden until it is switched on. |
| Legal pages | `/privacy`, `/terms`, `/contact` in Arabic and English, written from what the product does; legal entity **Kigofi LLC**, 30 N Gould St #7354, Sheridan, WY 82801, USA; governing law Wyoming, USA; contact **info@kabsolive.com**; minimum age **18 (confirmed)**; a «مسودة — تحتاج مراجعة قانونية» banner until a lawyer has reviewed them. |
| Social links | Instagram, TikTok, WhatsApp — **managed by the owner from the admin panel (D191)**: a public read `GET /site/settings` and an admin write `PUT /admin/site-settings` on a `site_settings` key/value table, module `site-settings`. The website hides an icon whose link is not set, and all of them when the read fails. |
| Language | AR (default) / EN toggle, `?lang=en`, every text translated, correct direction. |

## 2. Contract (v1.61-social, additive)

- `joinWaitlist` — `POST /api/v1/waitlist`, `WaitlistSignupRequest`, 202 `WaitlistAccepted` (always the same body).
- `getSiteSettings` — `GET /api/v1/site/settings`, `SiteSettings` (`socials` + `topupEnabled`), cached 60 s.
- `updateSiteSettings` — `PUT /api/v1/admin/site-settings`, `UpdateSiteSettingsRequest` (partial), admin permission
  `SITE_SETTINGS`, audited `site.settings.update` (before/after). Links validated to the right hosts and stored
  normalized; WhatsApp is a number (`wa.me`).
- Rate limit `RATE_LIMIT_WAITLIST_IP` 10 / hour per IP; audit `waitlist.view` for the CLI.

## 3. Split with D191

D192 owns the table, `SiteSettingsService` and both operations. D191 builds the panel screen «إعدادات الموقع» that
calls `PUT /admin/site-settings`, and maps its OWNER role onto `SITE_SETTINGS` (or swaps the guard for its own OWNER
check — one place, the controller's `@RequireAdminPermission`). If both branches add the module, the integrator keeps
one.

## 4. Open points for the owner

1. The terms and privacy texts are drafts for a lawyer (US/Wyoming entity, users mainly in Arab countries; store
   rules for virtual currency). `legalReviewed` stays false until then.
2. The launch e-mail itself (sender, wording, unsubscribe) is a later step; nothing is sent today.

## 5. Integration note (KL-069, with CP-033 / CP-034, before any deploy)

D191 (CP-034) built the same settings. One module, table, contract and service remain (CONVENTIONS §10.54.6):
D191's table (`socials`, `topupEnabled` keys) and its OWNER panel route `updateAdminSiteSettings` (cookie session +
CSRF) are the only write path; D192's link rules give the one stored form the website accepts
(`https://www.instagram.com/<handle>`, `https://www.tiktok.com/@<handle>`, `https://wa.me/<digits>`). The bearer
`updateSiteSettings` and the `SITE_SETTINGS` permission above were dropped (OWNER is the editor), with the never-run
migration `20270106090000_website_enums` and the `site_settings` DDL of `20270106100000_website`. The apex `/topup*`
is D190's 302 to `https://api.<domain>/topup` instead of a proxy.
