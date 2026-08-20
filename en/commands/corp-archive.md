---
description: Post-merge close-out — fold the delta into living specs, ADR, index (dev flow, on main)
---
Archive change {{args}}. Follow skill corp-verification (evidence for every step below).
Set `REPO_ROOT="$(git rev-parse --show-toplevel)"`. Run
`bash "$REPO_ROOT/tools/repository-state.sh" prepare-base`; stop on any failure.
Precondition: the change's PR is merged and the prepared branch is its configured base branch.
Verify both; do not assume the base is named `main`, `master`, or `develop`.
1. Run `<opsx-archive-command> {{args}}`. The delta folds into `openspec/specs/`.
2. Draft an ADR from the change's decisions (proposal "why" + research.md discoveries + any
   spec amendments) using `templates/adr.md`; write to openspec/adr/NNNN-<slug>.md
   (next free number). ADRs are append-only: never edit an accepted ADR — supersede it.
3. Regenerate the index: `node "$REPO_ROOT/tools/gen-index.mjs"`.
4. Run `bash "$REPO_ROOT/tools/verify-docs.sh"`; it must be green.
5. Commit as `chore(<TICKET>): archive {{args}} living spec and ADR`, then push. The store catalog picks
   this up on its next aggregation — no manual store edits, ever.
6. Post a one-line completion note through the configured tracker integration. If none exists,
   print the exact note for a human to paste.
