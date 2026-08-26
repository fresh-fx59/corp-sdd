# Corporate SDD starter kit

This kit installs a project-level SDD system store and repository-level OpenSpec
workflow. It is self-contained for restricted networks after your organization
mirrors the required binaries and npm package.

Start with [`docs/SETUP.md`](docs/SETUP.md): it is the installation runbook for a
new workspace. An existing workspace moves to a newer kit edition through
[`docs/UPGRADE.md`](docs/UPGRADE.md); an installation still on the 2026-08-05 layout
migrates with [`docs/MIGRATION-71de101-to-current.md`](docs/MIGRATION-71de101-to-current.md).
Daily use and recovery are in
[`docs/OPERATIONS.md`](docs/OPERATIONS.md).

The workflow itself is described three times, and none of these files installs anything:
[`docs/FLOW.md`](docs/FLOW.md) is the seven-stage table, one row per `corp-*` command;
[`docs/FLOW-TABLE.md`](docs/FLOW-TABLE.md) is the wide table with the OpenSpec call, the
Superpowers discipline, the scripts that actually run, the exit gate and the value per step;
[`docs/FLOW-SCHEMA.md`](docs/FLOW-SCHEMA.md) is the same seven stages as a one-screen diagram.

## Resulting workspace

```text
<workspace>/
├── corp-sdd/                  # this kit, settings, commands, skills, scripts
└── system-store/              # independent Git repository
    ├── project-repositories.json
    ├── .gitmodules
    ├── openspec/              # cross-repository contracts and ADRs
    ├── tools/
    └── submodules/
        ├── <repository-a>/
        └── <repository-b>/
```

Repository bindings come from the project's MCP integration when available.
The same normalized JSON can be supplied manually, so MCP is not an installer
dependency. The kit ships its own `corp-*` skills. Upstream Superpowers is not
required.

## Shipped components

- `system-store-template/`: plain files copied to create the sibling store;
- `scripts/tools/`: submodule sync, repository-state gates, docs checks, indexes;
- `commands/`: seven Corp workflow command templates with explicit OpenSpec calls;
- `skills/`: six self-contained Corp skills;
- `templates/`: research, ADR, contract, port facts, and branch conventions;
- `config/`: normalized inventory example and lefthook example;
- `slides/`: the talk deck and its editable source.

The acceptance suites that gate this kit are not shipped inside the kit: all eight live at
`tests/` in the repository root, beside the two language copies, and each one is run against
this tree's shipped files by passing the file under test as its first argument, for example
`bash tests/corp-lint-test.sh en/scripts/tools/corp-lint.mjs`.

The template is deliberately not a nested Git repository. Setup copies it beside
`corp-sdd`, initializes Git there, and never modifies or removes an existing store.
