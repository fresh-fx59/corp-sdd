# Corporate SDD — Step-by-Step Implementation Guide

**Companion to:** [2026-07-17-corp-sdd-transition-design.md](../specs/2026-07-17-corp-sdd-transition-design.md) (APPROVED) · **Date:** 2026-07-18
**Hand-off:** implementing agent starts with [2026-07-18-corp-sdd-handoff-to-coder-agent.md](2026-07-18-corp-sdd-handoff-to-coder-agent.md). **Team-facing manual:** [2026-07-18-corp-sdd-team-playbook.md](2026-07-18-corp-sdd-team-playbook.md) — hand each role its section during Phase-1 onboarding.
**Amendment 2026-08-04 — Zoekt moved Phase 2 → Phase 0:** the generated `openspec/index.md` indexes specs + modules only and starts at 0 capabilities on a brownfield repo, so cross-repo code search is the agent's day-1 map of the estate. Tested runbook: [2026-08-04-corp-sdd-zoekt-setup.md](2026-08-04-corp-sdd-zoekt-setup.md) — install, the silent `sym:`-without-ctags trap, `tools/index-all.sh`, and the agent JSON contract. Add its §1 to §0b prerequisites and its exit rows to §8.

> **⚠ THE HARNESS IS A PORT.** The org runs a **corporate port of the agent CLI, not upstream**. Every harness-level mechanic in this guide that came from the upstream agent-CLI docs — the `.agent/` config directory, custom-command location/format, Agent-Skills support, MCP wiring, headless flags, context-file name — is a **default assumption to VERIFY against the port** (§0a), never a fact. The §10 scripts (five original + four added 2026-08-04/05) are harness-agnostic (pure Node/bash over files) and unaffected, except two strings in `corp-lint.mjs` that name the config dir: the `SCOPES` entry `.agent` and the `CAPS` regex `\.agent\/skills\/` — rename both to the port's config dir if it differs (these two strings are the only sanctioned script edits).

**Verification status:** every script in §10 was executed against a synthetic pilot repo + store, then an **independent adversarial reviewer re-executed the whole guide from scratch** and filed 11 findings (1 blocker, 4 serious) — all fixed and re-proven. Full matrix in §11 (T0–T18). Items marked **TEMPLATE** were *not* executed (need your real CI/tracker/agent CLI) — smoke-test them before relying on them.

**Declared deviations from the design doc** (all in service of zero-dependency determinism):
1. Machine index is **`index.json`** (not yaml) — native parse, canonical output. Same for **`repos.json`**.
2. The repo-level freshness stamp is a **content `source_digest` + committed `openspec/repo.txt`** instead of a git SHA (a SHA can't reference its own commit; a digest is self-consistent and machine-independent). The design's "compare stamp to HEAD" freshness check lives at the **store** level: catalog entries carry each clone's HEAD SHA.
3. Aggregator implements **keep-last-good**: a red repo's previous entry is carried, marked `stale`, never silently dropped.
4. The design's external checkers (lychee, embedmd, check-jsonschema) are **folded into corp-lint natively** (link/anchor, embed, schema checks — tested T2/T3/T13): fewer binaries to distribute, same guarantees. lefthook remains the only third-party binary.

## 0a. Port discovery — do this FIRST (half a day)

Establish what the corporate port actually supports. Record every answer in **`port-facts.md` in the system store** (committed — it parameterizes the rest of this guide). For each item: run the probe, paste the evidence.

| # | Question | Probe | Vanilla default (assumption only) |
|---|---|---|---|
| P1 | Project config dir name? | create a repo-local settings/config file where the port docs say; confirm the port reads it | `.agent/` |
| P2 | Custom slash commands supported? Location + format? | drop a trivial `hello` command (Markdown, then TOML if needed); invoke it; note the exact palette syntax | `.agent/commands/*.md` (TOML legacy); `/name` or `name` |
| P3 | Agent Skills supported (model-invoked SKILL.md)? | place a marker skill ("when asked POLO respond MARCO"); test both auto-trigger and explicit invocation | `.agent/skills/<name>/SKILL.md`; auto-trigger unreliable — plan for explicit |
| P4 | MCP config surface? Tracker/wiki/JVM-LSP MCP reachable from the port? | register one known-good MCP server; list tools from a session | `mcpServers` in settings.json (stdio/HTTP/SSE) |
| P5 | Headless mode for CI? | run the port non-interactively with a prompt; capture output format + exit code | `-p`, `--yolo`, `--approval-mode`, `--output-format json` |
| P6 | Gateway env route? | point the port at the self-hosted model gateway via env; confirm a completion | `OPENAI_BASE_URL/_API_KEY/_MODEL` |
| P7 | Context file the port auto-reads? | marker line in candidate files (`AGENT.md`, `AGENTS.md`, port-specific); see which lands in context | `AGENT.md`/`AGENTS.md` |
| P8 | Does `openspec init --tools <your-agent>` output land where the port looks? | run it; if not, try other OpenSpec adapters or hand-place the generated files per P1/P2 answers | adapter targets `.agent/` |

If P2 **and** P3 both fail: the port cannot host the command surface — STOP and escalate to the operator (fallback design: plain prompt files the team pastes, or wrapper shell aliases invoking headless mode — a real degradation worth a human decision).

## 0b. Prerequisites (once)

- [ ] Node ≥ 20 on dev machines and CI agents (the disposer is zero-dependency Node + bash).
- [ ] **OpenSpec mirrored on the internal npm registry** under its REAL name **`@fission-ai/openspec`** (restricted network — `npx @fission-ai/openspec` must resolve internally) and version-pinned. The bare name `openspec` is an unrelated placeholder at 0.0.0 with no binary.
- [ ] The corporate agent-CLI port installed per team standard; gateway settings distributed (per **P6**).
- [ ] MCP servers for your tracker + wiki reachable **from the port** (per **P4**); confirm the name of the deployed **JVM LSP MCP** and its connection config.
- [ ] `lefthook` binary available via your internal package channel (single Go binary; per-OS).
- [ ] Pick 2–3 pilot repos (mix: one JVM multi-module, one simpler — 20/60/20 evangelist/representative/skeptic teams).
- [ ] Capture **baseline metrics before any rollout** (§7).

## 1. Create the system store (30 min)

```bash
git init system-store && cd system-store
mkdir -p tools contracts conventions
cat > repos.json <<'EOF'
{ "clones_dir": "../clones", "repos": [
  { "name": "pilot-repo-a", "url": "ssh://git@your-forge/org/pilot-repo-a.git" },
  { "name": "pilot-repo-b", "url": "ssh://git@your-forge/org/pilot-repo-b.git" }
] }
EOF
# add tools/aggregate-index.mjs and tools/sync-repos.sh from §10
chmod +x tools/sync-repos.sh
bash tools/sync-repos.sh              # clone/adopt local clones (exit 1 on any failure)
bash tools/sync-repos.sh --prune --dry-run   # clean-up preview (see §1b) — deletes nothing
node tools/aggregate-index.mjs       # builds catalog.json + catalog.md (RED entries are loud)
git add -A && git commit -m "system store: skeleton + first catalog"
```

### 1b. Adopt what is already there, then clean up (10 min)

**A clone that already exists is ADOPTED, never re-cloned and never overwritten.** That is
what makes this safe to point at a machine where someone already cloned half the estate by
hand: `sync-repos.sh` proves the directory is the repo `repos.json` names, then fast-forwards
it. What it does with every case, and what you do about it:

| On disk | The script | Your fix |
|---|---|---|
| nothing | clones it | — |
| the right repo, clean | fetch + `--ff-only` pull, reports `↑ N commit(s)` | — |
| the right repo, local edits | adopts, **does not pull** (⚠) | commit or stash, re-run |
| the right repo, detached HEAD | adopts, does not pull (⚠) | `git -C <clone> checkout <branch>` |
| a clone whose `origin` is a **different** repo | 🔴 refuses, exit 1 | `git -C <clone> remote set-url origin …`, or fix `repos.json` |
| a directory that is not a clone | 🔴 refuses, exit 1, **touches nothing** | move it aside yourself |
| a clone nobody listed (**stray**) | ⚠ reports it | the clean-up below |

**Clean-up — run it once the store is up, and after every change to `repos.json`:**

```bash
bash tools/sync-repos.sh --prune --dry-run   # what --prune would remove; removes nothing
bash tools/sync-repos.sh --prune             # remove strays that hold no local work
```

`--prune` deletes a stray **only** if it is a git clone with no uncommitted changes, no commits
missing from every remote, and no stashes. Anything else it refuses out loud, with the reason
and the command to look at it. That distinction is the whole point: strays are usually
leftovers of a half-finished setup, but one of them can be the only copy of somebody's branch.

**Keeping the clones current afterwards** is the same one command — it is idempotent, so run it
before any cross-repo change and nightly in CI (§4): `bash tools/sync-repos.sh`. Exit codes:
`0` fine (⚠ warnings still print), `1` a clone needs a human, `2` `repos.json` is invalid.
Nothing in the store writes to `clones/`, so a clone you would rather not debug can always be
deleted and re-created.

Repo names in `repos.json` are input-gated (`[a-z0-9._-]`, unique) — both tools refuse invalid config with exit 2. Also seed: `helicopter.md` (one page: systems, integration edges), `conventions/` (org rules the commands reference), `contracts/` (empty until the first cross-repo change). Build the ownership registry when the first collision appears — not before.

## 2. Onboard each pilot repo (~1 hour each)

> **⚠ BLOCKER FIXED 2026-08-04 — read [2026-08-04-openspec-root-resolution-fix.md](2026-08-04-openspec-root-resolution-fix.md) before running this section.** OpenSpec resolves its root by walking **up** from the current directory for an `openspec/` dir, and **the walk does not stop at a `.git` boundary** (verified, 1.7.0). A repo that skipped this section — or that sits inside the store's tree — silently writes every spec into the **store** instead of the code repo. Two rules follow: run this section on *every* code repo before any spec work, and keep clones **outside** the store (`repos.json` ships `"clones_dir": "../clones"`, a sibling, on purpose). Assert with `openspec context` or `tools/check-openspec-root.sh`. Also corrected there: the npm name is **`@fission-ai/openspec`** — the bare name `openspec` is an unrelated placeholder at version 0.0.0 with no binary.

```bash
cd pilot-repo-a
npx @fission-ai/openspec init --tools <your-agent>  # pin the version; verify output lands per P8 —
                                        # if the port reads a different dir, move/symlink the
                                        # generated command+skill files to the P1/P2 locations
mkdir -p tools
# add tools/corp-lint.mjs, tools/gen-index.mjs, tools/verify-docs.sh from §10
chmod +x tools/verify-docs.sh
node tools/gen-index.mjs                # first index; ALSO writes openspec/repo.txt (committed identity —
                                        # never depend on the checkout folder name; CI renames it)
cat > lefthook.yml <<'EOF'
pre-commit:
  parallel: true
  commands:
    docs-disposer:
      run: bash tools/verify-docs.sh
EOF
lefthook install
bash tools/verify-docs.sh               # must print: ✓ verify-docs passed
git add -A && git commit -m "SDD onboarding: openspec + disposer + index (incl. openspec/repo.txt)"
```

Multi-module JVM repos: also wire the module list into the index — add a build step that writes one module per line to `build/modules.txt` (Maven: the depgraph plugin; Gradle: `./gradlew -q projects | grep -oP "':\K[^']+"`), then regenerate. `gen-index.mjs` picks the file up automatically. The linter only scans `openspec/`, `docs/`, `.agent/` — build output (`target/`, `build/`) is never linted.

## 3. Agent self-check wiring (15 min per repo)

Append to the repo's agent context file (**the file P7 proved the port reads** — upstream candidates: `AGENT.md` / `AGENTS.md`):

```markdown
## HARD RULE — disposer self-check
After creating or editing ANY file under openspec/ or docs/, run:
    bash tools/verify-docs.sh
Fix every ✗ (each error carries a remediation hint) and re-run until green
BEFORE reporting work done or proposing a commit. Rejected writes are corrected
by regenerating the content — never by loosening caps or deleting checks.
CIRCUIT BREAKER: if the same error survives 3 fix attempts, STOP and ask a human —
do not keep looping.
```

This is the write-boundary contract: the same script gates the agent (post-write), the human (pre-commit via lefthook), and CI (backstop) — one code path, three triggers.

## 4. CI backstop (TEMPLATE — adapt and smoke-test)

```groovy
// CI pipeline definition stage — spoke repos
stage('docs-disposer') { steps { sh 'bash tools/verify-docs.sh' } }

// system-store pipeline: nightly + on spoke merges (webhook or cron)
stage('catalog') {
  steps {
    sh 'bash tools/sync-repos.sh'
    sh 'node tools/aggregate-index.mjs --strict'   // red repo fails the build, loudly
    sh 'git add catalog.json catalog.md && git diff --cached --quiet || git commit -m "catalog: refresh" && git push'
  }
}
```

Held-out gates (Phase 2, per design §3): separate credential-scoped CI jobs for contract tests / schema compatibility / migration lint — the agent-facing job must not share credentials with them.

## 5. Vendored commands + skills (TEMPLATE bodies — adapt to the port per P1/P2)

**The complete set lives in the [harness pack](2026-07-18-corp-sdd-harness-pack.md): all SEVEN command bodies (the six below-referenced verbs + `corp-archive` for post-merge close-out), all five skill texts (self-contained — no external repo needed on the restricted network), and every file template (research.md, ADR, store contract, port-facts) plus the manual cross-repo checklist.** Install per pack §E. Two command examples inline here to set the pattern:

**`<port-command-dir>/corp-spec.md`** — *rewritten 2026-08-05: one command now handles both the single-repo and the cross-repo case, deciding which from the drill-down. Rationale + the ticket model: [cross-repo fan-out](2026-08-04-corp-sdd-cross-repo-fanout.md) §4.*
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

**`<port-command-dir>/corp-implement.md`**
```markdown
---
description: Implement the current change task-by-task under TDD discipline (dev flow)
---
Implement change {{args}}.
Discipline: follow skills corp-tdd (all coding), corp-verification (all done-claims),
corp-debugging (any unexpected failure), corp-drill-down (any fact about the system).
0. Read tasks.md state header + research.md FIRST — resume, never re-derive.
1. If design.md/tasks.md are missing or stale (index digest changed): regenerate them
   now against current code (plans are disposable, specs are durable).
2. Per task: write the failing test from the spec scenario (fast unit tier; slow
   integration tier only at task boundaries) → implement → run → record evidence in
   tasks.md → tick the checkbox → overwrite the state header.
3. On spec/code mismatch STOP and classify: (a) spec incomplete → draft amendment to
   the delta on this branch, notify analyst via tracker, wait; (b) code surprising but
   spec right → regenerate tasks, note in research.md; (c) unimplementable → halt, escalate.
4. After every file write under openspec/ or docs/: bash tools/verify-docs.sh.
5. Done = all boxes ticked + full test suite green + verify-docs green. Never claim
   done without pasted evidence of the last test run.
```

Remaining five (`corp-plan`, `corp-review`, `corp-test-plan`, `corp-autotest`, `corp-archive`) — **full bodies in the harness pack §A**. The five skills they reference (`corp-tdd` with the fast/slow tier split, `corp-verification`, `corp-debugging`, `corp-code-review`, `corp-drill-down`) — **full texts in the harness pack §B**, install into the port's skills dir (P3; if the port lacks skills support, inline per pack §E). Commit everything to the repo — clone = configured.

## 6. Smoke test the loop (half a day, one champion)

Run one **real but small** story end to end: `corp-spec` interview → analyst approves the rendered spec (Phase 1 review surface = the forge's markdown rendering in the PR; a wiki-mirror script is a Phase-2 nicety, not a blocker) → `corp-plan` + `corp-implement` → PR with spec+code together → merge → **`corp-archive` on main** (folds delta into living spec, drafts the ADR, regenerates the index) → store catalog picks it up on next aggregation. Every friction point found here is a bug in the harness, not in the people — fix the command/skill/script, commit, retry.

## 7. Baseline metrics (before Phase 1)

TESTED (pure git, run per repo; note: merge-commit based — squash-merge repos should count PR-merge subjects via `git log --grep` instead):
```bash
# merges in the trailing 90 days (deploy-frequency proxy until CI data is wired)
git log --merges --since="90 days ago" --format=%cI | wc -l
# median hours from branch's first commit to merge (lead-time proxy)
git log --merges --since="90 days ago" --format="%H" | while read -r m; do
  s=$(git log --format=%ct "$m"^1.."$m"^2 2>/dev/null | tail -1); e=$(git show -s --format=%ct "$m")
  [ -n "$s" ] && echo $(( (e - s) / 3600 ))
done | sort -n | awk '{a[NR]=$1} END{if(NR)print a[int((NR+1)/2)]" h median"}'
```
TEMPLATE: change-failure-rate + MTTR from your incident tracker; deploy frequency from CI (its job API on the deploy job); rework rate = % PRs tagged fix/revert; anti-gaming spec-order check per archived change (`git log --diff-filter=A --format=%ct -- openspec/changes/<id>/proposal.md | tail -1` must predate the first implementation commit on that branch — spec written after code = flow theater, count it as non-adoption).
**The DevEx pulse — use these five, verbatim, quarterly, anonymous, team-level (1–5 scale + one free-text):** (1) "How satisfied are you with your day-to-day development workflow?" (2) "How often can you work on a task without losing flow to friction or waiting?" (3) "How would you rate the quality of code review you receive?" (4) "How much does the SDD flow help vs hinder your work?" (5) "Would you recommend the flow to a colleague team?" + "What one thing should we fix?"
Record everything in a `baselines/` note in the store.

## 8. Phase 0 exit checklist

- [ ] Store live: `sync-repos` + `aggregate-index --strict` green in CI nightly
- [ ] 2–3 pilot repos: disposer green in pre-commit AND CI; index + `repo.txt` committed
- [ ] Commands + skills vendored; JVM LSP MCP wired; champion completed §6 on a real story
- [ ] Baselines recorded; exception path documented ("any story may skip the flow — note why in the tracker")
- [ ] Named champions; **named harness owner** (DevOps — owns pins, catalog job, port re-probes); weekly office-hour slot booked
- [ ] Adoption counter works: `ls openspec/changes/archive 2>/dev/null | wc -l` per repo vs feature-merge count (the Phase-1 weekly number)

Then run Phase 1 exactly per design §11 (opt-in, demo day, 4-week gates). The single go/no-go metric to watch weekly: **do the indexes stay green without human effort?**

## 9. Operating rules (print these)

1. Prompts advise, the disposer and CI enforce. Never fix a red check by weakening it.
2. Caps reject, never trim. The agent regenerates; humans never hand-repair generated files.
3. Central catalog is a routing hint. The repo index outranks it; the repo outranks its index.
4. Specs are durable, plans are disposable. Regenerate design/tasks whenever in doubt.
5. Every discovered spec/code mismatch becomes a delta — that's the spec base growing, not failure.
6. Same error three times → stop and ask a human.

## 10. Script reference (tested sources, post-review)

### tools/corp-lint.mjs (spoke repos)
```javascript
#!/usr/bin/env node
// corp-lint.mjs — deterministic disposer for agent-written docs. Zero dependencies.
// Scope: openspec/, docs/, .agent/ only (never lints build output or source code docs).
// Checks: hard file caps, index<->spec bijection + index schema, relative links + anchors,
// embedded snippets vs source, tasks.md state header, delta-spec sections.
// Every ERROR carries a remediation hint. Exit 1 on any ERROR; WARNs never block.
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname, resolve, relative, sep } from 'node:path';

const ROOT = resolve(process.argv[2] ?? '.');
const SCOPES = ['openspec', 'docs', '.agent'].map(d => join(ROOT, d)).filter(existsSync);

// ---- hardcoded caps (lines). The write-boundary contract: exceed => rejected, never trimmed.
const CAPS = [
  [/(^|\/)openspec\/index\.md$/, 300],
  [/(^|\/)openspec\/specs\/.+\/spec\.md$/, 400],
  [/(^|\/)openspec\/changes\/.+\/tasks\.md$/, 200],
  [/(^|\/)openspec\/changes\/.+\/research\.md$/, 400],
  [/(^|\/)openspec\/changes\/.+\/proposal\.md$/, 200],
  [/(^|\/)\.agent\/skills\/.+\.md$/, 250],
];

const errors = [], warns = [];
const err = (f, m, hint) => errors.push(`  ✗ ${f}: ${m}\n     ↳ ${hint}`);
const warn = (f, m, hint) => warns.push(`  • ${f}: ${m}\n     ↳ ${hint}`);

function* walk(dir) {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    if (e.name === '.git' || e.name === 'node_modules') continue;
    const p = join(dir, e.name);
    if (e.isDirectory()) yield* walk(p);
    else yield p;
  }
}
const rel = p => relative(ROOT, p).split(sep).join('/');
const mdFiles = SCOPES.flatMap(s => [...walk(s)]).filter(p => p.endsWith('.md'));

// GitHub-style anchor slug (basic: covers latin headings; extend for cyrillic if needed)
const slug = h => h.toLowerCase().trim().replace(/[^\w\s-]/g, '').replace(/\s+/g, '-');
const headingSlugs = txt => new Set(
  [...txt.matchAll(/^#{1,6}\s+(.+?)\s*$/gm)].map(m => slug(m[1]))
);
// strip fenced code (``` and ~~~), inline code, and HTML comments before link checks
const stripCode = txt => txt
  .replace(/```[\s\S]*?```/g, '').replace(/~~~[\s\S]*?~~~/g, '')
  .replace(/`[^`\n]*`/g, '').replace(/<!--[\s\S]*?-->/g, '');
// per-line fence tracking for the embed scanner
const fenceMask = lines => {
  const mask = []; let open = null;
  for (const l of lines) {
    const f = l.match(/^(```|~~~)/)?.[1];
    if (f && !open) { open = f; mask.push(true); continue; }
    if (f && open === f) { open = null; mask.push(true); continue; }
    mask.push(!!open);
  }
  return mask;
};

// ---- 1. caps
for (const p of mdFiles) {
  const r = rel(p);
  for (const [re, cap] of CAPS) {
    if (re.test(r)) {
      const lines = readFileSync(p, 'utf8').split('\n').length;
      if (lines > cap) err(r, `${lines} lines (hard cap ${cap})`,
        `split content into references/ subfiles or tighten; caps are rejected-not-trimmed by design`);
    }
  }
}

// ---- 2. index.json schema + bijection with openspec/specs/ (a capability = a dir WITH spec.md)
const idxPath = join(ROOT, 'openspec', 'index.json');
const specsDir = join(ROOT, 'openspec', 'specs');
let capDirs = [];
if (existsSync(specsDir)) {
  for (const d of readdirSync(specsDir, { withFileTypes: true }).filter(d => d.isDirectory())) {
    if (existsSync(join(specsDir, d.name, 'spec.md'))) capDirs.push(d.name);
    else err(`openspec/specs/${d.name}/`, 'capability dir has no spec.md',
      'add spec.md (a capability IS its spec) or delete the dir');
  }
}
if (existsSync(idxPath)) {
  let idx;
  try { idx = JSON.parse(readFileSync(idxPath, 'utf8')); }
  catch (e) { err('openspec/index.json', `invalid JSON: ${e.message}`, 'regenerate: node tools/gen-index.mjs'); }
  if (idx) {
    const allowed = new Set(['schema_version', 'repo', 'source_digest', 'capabilities', 'modules']);
    for (const k of Object.keys(idx)) if (!allowed.has(k))
      err('openspec/index.json', `unknown key "${k}"`, 'schema forbids extra keys (pollution gate); regenerate');
    for (const k of ['schema_version', 'repo', 'source_digest', 'capabilities']) if (!(k in idx))
      err('openspec/index.json', `missing required key "${k}"`, 'regenerate: node tools/gen-index.mjs');
    if (typeof idx.repo === 'string' && idx.repo.length > 80)
      err('openspec/index.json', 'repo name >80 chars', 'shorten openspec/repo.txt');
    const ids = new Set();
    for (const c of idx.capabilities ?? []) {
      for (const k of ['id', 'title', 'path', 'summary']) if (!(k in c))
        err('openspec/index.json', `capability missing "${k}"`, 'regenerate');
      if (c.id && !/^[a-z0-9]+(-[a-z0-9]+)*$/.test(c.id))
        err('openspec/index.json', `capability id "${c.id}" not kebab-case`, 'rename the spec dir to kebab-case');
      if (c.summary && c.summary.length > 200)
        err('openspec/index.json', `summary for "${c.id}" >200 chars`, 'first paragraph of the spec is the summary; shorten it');
      ids.add(c.id);
    }
    for (const d of capDirs) if (!ids.has(d))
      err('openspec/index.json', `spec dir "${d}" missing from index`, 'regenerate: node tools/gen-index.mjs && git add openspec/index.*');
    for (const id of ids) if (!capDirs.includes(id))
      err('openspec/index.json', `index lists "${id}" but openspec/specs/${id}/spec.md does not exist`, 'regenerate the index');
  }
} else if (capDirs.length) {
  err('openspec/index.json', 'missing but specs exist', 'generate: node tools/gen-index.mjs');
}

// ---- 3. relative links + anchors (skip external, skip code/comments)
for (const p of mdFiles) {
  const r = rel(p);
  const txt = stripCode(readFileSync(p, 'utf8'));
  for (const m of txt.matchAll(/\[[^\]]*\]\(([^)\s]+)\)/g)) {
    const target = m[1];
    if (/^(https?:|mailto:|#)/.test(target)) continue;
    const [fp, anchor] = target.split('#');
    const abs = resolve(dirname(p), fp);
    if (!existsSync(abs)) {
      err(r, `broken link → ${target}`, 'fix the path or create the target');
      continue;
    }
    if (anchor && abs.endsWith('.md')) {
      const slugs = headingSlugs(readFileSync(abs, 'utf8'));
      if (!slugs.has(anchor)) err(r, `broken anchor → ${target}`, `no heading "#${anchor}" in ${rel(abs)}`);
    }
  }
}

// ---- 4. embedded snippets: <!-- embed: path#L3-L5 --> followed by a fence whose body must equal those lines
for (const p of mdFiles) {
  const r = rel(p);
  const lines = readFileSync(p, 'utf8').split('\n');
  const inFence = fenceMask(lines);
  for (let i = 0; i < lines.length; i++) {
    if (inFence[i]) continue; // fenced examples are not directives
    const line = lines[i].trimEnd(); // trailing whitespace must not disable the check
    const m = line.match(/^<!--\s*embed:\s*(\S+?)#L(\d+)-L(\d+)\s*-->$/);
    if (!m) {
      if (/<!--.*embed:/.test(line)) warn(r, `line ${i + 1} looks like an embed directive but does not parse`,
        'expected exactly: <!-- embed: relative/path#Lstart-Lend -->');
      continue;
    }
    const [, src, a, b] = m;
    const srcAbs = resolve(dirname(p), src);
    if (!existsSync(srcAbs)) { err(r, `embed source missing: ${src}`, 'fix the path'); continue; }
    let j = i + 1;
    while (j < lines.length && lines[j].trim() === '') j++;
    if (!lines[j]?.startsWith('```')) { err(r, `embed directive at line ${i + 1} not followed by a code fence`, 'add ``` fence right after the directive'); continue; }
    const fenceStart = j + 1;
    let k = fenceStart;
    while (k < lines.length && !lines[k].startsWith('```')) k++;
    const body = lines.slice(fenceStart, k).join('\n');
    const want = readFileSync(srcAbs, 'utf8').split('\n').slice(a - 1, +b).join('\n');
    if (body !== want) err(r, `embed drift at line ${i + 1} (${src}#L${a}-L${b})`,
      'source changed — re-copy the lines (or update the range); specs must embed live truth');
  }
}

// ---- 5. tasks.md state header + checkbox shape (nesting allowed)
for (const p of mdFiles.filter(p => /(^|\/)openspec\/changes\/[^/]+\/tasks\.md$/.test(rel(p)))) {
  const r = rel(p);
  const head = readFileSync(p, 'utf8').split('\n').slice(0, 5).join('\n');
  if (!/^As of \d{4}-\d{2}-\d{2} — .+/m.test(head))
    err(r, 'missing state header in first 5 lines', 'add a line: "As of YYYY-MM-DD — stage N, next: <action>" (overwrite it each session)');
  const bad = readFileSync(p, 'utf8').split('\n')
    .map((l, i) => [l, i + 1]).filter(([l]) => /^\s*-\s*\[/.test(l) && !/^\s*- \[( |x)\] \S/.test(l));
  for (const [, n] of bad) err(r, `malformed checkbox at line ${n}`, 'use "- [ ] task" or "- [x] task" (indentation for sub-tasks is fine)');
}

// ---- 6. delta specs must use delta sections
for (const p of mdFiles.filter(p => /(^|\/)openspec\/changes\/[^/]+\/specs\/.+\.md$/.test(rel(p)))) {
  const r = rel(p);
  const txt = readFileSync(p, 'utf8');
  if (!/^## (ADDED|MODIFIED|REMOVED) Requirements$/m.test(txt))
    err(r, 'no ADDED/MODIFIED/REMOVED section', 'delta specs describe changes, not full state — use the delta sections');
}

// ---- report
if (warns.length) console.log(`warnings (${warns.length}):\n${warns.join('\n')}\n`);
if (errors.length) {
  console.log(`errors (${errors.length}):\n${errors.join('\n')}\n\n✗ corp-lint failed`);
  process.exit(1);
}
console.log('✓ corp-lint passed');
```

### tools/gen-index.mjs (spoke repos)
```javascript
#!/usr/bin/env node
// gen-index.mjs — generates openspec/index.json + index.md from openspec/specs/ (+ optional build/modules.txt).
// Deterministic across machines: byte-wise sort (no locale), digest built from sorted content,
// repo name from committed openspec/repo.txt (never from the checkout folder name).
// --check: regenerate in memory and diff against committed files; exit 1 on drift.
import { readFileSync, readdirSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { join, resolve, basename } from 'node:path';
import { createHash } from 'node:crypto';

const CHECK = process.argv.includes('--check');
const ROOT = resolve(process.argv.filter(a => !a.startsWith('--'))[2] ?? '.');
const osDir = join(ROOT, 'openspec');
const specsDir = join(osDir, 'specs');
const repoTxt = join(osDir, 'repo.txt');

// repo identity is committed data, not the folder name (CI workspaces, worktrees, renamed clones)
const repoName = existsSync(repoTxt) ? readFileSync(repoTxt, 'utf8').trim() : basename(ROOT);

const byId = (a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0); // byte-wise, locale-independent
const caps = [];
const texts = {};
if (existsSync(specsDir)) {
  for (const d of readdirSync(specsDir, { withFileTypes: true }).filter(e => e.isDirectory())) {
    const specPath = join(specsDir, d.name, 'spec.md');
    if (!existsSync(specPath)) continue; // dirs without spec.md are corp-lint's problem, not the index's
    const txt = readFileSync(specPath, 'utf8');
    texts[d.name] = txt;
    const title = txt.match(/^#\s+(.+)$/m)?.[1]?.trim() ?? d.name;
    const summary = (txt.split('\n').find(l => l.trim() && !l.startsWith('#')) ?? '').trim().slice(0, 200);
    caps.push({ id: d.name, title, path: `openspec/specs/${d.name}/spec.md`, summary });
  }
}
caps.sort(byId);

let modules = [];
const modFile = join(ROOT, 'build', 'modules.txt'); // produced by the build: mvn/gradle module list
if (existsSync(modFile)) {
  modules = readFileSync(modFile, 'utf8').split('\n').map(s => s.trim()).filter(Boolean).sort(); // default sort = code-unit order
}

// digest over SORTED content so filesystem readdir order can never change it
const digestInput = [repoName, ...caps.map(c => c.id + '\x00' + texts[c.id]), ...modules];
const index = {
  schema_version: 1,
  repo: repoName,
  source_digest: createHash('sha256').update(digestInput.join('\x01')).digest('hex').slice(0, 16),
  capabilities: caps,
  ...(modules.length ? { modules } : {}),
};
const json = JSON.stringify(index, null, 2) + '\n';

const md = [
  `# ${index.repo} — capability index`,
  '',
  `> GENERATED by tools/gen-index.mjs — do not edit. digest: ${index.source_digest}`,
  '',
  ...caps.map(c => `- [${c.title}](${c.path.replace(/^openspec\//, '')}) — ${c.summary}`),
  ...(modules.length ? ['', '## Modules', '', ...modules.map(m => `- ${m}`)] : []),
  '',
].join('\n');

const jsonPath = join(osDir, 'index.json');
const mdPath = join(osDir, 'index.md');

if (CHECK) {
  const cur = f => (existsSync(f) ? readFileSync(f, 'utf8') : '');
  if (cur(jsonPath) !== json || cur(mdPath) !== md) {
    console.error('✗ index drift: openspec/index.* does not match current specs');
    console.error('  ↳ run: node tools/gen-index.mjs && git add openspec/index.json openspec/index.md openspec/repo.txt');
    process.exit(1);
  }
  console.log('✓ index up to date');
} else {
  mkdirSync(osDir, { recursive: true });
  if (!existsSync(repoTxt)) writeFileSync(repoTxt, repoName + '\n'); // pin identity on first run — commit it
  writeFileSync(jsonPath, json);
  writeFileSync(mdPath, md);
  console.log(`✓ wrote openspec/index.json + index.md (${caps.length} capabilities, digest ${index.source_digest})`);
}
```

### tools/verify-docs.sh (spoke repos)
```bash
#!/usr/bin/env bash
# verify-docs.sh — the disposer entry point. One code path, four triggers:
# agent post-write self-check / lefthook pre-commit / on demand / CI backstop.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
node tools/gen-index.mjs --check || fail=1
node tools/corp-lint.mjs || fail=1
node tools/check-contract-split-brain.mjs || fail=1   # no-op in repos with no references:
if [ "$fail" -ne 0 ]; then
  echo "✗ verify-docs failed — fix the errors above (each carries a remediation hint), then retry"
  exit 1
fi
echo "✓ verify-docs passed"
```

### tools/aggregate-index.mjs (system store)
```javascript
#!/usr/bin/env node
// aggregate-index.mjs — builds the store's thin catalog from spoke repos' generated indexes.
// Central = routing hint only. Invalid/missing spoke index => RED entry + last-good data kept (stale:true).
// repos.json names are input-gated (unique, safe charset). --strict (CI mode): exit 1 if any repo is red.
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { execSync } from 'node:child_process';

const STRICT = process.argv.includes('--strict');
const ROOT = resolve(process.argv.filter(a => !a.startsWith('--'))[2] ?? '.');
const cfg = JSON.parse(readFileSync(join(ROOT, 'repos.json'), 'utf8'));
// repos.json: { "clones_dir": "..", "repos": [ { "name": "...", "url": "..." } ] }
const clonesDir = resolve(ROOT, cfg.clones_dir);

// input gate: names become filesystem paths and shell words — constrain at the boundary
const seen = new Set();
for (const r of cfg.repos) {
  if (!/^[a-z0-9][a-z0-9._-]*$/.test(r.name)) { console.error(`✗ repos.json: invalid repo name "${r.name}" (allowed: [a-z0-9._-], no leading dot/dash)`); process.exit(2); }
  if (seen.has(r.name)) { console.error(`✗ repos.json: duplicate repo name "${r.name}"`); process.exit(2); }
  seen.add(r.name);
}

// keep-last-good: carry a red repo's previous entry, marked stale, instead of dropping it
const prevPath = join(ROOT, 'catalog.json');
const prev = existsSync(prevPath) ? JSON.parse(readFileSync(prevPath, 'utf8')) : { entries: [] };
const prevByName = new Map((prev.entries ?? []).map(e => [e.name, e]));

const entries = [], red = [];
const byName = (a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0); // byte-wise, locale-independent
for (const r of [...cfg.repos].sort(byName)) {
  const repoDir = join(clonesDir, r.name);
  const idxPath = join(repoDir, 'openspec', 'index.json');
  try {
    if (!existsSync(repoDir)) throw new Error('clone missing — run tools/sync-repos.sh');
    if (!existsSync(idxPath)) throw new Error('openspec/index.json missing — repo not onboarded or index not generated');
    const idx = JSON.parse(readFileSync(idxPath, 'utf8'));
    if (!Array.isArray(idx.capabilities)) throw new Error('index.json has no capabilities[] — regenerate in the repo');
    const head = execSync('git rev-parse --short HEAD', { cwd: repoDir }).toString().trim();
    entries.push({ name: r.name, url: r.url, head, digest: idx.source_digest, capabilities: idx.capabilities.map(c => ({ id: c.id, title: c.title, summary: c.summary })) });
  } catch (e) {
    red.push({ name: r.name, reason: e.message });
    const lastGood = prevByName.get(r.name);
    if (lastGood) entries.push({ ...lastGood, stale: true, stale_reason: e.message });
  }
}
entries.sort(byName);

const catalog = { schema_version: 1, entries, red };
writeFileSync(join(ROOT, 'catalog.json'), JSON.stringify(catalog, null, 2) + '\n');

const md = [
  '# System catalog',
  '',
  '> GENERATED by tools/aggregate-index.mjs — routing hints only. The repo index is the authority; the repo itself outranks its index.',
  '',
  ...(red.length ? ['## 🔴 RED — fix before trusting the catalog', '', ...red.map(x => `- **${x.name}**: ${x.reason}`), ''] : []),
  ...entries.flatMap(e => [
    `## ${e.name}${e.stale ? ' ⚠ STALE (last-good data; see RED above)' : ''}`,
    '',
    `repo: ${e.url} · HEAD \`${e.head}\` · digest \`${e.digest}\``,
    '',
    ...e.capabilities.map(c => `- **${c.id}** — ${c.summary}`),
    '',
  ]),
].join('\n');
writeFileSync(join(ROOT, 'catalog.md'), md);

console.log(`✓ catalog: ${entries.length} entries (${entries.filter(e => e.stale).length} stale), ${red.length} red`);
if (red.length) {
  for (const x of red) console.error(`  🔴 ${x.name}: ${x.reason}`);
  if (STRICT) process.exit(1);
}
```

### tools/sync-repos.sh (system store)
```bash
#!/usr/bin/env bash
# sync-repos.sh — materialize, ADOPT and refresh local clones of every repo in repos.json.
#
#   bash tools/sync-repos.sh              # clone what is missing, adopt what is there, pull
#   bash tools/sync-repos.sh --prune      # also delete stray clones that hold no local work
#   bash tools/sync-repos.sh --prune --dry-run   # say what --prune would delete, delete nothing
#
# Safe by construction: ff-only pulls, never touches local work, and a clone that already
# exists is ADOPTED (checked, then pulled) — never re-cloned and never overwritten. A repo
# whose origin points somewhere else, or a directory that is not a clone at all, is reported
# with the exact one-line fix instead of being silently pulled from the wrong place.
# --prune refuses to delete anything holding uncommitted, unpushed or stashed work.
set -uo pipefail
cd "$(dirname "$0")/.."

PRUNE=0; DRYRUN=0
for a in "$@"; do
  case "$a" in
    --prune)   PRUNE=1 ;;
    --dry-run) DRYRUN=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "✗ unknown flag: $a (use --prune, --dry-run)"; exit 2 ;;
  esac
done

CLONES_DIR=$(node -e "console.log(require('./repos.json').clones_dir)")
mkdir -p "$CLONES_DIR"
fail=0
warn=0

# Compare remotes by MEANING, not by string: ssh://…/x.git, …/x.git/ and …/x are one repo.
norm() { printf '%s' "${1%/}" | sed -e 's#/*$##' -e 's#\.git$##'; }

repolist=$(node -e "const c=require('./repos.json');const seen=new Set();for(const r of c.repos){if(!/^[a-z0-9][a-z0-9._-]*\$/.test(r.name)||seen.has(r.name)){console.error('invalid/duplicate repo name: '+r.name);process.exit(2)}seen.add(r.name);console.log(r.name+' '+r.url)}") || { echo "✗ repos.json failed validation"; exit 2; }

configured=""
while read -r name url; do
  [ -z "$name" ] && continue
  configured="$configured $name"
  dir="$CLONES_DIR/$name"

  # --- a directory that is not a clone: never clone INTO it, never delete it -------------
  if [ -e "$dir" ] && [ ! -d "$dir/.git" ]; then
    echo "🔴 $name: $dir exists but is not a git clone"
    echo "     fix: mv \"$dir\" \"$dir.not-a-clone\"   # then re-run; nothing here is deleted for you"
    fail=1; continue
  fi

  # --- missing: clone --------------------------------------------------------------------
  if [ ! -d "$dir/.git" ]; then
    echo "cloning $name..."
    git clone --quiet "$url" "$dir" || { echo "🔴 $name: clone failed"; fail=1; continue; }
    echo "✓ $name (cloned)"
    continue
  fi

  # --- present: ADOPT it — prove it is the right repo before pulling anything -------------
  have=$(git -C "$dir" remote get-url origin 2>/dev/null || true)
  if [ -z "$have" ]; then
    echo "🔴 $name: existing clone has no 'origin' remote"
    echo "     fix: git -C \"$dir\" remote add origin \"$url\""
    fail=1; continue
  fi
  if [ "$(norm "$have")" != "$(norm "$url")" ]; then
    echo "🔴 $name: existing clone points at a DIFFERENT repo — not pulling"
    echo "     on disk:   $have"
    echo "     repos.json: $url"
    echo "     fix: git -C \"$dir\" remote set-url origin \"$url\"   (or correct repos.json)"
    fail=1; continue
  fi

  git -C "$dir" fetch --quiet origin || { echo "🔴 $name: fetch failed"; fail=1; continue; }

  branch=$(git -C "$dir" symbolic-ref --quiet --short HEAD || true)
  if [ -z "$branch" ]; then
    echo "⚠ $name: detached HEAD — adopted, but not pulled (drill-down may read stale files)"
    echo "     fix: git -C \"$dir\" checkout <branch>"
    warn=1; continue
  fi
  if ! git -C "$dir" diff --quiet || ! git -C "$dir" diff --cached --quiet; then
    echo "⚠ $name: local changes on $branch — adopted, not pulled (drill-down may read stale files)"
    warn=1; continue
  fi
  if ! git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    echo "⚠ $name: $branch has no upstream — adopted, not pulled"
    echo "     fix: git -C \"$dir\" branch --set-upstream-to=origin/$branch $branch"
    warn=1; continue
  fi
  before=$(git -C "$dir" rev-parse HEAD)
  if ! git -C "$dir" pull --quiet --ff-only; then
    echo "⚠ $name: cannot fast-forward $branch (diverged) — resolve manually"
    warn=1; continue
  fi
  after=$(git -C "$dir" rev-parse HEAD)
  if [ "$before" = "$after" ]; then echo "✓ $name (adopted, up to date)"
  else echo "↑ $name (adopted, fast-forwarded $(git -C "$dir" rev-list --count "$before..$after") commit(s))"; fi
done <<< "$repolist"

# --- strays: clones nobody listed. They are what a half-finished setup leaves behind, and
# they are read by nothing — but they are also where someone's only copy of a branch can be
# hiding, so they are never removed without proof that they hold no work. ------------------
strays=""
for d in "$CLONES_DIR"/*; do
  [ -d "$d" ] || continue
  n=$(basename "$d")
  case " $configured " in *" $n "*) continue ;; esac
  strays="$strays $n"
done

if [ -n "$strays" ]; then
  for n in $strays; do
    d="$CLONES_DIR/$n"
    reason=""
    if [ ! -d "$d/.git" ]; then reason="not a git clone"
    elif [ -n "$(git -C "$d" status --porcelain 2>/dev/null)" ]; then reason="uncommitted changes"
    elif [ -n "$(git -C "$d" log --branches --not --remotes --oneline 2>/dev/null | head -1)" ]; then reason="commits that exist nowhere else"
    elif [ -n "$(git -C "$d" stash list 2>/dev/null)" ]; then reason="stashed work"
    fi
    if [ "$PRUNE" -eq 0 ]; then
      echo "⚠ stray clone: $n — not in repos.json${reason:+ (holds $reason)}"
      warn=1
    elif [ -n "$reason" ]; then
      echo "⚠ stray clone: $n — REFUSING to delete: $reason"
      echo "     look at it first: git -C \"$d\" status && git -C \"$d\" log --branches --not --remotes --oneline"
      warn=1
    elif [ "$DRYRUN" -eq 1 ]; then
      echo "would delete stray clone: $d (no local work)"
    else
      rm -rf "$d" && echo "deleted stray clone: $d (no local work)"
    fi
  done
  [ "$PRUNE" -eq 0 ] && echo "   (run: bash tools/sync-repos.sh --prune --dry-run  to see what --prune would remove)"
fi

if [ "$fail" -ne 0 ]; then
  echo "✗ sync finished with failures (see 🔴 above)"
  exit 1
fi
if [ "$warn" -ne 0 ]; then
  echo "✓ sync done → $CLONES_DIR (with warnings — see ⚠ above)"
  exit 0
fi
echo "✓ sync done → $CLONES_DIR"
```

### Scripts added 2026-08-04/05 (sources live in their own runbooks)

Four more zero-dependency scripts ship in the starter kit's `scripts/tools/`. Their full sources and
test matrices are in the runbooks rather than repeated here, so there is one copy to keep correct:

| Script | Purpose | Source + evidence |
|---|---|---|
| `check-openspec-root.sh` | refuse to run when the resolved OpenSpec root is not this repo | [openspec-root-resolution-fix](2026-08-04-openspec-root-resolution-fix.md) §2, T9–T10 |
| `check-contract-split-brain.mjs` | fail the build when a spoke restates a store contract fact | [openspec-root-resolution-fix](2026-08-04-openspec-root-resolution-fix.md) §3b, T15–T19 |
| `check-git-naming.sh` | enforce `feature/ABCD-1234` and `feat(ABCD-1234): text` | [setup task](2026-08-04-corp-sdd-setup-task-for-agent.md) §6–§7 |
| `index-all.sh` | rebuild the Zoekt index over the store's existing clones | [zoekt setup](2026-08-04-corp-sdd-zoekt-setup.md) §3 |

`verify-docs.sh` above already calls the split-brain lint. `check-git-naming.sh` is wired through
`lefthook.yml` (`commit-msg` + `pre-push`), not through `verify-docs.sh`.

## 11. Test evidence (2026-07-18, Node v22, synthetic pilot repo + store)

Round 1 = author's matrix. Round 2 = independent adversarial reviewer re-executing the guide from scratch (11 findings: 1 blocker, 4 serious, 6 minor — all fixed below and re-proven).

| # | Scenario | Result |
|---|---|---|
| T0 | Healthy repo: specs + change folder + embed + cross-links | ✓ all green |
| T1 | Spec dir added without regenerating index | ✗ caught by `gen-index --check` |
| T2 | Broken relative link + broken heading anchor | ✗ both caught with target file named |
| T3 | Embed source changed under the spec | ✗ embed drift caught with exact range |
| T4 | Spec file at 410 lines (cap 400) | ✗ hard-cap rejection |
| T5 | tasks.md without state header + `- []` checkbox | ✗ both caught |
| T6 | Delta spec restating full state (no delta sections) | ✗ caught |
| T7 | Store: good repo + missing repo | ✓ catalog built; RED loud; `--strict` exit 1 |
| T8 | sync-repos: fresh clone, idempotent re-run, aggregate from clone | ✓ green |
| T9 | sync-repos: unreachable origin | ✗ exit 1 (pipe-subshell bug found in round 1, fixed) |
| T10 | **Clone under a different folder name (CI workspace)** | ✓ green — reviewer's blocker, fixed via committed `openspec/repo.txt` |
| T11 | gen-index/check under LC_ALL=C, en_US.UTF-8, C.UTF-8, POSIX | ✓ stable — locale-dependent `localeCompare` replaced with byte-wise sort |
| T12 | Capability dir without spec.md | ✗ distinct error (was an unfixable regenerate-loop — reviewer finding) |
| T13 | Embed directive with trailing whitespace + source drift | ✗ still caught (was failing open — reviewer finding) |
| T14 | Broken link in `target/site/*.md` build output | ignored — lint scoped to openspec/, docs/, .agent/ |
| T15 | Nested sub-checkbox in tasks.md | ✓ allowed |
| T16 | Embed directive inside a code fence (example) + malformed directive | example ignored; malformed → WARN, not silent |
| T17 | repos.json with duplicate / path-traversal repo names | ✗ exit 2, loud (input gate) |
| T18 | Repo turns red after being green | last-good entry kept, marked ⚠ STALE (never silently dropped) |

Bugs found by testing before handover: wrong relative links in generated index.md (round 1); folder-name-dependent index, locale-dependent sort, bijection regenerate-loop, fail-open embed check, build-output linting, checkbox nesting, ENOENT on missing openspec/, unvalidated repos.json, sync exit-code swallowing (round 2). **This is the disposer philosophy applied to the disposer itself.**

**Known limitations (deliberate v0):** anchor slugs cover latin headings (extend `slug()` for cyrillic if specs go bilingual); the split-brain restate check and `sources:` freshness are future lint promotions; the 3-strikes circuit breaker is prompt-level (§3), not tool-enforced; index.md >300-line pagination story deferred until a repo actually hits it; commands/skills bodies and lefthook/CI-pipeline snippets are TEMPLATE until smoke-tested on the corporate port and CI; **all T-cases ran against filesystem + git only — nothing here has yet executed inside the port itself** (that's §0a + §6's job in the corp environment).
