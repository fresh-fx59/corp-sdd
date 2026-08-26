# Upgrade task for the installation agent

Use this runbook when the workspace already exists — `corp-sdd`, a sibling
system store, and N onboarded submodules — and you are moving it from an older
kit edition to the current one. A first install is `docs/SETUP.md`; this file
never replaces it.

Stop on every failed gate. Record commands and outputs in your project handover.
Never delete, reset, clean, rebase, force-checkout, or rewrite an existing
repository during an upgrade. An upgrade replaces *tool, command and skill
files*. It never touches project content.

## 0. Take stock before you touch anything

Resolve the same durable roots the setup runbook uses. Run this from the new,
unpacked `corp-sdd` checkout:

```bash
export CORP_SDD_ROOT="$(git rev-parse --show-toplevel)"
export CORP_WORKSPACE_ROOT="$(cd "$CORP_SDD_ROOT/.." && pwd -P)"
export CORP_SYSTEM_STORE_ROOT="${CORP_SYSTEM_STORE_ROOT:-$CORP_WORKSPACE_ROOT/system-store}"
export KV="$CORP_SDD_ROOT/scripts/tools/kit-version.sh"
test -d "$CORP_SYSTEM_STORE_ROOT/.git" || test -f "$CORP_SYSTEM_STORE_ROOT/.git"
test "$CORP_SYSTEM_STORE_ROOT" != "$CORP_SDD_ROOT"
```

Name both editions — the one you are installing, and the one already on disk:

```bash
bash "$KV" show      # the edition this kit is
bash "$KV" verify    # this kit's own files are the bytes of that edition
bash "$KV" list      # every stamped file and its stamp
```

`verify` must be green before you copy anything out of this kit. A kit that fails
its own manifest is not a release; re-unpack it.

Now classify every **installed** copy. `identify` hashes the file you name, so it
works at any path, including an agent-home command directory:

```bash
# store tools
bash "$KV" identify "$CORP_SYSTEM_STORE_ROOT"/tools/* || true
# every submodule's spoke tools
git -C "$CORP_SYSTEM_STORE_ROOT" submodule foreach --quiet 'echo "$toplevel/$sm_path"' \
  | while IFS= read -r repo; do bash "$KV" identify "$repo"/tools/* || true; done
# installed commands and skills, at the paths port-facts.md records
bash "$KV" identify "<installed-command-dir>"/corp-*.md || true
bash "$KV" identify "<installed-skill-dir>"/corp-*/SKILL.md || true
```

Each line is one of three verdicts:

| Verdict | Meaning | What the upgrade does |
|---|---|---|
| `pristine <edition>` | untouched kit file of that edition | replace it silently |
| `MODIFIED` | carries a stamp, but not those bytes — someone edited it | **stop**, stage 5 |
| `UNSTAMPED` | predates versioning, or is a local file | treat as MODIFIED, stage 5 |

Write the full three-way inventory into the handover **before** the first copy.
After the upgrade it cannot be reconstructed: a replaced file looks exactly like
a file that was already current.

## 1. Every repository clean and on its base branch

The upgrade writes into the store and into every submodule. Each one is a
separate Git repository and is committed separately, so each one is gated
separately, before any copy:

```bash
bash "$CORP_SDD_ROOT/scripts/tools/repository-state.sh" prepare-base \
  --repo "$CORP_SYSTEM_STORE_ROOT" --base "$(git -C "$CORP_SYSTEM_STORE_ROOT" config corp.baseBranch)"
git -C "$CORP_SYSTEM_STORE_ROOT" submodule foreach --quiet 'echo "$toplevel/$sm_path"' \
  | while IFS= read -r repo; do
      bash "$CORP_SDD_ROOT/scripts/tools/repository-state.sh" prepare-base --repo "$repo"
    done
```

The state gate refuses dirty worktrees, detached HEAD, unpushed commits on the
base branch, wrong upstreams, and divergence. It only performs a verified
fast-forward. A stash and commits on other local branches are reported, never
blocked and never touched. Resolve every stop with the owner of that work — do not upgrade
around it. A repository that cannot be gated is skipped whole and named in the
handover; a half-upgraded repository is the one state the daily flow cannot
detect.

Do not start a shared "upgrade" branch across repositories. Each repository gets
its own commit on its own base, so each can be reverted alone (stage 9).

## 2. Re-probe the port only when it changed

Skip this stage unless the agent CLI version, its command or skill directory, or
the pinned OpenSpec package version changed since `port-facts.md` was written.
If any of those changed, redo SETUP stage 2 in full against the real port —
never edit the recorded invocations by hand — and prove the new pin once:

```bash
npx @fission-ai/openspec@<pinned-version> --version
```

Refresh the store's copy of the facts, keeping the recorded ids:

```bash
git -C "$CORP_SYSTEM_STORE_ROOT" diff -- port-facts.md
```

`<store-id>` and every repository id are a contract, not a label. An upgrade
never renames them; cross-repo links resolve by id and would break silently.

## 3. Refresh the system store's own tools

This is the stage the old five-line upgrade note omitted, and the only place the
store's `tools/` are installed. Skipping it leaves the store running the previous
edition's `sync-submodules.sh`, `repository-state.sh` and `aggregate-index.mjs`
while every other file claims to be current:

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
install -m 0644 "$CORP_SDD_ROOT/templates/conventions-branching.md" "$CORP_SYSTEM_STORE_ROOT/conventions/branching.md"
mkdir -p "$CORP_SYSTEM_STORE_ROOT/templates"
install -m 0644 "$CORP_SDD_ROOT/templates/store-contract.md"  "$CORP_SYSTEM_STORE_ROOT/templates/"
install -m 0644 "$CORP_SDD_ROOT/templates/testing-stack.md"   "$CORP_SYSTEM_STORE_ROOT/templates/"
install -m 0644 "$CORP_SDD_ROOT/templates/research.md"        "$CORP_SYSTEM_STORE_ROOT/templates/"
install -m 0644 "$CORP_SDD_ROOT/templates/adr.md"             "$CORP_SYSTEM_STORE_ROOT/templates/"
```

`port-facts.md` is **not** in that list. It holds this installation's probed
facts, not kit content; stage 2 owns it. Copying the blank template over it
erases the port evidence the installed commands were resolved from.

Prove the copy, then leave the commit for stage 8:

```bash
bash -n "$CORP_SYSTEM_STORE_ROOT/tools/sync-submodules.sh"
bash -n "$CORP_SYSTEM_STORE_ROOT/tools/repository-state.sh"
bash "$KV" identify "$CORP_SYSTEM_STORE_ROOT"/tools/*.sh "$CORP_SYSTEM_STORE_ROOT"/tools/*.mjs
git -C "$CORP_SYSTEM_STORE_ROOT" status --short
```

Every stamped line must now read `pristine <new edition>`.

## 4. Refresh the spoke tools in every submodule

Each onboarded repository carries the seven spoke tools from SETUP stage 5
step 4. Copy them from the store's freshly updated `tools/`, one repository at a
time, skipping any repository stage 1 could not gate:

```bash
git -C "$CORP_SYSTEM_STORE_ROOT" submodule foreach --quiet 'echo "$toplevel/$sm_path"' \
  | while IFS= read -r repo; do
      test -d "$repo/tools" || continue
      install -m 0755 "$CORP_SYSTEM_STORE_ROOT/tools/repository-state.sh"        "$repo/tools/"
      install -m 0755 "$CORP_SYSTEM_STORE_ROOT/tools/verify-docs.sh"             "$repo/tools/"
      install -m 0755 "$CORP_SYSTEM_STORE_ROOT/tools/check-openspec-root.sh"     "$repo/tools/"
      install -m 0755 "$CORP_SYSTEM_STORE_ROOT/tools/check-git-naming.sh"        "$repo/tools/"
      install -m 0644 "$CORP_SYSTEM_STORE_ROOT/tools/corp-lint.mjs"              "$repo/tools/"
      install -m 0644 "$CORP_SYSTEM_STORE_ROOT/tools/gen-index.mjs"              "$repo/tools/"
      install -m 0644 "$CORP_SYSTEM_STORE_ROOT/tools/check-contract-split-brain.mjs" "$repo/tools/"
      bash -n "$repo/tools/verify-docs.sh"
      bash "$repo/tools/verify-docs.sh"
    done
```

`aggregate-index.mjs`, `index-all.sh` and `sync-submodules.sh` are store-only.
A spoke that grows them starts maintaining a second repository list.

If a repository's `verify-docs.sh` turns red on content that was green before,
the new disposer tightened a cap. Regenerate the content. Never loosen the cap
and never delete the check to finish the upgrade.

## 4a. New per-repository files this edition requires

Two files SETUP now installs into every repository did not exist in older editions, and an
upgrade that skips them leaves working repositories half-configured:

```bash
for repo in $(git -C "$CORP_SYSTEM_STORE_ROOT" submodule --quiet foreach 'echo $sm_path'); do
  d="$CORP_SYSTEM_STORE_ROOT/$repo"
  mkdir -p "$d/docs" "$d/templates"
  install -m 0644 "$CORP_SDD_ROOT/templates/testing-stack.md" "$d/templates/"
  install -m 0644 "$CORP_SDD_ROOT/templates/research.md"      "$d/templates/"
  install -m 0644 "$CORP_SDD_ROOT/templates/adr.md"           "$d/templates/"
  test -f "$d/docs/testing-stack.md" || cp "$CORP_SDD_ROOT/templates/testing-stack.md" "$d/docs/testing-stack.md"
  test -f "$d/.gitignore" || install -m 0644 "$CORP_SDD_ROOT/system-store-template/.gitignore" "$d/.gitignore"
done
```

`docs/testing-stack.md` is what `corp-tdd` and `corp-debugging` read instead of naming a
technology; a repository without it leaves both skills with no stack, and the copy above is a
blank template someone must fill in with the team (SETUP step 6a). Never overwrite one that
already holds real content. The `.gitignore` is SETUP step 6b: untracked files never block a
gate, but an ignored file can never be staged by accident either — merge it into an existing
`.gitignore` rather than replacing it.

## 5. Commands, skills, and the placeholder re-resolution

Copy `skills/corp-*` into the project-scoped skill directory recorded in
`port-facts.md`, and `commands/corp-*.md` into the recorded command directory.
Adapt only the port wrapper, frontmatter, and `{{args}}` token, exactly as at
install time.

A fresh command file ships **unresolved** placeholders. The copy therefore undoes
the install-time resolution, and re-resolving is mandatory, not optional:
replace every `<openspec>` token with the resolved CLI invocation recorded in
`port-facts.md`. `corp-spec` must call `new change` and per-artifact `instructions`,
`corp-plan` `instructions design`/`instructions tasks`, `corp-implement`
`instructions apply`, `corp-review` `validate` and `status`, `corp-archive` `archive`.

```bash
rg -n '<openspec>' "<installed-command-dir>" && exit 1 || true
```

That proof is the gate: a non-empty result means the upgrade left a command
that cannot run. If the port has no skill mechanism, inline the skill bodies
again and prove no unavailable skill reference remains.

## 6. MODIFIED and UNSTAMPED files: decide, never overwrite

Stage 0 listed them. For each one, stop the copy for that single file and:

1. diff the installed copy against the kit copy of the same path:

   ```bash
   diff -u "<installed-file>" "$CORP_SDD_ROOT/<kit-path-from-identify>"
   ```

   `identify` prints the kit path for a pristine file; for a MODIFIED one, use
   the same relative path under `$CORP_SDD_ROOT`.
2. decide **keep** or **replace** with a named human — the harness owner, or the
   author of the local change when Git names one:

   ```bash
   git -C "<repo>" log -1 --format='%an %ae %cI' -- "<path-relative-to-repo>"
   ```
3. record the decision in the handover: file, both editions, who decided, why.
   A kept local change is now a permanent fork of that file — say so, and file it
   as a kit change request so the next upgrade does not re-litigate it.

Silently overwriting here is the failure this stage exists to prevent: a
deliberate local guard or a port-specific wrapper disappears, and nothing in the
daily flow reports it.

## 7. What an upgrade must never touch

These are project content and installation identity, not kit files. Leave them
exactly as they are:

- `project-repositories.json` — the inventory. Refreshing bindings is a separate
  operation (`docs/OPERATIONS.md`, "Refresh project bindings").
- `.gitmodules` and the submodule contents — an upgrade adds no repository and
  moves no pointer.
- `openspec/` in the store and in every repository — contracts, ADRs, changes,
  archives, `repo.txt`, `config.yaml`.
- `port-facts.md`, except through stage 2.
- The store's own project files under `tools/` that the kit does not ship.

Never re-run the `system-store-template` copy and never run `git init` in the
store. Both are first-install-only. Running them against a live store creates a
second, unrelated history and costs a rewrite rather than a retry.

## 8. Re-prove the guards, then run one real command

New tool bytes mean the guards are unproven again. Repeat SETUP stage 8 against
temporary bad inputs, in the store and in one representative spoke:

- a bad OpenSpec root must fail;
- a duplicated shared contract shape must fail the split-brain check;
- a bad branch and mismatched ticket commit must fail naming checks;
- `git config core.hooksPath` must be empty or point to this repository's hooks;
- a deliberate bad temporary commit must be rejected by the installed hook.

Re-run `lefthook install` in any repository whose `lefthook.yml` changed. Then
prove idempotence and the live catalog path:

```bash
bash "$CORP_SYSTEM_STORE_ROOT/tools/sync-submodules.sh" \
  --inventory "$CORP_SYSTEM_STORE_ROOT/project-repositories.json" \
  --store-root "$CORP_SYSTEM_STORE_ROOT"
git -C "$CORP_SYSTEM_STORE_ROOT" diff -- .gitmodules   # must be empty
node "$CORP_SYSTEM_STORE_ROOT/tools/aggregate-index.mjs" --strict "$CORP_SYSTEM_STORE_ROOT"
git -C "$CORP_SYSTEM_STORE_ROOT" submodule status
```

Files on disk are not a working upgrade. Invoke one Corp command inside the port
itself — run `corp-spec` against a throwaway ticket in one onboarded repository,
confirm it reaches the interview and writes `openspec/changes/<id>/proposal.md`,
then delete the branch and the change folder. An upgrade that has never executed
a command in the real port is unproven, whatever `identify` prints.

Commit each repository separately, one commit per repository, touching only the
copied files:

```bash
git -C "<repo>" add tools/ && git -C "<repo>" commit -m "chore(<TICKET>): corp-sdd tools -> <new edition>"
```

Do the same in the store, and commit the installed commands and skills wherever
the port keeps them under version control.

## 9. Rollback

Each repository's copy is exactly one commit, so rollback is one revert per
repository and nothing else:

```bash
git -C "<repo>" revert --no-edit <upgrade-commit>
bash "<repo>/tools/verify-docs.sh"
```

The store and the spokes roll back independently and in any order: the tools do
not read each other. Reverting the store does not change a submodule pointer,
because stage 4 committed inside the submodule, not in the store.

Rolling back commands and skills means re-installing the previous kit's
`commands/` and `skills/` and re-running the stage 5 placeholder resolution — the
port directory is usually not a Git repository, so keep the previous kit
unpacked until the acceptance checklist is green.

Nothing in stages 3–5 touches project content, so a rollback never loses a spec,
a change, or a submodule pointer.

## Acceptance

Close the upgrade only when every line holds:

- [ ] the pre-upgrade pristine / MODIFIED / UNSTAMPED inventory is in the handover;
- [ ] `kit-version.sh verify` green on the new kit before any copy;
- [ ] every repository gated with `prepare-base` before its copy; skipped
      repositories named with the failing gate and its output;
- [ ] store `tools/` and every spoke `tools/` now `identify` as pristine at the
      new edition;
- [ ] every MODIFIED or UNSTAMPED file has a recorded keep-or-replace decision
      and a named decider;
- [ ] commands and skills reinstalled, `rg` proves no `<openspec>` token left;
- [ ] `port-facts.md`, `project-repositories.json`, `.gitmodules` and every
      `openspec/` tree unchanged by the upgrade;
- [ ] SETUP stage 8 negative tests re-run and red where they must be red;
- [ ] `sync-submodules.sh` re-run clean and `aggregate-index --strict` green;
- [ ] one Corp command executed end-to-end in the port after the upgrade;
- [ ] one commit per repository, each revertible on its own, recorded in the
      handover by SHA.
