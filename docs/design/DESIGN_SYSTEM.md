# Kabso Live — Design System (spec v1)

Status: **Specification for Phase 1 implementation (KL-004).** Nothing here is implemented
until the Flutter work package says so. Token names and values come from
[`../contracts/design-tokens.json`](../contracts/design-tokens.json) (authoritative). Where this
spec needs a value the JSON does not have, it is listed in **§12 Token change proposals** and an
interim rule is given — the engineer never invents a hex value.

Notation: `color.dark.surface` = token path in the JSON. In Flutter, tokens live in
`lib/design_system/tokens` and components in `lib/design_system/components` (prefix `K`, e.g.
`KButton`). "start"/"end" are directional (right/left in Arabic, left/right in English).

---

## 1. Principles

| # | Principle | What it means in practice |
| - | --------- | ------------------------- |
| 1 | **Arabic first, never Arabic later** | Every layout is designed in RTL first and checked in LTR. Directional APIs only (`EdgeInsetsDirectional`, `AlignmentDirectional`, `start/end`). No hard-coded `left/right`. |
| 2 | **Content is the hero** | Dark, quiet chrome; media, faces and live video carry the colour. Brand red is a signal, not a wallpaper. |
| 3 | **One loud thing per screen** | At most one filled primary button per view. Gold and the live gradient are reserved meanings (§2.3). |
| 4 | **Honest states** | Every screen specifies loading, empty, error, offline and permission states. Never show fake counts, fake users or placeholder data as if real. Unbuilt features say "coming in Phase N". |
| 5 | **Smooth over spectacular** | Video, live and scroll must hold 60 fps on mid-range Android. Decorative motion yields to playback (§6.3). |
| 6 | **Accessible by default** | WCAG 2.2 AA targets: 4.5:1 body text, 3:1 large text and UI boundaries, 48 dp targets, screen-reader labels, reduce-motion, text scaling to 200 % on non-overlay screens. |
| 7 | **Original** | No copied logos, icon glyphs, layouts or assets from other platforms. Patterns (tabs, stories ring, vertical feed) are generic; our execution is our own. |

---

## 2. Colour

### 2.1 Semantic roles (implement as a `KColors` theme extension, one instance per mode)

| Role | Dark token | Light token | Use |
| ---- | ---------- | ----------- | --- |
| `background` | `color.dark.background` #0B0B0D | `color.light.background` #FFFFFF | Scaffold, full-bleed screens |
| `surface` | `color.dark.surface` #16161A | `color.light.surface` #F6F6F8 | Cards, list groups, text-field fill |
| `surfaceRaised` | `color.dark.surfaceRaised` #1F1F25 | `color.light.surfaceRaised` #FFFFFF | Bottom sheets, menus, BottomNav, TopBar on scroll |
| `surfaceOverlay` | `color.dark.surfaceOverlay` #2A2A32 | `color.light.surfaceOverlay` #ECECF0 | Dialogs, snackbars, pressed rows on raised, skeleton base |
| `border` | `color.dark.border` #34343D | `color.light.border` #DCDCE2 | Dividers, decorative card outlines only (**not** input outlines — see §2.4) |
| `textPrimary` | #FFFFFF | #0B0B0D | Titles, body |
| `textSecondary` | #B4B4BE | #4A4A55 | Meta, helper text, inactive tab labels |
| `textTertiary` | #7A7A86 | #7A7A86 | **Restricted** — see §2.4 (fails AA on most surfaces) |
| `primary` | `color.dark.primary` #E50914 | `color.light.primary` #C8080F | Filled primary button fill, selected tab indicator, toggle-on track |
| `onPrimary` | #FFFFFF | #FFFFFF | Text/icons on `primary` |
| `primaryText` (interim) | `color.brand.red400` #FF3B47 | `color.light.primary` #C8080F | Red **text/links/icons** on dark/light surfaces (dark `primary` fails 4.5:1 as text) |
| `primaryPressed` | `color.brand.red600` #B80710 | `color.brand.red700` #8A050C | Filled button pressed fill |
| `success` / `warning` / `error` / `info` | dark tokens | light tokens | Status text, icons, field errors (light values restricted — §2.4) |
| `scrim` | `color.dark.scrim` (70 % black) | `color.light.scrim` (60 % black) | Behind sheets/dialogs, and under text on media |
| `focusRing` (interim) | `color.brand.red400` | `color.light.primary` | 2 dp keyboard/switch-access focus outline |
| `gold` | `color.brand.gold` #F5C451 | dark only, see §2.4 | Coins, gifts, VIP/top-gifter, earnings |
| `liveBadge` | `color.live.badge` | same | LIVE badge fill |
| `pkLeft` / `pkRight` | `color.live.pkLeft` / `pkRight` | same | PK team bars and score fills (team "start"/"end", §6.2) |
| `liveGradient` | `color.brand.gradientLive` | same | Live ring, Go-Live button, live tile accent |

Default theme: **Dark**. Settings offers Dark / Light / System (Phase 1). Live, Reels, Story
viewer and Broadcaster are **always dark** regardless of theme (video-first surfaces).

### 2.2 Light mode notes

Light `surfaceRaised` (#FFFFFF) sits on `surface` (#F6F6F8); separate them with a 1 dp `border`
or the light elevation shadow (§5). Status colours on light need the replacements in §12 before
being used as text.

### 2.3 Brand red vs. gold vs. live gradient — when to use which

| Colour | Means | Allowed | Never |
| ------ | ----- | ------- | ----- |
| **Brand red** (`primary`, `primaryText`) | "Act here / you are here" | One filled primary CTA per view; selected tab/segment indicator; toggle on; links; unread dot; notification badge count | Error messages (use `error` + icon); large background areas; body text |
| **Gold** (`gold`) | "Value / money / prestige" | Coin amounts & icon, gift prices, top-gifter rank 1–3, VIP marks, creator earnings | CTAs, errors, links, anything not monetary or status-of-rank |
| **Live gradient** (`liveGradient`) | "Live right now" | Avatar live ring, "Go live" button, live tile 2 dp top accent, PK "VS" emblem | Static/non-live UI; stories (story ring uses solid `primary`, §9.4); decorative headers |
| **LIVE badge red** (`liveBadge`) | "This is live" | LIVE badge only | Anything else |
| `error` (#FF5A5F dark) | "Something failed / destructive" | Field errors, error icons, destructive text buttons | Primary CTA |

Destructive actions (logout, revoke session, delete) use a **text/outlined button in `error`
colour** plus a confirmation Dialog — never the filled brand-red primary, so "red = go" and
"red = danger" do not collide.

### 2.4 Contrast audit (computed from token values, WCAG 2.x relative luminance)

Thresholds: body/small text ≥ 4.5:1; large text (≥ 24 px regular or ≥ 18.66 px bold) ≥ 3:1;
UI component boundaries & meaningful icons ≥ 3:1. **FAIL** = below 4.5:1 for body text.

**Dark mode — text on surfaces**

| Foreground | background | surface | surfaceRaised | surfaceOverlay | Verdict |
| ---------- | ---------- | ------- | ------------- | -------------- | ------- |
| textPrimary #FFFFFF | 19.66 | 18.04 | 16.39 | 14.23 | Pass |
| textSecondary #B4B4BE | 9.56 | 8.78 | 7.97 | 6.92 | Pass |
| textTertiary #7A7A86 | 4.64 | **4.26** | **3.87** | **3.36** | **FAIL except on background** |
| primary #E50914 (as text) | **4.10** | **3.76** | **3.42** | **2.97** | **FAIL as text** → use `primaryText` |
| red400 #FF3B47 (`primaryText`) | 5.59 | 5.13 | 4.66 | **4.04** | Pass, except on surfaceOverlay |
| error #FF5A5F | 6.44 | 5.91 | 5.37 | 4.66 | Pass |
| success #2ECC71 | 9.36 | 8.59 | 7.80 | 6.77 | Pass |
| warning #F5A623 | 9.70 | 8.90 | 8.09 | 7.02 | Pass |
| info #4DA3FF | 7.49 | 6.87 | 6.24 | 5.42 | Pass |
| gold #F5C451 | 12.08 | — | — | — | Pass |
| border #34343D (non-text, needs 3:1) | **1.60** | **1.46** | — | — | **FAIL as input boundary** (OK for decorative dividers) |

**Light mode — text on surfaces**

| Foreground | background | surface | surfaceRaised | surfaceOverlay | Verdict |
| ---------- | ---------- | ------- | ------------- | -------------- | ------- |
| textPrimary #0B0B0D | 19.66 | 18.22 | 19.66 | 16.69 | Pass |
| textSecondary #4A4A55 | 8.74 | 8.10 | 8.74 | 7.42 | Pass |
| textTertiary #7A7A86 | **4.24** | **3.93** | **4.24** | **3.60** | **FAIL everywhere** |
| primary #C8080F | 6.00 | 5.56 | 6.00 | 5.10 | Pass |
| error #D92D36 | 4.80 | **4.44** | 4.80 | **4.07** | **FAIL on surface/overlay** |
| success #1E9E57 | **3.45** | **3.20** | **3.45** | **2.93** | **FAIL as text** |
| warning #C77D00 | **3.30** | **3.06** | **3.30** | **2.80** | **FAIL as text** |
| info #1F6FD1 | 4.94 | 4.58 | 4.94 | **4.19** | FAIL on overlay only |
| gold #F5C451 | **1.63** | — | — | — | **FAIL — unusable on light** |
| border #DCDCE2 (non-text) | **1.37** | **1.27** | — | — | **FAIL as input boundary** |

**Fills with text on them**

| Pair | Ratio | Verdict / rule |
| ---- | ----- | -------------- |
| #FFFFFF on dark `primary` / red500 (button) | 4.79 | Pass (just) — label must be ≥ `label` 13/600; never thinner/smaller |
| #FFFFFF on light `primary` #C8080F | 6.00 | Pass |
| #FFFFFF on red600 (pressed) / red700 | 6.83 / 9.96 | Pass |
| #FFFFFF on red400 | **3.52** | FAIL for small text — red400 is never a fill behind text |
| #FFFFFF on gold | **1.63** | FAIL → text on gold fill is #0B0B0D (12.08) |
| #FFFFFF on pkLeft / pkRight | **3.45 / 3.32** | Large-text only: PK scores must be ≥ 20 px / 700. Small labels on PK fills use #0B0B0D (5.70 / 5.92) |
| #FFFFFF on dark success / warning / info / error fills | 2.10 / 2.03 / 2.63 / 3.05 | FAIL → status pills use #0B0B0D text (≥ 6.44) or tinted background + coloured text |
| #FFFFFF on dark `scrim` over a pure-white video frame | 8.45 | Pass |
| #FFFFFF on light `scrim` (60 %) over white frame | 5.74 | Pass |
| #FFFFFF on 50 % / 40 % black over white frame | 3.95 / 2.85 | FAIL → overlay text on media needs ≥ 60 % black under it |

**Rules that follow (binding until §12 is resolved):**

1. `textTertiary` is allowed only for: (a) dark mode on `background`; (b) placeholder text whose
   field also has a visible label; (c) disabled content. Timestamps/meta use `textSecondary`.
2. Red text/links/icons on dark use `primaryText` (red400) and never sit on `surfaceOverlay`.
3. Light-mode `success`/`warning` are icon/fill colours only; status text next to them uses
   `textPrimary`. Light `error` text appears only on `background`/`surfaceRaised` (inputs on
   `surface` render their error message below the field, on the page background).
4. Text-field outlines, toggle-off tracks, checkbox outlines use `textTertiary` as boundary in
   dark (4.26–4.64 ≥ 3:1) and `textSecondary` in light (≥ 7.4) until `borderStrong` exists.
5. Gold is dark-mode only as a foreground. In light mode, coin/gift values use `textPrimary` text
   with a gold **icon on a #0B0B0D 20 dp disc** (icon is decorative, value text carries meaning).
6. Any text over photos/video sits on a `scrim`-strength gradient (≥ 60 % black at the text's
   location). Captions/usernames on Reels/Live/Stories always get this gradient.

---

## 3. Typography

### 3.1 Families

| Script | Family | Weights bundled | Notes |
| ------ | ------ | --------------- | ----- |
| Arabic | `Readex Pro` (OFL-1.1; tokens v1.2, D47) | 400, 500, 600, 700 | Used whenever the app locale is `ar`, with Inter as `fontFamilyFallback`. The bundled files merge the Arabic, Latin and Latin Extended subsets, so Latin digits and hashtags in Arabic text use the same face |
| Latin | `Inter` (OFL-1.1) | 400, 600, 700 | Used when locale is `en`, with Readex Pro as fallback for Arabic runs (user names, captions) |

Both bundled as assets (no runtime download). Mixed-script strings (Arabic caption with an
English hashtag) render correctly through the fallback chain — do not split into spans manually.

### 3.2 Scale (from `typography.scale`)

| Style | Size / weight / height | Use |
| ----- | ---------------------- | --- |
| `display` | 32 / 700 / 1.2 | Splash wordmark, end-of-live summary numbers |
| `headline` | 24 / 700 / 1.25 | Screen titles on auth screens, profile display name |
| `title` | 18 / 600 / 1.3 | TopBar title, sheet titles, section headers |
| `body` | 15 / 400 / 1.45 | Body copy, list primary text, inputs |
| `bodyStrong` | 15 / 600 / 1.45 | Usernames in lists, emphasised body |
| `label` | 13 / 600 / 1.3 | Buttons, chips, tabs, badges |
| `caption` | 12 / 400 / 1.35 | Meta (timestamps, counts), helper/error text, BottomNav labels |

Rules:

- **Arabic line height**: Arabic marks are tall (measured on IBM Plex Sans Arabic, kept for Readex Pro); with the token heights, `label` 1.3
  and `title` 1.3 can clip diacritics in single-line boxes. Never constrain text boxes to an
  exact height; size containers from padding + text. See §12 proposal (`arabicHeightDelta`).
- **No letter-spacing on Arabic** (breaks joining). Latin `label` may use +0.1 px. No italics in
  Arabic; emphasis = weight 600.
- No ALL CAPS in either locale except the Latin "LIVE" / "PK" badge text.
- Minimum rendered size 12 px. Text scaling: support `TextScaler` up to 2.0 on standard screens;
  overlays on video (Live, Reels, Stories) clamp to 1.3 to keep video visible.
- Numbers in counters use tabular figures (`FontFeature.tabularFigures()`) so viewer counts and
  timers don't jitter.

### 3.3 Numerals policy — **Western Arabic digits (0–9) in both locales**

| Decision | Rationale |
| -------- | --------- |
| Counts, prices, coins, timers, dates use **0–9** in `ar` and `en` | (1) Target markets (Gulf, Levant, Egypt, Maghreb) see 0–9 daily in social apps, banking and store prices; Maghreb locales use them natively. (2) Store prices (IAP `localizedPrice`) and usernames already arrive in Latin digits — one system avoids mixing `١٢` and `12` on one screen. (3) Usernames/handles may contain digits and must match what users type. (4) Tabular alignment and compact formats are simpler and tested once. |
| Implementation | Do **not** rely on `intl` locale defaults for `ar` (digit system differs by `ar` sub-locale and CLDR version). Use a single `KNumberFormat` that formats with Latin digits and takes suffix words from ARB. Unit-test it. |
| Exception | None in Phase 1. If market research later demands Eastern digits, it is one formatter switch — do not scatter `NumberFormat` calls. |

Compact counter formatting (`KNumberFormat.compact`), used by Counter (§9.18):

| Value | en | ar | Rule |
| ----- | -- | -- | ---- |
| 0–9,999 | `0`, `987`, `9,999` | `0`, `987`, `9,999` | Exact, grouping with `,` |
| 10,000–999,999 | `12.3K`, `999.9K` | `12.3 ألف`, `999.9 ألف` | One decimal, **truncate (floor)**, drop trailing `.0` (`120K`) |
| 1,000,000–999,999,999 | `1.2M` | `1.2 مليون` | as above |
| ≥ 1,000,000,000 | `1.2B` | `1.2 مليار` | as above |

- Arabic suffix separated by U+00A0 (no-break space). Never overstate: floor, not round.
- Coins and money are **never** compacted (wallet, gift prices, earnings show exact `12,500`).
- Screen-reader label always gets the full number ("12,345 likes" / "12,345 إعجابًا").
- Relative time: `now`/`الآن`, `5m`/`5 د`, `3h`/`3 س`, `2d`/`2 ي`, `3w`/`3 أ`, then date
  `15 Oct` / `15 أكتوبر` (Gregorian month names; Arabic uses the standard Arabic month names).

### 3.4 Bidi rules

- Wrap user-generated strings that may be in the other script (usernames, display names,
  captions inside a sentence) in Unicode isolates (FSI U+2068 … PDI U+2069) via a `bidiIsolate()`
  helper, e.g. `"تابعك ⁨@sara.k⁩"`.
- `@username` is always LTR-isolated; email fields and password fields are `TextDirection.ltr`
  input regardless of locale, with text aligned to `start` of the locale.
- Numbers + units in Arabic follow the number: `5 د`, `12.3 ألف`.

---

## 4. Spacing, grid, radius

### 4.1 Spacing (4 dp base, `spacing.*`)

| Token | dp | Typical use |
| ----- | -- | ----------- |
| `xxs` | 2 | Grid gutters on media grids, badge inner offset |
| `xs` | 4 | Icon-to-label inside chips, between stacked caption lines |
| `sm` | 8 | Gap between related controls, avatar-to-text in compact rows |
| `md` | 12 | ListTile vertical padding, card inner padding (compact), avatar-to-text in ListTile |
| `lg` | 16 | **Screen side gutter** (start & end), card inner padding, field-to-field gap |
| `xl` | 24 | Section-to-section gap, sheet top padding, auth form top margin |
| `xxl` | 32 | Above primary CTA on auth screens, empty-state block margins |
| `xxxl` | 48 | Splash/empty-state vertical breathing room |

### 4.2 Layout grid

| Context | Spec |
| ------- | ---- |
| Phone (< 600 dp) | 4-column fluid, side gutter `lg` 16, column gap `lg` 16 |
| Tablet (≥ 600 dp) | Content max width 600 dp, centred; Live/Reels stay full-bleed |
| Media grid (profile posts, reels grid) | 3 columns, gap `xxs` 2, square (posts) or 9:16 (videos) cells, no side gutter |
| Live tiles (Live tab) | 2 columns, gap `sm` 8, side gutter `lg`, tile 3:4 |
| Safe areas | Always respect top/bottom insets; BottomNav sits above the bottom inset |

### 4.3 Radius (`radius.*`)

| Element | Token |
| ------- | ----- |
| Badge, small tags | `xs` 4 |
| TextField, Snackbar, tiles in grids (live/video) | `sm` 8 |
| Button, IconButton (filled container), Card (list) | `md` 12 |
| Post card, Dialog | `lg` 16 |
| BottomSheet top corners | `xl` 24 |
| Chip, Toggle, Counter pills, Avatar | `pill` 999 |

---

## 5. Elevation via surfaces

Dark mode uses **no shadows**; depth = lighter surface. Light mode adds one soft shadow on
level 2+.

| Level | Surface token | Light-mode shadow | Used by |
| ----- | ------------- | ----------------- | ------- |
| 0 | `background` | none | Scaffold |
| 1 | `surface` | none (1 dp `border` if adjacent to background needs separation) | Cards, grouped lists, fields |
| 2 | `surfaceRaised` | 0 2 8 rgba(0,0,0,.08) | BottomNav, TopBar (scrolled), BottomSheet, menus |
| 3 | `surfaceOverlay` | 0 8 24 rgba(0,0,0,.12) | Dialog, Snackbar, tooltips |
| Scrim | `scrim` | — | Behind modal sheets & dialogs; under overlay text on media |

Pressed state on a level-N surface = overlay of `textPrimary` at 8 % (dark) / 6 % (light),
not a surface swap. Use a single `KStateLayer` helper.

---

## 6. Iconography

### 6.1 Set

- One **outline** icon set for the whole app; selected/active state uses the **filled**
  counterpart of the same glyph (BottomNav, like, save). Recommendation: Material Symbols
  *Outlined* / *Filled* (Apache-2.0, ships with Flutter tooling); alternative Phosphor (MIT).
  Final package choice is the Flutter owner's (pubspec). Access icons only through a
  `KIcons` registry so the set can be swapped.
- Sizes: 20 dp (inline with `label`/`caption`), 24 dp (default), 28 dp (BottomNav, video
  overlay actions). Stroke weight consistent across the set (one optical weight).
- Icons that carry meaning have a semantic label; decorative ones are excluded from semantics.
- Brand assets (logo, app icon) are blocked on B8; use the text wordmark "Kabso Live".

### 6.2 RTL mirroring rules

Use `Icon(..., textDirection)` / `matchTextDirection: true` only for the "Flip" list.

| Flip in RTL | Never flip |
| ----------- | ---------- |
| Back / forward arrows, chevrons in list rows (`chevron_end`) | Play, pause, stop, record, skip, rewind/fast-forward (media timeline is LTR worldwide) |
| Send (paper-plane points toward `end`) | Clocks, timers, history/refresh circular arrows |
| Reply / forward (message) | Logos, wordmark, third-party brand marks |
| Undo / redo (swap) | Checkmarks, close (×), plus, search magnifier |
| Text alignment, indent, list bullets | Volume/speaker, microphone, camera, flash, gift, coin, heart, star |
| "Open in new"/external, logout/login arrows, exit door | Video progress/scrubber direction, volume/brightness sliders |
| Comment bubble tail, quote marks | Numbers, charts' time axis (stays LTR) |

Special cases:

- **Story progress segments** advance in reading direction (start → end): right-to-left in
  Arabic. Tap zones flip: tap `end` side = next, `start` side = previous.
- **Swipe**: horizontal "next story/user" follows reading direction (swipe toward start =
  next). Vertical Reels feed is unaffected.
- **PK bar**: the host is always on the `start` side with `pkLeft` colour, opponent on `end`
  with `pkRight`; the bar mirrors with layout so "my side" is where the eye starts.
- **Media scrubber**: timeline stays LTR (0:00 at the left) in both locales.

---

## 7. Motion

### 7.1 Tokens

| Token | Value | Use |
| ----- | ----- | --- |
| `motion.durationFastMs` | 120 | Pressed/ripple feedback, toggle thumb, icon fill swap, tab label colour |
| `motion.durationBaseMs` | 220 | Page push/pop, BottomSheet open, snackbar in, tab indicator slide, field error reveal |
| `motion.durationSlowMs` | 360 | Large layout transitions, dialog with content morph, end-of-live summary reveal |
| `motion.curveStandard` | easeOutCubic (`Curves.easeOutCubic`) | Everything entering/moving. Exits use the same duration with `Curves.easeInCubic` (interim, §12) |

Page transitions slide along the reading direction (push from `end` side). Shell tab switches
cross-fade (`durationFastMs`), no slide.

### 7.2 Reduce motion (`motion.respectReduceMotion: true`)

Read `MediaQuery.disableAnimations` (iOS Reduce Motion / Android "Remove animations").

| Normal | Reduce motion |
| ------ | ------------- |
| Slides, scale, parallax | Cross-fade at `durationFastMs`, or instant |
| Skeleton shimmer | Static `surfaceOverlay` blocks (no shimmer) |
| Like burst, confetti, gift full-screen animations | Static badge/banner "{user} sent {gift}" for 2 s |
| Live ring rotating gradient | Static gradient ring |
| Auto-advancing story/reel previews | Still allowed (content), but no decorative transitions between them |
| Counter roll-up | Instant value change |

### 7.3 Gift / effects performance budget (Phase 7, fixed now)

| Budget | Rule |
| ------ | ---- |
| Concurrency | Max **1** full-screen gift animation at a time (queue, FIFO, highest coin value may jump queue); max **3** stacked gift banners (combo pills) on the `start` side; extra banners merge into "×N" combos |
| Duration | Standard gift ≤ 3 s, premium ≤ 6 s; queue drops (shows banner only) any item waiting > 10 s |
| Assets | Vector (Lottie/Rive) preferred; ≤ 500 KB per gift, ≤ 30 fps authored, preloaded when the gift sheet catalogue loads; no runtime video decode for gifts on low-end devices |
| Rendering | Gift layer in its own `RepaintBoundary` above the video `Texture`; never rebuild the video widget; no `Opacity`/`BackdropFilter` over the full video (use pre-multiplied asset alpha) |
| Frame budget | If the raster thread exceeds 16 ms for > 10 frames in 1 s, degrade: skip full-screen animations, banners only, for 30 s |
| Low-power / reduce motion | Banners only |
| Scroll surfaces | No gift/like animations play while a feed is actively scrolling; autoplay only for the settled item |

---

## 8. Accessibility checklist (applies to every component)

- Touch target ≥ `size.minTouchTarget` 48 dp even when the visual is smaller (pad the hit area).
- Every interactive element has a `Semantics` label in both languages; state is announced
  (selected, expanded, disabled, loading, error).
- Focus order follows reading order (RTL aware). Visible focus = 2 dp `focusRing`, 2 dp offset,
  radius = component radius + 2.
- Colour is never the only signal: errors have icon + text, LIVE has text, selected tabs have
  filled icon + indicator.
- Live regions: snackbars, field errors, username availability, and loading → loaded swaps
  announce politely (`SemanticsService.announce` / `liveRegion: true`).
- Captions/subtitles for reels when available (Phase 5); live chat readable by screen readers
  with throttled announcements (Phase 6).

---

## 9. Component specs

Common state definitions (used by every table below):

| State | Visual rule |
| ----- | ----------- |
| Default | As specified per component |
| Pressed | State layer `textPrimary` 8 % dark / 6 % light over the container, `durationFastMs`; filled primary swaps to `primaryPressed` |
| Focused | 2 dp `focusRing` outline, 2 dp offset |
| Disabled | Content + container at 38 % opacity; no state layer; still in semantics with "disabled"; not focusable |
| Loading | Content replaced by 20 dp circular indicator in the content colour; width locked to pre-loading width; taps ignored; semantics "loading" |
| Error | `error` colour boundary/icon + message in `caption` below or inside, announced |

### 9.1 Button — `KButton`

Anatomy: container · optional leading icon (20 dp, `sm` 8 gap to label) · label (`label`, max 1 line, ellipsis) · optional trailing icon.

| Variant | Container | Content | Use |
| ------- | --------- | ------- | --- |
| `primary` | `primary` fill | `onPrimary` | The one main action per view |
| `secondary` | `surfaceOverlay` fill | `textPrimary` | Secondary actions ("Resend email") |
| `outline` | transparent, 1 dp boundary `textTertiary` (dark) / `textSecondary` (light) | `textPrimary` | Tertiary actions on dense screens |
| `text` | none | `primaryText` | Links, "Forgot password?" |
| `destructive` | transparent or `outline` | `error` | Logout, revoke, delete (always with Dialog) |
| `live` | `liveGradient` (start → end) | #FFFFFF, 700 weight | "Go live" only |

| Size | Height | Horizontal padding | Radius |
| ---- | ------ | ------------------ | ------ |
| `large` (default) | `size.buttonHeight` 52 | `xl` 24 | `md` |
| `medium` | 40 (hit area 48) | `lg` 16 | `md` |
| `small` | 32 (hit area 48) | `md` 12 | `pill` |

Full-width on auth/forms (`lg` gutters). States: all six common states; `error` is not a
button state — failures surface through the form/snackbar. Loading keeps the button
`primary`-coloured (not 38 %).

### 9.2 IconButton — `KIconButton`

Anatomy: 48 dp hit area · 24 dp icon · optional container (40 dp circle `surfaceOverlay`, or
`scrim` 40 % over media) · optional Badge (§9.5) at top-end.

| Variant | Use |
| ------- | --- |
| `plain` | TopBar actions, list trailing actions |
| `filled` | Floating actions on media (close, flip camera) — container `scrim` |
| `toggle` | Like/save/mute — outline ↔ filled glyph, filled colour `primaryText` (like) or `textPrimary` (save) |

States: common six; loading shows 20 dp indicator in place of icon. Tooltip/semantics label
mandatory (icon-only).

### 9.3 TextField — `KTextField`

Anatomy (top → bottom): label (`label`, `textSecondary`, always visible above field — no
floating label, for Arabic legibility) · field container (height 52, `surface` fill, radius
`sm`, 1 dp boundary) with optional leading icon/prefix (e.g. `@`), input text (`body`),
optional trailing (clear, visibility toggle, status icon) · helper/error line (`caption`) ·
optional counter at `end`.

| State | Boundary | Helper line |
| ----- | -------- | ----------- |
| Default | `textTertiary` (dark) / `textSecondary` (light) 1 dp | helper in `textSecondary` |
| Focused | 2 dp `focusRing` (replaces boundary), caret `primaryText` | helper |
| Filled | as default | helper |
| Disabled | 38 % | helper 38 % |
| Loading (async validation) | default + trailing 16 dp indicator | "Checking…" copy |
| Error | 2 dp `error` + trailing error icon | error message `error` colour, announced |
| Success (async validation) | default + trailing check icon `success` | success copy in `textSecondary` (light) / `success` (dark) |
| Read-only | no fill, no boundary, text `textSecondary` | — |

Variants: `text`, `email` (LTR input, email keyboard, no autocorrect), `password` (LTR,
obscured, trailing show/hide IconButton), `username` (LTR, `@` prefix, lowercase transform,
no autocorrect/suggestions), `multiline` (bio, min 3 lines). Placeholder text is optional
and never the only label. Autofill hints set for email/username/password/newPassword.

### 9.4 Avatar — `KAvatar` (+ rings)

Anatomy: circular image (cover) · fallback initials on `surfaceOverlay` (`label`/`title`,
first grapheme of display name; Arabic letters render unjoined-isolated form — acceptable) ·
optional ring · optional status/badge slot at bottom-end.

| Size | Token | Ring stroke | Gap ring→image |
| ---- | ----- | ----------- | -------------- |
| `sm` | `size.avatarSm` 32 | 2 | 2 |
| `md` | `size.avatarMd` 48 | 2 | 2 |
| `lg` | `size.avatarLg` 88 | 3 | 3 |
| `story` | `size.storyRing` 68 outer (image 58) | 3 | 2 |

| Ring | Look | Semantics suffix |
| ---- | ---- | ---------------- |
| none | — | — |
| `storyUnseen` | solid `primary` ring | "has new story" / "لديه قصة جديدة" |
| `storySeen` | 1.5 dp `border` ring | "story viewed" / "تمت مشاهدة القصة" |
| `live` | `liveGradient` ring (sweep), + LIVE badge overlapping bottom centre | "live now" / "يبث مباشرة الآن" |
| `closeFriends` (later) | reserved, `success` | — |

Live overrides story. States: loading = Skeleton circle; error (image fails) = initials
fallback silently; pressed = 8 % layer; focused = focus ring outside the story ring.

### 9.5 Badge — `KBadge`

| Variant | Visual | Text | Size |
| ------- | ------ | ---- | ---- |
| `live` | `liveBadge` fill, radius `xs`, #FFFFFF `label` 700 (ratio 4.79) | "LIVE" (en) / "مباشر" (ar) | h 20, padding `xs`/`sm` |
| `liveWithViewers` | `live` + `scrim` pill with eye icon + compact count | "LIVE · 1.2K" | h 20 |
| `verified` | 16/20 dp filled check-seal glyph, `info` colour; placed after name at `end` with `xs` gap | none; semantics "verified" / "موثّق" | inline |
| `pk` | `liveGradient` fill, #FFFFFF `label` 700 | "PK" (both locales) | h 20 |
| `count` | `primary` fill, `onPrimary` `caption` 600, min 16 dp circle, "99+" cap | number | min 16 |
| `dot` | 8 dp `primary` | — (semantics on parent: "unread") | 8 |
| `phase` | `surfaceOverlay` fill, `textSecondary` `caption` | "Phase 3" / "المرحلة 3" | h 20 |

Badges are not interactive (no pressed/focused). Disabled = 38 %. Loading/error N/A.

### 9.6 BottomNav — `KBottomNav` (5-tab shell)

Anatomy: container `surfaceRaised`, height `size.bottomNavHeight` 64 + bottom inset, top 1 dp
`border` · 5 equal slots (start → end): **Home · Discover · Create · Live · Profile**.

| Slot | Icon (outline → filled when selected) | Label en / ar |
| ---- | ------------------------------------- | ------------- |
| Home | house | Home / الرئيسية |
| Discover | compass | Discover / استكشاف |
| Create (centre, emphasized) | plus in a 44×32 `primary` pill, radius `md`, `onPrimary` icon; no selected state change except 8 % layer | Create / إنشاء |
| Live | broadcast/antenna | Live / مباشر |
| Profile | person (or user's `sm` avatar once avatars exist, Phase 2) | Profile / حسابي |

| State | Rule |
| ----- | ---- |
| Default (unselected) | Outline icon 28 dp + `caption` label, `textSecondary` |
| Selected | Filled icon + label `textPrimary`; 3×16 dp `primary` indicator bar above icon; animation `durationFastMs` |
| Pressed | 8 % circular layer behind icon |
| Focused | focus ring around slot |
| Disabled | Not used (tabs are always reachable; unbuilt tabs show phase empty states) |
| Badge | `dot`/`count` at icon top-end (Phase 9 notifications) |

Order mirrors in RTL automatically (Home at the right in Arabic); Create stays centre.
Re-tapping the selected tab scrolls to top / pops to tab root. Hidden on full-screen surfaces
(Live room, Reels player, Story viewer, Camera).

### 9.7 TopBar — `KTopBar`

Anatomy: height 56 + top inset · leading slot (back IconButton — flips — or wordmark on Home)
· title (`title`, start-aligned; centred only on modal screens) · up to 3 trailing actions.

| Variant | Use |
| ------- | --- |
| `standard` | `background` fill; becomes `surfaceRaised` + bottom `border` after 4 dp scroll |
| `large` | Title in `headline` below the bar (auth screens, Settings root) |
| `transparent` | Over media; icons in `filled` IconButtons on `scrim` |
| `modal` | Close (×) at start, title centred, text action at end ("Save") |

States: action buttons follow IconButton states; title never interactive.

### 9.8 Tabs — `KTabs`

Anatomy: row of tab labels (`label`) · 2 dp `primary` indicator under selected · bottom 1 dp
`border`. Variants: `fixed` (2–4 equal tabs), `scrollable` (start-aligned, `lg` padding),
`icon` (profile grid: posts/reels/tagged — icon only + semantics label). Selected =
`textPrimary`, unselected = `textSecondary`. Indicator slides `durationBaseMs`; follows RTL
order. Swipe between tab pages follows reading direction. States: pressed, focused,
disabled (38 %, e.g. "Tagged — Phase 3"). Min tab width 72 dp, hit height 48.

### 9.9 Chip — `KChip`

Anatomy: pill container h 32 (hit 48) · optional leading icon 16 · `label` · optional trailing
close. Variants: `filter` (selectable; selected = `primary` fill + `onPrimary` text; unselected
= `surfaceOverlay` + `textPrimary`), `input` (removable tag, trailing ×), `suggestion`
(outline). States: common six; loading N/A; error = `error` 1 dp boundary (invalid tag).

### 9.10 Card

| Card | Anatomy | Notes |
| ---- | ------- | ----- |
| **Post card** (Phase 3) | Header row (avatar `sm` + name/@username + verified + time + overflow IconButton) · media (1:1 / 4:5, carousel dots below) · action row (like, comment, share at start; save at end) · like Counter · caption (2 lines + "more") · "View all N comments" · padding `lg` horizontal, media full-bleed | No card container in feed (flat on `background`, `xl` between posts). Double-tap like burst (reduce-motion: none). |
| **Live room tile** (Phase 6) | 3:4 cover/stream thumbnail, radius `sm` · top-start `liveWithViewers` badge · top-end `pk` badge when in PK · bottom gradient scrim with host name (`bodyStrong`) + title (`caption`, 1 line) · 2 dp `liveGradient` top accent | Tile announces "{host}, live, {n} viewers, {title}" |
| **Video tile** (Phase 5) | 9:16 thumbnail, radius `sm` (0 in profile grid) · bottom-start play glyph + view Counter on scrim · processing overlay ("Processing…" + indeterminate bar) for own uploads | Play glyph never flips |

States for all cards: default; pressed (8 % layer over whole card); focused (ring); loading =
Skeleton of same anatomy; error = media failed → `surfaceOverlay` block with broken-image icon
+ "Tap to retry"; unavailable (deleted/blocked) = row "This content isn't available" in
`textSecondary`.

### 9.11 BottomSheet — `KBottomSheet` (+ Gift sheet)

Base anatomy: `scrim` behind · container `surfaceRaised`, top radius `xl` · drag handle 32×4
`border` centred, `sm` from top · optional title row (`title`, close at end) · content ·
optional sticky footer with primary button. Open/close `durationBaseMs`; dismiss by drag,
scrim tap, back gesture. Max height 90 %. Keyboard pushes content (sheet resizes).

**Gift sheet (Phase 7)** — always dark:

| Region | Spec |
| ------ | ---- |
| Header | Tabs (`scrollable`): Popular · Lucky · VIP · … (server-defined) ; coin balance at `end`: coin icon (`gold`) + exact balance (`bodyStrong`, `gold`) + "Top up" text button |
| Grid | 4 columns, gap `sm`; cell = gift art 48 dp + name (`caption`, 1 line) + price (coin icon + exact number, `gold` `caption`) |
| Selected cell | 1.5 dp `gold` outline + `surfaceOverlay` fill; shows quantity stepper (1, 10, 66, 99 presets as Chips) |
| Recipient | Multi-guest/PK: avatar row of recipients above grid (Avatar `sm`, selected = `primary` ring) |
| Footer | Primary "Send" / "إرسال" button (`large`), shows total cost |
| States | Loading (Skeleton grid), empty (no gifts configured), insufficient balance (Send replaced by "Top up to send" secondary button + `warning` caption), sending (button loading, double-tap guarded, idempotency key per tap), error (snackbar with code copy; balance re-fetched), offline (Send disabled + offline banner) |

### 9.12 Dialog — `KDialog`

Anatomy: `scrim` · container `surfaceOverlay`, radius `lg`, width min(320, screen − 2×`xl`),
padding `xl` · optional icon (24) · title (`title`) · body (`body`, `textSecondary`) · actions
row at `end`: secondary (text) then primary/destructive. Stacked vertically if labels don't
fit. Enter: fade + scale 0.96 → 1 `durationBaseMs` (reduce motion: fade only). Focus trapped;
initial focus on the least-destructive action. Variants: `confirm`, `destructive` (primary
action uses `destructive` button), `info` (single OK).

### 9.13 Toast / Snackbar — `KSnackbar`

Anatomy: container `surfaceOverlay`, radius `sm`, margin `lg`, padding `md`/`lg` · optional
leading status icon (`success`/`error`/`info`) · message (`body`, max 2 lines) · optional
action (text button, `primaryText`). Position: above BottomNav / above keyboard. Duration 4 s
(no action) / 7 s (with action); never auto-dismiss errors that need an action (use inline
error instead). One at a time, newest replaces. Announced as polite live region. States:
pressed/focused on action only.

### 9.14 Skeleton — `KSkeleton`

Blocks in `surfaceOverlay` (dark) / `surfaceOverlay` (light) matching the final layout's
shapes (circles for avatars, `xs`-radius bars at text line heights, 60 %/40 % widths for
second lines). Shimmer: highlight `surfaceRaised` sweep along reading direction, 1200 ms loop;
reduce motion → static. Show only after 300 ms of loading (avoid flash); minimum visible
300 ms once shown. Semantics: single "Loading" / "جارٍ التحميل" for the region.

### 9.15 EmptyState — `KEmptyState`

Anatomy (centred column, max width 320, `xxxl` vertical padding): icon 48 dp `textSecondary`
in 88 dp `surface` circle · title (`title`) · body (`body`, `textSecondary`, centred) ·
optional primary or secondary button (`medium`) · optional `phase` Badge above title for
"coming in Phase N". Variants: `noContent`, `noResults`, `comingSoon(phase)`,
`permission` (camera/mic/photos with "Open settings" button).

### 9.16 ErrorState — `KErrorState`

Same anatomy as EmptyState with icon in `error` tint; title + body from the error-code copy
table (`PHASE1_SCREENS.md` §10); "Try again" secondary button; for `INTERNAL_ERROR` a
selectable `caption` line "Error ID: {requestId}". Variants:

| Variant | Trigger | Action |
| ------- | ------- | ------ |
| `offline` | `NETWORK_OFFLINE` | "Try again"; auto-retry when connectivity returns |
| `timeout` | `NETWORK_TIMEOUT` | "Try again" |
| `server` | `INTERNAL_ERROR`, `SERVICE_UNAVAILABLE` | "Try again" + Error ID |
| `notFound` | `NOT_FOUND` | "Go back" |
| `forbidden` | `AUTH_FORBIDDEN` | "Go back" |
| `restricted` | private account / blocked (Phase 2) | none, or "Follow" when applicable |
| `rateLimited` | `RATE_LIMITED` | Button disabled with countdown from `Retry-After` |

Inline variant (inside lists, e.g. failed "load more"): one row, `caption` message + "Retry"
text button.

### 9.17 ProgressBar — `KProgressBar` (incl. story segments)

| Variant | Spec |
| ------- | ---- |
| `linear` | 4 dp track `surfaceOverlay`, fill `primary`, radius pill; determinate or indeterminate (1.2 s loop; reduce motion → pulsing opacity) |
| `circular` | 20/32 dp stroke 2.5/3 in content colour |
| `storySegments` | N segments in a row, top of viewer under status bar inset + `sm`; gap `xxs`; height 2 dp; track #FFFFFF 35 %; fill #FFFFFF; filled segments = viewed; current animates linearly over story duration (image 5 s default, video = length, max 60 s); fill direction = reading direction; paused on long-press / app background / sheet open; on a `scrim` gradient for contrast |

Semantics: `linear` exposes value %; story segments expose "Story 2 of 5" / "القصة 2 من 5".

### 9.18 Counter — `KCounter`

Anatomy: optional icon (20) · value via `KNumberFormat.compact` (§3.3), tabular figures ·
optional label. Variants: `inline` (`caption` "1.2K likes"), `stat` (profile: value
`title` over label `caption`, centred; tappable → list), `overlay` (on video: `scrim` pill
h 24, #FFFFFF), `viewers` (eye icon + value, inside live badge). Value change animates
(vertical roll `durationFastMs`; reduce motion: instant). Semantics always full number +
noun with correct Arabic plural form (ARB `plural` with zero/one/two/few/many/other).
States: loading = Skeleton bar 32×12; error = "—" with no semantics value; disabled N/A.

### 9.19 Toggle — `KToggle`

Track 52×32 pill; thumb 24 (28 pressed). Off: track `surfaceOverlay` + 1 dp boundary
(`textTertiary` dark / `textSecondary` light), thumb `textSecondary`. On: track `primary`,
thumb #FFFFFF. Thumb travels start → end when switching on (mirrors in RTL). Hit area is the
whole ListTile when inside one. States: pressed (thumb grows), focused (ring), disabled
(38 %), loading (thumb shows 16 dp indicator, interaction blocked — for server-synced
settings), error (reverts to previous value + snackbar). Semantics: switch, on/off.

### 9.20 ListTile — `KListTile`

Anatomy: min height 56 (one line) / 72 (two lines); padding `md` vertical, `lg` horizontal ·
leading (24 icon, or Avatar `md`) with `md` gap · title (`body`/`bodyStrong`) + subtitle
(`caption` `textSecondary`, max 2 lines) · trailing (chevron that flips, Toggle, value text
`textSecondary`, Badge, or button). Variants: `navigation` (chevron), `toggle`, `value`,
`user` (avatar + name + @username + action button), `destructive` (title in `error`, no
chevron). Grouped lists sit on `surface` with radius `md` and `border` dividers inset to text
start. States: pressed (8 % layer, full width), focused (ring inset), disabled (38 %),
loading (trailing indicator), error (subtitle replaced by error message in `error` + retry).

---

## 10. Content & voice

| Rule | Example |
| ---- | ------- |
| Arabic: Modern Standard Arabic, warm and short; address the user in masculine-neutral imperative (standard UI convention) | "سجّل الدخول للمتابعة" |
| English: sentence case, no exclamation marks in errors | "Log in to continue" |
| Errors say what happened + what to do; never blame | "You're offline. Check your connection and try again." |
| Never confirm whether an email/username exists in login/forgot flows | see PHASE1_SCREENS §5 |
| Buttons are verbs | "Send link", not "OK" |
| All strings in ARB with `@description`; placeholders named (`{username}`), plurals via ICU | — |

---

## 11. Implementation handoff checklist (Flutter)

| Item | Where |
| ---- | ----- |
| `KColors`, `KSpacing`, `KRadius`, `KTypography`, `KMotion`, `KSizes` generated/hand-mapped 1:1 from `design-tokens.json` | `lib/design_system/tokens` |
| Interim roles from §2.1 (`primaryText`, `primaryPressed`, `focusRing`) defined **as references to existing tokens**, not new hex | same |
| `ThemeData` dark + light built only from tokens; component themes for buttons, inputs, nav | `lib/design_system/theme` |
| Components §9 with a widget gallery/golden tests in ar + en, dark + light, text scale 1.0 and 2.0 | `lib/design_system/components`, `test/` |
| `KNumberFormat` (compact + exact + relative time) with unit tests for every row in §3.3 | `lib/core/...` |
| `KIcons` registry with `flipsInRtl` flag per icon | `lib/design_system` |

---

## 12. Token change proposals (not applied — for CTO decision)

The JSON is unchanged. Each proposal includes computed ratios; interim rules above keep the
app compliant without them.

| # | Proposal | Value | Reason (computed) |
| - | -------- | ----- | ----------------- |
| P1 | Change `color.dark.textTertiary` | #7A7A86 → **#92929E** | Current 4.26 / 3.87 / 3.36 on surface / raised / overlay (fails). New: 6.39 / 5.87 / 5.33 / 4.63 on bg / surface / raised / overlay — passes everywhere |
| P2 | Change `color.light.textTertiary` | #7A7A86 → **#666671** | Current 4.24 on white (fails). New: 5.67 / 5.25 / 5.67 / 4.81 |
| P3 | Add `color.dark.primaryText` | **#FF3B47** (= red400) | `dark.primary` as text is 4.10 on background. red400: 5.59 / 5.13 / 4.66 (bg / surface / raised); still 4.04 on overlay → rule "no red text on overlay" |
| P4 | Add `color.light.primaryText` | **#C8080F** (= light.primary) | Symmetry so components read one role |
| P5 | Change `color.light.success` | #1E9E57 → **#137A43** | 3.45 on white fails; new 5.39 / 5.00 / 5.39 / 4.58 |
| P6 | Change `color.light.warning` | #C77D00 → **#955C00** | 3.30 fails; new 5.51 / 5.11 / 5.51 / 4.68 |
| P7 | Change `color.light.error` | #D92D36 → **#C4242D** | 4.44 on surface, 4.07 on overlay fail; new 5.77 / 5.35 / 5.77 / 4.90 |
| P8 | Change `color.light.info` | #1F6FD1 → **#1A64BF** | 4.19 on overlay fails; new 5.80 / 5.38 / 5.80 / 4.92 |
| P9 | Add `color.dark.borderStrong` / `color.light.borderStrong` | **#70707C** / **#85858F** | Input & toggle boundaries need 3:1 (WCAG 1.4.11); `border` is 1.60 / 1.37. New dark: 4.02 / 3.69 / 3.36 (bg/surface/raised); light: 3.65 / 3.38 / 3.65 / 3.10 |
| P10 | Add `color.brand.goldOnLight` | **#8A5F00** | `gold` on white is 1.63. New: 5.65 / 5.23 / 5.65 / 4.79 |
| P11 | Add `color.dark.focusRing` / `color.light.focusRing` | red400 / light.primary | Name the focus role explicitly (5.59 / 6.00 vs background) |
| P12 | Add `color.brand.red600` pressed mapping as `color.dark.primaryPressed` / `color.light.primaryPressed` | #B80710 / #8A050C | Named pressed role (white text 6.83 / 9.96) |
| P13 | Add `color.live.pkLeftStrong` / `pkRightStrong` (text-bearing fills) | **#D6084A** / **#1E66D0** | White on current pkLeft/pkRight is 3.45 / 3.32 (small text fails). New: 5.26 / 5.43 |
| P14 | Add `color.onStatus` | **#0B0B0D** | Text on status/gold fills (white fails: 1.63–3.05; #0B0B0D: 6.44–12.08) |
| P15 | Add `motion.curveExit` | easeInCubic | Exits currently undefined |
| P16 | Add `motion.durationShimmerMs` = 1200, `motion.skeletonDelayMs` = 300 | — | Used by Skeleton spec |
| P17 | Add `typography.arabicHeightDelta` | +0.15 (applied to every style when locale is `ar`) | Plex Sans Arabic marks clip at `label`/`title` 1.3 in tight single-line boxes |
| P18 | Add `size.topBarHeight` = 56, `size.iconSm/Md/Lg` = 20/24/28, `size.textFieldHeight` = 52, `size.focusRingWidth` = 2 | — | Values this spec relies on that have no token yet |
| P19 | Add `elevation.lightShadow2` / `lightShadow3` | 0 2 8 rgba(0,0,0,.08) / 0 8 24 rgba(0,0,0,.12) | Light-mode separation of raised surfaces |
