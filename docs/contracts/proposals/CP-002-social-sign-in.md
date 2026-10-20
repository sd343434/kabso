# CP-002 — Sign in with Google and Apple (PROPOSED, not approved)

**Status:** draft for owner/CTO review (D64). Not applied: `openapi.yaml`, `CONVENTIONS.md`,
`apps/api` and `apps/mobile` are unchanged by this document. Until it is approved the login
screen shows both buttons disabled, marked "Soon".

## Why

The owner wants Google and Apple sign-in on the login screen (D64). The contract has only
email/username + password (`POST /api/v1/auth/login`, `POST /api/v1/auth/register`).

## Proposed change (v1.4 candidate)

`POST /api/v1/auth/oauth/{provider}` with `provider` ∈ `google | apple`.

Request:

| Property | Type | Rules |
| --- | --- | --- |
| `idToken` | string | The provider's OpenID Connect ID token from the native SDK. Verified server-side: signature against the provider's JWKS, `iss`, `aud` = our client IDs, `exp`, and (Apple) the `nonce`. |
| `nonce` | string \| null | Required for Apple: the raw nonce whose SHA-256 the app passed to the SDK. |
| `locale` | `Locale` | As in registration (v1.2). |

Responses:

- `200` with the existing session payload when the provider account (`provider`, `sub`) is
  linked to a user.
- `202` with a short-lived `signupToken` when it is not: the app then asks for a username
  (and display name) and calls `POST /api/v1/auth/oauth/complete { signupToken, username,
  displayName }`, which applies the registration rules of CONVENTIONS §6 and returns `201`.
- Errors: `OAUTH_TOKEN_INVALID` (401), `OAUTH_EMAIL_UNVERIFIED` (403, Google `email_verified`
  false), `ACCOUNT_SUSPENDED` (403), `RATE_LIMITED` (429), as in §4.

## Rules to agree

1. **No silent account merge.** A provider email that matches an existing password account is
   not linked automatically (account takeover risk); the user signs in with the password and
   links the provider from settings (a later endpoint).
2. **Apple's private relay emails** are stored as given; Apple may withhold the name after the
   first sign-in, so the display name is asked for in the completion step.
3. **Store review:** iOS apps that offer Google sign-in must also offer Sign in with Apple.
4. **Data:** a new `user_identities (user_id, provider, subject, email, created_at)` table,
   unique on `(provider, subject)`; tokens themselves are never stored.
5. **Secrets:** the provider client IDs are public configuration; the Apple key for the
   server-to-server revocation endpoint is a secret managed like the others (none in git).

## App side once approved

- Native SDKs (`google_sign_in`, `sign_in_with_apple`), the providers' official button assets
  and branding rules (replacing the Simple Icons placeholders of D64).
- The two buttons become enabled; the username step reuses the registration form's username
  field and availability check.
