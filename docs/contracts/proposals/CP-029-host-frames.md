# CP-029 — The active-host frame «إطار المضيف»

**Status: OWNER DECISIONS (2026-10-30, chat, relayed by the coordinator) — built in D186 (contract
v1.55-social, CONVENTIONS §10.49).** The coordinator's proposal was accepted by the owner; the wording stays
in the coordinator's spec (scratch, not in git). This file records the decisions, the defaults we chose where
the owner was silent, and the questions for the owner.

## 1. Owner decisions

| Topic | Decision (owner) |
|-------|------------------|
| Who | Free for **active hosts** only: ≥ 7 live days and ≥ 10 live hours in the last 30 days — the same definition as D179. Kept while active; taken back automatically when no longer active (the existing sweeper / rank evaluation); given again when active again. |
| Gender (D175) | Male → the blue frame, female → the pink frame. «أفضّل عدم الذكر» or no gender → the host chooses one of the two. |
| Wearing | The host chooses to wear it from the bag (D171 / D180), alongside the support frames (and the recharge-agent frame). |
| Sending | Not sendable. |
| Name | No name under the frame. |
| Art | Two owner-supplied AI-generated Kabso frames (blue, pink); may enter git (`apps/mobile/assets/host_frames/PROVENANCE.md`). |

## 2. Choices made (CTO defaults, changeable)

1. **A bag item, not a derived perk:** unlike the recharge-agent frame (D185, derived from the status and
   always shown), the host frame is a bag `AVATAR_FRAME` with the new source `HOST_ACTIVE` so the host can wear
   or remove it like any frame. It has no expiry while kept, is not transferable, and `bag-admin` cannot give or
   take it.
2. **"Host" = an ACTIVE agency host:** D179's active-host test is defined on agency hosts, so a user who goes
   live without an agency does not get the frame. *(Owner question 1.)*
3. **Reuse, not a second clock:** the frame follows `hostActivity` (the same SQL the rank evaluation uses), run
   by the agency sweeper right after the ranks (hourly by default), by `economy-admin agency-evaluate`, and at
   once for the one host after joining or leaving an agency, a resolved complaint, a gender change or a choice.
   Becoming active through a new live is picked up by the next sweep (up to an hour).
4. **Revoked while worn:** taken off with it; nothing else is put on. Given again: not worn (a grant never
   changes what the user wears, as D107/D169).
5. **No gender:** no frame until the host picks a colour; the bag shows «اختر لون إطار المضيف» to an active host
   who has not chosen, and «تغيير اللون» afterwards. The choice can be made any time and changed later; a stated
   gender always wins over a stored choice. A gender change swaps the frame and keeps it worn.
6. **Where it is drawn:** the worn avatar frame is public (`PublicProfile.avatarFrame`, `UserSummary.avatarFrame`):
   own and public profiles, the audio room's seats and the host's seat. On the profile an ACTIVE recharge agent's
   agent frame (with the code) wins over a worn bag frame. *(Owner question 2.)*
7. **Art size:** like the support frames — trimmed, centred on a square, 256 × 256 WebP with alpha; the photo
   circle measured from the alpha channel. *(Owner question 3.)*

## 3. Not built (honest)

- Drawing the support-tier frames (D169) around photos: the API now carries any worn frame, but the app draws
  only the frames whose photo circle it knows (the host frames); a worn support frame is shown in the bag only,
  as before.
- The frame on video-room tiles (the camera fills the tile) and in chat rows / lists.
- A notification when the frame is given or taken back.

## 4. Questions for the owner

1. Should a host who goes live without an agency also count as an active host (and get the frame)?
2. A recharge agent who also wears a host frame: the agent frame (with the code) on the profile (default), or
   the frame they wear?
3. The frames are 256 px like the support frames; on the profile at @3x they are drawn about 2× larger than the
   art. Send a larger version or keep 256 px?
4. Notify the host when the frame is given or taken back?
