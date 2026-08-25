# Testing stack — <repository or project name> (recorded YYYY-MM-DD)

The two tiers `corp-tdd` runs, named in YOUR stack. Fill this in once per repository, from
what the build actually runs — not from what the team intends to use. Keep it to real
commands and real class names; an entry nobody can run is worse than an empty line.

## FAST tier — the inner loop, run after EVERY green step, must stay in seconds
| Component / module | What a fast test is here | Command that runs only these |
|---|---|---|
| ... | e.g. plain unit tests, no DI container | ... |

## SLOW tier — run at TASK boundaries and before the PR, never inside the micro-loop
| Component / module | What a slow test is here | Command that runs only these |
|---|---|---|
| ... | e.g. container-backed integration tests, end-to-end pass | ... |

## Wiring bugs
Name the boundaries in this stack that ONLY the slow tier can catch (dependency injection,
serialization, configuration profiles). A task touching one of them is not done on fast-tier
green alone.

## Debugging boundary order
The chain `corp-debugging` walks from symptom to cause in this stack, innermost first — e.g.
the failing unit → its direct inputs → serialization/config boundaries → stored state →
upstream systems. Name the concrete technologies at each step.
