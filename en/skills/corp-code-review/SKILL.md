---
name: corp-code-review
description: Giving and receiving review on agent-written diffs. Use for corp-review runs and when responding to review feedback.
---
## Giving review (the order matters)
0. Coverage from the machine first: /opsx:verify reports incomplete tasks, unimplemented
   requirements (CRITICAL) and uncovered scenarios (WARNING). CRITICAL becomes a blocker. It
   proves a test EXISTS, not that it ran — evidence of the run stays a separate requirement.
1. Spec conformance first: the delta spec is the contract. Missing behavior = blocker. EXTRA
   behavior nobody asked for = finding too (scope creep hides bugs and unreviewed surface).
2. Test honesty second: for each test ask "would this fail if the feature broke?" A diff whose
   tests cannot fail is unreviewed code with decoration.
3. Correctness third: edge cases FROM THE SCENARIOS, error paths, nulls, concurrency.
4. Severity-tag every finding (blocker/serious/minor) with file:line + concrete fix. No vague
   "consider improving". A clean diff gets one line saying so — invented findings erode trust.

## Receiving review
- Never perform agreement ("great point!") — evaluate the finding. If correct: fix it, show the
  fixed diff + re-run evidence. If wrong: say why, with code/spec references, and let the human
  decide. Both responses are respectful; hollow agreement is not.
- A finding you fixed is not done until the evidence (test run, verify-docs) is re-produced.
- Review comments about the SPEC (requirement seems wrong) route to the analyst via the tracker —
  code review is not where contracts get renegotiated.
