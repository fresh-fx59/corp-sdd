# Пакет SDD-харнесса — полные тела команд, скиллы и шаблоны

**Спутник к:** [руководству по внедрению](2026-07-18-corp-sdd-implementation-guide.md) §5 · **Дата:** 2026-07-18
Этот файл делает набор документов самодостаточным в **закрытой сети**: тела команд (пять здесь в §A; остальные две — `corp-spec`, `corp-implement` — канонически изложены в руководстве §5: **всего семь**), тексты всех пяти скиллов (самодостаточные — внешний репозиторий не нужен; выведены из superpowers, MIT, переписаны под этот стек) и все файловые шаблоны. Внедряющий агент устанавливает их в проверенные места порта (port-facts P1–P3) и заменяет синтаксис вызова `corp-*` согласно P2.

---

## A. Тела команд (7)

`corp-spec` и `corp-implement` находятся в руководстве §5. Остальные пять:

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

## B. Тексты скиллов (5, самодостаточные)

Установите в каталог скиллов порта (P3) или — если в порте нет скиллов — встройте нужный текст прямо в тела команд. Каждый ≤ 250 строк по правилу лимитов. Они принадлежат компании: улучшать через PR + обсуждение на office-hours, никогда не наспех.

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
- Stream-processing jobs: the stream processor's operator-test harness (single-input and keyed
  variants) for operators and UDFs — in-JVM, no cluster.
- JS frontend: component tests (testing-library style), pure-function tests.
SLOW tier — run at TASK boundaries and before PR, never inside the micro-loop:
- JVM services: Testcontainers / full-framework-context integration tests. Respect context caching:
  shared abstract base class, static containers, no per-class context-dirtying/mock-bean
  scattering — a cache-busted suite turns 2 minutes into 15 and kills this whole discipline.
- Stream-processing jobs: the stream processor's embedded-cluster pipeline tests.
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
   silently injected? profile/config value actually loaded?) → state (DB/cache contents vs
   expectation) → only then upstream systems. Cross-component bugs are found at a boundary where
   reality stops matching assumption — find THAT boundary before touching code.
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

## C. Шаблоны

### research.md (на каждое изменение; только добавление; лимит 400 строк)
```markdown
# Research — <change-id>

<!-- append-only; pointers not payloads; one line per fact -->
- src/payments/api/PaymentApi.java#L14-L22 — refund() takes minor units; no partial-refund overload today
- ../billing-repo: openspec/specs/invoicing/spec.md#R4 — invoices lock 24h after issue (affects refund window)
- TRACKER-123 comment 2026-07-18 — analyst confirmed: partial refunds NOT in scope this change
```

### ADR (openspec/adr/NNNN-<slug>.md; только добавление, замещать-а-не-редактировать)
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

### Спека контракта в сторе (system-store/contracts/<contract-id>.md)
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

### port-facts.md (system store; заполняется во время §0a руководства)
```markdown
# Port facts — <port name + version> (probed YYYY-MM-DD)

| # | Question | Probe ran | Evidence (verbatim output) | Conclusion |
|---|---|---|---|---|
| P1 | config dir | ... | ... | e.g. `.acme/` |
... (P2–P8)
Re-probe on EVERY port upgrade before rollout (playbook, DevOps §2).
```

---

## D. Межрепозиторная история — ручной чек-лист (Фаза 2; первые несколько раз прогоняйте вручную)

Атомарности между репозиториями не существует — этот чек-лист и есть та дисциплина, что её заменяет. Один человек (ведущий разработчик истории) владеет всем списком.

1. [ ] Аналитик запускает corp-spec против истории; агент выявляет >1 репозитория-владельца → точка решения: есть ли здесь настоящий межрепозиторный КОНТРАКТ (общая форма/протокол)? Если это просто два независимых изменения — запустите две обычные истории и остановитесь здесь.
2. [ ] Создайте/обновите спеку контракта в системном сторе (шаблон §C) в ветке стора. Факты о форме живут ТОЛЬКО ТАМ.
3. [ ] В каждом затронутом репозитории: создайте дочернее изменение, чья делта ССЫЛАЕТСЯ на контракт стора (никогда не пересказывает его); укажите ID истории во всех ветках (связка в трекере).
4. [ ] Порядок ревью: аналитик СНАЧАЛА утверждает спеку контракта (PR в сторе), затем подельтовые изменения по репозиториям (которые невелики, раз контракт устоялся).
5. [ ] Реализуйте по репозиториям через corp-implement, **сначала репозиторий-производитель**, потребители после — потребители встраивают реальный исходник производителя, поэтому он должен существовать.
6. [ ] Открытие в ходе реализации, меняющее КОНТРАКТ → остановите работу во всех репозиториях → внесите поправку в PR контракта стора → аналитик заново утверждает → продолжайте. (Открытия только внутри дочернего изменения идут обычным потоком a/b/c.)
7. [ ] Порядок слияния: производитель → потребители → PR контракта стора последним (он встраивает уже слитую реальность). Между первым и последним слиянием система намеренно находится в переходном состоянии: держите окно коротким (цель: тот же день) и напишите об этом в истории.
8. [ ] Каждый репозиторий обычным образом запускает corp-archive; после этого убедитесь, что каталог стора показывает все репозитории зелёными.
9. [ ] Строка ретро в истории: что сделало бы это глаже → office hours. (Это питает решение о том, когда и стоит ли автоматизировать межрепозиторную оркестрацию — дизайн гласит: не раньше, чем станет больно.)

---

## E. Заметка по установке для внедряющего агента

Порядок установки: сначала скиллы (B), затем команды (A) — команды ссылаются на скиллы по имени (строки «follow skill corp-X» в каждом теле). Подключайте согласно **результату пробы P3**, один из трёх случаев:
1. **Авто-триггер работает** (скиллы загружаются, когда релевантны): установите скиллы как файлы; ссылки в командах их подкрепляют. Лучший случай, проверьте через маркерный скилл.
2. **Скиллы есть, но грузятся только по явному вызову** (ожидаемый случай): добавьте в начало каждого тела команды явную инструкцию загрузки в синтаксисе порта (напр. «Load skills corp-tdd, corp-verification before proceeding» — точная формулировка из вашего свидетельства P3). Проверьте в каждом транскрипте Шага 5, что текст скилла действительно попал в сессию.
3. **Поддержки скиллов нет вовсе**: встройте полный текст каждого упомянутого скилла в тела команд (команды крупнее, дисциплина та же) и держите файлы скиллов в репозитории как канонический источник, с которым синхронизируются встроенные копии.
После установки прогоните по одному живому транскрипту на команду (приёмка Шага 5 при передаче). Все файлы здесь считаются написанными агентом документами: они живут под лимитами диспозера — если скилл превышает 250 строк, ужмите его, а не поднимайте лимит.
