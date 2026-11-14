# CP-025 — Profile fields, private accounts and follow requests

**Status: APPROVED (owner, 2026-10-30, Arabic, answering D168's open questions a–g) — built in D175
(contract v1.47-social draft, CONVENTIONS §10.47).** v1.43–v1.46-social may be taken by parallel
branches; this change uses **v1.47-social**. (Written as §10.43; renumbered §10.47 at integration: D169 took §10.43, D170 §10.44, D171 §10.45 and D179 §10.46.) If another branch has already taken CP-025,
renumber this file and section at merge time; nothing else depends on the numbers.

## The owner's answers (D168 a–g)

| D168 question | Answer (owner) | Contract |
| --- | --- | --- |
| (b) Gender | «ذكر / أنثى / أفضّل عدم الذكر». Chosen **at sign-up** (required, the third option available); existing users have none until they set it. **Private by default**; the user may show it on the profile. Editable in Edit profile. | `Gender`; `RegisterRequest.gender` (required); `updateMe` `gender`, `showGender`; `Me.gender`, `Me.showGender`; `PublicProfile.gender` (only when shown) |
| (c) Links | Up to **3**, https only. Known domains (Instagram, TikTok, YouTube/youtu.be, Facebook/fb.com, X/Twitter, any subdomain) open directly; any other link opens only after a warning «أنت تغادر Kabso» with the full URL. Links are reportable. The server validates (https, length, no credentials, no IP hosts, normalised); a label is optional. | `ProfileLinkInput`, `ProfileLink`, `ProfileLinkPlatform`; report target `PROFILE_LINK` |
| (d) Account category | مغنٍّ، موسيقي، شاعر، مقدّم برامج، لاعب ألعاب، صانع محتوى، رياضي، فنان، مدوّن، شخصية عامة، أخرى — an enum on the server, named by the app in Arabic and English; optional, can be cleared. Shown under the name. | `AccountCategory`; `updateMe.category` |
| (f) Private account | Build follow requests. Private → only accepted followers see posts, reels and stories everywhere (feeds, grids, search, hashtags, story tray and viewer, direct links → «هذا الحساب خاص»). Lives stay public. Follow → a request; the owner is notified and has a «طلبات المتابعة» list (accept / decline); the requester can cancel; private → public accepts pending requests; existing followers stay; counts stay visible. Enforced on the server everywhere. | `PrivacySettings.isPrivate`; `FollowState.isRequested`; `PublicProfile.followRequested`; `FollowListItem.requestedByMe`; `listFollowRequests`, `acceptFollowRequest`, `declineFollowRequest`; notifications `FOLLOW_REQUEST`, `FOLLOW_REQUEST_ACCEPTED`; code `FOLLOW_REQUEST_NOT_PENDING` |
| (e) Grid order | No change — pinning 3 posts is enough. Edit profile shows the pin hint instead of «قريباً». | none |
| (a) CP frame on other people's profiles | Keep it (D112 unchanged). | none |
| (g) Profile photos | Visible at once with reports, as today, **plus** an admin CLI to remove a violating photo (audited, deletes the asset, notifies the user). | CLI `profile-admin remove-avatar`; notification `AVATAR_REMOVED`; audit `admin.avatar.remove` |

## Choices made while specifying (CTO, within the answers)

- **Link rules.** WHATWG URL parsing, then: `https:` only; no user info; no explicit port other than the
  default; host not an IP literal in any spelling, not `localhost`, at least two labels, LDH labels, an
  alphabetic or `xn--` TLD; no whitespace, controls, bidi or zero-width characters anywhere in the raw
  text (they can hide the real address). Stored as the normalised serialisation without the fragment,
  ≤ 500 characters (raw input ≤ 2 048). Label ≤ 30 code points, one line, §6 hygiene. Duplicates refused.
  The **platform is computed by the server** so the app and any later client agree on what is "known".
- **Gender visibility.** `UNDISCLOSED` never shows, even with `showGender` on. Gender cannot be cleared to
  null once chosen (the third option is the way to say nothing).
- **Follow requests reuse the follow endpoints** (`PUT` creates, `DELETE` cancels), so old screens keep
  working; the answer says `isRequested`. Accept and decline are `POST …/accept` / `…/decline` like the
  family and CP requests. A decline is silent; an accept notifies the requester.
- **Private → public** accepts every pending request in one statement (no per-request notifications, so
  a popular account switching does not fan out thousands of rows in one transaction).
- **Hashtag search** now applies the visibility rule to the tags it lists (before, a tag used only by a
  private account's posts was listed with a count of 0 — the tag text itself leaked).
- **Link reports** keep a snapshot (like DM reports, D155), because the owner may edit the link away; a
  moderator's `REMOVE_TARGET` deletes the link.
- **Admin photo removal** is a CLI (`profile-admin`), like every other admin tool today; it runs as the
  migration role, deletes the asset row with the change and the files after commit (or prints the keys
  when S3 is not configured on that machine), notifies the user with a system notification and audits
  the reason.

## Compatibility

- **Breaking for registration:** `gender` is required. The app adds the step in the same change set; an
  older build gets 400 `gender` / `required` (no released clients exist).
- **Behaviour change:** a new follow of a private account answers 200 `{isFollowing: false, isRequested:
  true}` instead of 403. No client could make an account private before v1.47, so nobody relied on it.
- Everything else is additive: new required response fields (strict clients update their models in the
  same change set), new operations, enum values (clients ignore unknown notification types and treat an
  unknown platform as `OTHER`).

## Not in this change

A cover photo, a birthday, free reordering of the grid, hiding the follower lists (lists are already
followers-only on private accounts), an admin UI (moderation stays the report queue + CLIs), push copy
for the new notification types beyond the generic general-push payload.
