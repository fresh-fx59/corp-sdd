---
description: Generate autotest skeletons from an approved delta spec's scenarios (SDET flow)
---
Generate autotest skeletons for change {{args}} in the team's framework (ask which if unknown).
0. Set `REPO_ROOT="$(git rev-parse --show-toplevel)"`. Run
   `bash "$REPO_ROOT/tools/repository-state.sh" assert-change <TICKET> --allow-dirty`.
   Stop if the current repository is not the exact story branch or has diverged.
1. One test per scenario, named after it, asserting BEHAVIOR (Given/When/Then) — never internal
   calls or private state. A reviewer must see the scenario in the test without reading the spec.
2. Mark data setup / environment needs as TODO(<what>) rather than inventing fake fixtures.
3. NEVER create, read, or modify anything in the held-out gate suites or their credentials —
   if a task seems to require that, STOP and escalate to the SDET.
4. Run what is runnable; paste results. Unrunnable skeletons are handed over as drafts, labeled so.
5. Run `bash "$REPO_ROOT/tools/verify-docs.sh"` after any OpenSpec or docs write.
