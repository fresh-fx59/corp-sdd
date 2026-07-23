# Corporate SDD — Step-by-Step Implementation Guide

**Companion to:** [2026-07-17-corp-sdd-transition-design.md](../specs/2026-07-17-corp-sdd-transition-design.md) (APPROVED) · **Date:** 2026-07-18
**Hand-off:** implementing agent starts with [2026-07-18-corp-sdd-handoff-to-coder-agent.md](2026-07-18-corp-sdd-handoff-to-coder-agent.md). **Team-facing manual:** [2026-07-18-corp-sdd-team-playbook.md](2026-07-18-corp-sdd-team-playbook.md) — hand each role its section during Phase-1 onboarding.

> **⚠ THE HARNESS IS A PORT.** The org runs a **corporate port of the agent CLI, not upstream**. Every harness-level mechanic in this guide that came from the upstream agent-CLI docs — the `.agent/` config directory, custom-command location/format, Agent-Skills support, MCP wiring, headless flags, context-file name — is a **default assumption to VERIFY against the port** (§0a), never a fact. The five §10 scripts are harness-agnostic (pure Node/bash over files) and unaffected, except two strings in `corp-lint.mjs` that name the config dir: the `SCOPES` entry `.agent` and the `CAPS` regex `\.agent\/skills\/` — rename both to the port's config dir if it differs (these two strings are the only sanctioned script edits).

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
- [ ] **OpenSpec mirrored on the internal npm registry** (restricted network — `npx openspec` must resolve internally) and version-pinned.
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
bash tools/sync-repos.sh              # materialize local clones (exit 1 on any failure)
node tools/aggregate-index.mjs       # builds catalog.json + catalog.md (RED entries are loud)
git add -A && git commit -m "system store: skeleton + first catalog"
```

Repo names in `repos.json` are input-gated (`[a-z0-9._-]`, unique) — both tools refuse invalid config with exit 2. Also seed: `helicopter.md` (one page: systems, integration edges), `conventions/` (org rules the commands reference), `contracts/` (empty until the first cross-repo change). Build the ownership registry when the first collision appears — not before.

## 2. Onboard each pilot repo (~1 hour each)

```bash
cd pilot-repo-a
npx openspec init --tools <your-agent>  # pin the version; verify output lands per P8 —
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

**`<port-command-dir>/corp-spec.md`**
```markdown
---
description: Draft a delta spec from a tracker story via interview (analyst flow)
---
You are drafting a delta spec for story {{args}}.
1. Fetch the story and linked wiki pages via the tracker/wiki MCP tools.
2. Read openspec/index.md, then ONLY the living specs the story touches; follow skill
   corp-drill-down (central catalog → repo index → live files; repo wins; ≤3 hops).
3. Verify every contract fact against live code (embed with <!-- embed --> directives).
4. Interview the analyst — ONE question at a time, multiple-choice preferred — until
   requirements and Given/When/Then scenarios are unambiguous.
5. Create the OpenSpec change (proposal + delta spec) via the opsx workflow.
   Append every verified fact as a pointer line to research.md (path#Lx-Ly + finding).
6. Run: bash tools/verify-docs.sh — fix until green.
7. HANDOVER (do this yourself — the analyst never touches git): create/switch to the
   change branch, commit the change folder, push, and open (or update) the spec PR.
   Post the spec summary + PR link back to the tracker story. Do NOT create design.md
   or tasks.md (plan happens at pull time).
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
# sync-repos.sh — materialize/refresh local clones of every repo in repos.json.
# Safe: ff-only pulls, never touches local work; reports repos that are behind/dirty.
set -uo pipefail
cd "$(dirname "$0")/.."
CLONES_DIR=$(node -e "console.log(require('./repos.json').clones_dir)")
mkdir -p "$CLONES_DIR"
fail=0
repolist=$(node -e "const c=require('./repos.json');const seen=new Set();for(const r of c.repos){if(!/^[a-z0-9][a-z0-9._-]*\$/.test(r.name)||seen.has(r.name)){console.error('invalid/duplicate repo name: '+r.name);process.exit(2)}seen.add(r.name);console.log(r.name+' '+r.url)}") || { echo "✗ repos.json failed validation"; exit 2; }
while read -r name url; do
  [ -z "$name" ] && continue
  dir="$CLONES_DIR/$name"
  if [ ! -d "$dir/.git" ]; then
    echo "cloning $name..."
    git clone --quiet "$url" "$dir" || { echo "🔴 $name: clone failed"; fail=1; continue; }
  else
    ( cd "$dir"
      git fetch --quiet origin || { echo "🔴 $name: fetch failed"; exit 1; }
      if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "⚠ $name: local changes — skipped pull (drill-down may read stale files here)"
      elif ! git pull --quiet --ff-only; then
        echo "⚠ $name: cannot fast-forward (diverged) — resolve manually"
      fi
    ) || fail=1
  fi
done <<< "$repolist"
if [ "$fail" -ne 0 ]; then
  echo "✗ sync finished with failures (see 🔴 above)"
  exit 1
fi
echo "✓ sync done → $CLONES_DIR"
```

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
