# CP-023 — Video posts and reels (CP-006 M2, without transcoding) (APPROVED)

**Status:** approved by the owner on 2026-10-28 (D162): the «فيديو» tab of «منشور جديد» must work,
reels («ريلز», short vertical videos) show in the «لحظات» (Moments) tab, and the ➕ tab opens a menu
of four choices (post, reel, story, go live). Applied to `openapi.yaml` and CONVENTIONS as
**v1.41-social (draft)** — §11.1, §11.2, §11.3, §11.8 and §11.14.

## Why

CP-006 planned M2 (video posts and reels) behind Q1, the choice of a transcoding / delivery service
(Cloudflare Stream, Mux or FFmpeg workers). Nothing was chosen, so video never shipped: the Create
screen's «فيديو» tab was a dead "soon" segment and Moments' Reels mode showed its unavailable state.
The owner wants both now. This proposal ships video **without server-side transcoding**: the
server checks the file's container and limits and serves the bytes as uploaded. Transcoding (HLS,
bitrate ladders, re-encoding of odd codecs) stays a later step and needs no contract change for
clients that play `url`.

## Scope

In scope:

- Upload a video (MP4 or QuickTime) for a post or a reel, with a poster picture made on the phone
  (its first frame).
- Posts with one video; reels (`format: REEL`, one vertical video and a caption).
- A reels feed for Moments: Following (newest first, the caller's own reels included) and Trending
  (the §11.3 global score over reels — not personalised; personal ranking is M5).

Not in scope (recorded so nobody assumes otherwise):

- Server-side transcoding, HLS, adaptive bitrate, server-made thumbnails (later; CP-006 Q1).
- Video stories (stories stay photo-only, CP-008), video in direct messages and live chat.
- Trim, filters, music and editing tools (M6), duets / remixes, sounds pages.
- Personalised ranking (M5).
- Mixing photos and a video in one post.

## Proposed contract (v1.41-social, additive)

### 1. Media kinds and limits

`MediaKind` gains three values:

| Kind | Content types | `byteSize` | Length | Attaches to |
| --- | --- | --- | --- | --- |
| `POST_VIDEO` | `video/mp4`, `video/quicktime` | ≤ 209 715 200 (200 MiB) | 1–180 s → **1–90 s** (D168, v1.45-social) | a `POST` |
| `REEL_VIDEO` | `video/mp4`, `video/quicktime` | ≤ 104 857 600 (100 MiB) | 1–60 s | a `REEL` |
| `VIDEO_POSTER` | the image types | ≤ 15 MiB | — | a video (at `complete`) |

- `CreateMediaUploadRequest.byteSize` maximum becomes 209 715 200; images stay ≤ 15 MiB and voice
  clips ≤ 1 MiB (a larger value for those kinds → 400 `byteSize` / `too_big`). A video type for
  another kind, or another type for a video kind → 400 `contentType` / `invalid_value`.
- The presigned PUT signs `Content-Type` and `Content-Length`, so storage refuses other bytes.
- `completeMediaUpload` takes an optional body `CompleteMediaUploadRequest {posterId}`:
  **required** for a video kind (400 `posterId` / `required`), refused for every other kind
  (400 `posterId` / `unknown_field`). `posterId` is a READY, unattached `VIDEO_POSTER` asset of the
  caller, younger than 24 h (else 400 `posterId` / `invalid_value`; the slot stays open, so the
  app can retry with another poster).
- Completing a video checks, without decoding: HEAD size = `byteSize`; the container (top-level
  boxes read with ranged GETs: `ftyp` first, every box inside the file, a `moov` of at most 16 MiB
  and an `mdat`); `video/quicktime` ⇔ major brand `qt  `; the movie length from `moov/mvhd`
  (1 s up to the kind's maximum, + 500 ms encoder padding, reported clipped to the maximum); at
  least one video track (`hdlr` `vide`) whose sample entry is H.264 (`avc1`/`avc3`) or HEVC
  (`hvc1`/`hev1`); the display size from that track's `tkhd` (a 90°/270° matrix swaps width and
  height), each side 16–4 096 px. Anything else → 422 `MEDIA_INVALID` and the object is deleted.
- The bytes are copied unchanged (server-side copy) to `media/{mediaId}/video.mp4` or `.mov` with
  the declared type and an immutable cache header; the upload object is deleted. The poster's two
  WebP variants become the video's: the poster asset is consumed (it no longer exists on its own).
- `MediaAsset.type` gains `VIDEO`: `url` = the video file, `thumbUrl` = the poster at 320 px,
  new `posterUrl` = the poster at 1 080 px (VIDEO only), `blurhash` = the poster's, `width` /
  `height` = the video's display size, `durationMs` = its length (≤ 180 000; new post videos ≤ 90 000 since D168).
- A video asset is attachable once, by its owner, within 24 h, like every asset; never-attached
  videos (and posters) are swept with their objects.

### 2. Posts and reels

- `Post.format` gains `REEL`; `CreatePostRequest` gains `format` (`POST` default, or `REEL`).
- A `POST` carries text and/or either 1–10 `POST_IMAGE` assets **or** exactly one `POST_VIDEO`
  (a mix, two videos, or another kind → 400 `mediaIds` / `invalid_value`).
- A `REEL` carries exactly one `REEL_VIDEO` (none → 400 `mediaIds` / `required`; anything else →
  `invalid_value`) and an optional caption (the post text rules).
- Drafts, scheduling, edits, pins, likes, comments, saves, reposts, views, reports, hashtags,
  mentions, search and the moderation rule apply to reels exactly as to posts. **Moderation:**
  *(amended by D162a, v1.42-social, owner «جميعها تظهر فوراً»)* posts and reels with media are
  `VISIBLE` at once, like stories (D91); reports and `REMOVE_TARGET` are the safety net.
- `listFeedPosts` lists `POST` posts only; reels are listed by `listFeedReels`. Profile grids,
  saved, reposts, search and hashtag pages list both formats (each item carries `format`).

### 3. Reels feed

`GET /api/v1/feed/reels?tab=following|trending&cursor&limit` (`listFeedReels`, `PostPage`):

- `following`: reels of followed accounts and the caller's own, plus reels reposted by followed
  accounts, newest first (the §11.3 following rules, `format = REEL`).
- `trending`: the §11.3 score over visible public reels of the last 7 days (not the caller's,
  muted or hidden; ≤ 2 per author in any 10), frozen 10 minutes per caller.
- Rate limit: the `GET /feed/posts` bucket (300 / 15 min per user).

## Server settings

None new. Videos need `MEDIA_UPLOADS_ENABLED` and the `S3_*` settings like every upload; the
storage key also needs `CopyObject` (read on `uploads/`, write on `media/`) and ranged `GetObject`.

## Costs and risks

- No transcoding: a phone that cannot decode the uploaded codec (rare: HEVC on old Android) shows
  the poster and an error; the full-size file is streamed (egress cost ∝ file size).
- Moov-at-end files play after the player fetches the end of the file (R2 serves ranges).
- Moderation: no hold (D162a); reports and removal only, until a provider exists (B13).

## Amendment — D168 (2026-10-29, owner)

Owner, from the phone: «مدة ريلز لا تتجاوز ٦٠ ثانية، مدة الفيديو لا تتجاوز ٩٠ ثانية». A post video is
now 1–90 s (contract v1.45-social, CONVENTIONS §11.14); reels stay 1–60 s. Post videos already stored
keep their length; an unattached one longer than 90 s can no longer be attached. The 200 MiB size
limit is unchanged.
