# Corp SDD flow — schema

> The one-screen view. The full workflow reference, with the per-command table, is
> [`FLOW.md`](FLOW.md); installation is [`SETUP.md`](SETUP.md) and daily use is
> [`OPERATIONS.md`](OPERATIONS.md).

```text
Story / request
  │
  ▼
1. SPECIFY  — Analyst, corp-spec
  input:   intent only, or a story + wiki + living specification + current code
  first:   when given intent only, triage it with the user before specification
  output:  proposal + delta specification + research + branch + pull request
  gate:    evidence and checks pass in every affected repository
  │
  ▼
2. PLAN  — Developer, corp-plan
  input:   approved delta + current code
  output:  design.md (<200 lines) + risk-first tasks.md
  gate:    checks pass; developer approves the plan
  │
  ▼
3. IMPLEMENT  — Developer, corp-implement
  loop:    failing scenario test → smallest change → fast tests → refactor
  output:  code + tests + checked tasks + test evidence
  gate:    all tasks complete; full suite and final checks pass
  │
  ▼
4. REVIEW  — Reviewer, corp-review
  checks:  coverage → spec fit → test honesty → correctness → scripted checks
  output:  findings with severity, file:line, and fix; or clean result
  gate:    blockers fixed and verification re-run
  │
  ├─────────────────────────────┐
  ▼                             ▼
5. MANUAL TEST PLAN             6. AUTOMATED TEST SCAFFOLDS
  input: approved scenarios       input: approved scenarios
  output: tester checklist        output: one behaviour test skeleton per scenario
  notes: regression + exploratory notes: missing setup stays TODO; run what can run
  └──────────────┬──────────────┘
                 ▼
7. ARCHIVE AFTER MERGE  — Developer or release owner
  input:   merged pull request + final evidence
  output:  archived OpenSpec change and durable record
  gate:    merge is complete; required records are retained
```

## Rules carried through every stage

- The OpenSpec proposal, delta specification, and task list are the delivery contract.
- A completed claim needs fresh evidence.
- A mismatch between specification and code stops work until it is classified.
- Documentation changes run the repository verification checks: `verify-docs.sh`, index check, lint, and contract-split check.
- Humans approve plans, execute manual testing, approve, and merge; automation does not claim those actions.
