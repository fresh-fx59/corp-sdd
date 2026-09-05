# Corporate SDD with AI agents

A starter kit for spec-driven development across corporate repositories. It combines
OpenSpec lifecycle commands with deterministic repository, branch, documentation and
contract checks. The kit's own scripts ship with zero npm dependencies, for restricted
networks — but it drives the OpenSpec CLI, and that is installed from npm.

## What it costs to run

This is a kit you install, not a binary you drop in. Before the workflow works:

| Needs | Why |
|---|---|
| `git` >= 2.13 | `submodule --branch` |
| `node` >= 18 | runs the `.mjs` checks |
| `lefthook` | the pre-commit hooks |
| `@fission-ai/openspec` (npm) | the spec engine the commands drive |
| An agent CLI | Claude Code, Codex, or your corporate agent |

The npm package name matters: the bare `openspec` on the public registry is an
unrelated empty `0.0.0` placeholder. Installation is a staged runbook, not one
command — [`en/docs/SETUP.md`](en/docs/SETUP.md).

## See one part of it work first (git only)

One script does not need any of the above, so you can judge the approach in a
minute before committing to the install. `repository-state.sh` is the
deterministic gate that opens every command in this kit:

```bash
git clone https://github.com/fresh-fx59/corp-sdd.git
cd corp-sdd
bash en/scripts/tools/repository-state.sh inspect
```

```text
repo=/home/you/corp-sdd
openspec_root=NONE
expected_base=main
branch=main
upstream=origin/main
dirty=0
untracked=0
stash_count=0
ahead=0
behind=0
```

Run it inside any repository you already have. It measures the state an agent is
about to work in instead of assuming it, and it never resets, cleans, rebases or
deletes anything — it reports, and it refuses:

```bash
bash en/scripts/tools/repository-state.sh assert-change ABCD-1234
```

```text
✗ OpenSpec root is not this repository
  ↳ resolved root: NONE
  ↳ every spec written here would land there instead — openspec walks up past .git
  ↳ onboard this repository (SETUP stage 5: openspec init, then check-openspec-root.sh)
```

Exit code 1. On a bare clone that refusal is expected and correct — nothing is
installed yet, so no spec may be written. That is the whole idea: the rules you
were hoping the model would remember are checks that run.

That is one of eleven scripts, around seven commands and six agent skills that
wrap [OpenSpec](https://github.com/Fission-AI/OpenSpec). The full flow, which
installs nothing to read: [`en/docs/FLOW.md`](en/docs/FLOW.md).

## Start here

| Language | Installation | Upgrade | Daily operations |
|---|---|---|---|
| English | [`en/docs/SETUP.md`](en/docs/SETUP.md) | [`en/docs/UPGRADE.md`](en/docs/UPGRADE.md) | [`en/docs/OPERATIONS.md`](en/docs/OPERATIONS.md) |
| Русский | [`ru/docs/SETUP.md`](ru/docs/SETUP.md) | [`ru/docs/UPGRADE.md`](ru/docs/UPGRADE.md) | [`ru/docs/OPERATIONS.md`](ru/docs/OPERATIONS.md) |

The workflow reference installs nothing and comes in three shapes:

| Language | Workflow reference | Wide table | Schema |
|---|---|---|---|
| English | [`en/docs/FLOW.md`](en/docs/FLOW.md) | [`en/docs/FLOW-TABLE.md`](en/docs/FLOW-TABLE.md) | [`en/docs/FLOW-SCHEMA.md`](en/docs/FLOW-SCHEMA.md) |
| Русский | [`ru/docs/FLOW.md`](ru/docs/FLOW.md) | [`ru/docs/FLOW-TABLE.md`](ru/docs/FLOW-TABLE.md) | [`ru/docs/FLOW-SCHEMA.md`](ru/docs/FLOW-SCHEMA.md) |

An installation still on the 2026-08-05 layout (`clones/` + `repos.json`) moves onto the
current one with `docs/MIGRATION-71de101-to-current.md`
([English](en/docs/MIGRATION-71de101-to-current.md) ·
[Русский](ru/docs/MIGRATION-71de101-to-current.md)).

Setup creates this operational layout:

```text
<workspace>/
├── corp-sdd/                  # this repository
└── system-store/              # independent Git repository
    ├── .gitmodules
    ├── project-repositories.json
    └── submodules/
        └── <project-repository>/
```

Project repository bindings come from MCP when available. The same normalized inventory can
be supplied manually, so MCP is not required for installation. The kit ships six self-contained
Corp skills; an external Superpowers installation is not required.

## Repository contents

- `en/` and `ru/`: equivalent English and Russian kits;
- `tests/`: the nine acceptance suites — the single home for them — run against both language trees;
- `docs/index.html`: the published presentation; its source lives in each language kit.
- `docs/common-contract.html`: how a cross-repo contract stays single-owner —
  <https://fresh-fx59.github.io/corp-sdd/common-contract.html>. Includes the two fetch
  routes a spoke delta needs (change-scoped while the contract change is open,
  spec-scoped once it is archived), measured against OpenSpec 1.10.0.

Each language kit keeps three operational documents — `SETUP.md`, `UPGRADE.md` and
`OPERATIONS.md` — plus the one-off `MIGRATION-71de101-to-current.md` runbook and three
reference documents that install nothing: `FLOW.md` (the short seven-stage reference),
`FLOW-TABLE.md` (the wide per-step table) and `FLOW-SCHEMA.md` (the same stages as a diagram).
Every OpenSpec call in a command is written as the single `<openspec>` token, which setup
replaces with the CLI invocation it resolved for the detected corporate agent.

Background: [Enterprise spec-driven development with AI agents](https://aiengineerhelper.com/posts/enterprise-spec-driven-development-ai-agents/).

## Versioning

The kit is versioned as a whole, by **edition**, not per asset. `<kit>/VERSION` holds the
edition (for example `2026-08-26.7`); every shipped command, skill and tool carries a matching
`corp-version:` stamp in its own header; `<kit>/MANIFEST.sha256` pins the exact bytes of each
stamped file for that edition. An installed copy can therefore be identified at any path,
without this repository.

`scripts/tools/kit-version.sh` is the only reader. Run it from the unpacked kit — it reads
`VERSION` and `MANIFEST.sha256` beside itself:

| Task | Command |
|---|---|
| Print the edition | `bash <kit>/scripts/tools/kit-version.sh show` |
| List every stamped file and its stamp | `bash <kit>/scripts/tools/kit-version.sh list` |
| Fail if any stamp differs from `VERSION` | `bash <kit>/scripts/tools/kit-version.sh check` |
| Fail if any file differs from the manifest | `bash <kit>/scripts/tools/kit-version.sh verify` |
| Report an installed copy: pristine / MODIFIED / UNSTAMPED | `bash <kit>/scripts/tools/kit-version.sh identify <file>…` |

`tests/kit-version-test.sh` gates all of this against both language trees.
