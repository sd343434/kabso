# Kabso Live: visual review of Home and Live discovery (KL-035a)

Status: **two passes.**
- §1–§6 review the integrated HEAD **before KL-047** (`04ffd09`).
- **§7 reviews the build after KL-047** (`27bfd44`). It records what KL-047 fixed, the remaining
  gaps, KL-047's design decisions, and the prioritized next changes.

**Read §7 for the current state.**

Author: A5 (product design), with A1. Date: 2026-10-16.

| | |
| --- | --- |
| App revision | Before: `04ffd09`. After: `27bfd44` (KL-047 `f5fb4f0`, KL-045 `4af9512`). Each is a web `--profile` build of the unchanged `apps/mobile` sources at that commit |
| API revision | Same commit as its app set; `apps/api` built and run locally on the same local data |
| Screenshots | [`review/2026-10-16-home-live/`](review/2026-10-16-home-live/). The README there gives the exact commands, environment, data provenance and file index |
| Viewports / locales | 393×852 and 360×800 @3x; `ar` (RTL) and `en` (LTR); dark theme |

**Screenshot labels.** Every image is in exactly one of these folders:
- **Production behaviour**: [`head-04ffd09-pre-kl047/production/`](review/2026-10-16-home-live/head-04ffd09-pre-kl047/production/).
  What production shows today: Home unavailable, Live hosting-unavailable.
- **Local API data**: [`head-04ffd09-pre-kl047/local-api/`](review/2026-10-16-home-live/head-04ffd09-pre-kl047/local-api/).
  The real app against the real API in a local review environment, with 8 labelled local test
  hosts, 1 reviewer account and 3 categories named "Local test: …" / "محلي: …".
- **Test fixture**: [`fixtures/`](review/2026-10-16-home-live/fixtures/). Golden renders of
  fixture data; not live data.

The after set uses the same labels, in `head-27bfd44-after-kl047/{production,local-api}/` and
`fixtures-after/`. Some captures are labelled **simulated** in their file name: a proxy 502, an
offline network, or a held request (loading).

Below, `P/`, `L/` and `F/` abbreviate the three before-set folders; §7 uses `A/` for the after
set. A file stem such as
`L/live.populated-popular` exists as `.{ar,en}.{393,360}.png`.

No comparison with any third-party app is made or implied. Authorized references have not been
supplied (§6).

---

## 1. Home (`/home`): social feed

### 1.1 Screenshots

| State | Label | ar / en × 393 / 360 |
| ----- | ----- | ------------------- |
| Popular (default), unavailable | Production behaviour | `P/home.popular-unavailable` |
| Following, unavailable | Production behaviour | `P/home.following-unavailable` |
| New, unavailable | Production behaviour | `P/home.new-unavailable` |
| Populated feed | Test fixture | `F/home.populated` |
| Loading / empty / error | **Not reproducible.** No feed API exists; `homeFeedProvider` returns `FeedUnavailable` for every tab, so production can only ever show the unavailable state | — |

### 1.2 What works well

- **Header:** Following · Popular · New with a search icon, 48 dp, no wordmark and no
  decorative icons (D36, HL-H1/H2, VG-05, VG-22).
- **Tab hierarchy:**
  - the selected tab (18/600 with a short red indicator) is clearly above the unselected tabs
    (15, secondary);
  - the indicator is the only red in the header.
- **States:** each tab has its own icon and copy, and the copy is honest ("coming soon"; no
  fake posts).
- **Placement:** the state sits in the content region under the header, not centred on the
  whole screen (VG-03).
- **RTL:** the order mirrors correctly. متابَعون is at the right, the search icon at the left,
  and the nav runs right to left with الرئيسية at the right.
- **Bottom nav:** active dot, `textPrimary` label, and red limited to the dot and the Create
  pill (VG-19).

### 1.3 Visual weaknesses

1. **Empty space.** The state block uses roughly y 100–230 dp. Everything from about 260 dp to
   the nav (about 530 dp at 393×852) is flat `#0B0B0D`. Nothing tells the user what to do
   meanwhile. There is no path to the one populated part of the product (Live), and Home does
   not point to it.
2. **Following looks the same on Home and Live.** Home Following and Live Following share the
   `group_outlined` icon and near-identical titles ("Posts from people you follow" vs "Live
   rooms from people you follow"). Side by side, the two tabs are hard to tell apart.
3. **Duplicated copy.** The Following body ("Coming soon: posts from people you follow will
   appear here.") restates the title.
4. **Arabic text weight.** At the same token sizes (15 body, 15 unselected tab), the Arabic
   copy looks visibly smaller and lighter than the English. Unselected Arabic tabs (رائج،
   جديد) are the weakest text on screen.

### 1.4 Typography, spacing, density, image ratio

- **Type sizes:** title 18/600; body 15/400 secondary; tabs 18/600 and 15/600. These are
  consistent with HL-H2.
- **Spacing:** the state block starts about 56 dp below the header. That is fine, but with no
  content below it the block reads as floating.
- **Density and image ratio:** there is no content, so neither applies in production. In the
  fixture (`F/home.populated`), post media spans the content width at roughly 4:3.

### 1.5 RTL / LTR

There are no mirroring defects in the Home captures. Body text is centred in both directions.

### 1.6 Against the design goals

| Goal | Result |
| ---- | ------ |
| D36/D39 Home = feed, separate from the Live grid | Met |
| HL-H1/H2 header and tabs | Met |
| HL-H6 compact unavailable state; pull-to-refresh disabled on Home (D41) | Met |
| VG-03 compact in-place state | Met |

### 1.7 Responsible files and widgets

| Concern | File | Widget |
| ------- | ---- | ------ |
| Screen and per-tab copy and icons | `apps/mobile/lib/features/home/home_screen.dart` | `HomeScreen`, `_HomeFeedPage`, `HomeFeedBody` (`FeedRegionCopy`) |
| Feed data source (unavailable everywhere) | `apps/mobile/lib/features/home/application/home_feed_provider.dart` | `homeFeedProvider` |
| Header, tabs and pager | `apps/mobile/lib/app/shell/feed_tabs_scaffold.dart`; `apps/mobile/lib/design_system/components/k_tabs.dart` | `FeedTabsScaffold`; `KPrimaryTabs`, `_Tab` |
| State region | `apps/mobile/lib/app/shell/feed_region.dart`; `apps/mobile/lib/design_system/components/k_states.dart` | `FeedRegion`; `KEmptyState(compact: true)` |
| Post tile (fixture only) | `apps/mobile/lib/features/home/presentation/widgets/feed_post_tile.dart` | `FeedPostTile`, `FeedPostSkeleton` |
| Bottom nav | `apps/mobile/lib/app/shell/app_shell.dart` | `KBottomNav`, `_NavButton` |
| Text styles | `apps/mobile/lib/design_system/tokens/tokens.dart`, `apps/mobile/lib/design_system/theme/app_theme.dart` | — |

---

## 2. Live discovery (`/live`)

### 2.1 Screenshots

| State | Label | ar / en × 393 / 360 |
| ----- | ----- | ------------------- |
| Hosting unavailable: Popular (default), Following, New | Production behaviour | `P/live.unavailable-popular`, `P/live.unavailable-following`, `P/live.unavailable-new` |
| Loading (API held for 15 s by the browser) | Local API data | `L/live.loading` |
| Empty: Popular, Following ("See popular"), New | Local API data | `L/live.empty-popular`, `L/live.empty-following`, `L/live.empty-new` |
| Error with Try again: API stopped | Local API data | `L/live.error-api-down` |
| Error with Try again: simulated proxy 502 | Local API data (simulated proxy fault) | `L/live.error-proxy-502` |
| Populated Popular with category chips | Local API data | `L/live.populated-popular` |
| Category selected ("Local test: Music") | Local API data | `L/live.category-selected` |
| Scrolled to the end, with the end caption | Local API data | `L/live.scrolled-end` |
| Following populated (2 followed hosts) | Local API data | `L/live.populated-following` |
| New | Local API data | `L/live.populated-new` |
| Covers, viewer counts, PK/multi-guest tags | Test fixture | `F/live.populated`, `F/live.categories` |
| Footer loading and footer error | Test fixture | `F/live.footer_loading`, `F/live.footer_error`, `F/live.end` |

### 2.2 What works well

- **Structure is always present.** Tabs, the chip row (Popular only) and the state or grid
  appear in every state, so the screen never collapses to a lone message (VG-01).
- **Grid:**
  - 2 columns, 3:4 cards, 8 dp side padding and 4 dp gaps (HL-H4, VG-09);
  - 2 full rows plus most of a third are visible at 393 with no insets;
  - the fixture with 59/34 insets shows 4 full cards and the start of row 3.
- **Honest cards:**
  - no LIVE badge or accent line in a live-only grid (VG-10);
  - "New / جديد" instead of "0" (VG-11);
  - a missing cover shows the host initial with no error text (VG-13);
  - a bottom scrim keeps the name and title legible.
- **Real data:**
  - the populated grid, category filter, Following and New all render real API data;
  - selecting "Local test: Music" correctly narrows to the 2 music rooms;
  - Following shows exactly the 2 followed hosts.
- **States:**
  - the loading skeleton mirrors the card anatomy (top chip, two text lines);
  - empty Following offers a real action, "See popular";
  - error shows a specific message for offline vs server error, plus Try again.
- **RTL:**
  - the grid starts at the right;
  - the New chip is at the card's top-right;
  - the chip row starts from the right with الكل;
  - server-localized category names appear (محلي: موسيقى).
- **Chip row:** it scrolls away and the end caption shows when you reach the end (HL-H5).

### 2.3 Visual weaknesses

1. **Cards read as placeholders (RG-03).**
   - With no covers or avatars, each card is about 75 % flat dark grey around a large initial
     circle.
   - Eight identical grey tiles do not convey "people are live right now". The only
     differences between cards are a letter and two lines of small text.
   - This is the biggest gap from D39's "clear thumbnails". The fixture (`F/live.populated`)
     shows the intended richness.
2. **Mixed-script text breaks in RTL (RG-04).**
   - A Latin title on an Arabic UI is laid out RTL. In `L/live.populated-popular.ar.393` it
     shows as "…Learning Arabic calligraphy," with the ellipsis at the start and the comma
     moved to the end. At 360 it shows as "…Morning coffee and quest".
   - In `en`, Arabic names and titles are left-aligned against a left edge, which reads as
     misaligned.
3. **"New" everywhere (RG-10).**
   - Every card carries a white "New" chip, the highest-contrast element on the card, above
     the host's name.
   - On the **New** tab every card repeats the tab's name.
4. **Popular and New are the same list (RG-11, D38).** Until presence exists the two tabs are
   pixel-identical apart from the chip row.
5. **No topic on cards (RG-05).** With All selected you cannot see which room is Music or
   Games, although the API sends the category.
6. **Inconsistent vertical rhythm (RG-08).**
   - On Popular every state (unavailable, loading, empty, error) starts 48 dp lower than on
     Following and New, because of the chip row.
   - In unavailable, empty and error the row holds a single non-interactive "All" chip that
     filters nothing.
7. **Misleading icon (RG-09).** The New-tab unavailable icon (`new_releases_outlined`, a
   starburst with "!") reads as a warning.
8. **Empty space (RG-07).** It is the same as on Home in every non-populated state. A Following
   tab with 2 rooms leaves more than half the screen blank, with only the end caption.
9. **Low-contrast skeleton (RG-13).** The skeleton cards are barely distinguishable from the
   background.
10. **Offline is just an error (RG-01, QA-003).** Losing the connection shows the error state
    with offline copy. There is no banner and no automatic recovery.
11. **Not interactive (RG-02).** Cards have no press feedback or button semantics until the
    room screen exists (slice 2).

### 2.4 Typography, spacing, density, image ratio

| Aspect | Observation |
| ------ | ----------- |
| Card text | Host `bodyStrong` 15/600 and title `caption` 12, both white on the scrim. The title truncates at about 25 Latin characters at 393 and 22 at 360 (RG-06). One line is per spec, but long English titles lose their meaning ("Morning coffee and que…") |
| Card ratio | 3:4 is correct (186.5×248.7 at 393; 170×226.7 at 360). Without covers the ratio gives a lot of empty grey; with covers (fixture) it works |
| Fallback avatar | `avatarLg`, near the card's centre. It dominates the card and competes with the name at the bottom |
| Chip row | 32 dp chips with an 8 dp gap. The long local test names push the third chip off-screen, which is an acceptable scroll affordance. Selected = red fill, unselected = raised surface; clear |
| Density | 2.4 rows per viewport at 393 without insets, about 2 with device insets. That is good for a discovery grid |
| End caption | `caption`, secondary, centred, below the grid. Easy to miss, but appropriate |
| State blocks | Same compact block as Home: 48 dp icon, 18/600 title, 15 body, an optional secondary button |

### 2.5 RTL / LTR

| Item | ar (RTL) | en (LTR) |
| ---- | -------- | -------- |
| Tab order, search, nav | Correct | Correct |
| Grid start, chip row start | Correct (right) | Correct (left) |
| New chip position | top-right (start) ✔ | top-left (start) ✔ |
| Latin text inside cards | **Broken**: ellipsis on the wrong side; trailing punctuation moved (RG-04) | n/a |
| Arabic text inside cards | n/a | Left-aligned (UI direction), not right-aligned by content (RG-04) |
| Category names | Server-localized (محلي: …) ✔ | ✔ |
| Error / empty copy | Correct, centred | Correct |

### 2.6 Against the design goals

The full met / partially met / not met table, with evidence, is in the
[review README §4](review/2026-10-16-home-live/README.md#4-design-goals-met-partially-met-or-not-met).
In summary:

- **Met:** D36/D39 structure (separate hub, Popular default, three tabs, categories, honest
  production states), HL-H1, HL-H2, HL-H3, HL-H4 grid geometry, the HL-H6 unavailable,
  loading, empty and error states, and VG-01/03/05/06/07/09/10/11/13/19/22.
- **Partially met:**
  - D39 creator identity (name and letter only);
  - D39 search (goes to the Discover placeholder);
  - HL-H5 / VG-41 (footer states only in fixtures);
  - VG-12 (mode tags fixture-only; category not shown).
- **Not met:**
  - D39 clear thumbnails (no covers);
  - the HL-H6 offline state (QA-003);
  - VG-44 card press/open (slice 2).
- **Not verified:** VG-42 swipe between tabs.

### 2.7 Responsible files and widgets

| Concern | File | Widget / member |
| ------- | ---- | --------------- |
| Hub page, per-tab copy and icons, chips, grid | `apps/mobile/lib/features/live/live_screen.dart` | `LiveScreen`, `_LiveHubPage`, `LiveHubBody` (`FeedRegionCopy`, `_chips`, `_grid`, `onOpenRoom`), `liveHubContent` |
| Data, paging, refresh | `apps/mobile/lib/features/live/application/live_rooms_provider.dart`; `apps/mobile/lib/features/live/data/live_repository.dart` | `liveRoomsProvider`, `LiveHubState`; `LiveRepositoryImpl` |
| Card view data (category dropped) | `apps/mobile/lib/features/live/presentation/widgets/live_view_data.dart` | `LiveRoomCardData.fromSummary` |
| Card | `apps/mobile/lib/features/live/presentation/widgets/live_cover_card.dart` | `KLiveCoverCard` (name/title `Text`), `_CardFrame`, `_BottomScrim`, `_CoverFallback`, `_CoverHostAvatar`, `KLiveCoverCardSkeleton` |
| New chip, PK and multi-guest tags | `apps/mobile/lib/design_system/components/k_badge.dart` | `KBadge.newRoom`, `KBadge.pk`, `KBadge.multiGuest` |
| Chips | `apps/mobile/lib/design_system/components/k_chip.dart` | `KChip`, `KChipRow` |
| States, footer, prefetch, refresh | `apps/mobile/lib/app/shell/feed_region.dart` | `FeedRegion`, `_DelayedSliver`, `_Prefetch`, `_LoadMoreError`, `_EndOfList` |
| Error content | `apps/mobile/lib/core/error/failure_widgets.dart`; `apps/mobile/lib/core/network/error_mapper.dart` | `FailureErrorState`; `toAppFailure` |
| Empty/unavailable block | `apps/mobile/lib/design_system/components/k_states.dart` | `KEmptyState` (compact) |
| Skeleton | `apps/mobile/lib/design_system/components/k_skeleton.dart` | `KSkeleton` |
| Header, tabs, pager | `apps/mobile/lib/app/shell/feed_tabs_scaffold.dart`; `apps/mobile/lib/design_system/components/k_tabs.dart` | `FeedTabsScaffold`; `KPrimaryTabs` |
| Metrics | `apps/mobile/lib/design_system/tokens/component_metrics.dart` | `KMetrics.liveGrid*`, `topBarHeight`, `loadingRevealDelay` |

---

## 3. Shared observations

- **Session restore failure.** Starting the app while the API is down shows the splash
  "We couldn't restore your session" in the **pre-redesign** style: a centred 88 dp circle
  (VG-03 anti-pattern). It is not part of Home or Live, but it is the screen in front of them
  (RG-14, `apps/mobile/lib/features/auth/presentation/splash_screen.dart`).
- **Safe areas.** The running-app captures have 0 insets (web). Real-device inset behaviour is
  shown only by the fixtures (RG-15).
- **Web-only artefact (not a product defect).** A mouse hovering a tab draws Material's hover
  highlight. The captures park the pointer to avoid it.

---

## 4. Prioritized changes

The priority reflects the impact on the owner's D39 goal of polished discovery. Each change
lists its acceptance criterion. Paths are under `apps/mobile/`.

| # | Pri | Change | Files / widgets | Acceptance criterion |
| - | --- | ------ | --------------- | -------------------- |
| C1 | P0 | **Bidi-correct card text (RG-04).** Lay out name and title by their own content direction (first-strong detection or a bidi isolate), so the ellipsis falls at the logical end and punctuation stays put. Align by content in both locales | `live_cover_card.dart` (`KLiveCoverCard`) | Widget test plus golden: in `ar`, the title "Learning Arabic calligraphy, lesson 3" renders LTR with a trailing "…" and the comma in place. In `en`, an Arabic title renders RTL, right-aligned. Re-capture `L/live.populated-popular.ar.393` shows no leading "…" |
| C2 | P0 | **Stronger no-cover card (RG-03)** until uploads exist: a calmer, more designed fallback that still reads as a person live now. For example, a tinted surface from the token palette derived deterministically from the host id (not an image or a fake cover), with a smaller avatar above the name. No invented imagery | `live_cover_card.dart` (`_CoverFallback`), `component_metrics.dart` | At 393, adjacent cards are visually distinct without covers. The fallback avatar is ≤ 56 dp. Name and title contrast is ≥ 4.5:1 on every tint. Golden at ar/en × 393/360. No network image is requested when `coverUrl` is null |
| C3 | P0 | **"New" chip noise (RG-10).** Hide the New chip on the New tab, and give it a quieter style (scrim fill, white text) so it does not outrank the host name | `live_screen.dart` (pass a flag into `KLiveCoverCard`), `live_cover_card.dart`, `k_badge.dart` (`KBadge.newRoom`) | On the New tab no card shows "New/جديد". On Popular and Following the chip's fill luminance is below the name text's. Text contrast is ≥ 4.5:1. Widget test for both tabs |
| C4 | P1 | **Show the room category on cards (RG-05)** when it is present and the All chip is selected. One short tag at top-end only when no mode tag occupies it, otherwise above the name. Never shown without data | `live_view_data.dart` (`LiveRoomCardData` + `fromSummary`), `live_cover_card.dart` | A room with a category shows its server-localized name; a room without one shows nothing in that slot. Hidden while that category's chip is selected. Golden plus widget test |
| C5 | P1 | **Offline state (RG-01, QA-003):** an offline banner under the header plus auto-retry on reconnect; keep the last loaded grid if there is one | `feed_region.dart`, `live_rooms_provider.dart`, a connectivity source (new dependency, CTO approval), `failure_widgets.dart` | With the API unreachable, the banner shows "offline" in ar/en. When connectivity returns, the tab reloads without a tap. A previously loaded grid stays visible under the banner. Widget test with a fake connectivity stream |
| C6 | P1 | **Consistent state position (RG-08):** hide the chip row in unavailable, loading-without-categories, empty-without-categories and error, or reserve the same 48 dp on all three tabs | `live_screen.dart` (`LiveHubBody.header`, `_chips`) | In `P/live.unavailable-*` and `L/live.error-*` the state icon's top edge is at the same y (±1 dp) on all three tabs. No chip renders when the server sent no categories and the state is not populated |
| C7 | P1 | **Use the empty space honestly (RG-07).** On Home's unavailable tabs, add a secondary action to "Go to Live" (a real route). On Live Following with few rooms, show a "See popular" link under the end caption. No filler content | `home_screen.dart` (`HomeFeedBody` copy/action), `feed_region.dart` (`FeedRegionCopy` action for unavailable), `live_screen.dart` | Home Popular unavailable shows a button that navigates to `/live` (widget test). Live Following with < 4 rooms shows "See popular" below the end caption. No fake posts or rooms |
| C8 | P2 | **Distinct icons and copy (RG-09; Home Following vs Live Following):** replace `new_releases_outlined`; use a different icon for Home Following, and remove the duplicated "Coming soon:" body text | `live_screen.dart` (`unavailableIcon`), `home_screen.dart`, `lib/l10n/app_{en,ar}.arb` | No warning-like glyph in any unavailable state. Home Following and Live Following use different icons. The bodies do not repeat their titles (copy review by A5) |
| C9 | P2 | **Arabic typography balance (RG-12):** tune the Arabic text styles (size +1 or a heavier weight for secondary body and unselected tabs) within the existing tokens | `tokens.dart`, `app_theme.dart`, `k_tabs.dart` (`_Tab`) | Side by side, ar and en captures of `P/home.popular-unavailable` show similar visual weight (A5 sign-off). Text-scale 2.0 ar does not overflow (existing test) |
| C10 | P2 | **Skeleton contrast (RG-13)** | `k_skeleton.dart`, `KLiveCoverCardSkeleton` | Skeleton-to-background luminance contrast ≥ 1.3:1, still below the card surface. `L/live.loading` re-capture is visibly structured |
| C11 | P2 | **Title truncation (RG-06):** allow 2 lines for the title when there is no cover, or reduce the host line to 14/600 | `live_cover_card.dart` | "Morning coffee and questions" is fully visible at 360 in a no-cover card; with a cover, one line is kept |
| C12 | P2 | **Splash restore failure in the compact style (RG-14)** | `splash_screen.dart`, `k_states.dart` | No 88 dp circle container on the restore-failure screen; layout per VG-03 |
| C13 | — | **Card tap / room open (RG-02)**: slice 2, on hold with KL-034 | `live_screen.dart` (`onOpenRoom`), `live_cover_card.dart` (`_CardFrame`) | Per VG-44 once the room route exists |

Out of Flutter's hands:
- **RG-11 (Popular ≡ New)** needs presence (API).
- **RG-03 (covers and avatars)** fully resolves only with the upload API.

C2 is the interim design answer to RG-03.

---

## 5. Limitations of this review

| Limitation | Effect |
| ---------- | ------ |
| Web build, not a device | Rendering is the same Flutter framework (CanvasKit). Platform fonts, safe areas, status bar, haptics, scroll physics and pull-to-refresh are not exercised |
| No pull gesture | The pull-to-refresh indicator was not captured |
| 8 real rooms, page size 20 | The footer loading/error paging states could not be produced without fabricating data. They are shown only as fixtures |
| No presence, PK, multi-guest or uploads in the API | Viewer counts, mode tags and covers appear only in fixtures. The local database was not edited to fake them |
| Home has no data source | Home loading, empty and error are not reachable in the app |
| Proxy 502 is simulated | `L/live.error-proxy-502` comes from browser request interception standing in for a failing reverse proxy; the API itself was healthy |
| Swipe between tabs | Not exercised (VG-42 not verified) |

## 6. Reference comparison: pending — no authorized references supplied

No authorized reference screenshots were provided, so there is **no comparison with any other
app** in this review, and no similarity is claimed. Everything above is measured against
Kabso's own documented decisions: D36/D39, `HOME_LIVE_LAYOUT_DECISIONS.md` and
`BIGO_INSPIRED_GAP_ANALYSIS.md`.

A comparison would need:
- authorized references from the owner, kept in the git-ignored `design/references/` and never
  committed while the repository is public (D40);
- the same states at the same device sizes;
- a structural side-by-side covering hierarchy, density and placement only, with no copied
  measurements or assets.

---

## 7. After KL-047 (`27bfd44`)

The after screenshots are in
[`review/2026-10-16-home-live/head-27bfd44-after-kl047/`](review/2026-10-16-home-live/head-27bfd44-after-kl047/).
- **Same matrix:** ar/en × 393/360, the same local data and the same capture script as the
  before set.
- **Pairing:** the state-by-state before → after table is in
  [README §8.2](review/2026-10-16-home-live/README.md#82-before--after-by-state).
- **Abbreviation:** `A/` = `head-27bfd44-after-kl047/`.

### 7.1 KL-047 design decisions (owner-directed), recorded

| Decision | Replaces | Where |
| -------- | -------- | ----- |
| **Search hidden** until a search API exists | HL-H1/VG-05 search slot. D39 "search" is now **not met, by decision** | `apps/mobile/lib/app/shell/feed_tabs_scaffold.dart` (`FeedTabsScaffold.searchAvailable = false`, `showSearch`) |
| **LIVE badge on** for grid cards | VG-10 (no LIVE badge in a live-only grid) | `apps/mobile/lib/features/live/presentation/widgets/live_cover_card.dart` (`KLiveCoverCard.showLiveBadge` defaults to true), `apps/mobile/lib/design_system/components/k_badge.dart` (`KBadge.live`) |
| **Centred composed states:** 88 dp disc, tinted icon, warm copy, primary/secondary actions, at the optical centre of the region | VG-03 and HL-H6 compact placement (48 dp icon at the top third, no circle). §4 C7's "use the empty space honestly" is answered by the actions | `apps/mobile/lib/design_system/components/k_states.dart` (`KEmptyState`: `embedded`, `actionVariant`, `actionIcon`, `secondaryActionLabel`), `apps/mobile/lib/app/shell/feed_region.dart` (`FeedRegion`) |

### 7.2 Home, after

**Screenshots.** All are production behaviour unless marked:
- `A/production/home.popular-unavailable`, `home.following-unavailable`,
  `home.new-unavailable`;
- the Home actions' result is local API data: `A/local-api/live.via-home-watch-live` (393) and
  `live.via-home-see-who-is-live`.

**What works now**
- **A way forward.** Each tab now has a real primary action. "Watch live streams" (Popular, New)
  and "See who's live" (Following) open the Live tab on the matching segment, through the real
  `/live` route. This was verified in the captures: Popular lands on Live Popular, and Following
  lands on Live Following with the 2 followed hosts.
- **Copy.** Warm and honest, with no phase numbers. Each body ends with a pointer to live, which
  matches the button.
- **Composition.** The composed block (disc, title, body, button) sits at the optical centre. The
  screen no longer reads as a line of text in a void.
- **Header.** Only the three tabs; the selected tab hierarchy is unchanged and clear.
- **RTL.** The button icon sits at the start (right) with the label after it. Mirroring is
  correct.

**Remaining weaknesses**
- **Following icon (RG-19).** Home Following and Live Following still share `group_outlined`.
- **Red saturation (RG-18).** A red-tinted icon, a red filled button and the red Create pill sit
  in one screen.
- **Arabic text weight (RG-12).** Unchanged: the Arabic body is visibly lighter than the English.
- **Search (RG-16).** Hidden, so Home has no discovery entry other than Live.

### 7.3 Live discovery, after

**Screenshots**

| Kind | Files |
| ---- | ----- |
| Production behaviour | `A/production/live.unavailable-{popular,following,new}` |
| Local API data | `A/local-api/live.populated-{popular,following,new}`, `live.category-selected`, `live.scrolled-end`, `live.empty-popular`, `live.empty-new-via-see-new`, `live.empty-following`, `live.error-api-down` |
| Simulated | `live.loading` (held requests), `live.offline-simulated`, `live.error-proxy-502` |
| Test fixture | `fixtures-after/live.*` (adds `live.offline`) |

**What works now**
- **Category on cards (RG-05 fixed).** Each card names its topic ("# Local test: Music" /
  "# محلي: موسيقى") when it has one. Rooms without a category show no empty slot.
- **Offline state (RG-01 partly fixed).** A dedicated offline state: wifi-off icon,
  "You're offline", Try again. It covers both a dropped network
  (`A/local-api/live.offline-simulated`) and an unreachable API
  (`A/local-api/live.error-api-down`).
- **Hosting unavailable:**
  - the chip row is gone (RG-08 fixed for this state);
  - "Try again" re-checks the server switch;
  - the copy explains that live streaming "isn't open yet".
- **Empty states with real routes:**
  - Popular: Try again + "See new streams", which switches to New;
  - Following: "See popular" + Try again.
- **Cards:** the LIVE badge (owner decision) makes the grid read as live at a glance, even
  without covers.

**Remaining weaknesses**
1. **RG-04 still reproduces.** Latin titles on an Arabic UI:
   - "…Learning Arabic calligraphy," (ar 393), "…Learning Arabic calligrap" (ar 360);
   - the new category line uses the same `Text` pattern, so it is exposed too.
2. **Badge stack (RG-10, denser).** Every card starts with two badges, red LIVE + white New.
   - With 0 viewers everywhere, every card in view shows the same badge pair.
   - On the New tab, "New" repeats the tab name on every card.
3. **RG-09 not fixed.** The New-tab unavailable icon is still `new_releases_outlined`, now red on
   a disc, so it looks like an alert.
4. **RG-08, rest.** On Popular, loading, empty, offline and error still show the chip row. In
   offline and error that is a lone "All". The Popular state block sits about 12 dp lower than
   on Following/New.
5. **Empty-state action order (RG-17).**
   - "Try again" is the red primary button on an empty list, which is not a failure.
   - On the New tab the body invites the user to "Explore new streams" while they are already
     there.
6. **Red saturation (RG-18).** In one viewport: red disc icons in states; red primary buttons;
   the red selected chip; red LIVE badges ×6–8; the red Create pill. The calmer-chrome direction
   (HL-N1 §2) is weakened.
7. **Unchanged:**
   - RG-03: no covers (cards are still grey tiles with a letter);
   - RG-06: title truncation;
   - RG-07: space under a short Following list;
   - RG-11: Popular ≡ New;
   - RG-13: skeleton contrast;
   - RG-02: cards not tappable.

**Typography, spacing, density, image ratio (after)**
- **Grid geometry:** unchanged: 3:4, 8/4 dp.
- **Card bottom block:** now three lines (name 15/600, title 12, `#` category 12), all white
  on the scrim. That is readable, but on a no-cover card the text block plus the two-badge top
  row leave the large letter avatar as the only focal point.
- **State blocks:** an 88 dp disc, 18/600 title, 15 body and a filled button, vertically
  centred. They are consistent across Home and Live.

**RTL / LTR (after)**
- Mirroring is correct throughout. The badge row starts at the right (مباشر, then جديد), and the
  `#` glyph sits at the start of the category line.
- The only defect is RG-04 (mixed-script `Text` direction).

### 7.4 Gap status after KL-047

| ID | Status | Note |
| -- | ------ | ---- |
| RG-01 | Partially fixed | Offline state added; no banner, no auto-retry on reconnect (no connectivity listener in `lib/`) |
| RG-02 | Open | Slice 2 |
| RG-03 | Open | Upload API |
| RG-04 | **Still reproduces** | §7.3 item 1 |
| RG-05 | **Fixed** | `#` category line |
| RG-06 | Open | |
| RG-07 | Partially fixed | Centred states with actions; short lists still leave a void |
| RG-08 | Partially fixed | Fixed for unavailable only |
| RG-09 | **Not fixed** | |
| RG-10 | Open, denser | LIVE + New |
| RG-11 | Open | API (D38) |
| RG-12 | Open | |
| RG-13 | Open | |
| RG-14 | Superseded | 88 dp disc is the house style now (§7.1) |
| RG-15 | Open (info) | |
| RG-16 | New | Search hidden |
| RG-17 | New | Empty-state action order and copy |
| RG-18 | New | Red saturation |
| RG-19 | New | Shared Following icon (was part of C8) |

### 7.5 Prioritized changes after KL-047

These replace §4 for planning. Paths are under `apps/mobile/`.

| # | Pri | Gap | Change | Files / widgets | Acceptance criterion |
| - | --- | --- | ------ | --------------- | -------------------- |
| N1 | P0 | RG-04 | Lay out the card's name, title and category by their own content direction (first-strong detection or bidi isolates); align by content | `lib/features/live/presentation/widgets/live_cover_card.dart` (`KLiveCoverCard`, the name, title and category `Text`s) | In `ar`, "Learning Arabic calligraphy, lesson 3" renders LTR with a trailing "…" and the comma in place. In `en`, Arabic titles render RTL. Golden ar/en × 393/360 plus a widget test; re-capture `A/local-api/live.populated-popular.ar.393` has no leading "…" |
| N2 | P0 | RG-10 | One top badge cluster per card. Keep LIVE (owner decision) and hide "New" when viewer counts are unavailable (all 0), or merge them as "LIVE · New". Never show "New" on the New tab | `live_cover_card.dart`, `lib/design_system/components/k_badge.dart` (`KBadge.live`, `KBadge.newRoom`), `lib/features/live/live_screen.dart` (pass the tab context) | On the New tab no card shows "New/جديد". On any tab a card shows at most one red element at its top. Widget test per tab; golden |
| N3 | P1 | RG-09, RG-19 | Replace `new_releases_outlined` with a neutral "recent" glyph, and give Home Following and Live Following different icons | `live_screen.dart` (`LiveHubBody` `unavailableIcon`), `lib/features/home/home_screen.dart` (`HomeFeedBody` `unavailableIcon`) | No warning-like glyph in any state; the Home Following and Live Following icons differ (golden diff) |
| N4 | P1 | RG-17 | Empty, not failed: make the primary action navigational ("See new streams" / "See popular") and demote "Try again" to secondary. Don't invite the user to "explore new streams" on the New tab | `live_screen.dart` (`FeedRegionCopy` empty action fields), `lib/l10n/app_{en,ar}.arb` (`liveHubEmptyBody`) | On Live empty Popular, the filled button navigates and Try again is ghost. On New the body does not reference New. Widget test plus A5 copy sign-off |
| N5 | P1 | RG-01 | Offline banner under the header plus auto-retry on reconnect; keep the last grid under the banner | `lib/app/shell/feed_region.dart` (`FeedRegion`), `lib/features/live/application/live_rooms_provider.dart`, a connectivity source (new dependency; CTO approval) | With the network lost, the banner shows in ar/en. On reconnect the tab reloads without a tap. A previously loaded grid stays visible. Widget test with a fake connectivity stream |
| N6 | P1 | RG-08 | Hide the chip row whenever the region is not showing rooms (loading without categories, empty, offline, error), or reserve the same header height on all tabs | `live_screen.dart` (`LiveHubBody.header`, `_chips`) | In `A/local-api/live.offline-simulated` and `live.error-proxy-502` no lone "All" chip shows. The state disc's centre y is equal (±1 dp) across the three tabs for the same state |
| N7 | P1 | RG-18 | Reduce red to one accent per region: state icons in `textSecondary` on the disc (red only for error), and LIVE badges as small solid tags (no larger than today) | `lib/design_system/components/k_states.dart` (`KEmptyState.iconColor`), `lib/app/shell/feed_region.dart`, `k_badge.dart` | In `A/production/home.popular-unavailable` the only red elements are the button, the nav dot and the Create pill. A5 visual sign-off |
| N8 | P1 | RG-03 | No-cover card: a deterministic token-palette tint per host and a smaller avatar (see §4 C2) | `live_cover_card.dart` (`_CoverFallback`), `lib/design_system/tokens/component_metrics.dart` | Adjacent cards are distinguishable without covers; the avatar is ≤ 56 dp; text contrast is ≥ 4.5:1 on every tint |
| N9 | P2 | RG-12 | Arabic secondary text balance | `lib/design_system/tokens/tokens.dart`, `lib/design_system/theme/app_theme.dart`, `lib/design_system/components/k_tabs.dart` (`_Tab`) | Equal perceived weight in ar/en captures (A5 sign-off); no overflow at text scale 2.0 |
| N10 | P2 | RG-13 | Skeleton contrast | `lib/design_system/components/k_skeleton.dart`, `KLiveCoverCardSkeleton` | Skeleton-to-background luminance contrast ≥ 1.3:1 |
| N11 | P2 | RG-06 | 2-line title on no-cover cards | `live_cover_card.dart` | "Morning coffee and questions" fully visible at 360 on a no-cover card |
| N12 | P2 | RG-07 | Under a short list (< 4 rooms), offer "See popular" below the end caption | `lib/app/shell/feed_region.dart` (`_EndOfList`), `live_screen.dart` | Live Following with 2 rooms shows the link; widget test |
| — | — | RG-16 | Search returns when the search API exists (KL-047 decision) | `feed_tabs_scaffold.dart` (`searchAvailable`) | Flag flipped only together with a working Discover search |
| — | — | RG-02 | Card tap: slice 2 (KL-034) | `live_screen.dart` (`onOpenRoom`), `live_cover_card.dart` (`_CardFrame`) | Per VG-44 |

### 7.6 Not reproducible in the after set

See [README §8.5](review/2026-10-16-home-live/README.md#85-states-not-captured-in-the-after-set).
- **Paging footers:** with 8 rooms there is no second page.
- **Not exercisable here:** pull-to-refresh and swipe.
- **No such API data:** PK, multi-guest, viewer counts and covers.
- **No feed API:** Home loading, empty and error.
- **Not implemented:** the offline banner and auto-retry.

Reference comparison remains **pending — no authorized references supplied** (§6). No
similarity to any other app is claimed.
