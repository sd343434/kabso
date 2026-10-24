# CP-013 — Live room chat (DRAFT)

**Status:** draft for owner review, 2026-10-24. Not applied: `openapi.yaml`, `CONVENTIONS.md`.
The open questions at the end need the owner's answers before the contract is written.

## Why

Every live room (solo video, multi-guest and audio) has a chat pill and a message area, but they
say "Chat isn't open yet" because no chat contract exists. Talking to the host and to each
other is the main way viewers take part, next to taps (CP-012) and seats (CP-011).

## Scope

In scope:

- text messages in a live room, sent by people with an account and shown to everyone in the
  room, guests included;
- the recent messages when someone opens the room;
- "joined" lines when a signed-in viewer comes in;
- the host and moderators (CP-011) deleting a message and muting someone in this live's chat;
- the host turning the chat off and on;
- reporting a message.

Not in this proposal: gift lines (L3 adds them to the same stream), stickers, images, voice
notes, replies or reactions to a message, links that open, a profanity word list (Q7),
removing someone from the room (Q5), slow mode set by the host.

## How it works (summary)

1. The app sends a message to the API.
2. The API checks it (text rules, the sender may chat, limits), stores it, and sends it as a
   media data message to everyone in the room through LiveKit, which the room already uses
   for seats and the score.
3. Apps show it as it arrives. Opening the room loads the last messages from the API.

Apps never publish data to the media room themselves (`canPublishData` stays false), so every
line on screen went through the server's checks.

## Proposed contract (v1.9-live, additive; tag `live`)

### 1. Sending: `POST /live/rooms/{roomId}/chat`

```yaml
LiveChatSendRequest:
  required: [text, clientId]
  properties:
    text:     { type: string, minLength: 1, maxLength: 200 }
    clientId: { type: string, format: uuid } # chosen by the app; a retry with the same id returns the same message
```

- **Text:** NFC, trimmed, 1–200 code points (Q2), §6 hygiene, no line breaks.
- **Who:** signed-in users who are in the room now: the host, or someone in the room's media
  session (a `live_room_viewers` row, CP-010), which includes seated guests and moderators.
  Guests without an account cannot send (Q1).
- **Refused:**
  - 401 without an account;
  - 404 for an unknown room or one the caller may not see (a block with the host);
  - 409 `LIVE_ROOM_ENDED` once the room has ended;
  - 403 `LIVE_CHAT_NOT_IN_ROOM` when the caller is not in the room;
  - 403 `LIVE_CHAT_MUTED` when the host or a moderator muted the caller in this live;
  - 409 `LIVE_CHAT_CLOSED` when the host turned the chat off (the host can still send);
  - 400 for text that breaks the rules.
- **Answer:** 201 with the stored `LiveChatMessage`. A retry with the same `clientId` and the
  same sender returns 200 with the first message, and sends nothing again.

```yaml
LiveChatMessage:
  required: [id, roomId, author, text, createdAt, authorRole]
  properties:
    id:         { type: string, format: uuid }
    roomId:     { type: string, format: uuid }
    author:     { $ref: UserSummary }
    authorRole: { enum: [HOST, MODERATOR, SPEAKER, VIEWER] } # at the time of sending; the app badges host and moderators
    text:       { type: string }
    createdAt:  { type: string, format: date-time }
```

### 2. Reading: `GET /live/rooms/{roomId}/chat`

- Returns the **last 50** messages of this live, oldest first, without deleted ones.
  Unpaginated and server-bounded (CONVENTIONS §5). Older messages are not shown.
- Anyone who may watch the room may read, guests included when the room allows guests
  (CP-010).
- A signed-in reader never gets messages from people **they** blocked. The other direction (the
  author blocked the reader) is also filtered here, since the server knows both.

### 3. Live delivery (media data messages, topic `chat`)

Sent by the server to everyone in the media room, reliable, in send order:

| `type` | Payload | When |
| ------ | ------- | ---- |
| `chat` | `{"type":"chat","message":LiveChatMessage}` | a message was stored |
| `chat-delete` | `{"type":"chat-delete","id":…}` | a message was deleted |
| `join` | `{"type":"join","user":UserSummary}` | a signed-in viewer joined (from the CP-010 webhook or reconciliation); at most one a second per room, extras dropped (Q3) |
| `chat-state` | `{"type":"chat-state","enabled":bool}` | the host turned the chat off or on |

- The app hides `chat` and `join` lines whose author the reader blocked (it has the list from
  `GET /me/blocks`). A broadcast cannot be filtered per reader on the server; the only gap is
  the other direction (someone who blocked the reader still appears to them in live delivery).
- Apps that do not know a `type` ignore it.

### 4. Moderation

| Operation | Who | Effect |
| --------- | --- | ------ |
| `DELETE /live/rooms/{roomId}/chat/{messageId}` | the author, the host, a moderator | soft delete; `chat-delete` sent; 204, and 204 again when already deleted |
| `PUT /live/rooms/{roomId}/chat/mutes/{username}` | host, moderator | the user cannot send in this live; their earlier messages stay; 204 |
| `DELETE /live/rooms/{roomId}/chat/mutes/{username}` | host, moderator | unmute; 204 |
| `GET /live/rooms/{roomId}/chat/mutes` | host, moderator | the muted users of this live |
| `PATCH /live/rooms/{roomId}` `chatEnabled` | host | turns the chat off or on (Q4); `chat-state` sent |

- A moderator never mutes the host or another moderator, and never deletes their messages
  (403 `AUTH_FORBIDDEN`), as in CP-011.
- Mutes last for this live only. They are not a block.
- `LiveRoom` gains `chatEnabled` (boolean, default true) and, for the caller, `chatMuted`
  (boolean).
- **Reports:** `POST /reports` accepts `targetType: LIVE_CHAT_MESSAGE` (one OPEN report per
  reporter and message, §11.7). The admin queue (`MODERATION`) shows the text and the room;
  `REMOVE_TARGET` deletes the message.

### 5. Rate limits (CONVENTIONS §7)

| Endpoint | Limit |
| -------- | ----- |
| `POST /live/rooms/{roomId}/chat` | 20 / min per user, and at most 1 a second per user and room (a counting rule: 429 with `Retry-After`) |
| delete, mutes, `chatEnabled` | the CP-011 host and moderator bucket (300 / hour per user) |
| `GET /live/rooms/{roomId}/chat` | the per-user default; guests share the guest read limit (CP-010) |

### 6. Compatibility

Additive: new paths, fields, codes and data message types. Older apps keep the "not open yet"
pill and ignore the new data messages.

## Data (DB)

- `live_chat_messages`: `id` (uuid v7), `room_id` (FK), `user_id` (FK), `client_id`
  (unique per sender), `text`, `author_role`, `created_at`, `deleted_at`, `deleted_by_id`.
  Index (`room_id`, `created_at`).
- `live_chat_mutes`: (`room_id`, `user_id`) primary key, `muted_by_id`, `created_at`.
- `live_rooms.chat_enabled` boolean, default true.
- **Retention (Q6):** messages are deleted 30 days after their room ends, by the existing
  live sweeper, unless an OPEN report points at them (then they stay until it is closed).

## The app (not part of the contract)

- **Composer:** the chat pill opens the keyboard with a one-line field and a send button, a
  200-character counter near the limit, and the pill shows "Chat is off" or "You're muted in
  this live" when it applies.
- **Messages:** the bottom-left area of every live mode, newest at the bottom, the last ~50
  kept, older ones fading at the top. Each line: avatar, name (a Host or Moderator badge), the
  text. "Joined" lines are lighter and shorter.
- **Tap a line:** the user's card (view profile, follow); for the host and moderators also
  Delete and Mute in chat; for everyone Report.
- Sending shows the message at once as "sending" and replaces it with the server's copy; a
  failure keeps it with a retry.
- Arabic and English, RTL/LTR, mixed text direction per line (as in comments, D90).

## Open questions for the owner

- **Q1. Guests without an account:** they **read** the chat but cannot write. Recommended.
- **Q2. Message length:** **200** characters. Recommended (live chat moves fast; comments
  allow 500).
- **Q3. "Joined" lines:** show "X joined" for signed-in viewers, at most one a second per
  room. Recommended. Guests without an account are not announced.
- **Q4. Host can turn the chat off:** yes, with a switch in the host's room settings.
  Recommended.
- **Q5. Removing someone from the room** (kick, cannot come back to this live): useful with
  chat but it is its own change (media token refusal, seats). Recommended: a short follow-up
  proposal, not this one.
- **Q6. Keep messages 30 days** after the live ends, longer when reported. Recommended.
- **Q7. Word filter:** block a list of insults automatically? Not recommended now: lists in
  Arabic dialects are easy to get around and block normal words. Start with delete, mute and
  reports; revisit with real reports.

## Work (after approval)

1. Contract: `openapi.yaml` (v1.9-live), CONVENTIONS §4 codes, §7 rows, §9 changelog, a
   §10.11 section; board decision.
2. API: migration (two tables, a column), send/read/delete/mute endpoints, the
   `chatEnabled` field, data messages through the media provider, join lines from the
   webhook and reconciliation, reports target, retention in the sweeper; e2e tests (rules,
   in-room check, mute, closed chat, moderator limits, block filtering, idempotent retry, rate
   limits, real LiveKit delivery).
3. App: composer, message list for all three modes, line actions, block filtering, states,
   widget tests and goldens (Arabic, English, 360 dp), and a real two-browser run (two
   viewers and the host chatting, a delete and a mute).
