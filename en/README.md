# Corporate SDD — starter kit

Everything needed to start implementing spec-driven development with an agent
(OpenSpec + vendored superpowers skills, disposer, hub-and-spoke store), plus the
two onboarding decks. Design **APPROVED**; scripts in `scripts/tools/` are
**tested** (see the guide §11 matrix). Command/skill bodies are **templates** —
adapt them to your corporate agent-CLI port after the §0a port-discovery probes.

## Read order
1. `docs/2026-07-18-corp-sdd-handoff-to-coder-agent.md` — **start here** (contract for the implementing agent: read order, ground rules, 8 execution steps).
2. `docs/2026-07-17-corp-sdd-transition-design.md` — the design & decisions (the WHY).
3. `docs/2026-07-18-corp-sdd-implementation-guide.md` — step-by-step (the HOW); §0a port-discovery is the very first task.
4. `docs/2026-07-18-corp-sdd-harness-pack.md` — full command/skill/template source (self-contained on a restricted network).
5. `docs/2026-07-18-corp-sdd-team-playbook.md` — per-role manual; hand each role its section during Phase-1 onboarding.
6. `docs/corp-sdd-transition-project-log.md` — decision log / provenance (optional deep background).

**Amendments (2026-08-04/05) — read after the six above; they supersede parts of them:**
7. `docs/2026-08-04-openspec-root-resolution-fix.md` — OpenSpec resolves its root by walking **up** and does **not** stop at a `.git` boundary, so specs silently land in the wrong repo; the npm package name is `@fission-ai/openspec` (bare `openspec` is an unrelated 0.0.0 placeholder); adds `references:` and the split-brain lint.
8. `docs/2026-08-04-corp-sdd-cross-repo-fanout.md` — cross-repo stories: the parent story **is** the store-contract ticket, one child ticket per repo, delivered by one extended `corp-spec`. Supersedes harness pack §D steps 1–4.
9. `docs/2026-08-04-corp-sdd-setup-task-for-agent.md` — the executable setup task: nine steps, each with a VERIFY whose real output must be pasted.
10. `docs/2026-08-04-corp-sdd-zoekt-setup.md` — cross-repo code search runbook (`sym:` search dies silently without `universal-ctags`).

## What's in the box
- **scripts/tools/** — the disposer & index tooling (zero-dependency Node + bash), tested against a synthetic pilot repo + store:
  - spoke repos: `corp-lint.mjs`, `gen-index.mjs`, `verify-docs.sh`, `check-openspec-root.sh`, `check-contract-split-brain.mjs`, `check-git-naming.sh`
  - system store: `aggregate-index.mjs`, `sync-repos.sh`, `index-all.sh`
- **commands/** — the 7 `corp-*` command bodies (spec · plan · implement · review · test-plan · autotest · archive). **TEMPLATE** — install into the port's command dir (guide §0a P2); replace `corp-*` invocation syntax per your port.
- **skills/** — the 5 vendored skills (tdd · verification · debugging · code-review · drill-down). **TEMPLATE** — install per P3 (or inline into commands if the port lacks skills; see harness pack §E).
- **templates/** — file templates: `research.md`, `adr.md`, `store-contract.md`, `port-facts.md`, `conventions-branching.md` (branch + commit-message convention, enforced by `check-git-naming.sh`).
- **config/** — `repos.json.example` (store clone manifest), `lefthook.yml.example` (pre-commit hook).
- **slides/** — `deck-ru-talk5.html` (the 5-minute solution talk, 10 slides — also served at https://fresh-fx59.github.io/corp-sdd/), `deck-ru-leadership.html` (для руководства), `deck-ru-team.html` (для команды). Self-contained; open in any browser (← → / пробел, T — тема, F — во весь экран, Ctrl/Cmd+P → PDF). Editable source in `slides/src/` (`node build-decks.mjs leadership team`).

## Quickstart (from the guide)
1. **§0a port discovery FIRST** (half a day) — probe P1–P8, record answers in `port-facts.md` (template provided) in the system store. This parameterizes everything below.
2. **Create the system store** (guide §1): `git init system-store`; add `config/repos.json.example` → `repos.json`; drop in `aggregate-index.mjs` + `sync-repos.sh`; run them.
3. **Onboard 2–3 pilot repos** (guide §2): `npx @fission-ai/openspec init --tools <your-agent>` (pin version); add `corp-lint.mjs` + `gen-index.mjs` + `verify-docs.sh` under `tools/`; wire lefthook (`lefthook.yml.example`); commit `openspec/repo.txt`.
4. **Vendor commands + skills** (guide §5 + harness pack §A/§B, install order §E): skills first, then commands.
5. **Smoke-test the loop** on one real small story (guide §6), then Phase 0 exit checklist (guide §8) → Phase 1.

Note: the harness is a **corporate PORT of the upstream agent CLI, not vanilla** — every `.agent/`, command-format, and MCP assumption is a default to VERIFY via §0a. The two sanctioned edits to `corp-lint.mjs` (the `.agent` scope + `\.agent\/skills\/` cap regex) rename to your port's config dir if it differs.

## Prerequisites
Node ≥ 20 (dev machines + CI agents) · OpenSpec mirrored on the internal npm registry (pinned) · `lefthook` binary via internal channel · MCP servers for tracker + wiki reachable from the port · the deployed JVM LSP MCP name confirmed.

---
Generated from the source vault, 2026-07-23. Skills derived from superpowers (MIT), rewritten for this stack. Slides content had a native-Russian editorial pass.
