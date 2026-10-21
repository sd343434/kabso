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
| B10 | Least-privilege runtime DB role (SEC-011) | Implemented in KL-013 (`466b66b`) and verified by A7 in KL-007f: PASS WITH CONDITIONS. KL7F-01/02/09 must be fixed in KL-013b before the first deployment | Nothing from you; engineering follow-up KL-013b |
| B12 | Media storage credentials (owner chose Cloudflare R2, D45) | Avatar, cover and post photo uploads stay disabled (`MEDIA_UPLOADS_ENABLED=false`); the upload code exists (KL-060) and is verified against an S3-compatible test server | R2 account, bucket, custom domain, API token via the secret manager; cost approval |
| B13 | Image moderation provider; legal duty for illegal content (e.g. CSAM detection and reporting) | Uploaded images are visible only to their owner | Provider choice (e.g. Rekognition, SafeSearch, Hive) + legal review before public launch |
| B8 | Brand assets (logo, app icon) | App uses a text wordmark placeholder | Official Kabso Live assets |

## Current limitations (Phase 1)

- Only email + password authentication. Social sign-in and phone auth are not implemented.
- Tabs other than authentication show explicit "coming in Phase N" states; no feature data yet.
- Docker Compose file is provided but was not executed in the authoring environment (no daemon).

## Social content API (v1.5-social draft, KL-060 / CP-006 M1)

- Posts with images stay `PENDING` (author-only) until a moderation provider is chosen (B13); they
  are absent from feeds, search and other people's grids.
- Trending and hashtag `top` score weights are server-side constants (`TRENDING_WEIGHTS`), not
  environment settings; personalised ranking is M5.
- The Following feed is computed per request from follows and reposts (no fan-out table); fine
  for launch volumes, to be revisited with real traffic.
- Views are counted synchronously per batch (the contract allows ≤ 1 min lag; no queue yet).
- Ranked lists (Trending, hashtag `top`) keep a 10-minute snapshot of ≤ 500 ids per caller in
  Redis; ranked search (users, hashtags) is offset-paged and stops after 500 results.
- A `USER` report actioned with `REMOVE_TARGET` records the decision only; suspension stays a
  separate admin tool. There is no admin web panel for the queue yet (API only).
- Counters (`like_count`, `comment_count`, …) are kept in the same transaction as their rows;
  a hard deletion of a user (FK cascade) does not adjust the counters of other users' posts.
- Stories (CP-008, D91): story photos are shown to others at once, without a moderation hold
  (owner decision); harmful ones are handled by reports and expire after 24 hours.
- Stories: deleting or removing a story is soft; its photo files stay in object storage (as for
  deleted posts) until a purge job exists. Video stories (M2) and replies (M7) are not built.
- App (KL-060 E1–E4): outside sharing is not offered, so `POST /posts/{id}/shares` is unused and
  the share count is display-only; sharing needs post links on a web domain (CP-006 Q7, M7).
- App: views are recorded best effort — a batch that fails is dropped, and views still waiting
  when the app is killed (not just sent to the background) are lost.
- App: a text field takes its direction from its first letter outside `@handles` and `#tags`
  (a reply's lone `@handle` reads left to right); in a field that also holds Arabic, a Latin
  `@handle` still shows its `@` on the right while editing (posted text is displayed with the
  handle isolated).
