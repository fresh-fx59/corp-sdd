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
if [ "$docs" = "FLOW-SCHEMA.md FLOW-TABLE.md FLOW.md OPERATIONS.md SETUP.md " ]; then pass "only SETUP.md, OPERATIONS.md and the three FLOW references ship"; else fail "unexpected docs: $docs"; fi

printf 'T2 submodule layout and inventory contract\n'
check test -f "$KIT/config/project-repositories.json.example"
check test -f "$KIT/system-store-template/submodules/.gitkeep"
check test -f "$KIT/scripts/tools/sync-submodules.sh"
if ! rg -n 'sync-repos|repos\.json|(^|[/` ])clones([/` ]|$)' "$KIT" --glob '!**/slides/**' >/dev/null; then
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

printf 'T5 OpenSpec lifecycle commands are explicit port placeholders\n'
if rg -q '<opsx-new-command>' "$KIT/commands/corp-spec.md" && rg -q '<opsx-continue-command>' "$KIT/commands/corp-spec.md"; then pass "corp-spec explicitly starts and continues OpenSpec"; else fail "corp-spec OpenSpec calls missing"; fi
if rg -q '<opsx-apply-command>' "$KIT/commands/corp-implement.md"; then pass "corp-implement explicitly applies OpenSpec"; else fail "corp-implement apply call missing"; fi
if rg -q '<opsx-verify-command>' "$KIT/commands/corp-review.md"; then pass "corp-review explicitly verifies OpenSpec"; else fail "corp-review verify call missing"; fi
if rg -q '<opsx-archive-command>' "$KIT/commands/corp-archive.md"; then pass "corp-archive explicitly archives OpenSpec"; else fail "corp-archive call missing"; fi

printf 'T6 installed command paths are runtime-derived\n'
if ! rg -n '/Users/|/home/|/var/lib/zoekt|\.\./clones|bash tools/' "$KIT/commands" "$KIT/docs" "$KIT/README.md" >/dev/null; then pass "no machine-specific or cwd-relative command path"; else fail "hardcoded command path remains"; fi

printf '\nPASS=%s FAIL=%s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
