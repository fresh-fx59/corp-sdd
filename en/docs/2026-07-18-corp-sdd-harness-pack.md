# SDD Harness Pack — complete command bodies, skills, and templates

**Companion to:** [implementation guide](2026-07-18-corp-sdd-implementation-guide.md) §5 · **Date:** 2026-07-18
This file makes the doc set self-sufficient on a **restricted network**: the command bodies (five here in §A; the other two — `corp-spec`, `corp-implement` — are canonical in guide §5: **seven total**), all five skill texts (self-contained — no external repo needed; derived from superpowers, MIT, rewritten for this stack), and every file template. The implementing agent installs these into the port's proven locations (port-facts P1–P3) and replaces `corp-*` invocation syntax per P2.

---

## A. Command bodies (7)

`corp-spec` and `corp-implement` are in the guide §5. The remaining five:

### corp-plan
```markdown
---
description: Generate design + tasks for an approved change, against TODAY's code (dev flow)
---
Plan change {{args}}. Follow skills corp-drill-down (all system facts) and corp-verification.
Precondition: proposal + delta spec exist and are approved — if not, STOP
and say which is missing.
1. Read the delta spec, research.md, and the living specs it modifies. Read the CURRENT code of
   the affected modules (use corp-drill-down; append new verified facts to research.md).
2. Write design.md: approach, files/classes to touch, integration points, risky areas flagged
   with why. Keep it under 200 lines — it is disposable; depth lives in the code and spec.
3. Write tasks.md: state header line first ("As of YYYY-MM-DD — stage 1 (planned), next: task 1"),
   then checkboxed tasks. Each task = one red-green cycle a reviewer could verify alone: names the
   scenario it implements, the test to write, the code area. Order: risky/unknown tasks FIRST.
4. Run: bash tools/verify-docs.sh — green before handing over.
5. Present the plan to the developer for approval. Do not start implementing.
```

### corp-review
```markdown
---
description: Structured pre-review of a diff before humans spend time (any role)
---
Review the diff of {{args}} (branch/PR/change). Follow skill corp-code-review throughout.
Review in this order, report findings by severity
(blocker / serious / minor), each with file:line and a concrete fix:
0. COVERAGE, from the machine first: run /opsx:verify <change-id> (add --store <id> when the
   change lives in the store). Read its report and carry it into your findings: an incomplete task
   or an unimplemented requirement (CRITICAL) is a blocker; an uncovered scenario (WARNING) is at
   least a serious finding. It checks that a test EXISTS — never that it ran — so the pasted
   test-run evidence from corp-implement is still required. If this is not an OpenSpec change, or
   the command is unavailable, say so in one line and start at 1.
1. SPEC CONFORMANCE: does the diff implement exactly the delta spec — nothing missing, nothing
   beyond scope? Unrequested changes are findings, however good they look.
2. TEST HONESTY: does each new test assert SCENARIO behavior (would it fail if the feature broke)?
   Flag tests that assert implementation details, tests weakened to pass, and scenarios with no test.
3. CORRECTNESS: bugs, edge cases from the scenarios, error handling, concurrency on shared state.
4. DISPOSER: run bash tools/verify-docs.sh; any red is automatically a blocker finding.
Do NOT approve or merge anything — output findings only; humans decide. If the diff is clean,
say so in one line; do not invent findings to look thorough.
```

### corp-test-plan
```markdown
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
```

### corp-autotest
```markdown
---
description: Generate autotest skeletons from an approved delta spec's scenarios (SDET flow)
---
Generate autotest skeletons for change {{args}} in the team's framework (ask which if unknown).
1. One test per scenario, named after it, asserting BEHAVIOR (Given/When/Then) — never internal
   calls or private state. A reviewer must see the scenario in the test without reading the spec.
2. Mark data setup / environment needs as TODO(<what>) rather than inventing fake fixtures.
3. NEVER create, read, or modify anything in the held-out gate suites or their credentials —
   if a task seems to require that, STOP and escalate to the SDET.
4. Run what is runnable; paste results. Unrunnable skeletons are handed over as drafts, labeled so.
```

### corp-archive
```markdown
---
description: Post-merge close-out — fold the delta into living specs, ADR, index (dev flow, on main)
---
Archive change {{args}}. Follow skill corp-verification (evidence for every step below).
Precondition: the change's PR is MERGED and you are on updated main —
verify both; if not, STOP.
1. Run the OpenSpec archive step (opsx archive) — delta folds into openspec/specs/.
2. Draft an ADR from the change's decisions (proposal "why" + research.md discoveries + any
   spec amendments) using the template in the harness pack; write to openspec/adr/NNNN-<slug>.md
   (next free number). ADRs are append-only: never edit an accepted ADR — supersede it.
3. Regenerate the index: node tools/gen-index.mjs
4. Run: bash tools/verify-docs.sh — must be green.
5. Commit ("archive <change-id>: living spec + ADR + index") and push. The store catalog picks
   this up on its next aggregation — no manual store edits, ever.
6. Post a one-line completion note to the tracker story via MCP.
```

---

## B. Skill texts (5, self-contained)

Install into the port's skills dir (P3), or — if the port lacks skills — inline the relevant text into the command bodies. Each ≤ 250 lines by the caps rule. These are corporate-owned: improve via PR + office-hours discussion, never ad-hoc.

### skills/corp-tdd/SKILL.md
```markdown
---
name: corp-tdd
description: Tiered test-driven development for this stack (JVM services, stream-processing jobs, JS frontend). Use for ALL implementation work.
---
## Iron law
No production code without a failing test first. No exceptions for "trivial" changes — trivial
changes with tests stay trivial; trivial changes without tests become incidents.

## The two tiers (this is the stack-specific part)
FAST tier — the inner loop, run after EVERY green step, must stay in seconds:
- JVM services: plain JUnit unit tests. No framework context. Mock at module boundaries only.
- Stream-processing jobs: an operator-test harness (single-input / keyed-input style API) for
  operators and UDFs — in-JVM, no cluster.
- JS frontend: component tests (testing-library style), pure-function tests.
SLOW tier — run at TASK boundaries and before PR, never inside the micro-loop:
- JVM services: Testcontainers / integration-context tests. Respect context caching: shared
  abstract base class, static containers, no per-class dirty-context/mock-bean scattering — a
  cache-busted suite turns 2 minutes into 15 and kills this whole discipline.
- Stream-processing jobs: embedded-cluster pipeline tests (a mini-cluster test resource).
- JS frontend: E2E/visual pass (run the app; screenshots are evidence).
DI/wiring bugs surface ONLY in the slow tier — a task touching the JVM framework's DI wiring is
not done on fast tier green alone.

## The cycle (per task in tasks.md)
1. RED: write the test from the task's scenario. Run it. SEE it fail with the expected failure —
   a test that passes immediately tests nothing; stop and fix the test.
2. GREEN: minimal code to pass. Resist adding unrequested behavior.
3. Run the fast tier. Refactor only on green. Re-run.
4. At task end: slow tier for touched areas. Paste the run output into tasks.md as evidence,
   tick the box, overwrite the state header.

## Forbidden moves
Weakening an assertion to pass · deleting/skipping a failing test · asserting implementation
details (private methods, call counts) instead of behavior · marking a task done without pasted
test output · writing tests after the code "to save time" (that is not TDD, that is decoration).
```

### skills/corp-verification/SKILL.md
```markdown
---
name: corp-verification
description: Verification before completion — no done-claims without fresh evidence. Use before reporting ANY work finished.
---
## The rule
Every claim of completion, for every kind of work, carries EVIDENCE produced AFTER the last edit:
- code → the actual test-run output (fast + slow tier as applicable)
- docs/specs → the verify-docs.sh green output
- config/infra → the command that proves the new state (service status, curl, pipeline run)
"Should work", "looks right", "the change is straightforward" are not evidence. If you cannot
produce evidence, the honest report is "implemented but unverified because <reason>" — never "done".

## Before you say done — the gate
1. Re-read the task/spec requirement you claim to satisfy. Does the evidence actually cover it,
   or something adjacent?
2. Did anything change after your last verification run? If yes, re-run. Evidence expires on edit.
3. Are all tasks.md boxes you ticked backed by evidence lines? Header updated?
4. bash tools/verify-docs.sh — green?

## Failure honesty
If tests fail: report the failure with output — never bury it, never "mostly passing".
If you weakened anything to get green: that is a red flag, undo it and report the conflict.
CIRCUIT BREAKER: the same error surviving 3 fix attempts → STOP, write up observations, ask a human.
```

### skills/corp-debugging/SKILL.md
```markdown
---
name: corp-debugging
description: Systematic root-cause debugging. Use when ANY test fails unexpectedly or behavior contradicts the spec — BEFORE attempting fixes.
---
## The law
No fix before diagnosis. A fix without a named root cause is a guess; guesses that pass are the
most expensive bugs you will ship.

## The four phases
1. READ: the actual error, verbatim, top frame first. Read the failing assertion and its actual-vs-
   expected values. Do not skim — half of all debugging ends here.
2. REPRODUCE minimally: the smallest command that shows the failure (single test > suite > app).
   Cannot reproduce → you do not understand it yet; vary one factor at a time until you can.
3. LOCATE the mechanism: trace from symptom to cause. In this stack, check boundaries in order:
   the failing unit itself → its direct inputs (what did it actually receive? log/inspect, don't
   assume) → serialization/config boundaries (event-bus message shape, DI wiring — wrong bean
   silently injected? profile/config value actually loaded?) → state (relational store/cache
   contents vs expectation) → only then upstream systems. Cross-component bugs are found at a
   boundary where reality stops matching assumption — find THAT boundary before touching code.
4. FIX THE CLASS, verify, then ask: can this same mistake exist elsewhere? Fix the pattern (or
   file it), not just the instance. Add the missing test that would have caught it.

## Forbidden moves
Shotgun edits ("try this") · adding sleeps/retries to hide race conditions · catching-and-ignoring
to silence a failure · "fixing" a held-out or contract test · deleting the failing test.
Note the finding in research.md if it revealed a spec/code mismatch → corp-implement's a/b/c flow.
```

### skills/corp-code-review/SKILL.md
```markdown
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
```

### skills/corp-drill-down/SKILL.md
```markdown
---
name: corp-drill-down
description: How to gather system knowledge — catalog to repo to live code. Use whenever work needs facts about ANY capability, module, or contract.
---
## Trust order (absolute)
live code > repo living spec > repo index > central catalog > wiki. Each level may only ROUTE you
to the level above it; only code and living specs may be QUOTED as fact.

## The walk (≤3 content-bearing hops; no sibling preloading)
1. Central catalog (system store catalog.md): find which repo owns the capability. A ⚠ STALE or
   🔴 RED marker means: do not trust the entry — go to the repo directly.
2. That repo's openspec/index.md: find the capability's living spec + relevant module. If the
   catalog and the repo index disagree, the repo index wins — note the mismatch in the tracker
   so DevOps re-aggregates.
3. The living spec, then the ACTUAL code it points to (local clone; run the sync script if the
   clone is stale — the lint warns). For contract facts (field names, endpoint/event shapes):
   read the source and EMBED it (<!-- embed: path#Lx-Ly -->) — never transcribe by hand, never
   quote a spec's prose for a shape when the source is one hop away.

## Recording (pointers, not payloads)
Every verified fact → one line in the change's research.md: path#Lstart-Lend + a one-line finding.
Never paste file contents into research.md — pointers stay fresh, payloads rot and bloat context.

## Cold start (capability in no index)
Search the catalog for related terms → search code (grep across local clones) → still nothing?
STOP and ask a human which repo should own it. NEVER scaffold a new capability without a confirmed
home; the first commit claims the name, and a wrong claim creates a duplicate-ownership mess.
New capability confirmed → create openspec/specs/<kebab-id>/spec.md in the owning repo; the index
regenerates; the catalog picks it up.

## Context discipline
Load only what the current hop needs. When assembling a large working context: spec sections
early, navigation material in the middle (disposable), code next, and RE-PASTE the exact verified
contract snippets at the very bottom, immediately before generating — recency wins for facts that
must be transcribed exactly. No single loaded artifact over ~4K tokens; use the spec's section
anchors instead of whole files.
```

---

## C. Templates

### research.md (per change; append-only; cap 400 lines)
```markdown
# Research — <change-id>

<!-- append-only; pointers not payloads; one line per fact -->
- src/payments/api/PaymentApi.java#L14-L22 — refund() takes minor units; no partial-refund overload today
- ../billing-repo: openspec/specs/invoicing/spec.md#R4 — invoices lock 24h after issue (affects refund window)
- TRACKER-123 comment 2026-07-18 — analyst confirmed: partial refunds NOT in scope this change
```

### ADR (openspec/adr/NNNN-<slug>.md; append-only, supersede-never-edit)
```markdown
# ADR-0007: Refunds processed asynchronously via outbox

- Status: accepted (2026-07-18) · Change: <change-id> · Supersedes: — · Superseded by: —

## Context
<2-6 lines: the forces — what constraint/discovery made a decision necessary>
## Decision
<1-3 lines: what was decided>
## Consequences
<the trade-offs accepted, incl. what becomes harder>
```

### Store contract spec (system-store/contracts/<contract-id>.md)
```markdown
# Contract: <contract-id> (e.g. payments-events-v2)

- Producer: <repo> · Consumers: <repos> · Status: active
- Owning change history: <change-ids>

## Shape
<!-- THE one place this contract's facts live. Spoke specs LINK here, never restate. -->
<!-- embed: <relative path into the producing repo's clone>#Lx-Ly -->
```<fence with the embedded schema/interface source>```

## Compatibility rules
<what a consumer may rely on; what the producer may change without notice>
```

### port-facts.md (system store; written during guide §0a)
```markdown
# Port facts — <port name + version> (probed YYYY-MM-DD)

| # | Question | Probe ran | Evidence (verbatim output) | Conclusion |
|---|---|---|---|---|
| P1 | config dir | ... | ... | e.g. `.acme/` |
... (P2–P8)
Re-probe on EVERY port upgrade before rollout (playbook, DevOps §2).
```

---

## D. Cross-repo story — manual checklist (Phase 2; run this by hand the first few times)

Atomicity across repos does not exist — this checklist is the discipline that replaces it. One person (the lead dev of the story) owns the whole list.

1. [ ] Analyst runs corp-spec against the story; the agent identifies >1 owning repo → decision point: is there a genuine cross-repo CONTRACT (shared shape/protocol)? If it's just two independent changes, run two normal stories and stop here.
2. [ ] Create/update the contract spec in the system store (template §C) on a store branch. Shape facts live THERE only.
3. [ ] In each affected repo: create a child change whose delta LINKS the store contract (never restates it); note the story ID in all branches (tracker linkage).
4. [ ] Review order: analyst approves the contract spec FIRST (store PR), then per-repo deltas (which are small once the contract is settled).
5. [ ] Implement per repo with corp-implement, **producer repo first**, consumers after — consumers embed the producer's real source, so it must exist.
6. [ ] Discovery mid-implementation that changes the CONTRACT → stop all repos' work → amend the store contract PR → analyst re-approves → resume. (Child-only discoveries follow the normal a/b/c flow.)
7. [ ] Merge order: producer → consumers → store contract PR last (it embeds merged reality). Between first and last merge the system is intentionally mid-transition: keep the window short (target: same day), and say so in the story.
8. [ ] Each repo runs corp-archive normally; verify the store catalog shows all repos green afterward.
9. [ ] Retro line in the story: what would have made this smoother → office hours. (This feeds the decision on when/whether to automate cross-repo orchestration — design says: not before it hurts.)

---

## E. Installation note for the implementing agent

Install order: skills first (B), then commands (A) — commands reference skills by name (each body's "follow skill corp-X" lines). Wire per the **P3 probe result**, one of three cases:
1. **Auto-trigger works** (skills load when relevant): install skills as files; the command references reinforce them. Best case, verify with the marker skill.
2. **Skills exist but load only on explicit invocation** (the expected case): prepend to each command body an explicit load instruction in the port's syntax (e.g. "Load skills corp-tdd, corp-verification before proceeding" — exact phrasing from your P3 evidence). Verify in each Step-5 transcript that the skill text actually entered the session.
3. **No skills support at all**: inline each referenced skill's full text into the command bodies (bigger commands, same discipline) and keep the skill files in the repo as the canonical source the inlined copies are synced from.
After installation, run one live transcript per command (hand-off Step 5 acceptance). All files here count as agent-written docs: they live under the disposer's caps — if a skill exceeds 250 lines, tighten it, don't raise the cap.
