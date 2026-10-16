# Kabso Live — Live-Streaming Pattern Gap Analysis (KL-031)

Status: **Design correction sprint (D34/D35), documentation only (A5).** Nothing here claims to
be implemented.

**How this was written**

- **Input:** the KL-030 headless captures in
  [`audit/2026-10-16-before/`](audit/2026-10-16-before/) (cited by file name below), the approved
  goldens, `design-tokens.json` v1.1, and the code in `apps/mobile/lib`.
- **What "intended" means:** the "intended" column describes **common live-streaming
  patterns**, the conventions shared by the genre the owner points to (BIGO LIVE and similar).
  It keeps **Kabso's own** branding, assets, iconography and typography.
- **No measurements from the reference app:**
  - There are **no reference screenshots**.
  - No BIGO measurement, colour or layout coordinate is used or implied.
  - Every number below is a Kabso proposal (tokens or `KMetrics`), not a copied value.
  - Nothing here claims fidelity to the reference app.
- **D35:** no discovery or live API exists, and contracts are frozen during the sprint. So
  **production** Home and Live render the new structure with honest states. **Populated**
  layouts are fixture-only (goldens and the debug gallery).

Columns:
- **ID**: VG-xx.
- **Current**: what the capture shows, with the cited file.
- **Intended**: the pattern-based behaviour, in Kabso's identity.
- **Where**: the files to change, relative to `apps/mobile/lib/`.
- **Pri**:
  - P0 = Home or Live room;
  - P1 = needed with the Phase 6/7 APIs or as secondary polish;
  - P2 = later.
- **Acceptance**: testable; **[G]** marks a golden-checkable criterion.
- **Backend**:
  - *no*: buildable now;
  - *yes*: populated state needs an API, so it is fixture-only until then.

Layout decisions referenced as **HL-x** are in
[`HOME_LIVE_LAYOUT_DECISIONS.md`](HOME_LIVE_LAYOUT_DECISIONS.md).

---

## 1. Composition and information density

| ID | Current (capture) | Intended | Where | Pri | Acceptance | Backend |
| -- | ----------------- | -------- | ----- | --- | ---------- | ------- |
| VG-01 | Home is a title bar plus one centred empty state; about 85 % of the screen is empty background (`home.en.png`, `home.ar.png`, `home-light.*`) | Home is a **live-discovery hub**. It shows its structure even with no data: top tabs, a category row and a grid region. The grid region holds the honest state. The first viewport of a populated Home shows ≥ 2.3 rows of 2 cards (HL-H1…H5) | `features/home/home_screen.dart` (replace the `ComingSoonTab` use), new `features/home/presentation/` | P0 | [G] `home.unavailable` shows the tabs, chip row and unavailable block at 393×852 and 360×800 in ar and en. [G] `home.populated` (fixture) at 393×852 with device insets (59 / 34) shows ≥ 4 full cards plus the start of a 3rd row | no (structure); yes (data) |
| VG-02 | Live tab duplicates the same empty pattern (`live.*`) | When Home is the live hub, the Live tab is redundant. Repurpose or remove it (route decision, HL-N1) | `app/router/routes.dart`, `app/router/app_router.dart`, `app/shell/app_shell.dart`, `features/live/live_screen.dart` | P0 (decision) | Owner decision recorded; router test updated; no dead tab | no |
| VG-03 | Every tab uses the same 88 dp circle icon, headline and paragraph, so screens are indistinguishable (`home`, `discover`, `create`, `live`) | Unavailable and empty states are **compact and in-place** within the structure: a 48 dp icon, a one-line title and a ≤ 2-line body, positioned at the top third of the grid region, not centred on the whole screen | `design_system/components/k_states.dart` (add a `compact` variant), `app/shell/coming_soon_tab.dart` | P0 | [G] compact state height ≤ 160 dp; placed below the tabs, not vertically centred | no |
| VG-04 | Profile is a large avatar, name and one big outlined card, with no stats or actions (`profile.*`) | Pattern: a header row (avatar with live ring when live, name, ID line), a stats row (following / followers / likes, shown only when the data exists), a primary action, then content tabs. **Phase 2 data**, so only the structure is spec'd now | `features/profile/profile_screen.dart` | P1 | No fake zero counts (D35); the structure golden uses fixtures | yes (Phase 2) |

## 2. Top navigation and category hierarchy

| ID | Current | Intended | Where | Pri | Acceptance | Backend |
| -- | ------- | -------- | ----- | --- | ---------- | ------- |
| VG-05 | The Home top bar is only the wordmark; there are no actions (`home.*`) | The top bar holds the **primary segment tabs** (Following · Popular · New, HL-H2) at the start and a **search** action at the end, which goes to Discover (an existing route). The wordmark moves to Splash and Login only (decision HL-H1) | `features/home/…`, `design_system/components/k_tabs.dart` | P0 | [G] top bar height 48 dp, with tabs and search only. The search tap navigates to `/discover` (widget test) | no |
| VG-06 | No second-level categories anywhere | A horizontal **category chip row** under the tabs, shown on Popular only. It is server-defined; until the API exists it shows "All" only, with no invented categories | new `design_system/components/k_chip.dart` | P0 | [G] chip row h 48 (32 visual) scrolls from start; with no API it shows exactly one selected "All" chip | yes (categories) |
| VG-07 | `KTabs` has a single style (underline, 13/600) (`gallery-1.*` "Scrollable tabs") | Two levels: **primary tabs** are `title` 18/600 when selected and `bodyStrong` 15 `textSecondary` otherwise, with a short 16×3 dp indicator. **Secondary** level uses chips (VG-06). The same underline style must not be used for both levels | `design_system/components/k_tabs.dart` | P0 | [G] primary and secondary levels are visually distinct in one capture | no |
| VG-08 | Discover is an empty placeholder (`discover.*`) | Discover becomes search plus (later) trending. Out of scope for this sprint beyond the HL-N1 decision | `features/discover/discover_screen.dart` | P2 | — | yes |

## 3. Live card layout and aspect ratios

| ID | Current | Intended | Where | Pri | Acceptance | Backend |
| -- | ------- | -------- | ----- | --- | ---------- | ------- |
| VG-09 | Cards are 3:4 (`liveCardAspect` 0.75), but the gallery grid uses large gutters (`component-cover_cards.*`) | Keep 0.75. Tighter **grid**: side padding `sm` 8, column and row gap `xs` 4, so content dominates (density pattern) | Home grid (new), `features/live/presentation/widgets/live_cover_card.dart` | P0 | [G] at 393 wide each card is 186.5 × 248.7 dp (±1); at 360 it is 170 × 226.7 | no |
| VG-10 | Each card has a red top accent line **and** a LIVE badge **and** a viewer pill (`component-cover_cards.en.phone.png`) | In a live-only grid every card is live, so the **LIVE badge and accent line are redundant**. Remove the accent line everywhere; hide the LIVE badge in live grids (keep it where live and non-live mix: profile, search, avatars) | `live_cover_card.dart` (`showLiveBadge` param, default false in grids) | P0 | [G] grid card shows no LIVE badge and no accent line; profile and search contexts still show the badge (widget test) | no |
| VG-11 | A "0" viewer count is shown (`component-cover_cards.*`, card 4; `gallery-1.*`) | Below 1 viewer, show a "New" / "جديد" chip instead of 0 | `live_cover_card.dart`, `design_system/components/k_badge.dart` | P0 | Widget test: 0 → "New"; 1 → "1" | no |
| VG-12 | Bottom of the card shows host name (bodyStrong) and title (caption); long names ellipsize (card 3) | Keep the two lines. Add the room **mode tag** at top-end (PK, multi-guest), and optionally a region/language tag when the API provides it. Never show tags without data | `live_cover_card.dart`, `live_view_data.dart` | P0 (PK, multi-guest) / P1 (region) | [G] PK and multi-guest variants; no empty tag slot | yes (fields) |
| VG-13 | "Cover couldn't load" shows a large icon and text on every broken card (card 4) | Use a quiet fallback: the host avatar (lg) centred on `surfaceRaised`, with no error text. A broken cover is not an error the user can act on | `live_cover_card.dart` (`_CoverUnavailable`) | P1 | [G] broken-cover card shows the avatar fallback and no text | no |
| VG-14 | No featured or banner strip | Reserve a **featured strip** slot above the grid, rendered only when a featured API returns items (HL-H4). No placeholder banner | Home (slot) | P1 | No slot rendered when the data is empty (widget test) | yes |

## 4. Avatars, viewer counts, room labels, status indicators

| ID | Current | Intended | Where | Pri | Acceptance | Backend |
| -- | ------- | -------- | ----- | --- | ---------- | ------- |
| VG-15 | Avatar rings exist (`gallery-1.*`) but no screen uses them; the Profile avatar is a plain grey circle (`profile.*`) | The live ring and "LIVE" tab are used wherever a user appears while live: the following-live rail (HL-H4), profile and chat-name taps. The story ring arrives in Phase 4 | `design_system/components/k_avatar.dart` | P1 | [G] following-live rail fixture shows rings | yes |
| VG-16 | The PK badge uses a red gradient (`gallery-1.*`, `component-cover_cards.*`) | Solid `live.badge`-family fill. Gradients are reserved for the avatar live ring only (anti-pattern: excessive gradients) | `design_system/components/k_badge.dart` | P0 | [G] PK badge is solid; contrast ≥ 4.5:1 for the text | no |
| VG-17 | The viewer pill in the room is small (about 12 sp) next to a 48 dp close circle; visual weight is unbalanced (`component-room_viewer.en.phone.png`) | The top-end cluster is: viewer avatar strip (on ≥ 430 dp screens, existing QA-009 rule), count chip and close. The close icon is 20 dp in a 32 dp visual scrim circle with a 48 dp hit area, aligned to the host-pill height | `features/live/presentation/widgets/live_room_scaffold.dart` (`KViewerStrip`, close) | P0 | [G] close visual 32 dp; hit test 48 dp (widget test) | no |
| VG-18 | No status indicators for connection or host state | Add room status chips: weak connection, reconnecting, camera off, host left (HL-L9) | `live_room_scaffold.dart` (status slot) | P0 | [G] one golden per state | no (fixture) |

## 5. Bottom nav and active states

| ID | Current | Intended | Where | Pri | Acceptance | Backend |
| -- | ------- | -------- | ----- | --- | ---------- | ------- |
| VG-19 | 5 items (Home, Discover, Create, Live, Profile); the centre is a red pill "+" with no label; the selected item uses `primaryText` (`home.*`, `live.*`) | Destinations per decision HL-N1 (proposed: Home(live) · Discover · Create · Inbox · Profile). Keep the label-less centre action, with a semantics label. The selected item shows a filled icon and a `textPrimary` label with a `primary` dot or indicator. Red text on the nav is reduced to the indicator only, for calmer chrome | `app/shell/app_shell.dart`, `app/router/*` | P0 (decision) | Router tests; [G] nav in ar and en; centre action semantics "Create" | no |
| VG-20 | The Create tab opens a full placeholder page (`create.*`) | Pattern: the centre action opens a **create sheet** (Go live, Post, Story, Video). Each row is enabled only when its phase ships; until then the sheet lists them disabled with phase badges (honest) | `features/create/create_screen.dart`, new sheet | P1 | [G] sheet with disabled rows; no navigation to an empty page | no |
| VG-21 | Nav bar has `surface` plus a 1 dp divider, and is hidden on no screen (room components are gallery-only) | Nav is hidden on full-screen live surfaces (room, PK) | `app/router/app_router.dart` (root-navigator routes) | P1 (with the room route) | Widget test: no `KBottomNav` in the room route | yes (room route, Phase 6) |

## 6. Hierarchy, typography, spacing, iconography

| ID | Current | Intended | Where | Pri | Acceptance | Backend |
| -- | ------- | -------- | ----- | --- | ---------- | ------- |
| VG-22 | Screen titles are generic 18–24 sp app-bar titles on every tab (`discover`, `create`, `live`, `settings`) | Home has no title; the tabs are the header. Secondary screens keep `title` 18. Remove redundant titles that repeat the nav label | Tabs | P0 (Home) | [G] Home has no AppBar title | no |
| VG-23 | Chat text is about 15 sp body with bold names, so lines are tall and few fit (`component-room_viewer.*`) | Denser chat: a **13/400 text, 13/600 name** style (token proposal T-1), line padding `xs`/`sm`, max 6 visible lines (existing `KMetrics.chatMaxVisibleLines`) | `live_chat_overlay.dart`, tokens | P0 | [G] 6 lines fit within the 30 % chat height cap at 393×852 and 360×800 | no |
| VG-24 | Icons are Material outline glyphs (gift, share, close) | Keep the single outline set (DESIGN_SYSTEM §6). Room icons are 24 dp on 40 dp scrim circles. No copied iconography from the reference app | `live_room_scaffold.dart` | P1 | Visual review | no |
| VG-25 | Profile and empty states use oversized rounded outlined containers (radius 16, full-width card) (`profile.*`) | Anti-pattern: generic dashboard cards. Use flat sections separated by spacing or dividers; cards only for media | `features/profile/profile_screen.dart`, `k_states.dart` | P1 | [G] no outlined container wrapping text-only content | no |

## 7. Live room: video area, chat overlay, host info, action controls

| ID | Current | Intended | Where | Pri | Acceptance | Backend |
| -- | ------- | -------- | ----- | --- | ---------- | ------- |
| VG-26 | The video is full-bleed with no legibility gradients; the overlay pills carry all the contrast (`component-room_viewer.*`) | Add a top gradient (black 0→45 %, 120 dp) and a bottom gradient (0→55 %, 280 dp) under the overlays, in addition to the pills. This keeps text legible on bright video | `live_room_scaffold.dart` | P0 | [G] on a white fixture frame, overlay text contrast ≥ 4.5:1 (existing `chatScrim` rule) | no |
| VG-27 | The host pill shows avatar, name and a red Follow chip; there is no secondary info (`component-room_viewer.*`) | Two-line pill: name (13/600, 1 line) and a secondary line (11–12 sp: e.g. follower count or room ID, **when the API provides it**). Follow collapses to a "+" icon chip and disappears after following (220 ms fade) | `live_room_scaffold.dart` (`KHostPill`) | P0 | [G] states: not following / following / no secondary data; the name keeps ≥ 8 visible characters at 360 dp | yes (secondary line) |
| VG-28 | There is no room info row under the header | A room info row (start, under the host pill): room title or topic chip, and a ranking or "top supporters" entry **only when data exists**. No decorative chips | `live_room_scaffold.dart` (new slot) | P1 | No slot without data (widget test) | yes |
| VG-29 | Chat bubbles stack at bottom-start; join lines ("رنا joined") are part of the history (`component-room_viewer.*`) | Join and entry notices become a **transient entry banner** (one at a time, 2 s, above the chat) instead of chat history. The chat keeps user, gift and system lines | `live_chat_overlay.dart` | P0 | Widget test: a join event shows the banner and does not add a chat line; reduce-motion means no slide | no |
| VG-30 | The mixed-script gift line in ar renders "3× Star Viewer B أرسل" (`gallery-2.ar.png`) | Wrap names, gift names and the ×N segment in bidi isolates; ×N always sits at the line end in reading order | `live_chat_overlay.dart` | P0 | [G] ar gift line reads "أرسل ⁨Viewer B⁩ ⁨Star⁩ ×3" in order | no |
| VG-31 | The action bar is a "Say something…" pill plus share plus gift (`component-room_viewer.*`) | Same three actions in v1 (all have documented integrations: chat send, share deep link (B7), gifts (Phase 7/8)). Add "more (⋯)" **only** when the report endpoint exists. No decorative buttons | `live_room_scaffold.dart` (`KRoomActionBar`) | P0 | Every button has a callback or is hidden (widget test asserts no null-callback icons in production builds) | yes (actions) |
| VG-32 | Chat width is 75 % with no reserved column | Keep 75 %. The end side stays free for the gift combo banners and the future vertical actions | `KMetrics.chatWidthFactor` | P0 | [G] chat never overlaps the end 25 % | no |

## 8. Gift selector and effects

| ID | Current | Intended | Where | Pri | Acceptance | Backend |
| -- | ------- | -------- | ----- | --- | ---------- | ------- |
| VG-33 | The gift panel dims the whole video with a scrim (`component-room_gifts.*`) | The sheet opens **without dimming the video** (a transparent barrier that still closes on tap). The stream stays visible, which is the common pattern while gifting | `gift_panel.dart`, the caller's `showModalBottomSheet` barrier | P0 | [G] the video area above the sheet is unchanged pixel-wise vs `room_viewer` (masked chat) | no |
| VG-34 | The panel is a 4×2 grid with a title and close; there are no category tabs, balance, or quantity choice; "Diamond c…" truncates (`component-gift_panel.*`) | Header: gift category tabs (server-defined; hidden until the API exists) and, at the end, a balance with top-up (**hidden until the wallet, Phase 8 / B5**). Grid: 4 columns, 2-line names allowed. Footer: quantity chips (1 / 10 / 99, product decision) and Send | `gift_panel.dart` | P1 | [G] long gift names wrap to 2 lines with no ellipsis at 360 dp; no balance UI without the wallet | yes |
| VG-35 | The combo counter exists only in the panel footer; there are no on-video combo banners in the room captures | Combo banners stack at the start side, above the chat, with a max of 3 (DESIGN_SYSTEM §7.3) | `live_chat_overlay.dart` / new `gift_banner.dart` (reuse `KGiftComboCounter`) | P0 | [G] 1, 2 and 3 stacked banners; a 4th merges | no (fixture) |
| VG-36 | No full-screen effect layer | Effect layer z-order per HL-L6 (above chat, below header and action bar, `IgnorePointer`) | `live_room_scaffold.dart` (`overlay` slot exists) | P1 | Widget test: taps on the action bar still work during an effect | yes (assets, Phase 7) |

## 9. PK layout

| ID | Current | Intended | Where | Pri | Acceptance | Backend |
| -- | ------- | -------- | ----- | --- | ---------- | ------- |
| VG-37 | PK is a thin score bar under the header over **one** full-screen video, with a timer chip below (`component-room_pk.*`) | Common PK pattern: a **split screen**, with two video panes side by side in the upper half (host at start, opponent at end), the score bar attached to the panes, the timer centred on the seam, and a Kabso-original VS mark. Each side has a supporter avatar row. Chat and actions use the lower part of the screen (HL-L8) | `pk_score_bar.dart` (reuse), new `pk_layout.dart`, `live_room_scaffold.dart` (PK mode) | P0 | [G] PK fixture shows 2 panes (each 196.5 dp wide at 393), the bar directly under the panes, and the chat starting below the supporter rows; ar mirrors the panes | no (fixture) |
| VG-38 | The timer is a small chip "0:09 left"; the final-10 s emphasis exists in code (`KMetrics.pkUrgentThreshold`) | Timer on the seam, tabular figures; urgent state uses an `error` tint plus pulse (static under reduce-motion) | `pk_score_bar.dart` | P0 | [G] 2:00 and 0:09 states | no |
| VG-39 | The result shows only a gold "Win" chip under the bar (`gallery-2.*`) | Per-pane result overlay (Win / Lose / Draw) on each pane, kept for 3 s, then a "next round / end" state | `pk_layout.dart` | P1 | [G] win/lose/draw fixtures | yes |

## 10. Transitions, gestures, overlays, modals

| ID | Current | Intended | Where | Pri | Acceptance | Backend |
| -- | ------- | -------- | ----- | --- | ---------- | ------- |
| VG-40 | No room-to-room gesture; the room exists only in the gallery | Vertical swipe between rooms (pager); overlays fade during the drag; no gift animation mid-drag | room route (Phase 6) | P1 | Widget test with the fixture pager | yes |
| VG-41 | No pull-to-refresh or infinite scroll on Home (no list) | Pull-to-refresh plus cursor pagination per HL-H5 | Home | P0 (structure) | Widget test with a fake repository in tests only | yes |
| VG-42 | Tab switch is an indicator fade (D33) | Home tabs: swipe between tab pages (reading direction) plus the indicator fade | `k_tabs.dart`, Home | P1 | Widget test: horizontal drag changes the tab, mirrored in RTL | no |
| VG-43 | Modals are standard bottom sheets with a heavy scrim | Room-context sheets (gifts, viewers, more) are non-dimming (VG-33). App-context sheets keep the scrim | sheets | P1 | — | no |
| VG-44 | Card tap has an ink ripple only | Card press: scale 0.98 for `durationFast`, then a push transition into the room (cover → video cross-fade). Reduce-motion means an instant switch | `live_cover_card.dart`, room route | P1 | Reduce-motion widget test | yes (room) |

---

## 11. What cannot be judged without reference screenshots

Each item below stays a **Kabso proposal** until the owner supplies authorized references
(REFERENCE_INVENTORY §5). Even then, the references inform the pattern, not pixel values:

1. Card proportions, grid gutters and how many rows sit above the fold in the reference.
2. Header composition: which top tabs and categories exist, their order, and whether a wordmark
   or search sits in the header.
3. Exact overlay positions and sizes in the room (host pill, viewer cluster, chat height and
   width, action bar).
4. Chat density: font size, line spacing, bubble or no-bubble treatment, how entry notices
   appear.
5. Gift panel structure: tabs, quantity selection, balance placement, panel height.
6. PK split proportions, where the score bar and timer sit, and supporter rows.
7. The bottom-nav destinations and what the centre action does.
8. Motion: timing and choreography of gift combos, PK countdowns, room swipes, card-to-room
   transitions.
9. How the reference localizes into Arabic (RTL mirroring of the PK sides, chat alignment).
10. Visual weight: colour saturation, translucency levels, iconography style. These stay Kabso
    by design, but whether our weight "feels" similar can only be checked side by side.
