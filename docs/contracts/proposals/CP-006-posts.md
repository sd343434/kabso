# CP-006 — Posts, reels and stories (complete social content)

**Status:** proposal v2, 2026-10-20 (D87). v1 covered photo/text posts only; the owner asked for
the full scope (video and reels, stories, hashtags and mentions, drafts/scheduling/pinning,
notifications, block/mute/hide, author controls, likers and views, sharing in messages and
reposts, a personalised Trending, locations and photo editing, and a web page for links).
Nothing is implemented until the owner answers §15 and signs this off. It adds contract
**v1.5-social** to `openapi.yaml`; it changes no existing path, schema or error code.

Delivery is split into milestones (§14) so each is reviewable and shippable on its own.

## 1. Audit (what exists today, `kl-059`)

| Needed | Found |
| --- | --- |
| Object storage | Decided: S3-compatible, **Cloudflare R2** (D45); **MinIO** locally. No credentials (**B12**). No upload code. |
| Video transcoding / CDN | Not decided (`SYSTEM_ARCHITECTURE.md`: FFmpeg worker or a managed service, "decided at Phase 5"). |
| Image / video moderation | Not chosen (**B13**). Rule recorded: uploads are visible only to their owner until moderation exists. |
| Push notifications | None (no FCM/APNs project or keys). |
| Background jobs | In-process `BackgroundTasks` only; no queue (BullMQ + Redis is the documented plan). |
| Messaging | None (no API). The designed screens exist (D61, D67–D70). |
| Posts, reels, stories, comments, likes, saves | None in API/DB. The app has every screen: feed, reel pager, stories tray, comments and share sheets, profile grids. |
| Follow | v1.3: public accounts; follow requests deferred. |
| Report / block / mute | None. |
| Web | No web landing site. |

## 2. Media (images and video)

Presigned two-step upload; the API never proxies bytes.

1. `POST /api/v1/media/uploads {kind, contentType, byteSize, durationMs?}` →
   `201 {uploadId, uploadUrl, method, headers, expiresAt}`.
   Kinds: `POST_IMAGE`, `POST_VIDEO`, `REEL_VIDEO`, `STORY_IMAGE`, `STORY_VIDEO`.
   `503 MEDIA_UPLOADS_DISABLED` while `MEDIA_UPLOADS_ENABLED=false`.
   Large videos use multipart upload (`parts[]` URLs, `POST …/complete {parts}`).
2. The app uploads to the URL(s).
3. `POST /api/v1/media/uploads/{uploadId}/complete` →
   - **image**: checked (magic bytes, size, dimensions), EXIF/GPS stripped, WebP 1080 px and
     320 px, blurhash → `MediaAsset {status: READY}`;
   - **video**: queued for transcoding → `MediaAsset {status: PROCESSING}`; becomes `READY`
     with an HLS URL (adaptive 240p–1080p), an MP4 fallback, a cover frame and `durationMs`, or
     `FAILED` with a reason. `GET /api/v1/media/{mediaId}` reports the status; a notification
     (§10) says when it is ready.
4. Unattached uploads are deleted after 24 h.

`MediaAsset {id, type: IMAGE|VIDEO, status, width, height, durationMs?, blurhash, url,
thumbUrl, hlsUrl?, coverUrl?}`.

Client-side editing before upload (§12): crop and aspect (1:1, 4:5, 16:9 for posts; 9:16 for
reels and stories), filters and adjustments, video trim. The server receives the edited file.

## 3. Posts and reels

One `Post` model; a **reel** is a post with `format: REEL` (one vertical video, 3–90 s, §15).

`Post {id, format: POST|REEL, author: UserSummary, text, media: MediaAsset[], location: Place|null,
hashtags[], mentions: UserSummary[], createdAt, publishedAt, editedAt|null, status:
DRAFT|SCHEDULED|PUBLISHED, pinned, likeCount|null (null when the author hides it), commentCount,
shareCount, repostCount, viewCount, viewerHasLiked, viewerHasSaved, viewerHasReposted,
settings: {commentsEnabled, whoCanComment: EVERYONE|FOLLOWERS|NOBODY, hideLikeCount},
moderation: VISIBLE|PENDING|REMOVED, repostOf: PostSummary|null}`

| Operation | Path |
| --- | --- |
| Create (post: text and/or 1–10 images/videos; reel: one video) — `status` `PUBLISHED`, `DRAFT` or `SCHEDULED` with `publishAt` | `POST /api/v1/posts` (`Idempotency-Key`) |
| Get one | `GET /api/v1/posts/{postId}` |
| Edit caption, location, settings; publish or reschedule a draft | `PATCH /api/v1/posts/{postId}` |
| Delete (soft) | `DELETE /api/v1/posts/{postId}` |
| My drafts / scheduled | `GET /api/v1/me/posts?status=DRAFT|SCHEDULED` |
| Pin / unpin on my profile (max 3) | `PUT` / `DELETE /api/v1/posts/{postId}/pin` |
| A user's posts / reels grid (pinned first) | `GET /api/v1/users/{username}/posts?format=POST|REEL` |
| Repost / undo (shows in the reposter's followers' feed and a "Reposts" profile tab) | `PUT` / `DELETE /api/v1/posts/{postId}/repost` |
| Record views (batched by the app: ≥ 1 s visible for posts, ≥ 2 s or 50 % for reels; once per user per post per 24 h) | `POST /api/v1/views {items:[{postId, watchedMs}]}` |
| Who liked (cursor list; hidden to others when the author hides likes) | `GET /api/v1/posts/{postId}/likes` |

Scheduled posts are published by a worker at `publishAt` (±1 min).

## 4. Hashtags and mentions

- Parsed by the server from captions and comments (`#tag`: Arabic and Latin letters, digits and
  `_`, max 30 per post; `@username`, max 20).
- `GET /api/v1/hashtags/{tag}` (post count) and `GET /api/v1/hashtags/{tag}/posts?sort=top|recent`.
- `GET /api/v1/search?q=&type=users|hashtags|posts` (prefix search; full-text later).
- A mention notifies the user (§10) unless they blocked the author; users can limit who may
  mention them (`EVERYONE|FOLLOWING|NOBODY`, §9).

## 5. Feeds

| Feed | Path | Content |
| --- | --- | --- |
| Posts · Following | `GET /api/v1/feed/posts?tab=following` | Posts and reposts from followed accounts, newest first. |
| Posts · Trending (personalised) | `GET /api/v1/feed/posts?tab=trending` | §6. |
| Reels · Following / Trending | `GET /api/v1/feed/reels?tab=…` | Same rules, reels only. |

Cursors freeze a ranking snapshot for 10 minutes (no repeats or gaps). Never shown: blocked or
muted authors, hidden posts, `PENDING`/`REMOVED` content, private accounts' posts to
non-followers.

## 6. Personalised Trending (ranking v1)

`score = quality × freshness × affinity`, computed for candidates from the last 7 days:

- **quality** = `(likes + 2·comments + 3·shares + 2·saves + 1.5·completedViews + 1) / (views + 10)`
  (engagement per view, so small new posts can surface);
- **freshness** = `1 / (hoursSincePublished + 2)^1.2`;
- **affinity** = `1 + 0.5·(the viewer follows the author) + 0.3·(viewer interacted with the
  author in 30 days) + 0.2·(shared hashtags with the viewer's last 50 likes)`;
- diversity: at most 2 posts of the same author per 10 results; "Not interested" (§9) removes
  the post and lowers that author and hashtag for the viewer for 30 days.

Weights are server configuration (versioned like level configs), not hard-coded; a cold-start
viewer gets the global ranking (affinity 1).

## 7. Comments

`Comment {id, author, text (1–500), createdAt, likeCount, viewerHasLiked, replyCount, parentId,
mentions, pinnedByAuthor}`; one level of replies.

| Operation | Path |
| --- | --- |
| List (top first, then newest) / replies | `GET /api/v1/posts/{postId}/comments`, `GET /api/v1/comments/{commentId}/replies` |
| Add / reply | `POST /api/v1/posts/{postId}/comments` |
| Delete (its author, or the post's author) | `DELETE /api/v1/comments/{commentId}` |
| Like / unlike | `PUT` / `DELETE /api/v1/comments/{commentId}/like` |
| Pin one comment (post author) | `PUT` / `DELETE /api/v1/comments/{commentId}/pin` |

Comment rules follow the post's `settings` (§3): off, followers only, or everyone.

## 8. Stories

`Story {id, author, media: MediaAsset (image ≤ 15 MB or video ≤ 60 s), text overlay, mentions,
createdAt, expiresAt (+24 h), viewCount (author only), viewerHasSeen}`

| Operation | Path |
| --- | --- |
| Post / delete | `POST /api/v1/stories`, `DELETE /api/v1/stories/{storyId}` |
| Tray (followed accounts with active stories; unseen first) | `GET /api/v1/feed/stories` |
| A user's active stories | `GET /api/v1/users/{username}/stories` |
| Mark seen | `POST /api/v1/stories/{storyId}/seen` |
| Who saw (author only, 48 h) | `GET /api/v1/stories/{storyId}/viewers` |
| Reply (becomes a direct message — needs messaging, CP-007) | `POST /api/v1/stories/{storyId}/replies` |

Expired stories disappear from every list; the author keeps them in a private archive
(`GET /api/v1/me/stories/archive`).

## 9. Safety and privacy

| Operation | Path |
| --- | --- |
| Block / unblock (both sides stop seeing each other; follow edges removed) | `PUT` / `DELETE /api/v1/users/{username}/block`, `GET /api/v1/me/blocks` |
| Mute / unmute (their posts and stories leave my feeds; they are not told) | `PUT` / `DELETE /api/v1/users/{username}/mute?scope=posts|stories|all` |
| Hide a post / "Not interested" | `PUT /api/v1/posts/{postId}/hide {reason: HIDE|NOT_INTERESTED}` |
| Report post, reel, story, comment or user | `POST /api/v1/reports` |
| Admin moderation queue (permission `MODERATION`) | `GET /api/v1/admin/reports`, `POST /api/v1/admin/reports/{id}/actions` |
| Privacy settings (who can mention me, comment on my posts by default, see my likes) | `PATCH /api/v1/me/privacy` |

Rate limits (CONVENTIONS §7): posts 20/h, stories 30/h, comments 60/h, likes 600/h, uploads
60/h, reports 30/h per user.

## 10. Notifications

`Notification {id, type, actor: UserSummary, target: {type, id, thumbUrl}, createdAt, read}`;
types: `LIKE_POST`, `LIKE_COMMENT`, `COMMENT`, `REPLY`, `MENTION`, `FOLLOW`, `REPOST`,
`MEDIA_READY`, `MEDIA_FAILED`, `SCHEDULED_PUBLISHED`, `POST_REMOVED`. Likes on the same target
are grouped ("Layla and 12 others").

| Operation | Path |
| --- | --- |
| Inbox / unread count / mark read | `GET /api/v1/notifications`, `GET /api/v1/notifications/unread-count`, `POST /api/v1/notifications/read {ids|all}` |
| Push token (FCM on Android and iOS) | `PUT` / `DELETE /api/v1/me/push-tokens/{token}` |
| Preferences per type (in-app / push) | `GET` / `PATCH /api/v1/me/notification-settings` |

The app gets a Notifications screen (bell on the Posts header) and a badge.

## 11. Sharing

- **In the app:** share a post, reel or story to one or more conversations (a message carrying
  a post card) — `POST /api/v1/posts/{postId}/send {conversationIds|usernames}`; needs
  messaging (**CP-007**, to be proposed next). Until then the button shows "coming soon".
- **Outside:** `https://kabso.app/p/{postId}` (§13), share count `POST /api/v1/posts/{postId}/shares`.
- **Repost:** §3.

## 12. Location and editing

- Places: `GET /api/v1/places/search?q=&lat=&lng=` → `Place {id, name, city, country}` from a
  places provider (§15 Q6); the post stores the place, never the user's coordinates.
- `GET /api/v1/places/{placeId}/posts`.
- Photo editing in the app: crop/rotate, aspect presets, 12 filters, brightness / contrast /
  saturation / warmth; video: trim, cover frame, mute. Done on the device (no server cost).

## 13. Web page for links

A small server-rendered page at `https://kabso.app/p/{postId}` (and `/r/{postId}`,
`/u/{username}`): public posts show the media, caption and author with Open Graph tags for
previews, and "Open in the app" (Android App Links / iOS Universal Links); private, removed
or pending posts show a neutral "not available" page. Lives in `apps/web` (new, minimal).

## 14. Milestones (each: contract → API + tests → app → captures → owner review)

| M | Scope | External needs |
| --- | --- | --- |
| **M1** | Media (images), posts (photo/text), drafts, scheduling, pinning, feeds (Following + global Trending), likes + likers, saves, comments + pins, hashtags, mentions, search, reposts, views, author controls, block / mute / hide, reports + admin queue, privacy settings | MinIO locally; R2 (B12) for phones |
| **M2** | Video: posts with video and **reels** (upload, transcoding, HLS playback, reel feeds) | Transcoding/CDN choice (Q1) |
| **M3** | Stories (tray, viewer, seen, viewers, archive) | M2 for video stories |
| **M4** | Notifications: inbox, badge, settings, push | Firebase project (Q4) |
| **M5** | Personalised Trending (§6) and "Not interested" | — |
| **M6** | Places and photo/video editing | Places provider (Q6) |
| **M7** | Share to messages, story replies; web link pages | CP-007 messaging; web domain (Q7) |

## 15. Owner decisions needed

| # | Question | Proposed default |
| --- | --- | --- |
| Q1 | Video transcoding and delivery | **Cloudflare Stream** (fits R2/Cloudflare, per-minute pricing, HLS + thumbnails); alternative: Mux, or self-hosted FFmpeg workers (cheapest, most ops). |
| Q2 | Moderation before media is public (B13) | Until a provider is chosen, photos and videos are seen **only by their author**; text is public. Candidates: Hive, AWS Rekognition, Google SafeSearch. |
| Q3 | Limits | Post: 10 items, caption 2 200; image 15 MB; post video ≤ 10 min / 1 GB; reel 3–90 s; story video ≤ 60 s; comment 500; 3 pins; 30 hashtags; 20 mentions. |
| Q4 | Push | Firebase Cloud Messaging for Android and iOS (needs a Firebase project and the APNs key). |
| Q5 | Trending weights | As in §6, adjustable by admins later. |
| Q6 | Places provider | **OpenStreetMap / Photon** (free) first; Google Places later if quality needs it. |
| Q7 | Web domain for links | `kabso.app` (or the domain you own). |
| Q8 | Editing and visibility | Caption editable (shown "edited"); private accounts: author + existing followers; comments: everyone who can see the post by default. |
| Q9 | Messaging next | Propose **CP-007 messaging** right after M1 so M7 can follow. |
