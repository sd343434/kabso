# CP-011 — Multi-guest live and audio live (seats) (APPROVED)

**Status:** approved by the owner on 2026-10-23 (D94), with these decisions:

- **Modes (owner):** going live offers three modes, built in full now:
  - **Multi-guest LIVE** (video): the host plus guests on seats, **4, 6, 9 or 12** tiles in
    all (host included);
  - **LIVE** (video, one host): CP-010, unchanged;
  - **Audio LIVE** (voice only): the host plus seats, **5, 9 or 13** in all (host + 4, 8 or
    12).
- **Getting on a seat (owner): both ways.**
  - A viewer **asks** for a seat, and the host (or a moderator) accepts or declines.
  - The host (or a moderator) **invites** a viewer, who accepts or declines.
- **Host controls (owner):**
  - mute a guest and take a guest off their seat;
  - lock and unlock seats;
  - change the number of seats during the live;
  - appoint **moderators**, who help with requests, invitations, muting and taking guests off.
- **Guests without an account (owner):** may watch both modes, as in CP-010, and do nothing
  else: they cannot ask for a seat or be invited. The host's "allow guests" switch applies.
- **Look (owner):** the go-live screen is redesigned with **ornate room themes** — Kabso's
  own artwork, generated for Kabso and approved by the owner before use. The theme is chosen
  before going live and viewers see the same theme.
- **Video beauty filters (owner):** now, processed on the device (no contract change).
- **Audio LIVE has no filters (owner).**

## Why

CP-010 (L1) gives one host on camera. The room designs already have multi-guest seats
(D71, `KGuestSeatGrid`) and the enum `live_room_mode` already has `MULTI`. The owner asked
for multi-guest and audio rooms now, with the go-live screen laid out after their
references (not copied: no third-party artwork, mascot or icons).

## Scope

In scope:

- going live in each mode, with the seat count and the theme;
- seats: ask, invite, accept, decline, cancel, leave;
- the host's and moderators' controls listed above;
- who is on which seat, live, for everyone in the room (viewers included);
- the media permission follows the seat: a guest publishes only while seated (camera and
  microphone in multi-guest, microphone only in audio);
- the hub shows the mode and how many seats are taken.

Not in this proposal: chat and gifts (L2, L3), PK battles (L5), seat gifts and seat
"scores", background music, recording.

## Proposed contract (v1.7-live, additive; tag `live`)

### 1. Modes, seats and themes on the room

- `LiveRoomMode` gains `AUDIO`. Going live uses `SOLO`, `MULTI` or `AUDIO` (`PK` stays
  reserved for L5).
- `StartLiveRoomRequest` gains:
  - `mode` (default `SOLO`);
  - `seatCount`: required for `MULTI` (4, 6, 9, 12) and `AUDIO` (5, 9, 13); absent for
    `SOLO`. It counts the host's tile;
  - `theme`: a slug from `GET /live/config` `themes` (default `classic`).
- `LiveRoom` and `LiveRoomSummary` gain `seatCount` (null for `SOLO`), `occupiedSeats`
  (guests seated now) and `theme`.
- `LiveConfig` gains `themes` (the slugs the server accepts, in display order) and
  `seatCounts` (`{MULTI: [4,6,9,12], AUDIO: [5,9,13]}`).

### 2. Reading the seats: `GET /live/rooms/{roomId}/seats`

Open to everyone who may see the room (guests too). Returns:

```yaml
LiveSeats:
  required: [version, seatCount, seats, moderators]
  properties:
    version: integer         # increases on every seat change
    seatCount: integer
    seats: [LiveSeat]        # index 1 … seatCount-1 (0 is the host)
    moderators: [UserSummary]
    pendingRequests: integer # host and moderators only, else absent
    mine:                    # signed-in caller only
      role: HOST | MODERATOR | SEATED | VIEWER
      seatIndex: integer?
      request: {id, createdAt}?   # my pending request
      invite: {id, seatIndex?, invitedBy: UserSummary, expiresAt}?  # my pending invitation
LiveSeat:
  required: [index, state]
  properties:
    index: integer
    state: EMPTY | LOCKED | TAKEN
    user: UserSummary?       # TAKEN only
    mutedByHost: boolean     # TAKEN only
```

**Live updates:** the API stamps `version` into the media room's metadata on every change;
the app refetches the seats when the version moves (no polling while connected). A user's
invitation also arrives as a targeted media data message.

### 3. Asking for a seat

- `POST /live/rooms/{roomId}/seat-requests` `{seatIndex?}` — a signed-in viewer asks.
  - One pending request per user and room; asking again returns the pending one (200).
  - Refused: already seated or host → 409 `LIVE_SEAT_UNAVAILABLE`; mode `SOLO` → 409
    `LIVE_SEAT_UNAVAILABLE`; all seats taken or locked → 409 `LIVE_SEAT_UNAVAILABLE`;
    guest (no token) → 401.
- `DELETE /live/rooms/{roomId}/seat-requests/me` — cancel (idempotent, 204).
- `GET /live/rooms/{roomId}/seat-requests` — host and moderators: pending requests, oldest
  first, cursor-paged (`{id, user, seatIndex?, createdAt}`).
- `POST /live/rooms/{roomId}/seat-requests/{requestId}/accept` `{seatIndex?}` — host or
  moderator; seats the user on the asked seat, the given one, or the first free seat.
  Handled already → 409 `LIVE_REQUEST_NOT_PENDING`; no free seat → 409
  `LIVE_SEAT_UNAVAILABLE`.
- `POST …/seat-requests/{requestId}/decline` — host or moderator (204).
- A pending request ends when the requester leaves the media session, or the room ends.

### 4. Invitations

- `POST /live/rooms/{roomId}/seat-invites` `{username, seatIndex?}` — host or moderator
  invites a signed-in viewer **who is watching now**. One pending invitation per user;
  inviting again replaces it. Expires after **60 seconds**.
  - Not watching → 409 `LIVE_SEAT_UNAVAILABLE`; already seated → 409 `LIVE_SEAT_UNAVAILABLE`.
- `POST /live/rooms/{roomId}/seat-invites/me/accept` — seats the caller (on the invited seat
  if still free, else the first free seat). Expired or none → 409 `LIVE_REQUEST_NOT_PENDING`.
- `POST /live/rooms/{roomId}/seat-invites/me/decline` (204).

### 5. On the seat

- `POST /live/rooms/{roomId}/seats/me/leave` — a guest leaves their seat (204).
- Host or moderator:
  - `POST /live/rooms/{roomId}/seats/{index}/mute` `{muted}` — `mutedByHost`. While muted, the
    guest cannot unmute (the media server withdraws the microphone).
  - `POST /live/rooms/{roomId}/seats/{index}/remove` — takes the guest off (204).
- Host only:
  - `POST /live/rooms/{roomId}/seats/{index}/lock` `{locked}` — an occupied seat cannot be
    locked (409 `LIVE_SEAT_UNAVAILABLE`).
  - `PATCH /live/rooms/{roomId}` gains `seatCount` (an allowed count for the mode) and
    `theme`. Shrinking below an occupied seat → 409 `LIVE_SEAT_UNAVAILABLE` (take the guest
    off first).
- A moderator cannot mute or remove the host or another moderator.
- A seated guest who leaves the media session (or is suspended, or blocked by the host)
  loses the seat.
- Self-mute (a guest muting their own microphone or camera) is local and needs no API.

### 6. Moderators

- `PUT /live/rooms/{roomId}/moderators/{username}` and `DELETE …` — host only; the user must be
  signed in and not blocked either way. Up to **5** per room. Idempotent.
- Moderators last for the room only.

### 7. Media permission

- The media token (CP-010) gains role `SPEAKER` for a seated guest.
- Seating, removing and muting change the guest's permission on the media server at once (no
  reconnect): `MULTI` → camera + microphone, `AUDIO` → microphone only, muted → camera only
  (`MULTI`) or nothing (`AUDIO`).
- The host of an `AUDIO` room publishes the microphone only.

### 8. Errors (CONVENTIONS §4)

- `LIVE_SEAT_UNAVAILABLE` (409): the seat or seats asked for cannot be used (taken, locked,
  out of range, none free, mode without seats, the user already seated or not watching).
- `LIVE_REQUEST_NOT_PENDING` (409): the request or invitation was already handled, cancelled
  or expired.
- Not host or moderator → 403 `AUTH_FORBIDDEN`. Ended room → 409 `LIVE_ROOM_ENDED`.

### 9. Rate limits

- Seat requests and invites: 30 per 10 minutes per user.
- Host and moderator seat actions: 300 per hour per user.
- Seat reads: the CP-010 guest read limit (by IP) and 600 per 15 minutes per user.

### 10. Compatibility

- **Additive:** a new mode value (`AUDIO`; older apps show it as `SOLO` through
  `unknownEnumValue`), new optional fields, new operations and two error codes.
- **Database:** `live_rooms.seat_count`, `live_rooms.theme`; tables `live_room_seats`
  (room, index, state, user, muted_by_host, version), `live_seat_requests`,
  `live_seat_invites`, `live_room_moderators`.

## Not part of the contract (app only)

- **Beauty filters (video):** smoothing and brightness applied to the camera picture on the
  device before publishing; on/off and strength on the go-live screen and while live.
- **Themes:** the artwork ships with the app (one image per theme slug, Kabso-made, owner
  approved). An unknown slug shows the default theme.

## Work

1. Contract: openapi v1.7-live, CONVENTIONS §10.9, Decision Log D94.
2. API: migration, seat service (transactions, version), requests, invites, moderators,
   media permission updates and room metadata, webhook clean-up, e2e (and the real LiveKit
   suite).
3. App: the go-live redesign (three modes, seat counts, themes, tools bar, beauty), the
   multi-guest and audio rooms (seats, ask, invite, host and moderator controls), Arabic and
   English, tests, and a real check with several browsers through local LiveKit.
