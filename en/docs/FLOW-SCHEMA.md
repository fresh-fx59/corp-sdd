# Corp SDD flow — schema

> The one-screen view. The full workflow reference, with the per-command table, is
> [`FLOW.md`](FLOW.md), and the wide per-step table is [`FLOW-TABLE.md`](FLOW-TABLE.md);
> installation is [`SETUP.md`](SETUP.md), upgrading is [`UPGRADE.md`](UPGRADE.md), and daily
> use is [`OPERATIONS.md`](OPERATIONS.md).

```text
Story / request
  │
  ▼
1. SPECIFY  — Analyst, corp-spec
  input:   intent only, or a story + wiki + living specification + current code
  first:   when given intent only, triage it with the user before specification
  output:  proposal + delta specification + research + branch + commit + pull request
  gate:    checks green and `validate --type change --strict --json` says "valid": true,
           in every affected repository
  │
  ▼
2. PLAN  — Developer, corp-plan
  input:   approved delta + current code
  output:  design.md (<200 lines) + risk-first tasks.md, committed by the command
  gate:    checks pass; developer approves the plan
  │
  ▼
3. IMPLEMENT  — Developer, corp-implement
  loop:    failing scenario test → smallest change → fast tests → refactor
  output:  code + tests + checked tasks + test evidence, in ONE commit at the end
  gate:    all tasks complete; full suite and final checks pass; work pushed
  │
  ▼
4. REVIEW  — Reviewer, corp-review
  checks:  coverage → spec fit → test honesty → correctness → scripted checks
  output:  findings with severity, file:line, and fix; or clean result
  gate:    blockers fixed and verification re-run
  │
  ├─────────────────────────────┐
  ▼                             ▼
5. BLACK-BOX TEST PLAN          6. AUTOMATED TEST SCAFFOLDS
  input: approved scenarios       input: approved scenarios
  output: runnable plan on the    output: one behaviour test skeleton per scenario
          same ticket             notes: missing setup stays TODO; run what can run
  notes: regression + exploratory;
         drift between spec and the built system STOPS the plan
         and asks the user: amend the delta, or file a defect
  └──────────────┬──────────────┘
                 ▼
7. ARCHIVE AFTER MERGE  — Developer or release owner, corp-archive
  input:   merged pull request + final evidence
  output:  living specs + ADR + index, in a `docs(<TICKET>): archive …` commit
  gate:    merge is complete; assert-archivable passes; records are retained
```

## Rules carried through every stage

- The OpenSpec proposal, delta specification, and task list are the delivery contract.
- A completed claim needs fresh evidence.
- A mismatch between specification and code stops work until it is classified.
- Documentation changes run the repository verification checks: `verify-docs.sh`, which runs the
  index check, `corp-lint.mjs`, and the contract-split check.
- OpenSpec is the authority on delta-spec grammar: every command that writes or reviews a spec
  runs `<openspec> validate <change-id> --type change --strict --json`. The lint keeps only what
  the CLI is blind to.
- Each command finishes its own Git work: staged BY PATH, committed, pushed. Never `git add -A`.
- Humans approve plans, execute manual testing, approve, and merge; automation does not claim those actions.
