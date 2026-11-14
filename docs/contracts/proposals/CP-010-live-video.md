# CP-010 — Live video: going live and watching (Live L1) (APPROVED)

**Status:** approved by the owner on 2026-10-23 (D93), with these decisions:

- **Order (owner):** video first (L1). Agencies and identity verification follow as **L1b**.
  - Until L1b, an admin grants the hosting permission for testing.
  - Going live stays switched off in production until both L1 and L1b are done.
- **Who can go live (owner):**
  - a host who joined a **host agency**: the agency invites them, or they ask to join with the
    agency's code and the agency owner accepts;
  - or a host who went live on their own after their **identity was verified**.
  - L1b specifies both paths. L1 adds the permission they will grant.
- **Private accounts (owner):** they can go live, and **everyone** can watch. Their posts,
  reels and stories stay followers-only.
- **Time limit (owner):** none.
- **Guests (owner):** people without an account may watch, but not comment or do anything else.
  - The host sees each of them as "Guest" with a short number.
  - Guests are allowed by default. The host can switch guests off before or during the live;
    guests already watching are removed at once.
- **Media server (owner):** LiveKit (D3), local for development; LiveKit Cloud in production
  with the owner's keys (B1).

The open questions at the end are answered by these decisions.

## Why

Contract v1.3 already has the live room: going live (`startLiveRoom`), the heartbeat, ending a
room, the discovery lists and room details. It has **no media**: nobody can publish a camera or
watch one, so `LIVE_HOSTING_ENABLED` stays off in production (D37) and the live screens show
covers only (D50). The room screens are designed (D71, D73). L1 connects them to real video.

## Scope

In scope (L1):

- the host publishes camera and microphone in their LIVE room (portrait, up to 720p);
- viewers watch it, from the hub pager or a link, and can switch between rooms;
- a real **viewer count** (people watching now);
- ending: by the host, by the heartbeat timeout, by suspension or by an admin, which also
  disconnects everyone at once;
- **reporting a live room**, and an admin action that ends it;
- the **hosting permission**: an admin grants or revokes it (agencies and identity
  verification grant it in L1b);
- **guest viewing** without an account, the host's viewer list, and the host's "allow guests"
  switch.

Later milestones, not in this proposal:

- **L1b:** host agencies (invite, or join with a code), identity verification, and granting
  the hosting permission through them;
- **L2:** chat, hearts, Kabi emojis, and muting or removing a viewer;
- **L3:** coins, gifts and the wallet;
- **L4:** guests on stage;
- **L5:** PK battles;
- push notifications ("X is live", CP-006 Q4);
- recording and replays.

## Proposed contract (v1.6-live, additive; tag `live`)

### 1. Media access: `POST /api/v1/live/rooms/{roomId}/media-token`

Returns what the app needs to join the room's media session:

```yaml
LiveMediaAccess:
  required: [url, token, expiresAt, role]
  properties:
    url: uri            # the media server (wss://…), from the server config
    token: string       # short-lived access token for this room only (10 min)
    expiresAt: date-time
    role: HOST | VIEWER
```

- **Host** (the room's host, room LIVE): may publish camera and microphone, and nothing else.
- **Viewer** (anyone else who may see the room): may only watch.
  - Viewers are hidden from each other: this keeps large rooms light, since the viewer list
    is not part of L1.
- **Refused:**
  - room not LIVE → 409 `LIVE_ROOM_ENDED`;
  - room not visible (host not ACTIVE, or a block either way) → 404;
  - hosting switched off → 503 `LIVE_HOSTING_UNAVAILABLE`.
- **Expiry:** a token works only to join. A session already joined stays open after the 10
  minutes. To rejoin (after a network change, for example), the app asks for a new token.
- **Rate limit:** 120 per hour per user.

### 2. Viewer count

- `viewerCount` (already on `LiveRoomSummary`, always 0 so far) becomes the number of distinct
  viewers connected now, without the host.
- The media server tells the API when someone joins or leaves, through a signed webhook (see
  §4). A reconciliation runs with the existing sweeper.
- `popular` then orders by real viewers (until now it ordered like `new`, D38).
- In the room, the app refreshes the count from `GET /live/rooms/{roomId}` every 15 seconds.

### 3. Ending and safety

- **Ending:** the media session is closed for everyone at once whenever a room ends:
  `endLiveRoom`, the heartbeat timeout, suspension or an admin action.
- **Host disconnects without ending:** the room ends after the heartbeat timeout (45 s), as
  today. The app shows "The host will be right back" during that time.
- **Reports:** `POST /reports` gains `targetType: LIVE_ROOM`. Admin `REMOVE_TARGET` ends the
  room with `endReason: ADMIN` and is audited.
- **Blocks:** a block either way hides the room (lists, details and media access), as for
  posts and stories.

### 4. Server-side (not in the app contract)

- `POST /internal/livekit/webhook`: accepts only the media server's signed events; it is not
  public API.
- **Configuration:** `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`.
  - `LIVE_HOSTING_ENABLED=true` now requires all three.
  - In production the URL must be `wss://`.
  - Secrets come from the secret manager, never from git.
- **Development:** a local LiveKit server (`livekit-server --dev`). Production uses LiveKit
  Cloud with the owner's keys (B1), with no code change.


### 4a. Hosting permission

- `startLiveRoom` also requires the caller to hold the **hosting permission**. Without it
  → 403 `LIVE_HOSTING_NOT_ALLOWED`.
- The app shows how to get the permission (L1b), and until then "Going live is not available
  for your account yet".
- `GET /me` gains `canHost` (boolean).
- **Admin control (permission `LIVE_HOSTS`, audited):**
  `PUT /admin/live/hosts/{username}` grants the permission and `DELETE` revokes it.
- **Source:** the grant records where it came from (`ADMIN`; later `AGENCY` or `IDENTITY`).
  Revoking ends the user's live room if one is running.

### 4b. Guests and the host's viewers

- **Endpoints guests can call without a token (rate-limited by IP):**
  - `GET /live/config`;
  - `GET /live/rooms` (`popular` and `new` only; `following` needs an account → 401);
  - `GET /live/rooms/{roomId}`;
  - `POST /live/rooms/{roomId}/media-token`.
- **A guest's token:**
  - identifies them as `guest:<random id>`, with a 4-digit `guestNumber` the host sees
    ("Guest 4821");
  - the app keeps the random id for the session, so the number stays the same.
- **Room switch:** `LiveRoom.allowGuests` (default `true`).
  - It can be set in `StartLiveRoomRequest`, and changed live with
    `PATCH /live/rooms/{roomId}` `{allowGuests}` (host only).
  - Switching it off removes every connected guest at once. New guest tokens are then refused
    with 403 `LIVE_GUESTS_NOT_ALLOWED`.
- **Viewer count:** guests count in `viewerCount`.
- **Viewer list:** `GET /live/rooms/{roomId}/viewers` (host only) lists who is watching now,
  newest first and paged. Each item is either a user (`UserSummary`) or a guest
  (`{guestNumber}`).
- **Guests can do nothing else:** follow, comment and report open "Sign in to continue" in the
  app. The API refuses them anyway, since those endpoints need a token.
- **Blocks:** a block cannot apply to a guest (there is no account).

### 5. Compatibility

- **Additive:**
  - new operations: `createLiveMediaToken`, `updateLiveRoom`, `listLiveRoomViewers`,
    `grantLiveHost` and `revokeLiveHost`;
  - new fields: `allowGuests` on the room and `canHost` on `/me`;
  - one new report target (`LIVE_ROOM`) and two error codes;
  - `viewerCount` starts counting. Its shape is unchanged.
- **Tightening:** going live now needs the hosting permission. It is switched off in
  production today, so nobody loses anything.
- **Relaxing:** four live reads accept no token (guests).
- **Database:**
  - a `live_room_viewers` table (room, user or guest id, joined_at) for the count and the list;
  - a `live_hosts` table (user, source, granted_by, granted_at);
  - `live_rooms.allow_guests`;
  - a column linking a report to a room.

## Owner decisions

The questions in the first draft are settled in the Status section above. Pending for L1b: how
identity is verified (the owner asked whether a small in-house document-and-face check is
possible; to be specified in L1b).

## Work if approved

1. **Contract:**
   - `openapi.yaml` (`createLiveMediaToken`, `LIVE_ROOM` reports);
   - CONVENTIONS §10.7;
   - a Decision Log entry.
2. **API:**
   - a `LiveMediaProvider` port with a LiveKit adapter;
   - tokens, the webhook, the viewer count, closing sessions and the reports;
   - configuration checks;
   - e2e tests against a real local LiveKit server.
3. **App:**
   - "Go live": camera preview, title, category and "allow guests", then start; without the
     hosting permission, an honest explanation;
   - signed out: "Watch as guest" on the welcome screen opens the live hub (Popular and New)
     and rooms; follow, comment and report ask the guest to sign in;
   - the host's viewer list, including "Guest 4821", and the guests switch during the live;
   - the host screen: publish, flip camera, mute, end, reconnecting;
   - viewers: video in the room and in the hub pager (only the visible page plays), the viewer
     count, "The host will be right back" and "Live ended";
   - camera and microphone permissions;
   - tests, Arabic and English captures, and a real check: a host and a viewer in two browsers
     through the local LiveKit server.
