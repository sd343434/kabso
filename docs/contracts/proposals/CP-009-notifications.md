# CP-009 — In-app notifications (CP-006 M4) (PROPOSED)

**Status:** proposed on 2026-10-21 for the owner's approval. Nothing is applied to `openapi.yaml`
or CONVENTIONS until it is approved.

## Why

The owner chose M4 next. Today nobody is told when someone likes their post, comments on it,
replies, mentions them, follows them or reposts them. CP-006 §10 sketched notifications. This
proposal turns that sketch into a contract for **in-app** notifications: an inbox, an unread
badge and per-type settings.

Push notifications to the phone are out of scope. They need a Firebase project and the APNs key
(CP-006 Q4), and will be added on top of this without changing it.

## Scope

In scope: in-app notifications for the actions that exist today (M1 and M3):

- likes on your posts and comments;
- comments on your posts, and replies to your comments;
- mentions in posts, comments and stories;
- new followers and reposts of your posts;
- your scheduled post was published;
- your post, comment or story was removed by moderation.

Not in scope:

- push notifications (Q4);
- email digests;
- follow requests (private accounts cannot be set yet);
- story views (the viewers list already covers them);
- live-stream notifications.

## Proposed contract (v1.5-social, additive; tag `notifications`)

### 1. `Notification`

```yaml
Notification:
  required: [id, type, actors, actorCount, target, createdAt, read]
  properties:
    id: uuid
    type: NotificationType
    actors: [UserSummary]   # the most recent ones, newest first, at most 3
    actorCount: integer     # all distinct actors in the group (≥ 1; 0 for system types)
    target: NotificationTarget | null
    createdAt: date-time    # the latest activity in the group
    read: boolean

NotificationType: LIKE_POST | LIKE_COMMENT | COMMENT | REPLY | MENTION | FOLLOW | REPOST |
                  POST_PUBLISHED | CONTENT_REMOVED

NotificationTarget:
  required: [type, id]
  properties:
    type: POST | COMMENT | STORY | USER
    id: string              # post, comment or story id; a username for USER
    postId: uuid | null     # for a COMMENT: its post (opens the post with its comments)
    thumbUrl: uri | null    # the post or story photo (320 px), when it has one
    text: string | null     # a short excerpt (≤ 80 characters) of the comment, or the caption
```

What each type means (the target is in brackets):

| Type | When | Target |
| --- | --- | --- |
| `LIKE_POST` | someone likes your post | POST |
| `LIKE_COMMENT` | someone likes your comment | COMMENT |
| `COMMENT` | someone comments on your post (top level) | COMMENT |
| `REPLY` | someone replies to your comment | COMMENT |
| `MENTION` | someone mentions you, if your `whoCanMention` allows it (§11.6) | POST, COMMENT or STORY |
| `FOLLOW` | someone follows you | USER |
| `REPOST` | someone reposts your post | POST |
| `POST_PUBLISHED` | your scheduled post went live (system, no actor) | POST |
| `CONTENT_REMOVED` | moderation removed your post, comment or story (system) | as removed; `thumbUrl` and `text` null |

### 2. Operations

| Operation | Path | Notes |
| --- | --- | --- |
| Inbox | `GET /api/v1/notifications` | `NotificationPage`, newest activity first, keyset cursor (§5). |
| Unread count | `GET /api/v1/notifications/unread-count` | `{count}`, capped at 99 (the badge shows "99+"). |
| Mark read | `POST /api/v1/notifications/read` | `{ids: [uuid] (1–100)}` or `{all: true}`; 204; idempotent. |
| Settings | `GET` / `PATCH /api/v1/me/notification-settings` | `{likes, comments, mentions, follows, reposts}`, all boolean, default `true`. |

### 3. Rules (new CONVENTIONS §11.10)

- **Never yourself:** your own actions on your own content notify no one.
- **Grouping:**
  - `LIKE_POST`, `LIKE_COMMENT` and `REPOST` on the same target group into one **unread**
    notification ("Sara and 12 others liked your post").
  - A group moves to the top on each new actor.
  - Once read, the next like starts a new group.
  - The other types never group.
- **Undo:** unliking, un-reposting, unfollowing, or deleting the comment or post removes that
  actor's contribution. A group or notification left with no actor is deleted. Deleted or removed
  targets drop their notifications.
- **Safety:**
  - no notification is created between two users with a block in either direction;
  - existing ones are hidden while the block exists;
  - an account that is no longer ACTIVE is left out of `actors` and counts;
  - a group with no visible actor is hidden.
- **Settings:** a type switched off creates no new notifications. `COMMENT` and `REPLY` share
  `comments`, and `LIKE_*` share `likes`. System types (`POST_PUBLISHED`, `CONTENT_REMOVED`)
  are always on.
- **Retention:** notifications older than 90 days are deleted by a sweeper.
- **Delivery:** in-app only, with no realtime channel. The app refreshes the unread count when
  it comes to the foreground and every 60 seconds while it is open.
- **Rate limits:** `GET /notifications` and the unread count share the feed rule (300 / 15 min);
  `POST /notifications/read` is limited to 120 / hour.

### 4. Compatibility

The change is additive: a new tag, paths and schemas; existing endpoints are unchanged.
Notifications are written in the same transaction as the action that causes them, so they never
point at something that did not happen. Database changes:

- a `notifications` table: recipient, type, target columns, `group_key`, `read_at` and
  `updated_at`, with indexes on (recipient, updated_at desc, id) and on
  (recipient, `group_key`) for unread rows;
- a `notification_actors` table (notification, actor, created_at);
- a `notification_settings` table (one row per user, created on first change).

## Open questions for the owner

- **Q1 — Muted accounts.** A mute today hides posts and stories. Should a muted account also not
  be able to notify you?
  - **Recommendation:** yes; a mute silences them in notifications too. They are never told.
- **Q2 — Grouping.** Group likes and reposts on the same item while unread (as above), or never
  group?
  - **Recommendation:** group them, to keep the inbox short.
- **Q3 — Retention.** Should notifications be kept for 90 days?
  - **Recommendation:** yes. The inbox is not an archive, and older activity stays visible on
    the posts themselves.

## Work if approved

1. **Contract:**
   - `openapi.yaml`: the `notifications` tag, paths and schemas;
   - CONVENTIONS §11.10 and the changelog row;
   - a Decision Log entry.
2. **API:**
   - schema, migration and grants;
   - a notifications module with an internal `Notifier` that the existing services call inside
     their transactions (likes, comments, replies, mentions, follow, repost, scheduled publish,
     moderation);
   - undo handling, grouping, settings and the sweeper;
   - e2e tests for every rule above.
3. **App:**
   - a bell with an unread badge on the Posts header;
   - a Notifications screen grouped by Today, This week and Earlier, where tapping opens the
     post (with its comments), the story or the profile, and the list is marked read;
   - a Notifications settings page in Settings;
   - polling of the unread count;
   - tests, RTL/LTR checks and real-app captures.
