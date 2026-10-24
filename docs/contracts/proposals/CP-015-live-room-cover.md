# CP-015 — The live room's cover picture ("Edit" on the cover)

**Status:** APPROVED (D98, 2026-10-24) with both recommendations: one cover reused by every live
(Q1), built now behind the upload gate (Q2). Applied as openapi v1.11-live (draft) and
CONVENTIONS §10.13 (owner request 2026-10-24: "the audio live's outside picture cannot be changed;
put Edit on the picture and make it work").

## Why

The audio go-live screen (owner refs 65/66/68) shows the room's picture with **Edit** on it. In
Kabso the room card shows the host's picture: `LiveRoomSummary.coverUrl` exists but is "always
null (no upload yet)" since v1.3, and covers are listed as not in the contract (§10, "Editing a
room's title or category after go-live; covers and cover upload"). The hub cards already show
`coverUrl` when there is one and fall back to the host's avatar.

## Proposal

### 1. A cover image kind

- `MediaKind` gains `LIVE_COVER`. Upload and checks exactly as §11.1 (JPEG / PNG / WebP, the
  bytes decide, ≤ 8 000 px per side, ≤ 50 MP, metadata stripped). Variants: a **square**
  `media/{mediaId}/640.webp` (centre crop, 640 x 640) and `320.webp`, plus the blurhash.
- A `LIVE_COVER` asset attaches only as a live cover (else 400 `mediaId` / `invalid_value`),
  once, by its owner, within 24 hours (as today).

### 2. Where the cover lives (owner decision Q1)

**Recommended — the host's live cover, reused by every live:**

- `PUT /me/live-cover` `{ "mediaId": "…" }` → 200 `{ "coverUrl": "…" }`;
  `DELETE /me/live-cover` → 204 (back to the avatar).
- `GET /me` (or `Me`) gains `liveCoverUrl` (string or null) so the go-live screen shows it
  before the room exists.
- A live started after that carries it: `LiveRoomSummary.coverUrl` is the host's live cover at
  the time the room started; changing the cover while live also updates the live room
  (`roomInfoVersion`, CP-014, moves so viewers re-read it).

*Alternative:* a cover per live (`StartLiveRoomRequest.coverMediaId`,
`UpdateLiveRoomRequest.coverMediaId`, null removes it) — the host picks a picture each time.

### 3. Safety

- Covers are public on the hub: reports of a room (`LIVE_ROOM`) cover its picture; a removed
  cover (moderation) falls back to the avatar. Same moderation path as post images (B13).
- Rate limits: the `POST /media/uploads` bucket; `PUT /me/live-cover` 30 / hour.

### 4. Availability (no change to the gates)

- Uploads stay behind `MEDIA_UPLOADS_ENABLED` and PP-28 (storage credentials B12, moderation
  B13, A7 review). Until they are on, **Edit** says so (503 `MEDIA_UPLOADS_UNAVAILABLE`, the
  app's existing message) and the card keeps the host's picture. Nothing is faked.

## App (after approval)

- The room card's picture gets **Edit** (owner ref 65): pick a photo (gallery / camera), crop
  square, upload (`createMediaUpload` → PUT → `completeMediaUpload`), then `PUT
  /me/live-cover`; progress and failure states; "Remove cover" back to the avatar.
- Hub cards and the room bar already read `coverUrl`.

## Questions for the owner

- **Q1.** One cover reused by every live (recommended), or a picture per live?
- **Q2.** Build the API and app now behind the upload gate (it works locally with MinIO and in
  production once PP-28 is cleared), or wait for the storage credentials?
