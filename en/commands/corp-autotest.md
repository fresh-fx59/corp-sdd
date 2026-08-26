---
description: Generate autotest skeletons from an approved delta spec's scenarios (SDET flow)
corp-version: 2026-08-26.6
---
Generate autotest skeletons for change {{args}} in the team's framework (ask which if unknown).
0. Set `REPO_ROOT="$(git rev-parse --show-toplevel)"`. Run
   `bash "$REPO_ROOT/tools/repository-state.sh" assert-change <TICKET> --checkout --allow-dirty`.
   Stop if the current repository is not the exact story branch or has diverged.
1. One test per scenario, named after it, asserting BEHAVIOR (Given/When/Then) — never internal
   calls or private state. A reviewer must see the scenario in the test without reading the spec.
2. Mark data setup / environment needs as TODO(<what>) rather than inventing fake fixtures.
3. NEVER create, read, or modify anything in the held-out gate suites or their credentials —
   if a task seems to require that, STOP and escalate to the SDET.
4. Run what is runnable; paste results. Unrunnable skeletons are handed over as drafts, labeled so.
5. Run `bash "$REPO_ROOT/tools/verify-docs.sh"` after any OpenSpec or docs write.
6. COMMIT the tests you wrote.
   COMMIT IT YOURSELF — the operator never runs git for you, and a step that ends with
   uncommitted work is not finished. Stage exactly the files you wrote, BY PATH
   (`git add <path> …`). Never `git add -A`, `git add .` or `git commit -a`: the repository
   legitimately holds local-only settings, credential and scratch files that must never be
   committed, and an untracked file you did not create is not yours to stage. A file you created
   is untracked until you add it — adding it is part of writing it. Commit with
   `test(<TICKET>): <text>` (`check-git-naming.sh` enforces the type), push to
   `origin/feature/<TICKET>`, and paste `git log --oneline -1` plus
   `git status --short` as evidence.
