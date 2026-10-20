# CP-004 — Photos and videos in messages (PROPOSED, not approved)

**Status:** draft for owner/CTO review (D67). Not applied: `openapi.yaml`, `CONVENTIONS.md`,
`apps/api` and `apps/mobile` are unchanged by this document. The app can already pick and
show a photo or video on the device (D67); nothing is sent until this is approved and the
messaging API exists.

## Depends on

- The storage provider decision (S3-compatible adapter, currently disabled) and the
  moderation decision that keep uploads off in production.
- The messaging API (conversations and messages), not yet specified.

## Proposed flow (v1.5 candidate)

1. `POST /api/v1/media/uploads` `{ kind: "image" | "video", contentType, byteSize }` →
   `201 { uploadId, url, headers, expiresAt }`: a short-lived presigned PUT URL.
   Limits: images ≤ 15 MB (`image/jpeg|png|webp|heic`), videos ≤ 100 MB and ≤ 60 s
   (`video/mp4|quicktime|webm`). Over a limit → `422` with an issue code.
2. The app uploads the bytes directly to storage with the returned URL and headers.
3. `POST /api/v1/media/uploads/{uploadId}/complete` → `202`: the server checks type and size
   from the stored object (not the client's claim), strips EXIF location, transcodes videos
   and makes a poster frame, and runs moderation.
4. The message references the media: `POST …/messages { text?, mediaId }`. Until processing
   and moderation pass, the sender sees "Sending…" and the recipient sees nothing.

## Rules to agree

1. Rate limits per user (uploads per hour, total bytes per day).
2. Retention: media of deleted messages and unreferenced uploads are purged (proposed 24 h
   for unreferenced uploads).
3. Privacy: media URLs are signed and expire; no public listing.
4. Moderation outcome codes the app shows ("This photo can't be sent").
