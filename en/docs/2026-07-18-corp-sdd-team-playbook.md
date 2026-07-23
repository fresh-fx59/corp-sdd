# SDD Team Playbook — how each role operates the system

**Companion to:** [the design](../specs/2026-07-17-corp-sdd-transition-design.md) (why it works this way) and [the implementation guide](2026-07-18-corp-sdd-implementation-guide.md) (how it was built). This document is for **people using the system daily**. Hand each role its section plus "Rules for everyone".
Command names (`corp-spec` etc.) are the defaults — your actual invocation syntax comes from the port setup (`port-facts.md` in the system store); the flow is identical either way.

## The flow on one page

```
story in tracker
  → ANALYST  corp-spec     agent interviews you → delta spec → you approve (wiki/tracker)
  → DEV      corp-plan     agent plans against TODAY's code → you approve tasks
  → DEV      corp-implement  agent codes task-by-task, tests-first → you steer & review
  → PR       spec + code together → team review as always → merge
  → TESTER   corp-test-plan  checklist from the same scenarios → manual pass
  → SDET     corp-autotest   autotest skeletons from the same scenarios → you harden
  → DEV      corp-archive    (on main, after merge) delta folds into the living spec,
                             ADR drafted, indexes & catalog update themselves
```

The spec is written **once** and consumed **four times** (plan, implementation tests, manual checklist, autotests). That's where your time comes back.

## Rules for everyone

1. **During the pilot, the flow is opt-in per story.** The old way stays legal. If you skip the flow, add one line in the story saying so — that's the whole exception process.
2. **The disposer is law.** If `verify-docs` is red, the content is wrong — fix content, never the check. Every error message tells you how. If you believe a *check* is wrong, raise it at office hours; changing checks is a deliberate team decision, not a local edit.
3. **Never hand-edit generated files** (`openspec/index.*`, store `catalog.*`). They regenerate; your edit dies and CI goes red. The error message names the command that regenerates them.
4. **Same problem three times → stop and ask a human.** Applies to you and to the agent. Looping is never the answer.
5. **Trust order for "how does the system behave": code > repo spec > repo index > central catalog > wiki.** The wiki is a generated mirror — read it, never cite it as proof.
6. **Escalation path:** office hours weekly · champions for how-do-I questions · tracker comment on the story for content questions · never block silently.

## Analyst

**What changes for you:** you stop writing requirement documents from a blank page. The agent interviews you and drafts; you answer, correct, and approve. You never touch git — ever.

**Per story:**
1. Create/refine the story in the tracker as today.
2. Open an agent session and run `corp-spec <story-id>`. The agent pulls the story + linked wiki pages itself, reads the current living spec for that capability, checks the actual code, then asks you questions **one at a time**. Answer from business knowledge; say "I don't know" freely — an open question in the spec beats a guess.
3. Watch for the agent's code-reality prompts ("today the system actually does X in this edge case — keep or change?"). These are the gold: decisions nobody ever wrote down.
   **New feature area** (capability in no index yet)? The agent will stop and ask which repo should own it — if you don't know, that's a question for the tech lead, not a guess; the first commit claims the name.
4. Review the resulting delta spec **as a rendered page** (wiki mirror or the PR preview — whichever you were shown in onboarding): requirements + Given/When/Then scenarios. Fix wording by telling the agent, not by editing files.
5. Approve = your normal approval action (tracker status or PR approve button — per team setup). Nothing proceeds without it.
6. **Amendments:** during implementation a dev may send you "implementation found nuance X; proposed spec amendment — approve?" It arrives as a small diff. Read it, decide, reply in the tracker. This is minutes, not meetings — and each one makes the spec base smarter.

**Never do:** paste requirements from old wiki pages into the interview without checking they're still true (the agent verifies against code — let it); approve a spec whose scenarios you couldn't hand to a tester as-is.
**Quality bar:** every requirement has at least one scenario; every scenario is executable by a human tester without asking you anything.

## Backend developer (JVM / stream processing)

**What changes for you:** you shift from typing most of the code to *directing and reviewing* it. The spec answers the questions you used to interrupt the analyst with. Hand-coding any story or any task remains your right.

**Per story:**
1. Pick up the story; the approved delta spec is already in the repo. Read it — it's short.
2. Run `corp-plan`. Plans are generated **now**, against today's code — never trust a stale plan; regenerating is free. Review `design.md`/`tasks.md`: you're checking *approach*, the same judgment as before, minus the typing.
3. Run `corp-implement`. The agent works task-by-task: failing test from the scenario first (fast unit tier), then code, then evidence, then next task. Your job while it runs: answer its questions, spot-check diffs as they land, interrupt whenever your instinct says so.
4. **When the agent stops with a spec/code mismatch**, it proposes a classification — the decision is yours, one keystroke:
   - **(a) spec is incomplete** → agent drafts the amendment, pings the analyst, you wait for the diff-approval (or continue another task);
   - **(b) code surprising, spec still right** → plans regenerate, carry on;
   - **(c) spec unimplementable** → hard stop; you + analyst renegotiate. Never "creatively interpret" a contract — downstream products consume this data.
5. PR as always — spec and code in one diff. `corp-review` gives you a structured pre-review before teammates spend time. If rebasing brings a conflict **inside `openspec/specs/`**, another story changed the same requirement — the analyst decides what's true now; don't resolve contract text solo.
6. After merge, on updated main: run `corp-archive` — folds the delta into the living spec, drafts the ADR, regenerates the index. Then tick the story. (A story isn't done until archived — unarchived changes are invisible to the next spec author.)
7. **Cross-repo story?** Use the manual checklist in the harness pack §D — producer first, contract facts live in the store only, you own the whole list.

**Stack specifics:** keep the fast/slow test-tier split honest — unit tests in the inner loop, Testcontainers/integration-context tests at task boundaries only (a DI wiring mistake only surfaces in the slow tier; run it before declaring a task done). Stream-processing jobs: the stream processor's operator-test/embedded-cluster harness is the unit tier — same rhythm.
**Never do:** let the agent mark a task done without a pasted test run; fix a red disposer check by weakening it; edit `tasks.md` checkboxes by hand to "catch up" — the header and boxes are the project's memory.

## Frontend developer (JS frontend)

Same skeleton as backend — spec → plan → implement → PR — with two differences:

1. **Scenarios describe user-visible behavior** ("Given an expired session, when the user submits, then show X and preserve the form"). Push the analyst's interview toward states and edge cases: loading, empty, error, permissions. The agent turns exactly these into component tests.
2. **Your slow tier is visual.** After the agent's tasks go green, run the app/Storybook and *look* at every changed state; attach before/after screenshots to the PR (until the team picks an automated visual-diff gate, your eyes are that gate — treat screenshots as the pasted evidence backend devs give with test runs).

Agent competence is highest in this stack — expect to accept more and steer less than your backend colleagues, but review interactive behavior (focus, keyboard, async races) yourself; that's where generated tests are weakest.

## Tester (manual QA)

**What changes for you:** you stop reverse-engineering "what should I test" from story titles. The spec's scenarios are your test basis, and they existed *before the code was written*.

**Per story:**
1. When a story reaches you, open its delta spec rendered: **Phase 1 = the spec file rendered in the forge (your onboarding shows where); wiki mirror once it goes live in Phase 2** — then bookmark the catalog page; it links every capability.
2. Run `corp-test-plan <change>` (or ask the story's dev to — per team setup): the scenarios become a checklist posted to the tracker. Review it — **add what the spec missed**; your exploratory instinct is the value the system can't generate.
3. Execute; file bugs exactly as today, but reference the requirement ID (e.g. "R3 violated: …"). That ID is what lets the agent reproduce and the analyst locate the broken contract instantly.
4. A bug in *behavior the spec never covered* is a spec gap — say so in the bug; it becomes a small delta, and next quarter's you will find it in the checklist automatically.

**Optional but gold (Phase 2 habit):** review scenarios at spec-approval time — "is this testable as written?" — catching an untestable requirement before code exists is the cheapest bug you'll ever find.
**Never do:** test against what the code does and call it expected; the spec is the contract — if code and spec disagree, that's a finding, whichever way it resolves.

## SDET / autotest engineer

**What changes for you:** less boilerplate authoring; more suite ownership and, over time, guardianship of the checks the agent cannot game.

**Per story:**
1. After merge (or in parallel from the approved spec), run `corp-autotest <change>`: scenario-derived test skeletons for your framework.
2. Harden them — assertions, data setup, stability. Generated skeletons are scaffolding, not deliverables; your name goes on the suite, not the agent's.
3. Reject skeletons that assert implementation details instead of scenario behavior — regenerate with feedback. Behavior-level tests survive refactors; detail-level tests rot.

**Phase 2+ — your promotion:** you own the **held-out gates** — contract tests and compatibility checks running in credential-scoped CI jobs the implementing agent can neither read nor edit. Rules: never move a held-out test into the repo the agent works in; never let its credentials into the agent-facing job; a held-out failure is *always* investigated, never "fixed" by touching the gate.

## DevOps

**What changes for you:** one-time setup (implementation guide §0a–§4 — the implementing agent does the building; you provide access and review), then a thin steady state. You own the *harness*, not the specs.

**Steady state:**
1. **Watch the catalog job.** RED entry = a repo's index is broken or unreachable — treat like a failing build: loud, assigned, fixed same-day. STALE = last-good data being served; acceptable for hours, not days.
2. **Version pins are yours:** the OpenSpec version, lefthook, the vendored scripts. Upgrades go through a branch + the §11 test matrix re-run, never straight to main. Same for the port: any port upgrade → re-run the port-facts probes (P1–P8) before rolling out; a silent format change there strands every command.
3. **Onboarding a new repo** = implementation guide §2 (an hour); add it to `repos.json`; catalog picks it up.
4. **MCP endpoints + gateway settings** distribution and health — the agent's tracker/wiki/LSP access is infrastructure now; a dead MCP server is a team-wide outage of the analyst flow.
5. **Credential separation** (Phase 2): agent-facing CI jobs and held-out-gate jobs must never share credentials — that boundary is the whole point; audit it when touching CI config.

**Never do:** hot-fix generated files in the store; grant the agent-facing lane access "temporarily"; upgrade tools and harness in the same change (one variable at a time — you'll thank yourself when the matrix goes red).

## Where things live (all roles)

| Thing | Where |
|---|---|
| What capabilities exist, who owns what | store `catalog.md` (or its wiki render) |
| Current behavior of capability X | that repo's `openspec/specs/<x>/spec.md` (living spec) |
| What's being changed right now | repo `openspec/changes/<id>/` (proposal, delta, tasks, research) |
| Why it was decided this way | ADR notes (append-only), linked from specs |
| How this harness itself works | implementation guide + `port-facts.md` in the store |
