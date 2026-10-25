# CP-016 — Live room extras from owner refs 71–75

**Status:** APPROVED in part (D99, 2026-10-24): order **B → A → C**, one region for rankings,
room level **built**. Part B applied as openapi v1.12-live (draft), CONVENTIONS §10.14. (Owner
request 2026-10-24, refs 71–75; the owner chose "what is backed first, one proposal for the
rest".) Parts not yet built are shown greyed with "Soon" in
the app and do nothing (owner choice for ref 71).

Already built from the same refs, on existing contracts: the seat action sheet (ref 72,
CP-011), the room info sheet's Change cover, title, Tag and Announcement (ref 73, CP-014 and
CP-015), Room settings → the settings sheet, Share (ref 71), and the Contribution list tab
(ref 75, CP-014).

## Parts

| # | Ref | Feature | What the contract needs | Depends on |
| - | --- | ------- | ----------------------- | ---------- |
| A | 74 | **Room rankings** — Regional room rank, Popularity rank, Rich (top spenders), each by This hour / Today / This week, with a countdown and "my room" pinned at the bottom | `GET /live/rankings?board=REGION\|POPULARITY\|RICH&period=HOUR\|DAY\|WEEK` → top 50 rooms (or users for RICH) + the caller's own row; period windows in UTC or the user's region; "region" = the host's country (we store none today) | Points (CP-012) exist; RICH needs coins (L3); REGION needs a host country |
| B | 71 | **Blocked words** — the host's list of words hidden from their room chat (count on the row) | `GET/PUT /me/live-blocked-words` (≤ 100 words, ≤ 30 chars, NFC + case-folded); the chat send path (CP-013) drops or masks matching messages in that host's rooms | CP-013 chat |
| C | 71 | **Live schedule** — the host announces upcoming lives; followers are reminded | `POST/GET/DELETE /me/live-schedule` (≤ 10 future slots, title, start time); a notification kind `LIVE_SCHEDULED_SOON` (CP-009) | Notifications (CP-009) |
| D | 73 | **Room level** (Lv.1 …) | Either reuse CP-005 levels with a new ladder for rooms (points per room over 30 days) or drop it | CP-005 levels |
| E | 73 | **Boost my room** | CP-014 part C (packages, prices, ranking effect) | L3 wallet/coins |
| F | 71 | **Event center**, **Creator center** | Product scope first (which events, which creator stats); likely web pages | Owner decisions |
| G | 73/75 | **Room number ID** ("ID: 981309806"), the viewers sheet gear | A short public room/host number (`LiveRoomSummary.shortId`), and what the gear opens | — |

## Questions for the owner

1. Which parts first? Recommended order: **B** (small, safety value, chat exists), **A** without
   RICH and REGION (popularity boards by hour/day/week from existing points), **C**, then the
   rest after L3.
2. Rankings: one region for everyone at first (no host country), or ask hosts for their
   country?
3. Room level: build it (D) or remove the row?
