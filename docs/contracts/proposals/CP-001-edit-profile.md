# CP-001 — Edit the own profile (PROPOSED, not approved)

**Status:** draft for owner/CTO review (D58). Not applied: `openapi.yaml`, `CONVENTIONS.md`,
`apps/api` and `apps/mobile` are unchanged by this document. Contracts stay frozen (D34/D35)
until it is approved.

## Why

The owner wants an "Edit profile" button on the profile (D57/D58). Today `PATCH /api/v1/me`
accepts only `{ "locale" }` (v1.2, additionalProperties false), so the app can show the edit
screen read-only but cannot save. Photo upload is out of scope here (it needs storage and
moderation decisions).

## Proposed change (v1.4 candidate)

`PATCH /api/v1/me` request body: at least one of these optional properties
(`minProperties: 1`, `additionalProperties: false`):

| Property | Type | Rules |
| --- | --- | --- |
| `locale` | `Locale` | unchanged (v1.2) |
| `displayName` | `DisplayName` | the registration rules of CONVENTIONS §6: NFC, trimmed, 1–50 graphemes, control/bidi/zalgo/reserved-term checks and the v1.3.1 text hygiene (§6 line "No endpoint edits a `displayName` in v1.3; a future one must apply these rules") |
| `bio` | `string \| null` | NFC, trimmed, 0–300 characters (matches `Me.bio` `maxLength: 300`); `null` or empty clears it; same control-character and bidi-mark rules as `displayName`; line breaks allowed (max 4) |

### Owner's additional options (D58)

The owner also chose these rows of the reference; the edit screen shows them as "Coming soon"
until they are approved and built.

| Property | Type | Rules | Visible to others |
| --- | --- | --- | --- |
| `links` | array of `{ title: string \| null, url: string }`, max 3 | `https://` only, ≤ 2048 chars, host must not be an IP literal or `localhost`; `title` 1–30 graphemes with the `displayName` text hygiene; duplicates rejected | yes: `PublicProfile.links` (new, same shape) |
| `gender` | `female \| male \| unspecified \| null` | `null` = not set | **no**: only in `Me` |
| `category` | enum `creator \| artist \| musician \| gamer \| educator \| business \| public_figure \| null` | fixed list, localized in the app | yes: `PublicProfile.category` (new) |
| `isPrivate` | boolean | turning private keeps existing followers; follow requests stay out of scope (v1.3.1 §10.6) | already public as `PublicProfile.isPrivate` |

**Reorder grid** is not part of this proposal: it needs the posts API (Phase 3) and a
`PUT /me/posts/order` endpoint designed with it.

Response: `200` with the updated `Me`: `Me` gains `links`, `gender` and `category`
(nullable, additive); `PublicProfile` gains `links` and `category`. Errors: `400 VALIDATION_ERROR` with
`details[].field` = `displayName` or `bio` and the existing `issue` values
(`invalid_format`, `too_long`, `reserved_term`), `401`, `429` (the existing `PATCH /me` rate limit).

Sketch:

```yaml
requestBody:
  required: true
  content:
    application/json:
      schema:
        type: object
        minProperties: 1
        additionalProperties: false
        properties:
          locale: { $ref: '#/components/schemas/Locale' }
          displayName: { $ref: '#/components/schemas/DisplayName' }
          bio: { type: [string, 'null'], maxLength: 300 }
```

## Compatibility

Additive: the current `{ "locale" }` body stays valid; responses only gain nullable fields
(clients ignore unknown fields, CONVENTIONS §3). New columns: `users.links` (jsonb),
`users.gender`, `users.category` (nullable enums). Public
profiles (`GET /users/{username}`) and live-room host cards show the new name and bio on the next
read; no cache invalidation exists to break.

## Work if approved

1. Contract: `openapi.yaml` + CONVENTIONS §6/§10 (+ changelog row), Decision Log entry.
2. API (`apps/api`): validation shared with registration, audit event `user.profile.updated`,
   tests for every rule above.
3. Mobile (`apps/mobile`): `EditProfileScreen` fields become editable, Save enabled when a value
   changed and valid, optimistic update of `meProvider`, field errors from `details[]`, tests.
