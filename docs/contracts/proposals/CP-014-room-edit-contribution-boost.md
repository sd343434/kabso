# CP-014 — Edit the room while live, the Contribution list, Room boost

**Status:** Parts A and B approved by the owner on 2026-10-24 (D97): Q1 the Contribution list is
**public** (top 50 of each live); Q2 **one category** per room (the tags are the category list);
Q4 the topic **shows on hub cards**. Part C (boost) waits for L3; Q3 (packages, prices,
durations) is decided with the wallet. Not applied yet: `openapi.yaml`, `CONVENTIONS.md`.
It comes from the owner's reference screenshots of another app (the viewers box with a
"Contribution" tab, and a "Room Boosting" sheet). Those pictures stay outside git (D40); only the
behaviour is described here. The questions at the end need answers before the contract is written.

## Why

The host cannot change the room's name, category or topic after going live; the viewers box
has no list of who contributed most; and there is no way to push a room up the hub. The three
fit together in the reference: the boost sheet edits the room's name, tags and topic and then
promotes it.

## Part A — Edit the room while live (no payment; can be built now)

`PATCH /live/rooms/{roomId}` (host only, existing operation) accepts three more fields:

| Field | Rules |
| ----- | ----- |
| `title` | Same rules as when going live (`LiveRoomTitle`, §6 hygiene). |
| `categorySlug` | An active category (`GET /live/categories`), or `null` for none. |
| `topic` | **New.** 0–100 code points, one line, §6 hygiene; `null` or `""` removes it. |

- `LiveRoom` and `LiveRoomSummary` gain `topic` (string or null). The app shows it as a chip
  under the room bar ("Topic: …") and on hub cards.
- The change reaches everyone in the room: the server writes `roomInfoVersion` into the media
  room's metadata (next to `seatsVersion` and `score`); apps re-read `GET /live/rooms/{roomId}`
  when it moves.
- Rate limit: the existing `PATCH` bucket (60 / hour per user). A title or topic change is
  audited (`live.room.edit`).
- Reports of a room (`LIVE_ROOM`) already cover a bad title; the topic is included.

## Part B — The Contribution list (needs a decision; can be built now)

The viewers box gets a third tab, **Contribution**: who gave this live the most points.

- `GET /live/rooms/{roomId}/contributors`: the top 50 of this live, by points given, highest
  first. Each row: the user (`UserSummary`) and `points`. Points are taps today (1 each, from
  CP-012) and, with L3, support (100 a coin).
- Anyone who may watch the room reads it; people the reader blocked are left out.
- This makes per-viewer tap counts public. CP-012 Q5 recorded them for admins only. **Q1
  decides.**

## Part C — Room boost (needs L3: wallet and coins)

The host pays coins to push the room up for a while.

- `POST /live/rooms/{roomId}/boost` with a package id; the server takes the coins from the
  host's wallet in the same transaction (L3), and the room is boosted until `boostedUntil`.
- A boosted room is shown **first in Popular** (in boost order, then by score), with a ⚡ mark
  on its card and in its room bar.
- A boost cannot be refunded; it ends early if the live ends.
- **Packages, prices and durations are the owner's (Q3).** Nothing here is built before L3
  (wallet, coins, purchases) exists, because there is no way to pay yet.

## Open questions for the owner

- **Q1. Contribution list public?** Recommended: **yes**, top 50 of each live, because it
  rewards people who take part (as in the reference). The alternative is visible to the host
  only.
- **Q2. Tags:** the reference shows several tags (Family, Games, Party, Music…). Kabso has one
  category per room, created by admins. Recommended: **keep one category** (the tags list is
  the category list), so the hub filters stay simple. Several tags per room is possible later.
- **Q3. Boost:** price per package, duration (e.g. 10 / 30 / 60 minutes), how many rooms may
  be boosted at once, and whether a boost needs the room to be open to guests (the reference
  switches the room to open mode). Recommended: decide with L3.
- **Q4. Topic on hub cards:** recommended **yes** (one line under the title).

## Work (after approval)

1. Contract (v1.10-live): A and B now; C written with L3.
2. API: A (fields, metadata version, audit), B (query over `live_room_tappers`, later support),
   e2e.
3. App: an "Edit room" sheet (name with counter, category chips, topic) from the room tools,
   the topic chip, the Contribution tab; C after L3.
