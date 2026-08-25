#!/usr/bin/env bash
set -u

KIT="${1:?usage: starter-contract-test.sh <starter-kit-root>}"
PASS=0
FAIL=0

pass() { printf '  ✓ %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  ✗ %s\n' "$1"; FAIL=$((FAIL + 1)); }
check() { if "$@"; then pass "$*"; else fail "$*"; fi; }

printf 'T1 compact current documentation\n'
docs="$(find "$KIT/docs" -maxdepth 1 -type f -exec basename {} \; | LC_ALL=C sort | tr '\n' ' ')"
if [ "$docs" = "FLOW-SCHEMA.md FLOW-TABLE.md FLOW.md MIGRATION-71de101-to-current.md OPERATIONS.md SETUP.md UPGRADE.md " ]; then pass "only the install, upgrade, migration, operations and FLOW documents ship"; else fail "unexpected docs: $docs"; fi

printf 'T2 submodule layout and inventory contract\n'
check test -f "$KIT/config/project-repositories.json.example"
check test -f "$KIT/system-store-template/submodules/.gitkeep"
check test -f "$KIT/scripts/tools/sync-submodules.sh"
# MIGRATION-71de101-to-current.md quotes the retired `clones/` + `repos.json` layout on
# purpose — it is the runbook off it — and the kit README points at that runbook. Every
# other file must be free of the clone-era contract.
if ! rg -n 'sync-repos|repos\.json|(^|[/` ])clones([/` ]|$)' "$KIT" \
     --glob '!**/slides/**' --glob '!**/MIGRATION-71de101-to-current.md' --glob '!README.md' >/dev/null; then
  pass "clone-era contract is absent"
else
  fail "clone-era contract remains"
fi

printf 'T3 setup has independent discovery and installation paths\n'
if rg -q 'MCP' "$KIT/docs/SETUP.md" && rg -qi 'manual' "$KIT/docs/SETUP.md"; then pass "MCP and manual inventory paths documented"; else fail "inventory fallback missing"; fi
if rg -qi 'without.*Superpowers|Superpowers.*not required|does not require.*Superpowers|Superpowers не требуется|без Superpowers' "$KIT/docs/SETUP.md"; then pass "Superpowers is optional"; else fail "Superpowers independence missing"; fi
mcp_line="$(rg -n '^## 1\.' "$KIT/docs/SETUP.md" | head -1 | cut -d: -f1)"
port_line="$(rg -n '^## 2\.' "$KIT/docs/SETUP.md" | head -1 | cut -d: -f1)"
if [ -n "$mcp_line" ] && [ -n "$port_line" ] && [ "$mcp_line" -lt "$port_line" ]; then pass "project repository discovery is the first setup stage"; else fail "repository discovery is not first"; fi
if rg -q 'git clone .*CORP_SYSTEM_STORE_ROOT' "$KIT/docs/SETUP.md" && rg -q 'system-store-template' "$KIT/docs/SETUP.md"; then pass "existing and new system-store paths documented"; else fail "system-store install paths incomplete"; fi
if rg -q 'repository-state\.sh.*prepare-base.*--repo.*CORP_SYSTEM_STORE_ROOT' "$KIT/docs/SETUP.md"; then pass "existing system store is state-gated before writes"; else fail "system-store state gate missing"; fi

printf 'T4 every command gates repository state\n'
for command in "$KIT"/commands/*.md; do
  if rg -q 'repository-state\.sh' "$command"; then pass "$(basename "$command") has repository gate"; else fail "$(basename "$command") lacks repository gate"; fi
done

printf 'T5 OpenSpec lifecycle calls are explicit `<openspec>` CLI placeholders\n'
# One vocabulary: every command spells the CLI as `<openspec>`, and setup replaces that single
# token with the invocation `port-facts.md` records. There is no per-command slash placeholder.
if rg -q '<openspec> new change' "$KIT/commands/corp-spec.md" && rg -q '<openspec> instructions specs' "$KIT/commands/corp-spec.md"; then pass "corp-spec creates the change and asks for proposal/specs"; else fail "corp-spec OpenSpec calls missing"; fi
if rg -q '<openspec> instructions design' "$KIT/commands/corp-plan.md" && rg -q '<openspec> instructions tasks' "$KIT/commands/corp-plan.md"; then pass "corp-plan asks for design/tasks"; else fail "corp-plan artifact calls missing"; fi
if rg -q '<openspec> instructions apply' "$KIT/commands/corp-implement.md"; then pass "corp-implement reads apply state"; else fail "corp-implement apply call missing"; fi
if rg -q '<openspec> status --change' "$KIT/commands/corp-review.md"; then pass "corp-review reads change status"; else fail "corp-review status call missing"; fi
if rg -q '<openspec> archive <change-id> --yes --json' "$KIT/commands/corp-archive.md"; then pass "corp-archive explicitly archives OpenSpec"; else fail "corp-archive call missing"; fi

printf 'T5a every spec-writing command hands the delta to strict OpenSpec validation\n'
for command in corp-spec corp-plan corp-implement corp-review corp-archive; do
  case "$command" in
    corp-plan) continue ;;  # corp-plan writes design/tasks, not the delta spec
  esac
  if rg -q 'validate <change-id> --type change --strict --json' "$KIT/commands/$command.md"; then pass "$command runs validate --strict --json"; else fail "$command lacks the strict validation call"; fi
done

printf 'T6 installed command paths are runtime-derived\n'
if ! rg -n '/Users/|/home/|/var/lib/zoekt|\.\./clones|bash tools/' "$KIT/commands" "$KIT/docs" "$KIT/README.md" \
     --glob '!**/MIGRATION-71de101-to-current.md' >/dev/null; then pass "no machine-specific or cwd-relative command path"; else fail "hardcoded command path remains"; fi

printf '\nPASS=%s FAIL=%s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
