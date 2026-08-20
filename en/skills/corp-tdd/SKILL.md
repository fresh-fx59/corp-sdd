---
name: corp-tdd
description: Tiered test-driven development for this stack (Java/Spring, Flink, Next.js). Use for ALL implementation work.
---
## Iron law
No production code without a failing test first. No exceptions for "trivial" changes — trivial
changes with tests stay trivial; trivial changes without tests become incidents.

## The two tiers (this is the stack-specific part)
FAST tier — the inner loop, run after EVERY green step, must stay in seconds:
- Java: plain JUnit unit tests. No Spring context. Mock at module boundaries only.
- Flink: OneInputStreamOperatorTestHarness / KeyedOneInputStreamOperatorTestHarness for operators
  and UDFs — in-JVM, no cluster.
- Next.js: component tests (testing-library style), pure-function tests.
SLOW tier — run at TASK boundaries and before PR, never inside the micro-loop:
- Java: Testcontainers / @SpringBootTest context tests. Respect context caching: shared abstract
  base class, static containers, no per-class @DirtiesContext/@MockBean scattering — a cache-busted
  suite turns 2 minutes into 15 and kills this whole discipline.
- Flink: MiniClusterWithClientResource pipeline tests.
- Next.js: E2E/visual pass (run the app; screenshots are evidence).
DI/wiring bugs surface ONLY in the slow tier — a task touching Spring wiring is not done on fast
tier green alone.

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
