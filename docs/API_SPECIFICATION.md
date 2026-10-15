# Kabso Live — API Specification (Phase 1)

The machine-readable contract is [`contracts/openapi.yaml`](contracts/openapi.yaml); transport,
error, auth and rate-limit rules are in [`contracts/CONVENTIONS.md`](contracts/CONVENTIONS.md).
This page records **how the implementation (`apps/api`) authorizes and limits each endpoint**.

## Global behaviour

- Every route requires `Authorization: Bearer <access JWT>` unless marked **public** below.
  The guard verifies the JWT (HS256 only, `iss=kabso-api`, `aud=kabso-mobile`, `typ=access`,
  not expired) **and** loads the session: it must belong to `sub`, not be revoked, not be expired,
  and the user must be `ACTIVE`. Otherwise → 401 `AUTH_UNAUTHENTICATED`.
- Bodies are strict: unknown fields → 400 `VALIDATION_FAILED` with `issue: "unknown_field"`.
  Malformed JSON / oversize bodies (> `BODY_LIMIT`, default 100 kB) → 400 `VALIDATION_FAILED`.
- Validation `issue` values: `required`, `invalid_type`, `too_short`, `too_long`, `too_small`,
  `too_big`, `invalid_email`, `invalid_format`, `invalid_value`, `unknown_field`,
  `malformed_json`, `payload_too_large`.
- Rate limits are Redis fixed windows. If Redis is unavailable, rate-limited routes fail
  **closed** with 503 `SERVICE_UNAVAILABLE`.
- Every authenticated request also counts against 600 / 15 min per user; public routes without
  a specific rule count against 300 / 15 min per IP (`RATE_LIMIT_PUBLIC_IP`).

## Endpoints

| Endpoint | Auth | Rate limit (default) | Notes |
| -------- | ---- | -------------------- | ----- |
| `GET /health/live` | public | none | process up |
| `GET /health/ready` | public | none | DB `SELECT 1` + Redis `PING` (2 s timeout each); 503 + `{status:"down"}` if either fails |
| `POST /auth/register` | public | 5/h per IP | reserved username → 409 `USERNAME_TAKEN`; creates user+profile+settings+session+verify token in one transaction; email sent after commit |
| `POST /auth/login` | public | 10/15 min per IP+identifier, 50/15 min per IP | `identifier` containing `@` is treated as an email, otherwise a username; unknown user and wrong password both → 401 `AUTH_INVALID_CREDENTIALS` (unknown users still pay an Argon2 verification); SUSPENDED (after correct password) → 403 `ACCOUNT_SUSPENDED`; DELETED → 401 |
| `POST /auth/refresh` | public (refresh token) | 60/15 min per session | rotation via compare-and-swap; any non-current secret for a live session = reuse → session revoked (`REFRESH_REUSE`) + 401 `AUTH_REFRESH_INVALID`; losing a concurrent race → 401 without revoking; SUSPENDED → 403 |
| `POST /auth/logout` | bearer | per user | revokes the caller's session (`LOGOUT`) |
| `POST /auth/email/verify` | public | per IP | malformed/unknown → 422 `TOKEN_INVALID`; used/expired → 410 `TOKEN_EXPIRED` |
| `POST /auth/email/resend` | bearer | 5/h per user (`RATE_LIMIT_EMAIL_RESEND_USER`) + per user | no-op when already verified; new token invalidates older ones |
| `POST /auth/password/forgot` | public | 3/h per email, 10/h per IP | always 202 with empty body; work happens after the response; only ACTIVE users receive mail |
| `POST /auth/password/reset` | public | per IP | token single-use; sets new password and revokes **all** sessions (`PASSWORD_RESET`) |
| `GET /auth/sessions` | bearer | per user | live sessions only, newest first, max 50, `current` = caller's session, `ipCountry` always null |
| `DELETE /auth/sessions/{id}` | bearer | per user | own live session only; foreign, revoked, unknown or malformed id → 404 `NOT_FOUND` |
| `GET /me` | bearer | per user | `Me` |
| `GET /users/username-availability` | public | per IP | malformed → 400; reserved or taken → `available:false` |

## Audit events

`auth.register`, `auth.login.success`, `auth.login.failure` (with `reason`: `unknown_identifier`
\| `bad_password` \| `suspended`), `auth.logout`, `auth.refresh.reuse`, `auth.email.verified`,
`auth.password.reset_requested`, `auth.password.reset`, `auth.session.revoke`.
