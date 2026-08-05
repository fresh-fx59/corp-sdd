# Cross-repo story → one ticket, one branch, one PR per repo

**Date:** 2026-08-04 · **Supersedes** harness pack [§D](2026-07-18-corp-sdd-harness-pack.md) steps 1–4 · **Companion to:** [setup task](2026-08-04-corp-sdd-setup-task-for-agent.md) · [root-resolution fix](2026-08-04-openspec-root-resolution-fix.md) §3b

**The ask (operator, 2026-08-04):** when the analyst builds a spec that spans several repos, each
repo must get its **own tracker task for a developer, its own commit, and its own PR with the spec
already prepared**.

**Why the old checklist does not cover it.** §D assumed *one* lead dev owning the whole cross-repo
list, and step 3 said "note the story ID in all branches" — one story, many branches. That is
incompatible with two things we have since settled:

- the branch convention `feature/ABCD-1234` is **one ticket per branch**, so many branches sharing
  one story ID cannot be named;
- work should be handed to the repo's own developer, not funnelled through one person.

So the model changes: **the parent story IS the store-contract ticket, plus one child ticket per
repo.** §D steps 5–9 (implementation order, discovery handling, merge order, archive, retro) still
stand unchanged. Delivered by **one extended `corp-spec`** — there is no separate fan-out command
(§4).

---

## 1. The ticket shape

```
ABCD-1000  parent story = THE STORE CONTRACT   branch feature/ABCD-1000 in system-store
                                               approved FIRST, merged LAST
  ├─ ABCD-1001  database    producer           implemented first
  ├─ ABCD-1002  backend     consumer
  └─ ABCD-1003  frontend    consumer
```

The parent owns the contract and gets its own branch and PR **in the store**; it does not get a
child ticket of its own. Each child carries: the owning repo, the parent link, its role
(**producer / consumer**), and "blocked by" the parent.

This composes with the branch rule for free: parent and children each get `feature/ABCD-100X`, and
`check-git-naming.sh` already enforces that the commit's ticket equals the branch's ticket.

## 2. What the analyst's run produces

One `corp-spec` run on the parent (body in §4), in this order:

1. **Interview once**, at story level — the requirements are shared.
2. **Decide it is really one change.** More than one owning repo is not enough; there must be a
   genuine shared contract (a shape or protocol crossing the boundary). Two independent changes are
   two normal stories; say so and stop.
3. **Confirm the plan and wait** — repos, producer, which tickets exist, which would be created,
   how many PRs. Never fan out silently.
4. **Store contract first**, on `feature/<parent-ticket>` in the store. Shape facts live here only.
5. **Per repo:** `feature/<child-ticket>` → delta spec that **links** the contract (never restates
   it — the split-brain lint enforces this) → `bash tools/verify-docs.sh` → commit → push → PR →
   post the PR link back onto the child ticket.
6. **Set the gates.** Every implementation child is blocked by the parent. Devs may read their spec
   immediately; they may not start until the contract PR is approved.

Result: each developer opens their own ticket and finds a branch and a PR with the spec already in
it. Their first action is `corp-plan`, not orientation.

## 3. Rules that do not change, and must be in every child ticket

- **Approval order:** the contract PR is approved **first**; per-repo deltas are small once it is
  settled.
- **Implementation order:** producer first, consumers after — consumers embed the producer's real
  source, so it must exist.
- **Merge order:** producer → consumers → **store contract PR last** (it embeds merged reality).
- **Atomicity does not exist.** Between the first and last merge the system is intentionally
  mid-transition. Keep the window short — target the same day — and say so on the parent story.
- **A discovery that changes the contract stops every repo.** Amend the store PR, re-approve, then
  resume. Child-only discoveries follow the normal (a)/(b)/(c) flow.
- Each repo runs `corp-archive` normally after merge; then verify the store catalog shows every
  repo green.

## 3b. WHEN to call it — the exact step

**Once, by the analyst, on the parent story, before any developer is assigned.** Never by a
developer, never once per repo.

Placed in the team's existing flow:

| # | Today | With SDD |
|---|---|---|
| 1 | Analyst writes the parent story: intent, wiki page, clarifications, attachments | **Unchanged** |
| 2 | Analyst creates the child stories, one per repo | **Here.** Run `corp-spec <parent-ticket>` once |
| 3 | Analyst assigns each child to a developer | **Unchanged** — but each child now carries a branch, a delta spec and an open PR |
| 4 | Developer opens their story and starts | Developer's first action is `corp-plan`, not orientation |

Step 2 needs no mode. The command reads the tracker: child stories already attached to the parent
are used as they are; if there are none, it asks the analyst whether to create them or wait.

**Single-repo story?** Same command, same step — `corp-spec` takes the single-repo path (§4 step 3),
with no contract and no store branch. The analyst never has to know which case it is in advance.

**The interview happens inside the command, once, at story level** — not per repo. The requirements
are shared, so interviewing per repo asks the same questions N times and invites N different
answers.

## 4. `corp-spec` — ONE command, extended (decided 2026-08-05)

**There is no separate `corp-spec-fanout`.** The operator's call, and it is the right one: the
analyst should not have to know in advance whether a story is cross-repo — *working that out is part
of the spec run*. The drill-down is what discovers how many repos are touched, so making the human
choose the command first pushes a determination onto the person least able to make it, and adds a
seventh verb to a command surface the design already wants small.

The one real argument for a separate verb was **blast radius**: a single-repo run touches one repo,
a fan-out creates N branches and N PRs across the estate, and an agent that misjudges "is this
really one shared contract?" produces work nobody asked for. That is answered better *inside* one
command, by a **confirmation gate** (step 2 below) than by a second command name — the safety then
comes from the agent stating its plan and waiting, not from the analyst remembering which verb to
type.

Ticket handling is **data-driven**, not a configured mode: if child tickets already hang off the
parent, fill them; if there are none, ask the analyst. That retires the earlier (a)/(b) choice — it
was a false binary.

```markdown
---
description: Draft the delta spec(s) for a story via interview; fan out across repos when needed (analyst flow)
---
You are drafting the spec for story {{args}}.
Follow skills corp-drill-down (all system facts) and corp-verification (all done-claims).

1. READ + INTERVIEW, once. Fetch the story, its wiki pages and attachments via the tracker/wiki
   MCP tools. Read openspec/index.md and ONLY the living specs the story touches; follow
   corp-drill-down (central catalog → repo index → live files; repo wins; ≤3 hops). Verify every
   contract fact against live code. Interview the analyst — ONE question at a time,
   multiple-choice preferred — until requirements and Given/When/Then scenarios are unambiguous.
   Interview ONCE at story level even if several repos are involved: the requirements are shared,
   so interviewing per repo asks the same questions N times and invites N different answers.

2. DECIDE THE SHAPE, then CONFIRM before creating anything.
   Count the repos the story touches.
   - ONE repo → single-repo path. Go to step 3.
   - MORE THAN ONE repo → is there a genuine shared contract (a shape or protocol crossing the
     boundary)? If NOT, say "not a cross-repo change; this is N independent stories" and stop —
     do not fan out. If YES, go to step 4.
   Before creating any ticket, branch, commit or PR, state the plan and WAIT for the analyst:
   which repos, which is the producer, which tickets already exist, which you would create, and
   how many PRs this will open. Never fan out silently.

3. SINGLE REPO. Create the OpenSpec change (proposal + delta spec) in that repo via the opsx
   workflow. Append verified facts to research.md as pointers (path#Lx-Ly + one-line finding).
   Do NOT create design.md or tasks.md — planning happens at pull time.
   Run: bash tools/verify-docs.sh — fix until green.
   HANDOVER (do this yourself — the analyst never touches git): create/switch to the change
   branch named feature/<TICKET> for the story's ticket, commit the change folder, push, and
   open (or update) the spec PR. Post the spec summary + PR link back to the story. Done.

4. CROSS-REPO — TICKETS FIRST, driven by what already exists.
   Look at the child tickets attached to the parent story.
   - Children already exist → use them. Map each child to its repo. If a repo has no child, or a
     child names no repo, STOP and ask the analyst — never guess an owner.
   - No children exist → ask the analyst: "N repos are involved; shall I create one child story
     per repo, or will you?" Follow the answer. If they create them, wait and re-read.
   The PARENT story is the store-contract ticket — it does not get a child of its own.

5. CONTRACT FIRST. On branch feature/<parent-ticket> in the SYSTEM STORE, create/update the
   contract spec (template store-contract.md). Shape facts live there and nowhere else.
   Run verify-docs, commit, push, open the store PR, post the PR link on the parent story.

6. PER REPO, one at a time:
   a. Branch feature/<child-ticket> (naming: conventions/branching.md).
   b. Write the OpenSpec change: proposal + that repo's OWN delta spec, which LINKS the store
      contract by spec id and store id — never restates the shape. Include the fetch line:
      `openspec show <contract-spec-id> --type spec --store <store-id>`
      Append verified facts to research.md as pointers. No design.md, no tasks.md.
   c. Run: bash tools/verify-docs.sh — fix until green. The split-brain lint must pass; if it
      fires you restated a contract fact — delete it and link instead.
   d. Commit as feat(<child-ticket>): <text>, push, open the PR, post the PR link to the ticket.

7. GATES. On every implementation child record: approval order (contract first), implementation
   order (producer first), merge order (producer → consumers → store contract last), and that a
   contract change stops work in all repos. Mark each child blocked by the parent.

8. On the parent story, post the ticket → repo → role map and the intended merge window.

9. VERIFY before reporting: every child is linked and mapped to a repo; every repo has a branch,
   a pushed commit and an open PR; verify-docs green in each. Paste the evidence.
   Never claim done without it.
```

## 4b. How this maps onto the team's CURRENT flow (operator, 2026-08-05)

What they do today:

> One big story holds the intent — sometimes a wiki page, clarifications, attached documents, but
> usually intent only. The analyst then creates child stories attached to it, **one per repository**
> (e.g. database, backend, frontend), assigns them to developers, and each developer opens their own
> story and starts working.

**That structure is already the model.** Parent = intent, children = one per repo, assigned to their
own developer. Nothing about the tracker shape has to change. The differences are four, and they are
small:

| Today | With SDD | Why |
|---|---|---|
| Parent holds intent + wiki + attachments | **Unchanged** | The parent stays the intent and the discussion home |
| N child stories, one per repo | **Unchanged**, plus **one extra child for the store contract** — *only when the repos share a shape or protocol* | Shape facts need one owner; no shared shape ⇒ no extra ticket, flow untouched |
| Dev opens the story and finds intent — and interprets it | Dev opens the story and finds a **branch, a delta spec, and an open PR** already there | This is the actual gain: the first action is `corp-plan`, not orientation |
| Ordering is implicit | Each child records: contract approved first · producer implemented before consumers · merge order producer → consumers → store last | Cross-repo atomicity does not exist; the order is the substitute |

**The one real change of habit:** the wiki page stops being the contract. Intent and narrative stay
there; the *behaviour* moves into each repo's delta spec, and the shared *shape* into the store
contract. The trust order is already written down —
`live code > repo living spec > repo index > central catalog > wiki` — and the wiki sits last on
purpose. A shape restated on a wiki page is the drift this whole design exists to remove.

**Their database/backend/frontend example, concretely.** The database change is normally the
**producer** — it originates the shape — so: DB → backend → frontend for implementation, and the
same order for merge, with the store contract PR last. If the three only need a shared field
definition, that definition is the store contract and everything else links it.

### "Can the store contract live on the parent story?" — two questions, two answers

Asked by the operator 2026-08-05. It separates into the **ticket** and the **spec text**, and the
answers differ.

**The ticket: yes — and it is better than the original proposal.** Make the **parent story itself
the store-contract ticket**. It gets a branch `feature/<parent-ticket>` in the **store repo** and
its own PR; the children stay one-per-repo exactly as today. No fourth ticket, and the ordering
still reads correctly: the contract PR is approved first and **merged last**, so the parent closes
last — which is what a parent story should do anyway. §1's four-ticket diagram becomes:

```
ABCD-1000  parent story = the store contract   branch feature/ABCD-1000 in system-store
  ├─ ABCD-1001  database    producer     implemented first
  ├─ ABCD-1002  backend     consumer
  └─ ABCD-1003  frontend    consumer
```

**The spec text: no.** The contract *spec* must stay a file in the store repo, not prose in the
ticket description or the wiki. Six mechanical reasons, all of which are things we have already
built or verified:

1. It is not versioned with code — no branch, no PR, no revert, and no rebase conflict when two
   changes touch the same requirement. Conflicting edits to a ticket description just overwrite.
2. It cannot embed contract facts from source (`<!-- embed: path#Lx-Ly -->`), so it drifts silently
   the first time the code moves.
3. The agent cannot fetch it. The mechanism is
   `openspec show <spec-id> --type spec --store <store-id>`; `references:` indexes **store specs on
   disk**, not tickets. A ticket description is unreachable from the flow.
4. `check-contract-split-brain.mjs` cannot check it — it compares this repo's specs against the
   store's spec files. A contract in a ticket makes the lint blind, so nothing stops a repo
   restating the shape.
5. `corp-archive` folds deltas into living specs. A ticket gets closed and forgotten; the next spec
   author six months later finds nothing.
6. The trust order puts the tracker and wiki **last** on purpose:
   `live code > repo living spec > repo index > central catalog > wiki`.

So: the parent story **owns and links** the contract; the contract **is** `openspec/specs/<id>/spec.md`
in the store. Put the store PR link on the parent — that is the pointer, and pointers are what the
tracker is good at.

### 4c. Worked example — what is actually in each branch

The operator's restatement on 2026-08-05 was correct: *"parent story has a branch in the store; that
branch holds the contract between the repos; the contract is a delta spec; and each repo has its own
delta spec linked to the contract."* That is the model. This section just shows the files.

Story: *the order amount must reach the frontend.* Database is the producer; backend and frontend
are consumers.

**Branch `feature/ABCD-1000` in `system-store`** — the contract, and nothing else:

```
openspec/
  changes/order-amount-contract/
    proposal.md                          why the contract changes
    specs/order-events/spec.md           the DELTA: ## ADDED Requirements — the shared shape
```

`specs/order-events/spec.md` is where `amountCents` is defined, once, for everybody. After this PR
merges and `corp-archive` runs, that delta folds into the living contract at
`openspec/specs/order-events/spec.md` in the store.

**Branch `feature/ABCD-1002` in `backend`** — that repo's own behaviour, plus a link:

```
openspec/
  config.yaml                            references: [corp-store]      <- declared once, at onboarding
  changes/publish-order-amount/
    proposal.md
    specs/order-publishing/spec.md       the repo's OWN delta — what BACKEND must do
    research.md                          pointers to verified facts
```

Inside `specs/order-publishing/spec.md` the link looks like this — a pointer, never a copy:

```markdown
### Requirement: Publish the order amount
The service SHALL include the order amount when publishing OrderCreated.

Contract: spec `order-events` in store `corp-store`.
Fetch: `openspec show order-events --type spec --store corp-store`

#### Scenario: order created
- **WHEN** an order is created
- **THEN** OrderCreated is published per the contract
```

`frontend` and `database` look the same — their own delta, their own requirement, the same link.

**The three rules that make it work:**

1. **Same format everywhere.** The contract *is* a delta spec. It is not a special file type — it
   just lives in the store and describes a shape shared across repos, while a repo's delta describes
   what that repo must do.
2. **Links point one way: repo → store.** The store never lists which repos consume it. Discovery
   runs the other way, through the aggregated catalog.
3. **The shape appears exactly once.** `amountCents` is defined in the store spec and nowhere else.
   A repo delta that spells the shape out again is caught by `check-contract-split-brain.mjs` and the
   commit is rejected.

**Merge order, on these branches:** `database` → `backend` → `frontend` → **`feature/ABCD-1000` last**,
because the contract embeds merged reality.

### Who creates the child stories — decided: whoever already did

**Retired as a choice.** The command reads the tracker instead (§4 step 4): child tickets already
attached to the parent are used as-is; if there are none, it asks the analyst whether to create them
or wait. No mode to configure, no tracker write access required unless the analyst asks for it, and
the team keeps whatever habit it already has.

## 5. Honest limits

- **The tracker work depends on the tracker MCP** being reachable from the port (port-facts **P4**).
  If ticket creation is not available to the agent, it produces the branches, specs and PRs and
  hands the analyst a ready-to-paste ticket list — the fan-out still works, the filing is manual.
- **This is more PRs, not fewer.** A three-repo change is four PRs and four tickets. That is the
  price of no cross-repo atomicity; it buys parallel work by the right owners.
- **Nothing here enforces the merge order mechanically.** It is recorded on the tickets and owned by
  the parent story's assignee. A CI-level "can-i-deploy" gate is the Phase-2 answer (Pact +
  `can-i-deploy`, already in the design's held-out gates) — not built.
- Not yet tested end to end: this is a command body plus tracker conventions, not a script. Smoke
  test it on one real two-repo story before it becomes the default (design §11 Phase-2 entry).
