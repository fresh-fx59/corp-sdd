# Specs landing in the store instead of the code repo — root cause + fix

**Companion to:** [implementation guide](2026-07-18-corp-sdd-implementation-guide.md) §2 · **Date:** 2026-08-04
**Reported by the operator 2026-08-04:** "I tried the process and it creates spec inside master repo, not under the clone."

**Reproduced and fixed.** Verified against **OpenSpec 1.7.0** (`@fission-ai/openspec`) on a synthetic
store + clone estate. This breaks the design's core promise — *the spec lives where its implementing
PR lands* — so it is a blocker for Phase 0, not a nicety.

---

## 1. Root cause (verified, not inferred)

**OpenSpec resolves its root by walking UP from the current directory until it finds a directory
containing `openspec/`. The walk does NOT stop at a `.git` boundary.**

That second clause is the whole bug. A code repo is its own git repository, and OpenSpec walks
straight past it into the parent.

Two conditions produce the symptom; either one is enough:

1. **The code repo was never onboarded** — no `openspec/` of its own, so the walk continues upward.
2. **The clone sits inside the store's directory tree** — e.g. `system-store/clones/pilot-repo-a`.
   Then the nearest `openspec/` above it *is* the store's.

Proof (test C in §4): a freshly `git init`-ed repo at `system-store/clones/nested-repo`, with its
own `.git`, resolved to the store:

```
$ openspec context
Working context for system-store (…/estate/system-store)
OpenSpec root
  system-store  …/estate/system-store
```

**Ruled out by test:** store *registration* is not the cause. With `corp-store` registered,
a non-nested un-onboarded repo errors cleanly instead of silently using the store —
`Error: No OpenSpec root found in the current directory or its ancestors. Registered stores:
corp-store. Pass --store <id> …`. A registered store is only used with an explicit `--store <id>`.

## 2. The fix

**Nearest `openspec/` wins.** Onboarding the repo makes its own root take precedence — even while
nested inside the store (test D). So:

1. **Run guide §2 on every code repo before any spec work.** `npx @fission-ai/openspec init --tools <agent>` in
   the repo is not optional setup — it is what keeps specs out of the store. This is the step that
   was missed.
2. **Keep clones OUTSIDE the store's tree.** `repos.json` ships `"clones_dir": "../clones"` — a
   *sibling* of the store, deliberately. Never point it at a path inside the store, and never
   hand-clone into the store. This removes condition 2 entirely, so a missed onboarding fails loudly
   instead of silently writing to the store.
3. **Assert the root before writing.** One command answers "where will this spec land?":

   ```
   openspec context
   ```

   It prints the resolved root. If that is not the repo you are standing in, stop.

### The mechanical guard — `tools/check-openspec-root.sh`

Tested both ways (§4 T6–T8). Wire it into `corp-spec` / `corp-plan` as a precondition, and into
`verify-docs.sh` if you want it enforced at the write boundary.

```bash
#!/usr/bin/env bash
# check-openspec-root.sh — refuse to run the SDD flow against the wrong OpenSpec root.
#
# OpenSpec resolves its root by walking UP from the current directory looking for openspec/.
# The walk does NOT stop at a .git boundary (verified, OpenSpec 1.7.0). So a code repo that was
# never `openspec init`-ed — or that sits inside another OpenSpec root's directory tree —
# silently resolves to the PARENT root, and every spec the agent writes lands there.
#
# This asserts: the resolved OpenSpec root is THIS git repo's root. Run it before any spec work.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$repo_root" ]; then
  echo "✗ not inside a git repository" >&2
  exit 1
fi

if [ ! -d "$repo_root/openspec" ]; then
  echo "✗ no openspec/ in this repo ($repo_root)" >&2
  echo "  ↳ this repo was never onboarded; specs would be written to a parent root" >&2
  echo "  ↳ run: npx @fission-ai/openspec init --tools <your-agent> ." >&2
  exit 1
fi

# walk up from cwd exactly the way OpenSpec does, and report the FIRST openspec/ found
dir="$PWD"
resolved=""
while :; do
  if [ -d "$dir/openspec" ]; then resolved="$dir"; break; fi
  parent="$(dirname "$dir")"
  [ "$parent" = "$dir" ] && break
  dir="$parent"
done

if [ -z "$resolved" ]; then
  echo "✗ no OpenSpec root found from $PWD" >&2
  exit 1
fi

if [ "$resolved" != "$repo_root" ]; then
  echo "✗ WRONG OpenSpec root" >&2
  echo "    resolved: $resolved" >&2
  echo "    this repo: $repo_root" >&2
  echo "  ↳ specs would be written OUTSIDE this repo. Fix the nesting or onboard this repo." >&2
  exit 1
fi

echo "✓ OpenSpec root = $repo_root (this repo)"
```

## 3. Correction to the guide: the npm package name

**`npx openspec` is WRONG.** The npm name `openspec` is an unrelated placeholder package at version
**0.0.0** with no binary — `npx openspec init` cannot work. The real CLI is
**`@fission-ai/openspec`** (currently 1.7.0, `bin: { openspec: 'bin/openspec.js' }`).

This matters twice over on a restricted network: the internal npm mirror must carry
`@fission-ai/openspec`, and a mirror that resolves the bare name `openspec` will silently serve the
empty placeholder. Pin the scoped name and the version.

Also note: OpenSpec 1.7.0 has **no `openspec change new`** subcommand — `openspec change` only has
`show`/`list`/`validate`. Change folders are created by the agent following the `opsx` workflow, not
by a CLI call. (The `store register` output suggests `openspec new change …`; that command does not
exist in the top-level help.)

## 3b. How a code repo links a store contract without restating it — `references:`

This is native, and it is the mechanism behind cross-repo checklist step 2 ("the contract spec lives
in the store only; each repo's child delta links it and never restates the shape"). Verified.

Declare the store in the **code repo's** `openspec/config.yaml`:

```yaml
schema: spec-driven

references:
  - corp-store
```

What that buys, from OpenSpec's own source doc-comment (`dist/core/references.js`):

> A root's `openspec/config.yaml` may declare `references:` — store ids whose specs the root's work
> draws on. Instructions output carries an INDEX of those stores' specs (id, one-line summary, fetch
> recipe via `--store`), built live from the registered checkouts at assembly time. **Content is
> never inlined; root resolution is never affected**; problems degrade to `warning` diagnostics
> instead of failing generation.

Both guarantees are the ones we need. **"Content is never inlined"** *is* link-don't-restate,
enforced by the tool. **"Root resolution is never affected"** means declaring a reference cannot
re-introduce §1's bug — verified: `openspec context --json` from the code repo still reports

```json
"root": { "path": "…/clones/nested-repo", "source": "nearest", "role": "openspec_root" },
"members": [ { "role": "referenced_store", "id": "corp-store",
               "fetch": "openspec show <spec-id> --type spec --store corp-store" } ]
```

`"source": "nearest"` is the root rule stated by the tool itself. The agent then pulls the contract
on demand, from inside the code repo:

```
$ openspec show order-events --type spec --store corp-store
Using OpenSpec root: corp-store (…/estate/system-store)
# order-events
…
```

**Prerequisite:** the store must be *registered on that machine* — `openspec store register <path>
--id corp-store --yes`. Registration is per machine and does **not** affect root resolution (§1
T4). On a restricted network, DevOps registers the store as part of dev-machine provisioning; a
missing registration degrades to a warning, so check `openspec doctor` in the self-hosted CI job.

### The split-brain lint — designed, missing, now BUILT (2026-08-04)

The design calls for a "split-brain lint: contract facts live in exactly ONE place, spokes link
never restate". `corp-lint.mjs` did **not** implement it (grep-verified — no contract or store check
existed). OpenSpec's "never inlined" guarantee covers what *OpenSpec* renders; it does not stop a
human or an agent from pasting the payload shape into a spoke's delta by hand.

Built as **`tools/check-contract-split-brain.mjs`** (zero dependencies, in the starter kit) and
wired into `verify-docs.sh` — so it inherits the disposer's one-code-path/four-triggers contract
(agent post-write, lefthook pre-commit, on demand, the self-hosted CI backstop) instead of becoming a fifth
thing someone has to remember to run.

Deliberately a **separate script, not an edit to `corp-lint.mjs`**: corp-lint's body is reproduced
verbatim in guide §10 and in both language kits, and the guide names only two sanctioned edits to
it. A new file keeps that contract intact.

How it works:

1. Reads `references:` from the spoke's `openspec/config.yaml`. **No references ⇒ exit 0
   immediately** — the check costs nothing in single-repo repos.
2. Resolves each store id through OpenSpec's own registry,
   `~/.local/share/openspec/stores/registry.yaml` (honours `XDG_DATA_HOME`; override with
   `OPENSPEC_STORE_REGISTRY`). An unregistered store is a **WARN, never a block** — it is an
   environment problem, and a missing registration must not stop a commit.
3. Fingerprints every referenced store's specs: `### Requirement:` headings (normalized) and fenced
   code blocks of 2+ lines (one-liners are too common to be evidence).
4. Scans the spoke's `openspec/specs/**` and `openspec/changes/**` (archive excluded unless
   `SPLIT_BRAIN_INCLUDE_ARCHIVE=1`) and **ERRORs** on a restated requirement heading or a copied
   shape, each with `file:line`, the owning `store:spec`, and the fetch command to use instead.

Real output on a spoke that pasted the contract:

```
✗ openspec/changes/bad-consume/specs/web-orders/spec.md:5: restates contract requirement
    "OrderCreated payload" owned by corp-store:order-events
     ↳ delete it here and link the store spec instead: `openspec show order-events --type spec --store corp-store`
✗ openspec/changes/bad-consume/specs/web-orders/spec.md:8: copies a contract shape owned by corp-store:order-events
     ↳ contract shapes live in the store only — reference it, never paste it
✗ split-brain: 2 contract fact(s) restated in this repo
```

**Known limit, stated honestly:** this catches *verbatim* restatement — an identical requirement
heading or an identical code block. A paraphrased shape ("the event has an order id and a cents
amount") still passes. That residue stays a `corp-code-review` judgement call; the lint removes the
copy-paste path, which is the one that actually happens.

## 4. Test evidence (2026-08-04, OpenSpec 1.7.0, node/npm)

| # | Setup | Result |
|---|---|---|
| T1 | `npm i openspec` | version **0.0.0**, no binary — placeholder package |
| T2 | `npm view @fission-ai/openspec` | **1.7.0**, `bin: {openspec: bin/openspec.js}` — the real CLI |
| T3 | `openspec context` in a repo with no `openspec/`, not nested | clean error: `No OpenSpec root found from the current directory.` |
| T4 | same, with store `corp-store` **registered** | clean error naming the store; registration does **not** hijack the root |
| T5 (C) | `git init`-ed repo at `system-store/clones/nested-repo`, **not** onboarded | **resolved to `system-store`** — the bug, walk crossed the `.git` boundary |
| T6 (D) | same repo after `openspec init` | resolved to `nested-repo` — nearest root wins |
| T7 | change created in the onboarded clone; `openspec list` **from the clone** | `add-bar-validation` listed |
| T8 | same change; `openspec list` **from the store** | `No active changes found.` — isolation holds |
| T9 | `check-openspec-root.sh` in a nested, never-onboarded repo | `✗ no openspec/ in this repo`, **exit 1** |
| T10 | `check-openspec-root.sh` in the onboarded clone, and from a subdirectory of it | `✓ OpenSpec root = …` both times, exit 0 |
| T11 | `references: [corp-store]` in the code repo's `openspec/config.yaml`; `openspec context` | root stays `nested-repo`; store listed under **Referenced stores** with its fetch recipe |
| T12 | `openspec context --json` with the reference declared | `"source": "nearest"`, member `"role": "referenced_store"` — root resolution unaffected |
| T13 | `openspec show order-events --type spec --store corp-store` run **from the code repo** | contract fetched on demand; nothing copied into the repo |
| T14 | grep `corp-lint.mjs` for a split-brain / contract / store check | **absent** — the designed lint had never been built (§3b) |
| T15 | `check-contract-split-brain.mjs` on a spoke that links the contract properly | `✓ split-brain: no contract facts restated (checked 2 spec file(s) against 1 store requirement(s))`, exit 0 |
| T16 | same lint on a spoke that restates the heading **and** pastes the JSON shape | both caught with `file:line` + owner + fix, exit 1 |
| T17 | same lint on a repo with no `references:` | `✓ split-brain: no references declared — nothing to check`, exit 0 |
| T18 | same lint with the store referenced but **not registered** | `⚠ … not registered on this machine`, exit 0 — warns, never blocks |
| T19 | invoked with no path argument from the repo root, as `verify-docs.sh` calls it | exit 0, correct output |
