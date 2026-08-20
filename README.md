# Corporate SDD with AI agents

A self-contained starter kit for spec-driven development across corporate repositories.
It combines OpenSpec lifecycle commands with deterministic repository, branch, documentation,
and contract checks.

## Start here

| Language | Installation | Daily operations |
|---|---|---|
| English | [`en/docs/SETUP.md`](en/docs/SETUP.md) | [`en/docs/OPERATIONS.md`](en/docs/OPERATIONS.md) |
| Русский | [`ru/docs/SETUP.md`](ru/docs/SETUP.md) | [`ru/docs/OPERATIONS.md`](ru/docs/OPERATIONS.md) |

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
- `CORP-SDD-FLOW.md` and `CORP-SDD-FLOW-RU.md`: short workflow references;
- `docs/index.html`: the published presentation; its source lives in each language kit.

Each language kit keeps only two operational documents: `SETUP.md` and `OPERATIONS.md`.
Commands contain port-resolved OpenSpec placeholders which setup replaces with the generated
command names for the detected corporate agent.

Background: [Enterprise spec-driven development with AI agents](https://aiengineerhelper.com/posts/enterprise-spec-driven-development-ai-agents/).
