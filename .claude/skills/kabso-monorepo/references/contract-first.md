# Contract-first development

Authoritative: `docs/contracts/CONVENTIONS.md` (§4 errors, §8 ownership, §9 contract change log),
`docs/contracts/openapi.yaml`, `docs/contracts/proposals/`, `docs/AI_WORKFORCE_BOARD.md` (decision
log), `redocly.yaml`.

## Rule

An API change starts in the contract, not in code. The order is:

1. **Contract.** Edit `openapi.yaml` (paths, schemas, error responses) and `CONVENTIONS.md` (rules, the
   new or extended section, error codes in §4, ownership rows in §8, a row in the §9 change log). Larger
   changes go through a proposal in `docs/contracts/proposals/` first.
2. **Board.** Add a decision row in `docs/AI_WORKFORCE_BOARD.md`. Ownership and approval follow
   `CONVENTIONS.md` §8.
3. **Code.** API, then the app, admin or studio, plus the error-code mapping in each client.
4. **Deployment and release.** Add a `docs/DEPLOYMENT.md` §5.n note and a `docs/PRE_PRODUCTION_CHECKLIST.md`
   PP-n item when the change needs server configuration or a release gate.

## Version labels and numbers

The contract uses labels such as `v1.83-social` and `v1.61-live` in the §9 change log and in the
`openapi.yaml` description. `info.version` is a separate field; read it, do not assume. Never hardcode
the next number. Several agents work on unmerged `claude/*` branches at once, so compute it over every
remote branch:

```sh
git fetch origin
# highest_on_all_branches <file> <grep -oE pattern>: the highest match on any remote branch.
highest_on_all_branches() {
  for r in $(git for-each-ref --format='%(refname)' refs/remotes/origin); do
    git show "$r:$1" 2>/dev/null | grep -oE "$2"
  done | sed -E 's/^[#| ]+//' | sort -V -u | tail -1   # strip heading/table prefixes before sorting
}
highest_on_all_branches docs/contracts/CONVENTIONS.md 'v1\.[0-9]+-live'     # live series
highest_on_all_branches docs/contracts/CONVENTIONS.md 'v1\.[0-9]+-social'   # social series (numbered separately)
highest_on_all_branches docs/AI_WORKFORCE_BOARD.md '^\| D[0-9]+'            # board decision rows
highest_on_all_branches docs/contracts/CONVENTIONS.md '^#+ 10\.[0-9]+'      # CONVENTIONS sections
highest_on_all_branches docs/DEPLOYMENT.md '^#+ 5\.[0-9]+'                  # DEPLOYMENT sections
highest_on_all_branches docs/PRE_PRODUCTION_CHECKLIST.md 'PP-[0-9]+'        # release-gate items
```

The next free number is the highest one plus one. The labels also appear in the `openapi.yaml`
description; cross-check it when the two disagree. If two branches already use a number, stop and report
it; do not renumber someone else's work.

## Checks

```sh
npm ci --prefix tools/redocly --ignore-scripts --no-audit --no-fund
tools/redocly/node_modules/.bin/redocly lint docs/contracts/openapi.yaml
```

This is the CI `contracts` job. The API e2e tests validate responses against the contract
(`apps/api/test/helpers/openapi.ts`). Run the ones related to the change.
