# Kabso Live — Implementation Plan

Each phase ends with: format + static analysis + tests executed, build where feasible, docs and
`AI_WORKFORCE_BOARD.md` updated, coherent commits. A phase is not "done" on a report alone —
QA (A6) verifies independently; Security (A7) reviews auth, privacy and money.

| Phase | Scope | Lead agents | Exit criteria (summary) | Status |
| ----- | ----- | ----------- | ----------------------- | ------ |
| 0 | Audit, contracts, architecture, plan, board | A1 | Docs committed | DONE |
| 1 | Flutter foundation (design system, nav, l10n/RTL, themes, API client), backend foundation, email auth + sessions, CI | A2, A3, A5, A8 | KL-002..008 acceptance criteria | IN_PROGRESS |
| 2 | Profiles, follow graph, follow requests, blocks, privacy settings, home feed skeleton | A3, A2 | Privacy & block tests; cursor feed | BACKLOG |
| 3 | Media upload (presigned S3), image posts, carousels, likes, comments, saves, share | A3, A2, A4 | Upload authorization tests | BACKLOG |
| 4 | Stories, archive, viewer, highlights | A3, A2 | Server-side expiry + highlight persistence tests | BACKLOG |
| 5 | Short video: upload, transcoding (HLS), vertical feed, playback lifecycle, ranking v1 | A4, A3, A2 | Controller pool bounded; processing state tests | BACKLOG |
| 6 | LiveKit integration, room lifecycle, chat, moderation, audience | A4, A2, A3 | Needs B1 | BLOCKED (B1) for e2e |
| 7 | Multi-host, PK battles, gifts, realtime events, reconnect | A4, A3 | Server-authoritative PK + replay protection tests | BACKLOG |
| 8 | Wallet ledger, coin packages, verified IAP, creator earnings, payouts (disabled) | A3, A7 | Concurrency + idempotency + webhook replay tests | BLOCKED (B5) for real money |
| 9 | DMs, push, creator analytics, discovery | A3, A2, A4 | Needs B4 for push | BACKLOG |
| 10 | Admin panel, moderation queues, appeals, verification, audit | A3 + web | RBAC tests | BACKLOG |
| 11 | Security hardening, deletion/export, accessibility, performance | A7, A6 | Pen-test checklist, load tests | BACKLOG |
| 12 | Staging, release pipelines, runbooks | A8 | Release gates + human authorization | BACKLOG |

## Phase 1 — work packages

See `AI_WORKFORCE_BOARD.md` KL-002 … KL-008 for owners and acceptance criteria.

Execution order:

1. **Wave 1 (parallel, isolated worktrees):** KL-002 backend, KL-003 Flutter, KL-004 design spec,
   KL-005 DevOps. Disjoint file ownership; shared contracts frozen.
2. **Wave 2:** CTO integrates branches → KL-006 QA verification and KL-007 security review run in
   parallel against the integrated tree.
3. **Wave 3:** fixes for QA/security findings, regression run, board + report.
