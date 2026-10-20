# CP-006 — Posts: media upload, photo and text posts, feeds, likes, comments, saves, shares

**Status:** proposal, 2026-10-20 (D87). Nothing is implemented until the owner answers §9 and
signs this off. It adds paths and schemas to `openapi.yaml` as contract **v1.5-posts**; it
changes no existing path, schema or error code. Phase 3 of `docs/IMPLEMENTATION_PLAN.md`.

**Out of scope here:** reels and video posts (Phase 5: transcoding and HLS, decided then),
stories (their own proposal), messaging, gifts. The app keeps their honest "unavailable" states;
with Demo data on (test builds, D86) they keep their test data.

## 1. Audit (what exists today, `kl-059`)

| Needed | Found |
| --- | --- |
| Object storage | Decided: S3-compatible, **Cloudflare R2** in the cloud (D45), **MinIO** locally (`dev-setup.sh --storage`). No credentials yet (**B12**); `MEDIA_UPLOADS_ENABLED=false`. No upload code. |
| Image moderation | Not chosen (**B13**). Rule already recorded: uploaded images are visible only to their owner until moderation exists. |
| Posts, likes, comments, saves | None (API and database). The app has the screens: Posts feed (Trending · Following), post tile, comments sheet, share sheet, profile grids (posts, saved). |
| Follow | v1.3: public accounts only; follow requests deferred (§10.6). |
| Report / block | None. |
| Cursor pagination, errors, rate limits | CONVENTIONS §4, §5, §7 — reused unchanged. |

## 2. Media upload (images only in v1.5)

Two-step presigned upload; the API never proxies bytes.

1. `POST /api/v1/media/uploads` `{kind: "POST_IMAGE", contentType: "image/jpeg"|"image/png"|"image/webp"|"image/heic", byteSize}` →
   `201 {uploadId, uploadUrl, method: "PUT", headers, expiresAt}` (URL valid 10 min, max
   **15 MB**). `503 MEDIA_UPLOADS_DISABLED` while `MEDIA_UPLOADS_ENABLED=false`.
2. The app `PUT`s the bytes to `uploadUrl`.
3. `POST /api/v1/media/uploads/{uploadId}/complete` → the server checks the object (size, magic
   bytes, decodes dimensions), strips EXIF/GPS, writes a 1080 px and a 320 px WebP, and returns
   `MediaAsset {id, width, height, blurhash, url, thumbUrl}`. An upload not completed in 24 h,
   or not attached to a post in 24 h, is deleted.

## 3. Posts

`Post {id, author: UserSummary, text, media: MediaAsset[] (0–10), location: string|null,
createdAt, editedAt|null, likeCount, commentCount, shareCount, viewerHasLiked, viewerHasSaved,
visibility: "PUBLIC", moderation: "VISIBLE"|"PENDING"|"REMOVED"}`

| Operation | Path |
| --- | --- |
| Create (text and/or 1–10 images, caption ≤ 2 200 chars, location optional) | `POST /api/v1/posts` (`Idempotency-Key` header) |
| Get one | `GET /api/v1/posts/{postId}` |
| Edit the caption and location (images are fixed) | `PATCH /api/v1/posts/{postId}` |
| Delete (author; soft delete, gone from every list) | `DELETE /api/v1/posts/{postId}` |
| A user's posts (profile grid) | `GET /api/v1/users/{username}/posts?cursor&limit` |

Visibility: a public account's posts are public; a private account's posts are seen only by the
author and existing followers. **Images** of a post stay `PENDING` (seen only by the author,
the post absent from feeds) until moderation clears them — see §9 Q1.

## 4. Feeds

`GET /api/v1/feed/posts?tab=trending|following&cursor&limit` → `PostPage` (CONVENTIONS §5).

- **Following:** posts of followed accounts, newest first.
- **Trending:** visible public posts of the last 7 days ranked by a score (§9 Q3); the cursor
  freezes the ranking snapshot for 10 minutes so pages never repeat or skip.
- The caller's own posts never appear in Trending; blocked/removed content never appears.

## 5. Likes, saves, shares

| Operation | Path |
| --- | --- |
| Like / unlike (idempotent) | `PUT` / `DELETE /api/v1/posts/{postId}/like` → `{liked, likeCount}` |
| Save / unsave (idempotent; private to the saver) | `PUT` / `DELETE /api/v1/posts/{postId}/save` |
| My saved posts (profile "Saved" grid) | `GET /api/v1/me/saved?cursor&limit` |
| Count a share (the app shares a link; the server only counts, once per user per post per day) | `POST /api/v1/posts/{postId}/shares` |
| Share link | `https://<web-host>/p/{postId}` (web landing page: a later phase) |

## 6. Comments

`Comment {id, author: UserSummary, text (1–500 chars), createdAt, likeCount, viewerHasLiked,
replyCount, parentId|null}` — one level of replies, as the comments sheet shows.

| Operation | Path |
| --- | --- |
| List (top level, newest first or top — §9 Q5) | `GET /api/v1/posts/{postId}/comments?cursor&limit` |
| Replies of a comment (oldest first) | `GET /api/v1/comments/{commentId}/replies?cursor&limit` |
| Add (or reply with `parentId`) | `POST /api/v1/posts/{postId}/comments` |
| Delete (its author, or the post's author) | `DELETE /api/v1/comments/{commentId}` |
| Like / unlike a comment | `PUT` / `DELETE /api/v1/comments/{commentId}/like` |

## 7. Safety (needed before posts are public to strangers)

- `POST /api/v1/reports {targetType: "POST"|"COMMENT"|"USER", targetId, reason}` (reasons: spam,
  nudity, violence, hate, harassment, illegal, other). Reports go to an admin queue
  (`GET /api/v1/admin/reports`, permission `MODERATION`), which can remove a post or comment.
- Rate limits (CONVENTIONS §7 style): posts 20/h, comments 60/h, likes 600/h, uploads 60/h per
  user.

## 8. Data (Prisma, one migration)

`media_assets`, `posts`, `post_media` (order), `post_likes`, `post_saves`, `post_share_events`,
`comments`, `comment_likes`, `reports`; counters kept on `posts`/`comments` in the same
transaction as the row change; soft delete with `deleted_at`. The runtime DB role gets the
usual least privileges (KL-013 style).

## 9. Owner decisions needed

| # | Question | Proposed default |
| --- | --- | --- |
| Q1 | Image moderation before photos are public (B13)? | Until a provider is chosen, photo posts are **visible only to their author**; text posts are public. Provider choice later (e.g. Hive, Rekognition, SafeSearch). |
| Q2 | Limits | Up to **10 images**, caption **2 200** chars, comment **500** chars, image **15 MB**. |
| Q3 | Trending score | `(likes + 2·comments + 3·shares + 1) / (hoursSincePost + 2)^1.5`, last 7 days. |
| Q4 | Can a caption be edited after posting? | Yes (caption and location; images fixed); shown as "edited". |
| Q5 | Comment order | Top comments first (by likes), then newest. |
| Q6 | Who may comment? | Everyone who can see the post. |
| Q7 | Private accounts | Their posts are seen by the author and existing followers only (no follow requests yet). |

## 10. Delivery plan once approved

1. Contract v1.5-posts in `openapi.yaml` + CONVENTIONS §11 (Redocly lint).
2. API: media (MinIO locally), posts, feeds, likes, saves, shares, comments, reports; e2e tests.
3. App: repositories and providers replacing the `FeedUnavailable` sources (posts feed,
   profile grids, saved, comments sheet, share count), the Create flow for photo and text
   posts, honest states for uploads disabled / pending moderation.
4. `docs/APP_MAP.md` updated: Posts tab, profile grids and comments become **API**.
