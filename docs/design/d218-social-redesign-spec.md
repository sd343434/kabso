# D218 — the posts feed, the story viewer and the public profile: reference spec

Owner, 2026-11-01: «بهذا التصميم حرفياً مع اضافة ميزاتنا وجعلها مناسبة لنا». The reference is a
third-party marketing composite (1122×1402 px, three phones, sha256
`bf81997ad45dbcae9e7c391789b89f841a888a47f46faebcefb010e67d4de6dd`); it stays in scratch (D40) and
nothing is taken from it but layout — no name, wordmark, photos, icons or colours of its brand.

**Composite → phones (M).** `split_composite.py` returned one box; the screens were isolated by the
near-black bezel runs (`measure.py`-style scan, rows 700 and 900, columns 200 / 560 / 920):
left (posts) x 42…359, middle (story) x 403…716, right (profile) x 760…1076, all y 439…1128 —
318 / 314 / 317 × 690 px.

**Gate A — viewport (assumption, E).** The composite says nothing about the device. Each phone is
treated as an iPhone-like **393 × 852 dp** screen (owner brief): 318 px / 393 = 0.809 px/dp and
690 px / 852 = 0.810 px/dp agree, so the assumption is consistent. Status bar ≈ 54 dp, home
indicator ≈ 34 dp. Light theme, English LTR in the reference; Kabso is Arabic RTL first.

**Precision.** At ≈0.81 px/dp one pixel is 1.24 dp and the image is a compressed WebP marketing render,
so almost every value is **E** (estimated, ±2 dp); **M** marks a value read from pixels with
`measure.py` (`bbox`, `vline`, `hline`) whose box is unambiguous. Typography is always E (no
font file, glyphs ≈ 8 px tall).

## 1. Posts page (left phone)

| Region | Reference | Spec (dp) | Tag |
| --- | --- | --- | --- |
| Top bar | avatar + name + handle at the start; 3 grey discs at the end | **owner override (after D218): the bar of before** — 48 dp, Search at the start, centred «المنشورات» + the «الريلز» switch word, the bell (badge) at the end; no avatar or name | owner |
| Own avatar | 43×33 px box with its ring | 38 dp incl. a thin story ring (image 32) | M (≈40) / E |
| Name / handle | bold over grey | 15 sp w700 / 12 sp `textTertiary` | E |
| Discs | search 31×30 px, light grey fill | 36 dp discs, `surfaceOverlay`, 8 dp apart, 48 dp targets | M (37–38) |
| Discs' content | search · bell (red count badge) · a third icon | Search · bell (`NotificationsBell`, count) · «ريلز» (opens Reels — owner: replaces the third icon) | owner |
| Stories ring | 56×56 px | 68 dp (`KSizes.storyRing`, unchanged) | M (69) |
| «Your story» | grey ring, blue «+» bottom-end | «قصتك», grey ring, `primary` «+» 22 dp | E |
| LIVE pill | red pill over the ring's bottom, ≈46×12 lp | 16 dp tall, 10 sp w700 white on `KLiveColors.badge`, 1.5 dp page-colour outline, overlapping by 8 | M (w) / E |
| Post avatar | 33×30 px | 40 dp (`KPostCard.avatar`, was 32) | M |
| Name / subline | bold / «Suggested for you» grey | 14 sp w700 / 12 sp `textTertiary` «مقترح لك» (+ location) | E |
| Follow | blue rounded pill | `primary` pill 32 dp tall, 16 dp padding (48 dp target) | E (bbox 28–35) |
| Dots | vertical ⋮ | `Icons.more_vert_rounded` | E |
| Caption | 2 lines, «…», hashtags blue | 2 lines, «… المزيد», hashtags/mentions `primaryText` | E |
| Time | grey under the caption | 12 sp `textTertiary` | E |
| Media | edge to edge, own ratio | **square 1:1, cover-cropped, centred** (owner after D218); several photos swipe (RTL-aware), «1/3» in the top corner, dots under the media | owner |
| Action row | heart+count, bubble+count, share; bookmark at the end | 22 dp icons, 13 sp w500 counts: like, comment, share, **repost, views** (ours), save at the end | M (icon box ≈30 lp incl. AA) / E |
| Separator | hairline | `border` hairline + 8 dp | E |
| Bottom bar | the reference's own | **not changed** (owner): لايف · منشورات · + · رسائل · أنا | owner |

## 2. Story viewer (middle phone)

| Region | Reference | Spec (dp) | Tag |
| --- | --- | --- | --- |
| Bars | 2 bars, white / 35 % white | 3 dp tall, 4 dp gap, 10 dp side insets | M (3.75 lp tall, 352 lp span) |
| Header | ringed avatar, name over «3 hours ago», ✕ | avatar 38 with ring, name 14 sp w700, time 12 sp 80 % white, ⋮ (ours) then ✕ | E |
| Header rule | faint line under the header | **none** (owner: «وازل الخط اسفل الايقونات») | owner |
| Reply | outlined pill «Type your message», heart, send | 44 dp pill, 1.2 dp white 70 % outline, black 15 % fill; heart and send 28 dp in 48 dp targets | M (pill 282×50 lp incl. AA) / E |
| Photo | full-bleed photo | **whole photo, contain, never cropped** (owner: «اجعل الصورة كاملة ولا تقص منها»); bars, header and reply bar lie over it on soft scrims | owner |
| Own story | — | keeps «who saw it», delete and (D218) the archive; no reply bar | owner |

## 3. Public profile seen by others (right phone)

| Region | Reference | Spec (dp) | Tag |
| --- | --- | --- | --- |
| Top bar | back and ⋮ squares over the photo | **owner override (after D218): the bar of before** — back, centred «@username», ⋯ — on the page colour; no squares over the cover | owner |
| Cover | photo from the top to ≈195 dp | 140 dp under the top bar; `coverUrl` or the Kabso red gradient (never a stock photo) | E |
| Avatar | ≈75 dp, white ring, half over the cover | `KProfile.avatar` 88 dp with a 3 dp page-colour ring (frames, live ring as before) | E |
| Name line | name, blue verified mark, @handle | name 18 sp w700 and our badges; **no @handle here** (only in the top bar) and **no verification mark yet** — its place stays free (owner); the **level badges right under the name** | owner / E |
| Counts | «36K Follower 600 Following» | «N متابِع · N متابَع», bold numbers, tappable (lists) | E |
| Bio | one line | `body` | E |
| Facts | 📍 London · 📅 Joined April 2025 | country flag + name, «انضم في <شهر سنة>» (`PublicProfile.country`, `joinedMonth`) | E |
| Follow | wide black pill | `textPrimary` fill / `background` text (inverted in dark), 44 dp; states متابَع / تم الطلب / إلغاء الحظر | M (238 lp wide) / E |
| Message | outlined circle | 44 dp circle, `borderStrong` outline, send glyph | E |
| Our features | — | medals shown, family / relationship / medals tiles (`ProfileBondsBlock`); **no PK record pill** (owner) | owner |
| Tabs | «Post · For Subscribers · Shorts» words | «منشورات · ريلز · إعادات» words, selected bold with a 2 dp underline; **no subscribers tab** | owner |
| Grid | 3 columns, 1 px gaps, square | unchanged (`KProfile.gridGap` hairline, square) | M |

## Not copied

The HUGEI name and wordmark, every photo, the blue accent (Kabso's `primary` / `primaryText` instead), the
verified badge, the «For Subscribers» tab, the reference's bottom bar and its icons. Icons are Kabso's
(`AppIcons`) or Material.

## Deliberate differences

- Touch targets: every control keeps a 48 dp target around the measured face.
- Arabic RTL first: every position above is mirrored (start/end).
- The posts page has one feed (the server's 1 : 2 mix); Reels keeps its own tabs.
- Dark theme: the same structure from Kabso tokens (the follow pill inverts: light fill, dark text).
