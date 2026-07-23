---
description: Turn an approved delta spec's scenarios into a manual test checklist (tester flow)
---
Build the manual test plan for change {{args}}.
1. Read the delta spec's scenarios AND the living spec sections it modifies (regressions live there).
2. For each scenario produce a checklist item: preconditions (test data, user role, system state),
   steps, expected result, requirement ID (e.g. R3). Add regression items for MODIFIED requirements.
3. Add a "worth exploring" section: edge areas the scenarios do not cover (state transitions,
   permissions, concurrency, empty/overflow inputs) — suggestions for the tester, clearly marked.
4. Post the checklist to the tracker story via MCP. Do not mark anything as passed — executing
   the plan is the tester's job, and their additions outrank yours.
