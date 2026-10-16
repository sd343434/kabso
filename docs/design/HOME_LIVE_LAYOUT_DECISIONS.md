# Kabso Live — Home & Live Room Layout Decisions (KL-032)

Status: **Owner-reviewed 2026-10-16 (D36) — see "Owner decisions" first; design correction sprint, D34/D35.** Documentation only;
nothing here is implemented. It pairs with the gap table in
[`BIGO_INSPIRED_GAP_ANALYSIS.md`](BIGO_INSPIRED_GAP_ANALYSIS.md) (VG-xx).

## Owner decisions (2026-10-16, D36) — these override the recommendations below

| ID | Owner answer | Effect on this spec |
| -- | ------------ | ------------------- |
| HL-N1 | **Home · Discover · Create · Live · Profile, Home = feed** (recommendation *not* taken) | No route change. The **Live tab stays** and becomes the live-discovery hub: §1 HL-H3–HL-H6 (category chips, 2-column 3:4 grid, refresh/paging, states) apply to `/live`, not `/home`. **Home is redesigned as a social feed** (posts / short video). No `/inbox`; Create stays a tab page (the Create-sheet change was part of the rejected option). §2 bottom-nav *styling* (active dot, `textPrimary` labels, calmer chrome) still applies |
| HL-H1/H2 | **Following · Popular · New, default Popular**; no wordmark on Home (stays on Splash/Login); Nearby deferred | Applies to the Home feed header. *Working assumption (to confirm at the before/after review, KL-035):* the Live hub uses the same three tabs over live rooms |
| HL-L8 | **Split screen** PK | As specified in §3 HL-L8 |
| HL-L6 | **Non-dimming** gift sheet | As specified in §3 HL-L6 |
| Q7 categories | Not answered | Production shows only the **All / الكل** chip (no invented categories) |
| Q8 references | Not answered | Sprint proceeds as a **documented reference-free approximation** (owner directive allows this); gap analysis §11 items stay unverified |
| §5 tokens T-1–T-5 | Not a contract change in this sprint | Values live in `KMetrics` / component styles derived from existing tokens; T-1–T-5 return as a token contract proposal after owner approval of the redesign |

Home feed (new, replaces §1 for `/home`): header = the three text tabs (HL-H2 style) + search
icon → `/discover`. Body = full-width feed items. **No feed API exists** (posts / short video are
later phases), so production renders the header and an honest compact unavailable state per tab;
populated feed layouts are fixture-only (D35).

**Ground rules**

- **Source of the patterns:** layouts follow **common live-streaming patterns** (the genre the
  owner points to), expressed in Kabso's own identity.
- **No measurements from the reference app:**
  - There are no reference screenshots.
  - No dimension below comes from the reference app. All are Kabso values, from tokens,
    `KMetrics` or new proposals marked as such.
- **No fake data in production (D35):** production Home and Live render the new structure with
  honest states. Populated wireframes are **fixture-only** (goldens and the debug gallery).
- **No contract changes in this sprint:** token changes are *proposals* to the CTO (§5).

**Wireframe conventions**

- **Viewport:** 393 × 852 dp. The iPhone-class safe areas are shown as `inset-top` (59) and
  `inset-bottom` (34); headless goldens use 0.
- **Scale:** one character is about 9.6 dp horizontally. Y values (dp from the top of the
  screen, with insets) are given at the right.
- **Locale:** wireframes are drawn LTR (en). An **ar** note under each one states what mirrors.
  Key screens also get an ar wireframe.

---

## 0. Decisions needing owner sign-off

| ID | Decision | Recommendation | Alternatives | Route change? |
| -- | -------- | -------------- | ------------ | ------------- |
| HL-N1 | Bottom-nav destinations | **Home (live) · Discover · Create · Inbox · Profile**; Live tab removed (Home is the live hub) | A: keep the current 5 (Live duplicates Home). C: Home · Discover · Create · Live(go-live/mine) · Profile | **Yes**: `/live` is removed or redirected to `/home`; `/inbox` is new (a Phase 9 placeholder with honest state) |
| HL-H1 | Home header content | Primary tabs + search; **no wordmark on Home** | Wordmark row above the tabs (costs 48 dp, about 0.2 card rows) | No |
| HL-H2 | Home primary tabs | **Following · Popular · New**, default Popular | Add **Nearby** (needs location permission, privacy review and backend geo); category-only tabs | No (in-tab) |
| HL-H4 | Featured strip | Slot exists but renders **only** with featured API data; no placeholder banner | An always-on promo carousel (rejected: no data, and decorative) | No |
| HL-L8 | PK layout | **Split screen** (2 panes in the upper half) | Keep a single video with an overlay bar (current) | No |
| HL-L6 | Gift sheet over the stream | **Non-dimming** sheet (video stays visible) | Dimmed scrim (current) | No |

---

## 1. Home: live-discovery hub

### HL-H1 Top bar

| Slot | Content | Why |
| ---- | ------- | --- |
| start | Primary tabs (HL-H2), as text tabs | In the genre the tabs *are* the header; it saves vertical space for cards |
| end | Search icon button (24 dp icon, 48 dp target) → `/discover` | Real, existing route (search lands in Phase 2/9 with honest state there) |
| — | No wordmark, no notification bell (Phase 9 API), no ranking or trophy icon (no API) | No dead or decorative controls |

Height 48 dp, background `background` (no surface change and no divider). On scroll the tabs
stay pinned. The chip row (HL-H3) scrolls away and reappears on a reverse scroll.

### HL-H2 Primary tabs

| Tab | en / ar | Content | Data (populated state) | Production state today |
| --- | ------- | ------- | ---------------------- | ---------------------- |
| Following | Following / متابَعون | Live rooms of people you follow | follow graph (Phase 2) + live list (Phase 6) | Unavailable state |
| Popular (default) | Popular / رائج | Ranked live rooms, with category chips | live list + categories (Phase 6) | Unavailable state |
| New | New / جديد | Recently started rooms; gives new hosts visibility | live list sorted by start (Phase 6) | Unavailable state |

**Style:**
- Selected tab: `title` 18/600 `textPrimary` with a 16 × 3 dp `primary` indicator under the
  label (fades per D33).
- Unselected: `bodyStrong` 15 `textSecondary`.
- Tab gap `lg`.
- Swiping between tab pages follows the reading direction (VG-42, P1).

**Why not Nearby now:** it needs a location permission flow, a privacy decision and backend
geo-indexing; none exist. Proposed for Phase 9 (owner question Q3).

### HL-H3 Category chip row (Popular only)

- **Layout:** a 48 dp row (32 dp chips, `pill` radius), padded `sm` at the start and end, with
  an `sm` gap. It scrolls horizontally from start.
- **Selected chip:** `primary` fill with `onPrimary` text.
- **Unselected chip:** `surfaceRaised` with `textPrimary`.
- **Production today:** a single selected **All / الكل** chip. Categories are server-defined,
  so none are invented.

### HL-H4 Featured strip vs grid

- **Grid (always):** 2 columns, card aspect `size.liveCardAspect` 0.75, side padding `sm`,
  column and row gap `xs`.
  - At 393 dp a card is 186.5 × 248.7 dp; at 360 dp it is 170 × 226.7 dp.
- **Card overlays** (`KLiveCoverCard`, refactored per §6):

  | Position | Content |
  | -------- | ------- |
  | top-start | Viewer chip (eye + compact count). Below 1 viewer it shows a "New / جديد" chip (VG-11) |
  | top-end | Mode tag only when true: `PK` (solid) or multi-guest (seats glyph + count) |
  | bottom | 50 % scrim, then host name (`bodyStrong`, 1 line) and title (`caption`, 1 line) |
  | removed in grids | LIVE badge and the top accent line (VG-10) |

- **Featured strip (optional slot):** a single horizontally paged row, 16:7, radius `md`, above
  the grid. It is rendered **only when the featured API returns items**.
- **Following-live rail (optional slot, Popular tab):** a row of avatars (`avatarMd`) with
  `live` rings and names, labelled "Live now from people you follow". It renders only when
  there are such rooms (Phase 2 + 6).

### HL-H5 Pull-to-refresh and infinite scroll

| Behaviour | Spec |
| --------- | ---- |
| Pull-to-refresh | Standard refresh indicator in `primaryText`. It reloads the current tab and chip from the first cursor and keeps the scroll position at the top |
| Pagination | Cursor-based (CONVENTIONS §5). Prefetch when ≤ 2 viewport heights remain. The footer shows 2 skeleton cards while loading |
| Footer error | Inline "Couldn't load more · Retry / تعذّر تحميل المزيد · إعادة المحاولة" row; the list stays usable |
| End of list | Caption "Pull down for new live rooms / اسحب للأسفل لعرض بثوث جديدة". Live lists are short-lived, so there is no "all caught up" |
| Freshness | Re-fetch on tab re-select and on app resume after more than 60 s. Ended rooms disappear on refresh; tapping a stale card opens the room's "Live ended" state (HL-L10) |
| Dedup | By room id across pages |

### HL-H6 States

| State | Where it renders | Spec |
| ----- | ---------------- | ---- |
| **Unavailable** (production today: no API) | Grid region, below the tabs and chips | Compact `KEmptyState` (48 dp icon, VG-03) at the top third. Pull-to-refresh is disabled. Tabs stay tappable (each shows its own unavailable copy) |
| Loading | Grid region | 6 `KLiveCoverCardSkeleton` (3 rows); shown after 300 ms |
| Empty: Popular / New | Grid region | "No one is live right now" + "Pull down to refresh" |
| Empty: Following | Grid region | "No one you follow is live" + secondary button "See popular" (switches tab) |
| Error | Grid region | `KErrorState` from the error copy (PHASE1 §10, PHASE1_1 §5) + Try again; tabs stay usable |
| Offline | Grid region + offline banner | `errorNetworkOffline` state; auto-retry on reconnect |
| Populated | Grid | **Fixture-only** until the Phase 6 API (D35) |

New strings:

| Key (suggested) | en | ar |
| --------------- | -- | -- |
| `homeTabFollowing` | Following | متابَعون |
| `homeTabPopular` | Popular | رائج |
| `homeTabNew` | New | جديد |
| `homeChipAll` | All | الكل |
| `homeSearch` (semantics) | Search | بحث |
| `homeUnavailableTitle` | Live rooms arrive in Phase 6 | تصل غرف البث المباشر في المرحلة 6 |
| `homeUnavailableBody` | People who are live right now will appear here. | سيظهر هنا الأشخاص الذين يبثون مباشرة الآن. |
| `homeFollowingUnavailableBody` | Following arrives in Phase 2, and their live rooms in Phase 6. | تتوفر المتابعة في المرحلة 2، وغرف البث الخاصة بمن تتابعهم في المرحلة 6. |
| `homeEmptyTitle` | No one is live right now | لا أحد يبث مباشرة الآن |
| `homeEmptyBody` | Pull down to refresh. | اسحب للأسفل للتحديث. |
| `homeFollowingEmptyTitle` | No one you follow is live | لا أحد ممن تتابعهم يبث الآن |
| `homeSeePopular` | See popular | عرض الرائج |
| `homeLoadMoreFailed` | Couldn't load more | تعذّر تحميل المزيد |
| `homeListEnd` | Pull down for new live rooms | اسحب للأسفل لعرض بثوث جديدة |
| `liveCardNew` | New | جديد |
| `homeFollowingRail` | Live now from people you follow | يبثون الآن ممن تتابعهم |

### Wireframe H-A: Home, populated (fixture-only), en

```
┌─────────────────────────────────────────┐ y
│ status bar                              │ 0-59    inset-top
├─────────────────────────────────────────┤
│ Following  POPULAR  New             (S) │ 59-107  tabs + search (48)
│            ‾‾                           │         16x3 indicator
├─────────────────────────────────────────┤
│ (*All*) (Music) (Chat) (Games) (Talk) > │ 107-155 chip row (32 visual)
├───────────────────┬─┬───────────────────┤ 155     pad sm 8 | gap xs 4
│[eye 12.3K]   [PK] │ │[eye 987]          │
│                   │ │                   │
│       cover       │ │       cover       │         card 186.5 x 248.7
│                   │ │                   │
│░░░░░░░░░░░░░░░░░░░│ │░░░░░░░░░░░░░░░░░░░│         50 % bottom scrim
│Sara               │ │Khalid             │         bodyStrong, 1 line
│Arabic music night │ │PK with fans       │         caption, 1 line
├───────────────────┘ └───────────────────┤ 404
│ ...row 2 (same)                         │ 408-657
│ ...row 3 (partially visible)            │ 661-
├─────────────────────────────────────────┤ 754
│ Home  Discover  [ + ]  Inbox  Profile   │ 754-818 nav 64 (HL-N1)
│ status/home indicator                   │ 818-852 inset-bottom
└─────────────────────────────────────────┘
```

**ar:**
- Tabs run right → left (متابَعون at the right, then رائج, then جديد), and the search icon is at
  the far left.
- Chips scroll from the right.
- The first card sits at the right column.
- The viewer chip is at the card's top-right and the mode tag at its top-left.
- The text is right-aligned.

### Wireframe H-A (ar)

```
┌─────────────────────────────────────────┐
│ (S)             جديد   *رائج*   متابَعون │ tabs (start = right)
├─────────────────────────────────────────┤
│ < (حوار) (ألعاب) (دردشة) (موسيقى) (*الكل*) │ chips scroll from right
├───────────────────┬─┬───────────────────┤
│          [987 eye]│ │[PK]   [12.3 ألف eye]│
│       cover       │ │       cover       │
│░░░░░░░░░░░░░░░░░░░│ │░░░░░░░░░░░░░░░░░░░│
│              خالد │ │              سارة │
│    تحدي مع المتابعين │ │  سهرة موسيقى عربية │
└───────────────────┘ └───────────────────┘
│ حسابي  الرسائل  [ + ]  استكشاف  الرئيسية │ nav mirrors
└─────────────────────────────────────────┘
```

### Wireframe H-B: Home, unavailable (production today)

```
┌─────────────────────────────────────────┐
│ status bar                              │ 0-59
│ Following  POPULAR  New             (S) │ 59-107
│ (*All*)                                 │ 107-155  single chip, no invented categories
├─────────────────────────────────────────┤
│                                         │
│            [48 dp live icon]            │ ~215     top third of grid region
│      Live rooms arrive in Phase 6       │          title (title 18)
│ People who are live right now will      │          body (body 15, secondary)
│ appear here.                            │
│                                         │
│                                         │
│ Home  Discover  [ + ]  Inbox  Profile   │ 754-818
└─────────────────────────────────────────┘
```

On Following, the body is `homeFollowingUnavailableBody` and the chip row is hidden. In ar the
block is centred, so only the text direction changes.

### Wireframe H-C: loading / empty / error (grid region only)

```
LOADING                    EMPTY (Following)              ERROR
┌─────────┐ ┌─────────┐    [48 icon]                      [48 icon, error tint]
│▒▒▒▒     │ │▒▒▒▒     │    No one you follow is live      Something went wrong
│         │ │         │    ( See popular )                Something unexpected happened…
│▒▒▒▒▒▒   │ │▒▒▒▒▒▒   │                                   ( Try again )
└─────────┘ └─────────┘                                   Error ID: …
 x3 rows (skeleton)
```

---

## 2. Bottom navigation (HL-N1, owner decision; route change)

| Aspect | Proposal |
| ------ | -------- |
| Items (start → end) | Home (live hub) · Discover · **Create** (centre) · Inbox · Profile |
| Labels en / ar | Home / الرئيسية · Discover / استكشاف · (centre: no visible label; semantics "Create" / "إنشاء") · Inbox / الرسائل · Profile / حسابي |
| Centre action | `primary` pill 44 × 32 dp, radius `md`, "+" in `onPrimary` (current build). It opens the **Create sheet** (VG-20); it is no longer a tab page |
| Active state | Filled icon + label in `textPrimary` + a 4 dp `primary` dot above the icon. Inactive: outline icon + `textSecondary` label. Red text is removed from labels (calmer chrome) |
| Inbox | Placeholder destination with an honest Phase 9 state (compact `KEmptyState`) |
| Routes | `/live` → redirect to `/home` (keep for deep links); add `/inbox`; the shell branches become home, discover, create-sheet trigger, inbox, profile. **Needs owner + CTO approval** (route registry ownership) |
| Hidden | On full-screen live surfaces (room, PK, go-live) and the camera |

---

## 3. Live room

All live surfaces are always dark. Every populated room state is **fixture-only** until the
Phase 6 live API and B1 (LiveKit) exist.

### HL-L1 Composition and z-order

| z | Layer | Notes |
| - | ----- | ----- |
| 0 | Video (full-bleed, `BoxFit.cover`) or the missing-video fallback | Under the status bar |
| 1 | Legibility gradients | Top: black 0→45 % over 120 dp. Bottom: 0→55 % over 280 dp (VG-26) |
| 2 | PK panes + score bar + timer (PK mode only) | HL-L8 |
| 3 | Chat overlay, entry banner, gift combo banners | Start side; the end 25 % stays free |
| 4 | Full-screen gift effect layer | `IgnorePointer`; above the chat, below the controls |
| 5 | Header (host pill, viewers, close) and action bar | Always tappable |
| 6 | Room sheets (gift, viewers, more) | Non-dimming barrier (HL-L6) |
| 7 | Dialogs, toasts, status chips | Status chips sit top-centre under the header |

### HL-L2 Header: host pill and follow (top-start)

- **Position:** `inset-top + sm`, start `sm`. The pill is 40 dp high on `scrim`, radius `pill`.
- **Contents:**
  - avatar 32 dp;
  - name: 13/600, 1 line, ellipsized, keeping ≥ 8 characters at 360 dp;
  - optional second line, 12/400 `textSecondary` (follower count or room ID), **only when the
    API provides it**;
  - Follow: a 28 dp `primary` chip "+ Follow / + متابعة". After following it shows a check for
    1 s, then fades out (`durationBase`).
- **Tap:** opens the host mini-profile sheet (Phase 2 data).

### HL-L3 Viewers and close (top-end)

- **Viewer strip:** up to 3 overlapping 28 dp avatars (only on screens ≥ 430 dp, QA-009 rule;
  otherwise hidden), then the count chip (eye + compact).
- **Close:** a 32 dp `scrim` circle with a 20 dp × icon and a 48 dp hit area.
- **Tap on viewers:** opens the audience sheet (Phase 6).

### HL-L4 Room info row

- **Position:** under the host pill (y + 48), start side, 28 dp chips on `scrim`.
- **Contents:** room title or topic chip, and a "Top supporters" entry (Phase 7).
- **Renders only with data:** with no data, the row is absent (no empty chips).

### HL-L5 Chat

| Aspect | Spec |
| ------ | ---- |
| Placement | Start side, above the action bar (`sm` gap), width 75 % (`KMetrics.chatWidthFactor`) |
| Height cap | 30 % of the screen height (255 dp at 852); newest line at the bottom; top 25 % fades |
| Density | Text 13/400, name 13/600 (proposal T-1); line padding `xs` vertical / `sm` horizontal; bubbles on `chatScrim` 60 %, radius `md`; `xs` gap between lines |
| Max lines | 6 visible (`KMetrics.chatMaxVisibleLines`); scroll-back on drag pauses auto-scroll and shows a "New messages ↓ / رسائل جديدة" pill |
| Line types | user · gift (gold gift icon, bidi-isolated parts, ×N at the end) · system (info icon, `textSecondary`). Join notices are **not** chat lines (see the entry banner) |
| Entry banner | One line above the chat, "{name} joined / ‏{name} انضم", visible for 2 s, replaced by the next one; reduce-motion means no slide |
| Empty chat | One system line "Welcome to {host}'s live / مرحبًا بك في بث {host}" |
| Names | White (D33); tap opens the user card (Phase 6) |

### HL-L6 Gift button, panel, animation layer

- **Gift button:** at the end of the action bar, a 40 dp `scrim` circle with a 24 dp gift icon
  in `gold` (the only gold on screen, D33).
- **Panel:**
  - a **non-dimming** sheet (transparent barrier; tap outside closes), about 45 % of the
    screen height, `surfaceRaised`, radius `xl` at the top;
  - grid of 4 columns, with names wrapping to 2 lines (VG-34);
  - category tabs, balance and top-up appear only when their APIs exist (Phase 7/8, B5);
  - while sending is unavailable, Send stays disabled with an explanation (current, honest).
- **Combo banners:** start side, at the vertical band just above the chat, max 3 stacked, ×N
  bump (`motion.giftComboBumpMs`).
- **Full-screen effects:** z-layer 4 (HL-L1); queue and budget per DESIGN_SYSTEM §7.3.

### HL-L7 Action bar (no decorative controls)

| Slot | Control | Integration requirement |
| ---- | ------- | ----------------------- |
| start (flex) | Comment pill "Say something… / قل شيئًا…", h 40, `scrim` | Chat send (Phase 6 realtime events) |
| end-2 | Share (40 dp circle) | Room deep link (B7 domain) + system share sheet |
| end-1 | Gift (40 dp circle, gold icon) | Gift catalogue + send (Phase 7; purchase B5) |
| later | More (⋯): report, mute sounds | Added only when the report endpoint exists (Phase 6) |
| later | Like (double-tap on video) | Likes API |

Position: `inset-bottom + sm`, padded `sm` at the start and end. When the keyboard is open, the
input replaces the bar and sits above the keyboard, and the chat compresses.

### HL-L8 PK split layout

```
┌─────────────────────────────────────────┐ y
│ status bar                              │ 0-59
│ (av Sara  +Follow)    [eye 12.3K]  (X)  │ 67-107  header
├────────────────────┬────────────────────┤ 115
│████ 9,000 █████████████████│▒▒ 1,000 ▒▒│ 115-139 score bar 24 (pkLeft | pkRight)
├────────────────────┼────────────────────┤ 139
│                    │                    │
│    HOST pane       │   OPPONENT pane    │         each 196.5 x 262 (aspect 0.75)
│    (start)       [ 0:09 ]     (end)     │         timer chip on the seam (urgent tint)
│                  [VS mark]              │         Kabso-original mark
│                    │                    │
├────────────────────┴────────────────────┤ 401
│ (o)(o)(o) supporters   supporters (o)(o)(o)│ 401-433 top-3 avatars per side
├─────────────────────────────────────────┤
│ [entry banner]                          │
│ [chat lines ×6, start, 75 %]            │ ~470-770
│ (Say something...........)  (sh) (gift) │ 770-810 action bar
│ inset-bottom                            │ 818-852
└─────────────────────────────────────────┘
```

**ar:**
- The **host pane is at the right (start)** with `pkLeft` on the right; the opponent is at the
  left.
- The score bar mirrors with the panes (DESIGN_SYSTEM §6.2).
- The timer and VS mark stay centred.
- Supporter rows mirror.
- Scores: ≥ 20/700 (`KMetrics.pkScoreMinFontSize`), tabular, Latin digits.

**Result:** a per-pane overlay ("Win / فوز", "Lose / خسارة", "Draw / تعادل") for 3 s (VG-39).

### HL-L9 Safe areas and sizes (viewer, non-PK)

```
┌─────────────────────────────────────────┐ y
│ status bar                              │ 0-59
│ (av Sara | ID 123 +Follow)  [12.3K]  (X) │ 67-107 header (8 below inset)
│ [Topic: Music]  [Top supporters >]      │ 115-143 room info (only with data)
│                                         │
│                 video                   │
│            [Weak connection]            │ status chip top-centre (when needed)
│                                         │
│ [gift combo banners ×≤3]                │ ~430-520
│ [entry banner]                          │
│ [chat ≤ 6 lines, start, 75 % width]     │ ~515-770 (cap 255)
│ (Say something...........)  (sh) (gift) │ 770-810
│ inset-bottom                            │ 818-852
└─────────────────────────────────────────┘
```

**ar:** the host pill moves to the right and the viewers and close to the left; the chat and
banners are right-aligned; in the action bar the comment pill starts at the right and share
and gift are at the left.

### HL-L10 Room states

| State | Trigger | UI |
| ----- | ------- | -- |
| Poor connectivity | Bitrate or packet-loss threshold from the media SDK (Phase 6) | Top-centre chip "Weak connection / اتصال ضعيف" (`warning` icon); video continues |
| Reconnecting | Media disconnected > 3 s | Last frame dimmed 30 % + centred spinner + "Reconnecting… / جارٍ إعادة الاتصال…"; after 30 s: "Can't reconnect / تعذّر إعادة الاتصال" with Try again and Leave |
| Missing video | Host camera off / audio-only | Host avatar `avatarLg` centred on a `surface` gradient-free background + "Camera is off / الكاميرا متوقفة"; chat and actions unchanged |
| Empty chat | No messages yet | A single welcome system line (HL-L5) |
| Host left / ended | Room ended event, or opening a stale card | A full overlay on `background` 90 %: host avatar, "This live has ended / انتهى هذا البث", Follow (if not following), "Back to live rooms / العودة إلى البثوث"; the video stops |

All are **fixture-only goldens** until Phase 6.

---

## 4. Anti-patterns to remove

| Anti-pattern | Where it is today (capture) | Replace with |
| ------------ | --------------------------- | ------------ |
| Excessive gradients | PK badge gradient (`gallery-1.*`); card red top accent line (`component-cover_cards.*`) | Solid PK tag; no accent line. Gradients only on the avatar live ring and the media legibility scrims |
| Generic dashboard cards | Profile "Your posts will live here" outlined card (`profile.*`) | Flat section with an inline compact state |
| Oversized rounded containers | 88 dp icon circles in every empty state (`home`, `discover`, `create`, `live`); full-width outlined cards | 48 dp icon, no circle container; content-first layout |
| Screen-centred empty states with title bars | All shell tabs | Structure first (tabs, chips), with the state inside the content region |
| Decorative elements | "Cover couldn't load" icon and text on cards; red link-coloured nav labels | Avatar fallback; indicator-only red in the nav |
| Redundant labels | LIVE badge on every card in a live-only grid; "0" viewers | Badge only in mixed contexts; "New" chip |
| Heavy modal dimming in the room | Gift sheet scrim over the stream (`component-room_gifts.*`) | Non-dimming room sheets |

---

## 5. Token change proposals (for the CTO; contract changes go through the CTO)

Per D32, component-only measurements go to `KMetrics`; only shared values are proposed as
tokens.

| ID | Proposal | Value | Used by | Reason |
| -- | -------- | ----- | ------- | ------ |
| T-1 | `typography.chat` and `typography.chatName` | 13/400/1.35 and 13/600/1.35 | Chat overlay, entry banner, gift combo banners, host pill name | Denser overlay text shared by ≥ 3 components |
| T-2 | `typography.tabPrimary` | 18/600/1.3 selected (= `title`); unselected uses `bodyStrong` | Home tabs, Inbox tabs (Phase 9) | Two-level header hierarchy (VG-07) |
| T-3 | `size.topBarHeight` | 48 | Home header, room-adjacent bars | Repeats DESIGN_SYSTEM P18 at the Home value |
| T-4 | `color.live.legibilityTop` / `legibilityBottom` | black 45 % / 55 % gradient end stops (`#73000000`, `#8C000000`) | Room, cover cards (bottom), story/reel later | Shared media-overlay scrims |
| T-5 | `size.pkPaneAspect` | 0.75 (alias of `liveCardAspect`) | PK panes, multi-guest seats | Shared aspect |

**`KMetrics` additions (no contract change):**
- `homeGridPadding` = `KSpacing.sm`;
- `homeGridGap` = `KSpacing.xs`;
- `chipHeight` = 32;
- `hostPillHeight` = 40;
- `roomIconVisual` = 40;
- `closeVisual` = 32;
- `chatMaxHeightFactor` = 0.30;
- `entryBannerDuration` = 2 s;
- `tabIndicatorWidth` = 16;
- `tabIndicatorHeight` = 3;
- `featuredAspect` = 16/7.

---

## 6. Component refactors (reuse; no duplicates)

| Existing component (file) | Refactor |
| ------------------------- | -------- |
| `KLiveCoverCard` (`features/live/presentation/widgets/live_cover_card.dart`) | Remove the top accent; `showLiveBadge` (default false); "New" for < 1 viewer; mode tag (PK solid, multi-guest); avatar fallback for a missing cover; press scale |
| `KTabs` (`design_system/components/k_tabs.dart`) | Add a `primary` style (T-2, short indicator); keep `scrollable` for secondary use only where chips don't fit |
| *(new)* `KChip` (`design_system/components/k_chip.dart`) | Filter chip per DESIGN_SYSTEM §9.9; used by the category row and the gift quantity |
| `KEmptyState` / `KErrorState` (`design_system/components/k_states.dart`) | `compact` variant (48 dp icon, no circle, top-third placement) |
| `KBadge` (`design_system/components/k_badge.dart`) | Solid PK; `newRoom` chip; multi-guest tag |
| `KLiveRoomScaffold` (`…/live_room_scaffold.dart`) | Explicit z-layer slots (HL-L1), legibility gradients, status-chip slot, room-info slot, PK mode, safe-area handling |
| `KHostPill`, `KViewerStrip`, `KRoomActionBar`, `KRoomIconButton` (same file) | Two-line pill, follow collapse, 32 dp close visual, v1 action set |
| `KLiveChatOverlay` / `KLiveChatBubble` (`…/live_chat_overlay.dart`) | T-1 typography, entry banner, bidi isolates (VG-30), "new messages" pill, height cap |
| `KPkScoreBar` (`…/pk_score_bar.dart`) | Becomes part of the new `KPkLayout` (panes, seam timer, VS mark, supporters, results) |
| `KGiftPanel`, `KGiftComboCounter` (`…/gift_panel.dart`) | Non-dimming presentation, 2-line names, hidden tab/balance slots; the combo counter is reused by the on-video combo banner |
| `KBottomNav` (`app/shell/app_shell.dart`) | Active dot indicator, `textPrimary` labels, items per HL-N1 |
| `ComingSoonTab` (`app/shell/coming_soon_tab.dart`) | No longer used by Home (or by Live, if it is removed) |

Goldens: each refactor updates its existing golden in `test/goldens/` in ar and en at
393×852 and 360×800. New fixture goldens: `home.unavailable`, `home.populated`,
`home.loading`, `home.empty.following`, `room.viewer`, `room.pk.split`, `room.gifts`, and
`room.state.{weak,reconnecting,camera-off,ended}`.

---

## 7. Questions for the owner

1. **Bottom nav (HL-N1):** may we remove the Live tab (Home becomes the live hub) and add Inbox
   (Phase 9 placeholder)? This is a route change.
2. **Home tabs:** is Following · Popular · New right? Should Popular be the default even for
   users who follow people?
3. **Nearby:** do you want a Nearby tab (needs location permission and privacy review; earliest
   Phase 9)?
4. **Wordmark:** OK to drop the wordmark from the Home header (it stays on Splash and Login)?
5. **PK:** approve the split-screen layout (2 panes) over the current single-video overlay?
6. **Gift sheet:** approve a non-dimming sheet so the stream stays visible while gifting?
7. **Categories:** who curates the category list (server config vs editorial), and do you have
   initial categories for Phase 6?
8. **References:** when can you supply the authorized reference screenshots (REFERENCE_INVENTORY
   §5)? Rows 1–5 first; they would let us check every item in the gap analysis §11.
