---
description: Structured pre-review of a diff before humans spend time (any role)
---
Review the diff of {{args}} (branch/PR/change). Follow skill corp-code-review throughout.
Review in this order, report findings by severity
(blocker / serious / minor), each with file:line and a concrete fix:
1. SPEC CONFORMANCE: does the diff implement exactly the delta spec — nothing missing, nothing
   beyond scope? Unrequested changes are findings, however good they look.
2. TEST HONESTY: does each new test assert SCENARIO behavior (would it fail if the feature broke)?
   Flag tests that assert implementation details, tests weakened to pass, and scenarios with no test.
3. CORRECTNESS: bugs, edge cases from the scenarios, error handling, concurrency on shared state.
4. DISPOSER: run bash tools/verify-docs.sh; any red is automatically a blocker finding.
Do NOT approve or merge anything — output findings only; humans decide. If the diff is clean,
say so in one line; do not invent findings to look thorough.
