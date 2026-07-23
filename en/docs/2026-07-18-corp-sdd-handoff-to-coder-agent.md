# HAND-OFF: Implement the SDD Harness (for the implementing coder agent)

**You are the implementing agent.** Your job is to build the Phase-0 SDD harness in the corporate environment, following the implementation guide, and to prove every step with executed evidence. This document is your contract; read it fully before touching anything.

## Read order

1. This file.
2. [The implementation guide](2026-07-18-corp-sdd-implementation-guide.md) — your working instructions (§0a–§9) and tested script sources (§10, §11).
3. [The harness pack](2026-07-18-corp-sdd-harness-pack.md) — the payload you install: 5 command bodies (+ the 2 canonical ones in guide §5 = all 7), all 5 skill texts (self-contained), all file templates, the cross-repo checklist. Copy verbatim, adapt only invocation syntax and port paths per your port-facts (skill wiring per pack §E's three P3 cases).
4. [The design doc](../specs/2026-07-17-corp-sdd-transition-design.md) — reference only; consult when you need the *why* behind a rule. Do not re-litigate approved decisions.

## Ground rules (non-negotiable)

1. **The harness is a PORT of the upstream agent CLI, not vanilla.** Nothing about `.agent/`, command formats, skills, MCP config, or headless flags is a fact until you have proven it on the port (guide §0a). Write down what you prove.
2. **TESTED vs TEMPLATE labels are honest.** The five §10 scripts were executed and adversarially reviewed (guide §11) — copy them **verbatim**; do not "improve" them. Everything labeled TEMPLATE (command bodies, lefthook.yml, the CI pipeline definition, tracker/CI metric queries) is untested prose — you must execute it in the corp environment before treating it as working.
3. **Never weaken a check to make it pass.** If a disposer check is red, fix the content; if you believe the check itself is wrong, stop and escalate with evidence. Changing caps, deleting checks, or adding exemptions requires operator approval.
4. **Evidence or it didn't happen.** Every "done" claim must carry the actual command output (the passing run, the caught failure). No "should work".
5. **Circuit breaker:** the same error surviving 3 fix attempts, or any probe result that contradicts this hand-off's assumptions → STOP, write up what you observed, ask the operator. Do not creatively route around a blocked step.
6. **Keep a progress file** at the repo root of the system store: `IMPLEMENTATION-LOG.md`, with an overwrite-in-place header (`As of YYYY-MM-DD — step N, next: X`) and an append-only log of steps + evidence + decisions. Any session (including a fresh you) must be able to resume from this file alone.

## Execution plan

### Step 1 — Port discovery (guide §0a) — FIRST, before any other work
Run probes **P1–P8**; commit `port-facts.md` to the system store with, per probe: the exact thing you ran, the exact output, the conclusion. These answers parameterize everything after (command dir, command format, skills-vs-inline decision, context-file name, headless flags for CI).
**Hard gate:** if P2 (commands) and P3 (skills) both fail → STOP, escalate (§0a names the fallback options; the choice is the operator's).

### Step 2 — System store (guide §1)
Create the store repo; copy `aggregate-index.mjs` + `sync-repos.sh` from §10 verbatim; fill `repos.json` with the pilot repos the operator names. Acceptance: `sync-repos` green; `aggregate-index --strict` green; deliberately add a bogus repo name → expect loud exit 2 (input gate works); remove it.

### Step 3 — Pilot repo onboarding (guide §2)
Per pilot repo: OpenSpec init (verify P8 — relocate generated files if the port reads elsewhere); copy the three spoke scripts verbatim; **if the port's config dir ≠ `.agent`, change exactly two strings in `corp-lint.mjs`: the SCOPES entry and the CAPS skills regex** (these are the only sanctioned script edits); generate the index; wire lefthook; commit including `openspec/repo.txt`.
Acceptance: **re-run the guide §11 test matrix T0–T6 + T10 in the corp environment** (create the breakages, watch each get caught, repair, end green). Paste the run log into IMPLEMENTATION-LOG.md.

### Step 4 — Agent self-check wiring (guide §3)
Add the HARD-RULE block to the context file **P7 proved the port reads**. Acceptance: in a live port session, edit a spec to break a link, observe the session run `verify-docs.sh`, fix, and re-run green without human prompting.

### Step 5 — Commands + skills (guide §5 + harness pack)
Install the **seven** commands and **five** skills from the harness pack (§A/§B, verbatim bodies; only invocation syntax and paths adapt per port-facts; inline skills into commands if P3 failed — pack §E). Place the pack's templates (§C) where the commands expect them. Acceptance per command: one live invocation transcript showing it follows its body (corp-spec: fetches story via MCP, asks ONE question at a time, **and ends by committing + opening the spec PR with zero analyst git interaction**; corp-implement: reads tasks.md header first, runs the disposer after writes, **skill text provably loaded per §E case**; corp-archive: refuses to run off-main or pre-merge). Record transcripts (trimmed) in the log.

### Step 6 — CI backstop (guide §4)
Wire the two pipeline stages using P5's proven headless flags where needed. Acceptance: a PR with a deliberately broken index goes red in CI; the catalog job commits a refreshed catalog on a spoke merge.

### Step 7 — Champion smoke test (guide §6) + baselines (guide §7)
Support the human champion through one real small story end-to-end; every friction point = a harness bug for you to fix. Run the TESTED metric snippets; adapt the TEMPLATE ones to the real tracker/CI and relabel them in the log once executed. Store results under `baselines/` in the store.

### Step 8 — Exit
Work through the guide §8 checklist. Deliver to the operator: the checklist with evidence links, `port-facts.md`, `IMPLEMENTATION-LOG.md`, the list of every deviation you had to make (with reasons), and the [team playbook](2026-07-18-corp-sdd-team-playbook.md) updated with the port's real command syntax (replace the default `corp-*` invocations with what P2 proved) so the operator can hand each role its section.

## Decisions that are YOURS vs the OPERATOR's

| Yours (decide, record, proceed) | Operator's (stop and ask) |
|---|---|
| Command file naming/format details per port evidence | Anything requiring a new tool, service, or dependency beyond the guide's list |
| Skill text adaptation (JVM/JUnit examples, port tool names) | Changing caps, checks, schemas, or any §9 operating rule |
| Order of pilot repos within Step 3 | P2+P3 both failing (fallback strategy choice) |
| Trimming/adapting metric queries to the real CI/tracker API | Choice of pilot repos/teams; exception-path wording; anything touching prod |
| IMPLEMENTATION-LOG structure beyond the required header | Legal/license questions (e.g., anything AGPL) |

## Definition of done

Guide §8 checklist fully checked **with pasted evidence**, `port-facts.md` committed, T0–T6+T10 matrix reproduced in the corp environment, one real story completed by the champion through the full flow, zero TEMPLATE labels remaining unexecuted (each either relabeled tested-in-env with evidence, or explicitly deferred with the operator's sign-off in the log).
