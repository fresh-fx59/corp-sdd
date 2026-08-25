# Setup task for the installation agent

Run these stages after pulling or upgrading `corp-sdd`. Stop on every failed gate.
Record commands and outputs in your project handover. Never delete, reset, clean,
rebase, force-checkout, or rewrite an existing repository during setup.

## 0. Prerequisites, required inputs, and durable roots

Prove the toolchain before anything else. Each line must print a version; a miss
stops the install, because the failure otherwise lands mid-stage 3 with a
half-populated store:

```bash
git --version        # >= 2.13, for `submodule --branch`
node --version       # >= 18, runs the .mjs disposers
rg --version         # used by the stage-6 placeholder proof
lefthook version     # install through the approved internal channel first
```

The OpenSpec CLI is pinned and internal. The package is `@fission-ai/openspec`;
the bare name `openspec` on the public registry is an unrelated empty `0.0.0`
placeholder and will silently install nothing usable. Record the pinned version
in `port-facts.md` and prove it once:

```bash
npx @fission-ai/openspec@<pinned-version> --version
```

On a restricted network, resolve that package through the approved internal
mirror and note the resolved registry in your handover.

Obtain `<project-id>`, the corporate agent port name, the pinned OpenSpec package
version, the system-store remote URL and approved base branch, and internal forge
credentials. From the `corp-sdd` checkout:

```bash
export CORP_SDD_ROOT="$(git rev-parse --show-toplevel)"
export CORP_WORKSPACE_ROOT="$(cd "$CORP_SDD_ROOT/.." && pwd -P)"
export CORP_SYSTEM_STORE_ROOT="${CORP_SYSTEM_STORE_ROOT:-$CORP_WORKSPACE_ROOT/system-store}"
test -d "$CORP_SDD_ROOT/system-store-template"
test "$CORP_SYSTEM_STORE_ROOT" != "$CORP_SDD_ROOT"
```

These variables replace machine-specific paths. Keep `system-store` beside
`corp-sdd`, never inside it.

## 1. Discover repositories for `<project-id>`

This is the first setup action after resolving roots. Enumerate available MCP
tools and, when a project-binding tool exists, call it now with `<project-id>`.
Include only repositories bound to that project.
Normalize its result to this schema:

```json
{
  "schema_version": 1,
  "project": "<project-id>",
  "repository_source": "mcp",
  "repositories": [
    {"name": "service-a", "url": "ssh://git@forge/project/service-a.git", "base_branch": "develop"}
  ]
}
```

Manual fallback: if MCP is absent, inaccessible, or does not expose repository
bindings, copy `config/project-repositories.json.example`, set
`repository_source` to `manual`, and fill the same fields from the forge project.
Installation continues normally; report which source was used.

For each repository, use the base branch returned by MCP when present. Otherwise
prefer `develop` when that remote branch exists, then use the remote symbolic
default branch. Never infer the base from the current checkout. Validate safe,
unique names, non-empty URLs, and valid Git branch names before writing anything.

## 2. Discover the agent port before installing

Probe the real port and write evidence to a copy of `templates/port-facts.md`:

1. configuration directory and project instruction filename;
2. command directory, file format, invocation syntax, and argument token;
3. skill directory and whether project-scoped skills load automatically;
4. generated OpenSpec command names for new, continue, apply, verify, and archive;
5. MCP tool names for project repository bindings, tracker, wiki, and code search;
6. hook support, context limits, and agent version.

Do not assume `.qwen/`, slash commands, or any MCP tool name. Initialize OpenSpec
once in temporary data with the pinned internal package, then inspect the generated
files. Record exact invocations as:

```text
<opsx-new-command>
<opsx-continue-command>
<opsx-apply-command>
<opsx-verify-command>
<opsx-archive-command>
```

Upstream Superpowers is not required. Use the self-contained `skills/corp-*`
files. If the port has no skill mechanism, inline each referenced skill body into
the installed command and remove its `Follow skill ...` sentence.

## 3. Create or verify the sibling system store

Three cases, and the machine decides which one you are in — never guess, and never
ask the operator something Git can answer:

```bash
git ls-remote --heads "<system-store-remote-url>" "<system-store-base-branch>"
```

**The store already exists on the remote** (the probe printed a ref) — you are the
second developer or later. Clone it; do not create anything:

```bash
test ! -e "$CORP_SYSTEM_STORE_ROOT"
git clone --branch "<system-store-base-branch>" --single-branch "<system-store-remote-url>" "$CORP_SYSTEM_STORE_ROOT"
bash "$CORP_SDD_ROOT/scripts/tools/repository-state.sh" prepare-base --repo "$CORP_SYSTEM_STORE_ROOT" --base "<system-store-base-branch>"
git -C "$CORP_SYSTEM_STORE_ROOT" config corp.baseBranch "<system-store-base-branch>"
```

Running the template path here would `git init` a second, unrelated history against
a remote that already holds the project's store. That is the one mistake in this
stage that costs a rewrite rather than a retry.

**The project is explicitly creating a new empty store** (the probe printed nothing,
and this is the first install anywhere) — start from the shipped template:

```bash
test ! -e "$CORP_SYSTEM_STORE_ROOT"
cp -R "$CORP_SDD_ROOT/system-store-template" "$CORP_SYSTEM_STORE_ROOT"
git -C "$CORP_SYSTEM_STORE_ROOT" init -b "<system-store-base-branch>"
git -C "$CORP_SYSTEM_STORE_ROOT" remote add origin "<system-store-remote-url>"
git -C "$CORP_SYSTEM_STORE_ROOT" config corp.baseBranch "<system-store-base-branch>"
```

**The store is already on this machine** — do not copy or clone over it. Prove it is
an independent Git root, then gate its branch and worktree before touching the
inventory or the installed files:

```bash
test "$(git -C "$CORP_SYSTEM_STORE_ROOT" rev-parse --show-toplevel)" = "$CORP_SYSTEM_STORE_ROOT"
git -C "$CORP_SYSTEM_STORE_ROOT" status --short --branch
bash "$CORP_SDD_ROOT/scripts/tools/repository-state.sh" prepare-base --repo "$CORP_SYSTEM_STORE_ROOT" --base "<system-store-base-branch>"
git -C "$CORP_SYSTEM_STORE_ROOT" config corp.baseBranch "<system-store-base-branch>"
```

The state gate refuses dirty worktrees, stashes, detached HEAD, unpublished commits,
wrong upstreams, and divergence. It only performs a verified fast-forward.

Place the normalized stage-1 result at
`$CORP_SYSTEM_STORE_ROOT/project-repositories.json`. Copy current store tools and
templates without removing project-owned files:

```bash
install -m 0755 "$CORP_SDD_ROOT/scripts/tools/sync-submodules.sh" "$CORP_SYSTEM_STORE_ROOT/tools/"
install -m 0755 "$CORP_SDD_ROOT/scripts/tools/repository-state.sh" "$CORP_SYSTEM_STORE_ROOT/tools/"
install -m 0755 "$CORP_SDD_ROOT/scripts/tools/index-all.sh" "$CORP_SYSTEM_STORE_ROOT/tools/"
install -m 0755 "$CORP_SDD_ROOT/scripts/tools/verify-docs.sh" "$CORP_SYSTEM_STORE_ROOT/tools/"
install -m 0755 "$CORP_SDD_ROOT/scripts/tools/check-git-naming.sh" "$CORP_SYSTEM_STORE_ROOT/tools/"
install -m 0644 "$CORP_SDD_ROOT/scripts/tools/aggregate-index.mjs" "$CORP_SYSTEM_STORE_ROOT/tools/"
install -m 0644 "$CORP_SDD_ROOT/scripts/tools/gen-index.mjs" "$CORP_SYSTEM_STORE_ROOT/tools/"
install -m 0644 "$CORP_SDD_ROOT/scripts/tools/corp-lint.mjs" "$CORP_SYSTEM_STORE_ROOT/tools/"
install -m 0644 "$CORP_SDD_ROOT/scripts/tools/check-contract-split-brain.mjs" "$CORP_SYSTEM_STORE_ROOT/tools/"
install -m 0755 "$CORP_SDD_ROOT/scripts/tools/check-openspec-root.sh" "$CORP_SYSTEM_STORE_ROOT/tools/"
install -m 0755 "$CORP_SDD_ROOT/scripts/tools/corp-versions.sh" "$CORP_SYSTEM_STORE_ROOT/tools/"
install -m 0644 "$CORP_SDD_ROOT/templates/port-facts.md" "$CORP_SYSTEM_STORE_ROOT/port-facts.md"
install -m 0644 "$CORP_SDD_ROOT/templates/conventions-branching.md" "$CORP_SYSTEM_STORE_ROOT/conventions/branching.md"
```

Initialize OpenSpec in the store using the exact pinned package and port discovered
in stage 2. Run the copied root check, then register the absolute store path under
a stable `<store-id>` with the pinned OpenSpec CLI. Prove that `openspec store list`
returns that id and exact path. Do not run another OpenSpec command until its root
is verified.

Ids are a contract, not a label: cross-repo links resolve by id, so two agents
installing the same project must produce the same string. Use `<project-id>-store`
for `<store-id>` and the repository name from stage 1 for each repo id, both
lower-case kebab-case. Record both in `port-facts.md`.

## 4. Materialize project repositories as submodules

```bash
bash "$CORP_SYSTEM_STORE_ROOT/tools/sync-submodules.sh" \
  --inventory "$CORP_SYSTEM_STORE_ROOT/project-repositories.json" \
  --store-root "$CORP_SYSTEM_STORE_ROOT"
git -C "$CORP_SYSTEM_STORE_ROOT" submodule status
git -C "$CORP_SYSTEM_STORE_ROOT" diff -- .gitmodules
```

The sync is additive and repeatable. It records every base branch in `.gitmodules`,
rejects URL or path mismatches, and reports removed bindings as preserved orphans.
Resolve an orphan manually only after confirming its project binding and local work.

## 5. Onboard every registered submodule

For each path reported by `.gitmodules`:

1. run the root-derived `repository-state.sh prepare-base` and resolve every stop;
2. initialize OpenSpec in that repository with the pinned package and discovered port;
3. run `check-openspec-root.sh` and prove the reported root is that submodule;
4. copy the spoke tools: `repository-state.sh`, `corp-lint.mjs`, `gen-index.mjs`,
   `verify-docs.sh`, `check-openspec-root.sh`, `check-contract-split-brain.mjs`,
   and `check-git-naming.sh` into its `tools/` directory;
5. copy `config/lefthook.yml.example` to `lefthook.yml`, install lefthook through
   the approved internal channel, then run `lefthook install`;
6. add a stable repository id at `openspec/repo.txt`, generate its index, and run
   the root-derived `verify-docs.sh`;
7. declare the store in that repository's `openspec/config.yaml` so a spoke can
   link the shared contract instead of restating it:

   ```yaml
   references:
     - <store-id>
   ```

   Without this block `openspec show <spec-id> --type spec --store <store-id>`
   cannot resolve — the fetch line `corp-spec` writes into every cross-repo delta
   — and `check-contract-split-brain.mjs` exits 0 without checking anything, so a
   pasted contract shape goes unnoticed.

Initialize every submodule's OpenSpec root before invoking generated commands from
inside it. This prevents the parent store root from capturing repository changes.

If one submodule cannot be onboarded, finish the others, leave that repository
un-onboarded rather than half-onboarded, and name it in the handover with the
failing gate and its output. A partial repository is the one state the daily flow
cannot detect.

Append the write-boundary rule to the project instruction file that stage 2 proved
the port reads, in every onboarded repository and in the store:

```markdown
## HARD RULE — disposer self-check
After creating or editing ANY file under openspec/ or docs/, run:
    bash "$(git rev-parse --show-toplevel)/tools/verify-docs.sh"
Fix every ✗ (each error carries a remediation hint) and re-run until green
BEFORE reporting work done or proposing a commit. Rejected writes are corrected
by regenerating the content — never by loosening caps or deleting checks.
CIRCUIT BREAKER: if the same error survives 3 fix attempts, STOP and ask a human —
do not keep looping.
```

One script gates all three actors: the agent after a write, the human at
pre-commit through lefthook, and CI as the backstop.

## 6. Install Corp commands and skills

Copy `skills/corp-*` into the project-scoped skill directory discovered in stage 2.
Copy `commands/corp-*.md` into the discovered command directory. Adapt only the
port wrapper, frontmatter, and `{{args}}` token where required.

Replace every named OpenSpec placeholder in the installed copies with the exact
generated invocation from `port-facts.md`. The command bodies must explicitly call
new and continue during `corp-spec`, apply during `corp-implement`, verify during
`corp-review`, and archive during `corp-archive`.

```bash
rg -n '<opsx-(new|continue|apply|verify|archive)-command>' "<installed-command-dir>" && exit 1 || true
```

If skills are unsupported, inline their bodies now and prove no unavailable skill
reference remains. This fallback still installs the complete workflow without
Superpowers.

## 7. Wire the CI backstop

Adapt this to the self-hosted CI in use and smoke-test it before relying on it.
Every spoke repository runs the same disposer the agent and the hook run:

```bash
bash "$(git rev-parse --show-toplevel)/tools/verify-docs.sh"
```

The system store runs the catalog job nightly and on spoke merges:

```bash
STORE_ROOT="$(git rev-parse --show-toplevel)"
bash "$STORE_ROOT/tools/sync-submodules.sh" \
  --inventory "$STORE_ROOT/project-repositories.json" --store-root "$STORE_ROOT"
node "$STORE_ROOT/tools/aggregate-index.mjs" --strict   # a red repo fails the build, loudly
git add catalog.json catalog.md
git diff --cached --quiet || git commit -m "chore(<TICKET>): refresh catalog" && git push
```

Keep contract-test, schema-compatibility, and migration-lint jobs in separate
credential-scoped pipelines; the agent-facing job must not share their credentials.

## 8. Prove hooks and guards

Run all tools against temporary bad inputs before using a live change:

- a bad OpenSpec root must fail;
- a duplicated shared contract shape must fail the split-brain check;
- a bad branch and mismatched ticket commit must fail naming checks;
- `git config core.hooksPath` must be empty or point to this repository's hooks;
- a deliberate bad temporary commit must be rejected by the installed hook.

Never weaken a guard to make this stage green.

## 9. Final acceptance

After the last edit, syntax-check the installed scripts and run sync again to prove
idempotence:

```bash
bash -n "$CORP_SYSTEM_STORE_ROOT/tools/sync-submodules.sh"
bash -n "$CORP_SYSTEM_STORE_ROOT/tools/repository-state.sh"
bash "$CORP_SYSTEM_STORE_ROOT/tools/sync-submodules.sh" \
  --inventory "$CORP_SYSTEM_STORE_ROOT/project-repositories.json" \
  --store-root "$CORP_SYSTEM_STORE_ROOT"
git -C "$CORP_SYSTEM_STORE_ROOT" status --short --branch
git -C "$CORP_SYSTEM_STORE_ROOT" submodule status
```

Also verify each submodule's OpenSpec root, configured base branch, current state,
hooks, docs checks, installed commands, and skills. Commit the store and each
repository separately. Report repository source (`mcp` or `manual`) and paste all
fresh evidence.

Files on disk are not a working install. Invoke one Corp command inside the port
itself — run `corp-spec` against a throwaway ticket in one onboarded repository,
confirm it reaches the interview and writes `openspec/changes/<id>/proposal.md`,
then delete the branch and the change folder. An install that has never executed a
command in the real port is unproven, whatever the file listing says.

Close the install only when every line holds:

- [ ] store live: sync + `aggregate-index --strict` green in the nightly CI job;
- [ ] each onboarded repository: disposer green in pre-commit and in CI, index and
      `repo.txt` committed;
- [ ] commands and skills installed, no `<opsx-*-command>` placeholder left;
- [ ] one Corp command executed end-to-end in the port;
- [ ] named champion per team and a named harness owner who owns the pins, the
      catalog job, and the port re-probes;
- [ ] the exception path written down: any story may skip the flow, with the reason
      recorded in the tracker.
