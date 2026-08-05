# SETUP TASK — for the agent, to run after pulling these changes

**Date:** 2026-08-04 · **Runs in:** the corporate environment, by the implementing agent
**Read first:** [handoff](2026-07-18-corp-sdd-handoff-to-coder-agent.md) · [implementation guide](2026-07-18-corp-sdd-implementation-guide.md) · [root-resolution fix](2026-08-04-openspec-root-resolution-fix.md)

You are configuring an existing corp SDD installation. Everything below is a **change to make**,
not a decision to take. Where a step says VERIFY, run the command and paste the real output into
`IMPLEMENTATION-LOG.md` — a step with no pasted output did not happen.

**Ground rules** (from the handoff, restated because they bind this task):
scripts go in verbatim · never weaken a check to make it pass · evidence or it is not done ·
same error 3 times ⇒ stop and ask a human.

Vocabulary: **store** = the system store repo. **repo** = a code repo (a clone). **ticket** =
a tracker key like `ABCD-1234`.

---

## Step 1 — Correct the OpenSpec package name everywhere

The npm name `openspec` is an unrelated placeholder at version **0.0.0 with no binary**. The real
CLI is **`@fission-ai/openspec`**.

1. Replace every `npx openspec` with `npx @fission-ai/openspec` in scripts, docs, CI jobs, and the
   agent context files.
2. Confirm the internal npm mirror carries the **scoped** name, and pin the version.
3. VERIFY: `npx @fission-ai/openspec --version` prints a real version (1.7.0 or later).

## Step 2 — Prove every repo owns its own OpenSpec root

Specs must land in the code repo, never in the store. OpenSpec resolves its root by walking **up**
from the current directory for an `openspec/` dir, and **the walk does not stop at a `.git`
boundary** — so an un-onboarded repo, or a repo nested inside the store, silently writes to the
store.

1. Confirm clones live **outside** the store's directory tree. `repos.json` ships
   `"clones_dir": "../clones"` — a sibling. If any clone is inside the store, move it.
2. In every repo, ensure it was onboarded: `npx @fission-ai/openspec init --tools <port> .`
3. Install `tools/check-openspec-root.sh` in every repo.
4. VERIFY per repo, from the repo root:
   ```bash
   npx @fission-ai/openspec context     # root must be THIS repo
   bash tools/check-openspec-root.sh    # must print ✓ and exit 0
   ```
5. If any spec already sits in the store that belongs to a repo, move it to that repo and re-run.

## Step 3 — Register the store on every machine

Per machine, not per repo. Cwd does not matter — the path argument is absolute. This writes
`~/.local/share/openspec/stores/registry.yaml`.

```bash
npx @fission-ai/openspec store register /abs/path/to/system-store --id corp-store --yes
```

Do this on every dev machine and every self-hosted CI agent. VERIFY: `npx @fission-ai/openspec store list`
shows `corp-store` when run from an unrelated directory.

## Step 3b — Adopt the clones that already exist, then clean up

Machines that have done this work already have clones in `clones/`. **Do not delete them and
start over.** `sync-repos.sh` adopts a clone that is already on disk: it proves the directory
is the repo `repos.json` names, then fast-forwards it. Local work is never overwritten.

1. Update `tools/sync-repos.sh` to the version in the implementation guide §10 — it gained the
   adoption checks, stray reporting and `--prune`.
2. Run it and read every line. Fix each 🔴 with the one-line command it prints (wrong `origin`,
   a directory that is not a clone, a clone with no `origin`), then re-run until none are left.
   ```bash
   bash tools/sync-repos.sh
   ```
3. Clean up what earlier attempts left behind:
   ```bash
   bash tools/sync-repos.sh --prune --dry-run   # preview; deletes nothing
   bash tools/sync-repos.sh --prune             # deletes only strays with no local work
   ```
   It refuses to delete anything holding uncommitted changes, unpushed commits or stashes.
4. **The clean-up that matters most: a clone INSIDE the store's own tree.** OpenSpec resolves
   its root by walking up (Step 2), so a nested clone writes its specs into the store. Move it
   to the sibling `clones/` directory and delete the nested copy.
   ```bash
   grep -n clones_dir repos.json                      # must be "../clones" — sibling, not child
   find . -path ./.git -prune -o -name .git -print    # must print NOTHING inside the store
   ```
5. VERIFY (paste all three into `IMPLEMENTATION-LOG.md`):
   ```bash
   bash tools/sync-repos.sh          # "✓ sync done", no 🔴
   ls clones/                        # exactly the repos listed in repos.json
   node tools/aggregate-index.mjs    # catalog rebuilds from the adopted clones
   ```

**How the team keeps them updated afterwards:** `bash tools/sync-repos.sh` — before any
cross-repo change, and nightly in CI. Idempotent and fast-forward-only; a clone with local work
is reported and skipped, never clobbered. After editing `repos.json`, run `--prune --dry-run`
to see what the change orphaned.

## Step 4 — Declare the store reference in consumer repos

Only in repos that consume a cross-repo contract. **Append** to the repo's existing
`openspec/config.yaml` (created by `init` — do not create a new file):

```yaml
references:
  - corp-store
```

VERIFY: `npx @fission-ai/openspec context` from the repo prints the repo as the root **and** a
`Referenced stores` line with the fetch recipe. The root must not change.

## Step 5 — Install the split-brain lint

Contract facts live in the store only; spokes link and never restate.

1. Copy `tools/check-contract-split-brain.mjs` into every repo's `tools/`.
2. Add this line to `tools/verify-docs.sh`, after the `corp-lint.mjs` line:
   ```bash
   node tools/check-contract-split-brain.mjs || fail=1   # no-op in repos with no references:
   ```
3. VERIFY twice, and paste both:
   - a repo with no `references:` prints `✓ split-brain: no references declared — nothing to check`
   - in a consumer repo, deliberately paste a store contract's `### Requirement:` heading into a
     scratch delta spec, run `bash tools/verify-docs.sh`, and confirm it **fails** with the
     `restates contract requirement` error. Then delete the scratch file.

## Step 6 — Install the branch and commit-message convention

The agreed conventions:

```
branch          feature/ABCD-1234
commit message  feat(ABCD-1234): commit message text
```

1. Write the conventions file into the store as `conventions/branching.md` — use the kit template
   `templates/conventions-branching.md` verbatim. This is the single source of truth.
2. Copy `tools/check-git-naming.sh` into every repo's `tools/`.
3. Add the two hooks to each repo's `lefthook.yml` (kit `config/lefthook.yml.example` has the full
   file):
   ```yaml
   commit-msg:
     commands:
       message-convention:
         run: bash tools/check-git-naming.sh --commit-msg {1}

   pre-push:
     commands:
       branch-convention:
         run: bash tools/check-git-naming.sh --branch
   ```
4. Run `lefthook install` in each repo.

## Step 7 — VERIFY the hooks actually fire (do not skip)

A hook that is installed but never runs is worse than none: everything looks green. **A global
`core.hooksPath` silently overrides every repo's local hooks, including lefthook's install.**
This was hit on a real box during testing — the hook file existed, was executable, and did nothing.

```bash
git config core.hooksPath          # expect empty, or this repo's own hooks dir
```

Then prove it with deliberate failures, in a scratch branch, and paste the output:

1. On a branch named `bugfix/ABCD-1234`, run `bash tools/check-git-naming.sh --branch` →
   must exit 1 with `branch name ... does not match the convention`.
2. On `feature/ABCD-1234`, attempt `git commit -m "added stuff"` → must be **rejected**.
3. Same branch, `git commit -m "feat(ABCD-9999): wrong ticket"` → must be **rejected** with
   `commit ticket 'ABCD-9999' does not match branch ticket 'ABCD-1234'`.
4. Same branch, `git commit -m "feat(ABCD-1234): real message"` → must **succeed**.

If any of 1–3 succeeds, the hooks are not running. Fix that before continuing — do not proceed on
the assumption that they work.

## Step 8 — Teach the agent the conventions

The checks reject bad names; they do not teach the pattern. Both are needed.

1. Append to each repo's agent context file (the one port-facts **P7** proved the port reads):

   ```markdown
   ## HARD RULE — branch and commit naming
   Branch: feature/<TICKET>            e.g. feature/ABCD-1234
   Commit: <type>(<TICKET>): <text>    e.g. feat(ABCD-1234): add invoice validation
   Types: feat, fix, chore, docs, refactor, test, perf, build, ci, revert.
   The ticket in the commit MUST equal the ticket in the branch.
   Nothing after the ticket in a branch name — the description goes in the commit and the PR title.
   Full rules: conventions/branching.md in the system store.
   These are enforced by tools/check-git-naming.sh on commit and push. A rejected commit is
   corrected by fixing the message, never by weakening or bypassing the check (no --no-verify).
   ```

2. The `corp-spec` body already names the pattern in the §4 version you install in **Step 8b** —
   do not hand-edit it here; just confirm the installed body says
   *"the change branch named `feature/<TICKET>` for the story's ticket"*.
3. Update the team playbook's backend/frontend sections with the same two lines, so humans and
   agents read one rule.

## Step 8b — Replace the `corp-spec` command body

Read [2026-08-04-corp-sdd-cross-repo-fanout.md](2026-08-04-corp-sdd-cross-repo-fanout.md) and
replace the installed `corp-spec` body with its **§4** version. There is **no** separate fan-out
command — one `corp-spec` handles both cases and decides which from the drill-down.

What changes in it: the interview happens once at story level; the command counts the repos touched;
a single repo takes the old path unchanged; more than one repo with a genuine shared contract goes
to the store-contract-first fan-out, **after stating the plan and waiting for the analyst**. Child
tickets already attached to the parent are used as they are; if none exist it asks whether to create
them.

VERIFY: the port loads the updated command (P2 syntax) and it appears in the palette. Do **not** run
the cross-repo path against a real story yet — the doc says smoke-test it on one real two-repo story
first.

## Step 9 — Report

Write `IMPLEMENTATION-LOG.md` in the store with, per step: what you ran, the real output, and
anything you could not do and why. Then post a summary to the tracker.

**Definition of done**
- [ ] `npx @fission-ai/openspec --version` works; no bare `npx openspec` left anywhere
- [ ] every repo: `openspec context` names that repo; `check-openspec-root.sh` green
- [ ] `store list` shows `corp-store` from an unrelated directory, on every machine
- [ ] consumer repos declare `references:` and still resolve their own root
- [ ] split-brain lint installed, and **proven to fail** on a deliberately restated contract
- [ ] `conventions/branching.md` committed in the store
- [ ] `git config core.hooksPath` checked on every machine
- [ ] all four naming checks in Step 7 behave as specified, output pasted
- [ ] agent context files and the `corp-spec` body carry the naming rule
- [ ] updated `corp-spec` body installed and loadable by the port (cross-repo path not yet run on a real story)
- [ ] `bash tools/verify-docs.sh` green in every repo
