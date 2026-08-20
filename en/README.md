# Corporate SDD starter kit

This kit installs a project-level SDD system store and repository-level OpenSpec
workflow. It is self-contained for restricted networks after your organization
mirrors the required binaries and npm package.

Start with [`docs/SETUP.md`](docs/SETUP.md). It is the only installation and
upgrade runbook. Daily use and recovery are in
[`docs/OPERATIONS.md`](docs/OPERATIONS.md).

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
- `tests/`: acceptance tests maintained beside the distributable kit.

The template is deliberately not a nested Git repository. Setup copies it beside
`corp-sdd`, initializes Git there, and never modifies or removes an existing store.
