# Operations

## Daily entry gate

Start inside the selected repository, not at the system-store root:

```bash
export REPO_ROOT="$(git rev-parse --show-toplevel)"
bash "$REPO_ROOT/tools/repository-state.sh" inspect
```

Before a new story, run `prepare-base`, create `feature/<TICKET>` from the reported
base, publish its upstream, then run `assert-change <TICKET>`. During interrupted
work, use `assert-change <TICKET> --allow-dirty` only after you recognize every
local edit. A non-zero result is a hard stop.

The repository-state tool never resets, cleans, rebases, deletes branches, changes
an unknown dirty tree, or hides local commits. It resolves the base from
`CORP_BASE_BRANCH`, local `corp.baseBranch`, the parent store's `.gitmodules`,
remote `develop`, then the remote default.

## Workflow

1. `corp-spec`: inspect live repositories, prepare bases, create story branches,
   and explicitly run the installed OpenSpec new and continue commands until
   proposal and delta spec exist.
2. `corp-plan`: assert the story branch and create current design and tasks.
3. `corp-implement`: assert the branch, enter OpenSpec apply, then use Corp TDD.
4. `corp-review`: inspect state and run OpenSpec verify before human review.
5. `corp-test-plan` and `corp-autotest`: derive checks from approved scenarios.
6. After merge, `corp-archive`: prepare the configured base and run OpenSpec archive.

The exact generated OpenSpec invocations live in `port-facts.md` and the installed
commands. Re-probe them after every port or OpenSpec upgrade.

## Refresh project bindings

Re-run project-binding discovery for the stored project id. Prefer MCP when its
tool is available; otherwise update the same normalized JSON manually. Then run:

```bash
export STORE_ROOT="$(git rev-parse --show-toplevel)"
bash "$STORE_ROOT/tools/sync-submodules.sh" \
  --inventory "$STORE_ROOT/project-repositories.json" --store-root "$STORE_ROOT"
git -C "$STORE_ROOT" submodule status
```

New bindings are added. Existing matching bindings are initialized. Missing
bindings are reported but preserved. URL, unsafe-path, and foreign-directory
mismatches stop before mutation.

To refresh registered content after reviewing local state:

```bash
git -C "$STORE_ROOT" submodule foreach --recursive 'git fetch --prune origin'
```

Use each repository's `repository-state.sh prepare-base` to fast-forward safely.
Do not use bulk checkout or reset commands.

## Cross-repository changes

Use one parent ticket for the system-store contract and one child ticket per
repository. Create the contract first. Repository delta specs link the contract
by store id and spec id; they do not restate its field shape. Approval order is
contract first. Implementation and merge order are producer, consumers, then
the store contract. A contract change stops all dependent work.

Regenerate the central catalog after repository indexes are current:

```bash
node "$STORE_ROOT/tools/aggregate-index.mjs" --strict "$STORE_ROOT"
```

## Recovery table

| State | Meaning | Safe next action |
|---|---|---|
| detached HEAD | no safe story branch | identify the owning remote branch; preserve commits |
| dirty during base preparation | edits may be unique | inspect and deliberately commit or relocate them |
| ahead of upstream | unpublished commits | review and push or move them before switching |
| behind only | safe update available | run `prepare-base` for verified fast-forward |
| ahead and behind | divergence | stop and choose merge or rebase under team policy |
| wrong story branch | work may belong elsewhere | inspect; switch only after preserving local work |
| orphaned binding | inventory no longer lists it | confirm project ownership before manual removal |

## Optional Zoekt index

Zoekt is optional. The workflow works without it. On its dedicated host, install
`zoekt-git-index` and Universal Ctags, then run:

```bash
bash "$STORE_ROOT/tools/index-all.sh" --store-root "$STORE_ROOT" \
  --index-dir "${CORP_ZOEKT_INDEX_DIR:-$STORE_ROOT/.cache/zoekt/index}"
```

The tool reads `.gitmodules`, validates every path before indexing, requires real
Universal Ctags, and reports missing registered submodules. Never maintain a
second repository list for search.

## Operating rules

1. Prompts advise, the disposer and CI enforce. Never fix a red check by weakening it.
2. Caps reject, never trim. The agent regenerates; humans never hand-repair generated files.
3. The central catalog is a routing hint. The repository index outranks it; the
   repository outranks its own index.
4. Specs are durable, plans are disposable. Regenerate design and tasks when in doubt.
5. Every spec-versus-code mismatch becomes a delta. That is the spec base growing,
   not a failure.
6. The same error three times: stop and ask a human.

## Measure adoption

Record these in a `baselines/` note in the store before the first team starts, then
on the same period afterwards. Both are pure Git and need no CI data:

```bash
# merges in the trailing 90 days — deploy-frequency proxy until CI data is wired
git log --merges --since="90 days ago" --format=%cI | wc -l
# archived changes per repository — the adoption counter
ls openspec/changes/archive 2>/dev/null | wc -l
```

Squash-merge repositories have no merge commits: count merged pull-request subjects
with `git log --grep` instead.

Anti-gaming check, per archived change: the proposal must predate the first
implementation commit on that branch.

```bash
git log --diff-filter=A --format=%ct -- "openspec/changes/<id>/proposal.md" | tail -1
```

A spec written after the code is flow theater; count it as non-adoption.

Ask the team these five questions quarterly, anonymously, at team level, on a 1–5
scale, plus one free-text answer. Use them verbatim so the periods stay comparable:

1. How satisfied are you with your day-to-day development workflow?
2. How often can you work on a task without losing flow to friction or waiting?
3. How would you rate the quality of code review you receive?
4. How much does the SDD flow help versus hinder your work?
5. Would you recommend the flow to a colleague team?

Free text: what one thing should we fix?
## Installed versions

Every command, skill, and script carries its own version marker, so an installed copy
identifies itself with no external index: `version: X.Y.Z` in Markdown frontmatter and
`corp-sdd-version: X.Y.Z` in scripts. `VERSIONS.md` in the kit lists all of them.

Report what is installed here, and compare it against the kit:

```bash
bash "$CORP_SYSTEM_STORE_ROOT/tools/corp-versions.sh" \
  --kit "$CORP_SDD_ROOT" \
  "$CORP_SYSTEM_STORE_ROOT/tools" "<command-dir>" "<skill-dir>"
```

`current` means the installed version equals the kit's. `STALE` means the kit moved on —
reinstall that asset. `UNVERSIONED` means a hand-edited copy with the marker stripped.
The exit code is 1 when anything is `STALE`, `UNVERSIONED`, or `MISSING`.

Versions rise automatically, and only on a real change. The kit's `pre-commit` hook bumps
the patch level of every staged command, skill, or script whose body differs from `HEAD`
(the version line itself is ignored in that comparison) and refreshes `VERSIONS.md`, so no
one is ever asked for a version number, and a restage, amend, or rebase bumps nothing.
Enable the hook once per clone:

```bash
git -C "$CORP_SDD_ROOT" config core.hooksPath .githooks
```

Set `CORP_SDD_BUMP_LEVEL=minor` or `major` on a commit that changes an asset's contract.

## Upgrade

Pull `corp-sdd`, review its changes, then repeat setup stages 1, 2, and 5–9.
Do not overwrite the system store from `system-store-template/`. Copy current
tools, commands, and skills into their discovered destinations, resolve OpenSpec
placeholders in installed command copies, run negative tests, and commit each Git
repository independently.
