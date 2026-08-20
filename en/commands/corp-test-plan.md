---
description: Turn an approved delta spec's scenarios into a manual test checklist (tester flow)
---
Build the manual test plan for change {{args}}.
0. Set `REPO_ROOT="$(git rev-parse --show-toplevel)"`. Run
   `bash "$REPO_ROOT/tools/repository-state.sh" inspect`. If this is a local change branch, also
   run `bash "$REPO_ROOT/tools/repository-state.sh" assert-change <TICKET> --allow-dirty`.
1. Read the delta spec's scenarios AND the living spec sections it modifies (regressions live there).
2. For each scenario produce a checklist item: preconditions (test data, user role, system state),
   steps, expected result, requirement ID (e.g. R3). Add regression items for MODIFIED requirements.
3. Add a "worth exploring" section: edge areas the scenarios do not cover (state transitions,
   permissions, concurrency, empty/overflow inputs) — suggestions for the tester, clearly marked.
4. Post the checklist through the configured tracker integration. If none exists, print a
   ready-to-paste checklist. Do not mark anything passed; the tester's additions outrank yours.
