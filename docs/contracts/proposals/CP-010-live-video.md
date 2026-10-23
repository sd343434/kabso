# CP-010 — Live video: going live and watching (Live L1) (PROPOSED)

**Status:** proposed for the owner on 2026-10-23. The owner chose to start the live system with
**L1, going live and watching**, and to run **LiveKit** (D3) locally for development and
**LiveKit Cloud** in production later (B1). Not applied to `openapi.yaml` yet.

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
- **reporting a live room**, and an admin action that ends it.

Later milestones, not in this proposal:

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

### 5. Compatibility

- **Additive:**
  - one new operation, `createLiveMediaToken`;
  - one new report target (`LIVE_ROOM`);
  - `viewerCount` starts counting. Its shape is unchanged.
- **Database:**
  - a `live_room_viewers` table (room, user, joined_at) for the count;
  - a column linking a report to a room.

## Open questions for the owner

- **Q1 — Who can go live.** You had no preference. v1.3 already allows every account with a
  verified email.
  - **Recommendation:** keep it that way, with reports and admin ending as the safety net.
- **Q2 — Private accounts.** Can a private account go live, and who can watch it?
  - **Recommendation:** for now, a private account's live is visible only to its followers,
    the same rule as its posts and stories.
- **Q3 — Time limit.** Should one live have a maximum length?
  - **Recommendation:** no limit in L1; the heartbeat ends abandoned rooms.
- **Q4 — Watching without an account.** Watching needs an account, as everything else in the
  app does today.
  - **Recommendation:** keep it.

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
   - "Go live": camera preview, title, category, then start;
   - the host screen: publish, flip camera, mute, end, reconnecting;
   - viewers: video in the room and in the hub pager (only the visible page plays), the viewer
     count, "The host will be right back" and "Live ended";
   - camera and microphone permissions;
   - tests, Arabic and English captures, and a real check: a host and a viewer in two browsers
     through the local LiveKit server.
