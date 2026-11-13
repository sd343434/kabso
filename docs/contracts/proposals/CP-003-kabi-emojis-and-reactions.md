# CP-003 — Kabi emojis in messages, comments and live reactions (PROPOSED, not approved)

**Status:** draft for owner/CTO review (D66). Not applied: `openapi.yaml`, `CONVENTIONS.md`,
`apps/api` and `apps/mobile` are unchanged by this document. The app already renders the
emojis (D66); nothing can be sent until this, and the APIs it extends, exist.

## Why

The owner wants the animated Kabi emojis in comments, private chat, the voice live and the
live room (D66). The contract has none of those surfaces yet (no messaging, comments, live
chat or reactions endpoints), so this proposal fixes how an emoji travels once they exist.

## 1. Emojis inside text (messages, comments, live chat)

An emoji is the token `:kabi_<id>:` inside the ordinary text field, with `<id>` one of:
`hi love lol wow sad angry wink live cool dizzy sleepy silly shy think party dead melt kiss`.

- The server stores and returns the text unchanged; no separate emoji field.
- Validation: a token counts as **one** character towards the text's length limit; an unknown
  id is plain text (shown as typed). At most 30 tokens per text.
- Moderation and search see the token as a word (e.g. `:kabi_love:`).
- Older clients without the emojis show the token as text, which stays readable.
- New emojis are added by extending the id list (a minor contract version); ids are never
  reused or renamed.

## 2. Live reactions (live room and voice live)

A reaction is a lightweight event, not a chat line:

`POST /api/v1/live/rooms/{roomId}/reactions` `{ "emoji": "<id>" }` → `202`

- Rate limit per viewer (proposed: 5 per second, burst 10); over the limit → `429` with
  `Retry-After`, the app simply stops sending.
- Fan-out to viewers through the room's realtime channel (designed with the live chat);
  clients aggregate bursts ("+12") instead of drawing every one.
- Not stored beyond the room's lifetime; counts per emoji may be kept for the host's summary.
- Only signed-in viewers of a live room; blocked users are dropped silently.

## Open questions for the owner

1. Should reactions also exist on posts and comments (like counts per emoji), or only "like"?
2. Voice live: same reaction endpoint, or part of the voice room design when it is specified?
