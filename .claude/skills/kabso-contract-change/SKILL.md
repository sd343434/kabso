---
name: kabso-contract-change
description: Checklist for any Kabso API change, from contract to code to release notes, in the repository's contract-first order. Use when adding or changing an endpoint, a response field, an error code or a rule.
disable-model-invocation: true
---

# /kabso-contract-change

Read `.claude/skills/kabso-monorepo/references/contract-first.md` and `docs/contracts/CONVENTIONS.md`
first.

1. **Numbers.** Compute the next contract label, board D-row, CONVENTIONS section, DEPLOYMENT section
   and PP item across all remote branches, using the commands in `contract-first.md`. Report any
   collision instead of choosing silently.
2. **Contract.** Change `docs/contracts/openapi.yaml` and `docs/contracts/CONVENTIONS.md`: the section,
   §4 error codes, §8 ownership if tables are involved, and a §9 change-log row. Use a proposal in
   `docs/contracts/proposals/` if the change is large or not yet approved.
3. **Board.** Add a decision row to `docs/AI_WORKFORCE_BOARD.md`.
4. **Database.** If tables change, follow `/kabso-db-migration`.
5. **API.** Implement it, with e2e tests that check the response against the contract.
6. **Clients.** Update the mobile models, repositories and error mapping (`lib/core/error/`), plus both
   ARB files, and the admin or studio types and `i18n` where they are affected.
7. **Release notes.** Add `docs/DEPLOYMENT.md` and `docs/PRE_PRODUCTION_CHECKLIST.md` entries when the
   change needs server configuration or a release gate.
8. **Verify.** Run `/kabso-verify`.

Stop and ask the owner before any commit, push or merge. If the documents disagree with each other or
with the code, report the conflict; do not resolve it by assumption.
