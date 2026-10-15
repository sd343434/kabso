# Kabso Live

Social entertainment and live-streaming platform: live rooms and PK battles, virtual gifts,
posts, stories and highlights, and short vertical videos. Arabic-first (RTL) with full English.

| Part | Path | Stack |
| ---- | ---- | ----- |
| Mobile app | [`apps/mobile`](apps/mobile) | Flutter (Android, iOS), Riverpod, GoRouter, Dio |
| Backend API | [`apps/api`](apps/api) | NestJS, Prisma, PostgreSQL, Redis |
| Contracts | [`docs/contracts`](docs/contracts) | OpenAPI 3.1, conventions, design tokens |

**Project status:** Phase 1 (foundation + email authentication) in progress. See
[`docs/AI_WORKFORCE_BOARD.md`](docs/AI_WORKFORCE_BOARD.md) for live status and
[`docs/KNOWN_LIMITATIONS.md`](docs/KNOWN_LIMITATIONS.md) for blockers.

## Documentation

- [System architecture](docs/SYSTEM_ARCHITECTURE.md)
- [Implementation plan](docs/IMPLEMENTATION_PLAN.md)
- [API conventions](docs/contracts/CONVENTIONS.md) · [OpenAPI](docs/contracts/openapi.yaml)
- [Known limitations & blockers](docs/KNOWN_LIMITATIONS.md)
