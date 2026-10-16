# Reference patterns OREF-02 … OREF-06 (owner-supplied, 2026-10-16)

The owner supplied five **real screenshots** of the reference app (iPhone, about 393 pt wide):
Discover grid, Hot list, Go-live setup, Messages, and Me.

**The images are NOT in this repository (D40, public repo).** They show real third-party users'
photos and names. This file describes **interaction and layout patterns only**:
- no names, photos, logos or brand assets are reproduced;
- measurements are the coordinator's **approximate visual estimates**, rounded to Kabso's 4 dp
  grid, not pixel measurements.

Kabso keeps its own identity (D44): its own colours, wordmark and icons.

## Overall visual language (all five screens)

| Aspect | Observed pattern |
| ------ | ---------------- |
| Theme | **Light**: white surfaces on a very light grey ground; content (photos) supplies most colour |
| Primary colour | One saturated brand colour for the main action (centre nav button, "Go LIVE"), used sparingly |
| Density | High. Photo-led cards fill the screen; little empty space; secondary information as small coloured chips |
| Type | Large bold page titles (≈28–32), bold tab labels (≈18–20) with grey unselected, bold 1-line card titles over photos |
| Chips | Small rounded pills in soft tints (purple-grey, light blue, light orange) carrying status: popularity, PK, host level |
| Emoji | Used freely in titles and category tabs (⭐ 👑 🔥) — user content, not chrome |
| Bottom nav | **Floating capsule** (white, rounded ≈28, soft shadow, inset ≈16 from the sides). 5 items: Live · Party · **centre circular primary button (go live, ≈56)** · Chats (red count badge) · Me (red dot). Selected item gets a soft grey pill behind icon+label |

## OREF-02 Discover (grid)

- **Header:** large bold wordmark title on the start side; search and bell icons on the end side.
- **Tab rows:**
  - Row 1 is **segmented pills**: Nearby · Popular ▾ (selected: white with shadow, opens a menu) · Featured · Explore, on light grey pills.
  - Row 2 is **text tabs**: All (bold) · regional/category tabs with emoji, grey when unselected. It scrolls horizontally.
- **Grid:** 2 columns, ≈14 side margin, ≈14 gutter. Cards are **≈0.9 aspect** (slightly taller than wide), corner radius ≈16. The **photo is full-bleed**.
- **Card overlay:**

  | Position | Content |
  | -------- | ------- |
  | Top-start | Animated equaliser glyph (live) + room mode label ("Room PK", "Video Room") |
  | Top-end | Person icon + viewer count (white, bold) |
  | Bottom-start, upper line | One badge pill: host tier, country flag + name chip, or a "1M viewers" milestone |
  | Bottom-start, lower line | Title, bold white, one line with ellipsis |

  Overlay text sits on a subtle bottom gradient.
- **Floating event bubble:** a circular promo button at the bottom end, above the nav.

## OREF-03 Hot list (list view)

- **Header row:** text tabs Follow · **Hot** (bold, short underline) · Video · Voice, with search and bell. Row 2 has country/region and category text tabs.
- **Section header:** "Room", with a layout toggle (grid/list) and a filter icon on the end side.
- **Rows:** white cards on light grey, ≈8 between rows.
  - Square thumbnail ≈72, radius ≈8, with a small "live bars + category" label at the bottom-start of the thumbnail.
  - Bold title (1 line).
  - A chips row: popularity tag, PK tag (light blue), level tag "Lv.NN" (light orange with a star).
  - End side: a mic or camera glyph (audio vs video room) + count, in the primary colour.
- **Floating promo card:** "Random Match" teaser, gradient, bottom end.

## OREF-04 Go-live setup

- **Background:** full-screen camera preview (blurred here).
- **Close:** × at the top end.
- **Title card:** a frosted-glass card containing:
  - a cover thumbnail with "Edit" and a red attention dot;
  - a large placeholder "Add a title…";
  - a row of hashtag chips (`# tag +`) and an expand chevron.
- **Tool row:** icons above labels: Flip · Beauty · Magic · Creator Center · Expand.
- **Go live button:** a large pill in the primary colour, nearly full width, ≈52 high.
- **Bottom mode switcher:** a horizontally scrolling text carousel: Multi-guest LIVE · **LIVE** (selected, with a dot below) · Audio Live · Game LIVE.

## OREF-05 Messages

- **Tabs:** Realmatch (red dot) · **Messages** (bold, short underline), with a menu icon on the end side.
- **Rows:** large round avatar ≈56, with a red unread count badge on its top-end.
  - Line 1: name (bold) + emoji + an age/gender pill (pink tint), and a grey timestamp on the end side.
  - Line 2: grey last-message preview.
- **System rows:** a coloured icon tile in place of the avatar, plus a verified badge.

## OREF-06 Me (profile)

- **Header:** soft gradient wash at the top (light cyan → white). Centred large avatar ≈96, bold name, and settings/profile icons at the top end.
- **Stats row:** big numbers with grey labels, e.g. Friends / Following / Fans.
- **Feature tiles:** 4 colourful tiles, each with an icon and a label: level, VIP, family, earnings.
- **Grouped list:**
  - rows have a coloured round icon, a label and a chevron, with optional trailing content (a thumbnail, a count or a dot);
  - groups are separated by light grey bands.

## What this means for Kabso (mapping, for the prototype KL-051)

| Pattern | Kabso today | Gap |
| ------- | ----------- | --- |
| Light theme, photo-led density | Dark theme, empty states, initials | Theme choice + real images (uploads KL-049) |
| Floating capsule nav with centre go-live button | Flat bottom bar, Create pill | Nav restyle; Create → go-live |
| Segmented pills + text sub-tabs | Text tabs + one chip row | Tab hierarchy |
| Card overlay: mode, viewers, badge pill, title | LIVE badge, "New", host + title + category | Overlay hierarchy; viewer counts need presence API |
| List view with level/PK/popularity chips | No list view | New view; levels need a levels system |
| Go-live setup screen | None (no host UI) | New screen; video needs B1 |
| Messages, Me with tiles | Placeholders | Phase 9 / profile slice |
