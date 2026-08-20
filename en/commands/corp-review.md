---
description: Structured pre-review of a diff before humans spend time (any role)
---
Review the diff of {{args}} (branch/PR/change). Follow skill corp-code-review throughout.
Review in this order, report findings by severity
(blocker / serious / minor), each with file:line and a concrete fix:
0. REPOSITORY STATE: set `REPO_ROOT="$(git rev-parse --show-toplevel)"` and run
   `bash "$REPO_ROOT/tools/repository-state.sh" inspect`. For a checked-out local story branch,
   also run `bash "$REPO_ROOT/tools/repository-state.sh" assert-change <TICKET> --allow-dirty`.
1. COVERAGE, from the machine first: run `<opsx-verify-command> <change-id>` (add the resolved
   store option when the
   change lives in the store). Read its report and carry it into your findings: an incomplete task
   or an unimplemented requirement (CRITICAL) is a blocker; an uncovered scenario (WARNING) is at
   least a serious finding. It checks that a test EXISTS — never that it ran — so the pasted
   test-run evidence from corp-implement is still required. If this is not an OpenSpec change, or
   the command is unavailable, say so in one line and start at 2.
2. SPEC CONFORMANCE: does the diff implement exactly the delta spec — nothing missing, nothing
   beyond scope? Unrequested changes are findings, however good they look.
3. TEST HONESTY: does each new test assert SCENARIO behavior (would it fail if the feature broke)?
   Flag tests that assert implementation details, tests weakened to pass, and scenarios with no test.
4. CORRECTNESS: bugs, edge cases from the scenarios, error handling, concurrency on shared state.
5. DISPOSER: run `bash "$REPO_ROOT/tools/verify-docs.sh"`; any red is a blocker finding.
Do NOT approve or merge anything — output findings only; humans decide. If the diff is clean,
say so in one line; do not invent findings to look thorough.
