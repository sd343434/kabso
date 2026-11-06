# Kabso Live — rules for AI agents

This file is for every AI coding agent in this repository: Codex, and Claude Code when there is no
`CLAUDE.md`. It does not restate the project's rules. It says where they live and which actions need a
human.

## Human approval gate (mandatory)

Get the owner's explicit approval **before** each of these, every time, even inside a scratch worktree:

- `git commit`, `git push`, `git merge`, `git rebase`, `git reset`, `git cherry-pick`, deleting or
  force-updating a branch or tag;
- merging, closing or approving a pull request;
- any deployment, or anything that touches the staging or production server;
- any destructive operation, such as deleting files outside your own scratch output, dropping or
  resetting a database, `prisma migrate reset`, or cleaning a working tree.

Earlier approval does not carry over to a later action. In Claude Code the project's default mode is
`plan`. Never modify uncommitted changes you did not make.

### Codex: when the project's read-only sandbox applies

`.codex/config.toml` sets `sandbox_mode = "read-only"`. This takes effect **only when this project is
trusted** in your personal Codex configuration. These results come from Codex CLI 0.163.0, run with a
temporary configuration home on 2026-11-06:

- **Project not marked as trusted:** Codex ignored the project configuration, so your personal or
  built-in sandbox applied. A personal `workspace-write` was used as is. `AGENTS.md` was still loaded.
- **Project marked `trust_level = "untrusted"`:** Codex ignored the project configuration and did
  **not** load `AGENTS.md`. The sandbox was `workspace-write`.
- **Trusted project:** the project's `read-only` overrode a personal `workspace-write` or
  `danger-full-access`.
- **Command line:** `-c sandbox_mode=...` took precedence over the project setting. A sandbox flag on
  other Codex commands should behave the same way, but this was not tested.

Decide whether to trust this repository yourself, after reviewing its `.codex/` files. Nothing in this
repository asks you to trust it. Whatever you decide, keep `sandbox_mode = "read-only"` in your personal
`~/.codex/config.toml` as a fallback, and do not pass a broader sandbox on the command line for work in
this repository.

## Sources of truth

Read these before changing anything. If they disagree with each other or with the code, stop and ask;
do not pick one silently.

| Topic | Source |
| ----- | ------ |
| Decisions (D-rows), tasks, agent ownership, the delivery labels | `docs/AI_WORKFORCE_BOARD.md` |
| API contract (contract-first) | `docs/contracts/openapi.yaml` and `docs/contracts/CONVENTIONS.md` |
| Design tokens | `docs/contracts/design-tokens.json` |
| Database | `apps/api/prisma/schema.prisma`, `apps/api/prisma/migrations/`, `docs/DATABASE_SCHEMA.md` |
| Deployment | `docs/DEPLOYMENT.md` |
| Release gates | `docs/PRE_PRODUCTION_CHECKLIST.md` |
| Security | `docs/SECURITY_MODEL.md` |
| Architecture and screens | `docs/SYSTEM_ARCHITECTURE.md`, `docs/APP_MAP.md` |
| CI (what must pass) | `.github/workflows/ci.yml` |

The repository map, the checks for each area and the workflows are in the skill
`.claude/skills/kabso-monorepo/SKILL.md`. Codex finds it through `.agents/skills/kabso-monorepo/`.

## Non-negotiable rules

- **Public repository (board decision D40).** Never commit secrets, third-party reference screenshots,
  images of real users, or open-finding exploit details.
- **Never report a test, check or command as passed unless you ran it and saw it pass.** Say "not run"
  and give the reason.
- Do not lower thresholds, weaken or skip tests, or add `.gitleaksignore` entries beyond exact verified
  fingerprints.
- Do not change unrelated files. Keep fixtures out of production paths.

## Visual work

For UI fidelity and visual regression, use the design skills `elite-design-engineering`,
`pixel-perfect-ui`, `pixel-perfect-ui-workflow`, `pixel-perfect-reference-analyzer`,
`asset-and-typography-forensics`, `reference-to-flutter-implementer`, `rtl-ltr-visual-specialist` and
`screenshot-diff-and-visual-regression`. **They are not on `staging` yet.** They live on the branch
`claude/elite-design-engineering`, together with its `CLAUDE.md`. If they are missing, say so; do not
recreate them.

## Maintenance of this bundle

These files are maintained by hand: `AGENTS.md`, `.claude/settings.json`, `.claude/skills/kabso-*`,
`.agents/skills/kabso-monorepo/`, `.codex/`. They are **not** managed by the ECC Tools GitHub App; do
not merge regenerated ECC bundles over them. Claude Code reads only `CLAUDE.md` when one exists, so the
`CLAUDE.md` that later lands from `claude/elite-design-engineering` should import this file.
