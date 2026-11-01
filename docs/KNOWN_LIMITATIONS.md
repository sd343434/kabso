# Known Limitations & Blockers

## Blockers (require human decision, credentials, or approval)

| ID | Blocker | Impact | Needed from you |
| -- | ------- | ------ | --------------- |
| B1 | Live streaming provider credentials (LiveKit Cloud API key/secret or a self-hosted LiveKit server) | Phase 6–7 cannot be verified end-to-end | Choose LiveKit Cloud vs self-host; provide keys via secret manager |
| B2 | Email delivery (SMTP or provider) | Verification/reset emails only logged in dev | Provider + sending domain (SPF/DKIM) |
| B3 | SMS provider for phone registration | Phone sign-up not implemented (email only) | Provider choice + budget |
| B4 | ~~Firebase project (FCM)~~ (done: `kabso-27b19`, D152) + APNs key | Android push implemented (D152); **iOS push** still waits | Apple Developer account and an APNs key (.p8) |
| B5 | Coin purchases: Apple IAP / Google Play Billing products, legal review of virtual currency & creator payouts per region | Phase 8 real money stays disabled | Commercial/legal sign-off, store product setup |
| B6 | Android SDK / Xcode not available in this cloud environment | No APK/IPA build or device test here; CI must run them | macOS runner / signing assets |
| B7 | App identity: final bundle id / application id (current placeholder in `apps/mobile`: `com.kabso.kabso_live`), domain, privacy/terms URLs, support contact | Store submission | Owner-provided values |
| B9 | Registration reveals whether an email is registered (`EMAIL_TAKEN`) | Account enumeration via sign-up | **Decided (D24): not acceptable.** Verify-first registration specified in contract v1.2, implementation KL-019; real delivery needs B2 |
| B11 | CAPTCHA / step-up provider for login abuse (SEC-023 residual) | Account-bucket 429 can link an email to a public username | Provider choice (e.g. hCaptcha, Turnstile, App Attest/Play Integrity) before public launch |
| B10 | Least-privilege runtime DB role (SEC-011) | Implemented in KL-013 (`466b66b`) and verified by A7 in KL-007f: PASS WITH CONDITIONS. KL7F-01/02/09 must be fixed in KL-013b before the first deployment | Nothing from you; engineering follow-up KL-013b |
| B12 | Media storage credentials (owner chose Cloudflare R2, D45) | Avatar, cover and post photo uploads stay disabled (`MEDIA_UPLOADS_ENABLED=false`); the upload code exists (KL-060) and is verified against an S3-compatible test server | R2 account, bucket, custom domain, API token via the secret manager; cost approval *(D222: the R2 account, the two buckets, the custom domain and the token can now be entered and turned on by the OWNER in the admin panel «التخزين (R2 / S3)» — DEPLOYMENT §5.40; still needed: the account and the token themselves.)* |
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
- Live video (CP-010, D93, L1): the hosting permission is admin-granted until host agencies
  and identity checks exist (L1b), so going live stays switched off in production until then.
  No live chat, gifts, guests on stage or PK yet (L2–L5); no recording or replays. Development
  runs a local LiveKit server; production needs LiveKit Cloud keys (B1).
- Notifications (CP-009, D92): the badge refreshes by polling (on foreground and every 60 s), not
  live. Since D152 Android phones also get pushes (FCM) once the server has the Firebase key and
  the APK was built with `google-services.json`; iOS pushes wait for APNs (B4); live-room chat is
  never pushed; private conversations do not exist yet (D86), so the only pushed chat is the
  family chat. Not verified on a device yet (delivery, sounds, the Android 13+ prompt).
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

## Me hub programs (v1.44-social draft, D166, CP-024 approved with defaults)

- **Recharge is still blocked on B5.** The wallet's «شحن العملات» grid shows the packages from server
  config `WALLET_RECHARGE_PACKAGES`; the defaults (D203) are the website's amounts at $12.50 per
  1 000 000 coins (100 000 $1.25 … 50 000 000 $625). The button stays disabled with
  «قريباً»; there is no purchase endpoint. No support banner is shown (no support destination exists).
- **Values the owner can change without a release** (server config or the admin CLIs): the tasks and
  their rewards (`task-admin`), the daily cap 50, check-in 5 + 20 on day 7, SVIP thresholds
  50 000 / 150 000 / 400 000 in 30 days, status 30 days, the 24-hour prize review, events
  (`event-admin`).
- **Owner art needed:** the SVIP emblem (the app shows a Kabso gold/red icon composition), SVIP badge,
  frames and entry effects, event banners (an https URL per event; a token gradient otherwise), the
  Task Center header art (the level emblem is used).
- **SVIP perks are not built yet** (badge, frame, coloured chat name, entry banner, daily bullet, entry
  effect, viewer-list priority, monthly bag gift): `GET /me/svip` lists them with `available: false`
  and the app shows each as «قريباً». SVIP points redemption (anti-mute / unban) is not offered.
- **Task Center:** coins only (no XP — level points are coin value, CP-005). «Share a live room» is not
  offered (a share is a link copied on the phone; the server cannot see it). The monthly benefits block
  of the reference is omitted (no monthly benefit exists). Weekly host tasks are outside the daily cap.
  A live's watch time counts for the day it was first joined.
- **Event Center:** events are created only with the `event-admin` CLI (no admin web page);
  `TAPS_RECEIVED` counts the taps of lives *started* in the event's window; an event with no
  configured events shows empty lists.
- **Purchase VIP** (CP-024 §3) is not part of the approval: its hub card stays «قريباً».
- Not verified on a device.

## Recharge orders with escrow (v1.69-social draft, D204)

- **No money is handled in the app.** The buyer pays the agent outside Kabso (mobile wallet, bank, cash …); the app
  only records the agent's payment details, the buyer's «قمت بالإرسال» with a screenshot, and freezes / moves
  **coins**. Kabso cannot see, verify, reverse or refund the money itself; a dispute is decided by the team on the
  chat's evidence (screenshots, the buyer's screen video kept outside the app).
- A screenshot can be faked; the protection notice asks the buyer to keep a screen video, but the app does not
  record, upload or check videos (pictures only in the chat).
- PAID orders never resolve by themselves: an agent who never answers keeps the coins frozen until the buyer opens a
  dispute (after 15 minutes) and the team decides.
- The chat's pictures and transfer screenshots are kept with the order (evidence) — there is no retention period or
  purge yet (owner question).
- Exchange rates are entered by hand by OWNER / FINANCE (no rate feed); a country without a rate is priced in USD.
- Pushes: one notification row per order and person, moved up by each event (not one per chat message); a push for a
  quick second event may be held back by the per-notification push throttle.
- An agent suspended while an order is open keeps it: the buyer can still be paid by «استلمت» or a dispute decision;
  new details cannot be sent.
- Not verified on a device (camera / gallery pick of the screenshot, pushes, the countdown on a real phone).

## «كن مضيفاً مع الإدارة» — hosting directly with the team (v1.73-social draft, D209)

- **No retention purge** of the applications' ID pictures and date of birth (rejected or cancelled ones included): they
  stay for the team until the account is deleted (then purged). Owner/legal to set a period, as for D206.
- The ID check and the age are **not automated**: the date of birth is the person's statement (no OCR, liveness or
  face match); the team compares it with the ID picture.
- Revoking a direct host later (`revokeAdminLiveHost`) leaves the application APPROVED and lets the person apply again
  at once (no cooldown after a revocation).
- A pending application is cancelled when the person joins or opens an agency; an agency the **team** creates for them
  (`economy-admin agency-create`) does not cancel it — the approval then refuses («now in an agency»).
- The panel's decision needs no authenticator code (owner: it moves no money); the pictures are OWNER + SUPPORT only,
  MODERATION reads the fields (including the contact and the date of birth) — owner to confirm.
- The rate limit's 429 for `applyForHosting` is configured but not covered by an e2e test (the suite raises the limit).
- The host rules are a short fixed text in the app (not a versioned legal document); the acceptance time is kept.
- Not verified on a device (the date picker, camera / gallery pickers were exercised with fakes only).

## «افتح وكالة» — self-opened agencies (v1.70-social draft, D206)

- **No retention purge** of the agency applications' ID pictures yet (D185's recharge applications have one): they stay
  for the team until the account is deleted (then the contact, bio and pictures are purged). Owner/legal to set a period.
- The ID check is **not automated**: no OCR, liveness or face match — the agency opens at once and the team reviews
  the pictures in the panel when it wants (and may close the agency).
- A host counts as activated only for a live **they hosted** (`live_rooms.host_user_id`); being a guest on someone
  else's seat does not count. Gifts are counted from the cherry ledger (`GIFT_RECEIVED` not reversed), any source.
- The panel's probation actions are OWNER only (`agencies.probation`); the application view is OWNER and SUPPORT.
- The rate limit's 429 for `openAgency` is configured but not covered by an e2e test (the suite raises the limit).
- The in-app closing notification says «خلال فترة التجربة» (the app has no probation days in the notification); the
  push sentence names the days.
- Not verified on a device (the form's camera / gallery pickers and the share sheet were exercised with fakes only).

## Gift categories and gift files in the admin panel (D207, v1.46-live / v1.71-social draft)

- **Uploads need the media bucket.** The panel stores gift files in the API's S3/R2 bucket like every other upload;
  without `S3_*` settings (the server today, B12 / PP-28) uploading answers 503, and since «صورة الهدية» is required,
  no gift can be created in the panel there (`gift-admin add` without `--image` still can). No other storage exists.
- **MP4 effects are checked, not decoded.** The server reads the MP4's boxes (H.264 sample entry, size, length); the API
  image has no ffprobe/ffmpeg. A file whose boxes are valid but whose frames are broken passes and is skipped by the
  app when it cannot play it. Side-by-side detection is a size rule (width ≥ 1.8 × height); the admin can override it.
- **Side-by-side alpha needs Impeller.** The app composites it with a fragment shader through `ImageFilter.shader`,
  which runs only on Impeller (Flutter's default on Android and iOS). Where it is not available (or the shader fails to
  load) a transparent MP4 effect is skipped — the gift's picture in the strip is all that shows; the MP3 still plays.
  Not verified on a device (no device or emulator in this environment): the shader's orientation on OpenGLES and the
  video_player texture under `ImageFiltered` need a check on a real Android and iPhone.
- **Sound.** An MP4's own audio track plays only when the gift has no MP3; the MP3 (and since D207 an SVGA's embedded
  sound too) plays only while «المؤثرات الصوتية» is on and the live's local sound switch is not muted. On iOS the video
  player adds `mixWithOthers` to the live's audio session (its category is only upgraded, never replaced).
- **The panel's SVGA preview** draws the movie's bitmaps frame by frame (a small built-in reader); vector shapes,
  mattes and the embedded audio are not previewed (the app shows them).
- **Special categories** (LUCKY, QUIPS) can be renamed, reordered and given an icon, never turned off or deleted;
  gifts cannot be moved into them when deleting a category. A category added in the panel uses the POPULAR host share
  (`GIFT_HOST_SHARE_PERCENTS` has no entry for it).
- **Orphaned files.** A file uploaded in the form and then not saved (or replaced later) stays in the bucket, as with
  the CLI. Nothing deletes unused gift files yet.
- **Older apps** see only the five seeded categories (by code, with their own names) and cannot play MP4 / MP3.

## Admin account controls (v1.72-social draft, D208)

- **Lock vs ban:** a lock is temporary and never changes `users.status`; the ban stays the permanent SUSPENDED status.
  A banned account cannot be locked; unbanning does not end a running lock.
- **Reasons are shown to the person** for locks and restrictions (log-in refusal, notification). The dialogs say so;
  the team must write them for the user.
- **Temporary password:** shown once in the panel; the team hands it over outside the app (no SMS / email of it).
- **Email change:** no notice is mailed to the OLD address (only the verification to the new one).
- **Username change by the team:** the old username is held for the person 30 days (`ADMIN_USERNAME_RENAME_HOLD_DAYS`)
  as a GRACE special-username row, so it also appears in the panel's special-usernames list during that time.
- **Deletion by the team** uses D193's grace period: the person can still cancel it by logging in (as with
  `account-admin request`). Whether a team deletion should be cancellable is an owner question.
- **Comments** removed by the team cannot be restored (only posts, reels and stories can).
- **Daily cap** counts the amounts of one admin's adjustments per `ADMIN_DASHBOARD_TIME_ZONE` day; the CLI has no cap.
- **Timeline query:** `listAdminUserAudit` matches the team's content actions through the audit row's
  `metadata.authorId` (no index on it); fine at today's sizes, to revisit with a large audit log.
- **CLI lock:** a live the person hosts ends by the sweeper, not at once.
- **App:** the four new notification types (`ACCOUNT_RESTRICTED`, `ACCOUNT_RESTRICTION_LIFTED`, `BALANCE_ADJUSTED`,
  `PROFILE_EDITED_BY_TEAM`) are not rendered by this build of the app (it ignores unknown types; their push texts
  exist server-side, not checked end to end). The locked-account message, the restriction messages and the «كلمة مرور جديدة» screen are done.
- Not verified on a device or on the server.

## Live categories and the podcast live (v1.47-live draft, D212)

- **«بث ستريمر»** (phone screen share) is not built (D213): the hub tab and the go-live mode say «قريباً» and call nothing.
- **Guests picked in the podcast setup** are invited onto a speaker seat only once they are in the live (seat
  invitations travel on the room's data channel); there is no push or DM invitation yet.
- **Timed questions** end within one reconciliation run (≤ 15 s) on the server, or at once when the speaker's app is
  open (it leaves the seat itself). The countdown is the speaker's phone clock against the server's `demoteAt`.
- **Raised hands in the listeners row** are the hands of people in the first page of viewers (the room's viewer
  preview); a hand beyond it counts in the host's sheet but has no badge in the row.
- **No podcast recording** (owner: not now).
- **«ذكّرني»** follows the host (the CP-016 C reminder goes to followers 15 minutes before); a private host's follow is a
  request, so no reminder until it is accepted.
- **Join lines:** the server sends at most one per 200 ms per room; a burst above 5 a second loses lines (recharge
  and host agents' joins are never dropped). Gender comes only from people who show it on their profile.
- Not verified on a device (LiveKit active speaker, mic permissions, the sweeper's demotion on a real server).

## «دعوة الأصدقاء» — referral rewards in cherries (v1.74-social draft, D217)

- **Amounts are defaults to confirm** (owner gave none): inviter 20 000 cherries per sign-up (≈ $0.02 at the default
  payout rate), friend 0, 5 % of the first recharge, milestones 1 / 5 / 15 → 50 000 / 300 000 / 1 000 000, 20
  sign-up rewards a day per inviter, held 24 h, a code may be entered 7 days after sign-up, self-IP window 24 h. The
  programme is **on** after the migration; switch it off in the panel («إعدادات الدعوات») or with
  `referral-admin settings --set enabled=false --reason …` before the owner confirms, if wanted.
- **Device id:** the server had no device id before D217. `DeviceInfo.installId` is a random id the app keeps per
  install (shared preferences): uninstalling the app gives a new one, and older apps send none — then only the
  mailbox, IP and daily-cap rules apply. Not a hardware id.
- **Same-IP rule:** an invitee on the inviter's IP (seen within 24 h) is REJECTED. Mobile carriers share IPs (CGNAT)
  and families share Wi-Fi, so real friends can be refused; the team can approve them. Whether to keep the rule on is
  an owner question (`selfIpWindowHours` 0 turns it off).
- **No phone rule:** Kabso has no phone numbers.
- **Voiding after crediting** (owner 2026-11-01): the team's «إلغاء» takes the credited cherries back at once
  (`REFERRAL_REVERSAL`). A balance that does not cover it goes below 0 (a debt, like a gift reversal's); the app shows
  the negative balance and the history row, but has no special message about the debt — a withdrawal simply answers
  «insufficient cherries» until it is earned back. Milestone bonuses the inviter no longer reaches are taken back too;
  whether the owner wants that is to confirm.
- **Deep links:** the app has no deep-link package; the link `/i/<code>` opens the website, which shows the code to copy.
  The sign-up field is not pre-filled from the link.
- **No notifications** for a friend who joined or a reward credited (the page and the cherry history show them).
- **The ticker** shows masked names of people who got a reward in the last 30 days, regardless of their privacy
  settings (only the masked name and the amount).
- **Data export (D198)** does not include the referral rows yet.
- **Not verified on a device or on the server.** The Flutter tests ran (full suite) and the page has goldens and
  @3x test captures (fake data), not device captures.

## Media storage from the admin panel «التخزين (R2 / S3)» (v1.75-social draft, D222)

- **No real R2 call was made.** The round trip, the uploads, the cross-bucket copy and «not public» were verified with
  the production adapter (AWS SDK v3) against a local S3-compatible test server (`test/helpers/fake-s3.ts`) and against
  moto 5.2 (`S3_TEST_ENDPOINT`); Cloudflare R2 itself (its public r2.dev / custom-domain serving, a token limited to two
  buckets, a CopyObject between the two buckets of one account) is not verified here.
- **Changing a bucket or the public URL does not move stored files.** Media saved earlier keep their keys; their URLs
  are built from the public base URL in force now, so after a switch of public bucket or domain the old files are not
  found unless copied (with rclone or the R2 dashboard) to the new bucket. Choose the buckets and the domain once.
- **An upload slot signed just before a change of the PRIVATE bucket** (or of the account / keys) puts its bytes into
  the old bucket; its `complete` then looks in the new one and answers 422 `MEDIA_INVALID` (the app asks to try
  again). A change of the public bucket only is safe (shown by the e2e). Calls already running finish on their client.
- **Another API instance** sees a change within 5 s (the cache), on its next request.
- **The CLIs that touch files** (`gift-admin`, `banner-admin`, `profile-admin`, `host-admin`, `recharge-admin`,
  `account-admin`, `privacy-admin`) still use the env `S3_*` (one bucket) only, not the panel's settings.
- **No upload-size settings** in the section: the limits stay the API's constants (images 15 MiB, voice 1 MiB, videos
  per D162); the brief allowed them only if a config existed, and none does.
- **The env layout is one bucket.** Only the panel's settings have a separate private bucket; on the env fallback the
  `uploads/` and `private/` prefixes stay in the one bucket under the §5.3 rule (only `media/` may be public — which R2's
  bucket-wide public access cannot express: with R2, use the panel's two buckets).
- **The admin panel's capture** of the section used the local test server as «S3 متوافق» (an R2 account id cannot be
  tested offline); the R2 form itself was rendered and filled but not tested.

## Live settings per live type (D225, client only)

- **The host's camera off** mutes the published camera track (as a seated guest's, D174a). Viewers see the host's
  picture, but with the D170 «المضيف سيعود قريباً» line: the app cannot tell a camera turned off from a host whose
  app is in the background without a server signal (a participant attribute), which does not exist yet. The live is
  not ended for it (no away report is sent).
- **«كتم الجميع»** is one `POST …/seats/{index}/mute` per taken seat (no bulk endpoint): each one is checked and
  logged by the server as a seat action. A seat that fails is said once; the others stay muted.
- **YouTube** is hidden in every mode but the audio room on the client; the server still accepts a watch session in
  any mode (there is no per-mode flag in `/live/config`).
- **The viewer's sound and volume** (`LivePlaybackControls`) use `RemoteAudioTrack.disable()` for 0 and flutter_webrtc's
  `Helper.setVolume` on Android/iOS (the web has mute only; the slider's partial volume is not applied there).
- **Data saver** disables the received video publications of this live's own connection; a PK opponent's video
  (a second connection) is still received.
- **«التسجيل»** in the voice rooms stays an honest «قريباً».
- The AUDIO host bar keeps its «قريباً» PK button (D225b, owner): its mic is a tile in ≡ (and the «إعدادات البث» row),
  not on the bar, so the bar fits 393 and 360 dp; a podcast has no PK by the owner's decision (its bar has the mic).
- Not verified on a device (remote volume, the data saver, the camera off seen by viewers).

## The social redesign (v1.76-social draft, D218)

- **Feed mix.** `tab=mixed` merges the newest 500 Following entries with Trending's 500-entry snapshot; past those
  1 000 entries the feed ends (pull to refresh starts a new snapshot). Visibility is re-checked per page (posts that
  became invisible leave the page; new posts wait for the next snapshot).
- **The posts page has one feed.** The Trending / Following tabs left Posts (the owner's top bar); the API keeps both
  tabs and the reels page keeps Following · For You · Nearby.
- **«مقترح لك»** means «you do not follow the author» (`Post.viewerFollowsAuthor` false), not a recommendation model.
- **Stories tray LIVE pills** come from the first page of `GET /live/rooms?tab=following` (up to 50 followed hosts
  live now); a host beyond it gets no pill. The tray hides when it has no story and nobody live (owner: «Hide the
  tray when it is empty»), so an account without stories and without live friends sees no «قصتك» there — the
  Create button still adds a story.
- **Story replies** go to the author's DMs as plain text («❤️» for the heart) with no reference to the story; the DM
  rules apply (the app shows the server's refusal).
- **Profile cover:** no crop step (the picture is uploaded whole and covers the banner); no report reason specific to
  covers (a report of the user covers it); the panel's «حذف صورة الغلاف» shows for every user and answers «no cover»
  when there is none (the panel's user view does not carry the cover yet).
- **Country and «انضم في»** are public on the profile from this version (the owner asked for the row); there is no
  switch to hide the country yet.
- **No verification badge** (owner: decided later).
- Not verified on a device (the keyboard over the story reply, the cover under the status bar on notched phones).


## At most 2 accounts created per device (v1.78-social draft, D223)

- **The id can change or be faked.** Android `ANDROID_ID` survives a reinstall and «clear data» but changes on a
  **factory reset** (and differs per app-signing key and per Android user profile); the iOS Keychain id survives a
  reinstall but not **erasing the iPhone** (it is `ThisDeviceOnly`, so a backup restored to another phone gets a new
  one). A **rooted or jailbroken** phone, an emulator or a modified app can send any value. The rule raises the cost of
  mass sign-ups; it does not stop a determined person.
- **No device key, no count.** A sign-up from the website, from an app older than D223, or from a client that omits
  `device.deviceKey` is allowed and not counted (owner brief: «No device id → allowed»). The limit only binds the
  current apps.
- **Not verified on a real phone.** The channel code (`MainActivity.kt`, `AppDelegate.swift`) was not run here (no
  Android device or emulator, no macOS / Xcode in this environment); that ANDROID_ID stays the same across a reinstall
  and that the Keychain item survives deleting the app come from the platform documentation, not from a test. The Dart
  side is covered by tests with a mocked channel only.
- **The copy names 2.** «لا يمكن إنشاء أكثر من حسابين…» is the owner's text for the default; a device with an exception
  (or a changed `SIGNUP_MAX_ACCOUNTS_PER_DEVICE`) gets the number from the error's detail with ICU plurals.
- **Shared phones.** A family sharing one phone can create only 2 accounts on it; an OWNER can raise the limit for
  that device in the panel (user page → «الجهاز»). Accounts made before D223 have no device and never count.
- **Rotating the key resets the counts.** Changing `SIGNUP_DEVICE_KEY` (or `RATE_LIMIT_KEY_SECRET` while it is unset)
  makes every device start again from 0.

## The free camera effects engine beside DeepAR (v1.49-live draft, D228)

- **Never run on a phone.** No Android device or emulator here, and the full APK was not built in this environment
  (disk shared and short; see the board row). What ran: the plugin's Kotlin compiled against the real DeepAR 5.6.22,
  WebRTC 150.7871.01, ML Kit segmentation-selfie 16.0.0-beta6 and MediaPipe tasks-vision 1.1.1 classes; the JVM tests;
  the GLSL compiled in WebGL 1 (GLSL ES 1.00, SwiftShader) with the warp checked pixel by pixel against the Kotlin
  twin. **Unverified:** frame rate (target 30 fps at 720p), the real per-frame GPU time and the 40 ms budget, picture
  quality of the blur edge and the beauty, memory, heat/battery, front/back camera orientation of the mask and the
  landmarks, the face model download on mobile data, R8/ProGuard in a release build (consumer keep rules were added for
  MediaPipe; ML Kit ships its own).
- **Lag on fast movement.** Segmentation and landmarks run asynchronously on a 256-px copy (every other frame when the
  phone keeps up); the frame drawn uses the latest result, one or two frames old. The slimming/eye warp can trail a
  quickly moving face; the masks are smoothed over time on purpose.
- **Slow phones.** A frame whose GPU work is not done in 40 ms goes out raw; 3 slow frames in a row → 30 frames raw;
  3 such back-offs without 90 good frames between them → the effect switches off (`too_slow`, Magic says why).
- **Usage metrics to Google.** ML Kit and MediaPipe send Google their own usage/performance metrics (never the
  picture). Not turned off. Owner approved disclosing it (2026-11-01): the privacy policy text has the line (§2 and
  §5 of `infra/deploy/site/privacy.html`, ar + en), **not yet published as a new version** (the owner publishes);
  the Play Data safety answers are PP-39 — the Google pages behind them could not be opened from the authoring
  environment and must be re-read when the form is filled.
- **APK size:** about +36 MB of native code per ABI (arm64, uncompressed, ~12 MB compressed; approved by the owner
  2026-11-01); see docs/DEPLOYMENT.md §9.2.
- **One engine for every host.** The server switch is global; the per-phone override exists only in debug/profile
  builds. iOS is unchanged (no camera processor there yet).

### Removing the free engine (if the owner does not like it)

1. `apps/mobile/packages/kabso_camera_fx/android/`: delete `src/main/kotlin/com/kabso/kabso_camera_fx/FreeFxStage.kt`,
   `FreeFxGl.kt`, `FreeFxRules.kt` and `src/test/kotlin/com/kabso/kabso_camera_fx/FreeFxRulesTest.kt`; in
   `build.gradle` remove the two `implementation` lines (`com.google.mlkit:segmentation-selfie`,
   `com.google.mediapipe:tasks-vision`) and set `minSdkVersion` back to 23 if wanted; in `proguard-rules.pro` remove the
   D228 block; in `CameraFxProcessor.kt` remove `Engine`, `freeFx`, `setEngine`, `setFreeFx` and the `when` in
   `onFrame` (back to `deepAr::process`); in `KabsoCameraFxPlugin.kt` remove `setEngine` / `setFreeFx` and the
   `engine` / `freeFx` fields; in `THIRD_PARTY_NOTICES.md` remove the D228 section.
2. Plugin Dart (`lib/kabso_camera_fx.dart`): remove `KabsoCameraFxEngine`, `KabsoFreeFx`, `setEngine`, `setFreeFx` and
   the D228 diagnostics fields; their tests in `test/kabso_camera_fx_test.dart` (group «D228 free engine»).
3. App: delete `lib/features/live/data/beauty/live_fx_engine.dart`,
   `lib/features/live/application/live_fx_engine_providers.dart`, `test/features/live/free_fx_d228_test.dart`; remove
   `LiveBeauty.free`, `LiveMediaEngine.fxEngine/setFxEngine` (+ `LiveKitMediaEngine`, `FakeLiveMediaEngine`),
   `LiveCameraFx.setEngine/_syncFree`, `LiveHostController.setFreeBeauty/setFxEngine`, the `listenManual` in
   `go_live_screen.dart`, Magic's `fxEngine/freeBeauty/onFreeBeauty` and `_FreeBeautySection` in `go_live_parts.dart`,
   the overlay's override chips and `_freeLines` in `live_fx_diagnostics.dart`, `PreferenceKeys.debugCameraFxEngine`,
   the `liveFreeBeauty*` / `liveEffectsEngineFree` strings (keep `liveEffectUnavailableSlow` only if wanted), and
   `LiveConfig.cameraFxEngine` (regenerate with build_runner); the fakes' `setEngine/setFreeFx`.
4. API/admin (optional — DEEPAR is the default, so leaving them is harmless): `src/modules/site-settings/camera-fx.rules.ts`
   (+ spec), `AdminCameraFxController`, `SiteSettingsService.getCameraFx/updateCameraFx`, `LiveConfigDto.cameraFxEngine`
   in `live-rooms.service.ts`, `test/d228-camera-fx.e2e-spec.ts` and the line in `kl037`; the panel card in
   `apps/admin/src/pages/SiteSettings.tsx`, `src/i18n-d228.ts`, `test/camera-fx.test.tsx`; the contract
   (`CameraFxEngine`, `CameraFxSettings`, `UpdateCameraFxRequest`, the two operations, the `LiveConfig` field,
   CONVENTIONS §10.79) through a contract change; a new migration may delete the `cameraFxEngine` row and restore the
   CHECK.
5. Privacy and store: remove the camera-effects paragraph and the Google (ML Kit / MediaPipe) processor line from
   `infra/deploy/site/privacy.html` (publish as a new version) and drop PP-39 / its Data safety answers.
6. On phones: the downloaded model (`files/kabso_camera_fx/face_landmarker.task`, 3.6 MB) is deleted with the app's
   data; an update that removes the engine leaves it until then (harmless).

