# Corporate SDD with AI agents

A self-contained starter kit for spec-driven development across corporate repositories.
It combines OpenSpec lifecycle commands with deterministic repository, branch, documentation,
and contract checks.

## Start here

| Language | Installation | Daily operations | Workflow reference | Schema |
|---|---|---|---|---|
| English | [`en/docs/SETUP.md`](en/docs/SETUP.md) | [`en/docs/OPERATIONS.md`](en/docs/OPERATIONS.md) | [`en/docs/FLOW.md`](en/docs/FLOW.md) | [`en/docs/FLOW-SCHEMA.md`](en/docs/FLOW-SCHEMA.md) |
| Русский | [`ru/docs/SETUP.md`](ru/docs/SETUP.md) | [`ru/docs/OPERATIONS.md`](ru/docs/OPERATIONS.md) | [`ru/docs/FLOW.md`](ru/docs/FLOW.md) | [`ru/docs/FLOW-SCHEMA.md`](ru/docs/FLOW-SCHEMA.md) |

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
- `tests/`: local Git acceptance tests for both language trees;
- `docs/index.html`: the published presentation; its source lives in each language kit.
- `VERSIONS.md`: the version of every shipped command, skill, and script;
- `tools/versions.mjs` and `.githooks/pre-commit`: the automatic version stamper.

Each language kit keeps two operational documents — `SETUP.md` and `OPERATIONS.md` — plus two
reference documents that install nothing: `FLOW.md` (the seven-stage table) and `FLOW-SCHEMA.md`
(the same stages as a diagram).
Commands contain port-resolved OpenSpec placeholders which setup replaces with the generated
command names for the detected corporate agent.

Background: [Enterprise spec-driven development with AI agents](https://aiengineerhelper.com/posts/enterprise-spec-driven-development-ai-agents/).

## Versioning

Every command, skill, and script states its own version: `version: X.Y.Z` in Markdown
frontmatter, `corp-sdd-version: X.Y.Z` in scripts. `VERSIONS.md` is the generated index.

Bumps are automatic — the `pre-commit` hook raises the patch level of every staged asset
whose body actually changed, and refreshes `VERSIONS.md`, so no one is asked for a version
number. Restaging an untouched file, amending, or rebasing never bumps anything: the check
compares the file against `HEAD` with the version line removed. Enable the hook once:

```bash
git config core.hooksPath .githooks
```

| Task | Command |
|---|---|
| Check markers and manifest | `node tools/versions.mjs --check` |
| Regenerate `VERSIONS.md` | `node tools/versions.mjs --manifest` |
| Raise minor/major by hand | `node tools/versions.mjs --minor <files>` |
| Commit without bumping | `CORP_SDD_NO_BUMP=1 git commit …` |
| Report what is installed | `bash <kit>/scripts/tools/corp-versions.sh --kit <kit> <dirs>` |
