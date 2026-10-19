# Kabso Live — Reference Inventory & Live-UI Gap Analysis (KL-021)

Status: **Documentation only (A5).** Nothing here is implemented by this document. It records
what the app renders today, the target live-streaming experience, and the gaps between them. It
prepares for the owner-supplied, authorized reference screenshots of the reference app (BIGO
LIVE).

**Ground rules**

- **No reference screenshots exist yet.** None were fetched from the web, and none may be. Every
  pattern below comes from general knowledge of the live-streaming genre. Nothing here
  reproduces a specific screen.
- **Fidelity boundary (owner decision pending, proposed `D-KL021`):**
  - **Option A, pattern fidelity (assumed by this doc):** Kabso follows the reference app's
    interaction patterns, information hierarchy, navigation structure, screen composition and
    live-room flow. Visual identity stays Kabso's own: tokens, typography, iconography, artwork,
    copy and motion.
  - **Option B, closer visual reproduction:** this raises trade-dress and copyright risk. The
    risk is flagged in every place it applies. The master prompt forbids copying proprietary
    logos, exact layouts and copyrighted assets, so Option B can never cover those.
- **Risk flags used in tables:**
  - **TD**: trade-dress risk if reproduced closely (distinctive look and feel, colour scheme,
    exact arrangement).
  - **CR**: copyright or asset risk (artwork, animations, icons, sounds, text).
  - **TM**: trademark or brand-name risk (names of features, currencies or levels).
  - **—**: a generic genre pattern with low risk at pattern level.

Related specs:
- [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md): tokens, components, motion, gift budget.
- [`SCREEN_INVENTORY.md`](SCREEN_INVENTORY.md): all screens by phase.
- [`PHASE1_SCREENS.md`](PHASE1_SCREENS.md) and [`PHASE1_1_SCREENS.md`](PHASE1_1_SCREENS.md).
- [`../contracts/design-tokens.json`](../contracts/design-tokens.json).
- [`../IMPLEMENTATION_PLAN.md`](../IMPLEMENTATION_PLAN.md).

---

## 1. Current implementation inventory (at `f8fd0cb`)

Paths are relative to `apps/mobile/lib/`. The route registry is `app/router/routes.dart` and the
router is `app/router/app_router.dart`, which uses GoRouter with a
`StatefulShellRoute.indexedStack`. An auth redirect lives in `app/router/auth_redirect.dart`.

### 1.1 Screens and routes

| Route | Screen (file) | What it renders | Data source |
| ----- | ------------- | --------------- | ----------- |
| `/splash` | `SplashScreen` (`features/auth/presentation/splash_screen.dart`) | Wordmark, progress indicator, and an error state with retry | **Real API**: session restore via `POST /auth/refresh` and `GET /me` (`session_controller.dart`) |
| `/auth/login` | `LoginScreen` (`…/login_screen.dart`, inside `AuthScaffold` from `widgets/auth_widgets.dart`) | Identifier and password fields, forgot link, register prompt, failure banner with countdown and Error ID | **Real API**: `POST /auth/login` |
| `/auth/register` | `RegisterScreen` (`…/register_screen.dart`) | Display name, username with six availability states, email, password | **Real API**: `GET /users/username-availability`, `POST /auth/register` (pre-v1.2 201 flow). The v1.2 code-entry step (KL-019, PHASE1_1 §1) is **not yet built** |
| `/auth/forgot-password` | `ForgotPasswordScreen` (`…/forgot_password_screen.dart`) | Email field, then a neutral confirmation | **Real API**: `POST /auth/password/forgot` |
| `/auth/verify-email-notice` | `VerifyEmailNoticeScreen` (`…/verify_email_notice_screen.dart`) | Verify notice with resend and continue | **Real API**: `POST /auth/email/resend`. **Retired by v1.2** (PHASE1_1 §0) |
| (shell) | `AppShell` and `KBottomNav` (`app/shell/app_shell.dart`) | 5 tabs: Home, Discover, Create (prominent), Live, Profile. The Row layout mirrors in RTL | Local |
| `/home` | `HomeScreen` (`features/home/home_screen.dart`) uses `ComingSoonTab` (`app/shell/coming_soon_tab.dart`) | AppBar with the `KLogo` wordmark and a `KEmptyState` "coming in Phase 2/3" | **Empty state**, static l10n |
| `/discover` | `DiscoverScreen` (`features/discover/discover_screen.dart`) | `ComingSoonTab` | **Empty state** |
| `/create` | `CreateScreen` (`features/create/create_screen.dart`) | `ComingSoonTab` | **Empty state** |
| `/live` | `LiveScreen` (`features/live/live_screen.dart`) | `ComingSoonTab` saying "Live rooms are coming" (Phase 6/7) | **Empty state** |
| `/profile` | `ProfileScreen` (`features/profile/profile_screen.dart`) | `KAvatar` (initials or image, **no ring**), display name, @username, bio, email-verification tile, "your posts will live here" card, skeleton, error state, pull-to-refresh | **Real API**: `GET /me`, `POST /auth/email/resend` |
| `/settings` | `SettingsScreen` (`features/settings/settings_screen.dart`) | Appearance (theme), language, active sessions with revoke, logout | **Local prefs** (`core/preferences/app_preferences.dart`). **Real API**: `GET /auth/sessions`, `DELETE /auth/sessions/{id}`, `POST /auth/logout` |

### 1.2 Design system as built

| Item | File | Notes relevant to live UI |
| ---- | ---- | ------------------------- |
| Tokens | `design_system/tokens/tokens.dart` | `KBrandColors` (reds, `gradientLive`, gold), `KLiveColors` (badge, pkLeft, pkRight), `KPalette` (dark/light), spacing, radius, typography, motion, sizes. **`KLiveColors` and `gold` are not used by any widget yet** |
| Theme | `design_system/theme/app_theme.dart` | Material theme built from the tokens; `secondary` is gold |
| `KButton` | `components/k_button.dart` | Variants: primary, secondary, ghost, destructive. No `live` variant |
| `KAvatar` | `components/k_avatar.dart` | Image or initials. **No live ring, story ring or badge slot** |
| `KLogo` | `components/k_logo.dart` | Two-part text wordmark (B8 placeholder) |
| `KSkeleton` | `components/k_skeleton.dart` | Shimmer that honours reduce-motion |
| `KSnack` | `components/k_snack.dart` | Success, error and info snackbars |
| `KEmptyState`, `KErrorState`, `KInlineMessage` | `components/k_states.dart` | Used by every placeholder tab |
| `KTextField` | `components/k_text_field.dart` | Form fields |
| `FailureBanner`, `FailureErrorState`, `RetryCountdown` | `core/error/failure_widgets.dart` | Error presentation (PHASE1 §10) |
| Fonts | `assets/fonts/` | Inter at 400/600/700 and Readex Pro (Arabic, D47) at 400/500/600/700, bundled (usable in goldens) |

**Not built:**
- design-system components: Badge, Chip, Tabs, Card or tile, BottomSheet, Dialog wrapper, Counter, Toggle wrapper, ProgressBar (story or PK);
- live-specific components of any kind;
- golden tests (no `matchesGoldenFile` in `test/`).

**Deviation found:** the Create nav button uses `KBrandColors.gradientLive`. DESIGN_SYSTEM §2.3
and §9.6 reserve the live gradient for "live right now" and give Create a solid `primary` pill.
Logged as gap G-21.

**Backend today** (`apps/api/src/modules`): `auth`, `users`, `mail`, `health`. There are no
`live`, `gifts`, `wallet`, `feed`, `posts`, `messaging` or `notifications` modules.

---

## 2. Target screen inventory

Columns:
- **Ph**: phase from IMPLEMENTATION_PLAN.
- **Backend**:
  - *exists*: the needed API is in the contract and implemented.
  - *missing*: no contract or module yet.
  - *blocked Bn*: depends on a KNOWN_LIMITATIONS blocker.
- **Reference needed**: the exact screen and state to capture (see §5 for the brief).
- **Status**: *none*, *placeholder* (honest empty state), *partial* or *done*.

**Viewport standard** (one standard for references and goldens):

| | Primary | Secondary (Android check) |
| - | ------- | ------------------------- |
| References | iPhone at 393 × 852 pt @3x, i.e. 1179 × 2556 px | Android at 1080 × 2400 px |
| Goldens | 393 × 852 logical @ DPR 3.0 | 360 × 800 @ DPR 3.0 (1080 × 2400 px) |

If the reference app is captured on one platform only, use the primary. Never mix device sizes
within one screen's state set.

**Information-architecture decision needed (`D-KL021-IA`).** In the genre, the first tab is
usually a **live-discovery hub**. SCREEN_INVENTORY currently makes Home a following feed and
Live a separate tab.

**Recommendation:**
- **Home** becomes the live-discovery hub, with category tabs, a featured carousel and a live
  grid.
- The posts/following feed becomes one of Home's top tabs.
- The **Live** tab becomes "Go live / my live" or is folded into Create.
- The 5-tab count and the centred Create stay.

This needs owner and CTO sign-off before P0 composition work. Components (§7) are unaffected.

### 2.1 Home / live discovery

| Element | Ph | Backend | Reference needed | Status |
| ------- | -- | ------- | ---------------- | ------ |
| Top nav: wordmark, search entry, notifications or ranking entry | 6 (search 9) | missing (`live` list API); search missing | Home, default tab, top of list, signed in | placeholder (wordmark only) |
| Category tabs (e.g. Popular / Nearby / New / Following / themed) | 6 | missing (category list) | Home, each category tab selected once; tab strip scrolled to end | none |
| Featured / banner cards (carousel) | 6 | missing (featured or promo API) | Home, carousel at item 1 and mid-swipe | none |
| Live grid (2-column cover cards) | 6 | missing, **blocked B1** for real streams | Home, Popular, grid scrolled 0 and about 2 screens; one card in PK; one multi-guest card | none |
| Recommended creators row | 6/9 | missing | Home, creators row visible; follow tapped state | none |
| Empty, loading and error states | 6 | — | Home with no rooms (if observable), loading skeleton, offline | placeholder (Phase 1 empty) |
| Bottom nav (5 items) | 1 | exists (local) | Home with bottom nav visible, each tab selected | partial (built; IA pending) |

### 2.2 Live room (viewer and host)

| Element | Ph | Backend | Reference needed | Status |
| ------- | -- | ------- | ---------------- | ------ |
| Full-screen video, swipe up/down between rooms | 6 | missing, **blocked B1** | Viewer, room open, just joined (first 3 s); mid-swipe to the next room | none |
| Broadcaster header: avatar, name, ID or level, follow | 6 | missing (`live`, follow graph Phase 2) | Viewer, not following host; after tapping follow | none |
| Viewers: avatar stack, count, ranking entry | 6/7 | missing | Viewer, room with more than 1k viewers; audience sheet open | none |
| Chat overlay: bottom-anchored, translucent, system and entry messages | 6 | missing (realtime events not defined) | Viewer, busy chat; chat with a join notice; long message wrapping; Arabic message in an English UI | none |
| Input bar and quick actions: comment, gift, share, more | 6/7 | missing | Viewer, input focused with keyboard; more-sheet open | none |
| Gift effects: banner combo, full-screen animation | 7 | missing, **blocked B5** for paid gifts | Viewer, a small gift combo (×N); a large full-screen gift mid-animation | none |
| Gift panel (sheet): tabs, grid, balance, quantity, send | 7/8 | missing, **blocked B5** | Viewer, gift sheet open, default tab; a gift selected; insufficient balance | none |
| Share, report and moderation (viewer) | 6 | missing | Viewer, share sheet; report sheet; long-press on a chat user | none |
| PK layout: split video, score bar, timer, result | 7 | missing, **blocked B1** | Viewer, PK in progress with about 2 min left, scores close; final 10 s; result shown | none |
| Multi-guest grid and seat requests | 7 | missing, **blocked B1** | Viewer, 4-seat and 9-seat layouts; request-to-join sheet | none |
| Host controls: camera flip, mic, beauty, moderators, end | 6 | missing, **blocked B1** | Host, live with tools open; end-live confirm; end summary | none |
| Go-live setup | 6 | missing, **blocked B1** | Host pre-live with cover, title and category | none |
| Live ended (viewer) | 6 | missing | Viewer when the host ends | none |

### 2.3 Other areas

| Area / screen | Ph | Backend | Reference needed | Status |
| ------------- | -- | ------- | ---------------- | ------ |
| Creator profile (other user): header, stats, live ring when live, follow/message, tabs, grid | 2/3/5 | missing (profiles Phase 2) | Other profile while offline; same profile while live | none (own profile **partial**) |
| Own profile | 1/2 | exists (`GET /me`); edit missing | Own profile, top | partial |
| Login and registration | 1 / 1.1 | exists; v1.2 verify endpoints specified (KL-019) | Login; register; code entry if the reference app has one | partial (built; v1.2 code entry pending) |
| Search | 2 (users) / 9 | missing | Search empty; typing; results with tabs | placeholder |
| Inbox / DMs | 9 | missing | Inbox list; conversation; message requests | none |
| Notifications | 9 | missing, **blocked B4** for push | Activity list with mixed types | none |
| Wallet / coin store / gift history | 8 | missing, **blocked B5** | Wallet home; top-up packages; transactions | none |
| Short-video feed (vertical) | 5 | missing (media, transcoding) | Feed item playing; comments sheet | none |
| Posts, stories, highlights | 3/4 | missing | Post detail; story viewer mid-progress; highlights row | none |
| Settings | 1 | exists (sessions) | Settings root; privacy page | partial |

---

## 3. Pattern analysis (genre knowledge; maps to Kabso tokens and components)

These are the common patterns of the live-streaming genre, described generically and mapped to
Kabso. **Existing** means it is in code today. **Spec** means it is specified in DESIGN_SYSTEM
but not built. **New** means it needs a spec and a build.

| # | Screen | Pattern (generic) | Kabso mapping | State |
| - | ------ | ----------------- | ------------- | ----- |
| 1 | Home | Two-column grid of portrait cover cards with a gradient scrim at the bottom carrying host name and title | `KLiveCoverCard` per DESIGN_SYSTEM §9.10 "Live room tile" (3:4, radius `sm`, gap `sm`, scrim gradient) | Spec → build |
| 2 | Home | Viewer-count chip in a card corner (eye or person glyph and compact number) | `KViewerCountChip` (`scrim` pill, `KNumberFormat.compact`, tabular figures); badge `liveWithViewers` §9.5 | Spec → build |
| 3 | Home | LIVE marker on cards and avatars | `KBadge.live` (`color.live.badge`, "LIVE"/"مباشر") | Spec → build |
| 4 | Home | PK or multi-guest marker on a card | `KBadge.pk`; new `KBadge.multiGuest` (seats glyph) | Spec / New |
| 5 | Home | Scrollable category tabs under the top bar | `KTabs` `scrollable` §9.8 | Spec → build |
| 6 | Home | Featured carousel with page dots | New `KFeaturedCarousel` (radius `lg`, 16:7, dots follow reading direction, reduce-motion means no auto-advance) | New |
| 7 | Home | Horizontal row of recommended creators with live rings | `KAvatar` + **live ring** (§9.4) + Follow `KButton` small | Spec → build (ring) |
| 8 | Live room | Edge-to-edge video; overlays live in safe zones (top header, side actions, bottom chat and input) | New `KLiveRoomScaffold` (layout only: slots for video, header, chat, actions, gift layer, PK) | New |
| 9 | Live room | Host pill at top-start: avatar, name, small follow button, on a translucent capsule | New `KHostPill` (`scrim` capsule, `KAvatar` sm, `bodyStrong`, Follow `primary` small) | New |
| 10 | Live room | Viewer avatar stack and count at top-end, plus close | New `KViewerStack` (3 overlapping `avatarSm`, then `KViewerCountChip`) + `KIconButton` filled close | New |
| 11 | Live room | Bottom-anchored translucent chat. Newest at the bottom, older lines fade toward the top, no bubbles or light bubbles; system and entry lines styled differently | New `KChatOverlay` + `KChatLine` (text on a 60 % black pill (`chatScrim`), username in `primaryText`/`gold` by role, fade mask at top, max height about 35 % of the screen, auto-scroll paused when the user scrolls up) | New |
| 12 | Live room | Bottom action bar: comment field pill, then icon actions (gift emphasised) | New `KRoomActionBar` (`KIconButton` filled; gift uses `gold` icon) | New |
| 13 | Live room | Gift combo banner sliding in from the start side: sender, gift, ×N counter that bumps | New `KGiftComboBanner` (§7.3 budget: max 3 stacked, counter roll `durationFast`) | New |
| 14 | Live room | Full-screen gift animation layer above the video | New `KGiftEffectLayer` (`RepaintBoundary`, queue, reduce-motion means banner only) | New (asset pipeline later) |
| 15 | Live room | Gift panel bottom sheet: category tabs, 4-column grid, balance and top-up, quantity, send | `KBottomSheet` gift variant §9.11 → `KGiftPanel` shell | Spec → build (shell) |
| 16 | Live room | PK split screen: two videos, a horizontal score bar whose fill ratio shows the lead, a countdown timer, a result overlay | New `KPkBar` (`pkLeft` start / `pkRight` end, mirrors in RTL, scores ≥ 20/700, timer tabular), `KPkTimer`, `KPkResult` | Spec (§6.2 rule) → build |
| 17 | Live room | Room swipe (vertical) to the next live | `PageView` vertical in `KLiveRoomScaffold`; no gift animation during a drag | New |
| 18 | Live room | Multi-guest seat grid with speaking indicators | New `KSeatGrid` (2×2, 3×3; speaking means a pulsing `success` ring, static when reduce-motion is on) | New |
| 19 | Live room | Join or level-entry announcement line | `KChatLine.system` variant | New |
| 20 | Live room | Ranking or top-gifter entry (crowns or medals for top 3) | Rank chip using `gold`; **Kabso-original rank glyphs** | New |
| 21 | Profile | Avatar with live ring and a "Live" tap target into the room | `KAvatar` ring `live` + `KBadge.live` | Spec → build |
| 22 | All | Compact counts (1.2K) with locale suffix | `KFormat` (exists, `useNativeDigits=false`) + DESIGN_SYSTEM §3.3 compact rules | Partial (verify compact form) |

---

## 4. Gap analysis

Priority:
- **P0**: home discovery and live-room presentation components (no backend).
- **P1**: needed when the Phase 6/7 APIs land.
- **P2**: later phases.

| ID | Target element | Current state | Gap | Pri | Needs backend | Risk notes |
| -- | -------------- | ------------- | --- | --- | ------------- | ---------- |
| G-01 | Live cover card (2-col grid) | none | Component, tokens (aspect 3:4, scrim gradient), goldens | P0 | No (component); Yes (data, Ph 6, B1) | TD if the reference's exact card proportions, corner radii, badge placement **and** colour scheme are combined; keep Kabso radii, colours and type |
| G-02 | LIVE badge | none | `KBadge.live` | P0 | No | — (generic). Do not copy the reference's badge shape or animated glyph (CR) |
| G-03 | Viewer-count chip | none | `KViewerCountChip` + compact format | P0 | No | — |
| G-04 | Live avatar ring | `KAvatar` without rings | Ring variants (live, story seen/unseen) | P0 | No | — |
| G-05 | Category tabs | none | `KTabs` scrollable | P0 | No (component); Yes (categories) | TM: don't reuse the reference's category names if they are branded |
| G-06 | Home composition (top nav, carousel, grid, creators row) | placeholder | Screen layout spec after IA decision; goldens with fixtures | P0 (spec + golden only) | Yes for real data | **TD hotspot**: whole-screen composition in close reproduction. Keep the order of blocks (pattern) but use Kabso spacing, typography, iconography and colour |
| G-07 | Live room scaffold (overlay safe zones) | none | `KLiveRoomScaffold` with slots | P0 | No (layout); Yes (video B1) | TD if exact overlay positions and sizes are matched pixel for pixel; follow zones, not coordinates |
| G-08 | Host pill + follow | none | `KHostPill` | P0 | No | — |
| G-09 | Chat overlay | none | `KChatOverlay`, `KChatLine` (user, system, gift variants), RTL alignment, fade mask | P0 | No (component); Yes (realtime events) | CR: do not reuse the reference's level badges, VIP frames or name colours as artwork |
| G-10 | Gift panel shell | none | `KGiftPanel` (tabs, grid, balance, quantity, send, states) | P0 | No (shell); **B5** for purchase | **CR**: gift artwork and animations must be Kabso-original or licensed. TM: currency names must be Kabso's own (revisit SCREEN_INVENTORY "Diamonds" wording if it matches the reference) |
| G-11 | Gift combo banner | none | `KGiftComboBanner` with the motion budget | P0 | No | CR on sounds and animation timing signatures |
| G-12 | PK bar, timer, result | none | `KPkBar`, `KPkTimer`, `KPkResult`; P13 tokens for text on fills | P0 | No (component); B1 + realtime (Ph 7) | TD if the reference's specific VS emblem, colours and bar styling are copied; Kabso uses `pkLeft`/`pkRight` and its own emblem |
| G-13 | Room action bar | none | `KRoomActionBar` | P0 | No | — |
| G-14 | Viewer stack and audience sheet | none | `KViewerStack`; sheet in Ph 6 | P1 | Yes | — |
| G-15 | Full-screen gift effect layer | none | Queue and render layer; asset pipeline | P1 | Yes (+B5) | **CR** (assets) |
| G-16 | Vertical room swipe | none | Pager + preload policy | P1 | Yes (B1) | — |
| G-17 | Multi-guest seat grid | none | `KSeatGrid` | P1 | Yes (B1, Ph 7) | — |
| G-18 | Host controls and go-live | placeholder | Screens in Ph 6 | P1 | Yes (B1) | — |
| G-19 | Creator profile with live ring | own profile partial | Other-profile screen (Ph 2) + ring | P1 | Yes (Ph 2) | — |
| G-20 | Featured carousel | none | `KFeaturedCarousel` | P1 | Yes (featured API) | CR: promo banner artwork is Kabso's own |
| G-21 | Create nav button uses the live gradient | built | Switch to `primary` per DESIGN_SYSTEM §9.6, or record a decision to keep it | P0 (small) | No | — |
| G-22 | Ranking / top gifter UI | none | Rank chip and sheet | P2 | Yes (Ph 7) | **TD/CR**: crown, medal and level designs must be original |
| G-23 | Wallet / top-up | none | Ph 8 screens | P2 | **B5** | TM: currency names |
| G-24 | Search, inbox, notifications | placeholder | Ph 2/9 | P2 | Yes (B4 for push) | — |
| G-25 | Short-video feed, posts, stories | none | Ph 3–5 | P2 | Yes | — |
| G-26 | Golden test infrastructure | none | Font loading, viewport helper, fixtures dir, CI job, diff tool | P0 | No | — |

---

## 5. Reference capture brief (for the owner)

### 5.1 Authorization

Supply only screenshots you are entitled to use for internal design reference. Examples: your own
captures of the publicly available app, for internal comparison, with legal review where needed.

They are used **only**:
- to compare patterns and hierarchy;
- as internal design notes.

They are **never**:
- shipped in the app;
- used as test goldens or as test fixtures inside `apps/`;
- published;
- used as a source for traced artwork.

Record in `design/references/README.md`:
- who captured each set;
- when, on which device, and with which app version;
- the authorization basis.

Remove anything containing other users' personal data (faces, names, messages) or blur it before
committing. Prefer the capturer's own test accounts and rooms they host themselves.

### 5.2 Format

| Item | Spec |
| ---- | ---- |
| Device | iPhone with a 393 × 852 pt screen (1179 × 2556 px PNG). Android alternative: 1080 × 2400 px. One device per screen set |
| Format | PNG, full screen including the status bar (it is masked during comparison). No crops, no annotations (annotate in a separate `_notes.md`) |
| Locale | Each state in **Arabic (RTL)** and **English** where the reference app supports both; otherwise note "en only" |
| Theme | The reference app's default theme; note if a dark/light switch exists |
| Location | **Not in this repository while it is public (D40).** The owner shares references privately (outside Git); agents keep them only in local scratch space, and `design/references/` is git-ignored as a guard. Only text notes with no images or measurements copied from them are committed. Once the repo is private, the previous plan (`design/references/<screen>/<state>_<locale>.png`, Git LFS or a private bucket) can be reconsidered |
| Naming | lowercase kebab-case. `<screen>` from the list below; `<state>` describes the state; `<locale>` is `ar` or `en`. Example: `design/references/live-room/pk-in-progress-2min_ar.png` |
| Video (optional) | Short screen recordings (`.mp4`, ≤ 15 s) for motion (gift combo, PK countdown, room swipe), stored as `<state>_<locale>.mp4` |

### 5.3 Checklist

| # | `<screen>` | `<state>` files to supply (each `_ar` and `_en`) |
| - | ---------- | ------------------------------------------------ |
| 1 | `home` | `default-top`, `scrolled-2-screens`, `category-<n>-selected` (each category once), `tabs-scrolled-end`, `carousel-item1`, `creators-row`, `loading`, `offline` (if observable), `empty` (if observable) |
| 2 | `live-card` | `single`, `pk`, `multi-guest`, `long-title`, `high-viewers` (≥ 100k) |
| 3 | `live-room` | `viewer-joined`, `viewer-following`, `chat-busy`, `chat-join-notice`, `chat-long-message`, `chat-mixed-script`, `input-focused-keyboard`, `more-sheet`, `share-sheet`, `report-sheet`, `user-card-longpress`, `swipe-mid`, `ended` |
| 4 | `gift` | `panel-default`, `panel-selected`, `panel-quantity`, `panel-insufficient`, `combo-banner`, `fullscreen-mid` |
| 5 | `pk` | `invite`, `in-progress-2min`, `final-10s`, `result-win`, `result-lose`, `rtl-scores` (Arabic) |
| 6 | `multi-guest` | `4-seats`, `9-seats`, `request-sheet` |
| 7 | `host` | `pre-live-setup`, `live-tools-open`, `end-confirm`, `end-summary` |
| 8 | `profile` | `other-offline`, `other-live`, `own` |
| 9 | `auth` | `login`, `register`, `code-entry` (if present), `language-switch` |
| 10 | `search` | `empty`, `typing`, `results` |
| 11 | `inbox` | `list`, `conversation`, `notifications` |
| 12 | `wallet` | `home`, `top-up`, `transactions` |
| 13 | `short-video` | `playing`, `comments` |
| 14 | `posts-stories` | `post-detail`, `story-viewer-mid`, `highlights-row` |
| 15 | `settings` | `root`, `privacy` |

Priority for the first batch is rows 1–5 (P0 home and live room).

---

## 6. Visual-regression plan

**Environment constraint.** Real device and emulator screenshots aren't possible in this cloud
environment (B6: no Android SDK or Xcode). Flutter golden tests are the substitute. Device
capture (integration-test screenshots on emulators and simulators) happens later in CI.

### 6.1 Golden tests (Flutter)

| Aspect | Spec |
| ------ | ---- |
| Location | `apps/mobile/test/golden/**`, goldens in `test/golden/goldens/` (owned by A2) |
| Viewport | `tester.view.physicalSize = Size(1179, 2556)` with `devicePixelRatio = 3.0` (393×852), plus `Size(1080, 2400)` @ 3.0 (360×800); reset in `addTearDown` |
| Fonts | Load the bundled Inter and Readex Pro via `FontLoader` in a shared `loadAppFonts()` helper (flutter_test defaults to Ahem, which hides Arabic shaping issues) |
| Determinism | Fixed clock, `MediaQuery.disableAnimations` where frames would vary (otherwise pump to settle), no network images (in-memory test image provider), seeded data |
| Fixtures | Plain Dart fixtures under `test/fixtures/**` **only**, never imported by `lib/`. Add a test that fails if `lib/` imports `test/` or fixture names. Production screens keep honest empty states |
| Matrix | Each component and composed screen in `ar` and `en`. Dark only for live surfaces (always dark); both themes for others. Text scale 1.0 and 1.3 for overlay surfaces (clamped), and 2.0 for standard screens |
| Platform | Generate and compare goldens on one pinned CI image (Linux, pinned Flutter). Locally on other OSes, goldens are informational (font rasterization differs). Tag `golden` |
| Update | `--update-goldens` only in a dedicated commit with reviewer sign-off (A5 checks the diff images) |

### 6.2 Reference comparison (design QA, not CI-gating)

Proposed tool: `tools/visual-diff/`, owned by A8 or A6 and not created by this doc. It is a
small Python CLI (Pillow and scikit-image) that takes a reference PNG and a golden PNG and
produces:

1. **Overlay** (50 % blend) and **side-by-side** images for human review. This is the primary
   method, used for pattern and hierarchy review.
2. **Region checks** from a per-screen YAML of named regions (header, grid card 1, chat zone, PK
   bar). Positions and sizes are measured from the golden layout dump, not by matching the
   reference's pixels.
3. **Diff heatmap** and **SSIM** per region, normalized to 393 dp width.

| Element class | Tolerance | Compared against |
| ------------- | --------- | ---------------- |
| Layout (block order, zone placement) | Same order and zone; positions ±2 dp; sizes ±2 dp | Reference (pattern fidelity) |
| Typography | Size ±1 sp; weight one step; line count equal | Kabso type scale (not the reference font) |
| Colour | ΔE2000 ≤ 3 | **Kabso tokens**, because the identity intentionally differs from the reference |
| Icons | Presence, position and size ±2 dp; glyph shape not compared | Reference position, Kabso glyph |
| Golden regression (CI) | Pixel diff ≤ 0.1 % per image and SSIM ≥ 0.99 per region | Previous approved golden |
| Reference similarity (design QA) | Report only; no pass/fail threshold on SSIM against the reference (high SSIM against a third-party app is not a goal) | — |

**Excluded or masked regions:** live video, avatars and images, usernames and display names,
counts, timers, chat text content, the status bar, the system navigation bar and the keyboard.

---

## 7. Proposed P0 implementation increments (no backend)

Rules for every increment:
- It is built in `lib/design_system/components/live/` (A2).
- It uses only design-system view-model classes (plain Dart, no API DTOs).
- Each ships with **widget tests** (semantics, RTL mirroring, states, reduce-motion, ≥ 48 dp
  targets) and **goldens** from §6.1, all driven by `test/fixtures`.
- **None is wired into production screens** until its API exists (Phase 6/7). Home and Live
  keep their honest empty states.
- Order follows dependency.

| # | Increment | Contents | Tokens used / proposed | Tests |
| - | --------- | -------- | ---------------------- | ----- |
| 1 | Golden infrastructure (G-26) | `loadAppFonts()`, viewport helper, `test/fixtures/live/` (fake rooms, chat lines, gifts, PK scores), lib-must-not-import-fixtures test, CI tag | — | Smoke golden of an existing screen (Login ar/en) |
| 2 | `KBadge` (live, pk, multiGuest, count, dot) + `KViewerCountChip` (G-02, G-03) | §9.5; compact numbers via `KFormat` | `live.badge`, `scrim`, `onStatus` (P14) | ar/en, 0, 999, 12.3K, 1.2M; semantics full number |
| 3 | `KAvatar` rings (G-04) | `ring: none / storyUnseen / storySeen / live` and a bottom badge slot | `gradientLive`, `primary`, `border` | All sizes × rings; reduce-motion static ring |
| 4 | `KTabs` scrollable (G-05) | §9.8 | `primary`, `textSecondary` | RTL order, indicator, focus |
| 5 | `KLiveCoverCard` (G-01) | Cover, scrim, badges, host and title, PK/multi-guest variants, skeleton, error image | radius `sm`; proposed `size.liveCardAspect = 0.75` | Long Arabic title, missing cover, PK variant, 2-col grid golden at both viewports |
| 6 | `KHostPill` + `KRoomActionBar` (G-08, G-13) | Follow states (follow, following, loading), action icons (gift `gold`) | `scrim`, `primary`, `gold` | RTL placement, 48 dp targets |
| 7 | `KChatOverlay` / `KChatLine` (G-09) | user, system and gift variants; fade mask; max height; pause-on-scroll; mixed script | proposed `color.live.chatScrim` (black 60 %) | ar line in an en UI and the reverse; 50 lines; text scale clamp 1.3 |
| 8 | `KGiftPanel` shell (G-10) | Tabs, 4-col grid, selection, quantity chips, balance and top-up, send; states: loading, empty, insufficient, sending, error, offline | `gold`, `goldOnLight` (P10, n/a: dark), `onStatus` | Each state golden; send disabled offline |
| 9 | `KGiftComboBanner` (G-11) | Stacking (max 3), ×N bump, queue rules from §7.3 | motion tokens | Reduce-motion, stacking order RTL |
| 10 | `KPkBar` + `KPkTimer` + `KPkResult` (G-12) | Ratio fill, scores ≥ 20/700, mirrored sides, final-10 s emphasis, result overlay | `pkLeft`/`pkRight`, P13 `pkLeftStrong`/`pkRightStrong` | 50/50, 90/10, 0/0, RTL mirror, timer 2:00 and 0:09 |
| 11 | `KLiveRoomScaffold` (G-07) | Slot layout (video placeholder, header, viewers, chat, actions, gift layer, PK) composed only in tests | — | Composed goldens: viewer default, PK in progress, gift panel open (ar/en) |
| 12 | Create button token fix (G-21) | Use `primary` per §9.6 (or record a decision) | `primary` | Existing shell tests + golden |

Increments 2–4 are independent of the IA decision. Increments 5–11 are presentation-only and
safe to build before `D-KL021-IA`. Composing the real Home screen waits for that decision and for
the Phase 6 API.

**Token proposals added by this doc** (for the CTO, not applied):
- `size.liveCardAspect` = 0.75;
- `color.live.chatScrim` = `#99000000` (60 % black). White chat text on it stays at 5.74:1 even
  over a pure-white video frame (computed; 45 % would fall to about 3.4:1);
- `size.giftGridColumns` = 4;
- `motion.giftComboBumpMs` = 120.

These are in addition to DESIGN_SYSTEM §12 P1–P19.

## Owner-supplied references (log; images are NOT in this repository, D40/D44)

| ID | Date | What | Use |
| -- | ---- | ---- | --- |
| OREF-01 | 2026-10-16 | A store marketing composite of 4 panels (Explore with Countries & Regions, live stream, multi-guest chat, live room with chat and PiP) | Patterns only: discovery by country, full-bleed media, host pill and follow, viewer avatars, chat bubbles, multi-guest seats, coin counter. It is marketing art, not screen captures, so no dimensions, colours or assets are taken from it |
| OREF-02..06 | 2026-10-16 | Five real screenshots of the reference app (Discover grid, Hot list, Go-live setup, Messages, Me) | Patterns written up in `REFERENCE_PATTERNS_OREF_02_06.md`. The images show third-party users and are kept out of the repo and the artifacts |
