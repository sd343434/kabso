# Kabso Live — System Architecture

Status: Phase 1 baseline. Decisions are recorded in the Decision Log of
[`AI_WORKFORCE_BOARD.md`](AI_WORKFORCE_BOARD.md).

## 1. Repository layout (monorepo)

```
kabso/
├── apps/
│   ├── mobile/          Flutter app (Android + iOS) — package `kabso_live`
│   ├── api/             NestJS + Prisma backend (REST /api/v1, WebSocket gateway from Phase 6)
│   └── admin/           Admin web panel (Phase 10; not yet created)
├── docs/
│   ├── contracts/       Authoritative shared contracts (OpenAPI, conventions, design tokens, events)
│   └── design/          Design system & screen specifications
├── infra/               Local/staging infrastructure definitions
├── .github/workflows/   CI
├── docker-compose.yml   Local Postgres + Redis (+ MinIO, LiveKit later)
└── package.json         pnpm workspace root (Node tooling only)
```

## 2. Mobile (apps/mobile)

- Flutter stable (3.47.x / Dart 3.13), Material 3 with a custom token-driven theme.
- **Clean Architecture, feature-first**: `lib/features/<feature>/{domain,data,presentation}`.
  - `domain`: entities (Freezed), repository interfaces, failure types. No Flutter/Dio imports.
  - `data`: DTOs (json_serializable), remote data sources (Dio), repository implementations.
  - `presentation`: Riverpod notifiers/providers, screens, widgets.
- Cross-cutting: `lib/core/` (config, networking, secure storage, error mapping, logging) and
  `lib/design_system/` (tokens, themes, reusable components).
- **State/DI**: Riverpod 3. **Navigation**: GoRouter with a `StatefulShellRoute` for the five
  primary tabs (Home, Discover, Create, Live, Profile) and an auth redirect guard driven by the
  session state provider.
- **Networking**: Dio with interceptors for request id, `Accept-Language`, bearer token,
  single-flight token refresh, and mapping of the server error envelope to typed failures.
- **Secrets**: none in the app. Only `API_BASE_URL` (and later public provider ids) via
  `--dart-define`. Refresh token in `flutter_secure_storage`; access token in memory.
- **Localization**: `gen-l10n` ARB files, Arabic (`ar`, default, RTL) and English (`en`).
  Directional APIs only (`EdgeInsetsDirectional`, `AlignmentDirectional`, `start/end`).
- Generated code (`*.g.dart`, `*.freezed.dart`) is committed; CI regenerates and fails on diff.

## 3. Backend (apps/api)

- Node.js 22, TypeScript (strict), NestJS 12, Prisma 7 (stable) with `@prisma/adapter-pg`,
  PostgreSQL 16, Redis 7.
- Modules: `health`, `auth`, `users`, `mail` (port + adapters), `common` (errors, request id,
  validation, rate limiting), `prisma`. Later: `social`, `posts`, `stories`, `media`, `videos`,
  `live`, `pk`, `gifts`, `wallet`, `payments`, `messaging`, `notifications`, `moderation`, `admin`.
- Each module owns its tables; cross-module access goes through the owning module's service,
  never its tables directly.
- Validation with Zod at the HTTP boundary; config validated with Zod at boot (fail fast).
- Structured JSON logging (pino) with secret redaction and request ids.
- The backend is authoritative for auth, permissions, money, gifts, PK scores, rankings,
  moderation and all expiry times.

## 4. Provider decisions (adapters behind interfaces)

| Concern | Choice | Why | Status |
| ------- | ------ | --- | ------ |
| Live A/V | **LiveKit** (Cloud or self-hosted) | Open-source SFU, maintained Flutter SDK (`livekit_client`), server SDK for token minting & webhooks, multi-host rooms, simulcast/adaptive quality, can self-host for cost/data residency. Agora remains a drop-in alternative behind `LiveMediaProvider`. | Phase 6; needs credentials → BLOCKED until provided |
| Object storage | S3-compatible (AWS S3 / Cloudflare R2; MinIO locally) | Portability | Phase 3+ |
| Video transcoding | Worker (BullMQ) + FFmpeg producing HLS; managed alternative (Mux / AWS MediaConvert) behind `TranscodeProvider` | Control vs. ops cost trade-off decided at Phase 5 | Phase 5 |
| CDN | CloudFront or Cloudflare in front of storage | — | Phase 5 |
| Email | `MailSender` port: `log` adapter (dev), SMTP adapter (prod) | Provider-agnostic | SMTP creds BLOCKED |
| SMS / phone auth | `SmsSender` port (Twilio/Vonage candidates) | — | BLOCKED (provider + cost) |
| Push | FCM (Android + iOS via APNs key) from backend | — | Phase 9; Firebase project BLOCKED |
| Payments | Apple IAP / Google Play Billing for coins (store rules for digital goods) with server-side receipt verification | Store policy for virtual currency | Phase 8; legal/commercial BLOCKED |

## 5. Security baseline

See `docs/SECURITY_MODEL.md` (Phase 1 deliverable of the Security specialist). Highlights:
Argon2id, rotating refresh tokens with reuse detection, immediate revocation via session check,
Redis rate limits, no account enumeration, least-privilege DB role, secrets only via env.
