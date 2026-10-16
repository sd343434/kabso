# KL-035a: Home and Live visual review package (current HEAD, pre-KL-047)

This package is for the owner's review of the **Home** and **Live discovery** screens as they
stand on the integration branch today. It is the **"before" baseline for KL-047** (the Home and
Live implementation pass now running). The same capture matrix is re-run on KL-047's build as
the "after" set.

**The analysis is in [`../../KABSO_LIVE_VISUAL_REVIEW.md`](../../KABSO_LIVE_VISUAL_REVIEW.md).**
That document covers, per screen: what works, weaknesses, typography and spacing, RTL/LTR,
differences from D36/D39, HL-H1–HL-H6 and VG-xx, responsible files and widgets, and prioritized
changes with acceptance criteria. This README holds the provenance, the file index, the
before/after table, the goal check and the gap table.

| | |
| --- | --- |
| App revision | `04ffd09` (`claude/amazing-tesla-5aj3um` HEAD; the tracked files of `apps/mobile` at that commit) |
| API revision | `04ffd09` (same commit; `apps/api` built with `pnpm build`) |
| Captured | 2026-10-16 |
| Toolchain | Flutter 3.47.7 (engine `deb287481e`), Chromium 141 headless (Playwright 1.56.1), Node 22.22, PostgreSQL 16.15, Redis 7 |
| Viewports | 393×852 and 360×800 CSS px at deviceScaleFactor 3 (PNGs are 1179×2556 and 1080×2400) |
| Locales | `ar` (RTL) and `en` (LTR); dark theme (the default) |

## Labels: what each folder shows

Every screenshot has exactly one of three labels, given by its folder.

| Folder | Label | Meaning |
| ------ | ----- | ------- |
| [`head-04ffd09-pre-kl047/production/`](head-04ffd09-pre-kl047/production/) | **Production behaviour** | What production shows today. Home has no feed API, so every tab shows its unavailable state. Live has `LIVE_HOSTING_ENABLED=false` (the production default, D37), so it shows hosting-unavailable. The real app ran against the real local API; no data is involved |
| [`head-04ffd09-pre-kl047/local-api/`](head-04ffd09-pre-kl047/local-api/) | **Local API data** | The real app against the real API in a **local review environment** with `LIVE_HOSTING_ENABLED=true`. All rooms, hosts, follows and categories are local test data created as described below. Some states use a network condition (delay, API stopped, or a simulated proxy 502); each is named in the file index |
| [`fixtures/`](fixtures/) | **Test fixture render — not live data** | Copies of the approved goldens from `apps/mobile/test/goldens/png/`. These are headless widget-test renders of fixture data with designed covers, not screenshots of the running app |

Production and local-API screenshots are **real screenshots of the running Flutter app**: a web
build of the production code, unchanged. None is a mockup or a composite.

## 1. How the screenshots were produced

### 1.1 App: web build from a scratch copy

The repo has no web platform and none was added. The build ran in a scratch folder outside the
repo:

```sh
# from apps/mobile at 04ffd09
git ls-files | tar -cf - -T - | tar -xf - -C <scratch>/webapp
cd <scratch>/webapp
flutter create --platforms=web --project-name kabso_live .
flutter build web --profile --dart-define=API_BASE_URL=http://localhost:3103
python3 -m http.server 8135 --bind 127.0.0.1 --directory build/web
```

- `--profile` is used because release builds refuse an `http` base URL.
- CanvasKit was served from the build's own `build/web/canvaskit/` by request interception, not
  from the CDN.
- All other non-localhost requests were blocked. The only one seen is a Roboto fallback font
  request from the engine; the app's bundled Inter, IBM Plex Sans Arabic and Material Icons
  rendered every glyph.

### 1.2 Capture

- **Tooling:** Playwright 1.56.1 with the preinstalled Chromium, headless. `isMobile: false`,
  `hasTouch: false`.
- **Profiles:** one persistent browser profile per locale×width (`en-393`, `en-360`, `ar-393`,
  `ar-360`) with browser locale `en` or `ar`.
- **Login:** the reviewer account logged in **once per profile through the app's own login
  screen**. Each later run restored the session from the app's own stored refresh token.
- **Arabic:** in the `ar` profiles Arabic was made an explicit choice with the login screen's
  language switch. Without that, the app adopts the account's stored locale at sign-in, as
  designed (`locale_sync.dart`).
- **Navigation:** taps go through Flutter's semantics tree, on the bottom-nav "Live" item, the
  tab labels and the chip labels. After each tap the mouse is parked over empty content, so
  that no web-only hover highlight shows.
- **Timing:** each screenshot is taken 2.5–6 s after the action. Animations were **not**
  disabled.
- **Safe areas:** no status bar or home indicator is drawn, and the safe-area insets are 0 (a
  browser has none). The fixture goldens at 393 use 59/34 insets.
- **Scripts:** the capture scripts are kept in the CTO-assigned scratchpad and are not
  committed: `scratchpad/kl035a/capture.mjs` (driver), `pw.mjs` (browser setup), the
  `plan-*.json` files (one per state group) and `login.mjs`.

### 1.3 API: local review environment

- **Process:** `apps/api` at `04ffd09` (`node dist/main.js`) on port 3103, with `NODE_ENV=development`,
  `MAIL_TRANSPORT=log` and `CORS_ORIGINS=http://localhost:8135`.
- **Stores:** Redis DB 3 and the local database `kabso_kl013_dev`.
- **Database setup:** the database was emptied and re-migrated with `prisma migrate deploy` as
  the **migration role**. The API ran as the DML-only **runtime role**. No superuser was used.
- **Secrets:** local throwaway values only; none is recorded here.
- **Registration limits:** for account setup only, `RATE_LIMIT_REGISTER_IP` and
  `RATE_LIMIT_REGISTER_VERIFY_IP` were raised by environment variable. All other settings were
  defaults.

### 1.4 What data is real local test data, and how it was made

All of it lives only in the local, disposable `kabso_kl013_dev` database.

| Data | How it was created |
| ---- | ------------------ |
| 9 accounts: `test.reviewer` ("Reviewer Test") and 8 hosts: `test.sara` "Sara Test", `test.omar` "Omar Test", `test.nora` "Nora Test", `test.hana` "Hana Test", `test.layla` "ليلى تجربة", `test.khalid` "خالد تجربة", `test.yousef` "يوسف تجربة", `test.ali` "علي تجربة" | Real verify-first registration: `POST /auth/register`, then the 8-digit code from the dev `log` mail transport, then `POST /auth/register/verify` |
| Reviewer follows `test.sara` and `test.layla` | `PUT /users/{username}/follow` as the reviewer |
| 3 categories: `local-music` "Local test: Music / محلي: موسيقى", `local-chat` "Local test: Chat / محلي: دردشة", `local-games` "Local test: Games / محلي: ألعاب" | **Inserted with SQL into `live_categories` as the migration role.** v1.3 has no admin API for categories (D37). The names are deliberately marked as local test data |
| 8 live rooms, for example "Evening oud practice" (music), "قراءة شعر مسائية" (music), "تحدي الشطرنج مع المتابعين" (games), "Learning Arabic calligraphy, lesson 3" (no category), "تحضير عشاء عائلي بسيط" (no category) | Each host logged in and called `POST /live/rooms`. A heartbeat loop (`POST /live/rooms/{id}/heartbeat` every 10 s) ran during capture |
| Viewer counts | **0 for every room.** Presence does not exist, so the cards honestly show "New / جديد". The database was not edited to fake counts. Popular and New therefore have the same order (D38) |
| Covers and avatars | None. No upload API exists yet, so every card shows the initial-letter fallback |

### 1.5 State conditions

| State | Condition |
| ----- | --------- |
| Production (`production/`) | API running with `LIVE_HOSTING_ENABLED=false` |
| `live.empty-*` | API with hosting on, before any host went live |
| `live.loading` | API with hosting on; the browser held every `/api/v1/live/*` request for 15 s (request interception), so the 300 ms-delayed skeleton shows |
| `live.error-api-down` | App booted with the API up; then the API process was stopped and the Live tab opened (connection refused) |
| `live.error-proxy-502` | **Simulated proxy fault:** the browser answered `/api/v1/live/rooms` with a bare 502 HTML body, as a failing reverse proxy would. That request never reached the API |
| `live.populated-*`, `live.category-selected`, `live.scrolled-end` | API with hosting on, 8 live rooms heartbeating, categories present |

## 2. File index

### Production behaviour: `head-04ffd09-pre-kl047/production/`

Each state exists as `.{ar,en}.{393,360}.png`.

| File stem | Shows |
| --------- | ----- |
| `home.popular-unavailable` | Home, Popular (default): "Popular posts are coming soon" |
| `home.following-unavailable` | Home, Following unavailable |
| `home.new-unavailable` | Home, New unavailable |
| `live.unavailable-popular` | Live hub, Popular (default), hosting off: "Live rooms aren't available yet" with the lone All chip |
| `live.unavailable-following` | Live, Following, hosting off |
| `live.unavailable-new` | Live, New, hosting off |

### Local API data: `head-04ffd09-pre-kl047/local-api/`

| File stem | Shows |
| --------- | ----- |
| `live.loading` | Popular loading skeleton (6 cards, 3 rows) |
| `live.empty-popular` | Hosting on, no rooms: "No one is live right now" |
| `live.empty-following` | "No one you follow is live" with the "See popular" button |
| `live.empty-new` | New, empty |
| `live.error-api-down` | Error with Try again; the offline message, because the connection was refused |
| `live.error-proxy-502` | Error with Try again; "Something went wrong on our side" (simulated proxy 502) |
| `live.populated-popular` | Popular, 8 rooms, chips All + 3 local test categories |
| `live.category-selected` | "Local test: Music" selected: 2 rooms (Sara, Layla) plus the end caption |
| `live.scrolled-end` | All selected, scrolled to the end: chip row scrolled away, end-of-list caption "Pull down for new live rooms" |
| `live.populated-following` | Following: the 2 followed hosts plus the end caption |
| `live.populated-new` | New: same 8 rooms, newest first |

### Test fixture render — not live data: `fixtures/`

These are copied unchanged from `apps/mobile/test/goldens/png/` and renamed:
- `live_hub.X.L.phone.png` → `live.X.L.393.png`;
- `*.android.png` → `.360.png`.

They are 1× renders (393×852 / 360×800 px). The 393 renders carry 59/34 dp insets.

| File stem | Shows (fixture data) |
| --------- | -------------------- |
| `live.populated` | Grid with designed covers, viewer chips, PK and multi-guest tags, small host avatars |
| `live.categories` | Chip row with fixture categories |
| `live.footer_loading` | Paging footer with 2 skeleton cards |
| `live.footer_error` | Inline "Couldn't load more · Retry" footer |
| `live.end` | End-of-list caption |
| `home.populated` | Home feed post tiles (no feed API exists) |

Other fixture goldens (rooms, gift panel, PK) are in `apps/mobile/test/goldens/png/` and are
outside this review (KL-034 is on hold).

## 3. Before / after

- **Before:** [`docs/design/audit/2026-10-16-before/`](../../audit/2026-10-16-before/) (KL-030),
  a headless widget render at 393×852 with no insets, before the redesign.
- **Now:** this package, the running app at `04ffd09`.
- **After:** the KL-047 set, to be captured with the identical matrix.

| Screen | Before (KL-030) | Now (`04ffd09`, this package) | After (KL-047) |
| ------ | --------------- | ----------------------------- | -------------- |
| Home | [`home.en.png`](../../audit/2026-10-16-before/home.en.png), [`home.ar.png`](../../audit/2026-10-16-before/home.ar.png): wordmark title bar, 88 dp icon circle, one screen-centred "Your feed is on its way" | `production/home.{popular,following,new}-unavailable.*`: Following · Popular · New header with search, compact per-tab state at the top of the content region | pending |
| Home, light | [`home-light.*`](../../audit/2026-10-16-before/) | not captured (dark is the default; out of the requested matrix) | pending |
| Live | [`live.en.png`](../../audit/2026-10-16-before/live.en.png), [`live.ar.png`](../../audit/2026-10-16-before/live.ar.png): "Live" title bar, 88 dp circle, "Live rooms are coming" | Production: `production/live.unavailable-*`. With hosting on: the `local-api/` set (loading, empty, error, populated, category, end) | pending |
| Cover cards | [`component-cover_cards.*`](../../audit/2026-10-16-before/): red accent line, LIVE badge, "0" viewers, "Cover couldn't load" | `local-api/live.populated-*`: no accent line, no LIVE badge, "New" chip, initial-letter fallback with no error text | pending |

## 4. Design goals: met, partially met or not met

Evidence names are file stems. `P/` means `head-04ffd09-pre-kl047/production/`, `L/` means
`head-04ffd09-pre-kl047/local-api/` and `F/` means `fixtures/`.

### Owner decisions

| Goal | Status | Evidence / note |
| ---- | ------ | --------------- |
| D36: Home = social feed with Following · Popular · New, default Popular, no wordmark, search | **Met** (structure) | `P/home.*`. The feed itself is fixture-only (`F/home.populated`); no feed API exists |
| D36: Live tab = live-discovery hub, same three tabs | **Met** | `P/live.unavailable-*`, `L/live.populated-*` |
| D39: Home and Live do not share the same room grid | **Met** | `P/home.*` shows no room cards |
| D39: Live opens on Popular | **Met** | `P/live.unavailable-popular`, `L/live.populated-popular` (Popular selected on arrival) |
| D39: polished discovery with clear thumbnails | **Not met** | `L/live.populated-*`: every card is a grey tile with an initial letter (no cover upload, no avatars) |
| D39: creator identity | **Partially met** | Name on every card and a letter avatar. No real avatar, so no recognisable identity |
| D39: category navigation | **Met** (with local test categories) | `L/live.populated-popular`, `L/live.category-selected`. Production has no categories (D37) |
| D39: search | **Partially met** | The search icon is present on both screens and goes to Discover, which is still a placeholder (VG-08) |
| D39: no fabricated rooms, counts or categories in production | **Met** | `P/*`. Viewer counts show "New", not 0 or invented numbers |

### HL-H1 to HL-H6

| Goal | Status | Evidence / note |
| ---- | ------ | --------------- |
| HL-H1 header: tabs + search, 48 dp, no wordmark or decorative icons | **Met** | all captures |
| HL-H2 tab style: 18/600 selected with a 16×3 indicator, 15 secondary unselected | **Met** | all captures. Arabic unselected labels read small (see the review doc) |
| HL-H3 chip row on Popular only; All only without server categories | **Met** | `P/live.unavailable-popular` (All only), `L/live.populated-popular`; no chips on Following/New |
| HL-H4 grid: 2 columns, 3:4, padding 8, gap 4 | **Met** | `L/live.populated-popular` |
| HL-H4 card overlays: viewer/New top-start, mode tag top-end, scrim + name + title | **Partially met** | New chip, scrim, name and title: yes. Mode tags are fixture-only (`F/live.populated`); the API has no PK/multi-guest rooms yet |
| HL-H4 featured strip and following-live rail | **Not met** (by design) | No featured API; no rail. Correctly absent |
| HL-H5 pull-to-refresh, paging, footer skeleton/error, end caption | **Partially met** | End caption: `L/live.scrolled-end`, `L/live.category-selected`. Footer loading/error: fixture only (`F/live.footer_*`), because 8 real rooms fit one page (limit 20). Pull-to-refresh is not demonstrable with a mouse |
| HL-H6 unavailable | **Met** | `P/live.unavailable-*`, `P/home.*` |
| HL-H6 loading (6 skeletons after 300 ms) | **Met** | `L/live.loading` |
| HL-H6 empty Popular/New and empty Following + "See popular" | **Met** | `L/live.empty-*` |
| HL-H6 error + Try again | **Met** | `L/live.error-api-down`, `L/live.error-proxy-502` |
| HL-H6 offline (banner + auto-retry on reconnect) | **Not met** (QA-003) | `L/live.error-api-down` shows the generic compact error with offline copy; there is no banner and no reconnect listener |
| HL-H6 populated = fixture-only until the API | **Superseded** | The API exists (KL-037); real data renders (`L/live.populated-*`) |

### VG-xx items targeted by KL-033

| VG | Status | Evidence / note |
| -- | ------ | --------------- |
| VG-01 structure visible with no data; ≥ 4 full cards in the first populated viewport with insets | **Met** for structure (`P/*`). Card count: fixture `F/live.populated` (4 full + start of row 3). The running app has no insets: `L/live.populated-popular` shows 4 full + row 3 |
| VG-02 Live tab role decided | **Met** (D36: discovery hub) |
| VG-03 compact in-place states (48 dp icon, top third, no circle) | **Met** | `P/*`, `L/live.empty-*`, `L/live.error-*` |
| VG-05 top bar = tabs + search | **Met** |
| VG-06 category chip row | **Met** |
| VG-07 two-level tabs vs chips | **Met** |
| VG-09 grid density | **Met** |
| VG-10 no LIVE badge, no accent line in the grid | **Met** | `L/live.populated-*` |
| VG-11 "New" instead of 0 | **Met** | `L/live.populated-*`. It shows on every card while presence is missing (gap RG-10) |
| VG-12 mode tags only with data | **Partially met** | Fixture only; also the room **category** is not shown on cards (RG-05) |
| VG-13 quiet broken/missing-cover fallback | **Met** | Initial-letter avatar and no error text. It is the only visual today (RG-03) |
| VG-14 featured slot only with data | **Met** (absent) |
| VG-16 solid PK badge | **Met** (fixture) | `F/live.populated` |
| VG-19 nav: active dot, `textPrimary` label | **Met** | all captures |
| VG-22 no AppBar title on Home | **Met** |
| VG-41 pull-to-refresh + pagination | **Partially met** | See HL-H5 |
| VG-42 swipe between tab pages | **Not verified** | The pager exists (`FeedTabsScaffold`); swiping was not exercised in this capture |
| VG-44 card press scale + push into room | **Not met** | Cards are not tappable until slice 2 (QA-004) |

## 5. Remaining visual gaps

Paths are relative to `apps/mobile/`. The analysis and the acceptance criteria are in
[`KABSO_LIVE_VISUAL_REVIEW.md`](../../KABSO_LIVE_VISUAL_REVIEW.md) §4.

| ID | Description | Severity | Flutter file(s) responsible | Evidence |
| -- | ----------- | -------- | --------------------------- | -------- |
| RG-01 | **QA-003:** the HL-H6 offline state is missing. Connection loss shows the generic compact error with offline text; there is no offline banner and no auto-retry on reconnect (no connectivity listener) | Medium | `lib/app/shell/feed_region.dart` (`FeedRegion`), `lib/core/error/failure_widgets.dart` (`FailureErrorState`), `lib/features/live/application/live_rooms_provider.dart`, `lib/core/network/error_mapper.dart` | `L/live.error-api-down` |
| RG-02 | Cards are not tappable until slice 2 (no room screen; `onOpenRoom` is null, so there is no button semantics and no press feedback) | Medium (expected, QA-004) | `lib/features/live/live_screen.dart` (`_LiveHubPage` → `LiveHubBody.onOpenRoom`), `lib/features/live/presentation/widgets/live_cover_card.dart` (`_CardFrame`) | all `L/live.populated-*` |
| RG-03 | No covers or avatars (no upload API). Every card is about 75 % flat grey with a large (`KSizes.avatarLg`) initial-letter circle; the grid reads as placeholders, not as people live now (D39 "clear thumbnails") | High (product), blocked on upload | `lib/features/live/presentation/widgets/live_cover_card.dart` (`_CoverFallback`), `lib/features/live/presentation/widgets/live_view_data.dart` (`LiveRoomCardData.fromSummary`) | `L/live.populated-popular.*` |
| RG-04 | **Bidi:** card name and title use the UI direction, not the text's own. A Latin title in RTL renders "…Learning Arabic calligraphy," (ellipsis on the wrong side, comma moved), and "…Morning coffee and quest". Arabic names in `en` are left-aligned | Medium | `lib/features/live/presentation/widgets/live_cover_card.dart` (`KLiveCoverCard`, the two `Text` widgets in the bottom `Column`) | `L/live.populated-popular.ar.393`, `L/live.scrolled-end.ar.360`, `L/live.populated-new.ar.360` |
| RG-05 | The room category is returned by the API but not shown on the card (dropped when the view data is built), so with All selected you cannot tell rooms apart by topic | Low | `lib/features/live/presentation/widgets/live_view_data.dart` (`LiveRoomCardData`), `live_cover_card.dart` | `L/live.populated-popular` |
| RG-06 | Titles truncate at 1 line well before the card edge on long English titles (about 25 characters at 393, 22 at 360) | Low | `live_cover_card.dart` (title `Text`, `caption` style) | `L/live.populated-popular.en.360` |
| RG-07 | Large empty space: compact states use about 20 % of the screen, and the remaining ~65 % is flat background (Home tabs, Live unavailable/empty/error, Following with 2 rooms) | Low–Medium (design decision; D35 forbids filler) | `lib/app/shell/feed_region.dart`, `lib/design_system/components/k_states.dart` (`KEmptyState` compact) | `P/home.*`, `P/live.unavailable-*`, `L/live.populated-following` |
| RG-08 | Vertical rhythm differs between tabs: on Popular the state block sits 48 dp lower than on Following/New because of the chip row. The lone non-interactive "All" chip also shows in unavailable/loading/error, where there is nothing to filter | Low | `lib/features/live/live_screen.dart` (`LiveHubBody._chips`, `header:`) | `P/live.unavailable-popular` vs `P/live.unavailable-following` |
| RG-09 | The Live → New unavailable icon (`Icons.new_releases_outlined`) reads as a warning/alert badge | Low | `lib/features/live/live_screen.dart` (`LiveHubBody`, `unavailableIcon`) | `P/live.unavailable-new.*` |
| RG-10 | "New / جديد" chip on every card (all viewer counts are 0). On the **New** tab every card repeats the tab name. The white chip is the highest-contrast element on the card | Low | `live_cover_card.dart`, `lib/design_system/components/k_badge.dart` (`KBadge.newRoom`) | `L/live.populated-new.*` |
| RG-11 | Popular and New show the identical list and order until presence exists (D38); the two tabs look duplicated | Info (API) | none in Flutter (API ordering) | `L/live.populated-popular` vs `L/live.populated-new` |
| RG-12 | Arabic secondary text (state bodies, unselected tabs, card titles) looks visibly smaller and lighter than Latin at the same token size (IBM Plex Sans Arabic proportions) | Low | `lib/design_system/tokens/tokens.dart` and `lib/design_system/theme/app_theme.dart` (text styles), `lib/design_system/components/k_tabs.dart` (`_Tab`) | `P/home.popular-unavailable.ar.*` vs `.en.*` |
| RG-13 | The loading skeleton has very low contrast on the near-black background | Low | `lib/design_system/components/k_skeleton.dart`, `live_cover_card.dart` (`KLiveCoverCardSkeleton`) | `L/live.loading.*` |
| RG-14 | The session-restore failure screen (seen when the API is down at launch) still uses the pre-redesign 88 dp circle state (VG-03 anti-pattern). Outside Home/Live, but on the path into them | Low | `lib/features/auth/presentation/splash_screen.dart`, `k_states.dart` (non-compact `KEmptyState`/`KErrorState`) | not committed (observed during capture) |
| RG-15 | Safe areas are not verified on a device: the web captures have 0 insets. The header and nav padding with real 59/34 insets are seen only in fixtures | Info | `lib/app/shell/feed_tabs_scaffold.dart` (`SafeArea`), `lib/app/shell/app_shell.dart` (`KBottomNav`) | `F/*.393` |

## 6. States that could not be captured from the running app

| State | Why | What is shown instead |
| ----- | --- | --------------------- |
| Footer loading and footer error (paging) | The page limit is 20 and there are only 8 real rooms, so there is no second page. Faking more rooms or failing a cursor would fabricate data | Fixtures `F/live.footer_loading`, `F/live.footer_error` |
| Offline banner / auto-retry | Not implemented (RG-01, QA-003) | `L/live.error-api-down` (what offline shows today) |
| Pull-to-refresh indicator | A headless mouse cannot perform the pull gesture | none |
| PK / multi-guest tags, non-zero viewer counts, covers | No such data exists through the API (no presence, no PK, no upload); the DB was not edited | Fixture `F/live.populated` |
| Populated Home feed | No feed API exists | Fixture `F/home.populated` |

## 7. Reference comparison: pending — no authorized references supplied

No authorized reference screenshots exist in this repository or in this review, so **no visual
comparison against any third-party app was made, and none is claimed**. The layout follows the
documented Kabso decisions only.

A reference comparison would need:
- the owner to supply authorized reference screenshots (REFERENCE_INVENTORY §5, rows 1–5 first)
  into the git-ignored `design/references/`. They are never committed while the repo is public
  (D40);
- the same states captured at the same device size;
- a side-by-side review that records only structural observations (hierarchy, density,
  placement), with no copied measurements or assets.
