---
description: Post-merge close-out — fold the delta into living specs, ADR, index (dev flow)
corp-version: 2026-08-26.6
---
Archive change {{args}}. Follow skill corp-verification (evidence for every step below).
`{{args}}` is `<change-id> [--here | --branch <name>]`. The flag chooses WHERE the archive
commit lands; the rest is the `<change-id>` passed to the archiver. `<openspec>` is the OpenSpec CLI
invocation setup resolved.
0. Set `REPO_ROOT="$(git rev-parse --show-toplevel)"`.
   Precondition, in every mode: the change's PR is merged. Verify it; if it is not, ask the
   user ONCE — continue here or stop — and follow the answer. Never stop silently.
   Then place yourself. With no flag, ask the user ONCE which of the three, print the
   current branch in the question, and wait for the answer — never pick for them:
   - (1) a fresh `feature/<TICKET>` from the base: run
     `bash "$REPO_ROOT/tools/repository-state.sh" prepare-base`, then
     `git checkout -b feature/<TICKET>` — recreating the story branch, which the merge usually
     deleted. Step 5 publishes it and opens a PR. The name carries no suffix: `check-git-naming.sh`
     accepts `feature/ABCD-1234` and nothing else, so a suffixed name fails the pre-push guard and
     the push is rejected.
   - (2) a branch you name: the same, using that name — it must still match `feature/ABCD-1234`.
   - (3) here: stay on the current branch and do NOT run `prepare-base`.
   A flag answers the question in advance and skips it: `--branch <name>` is (2), `--here` is (3).
   Then, in every mode, run `bash "$REPO_ROOT/tools/repository-state.sh" assert-archivable`;
   stop on any failure. It proves the tree is clean, there are no stashes, and HEAD already
   contains the configured base — so the delta cannot fold into stale specs. Do not assume the
   base is named `main`, `master` or `develop`; the tool resolves it.
   If the change's status shows every artifact done and every task complete, skip the
   per-artifact and per-task confirmations; the status check already answered them.
1. Run `bash "$REPO_ROOT/tools/verify-docs.sh"`, then
   `<openspec> validate <change-id> --type change --strict --json`; fix until verify-docs is green
   and the CLI reports `"valid": true`. The CLI is the authority on delta-spec grammar — the lint
   no longer re-checks it. A heading that is not `### Requirement: <text>` verbatim is exactly what
   `<openspec> archive` rejects, and it fails mid-archive, where recovery is manual.
   Only if the delta is semantically valid and the archiver still refuses, ask the user once
   before using its `--no-validate` escalation. Then run `<openspec> archive <change-id> --yes --json`
   — the change id only, never the placement flag. The delta folds into `openspec/specs/`.
2. Draft an ADR from the change's decisions (proposal "why" + research.md discoveries + any
   spec amendments) using `templates/adr.md`; write to openspec/adr/NNNN-<slug>.md
   (next free number). ADRs are append-only: never edit an accepted ADR — supersede it.
3. Write the index: `node "$REPO_ROOT/tools/gen-index.mjs"`. This step is not optional —
   verify-docs only runs `gen-index.mjs --check`, which reports drift and writes nothing.
4. Run `bash "$REPO_ROOT/tools/verify-docs.sh"`; it must be green.
5. Commit as `docs(<TICKET>): archive {{args}} living spec and ADR`, then push the branch you
   are on. Default and `--branch` mode: open a PR into the configured base. `--here` mode: the
   commit rides the branch's existing PR. The store catalog picks this up on its next
   aggregation — no manual store edits, ever.
6. Post a one-line completion note through the configured tracker integration. If none exists,
   print the exact note for a human to paste.
