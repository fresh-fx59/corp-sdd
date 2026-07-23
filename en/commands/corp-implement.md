---
description: Implement the current change task-by-task under TDD discipline (dev flow)
---
Implement change {{args}}.
Discipline: follow skills corp-tdd (all coding), corp-verification (all done-claims),
corp-debugging (any unexpected failure), corp-drill-down (any fact about the system).
0. Read tasks.md state header + research.md FIRST — resume, never re-derive.
1. If design.md/tasks.md are missing or stale (index digest changed): regenerate them
   now against current code (plans are disposable, specs are durable).
2. Per task: write the failing test from the spec scenario (fast unit tier; slow
   integration tier only at task boundaries) → implement → run → record evidence in
   tasks.md → tick the checkbox → overwrite the state header.
3. On spec/code mismatch STOP and classify: (a) spec incomplete → draft amendment to
   the delta on this branch, notify analyst via tracker, wait; (b) code surprising but
   spec right → regenerate tasks, note in research.md; (c) unimplementable → halt, escalate.
4. After every file write under openspec/ or docs/: bash tools/verify-docs.sh.
5. Done = all boxes ticked + full test suite green + verify-docs green. Never claim
   done without pasted evidence of the last test run.
