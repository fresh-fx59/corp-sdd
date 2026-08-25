#!/usr/bin/env bash
set -u

KIT="${1:?usage: starter-contract-test.sh <starter-kit-root>}"
PASS=0
FAIL=0

pass() { printf '  ✓ %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  ✗ %s\n' "$1"; FAIL=$((FAIL + 1)); }
check() { if "$@"; then pass "$*"; else fail "$*"; fi; }

printf 'T1 compact current documentation\n'
# In the public repo each language tree also carries three repo-only FLOW documents and the
# migration runbook. They install nothing; the kit contract is about what the KIT ships.
REPO_ONLY_DOCS="FLOW-SCHEMA.md FLOW-TABLE.md FLOW.md MIGRATION-71de101-to-current.md"
docs="$(find "$KIT/docs" -maxdepth 1 -type f -exec basename {} \; | LC_ALL=C sort | tr '\n' ' ')"
for extra in $REPO_ONLY_DOCS; do docs="${docs/$extra /}"; done
if [ "$docs" = "OPERATIONS.md SETUP.md UPGRADE.md " ]; then pass "only SETUP.md, UPGRADE.md and OPERATIONS.md ship"; else fail "unexpected docs: $docs"; fi

printf 'T2 submodule layout and inventory contract\n'
check test -f "$KIT/config/project-repositories.json.example"
check test -f "$KIT/system-store-template/submodules/.gitkeep"
check test -f "$KIT/scripts/tools/sync-submodules.sh"
# The migration runbook quotes the retired clones/ + repos.json layout deliberately — it is the
# document that moves an installation off it.
if ! rg -n 'sync-repos|repos\.json|(^|[/` ])clones([/` ]|$)' "$KIT" --glob '!**/slides/**' --glob '!**/MIGRATION-*.md' >/dev/null; then
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
if rg -q '<openspec> new change' "$KIT/commands/corp-spec.md" && rg -q '<openspec> instructions proposal' "$KIT/commands/corp-spec.md" && rg -q '<openspec> instructions specs' "$KIT/commands/corp-spec.md"; then pass "corp-spec creates the change and names each artifact"; else fail "corp-spec OpenSpec calls missing"; fi
# A spec run can start with no ticket, on an existing branch, or already on it: all three must be handled.
if rg -q 'NO-TICKET' "$KIT/commands/corp-spec.md"; then pass "corp-spec refuses to invent a ticket key"; else fail "corp-spec ticket gate missing"; fi
if rg -q 'ls-remote --heads origin feature/<TICKET>' "$KIT/commands/corp-spec.md"; then pass "corp-spec looks for an existing story branch"; else fail "corp-spec existing-branch probe missing"; fi
if rg -q 'assert-change <TICKET> --allow-dirty' "$KIT/commands/corp-spec.md"; then pass "corp-spec resumes on the story branch instead of re-preparing the base"; else fail "corp-spec resume path missing"; fi
if rg -q '<openspec> instructions design' "$KIT/commands/corp-plan.md" && rg -q '<openspec> instructions tasks' "$KIT/commands/corp-plan.md"; then pass "corp-plan asks for design and tasks only"; else fail "corp-plan OpenSpec calls missing"; fi
if rg -q '<openspec> instructions apply' "$KIT/commands/corp-implement.md"; then pass "corp-implement reads apply state"; else fail "corp-implement apply call missing"; fi
if rg -q '<openspec> validate' "$KIT/commands/corp-review.md" && rg -q '<openspec> status' "$KIT/commands/corp-review.md"; then pass "corp-review validates and reads status"; else fail "corp-review validate call missing"; fi
if rg -q '<openspec> archive' "$KIT/commands/corp-archive.md"; then pass "corp-archive explicitly archives OpenSpec"; else fail "corp-archive call missing"; fi
# One vocabulary everywhere: CLI calls take <change-id>, never the raw {{args}} token, and every
# machine-readable call asks for --json. Mixed semantics across files is what confuses the model.
if rg -q -- '--change \{\{args\}\}' "$KIT/commands" "$KIT/skills"; then fail "a CLI call still takes {{args}} instead of <change-id>"; else pass "every OpenSpec CLI call takes <change-id>"; fi
if rg -q -- '<openspec> archive \{\{args\}\}' "$KIT/commands"; then fail "archive still passes {{args}} (it carries placement flags)"; else pass "archive passes the change id only"; fi
if [ "$(rg -c -- '<openspec> (status|instructions) [^`]*--json' "$KIT/commands" | wc -l | tr -d ' ')" -ge 3 ]; then pass "status and instructions calls are --json in every command that uses them"; else fail "an OpenSpec state call is missing --json"; fi
# Acceptance semantics live in the spec; corp-test-plan renders them and may not silently re-derive.
if rg -q 'SENDS and what they OBSERVE|ОТПРАВЛЯЕТ и что НАБЛЮДАЕТ' "$KIT/commands/corp-spec.md"; then pass "corp-spec makes every scenario observable from outside"; else fail "corp-spec testability question missing"; fi
if rg -q 'DRIFT IS NOT YOURS TO FIX|РАСХОЖДЕНИЕ ЧИНИШЬ НЕ ТЫ' "$KIT/commands/corp-test-plan.md"; then pass "corp-test-plan routes drift back as a spec amendment"; else fail "corp-test-plan drift rule missing"; fi
if rg -q 'dead-letter|dead-letter назначение' "$KIT/commands/corp-spec.md"; then pass "corp-spec records error and dead-letter facts"; else fail "corp-spec error/DLQ facts missing"; fi
if rg -q 'ACCEPTANCE|ПРИЁМКА' "$KIT/commands/corp-review.md"; then pass "corp-review reviews the acceptance scenarios"; else fail "corp-review acceptance lens missing"; fi
if rg -q 'names no observable surface' "$KIT/scripts/tools/corp-lint.mjs"; then pass "corp-lint warns on an unobservable requirement"; else fail "corp-lint observability warning missing"; fi
# The slash commands these replaced do not exist in OpenSpec 1.10's core profile.
if rg -q 'opsx' "$KIT/commands" "$KIT/skills" "$KIT/docs" --glob '!**/MIGRATION-*.md'; then fail "a non-existent opsx slash command is still referenced"; else pass "no opsx slash command referenced"; fi

printf 'T6 installed command paths are runtime-derived\n'
if ! rg -n '/Users/|/home/|/var/lib/zoekt|\.\./clones|bash tools/' "$KIT/commands" "$KIT/docs" "$KIT/README.md" --glob '!**/MIGRATION-*.md' >/dev/null; then pass "no machine-specific or cwd-relative command path"; else fail "hardcoded command path remains"; fi

printf 'T7 corp-lint keeps only what openspec validate does NOT check\n'
# Delta-spec grammar (missing delta section, non-`### Requirement:` heading, scenario-less
# ADDED/MODIFIED, delta section with no requirement) is the CLI's job since edition .12 —
# every command that writes or reviews a spec runs `validate --strict`. What the lint must still
# catch is what the CLI is measurably blind to: a requirement outside any delta section.
fixture="$(mktemp -d)"
mkdir -p "$fixture/openspec/changes/c1/specs"
delta="$fixture/openspec/changes/c1/specs/spec.md"
lint() { node "$KIT/scripts/tools/corp-lint.mjs" "$fixture" >/dev/null 2>&1; }

printf '# Delta\n\n## ADDED Requirements\n\n### Requirement: User signs in\n\n#### Scenario: ok\n- **WHEN** x\n- **THEN** y\n' > "$delta"
if lint; then pass "the literal '### Requirement:' heading passes"; else fail "correct heading rejected"; fi

printf '# Delta\n\n## ADDED Requirements\n\n### \xd0\xa2\xd1\x80\xd0\xb5\xd0\xb1\xd0\xbe\xd0\xb2\xd0\xb0\xd0\xbd\xd0\xb8\xd0\xb5 1: \xd0\xb2\xd1\x85\xd0\xbe\xd0\xb4\n\n#### Scenario: ok\n- **WHEN** x\n' > "$delta"
if lint; then fail "translated requirement heading accepted"; else pass "translated requirement heading rejected"; fi

printf '# Delta\n\n## ADDED Requirements\n\n### Requirement: Good\n\nThe system SHALL expose GET /x and return 200.\n\n#### Scenario: ok\n- **WHEN** x\n\n### \xd0\xa2\xd1\x80\xd0\xb5\xd0\xb1\xd0\xbe\xd0\xb2\xd0\xb0\xd0\xbd\xd0\xb8\xd0\xb5: \xd0\xb2\xd1\x82\xd0\xbe\xd1\x80\xd0\xbe\xd0\xb5\n\n#### \xd0\xa1\xd1\x86\xd0\xb5\xd0\xbd\xd0\xb0\xd1\x80\xd0\xb8\xd0\xb9: ok\n- **WHEN** y\n' > "$delta"
if lint; then fail "mistyped heading beside a good one accepted (openspec keeps valid=true and drops the requirement)"; else pass "mistyped heading beside a good one rejected"; fi

printf '# Delta\n\n## ADDED Requirements\n\nprose only, no heading\n' > "$delta"
if lint; then pass "empty delta section left to openspec"; else fail "lint still re-implements the openspec parser"; fi

printf '# Delta\n\n## ADDED Requirements\n\n### Requirement: Good\n\nThe system SHALL expose GET /x and return 200.\n\n#### Scenario: ok\n- **WHEN** x\n\n## Notes\n\n### Requirement: Orphan\n\nThe system SHALL do y.\n' > "$delta"
if lint; then fail "requirement outside a delta section accepted (openspec drops it silently)"; else pass "requirement outside a delta section rejected"; fi

printf '# Delta\n\n## ADDED Requirements\n\n### Requirement: X\n\nThe system SHALL do x.\n\n#### Scenario: ok\n- **WHEN** x\n\n```md\n### \xd0\xa2\xd1\x80\xd0\xb5\xd0\xb1\xd0\xbe\xd0\xb2\xd0\xb0\xd0\xbd\xd0\xb8\xd0\xb5: sample\n```\n' > "$delta"
if lint; then pass "a heading inside a fenced example is not flagged"; else fail "fenced example flagged"; fi

# Upstream SCENARIO_HEADER is /^####\s+/ — ANY level-4 heading counts, so Russian scenario
# wording is valid; what archive refuses is an ADDED/MODIFIED requirement with no scenario at all.
printf '# Delta\n\n## ADDED Requirements\n\n### Requirement: \xd0\xb2\xd1\x85\xd0\xbe\xd0\xb4 SHALL work\n\n#### \xd0\xa1\xd1\x86\xd0\xb5\xd0\xbd\xd0\xb0\xd1\x80\xd0\xb8\xd0\xb9: \xd0\xbe\xd0\xba\n- **WHEN** x\n' > "$delta"
if lint; then pass "a Russian scenario heading is accepted (upstream counts any ####)"; else fail "Russian scenario heading wrongly rejected"; fi

printf '# Delta\n\n## ADDED Requirements\n\n### Requirement: X SHALL work\n\nprose but no scenario\n' > "$delta"
if lint; then pass "scenario-less ADDED left to openspec (ERROR: must include at least one scenario)"; else fail "lint still re-implements the openspec parser"; fi

printf '# Delta\n\n## REMOVED Requirements\n\n### Requirement: X\n' > "$delta"
if lint; then pass "REMOVED needs no scenario"; else fail "REMOVED requirement wrongly required a scenario"; fi

printf '# Delta\n\n## RENAMED Requirements\n\n### Requirement: X\n' > "$delta"
if lint; then pass "RENAMED is a valid delta section"; else fail "RENAMED section rejected (openspec accepts it)"; fi
rm -rf "$fixture"

printf 'T7b every command that writes or archives a spec calls openspec validate --strict\n'
for f in corp-spec corp-archive corp-implement corp-review; do
  if rg -q -- 'validate .*--type change --strict --json' "$KIT/commands/$f.md"; then
    pass "$f calls validate --strict"
  else
    fail "$f does not call validate --strict (the lint no longer checks delta grammar)"
  fi
done
if rg -q -- 'validate .*--type change --strict --json' "$KIT/skills/corp-code-review/SKILL.md"; then
  pass "corp-code-review calls validate --strict"
else
  fail "corp-code-review does not call validate --strict"
fi

printf 'T7c every writing command commits its own work, by path\n'
for f in corp-spec corp-plan corp-implement corp-autotest corp-archive; do
  if rg -qi 'commit|коммит' "$KIT/commands/$f.md"; then
    pass "$f commits what it writes"
  else
    fail "$f leaves its work uncommitted for the operator"
  fi
done
for f in corp-spec corp-plan corp-implement corp-autotest; do
  if rg -q -- 'git add -A' "$KIT/commands/$f.md" | rg -qv 'Never|никогда'; then
    fail "$f tells the agent to stage everything (local-only files would be committed)"
  else
    pass "$f stages by path, not everything"
  fi
done

printf 'T8 corp-archive keeps the write-then-check index order\n'
if rg -q 'gen-index\.mjs' "$KIT/commands/corp-archive.md"; then pass "corp-archive writes the index"; else fail "corp-archive dropped gen-index (verify-docs only runs --check)"; fi
if rg -q 'verify-docs\.sh' "$KIT/commands/corp-archive.md"; then pass "corp-archive verifies"; else fail "corp-archive lacks verify-docs"; fi

printf 'T9 corp-archive lets the operator choose where the archive commit lands\n'
if rg -q -- '--here' "$KIT/commands/corp-archive.md"; then pass "corp-archive offers --here"; else fail "corp-archive has no --here mode"; fi
if rg -q -- '--branch' "$KIT/commands/corp-archive.md"; then pass "corp-archive offers --branch"; else fail "corp-archive has no --branch mode"; fi
if rg -q 'repository-state\.sh" assert-archivable' "$KIT/commands/corp-archive.md"; then pass "corp-archive gates placement with assert-archivable"; else fail "corp-archive lost the assert-archivable gate"; fi
if rg -q 'assert-archivable' "$KIT/scripts/tools/repository-state.sh"; then pass "repository-state implements assert-archivable"; else fail "repository-state has no assert-archivable mode"; fi

printf 'T10 every shipped command, skill and tool is version-stamped\n'
if [ -f "$KIT/VERSION" ]; then pass "kit carries a VERSION"; else fail "kit has no VERSION file"; fi
if [ -f "$KIT/MANIFEST.sha256" ]; then pass "kit carries MANIFEST.sha256"; else fail "kit has no MANIFEST.sha256"; fi
if bash "$KIT/scripts/tools/kit-version.sh" check >/dev/null 2>&1; then pass "every stamp matches VERSION"; else fail "a command, skill or tool is unstamped or stale"; fi
if bash "$KIT/scripts/tools/kit-version.sh" verify >/dev/null 2>&1; then pass "every stamped file matches the manifest"; else fail "MANIFEST.sha256 is stale — re-run tests/stamp-kit.py"; fi

printf '\nPASS=%s FAIL=%s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
