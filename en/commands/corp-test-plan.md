---
description: Turn an approved delta spec's scenarios into a black-box integration test plan QA can run on the dev stand (tester flow)
corp-version: 2026-08-26.7
---
Build the black-box integration test plan for change {{args}}.

AUDIENCE — read this before writing anything. The testers only see the application deployed
on the dev stand. They do not read the code and they do not test methods. Every item you
produce must be something they can send, query or observe from OUTSIDE the running system:
an HTTP request, a message produced to a topic, a row in a database, a file, a log line the
stand exposes. Payloads and queries must be copy-paste ready, not described in prose. A check
that needs internal calls or private state belongs in `corp-autotest`, not here.

TOOLS THE TESTERS HAVE. HTTP requests go through Insomnia or `curl` — so give method, full
path, headers and body as separate labeled fields (pasteable into Insomnia) AND as one `curl`
line. There is NO house CLI for producing a Kafka event yet: print the topic, the message key
and the full JSON as data the tester produces with whatever client the stand offers, and add
`TODO(produce path)` once per plan. Do not invent a produce command.

0. Set `REPO_ROOT="$(git rev-parse --show-toplevel)"`. Run
   `bash "$REPO_ROOT/tools/repository-state.sh" inspect`. If this is a local change branch, also
   run `bash "$REPO_ROOT/tools/repository-state.sh" assert-change <TICKET> --allow-dirty`.
1. The delta spec's scenarios ARE the expected behaviour — you render them into runnable form, you
   do not re-derive them. Read them and the living spec sections the change modifies (regressions
   live there), then the change's `research.md` OBSERVABLE CONTRACT block, which pins the endpoints,
   topics and stores with source pointers. The built system supplies only CONCRETE VALUES the spec
   cannot hold: generated ids, actual error bodies, dead-letter names, real wait times.
   DRIFT IS NOT YOURS TO FIX. If the built system contradicts a scenario, STOP and ask the user
   how to proceed: print the scenario, the observed behaviour and the source pointer, and offer
   the two ways out — (1) amend the delta on that branch through `corp-implement` step 4(a)
   because the built behaviour is right, or (2) leave the spec and file the mismatch as a defect.
   Do not pick for them and do not continue the plan until they answer. Writing the
   tester a plan that matches the code instead of the spec turns the plan into a description of
   whatever was built — the one thing a black-box plan must never be. Never invent a field name.
2. One test case per scenario, in this shape:
   - **ID + title** (the scenario name) and the requirement ID (e.g. R3).
   - **Preconditions** — stand, user/role and token, and the exact seed data as runnable
     `INSERT` statements or admin API calls, including the reference rows the flow reads for
     enrichment.
   - **Action** — exactly one, fully written out:
     - *API*: method, full path, headers and the complete request body as labeled fields, then
       the same request as one `curl` line.
     - *Event flow*: the topic, the message key if the topic is keyed, and the complete JSON
       event — the exact string the tester sends.
     - *UI or scheduled job*: the click path, or how the run is triggered.
   - **Expected observable result** — all that apply:
     - *Response*: HTTP status plus the complete response body. Mark generated values as
       `<uuid>`, `<timestamp>` instead of inventing them.
     - *Data*: for each affected store, name it (e.g. Postgres `orders`, ClickHouse
       `events_enriched`), give the `SELECT` the tester runs, and the expected row values column
       by column — including which columns are enriched or normalized and what they must become.
       State also what must NOT change.
     - *Messages*: the expected outgoing event(s) and their topic, full body.
     - *Timing*: for asynchronous flows, the maximum wait before the result must be visible and
       how to re-check.
   - **Cleanup**, if the case leaves state behind.
3. Negative and boundary cases for the same endpoint or topic, in the same shape: malformed
   payload, missing required field, wrong type, unknown enrichment key, duplicate or replayed
   event, out-of-order event. Give the exact error body, or the dead-letter topic and what lands
   there — "returns an error" is not an expected result.
4. Regression items for every MODIFIED requirement: the request or event as it is sent today and
   the result expected after the change, so the tester can prove nothing else moved.
5. Add a "worth exploring" section, clearly marked as suggestions rather than requirements: state
   transitions, permissions, concurrency, empty and overflow inputs, retention and partitioning.
6. Anything you could not verify becomes `TODO(<what>)`. Never fill a payload field or an expected
   value with a guess — an unmarked guess costs the tester a false failure.
7. Post the plan as a COMMENT on the SAME ticket this spec was written on — for a cross-repo story
   that is the repository's own child ticket. Do NOT create a separate test ticket: the testers
   work inside that ticket and leave their findings there. If no tracker integration is
   configured, print the plan ready to paste. Do not mark anything passed; the tester's additions
   outrank yours.
