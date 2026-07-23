# Corporate SDD Transition — Full Design

**Date:** 2026-07-17 · **Status:** APPROVED by operator 2026-07-18 · **Owner:** operator (day-job corp team)
**Decided baseline:** Variant A (minimal tooling). Variant B (unconstrained OSS) documented as the upgrade path.

## 1. Context and goals

A cross-functional corporate team (analysts, developers, manual testers, SDETs, DevOps) moves to spec-driven development (SDD). Environment:

- **Agent:** **the corporate agent-CLI port** (amendment 2026-07-18: not vanilla — every harness-level fact in this doc cited from the upstream agent CLI's docs, i.e. `.agent/` layout, command/skill formats, MCP config, headless flags, OTLP export, is an assumption to re-verify via the implementation guide's §0a port-discovery probes) backed by **a self-hosted open-weight model with a large context window** via an OpenAI-compatible gateway — *provided as-is; only client-side settings are ours*. Effective usable length still degrades well before the advertised limit (benchmarks put it at ~50–65%), so the design keeps its small-artifact/drill-down discipline as a quality optimization — but no work class needs special context routing.
- **Product:** big, mainly JVM-stack, multi-module builds; stream-processing jobs (real-time processing/normalization/enrichment, stateless — no savepoint restore in use); a JS frontend; the event bus + REST; a columnar OLAP store, a cache, and the relational store; downstream products consume its data. A visual dataflow tool exists but is **fully out of SDD scope** (§14). No graph database in use.
- **Repos:** many git repositories; some contain several independent modules. **CI: a self-hosted CI system.** A JVM LSP MCP server is already deployed (name TBC — Serena-class); it is part of the baseline, not an addition.
- **Tooling policy:** OSS only; product-agnostic w.r.t. tracker/wiki/forge (org is migrating off the self-hosted ALM suite to internal tools that speak **MCP**); team members can clone all repos locally; **minimal tooling preferred** (Variant A decided); no external services in the inner loop.
- **#1 design goal:** minimal friction — AI must simplify each role's work, not add ceremony. Nobody changes their primary tool; nobody's typing volume goes up.

Evidence base: three research rounds + adversarial critique (2026-07-16/17), logged in `corp-sdd-transition-project-log.md`. No credible published enterprise SDD outcome numbers exist — the org must baseline and measure its own (see §11–12).

## 2. Decisions at a glance

| # | Decision | Why (short) |
|---|---|---|
| 1 | **Combo via selective vendoring**: OpenSpec (pinned) = spec lifecycle; 4–6 skills vendored from superpowers (MIT) = execution discipline; corporate commands bridge them | Neither alone suffices: OpenSpec's `apply` has zero test/verify discipline (verified in source); superpowers has no spec lifecycle and no working agent-CLI auto-trigger (live test failed) |
| 2 | **Explicit commands, never auto-trigger** | The one invocation mechanism proven reliable on the agent CLI; auditable |
| 3 | **Specs colocated per repo** (atomic spec+code PRs) + **hub-and-spoke system store** for cross-repo contracts/index | No atomic cross-repo PR exists in git; colocated docs are the evidenced survivor (g3doc, OpenSpec default); central-only = documented drift topology |
| 4 | **Federated drill-down index**: per-repo generated index; store holds thin aggregate + helicopter view; agent drills central→repo→live code; *repo wins by construction* | = Backstage architecture; matches context ceiling; central index is routing, never authority |
| 5 | **Three-layer state**: living specs / generated maps / append-only ADRs | Volatility-matched; generated content cannot rot ("the source is the input") |
| 6 | **Requirements durable, plans disposable**: spec at story time, design/tasks at implementation-pull time | Collapses the staleness window; regeneration is cheap with an agent |
| 7 | **Disposer layer**: one deterministic verify script, 4 triggers, Hermes-style write-boundary contract | "Model proposes, code disposes"; agent output is validated, never trusted |
| 8 | **Intermediate files over big context**: change folder = on-disk state machine | effective context < advertised even at the model's large-context ceiling; multistage with todos; sessions resume from files, not transcripts |
| 9 | **Prompts advise, CI enforces** — but checks run **locally first** (pre-commit + agent self-check); CI is backstop only | CI is last in the org's flow; feedback must be at write time |
| 10 | **The visual dataflow tool fully excluded from SDD** (not in git; hand-edited on prod) | Nothing to version, nothing to gate — flagged as a standing risk outside this design |
| 11 | **Variant A first, Variant B as the next phase** (not optional luxury) | Minimal footprint proves the flow; B items enter at the phase where each pays off (§11) |

## 3. Architecture (four layers)

```
L3 ENFORCEMENT (CI backstop — helicopter level, detailed later)
   held-out checks the agent can't see/edit: contract tests (Pact-class),
   schema compatibility, migration lint; credential-scoped jobs
L2 EXECUTION DISCIPLINE (corporate-owned, per-repo, versioned in git)
   vendored skills: tiered-TDD-jvm, verification-before-completion,
   systematic-debugging, code-review, drill-down protocol, stack skills
   (jvm-test-tiers, stream-harness-tdd) + ~6 corp commands
L1 SPEC LIFECYCLE (OpenSpec, pinned)
   living capability specs + delta changes per repo; system store hub;
   wiki mirror + tracker links via MCP
L0 MODEL & BRIDGES (given)
   the agent CLI → corporate gateway (settings tweak only); MCP to tracker/wiki;
   local clones of all repos via repos.yaml manifest
```

Two principles govern everything: **(a)** prompts and skills are advisory — every rule that must never break is enforced by deterministic code (L2→disposer, L3→CI); **(b)** all agent workflows are entered via explicit commands.

## 4. Topology, index, and state

### 4.1 Hub-and-spoke

- Each code repo owns `openspec/` (living specs + change folders) → spec and code merge in **one PR**, revert together, version with release branches for free.
- One **system store** repo (plain git — *no dependency on OpenSpec stores-beta features*): cross-repo integration contracts, org conventions + schemas, helicopter system description, capability-ownership registry (capability → owning repo; others declare `consumes`, never `owns`), `repos.yaml` clone manifest, and the aggregated index.
- **Placement rule:** a spec lives in the repo where its implementing PR lands; no single home → store.
- **Split-brain rule (blocker-level):** each contract fact lives in exactly one place; spokes link, never restate (lint-checked).
- Release branches: colocation solves spoke-level versioning; the central index/store describe `main` only and are discovery-only elsewhere.

### 4.2 Federated drill-down index

- **Per-repo** `openspec/index.yaml` (machine) + `index.md` (human): identity (handwritten, tiny) + capability list, contract *pointers* (ID + path, never the shape), module map — **all generated by a committed script** from `openspec/` + build manifests; canonicalized output; stamped `generated_from: <SHA>`.
- **Central aggregate**: one entry per repo (link, 1-paragraph description, capability one-liners, source SHA+timestamp), **pushed by spoke CI on merge** + daily full rescan; on bad input keep last-good and mark `stale` with reason; invalid repo shows **red** on the helicopter view, never silently omitted; moves leave tombstone redirects.
- **Drill-down contract** (a vendored skill): central index → target repo's own index → live files in the **local clone** (sync script refreshes; lint warns when a clone is behind origin). Central is navigation only; *repo wins by construction*; freshness = compare stamp SHA to HEAD. Budget: ≤3 content-bearing hops, search-first, no sibling preloading.
- Context assembly order (mid-tier model, lost-in-the-middle): specs early → navigation middle (disposable) → code → **re-paste verified contract snippets at the bottom** immediately before generation. Single artifact cap ~4K tokens; specs section-addressable.

### 4.3 Three-layer state (hardened)

| Layer | Content | Mechanics |
|---|---|---|
| Living specs | current behavior per capability | updated only by the archive step; contract facts **embedded from source** (embed-verify in CI), `sources:` front-matter list drives freshness flags; checkable claims become ArchUnit rules, not prose |
| Generated maps | navigation only | **two kinds**: module/dependency skeleton from the build (depgraph-maven-plugin / Gradle graph / jdeps — deterministic, immune to duplicate-symbol failure of PageRank-style maps) + per-module ranked maps; ≤1–2K tokens each; CI regenerate-and-diff |
| Notes (WHY) | decisions & rationale | **append-only ADRs** (immutable, superseded-by links) — agent-drafted at archive (evidence: ~50% of manual ADR adoptions die); one tiny mutable "current state" note per repo allowed |

Hard rules: state files **point at truth, never cache it**; anything asserted as contract is embedded/verified from live code.

## 5. Command surface and roles

Six verbs carry the whole methodology (project-scoped, explicit):

```
corp spec <story>   analyst+agent: MCP-pull story/wiki → Socratic interview →
                    delta spec (reqs + G/W/T scenarios) → wiki mirror; git invisible
corp plan           dev: spec → design/tasks — generated AT PULL TIME (Decision 6)
corp implement      dev: per-task loop — failing test from scenario → code →
                    verify-with-evidence → next; pauses on ambiguity; self-check
                    via disposer before proposing any commit
corp review         structured pre-review of a diff before humans spend time
corp test-plan      tester: scenarios → manual checklist in tracker
corp autotest       SDET: scenarios → autotest skeletons
```

**The spec is written once, consumed four times** (plan, tests, tester checklist, autotests) — that's the structural simplification. Role deltas: analyst = interviewee+editor instead of document typist (never touches git); dev = steers and reviews, may hand-code any story (opt-in during transition); tester = checklist derived from scenarios instead of reverse-engineering scope; SDET = reviews generated skeletons, later owns held-out gates; DevOps = one-time setup, everything ships via the repo (clone = configured). Approval events use the forge's existing PR-approval UI (a merge gate, not a convention) — no new tool.

## 6. Drift and discovery loops

**Queue staleness** (story waits, code moves): only proposal + delta spec exist at story time (behavior-coupled, robust); all code-coupled artifacts generate at pull time. On pull: rebase (living-spec conflicts surface as ordinary git conflicts), then a semantic freshness pass flags requirement-level drift; open changes touching the same capability are listed at propose time.

**Mid-implementation discovery** (spec ≠ code reality): stop, classify — **(a)** spec incomplete → agent drafts the amendment to the still-mutable delta on the same branch; analyst approves a diff via tracker; **(b)** code surprising but spec right → regenerate design/tasks, spec untouched; **(c)** spec unimplementable → hard stop, escalate with evidence. Every (a) ratchets the living spec toward reality — early on (a) is frequent and is spec-base growth, not failure. Cross-repo variant: amendment fans out to a store PR (2–3 PRs, accepted cost — see risks).

## 7. The disposer layer

One script, `scripts/verify-docs.sh`, ordered cheap→expensive, fully offline (tools hands-on verified):

1. **Caps table** — hard per-file line/char limits (`wc -l` loop; e.g. index.md ≤300, module map ≤150, tasks.md ≤200, research.md ≤400)
2. **Schemas** — `check-jsonschema` (or ~20-line ajv+gray-matter Node script) for `index.yaml` + spec front-matter; **schemas carry the pollution limits** (`maxLength`, `maxItems`, `additionalProperties: false`)
3. **Links+anchors** — `lychee --offline --include-fragments` (catches broken cross-file heading anchors, ~0s)
4. **Embeds** — `embedmd -d` (contract snippets byte-checked against source)
5. **Generated drift** — regenerate index/maps, diff vs committed, fail on difference
6. **Structure** — forked `lint-notes.mjs` (zero-dep Node, ~240 lines): frontmatter enum/date checks, kebab-case, required sections per type (delta has ADDED/MODIFIED/REMOVED; tasks.md has state header + well-formed checkboxes), index bijection, restate-lint, stage input-gates, **remediation hint on every error** (what lets a mid-tier model self-correct)

**Four triggers, one code path:** agent post-write self-check (write → verify → stderr → regenerate; CI never sees first drafts) → **lefthook** pre-commit (blocking on ERRORs; Go single binary — no Node for JVM devs, no Python for anyone) → on demand → CI backstop (identical script). Vendored binaries: lychee, embedmd, lefthook. Rejected: pre-commit.com (Python + network), husky (Node-only).

**Write-boundary contract** (Hermes precedent, NousResearch/hermes-agent): hardcoded caps live in version-controlled schemas + caps table; violations are **rejected with remediation text** ("index.md is 320/300 lines — split module details into module maps"), never trimmed or auto-fixed; budgets in chars/lines (model-independent); repeated failures hit a circuit breaker (stop, ask human) instead of looping.

**Acceptance test for the whole design: if a repo's index can be wrong while its CI is green, the design has failed.**

## 8. Intermediate files (multistage working memory)

The change folder is the agent's cross-stage, cross-session state machine — sessions stay small because state lives on disk (a personal note-vault / OpenAI exec-plans / Manus / Anthropic note-taking convergence):

| File | Discipline | Role |
|---|---|---|
| `proposal.md` + delta | durable, approved | the contract |
| `research.md` | append-only; **pointers not payloads** (path/SHA/one-line finding) | drill-down evidence gathered once, read by all later stages |
| `tasks.md` | checkboxes + overwrite-in-place header "As of DATE — stage N, next: X" (lint-enforced) | resume point + progress; constant header rewrite doubles as recitation against lost-in-the-middle |
| `design.md` | disposable, regenerated | the how, at pull time |
| decisions | append → ADR at archive | WHY layer feed |

Disposer checks cover these files too — the agent cannot pollute its own working memory past the caps.

## 9. Variant A — minimal tooling (DECIDED)

Complete bill of materials beyond what the org already runs (forge, CI, tracker/wiki MCP, the agent CLI + gateway):

| Piece | What it is | License |
|---|---|---|
| OpenSpec | spec lifecycle CLI, **version-pinned**, TOML-command + `/opsx:` naming quirks accepted | MIT |
| Vendored skills + 6 commands | markdown in each repo (`.agent/`), seeded from superpowers | MIT source |
| corp-lint | forked `lint-notes.mjs`, zero-dependency Node | ours |
| `verify-docs.sh` + caps table + schemas | the disposer | ours |
| lefthook, lychee, embedmd | 3 vendored static binaries | MIT / MIT+Apache / Apache |
| check-jsonschema *or* ajv script | schema validation | Apache / MIT |
| Index generator + aggregator + `repos.yaml` sync script | ~3 small scripts | ours |
| System store | a plain git repo | — |

That is the entire footprint: one CLI, three binaries, a handful of scripts, markdown. No services, no databases, nothing to operate.

## 10. Variant B — unconstrained OSS (the next phase, per Decision 11)

Same architecture; additions ranked by value per unit of operational burden (licenses verified 2026-07-17). Each item enters at the rollout phase named in §11. Note: the org's **existing JVM LSP MCP** already covers the symbol-navigation half of item 1 — wire it into the vendored skills from day one (Variant A), and only add Serena (oraios/serena, MIT — the likely candidate for what's already deployed) if the incumbent proves weaker.

**Top 3:**
1. **Zoekt** (Apache-2.0) — trigram cross-repo search (two small Go services + mirror cron); pairs with the existing LSP MCP for symbol-precise follow-up. Largest agent-quality delta on a multi-module JVM estate. *Enters: Phase 2, when cross-repo work starts.*
2. **promptfoo** (MIT) — golden-set regression suites for every corporate command/skill, run on each skill edit and any model swap; near-zero infra. The insurance policy for "the model changed under us." *Enters: Phase 2 entry — guard the skills before they spread beyond the pilot.*
3. **OTel Collector + Langfuse** (MIT core; ee/ carve-out) — the agent CLI has **built-in OTLP export**, so cost/latency/failure-rate per team and command is nearly free to wire; self-hosts offline (the relational store + a columnar OLAP store + a cache + MinIO). *Enters: Phase 3, when the org asks "what does this cost and where does it fail."*

**Middle — when the trigger fires:** **Sveltia CMS** (MIT) form-based spec editing for non-git analysts (git commits under the hood, schema-constrained) — *Phase 2 if analysts resist PR-based review*; **Renovate** self-hosted (AGPL — flag to legal) to pin/update OpenSpec, lefthook, skills via internal registry mirrors — *Phase 3*; a CI-cron doc-gardener (headless agent CLI + gardener command → draft PR) — *Phase 3*.
**Luxury — defer:** **Backstage** (Apache-2.0, CNCF incubating) as catalog UI over the same hub files — highest standing cost in class, duplicate of the git index until org scale forces a UI (no credible lighter OSS exists); **PR-Agent** (The-PR-Agent/pr-agent, MIT — governance just moved from Qodo, pin SHA and watch two quarters) as an independent review lane; OpenHands reviewer (bounded experiment only); DeepEval; spec-workflow-mcp dashboard (GPL + format-coupled — steal the UX only).
**Disqualified under strict OSS:** Sourcebot (FSL), Arize Phoenix (Elastic License), a SaaS visual-diff service, Atlas (EULA + paywalled lint/columnar-store adapter), Liquibase 5+ (FSL), Confluent Schema Registry (Community License). License flags for legal: AGPL (Renovate, Doc Detective), GPL (spec-workflow-mcp if ever used).

## 11. Phased rollout

Evidence anchors: social exposure drives trial (+216% skip-level peer effect) but *adoption ≠ retention*; top-down provisioning "creates access, not motivation"; golden-path practice = opt-in → default → require **only after >80% voluntary adoption** (mandate as ratification of reality); DORA 2025: AI amplifies existing system health and raises instability — watch second-order metrics; baseline before rollout; measure team-level only.

**Phase 0 — Baseline & foundation (4–6 wks).** Store + index live; disposer + lefthook in 2–3 pilot repos; skills/commands vendored; MCP wiring; **capture baseline** (DORA-5 from existing data + anonymous DevEx pulse). Pilot teams picked 20/60/20 (evangelist/representative/skeptic). *Exit:* metrics queryable per pilot repo; lint green; named champions; documented exception path; one champion has run the full single-repo lifecycle on a real story.

**Phase 1 — Opt-in pilot (6–12 wks, 2 repos, assistant level).** Real stories through the flow; weekly office hours; internal demo day (visibility is the adoption lever); champions author first ADRs. *Exit (expand):* ≥60% of pilot feature changes use the flow voluntarily for 4 consecutive weeks; ≥10 archived changes; **indexes stayed green without human effort**; pulse ≥ baseline; rework + change-failure flat-to-down. *Hold:* adoption low but satisfaction positive → fix friction, re-run. *Rollback:* satisfaction materially below baseline or CI-reliability/review-quality degradation attributable to the flow.

**Phase 2 — Default with exception path (12–24 wks, module-by-module).** SDD becomes the *default* for feature work (mechanical checks blocking; process default-not-mandated); spec approval via forge gate; SDET autotest generation; held-out gate v1 in CI (credential-scoped jobs); devs shift review-heavy — preserve pairing/mentoring rituals, frame SDD as *spec authorship* (identity mitigation). **Variant B enters:** promptfoo at phase entry (regression-guard the skills before they spread); Zoekt when cross-repo stories start; Sveltia if analysts resist PR review. *Exit:* >80% voluntary org-wide; lead time flat-to-improving; review time per PR not inflating; spec-amendment rate declining within changes (experimental signal).

**Phase 3 — Required-with-exceptions, steady state.** Spec artifacts required for feature-class changes; exceptions logged, path stays forever; quarterly review; selective headless autonomy for low-risk classes via CI agent lanes. **Variant B completes:** OTel+Langfuse observability, Renovate version hygiene, a CI-cron doc-gardener; Backstage/PR-Agent remain deferred until org scale forces them. **Sunset criterion:** two consecutive quarterly reviews showing attributable delivery degradation → de-mandate back to default.

## 12. Metrics (team-level only; baseline first)

| Metric | Target | Note |
|---|---|---|
| Voluntary flow adoption (archived changes ÷ feature merges) | ≥60% pilot, >80% phase-2 | check spec-commit precedes impl-commit (anti-gaming) |
| Retention (dev active ≥5 of first 14 days) | up | separates tried from stayed |
| DORA-5: lead time, deploy freq, rework rate, CFR, MTTR | flat→improving; instability watched | rework rate is the AI-era addition |
| Review time per PR | flat (guard) | throughput inflates exactly when review bottlenecks |
| Spec-amendment rate per change | declining = spec base converging | **ours/experimental**; pair with completeness lint |
| Pre-commit vs CI catch ratio | CI catches → ~0 | proves the disposer works locally |
| DevEx pulse (SPACE: satisfaction, flow, review) | ≥ baseline | perceptual measure required; METR: self-reported speed is unreliable (~39pp gap) — never a gate |

**Anti-metrics (never):** LOC, % AI-written code, individual acceptance rate, individual rankings.

## 13. Risk register (consolidated)

| Risk | Sev | Mitigation |
|---|---|---|
| Index rot = new wiki-rot | blocker if manual | 100% generated content, CI drift-fail, acceptance test §7 |
| Split-brain (store vs spoke spec) | blocker if unaddressed | one-place rule + restate lint |
| Mid-tier model vs OpenSpec's frontier tuning | serious | L2 discipline skills + disposer + small deltas; promptfoo (B) on model swap |
| Cross-repo: no atomic spec+code merge across repos | serious, accepted | manual checklist first; no orchestration until proven need (context is no longer the constraint at the model's large-context ceiling — the 35–48K cross-repo load fits comfortably) |
| OpenSpec churn (TOML deprecation #838, naming #680, fast-path #1212, stores-beta) | serious | pin version; explicit commands; never depend on beta-only features; Renovate (B) |
| Agent output pollution | serious | write-boundary contract §7 (reject-with-remediation, hard caps) |
| Dev identity shift → resistance | serious | opt-in per story, escape hatches, champions as mentors, spec-authorship framing, team-level metrics only |
| JVM integration-test slowness kills TDD loop | serious | tiered TDD skill + context-cache discipline as prerequisite in pilot repos |
| Stale local clones | annoyance | sync script + lint warning; SHA stamps |
| Wiki-mirror lag / manual edits lost | annoyance | generated-page banner; push-on-merge |
| Sonnet-class placeholder failures in subagent workflows (observed 3×) | process note | structured outputs validated; journals checked; disposer catches file-level junk |
| Harness is a port of the upstream agent CLI — vanilla-derived mechanics may not hold | serious | guide §0a port-discovery probes P1–P8 before anything else; commands over skills if auto-trigger absent; escalate if neither commands nor skills exist |

## 14. Scope boundaries & open questions

**Boundaries:** **The visual dataflow tool — fully out of SDD scope**: flows are not in git and are hand-edited on prod. This design does not attempt to cover them; recorded as a standing operational risk *outside* the SDD program (unversioned prod-edited artifacts), worth its own initiative someday, not this one. **No graph-oriented store in use; skipped.** **The stream processor** — operator-harness/MiniCluster TDD applies (fast in-JVM loop); no savepoint gate needed for the current stateless real-time jobs — revisit only if stateful jobs with restore appear. **The JS frontend** — lowest-risk pilot zone.
**Open:** visual-regression choice for frontend (OSS substitute vs SaaS exception); legal sign-off on AGPL items when Variant B phases arrive; exact name of the deployed JVM LSP MCP (confirm and wire into skills); **the corporate agent-CLI port's actual capability surface** (guide §0a P1–P8 — answers parameterize the whole command/skill layer).

## 15. Provenance

Built from: deep-research workflow (105 agents, 23/25 claims verified 3-0), gap-fill (4 agents), four-agent layer trade-off deep-dive (OpenSpec/superpowers source + trackers read directly), stores/state verification (primary docs + evidence agent), state-index refinement (2 research + adversarial critic with token budgets), disposer/files research (starter harness + Hermes read, tooling hands-on verified), variant-B + rollout research (licenses verified 2026-07-17). Full trail: `corp-sdd-transition-project-log.md`.
