# Known Limitations & Blockers

## Blockers (require human decision, credentials, or approval)

| ID | Blocker | Impact | Needed from you |
| -- | ------- | ------ | --------------- |
| B1 | Live streaming provider credentials (LiveKit Cloud API key/secret or a self-hosted LiveKit server) | Phase 6–7 cannot be verified end-to-end | Choose LiveKit Cloud vs self-host; provide keys via secret manager |
| B2 | Email delivery (SMTP or provider) | Verification/reset emails only logged in dev | Provider + sending domain (SPF/DKIM) |
| B3 | SMS provider for phone registration | Phone sign-up not implemented (email only) | Provider choice + budget |
| B4 | Firebase project (FCM) + APNs key | Push notifications (Phase 9) | Firebase project, Apple developer account |
| B5 | Coin purchases: Apple IAP / Google Play Billing products, legal review of virtual currency & creator payouts per region | Phase 8 real money stays disabled | Commercial/legal sign-off, store product setup |
| B6 | Android SDK / Xcode not available in this cloud environment | No APK/IPA build or device test here; CI must run them | macOS runner / signing assets |
| B7 | App identity: final bundle id / application id (current placeholder in `apps/mobile`: `com.kabso.kabso_live`), domain, privacy/terms URLs, support contact | Store submission | Owner-provided values |
| B9 | Registration reveals whether an email is registered (`EMAIL_TAKEN`) | Account enumeration via sign-up | **Decided (D24): not acceptable.** Verify-first registration specified in contract v1.2, implementation KL-019; real delivery needs B2 |
| B11 | CAPTCHA / step-up provider for login abuse (SEC-023 residual) | Account-bucket 429 can link an email to a public username | Provider choice (e.g. hCaptcha, Turnstile, App Attest/Play Integrity) before public launch |
| B10 | Least-privilege runtime DB role not implemented (SEC-011) | API connects as a schema owner | Required before any production deployment (KL-013) |
| B8 | Brand assets (logo, app icon) | App uses a text wordmark placeholder | Official Kabso Live assets |

## Current limitations (Phase 1)

- Only email + password authentication. Social sign-in and phone auth are not implemented.
- Tabs other than authentication show explicit "coming in Phase N" states; no feature data yet.
- Docker Compose file is provided but was not executed in the authoring environment (no daemon).
