# CP-007 — Muted accounts: list and state (PROPOSED, not approved)

**Status:** draft for owner/CTO review, 2026-10-21. Not applied: `openapi.yaml`,
`CONVENTIONS.md`, `apps/api` and `apps/mobile` are unchanged by this document. It would extend
contract **v1.5-social** (draft) additively.

## Why

v1.5-social (CP-006 M1) lets a user mute an account (`PUT`/`DELETE /users/{username}/mute`,
CONVENTIONS §11.7), but the contract gives no way to **see** a mute afterwards:

- there is no list of muted accounts (blocks have `GET /me/blocks`, mutes have nothing);
- `PublicProfile` carries no mute state, so a profile cannot show "Unmute" instead of "Mute".

So in the app (KL-060 part D3) a mute can be undone only from the "Undo" on the message right
after muting. Once that message is gone, the muted account stays muted with no way back in the
app, and the user cannot tell from the profile that they muted it. Mute is silent and one-way:
the muted person is never told, so nothing here may reveal a mute to them.

## Proposed change

### 1. `GET /api/v1/me/mutes` — the caller's muted accounts

Mirrors `GET /me/blocks` (tag `safety`, `operationId: listMutes`).

| | |
| --- | --- |
| Query | `cursor`, `limit` (the shared `Cursor` / `Limit` parameters) |
| Order | newest mute first (`createdAt` desc, then `mutedId` desc) |
| 200 | `UserSummaryPage` (existing schema) |
| Errors | `400` (bad cursor / limit), `401` |
| Visibility | every account the caller muted is listed, including one blocked either way (the caller muted it and must be able to unmute it). Same rule as `/me/blocks`, which today filters nothing; whether both lists should leave out deleted or suspended accounts is open question Q1 below |

```yaml
/api/v1/me/mutes:
  get:
    tags: [safety]
    operationId: listMutes
    summary: "Users the caller muted, newest first"
    parameters:
      - $ref: '#/components/parameters/Cursor'
      - $ref: '#/components/parameters/Limit'
    responses:
      '200':
        description: One page.
        content:
          application/json:
            schema: { $ref: '#/components/schemas/UserSummaryPage' }
      '400': { $ref: '#/components/responses/Error' }
      '401': { $ref: '#/components/responses/Error' }
```

### 2. `PublicProfile.isMuted` — the caller's mute state

```yaml
isMuted:
  type: boolean
  description: Whether the caller muted this user (always false when isSelf). Only the caller sees their own mute.
```

Added to `PublicProfile.required`. `GET /users/{username}` already reads the caller; the server
adds one primary-key lookup on `user_mutes (muter_id, muted_id)`. The value describes the
**caller's** mute only; no endpoint ever tells a user who muted them.

### 3. CONVENTIONS §11.7 (one line added under Mute)

> The caller sees their mutes in `GET /me/mutes` (newest first) and on profiles as
> `PublicProfile.isMuted`; the muted account is never told.

## Compatibility

Additive. A new path; `PublicProfile` gains one boolean (clients ignore unknown fields,
CONVENTIONS §3). No existing path, schema or error code changes.

Database: one index for the list's order, mirroring the blocks index:

```prisma
@@index([muterId, createdAt(sort: Desc)], map: "user_mutes_muter_created_idx")
```

(today `user_mutes` has only its primary key `(muter_id, muted_id)` and an index on
`muted_id`). No data migration.

## Alternatives considered

- **List only, no `isMuted`:** fixes "how do I unmute", but the profile would still offer "Mute"
  for an account already muted. Rejected: two calls instead of one, and a misleading menu.
- **`isMuted` only, no list:** the user has to remember whom they muted and find each profile.
  Rejected.
- **Mute state on `Post.author` / `UserSummary`:** would make every feed item heavier for a
  rare need. Not proposed.

## Work if approved

1. **Contract:** `openapi.yaml` (path, `PublicProfile.isMuted`), CONVENTIONS §11.7 line,
   changelog row (v1.5-social draft), Decision Log entry.
2. **API** (`apps/api`, `safety` and `users/profiles` modules):
   - `SafetyService.mutes()` with the same cursor scheme as `blocks()` (scope
     `mutes:<callerId>`);
   - the index migration;
   - `isMuted` in the public profile DTO;
   - e2e tests: order and paging, foreign cursor rejected, the Q1 rule,
     `isMuted` true / false / false for self, never visible to the muted user.
3. **App** (`apps/mobile`):
   - Settings → Privacy and safety → **Muted accounts** (paged list with Unmute, empty state),
     like Blocked accounts;
   - the profile menu shows **Unmute** when `isMuted` is true;
   - tests for both.

## Open question for the owner

- **Q1.** Should `/me/mutes` (and, for consistency, the existing `/me/blocks`) leave out deleted
  or suspended accounts? Today `/me/blocks` lists them. Recommendation: keep them listed. The row
  can still be unmuted or unblocked, and the list stays an exact record of what the caller set.

## Not in scope

Muting words or hashtags, timed mutes, and muting stories or comments separately are not part
of this proposal; each would need its own decision.
