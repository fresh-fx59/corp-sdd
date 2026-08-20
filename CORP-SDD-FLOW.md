# Corp SDD flow

This is the short English workflow reference. Installation is documented only in
[`en/docs/SETUP.md`](en/docs/SETUP.md); daily use is documented only in
[`en/docs/OPERATIONS.md`](en/docs/OPERATIONS.md).

## Installation boundary

The installer places `system-store` next to this repository. Product repositories are Git
submodules under `system-store/submodules/`; no clone directory is maintained.

1. Discover project-bound repositories through the available MCP during setup stage 1.
2. If MCP is unavailable, collect the same `name`, `url`, and `baseBranch` inventory manually.
3. Validate the inventory and write `system-store/project-repositories.json`.
4. Run `sync-submodules.sh`; it registers, initializes, and updates only declared submodules.
5. Install the kit's commands, tools, and six self-contained `corp-*` skills.
6. Resolve the local OpenSpec command names into the command placeholders.
7. Run the acceptance checks before using the workflow.

MCP improves discovery but is not an installation dependency. Upstream Superpowers is also
optional because the required engineering disciplines are included in the kit.

## Delivery lifecycle

| Step | Corp command | Required OpenSpec action | Repository-state gate |
|---|---|---|---|
| Specify | `corp-spec` | Run resolved `opsx new`, then `opsx continue` until `proposal.md` and `spec.md` exist. | Inspect first; prepare the configured base branch before creating a change branch. |
| Plan | `corp-plan` | Run resolved `opsx continue` until `design.md` and `tasks.md` exist. | Require the exact tracked change branch and a clean state. |
| Implement | `corp-implement` | Enter resolved `opsx apply`, then execute each task with Corp TDD. | Require the exact change branch; dirty work is allowed explicitly. |
| Plan tests | `corp-test-plan` | Read the OpenSpec change and create scenario coverage. | Inspect and validate a local change branch when present. |
| Run tests | `corp-autotest` | Update OpenSpec evidence after the test tiers finish. | Require the exact change branch; dirty work is allowed explicitly. |
| Review | `corp-review` | Run resolved `opsx verify` before the deeper code review. | Inspect and validate a local change branch when present. |
| Archive | `corp-archive` | Run resolved `opsx archive` after the pull request is merged. | Prepare and verify the configured base branch first. |

Every command derives `REPO_ROOT`, `STORE_ROOT`, and tool paths at runtime. It never depends on a
developer-specific absolute path or on the caller's current directory.

## Proof

Run the six scripts in `tests/` against both language kits. They cover submodule synchronization,
branch safety, aggregation, indexing, path derivation, documentation scope, MCP fallback, explicit
OpenSpec actions, and the absence of clone-era paths.
