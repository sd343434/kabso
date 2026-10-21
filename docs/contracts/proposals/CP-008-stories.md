# CP-008 — Stories with photos (CP-006 M3) (APPROVED)

**Status:** approved by the owner on 2026-10-21 (D91) with two decisions that differ from or
settle the open questions below: **Q1 — story photos are visible at once** (no moderation hold;
safety relies on reports and the 24-hour expiry), and **Q2 — the existing mute also hides
stories** (no separate option). Applied to `openapi.yaml` (v1.5-social, draft) and CONVENTIONS
§11.1, §11.7, §11.8 and §11.9. Because of Q1 the `Story.moderation` field below is not part of
the applied contract.

## Why

The owner chose M3 (stories) as the next milestone after M1. CP-006 §8 sketched stories. This
proposal turns the sketch into a contract for **photo stories**. Photo stories need no outside
service. Video stories follow with M2, which waits on Q1, and replies follow with M7, which waits
on messaging.

The app already has the stories tray on the Posts page. It is shown only with demo data. Nothing
serves stories, and there is no viewer.

## Scope

In scope:

- Post and delete a photo story, with an optional short text.
- The tray, a user's active stories, mark seen, who saw it, and the author's archive.
- Report a story.
- Mute, block and privacy rules for stories.

Not in scope:

- Video stories (M2).
- Story replies and sharing a story into messages (M7).
- Highlights, stickers, polls, music and close friends.
- Story editing tools (M6).

## Proposed contract (v1.5-social, additive)

### 1. Media

- `MediaKind` gains **`STORY_IMAGE`**. It uses the same upload, checks and EXIF stripping as
  `POST_IMAGE` (CONVENTIONS §11.1). One difference: `url` is WebP **at most 1 920 px on the long
  side** (`media/{id}/1920.webp`), so a full-screen 9:16 photo stays sharp. `thumbUrl` stays
  320 px. A `STORY_IMAGE` asset can be attached only to a story, and a `POST_IMAGE` asset only to
  a post (otherwise 400 `mediaId` / `invalid_value`).

### 2. `Story`

```yaml
Story:
  required: [id, author, media, text, mentions, createdAt, expiresAt, viewerHasSeen, isSelf,
             viewCount, moderation]
  properties:
    id: uuid
    author: UserSummary
    media: MediaAsset            # one photo
    text: string                 # "" when none; ≤ 200 code points, §6 hygiene, ≤ 3 line breaks
    mentions: [UserSummary]      # parsed from text (§11.6 rules, at most 10)
    createdAt: date-time
    expiresAt: date-time         # createdAt + 24 h
    viewerHasSeen: boolean       # always true for the author's own stories
    isSelf: boolean
    viewCount: integer | null    # the author only; null for everyone else
    moderation: VISIBLE | PENDING  # PENDING only ever reaches the author (Q1)
```

### 3. Operations

| Operation | Path | Notes |
| --- | --- | --- |
| Post | `POST /api/v1/stories` | `{mediaId, text?}` and an `Idempotency-Key` header (as `createPost`). Returns 201 `Story`. |
| Delete (author) | `DELETE /api/v1/stories/{storyId}` | Soft delete; it leaves every list and the archive. Returns 204, or 404 when already gone. |
| Tray | `GET /api/v1/feed/stories` | `StoryTrayPage {data: [StoryTrayItem], page}`. |
| A user's active stories | `GET /api/v1/users/{username}/stories` | Oldest first, not paged (at most 100 a day). 404 when not visible (private and not followed, or a block). |
| One story | `GET /api/v1/stories/{storyId}` | For links from mentions. 404 when expired (except for the author) or not visible. |
| Mark seen | `PUT /api/v1/stories/{storyId}/seen` | Idempotent. Returns 204. Never counts for the author. |
| Who saw (author) | `GET /api/v1/stories/{storyId}/viewers` | `UserSummaryPage`, newest view first. Available until 48 h after posting; then 404. Others → 404. |
| Archive (author) | `GET /api/v1/me/stories/archive` | `StoryPage`, newest first, active and expired. Kept until the author deletes them. |
| Report | `POST /api/v1/reports` | `targetType` gains **`STORY`**. Admin `REMOVE_TARGET` removes the story (soft, audited). |

The tray item:

```yaml
StoryTrayItem:
  required: [user, storyCount, hasUnseen, latestAt]
  properties:
    user: UserSummary
    storyCount: integer      # active stories
    hasUnseen: boolean       # any active story the caller has not seen
    latestAt: date-time      # newest active story
```

### 4. Rules (new CONVENTIONS §11.9)

- **Active** means not deleted and `expiresAt` is in the future. Expired stories leave every
  list except the author's archive. A worker deletes their media 30 days after expiry, unless
  they are kept in the archive. The archive keeps the media until the author deletes the story.
- **Visibility** follows the post rules (§11.2): the author is ACTIVE, there is no block in either
  direction, and the author is public or followed by the caller. Not visible → 404.
- **Tray**:
  - the caller's own entry comes first when they have an active story;
  - then followed accounts with active stories, unseen ones first, each group newest first;
  - muted accounts (§11.7) are left out;
  - paged by the shared cursor.
- **Seen**: one row per viewer and story. `viewCount` counts distinct viewers other than the
  author.
- **Text**: hashtags in story text are plain text (no hashtag pages for stories). Mentions follow
  `whoCanMention`.
- **Rate limits**: `POST /stories` 30 / hour; `PUT …/seen` 600 / hour; `GET /feed/stories`
  300 / 15 min. `STORY_IMAGE` uploads share the 60 / hour upload bucket.

### 5. Compatibility

The change is additive: new paths, new schemas, and new enum values (`MediaKind.STORY_IMAGE`,
report `targetType: STORY`). Existing clients ignore all of them. Database changes:

- a `stories` table with indexes on `(author_id, expires_at)` and `(created_at)`;
- a `story_views` table with primary key `(story_id, viewer_id)` and an index on `(story_id, seen_at desc)`;
- one new value in each of the media kind and report target enums.

## Open questions for the owner

- **Q1 — Moderation of story photos.** Until a moderation provider is chosen (CP-006 Q2, B13),
  photo **posts** stay author-only (`PENDING`). If stories follow the same rule, nobody else can
  see a photo story until a provider exists.
  - **Recommendation:** keep the same rule for safety.
  - Choosing a provider (B13) then turns on posts and stories together.
  - The alternative is to show story photos immediately, relying on reports and the 24-hour
    expiry. That is a product and safety decision for you.
- **Q2 — Mute scope.** CP-006 §9 sketched `mute?scope=posts|stories|all`. Today a mute hides
  posts only.
  - **Recommendation:** a mute also hides the account's stories, with no new parameter.
  - A separate "mute stories only" option can come later.

## Work if approved

1. **Contract:**
   - `openapi.yaml`: paths, schemas and enum values;
   - CONVENTIONS §11.9 and the changelog row;
   - a Decision Log entry.
2. **API** (`apps/api`):
   - schema, migration and runtime grants;
   - the 1920 px variant for `STORY_IMAGE`;
   - a stories module (create, delete, tray, user stories, one story, seen, viewers, archive);
   - reports `STORY`;
   - the expiry sweeper;
   - e2e tests for every rule above.
3. **App** (`apps/mobile`):
   - the real tray on the Posts page (own entry with "+" first);
   - a full-screen viewer: progress bars, tap and hold, swipe to the next user, mark seen,
     delete, report, and viewers for the author;
   - Create gains a "Story" step: one photo plus optional text;
   - an archive screen;
   - tests, RTL/LTR checks and real-app captures.
