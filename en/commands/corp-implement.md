---
description: Implement the current change task-by-task under TDD discipline (dev flow)
---
Implement change {{args}}.
Discipline: follow skills corp-tdd (all coding), corp-verification (all done-claims),
corp-debugging (any unexpected failure), corp-drill-down (any fact about the system).
0. Set `REPO_ROOT="$(git rev-parse --show-toplevel)"`. Run
   `bash "$REPO_ROOT/tools/repository-state.sh" assert-change <TICKET> --allow-dirty`.
   Stop on the wrong branch, missing upstream, or divergence. Then run
   `<opsx-apply-command> {{args}}` to enter the OpenSpec apply workflow. The stricter Corp TDD
   cycle below overrides any generic implementation guidance from that command.
1. Read tasks.md state header + research.md FIRST — resume, never re-derive.
2. If design.md/tasks.md are missing or stale (index digest changed): regenerate them
   now against current code (plans are disposable, specs are durable).
3. Per task: write the failing test from the spec scenario (fast unit tier; slow
   integration tier only at task boundaries) → implement → run → record evidence in
   tasks.md → tick the checkbox → overwrite the state header.
4. On spec/code mismatch STOP and classify: (a) spec incomplete → draft amendment to
   the delta on this branch, notify analyst via tracker, wait; (b) code surprising but
   spec right → regenerate tasks, note in research.md; (c) unimplementable → halt, escalate.
5. After every file write under openspec/ or docs/, run
   `bash "$REPO_ROOT/tools/verify-docs.sh"`.
6. Done = all boxes ticked + full test suite green + verify-docs green. Never claim
   done without pasted evidence of the last test run.
