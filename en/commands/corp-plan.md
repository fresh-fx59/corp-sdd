---
description: Generate design + tasks for an approved change, against TODAY's code (dev flow)
version: 1.0.0
---
Plan change {{args}}. Follow skills corp-drill-down (all system facts) and corp-verification.
Precondition: proposal + delta spec exist and are approved — if not, STOP
and say which is missing.
0. Set `REPO_ROOT="$(git rev-parse --show-toplevel)"`. Run
   `bash "$REPO_ROOT/tools/repository-state.sh" assert-change <TICKET>`; stop on failure.
   Run `<opsx-continue-command> {{args}}` until the OpenSpec workflow exposes its design and
   tasks artifacts. Do not continue into implementation.
1. Read the delta spec, research.md, and the living specs it modifies. Read the CURRENT code of
   the affected modules (use corp-drill-down; append new verified facts to research.md).
2. Write design.md: approach, files/classes to touch, integration points, risky areas flagged
   with why. Keep it under 200 lines — it is disposable; depth lives in the code and spec.
3. Write tasks.md: state header line first ("As of YYYY-MM-DD — stage 1 (planned), next: task 1"),
   then checkboxed tasks. Each task = one red-green cycle a reviewer could verify alone: names the
   scenario it implements, the test to write, the code area. Order: risky/unknown tasks FIRST.
4. Run `bash "$REPO_ROOT/tools/verify-docs.sh"`; it must be green before handover.
5. Present the plan to the developer for approval. Do not start implementing.
